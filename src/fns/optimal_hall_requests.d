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
    bool[][ubyte]               cabReqs,
    LocalElevatorState[ubyte]   elevatorStates,
    ubyte[]                     peerList
){
    if(id !in elevatorStates){
        return hallReqs;
    }
    if(cabReqs.keys.sort() != elevatorStates.keys.sort()){
        writeln(__FUNCTION__, " error: elevatorStates & cabReqs do not share keys");
        return hallReqs;
    }
    debug(optimal_hall_requests) writefln("\n  ---- OPTIMAL ORDERS START ----\n");
    debug(optimal_hall_requests) scope(exit) writefln("\n  ---- OPTIMAL ORDERS END ----\n");
    auto reqs   = hallReqs.toReq;
    auto states = initialStates(elevatorStates, cabReqs, peerList);
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
        states.sort!("a.time < b.time")();    
    
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
    bool[]              cabReqs;
    Duration            time;
}




bool[2][] filterReq(alias fn)(Req[2][] reqs){
    return reqs.map!(a => a.to!(Req[]).map!(fn).array).array.to!(bool[2][]);
}

Req[2][] toReq(bool[2][] hallReqs){
    return hallReqs.map!(a => a.to!(bool[]).map!(b => Req(b, ubyte.init)).array).array.to!(Req[2][]);
}

ElevatorState withReqs(alias fn)(State s, Req[2][] reqs){
    return s.state.withRequests(s.cabReqs, reqs.filterReq!(fn));
}

bool anyUnassigned(Req[2][] reqs){
    return reqs
        .filterReq!(a => a.active && a.assignedTo == ubyte.init)
        .map!(a => a.to!(bool[]).any).any;
}

State[] initialStates(LocalElevatorState[ubyte] states, bool[][ubyte] cabReqs, ubyte[] peerList){
    return states.keys.zip(states.values)
        .filter!(a => 
            (peerList.canFind(a[0]) || a[0] == cfg.id)             && 
            a[1].behaviour != ElevatorBehaviour.uninitialized   &&
            a[1].error == ElevatorError.none
        )
        .map!(a => 
            State(a[0], a[1], cabReqs[a[0]], a[0].usecs)
        )
        .array;
}



void performInitialMove(ref State s, ref Req[2][] reqs){
    debug(optimal_hall_requests) writefln("initial move: %s", s);
    final switch(s.state.behaviour) with(ElevatorBehaviour){    
    case doorOpen:
        debug(optimal_hall_requests) writefln("  closing door");
        s.time += cfg.feeds_elevatorControl_doorOpenDuration.msecs/2;
        goto case idle;
    case idle:
        foreach(c; 0..2){
            if(reqs[s.state.floor][c].active){
                debug(optimal_hall_requests) writefln("  taking req %s at current floor", c);
                reqs[s.state.floor][c].assignedTo = s.id;
                s.time += cfg.feeds_elevatorControl_doorOpenDuration.msecs;
            }
        }
        break;
    case moving:
        debug(optimal_hall_requests) writefln("  arriving");
        s.state.floor += s.state.dirn;
        s.time += cfg.feeds_elevatorControl_travelTimeEstimate.msecs/2;
        break;
    case uninitialized:
        assert(0);
    }
}

void performSingleMove(ref State s, ref Req[2][] reqs){
    debug(optimal_hall_requests) writefln("single move: %s", s);
    
    auto e = s.withReqs!(a => a.active  &&  a.assignedTo == ubyte.init)(reqs);
    
    debug(optimal_hall_requests) writefln("%s", e);
    
    auto onClearRequest = (CallType c){
        final switch(c) with(CallType){
        case hallUp, hallDown:
            reqs[s.state.floor][c].assignedTo = s.id;
            break;
        case cab:
            s.cabReqs[s.state.floor] = false;
        }
    };
    
    final switch(s.state.behaviour) with(ElevatorBehaviour){
    case moving:
        if(e.shouldStop){
            debug(optimal_hall_requests) writefln("  stopping");
            s.state.behaviour = doorOpen;
            s.time += cfg.feeds_elevatorControl_doorOpenDuration.msecs;
            e.clearReqsAtFloor(onClearRequest);
        } else {
            debug(optimal_hall_requests) writefln("  continuing");
            s.state.floor += s.state.dirn;
            s.time += cfg.feeds_elevatorControl_travelTimeEstimate.msecs;
        }
        break;
    case idle, doorOpen:
        s.state.dirn = e.chooseDirection;
        if(s.state.dirn == Dirn.stop){
            if(e.anyRequestsAtFloor){
                e.clearReqsAtFloor(onClearRequest);
                debug(optimal_hall_requests) writefln("  taking req in opposite dirn");
            } else {
                s.state.behaviour = idle;
                debug(optimal_hall_requests) writefln("  idling");
            }
        } else {
            s.state.behaviour = moving;
            debug(optimal_hall_requests) writefln("  departing");
            s.state.floor += s.state.dirn;
            s.time += cfg.feeds_elevatorControl_travelTimeEstimate.msecs;
        }
        break;
    case uninitialized:
        assert(0);
    }
}

// all unvisited hall requests are at floors with elevators with no cab requests
bool unvisitedAreImmediatelyAssignable(Req[2][] reqs, State[] states){
    if(states.map!(a => a.cabReqs.any).any){
        return false;
    }
    foreach(f, reqsAtFloor; reqs){
        foreach(c, req; reqsAtFloor){
            if(req.active && req.assignedTo == ubyte.init){
                if(states.filter!(a => a.state.floor == f && !a.cabReqs.any).empty){
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
            foreach(ref s; states){
                if(req.active && req.assignedTo == ubyte.init){
                    if(s.state.floor == f && !s.cabReqs.any){
                        req.assignedTo = s.id;
                        s.time += cfg.feeds_elevatorControl_doorOpenDuration.msecs;
                    }
                }
            }
        }
    }    
}









unittest {
    LocalElevatorState[ubyte] states = [
        1 : LocalElevatorState(ElevatorBehaviour.idle,      ElevatorError.none, 0, Dirn.stop),
        2 : LocalElevatorState(ElevatorBehaviour.doorOpen,  ElevatorError.none, 3, Dirn.down),
        3 : LocalElevatorState(ElevatorBehaviour.moving,    ElevatorError.none, 2, Dirn.up  ),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [true,  false],
        [false, false],
        [false, false],
    ];
    
    bool[][ubyte] cabReqs = [
        1 : [0, 0, 0, 0].to!(bool[]),
        2 : [1, 0, 0, 0].to!(bool[]),
        3 : [1, 0, 0, 1].to!(bool[]),
    ];

    ubyte[] peers = [1, 2, 3];

    ubyte id = 1;

    auto optimal = optimalHallRequests(id, hallreqs, cabReqs, states, peers);
    assert(optimal[1][CallType.hallUp]);
}

unittest {
    // Two elevators moving from each "end" toward the middle floors
    // Elevators should stop at the closest order, even if it is in the "wrong" direction
    LocalElevatorState[ubyte] states = [
        1 : LocalElevatorState(ElevatorBehaviour.idle, ElevatorError.none, 0, Dirn.stop),
        2 : LocalElevatorState(ElevatorBehaviour.idle, ElevatorError.none, 3, Dirn.stop),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [false, true],
        [true,  false],
        [false, false],
    ];
    
    bool[][ubyte] cabReqs = [
        1 : [0, 0, 0, 0].to!(bool[]),
        2 : [0, 0, 0, 0].to!(bool[]),
    ];

    ubyte[] peers = [1, 2];

    ubyte id = 1;

    auto optimal = optimalHallRequests(id, hallreqs, cabReqs, states, peers);
    assert(!optimal[2][CallType.hallUp]);
    assert(optimal[1][CallType.hallDown]);

    states = [
        1 : LocalElevatorState(ElevatorBehaviour.moving, ElevatorError.none, 0, Dirn.up  ), // only change from prev scenario
        2 : LocalElevatorState(ElevatorBehaviour.idle,   ElevatorError.none, 3, Dirn.stop),
    ];

    optimal = optimalHallRequests(id, hallreqs, cabReqs, states, peers);
    assert(!optimal[2][CallType.hallUp]);
    assert(optimal[1][CallType.hallDown]);
}

unittest {
    // Two elevators are the same number of floors away from an order, but one is moving toward it
    // Should give the order to the moving elevator
    LocalElevatorState[ubyte] states = [
        27 : LocalElevatorState(ElevatorBehaviour.moving,   ElevatorError.none, 1,  Dirn.down),
        20 : LocalElevatorState(ElevatorBehaviour.doorOpen, ElevatorError.none, 1,  Dirn.down),
    ];

    bool[2][] hallreqs = [
        [true,  false],
        [false, false],
        [false, false],
        [false, false],
    ];
    
    bool[][ubyte] cabReqs = [
        27 : [0, 0, 0, 0].to!(bool[]),
        20 : [0, 0, 0, 0].to!(bool[]),
    ];

    ubyte[] peers = [20, 27];

    ubyte id = 27;

    auto optimal = optimalHallRequests(id, hallreqs, cabReqs, states, peers);
    assert(optimal[0][CallType.hallUp]);
}

unittest {
    LocalElevatorState[ubyte] states = [
        1 : LocalElevatorState(ElevatorBehaviour.moving,    ElevatorError.none, 1, Dirn.up  ),
        2 : LocalElevatorState(ElevatorBehaviour.idle,      ElevatorError.none, 1, Dirn.stop),
        3 : LocalElevatorState(ElevatorBehaviour.idle,      ElevatorError.none, 1, Dirn.stop),
    ];

    bool[2][] hallreqs = [
        [true,  false],
        [false, false],
        [false, false],
        [false, true],
    ];
    
    bool[][ubyte] cabReqs = [
        1 : [0, 0, 0, 0].to!(bool[]),
        2 : [0, 0, 0, 0].to!(bool[]),
        3 : [0, 0, 0, 0].to!(bool[]),
    ];

    ubyte[] peers = [1, 2, 3];

    ubyte id = 1;

    assert(optimalHallRequests(1, hallreqs, cabReqs, states, peers) == [[0,0], [0,0], [0,0], [0,1]].to!(bool[2][]));
    assert(optimalHallRequests(2, hallreqs, cabReqs, states, peers) == [[1,0], [0,0], [0,0], [0,0]].to!(bool[2][]));
    assert(optimalHallRequests(3, hallreqs, cabReqs, states, peers) == [[0,0], [0,0], [0,0], [0,0]].to!(bool[2][]));
}




