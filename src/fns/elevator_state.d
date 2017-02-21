module fns.elevator_state;

public import elevio.elev : CallType, Dirn;

import std.algorithm;
import std.array;
import std.conv;
import std.range;

enum ElevatorBehaviour {
    uninitialized,
    idle,
    moving,
    doorOpen,
}

enum ElevatorError {
    none,
    movementTimeout,
    doorCloseTimeout,
}

struct LocalElevatorState {
    ElevatorBehaviour   behaviour;
    ElevatorError       error;
    int                 floor;
    Dirn                dirn;
}


struct ElevatorState {
    ElevatorBehaviour   behaviour;
    ElevatorError       error;
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
        e.error,
        e.floor,
        e.dirn
    );
}

ElevatorState withRequests(LocalElevatorState e, bool[] cabReqs, bool[2][] hallReqs){
    return ElevatorState(
        e.behaviour,
        e.error,
        e.floor,
        e.dirn,
        zip(hallReqs, cabReqs).map!(a => a[0] ~ a[1]).array.to!(bool[3][]),
    );
}

bool[2][] hallRequests(ElevatorState e){
    return e.requests.to!(bool[][]).map!(a => a[0..2]).array.to!(bool[2][]);
    // efficiency... :thinking:
}

