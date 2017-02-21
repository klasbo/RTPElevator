module net.udp_bcast;

import std.array;
import std.algorithm;
import std.concurrency;
import std.conv;
import std.datetime;
import std.meta;
import std.socket;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;

import jsonx;



template isSerialisable(T){
    enum isSerialisable = is(T == struct)  &&  (allSatisfy!(isBuiltinType, RepresentationTypeTuple!T) && !hasUnsharedAliasing!T);
}


struct Config {
    ubyte   id              = 255;
    ushort  port            = 16567;
    int     recvFromSelf    = 0;
    size_t  bufSize         = 1024;
}

Tid init(T...)(Tid receiver = thisTid, Config cfg = Config.init) if(allSatisfy!(isSerialisable, T)){
    spawnLinked(&rx!T, receiver, cfg);
    return spawnLinked(&tx!T, cfg);
}




private void rx(T...)(Tid receiver, Config cfg){

    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr    = new InternetAddress(cfg.port);
    auto    sock    = new UdpSocket();
    ubyte[] buf     = new ubyte[](cfg.bufSize);
    Address remote  = new UnknownAddress;

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.bind(addr);
    
    bool quit = false;
    while(!quit){
        
        auto n = sock.receiveFrom(buf, remote);
        if(n > 0){
            ubyte remoteId = buf[0];
            if(cfg.recvFromSelf  ||  remoteId != cfg.id){
                string s = (cast(string)buf[1..n].dup).strip('\0');
                foreach(t; T){
                    if(s.startsWith(t.stringof ~ "{")){
                        s.skipOver(t.stringof);
                        try {
                            receiver.send(s.jsonDecode!t);
                        } catch(Exception e){
                            writeln(__FUNCTION__, " Decoding type ", t.stringof, " failed: ", e.msg);
                        }
                    }
                }
            }
        }
        buf[0..n] = 0;
        
        receiveTimeout(0.msecs,
            (LinkTerminated lt){    quit = true;    },
            (OwnerTerminated ot){   quit = true;    },
        );        
    }
    
    } catch(Throwable t){ t.writeln; throw t; }

}

private void tx(T...)(Config cfg){
    scope(exit) writeln(__FUNCTION__, " died");
    try {
    
    auto    addr    = new InternetAddress("255.255.255.255", cfg.port);
    auto    sock    = new UdpSocket();

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    bool quit = false;
    while(!quit){
        receive(
            (LinkTerminated lt){    quit = true;    },
            (OwnerTerminated ot){   quit = true;    },
            (Variant v){
                foreach(t; T){
                    if(v.type == typeid(t)){
                        string msg = __traits(identifier, t) ~ v.get!t.jsonEncode;
                        sock.sendTo([cfg.id] ~ cast(ubyte[])msg, addr);
                        return;
                    }
                }
                writeln(__FUNCTION__, " Unexpected type! ", v);
            }
        );
    }
    } catch(Throwable t){ t.writeln; throw t; }    
}








