#!/usr/bin/env bash
# derivation-capture/run.sh — drive the REAL ai-dlc-derivation-capture.sh hook with
# synthesized PostToolUse JSON and prove a ```derived block is witnessed at the moment
# it is written.
#
# THE DEFECT THIS EXISTS TO CATCH. `validate-artifact-derivations.sh` runs at the gate,
# so a fabricated output that happens to be RIGHT is indistinguishable from an observed
# one, and a fabricated output that is WRONG is caught a gate late — after the passes
# that read the number have already reasoned from it. This hook re-runs the command
# inside the tool call that wrote it. Reported by the reference consumer at sprint 304
# as PC-S304-DERIVED-BLOCK-VERIFIES-REPRODUCIBILITY-NOT-PROVENANCE.
#
# THE ARM THAT DECIDES THE DESIGN is A5/A6, the pair-grain pair. Measured on that same
# consumer's active sprint, 12 of the 40 artifact files carrying a fence already fail
# whole-file validation, so a hook that submitted the whole file would refuse an
# unrelated edit in 30% of live files and be turned off within a sprint. A5 and A6 edit
# two pairs of ONE block and require opposite verdicts; a mask that works at block grain
# passes every other arm here and fails those two.
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set in settings.json into
# this process. Scrub them so the hook and the validator are tested against their own
# defaults, not the tester's env.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required to build payloads" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

OUT="$WORK/stdout"; ERR="$WORK/stderr"
# fire <json> -> sets RC, writes the hook's streams to $OUT/$ERR
fire() {
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$HOOK" >"$OUT" 2>"$ERR"
  RC=$?
}
edit_json()      { jq -nc --arg f "$1" --arg s "$2" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"IRRELEVANT",new_string:$s}}'; }
multiedit_json() { jq -nc --arg f "$1" --arg s "$2" '{tool_name:"MultiEdit",tool_input:{file_path:$f,edits:[{old_string:"IRRELEVANT",new_string:$s}]}}'; }
write_json()     { jq -nc --arg f "$1" --arg c "$(cat "$1")" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}'; }
other_json()     { jq -nc --arg f "$1" '{tool_name:"Read",tool_input:{file_path:$f}}'; }

# The four pairs as an author would have written them.
PAIR_STALE_A="$(printf '```derived\n$ grep -c stale VERSION\n99\n```')"
PAIR_FRESH_B="$(printf '```derived\n$ grep -c 0 VERSION\n1\n```')"
PAIR_FRESH_C="$(printf '$ cat VERSION\n0.0.0')"
PAIR_STALE_C="$(printf '$ grep -c neverpresent VERSION\n7')"

echo "derivation-capture:"

# --- A0: SANITY — the hook and the validator are present and runnable ---------
[ -x "$HOOK" ] || bad "hook not executable: $HOOK"
[ -r "$VALIDATOR" ] || bad "validator not readable: $VALIDATOR"

# --- A1: CONTROL — the seed really is half stale, and all four pairs are seen --
# Without this, every silent arm below would read the same whether the seed
# discriminated or the validator never saw a pair.
CTL="$( ( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" "$ART" ) 2>&1 )"
CTL_RC=$?
if [ "$CTL_RC" = 1 ] && grep -q '2 stale or unrunnable derivation(s) of 4 checked' <<<"$CTL"; then
  ok "control: the seeded artifact is 2-of-4 stale under the real validator"
else
  bad "control: expected rc 1 and '2 stale ... of 4 checked', got rc $CTL_RC — the seed no longer discriminates, so every arm below is vacuous"
fi

# --- A1b: CONTROL — the indented artifact is 1-of-2 stale under the real validator
# The validator half of PC-S308-VALIDATE-ARTIFACT-DERIVATIONS-INDENTED-FENCE-BLIND-SPOT.
# A validator matching the opener at column 0 reports "0 derivation(s) in 0 block(s)" here
# with exit 0, and then every indented arm below is a statement about nothing.
ICTL="$( ( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" "$IND_ART" ) 2>&1 )"
ICTL_RC=$?
if [ "$ICTL_RC" = 1 ] && grep -q '1 stale or unrunnable derivation(s) of 2 checked' <<<"$ICTL"; then
  ok "control: the indented artifact is 1-of-2 stale under the real validator"
else
  bad "control: expected rc 1 and '1 stale ... of 2 checked' on the indented artifact, got rc $ICTL_RC — the validator cannot see an indented fence, so the indented arms below are vacuous"
fi

# --- A2: an edit that wrote the STALE block → BLOCK ---------------------------
fire "$(edit_json "$ART" "$PAIR_STALE_A")"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "edit writing a stale pair → exit 2"
else
  bad "edit writing a stale pair exited $RC (expected 2) — the capture is not firing"
fi

# --- A2b: the message names the REAL artifact, not the mask -------------------
if grep -q '_bmad-output/planning-artifacts/s1/stories-repair-p1.md:8' "$ERR"; then
  ok "the block message cites the real path and the real line"
else
  bad "the message does not cite stories-repair-p1.md:8 — a report pointing at a temp file sends the author nowhere"
fi

# --- A2c: it blocks on stderr and prints NOTHING on stdout --------------------
# A PostToolUse hook's stdout is transcript noise on every passing edit; the verdict
# belongs on stderr, which is what exit 2 feeds back to the author.
[ ! -s "$OUT" ] && ok "nothing on stdout" \
  || bad "the hook wrote $(wc -c <"$OUT") bytes to stdout — every passing edit would carry it too"

# --- A3: an edit that wrote only the FRESH block → SILENT ---------------------
fire "$(edit_json "$ART" "$PAIR_FRESH_B")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "edit writing a reproducing pair → exit 0, silent"
else
  bad "edit writing a reproducing pair exited $RC with $(wc -c <"$ERR") bytes of stderr — a check that flags everything discriminates nothing"
fi

# --- A4: an edit that touched only prose → SILENT -----------------------------
# The file still carries two stale pairs. Reporting them here is the wedge this
# fixture's header measures: it would refuse an edit that wrote no derivation at all.
fire "$(edit_json "$ART" "One line carries the version.")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "edit touching only prose → exit 0, though the file holds two stale pairs"
else
  bad "an edit that wrote no derivation exited $RC — this is the wedge that gets the hook turned off"
fi

# --- A5: the FRESH pair of the two-pair block → SILENT ------------------------
fire "$(edit_json "$ART" "$PAIR_FRESH_C")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "pair grain: the reproducing pair of a mixed block → exit 0"
else
  bad "the reproducing pair of a mixed block exited $RC — the mask is working at BLOCK grain, so its stale sibling is dragging it down"
fi

# --- A6: the STALE pair of the SAME block → BLOCK -----------------------------
fire "$(edit_json "$ART" "$PAIR_STALE_C")"
if [ "$RC" = 2 ] && grep -q 'stories-repair-p1.md:28' "$ERR"; then
  ok "pair grain: the stale pair of the same block → exit 2 at its own line"
else
  bad "the stale pair of a mixed block exited $RC (expected 2 citing :28) — the mask is dropping pairs it should submit"
fi

# --- A7: an edit that rewrote only an OUTPUT line → BLOCK ---------------------
# The fabrication shape is not always a whole new block. Retyping a recorded output
# from expectation, leaving the command line untouched, is the same defect, and a mask
# keyed on the `$ ` line alone would miss exactly it.
fire "$(edit_json "$ART" "99")"
if [ "$RC" = 2 ]; then
  ok "edit rewriting only a recorded output line → exit 2"
else
  bad "an output-only rewrite exited $RC (expected 2) — the mask is keyed on the command line alone"
fi

# --- A8: a whole-file Write → BLOCK (every pair is in scope) ------------------
fire "$(write_json "$ART")"
if [ "$RC" = 2 ]; then
  ok "Write of the whole file → exit 2 (a Write authors every pair in it)"
else
  bad "a whole-file Write exited $RC (expected 2) — .tool_input.content is not being read"
fi

# --- A9: MultiEdit carries its payload in edits[] -----------------------------
fire "$(multiedit_json "$ART" "$PAIR_STALE_A")"
if [ "$RC" = 2 ]; then
  ok "MultiEdit writing a stale pair → exit 2"
else
  bad "MultiEdit exited $RC (expected 2) — edits[].new_string is not being read, so every MultiEdit is unwitnessed"
fi

# --- A10: a file with no fence at all → SILENT --------------------------------
fire "$(edit_json "$PROSE_ART" "42 things, asserted and underived.")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "a file carrying no fence → exit 0"
else
  bad "an unfenced file exited $RC — the cheap reject is not rejecting"
fi

# --- A11: a non-Write/Edit tool → SILENT --------------------------------------
fire "$(other_json "$ART")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "a Read payload → exit 0"
else
  bad "a Read payload exited $RC — the hook is judging tools that wrote nothing"
fi

# --- A12: a non-markdown path → SILENT ----------------------------------------
cp "$ART" "$CONSUMER/notes.txt"
fire "$(edit_json "$CONSUMER/notes.txt" "$PAIR_STALE_A")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "a non-markdown path → exit 0"
else
  bad "a .txt path exited $RC — the artifact grammar is markdown"
fi

# --- A13: FAIL OPEN — validator absent (a consumer that has not pulled it) ----
# A core hook ships ahead of its subject: it lands in one pull and the validator it
# calls may already be there or may not. Blocking a write because a script is missing
# would make the pipeline's ability to save a file depend on the pull order.
mv "$VALIDATOR" "$WORK/validator.bak"
fire "$(edit_json "$ART" "$PAIR_STALE_A")"
mv "$WORK/validator.bak" "$VALIDATOR"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "validator absent → exit 0, silent (fails open)"
else
  bad "with the validator absent the hook exited $RC — an infrastructure state must never fail a tool call"
fi

# --- A15: the validator refusing to START is not a verdict --------------------
# Exit 2 out of validate-artifact-derivations.sh is usage or an unresolvable root. The
# hook reads only exit 1 as a statement about the text; anything else is infrastructure
# and must not fail the author's write.
cp "$VALIDATOR" "$WORK/validator.bak"
printf '#!/bin/sh\nexit 2\n' > "$VALIDATOR"
fire "$(edit_json "$ART" "$PAIR_STALE_A")"
cp "$WORK/validator.bak" "$VALIDATOR"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "validator exiting 2 → exit 0, silent (only rc 1 is a verdict)"
else
  bad "a validator that refused to start exited the hook $RC — usage and root-resolution failures would block writes"
fi

# --- A16: a REFUSED command blocks at write time too --------------------------
# The validator refuses a command it cannot run read-only, and that refusal is a FAIL,
# not a skip. It has to reach the author at the moment the fence is written rather than
# at the gate, and the headline must not claim the block "does not reproduce" -- it was
# never run.
REFUSED_PAIR="$(printf '```derived\n$ python3 -c "print(2)"\n2\n```')"
printf '\n%s\n' "$REFUSED_PAIR" >> "$ART"
fire "$(edit_json "$ART" "$REFUSED_PAIR")"
if [ "$RC" = 2 ] && grep -q 'ALLOWLIST' "$ERR"; then
  ok "a command the allowlist refuses → exit 2, named as a refusal"
else
  bad "a refused command exited $RC without naming ALLOWLIST — a refusal that reaches nobody is a skip"
fi

# --- A17: an edit to PROSE in a file whose only fences are INDENTED → SILENT --
# The indented artifact's block A is stale. A hook whose mask cannot see an indented opener
# passes that block through UNMASKED, so the stale pair is submitted on every edit to the
# file and an author who touched only prose is refused -- the wedge this fixture's header
# measures, arriving through the fence form the mask could not spell.
IND_PAIR_STALE="$(printf '  ```derived\n  $ grep -c neverpresent VERSION\n  7\n  ```')"
IND_PAIR_FRESH="$(printf '  ```derived\n  $ cat VERSION\n  0.0.0\n  ```')"
fire "$(edit_json "$IND_ART" "- Finding B, the same shape, fresh.")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "indented file, edit touching only prose → exit 0, though its block A is stale"
else
  bad "a prose-only edit to the indented file exited $RC — the mask is passing an indented block through unmasked"
fi

# --- A18: an edit that wrote the INDENTED stale pair → BLOCK at its real line ---
# Both cheap rejects sit in front of the validator: the fence grep that scopes the hook to
# files carrying a fence, and the `$ ` grep that skips a mask holding no command. Either one
# matching at column 0 only exits 0 here, and the indented stale pair is written unwitnessed.
fire "$(edit_json "$IND_ART" "$IND_PAIR_STALE")"
if [ "$RC" = 2 ] && grep -q 'indented-repair-p1.md:6' "$ERR"; then
  ok "indented stale pair written → exit 2 citing indented-repair-p1.md:6"
else
  bad "an edit writing the indented stale pair exited $RC (expected 2 citing :6) — an indented fence is not witnessed"
fi

# --- A19: an edit that wrote the INDENTED fresh pair → SILENT ------------------
# The near-miss beside A18: same file, same shape, the reproducing block. A hook that refused
# every indented fence would pass A18 and fail this.
fire "$(edit_json "$IND_ART" "$IND_PAIR_FRESH")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "indented fresh pair written → exit 0, silent"
else
  bad "an edit writing the indented FRESH pair exited $RC — the hook is refusing indented fences rather than reading them"
fi

# --- A1c: CONTROL — the prose-opener artifact is 1-of-1 stale under the real validator
# A validator whose opener accepts any text after `derived` opens a phantom block on line 4,
# closes it on the real opener at line 6, and reports 0 checked with exit 0.
OCTL="$( ( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" "$OPN_ART" ) 2>&1 )"
OCTL_RC=$?
if [ "$OCTL_RC" = 1 ] && grep -q '1 stale or unrunnable derivation(s) of 1 checked' <<<"$OCTL"; then
  ok "control: the prose-opener artifact is 1-of-1 stale under the real validator"
else
  bad "control: expected rc 1 and '1 stale ... of 1 checked' on the prose-opener artifact, got rc $OCTL_RC — the prose line is swallowing the real block"
fi

# --- A20: an edit to PROSE in a file whose real block sits below a prose line that begins
# with the fence token → SILENT. The near-miss beside A21: same file, one property apart. It
# holds under a mask that misreads the prose line too, and moves only when every pair is
# submitted regardless of the payload (the file-grain mutant).
fire "$(edit_json "$OPN_ART" "A sentence that wraps so its continuation begins with the fence token, and the block")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "prose-opener file, edit touching only prose → exit 0"
else
  bad "a prose-only edit to the prose-opener file exited $RC — a pair this edit did not write was submitted"
fi

# --- A21: an edit that wrote that file's real stale pair → BLOCK at its real line -----
# A mask that reads the prose line as an opener blanks the REAL opener as that phantom block's
# closer, so the real pairs reach the validator outside any fence and are never run: the pair
# is written unwitnessed and the hook exits 0. Silent, in the direction that matters.
fire "$(edit_json "$OPN_ART" "$PAIR_STALE_C")"
if [ "$RC" = 2 ] && grep -q 'prose-opener-p1.md:7' "$ERR"; then
  ok "prose-opener file, stale pair written → exit 2 citing prose-opener-p1.md:7"
else
  bad "an edit writing the prose-opener file's stale pair exited $RC (expected 2 citing :7)"
fi

# --- A14: the artifact is not modified by the hook ----------------------------
# The rejected design overwrote the recorded output with the captured one. It must
# stay rejected: a wrong COMMAND would then be silently paired with its own real
# output and read as machine-verified forever.
fire "$(edit_json "$ART" "$PAIR_STALE_A")"
if grep -q '^99$' "$ART"; then
  ok "the hook does not rewrite the artifact — the author reconciles, the hook does not launder"
else
  bad "the artifact's recorded output changed under the hook — overwrite is the rejected design"
fi

if [ "$fails" -gt 0 ]; then
  printf '  %s assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
