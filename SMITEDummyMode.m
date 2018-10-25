classdef SMITEDummyMode < SMITE
    properties
        isRecording = false;
        isBuffering = false;
    end
    
    methods
        function obj = SMITEDummyMode(SMITEInstance)
            qPassedSuperClass = false;
            if ischar(SMITEInstance)
                % direct construction, thats fine
                name = SMITEInstance;
            elseif isa(SMITEInstance,'SMITE')
                qPassedSuperClass = true;
                name = SMITEInstance.settings.tracker;
            end
            
            % construct default base class, below we overwrite some
            % settings, if a super class was passed in
            obj = obj@SMITE(name);
            
            if qPassedSuperClass
                % passed the superclass. "cast" into subclass by copying
                % over all properties. This is what TMW recommends when you
                % want to downcast...
                C = metaclass(SMITEInstance);
                P = C.Properties;
                for k = 1:length(P)
                    if ~P{k}.Dependent && ~strcmp(P{k}.SetAccess,'private')
                        obj.(P{k}.Name) = SMITEInstance.(P{k}.Name);
                    end
                end
            end
            
            % check we overwrite all public methods (for developer, to make
            % sure we override all accessible baseclass calls with no-ops)
            if 0
                thisInfo = metaclass(obj);
                superMethods = thisInfo.SuperclassList.MethodList;
                superMethods(~strcmp({superMethods.Access},'public') | (~~[superMethods.Static])) = [];
                thisMethods = thisInfo.MethodList;
                % delete, getOptions and setOptions still work in dummy mode
                thisMethods(~strcmp({thisMethods.Access},'public') | (~~[thisMethods.Static]) | ismember({thisMethods.Name},{'SMITEDummyMode','delete','getOptions','setOptions'})) = [];
                
                % now check for problems:
                % 1. any methods we define here that are not in superclass?
                notInSuper = ~ismember({thisMethods.Name},{superMethods.Name});
                if any(notInSuper)
                    fprintf('methods that are in %s but not in %s:\n',thisInfo.Name,thisInfo.SuperclassList.Name);
                    fprintf('  %s\n',thisMethods(notInSuper).Name);
                end
                
                % 2. methods from superclas that are not overridden.
                qNotOverridden = arrayfun(@(x) strcmp(x.DefiningClass.Name,thisInfo.SuperclassList.Name), thisMethods);
                if any(qNotOverridden)
                    fprintf('methods from %s not overridden in %s:\n',thisInfo.SuperclassList.Name,thisInfo.Name);
                    fprintf('  %s\n',thisMethods(qNotOverridden).Name);
                end
                
                % 3. right number of input arguments? (NB: this code only
                % makes sense if there are no overloads with a different
                % number of inputs)
                qMatchingInput = false(size(qNotOverridden));
                for p=1:length(thisMethods)
                    superMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                    if isscalar(superMethod)
                        qMatchingInput(p) = length(superMethod.InputNames) == length(thisMethods(p).InputNames);
                    else
                        qMatchingInput(p) = true;
                    end
                end
                if any(~qMatchingInput)
                    fprintf('methods in %s with wrong number of input arguments (mismatching %s):\n',thisInfo.Name,thisInfo.SuperclassList.Name);
                    fprintf('  %s\n',thisMethods(~qMatchingInput).Name);
                end
                
                % 4. right number of output arguments?
                qMatchingOutput = false(size(qNotOverridden));
                for p=1:length(thisMethods)
                    superMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                    if isscalar(superMethod)
                        qMatchingOutput(p) = length(superMethod.OutputNames) == length(thisMethods(p).OutputNames);
                    else
                        qMatchingOutput(p) = true;
                    end
                end
                if any(~qMatchingOutput)
                    fprintf('methods in %s with wrong number of output arguments (mismatching %s):\n',thisInfo.Name,thisInfo.SuperclassList.Name);
                    fprintf('  %s\n',thisMethods(~qMatchingOutput).Name);
                end
            end
        end
        
        function out = setDummyMode(obj)
            % we're already in dummy mode, just pass out the same instance
            out = obj;
        end
        
        function out = init(obj)
            out = [];
            % mark as inited
            obj.isInitialized = true;
        end
        
        function out = calibrate(~,~,~)
            out = [];
        end
        
        function startRecording(obj,~)
            % so we only get data when 'recording'
            obj.isRecording = true;
        end
        
        function startBuffer(obj,~)
            % so we only get data when 'buffering'
            obj.isBuffering = true;
        end
        
        function data = consumeBufferData(obj,varargin)
            % at least returns one sample all the time...
            if obj.isBuffering
                data = obj.getMouseSample();
            else
                data = [];
            end
        end
        
        function data = peekBufferData(obj,varargin)
            % at least returns one sample all the time...
            if obj.isBuffering
                data = obj.getMouseSample();
            else
                data = [];
            end
        end
        
        function sample = getLatestSample(obj)
            if obj.isRecording
                sample = obj.getMouseSample();
            else
                sample = [];
            end
        end
        
        function stopBuffer(obj,~)
            obj.isBuffering = false;
        end
        
        function stopRecording(obj)
            obj.isRecording = false;
        end
        
        function out = isConnected(~)
            out = true;
        end
        
        function sendMessage(~,~)
        end
        
        function setBegazeTrialImage(~,~)
        end
        
        function setBegazeKeyPress(~,~)
        end
        
        function setBegazeMouseClick(~,~,~,~)
        end
        
        function startEyeImageRecording(~,~,~,~)
        end
        
        function stopEyeImageRecording(~)
        end
        
        function saveData(~,~,~,~,~)
        end
        
        function out = deInit(~,~)
            out = [];
            % mark as deinited
            obj.isInitialized = false;
        end
    end
    
    methods  (Access = private, Hidden)
        function sample = getMouseSample(~)
            [mx, my] = GetMouse();
            % put into fake SampleStruct
            edat = struct('gazeX',mx,'gazeY',my,'diam',0,'eyePositionX',0,'eyePositionY',0,'eyePositionZ',0);
            sample = struct('timestamp',round(GetSecs*1000*1000),'leftEye',edat,'rightEye',edat);
        end
    end
end