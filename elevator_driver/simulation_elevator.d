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



/**
Visual representation of the elevator appears in a second window.

Use QWE, SDF, ZXCV to control Up, Down, Command buttons.
Use T for Stop button, G for obstruction switch.

Windows: Keys react instantly.
Linux: Press key followed by Enter.
*/
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
            nextFloor = prevFloor;
            if(currFloor == -1  &&  prevFloor == minFloor){
                prevDir = MotorDirection.UP;
            } else if(currFloor == -1  &&  prevFloor == maxFloor){
                prevDir = MotorDirection.DOWN;
            } else {
                prevDir = dice(50,50) ? MotorDirection.DOWN : MotorDirection.UP;
            }
            currDir = MotorDirection.STOP;
            break;
        case no:
            prevDir = MotorDirection.STOP;
            currDir = MotorDirection.STOP;
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
        simulationLoop_thread.send(stateUpdated());
    }

    void SetLight(int floor, Light l){
        if (l == Light.FLOOR_INDICATOR){
            flrIndLight = floor;
        } else {
            throw new Exception("Invalid argument. Use a floor-dependent light. Got " ~ to!(string)(l));
        }
        simulationLoop_thread.send(stateUpdated());
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
        simulationLoop_thread.send(stateUpdated());
    }

    void ResetLights(){
        foreach(l; lights){
            fill(cast(bool[])l, false);
        }
        doorLight   = false;
        stpBtnLight = false;
        flrIndLight = 0;

        simulationLoop_thread.send(stateUpdated());
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
            "simulationElevator_comPort",                       &comPort,
            "OS_linux_terminal",                                &linux_terminal
        );
    } catch(Exception e){
        writeln("Unable to load simulationElevator config: ", e.msg);
    }
}

private {

    // Elevator state
    shared int              currFloor;
    shared int              prevFloor;
    shared int              nextFloor;
    shared MotorDirection   currDir;
    shared MotorDirection   prevDir;

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
    shared uint             travelTimeBetweenFloors_ms  = 1500;
    shared uint             travelTimePassingFloor_ms   = 650;
    shared uint             btnDepressedTime_ms         = 200;
    shared ushort           comPort                     = 40000;
    __gshared string        linux_terminal              = "$TERM";
    Duration                travelTimeBetweenFloors;
    Duration                travelTimePassingFloor;
    Duration                btnDepressedTime;




void thr_simulationLoop(){
    scope(exit){
        writeln(__FUNCTION__, " died");
        writeln("Debug info:\nprevDir=", prevDir, "\ncurrDir=", currDir,
                "\nprevFloor=", prevFloor, "\ncurrFloor=", currFloor,
                "\nnextFloor=", nextFloor);
    }
    try {

    // --- DECLARATIONS --- //

    Tid         timerEvent_thread;
    Tid         controlPanelInput_thread;



    // --- FUNCTIONS --- //

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
                    timerEvent_thread.send(thisTid, "dep"~currFloor.to!string, travelTimePassingFloor);
                    return;
                }
                if(currDir == MotorDirection.STOP){
                    // ignore, elevator stopped before it reached the floor
                }
                return;

            case "dep":
                if(currDir == MotorDirection.UP){
                    if(s[3] == '3'){
                        throw new ElevatorCrash("\nELEVATOR HAS CRASHED: Departed top floor going upward\n");
                    }
                    currFloor = -1;
                    timerEvent_thread.send(thisTid, "arr"~(prevFloor+1).to!string, travelTimeBetweenFloors);
                    nextFloor = prevFloor+1;
                    return;
                }
                if(currDir == MotorDirection.DOWN){
                    if(s[3] == '0'){
                        throw new ElevatorCrash("\nELEVATOR HAS CRASHED: Departed bottom floor going downward\n");
                    }
                    currFloor = -1;
                    timerEvent_thread.send(thisTid, "arr"~(prevFloor-1).to!string, travelTimeBetweenFloors);
                    nextFloor = prevFloor-1;
                    return;
                }
                return;

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
                obstrSwch ? (obstrSwch = false) : (obstrSwch = true);
                break;
            default: break;
        }
    }




    // --- INIT --- //


    timerEvent_thread           = spawn( &timerEvent_thr );
    controlPanelInput_thread    = spawn( &thr_controlPanelInput );

    travelTimeBetweenFloors     = travelTimeBetweenFloors_ms.msecs;
    travelTimePassingFloor      = travelTimePassingFloor_ms.msecs;
    btnDepressedTime            = btnDepressedTime_ms.msecs;
    addr                        = new InternetAddress("localhost", comPort);
    sock                        = new UdpSocket();
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);


    // Create and spawn second window
    string path = thisExePath[0..thisExePath.lastIndexOf("\\")+1];
    std.file.write(path~"secondWindow.d", secondWindowProgram);
    version(Windows){
        std.process.spawnShell(("start \"\" rdmd -w -g \"" ~ path ~ "secondWindow.d\""));
    } else version(linux){
        std.process.spawnShell((linux_terminal ~ " -x rdmd -w -g \"" ~ path ~ "secondWindow.d\""));
    }
    Thread.sleep(1.seconds);
    std.file.remove(path~"secondWindow.d");


    // --- LOOP --- //
    printState;
    while(1){
        receive(
            (MotorDirection m){
                // writeln("received MotorDirChange: prevDir=", prevDir, " currDir=", currDir,
                //                                 " prevFloor=", prevFloor, " currFloor=", currFloor,
                //                                 " m=", m);
                currDir = m;
                final switch(currDir) with(MotorDirection){
                case UP:
                    if(currFloor != -1){
                        timerEvent_thread.send(thisTid, "dep"~currFloor.to!string, travelTimePassingFloor);
                    } else {
                        if(prevDir == MotorDirection.UP){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor+1).to!string, travelTimeBetweenFloors);
                            nextFloor = prevFloor+1;
                        }
                        if(prevDir == MotorDirection.DOWN){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor).to!string, travelTimeBetweenFloors);
                        }
                    }
                    prevDir = currDir;
                    break;
                case DOWN:
                    if(currFloor != -1){
                        timerEvent_thread.send(thisTid, "dep"~currFloor.to!string, travelTimePassingFloor);
                    } else {
                        if(prevDir == MotorDirection.UP){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor).to!string, travelTimeBetweenFloors);
                        }
                        if(prevDir == MotorDirection.DOWN){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor-1).to!string, travelTimeBetweenFloors);
                            nextFloor = prevFloor-1;
                        }
                    }
                    prevDir = currDir;
                    break;
                case STOP:
                    break;
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
            (stateUpdated su){
            }
        );
        printState;
    }
    } catch(Exception e){ e.writeln; throw e; }
}

void thr_controlPanelInput(){
    scope(exit){ writeln(__FUNCTION__, " died"); }

    writeln("elevator control started");

    version(Windows){
        import core.sys.windows.windows;
        SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), ENABLE_PROCESSED_INPUT);
    }
    while(1){
        foreach(ubyte[] buf; stdin.byChunk(1)){
            ownerTid.send(buf.idup);
            version(Windows){
                SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), ENABLE_PROCESSED_INPUT);
            }
        }
    }
}

void printState(){

    string fmt = "%-(%s\n%)";


    char[][] bg = [
        "+---------------+ +-+---------------+----+",
        "|               | |u|  0  1  2      | o  |",
        "| 0 - 1 - 2 - 3 | |d|     1  2  3   | d  |",
        "|       -       | |c|  0  1  2  3   | s  |",
        "+---------------+ +-+---------------+----+" ].to!(char[][]);


    // Elevator position
    if(currFloor != -1){
        bg[1][2+currFloor*4] = '#';
    } else {
//        writeln("debug printState: prevDir=", prevDir,
//                                " currDir=", currDir,
//                                " prevFloor=", prevFloor,
//                                " currFloor=", currFloor,
//                                " nextFloor=", nextFloor);

        if(nextFloor > prevFloor){
            bg[1][4+prevFloor*4] = '#';
        }
        if(nextFloor < prevFloor){
            bg[1][0+prevFloor*4] = '#';
        }
        if(nextFloor == prevFloor){
            if(prevDir == MotorDirection.UP){
                bg[1][4+prevFloor*4] = '#';
            }
            if(prevDir == MotorDirection.DOWN){
                bg[1][0+prevFloor*4] = '#';
            }
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
    foreach(i, a; lights){ //0..3
        foreach(j, b; a){  //0..2
            if(b){
                bg[j+1][24+i*3] = '*';
            }
        }
    }
    // Other lights
    bg[2][3+flrIndLight*4] = '*';
    if(obstrSwch){
        bg[1][39] = '^';
    }
    if(doorLight){
        bg[2][39] = '*';
    }
    if(stpBtnLight){
        bg[3][39] = '*';
    }

    auto c = printCount++.to!(char[]);
    bg[4][41-c.length..41] = c[0..$];

    sock.sendTo(bg.reduce!((a, b) => a ~ "\n" ~ b), addr);

}


class ElevatorCrash : Exception {
    this(string msg){
        super(msg);
    }
}

struct stateUpdated {}





string secondWindowProgram(){
return
"
import  std.stdio,
        std.socket,
        std.c.process;

void main(){
    import core.thread;

    auto    addr    = new InternetAddress(\"localhost\", " ~ comPort.to!string ~ ");
    auto    sock    = new UdpSocket();

    ubyte[2048]     buf;

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.bind(addr);

    while(sock.receive(buf) > 0){
        version(Windows){
            system(\"CLS\");
        }
        version(linux){
            system(\"clear\");
        }
        writeln(cast(string)buf);
        buf.destroy;
    }
}
";
};


}
