#!/usr/bin/env bash
# context-provenance — drives core/hooks/ai-dlc-context-provenance.sh and two of the
# nine hooks that prefix their `additionalContext` with its marker.
#
# WHAT THE SUBJECT IS. The library is a SOURCED library, not a hook: no settings file
# registers it and no event invokes it. Its whole observable surface is what a hook's
# emitted JSON carries and what lands in `_bmad-output/.ai-dlc-context-nonce`. So every
# assertion here reads one of those two, and the library is only ever reached the way a
# hook reaches it — by a hook sourcing its sibling copy.
#
# WHY TWO HOOKS AND NOT ONE. `ai-dlc-rules-floor.sh` passes a LITERAL `SessionStart` to
# `ai_dlc_provenance_tag`, so it can only ever exercise the rotating branch and the
# contract paragraph. `ai-dlc-context-sensor.sh` passes its own `$EVENT`, which is the
# only end-to-end way to reach the REUSE branch and the no-contract branch. A fixture
# that drove one hook would assert the event split against a library function it called
# itself, and a call site that passed the wrong event literal would stay invisible —
# which is the defect the split exists to catch.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the subject regressed, 2 = fixture broken.
set -uo pipefail

# HERMETIC. The pre-push gate exports every AI_DLC_* tunable a consumer set in
# settings.json into this process, and I10 fails the push on a hook-driving fixture that
# does not scrub them. The context-sensor honours several; a consumer that pinned one
# would fail this file against hooks behaving exactly as specified.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# Same class, different prefix: the sensor's window resolution reads this ahead of every
# settings layer, and the sandboxed layers below could not override an ambient export.
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW
unset CLAUDE_CONFIG_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS, BOTH ROOTED AT THIS FILE. install.sh splits what shares a parent here:
# core/fixtures/<x> lands at tests/fixtures/<x> and core/hooks/ lands at .claude/hooks/,
# so the hooks are two levels up in the distribution and three levels up plus .claude/
# in a consumer. Every candidate starts from $HERE — I33 fails the build on a fixture
# that reaches a core subtree by walking up from a path some other resolver produced.
#
# THERE IS DELIBERATELY NO REPO-ROOT WALK. This fixture needs no repo root: an installed
# consumer has no VERSION marker at its root, so a walk-up for one would resolve to the
# operator's enclosing checkout or to nothing, and the fixture would answer about the
# wrong tree exactly where it matters most.
resolve() {  # <basename> -> absolute path, or empty
  local n="$1" c
  for c in "$HERE/../../hooks/$n" "$HERE/../../../.claude/hooks/$n"; do
    [ -f "$c" ] && { printf '%s/%s' "$(cd "$(dirname "$c")" && pwd)" "$n"; return 0; }
  done
  return 1
}

LIB="$(resolve ai-dlc-context-provenance.sh)" || LIB=""
FLOOR="$(resolve ai-dlc-rules-floor.sh)" || FLOOR=""
SENSOR="$(resolve ai-dlc-context-sensor.sh)" || SENSOR=""

if [ -z "$LIB" ] || [ -z "$FLOOR" ] || [ -z "$SENSOR" ]; then
  echo "FIXTURE ERROR: could not locate the library or a driver hook from $HERE" >&2
  echo "  lib=${LIB:-<absent>} floor=${FLOOR:-<absent>} sensor=${SENSOR:-<absent>}" >&2
  exit 2
fi

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
chk() { [ "$2" = "$3" ] && ok "$1" || bad "$1 -- expected '$3', got '$2'"; }

echo "context-provenance:"
# Print the RESOLVED paths. A fixture that mutated or measured the copy it never loaded
# reads exactly like one whose arms cannot fire.
printf '  ..    lib=%s\n' "$LIB"
printf '  ..    drivers=%s , %s\n' "$FLOOR" "$SENSOR"

TOKEN='[AI-DLC-HOOK-PROVENANCE'
STORE_REL='_bmad-output/.ai-dlc-context-nonce'

# ---------------------------------------------------------------------------
# PREDICATES. Each one is probed in BOTH directions below, before any of them is
# pointed at the subject. An arm built on an unprobed predicate reports that it ran,
# not that the subject is well-formed.
# ---------------------------------------------------------------------------

is_json()      { jq -e . "$1" >/dev/null 2>&1; }

# Anchored at byte 0, never a whole-file grep: a block that MENTIONS the token further
# down is precisely the forgery the marker exists to exclude, and `grep -F` accepts it.
starts_with()  { [ "$(head -c "${#2}" "$1" 2>/dev/null)" = "$2" ]; }

# Membership is EXACT on the last field. A substring test would score a prefix of a real
# nonce as a member, and the store's own trim boundary is asserted with one.
member()       { awk -v n="$2" '$NF==n{f=1} END{exit !f}' "$1" 2>/dev/null; }

# Byte-exact suffix. This is how "the payload survives" is established: not by grepping
# for a phrase that a mangled payload still contains, but by comparing the tail of the
# marked context against the whole of the unmarked one.
suffix_is()    { tail -c "$(wc -c < "$2" | tr -d ' ')" "$1" 2>/dev/null | cmp -s - "$2"; }

# `grep -c` PRINTS 0 and EXITS 1 on no match. An `|| printf 0` fallback therefore emits
# a SECOND zero on exactly the input the arms care about, and every absence assertion
# then compares against "0\n0" and fails for a reason that has nothing to do with the
# subject. Take grep's own count and let the exit status go.
countF()       { grep -cF -- "$2" "$1" 2>/dev/null | tr -d ' '; }
nonce_of()     { head -c 200 "$1" 2>/dev/null \
                   | sed -n 's/^.*nonce=\([0-9a-f][0-9a-f]*\) verify=.*$/\1/p' | head -1; }
nlines()       { wc -l < "$1" 2>/dev/null | tr -d ' '; }

# --- SELF-PROBES --------------------------------------------------------------
# Every predicate gets a seeded offender AND a seeded near-miss, under mktemp, never the
# real corpus. The near-miss half is the one that matters: a predicate that flags
# everything is indistinguishable from one that discriminates when the corpus is clean.
P="$WORK/probe"; mkdir -p "$P"

printf '{"a":1}\n'  > "$P/good.json"
printf '{"a":\n'    > "$P/bad.json"
is_json "$P/good.json" && ok "probe: is_json accepts well-formed JSON" \
                       || bad "probe: is_json rejected well-formed JSON"
is_json "$P/bad.json"  && bad "probe: is_json accepted truncated JSON" \
                       || ok "probe: is_json rejects truncated JSON"

printf '%s hook=x event=y]\npayload\n' "$TOKEN"      > "$P/prefixed.txt"
printf 'payload mentioning %s later\n' "$TOKEN"      > "$P/mentions.txt"
starts_with "$P/prefixed.txt" "$TOKEN" && ok "probe: starts_with accepts a token at byte 0" \
                                       || bad "probe: starts_with rejected a token at byte 0"
starts_with "$P/mentions.txt" "$TOKEN" && bad "probe: starts_with accepted a token at a non-zero offset -- a forged block that merely quotes the token would pass every arm below" \
                                       || ok "probe: starts_with rejects a token at a non-zero offset"

printf '2020-01-01T00:00:00Z abcd1234abcd1234\n' > "$P/store"
member "$P/store" abcd1234abcd1234 && ok "probe: member accepts an exact nonce" \
                                   || bad "probe: member rejected an exact nonce"
member "$P/store" abcd1234abcd123  && bad "probe: member accepted a PREFIX of a real nonce -- the trim-boundary control below would be meaningless" \
                                   || ok "probe: member rejects a prefix of a real nonce"
member "$P/store" 0000000000000000 && bad "probe: member accepted an absent nonce" \
                                   || ok "probe: member rejects an absent nonce"

printf 'PAYLOAD BODY\n'        > "$P/small.txt"
printf 'MARKER\nPAYLOAD BODY\n' > "$P/big-ok.txt"
printf 'PAYLOAD BODY EXTRA\n'   > "$P/big-no.txt"
suffix_is "$P/big-ok.txt" "$P/small.txt" && ok "probe: suffix_is accepts a byte-exact tail" \
                                         || bad "probe: suffix_is rejected a byte-exact tail"
suffix_is "$P/big-no.txt" "$P/small.txt" && bad "probe: suffix_is accepted a tail that differs -- a mangled payload would score as surviving" \
                                         || ok "probe: suffix_is rejects a tail that differs"

printf '%s hook=h event=e nonce=0123456789abcdef verify=%s]\nbody\n' "$TOKEN" "$STORE_REL" > "$P/marker.txt"
chk "probe: nonce_of extracts the nonce from a marker" "$(nonce_of "$P/marker.txt")" "0123456789abcdef"
chk "probe: nonce_of yields nothing on a body with no marker" "$(nonce_of "$P/small.txt")" ""

# --- SEEDS --------------------------------------------------------------------
# Each project gets the SAME .claude/rules/ contents, so the rules-floor payload is
# byte-identical across them and the suffix join in arm 5 is a comparison of two runs
# that differ ONLY in whether the library was reachable.
mkproj() {  # <dir>
  mkdir -p "$1/.claude/rules" "$1/.claude/skills/ai-dlc" "$1/_bmad-output" "$1/home"
  printf 'seed rule file\n' > "$1/.claude/rules/ai-dlc-resident-discipline.md"
  cat > "$1/.claude/skills/ai-dlc/SKILL.md" <<'SKILL'
### Threshold defaults

| Model context window | Yellow (first reminder) | Red (urgent reminder) |
|---|---|---|
| 200K | 80K tokens | 120K tokens |
| 1M   | 120K tokens | 200K tokens |
SKILL
  : > "$1/_bmad-output/pipeline-snapshot.md"
  printf '{"autoCompactWindow":200000}\n' > "$1/.claude/settings.json"
}

# A one-line transcript above the 200K row's yellow threshold, synthesized rather than
# committed: the sensor only needs a reading, and a blob does not belong in git.
TRANSCRIPT="$WORK/transcript.jsonl"
printf '{"type":"assistant","isSidechain":false,"message":{"model":"claude-opus-4-8","usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":89998}}}\n' \
  > "$TRANSCRIPT"

# fire_floor <proj> <outfile> -- rules-floor at SessionStart. AI_AGENT below the 2.0.64
# floor is what makes it emit at all; that payload is the text the marker must not eat.
fire_floor() {
  printf '{"hook_event_name":"SessionStart"}' \
    | CLAUDE_PROJECT_DIR="$1" AI_AGENT=claude-code_1-0-0_agent bash "$FLOOR" > "$2" 2>/dev/null
}
# fire_sensor <proj> <outfile> -- context-sensor at Stop, the non-SessionStart driver.
#
# The sidecar reset is not incidental. The sensor is deliberately idempotent -- a band
# that already fired stays silent on the next turn -- so a second fire against the same
# reading emits NOTHING, and an empty context reads exactly like a hook that reused the
# wrong nonce. Clearing the fire state is how the sensor's own fixture drives repeats;
# every fire here is asserted non-silent immediately afterwards, so a sensor that stopped
# emitting for some other reason fails loudly instead of scoring as a silent pass.
fire_sensor() {
  rm -f "$1/_bmad-output/.context-sensor-state"
  printf '{"transcript_path":"%s","session_id":"t","hook_event_name":"Stop"}' "$TRANSCRIPT" \
    | CLAUDE_CONFIG_DIR="$1/home" CLAUDE_PROJECT_DIR="$1" bash "$SENSOR" > "$2" 2>/dev/null
}
ctx_of() { jq -r '.hookSpecificOutput.additionalContext // ""' < "$1" > "$2" 2>/dev/null; }

# --- SANITY -------------------------------------------------------------------
# Both drivers must actually emit under these seeds. A hook that fell silent produces
# an empty context, and every absence-shaped arm below would pass against it at once.
A="$WORK/a"; mkproj "$A"
fire_floor "$A" "$WORK/a-floor.json"; floor_rc=$?
fire_sensor "$A" "$WORK/a-sensor.json"
ctx_of "$WORK/a-floor.json"  "$WORK/a-floor.ctx"
ctx_of "$WORK/a-sensor.json" "$WORK/a-sensor.ctx"

if [ "$(countF "$WORK/a-floor.ctx" 'AI/DLC RULES FLOOR NOT MET')" != "1" ] \
|| [ "$(countF "$WORK/a-sensor.ctx" 'YELLOW threshold')" != "1" ]; then
  bad "FIXTURE BROKEN -- a driver hook did not emit its own payload under these seeds; every assertion below would be a false pass"
  echo; echo "context-provenance: $fails assertion(s) FAILED" >&2; exit 2
fi
ok "both drivers emit their own payload (the arms below are scoring the marker, not silence)"

# --- ARM 1: the marker OPENS the context, and the payload survives it ---------
chk "the rules-floor hook exits 0" "$floor_rc" "0"
is_json "$WORK/a-floor.json"  && ok "  its output is still valid JSON" \
                              || bad "  its output is no longer valid JSON"
is_json "$WORK/a-sensor.json" && ok "  the sensor's output is still valid JSON" \
                              || bad "  the sensor's output is no longer valid JSON"

starts_with "$WORK/a-floor.ctx" "$TOKEN" \
  && ok "additionalContext OPENS with the provenance token (byte 0, not merely contains)" \
  || bad "additionalContext does not open with the provenance token"
starts_with "$WORK/a-sensor.ctx" "$TOKEN" \
  && ok "  the second hook's context opens with it too" \
  || bad "  the second hook's context does not open with the token"

# The marker's STRUCTURE, not just its token. A hook name or event that silently went
# empty still carries the token and still passes the two arms above.
if grep -qE "^\\[AI-DLC-HOOK-PROVENANCE hook=ai-dlc-rules-floor event=SessionStart nonce=[0-9a-f][0-9a-f]* verify=_bmad-output/\\.ai-dlc-context-nonce\\]" "$WORK/a-floor.ctx"; then
  ok "  the marker names its hook, its event, a hex nonce and the store to verify against"
else
  bad "  the marker is malformed -- an empty hook name or event reads as a valid marker to a token-only check"
fi
N_A="$(nonce_of "$WORK/a-floor.ctx")"
chk "  the minted nonce is 16 hex characters (the urandom path, not the degraded fallback)" "${#N_A}" "16"

# --- ARM 2: membership, with a control that was never minted ------------------
# Both halves in one arm. A membership test that only ever sees present values proves
# that it can read the file, not that it can discriminate.
STORE_A="$A/$STORE_REL"
[ -s "$STORE_A" ] && ok "the store exists and is non-empty" \
                  || bad "the store was not written -- the membership arm below cannot discriminate"
member "$STORE_A" "$N_A" && ok "  the nonce in the emitted marker IS a member of the on-disk store" \
                         || bad "  the emitted nonce is NOT a member of the store"
CTL='deadbeefdeadbeef'
chk "  the control nonce differs from the minted one (else the pair below is one assertion twice)" \
  "$([ "$CTL" != "$N_A" ] && echo differs || echo same)" "differs"
member "$STORE_A" "$CTL" && bad "  a control nonce that was never minted scored as a MEMBER -- the test accepts anything" \
                         || ok "  a control nonce that was never minted is NOT a member"

# --- ARM 3: SessionStart rotates, every other event reuses, the store appends --
B="$WORK/b"; mkproj "$B"
STORE_B="$B/$STORE_REL"

# THE STORE COUNT IS READ BETWEEN THE FIRES, NOT AT THE END. Read afterwards it is the
# SUM of every mint in the sequence, so "reuse appends nothing" and "a rotation appends"
# both resolve to the same final number and neither can fail. Capture at each step.
fire_floor  "$B" "$WORK/b1.json"; ctx_of "$WORK/b1.json" "$WORK/b1.ctx"; N1="$(nonce_of "$WORK/b1.ctx")"
L1="$(nlines "$STORE_B")"
fire_sensor "$B" "$WORK/b2.json"; ctx_of "$WORK/b2.json" "$WORK/b2.ctx"; N2="$(nonce_of "$WORK/b2.ctx")"
L2="$(nlines "$STORE_B")"
fire_floor  "$B" "$WORK/b3.json"; ctx_of "$WORK/b3.json" "$WORK/b3.ctx"; N3="$(nonce_of "$WORK/b3.ctx")"
L3="$(nlines "$STORE_B")"
fire_sensor "$B" "$WORK/b4.json"; ctx_of "$WORK/b4.json" "$WORK/b4.ctx"; N4="$(nonce_of "$WORK/b4.ctx")"
L4="$(nlines "$STORE_B")"

# Every fire must have produced a marked emission. Without this, an N that came back
# empty because the hook fell silent compares equal to another empty N and the reuse
# assertions below pass on two absences.
chk "all four fires emitted a marker (else the nonce comparisons below compare absences)" \
  "$(countF "$WORK/b1.ctx" "$TOKEN")$(countF "$WORK/b2.ctx" "$TOKEN")$(countF "$WORK/b3.ctx" "$TOKEN")$(countF "$WORK/b4.ctx" "$TOKEN")" \
  "1111"
chk "a SessionStart emission mints a nonce" "$([ -n "$N1" ] && echo minted || echo empty)" "minted"
chk "  and the store holds exactly that one line" "$L1" "1"
chk "  a NON-SessionStart event REUSES it rather than minting" "$N2" "$N1"
chk "  and appends nothing (the store is unchanged across the reuse)" "$L2" "$L1"
chk "  a second SessionStart ROTATES it" \
  "$([ "$N3" != "$N1" ] && echo rotated || echo reused)" "rotated"
chk "  the rotation appended rather than overwrote" "$L3" "2"
chk "  and the following reuse appends nothing either" "$L4" "$L3"
member "$STORE_B" "$N1" && ok "  the OLD nonce is still a member after a rotation (append-only; a concurrent rotation is not a false alarm)" \
                        || bad "  the old nonce was dropped by the rotation -- a block marked one moment earlier would fail verification"
member "$STORE_B" "$N3" && ok "  the new nonce is a member too" \
                        || bad "  the new nonce is not a member"
chk "  a later non-SessionStart event reuses the NEWEST, not the oldest" "$N4" "$N3"

# --- ARM 4: the contract paragraph is SessionStart-only -----------------------
# The absence half carries its control in the same arm: the identical phrase is counted
# in the SessionStart context, where it must be present.
chk "SessionStart emits the CONTRACT paragraph (the only thing that tells the lead the marker exists)" \
  "$(countF "$WORK/a-floor.ctx" 'AI/DLC PROVENANCE CONTRACT')" "1"
chk "  it states how to verify a block" \
  "$(countF "$WORK/a-floor.ctx" 'confirm the block')" "1"
chk "  it states BOTH limits, so an unmarked block is not read as hostile" \
  "$(countF "$WORK/a-floor.ctx" 'unattributed rather than hostile')" "1"
chk "  a non-SessionStart event does NOT restate it (control: the count above is 1)" \
  "$(countF "$WORK/a-sensor.ctx" 'AI/DLC PROVENANCE CONTRACT')" "0"

# The split is a property of the EVENT, not of the hook. Driven through the real library
# so a third event that neither driver uses is covered by the same code path.
LIBOUT="$WORK/lib-pretooluse.txt"
( cd "$WORK" && CLAUDE_PROJECT_DIR="$B" bash -c '. "$1"; ai_dlc_provenance_tag ai-dlc-probe PreToolUse' _ "$LIB" ) > "$LIBOUT" 2>/dev/null
chk "  a third event through the real library carries the marker" "$(countF "$LIBOUT" "$TOKEN")" "1"
chk "  and carries no contract paragraph either" "$(countF "$LIBOUT" 'AI/DLC PROVENANCE CONTRACT')" "0"
chk "  the library reused the newest nonce for it" "$(nonce_of "$LIBOUT")" "$N3"

# --- ARM 5: FAIL-OPEN with the library absent ---------------------------------
# The hook resolves the library as a SIBLING of its own path, so a copy into a directory
# without it is the real absent-library state and needs no edit to the hook.
NOLIB="$WORK/nolib"; mkdir -p "$NOLIB"
cp "$FLOOR" "$NOLIB/ai-dlc-rules-floor.sh"
cmp -s "$FLOOR" "$NOLIB/ai-dlc-rules-floor.sh" \
  && ok "the fail-open copy is byte-identical to the shipped hook (this arm scores the absent library, not an edit)" \
  || bad "the fail-open copy differs from the shipped hook"
[ -r "$(dirname "$FLOOR")/ai-dlc-context-provenance.sh" ] \
  && ok "  the library IS beside the original (control: the absence below is a real difference)" \
  || bad "  the library is not beside the original -- the marked runs above cannot have been marked"
[ -e "$NOLIB/ai-dlc-context-provenance.sh" ] \
  && bad "  the library leaked into the copy's directory; this arm would test nothing" \
  || ok "  the library is absent beside the copy"

C="$WORK/c"; mkproj "$C"
printf '{"hook_event_name":"SessionStart"}' \
  | CLAUDE_PROJECT_DIR="$C" AI_AGENT=claude-code_1-0-0_agent bash "$NOLIB/ai-dlc-rules-floor.sh" \
    > "$WORK/c.json" 2>/dev/null
nolib_rc=$?
ctx_of "$WORK/c.json" "$WORK/c.ctx"

chk "with the library ABSENT the hook still exits 0" "$nolib_rc" "0"
is_json "$WORK/c.json" && ok "  and still emits valid JSON" || bad "  its output is not valid JSON"
# PRESENCE-shaped, not "the exit code was fine": a hook that emitted an empty context
# also exits 0, and that is the failure fail-open is supposed to prevent.
chk "  and still carries its FULL payload" \
  "$(countF "$WORK/c.ctx" 'AI/DLC RULES FLOOR NOT MET')" "1"
chk "  including the rule filename the payload names" \
  "$(countF "$WORK/c.ctx" 'ai-dlc-resident-discipline.md')" "1"
chk "  it simply carries no marker (control: the marked run counts 1)" \
  "$(countF "$WORK/c.ctx" "$TOKEN")/$(countF "$WORK/a-floor.ctx" "$TOKEN")" "0/1"
chk "  and mints no store (control: the marked project has one)" \
  "$([ -e "$C/$STORE_REL" ] && echo present || echo absent)/$([ -e "$STORE_A" ] && echo present || echo absent)" \
  "absent/present"

# THE JOIN. The unmarked context is exactly what the payload is, so the marked context
# must END with it byte for byte. This is what "the payload survives after the marker"
# means without depending on a phrase a mangled payload would still contain -- and it
# holds whatever separator the marker is followed by.
suffix_is "$WORK/a-floor.ctx" "$WORK/c.ctx" \
  && ok "  the MARKED context ends with the unmarked one, byte for byte -- the marker only prepends" \
  || bad "  the marked context is not the unmarked payload with a prefix; the marker altered the payload"
# Control for the join: it must be able to say no. The sensor's context is a different
# payload entirely, so the same comparison against it has to fail.
suffix_is "$WORK/a-sensor.ctx" "$WORK/c.ctx" \
  && bad "  the suffix join accepted an unrelated payload -- it cannot detect a mangled one" \
  || ok "  the same join REJECTS an unrelated payload (it discriminates)"

# --- ARM 6: the store is bounded, and a trim never drops the fresh nonce ------
D="$WORK/d"; mkproj "$D"
STORE_D="$D/$STORE_REL"
awk 'BEGIN{for(i=1;i<=100;i++) printf "2020-01-01T00:00:00Z %016x\n", i}' > "$STORE_D"
OLDEST='0000000000000001'   # seeded line 1     -> must be trimmed away
KEPT='000000000000003e'     # seeded line 62    -> the newest 40 begin here (100+1 minted)
DROPPED='000000000000003d'  # seeded line 61    -> one line outside the window

# Self-probe on the pre-state: the reader must SEE the seeded values before their
# absence afterwards can mean anything.
chk "the seeded store is over the bound before the trim" "$(nlines "$STORE_D")" "100"
member "$STORE_D" "$OLDEST"  && ok "  and the oldest seeded nonce IS readable pre-trim (so its absence below is a change, not a broken reader)" \
                             || bad "  the oldest seeded nonce was not readable pre-trim; the trim assertions prove nothing"
member "$STORE_D" "$DROPPED" && ok "  as is the line just outside the eventual window" \
                             || bad "  the boundary line was not readable pre-trim"

fire_floor "$D" "$WORK/d.json"; ctx_of "$WORK/d.json" "$WORK/d.ctx"; N_D="$(nonce_of "$WORK/d.ctx")"

chk "a mint TRIMS the store to its bound" "$(nlines "$STORE_D")" "40"
member "$STORE_D" "$N_D"     && ok "  and the nonce just minted survived its own trim" \
                             || bad "  THE TRIM DROPPED THE NONCE IT JUST MINTED -- every block marked this session fails verification"
member "$STORE_D" "$OLDEST"  && bad "  the oldest seeded nonce survived a trim of a 101-line store; the bound is not being applied" \
                             || ok "  the oldest seeded nonce was dropped (the bound is real, not a no-op)"
member "$STORE_D" "$KEPT"    && ok "  the newest 40 are retained exactly (boundary line kept)" \
                             || bad "  the retained window is not the newest 40"
member "$STORE_D" "$DROPPED" && bad "  one line beyond the window was retained; the window is off by one or wider than 40" \
                             || ok "  the line one beyond the window was dropped (boundary line dropped)"

# --- MUTANTS ------------------------------------------------------------------
# Three of the arms above are ABSENCE-shaped -- no contract paragraph at a non-SessionStart
# event, no second nonce minted on a reuse, no line surviving past the bound. A seeded
# near-miss establishes that such an arm DISCRIMINATES between two inputs; only a mutant
# establishes that it discriminates at all. Each mutant is a COPY of the library, guarded
# by `cmp -s` so a sed that matched nothing cannot pass as a mutation, and each asserts a
# POSITIVE outcome: the property the shipped arm demands is OBSERVABLY GONE.
#
# The hooks are copied beside the mutated library because they resolve it as a sibling of
# their own path, so no edit to a hook is needed and none is made.
MUT_UNLANDED="$WORK/mutations-that-did-not-land"
: > "$MUT_UNLANDED"

mutlib() {  # <name> <sed program|-> -> prints the mutant hook DIRECTORY
  local name="$1" prog="$2" md="$WORK/mut-$1"
  mkdir -p "$md"
  cp "$FLOOR" "$SENSOR" "$md/"
  if [ "$prog" = "-" ]; then
    cp "$LIB" "$md/ai-dlc-context-provenance.sh"
  else
    sed "$prog" "$LIB" > "$md/ai-dlc-context-provenance.sh"
    if cmp -s "$LIB" "$md/ai-dlc-context-provenance.sh"; then
      printf '%s\n' "$name" >> "$MUT_UNLANDED"; rm -rf "$md"; return 1
    fi
  fi
  printf '%s' "$md"
}
# mfire_floor / mfire_sensor -- the same two drivers, taken from a mutant directory.
mfire_floor()  { printf '{"hook_event_name":"SessionStart"}' \
                   | CLAUDE_PROJECT_DIR="$2" AI_AGENT=claude-code_1-0-0_agent \
                     bash "$1/ai-dlc-rules-floor.sh" > "$3" 2>/dev/null; }
mfire_sensor() { rm -f "$2/_bmad-output/.context-sensor-state"
                 printf '{"transcript_path":"%s","session_id":"t","hook_event_name":"Stop"}' "$TRANSCRIPT" \
                   | CLAUDE_CONFIG_DIR="$2/home" CLAUDE_PROJECT_DIR="$2" \
                     bash "$1/ai-dlc-context-sensor.sh" > "$3" 2>/dev/null; }

# CONTROL -- an UNMUTATED library, copied and driven exactly like the mutants. A copy that
# dies of its own accord emits nothing, and "no contract paragraph" is what silence looks
# like, so every mutant below could be scoring the copy mechanism instead of the mutation.
# It carries a POSITIVE conjunct: the marker must be THERE, not merely undisturbed.
if MD="$(mutlib control -)"; then
  MC="$WORK/mp-control"; mkproj "$MC"
  mfire_floor  "$MD" "$MC" "$WORK/mc1.json"; ctx_of "$WORK/mc1.json" "$WORK/mc1.ctx"
  mfire_sensor "$MD" "$MC" "$WORK/mc2.json"; ctx_of "$WORK/mc2.json" "$WORK/mc2.ctx"
  if [ "$(countF "$WORK/mc1.ctx" "$TOKEN")" = "1" ] \
  && [ "$(countF "$WORK/mc1.ctx" 'AI/DLC PROVENANCE CONTRACT')" = "1" ] \
  && [ "$(countF "$WORK/mc2.ctx" 'AI/DLC PROVENANCE CONTRACT')" = "0" ] \
  && [ "$(nonce_of "$WORK/mc2.ctx")" = "$(nonce_of "$WORK/mc1.ctx")" ]; then
    ok "CONTROL: an unmutated library copy still marks, still states the contract once, and still reuses (the mutants below score the mutation, not the copy)"
  else
    bad "FIXTURE BROKEN -- an unmutated library copy did not reproduce the shipped behaviour; every mutant below is a false kill"
  fi
fi

# MUTANT 1 -- the reuse branch can never be taken, so EVERY event mints. Kills arm 3's
# "a non-SessionStart event REUSES it" and its store-unchanged partner, and nothing else:
# the contract branch and the trim are untouched.
if MD="$(mutlib m1 's@if \[ "$event" != "SessionStart" \] && \[ -r "$file" \]; then@if false; then@')"; then
  M1P="$WORK/mp-m1"; mkproj "$M1P"
  mfire_floor  "$MD" "$M1P" "$WORK/m1a.json"; ctx_of "$WORK/m1a.json" "$WORK/m1a.ctx"
  mfire_sensor "$MD" "$M1P" "$WORK/m1b.json"; ctx_of "$WORK/m1b.json" "$WORK/m1b.ctx"
  if [ "$(countF "$WORK/m1b.ctx" "$TOKEN")" = "1" ] \
  && [ "$(nonce_of "$WORK/m1b.ctx")" != "$(nonce_of "$WORK/m1a.ctx")" ] \
  && [ "$(nlines "$M1P/$STORE_REL")" = "2" ] \
  && [ "$(countF "$WORK/m1b.ctx" 'AI/DLC PROVENANCE CONTRACT')" = "0" ]; then
    ok "MUTANT 1: with the reuse branch unreachable a non-SessionStart event MINTS -- the reuse arm is load-bearing, and the contract arm is unmoved by it"
  else
    bad "MUTANT 1 did not isolate the reuse branch (either the nonce was still reused, or the contract arm moved with it)"
  fi
fi

# MUTANT 2 -- the contract branch is always taken, so every event restates it. Kills arm
# 4's absence half. The nonce must still be REUSED, so arm 3 is unmoved.
if MD="$(mutlib m2 's@if \[ "$event" = "SessionStart" \]; then@if true; then@')"; then
  M2P="$WORK/mp-m2"; mkproj "$M2P"
  mfire_floor  "$MD" "$M2P" "$WORK/m2a.json"; ctx_of "$WORK/m2a.json" "$WORK/m2a.ctx"
  mfire_sensor "$MD" "$M2P" "$WORK/m2b.json"; ctx_of "$WORK/m2b.json" "$WORK/m2b.ctx"
  if [ "$(countF "$WORK/m2b.ctx" 'AI/DLC PROVENANCE CONTRACT')" = "1" ] \
  && [ "$(nonce_of "$WORK/m2b.ctx")" = "$(nonce_of "$WORK/m2a.ctx")" ]; then
    ok "MUTANT 2: with the contract branch always taken a Stop event restates it -- the SessionStart-only arm is load-bearing, and the reuse arm is unmoved by it"
  else
    bad "MUTANT 2 did not isolate the contract branch (either the paragraph stayed absent, or the nonce stopped being reused with it)"
  fi
fi

# MUTANT 3 -- the trim keeps everything. Kills arm 6's bound and its "oldest was dropped"
# control. The mint itself is untouched, so the fresh nonce is still a member.
if MD="$(mutlib m3 's@tail -n 40 "$file"@tail -n 100000 "$file"@')"; then
  M3P="$WORK/mp-m3"; mkproj "$M3P"
  awk 'BEGIN{for(i=1;i<=100;i++) printf "2020-01-01T00:00:00Z %016x\n", i}' > "$M3P/$STORE_REL"
  mfire_floor "$MD" "$M3P" "$WORK/m3.json"; ctx_of "$WORK/m3.json" "$WORK/m3.ctx"
  if [ "$(nlines "$M3P/$STORE_REL")" = "101" ] \
  && member "$M3P/$STORE_REL" "$OLDEST" \
  && member "$M3P/$STORE_REL" "$(nonce_of "$WORK/m3.ctx")"; then
    ok "MUTANT 3: with the bound widened the store keeps all 101 lines and the oldest survives -- arm 6's bound and its drop-control are both load-bearing"
  else
    bad "MUTANT 3 did not isolate the trim (the store was still bounded, or the fresh nonce stopped being recorded with it)"
  fi
fi

# CONTROL: every mutation landed. Each mutant sits behind `if MD="$(mutlib ...)"`, so a sed
# that matched nothing takes the false branch and its assertion vanishes with no
# diagnostic -- a fixture one arm shorter, still reporting PASS. mutlib() records to a FILE
# because this is the only scope `$( )` cannot swallow.
if [ ! -s "$MUT_UNLANDED" ]; then
  ok "control: every mutation landed (a sed matching nothing cannot skip its assertion in silence)"
else
  bad "mutation(s) matched nothing and their assertions were SKIPPED, not failed: $(tr '\n' ' ' < "$MUT_UNLANDED")-- each leaves a branch scoring as load-bearing when nothing tested it"
fi

# --- CWD INVARIANCE -----------------------------------------------------------
# A fixture that is green only from the repo root may be asserting nothing, because that
# is a cwd where its subject happens to resolve. This asserts the property in its own
# arm rather than inheriting it from how the suite dispatches.
case "$LIB" in /*) ok "the library resolved to an ABSOLUTE path (cwd cannot change what was measured)" ;;
  *) bad "the library resolved to a relative path -- every run above depended on the caller's cwd" ;; esac
( cd / && [ -r "$LIB" ] && [ -r "$FLOOR" ] && [ -r "$SENSOR" ] ) \
  && ok "  and every resolved path is still readable from an unrelated cwd" \
  || bad "  a resolved path is unreadable from another cwd; this fixture answers differently depending on where it is run"

echo
if [ "$fails" -eq 0 ]; then echo "context-provenance: PASS"; exit 0; fi
echo "context-provenance: $fails assertion(s) FAILED" >&2
exit 1
