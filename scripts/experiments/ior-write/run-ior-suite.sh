#!/usr/bin/env bash

set -u

source ../common.sh

TESTDIR=/mnt/lt20ad1/fio-jobdir
LOGFILE=ior-logs.csv
IOR_PREFIX=/users/ankushj/repos/carp-misc/ior-prefix

IOR=$IOR_PREFIX/bin/ior
MPIRUN=mpirun

prepare() {
  mkdir -p $TESTDIR
  rm -rf $TESTDIR/*

  sleep 5
}

clean() {
  rm $TESTDIR/*
}

invoke_ior() {
  MPISTR=$1
  NEPOCHS=$2
  EPOCHSZ=372
  BLOCKSZ=1m

  WRITESZ=$(( NEPOCHS * EPOCHSZ ))M

  echo "Writing $WRITESZ per rank ($NEPOCHS epochs)"
  IOR_FLAGS="-w -F -o $TESTDIR/test.dat -t $BLOCKSZ -b $WRITESZ -k -e"
  echo -e "Running: ior $IOR_FLAGS\n"

  $MPISTR $IOR $IOR_FLAGS > tmp
  cat tmp | grep 'iter' -A 2 | tee tmp
  log_run
  rm tmp
}

log_run() {
  run_hdr=$(cat tmp | grep 'iter' | sed 's/\ \ */,/g')
  run_line=$(cat tmp | grep 'iter' -A 2 | grep 'write' | sed 's/\ \ */,/g')

  run_hdr="testdir,nranks,epcnt,epsz,wrsz,blksz,$run_hdr"
  run_line="$TESTDIR,$NRANKS,$NEPOCHS,$EPOCHSZ,$WRITESZ,$BLOCKSZ,$run_line"

  if [ ! -f $LOGFILE ]; then
    echo $run_hdr > $LOGFILE
  fi

  echo $run_line >> $LOGFILE
}

run_mpich() {
  NRANKS=$1
  NEPOCHS=$2
  MPISTR="$MPIRUN -np $NRANKS -map-by node -hostfile hosts.txt"

  echo "Num Ranks: $NRANKS"
  echo "MPI cmd: $MPISTR"

  invoke_ior "$MPISTR" $NEPOCHS
}

run_suite_mpich() {
  NHOSTS=32
  NTRIES=3

  ALL_NRANKS=(16 64 512)
  ALL_NEPOCHS=(1 3 6 9 12)

  gen_hostfile $NHOSTS h -dib:16

  for TRY in $(seq $NTRIES); do
    for NRANKS in "${ALL_NRANKS[@]}"; do
      for NEPOCHS in "${ALL_NEPOCHS[@]}"; do
        echo "Try $TRY: $NRANKS ranks, $NEPOCHS epochs"

        prepare
        run_mpich $NRANKS $NEPOCHS
        clean

      done
    done
  done
}

run_suite() {
  TESTDIR=/mnt/lt20ad1/fio-jobdir
  BLOCKSZ=1m
  run_suite_mpich

  BLOCKSZ=48m
  run_suite_mpich

  TESTDIR=/mnt/lt20ad2/fio-jobdir
  BLOCKSZ=1m
  run_suite_mpich

  BLOCKSZ=48m
  run_suite_mpich

  TESTDIR=/mnt/ltio/fio-jobdir
  BLOCKSZ=1m
  run_suite_mpich

  BLOCKSZ=48m
  run_suite_mpich
}

run_suite
