module network.udp_p2p;

import  core.thread,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.datetime,
        std.socket,
        std.stdio,
        std.string;

import  util.threeway_spawn_mixin;


public {
    static this(){
        localIP     = new TcpSocket(new InternetAddress("www.google.com", 80)).localAddress.toAddrString;
        broadcastIP = localIP[0..localIP.lastIndexOf(".")+1] ~ "255";
        _thisPeerID = localIP[localIP.lastIndexOf(".")+1..$].to!ubyte;
    }

    Tid udp_p2p_start(Tid receiver = thisTid){
        Tid t = spawn( &udp_p2p, receiver );
        receive((initDone id){});
        return t;
    }
    
    ubyte thisPeerID(){
        return _thisPeerID;
    }

    struct peerListUpdate {
        immutable(ubyte)[] peers;
        alias peers this;
    }
}


private {
    string  localIP;
    string  broadcastIP;
    ubyte   _thisPeerID;
    enum    msg_bufsize             = 1024;
    auto    iAmAliveSendInterval    = 300.msecs;
    auto    iAmAliveTimeout         = 1.seconds;
    ushort  iAmAlivePort            = 22222;
    ushort  msgPort                 = 22223;
    bool    recvMsgsFromSelf        = true;

    struct msgFromNetwork {
        string msg;
    }
    struct msgToNetwork {
        string msg;
    }
    Tid[string] tids;

    struct initDone {}




    void udp_p2p(Tid receiver){
        scope(exit) writeln(__FUNCTION__, " died");
        
        mixin(spawn3way(
            [   "thread:iAmAlive_send_tid   iAmAlive_send_thr",
                "thread:iAmAlive_recv_tid   iAmAlive_recv_thr",
                "thread:msg_send_tid        msg_send_thr",
                "thread:msg_recv_tid        msg_recv_thr"   ],
            false
        ));

        //tids["iAmAlive_send"]   = spawnLinked( &iAmAlive_send_thr );    receiveOnly!(initDone);
        //tids["iAmAlive_recv"]   = spawnLinked( &iAmAlive_recv_thr );    receiveOnly!(initDone);
        //tids["msg_send"]        = spawnLinked( &msg_send_thr );         receiveOnly!(initDone);
        //tids["msg_recv"]        = spawnLinked( &msg_recv_thr );         receiveOnly!(initDone);


        ownerTid.send(initDone());
        while(true){
            receive(
                (msgFromNetwork mfn){
                    receiver.send(thisTid, mfn.msg);
                },
                (string msg){
                    msg_send_tid.send(msgToNetwork(msg));
                },
                (peerListUpdate plu){
                    receiver.send(thisTid, plu);
                },
                (LinkTerminated lt){
                    
                },
                (Variant v){
                    writeln(__FUNCTION__, " received unknown type ", v);
                }
            );
        }

    }


    void iAmAlive_send_thr(){
        scope(exit) writeln(__FUNCTION__, " died");
        auto    addr    = new InternetAddress(broadcastIP, iAmAlivePort);
        auto    sock    = new UdpSocket();

        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

        //ownerTid.send(initDone());
        mixin(reciprocate3way(""));
        while(true){
            sock.sendTo("!", addr);
            Thread.sleep(iAmAliveSendInterval);
        }

    }

    void iAmAlive_recv_thr(){
        scope(exit) writeln(__FUNCTION__, " died");

        auto    addr    = new InternetAddress(iAmAlivePort);
        auto    sock    = new UdpSocket();
        ubyte[2]            buf;
        SysTime[ubyte]      lastSeen;
        Address             remoteAddr;
        bool                listHasChanges;
        ubyte               addrLastByte;

        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, iAmAliveTimeout);
        sock.bind(addr);

        //ownerTid.send(initDone());
        mixin(reciprocate3way(""));
        while(true){
            listHasChanges  = false;
            remoteAddr      = new UnknownAddress;
            sock.receiveFrom(buf, remoteAddr);
            addrLastByte    = remoteAddr.addrStringLastByte;

            if(addrLastByte != 0){
                if(addrLastByte !in lastSeen){
                    listHasChanges = true;
                }
                lastSeen[addrLastByte] = Clock.currTime;
            }

            foreach(k, v; lastSeen){
                if(Clock.currTime - v > iAmAliveTimeout){
                    listHasChanges = true;
                    lastSeen.remove(k);
                }
            }

            if(listHasChanges){
                ownerTid.send(peerListUpdate(lastSeen.keys.idup));
            }
        }
    }

    void msg_send_thr(){
        scope(exit) writeln(__FUNCTION__, " died");

        auto    addr    = new InternetAddress(broadcastIP, msgPort);
        auto    sock    = new UdpSocket();

        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

        //ownerTid.send(initDone());
        mixin(reciprocate3way(""));
        while(true){
            receive(
                (msgToNetwork mtn){
                    assert(mtn.msg.length < msg_bufsize,
                        "Cannot send message larger than the buffer size (" ~ msg_bufsize.to!string ~ ")");
                    sock.sendTo(mtn.msg, addr);
                }
            );
        }
    }

    void msg_recv_thr(){
        scope(exit) writeln(__FUNCTION__, " died");

        auto    addr    = new InternetAddress(msgPort);
        auto    sock    = new UdpSocket();
        ubyte[msg_bufsize]  buf;
        Address             remoteAddr;

        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        sock.bind(addr);

        import std.algorithm : strip;
        //ownerTid.send(initDone());
        mixin(reciprocate3way(""));
        while(sock.receiveFrom(buf, remoteAddr) > 0){
            if(recvMsgsFromSelf || remoteAddr.toAddrString != localIP){
                ownerTid.send( msgFromNetwork( (cast(string)buf).strip('\0').dup ) );
            }
            buf.clear;
        }
    }


    ubyte addrStringLastByte(Address addr){
        string ip = addr.toAddrString;
        return ip[ip.lastIndexOf(".")+1..$].to!ubyte;
    }

}
