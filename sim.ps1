cls;
$res = dmd -w -g sim_interface.d;
if ($LASTEXITCODE -eq 0){
    try {
        .\sim_interface.exe
    } finally {
        rm .\sim_interface.exe
        rm .\sim_interface.obj
    }
}