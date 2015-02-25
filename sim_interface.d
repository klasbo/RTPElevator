import  std.stdio,
        std.socket,
        std.concurrency,
        std.file,
        std.getopt,
        std.string,
        std.c.process,
        core.thread;

/*
Use QWE, SDF, ZXCV to control Up, Down, Command buttons.
Use T for Stop button, G for obstruction switch.

Windows: Keys react instantly.
Linux: Press key followed by Enter.
*/
        
        
shared ushort comPortToDisplay      = 40000;
shared ushort comPortFromDisplay    = 40001;

shared static this(){
    string[] configContents;
    try {
        configContents = readText("ElevatorConfig.con").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "simulationElevator_comPortToDisplay",          &comPortToDisplay,
            "simulationElevator_comPortFromDisplay",        &comPortFromDisplay,
        );
    } catch(Exception e){
        writeln("Unable to load simulationElevator config: ", e.msg);
    }
}


void thr_controlPanelInput(shared UdpSocket _sock){
    scope(exit){ writeln(__FUNCTION__, " died"); }

    auto    addr    = new InternetAddress("localhost", comPortFromDisplay);
    auto    sock    = cast(UdpSocket)_sock;

    version(Windows){
        import core.sys.windows.windows;
        SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), ENABLE_PROCESSED_INPUT);
    }
    while(1){
        foreach(ubyte[] buf; stdin.byChunk(1)){
            sock.sendTo(buf, addr);
            version(Windows){
                SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), ENABLE_PROCESSED_INPUT);
            }
        }
    }
}

void main(){
    scope(exit){ writeln(__FUNCTION__, " died"); }
    auto    addr    = new InternetAddress("localhost", comPortToDisplay);
    auto    sock    = new UdpSocket();

    ubyte[2048]     buf;

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.bind(addr);

    spawn( &thr_controlPanelInput, cast(shared)sock );

    void cls(){
        version(Windows){
            system("CLS");
        }
        version(linux){
            system("clear");
        }
    }
    cls;
    while(sock.receiveFrom(buf) > 0){
        cls;
        writeln(cast(string)buf);
        buf.destroy;
    }
}