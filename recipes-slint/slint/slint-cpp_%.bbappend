#TODO Remove when fixed
#slint-git-r0 do_package_qa: QA Issue: File /usr/lib/libslint_cpp.so.0.1.0·
#in package slint doesn't have GNU_HASH (didn't pass LDFLAGS?) [ldflags]
INSANE_SKIP:${PN} = "ldflags"

# Slint generates a compiler during the target generation step
# separate this to the -native-bin package, and skip the ARCH checks
# also in the image file for stations_sdk move the app to right dir and add execute flag
PACKAGES:prepend = "${PN}-native-bin "
PROVIDES:prepend = "${PN}-native-bin "
INSANE_SKIP:${PN}-native-bin = "arch"
FILES:${PN}-native-bin = "/usr/bin/slint-compiler"

RPROVIDES:${PN} += " libslint_cpp.so.1.0()(64bit)"

SYSROOT_DIRS += "/"