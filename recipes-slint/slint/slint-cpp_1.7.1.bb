require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-6-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=eebec9101f22e9d1977ba3352a1c24c0"

# v1.7.1 tag
SLINT_REV = "b8c8bff2b1eb2d751c6280884bbbf92f5ef5f7c0"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

