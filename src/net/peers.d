module net.peers;


import core.thread;
import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.datetime;
import std.file;
import std.getopt;
import std.socket;
import std.stdio;

        
struct PeerList {
    immutable(ubyte)[] peers;
    alias peers this;
}

struct TxEnable {
    bool enable;
    alias enable this;
}

struct Config {
    ubyte   id          = 255;
    ushort  port        = 16567;
    int     interval    = 100;
    int     timeout     = 350;
}


Tid init(Tid receiver = thisTid, Config cfg = Config.init){
    spawnLinked(&rx, receiver, cfg);
    return spawnLinked(&tx, cfg);
}



private void tx(Config cfg){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr                    = new InternetAddress("255.255.255.255", cfg.port);
    auto    sock                    = new UdpSocket();
    ubyte[1] buf                    = [cfg.id];

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    bool txEnable = true;
    bool quit = false;
    while(!quit){
        receiveTimeout(cfg.interval.msecs,
            (LinkTerminated lt){    quit = true;    },
            (OwnerTerminated ot){   quit = true;    },
            (TxEnable t){
                txEnable = t;
            }
        );
        if(txEnable){
            sock.sendTo(buf, addr);
        }
    }
    } catch(Throwable t){ t.writeln; throw t; }
}

private void rx(Tid receiver, Config cfg){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr                    = new InternetAddress(cfg.port);
    auto    sock                    = new UdpSocket();

    ubyte[1]        buf;
    SysTime[ubyte]  lastSeen;
    bool            listHasChanges;


    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, cfg.timeout.msecs);
    sock.bind(addr);

    bool quit = false;
    while(!quit){    
        listHasChanges  = false;
        buf[]           = 0;

        sock.receiveFrom(buf);

        if(buf[0] != 0){
            if(buf[0] !in lastSeen){
                listHasChanges = true;
            }
            lastSeen[buf[0]] = Clock.currTime;
        }

        foreach(k, v; lastSeen){
            if(Clock.currTime - v > cfg.timeout.msecs){
                listHasChanges = true;
                lastSeen.remove(k);
            }
        }

        if(listHasChanges){
            ownerTid.send(PeerList(lastSeen.keys.idup));
        }
        
        
        receiveTimeout(0.msecs,
            (LinkTerminated lt){    quit = true;    },
            (OwnerTerminated ot){   quit = true;    },
        );
    }
    } catch(Throwable t){ t.writeln; throw t; }
}