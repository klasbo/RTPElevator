module feeds.request_consensus_hall;

//debug = request_consensus_hall;

import std.algorithm;
import std.concurrency;
import std.datetime;
import std.format;
import std.random;
import std.range;
import std.stdio;

import elev_config;
import feed;

import feeds.elevio_reader;
import feeds.peer_list;
import feeds.elevator_control;

import net.udp_bcast;

import fns.request_consensus;





struct ActiveHallRequests {
    immutable(bool[2])[] requests;
    alias requests this;
}




void thr(){
    try {
    net.udp_bcast.Config netcfg = {
        id :            id,
        port :          feeds_requestConsensusHall_port,
        recvFromSelf :  1,
        bufSize :       feeds_requestConsensus_bufSize,
    };
    Tid netTx = net.udp_bcast.init!(HReqMsg)(thisTid, netcfg);

    subscribe!PeerList;
    subscribe!HallCall;
    subscribe!CompletedHallRequest;


    Req[2][]    requests = new Req[2][](numFloors);
    ubyte[]     peers;

    while(true){
        Duration period = uniform(feeds_requestConsensus_minPeriod, feeds_requestConsensus_maxPeriod).msecs;
        bool timeout = !receiveTimeout(period,
            (HReqMsg a){
                Req[2][] recvdRequests = a.requests;
                debug(request_consensus_hall){
                    bool reqDifference = false;
                    if(recvdRequests != requests){
                        reqDifference = true;
                        writeln("Received different hall request table from id:", a.owner);
                        recvdRequests.print;
                    }
                }

                foreach(int floor, ref requestsAtFloor; requests){
                    foreach(call, ref local; requestsAtFloor){
                    
                    
                        /// --- Merge worldviews (consensus algo) --- ///                        
                        merge(
                            local,
                            recvdRequests[floor][call],
                            id,
                            a.owner,
                            peers,
                            (){
                                publish(ActiveHallRequests(requests.isActive.idup));
                            },
                            (){
                                publish(ActiveHallRequests(requests.isActive.idup));
                            }
                        );
                    }
                }

                debug(request_consensus_hall){
                    if(reqDifference || recvdRequests != requests){
                        writeln("Hall requests updated:");
                        requests.print;
                        writeln;
                    }
                }
            },
            (HallCall a){
                requests[a.floor][a.call].activate(id);
                debug(request_consensus_hall){
                    writeln("New request: ", a.floor, " ", a.call);
                    requests.print;
                    writeln;
                }
            },
            (CompletedHallRequest a){
                requests[a.floor][a.call].deactivate(id, peers);
                debug(request_consensus_hall){
                    writeln("Cleared request: ", a.floor, " ", a.call);
                    requests.print;
                    writeln;
                }
                publish(ActiveHallRequests(requests.isActive.idup));
            },
            (PeerList a){
                peers = a.dup.sort().array;
                
                // if lost all: set inactive to unknown
                if(peers == [id] || peers.empty){
                    foreach(int floor, ref requestsAtFloor; requests){
                        foreach(call, ref req; requestsAtFloor){
                            if(req.state == ReqState.inactive){
                                req.state = ReqState.unknown;
                            }
                        }
                    }
                }
            }
        );
        if(timeout){        
            netTx.send(HReqMsg(id, requests));
        }
    }
    } catch(Throwable t){ t.writeln; throw(t); }
}





private :



struct HReqMsg {
    this(ubyte owner, Req[2][] requests){
        this.owner = owner;

        auto a = new Req[][](requests.length, 2);
        foreach(floor, reqsAtFloor; requests){
            foreach(i, request; reqsAtFloor){
                a[floor][i] = Req(
                    requests[floor][i].state,
                    requests[floor][i].ackdBy.dup
                );
            }
        }
        this._requests = cast(shared)a;
    }

    ubyte owner;
    shared Req[][] _requests;

    Req[2][] requests(){
        auto a = new Req[2][](_requests.length);
        foreach(floor, reqsAtFloor; _requests){
            foreach(i, request; reqsAtFloor){
                a[floor][i] = Req(
                    _requests[floor][i].state,
                    cast(ubyte[])_requests[floor][i].ackdBy
                );
            }
        }
        return a;
    }
}

void print(Req[2][] reqs){
    auto ackdByStrs = reqs.map!(a => a.array.map!(b => format("%s", b.ackdBy.sort())));
    auto maxAckdByStrLens = ackdByStrs.map!(a => a.map!(b => b.length).array).reduce!max;
    auto w = appender!string;
    formattedWrite(w, " Hall\n");
    foreach(floor, a; reqs){
        formattedWrite(w, "  %3d", floor);
        foreach(call, request; a){
            formattedWrite(w, "  |  %10s : %-*s", request.state, maxAckdByStrLens[call], ackdByStrs[floor][call]);
        }
        formattedWrite(w, "\n");
    }
    w.data.writeln;
}


bool[2][] isActive(Req[2][] reqs){
    bool[2][] a = new bool[2][](reqs.length);
    foreach(floor, hreqsAtFloor; reqs){
        foreach(call, order; hreqsAtFloor){
            a[floor][call] = (order.state == ReqState.active);
        }
    }
    return a;
}




















