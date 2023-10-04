inherit cargo

SUMMARY = "Slint C++ UI Toolkit"
DESCRIPTION = "Slint is a toolkit to efficiently develop fluid graphical \
user interfaces for any display: embedded devices and desktop applications. \
We support multiple programming languages, such as Rust, C++, and JavaScript. \
This recipe is the C++/CMake package of Slint. For Rust application, use the slint \
crate from crates.io."
HOMEPAGE = "https://github.com/slint-ui/slint"
BUGTRACKER = "https://github.com/slint-ui/slint/issues"

LICENSE = "GPLv3 | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=a71019dc9c240d7add35e9d036870929"

inherit cmake
inherit slint_common

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxcb wayland virtual/libgl"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH}"

SLINT_REV ?= "master"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=${SLINT_REV}"


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

do_install() {
    # Cargo will rebuild if some environment variables changed. To avoid going through the steps of checking
    # all variables and re-instating them here, let's go straight for the install step:
    DESTDIR="${D}" cmake -P ${B}/cmake_install.cmake

    # Slint is not installing proper versioned .so files/symlinks yet, do it by hand:
    mv ${D}/usr/lib/libslint_cpp.so ${D}/usr/lib/libslint_cpp.so.1.0.0
    ln -s libslint_cpp.so.1.0.0 ${D}/usr/lib/libslint_cpp.so.1.0
    ln -s libslint_cpp.so.1.0.0 ${D}/usr/lib/libslint_cpp.so

    # Set permision without run flag so that it doesn't fail on checks
    chmod 644 ${D}/usr/bin/slint-compiler
}

# Usually OE_CMAKE_C_COMPILER is just say `arm-poky-linux-gcc`, but we need the original `${CC}` that includes
# options like -mfloat-abi. This is taken into use when compiling Rust Skia's bindings.cpp (the manual part),
# where OECMAKE_CXX_COMPILER becomes CMAKE_CXX_COMPILER, and Corrison turns it into CXX_<triplet>.
OECMAKE_C_COMPILER = "${RUST_TARGET_CC}"
OECMAKE_CXX_COMPILER = "${RUST_TARGET_CXX}"

EXTRA_OECMAKE:append = " -DRust_CARGO_TARGET=${HOST_SYS}"

EXTRA_OECMAKE:append = " -DFETCHCONTENT_FULLY_DISCONNECTED=OFF"
EXTRA_OECMAKE:append = " -DBUILD_TESTING=OFF -DSLINT_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo"
EXTRA_OECMAKE:append = " -DCMAKE_DISABLE_FIND_PACKAGE_Qt5=true -DSLINT_FEATURE_BACKEND_QT=OFF"
EXTRA_OECMAKE:append = " -DSLINT_FEATURE_BACKEND_WINIT=OFF -DSLINT_FEATURE_BACKEND_WINIT_WAYLAND=ON"
EXTRA_OECMAKE:append = " -DSLINT_FEATURE_RENDERER_WINIT_FEMTOVG=OFF -DSLINT_FEATURE_RENDERER_WINIT_SKIA=ON"

