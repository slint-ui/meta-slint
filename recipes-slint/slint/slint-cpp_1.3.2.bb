require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-3-2-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=c12ffea0eacb376c3ba8c0601fe78d5d"

# v1.3.2 tag
SLINT_REV = "768084b68e18c8d5320eb78b756e33a1f8e136ad"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

