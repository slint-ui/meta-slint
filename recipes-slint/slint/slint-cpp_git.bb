require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from 1.1.0 release
SRC_URI += "file://0001-WIP-git-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=093007ec281bbdeea447b0040b01a74d"
SLINT_REV = "master"

PV = "git-${SRCPV}"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
