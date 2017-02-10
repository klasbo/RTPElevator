module fns.elevator_algorithm;

import std.algorithm;
import std.range;
import std.stdio;

import fns.elevator_state;


private bool requestsAbove(ElevatorState e){
    return e.requests[e.floor+1..$].map!(a => a.array.any).any;
}

private bool requestsBelow(ElevatorState e){
    return e.requests[0..e.floor].map!(a => a.array.any).any;
}

bool anyRequests(ElevatorState e){
    return e.requests.map!(a => a.array.any).any;
}

bool anyRequestsAtFloor(ElevatorState e){
    return e.requests[e.floor].array.any;
}


bool shouldStop(ElevatorState e){
    final switch(e.dirn) with(Dirn){
    case up:
        return
            e.requests[e.floor][Call.hallUp]    ||
            e.requests[e.floor][Call.cab]       ||
            !e.requestsAbove                    ||
            e.floor == e.requests.length-1;
    case down:
        return
            e.requests[e.floor][Call.hallDown]  ||
            e.requests[e.floor][Call.cab]       ||
            !e.requestsBelow                    ||
            e.floor == 0;
    case stop:
        return true;
    }
}

Dirn chooseDirection(ElevatorState e){
    final switch(e.dirn) with(Dirn){
    case up:
        return
            e.requestsAbove ?   up      :
            e.requestsBelow ?   down    :
                                stop;
    case down, stop:
        return
            e.requestsBelow ?   down    :
            e.requestsAbove ?   up      :
                                stop;
    }
}

ElevatorState clearReqsAtFloor(ElevatorState e, void delegate(Call c) onClearedRequest = null){
    auto e2 = e;
    for(Call c = Call.min; c < e2.requests[0].length; c++){
        if(e2.requests[e2.floor][c]){
            if(&onClearedRequest){
                onClearedRequest(c);
            }
            e2.requests[e2.floor][c] = false;
        }
    }
    return e2;
}