#include "SMIbuffer/SMIbuffer.h"

#include <iostream>
#include <string>

#define BOOST_PYTHON_STATIC_LIB
#include <boost/python.hpp>
using namespace boost::python;


struct EyeDataConverter {
    void init() {
        auto collections = import("collections");
        auto namedtuple = collections.attr("namedtuple");
        list fields;
        fields.append("gazeX");
        fields.append("gazeY");
        fields.append("diam");
        fields.append("eyePositionX");
        fields.append("eyePositionY");
        fields.append("eyePositionZ");
        eyeDataTuple = namedtuple("eyeData", fields);
    }

    bool inited = false;
    api::object eyeDataTuple;

    api::object get(const EyeDataStruct& data_) {
        if (!inited)
        {
            init();
            inited = true;
        }
        return eyeDataTuple(data_.gazeX, data_.gazeY, data_.diam, data_.eyePositionX, data_.eyePositionY, data_.eyePositionZ);
    }
};
EyeDataConverter convertEyeData;

struct SampConverter {
    void init() {
        auto collections = import("collections");
        auto namedtuple = collections.attr("namedtuple");
        list fields;
        fields.append("timestamp");
        fields.append("leftEye");
        fields.append("rightEye");
        sampTuple = namedtuple("sample", fields);
    }

    bool inited = false;
    api::object sampTuple;

    list get(const std::vector<SampleStruct>& data_) {
        if (!inited)
        {
            init();
            inited = true;
        }
        list result;
        for (auto& samp : data_)
            result.append(sampTuple(samp.timestamp, convertEyeData.get(samp.leftEye), convertEyeData.get(samp.rightEye)));
        return result;
    }
};
SampConverter convertSamples;

struct EventConverter {
    void init() {
        auto collections = import("collections");
        auto namedtuple = collections.attr("namedtuple");
        list fields;
        fields.append("eventType");
        fields.append("eye");
        fields.append("startTime");
        fields.append("endTime");
        fields.append("duration");
        fields.append("positionX");
        fields.append("positionY");
        eventTuple = namedtuple("event", fields);
    }

    bool inited = false;
    api::object eventTuple;

    list get(const std::vector<EventStruct>& data_) {
        if (!inited)
        {
            init();
            inited = true;
        }
        list result;
        for (auto& evt : data_)
            result.append(eventTuple(evt.eventType, evt.eye, evt.startTime, evt.endTime, evt.duration, evt.positionX, evt.positionY));
        return result;
    }
};
EventConverter convertEvents;


list getEvents(SMIbuffer& smib_) {
    return convertEvents .get(smib_.getEvents());
}
list getSamples(SMIbuffer& smib_) {
    return convertSamples.get(smib_.getSamples());
}

// tell boost.python about functions with optional arguments
BOOST_PYTHON_MEMBER_FUNCTION_OVERLOADS(startSampleBuffering_overloads, SMIbuffer::startSampleBuffering, 0, 1);
BOOST_PYTHON_MEMBER_FUNCTION_OVERLOADS( startEventBuffering_overloads, SMIbuffer:: startEventBuffering, 0, 1);
// start module scope
BOOST_PYTHON_MODULE(SMIbuffer_python)
{
    class_<SMIbuffer, boost::noncopyable>("SMIbuffer", init<optional<bool>>())
        .def("startSampleBuffering", &SMIbuffer::startSampleBuffering, startSampleBuffering_overloads())
        .def("startEventBuffering" , &SMIbuffer:: startEventBuffering,  startEventBuffering_overloads())
        .def("clearSampleBuffer", &SMIbuffer::clearSampleBuffer)
        .def("clearEventBuffer" , &SMIbuffer:: clearEventBuffer)
        .def("stopSampleBuffering", &SMIbuffer::stopSampleBuffering)
        .def("stopEventBuffering" , &SMIbuffer:: stopEventBuffering)

        // get the data and command messages received since the last call to this function
        .def("getSamples", getSamples)
        .def("getEvents" , getEvents)
        ;
}