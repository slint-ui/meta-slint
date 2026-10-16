DESCRIPTION = "An image that includes Slint demos machine."

LICENSE = "MIT"

inherit core-image

# On-target profiling and debugging: tools-debug brings gdb, gdbserver and
# strace. The profiling tools are listed instead of using tools-profile, which
# pulls in lttng-modules, LTTng's out-of-tree kernel tracer -- it doesn't build
# against every vendor kernel (2.13.12 fails on Toradex's 6.6), and lttng-tools
# would bring it back as a recommendation (still built), so leave LTTng out.
IMAGE_FEATURES += "tools-debug"
CORE_IMAGE_EXTRA_INSTALL += "perf powertop systemtap blktrace"

# Python with the full standard library, so the packages installed with uv
# (which the demo-image builds add) find the modules they expect.
CORE_IMAGE_EXTRA_INSTALL += "python3 python3-modules"

CORE_IMAGE_EXTRA_INSTALL += " \
    packagegroup-fsl-tools-gpu \
    packagegroup-fsl-gstreamer1.0 \
    packagegroup-imx-tools-audio \
    slint-launcher \
    slint-viewer \
    liberation-fonts \
"

