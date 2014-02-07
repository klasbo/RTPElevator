module  elevator_driver;

import  std.stdio,
        std.algorithm,
        std.conv,
        std.concurrency,
        core.thread;

public import   elevator_driver.i_elevator,
                elevator_driver.comedi_elevator,
                elevator_driver.simulation_elevator;


import  types;





Tid elevator_events_start(Elevator elevator){
    Tid t = spawnLinked( &elevator_eventsGenerator, cast(shared)elevator );
    receiveOnly!initDone;
    return t;
}

private void elevator_eventsGenerator(shared Elevator e){
    Elevator elev = cast(Elevator)e;

    auto buttonsArr = new bool[][](3,4);
    bool stopBtn; 
    bool obstrSwitch;
    int  currFloor;

    ownerTid.send(initDone());
    while(true){
        Thread.sleep(10.msecs);
        
        for(auto btn = ButtonType.min; btn <= ButtonType.max; btn++){
            foreach(floor; elev.minFloor..elev.maxFloor+1){
                if( (btn == ButtonType.DOWN   && floor == 0)  ||
                    (btn == ButtonType.UP     && floor == elev.maxFloor) )
                {
                    continue;
                }
                
                if( buttonsArr[btn][floor] != (buttonsArr[btn][floor] = elev.ReadButton(floor, btn).to!bool)  &&
                    buttonsArr[btn][floor] == true)
                {
                    debug(elevator_driver) writeln("The ", btn, " button was pressed on floor ", floor);
                    ownerTid.send(btnPressEvent(btn, floor));
                }
            }
        }
        
        
        if(stopBtn != (stopBtn = elev.ReadStopButton.to!bool) && stopBtn == true){
            debug(elevator_driver) writeln("STOP button pressed");
            ownerTid.send(stopBtnEvent());
        }
        
        if(obstrSwitch != (obstrSwitch = elev.ReadObstruction.to!bool)){
            debug(elevator_driver) obstrSwitch ? writeln("Obstruction on") : writeln("Obstruction off");
            ownerTid.send(obstrSwitchEvent(obstrSwitch));
        }

        if(currFloor != (currFloor = elev.ReadFloorSensor)  &&  currFloor != -1){
            elev.SetLight(currFloor, Light.FLOOR_INDICATOR);
            debug(elevator_driver) writeln("Arrived at floor ", currFloor);
            ownerTid.send(newFloorEvent(currFloor));
        }
    }


}


























