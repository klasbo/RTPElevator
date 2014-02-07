import  std.stdio,
        std.algorithm,
        std.range;


class C
{
    void foo(string onoff)(int arg1, string arg2, Light l){
        static if (onoff == "on"){
            arg2.repeat(arg1).writeln;
        } else static if (onoff == "off"){
            arg2.writeln(" etc");
        } else {
            static assert(0, "call with on or off");
        }
    }
    void foo(int arg1, string arg2, Light l){
        writeln("asdfwer");
    }
}

void main(){
    auto c = new C;
    c.foo!"on"(3, "hello", Light.UP);
    
    
}



enum Light : int {
    UP=0,
    DOWN=1,
    COMMAND=2,
    FLOOR_INDICATOR=3,
    STOP=4,
    DOOR_OPEN=5
}