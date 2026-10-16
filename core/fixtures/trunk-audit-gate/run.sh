#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# trunk-audit-gate — prove gate Check 36 re-runs the step-1b trunk audit and maps every exit
# the audit emits to the right gate verdict.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT. carry-over-evaluation.md step 1b makes `--audit-trunk` exit 1 a HARD_BLOCK, and
# no gate check read the result. On the reference consumer the result landed nowhere a gate
# reads: two sprints that ran the audit clean left no line in their artifact, so a check keyed
# on artifact text would fail them, and the watermark file is gitignored. Check 36 re-runs.
#
# WORLDS (each its own scratch repo, a trunk named main, a taxonomy with one passing and one
# failing validator):
#   clean      a commit whose class validator passes          -> exit 0, PASS
#   finding    a commit whose class validator fails           -> exit 1, FAIL (findings)
#   empty      nothing reached the trunk since the watermark  -> exit 0, PASS + control line
#   worklist   the contract declares no PR-class file         -> exit 0, WORKLIST (not a FAIL)
#   nogenesis  carry-over, no watermark                       -> exit 2, setup error, NOT shallow
#   nobmad     no _bmad-output/ at all                        -> exit 2, no snapshot
#   feature    pipeline_variant: feature, no watermark        -> exit 0, NOT-APPLICABLE
#   anchors    carry-over, no watermark; audit-anchors.md in the shape retro.md step 5b
#              writes (rendered header, sprint/sha/closed_at, NO audit_window) behind a
#              decoy entry whose sha resolves to nothing    -> exit 0, PASS from sprint 6's sha
#   wedge-*    a finding, then a fix-forward commit. The audit stops at the finding, so
#              without an exit route every later gate FAILS:
#     wedge-resolved  the finding's sha is named by an operator-RESOLVED escalation entry,
#                     filed in pending-archive.md where retro close moves it -> exit 0, PASS
#     wedge-noexit    the entry naming the sha is still HARD_BLOCK in pending.md -> exit 1
#     wedge-othersha  a RESOLVED, cited entry names a DIFFERENT sha             -> exit 1
#   shallow    a `git clone --depth 1` whose watermark names an unfetched commit -> exit 2,
#              the message names the shallow history and `git fetch --unshallow`
# Every arm is PRESENCE-shaped: it requires a specific verdict line, so a subject that prints
# nothing fails all of them. Mutants M1-M12 follow, each run against a whole copy of the
# subject and its sibling scripts, behind an unmutated control.

set -uo pipefail
# The gate inherits every AI_DLC_* a consumer set; AI_DLC_TRUNK alone would re-point the audit.
unset AI_DLC_TRUNK AI_DLC_PROJECT_ROOT AI_DLC_TAG_SUBJECT AI_DLC_AUDIT_ANCHORS_SCHEMA 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-trunk-audit-gate.sh" ]; then
  SUBJ="$ROOT/core/scripts/validate-trunk-audit-gate.sh"
  SCHEMA="$ROOT/core/schemas/audit-anchors.json"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-trunk-audit-gate.sh" ]; then
  SUBJ="$ROOT/scripts/ai-dlc/validate-trunk-audit-gate.sh"
  SCHEMA="$ROOT/.claude/schemas/audit-anchors.json"
else
  echo "FIXTURE ERROR: validate-trunk-audit-gate.sh not found in either layout" >&2; exit 2
fi
SUBJ_DIR="$(dirname "$SUBJ")"
SIBS="validate-cycle-commits.sh validate-audit-anchors.sh validate-escalation-resolution.sh"
for s in $SIBS; do
  [ -f "$SUBJ_DIR/$s" ] || { echo "FIXTURE ERROR: $s is not beside $SUBJ" >&2; exit 2; }
done
[ -f "$SCHEMA" ] || { echo "FIXTURE ERROR: audit-anchors.json not found at $SCHEMA" >&2; exit 2; }
echo "HERMETIC-CONSUMED $SUBJ"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

G() { git -C "$1" -c user.email=f@x -c user.name=F -c commit.gpgsign=false "${@:2}"; }

# $1 dir, $2 variant ("" = no _bmad-output/ at all), $3 "declared"|"predates", $4 "wm"|"nowm"
mkworld() {
  local d="$1" variant="$2" decl="$3" wm="$4"
  mkdir -p "$d/.claude/skills/ai-dlc" "$d/validators"
  if [ "$decl" = "predates" ]; then
    printf 'contract_version: 13\n' > "$d/.claude/skills/ai-dlc/layer-contract.yaml"
  else
    printf 'contract_version: 13\nconsumer_pr_class_file: .claude/skills/ai-dlc/pr-classes.md\n' \
      > "$d/.claude/skills/ai-dlc/layer-contract.yaml"
    printf 'x\n```\nclass: code\npaths: ^src/\nvalidator: validators/ok.sh\n\nclass: bad\npaths: ^broken/\nvalidator: validators/bad.sh\n```\n' \
      > "$d/.claude/skills/ai-dlc/pr-classes.md"
  fi
  printf '#!/bin/sh\nexit 0\n' > "$d/validators/ok.sh";  chmod +x "$d/validators/ok.sh"
  printf '#!/bin/sh\nexit 1\n' > "$d/validators/bad.sh"; chmod +x "$d/validators/bad.sh"
  git init -q "$d" >/dev/null 2>&1
  git -C "$d" symbolic-ref HEAD refs/heads/main
  G "$d" add .claude validators >/dev/null 2>&1
  G "$d" commit -q -m genesis >/dev/null 2>&1
  # _bmad-output/ and docs/escalations/ stay UNTRACKED here, so no audited commit touches them.
  if [ -n "$variant" ]; then
    mkdir -p "$d/_bmad-output"
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n- sprint_id: 7\n- pipeline_variant: %s\n' \
      "$variant" > "$d/_bmad-output/pipeline-snapshot.md"
    [ "$wm" = "wm" ] && git -C "$d" rev-parse HEAD > "$d/_bmad-output/.audit-watermark"
  fi
  return 0
}
commit_under() { # $1 dir, $2 subdir
  mkdir -p "$1/$2"; printf 'x\n' > "$1/$2/f.txt"
  G "$1" add "$2" >/dev/null 2>&1; G "$1" commit -q -m "change in $2" >/dev/null 2>&1
}
# An escalation entry in the shape escalations.md documents. $1 file, $2 status, $3 sha named,
# $4 "cite"|"nocite"
esc_entry() {
  mkdir -p "$(dirname "$1")"
  {
    printf '## S7-TRUNK-AUDIT lead - 2026-10-16\n'
    printf '**Status:** %s\n' "$2"
    printf '**Blocker type:** contradicts decision\n'
    printf '**Context:** step 1b trunk audit FAIL at %s (bad class validator).\n' "$3"
    printf '**Evidence observed:** audit-trunk exit 1, FAIL %s.\n' "$3"
    printf '**Assertion (beyond evidence):** none — assertion equals evidence.\n'
    printf '**Decision/Question:** accept the fix-forward that follows it?\n'
    [ "$4" = "cite" ] && printf '**Operator authorization:** 2026-10-16T10:00:00Z | "accept the fix-forward for that trunk finding"\n'
    printf '\n'
  } >> "$1"
}

W="$WORK/w"
mkworld "$W/clean"     carry-over declared wm;   commit_under "$W/clean" src
mkworld "$W/finding"   carry-over declared wm;   commit_under "$W/finding" broken
mkworld "$W/empty"     carry-over declared wm
mkworld "$W/worklist"  carry-over predates nowm; commit_under "$W/worklist" src
mkworld "$W/nogenesis" carry-over declared nowm; commit_under "$W/nogenesis" src
mkworld "$W/nobmad"    ""         declared nowm; commit_under "$W/nobmad" src
mkworld "$W/feature"   feature    declared nowm; commit_under "$W/feature" src

# anchors: a fresh clone (no watermark) whose genesis is the PRIOR sprint's (6) required `sha`.
# Seeded as retro.md step 5b writes the file: the rendered schema header, `## Entries`, and
# entries carrying sprint, sha and closed_at only. The sprint-5 decoy sits FIRST with a sha
# that resolves to nothing, so a reader taking the wrong entry exits 2.
mkworld "$W/anchors"   carry-over declared nowm
AG="$(git -C "$W/anchors" rev-parse HEAD)"
commit_under "$W/anchors" src
AA="$W/anchors/_bmad-output/audit-anchors.md"
AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" bash "$SUBJ_DIR/validate-audit-anchors.sh" --render > "$AA" 2>/dev/null \
  || { echo "FIXTURE BROKEN: validate-audit-anchors.sh --render failed" >&2; exit 2; }
printf -- '\n## Entries\n\n- sprint: 5\n  sha: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n  closed_at: 2026-10-07\n- sprint: 6\n  sha: %s\n  closed_at: 2026-10-14\n' \
  "$AG" >> "$AA"

# wedge-*: genesis, a FINDING (broken/), then a fix-forward (src/, clean).
for w in wedge-resolved wedge-noexit wedge-othersha; do
  mkworld "$W/$w" carry-over declared wm
  commit_under "$W/$w" broken
  git -C "$W/$w" rev-parse HEAD > "$W/$w/.bad-sha"
  commit_under "$W/$w" src
done
BAD_R="$(cut -c1-12 "$W/wedge-resolved/.bad-sha")"
BAD_N="$(cut -c1-12 "$W/wedge-noexit/.bad-sha")"
esc_entry "$W/wedge-resolved/docs/escalations/pending-archive.md" RESOLVED "$BAD_R" cite
esc_entry "$W/wedge-noexit/docs/escalations/pending.md" HARD_BLOCK "$BAD_N" nocite
esc_entry "$W/wedge-othersha/docs/escalations/pending.md" RESOLVED "0123456789ab" cite

# shallow: a depth-1 clone of a two-commit repo. Its watermark names the genesis commit, which
# the clone never fetched, so the audit exits 2 for a reason no anchor edit can fix.
mkworld "$WORK/shallow-src" "" declared nowm; commit_under "$WORK/shallow-src" src
git clone -q --depth 1 "file://$WORK/shallow-src" "$W/shallow" >/dev/null 2>&1 \
  || { echo "FIXTURE BROKEN: git clone --depth 1 failed" >&2; exit 2; }
git -C "$W/shallow" branch -m main >/dev/null 2>&1 || true
mkdir -p "$W/shallow/_bmad-output"
printf '# Pipeline Snapshot\n\n## Pipeline Position\n- sprint_id: 7\n- pipeline_variant: carry-over\n' \
  > "$W/shallow/_bmad-output/pipeline-snapshot.md"
git -C "$WORK/shallow-src" rev-parse HEAD~1 > "$W/shallow/_bmad-output/.audit-watermark"

# Seed sanity: without these every arm below compares against a world nobody built.
for w in clean finding empty worklist nogenesis nobmad feature anchors wedge-resolved wedge-noexit wedge-othersha shallow; do
  [ "$(git -C "$W/$w" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "main" ] \
    || { echo "FIXTURE BROKEN: world $w has no main trunk" >&2; exit 2; }
done
[ ! -e "$W/nobmad/_bmad-output" ] || { echo "FIXTURE BROKEN: nobmad carries _bmad-output/" >&2; exit 2; }
[ -s "$W/clean/_bmad-output/.audit-watermark" ] || { echo "FIXTURE BROKEN: clean has no watermark" >&2; exit 2; }
[ "$(git -C "$W/shallow" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ] \
  || { echo "FIXTURE BROKEN: shallow is not a shallow clone" >&2; exit 2; }
[ "$(git -C "$W/nogenesis" rev-parse --is-shallow-repository 2>/dev/null)" = "false" ] \
  || { echo "FIXTURE BROKEN: nogenesis is shallow, so it is no near-miss for shallow" >&2; exit 2; }
! grep -q '^  sha: ' "$AA" && { echo "FIXTURE BROKEN: anchors seeds no sha entry field" >&2; exit 2; }
grep -q '^  audit_window:' "$AA" \
  && { echo "FIXTURE BROKEN: anchors seeds an audit_window entry field, which step 5b never writes" >&2; exit 2; }
AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" bash "$SUBJ_DIR/validate-audit-anchors.sh" "$AA" >/dev/null 2>&1 \
  || { echo "FIXTURE BROKEN: the anchors seed fails the producer-side validate-audit-anchors.sh check" >&2; exit 2; }

OUT=""; RC=""
# Not a command substitution at the call site: OUT and RC must reach the caller.
drive() { # $1 subject script, $2 world dir. A fresh copy of the world per drive: the audit
          # advances the watermark, so a second drive of one world would audit an empty range.
  local cp="$WORK/run.$$.$RANDOM"
  rm -rf "$cp"; cp -R "$2" "$cp"
  OUT="$(AI_DLC_PROJECT_ROOT="$cp" AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" bash "$1" --sprint 7 2>&1)"; RC=$?
  rm -rf "$cp"
}
has() { grep -qF -- "$1" <<< "$OUT"; }

# expect <subject> <world> <rc> <required verdict text> <label>
expect() {
  drive "$1" "$W/$2"
  if [ "$RC" = "$3" ] && has "$4"; then return 0; fi
  LAST="world $2: exit $RC (want $3), verdict: $(printf '%s\n' "$OUT" | grep '^verdict' | head -1)"
  return 1
}

echo "trunk-audit-gate:"

expect "$SUBJ" clean 0 'verdict  : PASS' && has 'audit_rc : 0' && has 'AUDIT-TRUNK: audited=1 ' \
  && ok "clean: the audit re-ran 1 commit at the gate -> PASS" || bad "clean: $LAST"
expect "$SUBJ" finding 1 'reported findings' && has 'audit_rc : 1' && has 'findings=1' \
  && ok "finding: audit exit 1 -> gate FAIL exit 1, HARD_BLOCK named" || bad "finding: $LAST"
expect "$SUBJ" empty 0 'verdict  : PASS' && has 'control: the trunk holds' \
  && ok "empty range: PASS carries the audit's own control line" || bad "empty: $LAST"
expect "$SUBJ" worklist 0 'verdict  : WORKLIST' && has 'AUDIT-TRUNK: WORKLIST' \
  && ok "worklist: undeclared taxonomy -> WORKLIST, exit 0, not a FAIL" || bad "worklist: $LAST"
expect "$SUBJ" nogenesis 2 'could not run (setup error)' && has 'audit_rc : 2' && ! has 'SHALLOW' \
  && ok "nogenesis: audit exit 2 -> gate FAIL exit 2, not a clean result, not called shallow" || bad "nogenesis: $LAST"
expect "$SUBJ" nobmad 2 'no readable pipeline snapshot' \
  && ok "no _bmad-output/: exit 2, no verdict about nothing" || bad "nobmad: $LAST"
expect "$SUBJ" feature 0 'NOT-APPLICABLE -- EXAMINED NOTHING' && ! has 'audit_rc' \
  && ok "feature variant: NOT-APPLICABLE, audit not run, no watermark needed" || bad "feature: $LAST"
expect "$SUBJ" anchors 0 'verdict  : PASS' && has "audit-anchors.md prior-sprint sha (${AG})" \
  && has 'AUDIT-TRUNK: audited=1 ' \
  && ok "anchors: no watermark, genesis from the prior sprint's required sha, no audit_window -> PASS" \
  || bad "anchors: $LAST"
expect "$SUBJ" wedge-resolved 0 'verdict  : PASS' && has "exit     : ${BAD_R}" && has 'findings=1' \
  && has 'AUDIT-TRUNK: audited=1 ' \
  && ok "wedge-resolved: finding -> fix-forward -> operator-RESOLVED entry names the sha -> PASS" \
  || bad "wedge-resolved: $LAST"
expect "$SUBJ" wedge-noexit 1 'reported findings' && has 'an escalation names' \
  && ok "wedge-noexit: fix-forward with the entry still HARD_BLOCK -> still FAIL" \
  || bad "wedge-noexit: $LAST"
expect "$SUBJ" wedge-othersha 1 'reported findings' && has 'no escalation entry names' \
  && ok "wedge-othersha: a resolved entry naming another sha is not an exit -> still FAIL" \
  || bad "wedge-othersha: $LAST"
expect "$SUBJ" shallow 2 'SHALLOW clone' && has 'git fetch --unshallow' && ! has 'setup error' \
  && ok "shallow: exit 2 names the shallow history and git fetch --unshallow" || bad "shallow: $LAST"

# ---- mutants: each a whole copy of the subject's directory with every sibling -----------------
# mkmut <name> <sed expr>: prints the mutated subject path; refuses a sed that changed nothing.
mkmut() {
  local d="$WORK/mut-$1" s
  mkdir -p "$d"
  for s in $SIBS; do cp "$SUBJ_DIR/$s" "$d/"; done
  if ! sed -e "$2" "$SUBJ" > "$d/validate-trunk-audit-gate.sh" 2>/dev/null; then
    echo "MUTANT $1 DID NOT APPLY (sed failed)" >&2; return 1
  fi
  if cmp -s "$SUBJ" "$d/validate-trunk-audit-gate.sh"; then
    echo "MUTANT $1 DID NOT APPLY (no change)" >&2; return 1
  fi
  printf '%s\n' "$d/validate-trunk-audit-gate.sh"
}
# Control: an unmutated copy built the same way must pass the worlds whose arms need the
# siblings, positively -- a copy missing one would read every mutant below as killed.
CTRL="$WORK/mut-ctrl"; mkdir -p "$CTRL"
cp "$SUBJ" "$CTRL/"; for s in $SIBS; do cp "$SUBJ_DIR/$s" "$CTRL/"; done
expect "$CTRL/validate-trunk-audit-gate.sh" clean 0 'verdict  : PASS' && has 'AUDIT-TRUNK: audited=1 ' \
  && ok "control: an unmutated copy passes the clean world" \
  || bad "control: an unmutated copy did not pass the clean world ($LAST) -- the mutants below prove nothing"
expect "$CTRL/validate-trunk-audit-gate.sh" anchors 0 'verdict  : PASS' && has 'prior-sprint sha' \
  && ok "control: an unmutated copy resolves the anchors genesis" \
  || bad "control: an unmutated copy did not pass the anchors world ($LAST)"
expect "$CTRL/validate-trunk-audit-gate.sh" wedge-resolved 0 'verdict  : PASS' && has "exit     : ${BAD_R}" \
  && ok "control: an unmutated copy takes the resolved-escalation exit" \
  || bad "control: an unmutated copy did not pass the wedge-resolved world ($LAST)"

# kill <name> <sed> <world> <rc> <verdict text>: the mutant must FAIL the arm that owns it.
killed() {
  local m
  m="$(mkmut "$1" "$2")" || { bad "mutant $1 did not apply"; return; }
  if expect "$m" "$3" "$4" "$5"; then
    bad "mutant $1 SURVIVED: world $3 still read exit $4 with '$5'"
  else
    ok "mutant $1 killed by world $3 ($LAST)"
  fi
}
killed M1-exit1-is-pass 's/^case "\$RC" in$/case "$((RC==1?0:RC))" in/' finding 1 'reported findings'
killed M2-exit2-is-pass 's/^case "\$RC" in$/case "$((RC==2?0:RC))" in/' nogenesis 2 'could not run (setup error)'
killed M3-worklist-fails 's/"AUDIT-TRUNK: WORKLIST"\*)/"AUDIT-TRUNK: NEVER"*)/' worklist 0 'verdict  : WORKLIST'
killed M4-no-variant-scope 's/if \[ "\$VARIANT" != "carry-over" \]; then/if false; then/' feature 0 'NOT-APPLICABLE'
killed M5-subject-silent '2i\
exit 0' clean 0 'verdict  : PASS'
killed M6-no-anchors-fallback 's/^      RUN_GENESIS="\$G_SHA"$/      RUN_GENESIS=""/' anchors 0 'verdict  : PASS'
killed M7-wrong-anchor-entry 's/--prior-sprint-sha "\$ANCHORS" "\$SPRINT"/--prior-sprint-sha "$ANCHORS" "$((SPRINT-1))"/' anchors 0 'verdict  : PASS'
killed M8-no-exit-route 's/^  F_SHA="\$(first_fail_sha "\$OUT")"$/  F_SHA=""/' wedge-resolved 0 'verdict  : PASS'
killed M9-unresolved-is-exit 's/^  if \[ "\$AUTH_RC" -ne 0 \]; then$/  if false; then/' wedge-noexit 1 'reported findings'
killed M10-any-entry-names-sha 's/if (length(t) >= 7 \&\& index(sha, t) == 1) hit = 1/hit = 1/' wedge-othersha 1 'reported findings'
killed M11-no-archive 's@ "\$ESC_DIR/pending-archive.md"; do$@; do@' wedge-resolved 0 'verdict  : PASS'
killed M12-shallow-unnamed 's/if \[ "\$(git -C "\$AI_DLC_ROOT" rev-parse --is-shallow-repository 2>\/dev\/null)" = "true" \]; then/if false; then/' shallow 2 'SHALLOW clone'

echo
if [ "$fails" -eq 0 ]; then
  echo "trunk-audit-gate: PASS"
  exit 0
fi
echo "trunk-audit-gate: $fails FAILED"
exit 1
