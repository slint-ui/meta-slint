require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-6-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=fce682d891cef27e78643d58a1c80149"

# v1.6.0 tag
SLINT_REV = "644e15dee19fb1a72975c81e62892b9251a1111a"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

