inherit cargo
inherit rust

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
inherit pkgconfig
inherit slint_common

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxkbcommon virtual/libgl"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH}"

SLINT_REV ?= "master"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=${SLINT_REV}"

DEPENDS:append:class-target = " ${PN}-native"
EXTRA_OECMAKE:append:class-target = " -DSLINT_COMPILER=\$ENV{OECORE_NATIVE_SYSROOT}/usr/bin/slint-compiler"

PACKAGECONFIG:append:class-native = "slint-compiler"
PACKAGECONFIG:append:class-target = " \
    slint-runtime renderer-skia interpreter \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'backend-winit-wayland', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'backend-winit-x11', '', d)} \
"

PACKAGECONFIG[slint-compiler] = "-DSLINT_FEATURE_COMPILER=ON, -DSLINT_FEATURE_COMPILER=OFF,"
PACKAGECONFIG[slint-runtime] = "-DSLINT_BUILD_RUNTIME=ON, -DSLINT_BUILD_RUNTIME=OFF,"
PACKAGECONFIG[backend-linuxkms] = "-DSLINT_FEATURE_BACKEND_LINUXKMS=ON, -DSLINT_FEATURE_BACKEND_LINUXKMS=OFF,libdrm virtual/egl virtual/libgbm seatd udev libinput"
PACKAGECONFIG[renderer-skia] = "-DSLINT_FEATURE_RENDERER_SKIA=ON, -DSLINT_FEATURE_RENDERER_SKIA=OFF,"
PACKAGECONFIG[renderer-femtovg] = "-DSLINT_FEATURE_RENDERER_FEMTOVG=ON, -DSLINT_FEATURE_RENDERER_FEMTOVG=OFF,"
PACKAGECONFIG[interpreter] = "-DSLINT_FEATURE_INTERPRETER=ON, -DSLINT_FEATURE_INTERPRETER=OFF,"
PACKAGECONFIG[backend-winit-wayland] = "-DSLINT_FEATURE_BACKEND_WINIT_WAYLAND=ON, -DSLINT_FEATURE_BACKEND_WINIT_WAYLAND=OFF,wayland"
PACKAGECONFIG[backend-winit-x11] = "-DSLINT_FEATURE_BACKEND_WINIT_X11=ON, -DSLINT_FEATURE_BACKEND_WINIT_X11=OFF,libxcb"

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
}

# Sadly, we don't install proper shared object files with DT_SONAME, etc. yet. For the time being,
# accept that we just install libslint_cpp.so and that's it.
FILES_SOLIBSDEV = ""
FILES:${PN} += "/usr/lib/libslint_cpp.so"

# Usually OE_CMAKE_C_COMPILER is just say `arm-poky-linux-gcc`, but we need the original `${CC}` that includes
# options like -mfloat-abi. This is taken into use when compiling Rust Skia's bindings.cpp (the manual part),
# where OECMAKE_CXX_COMPILER becomes CMAKE_CXX_COMPILER, and Corrison turns it into CXX_<triplet>.
OECMAKE_C_COMPILER = "${RUST_TARGET_CC}"
OECMAKE_CXX_COMPILER = "${RUST_TARGET_CXX}"

def extract_rust_target(d):
    import re
    commandline = d.getVar('RUSTC_ARCHFLAGS')
    return re.search('--target=(?P<rusttriplet>[^\s]+)', commandline).group('rusttriplet')

EXTRA_OECMAKE:append = " -DRust_CARGO_TARGET=${@extract_rust_target(d)}"

EXTRA_OECMAKE:append = " -DFETCHCONTENT_FULLY_DISCONNECTED=OFF"
EXTRA_OECMAKE:append = " -DBUILD_TESTING=OFF -DSLINT_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo"
EXTRA_OECMAKE:append = " -DCMAKE_DISABLE_FIND_PACKAGE_Qt5=true -DSLINT_FEATURE_BACKEND_QT=OFF"
EXTRA_OECMAKE:append = " -DSLINT_FEATURE_BACKEND_WINIT=OFF"

BBCLASSEXTEND = "native"
