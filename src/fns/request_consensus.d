module fns.request_consensus;

import std.algorithm;
import std.array;
import std.stdio;

enum ReqState {
    unknown,
    inactive,
    pendingAck,
    active
}

struct Req {
    ReqState state;
    ubyte[] ackdBy;
}


void merge(
    ref Req local,
    Req remote,
    ubyte localId,
    ubyte remoteId,
    ubyte[] peers,
    void delegate() onActive,
    void delegate() onInactive
){
    ubyte[] appendUniq(ubyte[] a, ubyte b){
        return (a ~ b).sort().uniq.array;
    }

    Req assumeRemote(Req local, Req remote){
        final switch(remote.state) with(ReqState){
        case unknown:       return local;
        case inactive:      return Req(inactive,    []);
        case pendingAck:    return Req(pendingAck,  appendUniq(remote.ackdBy, localId));
        case active:        return Req(active,      appendUniq(remote.ackdBy, localId));
        }
    }

    final switch(local.state) with(ReqState){
    case unknown:
        // Local state 'unknown':
        //      Assume remote state (as long as it too is not unknown)
        //      (Old states from localID may still live on the network, ignore these)
        if(remoteId != localId){
            local = assumeRemote(local, remote);
            if(local.state == active){
                onActive();
            }
        }
        break;
        
    case inactive:
        // Local state 'inactive':
        //      Move to pendingAck if remote says so
        final switch(remote.state){
        case pendingAck:
            local = assumeRemote(local, remote);
            break;
        case unknown, inactive, active:
            break;
        }
        break;
        
    case pendingAck:
        // Local state 'pendingAck':
        //      Move to active if all have ackd, or remote says all have ackd
        final switch(remote.state){
        case unknown, inactive:
            break;
        case pendingAck:
            local = assumeRemote(local, remote);
            // (technically "if all or more have ackd", in case of lost peers)
            if(setDifference(peers, local.ackdBy.sort()).empty){
                local.state = active;
                onActive();
            }
            break;
        case active:
            local = assumeRemote(local, remote);
            onActive();
            break;
        }
        break;
        
    case active:
        // Local state 'active':
        //      Move to inactive if remote says so
        //      Append peers if remote also active
        final switch(remote.state){
        case unknown, pendingAck:
            break;
        case inactive:
            local = assumeRemote(local, remote);
            onInactive();
            break;
        case active:
            local = assumeRemote(local, remote);
            break;
        }
        break;
    }
}

void activate(ref Req local, ubyte localId){
    final switch(local.state) with(ReqState){
    case unknown, inactive:
        local.state = pendingAck;
        local.ackdBy = [localId];
        break;
    case pendingAck, active:
        // Do not add existing request
        break;
    }
}

void deactivate(ref Req local, ubyte localId, ubyte[] peers){
    if(peers == [localId]){
        local.state = ReqState.unknown;
    } else {
        local.state = ReqState.inactive;
    }
    local.ackdBy.destroy;
}
