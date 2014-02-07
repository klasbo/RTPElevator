module  test.tcp_ms_test;

import  std.stdio,
        std.concurrency,
        std.socket,
        core.thread;

import  network.tcp_ms;


void tcp_ms_test(){
    auto tcp_ms_tid = tcp_ms_start;

    spawn( &spammer );

    while(true){
        receive(
            (Tid t, string s){
                writeln("\n    tcp_ms_test received message:\n     ", s, "\n");
            },
            (Tid t, peerListUpdate plu){
                writeln("\n    tcp_ms_test received peer list:\n     ", plu.peers, "\n");
            },
            (spam s){
                tcp_ms_tid.send(s.msg);
            },
            (Variant v){
                v.writeln;
            }
        );
    }

}


void spammer(){
    localIP     = new TcpSocket(new InternetAddress("www.google.com", 80)).localAddress.toAddrString;
    while(true){
        ownerTid.send(spam("hello from " ~ localIP ~ "\0"));
        Thread.sleep(5.seconds);
    }
}

struct spam {
    string msg;
}
