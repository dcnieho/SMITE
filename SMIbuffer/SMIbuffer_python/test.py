import SMIbuffer
import time

sampEvtBuffers = SMIbuffer.SMIbuffer()

success = sampEvtBuffers.startSampleBuffering()
print success

time.sleep(5)
samples = sampEvtBuffers.getSamples()

sampEvtBuffers.stopSampleBuffering(true)    # optional input indicating whether to also destroy buffer (delete samples) or not