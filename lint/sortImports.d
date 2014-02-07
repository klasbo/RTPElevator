
import std.stdio, std.array, std.algorithm;//, std.string;

void main(){

    auto imports = 
        "std.algorithm,
        std.concurrency,
        std.conv,
        std.datetime,
        std.stdio,
        std.string,
        std.range,
        core.thread";
        
    imports
    .split(",\n")
    .map!(a => a.strip(' '))
    .array
    .sort
    .reduce!((a,b) => a ~ ",\n" ~ b)
    .writeln;
}