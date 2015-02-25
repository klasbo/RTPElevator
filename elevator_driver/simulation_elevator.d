module elevator_driver.simulation_elevator;


import  core.thread,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.file,
        std.getopt,
        std.process,
        std.socket,
        std.stdio,
        std.string;

public import  elevator_driver.i_elevator;

import util.timer_event;



class SimulationElevator : Elevator
{
public:
    this(RandomStart rs){
        simulationLoop_thread = spawn( &thr_simulationLoop );
        buttons = new shared bool[][](4, 3);
        lights  = new shared bool[][](4, 3);
        final switch(rs) with(RandomStart){
        case yes:
            import std.random;
            prevFloor = uniform(minFloor, maxFloor);
            currFloor = dice(80,20) ? -1 : prevFloor;
            if(currFloor == -1  &&  prevFloor == minFloor){
                departDir = MotorDirection.UP;
            } else if(currFloor == -1  &&  prevFloor == maxFloor){
                departDir = MotorDirection.DOWN;
            } else {
                departDir = dice(50,50) ? MotorDirection.DOWN : MotorDirection.UP;
            }
            currDir = MotorDirection.STOP;
            break;
        case no:
            departDir   = MotorDirection.STOP;
            currDir     = MotorDirection.STOP;
            break;
        }
    }

    this(){
        this(RandomStart.no);
    }

    int ReadButton(int floor, ButtonType b){
        if(floor < minFloor  ||  floor > maxFloor){
            assert(0, "ReadButton floor is out of bounds: floor = " ~ floor.to!string);
        }
        if (b == ButtonType.DOWN  &&  floor == 0){ return -1; }
        if (b == ButtonType.UP    &&  floor == 3){ return -1; }
        return buttons[floor][b];
    }

    int ReadFloorSensor(){
        return currFloor;
    }

    int ReadStopButton(){
        return (stopBtn ? 1 : 0);
    }

    int ReadObstruction(){
        return (obstrSwch ? 1 : 0);
    }

    void SetLight(int floor, Light l, bool enable){
        if (l == Light.UP || l == Light.DOWN || l == Light.COMMAND){
            lights[floor][l] = enable;
        } else {
            throw new Exception("Invalid argument. Use a floor-dependent light. Got " ~ to!(string)(l));
        }
        simulationLoop_thread.send(StateUpdated());
    }

    void SetLight(int floor, Light l){
        if (l == Light.FLOOR_INDICATOR){
            flrIndLight = floor;
        } else {
            throw new Exception("Invalid argument. Use a floor-dependent light. Got " ~ to!(string)(l));
        }
        simulationLoop_thread.send(StateUpdated());
    }

    void SetLight(Light l, bool enable){
        switch(l){
            case Light.STOP:
                stpBtnLight = enable;
                break;
            case Light.DOOR_OPEN:
                doorLight = enable;
                break;
            default:
                throw new Exception("Invalid argument. Use a floor-invariant light. Got " ~ to!(string)(l));
        }
        simulationLoop_thread.send(StateUpdated());
    }

    void ResetLights(){
        foreach(l; lights){
            fill(cast(bool[])l, false);
        }
        doorLight   = false;
        stpBtnLight = false;
        flrIndLight = 0;

        simulationLoop_thread.send(StateUpdated());
    }

    void SetMotorDirection(MotorDirection m){
        if(m != currDir){
            simulationLoop_thread.send(m);
        }
    }

    @property int minFloor() const { return 0; }
    @property int maxFloor() const { return 3; }


private:
    Tid simulationLoop_thread;
}



enum RandomStart {
    yes,
    no
}


shared static this(){
    string[] configContents;
    try {
        configContents = readText("ElevatorConfig.con").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "simulationElevator_travelTimeBetweenFloors_ms",    &travelTimeBetweenFloors_ms,
            "simulationElevator_travelTimePassingFloor_ms",     &travelTimePassingFloor_ms,
            "simulationElevator_btnDepressedTime_ms",           &btnDepressedTime_ms,
            "simulationElevator_comPortToDisplay",              &comPortToDisplay,
            "simulationElevator_comPortFromDisplay",            &comPortFromDisplay,
        );
    } catch(Exception e){
        writeln("Unable to load simulationElevator config: ", e.msg);
    }
}

private {

// Threads
Tid                     simulationLoop_thread;
Tid                     timerEvent_thread;
Tid                     controlPanelInput_thread;

// Position and direction
shared int              currFloor;
shared int              prevFloor;
shared MotorDirection   currDir;
shared MotorDirection   departDir;
__gshared string        moveEvent;

shared int              ioDir;
shared int              motorAnalogVal;

// Buttons & switches
shared bool[][]         buttons;
shared bool             stopBtn;
shared bool             obstrSwch;

// Lights
shared bool[][]         lights;
shared int              flrIndLight;
shared bool             stpBtnLight;
shared bool             doorLight;

// Printing
int                     printCount;
InternetAddress         addr;
Socket                  sock;

// Config
__gshared uint          travelTimeBetweenFloors_ms  = 1500;
Duration                travelTimeBetweenFloors;
__gshared uint          travelTimePassingFloor_ms   = 650;
Duration                travelTimePassingFloor;
__gshared uint          btnDepressedTime_ms         = 200;
Duration                btnDepressedTime;
__gshared ushort        comPortToDisplay            = 40000;
__gshared ushort        comPortFromDisplay          = 40001;

immutable int           minFloor        = 0;
immutable int           maxFloor        = 3;



void thr_simulationLoop(){
    scope(failure){
        writeln(__FUNCTION__, " died");
        writeln("Debug info:\ndepartDir=", departDir, "\ncurrDir=", currDir,
                "\nprevFloor=", prevFloor, "\ncurrFloor=", currFloor);
    }
    try {

    // --- INIT --- //


    timerEvent_thread           = spawn( &timerEvent_thr );
    controlPanelInput_thread    = spawn( &thr_controlPanelInput );

    travelTimeBetweenFloors     = travelTimeBetweenFloors_ms.msecs;
    travelTimePassingFloor      = travelTimePassingFloor_ms.msecs;
    btnDepressedTime            = btnDepressedTime_ms.msecs;
    addr                        = new InternetAddress("localhost", comPortToDisplay);
    sock                        = new UdpSocket();
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);



    // --- LOOP --- //
    printState;
    while(1){
        receive(
            (MotorDirection m){
                /+
                writeln("received MotorDirChange:",
                    "\n  m=", m,
                    "\n  departDir=", departDir, " currDir=", currDir,
                    "\n  prevFloor=", prevFloor, " currFloor=", currFloor);
                +/                
                
                if(m != currDir){
                    timerEvent_thread.send(thisTid, moveEvent, CancelEvent());
                    currDir = m;
                    
                    final switch(currDir) with(MotorDirection){
                    case UP:
                        if(currFloor != -1){
                            moveEvent = "dep"~currFloor.to!string;
                            timerEvent_thread.send(thisTid, moveEvent, travelTimePassingFloor);
                            departDir = UP;
                        } else {
                            if(departDir == MotorDirection.UP){
                                moveEvent = "arr"~(prevFloor+1).to!string;
                                timerEvent_thread.send(thisTid, moveEvent, travelTimeBetweenFloors);
                            }
                            if(departDir == MotorDirection.DOWN){
                                moveEvent = "arr"~(prevFloor).to!string;
                                timerEvent_thread.send(thisTid, moveEvent, travelTimeBetweenFloors);
                            }
                        }
                        break;
                    case DOWN:
                        if(currFloor != -1){
                            moveEvent = "dep"~currFloor.to!string;
                            timerEvent_thread.send(thisTid, moveEvent, travelTimePassingFloor);
                            departDir = DOWN;
                        } else {
                            if(departDir == MotorDirection.UP){
                                moveEvent = "arr"~(prevFloor).to!string;
                                timerEvent_thread.send(thisTid, moveEvent, travelTimeBetweenFloors);
                            }
                            if(departDir == MotorDirection.DOWN){
                                moveEvent = "arr"~(prevFloor-1).to!string;
                                timerEvent_thread.send(thisTid, moveEvent, travelTimeBetweenFloors);
                            }
                        }
                        break;
                    case STOP:
                        break;
                    }
                }
            },
            (Tid t, string s){
                if(t == timerEvent_thread){
                    handleTimerEvent(s);
                }
            },
            (immutable(ubyte)[] b){
                handleStdinEvent(b[0].to!char);
            },
            (StateUpdated su){
            },
            (OwnerTerminated ot){
                return;
            }
        );
        printState;
    }
    } catch(Throwable t){ t.writeln; throw t; }
}



void handleTimerEvent(string s){
    switch(s[0..3]){
        case "arr":
            if(currDir != MotorDirection.STOP){
                if(s[3] == '-'  || s[3] == '4'){
                    throw new ElevatorCrash("\nELEVATOR HAS CRASHED: \"Arrived\" at a non-existent floor\n");
                }
                if(currDir == MotorDirection.UP    &&  (s[3]-'0').to!int < prevFloor){ return; }
                if(currDir == MotorDirection.DOWN  &&  (s[3]-'0').to!int > prevFloor){ return; }
                currFloor = prevFloor = (s[3]-'0').to!int;
                moveEvent = "dep"~currFloor.to!string;
                timerEvent_thread.send(thisTid, moveEvent, travelTimePassingFloor);
                return;
            } else {
                // ignore, elevator stopped before it reached the floor
            }
            return;

        case "dep":
            final switch(currDir) with(MotorDirection){
            case UP:
                if(s[3] == '3'){
                    throw new ElevatorCrash("\nELEVATOR HAS CRASHED: Departed top floor going upward\n");
                }
                currFloor = -1;
                moveEvent = "arr"~(prevFloor+1).to!string;
                timerEvent_thread.send(thisTid, moveEvent, travelTimeBetweenFloors);
                departDir = UP;
                return;
            case DOWN:
                if(s[3] == '0'){
                    throw new ElevatorCrash("\nELEVATOR HAS CRASHED: Departed bottom floor going downward\n");
                }
                currFloor = -1;
                moveEvent = "arr"~(prevFloor-1).to!string;
                timerEvent_thread.send(thisTid, moveEvent, travelTimeBetweenFloors);
                departDir = DOWN;
                return;
            case STOP:
                return;
            }

        case "btn":
            switch(s[3]){
                case 'u': buttons[(s[4]-'0').to!int][0] = false; return;
                case 'd': buttons[(s[4]-'0').to!int][1] = false; return;
                case 'c': buttons[(s[4]-'0').to!int][2] = false; return;
                default: writeln("Bad timer event received: unable to parse \"", s, "\""); return;
            }

        case "stp":
            stopBtn = false;
            return;

        default:
            writeln("Bad timer event received: unable to parse \"", s, "\"");
            return;
    }
}


void handleStdinEvent(char c){
    switch(c){
        case 'q': // 0 up
            buttons[0][ButtonType.UP] = true;
            timerEvent_thread.send(thisTid, "btnu0", btnDepressedTime);
            break;
        case 'w': // 1 up
            buttons[1][ButtonType.UP] = true;
            timerEvent_thread.send(thisTid, "btnu1", btnDepressedTime);
            break;
        case 'e': // 2 up
            buttons[2][ButtonType.UP] = true;
            timerEvent_thread.send(thisTid, "btnu2", btnDepressedTime);
            break;
        case 's': // 1 dn
            buttons[1][ButtonType.DOWN] = true;
            timerEvent_thread.send(thisTid, "btnd1", btnDepressedTime);
            break;
        case 'd': // 2 dn
            buttons[2][ButtonType.DOWN] = true;
            timerEvent_thread.send(thisTid, "btnd2", btnDepressedTime);
            break;
        case 'f': // 3 dn
            buttons[3][ButtonType.DOWN] = true;
            timerEvent_thread.send(thisTid, "btnd3", btnDepressedTime);
            break;
        case 'z': // 0 cm
            buttons[0][ButtonType.COMMAND] = true;
            timerEvent_thread.send(thisTid, "btnc0", btnDepressedTime);
            break;
        case 'x': // 1 cm
            buttons[1][ButtonType.COMMAND] = true;
            timerEvent_thread.send(thisTid, "btnc1", btnDepressedTime);
            break;
        case 'c': // 2 cm
            buttons[2][ButtonType.COMMAND] = true;
            timerEvent_thread.send(thisTid, "btnc2", btnDepressedTime);
            break;
        case 'v': // 3 cm
            buttons[3][ButtonType.COMMAND] = true;
            timerEvent_thread.send(thisTid, "btnc3", btnDepressedTime);
            break;
        case 't': // stop
            stopBtn = true;
            timerEvent_thread.send(thisTid, "stp", btnDepressedTime);
            break;
        case 'g': // obst
            obstrSwch = !obstrSwch;
            break;
        default: break;
    }
}



void thr_controlPanelInput(){
    scope(exit){ writeln(__FUNCTION__, " died"); }

    ubyte[1] buf;
    auto    addr    = new InternetAddress("localhost", comPortFromDisplay);
    auto    sock    = new UdpSocket();

    sock.bind(addr);

    while(sock.receive(buf) > 0){
        ownerTid.send(buf.idup);
    }
}



void printState(){

    char[][] bg = [
        "+---------------+ +----+--------------+---------+",
        "|               | |  up| 0  1  2      | obstr:  |",
        "| 0 - 1 - 2 - 3 | |down|    1  2  3   | door:   |",
        "|       -       | | cmd| 0  1  2  3   | stop:   |",
        "+---------------+ +----+--------------+---------+" ].to!(char[][]);

/+
    writeln("debug printState:",
        " departDir=", departDir,
        " currDir=", currDir,
        " prevFloor=", prevFloor,
        " currFloor=", currFloor);
+/


    // Elevator position
    if(currFloor != -1){
        bg[1][2+currFloor*4] = '#';
    } else {
        if(departDir == MotorDirection.UP){
            bg[1][4+prevFloor*4] = '#';
        }
        if(departDir == MotorDirection.DOWN){
            bg[1][0+prevFloor*4] = '#';
        }
    }

    // Elevator Direction
    if(currDir == MotorDirection.DOWN){
        bg[3][7]  = '<';
    }
    if(currDir == MotorDirection.UP){
        bg[3][9]  = '>';
    }

    // Button lights
    foreach(floor, lightsAtFloor; lights){ //0..3
        foreach(light, on; lightsAtFloor){  //0..2
            if(on){
                bg[light+1][26+floor*3] = '*';
            }
        }
    }
    // Other lights
    bg[2][3+flrIndLight*4] = '*';
    bg[1][46] = obstrSwch ? 'v' : '^';
    if(doorLight){
        bg[2][46] = '*';
    }
    if(stpBtnLight){
        bg[3][46] = '*';
    }

    auto c = printCount++.to!(char[]);
    bg[4][48-c.length..48] = c[0..$];

    sock.sendTo(bg.reduce!((a, b) => a ~ "\n" ~ b), addr);

}


class ElevatorCrash : Exception {
    this(string msg){
        super(msg);
    }
}

struct StateUpdated {}


}

