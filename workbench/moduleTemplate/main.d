module main;

import std.stdio;

import moduleOne, moduleTwo;


void main(){
    with(moduleOne.types!moduleTwoStructOne){
        moduleOneStructOne.init.writeln;
        moduleOneStructTwo.init.writeln;
        func.writeln;
    }
}