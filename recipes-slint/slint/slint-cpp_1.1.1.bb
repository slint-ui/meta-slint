require recipes-slint/slint/slint-cpp.inc

SRC_URI += "file://0001-WIP-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=de1f7e3f6c26ccc1b87ed67735db968f"

# v1.1.1 tag
SLINT_REV = "cbc6cfed5bc59e0d00300092b19a928ef098599f"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
