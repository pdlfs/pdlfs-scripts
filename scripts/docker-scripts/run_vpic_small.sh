#!/usr/bin/env bash

VPIC_BIN=/root/carp-umbrella/build/carp-prefix/src/carp/scripts/vpic-magrecon-deck-modified-3584M/reconnection.Linux
VPIC_PWD=~/data/vpic_out_small

mkdir -p $VPIC_PWD
cd $VPIC_PWD

# run VPIC, small scale. should be doable on a smaller cluster
mpirun -n 32 $VPIC_BIN

# consumes $VPIC_PWD/particle, generates $VPIC_PWD/particle.compressed
python /root/carp-install/scripts/workload_parser.py $VPIC_PWD/particle
