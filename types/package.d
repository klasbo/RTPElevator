module  types;

import  std.typecons;


struct initDone {}

struct btnPressEvent {
    ButtonType  btn;
    int         floor;
}
struct stopBtnEvent {}
struct obstrSwitchEvent {
    bool        active;
}
struct newFloorEvent {
    int         floor;
    invariant() {
        assert(floor >= 0, "newFloorEvent floor must be positive");
    }
}


enum ButtonType : int {
    UP=0,
    DOWN=1,
    COMMAND=2
}

enum Light : int {
    UP=0,
    DOWN=1,
    COMMAND=2,
    FLOOR_INDICATOR,
    STOP,
    DOOR_OPEN
}

enum MotorDirection {
    UP,
    DOWN,
    STOP
}
