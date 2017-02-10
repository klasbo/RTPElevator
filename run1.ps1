cls;
dmd -unittest -w -g $(gci src -Recurse "*.d" | % {$_.FullName}) -ofRTPElevator;
if($LASTEXITCODE -eq 0){
    .\RTPElevator.exe
}