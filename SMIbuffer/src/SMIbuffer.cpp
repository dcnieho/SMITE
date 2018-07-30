#include "SMIbuffer/SMIbuffer.h"
#include <shared_mutex>
#include <vector>
#include <algorithm>
#include <utility>

namespace {
    typedef std::shared_timed_mutex mutex_type;
    typedef std::shared_lock<mutex_type> read_lock;
    typedef std::unique_lock<mutex_type> write_lock;
    mutex_type m;
    read_lock  lockForReading() { return  read_lock(m); }
    write_lock lockForWriting() { return write_lock(m); }

    typedef std::pair<SMIbuffer*, unsigned int> instance_type;
    std::vector<instance_type> SMIbufferClassInstances;  // for plain C callback to be able to call into the class instances

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
    auto l = lockForReading();
    for each (auto&& instance in SMIbufferClassInstances)
    {
        if ((instance.second & 1) && instance.first->_sampleData)
            instance.first->_sampleData->enqueue(sample_);
    }

    return 1;
}

int __stdcall SMIEventCallback(EventStruct event_)
{
    auto l = lockForReading();
    for each (auto&& instance in SMIbufferClassInstances)
    {
        if ((instance.second & 2) && instance.first->_eventData)
            instance.first->_eventData->enqueue(event_);
    }

    return 1;
}




SMIbuffer::SMIbuffer()
{}

SMIbuffer::~SMIbuffer()
{
    stopSampleBuffering(true);
    stopEventBuffering (true);
}

int SMIbuffer::startSampleBuffering(size_t bufferSize_ /*= 1<<22*/)
{
    if (!_sampleData)
        _sampleData = new mpmc_bounded_queue<SampleStruct>(bufferSize_);

    // if instance already in set, register it for samples, else add to set
    auto l = lockForWriting();
    auto it = std::find_if(SMIbufferClassInstances.begin(), SMIbufferClassInstances.end(), [this](const instance_type& a_) {return a_.first == this;});
    if (it == SMIbufferClassInstances.end())
        SMIbufferClassInstances.emplace_back(this, 1);
    else
        it->second |= 1;

    return iV_SetSampleCallback(SMISampleCallback);
}

int SMIbuffer::startEventBuffering(size_t bufferSize_ /*= 1<<20*/)
{
    if (!_eventData)
        _eventData = new mpmc_bounded_queue<EventStruct>(bufferSize_);

    // if instance already in set, register it for events, else add to set
    auto l = lockForWriting();
    auto it = std::find_if(SMIbufferClassInstances.begin(), SMIbufferClassInstances.end(), [this](const instance_type& a_) {return a_.first == this; });
    if (it == SMIbufferClassInstances.end())
        SMIbufferClassInstances.emplace_back(this, 2);
    else
        it->second |= 2;

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

    // remove registration for event buffering for this instance
    auto l = lockForWriting();
    auto it = std::find_if(SMIbufferClassInstances.begin(), SMIbufferClassInstances.end(), [this](const instance_type& a_) {return a_.first == this; });
    if (it != SMIbufferClassInstances.end())
        it->second &= ~(1);

    // if no callback registrations left, remove instance from instance list
    if (!it->second)
        SMIbufferClassInstances.erase(it);

    // if no instances left, remove callback function
    if (SMIbufferClassInstances.empty())
    iV_SetSampleCallback(nullptr);
}

void SMIbuffer::stopEventBuffering(bool deleteBuffer_)
{
    if (_eventData && deleteBuffer_)
    {
        delete _eventData;
        _eventData = nullptr;
    }

    // remove registration for event buffering for this instance
    auto l = lockForWriting();
    auto it = std::find_if(SMIbufferClassInstances.begin(), SMIbufferClassInstances.end(), [this](const instance_type& a_) {return a_.first == this; });
    if (it != SMIbufferClassInstances.end())
        it->second &= ~(2);

    // if no callback registrations left, remove instance from instance list
    if (!it->second)
        SMIbufferClassInstances.erase(it);

    // if no instances left, remove callback function
    if (SMIbufferClassInstances.empty())
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
