#include "SMIbuffer/SMIbuffer.h"
#define DLL_EXPORT_SYM __declspec(dllexport)
#include "mex.h"
#include "class_handle.hpp"
#include "strHash.h"

#include <cwchar>
#include <algorithm>

mxArray* SampleVectorToMatlab(std::vector<SampleStruct> data_);
mxArray* EventVectorToMatlab(std::vector<EventStruct> data_);

void DLL_EXPORT_SYM mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // Get the command string
    char cmd[64] = {0};
    if (nrhs < 1 || mxGetString(prhs[0], cmd, sizeof(cmd)))
        mexErrMsgTxt("First input should be a command string less than 64 characters long.");
    size_t nChar = std::min(strlen(cmd),size_t(64));

    // New
    if (!strcmp("new", cmd)) {
        // Check parameters
        if (nlhs != 1)
            mexErrMsgTxt("New: One output expected.");
        // Return a handle to a new C++ instance
        plhs[0] = convertPtr2Mat<SMIbuffer>(new SMIbuffer);
        return;
    }

    // Check there is a second input, which should be the class instance handle
    if (nrhs < 2)
        mexErrMsgTxt("Second input should be a class instance handle.");

    // Delete
    if (!strcmp("delete", cmd)) {
        // Destroy the C++ object
        destroyObject<SMIbuffer>(prhs[1]);
        // Warn if other commands were ignored
        if (nlhs != 0 || nrhs != 2)
            mexWarnMsgTxt("Delete: Unexpected arguments ignored.");
        return;
    }

    // Get the class instance pointer from the second input
    SMIbuffer *SMIBufInstance = convertMat2Ptr<SMIbuffer>(prhs[1]);

    // Call the various class methods
    switch (rt::crc32(cmd, nChar))
    {
        case ct::crc32("startSampleBuffering"):
        {
            // Check parameters
            if (nlhs < 0 || nrhs < 2)
                mexErrMsgTxt("startSampleBuffering: Unexpected arguments.");
            bool success;
            if (nrhs > 2)
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startSampleBuffering: Expected argument to be a uint64 scalar.");
                // Call the method
                success = SMIBufInstance->startSampleBuffering(static_cast<size_t>(mxGetScalar(prhs[2])));
            }
            else
            {
                success = SMIBufInstance->startSampleBuffering();
            }
            plhs[0] = mxCreateLogicalMatrix(1, 1);
            *static_cast<bool*>(mxGetData(plhs[0])) = success;
            return;
        }
        case ct::crc32("startEventBuffering"):
        {
            // Check parameters
            if (nlhs < 0 || nrhs < 2)
                mexErrMsgTxt("startEventBuffering: Unexpected arguments.");
            bool success;
            if (nrhs > 2)
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startEventBuffering: Expected argument to be a uint64 scalar.");
                // Call the method
                success = SMIBufInstance->startEventBuffering(static_cast<size_t>(mxGetScalar(prhs[2])));
            }
            else
            {
                success = SMIBufInstance->startEventBuffering();
            }
            plhs[0] = mxCreateLogicalMatrix(1, 1);
            *static_cast<bool*>(mxGetData(plhs[0])) = success;
            return;
        }
        case ct::crc32("clearSampleBuffer"):
            // Check parameters
            if (nrhs < 2)
                mexErrMsgTxt("clearSampleBuffer: Unexpected arguments.");
            // Call the method
            SMIBufInstance->clearSampleBuffer();
            return;
        case ct::crc32("clearEventBuffer"):
            // Check parameters
            if (nrhs < 2)
                mexErrMsgTxt("clearEventBuffer: Unexpected arguments.");
            // Call the method
            SMIBufInstance->clearEventBuffer();
            return;
        case ct::crc32("stopSampleBuffering"):
        {
            // Check parameters
            if (nlhs < 0 || nrhs < 3)
                mexErrMsgTxt("stopSampleBuffering: Expected deleteBuffer input.");
            if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                mexErrMsgTxt("stopSampleBuffering: Expected argument to be a logical scalar.");
            bool deleteBuffer;
            if (mxIsDouble(prhs[2]))
                deleteBuffer = !!mxGetScalar(prhs[2]);
            else
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            // Call the method
            SMIBufInstance->stopSampleBuffering(deleteBuffer);
            return;
        }
        case ct::crc32("stopEventBuffering"):
        {
            // Check parameters
            if (nlhs < 0 || nrhs < 3)
                mexErrMsgTxt("stopEventBuffering: Expected deleteBuffer input.");
            if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                mexErrMsgTxt("stopEventBuffering: Expected argument to be a logical scalar.");
            bool deleteBuffer;
            if (mxIsDouble(prhs[2]))
                deleteBuffer = !!mxGetScalar(prhs[2]);
            else
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            // Call the method
            SMIBufInstance->stopEventBuffering(deleteBuffer);
            return;
        }
        case ct::crc32("getSamples"):
            // Check parameters
            if (nlhs < 1 || nrhs < 2)
                mexErrMsgTxt("getSamples: Unexpected arguments.");
            // Call the method
            plhs[0] = SampleVectorToMatlab(SMIBufInstance->getSamples());
            return;
        case ct::crc32("getEvents"):
            // Check parameters
            if (nlhs < 1 || nrhs < 2)
                mexErrMsgTxt("getEvents: Unexpected arguments.");
            // Call the method
            plhs[0] = EventVectorToMatlab(SMIBufInstance->getEvents());
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

    const char* fieldNames[] = {"timestamp","leftEye","rightEye","planeNumber"};
    mxArray* out = mxCreateStructMatrix(data_.size(), 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
    size_t i = 0;
    for (auto &samp : data_)
    {
        mxArray *temp;
        mxSetFieldByNumber(out, i, 0, temp = mxCreateUninitNumericMatrix(1, 1, mxINT64_CLASS, mxREAL));
        *static_cast<long long*>(mxGetData(temp)) = samp.timestamp;
        mxSetFieldByNumber(out, i, 1, EyeDataStructToMatlab(samp.leftEye));
        mxSetFieldByNumber(out, i, 2, EyeDataStructToMatlab(samp.rightEye));
        mxSetFieldByNumber(out, i, 3, temp = mxCreateUninitNumericMatrix(1, 1, mxINT32_CLASS, mxREAL));
        *static_cast<int*>(mxGetData(temp)) = samp.planeNumber;
        i++;
    }
    return out;
}