% testing MATLAB class wrapper to underlying C++ class UDPClient

udp = UDPClient();
fprintf('build from git revision ID %s\n',udp.getGitRefID());
udp.setPort(4444);
udp.getGroupAddress()
udp.setUseWTP(false);
udp.setMaxClockRes(true);
udp.init();
udp.setLoopBack(true);

udp.getCurrentTime();   % warmup timestamper

% send a bunch of messages
for i=1:2048
    udp.sendWithTimeStamp('dat,1,crap',';');
end
dataMsgs = udp.getData;
for i=1:20
    udp.sendWithTimeStamp('dat,2,crap');    % testing default delimiter
end
dataMsgs2 = udp.getData;


% send a bunch of commands
for i=1:10
    udp.send('cmd');  % testing empty string in message struct
end
cmdMsgs = udp.getCommands;

% send exit msg
fprintf('nThreads active: %i\n',udp.checkReceiverThreads);
udp.send('exit');
fprintf('nThreads active: %i\n',udp.checkReceiverThreads);

% clean up
udp.deInit();
fprintf('nThreads active: %i\n',udp.checkReceiverThreads);
