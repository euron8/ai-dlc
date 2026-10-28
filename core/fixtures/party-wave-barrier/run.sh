#!/usr/bin/env bash
# party-wave-barrier -- bind scripts/audit-party-wave-barrier.sh (BL-695): it must FIRE when a round
# member's exit was DELIVERED with a slot free and round members still undispatched and the lead's
# response dispatched nothing for the round, stay QUIET on slot-on-exit refill and when the slots were
# full at the delivery, report an unknown cap apart from findings and LOUDLY, and refuse an empty or
# unreadable transcript list.
#
# Every transcript is seeded under mktemp with the detector's own --seed shapes, so the seeds are the
# records the self-probe replays; the cases this fixture adds beyond them are derived here:
#   (a) cap 4 env; Dev 01's delivery answered by --status only    -> rc 1, one FINDING, idle 3
#   (b) refill on exit, with the barrier SENTENCE as prose         -> rc 0, no FINDING, 4 agents parsed
#   (c) cap 2 from a rejection; the held spawn re-sent and rejected -> rc 0, 2 batches judged
#   (d) unknown cap                                                -> rc 0, one UNKNOWN-CAP, the loud line
#   (e) four 25-member seat waves, cap 42 env                      -> rc 1, exactly 3 FINDINGs, idle 18
#   (f) X6, cap 4 by printenv, full at the beat; 3 exits left idle  -> rc 1, one FINDING, idle 1
#   (g) X6 reversed, each delivery refilled                        -> rc 0, 5 batches
#   (h) X2, no beat; one delivery by the attachment carrier        -> rc 1, one FINDING, unrefilled 3
#   (i) X1 / (j) X1b, stragglers still running                     -> rc 1, one FINDING each
#   (k) X3, beat then refill in the same turn                      -> rc 0
#   (l) X4, four exits, four refills                               -> rc 0
#   (m) slots full at the delivery (refill raced ahead of it)      -> rc 0, SLOTS-FULL traced
#   (n) a MISSING re-send, no new member after                     -> rc 0, 1 batch
#   (o) a hook-denied Architect 01, later re-sent and launched     -> rc 1, one FINDING, running 1 idle 3
#   (p) cap 3 by rejection, two rejected spawns held across an exit -> rc 1, one FINDING, running 1 idle 2
#   (q) a refill with a compaction summary between delivery and refill -> rc 0
#   (q') (q) with that record flagged isMeta (Stop-hook feedback)  -> rc 1: isMeta still ends a turn
#   (r) a sidechain Agent call naming a round path after a delivery -> rc 1, one FINDING
#   (s) two rejection caps, 5 then 3                               -> rc 1, the lower 3 wins, idle 1
#   (t) a delivery answered only by non-seat calls citing round paths -> rc 1, one FINDING, 7 agents
#   (BL-732) graph a367e62c's shape: 2 remediator calls citing party-mode/s900/stories-sm-0N.md as INPUT
#       -> STAT rounds=0; its twin, one property apart (subagent_type sm), -> rounds=1; an adversary or
#       general-purpose agent citing the same files -> rounds=0; graph's real seat prompt (`Deliverable:`,
#       no write verb) -> rounds=1; an architect cross seat citing stories-dev-01.md before its own file
#       -> rounds=1
#   (c') (c) with an env line of 4 as well                         -> the rejection's 2 wins
#   (b') (b) with a cap written only as assistant prose            -> the prose value is not read
#   (a+b) a two-transcript list with the firing one SECOND -> rc 1, given=2 scanned=2
#   empty list -> rc 2; unreadable path -> rc 2; an empty file -> rc 2, scanned 0 of 1
#   --cap on (d) -> fires: the option is a cap source
#
#
# COST. The detector replays a 20-case self-probe (wave_selfprobe, ~1.6s) on every call that names a
# transcript. The arms below ask about the DETECTOR'S REPLAY, not about its self-probe, so they run a
# BASE copy of the shipped detector with exactly that one call line replaced (BASE_DET). The copy is
# bound to the shipped file three ways: it differs from it by exactly one line, the shipped detector's
# own self-probe passes end to end, and the shipped detector and the copy print byte-identical stdout
# and (self-probe line aside) stderr over a two-transcript list. The shipped detector is therefore
# run twice per push; every mutant arm and every base arm runs the copy at ~0.06s a call.
#
# MUTANTS, each a copy of the detector with the self-probe call removed, guarded by an exact anchor
# count and `cmp -s`. Each mutant is driven through its DECIDING arm (which must FAIL under it) and its
# named TWIN arm(s) (which must HOLD), and its kill is emitted through mutant_killed behind the
# same-run base-pass flags of those very arms. M1 additionally keeps one end-to-end self-probe
# refusal per push, as the representative; for the other mutants the probe cell lives in the matrix.
#   M1  the free-slot test removed                 M2  a dispatch no longer answers a delivery
#   M3  an unknown cap judged as a finding         M4  an empty corpus returns 0
#   M5  the cap read from assistant prose          M6  the attachment delivery carrier dropped
#   M7  the user delivery carrier dropped          M8  an enqueue judged as a delivery
#   M9  the response cut to the next assistant record (no turn)
#   M10 a rejected call no longer answers          M11 a re-send counted as a new member
#   M12 the printenv cap source dropped            M13 the round's last stretch judged too
#   M14 the environment ranked above the rejection M15 the loud unknown-cap line silenced
#   MB  rejected spawns counted as RUNNING         ME  two cap values take the HIGHER
#   MF  the isSidechain filter removed             MD  error results dropped by the prefilter
#   MC  a compaction summary ends a turn again
#   MK  the member key reverted to "first cited path, any subagent_type" (the BL-732 defect); the
#       former MK-arm was this same mutation scored on the rem/adv/gp cells, which are now MK's
#       decides arms, so it has no row of its own
#   MX  the member key is the FIRST cited path's seat only (MC is taken, so this one is MX)
#
# MATRIX. Measured by `bash core/fixtures/party-wave-barrier/run.sh --matrix`: every mutant against
# every base arm (plus the `probe` cell, the mutant with its self-probe left in). A cell is FAIL when
# the arm fails under the mutant. decides = the arm that kills it; twins = arms that stay green under
# it. Re-measured whenever an arm or a mutant is added or changed.
# MUTANT-MATRIX M1 decides=m twins=l
# MUTANT-MATRIX M2 decides=b twins=a
# MUTANT-MATRIX M3 decides=d twins=dcap
# MUTANT-MATRIX M4 decides=refuse-empty twins=refuse-unread
# MUTANT-MATRIX M5 decides=bprose twins=b
# MUTANT-MATRIX M6 decides=h twins=i
# MUTANT-MATRIX M7 decides=a twins=n
# MUTANT-MATRIX M8 decides=g twins=l
# MUTANT-MATRIX M9 decides=k twins=l
# MUTANT-MATRIX M10 decides=c twins=b
# MUTANT-MATRIX M11 decides=n twins=m
# MUTANT-MATRIX M12 decides=f twins=g
# MUTANT-MATRIX M13 decides=e twins=g
# MUTANT-MATRIX M14 decides=cenv twins=c
# MUTANT-MATRIX M15 decides=d twins=dcap
# MUTANT-MATRIX MB decides=p twins=o
# MUTANT-MATRIX ME decides=s twins=p
# MUTANT-MATRIX MF decides=r twins=a
# MUTANT-MATRIX MD decides=o twins=p
# MUTANT-MATRIX MC decides=q twins=qmeta
# MUTANT-MATRIX MK decides=t twins=remseat
# MUTANT-MATRIX MX decides=cross twins=remseat
# MUTANT-MATRIX-DYNAMIC score why=every mutant is passed to mutant_killed by name from the one score() driver
# MUTANT-MATRIX-REMEASURE bash core/fixtures/party-wave-barrier/run.sh --matrix
#
# Exit: 0 = every assertion holds, 1 = an assertion failed, 2 = the fixture could not run.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
set -uo pipefail
# --matrix is parsed and shifted first. A plain run executes no matrix-only cell (asserted at the end).
MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; shift; echo "MATRIX-MODE on"; fi
MATRIX_CELLS=0

HERE="$(cd "$(dirname "$0")" && pwd)"
# Both layouts named, never a single walk-up (I33c). The subject is distribution-only.
ROOT=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/scripts/audit-party-wave-barrier.sh" ]; then ROOT="$(cd "$cand" && pwd -P)"; break; fi
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: could not locate scripts/audit-party-wave-barrier.sh from $HERE" >&2; exit 2; }
DET="$ROOT/scripts/audit-party-wave-barrier.sh"
echo "HERMETIC-CONSUMED scripts/audit-party-wave-barrier.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pwb-fx.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if grep -qF -- "$3" <<<"$2"; then ok "$1"; else bad "$1 (absent: $3)"; fi; }
hasnt() { if grep -qF -- "$3" <<<"$2"; then bad "$1 (present: $3)"; else ok "$1"; fi; }
MUT_LIB="$ROOT/core/fixtures/lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found at $MUT_LIB" >&2; exit 2; }
. "$MUT_LIB"
echo "party-wave-barrier:"

# --- seeds ---------------------------------------------------------------------------------------
CASES="a b c d e f g h i j k l m n o p q r s t"
T="$WORK/t"; mkdir -p "$T" || exit 2
for c in $CASES; do
  bash "$DET" --seed "$c" "$T/$c.jsonl" || { echo "FIXTURE ERROR: the detector could not write seed $c" >&2; exit 2; }
  [ -s "$T/$c.jsonl" ] || { echo "FIXTURE ERROR: seed $c is empty" >&2; exit 2; }
done
# (b) carries the barrier sentence as prose; the arm below needs it present to mean anything.
grep -qF 'join each wave before the next wave spawns' "$T/b.jsonl" || { echo "FIXTURE ERROR: seed (b) lost its barrier prose" >&2; exit 2; }
# No seed writes the notification envelope tag: exit records are read by their fields. The control is
# that the same search finds the body's children.
n="$(grep -c 'task-notification>' "$T"/*.jsonl | grep -vc ':0$')" || n=0
eq "seeds: no seed carries the envelope tag" "$n" 0
n="$(grep -c '<task-id>' "$T/a.jsonl")" || n=0
[ "$n" -gt 0 ] && ok "seeds control: (a) carries <task-id> children ($n)" || bad "seeds control: (a) carries no <task-id>"
# (b') refill with an env cap written only as assistant PROSE (M5's subject); its real cap line is 2.
sed 's|"text":"The other three seats|"text":"CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=42\\nThe other three seats|' "$T/b.jsonl" > "$T/bprose.jsonl"
cmp -s "$T/b.jsonl" "$T/bprose.jsonl" && { echo "FIXTURE ERROR: seed (b') did not apply" >&2; exit 2; }
# (c') (c) with an env line of 4 ahead of it (M14's subject): rejection 2 and env 4 disagree.
bash "$DET" --seed a "$T/a-env.jsonl" || exit 2
head -n 2 "$T/a-env.jsonl" > "$T/cenv.jsonl" && cat "$T/c.jsonl" >> "$T/cenv.jsonl" || exit 2
grep -qF 'CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=4"' "$T/cenv.jsonl" || { echo "FIXTURE ERROR: seed (c') carries no env line of 4" >&2; exit 2; }
: > "$T/empty.jsonl"
# BL-732 seeds: two launched Agent calls, each naming party-mode/s900/stories-<seat>-0N.md.
# bl732_seed <out> <subagent_type> <prompt before the path> <seat> [<text after the path>]
bl732_seed() {
  local i; : > "$1" || return 1
  for i in 1 2; do
    printf '%s\n' '{"type":"assistant","timestamp":"2026-01-01T10:00:0'"$i"'.000Z","message":{"id":"m'"$i"'","role":"assistant","content":[{"type":"tool_use","id":"tu'"$i"'","name":"Agent","input":{"subagent_type":"'"$2"'","description":"call 0'"$i"'","prompt":"'"$3"'_bmad-output/party-mode/s900/stories-'"$4"'-0'"$i"'.md'"${5:-}"'","run_in_background":true}}]}}' \
      '{"type":"user","timestamp":"2026-01-01T10:00:0'"$i"'.500Z","message":{"role":"user","content":[{"tool_use_id":"tu'"$i"'","type":"tool_result","content":[{"type":"text","text":"Async agent launched successfully.\nagentId: ag'"$i"'"}]}]},"toolUseResult":{"isAsync":true,"status":"async_launched","agentId":"ag'"$i"'"}}' >> "$1" || return 1
  done
}
bl732_seed "$T/rem.jsonl" remediator 'part path: _bmad-output/planning-artifacts/s900/shards/stories-party-repair-p1/x.md\nYour findings: every finding in ' sm || exit 2
sed 's|"subagent_type":"remediator"|"subagent_type":"sm"|' "$T/rem.jsonl" > "$T/remseat.jsonl"
cmp -s "$T/rem.jsonl" "$T/remseat.jsonl" && { echo "FIXTURE ERROR: seed (BL-732 seat twin) did not apply" >&2; exit 2; }
bl732_seed "$T/adv.jsonl" adversary 'Your findings: every finding in ' sm || exit 2
bl732_seed "$T/deliv.jsonl" architect 'Deliverable: `' architect '`' || exit 2
bl732_seed "$T/gp.jsonl" general-purpose 'Summarise every finding in ' sm || exit 2
# A cross seat whose FIRST cited party-mode path is another seat's file: it is still its own seat.
bl732_seed "$T/cross.jsonl" architect 'Read _bmad-output/party-mode/s900/stories-dev-01.md first.\nWrite your findings file at: ' architect-cross || exit 2
grep -qF 'stories-dev-01.md first.' "$T/cross.jsonl" && grep -qF 'stories-architect-cross-02.md' "$T/cross.jsonl" || { echo "FIXTURE ERROR: seed (BL-732 cross) lost its shape" >&2; exit 2; }
# (q') the same record flagged isMeta (Stop-hook feedback) instead: that follows an end_turn, so it DOES
# start a turn and the refill after it is a new response. The exemption is compaction-only.
sed 's|"isCompactSummary":true|"isMeta":true|' "$T/q.jsonl" > "$T/qmeta.jsonl"
cmp -s "$T/q.jsonl" "$T/qmeta.jsonl" && { echo "FIXTURE ERROR: seed (q') did not apply" >&2; exit 2; }

# ADET is the detector the arms below drive: BASE_DET live, a mutant's copy when scored.
# R_OUT, R_ERR, R_RC: run <detector> <args...>
run() { local d="$1"; shift; R_OUT="$(bash "$d" "$@" 2>"$WORK/err")"; R_RC=$?; R_ERR="$(cat "$WORK/err")"; }
nfind() { local n; n="$(grep -c '^FINDING ' <<<"$R_OUT")" || n=0; printf '%s' "$n"; }
nunk()  { local n; n="$(grep -c '^UNKNOWN-CAP ' <<<"$R_OUT")" || n=0; printf '%s' "$n"; }
rfu() { printf '%s/%s/%s' "$R_RC" "$(nfind)" "$(nunk)"; }
# bl732_rounds <seed>: prints the STAT rounds count, or NONE when no STAT line was printed.
bl732_rounds() { run "$ADET" --trace "$1"; sed -n 's/.* STAT rounds=\([0-9]*\) .*/\1/p' <<<"$R_ERR" | head -n 1 | grep . || echo NONE; }

# --- the BASE detector and its binding to the shipped one ----------------------------------------
# BASE_DET is the shipped detector with ONE line changed: the call that replays the self-probe. Built
# with sed on a line-anchored literal, counted first, so a moved call is an error and not a no-op.
NP_LINE='wave_selfprobe || exit 2'
n="$(grep -cxF -- "$NP_LINE" "$DET")" || n=0
[ "$n" = 1 ] || { echo "FIXTURE ERROR: the detector carries the self-probe call line $n times, want 1" >&2; exit 2; }
BASE_DET="$WORK/base-np.sh"
sed 's#^wave_selfprobe || exit 2$#: wave_selfprobe skipped#' "$DET" > "$BASE_DET" || exit 2
cmp -s "$DET" "$BASE_DET" && { echo "FIXTURE ERROR: the base copy equals the shipped detector" >&2; exit 2; }
n1="$(grep -cvxFf "$DET" "$BASE_DET")" || n1=0
n2="$(grep -cvxFf "$BASE_DET" "$DET")" || n2=0
eq "base copy differs from the shipped detector by exactly one line (copy side, shipped side)" "$n1/$n2" "1/1"

# Control: the SHIPPED detector's self-probe, end to end. Run once; it is the only per-push self-probe
# replay besides the two below.
PROBE_OK='self-probe: ok (20 cases)'
run "$DET" "$T/a.jsonl"
if ! grep -qF "$PROBE_OK" <<<"$R_ERR"; then
  echo "FIXTURE BROKEN: the unmutated detector's self-probe did not pass; no verdict below would mean anything" >&2
  printf '%s\n' "$R_ERR" | head -10 >&2; exit 2
fi
eq "control: the shipped detector with its self-probe exits 1 on (a)" "$R_RC" 1
has "control: the shipped detector prints one FINDING on (a)" "$R_OUT" "FINDING a.jsonl "
# The positive baseline of the copy, run once: it must print the same rows as the shipped detector.
S_OUT="$R_OUT"; S_RC="$R_RC"; S_ERR="$(grep -vF 'self-probe: ok' <<<"$R_ERR")"
run "$BASE_DET" "$T/a.jsonl"
eq  "baseline: the base copy and the shipped detector exit alike on (a)" "$R_RC" "$S_RC"
eq  "baseline: the base copy and the shipped detector print the same stdout on (a)" "$R_OUT" "$S_OUT"
eq  "baseline: the base copy and the shipped detector print the same stderr on (a), self-probe line aside" "$R_ERR" "$S_ERR"
has "baseline: the base copy prints the FINDING row, so it ran" "$R_OUT" "FINDING a.jsonl "
run "$DET" --trace "$T/b.jsonl" "$T/a.jsonl"
S_OUT="$R_OUT"; S_RC="$R_RC"; S_ERR="$(grep -vF 'self-probe: ok' <<<"$R_ERR")"
run "$BASE_DET" --trace "$T/b.jsonl" "$T/a.jsonl"
eq  "baseline: the same over a traced two-transcript list (exit)" "$R_RC" "$S_RC"
eq  "baseline: the same over a traced two-transcript list (stdout)" "$R_OUT" "$S_OUT"
eq  "baseline: the same over a traced two-transcript list (stderr)" "$R_ERR" "$S_ERR"

# --- base arms -----------------------------------------------------------------------------------
# Every arm is a function over the global ADET, so the live pass and a mutant score the same code.
arm_a() {
  run "$ADET" "$T/a.jsonl"
  eq  "a: an exit answered by --status only exits 1" "$R_RC" 1
  eq  "a: exactly one FINDING" "$(nfind)" 1
  has "a: the finding names round, batch, exit, idle slots and the gap" "$R_OUT" "round=s900/stories batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:07:00.000Z running=1 cap=4 idle=3 gap=120s unrefilled=1"
  has "a: the summary counts one scanned of one given" "$R_ERR" "given=1 scanned=1 rounds=1 batches=2 findings=1 unknown-cap=0"
}
arm_b() {
  run "$ADET" "$T/b.jsonl"
  eq  "b: refill on exit exits 0" "$(rfu)" "0/0/0"
  has "b: the refill transcript was parsed (one round, three batches)" "$R_ERR" "given=1 scanned=1 rounds=1 batches=3 findings=0 unknown-cap=0"
  run "$ADET" --trace "$T/b.jsonl"
  has "b: --trace scores Dev 02's delivery REFILLED" "$R_OUT" "DELIVERED exit=2026-01-01T10:06:00.000Z running=1 cap=2 REFILLED"
  has "b: --trace reports 4 agents and the cap of 2" "$R_ERR" "agents=4 cap=2 capsrc=env"
}
arm_c() {
  run "$ADET" "$T/c.jsonl"
  eq  "c: a delivery answered by a rejected re-send exits 0" "$(rfu)" "0/0/0"
  has "c: two batches were judged" "$R_ERR" "rounds=1 batches=2 findings=0"
  run "$ADET" --trace "$T/c.jsonl"
  has "c: the cap is the rejection's 2" "$R_ERR" "cap=2 capsrc=rejection capvals=2"
}
arm_cenv() {
  run "$ADET" --trace "$T/cenv.jsonl"
  has "c': with an env line of 4 too, the rejection's live 2 wins" "$R_ERR" "cap=2 capsrc=rejection capvals=2"
}
arm_d() {
  run "$ADET" "$T/d.jsonl"
  eq  "d: an unknown cap exits 0 with one UNKNOWN-CAP" "$(rfu)" "0/0/1"
  has "d: the summary counts it apart" "$R_ERR" "findings=0 unknown-cap=1"
  has "d: the unknown cap is LOUD on stderr, naming session, round and count" "$R_ERR" "audit-party-wave-barrier: UNKNOWN-CAP session=d.jsonl round=s900/stories unjudged=1"
}
arm_dcap() {
  run "$ADET" --cap 4 "$T/d.jsonl"
  eq  "d control: --cap 4 makes the same transcript fire" "$(rfu)" "1/1/0"
  hasnt "d control: a judged transcript prints no loud line" "$R_ERR" "UNKNOWN-CAP session="
}
arm_e() {
  run "$ADET" "$T/e.jsonl"
  eq  "e: the measured 25-seat-wave shape exits 1 with exactly 3 FINDINGs" "$(rfu)" "1/3/0"
  has "e: batch 2 is left with 18 of 42 free at the first Dev exit" "$R_OUT" "batch=2 exit=2026-01-01T11:20:01.000Z dispatch=2026-01-01T12:00:01.000Z running=24 cap=42 idle=18 gap=2400s unrefilled=25"
  has "e: batch 4 fires too" "$R_OUT" "batch=4 exit=2026-01-01T13:20:01.000Z dispatch=2026-01-01T14:00:01.000Z running=24 cap=42 idle=18"
  has "e: 100 agents in one round, four batches" "$R_ERR" "given=1 scanned=1 rounds=1 batches=4 findings=3 unknown-cap=0"
}
arm_f() {
  run "$ADET" "$T/f.jsonl"
  eq  "f: X6, all four running at the beat, three exits left idle, fires" "$(rfu)" "1/1/0"
  has "f: the finding is at the first exit, 1 slot free, 3 unrefilled" "$R_OUT" "batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:10.000Z running=3 cap=4 idle=1 gap=2110s unrefilled=3"
  run "$ADET" --trace "$T/f.jsonl"
  has "f: the cap is read from a bare printenv integer" "$R_ERR" "cap=4 capsrc=env capvals=4"
}
arm_g() {
  run "$ADET" "$T/g.jsonl"
  eq  "g: X6 reversed, every delivery refilled, is quiet" "$(rfu)" "0/0/0"
  has "g: five batches judged, cap 4" "$R_ERR" "rounds=1 batches=5 findings=0"
}
arm_h() {
  run "$ADET" "$T/h.jsonl"
  eq  "h: X2, a barrier with no beat, fires" "$(rfu)" "1/1/0"
  has "h: the first exit, delivered by the attachment carrier, is counted" "$R_OUT" "exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:01.000Z running=3 cap=10 idle=7 gap=2101s unrefilled=3"
}
arm_i() {
  run "$ADET" "$T/i.jsonl"
  eq  "i: X1, three Architects while Dev 04 straggles, fires" "$(rfu)" "1/1/0"
  has "i: three unrefilled exits" "$R_OUT" "running=3 cap=10 idle=7 gap=2101s unrefilled=3"
}
arm_j() {
  run "$ADET" "$T/j.jsonl"
  eq  "j: X1b, two stragglers, fires" "$(rfu)" "1/1/0"
  has "j: two unrefilled exits" "$R_OUT" "running=3 cap=10 idle=7 gap=2101s unrefilled=2"
}
arm_k() {
  run "$ADET" "$T/k.jsonl"
  eq  "k: X3, a beat then the refill in the same turn, is quiet" "$(rfu)" "0/0/0"
  has "k: two batches judged" "$R_ERR" "rounds=1 batches=2 findings=0"
}
arm_l() {
  run "$ADET" "$T/l.jsonl"
  eq  "l: X4, four exits refilled by four, is quiet" "$(rfu)" "0/0/0"
  has "l: two batches judged" "$R_ERR" "rounds=1 batches=2 findings=0"
}
arm_m() {
  run "$ADET" "$T/m.jsonl"
  eq  "m: a delivery at running = cap answered by --status only is quiet" "$(rfu)" "0/0/0"
  run "$ADET" --trace "$T/m.jsonl"
  has "m: --trace scores it SLOTS-FULL" "$R_OUT" "DELIVERED exit=2026-01-01T10:05:02.000Z running=2 cap=2 SLOTS-FULL"
}
arm_n() {
  run "$ADET" "$T/n.jsonl"
  eq  "n: a MISSING re-send with no new member after is quiet" "$(rfu)" "0/0/0"
  has "n: one batch, three agents" "$R_ERR" "rounds=1 batches=1 findings=0"
}
arm_o() {
  run "$ADET" "$T/o.jsonl"
  eq  "o: a hook-denied call later re-sent and launched fires" "$(rfu)" "1/1/0"
  has "o: the denied call is not RUNNING and the re-send is the new member" "$R_OUT" "batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:01.000Z running=1 cap=4 idle=3 gap=2101s unrefilled=1"
}
arm_p() {
  run "$ADET" "$T/p.jsonl"
  eq  "p: two rejected spawns held across an exit fire" "$(rfu)" "1/1/0"
  has "p: the rejected spawns are not RUNNING at the finding" "$R_OUT" "running=1 cap=3 idle=2 gap=2101s unrefilled=1"
}
arm_q() {
  run "$ADET" "$T/q.jsonl"
  eq  "q: a compaction summary does not end the response" "$(rfu)" "0/0/0"
  has "q: three batches judged" "$R_ERR" "rounds=1 batches=3 findings=0"
}
arm_qmeta() {
  run "$ADET" "$T/qmeta.jsonl"
  eq  "q': an isMeta record between delivery and refill ends the response (fires)" "$(rfu)" "1/1/0"
}
arm_r() {
  run "$ADET" "$T/r.jsonl"
  eq  "r: a sidechain Agent call naming a round path answers nothing" "$(rfu)" "1/1/0"
  has "r: the finding is the lead's own" "$R_OUT" "running=1 cap=4 idle=3 gap=2101s unrefilled=1"
}
arm_s() {
  run "$ADET" --trace "$T/s.jsonl"
  eq  "s: two rejection caps fire" "$(rfu)" "1/1/0"
  has "s: the lower cap 3 is the one judged" "$R_OUT" "FINDING s.jsonl round=s900/stories batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:01.000Z running=2 cap=3 idle=1"
  has "s: both values are named" "$R_ERR" "cap=3 capsrc=rejection capvals=3 5"
}
arm_t() {
  run "$ADET" --trace "$T/t.jsonl"
  eq  "t: non-seat calls citing round paths answer nothing" "$(rfu)" "1/1/0"
  has "t: the finding is at Dev 01's unanswered delivery" "$R_OUT" "running=1 cap=4 idle=3 gap=2101s unrefilled=1"
  has "t: they are RUNNING, so the straggler's delivery reads 4 of 4" "$R_OUT" "DELIVERED exit=2026-01-01T10:40:00.000Z running=4 cap=4 REFILLED"
  has "t: all seven calls are parsed" "$R_ERR" "agents=7 cap=4"
}
# BL-732: a member is a call whose subagent_type is the seat of its cited party-mode path. Every cell
# below is presence-shaped (a STAT line with a stated count must APPEAR), and each rounds=0 cell has
# its rounds=1 twin in the same run.
arm_rem()     { eq "BL-732: a remediator citing seat files as INPUT is no member (rounds=0)" "$(bl732_rounds "$T/rem.jsonl")" 0; }
arm_remseat() { eq "BL-732: its seat twin, subagent_type sm, is a round (rounds=1)" "$(bl732_rounds "$T/remseat.jsonl")" 1; }
arm_adv()     { eq "BL-732: an adversary citing seat files is no member (rounds=0)" "$(bl732_rounds "$T/adv.jsonl")" 0; }
arm_deliv()   { eq "BL-732: graph's real seat prompt, Deliverable with no write verb, is a round (rounds=1)" "$(bl732_rounds "$T/deliv.jsonl")" 1; }
arm_gp()      { eq "BL-732: a general-purpose agent citing seat files is no member (rounds=0)" "$(bl732_rounds "$T/gp.jsonl")" 0; }
arm_cross()   { eq "BL-732: a cross seat citing another seat's file first is a round (rounds=1)" "$(bl732_rounds "$T/cross.jsonl")" 1; }
arm_bprose() {
  run "$ADET" "$T/bprose.jsonl"
  eq  "b': a cap written only in assistant prose is not read (still quiet)" "$R_RC/$(nfind)" "0/0"
  run "$ADET" --trace "$T/bprose.jsonl"
  has "b': the cap stays the tool_result line's 2" "$R_ERR" "cap=2 capsrc=env capvals=2"
  if grep -qE 'capvals=[0-9 ]*42' <<<"$R_ERR"; then bad "b': the prose value 42 is among the cap values"; else ok "b': the prose value 42 is not among the cap values"; fi
}
arm_set() {
  run "$ADET" "$T/b.jsonl" "$T/a.jsonl"
  eq  "set: the firing transcript listed SECOND still fires" "$R_RC/$(nfind)" "1/1"
  has "set: both transcripts were scanned" "$R_ERR" "given=2 scanned=2"
}
arm_refuse_empty() {
  run "$ADET"
  eq  "refuse: an empty transcript list exits 2" "$R_RC" 2
}
arm_refuse_unread() {
  run "$ADET" "$T/does-not-exist.jsonl"
  eq  "refuse: an unreadable transcript exits 2" "$R_RC" 2
}
arm_refuse_emptyfile() {
  run "$ADET" "$T/empty.jsonl" "$T/b.jsonl"
  eq  "refuse: an empty transcript beside a clean one exits 2, never 0" "$R_RC" 2
  has "refuse: scanned is counted short of given" "$R_ERR" "given=2 scanned=1"
}
# Arm ids as the header spells them; an id's function is arm_<id with - as _>.
ARMS="a b c cenv d dcap e f g h i j k l m n o p q qmeta r s t rem remseat adv deliv gp cross bprose set refuse-empty refuse-unread refuse-emptyfile"
armfn() { printf 'arm_%s' "${1//-/_}"; }
flagvar() { printf 'B_%s' "${1//-/_}"; }
# armrc <arm> <detector>: 0 when the arm passes against that detector. A subshell, so FAILS is untouched.
armrc() { ( ADET="$2"; FAILS=0; "$(armfn "$1")" >/dev/null 2>&1; [ "$FAILS" -eq 0 ] ); }
# The live pass over the SHIPPED subject's base copy: every arm, every assertion. B_<arm>=1 when it passed.
for a in $ARMS; do
  f0="$FAILS"; ADET="$BASE_DET"; "$(armfn "$a")"
  if [ "$FAILS" -eq "$f0" ]; then printf -v "$(flagvar "$a")" 1; else printf -v "$(flagvar "$a")" 0; fi
done
ADET="$BASE_DET"

# --- mutants -------------------------------------------------------------------------------------
mkdir -p "$WORK/mut"
# mut <name> [<count> <old> <new>]... -> prints the mutant path; each <old> must occur exactly <count> times.
mut() {
  local name="$1" dst c; shift
  dst="$WORK/mut/$name.sh"; cp "$DET" "$dst" || return 1
  while [ $# -ge 3 ]; do
    c="$(MO="$2" MN="$3" awk 'BEGIN { o = ENVIRON["MO"]; n = ENVIRON["MN"] }
      { s = $0; out = ""; while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) n; s = substr(s, i + length(o)); k++ } print out s }
      END { print k + 0 > "/dev/stderr" }' "$dst" 2>&1 >"$dst.t")" || { echo "DID NOT APPLY: $name (awk failed)" >&2; return 1; }
    [ "$c" = "$1" ] || { echo "DID NOT APPLY: $name (anchor matched $c times, want $1): $2" >&2; return 1; }
    cat "$dst.t" > "$dst"; rm -f "$dst.t"; shift 3
  done
  cmp -s "$DET" "$dst" && { echo "DID NOT APPLY: $name (copy unchanged)" >&2; return 1; }
  printf '%s' "$dst"
}
NP_O='wave_selfprobe || exit 2'; NP_N=': wave_selfprobe skipped'

# score <id> "<decides arms>" "<twin arms or ->" <mut args...>
# Per push: the mutant (self-probe call removed) is driven through its deciding arm(s), which must FAIL,
# and its twins, which must HOLD; the kill goes through mutant_killed behind the same-run base-pass flags
# of exactly those arms. With --matrix: every arm, plus the `probe` cell (the mutant with its self-probe
# left in), one MATRIX line per cell.
score() {
  local id="$1" dec="$2" tw="$3" P Pp a c flag=1 good=1 want
  shift 3
  if ! P="$(mut "$id" "$@" 1 "$NP_O" "$NP_N")"; then bad "$id: DID NOT APPLY"; return; fi
  if [ "$MATRIX" = 1 ]; then
    for a in $ARMS; do
      if armrc "$a" "$P"; then c=ok; else c=FAIL; fi
      printf 'MATRIX\t%s\t%s\t%s\n' "$id" "$a" "$c"; MATRIX_CELLS=$((MATRIX_CELLS + 1))
    done
    if Pp="$(mut "$id-probe" "$@")"; then
      run "$Pp" "$T/a.jsonl"
      if [ "$R_RC" = 2 ] && grep -qF 'self-probe FAILED' <<<"$R_ERR"; then c=FAIL; else c=ok; fi
      printf 'MATRIX\t%s\t%s\t%s\n' "$id" probe "$c"; MATRIX_CELLS=$((MATRIX_CELLS + 1))
    else bad "$id-probe: DID NOT APPLY"; fi
    return
  fi
  [ "$tw" = "-" ] && tw=""
  for a in $dec $tw; do [ "$(eval "printf '%s' \"\${$(flagvar "$a"):-0}\"")" = 1 ] || flag=0; done
  for a in $dec; do armrc "$a" "$P" && good=0; done
  for a in $tw; do armrc "$a" "$P" || good=0; done
  if [ "$good" = 1 ]; then
    mutant_killed "$flag" "$id" "$id killed: arm(s) $dec FAIL under it and twin(s) ${tw:--} hold"
  else
    bad "$id SURVIVED or is entangled: arm(s) $dec must FAIL and twin(s) ${tw:--} must HOLD"
  fi
}
score M1 m l \
  1 '    else if (grun[i] >= cap) v = "SLOTS-FULL"' '    else if (0) v = "SLOTS-FULL"'
score M2 b a \
  1 '  for (i = 1; i <= gn; i++) if (gr[i] == r) gans[i] = 1' '  gans[0] = 0'
score M3 d dcap \
  1 '    else if (cap == "") { v = "NO-CAP"; if (!snocap[r]) { snts[r] = gts[i]; snrun[r] = grun[i] } snocap[r]++ }' \
    '    else if (cap == "") { v = "UNREFILLED"; if (!sunref[r]) { suts[r] = gts[i]; suep[r] = gep[i]; surun[r] = grun[i] } sunref[r]++ }'
score M4 refuse-empty refuse-unread \
  1 '[ "${#FILES[@]}" -gt 0 ] || usage "no transcript given"' '[ "${#FILES[@]}" -gt 0 ] || exit 0'
score M5 bprose b \
  1 '       | if (.name == "Agent" or .name == "Task") then' '       | if .type == "text" then (["R", $e, $ts, "-", "", "ok", "", ([(.text // "") | split("\n")[] | select(test("^CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=[0-9]+$"))] | .[0] // "" | sub("^[^=]*="; "")), "", "fg", ""])
         elif (.name == "Agent" or .name == "Task") then' \
  1 '       | select(type == "object" and .type == "tool_use")' '       | select(type == "object" and (.type == "tool_use" or .type == "text"))'
score M6 h i \
  1 '  elif .type == "attachment" and akind == "task-notification" then' '  elif false then'
score M7 a n \
  1 '(if nkind == "task-notification" then ($c | exitrec("d"; $e; $ts)) else empty end)' 'empty'
score M8 g l \
  1 'if ($4 == "d" && !(id in adel)) adel[id] = FNR' 'if (!(id in adel)) adel[id] = FNR'
score M9 k l \
  1 '$1 == "M" { for (i = 1; i <= gn; i++) gseen[i] = 1; next }' '$1 == "M" { close_seen(); for (i = 1; i <= gn; i++) gseen[i] = 1; next }'
score M10 c b \
  1 '  for (i = 1; i <= gn; i++) if (gr[i] == r) gans[i] = 1' '  if (ast[id] != "rej" && ast[id] != "err") for (i = 1; i <= gn; i++) if (gr[i] == r) gans[i] = 1'
score M11 n m \
  1 '  if ((r SUBSEP bn) in mem) next' '  mem[0] = 0'
score M12 f g \
  1 'v = $8; if (v == "" && ($5 in envcmd)) v = $11' 'v = $8'
score M13 e g \
  1 '  close_seen(); for (i = 1; i <= gn; i++) gseen[i] = 1; close_seen()' \
    '  close_seen(); for (i = 1; i <= gn; i++) gseen[i] = 1; close_seen(); for (r in sunref) if (sunref[r] > 0) { nfind++; printf "FINDING %s round=%s batch=end\n", name, r }'
score M14 cenv c \
  1 '  else if (rejmin != "") {' '  else if (rejmin != "" && envmin == "") {'
score M15 d dcap \
  1 '    [ -n "${ur:-}" ] && echo' '    [ -n "${ur:-}" ] && : echo'
score MB p o \
  1 'if (ast[id] == "rej" || ast[id] == "err") continue' 'if (ast[id] == "err") continue'
score ME s p \
  1 '$7 + 0 < rejmin + 0' '$7 + 0 > rejmin + 0'
score MF r a \
  1 '| select(type == "object" and .isSidechain != true)' '| select(type == "object")'
score MD o p \
  1 '"is_error": ?true' 'Concurrent subagent limit'
score MC q qmeta \
  1 '(if .isCompactSummary != true then ["T", $e, $ts] else empty end),' '["T", $e, $ts],'
score MK t remseat \
  1 '      mp = memberpath($7, $6)' '      mp = $7; sub(/ .*/, "", mp)'
score MX cross remseat \
  1 '      mp = memberpath($7, $6)' '      mp = $7; sub(/ .*/, "", mp); if (!seatmember(mp, $6)) mp = ""'

# M1's self-probe refusal, end to end, once per push: the probe is the shipped detector's own defence and
# one representative proves it still fires. The other mutants' probe cells are in the matrix.
if [ "$MATRIX" = 0 ]; then
  if P="$(mut M1-probe 1 '    else if (grun[i] >= cap) v = "SLOTS-FULL"' '    else if (0) v = "SLOTS-FULL"')"; then
    run "$P" "$T/a.jsonl"
    eq  "M1: the self-probe refuses the mutant (exit 2)" "$R_RC" 2
    has "M1: the self-probe names case m" "$R_ERR" "self-probe FAILED: case m"
  else bad "M1-probe: DID NOT APPLY"; fi
fi

echo
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX cells=$MATRIX_CELLS"
  [ "$MATRIX_CELLS" -gt 0 ] || bad "matrix mode measured no cell"
else
  eq "a plain run executed no matrix-only cell" "$MATRIX_CELLS" 0
fi
if [ "$FAILS" -eq 0 ]; then echo "party-wave-barrier: PASS"; exit 0; fi
echo "party-wave-barrier: $FAILS assertion(s) FAILED"; exit 1
