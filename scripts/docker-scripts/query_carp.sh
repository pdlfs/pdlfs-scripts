#!/bin/bash

PLFSDIR=/root/data/carp-jobdir/fig-5a-runtime/plfs/particle
READER_BIN=/root/carp-install/bin/rangereader
PARALLELISM=4

# Analyze the output and print generic stats
$READER_BIN -i $PLFSDIR -a -p $PARALLELISM

# Read CARP output and trigger a query
# A query, in this example, queries all keys between 0.5 and 0.6 in epoch 0
$READER_BIN -i $PLFSDIR -p $PARALLELISM -q -e 0 -x 0.5 -y 0.6
