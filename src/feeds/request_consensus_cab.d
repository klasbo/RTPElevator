module feeds.request_consensus_cab;

//debug = request_consensus_cab;

import std.algorithm;
import std.concurrency;
import std.datetime;
import std.format;
import std.random;
import std.range;
import std.stdio;
import std.typecons;

import elev_config;
import feed;

import feeds.call_button_demuxer;
import feeds.peer_list;
import feeds.elevator_control;

import net.udp_bcast;
public import elevio.elev_types : HallCall;

import fns.request_consensus;





struct ActiveCabRequests {
    shared bool[][ubyte] requests;
    alias requests this;
}

struct LocalCabRequests {
    immutable (bool)[] requests;
    alias requests this;
}




void thr(){
    try {
    net.udp_bcast.Config netcfg = {
        id :            id,
        port :          feeds_requestConsensusCab_port,
        recvFromSelf :  1,
        bufSize :       feeds_requestConsensus_bufSize,
    };
    Tid netTx = net.udp_bcast.init!(CReqMsg)(thisTid, netcfg);

    subscribe!PeerList;
    subscribe!LostPeers;
    subscribe!CabRequest;
    subscribe!CompletedCabRequest;


    Req[][ubyte]    requests = [id : new Req[](numFloors)];
    ubyte[]         peers;

    publish(ActiveCabRequests(cast(shared)requests.activeCabRequests));
    publish(LocalCabRequests(requests.localActiveCabRequests.idup));
    
    while(true){
        Duration period = uniform(feeds_requestConsensus_minPeriod, feeds_requestConsensus_maxPeriod).msecs;
        bool timeout = !receiveTimeout(period,
            (CReqMsg a){
                Req[][ubyte] recvdRequests = a.requests;
                debug(request_consensus_cab){
                    bool reqDifference = false;
                    if(recvdRequests != requests){
                        reqDifference = true;
                        writeln("Received different cab request table from id:", a.owner);
                        recvdRequests.print;
                    }
                }

                foreach(ubyte remoteID, ref requestsForID; recvdRequests){
                    if(remoteID !in requests){
                        requests[remoteID] = requestsForID;
                        publish(ActiveCabRequests(cast(shared)requests.activeCabRequests));
                    }
                    
                    foreach(floor, ref remote; requestsForID){                    
                    
                        /// --- Merge worldviews (consensus algo) --- ///
                        merge(
                            requests[remoteID][floor],
                            remote,
                            id,
                            a.owner,
                            peers,
                            (){
                                publish(ActiveCabRequests(cast(shared)requests.activeCabRequests));
                                publish(LocalCabRequests(requests.localActiveCabRequests.idup));    // if ours.. ?
                            },
                            (){
                                publish(ActiveCabRequests(cast(shared)requests.activeCabRequests));
                                publish(LocalCabRequests(requests.localActiveCabRequests.idup));
                            }
                        );
                    }
                }

                debug(request_consensus_cab){
                    if(reqDifference || recvdRequests != requests){
                        writeln("Cab requests updated:");
                        requests.print;
                        writeln;
                    }
                }
            },
            (CabRequest a){
                requests[id][a].activate(id);
                debug(request_consensus_cab){
                    writeln("New request: ", a);
                    requests.print;
                    writeln;
                }
            },
            (CompletedCabRequest a){
                requests[id][a].deactivate(id, peers);
                debug(request_consensus_cab){
                    writeln("Cleared request: ", a);
                    requests.print;
                    writeln;
                }
                publish(ActiveCabRequests(cast(shared)requests.activeCabRequests));
                publish(LocalCabRequests(requests.localActiveCabRequests.idup));
            },
            (PeerList a){
                peers = a.dup.sort().array;
            },
            (LostPeers a){
                foreach(lostPeer; a){
                    if(lostPeer in requests){
                        foreach(floor, ref req; requests[lostPeer]){
                            if(req.state == ReqState.inactive){
                                req.state = ReqState.unknown;
                            }
                        }
                    }
                }
            }
        );
        if(timeout){
            netTx.send(CReqMsg(id, requests));
        }
    }
    } catch(Throwable t){ t.writeln; throw(t); }
}





private :


struct CReqMsg {
    this(ubyte owner, Req[][ubyte] requests){
        this.owner = owner;
        this._requests = cast(shared)requests.dup;
    }

    ubyte owner;
    shared Req[][ubyte] _requests;
    
    Req[][ubyte] requests(){
        return cast(Req[][ubyte])_requests;
    }
}


void print(Req[][ubyte] reqs){
    auto ackdByStrs = reqs.values.map!(a => a.map!(b => format("%s", b.ackdBy.sort())).array).array;
    auto maxAckdByStrLens = ackdByStrs.map!(a => a.map!(b => b.length).reduce!max).array;
    
    auto w = appender!string;
    
    formattedWrite(w, " Cab ");
    foreach(i, reqsForId; reqs.values){
        formattedWrite(w, "  |  %-*s", maxAckdByStrLens[i]+13, reqs.keys[i]);
    }
    formattedWrite(w, "\n");
    auto rv = reqs.values;
    for(int floor = 0; floor < rv[0].length; floor++){
        formattedWrite(w, "  %3d", floor);
        for(int i = 0; i < rv.length; i++){
            formattedWrite(w, "  |  %10s : %-*s", rv[i][floor].state, maxAckdByStrLens[i], ackdByStrs[i][floor]);
        }
        formattedWrite(w, "\n");
    }
    w.data.writeln;
}


bool[] localActiveCabRequests(Req[][ubyte] reqs){
    return reqs[id].map!(a => (a.state == ReqState.active)).array;
}

bool[][ubyte] activeCabRequests(Req[][ubyte] reqs){
    return reqs.keys.zip(reqs.values).map!(a => tuple(a[0], a[1].map!(b => (b.state == ReqState.active)).array)).assocArray;
}



















