module event_loop.types;


public import network.udp_p2p : ID;
public import elevator_driver.i_elevator : ButtonType, MotorDirection;

struct initDone {}


struct ElevatorState {
    int             floor;
    MotorDirection  dirn;
    bool            moving;
    bool[]          internalOrders;
}
struct ElevatorStateWrapper {
    string          content;
    ID              belongsTo;
}
struct ExternalOrder {
    enum Status {
        inactive,
        pending,
        active
    }
    Status          status;
    ID              assigned;
    ID[]            hasConfirmed;
}

struct GeneralizedElevatorState {
    int             floor;
    MotorDirection  dirn;
    bool            moving;
    bool[][]        orders;
    ID              id;
}

struct OrderMsg {
    // order description
    ID              assigned;
    int             floor;
    ButtonType      btn;

    // meta
    ID              orderOrigin;
    ID              msgOrigin;
    MessageType     msgType;
}
enum MessageType {
    newOrder,
    ackOrder,
    confirmedOrder,
    completedOrder
}

struct StateRestoreRequest {
    ID              asker;
}
struct StateRestoreInfo {
    ID              belongsTo;
    string          stateString;
}
