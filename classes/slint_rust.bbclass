# Build a Rust application that uses Slint, via meta-rust-bin's cargo_bin.
#
# In the application's recipe:
#
#     inherit slint_rust
#     SLINT_RENDERERS = "skia"
#     SLINT_BACKENDS = "linuxkms"
#
# The class turns the renderer and backend selection into build dependencies,
# required DISTRO_FEATURES and cargo features, sets up the environment the Skia
# renderer needs to build (see slint_skia), and applies the cargo settings that
# every Slint application here needs.
#
# SLINT_RENDERERS: skia, skia-opengl, skia-vulkan, femtovg, software
# SLINT_BACKENDS:  linuxkms, linuxkms-noseat, winit, winit-wayland, winit-x11
#
# Each entry enables the Slint cargo feature of the same name (renderer-<name>,
# backend-<name>), prefixed with SLINT_CARGO_FEATURE_PREFIX. The default,
# "slint/", addresses the slint crate directly, which works when slint is a
# direct dependency of the package cargo builds. Set it to "" when the
# application exposes same-named features of its own that forward to slint, or
# set SLINT_CARGO_FEATURES = "" to select the features in CARGO_FEATURES
# yourself.
#
# The crate's default features stay enabled unless the application disables
# them, so a plain `slint = "1"` dependency also builds the winit backend and
# the FemtoVG renderer. The x11 and wayland libraries are therefore added
# whenever DISTRO_FEATURES has them, whichever backends are selected.
#
# This class does not set S: when fetching from git on releases before
# whinlatter, set S = "${WORKDIR}/git" as usual.

inherit cargo_bin
inherit pkgconfig
inherit features_check
inherit slint_skia

SLINT_RENDERERS ??= "skia"
SLINT_BACKENDS ??= "linuxkms"
SLINT_CARGO_FEATURE_PREFIX ??= "slint/"

SLINT_GL_DEPENDS = "virtual/libgles2 virtual/egl"
# clang-cross builds Skia and runs bindgen; curl-native fetches Skia's sources.
SLINT_SKIA_DEPENDS = "clang-cross-${TARGET_ARCH} curl-native ${SLINT_GL_DEPENDS}"
SLINT_KMS_DEPENDS = "libdrm virtual/libgbm virtual/egl udev libinput"

# name: (cargo feature, DEPENDS, REQUIRED_DISTRO_FEATURES)
def slint_rust_options(d):
    return {
        'SLINT_RENDERERS': {
            'skia': ('renderer-skia', '${SLINT_SKIA_DEPENDS}', 'opengl'),
            'skia-opengl': ('renderer-skia-opengl', '${SLINT_SKIA_DEPENDS}', 'opengl'),
            'skia-vulkan': ('renderer-skia-vulkan', '${SLINT_SKIA_DEPENDS} vulkan-loader', 'opengl vulkan'),
            'femtovg': ('renderer-femtovg', '${SLINT_GL_DEPENDS}', 'opengl'),
            'software': ('renderer-software', '', ''),
        },
        'SLINT_BACKENDS': {
            'linuxkms': ('backend-linuxkms', '${SLINT_KMS_DEPENDS} seatd', ''),
            'linuxkms-noseat': ('backend-linuxkms-noseat', '${SLINT_KMS_DEPENDS}', ''),
            'winit': ('backend-winit', '', ''),
            'winit-wayland': ('backend-winit-wayland', 'wayland', 'wayland'),
            'winit-x11': ('backend-winit-x11', 'libxcb', 'x11'),
        },
    }

# The cargo features (index 0), DEPENDS (1) or REQUIRED_DISTRO_FEATURES (2) of
# the selected renderers and backends.
def slint_rust_selected(d, index):
    options = slint_rust_options(d)
    selection = (
        ('SLINT_RENDERERS', d.getVar('SLINT_RENDERERS')),
        ('SLINT_BACKENDS', d.getVar('SLINT_BACKENDS')),
    )
    result = []
    for var, value in selection:
        for name in (value or '').split():
            if name not in options[var]:
                bb.fatal("%s: unknown entry '%s', expected one of: %s"
                         % (var, name, ' '.join(options[var])))
            result.append(options[var][name][index])
    return d.expand(' '.join(result))

SLINT_CARGO_FEATURES ??= "${@' '.join(d.getVar('SLINT_CARGO_FEATURE_PREFIX') + f for f in slint_rust_selected(d, 0).split())}"
CARGO_FEATURES:append = " ${SLINT_CARGO_FEATURES}"

DEPENDS:append:class-target = " ${@slint_rust_selected(d, 1)}"
DEPENDS:append:class-target = " fontconfig libxkbcommon ca-certificates-native"
DEPENDS:append:class-target = " \
    ${@bb.utils.contains('DISTRO_FEATURES', 'x11', 'libxcb', '', d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'wayland', 'wayland', '', d)} \
"
# Set for every variant, so that features_check doesn't warn it's unused in the
# native one.
REQUIRED_DISTRO_FEATURES ??= ""
REQUIRED_DISTRO_FEATURES:append:class-target = " ${@slint_rust_selected(d, 2)}"
RDEPENDS:${PN}:class-target += "xkeyboard-config"

python () {
    renderers = (d.getVar('SLINT_RENDERERS') or '').split()
    if any(r.startswith('skia') for r in renderers):
        slint_require_clang_layer(d, "The Skia renderer (SLINT_RENDERERS)")
}

# cargo fetches the crates, and skia-bindings the Skia sources, while building.
do_configure[network] = "1"
do_compile[network] = "1"

do_compile:prepend() {
    CURL_CA_BUNDLE=${STAGING_DIR_NATIVE}/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE
    # Skia + LTO is very RAM-hungry; keep LTO off.
    export CARGO_PROFILE_RELEASE_LTO=false
}

do_install:append() {
    # cargo_bin_do_install ships every .so/.rlib that the build left next to the
    # binaries, such as the cdylib targets of dependencies. The application
    # package should carry just its executables.
    rm -f ${D}${libdir}/*.so ${D}${libdir}/*.rlib
    if [ -d ${D}${libdir} ]; then
        rmdir --ignore-fail-on-non-empty ${D}${libdir}
    fi
}
