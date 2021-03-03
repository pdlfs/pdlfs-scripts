# pdlfs-scripts
scripts for use with pdlfs-related projects

# overview

This repository contains scripts we use for running pdlfs-related
projects.

# building

Use cmake to build and install pdlfs-scripts:

```bash
git clone https://github.com/pdlfs/pdlfs-scripts.git
cd pdlfs-scripts
mkdir build
cd build
cmake \
-DCMAKE_INSTALL_PREFIX=</tmp/deltafs-nexus-prefix> \
..
make
make install
```

## additional cmake option variables

```
-DVPIC407:STRING=0                      set to 1 if using VPIC407
-DUMBRELLA_BINARY_DIR=dir               umbrella CMAKE_BINARY_DIR
```

The VPIC407 variable is expanded in run_vpic_test.sh.in.
UMBRELLA_BINARY_DIR is optional. If you set it to the
umbrella CMAKE_BINARY_DIR then we will look there to see
what umbrella targets are configured and only install scripts
for those targets.
