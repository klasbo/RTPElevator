module feeds.button_lights;

import std.concurrency;

import feed;
import elevio.elev;
import feeds.request_consensus_hall;
import feeds.request_consensus_cab;

void thr(){
    subscribe!ActiveCabRequests;
    subscribe!ActiveHallRequests;
    while(true){
        receive(
            (ActiveHallRequests a){
                foreach(floor, reqsAtFloor; a){
                    foreach(call, req; reqsAtFloor){
                        callButtonLight(floor, cast(Call)call, req);
                    }
                }
            },
            (ActiveCabRequests a){
                foreach(floor, req; a){
                    callButtonLight(floor, Call.cab, req);
                }
            }
        );
    }
}