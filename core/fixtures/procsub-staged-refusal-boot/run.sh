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
for _s in ledger-reverify.sh preclassify.sh emit-report.sh self-update-gate.sh lib.sh; do
  [ -f "$RECON/$_s" ] || { echo "FIXTURE ERROR: reconcile/$_s is missing beside ledger-reverify.sh" >&2; exit 2; }
done
SIB="$HERE/../reconcile-emit-report"
[ -f "$SIB/seed.sh" ] || { echo "FIXTURE ERROR: sibling reconcile-emit-report/seed.sh not found beside this unit" >&2; exit 2; }

REAL_TR="$(command -v tr)"; REAL_GIT="$(command -v git)"; REAL_FIND="$(command -v find)"
REAL_SED="$(command -v sed)"; REAL_COMM="$(command -v comm)"; REAL_GREP="$(command -v grep)"
for _b in "$REAL_TR" "$REAL_GIT" "$REAL_FIND" "$REAL_SED" "$REAL_COMM" "$REAL_GREP"; do
  case "$_b" in /*) ;; *) echo "FIXTURE ERROR: tr/git/find/sed/comm/grep must resolve to binaries on PATH (got '$_b'), or no stub can pass through" >&2; exit 2 ;; esac
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
  esac
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
  und_row="$(awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" && $3 ~ /could not be computed/' <<<"$out" | "$REAL_GREP" -c .)" || und_row=0
  if [ "$rc" -ne 0 ] || [ -z "$v" ]; then echo "OTHER(rc=$rc,record=${v:-none})"
  elif [ "$v" = OK ] && [ "$n_ok" -gt 0 ] && [ "$n_def" -eq 0 ] && [ "$n_und" -eq 0 ]; then echo OK
  elif [ "$v" != OK ] && [ "$und_row" -gt 0 ] && [ "$n_ok" -eq 0 ]; then echo "UNDECIDED-UNCOMPUTED/$v"
  elif [ "$v" = DEFER ] && [ "$n_und" -eq 0 ] && [ "$n_ok" -eq 0 ]; then echo DEFER
  else echo "OTHER(record=$v,ok=$n_ok,defer=$n_def,undecided=$n_und)"
  fi
}

# === ONE ARM ======================================================================================
# arm_shape <arm> <recon> <stub-dir or -> -> the shape
arm_shape() {
  case "$1" in
    L1|L2|L3) lr_shape "$2" "$1" "$3" ;;
    P1) pc_shape "$2" "$3" ;;
    E1) er_shape "$2" "$3" ;;
    S1|S2) sg_shape "$2" "$1" "$3" ;;
  esac
}
# THE EXPECTATION TABLE. <arm> <key> <control shape> <tip shape> <base shape>
EXPECT='L1 lr NEEDS-REVIEW-ABSENT REFUSED-ABSENT CLOSE-CANDIDATE
L2 lr NEEDS-REVIEW-UNFALSIFIABLE REFUSED-NAMED STILL-LIVE-NO-SUBJECT
L3 lr NEEDS-REVIEW-UNFALSIFIABLE STILL-LIVE-LSTREE-FAILED STILL-LIVE-CONSUMER-OWNED
P1 pc ORPHAN-ROWS REFUSED NO-ORPHAN-ROWS
E1 er UNDECIDED-DIFF UNDECIDED-UNCOMPUTED BLOCKERS-RESOLVED
S1 sg DEFER UNDECIDED-UNCOMPUTED/DEFER OK
S2 sg DEFER UNDECIDED-UNCOMPUTED/UNDECIDED OK'
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
for A in L1 L2 L3 P1 E1 S1 S2; do
  c="$(arm_shape "$A" "$RECON" -)"
  if [ "$c" = "$(col "$A" 3)" ]; then
    ok "$A control (no stub): $c -- the world expresses the healthy verdict"
  else
    bad "$A control (no stub): $c, expected $(col "$A" 3) -- the world does not express the case, so the forced arm below is unattributable"
  fi
  set -- $(forced "$A" "$RECON" tip)
  if [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 4)" ]; then
    ok "$A forced (stub fired ${2}x): $1 -- the failed producer is refused, never read as empty (base spelling reads $(col "$A" 5))"
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
  h="$("$REAL_GREP" -cF -- "$staged" "$d/$s")" || h=0
  [ "$h" -eq 0 ] || { mutbad "MUTANT PARTIAL [$n]: the staged spelling '$staged' survives $h time(s) -- a partial revert proves the layer left in place"; return 1; }
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
  case "$got_own" in
    '!'*) bad "MUTANT SURVIVED [$m]: arm $own read ${got_own#!}, expected the base shape $(col "$own" 5) -- the arm cannot see its own site revert" ;;
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

echo
if [ "$fails" -eq 0 ]; then
  echo "procsub-staged-refusal-boot: PASS"
  exit 0
fi
echo "procsub-staged-refusal-boot: FAIL ($fails assertion(s))" >&2
exit 1
