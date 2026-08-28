require pseudo.inc

# This recipe only exists to backport the pseudo openat2 fix (pseudo 1.9.8) onto
# the releases that pin a pseudo without it. Since the tar security update for
# CVE-2025-45582, host tar resolves paths with openat2(), which pseudo 1.9.0 has
# no wrapper for -- so under fakeroot its dirfds go untracked and *every*
# do_package fails ("got *at() syscall for unknown directory").
#
# That pin is what both the i.MX scarthgap BSP and walnascar ship, so both need
# the backport. Newer OpenEmbedded (whinlatter/wrynose) carries the fix in its
# own oe-core pseudo, and there this override is not merely redundant but fatal:
# `S = "${WORKDIR}/git"` below is a hard error on that bitbake. So skip it there
# and defer to oe-core's pseudo.
PSEUDO_HAS_OPENAT2_FIX = "whinlatter wrynose"

python () {
    releases = set((d.getVar('LAYERSERIES_CORENAMES') or '').split())
    fixed = set((d.getVar('PSEUDO_HAS_OPENAT2_FIX') or '').split())
    if releases & fixed:
        raise bb.parse.SkipRecipe(
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
