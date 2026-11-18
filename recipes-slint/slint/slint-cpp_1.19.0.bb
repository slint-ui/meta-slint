require recipes-slint/slint/slint-cpp-v2.inc

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=eddf02df1cb330c56cc727e9e3a379c9"

# v1.19.0 tag
SLINT_REV = "e436f546f71481d786cbc2a74316b1be1ef678c1"
SRC_URI = "git://github.com/slint-ui/slint.git;protocol=https;branch=release/1.19;rev=${SLINT_REV}"

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from other releases.
# NOTE: appended after the SRC_URI assignment above, otherwise the patch is dropped.
SRC_URI += "file://0001-WIP-v-1-19-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
