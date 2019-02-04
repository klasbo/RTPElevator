import std.file;
import std.getopt;
import std.stdio;
import std.string;
import std.traits;


import elevio.elev_types : ElevatorType;
import fns.elevator_state : ClearRequestType;

struct Config {
    ubyte               id                                              = 1;
    int                 numFloors                                       = 4;

    ElevatorType        elevio_elev_elevtype                            = ElevatorType.simulation;
    string              elevio_elev_ip                                  = "localhost";
    ushort              elevio_elev_port                                = 15657;

    int                 feeds_elevioReader_pollrate                     = 25;

    ushort              feeds_peerList_port                             = 16567;
    int                 feeds_peerList_timeout                          = 550;
    int                 feeds_peerList_interval                         = 50;

    ushort              feeds_elevatorStates_port                       = 16568;
    size_t              feeds_elevatorStates_bufSize                    = 1024;
    int                 feeds_elevatorStates_minPeriod                  = 100;

    ushort              feeds_requestConsensusCab_port                  = 16569;
    ushort              feeds_requestConsensusHall_port                 = 16570;
    size_t              feeds_requestConsensus_bufSize                  = 1024;
    int                 feeds_requestConsensus_minPeriod                = 100;
    int                 feeds_requestConsensus_maxPeriod                = 150;

    int                 feeds_elevatorControl_doorOpenDuration          = 3000;
    int                 feeds_elevatorControl_travelTimeEstimate        = 2500;
    ClearRequestType    feeds_elevatorControl_clearRequestType          = ClearRequestType.inDirn;
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