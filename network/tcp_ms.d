module network.tcp_ms;

import  core.thread,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.datetime,
        std.range,
        std.socket,
        std.stdio,
        std.string,
        std.typecons;

        

        
ushort  tcpPort                 = 27567;
ushort  iAmAlivePort            = 27546;
auto    iAmAliveSendInterval    = 300.msecs;
auto    iAmAliveTimeout         = 1.seconds;
string  localIP;
string  IPprefix;
string  broadcastIP;
ubyte   thisPeerID;


static this(){
    localIP     = new TcpSocket(new InternetAddress("www.google.com", 80)).localAddress.toAddrString;
    IPprefix    = localIP[0 .. localIP.lastIndexOf(".")+1];
    broadcastIP = IPprefix ~ "255";
    thisPeerID  = localIP[localIP.lastIndexOf(".")+1 .. $].to!ubyte;
}

Tid tcp_ms_start(){
    Tid t = spawn( &tcp_ms_hub );
    receiveOnly!(initDone);
    return t;
}

void tcp_ms_hub(){
    writeln(__FUNCTION__, " started");
    
    conn_t[ubyte]   socketMap;
    ubyte[]         currPeers;
    bool            isMaster;
    ubyte           newMasterID;
    ubyte           oldMasterID;

    void printConnInfo(){
        writeln("\n  Current socketMap: ", 
                zip(socketMap.keys, socketMap.values.map!(a => a.socket.isAlive)).map!(a => a[0].to!string ~ ":" ~ (a[1] ? "alive" : "dead")).array,
                "\n  Current peers: ", currPeers,
                "\n  This is master: ", isMaster );
    }


    auto accepter = spawn( &accept_thr, thisTid );  receiveOnly!initDone;
    auto aliveSender = spawn( &iAmAlive_send_thr ); receiveOnly!initDone;
    auto aliveRecver = spawn( &iAmAlive_recv_thr ); receiveOnly!initDone;

    accepter.send(initDone());
    aliveSender.send(initDone());
    aliveRecver.send(initDone());
    

    ownerTid.send(initDone());
    while(true){
        receive(
            // Send a message to all connections
            // If the set of connections is properly maintained, it should only contain:
            //     When slave: only the master
            //     When master: all the slaves
            (string msg){
                foreach(conn; socketMap){
                    conn.socket.send(msg~"\0");
                }
            },
            
            // Received a message from the network
            // Forward it to the owner of the network module instance
            (Tid t, msgFromNetwork mfn){
                if(mfn.msg.length){
                    ownerTid.send(thisTid, mfn.msg);
                }
            },
            
            // Received a new socket (accepted)
            // Add to socketMap
            (Tid t, shared Socket s){
                if(isMaster  &&  t == accepter){
                    debug(tcp_ms) writeln("  Adding Socket ", (cast(Socket)s).remoteAddress.addrStringLastByte, "...");
                    socketMap[(cast(Socket)s).remoteAddress.addrStringLastByte] = 
                        conn_t( cast(Socket)s, spawn( &receive_thr, thisTid, s ) );
                } else {
                    debug(tcp_ms) writeln("Got new socket when not master");
                }
                printConnInfo();
            },
            
            // A socket was shut down (connection died)
            // Remove from the socketMap
            (Tid t, shutdownMsg s){
                debug(tcp_ms) writeln("  Removing Socket ", s.ID, "...");
                socketMap.remove(s.ID);
                printConnInfo();
            },
            
            
            // List of active peers has a changed
            // If slave->master (self has new highest ID):
            //    Kill all conns
            // If master->slave (other has new highest ID) OR slave->slave for new master (masterID has changed):
            //    Kill all conns. Connect to new master.
            // Otherwise: Do nothing
            (peerListUpdate plu){
                currPeers = plu.peers.dup.sort;
                debug(tcp_ms) writeln("New peer list: ", currPeers);

                newMasterID = currPeers.reduce!max;

                debug(tcp_ms) writeln("  thisPeerID:", thisPeerID, "\n",
                        "  newMasterID:", newMasterID, "\n",
                        "  oldMasterID:", oldMasterID, "\n",
                        "  isMaster:", isMaster, "\n",
                        );

                if(!isMaster  &&  thisPeerID == newMasterID){
                    socketMap.killAllConns;
                    isMaster = true;
                    writeln(thisPeerID, " is now the master");
                } else if ((isMaster  &&  thisPeerID < newMasterID)  || (newMasterID != oldMasterID)){
                    socketMap.killAllConns;
                    auto newConn = new TcpSocket(new InternetAddress(IPprefix ~ newMasterID.to!string, tcpPort));
                    socketMap[newMasterID] = conn_t( newConn, spawn( &receive_thr, thisTid, cast(shared)newConn ) );
                    isMaster = false;
                    writeln(thisPeerID, " is now a slave. Expecting ", newMasterID, " to become the master");
                }
                oldMasterID = newMasterID;

                printConnInfo();
                
                ownerTid.send(thisTid, plu);    
            },
            
            // Unknown type
            (Variant v){
                writeln(v, " (unknown)");
            }
        );     
    }
}


void iAmAlive_send_thr(){
    auto    addr    = new InternetAddress(broadcastIP, iAmAlivePort);
    auto    sock    = new UdpSocket();

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    ownerTid.send(initDone());
    receiveOnly!initDone;
    while(true){
        sock.sendTo("!", addr);
        Thread.sleep(iAmAliveSendInterval);
    }
}

void iAmAlive_recv_thr(){
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
    receiveOnly!initDone;
    while(true){
        listHasChanges  = false;
        remoteAddr      = new UnknownAddress;
        sock.receiveFrom(buf, remoteAddr);
        addrLastByte    = remoteAddr.addrStringLastByte;

        if(addrLastByte != 0 /+ &&  addrLastByte != thisPeerID+/){
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
    
    


/** 
Read until '\0' on socket s
Send a msgFromNetwork with the content to recipient
 */
void receive_thr(Tid recipient, shared Socket s){
    scope(exit){ 
        debug(tcp_ms) writeln("scope(exit): ", __FUNCTION__, " for ID ", ID);
    }

    auto        sock    = cast(Socket)s;
    ubyte       ID      = sock.remoteAddress.addrStringLastByte;
    ubyte[1]    buff;
    string      buffer;

    debug(tcp_ms) writeln("    Receive thread started for ", sock.localAddress, " <-> ", sock.remoteAddress);

    while(sock.isAlive){
        long retVal = sock.receive(buff);
        if(retVal > 0){
            if(buff[0] != 0){
                buffer ~= buff;
            } else {
                recipient.send(thisTid, msgFromNetwork(buffer));
                buffer.clear;
            }
        } else {
            writeln("Disconnected... ", sock.localAddress, " <-> ", sock.remoteAddress, " ", Clock.currTime);
            sock.shutdown(SocketShutdown.BOTH);
            recipient.send(thisTid, shutdownMsg(ID));
            return;
        }
    }
    recipient.send(thisTid, shutdownMsg(ID));
}



/**
Accept sockets on tcpPort
Sends (thisTid, socket) to the receiver
*/
void accept_thr(Tid receiver){
    Socket acceptSock  = new TcpSocket();
    Socket newSock;

    acceptSock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    acceptSock.bind(new InternetAddress(tcpPort));
    acceptSock.listen(10);

    ownerTid.send(initDone());
    receiveOnly!initDone;
    while(true){
        newSock = acceptSock.accept();
        writeln("    Accepted socket ", newSock.remoteAddress, " on ", Clock.currTime );
        receiver.send(thisTid, cast(shared)newSock);
    }


}

/*
Get the last byte of an IPv4 Address
*/
ubyte addrStringLastByte(Address addr){
    string ip = addr.toAddrString;
    return ip[ip.lastIndexOf(".")+1..$].to!ubyte;
}


/*
Kill all connections i a socket map
The receiver should receive() an error since the socket has been shut down.
*/
void killAllConns(ref conn_t[ubyte] conns){
    foreach(key, val; conns){
        val.socket.shutdown(SocketShutdown.BOTH);
    }
}


alias Tuple!(Socket, "socket", Tid, "receiver") conn_t;

struct shutdownMsg {
    ubyte ID;
}
struct msgFromNetwork {
    string msg;
}
struct msgToNetwork {
    string msg;
}
struct initDone {}
struct peerListUpdate {
    immutable(ubyte)[] peers;
}