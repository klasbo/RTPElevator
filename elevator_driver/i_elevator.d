module  elevator_driver.i_elevator;


enum ButtonType : int {
    UP=0,
    DOWN=1,
    COMMAND=2
}

enum Light : int {
    UP=0,
    DOWN=1,
    COMMAND=2,
    FLOOR_INDICATOR,
    STOP,
    DOOR_OPEN
}

enum MotorDirection {
    UP,
    DOWN,
    STOP
}


interface Elevator {
public:
    int ReadButton(int floor, ButtonType b);
    int ReadFloorSensor();
    int ReadStopButton();
    int ReadObstruction();
    void SetLight(string onoff)(int floor, Light l);
    void SetLight(int floor, Light l);
    void SetLight(string onoff)(Light l);
    void ResetLights();
    void SetMotorDirection(MotorDirection m);
    @property int minFloor() const;
    @property int maxFloor() const;
}



