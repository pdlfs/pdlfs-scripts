#!/usr/bin/env bash

VPIC_BIN=/root/carp-umbrella/build/carp-prefix/src/carp/scripts/vpic-magrecon-deck-modified-3584M/reconnection512.Linux
VPIC_PWD=~/data/vpic_out_big

mkdir -p $VPIC_PWD
cd $VPIC_PWD

# run VPIC, large scale. mpirun needs to be configured appropriately for a larger cluster
mpirun -n 512 $VPIC_BIN

# consumes $VPIC_PWD/particle, generates $VPIC_PWD/particle.compressed
python /root/carp-install/scripts/workload_parser.py $VPIC_PWD/particle
