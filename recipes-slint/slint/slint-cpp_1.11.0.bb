require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-11-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=47db5060638acc88cba176445dbd98b6"

# v1.11.0 tag
SLINT_REV = "b77d013eb9642396c66c7e39897415043514d08c"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"

