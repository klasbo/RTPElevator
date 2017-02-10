module fns.elevator_state;

public import elevio.elev : Call, Dirn;

import std.algorithm;
import std.array;
import std.conv;
import std.range;

enum ElevatorBehaviour {
    uninitialized,
    idle,
    moving,
    doorOpen,
    error,
}

struct LocalElevatorState {
    ElevatorBehaviour   behaviour;
    int                 floor;
    Dirn                dirn;
    bool[]              cabRequests;
    this(this){
        cabRequests = cabRequests.dup;
    }
}

struct LocalElevatorStateImm {
    ElevatorBehaviour   behaviour;
    int                 floor;
    Dirn                dirn;
    immutable(bool)[]   cabRequests;
    this(this){
        cabRequests = cabRequests.dup;
    }
}

struct ElevatorState {
    ElevatorBehaviour   behaviour;
    int                 floor;
    Dirn                dirn;
    bool[3][]           requests;
    this(this){
        requests = requests.dup;
    }
}

LocalElevatorState local(ElevatorState e){
    return LocalElevatorState(
        e.behaviour,
        e.floor,
        e.dirn,
        e.requests.map!(a => a[Call.cab]).array.dup,
    );
}

ElevatorState withHallRequests(LocalElevatorState e, bool[2][] hReqs){
    return ElevatorState(
        e.behaviour,
        e.floor,
        e.dirn,
        e.cabRequests.zip(hReqs).map!(a => a[1] ~ a[0]).array.to!(bool[3][]),
    );
}

bool[2][] hallRequests(ElevatorState e){
    return e.requests.to!(bool[][]).map!(a => a[0..2]).array.to!(bool[2][]);
    // efficiency... :thinking:
}

LocalElevatorStateImm imm(LocalElevatorState e){
    return LocalElevatorStateImm(
        e.behaviour,
        e.floor,
        e.dirn,
        e.cabRequests.idup,
    );
}

LocalElevatorState mut(LocalElevatorStateImm e){
    return LocalElevatorState(
        e.behaviour,
        e.floor,
        e.dirn,
        e.cabRequests.dup,
    );
}