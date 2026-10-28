#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Exercise validate-adversarial-convergence.sh against the check-24 fixture.
#
# Exit 0 iff the validator returns the correct verdict on every seeded series.
#
# TWO CASES DECIDE SHIPPABILITY, and they pull in opposite directions:
#
#   nitpicks-remain    must PASS. A naive "the last pass must have zero findings"
#                      implementation fails it, and in doing so makes the exit condition
#                      "continue until only nitpicks remain" unreachable -- the v0.46.0
#                      defect, reintroduced one layer down.
#   divergent-resolved must PASS. It is the SANCTIONED EXIT from a hard block, and before
#                      v0.59.0 it did not exist: arm D demanded a terminal clean pass while
#                      the Stop hook's deny reason said "do NOT dispatch another adversarial
#                      pass, and do NOT clear the pause flag to get past this." If this case
#                      goes red, the deadlock is back.
#
# AND A RULE ABOUT HOW THIS FILE ASSERTS. Several v0.59.0 cases exit 1 BOTH before and after
# the fix -- `stalled-then-diverges` exits 1 today via arm D alone and exits 1 after via arms
# D and E. A fixture that checked only the exit code would score a FALSE PASS against the
# broken validator. That is this repo's own defect class (a check that cannot fire reads
# exactly like one that passed) reproduced inside the test written to catch it. So: every
# v0.59.0 case asserts on the MESSAGE.
set -u
# Scrub ambient AI_DLC_* — the live-series arm below reads an expression out of a shipped
# hook, and a consumer that tunes any AI_DLC_* variable in settings.json would otherwise
# fail this fixture against a hook behaving correctly, wedging its pre-push on every push.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-adversarial-convergence.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-adversarial-convergence.sh" \
  "$DIR/../../core/scripts/validate-adversarial-convergence.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FAIL: cannot locate validate-adversarial-convergence.sh from $DIR"
  exit 1
fi

# ---------------------------------------------------------------------------- shards ----
# THIS FILE IS FOUR SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY. Every section below is a UNIT guarded by `if sg <unit>; then ... fi`; `--group <x>` runs
# the units dealt to shard <x>. The three siblings `check-24-adversarial-convergence-{b,c,d}/run.sh` are
# one-line drivers that `exec bash` this file with their group (the readset-skip shape), so the pre-push
# pool can start each on its own and the suite's makespan stops tracking one 2600-line directory. No
# `--group` runs shard 'a', so `bash core/fixtures/check-24-adversarial-convergence/run.sh` is shard a.
#
# THE SEED, THE VALIDATOR LOOKUP AND THE SHARED HELPERS ARE NOT UNITS: every shard pays them, because a
# shard that skipped them would score its cases against a harness that never ran.
#
# THE COVERAGE JOIN runs in EVERY shard before anything else: the declared units are DERIVED from this
# file's own `if sg <unit>; then` lines, the dealt lists must be disjoint and their union must equal the
# declared set exactly, so no unit can fall out of every shard, and every declared shard must have a
# driver directory. The join proves it can fire first, on a seeded duplicate and a seeded omission.
#   a  core corp pair tstrat   the v0.52-v0.103 cases, --cycle-state and the stall exit, the corpus third state, pairing, the test-strategy series (BL-723)
#   b  hook k2 elic j3  the live-series derivation, H-BIND, exit ceiling, arm K, arm K2 and its mutants, arm L, arm J3 (BL-814)
#   c  arms_ij pass1 j2h  arm J and I, the pass-1 guard, arm J2 and J's door, arm H by series
#   d  k3               arm K3, K3 widened, J2 per stem, K3 cross groups (every world a git repository)
SHARDS="a b c d"
UNITS_a="core corp pair tstrat"
UNITS_b="hook k2 elic j3"
UNITS_c="arms_ij pass1 j2h"
UNITS_d="k3"
GROUP=a
# --matrix: run every mutant against every arm (the mutant-matrix measurement). Taken as an ARGUMENT, never
# from the environment: hermetic-run.sh runs a fixture under `env -i`, so an env-var mode would silently
# never arrive and the run would read green on the per-push subset.
MATRIX_ARG=0; GROUP_SET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --group) GROUP="${2:-}"; GROUP_SET=1; [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }; shift 2 ;;
    --matrix) MATRIX_ARG=1; shift ;;
    *) echo "FIXTURE ERROR: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
# `--matrix` with no `--group` measures EVERY shard, one after another, so the one re-measure command covers
# the whole battery. Each shard is its own process and prints its own `MATRIX MODE: on` line.
if [ "$MATRIX_ARG" = 1 ] && [ "$GROUP_SET" = 0 ]; then
  mx_rc=0
  for mx_g in $SHARDS; do bash "$0" --group "$mx_g" --matrix || mx_rc=1; done
  exit "$mx_rc"
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
NAME="check-24-adversarial-convergence"; [ "$GROUP" = a ] || NAME="check-24-adversarial-convergence-$GROUP"
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
[ -n "$MINE" ] || broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
SELF="$0"
[ -f "$SELF" ] || broken "cannot read $SELF for the coverage join"
partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/check24-join.XXXXXX")" || broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  rm -rf "$JW"; broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$SELF" > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  rm -rf "$JW"; broken "$ndecl unit guards derived from $SELF ($ndupdecl declared twice)"
fi
if ! _why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  rm -rf "$JW"; broken "the shard partition does not cover the guarded units exactly -- $_why"
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$DIR/../check-24-adversarial-convergence-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    rm -rf "$JW"; broken "shard '$_s' is declared but $_drv does not drive it"
  fi
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"
ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT

# The transcript the RESOLUTION citations (arm F6) verify against. Every invocation passes
# it, exactly as the real Check 24 gate and the acknowledge hook do -- a resolution clears an
# operator-gated HARD_BLOCK, so the gate must be handed the ground truth to check the citation.
TRANSCRIPT="$ROOT/operator-transcript.jsonl"

FAILURES=0
ASSERTIONS=0

# ------------------------------------------------------------------------------ vrun ----
# THE PER-RUN MEMO. Most arms in a unit ask the SAME (program, series, flags) question and read a
# different property of the one answer: `expect` reads the exit, `expect_says` the message,
# `expect_silent` re-asks a control another arm already asked. The program is deterministic over a
# seeded tree that nothing rewrites, so each distinct question is executed ONCE and every arm reads
# exit and output off that one execution.
#
# THE KEY IS WHAT STOPS A MUTANT READING THE ORIGINAL'S ANSWER (fixture-mutants.md: a cached subject
# scores every mutant SURVIVED, and the key will not say so). It hashes the stream mode, the script's
# RESOLVED PATH (a copy in a directory missing a sibling is a different program from the shipped one
# even when its bytes are equal), TMPDIR, every argument, and the script's full CONTENT. A mutant has
# different bytes, so it can never share an entry with its control; a control copy has a different
# path, so it never shares one with the shipped validator either. vrun takes no environment
# overrides: a call that needs one (GIT_CEILING_DIRECTORIES, TMPDIR=) stays a direct `bash`.
#
# THE MODE IS PART OF THE ANSWER. `both` is `2>&1`, `out` is `2>/dev/null`, `split` keeps stdout in
# VR_OUT and stderr in VR_ERR -- exactly the shapes the arms used before. An interleaved stream cannot
# be rebuilt from two separate captures, so no mode is ever derived from another.
#
# THE KEY DOES NOT COVER THE TREE. A series is named by path, so an arm that EDITS a world and asks the
# same path again (the hook unit's live-series arm removes its decoy and re-asks) must call `bash`
# directly. vrun is for trees nothing rewrites after the first question -- the seeded $ROOT, and any
# world a unit builds once and then only reads.
#
# Usage: vrun <both|out|split> <script> <args...>  -> sets VR_OUT (as `$(...)` would), VR_ERR, VR_RC.
# The validator's siblings: copied beside every mutant by rcpt_mut, and hashed into every memo key.
RCPT_SIBS="validate-steering-budget.sh partition-document.sh partition-subject.sh merge-adversarial-shards.sh validate-artifact-budget.sh validate-provenance-block.sh"
VMEMO_DIR="$ROOT/.vmemo"
mkdir -p "$VMEMO_DIR" || broken "cannot create the memo directory under $ROOT"
vrun() {
  local mode="$1" script="$2" key f
  shift 2
  case "$mode" in both|out|split) ;; *) broken "vrun: unknown mode '$mode'" ;; esac
  [ -f "$script" ] || broken "vrun: no script at $script"
  # The SIBLINGS are hashed too: a mutant of partition-document.sh or of the steering predicate leaves
  # the validator's bytes alone and changes only the file beside it, so a key on the script alone would
  # hand that mutant its control's answer.
  local sd s
  sd="$(cd "$(dirname "$script")" && pwd -P)" || broken "vrun: cannot resolve $script"
  key="$( { printf '%s\0' "$mode" "$sd/${script##*/}" "${TMPDIR:-}" "$@"; cat "$script"
            for s in $RCPT_SIBS; do printf '\0%s\0' "$s"; [ -f "$sd/$s" ] && cat "$sd/$s"; done; } | shasum -a 256)" \
    || broken "vrun: could not key $script"
  f="$VMEMO_DIR/${key%% *}"
  if [ ! -f "$f.rc" ]; then
    case "$mode" in
      both)  bash "$script" "$@" > "$f.out" 2>&1 ;;
      out)   bash "$script" "$@" > "$f.out" 2>/dev/null ;;
      split) bash "$script" "$@" > "$f.out" 2> "$f.err" ;;
    esac
    printf '%s\n' "$?" > "$f.rc"
  fi
  VR_OUT="$(cat "$f.out")"
  VR_ERR=""; [ "$mode" = split ] && VR_ERR="$(cat "$f.err")"
  VR_RC="$(cat "$f.rc")"
}
# THE MEMO PROVES IT CAN SEPARATE TWO PROGRAMS before any arm reads it: two scripts that differ in one
# byte at the same path, asked the same question, must answer differently; asked twice, the same
# script must execute once. A key that dropped the content would pass the second and fail the first.
# A THIRD arm proves a SIBLING-only change is a different program: the probe reads a sibling named in
# RCPT_SIBS, and rewriting only that sibling must re-execute.
mkdir -p "$ROOT/.vmemo-probe" || broken "cannot create the memo probe directory"
VMEMO_PROBE="$ROOT/.vmemo-probe/p.sh"
VMEMO_SIB="$ROOT/.vmemo-probe/${RCPT_SIBS%% *}"
# Builtins only: the sandbox PATH holds the declared tools and nothing else.
printf '#!/usr/bin/env bash\nn=0; [ -f "%s" ] && read -r n < "%s"; echo "$((n + 1))" > "%s"; read -r s < "%s"; echo "A$s"\n' \
  "$ROOT/.vmemo-probe.n" "$ROOT/.vmemo-probe.n" "$ROOT/.vmemo-probe.n" "$VMEMO_SIB" > "$VMEMO_PROBE"
echo 1 > "$VMEMO_SIB"
vrun both "$VMEMO_PROBE" q; vp1="$VR_OUT"
vrun both "$VMEMO_PROBE" q; vp2="$VR_OUT"
vp_n="$(cat "$ROOT/.vmemo-probe.n" 2>/dev/null)"
echo 2 > "$VMEMO_SIB"
vrun both "$VMEMO_PROBE" q; vp4="$VR_OUT"
printf '#!/usr/bin/env bash\necho B\n' > "$VMEMO_PROBE"
vrun both "$VMEMO_PROBE" q; vp3="$VR_OUT"
if [ "$vp1" != A1 ] || [ "$vp2" != A1 ] || [ "$vp_n" != 1 ] || [ "$vp4" != A2 ] || [ "$vp3" != B ]; then
  broken "the memo self-probe did not discriminate (first '$vp1', repeat '$vp2', executions '$vp_n', sibling changed '$vp4', script changed '$vp3' want A1 A1 1 A2 B)"
fi
echo "  [M0] memo: one execution per (mode, resolved path, TMPDIR, args, content, sibling content); a one-byte change is a different program"

# $1 case-dir  $2 expected exit (0|1)  $3 why  $4 (optional) series prefix
expect() {
  local case_dir="$1" want="$2" why="$3" prefix="${4:-s1-adversarial-pass}" got out
  ASSERTIONS=$((ASSERTIONS + 1))
  vrun both "$VALIDATOR" --series "$ROOT/$case_dir/$prefix" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT"
  out="$VR_OUT"; got="$VR_RC"
  if [ "$got" -eq "$want" ]; then
    printf '  ok    %-28s exit=%s  (%s)\n' "$case_dir" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s  (%s)\n' "$case_dir" "$got" "$want" "$why"
    printf '%s\n' "$out" | sed 's/^/          | /'
  fi
}

# $1 case-dir  $2 series prefix  $3 label  $4... required substrings (ALL must appear)
# The exit code is NOT the assertion here -- the message is. See the header.
expect_says() {
  local case_dir="$1" prefix="$2" label="$3"; shift 3
  local out missing=""
  ASSERTIONS=$((ASSERTIONS + 1))
  vrun both "$VALIDATOR" --series "$ROOT/$case_dir/$prefix" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT"
  out="$VR_OUT"
  for want in "$@"; do
    grep -qF -- "$want" <<<"$out" || missing="$missing
            missing: \"$want\""
  done
  if [ -z "$missing" ]; then
    printf '  ok    %-28s %s\n' "$label" "says what it must"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s\n' "$label" "the right exit code for the WRONG reason:$missing"
  fi
}

# $1 case-dir  $2 series prefix  $3 expected STATE  $4 expected exit  $5 why
expect_state() {
  local case_dir="$1" prefix="$2" want_state="$3" want_rc="$4" why="$5" out state rc
  ASSERTIONS=$((ASSERTIONS + 1))
  vrun out "$VALIDATOR" --series "$ROOT/$case_dir/$prefix" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT"
  out="$VR_OUT"; rc="$VR_RC"
  state="$(printf '%s' "$out" | cut -f1)"
  if [ "$state" = "$want_state" ] && [ "$rc" -eq "$want_rc" ]; then
    printf '  ok    %-28s %s/%s  (%s)\n' "$case_dir" "$state" "$rc" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s/%s want=%s/%s  (%s)\n' \
      "$case_dir" "${state:-<none>}" "$rc" "$want_state" "$want_rc" "$why"
  fi
}

# The validator as a resolved path, so the sentinel below is spelled without any `..`.
VALIDATOR="$(cd "$(dirname "$VALIDATOR")" && pwd -P)/$(basename "$VALIDATOR")"
# The REQUIRED input of inputs.decl: every assertion drives this file. Printed in whichever layout holds it.
case "$VALIDATOR" in
  */core/scripts/validate-adversarial-convergence.sh)       echo "HERMETIC-CONSUMED core/scripts/validate-adversarial-convergence.sh" ;;
  */scripts/ai-dlc/validate-adversarial-convergence.sh)     echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-adversarial-convergence.sh" ;;
esac

# SHARED BY MORE THAN ONE UNIT, so they live here and not inside a unit that may be dealt elsewhere.
D_GENERIC="Do not pass the gate by overriding the field in prose."

# AN ABSENCE ASSERTION CARRIES ITS CONTROL IN THE SAME INVOCATION -- the token must be
# missing from the subject AND present in a case that must emit it, or a validator that
# stopped emitting the token at all passes every negative arm below.
expect_silent() {  # $1 case-dir  $2 token  $3 control-dir  $4 why-it-must-be-silent
  local out ctl
  # The control is usually a series another arm already asked; the memo answers it from that run.
  vrun both "$VALIDATOR" --series "$ROOT/$1/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT"
  out="$VR_OUT"
  vrun both "$VALIDATOR" --series "$ROOT/$3/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT"
  ctl="$VR_OUT"
  ASSERTIONS=$((ASSERTIONS + 1))
  if grep -qF -- "$2" <<<"$out"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s fired where it must be SILENT -- %s\n' "$1" "$2" "$4"
  elif ! grep -qF -- "$2" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s CONTROL: %s absent from %s too -- the negative assertion is vacuous\n' "$1" "$2" "$3"
  else
    printf '  ok    %-28s %s silent here, present in %s (control)\n' "$1" "$2" "$3"
  fi
}

# K2 asks partition-document.sh, a SIBLING of the validator, whether the document partitions. Read by
# the k2 and k3 units (different shards), so it is resolved here. Its absence is refused loudly.
K2_PD="$(cd "$(dirname "$VALIDATOR")" && pwd)/partition-document.sh"
if [ ! -f "$K2_PD" ]; then
  echo "FIXTURE BROKEN: partition-document.sh is not beside $VALIDATOR -- arm K2 cannot be scored"
  exit 1
fi
# THE BACKLOG RECEIPTS AS ARMS (BL-733 in unit elic, BL-736 in unit j2h): each receipt builds its own
# worlds and drives the validator it is handed, so the arm is the receipt against the shipped
# validator, an UNMUTATED COPY (presence-shaped: it must print `fixed`), and each mutant, built in a
# copy of the validator's whole directory so its siblings resolve. Worlds land under $ROOT.
# RCPT_SIBS is defined beside the memo above, which hashes the same set.
#
# THE RECEIPT MUTANT MATRIX (mutant-battery rule). A receipt judges N worlds; a mutant's DECIDING ARM is
# the set of worlds its exact NOT FIXED line names, and its TWIN is ONE further world it could plausibly
# co-trip and does NOT -- the near-miss beside its subject. The matrix (every mutant against every
# world) was measured once, and every mutant's twin was GREEN in it; the twin column below is that
# measurement, and the exact-line match in rcpt_cell is what proves the twin stayed green on each push.
#
# PER PUSH (the default): the shipped validator and the unmutated control judge EVERY world -- that is
# the receipt's own verdict and the copy-tree control. Each mutant judges only its deciding worlds plus
# its twin (RCPT_WORLDS), against worlds built ONCE per receipt and release (RCPT_WORLD_DIR), never once
# per mutant. A mutant that crashes the validator flips its twin too, so the exact line still refuses it.
#
# RE-MEASURE THE MATRIX whenever an arm, a world or a mutant is added or changed, from the repo root, by
# invoking run.sh DIRECTLY (hermetic-run.sh runs a fixture under `env -i` and forwards no argument, so a
# matrix run through it would silently be a per-push run):
# MUTANT-MATRIX-REMEASURE bash core/fixtures/check-24-adversarial-convergence/run.sh --matrix
# With no --group it runs every shard in turn; the log must carry `MATRIX MODE: on` once per shard. Every
# mutant then scores every cell and every receipt world; each row must still equal its want row, which is
# the proof every twin stayed green. A run WITHOUT --matrix scores no matrix-only cell: arm MX0 counts the
# cells each mutant skipped and refuses a per-push run that skipped none.
# MUTANT-MATRIX-BEGIN -- the matrix, measured by the MUTANT-MATRIX-REMEASURE command above: every shard printed
# `MATRIX MODE: on`, every mutant row equalled its want row, 0 FAIL. A row is `<mutant> decides=<arm>.<cell>
# twins=<arm>.<cell>`: the arm is the mutant's own `ok` label (slugged: any character outside [A-Za-z0-9_-]
# becomes `-`), the deciding cells are the cells (1-based in the row) or receipt worlds whose verdict the
# mutant flips, and each twin is a cell of the same arm, beside the subject, GREEN in the matrix and run on
# every push. Re-measure whenever an arm, a world or a mutant is added or changed.
# MUTANT-MATRIX MUTATION-chrono-raw-string decides=MUTATION-chrono-raw-string.cell1,MUTATION-chrono-raw-string.cell2 twins=MUTATION-chrono-raw-string.cell3
# MUTANT-MATRIX MUTATION-chrono-strip-z decides=MUTATION-chrono-strip-z.cell3 twins=MUTATION-chrono-strip-z.cell2
# MUTANT-MATRIX MUTATION-chrono-arm-g-off decides=MUTATION-chrono-arm-g-off.cell2 twins=MUTATION-chrono-arm-g-off.cell1
# MUTANT-MATRIX MUTATION-over-broad decides=MUTATION-over-broad.cell3,MUTATION-over-broad.cell4,MUTATION-over-broad.cell5 twins=MUTATION-over-broad.cell2
# MUTANT-MATRIX MUTATION-disabled decides=MUTATION-disabled.cell2 twins=MUTATION-disabled.cell1
# MUTANT-MATRIX MUTATION-token-on-both decides=MUTATION-token-on-both.cell3,MUTATION-token-on-both.cell4 twins=MUTATION-token-on-both.cell2
# MUTANT-MATRIX MUTATION-since-acquitted decides=MUTATION-since-acquitted.cell5 twins=MUTATION-since-acquitted.cell4
# MUTANT-MATRIX MUTATION-k2-stamp-gate decides=MUTATION-k2-stamp-gate.cell2 twins=MUTATION-k2-stamp-gate.cell1
# MUTANT-MATRIX MUTATION-k2-serial-check decides=MUTATION-k2-serial-check.cell3 twins=MUTATION-k2-serial-check.cell2
# MUTANT-MATRIX MUTATION-k2-sha-gate decides=MUTATION-k2-sha-gate.cell5 twins=MUTATION-k2-sha-gate.cell4
# MUTANT-MATRIX MUTATION-k2-current-map-revert decides=MUTATION-k2-current-map-revert.cell1,MUTATION-k2-current-map-revert.cell2,MUTATION-k2-current-map-revert.cell4,MUTATION-k2-current-map-revert.cell5,MUTATION-k2-current-map-revert.cell6 twins=MUTATION-k2-current-map-revert.cell3
# MUTANT-MATRIX MUTATION-k2-fallback-unmarked decides=MUTATION-k2-fallback-unmarked.cell4 twins=MUTATION-k2-fallback-unmarked.cell3
# MUTANT-MATRIX MUTATION-k2-first-pass-time decides=MUTATION-k2-first-pass-time.cell3 twins=MUTATION-k2-first-pass-time.cell2
# MUTANT-MATRIX MUTATION-k2-added-commit-dropped decides=MUTATION-k2-added-commit-dropped.cell5,MUTATION-k2-added-commit-dropped.cell6 twins=MUTATION-k2-added-commit-dropped.cell4
# MUTANT-MATRIX J3-1-keyed-on-blocking decides=J3-1-keyed-on-blocking.underonly twins=J3-1-keyed-on-blocking.undeferred
# MUTANT-MATRIX J3-2-bare-finding-id decides=J3-2-bare-finding-id.undeferred,J3-2-bare-finding-id.stalepass,J3-2-bare-finding-id.twof1,J3-2-bare-finding-id.ident,J3-2-bare-finding-id.partlink,J3-2-bare-finding-id.seriallink,J3-2-bare-finding-id.dupid twins=J3-2-bare-finding-id.deferred
# MUTANT-MATRIX J3-3-any-deferred-to decides=J3-3-any-deferred-to.wrongstep,J3-3-any-deferred-to.nosucc twins=J3-3-any-deferred-to.deferred
# MUTANT-MATRIX J3-4-era-on-presence decides=J3-4-era-on-presence.legacy twins=J3-4-era-on-presence.undeferred
# MUTANT-MATRIX J3-5-any-pass-s-record decides=J3-5-any-pass-s-record.stalepass twins=J3-5-any-pass-s-record.repaired
# MUTANT-MATRIX J3-6-dispatch-narrowed-to-one-digit decides=J3-6-dispatch-narrowed-to-one-digit.p12 twins=J3-6-dispatch-narrowed-to-one-digit.undeferred
# MUTANT-MATRIX J3-7-dispatch-widened-digits-guard-gone decides=J3-7-dispatch-widened-digits-guard-gone.pxp2 twins=J3-7-dispatch-widened-digits-guard-gone.ptxt
# MUTANT-MATRIX J3-8-successor-substring decides=J3-8-successor-substring.substr twins=J3-8-successor-substring.subok
# MUTANT-MATRIX J3-9-identity-triple-links decides=J3-9-identity-triple-links.ident twins=J3-9-identity-triple-links.repaired
# MUTANT-MATRIX J3-10-one-link-closes-all decides=J3-10-one-link-closes-all.partlink,J3-10-one-link-closes-all.seriallink twins=J3-10-one-link-closes-all.unlinked
# MUTANT-MATRIX J3-11-heading-id-read-raw decides=J3-11-heading-id-read-raw.dupid,J3-11-heading-id-read-raw.idpunct twins=J3-11-heading-id-read-raw.deferbold
# MUTANT-MATRIX J3-12-keys-counted-with-repeats decides=J3-12-keys-counted-with-repeats.dupid twins=J3-12-keys-counted-with-repeats.unkeyed
# MUTANT-MATRIX J3-13-remedy-says-write decides=J3-13-remedy-says-write.undeferred twins=J3-13-remedy-says-write.wrongstep
# MUTANT-MATRIX LX1-map-staged-on-nothing decides=LX1-map-staged-on-nothing.cell1,LX1-map-staged-on-nothing.cell2,LX1-map-staged-on-nothing.cell4,LX1-map-staged-on-nothing.cell5,LX1-map-staged-on-nothing.cell6,LX1-map-staged-on-nothing.cell7,LX1-map-staged-on-nothing.cell8,LX1-map-staged-on-nothing.cell9 twins=LX1-map-staged-on-nothing.cell3
# MUTANT-MATRIX LX2-ordinals-not-de-padded decides=LX2-ordinals-not-de-padded.cell1 twins=LX2-ordinals-not-de-padded.cell2
# MUTANT-MATRIX LX3-recorded-K-ignored decides=LX3-recorded-K-ignored.cell3,LX3-recorded-K-ignored.cell4 twins=LX3-recorded-K-ignored.cell2
# MUTANT-MATRIX LX4-recorded-K-acquits-all decides=LX4-recorded-K-acquits-all.cell4 twins=LX4-recorded-K-acquits-all.cell3
# MUTANT-MATRIX LX5-smaller-recorded-K-honoured decides=LX5-smaller-recorded-K-honoured.cell5 twins=LX5-smaller-recorded-K-honoured.cell4
# MUTANT-MATRIX LX6-subject-cover-dropped decides=LX6-subject-cover-dropped.cell6,LX6-subject-cover-dropped.cell9 twins=LX6-subject-cover-dropped.cell5
# MUTANT-MATRIX LX7-equality-honoured decides=LX7-equality-honoured.cell7,LX7-equality-honoured.cell8 twins=LX7-equality-honoured.cell6
# MUTANT-MATRIX LX8-sprint-scope-dropped decides=LX8-sprint-scope-dropped.cell9 twins=LX8-sprint-scope-dropped.cell8
# MUTANT-MATRIX LM1-lone-cross-refused decides=LM1-lone-cross-refused.cell1 twins=LM1-lone-cross-refused.cell2
# MUTANT-MATRIX LM2-any-cross-subset-accepted decides=LM2-any-cross-subset-accepted.cell3 twins=LM2-any-cross-subset-accepted.cell2
# MUTANT-MATRIX LM3-delta-owes-no-cross decides=LM3-delta-owes-no-cross.cell5 twins=LM3-delta-owes-no-cross.cell4
# MUTANT-MATRIX LD1-owed-groups-by-index-diff decides=LD1-owed-groups-by-index-diff.nodelta,LD1-owed-groups-by-index-diff.fullg,LD1-owed-groups-by-index-diff.nocross,LD1-owed-groups-by-index-diff.xnamed twins=LD1-owed-groups-by-index-diff.full
# MUTANT-MATRIX LD2-cross-names-acquit-ordinals decides=LD2-cross-names-acquit-ordinals.xnamed twins=LD2-cross-names-acquit-ordinals.nodelta
# MUTANT-MATRIX MUTATION-kind decides=MUTATION-kind.cell2 twins=MUTATION-kind.cell1
# MUTANT-MATRIX MUTATION-count decides=MUTATION-count.cell3 twins=MUTATION-count.cell2
# MUTANT-MATRIX MUTATION-counter decides=MUTATION-counter.cell1 twins=MUTATION-counter.cell2
# MUTANT-MATRIX MUTATION-scope-grew-unguarded decides=MUTATION-scope-grew-unguarded.cell1,MUTATION-scope-grew-unguarded.cell4 twins=MUTATION-scope-grew-unguarded.cell2
# MUTANT-MATRIX MUTATION-scope-grew-wrong-var decides=MUTATION-scope-grew-wrong-var.cell2,MUTATION-scope-grew-wrong-var.cell3 twins=MUTATION-scope-grew-wrong-var.cell1
# MUTANT-MATRIX MUTATION-scope-grew-prior-zero decides=MUTATION-scope-grew-prior-zero.cell3 twins=MUTATION-scope-grew-prior-zero.cell2
# MUTANT-MATRIX MUTATION-scope-grew-pass-number decides=MUTATION-scope-grew-pass-number.cell4 twins=MUTATION-scope-grew-pass-number.cell3
# MUTANT-MATRIX MUTATION-j2-chain-walk decides=MUTATION-j2-chain-walk.cell3,MUTATION-j2-chain-walk.cell4 twins=MUTATION-j2-chain-walk.cell2
# MUTANT-MATRIX MUTATION-j2-fork-check decides=MUTATION-j2-fork-check.cell5 twins=MUTATION-j2-fork-check.cell4
# MUTANT-MATRIX MUTATION-j2-subject decides=MUTATION-j2-subject.cell6 twins=MUTATION-j2-subject.cell5
# MUTANT-MATRIX MUTATION-j2-stamp-rebind decides=MUTATION-j2-stamp-rebind.cell2 twins=MUTATION-j2-stamp-rebind.cell1
# MUTANT-MATRIX J2T1-whole-file-id-scan decides=J2T1-whole-file-id-scan.split,J2T1-whole-file-id-scan.merge,J2T1-whole-file-id-scan.norows twins=J2T1-whole-file-id-scan.reword
# MUTANT-MATRIX J2T2-unreachable-read-unchanged decides=J2T2-unreachable-read-unchanged.unreach twins=J2T2-unreachable-read-unchanged.split
# MUTANT-MATRIX J2T3-empty-extraction-judged decides=J2T3-empty-extraction-judged.norows twins=J2T3-empty-extraction-judged.reword
# MUTANT-MATRIX J2T4-J2T_RELEASE-lowered decides=J2T4-J2T_RELEASE-lowered.pred twins=J2T4-J2T_RELEASE-lowered.nostamp
# MUTANT-MATRIX J2T5-J2T_RELEASE-raised decides=J2T5-J2T_RELEASE-raised.split,J2T5-J2T_RELEASE-raised.merge,J2T5-J2T_RELEASE-raised.legacy twins=J2T5-J2T_RELEASE-raised.reword
# MUTANT-MATRIX MUTATION-j-citation decides=MUTATION-j-citation.cell2,MUTATION-j-citation.cell3 twins=MUTATION-j-citation.cell1
# MUTANT-MATRIX MUTATION-f5-reopen-spec decides=MUTATION-f5-reopen-spec.cell3 twins=MUTATION-f5-reopen-spec.cell2
# MUTANT-MATRIX MUTATION-h-stamp-gate decides=MUTATION-h-stamp-gate.cell3,MUTATION-h-stamp-gate.cell4 twins=MUTATION-h-stamp-gate.cell2
# MUTANT-MATRIX MUTATION-h-glob-restored decides=MUTATION-h-glob-restored.cell2,MUTATION-h-glob-restored.cell3,MUTATION-h-glob-restored.cell4 twins=MUTATION-h-glob-restored.cell1
# MUTANT-MATRIX MUTATION-h-stamp-rebind decides=MUTATION-h-stamp-rebind.cell4 twins=MUTATION-h-stamp-rebind.cell3
# MUTANT-MATRIX MUTATION-h-stem-unstripped decides=MUTATION-h-stem-unstripped.cell1 twins=MUTATION-h-stem-unstripped.cell2
# MUTANT-MATRIX K3X1-count-not-identity decides=K3X1-count-not-identity.cell3 twins=K3X1-count-not-identity.cell2
# MUTANT-MATRIX K3X2-stamp-gate-deleted decides=K3X2-stamp-gate-deleted.cell4 twins=K3X2-stamp-gate-deleted.cell3
# MUTANT-MATRIX K3WX1-widened-case-arm-gone decides=K3WX1-widened-case-arm-gone.cell1,K3WX1-widened-case-arm-gone.cell2,K3WX1-widened-case-arm-gone.cell3,K3WX1-widened-case-arm-gone.cell6,K3WX1-widened-case-arm-gone.cell7 twins=K3WX1-widened-case-arm-gone.cell4
# MUTANT-MATRIX K3WX2-artifact-test-skipped decides=K3WX2-artifact-test-skipped.cell5 twins=K3WX2-artifact-test-skipped.cell4
# MUTANT-MATRIX K3WX3-widened-stamp-not-rebound decides=K3WX3-widened-stamp-not-rebound.cell3 twins=K3WX3-widened-stamp-not-rebound.cell2
# MUTANT-MATRIX K3WX4-K3B_RELEASE-lowered decides=K3WX4-K3B_RELEASE-lowered.cell3 twins=K3WX4-K3B_RELEASE-lowered.cell2
# MUTANT-MATRIX K3WX5-manifest-root-not-walked decides=K3WX5-manifest-root-not-walked.cell1,K3WX5-manifest-root-not-walked.cell2,K3WX5-manifest-root-not-walked.cell3,K3WX5-manifest-root-not-walked.cell6,K3WX5-manifest-root-not-walked.cell7 twins=K3WX5-manifest-root-not-walked.cell4
# MUTANT-MATRIX J2SX1-per-stem-branch-gone decides=J2SX1-per-stem-branch-gone.cell1,J2SX1-per-stem-branch-gone.cell5,J2SX1-per-stem-branch-gone.cell6 twins=J2SX1-per-stem-branch-gone.cell2
# MUTANT-MATRIX J2SX2-identity-links-kept decides=J2SX2-identity-links-kept.cell3 twins=J2SX2-identity-links-kept.cell2
# MUTANT-MATRIX J2SX3-record-glob-narrowed decides=J2SX3-record-glob-narrowed.cell2 twins=J2SX3-record-glob-narrowed.cell1
# MUTANT-MATRIX J2SX4-first-entry-only decides=J2SX4-first-entry-only.cell2,J2SX4-first-entry-only.cell3 twins=J2SX4-first-entry-only.cell1
# MUTANT-MATRIX J2SX5-cumulative-stem-judged decides=J2SX5-cumulative-stem-judged.cell4 twins=J2SX5-cumulative-stem-judged.cell3
# MUTANT-MATRIX J2SX6-stamp-gate-deleted decides=J2SX6-stamp-gate-deleted.cell5 twins=J2SX6-stamp-gate-deleted.cell4
# MUTANT-MATRIX J2SX7-J2S_RELEASE-lowered decides=J2SX7-J2S_RELEASE-lowered.cell6 twins=J2SX7-J2S_RELEASE-lowered.cell5
# MUTANT-MATRIX K3CX1-want-set-left-cross decides=K3CX1-want-set-left-cross.cell1,K3CX1-want-set-left-cross.cell2,K3CX1-want-set-left-cross.cell3,K3CX1-want-set-left-cross.cell4 twins=K3CX1-want-set-left-cross.cell5
# MUTANT-MATRIX K3CX2-pin-capability-ignored decides=K3CX2-pin-capability-ignored.cell5 twins=K3CX2-pin-capability-ignored.cell4
# MUTANT-MATRIX K3CX3-control-K3C-raised decides=K3CX3-control-K3C-raised.cell2 twins=K3CX3-control-K3C-raised.cell1
# MUTANT-MATRIX K3CX4-K3C-stamp-not-rebound decides=K3CX4-K3C-stamp-not-rebound.cell4 twins=K3CX4-K3C-stamp-not-rebound.cell3
# MUTANT-MATRIX m-k2only-K3D-acquittal-off decides=m-k2only-K3D-acquittal-off.cell1 twins=m-k2only-K3D-acquittal-off.cell2
# MUTANT-MATRIX K3DX2-K3D-raised-to-99-0-0 decides=K3DX2-K3D-raised-to-99-0-0.cell1 twins=K3DX2-K3D-raised-to-99-0-0.cell2
# MUTANT-MATRIX K3DX3-date-rule-dropped decides=K3DX3-date-rule-dropped.cell2,K3DX3-date-rule-dropped.cell3 twins=K3DX3-date-rule-dropped.cell1
# MUTANT-MATRIX MUTATION-stall-resolution decides=MUTATION-stall-resolution.stalled-resolved twins=MUTATION-stall-resolution.stalled,MUTATION-stall-resolution.stalled-record-invalid
# MUTANT-MATRIX MUTATION-cdiv-terminal decides=MUTATION-cdiv-terminal.cdiv-terminal-resolved twins=MUTATION-cdiv-terminal.cdiv-terminal,MUTATION-cdiv-terminal.cdiv-record-invalid
# MUTANT-MATRIX MUTATION-cdiv-never-resolves decides=MUTATION-cdiv-never-resolves.cdiv-verified,MUTATION-cdiv-never-resolves.gate twins=MUTATION-cdiv-never-resolves.cdiv-verified-unresolved,MUTATION-cdiv-never-resolves.cdiv-verified-invalid
# MUTANT-MATRIX MUTATION-cdiv-always-resolves decides=MUTATION-cdiv-always-resolves.cdiv-verified-invalid twins=MUTATION-cdiv-always-resolves.cdiv-verified,MUTATION-cdiv-always-resolves.cdiv-verified-unresolved
# MUTANT-MATRIX MUTATION-cdiv-terminal-silent decides=MUTATION-cdiv-terminal-silent.cdiv-terminal-resolved twins=MUTATION-cdiv-terminal-silent.cdiv-verified-unresolved
# MUTANT-MATRIX MUTATION-sha-key decides=MUTATION-sha-key.sharded-revert-reordered twins=MUTATION-sha-key.sharded-revert-partial
# MUTANT-MATRIX MUTATION-ts-bmad-restored decides=MUTATION-ts-bmad-restored.cell2 twins=MUTATION-ts-bmad-restored.cell1,MUTATION-ts-bmad-restored.cell3
# MUTANT-MATRIX MUTATION-ts-gate-prefix-dropped decides=MUTATION-ts-gate-prefix-dropped.cell1 twins=MUTATION-ts-gate-prefix-dropped.cell2,MUTATION-ts-gate-prefix-dropped.cell3
# MUTANT-MATRIX MUTATION-ts-precondition-deleted decides=MUTATION-ts-precondition-deleted.cell3 twins=MUTATION-ts-precondition-deleted.cell1,MUTATION-ts-precondition-deleted.cell2
# MUTANT-MATRIX K3WX6-b-K3B-conjunct-dropped decides=K3WX6-b-K3B-conjunct-dropped.k3w-subj twins=K3WX6-applied-discriminates.kept-binding
# MUTANT-MATRIX live-series-unfiltered decides=live-series-unfiltered.decoy-world twins=live-series-control-unfiltered.no-decoy-world
# MUTANT-MATRIX live-series-unscoped decides=live-series-unscoped.two-sprint-world twins=live-series-control-unscoped.one-sprint-world
# The twelve rows above are measured row-whole: each row is 2-3 cells, its deciding cell plus its twins ARE
# the row, and the whole row runs on every push, so the per-push match IS the matrix measurement.
# MUTANT-MATRIX-CONTROL CONTROL-chrono-copy why=the unmutated copy beside the arm-G mutants must reproduce the shipped row
# MUTANT-MATRIX-CONTROL CONTROL-third-state-copy why=the unmutated copy in the third-state mutants' directory must reproduce the shipped row
# MUTANT-MATRIX-CONTROL CONTROL-unmutated-copy why=the unmutated copy beside the arm-I mutants must reproduce the four ceiling verdicts
# MUTANT-MATRIX-CONTROL CONTROL-k2-copy why=the unmutated copy in the K2 mutants' directory must reproduce the shipped row
# MUTANT-MATRIX-CONTROL K2-in-force-copy why=the shipped validator in the K2 history worlds must reproduce the row before any mutant is copied in
# MUTANT-MATRIX-CONTROL CONTROL-scope-grew-copy why=the unmutated copy beside the scope-grew mutants must reproduce the shipped row
# MUTANT-MATRIX-CONTROL CONTROL-j2-copy why=the unmutated copy in the J2 mutants' directory must reproduce the shipped row
# MUTANT-MATRIX-CONTROL CONTROL-j-door-copy why=the same copy must reproduce the J-door row
# MUTANT-MATRIX-CONTROL H-series-named-record why=the shipped validator must reproduce the H row the mutants are read against
# MUTANT-MATRIX-CONTROL CONTROL-h-copy why=the unmutated copy in the J2 mutants' directory must reproduce the H row
# MUTANT-MATRIX-CONTROL MUTATION-cdiv-control why=the unmutated copy beside the cdiv mutants must pass the verified series
# MUTANT-MATRIX-CONTROL CONTROL-ts-unmutated why=the shipped documents must score ok on all three test-strategy cells
# MUTANT-MATRIX-CONTROL MUTATION-g-anchor why=the arm-G anchor is unique against an impossible-anchor control, or every G mutant proves nothing
# MUTANT-MATRIX-CONTROL MUTATION-sg-anchor why=the scope-grew anchor is unique against an impossible-anchor control
# MUTANT-MATRIX-CONTROL MUTATION-ts-anchor why=the test-strategy step-2 anchor is unique against an impossible-anchor control
# MUTANT-MATRIX-CONTROL J3-shipped-validator why=the receipt's own verdict on the shipped validator, every world judged
# MUTANT-MATRIX-CONTROL J3-0-control-unmutated why=the unmutated copy beside the J3 mutants, every world judged, so a partial copy tree cannot pass
# MUTANT-MATRIX-CONTROL J2T-shipped-validator why=the receipt's own verdict on the shipped validator, every world judged
# MUTANT-MATRIX-CONTROL J2T0-control-unmutated why=the unmutated copy beside the J2T mutants, every world judged
# MUTANT-MATRIX-CONTROL LD-shipped-validator why=the receipt's own verdict on the shipped validator, every world judged
# MUTANT-MATRIX-CONTROL LD0-control-unmutated why=the unmutated copy beside the LD mutants, every world judged
# MUTANT-MATRIX-CONTROL LX0-control-unmutated why=the unmutated copy must reproduce the nine-world arm-L row
# MUTANT-MATRIX-CONTROL LM0-control-unmutated why=the unmutated copy must reproduce the five-world arm-L merge row
# MUTANT-MATRIX-CONTROL K3X0-control-unmutated why=the unmutated copy must reproduce the four-world K3 row
# MUTANT-MATRIX-CONTROL K3WX0-control-unmutated why=the unmutated copy must reproduce the seven-world K3-widened row
# MUTANT-MATRIX-CONTROL K3WX6c-k3w-subj-control why=the unmutated copy must read k3w-subj PENDING before the K3B conjunct mutant is read
# MUTANT-MATRIX-CONTROL J2SX0-control-unmutated why=the unmutated copy must reproduce the six-world J2-per-stem row
# MUTANT-MATRIX-CONTROL K3CX0-control-unmutated why=the unmutated copy must reproduce the five-world K3 cross-group row
# MUTANT-MATRIX-CONTROL K3DX0-control-unmutated why=the unmutated copy must reproduce the four-world K3 lone-cross row
# MUTANT-MATRIX-CONTROL live-series-control-shipped why=the shipped derivation on the no-decoy world, the baseline both live-series mutants are read against
# MUTANT-MATRIX-DYNAMIC rcpt_mut why=the receipt battery passes each mutant label and its exact NOT FIXED line as arguments; every label it produces has its own row above
# MUTANT-MATRIX-DYNAMIC _sp-loop why=the adjudication-unlocked-<spelling> loop passes six spellings as a variable; these are seeded cases, not mutants, so it produces no mutant row
# MUTANT-MATRIX-END
MATRIX="$MATRIX_ARG"
if [ "$MATRIX" = 1 ]; then echo "MATRIX MODE: on -- every mutant scores every cell and every receipt world (shard $GROUP)"
else echo "MATRIX MODE: off -- per push, each mutant scores its deciding cells plus one green twin (shard $GROUP)"; fi
RCPT_WD="$ROOT/rcpt-worlds"
# THE ROW BATTERIES use the same rule over CELLS. A row mutant is scored over N cases; its DECIDING
# cells are the ones whose expected verdict differs from the unmutated control row, and its TWIN is the
# nearest cell (in row order) whose verdict it must leave unchanged -- the case beside its subject. Per
# push only those cells run; the rest print `.` in both the got and the want row. A row whose want equals
# the control's (every control) runs in full. MATRIX=1 runs every cell of every mutant, which is the
# matrix measurement: a full-row match there is the proof each twin stayed green.
#   rsel <want row> <control row>  -> RSEL (1-based cells to run, empty = all) and RTWIN
#   ron <i>                        -> 0 when cell i runs
#   rmask <row>                    -> the row with every cell that does not run replaced by `.`
rsel() {
  # `w`, `r` and `x` are LOCAL arrays: the callers use a scalar `w` for a world name.
  local -a w r x
  local i=0 d="" t="" best=999999 dist first="" y
  RSEL=""; RTWIN=""
  set -f; w=($1); r=($2); set +f
  [ "${#w[@]}" -eq "${#r[@]}" ] || broken "rsel: want row [$1] and control row [$2] differ in length"
  for y in "${w[@]}"; do i=$((i + 1)); [ "$y" = "${r[$((i - 1))]}" ] || { d="$d $i"; [ -n "$first" ] || first="$i"; }; done
  MX_ROWS=$((MX_ROWS + 1))
  [ -n "$d" ] || return 0
  i=0
  for y in "${w[@]}"; do i=$((i + 1))
    case " $d " in *" $i "*) continue ;; esac
    dist=$((i - first)); [ "$dist" -lt 0 ] && dist=$((0 - dist))
    if [ "$dist" -lt "$best" ]; then best="$dist"; t="$i"; fi
  done
  RTWIN="$t"
  if [ "$MATRIX" = 1 ]; then
    printf '  matrix-cells deciding {%s} twin {%s} of [%s] (every cell scored)\n' "${d# }" "$t" "$1"
  else
    RSEL="${d# }${t:+ $t}"
    set -f; x=($RSEL); set +f
    MX_SKIPPED=$((MX_SKIPPED + ${#w[@]} - ${#x[@]}))
    printf '  per-push cells deciding {%s} twin {%s} of [%s]\n' "${d# }" "$t" "$1"
  fi
}
MX_ROWS=0; MX_SKIPPED=0
# THE SEAM (validate-adversarial-convergence.sh --arms). The mutant batteries of units k3, j2h, elic and
# j3 run each mutant through the seam, which executes only the named gate-only arms of the SAME file the
# mutant edits, so a mutant can never read an unmutated answer. Per-case cells, the shipped validator and
# every receipt's shipped/control run stay on the FULL entry: those are the end-to-end runs. seam_guard
# proves, per seamed arm set, that the seam's control row equals the full entry's row over the same worlds.
SEAM_ARMS=""
seam_guard() { # <label> <arm set> <row fn> <script>
  local srow frow nd
  ASSERTIONS=$((ASSERTIONS + 1))
  srow="$(SEAM_ARMS="$2"; "$3" "$4")"
  frow="$(SEAM_ARMS=""; "$3" "$4")"
  nd="$(printf '%s\n' $srow | sort -u | grep -c .)" || nd=0
  if [ -n "$srow" ] && [ "$srow" = "$frow" ] && [ "$nd" -ge 2 ]; then
    printf '  ok    %-28s seam --arms %s [%s] = full entry\n' "$1" "$2" "$srow"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s seam --arms %s [%s], full entry [%s], %s distinct verdicts (want equal, >= 2)\n' "$1" "$2" "$srow" "$frow" "$nd"
  fi
}
# MX0, read once at the end of the shard: a per-push run must have SKIPPED matrix-only cells (else the
# subset never applied and the cut is fiction), and a --matrix run must have skipped NONE.
mx_arm() {
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$MX_ROWS" -eq 0 ]; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s no mutant row was scored in this shard -- the arm reads nothing\n' "MX0 matrix mode"
  elif [ "$MATRIX" = 1 ] && [ "$MX_SKIPPED" -ne 0 ]; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s --matrix skipped %s cell(s) over %s rows\n' "MX0 matrix mode" "$MX_SKIPPED" "$MX_ROWS"
  elif [ "$MATRIX" != 1 ] && [ "$MX_SKIPPED" -eq 0 ]; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s a per-push run scored every cell of %s rows -- the subset never applied\n' "MX0 matrix mode" "$MX_ROWS"
  else
    printf '  ok    %-28s %s rows; matrix=%s; cells skipped=%s\n' "MX0 matrix mode" "$MX_ROWS" "$MATRIX" "$MX_SKIPPED"
  fi
}
ron() { [ -z "${RSEL:-}" ] && return 0; case " $RSEL " in *" $1 "*) return 0 ;; esac; return 1; }
rmask() { local x i=0 o=""; set -f; for x in $1; do i=$((i + 1)); if ron "$i"; then o="$o $x"; else o="$o ."; fi; done; set +f; printf '%s' "${o# }"; }
rcpt_cell() { # <label> <receipt> <validator> <want rc 0|1> [<the exact NOT FIXED line>]
  # The fifth argument names WHICH worlds flipped: a mutant that crashes the validator (rc 2 in every
  # world) also prints NOT FIXED and would otherwise read as a kill. RM_TWIN (set by the caller) names the
  # mutant's green twin; with it and MATRIX=0 only the flipped worlds and the twin are judged.
  local out rc want_say="fixed (" worlds="" t
  [ "$4" -eq 0 ] || want_say="NOT FIXED"
  [ -z "${5:-}" ] || want_say="$5"
  [ -z "${RM_TWIN:-}" ] || [ -n "${5:-}" ] || broken "$1: RM_TWIN is set but no exact NOT FIXED line names the deciding worlds"
  if [ "$MATRIX" != 1 ] && [ -n "${RM_TWIN:-}" ] && [ -n "${5:-}" ]; then
    for t in ${5#*--}; do worlds="$worlds ${t%%(*}"; done
    case " $worlds " in *" $RM_TWIN "*) broken "$1: the twin $RM_TWIN is one of its own deciding worlds" ;; esac
    worlds="${worlds# } $RM_TWIN"
  fi
  local arms=""
  if [ -n "${RM_TWIN:-}" ] || [ "${RCPT_SEAM:-}" = 1 ]; then
    case "${2##*/}" in receipt-bl814.sh) arms=J3 ;; receipt-bl736.sh) arms=J2 ;; receipt-bl733.sh) arms=L ;; *) broken "$1: no seam arm for ${2##*/}" ;; esac
  fi
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(TMPDIR="$ROOT" RCPT_WORLD_DIR="$RCPT_WD/${2##*/}" RCPT_WORLDS="$worlds" RCPT_REPORT="$([ "$MATRIX" = 1 ] && echo 1)" \
         RCPT_ARMS="$arms" bash "$2" "$3" 2>&1)"; rc=$?
  [ "$MATRIX" != 1 ] || printf '  matrix %-27s %s\n' "$1" "$(grep -m1 '^receipt worlds judged:' <<<"$out")"
  [ -z "$worlds" ] || printf '  per-push %-25s judged {%s} (deciding + twin %s)\n' "$1" "$worlds" "$RM_TWIN"
  if [ "$rc" -eq "$4" ] && { if [ -n "${5:-}" ]; then grep -qxF -- "$want_say" <<<"$out"; else grep -qF -- "$want_say" <<<"$out" && ! grep -q '^receipt: ' <<<"$out"; fi; }; then
    # --matrix prints the receipt's whole verdict line, so every deciding world is in the log by name.
    if [ "$MATRIX" = 1 ]; then printf '  ok    %-28s exit=%s %s\n' "$1" "$rc" "$(printf '%s' "$out" | tail -1)"
    else printf '  ok    %-28s exit=%s %s\n' "$1" "$rc" "$(printf '%s' "$out" | tail -1 | cut -c1-110)"; fi
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s (%s)\n' "$1" "$rc" "$4" "$want_say"
    printf '%s\n' "$out" | sed 's/^/          | /'
  fi
}
rcpt_mut() { # <label> <receipt> <want rc> [<old> <new>]... -- a mutant (or, with no pairs, the control) in a copy
  local label="$1" rcpt="$2" want="$3" d s; shift 3
  d="$(mktemp -d "$ROOT/rcpt-mut.XXXXXX")" || broken "cannot create a mutant dir under $ROOT"
  for s in $RCPT_SIBS; do cp "$(dirname "$VALIDATOR")/$s" "$d/" 2>/dev/null; done
  [ -f "$d/merge-adversarial-shards.sh" ] && [ -f "$d/partition-document.sh" ] || {
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s FIXTURE BROKEN -- the siblings are not beside the copy\n' "$label"; return; }
  python3 - "$VALIDATOR" "$d/validate-adversarial-convergence.sh" "$@" <<'PY' || {
import sys
s = open(sys.argv[1], encoding="utf-8").read(); a = sys.argv[3:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(3)
    s = s.replace(a[i], a[i + 1])
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s FIXTURE STALE -- an anchor is not in the validator exactly once\n' "$label"; return; }
  if [ $# -gt 0 ] && { cmp -s "$VALIDATOR" "$d/validate-adversarial-convergence.sh" || ! bash -n "$d/validate-adversarial-convergence.sh" 2>/dev/null; }; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s FIXTURE STALE -- the mutation DID NOT APPLY or is not valid shell\n' "$label"; return
  fi
  # `<rc>|<line>`: the receipt's exact NOT FIXED line, so a crash that flips every world is not a kill.
  case "$want" in
    *"|"*) rcpt_cell "$label" "$rcpt" "$d/validate-adversarial-convergence.sh" "${want%%|*}" "${want#*|}" ;;
    *) rcpt_cell "$label" "$rcpt" "$d/validate-adversarial-convergence.sh" "$want" ;;
  esac
}
echo "check-24 adversarial-convergence fixture (shard $GROUP)"
echo
if sg core; then

# --- backward compatibility (pre-v0.52.0 artifacts: no prior_scope field) -----
expect converged           0 "clean terminal pass -- the cycle the machinery should produce"
expect nitpicks-remain     0 "THE DECOY: 0C/0M with 5 MINOR open is 'only nitpicks remain' -- MET"
expect refused-to-converge 1 "S289 pass-4 shape: clean residue, still stamps NOT_MET"
expect divergent           1 "no field, CRITICALs 3 -> 6, no DHB: the default is FAIL-CLOSED"
expect no-verdict          1 "a pass with no verdict: key is un-adjudicable"

echo
# --- v0.52.0: the scope-relative predicate ------------------------------------
expect scope-grew-converges   0 "RELEASE: CRIT rise 2->3 but only 1 in prior scope -- NOT divergence"
expect repair-injected        1 "3 of 3 CRIT in PRIOR scope: real divergence still caught"
expect scope-grew-unconverged 1 "never converges on a MOVING artifact -- FAIL (D)"
expect_says scope-grew-unconverged s1-adversarial-pass "D-remedy" \
  "MOVING ARTIFACT" "CUT the added scope"

echo
# --- v0.55.3: numeric ordering + the STALL rung -------------------------------
expect long-series-p-naming 0 "11 passes, -p<N>: ordered NUMERICALLY, so p11 (MET) is terminal, not p9" s1-adversarial-p
expect stalled              1 "0 CRITICAL, blocking MAJOR pinned at 4 -- ABOVE the exit ceiling of 3 -- for 3 passes: STALLED, FAIL (E)" s1-adversarial-p
expect stall-then-converges 0 "DECOY: holds MAJOR one pass short of K, then clears it -- E must NOT fire" s1-adversarial-p
expect_says stalled s1-adversarial-p "E-remedy" \
  "E -- STALL" "ANOTHER PASS IS NOT THE REMEDY" "VERIFY THE DISPUTED FACT MECHANICALLY"

# E must PRE-EMPT D. A stalled series that merely inherits D's generic "run another pass to
# a clean verdict" is the bug wearing a new error code.
#
# THE TOKEN IS ONE THE MESSAGE ACTUALLY CARRIES ON ONE LINE. Arm D's generic remedy wraps
# between "Either run another pass to a" and "clean verdict", so the obvious phrase spans a
# newline, is absent from the output of EVERY series, and an absence arm keyed on it can
# never fire. Measured: 0 occurrences in the validator against a control of 1 for the line
# below. Both pre-empt arms were keyed that way, and both were dead.
# The POSITIVE control for this token is `D-generic-at-pass1` further down, which requires
# it to APPEAR: without it, an arm D that stopped emitting the remedy passes both arms here.
# D_GENERIC is defined once in the shared prelude above: units in different shards read it.
ASSERTIONS=$((ASSERTIONS + 1))
vrun both "$VALIDATOR" --series "$ROOT/stalled/s1-adversarial-p"
if grep -qF -- "$D_GENERIC" <<<"$VR_OUT"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s a STALLED series still got Check D generic advice. E must pre-empt D.\n' "stall-preempts-d"
else
  printf '  ok    %-28s E pre-empts D: the stalled series is not told to run another pass\n' "stall-preempts-d"
fi

echo
# --- v0.59.0: THE RESUME CONTRACT ---------------------------------------------

# THE RELEASE. If this goes red, the sanctioned exit is gone and the deadlock is back.
expect divergent-resolved 0 "THE RELEASE: hard block -> REVERT_REPAIR record -> verification pass -> MET" s1-adversarial-p

# D2: arm E must be REACHABLE when the series ends DIVERGENT, and must name the PEAK.
# Exits 1 before and after -- only the message distinguishes a fixed validator from a broken one.
expect stalled-then-diverges 1 "plateau at p2-p4, then divergent p5: BOTH D and E must fire" s1-adversarial-p
expect_says stalled-then-diverges s1-adversarial-p "E-reachable-past-D" \
  "E -- STALL" "should have STOPPED at" "s1-adversarial-p4.md"

# F1: a pass ran after a hard block and declared nothing.
expect divergent-unresolved 1 "p3 ran after p2's hard block, declaring no resolution -- FAIL (F)" s1-adversarial-p
expect_says divergent-unresolved s1-adversarial-p "F1-declared" \
  "F -- RESOLUTION" "STOP -> ADJUDICATE -> RESOLVE -> VERIFY" "resolves_divergence"

# F3: THE LIVE DEADLOCK. Freezing cannot clear a hard block, and the message must say why.
expect divergent-frozen 1 "FREEZE_SCOPE cannot resolve a prior-scope hard block -- FAIL (F)" s1-adversarial-p
expect_says divergent-frozen s1-adversarial-p "F3-freeze-is-void" \
  "does not remove a CRITICAL that is already inside the frozen text" \
  "ALREADY FROZEN"

# F5: the two launder paths that close by arithmetic and by construction.
expect divergent-laundered-cut 1 "CUT_SCOPE that GREW: a repair wearing a resolution's name" s1-adversarial-p
expect_says divergent-laundered-cut s1-adversarial-p "F5-cut-arithmetic" \
  "declares CUT_SCOPE but the artifact did not shrink"
expect divergent-laundered-revert 1 "REVERT_REPAIR landing on a sha no pass ever notarized" s1-adversarial-p
expect_says divergent-laundered-revert s1-adversarial-p "F5-revert-construction" \
  "matches no" "earlier pass in this series"

# F7: the adjudication's SHAPE. These three carry the same passes, the same anchors and the
# same operator citation as divergent-resolved, which exits 0 -- so the exit code alone
# cannot tell a validator with F7 from one without it, and the messages are the assertion.
expect adjudication-no-options 1 "a resolution recording NO options put to the operator -- FAIL (F7)" s1-adversarial-p
expect_says adjudication-no-options s1-adversarial-p "F7-no-options" \
  "options_presented=<none>" "an operator adjudicates by CHOOSING"
expect adjudication-one-option 1 "one option is a request for approval, not an adjudication -- FAIL (F7)" s1-adversarial-p
expect_says adjudication-one-option s1-adversarial-p "F7-one-option" \
  "options_presented=1" "at least two worked-out"
expect adjudication-no-recommendation 1 "a menu with no recommendation hands the judgment back -- FAIL (F7)" s1-adversarial-p
expect_says adjudication-no-recommendation s1-adversarial-p "F7-no-recommendation" \
  "names no 'recommended_option:'" "who has not read the artifact"

# F7b: the locked branch, keyed on the record's `locked_requirements_touched:`. Each world is
# divergent-resolved with only the adjudication fields changed, so each exit is F7b's alone.
expect adjudication-locked-badged 1 "a locked requirement touched AND a badge recorded -- FAIL (F7b)" s1-adversarial-p
expect_says adjudication-locked-badged s1-adversarial-p "F7b-locked-badged" \
  "names a locked requirement" "PRESENTED" "UNBADGED" "'recommended_option: none'"
expect adjudication-locked-none   0 "a locked requirement touched, recommended_option: none -- PASS" s1-adversarial-p
expect adjudication-locked-absent 0 "a locked requirement touched, no recommended_option line -- PASS" s1-adversarial-p
expect adjudication-unlocked-badged 0 "locked_requirements_touched: none and one badge -- the unlocked rule holds, PASS" s1-adversarial-p
expect adjudication-unlocked-none 1 "locked_requirements_touched: none with recommended_option: none -- the badge is owed, FAIL (F7)" s1-adversarial-p
expect_says adjudication-unlocked-none s1-adversarial-p "F7b-unlocked-none" \
  "names no 'recommended_option:'" "who has not read the artifact"
# The locked finding must NOT fire on an unlocked record, and the control proves it can fire.
expect_silent adjudication-unlocked-badged "names a locked requirement" adjudication-locked-badged \
  "locked_requirements_touched: none is the unlocked branch"
expect_silent divergent-resolved "names a locked requirement" adjudication-locked-badged \
  "a record with no locked_requirements_touched line reads as none"
# The field is read on its FIRST TOKEN. Each unlocked spelling below carries one badge and must
# take the unlocked branch: exit 0 AND silent on the locked finding, against the badged control.
for _sp in emdash changed nonedot na list dash; do
  expect "adjudication-unlocked-$_sp" 0 "locked_requirements_touched spelled '$_sp' is unlocked, one badge -- PASS" s1-adversarial-p
  expect_silent "adjudication-unlocked-$_sp" "names a locked requirement" adjudication-locked-badged \
    "the first token of the '$_sp' spelling is in the unlocked set"
done
unset _sp
# A real id with a parenthetical after it is LOCKED: its first token is `lr`, and the badge FAILS.
expect adjudication-locked-lr-paren 1 "LR-S1-1 (...) is a locked entry, a badge recorded -- FAIL (F7b)" s1-adversarial-p
expect_says adjudication-locked-lr-paren s1-adversarial-p "F7b-locked-lr-paren" \
  "names a locked requirement" "mark NO option (Recommended)"

# D4/G: the dead cycle's tail.
expect restart-cycle 1 "restart left p4-p6 of the dead cycle on disk -- FAIL (G)" s1-adversarial-p
# The message must name BOTH causes. Driving this against the reference consumer's live series
# fired G on a pass whose `invoked_at` was simply MIS-TYPED — and the first draft of the message
# confidently diagnosed a dead-cycle tail. An error message that asserts the wrong cause with
# confidence is the exact defect v0.57.0's changelog shipped, in the release that retracts it.
expect_says restart-cycle s1-adversarial-p "G-chronology" \
  "G -- CHRONOLOGY" "DEAD CYCLE'S TAIL" "archive the abandoned series" \
  "A MIS-STAMPED" "Do not back-fit it to make"

# --- G across the two stamped forms (BL-371): the ordering KEY, not the raw string ---------
# Each pair sits inside ONE second, so a different-second comparison cannot separate them.
expect chrono-fraction-forward 0 "19Z then 19.497Z: 497 ms LATER, so the chain is in order" s1-adversarial-p
expect chrono-fraction-equal   0 "19.000Z then 19Z: the SAME instant, so nothing ran first" s1-adversarial-p
expect chrono-fraction-backward 1 "19.497Z then 19Z: the second pass was written 497 ms FIRST -- FAIL (G)" s1-adversarial-p
expect_says chrono-fraction-backward s1-adversarial-p "G-fraction-backward" "G -- CHRONOLOGY"
expect_silent chrono-fraction-forward "G -- CHRONOLOGY" chrono-fraction-backward \
  "a raw string comparison reads the fractional stamp as EARLIER, because '.' sorts before 'Z'"
expect_silent chrono-fraction-equal "G -- CHRONOLOGY" chrono-fraction-backward \
  "a comparison with the Z stripped reads '19' as earlier than '19.000', a prefix, not a time"

# --- MUTATION: arm G's comparison, one wrong key per cell ---------------------------------
# Three cells, four validators. Each wrong comparison is one an author would write, and each
# moves a DIFFERENT cell, so the three cells together are what pin the key:
#
#                         forward  backward  equal
#   shipped (at_key)      -        G         -
#   raw string            G        -         -       <- the BL-371 defect
#   Z stripped            -        G         G
#   arm G removed         -        -         -
G_ANCHOR='    if [[ "$AT_KEY" < "$PREV_AT_KEY" ]]; then'
G_CASES="chrono-fraction-forward chrono-fraction-backward chrono-fraction-equal"
g_fired() {  # $1 script  $2 case -> G or -
  case "$(bash "$1" --series "$ROOT/$2/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)" in
    *"G -- CHRONOLOGY"*) printf 'G\n' ;;
    *) printf -- '-\n' ;;
  esac
}
g_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  local i=0 wm; rsel "$3" "- G -"; wm="$(rmask "$3")"
  for c in $G_CASES; do i=$((i + 1)); if ron "$i"; then got="$got $(g_fired "$2" "$c")"; else got="$got ."; fi; done
  RSEL=""
  if [ "$(echo $got)" = "$wm" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$3"
  fi
}
ASSERTIONS=$((ASSERTIONS + 1))
g_n="$(grep -cF -- "$G_ANCHOR" "$VALIDATOR")" || g_n=0
g_ctl="$(grep -cF -- "$G_ANCHOR-no-such-line" "$VALIDATOR")" || g_ctl=0
if [ "$g_n" -ne 1 ] || [ "$g_ctl" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0) -- the mutants below prove nothing\n' \
    "MUTATION g-anchor" "$g_n" "$g_ctl"
else
  printf '  ok    %-28s the anchor is unique (impossible-anchor control: 0)\n' "MUTATION g-anchor"
fi
# THE UNMUTATED CONTROL carries a positive cell (backward = G), so a copy that died emitting
# nothing reads [- - -] and fails here rather than scoring as a kill below.
cp "$VALIDATOR" "$ROOT/control-chrono.sh"
g_score "CONTROL chrono copy" "$ROOT/control-chrono.sh" "- G -"
g_mutate() {  # $1 label  $2 replacement line  $3 expected row
  local mut="$ROOT/mutant-$1.sh"
  MUT_OLD="$G_ANCHOR" MUT_NEW="$2" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched nothing or is not valid shell -- this assertion proves nothing\n' "MUTATION $1"
    return
  fi
  g_score "MUTATION $1" "$mut" "$3"
}
g_mutate chrono-raw-string '    if [[ "$invoked_at" < "$PREV_AT" ]]; then' "G - -"
g_mutate chrono-strip-z    '    if [[ "${invoked_at%Z}" < "${PREV_AT%Z}" ]]; then' "- G G"
g_mutate chrono-arm-g-off  '    if false; then' "- - -"

# --- F4/F5 on a SHARDED series: artifact_sha compared per stem, not as a hex smear -------
expect sharded-revert-reordered 0 "a genuine revert of a sharded hard block, stories listed in another order -- RESOLVED" s1-adversarial-p
expect sharded-revert-partial 1 "story 2 lands on a sha no pass notarized -- FAIL (F5)" s1-adversarial-p
expect_says sharded-revert-partial s1-adversarial-p "F5-sharded-partial" "matches no" "earlier pass in this series"
expect_state sharded-revert-partial s1-adversarial-p DIVERGENT 3 "a partial revert of a sharded pass is not a release -- deny"
expect sharded-revert-atform 0 "passes notarize <stem>@<sha>, the record <stem>=<sha>: one key, the revert joins -- RESOLVED, no false F4" s1-adversarial-p

# MUTANT: restore the `tr -cd` read at all three sites (every layer of the fix). The reordered
# case must flip to F4 "never saw"; the partial case must still fail on F5, so the mutant is
# attributable to the reader and not to a validator that fails everything. Built in a directory
# holding the steering validator too: F6 resolves it beside $0, and without it the citation
# arm fails both cases for its own reason.
SH_DIR="$ROOT/mut-sha-key"; mkdir -p "$SH_DIR"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$SH_DIR/" 2>/dev/null
cp "$VALIDATOR" "$SH_DIR/control.sh"
python3 - "$VALIDATOR" "$SH_DIR/mutant.sh" <<'PY'
import sys
s = open(sys.argv[1]).read()
subs = [
  ('  sha_key "$(block_field "$f" \'artifact_sha\')"; P_SHA+=("$SHA_KEY")',
   '  P_SHA+=("$(block_field "$f" \'artifact_sha\' | tr -cd \'0-9a-fA-F\')")'),
  ('  sha_key "$(record_field "$rec" \'artifact_sha_before\')"; sha_b="$SHA_KEY"',
   '  sha_b="$(record_field "$rec" \'artifact_sha_before\' | tr -cd \'0-9a-fA-F\')"'),
  ('  sha_key "$(record_field "$rec" \'artifact_sha_after\')";  sha_a="$SHA_KEY"',
   '  sha_a="$(record_field "$rec" \'artifact_sha_after\'  | tr -cd \'0-9a-fA-F\')"'),
]
for o, n in subs:
    if s.count(o) != 1: sys.exit(3)
    s = s.replace(o, n)
open(sys.argv[2], "w").write(s)
PY
sh_rc=$?
sh_run() {  # $1 script  $2 case -> PASS | NEVER-SAW | F5 | OTHER
  local o
  o="$(bash "$1" --series "$ROOT/$2/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)" && { echo PASS; return; }
  case "$o" in *"never saw"*) echo NEVER-SAW ;; *"matches no"*) echo F5 ;; *) echo OTHER ;; esac
}
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$sh_rc" -ne 0 ] || [ ! -f "$SH_DIR/validate-steering-budget.sh" ] || cmp -s "$VALIDATOR" "$SH_DIR/mutant.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE STALE -- the three sha_key anchors are not each in the validator exactly once, or the sibling is missing\n' "MUTATION sha-key"
else
  c_row="$(sh_run "$SH_DIR/control.sh" sharded-revert-reordered) $(sh_run "$SH_DIR/control.sh" sharded-revert-partial)"
  m_row="$(sh_run "$SH_DIR/mutant.sh" sharded-revert-reordered) $(sh_run "$SH_DIR/mutant.sh" sharded-revert-partial)"
  if [ "$c_row" = "PASS F5" ] && [ "$m_row" = "NEVER-SAW F5" ]; then
    printf '  ok    %-28s control [%s], tr -cd restored [%s]\n' "MUTATION sha-key" "$c_row" "$m_row"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s control [%s] want [PASS F5]; tr -cd restored [%s] want [NEVER-SAW F5]\n' "MUTATION sha-key" "$c_row" "$m_row"
  fi
fi

# Arm A: the free bypass. Omit findings_major on one pass and arm E used to go dark.
expect counts-omitted 1 "a verdict with no derivable MAJOR count turns arm E OFF -- FAIL (A)" s1-adversarial-p
expect_says counts-omitted s1-adversarial-p "A-counts-required" \
  "severity counts are not derivable" "arm E in particular goes SILENT"

echo
# --- v0.103.0: arm H, the repair-record ---------------------------------------
# THE DIFFERENTIAL. repaired-delegated and repaired-inline-no-record have BYTE-IDENTICAL
# pass series; the only difference on disk is the two repair records. If arm H is
# neutralized (does not stat the record), repaired-inline-no-record flips to exit 0 and
# the assertion below goes red -- the fixture cannot pass a validator that ignores the
# record. That is the mutation proof, baked into the pair.
expect repaired-delegated        0 "converging series WITH repair records -- arm H satisfied"
expect repaired-inline-no-record 1 "S295: same series, NO repair records -- the lead repaired inline (H)"
expect_says repaired-inline-no-record s1-adversarial-pass "H-missing-record" \
  "H -- REPAIR-RECORD" "the lead does not repair the artifact itself"
expect repair-record-empty       1 "a narrative stub is not a structured repair record -- FAIL (H)"
expect_says repair-record-empty s1-adversarial-pass "H-structure" \
  "H -- REPAIR-RECORD" "not a structured record"

# --- v0.355.0: the emphasis pair. Neither of these two can move alone. --------
# repaired-delegated-bold is the FALSE POSITIVE that shipped for nine releases: a complete
# record in the house style, read as UNSTRUCTURED because `[[:space:]-]` has no `*`.
# repair-record-off-label is the floor under the fix: the reader is allowed to tolerate
# EMPHASIS around the taught label and nothing else, so a widening that admits a renamed
# field or a prose line turns this red. Fixing one by breaking the other is not a fix.
expect repaired-delegated-bold   0 "the house style -- '- **disposition:**' is the same field (H)"
expect repair-record-off-label   1 "'edit sites:' / 'derivation (x):' rename the field -- FAIL (H)"
expect_says repair-record-off-label s1-adversarial-pass "H-off-label" \
  "H -- REPAIR-RECORD" "not a structured record"

echo
# --- v0.59.0: --cycle-state, the mode the hooks call --------------------------
# The hooks hold NO logic. They shell out, read the exit code, and deny on 3. These five
# assertions are the entire contract between the validator and both hooks.
expect_state in-progress               s1-adversarial-p CONTINUE  0 "DECOY: healthy NOT_MET cycle -- arm D must NOT run here"
expect_state converged                 s1-adversarial-pass CONVERGED 0 "terminal MET: nothing to stop"
expect_state stalled                   s1-adversarial-p STALLED   3 "the STOP code: another pass is not the remedy"
expect_state divergent-terminal        s1-adversarial-p DIVERGENT 3 "the reference consumer's parked state, exactly"
expect_state divergent-terminal-resolved s1-adversarial-p RESOLVED 0 "THE RESUME: the record exists, so the verification pass is permitted"

# --- the sanctioned exit from a STALL ------------------------------------------
expect_state stalled              s1-adversarial-p STALLED  3 "no record: the stall stands"
expect_state stalled-resolved     s1-adversarial-p RESOLVED 0 "SAME trajectory + a valid record: the verification pass is legal. RESOLVED was unreachable for a stall and the branch was dead code"
expect_state stalled-record-invalid s1-adversarial-p STALLED 3 "OVER-FIRE CONTROL: an INVALID record legalises nothing, or the resume is reachable by writing any file"

# --- MUTATION: the stall call site is what makes RESOLVED reachable ------------
# Neuter ONLY the new terminal-record lookup on the stall path. `stalled-resolved` must go
# back to STALLED/3 -- the shipped defect on demand -- and `stalled` and
# `stalled-record-invalid` must be UNCHANGED, because a mutant that moves all three is too
# broad to attribute.
MUT="$ROOT/mutant-stall-resolution.sh"
MUT_OLD='  terminal_record_resolves "$((N - 1))" && RESOLVED_TERMINAL=1' \
MUT_NEW='  : ' \
python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MUT"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$VALIDATOR" "$MUT"; then
  echo "  FAIL  MUTATION matched nothing -- the stalled-resolved assertion proves nothing" >&2
  FAILURES=$((FAILURES + 1))
else
  m_res="$(bash "$MUT" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"
  m_pln="$(bash "$MUT" --series "$ROOT/stalled/s1-adversarial-p"          --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"
  m_inv="$(bash "$MUT" --series "$ROOT/stalled-record-invalid/s1-adversarial-p" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"
  if [ "$m_res" = "STALLED" ] && [ "$m_pln" = "STALLED" ] && [ "$m_inv" = "STALLED" ]; then
    printf '  ok    %-28s %s  (%s)\n' "MUTATION stall-resolution" "STALLED" "without the stall call site RESOLVED is unreachable again; the other two are unmoved, so the mutant is attributable"
  else
    echo "  FAIL  MUTATION: expected stalled-resolved to revert to STALLED, got '$m_res' (plain='$m_pln' invalid='$m_inv')" >&2
    FAILURES=$((FAILURES + 1))
  fi
fi

# --- the sanctioned exit from an UNSTAMPED divergence (arm C) --------------------
# Arm C raised and latched inline, and arm F skips every unstamped pass, so a valid record
# beside an arm-C pass changed nothing -- before the verification pass AND after it. Every
# case below shares one trajectory (CRITICALs 1 -> 2 in prior scope, never stamped); only
# the record and the verification pass vary.
expect_state cdiv-terminal            s1-adversarial-p DIVERGENT 3 "no record: the divergence stands"
expect_state cdiv-terminal-resolved   s1-adversarial-p RESOLVED  0 "THE RESUME: a valid record makes the verification pass legal, stamped or not"
expect_state cdiv-record-invalid      s1-adversarial-p DIVERGENT 3 "OVER-FIRE CONTROL: a record whose artifact GREW legalises nothing"
expect_state cdiv-verified            s1-adversarial-p CONVERGED 0 "the verification pass on a resolved artifact must not re-latch arm C"
expect_state cdiv-verified-unresolved s1-adversarial-p DIVERGENT 3 "a pass after the divergence that declares no record is another repair pass"
expect_state cdiv-verified-invalid    s1-adversarial-p DIVERGENT 3 "declaring an INVALID record is declaring none"
expect cdiv-terminal-resolved   1 "the gate still fails a series ENDING on a divergence, record or not (C)" s1-adversarial-p
expect cdiv-verified            0 "resolved on the record and verified MET -- the gate passes" s1-adversarial-p
expect cdiv-verified-unresolved 1 "the divergence was walked past -- FAIL (C)" s1-adversarial-p
expect cdiv-verified-invalid    1 "the record does not resolve it -- FAIL (C, F)" s1-adversarial-p
expect_says cdiv-verified-invalid s1-adversarial-p "cdiv-invalid-names-defect" \
  "C -- DIVERGENCE" "F -- RESOLUTION" "did not shrink"
# The terminal branch's own error. Arm D fires on these series too, so the exit code alone
# cannot see arm C go silent there -- only the arm's name can.
expect_says cdiv-terminal-resolved s1-adversarial-p "cdiv-terminal-names-C" "C -- DIVERGENCE"

# --- MUTATIONS: each branch of the arm-C resolution block is load-bearing --------
# Built with an EXACT-ONCE replace: an anchor that occurs zero times or twice refuses (exit 3)
# rather than silently mutating nothing or the wrong site. The terminal lookup is spelled on
# `ci` precisely so its anchor is not arm F's `"$i"` line. Each mutant must move its NAMED case
# and leave both controls where the shipped validator puts them, or it is not attributable.
#
# THE MUTANTS LIVE BESIDE THE STEERING VALIDATOR. Outside --cycle-state a record's citation is
# checked by `validate-steering-budget.sh` resolved beside $0; a mutant without it fails every
# record for that reason alone, so a GATE row would read 1 whether or not the mutation applied.
# The unmutated control in the same directory must reproduce the shipped gate first.
CDIV_DIR="$ROOT/mut-cdiv"; mkdir -p "$CDIV_DIR"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$CDIV_DIR/" 2>/dev/null
cp "$VALIDATOR" "$CDIV_DIR/control.sh"
cdiv_gate() {  # $1 validator  $2 case -> the gate's exit code
  bash "$1" --series "$ROOT/$2/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" >/dev/null 2>&1
  printf '%s' "$?"
}
ASSERTIONS=$((ASSERTIONS + 1))
cdiv_ctl="$(cdiv_gate "$CDIV_DIR/control.sh" cdiv-verified)"
if [ -f "$CDIV_DIR/validate-steering-budget.sh" ] && [ "$cdiv_ctl" = "0" ]; then
  printf '  ok    %-28s gate=0  (the unmutated copy in the mutant dir passes the verified series)\n' "MUTATION cdiv-control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s gate=%s on cdiv-verified, want 0 -- a gate row on a mutant here proves nothing\n' "MUTATION cdiv-control" "$cdiv_ctl"
fi
cdiv_mutant() {  # $1 out  (MUT_OLD / MUT_NEW in the env) -> python's exit status
  python3 -c '
import os, sys
s = open(sys.argv[1]).read()
o = os.environ["MUT_OLD"]
if s.count(o) != 1: sys.exit(3)
open(sys.argv[2], "w").write(s.replace(o, os.environ["MUT_NEW"]))
' "$VALIDATOR" "$1"
}
cdiv_state() {  # $1 validator  $2 case -> STATE/rc
  local o rc
  o="$(bash "$1" --series "$ROOT/$2/s1-adversarial-p" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null)"
  rc=$?
  printf '%s/%s' "$(printf '%s' "$o" | cut -f1)" "$rc"
}
cdiv_score() {  # $1 label  $2 mutant  $3 want-row  $4.. cases
  local label="$1" mut="$2" want="$3" row="" c; shift 3
  for c in "$@"; do row="$row $(cdiv_state "$mut" "$c")"; done
  row="${row# }"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$row" = "$want" ]; then
    printf '  ok    %-28s [%s]  (the named case moved, its controls did not)\n' "$label" "$row"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s [%s] want [%s]\n' "$label" "$row" "$want"
  fi
}
cdiv_build() {  # $1 label  $2 out -> 0 if built and different
  local rc
  cdiv_mutant "$2"; rc=$?
  if [ "$rc" -ne 0 ] || cmp -s "$VALIDATOR" "$2"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s FIXTURE STALE -- the anchor is not in the validator exactly once (python rc %s)\n' "$1" "$rc"
    return 1
  fi
}

# M1: drop the terminal lookup. cdiv-terminal-resolved re-deadlocks; the two without a valid record were never RESOLVED.
MUT="$CDIV_DIR/mutant-cdiv-terminal.sh"
MUT_OLD='    terminal_record_resolves "$ci" && RESOLVED_TERMINAL=1' MUT_NEW='    :' \
  cdiv_build "MUTATION cdiv-terminal" "$MUT" \
  && cdiv_score "MUTATION cdiv-terminal" "$MUT" "DIVERGENT/3 DIVERGENT/3 DIVERGENT/3" \
       cdiv-terminal-resolved cdiv-terminal cdiv-record-invalid

# M2: the non-terminal branch never resolves. cdiv-verified re-latches -- the defect after the verification pass.
MUT="$CDIV_DIR/mutant-cdiv-never.sh"
MUT_OLD='      if validate_record "$cdiv_rec" "${P_FILE[$ci]}" "$ci"; then' MUT_NEW='      if false; then' \
  cdiv_build "MUTATION cdiv-never-resolves" "$MUT" \
  && cdiv_score "MUTATION cdiv-never-resolves" "$MUT" "DIVERGENT/3 DIVERGENT/3 DIVERGENT/3" \
       cdiv-verified cdiv-verified-unresolved cdiv-verified-invalid \
  && {
    ASSERTIONS=$((ASSERTIONS + 1))
    m_gate="$(cdiv_gate "$MUT" cdiv-verified)"
    if [ "$m_gate" = "1" ]; then
      printf '  ok    %-28s gate=1  (and the GATE refuses the verified series again)\n' "MUTATION cdiv-never-resolves"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-28s gate=%s on cdiv-verified, want 1\n' "MUTATION cdiv-never-resolves" "$m_gate"
    fi
  }

# M3: the non-terminal branch resolves on ANY declared record. cdiv-verified-invalid escapes;
# cdiv-verified was already clear and cdiv-verified-unresolved declares nothing.
MUT="$CDIV_DIR/mutant-cdiv-always.sh"
MUT_OLD='      if validate_record "$cdiv_rec" "${P_FILE[$ci]}" "$ci"; then' MUT_NEW='      if true; then' \
  cdiv_build "MUTATION cdiv-always-resolves" "$MUT" \
  && cdiv_score "MUTATION cdiv-always-resolves" "$MUT" "CONVERGED/0 CONVERGED/0 DIVERGENT/3" \
       cdiv-verified-invalid cdiv-verified cdiv-verified-unresolved

# M4: the terminal branch stops RAISING arm C. Every state and exit is unchanged, because arm D
# fails the same series -- so only the named arm can see it. cdiv-terminal-resolved loses its
# `C -- DIVERGENCE` line; the non-terminal cdiv-verified-unresolved keeps its own.
MUT="$CDIV_DIR/mutant-cdiv-terminal-silent.sh"
MUT_OLD='    err "C -- DIVERGENCE" "${P_CDIV_MSG[$ci]}"
    C_DIVERGED=1
    terminal_record_resolves' MUT_NEW='    :
    C_DIVERGED=1
    terminal_record_resolves' \
  cdiv_build "MUTATION cdiv-terminal-silent" "$MUT" \
  && {
    ASSERTIONS=$((ASSERTIONS + 1))
    # The output is captured BEFORE it is counted: the validator exits 1 on both series, and a
    # pipeline's `|| m=0` would read that exit as zero matches under pipefail.
    m_out="$(bash "$MUT" --series "$ROOT/cdiv-terminal-resolved/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
    m_t="$(grep -c 'C -- DIVERGENCE' <<<"$m_out")" || m_t=0
    m_out="$(bash "$MUT" --series "$ROOT/cdiv-verified-unresolved/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
    m_u="$(grep -c 'C -- DIVERGENCE' <<<"$m_out")" || m_u=0
    if [ "$m_t" = "0" ] && [ "$m_u" != "0" ]; then
      printf '  ok    %-28s terminal C lines=0, non-terminal=%s  (the terminal error is pinned by name)\n' "MUTATION cdiv-terminal-silent" "$m_u"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-28s terminal C lines=%s want 0, non-terminal=%s want >0\n' "MUTATION cdiv-terminal-silent" "$m_t" "$m_u"
    fi
  }

# --- the citation must OUTLIVE the session that wrote it ------------------------
# `stalled-resolved`'s operator adjudication lives in `prior-session-transcript.jsonl`,
# NOT in the current session's transcript. That is the real shape: a resolution record
# outlives its session, and `transcript_path` is always the session ASKING permission,
# never the one in which the operator spoke.
#
# The pair is the assertion. Current transcript alone -> the citation is unfindable, the
# record stops counting and the stall re-deadlocks. Add the DIRECTORY the transcripts
# actually live in and the same record verifies. Same tree, same record, same citation.
cs_state() {  # cs_state <extra-args...> -> prints the state
  vrun out "$VALIDATOR" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state \
    --transcript "$TRANSCRIPT" "$@"
  printf '%s' "$VR_OUT" | cut -f1
}
ASSERTIONS=$((ASSERTIONS + 2))
got_nodir="$(cs_state)"
got_dir="$(cs_state --transcript-dir "$ROOT")"
if [ "$got_nodir" = "STALLED" ]; then
  printf '  ok    %-28s %s  (%s)\n' "cross-session (no dir)" "STALLED" "a citation from a PRIOR session is unfindable in one transcript -- the deadlock"
else
  echo "  FAIL  cross-session (no dir): expected STALLED, got '$got_nodir'" >&2; FAILURES=$((FAILURES + 1))
fi
if [ "$got_dir" = "RESOLVED" ]; then
  printf '  ok    %-28s %s  (%s)\n' "cross-session (with dir)" "RESOLVED" "the SAME record verifies against the corpus the citation actually lives in"
else
  echo "  FAIL  cross-session (with dir): expected RESOLVED, got '$got_dir'" >&2; FAILURES=$((FAILURES + 1))
fi

fi
if sg corp; then
# --- A CORPUS THAT HELD NO RECORD IS THE ABSENT CORPUS, ONE STEP LATER ----------
# `steer_dir_has_transcript` asks whether a `*.jsonl` is READABLE, never whether it holds a
# record. So a directory of empty or sidechain-only transcripts set STEER_FLAG, skipped the
# two-tier fail-open, ran the predicate and DENIED -- while passing NO flag at all failed
# open. Supplying MORE ground truth than the passing case requires wedged the pipeline.
#
# THE NARROWING IS THE ASSERTION, AND IT IS WHY EVERY ARM HERE COMES IN A PAIR. "Held no
# record" fails open; "held operator records that do not carry the quote" keeps denying,
# because that corpus REFUTED the citation and that is S290. A fix that cannot tell the two
# apart acquits the forgery, so each acquitted world below sits beside a denied one that
# differs from it in exactly one property.
CORP="$ROOT/corpora"; mkdir -p "$CORP"
# no-records: a directory holding a transcript FILE with nothing parseable in it. The
# motivating world, kept as its own case: a dir with no `*.jsonl` at all does not reach the
# predicate (steer_dir_has_transcript refuses it), so it cannot exercise this branch.
mkdir -p "$CORP/no-records"; : > "$CORP/no-records/session-a.jsonl"
# sidechain-only: parseable lines, every one dropped by the reader's `!r.isSidechain` filter.
# A subagent's turns are not the operator's, and a corpus made only of them read ZERO.
mkdir -p "$CORP/sidechain"
printf '%s\n' '{"type":"user","isSidechain":true,"timestamp":"2026-07-12T03:00:00Z","message":{"content":"Revert the p1 to p2 repair wholesale — it made the check unfalsifiable."}}' \
  > "$CORP/sidechain/session-a.jsonl"
# assistant-only: THE NEAR-MISS, and it must DENY. Records parse and are read; none of them
# is an operator turn. That is the S290 shape exactly -- the machine spoke, the human did
# not -- and it is one property from `sidechain` above, which is acquitted.
mkdir -p "$CORP/assistant"
printf '%s\n' '{"type":"assistant","timestamp":"2026-07-12T03:00:00Z","message":{"content":[{"type":"text","text":"Revert the p1 to p2 repair wholesale — it made the check unfalsifiable."}]}}' \
  > "$CORP/assistant/session-a.jsonl"
# operator-no-quote: the other near-miss. A real human turn, in the window, that simply does
# not carry the cited words. The ground truth is present and refutes the record.
mkdir -p "$CORP/operator-no-quote"
printf '%s\n' '{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Something this resolution record does not quote, at ample length."}}' \
  > "$CORP/operator-no-quote/session-a.jsonl"
# since-excluded: THE ONE THAT MUST KEEP DENYING, and it is not obvious. The corpus holds the
# GENUINE operator turn; its file's MTIME predates the bound, so `--since` drops the FILE and
# the reader sees zero records. That zero is a fact about the BOUND, not about the corpus --
# and the bound is `invoked_at` from a pass file the LEAD writes. Acquitting it would hand the
# lead a one-field fail-open over ground truth that refutes nothing. The predicate withholds
# the token when the file LIST is empty, which is exactly this state.
mkdir -p "$CORP/since-excluded"
cp "$ROOT/prior-session-transcript.jsonl" "$CORP/since-excluded/session-a.jsonl"
touch -t 200001010000 "$CORP/since-excluded/session-a.jsonl"

# $1 label  $2 corpus-dir  $3 expected STATE  $4 expected rc  $5 stderr expectation (UNVERIFIABLE|quiet)  $6 why
# ASSERTS THE MESSAGE, not only the state. A fail-open that stops SAYING it is unverifiable
# is indistinguishable from a verified citation in the flow log, which is the whole reason
# the no-transcript branch prints one.
corp_state() {
  local label="$1" cdir="$2" want_state="$3" want_rc="$4" want_err="$5" why="$6" out rc state err
  ASSERTIONS=$((ASSERTIONS + 1))
  vrun split "$VALIDATOR" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state \
         --transcript-dir "$cdir"
  out="$VR_OUT"; rc="$VR_RC"
  state="$(printf '%s' "$out" | cut -f1)"
  err="quiet"
  grep -qF 'ADVERSARIAL_CITATION_UNVERIFIABLE' <<<"$VR_ERR" && err="UNVERIFIABLE"
  if [ "$state" = "$want_state" ] && [ "$rc" -eq "$want_rc" ] && [ "$err" = "$want_err" ]; then
    printf '  ok    %-28s %s/%s %s  (%s)\n' "$label" "$state" "$rc" "$err" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s/%s %s want=%s/%s %s  (%s)\n' \
      "$label" "${state:-<none>}" "$rc" "$err" "$want_state" "$want_rc" "$want_err" "$why"
  fi
}

# THE CONTROL FIRST. The real corpus VERIFIES, so every deny below is a deny about the
# citation and not a series that could never resolve.
corp_state corpus-real          "$ROOT"                  RESOLVED 0 quiet        "CONTROL: the genuine operator turn is in this corpus -- the record verifies"
corp_state corpus-no-records    "$CORP/no-records"       RESOLVED 0 UNVERIFIABLE "THE SUBJECT: a present transcript holding zero records could not have verified anything -- fail OPEN, and say so"
corp_state corpus-sidechain     "$CORP/sidechain"        RESOLVED 0 UNVERIFIABLE "every line dropped as a sidechain: FILES were opened and zero records came back, same fact"
corp_state corpus-since-excluded "$CORP/since-excluded"  STALLED  3 quiet        "THE BOUND, NOT THE CORPUS: --since dropped the only FILE, so zero is a fact about a lead-written field -- DENIED"
corp_state corpus-assistant     "$CORP/assistant"        STALLED  3 quiet        "THE NEAR-MISS: records WERE read and none is an operator turn -- the S290 shape, still DENIED"
corp_state corpus-operator-quiet "$CORP/operator-no-quote" STALLED 3 quiet       "THE NEAR-MISS: a real operator turn that does not carry the quote REFUTES the record -- still DENIED"

# THE PROOF THAT since-excluded IS A LIVE ATTACK AND NOT A CURIOSITY. Unbounded, that SAME
# corpus verifies that SAME citation -- so its zero came from the bound, over ground truth
# that refutes nothing. Without this arm the deny above is indistinguishable from a corpus
# that simply never held the words, and the `files.length` conjunct would read as decoration.
ASSERTIONS=$((ASSERTIONS + 1))
STEER_FOR_SINCE="$(cd "$(dirname "$VALIDATOR")" && pwd)/validate-steering-budget.sh"
since_out="$(bash "$STEER_FOR_SINCE" --dir "$CORP/since-excluded" \
  --cite "Cut the claim and re-verify" --authorized-at "" --quiet 2>/dev/null)"
since_rc=$?
if [ "$since_rc" -eq 0 ]; then
  printf '  ok    %-28s %s  (%s)\n' "since-excluded-unbounded" "MATCH" "unbounded, the SAME corpus verifies -- so the deny above came from the BOUND, not from an absent operator"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s got %s/%s want MATCH/0 -- the seed never held the quote, so the since arm above proves nothing\n' \
    "since-excluded-unbounded" "${since_out:-<none>}" "$since_rc"
fi

# THE FORGED BOUND, END TO END, through the SHIPPING validator. The arm above drives the
# predicate directly; this one drives the attack as a lead would actually mount it -- by
# rewriting `invoked_at` on the pass the resolution record resolves, which is the sole source
# of `--since`. It must stay STALLED, and it is the discriminating case: a token emitted
# without the `files.length` conjunct reports RESOLVED/UNVERIFIABLE here over a corpus holding
# the operator's real message, which is a fail-open on a field the lead writes.
ASSERTIONS=$((ASSERTIONS + 1))
FORGE="$ROOT/forged-since"; mkdir -p "$FORGE"
cp -R "$ROOT/stalled-resolved" "$FORGE/series"
cp "$ROOT"/*.jsonl "$FORGE/" 2>/dev/null
sed -i.bak 's/^invoked_at: .*/invoked_at: 2099-01-01T00:00:00Z/' "$FORGE/series/s1-adversarial-p4.md"
rm -f "$FORGE/series/s1-adversarial-p4.md.bak"
forge_out="$(bash "$VALIDATOR" --series "$FORGE/series/s1-adversarial-p" --cycle-state \
  --transcript-dir "$ROOT" 2>/dev/null)"
forge_rc=$?
forge_state="$(printf '%s' "$forge_out" | cut -f1)"
if [ "$forge_state" = "STALLED" ] && [ "$forge_rc" -eq 3 ]; then
  printf '  ok    %-28s %s/%s  (%s)\n' "forged-invoked-at" "$forge_state" "$forge_rc" "a future invoked_at empties the corpus by mtime; the third state must NOT open on a bound the lead controls"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s %s/%s want STALLED/3  (%s)\n' "forged-invoked-at" "${forge_state:-<none>}" "$forge_rc" "a lead-forged invoked_at bought a fail-open over a corpus holding the operator's real message"
fi

# GATE MODE STILL FAILS CLOSED ON THE THIRD STATE. The RELEASE surface must not open on a
# claim nothing checked. `divergent-resolved` is the series used because it PASSES the gate
# on the real corpus -- `stalled-resolved` exits 1 whatever the corpus says, so a deny read
# off it would be non-discriminating and its agreement would mean nothing.
gate_corp() { # $1 label  $2 corpus  $3 want rc  $4 why
  local label="$1" cdir="$2" want="$3" why="$4" got
  ASSERTIONS=$((ASSERTIONS + 1))
  vrun out "$VALIDATOR" --series "$ROOT/divergent-resolved/s1-adversarial-p" --transcript-dir "$cdir"
  got="$VR_RC"
  if [ "$got" -eq "$want" ]; then
    printf '  ok    %-28s exit=%s  (%s)\n' "$label" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s  (%s)\n' "$label" "$got" "$want" "$why"
  fi
}
gate_corp gate-corpus-real       "$ROOT"            0 "CONTROL: the gate PASSES this series on the real corpus, so the denies below are about the corpus"
gate_corp gate-corpus-no-records "$CORP/no-records" 1 "the gate still fails CLOSED on the third state -- a release never opens on an unverifiable claim"
gate_corp gate-corpus-sidechain  "$CORP/sidechain"  1 "same, by the other route to zero records"

# --- MUTATION: the third state, three ways it goes wrong ------------------------
# THE COPIES NEED THEIR SIBLING. `STEER_SCRIPT` resolves as `$(dirname "$0")/…`, so a lone
# copy finds no predicate, every citation becomes UNVERIFIABLE (rc!=2 branch) and --cycle-state
# fails OPEN on everything -- which would score `corpus-assistant` as acquitted and read as a
# kill it did not earn. m3 mutates the PREDICATE, so its copy needs its own directory with a
# convergence validator beside it.
MWORK="$ROOT/third-state-mutants"; mkdir -p "$MWORK"
SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
cp "$VALIDATOR" "$MWORK/validate-adversarial-convergence.sh"
cp "$SRC_DIR/validate-steering-budget.sh" "$MWORK/validate-steering-budget.sh"

# $1 convergence-script  $2 corpus -> "<STATE>/<rc>/<err>"
ts_probe() {
  local v="$1" cdir="$2" out rc state err
  out="$(bash "$v" --series "$ROOT/stalled-resolved/s1-adversarial-p" --cycle-state \
         --transcript-dir "$cdir" 2>"$ROOT/ts.err")"
  rc=$?
  state="$(printf '%s' "$out" | cut -f1)"
  err="quiet"; grep -qF 'ADVERSARIAL_CITATION_UNVERIFIABLE' "$ROOT/ts.err" && err="UNVERIFIABLE"
  printf '%s/%s/%s' "${state:-NONE}" "$rc" "$err"
}
# The five worlds every mutant is scored on, in order. One acquitted, three denied, plus the
# verifying control -- a mutant that moves only one cell is attributable, and one that moves
# all five is not a finding about this branch. The three denied worlds fail for THREE
# DIFFERENT reasons (no operator turn / the quote is absent / the bound emptied the file
# list), which is what lets each mutant below name its own subject.
TS_CORPORA="$ROOT $CORP/no-records $CORP/assistant $CORP/operator-no-quote $CORP/since-excluded"
TS_REAL="RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE STALLED/3/quiet STALLED/3/quiet STALLED/3/quiet"

ts_row() { # ts_row <convergence-script> -> the five verdicts, space separated (`.` for a cell RSEL skips)
  local v="$1" c row="" i=0
  for c in $TS_CORPORA; do i=$((i + 1)); if ron "$i"; then row="$row $(ts_probe "$v" "$c")"; else row="$row ."; fi; done
  echo $row
}

# THE UNMUTATED CONTROL, in the mutants' own directory. A partial copy tree makes every
# mutant "survive" and this control pass too, because two inert runs compare equal -- so the
# control carries a POSITIVE conjunct: it must reproduce the acquittal AND both denies.
ASSERTIONS=$((ASSERTIONS + 1))
ts_ctrl="$(ts_row "$MWORK/validate-adversarial-convergence.sh")"
if [ "$ts_ctrl" = "$(echo $TS_REAL)" ]; then
  printf '  ok    %-28s [%s]\n' "CONTROL third-state copy" "$ts_ctrl"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s got [%s] want [%s] -- the copy tree is what fails; every mutant below is vacuous\n' \
    "CONTROL third-state copy" "$ts_ctrl" "$(echo $TS_REAL)"
fi

# $1 label  $2 which-file (conv|pred)  $3 old  $4 new  $5 expected four verdicts  $6 why
ts_mutate() {
  local label="$1" which="$2" old="$3" new="$4" want="$5" why="$6"
  local mdir="$ROOT/tsm-$label"
  ASSERTIONS=$((ASSERTIONS + 1))
  mkdir -p "$mdir"
  cp "$VALIDATOR" "$mdir/validate-adversarial-convergence.sh"
  cp "$SRC_DIR/validate-steering-budget.sh" "$mdir/validate-steering-budget.sh"
  local target="$mdir/validate-adversarial-convergence.sh"
  [ "$which" = pred ] && target="$mdir/validate-steering-budget.sh"
  local src="$VALIDATOR"
  [ "$which" = pred ] && src="$SRC_DIR/validate-steering-budget.sh"
  if ! MUT_OLD="$old" MUT_NEW="$new" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
       "$src" "$target"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation DID NOT APPLY -- a mutant that never existed scores every arm as a kill\n' "MUTATION $label"
    return
  fi
  if cmp -s "$src" "$target"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched NOTHING -- this assertion proves nothing\n' "MUTATION $label"
    return
  fi
  # A mutant that is no longer a PROGRAM emits nothing, and nothing scores as a kill.
  if [ "$which" = conv ] && ! bash -n "$target" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $label"
    return
  fi
  local got wm
  rsel "$want" "$TS_REAL"; wm="$(rmask "$want")"
  got="$(ts_row "$mdir/validate-adversarial-convergence.sh")"
  RSEL=""
  if [ "$got" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]  (%s)\n' "MUTATION $label" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]  (%s)\n' "MUTATION $label" "$got" "$(echo $want)" "$why"
  fi
}

# m1 -- THE OVER-BROAD ACQUITTAL the entry itself warns against: every rc=2 is unverifiable,
# so a corpus that REFUTED the citation acquits it too. Both near-misses must flip; that is
# the fix this branch is deliberately not.
ts_mutate over-broad conv \
  'if [ "$cite_rc" -eq 2 ] && [ "$cite_out" = "NOMATCH-NO-RECORDS" ] && [ "$CYCLE_STATE" -eq 1 ]; then' \
  'if [ "$cite_rc" -eq 2 ] && [ "$CYCLE_STATE" -eq 1 ]; then' \
  "RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE" \
  "treating ALL rc=2 as unverifiable acquits the S290 forgery AND the forged bound -- every deny flips, which is the over-broad fix"

# m2 -- THE FIX DISABLED. The token is never matched, so the third state denies again: the
# shipped defect on demand. Only the zero-records world moves, which is what makes m1's
# two-cell flip attributable to the WIDENING and not to the branch existing.
ts_mutate disabled conv \
  '[ "$cite_out" = "NOMATCH-NO-RECORDS" ]' \
  '[ "$cite_out" = "ZZ-UNREACHABLE-TOKEN-ZZ" ]' \
  "RESOLVED/0/quiet STALLED/3/quiet STALLED/3/quiet STALLED/3/quiet STALLED/3/quiet" \
  "without the branch a present-but-empty corpus DENIES again -- worse off for supplying ground truth"

# m3 -- THE PREDICATE emits the token on BOTH NOMATCH paths, which is the same acquittal as
# m1 reached from the other side of the interface. It proves the branch keys on a distinction
# the PREDICATE draws, not on one the caller invented: mutate the producer and the caller
# widens with it. Anchored on the `console.log` line the no-quote path owns -- the zero-records
# path's own log line is a different string, so this cannot edit both.
ts_mutate token-on-both pred \
  '  console.log("NOMATCH"); process.exit(2);' \
  '  console.log("NOMATCH-NO-RECORDS"); process.exit(2);' \
  "RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE RESOLVED/0/UNVERIFIABLE STALLED/3/quiet" \
  "a predicate that cannot tell its two NOMATCHes apart hands the caller the over-broad acquittal. The since-excluded cell is UNMOVED and that is the point: this mutation edits only the records-PRESENT path, so m4 below is the only arm that can see the files.length conjunct"

# m4 -- THE SECURITY CONJUNCT REMOVED, and the reason it needs its own mutant is that the
# three above cannot see it: they all leave `files.length` in place, so an author could delete
# it and every one of them stays green. A zero produced by the BOUND then wears the same token
# as a zero produced by the corpus, and `--since` -- a lead-written `invoked_at` -- becomes a
# one-field fail-open. ONLY the since-excluded cell moves, which is what makes it attributable.
ts_mutate since-acquitted pred \
  'console.log(files.length ? "NOMATCH-NO-RECORDS" : "NOMATCH");' \
  'console.log("NOMATCH-NO-RECORDS");' \
  "RESOLVED/0/quiet RESOLVED/0/UNVERIFIABLE STALLED/3/quiet STALLED/3/quiet RESOLVED/0/UNVERIFIABLE" \
  "without files.length a forged future --since acquits itself over a corpus holding the operator's real message"

echo
fi
if sg arms_ij; then
# --- arm J: RE-OPEN ------------------------------------------------------------
expect reopen-unrecorded 1 "a pass ran after EXIT_CONDITION_MET reporting 1C/2M -- RE-OPEN, FAIL (J)" s1-adversarial-p
expect reopen-same-bytes 0 "THE DECOY: p1 MET -> p2 MET at the SAME artifact_sha -- same bytes, same residue, not a re-open" s1-adversarial-p
expect reopen-moved-clean 1 "p1 MET -> p2 MET at a CHANGED artifact_sha with 0 findings -- the artifact MOVED after sign-off, RE-OPEN, FAIL (J)" s1-adversarial-p
expect reopen-sha-absent 0 "no artifact_sha on either side -- the arm fails OPEN rather than erroring on pre-migration data" s1-adversarial-p
expect reopen-recorded   0 "a re-open DECLARED with resolution: REOPEN_AFTER_MET resumes -- the arm has a door" s1-adversarial-p
expect_state reopen-unrecorded s1-adversarial-p REOPENED  3 "the hooks must deny the dispatch on a live re-open"
# GATE MODE AND HOOK MODE MUST NOT DISAGREE. Each of these failed the gate (exit 1) while
# --cycle-state answered CONVERGED/0, so the hooks were told to proceed on a series the gate
# had already refused. Arm F ran and set nothing the emit block could read.
expect_state divergent-unresolved       s1-adversarial-p    DIVERGENT 3 "a pass ran past a hard block with no resolution -- deny"
expect_state divergent-frozen           s1-adversarial-p    DIVERGENT 3 "FREEZE_SCOPE is not a resolution -- deny"
expect_state divergent-laundered-cut    s1-adversarial-p    DIVERGENT 3 "a repair wearing CUT_SCOPE's name is not a release -- deny"
expect_state divergent-laundered-revert s1-adversarial-p    DIVERGENT 3 "REVERT_REPAIR onto an unnotarized sha is not a release -- deny"
expect_state divergent                  s1-adversarial-pass DIVERGENT 3 "a live divergence denies dispatch"
expect_state repair-injected            s1-adversarial-pass DIVERGENT 3 "a repair injecting defects denies dispatch"
expect_state stalled-then-diverges      s1-adversarial-p    DIVERGENT 3 "divergence outranks the stall it followed"
expect_state restart-cycle              s1-adversarial-p    REOPENED  3 "a RESTART_CYCLE series still owes its declaration"
# Found by the pairing arm below, not by hand: an adjudication that presents no real choice
# denies the dispatch, and none of the three said so.
expect_state adjudication-no-options        s1-adversarial-p DIVERGENT 3 "a record presenting no options denies dispatch"
expect_state adjudication-one-option        s1-adversarial-p DIVERGENT 3 "a menu of one denies dispatch"
expect_state adjudication-no-recommendation s1-adversarial-p DIVERGENT 3 "a menu with no recommendation denies dispatch"
expect_state adjudication-locked-badged     s1-adversarial-p DIVERGENT 3 "a badge on a locked requirement denies dispatch"
expect_state adjudication-unlocked-none     s1-adversarial-p DIVERGENT 3 "recommended_option: none on an unlocked record denies dispatch"
expect_state adjudication-locked-lr-paren   s1-adversarial-p DIVERGENT 3 "a badge on LR-S1-1 (...) denies dispatch"
expect_state adjudication-unlocked-emdash   s1-adversarial-p CONVERGED 0 "'none — <prose>' is unlocked: one badge must not deny"
expect_state reopen-same-bytes  s1-adversarial-p CONVERGED 0 "a same-bytes re-review must not be denied"
expect_state reopen-moved-clean s1-adversarial-p REOPENED  3 "the hooks must deny on a re-open even when the successor pass found nothing"
expect_state reopen-sha-absent  s1-adversarial-p CONVERGED 0 "an unevidenced re-open must not be denied"
expect_state reopen-recorded   s1-adversarial-p CONVERGED 0 "a declared re-open ran its sub-cycle to convergence -- never denied"
echo
# --- arm I: RESOLUTION CEILING -------------------------------------------------
# The four cases carry the SAME five-pass series and differ only in the records beside
# it. Any rung that reads the series cannot separate them; that is the point.
expect_state ceiling-unanchored        s1-adversarial-p CEILING   3 "the exit taken TWICE, second release unanchored -- the hooks must deny"
expect_state ceiling-anchored-release  s1-adversarial-p CONTINUE  0 "THE DOOR: same series, second release CUT_SCOPE (bytes fell) -- without this the arm wedges every twice-resolved cycle"
expect_state ceiling-single-resolution s1-adversarial-p CONTINUE  0 "THE DECOY: ONE unanchored release is the SANCTIONED exit and must cost nothing"
expect_state ceiling-converged         s1-adversarial-p CONVERGED 0 "two unanchored releases but the cycle TERMINATED -- no gate fails retroactively"

expect ceiling-unanchored 1 "gate: a cycle released twice without an anchor does not pass" s1-adversarial-p
expect ceiling-converged  0 "gate: it converged; the arm is suppressed by the terminal verdict" s1-adversarial-p
expect_says ceiling-unanchored s1-adversarial-p "I-remedy" \
  "I -- CEILING" "RELEASED too cheaply" "CUT_SCOPE" "REVERT_REPAIR"

# I must PRE-EMPT D, for the same reason E does: a series told to "run another pass to a
# clean verdict" has been handed the advice that produced the passes.
ASSERTIONS=$((ASSERTIONS + 1))
# The same question `expect ceiling-unanchored` asked: the memo answers it from that run.
vrun both "$VALIDATOR" --series "$ROOT/ceiling-unanchored/s1-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT"
if grep -qF -- "$D_GENERIC" <<<"$VR_OUT"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s a CEILING series still got Check D generic advice. I must pre-empt D.\n' "ceiling-preempts-d"
else
  printf '  ok    %-28s I pre-empts D: the released-twice series is not told to run another pass\n' "ceiling-preempts-d"
fi

# --- MUTATION: each conjunct of arm I, one at a time ---------------------------
# THE COPIES NEED A SIBLING. `STEER_SCRIPT` is resolved as `$(dirname "$0")/…`, so a
# validator copied into $ROOT cannot find validate-steering-budget.sh, every
# operator_authorization becomes UNVERIFIABLE, and --cycle-state FAILS OPEN on it. A
# mutant that cannot check a citation is not testing this arm -- it is testing the copy.
# Hence the sibling, and hence the unmutated control below, which must reproduce all four
# real verdicts before any mutant's changed verdict is attributable to its mutation.
cp "$(cd "$(dirname "$VALIDATOR")" && pwd)/validate-steering-budget.sh" "$ROOT/validate-steering-budget.sh" 2>/dev/null

mstate() {  # mstate <script> <case-dir> -> the --cycle-state STATE
  bash "$1" --series "$ROOT/$2/s1-adversarial-p" --cycle-state \
    --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>/dev/null | cut -f1
}

CEIL_CASES="ceiling-unanchored ceiling-anchored-release ceiling-single-resolution ceiling-converged"
CEIL_REAL="CEILING CONTINUE CONTINUE CONVERGED"

# THE UNMUTATED CONTROL. A lone copy that dies sourcing or mis-resolves a sibling emits
# nothing, and "no output" otherwise scores as a kill on every mutant below.
CTRL="$ROOT/control-unmutated.sh"
cp "$VALIDATOR" "$CTRL"
ASSERTIONS=$((ASSERTIONS + 1))
ctrl_got=""
for c in $CEIL_CASES; do ctrl_got="$ctrl_got $(mstate "$CTRL" "$c")"; done
if [ "$(echo $ctrl_got)" = "$(echo $CEIL_REAL)" ]; then
  printf '  ok    %-28s %s\n' "CONTROL unmutated copy" "reproduces all four verdicts from \$ROOT, so a mutant's change is the mutation"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s got [%s] want [%s] -- the harness itself is what fails; every mutant below is vacuous\n' \
    "CONTROL unmutated copy" "$(echo $ctrl_got)" "$(echo $CEIL_REAL)"
fi

# $1 label  $2 old-text  $3 new-text  $4 expected four states (space separated)
# A mutant must fail ONLY its own assertion: two moved cases mean the conjuncts are
# entangled and one of them is vacuous.
mutate_ceiling() {
  local label="$1" old="$2" new="$3" want="$4" got="" c
  # `mut` on its own line: bash 3.2 expands every word of a `local` before assigning any
  # of them, so `mut="$ROOT/mutant-$label.sh"` on the line above reads $label UNSET and
  # dies under `set -u`.
  local mut="$ROOT/mutant-$label.sh"
  ASSERTIONS=$((ASSERTIONS + 1))
  MUT_OLD="$old" MUT_NEW="$new" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched NOTHING -- this assertion proves nothing\n' "MUTATION $label"
    return
  fi
  # cmp proves bytes moved; bash -n proves the mutant is still a PROGRAM. A mutant that
  # dies on a syntax error emits nothing, and nothing scores as a kill.
  if ! bash -n "$mut" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $label"
    return
  fi
  local i=0 wm; rsel "$want" "$CEIL_REAL"; wm="$(rmask "$want")"
  for c in $CEIL_CASES; do i=$((i + 1)); if ron "$i"; then got="$got $(mstate "$mut" "$c")"; else got="$got ."; fi; done
  RSEL=""
  if [ "$(echo $got)" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]\n' "MUTATION $label" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "MUTATION $label" "$(echo $got)" "$(echo $want)"
  fi
}

# (1) The KIND conjunct. Anchored on `case "$CEILING_KIND" in`, which is UNIQUE --
#     `CHANGE_APPROACH|RESTART_CYCLE)` alone appears TWICE in this file (validate_record's
#     F5 arm is the other), and a bare replace would silently mutate that instead and
#     come out green here.
mutate_ceiling kind \
  'case "$CEILING_KIND" in
    CHANGE_APPROACH|RESTART_CYCLE)' \
  'case "$CEILING_KIND" in
    *)' \
  "CEILING CEILING CONTINUE CONVERGED"

# (2) The COUNT conjunct: the sanctioned single resolution stops being free.
mutate_ceiling count \
  'if [ "$CEILING_COUNT" -gt "$RESOLUTION_CEILING" ] && [ "$LAST_VERDICT" != "EXIT_CONDITION_MET" ]; then' \
  'if [ "$CEILING_COUNT" -gt 0 ] && [ "$LAST_VERDICT" != "EXIT_CONDITION_MET" ]; then' \
  "CEILING CONTINUE CEILING CONVERGED"

# (3) The arm itself: no record is ever counted, so it can never fire. This is the mutant
#     that proves arm I can fire at all -- without it the three cases above are consistent
#     with an arm that is simply absent.
mutate_ceiling counter \
  '    CEILING_COUNT=$((CEILING_COUNT + 1))' \
  '    : ' \
  "CONTINUE CONTINUE CONTINUE CONVERGED"

# =============================================================================
# v0.286.0: the LIVE-SERIES DERIVATION the two hooks share (I81)
# =============================================================================
# The validator was never the problem here -- every arm above already worked. What was
# broken is the question asked BEFORE it: "which adversarial cycle is live". Both hooks
# picked the newest glob match and stripped the pass suffix afterwards, so a filename the
# strip could not match became a SERIES that was the whole filename -- which resolves as a
# ONE-PASS series. A one-pass series can never be STALLED or DIVERGENT, so the guard
# returned CONTINUE and the PreToolUse hook allowed the dispatch while a real multi-pass
# series sat stalled. Measured on the reference consumer: 6 of 135 files matching the glob
# defeat the strip.
#
# THIS ARM DRIVES THE SHIPPED EXPRESSION, not a copy of it. The derivation is extracted from
# ai-dlc-acknowledge.sh -- the hook that owns the DENY -- and eval'd. A fixture carrying its
# own copy of the expression would pass while the hook shipped something else, which is the
# defect this whole release is about.
fi
if sg hook; then
HOOK=""
for cand in \
  "$DIR/../../hooks/ai-dlc-acknowledge.sh" \
  "$DIR/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
  "$DIR/../../core/hooks/ai-dlc-acknowledge.sh"; do
  [ -f "$cand" ] && HOOK="$cand" && break
done

if [ -z "$HOOK" ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s (cannot locate ai-dlc-acknowledge.sh from %s)\n' "live-series-derivation" "$DIR"
else
  # Seed, under the artifact path grammar: the sprint is the DIRECTORY.
  #   s9/  the LIVE sprint -- a STALLED 3-pass series, plus a NEWER file that matches the
  #        glob and DEFEATS the pass-suffix strip. The decoy keeps the shape of a real
  #        reference-consumer filename (`...adversarial-pass1-...`), not an invented one.
  #   s8/  a DIFFERENT, older sprint whose files are NEWEST by mtime and whose series has
  #        CONVERGED. Nothing about the live sprint is wrong; s8 exists only so that a
  #        reader which forgets to scope by sprint has somewhere wrong to land.
  SD="$ROOT/live-series"; mkdir -p "$SD/s9" "$SD/s8"
  prov() { # <path> <hour> <major-count> <verdict>
    printf '# pass\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\nmode: subagent\nlead_role: stories-test-strategy\ninvoked_at: 2026-08-07T0%s:00:00Z\ntool_use_id: toolu_ls%s\nfindings: 0 CRITICAL, %s MAJOR, 0 MINOR\nfindings_critical: 0\nfindings_major: %s\nfindings_minor: 0\nverdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n' \
      "$2" "$2" "$3" "$3" "$4" > "$1"
  }
  # THE MAJOR COUNT IS 5, ABOVE MAJOR_EXIT_CEILING, AND IT HAS TO BE. This arm's subject is
  # WHICH SERIES the shipped derivation resolves, and it reads the answer off a STALLED
  # verdict. At or below the ceiling the plateau is a met exit condition, arm E never
  # accumulates, and every expression -- shipped and mutant alike -- reports CONTINUE. The
  # arm would then be green on all five rows while discriminating nothing, which is this
  # repo's own defect class inside the test written to catch it.
  for i in 1 2 3; do prov "$SD/s9/stories-adversarial-p$i.md" "$i" 5 EXIT_CONDITION_NOT_MET; done
  sleep 1
  cp "$SD/s9/stories-adversarial-p3.md" "$SD/s9/adversarial-pass1-discovery.md"
  sleep 1
  prov "$SD/s8/prd-adversarial-p1.md" 1 5 EXIT_CONDITION_NOT_MET
  prov "$SD/s8/prd-adversarial-p2.md" 2 0 EXIT_CONDITION_MET

  # $1 label  $2 the derivation expression  $3 expected STATE  $4 expected rc  $5 why
  # SPRINT_N is the DECLARED sprint, supplied here the way the hook supplies it from
  # `sprint-status.sh sprint-id`. An expression that ignores it is exactly the unscoped
  # regression the second mutant below drives.
  ls_expect() {
    local label="$1" expr="$2" want_state="$3" want_rc="$4" why="$5"
    local ART_DIR="$SD" SPRINT_N="9" SERIES="" out state rc
    ASSERTIONS=$((ASSERTIONS + 1))
    eval "$expr"
    if [ -z "$SERIES" ]; then
      state="(empty)"; rc="-"
    else
      out="$(bash "$VALIDATOR" --series "$SERIES" --cycle-state 2>/dev/null)"; rc=$?
      state="$(printf '%s' "$out" | cut -f1)"
    fi
    if [ "$state" = "$want_state" ] && [ "$rc" = "$want_rc" ]; then
      printf '  ok    %-28s %s rc=%s  (%s)\n' "$label" "$state" "$rc" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-28s %s rc=%s  want %s rc=%s  (%s)\n' "$label" "$state" "$rc" "$want_state" "$want_rc" "$why"
    fi
  }

  # THE WHOLE MARKED BLOCK, not one line of it. The derivation stopped being a single
  # assignment when it gained a sprint scope, and a fixture that kept extracting only the
  # `SERIES=` line would eval it with `$SPRINT_DIR` unset -- resolving nothing, every arm
  # reporting `(empty)`, and the mutants below "differing" from a shipped form that never ran.
  #
  # ONE LINE IS DROPPED: the `sprint-status.sh` shell-out. This fixture's subject is what the
  # hook does WITH a declared sprint -- the glob's scope and its filter. Resolving the sprint
  # from an envelope is `divergence-hard-block`'s subject, and it drives the real hooks
  # end-to-end to do it. Supplying SPRINT_N here is the same substitution this harness already
  # makes for ART_DIR.
  SHIPPED="$(awk '/>>> I81 LIVE-SERIES BLOCK >>>/{f=1;next} /<<< I81 LIVE-SERIES BLOCK <<</{f=0} f' "$HOOK" \
             | grep -v 'sprint-status.sh' | sed 's/^[[:space:]]*//')"
  case "$SHIPPED" in
    *adversarial*) : ;;
    *) SHIPPED="" ;;   # extracted something, but not the glob -- treat as no extraction
  esac
  if [ -z "$SHIPPED" ]; then
    FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
    printf '  FAIL  %-28s (extracted no derivation from %s -- the arm below would test nothing)\n' "live-series-derivation" "$(basename "$HOOK")"
  else
    # THE ASSERTION: the shipped expression sees past the decoy to the stalled series.
    ls_expect "live-series-shipped" "$SHIPPED" "STALLED" "3" \
      "the shipped derivation reaches the 3-pass stalled series despite a newer non-conforming file"

    # MUTANT 1 -- REVERT THE FILTER. Scoped correctly, but newest-then-strip. Without it the
    # arm above is consistent with a decoy that never mattered. CONTINUE rc=0 is exactly the
    # silent allow this whole line of work exists to remove.
    ls_expect "live-series-unfiltered" \
      'SERIES="$(ls -t "${ART_DIR}/s${SPRINT_N}"/*adversarial*p*.md 2>/dev/null | head -1 | sed -E '"'"'s/(pass|p)[0-9]+\.md$//'"'"')"' \
      "CONTINUE" "0" \
      "MUTANT: newest-then-strip resolves the decoy as a one-pass series and reports a clean cycle"

    # MUTANT 2 -- REVERT THE SCOPE. Filters correctly, but asks every sprint instead of the
    # declared one, so mtime hands it s8's CONVERGED series while s9 sits stalled. This is
    # the defect both hooks confessed to in their own comments for four releases: a clean
    # verdict read off a cycle that is not the live one.
    ls_expect "live-series-unscoped" \
      'SERIES="$(ls -t "${ART_DIR}"/s*/*adversarial*p*.md 2>/dev/null | sed -E -n '"'"'s/(pass|p)[0-9]+\.md$//p'"'"' | head -1)"' \
      "CONVERGED" "0" \
      "MUTANT: an unscoped glob adjudicates the newest sprint on disk (s8, converged), not the declared one"

    # UNMUTATED CONTROL. Remove BOTH variables -- the decoy and the other sprint -- and all
    # three forms must agree. That is what pins each difference above on its own variable
    # rather than on three expressions that disagree about everything.
    rm -f "$SD/s9/adversarial-pass1-discovery.md"; rm -rf "$SD/s8"
    ls_expect "live-series-control-shipped" "$SHIPPED" "STALLED" "3" \
      "CONTROL: one sprint, no decoy — the shipped form is correct here too"
    ls_expect "live-series-control-unfiltered" \
      'SERIES="$(ls -t "${ART_DIR}/s${SPRINT_N}"/*adversarial*p*.md 2>/dev/null | head -1 | sed -E '"'"'s/(pass|p)[0-9]+\.md$//'"'"')"' \
      "STALLED" "3" \
      "CONTROL: with no decoy the unfiltered form is correct too, so the decoy is the variable"
    ls_expect "live-series-control-unscoped" \
      'SERIES="$(ls -t "${ART_DIR}"/s*/*adversarial*p*.md 2>/dev/null | sed -E -n '"'"'s/(pass|p)[0-9]+\.md$//p'"'"' | head -1)"' \
      "STALLED" "3" \
      "CONTROL: with only one sprint on disk the unscoped form is correct too, so s8 is the variable"
  fi
fi

echo
# =============================================================================
# v0.355.0 -- H-BIND. The reader and the taught form are ONE decision in two files.
#
# The cases above prove arm H accepts the bold form and rejects a renamed field. They do
# NOT prove the form arm H accepts is the form remediator.md TEACHES -- and for nine
# releases it was not: the template wrote `- disposition:`, the reader read exactly that,
# the seed seeded exactly that, and every record the reference consumer actually wrote
# used the bold form that none of the three admitted. Three files agreeing with each other
# and disagreeing with reality is what a fixture seeded from its own reader cannot see.
#
# So this arm runs the validator's OWN repair_field on the template's OWN field lines,
# both extracted from their files at run time. It evals the definition rather than
# restating the regex: a copy here could be wrong in the fixture and right in the
# validator, and the join would report clean.
# =============================================================================
bind_fail() { FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s %s\n' "H-BIND" "$1"; }
bind_ok()   { printf '  ok    %-28s %s\n' "H-BIND" "$1"; }

# Both layouts, rooted at this fixture's own self-location (I33) -- never walked up from
# $VALIDATOR, whose parent is `core/scripts` here and `scripts/ai-dlc` on a consumer.
REMEDIATOR=""
for cand in \
  "$DIR/../../team-roles/remediator.md" \
  "$DIR/../../../.claude/team-roles/remediator.md"; do
  [ -f "$cand" ] && REMEDIATOR="$cand" && break
done
GATEDOC=""
for cand in \
  "$DIR/../../skills/ai-dlc/steps/gate-validation.md" \
  "$DIR/../../../.claude/skills/ai-dlc/steps/gate-validation.md"; do
  [ -f "$cand" ] && GATEDOC="$cand" && break
done

ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$REMEDIATOR" ] || [ -z "$GATEDOC" ]; then
  bind_fail "FIXTURE BROKEN: remediator.md=${REMEDIATOR:-<not found>} gate-validation.md=${GATEDOC:-<not found>} from $DIR"
else
  # --- extract the reader ----------------------------------------------------
  # Exactly one one-line definition, or the eval below silently binds the wrong thing.
  n_fn="$(grep -c '^repair_field() {' "$VALIDATOR")"
  fn="$(grep -m1 '^repair_field() {' "$VALIDATOR")"
  # --- extract the taught form ----------------------------------------------
  # The three field lines of remediator.md's per-finding template, as written there.
  # sed -E, not BRE: `\|` alternation is a GNU extension and matches nothing under the
  # BSD sed on macOS. The first draft used it, extracted 0 lines, and was caught by the
  # count guard below rather than by every assertion quietly passing over an empty set.
  tmpl="$(sed -E -n 's/^(- (disposition|edit|derivation):).*/\1/p' "$REMEDIATOR" | sort -u)"
  n_tmpl="$(printf '%s\n' "$tmpl" | grep -c .)"

  if [ "$n_fn" -ne 1 ] || [ "$n_tmpl" -ne 3 ]; then
    # A ZERO HERE IS NOT A FINDING. If the definition were renamed or the template
    # reworded, every assertion below would pass over an empty set and report clean.
    bind_fail "FIXTURE BROKEN: extracted $n_fn repair_field definitions (want 1) from $VALIDATOR and $n_tmpl template field lines (want 3) from $REMEDIATOR"
  else
    eval "$fn"
    BT="$ROOT/bind"; mkdir -p "$BT"
    bind_miss=""
    # Every taught line must read, as written AND with the emphasis the house style adds.
    printf '%s\n' "$tmpl" | while IFS= read -r line; do
      [ -n "$line" ] || continue
      lbl="${line#- }"; lbl="${lbl%%:*}"
      printf '%s repaired\n' "$line"                     > "$BT/plain-$lbl.md"
      printf -- '- **%s:** repaired\n' "$lbl"            > "$BT/bold-$lbl.md"
      printf -- '  _%s:_ repaired\n' "$lbl"              > "$BT/ital-$lbl.md"
      for form in plain bold ital; do
        repair_field "$lbl" "$BT/$form-$lbl.md" || printf '%s\n' "$form:$lbl" >> "$BT/misses"
      done
    done
    # CONTROL, and it is the one that matters: the eval'd reader must still REJECT. A
    # function that returned 0 unconditionally would pass every assertion above.
    printf 'The disposition was recorded and the edit made; see the derivation.\n' > "$BT/prose.md"
    printf -- '- **edit sites:** a.md:4\n- derivation (why): x\n### Derivation 1 — y\n' > "$BT/offlabel.md"
    for lbl in disposition edit derivation; do
      repair_field "$lbl" "$BT/prose.md"    && printf '%s\n' "control-prose:$lbl"    >> "$BT/misses"
      repair_field "$lbl" "$BT/nonexistent" 2>/dev/null && printf '%s\n' "control-absent:$lbl" >> "$BT/misses"
    done
    repair_field edit       "$BT/offlabel.md" && printf 'control-offlabel:edit\n'       >> "$BT/misses"
    repair_field derivation "$BT/offlabel.md" && printf 'control-offlabel:derivation\n' >> "$BT/misses"
    bind_miss="$(cat "$BT/misses" 2>/dev/null | tr '\n' ' ')"
    if [ -n "$bind_miss" ]; then
      bind_fail "the reader in $VALIDATOR and the template in $REMEDIATOR disagree: $bind_miss"
    else
      bind_ok "reader accepts all 3 taught labels plain/bold/italic and rejects prose + renamed fields"
    fi
  fi

  # --- the third statement of the same three labels --------------------------
  # gate-validation.md teaches arm H to the lead. It is prose, so this is a token join,
  # not a grammar one -- but a label dropped from it is a label nobody is taught.
  ASSERTIONS=$((ASSERTIONS + 1))
  gv_miss=""
  for lbl in disposition edit derivation; do
    grep -qF "\`$lbl:\`" "$GATEDOC" || gv_miss="$gv_miss $lbl"
  done
  gv_ctl="$(grep -c 'REPAIR-RECORD\|arm H' "$GATEDOC")"
  if [ "$gv_ctl" -eq 0 ]; then
    bind_fail "FIXTURE BROKEN: $GATEDOC names no arm H at all, so the label check below reads a file that moved"
  elif [ -n "$gv_miss" ]; then
    bind_fail "$GATEDOC teaches arm H but no longer names:$gv_miss (control: $gv_ctl arm-H mentions in the same file)"
  else
    bind_ok "gate-validation.md names all 3 labels the reader reads"
  fi
fi

# --- the MAJOR split: findings_major_underived --------------------------------
# UNPROVEN used to block the exit exactly as hard as WRONG, because the exit condition reads
# findings_major and adversary.md grades an underived claim a MAJOR "whether or not you can
# yet falsify it". These five are a partition of the ways the split can be got wrong, and the
# last one is the migration proof.
expect underived-exits               0 "0C, 7M ALL underived: 0 blocking -- MET is honest" s1-adversarial-p
expect underived-partial-blocks      1 "0C, 7M with 2 underived: FIVE blocking MAJORs, above the ceiling -- MET is a false convergence (B)" s1-adversarial-p
expect underived-exceeds             1 "8 underived of 7 MAJOR: the partition cannot exceed the whole (B)" s1-adversarial-p
expect underived-refuses             1 "0 blocking and still NOT_MET -- the residue IS the exit condition (B)" s1-adversarial-p
expect underived-absent-still-blocks 1 "MIGRATION: same residue, NO field -- absent means ZERO, so 7 blocking still blocks" s1-adversarial-p

# The exit codes above are necessary and not sufficient: three of those four failures are arm
# B, so a message naming the wrong quantity would score identically.
expect_says underived-partial-blocks s1-adversarial-p "B-blocking-count" \
  "5 blocking MAJOR" "7 MAJOR less 2 underived"
expect_says underived-exceeds s1-adversarial-p "B-partition" \
  "findings_major_underived=8" "7 MAJOR"

# --- THE EXIT CEILING: 0 CRITICAL and at most 3 BLOCKING MAJOR ------------------
# The criteria are declared once, at CRITICAL_EXIT_CEILING / MAJOR_EXIT_CEILING in the
# validator, and read by arm B in both directions and by arm E's accumulator. These assert
# the VALUE, not merely that some ceiling exists: at the limit must PASS and one above it
# must FAIL, in the same block, or a validator that dropped arm B's MAJOR half entirely
# would score identically on the first of them.
expect ceiling-at-limit        0 "0C / exactly 3 blocking MAJOR stamped MET -- AT the criteria, converged" s1-adversarial-p
expect ceiling-above-limit     1 "0C / 4 blocking MAJOR stamped MET -- ONE above the ceiling, false convergence (B)" s1-adversarial-p
expect ceiling-midcycle-below  0 "0C / 2 blocking MAJOR stamped NOT_MET mid-cycle -- declining an open exit is legal" s1-adversarial-p

expect_says ceiling-above-limit s1-adversarial-p "B-ceiling-exceeded" \
  "B -- CONSISTENCY" "4 blocking MAJOR" "at most 3"

# THE NOT_MET HALF STILL FIRES AT A FULLY CLEAN RESIDUE, and `refused-to-converge` above is
# its true positive. Asserted here by MESSAGE so that relaxing the ceiling cannot be mistaken
# for deleting the arm: an implementation that dropped the NOT_MET half entirely passes every
# exit-code assertion in this block and fails this one.
expect_says refused-to-converge s1-adversarial-pass "B-notmet-at-clean" \
  "B -- CONSISTENCY" "0 CRITICAL and 0 blocking MAJOR" "stamps"

# TWO ARMS MUST BE SILENT ON A PLATEAU BELOW THE CEILING, and the exit code cannot say so --
# arms C and D fire on the p5 divergence either way. Each negative carries its own positive
# control in the same invocation shape, because an absence is not a finding.
# Arm D, not arm C: p5 DECLARES DIVERGENT_HARD_BLOCK, so C is satisfied and D owns the
# unresolved terminal. Naming the wrong arm here is how a silence assertion below could pass
# against a run that failed for a third reason entirely.
expect_says ceiling-plateau-below s1-adversarial-p "D-owns-plateau-series" \
  "D -- TERMINAL" "DIVERGENT_HARD_BLOCK"
expect_state ceiling-plateau-below s1-adversarial-p DIVERGENT 3 \
  "the hooks must deny on the divergence that ended the plateau"

# expect_silent is defined once in the shared prelude above (units in more than one shard call it).

expect_silent ceiling-plateau-below "E -- STALL" stalled \
  "E and B's MET half are reading two different ceilings"
expect_silent ceiling-plateau-below "B -- CONSISTENCY" ceiling-above-limit \
  "the biconditional is back and every consumer's mid-cycle NOT_MET is retroactively an error"

# --- ARM K: the shard arm reads the TERMINAL pass --------------------------------------------
# Each case is a stamped git repo built by seed.sh. The recovery cell is the one that separates
# terminal keying from every-pass keying: under the latter it exits 1 on p1 forever, which is
# a remedy the arm prints and the gate cannot accept. The offender cell asserts the MESSAGE,
# because arm K's exit is shared with every other arm.
expect shard-recovered 0 \
  "unsharded p1, then the sharded MET p2 the remedy prescribes: the series CLEARS" stories-adversarial-p
expect shard-recovered-call 0 \
  "the same recovery with every shard id in a local-model lead's call_ shape: the series CLEARS (BL-597)" stories-adversarial-p
expect shard-recovered-xyz 1 \
  "the same recovery with ids in no declared shape -- FAIL (K), the control the call_ cell is read against" stories-adversarial-p
expect_says shard-recovered-xyz stories-adversarial-p "K-xyz-names-terminal" \
  "FAIL (K -- SHARD): stories-adversarial-p2.md reviews"
expect shard-terminal-unsharded 1 \
  "sharded p1, whole-subject TERMINAL p2 after the stamp -- FAIL (K)" stories-adversarial-p
expect_says shard-terminal-unsharded stories-adversarial-p "K-names-terminal" \
  "FAIL (K -- SHARD): stories-adversarial-p2.md reviews" "write it as the NEXT" \
  "This arm reads only"
expect_state shard-terminal-unsharded stories-adversarial-p CONVERGED 0 \
  "arm K is GATE-ONLY: the hooks' state is untouched by a missing shard line"
expect shard-legacy 0 \
  "the series opened before the stamp: PENDING, printed and not counted" stories-adversarial-p
expect_says shard-legacy stories-adversarial-p "K-legacy-pending" \
  "PENDING (K -- SHARD): the terminal pass stories-adversarial-p2.md" "Legacy series."

fi
if sg k2; then
echo
# --- ARM K2: one shardable DOCUMENT, reviewed whole -----------------------------------------
# K2 asks partition-document.sh, a SIBLING of the validator, whether the document partitions.
# That program is owned by another change and may be absent from a tree this fixture runs in;
# a K2 cell scored against a validator with no partitioner reads PENDING everywhere and the
# FAIL cell alone would say so -- but the SERIAL and sharded cells would pass for the wrong
# reason. So its absence is refused HERE, loudly, before any K2 cell is read.
# K2_PD and its presence check are in the shared prelude above (the k2 and k3 units both read it).
K2_POST_MSG="FAIL (K2 -- SECTIONS): prd-adversarial-p1.md reviews"
expect k2-shardable-post 1 \
  "a whole-document pass over a 4-part document, series opened after the 0.665.0 stamp -- FAIL (K2)" prd-adversarial-p
expect_says k2-shardable-post prd-adversarial-p "K2-names-document" \
  "$K2_POST_MSG" "splits into" "4 parts" "merge-adversarial-shards.sh --document"
expect_state k2-shardable-post prd-adversarial-p CONVERGED 0 \
  "arm K2 is GATE-ONLY: the hooks' state is untouched by a missing shard line"
expect k2-shardable-pre 0 \
  "the same bytes, series opened before the stamp: PENDING, printed and not counted" prd-adversarial-p
expect_says k2-shardable-pre prd-adversarial-p "K2-legacy-pending" \
  "PENDING (K2 -- SECTIONS): the terminal pass prd-adversarial-p1.md" "Legacy series."
expect k2-serial 0 "one ## section: the map says SERIAL, Rule 28 exception 4 -- one adversary is correct" prd-adversarial-p
expect k2-sharded 0 "the offender with the merge's shard_tool_use_ids: line -- sectioned, passes" prd-adversarial-p
expect k2-sha-moved 0 "the document moved after the pass notarized it: PENDING, never judged on unreviewed bytes" prd-adversarial-p
expect_says k2-sha-moved prd-adversarial-p "K2-sha-moved-pending" \
  "PENDING (K2 -- SECTIONS)" "is not the bytes it notarized"

# THE SILENT CELLS, each against the offender as the control that K2 fires at all.
k2_silent() {  # $1 case  $2 why
  local out ctl
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$ROOT/$1/prd-adversarial-p" 2>&1)"
  ctl="$(bash "$VALIDATOR" --series "$ROOT/k2-shardable-post/prd-adversarial-p" 2>&1)"
  if grep -qF -- "K2 -- SECTIONS" <<<"$out"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s K2 spoke where it must be SILENT -- %s\n' "$1" "$2"
  elif ! grep -qF -- "$K2_POST_MSG" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s CONTROL: k2-shardable-post did not FAIL (K2) -- the silence is vacuous\n' "$1"
  else
    printf '  ok    %-28s K2 silent here, FAILs k2-shardable-post (control)\n' "$1"
  fi
}
k2_silent k2-serial  "a SERIAL document is a correct whole-subject review, not a deferral"
k2_silent k2-sharded "a merged pass carries shard_tool_use_ids: and is the dispatch K2 asks for"

# THE PROGRAM ABSENT. A consumer may carry this validator before it carries the partitioner;
# that must read PENDING, naming the program, never FAIL. The copy carries every OTHER sibling
# the validator resolves, so the only thing it lacks is the program under test.
K2_NOPROG="$ROOT/k2-noprog"; mkdir -p "$K2_NOPROG"
cp "$VALIDATOR" "$K2_NOPROG/validate-adversarial-convergence.sh"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$K2_NOPROG/validate-steering-budget.sh"
ASSERTIONS=$((ASSERTIONS + 1))
k2np_out="$(bash "$K2_NOPROG/validate-adversarial-convergence.sh" --series "$ROOT/k2-shardable-post/prd-adversarial-p" 2>&1)"
k2np_rc=$?
if [ -e "$K2_NOPROG/partition-document.sh" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s the copy carries partition-document.sh -- this cell cannot see its absence\n' "k2-program-absent"
elif [ "$k2np_rc" -eq 0 ] && grep -qF -- "is not installed beside this validator" <<<"$k2np_out" \
     && ! grep -qF -- "FAIL (K2" <<<"$k2np_out"; then
  printf '  ok    %-28s %s\n' "k2-program-absent" "the offender reads PENDING naming the missing program, exit 0"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s exit=%s -- an absent partitioner must be PENDING, never FAIL\n' "k2-program-absent" "$k2np_rc"
  printf '%s\n' "$k2np_out" | sed 's/^/          | /'
fi

# --- MUTATION: the three gates that keep K2 off in-flight and legacy work -------------------
# Each gate removed moves exactly ONE cell of five, and a different cell:
#
#                          post   pre      serial   sharded  sha-moved
#   shipped                FAIL   PENDING  SILENT   SILENT   PENDING
#   stamp gate removed     FAIL   FAIL     SILENT   SILENT   PENDING
#   SERIAL check removed   FAIL   PENDING  FAIL     SILENT   PENDING
#   sha gate removed       FAIL   PENDING  SILENT   SILENT   FAIL
#
# Built in a copy of the validator's directory carrying its siblings, with an unmutated control
# from the same directory, so a copy that cannot resolve its partitioner reads as broken.
K2_CASES="k2-shardable-post k2-shardable-pre k2-serial k2-sharded k2-sha-moved"
K2_REAL="FAIL PENDING SILENT SILENT PENDING"
K2_MUT="$ROOT/k2-mutants"; mkdir -p "$K2_MUT"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$K2_MUT/validate-steering-budget.sh"
cp "$K2_PD" "$K2_MUT/partition-document.sh"

k2_cell() {  # $1 script  $2 case -> FAIL | PENDING | SILENT
  local out
  out="$(bash "$1" --series "$ROOT/$2/prd-adversarial-p" 2>&1)"
  case "$out" in
    *"FAIL (K2 -- SECTIONS)"*)    printf 'FAIL\n' ;;
    *"PENDING (K2 -- SECTIONS)"*) printf 'PENDING\n' ;;
    *)                            printf 'SILENT\n' ;;
  esac
}
k2_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  local i=0 wm; rsel "$3" "$K2_REAL"; wm="$(rmask "$3")"
  for c in $K2_CASES; do i=$((i + 1)); if ron "$i"; then got="$got $(k2_cell "$2" "$c")"; else got="$got ."; fi; done
  RSEL=""
  if [ "$(echo $got)" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
cp "$VALIDATOR" "$K2_MUT/control.sh"
k2_score "CONTROL k2 copy" "$K2_MUT/control.sh" "$K2_REAL"

k2_mutate() {  # $1 label  $2 anchor line (must be unique)  $3 replacement  $4 expected row
  local mut="$K2_MUT/mutant-$1.sh" n ctl
  n="$(grep -cxF -- "$2" "$VALIDATOR")" || n=0
  ctl="$(grep -cxF -- "$2 # no-such-line" "$VALIDATOR")" || ctl=0
  if [ "$n" -ne 1 ] || [ "$ctl" -ne 0 ]; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0)\n' "MUTATION $1" "$n" "$ctl"
    return
  fi
  MUT_OLD="$2" MUT_NEW="$3" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation DID NOT APPLY -- this assertion proves nothing\n' "MUTATION $1"
    return
  fi
  if ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $1"
    return
  fi
  k2_score "MUTATION $1" "$mut" "$4"
}
k2_mutate k2-stamp-gate \
  '  elif [[ "$k2_at" < "$k2_stamp" ]]; then' \
  '  elif false; then' \
  "FAIL FAIL SILENT SILENT PENDING"
k2_mutate k2-serial-check \
  '          if [ "$k2rc" -eq 0 ]; then' \
  '          if [ "$k2rc" -eq 0 ] || [ "$k2rc" -eq 3 ]; then' \
  "FAIL PENDING FAIL SILENT PENDING"
k2_mutate k2-sha-gate \
  '      elif [ "$k2h_lc" != "$k2_disk" ]; then' \
  '      elif false; then' \
  "FAIL PENDING SILENT SILENT FAIL"

# --- ARM K2 asks the partitioner IN FORCE AT THE PASS, not today's --------------------------
# Every world above holds the validator OUTSIDE the world (the distribution layout), so each of
# them is judged by today's copy and must SAY so -- beside a SILENT verdict as much as a FAIL.
expect_says k2-shardable-post prd-adversarial-p "K2-fallback-marked-fail" \
  "FALLBACK (K2 partitioner): prd-adversarial-p1.md is judged by the CURRENT" "the distribution layout"
expect_says k2-serial prd-adversarial-p "K2-fallback-marked-silent" \
  "FALLBACK (K2 partitioner): prd-adversarial-p1.md is judged by the CURRENT" "the distribution layout"
#
# The HISTORY worlds hold the validator INSIDE a stamped git root, beside a partitioner the root
# TRACKS, and commit two copies of it: the shipped one and a stub that maps a two-section probe
# (so it passes K2's map probe) and calls anything larger SERIAL. The stub is self-contained on
# purpose -- a copy derived by editing the shipped partitioner breaks whenever those lines move.
# The document has four sections: the shipped copy maps it (FAIL), the stub calls it SERIAL.
#
#   world          layout          10:00         12:00       pass(es)       in force   today
#   old-serial     scripts/ai-dlc  stub+stamp    shipped     11:00          stub       shipped
#   old-splits     core/scripts    shipped+stamp stub        11:00          shipped    stub
#   terminal       scripts/ai-dlc  stub+stamp    shipped     11:00, 13:00   shipped    shipped
#   untracked      scripts/ai-dlc  stamp only    --          11:00          (none)     shipped
#
# old-serial and old-splits are the two DISAGREEMENT DIRECTIONS (an update, and a downgrade): a
# today's-map read inverts both. terminal pins the TIME KEY: its first pass predates the shipped
# copy and its terminal pass follows it, so keying on the first pass reads the stub. untracked
# cannot resolve a copy and must fall back to today's AND say so.
K2H="$ROOT/k2-hist"; mkdir -p "$K2H"
k2h_commit() {  # $1 world  $2 iso time  $3 message -- every tracked change in the world
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    cd "$1" || exit 1
    git add -A . >/dev/null || exit 1
    GIT_COMMITTER_DATE="$2" GIT_AUTHOR_DATE="$2" \
      git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
          -c core.hooksPath=/dev/null commit -q -m "$3" >/dev/null )
}
k2h_stub() {  # $1 path -- a partitioner that maps exactly two `## ` sections, SERIAL otherwise
  printf '%s\n' '#!/usr/bin/env bash' \
    '[ "${1:-}" = --map ] || exit 2' \
    'n="$(grep -c "^## " "$2")" || n=0' \
    'if [ "$n" -eq 2 ]; then printf "1\t1\t2\t## a\n2\t3\t4\t## b\n"; exit 0; fi' \
    'echo "SERIAL: stub partitioner"; exit 3' > "$1"
}
k2h_pass() {  # $1 file  $2 n  $3 major  $4 verdict  $5 invoked_at  $6 artifact_sha
  {
    printf '# prd -- adversarial pass %s\n\n' "$2"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'invoked_at: %s\n' "$5"
    printf 'tool_use_id: toolu_fixture_k2h%s\n' "$2"
    printf 'mode: subagent\n'
    printf 'lead_role: pm\n'
    printf 'artifact: prd.md\n'
    printf 'artifact_sha: %s\n' "$6"
    printf 'findings_critical: 0\n'
    printf 'findings_critical_prior_scope: 0\n'
    printf 'findings_major: %s\n' "$3"
    printf 'findings_major_underived: 0\n'
    printf 'findings_minor: 0\n'
    printf 'verdict: %s\n' "$4"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$1"
}
k2h_world() {  # $1 world  $2 layout dir  $3 copy at 10:00 (stub|shipped|none)  $4 copy at 12:00 (stub|shipped|none)
  local w="$K2H/$1" l="$K2H/$1/$2" c
  mkdir -p "$w/.claude" "$l" || return 1
  printf 'version: 0.665.0\n' > "$w/.claude/.ai-dlc-version"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; cd "$w" && git init -q . >/dev/null ) || return 1
  for c in "$3:2026-09-29T10:00:00Z" "$4:2026-09-29T12:00:00Z"; do
    case "${c%%:*}" in
      stub)    k2h_stub "$l/partition-document.sh" ;;
      shipped) cp "$K2_PD" "$l/partition-document.sh" ;;
      none)    [ "${c#*:}" = 2026-09-29T10:00:00Z ] || continue ;;
    esac
    k2h_commit "$w" "${c#*:}" "at ${c#*:}" || return 1
  done
  # Untracked from here on: the validator, its steering sibling, the document and the passes.
  # The untracked world's partitioner is today's copy and is never committed.
  [ "$3" = none ] && cp "$K2_PD" "$l/partition-document.sh"
  cp "$VALIDATOR" "$l/validate-adversarial-convergence.sh"
  cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$l/validate-steering-budget.sh"
  printf '# PRD\n\n## One\n\nalpha alpha\n\n## Two\n\nbravo bravo\n\n## Three\n\ncharlie charlie\n\n## Four\n\ndelta delta\n' > "$w/prd.md"
  K2H_SHA="$(shasum -a 256 "$w/prd.md" 2>/dev/null | cut -d' ' -f1)"
  [ -n "$K2H_SHA" ] || K2H_SHA="$(sha256sum "$w/prd.md" | cut -d' ' -f1)"
  printf '%s\n' "$2" > "$w/.layout"
}
K2H_OK=1
k2h_world old-serial scripts/ai-dlc stub shipped || K2H_OK=0
k2h_pass "$K2H/old-serial/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
k2h_world old-splits core/scripts shipped stub || K2H_OK=0
k2h_pass "$K2H/old-splits/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
k2h_world terminal scripts/ai-dlc stub shipped || K2H_OK=0
k2h_pass "$K2H/terminal/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
k2h_pass "$K2H/terminal/prd-adversarial-p2.md" 2 0 EXIT_CONDITION_MET 2026-09-29T13:00:00Z "$K2H_SHA"
k2h_world untracked scripts/ai-dlc none none || K2H_OK=0
k2h_pass "$K2H/untracked/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"

# THE MERGE WORLDS. Main installs the stub at 10:00; a sprint branch installs the shipped copy at
# 10:30, writes the pass (dispatched 11:00) and commits it at 11:05; main then takes the sprint at
# 12:00 by a SQUASH or by a TRUE merge (--no-ff). On main's first-parent chain the shipped copy is
# dated 12:00, after the pass, so the time key alone reads the stub -- SERIAL, an acquittal of a
# dispatch made under the copy that maps the document. The commit that ADDED the pass file
# carries the shipped copy, so the two disagree and K2 must be PENDING, never silent.
k2h_merge_world() {  # $1 world  $2 squash|true
  local w="$K2H/$1" l="$K2H/$1/scripts/ai-dlc" main
  mkdir -p "$w/.claude" "$l" || return 1
  printf 'version: 0.665.0\n' > "$w/.claude/.ai-dlc-version"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; cd "$w" && git init -q . >/dev/null ) || return 1
  printf '# PRD\n\n## One\n\nalpha alpha\n\n## Two\n\nbravo bravo\n\n## Three\n\ncharlie charlie\n\n## Four\n\ndelta delta\n' > "$w/prd.md"
  k2h_stub "$l/partition-document.sh"
  k2h_commit "$w" 2026-09-29T10:00:00Z "install stub" || return 1
  main="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git -C "$w" symbolic-ref --short HEAD ) )"
  [ -n "$main" ] || return 1
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git -C "$w" checkout -q -b sprint ) || return 1
  cp "$K2_PD" "$l/partition-document.sh"
  k2h_commit "$w" 2026-09-29T10:30:00Z "self-update on sprint" || return 1
  K2H_SHA="$(shasum -a 256 "$w/prd.md" 2>/dev/null | cut -d' ' -f1)"
  [ -n "$K2H_SHA" ] || K2H_SHA="$(sha256sum "$w/prd.md" | cut -d' ' -f1)"
  k2h_pass "$w/prd-adversarial-p1.md" 1 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$K2H_SHA"
  k2h_commit "$w" 2026-09-29T11:05:00Z "pass p1" || return 1
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    cd "$w" || exit 1
    git checkout -q "$main" || exit 1
    if [ "$2" = squash ]; then
      git merge -q --squash sprint >/dev/null 2>&1 || exit 1
      GIT_COMMITTER_DATE=2026-09-29T12:00:00Z GIT_AUTHOR_DATE=2026-09-29T12:00:00Z \
        git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
            -c core.hooksPath=/dev/null commit -q -m "squash sprint" >/dev/null || exit 1
    else
      GIT_COMMITTER_DATE=2026-09-29T12:00:00Z GIT_AUTHOR_DATE=2026-09-29T12:00:00Z \
        git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
            -c core.hooksPath=/dev/null merge -q --no-ff -m "merge sprint" sprint >/dev/null 2>&1 || exit 1
    fi ) || return 1
  cp "$VALIDATOR" "$l/validate-adversarial-convergence.sh"
  cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$l/validate-steering-budget.sh"
  printf 'scripts/ai-dlc\n' > "$w/.layout"
}
k2h_merge_world merge-squash squash || K2H_OK=0
k2h_merge_world merge-true true || K2H_OK=0

# THE WORLDS ARE WHAT THEY CLAIM, or every cell below scores a world nobody built: the two
# directions really do disagree (today's copy on disk answers the opposite of the copy at 10:00),
# and the untracked world tracks no partitioner.
k2h_rc() { bash "$1" --map "$2" >/dev/null 2>&1; echo $?; }
ASSERTIONS=$((ASSERTIONS + 1))
K2H_TMP="$K2H/.probe"; mkdir -p "$K2H_TMP"
k2h_blob() { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
  git -C "$K2H/$1" cat-file blob "$(git -C "$K2H/$1" rev-list -1 --before=2026-09-29T11:00:00Z HEAD):./$(cat "$K2H/$1/.layout")/partition-document.sh" ) > "$K2H_TMP/$1.sh" 2>/dev/null; }
k2h_blob old-serial; k2h_blob old-splits
k2h_disk() { echo "$K2H/$1/$(cat "$K2H/$1/.layout")/partition-document.sh"; }
k2h_shape="$(k2h_rc "$K2H_TMP/old-serial.sh" "$K2H/old-serial/prd.md")$(k2h_rc "$(k2h_disk old-serial)" "$K2H/old-serial/prd.md")"
k2h_shape="$k2h_shape $(k2h_rc "$K2H_TMP/old-splits.sh" "$K2H/old-splits/prd.md")$(k2h_rc "$(k2h_disk old-splits)" "$K2H/old-splits/prd.md")"
k2h_untr="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git -C "$K2H/untracked" ls-files -- scripts/ai-dlc ) | grep -c .)" || k2h_untr=0
# The merge worlds: the first-parent copy at the pass's time must be the stub (rc 3) and the copy
# at the commit that added the pass the shipped one (rc 0), or the world cannot express the defect.
k2h_mshape=""
for k2h_mw in merge-squash merge-true; do
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    git -C "$K2H/$k2h_mw" cat-file blob "$(git -C "$K2H/$k2h_mw" rev-list -1 --first-parent --before=2026-09-29T11:00:00Z HEAD):./scripts/ai-dlc/partition-document.sh"
  ) > "$K2H_TMP/$k2h_mw-time.sh" 2>/dev/null
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    git -C "$K2H/$k2h_mw" cat-file blob "$(git -C "$K2H/$k2h_mw" log --diff-filter=A --format=%H HEAD -- prd-adversarial-p1.md | tail -1):./scripts/ai-dlc/partition-document.sh"
  ) > "$K2H_TMP/$k2h_mw-add.sh" 2>/dev/null
  k2h_mshape="$k2h_mshape$(k2h_rc "$K2H_TMP/$k2h_mw-time.sh" "$K2H/$k2h_mw/prd.md")$(k2h_rc "$K2H_TMP/$k2h_mw-add.sh" "$K2H/$k2h_mw/prd.md") "
done
k2h_mshape="$(echo $k2h_mshape)"
if [ "$K2H_OK" -ne 1 ] || [ "$k2h_shape" != "30 03" ] || [ "$k2h_untr" -ne 0 ] || [ "$k2h_mshape" != "30 30" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN: built=%s, in-force/today rc per direction [%s] want [30 03], untracked tracks %s file(s), merge time/added rc [%s] want [30 30]\n' \
    "k2-history-worlds" "$K2H_OK" "$k2h_shape" "$k2h_untr" "$k2h_mshape"
else
  printf '  ok    %-28s both directions disagree [%s]; untracked tracks nothing; merges: time vs added [%s]\n' "k2-history-worlds" "$k2h_shape" "$k2h_mshape"
fi

# One cell per world: the K2 verdict, suffixed `/FB` when the FALLBACK line printed. Driven by
# a script copied INTO the world's layout dir, because the copy in force is resolved from where
# the validator sits.
K2H_WORLDS="old-serial old-splits terminal untracked merge-squash merge-true"
K2H_REAL="SILENT FAIL FAIL FAIL/FB PENDING PENDING"
k2h_cell() {  # $1 script basename  $2 world
  local out v
  out="$(bash "$K2H/$2/$(cat "$K2H/$2/.layout")/$1" --series "$K2H/$2/prd-adversarial-p" 2>&1)"
  case "$out" in
    *"FAIL (K2 -- SECTIONS)"*)    v=FAIL ;;
    *"PENDING (K2 -- SECTIONS)"*) v=PENDING ;;
    *)                            v=SILENT ;;
  esac
  case "$out" in *"FALLBACK (K2 partitioner)"*) v="$v/FB" ;; esac
  printf '%s\n' "$v"
}
k2h_score() {  # $1 label  $2 script basename  $3 expected row
  local got="" w
  ASSERTIONS=$((ASSERTIONS + 1))
  local i=0 wm; rsel "$3" "$K2H_REAL"; wm="$(rmask "$3")"
  for w in $K2H_WORLDS; do i=$((i + 1)); if ron "$i"; then got="$got $(k2h_cell "$2" "$w")"; else got="$got ."; fi; done
  RSEL=""
  if [ "$(echo $got)" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
k2h_score "K2 in-force copy" validate-adversarial-convergence.sh "$K2H_REAL"
expect_says_k2h() {  # $1 world  $2 label  $3... required substrings
  local w="$1" label="$2" out missing="" want; shift 2
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$K2H/$w/$(cat "$K2H/$w/.layout")/validate-adversarial-convergence.sh" --series "$K2H/$w/prd-adversarial-p" 2>&1)"
  for want in "$@"; do grep -qF -- "$want" <<<"$out" || missing="$missing \"$want\""; done
  if [ -z "$missing" ]; then printf '  ok    %-28s %s\n' "$label" "says what it must"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s missing:%s\n' "$label" "$missing"; fi
}
expect_says_k2h old-splits "K2h-names-copy-in-force" \
  "asked of the copy of core/scripts/partition-document.sh in force at"
expect_says_k2h untracked "K2h-untracked-reason" \
  "FALLBACK (K2 partitioner):" "scripts/ai-dlc/partition-document.sh is not tracked at"
expect_says_k2h merge-squash "K2h-squash-ambiguous" \
  "PENDING (K2 -- SECTIONS): in-force partitioner ambiguous ("
expect_says_k2h merge-true "K2h-merge-ambiguous" \
  "PENDING (K2 -- SECTIONS): in-force partitioner ambiguous ("

# MUTANTS, each built from the validator under test and dropped into every history world beside
# the real copy. Each moves only the cells its own clause owns; the revert takes out the WHOLE
# layer (resolution and marker), so a revert leaving the marker in place cannot pass as one.
k2h_mutate() {  # $1 label  $2 anchor (unique)  $3 replacement  $4 expected row
  local mut="$K2H/.mut-$1.sh" n ctl w
  n="$(grep -cF -- "$2" "$VALIDATOR")" || n=0
  ctl="$(grep -cF -- "$2 # no-such-line" "$VALIDATOR")" || ctl=0
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$n" -ne 1 ] || [ "$ctl" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0)\n' "MUTATION $1" "$n" "$ctl"
    return
  fi
  MUT_OLD="$2" MUT_NEW="$3" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation DID NOT APPLY or does not parse -- this assertion proves nothing\n' "MUTATION $1"
    return
  fi
  ASSERTIONS=$((ASSERTIONS - 1))
  for w in $K2H_WORLDS; do cp "$mut" "$K2H/$w/$(cat "$K2H/$w/.layout")/mutant-$1.sh"; done
  k2h_score "MUTATION $1" "mutant-$1.sh" "$4"
}
k2h_mutate k2-current-map-revert \
  '        k2_pd_in_force "$k2_root" "${P_AT[$((N - 1))]:-}" "$LAST_FILE"' \
  '        K2_RUN="$K2_PD"; K2_PD_FROM="the CURRENT ${K2_PD}"; K2_PD_FALLBACK=""; K2_PD_AMBIG=""' \
  "FAIL SILENT FAIL FAIL FAIL FAIL"
k2h_mutate k2-fallback-unmarked \
  '        if [ -n "$K2_PD_FALLBACK" ]; then' \
  '        if false; then' \
  "SILENT FAIL FAIL FAIL PENDING PENDING"
k2h_mutate k2-first-pass-time \
  '        k2_pd_in_force "$k2_root" "${P_AT[$((N - 1))]:-}" "$LAST_FILE"' \
  '        k2_pd_in_force "$k2_root" "${P_AT[0]:-}" "$LAST_FILE"' \
  "SILENT FAIL SILENT FAIL/FB PENDING PENDING"
# The added-commit cross-check dropped: ONLY the two merge worlds move, both to the acquittal.
k2h_mutate k2-added-commit-dropped \
  '  cmp -s "$AC_T/k2-pd-in-force.sh" "$AC_T/k2-pd-at-add.sh" || K2_PD_AMBIG="${c:0:12} vs ${a:0:12}"' \
  '  :' \
  "SILENT FAIL FAIL FAIL/FB SILENT SILENT"

fi
if sg pass1; then
echo
# --- PASS 1 HAS NO PREVIOUS PASS -----------------------------------------------
# THE SEED GAP THESE CLOSE. Every case above declares pass 1 with prior == crit, and that
# is the ONE shape that cannot exercise the pass-1 branch of arm D's SCOPE_GREW counter.
# The reference consumer's dominant pass-1 shape is the other one -- an honest
# `findings_critical_prior_scope: 0`, because there is no previous pass. seed.sh carries
# the census and the three cases.
#
# THE EXIT CODE CANNOT BE THE ASSERTION on the first case: it exits 1 with the MOVING
# ARTIFACT remedy before the guard and exits 1 with the generic remedy after it. Only the
# MESSAGE separates a validator that excludes pass 1 from one that counts it.
expect pass1-honest-zero-unconverged 1 \
  "p1 1C at prior 0, p2 clears it, exit still short on 2 blocking MAJOR -- D fires" s1-adversarial-p
expect_says pass1-honest-zero-unconverged s1-adversarial-p "D-generic-at-pass1" \
  "$D_GENERIC"
expect_silent pass1-honest-zero-unconverged "MOVING ARTIFACT" pass1-honest-zero-then-growth \
  "an honest prior_scope 0 at pass 1 reads as scope the sprint ADDED, and every series whose FIRST pass found a CRITICAL is then told to freeze"
expect_silent pass1-honest-zero-unconverged "CUT the added scope" pass1-honest-zero-then-growth \
  "the remedy names an action this series cannot take: there is no added scope to cut"

# THE NEAR-MISS CONTROL. Byte-identical pass 1; pass 2 converges. Green on both sides of
# the guard -- a terminal EXIT_CONDITION_MET takes arm D's first branch and never reads
# SCOPE_GREW -- so it pins that the guard bought nothing by suppressing a terminal verdict.
expect pass1-honest-zero-converges 0 \
  "NEAR-MISS CONTROL: same p1, p2 converges -- a terminal MET never reads SCOPE_GREW" s1-adversarial-p

# THE OVER-FIRE CONTROL. Growth at a pass that HAS a predecessor is the arm's real subject
# and must be untouched. `scope-grew-unconverged` above is the same claim on a longer series.
expect pass1-honest-zero-then-growth 1 \
  "OVER-FIRE CONTROL: p2 finds 3C against 1 in prior scope -- genuine growth" s1-adversarial-p
expect_says pass1-honest-zero-then-growth s1-adversarial-p "D-moving-at-pass2" \
  "MOVING ARTIFACT" "CUT the added scope"

# GROWTH AT prior == 0 AFTER PASS 1 -- the case that separates "no previous pass exists"
# from "prior is zero". Every case above puts its pass-2 growth at prior > 0, so a guard
# keyed on `[ "$prior" -gt 0 ]` passes all of them and is WRONG: it also drops the purest
# moving-artifact signal there is, a pass none of whose CRITICALs sit in reviewed text.
expect scope-grew-at-zero-prior 1 \
  "p1 declares prior == crit, p2 finds 3C with NONE in prior scope -- the sprint added all of them" s1-adversarial-p
expect_says scope-grew-at-zero-prior s1-adversarial-p "D-moving-at-zero-prior" \
  "MOVING ARTIFACT" "CUT the added scope"

# A SERIES WHOSE FIRST FILE IS NOT PASS 1 -- the case that separates "has no predecessor"
# from "is numbered 1". p2 is the first file on disk; its honest prior 0 is not growth.
expect series-starts-at-pass2 1 \
  "the series starts at p2 -- its first file has no predecessor either, and p3 clears the CRITICAL" s1-adversarial-p
expect_says series-starts-at-pass2 s1-adversarial-p "D-generic-at-first-file" \
  "$D_GENERIC"
expect_silent series-starts-at-pass2 "MOVING ARTIFACT" scope-grew-at-zero-prior \
  "a guard reading the pass NUMBER counts the first file of every series that starts above 1, and five of the consumer's 84 do"

# --- MUTATION: the pass-1 guard, keyed on LOCATION and on BEHAVIOUR -------------
# FOUR cells, four mutants. The last two are WRONG FIXES, not vandalism: each is a guard a
# careful author would write, each satisfies every case the first two cells can see, and
# each is killed by exactly one of the cells added for it. A byte-lock on the shipped
# condition would flag them too -- and an author who re-anchors the mutations, as
# fixture-mutants.md tells them to, is then green on a validator that lost real coverage.
# So the discrimination lives in BEHAVIOUR, and the anchor arm is only the guard on the
# mutations being applied at all.
#
#                                    unconv   growth   zero-prior   starts-p2
#   shipped                          GENERIC  MOVING   MOVING       GENERIC
#   m1  guard removed                MOVING   MOVING   MOVING       MOVING     <- both
#   m2  guard on a wrong variable    GENERIC  GENERIC  GENERIC      GENERIC    <- growth
#   m3  guard on `prior > 0`         GENERIC  MOVING   GENERIC      GENERIC    <- zero-prior
#   m4  guard on the pass NUMBER     GENERIC  MOVING   MOVING       MOVING     <- starts-p2
#
# m3 and m4 move ONE cell each, and it is a different cell. That is the whole assertion:
# "this pass has no PREDECESSOR" is neither "prior is zero" nor "the number is 1".
#
# Anchored on the WHOLE condition line. `[ -n "$crit" ] && [ -n "$prior" ]` opens arm C's
# partition check as well, so a mutation keyed on the shared prefix would edit that instead
# and come out green here.
SG_ANCHOR='  if [ -n "$crit" ] && [ -n "$prior" ] && [ -n "$PREV_CRIT" ] && [ "$crit" -gt "$prior" ]; then'
ASSERTIONS=$((ASSERTIONS + 1))
sg_n="$(grep -cF -- "$SG_ANCHOR" "$VALIDATOR")" || sg_n=0
sg_ctl="$(grep -cF -- "$SG_ANCHOR-no-such-line" "$VALIDATOR")" || sg_ctl=0
if [ "$sg_n" -ne 1 ] || [ "$sg_ctl" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s the anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0) -- the two mutants below prove nothing\n' \
    "MUTATION sg-anchor" "$sg_n" "$sg_ctl"
else
  printf '  ok    %-28s the anchor is unique in %s (impossible-anchor control: 0)\n' \
    "MUTATION sg-anchor" "$(basename "$VALIDATOR")"
fi

SG_CASES="pass1-honest-zero-unconverged pass1-honest-zero-then-growth scope-grew-at-zero-prior series-starts-at-pass2"
SG_REAL="GENERIC MOVING MOVING GENERIC"

sg_remedy() {  # $1 script  $2 case-dir -> which of arm D's two remedies it emitted
  local out
  out="$(bash "$1" --series "$ROOT/$2/s1-adversarial-p" \
          --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  case "$out" in
    *"MOVING ARTIFACT"*) printf 'MOVING\n' ;;
    *"$D_GENERIC"*)      printf 'GENERIC\n' ;;
    *)                   printf 'NEITHER\n' ;;
  esac
}

sg_score() {  # $1 label  $2 script  $3 expected pair
  local label="$1" script="$2" want="$3" got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  local i=0 wm; rsel "$want" "$SG_REAL"; wm="$(rmask "$want")"
  for c in $SG_CASES; do i=$((i + 1)); if ron "$i"; then got="$got $(sg_remedy "$script" "$c")"; else got="$got ."; fi; done
  RSEL=""
  if [ "$(echo $got)" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]\n' "$label" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$label" "$(echo $got)" "$(echo $want)"
  fi
}

# THE UNMUTATED CONTROL, from $ROOT like every mutant. A copy that dies resolving a
# sibling emits nothing, NEITHER is what "no output" scores as, and NEITHER would read
# as a kill on both mutants below.
SG_CTRL="$ROOT/control-scope-grew.sh"
cp "$VALIDATOR" "$SG_CTRL"
sg_score "CONTROL scope-grew copy" "$SG_CTRL" "$SG_REAL"

sg_mutate() {  # $1 label  $2 replacement condition line  $3 expected pair
  local label="$1" new="$2" want="$3"
  local mut="$ROOT/mutant-$label.sh"
  MUT_OLD="$SG_ANCHOR" MUT_NEW="$new" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$mut"
  if cmp -s "$VALIDATOR" "$mut"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutation matched NOTHING -- this assertion proves nothing\n' "MUTATION $label"
    return
  fi
  if ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the mutant is not a valid shell script -- its silence is not a kill\n' "MUTATION $label"
    return
  fi
  sg_score "MUTATION $label" "$mut" "$want"
}

# m1 -- REMOVE THE GUARD. This is the shipped defect on demand: pass 1's honest zero is
# counted as growth and the unconverged series is handed the freeze-and-cut remedy.
sg_mutate scope-grew-unguarded \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$crit" -gt "$prior" ]; then' \
  "MOVING MOVING MOVING MOVING"

# m2 -- GUARD ON THE WRONG VARIABLE. STALL_FROM is also empty at pass 1, so it looks like
# "a previous pass exists" and is not: it is empty on every pass of a series that never
# stalls, which kills the increment outright. The unconverged case is GREEN against this
# mutant -- right answer, no working guard -- and only the growth case says so.
sg_mutate scope-grew-wrong-var \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ -n "$STALL_FROM" ] && [ "$crit" -gt "$prior" ]; then' \
  "GENERIC GENERIC GENERIC GENERIC"

# m3 -- A WRONG FIX: "there is no previous pass" spelled as "prior is zero". It excludes
# pass 1 in every case seeded before `scope-grew-at-zero-prior` existed, and it also
# excludes a mid-cycle pass whose CRITICALs are ALL in added scope -- the strongest
# moving-artifact evidence the field can carry.
sg_mutate scope-grew-prior-zero \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$prior" -gt 0 ] && [ "$crit" -gt "$prior" ]; then' \
  "GENERIC MOVING GENERIC GENERIC"

# m4 -- A WRONG FIX: "there is no previous pass" spelled as "the pass number is not 1".
# True of pass 1 and false of nothing else, so it counts the FIRST FILE of every series
# that starts above pass 1 -- which is the state the guard exists to exclude. The pass
# number is read off `$f` the way order_key does, so the mutant is the guard an author
# would actually write.
sg_mutate scope-grew-pass-number \
  '  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$(printf "%s" "$f" | sed -E "s/.*[^0-9]([0-9]+)\.md$/\1/")" != "1" ] && [ "$crit" -gt "$prior" ]; then' \
  "GENERIC MOVING MOVING MOVING"

fi
if sg j2h; then
echo
# --- ARM J's DOOR: a re-open is sanctioned by a VALID record, not by naming one ------------
expect reopen-record-missing 1 "resolves_divergence names a record that was never written -- FAIL (J)" s1-adversarial-p
expect_says reopen-record-missing s1-adversarial-p "J-door-validates" \
  "FAIL (J -- REOPEN)" "the record it names does not exist"
expect_state reopen-record-missing s1-adversarial-p REOPENED 3 "a citation of nothing is not a sanctioned exit -- deny"
expect drift-spec-no-cap 1 "a SPEC.md re-open whose scope_delta names no CAP-<n> or FR-S<N>-<n> -- FAIL (J, F5)" s1-adversarial-p
expect_says drift-spec-no-cap s1-adversarial-p "F5-reopen-spec" \
  "FAIL (J -- REOPEN)" "names no CAP-<n>"
expect_state drift-spec-no-cap s1-adversarial-p REOPENED 3 "a spec amendment naming nothing it moved is not a release -- deny"
expect drift-spec-cap 0 "NEAR-MISS: the same SPEC.md record naming CAP-2 -- PASS" s1-adversarial-p

echo
# --- ARM J2: TERMINAL DRIFT --------------------------------------------------------------
# Each case is a stamped repo built by seed.sh with TWO stamp commits (0.663.0 at 09:00, 0.669.0
# at 10:00); its series lives under `_bmad-output/planning-artifacts/s1/`, where the gate reads it.
J2P=_bmad-output/planning-artifacts/s1/spec-adversarial-p
expect drift-unrecorded 1 "SPEC.md moved after MET, nothing on the record -- FAIL (J2)" "$J2P"
expect_says drift-unrecorded "$J2P" "J2-names-both-remedies" \
  "FAIL (J2 -- DRIFT): spec-adversarial-p1.md stamps EXIT_CONDITION_MET" "REPAIR" "REOPEN" \
  "artifact_sha_before:"
expect_state drift-unrecorded "$J2P" CONVERGED 0 "arm J2 is GATE-ONLY: --cycle-state stays CONVERGED under drift"
expect drift-same-bytes 0 "DECOY: the bytes on disk are the notarized bytes" "$J2P"
expect drift-pre-stamp 0 "the series opened before J2's stamp (after K's): PENDING, not counted" "$J2P"
expect_says drift-pre-stamp "$J2P" "J2-legacy-pending" "PENDING (J2 -- DRIFT)" "Legacy series."
expect drift-repair-linked 0 "one structured repair link from the notarized sha to the disk sha -- PASS" "$J2P"
expect drift-repair-chain-two-links 0 "two links v1->v2->v3, the first link in the second-read record -- PASS" "$J2P"
expect drift-chain-broken 1 "only the v2->v3 link: no chain from the notarized sha -- FAIL (J2)" "$J2P"
expect drift-repair-fork 1 "two links from the same sha -- FAIL (J2), even though one of them reaches the disk sha" "$J2P"
expect_says drift-repair-fork "$J2P" "J2-fork-names-both" \
  "FAIL (J2 -- DRIFT)" "gate-planning-repair-p1.md gate-planning-repair-p2.md"
expect drift-repair-unstructured 1 "a link with both shas and no derivation: arm H would refuse it -- FAIL (J2)" "$J2P"
expect drift-reopen-verified 0 "REOPEN_AFTER_MET record + ONE verify pass: the verify pass is terminal -- PASS" "$J2P"
expect drift-reopen-no-verify 1 "the REOPEN record without the verify pass is not a link -- FAIL (J2)" "$J2P"
expect drift-reopen-after-not-disk 1 "verified at v2, then moved to v3 with no record -- FAIL (J2)" "$J2P"
expect drift-cumulative 0 "RESIDUE: prd.md is cumulative and not in the subject -- J2 silent" "$J2P"
expect drift-list 0 "RESIDUE: a comma list is not one file, even when its first member moved -- J2 silent" "$J2P"

# THE SKIP IS IN THE PROCEDURE BECAUSE A BARE --series MATCHING NOTHING FAILS. gate-validation.md
# tells the gate to skip a sprint dir holding no *-adversarial-p series; this pins why.
ASSERTIONS=$((ASSERTIONS + 1))
es_out="$(bash "$VALIDATOR" --series "$ROOT/drift-empty-sprint/$J2P" 2>&1)"; es_rc=$?
if [ "$es_rc" -eq 1 ] && grep -qF -- "matched nothing" <<<"$es_out"; then
  printf '  ok    %-28s exit=1 "matched nothing" (%s)\n' "drift-empty-sprint" "the procedure skips such a sprint rather than running the check"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s exit=%s -- a --series over an empty sprint dir must exit 1 naming the empty match\n' "drift-empty-sprint" "$es_rc"
fi

# --- MUTATION: J2's walk, fork check, subject, stamp rebinding; J's door ------------------
#                         unrec  pre      linked  chain2  fork   cumul   reopen-ver
#   shipped               FAIL   PENDING  SILENT  SILENT  FAIL   SILENT  SILENT
#   chain walk removed    FAIL   PENDING  FAIL    FAIL    FAIL   SILENT  SILENT
#   fork check removed    FAIL   PENDING  SILENT  SILENT  SILENT SILENT  SILENT
#   subject widened       FAIL   PENDING  SILENT  SILENT  FAIL   FAIL    SILENT
#   stamp not rebound     FAIL   FAIL     SILENT  SILENT  FAIL   SILENT  SILENT
# Built in a copy of the validator's directory carrying both siblings, with an unmutated control.
J2_CASES="drift-unrecorded drift-pre-stamp drift-repair-linked drift-repair-chain-two-links drift-repair-fork drift-cumulative drift-reopen-verified"
J2_REAL="FAIL PENDING SILENT SILENT FAIL SILENT SILENT"
J2_MUT="$ROOT/j2-mutants"; mkdir -p "$J2_MUT"
cp "$(dirname "$VALIDATOR")/validate-steering-budget.sh" "$J2_MUT/validate-steering-budget.sh"
cp "$(dirname "$VALIDATOR")/partition-document.sh" "$J2_MUT/partition-document.sh"
j2_cell() {  # $1 script  $2 case -> FAIL | PENDING | SILENT
  local out
  out="$(bash "$1" --series "$ROOT/$2/$J2P" --transcript-dir "$ROOT" ${SEAM_ARMS:+--arms "$SEAM_ARMS"} 2>&1)"
  case "$out" in
    *"FAIL (J2 -- DRIFT)"*)    printf 'FAIL\n' ;;
    *"PENDING (J2 -- DRIFT)"*) printf 'PENDING\n' ;;
    *)                         printf 'SILENT\n' ;;
  esac
}
j2_row() { local c r=""; for c in $J2_CASES; do r="$r $(j2_cell "$1" "$c")"; done; echo $r; }
j2_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  local i=0 wm; rsel "$3" "$J2_REAL"; wm="$(rmask "$3")"
  for c in $J2_CASES; do i=$((i + 1)); if ron "$i"; then got="$got $(j2_cell "$2" "$c")"; else got="$got ."; fi; done
  RSEL=""
  if [ "$(echo $got)" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
cp "$VALIDATOR" "$J2_MUT/control.sh"
j2_score "CONTROL j2 copy" "$J2_MUT/control.sh" "$J2_REAL"
# The j2 battery's mutants run in this directory, which has no merge beside them, so the guard reads
# the same copy they do.
seam_guard "SEAM-GUARD J2" J2 j2_row "$J2_MUT/control.sh"

# $1 label  $2 expected row  $3.. old/new pairs, EACH anchor exactly once in the validator.
# Every layer of a layered subject is reverted. The fork mutant removes the fork verdict AND the
# single-hit guard below it, which on its own also stops a two-hit walk as incomplete (measured:
# with only the first layer removed the fork cell still read FAIL). It also drops the fork
# conjunct of the self-probe, which would otherwise refuse the mutant with exit 2.
j2_mut_build() {  # $1 out  $2.. old/new pairs -> 0 applied, 1 an anchor was not unique
  local out="$1"; shift
  python3 - "$VALIDATOR" "$out" "$@" <<'PY'
import sys
s = open(sys.argv[1]).read()
a = sys.argv[3:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(1)
    s = s.replace(a[i], a[i + 1])
open(sys.argv[2], "w").write(s)
PY
}
j2_mutate() {  # $1 label  $2 expected row  $3.. old/new pairs
  local label="$1" want="$2" mut="$J2_MUT/mutant-$1.sh"; local SEAM_ARMS="J2"; shift 2
  if ! j2_mut_build "$mut" "$@" || cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s an anchor is not unique, the mutation DID NOT APPLY, or the mutant is not valid shell\n' "MUTATION $label"
    return
  fi
  j2_score "MUTATION $label" "$mut" "$want"
}
# MUTANT seam-constant: the seam answers a CONSTANT -- with --arms set, no arm runs at all; the full entry is
# untouched. SEAM-GUARD's own comparison is run on that copy and must REFUSE it (seam row != full row).
SC_MUT="$J2_MUT/mutant-seam-constant.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if ! j2_mut_build "$SC_MUT" 'case ",$AC_ARMS," in *",$1,"*) return 0 ;; esac; return 1; }' 'return 1; }' \
   || cmp -s "$VALIDATOR" "$SC_MUT" || ! bash -n "$SC_MUT" 2>/dev/null; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s the seam anchor is not in the validator exactly once -- FIXTURE STALE\n' "MUTATION seam-constant"
else
  sc_s="$(SEAM_ARMS=J2; j2_row "$SC_MUT")"; sc_f="$(SEAM_ARMS=""; j2_row "$SC_MUT")"
  if [ "$sc_f" = "$(echo $J2_REAL)" ] && [ "$sc_s" != "$sc_f" ]; then
    printf '  ok    %-28s SEAM-GUARD refuses it: seam [%s] != full [%s]\n' "MUTATION seam-constant" "$sc_s" "$sc_f"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s seam [%s] full [%s] -- the guard would pass a constant seam\n' "MUTATION seam-constant" "$sc_s" "$sc_f"
  fi
fi
j2_mutate j2-chain-walk "FAIL PENDING FAIL FAIL FAIL SILENT SILENT" \
  '      j2_walk "$j2_sha" "$j2_disk" "$AC_T/j2-links"' '      J2_END=incomplete'
j2_mutate j2-fork-check "FAIL PENDING SILENT SILENT SILENT SILENT SILENT" \
  '    if [ "$hits" -ge 2 ]; then J2_END=fork; return 0; fi' '    :' \
  '    [ "$hits" -eq 1 ] || return 0' '    [ "$hits" -ge 1 ] || return 0' \
  '[ "$j2p3" != fork ]' '[ -z "$j2p3" ]'
j2_mutate j2-subject "FAIL PENDING SILENT SILENT FAIL FAIL SILENT" \
  '  if [ -n "$j2_file" ] && j2_is_sha "$j2_sha" && j2_in_subject "$j2_file"; then' \
  '  if [ -n "$j2_file" ] && j2_is_sha "$j2_sha"; then'
j2_mutate j2-stamp-rebind "FAIL FAIL SILENT SILENT FAIL SILENT SILENT" \
  '          j2_stamp="$(K_RELEASE="$J2_RELEASE" k_stamp_parse < "$STAMP_LOG")"' \
  '          j2_stamp="$(k_stamp_parse < "$STAMP_LOG")"'

# --- BL-736: a story split carried into test-strategy.md by a repair chain is a SCOPE change. The
# receipt as an arm: graph s319's row shape, three worlds of the entry (unchanged ids silent; split
# refused without a re-open; split with REOPEN_AFTER_MET + verify silent), a MERGE whose row ids keep
# the split letters (whole-file sets equal), and the unreachable-blob and empty-extraction PENDINGs.
# Mutants, each a plausible regression: a whole-file id scan (its self-probe conjunct dropped, or it
# exits 2 and scores a kill it did not earn); an unreachable before blob read as unchanged; an empty
# extraction judged as a set.
echo "--- arm J2 story-id set (BL-736): receipt-bl736.sh against the validator, a control copy and three mutants"
R736="$DIR/receipt-bl736.sh"
[ -f "$R736" ] || broken "receipt-bl736.sh is not beside run.sh"
rcpt_cell "J2T shipped validator"     "$R736" "$VALIDATOR" 0
rcpt_mut  "J2T0 control (unmutated)"  "$R736" 0
RCPT_SEAM=1 rcpt_mut "SEAM-GUARD J2T receipt" "$R736" 0
RM_TWIN=reword rcpt_mut  "J2T1 whole-file id scan"   "$R736" "1|receipt BL-736: NOT FIXED -- split(rc=1) merge(rc=0) norows(rc=1)" \
  $'  awk \'/^\\|[ \\t]*ST[0-9]+-[^|]*\\|[ \\t]*[0-9]+\\.[0-9]+[a-z]?[ \\t]*\\|/ {\n         v = $0; sub(/^\\|[^|]*\\|[ \\t]*/, "", v); sub(/[ \\t]*\\|.*$/, "", v); print v }\' "$1" | sort -u' \
  $'  grep -oE \'[0-9]+\\.[0-9]+[a-z]?\' "$1" | sort -u' \
  '        if [ "$j2tp" != "2.3a 2.3b " ]; then' '        if false; then'
RM_TWIN=split rcpt_mut  "J2T2 unreachable read unchanged" "$R736" "1|receipt BL-736: NOT FIXED -- unreach(rc=0)" \
  '          j2t_why="no committed version of ${j2_file##*/} hashes to the notarized ${j2_sha}, so its story-id set cannot be read"' '          :'
RM_TWIN=reword rcpt_mut  "J2T3 empty extraction judged" "$R736" "1|receipt BL-736: NOT FIXED -- norows(rc=1)" \
  '          if [ -z "$j2t_b" ] || [ -z "$j2t_a" ]; then' '          if false; then'
# The era constant moved (J2SX7's shape): the worlds stay stamped at the SHIPPED J2T_RELEASE
# (RCPT_STAMP_FROM), so lowered, the predecessor-stamped world FAILs; raised, split and merge read
# not-owed and the legacy world loses its Legacy line. The receipt reads the line `J2T_RELEASE="x.y.z"`.
J2T_REL="$(sed -n 's/^J2T_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
IFS=. read -r j2t_ma j2t_mi j2t_pa <<EOF
$J2T_REL
EOF
if [ -z "$J2T_REL" ] || ! [ "$j2t_mi" -ge 1 ] 2>/dev/null; then
  ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE STALE -- no J2T_RELEASE="x.y.z" line (minor >= 1) in the validator\n' "J2T4/J2T5"
else
  RCPT_STAMP_FROM="$VALIDATOR" RM_TWIN=nostamp rcpt_mut "J2T4 J2T_RELEASE lowered" "$R736" "1|receipt BL-736: NOT FIXED -- pred(rc=1)" \
    "J2T_RELEASE=\"$J2T_REL\"" "J2T_RELEASE=\"${j2t_ma}.$((j2t_mi - 1)).${j2t_pa}\""
  RCPT_STAMP_FROM="$VALIDATOR" RM_TWIN=reword rcpt_mut "J2T5 J2T_RELEASE raised" "$R736" "1|receipt BL-736: NOT FIXED -- split(rc=0) merge(rc=0) legacy(rc=0)" \
    "J2T_RELEASE=\"$J2T_REL\"" "J2T_RELEASE=\"${j2t_ma}.$((j2t_mi + 1)).${j2t_pa}\""
fi

# J's door, scored on its own four cells in --cycle-state, the mode the hooks read.
JD_CASES="reopen-recorded reopen-record-missing drift-spec-no-cap drift-spec-cap"
JD_REAL="CONVERGED REOPENED REOPENED CONVERGED"
jd_score() {  # $1 label  $2 script  $3 expected row
  local got="" c
  ASSERTIONS=$((ASSERTIONS + 1))
  local i=0 wm; rsel "$3" "$JD_REAL"; wm="$(rmask "$3")"
  for c in $JD_CASES; do i=$((i + 1))
    if ron "$i"; then got="$got $(bash "$2" --series "$ROOT/$c/s1-adversarial-p" --cycle-state --transcript-dir "$ROOT" 2>/dev/null | cut -f1)"; else got="$got ."; fi
  done
  RSEL=""
  if [ "$(echo $got)" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
jd_score "CONTROL j-door copy" "$J2_MUT/control.sh" "$JD_REAL"
jd_mutate() {  # $1 label  $2 expected row  $3.. old/new pairs
  local label="$1" want="$2" mut="$J2_MUT/mutant-$1.sh"; shift 2
  if ! j2_mut_build "$mut" "$@" || cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s an anchor is not unique, the mutation DID NOT APPLY, or the mutant is not valid shell\n' "MUTATION $label"
    return
  fi
  jd_score "MUTATION $label" "$mut" "$want"
}
# The door accepting the field again -- the shipped defect on demand. Both invalid records pass.
jd_mutate j-citation "CONVERGED CONVERGED CONVERGED CONVERGED" \
  '    if validate_record "$j_rec" "${P_FILE[$i]}" "$i"; then' '    if true; then'
# F5's SPEC rule alone. Only the SPEC.md cell with no CAP moves, so the door mutant above is not
# the only thing standing between a spec amendment and an unnamed scope change.
jd_mutate f5-reopen-spec "CONVERGED REOPENED CONVERGED CONVERGED" \
  '      if [ "${r_art##*/}" = "SPEC.md" ] && ! [[ "$delta" =~ $r_re ]]; then' '      if false; then'

echo
# --- ARM H: the record is named by its SERIES, behind a stamp -------------------------------
# Every arm-H case above sits in no stamped repo and names its records `s1-brief-repair-p<M>`
# against the stem `s1`, so each one is a FOREIGN record that reads PENDING (no stamp). These
# worlds are stamped git repos, one property apart. The series is `prd-adversarial-p1/p2`, 3 MAJOR
# falling to 0, so arm H owes `prd-repair-p1.md`. The release is READ from the validator, so a
# renumbered H_RELEASE moves the worlds with it. Five worlds, one cell each (`<class>/<exit>`):
#   stem-post     owed name present, series opened after the stamp     -> SILENT/0
#   foreign-post  only `arch-repair-p1.md` (another series' record)     -> FOREIGN/1
#   foreign-pre   the same record, series opened BEFORE the stamp       -> PENDING/0
#   pred-stamp    the same record, repo stamped only at H_RELEASE's
#                 predecessor (but above K_RELEASE)                      -> PENDING/0
#   none-post     no record at all                                      -> MISSING/1 (unchanged)
H_REL="$(sed -n 's/^H_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
IFS=. read -r h_ma h_mi h_pa <<EOF
$H_REL
EOF
H_PRED="${h_ma}.$((h_mi - 1)).${h_pa}"
HW="$ROOT/.h-worlds"
h_world() {  # $1 world  $2 stamp version  $3 first invoked_at  $4 record name ("" = none)
  local w="$HW/$1" n
  mkdir -p "$w/.claude" || return 1
  printf 'version: %s\n' "$2" > "$w/.claude/.ai-dlc-version"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    cd "$w" || exit 1
    git init -q . >/dev/null || exit 1
    git add .claude/.ai-dlc-version || exit 1
    GIT_COMMITTER_DATE=2026-09-29T10:00:00Z GIT_AUTHOR_DATE=2026-09-29T10:00:00Z \
      git -c user.email=fixture@example.invalid -c user.name=fixture -c commit.gpgsign=false \
          -c core.hooksPath=/dev/null commit -q -m stamp >/dev/null ) || return 1
  for n in 1 2; do
    {
      printf '# prd -- adversarial pass %s\n\n' "$n"
      printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
      printf 'skill: ai-dlc-adversary-review\n'
      if [ "$n" = 1 ]; then printf 'invoked_at: %s\n' "$3"; else printf 'invoked_at: 2026-09-29T12:00:00Z\n'; fi
      printf 'tool_use_id: toolu_fixture_h%s\n' "$n"
      printf 'mode: subagent\nlead_role: pm\nartifact: prd.md\n'
      printf 'artifact_sha: %s\n' 0000000000000000000000000000000000000000000000000000000000000000
      printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\n'
      if [ "$n" = 1 ]; then printf 'findings_major: 3\nverdict: EXIT_CONDITION_NOT_MET\n'
      else printf 'findings_major: 0\nverdict: EXIT_CONDITION_MET\n'; fi
      printf 'findings_major_underived: 0\nfindings_minor: 0\n'
      printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
    } > "$w/prd-adversarial-p$n.md"
  done
  [ -z "$4" ] || printf '# Repair record\n\n### F1 -- MAJOR\n- disposition: repaired\n- edit: prd.md:4\n- derivation:\n    $ grep -c x prd.md\n    1\n' > "$w/$4"
}
H_WORLDS="stem-post foreign-post foreign-pre pred-stamp none-post"
H_REAL="SILENT/0 FOREIGN/1 PENDING/0 PENDING/0 MISSING/1"
H_OK=1
[ -n "$H_REL" ] && [ "$h_mi" -ge 1 ] 2>/dev/null || H_OK=0
h_world stem-post    "$H_REL"  2026-09-29T11:00:00Z prd-repair-p1.md  || H_OK=0
h_world foreign-post "$H_REL"  2026-09-29T11:00:00Z arch-repair-p1.md || H_OK=0
h_world foreign-pre  "$H_REL"  2026-09-29T09:00:00Z arch-repair-p1.md || H_OK=0
h_world pred-stamp   "$H_PRED" 2026-09-29T11:00:00Z arch-repair-p1.md || H_OK=0
h_world none-post    "$H_REL"  2026-09-29T11:00:00Z ""                || H_OK=0
# Not in the row: the consumer's commonest misname, this series' OWN record under its pass stem.
# It fails like foreign-post and must hand the opposite remedy (rename it, not leave it).
h_world misnamed-post "$H_REL" 2026-09-29T11:00:00Z prd-adversarial-repair-p1.md || H_OK=0
# Nor this: a lane round's record (BL-716) with round one's absent. It fails like foreign-post, and its
# remedy names the missing round-one record and never says rename.
h_world lane-post "$H_REL" 2026-09-29T11:00:00Z prd-serial-repair-p1.md || H_OK=0
# THE WORLDS ARE WHAT THEY CLAIM: the release was read, every world built, the predecessor
# still satisfies K_RELEASE (so a stamp read that forgot to rebind WOULD date pred-stamp), and
# the BASE glob would accept the foreign record -- or the FOREIGN cells test a name nobody uses.
ASSERTIONS=$((ASSERTIONS + 1))
h_krel="$(sed -n 's/^K_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
h_glob=0; for h_c in "$HW/foreign-post"/*-repair-p1.md; do [ -f "$h_c" ] && h_glob=$((h_glob + 1)); done
if [ "$H_OK" -ne 1 ] || [ -z "$h_krel" ] || [ "$(printf '%s\n%s\n' "$h_krel" "$H_PRED" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" != "$h_krel" ] || [ "$h_glob" -ne 1 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN: built=%s release=%s pred=%s K_RELEASE=%s old-glob hits=%s (want 1)\n' \
    "h-worlds" "$H_OK" "$H_REL" "$H_PRED" "$h_krel" "$h_glob"
else
  printf '  ok    %-28s release %s, predecessor %s >= K_RELEASE %s; the old glob takes the foreign record\n' \
    "h-worlds" "$H_REL" "$H_PRED" "$h_krel"
fi
h_cell() {  # $1 script  $2 world -> <class>/<exit>
  local out rc v
  out="$(bash "$1" --series "$HW/$2/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" ${SEAM_ARMS:+--arms "$SEAM_ARMS"} 2>&1)"; rc=$?
  case "$out" in
    *"The only structured record for pass"*)  v=FOREIGN ;;
    *"PENDING (H -- REPAIR-RECORD)"*)         v=PENDING ;;
    *"the lead having repaired inline"*)      v=MISSING ;;
    *"FAIL ("*)                               v=OTHER ;;
    *"adversarial convergence -- 2 pass"*)    v=SILENT ;;
    *)                                        v=NORUN ;;
  esac
  printf '%s/%s\n' "$v" "$rc"
}
h_row() { local w r=""; for w in $H_WORLDS; do r="$r $(h_cell "$1" "$w")"; done; echo $r; }
h_score() {  # $1 label  $2 script  $3 expected row
  local got="" w
  ASSERTIONS=$((ASSERTIONS + 1))
  local i=0 wm; rsel "$3" "$H_REAL"; wm="$(rmask "$3")"
  for w in $H_WORLDS; do i=$((i + 1)); if ron "$i"; then got="$got $(h_cell "$2" "$w")"; else got="$got ."; fi; done
  RSEL=""
  if [ "$(echo $got)" = "$(echo $wm)" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$(echo $got)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$(echo $got)" "$(echo $3)"
  fi
}
h_score "H series-named record" "$VALIDATOR" "$H_REAL"
# The unmutated copy in the mutant directory, siblings beside it. SILENT is a positive cell: it
# requires the validator's own header line, so a copy that never ran reads NORUN, not SILENT.
h_score "CONTROL h copy" "$J2_MUT/control.sh" "$H_REAL"
seam_guard "SEAM-GUARD H" H h_row "$J2_MUT/control.sh"
expect_says_h() {  # $1 world  $2 label  $3... required substrings
  local w="$1" label="$2" out missing="" want; shift 2
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$HW/$w/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  for want in "$@"; do grep -qF -- "$want" <<<"$out" || missing="$missing \"$want\""; done
  if [ -z "$missing" ]; then printf '  ok    %-28s %s\n' "$label" "says what it must"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s missing:%s\n' "$label" "$missing"; fi
}
expect_says_h foreign-post "H-foreign-names-both" "prd-repair-p1.md, is absent" "The only structured record for pass 1 is arch-repair-p1.md" \
  "do not rename a record that belongs to a different repair"
expect_says_h misnamed-post "H-misnamed-own-rename" "The only structured record for pass 1 is prd-adversarial-repair-p1.md" \
  "If it records THIS series' repair, rename it to the owed path"
expect_silent_h() {  # $1 world  $2 token that must be absent  $3 world where it is present (control)
  local out ctl
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$(bash "$VALIDATOR" --series "$HW/$1/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  ctl="$(bash "$VALIDATOR" --series "$HW/$3/prd-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"
  if grep -qF -- "$2" <<<"$out"; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s "%s" fired in %s\n' "H-remedy-$1" "$2" "$1"
  elif ! grep -qF -- "$2" <<<"$ctl"; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s CONTROL: "%s" absent from %s too\n' "H-remedy-$1" "$2" "$3"
  else printf '  ok    %-28s the other remedy is silent here, present in %s\n' "H-remedy-$1" "$3"; fi
}
expect_silent_h misnamed-post "do not rename a record" foreign-post
expect_silent_h foreign-post "rename it to the owed path" misnamed-post
expect_says_h lane-post "H-lane-names-round-one" "The only structured record for pass 1 is prd-serial-repair-p1.md" \
  "It is a lane round's record" "The missing record is round one's own, prd-repair-p1.md"
expect_silent_h lane-post "rename it to the owed path" misnamed-post
expect_says_h foreign-pre  "H-foreign-legacy" "is satisfied only by arch-repair-p1.md, not by" "prd-repair-p1.md" "Legacy series."
expect_says_h pred-stamp   "H-foreign-not-owed" "at ${H_REL} or later -- not owed yet."
h_mutate() {  # $1 label  $2 expected row  $3.. old/new pairs
  local label="$1" want="$2" mut="$J2_MUT/mutant-$1.sh"; local SEAM_ARMS="H"; shift 2
  if ! j2_mut_build "$mut" "$@" || cmp -s "$VALIDATOR" "$mut" || ! bash -n "$mut" 2>/dev/null; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s an anchor is not unique, the mutation DID NOT APPLY, or the mutant is not valid shell\n' "MUTATION $label"
    return
  fi
  h_score "MUTATION $label" "$mut" "$want"
}
# The stamp gate removed: every foreign record is owed, legacy or not.
h_mutate h-stamp-gate "SILENT/0 FOREIGN/1 FOREIGN/1 FOREIGN/1 MISSING/1" \
  '  [ -n "$H_GATE" ] && return 0' '  H_GATE=owed; H_GATE_MSG=mutant; return 0'
# The glob restored, every layer: the owed-name test and the foreign branch both gone, so any
# `*-repair-p<M>.md` satisfies the pass again -- the pre-fix arm.
h_mutate h-glob-restored "SILENT/0 SILENT/0 SILENT/0 SILENT/0 MISSING/1" \
  '  if [ -n "$H_STEM" ] && [ -f "$h_own" ] && [ -s "$h_own" ] && repair_field disposition "$h_own" \' \
  '  if false && [ -f "$h_own" ] && [ -s "$h_own" ] && repair_field disposition "$h_own" \' \
  '    [ -n "$rec" ] && h_foreign="$rec"' '    :'
# The stamp read without the rebinding: K_RELEASE's stamp dates pred-stamp, which then FAILS.
h_mutate h-stamp-rebind "SILENT/0 FOREIGN/1 PENDING/0 FOREIGN/1 MISSING/1" \
  '    h_stamp="$(K_RELEASE="$H_RELEASE" k_stamp_parse < "$STAMP_LOG")"' \
  '    h_stamp="$(k_stamp_parse < "$STAMP_LOG")"'
# The stem keeps `-adversarial`: the owed name becomes `prd-adversarial-repair-p1.md`, and the
# series' own correctly-named record reads as foreign. The self-probe conjunct goes with it.
h_mutate h-stem-unstripped "FOREIGN/1 FOREIGN/1 PENDING/0 PENDING/0 MISSING/1" \
  '  H_STEM="${b%-adversarial}"' '  H_STEM="$b"' \
  '  if [ "$hp1" != prd ] || [ "$hp2" != s289-rr ] || [ "$hp3" != x-p1 ] \' '  if false \'

fi

if sg j3; then
echo
# --- ARM J3 (BL-814): every MAJOR the terminal MET pass leaves is repaired or deferred on a record ---
# The receipt as an arm: it builds its own worlds (coe, architecture and stories series, each a repo
# stamped at the validator's J3_RELEASE) and drives the validator it is handed. Mutants, each a
# plausible regression: the subject keyed on blocking (the underived-only world passes); a key without
# its shard file (two `F-1`s read as one closed key); any deferred-to accepted; an era gate on the
# version file's presence (the legacy world FAILs); every pass's repair record read (a stale pass's
# identity entry closes the terminal pass's colliding id); the successor's digest matched as a substring
# (cross-1.md#F-1 names 1.md#F-1); an identity triple read as a link; one linked triple closing every
# token of both records; the heading id read raw (`F-1:` is not F-1, and two headings of one key count
# twice); the DEFER remedy telling the lead to write a record its guard denies. Each mutant names the
# exact NOT FIXED line it must produce, so a mutant that crashes the validator (rc 2 everywhere) is no kill.
echo "--- arm J3 (BL-814): receipt-bl814.sh against the validator, a control copy and thirteen mutants"
R814="$DIR/receipt-bl814.sh"
[ -f "$R814" ] || broken "receipt-bl814.sh is not beside run.sh"
J3NF="receipt BL-814: NOT FIXED --"
rcpt_cell "J3 shipped validator"     "$R814" "$VALIDATOR" 0
rcpt_mut  "J3-0 control (unmutated)" "$R814" 0
RCPT_SEAM=1 rcpt_mut "SEAM-GUARD J3 receipt" "$R814" 0
RM_TWIN=undeferred rcpt_mut  "J3-1 keyed on blocking"   "$R814" "1|$J3NF underonly(rc=0)" \
  '  && [ "${LAST_MAJOR:-0}" -gt 0 ] 2>/dev/null && J3_OPEN=1' \
  '  && [ "$(( ${LAST_MAJOR:-0} - $(block_field "$LAST_FILE" findings_major_underived | tr -cd 0-9) ))" -gt 0 ] 2>/dev/null && J3_OPEN=1'
RM_TWIN=deferred rcpt_mut  "J3-2 bare finding id"     "$R814" "1|$J3NF undeferred(rc=1) stalepass(rc=1) twof1(rc=0) ident(rc=1) partlink(rc=0) seriallink(rc=0) dupid(rc=0)" \
  '        if (t ~ /[0-9]/) { k = (sh == "" ? base : sh) "#" t; if (!seen[k]++) print k } } }'"' \"\$1\"" '        if (t ~ /[0-9]/) print t } }'"' \"\$1\"" \
  '    FILENAME == ARGV[2] { r[norm($1)] = 1; next }' '    FILENAME == ARGV[2] { x = norm($1); sub(/^.*#/, "", x); r[x] = 1; next }' \
  '    FILENAME == ARGV[3] { d[norm($1)] = $2; next }' '    FILENAME == ARGV[3] { x = norm($1); sub(/^.*#/, "", x); d[x] = $2; next }' \
  '  if [ "$j3p1" != "1.md#F-1 cross-2.md#F-1 " ] || [ "$j3p2" != "j3u-adversarial-p1.md#M1 " ] \' '  if [ "$j3p1" != "F-1 F-1 " ] || [ "$j3p2" != "M1 " ] \'
RM_TWIN=deferred rcpt_mut  "J3-3 any deferred-to"     "$R814" "1|$J3NF wrongstep(rc=0) nosucc(rc=0)" \
  '            if (x in d) { if (succ != "" && d[x] == succ) continue' '            if (x in d) { continue'
RM_TWIN=undeferred rcpt_mut  "J3-4 era on presence"     "$R814" "1|$J3NF legacy(rc=1)" \
  '  if [[ "$at" < "$J3_STAMP" ]]; then' '  if false; then'
RM_TWIN=repaired rcpt_mut  "J3-5 any pass's record"   "$R814" "1|$J3NF stalepass(rc=0)" \
  '  for j3_rec in "$j3_dir/${j3_stem}-repair-p${j3_m}.md" "$j3_dir/${j3_stem}-serial-repair-p${j3_m}.md"; do' \
  '  for j3_rec in "$j3_dir/${j3_stem}"-*repair-p*.md; do'
RM_TWIN=undeferred rcpt_mut  "J3-6 dispatch narrowed to one digit" "$R814" "1|$J3NF p12(rc=0)" \
  '  *-adversarial-p[0-9]*".md")' '  *-adversarial-p[0-9]".md")'
# Widening the outer pattern alone is an EQUIVALENT mutant (the inner digits-only case still rejects pX and a bare p),
# so J3-7 widens it and drops the inner guard together: the near-miss world pxp2 is then judged and FAILs.
RM_TWIN=ptxt rcpt_mut  "J3-7 dispatch widened, digits guard gone" "$R814" "1|$J3NF pxp2(rc=1)" \
  '  *-adversarial-p[0-9]*".md")' '  *-adversarial-p*".md")' \
  '    case "$j3_m" in ""|*[!0-9]*) ;; *) [ -n "$j3_stem" ] && J3_ARM=1 ;; esac ;;' '    J3_ARM=1 ;;'
RM_TWIN=subok rcpt_mut  "J3-8 successor substring" "$R814" "1|$J3NF substr(rc=0)" \
  '          if ((p == 1 || pre !~ pc) && (post == "" || post !~ nc)) { hit = 1; break }' '          if (1) { hit = 1; break }'
RM_TWIN=repaired rcpt_mut  "J3-9 identity triple links" "$R814" "1|$J3NF ident(rc=0)" \
  '      $1 == "T" && $3 != $4 { m = split' '      $1 == "T" { m = split'
RM_TWIN=unlinked rcpt_mut  "J3-10 one link closes all" "$R814" "1|$J3NF partlink(rc=0) seriallink(rc=0)" \
  '      END { for (i = 1; i <= ns; i++) if (st[i] in lk) print sk[i] }'"'" \
  '      END { for (i = 1; i <= ns; i++) print sk[i]; for (x in lk) { print "#LINKED"; break } }'"'" \
  '  done
  j3_succ "$j3_stem"' '  done
  grep -qx '"'#LINKED'"' "$AC_T/j3-tok" || : > "$AC_T/j3-tok"
  j3_succ "$j3_stem"'
RM_TWIN=deferbold rcpt_mut  "J3-11 heading id read raw" "$R814" "1|$J3NF dupid(rc=0) idpunct(rc=1)" \
  '    /^### / && fnd && sev($0) == "MAJOR" { s = $0; sub(/^#+[ \t]+/, "", s); gsub(/[*`_]/, "", s); gsub(/[][]/, "", s)
      sub(/^[ \t]+/, "", s); sub(/^[Ff]inding[ \t]+/, "", s)
      if (match(s, /^[A-Za-z0-9][A-Za-z0-9.-]*/)) { t = substr(s, 1, RLENGTH); sub(/[.-]+$/, "", t)
        if (t ~ /[0-9]/) { k = (sh == "" ? base : sh) "#" t; if (!seen[k]++) print k } } }'"' \"\$1\"" \
  '    /^### / && fnd && sev($0) == "MAJOR" { print (sh == "" ? base : sh) "#" $2 }'"' \"\$1\""
RM_TWIN=unkeyed rcpt_mut  "J3-12 keys counted with repeats" "$R814" "1|$J3NF dupid(rc=0)" \
  'if (!seen[k]++) print k } } }'"' \"\$1\"" 'print k } } }'"' \"\$1\""
RM_TWIN=wrongstep rcpt_mut  "J3-13 remedy says write"  "$R814" "1|$J3NF undeferred(rc=1)" \
  'DEFER    dispatch a remediator to write $j3_dir' 'DEFER    write $j3_dir'

# THE DEFERRAL MAP IS BOUND TO THE STEP FILES. Each J3_SUCCESSORS row `<stem>:<step>:<succ>:<ctx>` names
# a step file whose `nextStepFile:` is `./<succ>.md`, and a successor step file that writes `s<N>/<ctx>`.
# Self-probe first, both directions: a seeded row whose successor is wrong is refused.
J3_STEPS=""
for cand in "$DIR/../../skills/ai-dlc/steps" "$DIR/../../../.claude/skills/ai-dlc/steps"; do
  [ -f "$cand/carry-over-evaluation.md" ] && [ -f "$cand/requirements.md" ] && { J3_STEPS="$cand"; break; }
done
[ -n "$J3_STEPS" ] || broken "BL-814: the step files are not under either layout from $DIR"
j3_bind() {  # $1 one map row -> 0 when it agrees with the step files
  local step succ ctx r="$1"
  r="${r#*:}"; step="${r%%:*}"; r="${r#*:}"; succ="${r%%:*}"; ctx="${r#*:}"
  [ -f "$J3_STEPS/$step.md" ] && [ -f "$J3_STEPS/$succ.md" ] || return 1
  grep -qx "nextStepFile: ./$succ.md" "$J3_STEPS/$step.md" || return 1
  grep -qF "s<N>/$ctx" "$J3_STEPS/$succ.md"
}
ASSERTIONS=$((ASSERTIONS + 1))
if ! j3_bind "coe:carry-over-evaluation:requirements:requirements-context.md" \
   || j3_bind "coe:carry-over-evaluation:architecture:architecture-context.md" \
   || j3_bind "requirements:requirements:architecture:requirements-context.md"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s the binding self-probe did not discriminate (a true row, a wrong successor, a wrong digest)\n' "J3-MAP"
else
  j3_rows="$(awk '/^J3_SUCCESSORS="/ { on = 1; sub(/^J3_SUCCESSORS="/, "") } on { l = $0; e = sub(/"$/, "", l); print l; if (e) exit }' "$VALIDATOR")"
  j3_n=0; j3_off=""
  while IFS= read -r j3_r; do
    [ -n "$j3_r" ] || continue
    j3_n=$((j3_n + 1))
    j3_bind "$j3_r" || j3_off="$j3_off {$j3_r}"
  done <<J3EOF
$j3_rows
J3EOF
  if [ "$j3_n" -lt 2 ] || [ -n "$j3_off" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s %s J3_SUCCESSORS row(s) read; disagreeing with the step files:%s\n' "J3-MAP" "$j3_n" "${j3_off:- none (too few rows read)}"
  else
    printf '  ok    %-28s %s J3_SUCCESSORS rows each agree with nextStepFile: and the successor digest\n' "J3-MAP" "$j3_n"
  fi
fi
fi
if sg k3; then
echo
# --- ARM K3: the requirements series reviews the SUBJECT ------------------------------------
# Every K3 world is its own git repository (trunk main, sprint 9 on a branch) carrying the
# requirements subject, a `.claude/.ai-dlc-version` stamp commit, and passes written by the REAL
# producers: partition-subject.sh's first map writes the manifest, merge-adversarial-shards.sh
# --subject (or --document) writes the pass. Built OUTSIDE $ROOT so the derived pairing loop below
# never walks them (K3 is gate-only; nothing here denies).
#   k3-subject    a sharded subject merge, post-stamp                      exit 0, K3 silent
#   k3-document   terminal pass = a `--document prd.md` merge, post-stamp exit 1, FAIL (K3
#   k3-wrongset   same shard COUNT, other ordinal SET, post-stamp         exit 1, FAIL (K3
#   k3-serial     a one-part subject, one adversary naming the manifest   exit 0, K3 and K2 silent
#   k3-pre        k3-document's shape, series opened BEFORE the stamp     exit 0, PENDING Legacy
#   k3-moved      k3-document's shape, prd.md moved after the pass        exit 0, PENDING bytes
#   k3-pin        installed layout; the copy in force has no --scope-ref  exit 0, PENDING; its
#                 control world, the real copy in force, FAILs (K3
#   k3-armh       a party record beside a fallen pass 1 -> pass 1 still owes requirements-repair-p1
K3W="$(mktemp -d "${TMPDIR:-/tmp}/check24-k3.XXXXXX")" || exit 2
trap 'rm -rf "$ROOT" "$K3W"' EXIT
K3S="$(cd "$(dirname "$VALIDATOR")" && pwd)"
k3g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
k3lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
k3sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
K3PA=_bmad-output/planning-artifacts
# The merge derives each shard's dispatch id from the harness records (merge-adversarial-shards.sh,
# THE DISPATCH ID), so every k3 shard written under shards/ is recorded the way a dispatched
# adversary's Write is: the REAL remediation-guard hook appends the write-ledger row, and the meta
# file, the adversary spawn row and the SubagentStop probe row are seeded beside it. None is read by
# the validator.
K3_HOOK=""
_k3d="$K3S"
while [ -n "$_k3d" ] && [ "$_k3d" != "/" ]; do
  for _k3c in "$_k3d/core/hooks/ai-dlc-gate-remediation-guard.sh" "$_k3d/.claude/hooks/ai-dlc-gate-remediation-guard.sh"; do
    [ -f "$_k3c" ] && { K3_HOOK="$_k3c"; break 2; }
  done
  _k3d="$(dirname "$_k3d")"
done
k3_rec() { # <shard file under <state>/planning-artifacts/s<N>/shards/<dir>/>
  local f="$1" st root tp c ag id
  case "$f" in */planning-artifacts/s*/shards/*/*) ;; *) return 0 ;; esac
  [ -n "$K3_HOOK" ] && command -v jq >/dev/null 2>&1 || return 1
  st="$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$f")")")")")"; root="$(dirname "$st")"
  c="$(printf '%s' "$f" | cksum)"; c="${c%% *}"; ag="$(printf 'a%016x' "$c")"; id="$(printf 'toolu_01K3Dispatch%012d' "$c")"
  tp="$root/.harness/k3-session.jsonl"; mkdir -p "${tp%.jsonl}/subagents" || return 1
  [ -f "$st/pipeline-snapshot.md" ] || : > "$st/pipeline-snapshot.md"
  printf '{"toolUseId":"%s","agentType":"adversary"}\n' "$id" > "${tp%.jsonl}/subagents/agent-$ag.meta.json"
  printf '{"v":1,"ts":"2026-10-01T09:00:00Z","role":"adversary","tool_use_id":"%s"}\n' "$id" >> "$st/spawn-ledger.jsonl"
  printf '{"v":3,"ts":"2026-10-01T09:30:00Z","agent_id":"%s","role":"adversary","tool_use_id":"%s"}\n' "$ag" "$id" >> "$st/subagent-context.jsonl"
  jq -nc --arg f "$f" --arg a "$ag" --arg t "$tp" '{session_id:"k3-session",transcript_path:$t,hook_event_name:"PreToolUse",tool_name:"Write",tool_use_id:"toolu_01K3WriteCall",agent_id:$a,tool_input:{file_path:$f,content:"shard"}}' \
    | AI_DLC_STATE_DIR=_bmad-output CLAUDE_PROJECT_DIR="$root" bash "$K3_HOOK" >/dev/null 2>&1
  return 0
}
# k3_world <name> <stamp-date> [serial] [scripts-dir] [stamp-version] -> the world path. serial: only
# the SPEC changes. stamp-version defaults to 9.0.0, above every release constant the validator binds.
k3_world() {
  local w="$K3W/$1" pa; pa="$w/$K3PA"
  mkdir -p "$pa/s9" "$w/_bmad-output/specs/s9/kernel" "$w/.claude" || return 1
  { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
      k3g "$w" init -q . && k3g "$w" checkout -q -b main
      { printf '# Brief\n\n## Vision\n\n'; k3lorem vision 10; } > "$pa/product-brief.md"
      { printf '# PRD\n\n## Current state\n\n'; k3lorem current 20; printf '\n## Sprint 8\n\n'; k3lorem s8 20; printf '\n'; } > "$pa/prd.md"
      printf -- '- FR-S8-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md"
      if [ -n "${4:-}" ]; then mkdir -p "$w/scripts/ai-dlc" && cp "$4"/*.sh "$w/scripts/ai-dlc/"; fi
      printf 'version: %s\n' "${5:-9.0.0}" > "$w/.claude/.ai-dlc-version"
      k3g "$w" add -A && GIT_COMMITTER_DATE="$2" GIT_AUTHOR_DATE="$2" k3g "$w" commit -q -m stamp && k3g "$w" checkout -q -b sprint-9 ); } >/dev/null 2>&1 || return 1
  printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"
  if [ "${3:-}" != serial ]; then
    printf 'A new brief line.\n' >> "$pa/product-brief.md"
    { printf '## Sprint 9\n\n### Goals\n\n'; k3lorem s9g 30; printf '\n### Requirements\n\n'; k3lorem s9r 30; } >> "$pa/prd.md"
    printf -- '- FR-S9-1: architecture_impact: none\n' >> "$pa/s9/architecture-impact.md"
  fi
  printf '%s' "$w"
}
k3_shard() { # <dir> <key> <cite> <minute> <artifact> <artifact_sha> [n-major]
  local i=0
  { printf '# shard %s\n\n## Findings\n\n' "$2"
    while [ "$i" -lt "${7:-0}" ]; do i=$((i + 1)); printf '### M%s — MAJOR — finding\n\nsections: %s\n\n' "$i" "$3"; done
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: 2026-10-01T10:%02d:00Z\n' "$4"
    printf 'tool_use_id: toolu_k3%s%s\nmode: subagent\nlead_role: requirements\nartifact: %s\nartifact_sha: %s\n' "$2" "$4" "$5" "$6"
    printf 'findings_critical: 0\nfindings_major: %s\nverdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n' "${7:-0}"; } > "$1/$2.md"
  k3_rec "$1/$2.md"
}
k3_stems() { local w="$1"
  printf 'product-brief=%s SPEC=%s prd=%s architecture-impact=%s' "$(k3sha "$w/$K3PA/product-brief.md")" \
    "$(k3sha "$w/_bmad-output/specs/s9/kernel/SPEC.md")" "$(k3sha "$w/$K3PA/prd.md")" "$(k3sha "$w/$K3PA/s9/architecture-impact.md")"; }
k3_xkeys() { # <scripts dir> <K> -> the cross shard keys the partitioner names for K (`cross` at G=1)
  local g; g="$(bash "$1/partition-document.sh" --cross-groups "$2" | grep -c .)" || g=0
  [ "$g" -ge 1 ] || return 1
  if [ "$g" -eq 1 ]; then echo cross; else seq 1 "$g" | sed 's/^/cross-/'; fi
}
k3_subject_pass() { # <world> <scripts dir> [at|lone] -> s9/requirements-adversarial-p1.md by merge --subject
  # lone: ONE cross.md in place of the groups (BL-811's dispatched shape), merged by the REAL merge.
  local w="$1" d="$1/$K3PA/s9/shards/requirements-p1" m=0 o sl x
  AI_DLC_PROJECT_ROOT="$w" bash "$2/partition-subject.sh" --map 9 > "$w/subject.map" 2>&1 || return 1
  mkdir -p "$d"; sl="$(k3_stems "$w")"
  [ "${3:-}" = at ] && sl="$(printf '%s' "$sl" | sed 's/=/@/g')"
  for o in $(cut -f1 "$w/subject.map"); do m=$((m + 1)); k3_shard "$d" "$o" "$o" "$m" "$K3PA/s9/requirements-subject.md" "$sl"; done
  if [ "${3:-}" = lone ]; then x=cross; else x="$(k3_xkeys "$2" "$(grep -c . "$w/subject.map")")" || return 1; fi
  for o in $x; do m=$((m + 1)); k3_shard "$d" "$o" "1, 2" "$((40 + m))" "$K3PA/s9/requirements-subject.md" "$sl"; done
  bash "$2/merge-adversarial-shards.sh" --subject 9 "$d" >/dev/null 2>&1
}
# k3_oldshape <world> -- the terminal pass rewritten into the PRE-GROUPS cross shape: the cross
# group ids collapsed to one `cross=` id, as a merge before the cross groups wrote it.
k3_oldshape() {
  local p="$1/$K3PA/s9/requirements-adversarial-p1.md"
  awk '/^shard_tool_use_ids:/ { n = split($0, t, " "); o = ""; c = 0
         for (i = 1; i <= n; i++) { if (t[i] ~ /^cross-[0-9]+=/) { if (!c++) o = o " cross=toolu_k3oldcross" } else o = o (i > 1 ? " " : "") t[i] }
         print o; next } { print }' "$p" > "$p.n" && mv "$p.n" "$p" && grep -q ' cross=toolu_k3oldcross' "$p" && ! grep -q ' cross-1=' "$p"
}
k3_document_pass() { # <world> <scripts dir> [keep|nomanifest] -> the consumer's shape: a --document prd.md merge in the series
  # The merge runs BEFORE the manifest exists: merge-adversarial-shards.sh B4 refuses a --document
  # merge of any file a sprint's subject manifest names (BL-461), so the consumer's shape is
  # reachable only from a sprint that wrote the pass first -- which is what its history holds.
  # keep: the pass keeps its `prd-adversarial-p1` name (K3's widened candidate). nomanifest: and
  # no manifest is ever written (the widened candidate's silent twin).
  local w="$1" d="$1/$K3PA/s9/shards/prd-p1" m=0 o sl
  mkdir -p "$d"; sl="$(k3sha "$w/$K3PA/prd.md")"
  for o in $(bash "$2/partition-document.sh" --map "$w/$K3PA/prd.md" | cut -f1); do m=$((m + 1)); k3_shard "$d" "$o" "$o" "$m" "$K3PA/prd.md" "$sl"; done
  for o in $(k3_xkeys "$2" "$m"); do m=$((m + 1)); k3_shard "$d" "$o" "1, 2" "$((40 + m))" "$K3PA/prd.md" "$sl"; done
  bash "$2/merge-adversarial-shards.sh" --document "$w/$K3PA/prd.md" "$d" >/dev/null 2>&1 || return 1
  [ -f "$w/$K3PA/s9/prd-adversarial-p1.md" ] || return 1
  case "${3:-}" in
    keep|nomanifest) ;;
    *) mv "$w/$K3PA/s9/prd-adversarial-p1.md" "$w/$K3PA/s9/requirements-adversarial-p1.md" || return 1 ;;
  esac
  [ "${3:-}" = nomanifest ] && return 0
  AI_DLC_PROJECT_ROOT="$w" bash "$2/partition-subject.sh" --map 9 >/dev/null 2>&1   # the manifest exists, as in a real sprint
  [ -f "$w/$K3PA/s9/requirements-subject.md" ]
}
# <world> <scripts dir> -> s9/test-strategy-adversarial-p1.md, a --document merge of a sprint file the
# manifest does NOT name, written WITH the manifest present (B4 accepts it). K3's widened candidate
# reaches it and must drop it at the artifact test.
k3_other_pass() {
  local w="$1" d="$1/$K3PA/s9/shards/test-strategy-p1" m=0 o sl
  AI_DLC_PROJECT_ROOT="$w" bash "$2/partition-subject.sh" --map 9 >/dev/null 2>&1
  [ -f "$w/$K3PA/s9/requirements-subject.md" ] || return 1
  { printf '# Test strategy\n\n## Scope\n\n'; k3lorem scope 20; printf '\n## Levels\n\n'; k3lorem levels 20
    printf '\n## Risks\n\n'; k3lorem risks 20; } > "$w/$K3PA/s9/test-strategy.md"
  mkdir -p "$d"; sl="$(k3sha "$w/$K3PA/s9/test-strategy.md")"
  for o in $(bash "$2/partition-document.sh" --map "$w/$K3PA/s9/test-strategy.md" | cut -f1); do
    m=$((m + 1)); k3_shard "$d" "$o" "$o" "$m" "$K3PA/s9/test-strategy.md" "$sl"; done
  [ "$m" -ge 2 ] || return 1
  for o in $(k3_xkeys "$2" "$m"); do m=$((m + 1)); k3_shard "$d" "$o" "1, 2" "$((40 + m))" "$K3PA/s9/test-strategy.md" "$sl"; done
  bash "$2/merge-adversarial-shards.sh" --document "$w/$K3PA/s9/test-strategy.md" "$d" >/dev/null 2>&1 || return 1
  [ -f "$w/$K3PA/s9/test-strategy-adversarial-p1.md" ]
}
K3_OUT="$K3W/out"
k3_run() { # <validator> <world> -> K3_RC, $K3_OUT
  bash "$1" --series "$2/$K3PA/s9/requirements-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" ${SEAM_ARMS:+--arms "$SEAM_ARMS"} > "$K3_OUT" 2>&1; K3_RC=$?
}
k3_cell() { # <label> <validator> <world> <want rc> <must-say | -> <must-not-say | ->
  ASSERTIONS=$((ASSERTIONS + 1))
  k3_run "$2" "$3"
  if [ "$K3_RC" -eq "$4" ] && { [ "$5" = - ] || grep -qF -- "$5" "$K3_OUT"; } && { [ "$6" = - ] || ! grep -qF -- "$6" "$K3_OUT"; }; then
    printf '  ok    %-28s exit=%s %s\n' "$1" "$K3_RC" "${5#-}"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s, must say [%s], must not say [%s]\n' "$1" "$K3_RC" "$4" "$5" "$6"
    sed 's/^/          | /' "$K3_OUT"
  fi
}
K3_POST=2026-01-01T00:00:00Z; K3_LATE=2026-12-01T00:00:00Z
K3_BUILT=1
w="$(k3_world k3-subject "$K3_POST")" && k3_subject_pass "$w" "$K3S" || K3_BUILT=0
w="$(k3_world k3-document "$K3_POST")" && k3_document_pass "$w" "$K3S" || K3_BUILT=0
# k3-atform: k3-subject with `@`-form shards. The merge in this tree emits the `@` list, so K3's own
# pair split reads the new form straight off the merge's output.
w="$(k3_world k3-atform "$K3_POST")" && k3_subject_pass "$w" "$K3S" at \
  && grep -q '^artifact_sha: product-brief@' "$w/$K3PA/s9/requirements-adversarial-p1.md" || K3_BUILT=0
w="$(k3_world k3-wrongset "$K3_POST")" && k3_subject_pass "$w" "$K3S" \
  && awk '/^shard_tool_use_ids:/ { sub(/ 1=/, " 99=") } { print }' "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/p1.n" \
  && mv "$w/p1.n" "$w/$K3PA/s9/requirements-adversarial-p1.md" || K3_BUILT=0
w="$(k3_world k3-serial "$K3_POST" serial)" && { AI_DLC_PROJECT_ROOT="$w" bash "$K3S/partition-subject.sh" --map 9 > "$w/serial.map" 2>&1; [ $? -eq 3 ]; } \
  && k3_shard "$w/$K3PA/s9" requirements-adversarial-p1 x 0 "$K3PA/s9/requirements-subject.md" "$(k3_stems "$w")" \
  && sed -i.b 's/^tool_use_id: .*/tool_use_id: toolu_k3serial/' "$w/$K3PA/s9/requirements-adversarial-p1.md" && rm -f "$w/$K3PA/s9/"*.b || K3_BUILT=0
w="$(k3_world k3-pre "$K3_LATE")" && k3_document_pass "$w" "$K3S" || K3_BUILT=0
w="$(k3_world k3-moved "$K3_POST")" && k3_document_pass "$w" "$K3S" && printf 'moved\n' >> "$w/$K3PA/prd.md" || K3_BUILT=0
# k3-pin: an installed layout whose tracked partition-document.sh has no --scope-ref; the working
# copy (what would run TODAY) is the real one. Control: the same world with the real copy tracked.
K3_STUB="$K3W/stub-scripts"; K3_REAL="$K3W/real-scripts"; mkdir -p "$K3_STUB" "$K3_REAL"
cp "$K3S"/validate-adversarial-convergence.sh "$K3S"/validate-steering-budget.sh "$K3S"/partition-document.sh \
   "$K3S"/partition-subject.sh "$K3S"/merge-adversarial-shards.sh "$K3S"/validate-artifact-budget.sh "$K3_REAL/" && cp "$K3_REAL"/*.sh "$K3_STUB/" \
  && awk '{ gsub(/scope-ref/, "scope-XXX"); print }' "$K3_REAL/partition-document.sh" > "$K3_STUB/partition-document.sh" || K3_BUILT=0
# The pin only matters where a MAP is asked -- a manifest pass -- so both worlds carry k3-wrongset's
# pass: the real copy in force FAILs it (count right, set wrong), the stub in force is PENDING.
for v in pin:"$K3_STUB" pinctl:"$K3_REAL"; do
  w="$(k3_world "k3-${v%%:*}" "$K3_POST" "" "${v#*:}")" && cp "$K3_REAL"/*.sh "$w/scripts/ai-dlc/" \
    && k3_subject_pass "$w" "$K3_REAL" \
    && awk '/^shard_tool_use_ids:/ { sub(/ 1=/, " 99=") } { print }' "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/p1.n" \
    && mv "$w/p1.n" "$w/$K3PA/s9/requirements-adversarial-p1.md" || K3_BUILT=0
done
# k3-armh: pass 1 has 2 MAJOR, pass 2 has 0, and only a PARTY record sits beside them.
w="$(k3_world k3-armh "$K3_POST")" && k3_subject_pass "$w" "$K3S" || K3_BUILT=0
if [ "$K3_BUILT" -eq 1 ]; then
  sed -i.b 's/^findings_major: 0$/findings_major: 2/; s/^verdict: .*/verdict: EXIT_CONDITION_NOT_MET/' "$w/$K3PA/s9/requirements-adversarial-p1.md"
  awk '/^## Findings/ { print; print ""; print "### M1 — MAJOR — a"; print ""; print "### M2 — MAJOR — b"; next } { print }' \
    "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/p1.n" && mv "$w/p1.n" "$w/$K3PA/s9/requirements-adversarial-p1.md"
  sed 's/invoked_at: 2026-10-01T10:00:00Z/invoked_at: 2026-10-02T10:00:00Z/; s/^findings_major: 2$/findings_major: 0/; s/^verdict: .*/verdict: EXIT_CONDITION_MET/; /^### M[12] — MAJOR/d' \
    "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/$K3PA/s9/requirements-adversarial-p2.md"
  sed -i.b 's/^invoked_at: 2026-10-01T/invoked_at: 2026-10-02T/' "$w/$K3PA/s9/requirements-adversarial-p2.md"
  rm -f "$w/$K3PA/s9/"*.b
  printf -- '- disposition: repaired\n- edit: prd.md:3\n- derivation: the party round\n' > "$w/$K3PA/s9/requirements-party-repair.md"
fi

# --- K3 WIDENED (K3B_RELEASE): a `<stem>-adversarial-p<M>` series beside a subject manifest ------
#   k3w-post   `prd-adversarial-p1` (a --document prd.md merge) + manifest, post-stamp  FAIL (K3
#   k3w-pre    the same, series opened BEFORE the stamp                                PENDING Legacy
#   k3w-pred   the same, repo stamped only at K3B_RELEASE's predecessor (= K3_RELEASE)  PENDING not owed
#   k3w-nomf   the same pass, NO manifest in the sprint                                SILENT
#   k3w-other  `test-strategy-adversarial-p1` over a file the manifest does not name   SILENT (drops at
#              the artifact test, K3's `k3_names`)
#   k3w-brief  `product-brief-adversarial-p1`, one adversary over the brief (a stem
#              OUTSIDE s<N>, root walk up two levels), + manifest, post-stamp          FAIL (K3
#   k3w-arch   `architecture-impact-adversarial-p1` over a stem INSIDE s<N>, + manifest FAIL (K3
# The new worlds carry their OWN build flag: a world here that fails to build is FIXTURE BROKEN by
# name, and never takes the original K3 cells above down with it.
K3W_BUILT=1; K3W_BAD=""
k3w_bad() { K3W_BUILT=0; K3W_BAD="$K3W_BAD $1"; }
# k3w_single <world> <stem> <file rel> -- one adversary's pass written directly, as a one-part
# reviewer writes it (no merge: these files read SERIAL), the manifest written by the real first map.
k3w_single() {
  AI_DLC_PROJECT_ROOT="$1" bash "$K3S/partition-subject.sh" --map 9 >/dev/null 2>&1
  [ -f "$1/$K3PA/s9/requirements-subject.md" ] || return 1
  k3_shard "$1/$K3PA/s9" "$2-adversarial-p1" x 0 "$3" "$(k3sha "$1/$3")" \
    && sed -i.b "s/^tool_use_id: .*/tool_use_id: toolu_k3$2/" "$1/$K3PA/s9/$2-adversarial-p1.md" && rm -f "$1/$K3PA/s9/"*.b
}
K3_PRED="$(sed -n 's/^K3_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
w="$(k3_world k3w-post "$K3_POST")" && k3_document_pass "$w" "$K3S" keep || k3w_bad k3w-post
w="$(k3_world k3w-pre "$K3_LATE")" && k3_document_pass "$w" "$K3S" keep || k3w_bad k3w-pre
w="$(k3_world k3w-pred "$K3_POST" "" "" "$K3_PRED")" && k3_document_pass "$w" "$K3S" keep || k3w_bad k3w-pred
w="$(k3_world k3w-nomf "$K3_POST")" && k3_document_pass "$w" "$K3S" nomanifest \
  && [ ! -e "$w/$K3PA/s9/requirements-subject.md" ] || k3w_bad k3w-nomf
w="$(k3_world k3w-other "$K3_POST")" && k3_other_pass "$w" "$K3S" || k3w_bad k3w-other
w="$(k3_world k3w-brief "$K3_POST")" && k3w_single "$w" product-brief "$K3PA/product-brief.md" || k3w_bad k3w-brief
w="$(k3_world k3w-arch "$K3_POST")" && k3w_single "$w" architecture-impact "$K3PA/s9/architecture-impact.md" || k3w_bad k3w-arch
# k3w-subj (BL-829): the widened `prd-adversarial-p1` whose artifact IS the subject manifest, so K3's
# terminal pass takes branch (b) -- four notarized stems, shas matching -- and fails its key set
# (k3-wrongset's `1=` -> `99=`, which is not the lone-cross shape, so K3C/K3D never rebind). The repo
# is stamped strictly BETWEEN K3_RELEASE and K3B_RELEASE: branch (b)'s rebind to K3B_RELEASE reads
# PENDING "not owed yet", and dating it against K3_RELEASE convicts. The stamp is derived from the
# validator's own constants and refused unless it separates them.
K3W_MID=""
IFS=. read -r k3m_ma k3m_mi k3m_pa <<EOF
$K3_PRED
EOF
K3W_B="$(sed -n 's/^K3B_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
IFS=. read -r k3b_ma k3b_mi k3b_pa <<EOF
$K3W_B
EOF
if [ -n "$k3m_mi" ] && [ -n "$k3b_mi" ] && [ "$k3m_ma" = "$k3b_ma" ] && [ $((k3m_mi + 1)) -lt "$k3b_mi" ]; then
  K3W_MID="${k3m_ma}.$((k3m_mi + 1)).${k3m_pa}"
fi
w="$(k3_world k3w-subj "$K3_POST" "" "" "$K3W_MID")" && [ -n "$K3W_MID" ] && k3_subject_pass "$w" "$K3S" \
  && awk '/^shard_tool_use_ids:/ { sub(/ 1=/, " 99=") } { print }' "$w/$K3PA/s9/requirements-adversarial-p1.md" > "$w/$K3PA/s9/prd-adversarial-p1.md" \
  && rm "$w/$K3PA/s9/requirements-adversarial-p1.md" \
  && grep -q '^artifact: .*s9/requirements-subject\.md$' "$w/$K3PA/s9/prd-adversarial-p1.md" \
  && grep -q '^shard_tool_use_ids:.* 99=' "$w/$K3PA/s9/prd-adversarial-p1.md" \
  && [ "$(grep -c '^file: ' "$w/$K3PA/s9/requirements-subject.md")" -eq 4 ] || k3w_bad k3w-subj

# --- J2 PER STEM (J2S_RELEASE): a subject stem moved after the requirements series met ---------
# Each world is k3-subject's (a MET `merge --subject` pass notarizing the four stems, so K3 itself is
# silent on the shard set and only its byte gate reads PENDING once a stem moves), then:
#   j2s-nochain   SPEC.md moved, no record; architecture-impact unchanged      FAIL (J2) naming SPEC only
#   j2s-chain     SPEC.md moved twice; link 1 is the THIRD entry of
#                 `requirements-repair-adv-p1.md` (a prd triple and an identity
#                 brief triple before it), link 2 is `requirements-repair-el.md`  SILENT
#   j2s-subjlink  architecture-impact moved (SPEC unchanged) by the serial
#                 remediator; the join's subject-form entry carries it x -> x
#                 and the serial entry x -> y, in `requirements-repair-p1.md`    SILENT (identity dropped)
#   j2s-prd       prd.md moved, no record                                        SILENT (the narrowing)
#   j2s-pre       architecture-impact moved, no record, series opened BEFORE
#                 the stamp                                                       PENDING Legacy
#   j2s-pred      SPEC.md moved, no record, repo stamped only at J2S_RELEASE's
#                 predecessor                                                     PENDING not owed
J2S_PRED="$(sed -n 's/^J2S_RELEASE="\([0-9.]*\)"$/\1/p' "$VALIDATOR")"
IFS=. read -r j2s_ma j2s_mi j2s_pa <<EOF
$J2S_PRED
EOF
J2S_PRED="${j2s_ma}.$((j2s_mi - 1)).${j2s_pa}"
J2S_SPEC=_bmad-output/specs/s9/kernel/SPEC.md
J2S_ARCH=$K3PA/s9/architecture-impact.md
J2S_MF=$K3PA/s9/requirements-subject.md
j2s_world() { # <name> <stamp-date> [stamp-version] -> a world holding a MET subject pass
  local w; w="$(k3_world "$1" "$2" "" "" "${3:-}")" || return 1
  k3_subject_pass "$w" "$K3S" || return 1
  grep -qx 'verdict: EXIT_CONDITION_MET' "$w/$K3PA/s9/requirements-adversarial-p1.md" || return 1
  printf '%s' "$w"
}
# j2s_rec <file> <entry>... ; an entry is `artifact|before|after`, written as the remediator template's
# triple, the three arm-H fields after them.
j2s_rec() {
  local f="$1" e a r b z; shift
  { for e in "$@"; do
      a="${e%%|*}"; r="${e#*|}"; b="${r%%|*}"; z="${r#*|}"
      printf -- '- artifact: %s\n- artifact_sha_before: %s\n- artifact_sha_after: %s\n\n' "$a" "$b" "$z"
    done
    printf -- '- disposition: repaired\n- edit: the subject\n- derivation: the seeded repair, shasum -a 256 each file\n'; } > "$f"
}
j2s_sub() { # <list> <stem> <sha> -> the list with that stem's sha replaced, in the pair's own separator
  local t o=""; for t in $1; do case "$t" in "$2="*) t="$2=$3" ;; "$2@"*) t="$2@$3" ;; esac; o="$o${o:+ }$t"; done; printf '%s' "$o"
}
J2S_FAKE="$(printf '%064d' 7)"
w="$(j2s_world j2s-nochain "$K3_POST")" && printf 'cap-2: THE system SHALL y.\n' >> "$w/$J2S_SPEC" || k3w_bad j2s-nochain
w="$(j2s_world j2s-chain "$K3_POST")" || k3w_bad j2s-chain
if [ "$K3W_BUILT" -eq 1 ]; then
  j2s_n="$(k3sha "$w/$J2S_SPEC")"; printf 'cap-2: THE system SHALL y.\n' >> "$w/$J2S_SPEC"
  j2s_m="$(k3sha "$w/$J2S_SPEC")"; printf 'cap-3: THE system SHALL z.\n' >> "$w/$J2S_SPEC"
  j2s_d="$(k3sha "$w/$J2S_SPEC")"; j2s_b="$(k3sha "$w/$K3PA/product-brief.md")"
  j2s_rec "$w/$K3PA/s9/requirements-repair-adv-p1.md" "$K3PA/prd.md|$(k3sha "$w/$K3PA/prd.md")|$J2S_FAKE" \
    "$K3PA/product-brief.md|$j2s_b|$j2s_b" "$J2S_SPEC|$j2s_n|$j2s_m"
  j2s_rec "$w/$K3PA/s9/requirements-repair-el.md" "$J2S_SPEC|$j2s_m|$j2s_d"
fi
w="$(j2s_world j2s-subjlink "$K3_POST")" || k3w_bad j2s-subjlink
if [ "$K3W_BUILT" -eq 1 ]; then
  j2s_l0="$(sed -n 's/^artifact_sha: //p' "$w/$K3PA/s9/requirements-adversarial-p1.md")"
  j2s_l1="$(j2s_sub "$j2s_l0" prd "$J2S_FAKE")"
  printf -- '- FR-S9-2: architecture_impact: none\n' >> "$w/$J2S_ARCH"
  j2s_l2="$(j2s_sub "$j2s_l1" architecture-impact "$(k3sha "$w/$J2S_ARCH")")"
  j2s_rec "$w/$K3PA/s9/requirements-repair-p1.md" "$J2S_MF|$j2s_l0|$j2s_l1" "$J2S_MF|$j2s_l1|$j2s_l2"
fi
w="$(j2s_world j2s-prd "$K3_POST")" && printf 'moved after MET\n' >> "$w/$K3PA/prd.md" || k3w_bad j2s-prd
w="$(j2s_world j2s-pre "$K3_LATE")" && printf -- '- FR-S9-2: architecture_impact: none\n' >> "$w/$J2S_ARCH" || k3w_bad j2s-pre
w="$(j2s_world j2s-pred "$K3_POST" "$J2S_PRED")" && printf 'cap-2: THE system SHALL y.\n' >> "$w/$J2S_SPEC" || k3w_bad j2s-pred

echo
echo "--- arm K3 (SUBJECT)"
if [ "$K3_BUILT" -ne 1 ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN -- a K3 world did not build (worlds under %s)\n' "k3-worlds" "$K3W"
else
  K3_DOC_FAIL="FAIL (K3 -- SUBJECT): requirements-adversarial-p1.md: it reviews"
  k3_cell k3-subject  "$VALIDATOR" "$K3W/k3-subject"  0 - "K3 -- SUBJECT"
  k3_cell k3-atform   "$VALIDATOR" "$K3W/k3-atform"   0 - "K3 -- SUBJECT"
  k3_cell k3-document "$VALIDATOR" "$K3W/k3-document" 1 "$K3_DOC_FAIL" -
  k3_cell k3-wrongset "$VALIDATOR" "$K3W/k3-wrongset" 1 "is not the subject map's ordinals plus cross" -
  k3_cell k3-serial   "$VALIDATOR" "$K3W/k3-serial"   0 - "K2 -- SECTIONS"
  k3_cell k3-serial-k3 "$VALIDATOR" "$K3W/k3-serial"  0 - "K3 -- SUBJECT): requirements"
  k3_cell k3-pre      "$VALIDATOR" "$K3W/k3-pre"      0 "Legacy series." "FAIL (K3"
  k3_cell k3-moved    "$VALIDATOR" "$K3W/k3-moved"    0 "PENDING (K3 -- SUBJECT)" "FAIL (K3"
  k3_cell k3-pin      "$K3W/k3-pin/scripts/ai-dlc/validate-adversarial-convergence.sh" "$K3W/k3-pin" 0 "has no --scope-ref" "FAIL (K3"
  k3_cell k3-pin-ctl  "$K3W/k3-pinctl/scripts/ai-dlc/validate-adversarial-convergence.sh" "$K3W/k3-pinctl" 1 "asked of the copy in force at" "FALLBACK (K3"
  k3_cell k3-armh     "$VALIDATOR" "$K3W/k3-armh"     1 "no repair" -
  # MUTATION: count-not-identity, and the stamp gate deleted. A copy of the validator's directory
  # with its siblings, and an unmutated control from the same directory scoring all four cells.
  k3_mut_row() { # <validator> -> "<subject> <document> <wrongset> <pre>" rc's (`.` for a cell RSEL skips)
    local r="" c i=0; for c in k3-subject k3-document k3-wrongset k3-pre; do i=$((i + 1)); if ron "$i"; then k3_run "$1" "$K3W/$c"; r="$r $K3_RC"; else r="$r ."; fi; done; printf '%s' "${r# }"; }
  k3_mut() { # <label> <expected row> <old> <new>
    local d; local SEAM_ARMS="K3"; d="$(mktemp -d "$K3W/mut.XXXXXX")"; cp "$K3_REAL"/*.sh "$d/"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [ -n "$3" ]; then
      M_OLD="$3" M_NEW="$4" python3 - "$d/validate-adversarial-convergence.sh" <<'PY' || { FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- anchor not unique\n' "$1"; return; }
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
      cmp -s "$VALIDATOR" "$d/validate-adversarial-convergence.sh" && { FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- byte-identical copy\n' "$1"; return; }
    fi
    local wm; rsel "$2" "0 1 1 0"; wm="$(rmask "$2")"
    got="$(k3_mut_row "$d/validate-adversarial-convergence.sh")"; RSEL=""
    if [ "$got" = "$wm" ]; then printf '  ok    %-28s row [%s]\n' "$1" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s row [%s], want [%s]\n' "$1" "$got" "$2"; fi
  }
  k3_mut "K3X0 control (unmutated)" "0 1 1 0" "" ""
  k3_mut "K3X1 count, not identity" "0 1 0 0" \
    '            if [ "$k3_have" != "$k3_want_s" ]; then' \
    '            if [ "$(printf "%s" "$k3_have" | wc -w)" != "$(printf "%s" "$k3_want_s" | wc -w)" ]; then'
  k3_mut "K3X2 stamp gate deleted" "0 1 1 1" \
    '    elif [[ "$k3_at" < "$k3_stamp" ]]; then' \
    '    elif false; then'
fi

echo
echo "--- arm K3 widened (K3B_RELEASE) and arm J2 per stem (J2S_RELEASE)"
if [ "$K3W_BUILT" -ne 1 ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN -- world(s)%s did not build (under %s)\n' "k3w-worlds" "$K3W_BAD" "$K3W"
else
  # --- K3 widened, J2 per stem: the cells ---------------------------------------------------
  # k3w_run <validator> <world> <series stem> -- the series is named by its own stem, as the
  # post-planning sweep names every `*-adversarial-p*` series in the sprint.
  k3w_cell() { # <label> <validator> <world> <stem> <want rc> <must-say | -> <must-not-say | ->
    ASSERTIONS=$((ASSERTIONS + 1))
    bash "$2" --series "$3/$K3PA/s9/$4-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" > "$K3_OUT" 2>&1; K3_RC=$?
    if [ "$K3_RC" -eq "$5" ] && { [ "$6" = - ] || grep -qF -- "$6" "$K3_OUT"; } && { [ "$7" = - ] || ! grep -qF -- "$7" "$K3_OUT"; }; then
      printf '  ok    %-28s exit=%s %s\n' "$1" "$K3_RC" "${6#-}"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-28s exit=%s want=%s, must say [%s], must not say [%s]\n' "$1" "$K3_RC" "$5" "$6" "$7"
      sed 's/^/          | /' "$K3_OUT"
    fi
  }
  k3w_cell k3w-post  "$VALIDATOR" "$K3W/k3w-post"  prd 1 "FAIL (K3 -- SUBJECT): prd-adversarial-p1.md: it reviews" -
  k3w_cell k3w-brief "$VALIDATOR" "$K3W/k3w-brief" product-brief 1 "FAIL (K3 -- SUBJECT): product-brief-adversarial-p1.md: it reviews" -
  k3w_cell k3w-arch  "$VALIDATOR" "$K3W/k3w-arch"  architecture-impact 1 "FAIL (K3 -- SUBJECT): architecture-impact-adversarial-p1.md: it reviews" -
  k3w_cell k3w-pre   "$VALIDATOR" "$K3W/k3w-pre"   prd 0 "Legacy series." "FAIL (K3"
  k3w_cell k3w-pred  "$VALIDATOR" "$K3W/k3w-pred"  prd 0 "at 0.738.0 or later -- not owed yet." "FAIL (K3"
  k3w_cell k3w-nomf  "$VALIDATOR" "$K3W/k3w-nomf"  prd 0 - "K3 -- SUBJECT"
  k3w_cell k3w-other "$VALIDATOR" "$K3W/k3w-other" test-strategy 0 - "K3 -- SUBJECT"
  k3w_cell k3w-subj  "$VALIDATOR" "$K3W/k3w-subj"  prd 0 "at ${K3W_B} or later -- not owed yet." "FAIL (K3"
  k3w_cell k3w-subj-b "$VALIDATOR" "$K3W/k3w-subj" prd 0 "is not the subject map's ordinals plus cross groups" "FAIL (K3"
  # The FAIL is J2's own, not K3's: K3 reads only PENDING (its byte gate) in every J2S world.
  k3w_cell j2s-nochain  "$VALIDATOR" "$K3W/j2s-nochain"  requirements 1 "SPEC (_bmad-output/specs/s9/kernel/SPEC.md): notarized" "FAIL (K3"
  k3w_cell j2s-nochain-j2 "$VALIDATOR" "$K3W/j2s-nochain" requirements 1 "FAIL (J2 -- DRIFT)" "architecture-impact (_bmad-output"
  k3w_cell j2s-chain    "$VALIDATOR" "$K3W/j2s-chain"    requirements 0 "PENDING (K3 -- SUBJECT)" "J2 -- DRIFT"
  k3w_cell j2s-subjlink "$VALIDATOR" "$K3W/j2s-subjlink" requirements 0 "PENDING (K3 -- SUBJECT)" "J2 -- DRIFT"
  k3w_cell j2s-prd      "$VALIDATOR" "$K3W/j2s-prd"      requirements 0 "PENDING (K3 -- SUBJECT)" "J2 -- DRIFT"
  k3w_cell j2s-pre      "$VALIDATOR" "$K3W/j2s-pre"      requirements 0 "architecture-impact (_bmad-output/planning-artifacts/s9/architecture-impact.md): notarized" "FAIL (J2"
  k3w_cell j2s-pre-legacy "$VALIDATOR" "$K3W/j2s-pre"    requirements 0 "Legacy series." "FAIL ("
  k3w_cell j2s-pred     "$VALIDATOR" "$K3W/j2s-pred"     requirements 0 "stamps .claude/.ai-dlc-version at 0.738.0 or later -- not owed yet." "FAIL (J2"

  # --- the mutants: one row per battery, each cell FAIL | PENDING | SILENT, a copy of the validator's
  # directory (partition-subject.sh beside it, or K3 itself reads no map), an unmutated control first.
  k3w_class() { # <validator> <world> <stem> <arm token> -> FAIL | PENDING | SILENT
    bash "$1" --series "$K3W/$2/$K3PA/s9/$3-adversarial-p" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" ${SEAM_ARMS:+--arms "$SEAM_ARMS"} > "$K3_OUT" 2>&1
    if grep -qF "FAIL ($4" "$K3_OUT"; then printf 'FAIL'
    elif grep -qF "PENDING ($4" "$K3_OUT"; then printf 'PENDING'
    else printf 'SILENT'; fi
  }
  rcell() { local i="$1"; shift; if ron "$i"; then "$@"; else printf '.'; fi; }
  k3w_row() { # <validator> -> the seven K3-widened cells
    # Each world's series is the only one run, so any K3 line in its output is about that series.
    printf '%s %s %s %s %s %s %s' "$(rcell 1 k3w_class "$1" k3w-post prd 'K3 -- SUBJECT')" \
      "$(rcell 2 k3w_class "$1" k3w-pre prd 'K3 -- SUBJECT')" "$(rcell 3 k3w_class "$1" k3w-pred prd 'K3 -- SUBJECT')" \
      "$(rcell 4 k3w_class "$1" k3w-nomf prd 'K3 -- SUBJECT')" "$(rcell 5 k3w_class "$1" k3w-other test-strategy 'K3 -- SUBJECT')" \
      "$(rcell 6 k3w_class "$1" k3w-brief product-brief 'K3 -- SUBJECT')" "$(rcell 7 k3w_class "$1" k3w-arch architecture-impact 'K3 -- SUBJECT')"
  }
  j2s_row() { # <validator> -> the six J2-per-stem cells
    local c r=""
    local i=0
    for c in j2s-nochain j2s-chain j2s-subjlink j2s-prd j2s-pre j2s-pred; do i=$((i + 1)); r="$r $(rcell "$i" k3w_class "$1" "$c" requirements 'J2 -- DRIFT')"; done
    printf '%s' "${r# }"
  }
  rowmut() { # <label> <row fn> <expected row> [<old> <new>]...
    local label="$1" fn="$2" want="$3" d got; local SEAM_ARMS="K3,J2"; shift 3
    d="$(mktemp -d "$K3W/rowmut.XXXXXX")"; cp "$K3_REAL"/*.sh "$d/"; ROWMUT_D="$d"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [ ! -f "$d/partition-subject.sh" ]; then
      FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE BROKEN -- partition-subject.sh is not beside the copy\n' "$label"; return
    fi
    if [ $# -gt 0 ]; then
      if ! python3 - "$d/validate-adversarial-convergence.sh" "$@" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read(); a = sys.argv[2:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(3)
    s = s.replace(a[i], a[i + 1])
open(p, "w", encoding="utf-8").write(s)
PY
      then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- an anchor is not in the validator exactly once\n' "$label"; return; fi
      if cmp -s "$VALIDATOR" "$d/validate-adversarial-convergence.sh" || ! bash -n "$d/validate-adversarial-convergence.sh" 2>/dev/null; then
        FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- the mutation DID NOT APPLY or is not valid shell\n' "$label"; return
      fi
    fi
    local real wm
    case "$fn" in k3w_row) real="$K3W_REAL" ;; j2s_row) real="$J2S_REAL" ;; *) real="$want" ;; esac
    rsel "$want" "$real"; wm="$(rmask "$want")"
    got="$("$fn" "$d/validate-adversarial-convergence.sh")"; ROWMUT_GOT="$got"; RSEL=""
    if [ "$got" = "$wm" ]; then printf '  ok    %-28s row [%s]\n' "$label" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s row [%s], want [%s]\n' "$label" "$got" "$want"; fi
  }
  #                       post    pre     pred    nomf   other  brief  arch
  K3W_REAL="FAIL PENDING PENDING SILENT SILENT FAIL FAIL"
  rowmut "K3WX0 control (unmutated)" k3w_row "$K3W_REAL"
  seam_guard "SEAM-GUARD K3" "K3,J2" k3w_row "$ROWMUT_D/validate-adversarial-convergence.sh"
  # The widened case arm matching nothing: every widened series escapes K3 by its name again.
  rowmut "K3WX1 widened case arm gone" k3w_row "SILENT SILENT SILENT SILENT SILENT SILENT SILENT" \
    '  *-adversarial-p[0-9]*.md)' '  *-adversarial-pNEVER.md)'
  # The artifact test skipped: a sprint's OTHER series beside the manifest is convicted as the subject's.
  rowmut "K3WX2 artifact test skipped" k3w_row "FAIL PENDING PENDING SILENT FAIL FAIL FAIL" \
    'k3_names "$k3_dir" "$k3_wf" || k3_go=0' 'true || k3_go=0'
  # The widened candidate dated against K3_RELEASE: a repo stamped at 0.735.0 convicts retroactively.
  rowmut "K3WX3 widened stamp not rebound" k3w_row "FAIL PENDING FAIL SILENT SILENT FAIL FAIL" \
    'k3_wide=1; k3_rel="$K3B_RELEASE"' 'k3_wide=1; k3_rel="$K3_RELEASE"'
  rowmut "K3WX4 K3B_RELEASE lowered" k3w_row "FAIL PENDING FAIL SILENT SILENT FAIL FAIL" \
    'K3B_RELEASE="0.738.0"' 'K3B_RELEASE="0.735.0"'
  # BL-829: branch (b) -- the terminal pass reviews the subject manifest -- re-binds k3_rel after the
  # key-set miss; dropping ONLY its widened conjunct dates k3w-subj against K3_RELEASE and convicts a
  # repo stamped between the two releases. The line is load-bearing as a whole too: branch (b)'s stem
  # loop reads the manifest with `read -r k3_k k3_st k3_rel`, clobbering the case arm's binding, so a
  # deleted line dates against whatever that loop left (measured: FAIL, killed). This mutant keeps
  # `k3_rel="$K3_RELEASE"` so that it tests the widened rebind and nothing else.
  k3w_subj_row() { k3w_class "$1" k3w-subj prd 'K3 -- SUBJECT'; }
  K3W_B_LINE='k3_rel="$K3_RELEASE"; [ "$k3_wide" -eq 1 ] && k3_rel="$K3B_RELEASE"'
  ROWMUT_GOT=none; rowmut "K3WX6c k3w-subj control" k3w_subj_row "PENDING"; K3W_SUBJ_FIX="$ROWMUT_GOT"
  ROWMUT_GOT=none; rowmut "K3WX6 (b) K3B conjunct dropped" k3w_subj_row "FAIL" "$K3W_B_LINE" 'k3_rel="$K3_RELEASE"'
  K3W_SUBJ_MUT="$ROWMUT_GOT"
  # The mutant APPLIED: the original line is gone from the copy and the kept binding stands alone
  # on its line exactly once; and the world DISCRIMINATES: the two programs give different verdicts.
  ASSERTIONS=$((ASSERTIONS + 1))
  k3w_o="$(grep -cF -- "$K3W_B_LINE" "$ROWMUT_D/validate-adversarial-convergence.sh")" || k3w_o=0
  k3w_r="$(grep -cx -- '[[:space:]]*k3_rel="$K3_RELEASE"' "$ROWMUT_D/validate-adversarial-convergence.sh")" || k3w_r=0
  k3w_v="$(grep -cF -- "$K3W_B_LINE" "$VALIDATOR")" || k3w_v=0
  if [ "$k3w_v" -eq 1 ] && [ "$k3w_o" -eq 0 ] && [ "$k3w_r" -eq 1 ] && [ "$K3W_SUBJ_FIX" = PENDING ] && [ "$K3W_SUBJ_MUT" = FAIL ]; then
    printf '  ok    %-28s line %s->%s, kept binding %s; fix %s, mutant %s\n' "K3WX6 applied, discriminates" "$k3w_v" "$k3w_o" "$k3w_r" "$K3W_SUBJ_FIX" "$K3W_SUBJ_MUT"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s line validator=%s mutant=%s, kept binding %s; fix %s, mutant %s (want 1 0 1 PENDING FAIL)\n' "K3WX6 applied, discriminates" "$k3w_v" "$k3w_o" "$k3w_r" "$K3W_SUBJ_FIX" "$K3W_SUBJ_MUT"
  fi
  # k3_names rooted at the sprint dir, no walk up (self-probe conjunct with it): only a stem the
  # manifest names relative to a root it can no longer find drops out -- every stem, in- or out-of-s<N>.
  rowmut "K3WX5 manifest root not walked" k3w_row "SILENT SILENT SILENT SILENT SILENT SILENT SILENT" \
    '    if [ -n "$first" ] && [ -f "$w/$first" ]; then root="$w"; break; fi' '    root=""; break' \
    'if [ "$k3bp1" -ne 0 ] || [ "$k3bp2" -eq 0 ] || [ "$k3bp3" -ne 0 ]; then' 'if false; then'
  #                       nochain chain   subjlink prd    pre     pred
  J2S_REAL="FAIL SILENT SILENT SILENT PENDING PENDING"
  rowmut "J2SX0 control (unmutated)" j2s_row "$J2S_REAL"
  seam_guard "SEAM-GUARD J2S" "K3,J2" j2s_row "$ROWMUT_D/validate-adversarial-convergence.sh"
  # The per-stem branch gone: the subject manifest's terminal pass is judged by nothing (BL-460).
  rowmut "J2SX1 per-stem branch gone" j2s_row "SILENT SILENT SILENT SILENT SILENT SILENT" \
    '  elif [ -n "$j2_file" ] && [ "${j2_file##*/}" = "requirements-subject.md" ]; then' '  elif false; then'
  # Identity links kept: the join's x -> x beside the serial remediator's x -> y reads as a fork. The
  # links conjunct of the self-probe goes with it (it seeds exactly that x -> x row), or the mutant
  # exits 2 in every moved-stem world and reads as SILENT everywhere.
  rowmut "J2SX2 identity links kept" j2s_row "FAIL SILENT FAIL SILENT PENDING PENDING" \
    '$1 == s && $2 != $3 && !seen' '$1 == s && !seen' \
    '[ "$j2sp3" != "x:y:r1 " ]' 'false'
  # The record glob narrowed to `*-repair-p*.md`: graph's `-repair-adv-p<M>` and `-repair-el` are unread.
  rowmut "J2SX3 record glob narrowed" j2s_row "FAIL FAIL SILENT SILENT PENDING PENDING" \
    '"$j2s_dir"/*repair*.md' '"$j2s_dir"/*-repair-p*.md'
  # The entry reader stopping at the FIRST entry (repair_value's reach), self-probe conjunct with it.
  rowmut "J2SX4 first entry only" j2s_row "FAIL FAIL FAIL SILENT PENDING PENDING" \
    'function flush() { if (a != "") printf' 'function flush() { if (a != "" && !done++) printf' \
    '[ "$j2sp1" != "s/SPEC.md|cc|dd m.md|SPEC=ee prd=ff| 3 " ]' 'false'
  # prd.md judged: the architecture step's legitimate mid-sprint rewrite is convicted.
  rowmut "J2SX5 cumulative stem judged" j2s_row "FAIL SILENT SILENT FAIL PENDING PENDING" \
    '          j2_in_subject "$j2s_root/$j2s_rel" || continue' '          true || continue'
  # The stamp gate deleted: a series opened before the stamp is convicted.
  rowmut "J2SX6 stamp gate deleted" j2s_row "FAIL SILENT SILENT SILENT FAIL PENDING" \
    '          elif [[ "$j2_at" < "$j2_stamp" ]]; then' '          elif false; then'
  rowmut "J2SX7 J2S_RELEASE lowered" j2s_row "FAIL SILENT SILENT SILENT PENDING FAIL" \
    'J2S_RELEASE="0.738.0"' 'J2S_RELEASE="0.735.0"'
fi

# --- ARM K3 CROSS GROUPS (K3C_RELEASE): the want-set's cross half is --cross-groups <K> ---------
# Every world is k3-subject's (a `merge --subject` pass over a 6-part subject, so cross-1..6), then:
#   k3-subject    (above) the grouped shape, post-stamp                        SILENT
#   k3c-old       the pass in the PRE-GROUPS shape (ordinals + one cross), post-stamp, the repo
#                 stamped AT K3C_RELEASE (below K3D, before the lone cross was owed)       FAIL (K3
#   k3c-oldpre    the same, series opened BEFORE the stamp                    PENDING Legacy
#   k3c-oldpred   the same, repo stamped only at K3C_RELEASE's predecessor    PENDING not owed
#   k3c-pinold    installed layout; the copy in force has no --cross-groups,
#                 the pass in the pre-groups shape                            SILENT (want-set {cross})
# K3C_RELEASE is a placeholder the lead sets at cut time, so the rebinding is also scored on a copy
# whose K3C_RELEASE is raised far above the world's 9.0.0 stamp, where only the rebinding separates
# PENDING from FAIL whatever value the lead picks.
K3C_BUILT=1; K3C_BAD=""
k3c_bad() { K3C_BUILT=0; K3C_BAD="$K3C_BAD $1"; }
K3C_REL="$(sed -n 's/^K3C_RELEASE="\([^"]*\)"$/\1/p' "$VALIDATOR")"
IFS=. read -r k3c_ma k3c_mi k3c_pa <<EOF
$K3C_REL
EOF
K3C_PRED="${k3c_ma}.$((k3c_mi - 1)).${k3c_pa}"
[ -n "$K3C_REL" ] || k3c_bad K3C_RELEASE-unreadable
# K3D_RELEASE (BL-811, the lone cross): read here because k3c-old is stamped at its predecessor -- a
# repo stamped at or above K3D_RELEASE acquits the one-cross shape, which is K3D's row below.
K3D_REL="$(sed -n 's/^K3D_RELEASE="\([^"]*\)"$/\1/p' "$VALIDATOR")"
K3D_PRED=""
if [[ "$K3D_REL" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IFS=. read -r k3d_ma k3d_mi k3d_pa <<EOF
$K3D_REL
EOF
  K3D_PRED="${k3d_ma}.$((k3d_mi - 1)).${k3d_pa}"
fi
# k3c-old and k3c-pinold are stamped AT K3C_RELEASE: at or after the cross groups, below any K3D, so
# the one-cross shape is never acquitted by K3D in them (a 9.0.0 stamp would acquit K3CX2's pinold).
w="$(k3_world k3c-old "$K3_POST" "" "" "$K3C_REL")" && k3_subject_pass "$w" "$K3S" && k3_oldshape "$w" || k3c_bad k3c-old
w="$(k3_world k3c-oldpre "$K3_LATE")" && k3_subject_pass "$w" "$K3S" && k3_oldshape "$w" || k3c_bad k3c-oldpre
w="$(k3_world k3c-oldpred "$K3_POST" "" "" "$K3C_PRED")" && k3_subject_pass "$w" "$K3S" && k3_oldshape "$w" || k3c_bad k3c-oldpred
# k3c-pinold: the tracked partitioner at the stamp commit is the real one with --cross-groups
# spelled away (so it predates the groups but still maps a subject); the working copy is the real one.
K3C_STUB="$K3W/stub-xg-scripts"; mkdir -p "$K3C_STUB" && cp "$K3_REAL"/*.sh "$K3C_STUB/" \
  && awk '{ gsub(/cross-groups/, "cross-gXXXXX"); print }' "$K3_REAL/partition-document.sh" > "$K3C_STUB/partition-document.sh" \
  && ! grep -q -- '--cross-groups' "$K3C_STUB/partition-document.sh" && grep -q -- '--scope-ref' "$K3C_STUB/partition-document.sh" || k3c_bad k3c-stub
w="$(k3_world k3c-pinold "$K3_POST" "" "$K3C_STUB" "$K3C_REL")" && cp "$K3_REAL"/*.sh "$w/scripts/ai-dlc/" \
  && k3_subject_pass "$w" "$K3_REAL" && k3_oldshape "$w" || k3c_bad k3c-pinold

echo
echo "--- arm K3 cross groups (K3C_RELEASE ${K3C_REL})"
# THE SHAPE CELL. K3C_RELEASE is written as a placeholder on the branch and stamped with the
# release version by the release commit. An unstamped validator must not ship: this cell FAILS
# until the value is <major>.<minor>.<patch>, so a branch that was never stamped cannot pass the
# gate. There is deliberately no skip for the placeholder -- a skip is how one would ship.
ASSERTIONS=$((ASSERTIONS + 1))
if [[ "$K3C_REL" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf '  ok    %-28s K3C_RELEASE is %s\n' k3c-release-shape "$K3C_REL"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s K3C_RELEASE is [%s], not <major>.<minor>.<patch> -- stamp it with the release version at cut\n' k3c-release-shape "$K3C_REL"
fi
if [ "$K3_BUILT" -ne 1 ] || [ "$K3C_BUILT" -ne 1 ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN -- world(s)%s did not build (under %s)\n' "k3c-worlds" "$K3C_BAD" "$K3W"
else
  # The grouped pass must actually carry the groups, or k3-subject's silence proves nothing here.
  ASSERTIONS=$((ASSERTIONS + 1))
  k3c_ids="$(sed -n 's/^shard_tool_use_ids://p' "$K3W/k3-subject/$K3PA/s9/requirements-adversarial-p1.md")"
  case "$k3c_ids" in
    *" cross-1="*" cross-6="*) printf '  ok    %-28s the merged subject pass carries cross-1..cross-6\n' k3c-shape ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE BROKEN -- k3-subject ids are [%s], not cross-1..6\n' k3c-shape "$k3c_ids" ;;
  esac
  k3_cell k3c-grouped  "$VALIDATOR" "$K3W/k3-subject"  0 - "K3 -- SUBJECT"
  k3_cell k3c-old      "$VALIDATOR" "$K3W/k3c-old"     1 "is not the subject map's ordinals plus cross groups" -
  k3_cell k3c-oldpre   "$VALIDATOR" "$K3W/k3c-oldpre"  0 "Legacy series." "FAIL (K3"
  k3_cell k3c-oldpred  "$VALIDATOR" "$K3W/k3c-oldpred" 0 "at ${K3C_REL} or later -- not owed yet." "FAIL (K3"
  k3_cell k3c-pinold   "$K3W/k3c-pinold/scripts/ai-dlc/validate-adversarial-convergence.sh" "$K3W/k3c-pinold" 0 - "K3 -- SUBJECT"
  k3c_class() { # <validator> <world> -> FAIL | PENDING | SILENT for K3
    k3_run "$1" "$K3W/$2"
    if grep -qF "FAIL (K3" "$K3_OUT"; then printf 'FAIL'
    elif grep -qF "PENDING (K3" "$K3_OUT"; then printf 'PENDING'
    else printf 'SILENT'; fi
  }
  k3c_row() { # <validator> <pin-validator> -> grouped old oldpre oldpred pinold
    printf '%s %s %s %s %s' "$(rcell 1 k3c_class "$1" k3-subject)" "$(rcell 2 k3c_class "$1" k3c-old)" "$(rcell 3 k3c_class "$1" k3c-oldpre)" \
      "$(rcell 4 k3c_class "$1" k3c-oldpred)" "$(rcell 5 k3c_class "$2" k3c-pinold)"
  }
  # k3c_mut <label> <expected row> [<old> <new>]... -- a copy of the scripts dir with the edits applied
  # to the validator, and the SAME copy dropped over k3c-pinold's working validator (its pin is git).
  k3c_mut() {
    local label="$1" want="$2" d got pv; local SEAM_ARMS="K3"; shift 2
    d="$(mktemp -d "$K3W/k3cmut.XXXXXX")"; cp "$K3_REAL"/*.sh "$d/"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [ $# -gt 0 ]; then
      if ! python3 - "$d/validate-adversarial-convergence.sh" "$@" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read(); a = sys.argv[2:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(3)
    s = s.replace(a[i], a[i + 1])
open(p, "w", encoding="utf-8").write(s)
PY
      then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- an anchor is not in the validator exactly once\n' "$label"; return; fi
      if cmp -s "$VALIDATOR" "$d/validate-adversarial-convergence.sh" || ! bash -n "$d/validate-adversarial-convergence.sh" 2>/dev/null; then
        FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- the mutation DID NOT APPLY or is not valid shell\n' "$label"; return
      fi
    fi
    pv="$K3W/k3c-pinold/scripts/ai-dlc/validate-adversarial-convergence.sh"
    cp "$d/validate-adversarial-convergence.sh" "$pv"
    local wm; rsel "$want" "SILENT FAIL PENDING PENDING SILENT"; wm="$(rmask "$want")"
    got="$(k3c_row "$d/validate-adversarial-convergence.sh" "$pv")"; RSEL=""
    cp "$K3_REAL/validate-adversarial-convergence.sh" "$pv"
    if [ "$got" = "$wm" ]; then printf '  ok    %-28s row [%s]\n' "$label" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s row [%s], want [%s]\n' "$label" "$got" "$want"; fi
  }
  #                    grouped old    oldpre  oldpred pinold
  k3c_mut "K3CX0 control (unmutated)"  "SILENT FAIL PENDING PENDING SILENT"
  # The want-set left at {cross}: the grouped pass is convicted and the old shape acquitted.
  k3c_mut "K3CX1 want-set left {cross}" "FAIL SILENT SILENT SILENT SILENT" \
    '              k3_xk="$(k3_xkeys "$AC_T/k3-groups")"' '              k3_xk=cross'
  # The pinned copy's capability ignored (today's groups always): the pre-groups pin is convicted.
  k3c_mut "K3CX2 pin capability ignored" "SILENT FAIL PENDING PENDING FAIL" \
    "          if grep -q -- '--cross-groups' \"\$AC_T/k3/partition-document.sh\"; then" '          if true; then' \
    '            if bash "$AC_T/k3/partition-document.sh" --cross-groups "$k3_k" > "$AC_T/k3-groups" 2>/dev/null; then' \
    '            if bash "$(dirname "$K2_PD")/partition-document.sh" --cross-groups "$k3_k" > "$AC_T/k3-groups" 2>/dev/null; then'
  # The rebinding, scored where only it separates PENDING from FAIL: K3C_RELEASE raised above every
  # world's 9.0.0 stamp. The control first, then the same raise with the rebinding removed.
  k3c_mut "K3CX3 control, K3C raised" "SILENT PENDING PENDING PENDING SILENT" \
    "K3C_RELEASE=\"${K3C_REL}\"" 'K3C_RELEASE="99.0.0"'
  # Unrebound, oldpred is dated against K3_RELEASE: FAIL iff its stamp (K3C_RELEASE's predecessor,
  # whatever the lead cut) is at or above K3_RELEASE. Computed, so the row holds for any cut value.
  k3c_pc="$(printf '%s\n' 'C 2026-01-01T00:00:00Z' "+version: ${K3C_PRED}" | awk -v rel="$K3_PRED" '
    /^\+version:/ { v = $2; split(v, x, "."); split(rel, y, "."); r = 1
      for (i = 1; i <= 3; i++) { if ((x[i] + 0) > (y[i] + 0)) { r = 1; break } if ((x[i] + 0) < (y[i] + 0)) { r = 0; break } }
      print (r ? "FAIL" : "PENDING") }')"
  k3c_mut "K3CX4 K3C stamp not rebound" "SILENT FAIL PENDING ${k3c_pc} SILENT" \
    "K3C_RELEASE=\"${K3C_REL}\"" 'K3C_RELEASE="99.0.0"' \
    'then k3_rel="$K3C_RELEASE"; k3_stamp_probe; fi' 'then :; fi'
fi

# --- ARM K3 LONE CROSS (K3D_RELEASE, BL-811): ordinals + ONE cross, written by the REAL merge --------
#   k3d-lone      a lone cross.md merged --subject, repo stamped 9.0.0, series opened after     SILENT
#   k3d-lonepred  the same pass, repo stamped only at K3D_RELEASE's predecessor            FAIL (K3, the old verdict
#   k3d-lonepre   the same pass, series opened BEFORE the 9.0.0 stamp                      PENDING Legacy, the old verdict
# K3D_RELEASE is a placeholder on the branch, stamped at cut: the shape cell FAILS until then, as K3C's did.
K3D_BUILT=1; K3D_BAD=""
k3d_bad() { K3D_BUILT=0; K3D_BAD="$K3D_BAD $1"; }
[ "$K3C_BUILT" -eq 1 ] || k3d_bad K3C-worlds   # k3c_class, which the rows below read, is K3C's
[ -n "$K3D_PRED" ] || k3d_bad K3D_RELEASE-unstamped
w="$(k3_world k3d-lone "$K3_POST")" && k3_subject_pass "$w" "$K3S" lone || k3d_bad k3d-lone
w="$(k3_world k3d-lonepred "$K3_POST" "" "" "${K3D_PRED:-0.0.0}")" && k3_subject_pass "$w" "$K3S" lone || k3d_bad k3d-lonepred
w="$(k3_world k3d-lonepre "$K3_LATE")" && k3_subject_pass "$w" "$K3S" lone || k3d_bad k3d-lonepre
echo
echo "--- arm K3 lone cross (K3D_RELEASE ${K3D_REL})"
# The same shape cell K3C_RELEASE carries above (k3c-release-shape), with its predicate held in one
# function and probed BOTH ways first: the placeholder must read red and a stamped value green, so a
# cell that could never fail (or never pass) is caught before it judges the real value.
k3d_rel_ok() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
ASSERTIONS=$((ASSERTIONS + 1))
if ! k3d_rel_ok "0.0.0-CUT" && k3d_rel_ok "0.950.0"; then
  printf '  ok    %-28s the shape cell reads the placeholder 0.0.0-CUT red and a stamped 0.950.0 green\n' k3d-release-probe
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN -- the shape cell does not separate 0.0.0-CUT from a stamped release\n' k3d-release-probe
fi
ASSERTIONS=$((ASSERTIONS + 1))
if k3d_rel_ok "$K3D_REL"; then
  printf '  ok    %-28s K3D_RELEASE is %s\n' k3d-release-shape "$K3D_REL"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s K3D_RELEASE is [%s], not <major>.<minor>.<patch> -- stamp it with the release version at cut\n' k3d-release-shape "$K3D_REL"
fi
if [ "$K3_BUILT" -ne 1 ] || [ "$K3D_BUILT" -ne 1 ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN -- world(s)%s did not build (under %s)\n' "k3d-worlds" "$K3D_BAD" "$K3W"
else
  # The lone pass must carry exactly one `cross=` id and no group id, or its cells prove nothing.
  ASSERTIONS=$((ASSERTIONS + 1))
  k3d_ids="$(sed -n 's/^shard_tool_use_ids://p' "$K3W/k3d-lone/$K3PA/s9/requirements-adversarial-p1.md")"
  case "$k3d_ids" in
    *" cross-"*|"") FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE BROKEN -- k3d-lone ids are [%s], not ordinals + one cross\n' k3d-shape "$k3d_ids" ;;
    *" cross="*) printf '  ok    %-28s the merged lone pass carries one cross= id and no group id\n' k3d-shape ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE BROKEN -- k3d-lone ids are [%s]\n' k3d-shape "$k3d_ids" ;;
  esac
  k3_cell k3d-lone      "$VALIDATOR" "$K3W/k3d-lone"     0 - "K3 -- SUBJECT"
  k3_cell k3d-lonepred  "$VALIDATOR" "$K3W/k3d-lonepred" 1 "is not the subject map's ordinals plus cross groups" -
  k3_cell k3d-lonepre   "$VALIDATOR" "$K3W/k3d-lonepre"  0 "Legacy series." "FAIL (K3"
  k3d_row() { # <validator> -> lone lonepred lonepre grouped
    printf '%s %s %s %s' "$(rcell 1 k3c_class "$1" k3d-lone)" "$(rcell 2 k3c_class "$1" k3d-lonepred)" "$(rcell 3 k3c_class "$1" k3d-lonepre)" "$(rcell 4 k3c_class "$1" k3-subject)"
  }
  k3d_mut() { # <label> <expected row> [<old> <new>]...
    local label="$1" want="$2" d got; local SEAM_ARMS="K3"; shift 2
    d="$(mktemp -d "$K3W/k3dmut.XXXXXX")"; cp "$K3_REAL"/*.sh "$d/"
    ASSERTIONS=$((ASSERTIONS + 1))
    if [ $# -gt 0 ]; then
      if ! python3 - "$d/validate-adversarial-convergence.sh" "$@" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read(); a = sys.argv[2:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(3)
    s = s.replace(a[i], a[i + 1])
open(p, "w", encoding="utf-8").write(s)
PY
      then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- an anchor is not in the validator exactly once\n' "$label"; return; fi
      if cmp -s "$VALIDATOR" "$d/validate-adversarial-convergence.sh" || ! bash -n "$d/validate-adversarial-convergence.sh" 2>/dev/null; then
        FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- the mutation DID NOT APPLY or is not valid shell\n' "$label"; return
      fi
    fi
    local wm; rsel "$want" "SILENT FAIL PENDING SILENT"; wm="$(rmask "$want")"
    got="$(k3d_row "$d/validate-adversarial-convergence.sh")"; RSEL=""
    if [ "$got" = "$wm" ]; then printf '  ok    %-28s row [%s]\n' "$label" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s row [%s], want [%s]\n' "$label" "$got" "$want"; fi
  }
  #                                   lone   lonepred lonepre grouped
  k3d_mut "K3DX0 control (unmutated)" "SILENT FAIL PENDING SILENT"
  # m-k2only: the lone-cross acquittal removed (the pre-BL-811 rule), so the post-stamp lone pass is convicted.
  k3d_mut "m-k2only (K3D acquittal off)" "FAIL FAIL PENDING SILENT" \
    'k3_opened_after && k3_dok=1; fi' 'false && k3_dok=1; fi'
  # The gate read: K3D_RELEASE raised above every world's stamp, so no series is after it -- the old verdict everywhere.
  k3d_mut "K3DX2 K3D raised to 99.0.0" "FAIL FAIL PENDING SILENT" \
    "K3D_RELEASE=\"${K3D_REL}\"" 'K3D_RELEASE="99.0.0"'
  # The acquittal widened to every date: the before-stamp series is acquitted too, so the old verdicts go.
  k3d_mut "K3DX3 date rule dropped" "SILENT SILENT SILENT SILENT" \
    'k3_opened_after && k3_dok=1; fi' 'k3_dok=1; fi'
fi

fi
if sg elic; then
echo
# --- ARM L: the stories elicitation, driven END TO END ------------------------------------------
# The validator's self-probe covers l_judge, l_records, l_kparse and the stamp parser on staged
# inputs; nothing there runs the LIVE path -- the staged `merge-adversarial-shards.sh --map` call
# (a shards/stories-p1/ beside a symlink to the real stories/), the `$1 + 0` de-padding, the
# intensity lookup, the era branches and the err text. Every world below is a sprint s9 with a MET,
# shard-merged `stories-adversarial-p1.md` (K is silent on it), run through the real validator.
# Built under $ROOT/.l-worlds, a hidden dir, so the pairing loop's `$ROOT/*/` never walks it.
# Stamp history, where a world has one: 0.781.0 at L_T0, 0.782.0 (L_RELEASE) at L_T1; every file is
# in the second commit, so a shallow clone carries the sprint.
#   l-pass     K=10, 01..10 + cross-1..6, post                      OK PASS, exit 0 (K=10, because
#              --map pads to the digit count of K: only a two-digit K prints `01`, so only it
#              can tell the `$1 + 0` de-padding from its absence; the complete per-group set)
#   l-voice    K=3, one stories-elicitation.md record, post         FAIL (a), exit 1
#   l-legacy   K=3, 01..03 + cross.md, post                         OK PASS: ONE cross shard is the rule
#   l-full7    K=7, 01..07 + cross-1..6 (G=6), post                 OK PASS: the complete set still accepted
#   l-part7    K=7, 01..07 + cross-1..3 only, post                  FAIL (c), never (d): the control
#   l-dx       l-grow2's base + a delta-k3 of story-3.md + cross.md OK PASS: the delta owes one cross.md
#   l-dxno     l-dx without the delta's cross.md                    FAIL (c) delta cross shard missing
#   l-absent   full, no record, no dir; dated by the first pass     FAIL (e)
#   l-std      intensity standard, nothing elicited                 OK NOT-OWED
#   l-pre      l-voice dated between the two stamps                 PENDING, legal in its era
#   l-pred     l-voice, the repo stamped only at 0.781.0            PENDING, not owed yet
#   l-nogit    l-voice copied out of git                            PENDING era unknown -- no git
#   l-shallow  l-voice cloned --depth 1                             PENDING era unknown -- shallow clone
#   l-undated  l-voice whose record carries no invoked_at           PENDING era unknown -- undated
#   l-nostamp  l-voice with no .claude/.ai-dlc-version anywhere     PENDING era unknown -- stamp absent
#   l-moved    shards record K=5 and hold the complete 5-set; stories/ now 3      PENDING, named
#   l-under    shards record K=5 and hold 01..03 + cross-1..3; stories/ now 3     FAIL, 4.md 5.md
#   l-match    shards record K=3, the complete 3-set (the near-miss of the two)   OK PASS
#   l-kdis     shard headers record K=3 and K=4                                    FAIL (f)
#   l-eqshort  shards record K=3 (equality) and hold 01, 02, cross-1; stories/ 3    FAIL (b)+(c), the
#              plain today's-K text, no `shards record` suffix -- nothing moves at equality
#   l-grow     ONE file, 01.md carrying `shard: 1/1 stories`; stories/ 3            FAIL (b)+(c), never PENDING
#   l-grow2    shards record K=2, the complete 2-set (01, 02, cross.md); stories/ 3 FAIL (b) 3.md only, never PENDING
#   l-replace  shards record K=5 over story-1..5, complete; stories/ now story-1..3 + story-new
#              (shrink WITH replacement)                                             FAIL, names story-new
#   l-replace1 l-moved's covering names, one current story renamed 3 -> 8           FAIL, names story-8
#   l-foreign  K_rec 5 complete; today story-1, story-2, story-new; story-new named only under s8/
#              (one sprint off, same basename), story-2 only by a RELATIVE s9 ordinal   FAIL, names story-new only
# The recorded-K worlds' shard files are written in s317's real layout (l_rshards).
# In every recorded-K world 01.md carries NO shard line, as the reference consumer's 01.md does
# not: a reader of the first file alone reads no K and judges l-moved as today, which FAILs it.
LW="$ROOT/.l-worlds"
mkdir -p "$LW" || broken "cannot create $LW"
LWP="$(cd "$LW" && pwd -P)"
L_T0=2026-10-01T00:00:00Z; L_T1=2026-10-05T00:00:00Z
L_POST=2026-10-06T00:00:00Z; L_PRE=2026-10-03T00:00:00Z
LS="$(cd "$(dirname "$VALIDATOR")" && pwd)"
lg() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
l_prov() { # <file> <invoked_at | ""> <shard line | ""> -- one elicitation record, the shipped block shape
  { printf '# Stories elicitation\n\n'
    if [ -n "$3" ]; then printf '%s\n\n' "$3"; fi
    printf 'Findings: 0 critical, 0 major, 0 minor.\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-advanced-elicitation\n'
    if [ -n "$2" ]; then printf 'invoked_at: %s\n' "$2"; fi
    printf 'tool_use_id: NOT_ACCESSIBLE\nmode: subagent\nlead_role: stories\nartifact: s9/stories/\n'
    printf 'findings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$1"
}
l_world() { # <name> <K> <intensity> -- stories, the status file and a MET shard-merged pass
  local w="$LW/$1" i
  mkdir -p "$w/.claude" "$w/s9/stories" || return 1
  for i in $(seq 1 "$2"); do printf '# Story %s\n\nAs the operator, I want %s.\n' "$i" "$i" > "$w/s9/stories/story-$i.md" || return 1; done
  printf 'sprint: 9\nvalidation_intensity: %s\n' "$3" > "$w/s9/sprint-status.yaml"
  { printf '# stories -- adversarial pass 1\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n'
    printf 'invoked_at: 2026-10-07T00:00:00Z\ntool_use_id: toolu_fixture_l1\n'
    printf 'shard_tool_use_ids: 1=toolu_fixture_l1a 2=toolu_fixture_l1b cross=toolu_fixture_l1x\n'
    printf 'mode: subagent\nlead_role: architect\nartifact: stories/\nfindings_critical: 0\nfindings_critical_prior_scope: 0\n'
    printf 'findings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\nverdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$w/s9/stories-adversarial-p1.md"
}
l_shards() { # <name> <invoked_at> <recorded K | ""> <name.md>... -- the first file named is always bare
  local d="$LW/$1/s9/shards/stories-elicitation" at="$2" k="$3" n s first=1; shift 3
  mkdir -p "$d" || return 1
  for n in "$@"; do
    s=""
    if [ -n "$k" ] && [ "$first" -eq 0 ]; then
      case "$n" in cross*) s="shard: cross/$k ${n%.md}" ;; *) s="shard: ${n%.md}/$k story-${n%.md}" ;; esac
    fi
    first=0
    l_prov "$d/$n" "$at" "$s" || return 1
  done
}
# l_rshards <world> <invoked_at> <K> bare|all <"elicited names"> <name.md>... -- shard files in the
# EXACT layout the reference consumer's s317 elicitation wrote (03.md and cross.md, read-only):
# the block first, `invoked_at:` on line 3, `artifact:` on 7 and `artifact_sha:` on 8, then a title and
# `shard:` at column 0 in the body. An ordinal shard names its story by ABSOLUTE file path and one sha;
# a cross shard names the stories dir RELATIVELY and one `<name>=<sha>` per elicited story, on one
# line. Ordinal NN reviews the NNth elicited name. `bare`: the first file carries no shard line, as
# s317's 01.md carries none.
l_rshards() {
  local w="$1" at="$2" k="$3" mode="$4" names="$5" d n o nm sl i first=1 shas=""; shift 5
  d="$LW/$w/s9/shards/stories-elicitation"
  mkdir -p "$d" || return 1
  i=0; for nm in $names; do i=$((i + 1)); shas="$shas${shas:+ }$nm=$(printf '%064d' "$i")"; done
  for n in "$@"; do
    sl="shard: cross/$k cross"
    case "$n" in
      cross*) { printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-advanced-elicitation\ninvoked_at: %s\n' "$at"
                printf 'tool_use_id: NOT_ACCESSIBLE\nmode: subagent\nlead_role: stories-test-strategy.md\nartifact: s9/stories/\n'
                printf 'artifact_sha: %s\nfindings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n\n' "$shas"
                printf '# Sprint 9 stories: advanced elicitation, cross shard\n\n'; } > "$d/$n" || return 1 ;;
      *) o="${n%.md}"; i=0; nm=""
         for nm in $names; do i=$((i + 1)); [ "$i" -eq "$((10#$o))" ] && break; done
         sl="shard: $o/$k $nm"
         { printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-advanced-elicitation\ninvoked_at: %s\n' "$at"
           printf 'tool_use_id: toolu_unknown_dispatch_id_not_visible_to_subagent\nmode: subagent\nlead_role: stories.md\n'
           printf 'artifact: %s/%s/s9/stories/%s.md\nartifact_sha: %064d\n' "$LWP" "$w" "$nm" "$((10#$o))"
           printf 'findings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n\n'
           printf '# Stories elicitation, shard %s/%s: %s.md\n\n' "$o" "$k" "$nm"; } > "$d/$n" || return 1 ;;
    esac
    if [ "$mode" = all ] || [ "$first" -eq 0 ]; then printf '%s\n' "$sl" >> "$d/$n" || return 1; fi
    printf '\nFindings: 0 critical, 0 major, 0 minor.\n' >> "$d/$n" || return 1
    first=0
  done
}
l_git() { # <name> two|pred|none|nostamp -- the stamp history, every file in the last commit
  local w="$LW/$1"
  case "$2" in
    none) printf 'version: 0.782.0\n' > "$w/.claude/.ai-dlc-version" ;;
    nostamp) rm -rf "$w/.claude" ;;
    two|pred)
      printf 'version: 0.781.0\n' > "$w/.claude/.ai-dlc-version" || return 1
      ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
        lg "$w" init -q . && lg "$w" add -A \
          && GIT_COMMITTER_DATE="$L_T0" GIT_AUTHOR_DATE="$L_T0" lg "$w" commit -q -m stamp-0.781.0 || exit 1
        [ "$2" = pred ] && exit 0
        printf 'version: 0.782.0\n' > "$w/.claude/.ai-dlc-version" && lg "$w" add -A \
          && GIT_COMMITTER_DATE="$L_T1" GIT_AUTHOR_DATE="$L_T1" lg "$w" commit -q -m stamp-0.782.0 ) >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}
L_SET3="01.md 02.md 03.md cross-1.md cross-2.md cross-3.md"
L_SET10="01.md 02.md 03.md 04.md 05.md 06.md 07.md 08.md 09.md 10.md cross-1.md cross-2.md cross-3.md cross-4.md cross-5.md cross-6.md"
L_SET5="01.md 02.md 03.md 04.md 05.md cross-1.md cross-2.md cross-3.md cross-4.md cross-5.md cross-6.md"
L_ORD7="01.md 02.md 03.md 04.md 05.md 06.md 07.md"
L_BUILT=1; L_BAD=""
l_bad() { L_BUILT=0; L_BAD="$L_BAD $1"; }
# shellcheck disable=SC2086 -- the sets are word lists by design
{ l_world l-pass 10 full && l_shards l-pass "$L_POST" "" $L_SET10 && l_git l-pass two; } || l_bad l-pass
# `|`-separated: an ISO time carries colons.
for v in "voice|$L_POST|two" "pre|$L_PRE|two" "pred|$L_POST|pred" "undated||two" "nostamp|$L_POST|nostamp"; do
  n="${v%%|*}"; r="${v#*|}"; at="${r%%|*}"; gm="${r#*|}"
  { l_world "l-$n" 3 full && l_prov "$LW/l-$n/s9/stories-elicitation.md" "$at" "" && l_git "l-$n" "$gm"; } || l_bad "l-$n"
done
{ l_world l-legacy 3 full && l_shards l-legacy "$L_POST" "" 01.md 02.md 03.md cross.md && l_git l-legacy two; } || l_bad l-legacy
{ l_world l-full7 7 full && l_shards l-full7 "$L_POST" "" $L_ORD7 cross-1.md cross-2.md cross-3.md cross-4.md cross-5.md cross-6.md \
    && l_git l-full7 two; } || l_bad l-full7
{ l_world l-part7 7 full && l_shards l-part7 "$L_POST" "" $L_ORD7 cross-1.md cross-2.md cross-3.md && l_git l-part7 two; } || l_bad l-part7
{ l_world l-absent 3 full && l_git l-absent two; } || l_bad l-absent
{ l_world l-std 3 standard && l_git l-std none; } || l_bad l-std
# l_reline <file> <exact old line> <new line> -- one whole-line rewrite, refused unless it applied.
l_reline() {
  awk -v o="$2" -v n="$3" '$0 == o { print n; c++; next } { print } END { exit (c == 1 ? 0 : 1) }' "$1" > "$1.n" \
    && mv "$1.n" "$1" && grep -qxF -- "$3" "$1"
}
L_N5="story-1 story-2 story-3 story-4 story-5"
L_ED=s9/shards/stories-elicitation
# l-moved's 02.md takes the RELATIVE `artifact:` form s317's 04, 13 and 18 write.
{ l_world l-moved 3 full && l_rshards l-moved "$L_POST" 5 bare "$L_N5" $L_SET5 \
    && l_reline "$LW/l-moved/$L_ED/02.md" "artifact: $LWP/l-moved/s9/stories/story-2.md" \
         "artifact: _bmad-output/planning-artifacts/s9/stories/story-2.md" && l_git l-moved two; } || l_bad l-moved
# l-foreign: K_rec 5 complete over story-1, story-2, story-new, story-4, story-5; today story-1, story-2,
# story-new. story-new is named ONLY by sprint s8 -- ONE off the world's s9, the SAME basename, so only
# the sprint scope separates them: ordinal 03 by the ABSOLUTE `.../s8/stories/story-new.md`, every cross
# shard by the RELATIVE `.../s8/stories/` dir. story-2 is named only by a RELATIVE s9 ordinal, so a
# reader that refused the relative form names story-2 too.
l_fx=1
{ l_world l-foreign 2 full && printf '# Story new\n' > "$LW/l-foreign/s9/stories/story-new.md" \
    && l_rshards l-foreign "$L_POST" 5 bare "story-1 story-2 story-new story-4 story-5" $L_SET5 \
    && l_reline "$LW/l-foreign/$L_ED/03.md" "artifact: $LWP/l-foreign/s9/stories/story-new.md" \
         "artifact: $LWP/l-foreign/s8/stories/story-new.md" \
    && l_reline "$LW/l-foreign/$L_ED/02.md" "artifact: $LWP/l-foreign/s9/stories/story-2.md" \
         "artifact: _bmad-output/planning-artifacts/s9/stories/story-2.md" && l_git l-foreign two; } || l_fx=0
for x in 1 2 3 4 5 6; do
  l_reline "$LW/l-foreign/$L_ED/cross-$x.md" "artifact: s9/stories/" "artifact: _bmad-output/planning-artifacts/s8/stories/" || l_fx=0
done
[ "$l_fx" -eq 1 ] || l_bad l-foreign
{ l_world l-under 3 full && l_rshards l-under "$L_POST" 5 bare "$L_N5" $L_SET3 && l_git l-under two; } || l_bad l-under
# l-replace: elicited story-1..5 complete at K=5; a repair deleted 4 and 5 and ADDED story-new (K=4).
{ l_world l-replace 3 full && printf '# Story new\n' > "$LW/l-replace/s9/stories/story-new.md" \
    && l_rshards l-replace "$L_POST" 5 bare "$L_N5" $L_SET5 && l_git l-replace two; } || l_bad l-replace
# l-replace1: l-moved's covering world with one current story renamed by ONE character (3 -> 8).
{ l_world l-replace1 3 full && mv "$LW/l-replace1/s9/stories/story-3.md" "$LW/l-replace1/s9/stories/story-8.md" \
    && l_rshards l-replace1 "$L_POST" 5 bare "$L_N5" $L_SET5 && l_git l-replace1 two; } || l_bad l-replace1
# l-match in s317's layout, naming story-1..3: its subjects COVER today's stories, so under an
# equality-honouring mutant (LX7) nothing but the direction test keeps it from reading PENDING.
{ l_world l-match 3 full && l_rshards l-match "$L_POST" 3 bare "story-1 story-2 story-3" $L_SET3 && l_git l-match none; } || l_bad l-match
{ l_world l-kdis 3 full && l_shards l-kdis "$L_POST" 3 $L_SET3 \
    && l_prov "$LW/l-kdis/s9/shards/stories-elicitation/03.md" "$L_POST" "shard: 03/4 story-03" && l_git l-kdis two; } || l_bad l-kdis
L_N3="story-1 story-2 story-3"
{ l_world l-eqshort 3 full && l_rshards l-eqshort "$L_POST" 3 bare "$L_N3" 01.md 02.md cross-1.md && l_git l-eqshort two; } || l_bad l-eqshort
# l-grow: ONE voice over the whole stories dir, so it is written as the dir-naming (cross) form with
# every story's name=sha -- its subjects COVER today's stories, and only the direction refuses it.
{ l_world l-grow 3 full && l_rshards l-grow "$L_POST" 1 all "$L_N3" cross.md \
    && mv "$LW/l-grow/s9/shards/stories-elicitation/cross.md" "$LW/l-grow/s9/shards/stories-elicitation/01.md" \
    && sed 's#^shard: cross/1 cross$#shard: 1/1 stories#' "$LW/l-grow/s9/shards/stories-elicitation/01.md" > "$LW/l-grow/01.n" \
    && mv "$LW/l-grow/01.n" "$LW/l-grow/s9/shards/stories-elicitation/01.md" \
    && grep -qx 'shard: 1/1 stories' "$LW/l-grow/s9/shards/stories-elicitation/01.md" && l_git l-grow two; } || l_bad l-grow
{ l_world l-grow2 3 full && l_rshards l-grow2 "$L_POST" 2 bare "story-1 story-2" 01.md 02.md cross.md && l_git l-grow2 two; } || l_bad l-grow2
# l-dx / l-dxno: l-grow2's base, plus the delta-k3 it owes (story-3 and the cross part), in s317's layout.
l_dshard() { # <world> <file> <story | cross>
  local d="$LW/$1/s9/shards/stories-elicitation-delta-k3"
  mkdir -p "$d" || return 1
  { printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-advanced-elicitation\ninvoked_at: %s\n' "$L_POST"
    printf 'tool_use_id: NOT_ACCESSIBLE\nmode: subagent\nlead_role: stories.md\n'
    if [ "$3" = cross ]; then printf 'artifact: s9/stories/\nartifact_sha: story-1=%064d story-2=%064d story-3=%064d\n' 1 2 3
    else printf 'artifact: %s/%s/s9/stories/%s.md\nartifact_sha: %064d\n' "$LWP" "$1" "$3" 3; fi
    printf 'findings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n\n'
    if [ "$3" = cross ]; then printf 'shard: cross/3 cross\n'; else printf 'shard: 03/3 %s\n' "$3"; fi
    printf '\nFindings: 0 critical, 0 major, 0 minor.\n'; } > "$d/$2"
}
for w in l-dx l-dxno; do
  { l_world "$w" 3 full && l_rshards "$w" "$L_POST" 2 bare "story-1 story-2" 01.md 02.md cross.md \
      && l_dshard "$w" story-3.md story-3 && { [ "$w" = l-dxno ] || l_dshard "$w" cross.md cross; } \
      && l_git "$w" two; } || l_bad "$w"
done
{ cp -R "$LW/l-voice" "$LW/l-nogit" && rm -rf "$LW/l-nogit/.git"; } || l_bad l-nogit
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git clone -q --depth 1 "file://$LWP/l-voice" "$LW/l-shallow" ) >/dev/null 2>&1 \
  && [ -f "$LW/l-shallow/s9/stories-elicitation.md" ] || l_bad l-shallow
# THE WORLDS ARE WHAT THEY CLAIM: the recorded-K worlds carry the K on every file but the first,
# the first carries none, and the shallow clone is shallow and holds the sprint.
if [ "$L_BUILT" -eq 1 ]; then
  [ "$(grep -l '^shard: .*/5 ' "$LW/l-moved/s9/shards/stories-elicitation/"*.md | grep -c .)" = 10 ] \
    && ! grep -q '^shard:' "$LW/l-moved/s9/shards/stories-elicitation/01.md" || l_bad l-moved-headers
  [ "$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git -C "$LW/l-shallow" rev-parse --is-shallow-repository ) 2>/dev/null)" = true ] || l_bad l-shallow-not-shallow
fi
L_OUT="$LW/out"
l_run() { # <validator> <world> -> L_RC, $L_OUT. The ceiling keeps git from answering for an ancestor.
  GIT_CEILING_DIRECTORIES="$LWP" bash "$1" --series "$LW/$2/s9/stories-adversarial-p" \
    --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" ${SEAM_ARMS:+--arms "$SEAM_ARMS"} > "$L_OUT" 2>&1; L_RC=$?
}
l_cell() { # <world> <want rc> <must-not-say | -> <must-say>...
  local w="$1" want="$2" not="$3" s miss=""; shift 3
  ASSERTIONS=$((ASSERTIONS + 1))
  l_run "$VALIDATOR" "$w"
  for s in "$@"; do grep -qF -- "$s" "$L_OUT" || miss="$miss [$s]"; done
  if [ "$L_RC" -eq "$want" ] && [ -z "$miss" ] && { [ "$not" = - ] || ! grep -qF -- "$not" "$L_OUT"; }; then
    printf '  ok    %-28s exit=%s %s\n' "$w" "$L_RC" "$1"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s exit=%s want=%s, missing:%s, must not say [%s]\n' "$w" "$L_RC" "$want" "${miss:- none}" "$not"
    sed 's/^/          | /' "$L_OUT"
  fi
}
echo "--- arm L (ELICITATION), end to end"
if [ "$L_BUILT" -ne 1 ]; then
  FAILURES=$((FAILURES + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  printf '  FAIL  %-28s FIXTURE BROKEN -- world(s)%s did not build (under %s)\n' "l-worlds" "$L_BAD" "$LW"
else
  L_FL="FAIL (L -- ELICITATION)"
  l_cell l-pass    0 "$L_FL" "OK (L -- ELICITATION): stories-adversarial-p1.md: s9 PASS -- shards/stories-elicitation/ holds exactly the owed set (10 stories, intensity full from"
  # No shard dir at all: nothing to top up, so the remedy is the FULL re-run and never the delta.
  l_cell l-voice   1 "ONLY THE DELTA" "FAIL (L -- ELICITATION): s9's stories elicitation over 3 stories is not the sharded shape: (a) single voice" \
    "after 0.782.0 was stamped (2026-10-05T00:00:00Z)" \
    "No shard dir complete for its own K exists to top up with a delta," "so re-run the elicitation in that shape before this gate."
  # ONE cross shard over every ordinal is the rule (BL-811); the complete per-group set is still
  # accepted (l-pass, l-full7), and a PARTIAL per-group set is (c), never (d) and never a PASS.
  l_cell l-legacy  0 "$L_FL" "OK (L -- ELICITATION): stories-adversarial-p1.md: s9 PASS -- shards/stories-elicitation/ holds exactly the owed set (3 stories"
  l_cell l-full7   0 "$L_FL" "OK (L -- ELICITATION): stories-adversarial-p1.md: s9 PASS -- shards/stories-elicitation/ holds exactly the owed set (7 stories"
  l_cell l-part7   1 "(d) wrong names" "$L_FL" \
    "(c) cross shards short: 3 cross shard(s) where G=6 are owed (owed: cross.md, or all of cross-1.md cross-2.md cross-3.md cross-4.md cross-5.md cross-6.md)"
  l_cell l-dx      0 "$L_FL" "OK (L -- ELICITATION): stories-adversarial-p1.md: s9 PASS -- shards/stories-elicitation/ is complete for its K=2 and shards/stories-elicitation-delta-k3/ holds exactly the delta owed (stories: story-3; cross: cross.md (or all of cross-2 cross-3))"
  l_cell l-dxno    1 "OK (L" "$L_FL" \
    "(c) delta cross shard missing: cross.md (or every owed group: cross-2.md cross-3.md; missing: cross-2.md cross-3.md)"
  l_cell l-absent  1 - "$L_FL" "(e) owed-absent" "(the series' first pass stories-adversarial-p1.md)"
  l_cell l-std     0 "$L_FL" "OK (L -- ELICITATION): stories-adversarial-p1.md: s9 NOT-OWED -- validation_intensity is standard"
  l_cell l-pre     0 "$L_FL" "PENDING (L -- ELICITATION): stories-adversarial-p1.md: s9: (a) single voice" \
    "before 0.782.0 was stamped (2026-10-05T00:00:00Z). Judged by its era's rule: legal then."
  l_cell l-pred    0 "$L_FL" "stamps .claude/.ai-dlc-version at 0.782.0 or later -- not owed yet."
  l_cell l-nogit   0 "$L_FL" "PENDING (L -- ELICITATION): era unknown -- no git -- " "is not inside a git work tree"
  l_cell l-shallow 0 "$L_FL" "PENDING (L -- ELICITATION): era unknown -- shallow clone -- "
  l_cell l-undated 0 "$L_FL" "PENDING (L -- ELICITATION): era unknown -- undated -- the elicitation's earliest invoked_at"
  l_cell l-nostamp 0 "$L_FL" "PENDING (L -- ELICITATION): era unknown -- stamp absent -- no directory above"
  l_cell l-moved   0 "$L_FL" "PENDING (L -- ELICITATION): stories-adversarial-p1.md: s9: stories/ changed since the elicitation: shards record K=5, stories/ holds 3;"
  # An under-sharded base is never topped up by a delta (BL-733): the full re-run is named.
  l_cell l-under   1 "ONLY THE DELTA" "$L_FL" "(b) ordinals missing: 4.md 5.md; (c) cross shards short: 3 cross shard(s) where G=6 are owed" \
    "judged against the K=5 the shard headers record (stories/ holds 3)" "No shard dir complete for its own K exists to top up"
  l_cell l-match   0 "stories/ changed since" "OK (L -- ELICITATION): stories-adversarial-p1.md: s9 PASS"
  l_cell l-kdis    1 - "$L_FL" "(f) the shard: lines do not record one K in 1..999: 02.md=3 03.md=4"
  l_cell l-eqshort 1 "shards record K=" "$L_FL" \
    "not the sharded shape: (b) ordinals missing: 3.md; (c) cross shards short: 1 cross shard(s) where G=3 are owed (owed: cross.md, or all of cross-1.md cross-2.md cross-3.md)."
  # BL-733: one voice at `shard: 1/1` is never a base a delta tops up -- the full re-run is named.
  l_cell l-grow    1 "ONLY THE DELTA" "$L_FL" \
    "(b) ordinals missing: 2.md 3.md; (c) cross shards short: 0 cross shard(s) where G=3 are owed" \
    "shards record K=1, fewer than the 3 stories/ holds" "No shard dir complete for its own K exists to top up"
  # BL-733: a base complete for its K=2 whose ordinals name story-1 and story-2 owes only story-3 and
  # ONE cross.md, the per-group form accepted being the K=3 groups holding ordinal 3 (groups 2 and 3:
  # `1,3` and `2,3`), never cross-1 (`1,2`). Its lone cross.md is now the whole cross part: no (c).
  l_cell l-grow2   1 "cross-1 cross-2" "$L_FL" "not the sharded shape: (b) ordinals missing: 3.md; shards record K=2, fewer than the 3 stories/ holds" \
    "ONLY THE DELTA is owed -- stories: story-3; cross: cross.md (or all of cross-2 cross-3) --" "s9/shards/stories-elicitation-delta-k3/<story-basename>.md"
  # BL-733: the shrink WITH replacement still FAILs, and what it owes is the one story never elicited.
  l_cell l-replace 1 "stories/ changed since" "$L_FL" "(d) wrong names present: 05.md" \
    "shards record K=5, but they never name the story file(s) stories/ holds: story-new" \
    "ONLY THE DELTA is owed -- stories: story-new;"
  l_cell l-replace1 1 "stories/ changed since" "$L_FL" \
    "shards record K=5, but they never name the story file(s) stories/ holds: story-8"
  # `holds: story-new` is the WHOLE list: a reader that refused the relative s9 ordinal would print
  # `holds: story-2 story-new`, which does not contain it.
  l_cell l-foreign 1 "stories/ changed since" "$L_FL" \
    "shards record K=5, but they never name the story file(s) stories/ holds: story-new"

  # --- the mutants: a copy of the validator's directory (the merge and the partitioner beside it, or
  # arm L reads no map at all), an unmutated control first. Each cell is the arm-L line's class.
  # FAIL+K: a FAIL judged against the RECORDED K (its `the shard headers record` suffix), so a mutant
  # that honours a K it should not, yet still FAILs, is told apart by its text (LX7 at equality).
  l_class() { # <validator> <world> -> OK | FAIL | FAIL+K | PENDING | SILENT
    l_run "$1" "$2"
    if grep -qF "the shard headers record" "$L_OUT" && grep -qF "FAIL (L -- ELICITATION)" "$L_OUT"; then printf 'FAIL+K'
    elif grep -qF "FAIL (L -- ELICITATION)" "$L_OUT"; then printf 'FAIL'
    elif grep -qF "PENDING (L -- ELICITATION)" "$L_OUT"; then printf 'PENDING'
    elif grep -qF "OK (L -- ELICITATION)" "$L_OUT"; then printf 'OK'
    else printf 'SILENT'; fi
  }
  l_mut() { # <label> <expected row: pass legacy moved under grow replace eqshort match foreign> [<old> <new>]...
    local label="$1" want="$2" d got c; local SEAM_ARMS="L"; shift 2
    d="$(mktemp -d "$LW/mut.XXXXXX")"
    cp "$LS/validate-adversarial-convergence.sh" "$LS/validate-steering-budget.sh" "$LS/partition-document.sh" \
       "$LS/partition-subject.sh" "$LS/merge-adversarial-shards.sh" "$d/" 2>/dev/null
    ASSERTIONS=$((ASSERTIONS + 1))
    if [ ! -f "$d/merge-adversarial-shards.sh" ] || [ ! -f "$d/partition-document.sh" ]; then
      FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE BROKEN -- the merge or the partitioner is not beside the copy\n' "$label"; return
    fi
    if [ $# -gt 0 ]; then
      if ! python3 - "$d/validate-adversarial-convergence.sh" "$@" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read(); a = sys.argv[2:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1: sys.exit(3)
    s = s.replace(a[i], a[i + 1])
open(p, "w", encoding="utf-8").write(s)
PY
      then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- an anchor is not in the validator exactly once\n' "$label"; return; fi
      if cmp -s "$VALIDATOR" "$d/validate-adversarial-convergence.sh" || ! bash -n "$d/validate-adversarial-convergence.sh" 2>/dev/null; then
        FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s FIXTURE STALE -- the mutation DID NOT APPLY or is not valid shell\n' "$label"; return
      fi
    fi
    local i=0 wm; rsel "$want" "$L_REAL"; wm="$(rmask "$want")"
    got=""; for c in $L_MW; do i=$((i + 1)); if ron "$i"; then got="$got $(l_class "$d/validate-adversarial-convergence.sh" "$c")"; else got="$got ."; fi; done
    got="${got# }"; RSEL=""
    if [ "$got" = "$wm" ]; then printf '  ok    %-28s row [%s]\n' "$label" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s row [%s], want [%s]\n' "$label" "$got" "$want"; fi
  }
  L_MW="l-pass l-legacy l-moved l-under l-grow l-replace l-eqshort l-match l-foreign"
  L_REAL="OK OK PENDING FAIL+K FAIL FAIL FAIL OK FAIL"
  #                                       pass legacy moved   under  grow replace eqshort match foreign
  l_mut "LX0 control (unmutated)"        "OK OK PENDING FAIL+K FAIL FAIL FAIL OK FAIL"
  l_row() { local c r=""; for c in $L_MW; do r="$r $(l_class "$1" "$c")"; done; echo $r; }
  seam_guard "SEAM-GUARD L" L l_row "$LS/validate-adversarial-convergence.sh"
  # The staging symlink pointed at an empty dir: --map reads no stories and every judged world stops
  # judging. The end-to-end FAIL depends on the staged map, not on a listing of the shard dir.
  l_mut "LX1 --map staged on nothing"    "PENDING PENDING PENDING PENDING PENDING PENDING PENDING PENDING PENDING" \
    'ln -s "$l_sd/stories" "$AC_T/l/s$l_n/stories"' 'mkdir -p "$AC_T/l/s$l_n/stories"'
  # The de-padding gone: --map's `01` never meets the judge's `1`, so a complete dir FAILs. Only the
  # two-digit K of l-pass pads; the recorded-K judgment builds its own unpadded set.
  l_mut "LX2 ordinals not de-padded"     "FAIL OK PENDING FAIL+K FAIL FAIL FAIL OK FAIL" \
    'printf "%s%d", s, $1 + 0' 'printf "%s%s", s, $1'
  # The recorded K ignored: the moved stories/ FAILs a correct elicitation, and the under-sharded one
  # PASSes against today's smaller K.
  l_mut "LX3 recorded K ignored"         "OK OK FAIL OK FAIL FAIL FAIL OK FAIL" \
    '    if [ -z "$l_kcov" ] && l_kuse "$L_KREC" "$l_k"; then' '    if false; then'
  # The recorded-K branch as an EXEMPTION: any honoured recorded K reads PENDING, whether or not the
  # dir is complete for it. The under-sharded world is acquitted -- the regression this binds.
  l_mut "LX4 recorded K acquits all"     "OK OK PENDING PENDING FAIL FAIL FAIL OK FAIL" \
    $'        if [ "$L_V" = PASS ]; then\n          l_kmsg=' $'        if true; then\n          l_kmsg='
  # The GROW direction re-admitted (any K_rec other than today's honoured, the first cut of this
  # branch): one voice at `shard: 1/1` over three stories is complete for K=1 and reads PENDING. The
  # self-probe's direction conjunct goes with it, or the mutant exits 2 and reads SILENT everywhere.
  l_mut "LX5 smaller recorded K honoured" "OK OK PENDING FAIL+K PENDING FAIL FAIL OK FAIL" \
    'l_kuse() { [ -n "$1" ] && [ "$1" -gt "$2" ]; }' 'l_kuse() { [ -n "$1" ] && [ "$1" != "$2" ]; }' \
    '[ "$lp_ku" = "y" ] || lp_bad=' 'true || lp_bad='
  # The subject-cover test dropped: a shrink WITH replacement is complete for K_rec=5 and reads
  # PENDING although story-new was never elicited -- in l-replace, and in l-foreign too.
  l_mut "LX6 subject cover dropped"      "OK OK PENDING FAIL+K FAIL PENDING FAIL OK PENDING" \
    '    if [ -z "$l_kcov" ] && l_kuse "$L_KREC" "$l_k"; then' '    if l_kuse "$L_KREC" "$l_k"; then'
  # EQUALITY honoured (-gt to -ge): killed on a VERDICT by l-match, complete at K_rec == K == 3 with
  # subjects covering today's stories, which flips OK -> PENDING. l-eqshort keeps its causes but is
  # judged through the recorded-K branch, so its text gains `the shard headers record` (FAIL+K). The
  # self-probe's direction conjunct (3 over 3 refused) goes with it.
  l_mut "LX7 equality honoured"          "OK OK PENDING FAIL+K FAIL FAIL FAIL+K PENDING FAIL" \
    'l_kuse() { [ -n "$1" ] && [ "$1" -gt "$2" ]; }' 'l_kuse() { [ -n "$1" ] && [ "$1" -ge "$2" ]; }' \
    '[ "$lp_ku" = "y" ] || lp_bad=' 'true || lp_bad='
  # The SPRINT SCOPE dropped (basename-only, the pre-fix reader): s8's same-named story-new covers s9's,
  # so l-foreign reads PENDING; only it moves. The four self-probe conjuncts that seed a foreign sprint
  # go with it, or the mutant exits 2 and reads SILENT everywhere.
  l_mut "LX8 sprint scope dropped"       "OK OK PENDING FAIL+K FAIL FAIL FAIL OK PENDING" \
    'l_insprint() { case "$1" in "$2"|*/"$2") return 0 ;; esac; return 1; }' 'l_insprint() { return 0; }' \
    '|| lp_bad="$lp_bad [cover, foreign-sprint ordinal:' '|| : "$lp_bad [cover, foreign-sprint ordinal:' \
    '|| lp_bad="$lp_bad [cover, foreign-sprint cross:' '|| : "$lp_bad [cover, foreign-sprint cross:' \
    '|| lp_bad="$lp_bad [cover, s19 ordinal suffix:' '|| : "$lp_bad [cover, s19 ordinal suffix:' \
    'then lp_bad="$lp_bad [l_insprint boundary' 'then : "$lp_bad [l_insprint boundary'
  # BL-811, ONE cross shard: its own worlds. LM1 and LM2 also silence the self-probe's verdict, whose
  # lone-cross and partial-set rows refuse each of them (exit 2) before the live arm is reached.
  L_MW="l-legacy l-full7 l-part7 l-dx l-dxno"
  L_REAL="OK OK FAIL OK FAIL"
  #                                         legacy full7 part7 dx dxno
  l_mut "LM0 control (unmutated)"          "OK OK FAIL OK FAIL"
  # The old rule: a lone cross.md never stands in for cross-1..G, so l-legacy FAILs (c).
  l_mut "LM1 lone cross refused"           "FAIL OK FAIL OK FAIL" \
    'then l_mx=""; l_xoff=""; fi' 'then :; fi' \
    '|| [ -n "$lp_bad" ]; then' '|| false; then'
  # Any non-empty cross subset accepted: the partial cross-1..3 of G=6 at K=7 PASSes.
  l_mut "LM2 any cross subset accepted"    "OK OK OK OK FAIL" \
    'if [ -n "$l_mx" ] && [ "$l_xh" -eq 0 ] && [ "$l_xoff" = " cross.md" ]; then' 'if [ -n "$l_mx" ] && { [ "$l_xh" -gt 0 ] || [ -n "$l_xoff" ]; }; then' \
    '|| [ -n "$lp_bad" ]; then' '|| false; then'
  # The delta owes no cross at all: a delta of story-3.md alone PASSes.
  l_mut "LM3 delta owes no cross"          "OK OK FAIL OK OK" \
    '  case "$l_dhave" in *" cross.md "*) l_dmx="" ;; *) [ -n "$l_dgn" ] || [ -z "$L_DU" ] || l_dmx=" cross.md" ;; esac' '  l_dmx=""'
fi

# --- BL-733: THE DELTA, the receipt as an arm. Its worlds are the reference consumer's s319 split
# (base complete at K=19, the 8th story split, K=20): owed by name {story-08a story-08b; cross-1
# cross-4 cross-5}, where a diff of the index lists answers {3,5,6}. Two mutants, each a plausible
# regression: owed groups taken from the index-list diff, and ordinal coverage read through l_cover,
# whose cross `<name>=` entries then acquit a story no ordinal shard names.
echo "--- arm L delta (BL-733): receipt-bl733.sh against the validator, a control copy and two mutants"
R733="$DIR/receipt-bl733.sh"
[ -f "$R733" ] || broken "receipt-bl733.sh is not beside run.sh"
rcpt_cell "LD shipped validator"      "$R733" "$VALIDATOR" 0
rcpt_mut  "LD0 control (unmutated)"   "$R733" 0
RCPT_SEAM=1 rcpt_mut "SEAM-GUARD LD receipt" "$R733" 0
RM_TWIN=full rcpt_mut  "LD1 owed groups by index diff" "$R733" "1|receipt BL-733: NOT FIXED -- nodelta(rc=1) fullg(rc=1) nocross(rc=1) xnamed(rc=1)" \
  '    END { for (i = 1; i <= r; i++) if (own[i]) printf "G %s\n", (r == 1 ? "cross" : "cross-" i) }'"'"' "$3" "$4")" \' \
  '    END { }'"'"' "$3" "$4")" \' \
  '  while read -r l_dt l_dv; do' \
  '  for l_g in $(awk -F"\t" "FNR == NR { o[\$1] = \$2; next } o[\$1] != \$2 { print \$1 }" "$AC_T/l-dbgroups" "$4"); do L_DG="$L_DG cross-$l_g"; done
  while read -r l_dt l_dv; do'
RM_TWIN=nodelta rcpt_mut  "LD2 cross names acquit ordinals" "$R733" "1|receipt BL-733: NOT FIXED -- xnamed(rc=1)" \
  $'  l_onames "$1" "$2"\n  # A base whose' \
  $'  l_cover "$1" "$AC_T/no-such-stories" "$2"; L_ONAMES="$l_cn"\n  # A base whose'

fi
if sg pair; then
# --- PAIRING: a case that DENIES must assert the state the hooks read -------------
# THE MECHANISM FOR A DEFECT CLASS THIS FIXTURE HAS NOW HIT TWICE. Gate mode and
# --cycle-state are different code paths with different branch ordering, and the second one
# is what the hooks call to deny a dispatch. A case asserted only in gate mode leaves that
# path untested, which is how `reopen-moved-clean` passed while the state machine reported
# CONVERGED, and how four divergence cases sat green for their whole lifetime while telling
# the hooks to proceed on a series the gate refused.
#
# It is DERIVED, not a hand list: any seeded case whose --cycle-state exits 3 must carry an
# expect_state naming it. Cases that do not deny are exempt, because arms D and H are
# gate-only by design and pairing them would fire on correct cases -- of the 39 cases
# carrying a gate expect, 15 deny and 24 are quiet, so a blanket pairing rule would have
# been wrong 24 times.
#
# ELEVEN OF THOSE FIFTEEN WERE UNPAIRED WHEN THIS ARM WAS WRITTEN, and three of the eleven
# were found BY the arm rather than by the hand-census that preceded it -- that census had
# been run without --transcript/--transcript-dir, so the adjudication cases answered
# CONVERGED and looked exempt. Run this arm the way the harness runs the validator, or it
# measures a different program.
PAIR_MISSING=""
for _d in "$ROOT"/*/; do
  [ -d "$_d" ] || continue
  _c="$(basename "$_d")"
  _pfx=""
  for _f in "$_d"*adversarial*p*.md; do
    [ -f "$_f" ] || continue
    case "$_f" in *-repair-p*) continue ;; esac
    _pfx="$_d$(basename "$_f" | sed 's/[0-9]*\.md$//')"
    break
  done
  [ -n "$_pfx" ] || continue
  # The exit code does not depend on where stderr goes, so this shares expect_state's `out` runs.
  vrun out "$VALIDATOR" --series "$_pfx" --cycle-state --transcript "$TRANSCRIPT" --transcript-dir "$ROOT"
  [ "$VR_RC" -eq 3 ] || continue
  grep -qE "^expect_state[[:space:]]+${_c}([[:space:]]|\$)" "$DIR/run.sh" \
    || PAIR_MISSING="$PAIR_MISSING $_c"
done
ASSERTIONS=$((ASSERTIONS + 1))
if [ -n "$PAIR_MISSING" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s case(s) deny via --cycle-state but assert only gate mode:%s\n' \
    "state-mode-pairing" "$PAIR_MISSING"
else
  printf '  ok    %-28s every denying case asserts the state the hooks read\n' "state-mode-pairing"
fi
fi
if sg tstrat; then
echo
# --- BL-723: THE TEST-STRATEGY SERIES, bound from Check 24's own text to the program ---------
# stories-test-strategy.md §5 step 2 converges `test-strategy.md` through the native cycle, and
# Check 24 runs that series. Two documents name one prefix, and nothing but this unit joins them:
#   bind    the prefix is EXTRACTED from Check 24's section (`### 24.` to `### 25.`), never typed
#           here. `s<N>` resolves to a seeded sprint, the series is seeded at the prefix §5 names,
#           and the SHIPPING validator runs with Check 24's prefix: exit 0 on a terminal MET pass at
#           0 CRITICAL and 3 derived MAJOR, exit 1 with rung A on a verdict-less pass. An empty
#           extraction is a FAIL naming the token; a prefix §5 does not write matches nothing.
#   absent  §5 (`### 5.` to `### 6.`) names no bmad-review-adversarial-general, against a
#           same-invocation control that bug-investigation.md does (control zero is BROKEN).
#   names   §5 names test-strategy-adversarial-p, "Adversarial review dispatch", "Adversarial repair
#           dispatch", and step 3's precondition (the highest pass "does not stamp
#           `verdict: EXIT_CONDITION_MET`" -> return to step 2), each once-unique in §5 today.
# Arm L's silence on this series is a CHARACTERIZATION (L keys on stories-adversarial-p only), not
# a kill. Worlds live under $ROOT/.ts-worlds, hidden, so the pairing loop's `$ROOT/*/` never walks them.
# THE ABSENCE ARM IS WHY THE MUTANTS ARE COMMITTED: an absence passes for a span that read nothing,
# so the unmutated docs must score `ok ok ok` (the positive control) and each mutant must move
# exactly its own cell.
TS_GATE=""; TS_STEP=""; TS_CTL=""
for cand in "$DIR/../../skills/ai-dlc/steps" "$DIR/../../../.claude/skills/ai-dlc/steps"; do
  if [ -f "$cand/gate-validation.md" ] && [ -f "$cand/stories-test-strategy.md" ] && [ -f "$cand/bug-investigation.md" ]; then
    TS_GATE="$cand/gate-validation.md"; TS_STEP="$cand/stories-test-strategy.md"; TS_CTL="$cand/bug-investigation.md"; break
  fi
done
[ -n "$TS_GATE" ] || broken "BL-723: gate-validation.md, stories-test-strategy.md and bug-investigation.md are not together under either layout from $DIR"
TS_TOKEN='_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p'
TS_RE='_bmad-output/planning-artifacts/s<N>/test-strategy[A-Za-z0-9_-]*-p'
TS_BMAD='bmad-review-adversarial-general'
ts_span() { awk -v s="$2" -v e="$3" 'index($0, s) == 1 { f = 1; next } index($0, e) == 1 { f = 0 } f' "$1"; }
ts_prefixes() { ts_span "$1" "$2" "$3" | grep -oE -- "$TS_RE" | sort -u; }
ts_count() { local n; n="$(ts_span "$1" "$2" "$3" | grep -cF -- "$4")" || n=0; printf '%s\n' "$n"; }
TSW="$ROOT/.ts-worlds"
mkdir -p "$TSW/probe" || broken "cannot create $TSW"

# SELF-PROBE, BEFORE THE CORPUS, BOTH DIRECTIONS. The extractor reports the in-section token and
# stays quiet on the same grammar one section either side; the span count sees a §5 offender and
# stays quiet on one in §6.
printf '%s\n' '### 23. a' 'x `_bmad-output/planning-artifacts/s<N>/test-strategy-before-p` x' '### 24. b' \
  'y `_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p` y' '### 25. c' \
  'z `_bmad-output/planning-artifacts/s<N>/test-strategy-after-p` z' > "$TSW/probe/hit.md"
printf '%s\n' '### 23. a' 'x `_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p` x' '### 24. b' 'y' \
  '### 25. c' 'z `_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p` z' > "$TSW/probe/miss.md"
printf '%s\n' '### 5. a' '2. `/bmad-review-adversarial-general` x' '### 6. b' > "$TSW/probe/s5hit.md"
printf '%s\n' '### 5. a' '2. converge' '### 6. b' '`/bmad-review-adversarial-general`' > "$TSW/probe/s5miss.md"
if [ "$(ts_prefixes "$TSW/probe/hit.md" '### 24.' '### 25.')" != "$TS_TOKEN" ] \
   || [ -n "$(ts_prefixes "$TSW/probe/miss.md" '### 24.' '### 25.')" ] \
   || [ "$(ts_count "$TSW/probe/s5hit.md" '### 5.' '### 6.' "$TS_BMAD")" != 1 ] \
   || [ "$(ts_count "$TSW/probe/s5miss.md" '### 5.' '### 6.' "$TS_BMAD")" != 0 ]; then
  broken "BL-723: the section extractor's self-probe did not discriminate (in-section hit, out-of-section near-miss)"
fi
echo "  [TS0] section extractor self-probe: reports the in-section token, silent one section either side"

ts_sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
ts_pass() { # <pass file> <artifact sha> <verdict line | ""> -- one unsharded pass, the shipped block shape
  { printf '# test-strategy -- adversarial pass 1\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n'
    printf 'mode: subagent\nlead_role: architect\ninvoked_at: 2026-07-12T02:00:00Z\ntool_use_id: toolu_fixture_ts1\n'
    printf 'artifact: test-strategy.md\nartifact_sha: %s\nfindings_critical: 0\nfindings_critical_prior_scope: 0\n' "$2"
    printf 'findings_major: 3\nfindings_major_underived: 0\nfindings_minor: 0\n'
    if [ -n "$3" ]; then printf '%s\n' "$3"; fi
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$1"
}
# ts_eval <label> <gate doc> <step doc> -> TS_BIND TS_ABS TS_NAMES (ok|FAIL), each with a _WHY, and
# TS_MET_OUT (the MET run's output). Every cell is PRESENCE-shaped toward `ok`: a cell reads ok only
# when its program ran and said the specific thing, so a harness that ran nothing cannot score `ok ok ok`.
ts_eval() {
  local w="$TSW/$(printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '_')" g="$2" s="$3" n gp sp ng nsp sprint f sha out rc tok
  TS_BIND=ok; TS_ABS=ok; TS_NAMES=ok; TS_BIND_WHY=""; TS_ABS_WHY=""; TS_NAMES_WHY=""; TS_MET_OUT=""
  n="$(ts_span "$s" '### 5.' '### 6.' | grep -c .)" || n=0
  if [ "$n" -eq 0 ]; then
    TS_ABS=FAIL; TS_ABS_WHY="the §5 span (### 5. to ### 6.) of $(basename "$s") is empty -- an absence over nothing"
  else
    n="$(ts_count "$s" '### 5.' '### 6.' "$TS_BMAD")"
    [ "$n" -eq 0 ] || { TS_ABS=FAIL; TS_ABS_WHY="§5 names $TS_BMAD on $n line(s); the test strategy converges through the native cycle"; }
  fi
  for tok in 'test-strategy-adversarial-p' 'Adversarial review dispatch' 'Adversarial repair dispatch' \
             'does not stamp `verdict: EXIT_CONDITION_MET`'; do
    n="$(ts_count "$s" '### 5.' '### 6.' "$tok")"
    [ "$n" -gt 0 ] || { TS_NAMES=FAIL; TS_NAMES_WHY="$TS_NAMES_WHY §5 does not name \"$tok\";"; }
  done
  gp="$(ts_prefixes "$g" '### 24.' '### 25.')"; sp="$(ts_prefixes "$s" '### 5.' '### 6.')"
  ng="$(printf '%s' "$gp" | grep -c .)" || ng=0
  nsp="$(printf '%s' "$sp" | grep -c .)" || nsp=0
  if [ "$ng" -eq 0 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's section (### 24. to ### 25.) names no \`$TS_TOKEN\` -- the gate runs no test-strategy series"; return 0
  elif [ "$ng" -ne 1 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's section names $ng distinct test-strategy prefixes: $(echo $gp)"; return 0
  elif [ "$nsp" -ne 1 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="§5 names $nsp distinct test-strategy series prefixes (want 1): $(echo $sp)"; return 0
  fi
  # s9 carries the terminal MET pass; s8 the same pass with no verdict: key (rung A). Each artifact_sha
  # is the sha of the test-strategy.md beside it, so nothing but the verdict separates them.
  for sprint in s9 s8; do
    f="$w/${sp/s<N>/$sprint}"
    mkdir -p "${f%/*}" || { TS_BIND=FAIL; TS_BIND_WHY="could not seed ${f%/*}"; return 0; }
    printf '# Sprint %s test strategy\n\nEvery acceptance criterion maps to a case.\n' "${sprint#s}" > "${f%/*}/test-strategy.md"
    sha="$(ts_sha "${f%/*}/test-strategy.md")"
    [ "${#sha}" -eq 64 ] || { TS_BIND=FAIL; TS_BIND_WHY="no sha256 of the seeded test-strategy.md"; return 0; }
    if [ "$sprint" = s9 ]; then ts_pass "${f}1.md" "$sha" 'verdict: EXIT_CONDITION_MET'; else ts_pass "${f}1.md" "$sha" ''; fi
  done
  TS_MET_OUT="$(bash "$VALIDATOR" --series "$w/${gp/s<N>/s9}" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's prefix over a terminal MET pass (0C, 3 derived MAJOR) exits $rc, want 0: $(printf '%s' "$TS_MET_OUT" | head -3 | tr '\n' ' ')"; return 0
  fi
  out="$(bash "$VALIDATOR" --series "$w/${gp/s<N>/s8}" --transcript "$TRANSCRIPT" --transcript-dir "$ROOT" 2>&1)"; rc=$?
  if [ "$rc" -ne 1 ] || ! grep -qF -- "FAIL (A -- VOCABULARY)" <<<"$out" || ! grep -qF -- "declares no 'verdict:'" <<<"$out"; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's prefix over a verdict-less pass exits $rc without rung A (want 1, FAIL (A -- VOCABULARY))"; return 0
  fi
  return 0
}

ts_eval shipped "$TS_GATE" "$TS_STEP"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$TS_BIND" = ok ]; then
  printf '  ok    %-28s %s\n' "ts-bind" "Check 24's own prefix runs the §5 series: MET exits 0, a verdict-less pass fails rung A"
else
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s %s\n' "ts-bind" "$TS_BIND_WHY"
fi
ASSERTIONS=$((ASSERTIONS + 1))
ts_ctl="$(grep -cF -- "$TS_BMAD" "$TS_CTL")" || ts_ctl=0
if [ "$ts_ctl" -eq 0 ]; then
  broken "BL-723 CONTROL: bug-investigation.md names $TS_BMAD 0 times -- the absence arm below cannot tell a clean §5 from a token no file carries"
elif [ "$TS_ABS" = ok ]; then
  printf '  ok    %-28s %s\n' "ts-absent" "§5 names no $TS_BMAD (control: bug-investigation.md names it $ts_ctl times)"
else
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s %s\n' "ts-absent" "$TS_ABS_WHY"
fi
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$TS_NAMES" = ok ]; then
  printf '  ok    %-28s %s\n' "ts-names" "§5 names test-strategy-adversarial-p, both Adversarial dispatches and step 3's MET precondition"
else
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s %s\n' "ts-names" "${TS_NAMES_WHY# }"
fi
# CHARACTERIZATION, not a kill: arm L keys on stories-adversarial-p and has nothing to say here.
if [ "$TS_BIND" = ok ]; then
  ASSERTIONS=$((ASSERTIONS + 1))
  if grep -qi -- 'elicitation' <<<"$TS_MET_OUT"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s %s\n' "ts-arm-l-silent" "arm L spoke about elicitation on the test-strategy series"
  else
    printf '  ok    %-28s %s\n' "ts-arm-l-silent" "arm L says nothing about elicitation on the test-strategy series"
  fi
fi

# --- MUTATION: one per cell the subject fix carries, each built as a COPY, cmp -s guarded ----------
#                               bind  absent  names
#   shipped (control)           ok    ok      ok
#   bmad restored in §5 step 2  ok    FAIL    ok
#   Check 24 drops the prefix   FAIL  ok      ok
#   step 3 precondition deleted ok    ok      FAIL
ts_score() { # <label> <gate doc> <step doc> <expected row>
  local got
  ts_eval "$1" "$2" "$3"; got="$TS_BIND $TS_ABS $TS_NAMES"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$got" = "$4" ]; then
    printf '  ok    %-28s [%s]\n' "$1" "$got"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-28s got [%s] want [%s]\n' "$1" "$got" "$4"
  fi
}
ts_mut() { # <label> <python re> <replacement> <source doc> <copy> -> 0 when the mutation applied and is complete
  MUT_RE="$2" MUT_NEW="$3" python3 -c 'import os,re,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(re.sub(os.environ["MUT_RE"],os.environ["MUT_NEW"],s,count=1 if os.environ["MUT_NEW"] else 0))' "$4" "$5"
  if [ ! -s "$5" ] || cmp -s "$4" "$5"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s DID NOT APPLY -- the mutation matched nothing; this assertion proves nothing\n' "MUTATION $1"
    return 1
  fi
  return 0
}
TSM="$TSW/mut"; mkdir -p "$TSM" || broken "cannot create $TSM"
ts_score "CONTROL ts unmutated" "$TS_GATE" "$TS_STEP" "ok ok ok"
# M1: the one-shot comes back as §5 step 2. Anchored on step 2's own opening, which must be unique.
ts_a="$(grep -c '^2\. \*\*Converge the test strategy\.\*\*' "$TS_STEP")" || ts_a=0
ts_actl="$(grep -c '^2\. \*\*Converge the test strategy no-such-line' "$TS_STEP")" || ts_actl=0
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$ts_a" -ne 1 ] || [ "$ts_actl" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-28s step 2 anchor matches %s line(s) (want 1; impossible-anchor control %s, want 0)\n' "MUTATION ts-anchor" "$ts_a" "$ts_actl"
else
  printf '  ok    %-28s step 2 anchor is unique (impossible-anchor control: 0)\n' "MUTATION ts-anchor"
fi
if ts_mut ts-bmad-restored '(?m)^2\. \*\*Converge the test strategy\.\*\*' \
     '2. `/bmad-review-adversarial-general` — review test strategy. **Converge the test strategy.**' \
     "$TS_STEP" "$TSM/stories-test-strategy.m1.md"; then
  ts_score "MUTATION ts-bmad-restored" "$TS_GATE" "$TSM/stories-test-strategy.m1.md" "ok FAIL ok"
fi
# M2: Check 24 stops naming the series. Keyed on the extractor's own grammar over the whole file, and
# the copy must carry ZERO matches against a non-zero original.
if ts_mut ts-gate-prefix-dropped "$TS_RE" '' "$TS_GATE" "$TSM/gate-validation.m2.md"; then
  ts_m2="$(grep -cE -- "$TS_RE" "$TSM/gate-validation.m2.md")" || ts_m2=0
  ts_m2o="$(grep -cE -- "$TS_RE" "$TS_GATE")" || ts_m2o=0
  if [ "$ts_m2" -ne 0 ] || [ "$ts_m2o" -eq 0 ]; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the copy keeps %s match(es) (original %s) -- an incomplete mutation\n' "MUTATION ts-gate-prefix-dropped" "$ts_m2" "$ts_m2o"
  else
    ts_score "MUTATION ts-gate-prefix-dropped" "$TSM/gate-validation.m2.md" "$TS_STEP" "FAIL ok ok"
  fi
fi
# M3: step 3's precondition paragraph is deleted, from its own opening line up to the bind paragraph
# that follows it. The em dash is matched by `.` so the pattern stays ASCII. The copy must carry
# ZERO precondition stamps against exactly one in the original, or the mutation is incomplete.
TS_PRE='does not stamp `verdict: EXIT_CONDITION_MET`'
if ts_mut ts-precondition-deleted \
     '(?ms)^3\. \*\*Precondition . the step-2 series has exited\.\*\*.*?(?=^   \*\*Bind every strategy case)' '' \
     "$TS_STEP" "$TSM/stories-test-strategy.m3.md"; then
  ts_m3="$(grep -cF -- "$TS_PRE" "$TSM/stories-test-strategy.m3.md")" || ts_m3=0
  ts_m3o="$(grep -cF -- "$TS_PRE" "$TS_STEP")" || ts_m3o=0
  if [ "$ts_m3" -ne 0 ] || [ "$ts_m3o" -ne 1 ]; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-28s the copy keeps %s precondition stamp(s) (original %s, want 1) -- an incomplete mutation\n' "MUTATION ts-precondition-deleted" "$ts_m3" "$ts_m3o"
  else
    ts_score "MUTATION ts-precondition-deleted" "$TS_GATE" "$TSM/stories-test-strategy.m3.md" "ok ok FAIL"
  fi
fi
fi

mx_arm
echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
