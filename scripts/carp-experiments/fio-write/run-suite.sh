#!/bin/bash

FIO_PREFIX=/users/ankushj/repos/carp-misc/fio-prefix
FIO=$FIO_PREFIX/bin/fio

WORKING_DIR=/mnt/lt20ad1/tmp
CSVFILE=fio-stats.csv

gen_hostfile() {
  echo "Generating hosts.txt with $1 hosts"
  HOSTFILE=hosts.txt
  rm $HOSTFILE || /bin/true

  for i in $(seq 0 $(($1 - 1))); do
    echo h$i >> $HOSTFILE
  done
}

prepare_jobfiles() {
  ALL_BLOCKSZ=( 10m 48m 372m )
  EPSZ=372

  NUM_EPS=( 1 3 6 9 12 )


  for BLOCKSZ in ${ALL_BLOCKSZ[@]}; do
    echo "Preparing jobfiles for blocksz: $BLOCKSZ"

    PREF=bs${BLOCKSZ}
    mkdir -p $PREF
    rm $PREF/*
    for EPCNT in ${NUM_EPS[@]}; do
      FIO_OUT=$PREF/write_b${BLOCKSZ}_ep$EPCNT.fio

      FILESZ=$(( EPSZ * EPCNT ))m
     DIROUT=$WORKING_DIR BLOCKSZ=$BLOCKSZ FILESZ=$FILESZ envsubst < write_ep.fio.template > $FIO_OUT
    done
  done

  echo -e "Preparing done.\n\n"
}

prepare() {
  echo ">>> Ensure that fio servers are running on all nodes!!"
  echo "Run command: $ fio --server"

  sleep 5

  echo "Deleting $CSVFILE... "

  sleep 5

  # JOBFILE=fio_test_$(date '+%Y-%m-%d_%H.%M.%S').json
  JOBFILE=fio_test.csv
  echo "Job output will be written to: $JOBFILE"

  JOBDIR=/mnt/lt20ad1/tmp
  echo "Job will write data to $JOBDIR"

  NHOSTS=32
  gen_hostfile $NHOSTS

  mkdir -p $WORKING_DIR
}

reset() {
  rm -rf $WORKING_DIR/*
  sleep 15
}

run() {
  # fio --bandwidth-log  --output-format=json --client=h0 --client=h1 writeseq.fio
  # fio --client=h0 --client=h1 --remote-args writeseq.fio
  CMD="--client=hosts.txt --output-format=json --output=$JOBFILE  $1"
  echo "Running fio..." echo fio $CMD

  fio $CMD
}

parse_njobs() {
  jobhostcnt=$(cat $JOBFILE |\
    jq '.client_stats[] | { "jobname": .jobname, "hostname": .hostname}' |\
    grep jobname | grep -v "All clients" | wc -l)

  echo "Job log reports benchmark data from $jobhostcnt clients"
}

parse_summary() {
  # cat $JOBFILE | jq '.client_stats[-1] | .write | keys'
  # cat $JOBFILE | jq '.client_stats[] | .write.bw'
  # cat $JOBFILE | jq '.client_stats[-1] | .write.bw'
  echo -e "\nSummary:"
  cat $JOBFILE |\
    jq '.client_stats[-1] | .write | to_entries[] 
      | select(.key as $k | ["io_bytes", "bw", "runtime"] 
      | index($k)) | "\(.key)=\(.value)"'

  csv_str=$(cat $JOBFILE |\
    jq '.client_stats[-1] | .write | [.io_bytes, .bw, .runtime] | @csv' -r)
  gen_csv $csv_str $1
}

gen_csv() {
  HEADER="job,io_bytes,bw,runtime"

  if [ ! -f $CSVFILE ]; then
    echo $HEADER > $CSVFILE
  fi

  LINE=$1
  FILE=$2
  echo $FILE,$LINE >> $CSVFILE
}

run_suite() {
  prepare_jobfiles
  prepare
  reset

  all_blocksz=( 10m 48m 372m )
  epochs=( 1 3 6 9 12 )

  for blocksz in "${all_blocksz[@]}"; do
    for epoch in "${epochs[@]}"; do
      fio_file=bs$blocksz/write_b${blocksz}_ep$epoch.fio
      if [ ! -f $fio_file ]; then
        echo "$fio_file does not exist. Skipping"
      fi

      echo "Running $fio_file... "
      run $fio_file
      parse_njobs $fio_file
      parse_summary $fio_file
      reset
    done
  done

}

run_suite
