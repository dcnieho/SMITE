#include "SMIbuffer/SMIbuffer.h"
#define DLL_EXPORT_SYM __declspec(dllexport)
#include "mex.h"
#include "strHash.h"

#include <cwchar>
#include <algorithm>

namespace {
    SMIbuffer* SMIbufferClassInstance=nullptr;  // as there can only be one instance (it gets reused), we can just store a ref to it in a global pointer
    // C++ object is of minimal size and does not have to be destroyed once created other than at mex unload
}

mxArray* SampleVectorToMatlab(std::vector<SampleStruct> data_);
mxArray* EventVectorToMatlab(std::vector<EventStruct> data_);

void DLL_EXPORT_SYM mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // Get the command string
    char cmd[64] = {0};
    if (nrhs < 1 || mxGetString(prhs[0], cmd, sizeof(cmd)))
        mexErrMsgTxt("First input should be a command string less than 64 characters long.");
    size_t nChar = std::min(strlen(cmd),size_t(64));

    // Call the various class methods
    switch (rt::crc32(cmd, nChar))
    {
        case ct::crc32("new"):
            if (!SMIbufferClassInstance)
                SMIbufferClassInstance = new SMIbuffer;
            else
            {
                // reset instance (deletes buffers, clears registered callbacks)
                SMIbufferClassInstance->stopEventBuffering(true);
                SMIbufferClassInstance->stopSampleBuffering(true);
            }
            return;
        case ct::crc32("delete"):
            // reset instance (deletes buffers, clears registered callbacks)
            SMIbufferClassInstance->stopEventBuffering(true);
            SMIbufferClassInstance->stopSampleBuffering(true);
            // Warn if other commands were ignored
            if (nrhs != 1)
                mexWarnMsgTxt("Delete: Unexpected arguments ignored.");
            return;
        case ct::crc32("startSampleBuffering"):
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
        case ct::crc32("startEventBuffering"):
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
        case ct::crc32("clearSampleBuffer"):
            // Call the method
            SMIbufferClassInstance->clearSampleBuffer();
            return;
        case ct::crc32("clearEventBuffer"):
            // Call the method
            SMIbufferClassInstance->clearEventBuffer();
            return;
        case ct::crc32("stopSampleBuffering"):
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
        case ct::crc32("stopEventBuffering"):
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
        case ct::crc32("getSamples"):
            // Call the method
            plhs[0] = SampleVectorToMatlab(SMIbufferClassInstance->getSamples());
            return;
        case ct::crc32("getEvents"):
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