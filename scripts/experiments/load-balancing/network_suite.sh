#!/bin/bash -eu

arg_jobdir_root=/mnt/lt20ad1
carp_tracedir_pref=/mnt/lustre/carp-big-run
carp_tracedir=$carp_tracedir_pref/particle.compressed.uniform

source ./pdlfs_common_wrapper.sh

run_nw_single() {
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=1

  arg_exp_type=deltafs
  arg_vpic_nranks=$(( arg_vpic_nodes * arg_vpic_ppn ))
  arg_vpic_partcnt_m=$( bc <<< $arg_vpic_nranks*6.55 )
  arg_vpic_partcnt=$(million $arg_vpic_partcnt_m)

  run_exp_until_ok
  clean_exp
  sleep 30
}

run_nw_suite() {
  arg_exp_type=deltafs
  arg_jobname=network-suite

  arg_all_job_ridx=( 1 2 3 4 5 6 )
  arg_all_nnodes=( 1 2 4 8 16 32 )
  arg_all_epochs=( 1 3 6 9 12 )
  arg_vpic_ppn=16

  for arg_job_ridx in "${arg_all_job_ridx[@]}"; do
    for arg_vpic_nodes in "${arg_all_nnodes[@]}"; do
      for arg_vpic_epochs in "${arg_all_epochs[@]}"; do
        run_nw_single
      done
    done
    break
  done
}

run_nw_suite
