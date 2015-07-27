% If function is not listed, use 'calllib' function to call it, or the o()
% fhndl with the function to call as string in the first input

% To list the available function use 'libfunctions iViewXAPI'


function f = iViewXAPI()
f.abortCalibration              = @iV_AbortCalibration;
f.acceptCalibrationPoint        = @iV_AcceptCalibrationPoint;
f.calibrate                     = @iV_Calibrate;
f.clearRecordingBuffer          = @iV_ClearRecordingBuffer;
f.configureFilter               = @iV_ConfigureFilter;
f.connect                       = @iV_Connect;
f.connectLocal                  = @iV_ConnectLocal;
f.continueRecording             = @iV_ContinueRecording;
f.disconnect                    = @iV_Disconnect;
f.getAccuracy                   = @iV_GetAccuracy;
f.getAccuracyImage              = @iV_GetAccuracyImage;
f.getCalibrationPoint           = @iV_GetCalibrationPoint;
f.getCalibrationStatus          = @iV_GetCalibrationStatus;
f.getCurrentCalibrationPoint    = @iV_GetCurrentCalibrationPoint;
f.getCurrentREDGeometry         = @iV_GetCurrentREDGeometry;
f.getEyeImage                   = @iV_GetEyeImage;
f.getSample                     = @iV_GetSample;
f.getSystemInfo                 = @iV_GetSystemInfo;
f.getTrackingMonitor            = @iV_GetTrackingMonitor;
f.getTrackingStatus             = @iV_GetTrackingStatus;
f.pauseRecording                = @iV_PauseRecording;
f.isConnected                   = @iV_IsConnected;
f.saveData                      = @iV_SaveData;
f.selectREDGeometry             = @iV_SelectREDGeometry;
f.sendImageMessage              = @iV_SendImageMessage;
f.setConnectionTimeout          = @iV_SetConnectionTimeout;
f.setLogger                     = @iV_SetLogger;
f.setTrackingParameter          = @iV_SetTrackingParameter;
f.setupCalibration              = @iV_SetupCalibration;
f.setupDebugMode                = @iV_SetupDebugMode;
f.setUseCalibrationKeys         = @iV_SetUseCalibrationKeys;
f.start                         = @iV_Start;
f.startRecording                = @iV_StartRecording;
f.stopRecording                 = @iV_StopRecording;
f.validate                      = @iV_Validate;
% for functions not specifically implemented in wrapper
f.o                             = @iV_Other;
end


% for functions not specifically implemented below
function ret = iV_Other(fun,varargin)
ret = calllib('iViewXAPI', fun, varargin{:});
end


function ret = iV_AbortCalibration()
ret = calllib('iViewXAPI', 'iV_AbortCalibration');
end

function ret = iV_AcceptCalibrationPoint()
ret = calllib('iViewXAPI', 'iV_AcceptCalibrationPoint');
end

function ret = iV_Calibrate()
ret = calllib('iViewXAPI', 'iV_Calibrate');
end

function ret = iV_ClearRecordingBuffer()
ret = calllib('iViewXAPI', 'iV_ClearRecordingBuffer');
end

function ret = iV_ConfigureFilter(filter, action, data)
ret = calllib('iViewXAPI', 'iV_ConfigureFilter', filter, action, data);
end

function ret = iV_Connect(sendIPAddress, sendPort, recvIPAddress, receivePort)
ret = calllib('iViewXAPI', 'iV_Connect', sendIPAddress, sendPort, recvIPAddress, receivePort);
end

function ret = iV_ConnectLocal
ret = calllib('iViewXAPI', 'iV_ConnectLocal');
end

function ret = iV_ContinueRecording(etMessage)
ret = calllib('iViewXAPI', 'iV_ContinueRecording', etMessage);
end

function ret = iV_Disconnect()
ret = calllib('iViewXAPI', 'iV_Disconnect');
end

function [ret,accuracy] = iV_GetAccuracy(pAccuracyData, visualization)
if isempty(pAccuracyData)
    pAccuracyData = getSMIStructEnum('AccuracyStruct');
end
ret = calllib('iViewXAPI', 'iV_GetAccuracy', pAccuracyData, visualization);
accuracy = struct(pAccuracyData);
end

function [ret,image] = iV_GetAccuracyImage(pImageData)
if nargin==0
    pImageData = getSMIStructEnum('ImageStruct');
end
ret = calllib('iViewXAPI', 'iV_GetAccuracyImage', pImageData);
image = getImage(ret,pImageData);
end

function ret = iV_GetCurrentCalibrationPoint(calibrationPoint)
ret = calllib('iViewXAPI', 'iV_GetCurrentCalibrationPoint', calibrationPoint);
end

function [ret,geom] = iV_GetCurrentREDGeometry(redGeometry)
if nargin==0
    redGeometry = getSMIStructEnum('REDGeometryStruct');
end
ret  = calllib('iViewXAPI', 'iV_GetCurrentREDGeometry', redGeometry);
geom = struct(redGeometry);
end

function ret = iV_GetCalibrationPoint(calibrationPointNumber, calibrationPoint)
ret = calllib('iViewXAPI', 'iV_GetCalibrationPoint', calibrationPointNumber, calibrationPoint);
end

function [ret,calStatus] = iV_GetCalibrationStatus(calibrationStatus)
if nargin==0
    calibrationStatus = getSMIStructEnum('CalibrationStatusEnum');
end
ret = calllib('iViewXAPI', 'iV_GetCalibrationStatus', calibrationStatus);
calStatus = calibrationStatus.Value;
end

function [ret,image] = iV_GetEyeImage(pImageData)
if nargin==0
    pImageData = getSMIStructEnum('ImageStruct');
end
ret = calllib('iViewXAPI', 'iV_GetEyeImage', pImageData);
image = getImage(ret,pImageData);
end

function [ret,sample] = iV_GetSample(pSampleData)
if nargin==0
    pSampleData = getSMIStructEnum('SampleStruct');
end
ret = calllib('iViewXAPI', 'iV_GetSample', pSampleData);
sample = struct(pSampleData);
end

function [ret,sysInfo] = iV_GetSystemInfo(pSystemInfoData)
if nargin==0
    pSystemInfoData = getSMIStructEnum('SystemInfoStruct');
end
ret = calllib('iViewXAPI', 'iV_GetSystemInfo', pSystemInfoData);
sysInfo = struct(pSystemInfoData);
end

function [ret,image] = iV_GetTrackingMonitor(pImageData)
ret = calllib('iViewXAPI', 'iV_GetTrackingMonitor', pImageData);
image = getImage(ret,pImageData);
end

function [ret,tStatus] = iV_GetTrackingStatus(pTrackingStatus)
if nargin==0
    pTrackingStatus = getSMIStructEnum('TrackingStatusStruct');
end
ret = calllib('iViewXAPI', 'iV_GetTrackingStatus', pTrackingStatus);
tStatus = struct(pTrackingStatus);
end

function ret = iV_IsConnected()
ret = calllib('iViewXAPI', 'iV_IsConnected');
end

function ret = iV_PauseRecording()
ret = calllib('iViewXAPI', 'iV_PauseRecording');
end

function ret = iV_SaveData(filename, description, user, overwrite)
ret = calllib('iViewXAPI', 'iV_SaveData', filename, description, user, overwrite);
end

function ret = iV_SelectREDGeometry(profileName)
ret = calllib('iViewXAPI', 'iV_SelectREDGeometry', profileName);
end

function ret = iV_SendImageMessage(etMessage)
ret = calllib('iViewXAPI', 'iV_SendImageMessage', etMessage);
end

function ret = iV_SetConnectionTimeout(time)
ret = calllib('iViewXAPI', 'iV_SetConnectionTimeout', time);
end

function ret = iV_SetLogger(logLevel,filename)
ret = calllib('iViewXAPI', 'iV_SetLogger', logLevel, filename);
end

function ret = iV_SetTrackingParameter(ET_PARAM_EYE, ET_PARAM, value)
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

function ret = iV_SetupCalibration(pCalibrationData)
ret = calllib('iViewXAPI', 'iV_SetupCalibration', pCalibrationData);
end

function ret = iV_SetupDebugMode(enableDebugMode)
ret = calllib('iViewXAPI', 'iV_SetupDebugMode', enableDebugMode);
end

function ret = iV_SetUseCalibrationKeys(enableKeys)
ret = calllib('iViewXAPI', 'iV_SetUseCalibrationKeys', enableKeys);
end

function ret = iV_Start(etApplication)
ret = calllib('iViewXAPI', 'iV_Start', etApplication);
end

function ret = iV_StartRecording()
ret = calllib('iViewXAPI', 'iV_StartRecording');
end

function ret = iV_StopRecording()
ret = calllib('iViewXAPI', 'iV_StopRecording');
end

function ret = iV_Validate()
ret = calllib('iViewXAPI', 'iV_Validate');
end


function image = getImage(ret,pImageData)
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
% or you'llleak the original buffer!
image = pImageData.imageBuffer;
if pImageData.imageSize==pImageData.imageWidth*pImageData.imageHeight
    % grayscale
    image = reshape(image,pImageData.imageWidth,pImageData.imageHeight).';
elseif pImageData.imageSize==pImageData.imageWidth*pImageData.imageHeight*3
    % three-color plane image
    % its returned in BGR format apparently, flip(...,3) to turn to RGB
    image = flip(permute(...
        reshape(image,3,pImageData.imageWidth,pImageData.imageHeight),...
        [3 2 1]),3);
end
end