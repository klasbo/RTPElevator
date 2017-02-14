
import core.thread;
import std.algorithm;
import std.concurrency;
import std.range;
import std.stdio;


import elev_config;
import feed;

import elevio.elev;

import feeds.call_button_demuxer;
import feeds.elevio_reader;
import feeds.request_consensus_cab;
import feeds.request_consensus_hall;
import feeds.peer_list;
import feeds.elevator_states;
import feeds.request_muxer;


void main(){
    spawn(&feeds.button_lights.thr);
    spawn(&feeds.call_button_demuxer.thr);
    spawn(&feeds.elevator_control.thr);
    spawn(&feeds.elevio_reader.thr);
    spawn(&feeds.floor_indicator.thr);
    spawn(&feeds.request_consensus_cab.thr);
    spawn(&feeds.request_consensus_hall.thr);
    spawn(&feeds.peer_list.thr);
    spawn(&feeds.request_muxer.thr);
    spawn(&feeds.elevator_states.thr);
    spawn(&feeds.hall_request_assigner.thr);


    writeln("Initialized");
    
    
    subscribe!FloorSensor;
    subscribe!PeerList;
    subscribe!LocalCabRequests;
    subscribe!ActiveCabRequests;
    subscribe!ActiveHallRequests;
    subscribe!ElevatorStates;
    subscribe!LocallyAssignedRequests;
    
    while(true){
        receive(
            (LocalCabRequests a){
                writefln("[Log]: %s\n     %(%s %)\n    [%(%d %)]",
                    typeid(a), iota(numFloors), a);
            },
            (ActiveCabRequests a){
                writefln("[Log]: %s\n         %(%s %)\n%(  %3d : [%(%d %)]%|\n%)",
                    typeid(a), iota(numFloors), a);
            },
            (ActiveHallRequests a){
                writefln("[Log]: %s\n     %(%s %)\n   [%([%(%d %)]%|\n    %)]", 
                    typeid(a), iota(numFloors), a.map!(r => r.array).array.transposed);
            },
            (LocallyAssignedRequests a){
                writefln("[Log]: %s\n     %(%s %)\n   [%([%(%d %)]%|\n    %)]", 
                    typeid(a), iota(numFloors), a.map!(r => r.array).array.transposed);
            },
            (ElevatorStates a){
                writefln("[Log]: %s\n%(  %3d : %s\n%)", 
                    typeid(a), a);
            },
            (Variant a){
                writeln("[Log]: ", a.type, "\n    ", a);
            }
        );
    }
}

/+
TODO
----

whatif elev_ctrl does not publish state for elev_states to broadcast? periodic thing in elev_ctrl?
    mostly relevant for init, make sure other e's know about us
peer feed subscribe to elev_ctrl errors, or maybe just errors in general (multi-publisher)
look into feed autorestart, should be doable with spawnlinked maybe
    LinkTerminated.tid. list of threadfn's and list of tids, lookup corresponding idx and respawn
    feeds.cleanup(Tid t) removes all instances of t subscribing to something

+/