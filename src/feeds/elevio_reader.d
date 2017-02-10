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
public import elevio.elev : Call;


struct CallButton {
    int floor;
    Call call;
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
    bool[][]    call    = new bool[][](numFloors, Call.max+1);
    int         floor   = -1;
    bool        stop    = 0;
    bool        obstr   = 0;

    while(true){
        Thread.sleep(feeds_elevioReader_pollrate.msecs);

       // Call button
        for(auto c = Call.min; c <= Call.max; c++){
            foreach(f; 0..numFloors){
                if(call[f][c] != (call[f][c] = callButton(f, c))  &&  call[f][c]){
                    publish(CallButton(f, c));
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









