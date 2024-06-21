#!/usr/bin/env bash

set -eu

INSTALL_PREFIX=/l0/install
source $INSTALL_PREFIX/paths.sh
source $INSTALL_PREFIX/run_common.sh

# directory to read trace from
TRACEDIR=/root/data/particle.compressed.sample

#number of timesteps to process from trace
TRACECNT=3

# renegotiation interval: 10000
INTVL=10000

# directory for carp output
SUITEDIR=/root/data/carp-jobdir/fig-6-dyn-vs-static

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

run_dyn_stat_suite(){
	CARP_POLICY=InvocationOnce
	BASEDIR=$SUITEDIR/policy.static
	setup_carp
	run_carp

	CARP_POLICY=InvocationPeriodic
	BASEDIR=$SUITEDIR/policy.dynamic
	setup_carp
	run_carp
}

run_dyn_stat_suite

