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
#   (c') (c) with an env line of 4 as well                         -> the rejection's 2 wins
#   (b') (b) with a cap written only as assistant prose            -> the prose value is not read
#   (a+b) a two-transcript list with the firing one SECOND -> rc 1, given=2 scanned=2
#   empty list -> rc 2; unreadable path -> rc 2; an empty file -> rc 2, scanned 0 of 1
#   --cap on (d) -> fires: the option is a cap source
#
# MUTANTS, each a copy of the detector, guarded by an exact anchor count and `cmp -s`. A probe_killed
# mutant is driven twice: as-is (its self-probe must refuse, naming the case it breaks) and as an -np
# twin with the self-probe call removed (the named seed's cell must flip). The rest have no probe case
# and are killed by the named fixture arm alone.
#   M1  the free-slot test removed                 -> probe m; -np (m) fires
#   M2  a dispatch no longer answers a delivery    -> probe b; -np (b) fires
#   M3  an unknown cap judged as a finding         -> probe d; -np (d) exits 1
#   M4  an empty corpus returns 0                  -> the empty list exits 0
#   M5  the cap read from assistant prose          -> (b') reads 42
#   M6  the attachment delivery carrier dropped    -> probe h; -np (h) loses its first exit
#   M7  the user delivery carrier dropped          -> probe a; -np (a) is quiet
#   M8  an enqueue judged as a delivery            -> probe g; -np (g) fires
#   M9  the response cut to the next assistant record (no turn) -> probe k; -np (k) fires
#   M10 a rejected call no longer answers          -> probe c; -np (c) fires
#   M11 a re-send counted as a new member          -> probe n; -np (n) fires
#   M12 the printenv cap source dropped            -> probe f; -np (f) reads UNKNOWN-CAP
#   M13 the round's last stretch judged too        -> probe e; -np (e) reads 4 findings
#   M14 the environment ranked above the rejection -> (c') reads cap 4 from the env
#   M15 the loud unknown-cap line silenced         -> (d) has no stderr line
#   MB  rejected spawns counted as RUNNING         -> probe p; -np (p) reads SLOTS-FULL, quiet
#   ME  two cap values take the HIGHER             -> probe s; -np (s) reads cap 5
#   MF  the isSidechain filter removed             -> probe r; -np (r) is quiet
#   MD  error results dropped by the prefilter     -> probe o; -np (o) is quiet
#   MC  a compaction summary ends a turn again     -> probe q; -np (q) fires
#
# Exit: 0 = every assertion holds, 1 = an assertion failed, 2 = the fixture could not run.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# Both layouts named, never a single walk-up (I33c). The subject is distribution-only.
ROOT=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/scripts/audit-party-wave-barrier.sh" ]; then ROOT="$(cd "$cand" && pwd -P)"; break; fi
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: could not locate scripts/audit-party-wave-barrier.sh from $HERE" >&2; exit 2; }
DET="$ROOT/scripts/audit-party-wave-barrier.sh"
echo "HERMETIC-CONSUMED scripts/audit-party-wave-barrier.sh"
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pwb-fx.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if grep -qF -- "$3" <<<"$2"; then ok "$1"; else bad "$1 (absent: $3)"; fi; }
hasnt() { if grep -qF -- "$3" <<<"$2"; then bad "$1 (present: $3)"; else ok "$1"; fi; }
echo "party-wave-barrier:"

# --- seeds ---------------------------------------------------------------------------------------
CASES="a b c d e f g h i j k l m n o p q r s"
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

# R_OUT, R_ERR, R_RC: run <detector> <args...>
run() { local d="$1"; shift; R_OUT="$(bash "$d" "$@" 2>"$WORK/err")"; R_RC=$?; R_ERR="$(cat "$WORK/err")"; }
nfind() { local n; n="$(grep -c '^FINDING ' <<<"$R_OUT")" || n=0; printf '%s' "$n"; }
nunk()  { local n; n="$(grep -c '^UNKNOWN-CAP ' <<<"$R_OUT")" || n=0; printf '%s' "$n"; }
rfu() { printf '%s/%s/%s' "$R_RC" "$(nfind)" "$(nunk)"; }

# --- control: the unmutated detector -------------------------------------------------------------
PROBE_OK='self-probe: ok (19 cases)'
run "$DET" "$T/a.jsonl"
if ! grep -qF "$PROBE_OK" <<<"$R_ERR"; then
  echo "FIXTURE BROKEN: the unmutated detector's self-probe did not pass; no verdict below would mean anything" >&2
  printf '%s\n' "$R_ERR" | head -10 >&2; exit 2
fi
eq  "a: an exit answered by --status only exits 1" "$R_RC" 1
eq  "a: exactly one FINDING" "$(nfind)" 1
has "a: the finding names round, batch, exit, idle slots and the gap" "$R_OUT" "round=s900/stories batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:07:00.000Z running=1 cap=4 idle=3 gap=120s unrefilled=1"
has "a: the summary counts one scanned of one given" "$R_ERR" "given=1 scanned=1 rounds=1 batches=2 findings=1 unknown-cap=0"

run "$DET" "$T/b.jsonl"
eq  "b: refill on exit exits 0" "$(rfu)" "0/0/0"
has "b: the refill transcript was parsed (one round, three batches)" "$R_ERR" "given=1 scanned=1 rounds=1 batches=3 findings=0 unknown-cap=0"
run "$DET" --trace "$T/b.jsonl"
has "b: --trace scores Dev 02's delivery REFILLED" "$R_OUT" "DELIVERED exit=2026-01-01T10:06:00.000Z running=1 cap=2 REFILLED"
has "b: --trace reports 4 agents and the cap of 2" "$R_ERR" "agents=4 cap=2 capsrc=env"

run "$DET" "$T/c.jsonl"
eq  "c: a delivery answered by a rejected re-send exits 0" "$(rfu)" "0/0/0"
has "c: two batches were judged" "$R_ERR" "rounds=1 batches=2 findings=0"
run "$DET" --trace "$T/c.jsonl"
has "c: the cap is the rejection's 2" "$R_ERR" "cap=2 capsrc=rejection capvals=2"
run "$DET" --trace "$T/cenv.jsonl"
has "c': with an env line of 4 too, the rejection's live 2 wins" "$R_ERR" "cap=2 capsrc=rejection capvals=2"

run "$DET" "$T/d.jsonl"
eq  "d: an unknown cap exits 0 with one UNKNOWN-CAP" "$(rfu)" "0/0/1"
has "d: the summary counts it apart" "$R_ERR" "findings=0 unknown-cap=1"
has "d: the unknown cap is LOUD on stderr, naming session, round and count" "$R_ERR" "audit-party-wave-barrier: UNKNOWN-CAP session=d.jsonl round=s900/stories unjudged=1"
run "$DET" --cap 4 "$T/d.jsonl"
eq  "d control: --cap 4 makes the same transcript fire" "$(rfu)" "1/1/0"
hasnt "d control: a judged transcript prints no loud line" "$R_ERR" "UNKNOWN-CAP session="

run "$DET" "$T/e.jsonl"
eq  "e: the measured 25-seat-wave shape exits 1 with exactly 3 FINDINGs" "$(rfu)" "1/3/0"
has "e: batch 2 is left with 18 of 42 free at the first Dev exit" "$R_OUT" "batch=2 exit=2026-01-01T11:20:01.000Z dispatch=2026-01-01T12:00:01.000Z running=24 cap=42 idle=18 gap=2400s unrefilled=25"
has "e: batch 4 fires too" "$R_OUT" "batch=4 exit=2026-01-01T13:20:01.000Z dispatch=2026-01-01T14:00:01.000Z running=24 cap=42 idle=18"
has "e: 100 agents in one round, four batches" "$R_ERR" "given=1 scanned=1 rounds=1 batches=4 findings=3 unknown-cap=0"

run "$DET" "$T/f.jsonl"
eq  "f: X6, all four running at the beat, three exits left idle, fires" "$(rfu)" "1/1/0"
has "f: the finding is at the first exit, 1 slot free, 3 unrefilled" "$R_OUT" "batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:10.000Z running=3 cap=4 idle=1 gap=2110s unrefilled=3"
run "$DET" --trace "$T/f.jsonl"
has "f: the cap is read from a bare printenv integer" "$R_ERR" "cap=4 capsrc=env capvals=4"

run "$DET" "$T/g.jsonl"
eq  "g: X6 reversed, every delivery refilled, is quiet" "$(rfu)" "0/0/0"
has "g: five batches judged, cap 4" "$R_ERR" "rounds=1 batches=5 findings=0"

run "$DET" "$T/h.jsonl"
eq  "h: X2, a barrier with no beat, fires" "$(rfu)" "1/1/0"
has "h: the first exit, delivered by the attachment carrier, is counted" "$R_OUT" "exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:01.000Z running=3 cap=10 idle=7 gap=2101s unrefilled=3"

run "$DET" "$T/i.jsonl"
eq  "i: X1, three Architects while Dev 04 straggles, fires" "$(rfu)" "1/1/0"
has "i: three unrefilled exits" "$R_OUT" "running=3 cap=10 idle=7 gap=2101s unrefilled=3"
run "$DET" "$T/j.jsonl"
eq  "j: X1b, two stragglers, fires" "$(rfu)" "1/1/0"
has "j: two unrefilled exits" "$R_OUT" "running=3 cap=10 idle=7 gap=2101s unrefilled=2"

run "$DET" "$T/k.jsonl"
eq  "k: X3, a beat then the refill in the same turn, is quiet" "$(rfu)" "0/0/0"
has "k: two batches judged" "$R_ERR" "rounds=1 batches=2 findings=0"
run "$DET" "$T/l.jsonl"
eq  "l: X4, four exits refilled by four, is quiet" "$(rfu)" "0/0/0"
has "l: two batches judged" "$R_ERR" "rounds=1 batches=2 findings=0"

run "$DET" "$T/m.jsonl"
eq  "m: a delivery at running = cap answered by --status only is quiet" "$(rfu)" "0/0/0"
run "$DET" --trace "$T/m.jsonl"
has "m: --trace scores it SLOTS-FULL" "$R_OUT" "DELIVERED exit=2026-01-01T10:05:02.000Z running=2 cap=2 SLOTS-FULL"

run "$DET" "$T/n.jsonl"
eq  "n: a MISSING re-send with no new member after is quiet" "$(rfu)" "0/0/0"
has "n: one batch, three agents" "$R_ERR" "rounds=1 batches=1 findings=0"

run "$DET" "$T/o.jsonl"
eq  "o: a hook-denied call later re-sent and launched fires" "$(rfu)" "1/1/0"
has "o: the denied call is not RUNNING and the re-send is the new member" "$R_OUT" "batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:01.000Z running=1 cap=4 idle=3 gap=2101s unrefilled=1"
run "$DET" "$T/p.jsonl"
eq  "p: two rejected spawns held across an exit fire" "$(rfu)" "1/1/0"
has "p: the rejected spawns are not RUNNING at the finding" "$R_OUT" "running=1 cap=3 idle=2 gap=2101s unrefilled=1"
run "$DET" "$T/q.jsonl"
eq  "q: a compaction summary does not end the response" "$(rfu)" "0/0/0"
has "q: three batches judged" "$R_ERR" "rounds=1 batches=3 findings=0"
# (q') the same record flagged isMeta (Stop-hook feedback) instead: that follows an end_turn, so it DOES
# start a turn and the refill after it is a new response. The exemption is compaction-only.
sed 's|"isCompactSummary":true|"isMeta":true|' "$T/q.jsonl" > "$T/qmeta.jsonl"
cmp -s "$T/q.jsonl" "$T/qmeta.jsonl" && { echo "FIXTURE ERROR: seed (q') did not apply" >&2; exit 2; }
run "$DET" "$T/qmeta.jsonl"
eq  "q': an isMeta record between delivery and refill ends the response (fires)" "$(rfu)" "1/1/0"
run "$DET" "$T/r.jsonl"
eq  "r: a sidechain Agent call naming a round path answers nothing" "$(rfu)" "1/1/0"
has "r: the finding is the lead's own" "$R_OUT" "running=1 cap=4 idle=3 gap=2101s unrefilled=1"
run "$DET" --trace "$T/s.jsonl"
eq  "s: two rejection caps fire" "$(rfu)" "1/1/0"
has "s: the lower cap 3 is the one judged" "$R_OUT" "FINDING s.jsonl round=s900/stories batch=2 exit=2026-01-01T10:05:00.000Z dispatch=2026-01-01T10:40:01.000Z running=2 cap=3 idle=1"
has "s: both values are named" "$R_ERR" "cap=3 capsrc=rejection capvals=3 5"

run "$DET" "$T/bprose.jsonl"
eq  "b': a cap written only in assistant prose is not read (still quiet)" "$R_RC/$(nfind)" "0/0"
run "$DET" --trace "$T/bprose.jsonl"
has "b': the cap stays the tool_result line's 2" "$R_ERR" "cap=2 capsrc=env capvals=2"

run "$DET" "$T/b.jsonl" "$T/a.jsonl"
eq  "set: the firing transcript listed SECOND still fires" "$R_RC/$(nfind)" "1/1"
has "set: both transcripts were scanned" "$R_ERR" "given=2 scanned=2"

run "$DET"
eq  "refuse: an empty transcript list exits 2" "$R_RC" 2
run "$DET" "$T/does-not-exist.jsonl"
eq  "refuse: an unreadable transcript exits 2" "$R_RC" 2
run "$DET" "$T/empty.jsonl" "$T/b.jsonl"
eq  "refuse: an empty transcript beside a clean one exits 2, never 0" "$R_RC" 2
has "refuse: scanned is counted short of given" "$R_ERR" "given=2 scanned=1"

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
    mv "$dst.t" "$dst"; shift 3
  done
  cmp -s "$DET" "$dst" && { echo "DID NOT APPLY: $name (copy unchanged)" >&2; return 1; }
  printf '%s' "$dst"
}
NP_O='wave_selfprobe || exit 2'; NP_N=': wave_selfprobe skipped'

# probe_killed <id> <case> <want rc/findings/unknown on that case's seed> <want text in its stdout or -> <count> <old> <new>...
probe_killed() {
  local id="$1" pc="$2" want="$3" text="$4" P; shift 4
  if P="$(mut "$id" "$@")"; then
    run "$P" "$T/a.jsonl"
    eq  "$id: the self-probe refuses (exit 2)" "$R_RC" 2
    has "$id: the self-probe names case $pc" "$R_ERR" "self-probe FAILED: case $pc"
  else bad "$id: DID NOT APPLY"; fi
  if P="$(mut "$id-np" "$@" 1 "$NP_O" "$NP_N")"; then
    run "$P" "$T/b.jsonl" "$T/a.jsonl"
    has "$id (probe removed): the mutant scanned two transcripts" "$R_ERR" "given=2 scanned=2"
    run "$P" "$T/$pc.jsonl"
    eq  "$id (probe removed): seed ($pc) reads rc/findings/unknown $want" "$(rfu)" "$want"
    [ "$text" = "-" ] || has "$id (probe removed): seed ($pc) prints" "$R_OUT" "$text"
  else bad "$id-np: DID NOT APPLY"; fi
}
probe_killed M1 m "1/1/0" "running=2 cap=2 idle=0" \
  1 '    else if (grun[i] >= cap) v = "SLOTS-FULL"' '    else if (0) v = "SLOTS-FULL"'
# M2: Dev 01's delivery is left unanswered and fires; Dev 02's arrives at running 2 = cap, SLOTS-FULL.
probe_killed M2 b "1/1/0" "running=1 cap=2 idle=1" \
  1 '  for (i = 1; i <= gn; i++) if (gr[i] == r) gans[i] = 1' '  gans[0] = 0'
probe_killed M3 d "1/1/0" "-" \
  1 '    else if (cap == "") { v = "NO-CAP"; if (!snocap[r]) { snts[r] = gts[i]; snrun[r] = grun[i] } snocap[r]++ }' \
    '    else if (cap == "") { v = "UNREFILLED"; if (!sunref[r]) { suts[r] = gts[i]; suep[r] = gep[i]; surun[r] = grun[i] } sunref[r]++ }'
probe_killed M6 h "1/1/0" "exit=2026-01-01T10:06:00.000Z dispatch=2026-01-01T10:40:01.000Z running=2 cap=10 idle=8 gap=2041s unrefilled=2" \
  1 '  elif .type == "attachment" and akind == "task-notification" then' '  elif false then'
probe_killed M7 a "0/0/0" "-" \
  1 '(if nkind == "task-notification" then ($c | exitrec("d"; $e; $ts)) else empty end)' 'empty'
# M8: each enqueue, judged as a delivery, is answered by the --status beat only: four stretches, four findings.
probe_killed M8 g "1/4/0" "-" \
  1 'if ($4 == "d" && !(id in adel)) adel[id] = FNR' 'if (!(id in adel)) adel[id] = FNR'
probe_killed M9 k "1/1/0" "-" \
  1 '$1 == "M" { for (i = 1; i <= gn; i++) gseen[i] = 1; next }' '$1 == "M" { close_seen(); for (i = 1; i <= gn; i++) gseen[i] = 1; next }'
probe_killed M10 c "1/1/0" "-" \
  1 '  for (i = 1; i <= gn; i++) if (gr[i] == r) gans[i] = 1' '  if (ast[id] != "rej" && ast[id] != "err") for (i = 1; i <= gn; i++) if (gr[i] == r) gans[i] = 1'
probe_killed M11 n "1/1/0" "-" \
  1 '  if ((r SUBSEP bn) in mem) next' '  mem[0] = 0'
probe_killed M12 f "0/0/1" "-" \
  1 'v = $8; if (v == "" && ($5 in envcmd)) v = $11' 'v = $8'
probe_killed M13 e "1/4/0" "-" \
  1 '  close_seen(); for (i = 1; i <= gn; i++) gseen[i] = 1; close_seen()' \
    '  close_seen(); for (i = 1; i <= gn; i++) gseen[i] = 1; close_seen(); for (r in sunref) if (sunref[r] > 0) { nfind++; printf "FINDING %s round=%s batch=end\n", name, r }'
# MB: with the rejected spawns RUNNING, (p)'s delivery reads 3 of 3 and SLOTS-FULL.
probe_killed MB p "0/0/0" "-" \
  1 'if (ast[id] == "rej" || ast[id] == "err") continue' 'if (ast[id] == "err") continue'
probe_killed ME s "1/1/0" "running=2 cap=5 idle=3" \
  1 '$7 + 0 < rejmin + 0' '$7 + 0 > rejmin + 0'
probe_killed MF r "0/0/0" "-" \
  1 '| select(type == "object" and .isSidechain != true)' '| select(type == "object")'
probe_killed MD o "0/0/0" "-" \
  1 '"is_error": ?true' 'Concurrent subagent limit'
probe_killed MC q "1/1/0" "-" \
  1 '(if .isCompactSummary != true then ["T", $e, $ts] else empty end),' '["T", $e, $ts],'

if P="$(mut M4 1 '[ "${#FILES[@]}" -gt 0 ] || usage "no transcript given"' '[ "${#FILES[@]}" -gt 0 ] || exit 0')"; then
  run "$P"
  eq "M4 (an empty corpus returns 0): the empty list exits 0" "$R_RC" 0
else bad "M4: DID NOT APPLY"; fi

# M5: the cap taken from any line of assistant text. Its probe still passes (no seeded probe case carries
# a prose cap), so only (b') can kill it.
if P="$(mut M5 1 '       | if (.name == "Agent" or .name == "Task") then' '       | if .type == "text" then (["R", $e, $ts, "-", "", "ok", "", ([(.text // "") | split("\n")[] | select(test("^CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=[0-9]+$"))] | .[0] // "" | sub("^[^=]*="; "")), "", "fg", ""])
         elif (.name == "Agent" or .name == "Task") then' \
  1 '       | select(type == "object" and .type == "tool_use")' '       | select(type == "object" and (.type == "tool_use" or .type == "text"))')"; then
  run "$P" --trace "$T/bprose.jsonl"
  has "M5: the self-probe still passes" "$R_ERR" "$PROBE_OK"
  if grep -qE 'capvals=[0-9 ]*42' <<<"$R_ERR"; then ok "M5 (cap read from prose): (b') reads the prose value 42"
  else bad "M5 (cap read from prose): (b') did not read 42 ($(grep -o 'capvals=.*' <<<"$R_ERR"))"; fi
else bad "M5: DID NOT APPLY"; fi

# M14: the environment ranked above the rejection. No probe case carries both, so only (c') kills it.
if P="$(mut M14 1 '  else if (rejmin != "") {' '  else if (rejmin != "" && envmin == "") {')"; then
  run "$P" --trace "$T/cenv.jsonl"
  has "M14: the self-probe still passes" "$R_ERR" "$PROBE_OK"
  has "M14 (env above rejection): (c') reads the env's 4" "$R_ERR" "cap=4 capsrc=env"
else bad "M14: DID NOT APPLY"; fi

# M15: the loud unknown-cap line silenced. The count on stdout is unchanged, so only the stderr arm sees it.
if P="$(mut M15 1 '    [ -n "${ur:-}" ] && echo' '    [ -n "${ur:-}" ] && : echo')"; then
  run "$P" "$T/d.jsonl"
  eq  "M15: (d) still reads one UNKNOWN-CAP on stdout" "$(rfu)" "0/0/1"
  hasnt "M15 (loud line silenced): (d) has no loud stderr line" "$R_ERR" "UNKNOWN-CAP session=d.jsonl"
else bad "M15: DID NOT APPLY"; fi

echo
if [ "$FAILS" -eq 0 ]; then echo "party-wave-barrier: PASS"; exit 0; fi
echo "party-wave-barrier: $FAILS assertion(s) FAILED"; exit 1
