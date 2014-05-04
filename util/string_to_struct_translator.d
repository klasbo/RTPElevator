module util.string_to_struct_translator;

import  std.traits,
        std.concurrency,
        std.algorithm;
        
import  types;

import std.stdio;


template stringToStructTranslator_thr(T...){
    void stringToStructTranslator_thr(){
        while(true){
            receive(
                (Tid discard, string s){
                    foreach(t; T){
                        static if(is(t == struct)){ 
                            static if(!std.traits.hasLocalAliasing!t){
                                mixin(
                    "if(s.startsWith(\"" ~ t.stringof ~ "(\")){
                        ownerTid.send(" ~ t.stringof ~ "(s));
                        return;
                    }"
                                );
                            } else {
                                static assert(false, "stringToStructTranslator types must not have local aliasing. (Violated by " ~ t.stringof ~ ")");
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