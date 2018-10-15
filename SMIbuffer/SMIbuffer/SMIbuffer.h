#pragma once
#include <vector>
#include <iViewXAPI.h>
#if _WIN64
#	pragma comment(lib, "iViewXAPI64.lib")
#else
#	pragma comment(lib, "iViewXAPI.lib")
#endif


namespace SMIbuff
{
    // default argument values
    constexpr size_t g_sampleBufDefaultSize = 1 << 22;

    constexpr size_t g_eventBufDefaultSize = 1 << 14;

    constexpr bool   g_stopBufferEmptiesDefault = false;
    constexpr size_t g_consumeDefaultAmount = -1;
    constexpr size_t g_peekDefaultAmount = 1;
}



class SMIbuffer
{
public:
    SMIbuffer(bool needsEyeSwap_ = false);
    ~SMIbuffer();

    void setEyeSwap(const bool& needsEyeSwap_);

    int startSampleBuffering(size_t initialBufferSize_ = SMIbuff::g_sampleBufDefaultSize);
    int startEventBuffering (size_t initialBufferSize_ = SMIbuff::g_eventBufDefaultSize);
    // clear all buffer contents
    void clearSampleBuffer();
    void clearEventBuffer ();
    // stop optionally deletes the buffer
    void stopSampleBuffering(bool emptyBuffer_ = SMIbuff::g_stopBufferEmptiesDefault);
    void stopEventBuffering (bool emptyBuffer_ = SMIbuff::g_stopBufferEmptiesDefault);

    // consume samples (by default all)
    std::vector<SampleStruct> consumeSamples(size_t firstN_ = SMIbuff::g_consumeDefaultAmount);
    // peek samples (by default only last one, can specify how many from end to peek)
    std::vector<SampleStruct> peekSamples(size_t lastN_ = SMIbuff::g_peekDefaultAmount);
    // consume events (by default all)
    std::vector<EventStruct>  consumeEvents(size_t firstN_ = SMIbuff::g_consumeDefaultAmount);
    // peek events (by default only last one, can specify how many from end to peek)
    std::vector<EventStruct>  peekEvents(size_t lastN_ = SMIbuff::g_peekDefaultAmount);

private:
    // SMI callbacks needs to be friends
    friend int __stdcall SMISampleCallback(SampleStruct sampleData_);
    friend int __stdcall SMIEventCallback (EventStruct   eventData_);

    //// generic functions for internal use
    // helpers
    template <typename T>  std::vector<T>&  getBuffer();
    // generic implementations
    template <typename T>  void             clearBuffer();
    template <typename T>  void             stopBufferingGenericPart(bool emptyBuffer_);
    template <typename T>  std::vector<T>   peek(size_t lastN_);
    template <typename T>  std::vector<T>   consume(size_t firstN_);

private:
    std::vector<SampleStruct> _sampleData;
    std::vector<EventStruct>  _eventData;
    bool                      _doEyeSwap;
};