#include "SMIbuffer/SMIbuffer.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>

namespace {
    SMIbuffer* SMIbufferClassInstance=nullptr;  // for plain C callback to be able to call into the class instances

    typedef std::shared_timed_mutex mutex_type;
    typedef std::shared_lock<mutex_type> read_lock;
    typedef std::unique_lock<mutex_type> write_lock;

    mutex_type g_mSamp, g_mEvent;

    template <typename T>
    read_lock  lockForReading() { return  read_lock(getMutex<T>()); }
    template <typename T>
    write_lock lockForWriting() { return write_lock(getMutex<T>()); }

    template <typename T>
    mutex_type& getMutex()
    {
        if constexpr (std::is_same<T, SampleStruct>::value)
            return g_mSamp;
        if constexpr (std::is_same<T, EventStruct>::value)
            return g_mEvent;
    }
}

int __stdcall SMISampleCallback(SampleStruct sample_)
{
    if (SMIbufferClassInstance)
    {
        if (SMIbufferClassInstance->_doEyeSwap)
            std::swap(sample_.leftEye, sample_.rightEye);

        auto l = lockForWriting<SampleStruct>();
        SMIbufferClassInstance->_sampleData.push_back(sample_);
    }

    return 1;
}

int __stdcall SMIEventCallback(EventStruct event_)
{
    if (SMIbufferClassInstance)
    {
        auto l = lockForWriting<EventStruct>();
        SMIbufferClassInstance->_eventData.push_back(event_);
    }

    return 1;
}





// helpers to make below generic
template <typename T>
std::vector<T>& SMIbuffer::getBuffer()
{
    if constexpr (std::is_same_v<T, SampleStruct>)
        return _sampleData;
    if constexpr (std::is_same_v<T, EventStruct>)
        return _eventData;
}
template <typename T>
void SMIbuffer::clearBuffer()
{
    auto l = lockForWriting<T>();
    getBuffer<T>().clear();
}
template <typename T>
void SMIbuffer::stopBufferingGenericPart(bool emptyBuffer_)
{
    if (emptyBuffer_)
        clearBuffer<T>();
}
template <typename T>
std::vector<T> SMIbuffer::peek(size_t lastN_)
{
    auto l = lockForReading<T>();
    auto& buf = getBuffer<T>();
    // copy last N or whole vector if less than N elements available
    return std::vector<T>(buf.end() - std::min(buf.size(), lastN_), buf.end());
}
template <typename T>
std::vector<T> SMIbuffer::consume(size_t firstN_)
{
    auto l = lockForWriting<T>();
    auto& buf = getBuffer<T>();

    if (firstN_ == -1 || firstN_ >= buf.size())		// firstN_=-1 overflows, so first check strictly not needed. Better keep code legible tho
        return std::vector<T>(std::move(buf));
    else
    {
        std::vector<T> out;
        out.reserve(firstN_);
        out.insert(out.end(), std::make_move_iterator(buf.begin()), std::make_move_iterator(buf.begin() + firstN_));
        buf.erase(buf.begin(), buf.begin() + firstN_);
        return out;
    }
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

int SMIbuffer::startSampleBuffering(size_t initialBufferSize_ /*= SMIbuff::g_sampleBufDefaultSize*/)
{
    // make sure we know what class instance should receive the data
    SMIbufferClassInstance = this;

    auto l = lockForWriting<SampleStruct>();
    _sampleData.reserve(initialBufferSize_);

    return iV_SetSampleCallback(SMISampleCallback);
}

int SMIbuffer::startEventBuffering(size_t initialBufferSize_ /*= SMIbuff::g_eventBufDefaultSize*/)
{
    // make sure we know what class instance should receive the data
    SMIbufferClassInstance = this;

    auto l = lockForWriting<EventStruct>();
    _eventData.reserve(initialBufferSize_);

    return iV_SetEventCallback(SMIEventCallback);
}

void SMIbuffer::clearSampleBuffer()
{
    clearBuffer<SampleStruct>();
}

void SMIbuffer::clearEventBuffer()
{
    clearBuffer<EventStruct>();
}

void SMIbuffer::stopSampleBuffering(bool emptyBuffer_ /*= g_stopBufferEmptiesDefault*/)
{
    // remove callback function
    iV_SetSampleCallback(nullptr);
    stopBufferingGenericPart<SampleStruct>(emptyBuffer_);
}

void SMIbuffer::stopEventBuffering(bool emptyBuffer_ /*= g_stopBufferEmptiesDefault*/)
{
    // remove callback function
    iV_SetEventCallback(nullptr);
    stopBufferingGenericPart<EventStruct>(emptyBuffer_);
}

std::vector<SampleStruct> SMIbuffer::consumeSamples(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<SampleStruct>(firstN_);
}
std::vector<SampleStruct> SMIbuffer::peekSamples(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<SampleStruct>(lastN_);
}
std::vector<EventStruct> SMIbuffer::consumeEvents(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<EventStruct>(firstN_);
}
std::vector<EventStruct> SMIbuffer::peekEvents(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<EventStruct>(lastN_);
}