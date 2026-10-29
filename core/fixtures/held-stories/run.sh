#!/usr/bin/env bash
# held-stories/run.sh -- drive the REAL validate-held-stories.sh, through the REAL sibling
# `sprint-status.sh list-stories`, against seeded sprint worlds.
#
# THE SUBJECT (BL-839). On the reference consumer's s320 the lead held stories 2.1 and 2.2 behind a
# tolerance amendment that never landed. The hold lived only in the lead's context; nothing at a
# wave join or at implementation's exit saw two ready-for-dev stories that were neither in flight nor
# held. The validator's grammar and contract are in its own header; this fixture does not restate
# them.
#
# ARMS (every world is a fresh root; stories 1.1 done, 1.3 and 2.1 ready-for-dev, file stems carry
# `<epic>-<index>` and the yaml keys are story-320-<M>, so the two spellings differ):
#   h1   the s320 shape: 1.3 dispatched (an In-Flight row whose DELIVERABLE carries its file stem),
#        2.1 held by yaml key -> exit 0 and the OK line names 3 stories
#   h2   h1 with the hold line deleted -> exit 1, UNACCOUNTED story-320-4 (2.1)
#   h3   2.1 moved to review, hold kept -> exit 1, STALE-HOLD story-320-4 (2.1)
#   h4   a hold line with no `since` -> exit 1, MALFORMED-HOLD
#   h5   no snapshot -> exit 2; also no `## Open Items` -> exit 2, and no yaml (list-stories exit 2) -> exit 2
#   h6   1.3 accounted by a row whose ROLE names `story 1.3` -> exit 0
#   h6b  the row names `story 1.30` instead -> exit 1, UNACCOUNTED story-320-3 (1.3) (boundary near-miss)
#   h6n  1.3 dispatched in spawn-ledger.jsonl only, no row, no hold -> exit 1, UNACCOUNTED (the ledger is never read)
#   h7   the 2.1 hold is 16h old -> exit 1, AGED-HOLD story-320-4 (2.1) 16h (the amendment that never lands)
#   h7n  the 2.1 hold is 1h old -> exit 0
#   h8   a wave-2 story 2.2 held `until 1.3 passes gate 3` -> exit 0, 4 stories
#   h9   `held: 2.1 ...` matches yaml key story-320-4 whose file is story-2-1-*.md -> exit 0
#   h0   a `stories:` key with no entries (list-stories exit 0, empty output) -> exit 0, 0 stories
#   S1   implementation.md section 7 carries the validator's invocation line
#   S2   ai-dlc-recover.sh's verification turn names every `held:` Open Item
# MUTANTS (each a copy of the validator beside a copy of sprint-status.sh and schemas/; each scored
# through lib/mutant.sh against the same-run pass of the arm it guards):
#   m-keyonly  a hold matches the yaml key only        -> h9 dies
#   m-noage    the age comparison never fires          -> h7 dies
#   m-nostale  the stale comparison never fires        -> h3 dies
#   m-norows   In-Flight rows never account a story    -> h6 dies (h1 also carries a row; h6 owns it)
#   m-fnrnr    the stories file keyed on FNR == NR     -> h0 dies (an empty answer eats the snapshot)
# A control drives the UNMUTATED copy through the same harness and requires h1's OK line, so a copy
# that cannot run is never read as a kill.
#
# MUTANT MATRIX (.claude/rules/fixture-mutants.md, "One run per distinct state", clause 2). Per push
# each mutant runs its deciding arm (must fail) and its twin (must stay green); --matrix drives every
# mutant against every arm and prints one MATRIX row each. The rows below are that measurement.
# Measured: m-norows also trips h1, h2, h7n, h8 and h9 (every world that accounts 1.3 by a row's
# deliverable stem); h6 owns it, and h6n, which carries no row, is its green twin. Every other mutant
# trips only its deciding arm.
# MUTANT-MATRIX m-keyonly decides=h9 twins=h1
# MUTANT-MATRIX m-noage decides=h7 twins=h7n
# MUTANT-MATRIX m-nostale decides=h3 twins=h1
# MUTANT-MATRIX m-norows decides=h6 twins=h6n
# MUTANT-MATRIX m-fnrnr decides=h0 twins=h1
# MUTANT-MATRIX-DYNAMIC score why=score passes its first argument to mutant_killed; every score call names a mutant carrying its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/held-stories/run.sh --matrix
set -uo pipefail
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
MX_FULL_RUNS=0     # incremented ONLY by matrix-only cells; a plain run must leave it at 0

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
VAL=""; SS=""; SCHEMA=""
for d in "$ROOT/core/scripts" "$ROOT/scripts/ai-dlc"; do
  if [ -f "$d/validate-held-stories.sh" ] && [ -f "$d/sprint-status.sh" ]; then
    VAL="$d/validate-held-stories.sh"; SS="$d/sprint-status.sh"; break
  fi
done
for s in "$ROOT/core/schemas/sprint-status.json" "$ROOT/.claude/schemas/sprint-status.json"; do
  [ -f "$s" ] && { SCHEMA="$s"; break; }
done
[ -n "$VAL" ] && [ -n "$SCHEMA" ] || { echo "FIXTURE ERROR: validate-held-stories.sh, sprint-status.sh and sprint-status.json not found together in either layout" >&2; exit 2; }
printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$VAL" "$SS" "$SCHEMA"
# The sibling resolves its schema script-relative first; a mutant copy carries schemas/ beside it,
# and the override makes both layouts read the one schema this fixture resolved.
export AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/held-stories.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
. "$HERE/../lib/mutant.sh"

NOW=1793200000
export AI_DLC_NOW="$NOW"
SP="_bmad-output/planning-artifacts/s320/stories"

# world <dir> <2.1 status> [extra yaml entry: 2.2] -> a root with .claude/ and the implementation yaml
world() {
  local w="$1"
  mkdir -p "$w/.claude" "$w/_bmad-output/implementation-artifacts"
  {
    printf 'sprint: 320\nname: "s"\nvariant: carry-over\nstatus: in_progress\nstories:\n'
    printf '  story-320-1:\n    status: done\n    file: %s/story-1-1-a-sweep-row.md\n' "$SP"
    printf '  story-320-3:\n    status: ready-for-dev\n    file: %s/story-1-3-each-dated-monitor.md\n' "$SP"
    printf '  story-320-4:\n    status: %s\n    file: %s/story-2-1-read-one-active-position.md\n' "$2" "$SP"
    [ "${3:-}" = with22 ] && printf '  story-320-5:\n    status: ready-for-dev\n    file: %s/story-2-2-correct-the-aggregator.md\n' "$SP"
  } > "$w/_bmad-output/implementation-artifacts/sprint-status.yaml"
}
# snap <dir> <open-items lines (\n-separated, may be empty)> <in-flight rows (may be empty)>
snap() {
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step_file: implementation.md\n\n'
    printf '## Open Items\n- fan-out round story-320-3 since 2026-10-27T21:14Z\n'
    [ -n "$2" ] && printf '%s\n' "$2"
    printf '\n## In-Flight Teammates\nteammate | role | deliverable | dispatched-at | status\n--- | --- | --- | --- | ---\n'
    [ -n "$3" ] && printf '%s\n' "$3"
    printf '\n## Context Reminders\n- context_reminders_sent: none\n'
  } > "$1/_bmad-output/pipeline-snapshot.md"
}
ROW_DELIV='a18da3c11dffb05ab | ops reads (AC1/2/3) | /w/graph-s320-story-1-3/_bmad-output/implementation-artifacts/s320/dev-report-story-1-3.md | 2026-10-27T19:54:23Z | delivered-reachable'
ROW_ROLE='ae0266c9c421f266a | code-reviewer gate 1 story 1.3 part 1/4 | /w/shards/1.md | 2026-10-27T21:14:47Z | in-flight'
ROW_130='ae0266c9c421f266a | code-reviewer gate 1 story 1.30 part 1/4 | /w/shards/1.md | 2026-10-27T21:14:47Z | in-flight'
HOLD_KEY="- held: story-320-4 until the 2.1 tolerance amendment lands since $((NOW - 600))"

RC=""; OUT=""
drive() { OUT="$(AI_DLC_PROJECT_ROOT="$2" bash "$1" --root "$2" 2>&1)"; RC=$?; }
has() { grep -qxF -- "$1" <<<"$OUT"; }

# arm <program> <name> -> builds the arm's world, drives it, sets A_<name>=1 on the expected outcome
arm() {
  local pr="$1" n="$2" w="$WORK/$3-$2"
  case "$n" in
    h1)  world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    h2)  world "$w" ready-for-dev; snap "$w" "" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'UNACCOUNTED story-320-4 (2.1)' && ! grep -q 'story-320-3' <<<"$OUT" ;;
    h3)  world "$w" review; snap "$w" "$HOLD_KEY" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'STALE-HOLD story-320-4 (2.1)' ;;
    h4)  world "$w" ready-for-dev; snap "$w" "- held: story-320-4 until the 2.1 tolerance amendment lands" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'MALFORMED-HOLD - held: story-320-4 until the 2.1 tolerance amendment lands' ;;
    h6)  world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_ROLE"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    h6b) world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_130"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'UNACCOUNTED story-320-3 (1.3)' ;;
    h6n) world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" ""
         printf '{"agent_id":"a18da3c11dffb05ab","role":"dev","story":"story-1-3","deliverable":"dev-report-story-1-3.md"}\n' > "$w/_bmad-output/spawn-ledger.jsonl"
         drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'UNACCOUNTED story-320-3 (1.3)' ;;
    h7)  world "$w" ready-for-dev; snap "$w" "- held: story-320-4 until the 2.1 tolerance amendment lands since $((NOW - 16 * 3600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 1 ] && has 'AGED-HOLD story-320-4 (2.1) 16h' ;;
    h7n) world "$w" ready-for-dev; snap "$w" "- held: story-320-4 until the 2.1 tolerance amendment lands since $((NOW - 3600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    h8)  world "$w" ready-for-dev with22
         snap "$w" "$HOLD_KEY"$'\n'"- held: story-320-5 until 1.3 passes gate 3 since $((NOW - 600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 4 stories' <<<"$OUT" ;;
    h0)  mkdir -p "$w/.claude" "$w/_bmad-output/implementation-artifacts"
         printf 'sprint: 321\nname: "s"\nvariant: carry-over\nstatus: in_progress\nstories:\n' > "$w/_bmad-output/implementation-artifacts/sprint-status.yaml"
         snap "$w" "" ""; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 0 stories' <<<"$OUT" ;;
    h9)  world "$w" ready-for-dev; snap "$w" "- held: 2.1 until the 2.1 tolerance amendment lands since $((NOW - 600))" "$ROW_DELIV"; drive "$pr" "$w"
         [ "$RC" = 0 ] && grep -q '^held-stories: OK -- 3 stories' <<<"$OUT" ;;
    *)   return 1 ;;
  esac
}

echo "held-stories:"
echo "  subject: $VAL"

for spec in \
  "h1|the s320 shape (1.3 by a row's deliverable stem, 2.1 held by key) is clean" \
  "h2|the hold deleted reports UNACCOUNTED story-320-4 (2.1) and nothing for the dispatched 1.3" \
  "h3|a hold on a story at review reports STALE-HOLD" \
  "h4|a hold with no since is MALFORMED-HOLD" \
  "h6|a row whose role names story 1.3 accounts it" \
  "h6b|a row naming story 1.30 does not account 1.3" \
  "h6n|a ledger-only dispatch is still UNACCOUNTED" \
  "h7|a 16h-old hold reports AGED-HOLD 16h" \
  "h7n|a 1h-old hold is quiet" \
  "h8|a wave-2 story held until 1.3 passes gate 3 is accounted" \
  "h9|held: 2.1 matches yaml key story-320-4 through its file stem" \
  "h0|a sprint with no story entries (list-stories exit 0, empty) is clean with 0 stories"; do
  n="${spec%%|*}"; msg="${spec#*|}"
  if arm "$VAL" "$n" ship; then ok "$n: $msg"; eval "A_$n=1"
  else bad "$n: $msg (rc=$RC: $(tr '\n' ' ' <<<"$OUT"))"; eval "A_$n=0"; fi
done

# h5: unevaluable inputs are exit 2, never a pass
w="$WORK/h5-nosnap"; world "$w" ready-for-dev; drive "$VAL" "$w"
[ "$RC" = 2 ] && grep -q 'no snapshot' <<<"$OUT" && ok "h5: no snapshot is exit 2" || bad "h5: no snapshot rc=$RC $OUT"
w="$WORK/h5-nooi"; world "$w" ready-for-dev
printf '# Pipeline Snapshot\n\n## In-Flight Teammates\nteammate | role | deliverable | dispatched-at | status\n--- | --- | --- | --- | ---\n' > "$w/_bmad-output/pipeline-snapshot.md"
drive "$VAL" "$w"
[ "$RC" = 2 ] && grep -q 'Open Items' <<<"$OUT" && ok "h5: no Open Items section is exit 2" || bad "h5: no Open Items rc=$RC $OUT"
w="$WORK/h5-noyaml"; world "$w" ready-for-dev; snap "$w" "$HOLD_KEY" "$ROW_DELIV"
rm "$w/_bmad-output/implementation-artifacts/sprint-status.yaml"
drive "$VAL" "$w"
[ "$RC" = 2 ] && grep -q 'list-stories exited 2' <<<"$OUT" && ok "h5: list-stories unevaluable (no yaml) is exit 2" || bad "h5: no yaml rc=$RC $OUT"

# --- S-arms: the two prose carriers this validator relies on ----------------
# Each resolves its subject in both layouts and first proves its section was found, so a moved
# heading reads FIXTURE BROKEN rather than a clean absence.
IMPL_MD=""; RECOVER=""
for f in "$ROOT/core/skills/ai-dlc/steps/implementation.md" "$ROOT/.claude/skills/ai-dlc/steps/implementation.md"; do [ -f "$f" ] && { IMPL_MD="$f"; break; }; done
for f in "$ROOT/core/hooks/ai-dlc-recover.sh" "$ROOT/.claude/hooks/ai-dlc-recover.sh"; do [ -f "$f" ] && { RECOVER="$f"; break; }; done
if [ -z "$IMPL_MD" ] || [ -z "$RECOVER" ]; then
  bad "FIXTURE BROKEN: implementation.md or ai-dlc-recover.sh not found in either layout"
else
  printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$IMPL_MD" "$RECOVER"
  S7="$(awk '/^### 7\. All Gates Passed$/ { on = 1 } on && /^\*\*READ AND FOLLOW:\*\*/ { exit } on { print }' "$IMPL_MD")"
  if [ -z "$S7" ]; then bad "FIXTURE BROKEN: implementation.md has no '### 7. All Gates Passed' section"
  elif grep -qxF 'Run `scripts/ai-dlc/validate-held-stories.sh`; a STALE-HOLD blocks the exit.' <<<"$S7"; then
    ok "S1: implementation.md section 7 runs validate-held-stories.sh before its exit"
  else bad "S1: implementation.md section 7 no longer runs validate-held-stories.sh"; fi
  VT="$(awk '/^Before acting, emit a verification turn naming:/ { on = 1 } on && /^$/ { exit } on { print }' "$RECOVER" | tr '\n' ' ')"
  if [ -z "$VT" ]; then bad "FIXTURE BROKEN: ai-dlc-recover.sh has no verification-turn paragraph"
  elif grep -qF 'state below, \`held:\`, and' <<<"$VT"; then
    ok "S2: ai-dlc-recover.sh's verification turn names every held: Open Item"
  else bad "S2: ai-dlc-recover.sh's verification turn no longer names the held: Open Items"; fi
fi

# --- mutants ----------------------------------------------------------------
# mkmut <name> <awk-free literal old> <literal new> -> path of the mutated copy, or empty when the
# edit matched nothing or the copy cannot be built (reported DID NOT APPLY, never scored)
mkmut() {
  local d="$WORK/mut-$1"
  mkdir -p "$d/scripts" "$d/schemas" || return 1
  cp "$SS" "$d/scripts/sprint-status.sh" && cp "$SCHEMA" "$d/schemas/sprint-status.json" || return 1
  OLD="$2" NEW="$3" awk 'BEGIN { o = ENVIRON["OLD"]; r = ENVIRON["NEW"] }
    { s = $0; out = ""; while ((p = index(s, o)) > 0) { out = out substr(s, 1, p - 1) r; s = substr(s, p + length(o)) } print out s }' \
    "$VAL" > "$d/scripts/validate-held-stories.sh" || return 1
  if [ "$1" != control ] && cmp -s "$VAL" "$d/scripts/validate-held-stories.sh"; then return 1; fi
  printf '%s' "$d/scripts/validate-held-stories.sh"
}

C="$(mkmut control x x)"
if [ -n "$C" ] && [ -f "$WORK/mut-control/scripts/sprint-status.sh" ] && arm "$C" h1 ctl; then
  ok "control: the unmutated copy beside its sibling reads h1 clean with 3 stories"; B_CTL=1
else
  bad "FIXTURE BROKEN: the unmutated copy did not read h1 clean (rc=$RC: $(tr '\n' ' ' <<<"$OUT")); no mutant is scored"; B_CTL=0
fi

ALL_ARMS="h1 h2 h3 h4 h6 h6b h6n h7 h7n h8 h9 h0"
score() { # score <mutant> <deciding arm> <twin arm> <old> <new>
  local m="$1" a="$2" t="$3" p base tbase x tr="" gr=""
  # The same-run base flags of the deciding arm and the twin, read from the A_<arm> the arm loop
  # above set; mutant_killed is passed their conjunction (validate-mutant-kills.sh M5's test form).
  base="$(eval "printf '%s' \"\${A_$a:-0}\"")"
  tbase="$(eval "printf '%s' \"\${A_$t:-0}\"")"
  [ "$B_CTL" = 1 ] || return 0
  p="$(mkmut "$m" "$4" "$5")"
  if [ -z "$p" ]; then bad "MUTANT $m DID NOT APPLY: its anchor matched nothing"; return 0; fi
  if [ "$MATRIX" = 1 ]; then
    for x in $ALL_ARMS; do
      MX_FULL_RUNS=$((MX_FULL_RUNS + 1))
      if arm "$p" "$x" "$m-mx"; then gr="$gr,$x"; else tr="$tr,$x"; fi
    done
    printf 'MATRIX %s decides=%s tripped=[%s] green=[%s]\n' "$m" "$a" "${tr#,}" "${gr#,}"
    return 0
  fi
  if arm "$p" "$a" "$m"; then bad "MUTANT $m survived: arm $a still passes"
  elif ! arm "$p" "$t" "$m-twin"; then bad "MUTANT $m moved its twin arm $t -- the arms overlap, re-measure with --matrix"
  else mutant_killed "$([ "$base" = 1 ] && [ "$tbase" = 1 ] && echo 1 || echo 0)" "$m" "mutant $m dies on $a; twin $t stays green"; fi
}
score m-keyonly h9 h1  'if (id == key[k] || id == ei[k] || id == stem[k]) return k' 'if (id == key[k]) return k'
score m-noage   h7 h7n 'if (now - hs[h] > maxs)' 'if (0)'
score m-nostale h3 h1  'if (st[k] != "ready-for-dev") { print "STALE-HOLD "' 'if (0) { print "STALE-HOLD "'
score m-norows  h6 h6n 'if (row_names(rows, k)) continue' 'if (0) continue'
score m-fnrnr   h0 h1  'FILENAME == ARGV[1] {' 'FNR == NR {'

if [ "$MATRIX" = 0 ]; then
  if [ "$MX_FULL_RUNS" -eq 0 ]; then ok "a plain run executed no matrix-only cell (MX_FULL_RUNS=0)"
  else bad "a plain run executed $MX_FULL_RUNS matrix-only cell(s)"; fi
fi

if [ "$fails" -eq 0 ]; then echo "held-stories: PASS"; exit 0; fi
echo "held-stories: $fails FAILED"; exit 1
