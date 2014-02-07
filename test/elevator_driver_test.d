module  test.elevator_driver_test;

import  std.algorithm,
        std.concurrency,
        std.stdio,
        std.conv;

import  elevator_driver,
        types;


void elevator_driver_test(){

    auto elevator = new ComediElevator;

    auto elevatorDriver = elevator_events_start(elevator);

    auto lightsArr = new bool[][](4,3);
    bool stopLight;
    bool doorOpenLight;

    elevator.SetMotorDirection(MotorDirection.UP);

    while(true){
        receive(
            (btnPressEvent bpe){
                writeln("The ", bpe.btn, " button on floor ", bpe.floor, " was pressed");
                lightsArr[bpe.floor][bpe.btn] =! lightsArr[bpe.floor][bpe.btn]
                    ? (elevator.SetLight!"on"(bpe.floor, cast(Light)bpe.btn), true)
                    : (elevator.SetLight!"off"(bpe.floor, cast(Light)bpe.btn), false);
            },
            (stopBtnEvent sbe){
                writeln("The STOP button was pressed");
                stopLight =! stopLight
                    ? (elevator.SetLight!"on"(Light.STOP), true)
                    : (elevator.SetLight!"off"(Light.STOP), false);
                elevator.SetMotorDirection(MotorDirection.STOP);
            },
            (obstrSwitchEvent ose){
                writeln("The obstruction is " ~ (ose.active ? "active" : "inactive"));
                doorOpenLight =! doorOpenLight
                    ? (elevator.SetLight!"on"(Light.DOOR_OPEN), true)
                    : (elevator.SetLight!"off"(Light.DOOR_OPEN), false);
            },
            (newFloorEvent nfe){
                writeln("Arrived at floor ", nfe.floor);
                if(nfe.floor == elevator.maxFloor){
                    elevator.SetMotorDirection(MotorDirection.DOWN);
                }
                if(nfe.floor == elevator.minFloor){
                    elevator.SetMotorDirection(MotorDirection.UP);
                }
            }
        );
    }
}


