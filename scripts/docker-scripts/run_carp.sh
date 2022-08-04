#!/usr/bin/env bash

source run_common.sh

INSTALL_DIR=/users/ankushj/repos/carp-umb-install/mpich-1804-2

# /root/data for docker
DATA_PREFIX=/root/data
mkdir -p $DATA_PREFIX

# directory to read trace from
TRACEDIR=$DATA_PREFIX/particle.compressed.sample

#number of timesteps to process from trace
TRACECNT=3

# renegotiation interval: 10000
INTVL=10000

# renegotiation policy: periodic
CARP_POLICY=InvocationPeriodic

# directory for carp output
SUITEDIR=$DATA_PREFIX/carp-jobdir/fig-5a-runtime

setup_carp() {
	EXPDIR=$BASEDIR
	VPICDIR=$EXPDIR/vpic
	PLFSDIR=$EXPDIR/plfs
	INFODIR=$EXPDIR/exp-info

	LOGFILE=$EXPDIR/log.txt

	# particle count is in millions
	# 1M particles across 16 ranks = 65536 part/rank
	PARTCNT=1

	mkdir -p $VPICDIR
	mkdir -p $PLFSDIR/particle
	mkdir -p $INFODIR
}

run_simple() {
	BASEDIR=$SUITEDIR
	setup_carp
	run_carp
}

run_simple
