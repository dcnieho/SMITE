#include "SMIbuffer/SMIbuffer.h"

namespace {
    SMIbuffer* SMIbufferClassInstance=nullptr;  // for plain C callback to be able to call into the class instances

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

int __stdcall SMISampleCallback(SampleStruct sample_)
{
    if (SMIbufferClassInstance && SMIbufferClassInstance->_sampleData)
    {
        if (SMIbufferClassInstance->_doEyeSwap)
            std::swap(sample_.leftEye, sample_.rightEye);
        SMIbufferClassInstance->_sampleData->enqueue(sample_);
    }

    return 1;
}

int __stdcall SMIEventCallback(EventStruct event_)
{
    if (SMIbufferClassInstance && SMIbufferClassInstance->_eventData)
        SMIbufferClassInstance->_eventData->enqueue(event_);

    return 1;
}




SMIbuffer::SMIbuffer(bool needsEyeSwap_ /*= false*/) :
    _doEyeSwap(needsEyeSwap_)
{}

SMIbuffer::~SMIbuffer()
{
    stopSampleBuffering(true);
    stopEventBuffering (true);
}

void SMIbuffer::setEyeSwap(const bool& needsEyeSwap_)
{
    _doEyeSwap = needsEyeSwap_;
}

int SMIbuffer::startSampleBuffering(size_t bufferSize_ /*= 1<<22*/)
{
    if (!_sampleData)
        _sampleData = new mpmc_bounded_queue<SampleStruct>(bufferSize_);

    // make sure we know what class instance should receive the data
    SMIbufferClassInstance = this;

    return iV_SetSampleCallback(SMISampleCallback);
}

int SMIbuffer::startEventBuffering(size_t bufferSize_ /*= 1<<20*/)
{
    if (!_eventData)
        _eventData = new mpmc_bounded_queue<EventStruct>(bufferSize_);

    // make sure we know what class instance should receive the data
    SMIbufferClassInstance = this;

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
    if (_sampleData && deleteBuffer_)
    {
        delete _sampleData;
        _sampleData = nullptr;
    }

    // remove callback function
    iV_SetSampleCallback(nullptr);
}

void SMIbuffer::stopEventBuffering(bool deleteBuffer_)
{
    if (_eventData && deleteBuffer_)
    {
        delete _eventData;
        _eventData = nullptr;
    }

    // remove callback function
    iV_SetEventCallback(nullptr);
}

std::vector<SampleStruct> SMIbuffer::getSamples()
{
    return getData(_sampleData);
}

std::vector<EventStruct> SMIbuffer::getEvents()
{
    return getData(_eventData);
}
