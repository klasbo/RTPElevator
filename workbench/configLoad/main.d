module main;

import  std.stdio,
        std.array,
        std.file,
        std.concurrency,
        core.thread,
        std.getopt;
        
import  module_one;


void main(string[] args){
    int i;
    bool b;
        
    auto configContents = readText("cfg.con").split;
    getopt( configContents,
        std.getopt.config.passThrough,
        "main_int", &i,
        "main_bool", &b        
    );
    
    i.writeln;
    b.writeln;
    
    module_one_start;
    
    
    Thread.sleep(500.msecs);
    
    str.writeln;
    dd.writeln;
    receive((double dd){
        writeln("received double ", dd);
    });
}