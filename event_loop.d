import  std.stdio,
        std.concurrency,
        std.algorithm,
        std.range,
        std.conv,
        std.datetime;

import  elevator_driver,
        util.timer_event,
        util.string_to_struct_translator,
        util.timer_event,
        network.udp_p2p,
        types;


public {
    Tid eventLoop_start(){
        Tid t = spawn( &eventLoop );
        receive((types.initDone id){});
        return t;
    }
}
    
private {

/// ----- DEPENDENCIES ----- ///
    Tid         timerEventTid;
    Tid         stringToStructTranslatorTid;
    Tid         networkTid;
    //Elevator    elevator;
    int         numFloors;
    Tid         elevatorEventsTid;


    /// ----- CONSTANTS ----- ///
    immutable   doorClose       = "doorClose";
    immutable   doorOpenTime    = 3.seconds;
 
 
    /// ----- VARIABLES ----- ///
    ExternalOrder[][]       externalOrders;
    ElevatorState[ubyte]    states;
    ubyte[]                 alivePeers;
    int                     maxFloor;
    int                     minFloor;
    


    


    void eventLoop(){
        scope(exit){ writeln(__FUNCTION__, " has died"); }
try {
        // Dependencies //
        timerEventTid                   = spawn( &timerEvent_thr );
        stringToStructTranslatorTid     = spawn( &stringToStructTranslator_thr!(
            ElevatorStateWrapper
        ) );
        networkTid                      = udp_p2p_start(stringToStructTranslatorTid);
        auto elevator                   = new SimulationElevator;
        minFloor = elevator.minFloor;
        maxFloor = elevator.maxFloor;
        numFloors                       = maxFloor - minFloor + 1;
        elevatorEventsTid               = elevatorEvents_start(elevator);

        // Variables //
        externalOrders = new ExternalOrder[][](numFloors, 2);
        
        


        writeln("Event loop started");

    
        /// ----- INIT PHASE ----- ///
        states[thisPeerID] = uninitializedElevatorState;
        // TODO: get state from other elevators
        //   send request, send new timer event (100ms?)
        //   wait until timer event, deduce previous state
    
    
    
    
    
    
    
        ownerTid.send(types.initDone());
        while(true){
            receive(
                // --- FROM ELEVATOR --- //
                (btnPressEvent bpe){
                    final switch(bpe.btn) with(ButtonType){
                    case UP:
                        break;
                    case DOWN:
                        break;
                    case COMMAND:
                        states[thisPeerID].internalOrders[bpe.floor] = true;
                        break;
                    }
                    networkTid.send(wrappedState);
                    if(getThisState.isIdle){
                        timerEventTid.send(thisTid, doorClose, 0.seconds);
                        elevator.SetMotorDirection(getThisState.chooseDirn);
                    }
                },
                (newFloorEvent nfe){
                    if(getThisState.shouldStop(nfe)){
                        elevator.SetMotorDirection(MotorDirection.STOP);
                        timerEventTid.send(thisTid, doorClose, doorOpenTime);
                        elevator.SetLight!"on"(Light.DOOR_OPEN);
                    }
                },
                
                // --- FROM NETWORK (from string to struct translator) --- //
                (OrderMsg om){
                },
                (peerListUpdate plu){
                    alivePeers = plu.peers.dup;
                },
                (ElevatorStateWrapper essw){
                    states[essw.belongsTo] = ElevatorState(essw.content);
                },
                (StateRestoreRequest srr){
                    networkTid.send(
                        StateRestoreInfo(
                            srr.askerID,
                            states.get(srr.askerID, ElevatorState.init).to!string
                        )
                        .to!string
                    );
                },
                
                // --- FROM TIMER --- //
                (Tid t, string s){
                    if(t == timerEventTid){
                        // --- order ack timeout --- //
                        // --- door close --- //
                        if(s == doorClose  &&  !getThisState.orders.map!any.any){
                            //elevator.SetLight!"off"(Light.DOOR_OPEN);
                            
                        }
                    }
                },
                (Variant v){
                    writeln("Event loop received unknown type: ", v.type, "\n    ", v);
                }
            );
        }
} catch(Throwable t){ t.writeln; throw t; }
    }
    
    
    
    
    /// ----- FUNCTIONS ----- ///
    
    
    string wrappedState(){
        return ElevatorStateWrapper(
            states[thisPeerID].to!string,
            thisPeerID
        ).to!string;
    }
    
    
    ElevatorState uninitializedElevatorState(){
        return ElevatorState(
            -1,
            MotorDirection.STOP,
            false,
            new bool[](numFloors)
        );
    }
    
    GeneralizedElevatorState generalize(ElevatorState state, ubyte ID, ExternalOrder[][] externalOrders){
        return GeneralizedElevatorState(
            state.floor,
            state.dirn,
            state.moving,
            
            externalOrders
            .map!(ordersAtFloor => 
                ordersAtFloor
                .map!(order => 
                    order.active  &&  
                    order.assignedID == ID
                )
                .array
            )
            .zip(state.internalOrders)
            .map!(a => a[0] ~ a[1])
            .array,
            
            ID
        );
    }
    
    GeneralizedElevatorState[] generalize(ElevatorState[ubyte] states, ExternalOrder[][] externalOrders){
        return
        states.values.zip(states.keys)
        .map!(a =>
            a[0].generalize(a[1], externalOrders)
        )
        .array;
    }
    
    GeneralizedElevatorState getThisState(){
        return states[thisPeerID].generalize(thisPeerID, externalOrders);
    }
    
    bool shouldStop(GeneralizedElevatorState state, int floor){
        
        final switch(state.dirn) with(MotorDirection){
        case UP:
            auto floorOfTopOrder = (state.orders.length.to!int - 1 - state.orders.map!any.retro.countUntil(true));
            return  floorOfTopOrder == state.floor  ||  
                    state.floor == maxFloor  ||
                    state.orders[floor][ButtonType.UP]  ||  
                    state.orders[floor][ButtonType.COMMAND];
        case DOWN:
            auto floorOfBottomOrder = state.orders.map!any.countUntil(true);
            return  floorOfBottomOrder == state.floor  ||  
                    state.floor == minFloor  ||
                    state.orders[floor][ButtonType.DOWN]  ||  
                    state.orders[floor][ButtonType.COMMAND];
        case STOP:
            return  true;
        }
    }
    
    bool isIdle(GeneralizedElevatorState state){
        return !state.moving  &&  state.dirn == MotorDirection.STOP;
    }
    
    MotorDirection chooseDirn(GeneralizedElevatorState state){
        auto ordersAbove = state.orders[state.floor+1..$].map!any.any;
        auto ordersBelow = state.orders[0..state.floor].map!any.any;
        final switch(state.dirn) with(MotorDirection){
        case UP:
            if(ordersAbove  &&  state.floor != maxFloor){
                return UP;
            } else {
                return DOWN;                
            }
        case DOWN:
            if(ordersBelow  &&  state.floor != minFloor){
                return DOWN;
            } else {
                return UP;                
            }
        case STOP:
            if(ordersAbove){
                return UP;
            } else if(ordersBelow){
                return DOWN;
            } else {
                return STOP;
            }            
        }
    }    
}
/+
button press
new floor

order msg
ack timeout
order integrity check (random interval)

peer list update
state update
state restore request

door close

random time
+/
