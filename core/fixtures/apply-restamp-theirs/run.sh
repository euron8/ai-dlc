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

# apply.sh WRITES the in-flight marker; pre-push READS it. Both halves are resolved here,
# because a marker nothing refuses on is a file, not a guard.
for cand in "$ROOT/core/git-hooks/pre-push" "$ROOT/.githooks/pre-push"; do
  [ -f "$cand" ] && PREPUSH="$cand" && break
done
[ -n "${PREPUSH:-}" ] || { echo "FIXTURE ERROR: pre-push not found in either layout — the marker's READER cannot be evaluated, and passing without it would report the guard as working when it was never run." >&2; exit 2; }

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
# A fixture that CHANGES in the range, so the write ORDER is observable. core/fixtures/
# sorts before core/scripts/ and core/session-driver/, so preclassify emits it first and
# the unsorted order is exactly backwards: the test lands before its subject.
mkdir -p "$DIST/core/fixtures/synthetic-fx" "$CONSUMER/tests/fixtures/synthetic-fx" || exit 2
printf '#!/usr/bin/env bash\n# fx v1\n' > "$DIST/core/fixtures/synthetic-fx/run.sh"
printf '#!/usr/bin/env bash\n# fx v1\n' > "$CONSUMER/tests/fixtures/synthetic-fx/run.sh"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS at 2.0.0 — this is the version the stamp must record.
printf '2.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\n# fx v2 UPSTREAM\n' > "$DIST/core/fixtures/synthetic-fx/run.sh"
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

# --- Assertion 4: A FIXTURE IS WRITTEN AFTER ITS SUBJECT ----------------------
# core/fixtures/ sorts first, so preclassify's natural order writes the test before the
# thing it tests. A suite run in that window fails on behaviour that is not installed
# yet: on the 0.156.0 -> 0.162.0 pull, check-15-bypass could not find core-paths.sh and
# core-write-guard read the core-fixture deny as `allow`. Assert every fixtures/ row
# lands after every non-fixture row.
fx_first="$(printf '%s\n' "$out" | awk '$0 ~ /pure-apply/ {print $3}' | grep -n '^fixtures/' | head -1 | cut -d: -f1)"
nonfx_last="$(printf '%s\n' "$out" | awk '$0 ~ /pure-apply/ {print $3}' | grep -vn '^fixtures/' | tail -1 | cut -d: -f1)"
if [ -z "$fx_first" ] || [ -z "$nonfx_last" ]; then
  bad "setup: the report has no fixtures/ row and/or no non-fixture row — assertion 4 would pass vacuously"
elif [ "$fx_first" -gt "$nonfx_last" ]; then
  ok "a changed fixture is written AFTER every non-fixture core file (test never precedes subject)"
else
  bad "a fixture was written at position $fx_first, before a non-fixture core file at $nonfx_last — the suite can run against a test newer than its subject"
fi

# --- Assertion 5: THE IN-FLIGHT MARKER CLEARS WITH THE STAMP ------------------
# Ordering cannot make the window safe on its own -- only one of the two directions can
# be last, and the reverse one breaks OLD assertions against a newer subject (this very
# fixture and apply-drift-refile both failed that way against a newer apply.sh). So the
# tree carries a marker saying "do not judge me yet", and pre-push refuses the suite while
# it exists. It must be GONE after a clean apply, or the consumer can never push again.
APPLYING="$CONSUMER/.claude/.ai-dlc-applying"
if [ ! -f "$APPLYING" ]; then
  ok "the in-flight marker is cleared by a clean apply (pre-push is not left wedged)"
else
  bad "the in-flight marker survived a CLEAN apply — every subsequent push blocks on a consistent tree"
fi
if printf '%s\n' "$out" | grep -q 'RESOLVED.*consistent'; then
  ok "  and the report says so, rather than clearing it silently"
else
  bad "  the report does not record the tree becoming consistent"
fi

# --- Assertion 6: A WITHHELD RE-STAMP KEEPS THE MARKER -----------------------
# The half that matters. A tree that could not be fully applied IS inconsistent, so the
# marker must stay and keep blocking the suite. Clearing it in a trap would have looked
# correct and defeated the whole guard. Drive the same withheld path assertion 0's
# manifest-unreadable case uses: no core/scripts/ in THEIRS means zero validators.
RECON2="$WORK/recon2"
mkdir -p "$RECON2" || exit 2
cp "$(dirname "$APPLY")"/* "$RECON2/" 2>/dev/null || { echo "FIXTURE ERROR: could not copy reconcile/" >&2; exit 2; }
printf '# no core_manifest block here\n' > "$RECON2/setup-sites.md"
APPLY2="$RECON2/apply.sh"
W2="$WORK/consumer2"
mkdir -p "$W2/.claude/session-driver" "$W2/tests/fixtures" || exit 2
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$W2/.claude/.ai-dlc-version"
out6="$(bash "$APPLY2" "$DIST" "$BASE" "$W2" "$THEIRS" 2>&1)"
if printf '%s\n' "$out6" | grep -q 'restamp-withheld'; then
  if [ -f "$W2/.claude/.ai-dlc-applying" ]; then
    ok "a withheld re-stamp LEAVES the marker — the suite stays blocked on a partial tree"
  else
    bad "the marker was cleared despite a withheld re-stamp — a partially applied tree would report false fixture failures as if they were real"
  fi
else
  bad "setup: could not drive a withheld re-stamp, so assertion 6 proves nothing"
  printf '%s\n' "$out6" | sed 's/^/        /' | head -5
fi

# --- Assertions 7/8: THE MARKER'S READER ACTUALLY REFUSES ---------------------
# A marker nothing refuses on is a file, not a guard -- and it would have looked identical
# in the report. Drive the real pre-push in a throwaway tree, both directions: the message
# must appear and the hook must exit non-zero with the marker, and the suite must run
# normally without it. The paired control is what makes assertion 7 mean anything, because
# every other step in that minimal tree fails too.
PP="$WORK/pptree"
mkdir -p "$PP/.claude" "$PP/tests/fixtures/x" || exit 2
printf '#!/usr/bin/env bash\nexit 0\n' > "$PP/tests/fixtures/x/run.sh"
: > "$PP/.claude/.ai-dlc-applying"
pp_out="$(cd "$PP" && bash "$PREPUSH" </dev/null 2>&1)"; pp_rc=$?
if printf '%s\n' "$pp_out" | grep -q 'ai-dlc-applying' && [ "$pp_rc" -ne 0 ]; then
  ok "pre-push REFUSES the fixture suite while the marker exists, and names the file"
else
  bad "pre-push ran the suite on a mid-pull tree (rc=$pp_rc) — the marker is written but nothing reads it"
fi
rm -f "$PP/.claude/.ai-dlc-applying"
pp_out2="$(cd "$PP" && bash "$PREPUSH" </dev/null 2>&1)"
if ! printf '%s\n' "$pp_out2" | grep -q 'ai-dlc-applying'; then
  ok "  control: with no marker the suite runs normally (the guard is not always-on)"
else
  bad "  the guard fires with no marker present — it would block every push forever"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  apply-restamp-theirs: the stamp is computed from theirs, so a distribution"
  echo "      checkout on any other ref cannot make it claim a version the tree lacks;"
  echo "      a changed fixture is written after its subject; and the in-flight marker"
  echo "      clears with the stamp, survives a withheld one, and is what pre-push"
  echo "      refuses on so a mid-pull tree is never judged by its own fixtures."
  exit 0
fi
echo "apply-restamp-theirs: $fails assertion(s) FAILED"
exit 1
