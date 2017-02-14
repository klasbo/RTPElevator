module feeds.elevator_states;

import std.concurrency;
import std.datetime;
import std.stdio;

import elev_config;
import feed;
import feeds.elevator_control;

import fns.elevator_state;

import net.udp_bcast;



struct ElevatorStates {
    shared LocalElevatorState[ubyte] states;
    alias states this;
}

private struct EStateMsg {
    ubyte id;
    LocalElevatorState state;
}

void thr(){
    try {
    net.udp_bcast.Config netcfg = {
        id :            id,
        port :          feeds_elevatorStates_port,
        recvFromSelf :  0,
        bufSize :       feeds_elevatorStates_bufSize,
    };
    Tid netTx = net.udp_bcast.init!(EStateMsg)(thisTid, netcfg);
    
    subscribe!LocalElevatorState;

    LocalElevatorState[ubyte] states;
    
    while(true){
        bool timeout = !receiveTimeout(feeds_elevatorStates_minPeriod.msecs,
            (LocalElevatorState a){
                states[id] = a;
                netTx.send(EStateMsg(id, states[id]));
                publish(ElevatorStates(cast(shared)states.dup));
            },
            (EStateMsg a){
                if(a.id !in states  ||  states[a.id] != a.state){
                    states[a.id] = a.state;
                    publish(ElevatorStates(cast(shared)states.dup));
                }
            }
        );
        if(timeout && id in states){
            netTx.send(EStateMsg(id, states[id]));
        }
    }
    } catch(Throwable t){ t.writeln; throw(t); }
}