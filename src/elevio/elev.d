module elevio.elev;

import  std.conv,
        std.string,
        std.socket,
        std.stdio;
        
        
import elev_config;
public import elevio.elev_types;

version(linux){
    extern(C){
        void elev_init();

        void elev_set_motor_direction(int dirn);
        void elev_set_button_lamp(int button, int floor, int value);
        void elev_set_floor_indicator(int floor);
        void elev_set_door_open_lamp(int value);
        void elev_set_stop_lamp(int value);

        int elev_get_button_signal(int button, int floor);
        int elev_get_floor_sensor_signal();
        int elev_get_stop_signal();
        int elev_get_obstruction_signal();
    }
} else {
    void elev_init(){ assert(0, "elev_init() not available on this OS"); }

    void elev_set_motor_direction(int dirn){}
    void elev_set_button_lamp(int button, int floor, int value){}
    void elev_set_floor_indicator(int floor){}
    void elev_set_door_open_lamp(int value){}
    void elev_set_stop_lamp(int value){}

    int elev_get_button_signal(int button, int floor){ return 0; }
    int elev_get_floor_sensor_signal(){ return 0; }
    int elev_get_stop_signal(){ return 0; }
    int elev_get_obstruction_signal(){ return 0; }
}







private __gshared TcpSocket sock;

mixin("simulator.con".conLoad!(
    string, "com_ip",
    ushort, "com_port",
));

shared static this(){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        try {
            sock = new TcpSocket();
            sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
            sock.connect(new InternetAddress(com_ip, com_port));
        } catch(Exception e){
            writeln(__FUNCTION__, ": Unable to connect to simulator");
        }
        break;
    case comedi:
        elev_init();
        break;
    }
    
    // Reset lights
    for(auto c = CallType.min; c <= CallType.max; c++){
        foreach(f; 0..numFloors){
            callButtonLight(f, c, false);
        }
    }
    floorIndicator(0);
    stopButtonLight(false);
    doorLight(false);    
    
    // Set Ctrl-C -handler
    version(linux){
        import core.sys.posix.signal;
        extern(C) void sigintHandler(int i){
            motorDirection(Dirn.stop);
            import std.c.process;
            exit(0);
        }
        sigset(SIGINT, &sigintHandler);
    } else version(Windows){
        import core.sys.windows.windows;
        extern(Windows) BOOL consoleHandler(DWORD signal) nothrow {
            try {
                if(signal == CTRL_C_EVENT){
                    motorDirection(Dirn.stop);
                    import std.c.process;
                    exit(0);
                }
            } catch(Throwable t){}
            return 1;
        }
        SetConsoleCtrlHandler(&consoleHandler, 1);
    }
}



void motorDirection(Dirn d){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [1, cast(ubyte)d, 0, 0];
        sock.send(buf);
        break;
    case comedi:
        elev_set_motor_direction(d);
        break;
    }
}

void callButtonLight(int floor, CallType call, bool on){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [2, cast(ubyte)call, cast(ubyte)floor, cast(ubyte)on];
        sock.send(buf);
        break;
    case comedi:
        elev_set_button_lamp(call, floor, on);
        break;
    }
}

void floorIndicator(int floor){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [3, cast(ubyte)floor, 0, 0];
        sock.send(buf);
        break;
    case comedi:
        elev_set_floor_indicator(floor);
        break;
    }
}

void doorLight(bool on){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [4, cast(ubyte)on, 0, 0];
        sock.send(buf);
        break;
    case comedi:
        elev_set_door_open_lamp(on);
        break;
    }
}

void stopButtonLight(bool on){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [5, cast(ubyte)on, 0, 0];
        sock.send(buf);
        break;
    case comedi:
        elev_set_stop_lamp(on);
        break;
    }
}




bool callButton(int floor, CallType call){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [6, cast(ubyte)call, cast(ubyte)floor, 0];
        sock.send(buf);
        sock.receive(buf);
        return buf[1].to!bool;
    case comedi:
        return elev_get_button_signal(call, floor).to!bool;
    }
}

int floorSensor(){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [7, 0, 0, 0];
        sock.send(buf);
        sock.receive(buf);
        return buf[1] ? buf[2] : -1;
    case comedi:
        return elev_get_floor_sensor_signal();
    }
}

bool stopButton(){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [8, 0, 0, 0];
        sock.send(buf);
        sock.receive(buf);
        return buf[1].to!bool;
    case comedi:
        return elev_get_stop_signal().to!bool;
    }
}

bool obstruction(){
    final switch(elevio_elevtype) with(ElevatorType){
    case simulation:
        ubyte[4] buf = [9, 0, 0, 0];
        sock.send(buf);
        sock.receive(buf);
        return buf[1].to!bool;
    case comedi:
        return elev_get_obstruction_signal().to!bool;
    }
}







