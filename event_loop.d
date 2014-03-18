import  std.stdio,
        std.concurrency,
        std.algorithm,
        std.range,
        std.conv,
        std.array,
        std.datetime;

import  elevator_driver,
        util.timer_event,
        util.string_to_struct_translator,
        util.timer_event,
        network.udp_p2p,
        types,
        best_fit;


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
    auto        doorClose       = "doorClose";
    auto        doorOpenTime    = 3.seconds;
    auto        ackTimeout      = 100.msecs;


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
            ElevatorStateWrapper,
            OrderMsg
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
                // --- FROM ELEVATOR HARDWARE --- //
                (btnPressEvent bpe){
                    writeln("  New button press: ", bpe);
                    final switch(bpe.btn) with(ButtonType){
                    case UP, DOWN:
                        if(externalOrders[bpe.floor][bpe.btn].active){
                            break;
                        }
                        networkTid.send(OrderMsg(
                            states
                                .filterAlive(alivePeers)
                                .generalize(externalOrders)
                                .augment(bpe)
                                .bestFit,
                            bpe.floor,
                            bpe.btn,
                            thisPeerID,
                            thisPeerID,
                            MessageType.newOrder
                        ).to!string);
                        timerEventTid.send(thisTid, ack(bpe.floor, bpe.btn), ackTimeout);
                        break;
                    case COMMAND:
                        states[thisPeerID].internalOrders[bpe.floor] = true;
                        elevator.SetLight!"on"(bpe.floor, Light.COMMAND);
                        if(getThisState.isIdle){
                            timerEventTid.send(thisTid, doorClose, 0.seconds);
                            states[thisPeerID].dirn = getThisState.chooseDirn;
                            if(states[thisPeerID].dirn != MotorDirection.STOP){
                                states[thisPeerID].moving = true;
                            }
                            elevator.SetMotorDirection(getThisState.chooseDirn);
                        } else if(  !getThisState.moving  &&  
                                    getThisState.floor == bpe.floor  &&
                                    getThisState.shouldStop(bpe.floor))
                        {
                            elevator.SetMotorDirection(MotorDirection.STOP);
                            states[thisPeerID].moving = false;
                            timerEventTid.send(thisTid, doorClose, doorOpenTime);
                            elevator.SetLight!"on"(Light.DOOR_OPEN);
                            elevator.SetLight!"off"(bpe.floor, Light.COMMAND);
                            clearOrders(bpe.floor);
                        }
                        break;                        
                    }
                    networkTid.send(wrappedState);
                },
                (newFloorEvent nfe){
                    writeln("  New floor: ", nfe);
                    states[thisPeerID].floor = nfe;
                    if(getThisState.shouldStop(nfe)){
                        elevator.SetMotorDirection(MotorDirection.STOP);
                        states[thisPeerID].moving = false;
                        timerEventTid.send(thisTid, doorClose, doorOpenTime);
                        elevator.SetLight!"on"(Light.DOOR_OPEN);
                        elevator.SetLight!"off"(nfe, Light.COMMAND);
                        clearOrders(nfe);
                    }
                    networkTid.send(wrappedState);
                },

                // --- FROM NETWORK (from string to struct translator) --- //
                (OrderMsg om){
                    writeln("  New order message: ", om);
                    final switch(om.msgType) with(MessageType){
                    case newOrder:
                        // add to externalOrders
                        externalOrders[om.floor][om.btn].pending = true;
                        externalOrders[om.floor][om.btn].active = false;
                        externalOrders[om.floor][om.btn].assignedID = om.assignedID;
                        externalOrders[om.floor][om.btn].hasConfirmed.clear;
                        // reply with ackOrder from this
                        networkTid.send(OrderMsg(
                            om.assignedID,
                            om.floor,
                            om.btn,
                            om.orderOriginID,
                            thisPeerID,
                            MessageType.ackOrder
                        ).to!string);
                        break;
                        
                    case ackOrder:
                        if(!externalOrders[om.floor][om.btn].pending){
                            break;
                        }
                        externalOrders[om.floor][om.btn].hasConfirmed ~= om.msgOriginID;
                        // if origin = this
                        //   send confirmedOrder
                        if( om.orderOriginID == thisPeerID  &&  
                            alivePeers
                            .sort
                            .setDifference(externalOrders[om.floor][om.btn].hasConfirmed.sort)
                            .empty)
                        {
                            networkTid.send(OrderMsg(
                                om.assignedID,
                                om.floor,
                                om.btn,
                                om.orderOriginID,
                                thisPeerID,
                                MessageType.confirmedOrder
                            ).to!string);
                            timerEventTid.send(thisTid, ack(om.floor, om.btn), cancel);
                        }
                        break;
                        
                    case confirmedOrder:
                        // set light on
                        externalOrders[om.floor][om.btn].pending = false;
                        externalOrders[om.floor][om.btn].active = true;
                        if(externalOrders[om.floor][om.btn].assignedID != om.assignedID){
                            writeln("  confirmedOrder.assignedID != externalOrders.assignedID!\n",
                                    "    ", om, "\n    ", externalOrders[om.floor][om.btn]);
                        }
                        elevator.SetLight!"on"(om.floor, cast(Light)om.btn);
                        
                        // start elevator if idle
                        if(getThisState.isIdle){
                            timerEventTid.send(thisTid, doorClose, 0.seconds);
                            states[thisPeerID].dirn = getThisState.chooseDirn;
                            if(states[thisPeerID].dirn != MotorDirection.STOP){
                                states[thisPeerID].moving = true;
                            }
                            elevator.SetMotorDirection(getThisState.chooseDirn);
                        } else if(  !getThisState.moving  &&  
                                    getThisState.floor == om.floor  &&
                                    getThisState.shouldStop(om.floor))
                        {
                            elevator.SetMotorDirection(MotorDirection.STOP);
                            states[thisPeerID].moving = false;
                            timerEventTid.send(thisTid, doorClose, doorOpenTime);
                            elevator.SetLight!"on"(Light.DOOR_OPEN);
                            elevator.SetLight!"off"(om.floor, Light.COMMAND);
                            clearOrders(om.floor);
                        }
                        break;
                        
                    case completedOrder:
                        // remove from externalOrders
                        externalOrders[om.floor][om.btn].pending = false;
                        externalOrders[om.floor][om.btn].active = false;
                        externalOrders[om.floor][om.btn].assignedID = 0;
                        externalOrders[om.floor][om.btn].hasConfirmed.clear;
                        // set light off
                        elevator.SetLight!"off"(om.floor, cast(Light)om.btn);
                        break;
                    }
                },
                (Tid discard, peerListUpdate plu){
                    writeln("  New peer list:", plu);
                    alivePeers = plu.peers.dup;
                },
                (ElevatorStateWrapper essw){
                    writeln("  New elevator state: ", essw);
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
                        writeln("  New timer event: ", s);
                        // --- order ack timeout --- //
                        // --- door close --- //
                        if(s == doorClose){
                            writeln("Closing door with: ", getThisState);
                            if(!getThisState.hasOrders){
                                states[thisPeerID].moving = false;
                                states[thisPeerID].dirn = MotorDirection.STOP;
                            } else/+ if(getThisState.isIdle)+/{
                                states[thisPeerID].dirn = getThisState.chooseDirn;
                                elevator.SetMotorDirection(states[thisPeerID].dirn);
                                if(states[thisPeerID].dirn != MotorDirection.STOP){
                                    elevator.SetLight!"off"(Light.DOOR_OPEN);
                                    states[thisPeerID].moving = true;
                                } else {
                                    elevator.SetLight!"off"(states[thisPeerID].floor, Light.COMMAND);
                                    clearOrders(states[thisPeerID].floor);
                                }
                            }
                            networkTid.send(wrappedState);
                        } else if(s.skipOver("ack")){
                            networkTid.send(OrderMsg(
                                thisPeerID,
                                s.parse!int,
                                s.parse!ButtonType,
                                thisPeerID,
                                thisPeerID,
                                MessageType.newOrder
                            ).to!string);
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

    ElevatorState[ubyte] filterAlive(ElevatorState[ubyte] states, ubyte[] alivePeers){
        return
        states.keys.zip(states.values)
        .filter!(a => alivePeers.canFind(a[0]))
        .assocArray;
    }
    
    void clearOrders(int floor){
        writeln("Clearing orders at floor ", floor);
        states[thisPeerID].internalOrders[floor] = false;
        final switch(states[thisPeerID].dirn) with(MotorDirection) {
        case UP:
            if(externalOrders[floor][UP].active){
                networkTid.send(OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder).to!string);
            }
            if(!getThisState.ordersAbove  &&  externalOrders[floor][DOWN].active){
                networkTid.send(OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder).to!string);
            }
            break;
        case DOWN:
            if(externalOrders[floor][DOWN].active){
                networkTid.send(OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder).to!string);
            }
            if(!getThisState.ordersBelow  &&  externalOrders[floor][UP].active){
                networkTid.send(OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder).to!string);
            }
            break;
        case STOP:
            if(externalOrders[floor][UP].active){
                networkTid.send(OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder).to!string);
            }
            if(externalOrders[floor][DOWN].active){
                networkTid.send(OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder).to!string);
            }
            break;
        }
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

    GeneralizedElevatorState[] augment(GeneralizedElevatorState[] states, btnPressEvent bpe){
        bool[][] b;
        return
        states
        .map!(a => 
            GeneralizedElevatorState(
                a.floor,
                a.dirn,
                a.moving,
                ( b = a.orders.map!(a=>a.dup).array, 
                  b[bpe.floor][bpe.btn] = true, 
                  b),
                a.ID
            )
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

    bool ordersAbove(GeneralizedElevatorState state){
        return state.orders[state.floor+1..$].map!any.any;
    }

    bool ordersBelow(GeneralizedElevatorState state){
        return state.orders[0..state.floor].map!any.any;
    }

    bool isIdle(GeneralizedElevatorState state){
        return !state.moving  &&  state.dirn == MotorDirection.STOP;
    }

    bool hasOrders(GeneralizedElevatorState state){
        return state.orders.map!any.any;
    }

    MotorDirection chooseDirn(GeneralizedElevatorState state){
        if(!state.hasOrders){
            return MotorDirection.STOP;
        }
        final switch(state.dirn) with(MotorDirection){
        case UP:
            if(state.ordersAbove  &&  state.floor != maxFloor){
                return UP;
            } else {
                return DOWN;
            }
        case DOWN:
            if(state.ordersBelow  &&  state.floor != minFloor){
                return DOWN;
            } else {
                return UP;
            }
        case STOP:
            if(state.ordersAbove){
                return UP;
            } else if(state.ordersBelow){
                return DOWN;
            } else {
                return STOP;
            }
        }
    }

    string ack(int floor, ButtonType btn){
        return "ack" ~ floor.to!string ~ btn.to!string;
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
