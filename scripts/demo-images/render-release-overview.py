#!/usr/bin/env python3
"""Render the overview page for the demo-images GitHub release.

Reads the board metadata (boards.json) and the release's asset list, and writes
markdown with one table per vendor. Assets are matched to boards by the
"<device>-" filename prefix; a board with no published asset is skipped, and any
asset that matches no board is listed under "Other" so nothing goes missing.

Usage:
    gh api repos/OWNER/REPO/releases/tags/demo-images \\
      | python3 render-release-overview.py > notes.md

The asset list is read from stdin as the release JSON (an object with "assets")
or as a bare JSON array of assets, so it can also be fed from a file for testing.
"""

import json
import sys
from datetime import datetime
from pathlib import Path

HEADER = """Prebuilt Slint demo images for supported boards. Each image boots straight into
the Slint demo launcher on the board's display (KMS/DRM, no desktop or
compositor). Assets are replaced by CI on each build.
"""

FOOTER = """
---

Built from [meta-slint](https://github.com/slint-ui/meta-slint) with the
`Demo Images` workflow. This page is generated -- see
`scripts/demo-images/render-release-overview.py`.
"""


def human_size(num_bytes):
    """Render a byte count the way a release page would (MB/GB, 1 decimal)."""
    mb = num_bytes / (1000 * 1000)
    if mb >= 1000:
        return f"{mb / 1000:.1f} GB"
    return f"{mb:.0f} MB"


def asset_date(asset):
    stamp = asset.get("updated_at") or asset.get("created_at") or ""
    try:
        return datetime.strptime(stamp[:10], "%Y-%m-%d").strftime("%Y-%m-%d")
    except ValueError:
        return ""


def pick_asset(assets, device):
    """The asset published for a device, matched by the '<device>-' prefix.

    Longest match wins so a device id that is a prefix of another one can't
    steal its asset.
    """
    matches = [a for a in assets if a["name"].startswith(device + "-")]
    if not matches:
        return None
    return max(matches, key=lambda a: len(a["name"]))


def main():
    here = Path(__file__).resolve().parent
    meta = json.loads((here / "boards.json").read_text())

    raw = json.load(sys.stdin)
    assets = raw["assets"] if isinstance(raw, dict) else raw
    assets = [a for a in assets if a.get("state", "uploaded") == "uploaded"]

    out = [HEADER]
    claimed = set()

    for vendor in meta["vendors"]:
        rows = []
        for board in vendor["boards"]:
            asset = pick_asset(assets, board["device"])
            if asset is None:
                continue  # board not published (yet)
            claimed.add(asset["name"])
            rows.append(
                "| {name} | {soc} | {gpu} | [{file}]({url}) | {size} | {date} |".format(
                    name=board["name"],
                    soc=board.get("soc", ""),
                    gpu=board.get("gpu", ""),
                    file=asset["name"],
                    url=asset["browser_download_url"],
                    size=human_size(asset["size"]),
                    date=asset_date(asset),
                )
            )
        if not rows:
            continue
        out.append(f"## {vendor['name']}\n")
        if vendor.get("flashing"):
            out.append(vendor["flashing"] + "\n")
        out.append("| Board | SoC | GPU | Download | Size | Updated |")
        out.append("| --- | --- | --- | --- | --- | --- |")
        out.extend(rows)
        out.append("")

    leftovers = [a for a in assets if a["name"] not in claimed]
    if leftovers:
        out.append("## Other\n")
        out.append("| Download | Size | Updated |")
        out.append("| --- | --- | --- |")
        for a in sorted(leftovers, key=lambda a: a["name"]):
            out.append(
                f"| [{a['name']}]({a['browser_download_url']}) "
                f"| {human_size(a['size'])} | {asset_date(a)} |"
            )
        out.append("")

    out.append(FOOTER)
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
