clear;
rm -f RTPElevator;
rm -f RTPElevator.o;
gcc -std=gnu11 -Wall -c src/elevio/elev.c -o obj/elev.o;
gcc -std=gnu11 -Wall -c src/elevio/io.c -o obj/io.o;
dmd -w -g -ofRTPElevator $(find src/ -name "*.d") obj/elev.o obj/io.o -L-lcomedi -L-lm