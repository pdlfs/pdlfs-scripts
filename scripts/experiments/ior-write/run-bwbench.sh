#!/usr/bin/env bash

set -eux

MPIBIN=""
MPICC=${MPIBIN}mpicc
MPIRUN=${MPIBIN}mpirun
BENCH_BIN=`pwd`/bw-bench
TESTDIR=/mnt/lt20ad1/fio-jobdir
LOGDIR=bw-logs
TRIM_SCRIPT=/users/ankushj/snips/scripts/fstrim-cluster.sh

trim_testdir() {
  mntpt=$(dirname $TESTDIR)
  testdir_ip=$(cat /etc/mtab | grep $mntpt | cut -d@ -f 1)
  echo "Trimming $testdir_ip"
  $TRIM_SCRIPT -c $testdir_ip
}

prepare() {
  /usr/bin/mpicc -o $BENCH_BIN -O3 bwbench.cc

  mkdir -p $TESTDIR
  mkdir -p $LOGDIR

  clean
}

run_bench() {
  WRITE_PATTERN=$1
  FSZ_M=$2

  CMD=$(echo $MPIRUN -n 512 -f hosts.txt $BENCH_BIN -b $BLKSZ_M -p $TESTDIR -s $FSZ_M -w $WRITE_PATTERN)
  echo "$CMD -> $LOGFILE"
  $CMD | tee $LOGFILE
}

clean() {
  rm $TESTDIR/test.* || /bin/true
  sleep 10
  trim_testdir
  sleep 20
}

run_bench_suite() {
  NTRIES=1
  ALL_NEPOCHS=(1 3 6 9 12)
  ALL_NEPOCHS=(1 3 6 9)
  ALL_WP=(0 1)
  EPOCHSZ=372

  prepare

  for TRY in $(seq $NTRIES); do
    for NEPOCHS in "${ALL_NEPOCHS[@]}"; do
      for WP in "${ALL_WP[@]}"; do
        DATASZ=$(( NEPOCHS * EPOCHSZ ))
        echo "[WP $WP] Try $TRY, $NEPOCHS epochs, writing ${DATASZ}M/rank"
        LOGFILE=$LOGDIR/log.wp$WP.ep$NEPOCHS.$TRY
        run_bench $WP $DATASZ
        clean
      done
    done
  done

}

run() {
  BLKSZ_M=1

  TESTDIR=/mnt/lt20ad1/fio-jobdir
  LOGDIR=bwlogs-lt20ad1
  run_bench_suite

  TESTDIR=/mnt/lt20ad2/fio-jobdir
  LOGDIR=bwlogs-lt20ad2
  run_bench_suite
}

run
