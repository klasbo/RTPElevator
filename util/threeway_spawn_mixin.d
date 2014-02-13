module util.threeway_spawn_mixin;

import  std.conv,
        std.algorithm,
        std.string,
        std.stdio;

public:

/+
Declare all Tids
spawn threads with params
               ->           reply xs
Expect xs from each            <-
Signal ys (and Tids)
               ->           await ys (and Tids)
//Handshake complete
+/

/**
    [  "thread:thrName thrFunc,
        params:p1 p2,
        expect:e1 e2,
        signal:s1 s2" ]
    Declares all thrNames
    Spawns all thrFuncs with params p#, and assignes them to their respective thrNames
    Expects to receive confirmation from spawned thread with types of e#, and assignes received types to variables e#
    Signals all threads when spawning/expecting phase is done, and sends s# as parameters
    If shareThreads is true: sends Tids of all threads along with signals
        reciprocate3way must then use "threads:t#" to receive these Tids
    If linked is true: use spawnLinked() instead of spawn()
*/
string spawn3way(string[] threads, bool shareThreads, bool linked = false){
    int             numThreads      = threads.length;
    string[]        threadsByName   = new string[](numThreads);
    string[]        threadsByFunc   = new string[](numThreads);
    string[][]      params          = new string[][](numThreads);
    string[][]      expect          = new string[][](numThreads);
    string[][]      signal          = new string[][](numThreads);
    string[] meta;


    foreach(i, thread; threads){
        string[] spawnInfo  = thread.split(",");
        auto numArgs = spawnInfo.length;
        typeof(numArgs) j;

        spawnInfo[j] = spawnInfo[j].strip;
        if(spawnInfo[j].skipOver("thread:")){
            meta = spawnInfo[j].strip.split;
            threadsByName[i] = meta[0];
            threadsByFunc[i] = meta[1];
            meta.clear;
            j++;
        } else {
            assert(0, "No thread specified for element " ~ i.to!string);
        }

        mixin(parseArg("params"));
        mixin(parseArg("expect"));
        mixin(parseArg("signal"));

        spawnInfo.clear;
    }

    string out1 = threadsByName.map!(a => ("Tid " ~ a ~ ";\n")).reduce!("a ~ b");

    string out2;
    foreach(i; 0..numThreads){
        out2 ~=
        (linked
            ? threadsByName[i] ~ " = spawnLinked( &" ~ threadsByFunc[i]
            : threadsByName[i] ~ " = spawn( &" ~ threadsByFunc[i]        ) ~
        params[i].mapConcat!( a => ", " ~ a ) ~
        " );
        receive(
            (Tid t" ~
            expect[i].mapConcat!( a => ", typeof("~a~") "~a~"_t" ) ~
            "){
                assert(t == " ~ threadsByName[i] ~ ");
                " ~
                expect[i].mapConcat!( a => a ~ " = " ~ a ~ "_t; " ) ~ "
            },
            (Variant v){
                writeln(v);
                assert(0, \"Thread " ~ threadsByFunc[i] ~ " did not return \\\"(Tid" ~
                        expect[i].mapConcat!( a => ", typeof("~a~")" ) ~
                    ")\\\"\");
            }
        );
        ";
    }

    string out3;
    foreach(i; 0..numThreads){
        out3 ~=
        threadsByName[i] ~ ".send( thisTid " ~
        (shareThreads ? threadsByName.map!( a => ", " ~ a ).reduce!("a ~ b") : "") ~
        signal[i].mapConcat!( a => ", " ~ a ) ~
        " );
        ";

    }

    return out1 ~ out2 ~ out3 ~ "pragma(msg, \"mixin last line: \"); pragma(msg, __LINE__);";
}

/**
    "threads:t1 t2, reply:r1 r2, await: a1 a2"
    Declare Tids of threads, if any
    When init done, reply with r#
    Await signal from owner with data of types a#, and assign to a#
    Assign received Tids of shared threads (comes with signal)
*/
string reciprocate3way(string stuff){
    string[] spawnInfo = stuff.split(",");
    auto numArgs = spawnInfo.length;
    string[][] threads = new string[][](1);
    string[][] reply = new string[][](1);
    string[][] await = new string[][](1);
    string[] meta;
    typeof(numArgs) j;

    foreach(i; 0..1){
        mixin(parseArg("threads"));
        mixin(parseArg("reply"));
        mixin(parseArg("await"));
    }


    return
    threads[0].mapConcat!( a => "Tid " ~ a ~ ";\n" ) ~
    "ownerTid.prioritySend(thisTid" ~
    reply[0].mapConcat!( a => ", " ~ a ) ~
    ");
    receive(
        (Tid t" ~
            threads[0].mapConcat!( a => ", Tid "~a~"_t" ) ~
            await[0].mapConcat!( a => ", typeof("~a~") "~a~"_t" ) ~
            "){
                assert(t == ownerTid, \"Returning handshake failed: The Tid is not the owner\");
                " ~
                threads[0].mapConcat!( a => a ~ " = " ~ a ~ "_t; " ) ~
                await[0].mapConcat!( a => a ~ " = " ~ a ~ "_t; " ) ~ "
        },
        (Variant v){
            writeln(v);
            assert(0, \"Returning handshake failed: Received \\\"(\" ~ v.to!string ~ \")\\\" Instead of \\\"(Tid" ~
                    await[0].mapConcat!( a => ", typeof("~a~")" ) ~
                ")\\\"\");
        }
    );
    ";
}



private:
string parseArg(string type){
    return
    "
    if(j>=numArgs){ continue; }
    spawnInfo[j] = spawnInfo[j].strip;
    if(spawnInfo[j].skipOver(\""~type~":\")){

        meta = spawnInfo[j].split;
        if(meta.length){
            "~type~"[i] = meta.dup;
        }
        meta.clear;
        j++;
    }";
}


template mapConcat(fun...) if (fun.length >= 1)
{
    string mapConcat(Range)(Range r)
    {
        return (r.length
                ?
                r.map!(fun).reduce!("a ~ b")
                :
                "" );
    }
}
