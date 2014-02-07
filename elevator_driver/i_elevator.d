module  elevator_driver.i_elevator;


public import   types:ButtonType;
public import   types:Light;
public import   types:MotorDirection;


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



