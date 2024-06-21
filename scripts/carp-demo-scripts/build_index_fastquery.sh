#!/usr/bin/env bash

FQ_LIB=/root/fastquery/install/lib
HDF_LIB=/root/fastquery/CMake-hdf5-1.10.7/HDF5-1.10.7-Linux/HDF_Group/HDF5/1.10.7/lib
BUILD_BIN=/root/fastquery/fastquery-0.8.4.3/examples/buildIndex
HDFFILE=/root/data/fastquery/particle.hdf5
IDXFILE=/root/data/fastquery/particle.hdf5.idx
ATTR="Ux"

NUM_RANKS=1

mpirun -env LD_LIBRARY_PATH "$FQ_LIB;$HDF_LIB" -n $NUM_RANKS $BUILD_BIN -m H5PART -f $HDFFILE -i $IDXFILE -n $ATTR -r -v 1
