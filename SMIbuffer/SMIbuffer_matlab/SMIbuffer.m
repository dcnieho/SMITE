% MATLAB class wrapper to underlying SMIbuffer mex file

classdef SMIbuffer < handle
    properties (Access = private, Hidden = true)
        objectHandle; % Handle to the underlying C++ class instance
    end
    methods
        %% Constructor - Create a new C++ class instance 
        function this = SMIbuffer(varargin)
            try
                this.objectHandle = SMIbuffer_matlab('new', varargin{:});
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
                this.objectHandle = SMIbuffer_matlab('new', varargin{:});
                rmpath(temppath);
            end
        end
        
        %% Destructor - Destroy the C++ class instance
        function delete(this)
            SMIbuffer_matlab('delete', this.objectHandle);
        end

        %% methods
        % get the data and command messages received since the last call to this function
        function data = getSamples(this)
            data = SMIbuffer_matlab('getSamples', this.objectHandle);
        end
        function events = getEvents(this)
            events = SMIbuffer_matlab('getEvents', this.objectHandle);
        end
        function success = startSampleBuffering(this,varargin)
            % optional buffer size input
            success = SMIbuffer_matlab('startSampleBuffering', this.objectHandle, varargin{:});
        end
        function success = startEventBuffering(this,varargin)
            % optional buffer size input
            success = SMIbuffer_matlab('startEventBuffering' , this.objectHandle, varargin{:});
        end
        function clearSampleBuffer(this)
            SMIbuffer_matlab('clearSampleBuffer', this.objectHandle);
        end
        function clearEventBuffer(this)
            SMIbuffer_matlab('clearEventBuffer' , this.objectHandle);
        end
        function stopSampleBuffering(this,varargin)
            % required boolean input indicating whether buffer should be
            % deleted
            SMIbuffer_matlab('stopSampleBuffering', this.objectHandle, varargin{:});
        end
        function stopEventBuffering(this,varargin)
            % required boolean input indicating whether buffer should be
            % deleted
            SMIbuffer_matlab('stopEventBuffering' , this.objectHandle, varargin{:});
        end
    end
end
