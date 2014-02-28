cls;
$res = dmd -w -g -ofRTPElevator (gci -r -i *.d | ? {$_ -notmatch 'lint' -and $_ -notmatch 'workbench'});
if ($LASTEXITCODE -eq 0){
    try {
        "Running"
        .\RTPElevator.exe
    } finally {
        rm .\RTPElevator.exe
        rm .\RTPElevator.obj
    }
}