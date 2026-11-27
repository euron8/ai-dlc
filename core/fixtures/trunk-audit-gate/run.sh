#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# nothing fails all of them.

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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# IN PROCESS WHERE IT CAN BE (BL-878). A gate run that reaches the audit starts its siblings
# (validate-cycle-commits.sh, validate-audit-anchors.sh, validate-escalation-resolution.sh) as separate programs, and
# a `nested` row covers such a child only when its logged parent is the gate. Every world's gate drive and the two
# validate-audit-anchors.sh seed calls run in process through core/fixtures/lib/inproc.sh inproc_run (never
# inproc_load: two subjects are driven, and a loaded one would log every pass under its own path); each gate drive
# logs an #inproc parent marker naming the gate first (drv_mark), so the three `nested` rows cover the sibling starts.
# The gate's three cli cells compare three worlds' in-process answers with the program's. A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECTS: a subject with neither its `<p>_main() {` line nor the
# column-0 source guard predates the wrap and reads SKIP through fx_skip_exit (exit 0 on a consumer, never an ok;
# FIXTURE BROKEN in the distribution); exactly one half FAILs; an unreadable one is FIXTURE ERROR.
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
wrap_gate() { # <subject> <entry>
  local _wd _wg
  grep -q "^$2() {\$" "$1"; _wd=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; _wg=$?
  if [ "$_wd" -gt 1 ] || [ "$_wg" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $_wd/$_wg), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2
  fi
  case "$_wd$_wg" in
    00) ;;
    11) echo "SKIP: subject $1 predates the in-process wrap"; fx_skip_exit "$HERE" ;;
    10) echo "  FAIL $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; echo "trunk-audit-gate: FAIL (1 assertion(s))"; exit 1 ;;
    *) echo "  FAIL $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"; echo "trunk-audit-gate: FAIL (1 assertion(s))"; exit 1 ;;
  esac
}
wrap_gate "$SUBJ" vtag_main
wrap_gate "$SUBJ_DIR/validate-audit-anchors.sh" vaa_main
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }


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
  printf '#!/bin/bash\nexit 0\n' > "$d/validators/ok.sh";  chmod +x "$d/validators/ok.sh"
  printf '#!/bin/bash\nexit 1\n' > "$d/validators/bad.sh"; chmod +x "$d/validators/bad.sh"
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
AI_DLC_PROJECT_ROOT="$W/anchors" AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" inproc_run "$SUBJ_DIR/validate-audit-anchors.sh" vaa_main --render > "$AA" 2>/dev/null \
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
AI_DLC_PROJECT_ROOT="$W/anchors" AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" inproc_run "$SUBJ_DIR/validate-audit-anchors.sh" vaa_main "$AA" >/dev/null 2>&1 \
  || { echo "FIXTURE BROKEN: the anchors seed fails the producer-side validate-audit-anchors.sh check" >&2; exit 2; }
# Printed only past the check above, which ran the validator on the schema's rendered header.
echo "HERMETIC-CONSUMED $SUBJ_DIR/validate-audit-anchors.sh"
echo "HERMETIC-CONSUMED $SCHEMA"

OUT=""; RC=""
# Every drive is an in-process pass, and a pass that reaches the audit starts the gate's siblings as children. drv_mark,
# called inside the pass's own $( ) under a counted run, appends one `#inproc` row to the start log (id i<fixture pid>.<n>,
# the previous FXCOUNT_PARENT, the gate's path) and exports FXCOUNT_PARENT as that id, so each sibling's start names the
# pass as its parent and the nested rows in cells.decl cover it; the export dies with the $( ).
DPN=0
drv_mark() {
  [ -n "${FXCOUNT_LOG:-}" ] || return 0
  printf '#inproc\t%s\t\t%s\t%s\n' "i$$.$DPN" "${FXCOUNT_PARENT:-}" "$SUBJ" 2>/dev/null >> "$FXCOUNT_LOG" || :
  export FXCOUNT_PARENT="i$$.$DPN"
}
# Not a command substitution at the call site: OUT and RC must reach the caller.
drive() { # $1 world dir. A fresh copy of the world per drive: the audit advances the watermark, so a
          # second drive of one world would audit an empty range.
  local cp="$WORK/run.$$.$RANDOM"
  rm -rf "$cp"; cp -R "$1" "$cp"
  DPN=$((DPN + 1))
  OUT="$(drv_mark && AI_DLC_PROJECT_ROOT="$cp" AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" inproc_run "$SUBJ" vtag_main --sprint 7 2>&1)"; RC=$?
  rm -rf "$cp"
}
has() { grep -qF -- "$1" <<< "$OUT"; }

# expect <world> <rc> <required verdict text>
expect() {
  drive "$W/$1"
  if [ "$RC" = "$2" ] && has "$3"; then return 0; fi
  LAST="world $1: exit $RC (want $2), verdict: $(printf '%s\n' "$OUT" | grep '^verdict' | head -1)"
  return 1
}

echo "trunk-audit-gate:"

if expect clean 0 'verdict  : PASS' && has 'audit_rc : 0' && has 'AUDIT-TRUNK: audited=1 ' \
  && echo "HERMETIC-CONSUMED $SUBJ_DIR/validate-cycle-commits.sh"; then
  ok "clean: the audit re-ran 1 commit at the gate -> PASS"
else bad "clean: $LAST"; fi
if expect finding 1 'reported findings' && has 'audit_rc : 1' && has 'findings=1'; then
  ok "finding: audit exit 1 -> gate FAIL exit 1, HARD_BLOCK named"
else bad "finding: $LAST"; fi
if expect empty 0 'verdict  : PASS' && has 'control: the trunk holds'; then
  ok "empty range: PASS carries the audit's own control line"
else bad "empty: $LAST"; fi
if expect worklist 0 'verdict  : WORKLIST' && has 'AUDIT-TRUNK: WORKLIST'; then
  ok "worklist: undeclared taxonomy -> WORKLIST, exit 0, not a FAIL"
else bad "worklist: $LAST"; fi
if expect nogenesis 2 'could not run (setup error)' && has 'audit_rc : 2' && ! has 'SHALLOW'; then
  ok "nogenesis: audit exit 2 -> gate FAIL exit 2, not a clean result, not called shallow"
else bad "nogenesis: $LAST"; fi
if expect nobmad 2 'no readable pipeline snapshot'; then
  ok "no _bmad-output/: exit 2, no verdict about nothing"
else bad "nobmad: $LAST"; fi
if expect feature 0 'NOT-APPLICABLE -- EXAMINED NOTHING' && ! has 'audit_rc'; then
  ok "feature variant: NOT-APPLICABLE, audit not run, no watermark needed"
else bad "feature: $LAST"; fi
if expect anchors 0 'verdict  : PASS' && has "audit-anchors.md prior-sprint sha (${AG})" \
  && has 'AUDIT-TRUNK: audited=1 '; then
  ok "anchors: no watermark, genesis from the prior sprint's required sha, no audit_window -> PASS"
else bad "anchors: $LAST"; fi
if expect wedge-resolved 0 'verdict  : PASS' && has "exit     : ${BAD_R}" && has 'findings=1' \
  && has 'AUDIT-TRUNK: audited=1 ' \
  && echo "HERMETIC-CONSUMED $SUBJ_DIR/validate-escalation-resolution.sh"; then
  ok "wedge-resolved: finding -> fix-forward -> operator-RESOLVED entry names the sha -> PASS"
else bad "wedge-resolved: $LAST"; fi
if expect wedge-noexit 1 'reported findings' && has 'an escalation names'; then
  ok "wedge-noexit: fix-forward with the entry still HARD_BLOCK -> still FAIL"
else bad "wedge-noexit: $LAST"; fi
if expect wedge-othersha 1 'reported findings' && has 'no escalation entry names'; then
  ok "wedge-othersha: a resolved entry naming another sha is not an exit -> still FAIL"
else bad "wedge-othersha: $LAST"; fi
if expect shallow 2 'SHALLOW clone' && has 'git fetch --unshallow' && ! has 'setup error'; then
  ok "shallow: exit 2 names the shallow history and git fetch --unshallow"
else bad "shallow: $LAST"; fi

# --- the cli cells (cells.decl): the gate run as a PROGRAM, one world per distinct exit -----------------------------
# feature (exit 0, NOT-APPLICABLE), nobmad (exit 2, no snapshot) and finding (exit 1, reaches the audit). One
# `FXCELL=<id> bash "$SUBJ"` start per outcome, each compared with the in-process call on a copy of the same world at
# the same path: stdout, stderr and exit separately, byte for byte, plus the outcome's own wording; the three exits must differ.
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <world> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1" cpw="$WORK/eq.w"
  rm -rf "$cpw"; cp -R "$W/$2" "$cpw"
  DPN=$((DPN + 1))
  ( drv_mark && AI_DLC_PROJECT_ROOT="$cpw" AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" inproc_run "$SUBJ" vtag_main --sprint 7 ) \
    > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  rm -rf "$cpw"; cp -R "$W/$2" "$cpw"
  AI_DLC_PROJECT_ROOT="$cpw" AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA" FXCELL="$id" bash "$SUBJ" --sprint 7 \
    > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  rm -rf "$cpw"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
if eqv cli-feature feature && [ "$(cat "$EQ/cli-feature.cl.rc")" = 0 ] \
   && grep -qF 'NOT-APPLICABLE -- EXAMINED NOTHING' "$EQ/cli-feature.cl.out"; then
  ok "cli-feature: the program answers the feature world exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-feature: the program and the in-process call differ, or the outcome is not exit 0 NOT-APPLICABLE ($(eq_twin cli-feature))"; fi
if eqv cli-nobmad nobmad && [ "$(cat "$EQ/cli-nobmad.cl.rc")" = 2 ] \
   && grep -qF 'no readable pipeline snapshot' "$EQ/cli-nobmad.cl.out"; then
  ok "cli-nobmad: the program refuses the snapshot-less world exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-nobmad: the program and the in-process call differ, or the outcome is not exit 2 with no snapshot ($(eq_twin cli-nobmad))"; fi
if eqv cli-finding finding && [ "$(cat "$EQ/cli-finding.cl.rc")" = 1 ] \
   && grep -qF 'reported findings' "$EQ/cli-finding.cl.out"; then
  ok "cli-finding: the program fails the finding world exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-finding: the program and the in-process call differ, or the outcome is not exit 1 with findings ($(eq_twin cli-finding))"; fi
if ! cmp -s "$EQ/cli-feature.cl.rc" "$EQ/cli-nobmad.cl.rc" && ! cmp -s "$EQ/cli-feature.cl.out" "$EQ/cli-nobmad.cl.out" \
   && ! cmp -s "$EQ/cli-finding.cl.rc" "$EQ/cli-feature.cl.rc" && ! cmp -s "$EQ/cli-finding.cl.rc" "$EQ/cli-nobmad.cl.rc"; then
  ok "cli cells discriminate: the feature, snapshot-less and finding worlds give different exits"
else bad "cli cells do not discriminate: two of cli-feature, cli-nobmad and cli-finding gave the same stdout or exit"; fi


echo
report_end trunk-audit-gate
