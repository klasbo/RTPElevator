module feeds.floor_indicator;

import std.concurrency;

import feed;
import elevio.elev;
import feeds.elevio_reader;

void thr(){
    subscribe!FloorSensor;
    while(true){
        receive(
            (FloorSensor f){
                floorIndicator(f);
            }
        );
    }
}
