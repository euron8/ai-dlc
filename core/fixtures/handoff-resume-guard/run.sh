#!/usr/bin/env bash
# handoff-resume-guard — assert Check 0 blocks a missed resume prompt, and does NOT
# block one that follows the rulebook.
#
# THE DEFECT THIS FIXTURE EXISTS FOR. The reference consumer carried this guard for
# months matching EXACTLY six hyphens (`^------$`) while `steps/handoff.md` step 4 has
# ALWAYS mandated four (`----`). Six-hyphen appears nowhere in core, at any sha. So the
# guard fired on handoffs that were CORRECT per the rulebook: the lead emitted `----` as
# instructed, was blocked, read a block message telling it to use `------`, and complied
# with the HOOK instead of the RULE.
#
# Assertion 2 is therefore the load-bearing one: it FAILS against the version of this
# guard that was actually running in production.
#
# Usage: run.sh [path-to-ai-dlc-continue.sh]
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook.
#
# A fixture that INHERITS ambient config tests the config, not the code. The hooks honour
# thirteen AI_DLC_* tunables; a consumer that sets any of them in settings.json exports it
# into every session, `git push` inherits it, and the pre-push gate then runs this fixture
# against a hook configured differently from what the assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M (the documented, sanctioned way to
# declare the model row). Its effective window became 300000 instead of 200000, every
# threshold shifted, and SEVEN assertions failed against a sensor that was behaving exactly
# as specified. The gate blocked every push on the repo. The distribution never caught it
# because the distribution sets none of these -- the check could not fire where it was
# authored.
#
# Unset ALL of them, by pattern, so a NEW tunable cannot reintroduce this. Per-command
# assignments (`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work: those are the deliberate tests.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done


HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "${1:-}" "$HERE/../../hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../core/hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../.claude/hooks/ai-dlc-continue.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-continue.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the hook exactly as the harness does: JSON on stdin, decision on stdout.
# A fresh state dir per case, so the rapid-fire backoff cannot leak between them.
#
# The optional second argument is a SNAPSHOT to place in the project dir. Without it the
# project has no snapshot at all, which is the shape every pre-existing assertion below was
# written against and the shape the teammate-sweep arm deliberately fails open on.
# The optional third is the hook to drive, defaulting to the resolved one -- the mutant
# battery passes its own copy here rather than reaching into this function.
#
# A SNAPSHOT ALSO NEEDS THE PAUSE FLAG, and leaving it out is a trap that reads as a guard
# failure. Check 0 is the FIRST check in the hook; Check 1 (pause flag) and Check 2 (no
# active pipeline) are what produce an ALLOW further down. With no snapshot, Check 2 allows
# and Check 0's verdict is the only thing that can block — which is why the five original
# assertions read cleanly without either file. Add a snapshot and the pipeline is ACTIVE, so
# Rule 3 enforcement blocks every Stop regardless of Check 0, and a compliant case comes
# back `block` for a reason that has nothing to do with the arm under test. Measured here:
# three assertions failed that way before the flag was added. The flag is also what really
# happens — ai-dlc-pause.sh created it the moment the operator typed the request.
drive() { # drive <transcript> [snapshot] [hook] -> prints "block" or "allow"
  local t="$1" snap="${2:-}" hk="${3:-$HOOK}" out
  local proj; proj="$(mktemp -d)"; mkdir -p "$proj/_bmad-output/.driver"
  # STEP 4's TOUCH, DONE. Check 0 asserts `.driver/handoff` once the resume, sweep and push
  # arms are satisfied, so an ALLOW case here needs the lead's own touch on disk or it blocks
  # for a reason this fixture does not test. This is the lead's Bash action, not a hook's
  # artifact, so writing it here is seeding the actor's step and not the reader's grammar;
  # handoff-completion-assertion owns the arm and its mutant.
  : > "$proj/_bmad-output/.driver/handoff"
  [ -n "$snap" ] && { cp "$snap" "$proj/_bmad-output/pipeline-snapshot.md"
                      touch "$proj/_bmad-output/pipeline-paused.flag"; }
  out="$(jq -nc --arg t "$t" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
        | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
          bash "$hk" 2>/dev/null)"
  rm -rf "$proj"
  if printf '%s' "$out" | jq -e '.decision=="block"' >/dev/null 2>&1; then
    printf 'block'
  else
    printf 'allow'
  fi
}

# --- Assertion 0: THE DECLARATION RESOLVES, and its absence really does disarm the guard --
#
# Check 0's handoff vocabulary is no longer written in the hook. It is read from
# schemas/pause-routing.json, because ai-dlc-answer-capture.sh needs the same set to route a
# handoff that arrives as an AskUserQuestion answer, and two hand-maintained lists of
# handoff phrasings are two lists that drift. The cost of that is a new way for this guard
# to do nothing: an install that lost the schema skips Check 0 entirely and every assertion
# below then passes for the wrong reason -- an ALLOW that means "the guard never ran".
#
# BOTH DIRECTIONS, because either alone is unreadable. First: the declaration is where the
# hook will look for it. Second: with it genuinely unreachable, assertion 1's case -- a
# handoff request with no resume block, which MUST block -- comes back ALLOW. That second
# arm is what makes the first load-bearing; without it, "the file exists" is a fact about
# the tree and not about the guard.
SCHEMA="$(pick "$HERE/../../schemas/pause-routing.json" \
               "$HERE/../../../core/schemas/pause-routing.json" \
               "$HERE/../../../.claude/schemas/pause-routing.json")"
if [ -n "$SCHEMA" ]; then
  ok "pause-routing.json resolves ($SCHEMA)"
else
  bad "FIXTURE BROKEN — schemas/pause-routing.json not found in either layout; Check 0 reads its vocabulary from there and would skip, so every assertion below would pass without the guard running"
  echo ""; echo "handoff-resume-guard: FIXTURE BROKEN" >&2; rm -rf "$ROOT"; exit 2
fi

# The unreachable-declaration probe. A copy of the hook in a directory with no sibling
# schemas/, driven with a project dir that has none either and the env override pointed at a
# path that does not exist.
ISO="$ROOT/isolated"; mkdir -p "$ISO"; cp "$HOOK" "$ISO/ai-dlc-continue.sh"
iso_proj="$(mktemp -d)"; mkdir -p "$iso_proj/_bmad-output"
iso_out="$(jq -nc --arg t "$(cat "$ROOT/.p_miss")" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
          | CLAUDE_PROJECT_DIR="$iso_proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$ROOT/no-such-schema.json" \
            bash "$ISO/ai-dlc-continue.sh" 2>/dev/null)"
rm -rf "$iso_proj"
if printf '%s' "$iso_out" | jq -e '.decision=="block"' >/dev/null 2>&1; then
  bad "the guard BLOCKED with its vocabulary declaration unreachable — it is matching on something written in the hook after all, and the single-source claim is false"
else
  ok "declaration unreachable -> the guard stands down (so assertion 0's first arm is load-bearing, not decoration)"
fi

r="$(drive "$(cat "$ROOT/.p_miss")")"
[ "$r" = block ] && ok "handoff requested, NO resume block -> BLOCK" \
                 || bad "handoff requested with no resume block was ALLOWED ($r) — the guard cannot fire"

r="$(drive "$(cat "$ROOT/.p_core4")")"
[ "$r" = allow ] && ok "resume block in CORE's mandated '----' form -> ALLOW" \
                 || bad "BLOCKED a handoff that follows steps/handoff.md step 4 verbatim ($r) — the check fires on COMPLIANCE"

r="$(drive "$(cat "$ROOT/.p_six")")"
[ "$r" = allow ] && ok "resume block with six hyphens -> ALLOW (delimiter is -{4,}, not a count)" \
                 || bad "six-hyphen delimiter rejected ($r) — this is what the consumer emits today"

r="$(drive "$(cat "$ROOT/.p_undelim")")"
[ "$r" = block ] && ok "'/ai-dlc resume' present but UNDELIMITED -> BLOCK (format, not substring)" \
                 || bad "an undelimited, non-copy-pasteable mention passed ($r) — presence is not format"

r="$(drive "$(cat "$ROOT/.p_noun")")"
[ "$r" = allow ] && ok "incidental NOUN mention of 'handoff guard' -> no fire" \
                 || bad "fired on a question ABOUT the guard ($r) — spurious block, this spammed a real operator"

# --- The teammate-sweep arm -------------------------------------------------------------
#
# THE DEFECT. A lead read a handoff request correctly and then improvised: one TaskStop, a
# snapshot edit, a touched pause flag, and by its own account afterwards "no full teammate
# sweep, no commit, no push attempt". The resume block was the only thing anything checked,
# so a handoff missing four of its five steps passed the guard. The successor session
# inherits a snapshot whose In-Flight Teammates rows still say `in-flight` for teammates
# that are gone — the one piece of state no later step can reconstruct.
#
# EVERY CASE BELOW DRIVES THE SAME TRANSCRIPT. `.p_sweep` is a fully compliant handoff turn,
# so the resume arm is satisfied in all three and the only thing that varies is the
# snapshot. A case that carried its own transcript could differ on the resume block and the
# verdict would not say which arm produced it.
SWEEP="$(cat "$ROOT/.p_sweep")"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running")")"
[ "$r" = block ] && ok "compliant resume block but a row still reads 'in-flight' -> BLOCK" \
                 || bad "a handoff whose teammate sweep was never recorded was ALLOWED ($r) — this is the s305 shape, and the successor inherits a snapshot that lies about what is running"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running_note")")"
[ "$r" = block ] && ok "a running row carrying a trailing note -> BLOCK (leading token, not the whole cell)" \
                 || bad "a row reading 'in-flight, since <ts>' was ALLOWED ($r) — that is the form the reference consumer actually writes, and an equality test lets a handoff proceed with teammates still running"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_stopped")")"
[ "$r" = allow ] && ok "the same row rewritten to 'stopped' -> ALLOW (the arm accepts the state it demands)" \
                 || bad "BLOCKED a handoff that recorded its sweep exactly as steps/handoff.md step 1 mandates ($r) — the check fires on COMPLIANCE, which is worse than no check"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_nosection")")"
[ "$r" = allow ] && ok "snapshot with no In-Flight Teammates section -> ALLOW (route.md says it auto-heals)" \
                 || bad "BLOCKED a snapshot written before the In-Flight section existed ($r) — every pre-v0.50.0 snapshot would wedge at handoff"

# --- MUTANT: delete the teammate arm and the BLOCK above must become an ALLOW -----------
#
# An ABSENCE-shaped verdict is what the arm produces on the two ALLOW cases, and both-
# directions seeding establishes only that it discriminates between two inputs — not that
# it discriminates at all. The mutant is the part that establishes the arm RUNS.
#
# Built as a COPY, guarded with `cmp -s` so a `sed` that matched nothing reports FIXTURE
# STALE instead of scoring a kill, and the resolved path is printed: a mutation applied to a
# file the run never loads leaves every arm green and reads exactly like an arm that cannot
# fire. It is anchored on the ASSIGNMENT that computes the verdict rather than on the
# condition that reads it, because that condition mentions RESUME_OK too and editing it
# would move both arms at once.
#
# The mutation NEUTRALISES the verdict rather than commenting the arm out: an `if false;`
# wrapper would need its own `fi` and the balance point is a `fi` the snapshot test already
# owns. Pinning the variable and sending awk's result to a discarded name is one expression,
# one anchor, and nothing to rebalance.
MUT="$ROOT/continue-nosweep.sh"
sed 's|^      TEAMMATES_OK=\$(awk .$|      TEAMMATES_OK=1; IGNORED=$(awk '"'"'|' "$HOOK" > "$MUT"
if cmp -s "$HOOK" "$MUT"; then
  bad "FIXTURE STALE: the teammate-arm mutation matched nothing in $HOOK — the verdict assignment was reworded, so this battery is editing a file it does not understand"
else
  printf '        mutant edits: %s (from %s)\n' "$MUT" "$HOOK"
  if ! bash -n "$MUT" 2>/dev/null; then
    bad "FIXTURE STALE: the teammate-arm mutant does not parse — the mutation is not a valid disable, so a kill would be a syntax error rather than a disarmed guard"
  else
    r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running")" "$MUT")"
    [ "$r" = allow ] && ok "mutant: with the teammate arm pinned open, the 'in-flight' case is ALLOWED — the arm is what produced the BLOCK above" \
                     || bad "MUTANT DID NOT FAIL — the 'in-flight' case still returned $r with the teammate arm disabled, so that BLOCK is coming from somewhere else and this arm proves nothing"
    # CONTROL from the same directory: the mutant is otherwise a working hook. A copy that
    # died on load emits nothing, and "no output" scores as ALLOW — indistinguishable from
    # the kill above. This asserts the mutant still BLOCKS the case it was not meant to
    # touch, which is a PRESENCE-shaped conjunct rather than an absence.
    r="$(drive "$(cat "$ROOT/.p_miss")" "" "$MUT")"
    [ "$r" = block ] && ok "mutant control: the same copy still BLOCKS a missing resume block — it loads and runs, so the kill above is a disarmed arm and not a dead script" \
                     || bad "MUTANT HARNESS BROKEN — the copy no longer blocks a missing resume block either ($r); it is not running, and the kill above is unreadable"
  fi
fi

rm -rf "$ROOT"
echo ""
[ "$fails" -eq 0 ] && { echo "handoff-resume-guard: PASS"; exit 0; }
echo "handoff-resume-guard: FAIL ($fails)"; exit 1
