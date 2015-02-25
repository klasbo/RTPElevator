clear;
RES=$(dmd -w -g sim_interface.d)$?

if [ $RES -eq 0 ] ; then
    ./sim_interface
fi

rm -r -f sim_interface.o;
rm sim_interface;

