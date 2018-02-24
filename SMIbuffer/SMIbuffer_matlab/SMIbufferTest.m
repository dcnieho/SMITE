% testing SMIbuffer mex file

sampEvtBuffers = SMIbuffer();



dataMsgs2 = sampEvtBuffers.getData;


% send a bunch of commands
for i=1:10
    sampEvtBuffers.send('cmd');  % testing empty string in message struct
end
cmdMsgs = sampEvtBuffers.getCommands;

% send exit msg
fprintf('nThreads active: %i\n',sampEvtBuffers.checkReceiverThreads);
sampEvtBuffers.send('exit');
fprintf('nThreads active: %i\n',sampEvtBuffers.checkReceiverThreads);

% clean up
sampEvtBuffers.deInit();
fprintf('nThreads active: %i\n',sampEvtBuffers.checkReceiverThreads);
