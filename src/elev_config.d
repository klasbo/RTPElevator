import std.stdio;
import std.meta;


import elevio.elev_types : ElevatorType;

mixin("elevator.con".conLoad!(

    ElevatorType,   "elevio_elevtype",
    
    ubyte,          "id",
    
    int,            "feeds_elevioReader_pollrate",
    
    ushort,         "feeds_peerList_port",
    int,            "feeds_peerList_timeout",
    int,            "feeds_peerList_interval",
    
    ushort,         "feeds_elevatorStates_port",
    size_t,         "feeds_elevatorStates_bufSize",
    int,            "feeds_elevatorStates_minPeriod",
    
    ushort,         "feeds_requestConsensusCab_port",
    ushort,         "feeds_requestConsensusHall_port",
    size_t,         "feeds_requestConsensus_bufSize",
    int,            "feeds_requestConsensus_minPeriod",
    int,            "feeds_requestConsensus_maxPeriod",
    
    int,            "feeds_elevatorControl_doorOpenDuration",
    int,            "feeds_elevatorControl_travelTimeEstimate",
));
mixin("simulator.con".conLoad!(
    int,            "numFloors",
));


string conLoad(Cvars...)(string filename){
    template parseSpecs(Specs...){
        static if (Specs.length == 0){
            alias types = AliasSeq!();
            alias names = AliasSeq!();
        } else static if (is(Specs[0])){
            static assert(is(typeof(Specs[1]) : string), "2nd arg not string");
            alias types = AliasSeq!(Specs[0], parseSpecs!(Specs[2 .. $]).types);
            alias names = AliasSeq!(Specs[1], parseSpecs!(Specs[2 .. $]).names);
        } else {
            static assert(0, "1st arg not valid");
        }
    }

    alias Ts = parseSpecs!(Cvars).types;
    alias Ns = parseSpecs!(Cvars).names;

    
    string str;

    foreach(i, N; Ns){
        str ~= "
        __gshared " ~ Ts[i].stringof ~ " " ~ N ~ ";";
    }
    str ~= "
        shared static this(){
            import std.file : readText;
            import std.getopt;
            import std.stdio;
            import std.string : split;
            try {
                string[] cfgContents;            
                cfgContents = readText(\"" ~ filename ~ "\").split;
                getopt( cfgContents,
                    std.getopt.config.passThrough,";
    foreach(i, N; Ns){
        str ~= "
                    \"" ~ N ~ "\", &" ~ N ~ ",";
    }
    str ~= "
                );            
            } catch(Exception e){
                writeln(\"Unable to load " ~ filename ~ ":\\n\", e.msg);
            }
        }";        
    return str;
}