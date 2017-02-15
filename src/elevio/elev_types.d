module elevio.elev_types;

enum CallType : int {
    hallUp,
    hallDown,
    cab
}

enum HallCallType : int {
    up,
    down
}

enum Dirn : int {
    down    = -1,
    stop    = 0,
    up      = 1
}

enum ElevatorType {
    simulation,
    comedi
}