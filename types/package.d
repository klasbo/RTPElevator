module  types;

import  std.typecons;
import  util.struct_constructor_mixin;

struct initDone {}

struct ElevatorState {
    import elevator_driver.i_elevator;
    
    int             floor;
    MotorDirection  dirn;
    bool            moving;
    bool[]          internalOrders;
    mixin(genConstructor!(typeof(this)));
}
struct ElevatorStateWrapper {
    string          content;
    ubyte           belongsTo;
    mixin(genConstructor!(typeof(this)));
}
struct ExternalOrder {
    bool            active;
    ubyte           assignedID;
    ubyte[]         hasConfirmed;
}
struct GeneralizedElevatorState {
    import elevator_driver.i_elevator;
    
    int             floor;
    MotorDirection  dirn;
    bool            moving;
    bool[][]        orders;
    ubyte           ID;
}

struct OrderMsg {
    import elevator_driver.i_elevator;
    
    // order description
    ubyte           assignedID;
    int             floor;
    ButtonType      button;
    
    // meta
    ubyte           originID;
    MsgType         msgType;
}
enum MsgType {
    newOrder,
    ackOrder,
    confirmedOrder,
    completedOrder
}

struct StateRestoreRequest {
    ubyte           askerID;
}
struct StateRestoreInfo {
    ubyte           belongsTo;
    string          stateString;
}







