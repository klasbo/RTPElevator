


import core.sync.mutex;
import core.thread;
import core.time;
import std.algorithm;
import std.concurrency;
import std.meta;
import std.stdio;
import std.traits;
import std.typecons;


private __gshared Mutex             sub_lock;
private __gshared Tid[][string]     subscribers;


shared static this(){
    sub_lock = new Mutex;
}

void subscribe(T)(){
    synchronized(sub_lock){
        subscribers[fullyQualifiedName!T] ~= thisTid;
        //writeln("subscribers [", fullyQualifiedName!T, "]: ", subscribers[fullyQualifiedName!T]);
    }
}

void publish(T)(T var){
    synchronized(sub_lock){
        if(fullyQualifiedName!T in subscribers){
            //writeln("publish ", fullyQualifiedName!T);
            foreach(tid; subscribers[fullyQualifiedName!T]){
                tid.send(var);
            }
        }
    }
}

void unsubscribeAll(Tid t){
    synchronized(sub_lock){
        foreach(feedName, ref subs; subscribers){
            auto idx = subs.countUntil!(a => a == t);
            if(idx != -1){
                subs = subs.remove(idx);
            }
        }
        //writefln("%(%s : %s\n%)", subscribers);
    }
}





