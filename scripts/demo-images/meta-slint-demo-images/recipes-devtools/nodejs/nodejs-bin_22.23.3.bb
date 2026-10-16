SUMMARY = "Node.js and npm, as a prebuilt binary"
DESCRIPTION = "Installs the Node.js project's release build of node, npm, npx \
and corepack, to run JavaScript and install npm packages on the target."
HOMEPAGE = "https://nodejs.org/"
# As meta-oe's nodejs recipe of the same version.
LICENSE = "MIT & ISC & BSD-2-Clause & BSD-3-Clause & Artistic-2.0 & Apache-2.0 & BlueOak-1.0.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=b195f4ea4368177a2fd84b879f09cba8"

# Prebuilt rather than meta-oe's nodejs: building V8 from source would add a
# long, memory-hungry build to every image. Node 22 is the newest release line
# with an official armv7 build, which the STM32MP1 needs.
NODE_ARCH = "unsupported"
NODE_ARCH:aarch64 = "arm64"
NODE_ARCH:arm = "armv7l"
COMPATIBLE_HOST = "(aarch64|arm).*-linux.*"
COMPATIBLE_HOST:libc-musl = "null"

# Unpack into ${BP} without the tarball's top-level directory, so the files end
# up in the default S on every release: under UNPACKDIR on walnascar+, and
# under WORKDIR on scarthgap, whose bitbake has no UNPACKDIR.
SRC_URI = "https://nodejs.org/dist/v${PV}/node-v${PV}-linux-${NODE_ARCH}.tar.xz;name=${NODE_ARCH};subdir=${BP};striplevel=1"
SRC_URI[arm64.sha256sum] = "a44aeb94849a299b22df10b9e622ec2f605c2183501bc40590705131de7c740f"
SRC_URI[armv7l.sha256sum] = "590a2768199bdd0b848648a81cd7f07f88a5ceb27949f0c70d5e6652c3eaca69"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

# npm, npx and corepack are symlinks into lib/node_modules, relative to bindir.
do_install() {
    install -d ${D}${bindir} ${D}${nonarch_libdir} ${D}${includedir}
    install -m 0755 ${S}/bin/node ${D}${bindir}
    cp -R --no-preserve=ownership ${S}/lib/node_modules ${D}${nonarch_libdir}
    cp -R --no-preserve=ownership ${S}/include/node ${D}${includedir}
    ln -s ../lib/node_modules/npm/bin/npm-cli.js ${D}${bindir}/npm
    ln -s ../lib/node_modules/npm/bin/npx-cli.js ${D}${bindir}/npx
    ln -s ../lib/node_modules/corepack/dist/corepack.js ${D}${bindir}/corepack
}

# The same split as meta-oe's nodejs: node on its own, and npm with its
# scripts' interpreters (node-gyp brings Python scripts).
PACKAGES =+ "${PN}-npm"
FILES:${PN}-npm = "${nonarch_libdir}/node_modules ${bindir}/npm ${bindir}/npx ${bindir}/corepack"
RDEPENDS:${PN}-npm = "${PN} bash python3-core python3-shell python3-datetime \
    python3-misc python3-multiprocessing"

# Built and linked by the Node.js project, not by our toolchain: our LDFLAGS
# were never applied (the armv7 build has no GNU_HASH section).
INSANE_SKIP:${PN} += "ldflags"
# The armv7 build uses the 32-bit time_t API, so it isn't Y2038-safe. This
# check reads the recipe-wide INSANE_SKIP, not the per-package one.
INSANE_SKIP += "32bit-time"
