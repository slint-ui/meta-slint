
REQUIRED_DISTRO_FEATURES:append:class-target = "opengl"

DEPENDS:append:class-target = " fontconfig libxcb wayland virtual/libgl"
DEPENDS:append:class-target = " clang-cross-${TARGET_ARCH}"

do_compile:prepend() {
    export RUST_FONTCONFIG_DLOPEN=on
    oe_cargo_fix_env
    export RUSTFLAGS="${RUSTFLAGS}"
    export RUST_TARGET_PATH="${RUST_TARGET_PATH}"
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

# Add -I=/usr/include/freetype2 as skia has hardcoded it to -I/usr/include/freetype2, which
# would locate freetype in the host system, not the sysroot target.
export CLANGCC="${TARGET_PREFIX}clang --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCXX="${TARGET_PREFIX}clang++ --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCPP="${TARGET_PREFIX}clang -E --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANG_TIDY_EXE="${TARGET_PREFIX}clang-tidy"
export SDKTARGETSYSROOT="${PKG_CONFIG_SYSROOT_DIR}"
