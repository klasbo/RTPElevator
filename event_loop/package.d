module event_loop;

import  std.algorithm,
        std.concurrency,
        std.conv,
        std.datetime,
        std.file,
        std.getopt,
        std.random,
        std.range,
        std.stdio;

import  elevator_driver,
        event_loop.free_funcs,
        event_loop.types,
        network.udp_p2p,
        util.string_to_struct_translator,
        util.timer_event;


public {
    Tid eventLoop_start(){
        Tid t = spawn( &eventLoop );
        receive((event_loop.types.initDone id){});
        return t;
    }
}


shared static this(){
    string[] configContents;
    try {
        configContents = readText("ElevatorConfig.con").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "eventLoop_elevatorType",           &elevatorType,
            "eventLoop_doorOpenTime_ms",        &doorOpenTime_ms,
            "eventLoop_ackTimeout_ms",          &ackTimeout_ms,
            "eventLoop_reassignMinTime_s",      &reassignMinTime_s,
            "eventLoop_reassignMaxTime_s",      &reassignMaxTime_s
        );
    } catch(Exception e){
        writeln("Unable to load eventLoop config: ", e.msg);
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
    immutable   doorClose               = "doorClose";
    immutable   reassignUnlinkedOrders  = "reassignUnlinkedOrders";

    /// ----- VARIABLES ----- ///
    ExternalOrder[][]       externalOrders;
    ElevatorState[ID_t]     states;
    ID_t[]                  alivePeers;

    /// ----- CONFIG ----- ///
    shared uint     reassignMinTime_s   = 3;
    shared uint     reassignMaxTime_s   = 7;
    shared uint     doorOpenTime_ms     = 3000;
    shared uint     ackTimeout_ms       = 50;
    enum ElevatorType {
        simulation,
        comedi
    }
    shared          elevatorType        = ElevatorType.simulation;





    void eventLoop(){
        scope(exit){ writeln(__FUNCTION__, " has died"); }
        try {

        timerEventTid                   = spawn( &timerEvent_thr );
        stringToStructTranslatorTid     = spawn( &stringToStructTranslator_thr!(
            ElevatorStateWrapper,
            OrderMsg,
            StateRestoreRequest,
            StateRestoreInfo
        ) );
        networkTid                      = udp_p2p_start(stringToStructTranslatorTid);
        final switch(elevatorType) with(ElevatorType){
        case simulation:
            elevator                    = new SimulationElevator(RandomStart.yes); break;
        case comedi:
            elevator                    = new ComediElevator; break;
        }
        elevatorEventsTid               = elevatorEvents_start(elevator);

        externalOrders                  = new ExternalOrder[][](elevator.numFloors, 2);
        states[thisPeerID]              = uninitializedElevatorState(elevator.numFloors);


        auto    doorOpenTime    = doorOpenTime_ms.msecs;
        auto    ackTimeout      = ackTimeout_ms.msecs;






        writeln("Event loop started");

        if(elevator.ReadFloorSensor == -1){
            elevator.SetMotorDirection(MotorDirection.DOWN);
            states[thisPeerID].moving = true;
        }

        networkTid.send(StateRestoreRequest(thisPeerID).to!string);
        timerEventTid.send(thisTid, reassignUnlinkedOrders, reassignMaxTime_s.seconds);
        ownerTid.send(event_loop.types.initDone());
        while(true){
            receive(
                (StateRestoreInfo sri){
                    if(sri.belongsTo == thisPeerID){
                        writeln("  New state restore info: ", sri);
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
                        if(states[thisPeerID].floor == -1){ // still not arrived at a valid floor
                            states[thisPeerID].floor = prevState.floor;
                        }
                    }
                },
                // --- FROM ELEVATOR HARDWARE --- //
                (btnPressEvent bpe){
                    writeln("  New button press: ", bpe);
                    final switch(bpe.btn) with(ButtonType){
                    case UP, DOWN:
                        if(externalOrders[bpe.floor][bpe.btn].status == ExternalOrder.Status.active){
                            break;
                        }
                        if(!alivePeers.canFind(thisPeerID)){
                            writeln("Warning: This elevator is DISCONNECTED, and will not take new external orders!");
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

                        if( !getThisState.moving  &&
                            getThisState.floor == bpe.floor  &&
                            getThisState.shouldStop)
                        {
                            timerEventTid.send(thisTid, doorClose, doorOpenTime);
                            clearOrdersAtCurrentFloor;
                        }
                        if(getThisState.isIdle){
                            timerEventTid.send(thisTid, doorClose, 0.seconds);
                        }

                        networkTid.send(wrappedState);

                        break;
                    }
                },
                (floorArrivalEvent fae){
                    writeln("  New floor: ", fae);
                    states[thisPeerID].floor = fae;
                    if(getThisState.shouldStop){
                        elevator.SetMotorDirection(MotorDirection.STOP);
                        states[thisPeerID].moving = false;
                        timerEventTid.send(thisTid, doorClose, doorOpenTime);
                        elevator.SetLight(Light.DOOR_OPEN, true);
                        clearOrdersAtCurrentFloor;
                    }
                    networkTid.send(wrappedState);
                },

                // --- FROM NETWORK (from string to struct translator) --- //
                (OrderMsg om){
                    writeln("  New order message: ", om);
                    final switch(om.msgType) with(MessageType){
                    case newOrder:
                        final switch(externalOrders[om.floor][om.btn].status) with(ExternalOrder.Status){
                        case inactive:
                            // add to externalOrders
                            externalOrders[om.floor][om.btn].status = pending;
                            externalOrders[om.floor][om.btn].assignedID = om.assignedID;
                            externalOrders[om.floor][om.btn].hasConfirmed.destroy;
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
                        case pending:
                            //  ok: will happen if either:
                            //      two origins sent the same newOrder before confirmedOrder was sent
                            //          > ackOrder will only be received/handled by the origin, and ack will time out
                            //      an ack has timed out, resulting in no confirmedOrder being sent
                            //          > light will not be turned on, user presses button again
                            break;
                        case active:
                            if(!alivePeers.canFind(externalOrders[om.floor][om.btn].assignedID)){
                                goto case inactive;
                            }
                            //  ok: will happen if either:
                            //      on reassignUnlinkedOrders (implies that om.assignedID != order.assignedID)
                            //          - This is intentional
                            //      another elevators external order is not active (information mismatch)
                            //          > the order already exists on this elevator, so another elevator should show up
                            //          possible remedy: send confirmedOrder to messageOriginID with current info
                            break;
                        }
                        break;

                    case ackOrder:
                        if(om.orderOriginID == thisPeerID){
                            final switch(externalOrders[om.floor][om.btn].status) with(ExternalOrder.Status){
                            case inactive:
                                //  ok: Only makes sense to accept ack's of pending orders where origin = this
                                writeln("Warning: Refused an acknowledgement of an order that is inactive");
                                break;
                            case pending:
                                externalOrders[om.floor][om.btn].hasConfirmed ~= om.msgOriginID;
                                // if all alive peers have ack'd
                                //   send confirmedOrder
                                if( alivePeers
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
                                    timerEventTid.send(thisTid, ack(om.floor, om.btn), CancelEvent());
                                    externalOrders[om.floor][om.btn].hasConfirmed.destroy;
                                }
                                break;
                            case active:
                                //  ok: Only makes sense to accept ack's of pending orders where origin = this
                                writeln("Warning: Refused an acknowledgement of an order that is already active");
                                break;
                            }
                        }
                        break;

                    case confirmedOrder:
                        final switch(externalOrders[om.floor][om.btn].status) with(ExternalOrder.Status){
                        case inactive:
                            if(om.msgOriginID != thisPeerID){
                                externalOrders[om.floor][om.btn].assignedID = om.assignedID;
                                externalOrders[om.floor][om.btn].hasConfirmed.destroy;
                                goto case pending;
                            } else {
                                break;
                            }
                        case pending:
                            externalOrders[om.floor][om.btn].status = active;

                            elevator.SetLight(om.floor, cast(Light)om.btn, true);

                            if( !getThisState.moving  &&
                                getThisState.floor == om.floor  &&
                                getThisState.shouldStop)
                            {
                                timerEventTid.send(thisTid, doorClose, doorOpenTime);
                                clearOrdersAtCurrentFloor;
                            }
                            if(getThisState.isIdle){
                                timerEventTid.send(thisTid, doorClose, 0.seconds);
                            }
                            break;
                        case active:
                            if(externalOrders[om.floor][om.btn].assignedID != om.assignedID){
                                //  ok: Order is already "in the system", but there is a disagreement on who is taking it (information mismatch).
                                writeln("Warning: confirmedOrder.assignedID is not the same as externalOrders.assignedID\n",
                                        "    ", om, "\n    ", externalOrders[om.floor][om.btn]);
                            } else {
                                //  ok: Order is already "in the system"
                            }
                            break;
                        }
                        break;

                    case completedOrder:
                        //  No reason to _not_ clear the order, even if it isn't active
                        //      This may mean that an unassigned elevator clears an order, which is ok.
                        externalOrders[om.floor][om.btn].status = ExternalOrder.Status.inactive;
                        externalOrders[om.floor][om.btn].assignedID = 0;
                        externalOrders[om.floor][om.btn].hasConfirmed.destroy;
                        elevator.SetLight(om.floor, cast(Light)om.btn, false);
                        break;
                    }
                },
                (Tid discard, peerListUpdate plu){
                    writeln("  New peer list:", plu);
                    alivePeers = plu.peers.dup;
                },
                (ElevatorStateWrapper essw){
                    if(essw.belongsTo != thisPeerID){
                        writeln("  New elevator state: ", essw);
                        states[essw.belongsTo] = ElevatorState(essw.content);
                    }
                },
                (StateRestoreRequest srr){
                    if(srr.askerID == thisPeerID){
                        return;
                    }
                    networkTid.send(wrappedState);
                    if(srr.askerID in states){
                        networkTid.send(
                            StateRestoreInfo(
                                srr.askerID,
                                states[srr.askerID].to!string
                            )
                            .to!string
                        );
                    }
                    foreach(floor, row; externalOrders){
                        foreach(btn, order; row){
                            if(order.status == ExternalOrder.Status.active){
                                networkTid.send(OrderMsg(
                                    order.assignedID,
                                    floor.to!int,
                                    cast(ButtonType)btn,
                                    thisPeerID,
                                    thisPeerID,
                                    MessageType.confirmedOrder
                                ).to!string);
                            }
                        }
                    }
                },

                // --- FROM TIMER --- //
                (Tid t, string s){
                    if(t == timerEventTid){
                        // --- door close --- //
                        if(s == doorClose){
                            writeln("  New timer event: ", doorClose);
                            if(getThisState.hasOrders){
                                states[thisPeerID].dirn = getThisState.chooseDirn;
                                elevator.SetMotorDirection(states[thisPeerID].dirn);

                                clearOrdersAtCurrentFloor;
                                if(states[thisPeerID].dirn != MotorDirection.STOP){
                                    elevator.SetLight(Light.DOOR_OPEN, false);
                                    states[thisPeerID].moving = true;
                                }
                            } else {
                                states[thisPeerID].moving = false;
                                states[thisPeerID].dirn = MotorDirection.STOP;
                            }
                            networkTid.send(wrappedState);
                            return;
                        }
                        // --- order ack timeout --- //
                        if(s.startsWith("ack")){
                            /+++++
                            // Not necessary! confirmedOrder will only be sent if ALL acknowledge, so there's no _need_ to solve this in software.
                            //   -> Reliability goes down with more participants (elevators)
                            // Solution: A heuristic of some sort...
                            networkTid.send(OrderMsg(
                                thisPeerID,
                                s.parse!int,
                                s.parse!ButtonType,
                                thisPeerID,
                                thisPeerID,
                                MessageType.newOrder
                            ).to!string);
                            +++++/
                            s.skipOver("ack");
                            writeln("Warning: Acknowledgement of order ", s.parse!int, " ", s.parse!ButtonType, " failed!\n",
                                    "    Expected behaviour: Light is not turned on. \n",
                                    "    Press the button again to retry...");
                            return;
                        }
                        // --- Order reassignment & data integrity checker --- //
                        if(s == reassignUnlinkedOrders){
                            foreach(floor, row; externalOrders){
                                foreach(btn, order; row){
                                    if(order.status == ExternalOrder.Status.active  &&  !alivePeers.canFind(order.assignedID)){
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
                            timerEventTid.send(thisTid, reassignUnlinkedOrders, uniform(reassignMinTime_s,reassignMaxTime_s).seconds);
                            return;
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




    /// ----- MEMBER FUNCTIONS ----- ///

    string wrappedState(){
        return ElevatorStateWrapper(
            states[thisPeerID].to!string,
            thisPeerID
        ).to!string;
    }

    GeneralizedElevatorState getThisState(){
        return states[thisPeerID].generalize(thisPeerID, externalOrders);
    }

    void clearOrdersAtCurrentFloor(){
        auto floor = states[thisPeerID].floor;
        states[thisPeerID].internalOrders[floor] = false;
        elevator.SetLight(floor, Light.COMMAND, false);
        final switch(states[thisPeerID].dirn) with(MotorDirection) {
        case UP:
            if(externalOrders[floor][UP].status == ExternalOrder.Status.active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            if(!getThisState.ordersAbove  &&  externalOrders[floor][DOWN].status == ExternalOrder.Status.active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            break;
        case DOWN:
            if(externalOrders[floor][DOWN].status == ExternalOrder.Status.active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            if(!getThisState.ordersBelow  &&  externalOrders[floor][UP].status == ExternalOrder.Status.active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            break;
        case STOP:
            if(externalOrders[floor][UP].status == ExternalOrder.Status.active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.UP, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            if(externalOrders[floor][DOWN].status == ExternalOrder.Status.active){
                auto om = OrderMsg(thisPeerID, floor, ButtonType.DOWN, 0, thisPeerID, MessageType.completedOrder);
                thisTid.send(om);
                networkTid.send(om.to!string);
            }
            break;
        }
    }



}

