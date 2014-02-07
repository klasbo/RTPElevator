clear;
gcc -std=c99 -Wall -g -c elevator_driver/io.c -lcomedi -lm;
RES=$(dmd -w -g $(find . -name "*.d" -not -path "./lint/*") io.o -ofRTPElevator -L-lcomedi -L-lm)$?

if [ $RES -eq 0 ] ; then
    ./RTPElevator
fi

rm -r -f *.o;
rm RTPElevator;

