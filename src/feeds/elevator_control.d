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
private struct MovementTimeout {}

void thr(){
    try {
    subscribe!FloorSensor;
    subscribe!LocallyAssignedRequests;
    
    ElevatorState e = {
        floor :     -1,
        dirn :      Dirn.stop,
        behaviour : ElevatorBehaviour.uninitialized,
        requests :  new bool[3][](numFloors),
    };
    auto doorTime = feeds_elevatorControl_doorOpenDuration.msecs;
    auto moveTime = feeds_elevatorControl_travelTimeEstimate.msecs;
    
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
                final switch(e.behaviour) with(ElevatorBehaviour){
                case uninitialized:
                    e.requests = a.dup;
                    break;
                case idle:
                    e.requests = a.dup;
                    if(e.anyRequests){
                        if(e.anyRequestsAtFloor){
                            doorLight(true);
                            thisTid.addEvent(doorTime, DoorClose());
                            e.behaviour = doorOpen;
                        } else {
                            e.dirn = e.chooseDirection;
                            motorDirection(e.dirn);
                            e.behaviour = moving;
                            //thisTid.addEvent(2*moveTime, MovementTimeout());
                        }
                    }
                    break;
                case moving:
                    e.requests = a.dup;
                    break;
                case doorOpen:
                    if(e.anyRequestsAtFloor){
                        thisTid.deleteEvent(typeid(DoorClose), Delete.all);
                        thisTid.addEvent(doorTime, DoorClose());
                        e = e.clearReqsAtFloor(publishCompletedRequest);
                    }
                    break;
                case error:
                    break;
                }
            },
            (FloorSensor a){
                e.floor = a;
                final switch(e.behaviour) with(ElevatorBehaviour){
                case uninitialized:
                    goto case moving;
                case idle:
                    break;
                case moving:
                    //thisTid.deleteEvent(typeid(MovementTimeout), Delete.all);
                    if(e.shouldStop){
                        motorDirection(Dirn.stop);
                        doorLight(true);
                        e = e.clearReqsAtFloor(publishCompletedRequest);
                        thisTid.addEvent(doorTime, DoorClose());
                        e.behaviour = doorOpen;                        
                    } else {                    
                        //thisTid.addEvent(2*moveTime, MovementTimeout());
                    }
                    break;
                case doorOpen:
                    break;
                case error:
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
                    doorLight(false);
                    e.dirn = e.chooseDirection;
                    if(e.dirn == Dirn.stop){
                        e.behaviour = idle;
                    } else {
                        motorDirection(e.dirn);
                        e.behaviour = moving;
                    }
                    break;
                case error:
                    break;
                }
            }
        );
        if(e != prevState){
            publish(e.local);
        }
    }
    } catch(Throwable t){ t.writeln; throw(t); }
}