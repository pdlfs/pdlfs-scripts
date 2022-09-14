#!/usr/bin/env bash

set -euxo pipefail

source run_common.sh

INSTALL_DIR=/users/ankushj/repos/dfsumb-install
JOBDIR=/mnt/lt20ad1/deltafs-jobdir
EPCNT=1

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

run_deltafs_baseline() {
  ALL_EPCNT=(1 3 6 9 12)

  for EPCNT in "${ALL_EPCNT[@]}"; do
    echo $EPCNT
    BASEDIR=$JOBDIR/deltafs-baseline-3584M-ep$EPCNT
    setup_deltafs
    run_deltafs
    reset
  done
}

run_deltafs_baseline
