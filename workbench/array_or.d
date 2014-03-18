import  std.stdio,
        std.range,
        std.algorithm,
        std.conv;
        
        
struct S {
    int i;
    bool[][] arr;
}
        
unittest {
    auto ss = [  
        S(1, [[true, false, false], [false, true, false]]),
        S(2, [[false, true, false], [true, true, false]]),
        S(3, [[false, false, false], [false, false, false]])
    ];
    
    bool[][] b;
    
    ss.map!(a => a.to!string ~ "\n").reduce!("a~b").writeln;
    ss.map!(s => 
        S(
            s.i,
            (b = s.arr.map!(a=>a.dup).array, b[0][1] = true, b)
        )    
    )
    .map!(a => a.to!string ~ "\n").reduce!("a~b").writeln;
    ss.map!(a => a.to!string ~ "\n").reduce!("a~b").writeln;
    
    /+
    auto s10 = S(
        //(a => s1.arr[0][1] = true, s1.arr, a)
        (b = s1.arr.map!(a=>a.dup).array, b[0][1] = true, b)
    );
    +/

}