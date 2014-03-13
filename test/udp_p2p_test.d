module  test.udp_p2p_test;

import  std.stdio,
        std.concurrency,
        core.thread;

import  network.udp_p2p;

        
void udp_p2p_test(){
    auto receiver = spawn( &recv_thr );

    auto udp_p2p_tid = udp_p2p_start(receiver);    
    
    udp_p2p_tid.send("hello");
    
    while(true){ Thread.sleep( Duration.max); }

}

void recv_thr(){
    while(true){
        receive(
            (Tid t, string s){
                writeln(__FUNCTION__, " received ", s);
            },
            (Tid t, peerListUpdate plu){
                writeln(__FUNCTION__, " received ", plu.peers);
            },
            (Variant v){
                v.writeln;
            }
        );
    }
}