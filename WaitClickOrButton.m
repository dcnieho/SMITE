function [mouse,keys,which,time] = WaitClickOrButton(mode,cursors)

if nargin<1 || isempty(mode)
    % mode (similar to KbWait):
    % 0: simply wait until a key is down
    % 1: simply wait until no keys are down
    % 2: wait for a key press (so if a key is already down upon function
    %    entering, it is ignored)
    %    waitForAllKeysReleased -> waitForKeypress
    % 3: wait for a keystroke like, 2, but wait until key is released after
    %    pressing it
    %    waitForAllKeysReleased -> waitForKeypress -> waitForAllKeysReleased
    mode = 2;
end

% process cursors
if nargin<2
    cursors = [];
end
cursor = cursorUpdater(cursors);

% init these
buttons = [];
keys = [];

% Wait for release of buttons if some already pressed:
if mode==2 || mode==3
    WaitClickButtonReleased(cursor);
end

% Wait for mouse button or keyboard press
if mode~=1
    while ~any(buttons) && ~any(keys)
        WaitSecs('YieldSecs', 0.002);
        [x,y,buttons] = GetMouse;
        [~,time,keys] = KbCheck;
        
        % check cursor change needed
        cursor.update(x,y);
    end
end

% wait for all keys released
if mode==1
    [x,y,time] = WaitClickButtonReleased(cursor);
elseif mode==3
    WaitClickButtonReleased(cursor);
end

mouse.x   = x;
mouse.y   = y;
mouse.but = buttons;
if mode==1
    which = '';
elseif any(buttons)
    which = 'M';
else
    which = 'K';
end
cursor.reset();


%%% helpers
function [x,y,time] = WaitClickButtonReleased(cursor)
buttons=1;
keys=1;
while any(buttons) || keys
    WaitSecs('YieldSecs', 0.002);
    [x,y,buttons] = GetMouse;
    [keys,time]   = KbCheck;
    
    % check cursor change needed
    cursor.update(x,y);
end