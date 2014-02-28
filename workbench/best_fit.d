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
    int         prevFloor;
    Dir         dir;
	bool 		moving;
    bool[][]    btnarr;
}

enum int travelTime = 4;
enum int doorOpenTime = 3;

void main(){

    State[] states;
    states ~= State(0, Dir.IDLE,	false,  [[false, false, false], [false, false, false], [false, false, false], [false, false, false]]);
    states ~= State(0, Dir.UP  ,    false,	[[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]]);
    states ~= State(2, Dir.DOWN,    false, 	[[true , false, false], [false, false, false], [false, true , false], [false, false, false]]);
    states ~= State(1, Dir.IDLE,    false, 	[[false, false, false], [false, false, false], [false, true , false], [false, false, false]]);
    states ~= State(0, Dir.UP  ,    false, 	[[false, false, true ], [true , false, false], [false, false, true ], [false, false, false]]);
    states ~= State(3, Dir.IDLE,    false, 	[[false, false, false], [true , false, false], [false, false, false], [false, false, false]]);
	states ~= State(2, Dir.DOWN,    true, 	[[true,  false, false], [false, false, false], [false, true , false], [false, false, false]]);




    writeln("Calculated completion times: ", states.map!completionTime.array);

    writeln("Expected completion times:   ",
    [
        0,
        doorOpenTime*6 + travelTime*5,
        doorOpenTime*2 + travelTime*2,
        travelTime + doorOpenTime,
        doorOpenTime*3 + travelTime*2,
        travelTime*2 + doorOpenTime,
		travelTime*4 + doorOpenTime*2
    ]);



}

enum ButtonType : int {
    UP=0,
    DOWN=1,
    COMMAND=2
}

int completionTime(State s){
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

	writeln("Prev floor: ", s.prevFloor, ", moving:", s.moving);
	
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
		tmp = s.btnarr[s.prevFloor..$]  .map!(a => a[ButtonType.DOWN]).countUntil(true);
		floorOfClosestDownwardOrderAbove = (tmp == -1 ? -1 : s.prevFloor + tmp);
	} else {
		tmp = s.btnarr[s.prevFloor+1..$].map!(a => a[ButtonType.DOWN]).countUntil(true);
		floorOfClosestDownwardOrderAbove = (tmp == -1 ? -1 : s.prevFloor + 1 + tmp);
	}
    writeln("floorOfClosestDownwardOrderAbove: ", floorOfClosestDownwardOrderAbove);

	int floorOfClosestUpwardOrderBelow;
	if(s.dir == Dir.UP  &&  s.moving){
		tmp = s.btnarr[0..s.prevFloor+1].map!(a => a[ButtonType.UP]).retro.countUntil(true);
		floorOfClosestUpwardOrderBelow = (tmp == -1 ? -1 : s.prevFloor - tmp);
	} else {
		tmp = s.btnarr[0..s.prevFloor]  .map!(a => a[ButtonType.UP]).retro.countUntil(true);
		floorOfClosestUpwardOrderBelow = (tmp == -1 ? -1 : s.prevFloor - 1 - tmp);
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
		completionTime += (s.prevFloor - floorOfBottomOrder) * travelTime;
		if(floorOfTopOrder > s.prevFloor  ||  (s.moving && floorOfTopOrder >= s.prevFloor) ){
			completionTime += (floorOfTopOrder - floorOfBottomOrder) * travelTime;
			completionTime += (floorOfTopOrder - floorOfClosestDownwardOrderAbove) * travelTime;
		} else {
			if(floorOfClosestUpwardOrderBelow != -1){
				completionTime += (floorOfClosestUpwardOrderBelow - floorOfBottomOrder) * travelTime;
			}
		}
	}
	if(s.dir == Dir.UP){
		completionTime += (floorOfTopOrder - s.prevFloor) * travelTime;
		if(s.prevFloor > floorOfBottomOrder  ||  (s.moving && s.prevFloor >= floorOfBottomOrder)){
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
		completionTime += (s.prevFloor - floorOfBottomOrder).abs * travelTime;
	}
	
    return completionTime;
}


























