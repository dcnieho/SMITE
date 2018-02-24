% testing SMIbuffer mex file

sampEvtBuffers = SMIbuffer();

success = sampEvtBuffers.startSampleBuffering()

WaitSecs(4);
samples = sampEvtBuffers.getSamples();

sampEvtBuffers.stopSampleBuffering(true);   % optional input indicating whether to also destroy buffer (delete samples) or not