#!/bin/bash -eu

pdl_cluster_name=$(hostname | cut -d. -f 2)
arg_jobdir_root=/mnt/lt20ad1
carp_tracedir_pref=/mnt/lustre/carp-big-run
carp_tracedir=$carp_tracedir_pref/particle.compressed.uniform

source ./pdlfs_common_wrapper.sh

init_suite() {
  SCRIPT=$(realpath "$0")
  SCRIPTPATH=$(dirname "$SCRIPT")

  exp_hosts_blacklist=$SCRIPTPATH/hosts-$pdl_cluster_name-exclude.txt
  if [ -f "$exp_hosts_blacklist" ]; then
    message "-INFO- Found hosts-exclude.txt at $exp_hosts_blacklist. Using it."
  else
    touch $exp_hosts_blacklist
    message "-INFO- Creating hosts-exclude.txt at $exp_hosts_blacklist. Using it."
  fi

  run_deltafs_micro
}

#
# XXX: Some notes: XX_NX_1HOP is temporary and is added for a 
# temporary uncommitted patch to deltafs-nexus
#

run_exp_common() {
  echo -e "\n"

  arg_vpic_nranks=$(( arg_vpic_nodes * arg_vpic_ppn ))
  arg_vpic_partcnt_m=$( bc <<< $arg_vpic_nranks*6.55 )
  arg_vpic_partcnt=$(million $arg_vpic_partcnt_m)

  RUN_ATLEAST_ONCE=0
  run_exp_until_ok
  clean_exp
  sleep 5
}

run_shufonly_psm_single() {
  arg_exp_type=deltafs
  arg_jobname=network-suite-psm

  XX_HG_PROTO="psm+psm"
  XX_CARP_ON=0
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=0
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=1
  XX_USE_PLAINDB=1

  run_exp_common
}

run_shufonly_single() {
  arg_exp_type=deltafs
  arg_jobname=network-suite

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=0
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=0
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=1
  XX_USE_PLAINDB=1

  run_exp_common
}

run_shufonly_bigrpc_single() {
  arg_exp_type=deltafs
  arg_jobname=network-suite-bigrpc

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=0
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=0
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=1
  XX_USE_PLAINDB=1

  XX_RPC_BUF=65536
  run_exp_common
  XX_RPC_BUF=32768
}

run_shufonly_1hopsim_single() {
  arg_exp_type=deltafs
  arg_jobname=network-suite-1hopsim

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=0
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=0
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=1
  XX_USE_PLAINDB=1

  XX_NX_1HOP=1
  run_exp_common
  XX_NX_1HOP=0
}

run_shufonly_1hopsim_node2x_single() {
  arg_exp_type=deltafs
  arg_jobname=network-suite-1hopsim-node2x

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=0
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=0
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=1
  XX_USE_PLAINDB=1

  XX_NX_1HOP=1
  arg_vpic_ppn=$(( arg_vpic_ppn / 2 ))
  arg_vpic_nodes=$(( arg_vpic_nodes * 2 ))
  run_exp_common
  XX_NX_1HOP=0
  arg_vpic_ppn=$(( arg_vpic_ppn * 2 ))
  arg_vpic_nodes=$(( arg_vpic_nodes / 2 ))
}

run_ioonly_single() {
  arg_exp_type=deltafs
  arg_jobname=dfs-ioonly

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=0
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

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=0
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=0
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=0
  XX_USE_PLAINDB=1

  run_exp_common
}

run_dfs_reg_single() {
  arg_exp_type=deltafs
  arg_jobname=dfs-reg-suite

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=0
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=12
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=0
  XX_USE_PLAINDB=0

  run_exp_common
}

run_carp_single() {
  arg_exp_type=carp
  arg_jobname=carp-suite

  all_intvl=( 750000 1000000 )
  all_pvtcnt=( 1024 2048 )

  XX_HG_PROTO="bmi+tcp"
  XX_CARP_ON=1
  XX_BYPASS_SHUFFLE=0
  XX_BF_BITS=0
  XX_IMD_RATELMIT=0
  XX_IMD_DROPDATA=0
  XX_USE_RANGEDB=1

  for carp_intvl in "${all_intvl[@]}"; do
    for carp_pvtcnt in "${all_pvtcnt[@]}"; do
      run_exp_common
      echo $(dump_map_repfirst $arg_vpic_epochs)
    done
  done
}

run_suite_single() {
  run_shufonly_psm_single
  run_shufonly_single
  run_shufonly_bigrpc_single
  run_shufonly_1hopsim_single
  run_shufonly_1hopsim_node2x_single
  run_ioonly_single
  run_dfs_seq_single
  run_dfs_reg_single
  # run_carp_single
}

run_suite_rankscale() {
  arg_all_job_ridx=( 1 2 3 )
  arg_all_job_ridx=( 3 )
  arg_all_nnodes=( 1 2 4 8 16 32 )
  arg_all_nnodes=( 1 2 4 8 16 )
  arg_all_epochs=( 12 )
  arg_vpic_ppn=16

  for arg_job_ridx in "${arg_all_job_ridx[@]}"; do
    for arg_vpic_nodes in "${arg_all_nnodes[@]}"; do
      for arg_vpic_epochs in "${arg_all_epochs[@]}"; do
        arg_carp_dumpmap=$(dump_map_repfirst $arg_vpic_epochs)
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

init_suite
# run_suite_rankscale
# run_suite_datascale
