cls;
$res = dmd -w -g -ofRTPElevator (gci -r *.d | ? {$_ -notmatch 'lint'});
if ($LASTEXITCODE -eq 0){
    try {
        "Running"
        .\RTPElevator.exe
    } finally {
        rm .\RTPElevator.exe
        rm .\RTPElevator.obj
    }
}