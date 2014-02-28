import  std.stdio,
        std.algorithm,
        std.range,
        std.math,
        std.conv;


enum Dir {
    UP,
    DOWN,
    STOP
}

struct State {
    int         prevFloor;
    Dir         dir;
    bool[][]    btnarr;
}

enum int travelTime = 4;
enum int doorOpenTime = 3;

void main(){

    State[] states;
    states ~= State(0, Dir.STOP,    [[false, false, false], [false, false, false], [false, false, false], [false, false, false]]);
    states ~= State(0, Dir.UP  ,    [[true , false, true ], [true , true , true ], [true , true , true ], [false, true , true ]]);
    states ~= State(2, Dir.DOWN,    [[true , false, false], [false, false, false], [false, true , false], [false, false, false]]);
    states ~= State(1, Dir.STOP,    [[false, false, false], [false, false, false], [false, true , false], [false, false, false]]);
    states ~= State(0, Dir.UP  ,    [[false, false, true ], [true , false, false], [false, false, true ], [false, false, false]]);
    states ~= State(3, Dir.STOP,    [[false, false, false], [true , false, false], [false, false, false], [false, false, false]]);




    writeln("Calculated completion times: ", states.map!completionTime.array);

    writeln("Expected completion times:   ",
    [
        0,
        doorOpenTime*6 + travelTime*5,
        doorOpenTime*2 + travelTime*2,
        travelTime + doorOpenTime,
        doorOpenTime*3 + travelTime*3,
        travelTime*2 + doorOpenTime
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

    int tmp;

    int floorOfTopOrder = (s.btnarr.length.to!int - 1 - s.btnarr.map!any.retro.countUntil(true));
    writeln("floorOfTopOrder: ", floorOfTopOrder);

    int floorOfBottomOrder = s.btnarr.map!any.countUntil(true);
    writeln("floorOfBottomOrder: ", floorOfBottomOrder);

    tmp = s.btnarr.map!(a => a[ButtonType.DOWN]).retro.countUntil(true);
    int floorOfTopDownwardOrder = (tmp == -1 ? -1 : s.btnarr.length.to!int - 1 - tmp);
    writeln("floorOfTopDownwardOrder: ", floorOfTopDownwardOrder);

    int floorOfBottomUpwardOrder = s.btnarr.map!(a => a[ButtonType.UP]).countUntil(true);
    writeln("floorOfBottomUpwardOrder: ", floorOfBottomUpwardOrder);


    tmp = s.btnarr[s.prevFloor+1..$].map!(a => a[ButtonType.DOWN]).countUntil(true);
    int floorOfClosestDownwardOrderAbove = (tmp == -1 ? -1 : s.prevFloor + 1 + tmp);
    writeln("floorOfClosestDownwardOrderAbove: ", floorOfClosestDownwardOrderAbove);


    tmp = s.btnarr[0..s.prevFloor].map!(a => a[ButtonType.UP]).retro.countUntil(true);
    int floorOfClosestUpwardOrderBelow = (tmp == -1 ? -1 : s.prevFloor - 1 - tmp);
    writeln("floorOfClosestUpwardOrderBelow: ", floorOfClosestUpwardOrderBelow);



    int numStopsUpward          = s.btnarr.map!(a => a[ButtonType.UP]).count(true);
    int numStopsDownward        = s.btnarr.map!(a => a[ButtonType.DOWN]).count(true);
    int numStopsCommandUnique   = s.btnarr.map!(a => a[ButtonType.COMMAND] && !a[ButtonType.DOWN] && !a[ButtonType.UP]).count(true);

    int numStops = numStopsUpward + numStopsDownward + numStopsCommandUnique;
    writeln("numStops: ", numStops);

/+    
downward:
    s.prevFloor -> floorOfBottomOrder ->
    if floorOfTopOrder > s.prevFloor
        -> floorOfTopOrder -> floorOfClosestDownwardOrderAbove .
    else
        -> floorOfClosestUpwardOrderBelow .
        
stop:
    floorOfOnlyOrder = floorOfTopOrder = floorOfBottomOrder
    s.prevFloor -> floorOfOnlyOrder
    
+/


    return
        numStops * doorOpenTime;



}


























