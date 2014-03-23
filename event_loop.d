import  std.stdio,
        std.concurrency,
        std.algorithm,
        std.range,
        std.conv,
        std.array,
        std.random,
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
    Elevator    elevator;
    Tid         elevatorEventsTid;


    /// ----- CONSTANTS ----- ///
    auto        doorClose               = "doorClose";
    auto        reassignUnlinkedOrders  = "reassignUnlinkedOrders";
    auto        doorOpenTime            = 3.seconds;
    auto        ackTimeout              = 50.msecs;


    /// ----- VARIABLES ----- ///
    ExternalOrder[][]       externalOrders;
    ElevatorState[ubyte]    states;
    ubyte[]                 alivePeers;






    void eventLoop(){
        scope(exit){ writeln(__FUNCTION__, " has died"); }
try {
        // Dependencies //
        timerEventTid                   = spawn( &timerEvent_thr );
        stringToStructTranslatorTid     = spawn( &stringToStructTranslator_thr!(
            ElevatorStateWrapper,
            OrderMsg,
            StateRestoreRequest,
            StateRestoreInfo
        ) );
        networkTid                      = udp_p2p_start(stringToStructTranslatorTid);
//        elevator                        = new SimulationElevator(RandomStart.yes);
        elevator                        = new ComediElevator;
        elevatorEventsTid               = elevatorEvents_start(elevator);

        // Variables //
        externalOrders = new ExternalOrder[][](numFloors, 2);


        writeln("Event loop started");


        /// ----- INIT PHASE ----- ///
        states[thisPeerID] = uninitializedElevatorState;
        // send request, send new timer event (100ms?)
        // wait until timer event, deduce previous state
        // Currently: Do logical or whenever StateRestoreInfo arrives
        networkTid.send(StateRestoreRequest(thisPeerID).to!string);
        
        if(elevator.ReadFloorSensor == -1){
            elevator.SetMotorDirection(MotorDirection.DOWN);
        }
        
        timerEventTid.send(thisTid, reassignUnlinkedOrders, 5.seconds);



        ownerTid.send(types.initDone());
        while(true){
            receive(
                (StateRestoreInfo sri){
                    if(sri.belongsTo == thisPeerID){
                        writeln("  GOT STATE RESTORE INFO: ", sri);
                        auto prevState = ElevatorState(sri.stateString);
                        if(prevState.internalOrders.length == states[thisPeerID].internalOrders.length){
                            states[thisPeerID].internalOrders = 
                                states[thisPeerID].internalOrders.zip(prevState.internalOrders)
                                .map!(a => a[0] || a[1])
                                .array;
                            foreach(floor, a; states[thisPeerID].internalOrders){
                                if(a){
                                    elevator.SetLight(floor.to!int, Light.COMMAND, true);
                                }
                            }
                        }
                    }
                },
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
                        elevator.SetLight(bpe.floor, Light.COMMAND, true);
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
                            elevator.SetLight(Light.DOOR_OPEN, false);
                            elevator.SetLight(bpe.floor, Light.COMMAND, false);
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
                        elevator.SetLight(Light.DOOR_OPEN, true);
                        elevator.SetLight(nfe, Light.COMMAND, false);
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
                        elevator.SetLight(om.floor, cast(Light)om.btn, true);

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
                            elevator.SetLight(Light.DOOR_OPEN, true);
                            elevator.SetLight(om.floor, Light.COMMAND, false);
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
                        elevator.SetLight(om.floor, cast(Light)om.btn, false);
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
                    if(srr.askerID == thisPeerID){
                        return;
                    }
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
                        // --- door close --- //
                        if(s == doorClose){
                            writeln("  New timer event: ", doorClose);
                            if(!getThisState.hasOrders){
                                states[thisPeerID].moving = false;
                                states[thisPeerID].dirn = MotorDirection.STOP;
                            } else/+ if(getThisState.isIdle)+/{
                                states[thisPeerID].dirn = getThisState.chooseDirn;
                                elevator.SetMotorDirection(states[thisPeerID].dirn);
                                if(states[thisPeerID].dirn != MotorDirection.STOP){
                                    elevator.SetLight(Light.DOOR_OPEN, false);
                                    states[thisPeerID].moving = true;
                                } else {
                                    elevator.SetLight(states[thisPeerID].floor, Light.COMMAND, false);
                                    clearOrders(states[thisPeerID].floor);
                                }
                            }
                            networkTid.send(wrappedState);
                            return;
                        }
                        // --- order ack timeout --- //
                        if(s.skipOver("ack")){
                            networkTid.send(OrderMsg(
                                thisPeerID,
                                s.parse!int,
                                s.parse!ButtonType,
                                thisPeerID,
                                thisPeerID,
                                MessageType.newOrder
                            ).to!string);
                            return;
                        }
                        // --- Order reassignment & data integrity checker --- //
                        if(s == reassignUnlinkedOrders){
                            foreach(floor, row; externalOrders){
                                foreach(btn, order; row){
                                    if(order.active  &&  !alivePeers.canFind(order.assignedID)){
                                        networkTid.send(OrderMsg(
                                            states
                                                .filterAlive(alivePeers)
                                                .generalize(externalOrders)
                                                .augment(btnPressEvent(cast(ButtonType)btn, floor.to!int))
                                                .bestFit,
                                            floor.to!int,
                                            cast(ButtonType)btn,
                                            thisPeerID,
                                            thisPeerID,
                                            MessageType.newOrder
                                        ).to!string);
                                    }
                                }
                            }
                            timerEventTid.send(thisTid, reassignUnlinkedOrders, uniform(3,8).seconds);
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
        .filter!(a => (alivePeers.canFind(a[0])  ||  a[0] == thisPeerID))
        .assocArray;
    }

    void clearOrders(int floor){
        states[thisPeerID].internalOrders[floor] = false;
        final switch(states[thisPeerID].dirn) with(MotorDirection) {
        case UP:
            if(externalOrders[floor][UP].active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            if(!getThisState.ordersAbove  &&  externalOrders[floor][DOWN].active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            break;
        case DOWN:
            if(externalOrders[floor][DOWN].active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            if(!getThisState.ordersBelow  &&  externalOrders[floor][UP].active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            break;
        case STOP:
            if(externalOrders[floor][UP].active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            if(externalOrders[floor][DOWN].active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
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
            return  /+floorOfTopOrder == state.floor  ||+/
                    !state.ordersAbove  ||
                    state.floor == elevator.maxFloor  ||
                    state.orders[floor][ButtonType.UP]  ||
                    state.orders[floor][ButtonType.COMMAND];
        case DOWN:
            auto floorOfBottomOrder = state.orders.map!any.countUntil(true);
            return  /+floorOfBottomOrder == state.floor  ||+/
                    !state.ordersBelow  ||
                    state.floor == elevator.minFloor  ||
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
            if(state.ordersAbove  &&  state.floor != elevator.maxFloor){
                return UP;
            } else {
                return DOWN;
            }
        case DOWN:
            if(state.ordersBelow  &&  state.floor != elevator.minFloor){
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
    
    int numFloors(){
        return elevator.maxFloor - elevator.minFloor + 1;
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
