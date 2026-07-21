require pseudo.inc

# This recipe only exists to backport the pseudo openat2 fix (pseudo 1.9.8) onto
# the NXP i.MX scarthgap BSP, which pins pseudo 1.9.0 and breaks do_package on
# newer host kernels. The Raspberry Pi build uses a newer OpenEmbedded (wrynose),
# whose own oe-core pseudo already carries that fix -- and there this override is
# both redundant and fatal: the "S = ${WORKDIR}/git" below is a hard error on
# newer bitbake (bitbake.conf sets S itself). So restrict it to scarthgap;
# elsewhere defer to oe-core's pseudo.
python () {
    if 'scarthgap' not in (d.getVar('LAYERSERIES_CORENAMES') or '').split():
        raise bb.parse.SkipRecipe(
            'pseudo override only needed on the scarthgap i.MX BSP; '
            'oe-core pseudo already has the openat2 fix on this release')
}

SRC_URI = "git://git.yoctoproject.org/pseudo;branch=master;protocol=https \
           file://fallback-passwd \
           file://fallback-group \
           "
SRC_URI:append:class-native = " \
    http://downloads.yoctoproject.org/mirror/sources/pseudo-prebuilt-2.33.tar.xz;subdir=git/prebuilt;name=prebuilt \
    file://older-glibc-symbols.patch"
SRC_URI:append:class-nativesdk = " \
    http://downloads.yoctoproject.org/mirror/sources/pseudo-prebuilt-2.33.tar.xz;subdir=git/prebuilt;name=prebuilt \
    file://older-glibc-symbols.patch"
SRC_URI[prebuilt.sha256sum] = "ed9f456856e9d86359f169f46a70ad7be4190d6040282b84c8d97b99072485aa"

SRCREV = "823895ba708c63f6ae4dcbfc266210f26c02c698"
S = "${WORKDIR}/git"
PV = "1.9.8"

# largefile and 64bit time_t support adds these macros via compiler flags globally
# remove them for pseudo since pseudo intercepts some of the functions which will be
# aliased due to this e.g. open/open64 and it will complain about duplicate definitions
# pseudo on 32bit systems is not much of use anyway and these features are not of much
# use for it.
TARGET_CC_ARCH:remove = "-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_TIME_BITS=64"

# error: use of undeclared identifier '_STAT_VER'
COMPATIBLE_HOST:libc-musl = 'null'
