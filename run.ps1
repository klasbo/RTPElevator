cls;
$res = dmd -w -g -ofRTPElevator (gci -r -i *.d | ? {$_ -notmatch 'workbench'} | ? {$_ -notmatch 'sim_interface'});
if ($LASTEXITCODE -eq 0){
    try {
        "Running"
        .\RTPElevator.exe
    } finally {
        rm .\RTPElevator.exe
        rm .\RTPElevator.obj
    }
}