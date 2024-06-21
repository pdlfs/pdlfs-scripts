#!/usr/bin/env bash

FQ_LIB=/root/fastquery/install/lib
HDF_LIB=/root/fastquery/CMake-hdf5-1.10.7/HDF5-1.10.7-Linux/HDF_Group/HDF5/1.10.7/lib
QUERY_BIN=/root/fastquery/fastquery-0.8.4.3/examples/queryIndex
HDFFILE=/root/data/fastquery/particle.hdf5
IDXFILE=/root/data/fastquery/particle.hdf5.idx

ATTR_PATH="/Step#200"
ATTR="Ux"
QBEG=0.5
QEND=0.6

NUM_RANKS=1

mpirun -env LD_LIBRARY_PATH "$FQ_LIB;$HDF_LIB" -n $NUM_RANKS $QUERY_BIN -m H5PART -f $HDFFILE -i $IDXFILE -p $ATTR_PATH -n $ATTR -v 1 -q "Ux > $QBEG && Ux < $QEND" 2>&1
