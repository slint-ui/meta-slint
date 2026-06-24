require recipes-slint/slint/slint-cpp-v2.inc

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=1fa63388f53bdc8a49fc4eef67b55c87"

# v1.17.0 tag
SLINT_REV = "fdde7a535305d2ab2d4072dee637bad186a49723"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases.
# NOTE: appended after the SRC_URI assignment above, otherwise the patch is dropped.
SRC_URI += "file://0001-WIP-v-1-17-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
