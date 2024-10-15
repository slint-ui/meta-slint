require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-6-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
SRC_URI += "  file://0001-Fix-build-on-ARM-host-systems.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=47db5060638acc88cba176445dbd98b6"

# v1.8.0 tag
SLINT_REV = "ca66a6af4a4e9c4c78ff889ba447bcb460d07c91"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

