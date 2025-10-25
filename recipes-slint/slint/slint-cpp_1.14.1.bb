require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-14-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=e3e11de4e6652abe8c9b2d74b416f33b"

# v1.14.1 tag
SLINT_REV = "ce50ea806a9a1d512d30acab6f99c8a1d511505f"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
