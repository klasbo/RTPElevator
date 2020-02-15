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



void thr(){
    try {
    subscribe!FloorSensor;
    subscribe!LocallyAssignedRequests;
    
    auto motorTid = spawnLinked(&motorStateThr);
    auto doorTid  = spawnLinked(&doorStateThr);
    
    ElevatorState e = {
        floor :     -1,
        dirn :      Dirn.stop,
        behaviour : ElevatorBehaviour.uninitialized,
        requests :  new bool[3][](cfg.numFloors),
    };
    
    
    {
        auto floor = floorSensor();
        if(floor == -1){
            e.dirn = Dirn.down;
            motorDirection(e.dirn);            
        } else {
            e.floor = floor;
            e.behaviour = ElevatorBehaviour.idle;
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
                case uninitialized, moving:
                    break;
                case idle:
                    if(e.anyRequests){
                        if(e.anyRequestsAtFloor){
                            doorTid.send(OpenDoor());
                            e.behaviour = doorOpen;
                        } else {
                            e.dirn = e.chooseDirection;
                            motorTid.send(e.dirn);
                            e.behaviour = moving;
                        }
                    }
                    break;
                case doorOpen:
                    if(e.anyRequestsAtFloor){
                        doorTid.send(OpenDoor());
                        e = e.clearReqsAtFloor(publishCompletedRequest);
                    }
                    break;
                }
            },
            
            (FloorSensor a){
                motorTid.send(a);
                e.floor = a;
                
                final switch(e.behaviour) with(ElevatorBehaviour){
                case idle, doorOpen:
                    motorTid.send(Dirn.stop);
                    break;                    
                case uninitialized, moving:                    
                    if(e.shouldStop){
                        motorTid.send(Dirn.stop);
                        doorTid.send(OpenDoor());
                        e = e.clearReqsAtFloor(publishCompletedRequest);
                        e.behaviour = doorOpen;                        
                    }
                    break;
                }
            },
            
            (DoorClose a){
                final switch(e.behaviour) with(ElevatorBehaviour){
                case uninitialized, idle, moving:
                    break;
                case doorOpen:
                    e.dirn = e.chooseDirection;
                    if(e.dirn == Dirn.stop){
                        e.behaviour = idle;
                    } else {
                        motorTid.send(e.dirn);
                        e.behaviour = moving;
                    }
                    break;
                }
            },
            
            (DoorError a){
                e.error = (a ? ElevatorError.doorCloseTimeout : ElevatorError.none);
                publish(e.error);
            },
            
            (MovementError a){
                e.error = (a ? ElevatorError.movementTimeout : ElevatorError.none);
                publish(e.error);
            },
            
            (LinkTerminated a){
                throw a;
            }
        );
        if(e != prevState){
            publish(e.local);
        }
    }
    } catch(Throwable t){ t.writeln; throw(t); }
}


private struct OpenDoor {}
private struct DoorClose {}
private struct DoorCloseTimeout {}
private struct DoorError {
    bool error;
    alias error this;
}

private void doorStateThr(){
    bool quit = false;
    auto doorOpenTime = cfg.feeds_elevatorControl_doorOpenDuration.msecs;
    auto maxDoorTime = 2 * doorOpenTime;
    
    bool doorOpen = false;
    bool error = false;
    
    while(!quit){
        receive(
            (OpenDoor a){
                if(doorOpen == false){
                    doorOpen = true;
                    doorLight(doorOpen);
                    thisTid.addEvent(doorOpenTime, DoorClose());
                    thisTid.addEvent(maxDoorTime, DoorCloseTimeout());
                } else {
                    thisTid.deleteEvent(typeid(DoorClose), Delete.all);
                    thisTid.addEvent(doorOpenTime, DoorClose());
                }
            },
            (DoorClose a){
                thisTid.deleteEvent(typeid(DoorCloseTimeout), Delete.all);
                doorOpen = false;
                doorLight(doorOpen);
                ownerTid.send(a);
                if(error){
                    error = false;
                    ownerTid.send(DoorError(error));
                }
            },
            (DoorCloseTimeout a){
                error = true;
                ownerTid.send(DoorError(error));
            },
            (OwnerTerminated a){
                quit = true;
            }
        );
    }
}


private struct MovementTimeout {}
private struct MovementError {
    bool error;
    alias error this;
}

private void motorStateThr(){
    bool quit = false;
    auto maxMoveTime = 2 * cfg.feeds_elevatorControl_travelTimeEstimate.msecs;
    
    Dirn dirn;
    bool error = false;
    
    while(!quit){
        receive(
            (Dirn a){
                if(dirn != a){
                    dirn = a;
                    motorDirection(dirn);
                    if(dirn == Dirn.stop){
                        thisTid.deleteEvent(typeid(MovementTimeout), Delete.all);
                    } else {
                        thisTid.addEvent(maxMoveTime, MovementTimeout());
                    }
                }
            },
            (FloorSensor a){
                thisTid.deleteEvent(typeid(MovementTimeout), Delete.all);
                thisTid.addEvent(maxMoveTime, MovementTimeout());
                if(error == true){
                    error = false;
                    send(ownerTid, MovementError(error));
                }   
            },
            (MovementTimeout a){
                error = true;
                send(ownerTid, MovementError(error));
            },
            (OwnerTerminated a){
                quit = true;
            }
        );
    }
}




















