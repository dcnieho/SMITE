#pragma once
#include <vector>
#include <iViewXAPI.h>
#pragma comment(lib, "iViewXAPI.lib")
#include "mpmcBoundedQueue.h"



class SMIbuffer
{
public:
    SMIbuffer();
    ~SMIbuffer();

    bool startSampleBuffering(size_t bufferSize_ = 1<<22);
    bool startEventBuffering (size_t bufferSize_ = 1<<20);
    // stop discards all data in the buffer
    void stopSampleBuffering(bool deleteBuffer_);
    void stopEventBuffering (bool deleteBuffer_);

    // get the data received since the last call to this function
    std::vector<SampleStruct>	getSamples();
    std::vector<EventStruct>	getEvents ();

private:
    // SMI callbacks needs to be friends
    friend int __stdcall SMISampleCallback(SampleStruct sampleData_);
    friend int __stdcall SMIEventCallback (EventStruct   eventData_);

private:
    mpmc_bounded_queue<SampleStruct>*	_sampleData = nullptr;
    mpmc_bounded_queue<EventStruct>*	_eventData  = nullptr;
};