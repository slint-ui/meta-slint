inherit cargo

SUMMARY = "UI Toolkit"
DESCRIPTION = "Slint is a toolkit to efficiently develop fluid graphical \
user interfaces for any display: embedded devices and desktop applications. \
We support multiple programming languages, such as Rust, C++, and JavaScript."
HOMEPAGE = "https://github.com/slint-ui/slint"
BUGTRACKER = "https://github.com/slint-ui/slint/issues"

LICENSE = "GPLv3 | Slint-Commercial"
LIC_FILES_CHKSUM="file://LICENSE.md;md5=29c2662b4609df90253e15270c25629d"

inherit cmake

REQUIRED_DISTRO_FEATURES = "opengl"

DEPENDS = "fontconfig libxcb wayland clang-cross-${TARGET_ARCH} virtual/libgl"

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=simon/skia-yocto-fixes;rev=e7aba62eada8dc1598077c7bb1a0c5f679364a12"
PV = "slint-cpp-${SRCPV}"

S = "${WORKDIR}/git"
	
CARGO_DISABLE_BITBAKE_VENDORING = "1"

# For FetchContent of corrosion
do_configure[network] = "1"
# For crate dependencies from crates.io
do_compile[network] = "1"

do_configure() {
    echo "set(CMAKE_SYSROOT \"${RECIPE_SYSROOT}\")" >> ${WORKDIR}/toolchain.cmake
    cargo_common_do_configure
    cmake_do_configure
}

do_compile:prepend() {
    export RUST_FONTCONFIG_DLOPEN=on
    oe_cargo_fix_env
    export RUSTFLAGS="${RUSTFLAGS}"
    export RUST_TARGET_PATH="${RUST_TARGET_PATH}"
}

do_install() {
    # Cargo will rebuild if some environment variables changed. To avoid going through the steps of checking
    # all variables and re-instating them here, let's go straight for the install step:
    DESTDIR="${D}" cmake -P ${B}/cmake_install.cmake

    # Slint is not installing proper versioned .so files/symlinks yet, do it by hand:
    mv ${D}/usr/lib/libslint_cpp.so ${D}/usr/lib/libslint_cpp.so.0.1.0
    ln -s libslint_cpp.so.0.1.0 ${D}/usr/lib/libslint_cpp.so.0.1
    ln -s libslint_cpp.so.0.1.0 ${D}/usr/lib/libslint_cpp.so

    # Set permision without run flag so that it doesn't fail on checks
    chmod 644 ${D}/usr/bin/slint-compiler
}

EXTRA_OECMAKE:append:aarch64 = " -DRust_CARGO_TARGET=aarch64-poky-linux"

EXTRA_OECMAKE:append = " -DFETCHCONTENT_FULLY_DISCONNECTED=OFF"
EXTRA_OECMAKE:append = " -DBUILD_TESTING=OFF -DSLINT_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo"
EXTRA_OECMAKE:append = " -DCMAKE_DISABLE_FIND_PACKAGE_Qt5=true -DSLINT_FEATURE_BACKEND_QT=OFF"
EXTRA_OECMAKE:append = " -DSLINT_FEATURE_BACKEND_WINIT=OFF -DSLINT_FEATURE_BACKEND_WINIT_WAYLAND=ON"
EXTRA_OECMAKE:append = " -DSLINT_FEATURE_RENDERER_WINIT_FEMTOVG=OFF -DSLINT_FEATURE_RENDERER_WINIT_SKIA=ON"

# Emulate what clang-environment.inc does.

export TARGET_CLANGCC_ARCH = "${TARGET_CC_ARCH}"
TARGET_CLANGCC_ARCH:remove = "-mthumb-interwork"
TARGET_CLANGCC_ARCH:remove = "-mmusl"
TARGET_CLANGCC_ARCH:remove = "-muclibc"
TARGET_CLANGCC_ARCH:remove = "-meb"
TARGET_CLANGCC_ARCH:remove = "-mel"
TARGET_CLANGCC_ARCH:append = "${@bb.utils.contains("TUNE_FEATURES", "bigendian", " -mbig-endian", " -mlittle-endian", d)}"
TARGET_CLANGCC_ARCH:remove:powerpc = "-mhard-float"
TARGET_CLANGCC_ARCH:remove:powerpc = "-mno-spe"

# Add -I=/usr/include/freetype2 as skia has hardcoded it to -I/usr/include/freetype2, which
# would locate freetype in the host system, not the sysroot target.
export CLANGCC="${TARGET_PREFIX}clang --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCXX="${TARGET_PREFIX}clang++ --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCPP="${TARGET_PREFIX}clang -E --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANG_TIDY_EXE="${TARGET_PREFIX}clang-tidy"
export SDKTARGETSYSROOT="${PKG_CONFIG_SYSROOT_DIR}"