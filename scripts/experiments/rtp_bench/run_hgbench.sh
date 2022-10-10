#!/usr/bin/env bash

INSTALL_ROOT=/users/ankushj/repos/carp-umb-tmp/install
hg_bin=$INSTALL_ROOT/bin/mercury-runner

set -u

get_hostname() {
  echo $(hostname | cut -d. -f 1)
}

extract_op_us() {
  time_sec=$(cat log.$hg_client | grep op | egrep -o '\(.*\)' | sed 's/(//g'  | awk '{ print $1 }')
  time_usec=$(bc <<< $time_sec*1000000)
  op_us=${time_usec%.*}
}

run_bench() {
  hg_server=${hg_server:-"h0"}
  hg_client=${hg_client:-"h1"}
  hg_poll=${hg_poll:-"false"}
  hg_insz=${hg_insz:-"64"}
  hg_outsz=${hg_outsz:-"64"}
  hg_count=${hg_count:-"100"}
  hg_limit=${hg_limit:-"1"}
  hg_ninst=${hg_ninst:-"1"}
  hg_protostr=${hg_protostr:-"bmi+tcp"}

  hg_flags=""
  hg_flags="$hg_flags -d $(pwd)"
  hg_flags="$hg_flags -i $hg_insz"
  hg_flags="$hg_flags -o $hg_outsz"
  hg_flags="$hg_flags -c $hg_count"
  hg_flags="$hg_flags -l $hg_limit"

  if [[ "$hg_poll" != "false" ]]; then
    hg_flags="$hg_flags -P"
  fi

  hg_flags="$hg_flags -q"

  our_hostname=$(get_hostname)
  if [[ "$our_hostname" != "$hg_server" ]]; then
    echo "!!! ERROR !!! This script is supposed to be run on $hg_server"
    return -1
  fi

  hg_flags_server="$hg_flags -m s $hg_ninst $hg_server=$hg_protostr"
  hg_flags_client="$hg_flags -m c $hg_ninst $hg_client=$hg_protostr $hg_server"

  cmd_server="$hg_bin $hg_flags_server"
  cmd_client="$hg_bin $hg_flags_client"
  echo "[mercury-runner-server] $cmd_server"
  echo "[mercury-runner-client] $cmd_client"

  $cmd_server > log.$hg_server &
  ssh $hg_client "$cmd_client" | tee log.$hg_client

  killall $(basename $hg_bin)

  log_bench
  rm log.$our_hostname
}

log_bench() {
  extract_op_us

  log_hdr="server,client,poll,insz,outsz,count,limit,proto,time_us"
  log_vals="$hg_server,$hg_client,$hg_poll,$hg_insz,$hg_outsz,$hg_count,$hg_limit,$hg_protostr,$op_us"

  if [[ ! -f $bm_log ]]; then
    echo $log_hdr > $bm_log
  fi

  echo $log_vals >> $bm_log

  echo "-INFO- Run completed, $op_us us/op"
}

run_bench_suite() {
  hg_server=h0
  hg_client=h1

  all_hg_poll=( false true )
  # all_hg_poll=( true )
  all_hg_insz=( 64 256 1024 4096 16384 65536 )
  # all_hg_insz=( 64 )
  hg_outsz=64
  hg_count=1000
  all_hg_limit=( 1 4 16 )
  # all_hg_limit=( 1 )
  all_hg_protostr=( bmi+tcp psm+psm )
  # all_hg_protostr=( psm+psm )

  for hg_poll in "${all_hg_poll[@]}"; do
    for hg_insz in "${all_hg_insz[@]}"; do
      for hg_limit in "${all_hg_limit[@]}"; do
        for hg_protostr in "${all_hg_protostr[@]}"; do
          run_bench
        done
      done
    done
  done
}

run_hgbench() {
  bm_log="hgbench_log.txt"
  echo "-INFO- Deleting $bm_log in 5 seconds"
  sleep 5
  rm $bm_log

  run_bench_suite

  cat $bm_log | column -t -s,
}

run_hgbench
