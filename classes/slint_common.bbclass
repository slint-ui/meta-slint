TARGET_CFLAGS:remove = "-fcanon-prefix-map"

# The Skia renderer builds Skia from source with GN + ninja (skia-bindings), and
# not every BSP provides ninja-native (OpenSTLinux doesn't), so depend on it.
DEPENDS:append:class-target = " ninja-native"

# S across OE releases: scarthgap's bitbake.conf does not derive S for git
# fetches, so point it at the checkout; newer OpenEmbedded (whinlatter, wrynose)
# sets S itself and hard-errors on an explicit "${WORKDIR}/git" assignment. Every
# slint_common consumer is a git-checkout recipe, so set S only on scarthgap and
# let bitbake.conf handle it elsewhere.
python () {
    if 'scarthgap' in (d.getVar('LAYERSERIES_CORENAMES') or '').split():
        d.setVar('S', '${WORKDIR}/git')
}

do_compile:prepend() {
    #export RUSTFLAGS="${RUSTFLAGS}"
    #export RUST_TARGET_PATH="${RUST_TARGET_PATH}"
    # Make sure that Skia's invocation of clang to generate bindings.rs for the Skia headers
    # passes the right flags, in particular float abi selection
    export BINDGEN_EXTRA_CLANG_ARGS="${HOST_CC_ARCH} ${TOOLCHAIN_OPTIONS} ${TARGET_CFLAGS}"
}

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
TARGET_CLANGCC_ARCH:remove = "-fcanon-prefix-map"

# Add -I=/usr/include/freetype2 as skia has hardcoded it to -I/usr/include/freetype2, which
# would locate freetype in the host system, not the sysroot target.
export CLANGCC="${TARGET_PREFIX}clang --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCXX="${TARGET_PREFIX}clang++ --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCPP="${TARGET_PREFIX}clang -E --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANG_TIDY_EXE="${TARGET_PREFIX}clang-tidy"
export SDKTARGETSYSROOT="${PKG_CONFIG_SYSROOT_DIR}"
