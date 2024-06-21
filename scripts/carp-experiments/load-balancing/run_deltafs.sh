#!/usr/bin/env bash

set -uxo pipefail

source run_common.sh

INSTALL_DIR=/users/ankushj/repos/dfsumb-install
JOBDIR=/mnt/lt20ad1/deltafs-jobdir
EPCNT=1

# default parameters
NRANKS=512
# particle count is in millions
# 1M particles across 16 ranks = 65536 part/rank
PARTCNT=$(( 3355 * 100 ))
# number of timesteps to process from trace
EPCNT=1
# run index
RIDX=1

reset() {
  fd idx $BASEDIR -x rm
  fd dat $BASEDIR -x rm
  sleep 30
}

setup_deltafs() {
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

run_deltafs_micro() {
  SUITEDIR=micro

  NRANKS=4
  EPCNT=1
  PARTCNT=$(( 26* 100 ))# 6.5M * 4 ranks
  FORCE=1 # run even if prev run completed

  BASEDIR=$SUITEDIR/deltafs-micro
  set_tc_params_dfs
  setup_deltafs
  run_deltafs
  reset
}

run_deltafs_baseline() {
  SUITEDIR=$JOBDIR/datascale-runs

  ALL_EPCNT=(1 3 6 9 12)
  # ALL_EPCNT=( 12 )
  ALL_RIDX=( 1 2 3 4 5 6 )

  for RIDX in "${ALL_RIDX[@]}"; do
    for EPCNT in "${ALL_EPCNT[@]}"; do
      echo $EPCNT
      BASEDIR=$SUITEDIR/run$RIDX.epcnt$EPCNT
      check_ok $BASEDIR

      if [ $? == 0 ] && [ !${FORCE+x} ]; then
        echo ok
      else
        echo not ok
        set_tc_params_dfs
        setup_deltafs
        run_deltafs || /bin/true
        reset
      fi
    done
  done
}

run_deltafs_scaleranks() {
  SUITEDIR=$JOBDIR/rankscale-runs

  ALL_EPCNT=( 1 3 6 9 12 )
  # ALL_EPCNT=( 12 )
  ALL_NRANKS=( 64 128 256 )
  ALL_RIDX=( 1 2 3 )

  for RIDX in "${ALL_RIDX[@]}"; do
    for NRANKS in "${ALL_NRANKS[@]}"; do
      for EPCNT in "${ALL_EPCNT[@]}"; do
        echo $EPCNT
        BASEDIR=$SUITEDIR/run$RIDX.nranks$NRANKS.epcnt$EPCNT
        echo $BASEDIR
        check_ok $BASEDIR

        if [ $? == 0 ] && [ !${FORCE+x} ]; then
          echo ok
        else
          echo not ok
          set_tc_params_dfs
          setup_deltafs
          run_deltafs || /bin/true
          reset
        fi
      done
    done
  done
}

init_common_vars

# THROTTLE_MB=3
# SKIPREALIO=1
run_deltafs_micro
#run_deltafs_baseline
#run_deltafs_scaleranks
