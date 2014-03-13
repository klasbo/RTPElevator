import  std.stdio,
        std.concurrency,
        std.algorithm,
        std.range,
        std.conv;

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

    int numFloors;

    void eventLoop(){
        scope(exit){ writeln(__FUNCTION__, " has died"); }
try {
    
        /// ----- DEPENDENCIES ----- ///
        auto timerEventTid                  = spawn( &timerEvent_thr );
        auto stringToStructTranslatorTid    = spawn( &stringToStructTranslator_thr!(
            ElevatorStateWrapper
        ) );
        auto networkTid                     = udp_p2p_start(stringToStructTranslatorTid);
        auto elevator                       = new SimulationElevator;
        numFloors                           = elevator.maxFloor - elevator.minFloor + 1;
        auto elevatorEventsTid              = elevatorEvents_start(elevator);
     
     
        /// ----- VARIABLES ----- ///
        auto                    externalOrders = new ExternalOrder[][](numFloors, 2);
        ElevatorState[ubyte]    states;
        ubyte[]                 alivePeers;
    
    
        /// ----- FUNCTIONS ----- ///
        string wrappedState(){
            return ElevatorStateWrapper(
                states[thisPeerID].to!string,
                thisPeerID
            ).to!string;
        }
    
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
                },
                (newFloorEvent nfe){
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
                    }
                },
                (Variant v){
                    writeln("Event loop received unknown type: ", v.type, "\n    ", v);
                }
            );
        }
} catch(Throwable t){ t.writeln; throw t; }
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
}
/+
button press
new floor

order msg
ack timeout
order integrity check (random interval)
light on

peer list update
state update
state restore request

door close
+/