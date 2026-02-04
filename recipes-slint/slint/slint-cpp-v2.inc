inherit cargo_bin

SUMMARY = "Slint C++ UI Toolkit"
DESCRIPTION = "Slint is a toolkit to efficiently develop fluid graphical \
user interfaces for any display: embedded devices and desktop applications. \
We support multiple programming languages, such as Rust, C++, and JavaScript. \
This recipe is the C++/CMake package of Slint. For Rust application, use the slint \
crate from crates.io."
HOMEPAGE = "https://github.com/slint-ui/slint"
BUGTRACKER = "https://github.com/slint-ui/slint/issues"

LICENSE = "GPL-3.0-only | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=a71019dc9c240d7add35e9d036870929"

inherit cmake
inherit pkgconfig
inherit slint_common

REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append = " fontconfig"
DEPENDS:append:class-target = " libxkbcommon virtual/libgl"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

SLINT_REV ?= "master"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=master;rev=${SLINT_REV}"

DEPENDS:append:class-target = " ${PN}-native ca-certificates-native"
EXTRA_OECMAKE:append:class-target = " -DSLINT_COMPILER=/\$ENV{OECORE_NATIVE_SYSROOT}/usr/bin/slint-compiler"

PACKAGECONFIG:append:class-native = "slint-compiler"
PACKAGECONFIG:class-nativesdk = "slint-compiler"
PACKAGECONFIG:append:class-target = " \
    slint-runtime renderer-femtovg renderer-software interpreter \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'backend-winit-wayland', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'backend-winit-x11', '', d)} \
"

PACKAGECONFIG[slint-compiler] = "-DSLINT_FEATURE_COMPILER=ON, -DSLINT_FEATURE_COMPILER=OFF,"
PACKAGECONFIG[slint-runtime] = "-DSLINT_BUILD_RUNTIME=ON, -DSLINT_BUILD_RUNTIME=OFF,"
PACKAGECONFIG[backend-linuxkms] = "-DSLINT_FEATURE_BACKEND_LINUXKMS=ON, -DSLINT_FEATURE_BACKEND_LINUXKMS=OFF,libdrm virtual/egl virtual/libgbm seatd udev libinput"
PACKAGECONFIG[renderer-skia] = "-DSLINT_FEATURE_RENDERER_SKIA=ON, -DSLINT_FEATURE_RENDERER_SKIA=OFF,clang-cross-${TARGET_ARCH}"
PACKAGECONFIG[renderer-femtovg] = "-DSLINT_FEATURE_RENDERER_FEMTOVG=ON, -DSLINT_FEATURE_RENDERER_FEMTOVG=OFF,"
PACKAGECONFIG[renderer-software] = "-DSLINT_FEATURE_RENDERER_SOFTWARE=ON, -DSLINT_FEATURE_RENDERER_SOFTWARE=OFF,"
PACKAGECONFIG[interpreter] = "-DSLINT_FEATURE_INTERPRETER=ON, -DSLINT_FEATURE_INTERPRETER=OFF,"
PACKAGECONFIG[backend-winit-wayland] = "-DSLINT_FEATURE_BACKEND_WINIT_WAYLAND=ON, -DSLINT_FEATURE_BACKEND_WINIT_WAYLAND=OFF,wayland"
PACKAGECONFIG[backend-winit-x11] = "-DSLINT_FEATURE_BACKEND_WINIT_X11=ON, -DSLINT_FEATURE_BACKEND_WINIT_X11=OFF,libxcb"
PACKAGECONFIG[experimental] = "-DSLINT_FEATURE_EXPERIMENTAL=ON, -DSLINT_FEATURE_EXPERIMENTAL=OFF,"
PACKAGECONFIG[system-testing] = "-DSLINT_FEATURE_SYSTEM_TESTING=ON, -DSLINT_FEATURE_SYSTEM_TESTING=OFF,"

S = "${WORKDIR}/git"

CARGO_DISABLE_BITBAKE_VENDORING = "1"

# For FetchContent of corrosion
do_configure[network] = "1"
# For crate dependencies from crates.io
do_compile[network] = "1"

do_configure:prepend:class-nativesdk() {
    # Since Corrosion decides that the native build is not a cross-build, it won't forward CMAKE_SYSROOT.
    # The sysroot however is instrumental, so pass it along via the toolchain and the cargo compile wrappers.
    echo "set(CMAKE_C_COMPILER \"${WRAPPER_DIR}/cc-wrapper.sh\")" >> ${WORKDIR}/toolchain.cmake
    echo "set(CMAKE_CXX_COMPILER \"${WRAPPER_DIR}/cxx-wrapper.sh\")" >> ${WORKDIR}/toolchain.cmake
}

do_configure() {
    echo "set(CMAKE_SYSROOT \"${RECIPE_SYSROOT}\")" >> ${WORKDIR}/toolchain.cmake
    cargo_bin_do_configure
    cmake_do_configure
}

do_compile:prepend() {
    # Wrappers created by cargo_bin_do_configure
    export TARGET_CC="${WRAPPER_DIR}/cc-wrapper.sh"
    export TARGET_CXX="${WRAPPER_DIR}/cxx-wrapper.sh"
    export CC="${WRAPPER_DIR}/cc-native-wrapper.sh"
    export CXX="${WRAPPER_DIR}/cxx-native-wrapper.sh"
    export TARGET_LD="${WRAPPER_DIR}/linker-wrapper.sh"
    export LD="${WRAPPER_DIR}/linker-native-wrapper.sh"
    export PKG_CONFIG_ALLOW_CROSS="1"
    export LDFLAGS=""
    export RUSTFLAGS="${RUSTFLAGS}"
    export SSH_AUTH_SOCK="${SSH_AUTH_SOCK}"

    # This "DO_NOT_USE_THIS" option of cargo is currently the only way to
    # configure a different linker for host and target builds when RUST_BUILD ==
    # RUST_TARGET.
    export __CARGO_TEST_CHANNEL_OVERRIDE_DO_NOT_USE_THIS="nightly"
    export CARGO_UNSTABLE_TARGET_APPLIES_TO_HOST="true"
    export CARGO_UNSTABLE_HOST_CONFIG="true"
    export CARGO_TARGET_APPLIES_TO_HOST="false"
    export CARGO_TARGET_${@rust_target(d, 'TARGET').replace('-','_').upper()}_LINKER="${WRAPPER_DIR}/linker-wrapper.sh"
    export CARGO_HOST_LINKER="${WRAPPER_DIR}/linker-native-wrapper.sh"
    export CARGO_BUILD_FLAGS="-C rpath"
    export CARGO_PROFILE_RELEASE_DEBUG="true"

    # The CC crate defaults to using CFLAGS when compiling everything. We can
    # give it custom flags for compiling on the host.
    export HOST_CXXFLAGS=""
    export HOST_CFLAGS=""
}

do_compile:prepend:class-target() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
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
#OECMAKE_C_COMPILER = "${RUST_TARGET_CC}"
#OECMAKE_CXX_COMPILER = "${RUST_TARGET_CXX}"

EXTRA_OECMAKE:append = " -DRust_CARGO_TARGET=${RUST_TARGET}"

EXTRA_OECMAKE:append = " -DFETCHCONTENT_FULLY_DISCONNECTED=OFF"
EXTRA_OECMAKE:append = " -DBUILD_TESTING=OFF -DSLINT_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo"
EXTRA_OECMAKE:append = " -DCMAKE_DISABLE_FIND_PACKAGE_Qt5=true -DSLINT_FEATURE_BACKEND_QT=OFF"
EXTRA_OECMAKE:append = " -DSLINT_FEATURE_BACKEND_WINIT=OFF"

# The slint compiler for the SDK doesn't need (shared) libstd-rs
RUSTLIB_DEP:class-nativesdk = ""

BBCLASSEXTEND = "native nativesdk"
