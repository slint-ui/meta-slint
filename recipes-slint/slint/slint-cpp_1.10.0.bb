require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-6-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=47db5060638acc88cba176445dbd98b6"

# v1.10.0 tag
SLINT_REV = "b4dd273989427f56dd85c5ac4cc2970963623f63"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

