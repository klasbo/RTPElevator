module feeds.call_button_demuxer;

import std.concurrency;
import std.stdio;

import feed;

import feeds.elevio_reader;
public import elevio.elev_types : HallCall;

struct CabRequest {
    int floor;
    alias floor this;
}

struct HallRequest {
    int         floor;
    HallCall    call;
}


void thr(){
    subscribe!CallButton;
    
    while(true){
        receive(
            (CallButton a){
                final switch(a.call) with(Call){
                case hallUp:
                    publish(HallRequest(a.floor, HallCall.up));
                    break;
                case hallDown:
                    publish(HallRequest(a.floor, HallCall.down));
                    break;
                case cab:
                    publish(CabRequest(a.floor));
                    break;
                }
            }
        );
    }
}