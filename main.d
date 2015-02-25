import  std.file,
        std.stdio,
        std.concurrency;

import  test.tcp_ms_test,
        test.udp_p2p_test,
        test.elevator_driver_test;        
        
import  elevator_driver;        

import  event_loop;

/+
config: terminal window, or userShell?
restart program if config does not exist

+/


shared static this(){
    if(!"ElevatorConfig.con".exists){
        std.file.write("ElevatorConfig.con", 
q"EOS
ElevatorConfig

--eventLoop_elevatorType                            simulation
--eventLoop_doorOpenTime_ms                         3000
--eventLoop_ackTimeout_ms                           50
--eventLoop_reassignMinTime_s                       3
--eventLoop_reassignMaxTime_s                       7
--eventLoop_bestFit_travelTimeEstimate_ms           4000

--network_IDOffset                                  0
--network_iAmAliveSendInterval_ms                   300
--network_iAmAliveTimeout_ms                        1000        // must be larger than sendInterval
--network_iAmAlivePort                              22222
--network_msgPort                                   22223

--simulationElevator_travelTimeBetweenFloors_ms     1500
--simulationElevator_travelTimePassingFloor_ms      650
--simulationElevator_btnDepressedTime_ms            200
--simulationElevator_comPort                        40000

--comediElevator_motorSpeed                         500

--elevatorDriver_pollRate_ms                        10
EOS"
        );
    }
}

void main(){
    //tcp_ms_test;
    //udp_p2p_test;
    //elevator_driver_test;
    eventLoop_start;
    
    import core.thread;
    while(true){ Thread.sleep(1.hours); }
}



