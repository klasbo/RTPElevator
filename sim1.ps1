cls;
dmd -w -g -ofelev_simulator\simulator .\elev_simulator\sim_server.d .\elev_simulator\timer_event.d;

if($LASTEXITCODE -eq 0){
    .\elev_simulator\simulator.exe
}

