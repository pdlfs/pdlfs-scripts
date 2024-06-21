#!/usr/bin/env bash

set -u

install_root=/users/ankushj/repos/carp-umb-tmp/carp-umbrella/build/deltafs-prefix/src/deltafs-build
bm_bin_rdb=$install_root/src/libdeltafs/rangewriter_test
bm_bin_pdb=$install_root/src/libdeltafs/pdb_test

bm_log=bm_log.txt
bm_stats=bm_stats.txt

echo_csv_line() {
  echo $1 | column -t -s,
}

log_csv_line() {
  echo $1 >> $bm_stats
}

log_header() {
  if [ ! -f $bm_stats ]; then
    log_csv_line $1
  fi
}

log_data() {
  log_csv_line $1
}


log_single() {
  util=$(cat $bm_log | grep Util | egrep -o '[0-9.%]+')
  header="runtype,mi_keys,num_bufs,bps,util"

  header="runtype,mi_keys,mbps,bufsz_mb,nbufs"
  header="$header,single_thread,epflcnt,mid_epflcnt,skip_sort,util"

  data="$runtype,$MI_KEYS,$ARG_BPS_M"
  data="$data,$BUF_SIZE_M,$NUM_BUFS,$SINGLE_THREADED"
  data="$data,$EPOCH_FLUSH_COUNT,$MID_EPOCH_FLUSH_COUNT,$SKIP_SORT"
  data="$data,$util"

  log_header $header
  log_data $data

  cat $bm_stats | column -t -s,
}

run_single_internal() {
  export MI_KEYS=${ARG_MI_KEYS:-1}
  export BYTES_PER_SEC=${ARG_BPS:-5000000}
  export BUF_SIZE_M=${ARG_BUFSZ_M:-4}
  export BUF_SIZE=$(( BUF_SIZE_M * 1024 * 1024 ))
  export NUM_BUFS=${ARG_NBUFS:-2}
  export SINGLE_THREADED=${SINGLE_THREADED:-0}
  export EPOCH_FLUSH_COUNT=${EPOCH_FLUSH_COUNT:-0}
  export MID_EPOCH_FLUSH_COUNT=${EPOCH_FLUSH_COUNT:-0}
  export SKIP_SORT=${SKIP_SORT:-0}

  echo "Running $runtype"

  taskset -c 0 $cmd &> $bm_log
  cat $bm_log >> ${bm_log}.all
  log_single
}

run_single_pdb() {
  runtype=run_pdb
  bm_bin=$bm_bin_pdb

  SKIP_SORT=0
  cmd="$bm_bin_pdb --bench=pdb"

  run_single_internal
}

run_single_rdb_unsorted() {
  runtype=run_rdb_unsorted
  bm_bin=$bm_bin_rdb

  SKIP_SORT=1
  EPOCH_FLUSH_COUNT=0
  MID_EPOCH_FLUSH_COUNT=0
  cmd="$bm_bin_rdb --bench=rdb"

  run_single_internal
}

run_single_rdb_sorted() {
  runtype=run_rdb_sorted
  bm_bin=$bm_bin_rdb

  SKIP_SORT=0
  EPOCH_FLUSH_COUNT=0
  MID_EPOCH_FLUSH_COUNT=0
  cmd="$bm_bin_rdb --bench=rdb"

  run_single_internal
}

run_single_rdb_wflush_lo() {
  runtype=run_rdb_sorted_wflush_lo
  bm_bin=$bm_bin_rdb

  SKIP_SORT=0
  EPOCH_FLUSH_COUNT=2
  MID_EPOCH_FLUSH_COUNT=2
  cmd="$bm_bin_rdb --bench=rdb"

  run_single_internal
}

run_single_rdb_wflush_hi() {
  runtype=run_rdb_sorted_wflush_hi
  bm_bin=$bm_bin_rdb

  SKIP_SORT=0
  EPOCH_FLUSH_COUNT=12
  MID_EPOCH_FLUSH_COUNT=6
  cmd="$bm_bin_rdb --bench=rdb"

  run_single_internal
}

run_single() {
  run_single_pdb
  run_single_rdb_unsorted
  run_single_rdb_sorted
  run_single_rdb_wflush_lo
  run_single_rdb_wflush_hi
}

run_suite() {
  MI_KEYS=7
  ARG_BUFSZ_M=10
  ARG_NBUFS=2

  ALL_BPS=( 5 10 15 20 25 30 )

  for ARG_BPS_M in "${ALL_BPS[@]}"; do
    ARG_BPS=$(( ARG_BPS_M * 1000000 ))
    run_single
  done
}

echo "Deleting $bm_stats..."
sleep 1
rm $bm_stats || /bin/true
run_suite
