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
  # ORDER MATTERS: the driver arm treats a signal OLDER than the snapshot as a previous
  # handoff's, so the snapshot is copied first and the touch comes after it, as step 3 precedes
  # step 4 in the procedure.
  [ -n "$snap" ] && { cp "$snap" "$proj/_bmad-output/pipeline-snapshot.md"
                      touch "$proj/_bmad-output/pipeline-paused.flag"; }
  : > "$proj/_bmad-output/.driver/handoff"
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

# --- THE PIPELESS ROW SHAPE ---------------------------------------------------------
#
# Every case above seeds a row with a leading `|`, which is why the sweep arm's
# `/^[[:space:]]*\|/` gate could not fail: the reference consumer writes the BARE form
# and no seed here carried it. Measured on its live snapshot, this arm found 1 in-flight
# row where the relaxed form finds 5 — four live teammates invisible to the guard whose
# whole job is to stop a handoff while teammates are running.
#
# FOUR CELLS, AND THE PAIRING IS WHAT MAKES ANY OF THEM READABLE. A pipeless BLOCK on
# its own passes identically whether the guard reads the token or simply refuses every
# bare row it can now see; its ALLOW twin, one property away, is what separates those.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_running")")"
[ "$r" = block ] && ok "PIPELESS row reading 'in-flight' -> BLOCK (the cell that was dead)" \
                 || bad "a PIPELESS 'in-flight' row was ALLOWED ($r) — this is the shape the reference consumer writes, and the handoff proceeds with teammates still running"

r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_stopped")")"
[ "$r" = allow ] && ok "PIPELESS row reading 'stopped' -> ALLOW (the relaxation reads the token, it does not refuse the shape)" \
                 || bad "BLOCKED a PIPELESS row that records its sweep exactly as steps/handoff.md step 1 mandates ($r) — the guard now fires on the bare SHAPE, and no edit to that row can satisfy it"

# THE PIPELESS HEADER IS NOT A TEAMMATE. Its own last cell is the literal word
# `status`, and a guard that scores it as a data row reads a teammate that does not exist.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_header")")"
[ "$r" = allow ] && ok "PIPELESS header with no data rows -> ALLOW (the header is never a teammate)" \
                 || bad "BLOCKED on a header row alone ($r) — an empty In-Flight table wedges every handoff, and there is no row to strike"

# THE MEASURED FALSE POSITIVE. A bare `/\|/` gate reads this prose line's last
# pipe-delimited field as a status cell, and that field is `in-flight`.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_prose")")"
[ "$r" = allow ] && ok "prose ending '| in-flight' beside a swept row -> ALLOW (the header-width narrowing holds)" \
                 || bad "BLOCKED on a PROSE line carrying a pipe ($r) — that is the measured false positive of the bare-pipe form, and it wedges every handoff in the sprint with no row to fix"

# A STRAY `|` INSIDE A CELL OF A PIPED ROW MUST STILL BLOCK.
# THE CASE THAT KILLS THE MOST PLAUSIBLE WRONG FIX: applying the header-width test to
# every row instead of only to pipeless ones acquits this one, because the stray pipe
# splits it one field wide. That is a BLOCK the pre-fix arm already produced, so the
# uniform form is a regression rather than a simplification.
r="$(drive "$SWEEP" "$(cat "$ROOT/.s_straypipe")")"
[ "$r" = block ] && ok "PIPED 'in-flight' row with a stray pipe inside a cell -> BLOCK (the width test did not leak onto piped rows)" \
                 || bad "a piped 'in-flight' row carrying a stray '|' was ALLOWED ($r) — the width test was applied uniformly and the relaxation LOST a block the pre-fix arm had"

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

# --- MUTANTS FOR THE PIPELESS ARMS --------------------------------------------------
#
# Four mutants, each keyed on a LOCATION in the sweep awk and scored on the hook's own
# observable — its block/allow decision — never on a spelling. Each is a COPY guarded by
# `cmp -s` and by `bash -n`, and each carries a CONTROL from the same copy on a case it
# was not meant to touch: a copy that died on load emits nothing, and no output reads as
# ALLOW, which is indistinguishable from three of the four kills below.
#
# WHAT EACH KILLS, one wrong implementation apiece:
#   the pre-fix leading-pipe gate  -> the pipeless BLOCK becomes an ALLOW
#   the bare `/\|/` form           -> the prose case becomes a BLOCK
#   the uniform width test         -> the stray-pipe BLOCK becomes an ALLOW
#   ncols taken from the first row -> the pipeless BLOCK becomes an ALLOW
hook_mut() { # hook_mut <dest> <sed-expr> <label>  -> 0 if usable
  sed "$2" "$HOOK" > "$1" || { bad "MUTANT $3: sed DIED — the mutation never existed"; return 1; }
  if cmp -s "$HOOK" "$1"; then
    bad "FIXTURE STALE: mutation $3 matched nothing in $HOOK — re-anchor it on the real line"
    return 1
  fi
  if ! bash -n "$1" 2>/dev/null; then
    bad "FIXTURE STALE: mutant $3 does not parse — a kill would be a syntax error, not a disarmed guard"
    return 1
  fi
  return 0
}

# THE BACKSLASH IN A sed REPLACEMENT MUST BE DOUBLED, and this is not cosmetic: a single
# `\|` is consumed, the mutant lands as `/^[[:space:]]*|/`, and in awk that is an
# ALTERNATION OF TWO EMPTY BRANCHES matching every line. Measured while building the
# sibling battery in inflight-row-shape: that mutant killed three arms at once and read
# as a successful revert. The arm below asserts the escape survived, byte-wise.
M_GATE="$ROOT/continue-prefixgate.sh"
if hook_mut "$M_GATE" 's%^        inb && /\\|/ {%        inb \&\& /^[[:space:]]*\\|/ {%' "pre-fix gate"; then
  if grep -qF 'inb && /^[[:space:]]*\|/ {' "$M_GATE"; then
    ok "mutant (pre-fix gate) applied with its escape intact"
  else
    bad "MUTANT (pre-fix gate) LOST ITS BACKSLASH — the gate became an empty alternation matching every line, so the kill below is a dead program rather than the pre-fix guard"
  fi
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_running")" "$M_GATE")"
  [ "$r" = allow ] && ok "mutant (pre-fix gate): the PIPELESS 'in-flight' row is ALLOWED — that BLOCK is the relaxation's, and this is the program that shipped" \
                   || bad "MUTANT DID NOT FAIL — the leading-pipe gate still returned $r on a pipeless row; either the seed is not pipeless or that BLOCK comes from elsewhere"
  # CONTROL, and it is the same conjunct that makes this a REVERT rather than a
  # disabled arm: the pre-fix guard blocked PIPED in-flight rows and must still do so.
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running")" "$M_GATE")"
  [ "$r" = block ] && ok "mutant control (pre-fix gate): the same copy still BLOCKS a PIPED 'in-flight' row — it reverts the gate, it does not disable the arm" \
                   || bad "MUTANT HARNESS BROKEN — the copy no longer blocks a piped 'in-flight' row either ($r); it is not running, and the kill above is unreadable"
fi

# DROP THE WIDTH TEST, leaving the bare `/\|/` form. Scored on the prose case, whose
# last pipe-delimited field is `in-flight`.
M_NOWIDTH="$ROOT/continue-nowidth.sh"
if hook_mut "$M_NOWIDTH" '/if (!piped \&\& n != ncols) next/d' "bare-pipe"; then
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_prose")" "$M_NOWIDTH")"
  [ "$r" = block ] && ok "mutant (bare-pipe): the PROSE line is read as a row and BLOCKS — the header-width narrowing is what holds that false positive at zero" \
                   || bad "MUTANT DID NOT FAIL — without the width test the prose case still returned $r, so that ALLOW is not the narrowing's and the prose arm proves nothing"
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_stopped")" "$M_NOWIDTH")"
  [ "$r" = allow ] && ok "mutant control (bare-pipe): the same copy still ALLOWS a swept pipeless row — it loads and reads tokens" \
                   || bad "MUTANT HARNESS BROKEN — the copy blocks a legal pipeless row too ($r); it is not discriminating, and the kill above is unreadable"
fi

# APPLY THE WIDTH TEST TO EVERY ROW. The simpler fix, and a regression: it passes every
# pipeless arm above and silently drops a BLOCK the pre-fix arm already produced.
M_UNIFORM="$ROOT/continue-uniform.sh"
if hook_mut "$M_UNIFORM" 's|if (!piped \&\& n != ncols) next|if (n != ncols) next|' "uniform width"; then
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_straypipe")" "$M_UNIFORM")"
  [ "$r" = allow ] && ok "mutant (uniform width): the stray-pipe row is ACQUITTED and the handoff proceeds — restricting the width test to pipeless lines is what keeps the relaxation a superset" \
                   || bad "MUTANT DID NOT FAIL — the uniform width test still returned $r on the stray-pipe row, so that arm cannot distinguish the two forms"
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running")" "$M_UNIFORM")"
  [ "$r" = block ] && ok "mutant control (uniform width): the same copy still BLOCKS an ordinary piped 'in-flight' row — the acquittal above is the stray pipe, not a dead arm" \
                   || bad "MUTANT HARNESS BROKEN — the copy allows an ordinary piped 'in-flight' row too ($r); it is not running, and the kill above is unreadable"
fi

# TAKE ncols FROM THE FIRST ROW rather than from the row declaring `status`. The width
# then comes from whatever pipe-bearing line appears first instead of from the table's
# own declaration, and the pipeless data row is measured against a width nothing declared.
M_FIRSTROW="$ROOT/continue-firstrow.sh"
if hook_mut "$M_FIRSTROW" 's|if (tolower(last) == "status") { ncols = n; next }|if (tolower(last) == "status") { next }|' "ncols from first row"; then
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_pl_running")" "$M_FIRSTROW")"
  [ "$r" = allow ] && ok "mutant (ncols from first row): with the header's width recording gone the pipeless 'in-flight' row escapes — the arm is bound to the DERIVED width, not to any width" \
                   || bad "MUTANT DID NOT FAIL — the pipeless row still returned $r with the header's ncols removed, so that BLOCK passes under a width from somewhere else"
  r="$(drive "$SWEEP" "$(cat "$ROOT/.s_running")" "$M_FIRSTROW")"
  [ "$r" = block ] && ok "mutant control (ncols from first row): the same copy still BLOCKS a PIPED 'in-flight' row — piped rows never consult ncols, so the escape above is the pipeless path alone" \
                   || bad "MUTANT HARNESS BROKEN — the copy allows a piped 'in-flight' row too ($r); it is not running, and the kill above is unreadable"
fi

# --- THE IN-FLIGHT ROW ARM ----------------------------------------------------------
#
# THE DEFECT. `steps/handoff.md` step 1 requires every dispatched teammate to be RECORDED
# in the snapshot's In-Flight Teammates table. The sweep arm above convicts a row that
# still reads `in-flight`; it is silent on a table with no rows at all, which is what a
# handoff that skipped step 1 entirely leaves behind. Measured on the reference consumer:
# 459 role-bound dispatches across sprints 307-311 and ZERO rows recorded over that span.
# Every one of those handoffs passed the sweep arm, correctly -- it can only convict a row
# somebody wrote.
#
# EACH CASE IS A WORLD, NOT A SNAPSHOT. The arm reads four files: the lead transcript
# (Agent/Task tool_use records), `spawn-ledger.jsonl`, the harness meta sidecars under
# `${TRANSCRIPT%.jsonl}/subagents/`, and `subagent-context.jsonl`. seed.sh builds each
# world with its own four, so a case cannot be handed another case's ledger.
#
# THE SCRUB IS WHY THESE ARE FILES AND NOT ENV. This fixture unsets every `AI_DLC_*`
# variable before driving anything (see the header). `AI_DLC_STATE_DIR` is one of them, so
# a world that relocated the ledgers by exporting it would be driving a hook that had
# forgotten the relocation -- the arm would read `_bmad-output/` and find nothing, and
# every case would ALLOW for a reason no assertion states. The worlds therefore write to
# the default `_bmad-output/` and the driver copies them in.
drive_world() { # drive_world <world-dir> [hook] -> "block" or "allow" (stderr: raw reason)
  local w="$1" hk="${2:-$HOOK}" out proj
  proj="$(mktemp -d)"; mkdir -p "$proj/_bmad-output/.driver"
  snap_from_body "$w/snapshot-body.md" > "$proj/_bmad-output/pipeline-snapshot.md"
  touch "$proj/_bmad-output/pipeline-paused.flag"
  cp "$w/_bmad-output/spawn-ledger.jsonl"     "$proj/_bmad-output/" 2>/dev/null || true
  cp "$w/_bmad-output/subagent-context.jsonl" "$proj/_bmad-output/" 2>/dev/null || true
  : > "$proj/_bmad-output/.driver/handoff"
  out="$(jq -nc --arg t "$w/lead.jsonl" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
        | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
          bash "$hk" 2>/dev/null)"
  rm -rf "$proj"
  # THE REASON GOES TO STDERR SO THE VERDICT CAN STAY ON STDOUT, and the redirection
  # ORDER is the whole trap: `2>/dev/null >&2` points stderr at /dev/null FIRST and then
  # duplicates stdout onto that same discarded descriptor, so the reason vanishes and
  # every text assertion below reads an empty file. Measured here — three assertions
  # failed against a hook whose message was correct. Capture into a variable, then write
  # it, rather than chaining redirections on one pipeline.
  local reason; reason="$(printf '%s' "$out" | jq -r '.reason // ""' 2>/dev/null)" || reason=""
  printf '%s\n' "$reason" >&2
  if printf '%s' "$out" | jq -e '.decision=="block"' >/dev/null 2>&1; then
    printf 'block'
  else
    printf 'allow'
  fi
}

# The world seeds carry only the In-Flight BODY; the surrounding snapshot is written
# here from the same seven-section shape seed.sh uses for the sweep cases, so a world
# cannot differ from a sweep case in anything but that body.
snap_from_body() {
  printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step_file: implementation.md\n\n'
  printf '## Sprint Context\nsprint_id: 311\n\n## Recent Activity\n- gate 3 in progress\n\n'
  printf '## Open Items\n- none\n\n## Locked Decisions\n- none\n\n## In-Flight Teammates\n'
  cat "$1"
  printf '\n\n## Context Reminders\ncontext_reminders_sent: none\n'
}

W_OFF="$(cat "$ROOT/.w_offender")"

# (A) THE OFFENDER. A dispatch with a ledger row, a meta sidecar, no stop record, and an
#     EMPTY table -> BLOCK, and the message must NAME the id: a block that says only
#     "something is open" cannot be acted on, and this is the presence-shaped conjunct
#     that a hook emitting nothing fails by construction.
a_err="$(mktemp)"
r="$(drive_world "$W_OFF" 2>"$a_err")"
[ "$r" = block ] && ok "A: dispatch with no stop record + EMPTY In-Flight table -> BLOCK" \
                 || bad "A: the offender world was ALLOWED ($r) — a handoff leaves an empty table with a teammate whose fate no later step can reconstruct"
if grep -qF 'toolu_01FIXTUREoffender000000000' "$a_err"; then
  ok "A: the block message NAMES the open tool_use_id"
else
  bad "A: the block message does NOT name the open tool_use_id — the lead is told a row is missing and not which row to write"
fi
if grep -qF 'dev-escalated' "$a_err"; then
  ok "A: the block message carries the ledger name/role for the open id"
else
  bad "A: the block message carries no ledger name/role — the lead cannot fill the row's \`agent\` and \`role\` cells"
fi
# THE REMEDY IS THE ROW, NOT TaskStop, AND THAT IS A MEASUREMENT NOT A PREFERENCE. The
# one true positive on the consumer FINISHED cleanly (its tool_result carries no error)
# and wrote no stop record, so TaskStop can neither clear the state nor report anything.
# A message that sent the lead to TaskStop would send it to a call that does nothing.
if grep -qF 'TaskStop' "$a_err" && grep -qF 'Do NOT call' "$a_err"; then
  ok "A: the message tells the lead to WRITE the row and explicitly NOT to call TaskStop"
else
  bad "A: the message does not steer away from TaskStop — a missing stop record is not evidence the teammate is running, and TaskStop cannot clear a record that was never written"
fi
rm -f "$a_err"

# (B) THE TABLE CARRIES A MATCHING ROW -> ALLOW. One property from (A).
r="$(drive_world "$(cat "$ROOT/.w_tablerow")" 2>/dev/null)"
[ "$r" = allow ] && ok "B: the same dispatch RECORDED in the table -> ALLOW" \
                 || bad "B: BLOCKED a handoff that wrote the row step 1 mandates ($r) — the arm fires on COMPLIANCE"

# (C) THE STOP RECORD EXISTS -> ALLOW. The teammate returned and the probe wrote its row,
#     so there is nothing outstanding and the empty table is correct.
r="$(drive_world "$(cat "$ROOT/.w_ctxrow")" 2>/dev/null)"
[ "$r" = allow ] && ok "C: the dispatch HAS a SubagentStop record -> ALLOW (empty table is correct)" \
                 || bad "C: BLOCKED over a teammate that already returned ($r) — the stop-record difference is not being taken, and every completed dispatch would wedge a handoff"

# (D) NEVER SPAWNED -> ALLOW. The guard writes the ledger row at PreToolUse, before
#     anything can deny the call, so a Rule-29 denial and an agent type that does not
#     exist both leave a row with no agent behind it. Measured: of the naive join's 3
#     open ids on the consumer, 2 were Rule-29 denials and the meta narrowing removes
#     exactly those, leaving 1.
r="$(drive_world "$(cat "$ROOT/.w_nospawn")" 2>/dev/null)"
[ "$r" = allow ] && ok "D: ledger row with NO meta sidecar (never spawned) -> ALLOW" \
                 || bad "D: BLOCKED over a dispatch that never spawned ($r) — a Rule-29 denial would wedge the next handoff over a teammate that does not exist"

# (E) A LIVE NAMED TEAMMATE -> ALLOW. THE STATED BLINDNESS, asserted rather than left
#     implicit. A named dispatch routes to the in-process teammate runner, whose meta
#     carries `teamName` and no `toolUseId`; partitioned over the harness corpus the two
#     keys never co-occur (330 toolUseId-only, 672 teamName-only, 0 both, 0 neither). A
#     name-keyed join was built and refuted — 115 false blocks over 303 rows. This cell
#     flips the day somebody adds one, which is the point of asserting it.
r="$(drive_world "$(cat "$ROOT/.w_namedteam")" 2>/dev/null)"
[ "$r" = allow ] && ok "E: live NAMED teammate (no tool_use_id, meta has teamName) -> ALLOW (the stated blindness)" \
                 || bad "E: BLOCKED on a named in-process teammate ($r) — that class carries no join key at all, so a block there is keyed on something the arm's header says it does not read"

# (F) FAIL-OPEN WITH NO jq. A PATH stub that exits 127 for every invocation, which is
#     what a consumer without jq looks like from inside the hook. The whole hook needs
#     jq to emit a decision at all, so the assertion is that the run produces NO block
#     text — an arm that convicted here would be reading an absence as a finding.
JQSTUB="$ROOT/nojq"; mkdir -p "$JQSTUB"
printf '#!/bin/sh\nexit 127\n' > "$JQSTUB/jq"; chmod +x "$JQSTUB/jq"
f_out="$(jq -nc --arg t "$W_OFF/lead.jsonl" --arg s "fx" '{transcript_path:$t,session_id:$s}')"
f_proj="$(mktemp -d)"; mkdir -p "$f_proj/_bmad-output/.driver"
snap_from_body "$W_OFF/snapshot-body.md" > "$f_proj/_bmad-output/pipeline-snapshot.md"
touch "$f_proj/_bmad-output/pipeline-paused.flag"
cp "$W_OFF/_bmad-output/"*.jsonl "$f_proj/_bmad-output/" 2>/dev/null || true
: > "$f_proj/_bmad-output/.driver/handoff"
f_res="$(printf '%s' "$f_out" | PATH="$JQSTUB:$PATH" CLAUDE_PROJECT_DIR="$f_proj" \
         AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$HOOK" 2>/dev/null)"
rm -rf "$f_proj"
# A HERE-STRING, NOT A PIPE INTO `grep -q`. `grep -q` leaves at its first match while the
# writer is still pushing, and under this file's `pipefail` the pipeline then answers with
# the writer's EPIPE and reports NOT-FOUND on input that contains the pattern. I54b of
# validate-enforcement-map.sh fails the push on the piped form.
if [ -z "$f_res" ] || ! grep -qF 'HANDOFF GUARD' <<<"$f_res"; then
  ok "F: jq shadowed by a stub exiting 127 -> no block text (fail-open, a handoff is never wedged by bookkeeping)"
else
  bad "F: the guard emitted block text with jq unavailable — it is convicting on an absence it cannot read, and every consumer without jq wedges at its first handoff"
fi
# CONTROL for F, and it is what makes the silence above readable: the stub really does
# shadow jq. Without it "no output" is equally consistent with the stub never being on
# PATH and the hook running normally on a world that happens to allow.
if PATH="$JQSTUB:$PATH" jq --version >/dev/null 2>&1; then
  bad "F CONTROL: the jq stub did NOT shadow the real jq — case F proved nothing about the fail-open path"
else
  ok "F control: the stub genuinely shadows jq (so F's silence is the fail-open path)"
fi

# (G) THE TRANSCRIPT PATH NAMES NO FILE -> fail open. Built from the offender world with
#     its transcript removed, so every other input still convicts.
G_W="$(cat "$ROOT/.w_notranscript")"
rm -f "$G_W/lead.jsonl"
r="$(drive_world "$G_W" 2>/dev/null)"
[ "$r" = allow ] && ok "G: transcript path names no file -> ALLOW (fail-open)" \
                 || bad "G: BLOCKED with no transcript to read ($r) — the arm is producing a verdict from a set it never derived"

# (H) NO META DIRECTORY beside the transcript -> fail open. A harness build that writes
#     no sidecars, or a session predating them. Without the narrowing this world is the
#     offender, so an arm that skipped the directory check would BLOCK here.
r="$(drive_world "$(cat "$ROOT/.w_nometadir")" 2>/dev/null)"
[ "$r" = allow ] && ok "H: no subagents/ meta directory -> ALLOW (fail-open)" \
                 || bad "H: BLOCKED with no meta sidecars on disk ($r) — a consumer whose harness writes none would wedge at every handoff"

# (I) ONE UNRELATED ROW IN THE TABLE -> ALLOW. THE STATED ACQUITTAL. The check is a
#     PRESENCE test, not an identity join, and one row from any dispatch acquits the
#     turn. The reason is coverage: over 647 tracked snapshot revisions on the reference
#     consumer, 2 of 115 distinct In-Flight first cells resolve to a spawn meta at all
#     and NEITHER reaches a ledger row, so an identity join false-positives on the whole
#     historical population. Asserted so the acquittal is visible rather than latent.
r="$(drive_world "$(cat "$ROOT/.w_unrelatedrow")" 2>/dev/null)"
[ "$r" = allow ] && ok "I: table carries one UNRELATED row -> ALLOW (the stated acquittal: presence, not identity)" \
                 || bad "I: BLOCKED with a row present in the table ($r) — the arm has become an identity join, which the header says it is not and which false-positives on 113 of 115 historical rows"

# --- MUTANTS FOR THE IN-FLIGHT ROW ARM ----------------------------------------------
#
# FOUR MUTANTS, one per wrong implementation, each a COPY guarded by `cmp -s` and
# `bash -n` through hook_mut above, each scored on the hook's block/allow decision, and
# each carrying a CONTROL on a case it was not meant to touch. A copy that died on load
# emits nothing and "no output" scores as ALLOW, which is indistinguishable from three of
# the four kills.
#
# WHAT EACH KILLS:
#   m1 drop the stop-record difference  -> C blocks (a returned teammate wedges a handoff)
#   m2 drop the meta narrowing          -> D blocks (a never-spawned dispatch wedges one)
#   m3 fire regardless of the row count  -> B and I block (every handoff wedges)
#   m4 read `tail -n 200` of the transcript -> A allows (the dispatch is above the window)

# m1: the set difference against the stop log is dropped, so a dispatch that RETURNED is
#     still "open". Anchored on the assignment that computes OPEN_IDS.
#     The candidate set is assigned straight through, which is the difference against an
#     EMPTY stop log — one conjunct gone, not a script with a hole in it. The `|`, `$`
#     and `/` inside the matched text are wildcarded with `.` rather than escaped, and
#     the replacement carries no `&` (the whole match, under every sed) and no backslash
#     (a `\n` there is a bare `n` under BSD sed). The delimiter is `|` and not `%`: BSD
#     sed rejects an expression OPENING with `%` as an invalid command code, which is how
#     this mutation first died — and `hook_mut` would have reported that as DID NOT APPLY.
M_NOCTX="$ROOT/continue-noctx.sh"
if hook_mut "$M_NOCTX" 's|OPEN_IDS="$(_if_minus "$_if_cand" "$_if_stop" . sed ./^$/d.)" .. OPEN_IDS=""|OPEN_IDS="$_if_cand"|' "m1 no-ctx-difference"; then
  r="$(drive_world "$(cat "$ROOT/.w_ctxrow")" "$M_NOCTX" 2>/dev/null)"
  [ "$r" = block ] && ok "m1 (drop the stop-record difference): case C now BLOCKS — that ALLOW is the difference, and without it every completed teammate wedges the next handoff" \
                   || bad "MUTANT m1 DID NOT FAIL — case C still returned $r with the stop-record difference removed, so C proves nothing about it"
  r="$(drive_world "$(cat "$ROOT/.w_tablerow")" "$M_NOCTX" 2>/dev/null)"
  [ "$r" = allow ] && ok "m1 control: the same copy still ALLOWS case B — it loads and reads the table, so the kill above is a dropped difference and not a dead script" \
                   || bad "MUTANT m1 HARNESS BROKEN — the copy blocks case B too ($r); it is not discriminating and the kill above is unreadable"
fi

# m2: the meta narrowing is dropped, so a ledger row for a dispatch that never spawned is
#     "open". This is the naive join the FP measurement started from.
M_NOMETA="$ROOT/continue-nometa.sh"
if hook_mut "$M_NOMETA" 's|_if_cand="$(_if_isect "$_if_cand" "$_if_metaids")" .. _if_cand=""|_if_cand="$_if_cand"|' "m2 no-meta-narrowing"; then
  r="$(drive_world "$(cat "$ROOT/.w_nospawn")" "$M_NOMETA" 2>/dev/null)"
  [ "$r" = block ] && ok "m2 (drop the meta narrowing): case D now BLOCKS — the narrowing is what removes a dispatch that was denied before it ever spawned" \
                   || bad "MUTANT m2 DID NOT FAIL — case D still returned $r with the meta narrowing removed, so that ALLOW comes from somewhere else"
  r="$(drive_world "$(cat "$ROOT/.w_ctxrow")" "$M_NOMETA" 2>/dev/null)"
  [ "$r" = allow ] && ok "m2 control: the same copy still ALLOWS case C — it loads and still takes the stop-record difference" \
                   || bad "MUTANT m2 HARNESS BROKEN — the copy blocks case C too ($r); it is not running the rest of the predicate"
fi

# m3: the row-count conjunct is dropped, so the arm fires whenever anything is open
#     regardless of what the table says. Killed by B AND by I, which are different
#     properties: B writes the matching row, I writes an unrelated one.
M_NOROWS="$ROOT/continue-norows.sh"
if hook_mut "$M_NOROWS" 's|if \[ "$OPEN_N" -gt 0 \] \&\& \[ "$INFLIGHT_ROWS" -eq 0 \]; then|if [ "$OPEN_N" -gt 0 ]; then|' "m3 ignore-row-count"; then
  r="$(drive_world "$(cat "$ROOT/.w_tablerow")" "$M_NOROWS" 2>/dev/null)"
  [ "$r" = block ] && ok "m3 (fire regardless of the row count): case B now BLOCKS — the count conjunct is what lets a compliant handoff through" \
                   || bad "MUTANT m3 DID NOT FAIL on B — case B still returned $r without the row-count test, so B is not scoring that conjunct"
  r="$(drive_world "$(cat "$ROOT/.w_unrelatedrow")" "$M_NOROWS" 2>/dev/null)"
  [ "$r" = block ] && ok "m3: case I also BLOCKS — the acquittal in I is the row COUNT, seeded one property away from B" \
                   || bad "MUTANT m3 DID NOT FAIL on I — case I still returned $r, so the unrelated-row acquittal is not the count"
  r="$(drive_world "$(cat "$ROOT/.w_ctxrow")" "$M_NOROWS" 2>/dev/null)"
  [ "$r" = allow ] && ok "m3 control: the same copy still ALLOWS case C — nothing is open there, so the count was never consulted" \
                   || bad "MUTANT m3 HARNESS BROKEN — the copy blocks case C too ($r), where the open set is empty; it is convicting unconditionally"
fi

# m4: the transcript is read through a `tail -n 200` window — the shape Check 0b uses for
#     its pause-question prefilter, and the cheap wrong fix here. Measured on the
#     reference consumer: across the sessions this arm was scored on, that window sees 1
#     dispatch of 80, because dispatches are spread through a session rather than
#     clustered at its end. The offender seed pads 400 records after the dispatch.
M_TAIL="$ROOT/continue-tail200.sh"
if hook_mut "$M_TAIL" 's|            . .id. "$TRANSCRIPT" 2>/dev/null . sort -u)" .. _if_disp=""|            \| .id'"'"' <(tail -n 200 "$TRANSCRIPT") 2>/dev/null \| sort -u)" \|\| _if_disp=""|' "m4 tail-200 window"; then
  r="$(drive_world "$W_OFF" "$M_TAIL" 2>/dev/null)"
  [ "$r" = allow ] && ok "m4 (tail -n 200 window): the OFFENDER is ALLOWED — the dispatch sits above the window, which is the real shape and why the transcript is read whole" \
                   || bad "MUTANT m4 DID NOT FAIL — the offender still returned $r through a 200-record window, so the seed does not place the dispatch above it and the whole-file read is unasserted"
  r="$(drive_world "$(cat "$ROOT/.w_tablerow")" "$M_TAIL" 2>/dev/null)"
  [ "$r" = allow ] && ok "m4 control: the same copy still ALLOWS case B — it loads and runs" \
                   || bad "MUTANT m4 HARNESS BROKEN — the copy blocks case B ($r); it is not running the arm at all"
fi

# --- Beat-before-stop arm -----------------------------------------------------------
#
# THE DEFECT THIS ARM EXISTS FOR. Measured on the reference consumer: an adversary pass
# was dispatched, the operator typed `handoff`, step 1 called `TaskStop` on every
# in-flight teammate with no join first, and the resumed session dispatched the same
# pass again from scratch — 38 minutes of opus time for a pass that would have landed
# in under one wait beat. `steps/handoff.md` step 1 and its copy in `_gate-procedures.md`
# "Auto-handoff evaluation" step 1 now run ONE `wait-for-deliverable.sh` beat over every
# in-flight row before calling `TaskStop`, and the two copies must carry the SAME clause
# — a copy that drifts is the defect class this whole fixture's header describes.
#
# TOKENS. `wait-for-deliverable.sh` names the beat script; `still absent after the beat`
# is the exact phrase marking which rows still get stopped. Both are asserted in BOTH
# files so a future edit to either cannot silently drop the join or reword it out of
# step with its sibling.
HANDOFF_MD="$(pick "$HERE/../../skills/ai-dlc/steps/handoff.md" \
                    "$HERE/../../../core/skills/ai-dlc/steps/handoff.md" \
                    "$HERE/../../../.claude/skills/ai-dlc/steps/handoff.md")"
GATE_PROC_MD="$(pick "$HERE/../../skills/ai-dlc/steps/_gate-procedures.md" \
                      "$HERE/../../../core/skills/ai-dlc/steps/_gate-procedures.md" \
                      "$HERE/../../../.claude/skills/ai-dlc/steps/_gate-procedures.md")"
if [ -z "$HANDOFF_MD" ] || [ -z "$GATE_PROC_MD" ]; then
  bad "FIXTURE BROKEN — could not locate handoff.md and/or _gate-procedures.md in either layout"
else
  # Extract step 1 of a "Stop all in-flight teammates" procedure: from the opening bold
  # line to the line before the next numbered "2. " step. Two occurrences can exist in
  # one file (handoff.md's own procedure, and a second copy if one is ever pasted in);
  # this greps every such block in the file, which is a superset of the single block
  # each of today's two files carries and still correct if that ever changes.
  extract_step1() {
    awk '
      /^1\. \*\*Stop all in-flight teammates first\.\*\*/ { f=1 }
      f { print }
      f && /^2\. / && !/^1\. / { exit }
    ' "$1"
  }
  check_beat_clause() { # check_beat_clause <label> <text>
    local label="$1" text="$2"
    if grep -qF 'wait-for-deliverable.sh' <<<"$text" \
       && grep -qF 'still absent after the beat' <<<"$text"; then
      ok "$label carries the beat-before-stop clause"
    else
      bad "$label is missing 'wait-for-deliverable.sh' and/or 'still absent after the beat' in its step 1 — the two-file clause has drifted or been dropped"
    fi
  }

  # THE SELF-PROBE, run BEFORE the corpus checks below so a check that cannot fire is
  # not mistaken for one that passed: a scratch copy of handoff.md with the clause
  # deleted (reverted to the pre-fix wording) must FAIL the same assertion. Built as a
  # copy per fixture-mutants.md, guarded by cmp -s.
  DECOY="$ROOT/handoff-nobeat.md"
  awk '
    /^1\. \*\*Stop all in-flight teammates first\.\*\*/ {
      print "1. **Stop all in-flight teammates first.** Call `TaskStop` on"
      print "   every `in_progress` task. Halt any Agent-spawned teammate not"
      print "   bound to a task. Wait until every teammate has returned before"
      print "   proceeding. Record stopped teammates and in-flight artifacts"
      print "   in the snapshot'"'"'s Open Items in Step 3, and set each stopped"
      print "   teammate'"'"'s **In-Flight Teammates** row `status` to `stopped`."
      skip=1
      next
    }
    skip && /^2\. / { skip=0 }
    skip { next }
    { print }
  ' "$HANDOFF_MD" > "$DECOY"
  if cmp -s "$HANDOFF_MD" "$DECOY"; then
    bad "FIXTURE STALE: the decoy rewrite produced a byte-identical copy of handoff.md — the self-probe cannot discriminate anything"
  else
    decoy_step1="$(extract_step1 "$DECOY")"
    if grep -qF 'wait-for-deliverable.sh' <<<"$decoy_step1" \
       && grep -qF 'still absent after the beat' <<<"$decoy_step1"; then
      bad "SELF-PROBE FAILED: a decoy with the beat clause deleted still matched the assertion — it cannot discriminate, so the two ok's above are not evidence"
    else
      ok "self-probe: a decoy with the beat clause removed correctly FAILS the assertion"
    fi
  fi

  # Only now, with the self-probe having shown the assertion can fail, run it on the
  # real corpus.
  h_step1="$(extract_step1 "$HANDOFF_MD")"
  g_step1="$(extract_step1 "$GATE_PROC_MD")"
  check_beat_clause "handoff.md step 1" "$h_step1"
  check_beat_clause "_gate-procedures.md step 1" "$g_step1"
fi

rm -rf "$ROOT"
echo ""
[ "$fails" -eq 0 ] && { echo "handoff-resume-guard: PASS"; exit 0; }
echo "handoff-resume-guard: FAIL ($fails)"; exit 1
