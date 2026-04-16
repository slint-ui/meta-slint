require recipes-slint/slint/slint-cpp-v2.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases
SRC_URI += "file://0001-WIP-v-1-14-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=093007ec281bbdeea447b0040b01a74d"

# v1.16.0 tag
SLINT_REV = "443908daeed77db500781670448d3688e4be0b9a"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
