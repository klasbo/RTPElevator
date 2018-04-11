module feeds.peer_list;

import std.algorithm;
import std.array;
import std.concurrency;
import std.stdio;

import elev_config;
import feed;
import net.peers;
public import net.peers : PeerList;



struct NewPeers {
    immutable(ubyte)[] peers;
    alias peers this;
}
struct LostPeers {
    immutable(ubyte)[] peers;
    alias peers this;
}


void thr(){
    try {
    net.peers.Config cfg = {
        port :      cfg.feeds_peerList_port,
        timeout :   cfg.feeds_peerList_timeout,
        interval :  cfg.feeds_peerList_interval,
        id :        cfg.id,
    };
    Tid peersTx = net.peers.init(thisTid, cfg);
    
    ubyte[] peers;
    
    while(true){
        receive(
            (PeerList a){
                publish(a);
                
                auto newList = a.dup.sort();
                
                auto newPeers = setDifference(a, peers).array.idup;
                if(!newPeers.empty){
                    publish(NewPeers(newPeers));
                }
                auto lostPeers = setDifference(peers, a).array.idup;
                if(!lostPeers.empty){
                    publish(LostPeers(lostPeers));
                }                
                
                peers = newList.array;
            }
        );
    }
    } catch (Throwable t){ t.writeln("\n", __FUNCTION__); }
}