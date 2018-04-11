
import core.thread;
import std.algorithm;
import std.concurrency;
import std.range;
import std.stdio;
import std.traits;


import elev_config;
import feed;

import elevio.elev;

import feeds.elevio_reader;
import feeds.request_consensus_cab;
import feeds.request_consensus_hall;
import feeds.peer_list;
import feeds.elevator_states;
import feeds.request_muxer;

import fns.elevator_state;



void feedSupervisor(F...)(){
    struct Child {
        string name;
        Tid tid;
        void function() fn;
    }

    Child[] children;
    foreach(fn; F){
        children ~= Child(fullyQualifiedName!fn, spawnLinked(&fn), &fn);
    }    
    while(true){
        receive(
            (LinkTerminated lt){
                auto i = children.countUntil!(a => a.tid == lt.tid);
                writefln("[Feed-Supervisor]: %s\n     %s",
                    typeid(lt), children[i].name);
                unsubscribeAll(lt.tid);
                children[i].tid = spawnLinked(children[i].fn);
            }
        );
    }
}



void main(string[] args){

    cfg = loadConfig(args, "elevator.con");
    
    elevio_init();

    spawn(&feedSupervisor!(
        feeds.elevator_control.thr,
        feeds.elevio_lights.thr,
        feeds.elevio_reader.thr,
        feeds.request_consensus_cab.thr,
        feeds.request_consensus_hall.thr,
        feeds.peer_list.thr,
        feeds.request_muxer.thr,
        feeds.elevator_states.thr,
        feeds.hall_request_assigner.thr,
    ));


    writeln("Initialized");
    
    
    subscribe!FloorSensor;
    subscribe!PeerList;
    subscribe!LocalCabRequests;
    subscribe!ActiveCabRequests;
    subscribe!ActiveHallRequests;
    subscribe!ElevatorStates;
    subscribe!LocallyAssignedRequests;
    subscribe!ElevatorError;
    
    while(true){
        receive(
            (LocalCabRequests a){
                writefln("[Log]: %s\n     %(%s %)\n    [%(%d %)]",
                    typeid(a), iota(cfg.numFloors), a);
            },
            (ActiveCabRequests a){
                writefln("[Log]: %s\n         %(%s %)\n%(  %3d : [%(%d %)]%|\n%)",
                    typeid(a), iota(cfg.numFloors), a);
            },
            (ActiveHallRequests a){
                writefln("[Log]: %s\n     %(%s %)\n   [%([%(%d %)]%|\n    %)]", 
                    typeid(a), iota(cfg.numFloors), a.map!(r => r.array).array.transposed);
            },
            (LocallyAssignedRequests a){
                writefln("[Log]: %s\n     %(%s %)\n   [%([%(%d %)]%|\n    %)]", 
                    typeid(a), iota(cfg.numFloors), a.map!(r => r.array).array.transposed);
            },
            (ElevatorStates a){
                writefln("[Log]: %s\n%(  %3d : %s\n%)", 
                    typeid(a), a);
            },
            (ElevatorError a){
                writefln("[Log]: %s\n    %s", 
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
peer feed subscribe to elev_ctrl errors, or maybe just errors in general (multi-publisher)
+/