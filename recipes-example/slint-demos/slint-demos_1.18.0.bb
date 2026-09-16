inherit cargo_bin
inherit pkgconfig

# Pinned to a release (not master): the demos get reshuffled on master. v1.18.0 tag.
SLINT_REV = "bd20dab8529add087b5cbc81aec70bf30861ae4c"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"
SRC_URI += "file://0001-WIP-v-1-18-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=eddf02df1cb330c56cc727e9e3a379c9"

SUMMARY = "Various Rust-based demos of Slint packaged up in /usr/bin"
DESCRIPTION = "This recipe builds various Slint demos such as the energy monitor \
or the printer demo and installs the binaries into /usr/bin."
HOMEPAGE = "https://slint.dev/"
LICENSE = "GPL-3.0-only | Slint-Commercial"

inherit slint_common
inherit features_check

REQUIRED_DISTRO_FEATURES:append = ""
REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgles2"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH} ca-certificates-native curl-native ninja-native"
DEPENDS:append:class-target = " libdrm virtual/egl virtual/libgbm seatd udev libinput"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

CARGO_DISABLE_BITBAKE_VENDORING = "1"

# Since 1.18 the demos and the examples are each their own cargo workspace, with
# the repository root excluding both, so the binaries below come from two
# manifests and no single `cargo build` covers them. The class builds the demos/
# workspace from CARGO_MANIFEST_PATH; do_compile:append builds the examples/ one.
CARGO_MANIFEST_PATH = "${S}/demos/Cargo.toml"

# Build only the demo binaries. A bare `cargo build` compiles a whole workspace,
# which is slow and pulls in binaries other recipes ship -- that is how
# slint-demos once came to install /usr/bin/slint-viewer and clash with the
# slint-viewer package at rootfs time. Scope each build with one -p per binary.
# cargo_bin turns CARGO_FEATURES into --features on its own; the second
# invocation has to pass them itself.
EXTRA_CARGO_FLAGS = "${@' '.join('-p ' + p for p in (d.getVar('SLINT_DEMOS') or '').split())}"
SLINT_EXAMPLES_CARGO_FLAGS = "${@' '.join('-p ' + p for p in (d.getVar('SLINT_EXAMPLES') or '').split())}"

do_configure[network] = "1"
do_compile[network] = "1"


BBCLASSEXTEND = "native"

CARGO_FEATURES = "slint/backend-linuxkms slint/renderer-skia"

SLINT_DEMOS = "printerdemo energy-monitor home-automation"
SLINT_EXAMPLES = "slide_puzzle gallery opengl_texture opengl_underlay"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
    # Skia + LTO is very RAM-hungry; keep LTO off.
    export CARGO_PROFILE_RELEASE_LTO=false
}
do_compile:append() {
    # The second workspace. cargo_bin_do_compile has already exported the
    # cross-compilation environment and CARGO_TARGET_DIR, and do_compile:prepend
    # the CA bundle and the LTO override, so this invocation only has to restate
    # the flags the class built from CARGO_MANIFEST_PATH and EXTRA_CARGO_FLAGS.
    # Both workspaces write into the same target directory, so every binary ends
    # up in CARGO_BINDIR for cargo_bin_do_install to pick up.
    bbnote cargo build --manifest-path "${S}/examples/Cargo.toml" ${SLINT_EXAMPLES_CARGO_FLAGS}
    cargo build --verbose \
        --manifest-path "${S}/examples/Cargo.toml" \
        --target="${RUST_TARGET}" \
        --profile="${CARGO_BUILD_PROFILE}" \
        --features "${CARGO_FEATURES}" \
        ${SLINT_EXAMPLES_CARGO_FLAGS}

    # cargo_bin_do_install ships every .so/.rlib next to the demo binaries; drop
    # them so the demos package carries just the executables.
    rm -f "${CARGO_BINDIR}"/*.so
    rm -f "${CARGO_BINDIR}"/*.rlib
}

# The demo binaries carry absolute build paths that the Rust --remap-path-prefix
# cannot rewrite: the slint compiler bakes the gettext translation dir
# (examples/*/lang) in as a string literal, and the vendored aws-lc-sys C crate
# bakes its source paths into debug info. These are example binaries, so accept
# the paths rather than chase every embedder. (slint-cpp/viewer/launcher are fully
# remapped and keep the check.)
INSANE_SKIP:${PN} += "buildpaths"
INSANE_SKIP:${PN}-dbg += "buildpaths"
INSANE_SKIP:${PN}-src += "buildpaths"
