#!/usr/bin/env bash

# u: error if var undefined. x: trace each cmd
set -ux

get_install_dir() {
  SCRIPT_DIR=$(realpath $0)
  INSTALL_ROOT=$SCRIPT_DIR

  while [ "$(basename $INSTALL_ROOT)" != "scripts" ]; do
    INSTALL_ROOT=$(dirname $INSTALL_ROOT)
  done

  INSTALL_ROOT=$(dirname $INSTALL_ROOT)

  echo $INSTALL_ROOT
}

gen_hostfile() {
  NHOSTS=$1
  PREFIX=$2
  SUFFIX=$3

  echo "Generating hosts.txt with $NHOSTS hosts (Pref/Suff: $PREFIX/$SUFFIX)"
  HOSTFILE=hosts.txt
  rm $HOSTFILE || /bin/true

  for i in $(seq 0 $(($NHOSTS - 1))); do
    echo $PREFIX$i$SUFFIX >> $HOSTFILE
  done
}

gen_hostfile_from_ui() {
  if [ ! -f hosts.txt ]; then
    echo "hosts.txt does not exist... creating"
  else
    echo "hosts.txt found! using it"
    return 0
  fi

  nhosts=32
  prefix=h
  suffix=-dib:16

  nhosts_in=""
  prefix_in=""
  suffix_in=""

  read -p "nhosts [$nhosts]: " $nhosts_in
  read -p "prefix [$prefix]: " $prefix_in
  read -p "suffix [$suffix]: " $suffix_in

  if [ "$nhosts_in" != "" ]; then
    nhosts=$nhosts_in
  fi

  if [ "$prefix_in" != "" ]; then
    prefix=$prefix_in
  fi

  if [ "$suffix_in" != "" ]; then
    suffix=$suffix_in
  fi

  gen_hostfile $nhosts $prefix $suffix
}
 
INSTALL_DIR=$(get_install_dir)
