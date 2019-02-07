module elevio.elev;

import  std.conv,
        std.string,
        std.socket,
        std.stdio,
        core.stdc.stdlib;
        
        
import elev_config;
public import elevio.elev_types;


private __gshared TcpSocket sock;



void elevio_init(){
    try {
        sock = new TcpSocket();
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        sock.connect(new InternetAddress(cfg.elevio_elev_ip, cfg.elevio_elev_port));
    } catch(Exception e){
        writeln(__FUNCTION__, ": Unable to connect to elevator");
        exit(0);
    }
    
    // Reset lights
    for(auto c = CallType.min; c <= CallType.max; c++){
        foreach(f; 0..cfg.numFloors){
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
            exit(0);
        }
        sigset(SIGINT, &sigintHandler);
    } else version(Windows){
        import core.sys.windows.windows;
        extern(Windows) BOOL consoleHandler(DWORD signal) nothrow {
            try {
                if(signal == CTRL_C_EVENT){
                    motorDirection(Dirn.stop);
                    exit(0);
                }
            } catch(Throwable t){}
            return 1;
        }
        SetConsoleCtrlHandler(&consoleHandler, 1);
    }
}



void motorDirection(Dirn d){
    ubyte[4] buf = [1, cast(ubyte)d, 0, 0];
    sock.send(buf);
}

void callButtonLight(int floor, CallType call, bool on){
    ubyte[4] buf = [2, cast(ubyte)call, cast(ubyte)floor, cast(ubyte)on];
    sock.send(buf);
}

void floorIndicator(int floor){
    ubyte[4] buf = [3, cast(ubyte)floor, 0, 0];
    sock.send(buf);
}

void doorLight(bool on){
    ubyte[4] buf = [4, cast(ubyte)on, 0, 0];
    sock.send(buf);
}

void stopButtonLight(bool on){
    ubyte[4] buf = [5, cast(ubyte)on, 0, 0];
    sock.send(buf);
}




bool callButton(int floor, CallType call){
    ubyte[4] buf = [6, cast(ubyte)call, cast(ubyte)floor, 0];
    sock.send(buf);
    sock.receive(buf);    
    return buf[1].to!bool;
}

int floorSensor(){
    ubyte[4] buf = [7, 0, 0, 0];
    sock.send(buf);
    sock.receive(buf);
    return buf[1] ? buf[2] : -1;
}

bool stopButton(){
    ubyte[4] buf = [8, 0, 0, 0];
    sock.send(buf);
    sock.receive(buf);
    return buf[1].to!bool;
}

bool obstruction(){
    ubyte[4] buf = [9, 0, 0, 0];
    sock.send(buf);
    sock.receive(buf);
    return buf[1].to!bool;
}







