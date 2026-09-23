SUMMARY = "Sets up cargo in an SDK to cross-compile Rust applications that use Slint"
DESCRIPTION = "Add this to TOOLCHAIN_TARGET_TASK to have the SDK's \
environment-setup script also configure cargo for the target: the Rust \
target, the linker, and the bindgen flags that Slint's Skia renderer needs \
to build. The Rust toolchain itself comes from rustup."
HOMEPAGE = "https://slint.dev/"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# For rust_target(): the same target triple as cargo_bin builds for, which is
# one rustup ships the standard library for.
inherit rust_bin-common

SLINT_SDK_RUST_TARGET = "${@rust_target(d, 'TARGET')}"
SLINT_SDK_RUST_TARGET_ENV = "${@d.getVar('SLINT_SDK_RUST_TARGET').replace('-', '_')}"
SLINT_SDK_LINKER = "${datadir}/${BPN}/linker"

# rust_target() goes by the machine's tune features, not just the architecture.
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Nothing is compiled, only two scripts installed.
INHIBIT_DEFAULT_DEPS = "1"
do_configure[noexec] = "1"
do_compile[noexec] = "1"

# The SDK's environment-setup script sources the *.sh files in the target
# sysroot's /environment-setup.d, after exporting CC, LDFLAGS, SDKTARGETSYSROOT
# and OECORE_TUNE_CCARGS.
do_install() {
    install -d ${D}/environment-setup.d
    cat > ${D}/environment-setup.d/slint-rust.sh <<'END'
# Set up cargo to cross-compile Rust applications, for example ones that use
# Slint with the Skia renderer, for this SDK's target. Installed by
# slint-rust-sdk-env from meta-slint.
#
# The Rust toolchain is not part of the SDK. Install it with rustup and add
# the target: rustup target add ${SLINT_SDK_RUST_TARGET}

export CARGO_BUILD_TARGET="${SLINT_SDK_RUST_TARGET}"
export CARGO_TARGET_${@d.getVar('SLINT_SDK_RUST_TARGET_ENV').upper()}_LINKER="$SDKTARGETSYSROOT${SLINT_SDK_LINKER}"
export PKG_CONFIG_ALLOW_CROSS=1

# Build scripts and proc-macros are compiled for the host: keep the cc crate
# from using the target's $CC and $CFLAGS for them.
export HOST_CC=cc
export HOST_CXX=c++
export HOST_CFLAGS=
export HOST_CXXFLAGS=

# skia-bindings runs bindgen over the Skia headers: parse them with the
# target's ABI flags, against the target sysroot. To build Skia itself,
# skia-bindings picks up CLANGCC/CLANGCXX (which meta-clang sets with
# CLANGSDK = "1") and SDKTARGETSYSROOT on its own.
export BINDGEN_EXTRA_CLANG_ARGS_${SLINT_SDK_RUST_TARGET_ENV}="$OECORE_TUNE_CCARGS --sysroot=$SDKTARGETSYSROOT"
END

    install -d ${D}${datadir}/${BPN}
    cat > ${D}${SLINT_SDK_LINKER} <<'END'
#!/bin/sh
# cargo takes a single executable as the linker, but the SDK's $CC carries the
# target flags and the sysroot.
exec $CC $LDFLAGS "$@"
END
    chmod 0755 ${D}${SLINT_SDK_LINKER}
}

FILES:${PN} = "/environment-setup.d ${datadir}/${BPN}"

# The linker wrapper runs on the SDK host, not on the target, so it needs no
# /bin/sh on the target.
INSANE_SKIP:${PN} += "file-rdeps"
