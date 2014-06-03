module module_one;

import  std.stdio,
        std.array,
        std.file,
        std.concurrency,
        core.thread,
        std.getopt;

        
public {
    string str(){
        return s;
    }
    double dd(){
        return d;
    }
    Tid module_one_start(){
        Tid t = spawn({
            auto configContents = readText("cfg.con").split;
            getopt( configContents,
                std.getopt.config.passThrough,
                "module_string", &s,
                "module_double", &d,
            );
            writeln("d is ", d);
            Thread.sleep(100.msecs);
            ownerTid.send(d);
        });
        return t;
    }
}

private {    
    __gshared string s;
    __gshared double d = 5.5;
    int i;
}
    