module feeds.hall_request_assigner;

import std.algorithm;
import std.concurrency;
import std.stdio;

import elev_config;
import feed;
import feeds.request_consensus_hall;
import feeds.peer_list;
import feeds.elevator_states;
import fns.elevator_state;
import fns.optimal_hall_requests;

struct LocallyAssignedHallRequests {
    immutable(bool[2])[] requests;
    alias requests this;
}

void thr(){
    try {
    subscribe!ActiveHallRequests;
    subscribe!ElevatorStates;
    subscribe!PeerList;
    
    bool[2][]                   hallReqs        = new bool[2][](numFloors);
    LocalElevatorState[ubyte]   elevatorStates;
    ubyte[]                     peerList;
    
    while(true){
        receive(
            (ActiveHallRequests a){
                hallReqs = a.dup;
            },
            (ElevatorStates a){
                elevatorStates = (cast(LocalElevatorState[ubyte])(a.states)).dup;
            },
            (PeerList a){
                peerList = a.dup;
            },
        );
        publish(
            LocallyAssignedHallRequests(
                optimalHallRequests(id, hallReqs, elevatorStates, peerList).idup
            )
        );
    }    
    } catch(Throwable t){ t.writeln; throw(t); }
}