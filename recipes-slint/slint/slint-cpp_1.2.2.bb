require recipes-slint/slint/slint-cpp-v1.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases.
SRC_URI += "file://0001-WIP-v1-2-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=c12ffea0eacb376c3ba8c0601fe78d5d"

# v1.2.2 tag
SLINT_REV = "9a07e50224faa2853a7ca61f69d64530816ff1a8"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1;rev=${SLINT_REV}"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
