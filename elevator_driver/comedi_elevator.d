module  elevator_driver.comedi_elevator;

import  elevator_driver.channels,
        elevator_driver.io_di;
public import elevator_driver.i_elevator;
import  std.conv,
        std.string;




/**
 * Thick wrapper for the Comedi Elevator
*
* The intention is that all interfacing to the elevator should be doable through an instance of class ComediElevator,<br>
*     which means that if some kind of interfacing is missing, borked or just damn unintuitive, this is the file to change.<br>
* No exceptions are handled within this class, but exceptions are thrown for the programmer (yes, I'm talking to you. If<br>
*     there was a fifth wall, I'd try to break that one too) to handle elsewhere.<br>
*
* The ComediElevator does NOT handle more than 4 floors in any sensible way. Mostly because of the way it has to<br>
*     interface with the hardware. Maybe it's possible to make it disregard hardware at higher floors, but still provide<br>
*     virtual functionality when the elevator is in orbit. However, this feels like solving a problem that doesn't<br>
*     really exist, unless you're creating elevator control for the elevator in the 1971 version of "Willy Wonka &<br>
*     the Chocolate Factory". The ComediElevator should support fewer than 4 floors, by using SetElevatorOption()<br>

* 2013, klasbo
*/

class ComediElevator : Elevator
{
    /**
     * Create a new ComediElevator instance
     * Throws: when hardware initialization fails
     */
    this(){
        if (!io_init()){
            throw new Exception("Unable to initialize elevator hardware");
        }
    }
    /**
     * Stops the elevator and destroys the ComediElevator instance
     */
    ~this(){
        SetMotorDirection(MotorDirection.STOP);
    }

    public:
        /**
         * Reads UP/DOWN/COMMAND button for given floor<br>
         *   Returns 1 on press, 0 otherwise<br>
         *   Returns -1 on invalid _floor/ButtonType combination at max/min _floor <br>
         *   If a floor is out of bounds, it will read the button at the closest _floor<br><br>
         */
        int ReadButton(int floor, ButtonType b){
            if(floor < ComediElevator.minFloor  ||  floor > ComediElevator.maxFloor){
                assert(0, "ReadButton floor is out of bounds: floor = " ~ floor.to!string);
            }
            if (b == ButtonType.DOWN  &&  floor == ComediElevator.minFloor){ return -1; }
            if (b == ButtonType.UP    &&  floor == ComediElevator.maxFloor){ return -1; }
            return io_read_bit(buttonChannelMatrix[floor][b]);
        }

        /** Reads the floor sensor<br>
         *   Returns the _floor the elevator is at, or -1 if the elevator<br>
         *   is not at a defined _floor (aka between two _floors, or in space)<br>
         */
        int ReadFloorSensor(){
            for( int floor = ComediElevator.minFloor; floor <= ComediElevator.maxFloor; floor++ ){
                switch(floor){
                    case 0: if( io_read_bit(SENSOR1) ){ return 0; } break;
                    case 1: if( io_read_bit(SENSOR2) ){ return 1; } break;
                    case 2: if( io_read_bit(SENSOR3) ){ return 2; } break;
                    case 3: if( io_read_bit(SENSOR4) ){ return 3; } break;
                    default: break;
                }                
            }
            return -1;
        }

        /** Reads the stop button<br>
         *   Returns 1 if the (internal) stop button is pressed, 0 otherwise<br>
         */
        int ReadStopButton(){
            return io_read_bit( STOP );
        }

        /** Reads the obstruction switch<br>
         *   Returns 1 if the obstruction is active, 0 otherwise<br>
         */
        int ReadObstruction(){
            return io_read_bit( OBSTRUCTION );
        }

        /** Sets the floor-dependent lights:<br>
         *   Hallway (UP/DOWN) and internal (COMMAND) only<br>
         *   Throws exception if an invalid light is given<br>
         *   If a _floor is out of bounds, it will set the light at the closest _floor<br>
         */
        void SetLight(int floor, Light l, bool enable){
            floor = coerce(floor, ComediElevator.minFloor, ComediElevator.maxFloor);
            
            if (l == Light.UP || l == Light.DOWN || l == Light.COMMAND){
                if (enable){
                    io_set_bit(lampChannelMatrix[floor][l]);
                } else {
                    io_clear_bit(lampChannelMatrix[floor][l]);
                }
            } else {
                throw new Exception("Invalid argument. Use a floor-dependent light. Got " ~ to!(string)(l));
            }
        }

        /** Sets the FLOOR_INDICATOR light only
         *   Throws exception if an invalid light is given<br>
         *   If a _floor is out of bounds, it will set the light at the closest _floor<br>
         */
        void SetLight(int floor, Light l){
            floor = coerce(floor, ComediElevator.minFloor, ComediElevator.maxFloor);
            
            if (l == Light.FLOOR_INDICATOR){     // So this thing is ugly. I don't know why these lights are encoded binary-esque.
                if (floor & 0x02){                      //   Copied from Martin Korsgaard's "elev_set_floor_indicator(int floor)"
                    io_set_bit(FLOOR_IND1);
                } else {
                    io_clear_bit(FLOOR_IND1);
                }
                if (floor & 0x01){
                    io_set_bit(FLOOR_IND2);
                } else {
                    io_clear_bit(FLOOR_IND2);
                }
            } else {
                throw new Exception("Invalid argument. This function is for the FLOOR_INDICATOR light only. Got " ~ to!(string)(l));
            }
        }
        
        /** Sets the floor-invariant lights:<br>
         *   Emergency stop (STOP), and door open (DOOR_OPEN)<br>
         *   Throws exception if an invalid light or invalid on/off parameter is given<br>
         */
        void SetLight(Light l, bool enable){
            if (l == Light.STOP || l == Light.DOOR_OPEN){
                if (enable){
                    io_set_bit(lampChannelMatrix[0][l]);
                } else {
                    io_clear_bit(lampChannelMatrix[0][l]);
                }
            } else {
                throw new Exception("Invalid argument. Use a floor-invariant light. Got " ~ to!(string)(l));
            }
        }

        /// Turns off all lights. Sets floor indicator to floor 0. Use with care.
        void ResetLights(){
                for(int j = ComediElevator.minFloor; j <= ComediElevator.maxFloor; j++){
                    SetLight(j, Light.UP, false);
                    SetLight(j, Light.DOWN, false);
                    SetLight(j, Light.COMMAND, false);
                }
                SetLight(Light.STOP, false);
                SetLight(Light.DOOR_OPEN, false);
                SetLight(Light.FLOOR_INDICATOR, true);
        }


        /** Stops or starts (up or down) the motor<br>
         */
        void SetMotorDirection(MotorDirection m){
            final switch(m) with(MotorDirection){
                case STOP:
                    if (lastMotorDir == UP){
                        io_set_bit(MOTORDIR);
                    } else if (lastMotorDir == DOWN){
                        io_clear_bit(MOTORDIR);
                    } else {
                        // already standing still, no need to toggle.
                    }
                    io_write_analog(MOTOR, 0);
                    lastMotorDir = STOP;
                    break;

                case UP:
                    io_clear_bit(MOTORDIR);
                    io_write_analog(MOTOR, 2048 + 2*MotorSpeed);
                    lastMotorDir = UP;
                    break;

                case DOWN:
                    io_set_bit(MOTORDIR);
                    io_write_analog(MOTOR, 2048 + 2*MotorSpeed);
                    lastMotorDir = DOWN;
                    break;
            }
        }

        /// Set various elevator options
        void SetElevatorOption(ElevatorOption opt, int val){
            final switch(opt) with(ElevatorOption){
                case SPEED:
                    MotorSpeed = coerce(val, minMotorSpeed.to!int, maxMotorSpeed.to!int);
                    break;
            }
        }

        ///
        @property int minFloor() const{
            return _minFloor;
        }

        ///
        @property int maxFloor() const{
            return _maxFloor;
        }

    private:
        static immutable int   minMotorSpeed   = 0;
        static immutable int   maxMotorSpeed   = 1000;
        int             MotorSpeed      = 500;
        auto            lastMotorDir    = MotorDirection.STOP;  // Used in SetMotorDirection. Try to not use it anywhere else.

        int   _minFloor     = 0;
        int   _maxFloor     = 3;




        T coerce(T)(T val, T min, T max){
            if ( val < min ){
                return min;
            } else if ( val > max ){
                return max;
            } else {
                return val;
            }
        }


}

const int[][] buttonChannelMatrix = [   // Make sure this aligns with the 'Button' enum!
    [FLOOR_UP1, FLOOR_DOWN1, FLOOR_COMMAND1],
    [FLOOR_UP2, FLOOR_DOWN2, FLOOR_COMMAND2],
    [FLOOR_UP3, FLOOR_DOWN3, FLOOR_COMMAND3],
    [FLOOR_UP4, FLOOR_DOWN4, FLOOR_COMMAND4]];



const int[][] lampChannelMatrix = [     // Make sure this aligns with the 'Light' enum!
    [LIGHT_UP1, LIGHT_DOWN1, LIGHT_COMMAND1],
    [LIGHT_UP2, LIGHT_DOWN2, LIGHT_COMMAND2],
    [LIGHT_UP3, LIGHT_DOWN3, LIGHT_COMMAND3],
    [LIGHT_UP4, LIGHT_DOWN4, LIGHT_COMMAND4]];

// Other
///
enum ElevatorOption {
    ///
    SPEED
}



version(Windows){
    pragma(msg, "    Compiling with empty io_X() functions...");

    int     io_init(){ return 0; }
    void    io_set_bit(int channel){ return; }
    void    io_clear_bit(int channel){ return; }
    void    io_write_analog(int channel, int value){ return; }
    int     io_read_bit(int channel){ return 0; }
    int     io_read_analog(int channel){ return 0; }
}




