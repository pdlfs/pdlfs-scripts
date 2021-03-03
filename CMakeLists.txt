#
# Copyright (c) 2019-2021 Carnegie Mellon University,
# Copyright (c) 2019-2021 Triad National Security, LLC, as operator of
#     Los Alamos National Laboratory.
#
# All rights reserved.
#
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file. See the AUTHORS file for names of contributors.
#

#
# CMakeLists.txt  pdlfs scripts
# 03-Mar-2021  chuck@ece.cmu.edu
#

# command line config:
#
# -DCMAKE_INSTALL_PREFIX=/tmp/delta       where to install
#                                         defaults to /usr/local
# -DVPIC407:STRING=0                      set to 1 if using VPIC407
# -DUMBRELLA_BINARY_DIR=dir               umbrella CMAKE_BINARY_DIR
#
# the VPIC407 variable is expanded in run_vpic_test.sh.in
# UMBRELLA_BINARY_DIR is optional... if you set this to the
# umbrella CMAKE_BINARY_DIR we will look there to see what targets
# are configured and only install scripts for those targets.
#
# 3 key variables: install-files, install-programs, and install-programs-in

cmake_minimum_required (VERSION 3.0)
project (pdlfs-scripts NONE)

#
# keep scripts in a subdir to reduce clutter in the top-level directory
#
add_subdirectory(scripts)
