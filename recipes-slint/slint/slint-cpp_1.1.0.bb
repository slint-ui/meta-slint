require recipes-slint/slint/slint-cpp-v1.inc

SRC_URI += "file://0001-WIP-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=4f9282cc0add078ee5638e65bb55c77c"

# v1.1.0 tag
SLINT_REV = "9b590368167f7cf3058a48317e5cf1d9798fc184"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
