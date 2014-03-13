import  std.stdio,
        std.algorithm,
        std.range,
        std.math,
        std.conv;


enum Dir {
    UP,
    DOWN,
    IDLE
}

struct State {
    int         floor;
    Dir         dir;
	bool 		moving;
    bool[][]    btnarr;
    ubyte       ID;
    this(this){
        btnarr = btnarr.map!(a => a.dup).array.dup;
    }
}
struct Button {
    int         floor;
    ButtonType  dir;
}

enum int travelTime = 4;
enum int doorOpenTime = 3;

immutable allDone = Button(-1, ButtonType.COMMAND);

unittest {

    State[] states;
    states ~= State(0, Dir.IDLE,	false,  [[false, false, false], [false, false, false], [false, false, false], [false, false, false]], 4);
    states ~= State(0, Dir.UP  ,    false,	[[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]], 5);
    states ~= State(3, Dir.DOWN,    false,	[[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]], 9);
    states ~= State(2, Dir.DOWN,    false, 	[[true , false, false], [false, false, false], [false, true , false], [false, false, false]], 1);
    states ~= State(1, Dir.IDLE,    false, 	[[false, false, false], [false, false, false], [false, true , false], [false, false, false]], 2);
    states ~= State(0, Dir.UP  ,    false, 	[[false, false, true ], [true , false, false], [false, false, true ], [false, false, false]], 6);
    states ~= State(3, Dir.IDLE,    false, 	[[false, false, false], [true , false, false], [false, false, false], [false, false, false]], 3);
	states ~= State(2, Dir.DOWN,    true, 	[[true,  false, false], [false, false, false], [false, true , false], [false, false, false]], 7);



    //writeln("Calculated completion times: ", states.map!completionTime.array);
    writeln("Calculated completion times: ", states.map!(a => a.timeUntil(allDone)).array);
    

    writeln("Expected completion times:   ",
    [
        0,
        doorOpenTime*6 + travelTime*5,
        doorOpenTime*6 + travelTime*5,
        doorOpenTime*2 + travelTime*2,
        travelTime + doorOpenTime,
        doorOpenTime*3 + travelTime*2,
        travelTime*2 + doorOpenTime,
		travelTime*4 + doorOpenTime*2
    ]);


    auto order = Button(1, ButtonType.UP);



    states
    .map!(a => a, a => a.
        //// Insert cost function here
        timeUntil(allDone)
        //timeUntil(order)
    )
    .array
    .sort!((a,b) => a[1] < b[1])
    .front[0]
    .ID
    .writeln(" has the lowest cost");

    //states.map!(to!string).reduce!((a,b) => a ~ "\n" ~ b).writeln;

}

enum ButtonType : int {
    UP=0,
    DOWN=1,
    COMMAND=2
}




deprecated int completionTime(State s){
    writeln;

    if(!s.btnarr.map!any.any){
        writeln("Order table is empty");
        return 0;
    }

	int numButtonPresses = s.btnarr.map!(a => a.count(true)).reduce!"a+b";
	if(s.dir == Dir.IDLE  &&  numButtonPresses > 1){
		writeln("dir == IDLE and more than one order makes no sense");
		return int.max;
	}

    int tmp;

	writeln("Prev floor: ", s.floor, ", moving:", s.moving);

    int floorOfTopOrder = (s.btnarr.length.to!int - 1 - s.btnarr.map!any.retro.countUntil(true));
    writeln("floorOfTopOrder: ", floorOfTopOrder);

    int floorOfBottomOrder = s.btnarr.map!any.countUntil(true);
    writeln("floorOfBottomOrder: ", floorOfBottomOrder);

    tmp = s.btnarr.map!(a => a[ButtonType.DOWN]).retro.countUntil(true);
    int floorOfTopDownwardOrder = (tmp == -1 ? -1 : s.btnarr.length.to!int - 1 - tmp);
    writeln("floorOfTopDownwardOrder: ", floorOfTopDownwardOrder);

    int floorOfBottomUpwardOrder = s.btnarr.map!(a => a[ButtonType.UP]).countUntil(true);
    writeln("floorOfBottomUpwardOrder: ", floorOfBottomUpwardOrder);

	int floorOfClosestDownwardOrderAbove;
	if(s.dir == Dir.DOWN  &&  s.moving){
		tmp = s.btnarr[s.floor..$]  .map!(a => a[ButtonType.DOWN]).countUntil(true);
		floorOfClosestDownwardOrderAbove = (tmp == -1 ? -1 : s.floor + tmp);
	} else {
		tmp = s.btnarr[s.floor+1..$].map!(a => a[ButtonType.DOWN]).countUntil(true);
		floorOfClosestDownwardOrderAbove = (tmp == -1 ? -1 : s.floor + 1 + tmp);
	}
    writeln("floorOfClosestDownwardOrderAbove: ", floorOfClosestDownwardOrderAbove);

	int floorOfClosestUpwardOrderBelow;
	if(s.dir == Dir.UP  &&  s.moving){
		tmp = s.btnarr[0..s.floor+1].map!(a => a[ButtonType.UP]).retro.countUntil(true);
		floorOfClosestUpwardOrderBelow = (tmp == -1 ? -1 : s.floor - tmp);
	} else {
		tmp = s.btnarr[0..s.floor]  .map!(a => a[ButtonType.UP]).retro.countUntil(true);
		floorOfClosestUpwardOrderBelow = (tmp == -1 ? -1 : s.floor - 1 - tmp);
	}
    writeln("floorOfClosestUpwardOrderBelow: ", floorOfClosestUpwardOrderBelow);



    int numStopsUpward          = s.btnarr.map!(a => a[ButtonType.UP]).count(true);
    int numStopsDownward        = s.btnarr.map!(a => a[ButtonType.DOWN]).count(true);
    int numStopsCommandUnique   = s.btnarr.map!(a => a[ButtonType.COMMAND] && !a[ButtonType.DOWN] && !a[ButtonType.UP]).count(true);

    int numStops = numStopsUpward + numStopsDownward + numStopsCommandUnique;
    writeln("numStops: ", numStops);

	int completionTime;

	completionTime += numStops * doorOpenTime;

	if(s.dir == Dir.DOWN){
		completionTime += (s.floor - floorOfBottomOrder) * travelTime;
		if(floorOfTopOrder > s.floor  ||  (s.moving && floorOfTopOrder >= s.floor) ){
			completionTime += (floorOfTopOrder - floorOfBottomOrder) * travelTime;
			completionTime += (floorOfTopOrder - floorOfClosestDownwardOrderAbove) * travelTime;
		} else {
			if(floorOfClosestUpwardOrderBelow != -1){
				completionTime += (floorOfClosestUpwardOrderBelow - floorOfBottomOrder) * travelTime;
			}
		}
	}
	if(s.dir == Dir.UP){
		completionTime += (floorOfTopOrder - s.floor) * travelTime;
		if(s.floor > floorOfBottomOrder  ||  (s.moving && s.floor >= floorOfBottomOrder)){
			completionTime += (floorOfTopOrder - floorOfBottomOrder) * travelTime;
			completionTime += (floorOfClosestUpwardOrderBelow - floorOfBottomOrder) * travelTime;
		} else {
			if(floorOfClosestDownwardOrderAbove != -1){
				completionTime += (floorOfTopOrder - floorOfClosestDownwardOrderAbove) * travelTime;
			}
		}
	}
	if(s.dir == Dir.IDLE){
		assert(floorOfBottomOrder == floorOfTopOrder, "dir == IDLE and more than one order makes no sense");
		completionTime += (s.floor - floorOfBottomOrder).abs * travelTime;
	}

    return completionTime;
}


deprecated int timeInDir(ref State s){
    int timeInDir;

    if(!s.btnarr.map!any.any){
        return 0;
    }

    final switch(s.dir) with(Dir){
    case IDLE:
        int numButtonPresses = s.btnarr.map!(a => a.count(true)).reduce!"a+b";
        if(s.dir == Dir.IDLE  &&  numButtonPresses > 1){
            writeln("dir == IDLE and more than one order makes no sense");
            return int.max;
        }
        int floorOfOnlyOrder = s.btnarr.map!any.countUntil(true);
        timeInDir += (s.floor - floorOfOnlyOrder).abs * travelTime;        
        timeInDir += doorOpenTime;
        
        s.btnarr[floorOfOnlyOrder][ButtonType.UP] = s.btnarr[floorOfOnlyOrder][ButtonType.DOWN] = s.btnarr[floorOfOnlyOrder][ButtonType.COMMAND] = false;
        s.floor = floorOfOnlyOrder;
        break;
    case UP:
        int floorOfTopOrder = (s.btnarr.length.to!int - 1 - s.btnarr.map!any.retro.countUntil(true));
        timeInDir += (floorOfTopOrder - s.floor) * travelTime;
        if(s.moving){
            s.floor++;
        }
        foreach(floor; s.floor..floorOfTopOrder){
            if(s.btnarr[floor][ButtonType.COMMAND]  ||  s.btnarr[floor][ButtonType.UP]){
                timeInDir += doorOpenTime;
                s.btnarr[floor][ButtonType.COMMAND] = s.btnarr[floor][ButtonType.UP] = false;
            }
        }
        timeInDir += doorOpenTime;
        
        s.btnarr[floorOfTopOrder][ButtonType.UP] = s.btnarr[floorOfTopOrder][ButtonType.DOWN] = s.btnarr[floorOfTopOrder][ButtonType.COMMAND] = false;        
        s.floor = floorOfTopOrder;
        s.dir = Dir.DOWN;
        s.moving = true;
        break;

    
    case DOWN:
        int floorOfBottomOrder = s.btnarr.map!any.countUntil(true);
        timeInDir += (s.floor - floorOfBottomOrder) * travelTime;
        if(s.moving){
            s.floor--;
        }
        foreach(floor; floorOfBottomOrder+1..s.floor+1){
            if(s.btnarr[floor][ButtonType.COMMAND]  ||  s.btnarr[floor][ButtonType.DOWN]){
                timeInDir += doorOpenTime;
                s.btnarr[floor][ButtonType.COMMAND] = s.btnarr[floor][ButtonType.DOWN] = false;
            }
        }
        timeInDir += doorOpenTime;
        
        s.btnarr[floorOfBottomOrder][ButtonType.UP] = s.btnarr[floorOfBottomOrder][ButtonType.DOWN] = s.btnarr[floorOfBottomOrder][ButtonType.COMMAND] = false;        
        s.floor = floorOfBottomOrder;
        s.dir = Dir.UP;
        s.moving = true;
        break;

    }
    
    return timeInDir;

}


int timeUntil(ref State s, Button b = allDone){

    int timeInDir;

    if(!s.btnarr.map!any.any){
        return 0;
    }
    if(b.floor != -1  &&  s.btnarr[b.floor][b.dir] == false){
        return 0;
    }
    if(s.floor == b.floor){
        s.btnarr[b.floor][b.dir] = false;
        return doorOpenTime;
    }

    final switch(s.dir) with(Dir){
    case IDLE:
        int numButtonPresses = s.btnarr.map!(a => a.count(true)).reduce!"a+b";
        if(s.dir == Dir.IDLE  &&  numButtonPresses > 1){
            writeln("dir == IDLE and more than one order makes no sense");
            return int.max;
        }
        int floorOfOnlyOrder = s.btnarr.map!any.countUntil(true);
        timeInDir += (s.floor - floorOfOnlyOrder).abs * travelTime;        
        timeInDir += doorOpenTime;
        
        s.btnarr[floorOfOnlyOrder][ButtonType.UP] = s.btnarr[floorOfOnlyOrder][ButtonType.DOWN] = s.btnarr[floorOfOnlyOrder][ButtonType.COMMAND] = false;
        s.floor = floorOfOnlyOrder;
        break;
        
        
    case UP:
        int floorOfTopOrder;
        if(b.floor != -1  &&  b.floor > s.floor  &&  b.dir == ButtonType.UP){
            floorOfTopOrder = b.floor;
        } else {
            floorOfTopOrder = (s.btnarr.length.to!int - 1 - s.btnarr.map!any.retro.countUntil(true));
        }
        timeInDir += (floorOfTopOrder - s.floor) * travelTime;
        if(s.moving){
            s.floor++;
        }
        foreach(floor; s.floor..floorOfTopOrder){
            if(s.btnarr[floor][ButtonType.COMMAND]  ||  s.btnarr[floor][ButtonType.UP]){
                timeInDir += doorOpenTime;
                s.btnarr[floor][ButtonType.COMMAND] = s.btnarr[floor][ButtonType.UP] = false;
            }
        }
        timeInDir += doorOpenTime;
        
        s.btnarr[floorOfTopOrder][ButtonType.UP] = s.btnarr[floorOfTopOrder][ButtonType.DOWN] = s.btnarr[floorOfTopOrder][ButtonType.COMMAND] = false;        
        s.floor = floorOfTopOrder;
        s.dir = Dir.DOWN;
        s.moving = true;
        break;

    
    case DOWN:
        int floorOfBottomOrder;
        if(b.floor != -1  &&  b.floor < s.floor  &&  b.dir == ButtonType.DOWN){
            floorOfBottomOrder = b.floor;
        } else {
            floorOfBottomOrder = s.btnarr.map!any.countUntil(true);
        }
        timeInDir += (s.floor - floorOfBottomOrder) * travelTime;
        if(s.moving){
            s.floor--;
        }
        foreach(floor; floorOfBottomOrder+1..s.floor+1){
            if(s.btnarr[floor][ButtonType.COMMAND]  ||  s.btnarr[floor][ButtonType.DOWN]){
                timeInDir += doorOpenTime;
                s.btnarr[floor][ButtonType.COMMAND] = s.btnarr[floor][ButtonType.DOWN] = false;
            }
        }
        timeInDir += doorOpenTime;
        
        s.btnarr[floorOfBottomOrder][ButtonType.UP] = s.btnarr[floorOfBottomOrder][ButtonType.DOWN] = s.btnarr[floorOfBottomOrder][ButtonType.COMMAND] = false;        
        s.floor = floorOfBottomOrder;
        s.dir = Dir.UP;
        s.moving = true;
        break;

    }
    
    if(timeInDir == 0){
        return 0;
    } else {
        return timeInDir + s.timeUntil(b);
    }
}




















