#!/bin/bash

set -ex

cd bitbake-builds/poky-master
. build/init-build-env
bitbake-layers show-layers
bitbake -c compile slint-hello-world
bitbake -c compile slint-demos
# Disabled: populate_sdk pushes the total run time past GitHub Actions'
# 6h job timeout on the Hetzner cx53 runner. The hello-world + demos
# compiles together already exercise slint-cpp and the cargo plumbing;
# re-enable once we've sped things up (bigger runner, less conservative
# BB_NUMBER_THREADS / CARGO_BUILD_JOBS, or a higher timeout-minutes).
#bitbake core-image-minimal -c populate_sdk
