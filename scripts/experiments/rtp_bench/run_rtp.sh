#!/usr/bin/env bash

source ../common.sh

RTP_BENCH=$INSTALL_DIR/bin/rtp-bench-runner
CSV_FILE=rtp-bench-runs-ipoib.csv

poll_cluster() {
  CLUSNAME=$1
  NNODES=$2

  for n in $(seq 0 $(( NNODES - 1 ))); do
    host=h$n.$CLUSNAME.tablefs
    host_ip=$(ssh $host "ifconfig | egrep -o 'inet 10.94[^\ ]*' | cut -d' ' -f 2")
    if [ "$host_ip" != "" ]; then
      echo $host, $host_ip
      echo $host_ip:16 >> hosts.$CLUSNAME.txt
    fi
  done
}

poll_all() {
  rm hosts.*.txt

  poll_cluster carpib06nok 6
  poll_cluster carpib34 34
  poll_cluster carpib34v3 34
  poll_cluster carpib60 60

  cat hosts.*.txt > hosts.txt
}

run_one() {
  nranks=$1
  nrounds=$2
  pvtcnt=$3
  logfile=$4

  mpirun -f hosts.txt -n $nranks \
    -ppn 16 \
   -env SHUFFLE_Mercury_proto bmi+tcp \
   -env SHUFFLE_Subnet 10.94 \
   $RTP_BENCH -n $nrounds -p $pvtcnt 2>&1 | tee $logfile
}

run_micro() {
  NRANKS=8
  NROUNDS=1
  PVTCNT=256
  LOGFILE=log.txt

  echo "h0-dib:16" > hosts.txt

  run_one $NRANKS $NROUNDS $PVTCNT $LOGFILE

  rm hosts.txt
}

run_all() {
  NROUNDS=( 1 10 100 )
  NROUNDS=( 100 )
  NNODES=( 1 2 4 8 16 32 64 128 )
  ALL_PVTCNT=( 256 512 1024 2048 4096 8192 )

  for nrounds in "${NROUNDS[@]}"; do
    echo $nrounds
    for n in "${NNODES[@]}"; do
      for npivots in "${ALL_PVTCNT[@]}"; do
        nranks=$(( n * 16 ))
        logfile=ranks.$nranks.txt
        echo $n, $nranks
        run_one $nranks $nrounds $npivots $logfile
        parse_logfile $logfile
      done
    done
  done
  return
}

parse_logfile() {
  logfile=$1
  times=$(cat $logfile | grep Rounds | egrep -o '[0-9]+\.?[0-9]*us' | sed 's/us//g' | paste -sd,)
  rounds=$(cat $logfile | egrep -o 'Rounds: [0-9]+' | sed 's/Rounds:\ //g')
  nranks=$(echo $logfile | egrep -o '[0-9]+')

  if [ ! -f "$CSV_FILE" ]; then
    echo "nranks,rounds,npivots,mean,std,min,max" > $CSV_FILE
  fi
  echo $nranks,$rounds,$npivots,$times >> $CSV_FILE
}

run_micro
# run_all
# poll_all
