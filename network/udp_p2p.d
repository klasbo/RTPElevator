module network.udp_p2p;

import  core.thread,
        std.algorithm,
        std.bitmanip,
        std.concurrency,
        std.conv,
        std.datetime,
        std.file,
        std.getopt,
        std.socket,
        std.stdio,
        std.string;


public {
    shared static this(){
        scope(failure) writeln("Unable to resolve local IP address");
        auto sock   = new TcpSocket(new InternetAddress("www.google.com", 80));
        localIP     = sock.localAddress.toAddrString;
        sock.close;
        broadcastIP = localIP[0..localIP.lastIndexOf(".")+1] ~ "255";
        _thisPeerID = localIP[localIP.lastIndexOf(".")+1..$].to!ubyte;
    }

    Tid udp_p2p_start(Tid receiver = thisTid){
        Tid t = spawn( &udp_p2p, receiver );
        receive((initDone id){});
        return t;
    }

    ID thisPeerID(){
        return (_thisPeerID + idOffset);
    }

    struct peerListUpdate {
        immutable(ID)[] peers;
        alias peers this;
    }

    alias ID = int;
}

shared static this(){
    string[] configContents;
    try {
        configContents = readText("ElevatorConfig.con").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "network_IDOffset",                 &idOffset,
            "network_iAmAliveSendInterval_ms",  &iAmAliveSendInterval_ms,
            "network_iAmAliveTimeout_ms",       &iAmAliveTimeout_ms,
            "network_iAmAlivePort",             &iAmAlivePort,
            "network_msgPort",                  &msgPort
        );
    } catch(Exception e){
        writeln("Unable to load network config: ", e.msg);
    }
}

private {
    shared string       localIP;
    shared string       broadcastIP;
    shared ubyte        _thisPeerID;
    shared ID           idOffset                = 0;
    shared uint         iAmAliveSendInterval_ms = 300;
    shared uint         iAmAliveTimeout_ms      = 1000;
    shared ushort       iAmAlivePort            = 22222;
    shared ushort       msgPort                 = 22223;

    enum                msgBufsize              = 1024;
    enum                aliveBufsize            = ID.sizeof;

    struct msgFromNetwork {
        string msg;
    }
    struct msgToNetwork {
        string msg;
    }
    struct initDone {}




    void udp_p2p(Tid receiver){
        scope(exit) writeln(__FUNCTION__, " died");

        auto iAmAlive_send_tid  = spawn( &iAmAlive_send_thr );
        auto iAmAlive_recv_tid  = spawn( &iAmAlive_recv_thr );
        auto msg_send_tid       = spawn( &msg_send_thr      );
        auto msg_recv_tid       = spawn( &msg_recv_thr      );
        
        
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
        try {

        auto    addr                    = new InternetAddress(broadcastIP, iAmAlivePort);
        auto    sock                    = new UdpSocket();
        ubyte[] id                      = new ubyte[](aliveBufsize);
        auto    iAmAliveSendInterval    = iAmAliveSendInterval_ms.msecs;
        id.write!(ID)(thisPeerID, 0);

        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

        while(true){
            sock.sendTo(id, addr);
            Thread.sleep(iAmAliveSendInterval);
        }
        } catch(Throwable t){ t.writeln; throw t; }
    }

    void iAmAlive_recv_thr(){
        scope(exit) writeln(__FUNCTION__, " died");
        try {

        auto    addr                    = new InternetAddress(iAmAlivePort);
        auto    sock                    = new UdpSocket();
        auto    iAmAliveTimeout         = iAmAliveTimeout_ms.msecs;

        ID              id;
        ubyte[]         buf             = new ubyte[](aliveBufsize);
        SysTime[ID]     lastSeen;
        bool            listHasChanges;


        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, iAmAliveTimeout);
        sock.bind(addr);

        while(true){
            listHasChanges  = false;
            buf[]           = 0;

            sock.receiveFrom(buf);
            id = buf.peek!ID;

            if(id != 0){
                if(id !in lastSeen){
                    listHasChanges = true;
                }
                lastSeen[id] = Clock.currTime;
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
        } catch(Throwable t){ t.writeln; throw t; }
    }

    void msg_send_thr(){
        scope(exit) writeln(__FUNCTION__, " died");
        try {

        auto    addr    = new InternetAddress(broadcastIP, msgPort);
        auto    sock    = new UdpSocket();

        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

        while(true){
            receive(
                (msgToNetwork mtn){
                    assert(mtn.msg.length < msgBufsize,
                        "Cannot send message larger than the buffer size (" ~ mtn.msg.length.to!string ~ " > " ~ msgBufsize.to!string ~ ")");
                    sock.sendTo(mtn.msg, addr);
                }
            );
        }
        } catch(Throwable t){ t.writeln; throw t; }
    }

    void msg_recv_thr(){
        scope(exit) writeln(__FUNCTION__, " died");
        try {

        auto    addr    = new InternetAddress(msgPort);
        auto    sock    = new UdpSocket();
        ubyte[msgBufsize] buf;

        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        sock.bind(addr);

        while(sock.receiveFrom(buf) > 0){
            ownerTid.send( msgFromNetwork( (cast(string)buf).strip('\0').dup ) );
            buf.destroy;
        }
        } catch(Throwable t){ t.writeln; throw t; }
    }


    ubyte addrStringLastByte(Address addr){
        string ip = addr.toAddrString;
        return ip[ip.lastIndexOf(".")+1..$].to!ubyte;
    }

}