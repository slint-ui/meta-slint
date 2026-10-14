SUMMARY = "A very basic image with Slint demos running via KMS/DRM"

IMAGE_FEATURES += "package-management ssh-server-dropbear"

# On-target profiling and debugging: gdb and gdbserver, plus the profiling
# tools. Both are listed instead of using the image features:
#  - tools-debug also brings strace, and strace 6.7 doesn't build for the
#    RZ/G3L (its ptp.c size check of struct ptp_sys_offset fails against the
#    kernel headers), so leave strace out.
#  - tools-profile pulls in lttng-modules, LTTng's out-of-tree kernel tracer --
#    it doesn't build against every vendor kernel (2.13.12 fails on Toradex's
#    6.6), and lttng-tools would bring it back as a recommendation (still
#    built), so leave LTTng out.
CORE_IMAGE_EXTRA_INSTALL += "gdb gdbserver perf powertop systemtap blktrace"

LICENSE = "MIT"

inherit core-image

CORE_IMAGE_BASE_INSTALL += "slint-launcher slint-viewer liberation-fonts"

QB_MEM = "-m 512"

require include/rz-distro-common.inc
require include/rz-modules-common.inc
