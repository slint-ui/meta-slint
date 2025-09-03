require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-13-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=47db5060638acc88cba176445dbd98b6"

# v1.13.0 tag
SLINT_REV = "9b0b620b4473c6d59c86cfaf6068f9cd19d50a0f"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

