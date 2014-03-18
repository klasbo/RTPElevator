import  std.stdio,
        std.range,
        std.algorithm,
        std.array;
        
        
unittest {
    string[int] data;
    data[1] = "one";
    data[2] = "two";
    data[3] = "three";
    data[4] = "four";
    
    int[]       filt = [1,4];
    
    data.keys.zip(data.values)
    .filter!(a => filt.canFind(a[0]))
    .assocArray
    .writeln;
}