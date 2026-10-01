#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# apply-legacy-script-path — a core validator left at the pre-0.126.0 location is
# reported, and a LOCALLY EDITED one is reported on its own.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# v0.126.0 moved core validators from scripts/ to scripts/ai-dlc/, and in doing so
# made the OLD path invisible to every detector at once:
#
#   - map_consumer() now sends core/scripts/X to scripts/ai-dlc/X. On a consumer
#     that has not migrated, that path does not exist yet, so the file classifies as
#     a clean ADD and the copy at scripts/X is compared against nothing.
#   - unregistered-drift.sh deliberately excludes scripts/ on the premise that "an
#     edit breaks LOUDLY, not silently". That premise was already thin: the
#     reference consumer had a validator 160 lines diverged from upstream, carrying
#     a whole derivation nothing upstream knew about, and nothing said a word about
#     it until it was diffed by hand.
#
#     It was ONE validator, not two. The original note here said two, and the
#     second was a miscount worth recording because of HOW it happened: the
#     consumer was diffed against its STAMPED BASE, which answers "does this tree
#     differ from what it was given" -- not "does it differ from what upstream has
#     NOW". Against HEAD that file was byte-identical; upstream had made the same
#     fix independently three releases later. Diffing against the base finds every
#     local change AND every upstream change the consumer has not yet pulled, and
#     reports them the same way.
#
# BEFORE the move, an edited scripts/X surfaced as a BOTH-CHANGED conflict. The move
# removed that without replacing it, which would turn a real local change into an
# orphan -- not clobbered, just never mentioned again. This is the replacement, and
# assertion 2 is the one that matters: it is the exact case the reference consumer
# is in right now.
#
# The driver REPORTS and never deletes. A difference is the very thing the new
# boundary exists to prevent, and it belongs upstream as a push candidate.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh"
else
  echo "FIXTURE ERROR: apply.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-legacy.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# apply.sh derives the relocation set and each file's destination from the
# core_manifest block in setup-sites.md, resolved relative to its OWN directory. So
# the whole reconcile engine is copied here and given a manifest naming this
# fixture's synthetic validators. Running the shipped apply.sh in place would read
# the real manifest, which of course does not list them -- nothing would relocate and
# every assertion below would pass or fail for the wrong reason.
RECON="$WORK/reconcile"
mkdir -p "$RECON" || exit 2
cp "$(dirname "$APPLY")"/* "$RECON/" 2>/dev/null || { echo "FIXTURE ERROR: could not copy reconcile/" >&2; exit 2; }
APPLY="$RECON/apply.sh"
cat > "$RECON/setup-sites.md" <<'SITES'
# Setup sites (fixture stand-in)

```yaml
core_manifest:
  - core/scripts/ai-dlc/validate-untouched.sh
  - core/scripts/ai-dlc/validate-edited.sh
```
SITES

DIST="$WORK/dist"; CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/scripts" "$CONSUMER/.claude" "$CONSUMER/scripts" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

printf '1.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\necho untouched\n' > "$DIST/core/scripts/validate-untouched.sh"
printf '#!/usr/bin/env bash\necho edited\n'    > "$DIST/core/scripts/validate-edited.sh"
# 100755 in git, or the exec-bit assertions below are vacuous: sync_mode_from_theirs
# derives the bit from ls-tree, so a 644 blob correctly yields a non-executable copy
# and there is nothing for the audit to catch.
chmod +x "$DIST/core/scripts/validate-untouched.sh" "$DIST/core/scripts/validate-edited.sh"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# The consumer as it stands BEFORE migrating: both validators loose in scripts/, one
# of them locally edited. Nothing in scripts/ai-dlc/ yet -- apply.sh creates it.
cp "$DIST/core/scripts/validate-untouched.sh" "$CONSUMER/scripts/"
cp "$DIST/core/scripts/validate-edited.sh"    "$CONSUMER/scripts/"
printf '# LOCAL EDIT the consumer made while the old layout permitted it\n' \
  >> "$CONSUMER/scripts/validate-edited.sh"
# A consumer-owned script that must never be mentioned.
printf '#!/usr/bin/env bash\necho mine\n' > "$CONSUMER/scripts/audit-dormant-gates.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-legacy-script-path:"

OUT="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"

# --- 0. The move actually happened, or every assertion below is vacuous --------
if [ -f "$CONSUMER/scripts/ai-dlc/validate-untouched.sh" ]; then
  ok "setup: apply.sh placed the validators at scripts/ai-dlc/ (mkdir -p works on the update path)"
else
  bad "setup: apply.sh did not create scripts/ai-dlc/ -- the whole subtree silently failed to land"
  printf '%s\n' "$OUT" | sed 's/^/        /'
  echo; echo "FIXTURE BROKEN apply-legacy-script-path."
  exit 2
fi

# --- 1. The identical leftovers are reported, as ONE row -----------------------
# One closed question per row is the report contract; N identical files is one call.
if grep -q 'relocate-move' <<<"$OUT"; then
  ok "an identical leftover at the old path is moved and reported"
else
  bad "the identical leftover was NOT moved/reported -- the consumer keeps a silent duplicate"
fi

# --- 2. AN EDITED COPY IS OVERWRITTEN, NOT ADJUDICATED -------------------------
# Core is upstream-owned and overwrite-on-pull, and a validator is machinery with no
# consumer layer -- no overrides/ shadow, no extensions/ entry, exactly like a hook.
# So an edit at the old path is a boundary violation the new layout prevents, not a
# call the operator owes an answer to. It is reported as done, in the same row as
# every other moved copy, and never as a DECISION.
if grep -q 'DECISION.*legacy-script' <<<"$OUT"; then
  bad "an edited leftover was raised as a DECISION -- it is overwrite-on-pull, not a call to make"
  printf '%s\n' "$OUT" | grep -i legacy | sed 's/^/        /'
else
  ok "no DECISION row is raised for a locally edited leftover"
fi
if grep -q 'validate-edited\.sh' <<<"$(printf '%s' "$OUT" | grep 'relocate-move')"; then
  ok "  the edited copy is reported as moved, alongside the rest"
else
  bad "  the edited copy was moved without appearing in the move record"
fi

# --- 3. THE OLD PATH IS EMPTIED -------------------------------------------------
# A leftover shadows nothing and nothing refreshes it, so it silently diverges from
# the file it is a copy of. Both copies move: the identical one and the edited one.
if [ ! -f "$CONSUMER/scripts/validate-untouched.sh" ] \
   && [ ! -f "$CONSUMER/scripts/validate-edited.sh" ]; then
  ok "both old copies are moved away, including the edited one"
else
  bad "a core validator is still at the pre-0.126.0 path after apply"
fi
# The new copy must be UPSTREAM's, not the consumer's stale edit promoted over it.
if grep -q 'LOCAL EDIT' "$CONSUMER/scripts/ai-dlc/validate-edited.sh" 2>/dev/null; then
  bad "  the edited copy was moved ON TOP of upstream's -- the new location is not THEIRS"
else
  ok "  and the new location holds upstream's content, not the edit"
fi

# --- 4. The consumer's OWN script is never mentioned ---------------------------
# The boundary must be silent on everything that is not ours, or it gets ignored.
if grep -q 'audit-dormant-gates' <<<"$OUT"; then
  bad "a consumer-owned script was reported -- the boundary is indicting their tooling"
else
  ok "the consumer's own script is not mentioned"
fi

# --- 5. THE EXEC BIT IS AUDITED, NOT ASSUMED -----------------------------------
# v0.70.1: `git show > file` is a shell redirect and takes the mode from the umask,
# so a validator lands non-executable and INERT while every content diff reports
# green. sync_mode_from_theirs() chmods with `|| true`, so a failed chmod is silent
# -- the RESULT has to be asserted, not the attempt.
# Guard the guard: if THEIRS ever stops shipping these 755 the assertions go vacuous.
if [ "$(git -C "$DIST" ls-tree "$THEIRS" -- core/scripts/validate-untouched.sh | awk '{print $1}')" != "100755" ]; then
  bad "setup: the fixture's own dist blob is not 100755 -- the exec-bit assertions would be vacuous"
elif [ -x "$CONSUMER/scripts/ai-dlc/validate-untouched.sh" ]; then
  ok "a relocated validator lands executable"
else
  bad "the relocated validator is not executable -- installed and inert (v0.70.1)"
fi
# Now break it the way a umask would, and require the audit to catch it AND to
# withhold the re-stamp: a stamp asserting THEIRS over a tree whose validators
# cannot run is the claim v0.70.1 showed is worse than no stamp.
chmod -x "$CONSUMER/scripts/ai-dlc/validate-untouched.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"
OUT2="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if grep -q 'not-executable.*validate-untouched\.sh' <<<"$OUT2"; then
  ok "  a non-executable shipped-755 file is reported by name"
else
  bad "  a non-executable validator was NOT reported -- inert and green, the v0.70.1 signature"
  printf '%s\n' "$OUT2" | sed 's/^/        /'
fi
if grep -q 'restamp-withheld' <<<"$OUT2"; then
  ok "  and the re-stamp is withheld"
else
  bad "  the re-stamp was written over a tree with an inert validator"
fi

# --- 6. THE RELOCATION SET IS THE MANIFEST'S, NOT THE DIRECTORY'S --------------
# Under a LITERAL manifest the declared set and the directory can disagree, and the
# only way to show which one drives the relocation is to make them: ship a third
# validator in core/scripts, present at BASE and UNCHANGED through THEIRS, and leave
# it out of the manifest.
#
# The SHIPPED manifest declares the directory instead (`core/scripts/ai-dlc/*`), and
# then the two cannot disagree by construction -- so case 11 re-runs this same tree
# against the glob form and requires the OPPOSITE outcome on this same file. The pair
# is what pins which source is being read; neither half means much alone.
#
# Unchanged is the load-bearing part. This asserts the LEVEL-TRIGGERED top-up loop
# only, which is the code the manifest governs. A file that CHANGED in the range is
# placed by the changed-files pass through map_consumer() -- the general mechanism
# for every core subtree, which stays a prefix mapper because I8 synthesises
# `core/scripts/PROBE` to test it and no manifest can answer for a path that does
# not exist. The first draft of this assertion used a NEW file and failed for that
# reason: it was measuring map_consumer(), not the manifest.
gitc checkout -q "$BASE" -- . 2>/dev/null || true
printf '#!/usr/bin/env bash\necho undeclared\n' > "$DIST/core/scripts/validate-undeclared.sh"
chmod +x "$DIST/core/scripts/validate-undeclared.sh"
gitc add -A && gitc commit -q --amend --no-edit -q 2>/dev/null || gitc commit -q -m rebase
BASE2="$(git -C "$DIST" rev-parse HEAD)"
printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m theirs2
THEIRS2="$(git -C "$DIST" rev-parse HEAD)"
# Confirm the separation this assertion depends on, or it goes quietly vacuous.
if [ -n "$(git -C "$DIST" diff --name-only "$BASE2" "$THEIRS2" -- core/scripts)" ]; then
  bad "setup: core/scripts changed in the range -- the changed-files pass would place it and this proves nothing"
else
  rm -rf "$CONSUMER/scripts/ai-dlc"
  bash "$APPLY" "$DIST" "$BASE2" "$CONSUMER" "$THEIRS2" >/dev/null 2>&1
  if [ -f "$CONSUMER/scripts/ai-dlc/validate-untouched.sh" ] \
     && [ ! -f "$CONSUMER/scripts/ai-dlc/validate-undeclared.sh" ]; then
    ok "the relocation loop places only manifest-declared validators"
  else
    bad "an undeclared validator was relocated -- the DIRECTORY is driving the loop, not the manifest"
  fi
fi

# --- 7. AN UNREADABLE MANIFEST IS NOT "NOTHING TO DO" --------------------------
# The failure this guards is the one that would hurt most: a manifest the driver
# cannot parse yields an empty set, relocates nothing, and the run still re-stamps —
# a stamp claiming a version whose validators are not where every core reference
# points. Zero must be loud.
printf '# no core_manifest block here\n' > "$RECON/setup-sites.md"
rm -rf "$CONSUMER/scripts/ai-dlc"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"
OUT4="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if grep -q 'manifest-unreadable' <<<"$OUT4"; then
  ok "an unreadable manifest is reported, not treated as an empty relocation set"
else
  bad "an unreadable manifest relocated nothing SILENTLY -- the check-that-cannot-fire, one layer down"
fi
if grep -q 'restamp-withheld' <<<"$OUT4"; then
  ok "  and the re-stamp is withheld"
else
  bad "  the re-stamp was written over a tree nothing was relocated into"
fi

# --- 8. THE WHOLE DECLARED SET IS VERIFIED, NOT JUST WHAT MOVED ----------------
# The migration's worst outcome is a half-landing: the old path is emptied, so a
# validator missing from the new path is missing full stop and every reference to it
# resolves to nothing. Delete one AFTER apply has placed it, re-run with nothing left
# at the old path to trigger a move, and require the verification pass to catch it on
# presence alone.
cat > "$RECON/setup-sites.md" <<'SITES'
```yaml
core_manifest:
  - core/scripts/ai-dlc/validate-untouched.sh
  - core/scripts/ai-dlc/validate-edited.sh
```
SITES
rm -rf "$CONSUMER/scripts/ai-dlc"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"
bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
rm -f "$CONSUMER/scripts/ai-dlc/validate-untouched.sh"   # a half-landed migration
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"
OUT5="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if grep -q 'declared-missing.*validate-untouched\.sh' <<<"$OUT5"; then
  ok "a declared validator missing from the new location is caught by name"
else
  # It may legitimately have been re-placed by the relocation loop; that is also a
  # correct outcome, but then it must be PRESENT. Absent AND unreported is the bug.
  if [ -f "$CONSUMER/scripts/ai-dlc/validate-untouched.sh" ]; then
    ok "a declared validator missing from the new location is re-placed"
  else
    bad "a declared validator is absent from the new location and nothing said so"
    printf '%s\n' "$OUT5" | sed 's/^/        /'
  fi
fi

# --- 9. IDEMPOTENT: THE STEADY STATE IS SILENT AND UNCHANGED -------------------
# This runs on EVERY /ai-dlc-update, not once at a migration. So the second run over
# an already-migrated tree must do nothing and say nothing about relocation: no
# placement (the files are there), no move (the old path is empty), and no rows. A
# process that keeps announcing a migration it already finished trains the operator
# to skim the report, which is how the rows that DO matter get missed.
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"
bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1   # settle
before="$(find "$CONSUMER/scripts" -type f 2>/dev/null | sort | while IFS= read -r f; do printf '%s %s\n' "$(cksum < "$f")" "${f#"$CONSUMER"/}"; done)"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"
OUT6="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
after="$(find "$CONSUMER/scripts" -type f 2>/dev/null | sort | while IFS= read -r f; do printf '%s %s\n' "$(cksum < "$f")" "${f#"$CONSUMER"/}"; done)"
if [ "$before" = "$after" ]; then
  ok "a second run over a migrated tree changes nothing on disk"
else
  bad "the second run altered the tree -- not idempotent"
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed 's/^/        /'
fi
if grep -qE 'relocate|legacy-script|declared-' <<<"$OUT6"; then
  bad "  the steady state still emits relocation rows -- the operator learns to skim them"
  printf '%s\n' "$OUT6" | grep -E 'relocate|legacy-script|declared-' | sed 's/^/        /'
else
  ok "  and says nothing about relocation"
fi

# --- 10. THE MUTATION TEST — prove the rows come from the new block ------------
# Neuter the legacy loop's file test on a COPY. Both rows must disappear; if either
# survives, something else was emitting it and assertions 1-2 prove nothing.
MUTANT="$WORK/mutant.sh"
sed 's@^  \[ -f "\$old" \] || continue@  continue@' "$APPLY" > "$MUTANT" || exit 2
if cmp -s "$APPLY" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the legacy loop was rewritten" >&2
  exit 2
fi
rm -rf "$CONSUMER/scripts/ai-dlc"
cp "$DIST/core/scripts/validate-edited.sh" "$CONSUMER/scripts/validate-edited.sh"
printf '# LOCAL EDIT\n' >> "$CONSUMER/scripts/validate-edited.sh"
MOUT="$(bash "$MUTANT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if grep -q 'legacy-script' <<<"$MOUT"; then
  bad "MUTATION: legacy rows still emitted without the loop -- assertions 1-2 prove nothing"
else
  ok "MUTATION: disabling the legacy loop removes both rows"
fi

# --- 11. THE SHIPPED GLOB FORM IS ITERATED AS ITS MEMBERS -----------------------
# v0.160.0 replaced the manifest's 27 filenames with `core/scripts/ai-dlc/*`. Every
# case above writes a hand-ENUMERATED stand-in manifest, so all of them stay green
# against a shipped manifest the mechanism can no longer iterate. That is the exact
# vacuous shape this repo has shipped before, and it would have hidden a bad failure:
# manifest_dests() reading the glob entry literally yields one non-path (`*`), every
# cat-file probe misses, the loop runs zero times -- and case 7's manifest_n guard
# does NOT fire, because one entry is not zero. The pull would relocate nothing and
# re-stamp anyway.
#
# So this case writes the SHIPPED form and asserts POSITIVELY: the files are placed
# and the old paths are gone. Asserting only "no failure row" passes on a loop that
# ran zero times.
#
# It also completes case 6's pair. Same tree, same undeclared third validator, same
# unchanged-in-range range -- and under the glob it MUST be relocated, because the
# manifest now claims the directory it sits in. Case 6 requires it left alone under a
# literal list; this requires it carried under the glob. Only the manifest shape
# differs, so together they pin which source the loop reads.
cat > "$RECON/setup-sites.md" <<'SITES'
```yaml
core_manifest:
  - core/scripts/ai-dlc/*
```
SITES
rm -rf "$CONSUMER/scripts/ai-dlc"
for f in validate-untouched.sh validate-edited.sh validate-undeclared.sh; do
  cp "$DIST/core/scripts/$f" "$CONSUMER/scripts/$f"
done
printf 'version: 1.0.0\ncommit: %s\n' "$BASE2" > "$CONSUMER/.claude/.ai-dlc-version"
OUT7="$(bash "$APPLY" "$DIST" "$BASE2" "$CONSUMER" "$THEIRS2" 2>&1)"

placed=0; missing=""
for f in validate-untouched.sh validate-edited.sh validate-undeclared.sh; do
  if [ -f "$CONSUMER/scripts/ai-dlc/$f" ]; then placed=$((placed+1)); else missing="$missing $f"; fi
done
if [ "$placed" -eq 3 ]; then
  ok "the glob entry is expanded to its members: all 3 placed at scripts/ai-dlc/"
else
  bad "the glob entry placed only $placed of 3 --$missing left behind; manifest_dests read it literally"
  printf '%s\n' "$OUT7" | sed 's/^/        /'
fi
left=""
for f in validate-untouched.sh validate-edited.sh validate-undeclared.sh; do
  [ -f "$CONSUMER/scripts/$f" ] && left="$left $f"
done
[ -z "$left" ] && ok "  and every old path is emptied" \
              || bad "  copies remain at the old path:$left -- the move ran zero times"
if [ -f "$CONSUMER/scripts/ai-dlc/validate-undeclared.sh" ]; then
  ok "  the validator case 6 requires LEFT ALONE under a literal list is CARRIED under the glob"
else
  bad "  validate-undeclared.sh was not carried -- the glob is not claiming the whole directory"
fi
if grep -q 'manifest-unreadable' <<<"$OUT7"; then
  bad "  the shipped glob form was reported unreadable -- manifest_dests cannot parse what ships"
else
  ok "  and no manifest-unreadable row is raised for the form that actually ships"
fi

# --- 12. BL-099: THE EXEC-BIT AUDIT READS BOTH DIRECTIONS ---------------------------------------
# The audit kept 100755 alone, so a path upstream ships 100644 whose consumer copy IS executable
# was never reported -- a bit left by an earlier pull stays forever. Three seeds, ONE world, each
# a different file so every cell is read off the same run:
#   (i)   m-exec.sh   100644, consumer +x       -> named under `extra-executable`, stamp withheld
#   (ii)  m-plain.sh  100644, consumer not +x   -> named in NO DECISION row (the near-miss a fix
#                                                  testing only "not executable" would name)
#   (iii) validate-x.sh 100755, consumer -x     -> still named under `not-executable`
# And (r): every exec-bit row's remedy is the union gate's own procedure, interpolated with this
# run's arguments -- never a bare "re-run", which that gate refuses once this run has written.
# OWN DIST, so cases 1-11 keep theirs. Mutants: XE-M1..M5 below.
X_ISDIST=0; [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ] && X_ISDIST=1
X_RUN=1
if ! grep -qF 'say DECISION extra-executable' "$APPLY"; then
  if [ "$X_ISDIST" = 1 ]; then
    printf '  --    (BL-099: this apply.sh carries no extra-executable row; in the distribution case 12 runs anyway and must go red)\n'
  else
    X_RUN=0
    printf '  SKIP  %s\n' "case 12 (BL-099) -- the installed apply.sh predates the mirror exec-bit arm; it lands with the pull that carries this fixture"
  fi
fi
if [ "$X_RUN" = 1 ]; then
  XD="$WORK/x-dist"
  mkdir -p "$XD/core/scripts" "$XD/core/session-driver" || exit 2
  xg() { git -C "$XD" -c user.email=f@f -c user.name=fixture "$@"; }
  printf '#!/usr/bin/env bash\necho x\n' > "$XD/core/scripts/validate-x.sh"; chmod +x "$XD/core/scripts/validate-x.sh"
  for f in m-exec m-plain m-moved; do printf '#!/usr/bin/env bash\n# %s v1\n' "$f" > "$XD/core/session-driver/$f.sh"; done
  printf '1.0.0\n' > "$XD/VERSION"
  git -C "$XD" init -q 2>/dev/null && xg add -A && xg commit -qm base || { echo "FIXTURE ERROR: case 12 base" >&2; exit 2; }
  XB="$(git -C "$XD" rev-parse HEAD)"
  printf '2.0.0\n' > "$XD/VERSION"; printf '#!/usr/bin/env bash\n# m-moved v2\n' > "$XD/core/session-driver/m-moved.sh"
  xg add -A && xg commit -qm theirs || { echo "FIXTURE ERROR: case 12 theirs" >&2; exit 2; }
  XT="$(git -C "$XD" rev-parse HEAD)"
  # x_vec <apply.sh> -> "i ii iii r" (1 = holds); one fresh consumer per call.
  x_vec() {
    local c o v="" d
    c="$(mktemp -d "$WORK/x.XXXXXX")" || { printf 'BROKEN'; return; }
    mkdir -p "$c/.claude/session-driver" "$c/scripts/ai-dlc"
    cp "$XD/core/scripts/validate-x.sh" "$c/scripts/ai-dlc/validate-x.sh"; chmod -x "$c/scripts/ai-dlc/validate-x.sh"
    for f in m-exec m-plain m-moved; do git -C "$XD" show "${XB}:core/session-driver/$f.sh" > "$c/.claude/session-driver/$f.sh"; done
    chmod +x "$c/.claude/session-driver/m-exec.sh"; chmod -x "$c/.claude/session-driver/m-plain.sh"
    printf 'version: 1.0.0\ncommit: %s\n' "$XB" > "$c/.claude/.ai-dlc-version"
    o="$(bash "$1" "$XD" "$XB" "$c" "$XT" 2>/dev/null)"
    printf '%s\n' "$o" > "$c/.rows"
    if awk -F'\t' '$1=="DECISION" && $2=="extra-executable" && $3==".claude/session-driver/m-exec.sh" {f=1} END {exit !f}' <<<"$o" \
       && grep -q '^DECISION	restamp-withheld' <<<"$o" && grep -q '^version: 1\.0\.0$' "$c/.claude/.ai-dlc-version"; then
      v=1; else v=0; fi
    if ! awk -F'\t' '$1=="DECISION" && index($3, "m-plain.sh") {f=1} END {exit !f}' <<<"$o" \
       && grep -q '^DECISION	' <<<"$o"; then v="$v 1"; else v="$v 0"; fi
    if awk -F'\t' '$1=="DECISION" && $2=="not-executable" && $3=="scripts/ai-dlc/validate-x.sh" {f=1} END {exit !f}' <<<"$o"; then
      v="$v 1"; else v="$v 0"; fi
    # (r) every exec-bit row, by kind, carries the procedure with THIS run's four arguments.
    d=1
    for k in not-executable extra-executable declared-not-executable; do
      awk -F'\t' -v k="$k" '$1=="DECISION" && $2==k {f=1} END {exit !f}' <<<"$o" || continue
      awk -F'\t' -v k="$k" -v w="emit-report.sh $XD $XB $c $XT" '$1=="DECISION" && $2==k && index($4, w) && index($4, "re-approve it, then re-run apply") {f=1} END {exit !f}' <<<"$o" || d=0
      awk -F'\t' -v k="$k" '$1=="DECISION" && $2==k && $4 ~ /and re-run[.;]/ {f=1} END {exit !f}' <<<"$o" && d=0
    done
    printf '%s %s' "$v" "$d"
  }
  X_WANT="1 1 1 1"
  XV="$(x_vec "$APPLY")"
  set -- $XV
  [ "${1:-0}" = 1 ] && ok "case 12 (i): a 100644 file the consumer holds executable is named under extra-executable and the re-stamp is withheld" \
                    || bad "case 12 (i): an executable copy of a 100644 file was not reported, or the stamp advanced over it ($XV)"
  [ "${2:-0}" = 1 ] && ok "case 12 (ii): a non-executable 100644 sibling is named in no DECISION row" \
                    || bad "case 12 (ii): a correctly non-executable 100644 file was reported -- the mirror arm names every 100644 file ($XV)"
  [ "${3:-0}" = 1 ] && ok "case 12 (iii): a 100755 file left -x is still named under not-executable" \
                    || bad "case 12 (iii): the original direction stopped firing ($XV)"
  [ "${4:-0}" = 1 ] && ok "case 12 (r): every exec-bit row names re-render/re-approve/apply with this run's arguments, and none ends in a bare re-run" \
                    || bad "case 12 (r): an exec-bit row still prescribes a bare re-run, which the union gate refuses after this run has written ($XV)"
  set --
  # CONTROL: an unmutated copy of the reconcile dir scores the same vector.
  XC="$WORK/x-ctl"; mkdir -p "$XC" && cp "$RECON"/* "$XC"/ 2>/dev/null
  XCV="$(x_vec "$XC/apply.sh")"
  [ "$XCV" = "$X_WANT" ] && ok "case 12 CONTROL: an unmutated copy scores $XCV" \
                         || bad "case 12 CONTROL: the unmutated copy scored '$XCV', want '$X_WANT' -- every mutant below is unreadable"
  # x_mut <label> <anchor> <replacement> <want> <what> -- a copy of the whole reconcile dir.
  x_mut() {
    local d="$WORK/x-$1" n
    n="$(grep -cF -- "$2" "$APPLY")" || n=0
    if [ "$n" != 1 ]; then bad "$1 DID NOT APPLY -- \`$2\` is not in apply.sh exactly once"; return; fi
    mkdir -p "$d" && cp "$RECON"/* "$d"/ 2>/dev/null
    X_A="$2" X_R="$3" awk '{ i = index($0, ENVIRON["X_A"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["X_R"] substr($0, i + length(ENVIRON["X_A"])); print }' "$APPLY" > "$d/apply.sh"
    if cmp -s "$APPLY" "$d/apply.sh" || ! bash -n "$d/apply.sh"; then bad "$1 DID NOT APPLY or does not parse"; return; fi
    local v; v="$(x_vec "$d/apply.sh")"
    if [ "$v" = "$4" ]; then ok "$1 ($5): vector i ii iii r = $v -- killed exactly its arms"
    elif [ "$v" = "$X_WANT" ]; then bad "$1 SURVIVED ($5)"
    else bad "$1 ($5) scored $v, want $4"; fi
  }
  # M1 is b177's wrong fix 1: every non-executable file named, whatever its mode.
  x_mut XE-M1 'if [ "$mode" = 100755 ] && [ ! -x "$cons" ]; then' 'if [ ! -x "$cons" ]; then' "1 0 1 1" "the 100755 conjunct dropped (names every non-exec file)"
  # M2 is wrong fix 2: the mirror's exec test inverted.
  x_mut XE-M2 'elif [ "$mode" = 100644 ] && [ -x "$cons" ]; then' 'elif [ "$mode" = 100644 ] && [ ! -x "$cons" ]; then' "0 0 1 1" "the mirror test inverted"
  x_mut XE-M3 'elif [ "$mode" = 100644 ] && [ -x "$cons" ]; then' 'elif false; then' "0 1 1 1" "the mirror arm removed"
  x_mut XE-M4 'if [ "$mode" = 100755 ] && [ ! -x "$cons" ]; then' 'if false; then' "1 1 0 1" "the original direction removed"
  x_mut XE-M5 'installed and inert. \`chmod +x\` it, then ${reapply_remedy}"' 'installed and inert. \`chmod +x\` and re-run."' "1 1 1 0" "declared-not-executable's bare re-run restored"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "apply-legacy-script-path: PASS"
  exit 0
fi
echo "apply-legacy-script-path: FAIL ($fails assertion(s))"
exit 1
