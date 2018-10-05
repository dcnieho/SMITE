sca
qDEBUG = 0;
s.bclr              = 255/2;

addpath(genpath(fullfile(cd,'..','theToolbox')));

try
    % get setup struct (can edit that of course):
    settings = SMITE.getDefaults('RED250');
    settings.connectInfo    = {'192.168.0.1',4444,'192.168.0.2',5555};
%     settings.connectInfo    = {'127.0.0.1',4444};
%     settings.setup.geomProfile = '250';
    settings.doAverageEyes  = false;
    settings.cal.autoPace = 0;
    % custom calibration drawer
    calViz = AnimatedCalibrationDisplay();
    settings.cal.drawFunction = @calViz.doDraw;
    
    % init
    EThndl         = SMITE(settings);
%     EThndl         = EThndl.setDummyMode();
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
    wpnt = PsychImaging('OpenWindow', 0, s.bclr);
    Priority(1);
    Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Preference', 'TextAlphaBlending', 1);
    Screen('Preference', 'TextAntiAliasing', 2);
    % This preference setting selects the high quality text renderer on
    % each operating system: It is not really needed, as the high quality
    % renderer is the default on all operating systems, so this is more of
    % a "better safe than sorry" setting.
    Screen('Preference', 'TextRenderer', 1);
    KbName('UnifyKeyNames')
    
    % do calibration
    smi.calVal{1}   = EThndl.calibrate(wpnt,true);     % clear recoding buffer to make sure any lingering shit from a previous session is removed
    
    % later:
    EThndl.startRecording();
    EThndl.startBuffer();
    %ETFhndl.recordEyeImages('test',5,2000);
     
    % send message into ET data file
    EThndl.sendMessage('test');
    
    % periodically check if the tracker is still working (NB: has been flaky with RED250, check fails, but tracking is fine...: you may want to skip it)
    EThndl.processError(EThndl.isConnected(),'No longer connected to eye tracker');
    
    EThndl.setBegazeTrialImage('test1.jpg');
    % record 2 seconds of data
    WaitSecs(1);
    EThndl.stopRecording();
    WaitSecs(1);
    
    EThndl.startRecording();
    EThndl.setBegazeTrialImage('test2.jpg');
    WaitSecs(.8);
    EThndl.setBegazeKeyPress('testme');
    sample = EThndl.getLatestSample();
    WaitSecs(.8);
    EThndl.setBegazeMouseClick('left',300,500);
    WaitSecs(.8);
    
    
    % stopping and saving
    data = EThndl.getBufferData();
    EThndl.stopRecording();
    EThndl.stopBuffer();
    WaitSecs(0.5);
    DrawFormattedText(wpnt,'Saving data...','center','center',0);
    Screen('Flip',wpnt);
    EThndl.saveData(fullfile(cd,'t'), 'Subject01', 'testExpt', true);
    
    % shut down
    EThndl.deInit(true);
catch me
    sca
    rethrow(me)
end
sca