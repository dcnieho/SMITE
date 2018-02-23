classdef SMIWrapperDummyMode < SMIWrapper
    properties
        doMouseSimulation = false;
    end
    
    methods
        function obj = SMIWrapperDummyMode(SMIWrapperInstance)
            qPassedSuperClass = false;
            if ischar(SMIWrapperInstance)
                % direct construction, thats fine
                name = SMIWrapperInstance;
            elseif isa(SMIWrapperInstance,'SMIWrapper')
                qPassedSuperClass = true;
                name = SMIWrapperInstance.settings.tracker;
            end
            
            obj = obj@SMIWrapper(name);
            
            if qPassedSuperClass
                % passed the superclass. "cast" into subclass by copying
                % over all properties. This is what TMW recommends when you
                % want to downcast...
                C = metaclass(SMIWrapperInstance);
                P = C.Properties;
                for k = 1:length(P)
                    if ~P{k}.Dependent
                        obj.(P{k}.Name) = SMIWrapperInstance.(P{k}.Name);
                    end
                end
            end
        end
        
        function out = init(obj)
            out = [];
            % mark as inited
            obj.isInitialized = true;
        end
        
        function out = calibrate(~,~,~)
            out = [];
        end
        
        function startRecording(~,~)
        end
        
        function stopRecording(~)
        end
        
        function out = isConnected(~)
            out = true;
        end
        
        function sendMessage(~,~)
        end
        
        function sample = getLatestSample(obj)
            if obj.doMouseSimulation
                [mx, my] = GetMouse();
                sample = [mx my];
            else
                sample = [];
            end
        end
        
        function saveData(~,~,~,~,~)
        end
        
        function out = deInit(obj,~)
            out = [];
            % mark as deinited
            obj.isInitialized = false;
        end
    end
end