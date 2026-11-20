#!/usr/bin/env bash
# gate-series-rung — the SERIES arms of validate-gate-adjudication.sh --series.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = an arm regressed, 2 = fixture broken.
#
# Sibling of `gate-repair-record`, which covers the repair-record arm of the same mode. This
# one covers the other four: series_stall_run, series_boundary_run, series_nonce_sortable,
# and the legacy posture. Together they are the mode's fixture surface; neither duplicates
# the other's subject.
#
# THE DEFECT THIS EXISTS TO CATCH. The reference consumer ran ONE [story] gate for eleven
# adjudication passes with the same check failing the last seven, while the failure protocol
# already said "if still failing after remediation, escalate as HARD_BLOCK per Rule 12".
# Nothing counted, so nothing escalated. The loop was not unbounded by design — it was
# unbounded because no artifact carried the SERIES, so no run was expressible.
#
# WHY EVERY CASE COMES IN A PAIR. Each pair differs in exactly one variable and the fixture
# asserts that identity BEFORE it asserts any verdict. Three of the four arms here were
# written to catch a defeat that leaves the verdict values untouched — a re-sorted nonce, a
# series split in half, a deleted series id — so a fixture that let a second difference in
# would be proving something else and reading exactly like the property it claims. That is
# this repo's recurring defect, and it has already been reproduced once inside a test written
# to catch it.
#
# ASSERT ON THE MESSAGE, NEVER THE EXIT CODE ALONE. A validator with no series arms at all
# exits 0 everywhere; one whose stall rung fires on everything exits 1 everywhere. An
# exit-code-only fixture scores the first as a pass on every silent case and the second as a
# pass on every firing case.
#
set -u
# Scrub ambient AI_DLC_* — the validator reads AI_DLC_VERDICT_SCHEMA and AI_DLC_STATE_DIR,
# and a consumer that tunes either in settings.json would otherwise fail this against
# correct code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-gate-adjudication.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-gate-adjudication.sh" \
  "$DIR/../../core/scripts/validate-gate-adjudication.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FIXTURE BROKEN: cannot locate validate-gate-adjudication.sh from $DIR"; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present validator with neither the `vga_main() {` line nor the column-0
# source guard predates the in-process wrap, and sourcing it would run its whole body: SKIP and exit 0 (FIXTURE BROKEN
# in the distribution), never an ok. Exactly one half is a respelled subject this fixture cannot drive, which FAILS. An
# unreadable subject is FIXTURE ERROR. This check runs BEFORE any source of the subject.
gsr_half() { # gsr_half <fixed line> -> 0 present, 1 absent; exit 2 when the subject is unreadable
  local x; grep -qxF "$1" "$VALIDATOR"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  return "$x"
}
_gsr_d=0; _gsr_g=0
gsr_half 'vga_main() {' || _gsr_d=1
gsr_half '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' || _gsr_g=1
# _d/_g hold 1 when the line is ABSENT.
if [ "$_gsr_d$_gsr_g" = 11 ]; then
  echo "SKIP: gate-series-rung: $VALIDATOR predates the in-process wrap"; fx_skip_exit "$DIR"
elif [ "$_gsr_d$_gsr_g" != 00 ]; then
  bad "$VALIDATOR carries one half of the in-process wrap (vga_main line absent=$_gsr_d, column-0 source guard absent=$_gsr_g) -- a respelled subject this fixture cannot drive"
  report_end gate-series-rung
fi
# IN PROCESS (BL-878). Every cell asks vga_main through vga_f, which hands the file to lib/inproc.sh's inproc_run: the
# validator is sourced inside inproc_run's own subshell and its entry called there, logged as a pass of the subject
# (the `inproc:` row). The operand is a literal tail, as gate-resume's, so arm P2 of validate-fixture-invocations.sh
# resolves it. The programs run only in the cells of cells.decl.
vga_f() { # vga_f <file> [args...] -> vga_main's stdout, stderr and exit
  local _f="$1"; shift
  case "$_f" in */validate-gate-adjudication.sh) ;; *) echo "FIXTURE BROKEN: vga_f was handed $_f, not a validate-gate-adjudication.sh" >&2; return 125 ;; esac
  ( inproc_run "${_f%/*}/validate-gate-adjudication.sh" vga_main "$@" )
}
# The REQUIRED input of inputs.decl: every case below drives this file.
echo "HERMETIC-CONSUMED core/scripts/validate-gate-adjudication.sh"
[ -f "$(dirname "$VALIDATOR")/gate_adjudication.py" ] && echo "HERMETIC-CONSUMED core/scripts/gate_adjudication.py"

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "FIXTURE BROKEN: seed.sh produced no root"; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

note_fail() { bad "$*"; }
gd() { printf '%s/%s/_bmad-output/gate-adjudication' "$ROOT" "$1"; }

# Run a case; set RC and OUT.
run_case() { OUT="$(vga_f "$VALIDATOR" --series "$(gd "$1")" 2>&1)"; RC=$?; }

# expect <case> <rc> <marker|-> <human name>
expect() {
  run_case "$1"
  if [ "$RC" -ne "$2" ]; then
    note_fail "$1 exited $RC, expected $2. $4
  validator said: $(head -3 <<<"$OUT")"
    return
  fi
  if [ "$3" != "-" ] && ! grep -q "$3" <<<"$OUT"; then
    note_fail "$1 exited $2 as expected but did NOT carry '$3'. The right exit for the wrong
  reason is the failure this fixture is shaped to refuse. $4
  validator said: $(head -3 <<<"$OUT")"
    return
  fi
  if [ "$3" = "-" ]; then ok "$1 exited $2"; else ok "$1 exited $2 carrying '$3'"; fi
}

# --------------------------------------------------------------------------
# 0. THE SEEDS. Every differential claim, checked before it is relied on.
# --------------------------------------------------------------------------
payloads() {
  python3 - "$1" <<'PY'
import json, os, sys
d = sys.argv[1]
out = []
for f in sorted(os.listdir(d)):
    if f.endswith(".json"):
        out.append(json.dumps(json.load(open(os.path.join(d, f)))["verdicts"], sort_keys=True))
print("\n".join(sorted(out)))
PY
}

if ! diff -q <(payloads "$(gd split-joined)") <(payloads "$(gd split-defeat)") >/dev/null; then
  note_fail "split-joined and split-defeat do NOT carry byte-identical verdict payloads.
  The entire claim of that pair is that gate_series_id is the ONLY difference; with a second
  one present, a validator could separate them by reading the verdicts and the boundary arm
  would score as held without existing."
else
  ok "seed: split-joined and split-defeat carry byte-identical verdict payloads"
fi

if ! diff -q <(payloads "$(gd nonce-sortable)") <(payloads "$(gd nonce-unsortable)") >/dev/null; then
  note_fail "nonce-sortable and nonce-unsortable do NOT carry byte-identical verdict payloads.
  That pair asserts the NONCE alone re-sequences the run; a verdict-value difference would
  prove the ordinary stall rung instead."
else
  ok "seed: nonce-sortable and nonce-unsortable carry byte-identical verdict payloads"
fi

# The intended difference must actually be present, or a pair is one case twice.
n_sids="$(python3 -c '
import json,glob,sys
print(len({json.load(open(f))["gate_series_id"] for f in glob.glob(sys.argv[1]+"/*.json")}))' "$(gd split-defeat)")"
if [ "$n_sids" = "2" ]; then
  ok "seed: split-defeat carries 2 distinct gate_series_id(s)"
else
  note_fail "split-defeat carries $n_sids distinct gate_series_id(s); expected 2.
  The independent variable is not set, so it is split-joined twice."
fi

# K IS PINNED HERE. If K changes, this assertion tells you, instead of the silent cases
# quietly going red and being blamed on whatever else changed.
run_case stall-fires
if ! grep -q 'across 3 consecutive passes' <<<"$OUT"; then
  note_fail "the stall rung did not report a threshold of 3. This fixture's silent cases are
  built one short of K=3; a different K makes them meaningless rather than wrong, so the
  threshold is asserted here explicitly."
else
  ok "K: the stall rung reports a threshold of 3"
fi

# --------------------------------------------------------------------------
# 1. series_stall_run
# --------------------------------------------------------------------------
expect stall-fires 1 'STALLED' \
  "Check 7 holds FAIL across three consecutive passes. This is the eleven-pass cascade in
  miniature; a rung that cannot see it is the state the consumer shipped in."
expect stall-silent 0 '-' \
  "No check reaches three consecutive FAILs here. A rung that fires anyway blocks a loop
  that is converging, and gets switched off."

# --------------------------------------------------------------------------
# 1b. FAIL_WAIVED breaks the run — a check waived on every pass does not stall
# --------------------------------------------------------------------------
# W1 is ABSENCE-shaped (exit 0, no STALLED). W2 is PRESENCE-shaped and pins WHERE the new run starts:
# pass 2's nonce through pass 4's, at pass 4. A rung that kept the waiver in the run reports from
# pass 1 at pass 3 instead.
W2_SPAN='story-20260811T180200Z → story-20260811T180400Z (pass 4 of 4'
# The waiver cases name their own escalations file and root, so the sibling reads the seeded entry
# and never the repo's or the sandbox's.
w_series() { # <validator> <case> -> OUT RC
  OUT="$(AI_DLC_PROJECT_ROOT="$ROOT/$2" AI_DLC_ESCALATIONS="$ROOT/$2/docs/escalations/pending.md" \
    vga_f "$1" --series "$(gd "$2")" 2>&1)"; RC=$?; }
w_p1() { w_series "$1" waived-x3
  [ "$RC" -eq 0 ] && ! grep -q 'STALLED' <<<"$OUT"; }
w_p2() { w_series "$1" waived-then-fail
  [ "$RC" -eq 1 ] && grep -qF "$W2_SPAN" <<<"$OUT"; }
w_p3() { w_series "$1" unresolved-x3
  [ "$RC" -eq 1 ] && grep -q "STALLED: series .* check '7' has held FAIL across 3" <<<"$OUT"; }
if ! w_p1 "$VALIDATOR"; then
  note_fail "waived-x3 (check 7 FAIL_WAIVED on three consecutive passes, waiver RESOLVES) exited $RC or
  reported STALLED. A FAIL_WAIVED under a resolving waiver breaks the check's run.
  validator said: $(head -3 <<<"$OUT")"
else ok "W1 waived-x3: a resolving waiver breaks the run (exit 0, no STALLED)"; fi
if ! w_p2 "$VALIDATOR"; then
  note_fail "waived-then-fail (FAIL_WAIVED, FAIL, FAIL, FAIL) did not stall with the run starting
  AFTER the waiver ('$W2_SPAN'). A later FAIL starts a new run from 1.
  validator said: $(head -3 <<<"$OUT")"
else ok "W2 waived-then-fail: the run restarts after the waiver ('$W2_SPAN')"; fi
if ! w_p3 "$VALIDATOR"; then
  note_fail "unresolved-x3 (three FAIL_WAIVED under a waiver_id naming no entry) did not STALL. A
  FAIL_WAIVED whose waiver does not resolve continues the run as FAIL.
  validator said: $(head -3 <<<"$OUT")"
else ok "W3 unresolved-x3: an unresolved waiver continues the run as FAIL (STALLED)"; fi

# --- the --sprint cells (section 5 below states them).
# H byte-locks every unscoped --series message. A DELIBERATE wording change turns it red: re-take both digests
# with hsig from the changed validator, and say in the commit that the unscoped output changed on purpose.
H_GRAPH=8b97a31758ceb96afbc157064b758927
H_LEGACY=ca0413ff65393dfcf12ff1fdf35becec
SG="$(gd graph)"
sr() { local v="$1"; shift; OUT="$(vga_f "$v" --series "$@" 2>&1)"; RC=$?; }
has() { grep -qF -- "$1" <<<"$OUT"; }
# hsig <validator> <dir>: md5 of "<rc>\n<stdout>\0<stderr>" with the seeded root normalised.
hsig() {
  vga_f "$1" --series "$2" >"$ROOT/.h.out" 2>"$ROOT/.h.err"; RC=$?
  python3 -c 'import hashlib,sys
r,rc,o,e=sys.argv[1:]
t=rc+"\n"+open(o).read().replace(r,"<ROOT>")+"\0"+open(e).read().replace(r,"<ROOT>")
print(hashlib.md5(t.encode()).hexdigest())' "$ROOT" "$RC" "$ROOT/.h.out" "$ROOT/.h.err"
}
sc_A() { sr "$1" --sprint 302 "$SG"; [ "$RC" -eq 1 ] && has "STALLED: series 'implementation-s302-20260812T202738Z'"; }
sc_B() { sr "$1" --sprint 322 "$SG" "$(gd s322-one)"; [ "$RC" -eq 0 ] && has "1 series / 1 pass(es)" \
  && has "Sprint 322: 187 file(s) out of scope (93 of another sprint's series, 94 legacy)."; }
sc_C() { sr "$1" --sprint 322 "$SG"; [ "$RC" -eq 0 ] && has "PASS — sprint 322: 0 in-scope series across 187" \
  && has "EXAMINED NOTHING" && has "not in scope (legacy, unplaceable nonce, generated_at 2026-07-19T02:53:44Z"; }
sc_D() { sr "$1" --sprint 32 "$SG" "$(gd s322-one)"; [ "$RC" -eq 0 ] && has "PASS — sprint 32: 0 in-scope series" \
  && has "EXAMINED NOTHING"; }
sc_E() {
  local a bad=0
  for a in 0322 3x ""; do
    OUT="$(vga_f "$1" --series "$SG" --sprint $a 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && has "usage:" || bad=1
  done
  OUT="$(vga_f "$1" --series --sprint 322 "$SG" --sprint 322 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && has "usage:" || bad=1
  sr "$1" --sprint 322 "$SG" "$(gd s322-one)"; local before="$OUT" brc=$RC
  sr "$1" "$SG" "$(gd s322-one)" --sprint 322
  # E's own runs end in exit 2 by design, so RC is the cell's verdict here, not the last exit.
  if [ "$bad" -eq 0 ] && [ "$brc" -eq 0 ] && [ "$RC" -eq 0 ] && [ "$before" = "$OUT" ]; then RC=0; return 0; fi
  RC=1; return 1
}
sc_F() { sr "$1" --sprint 322 "$SG" "$(gd s322-legacy-after)"; [ "$RC" -eq 1 ] \
  && has "implementation-20261109T020000Z.verdict.json: carries no gate_series_id"; }
sc_F1() { sr "$1" --sprint 322 "$SG" "$(gd s322-stripped)"; [ "$RC" -eq 1 ] \
  && has "implementation-20261109T010000Z.verdict.json: carries no gate_series_id"; }
sc_F3() { sr "$1" --sprint 322 "$SG" "$(gd s322-nosprint)"; [ "$RC" -eq 1 ] && has "carries no -s<N>- sprint field"; }
sc_UR() { sr "$1" --sprint 322 "$SG" "$(gd unplaceable-recent)"; [ "$RC" -eq 1 ] \
  && has "planning-20261109T0100-arch.verdict.json: gate_nonce"; }
sc_UU() { sr "$1" --sprint 322 "$SG" "$(gd unplaceable-undated)"; [ "$RC" -eq 1 ] \
  && has "planning-20261109T0100-arch.verdict.json: gate_nonce" && has "planning-20261109T0200-arch.verdict.json: gate_nonce"; }
sc_G() { sr "$1" --sprint 322 "$SG" "$(gd s322-reset)"; [ "$RC" -eq 1 ] \
  && has "SPLIT SERIES: check '7'" && has "and 'implementation-s322-reset-20261109T030000Z'"; }
sc_H() { [ "$(hsig "$1" "$SG")" = "$H_GRAPH" ] && [ "$(hsig "$1" "$(gd graph-legacy)")" = "$H_LEGACY" ]; }

# --------------------------------------------------------------------------
# 2. series_boundary_run — a reset must not launder a live stall
# --------------------------------------------------------------------------
expect split-joined 1 'STALLED' \
  "Four consecutive FAILs under ONE series id: the ordinary rung owns this one."
expect split-defeat 1 'SPLIT SERIES' \
  "The same four FAILs with the series id changed midway. Neither half reaches K, so the
  ordinary rung is silent by construction and only the boundary arm can see it. If this
  case reports STALLED instead, the arms are entangled and one of them is vacuous."
expect split-honest-reset 0 '-' \
  "The same boundary, but the reset CLEARED the stall. Firing here would make the arm mean
  'series boundaries are illegal', which contradicts the reset semantics — minting a new id
  restarts the pass count — that the arm is supposed to leave intact."

# --------------------------------------------------------------------------
# 3. series_nonce_sortable — the nonce is the SORT KEY, not just a freshness anchor
# --------------------------------------------------------------------------
expect nonce-sortable 1 'STALLED' \
  "PASS then four FAILs: a run of 4, seen because the nonces sort chronologically."
expect nonce-unsortable 1 'does not match the required' \
  "The same five verdicts with the PASS re-nonced to '<timestamp>-arch' — the shape of the
  one non-conforming file in the reference corpus. It sorts into the middle and splits the
  run 2+2. Before this arm existed the mode returned exit 0 here: a silent skip path is a
  defeat anyone can produce by accident, and it reads exactly like a clean gate."

# --------------------------------------------------------------------------
# 4. the legacy posture — the mode's ONLY fail-open, and its boundary
# --------------------------------------------------------------------------
expect legacy-retained 0 'counted, not grouped' \
  "A prior series retained on disk after a reset — nothing is ever deleted — sorts strictly
  before the live series. It must be counted and NAMED, not silently dropped, and it must
  not block: failing closed here kills the mode at the first scan after any reset, which is
  exactly when it is meant to run."
expect legacy-interleaved 1 'falls at or after' \
  "The same legacy file moved INSIDE the live series' span. That is not a retained series,
  it is a live pass with its gate_series_id deleted — one field, and the run gets shorter.
  If the fail-open covered this case, the mechanism would ship its own opt-out."

# --------------------------------------------------------------------------
# 5. --sprint <N> — the rung scoped to one sprint's series
# --------------------------------------------------------------------------
# THE DEFECT. Unscoped, the rung reads every verdict on disk, so the reference consumer's closed
# sprints (s302-s307: 4 STALLED, 4 SPLIT SERIES, a malformed legacy nonce, a duplicated nonce)
# failed every later sprint's step 4 and its exit 0 was unreachable. Every cell below runs over
# the `graph` world -- that consumer's 187 real stems, nonces, series ids, generated_at values and
# FAIL sets, from graph-corpus.tsv -- with the cell's own world beside it as a second path, so the
# out-of-scope population is always the real one.
#   A   --sprint 302 still STALLS on implementation-s302-20260812T202738Z: the filter keeps an in-scope stall
#   B   --sprint 322 with ONE conforming s322 pass: exit 0, exactly 1 series / 1 pass, the out-of-scope count
#   C   --sprint 322 with no s322 pass: EXAMINED NOTHING naming sprint 322; the real -arch file exempt (F2)
#   D   --sprint 32 against an s322 pass selects nothing: the sprint is an exact field, never a prefix
#   E   both flag orders byte-equal; a leading zero, a non-integer and a second --sprint each exit 2
#   F   a legacy verdict sorting AFTER the first in-scope pass still blocks
#   F1  an s322 FAIL series whose first pass lost its id still blocks, judged against every sprint's series
#   F3  a series id with no -s<N>- is a defect under --sprint, never scoped out
#   UR  an unplaceable legacy nonce written after every series began still blocks (F2)
#   UU  the same with generated_at missing, and with it unparseable (F2)
#   G   a reset INSIDE sprint 322 still trips SPLIT SERIES
#   H   unscoped output is byte-identical to the BASE script's, on graph and on its legacy-only half
#       (the digests below were taken from the pre-flag validator, never from this one)
SC_CELLS='A B C D E F F1 F3 UR UU G H'
SC_RED=0
for c in $SC_CELLS; do
  if "sc_$c" "$VALIDATOR"; then ok "sprint-scope $c"
  else SC_RED=$((SC_RED + 1)); note_fail "sprint-scope $c did not hold on the shipped validator (rc=$RC).
  validator said: $(head -3 <<<"$OUT")"; fi
done
[ "$SC_RED" -eq 0 ] && ok "sprint-scope: all 12 cells hold on the shipped validator"

# --------------------------------------------------------------------------
# 6. THE PROGRAM, once per distinct CLI outcome (cells.decl cli rows). Each is `FXCELL=<id> bash <validator>` compared
# byte for byte (stdout, stderr, exit) with the in-process call on the same input, and asserts its own exit code and a
# line of output so two runs that both printed nothing cannot read as equivalent.
# --------------------------------------------------------------------------
EQ="$ROOT/.eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
eqv() { # eqv <cell-id> <rc> <marker> <args...>
  local id="$1" erc="$2" mk="$3"; shift 3
  vga_f "$VALIDATOR" "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VALIDATOR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  if cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc" \
     && [ "$(cat "$EQ/$id.cl.rc")" = "$erc" ] && grep -qF -- "$mk" "$EQ/$id.cl.out" "$EQ/$id.cl.err"; then
    ok "$id: the program exits $erc carrying '$mk', byte-identical to the in-process call"
  else
    bad "$id: the program and the in-process call differ, or the outcome is not exit $erc carrying '$mk' (in-process rc=$(cat "$EQ/$id.ip.rc"), program rc=$(cat "$EQ/$id.cl.rc"))"
  fi
}
eqv cli-series-fail 1 'STALLED' --series "$(gd stall-fires)"
eqv cli-series-pass 0 'PASS' --series "$(gd stall-silent)"
eqv cli-series-usage 2 'usage:' --series "$SG" --sprint 0322

echo
report_end gate-series-rung
