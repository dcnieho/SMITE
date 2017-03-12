function fhndl = SMIWrapper(smiSetup,scrInfo,textSetup)


% params
iView       = [];
debugLevel  = false;

if isnumeric(scrInfo) % bgColor only
    thecolor = scrInfo;
    clear scrInfo;
    scrInfo.rect    = Screen('Rect',0); scrInfo.rect(1:2) = [];
    scrInfo.center  = scrInfo.rect/2;
    scrInfo.bgclr   = thecolor;
end


% setup function handles
fhndl.init              = @init;
fhndl.calibrate         = @calibrate;
fhndl.startRecording    = @startRecording;  % NB: stops any previous recording and throws away all recorded data. So only call at start of experiment
fhndl.pauseRecording    = @pauseRecording;
fhndl.continueRecording = @continueRecording;
fhndl.stopRecording     = @stopRecording;
% NB: consider using: % calllib('iViewXAPI','iV_SendImageMessage','msg_string') 
% directly whenever you want to store a message in the data file to ensure
% minimum overhead.
fhndl.sendMessage       = @sendMessage;
fhndl.isConnected       = @isConnected;
fhndl.saveData          = @saveData;
fhndl.cleanUp           = @cleanUp;
fhndl.processError      = @processError;
        
    function out = init(input1)
        debugLevel = input1;
        
        % setup colors
        smiSetup.cal.fixBackColor = color2RGBA(smiSetup.cal.fixBackColor);
        smiSetup.cal.fixFrontColor= color2RGBA(smiSetup.cal.fixFrontColor);
        
        % Load in plugin, create structure with function wrappers
        iView = iViewXAPI();
        
        % Create logger file
        if debugLevel&&0    % forced switch off as 2 always crashes on the second invocation of setlog...
            logLvl = 1+2+8+16;  % 4 shows many internal function calls as well. as long as the server i on, it is trying to track. so every x ms you have a record of the output of the function that calculates gaze position...
        else
            logLvl = 1;
        end
        ret = iView.setLogger(logLvl, smiSetup.logFileName);
        if ret ~= 1
            error('Logger at "%s" could not be opened (error %d: %s)',smiSetup.logFileName,ret,SMIErrCode2String(ret));
        end
        
        % Connect to server
        iView.disconnect();  % disconnect first, found this necessary as API otherwise apparently does not recognize it when eye tracker server crashed or closed by hand while connected. Well, calling 'iV_IsConnected' twice seems to work...
        ret = iView.start(smiSetup.etApp);  % returns 1 when starting app, 4 if its already running
        qStarting = ret==1;
        
        % connect
        ret = connect(iView,smiSetup.connectInfo);
        if qStarting && ret~=1
            % in case eye tracker server is starting, give it some time
            % before trying to connect, don't hammer it unnecessarily
            iView.setConnectionTimeout(1);   % "timeout for how long iV_Connect tries to connect to iView eye tracking server." server startup is slow, give it a lot of time to try to connect.
            count = 1;
            while count < 30 && ret~=1
                ret = connect(iView,smiSetup.connectInfo);
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
        
        % Set debug mode with iView.setupDebugMode(1) not supported on
        % REDm it seems
        
        % setup device geometry
        ret = iView.selectREDGeometry(smiSetup.geomProfile);
        assert(ret==1,'SMI: Error selecting geometry profile (error %d: %s)',ret,SMIErrCode2String(ret));
        % get info about the setup
        [~,out.geom] = iView.getCurrentREDGeometry();
        % get info about the system
        [~,out.systemInfo] = iView.getSystemInfo();
        % check operating at requested tracking frequency (the command
        % to set frequency is only supported on the NG systems...)
        assert(out.systemInfo.samplerate == smiSetup.freq,'Tracker not running at requested sampling rate (%d Hz), but at %d Hz',smiSetup.freq,out.systemInfo.samplerate);
        % setup track mode
        ret = iView.setTrackingParameter(['ET_PARAM_' smiSetup.trackEye], ['ET_PARAM_' smiSetup.trackMode], 1);
        assert(ret==1,'SMI: Error selecting tracking mode (error %d: %s)',ret,SMIErrCode2String(ret));
        % switch off averaging filter so we get separate data for each eye
        ret = iView.configureFilter('Average', 'Set', 0);
        assert(ret==1,'SMI: Error configuring averaging filter (error %d: %s)',ret,SMIErrCode2String(ret));
    end

    function out = calibrate(wpnt)
        % setup calibration
        CalibrationData = getSMIStructEnum('CalibrationStruct');
        CalibrationData.method = smiSetup.cal.nPoint;
        % Setup calibration look. Necessary in all cases so that validate
        % image looks similar to calibration stimuli
        CalibrationData.foregroundBrightness = smiSetup.cal.fixBackColor(1);
        CalibrationData.backgroundBrightness = smiSetup.cal.bgColor(1);
        CalibrationData.targetSize           = max(10,round(smiSetup.cal.fixBackSize/2));   % 10 is the minimum size. Ignored for validation image...
        if nargin>0&&smiSetup.cal.qUsePTB
            CalibrationData.visualization = 0;
        else
            CalibrationData.visualization = 1;
        end
        ret = iView.setupCalibration(CalibrationData);
        processError(ret,'SMI: Error setting up calibration');
        
        % change calibration points if wanted
        if ~isempty(smiSetup.cal.pointPos)
            error('Not implemented')
            % be careful! "If this function is used with a RED or RED-m
            % device, the change is applied to the currently selected
            % profile." So we better first make a temp profile or so that
            % we then use...
            % iV_ChangeCalibrationPoint ( int number, int positionX, int positionY )
        end
        % get where the calibration points are
        pCalibrationPoint = getSMIStructEnum('CalibrationPointStruct');
        out.calibrationPoints = struct('X',zeros(1,smiSetup.cal.nPoint),'Y',zeros(1,smiSetup.cal.nPoint));
        for p=1:smiSetup.cal.nPoint
            iView.getCalibrationPoint(p, pCalibrationPoint);
            out.calibrationPoints.X(p) = pCalibrationPoint.positionX;
            out.calibrationPoints.Y(p) = pCalibrationPoint.positionY;
        end
        
        % now run calibration until successful or exited
        kCal = 0;
        qDoSetup = smiSetup.cal.qStartWithHeadBox;
        while true
            kCal = kCal+1;
            if qDoSetup
                % show eye image (optional), headbox.
                status = doShowHeadBoxEye(wpnt,iView,scrInfo,textSetup,debugLevel);
                switch status
                    case 1
                        % all good, continue
                    case 2
                        % skip setup
                        break;
                    case -1
                        % doesn't make sense here, doesn't exist
                    case -2
                        % full stop
                        error('run ended from SMI calibration routine')
                    otherwise
                        error('status %d not implemented',status);
                end
            end
            
            % calibrate and validate
            if nargin>0&&smiSetup.cal.qUsePTB
                [out.attempt{kCal}.calStatus,temp] = DoCalAndValPTB(wpnt,iView,smiSetup.cal,@startRecording,@stopRecording,@sendMessage);
                warning('off','catstruct:DuplicatesFound')  % field already exists but is empty, will be overwritten with the output from the function here
                out.attempt{kCal} = catstruct(out.attempt{kCal},temp);
            else
                out.attempt{kCal}.calStatus = DoCalAndValSMI(iView,@startRecording,@stopRecording,@sendMessage);
            end
            switch out.attempt{kCal}.calStatus
                case 1
                    % all good, continue
                case 2
                    % skip setup
                    break;
                case -1
                    % retry calibration
                    qDoSetup = true;
                    continue;
                case -2
                    % full stop
                    error('run ended from SMI calibration routine')
                otherwise
                    error('status %d not implemented',out.attempt{kCal}.calStatus);
            end
            
            % check calibration status to be sure we're calibrated
            [~,out.attempt{kCal}.calStatusSMI] = iView.getCalibrationStatus();
            if ~strcmp(out.attempt{kCal}.calStatusSMI,'calibrationValid')
                % retry calibration
                qDoSetup = true;
                continue;
            end
            
            % get info about accuracy of calibration
            [~,out.attempt{kCal}.validateAccuracy] = iView.getAccuracy([], 0);
            % get validation image
            [~,out.attempt{kCal}.validateImage] = iView.getAccuracyImage();
            % show validation result and ask to continue
            out.attempt{kCal}.valResultAccept = showValidateImage(wpnt,out.attempt{kCal},scrInfo,textSetup);
            switch out.attempt{kCal}.valResultAccept
                case 1
                    % all good, we're done
                    break;
                case 2
                    % skip setup
                    break;
                case -1
                    % retry calibration
                    qDoSetup = true;
                    continue;
                case -2
                    % full stop
                    error('run ended from SMI calibration routine')
                otherwise
                    error('status %d not implemented',out.attempt{kCal}.valResultAccept);
            end
        end
    end

    function out = startRecording(qClearBuffer)
        % by default do not clear recording buffer. For SMI, by the time
        % user calls startRecording, we already have data recorded during
        % calibration and validation in the buffer
        if nargin<1
            qClearBuffer = false;
        end
        iView.stopRecording();      % make sure we're not already recording when we startRecording(), or we get an error
        if qClearBuffer
            iView.clearRecordingBuffer();
        end
        ret = iView.startRecording();
        out = true;
        processError(ret,'SMI: Error starting recording');
        WaitSecs(.1); % give it some time to get started. not needed according to doc, but never hurts
    end

    function out = pauseRecording()
        ret = iView.pauseRecording();
        out = true;
        processError(ret,'SMI: Error pausing recording');
    end

    function out = continueRecording(message)
        ret = iView.continueRecording(message);
        out = true;
        processError(ret,'SMI: Error continuing recording');
    end

    function out = stopRecording()
        ret = iView.stopRecording();
        out = true;
        processError(ret,'SMI: Error stopping recording');
    end

    function out = isConnected()
        % call it twice as i have found that after manually closing the
        % server (and waiting for 10 s), the first call still returns that
        % we are connected. I don't want to risk the connection breaking
        % and only finding out much later
        iView.isConnected();
        out = iView.isConnected();
    end

    function out = sendMessage(str)
        % using
        % calllib('iViewXAPI','iV_SendImageMessage','msg_string')
        % here to save overhead
        % consider using that directly in your code for best timing
        % ret = iView.sendImageMessage(str);
        ret = calllib('iViewXAPI','iV_SendImageMessage',str);
        out = true;
        processError(ret,'SMI: Error sending message to data file');
    end

    function out = saveData(filename, description, user, overwrite)
        out = true;
        ret = iView.saveData([filename '.idf'], description, user, overwrite);
        processError(ret,'SMI: Error saving data');
    end

    function out = cleanUp()
        iView.disconnect();
        % also, read log, return contents as output and delete
        fid = fopen(smiSetup.logFileName, 'r');
        out = fread(fid, inf, '*char').';
        fclose(fid);
        % somehow, matlab maintains a handle to the log file, even after
        % fclose all and unloading the SMI library. Somehow a dangling
        % handle from smi, would be my guess (note that calling iV_Quit did
        % not fix it).
        % delete(smiSetup.logFileName);
    end

    function processError(returnCode,errorString)
        % for SMI, anything that is not 1 is an error
        assert(returnCode==1,'%s (error %d: %s)',errorString,returnCode,SMIErrCode2String(returnCode));
    end

end




% helpers
function ret_con = connect(iView,connectInfo)
if isempty(connectInfo)
    ret_con = iView.connectLocal();
else
    ret_con = iView.connect(connectInfo{:});
end
end

function status = doShowHeadBoxEye(wpnt,iView,scrInfo,textSetup,debugLevel)
% status output:
%  1: continue (setup seems good) (space)
%  2: skip calibration and continue with task (shift+s)
% -2: Exit completely (control+escape)
% (NB: no -1 for this function)

% setup text
Screen('TextFont',  wpnt, textSetup.font);
Screen('TextSize',  wpnt, textSetup.size);
Screen('TextStyle', wpnt, textSetup.style);
% setup box
REDmBox = [31 21]; % at 60 cm, doesn't matter as we need aspect ratio
boxSize = round(500.*REDmBox./REDmBox(1));
[boxCenter(1),boxCenter(2)] = RectCenter([0 0 boxSize]);
% position box
boxRect = CenterRectOnPoint([0 0 boxSize],scrInfo.center(1),scrInfo.center(2));
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
% setup interface buttons, draw text once to get cache
yposBase    = round(scrInfo.rect(2)*.95);
buttonSz    = [250 45];
buttonOff   = 80;
baseRect    = OffsetRect([0 0 buttonSz],scrInfo.center(1),yposBase-buttonSz(2)); % left is now at screen center, bottom at right height
continueButRect     = OffsetRect(baseRect,-buttonOff/2-buttonSz(1),0);
[~,~,~,continueButTextCache] = DrawMonospacedText(wpnt,'continue (<i>space<i>)','center','center',0,[],[],[],OffsetRect(continueButRect,0,textSetup.lineCentOff));
eyeImageButRect     = OffsetRect(baseRect, buttonOff/2            ,0);
[~,~,~,eyeImageButTextCache] = DrawMonospacedText(wpnt,'eye image (<i>e<i>)'   ,'center','center',0,[],[],[],OffsetRect(eyeImageButRect,0,textSetup.lineCentOff));
Screen('FillRect', wpnt, scrInfo.bgclr); % clear what we've just drawn
eyeButClrs  = {[37  97 163],[11 122 244]};
% these will be set up when the eye image is shown
eoButSz         = [174 buttonSz(2)];
eoButMargin     = [15 20];
contourButRect  = [];
pupilButRect  	= [];
reflexButRect   = [];

% setup cursors
cursors.rect    = {continueButRect.' eyeImageButRect.'};
cursors.cursor  = [2 2];    % Hand
cursors.other   = 0;        % Arrow
if debugLevel<2  % for cleanup
    cursors.reset = -1; % hide cursor (else will reset to cursor.other by default, so we're good with that default
end
cursor          = cursorUpdater(cursors);


% get tracking status and visualize, showing eye image as well if wanted
qShowEyeImage = false;
qRecalculateRects = false;
qFirstTimeEyeImage= true;
tex = 0;
arrowColor = zeros(3,6);
pTrackingStatusS= getSMIStructEnum('TrackingStatusStruct');
pSampleS        = getSMIStructEnum('SampleStruct');
pImageDataS     = getSMIStructEnum('ImageStruct');
eyeKeyDown      = false;
eyeClickDown    = false;
relPos          = zeros(3);
% for overlays in eye image. disable them all initially
iView.setTrackingParameter(2,3,0);  % disabling ET_PARAM_SHOW_CONTOUR
iView.setTrackingParameter(2,4,0);  % disabling ET_PARAM_SHOW_PUPIL
iView.setTrackingParameter(2,5,0);  % disabling ET_PARAM_SHOW_REFLEX
overlays        = false(3);
toggleKeys      = KbName({'c','e','g','p'});
while true
    % get tracking status info
    [~,pTrackingStatus]=iView.getTrackingStatus(pTrackingStatusS);  % for position in headbox
    [~,pSample]=iView.getSample(pSampleS);                          % for distance
    
    % get average eye distance. use distance from one eye if only one eye
    % available
    distL   = pSample.leftEye .eyePositionZ*(pSample.leftEye .diam/pSample.leftEye .diam)/10;
    distR   = pSample.rightEye.eyePositionZ*(pSample.rightEye.diam/pSample.rightEye.diam)/10;
    dists   = [distL distR];
    avgDist = mean(dists(~isnan(dists)));
    % if missing, estimate where eye ould be in depth if user kept head yaw
    % constant
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
        arrowColor(:,idx) = getArrowColor(pTrackingStatus.total.positionRatingX,xThresh,col1,col2,col3);
    end
    if abs(pTrackingStatus.total.positionRatingY)>yThresh(1)
        idx = 3 + (pTrackingStatus.total.positionRatingY<0);
        qDrawArrow(idx) = true;
        arrowColor(:,idx) = getArrowColor(pTrackingStatus.total.positionRatingY,yThresh,col1,col2,col3);
    end
    if abs(pTrackingStatus.total.positionRatingZ)>zThresh(1)
        idx = 5 + (pTrackingStatus.total.positionRatingZ>0);
        qDrawArrow(idx) = true;
        arrowColor(:,idx) = getArrowColor(pTrackingStatus.total.positionRatingZ,zThresh,col1,col2,col3);
    end
    if qShowEyeImage
        % get eye image
        [ret,eyeImage] = iView.getEyeImage(pImageDataS);
        if ret==1
            % clean up old one, if any
            if tex
                Screen('Close',tex);
            end
            tex         = Screen('MakeTexture',wpnt,eyeImage,[],8);   % 8 to prevent mipmap generation, we don't need it
            if qRecalculateRects && qFirstTimeEyeImage
                % only calculate when first time to show image
                eyeImageRect= [0 0 size(eyeImage,2) size(eyeImage,1)];
            end
        end
    elseif tex
        Screen('Close',tex);
        tex = 0;
    end
    if qRecalculateRects && (~qShowEyeImage || (qShowEyeImage&&tex))
        if qShowEyeImage
            % now visible
            % center whole box+eye image on screen
            margin      = 80;
            sidespace   = round((scrInfo.rect(2)-RectHeight(boxRect)-margin-RectHeight(eyeImageRect))/2);
            % put boxrect such that it is sidespace pixels away from top of
            % screen
            boxRect     = OffsetRect(boxRect,0,sidespace-boxRect(2));
            if qFirstTimeEyeImage
                % only calculate all this once, it'll be the same the next
                % time we show the eye image.
                % move such that top-left of imRect is at right place
                eyeImageRect    = OffsetRect(eyeImageRect,scrInfo.center(1)-eyeImageRect(3)/2,sidespace+RectHeight(boxRect)+margin);
                % setup buttons for overlays in the eye image, draw text once to get cache
                contourButRect      = OffsetRect([0 0 eoButSz],eyeImageRect(3)+eoButMargin(1),eyeImageRect(4)-eoButSz(2));
                [~,~,~,contourButTextCache]= DrawMonospacedText(wpnt,'contour (<i>c<i>)' ,'center','center',0,[],[],[],OffsetRect(contourButRect,0,textSetup.lineCentOff));
                pupilButRect        = OffsetRect([0 0 eoButSz],eyeImageRect(3)+eoButMargin(1),eyeImageRect(4)-eoButSz(2)*2-eoButMargin(2));
                [~,~,~,pupilButTextCache]  = DrawMonospacedText(wpnt,'pupil (<i>p<i>)'   ,'center','center',0,[],[],[],OffsetRect(pupilButRect,0,textSetup.lineCentOff));
                reflexButRect       = OffsetRect([0 0 eoButSz],eyeImageRect(3)+eoButMargin(1),eyeImageRect(4)-eoButSz(2)*3-eoButMargin(2)*2);
                [~,~,~,reflexButTextCache] = DrawMonospacedText(wpnt,'glint (<i>g<i>)'   ,'center','center',0,[],[],[],OffsetRect(reflexButRect,0,textSetup.lineCentOff));
                Screen('FillRect', wpnt, scrInfo.bgclr); % clear what we've just drawn
                qFirstTimeEyeImage = false;
            end
            % update cursors
            cursors.rect    = [cursors.rect {contourButRect.' pupilButRect.' reflexButRect.'}];
            cursors.cursor  = [2 2 2 2 2];
            cursor          = cursorUpdater(cursors);
        else
            % now hidden
            boxRect     = CenterRectOnPoint([0 0 boxSize],scrInfo.center(1),scrInfo.center(2));
            % update cursors: remove buttons for overlays in the eye image
            cursors.rect    = cursors.rect(1:2);
            cursors.cursor  = [2 2];
            cursor          = cursorUpdater(cursors);
        end
        qRecalculateRects = false;
    end
    
    % do drawing
    % draw box
    Screen('FillRect',wpnt,80,boxRect);
    % draw distance
    if ~isnan(avgDist)
        Screen('TextSize',  wpnt, 10);
        Screen('DrawText',wpnt,sprintf('%.0f cm',avgDist) ,boxRect(3)-40,boxRect(4)-16,255);
    end
    % draw eyes in box
    Screen('TextSize',  wpnt, textSetup.size);
    % scale up size of oval. define size/rect at standard distance (60cm),
    % have a gain for how much to scale as distance changes
    if pTrackingStatus.leftEye.validity || pTrackingStatus.rightEye.validity
        posL = [pTrackingStatus.leftEye .relativePositionX -pTrackingStatus.leftEye .relativePositionY]/2+.5;  %-Y as +1 is upper and -1 is lower edge. needs to be reflected for screen drawing
        posR = [pTrackingStatus.rightEye.relativePositionX -pTrackingStatus.rightEye.relativePositionY]/2+.5;
        % determine size of eye. based on distance to standard distance of
        % 60cm, calculate size change
        fac  = 60/avgDist;
        facL = 60/distL;
        facR = 60/distR;
        gain = 1.5;  % 1.5 is a gain to make differences larger
        sz   = 15;
        % left eye
        style = Screen('TextStyle',  wpnt, 1);
        drawEye(wpnt,pTrackingStatus.leftEye .validity,posL,posR, relPos*fac,[255 120 120],[220 186 186],round(sz*facL*gain),'L',boxRect);
        % right eye
        drawEye(wpnt,pTrackingStatus.rightEye.validity,posR,posL,-relPos*fac,[120 255 120],[186 220 186],round(sz*facR*gain),'R',boxRect);
        Screen('TextStyle',  wpnt, style);
        % update relative eye positions - used for drawing estimated
        % position of missing eye. X and Y are relative position in
        % headbox, Z is difference in measured eye depths
        if pTrackingStatus.leftEye.validity&&pTrackingStatus.rightEye.validity
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
    % draw eye image, if any
    if tex
        Screen('DrawTexture', wpnt, tex,[],eyeImageRect);
    end
    % draw buttons
    Screen('FillRect',wpnt,[0 120   0],continueButRect);
    DrawMonospacedText(continueButTextCache);
    Screen('FillRect',wpnt,eyeButClrs{logical(tex)+1},eyeImageButRect);
    DrawMonospacedText(eyeImageButTextCache);
    if tex
        Screen('FillRect',wpnt,eyeButClrs{overlays(1)+1},contourButRect);
        DrawMonospacedText(contourButTextCache);
        Screen('FillRect',wpnt,eyeButClrs{overlays(2)+1},pupilButRect);
        DrawMonospacedText(pupilButTextCache);
        Screen('FillRect',wpnt,eyeButClrs{overlays(3)+1},reflexButRect);
        DrawMonospacedText(reflexButTextCache);
    end
    % drawing done, show
    Screen('Flip',wpnt);

    % check for keypresses or button clicks
    [mx,my,buttons] = GetMouse;
    [~,~,keyCode] = KbCheck;
    % update cursor look if needed
    cursor.update(mx,my);
    if any(buttons)
        % don't care which button for now. determine if clicked on either
        % of the buttons
        qIn = inRect([mx my],[continueButRect.' eyeImageButRect.' contourButRect.' pupilButRect.' reflexButRect.']);
        if any(qIn)
            if qIn(1)
                status = 1;
                break;
            elseif ~eyeClickDown
                if qIn(2)
                    % show/hide eye image: reposition screen elements
                    qShowEyeImage       = ~qShowEyeImage;
                    qRecalculateRects   = true;     % can only do this when we know how large the image is
                elseif length(qIn)>2 && qIn(3)
                    overlays(1) = ~overlays(1);
                    iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',overlays(1));
                elseif length(qIn)>2 && qIn(4)
                    overlays(2) = ~overlays(2);
                    iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL',overlays(2));
                elseif length(qIn)>2 && qIn(5)
                    overlays(3) = ~overlays(3);
                    iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX',overlays(3));
                end
                eyeClickDown = any(qIn);
            end
        end
    elseif any(keyCode)
        keys = KbName(keyCode);
        if any(strcmpi(keys,'space'))
            status = 1;
            break;
        elseif any(strcmpi(keys,'escape')) && any(strcmpi(keys,'shift'))
            status = -2;
            break;
        elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
            % skip calibration
            iView.abortCalibration();
            status = 2;
            break;
        end
        if ~eyeKeyDown
            if any(strcmpi(keys,'e'))
                % show/hide eye image: reposition screen elements
                qShowEyeImage       = ~qShowEyeImage;
                qRecalculateRects   = true;     % can only do this when we know how large the image is
            elseif qShowEyeImage
                if any(strcmpi(keys,'c'))
                    overlays(1) = ~overlays(1);
                    iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',overlays(1));
                elseif any(strcmpi(keys,'p'))
                    overlays(2) = ~overlays(2);
                    iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL',overlays(2));
                elseif any(strcmpi(keys,'g'))
                    overlays(3) = ~overlays(3);
                    iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX',overlays(3));
                end
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
iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_CONTOUR',0);
iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_PUPIL',0);
iView.setTrackingParameter('ET_PARAM_EYE_BOTH','ET_PARAM_SHOW_REFLEX',0);
HideCursor;
end

function arrowColor = getArrowColor(posRating,thresh,col1,col2,col3)
if abs(posRating)>thresh(2)
    arrowColor = col3;
else
    arrowColor = col1+(abs(posRating)-thresh(1))./diff(thresh)*(col2-col1);
end
end

function drawEye(wpnt,validity,pos,posOther,relPos,clr1,clr2,sz,lbl,boxRect)
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

function status = DoCalAndValSMI(iView,startRecording,stopRecording,ETSendMessageFun)
% calibrate
startRecording(true);   % explicitly clear recording buffer
ETSendMessageFun('CALIBRATION START');
ret = iView.calibrate();
ETSendMessageFun('CALIBRATION END');
if ret==3       % RET_CALIBRATION_ABORTED
    status = -1;
    return;
elseif ret~=1
    error('SMI: error calibrating (error %d: %s)',ret,SMIErrCode2String(ret));
end
% validate
ETSendMessageFun('VALIDATION START');
ret = iView.validate();
ETSendMessageFun('VALIDATION END');
if ret==1
    status = 1;
elseif ret==3   % RET_CALIBRATION_ABORTED
    status = -1;
else
    error('SMI: error validating (error %d: %s)',ret,SMIErrCode2String(ret));
end
stopRecording();
end

function [status,out] = DoCalAndValPTB(wpnt,iView,calSetup,startRecording,stopRecording,ETSendMessageFun)
% disable SMI key listeners, we'll deal with key presses
iView.setUseCalibrationKeys(0);
%% calibrate
startRecording(true);   % explicitly clear recording buffer
% enter calibration mode
ETSendMessageFun('CALIBRATION START');
iView.calibrate();
% show display
[status,out.cal] = DoCalPointDisplay(wpnt,iView,calSetup,ETSendMessageFun);
ETSendMessageFun('CALIBRATION END');
if status~=1
    return;
end

%% validate
% enter validation mode
ETSendMessageFun('VALIDATION START');
iView.validate();
% show display
[status,out.val] = DoCalPointDisplay(wpnt,iView,calSetup,ETSendMessageFun);
ETSendMessageFun('VALIDATION END');
stopRecording();

% clear flip
Screen('Flip',wpnt);
end

function [status,out] = DoCalPointDisplay(wpnt,iView,calSetup,ETSendMessageFun)
% status output:
%  1: finished succesfully (you should query SMI software whether they think
%     calibration was succesful though)
%  2: skip calibration and continue with task (shift+s)
% -1: This calibration aborted/restart (escape key)
% -2: Exit completely (control+escape)

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

pCalibrationPoint = getSMIStructEnum('CalibrationPointStruct');
while true
    nextFlipT = out.flips(end)+1/1000;
    ret = iView.getCurrentCalibrationPoint(pCalibrationPoint);
    if ret==2   % RET_NO_VALID_DATA
        % calibration/validation finished
        Screen('Flip',wpnt);    % clear
        ETSendMessageFun(sprintf('POINT OFF %d',out.point(end)));
        status = 1;
        break;
    end
    pos = [pCalibrationPoint.positionX pCalibrationPoint.positionY];
    drawfixpoints(wpnt,pos,{'.','.'},{calSetup.fixBackSize calSetup.fixFrontSize},{calSetup.fixBackColor calSetup.fixFrontColor},1);
    
    out.point(end+1) = pCalibrationPoint.number;
    out.flips(end+1) = Screen('Flip',wpnt,nextFlipT);
    if out.point(end)~=out.point(end-1)
        ETSendMessageFun(sprintf('POINT ON %d (%d %d)',out.point(end),pos));
        out.pointPos(end+1,1:3) = [out.point(end) pos];
    end
    % check for keys
    [keyPressed,~,keyCode] = KbCheck();
    if keyPressed
        keys = KbName(keyCode);
        if any(strcmpi(keys,'space')) && pCalibrationPoint.number==1
            iView.acceptCalibrationPoint();
        elseif any(strcmpi(keys,'escape'))
            iView.abortCalibration();
            if any(strcmpi(keys,'shift'))
                status = -2;
            else
                status = -1;
            end
            break;
        elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
            % skip calibration
            iView.abortCalibration();
            status = 2;
            break;
        end
    end
end
end

function status = showValidateImage(wpnt,cal,scrInfo,textSetup)
% status output:
%  1: calibration/validation accepted, continue (a)
%  2: just continue with task (shift+s)
% -1: restart calibration (escape key)
% -2: Exit completely (control+escape)

% draw validation screen image
tex   = Screen('MakeTexture',wpnt,cal.validateImage,[],8);   % 8 to prevent mipmap generation, we don't need it
Screen('DrawTexture', wpnt, tex);   % its a fullscreen image, so just draw
% setup text
Screen('TextFont',  wpnt, textSetup.font);
Screen('TextSize',  wpnt, textSetup.size);
Screen('TextStyle', wpnt, textSetup.style);
% draw text with validation accuracy info
valText = sprintf('<size=20>Accuracy  <color=ff0000>Left<color>: <size=18><font=Georgia><i>X<i><font><size> = %.2f°, <size=18><font=Georgia><i>Y<i><font><size> = %.2f°\nAccuracy <color=00ff00>Right<color>: <size=18><font=Georgia><i>X<i><font><size> = %.2f°, <size=18><font=Georgia><i>Y<i><font><size> = %.2f°',cal.validateAccuracy.deviationLX,cal.validateAccuracy.deviationLY,cal.validateAccuracy.deviationRX,cal.validateAccuracy.deviationRY);
DrawMonospacedText(wpnt,valText,'center',100,0,[],textSetup.vSpacing);
% place buttons
yposBase = round(scrInfo.rect(2)*.95);
buttonSz  = [300 45];
buttonOff = 80;
baseRect= OffsetRect([0 0 buttonSz],scrInfo.center(1),yposBase-buttonSz(2)); % left is now at screen center, bottom at right height
acceptRect= OffsetRect(baseRect,-buttonOff/2-buttonSz(1),0);
recalRect = OffsetRect(baseRect, buttonOff/2            ,0);
% draw buttons
Screen('FillRect',wpnt,[0 120 0],acceptRect);
DrawMonospacedText(wpnt,'accept (<i>a<i>)'       ,'center','center',0,[],[],[],OffsetRect(acceptRect,0,textSetup.lineCentOff));
Screen('FillRect',wpnt,[150 0 0],recalRect);
DrawMonospacedText(wpnt,'recalibrate (<i>esc<i>)','center','center',0,[],[],[],OffsetRect(recalRect ,0,textSetup.lineCentOff));
% drawing done, show
Screen('Flip',wpnt);
% setup cursors
cursors.rect    = {acceptRect.',recalRect.'};
cursors.cursor  = [2 2];% Hand
cursors.other   = 0;    % Arrow
cursors.qReset  = false;
% NB: don't reset cursor to invisible here as it will then flicker every
% time you click something. default behaviour is good here

% get user response
while true
    [mouse,keyCode,which] = WaitClickOrButton(3,cursors);
    if which=='M'
        % don't care which button for now. determine if clicked on either
        % of the buttons
        qIn = inRect([mouse.x mouse.y],[acceptRect.' recalRect.']);
        if any(qIn)
            if qIn(1)
                status = 1;
            else
                status = -1;
            end
            break;
        end
    elseif which=='K'
        keys = KbName(keyCode);
        if any(strcmpi(keys,'a'))
            status = 1;
            break;
        elseif any(strcmpi(keys,'escape'))
            if any(strcmpi(keys,'shift'))
                status = -2;
            else
                status = -1;
            end
            break;
        elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
            % skip calibration
            iView.abortCalibration();
            status = 2;
            break;
        end
    end
end
% done, clean up
Screen('Close',tex);
HideCursor;
end
