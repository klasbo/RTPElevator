module event_loop.freeFuncs;

import  std.algorithm,
        std.conv,
        std.file,
        std.getopt,
        std.math,
        std.range,
        std.stdio;

import  elevator_driver,
        event_loop.types;


private {
    shared ulong travelTimeEstimate    = 4000;
    shared ulong doorOpenTime          = 3000;

    shared static this(){
        string[] configContents;
        try {
            configContents = readText("ElevatorConfig.con").split;
            getopt( configContents,
                std.getopt.config.passThrough,
                "eventLoop_doorOpenTime_ms",                &doorOpenTime,
                "eventLoop_bestFit_travelTimeEstimate_ms",  &travelTimeEstimate
            );
        } catch(Exception e){
            writeln("Unable to load event_loop config: ", e.msg);
        }
    }
}

ElevatorState[ID_t] filterAlive(ElevatorState[ID_t] states, ID_t[] alivePeers){
    return
    states.keys.zip(states.values)
    .filter!(a => alivePeers.canFind(a[0]))
    .assocArray;
}

GeneralizedElevatorState generalize(ElevatorState state, ID_t ID, ExternalOrder[][] externalOrders){
    return GeneralizedElevatorState(
        state.floor,
        state.dirn,
        state.moving,

        externalOrders
        .map!(ordersAtFloor =>
            ordersAtFloor
            .map!(order =>
                order.status == ExternalOrder.Status.active  &&
                order.assignedID == ID
            )
            .array
        )
        .zip(state.internalOrders)
        .map!(a => a[0] ~ a[1])
        .array,

        ID
    );
}

GeneralizedElevatorState[] generalize(ElevatorState[ID_t] states, ExternalOrder[][] externalOrders){
    return
    states.values.zip(states.keys)
    .map!(a =>
        a[0].generalize(a[1], externalOrders)
    )
    .array;
}

GeneralizedElevatorState[] augment(GeneralizedElevatorState[] states, btnPressEvent bpe){
    // Uses CommaExpression.
    bool[][] b;
    return
    states
    .map!(a =>
        GeneralizedElevatorState(
            a.floor,
            a.dirn,
            a.moving,
            ( b = a.orders.map!(a=>a.dup).array,
              b[bpe.floor][bpe.btn] = true,
              b),
            a.ID
        )
    )
    .array;
}

bool shouldStop(GeneralizedElevatorState state, int floor){
    final switch(state.dirn) with(MotorDirection){
    case UP:
        return  !state.ordersAbove  ||
                state.floor == state.orders.length  ||
                state.orders[floor][ButtonType.UP]  ||
                state.orders[floor][ButtonType.COMMAND];
    case DOWN:
        return  !state.ordersBelow  ||
                state.floor == 0  ||
                state.orders[floor][ButtonType.DOWN]  ||
                state.orders[floor][ButtonType.COMMAND];
    case STOP:
        return  true;
    }
}

bool ordersAbove(GeneralizedElevatorState state){
    return state.orders[state.floor+1..$].map!any.any;
}

bool ordersBelow(GeneralizedElevatorState state){
    return state.orders[0..state.floor].map!any.any;
}

MotorDirection chooseDirn(GeneralizedElevatorState state){
    if(!state.hasOrders){
        return MotorDirection.STOP;
    }
    final switch(state.dirn) with(MotorDirection){
    case UP:
        if(state.ordersAbove  &&  state.floor != state.orders.length){
            return UP;
        } else {
            return DOWN;
        }
    case DOWN:
        if(state.ordersBelow  &&  state.floor != 0){
            return DOWN;
        } else {
            return UP;
        }
    case STOP:
        if(state.ordersAbove){
            return UP;
        } else if(state.ordersBelow){
            return DOWN;
        } else {
            return STOP;
        }
    }
}

bool isIdle(GeneralizedElevatorState state){
    return !state.moving  &&  state.dirn == MotorDirection.STOP;
}

bool hasOrders(GeneralizedElevatorState state){
    return state.orders.map!any.any;
}

int numFloors(Elevator e){
    return e.maxFloor - e.minFloor + 1;
}



ElevatorState uninitializedElevatorState(int numFloors){
    return ElevatorState(
        -1,
        MotorDirection.STOP,
        false,
        new bool[](numFloors)
    );
}

string ack(int floor, ButtonType btn){
    return "ack" ~ floor.to!string ~ btn.to!string;
}



auto bestFit(GeneralizedElevatorState[] states, int floor = -1, ButtonType btn = ButtonType.COMMAND){

    struct Button {
        int         floor;
        ButtonType  btn;
    }

    ulong timeUntil(ref GeneralizedElevatorState s, Button b){
        int timeInDir;

        if(!s.orders.map!any.any){
            return 0;
        }
        if(b.floor != -1  &&  s.orders[b.floor][b.btn] == false){
            return 0;
        }
        if(s.floor == b.floor){
            s.orders[b.floor][b.btn] = false;
            return doorOpenTime;
        }

        final switch(s.dirn) with(MotorDirection){
        case STOP:
            int numButtonPresses = s.orders.map!(a => a.count(true)).reduce!"a+b".to!int;
            if(s.dirn == MotorDirection.STOP  &&  numButtonPresses > 1){
                writeln("dirn == STOP and more than one order makes no sense");
                return int.max;
            }
            int floorOfOnlyOrder = s.orders.map!any.countUntil(true).to!int;
            timeInDir += (s.floor - floorOfOnlyOrder).abs * travelTimeEstimate;
            timeInDir += doorOpenTime;

            s.orders[floorOfOnlyOrder][ButtonType.UP] = s.orders[floorOfOnlyOrder][ButtonType.DOWN] = s.orders[floorOfOnlyOrder][ButtonType.COMMAND] = false;
            s.floor = floorOfOnlyOrder;
            break;


        case UP:
            int floorOfTopOrder;
            if(b.floor != -1  &&  b.floor > s.floor  &&  b.btn == ButtonType.UP){
                floorOfTopOrder = b.floor;
            } else {
                floorOfTopOrder = (s.orders.length.to!int - 1 - s.orders.map!any.retro.countUntil(true).to!int);
            }
            timeInDir += (floorOfTopOrder - s.floor) * travelTimeEstimate;
            if(s.moving){
                s.floor++;
            }
            foreach(floor; s.floor..floorOfTopOrder){
                if(s.orders[floor][ButtonType.COMMAND]  ||  s.orders[floor][ButtonType.UP]){
                    timeInDir += doorOpenTime;
                    s.orders[floor][ButtonType.COMMAND] = s.orders[floor][ButtonType.UP] = false;
                }
            }
            timeInDir += doorOpenTime;

            s.orders[floorOfTopOrder][ButtonType.UP] = s.orders[floorOfTopOrder][ButtonType.DOWN] = s.orders[floorOfTopOrder][ButtonType.COMMAND] = false;
            s.floor = floorOfTopOrder;
            s.dirn = MotorDirection.DOWN;
            s.moving = true;
            break;


        case DOWN:
            int floorOfBottomOrder;
            if(b.floor != -1  &&  b.floor < s.floor  &&  b.btn == ButtonType.DOWN){
                floorOfBottomOrder = b.floor;
            } else {
                floorOfBottomOrder = s.orders.map!any.countUntil(true).to!int;
            }
            timeInDir += (s.floor - floorOfBottomOrder) * travelTimeEstimate;
            if(s.moving){
                s.floor--;
            }
            foreach(floor; floorOfBottomOrder+1..s.floor+1){
                if(s.orders[floor][ButtonType.COMMAND]  ||  s.orders[floor][ButtonType.DOWN]){
                    timeInDir += doorOpenTime;
                    s.orders[floor][ButtonType.COMMAND] = s.orders[floor][ButtonType.DOWN] = false;
                }
            }
            timeInDir += doorOpenTime;

            s.orders[floorOfBottomOrder][ButtonType.UP] = s.orders[floorOfBottomOrder][ButtonType.DOWN] = s.orders[floorOfBottomOrder][ButtonType.COMMAND] = false;
            s.floor = floorOfBottomOrder;
            s.dirn = MotorDirection.UP;
            s.moving = true;
            break;

        }

        if(timeInDir == 0){
            return 0;
        } else {
            return timeInDir + timeUntil(s, b);
        }
    }

    return
        states
        .map!( a => a,  a => timeUntil(a, Button(floor, btn)) )
        .array
        .sort!((a,b) => a[1] < b[1])
        .front[0]
        .ID;

}
