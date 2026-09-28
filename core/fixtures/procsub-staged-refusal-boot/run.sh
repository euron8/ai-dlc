#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# procsub-staged-refusal-boot — the four BOOTSTRAPPING reconcile scripts refuse when a producer
# they read fails, where they used to read the failure as an empty input.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = an assertion failed, 2 = fixture broken.
#
# THE DEFECT. A `<( )` producer's exit status is discarded, so a producer that failed fed its
# reader an EMPTY stream and the script decided on it. In these four scripts the empty stream was
# a verdict, and at every site armed below it was the CLEAN one:
#
#   L1  ledger-reverify  receipt_absent_subjects  empty token list = "every named path exists"
#                        -> a false CLOSE-CANDIDATE, the verdict that retires a live entry
#   L2  ledger-reverify  receipt_named_subjects   empty token list = "names no subject"
#                        -> STILL-LIVE, and the NEEDS-REVIEW the split would raise goes silent
#   L3  ledger-reverify  core_map ls-tree         a PARTIAL listing passes the emptiness guard
#                        -> STILL-LIVE "consumer-owned", the bucket-2 all-clear
#   P1  preclassify      orphan-pass find         a failed walk = "no orphan here"
#                        -> rc 0 with zero O rows
#   E1  emit-report      --verify set difference  a failed want side = every approved row
#                        resolved -> exit 3 BLOCKERS-RESOLVED
#   S1  self-update-gate arm R1 comm              a failed difference = "no anchor missing"
#                        -> SELF-UPDATE-OK, record `# verdict: OK`
#   S2  self-update-gate GATING grep -Fxf         grep's exit 2 swallowed by `|| true`
#                        -> SELF-UPDATE-OK, record `# verdict: OK`
#   S3  self-update-gate changed-script git diff  a failed diff = "changes no core/scripts/ path"
#                        -> SELF-UPDATE-OK, record `# verdict: OK`
#   U1  unregistered-drift  empty scan set        grep's 1 for "no .md/.sh/.json" became the
#                        script's exit -> rc 1, which emit-report renders DETECTOR-REFUSED
#   U2  unregistered-drift  both listings fail    rc 1 with no row, where the contract is 0 always
#                        and a named HARD-DRIFT-SCAN-UNAVAILABLE row
#   U3  unregistered-drift  file-type grep exit 2 rc 2 with no row
#   U4  unregistered-drift  prefix grep exit 2    the base FELL BACK to the direct listing and
#                        scanned; the staged spelling refuses instead (safe direction, same shape
#                        at base and tip on U2b below, so U4's base shape is SCANNED)
#   U2b unregistered-drift  memo listing alone fails -- the NEAR-MISS for U2: the direct listing
#                        still answers, so the scan must still run. A refusal keyed on the memo's
#                        failure alone would pass U2 and fail here.
#   A*  apply.sh         each of the four detectors it consults, and the scan-unavailable row:
#                        a refusal (exit 2, reason on stderr) read as "found nothing" -> no row.
#                        Now a `DECISION <detector>-refused` row carrying the exit and the first
#                        stderr line; for retired-tokens the `WORKLIST semantic-merge` stands.
#
# EACH ARM IS FORCED WITH A PATH STUB, NEVER SAMPLED. The stub fails ONE call shape and execs
# the real binary for every other call, and it appends a line to its own FIRED file per call it
# claims. Every forced arm requires FIRED > 0: a stub that stopped matching the engine's call
# shape would otherwise read exactly like an engine that stopped refusing -- or, under a mutant,
# like a kill. Every forced arm is paired with a NO-STUB control over the same world, which must
# reach that world's ordinary verdict, so the world is shown to express the case before the
# forced run is read.
#
# WHY S1, S2 AND E1 FAIL THE READER AND NOT THE PRODUCER. Their `<( )` producers were the
# `printf` BUILTIN, which no PATH stub can reach. What the base spelling lost there was the
# reader's own status (`comm`'s, `grep`'s) or a `sed` running INSIDE the substitution, so those
# are what the stubs fail. E1's stub fails `norm_rows`' sed only when its input LACKS this world's
# hand-edit marker, which selects the fresh render's side (the report's side carries the marker):
# failing both sides leaves both sets empty, which reads UNDECIDED at base too and discriminates
# nothing.
#
# SHAPES, NOT PASS/FAIL. Every arm classifies its run into a named SHAPE, and the expectation
# table below names the shape the fixed code must produce (tip) and the one the base spelling
# produces (base). Run on the four scripts as they stood at the parent release, every forced arm
# reports its base shape. A MUTANT IS KILLED ONLY WHEN ITS OWN ARM REPORTS THE BASE SHAPE, never
# merely when the arm fails: every base shape is presence-shaped (a named row, a record verdict,
# exit 3, a non-O row), so a mutant copy that died on its own -- a lib.sh it could not source --
# cannot score a kill. A mutant must also leave every OTHER arm of its script at the tip shape,
# or two arms are entangled.
#
# MUTANTS restore ONE site's base block verbatim in a copy of the WHOLE reconcile/ directory
# (these scripts resolve lib.sh and each other beside themselves). Each mutation's anchors are
# counted exactly once before it is applied, the copy must differ (`cmp -s`), must parse
# (`bash -n`), and must carry the base spelling once and the staged spelling zero times.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking any reconcile script (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
# DISTRIBUTION-ONLY (see .dist-only), so one layout. The tree top is NOT spelled `$ROOT`:
# self-update-gate.sh's arm R2 scans every distribution fixture for a rulebook path beside a
# `$ROOT`-family variable and defers a pull that changes rulebook when one matches. This file names
# `skills/ai-dlc/steps/` only inside the synthetic gate worlds below, never in the live tree, so a
# match here would be a false rulebook coupling.
TREE_TOP="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
RECON="$TREE_TOP/core/skills/ai-dlc-update/reconcile"
[ -n "$TREE_TOP" ] && [ -f "$RECON/ledger-reverify.sh" ] \
  || { echo "FIXTURE ERROR: core/skills/ai-dlc-update/reconcile/ledger-reverify.sh not found — this fixture is distribution-only" >&2; exit 2; }
for _s in ledger-reverify.sh preclassify.sh emit-report.sh self-update-gate.sh lib.sh apply.sh \
          unregistered-drift.sh retired-tokens.sh retired-layer-passage.sh layer-drift.sh; do
  [ -f "$RECON/$_s" ] || { echo "FIXTURE ERROR: reconcile/$_s is missing beside ledger-reverify.sh" >&2; exit 2; }
done
SIB="$HERE/../reconcile-emit-report"
[ -f "$SIB/seed.sh" ] || { echo "FIXTURE ERROR: sibling reconcile-emit-report/seed.sh not found beside this unit" >&2; exit 2; }

REAL_TR="$(command -v tr)"; REAL_GIT="$(command -v git)"; REAL_FIND="$(command -v find)"
REAL_SED="$(command -v sed)"; REAL_COMM="$(command -v comm)"; REAL_GREP="$(command -v grep)"
REAL_BASH="$(command -v bash)"
for _b in "$REAL_TR" "$REAL_GIT" "$REAL_FIND" "$REAL_SED" "$REAL_COMM" "$REAL_GREP" "$REAL_BASH"; do
  case "$_b" in /*) ;; *) echo "FIXTURE ERROR: tr/git/find/sed/comm/grep/bash must resolve to binaries on PATH (got '$_b'), or no stub can pass through" >&2; exit 2 ;; esac
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/psb-boot.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
EW=""
trap 'rm -rf "$WORK"; [ -n "$EW" ] && rm -rf "$EW"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
echo "procsub-staged-refusal-boot:"

# --- STUBS ---------------------------------------------------------------------------------------
# stub <dir> <tool> <real-binary> <case-pattern over "$*"> <action>
# The action runs only for a call whose joined arguments match the pattern; it must log to "$F"
# itself, so a stub whose action passes through (E1's other side) logs nothing it did not fail.
stub() {
  local d="$1" t="$2" real="$3" pat="$4" act="$5"
  mkdir -p "$d"; : > "$d/FIRED"
  {
    printf '#!/bin/sh\nF="%s/FIRED"\n' "$d"
    printf 'case "$*" in\n  %s)\n    %s ;;\nesac\n' "$pat" "$act"
    printf 'exec "%s" "$@"\n' "$real"
  } > "$d/$t"
  chmod +x "$d/$t"
}
fired() { local n; n="$("$REAL_GREP" -c . "$1/FIRED" 2>/dev/null)" || n=0; printf '%s' "$n"; }
LOGF='echo "$*" >> "$F"'
# mkstub_for <arm> <dir>: the one stub each forced arm uses.
mkstub_for() {
  case "$1" in
    L1|L2) stub "$2" tr "$REAL_TR" "'-c A-Za-z0-9_./\$- '*" "$LOGF; exit 1" ;;
    L3)    stub "$2" git "$REAL_GIT" "*' ls-tree -r --name-only '*' -- core/'" \
             "$LOGF; \"$REAL_GIT\" \"\$@\" | head -n 1; exit 1" ;;
    P1)    stub "$2" find "$REAL_FIND" "*'/.claude/fixtures -type f'" "$LOGF; echo 'find: forced failure' >&2; exit 1" ;;
    E1)    stub "$2" sed "$REAL_SED" "'-E s/[[:space:]]+/ /g'" \
             "t=\"\$(mktemp)\" || exit 3; cat > \"\$t\"; if \"$REAL_GREP\" -q ZZ-PSB-HAND-EDIT \"\$t\"; then \"$REAL_SED\" \"\$@\" < \"\$t\"; r=\$?; rm -f \"\$t\"; exit \$r; fi; rm -f \"\$t\"; $LOGF; exit 2" ;;
    S1)    stub "$2" comm "$REAL_COMM" "'-23 '*" "$LOGF; echo 'comm: forced failure' >&2; exit 2" ;;
    S2)    stub "$2" grep "$REAL_GREP" "'-Fxf '*" "$LOGF; echo 'grep: forced failure' >&2; exit 2" ;;
    S3)    stub "$2" git "$REAL_GIT" "*' diff --name-only '*' -- core/scripts/'" "$LOGF; echo 'fatal: forced failure' >&2; exit 2" ;;
    # U1 FAILS NOTHING: its discriminating input is the WORLD. The stub only logs the listing and
    # passes through, so FIRED > 0 proves the run reached the scan rather than dying before it.
    U1)    stub "$2" git "$REAL_GIT" "*' ls-tree '*" "$LOGF" ;;
    U2)    stub "$2" git "$REAL_GIT" "*' ls-tree '*" "$LOGF; echo 'fatal: forced failure' >&2; exit 128" ;;
    # The memo's call shape alone: the full listing ENDS at the ref, the direct one carries ` -- `.
    U2b)   stub "$2" git "$REAL_GIT" "*' ls-tree -r --name-only $(cat "$UW_OK/B")'" "$LOGF; echo 'fatal: forced failure' >&2; exit 128" ;;
    U3)    stub "$2" grep "$REAL_GREP" "*'(md|sh|json)'*" "$LOGF; echo 'grep: forced failure' >&2; exit 2" ;;
    U4)    stub "$2" grep "$REAL_GREP" "*'core/team-roles/|core/hooks/'*" "$LOGF; echo 'grep: forced failure' >&2; exit 2" ;;
    # U5 fails nothing either: its forcing input is the CLOSED STDOUT ud_shape runs it under.
    U5)    stub "$2" git "$REAL_GIT" "*' ls-tree '*" "$LOGF" ;;
    Aud)   ap_stub "$2" unregistered-drift ;;
    Art)   ap_stub "$2" retired-tokens ;;
    Arlp)  ap_stub "$2" retired-layer-passage ;;
    Ald)   ap_stub "$2" layer-drift ;;
    Ana)   stub "$2" bash "$REAL_BASH" "*'/unregistered-drift.sh '*" \
             "$LOGF; printf 'HARD-DRIFT-SCAN-UNAVAILABLE\\tcore/\\tZZ-PSB-NA-DETAIL forced\\n'; exit 0" ;;
  esac
}
# ap_stub <dir> <detector>: `bash <reconcile>/<detector>.sh …` refuses the way a detector does --
# exit 2, empty stdout, the reason on stderr -- and every other `bash` call passes through.
ap_stub() {
  stub "$1" bash "$REAL_BASH" "*'/$2.sh '*" "$LOGF; echo 'ZZ-PSB-STDERR-$2 forced refusal' >&2; exit 2"
}

gi() { git -C "$1" -c user.email=f@f -c user.name=fixture -c commit.gpgsign=false "${@:2}"; }

# === WORLD lr: ledger-reverify ====================================================================
# One core subject that upstream ships and moves (validate-thing.sh), and `aaa-first.md`, which
# sorts FIRST in theirs' `core/` listing: L3's stub hands the reader that one line and fails, so
# the partial table the base spelling accepted lacks the subject.
LW="$WORK/lw"; LD="$LW/dist"; LC="$LW/consumer"
mkdir -p "$LD/core/scripts" "$LC/scripts/ai-dlc"
printf '0.1.0\n' > "$LD/VERSION"
printf 'first\n' > "$LD/core/aaa-first.md"
printf '#!/bin/bash\nrun_thing() { :; }\n' > "$LD/core/scripts/validate-thing.sh"
{ gi "$LD" init -q && gi "$LD" add -A && gi "$LD" commit -qm base; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: lr dist base" >&2; exit 2; }
LB="$(git -C "$LD" rev-parse HEAD)"
printf '0.2.0\n' > "$LD/VERSION"
printf '# theirs moved\n' >> "$LD/core/scripts/validate-thing.sh"
{ gi "$LD" add -A && gi "$LD" commit -qm theirs; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: lr dist theirs" >&2; exit 2; }
LT="$(git -C "$LD" rev-parse HEAD)"
git -C "$LD" show "${LB}:core/scripts/validate-thing.sh" > "$LC/scripts/ai-dlc/validate-thing.sh"
printf '#!/bin/bash\necho keep\n' > "$LC/scripts/keep.sh"
{ gi "$LC" init -q && gi "$LC" add -A && gi "$LC" commit -qm consumer; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: lr consumer" >&2; exit 2; }
# L1: the receipt exits non-zero (grep on a file that is not there) and NAMES that missing file,
# so the healthy reading is NEEDS-REVIEW "DO NOT EXIST", never a close.
cat > "$LW/ledger-absent.md" <<'EOM'
## PSB-ABSENT — a receipt whose subject moved away

verify: sh cd "$CONSUMER" && grep -q psb_needle scripts/psb-moved-away.sh

---
EOM
# L2/L3: the receipt exits 0, names neither $THEIRS nor $DIST, and reads a file upstream SHIPS,
# so the healthy reading is NEEDS-REVIEW "unfalsifiable predicate:" (bucket 3).
cat > "$LW/ledger-named.md" <<'EOM'
## PSB-NAMED — a receipt that reads only the installed copy of a shipped file

verify: sh cd "$CONSUMER" && [ -f scripts/ai-dlc/validate-thing.sh ] && ! grep -q ZZ_PSB_NEVER scripts/ai-dlc/validate-thing.sh

---
EOM
[ "$(git -C "$LD" ls-tree -r --name-only "$LT" -- core/ | head -n 1)" = core/aaa-first.md ] \
  || { echo "FIXTURE ERROR: lr world: core/aaa-first.md is not the first entry of theirs' core/ listing, so L3's partial table would carry the subject" >&2; exit 2; }

# lr_shape <recon> <arm> <stub-dir or -> -> prints the SHAPE of one ledger-reverify run
lr_shape() {
  local recon="$1" arm="$2" sd="$3" led label out err rc row det p="$PATH"
  case "$arm" in L1) led="$LW/ledger-absent.md"; label=PSB-ABSENT ;; *) led="$LW/ledger-named.md"; label=PSB-NAMED ;; esac
  [ "$sd" = - ] || p="$sd:$PATH"
  err="$WORK/lr.err.$$"
  out="$(PATH="$p" bash "$recon/ledger-reverify.sh" "$LD" "$LB" "$LC" "$LT" "$led" 2>"$err")"; rc=$?
  row="$(awk -F'\t' -v l="$label" '$2==l {print $1; exit}' <<<"$out")"
  det="$(awk -F'\t' -v l="$label" '$2==l {print $3; exit}' <<<"$out")"
  if [ "$rc" -eq 2 ] && [ -z "$row" ] && "$REAL_GREP" -qF 'receipt_absent_subjects returned' "$err"; then echo REFUSED-ABSENT
  elif [ "$rc" -eq 2 ] && [ -z "$row" ] && "$REAL_GREP" -qF 'receipt_named_subjects returned' "$err"; then echo REFUSED-NAMED
  elif [ "$rc" -eq 0 ] && [ "$row" = CLOSE-CANDIDATE ]; then echo CLOSE-CANDIDATE
  elif [ "$rc" -eq 0 ] && [ "$row" = NEEDS-REVIEW ] && grep -qF 'DO NOT EXIST' <<<"$det"; then echo NEEDS-REVIEW-ABSENT
  elif [ "$rc" -eq 0 ] && [ "$row" = NEEDS-REVIEW ] && grep -qF 'unfalsifiable predicate:' <<<"$det"; then echo NEEDS-REVIEW-UNFALSIFIABLE
  elif [ "$rc" -eq 0 ] && [ "$row" = STILL-LIVE ] && grep -qF 'names no path-shaped subject' <<<"$det"; then echo STILL-LIVE-NO-SUBJECT
  elif [ "$rc" -eq 0 ] && [ "$row" = STILL-LIVE ] && grep -qF "'git ls-tree -r" <<<"$det" && grep -qF 'failed in' <<<"$det"; then echo STILL-LIVE-LSTREE-FAILED
  elif [ "$rc" -eq 0 ] && [ "$row" = STILL-LIVE ] && grep -qF 'CONSUMER-OWNED' <<<"$det"; then echo STILL-LIVE-CONSUMER-OWNED
  else echo "OTHER(rc=$rc,row=${row:-none})"
  fi
  rm -f "$err"
}

# === WORLD pc: preclassify ========================================================================
# A consumer holding a pre-0.49.0 copy of a core fixture at `.claude/fixtures/`, byte-identical to
# base: the orphan pass must report it. core/rules/r.md moves base->theirs so the changed-files
# pass emits a non-O row -- the positive conjunct that separates "ran, found no orphan" (base
# shape) from a copy that never ran.
PW="$WORK/pw"; PD="$PW/dist"; PC="$PW/consumer"
mkdir -p "$PD/core/fixtures/old" "$PD/core/rules" "$PC/.claude/fixtures/old" "$PC/.claude/rules"
printf '0.1.0\n' > "$PD/VERSION"
printf '#!/usr/bin/env bash\necho old\n' > "$PD/core/fixtures/old/run.sh"
printf 'rule base\n' > "$PD/core/rules/r.md"
{ gi "$PD" init -q && gi "$PD" add -A && gi "$PD" commit -qm base; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: pc dist base" >&2; exit 2; }
PB="$(git -C "$PD" rev-parse HEAD)"
printf '0.2.0\n' > "$PD/VERSION"; printf 'rule theirs\n' > "$PD/core/rules/r.md"
{ gi "$PD" add -A && gi "$PD" commit -qm theirs; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: pc dist theirs" >&2; exit 2; }
PT="$(git -C "$PD" rev-parse HEAD)"
cp "$PD/core/fixtures/old/run.sh" "$PC/.claude/fixtures/old/run.sh"
git -C "$PD" show "${PB}:core/rules/r.md" > "$PC/.claude/rules/r.md"
printf 'version: 0.1.0\ncommit: %s\n' "$PB" > "$PC/.claude/.ai-dlc-version"

pc_shape() { # <recon> <stub-dir or ->
  local p="$PATH" out err rc no nn
  [ "$2" = - ] || p="$2:$PATH"
  err="$WORK/pc.err.$$"
  out="$(PATH="$p" bash "$1/preclassify.sh" "$PD" "$PB" "$PT" "$PC" 2>"$err")"; rc=$?
  no="$(awk -F'\t' '$1=="O"' <<<"$out" | "$REAL_GREP" -c .)" || no=0
  nn="$(awk -F'\t' 'NF>=4 && $1!="O"' <<<"$out" | "$REAL_GREP" -c .)" || nn=0
  if [ "$rc" -eq 2 ] && "$REAL_GREP" -qF 'the orphan walk of' "$err" && "$REAL_GREP" -qF 'did not complete' "$err"; then echo REFUSED
  elif [ "$rc" -eq 0 ] && [ "$no" -eq 0 ] && [ "$nn" -gt 0 ]; then echo NO-ORPHAN-ROWS
  elif [ "$rc" -eq 0 ] && [ "$no" -gt 0 ]; then echo ORPHAN-ROWS
  else echo "OTHER(rc=$rc,O=$no,other=$nn)"
  fi
  rm -f "$err"
}

# === WORLD er: emit-report --verify ===============================================================
# The sibling's seed, and a report that is its approved region plus ONE line the detectors never
# render. Healthy, that is a mismatch with no HARD row gone: UNDECIDED (the generic cause). With the
# fresh render's side emptied, every approved row -- the HARD ones included -- reads as gone.
EW="$(bash "$SIB/seed.sh")" || { echo "FIXTURE ERROR: the sibling seed failed" >&2; exit 2; }
# shellcheck source=/dev/null
. "$EW/env.sh"
ER_REPORT="$WORK/report-hand-edited.md"
awk '/END GENERATED: reconcile-mechanical/ { print "ZZ-PSB-HAND-EDIT a line no detector renders" } { print }' "$REPORT_GOOD" > "$ER_REPORT"
_h="$("$REAL_GREP" -c '^HARD-' "$ER_REPORT")" || _h=0
_m="$("$REAL_GREP" -c '^ZZ-PSB-HAND-EDIT' "$ER_REPORT")" || _m=0
if [ "$_h" -lt 1 ] || [ "$_m" -ne 1 ]; then
  echo "FIXTURE ERROR: er world: the approved region carries $_h column-0 HARD row(s) (want >= 1) and $_m hand-edit marker(s) (want 1), so E1 cannot express a false BLOCKERS-RESOLVED" >&2; exit 2
fi
er_shape() { # <recon> <stub-dir or ->
  local p="$PATH" err rc
  [ "$2" = - ] || p="$2:$PATH"
  err="$WORK/er.err.$$"
  PATH="$p" bash "$1/emit-report.sh" --verify "$ER_REPORT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>"$err"; rc=$?
  if [ "$rc" -eq 1 ] && "$REAL_GREP" -qF 'cause: UNDECIDED — the region does not match, but which rows differ could not be computed' "$err"; then echo UNDECIDED-UNCOMPUTED
  elif [ "$rc" -eq 3 ] && "$REAL_GREP" -qF 'cause: BLOCKERS-RESOLVED' "$err"; then echo BLOCKERS-RESOLVED
  elif [ "$rc" -eq 1 ] && "$REAL_GREP" -qF 'cause: UNDECIDED — the fresh render carries' "$err"; then echo UNDECIDED-DIFF
  else echo "OTHER(rc=$rc)"
  fi
  rm -f "$err"
}

# === WORLDS sg: self-update-gate ==================================================================
# Two worlds, because an arm-R1 DEFER exits before the GATING intersection is ever read.
#   r1  theirs' gate-validation.md anchors `psb-b`, the consumer's does not; no core/scripts path
#       moves. Healthy: R1 DEFERs naming psb-b. Silenced: the gate falls through to "changes no
#       core/scripts/ path" -- OK.
#   gt  no gate-validation.md at all (R1 has no subject); the pull changes gate-defer.sh, which the
#       consumer's hook invokes, and the incoming copy exits 1 where the current exits 0. Healthy:
#       DEFER. Silenced: an empty intersection -- OK.
# Neither consumer is a git work tree, so arm P (the push probe) has nothing to probe.
mk_gate_world() { # <dir> <r1|gt>
  local W="$1" D="$1/dist" C="$1/consumer"
  mkdir -p "$D/core/scripts" "$C/scripts/ai-dlc" "$C/.githooks"
  printf '0.1.0\n' > "$D/VERSION"
  if [ "$2" = r1 ]; then
    mkdir -p "$D/core/skills/ai-dlc/steps" "$C/.claude/skills/ai-dlc/steps"
    printf '#!/bin/sh\nexit 0\n' > "$D/core/scripts/keep.sh"
    printf '# gate\n<!-- CHECK_LOADED: psb-a -->\n' > "$D/core/skills/ai-dlc/steps/gate-validation.md"
  else
    printf '#!/bin/sh\nexit 0\n' > "$D/core/scripts/gate-defer.sh"
  fi
  { gi "$D" init -q && gi "$D" add -A && gi "$D" commit -qm base; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/B"
  printf '0.2.0\n' > "$D/VERSION"
  if [ "$2" = r1 ]; then
    printf '# gate\n<!-- CHECK_LOADED: psb-a -->\n<!-- CHECK_LOADED: psb-b -->\n' > "$D/core/skills/ai-dlc/steps/gate-validation.md"
    git -C "$D" show "$(cat "$W/B"):core/skills/ai-dlc/steps/gate-validation.md" > "$C/.claude/skills/ai-dlc/steps/gate-validation.md"
    cp "$D/core/scripts/keep.sh" "$C/scripts/ai-dlc/keep.sh"
    printf '#!/usr/bin/env bash\nbash scripts/ai-dlc/keep.sh\n' > "$C/.githooks/pre-push"
  else
    printf '#!/bin/sh\n# the incoming check finds something\nexit 1\n' > "$D/core/scripts/gate-defer.sh"
    printf '#!/bin/sh\nexit 0\n' > "$C/scripts/ai-dlc/gate-defer.sh"
    printf '#!/usr/bin/env bash\nbash scripts/ai-dlc/gate-defer.sh\n' > "$C/.githooks/pre-push"
  fi
  chmod +x "$C/.githooks/pre-push" "$C/scripts/ai-dlc/"*.sh
  { gi "$D" add -A && gi "$D" commit -qm theirs; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/T"
}
mk_gate_world "$WORK/gw-r1" r1 || { echo "FIXTURE ERROR: sg r1 world" >&2; exit 2; }
mk_gate_world "$WORK/gw-gt" gt || { echo "FIXTURE ERROR: sg gt world" >&2; exit 2; }
# ONE FRESH CONSUMER COPY PER RUN: the gate writes its record into the consumer, and the record's
# `# verdict:` is half of what every S arm reads, so a copy shared between runs would let one run's
# record answer for another. `mktemp -d`, because this runs inside `$( )` and a counter would not
# survive it.
sg_shape() { # <recon> <arm S1|S2> <stub-dir or ->
  local W p="$PATH" run out rc rec v
  case "$2" in S1) W="$WORK/gw-r1" ;; *) W="$WORK/gw-gt" ;; esac
  [ "$3" = - ] || p="$3:$PATH"
  run="$(mktemp -d "$WORK/sg-run.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
  cp -R "$W/consumer/." "$run/" || { echo "OTHER(copy)"; return 0; }
  out="$(PATH="$p" bash "$1/self-update-gate.sh" "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$run" 2>/dev/null)"; rc=$?
  rec="$(ls "$run"/_bmad-output/ai-dlc-update/self-update-gate-*.md 2>/dev/null | head -n 1)"
  v="$(sed -n 's/^# verdict: //p' "$rec" 2>/dev/null | head -n 1)"
  local n_ok n_def n_und und_row
  n_ok="$(awk -F'\t' '$1=="SELF-UPDATE-OK"' <<<"$out" | "$REAL_GREP" -c .)" || n_ok=0
  n_def="$(awk -F'\t' '$1=="SELF-UPDATE-DEFER"' <<<"$out" | "$REAL_GREP" -c .)" || n_def=0
  n_und="$(awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED"' <<<"$out" | "$REAL_GREP" -c .)" || n_und=0
  # S3's row must also NAME the diff's exit: `could not be computed` alone is S2's spelling too.
  if [ "$2" = S3 ]; then
    und_row="$(awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" && $3 ~ /could not be computed/ && $3 ~ /core\/scripts\/ exited 2/' <<<"$out" | "$REAL_GREP" -c .)" || und_row=0
  else
    und_row="$(awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" && $3 ~ /could not be computed/' <<<"$out" | "$REAL_GREP" -c .)" || und_row=0
  fi
  if [ "$rc" -ne 0 ] || [ -z "$v" ]; then echo "OTHER(rc=$rc,record=${v:-none})"
  elif [ "$v" = OK ] && [ "$n_ok" -gt 0 ] && [ "$n_def" -eq 0 ] && [ "$n_und" -eq 0 ]; then echo OK
  elif [ "$v" != OK ] && [ "$und_row" -gt 0 ] && [ "$n_ok" -eq 0 ]; then echo "UNDECIDED-UNCOMPUTED/$v"
  elif [ "$v" = DEFER ] && [ "$n_und" -eq 0 ] && [ "$n_ok" -eq 0 ]; then echo DEFER
  else echo "OTHER(record=$v,ok=$n_ok,defer=$n_def,undecided=$n_und)"
  fi
}

# === WORLDS ud: unregistered-drift ================================================================
#   ne  the scan-set subtrees hold NO .md/.sh/.json file (one .txt): an empty scan set, which the
#       base spelling exited 1 on through `pipefail` -- grep's "no match" as the script's status.
#   ok  one .md, consumer copy byte-identical to base: one CORE-OK row, the positive conjunct that
#       separates a scan that ran from a copy that never did.
#   hu  one .md the consumer edited in place: one HARD-UNREGISTERED-CORE-DRIFT row, the one emit in
#       the loop with no `continue` after it, so it is the loop's last command. U5 runs it with
#       STDOUT CLOSED: the emit fails, and without the explicit `exit 0` that failure is the loop's
#       status and the script's (measured: rc 1 at d1c72fa9 and with the `exit 0` deleted, rc 0 on
#       tip). U1 CANNOT see that line: once the scan set is staged, an empty one runs the loop zero
#       times and exits 0 without it -- the `exit 0` guards a failing LAST WRITE, nothing else.
mk_ud_world() { # <dir> <ne|ok|hu>
  local D="$1/dist" C="$1/consumer"
  mkdir -p "$D/core/skills/ai-dlc/steps" "$C/.claude/skills/ai-dlc/steps"
  printf '0.1.0\n' > "$D/VERSION"
  if [ "$2" = ne ]; then
    printf 'n\n' > "$D/core/skills/ai-dlc/notes.txt"; printf 'n\n' > "$C/.claude/skills/ai-dlc/notes.txt"
  elif [ "$2" = hu ]; then
    printf '# One step\n\nThe lead reads this file at the top of the one phase.\n' > "$D/core/skills/ai-dlc/steps/one.md"
    cp "$D/core/skills/ai-dlc/steps/one.md" "$C/.claude/skills/ai-dlc/steps/one.md"
    printf 'The consumer added this long line to the one phase in place.\n' >> "$C/.claude/skills/ai-dlc/steps/one.md"
  else
    printf '# one\n' > "$D/core/skills/ai-dlc/steps/one.md"; cp "$D/core/skills/ai-dlc/steps/one.md" "$C/.claude/skills/ai-dlc/steps/one.md"
  fi
  { gi "$D" init -q && gi "$D" add -A && gi "$D" commit -qm base; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$1/B"
  printf '0.2.0\n' > "$D/VERSION"
  { gi "$D" add -A && gi "$D" commit -qm theirs; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$1/T"
  printf 'version: 0.1.0\ncommit: %s\n' "$(cat "$1/B")" > "$C/.claude/.ai-dlc-version"
}
UW_NE="$WORK/uw-ne"; UW_OK="$WORK/uw-ok"; UW_HU="$WORK/uw-hu"
mk_ud_world "$UW_NE" ne || { echo "FIXTURE ERROR: ud ne world" >&2; exit 2; }
mk_ud_world "$UW_OK" ok || { echo "FIXTURE ERROR: ud ok world" >&2; exit 2; }
mk_ud_world "$UW_HU" hu || { echo "FIXTURE ERROR: ud hu world" >&2; exit 2; }
_n="$(git -C "$UW_NE/dist" ls-tree -r --name-only "$(cat "$UW_NE/B")" -- core/skills/ai-dlc | "$REAL_GREP" -cE '\.(md|sh|json)$')" || _n=0
_c="$(git -C "$UW_NE/dist" ls-tree -r --name-only "$(cat "$UW_NE/B")" -- core/skills/ai-dlc | "$REAL_GREP" -c .)" || _c=0
[ "$_n" -eq 0 ] && [ "$_c" -ge 1 ] \
  || { echo "FIXTURE ERROR: ud ne world: its scan subtree lists $_c path(s), $_n of them .md/.sh/.json (want >= 1 and 0), so U1 cannot express an EMPTY scan set" >&2; exit 2; }
ud_shape() { # <recon> <arm> <stub-dir or ->
  local W p="$PATH" out rc n nun nok nhu det
  case "$2" in U1) W="$UW_NE" ;; U5) W="$UW_HU" ;; *) W="$UW_OK" ;; esac
  [ "$3" = - ] || p="$3:$PATH"
  if [ "$2" = U5 ] && [ "$3" != - ]; then
    PATH="$p" "$REAL_BASH" "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" >&- 2>/dev/null
    echo "CLOSED-RC$?"; return 0
  fi
  out="$(PATH="$p" "$REAL_BASH" "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" 2>/dev/null)"; rc=$?
  n="$("$REAL_GREP" -c . <<<"$out")" || n=0
  nun="$(awk -F'\t' '$1=="HARD-DRIFT-SCAN-UNAVAILABLE"' <<<"$out" | "$REAL_GREP" -c .)" || nun=0
  nok="$(awk -F'\t' '$1=="CORE-OK"' <<<"$out" | "$REAL_GREP" -c .)" || nok=0
  nhu="$(awk -F'\t' '$1=="HARD-UNREGISTERED-CORE-DRIFT"' <<<"$out" | "$REAL_GREP" -c .)" || nhu=0
  det="$(awk -F'\t' '$1=="HARD-DRIFT-SCAN-UNAVAILABLE" {print $3; exit}' <<<"$out")"
  if [ "$rc" -eq 0 ] && [ "$n" -eq 1 ] && [ "$nun" -eq 1 ]; then
    case "$det" in
      *"memo_ls_tree exited 128, git ls-tree exited 128"*) echo UNAVAILABLE-LISTING ;;
      *"the file-type filter over the tree listing exited 2"*) echo UNAVAILABLE-EXT ;;
      *"the scan-set prefix filter over the cached tree listing exited 2"*) echo UNAVAILABLE-PREFIX ;;
      *) echo "OTHER(unavailable-unnamed)" ;;
    esac
  elif [ "$rc" -eq 0 ] && [ "$n" -eq 1 ] && [ "$nok" -eq 1 ]; then echo SCANNED
  elif [ "$rc" -eq 0 ] && [ "$n" -eq 1 ] && [ "$nhu" -eq 1 ]; then echo HARD-UNREG
  elif [ "$rc" -eq 0 ] && [ "$n" -eq 0 ]; then echo EMPTY
  elif [ "$n" -eq 0 ]; then echo "RC${rc}-NOROW"
  else echo "OTHER(rc=$rc,rows=$n)"
  fi
}

# === WORLD ap: apply.sh ===========================================================================
# One core step both sides moved (BOTH-CHANGED->CLASSIFY), so the run reaches all four detectors
# and retired-tokens runs for a real path. Healthy, every detector exits 0 on it and the run emits
# `WORKLIST semantic-merge skills/ai-dlc/steps/m.md` -- the positive conjunct every shape keys on,
# so an apply.sh copy that never ran reads OTHER, never a clean pass.
AW="$WORK/aw"; AD="$AW/dist"; AC="$AW/consumer"
mkdir -p "$AD/core/skills/ai-dlc/steps" "$AC/.claude/skills/ai-dlc/steps"
printf '0.1.0\n' > "$AD/VERSION"
printf '# M step\n\nThe lead reads this file at the top of the m phase.\n' > "$AD/core/skills/ai-dlc/steps/m.md"
{ gi "$AD" init -q && gi "$AD" add -A && gi "$AD" commit -qm base; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: ap dist base" >&2; exit 2; }
git -C "$AD" rev-parse HEAD > "$AW/B"
printf '0.2.0\n' > "$AD/VERSION"
printf 'Upstream added this long line to the m phase for the pull.\n' >> "$AD/core/skills/ai-dlc/steps/m.md"
{ gi "$AD" add -A && gi "$AD" commit -qm theirs; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: ap dist theirs" >&2; exit 2; }
git -C "$AD" rev-parse HEAD > "$AW/T"
git -C "$AD" show "$(cat "$AW/B"):core/skills/ai-dlc/steps/m.md" > "$AC/.claude/skills/ai-dlc/steps/m.md"
printf 'The consumer added this long line to the m phase in place.\n' >> "$AC/.claude/skills/ai-dlc/steps/m.md"
printf 'version: 0.1.0\ncommit: %s\n' "$(cat "$AW/B")" > "$AC/.claude/.ai-dlc-version"
ap_det() { case "$1" in Aud|Ana) echo unregistered-drift ;; Art) echo retired-tokens ;; Arlp) echo retired-layer-passage ;; Ald) echo layer-drift ;; esac; }
# ONE FRESH CONSUMER COPY PER RUN, for the reason sg_shape states: apply.sh writes the consumer.
ap_shape() { # <recon> <arm> <stub-dir or ->
  local p="$PATH" run out rc nref nmerge row path det d
  [ "$3" = - ] || p="$3:$PATH"
  d="$(ap_det "$2")"
  run="$(mktemp -d "$WORK/ap-run.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
  cp -R "$AC/." "$run/" || { echo "OTHER(copy)"; return 0; }
  out="$(PATH="$p" "$REAL_BASH" "$1/apply.sh" "$AD" "$(cat "$AW/B")" "$run" "$(cat "$AW/T")" 2>/dev/null)"; rc=$?
  nref="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/' <<<"$out" | "$REAL_GREP" -c .)" || nref=0
  nmerge="$(awk -F'\t' '$1=="WORKLIST" && $2=="semantic-merge" && $3=="skills/ai-dlc/steps/m.md"' <<<"$out" | "$REAL_GREP" -c .)" || nmerge=0
  row="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/ {print $2; exit}' <<<"$out")"
  path="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/ {print $3; exit}' <<<"$out")"
  det="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/ {print $4; exit}' <<<"$out")"
  if [ "$rc" -ne 0 ]; then echo "OTHER(rc=$rc)"; return 0; fi
  if [ "$nref" -eq 0 ] && [ "$nmerge" -ge 1 ]; then echo NO-REFUSAL; return 0; fi
  if [ "$nref" -ne 1 ] || [ "$row" != "$d-refused" ]; then echo "OTHER(refused=$nref,row=${row:-none},merge=$nmerge)"; return 0; fi
  case "$2" in
    Ana) case "$det" in *"emitted HARD-DRIFT-SCAN-UNAVAILABLE"*"ZZ-PSB-NA-DETAIL forced"*) ;; *) echo "OTHER(na-detail)"; return 0 ;; esac ;;
    *)   case "$det" in "DETECTOR-REFUSED: $d.sh exited 2 "*"stderr: ZZ-PSB-STDERR-$d forced refusal") ;; *) echo "OTHER(detail)"; return 0 ;; esac ;;
  esac
  if [ "$2" = Art ] && [ "$path" != skills/ai-dlc/steps/m.md ]; then echo "OTHER(path=$path)"; return 0; fi
  if [ "$nmerge" -eq 0 ]; then echo REFUSED-NOMERGE; else echo REFUSED; fi
}

# === ONE ARM ======================================================================================
# arm_shape <arm> <recon> <stub-dir or -> -> the shape
arm_shape() {
  case "$1" in
    L1|L2|L3) lr_shape "$2" "$1" "$3" ;;
    P1) pc_shape "$2" "$3" ;;
    E1) er_shape "$2" "$3" ;;
    S1|S2|S3) sg_shape "$2" "$1" "$3" ;;
    U1|U2|U2b|U3|U4|U5) ud_shape "$2" "$1" "$3" ;;
    Aud|Art|Arlp|Ald|Ana) ap_shape "$2" "$1" "$3" ;;
  esac
}
# THE EXPECTATION TABLE. <arm> <key> <control shape> <tip shape> <base shape>
EXPECT='L1 lr NEEDS-REVIEW-ABSENT REFUSED-ABSENT CLOSE-CANDIDATE
L2 lr NEEDS-REVIEW-UNFALSIFIABLE REFUSED-NAMED STILL-LIVE-NO-SUBJECT
L3 lr NEEDS-REVIEW-UNFALSIFIABLE STILL-LIVE-LSTREE-FAILED STILL-LIVE-CONSUMER-OWNED
P1 pc ORPHAN-ROWS REFUSED NO-ORPHAN-ROWS
E1 er UNDECIDED-DIFF UNDECIDED-UNCOMPUTED BLOCKERS-RESOLVED
S1 sg DEFER UNDECIDED-UNCOMPUTED/DEFER OK
S2 sg DEFER UNDECIDED-UNCOMPUTED/UNDECIDED OK
S3 sg DEFER UNDECIDED-UNCOMPUTED/UNDECIDED OK
U1 ud EMPTY EMPTY RC1-NOROW
U2 ud SCANNED UNAVAILABLE-LISTING RC1-NOROW
U2b ud SCANNED SCANNED SCANNED
U3 ud SCANNED UNAVAILABLE-EXT RC2-NOROW
U4 ud SCANNED UNAVAILABLE-PREFIX SCANNED
U5 ud HARD-UNREG CLOSED-RC0 CLOSED-RC1
Aud ap NO-REFUSAL REFUSED NO-REFUSAL
Art ap NO-REFUSAL REFUSED NO-REFUSAL
Arlp ap NO-REFUSAL REFUSED NO-REFUSAL
Ald ap NO-REFUSAL REFUSED NO-REFUSAL
Ana ap NO-REFUSAL REFUSED NO-REFUSAL'
col() { awk -v a="$1" -v c="$2" '$1==a {print $c}' <<<"$EXPECT"; }
arms_of() { awk -v k="$1" '$2==k {print $1}' <<<"$EXPECT"; }

# forced <arm> <recon> <tag> -> "<shape> <fired>"
forced() {
  local sd="$WORK/stub/$3-$1" s
  mkstub_for "$1" "$sd"
  s="$(arm_shape "$1" "$2" "$sd")"
  printf '%s %s\n' "$s" "$(fired "$sd")"
}

# --- CONTROLS AND FORCED ARMS ON THE SHIPPED SCRIPTS ----------------------------------------------
for A in $(awk '{print $1}' <<<"$EXPECT"); do
  c="$(arm_shape "$A" "$RECON" -)"
  if [ "$c" = "$(col "$A" 3)" ]; then
    ok "$A control (no stub): $c -- the world expresses the healthy verdict"
  else
    bad "$A control (no stub): $c, expected $(col "$A" 3) -- the world does not express the case, so the forced arm below is unattributable"
  fi
  set -- $(forced "$A" "$RECON" tip)
  if [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 4)" ]; then
    ok "$A forced (stub fired ${2}x): $1 -- the tip shape (base spelling reads $(col "$A" 5))"
  elif [ "${2:-0}" -eq 0 ]; then
    bad "$A FIXTURE BROKEN: the stub never fired, so its shape ($1) says nothing about the site"
  else
    bad "$A forced (stub fired ${2}x): $1, expected $(col "$A" 4) -- a failed producer read as $1"
  fi
done

# --- MUTANTS: one per forced site, the site's base block restored verbatim ------------------------
# mut <name> <script> <awk-program> <base-line-literal> <staged-token> <anchor-literal...>
# The awk program reads ENVIRON; every anchor must match exactly one whole line before mutation.
MUTROOT="$WORK/mut"
mkdir -p "$MUTROOT" || { echo "FIXTURE ERROR: mkdir $MUTROOT" >&2; exit 2; }
# `mut` runs inside `$( )`, where a `bad` would lose both its line and its count. It writes the
# reason to a file instead and returns 1; the caller's `mutreport` turns that into the FAIL, and a
# mut that returned 1 with no reason written is reported as a harness fault, never as silence.
mutbad() { printf '%s\n' "$1" > "$MUTROOT/$n.why"; }
mutreport() {
  if [ -s "$MUTROOT/$1.why" ]; then bad "$(cat "$MUTROOT/$1.why")"
  else bad "MUTANT HARNESS [$1]: the mutant was not scored and no reason was recorded"; fi
}
mut() {
  local n="$1" s="$2" prog="$3" base_line="$4" staged="$5" d="$MUTROOT/$1" a h
  shift 5
  for a in "$@"; do
    h="$("$REAL_GREP" -cxF -- "$a" "$RECON/$s")" || h=0
    [ "$h" -eq 1 ] || { mutbad "MUTANT STALE [$n]: anchor matches $h line(s) of $s, not 1 -- re-anchor on the same site, never relax the arm: $a"; return 1; }
  done
  h="$("$REAL_GREP" -cxF -- 'ZZ-PSB-NO-SUCH-LINE-ZZ' "$RECON/$s")" || h=0
  [ "$h" -eq 0 ] || { mutbad "MUTANT HARNESS [$n]: the impossible-anchor control matched $h line(s)"; return 1; }
  mkdir -p "$MUTROOT"; cp -R "$RECON" "$d" || { mutbad "MUTANT HARNESS [$n]: copy failed"; return 1; }
  awk "$prog" "$RECON/$s" > "$d/$s" || { mutbad "MUTANT DID NOT APPLY [$n]: awk failed"; return 1; }
  if cmp -s "$RECON/$s" "$d/$s"; then mutbad "MUTANT DID NOT APPLY [$n]: the copy is byte-identical"; return 1; fi
  bash -n "$d/$s" 2>/dev/null || { mutbad "MUTANT DID NOT APPLY [$n]: the mutant does not parse"; return 1; }
  h="$("$REAL_GREP" -cxF -- "$base_line" "$d/$s")" || h=0
  [ "$h" -eq 1 ] || { mutbad "MUTANT DID NOT APPLY [$n]: the base spelling is present $h time(s), not 1"; return 1; }
  # `-` for a mutant that DELETES a line with no staged counterpart (M-Art-merge): its anchors and
  # its base line still bind it, and `cmp -s` proves it applied.
  if [ "$staged" != - ]; then
    h="$("$REAL_GREP" -cF -- "$staged" "$d/$s")" || h=0
    [ "$h" -eq 0 ] || { mutbad "MUTANT PARTIAL [$n]: the staged spelling '$staged' survives $h time(s) -- a partial revert proves the layer left in place"; return 1; }
  fi
  [ -f "$d/lib.sh" ] || { mutbad "MUTANT HARNESS [$n]: lib.sh is not beside the mutant"; return 1; }
  printf '%s\n' "$d"
}
# Line-for-line replacement: drop each line equal to $DROP1/$DROP2, replace the line equal to $OLD.
SWAP='$0==ENVIRON["DROP1"] {next} $0==ENVIRON["DROP2"] {next} $0==ENVIRON["OLD"] {print ENVIRON["NEW"]; next} {print}'
# Block replacement: from the line equal to $START through the $NFI-th following line equal to $END
# (inclusive), print $NEW instead.
BLOCK='!inb && $0==ENVIRON["START"] {inb=1; seen=0; print ENVIRON["NEW"]; next}
       inb { if ($0==ENVIRON["END"]) { seen++; if (seen==ENVIRON["NFI"]+0) inb=0 } next }
       {print}'

# score <mutant-name> <own-arm> <recon-copy>
score() {
  local m="$1" own="$2" d="$3" k A s want got_own="" others_ok=1 detail=""
  k="$(col "$own" 2)"
  for A in $(arms_of "$k"); do
    set -- $(forced "$A" "$d" "$m")
    if [ "$A" = "$own" ]; then
      got_own="$1 fired=${2:-0}"
      [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 5)" ] || got_own="!$got_own"
    else
      [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 4)" ] || { others_ok=0; detail="$detail $A=$1"; }
    fi
  done
  report_score "$m" "$own" "$k" "$got_own" "$others_ok" "$detail" "$(col "$own" 5)"
  return 0
}
# score_as <mutant-name> <key> <recon-copy> <arm=shape>... -- for a mutant whose own arm lands on a
# shape OTHER than the base spelling's (M-U2a reads EMPTY, the silent clear, where the whole base
# pipeline read rc 1), or that two arms genuinely both own. Every arm NOT named must stay at its
# tip shape, so an undeclared move is still ENTANGLED.
score_as() {
  local m="$1" k="$2" d="$3" A want got fails="" others_ok=1 detail="" named=""
  shift 3
  for A in $(arms_of "$k"); do
    want=""
    for _p in "$@"; do [ "${_p%%=*}" = "$A" ] && want="${_p#*=}"; done
    set -- $(forced "$A" "$d" "$m") "$@"
    got="$1"; local fired="${2:-0}"; shift 2
    if [ -n "$want" ]; then
      named="$named $A=$got"
      [ "$fired" -gt 0 ] && [ "$got" = "$want" ] || fails="$fails $A=$got(want $want,fired=$fired)"
    else
      [ "$fired" -gt 0 ] && [ "$got" = "$(col "$A" 4)" ] || { others_ok=0; detail="$detail $A=$got"; }
    fi
  done
  if [ -n "$fails" ]; then bad "MUTANT SURVIVED [$m]:$fails -- the arm cannot see its own site revert"
  elif [ "$others_ok" -eq 1 ]; then ok "MUTANT KILLED [$m]:$named, every other $k arm stays at its tip shape"
  else bad "MUTANT ENTANGLED [$m]:$named but undeclared arm(s) moved too:$detail"; fi
  return 0
}
report_score() { # <m> <own> <k> <got_own> <others_ok> <detail> <base-shape>
  local m="$1" own="$2" k="$3" got_own="$4" others_ok="$5" detail="$6"
  case "$got_own" in
    '!'*) bad "MUTANT SURVIVED [$m]: arm $own read ${got_own#!}, expected the base shape $7 -- the arm cannot see its own site revert" ;;
    *) if [ "$others_ok" -eq 1 ]; then
         ok "MUTANT KILLED [$m]: $own reads $got_own (the base shape), every other $k arm stays at its tip shape"
       else
         bad "MUTANT ENTANGLED [$m]: $own reads $got_own but other arm(s) moved too:$detail"
       fi ;;
  esac
  return 0
}

LR=ledger-reverify.sh
  d="$(DROP1='  receipt_path_tokens "$rest" > "$LR_STAGE/absent-tokens" || return 3' DROP2='ZZ-PSB-NONE' \
       OLD='  done < "$LR_STAGE/absent-tokens"' NEW='  done < <(receipt_path_tokens "$rest")' \
       mut M-L1 "$LR" "$SWAP" '  done < <(receipt_path_tokens "$rest")' 'absent-tokens' \
         '  receipt_path_tokens "$rest" > "$LR_STAGE/absent-tokens" || return 3' '  done < "$LR_STAGE/absent-tokens"')" \
    && score M-L1 L1 "$d" \
    || mutreport M-L1
  d="$(DROP1='  receipt_path_tokens "$1" > "$LR_STAGE/named-tokens" || return 3' DROP2='ZZ-PSB-NONE' \
       OLD='  done < "$LR_STAGE/named-tokens"' NEW='  done < <(receipt_path_tokens "$1")' \
       mut M-L2 "$LR" "$SWAP" '  done < <(receipt_path_tokens "$1")' 'named-tokens' \
         '  receipt_path_tokens "$1" > "$LR_STAGE/named-tokens" || return 3' '  done < "$LR_STAGE/named-tokens"')" \
    && score M-L2 L2 "$d" \
    || mutreport M-L2
  d="$(DROP1='  git -C "$DIST" ls-tree -r --name-only "${THEIRS}" -- core/ > "$LR_STAGE/core-map-ls-tree" 2>/dev/null || return 1' DROP2='ZZ-PSB-NONE' \
       OLD='  done < "$LR_STAGE/core-map-ls-tree" > "$CORE_MAP"' \
       NEW='  done < <(git -C "$DIST" ls-tree -r --name-only "${THEIRS}" -- core/ 2>/dev/null) > "$CORE_MAP"' \
       mut M-L3 "$LR" "$SWAP" '  done < <(git -C "$DIST" ls-tree -r --name-only "${THEIRS}" -- core/ 2>/dev/null) > "$CORE_MAP"' 'core-map-ls-tree' \
         '  git -C "$DIST" ls-tree -r --name-only "${THEIRS}" -- core/ > "$LR_STAGE/core-map-ls-tree" 2>/dev/null || return 1' \
         '  done < "$LR_STAGE/core-map-ls-tree" > "$CORE_MAP"')" \
    && score M-L3 L3 "$d" \
    || mutreport M-L3
  # The walk and its sort are four lines (two commands, each with its `|| pc_refuse` continuation);
  # all four go, and the reader line gets the base substitution back, in one copy.
  d="$(START='  find "$CONS/$old_prefix" -type f > "$PC_STAGE/orphan-walk" 2>/dev/null \' \
       END='    || pc_refuse "the orphan walk of $CONS/$old_prefix could not be sorted (sort exited $?)"' NFI=1 NEW='' \
       OLD='  done < "$PC_STAGE/orphan-sorted"' NEW2='  done < <(find "$CONS/$old_prefix" -type f 2>/dev/null | sort)' \
       mut M-P1 preclassify.sh '!inb && $0==ENVIRON["START"] {inb=1; next}
             inb { if ($0==ENVIRON["END"]) inb=0; next }
             $0==ENVIRON["OLD"] {print ENVIRON["NEW2"]; next} {print}' \
         '  done < <(find "$CONS/$old_prefix" -type f 2>/dev/null | sort)' 'orphan-walk' \
         '  find "$CONS/$old_prefix" -type f > "$PC_STAGE/orphan-walk" 2>/dev/null \' \
         '    || pc_refuse "the orphan walk of $CONS/$old_prefix could not be sorted (sort exited $?)"' \
         '  done < "$PC_STAGE/orphan-sorted"')" \
    && score M-P1 P1 "$d" \
    || mutreport M-P1
  E_B1='only_render="$(LC_ALL=C comm -23 <(printf '"'"'%s\n'"'"' "$want" | norm_rows) <(printf '"'"'%s\n'"'"' "$got" | norm_rows))"'
  E_B2='only_report="$(LC_ALL=C comm -13 <(printf '"'"'%s\n'"'"' "$want" | norm_rows) <(printf '"'"'%s\n'"'"' "$got" | norm_rows))"'
  d="$(START='er_sets_why=""' END='fi' NFI=1 NEW="$E_B1
$E_B2
er_sets_why=\"\"" \
       mut M-E1 emit-report.sh "$BLOCK" "$E_B1" 'sets.want-rows' 'er_sets_why=""')" \
    && score M-E1 E1 "$d" \
    || mutreport M-E1
  S_B1='    r1_missing="$(comm -23 <(printf '"'"'%s\n'"'"' "$r1_theirs") <(printf '"'"'%s\n'"'"' "$r1_ours") | tr '"'"'\n'"'"' '"'"' '"'"' | sed '"'"'s/ *$//'"'"')"'
  d="$(START='    r1_why=""' END='    elif [ -n "$r1_missing" ]; then' NFI=1 NEW="$S_B1
    if [ -n \"\$r1_missing\" ]; then" \
       mut M-S1 self-update-gate.sh "$BLOCK" "$S_B1" 'r1-theirs' '    r1_why=""' '    elif [ -n "$r1_missing" ]; then')" \
    && score M-S1 S1 "$d" \
    || mutreport M-S1
  S_B2='GATING="$(printf '"'"'%s\n'"'"' "$INVOKED" | grep -Fxf <(printf '"'"'%s\n'"'"' "$CHANGED") 2>/dev/null || true)"'
  # The staged block closes with TWO column-0 `fi`s: the staging if/elif/else, then the refusal.
  d="$(START='gating_why=""' END='fi' NFI=2 NEW="$S_B2" \
       mut M-S2 self-update-gate.sh "$BLOCK" "$S_B2" 'gating-changed' 'gating_why=""')" \
    && score M-S2 S2 "$d" \
    || mutreport M-S2
  # S3: the staging block and its refusal, through the sed that reads the staged file, become the
  # base two-line pipeline again -- every layer in one copy.
  S_B3='CHANGED="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/scripts/ 2>/dev/null \'
  S_B3b='            | sed '"'"'s|.*/||'"'"' | sort -u)"'
  d="$(START='changed_why=""' END='CHANGED="$(sed '"'"'s|.*/||'"'"' "$TMP/changed-raw" | sort -u)"' NFI=1 NEW="$S_B3
$S_B3b" \
       mut M-S3 self-update-gate.sh "$BLOCK" "$S_B3" 'changed-raw' 'changed_why=""' \
         'CHANGED="$(sed '"'"'s|.*/||'"'"' "$TMP/changed-raw" | sort -u)"')" \
    && { score M-S3 S3 "$d"
         # THE HEALTHY PATH IS BYTE-IDENTICAL TO THE BASE SPELLING on the world S3 forces: same
         # stdout rows from the staged diff and from the pipeline it replaced, sides shown to differ.
         _o() { local r; r="$(mktemp -d "$WORK/sg-bi.XXXXXX")" && cp -R "$WORK/gw-gt/consumer/." "$r/" \
                  && "$REAL_BASH" "$1/self-update-gate.sh" "$WORK/gw-gt/dist" "$(cat "$WORK/gw-gt/B")" "$(cat "$WORK/gw-gt/T")" "$r" 2>/dev/null; }
         _a="$(_o "$RECON")"; _b="$(_o "$d")"
         if cmp -s "$RECON/self-update-gate.sh" "$d/self-update-gate.sh"; then bad "S3 healthy differential: the two gate copies are identical"
         elif [ -n "$_a" ] && [ "$_a" = "$_b" ]; then ok "S3 healthy: the staged diff prints byte-identical rows to the base pipeline ($(cut -f1 <<<"$_a" | sort | uniq -c | tr -s ' ' | tr '\n' ';'))"
         else bad "S3 healthy: the staged diff and the base pipeline disagree on a readable range"; fi; } \
    || mutreport M-S3

UD=unregistered-drift.sh
N0='ZZ-PSB-NONE'
# M-U-base: THE WHOLE BASE LISTING PIPELINE RESTORED, which makes the copy byte-identical to
# unregistered-drift.sh at the parent release apart from its comments. It is the in-fixture form of
# "the parent's copy exits 1 on an empty scan set": every U arm must read its base shape at once.
# WRITTEN STRAIGHT TO A FILE, never through `$( )` or ENVIRON: bash 3.2 mis-scans the body's
# unbalanced `(` inside a heredoc in a command substitution, and BSD awk joins a backslash-newline
# inside an ENVIRON value. Measured both ways: the base-line count read 0 each time.
U_BASE_F="$MUTROOT/u-base-head.txt"
cat > "$U_BASE_F" <<'EOB' || { echo "FIXTURE ERROR: could not write $U_BASE_F" >&2; exit 2; }
{ { command -v memo_ls_tree >/dev/null 2>&1 \
    && memo_ls_tree "$DIST" "$BASE" \
       | grep -E '^(core/skills/ai-dlc/|core/skills/ai-dlc-setup/|core/team-roles/|core/hooks/|core/schemas/)'; } \
  || git -C "$DIST" ls-tree -r --name-only "$BASE" -- \
      core/skills/ai-dlc core/skills/ai-dlc-setup core/team-roles core/hooks core/schemas 2>/dev/null; } \
  | grep -E '\.(md|sh|json)$' \
  | while IFS= read -r cp; do
EOB
_h="$("$REAL_GREP" -c . "$U_BASE_F")" || _h=0
[ "$_h" -eq 7 ] || { echo "FIXTURE ERROR: the base listing block is $_h line(s), not 7" >&2; exit 2; }
U_BASE_PROG='!inb && $0==ENVIRON["START"] {inb=1; while ((getline l < ENVIRON["NEWF"]) > 0) print l; next}
  inb { if ($0==ENVIRON["END"]) inb=0; next }
  $0==ENVIRON["DONE_T"] {print "    done"; tail=1; next}
  tail && ($0 ~ /^#/ || $0=="exit 0") {next}
  {print}'
  d="$(START='ud_scan_why=""' END='while IFS= read -r cp; do' NEWF="$U_BASE_F" DONE_T='    done < "$UD_DIFF_TMP/scan-set"' \
       mut M-U-base "$UD" "$U_BASE_PROG" "  | grep -E '\\.(md|sh|json)\$' \\" 'ud_scan_why' \
         'ud_scan_why=""' 'while IFS= read -r cp; do' '    done < "$UD_DIFF_TMP/scan-set"' 'exit 0')" \
    && { score_as M-U-base ud "$d" U1=RC1-NOROW U2=RC1-NOROW U2b=SCANNED U3=RC2-NOROW U4=SCANNED U5=CLOSED-RC1
         # THE HEALTHY PATH IS BYTE-IDENTICAL TO THE BASE SPELLING, on both worlds that scan a file.
         # The two sides are asserted to DIFFER first, or the comparison reads the same program twice.
         for _w in "$UW_OK" "$UW_HU"; do
           _a="$("$REAL_BASH" "$RECON/$UD" "$_w/dist" "$(cat "$_w/B")" "$_w/consumer" "$(cat "$_w/T")" 2>/dev/null)"
           _b="$("$REAL_BASH" "$d/$UD" "$_w/dist" "$(cat "$_w/B")" "$_w/consumer" "$(cat "$_w/T")" 2>/dev/null)"
           if cmp -s "$RECON/$UD" "$d/$UD"; then bad "U healthy differential: the two unregistered-drift.sh copies are identical, so the comparison reads one program twice"
           elif [ -n "$_a" ] && [ "$_a" = "$_b" ]; then ok "U healthy ($(basename "$_w")): the staged listing prints byte-identical rows to the base pipeline ($(cut -f1 <<<"$_a" | tr '\n' ' '))"
           else bad "U healthy ($(basename "$_w")): the staged listing and the base pipeline disagree on a world both can scan (tip [$(cut -f1 <<<"$_a" | tr '\n' ' ')] base [$(cut -f1 <<<"$_b" | tr '\n' ' ')])"; fi
         done; } \
    || mutreport M-U-base
# M-U-exit: the explicit `exit 0` deleted. U1 CANNOT kill it -- a staged empty scan set runs the
# loop zero times and exits 0 without that line -- so its killer is U5, the failed last write.
  d="$(mut M-U-exit "$UD" '$0=="exit 0" {next} {print}' '    done < "$UD_DIFF_TMP/scan-set"' - 'exit 0')" \
    && score M-U-exit U5 "$d" \
    || mutreport M-U-exit
# M-U-memo: the memo branch's status unread, so a failed memo listing is taken as an empty one and
# the direct listing is never tried. U2 reads EMPTY -- the silent clear, not the base's rc 1 -- and
# U2b, the near-miss whose direct listing WOULD have answered, reads EMPTY too: both own it.
  d="$(DROP1="$N0" DROP2="$N0" OLD='    ud_memo_rc=$?' NEW='    ud_memo_rc=0' \
       mut M-U-memo "$UD" "$SWAP" '    ud_memo_rc=0' 'ud_memo_rc=$?' '    ud_memo_rc=$?')" \
    && score_as M-U-memo ud "$d" U2=EMPTY U2b=EMPTY \
    || mutreport M-U-memo
# M-U-ext / M-U-pfx: a grep status >1 accepted as "no match", one filter each.
  d="$(DROP1="$N0" DROP2="$N0" OLD='    [ "$ud_rc" -le 1 ] || ud_scan_why="the file-type filter over the tree listing exited ${ud_rc}"' NEW='    : ZZ-PSB-M-UEXT' \
       mut M-U-ext "$UD" "$SWAP" '    : ZZ-PSB-M-UEXT' 'the file-type filter over the tree listing exited' \
         '    [ "$ud_rc" -le 1 ] || ud_scan_why="the file-type filter over the tree listing exited ${ud_rc}"')" \
    && score_as M-U-ext ud "$d" U3=EMPTY \
    || mutreport M-U-ext
  d="$(DROP1="$N0" DROP2="$N0" OLD='      [ "$ud_rc" -le 1 ] || ud_scan_why="the scan-set prefix filter over the cached tree listing exited ${ud_rc}"' NEW='      : ZZ-PSB-M-UPFX' \
       mut M-U-pfx "$UD" "$SWAP" '      : ZZ-PSB-M-UPFX' 'the scan-set prefix filter over the cached tree listing exited' \
         '      [ "$ud_rc" -le 1 ] || ud_scan_why="the scan-set prefix filter over the cached tree listing exited ${ud_rc}"')" \
    && score_as M-U-pfx ud "$d" U4=EMPTY \
    || mutreport M-U-pfx

# apply.sh: each site's exit read turned off, one copy per site. The other four A arms must stay
# REFUSED, so a mutant cannot be killed by an arm that watches a different detector.
AP=apply.sh
ap_off() { # <mutant> <own-arm> <indent> <line-literal> <staged-token>
  local d
  d="$(DROP1="$N0" DROP2="$N0" OLD="$3$4" NEW="${3}if false; then" \
       mut "$1" "$AP" "$SWAP" "${3}if false; then" "$5" "$3$4")" \
    && score "$1" "$2" "$d" \
    || mutreport "$1"
}
ap_off M-Aud  Aud  ''       'if [ "$UD_RC" -ne 0 ]; then'         'UD_RC" -ne 0'
ap_off M-Art  Art  '      ' 'if [ "$rt_rc" -ne 0 ]; then'         'rt_rc" -ne 0'
ap_off M-Arlp Arlp ''       'if [ "${RLP_RC:-0}" -ne 0 ]; then'   'RLP_RC:-0}" -ne 0'
ap_off M-Ald  Ald  ''       'if [ "$LD_RC" -ne 0 ]; then'         'LD_RC" -ne 0'
ap_off M-Ana  Ana  '  '     'if [ -n "$UD_NA" ]; then'            'if [ -n "$UD_NA" ]; then'
# M-Art-merge: the refusal branch stops emitting the merge row. The row is spelled identically in the
# refusal branch and the plain branch, so the mutation anchors on what SEPARATES them: the line
# directly after the refusal test.
  d="$(mut M-Art-merge "$AP" '{ if (skip && $0=="        say WORKLIST semantic-merge \"$rel\"") { skip=0; next } skip=0 }
       $0=="      if [ \"$rt_rc\" -ne 0 ]; then" {skip=1} {print}' \
         '        detector_refused retired-tokens retired-tokens.sh "$rel" "$rt_rc" rt' - \
         '      if [ "$rt_rc" -ne 0 ]; then' '        detector_refused retired-tokens retired-tokens.sh "$rel" "$rt_rc" rt')" \
    && { _h="$("$REAL_GREP" -cxF '        say WORKLIST semantic-merge "$rel"' "$d/$AP")" || _h=0
         if [ "$_h" -eq 1 ]; then score_as M-Art-merge ap "$d" Art=REFUSED-NOMERGE
         else bad "MUTANT DID NOT APPLY [M-Art-merge]: the plain merge row is present $_h time(s) in the copy, want 1 (the refusal branch's removed, the plain branch's kept)"; fi; } \
    || mutreport M-Art-merge

echo
if [ "$fails" -eq 0 ]; then
  echo "procsub-staged-refusal-boot: PASS"
  exit 0
fi
echo "procsub-staged-refusal-boot: FAIL ($fails assertion(s))" >&2
exit 1
