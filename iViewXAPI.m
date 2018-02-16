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
                    % iViewXAPI failed. Most likely cause would be "invalid MEX file
                    % error" due to iViewXAPI failing to link against required DLL's.
                    % The old drill: cd into (likely) location of DLL. Retry. If this
                    % was the culprit, then the linker should load, link and init
                    % iViewXAPI and we should succeed. Otherwise we fail again. Try
                    % some common paths...
                    wd = pwd;
                    if exist('C:\Program Files\SMI\iView X SDK\bin','dir')
                        cd('C:\Program Files\SMI\iView X SDK\bin');
                    elseif exist('C:\Program Files (x86)\SMI\iView X SDK\bin','dir')
                        cd('C:\Program Files (x86)\SMI\iView X SDK\bin');
                    else
                        error('failed to load iViewXAPI.dll, and cannot find it in common locations. Please make sure the iView X SDK is installed and that it''s bin directory is in the Windows path variable')
                    end
                    loadlibrary(libfile, input{:});
                    cd(wd);
                end
            end
        end
    end
    
    methods(Static) % this whole class is static, it has no state as it just forwards calls to the dll    
        function f = iViewXAPIdinkum()
            % still to implement...
            f.abortCalibrationPoint                 = @iV_AbortCalibrationPoint;
            f.changeCalibrationPoint                = @iV_ChangeCalibrationPoint;
            f.clearAOI                              = @iV_ClearAOI;
            f.continueEyetracking                   = @iV_ContinueEyetracking;
            f.defineAOI                             = @iV_DefineAOI;
            f.defineAOIPort                         = @iV_DefineAOIPort;
            f.deleteREDGeometry                     = @iV_DeleteREDGeometry;
            f.disableAOI                            = @iV_DisableAOI;
            f.disableAOIGroup                       = @iV_DisableAOIGroup;
            f.disableGazeDataFilter                 = @iV_DisableGazeDataFilter;
            f.disableProcessorHighPerformanceMode   = @iV_DisableProcessorHighPerformanceMode;
            f.enableAOI                             = @iV_EnableAOI;
            f.enableAOIGroup                        = @iV_EnableAOIGroup;
            f.enableGazeDataFilter                  = @iV_EnableGazeDataFilter;
            f.enableProcessorHighPerformanceMode    = @iV_EnableProcessorHighPerformanceMode;
            f.getAOIOutputValue                     = @iV_GetAOIOutputValue;
            f.getAvailableLptPorts                  = @iV_GetAvailableLptPorts;
            f.getCalibrationParameter               = @iV_GetCalibrationParameter;
            f.getCalibrationQuality                 = @iV_GetCalibrationQuality;
            f.getCalibrationQualityImage            = @iV_GetCalibrationQualityImage;
            f.getCurrentTimestamp                   = @iV_GetCurrentTimestamp;
            f.getDeviceName                         = @iV_GetDeviceName;
            f.getEvent                              = @iV_GetEvent;
            f.getEvent32                            = @iV_GetEvent32;
            f.getFeatureKey                         = @iV_GetFeatureKey;
            f.getGazeChannelQuality                 = @iV_GetGazeChannelQuality;
            f.getGeometryProfiles                   = @iV_GetGeometryProfiles;
            f.getLicenseDueDate                     = @iV_GetLicenseDueDate;
            f.getRecordingState                     = @iV_GetRecordingState;
            f.getREDGeometry                        = @iV_GetREDGeometry;
            f.getSample32                           = @iV_GetSample32;
            f.getSceneVideo                         = @iV_GetSceneVideo;
            f.getSerialNumber                       = @iV_GetSerialNumber;
            f.getSpeedModes                         = @iV_GetSpeedModes;
            f.getTrackingMode                       = @iV_GetTrackingMode;
            f.getUseCalibrationKeys                 = @iV_GetUseCalibrationKeys;
            f.hideAccuracyMonitor                   = @iV_HideAccuracyMonitor;
            f.hideEyeImageMonitor                   = @iV_HideEyeImageMonitor;
            f.hideSceneVideoMonitor                 = @iV_HideSceneVideoMonitor;
            f.hideTrackingMonitor                   = @iV_HideTrackingMonitor;
            f.log                                   = @iV_Log;
            f.pauseEyetracking                      = @iV_PauseEyetracking;
            f.quit                                  = @iV_Quit;
            f.recalibrateOnePoint                   = @iV_RecalibrateOnePoint;
            f.releaseAOIPort                        = @iV_ReleaseAOIPort;
            f.removeAOI                             = @iV_RemoveAOI;
            f.resetCalibrationPoints                = @iV_ResetCalibrationPoints;
            f.sendCommand                           = @iV_SendCommand;
            f.setEventDetectionParameter            = @iV_SetEventDetectionParameter;
            f.setLicense                            = @iV_SetLicense;
            f.setREDGeometry                        = @iV_SetREDGeometry;
            f.setResolution                         = @iV_SetResolution;
            f.setSpeedMode                          = @iV_SetSpeedMode;
            f.setTrackingMode                       = @iV_SetTrackingMode;
            f.setupLptRecording                     = @iV_SetupLptRecording;
            f.showAccuracyMonitor                   = @iV_ShowAccuracyMonitor;
            f.showEyeImageMonitor                   = @iV_ShowEyeImageMonitor;
            f.showSceneVideoMonitor                 = @iV_ShowSceneVideoMonitor;
            f.showTrackingMonitor                   = @iV_ShowTrackingMonitor;
            f.testTTL                               = @iV_TestTTL;
            f.setupMonitorAttachedGeometry          = @iV_SetupMonitorAttachedGeometry;
            f.setupStandAloneMode                   = @iV_SetupStandAloneMode;
            f.setupREDMonitorAttachedGeometry       = @iV_SetupREDMonitorAttachedGeometry;
            f.setupREDStandAloneMode                = @iV_SetupREDStandAloneMode;
            f.getMonitorAttachedGeometry            = @iV_GetMonitorAttachedGeometry;
            f.setGeometryProfile                    = @iV_SetGeometryProfile;
            f.deleteMonitorAttachedGeometry         = @iV_DeleteMonitorAttachedGeometry;
            f.deleteStandAloneGeometry              = @iV_DeleteStandAloneGeometry;
            
        end
        
        function ret = abortCalibration()
            ret = calllib('iViewXAPI', 'iV_AbortCalibration');
        end
        
        function ret = acceptCalibrationPoint()
            ret = calllib('iViewXAPI', 'iV_AcceptCalibrationPoint');
        end
        
        function ret = calibrate()
            ret = calllib('iViewXAPI', 'iV_Calibrate');
        end
        
        function ret = clearRecordingBuffer()
            ret = calllib('iViewXAPI', 'iV_ClearRecordingBuffer');
        end
        
        function ret = configureFilter(filter, action, data)
            ret = calllib('iViewXAPI', 'iV_ConfigureFilter', filter, action, data);
        end
        
        function ret = connect(sendIPAddress, sendPort, recvIPAddress, receivePort)
            ret = calllib('iViewXAPI', 'iV_Connect', sendIPAddress, sendPort, recvIPAddress, receivePort);
        end
        
        function ret = connectLocal()
            ret = calllib('iViewXAPI', 'iV_ConnectLocal');
        end
        
        function ret = continueRecording(etMessage)
            ret = calllib('iViewXAPI', 'iV_ContinueRecording', etMessage);
        end
        
        function ret = disconnect()
            ret = calllib('iViewXAPI', 'iV_Disconnect');
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
        
        function ret = getCurrentCalibrationPoint(calibrationPoint)
            ret = calllib('iViewXAPI', 'iV_GetCurrentCalibrationPoint', calibrationPoint);
        end
        
        function [ret,geom] = getCurrentREDGeometry(redGeometry)
            if nargin==0
                redGeometry = SMIStructEnum.REDGeometryStruct;
            end
            ret  = calllib('iViewXAPI', 'iV_GetCurrentREDGeometry', redGeometry);
            geom = struct(redGeometry);
        end
        
        function ret = getCalibrationPoint(calibrationPointNumber, calibrationPoint)
            ret = calllib('iViewXAPI', 'iV_GetCalibrationPoint', calibrationPointNumber, calibrationPoint);
        end
        
        function [ret,calStatus] = getCalibrationStatus(calibrationStatus)
            if nargin==0
                calibrationStatus = SMIStructEnum.CalibrationStatus;
            end
            ret = calllib('iViewXAPI', 'iV_GetCalibrationStatus', calibrationStatus);
            calStatus = calibrationStatus.Value;
        end
        
        function [ret,image] = getEyeImage(pImageData)
            if nargin==0
                pImageData = SMIStructEnum.Image;
            end
            ret = calllib('iViewXAPI', 'iV_GetEyeImage', pImageData);
            image = getImage(ret,pImageData,'mono');
        end
        
        function [ret,sample] = getSample(pSampleData)
            if nargin==0
                pSampleData = SMIStructEnum.Sample;
            end
            ret = calllib('iViewXAPI', 'iV_GetSample', pSampleData);
            sample = struct(pSampleData);
        end
        
        function [ret,sysInfo] = getSystemInfo(pSystemInfoData)
            if nargin==0
                pSystemInfoData = SMIStructEnum.SystemInfo;
            end
            ret = calllib('iViewXAPI', 'iV_GetSystemInfo', pSystemInfoData);
            sysInfo = struct(pSystemInfoData);
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
        
        function ret = isConnected()
            ret = calllib('iViewXAPI', 'iV_IsConnected');
        end
        
        function ret = loadCalibration(name)
            ret = calllib('iViewXAPI', 'iV_LoadCalibration', name);
        end
        
        function ret = pauseRecording()
            ret = calllib('iViewXAPI', 'iV_PauseRecording');
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
        
        function ret = sendImageMessage(etMessage)
            ret = calllib('iViewXAPI', 'iV_SendImageMessage', etMessage);
        end
        
        function ret = setConnectionTimeout(time)
            ret = calllib('iViewXAPI', 'iV_SetConnectionTimeout', time);
        end
        
        function ret = setLogger(logLevel,filename)
            ret = calllib('iViewXAPI', 'iV_SetLogger', logLevel, filename);
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
        
        function ret = setUseCalibrationKeys(enableKeys)
            ret = calllib('iViewXAPI', 'iV_SetUseCalibrationKeys', enableKeys);
        end
        
        function ret = start(etApplication)
            ret = calllib('iViewXAPI', 'iV_Start', etApplication);
        end
        
        function ret = startRecording()
            ret = calllib('iViewXAPI', 'iV_StartRecording');
        end
        
        function ret = stopRecording()
            ret = calllib('iViewXAPI', 'iV_StopRecording');
        end
        
        function ret = validate()
            ret = calllib('iViewXAPI', 'iV_Validate');
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
        % untested/implemented. HED not supported by us
end
end