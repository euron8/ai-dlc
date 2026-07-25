#!/usr/bin/env bash
# apply-restamp-theirs — the re-stamp reads VERSION from THEIRS, never from the
# distribution's working tree.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# apply.sh resolves every file it copies through `git show "${THEIRS}:core/..."`, and
# takes the stamp's `commit:` from `git rev-parse "$THEIRS"`. One line did not follow:
# the stamp's `version:` came from `cat "$DIST/VERSION"` — whatever ref the operator's
# distribution checkout happened to be sitting on.
#
# Hit live on the v0.92.0 pull. The checkout sat on a v0.93.0 branch while theirs was
# origin/main at v0.92.0, so the stamp was written `version: 0.93.0` against 0.92.0
# content, and had to be corrected by hand. Note the shape: the SAME stamp carried a
# `commit:` taken correctly from theirs. The result is not merely stale, it is
# INCOHERENT — a version and a commit that cannot both be true of one tree.
#
# Why it matters more than a cosmetic field: `.ai-dlc-version` is what the NEXT pull
# reads to compute its base. A stamp that overstates the version silently mis-bases that
# merge, and the damage surfaces a pull later, far from the run that caused it.
#
# WHY THIS FIXTURE IS NOT VACUOUS. The assertion only means anything if the working
# tree's VERSION differs from THEIRS' — otherwise `cat` and `git show` agree and a
# reverted fix would still pass. So the dist repo below is built with THREE different
# versions (base 1.0.0, theirs 2.0.0, working tree 9.9.9) and assertion 0 FAILS THE
# FIXTURE if that separation ever collapses.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping: core/skills/<x> lands under
# .claude/skills/<x> on a consumer.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh"
else
  echo "FIXTURE ERROR: apply.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/skills/... (distribution), $ROOT/.claude/skills/... (consumer)" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-restamp.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

DIST="$WORK/dist"; CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/session-driver" "$CONSUMER/.claude/session-driver" \
         "$DIST/core/scripts" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

# BASE at 1.0.0.
printf '1.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v1\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
# A real distribution ALWAYS ships core validators, and since v0.160.0 the manifest
# claims them as `core/scripts/ai-dlc/*` -- one entry apply.sh expands against THEIRS'
# tree. A synthetic DIST that ships none makes that expansion empty, which apply.sh
# reports as manifest-unreadable and withholds the re-stamp for, correctly: a stamp
# claiming a version whose validators are absent is the failure it exists to prevent.
# This fixture used to pass through that hole -- the old 27-name enumeration produced
# 27 individual cat-file misses, and 27 misses read as "nothing to relocate".
printf '#!/usr/bin/env bash\necho v\n' > "$DIST/core/scripts/validate-synthetic.sh"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS at 2.0.0 — this is the version the stamp must record.
printf '2.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
THEIRS_SHORT="$(git -C "$DIST" rev-parse --short HEAD)"

# The operator's checkout is on something else entirely — a later release branch. This is
# the live condition: the tree says 9.9.9 while the pull is bringing 2.0.0.
printf '9.9.9\n' > "$DIST/VERSION"

# Consumer sits at BASE, unmodified: the plainest possible pull.
printf '#!/usr/bin/env bash\n# driver v1\n' > "$CONSUMER/.claude/session-driver/ai-dlc-session-driver.sh"
STAMP="$CONSUMER/.claude/.ai-dlc-version"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$STAMP"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-restamp-theirs:"

# --- Assertion 0: the three versions are actually distinct --------------------
# Without this the whole fixture can go quietly vacuous.
wt_ver="$(cat "$DIST/VERSION")"
theirs_ver="$(git -C "$DIST" show "$THEIRS:VERSION")"
if [ "$wt_ver" != "$theirs_ver" ] && [ "$theirs_ver" != "1.0.0" ]; then
  ok "setup: working tree ($wt_ver) differs from theirs ($theirs_ver) — the assertion can fail"
else
  bad "setup: working tree ($wt_ver) and theirs ($theirs_ver) are not separated — every assertion below would pass vacuously"
  echo; echo "FIXTURE BROKEN apply-restamp-theirs: the separation this fixture depends on is gone."
  exit 2
fi

# --- Assertion 1: the stamp records THEIRS' version ---------------------------
out="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
got_ver="$(sed -n 's/^version: *//p' "$STAMP")"
if [ "$got_ver" = "$theirs_ver" ]; then
  ok "stamp records theirs' version ($theirs_ver)"
elif [ "$got_ver" = "$wt_ver" ]; then
  bad "stamp records the WORKING TREE's version ($got_ver), not theirs ($theirs_ver) — this is the v0.92.0 defect: apply.sh read VERSION with cat instead of git show \"\$THEIRS:VERSION\""
else
  bad "stamp records $got_ver, expected theirs' $theirs_ver"
fi

# --- Assertion 2: version and commit describe the SAME tree -------------------
# The defect's signature is a coherent commit beside an incoherent version, so assert
# the pair, not just the field that broke.
got_sha="$(sed -n 's/^commit: *//p' "$STAMP")"
if [ "$got_sha" = "$THEIRS_SHORT" ] && [ "$got_ver" = "$theirs_ver" ]; then
  ok "version and commit describe one tree ($theirs_ver @ $THEIRS_SHORT)"
else
  bad "stamp is internally inconsistent: version $got_ver with commit $got_sha (theirs is $theirs_ver @ $THEIRS_SHORT)"
fi

# --- Assertion 3: the control — checkout ON theirs still stamps correctly -----
# A fix that hardcoded the wrong ref, or broke the ordinary path, fails here.
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$STAMP"
# Put the working tree genuinely ON theirs. `git checkout` will NOT do it here: VERSION
# is modified-and-uncommitted, so the dirty 9.9.9 survives the checkout and the "control"
# would silently still be testing the mismatched case.
git -C "$DIST" show "$THEIRS:VERSION" > "$DIST/VERSION"
bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
ctl_ver="$(sed -n 's/^version: *//p' "$STAMP")"
if [ "$ctl_ver" = "$theirs_ver" ]; then
  ok "control: checkout already on theirs still stamps $theirs_ver"
else
  bad "control: checkout on theirs stamped $ctl_ver, expected $theirs_ver — the ordinary path regressed"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  apply-restamp-theirs: the stamp is computed from theirs, so a distribution"
  echo "      checkout on any other ref cannot make it claim a version the tree lacks."
  exit 0
fi
echo "apply-restamp-theirs: $fails assertion(s) FAILED"
exit 1
