SUMMARY = "uv, the Python package and project manager, as a prebuilt binary"
DESCRIPTION = "Installs Astral's release build of uv and uvx into /usr/bin, to \
install Python packages and create virtual environments on the target."
HOMEPAGE = "https://github.com/astral-sh/uv"
LICENSE = "MIT | Apache-2.0"
# The release tarballs ship only the two binaries, no license files.
LIC_FILES_CHKSUM = " \
    file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
    file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10 \
"

# Prebuilt rather than built from source: uv is a workspace of hundreds of
# crates, which would add a long Rust build to every image. Astral publishes
# glibc builds for both of the architectures the demo images target.
UV_TARGET = "unsupported"
UV_TARGET:aarch64 = "aarch64-unknown-linux-gnu"
UV_TARGET:arm = "armv7-unknown-linux-gnueabihf"
COMPATIBLE_HOST = "(aarch64|arm).*-linux.*"
COMPATIBLE_HOST:libc-musl = "null"

# Unpack into ${BP} without the tarball's top-level directory, so the files end
# up in the default S on every release: under UNPACKDIR on walnascar+, and
# under WORKDIR on scarthgap, whose bitbake has no UNPACKDIR.
SRC_URI = "https://github.com/astral-sh/uv/releases/download/${PV}/uv-${UV_TARGET}.tar.gz;name=${UV_TARGET};subdir=${BP};striplevel=1"
SRC_URI[aarch64-unknown-linux-gnu.sha256sum] = "9041c73c99fdc5892cf128140beb354eca9231d502068cc36e6cb53a8e59ad14"
SRC_URI[armv7-unknown-linux-gnueabihf.sha256sum] = "833bb2b4a47ba2aa4356e577eb52be2deb15d145d79e559dfe8fcc3bf546017b"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/uv ${S}/uvx ${D}${bindir}
}

# uv fetches packages over HTTPS. It ships its own root certificates, but
# UV_NATIVE_TLS / --native-tls switches it to the system store.
RDEPENDS:${PN} += "ca-certificates"

# Built and linked by Astral, not by our toolchain: the armv7 binaries come
# stripped, and our LDFLAGS were never applied.
INSANE_SKIP:${PN} += "already-stripped ldflags"
