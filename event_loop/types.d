module event_loop.types;

import  util.struct_constructor_mixin;

public import network.udp_p2p : ID_t;
public import elevator_driver.i_elevator : ButtonType, MotorDirection;

struct initDone {}


struct ElevatorState {
    int             floor;
    MotorDirection  dirn;
    bool            moving;
    bool[]          internalOrders;
    mixin(genConstructor!(typeof(this)));
}
struct ElevatorStateWrapper {
    string          content;
    ID_t            belongsTo;
    mixin(genConstructor!(typeof(this)));
}
struct ExternalOrder {
    enum Status {
        inactive,
        pending,
        active
    }
    Status          status;
    ID_t            assignedID;
    ID_t[]          hasConfirmed;
}

struct GeneralizedElevatorState {
    int             floor;
    MotorDirection  dirn;
    bool            moving;
    bool[][]        orders;
    ID_t            ID;
}

struct OrderMsg {
    // order description
    ID_t            assignedID;
    int             floor;
    ButtonType      btn;

    // meta
    ID_t            orderOriginID;
    ID_t            msgOriginID;
    MessageType     msgType;

    mixin(genConstructor!(typeof(this)));
}
enum MessageType {
    newOrder,
    ackOrder,
    confirmedOrder,
    completedOrder
}

struct StateRestoreRequest {
    ID_t            askerID;
    mixin(genConstructor!(typeof(this)));
}
struct StateRestoreInfo {
    ID_t            belongsTo;
    string          stateString;
    mixin(genConstructor!(typeof(this)));
}
