import std.file;
import std.getopt;
import std.stdio;
import std.string;
import std.traits;


import elevio.elev_types : ElevatorType;
import fns.elevator_state : ClearRequestType;

struct Config {
    ubyte               id;
    int                 numFloors;

    ElevatorType        elevio_elev_elevtype;
    string              elevio_elev_ip;
    ushort              elevio_elev_port;

    int                 feeds_elevioReader_pollrate;

    ushort              feeds_peerList_port;
    int                 feeds_peerList_timeout;
    int                 feeds_peerList_interval;

    ushort              feeds_elevatorStates_port;
    size_t              feeds_elevatorStates_bufSize;
    int                 feeds_elevatorStates_minPeriod;

    ushort              feeds_requestConsensusCab_port;
    ushort              feeds_requestConsensusHall_port;
    size_t              feeds_requestConsensus_bufSize;
    int                 feeds_requestConsensus_minPeriod;
    int                 feeds_requestConsensus_maxPeriod;

    int                 feeds_elevatorControl_doorOpenDuration;
    int                 feeds_elevatorControl_travelTimeEstimate;
    ClearRequestType    feeds_elevatorControl_clearRequestType;
}


__gshared Config cfg;


Config parseConfig(string[] contents, Config old = Config.init){
    Config cfg = old;

    string createGetopt(T)(){
        auto fieldnames = FieldNameTuple!(T);
        string res = q{ getopt( contents, std.getopt.config.passThrough, };
        foreach(fieldname; fieldnames){
            res ~= "\"" ~ fieldname ~ "\", &cfg." ~ fieldname ~ ", ";
        }
        res ~= ");";
        return res;
    }

    mixin(createGetopt!Config);

    return cfg;
}


Config loadConfig(string[] cmdLineArgs, string configFileName, Config old = Config.init){
    try {
        writeln("Reading config file...");
        old = configFileName.readText.split.parseConfig(old);
    } catch(Exception e){
        writeln("Encountered a problem when loading ", configFileName, ": ", e.msg, "\n");

    }

    if(cmdLineArgs.length > 1){
        try {
            writeln("Reading command line args...");
            old = cmdLineArgs.parseConfig(old);
        } catch(Exception e){
            writeln("Encountered a problem when reading command line args: ", e.msg, "\n");
        }
    }
    return old;
}