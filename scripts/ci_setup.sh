#!/bin/bash
set -ex

# poky's master branch is just a README now; use bitbake-setup from bitbake
# itself. Clone only bitbake to bootstrap it.
git clone -b master https://git.openembedded.org/bitbake

# The poky-with-sstate configuration bundles the sstate CDN mirror fragment,
# so we inherit BB_HASHSERVE_UPSTREAM + SSTATE_MIRRORS automatically.
./bitbake/bin/bitbake-setup init --non-interactive \
    poky-master poky-with-sstate distro/poky machine/qemuarm64

# bitbake-setup lands the build under bitbake-builds/poky-master/ (a
# bitbake-builds "top dir" wrapper plus the setup-dir-name from the
# registry config). Drop our two extra layers alongside the ones it cloned.
git clone -b master https://github.com/kraj/meta-clang.git bitbake-builds/poky-master/layers/meta-clang
ln -s "$(cd "$(dirname "$0")/.." && pwd)" bitbake-builds/poky-master/layers/meta-slint

cd bitbake-builds/poky-master
. build/init-build-env
bitbake-layers add-layer ../layers/meta-clang
bitbake-layers add-layer ../layers/meta-slint

echo 'PREFERRED_PROVIDER_virtual/kernel = "linux-dummy"' >> conf/local.conf
echo 'CLANGSDK = "1"' >> conf/local.conf
echo 'PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-skia system-testing"' >> conf/local.conf
echo 'TOOLCHAIN_HOST_TASK:append = " nativesdk-slint-cpp"' >> conf/local.conf
echo 'INHERIT:remove = "create-spdx"' >> conf/local.conf
# Cap parallelism: Hetzner cx53 has 32G RAM but rustc + LTO linking the
# slint crate graph can spike multiple GB per job. Build-time wins from
# parallelism don't help if a single oversubscribed task OOMs the box.
echo 'BB_NUMBER_THREADS = "4"' >> conf/local.conf
echo 'PARALLEL_MAKE = "-j 4"' >> conf/local.conf
echo 'export CARGO_BUILD_JOBS = "2"' >> conf/local.conf
