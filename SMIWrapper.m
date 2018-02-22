classdef SMIWrapper < handle
    properties (Access = protected, Hidden = true)
        % state
        iView;
        debugLevel      = 0;
        isInitialized   = false;
        
        % obj.settings and external info
        settings;
        scrInfo;
        
        % eye-tracker info
        caps;           % will be populated with info about capabilities of the connected eye-tracker
        systemInfo;
        geom;
    end
    
    % computed properties (so not actual properties)
    properties (Dependent, SetAccess = private)
        raw;            % get naked obj.iViewXAPI instance
        % things like sampling which machine, freq, settings?
    end
    properties (Dependent)
        options;    % subset of settings that can actually be changed. contents differ based on state of class (once inited, much less can be set)
    end
    
    methods
        function obj = SMIWrapper(settingsOrETName,scrInfo)
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
                assert(isfield(scrInfo,'resolution') && isfield(scrInfo,'center'),'scrInfo should have a ''resolution'' and a ''center'' field')
                obj.scrInfo             = scrInfo;
            end
            
            % get capabilities for the connected eye-tracker
            obj.setCapabilities();
            
            % Load in plugin (SMI dll)
            obj.iView = iViewXAPI();
        end
        
        function out = setDummyMode(obj)
            assert(nargout==1,'you must use the output argument of setDummyMode, like: SMIhandle = SMIhandle.setDummyMode(), or SMIhandle = setDummyMode(SMIhandle)')
            out = SMIWrapperDummyMode(obj);
        end
        
        function out = get.raw(obj)
            out = obj.iView;
        end
        
        function out = get.options(obj)
            if ~obj.isInitialized
                out = obj.settings;
            else
                % only the subset that can be changed "live"
                out = obj.getAllowedOptions();
            end
        end
        
        function set.options(obj,settings)
            if obj.isInitialized
                % only a subset of settings is allowed. Hardcode here, and
                % copy over if exist
                allowed = obj.getAllowedOptions();
                for p=1:size(allowed,1)
                    if isfield(settings,allowed{1}) && isfield(settings.(allowed{1}),allowed{2})
                        obj.settings.(allowed{1}).(allowed{2}) = settings.(allowed{1}).(allowed{2});
                    end
                end
            else
                % just copy it over. If user didn't remove fields from
                % settings struct, we're good. If they did, they're an
                % idiot.
                obj.settings = settings;
            end
            % setup colors
            obj.settings.cal.bgColor        = color2RGBA(obj.settings.cal.bgColor);
            obj.settings.cal.fixBackColor   = color2RGBA(obj.settings.cal.fixBackColor);
            obj.settings.cal.fixFrontColor  = color2RGBA(obj.settings.cal.fixFrontColor);
        end
        
        function out = init(obj)
            % Create logger file
            if obj.debugLevel&&0    % forced switch off as 2 always crashes on the second invocation of setlog...
                logLvl = 1+2+8+16;  % 4 shows many internal function calls as well. as long as the server is on, it is trying to track. so every x ms you have a record of the output of the function that calculates gaze position...
            else
                logLvl = 1;
            end
            ret = obj.iView.setLogger(logLvl, obj.settings.logFileName);
            if ret ~= 1
                error('Logger at "%s" could not be opened (error %d: %s)',obj.settings.logFileName,ret,SMIErrCode2String(ret));
            end
            
            % Connect to server
            obj.iView.disconnect();  % disconnect first, found this necessary as API otherwise apparently does not recognize it when eye tracker server crashed or closed by hand while connected. Well, calling 'iV_IsConnected' twice seems to work...
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
                    error('SMI: Could not establish connection. Check if Eye Tracker is running (error 104: %s)',SMIErrCode2String(ret));
                case 105
                    error('SMI: Could not establish connection. Check the communication ports (error 105: %s)',SMIErrCode2String(ret));
                case 123
                    error('SMI: Could not establish connection. Another process is blocking the communication ports (error 123: %s)',SMIErrCode2String(ret));
                case 201
                    error('SMI: Could not establish connection. Check if Eye Tracker is installed and running (error 200: %s)',SMIErrCode2String(ret));
                otherwise
                    error('SMI: Could not establish connection (error %d: %s)',ret,SMIErrCode2String(ret));
            end
            
            % check this is the device the user specified
            if obj.caps.deviceName
                [~,trackerName] = obj.iView.getDeviceName;
                assert(strcmp(trackerName,obj.settings.tracker),'Connected tracker is a "%s", not the "%s" you specified',obj.settings.tracker,trackerName)
            end
            
            % deal with device geometry
            if obj.caps.REDGeometry
                % setup device geometry
                ret = obj.iView.selectREDGeometry(obj.settings.geomProfile);
                assert(ret==1,'SMI: Error selecting geometry profile (error %d: %s)',ret,SMIErrCode2String(ret));
                % get info about the setup
                [~,obj.geom]    = obj.iView.getCurrentREDGeometry();
                out.geom        = obj.geom;
            end
            % get info about the system
            [~,obj.systemInfo]          = obj.iView.getSystemInfo();
            if obj.caps.serialNumber
                [~,out.systemInfo.Serial]   = obj.iView.getSerialNumber();
            end
            out.systemInfo              = obj.systemInfo;
            
            % check tracker is operating at requested tracking frequency
            if obj.caps.setSpeedMode
                % TODO
            else
                assert(obj.systemInfo.samplerate == obj.settings.freq,'Tracker not running at requested sampling rate (%d Hz), but at %d Hz',obj.settings.freq,obj.systemInfo.samplerate);
            end
            % setup track mode
            if obj.caps.setTrackingParam
                ret = obj.iView.setTrackingParameter(['ET_PARAM_' obj.settings.trackEye], ['ET_PARAM_' obj.settings.trackMode], 1);
                assert(ret==1,'SMI: Error selecting tracking mode (error %d: %s)',ret,SMIErrCode2String(ret));
            end
            % switch off averaging filter so we get separate data for each eye
            if obj.caps.configureFilter && isfield(obj.settings,'doAverageEyes')
                ret = obj.iView.configureFilter('Average', 'Set', int32(obj.settings.doAverageEyes));
                assert(ret==1,'SMI: Error configuring averaging filter (error %d: %s)',ret,SMIErrCode2String(ret));
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
            % set background color
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % NB: fullscreen fillrect sets new clear color in PTB
            % SMI calibration setup
            CalibrationData = SMIStructEnum.Calibration;
            CalibrationData.method               = obj.settings.cal.nPoint;
            CalibrationData.autoAccept           = int(obj.settings.cal.autoPace);
            % Setup calibration look. Necessary in all cases so that
            % validate image looks similar to calibration stimuli
            CalibrationData.foregroundBrightness = obj.settings.cal.fixBackColor(1);
            CalibrationData.backgroundBrightness = obj.settings.cal.bgColor(1);
            CalibrationData.targetSize           = max(10,round(obj.settings.cal.fixBackSize/2));   % 10 is the minimum size. Ignored for validation image...
            ret = obj.iView.setupCalibration(CalibrationData);
            obj.processError(ret,'SMI: Error setting up calibration');
            
            % reset calibration points in case someone else changed them
            % previously
            obj.iView.resetCalibrationPoints();
            % change calibration points if wanted
            if ~isempty(obj.settings.cal.pointPos)
                error('Not implemented')
                % TODO
                % be careful! "If this function is used with a RED or RED-m
                % device, the change is applied to the currently selected
                % profile." So we better first make a temp profile or so that
                % we then use...
                % iV_ChangeCalibrationPoint ( int number, int positionX, int positionY )
            end
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
                            error('run ended from SMI calibration routine')
                        otherwise
                            error('status %d not implemented',status);
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
                            error('run ended from SMI calibration routine')
                        otherwise
                            error('status %d not implemented',out.attempt{kCal}.calStatus);
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
                        error('run ended from SMI calibration routine')
                    otherwise
                        error('status %d not implemented',out.attempt{kCal}.valResultAccept);
                end
            end
        end
        
        function startRecording(obj,qClearBuffer)
            % by default do not clear recording buffer. For SMI, by the time
            % user calls startRecording, we already have data recorded during
            % calibration and validation in the buffer
            if nargin<2
                qClearBuffer = false;
            end
            obj.iView.stopRecording();      % make sure we're not already recording when we startRecording(), or we get an error. Ignore error return code here
            if qClearBuffer
                obj.iView.clearRecordingBuffer();
            end
            ret = obj.iView.startRecording();
            obj.processError(ret,'SMI: Error starting recording');
            WaitSecs(.1); % give it some time to get started. not needed according to doc, but never hurts
        end
        
        function pauseRecording(obj)
            ret = obj.iView.pauseRecording();
            obj.processError(ret,'SMI: Error pausing recording');
        end
        
        function continueRecording(obj,message)
            if nargin<2
                message = 'SMIWrapper: continueRecording called';
            end
            ret = obj.iView.continueRecording(message);
            obj.processError(ret,'SMI: Error continuing recording');
        end
        
        function stopRecording(obj)
            ret = obj.iView.stopRecording();
            obj.processError(ret,'SMI: Error stopping recording');
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
            obj.processError(ret,'SMI: Error sending message to data file');
        end
        
        function sample = getLatestSample(obj)
            % returns empty when sample not gotten successfully
            [ret,sample] = obj.iView.getSample();
            if ret~=1
                sample = [];
            end
        end
        
        function time = getTimeStamp(obj)
            % returns empty when sample not gotten successfully
            [ret,time] = obj.iView.getCurrentTimestamp();
            if ret~=1
                time = [];
            end
        end
        
        function saveData(obj,filename, user, description, doAppendVersion)
            % check if 2 computer setup
            isTwoComputerSetup = ~isempty(obj.settings.connectInfo) && ~strcmp(obj.settings.connectInfo{1},obj.settings.connectInfo{3});
            
            % 1. get filename and path
            [path,file,ext] = fileparts(filename);
            assert(~isempty(path),'saveData: filename should contain a path')
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
            
            if isTwoComputerSetup
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
                    allDat = [allDat data];
                end
                remotePath = allDat(6:end); % skip first 5 bits, they are a response header
                
                % 2: now save file on remote computer with path indicated
                % by remote computer. Overwrite if exists
                remoteFile = fullfile(remotePath,[file(1:3) '-eye_data.idf']);   % nearly hardcode remote file name. Only very specific file names are transferred by the remote endpoint
                ret = obj.iView.saveData(remoteFile, description, user, 1);
                obj.processError(ret,'SMI: Error saving data');
                
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
                    allDat = [allDat data];
                end
                pnet(con,'close');
                
                % 4: now save file locally
                assert(~isempty(allDat),'SMIWrapper: remote file could not be received')
                fid=fopen(filename,'w');
                fwrite(fid,allDat(6:end));  % skip first 5 bits, they are a response header
                fclose(fid);
            else
                ret = obj.iView.saveData(filename, description, user, 0);
                obj.processError(ret,'SMI: Error saving data');
            end
        end
        
        function out = deInit(obj,qQuit)
            obj.iView.disconnect();
            % also, read log, return contents as output and delete
            fid = fopen(obj.settings.logFileName, 'r');
            out = fread(fid, inf, '*char').';
            fclose(fid);
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
                case {'HiSpeed240','HiSpeed1250','RED250','RED500'}
                    settings.etApp              = 'iViewX';
                case 'RED-m'
                    settings.etApp              = 'iViewXOEM';
                case {'RED250mobile','REDn'}
                    settings.etApp              = 'iViewNG';
                otherwise
                    error('tracker "%s" not known/supported by this wrapper.\nSupported are: HiSpeed240, HiSpeed1250, RED250, RED500, RED-m, RED250mobile, REDn',tracker);
            end
            % connection info
            switch tracker
                case {'RED-m','RED250mobile','REDn'}
                    % likely one-computer setup, connectLocal() should
                    % work, so default is:
                    settings.connectInfo        = {};
                case {'HiSpeed240','HiSpeed1250','RED250','RED500'}
                    % template IPs, default ports
                    settings.connectInfo        = {'ipThis',4444,'ipET',5555};
            end
            % default tracking settings per eye-tracker
            % settings (only provided if supported):
            % - trackEye:               'EYE_LEFT', 'EYE_RIGHT', or
            %                           'EYE_BOTH'
            % - trackMode:              'MONOCULAR', 'BINOCULAR',
            %                           'SMARTBINOCULAR', or
            %                           'SMARTTRACKING'
            % - doAverageEyes           true/false. TODO: check if only for
            %                           RED-m and newer?
            % - freq:                   eye-tracker dependant. Only for NG
            %                           trackers can it actually be set 
            % - cal.nPoint:             0, 1, 2, 5, 9 or 13 calibration
            %                           points are possible
            switch tracker
                case 'HiSpeed1250'
                case 'HiSpeed240'
                case 'RED250'
                    % NB: averaging eyes and any tracking mode setup is not
                    % possible remotely. has to be done by hand in iViewX
                    settings.freq                   = 250;
                    settings.cal.nPoint             = 5;
                    settings.setup.headBox          = [40 20];  % at 70 cm. Doesn't matter what distance, is just for getting aspect ratio
                case 'RED500'
                    % NB: averaging eyes and any tracking mode setup is not
                    % possible remotely. has to be done by hand in iViewX
                    settings.freq                   = 500;
                    settings.cal.nPoint             = 5;
                    settings.setup.headBox          = [40 20];  % at 70 cm. Doesn't matter what distance, is just for getting aspect ratio
                case 'RED-m'
                    settings.trackEye               = 'EYE_BOTH';
                    settings.trackMode              = 'SMARTBINOCULAR';
                    settings.freq                   = 120;
                    settings.cal.nPoint             = 5;
                    settings.doAverageEyes          = true;
                    settings.setup.headBox          = [31 21];  % at 60 cm. Doesn't matter what distance, is just for getting aspect ratio
                case 'RED250mobile'
                case 'REDn'
            end
            
            % some settings only for remotes
            if ismember(tracker,{'RED250','RED500','RED-m','RED250mobile','REDn'})
                settings.setup.viewingDist      = 65;
                settings.geomProfile            = 'Desktop 22in Monitor';    % TODO: check it works for old REDs, does iViewX have these profiles?
            end
            
            % the rest here are good defaults for the RED-m (mostly), some
            % are general. Many are hard to set...
            settings.setup.startScreen  = 1;                                % 0. skip head positioning, go straight to calibration; 1. start with simple head positioning interface; 2. start with advanced head positioning interface
            settings.cal.autoPace       = true;                             % false: manually confirm each calibration point. true: only manually confirm the first point, the rest will be autoaccepted
            settings.cal.pointPos       = [];                               % if empty, default positions are used, else, specify N calibration point positions in an Nx2 matrix
            settings.cal.bgColor        = 127;
            settings.cal.fixBackSize    = 20;
            settings.cal.fixFrontSize   = 5;
            settings.cal.fixBackColor   = 0;
            settings.cal.fixFrontColor  = 255;
            settings.logFileName        = 'iView_log.txt';
            settings.text.font          = 'Consolas';
            settings.text.size          = 20;
            settings.text.style         = 0;                                % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.text.wrapAt        = 62;
            settings.text.vSpacing      = 1;
            % TODO
            %if ~Is64Bit
                settings.text.lineCentOff   = 3;                                % amount (pixels) to move single line text down so that it is visually centered on requested coordinate
            %end
            settings.string.simplePositionInstruction = 'Position yourself such that the two circles overlap.\nDistance: %.0f cm';
            settings.debugMode          = false;                            % for use with PTB's PsychDebugWindowConfiguration. e.g. does not hide cursor
            settings.logLevel           = 1;                                % TODO: implement
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
                'cal','nPoint'
                'cal','useSmartCalibration'
                'cal','bgColor'
                'cal','fixBackSize'
                'cal','fixFrontSize'
                'cal','fixBackColor'
                'cal','fixFrontColor'
                'text','font'
                'text','size'
                'text','style'
                'text','wrapAt'
                'text','vSpacing'
                'text','lineCentOff'
                'string','simplePositionInstruction'
                };
            for p=size(allowed,1):-1:1
                if ~isfield(obj.settings,allowed{1}) || ~isfield(obj.settings.(allowed{1}),allowed{2})
                    allowed(p,:) = [];
                end
            end
                        
        end
        
        function setCapabilities(obj)
            % preset all to false
            obj.caps.connectLocal       = false;
            obj.caps.configureFilter    = false;
            obj.caps.enableHighPerfMode = false;
            obj.caps.deviceName         = false;
            obj.caps.serialNumber       = false;
            obj.caps.setSpeedMode       = false;
            obj.caps.REDGeometry        = false;
            obj.caps.setTrackingParam   = false;
            obj.caps.hasHeadbox         = true;
            
            % RED-m and newer functionality
            switch obj.settings.tracker
                case {'RED-m','RED250mobile','REDn'}
                    obj.caps.connectLocal       = true;
                    obj.caps.configureFilter    = true;         % TODO: probably, have not tried on Hispeed and NG
                    obj.caps.enableHighPerfMode = true;
                    obj.caps.deviceName         = true;
                    obj.caps.serialNumber       = true;
            end
            % RED NG only functionality
            switch obj.settings.tracker
                case {'RED250mobile','REDn'}
                    obj.caps.setSpeedMode       = true;
            end
            % functionality not for hiSpeeds
            switch obj.settings.tracker
                case {'RED250','RED500','RED-m','RED250mobile','REDn'}
                    obj.caps.REDGeometry        = true;
            end
            % functionality not for old REDs
            switch obj.settings.tracker
                case {'HiSpeed240','HiSpeed1250','RED-m','RED250mobile','REDn'}
                    obj.caps.setTrackingParam   = true;
            end
            % setting only for hispeed
            switch obj.settings.tracker
                case {'HiSpeed240','HiSpeed1250'}
                    obj.caps.hasHeadbox = false;
            end
            % supported number of calibration points
            % TODO (check if differs, or all support all)
            % old REDs: 2, 5 or 9 points
            
            % some other per tracker settings.
            % TODO: I don't know which trackers support which!!. Have now
            % checked: RED-m, RED250, RED500
            obj.caps.setShowContour    = ismember(obj.settings.tracker,{});
            obj.caps.setShowPupil      = ismember(obj.settings.tracker,{'RED-m'});
            obj.caps.setShowCR         = ismember(obj.settings.tracker,{'RED-m'});
        end
        
        function ret_con = connect(obj)
            if isempty(obj.settings.connectInfo)
                if obj.caps.connectLocal
                    ret_con = obj.iView.connectLocal();
                else
                    error('%s tracker does not support iV_ConnectLocal, provide settings.connectInfo')
                end
            else
                ret_con = obj.iView.connect(obj.settings.connectInfo{:});
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
            if obj.caps.hasHeadbox
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
            if ~obj.caps.hasHeadbox
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
            if obj.debugLevel<2             % for cleanup
                cursors.reset = -1;         % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor          = cursorUpdater(cursors);
            
            % get tracking status and visualize
            if obj.caps.hasHeadbox
                pTrackingStatusS= SMIStructEnum.TrackingStatus;
                pSampleS        = SMIStructEnum.Sample;
            end
            qFirst          = true;
            while true
                if obj.caps.hasHeadbox
                    % get tracking status info
                    [~,pTrackingStatus]=obj.iView.getTrackingStatus(pTrackingStatusS);  % for position in headbox
                    [~,pSample]        =obj.iView.getSample(pSampleS);                  % for distance

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
                    DrawMonospacedText(advancedButTextCache);
                end
                Screen('FillRect',wpnt,[  0 120   0],calibButRect);
                DrawMonospacedText(calibButTextCache);
                if qHaveValidCalibrations
                    Screen('FillRect',wpnt,[150 150   0],validateButRect);
                    DrawMonospacedText(validateButTextCache);
                end
                % draw fixation points
                obj.drawfixpoint(wpnt,fixPos);
                
                % drawing done, show
                Screen('Flip',wpnt);
                
                
                % check for keypresses or button clicks
                [keyPressed,~,keyCode]  = KbCheck();
                [mx,my,buttons]         = GetMouse();
                % update cursor look if needed
                cursor.update(mx,my);
                if qFirst
                    % make sure we don't immediately click a button
                    % just because we come from another screen where
                    % there is a button at the same location and mouse
                    % is still down (or keyboard action with same
                    % accelerator for that matter)
                    while keyPressed || any(buttons)
                        [keyPressed]    = KbCheck();
                        [~,~,buttons]   = GetMouse();
                    end
                end
                qFirst = false;
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    qIn = inRect([mx my],[advancedButRect.' calibButRect.' validateButRect.']);
                    if any(qIn)
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
                    elseif any(strcmpi(keys,'escape')) && any(strcmpi(keys,'shift'))
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
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
            margin  = 80;
            ret = 0;
            while ret~=1
                [ret,eyeImage] = obj.iView.getEyeImage();
            end
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
            if obj.debugLevel<2                 % for cleanup
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
            pImageDataS     = SMIStructEnum.Image;
            tex             = 0;
            eyeKeyDown      = false;
            eyeClickDown    = false;
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
            toggleKeys      = KbName({'c','g','p'});
            qFirst          = true;
            while true
                if obj.caps.hasHeadbox
                    % get tracking status info
                    [~,pTrackingStatus]=obj.iView.getTrackingStatus(pTrackingStatusS);  % for position in headbox
                    [~,pSample]        =obj.iView.getSample(pSampleS);                  % for distance

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
                    if tex
                        Screen('Close',tex);
                    end
                    tex = Screen('MakeTexture',wpnt,eyeImage,[],8);   % 8 to prevent mipmap generation, we don't need it
                end
                
                % do drawing
                if obj.caps.hasHeadbox
                    % draw box
                    Screen('FillRect',wpnt,80,boxRect);
                    % draw distance
                    if ~isnan(avgDist)
                        Screen('TextSize',  wpnt, 10);
                        Screen('DrawText',wpnt,sprintf('%.0f cm',avgDist) ,boxRect(3)-40,boxRect(4)-16,255);
                    end
                    % draw eyes in box
                    Screen('TextSize',  wpnt, obj.settings.text.size);
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
                        style = Screen('TextStyle',  wpnt, 1);
                        obj.drawEye(wpnt,pTrackingStatus.leftEye .validity,posL,posR, relPos*fac,[255 120 120],[220 186 186],round(sz*facL*gain),'L',boxRect);
                        % right eye
                        obj.drawEye(wpnt,pTrackingStatus.rightEye.validity,posR,posL,-relPos*fac,[120 255 120],[186 220 186],round(sz*facR*gain),'R',boxRect);
                        Screen('TextStyle',  wpnt, style);
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
                DrawMonospacedText(basicButTextCache);
                Screen('FillRect',wpnt,[ 0 120   0],calibButRect);
                DrawMonospacedText(calibButTextCache);
                if qHaveValidCalibrations
                    Screen('FillRect',wpnt,[150 150   0],validateButRect);
                    DrawMonospacedText(validateButTextCache);
                end
                if obj.caps.setShowContour
                    Screen('FillRect',wpnt,eyeButClrs{overlays(1)+1},contourButRect);
                    DrawMonospacedText(contourButTextCache);
                end
                if obj.caps.setShowPupil
                    Screen('FillRect',wpnt,eyeButClrs{overlays(2)+1},pupilButRect);
                    DrawMonospacedText(pupilButTextCache);
                end
                if obj.caps.setShowCR
                    Screen('FillRect',wpnt,eyeButClrs{overlays(3)+1},glintButRect);
                    DrawMonospacedText(glintButTextCache);
                end
                % draw fixation points
                obj.drawfixpoint(wpnt,fixPos);
                
                % drawing done, show
                Screen('Flip',wpnt);
                
                % check for keypresses or button clicks
                [keyPressed,~,keyCode]  = KbCheck();
                [mx,my,buttons]         = GetMouse();
                % update cursor look if needed
                cursor.update(mx,my);
                if qFirst
                    % make sure we don't immediately click a button
                    % just because we come from another screen where
                    % there is a button at the same location and mouse
                    % is still down (or keyboard action with same
                    % accelerator for that matter)
                    while keyPressed || any(buttons)
                        [keyPressed]    = KbCheck();
                        [~,~,buttons]   = GetMouse();
                    end
                end
                qFirst = false;
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
                        elseif ~eyeClickDown
                            if qIn(4)
                                overlays(1) = ~overlays(1);
                                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',overlays(1));
                            elseif qIn(5)
                                overlays(2) = ~overlays(2);
                                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL',overlays(2));
                            elseif qIn(6)
                                overlays(3) = ~overlays(3);
                                obj.iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX',overlays(3));
                            end
                            eyeClickDown = any(qIn);
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
                    elseif any(strcmpi(keys,'p')) &&qHaveValidCalibrations
                        status = -3;
                        break;
                    elseif any(strcmpi(keys,'escape')) && any(strcmpi(keys,'shift'))
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    end
                    if ~eyeKeyDown
                        if any(strcmpi(keys,'c')) && obj.caps.setShowContour
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
                eyeKeyDown   = any(keyCode(toggleKeys));        % maintain button state so only one press counted until after key up
                eyeClickDown = eyeClickDown && any(buttons);    % maintain button state so only one press counted until after mouse up
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
        
        function drawCircle(~,wpnt,refClr,center,refSz,lineWidth)
            nStep = 200;
            alpha = linspace(0,2*pi,nStep);
            alpha = [alpha(1:end-1); alpha(2:end)]; alpha = alpha(:).';
            xy = refSz.*[cos(alpha); sin(alpha)];
            Screen('DrawLines', wpnt, xy, lineWidth ,refClr ,center,2);
        end
        
        function cache = getButtonTextCache(obj,wpnt,lbl,rect)
            [~,~,~,cache] = DrawMonospacedText(wpnt,lbl,'center','center',0,[],[],[],OffsetRect(rect,0,obj.settings.text.lineCentOff));
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
        
        function drawfixpoint(obj,wpnt,pos)
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
            % calibrate
            obj.startRecording(qClearBuffer);
            % enter calibration mode
            obj.sendMessage('CALIBRATION START');
            obj.iView.calibrate();
            % show display
            [status,out.cal] = obj.DoCalPointDisplay(wpnt);
            obj.sendMessage('CALIBRATION END');
            if status~=1
                return;
            end
            
            % validate
            % enter validation mode
            obj.sendMessage('VALIDATION START');
            obj.iView.validate();
            % show display
            [status,out.val] = obj.DoCalPointDisplay(wpnt);
            obj.sendMessage('VALIDATION END');
            obj.stopRecording();
            
            % clear flip
            Screen('Flip',wpnt);
        end
        
        function [status,out] = DoCalPointDisplay(obj,wpnt)
            % status output:
            %  1: finished succesfully (you should query SMI software whether they think
            %     calibration was succesful though)
            %  2: skip calibration and continue with task (shift+s)
            % -1: restart calibration (r)
            % -2: abort calibration and go back to setup (escape key)
            % -4: Exit completely (control+escape)
            
            % clear screen, anchor timing, get ready for displaying calibration points
            out.flips = Screen('Flip',wpnt);
            out.point = nan;
            out.pointPos = [];
            
            % wait till keys released
            keyDown = 1;
            while keyDown
                WaitSecs('YieldSecs', 0.002);
                keyDown = KbCheck;
            end
            
            pCalibrationPoint = SMIStructEnum.CalibrationPoint;
            while true
                nextFlipT = out.flips(end)+1/1000;
                ret = obj.iView.getCurrentCalibrationPoint(pCalibrationPoint);
                if ret==2   % RET_NO_VALID_DATA
                    % calibration/validation finished
                    Screen('Flip',wpnt);    % clear
                    obj.sendMessage(sprintf('POINT OFF %d',out.point(end)));
                    status = 1;
                    break;
                end
                pos = [pCalibrationPoint.positionX pCalibrationPoint.positionY];
                obj.drawfixpoint(wpnt,pos);
                
                out.point(end+1) = pCalibrationPoint.number;
                out.flips(end+1) = Screen('Flip',wpnt,nextFlipT);
                if out.point(end)~=out.point(end-1)
                    obj.sendMessage(sprintf('POINT ON %d (%d %d)',out.point(end),pos));
                    out.pointPos(end+1,1:3) = [out.point(end) pos];
                end
                % check for keys
                [keyPressed,~,keyCode] = KbCheck();
                if keyPressed
                    keys = KbName(keyCode);
                    % NB: SMI SDK (apparently) takes care of detecting
                    % calibration key presses (space for acception point).
                    % More reliably than switching that off and doing it
                    % ourselves it appears, so we'll work with that.
                    if any(strcmpi(keys,'r'))
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
                    elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    end
                end
            end
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
                    menuTextCache(c) = obj.getButtonTextCache(wpnt,str,menuRects(c,:));
                end
            end
            
            % setup fixation points in the corners of the screen
            fixPos = [.1 .1; .1 .9; .9 .9; .9 .1] .* repmat(obj.scrInfo.resolution(1:2),4,1);
            
            qDoneCalibSelection = false;
            qSelectMenuOpen     = false;
            qShowGaze           = false;
            tex                 = 0;
            gazeKeyDown         = false;
            gazeClickDown       = false;
            pSampleS            = SMIStructEnum.Sample;
            toggleKeys          = KbName({'g'});
            qFirst              = true;
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
                        valText = sprintf('<font=Consolas><size=20>accuracy   X       Y\n<color=0000ff>Average<color>: % 2.2f°  % 2.2f°',cal{selection}.validateAccuracy.deviationLX,cal{selection}.validateAccuracy.deviationLY);
                    else
                        valText = sprintf('<font=Consolas><size=20>accuracy   X       Y\n   <color=ff0000>Left<color>: % 2.2f°  % 2.2f°\n  <color=00ff00>Right<color>: % 2.2f°  % 2.2f°',cal{selection}.validateAccuracy.deviationLX,cal{selection}.validateAccuracy.deviationLY,cal{selection}.validateAccuracy.deviationRX,cal{selection}.validateAccuracy.deviationRY);
                    end
                    DrawMonospacedText(wpnt,valText,'center',100,255,[],obj.settings.text.vSpacing);
                    % draw buttons
                    Screen('FillRect',wpnt,[150 0 0],recalButRect);
                    DrawMonospacedText(recalButTextCache);
                    Screen('FillRect',wpnt,[0 120 0],continueButRect);
                    DrawMonospacedText(continueButTextCache);
                    if qHaveMultipleValidCals
                        Screen('FillRect',wpnt,[150 150 0],selectButRect);
                        DrawMonospacedText(selectButTextCache);
                    end
                    Screen('FillRect',wpnt,[150 0 0],setupButRect);
                    DrawMonospacedText(setupButTextCache);
                    Screen('FillRect',wpnt,showGazeButClrs{qShowGaze+1},showGazeButRect);
                    DrawMonospacedText(showGazeButTextCache);
                    % if selection menu open, draw on top
                    if qSelectMenuOpen
                        % menu background
                        Screen('FillRect',wpnt,140,menuBackRect);
                        % menuRects
                        Screen('FillRect',wpnt,110,menuRects.');
                        % text in each rect
                        for c=1:length(iValid)
                            DrawMonospacedText(menuTextCache(c));
                        end
                    end
                    % if showing gaze, draw
                    if qShowGaze
                        [ret,pSample] = obj.iView.getSample(pSampleS);
                        if ret==1
                            % draw
                            if qAveragedEyes
                                Screen('gluDisk', wpnt,[255 0 0], pSample. leftEye.gazeX, pSample. leftEye.gazeY, 10);
                            else
                                Screen('gluDisk', wpnt,[255 0 0], pSample. leftEye.gazeX, pSample. leftEye.gazeY, 10);
                                Screen('gluDisk', wpnt,[0 255 0], pSample.rightEye.gazeX, pSample.rightEye.gazeX, 10);
                            end
                        end
                        % draw fixation points
                        obj.drawfixpoint(wpnt,fixPos);
                    end
                    % drawing done, show
                    Screen('Flip',wpnt);
                    
                    % get user response
                    [keyPressed,~,keyCode]  = KbCheck();
                    [mx,my,buttons]         = GetMouse();
                    % update cursor look if needed
                    cursor.update(mx,my);
                    if qFirst
                        % make sure we don't immediately click a button
                        % just because we come from another screen where
                        % there is a button at the same location and mouse
                        % is still down (or keyboard action with same
                        % accelerator for that matter)
                        while keyPressed || any(buttons)
                            [keyPressed]    = KbCheck();
                            [~,~,buttons]   = GetMouse();
                        end
                    end
                    qFirst = false;
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
                                elseif qIn(5) && ~gazeClickDown
                                    qShowGaze           = ~qShowGaze;
                                    gazeClickDown       = true;
                                end
                                break;
                            end
                        end
                    elseif keyPressed
                        keys = KbName(keyCode);
                        if qSelectMenuOpen
                            if any(strcmpi(keys,'escape'))
                                qSelectMenuOpen = false;
                                break;
                            elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance
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
                            elseif any(strcmpi(keys,'escape')) && ~any(strcmpi(keys,'shift'))
                                status = -1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'s')) && ~any(strcmpi(keys,'shift'))
                                status = -2;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'c')) && qHaveMultipleValidCals
                                qSelectMenuOpen     = true;
                                break;
                            elseif any(strcmpi(keys,'g')) && ~gazeKeyDown
                                qShowGaze           = ~qShowGaze;
                                gazeKeyDown         = true;
                                break;
                            end
                        end
                        
                        % these two key combinations should always be available
                        if any(strcmpi(keys,'escape')) && any(strcmpi(keys,'shift'))
                            status = -2;
                            qDoneCalibSelection = true;
                            break;
                        elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
                            % skip calibration
                            obj.iView.abortCalibration();
                            status = 2;
                            qDoneCalibSelection = true;
                            break;
                        end
                    end
                    gazeKeyDown   = gazeKeyDown && any(keyCode(toggleKeys));  % maintain button state so only one press counted until after key up
                    gazeClickDown = gazeClickDown && any(buttons);            % maintain button state so only one press counted until after mouse up
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
    end
end