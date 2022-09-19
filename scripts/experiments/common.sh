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
 
INSTALL_DIR=$(get_install_dir)
