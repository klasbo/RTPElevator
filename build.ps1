dmd -unittest -w -g $(gci src -Recurse "*.d" | % {$_.FullName}) -ofRTPElevator;