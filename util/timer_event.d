module  util.timer_event;


import  core.thread,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.datetime,
        std.range,
        std.stdio,
        std.string;

//debug = timerEvent_thr;


enum {
    oneshot,
    periodic,
    cancel
}

void timerEvent_thr(){
    scope(failure){
        writeln(__FUNCTION__, " died");
    }

try{


    struct Event {
        Tid         owner;
        string      name;
        SysTime     time;
        Duration    period;

        string toString(){
            return "Event("
                    ~ name  ~ ", "
                    ~ time.to!string ~ ", "
                    ~ period.to!string ~ ")";
        }
    }


    Event[]     events;
    Duration    timeUntilNextEvent  = 1.hours;
    Duration    eventMinimumPeriod  = 5.msecs;


    void AddEvent(Tid owner, string eventName, SysTime timeOfEvent, Duration period, int type){
        foreach(event; events){
            if(owner == event.owner  &&  eventName == event.name){
                debug writeln("Failure to add new event: Event \"" ~ eventName ~ "\" already exists for this owner");
                return;
            }
        }
        if(type == periodic  &&  period < eventMinimumPeriod){
            debug writeln("Failure to add new event: Event period is too fast");
            return;
        }
        if(type == periodic){
            events ~= Event(owner, eventName, timeOfEvent + period, period);
        } else if(type == oneshot){
            events ~= Event(owner, eventName, timeOfEvent, 0.msecs);
        } else {
            debug writeln("Failure to add new event: Event type ", type, "  does not exist");
        }
    }

    while(true){

        receiveTimeout( timeUntilNextEvent,
            // in [time] timeunits (implicit oneshot)
           (Tid owner, string eventName, Duration time){
               AddEvent(owner, eventName, Clock.currTime + time, 0.msecs, oneshot);
           },
           // in [time] timeunits, with type
           (Tid owner, string eventName, Duration time, int type){
               AddEvent(owner, eventName, Clock.currTime + time, time, type);
           },
           // at [time] (implicit oneshot)
           (Tid owner, string eventName, SysTime time){
                AddEvent(owner, eventName, time, 0.msecs, oneshot);
           },
           // cancel event
           (Tid owner, string eventName, int cancel){
               foreach(idx, event; events){
                   if(event.name == eventName){
                       events = events.remove(idx);
                       break;
                   }
               }
           },
           (Variant v){
               writeln(__FUNCTION__,":",__LINE__," Unhandled input: ", v);
           }
        );


        // Go through all events. If one has passed, send back event & update events list
        iter:
        events.sort!("a.time < b.time");
        foreach(idx, ref event; events){
            timeUntilNextEvent = event.time - Clock.currTime;
            if(timeUntilNextEvent <= 0.msecs){

                event.owner . send(thisTid, event.name);

                if(event.period >= eventMinimumPeriod){
                    event.time += event.period;
                } else {
                    events = events.remove(idx);
                }
                goto iter;  // Do not foreach over a list that is being modified
            }
        }



        // Set the time until next event to the shortest time
        events.sort!("a.time < b.time");
        if(events.length > 0){
            timeUntilNextEvent = events.front.time - Clock.currTime;
            if(timeUntilNextEvent <= 0.msecs){
                timeUntilNextEvent = 0.msecs;
            }
        } else {
            timeUntilNextEvent = 1.hours;
        }
    }
}
catch(Throwable t){ t.writeln; }
}
