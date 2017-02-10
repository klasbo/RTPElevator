


import core.sync.mutex;
import core.thread;
import core.time;
import std.concurrency;
import std.meta;
import std.stdio;
import std.typecons;


__gshared Mutex             sub_lock;
__gshared Tid[][string]     subscribers;


shared static this(){
    sub_lock = new Mutex;
}

void subscribe(T)(){
    synchronized(sub_lock){
        subscribers[T.stringof] ~= thisTid;
        //writeln("subscribers [", T.stringof, "]: ", subscribers[T.stringof]);
    }
}

void publish(T)(T var){
    synchronized(sub_lock){
        if(T.stringof in subscribers){
            //writeln("publish ", T.stringof);
            foreach(tid; subscribers[T.stringof]){
                tid.send(var);
            }
        }
    }
}





