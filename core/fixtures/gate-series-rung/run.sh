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
# THE MUTANT MATRIX. A cell is one waiver case (W1 waived-x3, W2 waived-then-fail, W3 unresolved-x3), GREEN
# on a validator when it gives the unmutated verdict for that case and RED when it does not. A mutant's row
# names the cell that kills it (decides) and the cell it could plausibly co-trip but must leave GREEN (twins).
# A plain run drives each mutant on its deciding cell and its twin only. W-MK also moves W2 (the run would
# start at pass 1, not pass 4); W2 is a second arm that kills it, so it is not a twin and is measured only
# by the REMEASURE command. The matrix is re-measured whenever an arm or a mutant is added or changed, by the
# command below, run from the repo root. It drives every mutant on every cell and prints one MATRIX line each.
# MUTANT-MATRIX W-MK decides=W1 twins=W3
# MUTANT-MATRIX W-MA decides=W3 twins=W1
# MUTANT-MATRIX-REMEASURE bash core/fixtures/gate-series-rung/run.sh --matrix
set -u
# MODE is "matrix" only under the positional `--matrix`; an AI_DLC_* name would be scrubbed below. Anything else
# as an argument is a usage error, never a silent plain run.
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "gate-series-rung: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac
# Scrub ambient AI_DLC_* — the validator reads AI_DLC_VERDICT_SCHEMA and AI_DLC_STATE_DIR,
# and a consumer that tunes either in settings.json would otherwise fail this against
# correct code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
DIR="$(cd "$(dirname "$0")" && pwd)"
SELF_FILE="$DIR/${0##*/}"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-gate-adjudication.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-gate-adjudication.sh" \
  "$DIR/../../core/scripts/validate-gate-adjudication.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FIXTURE BROKEN: cannot locate validate-gate-adjudication.sh from $DIR"; exit 2; }
# The REQUIRED input of inputs.decl: every case below drives this file.
echo "HERMETIC-CONSUMED core/scripts/validate-gate-adjudication.sh"

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "FIXTURE BROKEN: seed.sh produced no root"; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

ASSERTIONS=0
FAILURES=0
note_fail() { echo "FAIL: $*"; FAILURES=$((FAILURES + 1)); }
gd() { printf '%s/%s/_bmad-output/gate-adjudication' "$ROOT" "$1"; }
# lib/mutant.sh needs ok() and bad() defined first; a kill is emitted only through mutant_killed.
ok()  { printf 'ok: %s\n' "$1"; }
bad() { note_fail "$1"; }
MUT_LIB="$(cd "$DIR/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $DIR"; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# Run a case; set RC and OUT.
run_case() { OUT="$(bash "$VALIDATOR" --series "$(gd "$1")" 2>&1)"; RC=$?; }

# expect <case> <rc> <marker|-> <human name>
expect() {
  ASSERTIONS=$((ASSERTIONS + 1))
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
  fi
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

ASSERTIONS=$((ASSERTIONS + 1))
if ! diff -q <(payloads "$(gd split-joined)") <(payloads "$(gd split-defeat)") >/dev/null; then
  note_fail "split-joined and split-defeat do NOT carry byte-identical verdict payloads.
  The entire claim of that pair is that gate_series_id is the ONLY difference; with a second
  one present, a validator could separate them by reading the verdicts and the boundary arm
  would score as held without existing."
fi

ASSERTIONS=$((ASSERTIONS + 1))
if ! diff -q <(payloads "$(gd nonce-sortable)") <(payloads "$(gd nonce-unsortable)") >/dev/null; then
  note_fail "nonce-sortable and nonce-unsortable do NOT carry byte-identical verdict payloads.
  That pair asserts the NONCE alone re-sequences the run; a verdict-value difference would
  prove the ordinary stall rung instead."
fi

# The intended difference must actually be present, or a pair is one case twice.
ASSERTIONS=$((ASSERTIONS + 1))
n_sids="$(python3 -c '
import json,glob,sys
print(len({json.load(open(f))["gate_series_id"] for f in glob.glob(sys.argv[1]+"/*.json")}))' "$(gd split-defeat)")"
[ "$n_sids" = "2" ] || note_fail "split-defeat carries $n_sids distinct gate_series_id(s); expected 2.
  The independent variable is not set, so it is split-joined twice."

# K IS PINNED HERE. If K changes, this assertion tells you, instead of the silent cases
# quietly going red and being blamed on whatever else changed.
ASSERTIONS=$((ASSERTIONS + 1))
run_case stall-fires
if ! grep -q 'across 3 consecutive passes' <<<"$OUT"; then
  note_fail "the stall rung did not report a threshold of 3. This fixture's silent cases are
  built one short of K=3; a different K makes them meaningless rather than wrong, so the
  threshold is asserted here explicitly."
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
# W1 is ABSENCE-shaped (exit 0, no STALLED), so it carries the committed mutant W-MK below, which
# must turn it into a STALLED on check 7. W2 is PRESENCE-shaped and pins WHERE the new run starts:
# pass 2's nonce through pass 4's, at pass 4. A rung that kept the waiver in the run reports from
# pass 1 at pass 3 instead.
W2_SPAN='story-20260811T180200Z → story-20260811T180400Z (pass 4 of 4'
# The waiver cases name their own escalations file and root, so the sibling reads the seeded entry
# and never the repo's or the sandbox's.
w_series() { # <validator> <case> -> OUT RC
  OUT="$(AI_DLC_PROJECT_ROOT="$ROOT/$2" AI_DLC_ESCALATIONS="$ROOT/$2/docs/escalations/pending.md" \
    bash "$1" --series "$(gd "$2")" 2>&1)"; RC=$?; }
w_p1() { w_series "$1" waived-x3
  [ "$RC" -eq 0 ] && ! grep -q 'STALLED' <<<"$OUT"; }
w_p2() { w_series "$1" waived-then-fail
  [ "$RC" -eq 1 ] && grep -qF "$W2_SPAN" <<<"$OUT"; }
w_p3() { w_series "$1" unresolved-x3
  [ "$RC" -eq 1 ] && grep -q "STALLED: series .* check '7' has held FAIL across 3" <<<"$OUT"; }
ASSERTIONS=$((ASSERTIONS + 1))
W_BASE=0
if w_p1 "$VALIDATOR"; then W_BASE=1; else
  note_fail "waived-x3 (check 7 FAIL_WAIVED on three consecutive passes, waiver RESOLVES) exited $RC or
  reported STALLED. A FAIL_WAIVED under a resolving waiver breaks the check's run.
  validator said: $(head -3 <<<"$OUT")"; fi
ASSERTIONS=$((ASSERTIONS + 1))
if ! w_p2 "$VALIDATOR"; then W_BASE=0
  note_fail "waived-then-fail (FAIL_WAIVED, FAIL, FAIL, FAIL) did not stall with the run starting
  AFTER the waiver ('$W2_SPAN'). A later FAIL starts a new run from 1.
  validator said: $(head -3 <<<"$OUT")"; fi
ASSERTIONS=$((ASSERTIONS + 1))
if ! w_p3 "$VALIDATOR"; then W_BASE=0
  note_fail "unresolved-x3 (three FAIL_WAIVED under a waiver_id naming no entry) did not STALL. A
  FAIL_WAIVED whose waiver does not resolve continues the run as FAIL.
  validator said: $(head -3 <<<"$OUT")"; fi

# --- the matrix cells. cell_green <cell> <validator>: 0 when the validator gives the UNMUTATED verdict for the
# waiver case (GREEN), 1 when it does not (RED), 2 for an UNKNOWN CELL (an unknown name must never read as GREEN).
cell_green() {
  case "$1" in W1) w_p1 "$2" ;; W2) w_p2 "$2" ;; W3) w_p3 "$2" ;; *) return 2 ;; esac
}
MX_CELLS='W1 W2 W3'
# The header IS the decides/twins list: nothing else in this file restates it.
mx_row() { # mx_row <mutant> <decides|twins>
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$SELF_FILE"
}
MXL="$ROOT/.mx.ledger"; : > "$MXL"
MX_FAILS=0
# mx_twins <mutant> <validator>: per-push, every twin cell must stay GREEN on the mutated validator. W-MA's twin (W1)
# is already driven by its kill chain, so W-MA does not call this.
mx_twins() {
  local m="$1" v="$2" tw t r
  tw="$(mx_row "$m" twins)"
  if [ -z "$tw" ]; then note_fail "$m: no single MUTANT-MATRIX row names its twins"; return; fi
  printf 'plain-twins %s\n' "$m" >> "$MXL"
  ASSERTIONS=$((ASSERTIONS + 1))
  for t in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_green "$t" "$v"; r=$?
    if [ "$r" -eq 2 ]; then note_fail "$m: twin $t names no cell"
    elif [ "$r" -ne 0 ]; then note_fail "$m: its twin $t also changed on this mutant, so the kill is not confined to its own cell"; fi
  done
}
# mx_score <mutant> <validator>: MATRIX-ONLY. Drives the mutated validator on EVERY cell. It records itself in the
# ledger first (rule 9).
mx_score() {
  local m="$1" v="$2" dec tw c r uex="" dl="" tl="" g=0 tot=0
  printf 'mx-score %s\n' "$m" >> "$MXL"
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  for c in $(printf '%s' "$dec" | tr ',' ' '); do
    cell_green "$c" "$v"; r=$?
    if [ "$r" -ne 0 ]; then dl="$dl,$c:RED"; else dl="$dl,$c:GREEN"; uex="$uex $c:GREEN"; fi
    case "$RC" in 0|1) ;; *) echo "MATRIX BROKEN $m"; exit 2 ;; esac
  done
  for c in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_green "$c" "$v"; r=$?
    if [ "$r" -ne 0 ]; then tl="$tl,$c:RED"; uex="$uex $c:RED"; else tl="$tl,$c:GREEN"; fi
    case "$RC" in 0|1) ;; *) echo "MATRIX BROKEN $m"; exit 2 ;; esac
  done
  for c in $MX_CELLS; do
    case ",$dec,$tw," in *",$c,"*) continue ;; esac
    cell_green "$c" "$v"; r=$?
    case "$RC" in 0|1) ;; *) echo "MATRIX BROKEN $m"; exit 2 ;; esac
    tot=$((tot + 1)); [ "$r" -eq 0 ] && g=$((g + 1))
  done
  # Not-decides, not-twin cells are reported as the count that stayed GREEN; W-MK is expected to move W2 (see header).
  if [ -n "$uex" ]; then
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d UNEXPECTED=%s\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot" "$(printf '%s' "${uex# }" | tr ' ' ',')"
    MX_FAILS=$((MX_FAILS + 1))
  else
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot"
  fi
}

# W-MK: the waiver kept in the run (the pre-fix predicate). Built in a copy beside the sibling the
# repair arm resolves, schema and map passed explicitly, and an unmutated control from the same
# directory scored first. Gated on W_BASE: the arms passed unmutated in this run.
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$W_BASE" -ne 1 ]; then
  note_fail "W-MK not scored: W1/W2 did not pass unmutated in this run, so a mutant verdict would not be about its mutation"
else
  VD="$(dirname "$VALIDATOR")"
  W_SCHEMA=""; W_MAP=""
  # Rooted at the fixture's own directory and naming BOTH layouts (I33b): core/schemas and
  # core/skills here, .claude/schemas and .claude/skills on a consumer.
  for c in "$DIR/../../schemas" "$DIR/../../../.claude/schemas"; do
    [ -f "$c/gate-adjudication-verdict.json" ] && { W_SCHEMA="$c/gate-adjudication-verdict.json"; break; }; done
  for c in "$DIR/../../skills/ai-dlc" "$DIR/../../../.claude/skills/ai-dlc"; do
    [ -f "$c/enforcement-map.yaml" ] && { W_MAP="$c/enforcement-map.yaml"; break; }; done
  WM="$ROOT/.w-mk"   # under the seeded root, so the EXIT trap clears it
  # The copy carries every sibling the validator resolves beside itself: the repair-arm reader AND
  # the --waivers owner. Without the second, every FAIL_WAIVED would read as unresolvable in the
  # copy and W1 would fail for a reason that has nothing to do with the mutation.
  mkdir -p "$WM/ctl" "$WM/mk" "$WM/ma"
  for s in validate-gate-adjudication.sh gate_adjudication.py validate-adversarial-convergence.sh validate-suppression-lifetime.sh; do
    cp "$VD/$s" "$WM/ctl/" && cp "$VD/$s" "$WM/mk/" && cp "$VD/$s" "$WM/ma/"; done
  # W-MK keeps FAIL_WAIVED in the run (the pre-D1 predicate); W-MA breaks the run on ANY
  # FAIL_WAIVED, resolved or not (the first D1 cut, before the ruling).
  # The mutations edit gate_adjudication.py, where the program text lives since the heredoc moved out.
  python3 - "$WM/mk/gate_adjudication.py" "$WM/ma/gate_adjudication.py" <<'PY'
import sys
for p, old, new in (
    (sys.argv[1],
     '                if vd == "FAIL":\n                    run[cid] = run.get(cid, 0) + 1',
     '                if vd in ("FAIL", "FAIL_WAIVED"):\n                    run[cid] = run.get(cid, 0) + 1'),
    (sys.argv[2],
     '                    if not waiver_covers(series_waivers.get(wid), wid, v_sprint, v_catalog, cid_s):',
     '                    if False:'),
):
    t = open(p, encoding="utf-8").read()
    if t.count(old) == 1:
        open(p, "w", encoding="utf-8").write(t.replace(old, new))
PY
  if [ -z "$W_SCHEMA" ] || [ -z "$W_MAP" ] || [ ! -f "$WM/ctl/validate-adversarial-convergence.sh" ] \
     || [ ! -f "$WM/ctl/validate-suppression-lifetime.sh" ] || [ ! -f "$WM/ctl/gate_adjudication.py" ]; then
    note_fail "W-MK/W-MA harness broken: schema '$W_SCHEMA', map '$W_MAP', the repair-arm sibling or the --waivers sibling is missing from the copy"
  elif cmp -s "$WM/ctl/gate_adjudication.py" "$WM/mk/gate_adjudication.py"; then
    note_fail "W-MK DID NOT APPLY: the run predicate anchor is absent or not unique, so the mutant is byte-identical to the control"
  elif cmp -s "$WM/ctl/gate_adjudication.py" "$WM/ma/gate_adjudication.py"; then
    note_fail "W-MA DID NOT APPLY: the waiver_covers anchor is absent or not unique, so the mutant is byte-identical to the control"
  else
    export AI_DLC_VERDICT_SCHEMA="$W_SCHEMA" AI_DLC_ENFORCEMENT_MAP="$W_MAP"
    if ! w_p1 "$WM/ctl/validate-gate-adjudication.sh" || ! w_p2 "$WM/ctl/validate-gate-adjudication.sh" \
       || ! w_p3 "$WM/ctl/validate-gate-adjudication.sh"; then
      note_fail "W-MK/W-MA control: the UNMUTATED copy failed W1, W2 or W3, so the copy is not the program
  validator said: $(head -3 <<<"$OUT")"
    else
      if w_p1 "$WM/mk/validate-gate-adjudication.sh"; then
        note_fail "W-MK SURVIVED: with FAIL_WAIVED kept in the stall run, waived-x3 still did not stall — W1 watches nothing"
      elif ! grep -q "STALLED: series .* check '7' has held FAIL across 3" <<<"$OUT"; then
        note_fail "W-MK died on W1 for the wrong reason (no STALLED on check 7): $(head -3 <<<"$OUT")"
      else
        mutant_killed "$W_BASE" W-MK "W-MK (FAIL_WAIVED kept in the stall run) KILLED by W1 — waived-x3 reports STALLED on check 7"
      fi
      mx_twins W-MK "$WM/mk/validate-gate-adjudication.sh"
      if [ "$MODE" = matrix ]; then mx_score W-MK "$WM/mk/validate-gate-adjudication.sh"; fi
      ASSERTIONS=$((ASSERTIONS + 1))
      if w_p3 "$WM/ma/validate-gate-adjudication.sh"; then
        note_fail "W-MA SURVIVED: with ANY FAIL_WAIVED breaking the run, unresolved-x3 still stalled — W3 watches nothing"
      elif [ "$RC" -ne 0 ] || grep -q 'STALLED' <<<"$OUT"; then
        note_fail "W-MA died on W3 for the wrong reason (rc=$RC, expected a silent exit 0): $(head -3 <<<"$OUT")"
      elif ! w_p1 "$WM/ma/validate-gate-adjudication.sh"; then
        note_fail "W-MA also moved W1, so W3 is not the arm that owns it"
      else
        mutant_killed "$W_BASE" W-MA "W-MA (ANY FAIL_WAIVED breaks the run) KILLED by W3 — unresolved-x3 goes silent, W1 unchanged"
      fi
      # W-MA's twin W1 was driven on this mutant in the chain above; it is not re-run here.
      printf 'plain-twins W-MA\n' >> "$MXL"
      if [ "$MODE" = matrix ]; then mx_score W-MA "$WM/ma/validate-gate-adjudication.sh"; fi
    fi
    unset AI_DLC_VERDICT_SCHEMA AI_DLC_ENFORCEMENT_MAP
  fi
fi

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
# RULE 9: a plain run executes NO matrix-only cell. Every matrix-only score appends `mx-score` to the ledger before
# anything else; the per-push twin check appends `plain-twins` to the SAME ledger. That second line is the CONTROL:
# it must be present, so a zero count of matrix-only cells cannot come from a ledger nothing writes.
mx_only="$(grep -c '^mx-score ' "$MXL")" || mx_only=0
mx_ctl="$(grep -c '^plain-twins ' "$MXL")" || mx_ctl=0
if [ "$MODE" = plain ]; then
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$mx_ctl" -eq 0 ]; then note_fail "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells would mean nothing"
  elif [ "$mx_only" -ne 0 ]; then note_fail "rule-9: a plain run executed $mx_only matrix-only cell(s), so the --matrix measurement leaked into the per-push run"
  else echo "ok: rule-9: a plain run executed no matrix-only cell, while its $mx_ctl per-push twin check(s) wrote to the same ledger"; fi
else
  mx_hdr="$(awk '$1 == "#" && $2 == "MUTANT-MATRIX" { print $3 }' "$SELF_FILE" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$mx_hdr" = "W-MA W-MK " ] || { echo "MATRIX BROKEN: the header rows are [$mx_hdr]"; exit 2; }
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran, $mx_ctl per-push twin check(s)"
  FAILURES=$((FAILURES + MX_FAILS))
fi
echo
if [ "$FAILURES" -eq 0 ]; then
  echo "ok: gate-series-rung — $ASSERTIONS assertion(s); the stall rung, the boundary arm,"
  echo "    the nonce sort key and both halves of the legacy posture each fire and each stay"
  echo "    silent on the case that must not fire."
  exit 0
fi
echo "FAILED: gate-series-rung — $FAILURES of $ASSERTIONS assertion(s)" >&2
exit 1
