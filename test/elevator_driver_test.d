module  test.elevator_driver_test;

import  std.algorithm,
        std.concurrency,
        std.stdio,
        std.conv;

import  elevator_driver;


void elevator_driver_test(){

    auto elevator = new SimulationElevator;

    auto elevatorDriver = elevatorEvents_start(elevator);

    auto lightsArr = new bool[][](4,3);
    bool stopLight;
    bool doorOpenLight;

    elevator.SetMotorDirection(MotorDirection.UP);

    while(true){
        receive(
            (btnPressEvent bpe){
                writeln("The ", bpe.btn, " button on floor ", bpe.floor, " was pressed");
                lightsArr[bpe.floor][bpe.btn] =! lightsArr[bpe.floor][bpe.btn]
                    ? (elevator.SetLight(bpe.floor, cast(Light)bpe.btn, true), true)
                    : (elevator.SetLight(bpe.floor, cast(Light)bpe.btn, false), false);
            },
            (stopBtnEvent sbe){
                writeln("The STOP button was pressed");
                stopLight =! stopLight
                    ? (elevator.SetLight(Light.STOP, true), true)
                    : (elevator.SetLight(Light.STOP, false), false);
                elevator.SetMotorDirection(MotorDirection.STOP);
            },
            (obstrSwitchEvent obstr){
                writeln("The obstruction is " ~ (obstr ? "active" : "inactive"));
                doorOpenLight =! doorOpenLight
                    ? (elevator.SetLight(Light.DOOR_OPEN, true), true)
                    : (elevator.SetLight(Light.DOOR_OPEN, false), false);
            },
            (floorArrivalEvent newFloor){
                writeln("Arrived at floor ", newFloor);
                if(newFloor == elevator.maxFloor){
                    elevator.SetMotorDirection(MotorDirection.DOWN);
                }
                if(newFloor == elevator.minFloor){
                    elevator.SetMotorDirection(MotorDirection.UP);
                }
            }
        );
    }
}


