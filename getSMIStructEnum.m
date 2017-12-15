function out = getSMIStructEnum(type,initVal)
% for memory efficiency, it is good to call this function once for each
% type and then reuse what you get in return. However, you can have
% multiple instances of each if you want.
% note that this is especially important when you use structs with pointer
% members (notably ImageStruct). Matlab does not seem to free memory
% correctly, so you'll quickly run out. The functions in the iViewXAPI
% wrapper are designed to allow reuse of the structs.
%
% initVal input is used only for enums, can be numeric value or string
% representation of enum value

if ismember(type,{'SystemInfoStruct','SpeedModeStruct','CalibrationPointStruct','CalibrationPointQualityStruct','EyeDataStruct','SampleStruct','SampleStruct32','EventStruct','EventStruct32','EyePositionStruct','TrackingStatusStruct','AccuracyStruct','GazeChannelQualityStruct','CalibrationStruct','REDGeometryStruct','ImageStruct','DateStruct','AOIRectangleStruct','AOIStruct','REDStandAloneModeStruct','REDMonitorAttachedGeometryStruct'})
    
    % use libstruct to construct the C structure. Default constructed
    % (fields are 0/NULL/etc) unless specified otherwise below here. The
    % output type has an interface that matches normal MATLAB structs and
    % can be converted to a MATLAB struct by simply struct(out)
    switch type
        case 'CalibrationStruct'
            % for this struct it is better to not use default init (all 0),
            % but put the default values documented in the header file here
            % so that user has to only change values he does not want to be
            % default
            init.method = 5;                    % select calibration method (default: 5) A bit mask is used to specify a new calibration workflow. If the highest bit is 1, The "Smart Calibration" workflow should be activated on iView eye tracking server.
            init.visualization = 1;             % draw calibration/validation by API (default: 1)
            init.displayDevice = 0;
            init.speed = 0;                     % set calibration/validation speed [0: slow (default), 1: fast]
            init.autoAccept = 1;                % set calibration/validation point acceptance [2: full-automatic, 1: semi-automatic (default), 0: manual]
            init.foregroundBrightness = 20;
            init.backgroundBrightness = 239;
            init.targetShape = 1;
            init.targetSize = 15;               % diameter
            % init.targetFilename = zeros(1,256,'uint8');   % default init is fine
        otherwise
            % [] default inits the struct. having no default init at all
            % gives a null/unallocated structure, which will lead to
            % crashes when passing it to the dll for it to write info in
            % (null pointer dereference...)
            init = [];
    end
    out = libstruct(type,init);
    
    
elseif ismember(type,{'CalibrationPointUsageStatusEnum','CalibrationStatusEnum','ETDevice','FilterAction','ETApplication','FilterType','REDGeometryEnum','RecordingState','TrackingMode'})
    % enums. Note that matlab will give you a
    % char, not an int32 back when you call enumPtr.Value;
    % to initialize, both the string for the enum value and the
    % corresponding int can be used.
    
    if nargin>1 && ~isempty(initVal)
        init = initVal;
    else
        % else default init
        init = 0;
    end
    
    out = libpointer(type, init);
    
else
    error('type %s not known or implemented',type);
end