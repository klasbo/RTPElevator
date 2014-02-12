module elevator_driver.simulation_elevator;


import  core.thread,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.file,
        std.process,
        std.socket,
        std.stdio,
        std.string;

public import  elevator_driver.i_elevator;

static this(){
    travelTime                  = 1500.msecs;
    doorOpenTime                = 650.msecs;
    btnDepressedTime            = 200.msecs;
}

/**
Visual representation of the elevator appears in a second window.
    Uses UDP port 40000 to communicate between the two windows.
    
Use QWE, SDF, ZXCV to control Up, Down, Command buttons.
Use T for Stop button, G for obstruction switch.

Windows: Keys react instantly.
Linux: Press key followed by Enter.

Linux: Spawns the window using mate-terminal.
*/
class SimulationElevator : Elevator
{
public:
    this(){
        simulationLoop_thread = spawn( &thr_simulationLoop );
        buttons = new shared bool[][](4, 3);
        lights  = new shared bool[][](4, 3);
        currDir = MotorDirection.STOP;
        prevDir = MotorDirection.STOP;
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

    void SetLight(string onoff)(int floor, Light l){
        if(floor < minFloor  ||  floor > maxFloor){
            assert(0, "SetLight floor is out of bounds: floor = " ~ floor.to!string);
        }
        if (l == Light.UP || l == Light.DOWN || l == Light.COMMAND){
            static if (onoff.toLower == "on"){
                lights[floor][l] = true;
            } else static if (onoff.toLower == "off"){
                lights[floor][l] = false;
            } else {
                static assert(0, "Invalid argument. Use \"on\" or \"off\". Got " ~ onoff);
            }
        } else {
            throw new Exception("Invalid argument. Use a floor-dependent light. Got " ~ to!(string)(l));
        }
        simulationLoop_thread.send(stateUpdated());
    }
    
    void SetLight(int floor, Light l){
        if (l == Light.FLOOR_INDICATOR){
            flrIndLight = floor;
        } else {
            assert(0, "Floor-dependent light must be set on or off");
        }
        simulationLoop_thread.send(stateUpdated());
    }

    void SetLight(string onoff)(Light l){
        switch(l){
            case Light.STOP:
                static if (onoff == "on"){
                    stpBtnLight = true;
                } else static if (onoff == "off"){
                    stpBtnLight = false;
                } else {
                    static assert(0, "Invalid argument. Use \"on\" or \"off\". Got " ~ onoff);
                }
                break;
            case Light.DOOR_OPEN:
                static if (onoff == "on"){
                    doorLight = true;
                } else static if (onoff == "off"){
                    doorLight = false;
                } else {
                    static assert(0, "Invalid argument. Use \"on\" or \"off\". Got " ~ onoff);
                }
                break;
            default:
                assert(0, "Invalid argument. Use a floor-invariant light. Got " ~ to!(string)(l));
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
    shared int              printCount;
    InternetAddress         addr;
    Socket                  sock;
    
    // Settings
    Duration                travelTime;
    Duration                doorOpenTime;
    Duration                btnDepressedTime;

    
    

void thr_simulationLoop(){
    scope(exit){ writeln(__FUNCTION__, " died"); }

     /+
    events:
        movements
            arr#  : arrive at floor #
                if arr-1 or arr5: crash
                set currFloor to #
                set prevFloor to #
            dep#  : depart floor #
                set currFloor to -1
        release buttons:
            btn%# : button %=u/d/c at floor #
            stp   : stop
    +/

    // --- IMPORTS --- //

    import util.timer_event;




    // --- DECLARATIONS --- //

    Tid         timerEvent_thread;
    Tid         controlPanelInput_thread;
    
    

    // --- FUNCTIONS --- //

    void handleTimerEvent(string s){
        //writeln("handling timer event: ", s);
        try {
            switch(s[0..3]){
                case "arr":
                    if(currDir != MotorDirection.STOP){
                        if(s[3] == '-'  || s[3] == '4'){
                            throw new ElevatorCrash("\nELEVATOR HAS CRASHED: \"Arrived\" at a non-existent floor\n");
                        }
                        if(currDir == MotorDirection.UP    &&  (s[3]-'0').to!int < prevFloor){ return; }
                        if(currDir == MotorDirection.DOWN  &&  (s[3]-'0').to!int > prevFloor){ return; }
                        currFloor = prevFloor = (s[3]-'0').to!int;
                        timerEvent_thread.send(thisTid, "dep"~currFloor.to!string, doorOpenTime);
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
                        timerEvent_thread.send(thisTid, "arr"~(prevFloor+1).to!string, travelTime);
                        nextFloor = prevFloor+1;
                        return;
                    }
                    if(currDir == MotorDirection.DOWN){
                        if(s[3] == '0'){
                            throw new ElevatorCrash("\nELEVATOR HAS CRASHED: Departed bottom floor going downward\n");
                        }
                        currFloor = -1;
                        timerEvent_thread.send(thisTid, "arr"~(prevFloor-1).to!string, travelTime);
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
        } catch(Throwable t){
            if(typeid(t) == typeid(ElevatorCrash)){ throw t; }
            writeln("Bad timer event received: unable to parse \"", s, "\"");
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
    addr                        = new InternetAddress("localhost", 40000);
    sock                        = new UdpSocket();
    
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    
    // Create and spawn second window
    string path = thisExePath[0..thisExePath.lastIndexOf("\\")+1];
    std.file.write(path~"secondWindow1.d", secondWindowProgram);
    version(Windows){
        std.process.spawnShell(("start \"\" rdmd -w -g \"" ~ path ~ "secondWindow1.d\""));
    } else version(linux){
        std.process.spawnShell(("mate-terminal -x rdmd -w -g \"" ~ path ~ "secondWindow1.d\""));
    }
    Thread.sleep(1.seconds);
    std.file.remove(path~"secondWindow1.d");
    

    // --- LOOP --- //
    printState;
    while(1){
        receive(
            (MotorDirection m){
                if(currDir != MotorDirection.STOP){
                    prevDir = currDir;
                }
                currDir = m;
                //writeln("received MotorDirChange: prevDir=", prevDir, " currDir=", currDir,
                //                                " prevFloor=", prevFloor, " currFloor=", currFloor);

                if(currDir == MotorDirection.UP){
                    if(currFloor != -1){
                        timerEvent_thread.send(thisTid, "dep"~currFloor.to!string, doorOpenTime);
                    }
                    if(currFloor == -1){
                        if(prevDir == MotorDirection.UP){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor+1).to!string, travelTime);
                            nextFloor = prevFloor+1;
                        }
                        if(prevDir == MotorDirection.DOWN){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor).to!string, travelTime);
                        }
                    }
                }
                if(currDir == MotorDirection.DOWN){
                    if(currFloor != -1){
                        timerEvent_thread.send(thisTid, "dep"~currFloor.to!string, doorOpenTime);
                    }
                    if(currFloor == -1){
                        if(prevDir == MotorDirection.UP){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor).to!string, travelTime);
                        }
                        if(prevDir == MotorDirection.DOWN){
                            timerEvent_thread.send(thisTid, "arr"~(prevFloor-1).to!string, travelTime);
                            nextFloor = prevFloor-1;
                        }
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
            (stateUpdated su){
            }
        );
        printState;
    }
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
        "|               | |d|  0  1  2      | o  |",
        "| 0 - 1 - 2 - 3 | |u|     1  2  3   | d  |",
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





auto secondWindowProgram = 
q"EOS
import  std.stdio,
        std.socket,
        std.c.process;
        
void main(){    
    scope(exit) writeln(__FUNCTION__, " died");

    auto    addr    = new InternetAddress("localhost", 40000);
    auto    sock    = new UdpSocket();
    
    ubyte[2048]     buf;    
    
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.bind(addr);

    while(sock.receive(buf) > 0){
        version(Windows){
            system("CLS");
        }
        version(linux){
            system("clear");
        }
        writeln(cast(string)buf);
        buf.clear;
    }
}
EOS";


}
