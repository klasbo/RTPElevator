module feeds.request_muxer;

import std.concurrency;
import std.stdio;

import elev_config;
public import elevio.elev_types : Call;
import feed;
import feeds.elevio_reader;
import feeds.request_consensus_cab;
import feeds.request_consensus_hall;
import feeds.elevator_control;
import feeds.call_button_demuxer;
import feeds.hall_request_assigner;

struct LocallyAssignedRequests {
    immutable(bool[3])[] requests;
    alias requests this;
}

void thr(){
    try {
    subscribe!LocallyAssignedHallRequests;
    subscribe!ActiveCabRequests;
    
    auto reqs = new bool[3][](numFloors);
    
    while(true){
        receive(
            (LocallyAssignedHallRequests a){
                foreach(int floor, ref reqsAtFloor; a){
                    foreach(call, ref req; reqsAtFloor){
                        reqs[floor][call] = a[floor][call];
                    }
                }
            },
            (ActiveCabRequests a){
                foreach(int floor, ref req; a){
                    reqs[floor][Call.cab] = req;
                }
            }
        );
        publish(LocallyAssignedRequests(reqs.idup));
    }
    } catch(Throwable t){ t.writeln; throw(t); }
}