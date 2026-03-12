inherit cargo
inherit pkgconfig

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master"
SRCREV = "${AUTOREV}"
SRC_URI += "file://0001-WIP-v-1-14-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=093007ec281bbdeea447b0040b01a74d"

# skia-bindings 0.90.0 needs tag m142-0.89.1 from rust-skia/skia - fetch via commit hash
SKIA_COMMIT = "d6b5e2f8677dfcbecb882cc1237b5d8a73e45c56"

# Pre-download Skia source via bitbake's fetcher (proxy/mirror aware, cached)
SRC_URI += "https://github.com/rust-skia/skia/archive/${SKIA_COMMIT}.tar.gz;downloadfilename=skia-source-${SKIA_COMMIT}.tar.gz;name=skia;unpack=0"
SRC_URI[skia.sha256sum] = "a13007290588a3810a68d9a3d476ca766904d16a4c2ab4803b759659ecd555d2"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPL-3.0-only | Slint-Commercial"

# QA exceptions for GitHub archive URLs and embedded build paths (Rust/Skia artifacts)
ERROR_QA:remove = "src-uri-bad"
WARN_QA:append = " src-uri-bad"
INSANE_SKIP:${PN} += "buildpaths"

inherit slint_common
inherit features_check

PV = "git-${SRCPV}"

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgl"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " gn-native ninja-native python3-native"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

CARGO_DISABLE_BITBAKE_VENDORING = "1"

# cargo.bbclass handles compilation directly using -p slint to build only the Slint UI framework with Skia+KMS features
CARGO_BUILD_FLAGS = "-v --target ${RUST_HOST_SYS} ${BUILD_MODE} --manifest-path=${CARGO_MANIFEST_PATH} -p slint --features 'slint/backend-linuxkms slint/renderer-skia'"

# Increase network timeouts: Skia source + dependencies can take several minutes
export CARGO_HTTP_TIMEOUT = "600"
export CARGO_NET_RETRY = "5"

do_configure[network] = "1"
do_compile[network] = "1"

BBCLASSEXTEND = "native"

# Prepare Skia source with all third-party dependencies, download Skia via bitbake's fetcher, and run git-sync-deps
do_configure:append() {
    SKIA_PREP_DIR="${UNPACKDIR}/skia-source"

    if [ ! -f "${SKIA_PREP_DIR}/.skia-deps-synced" ]; then
        bbnote "Preparing Skia source with dependencies..."

        # Extract Skia source from bitbake-downloaded tarball
        rm -rf ${SKIA_PREP_DIR}
        tar -xzf ${DL_DIR}/skia-source-${SKIA_COMMIT}.tar.gz -C ${UNPACKDIR}
        mv ${UNPACKDIR}/skia-${SKIA_COMMIT} ${SKIA_PREP_DIR}

        # Place native gn binary where Skia expects it
        mkdir -p ${SKIA_PREP_DIR}/bin
        mkdir -p ${SKIA_PREP_DIR}/third_party/gn
        cp ${STAGING_BINDIR_NATIVE}/gn ${SKIA_PREP_DIR}/bin/gn
        chmod +x ${SKIA_PREP_DIR}/bin/gn
        cp ${STAGING_BINDIR_NATIVE}/gn ${SKIA_PREP_DIR}/third_party/gn/gn
        chmod +x ${SKIA_PREP_DIR}/third_party/gn/gn

        # Replace fetch-gn with a no-op (gn is already in place)
        cat > ${SKIA_PREP_DIR}/bin/fetch-gn << 'FETCHGN'
#!/usr/bin/env python3
import sys
sys.exit(0)
FETCHGN
        chmod +x ${SKIA_PREP_DIR}/bin/fetch-gn

        # Run git-sync-deps to download third-party dependencies (icu, harfbuzz, etc.)
        # Git protocol works in Yocto sandbox (unlike HTTP/Python downloads)
        cd ${UNPACKDIR}
        GIT_SYNC_DEPS_PATH="${SKIA_PREP_DIR}/DEPS" \
        GIT_SYNC_DEPS_SKIP_EMSDK=1 \
        python3 ${SKIA_PREP_DIR}/tools/git-sync-deps
        cd -

        touch ${SKIA_PREP_DIR}/.skia-deps-synced
        bbnote "Skia source prepared with all dependencies at ${SKIA_PREP_DIR}"
    fi
}

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE

    # Point skia-bindings to use pre-prepared Skia source
    export SKIA_SOURCE_DIR="${UNPACKDIR}/skia-source"
    export SKIA_GN_COMMAND="${STAGING_BINDIR_NATIVE}/gn"
    export SKIA_NINJA_COMMAND="${STAGING_BINDIR_NATIVE}/ninja"
}

do_compile:append() {
    # Reduce RAM requirements
    export CARGO_PROFILE_RELEASE_LTO=false
    for p in slide_puzzle printerdemo gallery opengl_texture opengl_underlay energy-monitor home-automation; do
        cargo build ${CARGO_BUILD_FLAGS} -p $p
    done
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}/"*.so
    rm -f "${B}/target/${CARGO_TARGET_SUBDIR}/"*.rlib
}
