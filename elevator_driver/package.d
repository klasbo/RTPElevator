module  elevator_driver;

import  std.array,
        std.algorithm,
        std.conv,
        std.concurrency,
        std.file,
        std.getopt,
        std.stdio,
        core.thread;

public import   elevator_driver.i_elevator,
                elevator_driver.comedi_elevator,
                elevator_driver.simulation_elevator;


public {
    Tid elevatorEvents_start(Elevator elevator){
        Tid t = spawnLinked( &elevatorEventsGenerator, cast(shared)elevator );
        receive((initDone id){});
        return t;
    }

    struct btnPressEvent {
        ButtonType  btn;
        int         floor;
    }
    struct stopBtnEvent {}
    struct obstrSwitchEvent {
        bool        active;
        alias active this;
    }
    struct floorArrivalEvent {
        int         floor;
        invariant() {
            assert(floor >= 0, "floorArrivalEvent floor must be positive");
        }
        alias floor this;
    }
}

shared static this(){
    string[] configContents;
    try {
        configContents = readText("ElevatorConfig.con").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "elevatorDriver_pollRate_ms",    &pollRate_ms
        );
    } catch(Exception e){
        writeln("Unable to load elevatorDriver config: ", e.msg);
    }
}

private {
    shared uint pollRate_ms = 10;

    void elevatorEventsGenerator(shared Elevator e){
        Elevator elev = cast(Elevator)e;

        auto buttonsArr     = new bool[][](3,4);
        bool stopBtn; 
        bool obstrSwitch;
        int  currFloor      = -1;
        auto pollRate       = pollRate_ms.msecs;

        ownerTid.send(initDone());
        while(true){
            Thread.sleep(pollRate);
            
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
                ownerTid.send(floorArrivalEvent(currFloor));
            }
        }
    }

    struct initDone{}

}
























