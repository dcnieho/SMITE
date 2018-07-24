% MATLAB class wrapper to underlying SMIbuffer mex file

classdef SMIbuffer < handle
    properties (Access = private, Hidden = true)
        objectHandle; % Handle to the underlying C++ class instance
        mexHndl;
    end
    methods
        %% Constructor - Create a new C++ class instance 
        function this = SMIbuffer(debugMode)
            % debugmode is for developer of SMIbuffer only, no use for end
            % users
            if nargin<1 || isempty(debugMode)
                debugMode = false;
            else
                debugMode = ~~debugMode;
            end
            % determine what mex file to call
            if debugMode
                this.mexHndl = @SMIbuffer_matlab_d;
            else
                this.mexHndl = @SMIbuffer_matlab;
            end
            % try to construct SMIBuffer C++ class instance
            try
                this.objectHandle = this.mexHndl('new');
            catch %#ok<CTCH>
                % constructor failed. Most likely cause would be "invalid
                % MEX file error" due to missing iViewXAPI DLL's.
                % The old drill: temporarily add (likely) location of DLL.
                % Retry. If this was the culprit, then the linker should
                % load, link and init iViewXAPI and we should succeed.
                % Otherwise we fail again. Try some common paths...
                if exist('C:\Program Files\SMI\iView X SDK\bin','dir')
                    temppath = 'C:\Program Files\SMI\iView X SDK\bin';
                elseif exist('C:\Program Files (x86)\SMI\iView X SDK\bin','dir')
                    temppath = 'C:\Program Files (x86)\SMI\iView X SDK\bin';
                else
                    warning('failed to load SMIbuffer_matlab, and cannot find it in common locations. Please make sure the iView X SDK is installed and that it''s bin directory is in the Windows path variable')
                end
                addpath(temppath);
                this.objectHandle = this.mexHndl('new');
                rmpath(temppath);
            end
        end
        
        %% Destructor - Destroy the C++ class instance
        function delete(this)
            this.mexHndl('delete', this.objectHandle);
        end

        %% methods
        % get the data and command messages received since the last call to this function
        function data = getSamples(this)
            data = this.mexHndl('getSamples', this.objectHandle);
        end
        function events = getEvents(this)
            events = this.mexHndl('getEvents', this.objectHandle);
        end
        function success = startSampleBuffering(this,varargin)
            % optional buffer size input
            success = this.mexHndl('startSampleBuffering', this.objectHandle, varargin{:});
        end
        function success = startEventBuffering(this,varargin)
            % optional buffer size input
            success = this.mexHndl('startEventBuffering' , this.objectHandle, varargin{:});
        end
        function clearSampleBuffer(this)
            this.mexHndl('clearSampleBuffer', this.objectHandle);
        end
        function clearEventBuffer(this)
            this.mexHndl('clearEventBuffer' , this.objectHandle);
        end
        function stopSampleBuffering(this,doDeleteBuffer)
            % required boolean input indicating whether buffer should be
            % deleted
            this.mexHndl('stopSampleBuffering', this.objectHandle, doDeleteBuffer);
        end
        function stopEventBuffering(this,doDeleteBuffer)
            % required boolean input indicating whether buffer should be
            % deleted
            this.mexHndl('stopEventBuffering' , this.objectHandle, doDeleteBuffer);
        end
    end
end
