require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-6-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=eebec9101f22e9d1977ba3352a1c24c0"

# v1.7.2 tag
SLINT_REV = "3f8163fa3f0d5cef08d9e734711aef9b45284eaa"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

