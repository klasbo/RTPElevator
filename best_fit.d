import  std.stdio,
        std.algorithm,
        std.range,
        std.math,
        std.conv;
        
import  types,
        elevator_driver;

private {
    struct Button {
        int         floor;
        ButtonType  btn;
    }
    immutable travelTime = 4;
    immutable doorOpenTime = 3;
}

ubyte bestFit(GeneralizedElevatorState[] states, int floor = -1, ButtonType btn = ButtonType.COMMAND){
    return
    states
    .map!(a => a, a => a.
        //// Insert cost function here
        timeUntil(Button(floor, btn))
    )
    .array
    .sort!((a,b) => a[1] < b[1])
    .front[0]
    .ID;
}


int timeUntil(ref GeneralizedElevatorState s, Button b){

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
        timeInDir += (s.floor - floorOfOnlyOrder).abs * travelTime;        
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
        timeInDir += (floorOfTopOrder - s.floor) * travelTime;
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
        timeInDir += (s.floor - floorOfBottomOrder) * travelTime;
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
        return timeInDir + s.timeUntil(b);
    }
}