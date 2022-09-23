#!/usr/bin/env bash

source ../common.sh
source run_common.sh

# /root/data for docker
DATA_PREFIX=/mnt/lustre/carp-big-run
JOB_DIR=/mnt/lt20ad1/carp-jobdir
# mkdir -p $DATA_PREFIX

# directory to read trace from
TRACEDIR=$DATA_PREFIX/particle.compressed.uniform

# default parameters
NRANKS=512
# particle count is in millions
# 1M particles across 16 ranks = 65536 part/rank
PARTCNT=$(( 3355 * 100 ))
# number of timesteps to process from trace
EPCNT=1
# run index
RIDX=1
# reneg interval
INTVL=500000
PVTCNT=2048
# per rank/epoch max particle limit (0: not set)
DROPLIM=0

# renegotiation policy: periodic
CARP_POLICY=InvocationPeriodic

# directory for carp output
SUITEDIR=$JOB_DIR/unnamed-suite

setup_carp() {
  set_tc_params

	EXPDIR=$BASEDIR
	VPICDIR=$EXPDIR/vpic
	PLFSDIR=$EXPDIR/plfs
	INFODIR=$EXPDIR/exp-info

	LOGFILE=$EXPDIR/log.txt

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
  rname=run$RIDX.nranks$NRANKS.epcnt$EPCNT.intvl$INTVL.pvtcnt$PVTCNT.drop$DROPLIM

  echo "Running $RIDX, $NRANKS, $EPCNT, $INTVL, $PVTCNT, $DROPLIM, rundir: $rname"

  BASEDIR=$SUITEDIR/$rname

  check_ok $BASEDIR

  if [ $? == 0 ] && [[ ! -v FORCE ]]; then
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

run_carp_micro() {
  NRANKS=4
  EPCNT=1
  PARTCNT=$(( 26 * 100 )) # 6.5M * 4 ranks 
  INTVL=500000
  FORCE=1 # run even if prev run completed

  DUMP_MAP=$(dump_map_repfirst $EPCNT)

  SUITEDIR=$JOB_DIR/carp-micro
  run_carp_wparams
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
  REPEATS=( 1 2 3 4 5 6 )
  INTVLS=( 250000 500000 750000 1000000 )
  INTVLS=( 750000 1000000 )
  PVTCNTS=( 256 512 1024 2048 4096 8192 )
  PVTCNTS=( 2048 )
  DROPLIMS=( 0 )

  for EPCNT in "${EPCNTS[@]}"; do
    DUMP_MAP=$(dump_map_repfirst $EPCNT)
    echo $NRANKS, $EPCNT
    run_carp_wparamsuite
  done
}

run_carp_suite_wodrop_repfirst_scaleranks() {
  SUITEDIR=$JOB_DIR/carp-suite-repfirst-scaleranks

  ALL_NRANKS=( 64 128 256 )
  EPCNTS=( 1 3 6 9 12 )
  REPEATS=( 1 2 3 4 5 6 )
  REPEATS=( 1 2 3 )
  INTVLS=( 250000 500000 750000 1000000 )
  INTVLS=( 1000000 )
  PVTCNTS=( 2048 )
  DROPLIMS=( 0 )

  for NRANKS in "${ALL_NRANKS[@]}"; do
    for EPCNT in "${EPCNTS[@]}"; do
      DUMP_MAP=$(dump_map_repfirst $EPCNT)
      echo $NRANKS, $EPCNT
      run_carp_wparamsuite
    done
  done
}

run_carp_suite_wodrop_repfirst_allpvtcnt() {
  SUITEDIR=$JOB_DIR/carp-suite-repfirst-allpvtcnt
  set_tc_params
  SUITEDIR_FIXED=$SUITEDIR

  echo $SUITEDIR
  sleep 5

  EPCNTS=( 1 3 6 9 )
  EPCNTS=( 12 )
  REPEATS=( 2 )
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

gen_hostfile_from_ui
init_common_vars

# THROTTLE_MB=3
# SKIPREALIO=1

# suites: uncomment one
run_carp_micro
# run_carp_single_epoch
# run_carp_suite_wdrop
# run_carp_suite_wodrop_repfirst
# run_carp_suite_wodrop_repfirst_scaleranks
# run_carp_suite_wodrop_allonce
# run_carp_suite_wodrop_repfirst_allpvtcnt
