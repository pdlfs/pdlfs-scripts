#!/usr/bin/env bash
set -uxo

source run_common.sh

INSTALL_DIR=/users/ankushj/repos/carp-umb-install/mpich-1804-2

# /root/data for docker
DATA_PREFIX=/mnt/lustre/carp-big-run
JOB_DIR=/mnt/lt20ad2/carp-jobdir
# mkdir -p $DATA_PREFIX

# directory to read trace from
TRACEDIR=$DATA_PREFIX/particle.compressed.uniform

#number of timesteps to process from trace
EPCNT=1

# default parameters
RIDX=1
INTVL=500000
PVTCNT=2048
DROPLIM=0

# renegotiation policy: periodic
CARP_POLICY=InvocationPeriodic

# directory for carp output
SUITEDIR=$JOB_DIR/unnamed-suite

setup_carp() {
	EXPDIR=$BASEDIR
	VPICDIR=$EXPDIR/vpic
	PLFSDIR=$EXPDIR/plfs
	INFODIR=$EXPDIR/exp-info

	LOGFILE=$EXPDIR/log.txt

	# particle count is in millions
	# 1M particles across 16 ranks = 65536 part/rank
  PARTCNT=$(( 3355 * 100 ))

	mkdir -p $VPICDIR
	mkdir -p $PLFSDIR/particle
	mkdir -p $INFODIR
}

clean_storage() {
  fd RDB $JOB_DIR -x rm
}

check_ok() {
  ok_file=$BASEDIR/log.txt
  if [ ! -f "$ok_file" ]; then
    return 1
  fi

  ok_check=$(tail -1 $ok_file | egrep 'BYE$')
  if [ -z "$ok_check" ]; then
    return 1
  else
    return 0
  fi
}

run_carp_wparams() {
  rname=run$RIDX.epcnt$EPCNT.intvl$INTVL.pvtcnt$PVTCNT.drop$DROPLIM

  echo "Running $RIDX, $EPCNT, $INTVL, $PVTCNT, $DROPLIM, rundir: $rname"

  BASEDIR=$SUITEDIR/$rname

  check_ok $BASEDIR

  if [ $? == 0 ]; then
    echo ok
  else
    echo not ok
    setup_carp
    run_carp
    clean_storage
    sleep 60
  fi
}

run_carp_wparamsuite() {
  clean_storage
  sleep 15

  for RIDX in "${REPEATS[@]}"; do
    for INTVL in "${INTVLS[@]}"; do
      for PVTCNT in "${PVTCNTS[@]}"; do
        for DROPLIM in "${DROPLIMS[@]}"; do
          echo $RIDX, $EPCNT, $INTVL, $PVTCNT, $DROPLIM
          run_carp_wparams
        done
      done
    done
  done
}

dump_map_repfirst() {
  EPCNT=$1
  DUMP_MAP="0:$EPCNT"
  if [[ $EPCNT -gt 1 ]]; then
    DUMP_MAP=$DUMP_MAP,$(seq 1 $(( EPCNT - 1 )) | sed 's/$/:0/g' | paste -sd,)
  fi
  echo $DUMP_MAP
}

dump_map_allonce() {
  EPCNT=$1
  DUMP_MAP=$(seq 0 $(( EPCNT - 1 )) | sed 's/$/:1/g' | paste -sd,)
  echo $DUMP_MAP
}

run_carp_single_epoch() {
  EPCNT=1

  SUITEDIR=$JOB_DIR/carp-single
  run_carp_wparams
}

run_carp_suite_wdrop() {
  EPCNT=12
  SUITEDIR=$JOB_DIR/carp-suite-epcnt-$EPCNT

  REPEATS=( 1 2 3 4 5 6 )
  INTVLS=( 250000 500000 750000 1000000 )
  PVTCNTS=( 256 512 1024 2048 4096 8192 )
  DROPLIMS=( 0 6500000 7000000 7500000 )

  run_carp_wparamsuite
}

run_carp_suite_wodrop_repfirst() {
  SUITEDIR=$JOB_DIR/carp-suite-repfirst

  EPCNTS=( 1 3 6 9 12 )
  REPEATS=( 1 )
  INTVLS=( 250000 500000 750000 1000000 )
  PVTCNTS=( 256 512 1024 2048 4096 8192 )
  PVTCNTS=( 2048 )
  DROPLIMS=( 0 )

  for EPCNT in "${EPCNTS[@]}"; do
    DUMP_MAP=$(dump_map_repfirst $EPCNT)
    run_carp_wparamsuite
  done
}

run_carp_suite_wodrop_repfirst_allpvtcnt() {
  SUITEDIR=$JOB_DIR/carp-suite-repfirst-allpvtcnt

  EPCNTS=( 12 )
  REPEATS=( 4 )
  INTVLS=( 250000 500000 750000 1000000 )
  PVTCNTS=( 256 512 1024 2048 4096 8192 )
  DROPLIMS=( 0 )

  for EPCNT in "${EPCNTS[@]}"; do
    DUMP_MAP=$(dump_map_repfirst $EPCNT)
    run_carp_wparamsuite
  done
}

run_carp_suite_wodrop_allonce() {
  SUITEDIR=$JOB_DIR/carp-suite-allonce

  EPCNTS=( 1 3 6 9 12 )
  REPEATS=( 1 )
  INTVLS=( 250000 500000 750000 1000000 )
  PVTCNTS=( 256 512 1024 2048 4096 8192 )
  PVTCNTS=( 2048 )
  DROPLIMS=( 0 )

  for EPCNT in "${EPCNTS[@]}"; do
    DUMP_MAP=$(dump_map_allonce $EPCNT)
    run_carp_wparamsuite
  done
}

# run_carp_single_epoch
# run_carp_suite_wdrop
# run_carp_suite_wodrop_repfirst
# run_carp_suite_wodrop_allonce
run_carp_suite_wodrop_repfirst_allpvtcnt
# dump_map_repfirst 12
# dump_map_allonce 12
