TARGET_CFLAGS:remove = "-fcanon-prefix-map"

# The Skia renderer builds Skia from source with GN + ninja (skia-bindings), and
# not every BSP provides ninja-native (OpenSTLinux doesn't), so depend on it.
DEPENDS:append:class-target = " ninja-native"

# skia-bindings also runs bindgen, which dlopens libclang.so to generate the Rust
# bindings for Skia's headers. Provide the native libclang and point bindgen at
# it via LIBCLANG_PATH; the target headers are still parsed cross, through the
# --target/--sysroot in BINDGEN_EXTRA_CLANG_ARGS below. (meta-rust-bin used to
# make this discoverable; oe-core's cargo does not.)
DEPENDS:append:class-target = " clang-native"
export LIBCLANG_PATH = "${STAGING_LIBDIR_NATIVE}"

do_compile:prepend() {
    #export RUSTFLAGS="${RUSTFLAGS}"
    #export RUST_TARGET_PATH="${RUST_TARGET_PATH}"
    # Make sure that Skia's invocation of clang to generate bindings.rs for the Skia headers
    # passes the right flags, in particular float abi selection
    export BINDGEN_EXTRA_CLANG_ARGS="${HOST_CC_ARCH} ${TOOLCHAIN_OPTIONS} ${TARGET_CFLAGS}"
}

# The skia-bindings crate compiles its src/bindings.cpp with the cargo cc-crate
# wrapper, which embeds oe-core's DEBUG_PREFIX_MAP. That map only remaps ${S}, ${B}
# and the sysroots — NOT ${WORKDIR}/sources/cargo_home, where the skia-bindings crate
# and the bundled Skia headers live. So absolute __FILE__ paths (e.g. the bundled
# .../skia/include/codec/SkEncodedOrigin.h) get baked into libslint_cpp.so's .rodata
# and trip the buildpaths QA check. Extend the map to cover the whole ${WORKDIR} so
# those cargo_home paths are remapped too. (Skia's own gn/ninja compile already emits
# relative paths, so it isn't affected.)
DEBUG_PREFIX_MAP:append:class-target = " -ffile-prefix-map=${WORKDIR}=/usr/src/debug/${PN}/${PV}"

# The -src package (poky default PACKAGE_DEBUG_SPLIT_STYLE=debug-with-srcpkg) ships
# debug sources, including build-script-generated files. The `built` crate used by
# rav1e (pulled in via Skia's AVIF image support) writes a built.rs recording absolute
# build paths (e.g. the rustc path) as string literals — these are not in any binary
# (dead code, absent from libslint_cpp.so) but trip buildpaths QA on the source package.
# Skip buildpaths for the -src package only; the binary packages keep full QA.
INSANE_SKIP:${PN}-src += "buildpaths"

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

# Forward proxy settings into task shells so Cargo build scripts can reach external hosts.
export http_proxy
export https_proxy
export HTTP_PROXY
export HTTPS_PROXY
