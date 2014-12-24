import  std.stdio,
        std.algorithm,
        std.range,
        std.math,
        std.conv;


enum MotorDirection {
    UP,
    DOWN,
    IDLE
}
enum ButtonType : int {
    UP=0,
    DOWN=1,
    COMMAND=2
}

struct State {
    int             floor;
    MotorDirection  dirn;
    bool            moving;
    bool[][]        orders;
    int             ID;
    /+this(this){
        orders = orders.map!(a => a.dup).array.dup;
    }+/
}
struct Button {
    int         floor;
    ButtonType  dirn;
}

enum int travelTimeEstimate = 4;
enum int doorOpenTime = 3;

immutable allDone = Button(-1, ButtonType.COMMAND);

unittest {

    State[] states;
    states ~= State(0, MotorDirection.IDLE, false,  [[false, false, false], [false, false, false], [false, false, false], [false, false, false]], 4);
    states ~= State(0, MotorDirection.UP  , false,  [[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]], 5);
    states ~= State(3, MotorDirection.DOWN, false,  [[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]], 900);
    states ~= State(2, MotorDirection.DOWN, false,  [[true , false, false], [false, false, false], [false, true , false], [false, false, false]], 910);
    states ~= State(1, MotorDirection.IDLE, false,  [[false, false, false], [false, false, false], [false, true , false], [false, false, false]], 2);
    states ~= State(0, MotorDirection.UP  , false,  [[false, false, true ], [true , false, false], [false, false, true ], [false, false, false]], 6);
    states ~= State(3, MotorDirection.IDLE, false,  [[false, false, false], [true , false, false], [false, false, false], [false, false, false]], 3);
    states ~= State(2, MotorDirection.DOWN, true,   [[true , false, false], [false, false, false], [false, true , false], [false, false, false]], 7);
    states ~= State(2, MotorDirection.DOWN, true,   [[false, false, true ], [false, false, false], [false, true , false], [false, false, false]], 100);
    states ~= State(2, MotorDirection.DOWN, false,  [[false, false, true ], [false, false, false], [false, true , false], [false, false, false]], 101);
    states ~= State(1, MotorDirection.UP,   true,   [[false, false, true ], [false, false, false], [false, true , false], [false, false, true ]], 11);
    states ~= State(2, MotorDirection.UP,   true,   [[true , false, true ], [true , false, false], [false, true , false], [false, false, true ]], 12);
    states ~= State(3, MotorDirection.DOWN, true,   [[true , false, false], [false, false, false], [false, true , false], [false, false, false]], 13);    
    states ~= State(3, MotorDirection.DOWN, true,   [[true , false, false], [false, false, false], [true , false, false], [false, false, false]], 140);
    states ~= State(0, MotorDirection.UP,   true,   [[false, false, false], [false, true , false], [false, false, false], [false, true , false]], 141);    
    states ~= State(3, MotorDirection.DOWN, true,   [[true , false, true ], [false, false, false], [false, false, false], [false, false, false]], 15);
    states ~= State(0, MotorDirection.UP,   true,   [[false, false, false], [false, false, false], [false, true , false], [false, false, true ]], 16);
    states ~= State(3, MotorDirection.DOWN, true,   [[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]], 901);
    states ~= State(0, MotorDirection.UP,   true,   [[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]], 902);
    states ~= State(2, MotorDirection.DOWN, true,   [[true , false, false], [false, false, false], [false, true , false], [false, false, false]], 911);
    states ~= State(1, MotorDirection.UP,   false,  [[false, false, false], [false, false, false], [false, true,  false], [false, false, false]], 200);
    states ~= State(1, MotorDirection.UP,   true,   [[false, false, false], [false, false, false], [false, true,  false], [false, false, false]], 201);
    states ~= State(1, MotorDirection.UP,   true,   [[true , false, false], [false, true , true ], [true , false, false], [false, true , false]], 500);
    states ~= State(0, MotorDirection.DOWN, false,  [[true , false, false], [true , false, false], [false, false, true ], [false, false, false]], 501);
    states ~= State(2, MotorDirection.UP,   true,   [[false, false, false], [true , false, true ], [false, true , true ], [false, true , true ]], 502);
    states ~= State(2, MotorDirection.UP,   true,   [[false, false, true ], [true , true , true ], [false, false, true ], [false, true , false]], 503);
    

    auto order = Button(1, ButtonType.UP);

    auto completionTimeResult = 
        states
        .map!(a => a, a => a.
            //// Insert cost function here
            //timeUntil(allDone)
            //timeUntil(order)
            timeUntilAllDone
        )
        .array;
        
    auto calculatedCompletionTimes =
        completionTimeResult
        .map!(a => a[1])
        .array;
        
    auto expectedCompletionTimes =
        [
            0,
            doorOpenTime*6 + travelTimeEstimate*5,
            doorOpenTime*6 + travelTimeEstimate*5,
            doorOpenTime*2 + travelTimeEstimate*2,
            travelTimeEstimate + doorOpenTime,
            doorOpenTime*3 + travelTimeEstimate*2,
            travelTimeEstimate*2 + doorOpenTime,
            travelTimeEstimate*4 + doorOpenTime*2,
            travelTimeEstimate*4 + doorOpenTime*2,
            travelTimeEstimate*2 + doorOpenTime*2,
            travelTimeEstimate*5 + doorOpenTime*3,
            travelTimeEstimate*5 + doorOpenTime*4,
            travelTimeEstimate*3 + doorOpenTime*2,            
            travelTimeEstimate*5 + doorOpenTime*2,
            travelTimeEstimate*5 + doorOpenTime*2,            
            travelTimeEstimate*3 + doorOpenTime,
            travelTimeEstimate*4 + doorOpenTime*2,
            travelTimeEstimate*6 + doorOpenTime*6,
            travelTimeEstimate*6 + doorOpenTime*6,
            travelTimeEstimate*4 + doorOpenTime*2,
            travelTimeEstimate   + doorOpenTime,
            travelTimeEstimate   + doorOpenTime,
            travelTimeEstimate*5 + doorOpenTime*4,
            travelTimeEstimate*2 + doorOpenTime*3,
            travelTimeEstimate*3 + doorOpenTime*3,
            travelTimeEstimate*5 + doorOpenTime*5,
        ];
        
    auto difference = 
        zip(calculatedCompletionTimes, expectedCompletionTimes)
        .map!(a => a[1].to!int - a[0].to!int)
        .array;
        
    /+
    zip(
        states.map!(to!string),
        completionTimeResult.map!(a => a[0].to!string)
    )
    .map!(a => a[0] ~ "\n" ~ a[1])
    .reduce!((a,b) => a ~ "\n\n" ~ b)
    .writeln;
    +/
    
states.map!(to!string).reduce!((a,b) => a ~ "\n\n" ~ b).writeln;
        
    writeln;
    writefln("Calculated completion times: [%(%4s %)]",     calculatedCompletionTimes);
    writefln("Expected completion times:   [%(%4s %)]",     expectedCompletionTimes);
    writefln("ID:                          [%(%4s %)]",     completionTimeResult.map!(a => a[0].ID).array);
    writefln("Difference:                  [%-(%4s %)]",    difference.map!(a => a==0 ? "" : a.to!string).array);
    
    assert(difference.all!(a => a==0));

    completionTimeResult
    .sort!((a,b) => a[1] < b[1])
    .front[0]
    .ID
    .writeln(" has the lowest cost");

    //completionTimeResult.map!(a => a[0].to!string).reduce!((a,b) => a ~ "\n" ~ b).writeln;
    //states.map!(to!string).reduce!((a,b) => a ~ "\n" ~ b).writeln;
    
}




ulong timeUntilAllDone(State s){
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
        , "  \t", s.ID, "\n"
    );
    +/

    
    return  (numStops * doorOpenTime)
        +   (topDestination - bottomDestination) * travelTimeEstimate
        +   (topDestination - bottomRetroDestination) * travelTimeEstimate
        +   (topRetroDestination - bottomDestination) * travelTimeEstimate
        // Include time from prevFloor (s.floor) to nextFloor when there are no orders at prevFloor: (only happenes when s.moving)
        +   ((s.floor < bottomDestination  ||  s.floor > topDestination) ? travelTimeEstimate : 0)
        ;
}

deprecated int completionTime(State s){
    writeln;

    if(!s.orders.map!any.any){
        writeln("Order table is empty");
        return 0;
    }

    int numButtonPresses = s.orders.map!(a => a.count(true)).reduce!"a+b";
    if(s.dirn == MotorDirection.IDLE  &&  numButtonPresses > 1){
        writeln("dirn == IDLE and more than one order makes no sense");
        return int.max;
    }

    int tmp;

    writeln("Prev floor: ", s.floor, ", moving:", s.moving);

    int floorOfTopOrder = (s.orders.length.to!int - 1 - s.orders.map!any.retro.countUntil(true));
    writeln("floorOfTopOrder: ", floorOfTopOrder);

    int floorOfBottomOrder = s.orders.map!any.countUntil(true);
    writeln("floorOfBottomOrder: ", floorOfBottomOrder);

    tmp = s.orders.map!(a => a[ButtonType.DOWN]).retro.countUntil(true);
    int floorOfTopDownwardOrder = (tmp == -1 ? -1 : s.orders.length.to!int - 1 - tmp);
    writeln("floorOfTopDownwardOrder: ", floorOfTopDownwardOrder);

    int floorOfBottomUpwardOrder = s.orders.map!(a => a[ButtonType.UP]).countUntil(true);
    writeln("floorOfBottomUpwardOrder: ", floorOfBottomUpwardOrder);

    int floorOfClosestDownwardOrderAbove;
    if(s.dirn == MotorDirection.DOWN  &&  s.moving){
        tmp = s.orders[s.floor..$]  .map!(a => a[ButtonType.DOWN]).countUntil(true);
        floorOfClosestDownwardOrderAbove = (tmp == -1 ? -1 : s.floor + tmp);
    } else {
        tmp = s.orders[s.floor+1..$].map!(a => a[ButtonType.DOWN]).countUntil(true);
        floorOfClosestDownwardOrderAbove = (tmp == -1 ? -1 : s.floor + 1 + tmp);
    }
    writeln("floorOfClosestDownwardOrderAbove: ", floorOfClosestDownwardOrderAbove);

    int floorOfClosestUpwardOrderBelow;
    if(s.dirn == MotorDirection.UP  &&  s.moving){
        tmp = s.orders[0..s.floor+1].map!(a => a[ButtonType.UP]).retro.countUntil(true);
        floorOfClosestUpwardOrderBelow = (tmp == -1 ? -1 : s.floor - tmp);
    } else {
        tmp = s.orders[0..s.floor]  .map!(a => a[ButtonType.UP]).retro.countUntil(true);
        floorOfClosestUpwardOrderBelow = (tmp == -1 ? -1 : s.floor - 1 - tmp);
    }
    writeln("floorOfClosestUpwardOrderBelow: ", floorOfClosestUpwardOrderBelow);



    int numStopsUpward          = s.orders.map!(a => a[ButtonType.UP]).count(true);
    int numStopsDownward        = s.orders.map!(a => a[ButtonType.DOWN]).count(true);
    int numStopsCommandUnique   = s.orders.map!(a => a[ButtonType.COMMAND] && !a[ButtonType.DOWN] && !a[ButtonType.UP]).count(true);

    int numStops = numStopsUpward + numStopsDownward + numStopsCommandUnique;
    writeln("numStops: ", numStops);

    int completionTime;

    completionTime += numStops * doorOpenTime;

    if(s.dirn == MotorDirection.DOWN){
        completionTime += (s.floor - floorOfBottomOrder) * travelTimeEstimate;
        if(floorOfTopOrder > s.floor  ||  (s.moving && floorOfTopOrder >= s.floor) ){
            completionTime += (floorOfTopOrder - floorOfBottomOrder) * travelTimeEstimate;
            completionTime += (floorOfTopOrder - floorOfClosestDownwardOrderAbove) * travelTimeEstimate;
        } else {
            if(floorOfClosestUpwardOrderBelow != -1){
                completionTime += (floorOfClosestUpwardOrderBelow - floorOfBottomOrder) * travelTimeEstimate;
            }
        }
    }
    if(s.dirn == MotorDirection.UP){
        completionTime += (floorOfTopOrder - s.floor) * travelTimeEstimate;
        if(s.floor > floorOfBottomOrder  ||  (s.moving && s.floor >= floorOfBottomOrder)){
            completionTime += (floorOfTopOrder - floorOfBottomOrder) * travelTimeEstimate;
            completionTime += (floorOfClosestUpwardOrderBelow - floorOfBottomOrder) * travelTimeEstimate;
        } else {
            if(floorOfClosestDownwardOrderAbove != -1){
                completionTime += (floorOfTopOrder - floorOfClosestDownwardOrderAbove) * travelTimeEstimate;
            }
        }
    }
    if(s.dirn == MotorDirection.IDLE){
        assert(floorOfBottomOrder == floorOfTopOrder, "dirn == IDLE and more than one order makes no sense");
        completionTime += (s.floor - floorOfBottomOrder).abs * travelTimeEstimate;
    }

    return completionTime;
}


deprecated int timeInDir(ref State s){
    int timeInDir;

    if(!s.orders.map!any.any){
        return 0;
    }

    final switch(s.dirn) with(MotorDirection){
    case IDLE:
        int numButtonPresses = s.orders.map!(a => a.count(true)).reduce!"a+b";
        if(s.dirn == MotorDirection.IDLE  &&  numButtonPresses > 1){
            writeln("dirn == IDLE and more than one order makes no sense");
            return int.max;
        }
        int floorOfOnlyOrder = s.orders.map!any.countUntil(true);
        timeInDir += (s.floor - floorOfOnlyOrder).abs * travelTimeEstimate;        
        timeInDir += doorOpenTime;
        
        s.orders[floorOfOnlyOrder][ButtonType.UP] = s.orders[floorOfOnlyOrder][ButtonType.DOWN] = s.orders[floorOfOnlyOrder][ButtonType.COMMAND] = false;
        s.floor = floorOfOnlyOrder;
        break;
    case UP:
        int floorOfTopOrder = (s.orders.length.to!int - 1 - s.orders.map!any.retro.countUntil(true));
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
        int floorOfBottomOrder = s.orders.map!any.countUntil(true);
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
    
    return timeInDir;

}


int timeUntil(ref State s, Button b = allDone){

    int timeInDir;

    if(!s.orders.map!any.any){
        return 0;
    }
    if(b.floor != -1  &&  s.orders[b.floor][b.dirn] == false){
        return 0;
    }
    if(s.floor == b.floor){
        s.orders[b.floor][b.dirn] = false;
        return doorOpenTime;
    }

    final switch(s.dirn) with(MotorDirection){
    case IDLE:
        int numButtonPresses = s.orders.map!(a => a.count(true)).reduce!"a+b";
        if(s.dirn == MotorDirection.IDLE  &&  numButtonPresses > 1){
            writeln("dirn == IDLE and more than one order makes no sense");
            return int.max;
        }
        int floorOfOnlyOrder = s.orders.map!any.countUntil(true);
        timeInDir += (s.floor - floorOfOnlyOrder).abs * travelTimeEstimate;        
        timeInDir += doorOpenTime;
        
        s.orders[floorOfOnlyOrder][ButtonType.UP] = s.orders[floorOfOnlyOrder][ButtonType.DOWN] = s.orders[floorOfOnlyOrder][ButtonType.COMMAND] = false;
        s.floor = floorOfOnlyOrder;
        break;
        
        
    case UP:
        int floorOfTopOrder;
        if(b.floor != -1  &&  b.floor > s.floor  &&  b.dirn == ButtonType.UP){
            floorOfTopOrder = b.floor;
        } else {
            floorOfTopOrder = (s.orders.length.to!int - 1 - s.orders.map!any.retro.countUntil(true));
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
        if(b.floor != -1  &&  b.floor < s.floor  &&  b.dirn == ButtonType.DOWN){
            floorOfBottomOrder = b.floor;
        } else {
            floorOfBottomOrder = s.orders.map!any.countUntil(true);
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
        return timeInDir + s.timeUntil(b);
    }
}




















