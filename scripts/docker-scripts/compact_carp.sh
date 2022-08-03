#!/usr/bin/env bash

COMPACTOR_BIN=/root/carp-install/bin/compactor
PLFS_DIR=/root/data/carp-jobdir/plfs/particle
SORT_DIR=/root/data/carp-jobdir/plfs/particle.sorted
NUM_EPOCHS=3

for epoch in $(seq 0 $((NUM_EPOCHS - 1))); do
	echo "Compacting Epoch $epoch"
	$COMPACTOR_BIN -i $PLFS_DIR -o $SORT_DIR -e $epoch
done
