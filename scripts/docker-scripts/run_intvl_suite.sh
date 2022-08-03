#!/usr/bin/env bash

source run_common.sh

# directory to read trace from
TRACEDIR=/root/data/particle.compressed.sample

#number of timesteps to process from trace
TRACECNT=3

# renegotiation intervals to run
INTVLS=( 2500 5000 10000 )

# renegotiation policy: periodic
CARP_POLICY=InvocationPeriodic

# directory for carp output
SUITEDIR=/root/data/carp-jobdir/fig-7-intvls

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

run_intvl_suite(){
	for INTVL in "${INTVLS[@]}"; do
		echo "Running With Interval: $INTVL"
		BASEDIR=$SUITEDIR/intvl.$INTVL
		setup_carp
		run_carp
	done
}

run_intvl_suite
