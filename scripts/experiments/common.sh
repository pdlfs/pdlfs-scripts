#!/usr/bin/env bash

# u: error if var undefined. x: trace each cmd
set -ux

get_install_dir() {
  script_dir=$(realpath $0)
  install_root=$script_dir

  while [ "$(basename $install_root)" != "scripts" ]; do
    install_root=$(dirname $install_root)
  done

  install_root=$(dirname $install_root)

  echo $install_root
}
 

INSTALL_DIR=$(get_install_dir)
