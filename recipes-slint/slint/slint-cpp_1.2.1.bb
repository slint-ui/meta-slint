require recipes-slint/slint/slint-cpp-v1.inc

SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1.2;rev=${SLINT_REV}"

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases.
SRC_URI += "file://0001-WIP-v1-2-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=c12ffea0eacb376c3ba8c0601fe78d5d"

# v1.2.1 tag
SLINT_REV = "dee1025e83c1e66e31fb192e0550d1c1c3f13012"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
