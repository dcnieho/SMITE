% IVIEWXAPI provides a nice interface to the functions defined in
% iViewXAPIHeader
%
% Part of the SMITE toolbox (https://github.com/dcnieho/SMITE), but can be
% used independently. When using this convenience interface (which is
% recommended because of several fixes that have been made compared to the
% code released by SMI), please cite the following paper:
% Niehorster, D.C., & Nyström, M., (2019). SMITE: A toolbox for creating
% Psychtoolbox and Psychopy experiments with SMI eye trackers.
% doi: 10.3758/s13428-019-01226-0.

classdef iViewXAPI < handle
    methods
        function obj = iViewXAPI()
            % load dll if not yet loaded
            if ~libisloaded('iViewXAPI')
                input = {@iViewXAPIHeader,'alias','iViewXAPI'};
                if strcmp(computer('arch'), 'win64')
                    libfile = 'iViewXAPI64.dll';
                else
                    libfile = 'iViewXAPI.dll';
                end
                try
                    loadlibrary(libfile, input{:});
                catch %#ok<CTCH>
                    % iViewXAPI failed. Most likely cause would be "invalid
                    % MEX file error" due to iViewXAPI failing to link
                    % against required DLL's.
                    % The old drill: temporarily add (likely) location of
                    % DLL. Retry. If this was the culprit, then the linker
                    % should load, link and init iViewXAPI and we should
                    % succeed. Otherwise we fail again. Try some common
                    % paths...
                    if exist('C:\Program Files\SMI\iView X SDK\bin','dir')
                        temppath = 'C:\Program Files\SMI\iView X SDK\bin';
                    elseif exist('C:\Program Files (x86)\SMI\iView X SDK\bin','dir')
                        temppath = 'C:\Program Files (x86)\SMI\iView X SDK\bin';
                    else
                        error('failed to load %s, and cannot find it in common locations. Please make sure the iView X SDK is installed and that it''s bin directory is in the Windows path variable',libfile);
                    end
                    addpath(temppath);
                    loadlibrary(libfile, input{:});
                    rmpath(temppath);
                end
            end
        end
    end
    
    methods(Static) % this whole class is static, it has no state as it just forwards calls to the dll    
        function ret = abortCalibration()
            ret = calllib('iViewXAPI', 'iV_AbortCalibration');
        end
        
        function ret = abortCalibrationPoint()
            ret = calllib('iViewXAPI', 'iV_AbortCalibrationPoint');
        end
        
        function ret = acceptCalibrationPoint()
            ret = calllib('iViewXAPI', 'iV_AcceptCalibrationPoint');
        end
        
        function ret = calibrate()
            ret = calllib('iViewXAPI', 'iV_Calibrate');
        end
        
        function ret = changeCalibrationPoint(number, positionX , positionY)
            ret = calllib('iViewXAPI', 'iV_ChangeCalibrationPoint', number, positionX , positionY);
        end
        
        function ret = clearAOI()
            ret = calllib('iViewXAPI', 'iV_ClearAOI');
        end
        
        function ret = clearRecordingBuffer()
            ret = calllib('iViewXAPI', 'iV_ClearRecordingBuffer');
        end
        
        function ret = configureFilter(filter, action, data)
            % filter: enum FilterType
            % action: enum FilterAction
            ret = calllib('iViewXAPI', 'iV_ConfigureFilter', filter, action, data);
        end
        
        function ret = connect(sendIPAddress, sendPort, recvIPAddress, receivePort)
            ret = calllib('iViewXAPI', 'iV_Connect', sendIPAddress, sendPort, recvIPAddress, receivePort);
        end
        
        function ret = connectLocal()
            ret = calllib('iViewXAPI', 'iV_ConnectLocal');
        end
        
        function ret = continueEyetracking()
            ret = calllib('iViewXAPI', 'iV_ContinueEyetracking', etMessage);
        end
        
        function ret = continueRecording(etMessage)
            ret = calllib('iViewXAPI', 'iV_ContinueRecording', etMessage);
        end
        
        function ret = defineAOI(aoiData)
            % aoiData type: AOIStruct
            ret = calllib('iViewXAPI', 'iV_DefineAOI', aoiData);
        end
        
        function ret = defineAOIPort(port)
            ret = calllib('iViewXAPI', 'iV_DefineAOIPort', port);
        end
        
        function ret = deleteREDGeometry(setupName)
            ret = calllib('iViewXAPI', 'iV_DeleteREDGeometry', setupName);
        end
        
        function ret = disableAOI(aoiName)
            ret = calllib('iViewXAPI', 'iV_DisableAOI', aoiName);
        end
        
        function ret = disableAOIGroup(aoiGroup)
            ret = calllib('iViewXAPI', 'iV_DisableAOIGroup', aoiGroup);
        end
        
        function ret = disableGazeDataFilter()
            ret = calllib('iViewXAPI', 'iV_DisableGazeDataFilter');
        end
        
        function ret = disableProcessorHighPerformanceMode()
            ret = calllib('iViewXAPI', 'iV_DisableProcessorHighPerformanceMode');
        end
        
        function ret = disconnect()
            ret = calllib('iViewXAPI', 'iV_Disconnect');
        end
        
        function ret = enableAOI(aoiName)
            ret = calllib('iViewXAPI', 'iV_EnableAOI', aoiName);
        end
        
        function ret = enableAOIGroup(aoiGroup)
            ret = calllib('iViewXAPI', 'iV_EnableAOIGroup', aoiGroup);
        end
        
        function ret = enableGazeDataFilter()
            ret = calllib('iViewXAPI', 'iV_EnableGazeDataFilter');
        end
        
        function ret = enableProcessorHighPerformanceMode()
            ret = calllib('iViewXAPI', 'iV_EnableProcessorHighPerformanceMode');
        end
        
        function [ret,accuracy] = getAccuracy(pAccuracyData, visualization)
            if isempty(pAccuracyData)
                pAccuracyData = SMIStructEnum.Accuracy;
            end
            ret = calllib('iViewXAPI', 'iV_GetAccuracy', pAccuracyData, visualization);
            accuracy = struct(pAccuracyData);
        end
        
        function [ret,image] = getAccuracyImage(pImageData)
            if nargin==0
                pImageData = SMIStructEnum.Image;
            end
            ret = calllib('iViewXAPI', 'iV_GetAccuracyImage', pImageData);
            image = getImage(ret,pImageData,'BGR');
        end
        
        function ret = getAOIOutputValue(aoiOutputValue)
            ret = calllib('iViewXAPI', 'iV_GetAOIOutputValue', aoiOutputValue);
        end
        
        function [ret,LPTNames] = getAvailableLptPorts()
            bufSize         = 2048;
            [ret,LPTNames]  = calllib('iViewXAPI', 'iV_GetAvailableLptPorts', blanks(bufSize), bufSize);
        end
        
        function [ret,calibrationData] = getCalibrationParameter(pCalibrationData)
            if nargin==0
                pCalibrationData = SMIStructEnum.Calibration;
            end
            ret = calllib('iViewXAPI', 'iV_GetCalibrationParameter', pCalibrationData);
            calibrationData = struct(pCalibrationData);
        end
        
        function ret = getCalibrationPoint(calibrationPointNumber, calibrationPoint)
            ret = calllib('iViewXAPI', 'iV_GetCalibrationPoint', calibrationPointNumber, calibrationPoint);
        end
        
        function [ret,calibrationPointQualityLeft,calibrationPointQualityRight] = getCalibrationQuality(calibrationPointNumber, pCalibrationPointQualityLeft, pCalibrationPointQualityRight)
            if nargin<2
                pCalibrationPointQualityLeft  = SMIStructEnum.CalibrationPointQuality;
            end
            if nargin<3
                pCalibrationPointQualityRight = SMIStructEnum.CalibrationPointQuality;
            end
            ret = calllib('iViewXAPI', 'iV_GetCalibrationQuality', calibrationPointNumber, pCalibrationPointQualityLeft, pCalibrationPointQualityRight);
            calibrationPointQualityLeft  = struct(pCalibrationPointQualityLeft);
            calibrationPointQualityRight = struct(pCalibrationPointQualityRight);
        end
        
        function [ret,image] = getCalibrationQualityImage(pImageData)
            if nargin==0
                pImageData = SMIStructEnum.Image;
            end
            ret = calllib('iViewXAPI', 'iV_GetCalibrationQualityImage', pImageData);
            image = getImage(ret,pImageData,'BGR');
        end
        
        function [ret,calStatus] = getCalibrationStatus(calibrationStatus)
            if nargin==0
                calibrationStatus = SMIStructEnum.CalibrationStatus;
            end
            ret = calllib('iViewXAPI', 'iV_GetCalibrationStatus', calibrationStatus);
            calStatus = calibrationStatus.Value;
        end
        
        function ret = getCurrentCalibrationPoint(calibrationPoint)
            ret = calllib('iViewXAPI', 'iV_GetCurrentCalibrationPoint', calibrationPoint);
        end
        
        function [ret,redGeometry] = getCurrentREDGeometry(pRedGeometry)
            if nargin==0
                pRedGeometry = SMIStructEnum.REDGeometryStruct;
            end
            ret         = calllib('iViewXAPI', 'iV_GetCurrentREDGeometry', pRedGeometry);
            redGeometry = struct(pRedGeometry);
        end
        
        function [ret,time] = getCurrentTimestamp()
            pTime   = libpointer('int64Ptr',int64(0));
            ret     = calllib('iViewXAPI', 'iV_GetCurrentTimestamp', pTime);
            
            time = [];
            if ret==1
                time    = pTime.Value;
            end
        end
        
        function [ret,name] = getDeviceName()
            pName   = libpointer('voidPtr',zeros(1,64,'uint8'));
            ret     = calllib('iViewXAPI', 'iV_GetDeviceName', pName);
            name    = '';
            if ret==1
                name  = char(pName.Value);
                name(name==0) = [];
            end
        end
        
        function [ret,eventDataSample] = getEvent(pEventDataSample)
            if nargin==0
                pEventDataSample = SMIStructEnum.Event;
            end
            ret = calllib('iViewXAPI', 'iV_GetEvent', pEventDataSample);
            eventDataSample = struct(pEventDataSample);
        end
        
        function [ret,eventDataSample] = getEvent32(pEventDataSample)
            if nargin==0
                pEventDataSample = SMIStructEnum.Event32;
            end
            ret = calllib('iViewXAPI', 'iV_GetEvent32', pEventDataSample);
            eventDataSample = struct(pEventDataSample);
        end
        
        function [ret,image] = getEyeImage(pImageData)
            if nargin==0
                pImageData = SMIStructEnum.Image;
            end
            ret = calllib('iViewXAPI', 'iV_GetEyeImage', pImageData);
            image = getImage(ret,pImageData,'mono');
        end
        
        function [ret,key] = getFeatureKey()
            pKey    = libpointer('int64Ptr',int64(0));
            ret     = calllib('iViewXAPI', 'iV_GetFeatureKey', pKey);
            
            key = [];
            if ret==1
                key    = pKey.Value;
            end
        end
        
        function [ret,qualityData] = getGazeChannelQuality(pQualityData)
            if nargin==0
                pQualityData = SMIStructEnum.GazeChannelQuality;
            end
            ret = calllib('iViewXAPI', 'iV_GetGazeChannelQuality', pQualityData);
            qualityData = struct(pQualityData);
        end
        
        function [ret,profNames] = getGeometryProfiles()
            bufSize             = 2048;
            [ret,profNames]     = calllib('iViewXAPI', 'iV_GetGeometryProfiles', bufSize, blanks(bufSize));
        end
        
        function [ret,licenseDueDate] = getLicenseDueDate(pLicenseDueDate)
            if nargin==0
                pLicenseDueDate = SMIStructEnum.GazeChannelQuality;
            end
            ret = calllib('iViewXAPI', 'iV_GetLicenseDueDate', pLicenseDueDate);
            licenseDueDate = struct(pLicenseDueDate);
        end
        
        function [ret,recordingState] = getRecordingState(pRecordingState)
            if nargin==0
                pRecordingState = SMIStructEnum.RecordingState;
            end
            ret = calllib('iViewXAPI', 'iV_GetRecordingState', pRecordingState);
            recordingState = struct(pRecordingState);
        end
        
        function [ret,redGeometry] = getREDGeometry(profileName,pRedGeometry)
            if nargin<2
                pRedGeometry = SMIStructEnum.REDGeometryStruct;
            end
            ret = calllib('iViewXAPI', 'iV_GetREDGeometry', profileName, pRedGeometry);
            redGeometry = struct(pRedGeometry);
        end
        
        function [ret,sample] = getSample(pSampleData)
            if nargin==0
                pSampleData = SMIStructEnum.Sample;
            end
            ret = calllib('iViewXAPI', 'iV_GetSample', pSampleData);
            sample = struct(pSampleData);
        end
        
        function [ret,sample] = getSample32(pSampleData)
            if nargin==0
                pSampleData = SMIStructEnum.Sample32;
            end
            ret = calllib('iViewXAPI', 'iV_GetSample32', pSampleData);
            sample = struct(pSampleData);
        end
        
        function [ret,image] = getSceneVideo(pImageData)
            if nargin==0
                pImageData = SMIStructEnum.Image;
            end
            ret = calllib('iViewXAPI', 'iV_GetSceneVideo', pImageData);
            image = getImage(ret,pImageData,'RGB');
        end
        
        function [ret,serial] = getSerialNumber()
            pSerial = libpointer('voidPtr',zeros(1,64,'uint8'));
            ret     = calllib('iViewXAPI', 'iV_GetSerialNumber', pSerial);
            serial  = '';
            if ret==1
                serial  = char(pSerial.Value);
                serial(serial==0) = [];
            end
        end
        
        function [ret,speedModes] = getSpeedModes(pSpeedModes)
            if nargin==0
                pSpeedModes = SMIStructEnum.SpeedMode;
            end
            ret = calllib('iViewXAPI', 'iV_GetSpeedModes', pSpeedModes);
            speedModes = struct(pSpeedModes);
        end
        
        function [ret,sysInfo] = getSystemInfo(pSystemInfoData)
            if nargin==0
                pSystemInfoData = SMIStructEnum.SystemInfo;
            end
            ret = calllib('iViewXAPI', 'iV_GetSystemInfo', pSystemInfoData);
            sysInfo = struct(pSystemInfoData);
        end
        
        function [ret,mode] = getTrackingMode(trackingMode)
            if nargin==0
                trackingMode = SMIStructEnum.TrackingMode;
            end
            ret = calllib('iViewXAPI', 'iV_GetTrackingMode', trackingMode);
            mode = trackingMode.Value;
        end
        
        function [ret,image] = getTrackingMonitor(pImageData)
            ret = calllib('iViewXAPI', 'iV_GetTrackingMonitor', pImageData);
            image = getImage(ret,pImageData,'BGR');
        end
        
        function [ret,tStatus] = getTrackingStatus(pTrackingStatus)
            if nargin==0
                pTrackingStatus = SMIStructEnum.TrackingStatus;
            end
            ret = calllib('iViewXAPI', 'iV_GetTrackingStatus', pTrackingStatus);
            tStatus = struct(pTrackingStatus);
        end
        
        function [ret,enableKeys] = getUseCalibrationKeys()
            pKey    = libpointer('int32Ptr',int32(0));
            ret     = calllib('iViewXAPI', 'iV_GetUseCalibrationKeys', pKey);
            
            enableKeys = [];
            if ret==1
                enableKeys    = pKey.Value;
            end
        end
        
        function ret = hideAccuracyMonitor()
            ret = calllib('iViewXAPI', 'iV_HideAccuracyMonitor');
        end
        
        function ret = hideEyeImageMonitor()
            ret = calllib('iViewXAPI', 'iV_HideEyeImageMonitor');
        end
        
        function ret = hideSceneVideoMonitor()
            ret = calllib('iViewXAPI', 'iV_HideSceneVideoMonitor');
        end
        
        function ret = hideTrackingMonitor()
            ret = calllib('iViewXAPI', 'iV_HideTrackingMonitor');
        end
        
        function ret = isConnected()
            ret = calllib('iViewXAPI', 'iV_IsConnected');
        end
        
        function ret = loadCalibration(name)
            ret = calllib('iViewXAPI', 'iV_LoadCalibration', name);
        end
        
        function ret = log(logMessage)
            ret = calllib('iViewXAPI', 'iV_Log', logMessage);
        end
        
        function ret = pauseEyetracking()
            ret = calllib('iViewXAPI', 'iV_PauseEyetracking');
        end
        
        function ret = pauseRecording()
            ret = calllib('iViewXAPI', 'iV_PauseRecording');
        end
        
        function ret = quit()
            ret = calllib('iViewXAPI', 'iV_Quit');
        end
        
        function ret = recalibrateOnePoint(number)
            ret = calllib('iViewXAPI', 'iV_RecalibrateOnePoint', number);
        end
        
        function ret = releaseAOIPort()
            ret = calllib('iViewXAPI', 'iV_ReleaseAOIPort');
        end
        
        function ret = removeAOI(aoiName)
            ret = calllib('iViewXAPI', 'iV_RemoveAOI', aoiName);
        end
        
        function ret = resetCalibrationPoints()
            ret = calllib('iViewXAPI', 'iV_ResetCalibrationPoints');
        end
        
        function ret = saveCalibration(name)
            ret = calllib('iViewXAPI', 'iV_SaveCalibration', name);
        end
        
        function ret = saveData(filename, description, user, overwrite)
            ret = calllib('iViewXAPI', 'iV_SaveData', filename, description, user, overwrite);
        end
        
        function ret = selectREDGeometry(profileName)
            ret = calllib('iViewXAPI', 'iV_SelectREDGeometry', profileName);
        end
        
        function ret = sendCommand(etMessage)
            ret = calllib('iViewXAPI', 'iV_SendCommand', etMessage);
        end
        
        function ret = sendImageMessage(etMessage)
            ret = calllib('iViewXAPI', 'iV_SendImageMessage', etMessage);
        end
        
        function ret = setConnectionTimeout(time)
            ret = calllib('iViewXAPI', 'iV_SetConnectionTimeout', time);
        end
        
        function ret = setEventDetectionParameter(minDuration, maxDispersion)
            ret = calllib('iViewXAPI', 'iV_SetEventDetectionParameter', minDuration, maxDispersion);
        end
        
        function ret = setLicense(licenseKey)
            ret = calllib('iViewXAPI', 'iV_SetLicense', licenseKey);
        end
        
        function ret = setLogger(logLevel,filename)
            ret = calllib('iViewXAPI', 'iV_SetLogger', logLevel, filename);
        end
        
        function ret = setREDGeometry(redGeometry)
            % redGeometry type: REDGeometryStruct
            ret = calllib('iViewXAPI', 'iV_SetREDGeometry', redGeometry);
        end
        
        function ret = setResolution(stimulusWidth, stimulusHeight)
            ret = calllib('iViewXAPI', 'iV_SetResolution', stimulusWidth, stimulusHeight);
        end
        
        function ret = setSpeedMode(speedMode)
            ret = calllib('iViewXAPI', 'iV_SetSpeedMode', speedMode);
        end
        
        function ret = setTrackingMode(mode)
            % type mode: enum TrackingMode
            ret = calllib('iViewXAPI', 'iV_SetTrackingMode', mode);
        end
        
        function ret = setTrackingParameter(ET_PARAM_EYE, ET_PARAM, value)
            % for ET_PARAM_EYE and ET_PARAM, can input the string values in the map
            % below, or the corresponding numerical values directly
            map = {
                'ET_PARAM_EYE_LEFT',0
                'ET_PARAM_EYE_RIGHT',1
                'ET_PARAM_EYE_BOTH',2
                
                'ET_PARAM_PUPIL_THRESHOLD',0
                'ET_PARAM_REFLEX_THRESHOLD',1
                'ET_PARAM_SHOW_AOI',2
                'ET_PARAM_SHOW_CONTOUR',3
                'ET_PARAM_SHOW_PUPIL',4
                'ET_PARAM_SHOW_REFLEX',5
                'ET_PARAM_DYNAMIC_THRESHOLD',6
                
                'ET_PARAM_PUPIL_AREA',11
                'ET_PARAM_PUPIL_PERIMETER',12
                'ET_PARAM_PUPIL_DENSITY',13
                'ET_PARAM_REFLEX_PERIMETER',14
                'ET_PARAM_REFLEX_PUPIL_DISTANCE',15
                'ET_PARAM_MONOCULAR',16
                'ET_PARAM_SMARTBINOCULAR',17
                'ET_PARAM_BINOCULAR',18
                'ET_PARAM_SMARTTRACKING',19};
            % these are not enums sadly, but macro defs. Search in map for corresponding value
            if ischar(ET_PARAM_EYE)
                qFound = strcmp(ET_PARAM_EYE,map(:,1));
                assert(sum(qFound)==1,'SMI iV_SetTrackingParameter: The EyeTrackingParameter "%s" is not understood',ET_PARAM_EYE)
                ET_PARAM_EYE = map{qFound,2};
            end
            if ischar(ET_PARAM)
                qFound = strcmp(ET_PARAM,map(:,1));
                assert(sum(qFound)==1,'SMI iV_SetTrackingParameter: The EyeTrackingParameter "%s" is not understood',ET_PARAM)
                ET_PARAM = map{qFound,2};
            end
            ret = calllib('iViewXAPI', 'iV_SetTrackingParameter', ET_PARAM_EYE, ET_PARAM, value);
        end
        
        function ret = setupCalibration(pCalibrationData)
            ret = calllib('iViewXAPI', 'iV_SetupCalibration', pCalibrationData);
        end
        
        function ret = setupDebugMode(enableDebugMode)
            ret = calllib('iViewXAPI', 'iV_SetupDebugMode', enableDebugMode);
        end
        
        function ret = setupLptRecording(portName, enableRecording)
            ret = calllib('iViewXAPI', 'iV_SetupLptRecording', portName, enableRecording);
        end
        
        function ret = setUseCalibrationKeys(enableKeys)
            ret = calllib('iViewXAPI', 'iV_SetUseCalibrationKeys', enableKeys);
        end
        
        function ret = showAccuracyMonitor()
            ret = calllib('iViewXAPI', 'iV_ShowAccuracyMonitor');
        end
        
        function ret = showEyeImageMonitor()
            ret = calllib('iViewXAPI', 'iV_ShowEyeImageMonitor');
        end
        
        function ret = showSceneVideoMonitor()
            ret = calllib('iViewXAPI', 'iV_ShowSceneVideoMonitor');
        end
        
        function ret = showTrackingMonitor()
            ret = calllib('iViewXAPI', 'iV_ShowTrackingMonitor');
        end
        
        function ret = start(etApplication)
            % etApplication type: enum ETApplication
            ret = calllib('iViewXAPI', 'iV_Start', etApplication);
        end
        
        function ret = startRecording()
            ret = calllib('iViewXAPI', 'iV_StartRecording');
        end
        
        function ret = stopRecording()
            ret = calllib('iViewXAPI', 'iV_StopRecording');
        end
        
        function ret = testTTL(value)
            ret = calllib('iViewXAPI', 'iV_TestTTL', value);
        end
        
        function ret = validate()
            ret = calllib('iViewXAPI', 'iV_Validate');
        end
        
        function ret = setupMonitorAttachedGeometry(monitorAttachedGeometry)
            % monitorAttachedGeometry type: MonitorAttachedGeometryStruct
            ret = calllib('iViewXAPI', 'iV_SetupMonitorAttachedGeometry', monitorAttachedGeometry);
        end
        
        function ret = setupStandAloneMode(standAloneModeGeometry)
            % standAloneModeGeometry type: StandAloneModeGeometryStruct
            ret = calllib('iViewXAPI', 'iV_SetupStandAloneMode', standAloneModeGeometry);
        end
        
        function ret = setupREDMonitorAttachedGeometry(attachedModeGeometry)
            % attachedModeGeometry type: REDMonitorAttachedGeometryStruct
            ret = calllib('iViewXAPI', 'iV_SetupREDMonitorAttachedGeometry', attachedModeGeometry);
        end
        
        function ret = setupREDStandAloneMode(standAloneModeGeometry)
            % standAloneModeGeometry type: REDStandAloneModeStruct
            ret = calllib('iViewXAPI', 'iV_SetupREDStandAloneMode', standAloneModeGeometry);
        end
        
        function [ret,monitorAttachedGeometry] = getMonitorAttachedGeometry(profileName, pMonitorAttachedGeometry)
            if nargin==0
                pMonitorAttachedGeometry = SMIStructEnum.TrackingStatus;
            end
            ret = calllib('iViewXAPI', 'iV_GetMonitorAttachedGeometry', profileName, pMonitorAttachedGeometry);
            monitorAttachedGeometry = struct(pMonitorAttachedGeometry);
        end
        
        function ret = setGeometryProfile(profileName)
            ret = calllib('iViewXAPI', 'iV_SetGeometryProfile', profileName);
        end
        
        function ret = deleteMonitorAttachedGeometry(setupName)
            ret = calllib('iViewXAPI', 'iV_DeleteMonitorAttachedGeometry', setupName);
        end
        
        function ret = deleteStandAloneGeometry(setupName)
            ret = calllib('iViewXAPI', 'iV_DeleteStandAloneGeometry', setupName);
        end
    end
end


% helpers
function image = getImage(ret,pImageData,type)
if ret~=1
    image = [];
    return;
end
% tell matlab how many elements there are to read
if isa(pImageData.imageBuffer,'lib.pointer')
    pImageData.imageBuffer.setdatatype(pImageData.imageBuffer.DataType,1,pImageData.imageSize);
else
    assert(numel(pImageData.imageBuffer)==pImageData.imageSize,'You can only reuse ImageStructs for images of same size')
end

% get image data to manipulate. NB: do not write to pImageData.imageBuffer,
% or you'l leak the original buffer!
image = pImageData.imageBuffer;

switch type
    case 'mono'
        % iV_GetEyeImage
        %
        % grayscale, one row of pixels at a time. Transpose to conform with
        % matlab conventions.
        image = reshape(image,pImageData.imageWidth,pImageData.imageHeight).';
    case 'BGR'
        % iV_GetTrackingMonitor, iV_GetAccuracyImage,
        % iV_GetCalibrationQualityImage
        %
        % BGR format, [B G R B G R ...] one row of pixels at a time. Turn
        % into three planes and then flip(...,3) to change BGR into RGB
        image = flip(permute(...
            reshape(image,3,pImageData.imageWidth,pImageData.imageHeight),...
            [3 2 1]),3);
    case 'RGB'
        % iV_GetSceneVideo
        %
        % untested. HED not supported by us. But this should probably do
        % the trick
        image = permute(...
            reshape(image,3,pImageData.imageWidth,pImageData.imageHeight),...
            [3 2 1]);
end
end