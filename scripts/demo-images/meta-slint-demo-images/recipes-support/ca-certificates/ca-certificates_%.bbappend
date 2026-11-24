# Distrust the roots behind the compromised eMudhra (emSign) intermediate
# CAs, as Debian 20260816+nmu1 and OE-core c5098a7 do. The vendor manifests
# the demo images build with pin OE-core revisions that predate that fix.
#
# The patch adds the two labels at the top of mozilla/blacklist.txt without
# any context lines, so it applies to every recipe version the build scripts
# use (kirkstone through wrynose). On an OE-core that already has the fix the
# labels end up listed twice, which certdata2pem.py doesn't mind.
#
# Like upstream, this drops "Comodo AAA Services root" entirely, for the
# image as well as for ca-certificates-native (the CURL_CA_BUNDLE of the
# Slint recipes): a server whose chain only ends at that root, rather than
# at a current Sectigo root, fails verification.
#
# Remove once all demo-image manifests include the OE-core backport.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-Distrust-the-compromised-eMudhra-roots.patch"
