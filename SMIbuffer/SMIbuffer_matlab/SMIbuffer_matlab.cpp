#include "SMIbuffer/SMIbuffer.h"
#define DLL_EXPORT_SYM __declspec(dllexport)
#include "mex.h"
#include "strHash.h"

#include <cwchar>
#include <algorithm>
#include <map>

namespace {
    SMIbuffer* SMIbufferClassInstance = nullptr;  // as there can only be one instance (it gets reused), we can just store a ref to it in a global pointer
    // C++ object is of minimal size and does not have to be destroyed once created other than at mex unload

    // List actions
    enum class Action
    {
        Touch,
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
        { "touch",					Action::Touch },
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
        case Action::Touch:
            // no-op
            break;
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
                // reset instance (deletes buffers, clears registered callbacks)
                SMIbufferClassInstance->stopEventBuffering(true);
                SMIbufferClassInstance->stopSampleBuffering(true);
                SMIbufferClassInstance->setEyeSwap(needsEyeSwap);
            }
            return;
        }
        case Action::Delete:
            // reset instance (deletes buffers, clears registered callbacks)
            SMIbufferClassInstance->stopEventBuffering(true);
            SMIbufferClassInstance->stopSampleBuffering(true);
            // Warn if other commands were ignored
            if (nrhs != 1)
                mexWarnMsgTxt("Delete: Unexpected arguments ignored.");
            return;
        case Action::StartSampleBuffering:
        {
            int ret;
            if (nrhs > 1 && !mxIsEmpty(prhs[1]))
            {
                if (!mxIsUint64(prhs[1]) || mxIsComplex(prhs[1]) || !mxIsScalar(prhs[1]))
                    mexErrMsgTxt("startSampleBuffering: Expected argument to be a uint64 scalar.");
                // Call the method
                ret = SMIbufferClassInstance->startSampleBuffering(static_cast<size_t>(mxGetScalar(prhs[1])));
            }
            else
            {
                ret = SMIbufferClassInstance->startSampleBuffering();
            }
            plhs[0] = mxCreateDoubleScalar(ret);
            return;
        }
        case Action::StartEventBuffering:
        {
            int ret;
            if (nrhs > 1 && !mxIsEmpty(prhs[1]))
            {
                if (!mxIsUint64(prhs[1]) || mxIsComplex(prhs[1]) || !mxIsScalar(prhs[1]))
                    mexErrMsgTxt("startEventBuffering: Expected argument to be a uint64 scalar.");
                // Call the method
                ret = SMIbufferClassInstance->startEventBuffering(static_cast<size_t>(mxGetScalar(prhs[1])));
            }
            else
            {
                ret = SMIbufferClassInstance->startEventBuffering();
            }
            plhs[0] = mxCreateDoubleScalar(ret);
            return;
        }
        case Action::ClearSampleBuffer:
            // Call the method
            SMIbufferClassInstance->clearSampleBuffer();
            return;
        case Action::ClearEventBuffer:
            // Call the method
            SMIbufferClassInstance->clearEventBuffer();
            return;
        case Action::StopSampleBuffering:
        {
            // Check parameters
            if (nlhs < 0 || nrhs < 2)
                mexErrMsgTxt("stopSampleBuffering: Expected deleteBuffer input.");
            if (!mxIsLogicalScalar(prhs[1]))
                mexErrMsgTxt("stopSampleBuffering: Expected argument to be a logical scalar.");
            bool deleteBuffer = mxIsLogicalScalarTrue(prhs[1]);
            // Call the method
            SMIbufferClassInstance->stopSampleBuffering(deleteBuffer);
            return;
        }
        case Action::StopEventBuffering:
        {
            // Check parameters
            if (nlhs < 0 || nrhs < 2)
                mexErrMsgTxt("stopEventBuffering: Expected deleteBuffer input.");
            if (!mxIsLogicalScalar(prhs[1]))
                mexErrMsgTxt("stopEventBuffering: Expected argument to be a logical scalar.");
            bool deleteBuffer = mxIsLogicalScalarTrue(prhs[1]);
            // Call the method
            SMIbufferClassInstance->stopEventBuffering(deleteBuffer);
            return;
        }
        case Action::ConsumeSamples:
            // Call the method
            plhs[0] = SampleVectorToMatlab(SMIbufferClassInstance->getSamples());
            return;
        case Action::ConsumeEvents:
            // Call the method
            plhs[0] = EventVectorToMatlab(SMIbufferClassInstance->getEvents());
            return;
        default:
            // Got here, so command not recognized
            mexErrMsgTxt("Command not recognized.");
    }
}

mxArray* EventVectorToMatlab(std::vector<EventStruct> data_)
{
    if (data_.empty())
        return mxCreateDoubleMatrix(0, 0, mxREAL);

    const char* fieldNames[] = {"eventType","eye","startTime","endTime","duration","positionX","positionY"};
    mxArray* out = mxCreateStructMatrix(data_.size(), 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
    size_t i = 0;
    for (auto &evt : data_)
    {
        mxArray *temp;
        mxSetFieldByNumber(out, i, 0, temp = mxCreateUninitNumericMatrix(1, 1, mxCHAR_CLASS, mxREAL));
        *static_cast<char*>(mxGetData(temp)) = evt.eventType;
        mxSetFieldByNumber(out, i, 1, temp = mxCreateUninitNumericMatrix(1, 1, mxCHAR_CLASS, mxREAL));
        *static_cast<char*>(mxGetData(temp)) = evt.eye;
        mxSetFieldByNumber(out, i, 2, temp = mxCreateUninitNumericMatrix(1, 1, mxINT64_CLASS, mxREAL));
        *static_cast<long long*>(mxGetData(temp)) = evt.startTime;
        mxSetFieldByNumber(out, i, 3, temp = mxCreateUninitNumericMatrix(1, 1, mxINT64_CLASS, mxREAL));
        *static_cast<long long*>(mxGetData(temp)) = evt.endTime;
        mxSetFieldByNumber(out, i, 4, temp = mxCreateUninitNumericMatrix(1, 1, mxINT64_CLASS, mxREAL));
        *static_cast<long long*>(mxGetData(temp)) = evt.duration;
        mxSetFieldByNumber(out, i, 5, mxCreateDoubleScalar(evt.positionX));
        mxSetFieldByNumber(out, i, 6, mxCreateDoubleScalar(evt.positionY));
        i++;
    }
    return out;
}

// helpers
namespace
{
    mxArray* EyeDataStructToMatlab(const EyeDataStruct& data_)
    {
        const char* fieldNames[] = {"gazeX","gazeY","diam","eyePositionX","eyePositionY","eyePositionZ"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        mxSetFieldByNumber(out, 0, 0, mxCreateDoubleScalar(data_.gazeX));
        mxSetFieldByNumber(out, 0, 1, mxCreateDoubleScalar(data_.gazeY));
        mxSetFieldByNumber(out, 0, 2, mxCreateDoubleScalar(data_.diam));
        mxSetFieldByNumber(out, 0, 3, mxCreateDoubleScalar(data_.eyePositionX));
        mxSetFieldByNumber(out, 0, 4, mxCreateDoubleScalar(data_.eyePositionY));
        mxSetFieldByNumber(out, 0, 5, mxCreateDoubleScalar(data_.eyePositionZ));
        return out;
    }

    mxArray* SampleVectorToMatlab(std::vector<SampleStruct> data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        const char* fieldNames[] = {"timestamp","leftEye","rightEye"};
        mxArray* out = mxCreateStructMatrix(data_.size(), 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        size_t i = 0;
        for (auto &samp : data_)
        {
            mxArray *temp;
            mxSetFieldByNumber(out, i, 0, temp = mxCreateUninitNumericMatrix(1, 1, mxINT64_CLASS, mxREAL));
            *static_cast<long long*>(mxGetData(temp)) = samp.timestamp;
            mxSetFieldByNumber(out, i, 1, EyeDataStructToMatlab(samp.leftEye));
            mxSetFieldByNumber(out, i, 2, EyeDataStructToMatlab(samp.rightEye));
            i++;
        }
        return out;
    }
}