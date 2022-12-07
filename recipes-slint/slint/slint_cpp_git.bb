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

DEPENDS = "fontconfig libxcb wayland"

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;rev=v0.3.2"
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

EXTRA_OECMAKE:append:aarch64 = "-DRust_CARGO_TARGET=aarch64-poky-linux"

EXTRA_OECMAKE:append += "-DFETCHCONTENT_FULLY_DISCONNECTED=OFF"
EXTRA_OECMAKE:append += "-DBUILD_TESTING=OFF -DSLINT_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo"
EXTRA_OECMAKE:append += "-DCMAKE_DISABLE_FIND_PACKAGE_Qt5=true -DSLINT_FEATURE_BACKEND_QT=OFF"
EXTRA_OECMAKE:append += "-DSLINT_FEATURE_BACKEND_WINIT=OFF -DSLINT_FEATURE_BACKEND_WINIT_WAYLAND=ON"
EXTRA_OECMAKE:append += "-DSLINT_FEATURE_RENDERER_WINIT_FEMTOVG=ON"

