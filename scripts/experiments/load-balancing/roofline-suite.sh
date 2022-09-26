#!/bin/bash -eu

arg_jobdir_root=/mnt/lt20ad1
carp_tracedir_pref=/mnt/lustre/carp-big-run
carp_tracedir=$carp_tracedir_pref/particle.compressed.uniform

source ./pdlfs_common_wrapper.sh

run_exp_common() {
  arg_vpic_nranks=$(( arg_vpic_nodes * arg_vpic_ppn ))
  arg_vpic_partcnt_m=$( bc <<< $arg_vpic_nranks*6.55 )
  arg_vpic_partcnt=$(million $arg_vpic_partcnt_m)

  RUN_ATLEAST_ONCE=0
  run_exp_until_ok
  clean_exp
  sleep 30
}

run_shufonly_single() {
  arg_exp_type=deltafs
  arg_jobname=network-suite

  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=1

  run_exp_common
}

run_ioonly_single() {
  arg_exp_type=deltafs
  arg_jobname=dfs-ioonly

  XX_BYPASS_SHUFFLE=1
  XX_BF_BITS=0
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=0
  XX_USE_PLAINDB=1

  run_exp_common
}

run_dfs_seq_single() {
  arg_exp_type=deltafs
  arg_jobname=dfs-seq-suite

  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=0
  XX_BF_BITS=0
  XX_USE_PLAINDB=1

  run_exp_common
}

run_dfs_reg_single() {
  arg_exp_type=deltafs
  arg_jobname=dfs-reg-suite

  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=0
  XX_BF_BITS=0
  XX_USE_PLAINDB=1

  run_exp_common
}

run_carp_single() {
  echo "CARP: what params to use??"
}

run_suite_single() {
  run_shufonly_single
  run_ioonly_single
  run_dfs_seq_single
  run_dfs_reg_single
  run_carp_single
}

run_suite_rankscale() {
  arg_all_job_ridx=( 1 2 3 )
  arg_all_nnodes=( 1 2 4 8 16 32 )
  arg_all_epochs=( 12 )
  arg_vpic_ppn=16

  for arg_job_ridx in "${arg_all_job_ridx[@]}"; do
    for arg_vpic_nodes in "${arg_all_nnodes[@]}"; do
      for arg_vpic_epochs in "${arg_all_epochs[@]}"; do
        run_suite_single
      done
    done
  done
}

run_suite_datascale() {
  arg_all_job_ridx=( 1 2 3 )
  arg_all_nnodes=( 32 )
  arg_all_epochs=( 1 3 6 9 12 )
  arg_vpic_ppn=16

  for arg_job_ridx in "${arg_all_job_ridx[@]}"; do
    for arg_vpic_nodes in "${arg_all_nnodes[@]}"; do
      for arg_vpic_epochs in "${arg_all_epochs[@]}"; do
        run_suite_single
      done
    done
  done
}

run_suite_rankscale
run_suite_datascale
