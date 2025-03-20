#!/bin/bash
set -ex

git clone -b kirkstone git://git.yoctoproject.org/poky
git clone -b kirkstone git://git.openembedded.org/meta-openembedded
git clone -b master https://github.com/rust-embedded/meta-rust-bin.git
git clone -b kirkstone https://github.com/kraj/meta-clang.git

cd poky
. oe-init-build-env
bitbake-layers add-layer ../../meta-openembedded/meta-oe
bitbake-layers add-layer ../../meta-rust-bin
bitbake-layers add-layer ../../meta-clang
bitbake-layers add-layer ../../meta-slint
echo 'PREFERRED_PROVIDER_virtual/kernel = "linux-dummy"' >> conf/local.conf
echo 'MACHINE = "qemuarm64"' >> conf/local.conf
echo 'CLANGSDK = "1"' >> conf/local.conf
echo 'PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-skia system-testing"' >> conf/local.conf
echo 'TOOLCHAIN_HOST_TASK:append = " nativesdk-slint-cpp"' >> conf/local.conf

