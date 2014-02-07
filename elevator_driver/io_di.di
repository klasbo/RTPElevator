/+
Stupidly simple D interface to C code.
    (D understands how C names are mangled)

C code dependencies:
    io.c
    io.h
    channels.h

2013, klasbo
+/

module elevator_driver.io_di;

version(linux){
    extern(C):
        int     io_init();
        void    io_set_bit(int channel);
        void    io_clear_bit(int channel);
        void    io_write_analog(int channel, int value);
        int     io_read_bit(int channel);
        int     io_read_analog(int channel);
}
