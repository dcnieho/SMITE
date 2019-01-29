% MATLAB class wrapper to underlying SMIbuffer mex file
% NB: there should only be one instance of this class at a time. Creating a
% new instance when one already exists simple resets the first, at no
% benefit
%
% Part of the SMITE toolbox (https://github.com/dcnieho/SMITE), but can be
% used independently. When using this file, please cite the following
% paper:
% Niehorster, D.C., & Nyström, M., (submitted). SMITE: A toolbox for
% creating Psychtoolbox and Psychopy experiments with SMI eye trackers.

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
                this.mexHndl('new',needsEyeSwap);
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
        function success = startSampleBuffering(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                success = this.mexHndl('startSampleBuffering',uint64(initialBufferSize));
            else
                success = this.mexHndl('startSampleBuffering');
            end
        end
        function clearSampleBuffer(this)
            this.mexHndl('clearSampleBuffer');
        end
        function stopSampleBuffering(this,doDeleteBuffer)
            % optional boolean input indicating whether buffer should be
            % deleted
            if nargin>1
                this.mexHndl('stopSampleBuffering',logical(doDeleteBuffer));
            else
                this.mexHndl('stopSampleBuffering');
            end
        end
        function data = consumeSamples(this,firstN)
            % optional input indicating how many samples to read from the
            % beginning of buffer. Default: all
            if nargin>1
                data = this.mexHndl('consumeSamples',uint64(firstN));
            else
                data = this.mexHndl('consumeSamples');
            end
        end
        function data = peekSamples(this,lastN)
            % optional input indicating how many samples to read from the
            % end of buffer. Default: 1
            if nargin>1
                data = this.mexHndl('peekSamples',uint64(lastN));
            else
                data = this.mexHndl('peekSamples');
            end
        end
        
        function success = startEventBuffering(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                success = this.mexHndl('startEventBuffering',uint64(initialBufferSize));
            else
                success = this.mexHndl('startEventBuffering');
            end
        end
        function clearEventBuffer(this)
            this.mexHndl('clearEventBuffer');
        end
        function stopEventBuffering(this,doDeleteBuffer)
            % optional boolean input indicating whether buffer should be
            % deleted
            if nargin>1
                this.mexHndl('stopEventBuffering',logical(doDeleteBuffer));
            else
                this.mexHndl('stopEventBuffering');
            end
        end
        function data = consumeEvents(this,firstN)
            % optional input indicating how many events to read from the
            % beginning of buffer. Default: all
            if nargin>1
                data = this.mexHndl('consumeEvents',uint64(firstN));
            else
                data = this.mexHndl('consumeEvents');
            end
        end
        function data = peekEvents(this,lastN)
            % optional input indicating how many events to read from the
            % end of buffer. Default: 1
            if nargin>1
                data = this.mexHndl('peekEvents',uint64(lastN));
            else
                data = this.mexHndl('peekEvents');
            end
        end
    end
end
