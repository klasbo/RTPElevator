module event_loop.free_funcs;

import  std.algorithm,
        std.conv,
        std.file,
        std.getopt,
        std.math,
        std.typecons,
        std.range,
        std.stdio;

import  elevator_driver,
        event_loop.types;




ElevatorState[ID] filterAlive(ElevatorState[ID] states, ID[] alivePeers){
    return
        states.keys.zip(states.values)
        .filter!(a => alivePeers.canFind(a[0]))
        .assocArray;
}

GeneralizedElevatorState generalize(ElevatorState state, ID id, ExternalOrder[][] externalOrders){
    return GeneralizedElevatorState(
        state.floor,
        state.dirn,
        state.moving,

        externalOrders
        .map!(ordersAtFloor =>
            ordersAtFloor
            .map!(order =>
                order.status == ExternalOrder.Status.active  &&
                order.assigned == id
            )
            .array
        )
        .zip(state.internalOrders)
        .map!(a => a[0] ~ a[1])
        .array,

        id
    );
}

GeneralizedElevatorState[] generalize(ElevatorState[ID] states, ExternalOrder[][] externalOrders){
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
                a.id
            )
        )
        .array;
}

ElevatorState uninitializedElevatorState(int numFloors){
    return ElevatorState(
        -1,
        MotorDirection.STOP,
        false,
        new bool[](numFloors)
    );
}


int numFloors(Elevator e){
    return e.maxFloor - e.minFloor + 1;
}


string ack(int floor, ButtonType btn){
    return "ack" ~ floor.to!string ~ btn.to!string;
}





