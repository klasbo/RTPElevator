module elevio.elev_types;

enum Call : int {
    hallUp,
    hallDown,
    cab
}

enum HallCall : int {
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