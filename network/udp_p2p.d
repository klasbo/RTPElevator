module network.udp_p2p;

import  core.thread,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.datetime,
        std.socket,
        std.stdio,
        std.string;




public {
    static this(){
        localIP     = new TcpSocket(new InternetAddress("www.google.com", 80)).localAddress.toAddrString;
        broadcastIP = localIP[0..localIP.lastIndexOf(".")+1] ~ "255";
    }

    Tid udp_p2p_start(){
        Tid t = spawn( &udp_p2p );
        receiveOnly!(initDone);
        return t;
    }

    struct peerListUpdate {
        immutable(ubyte)[] peers;
    }
}


private {
    string  localIP;
    string  broadcastIP;
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




    void udp_p2p(){
        scope(exit) writeln(__FUNCTION__, " died");


        tids["iAmAlive_send"]   = spawnLinked( &iAmAlive_send_thr );    receiveOnly!(initDone);
        tids["iAmAlive_recv"]   = spawnLinked( &iAmAlive_recv_thr );    receiveOnly!(initDone);
        tids["msg_send"]        = spawnLinked( &msg_send_thr );         receiveOnly!(initDone);
        tids["msg_recv"]        = spawnLinked( &msg_recv_thr );         receiveOnly!(initDone);


        ownerTid.send(initDone());
        while(true){
            receive(
                (msgFromNetwork mfn){
                    ownerTid.send(thisTid, mfn.msg);
                },
                (string msg){
                    tids["msg_send"].send(msgToNetwork(msg));
                },
                (peerListUpdate plu){
                    ownerTid.send(thisTid, plu);
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

        ownerTid.send(initDone());
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

        ownerTid.send(initDone());
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

        ownerTid.send(initDone());
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

        import std.range : strip;
        ownerTid.send(initDone());
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