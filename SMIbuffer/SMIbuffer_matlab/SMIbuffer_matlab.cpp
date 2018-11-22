#include "SMIbuffer/SMIbuffer.h"
#define DLL_EXPORT_SYM __declspec(dllexport)
#include "mex.h"

#include <map>

namespace {
    SMIbuffer* SMIbufferClassInstance = nullptr;  // as there can only be one instance (it gets reused), we can just store a ref to it in a global pointer
    // C++ object is of minimal size and does not have to be destroyed once created other than at mex unload

    // List actions
    enum class Action
    {
        New,
        Delete,

        StartSampleBuffering,
        ClearSampleBuffer,
        StopSampleBuffering,
        ConsumeSamples,
        PeekSamples,

        StartEventBuffering,
        ClearEventBuffer,
        StopEventBuffering,
        ConsumeEvents,
        PeekEvents
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        { "new",					Action::New },
        { "delete",					Action::Delete },

        { "startSampleBuffering",	Action::StartSampleBuffering },
        { "clearSampleBuffer",		Action::ClearSampleBuffer },
        { "stopSampleBuffering",	Action::StopSampleBuffering },
        { "consumeSamples",			Action::ConsumeSamples },
        { "peekSamples",			Action::PeekSamples },

        { "startEventBuffering",	Action::StartEventBuffering },
        { "clearEventBuffer",	    Action::ClearEventBuffer },
        { "stopEventBuffering",		Action::StopEventBuffering },
        { "consumeEvents",		    Action::ConsumeEvents },
        { "peekEvents",				Action::PeekEvents },
    };

    // forward declare
    mxArray* SampleVectorToMatlab(std::vector<SampleStruct> data_);
    mxArray* EventVectorToMatlab(std::vector<EventStruct> data_);
}

void DLL_EXPORT_SYM mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // get action string
    char *actionCstr = mxArrayToString(prhs[0]);
    std::string actionStr(actionCstr);
    mxFree(actionCstr);

    // get corresponding action
    if (actionTypeMap.count(actionStr) == 0)
        mexErrMsgTxt(("Unrecognized action (not in actionTypeMap): " + actionStr).c_str());
    Action action = actionTypeMap.at(actionStr);

    // Call the various class methods
    switch (action)
    {
        case Action::New:
        {
            if (nlhs < 0 || nrhs < 2)
                mexErrMsgTxt("new: Expected needsEyeSwap input.");
            if (!mxIsLogicalScalar(prhs[1]))
                mexErrMsgTxt("new: Expected argument to be a logical scalar.");
            bool needsEyeSwap = mxIsLogicalScalarTrue(prhs[1]);

            if (!SMIbufferClassInstance)
                SMIbufferClassInstance = new SMIbuffer(needsEyeSwap);
            else
            {
                // reset instance (clears buffers, clears registered callbacks)
                SMIbufferClassInstance->stopEventBuffering(true);
                SMIbufferClassInstance->stopSampleBuffering(true);
                SMIbufferClassInstance->setEyeSwap(needsEyeSwap);
            }
            return;
        }
        case Action::Delete:
            // reset instance (clears buffers, clears registered callbacks)
            SMIbufferClassInstance->stopEventBuffering(true);
            SMIbufferClassInstance->stopSampleBuffering(true);
            // Warn if other commands were ignored
            if (nrhs != 1)
                mexWarnMsgTxt("Delete: Unexpected arguments ignored.");
            return;
        case Action::StartSampleBuffering:
        {
            uint64_t bufSize = SMIbuff::g_sampleBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startSampleBuffering: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            
            plhs[0] = mxCreateDoubleScalar(SMIbufferClassInstance->startSampleBuffering(bufSize));
            return;
        }
        case Action::ClearSampleBuffer:
            SMIbufferClassInstance->clearSampleBuffer();
            return;
        case Action::StopSampleBuffering:
        {
            bool deleteBuffer = SMIbuff::g_stopBufferEmptiesDefault;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                    mexErrMsgTxt("stopSampleBuffering: Expected argument to be a logical scalar.");
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            }

            SMIbufferClassInstance->stopSampleBuffering(deleteBuffer);
            return;
        }
        case Action::ConsumeSamples:
        {
            uint64_t nSamp = SMIbuff::g_consumeDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("consumeSamples: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = SampleVectorToMatlab(SMIbufferClassInstance->consumeSamples(nSamp));
            return;
        }
        case Action::PeekSamples:
        {
            uint64_t nSamp = SMIbuff::g_peekDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("peekSamples: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = SampleVectorToMatlab(SMIbufferClassInstance->peekSamples(nSamp));
            return;
        }

        case Action::StartEventBuffering:
        {
            uint64_t bufSize = SMIbuff::g_eventBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startEventBuffering: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }

            plhs[0] = mxCreateDoubleScalar(SMIbufferClassInstance->startEventBuffering(bufSize));
            return;
        }
        case Action::ClearEventBuffer:
            // Call the method
            SMIbufferClassInstance->clearEventBuffer();
            return;
        case Action::StopEventBuffering:
        {
            bool deleteBuffer = SMIbuff::g_stopBufferEmptiesDefault;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                    mexErrMsgTxt("stopEventBuffering: Expected argument to be a logical scalar.");
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            }

            SMIbufferClassInstance->stopEventBuffering(deleteBuffer);
            return;
        }
        case Action::ConsumeEvents:
        {
            uint64_t nSamp = SMIbuff::g_consumeDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("consumeEvents: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = EventVectorToMatlab(SMIbufferClassInstance->consumeEvents(nSamp));
            return;
        }
        case Action::PeekEvents:
        {
            uint64_t nSamp = SMIbuff::g_peekDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("peekEvents: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = EventVectorToMatlab(SMIbufferClassInstance->peekEvents(nSamp));
            return;
        }

        default:
            mexErrMsgTxt(("Unhandled action: " + actionStr).c_str());
            break;
    }
}


// helpers
namespace
{

    template <typename D, typename O, typename T>
    mxArray* FieldToMatlab(std::vector<D> data_, mxClassID type_, T O::*field1)
    {
        mxArray* temp;
        auto storage = static_cast<T*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, data_.size(), type_, mxREAL)));
        size_t i = 0;
        for (auto &samp : data_)
            storage[i++] = samp.*field1;

        return temp;
    }

    template <typename D, typename O, typename T, typename O2, typename T2>
    mxArray* FieldToMatlab(std::vector<D> data_, mxClassID type_, T O::*field1, T2 O2::* field2)
    {
        mxArray* temp;
        auto storage = static_cast<T2*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, data_.size(), type_, mxREAL)));
        size_t i = 0;
        for (auto &samp : data_)
            storage[i++] = samp.*field1.*field2;

        return temp;
    }

    mxArray* EventVectorToMatlab(std::vector<EventStruct> data_)
    {
        const char* fieldNames[] = {"eventType","eye","startTime","endTime","duration","positionX","positionY"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, mxCHAR_CLASS, &EventStruct::eventType));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, mxCHAR_CLASS, &EventStruct::eye));
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, mxINT64_CLASS, &EventStruct::startTime));
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, mxINT64_CLASS, &EventStruct::endTime));
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, mxINT64_CLASS, &EventStruct::duration));
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, mxDOUBLE_CLASS, &EventStruct::positionX));
        mxSetFieldByNumber(out, 0, 6, FieldToMatlab(data_, mxDOUBLE_CLASS, &EventStruct::positionY));
        return out;
    }

    mxArray* EyeDataStructToMatlab(std::vector<SampleStruct> data_, EyeDataStruct SampleStruct::*whichEye)
    {
        const char* fieldNames[] = {"gazeX","gazeY","diam","eyePositionX","eyePositionY","eyePositionZ"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, mxDOUBLE_CLASS, whichEye, &EyeDataStruct::gazeX));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, mxDOUBLE_CLASS, whichEye, &EyeDataStruct::gazeY));
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, mxDOUBLE_CLASS, whichEye, &EyeDataStruct::diam));
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, mxDOUBLE_CLASS, whichEye, &EyeDataStruct::eyePositionX));
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, mxDOUBLE_CLASS, whichEye, &EyeDataStruct::eyePositionY));
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, mxDOUBLE_CLASS, whichEye, &EyeDataStruct::eyePositionZ));
        return out;
    }

    mxArray* SampleVectorToMatlab(std::vector<SampleStruct> data_)
    {
        // NB: planeNumber field is not provided by any of the supported eye tracker, so I ignore it here.

        const char* fieldNames[] = {"timestamp","leftEye","rightEye"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, mxINT64_CLASS, &SampleStruct::timestamp));
        mxSetFieldByNumber(out, 0, 1, EyeDataStructToMatlab(data_, &SampleStruct::leftEye));
        mxSetFieldByNumber(out, 0, 2, EyeDataStructToMatlab(data_, &SampleStruct::rightEye));

        return out;
    }
}