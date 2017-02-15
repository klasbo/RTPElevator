module feeds.button_lights;

import std.concurrency;

import feed;
import elevio.elev;
import feeds.request_consensus_hall;
import feeds.request_consensus_cab;

void thr(){
    subscribe!LocalCabRequests;
    subscribe!ActiveHallRequests;
    while(true){
        receive(
            (ActiveHallRequests a){
                foreach(floor, reqsAtFloor; a){
                    foreach(call, req; reqsAtFloor){
                        callButtonLight(floor, cast(CallType)call, req);
                    }
                }
            },
            (LocalCabRequests a){
                foreach(floor, req; a){
                    callButtonLight(floor, CallType.cab, req);
                }
            }
        );
    }
}