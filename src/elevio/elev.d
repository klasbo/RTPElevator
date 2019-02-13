module elevio.elev;

import  std.conv,
        std.exception,
        std.string,
        std.socket,
        std.stdio,
        core.sync.mutex;
        
        
import elev_config;
public import elevio.elev_types;


private __gshared TcpSocket sock;
private __gshared Mutex     mtx;
private __gshared bool      ok      = false;

shared static this(){
    mtx = new Mutex;
}


private ubyte[4] get(ubyte[4] cmd){
    ubyte[4] buf;
    synchronized(mtx){
        ok = (sock.send(cmd)  != -1);
        ok = (sock.receive(buf) != -1);
        enforce(ok);
    }
    return buf;
}

private void set(ubyte[4] cmd){
    synchronized(mtx){
        ok = (sock.send(cmd)  != -1);
        enforce(ok);
    }
}



void elevio_init(){
    synchronized(mtx){
        if(!ok){
            try {
                sock = new TcpSocket();
                sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
                sock.connect(new InternetAddress(cfg.elevio_elev_ip, cfg.elevio_elev_port));
            } catch(Exception e){
                writeln(__FUNCTION__, ": Unable to connect to elevator");
            }
        }
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
}



void motorDirection(Dirn d){
    set([1, cast(ubyte)d, 0, 0]);
}

void callButtonLight(int floor, CallType call, bool on){
    set([2, cast(ubyte)call, cast(ubyte)floor, cast(ubyte)on]);
}

void floorIndicator(int floor){
    set([3, cast(ubyte)floor, 0, 0]);
}

void doorLight(bool on){
    set([4, cast(ubyte)on, 0, 0]);
}

void stopButtonLight(bool on){
    set([5, cast(ubyte)on, 0, 0]);
}




bool callButton(int floor, CallType call){
    auto buf = get([6, cast(ubyte)call, cast(ubyte)floor, 0]);
    return buf[1].to!bool;
}

int floorSensor(){
    auto buf = get([7, 0, 0, 0]);
    return buf[1] ? buf[2] : -1;
}

bool stopButton(){
    auto buf = get([8, 0, 0, 0]);
    return buf[1].to!bool;
}

bool obstruction(){
    auto buf = get([9, 0, 0, 0]);
    return buf[1].to!bool;
}







