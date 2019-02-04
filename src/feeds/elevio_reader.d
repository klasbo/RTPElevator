module feeds.elevio_reader;

import core.thread;
import std.concurrency;
import std.conv;
import std.socket;
import std.stdio;
import std.string;

import elev_config;
import feed;
import elevio.elev;
public import elevio.elev : CallType;


struct Call {
    int         floor;
    CallType    call;
}

struct CabCall {
    int floor;
    alias floor this;
}

struct HallCall {
    int             floor;
    HallCallType    call;
}


struct FloorSensor {
    int floor;
    alias floor this;
}

struct StopButton {
    bool stop;
    alias stop this;
}

struct Obstruction {
    bool obstruction;
    alias obstruction this;
}






void thr(){

    elevio_init();

    bool[][]    call    = new bool[][](cfg.numFloors, CallType.max+1);
    int         floor   = -1;
    bool        stop    = 0;
    bool        obstr   = 0;

    while(true){
        Thread.sleep(cfg.feeds_elevioReader_pollrate.msecs);

       // Call button
        foreach(f; 0..cfg.numFloors){
            for(auto c = CallType.min; c <= CallType.max; c++){
                if(call[f][c] != (call[f][c] = callButton(f, c))  &&  call[f][c]){
                    final switch(c) with(CallType){
                    case hallUp:    publish(HallCall(f, HallCallType.up));      break;
                    case hallDown:  publish(HallCall(f, HallCallType.down));    break;
                    case cab:       publish(CabCall(f));                        break;
                    }
                    publish(Call(f, c));
                }
            }
        }

        // Floor sensor
        if(floor != (floor = floorSensor())  &&  floor != -1){
            publish(FloorSensor(floor));
        }

        // Stop button
        if(stop != (stop = stopButton())){
            publish(StopButton(stop));
        }

        // Obstruction
        if(obstr != (obstr = obstruction())){
            publish(Obstruction(obstr));
        }
    }
}









