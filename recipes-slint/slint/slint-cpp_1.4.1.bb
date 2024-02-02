require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-4-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=0cfef883ea34026eab43837344667cfe"

# v1.4.1 tag
SLINT_REV = "0984170cb3e2effb2c788238bdc42c53109966fa"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

