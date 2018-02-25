#include "SMIbuffer/SMIbuffer.h"

namespace {
    SMIbuffer* classPtr = nullptr;

    template <typename T>
    inline std::vector<T> getData(mpmc_bounded_queue<T>* dataBuffer_)
    {
        std::vector<T> data;
        if (!dataBuffer_)
            return data;

        while (true)
        {
            T temp;
            bool success = dataBuffer_->dequeue(temp);
            if (success)
                data.push_back(std::move(temp));
            else
                break;
        }
        return data;
    }

    template <typename T>
    inline void clearBuffer(mpmc_bounded_queue<T>* dataBuffer_)
    {
        if (!dataBuffer_)
            return;

        T temp;
        while (true)
        {
            bool success = dataBuffer_->dequeue(temp);
            if (!success)
                break;
        }
    }
}

int __stdcall SMISampleCallback(SampleStruct sampleData_)
{
    if (classPtr && classPtr->_sampleData)
        classPtr->_sampleData->enqueue(sampleData_);
    return 1;
}

int __stdcall SMIEventCallback(EventStruct eventData_)
{
    if (classPtr && classPtr->_eventData)
        classPtr->_eventData->enqueue(eventData_);
    return 1;
}




SMIbuffer::SMIbuffer()
{
    classPtr = this;
}

SMIbuffer::~SMIbuffer()
{
    stopSampleBuffering(true);
    stopEventBuffering (true);
    classPtr = nullptr;
}

int SMIbuffer::startSampleBuffering(size_t bufferSize_ /*= 1<<22*/)
{
    if (!_sampleData)
        _sampleData = new mpmc_bounded_queue<SampleStruct>(bufferSize_);
    return iV_SetSampleCallback(SMISampleCallback);
}

int SMIbuffer::startEventBuffering(size_t bufferSize_ /*= 1<<20*/)
{
    if (!_eventData)
        _eventData = new mpmc_bounded_queue<EventStruct>(bufferSize_);
    return iV_SetEventCallback(SMIEventCallback);
}

void SMIbuffer::clearSampleBuffer()
{
    return clearBuffer(_sampleData);
}

void SMIbuffer::clearEventBuffer()
{
    return clearBuffer(_eventData);
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

