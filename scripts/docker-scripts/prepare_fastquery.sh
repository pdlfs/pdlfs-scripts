#!/usr/bin/env bash

BIN=/root/carp-install/bin/vpicwriter
DATA_IN=/root/data/particle.compressed.sample
DATA_OUT=/root/data/fastquery/particle.hdf5

mpirun -n 32 $BIN -i $DATA_IN -o $DATA_OUT
