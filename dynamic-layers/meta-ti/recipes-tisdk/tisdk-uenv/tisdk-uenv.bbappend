# AM62L's CMA pool defaults to 32 MB (CONFIG_CMA_SIZE_MBYTES in TI's arm64
# defconfig; the AM62L devicetree has no linux,cma node), too small for a
# triple-buffered 2K scanout -- the demo's dumb-buffer allocation then fails.
# Enlarge it to 64 MB via the kernel command line, without a kernel rebuild:
# TI's U-Boot imports uEnv.txt (on the FAT boot partition, in IMAGE_BOOT_FILES
# via arago.conf) after bootcmd and appends ${optargs} to the kernel bootargs,
# so extend optargs with cma=64M. The arago base uEnv.txt sets no optargs, so
# U-Boot's default (vt.global_cursor_default=0) applies otherwise -- preserve
# that and add cma. (A CONFIG_CMA_SIZE_MBYTES fragment would work too but forces
# a full kernel rebuild; this is a boot-partition-only change.)
do_deploy:append:am62lxx-evm() {
    uenv=${DEPLOYDIR}/uEnv.txt
    if grep -q '^optargs=' "$uenv"; then
        sed -i '/^optargs=/ s/$/ cma=64M/' "$uenv"
    else
        printf '\n# Enlarge CMA for the triple-buffered 2K scanout (Slint demo).\noptargs=vt.global_cursor_default=0 cma=64M\n' >> "$uenv"
    fi
}
