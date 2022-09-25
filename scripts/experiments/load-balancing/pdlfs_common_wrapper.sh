#!/bin/bash -eu
#
#

# To avoid conflict with pdlfs_common vars, all local variables that are
# not meant to be shared with that stack should have the prefix arg_.
# All other variables are assumed to be shared.

# Current list of variables used by the common scripts:
# $jobdir, $nodes, $bbos_buddies, $arg_vpic_nodes, $bbos_nodes
# $dfsu_prefix, $exp_tag, $bbdir, $cores, $nodes, $logfile,
# $arg_vpic_nodes, $vpic_cpubind, $arg_vpic_epochs, $vpic_steps
# $vpic_use_vpic407, $vpic_do_querying

source ../../common.sh
source pdlfs_common.sh

million() {
  in=$1
  echo $( bc <<< $in*1000*1000 ) | cut -d. -f 1
}

dump_map_repfirst() {
  arg_vpic_epochs=$1
  arg_carp_dumpmap="0:$arg_vpic_epochs"
  if [[ $arg_vpic_epochs -gt 1 ]]; then
    arg_carp_dumpmap=$arg_carp_dumpmap,$(seq 1 $(( job_epcnt - 1 )) | sed 's/$/:0/g' | paste -sd,)
  fi
  echo $arg_carp_dumpmap
}

dump_map_allonce() {
  arg_vpic_epochs=$1
  arg_carp_dumpmap=$(seq 0 $(( job_epcnt - 1 )) | sed 's/$/:1/g' | paste -sd,)
  echo $arg_carp_dumpmap
}

init_carp() {
  # preload
  XX_CARP_ON=1
  XX_FNAME_SIZE=8
  XX_FDATA_SIZE=48
  # TODO: next two properties are deprecated
  XX_PARTICLE_ID_SIZE=8
  XX_PARTICLE_SIZE=48
  XX_IDXATTR_SIZE=4
  XX_IDXATTR_OFFSET=0
  XX_NO_BAR=0
  XX_NO_POST_BAR=0
  XX_NO_PRE_BAR=0

  # carp
  XX_CARP_POLICY=InvocationPeriodic
  XX_USE_RANGEDB=1
  XX_CARP_INTVL=$carp_intvl
  XX_CARP_OOBSZ=512
  XX_RTP_PVTCNT=$carp_pvtcnt

  # shuffle
  XX_SH_THREE_HOP=1
  XX_NX_ONEHG=1

  # plfs
  XX_IMD_RATELIMIT=${XX_IMD_RATELIMIT:-0}
  XX_IMD_DROPDATA=${XX_IMD_DROPDATA:-0}
}

init_deltafs() {
  XX_CARP_ON=0
  XX_FNAME_SIZE=8
  XX_FDATA_SIZE=52
  # TODO: next two properties are deprecated
  XX_PARTICLE_ID_SIZE=8
  XX_PARTICLE_SIZE=52
  XX_NO_BAR=1
  XX_NO_POST_BAR=1
  XX_NO_PRE_BAR=1

  # shuffle
  XX_SH_THREE_HOP=1
  XX_NX_ONEHG=1

  # plfs
  XX_IMD_RATELIMIT=${XX_IMD_RATELIMIT:-0}
  XX_IMD_DROPDATA=${XX_IMD_DROPDATA:-0}
}

#
# Initializes all variables used by pdlfs-common.sh
# Only side-effect: $jobdir is created if it does not exist.
# Safe to be reinvoked without any side-effects.
#

init_all() {
  vpic_do_querying=${vpic_do_querying:-0}
  host_suffix=${host_suffix:-"dib"}
  ip_subnet=${ip_subnet:-10.94}
  vpic_epochs=${arg_vpic_epochs:-1}
  vpic_steps=$arg_vpic_epochs
  bbos_buddies=0

  vpic_nranks=${arg_vpic_nranks:-4}
  vpic_nodes=${arg_vpic_nodes:-1}
  vpic_ppn=${arg_vpic_ppn:-16}
  vpic_partcnt=${arg_vpic_partcnt:-$(million 1)}

  arg_jobdir_root=${arg_jobdir_root:-/tmp}
  arg_exp_type=${arg_exp_type:-misc-exp}
  arg_jobname=${arg_jobname:-unnamed-job}

  jobdir=$arg_jobdir_root/${arg_exp_type}-jobdir/$arg_jobname

  vpic_cpubind="none"

  if [ "$arg_exp_type" == "carp" ]; then
    init_carp
  else
    init_deltafs
  fi

  cores=$arg_vpic_nranks
  nodes=$arg_vpic_nodes
  ppn=$arg_vpic_ppn

  logfile=log.txt

  p=$arg_vpic_partcnt # particle count, actual number

  prelib=$dfsu_prefix/lib/libdeltafs-preload.so
  prelibq=""

  mkdir -p $jobdir
  gen_hosts
  get_bbdir
  gen_exptag
}


gen_jobdeck() {
  # product is internally scaled by 100
  px=$(( arg_vpic_partcnt / 10000 ))
  py=$(( 100 ))
  pz=$(( 1 ))

  tx=$arg_vpic_nranks
  ty=1
  tz=1

  if [ "$arg_exp_type" == "carp" ]; then
    jobbin=$dfsu_prefix/bin/range-runner
    jobsimargs="-i $carp_tracedir -t 6000 -m $arg_carp_dumpmap"
  else
    jobbin=$dfsu_prefix/bin/preload-runner
    jobsimargs="-t 6000"
  fi

  jobdeckargs="file-per-particle trecon-part/turbulence"
  jobszargs="$px $py $pz $tx $ty $pz $arg_vpic_epochs $vpic_steps"
  jobdeck="$jobbin $jobsimargs $jobdeckargs $jobszargs"
  echo $jobdeck
}

gen_exptag() {
  exp_tag=$arg_exp_type.run$arg_job_ridx
  exp_tag=${exp_tag}.nranks$arg_vpic_nranks
  exp_tag=${exp_tag}.epcnt$arg_vpic_epochs

  if [ "$arg_exp_type" == "carp" ]; then
    exp_tag=${exp_tag}.intvl$carp_intvl
    exp_tag=${exp_tag}.pvtcnt$carp_pvtcnt
  fi
}

run_exp() {
  echo "-INFO- Running exp type: $arg_exp_type"
  init_all
  gen_jobdeck # jobdeck is now defined
  vpic_do_run $arg_exp_type $p $ppn "$jobdeck" $exp_tag $prelib $prelibq
}

clean_exp() {
  init_all

  echo "-INFO Cleaning up exp: $exp_tag"

  fd idx $jobdir -x rm
  fd dat $jobdir -x rm
  fd RDB $jobdir -x rm
}

check_exp_ok() {
  init_all

  arg_ok_file=$jobdir/$exp_tag/$logfile
  if [ ! -f "$arg_ok_file" ]; then
    echo notok
  fi

  arg_ok_check=$(tail -100 $arg_ok_file | egrep 'BYE$' | wc -l)
  if [ "$arg_ok_check" -gt "0" ]; then
    return 0
  else
    return 1
  fi
}

run_exp_until_ok() {
  init_all
  run_exp

  arg_ret=0
  check_exp_ok || arg_ret=$?

  while [ "$arg_ret" != "0" ]; do
    clean_exp
    sleep 30
    run_exp

    arg_ret=0
    check_exp_ok || arg_ret=$?
  done
}

run_carp_micro() {
  FORCE=1 # run even if prev run completed

  arg_exp_type=carp
  arg_jobname=carp_micro

  arg_job_ridx=1
  arg_vpic_nranks=4
  arg_vpic_nodes=1
  arg_vpic_ppn=16
  arg_vpic_epochs=1 carp_intvl=500000 carp_pvtcnt=512
  arg_carp_dumpmap=$(dump_map_repfirst $arg_vpic_epochs)
  arg_vpic_partcnt=$(million 26)

  run_exp
}

run_deltafs_micro() {
  FORCE=1 # run even if prev run completed

  arg_exp_type=deltafs
  arg_jobname=carp_micro

  arg_job_ridx=1
  arg_vpic_nranks=4
  arg_vpic_nodes=1
  arg_vpic_ppn=16
  arg_vpic_epochs=1
  arg_vpic_partcnt=$(million 26)

  run_exp
}
