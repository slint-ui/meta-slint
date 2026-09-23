# The build environment for compiling Slint's Skia renderer (the skia-bindings
# crate) with bitbake: Skia is built from source with clang, GN and ninja, and
# bindgen runs clang over the Skia headers. Inherited through slint_rust by Rust
# applications and through slint_common by slint-cpp.

TARGET_CFLAGS:remove = "-fcanon-prefix-map"

# The layer collection that provides clang-cross, which Skia needs. Set it to
# the collection of another layer that provides clang, or to "" to disable the
# check.
SLINT_CLANG_LAYER ??= "clang-layer"

# Skip the recipe with a readable reason when Skia is requested but no clang
# layer is present -- instead of "Nothing PROVIDES clang-cross-..." or a
# bindgen failure deep in do_compile.
def slint_require_clang_layer(d, what):
    if d.getVar('CLASSOVERRIDE') != 'class-target':
        return
    layer = d.getVar('SLINT_CLANG_LAYER')
    if layer and layer not in (d.getVar('BBFILE_COLLECTIONS') or '').split():
        raise bb.parse.SkipRecipe("%s requires clang: add the meta-clang layer "
                                  "(https://github.com/kraj/meta-clang)" % what)

# The Skia renderer builds Skia from source with GN + ninja (skia-bindings), and
# not every BSP provides ninja-native (OpenSTLinux doesn't), so depend on it.
DEPENDS:append:class-target = " ninja-native"

# oe-core's rust classes remap ${WORKDIR} out of the debug paths rustc bakes in
# (rust-common's RUST_DEBUG_REMAP); meta-rust-bin's cargo_bin does not, so the
# absolute ${WORKDIR}/sources/cargo_home crate paths end up in the binaries and
# trip the buildpaths QA check. Apply the same remap rustc-side.
RUSTFLAGS += "--remap-path-prefix=${WORKDIR}=${TARGET_DBGSRC_DIR}"

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
export CLANGCC = "${TARGET_PREFIX}clang --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCXX = "${TARGET_PREFIX}clang++ --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANGCPP = "${TARGET_PREFIX}clang -E --target=${TARGET_SYS} ${TARGET_CLANGCC_ARCH} --sysroot=${STAGING_DIR_TARGET}  -I=/usr/include/freetype2"
export CLANG_TIDY_EXE = "${TARGET_PREFIX}clang-tidy"
export SDKTARGETSYSROOT = "${PKG_CONFIG_SYSROOT_DIR}"

# Forward proxy settings into task shells so Cargo build scripts can reach external hosts.
export http_proxy
export https_proxy
export HTTP_PROXY
export HTTPS_PROXY
