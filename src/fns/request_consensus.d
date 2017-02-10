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
    final switch(local.state) with(ReqState){
    case unknown:
        // Local state 'unknown':
        //      Assume remote state (as long as it too is not unknown)
        if(remoteId != localId){
            final switch(remote.state){
            case unknown:
                break;
            case inactive:
                local.state = inactive;
                local.ackdBy.destroy;
                break;
            case pendingAck:
                local.state = pendingAck;
                local.ackdBy = remote.ackdBy ~ [localId];
                break;
            case active:
                local.state = active;
                local.ackdBy = remote.ackdBy ~ [localId];
                onActive();
                break;
            }
        }
        break;
        
    case inactive:
        // Local state 'inactive':
        //      Move to pendingAck if remote says so
        final switch(remote.state){
        case unknown:
            break;
        case inactive:
            break;
        case pendingAck:
            local.state = pendingAck;
            local.ackdBy = remote.ackdBy ~ [localId];
            break;
        case active:
            break;
        }
        break;
        
    case pendingAck:
        // Local state 'pendingAck':
        //      Move to active if all have ackd, or remote says all have ackd
        final switch(remote.state){
        case unknown:
            break;
        case inactive:
            break;
        case pendingAck:
            local.ackdBy ~= remote.ackdBy ~ [localId];
            // (technically "if all or more have ackd", in case of lost peers)
            if(setDifference(peers, local.ackdBy.sort()).empty){
                local.state = active;
                onActive();
            }
            break;
        case active:
            local.state = active;
            local.ackdBy ~= remote.ackdBy ~ [localId];
            onActive();
            break;
        }
        break;
        
    case active:
        // Local state 'active':
        //      Move to inactive if remote says so
        final switch(remote.state){
        case unknown:
            break;
        case inactive:
            local.state = inactive;
            local.ackdBy.destroy;
            onInactive();
            break;
        case pendingAck:
            break;
        case active:
            local.ackdBy ~= remote.ackdBy ~ [localId];
            break;
        }
        break;
    }
    local.ackdBy = local.ackdBy.sort().uniq.array;
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
