require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-5-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=0cfef883ea34026eab43837344667cfe"

# v1.5.1 tag
SLINT_REV = "44c405bdf87042694c9fc19c8705c21ecf602ac7"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

