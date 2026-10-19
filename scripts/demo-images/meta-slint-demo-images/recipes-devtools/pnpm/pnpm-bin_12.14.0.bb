SUMMARY = "pnpm, the Node.js package manager, as a prebuilt binary"
DESCRIPTION = "Installs the pnpm project's release build of pnpm, pn, pnpx \
and pnx, to install npm packages on the target."
HOMEPAGE = "https://pnpm.io/"
# pnpm, the Yarn code its notices list, and the node-gyp it bundles in dist/.
LICENSE = "MIT & BSD-2-Clause & ISC & BlueOak-1.0.0 & Apache-2.0"
LIC_FILES_CHKSUM = " \
    file://exe/LICENSE;md5=82fba89fc579f3f8db344019809824f6 \
    file://wrapper/THIRD-PARTY-NOTICES.md;md5=6249caa2386b053c2f739f167bcc18e0 \
"

# Since pnpm 12, pnpm is a native (Rust) binary. The pnpm npm package is only a
# wrapper that runs the binary of the matching @pnpm/exe.<target> package, and
# carries the node-gyp the binary runs for native addons. There's no 32-bit
# Arm binary and no JavaScript fallback, so the armv7 images go without pnpm.
COMPATIBLE_HOST = "aarch64.*-linux.*"
COMPATIBLE_HOST:libc-musl = "null"

# Unpack below ${BP}, so the files end up in the default S on every release:
# under UNPACKDIR on walnascar+, and under WORKDIR on scarthgap, whose bitbake
# has no UNPACKDIR.
SRC_URI = " \
    https://registry.npmjs.org/pnpm/-/pnpm-${PV}.tgz;name=wrapper;subdir=${BP}/wrapper;striplevel=1 \
    https://registry.npmjs.org/@pnpm/exe.linux-arm64/-/exe.linux-arm64-${PV}.tgz;name=exe;subdir=${BP}/exe;striplevel=1 \
"
SRC_URI[wrapper.sha256sum] = "ea206e35474bf87be9564a85ca70ed1c8ebdc45da55aafb0a3bf09d1ba69b179"
SRC_URI[exe.sha256sum] = "e7ca24224eb626a032828ec584c67903ad2f389911b849d009ed70a19f70d8d3"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

PNPM_DIR = "${nonarch_libdir}/node_modules/pnpm"
PNPM_BINS = "pnpm pn pnpx pnx"

# The layout `npm install -g pnpm` gives: the wrapper package, with the native
# binary in place of its placeholder bins. Those have to be hard links, not
# symlinks: the binary tells pnpx from pnpm by the name of the file it runs
# from, with symlinks resolved.
do_install() {
    install -d ${D}${PNPM_DIR} ${D}${bindir}
    cp -R --no-preserve=ownership ${S}/wrapper/. ${D}${PNPM_DIR}
    install -m 0755 ${S}/exe/pnpm ${D}${PNPM_DIR}/pnpm
    for bin in ${PNPM_BINS}; do
        if [ "$bin" != pnpm ]; then
            rm -f ${D}${PNPM_DIR}/$bin
            ln ${D}${PNPM_DIR}/pnpm ${D}${PNPM_DIR}/$bin
        fi
        ln -s ../lib/node_modules/pnpm/$bin ${D}${bindir}/$bin
    done
}

FILES:${PN} += "${PNPM_DIR}"

# The wrapper's scripts and the package scripts pnpm runs need Node.js, and
# node-gyp brings Python scripts, as for npm.
RDEPENDS:${PN} = "nodejs-bin bash python3-core python3-shell python3-datetime \
    python3-misc python3-multiprocessing"

# Built and linked by the pnpm project, not by our toolchain: the binary comes
# stripped.
INSANE_SKIP:${PN} += "already-stripped"
