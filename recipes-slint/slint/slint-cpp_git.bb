require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from 1.1.0 release
SRC_URI += "file://0001-WIP-git-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=47db5060638acc88cba176445dbd98b6"
SLINT_REV = "master"

PV = "git-${SRCPV}"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

do_configure:prepend() {
    # Work around current half not cross-compiling well
    (cd ${S} && cargo update -p half --precise 2.2.1)
}
