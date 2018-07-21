#include "SMIbuffer/SMIbuffer.h"

namespace {
    SMIbuffer* SMIbufferClassInstance = nullptr;  // for plain C callback to be able to call into the class

    template <typename T>
    inline std::vector<T> getData(mpmc_bounded_queue<T>* dataBuffer_, bool justDump_=false)
    {
        std::vector<T> data;
        if (!dataBuffer_)
            return data;

        while (true)
        {
            T temp;
            bool success = dataBuffer_->dequeue(temp);
            if (success && !justDump_)
                data.push_back(std::move(temp));
            else
                break;
        }
        return data;
    }
}

int __stdcall SMISampleCallback(SampleStruct sampleData_)
{
    if (SMIbufferClassInstance && SMIbufferClassInstance->_sampleData)
        SMIbufferClassInstance->_sampleData->enqueue(sampleData_);
    return 1;
}

int __stdcall SMIEventCallback(EventStruct eventData_)
{
    if (SMIbufferClassInstance && SMIbufferClassInstance->_eventData)
        SMIbufferClassInstance->_eventData->enqueue(eventData_);
    return 1;
}




SMIbuffer::SMIbuffer()
{}

SMIbuffer::~SMIbuffer()
{
    stopSampleBuffering(true);
    stopEventBuffering (true);
    SMIbufferClassInstance = nullptr;
}

int SMIbuffer::startSampleBuffering(size_t bufferSize_ /*= 1<<22*/)
{
    SMIbufferClassInstance = this;    // make sure its set. doing this in constructor is dangerous, as destructor of an older instance of class (from precious matlab script execution) may be lingering, and destroyed **after** this instance is created. So update SMIbufferClassInstance as late as possible

    if (!_sampleData)
        _sampleData = new mpmc_bounded_queue<SampleStruct>(bufferSize_);

    return iV_SetSampleCallback(SMISampleCallback);
}

int SMIbuffer::startEventBuffering(size_t bufferSize_ /*= 1<<20*/)
{
    SMIbufferClassInstance = this;

    if (!_eventData)
        _eventData = new mpmc_bounded_queue<EventStruct>(bufferSize_);
    
    return iV_SetEventCallback(SMIEventCallback);
}

void SMIbuffer::clearSampleBuffer()
{
    getData(_sampleData,true);
}

void SMIbuffer::clearEventBuffer()
{
    getData(_eventData,true);
}

void SMIbuffer::stopSampleBuffering(bool deleteBuffer_)
{
    iV_SetSampleCallback(nullptr);
    if (_sampleData && deleteBuffer_)
    {
        delete _sampleData;
        _sampleData = nullptr;
    }
}

void SMIbuffer::stopEventBuffering(bool deleteBuffer_)
{
    iV_SetEventCallback(nullptr);
    if (_eventData && deleteBuffer_)
    {
        delete _eventData;
        _eventData = nullptr;
    }
}

std::vector<SampleStruct> SMIbuffer::getSamples()
{
    return getData(_sampleData);
}

std::vector<EventStruct> SMIbuffer::getEvents()
{
    return getData(_eventData);
}

