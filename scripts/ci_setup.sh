#!/bin/bash
set -ex

# Test against the latest Yocto release (wrynose, 6.0), not master. Master is a
# moving target -- e.g. meta-rust-bin's rust-bin prebuilt handling currently
# breaks there -- and isn't what we ship. poky's git has no release branches
# (its master is just a README), so use bitbake-setup: its poky-wrynose config
# assembles the release from openembedded-core@wrynose + meta-yocto@wrynose and
# pins bitbake. Clone bitbake only to bootstrap the tool.
git clone -b master https://git.openembedded.org/bitbake

# poky-with-sstate bundles the sstate CDN mirror fragment, so we inherit
# BB_HASHSERVE_UPSTREAM + SSTATE_MIRRORS automatically.
./bitbake/bin/bitbake-setup init --non-interactive \
    poky-wrynose poky-with-sstate distro/poky machine/qemuarm64

# bitbake-setup lands the build under bitbake-builds/poky-wrynose/ (setup-dir-name
# "$distro-wrynose" with distro/poky). Drop our extra layers alongside the ones it
# cloned: meta-clang at the release, meta-rust-bin at master (no release branch).
git clone -b wrynose https://github.com/kraj/meta-clang.git bitbake-builds/poky-wrynose/layers/meta-clang
git clone https://github.com/rust-embedded/meta-rust-bin.git bitbake-builds/poky-wrynose/layers/meta-rust-bin
ln -s "$(cd "$(dirname "$0")/.." && pwd)" bitbake-builds/poky-wrynose/layers/meta-slint

cd bitbake-builds/poky-wrynose
. build/init-build-env
# meta-rust-bin (rust-bin-layer) before meta-slint, which LAYERDEPENDS on it.
bitbake-layers add-layer ../layers/meta-clang
bitbake-layers add-layer ../layers/meta-rust-bin
bitbake-layers add-layer ../layers/meta-slint

echo 'PREFERRED_PROVIDER_virtual/kernel = "linux-dummy"' >> conf/local.conf
echo 'CLANGSDK = "1"' >> conf/local.conf
echo 'PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-skia system-testing"' >> conf/local.conf
echo 'TOOLCHAIN_HOST_TASK:append = " nativesdk-slint-cpp"' >> conf/local.conf
echo 'INHERIT:remove = "create-spdx"' >> conf/local.conf
# Cap parallelism: the runner has 32G RAM but rustc + LTO linking the slint
# crate graph can spike multiple GB per job, so an oversubscribed task can OOM
# the box. Build-time wins from parallelism don't help if a single task OOMs.
echo 'BB_NUMBER_THREADS = "4"' >> conf/local.conf
echo 'PARALLEL_MAKE = "-j 4"' >> conf/local.conf
echo 'export CARGO_BUILD_JOBS = "2"' >> conf/local.conf
