SUMMARY = "Slint Hello World in Rust, built with the Skia renderer"
DESCRIPTION = "Builds the Slint Rust template application for the LinuxKMS \
backend with the Skia renderer, as an example for using the slint_rust class."
HOMEPAGE = "https://github.com/slint-ui/slint"
LICENSE = "GPL-3.0-only | Slint-Commercial"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9e911597e678943cde54111f7518e299"

SRC_URI = "git://github.com/slint-ui/slint-rust-template.git;protocol=https;branch=main;rev=main"

inherit slint_rust
inherit slint_git_source

# The template depends on the slint crate directly, so slint_rust selects
# slint/renderer-skia and slint/backend-linuxkms on top of its default features.
SLINT_RENDERERS = "skia"
SLINT_BACKENDS = "linuxkms"

PV = "slint-hello-world-rust-${SRCPV}"
