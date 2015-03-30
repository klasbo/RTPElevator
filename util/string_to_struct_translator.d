module util.string_to_struct_translator;

import  std.traits,
        std.concurrency,
        std.string,
        std.conv,
        std.range,
        std.algorithm;
        

template stringToStructTranslator_thr(T...){
    void stringToStructTranslator_thr(){
        while(true){
            receive(
                (Tid discard, string s){
                    foreach(t; T){
                        static if(is(t == struct)){ 
                            static if(!std.traits.hasUnsharedAliasing!t){
                            
                    if(s.startsWith(t.stringof)){
                        ownerTid.send(s.construct!t);
                        return;
                    }
                    
                            } else {
                                static assert(false, "stringToStructTranslator types must not have unshared aliasing. (Violated by " ~ t.stringof ~ ")");
                            }
                        } else {
                            static assert(false, "stringToStructTranslator types need to be structs. (Violated by " ~ t.stringof ~ ")");
                        }
                    }
                    ownerTid.send(s);
                },
                (Variant v){
                    ownerTid.send(v);
                }
            );
        }
    }
}

T construct(T)(string str) if(is(T == struct)){

    T inst;

    string typeName = typeid(T).name;    
    str.skipOver(typeName[typeName.lastIndexOf(".")+1 .. $]);
        
    alias names = FieldNameTuple!T;
    foreach(idx, type; FieldTypeTuple!T){
        str.popFront;
        
        static if(is(type == string)){
            str.popFront;   // pop opening quote
            __traits(getMember, inst, names[idx]) = str[0 .. str.indexOf("\"")];
            str.findSkip("\"");
        } else static if(is(type == struct)){
            __traits(getMember, inst, names[idx]) = str.construct!type;
        } else {
            __traits(getMember, inst, names[idx]) = str.parse!type;
        }
        
        str.popFront;
    }
    
    return inst;
}