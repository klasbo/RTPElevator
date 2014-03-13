import  std.stdio,
        std.concurrency;

import  test.tcp_ms_test,
        test.udp_p2p_test,
        test.elevator_driver_test;        
        
import  elevator_driver;        

import  event_loop;

void main(){
    //tcp_ms_test;
    //udp_p2p_test;
    //elevator_driver_test;
    eventLoop_start;
    
    import core.thread;
    while(true){ Thread.sleep(1.hours); }
}



