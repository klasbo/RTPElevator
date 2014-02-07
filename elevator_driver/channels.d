// Channel definitions for elevator control using LibComedi
//
// 2006, Martin Korsgaard
// Modified for D: 2013, klasbo
module elevator_driver.channels;


//in port 4
const int PORT4          = 3;
const int OBSTRUCTION    = (0x300+23);
const int STOP           = (0x300+22);
const int FLOOR_COMMAND1 = (0x300+21);
const int FLOOR_COMMAND2 = (0x300+20);
const int FLOOR_COMMAND3 = (0x300+19);
const int FLOOR_COMMAND4 = (0x300+18);
const int FLOOR_UP1      = (0x300+17);
const int FLOOR_UP2      = (0x300+16);

//in port 1
const int PORT1          = 2;
const int FLOOR_DOWN2    = (0x200+0);
const int FLOOR_UP3      = (0x200+1);
const int FLOOR_DOWN3    = (0x200+2);
const int FLOOR_DOWN4    = (0x200+3);
const int SENSOR1        = (0x200+4);
const int SENSOR2        = (0x200+5);
const int SENSOR3        = (0x200+6);
const int SENSOR4        = (0x200+7);

//out port 3
const int PORT3          = 3;
const int MOTORDIR       = (0x300+15);
const int LIGHT_STOP     = (0x300+14);
const int LIGHT_COMMAND1 = (0x300+13);
const int LIGHT_COMMAND2 = (0x300+12);
const int LIGHT_COMMAND3 = (0x300+11);
const int LIGHT_COMMAND4 = (0x300+10);
const int LIGHT_UP1      = (0x300+9);
const int LIGHT_UP2      = (0x300+8);

//out port 2
const int PORT2          = 3;
const int LIGHT_DOWN2    = (0x300+7);
const int LIGHT_UP3      = (0x300+6);
const int LIGHT_DOWN3    = (0x300+5);
const int LIGHT_DOWN4    = (0x300+4);
const int DOOR_OPEN      = (0x300+3);
const int FLOOR_IND2     = (0x300+1);
const int FLOOR_IND1     = (0x300+0);

//out port 0
const int PORT0          = 1;
const int MOTOR          = (0x100+0);

//non-existing ports (to achieve macro consistency)
const int FLOOR_DOWN1    = -1;
const int FLOOR_UP4      = -1;
const int LIGHT_DOWN1    = -1;
const int LIGHT_UP4      = -1;

