#!/usr/bin/env bash
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
#     reference consumer had TWO edited validators that nobody noticed for months,
#     and one of them was a real fix that was never filed upstream.
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
if printf '%s' "$OUT" | grep -q 'relocate-move'; then
  ok "an identical leftover at the old path is moved and reported"
else
  bad "the identical leftover was NOT moved/reported -- the consumer keeps a silent duplicate"
fi

# --- 2. THE EDITED ONE GETS ITS OWN ROW, AND IS NAMED --------------------------
# The assertion this fixture exists for. Bundling it with the identical copies would
# invite a bulk delete, which is precisely how the local edit gets destroyed unread.
if printf '%s' "$OUT" | grep -q 'legacy-script-edited.*validate-edited\.sh'; then
  ok "the locally EDITED leftover is reported separately and by name"
else
  bad "the edited leftover was not reported on its own -- a real local change would be deleted unread"
  printf '%s\n' "$OUT" | grep -i legacy | sed 's/^/        /'
fi
if printf '%s' "$OUT" | grep 'legacy-script-duplicates' | grep -q 'validate-edited\.sh'; then
  bad "  the EDITED file was bundled with the identical ones -- a bulk delete destroys it"
else
  ok "  and it is NOT bundled with the identical ones"
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
# The edited one must have been ANNOUNCED before it went. The removal is recoverable
# from git; the silence would not have been, and this is the single most important
# thing to say in the whole migration.
if printf '%s' "$OUT" | grep -q 'legacy-script-edited.*validate-edited\.sh'; then
  ok "  and the edited one was announced by name before the move"
else
  bad "  the edited copy was removed with no mention -- a real local change vanished"
fi
# The new copy must be UPSTREAM's, not the consumer's stale edit promoted over it.
if grep -q 'LOCAL EDIT' "$CONSUMER/scripts/ai-dlc/validate-edited.sh" 2>/dev/null; then
  bad "  the edited copy was moved ON TOP of upstream's -- the new location is not THEIRS"
else
  ok "  and the new location holds upstream's content, not the edit"
fi

# --- 4. The consumer's OWN script is never mentioned ---------------------------
# The boundary must be silent on everything that is not ours, or it gets ignored.
if printf '%s' "$OUT" | grep -q 'audit-dormant-gates'; then
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
if printf '%s' "$OUT2" | grep -q 'not-executable.*validate-untouched\.sh'; then
  ok "  a non-executable shipped-755 file is reported by name"
else
  bad "  a non-executable validator was NOT reported -- inert and green, the v0.70.1 signature"
  printf '%s\n' "$OUT2" | sed 's/^/        /'
fi
if printf '%s' "$OUT2" | grep -q 'restamp-withheld'; then
  ok "  and the re-stamp is withheld"
else
  bad "  the re-stamp was written over a tree with an inert validator"
fi

# --- 6. THE RELOCATION SET IS THE MANIFEST'S, NOT THE DIRECTORY'S --------------
# `ls-tree core/scripts` yields the same set today (I5b binds them), so the only way
# to show which source drives the relocation is to make them DISAGREE: ship a third
# validator in core/scripts, present at BASE and UNCHANGED through THEIRS, and leave
# it out of the manifest.
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
if printf '%s' "$OUT4" | grep -q 'manifest-unreadable'; then
  ok "an unreadable manifest is reported, not treated as an empty relocation set"
else
  bad "an unreadable manifest relocated nothing SILENTLY -- the check-that-cannot-fire, one layer down"
fi
if printf '%s' "$OUT4" | grep -q 'restamp-withheld'; then
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
if printf '%s' "$OUT5" | grep -q 'declared-missing.*validate-untouched\.sh'; then
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
if printf '%s' "$OUT6" | grep -qE 'relocate|legacy-script|declared-'; then
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
if printf '%s' "$MOUT" | grep -q 'legacy-script'; then
  bad "MUTATION: legacy rows still emitted without the loop -- assertions 1-2 prove nothing"
else
  ok "MUTATION: disabling the legacy loop removes both rows"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "apply-legacy-script-path: PASS"
  exit 0
fi
echo "apply-legacy-script-path: FAIL ($fails assertion(s))"
exit 1
