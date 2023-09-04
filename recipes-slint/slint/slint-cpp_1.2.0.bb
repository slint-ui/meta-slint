require recipes-slint/slint/slint-cpp.inc

# Either REMOVE or REPLACE this patch, but never change it, as it's also referenced
# from 1.2.0 release
SRC_URI += "file://0001-WIP-v1-2-0-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"

LIC_FILES_CHKSUM = "file://LICENSE.md;md5=de1f7e3f6c26ccc1b87ed67735db968f"

# v1.2.0 tag
SLINT_REV = "c5135ab46c464fb9e7b1f1ec518b9d247c770c9b"

EXTRA_OECMAKE:append = " -DSLINT_FEATURE_GETTEXT=ON"
