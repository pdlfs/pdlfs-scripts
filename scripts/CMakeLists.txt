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
# 28-Feb-2017  chuck@ece.cmu.edu
#

#
# set ${all} true if we are not filtering on UMBRELLA_BINARY_DIR and
# thus want everything...
#
set(all 1)
if (NOT "${UMBRELLA_BINARY_DIR}" STREQUAL "")
    if (EXISTS ${UMBRELLA_BINARY_DIR})
        set(all 0)
    else()
        message(WARNING "UMBRELLA_BINARY_DIR set, but not present!")
    endif()
endif()

#
# scripts we always install
#
set (install-files )
set (install-programs cbatch cobalt_nodefile ethq.pl slurm_nodefile)
set (install-programs-in common.sh.in run_rtp_bench.sh.in)

#
# deltafs-bb scripts
#
if (all OR EXISTS "${UMBRELLA_BINARY_DIR}/deltafs-bb-prefix")
    list (APPEND install-programs basic-bb.sh)
    list (APPEND install-programs-in run_bbos_test.sh.in)
endif()

#
# mercury-runner scripts
#
if (all OR EXISTS "${UMBRELLA_BINARY_DIR}/mercury-runner-prefix")
    list (APPEND install-programs process_logs.sh process_runner.pl
                                  report_runner.pl)
    list (APPEND install-programs-in anl_do_combo_mercrunner.sh.in
                                     lanl_do_combo_mercrunner.sh.in
                                     run_combo_mercury_runner.sh.in)
endif()

#
# vpic scripts
#
if (all OR EXISTS "${UMBRELLA_BINARY_DIR}/vpic-prefix"
        OR EXISTS "${UMBRELLA_BINARY_DIR}/vpic407-prefix")
    list (APPEND install-files vpic_plots.R)
    list (APPEND install-programs vpic_common.sh vpic_report.sh
                                  vpic_cleanup.pl)
    list (APPEND install-programs-in run_vpic_test.sh.in vpic_mkcombo.pl.in
                                     vpicexpt_gen.pl.in)
endif()

#
# end of scripts.   now we can configure and install...
#

#
# expand ${install-programs-in} and build a list of output files for install
#
foreach (lcv ${install-programs-in})
    string (REGEX REPLACE "\\.in$" "" out "${lcv}")
    configure_file (${lcv} ${out} @ONLY)
    list (APPEND install-programs-in-done ${CMAKE_CURRENT_BINARY_DIR}/${out})
endforeach ()

#
# "make install" rules
#
install (FILES ${install-files} DESTINATION scripts)
install (PROGRAMS ${install-programs} DESTINATION scripts)
install (PROGRAMS ${install-programs-in-done} DESTINATION scripts)
