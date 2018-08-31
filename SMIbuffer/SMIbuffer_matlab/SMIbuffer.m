% MATLAB class wrapper to underlying SMIbuffer mex file
% NB: there should only be one instance of this class at a time. Creating a
% new instance when one already exists simple resets the first, at no
% benefit

classdef SMIbuffer < handle
    properties (Access = private, Hidden = true)
        mexHndl;
    end
    methods
        %% Constructor - Create a new C++ class instance 
        function this = SMIbuffer(needsEyeSwap,debugMode)
            if nargin<1 || isempty(needsEyeSwap)
                needsEyeSwap = false;
            end
            % debugmode is for developer of SMIbuffer only, no use for end
            % users
            if nargin<2 || isempty(debugMode)
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
                this.mexHndl('new');
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
                this.mexHndl('new',needsEyeSwap);
                rmpath(temppath);
            end
        end
        
        %% Destructor - Destroy the C++ class instance
        function delete(this)
            this.mexHndl('delete');
        end

        %% methods
        % get the data and command messages received since the last call to this function
        function data = getSamples(this)
            data = this.mexHndl('getSamples');
        end
        function events = getEvents(this)
            events = this.mexHndl('getEvents');
        end
        function success = startSampleBuffering(this,varargin)
            % optional buffer size input
            success = this.mexHndl('startSampleBuffering', varargin{:});
        end
        function success = startEventBuffering(this,varargin)
            % optional buffer size input
            success = this.mexHndl('startEventBuffering', varargin{:});
        end
        function clearSampleBuffer(this)
            this.mexHndl('clearSampleBuffer');
        end
        function clearEventBuffer(this)
            this.mexHndl('clearEventBuffer');
        end
        function stopSampleBuffering(this,doDeleteBuffer)
            % required boolean input indicating whether buffer should be
            % deleted
            this.mexHndl('stopSampleBuffering', doDeleteBuffer);
        end
        function stopEventBuffering(this,doDeleteBuffer)
            % required boolean input indicating whether buffer should be
            % deleted
            this.mexHndl('stopEventBuffering', doDeleteBuffer);
        end
    end
end
