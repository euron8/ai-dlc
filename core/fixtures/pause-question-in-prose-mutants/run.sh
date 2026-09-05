#!/usr/bin/env bash
# pause-question-in-prose-mutants — prove every arm of the shipped fixture beside this one can
# FAIL, by breaking the hook six ways and reading which arm goes red.
#
# WHY A BATTERY AND NOT MORE ARMS. Six of the shipped fixture's arms are ABSENCE-shaped: they
# assert that NO systemMessage appears, that a paragraph is NOT prepended, that a log line is
# NOT written. Both-directions seeding establishes that those arms discriminate between two
# inputs; only a mutant establishes that they discriminate at all. Each mutation below is
# keyed on the SUBJECT'S OWN expression, built as a COPY, guarded with `cmp -s` so a `sed`
# that matched nothing reports DID NOT APPLY instead of scoring a kill, and checked with
# `bash -n` so a mutant that does not parse is reported rather than counted.
#
# EACH MUTANT MUST TURN EXACTLY ITS OWN ARM RED. Two failures would mean the assertions are
# entangled and one of them is vacuous; zero would mean the arm is watching something else.
# The battery therefore compares the arm-id SET, not a pass/fail.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "$HERE/../../hooks/ai-dlc-continue.sh" "$HERE/../../../core/hooks/ai-dlc-continue.sh")"
FX="$(pick "$HERE/../pause-question-in-prose/run.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-continue.sh" >&2; exit 2; }
[ -n "$FX" ]   || { echo "FIXTURE ERROR: cannot locate the shipped fixture's run.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required" >&2; exit 2; }

ROOT="$(mktemp -d)"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
printf '        mutating: %s\n' "$HOOK"

# mut <name> <sed-expr> -> prints the mutant path, or empty on DID NOT APPLY
mut() {
  # SEPARATE `local` STATEMENTS, DELIBERATELY. bash expands every word on a `local` line
  # BEFORE any of them is assigned, so `local n="$1" out="…$n…"` reads an unset `n` and dies
  # under `set -u` — inside a command substitution, where the message is easy to miss.
  local n="$1"
  local e="$2"
  local out="$ROOT/hook-$n.sh"
  if ! sed "$e" "$HOOK" > "$out" 2>/dev/null; then
    bad "$n DID NOT APPLY — sed exited non-zero, so no mutant exists and the arm below would score a kill against a file that was never written"
    return
  fi
  if cmp -s "$HOOK" "$out"; then
    bad "$n DID NOT APPLY — the expression matched nothing. The subject was reworded, so this battery is editing a file it does not understand and its silence means nothing"
    return
  fi
  if ! bash -n "$out" 2>/dev/null; then
    bad "$n does not parse — a kill would be a syntax error rather than a disarmed arm"
    return
  fi
  printf '%s' "$out"
}

# kills <fixture-output-file> -> the sorted set of arm ids that went red
kills() { sed -n 's/^  FAIL  \([A-Z][A-Z0-9]*\) .*/\1/p' "$1" | sort -u | tr '\n' ' '; }

# score <name> <mutant> <expected-arm-ids>
score() {
  local n="$1"
  local m="$2"
  local want="$3"
  local log="$ROOT/out-$n.txt"
  local got
  [ -n "$m" ] || return
  bash "$FX" "$m" > "$log" 2>&1
  got="$(kills "$log")"
  if [ "$got" = "$want" ]; then
    ok "$n -> ${want}red, and nothing else"
  else
    bad "$n turned [${got}] red; expected exactly [${want}]. A mutant that kills the wrong arm means the arms are entangled; one that kills nothing means the arm it targets is watching something the mutation did not touch"
  fi
}

# --- CONTROL, run FIRST and PRESENCE-shaped -----------------------------------------------
# An unmutated copy must be green AND must print a specific ok row. A control asserting only
# "rc=0 with no findings" passes against a subject replaced by `exit 0`.
cp "$HOOK" "$ROOT/hook-control.sh"
bash "$FX" "$ROOT/hook-control.sh" > "$ROOT/out-control.txt" 2>&1
c_rc=$?
if [ "$c_rc" -eq 0 ] && grep -q '^  ok    F1 flag UP + prose question -> systemMessage emitted$' "$ROOT/out-control.txt"; then
  ok "control: an unmutated copy is green and F1 positively reports the fire"
else
  bad "CONTROL BROKEN — an unmutated copy of the hook exited $c_rc and/or never printed F1's ok row. Every kill below is unreadable, because a copy that cannot run looks exactly like a disarmed arm"
  echo ""; echo "pause-question-in-prose-mutants: FIXTURE BROKEN" >&2; rm -rf "$ROOT"; exit 2
fi

# M1 -- the operator-facing emission neutered: the branch still runs and still logs, but the
# JSON it prints carries no systemMessage key.
#
# EVERY FLAG-UP FIRING ARM OWNS THIS OBSERVABLE AND ALL OF THEM ARE MEANT TO. F1, A3 and F3
# are the three, and `systemMessage` is the only thing any of them can read; a mutant that
# removes it must redden all three, and an expected set naming fewer would be scoring a kill it
# did not earn. The overlap is real rather than accidental, so the expectation names it. The
# arms are NOT interchangeable: M4 leaves the key in place and moves only F1, M3 moves only A3,
# and M7 moves only F3 -- each still has a subject the others cannot see.
score M1 "$(mut M1 's#{systemMessage:$m}#{}#')" "A3 F1 F3 "

# M2 -- the predicate widened to `?` ANYWHERE in the last assistant text, which is the obvious
# wrong implementation: A2's reply asks its question three paragraphs above the final line.
score M2 "$(mut M2 's#(($final_line | index("?")) != null)#(($last | index("?")) != null)#')" "A2 "

# M3 -- the tool_use search widened from the TURN to the whole transcript, which acquits every
# session that ever used AskUserQuestion once.
score M3 "$(mut M3 's#$turn\[\] | select#$r[] | select#')" "A3 "

# M4 -- the allow branch grows a `decision`. It would reach the operator and ALSO block the
# turn, wedging every (b)/(c) pause; F1's no-decision assertion is what stands between.
score M4 "$(mut M4 's#{systemMessage:$m}#{systemMessage:$m,decision:"block",reason:$m}#')" "F1 "

# M5 -- the turn boundary taken at ANY user record, including the tool_result-only one an
# AskUserQuestion answer arrives as. A4 is the seed that can see it.
score M5 "$(mut M5 's#^def genuine: (.message.role=="user") and ((txt|blank)|not);$#def genuine: (.message.role=="user");#')" "A4 "

# M6 -- the second reader removed: the block reason loses its prepended paragraph. This is the
# branch that covers the turn the defect actually happened on, and only the flag-DOWN arm sees it.
# The anchor is the COLUMN-ZERO call. Check 1's call and the log row's are both indented two,
# so a pattern keyed on the call alone would edit three sites and move two arms at once.
score M6 "$(mut M6 's#^if pq_fire; then$#if false; then#')" "F2 "

# M7 -- the tool NAME dropped from the search, so any tool_use acquits the turn. Measured over
# the reference consumer, this widening acquits 65 of 96 fires while passing every arm except
# F3; it is the wrong fix that looks most like the right one.
score M7 "$(mut M7 's#select(.type=="tool_use" and .name=="AskUserQuestion")#select(.type=="tool_use")#')" "F3 "

# --- THE NO-PREPEND BASELINE, byte-compared ------------------------------------------------
# A7 in the shipped fixture asserts the standing block reason is unshortened and carries no
# Rule 11(a) paragraph. Those are two substring tests, and a substring test cannot see a byte
# the prepend moved somewhere else in the same string. This is the byte-exact half.
#
# THE BASELINE IS THE BRANCH-DISABLED MUTANT, NOT A HISTORICAL SHA, AND THE REASON IS A
# MEASUREMENT. It was pinned to the revision before this arm existed, and the first release to
# reword the STANDING reason -- prose this arm does not own and has no opinion about -- turned
# the comparison red with a message accusing the prepend of leaking. A pin to a sha is a
# byte-lock on every line of that string, not on the property under test. M6's copy is the same
# hook with only the prepend branch neutered, so the two sides differ in exactly the thing this
# arm is about and in nothing else, and it stays true through any later rewording.
#
# BOTH DIRECTIONS, because equality alone cannot show the comparison RESOLVES anything: the
# non-firing seed must produce identical reasons, and the FIRING seed must produce different
# ones. Without the second, a `reason_of` that returned "" on every input would pass.
BASE="$(mut BASE 's#^if pq_fire; then$#if false; then#')"
if [ -n "$BASE" ]; then
  SEED_ROOT="$(bash "$HERE/../pause-question-in-prose/seed.sh")"
  reason_of() { # reason_of <hook> <transcript> -> the block reason, flag DOWN, snapshot present
    local hk="$1"
    local tr="$2"
    local proj
    proj="$(mktemp -d)"; mkdir -p "$proj/_bmad-output"
    cp "$SEED_ROOT/snapshot.md" "$proj/_bmad-output/pipeline-snapshot.md"
    jq -nc --arg t "$tr" --arg s "fx-base" '{transcript_path:$t,session_id:$s}' \
      | CLAUDE_PROJECT_DIR="$proj" bash "$hk" 2>/dev/null | jq -r '.reason // "NO-REASON"'
    rm -rf "$proj"
  }
  reason_of "$HOOK" "$SEED_ROOT/noq.jsonl"  > "$ROOT/r-now-noq.txt"
  reason_of "$BASE" "$SEED_ROOT/noq.jsonl"  > "$ROOT/r-base-noq.txt"
  reason_of "$HOOK" "$SEED_ROOT/fire.jsonl" > "$ROOT/r-now-fire.txt"
  reason_of "$BASE" "$SEED_ROOT/fire.jsonl" > "$ROOT/r-base-fire.txt"
  if grep -q '^NO-REASON$' "$ROOT/r-base-noq.txt" || [ ! -s "$ROOT/r-now-noq.txt" ]; then
    bad "BASELINE BROKEN — one side produced no block reason at all, so the comparison has nothing to compare"
  elif ! cmp -s "$ROOT/r-now-fire.txt" "$ROOT/r-base-fire.txt"; then
    ok "baseline control: on the FIRING seed the two reasons DIFFER, so this comparison can resolve the prepend"
    if cmp -s "$ROOT/r-now-noq.txt" "$ROOT/r-base-noq.txt"; then
      ok "A7 baseline: on a non-firing flag-down seed the reason is byte-identical to the branch-disabled hook's"
    else
      bad "A7 baseline: the block reason on a NON-FIRING seed differs from the branch-disabled hook's, so the prepend is leaking into turns that carry no question: $(diff "$ROOT/r-base-noq.txt" "$ROOT/r-now-noq.txt" | head -5)"
    fi
  else
    bad "BASELINE VACUOUS — the two hooks produce the SAME reason on the FIRING seed, so the comparison cannot see the prepend and its agreement on the non-firing seed means nothing"
  fi
  rm -rf "$SEED_ROOT"
fi

rm -rf "$ROOT"
echo ""
[ "$fails" -eq 0 ] && { echo "pause-question-in-prose-mutants: PASS"; exit 0; }
echo "pause-question-in-prose-mutants: FAIL ($fails)"; exit 1
