module feeds.elevator_control;

import std.algorithm;
import std.concurrency;
import std.datetime;
import std.stdio;

import elev_config;
import feed;
import timer_event;

import elevio.elev;
import feeds.request_muxer;
import feeds.elevio_reader;
import fns.elevator_algorithm;
import fns.elevator_state;

struct CompletedHallRequest {
    int             floor;
    HallCallType    call;
}
struct CompletedCabRequest {
    int floor;
    alias floor this;
}



private struct DoorClose {}
private struct DoorCloseTimeout {}
private struct MovementTimeout {}

void thr(){
    try {
    subscribe!FloorSensor;
    subscribe!LocallyAssignedRequests;
    
    ElevatorState e = {
        floor :     -1,
        dirn :      Dirn.stop,
        behaviour : ElevatorBehaviour.uninitialized,
        requests :  new bool[3][](cfg.numFloors),
    };
    
    auto doorTime       = cfg.feeds_elevatorControl_doorOpenDuration.msecs;
    auto maxDoorTime    = 3 * cfg.feeds_elevatorControl_doorOpenDuration.msecs;
    auto maxMoveTime    = 2 * cfg.feeds_elevatorControl_travelTimeEstimate.msecs;
    
    {
        auto floor = floorSensor();
        if(floor == -1){
            e.dirn = Dirn.down;
            motorDirection(e.dirn);            
        } else {
            e.floor = floor;
        }
    }
    publish(e.local);
    
    auto publishCompletedRequest = (CallType c){
        final switch(c) with(CallType){
        case hallUp:
            publish(CompletedHallRequest(e.floor, HallCallType.up));
            break;
        case hallDown:
            publish(CompletedHallRequest(e.floor, HallCallType.down));
            break;
        case cab:
            publish(CompletedCabRequest(e.floor));
            break;
        }
    };
    
    while(true){
        auto prevState = e;
        receive(
            (LocallyAssignedRequests a){
                e.requests = a.dup;                
                final switch(e.behaviour) with(ElevatorBehaviour){
                case uninitialized:
                    break;
                case idle:
                    if(e.anyRequests){
                        if(e.anyRequestsAtFloor){
                            doorLight(true);
                            thisTid.addEvent(doorTime, DoorClose());
                            e.behaviour = doorOpen;
                        } else {
                            e.dirn = e.chooseDirection;
                            motorDirection(e.dirn);
                            e.behaviour = moving;
                            thisTid.addEvent(maxMoveTime, MovementTimeout());
                        }
                    }
                    break;
                case moving:
                    break;
                case doorOpen:
                    if(e.anyRequestsAtFloor){
                        thisTid.deleteEvent(typeid(DoorClose), Delete.all);
                        if(e.error == ElevatorError.movementTimeout){
                            e.error = ElevatorError.none;
                            publish(e.error);
                        }
                        thisTid.addEvent(doorTime, DoorClose());
                        e = e.clearReqsAtFloor(publishCompletedRequest);
                    }
                    break;
                }
            },
            
            (FloorSensor a){
                e.floor = a;
                final switch(e.behaviour) with(ElevatorBehaviour){
                case uninitialized:
                    goto case moving;
                case idle:
                    motorDirection(Dirn.stop);
                    break;
                case moving:
                    thisTid.deleteEvent(typeid(MovementTimeout), Delete.all);
                    if(e.error == ElevatorError.movementTimeout){
                        e.error = ElevatorError.none;
                        publish(e.error);
                    }
                    
                    if(e.shouldStop){
                        motorDirection(Dirn.stop);
                        doorLight(true);
                        e = e.clearReqsAtFloor(publishCompletedRequest);
                        thisTid.addEvent(doorTime, DoorClose());
                        thisTid.addEvent(maxDoorTime, DoorCloseTimeout());
                        e.behaviour = doorOpen;                        
                    } else {                    
                        thisTid.addEvent(maxMoveTime, MovementTimeout());
                    }
                    break;
                case doorOpen:
                    motorDirection(Dirn.stop);
                    break;
                }
            },
            
            (DoorClose a){
                final switch(e.behaviour) with(ElevatorBehaviour){
                case uninitialized:
                    break;
                case idle:
                    break;
                case moving:
                    break;
                case doorOpen:
                    thisTid.deleteEvent(typeid(DoorCloseTimeout), Delete.all);
                    if(e.error == ElevatorError.doorCloseTimeout){
                        e.error = ElevatorError.none;
                        publish(e.error);
                    }
                    
                    doorLight(false);
                    e.dirn = e.chooseDirection;
                    if(e.dirn == Dirn.stop){
                        e.behaviour = idle;
                    } else {
                        motorDirection(e.dirn);
                        e.behaviour = moving;
                        thisTid.addEvent(maxMoveTime, MovementTimeout());
                    }
                    break;
                }
            },
            
            (DoorCloseTimeout a){
                e.error = ElevatorError.doorCloseTimeout;
                publish(e.error);
            },
            
            (MovementTimeout a){
                e.error = ElevatorError.movementTimeout;
                publish(e.error);
            },
        );
        if(e != prevState){
            publish(e.local);
        }
    }
    } catch(Throwable t){ t.writeln; throw(t); }
}