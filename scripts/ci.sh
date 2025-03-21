#!/bin/bash

set -ex

branch=$1
shift

for dir in poky meta-openembedded meta-clang; do
    pushd $dir
    git status
    git checkout -f $branch
    popd
done

cd poky
. oe-init-build-env
bitbake-layers show-layers
bitbake -c compile slint-hello-world
bitbake -c compile slint-demos
bitbake core-image-minimal -c populate_sdk
