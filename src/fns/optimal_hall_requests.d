module fns.optimal_hall_requests;

//debug = optimal_hall_requests;

import fns.elevator_state;
import fns.elevator_algorithm;

import std.algorithm;
import std.conv;
import std.datetime;
import std.range;
import std.stdio;

import elev_config;

bool[2][] optimalHallRequests(
    ubyte                       id, 
    bool[2][]                   hallReqs, 
    LocalElevatorState[ubyte]   elevatorStates,
    ubyte[]                     peerList
){
    if(id !in elevatorStates){
        return hallReqs;
    }
    debug(optimal_hall_requests) writefln("\n  ---- OPTIMAL ORDERS START ----\n");
    debug(optimal_hall_requests) scope(exit) writefln("\n  ---- OPTIMAL ORDERS END ----\n");
    auto reqs   = hallReqs.toReq;
    auto states = initialStates(elevatorStates, peerList);
    if(states.empty || !states.any!(a => a.id == id)){
        debug(optimal_hall_requests) writeln("requested state not eligible");
        return hallReqs;
    }
    
    debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
    debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    
    foreach(ref s; states){
        performInitialMove(s, reqs);
    }
    
    while(true){
        debug(optimal_hall_requests) writeln;
        debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
        debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    
        bool done = true;
        if(reqs.anyUnassigned){
            done = false;
        }
        if(unvisitedAreImmediatelyAssignable(reqs, states)){
            debug(optimal_hall_requests) writefln("unvisited immediately assignable");
            assignImmediate(reqs, states);
            done = true;
        }
        
        if(done){
            break;
        }
    
    
        states.sort!("a.time < b.time")();
        performSingleMove(states[0], reqs);
    }
    
    auto ourState = states.find!(a => a.id == id)[0];
    auto ret = ourState.withReqs!(a => a.assignedTo == id)(reqs).hallRequests;
    
    debug(optimal_hall_requests) writefln("\nfinal:");
    debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
    debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    debug(optimal_hall_requests) writefln("ours(%s):\n%(  %(%s, %)\n%)", id, ret);
    
    return ret;
}

private :

struct Req {
    bool    active;
    ubyte   assignedTo;
}

struct State {
    ubyte               id;
    LocalElevatorState  state;
    Duration            time;
}




bool[2][] filterReq(alias fn)(Req[2][] reqs){
    return reqs.map!(a => a.to!(Req[]).map!(fn).array).array.to!(bool[2][]);
}

Req[2][] toReq(bool[2][] hallReqs){
    return hallReqs.map!(a => a.to!(bool[]).map!(b => Req(b, ubyte.init)).array).array.to!(Req[2][]);
}

ElevatorState withReqs(alias fn)(State s, Req[2][] reqs){
    return s.state.withHallRequests(reqs.filterReq!(fn));
}

bool anyUnassigned(Req[2][] reqs){
    return reqs
        .filterReq!(a => a.active && a.assignedTo == ubyte.init)
        .map!(a => a.to!(bool[]).any).any;
}

State[] initialStates(LocalElevatorState[ubyte] states, ubyte[] peerList){
    auto ineligibleBehaviours = [
        ElevatorBehaviour.uninitialized,
        ElevatorBehaviour.error,
    ];
    return states.keys.zip(states.values)
        .filter!(a => 
            (peerList.canFind(a[0]) || a[0] == .id) && 
            !ineligibleBehaviours.canFind(a[1].behaviour))
        .map!(a => 
            State(a[0], a[1], a[0].usecs)
        )
        .array;
}



void performInitialMove(ref State s, ref Req[2][] reqs){
    debug(optimal_hall_requests) writefln("initial move: %s", s);
    final switch(s.state.behaviour) with(ElevatorBehaviour){    
    case doorOpen:
        debug(optimal_hall_requests) writefln("  closing door");
        s.time += feeds_elevatorControl_doorOpenDuration.msecs/2;
        goto case idle;
    case idle:
        foreach(c; 0..2){
            if(reqs[s.state.floor][c].active){
                debug(optimal_hall_requests) writefln("  taking req %s at current floor", c);
                reqs[s.state.floor][c].assignedTo = s.id;
                s.time += feeds_elevatorControl_doorOpenDuration.msecs;
            }
        }
        break;
    case moving:
        debug(optimal_hall_requests) writefln("  arriving");
        s.state.floor += s.state.dirn;
        s.time += feeds_elevatorControl_travelTimeEstimate.msecs/2;
        break;
    case uninitialized, error:
        assert(0);
    }
}

void performSingleMove(ref State s, ref Req[2][] reqs){
    debug(optimal_hall_requests) writefln("single move: %s", s);
    auto e = s.withReqs!(a => a.active && (a.assignedTo == ubyte.init || a.assignedTo == s.id))(reqs);
    debug(optimal_hall_requests) writefln("%s", e);
    final switch(s.state.behaviour) with(ElevatorBehaviour){
    case moving:
        if(e.shouldStop){
            debug(optimal_hall_requests) writefln("  stopping");
            s.state.behaviour = doorOpen;
            s.time += feeds_elevatorControl_doorOpenDuration.msecs;
            e.clearReqsAtFloor((Call c){
                final switch(c) with(Call){
                case hallUp, hallDown:
                    reqs[s.state.floor][c].assignedTo = s.id;
                    break;
                case cab:
                    s.state.cabRequests[s.state.floor] = false;
                }
            });
        } else {
            debug(optimal_hall_requests) writefln("  continuing");
            s.state.floor += s.state.dirn;
            s.time += feeds_elevatorControl_travelTimeEstimate.msecs;
        }
        break;
    case idle, doorOpen:
        s.state.dirn = e.chooseDirection;
        if(s.state.dirn == Dirn.stop){
            s.state.behaviour = idle;
            debug(optimal_hall_requests) writefln("  idling");
        } else {
            s.state.behaviour = moving;
            debug(optimal_hall_requests) writefln("  departing");
            s.state.floor += s.state.dirn;
            s.time += feeds_elevatorControl_travelTimeEstimate.msecs;
        }
        break;
    case uninitialized, error:
        assert(0);
    }
}

// all unvisited hall requests are at floors with elevators with no cab requests
bool unvisitedAreImmediatelyAssignable(Req[2][] reqs, State[] states){
    foreach(f, reqsAtFloor; reqs){
        foreach(c, req; reqsAtFloor){
            if(req.active && req.assignedTo == ubyte.init){
                if(states.filter!(a => a.state.floor == f && !a.state.cabRequests.any).empty){
                    return false;
                }
            }
        }
    }
    return true;
}

void assignImmediate(ref Req[2][] reqs, ref State[] states){
    foreach(f, ref reqsAtFloor; reqs){
        foreach(c, ref req; reqsAtFloor){
            if(req.active && req.assignedTo == ubyte.init){
                foreach(ref s; states){
                    if(s.state.floor == f && !s.state.cabRequests.any){
                        req.assignedTo = s.id;
                        s.time += feeds_elevatorControl_doorOpenDuration.msecs;
                    }
                }
            }
        }
    }    
}









unittest {
    LocalElevatorState[ubyte] states = [
        1 : LocalElevatorState(ElevatorBehaviour.idle,       0, Dirn.stop,   [0, 0, 0, 0].to!(bool[])),
        2 : LocalElevatorState(ElevatorBehaviour.doorOpen,   3, Dirn.down,   [1, 0, 0, 0].to!(bool[])),
        3 : LocalElevatorState(ElevatorBehaviour.moving,     2, Dirn.up,     [1, 0, 0, 1].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [true,  false],
        [false, false],
        [false, false],
    ];

    ubyte[] peers = [1, 2, 3];

    ubyte id = 1;

    auto optimal = optimalHallRequests(id, hallreqs, states, peers);
    assert(optimal[1][Call.hallUp]);
}

unittest {
    // Two elevators moving from each "end" toward the middle floors
    // Elevators should stop at the closest order, even if it is in the "wrong" direction
    LocalElevatorState[ubyte] states = [
        1 : LocalElevatorState(ElevatorBehaviour.idle, 0, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
        2 : LocalElevatorState(ElevatorBehaviour.idle, 3, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [false, true],
        [true,  false],
        [false, false],
    ];

    ubyte[] peers = [1, 2];

    ubyte id = 1;

    auto optimal = optimalHallRequests(id, hallreqs, states, peers);
    assert(!optimal[2][Call.hallUp]);
    assert(optimal[1][Call.hallDown]);

    states = [
        1 : LocalElevatorState(ElevatorBehaviour.moving, 0, Dirn.up,   [0, 0, 0, 0].to!(bool[])), // only change from prev scenario
        2 : LocalElevatorState(ElevatorBehaviour.idle,   3, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
    ];

    optimal = optimalHallRequests(id, hallreqs, states, peers);
    assert(!optimal[2][Call.hallUp]);
    assert(optimal[1][Call.hallDown]);
}

unittest {
    // Two elevators are the same number of floors away from an order, but one is moving toward it
    // Should give the order to the moving elevator
    LocalElevatorState[ubyte] states = [
        27 : LocalElevatorState(ElevatorBehaviour.moving,   1,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
        20 : LocalElevatorState(ElevatorBehaviour.doorOpen, 1,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [true,  false],
        [false, false],
        [false, false],
        [false, false],
    ];

    ubyte[] peers = [20, 27];

    ubyte id = 27;

    auto optimal = optimalHallRequests(id, hallreqs, states, peers);
    assert(optimal[0][Call.hallUp]);
}


