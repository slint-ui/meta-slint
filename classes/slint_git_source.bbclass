# Point S at the git checkout, for the releases that do not do it themselves.
#
# Up to and including walnascar, bitbake.conf defaults S to ${WORKDIR}/${BP} --
# a directory no git fetch ever populates. The checkout lands in ${UNPACKDIR}/git
# (which is ${WORKDIR}/git before walnascar moved UNPACKDIR beneath the workdir),
# and base.bbclass only relocates it to ${WORKDIR}/<dir> when S actually names
# that directory. Without this, every recipe here fails at do_populate_lic with
# "LIC_FILES_CHKSUM points to an invalid file".
#
# From whinlatter on, bitbake sets S itself and hard-errors on an explicit
# assignment. So exclude those releases rather than listing the ones that need
# the assignment: that is every other release in LAYERSERIES_COMPAT, and the
# set of releases that set S themselves is the one that stops growing.
#
# Inherited by slint_common and by the recipes that do not use it, so the next
# release only has to be handled in one place.

SLINT_S_IS_SET_BY_BITBAKE = "whinlatter wrynose"

python () {
    releases = set((d.getVar('LAYERSERIES_CORENAMES') or '').split())
    handled = set((d.getVar('SLINT_S_IS_SET_BY_BITBAKE') or '').split())
    if not releases & handled:
        d.setVar('S', '${WORKDIR}/git')
}
