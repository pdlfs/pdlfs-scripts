#!/bin/bash -eu
#
#

source ../../common.sh
source pdlfs_common.sh

jobdir_root=/mnt/lt20ad1
carp_tracedir_pref=/mnt/lustre/carp-big-run
carp_tracedir=$carp_tracedir_pref/particle.compressed.uniform

million() {
  in=$1
  echo $(( in * 1000 * 1000 ))
}

dump_map_repfirst() {
  vpic_epochs=$1
  carp_dumpmap="0:$vpic_epochs"
  if [[ $vpic_epochs -gt 1 ]]; then
    carp_dumpmap=$carp_dumpmap,$(seq 1 $(( job_epcnt - 1 )) | sed 's/$/:0/g' | paste -sd,)
  fi
  echo $carp_dumpmap
}

dump_map_allonce() {
  vpic_epochs=$1
  carp_dumpmap=$(seq 0 $(( job_epcnt - 1 )) | sed 's/$/:1/g' | paste -sd,)
  echo $carp_dumpmap
}

init_carp() {
  # preload
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
  XX_CARP_OOBSZ=0
  XX_RTP_PVTCNT=$carp_pvtcnt

  # shuffle
  XX_SH_THREE_HOP=1
  XX_NX_ONEHG=1

  # plfs
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=0
}

init_deltafs() {
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
  XX_IMD_RATELIMIT=0
  XX_IMD_DROPDATA=0
}

init_all() {
  vpic_do_querying=${vpic_do_querying:-0}
  host_suffix=${host_suffix:-"dib"}
  ip_subnet=${ip_subnet:-10.94}
  vpic_epochs=${vpic_epochs:-1}
  vpic_steps=$vpic_epochs
  bbos_buddies=0

  vpic_nranks=${vpic_nranks:-4}
  vpic_nodes=${vpic_nodes:-1}
  vpic_ppn=${vpic_ppn:16}
  vpic_partcnt=${vpic_partcnt:-$(million 1)}

  jobdir_root=${jobdir_root:-/tmp}
  exp_type=${exp_type:-misc-exp}
  jobname=${jobname:-unnamed-job}

  jobdir=$jobdir_root/${exp_type}_jobdir/$jobname
  jobdir=$jobdir_pref/$jobname

  vpic_cpubind="none"

  if [ "$exp_type" == "carp"]; then
    init_carp
  else;
    init_deltafs
  fi

  cores=$vpic_nranks
  nodes=$vpic_nodes
  ppn=$vpic_ppn

  logfile=log.txt

  p=$vpic_partcnt # particle count, actual number

  prelib=$dfsu_prefix/lib/libdeltafs-preload.so
  prelibq=""

  mkdir -p $jobdir
  gen_hosts
  get_bbdir
}


gen_jobdeck() {
  # product is internally scaled by 100
  px=$(( vpic_partcnt / 10000 ))
  py=$(( 100 ))
  pz=$(( 1 ))

  tx=$vpic_nranks
  ty=1
  tz=1

  if [ "$exptype" == "carp" ]; then
    jobbin=$dfsu_prefix/bin/range-runner
    jobsimargs="-i $carp_tracedir -t 6000 -m $carp_dumpmap"
  else;
    jobbin=$dfsu_prefix/bin/preload-runner
    jobsimargs=""
  fi

  jobdeckargs="file-per-particle trecon-part/turbulence"
  jobszargs="$px $py $pz $tx $ty $pz $vpic_epochs $vpic_steps"
  jobdeck="$jobbin $jobsimargs $jobdeckargs $jobszargs"
  echo $jobdeck
}

gen_exptag() {
  exp_tag=$exptype.run$job_ridx
  exp_tag=${exp_tag}.nranks$vpic_nranks
  exp_tag=${exp_tag}.epcnt$vpic_epochs

  if [ "$exptype" == "carp" ]; then
    exp_tag=${exp_tag}.intvl$carp_intvl
    exp_tag=${exp_tag}.pvtcnt$carp_pvtcnt
  fi
}

run_exp() {
  echo "- INFO - Running exp type: $exp_type"

  gen_exptag
  init_all
  gen_jobdeck # jobdeck is now defined

  echo $exptype
  echo $jobdeck
  echo $exp_tag
  echo $XX_FDATA_SIZE
  # vpic_do_run $exptype $p $ppn "$jobdeck" $exp_tag $prelib $prelibq
}

run_carp_micro() {
  FORCE=1 # run even if prev run completed

  exp_type=carp
  jobname=carp_micro

  job_ridx=1
  vpic_nranks=4
  vpic_nodes=1
  vpic_ppn=16
  vpic_epochs=1
  carp_intvl=500000
  carp_pvtcnt=512
  carp_dumpmap=$(dump_map_repfirst $vpic_epochs)
  vpic_partcnt=$(million 26)

  run_exp
}

run_deltafs_micro() {
  FORCE=1 # run even if prev run completed

  exp_type=deltafs
  jobname=carp_micro

  job_ridx=1
  vpic_nranks=4
  vpic_nodes=1
  vpic_ppn=16
  vpic_epochs=1
  vpic_partcnt=$(million 26)

  run_exp
}

run_carp_micro
