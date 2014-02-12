module util.struct_constructor_mixin;

// Does not support backslash (and therefore escape sequences) in strings
//   Because struct to!string substitutes codes with escape sequences
//   (Eg char [10, 13]  =>  string "\n\r", which has length 4)
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