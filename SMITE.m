classdef SMITE < handle
    properties (Access = protected, Hidden = true)
        % dll and mex files
        iView;
        sampEvtBuffers;
        
        % state
        isInitialized   = false;
        usingFTGLTextRenderer;
        keyState;
        shiftKey;
        mouseState;
        needsCheckAveraging = false;    % for systems that do not support setting averaging of eye data
        
        % settings and external info
        settings;
        scrInfo;
        
        % eye-tracker info
        caps;           % will be populated with info about capabilities of the connected eye-tracker
    end
    
    properties (SetAccess=private)
        systemInfo;
        geom;
        calibrateHistory;
    end
    
    % computed properties (so not actual properties)
    properties (Dependent, SetAccess = private)
        rawET;          % get naked iViewXAPI instance
        rawBuffers;     % get naked SMIbuffer instance
    end
    properties (Dependent)
        options;    % subset of settings that can actually be changed. contents differ based on state of class (once inited, much less can be set)
    end
    
    methods
        function obj = SMITE(settingsOrETName,scrInfo)
            % deal with inputs
            if ischar(settingsOrETName)
                % only eye-tracker name provided, load defaults for this
                % tracker
                obj.options = obj.getDefaults(settingsOrETName);
            else
                obj.options = settingsOrETName;
            end
            
            if nargin<2 || isempty(scrInfo)
                obj.scrInfo.resolution  = Screen('Rect',0); obj.scrInfo.resolution(1:2) = [];
                obj.scrInfo.center      = obj.scrInfo.resolution/2;
            else
                assert(isfield(scrInfo,'resolution') && isfield(scrInfo,'center'),'SMITE: scrInfo should have a ''resolution'' and a ''center'' field')
                obj.scrInfo             = scrInfo;
            end
        end
        
        function delete(obj)
            obj.deInit();
        end
        
        function out = setDummyMode(obj)
            assert(nargout==1,'SMITE: you must use the output argument of setDummyMode, like: SMIhandle = SMIhandle.setDummyMode(), or SMIhandle = setDummyMode(SMIhandle)')
            out = SMITEDummyMode(obj);
        end
        
        function out = get.rawET(obj)
            out = obj.iView;
        end
        
        function out = get.rawBuffers(obj)
            out = obj.sampEvtBuffers;
        end
        
        function out = get.options(obj)
            if ~obj.isInitialized
                % return all settings
                out = obj.settings;
            else
                % only the subset that can be changed "live"
                opts = obj.getAllowedOptions();
                for p=1:size(opts,1)
                    out.(opts{p,1}).(opts{p,2}) = obj.settings.(opts{p,1}).(opts{p,2});
                end
            end
        end
        
        function set.options(obj,settings)
            if obj.isInitialized
                % only a subset of settings is allowed. Hardcode here, and
                % copy over if exist. Ignore all others silently
                allowed = obj.getAllowedOptions();
                for p=1:size(allowed,1)
                    if isfield(settings,allowed{p,1}) && isfield(settings.(allowed{p,1}),allowed{p,2})
                        obj.settings.(allowed{p,1}).(allowed{p,2}) = settings.(allowed{p,1}).(allowed{p,2});
                    end
                end
            else
                % just copy it over. If user didn't remove fields from
                % settings struct, we're good. If they did, they're an
                % idiot. If they added any, they'll be ignored, so no
                % problem.
                obj.settings = settings;
            end
            % setup colors
            obj.settings.cal.bgColor        = color2RGBA(obj.settings.cal.bgColor);
            obj.settings.cal.fixBackColor   = color2RGBA(obj.settings.cal.fixBackColor);
            obj.settings.cal.fixFrontColor  = color2RGBA(obj.settings.cal.fixFrontColor);
        end
        
        function out = init(obj)
            % see what text renderer to use
            obj.usingFTGLTextRenderer = ~~exist('libptbdrawtext_ftgl64.dll','file');    % check if we're on a Windows platform with the high quality text renderer present (was never supported for 32bit PTB, so check only for 64bit)
            if ~obj.usingFTGLTextRenderer
                assert(isfield(obj.settings.text,'lineCentOff'),'SMITE: PTB''s TextRenderer changed between calls to getDefaults and the SMITE constructor. If you force the legacy text renderer by calling ''''Screen(''Preference'', ''TextRenderer'',0)'''' (not recommended) make sure you do so before you call SMITE.getDefaults(), as it has differnt settings than the recommended TextRendered number 1')
            end
            % init key, mouse state
            [~,~,obj.keyState] = KbCheck();
            obj.shiftKey = KbName('shift');
            [~,~,obj.mouseState] = GetMouse();
            
            % get capabilities for the connected eye-tracker
            obj.setCapabilities();
            
            % Load in plugin (SMI dll)
            obj.iView = iViewXAPI();
            
            % Load in our callback buffer mex (tell it if online data has
            % eyes swapped)
            obj.sampEvtBuffers = SMIbuffer(obj.caps.needsEyeFlip);
            
            % For reasons unclear to me, a brief wait here improved
            % stability on some of the testing systems.
            WaitSecs(0.1);
            
            % Create logger file, if wanted
            if obj.settings.logLevel
                ret = obj.iView.setLogger(obj.settings.logLevel, obj.settings.logFileName);
                obj.processError(ret,sprintf('SMITE: Logger at "%s" could not be opened',obj.settings.logFileName));
            end
            
            % Connect to server
            obj.iView.disconnect();  % disconnect first, found this necessary as API otherwise apparently does not recognize it when eye tracker server crashed or closed by hand while connected. Well, calling 'iV_IsConnected' twice seems to work...
            if obj.settings.start.removeTempDataFile && ~obj.isTwoComputerSetup()
                % remove temp idf file on this computer (file or even
                % folder may not exist, no worries because then no problem)
                % NB: we don't support one computer setup for old RED
                % officially, so i'm not deleting anything from that temp
                % folder here (its also likely to contain a lot of
                % different files instead of just the temp file for the
                % current unfinished recording, so blanket deletion is
                % perhaps unsafe)
                [~,~]=system('del /F /S /Q /A "C:\ProgramData\SMI\iView X\temp\*.idf"');            % RED-m location
                [~,~]=system('del /F /S /Q /A "C:\ProgramData\SMI\TempRemoteRecordings\*.idf"');    % RED NG location
            end
            ret = obj.iView.start(obj.settings.etApp);  % returns 1 when starting app, 4 if its already running
            qStarting = ret==1;
            
            % connect
            ret = obj.connect();
            if qStarting && ret~=1
                % in case eye tracker server is starting, give it some time
                % before trying to connect, don't hammer it unnecessarily
                obj.iView.setConnectionTimeout(1);   % "timeout for how long iV_Connect tries to connect to iView eye tracking server." Try short, try often, so we don't wait unnecessarily long
                count = 1;
                while count < 30 && ret~=1
                    ret = obj.connect();
                    count = count+1;
                end
            end
            
            switch ret
                case 1
                    % connected, we're good. nothing to do here
                case 104
                    error('SMITE: Could not establish connection. Check if Eye Tracker application is running (error 104: %s)',SMIErrCode2String(ret));
                case 105
                    error('SMITE: Could not establish connection. Check the communication ports (error 105: %s)',SMIErrCode2String(ret));
                case 123
                    error('SMITE: Could not establish connection. Another process is blocking the communication ports (error 123: %s)',SMIErrCode2String(ret));
                case 201
                    error('SMITE: Could not establish connection. Check if Eye Tracker is installed and running (error 201: %s)',SMIErrCode2String(ret));
                otherwise
                    obj.processError(ret,'SMITE: Could not establish connection');
            end
            
            % check this is the device the user specified
            if obj.caps.deviceName
                % if possible, use this interface as it is most precise
                % (RED-m and RED250mobile are both 'REDm' in the return of
                % getSystemInfo)
                [~,trackerName] = obj.iView.getDeviceName;
                assert(strcmp(trackerName(1:min(end,length(obj.settings.tracker))),obj.settings.tracker),'SMITE: Connected tracker is a "%s", not the "%s" you specified',trackerName,obj.settings.tracker)
            else
                % this is a old RED or a HiSpeed, check using ETDevice in
                % getSystemInfo if it is the device specified by the user
                [~,sysInfo] = obj.iView.getSystemInfo();
                qErr = false;
                switch obj.settings.tracker
                    case {'HiSpeed240','HiSpeed1250'}
                        qErr = ~strcmp(sysInfo.iV_ETDevice,'HiSpeed');
                    case {'RED500','RED250','RED120','RED60'}
                        qErr = ~strcmp(sysInfo.iV_ETDevice,'RED');
                end
                assert(~qErr,'SMITE: Connected tracker is a "%s", not the "%s" you specified',sysInfo.iV_ETDevice,obj.settings.tracker)
            end
            
            % deal with device geometry
            if obj.caps.setREDGeometry
                % setup device geometry
                ret = obj.iView.selectREDGeometry(obj.settings.setup.geomProfile);
                obj.processError(ret,sprintf('SMITE: Error selecting geometry profile "%s"',obj.settings.setup.geomProfile));
            end
            if obj.caps.hasREDGeometry
                % get info about the setup
                [~,obj.geom]    = obj.iView.getCurrentREDGeometry();
                obj.geom.setupName = char(obj.geom.setupName(obj.geom.setupName~=0));
                out.geom        = obj.geom;
                if ismember(obj.settings.tracker,{'RED500','RED250','RED120','RED60'})
                    % check correct geometry is set in iViewX (NB:
                    % technically, if iViewX is set to standalone mode,
                    % selectREDGeometry() would work to select the profile.
                    % but since that requires the user to set it up
                    % correctly manually anyway, we gain nothing by
                    % supporting that here).
                    assert(strcmpi(obj.geom.redGeometry,obj.settings.setup.geomMode),'SMITE: incorrect RED Operation Mode selected in iViewX. Got "%s", expected "%s"',obj.geom.redGeometry, obj.settings.setup.geomMode)
                    switch obj.geom.redGeometry
                        case 'monitorIntegrated'
                            assert(obj.geom.monitorSize==obj.settings.setup.monitorSize,'SMITE: incorrect monitor size selected in iViewX for monitorIntegrated RED Operation Mode. Got "%d", expected "%d"',obj.geom.monitorSize, obj.settings.setup.monitorSize)
                        case 'standalone'
                            assert(strcmpi(obj.geom.setupName,obj.settings.setup.geomProfile),                        'SMITE: incorrect profile selected in iViewX for standalone RED Operation Mode. Got "%s", expected "%s"'                ,obj.geom.setupName, obj.settings.setup.geomProfile)
                            assert(obj.geom.stimX              == obj.settings.setup.scrWidth,                   'SMITE: incorrect screen width selected in iViewX for standalone profile "%s" in RED Operation Mode. Got "%d", expected "%d"',obj.geom.setupName, obj.geom.stimX              , obj.settings.setup.scrWidth)
                            assert(obj.geom.stimY              ==obj.settings.setup.scrHeight,                  'SMITE: incorrect screen height selected in iViewX for standalone profile "%s" in RED Operation Mode. Got "%d", expected "%d"',obj.geom.setupName, obj.geom.stimY              , obj.settings.setup.scrHeight)
                            assert(obj.geom.stimHeightOverFloor==obj.settings.setup.scrDistToFloor,  'SMITE: incorrect distance floor to screen selected in iViewX for standalone profile "%s" in RED Operation Mode. Got "%d", expected "%d"',obj.geom.setupName, obj.geom.stimHeightOverFloor, obj.settings.setup.scrDistToFloor)
                            assert(obj.geom.redHeightOverFloor ==obj.settings.setup.REDDistToFloor,     'SMITE: incorrect distance floor to RED selected in iViewX for standalone profile "%s" in RED Operation Mode. Got "%d", expected "%d"',obj.geom.setupName, obj.geom.redHeightOverFloor , obj.settings.setup.REDDistToFloor)
                            assert(obj.geom.redStimDist        ==obj.settings.setup.REDDistToScreen,            'SMITE: incorrect distance RED to screen in iViewX for standalone profile "%s" in RED Operation Mode. Got "%d", expected "%d"',obj.geom.setupName, obj.geom.redStimDist        , obj.settings.setup.REDDistToScreen)
                            assert(obj.geom.redInclAngle       ==obj.settings.setup.REDInclAngle,       'SMITE: incorrect RED inclination angle selected in iViewX for standalone profile "%s" in RED Operation Mode. Got "%d", expected "%d"',obj.geom.setupName, obj.geom.redInclAngle       , obj.settings.setup.REDInclAngle)
                    end
                end
            end
            
            % if supported, set tracker to operate at requested tracking frequency
            if obj.caps.setSpeedMode
                % NB: I found this command to be unstable at best, so i'm
                % not checking the return value. Below we're checking if
                % we're at the right tracking frequency anyway
                ret = obj.iView.setSpeedMode(obj.settings.freq);
                obj.processError(ret,sprintf('SMITE: Error setting tracker sampling frequency to "%d"',obj.settings.freq));
            end
            
            % get info about the system
            [~,obj.systemInfo]          = obj.iView.getSystemInfo();
            if obj.caps.serialNumber
                [~,obj.systemInfo.Serial]   = obj.iView.getSerialNumber();
            end
            out.systemInfo              = obj.systemInfo;
            
            % check tracker is operating at requested tracking frequency
            assert(obj.systemInfo.samplerate == obj.settings.freq,'SMITE: Tracker not running at requested sampling rate (%d Hz), but at %d Hz',obj.settings.freq,obj.systemInfo.samplerate);
            % setup track mode
            if obj.caps.setTrackingParam
                ret = obj.iView.setTrackingParameter(['ET_PARAM_' obj.settings.trackEye], ['ET_PARAM_' obj.settings.trackMode], 1);
                obj.processError(ret,'SMITE: Error selecting tracking mode');
            end
            % switch off averaging filter so we get separate data for each eye
            if isfield(obj.settings,'doAverageEyes')
                if obj.caps.configureFilter
                    ret = obj.iView.configureFilter('Average', 'Set', int32(obj.settings.doAverageEyes));
                    obj.processError(ret,'SMITE: Error configuring averaging filter');
                else
                    obj.needsCheckAveraging = true;
                end
            end
            
            % prevents CPU from entering power saving mode according to
            % docs
            if obj.caps.enableHighPerfMode
                obj.iView.enableProcessorHighPerformanceMode();
            end
            
            % mark as inited
            obj.isInitialized = true;
        end
        
        function out = calibrate(obj,wpnt,qClearBuffer)
            % this function does all setup, draws the interface, etc
            
            % by default don't clear recording buffer. You DO NOT want to do
            % that when recalibrating, e.g. in the middle of the trial, or at
            % second attempt
            if nargin<2
                qClearBuffer = false;
            end
            
            %%% 1: set up calibration
            % to be safe, disable SMI calibration keys when possible
            % NB: manual says only for NG trackers, but seems to help
            % implementation act correctly on the RED-m as well...
            obj.iView.setUseCalibrationKeys(0);
            
            % set background color
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % NB: fullscreen fillrect sets new clear color in PTB
            % SMI calibration setup
            CalibrationData = SMIStructEnum.Calibration;
            CalibrationData.method               = obj.settings.cal.nPoint;
            CalibrationData.autoAccept           = int32(obj.settings.cal.autoPace);
            % Setup calibration look. Necessary in all cases so that
            % validate image looks similar to calibration stimuli
            CalibrationData.foregroundBrightness = obj.settings.cal.fixBackColor(1);
            CalibrationData.backgroundBrightness = obj.settings.cal.bgColor(1);
            CalibrationData.targetSize           = max(10,round(obj.settings.cal.fixBackSize/2));   % 10 is the minimum size. Ignored for validation image...
            ret = obj.iView.setupCalibration(CalibrationData);
            obj.processError(ret,'SMITE: Error setting up calibration');
            
            % reset calibration points in case someone else changed them
            % previously
            obj.iView.resetCalibrationPoints();
            
            % TODO: HiSpeed only: set calibration/validation points
            
            % get where the calibration points are
            pCalibrationPoint = SMIStructEnum.CalibrationPoint;
            out.calibrationPoints = struct('X',zeros(1,obj.settings.cal.nPoint),'Y',zeros(1,obj.settings.cal.nPoint));
            for p=1:obj.settings.cal.nPoint
                obj.iView.getCalibrationPoint(p, pCalibrationPoint);
                out.calibrationPoints.X(p) = pCalibrationPoint.positionX;
                out.calibrationPoints.Y(p) = pCalibrationPoint.positionY;
            end
            
            %%% 2: enter the screens, from setup to validation results
            kCal = 0;
            
            % The below is a big loop that will run possibly multiple
            % calibration until exiting because skipped or a calibration is
            % selected by user.
            % there are three start modes:
            % 0. skip head positioning, go straight to calibration
            % 1. start with simple head positioning interface
            % 2. start with advanced head positioning interface
            startScreen = obj.settings.setup.startScreen;
            while true
                qGoToValidationViewer = false;
                kCal = kCal+1;
                if startScreen>0
                    %%% 2a: show head positioning screen
                    status = obj.showHeadPositioning(wpnt,out,startScreen);
                    switch status
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            break;
                        case -3
                            % go to validation viewer screen
                            qGoToValidationViewer = true;
                        case -4
                            % full stop
                            error('SMITE: run ended from SMI calibration routine')
                        otherwise
                            error('SMITE: status %d not implemented',status);
                    end
                end
                
                %%% 2b: calibrate and validate
                if ~qGoToValidationViewer
                    [out.attempt{kCal}.calStatus,temp] = obj.DoCalAndVal(wpnt,qClearBuffer);
                    warning('off','catstruct:DuplicatesFound')  % field already exists but is empty, will be overwritten with the output from the function here
                    out.attempt{kCal} = catstruct(out.attempt{kCal},temp);
                    % qClearbuffer should now become false even if it was true,
                    % as buffer has been cleared in calibration lines above
                    qClearBuffer = false;
                    % check returned action state
                    switch out.attempt{kCal}.calStatus
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            break;
                        case -1
                            % restart calibration
                            startScreen = 0;
                            continue;
                        case -2
                            % go to setup
                            startScreen = max(1,startScreen);
                            continue;
                        case -4
                            % full stop
                            error('SMITE: run ended from SMI calibration routine')
                        otherwise
                            error('SMITE: status %d not implemented',out.attempt{kCal}.calStatus);
                    end
                    
                    % check calibration status to be sure we're calibrated
                    [~,out.attempt{kCal}.calStatusSMI] = obj.iView.getCalibrationStatus();
                    if ~strcmp(out.attempt{kCal}.calStatusSMI,'calibrationValid')
                        % retry calibration
                        startScreen = max(1,startScreen);
                        continue;
                    end
                    
                    % store calibration so user can select which one they want
                    obj.iView.saveCalibration(num2str(kCal));
                end
                
                %%% 2c: show calibration results
                % get info about accuracy of calibration
                [~,out.attempt{kCal}.validateAccuracy] = obj.iView.getAccuracy([], 0);
                % get validation image
                [~,out.attempt{kCal}.validateImage] = obj.iView.getAccuracyImage();
                % show validation result and ask to continue
                [out.attempt{kCal}.valResultAccept,out.attempt{kCal}.calSelection] = obj.showValidationResult(wpnt,out.attempt,kCal);
                switch out.attempt{kCal}.valResultAccept
                    case 1
                        % all good, we're done
                        break;
                    case 2
                        % skip setup
                        break;
                    case -1
                        % restart calibration
                        startScreen = 0;
                        continue;
                    case -2
                        % go to setup
                        startScreen = max(1,startScreen);
                        continue;
                    case -4
                        % full stop
                        error('SMITE: run ended from SMI calibration routine')
                    otherwise
                        error('SMITE: status %d not implemented',out.attempt{kCal}.valResultAccept);
                end
            end
            
            % clean up
            Screen('Flip',wpnt);
            
            % store calibration info in calibration history, for later
            % retrieval if wanted
            if isempty(obj.calibrateHistory)
                obj.calibrateHistory{1} = out;
            else
                obj.calibrateHistory{end+1} = out;
            end
        end
        
        function startRecording(obj,qClearFileBuffer)
            % by default do not clear recording buffer. For SMI, by the time
            % user calls startRecording, we already have data recorded during
            % calibration and validation in the buffer
            if nargin<2 || isempty(qClearFileBuffer)
                qClearFileBuffer = false;
            end
            obj.iView.stopRecording();      % make sure we're not already recording when we startRecording(), or we get an error. Ignore error return code here
            if qClearFileBuffer
                obj.iView.clearRecordingBuffer();
            end
            ret = obj.iView.startRecording();
            obj.processError(ret,'SMITE: Error starting recording');
            WaitSecs(.1); % give it some time to get started. not needed according to doc, but never hurts
        end
        
        function startBuffer(obj,size)
            if nargin<2
                size = [];
            end
            ret = obj.sampEvtBuffers.startSampleBuffering(size);
            obj.processError(ret,'SMITE: Error starting sample buffer');
        end
        
        function data = getBufferData(obj)
            data = obj.sampEvtBuffers.getSamples();
        end
        
        function sample = getLatestSample(obj)
            % returns empty when sample not gotten successfully
            [sample,ret] = obj.getSample();
            if ret~=1
                sample = [];
            end
        end
        
        function stopBuffer(obj,doDeleteBuffer)
            if nargin<2
                doDeleteBuffer = false;
            end
            obj.sampEvtBuffers.stopSampleBuffering(doDeleteBuffer);
        end
        
        function stopRecording(obj)
            ret = obj.iView.stopRecording();
            obj.processError(ret,'SMITE: Error stopping recording');
        end
        
        function out = isConnected(obj)
            out = obj.iView.isConnected();
        end
        
        function sendMessage(obj,str)
            % using
            % calllib('obj.iViewXAPI','iV_SendImageMessage','msg_string')
            % here to save overhead
            % consider using that directly in your code for best timing
            % ret = obj.iView.sendImageMessage(str);
            ret = calllib('iViewXAPI','iV_SendImageMessage',str);
            obj.processError(ret,'SMITE: Error sending message to data file');
            if obj.settings.debugMode
                fprintf('%s\n',str);
            end
        end
        
        function setBegazeTrialImage(obj,filename)
            [path,~,ext] = fileparts(filename);
            % 1. there must not be a path
            assert(isempty(path),'SMITE: SMI BeGaze trial image/video must not contain a path to be usable by BeGaze')
            % 2. check extention is one of the supported ones
            assert(ismember(ext,{'.png','.jpg','.jpeg','.bmp','.avi'}),'SMITE: SMI BeGaze trial image/video must have one of the following extensions: .png, .jpg, .jpeg, .bmp or .avi')
            % ok, send
            obj.sendMessage(filename);
        end
        
        function setBegazeKeyPress(obj,string)
            % can use this to send any string into BeGaze event stream (do
            % not know length limit). I advise to keep this short
            % special format to achieve this
            string = sprintf('UE-keypress %s',string);
            % ok, send
            obj.sendMessage(string);
        end
        
        function setBegazeMouseClick(obj,which,x,y)
            assert(ismember(which,{'left','right'}),'SMITE: SMI BeGaze mouse press must be for ''left'' or ''right'' mouse button')
            % special format to achieve this
            string = sprintf('UE-mouseclick %s x=%d y=%d',which,x,y);
            % ok, send
            obj.sendMessage(string);
        end
        
        function startEyeImageRecording(obj,filename, format, duration)
            % NB: does NOT work on NG eye-trackers (RED250mobile, RED-n)
            % if using two computer setup, save location is on remote
            % computer, if not a full path is given, it is relative to
            % iView install directory on that computer. If single computer
            % setup, relative paths are relative to the current working
            % directory when this function is called
            % duration is in ms. If provided, images for the recording
            % duration are buffered and written to disk afterwards, so no
            % images will be lost. If empty, images are recorded directly
            % to disk (and lost if disk can't keep up).
            
            % get filename and path
            [path,file,~] = fileparts(filename);
            if isempty(regexp(path,'^\w:', 'once')) && ~obj.isTwoComputerSetup()
                % single computer setup and no drive letter in provided
                % path. Interpret path as relative to cd
                path = fullfile(cd,path);
            end
            
            % check format
            if ischar(format)
                format = find(strcmpi(format,{'jpg','bmp','xvid','huffyuv','alpary','xmp4'}));
                assert(~isempty(format),'SMITE: if eyeimage format provided as string, should be one of ''jpg'',''bmp'',''xvid'',''huffyuv'',''alpary'',''xmp4''');
                format = format-1;
            end
            assert(isnumeric(format) && format>=0 && format<=5,'SMITE eyeimage format should be between 0 and 5 (inclusive)')
            
            % send command
            if isempty(duration)
                obj.rawET.sendCommand(sprintf('ET_EVB %d "%s" "%s"\n',format,file,path));
            else
                obj.rawET.sendCommand(sprintf('ET_EVB %d "%s" "%s" %d\n',format,file,path,duration));
            end
        end
        
        function stopEyeImageRecording(obj)
            % if no duration specified when calling recordEyeImages, call
            % this function to stop eye image recording
            obj.rawET.sendCommand('ET_EVE\n');
        end
        
        function saveData(obj,filename, user, description, doAppendVersion)
            % 1. get filename and path
            [path,file,ext] = fileparts(filename);
            assert(~isempty(path),'SMITE: saveData: filename should contain a path (consider using ''fullfile(cd,%s)'')',filename);
            % eat .idf off filename, preserve any other extension user may
            % have provided
            if ~isempty(ext) && ~strcmpi(ext,'.idf')
                file = [file ext];
            end
            % add versioning info to file name, if wanted and if already
            % exists
            if nargin>=5 && doAppendVersion
                % see what files we have in data folder with the same name
                f = FileFromFolder(path,'ssilent','idf');
                f = regexp({f.fname},['^' regexptranslate('escape',file) '(_\d+)?$'],'tokens');
                % see if any. if so, see what number to append
                f = [f{:}];
                if ~isempty(f)
                    % files with this subject name exist
                    f=cellfun(@(x) sscanf(x,'_%d'),[f{:}],'uni',false);
                    f=sort([f{:}]);
                    if isempty(f)
                        file = [file '_1'];
                    else
                        file = [file '_' num2str(max(f)+1)];
                    end
                end
            end
            % now make sure file ends with .idf
            file = [file '.idf'];
            % set defaults
            if nargin<3 || isempty(user)
                user = file;
            end
            if nargin<4 || isempty(description)
                description = '';
            end
            
            % construct full filename
            filename = fullfile(path,file);
            
            if obj.isTwoComputerSetup()
                % Two computer setup: file gets saved on eye-tracker
                % computer (do so with without path info and allowing
                % overwrite). Transfer the file using the
                % FileTransferServer running on the remote machine. NB:
                % this seems to only work when iView is running on the
                % remote machine.
                
                % 1: connect to file transfer server
                % 1a: request FileTransferServer.exe's version (always
                %     happens when experiment center is just started)
                con = pnet('tcpconnect',obj.settings.connectInfo{1},9050);
                pnet(con,'setreadtimeout',0.1);
                pnet(con,'write',uint8(4));
                data = '';
                while isempty(data)
                    data = pnet(con,'read',2^20,'uint8');
                end
                fprintf('FileTransferServer.exe version: %s\n',char(data(6:end)));    % first 5 bytes are a response header
                pnet(con,'close');  % copy exact order of events, perhaps important
                % 1b: ask what the data folder is
                con = pnet('tcpconnect',obj.settings.connectInfo{1},9050);
                pnet(con,'setreadtimeout',0.1);
                pnet(con,'write',uint8(0));
                allDat = '';
                tries = 0;
                while tries<5
                    data = pnet(con,'read',2^20,'uint8');
                    if isempty(data)
                        tries = tries+1;
                    end
                    allDat = [allDat data]; %#ok<AGROW>
                end
                remotePath = allDat(6:end); % skip first 5 bits, they are a response header
                
                % 2: now save file on remote computer with path indicated
                % by remote computer. Overwrite if exists
                remoteFile = fullfile(remotePath,[file(1:3) '-eye_data.idf']);   % nearly hardcode remote file name. Only very specific file names are transferred by the remote endpoint
                ret = obj.iView.saveData(remoteFile, description, user, 1);     % 1: always overwrite existing file with same name on the remote computer
                obj.processError(ret,'SMITE: Error saving data');
                fprintf('file stored on the remote (eye-tracker) computer as ''%s''\n',remoteFile);
                % now that data is savely stored remotely, check that we
                % would not be overwriting a file locally
                assert(~exist(filename,'file'),'SMITE: error saving data because local file already exists. File stored on the remote (eye-tracker) computer as ''%s''\n',remoteFile);
                
                % 3a: now request remote file to be transferred
                pnet(con,'write', [uint8([1 50 0 0 0]) uint8(remoteFile)]);
                
                % 3b: receive file: read from socket until exhausted
                allDat = '';
                tries = 0;
                pnet(con,'setreadtimeout',0.5);
                while tries<10
                    data = pnet(con,'read',2^20,'uint8');
                    if isempty(data)
                        tries = tries+1;
                    else
                        tries = 0;
                    end
                    allDat = [allDat data]; %#ok<AGROW>
                end
                pnet(con,'close');
                
                % 4: now save file locally (we already check above that the
                % file does not exist, so overwriting should not happen
                % here)
                assert(~isempty(allDat),'SMITE: remote file could not be received. File stored on the remote (eye-tracker) computer as ''%s''\n',remoteFile);
                fid=fopen(filename,'w');
                fwrite(fid,allDat(6:end));  % skip first 5 bits, they are a response header
                fclose(fid);
            else
                ret = obj.iView.saveData(filename, description, user, 0);   % 0: never overwrite existing file with same name
                obj.processError(ret,'SMITE: Error saving data');
            end
        end
        
        function out = deInit(obj,qQuit)
            if isempty(obj.iView)
                % init was never called, nothing to do here
                return;
            end
            
            obj.iView.disconnect();
            % also, read log, return contents as output and delete
            fid = fopen(obj.settings.logFileName, 'r');
            if fid~=-1
                out = fread(fid, inf, '*char').';
                fclose(fid);
            else
                out = '';
            end
            % somehow, matlab maintains a handle to the log file, even after
            % fclose all and unloading the SMI library. Somehow a dangling
            % handle from smi, would be my guess (note that calling iV_Quit did
            % not fix it).
            % delete(smiSetup.logFileName);
            if nargin>1 && qQuit
                obj.iView.quit();
            end
            
            % mark as deinited
            obj.isInitialized = false;
        end
    end
    
    
    
    
    % helpers
    methods (Static)
        function settings = getDefaults(tracker)
            settings.tracker    = tracker;
            
            % which app to iV_Start()
            switch tracker
                case {'HiSpeed240','HiSpeed1250','RED500','RED250','RED120','RED60'}
                    settings.etApp              = 'iViewX';
                case 'RED-m'
                    settings.etApp              = 'iViewXOEM';
                case {'RED250mobile','REDn'}
                    settings.etApp              = 'iViewNG';
                otherwise
                    error('SMITE: tracker "%s" not known/supported.\nSupported are: HiSpeed240, HiSpeed1250, RED500, RED250, RED120, RED60, RED-m, RED250mobile, REDn.\nNB: correct capitalization in the name is important.',tracker);
            end
            % connection info
            switch tracker
                case {'RED-m','RED250mobile','REDn'}
                    % likely one-computer setup, connectLocal() should
                    % work, so default is:
                    settings.connectInfo        = {};
                    % NB: for RED NG trackers, it is also supported to
                    % supply only the remote endpoint, like:
                    % settings.connectInfo        = {'ipETComputer',4444};
                case {'HiSpeed240','HiSpeed1250','RED500','RED250','RED120','RED60'}
                    % template IPs, default ports
                    settings.connectInfo        = {'ipETComputer',4444,'ipThis',5555};
            end
            % default tracking settings per eye-tracker
            % settings (only provided if supported):
            % - trackEye:               'EYE_LEFT', 'EYE_RIGHT', or
            %                           'EYE_BOTH'
            % - trackMode:              'MONOCULAR', 'BINOCULAR',
            %                           'SMARTBINOCULAR', or
            %                           'SMARTTRACKING'
            % - doAverageEyes           true/false.
            % - freq:                   eye-tracker dependant. Only for NG
            %                           trackers can it actually be set 
            % - cal.nPoint:             0, 1, 2, 5, 9 or 13 calibration
            %                           points are possible
            switch tracker
                case 'HiSpeed1250'
                case 'HiSpeed240'
                case {'RED500','RED250','RED120','RED60'}
                    % TODO: averaging eyes and any tracking mode setup is not
                    % possible remotely. has to be done by hand in iViewX.
                    % so, check/warn
                    settings.cal.nPoint             = 5;
                    settings.doAverageEyes          = false;
                    settings.setup.headBox          = [40 20];  % at 70 cm. Doesn't matter what distance, is just for getting aspect ratio
                    if strcmp(tracker,'RED500')
                        settings.setup.eyeImageSize     = [ 80 344];
                    else
                        settings.setup.eyeImageSize     = [160 496];
                    end
                    settings.freq                   = str2double(tracker(4:end));   % tracker sampling frequency is the number at the end of the tracker name
                case 'RED-m'
                    settings.trackEye               = 'EYE_BOTH';
                    settings.trackMode              = 'SMARTBINOCULAR';
                    settings.freq                   = 120;
                    settings.cal.nPoint             = 5;
                    settings.doAverageEyes          = true;
                    settings.setup.headBox          = [31 21];  % at 60 cm. Doesn't matter what distance, is just for getting aspect ratio
                    settings.setup.eyeImageSize     = [];   % TODO
                case 'RED250mobile'
                    settings.trackEye               = 'EYE_BOTH';
                    settings.trackMode              = 'SMARTBINOCULAR';
                    settings.freq                   = 250;
                    settings.cal.nPoint             = 5;
                    settings.doAverageEyes          = true;
                    settings.setup.headBox          = [32 21];  % at 60 cm. Doesn't matter what distance, is just for getting aspect ratio
                    settings.setup.eyeImageSize     = [160 496];
                case 'REDn'
                    settings.trackEye               = 'EYE_BOTH';
                    settings.trackMode              = 'SMARTBINOCULAR';
                    settings.freq                   = 60;
                    settings.cal.nPoint             = 5;
                    settings.doAverageEyes          = true;
                    settings.setup.headBox          = [50 30];  % at 65 cm. Doesn't matter what distance, is just for getting aspect ratio
                    settings.setup.eyeImageSize     = []; % TODO
            end
            
            % some settings only for remotes
            switch tracker
                case {'RED500','RED250','RED120','RED60'}
                    settings.setup.viewingDist      = 65;
                    settings.setup.geomMode         = 'monitorIntegrated';  % monitorIntegrated or standalone
                    % only when in monitorIntegrated mode:
                    settings.setup.monitorSize      = 22;
                    % only when in standalone mode:
                    settings.setup.geomProfile      = 'profileName';
                    settings.setup.scrWidth         = 0;
                    settings.setup.scrHeight        = 0;
                    settings.setup.scrDistToFloor   = 0;
                    settings.setup.REDDistToFloor   = 0;
                    settings.setup.REDDistToScreen  = 0;
                    settings.setup.REDInclAngle     = 0;
                case 'RED-m'
                    settings.setup.viewingDist      = 65;
                    settings.setup.geomProfile      = 'Desktop 22in Monitor';
                case {'RED250mobile'}
                    settings.setup.viewingDist      = 65;
                    settings.setup.geomProfile      = 'Default Profile';
                case {'REDn'}
                    settings.setup.viewingDist      = 65;
                    settings.setup.geomProfile      = 'Default Profile';    % TODO, is it the correct name?
            end
            
            % the rest here are general defaults. Many are hard to set...
            settings.start.removeTempDataFile   = true;                     % when calling iV_Start, it always complains with a popup if there is some unsaved recorded data in iView's temp location. The popup can really mess with visual timing of PTB, so its best to remove it. Not relevant for a two computer setup
            settings.setup.startScreen  = 1;                                % 0. skip head positioning, go straight to calibration; 1. start with simple head positioning interface; 2. start with advanced head positioning interface
            settings.cal.autoPace       = 1;                                % 0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted
            settings.cal.bgColor        = 127;
            settings.cal.fixBackSize    = 20;
            settings.cal.fixFrontSize   = 5;
            settings.cal.fixBackColor   = 0;
            settings.cal.fixFrontColor  = 255;
            settings.cal.drawFunction   = [];
            settings.logFileName        = 'iView_log.txt';
            settings.text.font          = 'Consolas';
            settings.text.style         = 0;                                % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.text.wrapAt        = 62;
            settings.text.vSpacing      = 1;
            if ~exist('libptbdrawtext_ftgl64.dll','file') % if old text renderer, we have different defaults and an extra settings
                settings.text.size          = 20;
                settings.text.lineCentOff   = 3;                                % amount (pixels) to move single line text down so that it is visually centered on requested coordinate
            else
                settings.text.size          = 24;
            end
            settings.string.simplePositionInstruction = 'Position yourself such that the two circles overlap.\nDistance: %.0f cm';
            settings.debugMode          = false;                            % for use together with PTB's PsychDebugWindowConfiguration. e.g. does not hide cursor
            % SDK log Level:
            % no logs at all:               0
            % LOG_LEVEL_BUG                 1
            % LOG_LEVEL_iV_FCT              2: NB: for RED-m, this always crashes on the second invocation of setlog, so use with care...
            % LOG_LEVEL_ALL_FCT             4: shows many internal function calls as well. as long as the server is on, it is trying to track. so every x ms you have a record of the output of the function that calculates gaze position...
            % LOG_LEVEL_IV_COMMAND          8
            % LOG_LEVEL_RECV_IV_COMMAND     16
            % You can request multiple types of log by adding them
            % together, e.g. logLevel = 1+4+8+16
            settings.logLevel           = 1;
        end
        
        function processError(returnCode,errorString)
            % for SMI, anything that is not 1 is an error
            if returnCode~=1
                error('%s (error %d: %s)',errorString,returnCode,SMIErrCode2String(returnCode));
            end
        end
    end
    
    methods (Access = private, Hidden)
        function allowed = getAllowedOptions(obj)
            allowed = {...
                'setup','startScreen'
                'cal','autoPace'
                'cal','nPoint'
                'cal','bgColor'
                'cal','fixBackSize'
                'cal','fixFrontSize'
                'cal','fixBackColor'
                'cal','fixFrontColor'
                'cal','drawFunction'
                'text','font'
                'text','size'
                'text','style'
                'text','wrapAt'
                'text','vSpacing'
                'text','lineCentOff'
                'string','simplePositionInstruction'
                };
            for p=size(allowed,1):-1:1
                if ~isfield(obj.settings,allowed{p,1}) || ~isfield(obj.settings.(allowed{p,1}),allowed{p,2})
                    allowed(p,:) = [];
                end
            end
                        
        end
        
        function setCapabilities(obj)
            % preset all to false
            obj.caps.connectLocal       = false;
            obj.caps.connectOnlyRemote  = false;
            obj.caps.configureFilter    = false;
            obj.caps.enableHighPerfMode = false;
            obj.caps.deviceName         = false;
            obj.caps.serialNumber       = false;
            obj.caps.setSpeedMode       = false;
            obj.caps.setREDGeometry     = false;
            obj.caps.hasREDGeometry     = false;
            obj.caps.setTrackingParam   = false;
            obj.caps.hasHeadbox         = true;
            obj.caps.needsEyeFlip       = false;
            
            % RED-m and newer functionality
            switch obj.settings.tracker
                case {'RED-m','RED250mobile','REDn'}
                    obj.caps.connectLocal       = true;
                    obj.caps.configureFilter    = true;
                    obj.caps.enableHighPerfMode = true;
                    obj.caps.deviceName         = true;
                    obj.caps.serialNumber       = true;
                    obj.caps.setREDGeometry     = true;
            end
            % RED NG only functionality
            switch obj.settings.tracker
                case {'RED250mobile','REDn'}
                    obj.caps.connectOnlyRemote  = true;
                    obj.caps.setSpeedMode       = true;
            end
            % functionality not for hiSpeeds
            switch obj.settings.tracker
                case {'RED500','RED250','RED120','RED60','RED-m','RED250mobile','REDn'}
                    obj.caps.hasREDGeometry     = true;
            end
            % functionality not for old REDs
            switch obj.settings.tracker
                case {'HiSpeed240','HiSpeed1250','RED-m','RED250mobile','REDn'}
                    obj.caps.setTrackingParam   = true;
            end
            % indicate for which trackers the eye identities are flipped
            % (also position in headbox needs a flip)
            switch obj.settings.tracker
                case {'RED500','RED250','RED120','RED60'}
                    obj.caps.needsEyeFlip     = true;
            end
            % setting only for hispeed
            switch obj.settings.tracker
                case {'HiSpeed240','HiSpeed1250'}
                    obj.caps.hasHeadbox         = false;
            end
            % supported number of calibration points
            % TODO
            % old REDs: 2, 5 or 9 points
            % RED NG: 0, 1, 2, 5, 9 or 13
            % RED-m:
            % Hispeed 1250:
            % Hispeed 240:
            
            % some other per tracker settings.
            % TODO: I don't know which trackers support which!!. Have now
            % checked: RED-m, old RED, RED250mobile
            obj.caps.setShowContour    = ismember(obj.settings.tracker,{});
            obj.caps.setShowPupil      = ismember(obj.settings.tracker,{'RED-m'});
            obj.caps.setShowCR         = ismember(obj.settings.tracker,{'RED-m'});
        end
        
        function ret = connect(obj)
            if isempty(obj.settings.connectInfo)
                if obj.caps.connectLocal
                    ret = obj.iView.connectLocal();
                else
                    error('SMITE: %s tracker does not support iV_ConnectLocal, provide settings.connectInfo',obj.settings.tracker)
                end
            else
                if length(obj.settings.connectInfo)==2
                    if obj.caps.connectOnlyRemote
                        ret = obj.iView.connect(obj.settings.connectInfo{:},'',0);
                    else
                        error('SMITE: %s tracker does not support calling iV_Connect specifying only the remote endpoint. Make sure setting.connectInfo is four elements long',obj.settings.tracker)
                    end
                elseif length(obj.settings.connectInfo)==4
                    ret = obj.iView.connect(obj.settings.connectInfo{:});
                else
                    error('SMITE: setting.connectInfo misspecified. Make sure it is four elements long')
                end
            end
        end
        
        function status = showHeadPositioning(obj,wpnt,out,startScreen)
            % status output:
            %  1: continue (setup seems good) (space)
            %  2: skip calibration and continue with task (shift+s)
            % -3: go to validation screen (p) -- only if there are already
            %     completed calibrations
            % -4: Exit completely (control+escape)
            % (NB: no -1 for this function)
            
            % init
            status = 5+5*(startScreen==2);  % 5 if simple screen requested, 10 if advanced screen
            
            while true
                if status==5
                    % simple setup screen. has two circles for positioning, a button to
                    % start calibration and a button to go to advanced view
                    status = obj.showHeadPositioningSimple(wpnt,out);
                elseif status==10
                    % advanced interface, has head box and eye image
                    status = obj.showHeadPositioningAdvanced(wpnt,out);
                else
                    break;
                end
            end
        end
        
        function status = showHeadPositioningSimple(obj,wpnt,out)
            % if user it at reference viewing distance and at center of head box
            % vertically and horizontally, two circles will overlap
            
            % see if we already have valid calibrations
            qHaveValidCalibrations = false;
            if isfield(out,'attempt')
                iValid = obj.getValidCalibrations(out.attempt);
                qHaveValidCalibrations = ~isempty(iValid);
            end
            
            % setup text
            Screen('TextFont',  wpnt, obj.settings.text.font);
            Screen('TextSize',  wpnt, obj.settings.text.size);
            Screen('TextStyle', wpnt, obj.settings.text.style);
            
            if obj.caps.hasHeadbox
                % setup ovals
                ovalVSz = .15;
                refSz   = ovalVSz*obj.scrInfo.resolution(2);
                refClr  = [0 0 255];
                headClr = [255 255 0];
                % setup head position visualization
                distGain= 1.5;
            end

            % setup buttons
            buttonSz    = {[220 45] [320 45] [400 45]};
            buttonSz    = buttonSz(1:2+qHaveValidCalibrations);  % third button only when more than one calibration available
            if ~obj.caps.hasHeadbox
                % don't show advanced button as you have all the info on
                % the iViewX display already. but during development, it
                % may be nice to see the eye image. So 'a' key remains
                % active
                buttonSz(1) = [];
            end
            buttonOff   = 80;
            yposBase    = round(obj.scrInfo.resolution(2)*.95);
            % place buttons for back to simple interface, or calibrate
            buttonWidths= cellfun(@(x) x(1),buttonSz);
            totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
            b = 1;
            if obj.caps.hasHeadbox
                advancedButRect         = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
                advancedButTextCache    = obj.getButtonTextCache(wpnt,'advanced (<i>a<i>)'        ,advancedButRect);
                b=b+1;
            else
                advancedButRect         = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            
            calibButRect            = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
            calibButTextCache       = obj.getButtonTextCache(wpnt,'calibrate (<i>spacebar<i>)',   calibButRect);
            b=b+1;
            if qHaveValidCalibrations
                validateButRect         = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
                validateButTextCache    = obj.getButtonTextCache(wpnt,'previous calibrations (<i>p<i>)',validateButRect);
            else
                validateButRect         = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % clear what we've just drawn
            
            % setup fixation points in the corners of the screen
            fixPos = [.1 .1; .1 .9; .9 .9; .9 .1] .* repmat(obj.scrInfo.resolution(1:2),4,1);
            
            % setup cursors
            cursors.rect    = {advancedButRect.' calibButRect.' validateButRect.'};
            cursors.cursor  = [2 2 2];      % Hand
            cursors.other   = 0;            % Arrow
            if ~obj.settings.debugMode      % for cleanup
                cursors.reset = -1;         % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor          = cursorUpdater(cursors);
            
            % get tracking status and visualize
            if obj.caps.hasHeadbox
                pTrackingStatusS= SMIStructEnum.TrackingStatus;
                pSampleS        = SMIStructEnum.Sample;
            end
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            while true
                if obj.caps.hasHeadbox
                    % get tracking status info
                    pTrackingStatus = obj.getTrackingStatus(pTrackingStatusS);  % for position in headbox
                    pSample         = obj.getSample(pSampleS);                  % for distance

                    % get average eye distance. use distance from one eye if only one eye
                    % available
                    distL   = pSample.leftEye .eyePositionZ/10;
                    distR   = pSample.rightEye.eyePositionZ/10;
                    dists   = [distL distR];
                    avgDist = mean(dists(~isnan(dists)));

                    % scale up size of oval. define size/rect at standard distance, have a
                    % gain for how much to scale as distance changes
                    if pTrackingStatus.leftEye.validity || pTrackingStatus.rightEye.validity
                        pos     = [pTrackingStatus.total.relativePositionX -pTrackingStatus.total.relativePositionY];  %-Y as +1 is upper and -1 is lower edge. needs to be reflected for screen drawing
                        % determine size of oval, based on distance from reference distance
                        fac     = avgDist/obj.settings.setup.viewingDist;
                        headSz  = refSz - refSz*(fac-1)*distGain;
                        % move
                        headPos = pos.*obj.scrInfo.resolution./2+obj.scrInfo.center;
                    else
                        headPos = [];
                    end

                    % draw distance info
                    DrawFormattedText(wpnt,sprintf(obj.settings.string.simplePositionInstruction,avgDist),'center',fixPos(1,2)-.03*obj.scrInfo.resolution(2),255,[],[],[],1.5);
                    % draw ovals
                    obj.drawCircle(wpnt,refClr,obj.scrInfo.center,refSz,5);
                    if ~isempty(headPos)
                        obj.drawCircle(wpnt,headClr,headPos,headSz,5);
                    end
                    % draw buttons
                    Screen('FillRect',wpnt,[ 37  97 163],advancedButRect);
                    obj.drawCachedText(advancedButTextCache);
                end
                Screen('FillRect',wpnt,[  0 120   0],calibButRect);
                obj.drawCachedText(calibButTextCache);
                if qHaveValidCalibrations
                    Screen('FillRect',wpnt,[150 150   0],validateButRect);
                    obj.drawCachedText(validateButTextCache);
                end
                % draw fixation points
                obj.drawAFixPoint(wpnt,fixPos);
                
                % drawing done, show
                Screen('Flip',wpnt);
                
                
                % get user response
                [mx,my,buttons,keyCode,haveShift] = obj.getNewMouseKeyPress();
                % update cursor look if needed
                cursor.update(mx,my);
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    qIn = inRect([mx my],[advancedButRect.' calibButRect.' validateButRect.']);
                    if qIn(1)
                        status = 10;
                        break;
                    elseif qIn(2)
                        status = 1;
                        break;
                    elseif qIn(3)
                        status = -3;
                        break;
                    end
                elseif any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,'a'))
                        status = 10;
                        break;
                    elseif any(strcmpi(keys,'space'))
                        status = 1;
                        break;
                    elseif any(strcmpi(keys,'p')) && qHaveValidCalibrations
                        status = -3;
                        break;
                    elseif any(strcmpi(keys,'escape')) && haveShift
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'s')) && haveShift
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    end
                end
            end
            % clean up
            HideCursor;
        end
        
        function pTrackingStatus = getTrackingStatus(obj,pTrackingStatusS)
            [~,pTrackingStatus] = obj.iView.getTrackingStatus(pTrackingStatusS);
            if obj.caps.needsEyeFlip
                % swap eyes
                temp = pTrackingStatus.leftEye;
                pTrackingStatus. leftEye = pTrackingStatus.rightEye;
                pTrackingStatus.rightEye = temp;
                % invert left and right (its a [-1 1] range, so
                % negate. Also invert position rating
                fs = {'leftEye','rightEye','total'};
                for f=1:length(fs)
                    pTrackingStatus.(fs{f}).relativePositionX = -pTrackingStatus.(fs{f}).relativePositionX;
                    pTrackingStatus.(fs{f}).positionRatingX   = -pTrackingStatus.(fs{f}).positionRatingX;
                end
            end
        end
        
        function [sample,ret] = getSample(obj,varargin)
            [ret,sample] = obj.iView.getSample(varargin{:});
            if obj.needsCheckAveraging && ~isnan(nan) && ~isnan(nan) % check have data from both eyes. also check this is not a monocular recording... (can we?)
                qSame = sample.leftEye.gazeX==sample.rightEye.gazeX && sample.leftEye.gazeY==sample.rightEye.gazeY;
                if obj.settings.doAverageEyes~=qSame
                    if obj.settings.doAverageEyes
                        error('SMITE: You specified in settings.doAverageEyes that tracker output should be the average of the two eyes, but it is not. Switch on averaging in iViewX')
                    else
                        error('SMITE: You specified in settings.doAverageEyes that tracker output should not be the average of the two eyes, but it is. Switch off averaging in iViewX')
                    end
                end
                obj.needsCheckAveraging = false;    % check done, no need to repeat
            end
            if obj.caps.needsEyeFlip
                % swap eyes
                temp = sample.leftEye;
                sample. leftEye = sample.rightEye;
                sample.rightEye = temp;
            end
        end
        
        
        function status = showHeadPositioningAdvanced(obj,wpnt,out)
            % see if we already have valid calibrations
            qHaveValidCalibrations = false;
            if isfield(out,'attempt')
                iValid = obj.getValidCalibrations(out.attempt);
                qHaveValidCalibrations = ~isempty(iValid);
            end
            
            % setup text
            Screen('TextFont',  wpnt, obj.settings.text.font);
            Screen('TextSize',  wpnt, obj.settings.text.size);
            Screen('TextStyle', wpnt, obj.settings.text.style);
            if obj.caps.hasHeadbox
                % setup box
                boxSize = round(500.*obj.settings.setup.headBox./obj.settings.setup.headBox(1));
                [boxCenter(1),boxCenter(2)] = RectCenter([0 0 boxSize]);
            end
            % setup eye image
            margin      = 80;
            pImageDataS = SMIStructEnum.Image;
            tex         = 0;
            count       = 0;
            ret         = 0;
            while ret~=1 && count<30
                [ret,eyeImage] = obj.iView.getEyeImage(pImageDataS);
                WaitSecs('YieldSecs',0.01);
                count = count+1;
            end
            if ret~=1
                eyeImage    = zeros(obj.settings.setup.eyeImageSize(1),obj.settings.setup.eyeImageSize(2),'uint8');
            end
            tex         = obj.UploadImage(tex,wpnt,eyeImage);
            eyeImageRect= [0 0 size(eyeImage,2) size(eyeImage,1)];
            
            % setup buttons
            if obj.caps.hasHeadbox
                buttonSz    = {[200 45] [320 45] [400 45]};
                buttonSz    = buttonSz(1:2+qHaveValidCalibrations);  % third button only when more than one calibration available
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution(2)*.95);
                eoButSz     = [174 buttonSz{1}(2)];
                eoButMargin = [15 20];
                eyeButClrs  = {[37  97 163],[11 122 244]};
                
                % position eye image, head box and buttons
                % center headbox and eye image on screen
                offsetV         = (obj.scrInfo.resolution(2)-boxSize(2)-margin-RectHeight(eyeImageRect))/2;
                offsetH         = (obj.scrInfo.resolution(1)-boxSize(1))/2;
                boxRect         = OffsetRect([0 0 boxSize],offsetH,offsetV);
                eyeImageRect    = OffsetRect(eyeImageRect,obj.scrInfo.center(1)-eyeImageRect(3)/2,offsetV+margin+RectHeight(boxRect));
            else
                eyeImageRect    = CenterRectOnPointd(eyeImageRect,obj.scrInfo.center(1),obj.scrInfo.center(2));
            end
            % place buttons for back to simple interface, or calibrate
            buttonWidths= cellfun(@(x) x(1),buttonSz);
            totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
            basicButRect        = OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz{1}(2)],obj.scrInfo.center(1),yposBase-buttonSz{1}(2));
            basicButTextCache   = obj.getButtonTextCache(wpnt,'basic (<i>b<i>)'          , basicButRect);
            calibButRect        = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz{2}(2)],obj.scrInfo.center(1),yposBase-buttonSz{2}(2));
            calibButTextCache   = obj.getButtonTextCache(wpnt,'calibrate (<i>spacebar<i>)',calibButRect);
            if qHaveValidCalibrations
                validateButRect         = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz{3}(2)],obj.scrInfo.center(1),yposBase-buttonSz{3}(2));
                validateButTextCache    = obj.getButtonTextCache(wpnt,'previous calibrations (<i>p<i>)',validateButRect);
            else
                validateButRect         = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            
            % place buttons for overlays in the eye image, draw text once to get cache
            if obj.caps.setShowContour
                contourButRect      = OffsetRect([0 0 eoButSz],eyeImageRect(3)+eoButMargin(1),eyeImageRect(4)-eoButSz(2));
                contourButTextCache = obj.getButtonTextCache(wpnt,'contour (<i>c<i>)',contourButRect);
            else
                contourButRect      = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            if obj.caps.setShowPupil
                pupilButRect        = OffsetRect([0 0 eoButSz],eyeImageRect(3)+eoButMargin(1),eyeImageRect(4)-eoButSz(2)*2-eoButMargin(2));
                pupilButTextCache   = obj.getButtonTextCache(wpnt,'pupil (<i>p<i>)'  ,  pupilButRect);
            else
                pupilButRect        = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            if obj.caps.setShowCR
                glintButRect        = OffsetRect([0 0 eoButSz],eyeImageRect(3)+eoButMargin(1),eyeImageRect(4)-eoButSz(2)*3-eoButMargin(2)*2);
                glintButTextCache   = obj.getButtonTextCache(wpnt,'glint (<i>g<i>)'  ,  glintButRect);
            else
                glintButRect        = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % clear what we've just drawn
            
            % setup fixation points in the corners of the screen
            fixPos = [.1 .1; .1 .9; .9 .9; .9 .1] .* repmat(obj.scrInfo.resolution(1:2),4,1);
            
            if obj.caps.hasHeadbox
                % obj.settings for eyes in headbox
                gain = 1.5;     % 1.5 is a gain to make differences larger
                sz   = 15;      % base size at reference distance
                % setup arrows + their positions
                aSize = 26;
                arrow = [
                    -0.52  -0.64
                     0.52  -0.64
                     0.52  -0.16
                     1.00  -0.16
                     0.00   0.64
                    -1.00  -0.16
                    -0.52  -0.16];
                arrowsLRUDNF = {[-arrow(:,2) arrow(:,1)],[arrow(:,2) -arrow(:,1)],arrow,-arrow,arrow,-arrow};
                arrowsLRUDNF{5}(1:2,1) = arrowsLRUDNF{5}(1:2,1)*.75;
                arrowsLRUDNF{5}( : ,2) = arrowsLRUDNF{5}( : ,2)*.6;
                arrowsLRUDNF{6}(1:2,1) = arrowsLRUDNF{6}(1:2,1)/.75;
                arrowsLRUDNF{6}( : ,2) = arrowsLRUDNF{6}( : ,2)*.6;
                arrowsLRUDNF = cellfun(@(x) round(x.*aSize),arrowsLRUDNF,'uni',false);
                % positions relative to boxRect. add position to arrowsLRDUNF to get
                % position of vertices in boxRect;
                margin = 4;
                arrowPos = cell(1,6);
                arrowPos{1} = [boxSize(1)-margin-max(arrowsLRUDNF{1}(:,1)) boxCenter(2)];
                arrowPos{2} = [           margin-min(arrowsLRUDNF{2}(:,1)) boxCenter(2)];
                % down is special as need space underneath for near and far arrows
                arrowPos{3} = [boxCenter(1)            margin-min(arrowsLRUDNF{3}(:,2))];
                arrowPos{4} = [boxCenter(1) boxSize(2)-margin-max(arrowsLRUDNF{4}(:,2))-max(arrowsLRUDNF{5}(:,2))+min(arrowsLRUDNF{5}(:,2))];
                arrowPos{5} = [boxCenter(1) boxSize(2)-margin-max(arrowsLRUDNF{5}(:,2))];
                arrowPos{6} = [boxCenter(1) boxSize(2)-margin-max(arrowsLRUDNF{6}(:,2))];
                % setup arrow colors and thresholds
                col1 = [255 255 0]; % color for arrow when just visible, exceeding first threshold
                col2 = [255 155 0]; % color for arrow when just visible, jhust before exceeding second threshold
                col3 = [255 0   0]; % color for arrow when extreme, exceeding second threshold
                xThresh = [0 .68];
                yThresh = [0 .8];
                zThresh = [0 .8];
            end
            
            % setup cursors
            cursors.rect    = {basicButRect.' calibButRect.' validateButRect.' contourButRect.' pupilButRect.' glintButRect.'};
            cursors.cursor  = [2 2 2 2 2 2];    % Hand
            cursors.other   = 0;                % Arrow
            if ~obj.settings.debugMode          % for cleanup
                cursors.reset = -1;             % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor          = cursorUpdater(cursors);
            
            
            % get tracking status and visualize along with eye image
            if obj.caps.hasHeadbox
                arrowColor      = zeros(3,6);
                pTrackingStatusS= SMIStructEnum.TrackingStatus;
                pSampleS        = SMIStructEnum.Sample;
                relPos          = zeros(3);
            end
            % for overlays in eye image. disable them all initially
            if obj.caps.setShowContour
                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',0);
            end
            if obj.caps.setShowPupil
                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL',0);
            end
            if obj.caps.setShowCR
                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX',0);
            end
            overlays        = false(3);
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            while true
                if obj.caps.hasHeadbox
                    % get tracking status info
                    pTrackingStatus = obj.getTrackingStatus(pTrackingStatusS);  % for position in headbox
                    pSample         = obj.getSample(pSampleS);                  % for distance

                    % get average eye distance. use distance from one eye if only one eye
                    % available
                    distL   = pSample.leftEye .eyePositionZ/10;
                    distR   = pSample.rightEye.eyePositionZ/10;
                    dists   = [distL distR];
                    avgDist = mean(dists(~isnan(dists)));
                    % if missing, estimate where eye would be in depth if user kept head
                    % yaw constant
                    if isnan(distL)
                        distL = distR-relPos(3);
                    elseif isnan(distR)
                        distR = distL+relPos(3);
                    end

                    % see which arrows to draw
                    qDrawArrow = false(1,6);
                    if abs(pTrackingStatus.total.positionRatingX)>xThresh(1)
                        idx = 1 + (pTrackingStatus.total.positionRatingX<0);  % if too far on the left, arrow should point to the right, etc below
                        qDrawArrow(idx) = true;
                        arrowColor(:,idx) = obj.getArrowColor(pTrackingStatus.total.positionRatingX,xThresh,col1,col2,col3);
                    end
                    if abs(pTrackingStatus.total.positionRatingY)>yThresh(1)
                        idx = 3 + (pTrackingStatus.total.positionRatingY<0);
                        qDrawArrow(idx) = true;
                        arrowColor(:,idx) = obj.getArrowColor(pTrackingStatus.total.positionRatingY,yThresh,col1,col2,col3);
                    end
                    if abs(pTrackingStatus.total.positionRatingZ)>zThresh(1)
                        idx = 5 + (pTrackingStatus.total.positionRatingZ>0);
                        qDrawArrow(idx) = true;
                        arrowColor(:,idx) = obj.getArrowColor(pTrackingStatus.total.positionRatingZ,zThresh,col1,col2,col3);
                    end
                end
                % get eye image
                [ret,eyeImage] = obj.iView.getEyeImage(pImageDataS);
                if ret==1
                    % clean up old one, if any
                    tex = obj.UploadImage(tex,wpnt,eyeImage);
                end
                
                % do drawing
                if obj.caps.hasHeadbox
                    % draw box
                    Screen('FillRect', wpnt, 80, boxRect);
                    % draw distance
                    if ~isnan(avgDist)
                        Screen('TextSize', wpnt, 10);
                        Screen('DrawText', wpnt, sprintf('%.0f cm',avgDist), boxRect(3)-40,boxRect(4)-16,255);
                    end
                    % draw eyes in box
                    Screen('TextSize', wpnt, obj.settings.text.size);
                    % scale up size of oval. define size/rect at standard distance (60cm),
                    % have a gain for how much to scale as distance changes
                    if pTrackingStatus.leftEye.validity || pTrackingStatus.rightEye.validity
                        posL = [pTrackingStatus.leftEye .relativePositionX -pTrackingStatus.leftEye .relativePositionY]/2+.5;  %-Y as +1 is upper and -1 is lower edge. needs to be reflected for screen drawing
                        posR = [pTrackingStatus.rightEye.relativePositionX -pTrackingStatus.rightEye.relativePositionY]/2+.5;
                        % determine size of eye. based on distance to standard distance of
                        % 60cm, calculate size change
                        fac  = obj.settings.setup.viewingDist/avgDist;
                        facL = obj.settings.setup.viewingDist/distL;
                        facR = obj.settings.setup.viewingDist/distR;
                        % left eye
                        style = Screen('TextStyle', wpnt, 1);
                        obj.drawEye(wpnt,pTrackingStatus.leftEye .validity,posL,posR, relPos*fac,[255 120 120],[220 186 186],round(sz*facL*gain),'L',boxRect);
                        % right eye
                        obj.drawEye(wpnt,pTrackingStatus.rightEye.validity,posR,posL,-relPos*fac,[120 255 120],[186 220 186],round(sz*facR*gain),'R',boxRect);
                        Screen('TextStyle', wpnt, style);
                        % update relative eye positions - used for drawing estimated
                        % position of missing eye. X and Y are relative position in
                        % headbox, Z is difference in measured eye depths
                        if pTrackingStatus.leftEye.validity && pTrackingStatus.rightEye.validity
                            relPos = [(posR-posL)/fac min(max(distR-distL,-8),8)];   % keep a distance normalized to eye-tracker distance of 60 cm, so we can scale eye distance with subject's distance from tracker correctly
                        end
                        % draw center
                        if 0 && pTrackingStatus.total.validity
                            pos = [pTrackingStatus.total.relativePositionX -pTrackingStatus.total.relativePositionY]/2+.5;
                            pos = pos.*[diff(boxRect([1 3])) diff(boxRect([2 4]))]+boxRect(1:2);
                            Screen('gluDisk',wpnt,[0 0 255],pos(1),pos(2),10)
                        end
                    end
                    % draw arrows
                    for p=find(qDrawArrow)
                        Screen('FillPoly', wpnt, arrowColor(:,p), bsxfun(@plus,arrowsLRUDNF{p},arrowPos{p}+boxRect(1:2)) ,0);
                    end
                end
                % draw eye image, if any
                if tex
                    Screen('DrawTexture', wpnt, tex,[],eyeImageRect);
                end
                % draw buttons
                Screen('FillRect',wpnt,[37  97 163],basicButRect);
                obj.drawCachedText(basicButTextCache);
                Screen('FillRect',wpnt,[ 0 120   0],calibButRect);
                obj.drawCachedText(calibButTextCache);
                if qHaveValidCalibrations
                    Screen('FillRect',wpnt,[150 150   0],validateButRect);
                    obj.drawCachedText(validateButTextCache);
                end
                if obj.caps.setShowContour
                    Screen('FillRect',wpnt,eyeButClrs{overlays(1)+1},contourButRect);
                    obj.drawCachedText(contourButTextCache);
                end
                if obj.caps.setShowPupil
                    Screen('FillRect',wpnt,eyeButClrs{overlays(2)+1},pupilButRect);
                    obj.drawCachedText(pupilButTextCache);
                end
                if obj.caps.setShowCR
                    Screen('FillRect',wpnt,eyeButClrs{overlays(3)+1},glintButRect);
                    obj.drawCachedText(glintButTextCache);
                end
                % draw fixation points
                obj.drawAFixPoint(wpnt,fixPos);
                
                % drawing done, show
                Screen('Flip',wpnt);
                
                % get user response
                [mx,my,buttons,keyCode,haveShift] = obj.getNewMouseKeyPress();
                % update cursor look if needed
                cursor.update(mx,my);
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    qIn = inRect([mx my],[basicButRect.' calibButRect.' validateButRect.' contourButRect.' pupilButRect.' glintButRect.']);
                    if any(qIn)
                        if qIn(1)
                            status = 5;
                            break;
                        elseif qIn(2)
                            status = 1;
                            break;
                        elseif qIn(3)
                            status = -3;
                            break;
                        elseif qIn(4)
                            overlays(1) = ~overlays(1);
                            obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',overlays(1));
                        elseif qIn(5)
                            overlays(2) = ~overlays(2);
                            obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL',overlays(2));
                        elseif qIn(6)
                            overlays(3) = ~overlays(3);
                            obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX',overlays(3));
                        end
                    end
                elseif any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,'b'))
                        status = 5;
                        break;
                    elseif any(strcmpi(keys,'space'))
                        status = 1;
                        break;
                    elseif any(strcmpi(keys,'p')) && qHaveValidCalibrations
                        status = -3;
                        break;
                    elseif any(strcmpi(keys,'escape')) && haveShift
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'s')) && haveShift
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    elseif any(strcmpi(keys,'c')) && obj.caps.setShowContour
                        overlays(1) = ~overlays(1);
                        obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',overlays(1));
                    elseif any(strcmpi(keys,'p')) && obj.caps.setShowPupil
                        overlays(2) = ~overlays(2);
                        obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL',overlays(2));
                    elseif any(strcmpi(keys,'g')) && obj.caps.setShowCR
                        overlays(3) = ~overlays(3);
                        obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX',overlays(3));
                    end
                end
            end
            % clean up
            if tex
                Screen('Close',tex);
            end
            % just to be safe, disable these overlays
            if obj.caps.setShowContour
                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',0);
            end
            if obj.caps.setShowPupil
                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL'  ,0);
            end
            if obj.caps.setShowCR
                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX' ,0);
            end
            HideCursor;
        end
        
        function tex = UploadImage(obj,tex,wpnt,image)
            if tex
                Screen('Close',tex);
            end
            if obj.caps.needsEyeFlip
                image = fliplr(image);
            end
            tex = Screen('MakeTexture',wpnt,image,[],8);   % 8 to prevent mipmap generation, we don't need it
        end
        
        function drawCircle(~,wpnt,refClr,center,refSz,lineWidth)
            nStep = 200;
            alpha = linspace(0,2*pi,nStep);
            alpha = [alpha(1:end-1); alpha(2:end)]; alpha = alpha(:).';
            xy = refSz.*[cos(alpha); sin(alpha)];
            Screen('DrawLines', wpnt, xy, lineWidth ,refClr ,center,2);
        end
        
        function cache = getButtonTextCache(obj,wpnt,lbl,rect)
            if obj.usingFTGLTextRenderer
                [sx,sy] = RectCenterd(rect);
                [~,~,~,cache] = DrawFormattedText2(lbl,'win',wpnt,'sx',sx,'xalign','center','sy',sy,'yalign','center','baseColor',0,'cacheOnly',true);
            else
                [~,~,~,cache] = DrawMonospacedText(wpnt,lbl,'center','center',0,[],[],[],OffsetRect(rect,0,obj.settings.text.lineCentOff),true);
            end
        end
        
        function drawCachedText(obj,cache)
            if obj.usingFTGLTextRenderer
                DrawFormattedText2(cache);
            else
                DrawMonospacedText(cache);
            end
        end
        
        function arrowColor = getArrowColor(~,posRating,thresh,col1,col2,col3)
            if abs(posRating)>thresh(2)
                arrowColor = col3;
            else
                arrowColor = col1+(abs(posRating)-thresh(1))./diff(thresh)*(col2-col1);
            end
        end
        
        function drawEye(~,wpnt,validity,pos,posOther,relPos,clr1,clr2,sz,lbl,boxRect)
            if validity
                clr = clr1;
            else
                clr = clr2;
                if any(relPos)
                    pos = posOther-relPos(1:2);
                else
                    return
                end
            end
            pos = pos.*[diff(boxRect([1 3])) diff(boxRect([2 4]))]+boxRect(1:2);
            Screen('gluDisk',wpnt,clr,pos(1),pos(2),sz)
            if validity
                bbox = Screen('TextBounds',wpnt,lbl);
                pos  = round(pos-bbox(3:4)/2);
                Screen('DrawText',wpnt,lbl,pos(1),pos(2),0);
            end
        end
        
        function drawAFixPoint(obj,wpnt,pos)
            % draws Thaler et al. 2012's ABC fixation point
            sz = [obj.settings.cal.fixBackSize obj.settings.cal.fixFrontSize];
            
            % draw
            for p=1:size(pos,1)
                rectH = CenterRectOnPointd([0 0        sz ], pos(p,1), pos(p,2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(p,1), pos(p,2));
                Screen('gluDisk', wpnt,obj.settings.cal. fixBackColor, pos(p,1), pos(p,2), sz(1)/2);
                Screen('FillRect',wpnt,obj.settings.cal.fixFrontColor, rectH);
                Screen('FillRect',wpnt,obj.settings.cal.fixFrontColor, rectV);
                Screen('gluDisk', wpnt,obj.settings.cal. fixBackColor, pos(p,1), pos(p,2), sz(2)/2);
            end
        end
        
        function [status,out] = DoCalAndVal(obj,wpnt,qClearBuffer)
            % make sure calibration settings are correct (they may have
            % been changed below before a previous validation)
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % NB: this sets the background color, because fullscreen fillrect sets new clear color in PTB
            % SMI calibration setup
            CalibrationData = SMIStructEnum.Calibration;
            CalibrationData.method               = obj.settings.cal.nPoint;
            CalibrationData.autoAccept           = int32(obj.settings.cal.autoPace);
            % Setup calibration look. Necessary in all cases so that
            % validate image looks similar to calibration stimuli
            CalibrationData.foregroundBrightness = obj.settings.cal.fixBackColor(1);
            CalibrationData.backgroundBrightness = obj.settings.cal.bgColor(1);
            CalibrationData.targetSize           = max(10,round(obj.settings.cal.fixBackSize/2));   % 10 is the minimum size. Ignored for validation image...
            ret = obj.iView.setupCalibration(CalibrationData);
            obj.processError(ret,'SMITE: Error setting up calibration');
            
            % calibrate
            obj.startRecording(qClearBuffer);
            % enter calibration mode
            obj.sendMessage('CALIBRATION START');
            obj.iView.calibrate();
            % show display
            [status,out.cal,tick] = obj.DoCalPointDisplay(wpnt,-1,true);
            obj.sendMessage('CALIBRATION END');
            if status~=1
                if status~=-1
                    % -1 means restart calibration from start. if we do not
                    % clean up here, we e.g. get a nice animation of the
                    % point back to the center of the screen, or however
                    % the user wants to indicate change of point. Clean up
                    % in all other cases, or we would maintain drawstate
                    % accross setup screens and such.
                    % So, send cleanup message to user function (if any)
                    if isa(obj.settings.cal.drawFunction,'function_handle')
                        obj.settings.cal.drawFunction(nan);
                    end
                end
                return;
            end
            
            % now change calibration setup if needed
            % if we're in semi-automatic pacing mode, for the RED NG
            % trackers, behaviour has changed. With these, you have to
            % manually accept the first validation point (this is not the
            % case for any older tracker). We don't want that, so fix it by
            % changing the mode to fully autoaccept before entering
            % validation, in case the current mode is semi-automatic
            if obj.settings.cal.autoPace==1
                % set background color
                Screen('FillRect', wpnt, obj.settings.cal.bgColor); % NB: fullscreen fillrect sets new clear color in PTB
                % SMI calibration setup
                CalibrationData = SMIStructEnum.Calibration;
                CalibrationData.method               = obj.settings.cal.nPoint;
                CalibrationData.autoAccept           = int32(2);
                CalibrationData.foregroundBrightness = obj.settings.cal.fixBackColor(1);
                CalibrationData.backgroundBrightness = obj.settings.cal.bgColor(1);
                CalibrationData.targetSize           = max(10,round(obj.settings.cal.fixBackSize/2));   % 10 is the minimum size. Ignored for validation image...
                ret = obj.iView.setupCalibration(CalibrationData);
                obj.processError(ret,'SMITE: Error setting up calibration');
            end
            
            % validate
            % enter validation mode
            obj.sendMessage('VALIDATION START');
            obj.iView.validate();
            % show display
            [status,out.val] = obj.DoCalPointDisplay(wpnt,tick,false,out.cal.flips(end));
            obj.sendMessage('VALIDATION END');
            obj.stopRecording();
            
            if status~=-1   % see comment above about why not when -1
                % cleanup message to user function (if any)
                if isa(obj.settings.cal.drawFunction,'function_handle')
                    obj.settings.cal.drawFunction(nan);
                end
            end
            
            % clear flip
            Screen('Flip',wpnt);
        end
        
        function [status,out,tick] = DoCalPointDisplay(obj,wpnt,tick,qCal,lastFlip)
            % status output:
            %  1: finished succesfully (you should query SMI software whether they think
            %     calibration was succesful though)
            %  2: skip calibration and continue with task (shift+s)
            % -1: restart calibration (r)
            % -2: abort calibration and go back to setup (escape key)
            % -4: Exit completely (control+escape)
            qFirst = nargin<5;
            
            % clear screen, anchor timing, get ready for displaying calibration points
            if qFirst
                out.flips = Screen('Flip',wpnt);
            else
                out.flips = lastFlip;
            end
            out.pointPos = [];
            
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            
            pCalibrationPoint = SMIStructEnum.CalibrationPoint;
            currentPoint    = -1;
            haveAccepted    = true;     % indicates if we are waiting for a space bar press (if not, either because automatic accept or because already pressed for current point)
            needManualAccept= @(cp) obj.settings.cal.autoPace==0 || (obj.settings.cal.autoPace==1 && qCal && cp==1);
            acceptCount     = 0;
            acceptInterval  = ceil(.4*Screen('NominalFrameRate',wpnt)); % 400 ms intervals
            while true
                tick        = tick+1;
                nextFlipT   = out.flips(end)+1/1000;
                ret         = obj.iView.getCurrentCalibrationPoint(pCalibrationPoint);
                if ret==2   % RET_NO_VALID_DATA
                    % calibration/validation finished
                    if ~qFirst
                        Screen('Flip',wpnt);    % clear
                        obj.sendMessage(sprintf('POINT OFF %d',currentPoint));
                    end
                    status = 1;
                    break;
                end
                qNewPoint = pCalibrationPoint.number~=currentPoint;
                if haveAccepted
                    % space bar already pressed, or not needed for current
                    % point.
                    if qNewPoint
                        currentPoint = pCalibrationPoint.number;
                        pos = [pCalibrationPoint.positionX pCalibrationPoint.positionY];
                        out.pointPos(end+1,1:3) = [currentPoint pos];
                        % check if manual acceptance needed for this point
                        if needManualAccept(currentPoint)
                            % all manual
                            haveAccepted = false;
                        else
                            % all automatic
                            haveAccepted = true;
                        end
                        acceptCount = 0;
                    elseif needManualAccept(currentPoint)
                        % send accept calibration point. Do it periodically
                        % as it seems sometimes even though the point was
                        % accepted, code does not move on. At all. So call
                        % accept again at hardcoded intervals set above, as
                        % counted by screen refreshes
                        acceptCount = acceptCount+1;
                        if mod(acceptCount,acceptInterval)==0
                            obj.iView.acceptCalibrationPoint();
                        end
                    end
                end
                
                % call drawer function
                if isempty(obj.settings.cal.drawFunction)
                    qAllowAcceptKey = obj.drawFixationPoint(wpnt,currentPoint,pos,tick);
                else
                    qAllowAcceptKey = obj.settings.cal.drawFunction(wpnt,currentPoint,pos,tick);
                end
                
                out.flips(end+1) = Screen('Flip',wpnt,nextFlipT);
                if qNewPoint
                    obj.sendMessage(sprintf('POINT ON %d (%d %d)',currentPoint,pos));
                end
                
                % get user response
                [~,~,~,keyCode,haveShift] = obj.getNewMouseKeyPress();
                if any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,'space')) && qAllowAcceptKey && ~haveAccepted
                        % if in semi-automatic and first point, or if
                        % manual and any point, space bars triggers
                        % accepting calibration point
                        % we do this on a timer to make sure eye-trackers
                        % older than NG ones have enough samples recorded
                        % before continuing. This appears to be needed as
                        % accept works on these older machines as long as
                        % there are any valid samples recorded.
                        haveAccepted    = true;
                    elseif any(strcmpi(keys,'r'))
                        status = -1;
                        break;
                    elseif any(strcmpi(keys,'escape'))
                        obj.iView.abortCalibration();
                        if any(strcmpi(keys,'shift'))
                            status = -4;
                        else
                            status = -2;
                        end
                        break;
                    elseif any(strcmpi(keys,'s')) && haveShift
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    end
                end
            end
        end
        
        function qAllowAcceptKey = drawFixationPoint(obj,wpnt,~,pos,~)
            obj.drawAFixPoint(wpnt,pos);
            qAllowAcceptKey = true;
        end
        
        function [status,selection] = showValidationResult(obj,wpnt,cal,kCal)
            % status output:
            %  1: calibration/validation accepted, continue (a)
            %  2: just continue with task (shift+s)
            % -1: restart calibration (escape key)
            % -2: go back to setup (s)
            % -4: Exit completely (control+escape)
            %
            % additional buttons
            % c: chose other calibration (if have more than one valid)
            % g: show gaze (and fixation points)
            
            % find how many valid calibrations we have:
            selection = kCal;
            iValid = obj.getValidCalibrations(cal);
            if ~ismember(selection,iValid)
                % this happens if setup cancelled to go directly to this validation
                % viewer
                selection = iValid(end);
            end
            qHaveMultipleValidCals = ~isscalar(iValid);
            % detect if average eyes
            qAveragedEyes = cal{selection}.validateAccuracy.deviationLX==cal{selection}.validateAccuracy.deviationRX && cal{selection}.validateAccuracy.deviationLY==cal{selection}.validateAccuracy.deviationRY;
            
            % setup buttons
            % 1. below screen
            yposBase    = round(obj.scrInfo.resolution(2)*.95);
            buttonSz    = {[300 45] [300 45] [350 45]};
            buttonSz    = buttonSz(1:2+qHaveMultipleValidCals);  % third button only when more than one calibration available
            buttonOff   = 80;
            buttonWidths= cellfun(@(x) x(1),buttonSz);
            totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
            recalButRect        = OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz{1}(2)],obj.scrInfo.center(1),yposBase-buttonSz{2}(2));
            recalButTextCache   = obj.getButtonTextCache(wpnt,'recalibrate (<i>esc<i>)'  ,    recalButRect);
            continueButRect     = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz{2}(2)],obj.scrInfo.center(1),yposBase-buttonSz{1}(2));
            continueButTextCache= obj.getButtonTextCache(wpnt,'continue (<i>spacebar<i>)', continueButRect);
            if qHaveMultipleValidCals
                selectButRect       = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz{3}(2)],obj.scrInfo.center(1),yposBase-buttonSz{3}(2));
                selectButTextCache  = obj.getButtonTextCache(wpnt,'select other cal (<i>c<i>)', selectButRect);
            else
                selectButRect = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            % 2. atop screen
            topMargin           = 50;
            buttonSz            = {[200 45] [250 45]};
            buttonOff           = 550;
            showGazeButClrs     = {[37  97 163],[11 122 244]};
            setupButRect        = OffsetRect([0 0 buttonSz{1}],obj.scrInfo.center(1)-buttonOff/2-buttonSz{1}(1),topMargin+buttonSz{1}(2));
            setupButTextCache   = obj.getButtonTextCache(wpnt,'setup (<i>s<i>)'    ,   setupButRect);
            showGazeButRect     = OffsetRect([0 0 buttonSz{2}],obj.scrInfo.center(1)+buttonOff/2               ,topMargin+buttonSz{1}(2));
            showGazeButTextCache= obj.getButtonTextCache(wpnt,'show gaze (<i>g<i>)',showGazeButRect);
            
            % setup menu, if any
            if qHaveMultipleValidCals
                margin      = 10;
                pad         = 3;
                height      = 45;
                nElem       = length(iValid);
                totHeight   = nElem*(height+pad)-pad;
                width       = 700;
                % menu background
                menuBackRect= [-.5*width+obj.scrInfo.center(1)-margin -.5*totHeight+obj.scrInfo.center(2)-margin .5*width+obj.scrInfo.center(1)+margin .5*totHeight+obj.scrInfo.center(2)+margin];
                % menuRects
                menuRects = repmat([-.5*width+obj.scrInfo.center(1) -height/2+obj.scrInfo.center(2) .5*width+obj.scrInfo.center(1) height/2+obj.scrInfo.center(2)],length(iValid),1);
                menuRects = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]);
                % text in each rect
                for c=1:length(iValid)
                    if qAveragedEyes
                        str = sprintf('(%d): <color=ff0000>Average<color>: (%.2f°,%.2f°)',c,cal{iValid(c)}.validateAccuracy.deviationLX,cal{iValid(c)}.validateAccuracy.deviationLY);
                    else
                        str = sprintf('(%d): <color=ff0000>Left<color>: (%.2f°,%.2f°), <color=00ff00>Right<color>: (%.2f°,%.2f°)',c,cal{iValid(c)}.validateAccuracy.deviationLX,cal{iValid(c)}.validateAccuracy.deviationLY,cal{iValid(c)}.validateAccuracy.deviationRX,cal{iValid(c)}.validateAccuracy.deviationRY);
                    end
                    menuTextCache(c) = obj.getButtonTextCache(wpnt,str,menuRects(c,:)); %#ok<AGROW>
                end
            end
            
            % setup fixation points in the corners of the screen
            fixPos = [.1 .1; .1 .9; .9 .9; .9 .1] .* repmat(obj.scrInfo.resolution(1:2),4,1);
            
            qDoneCalibSelection = false;
            qSelectMenuOpen     = false;
            qShowGaze           = false;
            tex                 = 0;
            pSampleS            = SMIStructEnum.Sample;
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            while ~qDoneCalibSelection
                % draw validation screen image
                if tex~=0
                    Screen('Close',tex);
                end
                tex   = Screen('MakeTexture',wpnt,cal{selection}.validateImage,[],8);   % 8 to prevent mipmap generation, we don't need it
                
                % setup cursors
                if qSelectMenuOpen
                    cursors.rect    = {menuRects.',continueButRect.',recalButRect.'};
                    cursors.cursor  = 2*ones(1,size(menuRects,1)+2);    % 2: Hand
                else
                    cursors.rect    = {continueButRect.',recalButRect.',selectButRect.',setupButRect.',showGazeButRect.'};
                    cursors.cursor  = [2 2 2 2 2];  % 2: Hand
                end
                cursors.other   = 0;    % 0: Arrow
                cursors.qReset  = false;
                % NB: don't reset cursor to invisible here as it will then flicker every
                % time you click something. default behaviour is good here
                cursor = cursorUpdater(cursors);
                
                while true % draw loop
                    Screen('DrawTexture', wpnt, tex);   % its a fullscreen image, so just draw
                    % setup text
                    Screen('TextFont',  wpnt, obj.settings.text.font);
                    Screen('TextSize',  wpnt, obj.settings.text.size);
                    Screen('TextStyle', wpnt, obj.settings.text.style);
                    % draw text with validation accuracy info
                    if qAveragedEyes
                        valText = sprintf('<font=Consolas><size=20>accuracy   X       Y\n<color=0000ff>Average<color>: %2.2f°  %2.2f°',cal{selection}.validateAccuracy.deviationLX,cal{selection}.validateAccuracy.deviationLY);
                    else
                        valText = sprintf('<font=Consolas><size=20>accuracy   X       Y\n   <color=ff0000>Left<color>: %2.2f°  %2.2f°\n  <color=00ff00>Right<color>: %2.2f°  %2.2f°',cal{selection}.validateAccuracy.deviationLX,cal{selection}.validateAccuracy.deviationLY,cal{selection}.validateAccuracy.deviationRX,cal{selection}.validateAccuracy.deviationRY);
                    end
                    if obj.usingFTGLTextRenderer
                        DrawFormattedText2(valText,'win',wpnt,'sx','center','xalign','center','sy',100,'baseColor',255,'vSpacing',obj.settings.text.vSpacing);
                    else
                        DrawMonospacedText(wpnt,valText,'center',100,255,[],obj.settings.text.vSpacing);
                    end
                    % draw buttons
                    Screen('FillRect',wpnt,[150 0 0],recalButRect);
                    obj.drawCachedText(recalButTextCache);
                    Screen('FillRect',wpnt,[0 120 0],continueButRect);
                    obj.drawCachedText(continueButTextCache);
                    if qHaveMultipleValidCals
                        Screen('FillRect',wpnt,[150 150 0],selectButRect);
                        obj.drawCachedText(selectButTextCache);
                    end
                    Screen('FillRect',wpnt,[150 0 0],setupButRect);
                    obj.drawCachedText(setupButTextCache);
                    Screen('FillRect',wpnt,showGazeButClrs{qShowGaze+1},showGazeButRect);
                    obj.drawCachedText(showGazeButTextCache);
                    % if selection menu open, draw on top
                    if qSelectMenuOpen
                        % menu background
                        Screen('FillRect',wpnt,140,menuBackRect);
                        % menuRects
                        Screen('FillRect',wpnt,110,menuRects.');
                        % text in each rect
                        for c=1:length(iValid)
                            obj.drawCachedText(menuTextCache(c));
                        end
                    end
                    % if showing gaze, draw
                    if qShowGaze
                        [pSample,ret] = obj.getSample(pSampleS);
                        if ret==1
                            % draw
                            if qAveragedEyes
                                if ~(pSample.leftEye .gazeX==0 && pSample.leftEye .gazeY==0)
                                    Screen('gluDisk', wpnt,[255 0 0], pSample. leftEye.gazeX, pSample. leftEye.gazeY, 10);
                                end
                            else
                                if ~(pSample.leftEye .gazeX==0 && pSample.leftEye .gazeY==0)
                                    Screen('gluDisk', wpnt,[255 0 0], pSample. leftEye.gazeX, pSample. leftEye.gazeY, 10);
                                end
                                if ~(pSample.rightEye.gazeX==0 && pSample.rightEye.gazeY==0)
                                    Screen('gluDisk', wpnt,[0 255 0], pSample.rightEye.gazeX, pSample.rightEye.gazeY, 10);
                                end
                            end
                        end
                        % draw fixation points
                        obj.drawAFixPoint(wpnt,fixPos);
                    end
                    % drawing done, show
                    Screen('Flip',wpnt);
                    
                    % get user response
                    [mx,my,buttons,keyCode,haveShift] = obj.getNewMouseKeyPress();
                    % update cursor look if needed
                    cursor.update(mx,my);
                    if any(buttons)
                        % don't care which button for now. determine if clicked on either
                        % of the buttons
                        if qSelectMenuOpen
                            iIn = find(inRect([mx my],[menuRects.' menuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                            if ~isempty(iIn) && iIn<=length(iValid)
                                selection = iValid(iIn);
                                obj.loadOtherCal(selection);
                                qSelectMenuOpen = false;
                                break;
                            else
                                qSelectMenuOpen = false;
                                break;
                            end
                        end
                        if ~qSelectMenuOpen     % if pressed outside the menu, check if pressed any of these menu buttons
                            qIn = inRect([mx my],[continueButRect.' recalButRect.' selectButRect.' setupButRect.' showGazeButRect.']);
                            if any(qIn)
                                if qIn(1)
                                    status = 1;
                                    qDoneCalibSelection = true;
                                elseif qIn(2)
                                    status = -1;
                                    qDoneCalibSelection = true;
                                elseif qIn(3)
                                    qSelectMenuOpen     = true;
                                elseif qIn(4)
                                    status = -2;
                                    qDoneCalibSelection = true;
                                elseif qIn(5)
                                    qShowGaze           = ~qShowGaze;
                                end
                                break;
                            end
                        end
                    elseif any(keyCode)
                        keys = KbName(keyCode);
                        if qSelectMenuOpen
                            if any(strcmpi(keys,'escape'))
                                qSelectMenuOpen = false;
                                break;
                            elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                                idx = str2double(keys(1));
                                selection = iValid(idx);
                                obj.loadOtherCal(selection);
                                qSelectMenuOpen = false;
                                break;
                            end
                        else
                            if any(strcmpi(keys,'space'))
                                status = 1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'escape')) && ~haveShift
                                status = -1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'s')) && ~haveShift
                                status = -2;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'c')) && qHaveMultipleValidCals
                                qSelectMenuOpen     = ~qSelectMenuOpen;
                                break;
                            elseif any(strcmpi(keys,'g'))
                                qShowGaze           = ~qShowGaze;
                                break;
                            end
                        end
                        
                        % these two key combinations should always be available
                        if any(strcmpi(keys,'escape')) && haveShift
                            status = -4;
                            qDoneCalibSelection = true;
                            break;
                        elseif any(strcmpi(keys,'s')) && haveShift
                            % skip calibration
                            obj.iView.abortCalibration();
                            status = 2;
                            qDoneCalibSelection = true;
                            break;
                        end
                    end
                end
            end
            % done, clean up
            cursor.reset();
            Screen('Close',tex);
            if status~=1
                selection = NaN;
            end
            HideCursor;
        end
        
        function loadOtherCal(obj,which)
            obj.iView.loadCalibration(num2str(which));
            % check correct one is loaded -- well, apparently below function returns
            % last calibration's accuracy, not loaded calibration. So we can't check
            % this way..... I have verified that loading works on the RED-m.
            % [~,validateAccuracy] = obj.iView.getAccuracy([], 0);
            % assert(isequal(validateAccuracy,out.attempt{selection}.validateAccuracy),'failed to load selected calibration');
        end
        
        function iValid = getValidCalibrations(~,cal)
            iValid = find(cellfun(@(x) isfield(x,'calStatusSMI') && strcmp(x.calStatusSMI,'calibrationValid'),cal));
        end
        
        function out = isTwoComputerSetup(obj)
            out = length(obj.settings.connectInfo)==4 && ~strcmp(obj.settings.connectInfo{1},obj.settings.connectInfo{3});
        end
        
        function [mx,my,mouse,key,haveShift] = getNewMouseKeyPress(obj)
            % function that only returns key depress state changes in the
            % down direction, not keys that are held down or anything else
            % NB: before using this, make sure internal state is up to
            % date!
            [~,~,keyCode]   = KbCheck();
            [mx,my,buttons] = GetMouse();
            
            % get only fresh mouse and key presses (so change from state
            % "up" to state "down")
            key     = keyCode & ~obj.keyState;
            mouse   = buttons & ~obj.mouseState;
            
            % get if shift key is currently down
            haveShift = ~~keyCode(obj.shiftKey);
            
            % store to state
            obj.keyState    = keyCode;
            obj.mouseState  = buttons;
        end
    end
end