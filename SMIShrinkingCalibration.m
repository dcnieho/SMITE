classdef SMIShrinkingCalibration < handle
    properties (Access=private, Constant)
        calStateEnum = struct('undefined',0, 'moving',1, 'shrinking',2 ,'waiting',3);
    end
    properties (Access=private)
        calState;
        currentPoint;
        lastPoint;
        moveStartT;
        shrinkStartT;
    end
    properties
        doShrink            = true;
        shrinkTime          = 1;
        doMove              = true;
        moveTime            = 1;
        fixBackSizeLarge    = 40;
        fixBackSizeSmall    = 15;
        fixFrontSize        = 5;
        fixBackColor        = 0;
        fixFrontColor       = 255;
        bgColor             = 127;
    end
    
    
    
    
    
    methods
        function obj = SMIShrinkingCalibration()
            obj.setCleanState();
        end
        
        function setCleanState(obj)
            obj.calState = obj.calStateEnum.undefined;
            obj.currentPoint= nan(1,3);
            obj.lastPoint= nan(1,3);
        end
        
        function doDraw(obj,wpnt,currentPoint,pos,~)
            % if called with nan as first input, this is a signal that
            % calibration/validation is done, and cleanup can occur if
            % wanted
            if isnan(wpnt)
                obj.setCleanState();
                return;
            end
            
            % check point changed
            curT = GetSecs;     % instead of using time directly, you could use the last input to this function to animate based on call sequence number to this function
            if obj.currentPoint(1)~=currentPoint
                if obj.doMove && ~isnan(obj.lastPoint(1))
                    obj.calState = obj.calStateEnum.moving;
                    obj.moveStartT = curT;
                elseif obj.doShrink
                    obj.calState = obj.calStateEnum.shrinking;
                    obj.shrinkStartT = curT;
                else
                    obj.calState = obj.calStateEnum.waiting;
                end
                
                obj.lastPoint       = obj.currentPoint;
                obj.currentPoint    = [currentPoint pos];
            end
            
            % check state transition
            if obj.calState==obj.calStateEnum.moving && (curT-obj.moveStartT)>obj.moveTime
                if obj.doShrink
                    obj.calState = obj.calStateEnum.shrinking;
                    obj.shrinkStartT = curT;
                else
                    obj.calState = obj.calStateEnum.waiting;
                end
            elseif obj.calState==obj.calStateEnum.shrinking && (curT-obj.shrinkStartT)>obj.shrinkTime
                obj.calState = obj.calStateEnum.waiting;
            end
            
            % determine current point position
            if obj.calState==obj.calStateEnum.moving
                frac = (curT-obj.moveStartT)/obj.moveTime;
                curPos = obj.lastPoint(2:3).*(1-frac) + obj.currentPoint(2:3).*frac;
            else
                curPos = obj.currentPoint(2:3);
            end
            
            % determine current point size
            if obj.calState==obj.calStateEnum.shrinking
                frac = (curT-obj.shrinkStartT)/obj.shrinkTime;
                sz   = [obj.fixBackSizeLarge.*(1-frac) + obj.fixBackSizeSmall.*frac   obj.fixFrontSize];
            else
                sz   = [obj.fixBackSizeSmall.*frac obj.fixFrontSize];
            end
            
            % draw
            obj.drawAFixPoint(wpnt,curPos,sz);
        end
        
        function drawAFixPoint(obj,wpnt,pos,sz)
            % draws Thaler et al. 2012's ABC fixation point            
            % draw
            for p=1:size(pos,1)
                rectH = CenterRectOnPointd([0 0        sz ], pos(p,1), pos(p,2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(p,1), pos(p,2));
                Screen('gluDisk', wpnt,obj. fixBackColor, pos(p,1), pos(p,2), sz(1)/2);
                Screen('FillRect',wpnt,obj.fixFrontColor, rectH);
                Screen('FillRect',wpnt,obj.fixFrontColor, rectV);
                Screen('gluDisk', wpnt,obj. fixBackColor, pos(p,1), pos(p,2), sz(2)/2);
            end
        end
    end
end