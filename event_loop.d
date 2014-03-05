import  std.stdio,
        std.concurrency;

import  elevator_driver,
        util.timer_event;


public {
    void event_loop_start(){
    }
}
    
private {
    void event_loop_hub(){
    
    
    auto timerEventThr  = spawn( &timerEvent_thr );
    //auto networkThr     = spawn( &)
    
    
    struct state {
        int             floor;
        MotorDirection  dirn;
        bool            moving;
        bool[]          internalOrders;
    }
    
    ubyte[][]       externalOrders;
    state[ubyte]    states;
    
    
    
    
    
        while(true){
            receive(
                /// ---- FROM ELEVATOR ---- ///
                (btnPressEvent bpe){
                },
                (newFloorEvent nfe){
                },
                
                /// ---- FROM NETWORK ---- ///
//                 (orderMsg om){
//                 },
//                 (peerListUpdate plu){
//                 },
//                 (stateUpdate su){
//                 },
//                 (stateRestoreRequest srr){
//                 },
                
                /// ---- FROM TIMER ---- ///
                (Tid t, string s){
                    if(t == timerEventThr){
                        // --- order ack timeout --- //
                        // --- door close --- //
                    }
                }
            );
        }
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