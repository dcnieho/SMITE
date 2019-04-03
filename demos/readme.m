% this demo code is part of SMITE, a toolbox providing convenient access to
% eye tracking functionality using SMI eye trackers
%
% SMITE can be found at https://github.com/dcnieho/SMITE. When using SMITE,
% please cite the following paper:
% Niehorster, D.C., & Nyström, M., (2019). SMITE: A toolbox for creating
% Psychtoolbox and Psychopy experiments with SMI eye trackers.
% doi: 10.3758/s13428-019-01226-0.

sca
qDEBUG      = 0;
bgclr       = 255/2;
fixClr      = 0;
fixTime     = .5;
imageTime   = 2;
scr         = max(Screen('Screens'));

addpath(genpath(fullfile(cd,'..')));

try
    % get setup struct, edit to change settings
    settings = SMITE.getDefaults('RED-m');
    %settings.connectInfo    = {'192.168.0.1',4444,'192.168.0.2',5555};
    settings.doAverageEyes  = false;
    settings.cal.bgColor    = bgclr;
    if 0
        % calibrate only lower-right quadrant of screen. Achieved by scale
        % to half of screen size, and then offsetting from centered on
        % screen to fitting in lower-right corner. Note that the position
        % of validation points cannot be set, and these will thus cover the
        % whole screen and show bad accuracy outside the calibrated area
        scrSz = Screen('Rect',scr);
        settings.cal.rangeX     = scrSz(3)/2;
        settings.cal.rangeY     = scrSz(4)/2;
        settings.cal.offsetX    = scrSz(3)/4;
        settings.cal.offsetY    = scrSz(4)/4;
    end
    % custom calibration drawer
    calViz = AnimatedCalibrationDisplay();
    settings.cal.drawFunction = @calViz.doDraw;
    
    % init
    EThndl         = SMITE(settings);
    % EThndl         = EThndl.setDummyMode();
    EThndl.init();
    
    
    if qDEBUG>1
        % make screen partially transparent on OSX and windows vista or
        % higher, so we can debug.
        PsychDebugWindowConfiguration;
    end
    if qDEBUG
        % Be pretty verbose about information and hints to optimize your code and system.
        Screen('Preference', 'Verbosity', 4);
    else
        % Only output critical errors and warnings.
        Screen('Preference', 'Verbosity', 2);
    end
    Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
    [wpnt,winRect] = PsychImaging('OpenWindow', scr, bgclr);
    hz=Screen('NominalFrameRate', wpnt);
    Priority(1);
    Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Preference', 'TextAlphaBlending', 1);
    Screen('Preference', 'TextAntiAliasing', 2);
    % This preference setting selects the high quality text renderer on
    % each operating system: It is not really needed, as the high quality
    % renderer is the default on all operating systems, so this is more of
    % a "better safe than sorry" setting.
    Screen('Preference', 'TextRenderer', 1);
    KbName('UnifyKeyNames');    % for correct operation of the setup/calibration interface, calling this is required
    
    % do calibration
    smi.calVal{1}   = EThndl.calibrate(wpnt,true);     % clear recording buffer to make sure any lingering shit from a previous session is removed
    
    % later:
    EThndl.startRecording();
    EThndl.startBuffer();
    %ETFhndl.recordEyeImages('test',5,2000);
     
    % send message into ET data file
    EThndl.sendMessage('test');
    
    % periodically check if the tracker is still working (NB: has been flaky with RED250: check fails, but tracking is fine...: you may want to skip it)
    EThndl.processError(EThndl.isConnected(),'No longer connected to eye tracker');
    
    % First draw a fixation point
    Screen('gluDisk',wpnt,0,winRect(3)/2,winRect(4)/2,round(winRect(3)/100));
    startT = Screen('Flip',wpnt);
    
    % read in konijntjes image (may want to preload this before the trial
    % to ensure good timing)
    im = imread(fullfile(PsychtoolboxRoot,'PsychHardware','EyelinkToolbox','EyelinkDemos','GazeContingentDemos','konijntjes1024x768.jpg'));
    tex = Screen('MakeTexture',wpnt,im);
    
    % show on screen and once shown, immediately set trial image to
    % indicate start of part of trial that should be analyzed.
    % NB: by setting a deadline for the flip, we ensure that the previous
    % screen (fixation point) stays visible for the indicated amount of
    % time. See PsychToolbox demos for further elaboration on this way of
    % timing your script.
    Screen('DrawTexture',wpnt,tex);
    imgT = Screen('Flip',wpnt,startT+fixTime-1/hz/2);   % bit of slack to make sure requested presentation time can be achieved
    EThndl.setBegazeTrialImage('konijntjes1024x768.jpg');
    
    % record x seconds of data, clear screen. Stop the recording
    % immediately after to indicate that trial is finished
    Screen('Flip',wpnt,imgT+imageTime-1/hz/2);
    EThndl.stopRecording();
    Screen('Close',tex);
    
    % slightly less precise ISI is fine..., about 1s give or take a frame
    WaitSecs(1);
    
    
    % next trial, start recording again
    EThndl.startRecording();
    
    % repeat the above but show a different image
    % 1. fixation point
    Screen('gluDisk',wpnt,0,winRect(3)/2,winRect(4)/2,round(winRect(3)/100));
    startT = Screen('Flip',wpnt);
    % 2. image
    im = imread(fullfile(PsychtoolboxRoot,'PsychHardware','EyelinkToolbox','EyelinkDemos','GazeContingentDemos','konijntjes1024x768blur.jpg'));
    tex = Screen('MakeTexture',wpnt,im);
    Screen('DrawTexture',wpnt,tex);
    imgT = Screen('Flip',wpnt,startT+fixTime-1/hz/2);   % bit of slack to make sure requested presentation time can be achieved
    EThndl.setBegazeTrialImage('konijntjes1024x768blur.jpg');
    
    % 3. now fake a key press and a mouse press
    WaitSecs(imageTime*.4);
    EThndl.setBegazeKeyPress('testme');
    sample = EThndl.getLatestSample();  % test this function 
    WaitSecs(imageTime*.4);
    EThndl.setBegazeMouseClick('left',300,500);
    
    % 4. end recording after x seconds of data again, clear screen.
    Screen('Flip',wpnt,imgT+imageTime-1/hz/2);
    EThndl.stopRecording();
    Screen('Close',tex);
    
    % stopping and saving
    data = EThndl.consumeBufferData();
    EThndl.stopBuffer();
    WaitSecs(0.5);
    DrawFormattedText(wpnt,'Saving data...','center','center',0);
    Screen('Flip',wpnt);
    EThndl.saveData(fullfile(cd,'t'), 'Subject01', 'testExpt', true);
catch me
    sca
    rethrow(me)
end
% shut down
sca
EThndl.deInit(true);