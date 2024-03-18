SUMMARY = "Framework sample Slint components with linuxkms backend"
LICENSE = "GPLv3 | Slint-Commercial"

inherit packagegroup features_check

CONFLICT_DISTRO_FEATURES = "x11 wayland"

RDEPENDS:${PN} = "\
    liberation-fonts          \
    slint-demos               \
    "
