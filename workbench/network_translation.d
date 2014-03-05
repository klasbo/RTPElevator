import  std.stdio,
        std.range,
        std.algorithm,
        std.conv,
        std.string,
        std.concurrency;

struct ElevatorStateUpdate {
    string state;
}


struct State {
    int     i;
    bool    b;
    int[]   a;
    mixin(genConstructor!(typeof(this)));
}

struct PeerListUpdate {
    string peerList;
}

struct PeerList {
    ubyte   master;
    ubyte[] peers;
    mixin(genConstructor!(typeof(this)));
}

void main(){
    auto t = spawn( &translator!(ElevatorStateUpdate, PeerListUpdate) );

    auto state1  = State(5, true, [1,2,3,4]);
    auto esu1    = ElevatorStateUpdate(state1.to!string);
    auto esu1_s  = esu1.to!string;
    t.send(esu1_s);

    auto peerList1  = PeerList(4, [4,5,6]);
    auto plu1       = PeerListUpdate(peerList1.to!string);
    auto plu1_s     = plu1.to!string;
    t.send(plu1_s);


    while(true){
        receive(
            (ElevatorStateUpdate esu){
                auto st = State(esu.state);
                writeln("Decoded: ", st);
            },
            (PeerListUpdate plu){
                auto pl = PeerList(plu.peerList);
                writeln("Decoded: ", pl);
            },
            (Variant v){
                writeln("Received variant ", typeid(v), v);
            }
        );
    }
}


template translator(T...){
    void translator(){
        while(true){
            receive(
                (string s){
                    foreach(t; T){
                        static if(is(t == struct)  &&  typeof(t.tupleof).length == 1  &&  is(typeof(t.tupleof.stringof) == string)){
                            mixin(
                    "if(s.skipOver(\"" ~ t.stringof ~ "(\\\"\")){
                        ownerTid.send(" ~ t.stringof ~ "(s));
                        return;
                    }"
                            );
                        } else {
                            static assert(false, "Translator types need to be a struct with only one string member");
                        }
                    }
                    ownerTid.send(s);
                }
            );
        }
    }
}



string genConstructor(T)(){
    string c0;  // imports
    string c1;  // constructor from string
    string c2;  // constructor from types: parameter list
    string c3;  // constructor from types: assignment

    c0 = "import std.conv:      parse;\n"
         "import std.algorithm: skipOver, countUntil;\n\n";

    c1 ~=  "this(string s){\n" ~
                    "    s.skipOver(\"" ~ T.stringof ~ "(\");";
    c2 ~= "this(";
    foreach(i, memberType; typeof(T.tupleof)){
        if(memberType.stringof == "string"){
            c1 ~=  "\n    s = s[1..$];\n    " ~
                   T.tupleof[i].stringof ~ " = s[0..s.countUntil(\"\\\"\")];";
            if(i < typeof(T.tupleof).length - 1){
                c1 ~= "   s = s[s.countUntil(\"\\\"\")+3..$];";
            }
        } else {
            c1 ~=  "\n    " ~ T.tupleof[i].stringof ~
                            " = s.parse!(" ~ memberType.stringof ~
                            ");";
            if(i < typeof(T.tupleof).length - 1){
                c1 ~= "   s = s[2..$];";
            }
        }

        c2 ~= memberType.stringof ~ " " ~ T.tupleof[i].stringof;
        c3 ~= "\n    this." ~ T.tupleof[i].stringof ~ " = " ~ T.tupleof[i].stringof ~ ";";

        if(i < typeof(T.tupleof).length - 1){
            c2 ~= ", ";
        }
    }
    c1 ~= "\n}\n\n";
    c2 ~= "){";
    c3 ~= "\n}";

    return c0 ~ c1 ~ c2 ~ c3;
}
