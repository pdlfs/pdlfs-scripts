#!/bin/bash -eu
#
# Copyright (c) 2019 Carnegie Mellon University,
# Copyright (c) 2019 Triad National Security, LLC, as operator of
#     Los Alamos National Laboratory.
#
# All rights reserved.
#
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file. See the AUTHORS file for names of contributors.
#

#
# vpic_common.sh  common helper functions for running vpic w/deltafs-umbrella
# 18-Apr-2019  chuck@ece.cmu.edu
#

#
# our assumption here is that the calling script has already
# sourced common.sh and thus that enviornment is currently loaded.
#

#
# variables:
#  $vpic_cpubind - cpu binding for vpic run (arg 3 to do_mpirun)
#  $vpic_epochs - number of frames/epochs for VPIC runs (int)
#  $vpic_steps - number of time steps for VPIC runs (int)
#  $vpic_use_vpic407 - if "1" then use vpic407 script interface
#  $vpic_do_querying - whether we will perform particle queries (bool - 0 or 1)
#
# functions:
#  vpic_build_deck() - build a deck
#  vpic_do_run() - do a vpic run
#  vpic_query_particles() - do a vpic particle query
#

#
# vpic_do_run: run a vpic experiment
#
# uses: $dfsu_prefix, $jobdir, $exp_tag, $bbdir, $cores, $nodes, $logfile, 
#        $vpic_nodes,
#        $jobdir/current-deck.op (precompiled deck)
#        $jobdir/vpic.hosts
# creates: an experiment tag: {runtype}_P{particles}_C${cores}_N${nodes}
#          $bbdir/$exp_tag - primary output directory for the experiment
#          $jobdir/$exp_tag - secondary output directory for the experiment
#          $jobdir/$exp_tag/$exp_tag.log - logfile for the experiment
# side effects: changes current directory to $jobdir/$exp_tag
#
# Arguments:
# @1 experiment type in {"baseline", "deltafs", "shuffle_test"}
# @2 number of particles
# @3 ppn
# @4 job deck
# @5 lib to preload for vpic run (disabled if not set)
# @6 lib to preload for read/query
vpic_do_run() {
    runtype=$1
    p=$2
    ppn=${3:-0}
    jobdeck=${4:-"${jobdir}/current-deck.op"}
    jobdeck1=$(echo $jobdeck | cut -d' ' -f1)
    exp_tag=$5
    prelib=${6:-}
    prelibq=${7:-}

    prelib_env="" # empty, will not insert any LD_PRELOAD stuff
    if [ x"$prelib" != x ]; then
        prelib_env="LD_PRELOAD $prelib"
    fi

    # pp: make a more human readable version of "p"
    if [ $((p / (10**6))) -gt 0 ]; then
        pp="$((p / (10**6)))M"
    elif [ $((p / (10**3))) -gt 0 ]; then
        pp="$((p / (10**3)))K"
    else
        pp="$p"
    fi

    exp_tag_fallback="${runtype}_P${pp}_C${cores}_N${nodes}"
    exp_tag=${exp_tag:-$exp_tag_fallback}
    cd $jobdir || die "cd to $jobdir failed"
    exp_jobdir="$jobdir/$exp_tag"   ### NOTE !! still on Lustre !! ###
    mkdir -p $exp_jobdir || die "mkdir $exp_jobdir failed"
    mkdir -p $exp_jobdir/exp-info || die "mkdir $exp_jobdir/exp-info failed"
    cd $exp_jobdir || die "cd to $exp_jobdir failed"
    ### log file for this exp ###
    exp_logfile="$exp_jobdir/$exp_tag.log"   ### NOTE !! absolute path !! ###

    ### purge data left by a prev job iter
    reset_bbdir  ### will skip removing data when DW is OFF

    message "--------------- [   DOIT   ] --------------"
    message "!!! NOTICE !!! starting exp >> >> ${exp_tag}..."
    message ""

    ### ATTENTION: data may or may not goto DW ###
    exp_dir="$bbdir/$exp_tag"  ### when DW is OFF, bbdir == jobdir
    message "-INFO- creating exp dir..."
    do_mpirun 1 1 "none" "" "" "mkdir -p ${exp_dir}"
    message "-INFO- done"

    ### NOTE: cannot cd to $exp_dir since it may land in bb ###

    clear_caches

    message ""
    message "[DECK] --- $(ls -lni --full-time ${jobdeck1})"
    message ""

    ### SPAM ENOUGH TO MAKE BOSS HAPPY ###
    message "=================================================================="
    message "!!! Running VPIC ($runtype) with $pp particles on $cores cores and $nodes nodes !!!"
    message "------------"
    message "> Using ${jobdeck1}"
    message "> Job dir is ${jobdir}"
    message "> Experiment dir is ${exp_dir}"
    message "> Log to ${exp_logfile}"
    message "  (+) Log to ${logfile}"
    message "      (+) Log to STDOUT"
    message "=================================================================="
    message ""

    case $runtype in
    "baseline")
        vpic_dir=$exp_dir/vpic

        ### BOOTSTRAPING ###
        message "-INFO- creating more exp dirs..."
        do_mpirun 1 1 "none" "" "" "mkdir -p $vpic_dir"
        message "-INFO- done"

        ### WRITE PATH ###
        env_vars=($prelib_env
            "VPIC_current_working_dir" "${vpic_dir}"
            "PRELOAD_Ignore_dirs" ${XX_IGNORE_DIRS:-":"}
            "PRELOAD_Log_home" "${exp_jobdir}/exp-info"
            "PRELOAD_No_sys_probing" ${XX_NO_SCAN:-"0"}
            "PRELOAD_Enable_verbose_error" ${XX_VERBOSE:-"1"}
        )

        do_mpirun $cores $ppn "$vpic_cpubind" env_vars[@] "$vpic_nodes" \
            "${jobdeck}" "${EXTRA_MPIOPTS-}"

        message ""
        message "-INFO- checking output size..."
        do_mpirun 1 1 "none" "" "" "du -sb $vpic_dir/particle" | tee -a $exp_jobdir/outsize.txt
        echo "Output size:" `cat $exp_jobdir/outsize.txt | \
            grep -F -v "[MPIEXEC]" | head -1 | cut -f1` "bytes" | \
                tee -a $exp_logfile | tee -a $logfile
        do_mpirun 1 1 "none" "" "" "du -h $vpic_dir/particle"
        message "-INFO- done"

        ### STAGE DATA OUT ###
        if [ $vpic_do_querying -ne 0 -a x$jobdir != x$bbdir ]; then
            message "-INFO- staging data out... "
            mkdir -p $exp_jobdir/bb || die "mkdir $exp_jobdir/bb failed"
            message ""
            message "FROM : $exp_dir" ### BB ###
            message "  TO : $exp_jobdir/bb"  ### Luster ###
            message ""

            message "[DWCLI] dwcli" "stage out" "--session $dwsessid" "--configuration $dwconfid" \
                "--backing-path $exp_jobdir/bb/" "--dir ${exp_dir:${#DW_JOB_STRIPED}}"
            dwcli stage out --session $dwsessid --configuration $dwconfid \
              --backing-path $exp_jobdir/bb/ --dir ${exp_dir:${#DW_JOB_STRIPED}}

            bb_stageoutwait

            message "-INFO- done"

            exp_dir=$exp_jobdir/bb
            vpic_dir=$exp_dir/vpic
        fi

        ### READ PATH ###
        if [ $vpic_do_querying -ne 0 ]; then
            vpic_query_particles $runtype $vpic_dir $pp "$prelibq"
        else
            message ""
            message "!!! WARNING !!! write only - skipping read phase..."
            message ""
        fi
        ;;

    *)
        plfs_dir=$exp_dir/plfs
        vpic_dir=$exp_dir/vpic

        ### BOOTSTRAPING ###
        message "-INFO- creating more exp dirs..."
        do_mpirun 1 1 "none" "" "" "mkdir -p $plfs_dir/particle"
        do_mpirun 1 1 "none" "" "" "mkdir -p $vpic_dir"
        message "-INFO- done"

        ### WRITE PATH ###
        if [ x${XX_SH_LOG_FILE-0} != x0 ]; then
            shuflogfile="$exp_jobdir/shuflog"
        else
            shuflogfile="/"    # preload treats '/' as disabled
        fi

        env_vars=($prelib_env
            "VPIC_current_working_dir" "${vpic_dir}"
            "PRELOAD_Ignore_dirs" ${XX_IGNORE_DIRS:-":"}
            "PRELOAD_Deltafs_mntp" "particle"
            "PRELOAD_Local_root" "${plfs_dir}"
            "PRELOAD_Log_home" "${exp_jobdir}/exp-info"
            "PRELOAD_Pthread_tap" ${XX_PTHREAD_TAP:-"0"}
            "PRELOAD_Papi_events" ${XX_PAPI:-"PAPI_L2_TCM;PAPI_L2_TCA"}
            "PRELOAD_Bypass_deltafs_namespace" "1"
            "PRELOAD_Bypass_shuffle" ${XX_BYPASS_SHUFFLE:-"0"}
            "PRELOAD_Bypass_write" ${XX_BYPASS_WRITE:-"0"}
            "PRELOAD_Bypass_placement" ${XX_BYPASS_CH:-"1"}
            "PRELOAD_Skip_mon" ${XX_SKIP_MON:-"0"}
            "PRELOAD_Skip_papi" ${XX_SKIP_PAPI:-"1"}
            "PRELOAD_Skip_sampling" ${XX_SKIP_SAMP:-"0"}
            "PRELOAD_Sample_threshold" ${XX_SAMP_TH:-"64"}
            "PRELOAD_No_sys_probing" ${XX_NO_SCAN:-"0"}
            "PRELOAD_No_paranoid_checks" ${XX_NO_CHECKS:-"1"}
            "PRELOAD_No_paranoid_barrier" ${XX_NO_BAR:-"0"}
            "PRELOAD_No_paranoid_post_barrier" ${XX_NO_POST_BAR:-"0"}
            "PRELOAD_No_paranoid_pre_barrier" ${XX_NO_PRE_BAR:-"0"}
            "PRELOAD_No_epoch_pre_flushing" ${XX_NO_PRE_FLUSH:-"0"}
            "PRELOAD_No_epoch_pre_flushing_wait" ${XX_NO_PRE_FLUSH_WAIT:-"1"}
            "PRELOAD_No_epoch_pre_flushing_sync" ${XX_NO_PRE_FLUSH_SYNC:-"1"}
            "PRELOAD_Print_meminfo" ${XX_PRINT_MEMINFO:-"0"}
            "PRELOAD_Enable_verbose_mode" ${XX_VERBOSE:-"1"}
            "PRELOAD_Enable_bg_pause" ${XX_BG_PAUSE:-"0"}
            "PRELOAD_Bg_threads" ${XX_BG_DEPTH:-"4"}
            "PRELOAD_Enable_bloomy" ${XX_FMT_BLOOM:-"0"}
            "PRELOAD_Enable_wisc" ${XX_FMT_WISC:-"0"}
            "PRELOAD_Particle_buf_size" ${XX_PARTICLE_BUF_SIZE-"$((2*1024*1024))"}
            "PRELOAD_Particle_id_size" ${XX_PARTICLE_ID_SIZE:-"8"}
            "PRELOAD_Particle_size" ${XX_PARTICLE_SIZE:-"56"}
            "PRELOAD_Particle_extra_size" ${XX_PARTICLE_EXTRA_SIZE:-"0"}
            "PRELOAD_Number_particles_per_rank" $(($p/$cores))
            "SHUFFLE_Mercury_proto" ${XX_HG_PROTO:-"bmi+tcp"}
            "SHUFFLE_Mercury_progress_timeout" ${XX_HG_TIMEOUT:-"100"}
            "SHUFFLE_Mercury_progress_warn_interval" ${XX_HG_INTERVAL:-"1000"}
            "SHUFFLE_Mercury_cache_handles" ${XX_HG_CACHE_HDL:-"0"}
            "SHUFFLE_Mercury_rusage" ${XX_HG_RUSAGE:-"0"}
            "SHUFFLE_Mercury_nice" ${XX_HG_NICE:-"0"}
            "SHUFFLE_Mercury_max_errors" ${XX_HG_MAX_ERRORS:-"1"}
            "SHUFFLE_Buffer_per_queue" ${XX_RPC_BUF:-"32768"}
            "SHUFFLE_Num_outstanding_rpc" ${XX_RPC_DEPTH:-"16"}
            "SHUFFLE_Use_worker_thread" ${XX_RPC_USE_WORKER:-"1"}
            "SHUFFLE_Force_sync_rpc" ${XX_RPC_FORCE_SYNC:-"0"}
            "SHUFFLE_Placement_protocol" ${XX_CH_PROTO:-"ring"}
            "SHUFFLE_Virtual_factor" ${XX_CH_VF:-"1024"}
            "SHUFFLE_Subnet" "${ip_subnet:-0.0.0.0}"
            "SHUFFLE_Finalize_pause" ${XX_SH_FINAL_PAUSE:-"0"}
            "SHUFFLE_Force_global_barrier" ${XX_SH_FORCE_GLOBAL:-"0"}
            "SHUFFLE_Local_senderlimit" ${XX_SH_LSNDLIMIT:-${XX_RPC_DEPTH:-"16"}}
            "SHUFFLE_Remote_senderlimit" ${XX_SH_RSNDLIMIT:-${XX_RPC_DEPTH:-"16"}}
            "SHUFFLE_Local_maxrpc" ${XX_SH_LOMAXRPC:-${XX_RPC_DEPTH:-"16"}}
            "SHUFFLE_Relay_maxrpc" ${XX_SH_LRMAXRPC:-${XX_RPC_DEPTH:-"16"}}
            "SHUFFLE_Remote_maxrpc" ${XX_SH_RMAXRPC:-${XX_RPC_DEPTH:-"16"}}
            "SHUFFLE_Local_buftarget" ${XX_SH_LOBUFTGT:-${XX_RPC_BUF:-"32768"}}
            "SHUFFLE_Relay_buftarget" ${XX_SH_LRBUFTGT:-${XX_RPC_BUF:-"32768"}}
            "SHUFFLE_Remote_buftarget" ${XX_SH_RBUFTGT:-${XX_RPC_BUF:-"32768"}}
            "SHUFFLE_Dq_min" ${XX_SH_DMIN:-"1024"}
            "SHUFFLE_Dq_max" ${XX_SH_DMAX:-"4096"}
            "SHUFFLE_Log_file" "${shuflogfile}"
            "SHUFFLE_Force_rpc" ${XX_ALWAYS_SHUFFLE:-"0"}
            "SHUFFLE_Hash_sig" ${XX_RPC_HASHSIG:-"0"}
            "SHUFFLE_Paranoid_checks" ${XX_RPC_CHECKS:-"0"}
            "SHUFFLE_Random_flush" ${XX_RPC_RANDOM_FLUSH:-"0"}
            "SHUFFLE_Recv_radix" ${XX_RECV_RADIX:-"0"}
            "SHUFFLE_Use_multihop" ${XX_SH_THREE_HOP:-"1"}
            "PLFSDIR_Skip_checksums" ${XX_SKIP_CRC:-"1"}
            "PLFSDIR_Memtable_size" ${XX_MEMTABLE_SIZE:-"48MiB"}
            "PLFSDIR_Compaction_buf_size" ${XX_COMP_BUF:-"4MiB"}
            "PLFSDIR_Data_min_write_size" ${XX_MIN_DATA_BUF:-"6MiB"}
            "PLFSDIR_Data_buf_size" ${XX_MAX_DATA_BUF:-"8MiB"}
            "PLFSDIR_Index_min_write_size" ${XX_MIN_INDEX_BUF:-"2MiB"}
            "PLFSDIR_Index_buf_size" ${XX_MAX_INDEX_BUF:-"2MiB"}
            "PLFSDIR_Key_size" ${XX_KEY_SIZE:-"8"}
            "PLFSDIR_Filter_bits_per_key" ${XX_BF_BITS:-"12"}
            "PLFSDIR_Lg_parts" ${XX_LG_PARTS:-"2"}
            "PLFSDIR_Force_leveldb_format" ${XX_FORCE_LEVELDB_FMT:-"0"}
            "PLFSDIR_Unordered_storage" ${XX_SKIP_SORT:-"0"}
            "PLFSDIR_Use_plaindb" ${XX_USE_PLAINDB:-"0"}
            "PLFSDIR_Use_leveldb" ${XX_USE_LEVELDB:-"0"}
            "PLFSDIR_Use_rangedb" ${XX_USE_RANGEDB:-"1"}
            "PLFSDIR_Ldb_force_l0" ${XX_LEVELDB_L0ONLY:-"0"}
            "PLFSDIR_Ldb_use_bf" ${XX_LEVELDB_WITHBF:-"0"}
            "PLFSDIR_Env_name" ${XX_ENV_NAME:-"posix.unbufferedio"}
            "NEXUS_1H" ${XX_NX_1HOP:-"0"}
            "NEXUS_ALT_LOCAL" ${XX_NX_LOCAL:-"na+sm"}
            "NEXUS_BYPASS_LOCAL" ${XX_NX_ONEHG:-"1"}
            "DELTAFS_TC_RATE" ${XX_IMD_RATELIMIT:-"0"}
            "DELTAFS_TC_SERIALIO" ${XX_IMD_SERIALIO:-"0"}
            "DELTAFS_TC_SYNCONCLOSE" ${XX_IMD_SYNCONCLOSE:-"0"}
            "DELTAFS_TC_IGNORESYNC" ${XX_IMD_IGNORESYNC:-"0"}
            "DELTAFS_TC_DROPDATA" ${XX_IMD_DROPDATA:-"0"}
            "PRELOAD_Enable_CARP" ${XX_CARP_ON:-"1"}
            "PRELOAD_Filename_size" ${XX_FNAME_SIZE:-"8"}
            "PRELOAD_Filedata_size" ${XX_FDATA_SIZE:-"48"}
            "PRELOAD_Particle_id_size" ${XX_PID_SIZE:-"8"}
            "PRELOAD_Particle_indexed_attr_size" ${XX_IDXATTR_SIZE:-"4"}
            "PRELOAD_Particle_indexed_attr_offset" ${XX_IDXATTR_OFFSET:-"0"}
            "RANGE_Enable_dynamic" ${XX_CARP_DYNTRIG:-"0"}
            "RANGE_Oob_size" ${XX_CARP_OOBSZ:-"512"}
            "RANGE_Dynamic_threshold" ${XX_CARP_DYNLIM:-"2.0"}
            "RANGE_Reneg_interval" ${XX_CARP_INTVL:-"250000"}
            "RANGE_Pvtcnt_s1" ${XX_RTP_PVTCNT:-"256"}
            "RANGE_Pvtcnt_s2" ${XX_RTP_PVTCNT:-"256"}
            "RANGE_Pvtcnt_s3" ${XX_RTP_PVTCNT:-"256"}
        )

        do_mpirun $cores $ppn "$vpic_cpubind" env_vars[@] \
            "$vpic_nodes" "${jobdeck}" "${EXTRA_MPIOPTS-}"

        message ""
        message "-INFO- checking output size..."
        do_mpirun 1 1 "none" "" "" "du -sb $plfs_dir/particle" | tee -a $exp_jobdir/outsize.txt
        echo "Output size:" `cat $exp_jobdir/outsize.txt | \
            grep -F -v "[MPIEXEC]" | head -1 | cut -f1` "bytes" | \
                tee -a $exp_logfile | tee -a $logfile
        do_mpirun 1 1 "none" "" "" "du -h $plfs_dir/particle"
        message "-INFO- done"

        ### STAGE DATA OUT ###
        if [ $vpic_do_querying -ne 0 -a x$jobdir != x$bbdir ]; then
            message "-INFO- staging data out... "
            mkdir -p $exp_jobdir/bb || die "mkdir $exp_jobdir/bb failed"
            message ""
            message "FROM : $exp_dir" ### BB ###
            message "  TO : $exp_jobdir/bb"  ### Luster ###
            message ""

            message "[DWCLI] dwcli" "stage out" "--session $dwsessid" "--configuration $dwconfid" \
                "--backing-path $exp_jobdir/bb/" "--dir ${exp_dir:${#DW_JOB_STRIPED}}"
            dwcli stage out --session $dwsessid --configuration $dwconfid \
              --backing-path $exp_jobdir/bb/ --dir ${exp_dir:${#DW_JOB_STRIPED}}

            bb_stageoutwait

            message "-INFO- done"

            exp_dir=$exp_jobdir/bb
            plfs_dir=$exp_dir/plfs
            vpic_dir=$exp_dir/vpic
        fi

        ### READ PATH ###
        if [ $vpic_do_querying -ne 0 ]; then
            vpic_query_particles $runtype $exp_dir $pp "$prelibq"
        else
            message ""
            message "!!! WARNING !!! write only - skipping read phase..."
            message ""
        fi
        ;;

    esac

    message ""
    message "--------------- [    OK    ] --------------"

    exp_logfile=""
}
