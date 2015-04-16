module event_loop.orders;

import  std.algorithm,
        std.conv,
        std.file,
        std.getopt,
        std.math,
        std.typecons,
        std.range,
        std.stdio;

import  event_loop.types;

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


bool ordersAbove(GeneralizedElevatorState state){
    return state.orders[state.floor+1..$].map!any.any;
}

bool ordersBelow(GeneralizedElevatorState state){
    return state.orders[0..state.floor].map!any.any;
}

bool isIdle(GeneralizedElevatorState state){
    return !state.moving  &&  state.dirn == MotorDirection.STOP;
}

bool hasOrders(GeneralizedElevatorState state){
    return state.orders.map!any.any;
}


bool shouldStop(GeneralizedElevatorState state){
    final switch(state.dirn) with(MotorDirection){
    case UP:
        return  !state.ordersAbove  ||
                state.floor == state.orders.length  ||
                state.orders[state.floor][ButtonType.UP]  ||
                state.orders[state.floor][ButtonType.COMMAND];
    case DOWN:
        return  !state.ordersBelow  ||
                state.floor == 0  ||
                state.orders[state.floor][ButtonType.DOWN]  ||
                state.orders[state.floor][ButtonType.COMMAND];
    case STOP:
        return  true;
    }
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

/++ Only current algorithm is "time until all orders are done".
        Passing floor and btn does nothing.
+/
ID bestFit(GeneralizedElevatorState[] states, int floor = -1, ButtonType btn = ButtonType.COMMAND){

    static ulong timeUntilAllDone(GeneralizedElevatorState s){
    
        if(s.floor == -1){
            return ulong.max;
        }
    
        auto numStopsUpward          = s.orders.map!(a => a[ButtonType.UP]).count(true);
        auto numStopsDownward        = s.orders.map!(a => a[ButtonType.DOWN]).count(true);
        auto numStopsCommandUnique   = s.orders.map!(a => a[ButtonType.COMMAND] && !a[ButtonType.DOWN] && !a[ButtonType.UP]).count(true);

        auto numStops = numStopsUpward + numStopsDownward + numStopsCommandUnique;
        
        auto nextFloor =
            s.moving
            ?   s.dirn == MotorDirection.UP   ? s.floor + 1 :
                s.dirn == MotorDirection.DOWN ? s.floor - 1 :
                /+ "moving" w/ dirn == STOP +/  s.floor
            : s.floor;
            
        auto topDestination = 
            s.orders[nextFloor..$].map!any.any
            ? s.orders.length - 1 - s.orders.retro.map!any.countUntil(true)
            : nextFloor;
            
        auto bottomDestination =
            s.orders[0..nextFloor].map!any.any
            ? s.orders.map!any.countUntil(true)
            : nextFloor;
                    
        auto topRetroDestination =
            //If moving down from a floor lower than topDestination: 
              (s.dirn == MotorDirection.DOWN  &&  nextFloor < topDestination)
            //  Include initial travel from s.floor to bottomDestination
            ?   s.floor
            //If moving down with upward orders between nextFloor and bottomDestination: 
            : ((s.dirn == MotorDirection.DOWN || s.floor > bottomDestination) &&  s.orders[bottomDestination..nextFloor].map!(a => a[ButtonType.UP]).any)
            //  Include travel from bottomDestination to highest upward order below s.floor
            ?   s.floor - 1 - s.orders[bottomDestination..s.floor].retro.map!(a => a[ButtonType.UP]).countUntil(true)
            //Else, Include no extra retrograde travel
            :   bottomDestination;
            
        auto bottomRetroDestination =
              (s.dirn == MotorDirection.UP  &&  nextFloor > bottomDestination)
            ?   s.floor
            : ((s.dirn == MotorDirection.UP || s.floor < topDestination)  &&  s.orders[nextFloor..topDestination].map!(a => a[ButtonType.DOWN]).any)
            ?   s.floor + s.orders[s.floor..topDestination].map!(a => a[ButtonType.DOWN]).countUntil(true)
            :   topDestination;

        
        
        // if(s.floor < bottomDestination  ||  s.floor > topDestination){
        //     assert(s.moving);
        // }
        
        /+
        writeln(bottomDestination, "-", bottomRetroDestination,
                "  ", s.floor, "(", nextFloor, ")  ",
                topRetroDestination, "-", topDestination
                
            , "  : ",   (topDestination - bottomDestination)
            , " ",      (topDestination - bottomRetroDestination)
            , " ",      (topRetroDestination - bottomDestination)
            , "  \t", s.id, "\n"
        );
        +/

        
        return  (numStops * doorOpenTime)
            +   (topDestination - bottomDestination) * travelTimeEstimate
            +   (topDestination - bottomRetroDestination) * travelTimeEstimate
            +   (topRetroDestination - bottomDestination) * travelTimeEstimate
            // Include time from prevFloor (s.floor) to nextFloor when there are no orders at prevFloor: (only happens when s.moving)
            +   ((s.floor < bottomDestination  ||  s.floor > topDestination) ? travelTimeEstimate : 0)
            ;
    }
    

    return
        states
        .map!( a => tuple(a,  timeUntilAllDone(a)) )
        .array
        .sort!((a,b) => a[1] < b[1])
        .front[0]
        .id;

}