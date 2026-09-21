#!/usr/bin/env python3
"""Update the meta-slint recipes to a new Slint release.

A release bump touches three recipe families plus the gettext patches two of
them carry:

  * recipes-slint/slint/slint-cpp_<version>.bb           -- added, older ones kept
  * recipes-slint/slint-viewer/slint-viewer_<version>.bb  -- moved onto the release
  * recipes-example/slint-demos/slint-demos_<version>.bb  -- moved onto the release

The patch is the interesting part. It does exactly one thing -- insert the
GETTEXT_BLOCK below into the manifest of every workspace the recipe builds from
-- so it never needs a real rebase, only new hunks once upstream's manifests
shift. Which manifests those are is resolved against the upstream tree rather
than hard-coded, because upstream moves them: 1.18 split examples/ and demos/
out of the root workspace, so from that release the slint-demos patch has to
reach examples/Cargo.toml and demos/Cargo.toml instead of the root one. This
script reuses the existing patch untouched when it still applies at exactly the
line numbers it records *and* still carries exactly that block in exactly those
manifests (which is what the 1.17.1 bump did with the 1.17.0 patch); otherwise
it writes a new 0001-WIP-v-<version>-... file. A patch that only applies at an
offset counts as stale: bitbake tolerates it, but it is one context change away
from the fuzz that trips ERROR_QA. Existing patch files are never modified --
older releases reference them by name and must keep building. They are removed,
though, when regenerating one leaves it with nothing referencing it: the moving
families carry a single recipe, so the file the renamed recipe used to name is
dead weight. slint-cpp keeps every patch, because it keeps every recipe.

Usage:
    scripts/update-slint-version.py 1.18.0
    scripts/update-slint-version.py 1.18.0 --rev pre-release/1.18 --branch pre-release/1.18
    scripts/update-slint-version.py 1.18.0 --repin-launcher
    scripts/update-slint-version.py 1.18.0 --dry-run

--summary-json, --commit-message-file and --pr-body-file write the machine
summary, the commit message and the pull request body; the workflow in
.github/workflows/update-slint-version.yml consumes all three.
"""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SLINT_URL = "https://github.com/slint-ui/slint.git"

# The whole of what the gettext patch does. A regenerated patch is defined by
# this, and a patch that inserts anything else is not reusable however cleanly
# it applies -- see reusable_patch(). The blank line that separates it from
# whatever follows is added at insertion time, not carried here, so that the
# same block can also go at the end of the file.
GETTEXT_BLOCK = (
    "[patch.crates-io]\n"
    'gettext-sys = { git = "https://github.com/slint-ui/gettext-rs", '
    'branch = "simon/fix-linux-detection" }\n'
)
# Where the block goes. Upstream carried the workspace's [profile.release] in
# Cargo.toml until 1.18, which moved it to .cargo/config.toml, so the anchor is
# optional: without it the block goes at the end of the file. Either position is
# valid TOML -- a table header ends the table before it, so nothing can fall
# into [patch.crates-io] by accident -- and either way the hunk carries three
# lines of real context.
GETTEXT_ANCHOR = "\n[profile.release]\n"

REPO = Path(__file__).resolve().parent.parent
LAUNCHER_RECIPE = REPO / "recipes-example" / "slint-launcher" / "slint-launcher_git.bb"


class Family:
    """One recipe family that pins a Slint revision.

    workspaces names the upstream directories the family builds packages from,
    "" being the repository root. A family with no workspaces carries no gettext
    patch (slint-viewer builds nothing that links gettext).

    keeps_history is slint-cpp, which carries a recipe per release so
    PREFERRED_VERSION can select an older one; the others move onto the new
    release and leave nothing behind.
    """

    def __init__(self, stem, directory, workspaces, keeps_history):
        self.stem = stem
        self.directory = directory
        self.workspaces = workspaces
        self.patch_dir = directory / stem if workspaces else None
        self.keeps_history = keeps_history

    @property
    def candidate_manifests(self):
        return [w + "/Cargo.toml" if w else "Cargo.toml" for w in self.workspaces]

    def manifests(self, workdir):
        """The manifests this family's gettext patch has to reach, at this revision.

        A [patch.crates-io] only takes effect in the manifest of the workspace
        cargo is actually building, and upstream split examples/ and demos/ into
        workspaces of their own in 1.18. Before that they were plain members of
        the root workspace with no manifest to patch, so fall back to the root
        one -- that keeps a bump working on either side of the split.
        """
        found = []
        for manifest in self.candidate_manifests:
            if not (workdir / manifest).is_file():
                manifest = "Cargo.toml"
            if manifest not in found:
                found.append(manifest)
        return found


FAMILIES = [
    Family("slint-cpp", REPO / "recipes-slint" / "slint", ("",), True),
    Family("slint-viewer", REPO / "recipes-slint" / "slint-viewer", (), False),
    # The demo binaries this recipe builds are spread over both workspaces.
    Family("slint-demos", REPO / "recipes-example" / "slint-demos", ("demos", "examples"), False),
]

# Everything any family might have to patch, so one sparse checkout covers them
# all. Missing paths are simply not checked out, which is what manifests() reads.
ALL_MANIFESTS = sorted({m for f in FAMILIES for m in f.candidate_manifests} | {"Cargo.toml"})


class Bump:
    """One family's move onto the new release.

    patch and patch_content stay None for a family with no patch, and
    patch_content stays None when the existing patch is carried forward.
    """

    def __init__(self, family, version):
        self.family = family
        self.old_version, self.recipe = newest_recipe(family)
        self.text = self.recipe.read_text()
        self.destination = family.directory / "{}_{}.bb".format(family.stem, version)
        self.previous_patch = (
            family.patch_dir / patch_reference(self.text, self.recipe)
            if family.patch_dir
            else None
        )
        self.patch = None
        self.patch_content = None

    @property
    def patch_action(self):
        return "regenerated" if self.patch_content else "reused"

    @property
    def retired_patch(self):
        """The patch file this bump orphans, if any.

        Only a regeneration orphans anything, and only for a family that moves
        its recipe: once the rename lands there is no recipe left naming the
        old file. A reuse keeps the same file, and slint-cpp keeps a recipe per
        release, each still naming the patch it was cut with.
        """
        if self.family.keeps_history or not self.patch_content:
            return None
        return self.previous_patch


class Failure(Exception):
    """A condition the script refuses to guess its way past."""


def git(args, cwd=REPO, check=True):
    result = subprocess.run(
        ["git"] + [str(a) for a in args],
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        raise Failure(
            "command failed: git {}\n{}".format(
                " ".join(str(a) for a in args), (result.stderr or "").strip()
            )
        )
    return result


# --------------------------------------------------------------------------
# Version bookkeeping
# --------------------------------------------------------------------------


def version_key(text):
    return tuple(int(part) for part in text.split("."))


def newest_recipe(family):
    """The highest-versioned <stem>_<x.y.z>.bb of a family.

    The _git.bb recipes are deliberately excluded: they track master and are not
    a template for a release recipe.
    """
    pattern = re.compile(r"^" + re.escape(family.stem) + r"_(\d+\.\d+\.\d+)\.bb$")
    found = []
    for path in family.directory.glob(family.stem + "_*.bb"):
        match = pattern.match(path.name)
        if match:
            found.append((version_key(match.group(1)), match.group(1), path))
    if not found:
        raise Failure(
            "no versioned {} recipe found in {}".format(family.stem, family.directory)
        )
    found.sort()
    return found[-1][1], found[-1][2]


def patch_reference(recipe_text, recipe_path):
    """The file://...patch the recipe pulls in via SRC_URI."""
    matches = re.findall(r'file://([^"\s]+\.patch)', recipe_text)
    if len(matches) != 1:
        raise Failure(
            "expected exactly one .patch reference in {}, found {}".format(
                recipe_path, matches
            )
        )
    return matches[0]


def patch_name_for(version):
    return (
        "0001-WIP-v-"
        + version.replace(".", "-")
        + "-Use-a-patched-gettext-to-avoid-cross-compiling-g.patch"
    )


# --------------------------------------------------------------------------
# Upstream
# --------------------------------------------------------------------------


def resolve_rev(rev, branch):
    """Resolve rev to a commit SHA, and prove branch exists, in one round trip."""
    if re.fullmatch(r"[0-9a-f]{40}", rev):
        wanted = []
    else:
        wanted = ["refs/tags/" + rev, "refs/tags/" + rev + "^{}", "refs/heads/" + rev]

    result = git(["ls-remote", SLINT_URL] + wanted + ["refs/heads/" + branch])
    resolved = {}
    for line in result.stdout.splitlines():
        if "\t" in line:
            sha, ref = line.split("\t", 1)
            resolved[ref] = sha

    if "refs/heads/" + branch not in resolved:
        raise Failure(
            "{} is not a branch in {} -- pass --branch with the branch the "
            "release lives on".format(branch, SLINT_URL)
        )
    if not wanted:
        return rev
    # An annotated tag yields both the tag object and, via ^{}, the commit it
    # points at -- always prefer the dereferenced commit.
    for ref in wanted:
        if ref in resolved:
            return resolved[ref]
    raise Failure("{} is neither a tag nor a branch in {}".format(rev, SLINT_URL))


def fetch_upstream(sha, branch, workdir, check_branch=True):
    """Materialise just the workspace manifests and LICENSE.md at sha.

    A blobless, depth-1 fetch plus a sparse checkout: a second or so and a couple
    of hundred kilobytes rather than a full clone of a repository this size. The
    shallow boundary from this first fetch is also what keeps the branch fetch
    below cheap -- it bounds the walk to the commits between sha and the branch
    head instead of the whole history.
    """
    git(["init", "--quiet", workdir], cwd=REPO)
    git(["remote", "add", "origin", SLINT_URL], cwd=workdir)
    git(["fetch", "--quiet", "--depth=1", "--filter=blob:none", "origin", sha], cwd=workdir)

    git(["sparse-checkout", "init", "--no-cone"], cwd=workdir)
    git(
        ["sparse-checkout", "set", "/LICENSE.md"] + ["/" + m for m in ALL_MANIFESTS],
        cwd=workdir,
    )
    git(["checkout", "--quiet", sha], cwd=workdir)

    for name in ("Cargo.toml", "LICENSE.md"):
        if not (workdir / name).is_file():
            raise Failure("{} is missing from the upstream tree at {}".format(name, sha[:12]))

    if check_branch:
        # The recipes pin `branch=<branch>;rev=<sha>` in SRC_URI and bitbake
        # trusts that pairing, so prove it. tree:0 pulls commit objects only.
        git(
            ["fetch", "--quiet", "--filter=tree:0", "origin", "refs/heads/" + branch],
            cwd=workdir,
        )
        ancestry = git(
            ["merge-base", "--is-ancestor", sha, "FETCH_HEAD"], cwd=workdir, check=False
        )
        if ancestry.returncode != 0:
            raise Failure(
                "{} is not reachable from {} -- the SRC_URI branch= and rev= "
                "would disagree. Pass --branch to name the right branch, or "
                "--no-branch-check to override.".format(sha[:12], branch)
            )


def has_path(path, workdir):
    """Whether path exists in the checked-out upstream tree.

    Local: --filter=blob:none omits blobs but fetches every tree, so this needs
    no network.
    """
    return bool(git(["ls-tree", "--name-only", "HEAD", path], cwd=workdir).stdout.strip())


# --------------------------------------------------------------------------
# The gettext patch
# --------------------------------------------------------------------------


def added_lines(patch_text):
    """What a patch inserts, per file it touches, with the leading '+' stripped.

    The blank line that goes with GETTEXT_BLOCK sits before or after it
    depending on where the block landed, so surrounding blank lines are not part
    of what a patch is compared on -- only the block itself is.
    """
    added = {}
    current = None
    for line in patch_text.splitlines():
        if line.startswith("+++ b/"):
            current = added.setdefault(line[len("+++ b/") :].strip(), [])
        elif line.startswith("+") and current is not None:
            current.append(line[1:])
    return {name: "\n".join(lines).strip("\n") for name, lines in added.items()}


def patched_cargo_toml(original, sha, manifest):
    """A workspace manifest with the gettext block inserted -- see GETTEXT_ANCHOR."""
    if "[patch.crates-io]" in original:
        raise Failure(
            "upstream {} at {} already declares [patch.crates-io]; the gettext "
            "patch would conflict. Resolve this by hand.".format(manifest, sha[:12])
        )
    anchors = original.count(GETTEXT_ANCHOR)
    if anchors > 1:
        raise Failure(
            "found {} [profile.release] sections in the upstream {} at {}; "
            "cannot tell which one to anchor the gettext patch to".format(
                anchors, manifest, sha[:12]
            )
        )
    if anchors == 1:
        index = original.index(GETTEXT_ANCHOR) + 1
        return original[:index] + GETTEXT_BLOCK + "\n" + original[index:]
    if not original.endswith("\n"):
        original += "\n"
    return original + "\n" + GETTEXT_BLOCK


def patch_application(patch_path, workdir):
    """How patch_path applies to the tree: "clean", "offset" or "failed".

    "offset" means the context still matches but at different line numbers.
    bitbake would accept that -- only genuine fuzz (context that had to be
    ignored) trips the patch-fuzz QA check, which is in ERROR_QA -- but an
    offset patch is one context change away from being a fuzzy one, and it puts
    "Hunk #1 succeeded at N (offset ...)" in every do_patch log until someone
    refreshes it. Treat it as stale.
    """
    result = git(["apply", "--check", "-v", patch_path], cwd=workdir, check=False)
    if result.returncode != 0:
        return "failed"
    # git apply is silent on an exact match and notes every relocated hunk.
    return "offset" if "Hunk #" in result.stdout + result.stderr else "clean"


def reusable_patch(previous_patch, workdir, manifests):
    """Whether the existing patch can be carried forward unchanged.

    Applying cleanly is not enough: the hunks only break when upstream's
    manifest context shifts, never when GETTEXT_BLOCK itself changes or when a
    workspace split moves the manifests that need it. Without this check,
    editing GETTEXT_BLOCK would silently have no effect for however many
    releases it takes for the context to move, and the release that split the
    demos out of the root workspace would have kept patching the root manifest.
    """
    wanted = {manifest: GETTEXT_BLOCK.strip("\n") for manifest in manifests}
    if added_lines(previous_patch.read_text()) != wanted:
        return False
    return patch_application(previous_patch, workdir) == "clean"


def regenerate_patch(previous_patch, workdir, sha, manifests):
    """A new patch file: the previous one's header, a freshly generated diff.

    The From/Subject/Upstream-Status lines are kept verbatim, so the patch keeps
    the provenance the layer has carried since 2023. The diffstat is regenerated
    along with the hunks, because a patch may now span more than one manifest.
    """
    previous = previous_patch.read_text()
    separator = "\n---\n"
    if separator not in previous:
        raise Failure("no diffstat separator found in {}".format(previous_patch))
    header = previous[: previous.index(separator)]

    # Yocto's patch-status QA check wants this; the older patches in the layer
    # predate it, so add it rather than silently inherit its absence.
    if "Upstream-Status:" not in header:
        header += "\nUpstream-Status: Inappropriate [embedded specific]\n"

    originals = {name: (workdir / name).read_text() for name in manifests}
    try:
        for name, original in originals.items():
            (workdir / name).write_text(patched_cargo_toml(original, sha, name))
        # --stat=72 is what git format-patch uses, so the diffstat looks like
        # the one the patch carried before.
        stat = git(["diff", "--stat=72", "--"] + manifests, cwd=workdir).stdout
        diff = git(["diff", "--"] + manifests, cwd=workdir).stdout
    finally:
        for name, original in originals.items():
            (workdir / name).write_text(original)

    # Drop the index line: the existing patches carry none, and a blob hash adds
    # noise that changes on every release without meaning anything.
    diff = "".join(
        line for line in diff.splitlines(keepends=True) if not line.startswith("index ")
    )
    if not diff.strip():
        raise Failure("generated an empty diff for the gettext patch")

    return header + separator + stat + "\n" + diff


def resolve_patch(previous_patch, version, workdir, sha, manifests):
    """Return (patch_name, content_or_None); None means reuse the old file."""
    if not previous_patch.is_file():
        raise Failure("a recipe references a patch that does not exist: {}".format(previous_patch))

    if reusable_patch(previous_patch, workdir, manifests):
        return previous_patch.name, None

    new_patch = previous_patch.parent / patch_name_for(version)
    if new_patch.exists():
        raise Failure(
            "{} needs regenerating but {} already exists; existing patch files "
            "are never modified".format(previous_patch.parent.name, new_patch)
        )
    return new_patch.name, regenerate_patch(previous_patch, workdir, sha, manifests)


def retire_patch(patch):
    """Drop a gettext patch the layer no longer references.

    Called once the recipe that used to name it has been renamed onto the new
    release and rewritten. Nothing reaches a patch except through bitbake's
    FILESPATH, which is <recipe dir>/<BPN>, so only the recipes sitting beside
    its directory can name it -- and the same basename exists under more than
    one family, so a layer-wide search by name would find slint-cpp's copy and
    conclude this one is still in use.
    """
    directory = patch.parent.parent
    referring = sorted(
        path.name
        for suffix in ("*.bb", "*.bbappend", "*.inc")
        for path in directory.glob(suffix)
        if patch.name in path.read_text()
    )
    if referring:
        raise Failure(
            "refusing to remove {}: still referenced by {}".format(
                patch.name, ", ".join(referring)
            )
        )
    git(["rm", "--quiet", "--", patch])


# --------------------------------------------------------------------------
# Recipes
# --------------------------------------------------------------------------


def substitute(text, pattern, replacement, what, where):
    """re.sub that insists on exactly one match.

    A silent no-op here leaves a recipe pinned to the previous release while
    every other field says otherwise -- and bitbake would build it happily.
    """
    text, count = re.subn(pattern, replacement, text)
    if count != 1:
        raise Failure("expected exactly one {} in {}, found {}".format(what, where, count))
    return text


def retarget(text, sha, md5, branch, where):
    """Point a recipe's SRC_URI and license checksum at a new revision."""
    text = substitute(
        text,
        r'(LIC_FILES_CHKSUM\s*=\s*"file://LICENSE\.md;md5=)[0-9a-f]{32}(")',
        r"\g<1>" + md5 + r"\g<2>",
        "LIC_FILES_CHKSUM",
        where,
    )
    text = substitute(
        text, r'(SLINT_REV\s*=\s*")[^"]*(")', r"\g<1>" + sha + r"\g<2>", "SLINT_REV", where
    )
    return substitute(
        text, r"(branch=)[^;\"]+(;)", r"\g<1>" + branch + r"\g<2>", "SRC_URI branch=", where
    )


def rewrite_recipe(text, old_version, new_version, sha, md5, branch, new_patch, where):
    """Point a release recipe at the new release."""
    text = retarget(text, sha, md5, branch, where)
    if new_patch:
        text = substitute(
            text, r'0001-WIP-[^"\s]+\.patch', new_patch, "gettext patch reference", where
        )
    # Comments referring to the release: "# v1.17.1 tag", "(release/1, v1.17.1)",
    # "(same revision as slint-cpp_1.17.1)".
    text = text.replace("v" + old_version, "v" + new_version)
    text = text.replace("slint-cpp_" + old_version, "slint-cpp_" + new_version)

    if old_version in text:
        raise Failure(
            "the old version {} still appears in {}:\n{}".format(
                old_version,
                where,
                "\n".join(line for line in text.splitlines() if old_version in line),
            )
        )
    return text


def repin_launcher(version, sha, md5, branch):
    """Move slint-launcher_git.bb from master onto the release.

    The launcher tracks master because demos/launcher post-dates the release the
    demos recipe is pinned to. Once a release carries it, the recipe can follow
    the same revision as everything else.
    """
    text = LAUNCHER_RECIPE.read_text()
    marker = 'SLINT_REV = "'
    if marker not in text:
        raise Failure("no SLINT_REV in {}".format(LAUNCHER_RECIPE))

    # Replace the contiguous comment block that explains the master pin, which
    # stops being true the moment we repin.
    lines = text.splitlines(keepends=True)
    start = next(i for i, line in enumerate(lines) if line.startswith(marker))
    first_comment = start
    while first_comment > 0 and lines[first_comment - 1].startswith("#"):
        first_comment -= 1
    lines[first_comment:start] = [
        "# Pinned to the same revision as the slint-demos and slint-viewer recipes\n"
        "# ({}, v{}), which now carries demos/launcher.\n".format(branch, version)
    ]

    LAUNCHER_RECIPE.write_text(
        retarget("".join(lines), sha, md5, branch, LAUNCHER_RECIPE.name)
    )


# --------------------------------------------------------------------------
# Verification
# --------------------------------------------------------------------------


def verify(written, workdir, new_patches, retired_patches):
    """Checks on what actually landed on disk.

    retarget() already guarantees every substitution fired, so this covers what
    it cannot see: that each recipe still points at a patch that exists and
    applies, and that no pre-existing patch file was touched beyond the ones
    deliberately retired.
    """
    problems = []

    for path in written:
        text = path.read_text()

        # A `SRC_URI +=` that lands before the `SRC_URI =` assignment is silently
        # discarded, taking the gettext patch with it -- the trap the recipes'
        # own NOTE comment warns about, inherited from whichever recipe was
        # copied forward, and one bitbake only catches at do_patch.
        assignment = re.search(r'^SRC_URI\s*=\s*"', text, re.MULTILINE)
        for append in re.finditer(r'^SRC_URI\s*\+=\s*"file://[^"]+\.patch"', text, re.MULTILINE):
            if assignment and append.start() < assignment.start():
                problems.append(
                    "{}: the SRC_URI += carrying the patch comes before the "
                    "SRC_URI assignment, so the patch would be dropped".format(path.name)
                )

        for reference in re.findall(r'file://([^"\s]+\.patch)', text):
            patch = path.parent / path.name.rsplit("_", 1)[0] / reference
            if not patch.is_file():
                problems.append(
                    "{} references {}, which does not exist".format(path.name, reference)
                )
            else:
                status = patch_application(patch, workdir)
                if status != "clean":
                    problems.append(
                        "{} references {}, which applies with {}".format(
                            path.name, reference, status
                        )
                    )

    # Existing patch files are load-bearing for older releases: any change to
    # one we neither created nor retired is a bug in this script. A retirement
    # is a deletion and nothing else -- retire_patch() has already established
    # that no recipe names the file.
    for name in git(["diff", "--name-only", "HEAD", "--"]).stdout.split():
        if "/0001-WIP-" in name and name not in new_patches + retired_patches:
            problems.append("modified an existing patch file: {}".format(name))
    for name in retired_patches:
        if (REPO / name).exists():
            problems.append("failed to remove the retired patch file: {}".format(name))

    if problems:
        raise Failure("verification failed:\n  " + "\n  ".join(problems))


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------


def summary_rows(summary, code=False):
    """The (label, value) pairs shown to a human and in the pull request.

    code marks up the machine-ish values for markdown; the terminal wants them
    bare, so the choice is a parameter rather than two copies of the table.
    """
    quote = (lambda value: "`{}`".format(value)) if code else (lambda value: value)
    rows = [
        (
            "Revision",
            "{} ({} on {})".format(
                quote(summary["sha"]), quote(summary["rev"]), quote(summary["branch"])
            ),
        ),
        ("LICENSE.md md5", quote(summary["license_md5"])),
    ]
    for patch in summary["patches"]:
        value = "{} ({})".format(quote(patch["patch"]), patch["action"])
        if patch["retired"]:
            value += ", {} removed".format(quote(patch["retired"]))
        rows.append(("{} patch".format(patch["recipe"]), value))
    rows.append(("slint-launcher", summary["launcher"]))
    return rows


def commit_message(summary):
    lines = [
        "Add {} release".format(summary["version"]),
        "",
        "Pin the {} recipes to {} ({}).".format(
            ", ".join(summary["recipes"]), summary["sha"], summary["rev"]
        ),
        "",
    ]
    for patch in summary["patches"]:
        line = "The {} gettext patch was {}: {}".format(
            patch["recipe"], patch["action"], patch["patch"]
        )
        if patch["retired"]:
            line += ", replacing {}, which nothing references any more".format(
                patch["retired"]
            )
        lines.append(line)
    lines += ["", "Produced by scripts/update-slint-version.py."]
    return "\n".join(lines) + "\n"


def pr_body(summary):
    lines = [
        "Bumps the layer from {} to {}.".format(summary["previous_version"], summary["version"]),
        "",
        "| | |",
        "|---|---|",
    ]
    lines += [
        "| {} | {} |".format(label, value)
        for label, value in summary_rows(summary, code=True)
    ]
    lines += [
        "",
        "Validated with `scripts/validate-slint-version.sh`: all recipes parse, and the "
        "bumped recipes get through `do_patch` and `do_populate_lic`, so the gettext "
        "patches apply and the license checksums match. Nothing was compiled.",
        "",
        "Still to do by hand:",
        "",
        "- [ ] Run the **CI** workflow on this branch for a real build",
        "- [ ] Rebuild the demo images (**Demo Images** workflow) once this is merged",
    ]
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("version", help="the Slint release, e.g. 1.18.0")
    parser.add_argument("--rev", help="tag, branch or SHA to pin (default: v<version>)")
    parser.add_argument(
        "--branch", help="branch for SRC_URI (default: whatever the previous release used)"
    )
    parser.add_argument(
        "--no-branch-check",
        action="store_true",
        help="skip proving the revision is reachable from the SRC_URI branch",
    )
    parser.add_argument(
        "--repin-launcher",
        action="store_true",
        help="also move slint-launcher_git.bb onto this release",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="report what would change, write nothing"
    )
    parser.add_argument("--summary-json", help="write a JSON summary to this path")
    parser.add_argument("--commit-message-file", help="write the commit message to this path")
    parser.add_argument("--pr-body-file", help="write the pull request body to this path")
    args = parser.parse_args()

    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        raise Failure("version must look like 1.18.0, got {!r}".format(args.version))

    # Everything each family needs, resolved once.
    plan = [Bump(family, args.version) for family in FAMILIES]

    cpp = plan[0]
    if version_key(args.version) <= version_key(cpp.old_version):
        raise Failure(
            "{} is not newer than the newest recipe already in the layer "
            "({})".format(args.version, cpp.old_version)
        )
    for bump in plan:
        if bump.destination.exists():
            raise Failure("{} already exists".format(bump.destination))

    branch_match = re.search(r"branch=([^;\"]+);", cpp.text)
    if not branch_match:
        raise Failure("no branch= in the SRC_URI of {}".format(cpp["recipe"]))
    branch = args.branch or branch_match.group(1)

    rev = args.rev or ("v" + args.version)
    sha = resolve_rev(rev, branch)

    workdir = Path(tempfile.mkdtemp(prefix="slint-src-"))
    try:
        fetch_upstream(sha, branch, workdir, check_branch=not args.no_branch_check)
        md5 = hashlib.md5((workdir / "LICENSE.md").read_bytes()).hexdigest()

        # Resolved before any writing, so a dry run exercises regeneration too.
        for bump in plan:
            if bump.previous_patch:
                bump.patch, bump.patch_content = resolve_patch(
                    bump.previous_patch,
                    args.version,
                    workdir,
                    sha,
                    bump.family.manifests(workdir),
                )

        launcher_carries_launcher = has_path("demos/launcher", workdir)
        if args.repin_launcher:
            if not launcher_carries_launcher:
                raise Failure(
                    "--repin-launcher was requested but demos/launcher does not "
                    "exist at {}".format(sha[:12])
                )
            launcher_action = "repinned to v" + args.version
        elif launcher_carries_launcher:
            launcher_action = (
                "left on master, but this release carries demos/launcher -- "
                "consider --repin-launcher"
            )
        else:
            launcher_action = "left on master"

        if not args.dry_run:
            staged = []
            new_patches = []
            retired_patches = []
            for bump in plan:
                if bump.patch_content:
                    patch = bump.family.patch_dir / bump.patch
                    patch.write_text(bump.patch_content)
                    if patch_application(patch, workdir) != "clean":
                        raise Failure(
                            "the regenerated patch {} does not apply cleanly".format(patch)
                        )
                    new_patches.append(str(patch.relative_to(REPO)))

                if not bump.family.keeps_history:
                    git(["mv", "--", bump.recipe, bump.destination])
                bump.destination.write_text(
                    rewrite_recipe(
                        bump.text,
                        bump.old_version,
                        args.version,
                        sha,
                        md5,
                        branch,
                        bump.patch,
                        bump.destination.name,
                    )
                )
                staged.append(bump.destination)

                # After the rename and the rewrite above, so the only recipe
                # that could still name the old patch no longer does.
                if bump.retired_patch:
                    retire_patch(bump.retired_patch)
                    retired_patches.append(str(bump.retired_patch.relative_to(REPO)))

            if args.repin_launcher:
                repin_launcher(args.version, sha, md5, branch)
                staged.append(LAUNCHER_RECIPE)

            git(["add", "--"] + staged + new_patches)
            verify(
                [bump.destination for bump in plan], workdir, new_patches, retired_patches
            )
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    summary = {
        "version": args.version,
        "rev": rev,
        "sha": sha,
        "branch": branch,
        "license_md5": md5,
        "previous_version": cpp.old_version,
        "recipes": [bump.family.stem for bump in plan],
        "patches": [
            {
                "recipe": bump.family.stem,
                "patch": bump.patch,
                "action": bump.patch_action,
                "retired": bump.retired_patch.name if bump.retired_patch else None,
            }
            for bump in plan
            if bump.previous_patch
        ],
        "launcher": launcher_action,
        "dry_run": args.dry_run,
    }

    print("Slint {}  ({} -> {})".format(args.version, cpp.old_version, args.version))
    rows = summary_rows(summary)
    width = max(len(label) for label, _ in rows)
    for label, value in rows:
        print("  {:{}} {}".format(label, width, value))
    if args.dry_run:
        print("\ndry run: nothing written")
    else:
        print()
        print(git(["status", "--short"]).stdout, end="")

    for path, content in (
        (args.summary_json, json.dumps(summary, indent=2) + "\n"),
        (args.commit_message_file, commit_message(summary)),
        (args.pr_body_file, pr_body(summary)),
    ):
        if path:
            Path(path).write_text(content)


if __name__ == "__main__":
    try:
        main()
    except Failure as failure:
        print("error: {}".format(failure), file=sys.stderr)
        sys.exit(1)
