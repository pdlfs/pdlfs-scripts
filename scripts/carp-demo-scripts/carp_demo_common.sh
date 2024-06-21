#!/usr/bin/env bash

set -eu

JOB_ROOT=/tmp

# sample trace for demos
TRACE_DIR=$INSTALL_PREFIX/share/traces/particle.compressed.sample

# trace has 3 epochs
TRACE_EPOCH_COUNT=3

RANGERUNNER_BIN=$INSTALL_PREFIX/bin/range-runner
RANGEREADER_BIN=$INSTALL_PREFIX/bin/rangereader
COMPACTOR_BIN=$INSTALL_PREFIX/bin/compactor

# particle count is 10^4 * PARTICLE_COUNT
PARTICLE_COUNT=100 # * 10^4 = 1M particles
# 1M particles across 16 ranks = 65536 part/rank

# renegotiation policy: periodic
CARP_POLICY=InvocationIntraEpoch

PARALLELISM=4

DRYRUN=0

RENEG_INTVL_DEMO=10000

RENEG_INTVLS_SUITE=(2500 5000 10000)

abort() {
  echo "Error: $1"
  exit 1
}

confirm() {
  if [[ "${DRYRUN:-1}" -eq 1 ]]; then
    return
  fi

  read -p "Press ENTER to continue, or n to stop: " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Exiting."
    exit 0
  fi
}

big_line() {
  echo "===================================================================="
}

small_line() {
  echo "--------------------------------------------------------------------"
}

init_job_root() {
  # while the user does not enter a valid job_root, infinite loop
  while true; do
    echo "Current job root: $JOB_ROOT"
    read -p "Enter job root to change, ENTER to accept. " job_root

    if [[ ! -z $job_root ]]; then
      JOB_ROOT=$job_root
    fi

    if [[ ! -d $JOB_ROOT ]]; then
      mkdir -p $JOB_ROOT && break
      echo "Error setting up job root."
    else
      break
    fi
  done

  echo "Job root set to: $JOB_ROOT"
}

#
# Requires: $INSTALL_PREFIX,
# $VPIC_DIR, $PLFSDIR, $INFO_DIR, $TRACE_DIR, $LOG_FILE
# $PARTICLE_COUNT, $TRACE_EPOCH_COUNT, $INTVL, $CARP_POLICY
#

run_carp() {
  # check if dir at install_prefix exists
  [[ ! -d $INSTALL_PREFIX ]] && abort "Install prefix $INSTALL_PREFIX does not exist"
  [[ ! -d $VPIC_DIR ]] && abort "VPIC dir $VPIC_DIR does not exist"
  [[ ! -d $PLFS_DIR ]] && abort "PLFS dir $PLFS DIR does not exist"
  [[ ! -d $INFO_DIR ]] && abort "INFO dir $INFO_DIR does not exist"
  [[ ! -d $TRACE_DIR ]] && abort "TRACE dir $TRACE_DIR does not exist"

  [[ -z $LOG_FILE ]] && abort "LOG_FILE is not set"
  [[ -z $PARTICLE_COUNT ]] && abort "PARTICLE_COUNT is not set"
  [[ -z $TRACE_EPOCH_COUNT ]] && abort "TRACE_EPOCH_COUNT is not set"
  [[ -z $RENEG_INTVL ]] && abort "INTVL is not set"
  [[ -z $CARP_POLICY ]] && abort "CARP_POLICY is not set"

  # configured for 16 ranks
  mpirun -np 16 -ppn 16 \
    -env LD_PRELOAD $INSTALL_PREFIX/lib/libdeltafs-preload.so \
    -env VPIC_current_working_dir $VPIC_DIR \
    -env PRELOAD_Ignore_dirs : \
    -env PRELOAD_Deltafs_mntp particle \
    -env PRELOAD_Local_root $PLFS_DIR \
    -env PRELOAD_Log_home $INFO_DIR \
    -env PRELOAD_Pthread_tap 0 \
    -env PRELOAD_Papi_events 'PAPI_L2_TCM;PAPI_L2_TCA' \
    -env PRELOAD_Bypass_deltafs_namespace 1 \
    -env PRELOAD_Bypass_shuffle 0 \
    -env PRELOAD_Bypass_write 0 \
    -env PRELOAD_Bypass_placement 1 \
    -env PRELOAD_Skip_mon 0 \
    -env PRELOAD_Skip_papi 1 \
    -env PRELOAD_Skip_sampling 0 \
    -env PRELOAD_Sample_threshold 64 \
    -env PRELOAD_No_sys_probing 0 \
    -env PRELOAD_No_paranoid_checks 1 \
    -env PRELOAD_No_paranoid_barrier 0 \
    -env PRELOAD_No_paranoid_post_barrier 0 \
    -env PRELOAD_No_paranoid_pre_barrier 0 \
    -env PRELOAD_No_epoch_pre_flushing 0 \
    -env PRELOAD_No_epoch_pre_flushing_wait 1 \
    -env PRELOAD_No_epoch_pre_flushing_sync 1 \
    -env PRELOAD_Print_meminfo 0 \
    -env PRELOAD_Enable_verbose_mode 1 \
    -env PRELOAD_Enable_bg_pause 0 \
    -env PRELOAD_Bg_threads 4 \
    -env PRELOAD_Enable_bloomy 0 \
    -env PRELOAD_Enable_CARP 1 \
    -env PRELOAD_Enable_wisc 0 \
    -env PRELOAD_Particle_buf_size 2097152 \
    -env PRELOAD_Particle_id_size 8 \
    -env PRELOAD_Particle_size 56 \
    -env PRELOAD_Particle_extra_size 0 \
    -env PRELOAD_Number_particles_per_rank 7000000 \
    -env SHUFFLE_Mercury_proto bmi+tcp \
    -env SHUFFLE_Mercury_progress_timeout 100 \
    -env SHUFFLE_Mercury_progress_warn_interval 1000 \
    -env SHUFFLE_Mercury_cache_handles 0 \
    -env SHUFFLE_Mercury_rusage 0 \
    -env SHUFFLE_Mercury_nice 0 \
    -env SHUFFLE_Mercury_max_errors 1 \
    -env SHUFFLE_Buffer_per_queue 32768 \
    -env SHUFFLE_Num_outstanding_rpc 16 \
    -env SHUFFLE_Use_worker_thread 1 \
    -env SHUFFLE_Force_sync_rpc 0 \
    -env SHUFFLE_Placement_protocol ring \
    -env SHUFFLE_Virtual_factor 1024 \
    -env SHUFFLE_Subnet 0.0.0.0 \
    -env SHUFFLE_Finalize_pause 0 \
    -env SHUFFLE_Force_global_barrier 0 \
    -env SHUFFLE_Local_senderlimit 16 \
    -env SHUFFLE_Remote_senderlimit 16 \
    -env SHUFFLE_Local_maxrpc 16 \
    -env SHUFFLE_Relay_maxrpc 16 \
    -env SHUFFLE_Remote_maxrpc 16 \
    -env SHUFFLE_Local_buftarget 32768 \
    -env SHUFFLE_Relay_buftarget 32768 \
    -env SHUFFLE_Remote_buftarget 32768 \
    -env SHUFFLE_Dq_min 1024 \
    -env SHUFFLE_Dq_max 4096 \
    -env SHUFFLE_Log_file / \
    -env SHUFFLE_Force_rpc 0 \
    -env SHUFFLE_Hash_sig 0 \
    -env SHUFFLE_Paranoid_checks 0 \
    -env SHUFFLE_Random_flush 0 \
    -env SHUFFLE_Recv_radix 0 \
    -env SHUFFLE_Use_multihop 1 \
    -env PLFSDIR_Skip_checksums 1 \
    -env PLFSDIR_Memtable_size 48MiB \
    -env PLFSDIR_Compaction_buf_size 4MiB \
    -env PLFSDIR_Data_min_write_size 6MiB \
    -env PLFSDIR_Data_buf_size 8MiB \
    -env PLFSDIR_Index_min_write_size 2MiB \
    -env PLFSDIR_Index_buf_size 2MiB \
    -env PLFSDIR_Key_size 8 \
    -env PLFSDIR_Filter_bits_per_key 12 \
    -env PLFSDIR_Lg_parts 2 \
    -env PLFSDIR_Force_leveldb_format 0 \
    -env PLFSDIR_Unordered_storage 0 \
    -env PLFSDIR_Use_plaindb 0 \
    -env PLFSDIR_Use_leveldb 0 \
    -env PLFSDIR_Use_rangedb 1 \
    -env PLFSDIR_Ldb_force_l0 0 \
    -env PLFSDIR_Ldb_use_bf 0 \
    -env PLFSDIR_Env_name posix.unbufferedio \
    -env NEXUS_ALT_LOCAL na+sm \
    -env NEXUS_BYPASS_LOCAL 0 \
    -env DELTAFS_TC_RATE 0 \
    -env DELTAFS_TC_SERIALIO 0 \
    -env DELTAFS_TC_SYNCONCLOSE 0 \
    -env DELTAFS_TC_IGNORESYNC 0 \
    -env DELTAFS_TC_DROPDATA 0 \
    -env RANGE_Enable_dynamic 0 \
    -env RANGE_Reneg_policy $CARP_POLICY \
    -env RANGE_Reneg_interval $RENEG_INTVL \
    -env RANGE_Pvtcnt_s1 256 \
    -env RANGE_Pvtcnt_s2 256 \
    -env RANGE_Pvtcnt_s3 256 \
    -bind-to=none \
    $RANGERUNNER_BIN -b 40 -s 2 -i $TRACE_DIR -t 6000 file-per-particle trecon-part/turbulence $PARTICLE_COUNT 100 1 512 1 1 $TRACE_EPOCH_COUNT $TRACE_EPOCH_COUNT 2>&1 | tee $LOG_FILE
}

init_job_root
