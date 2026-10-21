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
NOROOT_DIRS=""
# shellcheck disable=SC2086 # NOROOT_DIRS is a space-joined list of mktemp paths, split on purpose
trap 'rm -rf "$WORK" $NOROOT_DIRS' EXIT
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
if [ "$ICTL_RC" = 1 ] && grep -q '1 stale or unrunnable derivation(s) of 3 checked' <<<"$ICTL"; then
  ok "control: the indented artifact is 1-of-3 stale under the real validator"
else
  bad "control: expected rc 1 and '1 stale ... of 3 checked' on the indented artifact, got rc $ICTL_RC — the validator cannot see an indented fence, so the indented arms below are vacuous"
fi

# EVERY SILENT ARM ON A SEEDED PAIR FIRST PROVES ITS PAYLOAD IS IN THE ARTIFACT. A silent arm
# asserts exit 0 and no stderr, which a payload found in NO artifact also produces -- so a
# seed-versus-payload drift on a fresh block would leave the arm green for the wrong reason.
# The conjunct is the `$ ` line of the payload, whole and exact, present in the file.
seeded() { # $1 artifact  $2 payload -> 0 when the payload's command line is a line of the file
  grep -qxF "$(printf '%s\n' "$2" | grep -m1 '\$ ')" "$1"
}

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

# --- A23-A26: EXIT 2 HAS TWO MEANINGS, AND THE VALIDATOR'S OWN LINES SEPARATE THEM ----------
# The validator exits 2 both when it cannot START and when a derivation this edit wrote did not
# run to completion (an `UNRUN:` line, then a `REFUSED:` summary). The second withholds every
# verdict in the file, STALE included, so a hook that reads every 2 as infrastructure lets one
# unrunnable block hide a real mismatch in the same write. Measured at the prior tip: a Write of
# one stale block beside one `"$FILE_ZZ_UNSET"` block gave hook rc=0 with nothing shown.
unset FILE_ZZ_UNSET
[ -z "${FILE_ZZ_UNSET+x}" ] && ok "control: FILE_ZZ_UNSET is unset, so A23's second block names an unbound variable" \
  || bad "control: FILE_ZZ_UNSET is set, so A23 is not about an unbound variable"
CAP_DIR="$CONSUMER/_bmad-output/planning-artifacts/s1"

# A23: the adversary's two-block Write -- one stale block, one bare unbound `$VAR` block. The
# unbound variable expands empty (the validator's eval runs with `set -u` off), `grep` on an
# empty operand prints nothing, and both blocks are STALE: exit 2 with the stale finding shown.
printf '# s\n\n```derived\n$ grep -c 0 VERSION\n9\n```\n\n```derived\n$ grep -c 0 "$FILE_ZZ_UNSET"\n1\n```\n' > "$CAP_DIR/unbound-write.md"
fire "$(write_json "$CAP_DIR/unbound-write.md")"
if [ "$RC" = 2 ] && grep -q 'unbound-write.md:4 records an output' "$ERR" && ! grep -q '^UNRUN' "$ERR"; then
  ok "a Write of a stale block beside a bare unbound \$VAR block → exit 2, the stale finding shown"
else
  bad "the stale-plus-unbound Write exited $RC without naming unbound-write.md:4 as stale — one block that aborts the eval is hiding a real STALE"
fi

# A24: a Write whose ONLY derivation is unrunnable -- an arithmetic error aborts the subshell
# whatever `set -u` says. The validator says UNRUN and REFUSED at exit 2; that is a statement
# about the text this edit wrote, so it reaches the author.
printf '# s\n\n```derived\n$ grep -c "0$[1/0]" VERSION\n1\n```\n' > "$CAP_DIR/unrun-only.md"
fire "$(write_json "$CAP_DIR/unrun-only.md")"
if [ "$RC" = 2 ] && grep -q '^UNRUN: _bmad-output/planning-artifacts/s1/unrun-only.md:4 ' "$ERR" && grep -q '^REFUSED: 1 derivation' "$ERR"; then
  ok "an UNRUN-only Write → exit 2, the UNRUN line shown at the real path"
else
  bad "an UNRUN-only Write exited $RC without surfacing its UNRUN line — a derivation that never ran was written unwitnessed"
fi

# A25: an UNRUN block BESIDE a stale block. The validator withholds its verdict, but it still
# prints the STALE it reached; the hook shows both, because a stale block this edit wrote is
# the author's to fix whether or not a sibling ran.
printf '# s\n\n```derived\n$ grep -c 0 VERSION\n9\n```\n\n```derived\n$ grep -c "0$[1/0]" VERSION\n1\n```\n' > "$CAP_DIR/unrun-beside-stale.md"
fire "$(write_json "$CAP_DIR/unrun-beside-stale.md")"
if [ "$RC" = 2 ] && grep -q 'unrun-beside-stale.md:4 records an output' "$ERR" && grep -q '^UNRUN: .*unrun-beside-stale.md:9 ' "$ERR"; then
  ok "an UNRUN block beside a stale block → exit 2, both the STALE and the UNRUN shown"
else
  bad "an UNRUN block beside a stale one exited $RC without showing both — the unrunnable block hid the stale one"
fi

# A26: THE NEAR-MISS. An exit 2 that carries no UNRUN or REFUSED line is the validator refusing
# to start, and it stays exit 0. The refusal text is the REAL validator's, captured by running it
# where no root resolves (a bare temp dir, no marker, no project variables), then replayed by a
# stub -- the hook always hands the validator a root, so the real refusal cannot be reached
# through it. The capture carries its own control: rc 2 and the root-resolution ERROR line.
# THE CAPTURE DIR IS TRIED UNDER /tmp FIRST, because `$WORK` sits under `$TMPDIR` and an
# ancestor of that may carry a marker the resolver accepts -- measured on the operator's
# machine, a `.claude/` directory two levels above `$TMPDIR`, so the copy resolved a root and
# exited 1. The first candidate whose run is a real root refusal is used.
NR_RC=""; NR_TXT="$WORK/refusal-root.txt"
for NR_BASE in /tmp "$WORK"; do
  NOROOT="$(mktemp -d "$NR_BASE/derivcap-noroot.XXXXXX" 2>/dev/null)" || continue
  NOROOT_DIRS="${NOROOT_DIRS:-} $NOROOT"
  cp "$VALIDATOR" "$NOROOT/v.sh"
  ( cd "$NOROOT" && env -u CLAUDE_PROJECT_DIR -u AI_DLC_PROJECT_ROOT bash "$NOROOT/v.sh" "$ART" ) > "$NR_TXT" 2>&1
  NR_RC=$?
  [ "$NR_RC" = 2 ] && grep -q '^ERROR: cannot resolve the project root' "$NR_TXT" && break
done
replay() { # $1 captured text  $2 status -> installs a stub validator that replays them
  { printf '#!/bin/sh\ncat <<'"'"'REFUSAL'"'"' >&2\n'; cat "$1"; printf 'REFUSAL\nexit %s\n' "$2"; } > "$VALIDATOR"
}
cp "$VALIDATOR" "$WORK/validator.bak"
replay "$NR_TXT" "$NR_RC"
fire "$(edit_json "$ART" "$PAIR_STALE_A")"
cp "$WORK/validator.bak" "$VALIDATOR"
if [ "$NR_RC" = 2 ] && grep -q '^ERROR: cannot resolve the project root' "$NR_TXT" \
   && [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "an unresolvable-root refusal (the real validator's text, exit 2) → exit 0, silent"
else
  bad "an unresolvable-root refusal: capture rc $NR_RC, hook rc $RC with $(wc -c <"$ERR") bytes — an infrastructure refusal must not fail the write, or no candidate dir gave a real root refusal"
fi

# A27: the second infrastructure refusal, bad usage -- the real validator run with no operand,
# which exits 2 on every machine. Same replay, same verdict: exit 0, silent.
( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" ) > "$WORK/refusal-usage.txt" 2>&1
NU_RC=$?
replay "$WORK/refusal-usage.txt" "$NU_RC"
fire "$(edit_json "$ART" "$PAIR_STALE_A")"
cp "$WORK/validator.bak" "$VALIDATOR"
if [ "$NU_RC" = 2 ] && grep -q '^usage: ' "$WORK/refusal-usage.txt" && [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
  ok "a usage refusal (the real validator's text, exit 2) → exit 0, silent"
else
  bad "a usage refusal: capture rc $NU_RC, hook rc $RC with $(wc -c <"$ERR") bytes — an infrastructure refusal must not fail the write"
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
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$IND_ART" "$IND_PAIR_FRESH"; then
  ok "indented fresh pair written → exit 0, silent (payload seeded in the artifact)"
else
  bad "an edit writing the indented FRESH pair exited $RC, or its payload is not in the artifact — the hook is refusing indented fences, or the arm is passing on a pair nothing submitted"
fi

# --- A22: an edit rewriting ONLY the command line of the pair whose output is a deeper `$ `
# line → SILENT. The hook-side half of "shed exactly the fence indent", and the payload is
# the command line ALONE on purpose: a mask shedding all leading blanks reads the eight-space
# `$ x` as a second command and therefore a second, UNTOUCHED pair, blanks it, and submits the
# real command with no recorded output -- STALE, and a reproducing block is refused. With the
# whole pair in the payload both masks keep both lines and the mutation is invisible.
IND_PAIR_DEEP="$(printf '  $ printf '"'"'      $ x\\n'"'"'')"
fire "$(edit_json "$IND_ART" "$IND_PAIR_DEEP")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$IND_ART" "$IND_PAIR_DEEP"; then
  ok "indented pair whose output is a deeper \$ line → exit 0, silent (payload seeded)"
else
  bad "the deeper-\$-output pair exited $RC (expected 0), or its payload is not in the artifact — the mask is shedding all leading blanks, so a deeper \$ line reads as a command"
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
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && grep -qxF "A sentence that wraps so its continuation begins with the fence token, and the block" "$OPN_ART"; then
  ok "prose-opener file, edit touching only prose → exit 0 (payload seeded in the artifact)"
else
  bad "a prose-only edit to the prose-opener file exited $RC, or its payload is not in the artifact — a pair this edit did not write was submitted, or the arm drifted from its seed"
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

# --- A28-A33: THE SECTION-COPY EXEMPTION (BL-372) -----------------------------------------
# A section remediator edits `shards/prd-repair-p1/sections/<i>.md`, a copy, while prd.md stays at
# its split bytes until the join assembles it. A fence in the copy that derives from prd.md
# describes the ASSEMBLED document and cannot reproduce yet, so that pair alone is exempt. Every
# arm below writes the SAME self-referencing stale pair unless it says otherwise, so the only
# property that moves between A28 and A30-A33 is WHERE it is written.
SELF_REL="_bmad-output/planning-artifacts/s1/prd.md"
PAIR_SELF="$(printf '```derived\n$ grep -c scope %s\n97\n```' "$SELF_REL")"
PAIR_GUESS="$(printf '```derived\n$ grep -c 0 VERSION\n9\n```')"
PAIR_LONGER="$(printf '```derived\n$ grep -c scope %s.orig\n97\n```' "$SELF_REL")"
sec_write() { # <file> <pair> -> append the pair to the file, then fire an Edit that wrote it
  mkdir -p "$(dirname "$1")"; printf '\n%s\n' "$2" >> "$1"
  fire "$(edit_json "$1" "$2")"
}
echo "  (section split made by $SPLIT_BY)"

# CONTROL: the pair really is stale, so every exit 0 below is the exemption and not a match.
printf '# c\n\n%s\n' "$PAIR_SELF" > "$WORK/self-ctl.md"
SCTL="$( ( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" "$WORK/self-ctl.md" ) 2>&1 )"
SCTL_RC=$?
if [ "$SCTL_RC" = 1 ] && grep -q '1 stale or unrunnable derivation(s) of 1 checked' <<<"$SCTL" \
   && [ -f "$REPDIR/sections/.manifest" ] && [ -f "$REPDIR/sections/2.md" ]; then
  ok "control: the self-referencing pair is stale under the real validator, and the split carries sections/.manifest"
else
  bad "control: expected the self-referencing pair stale (rc 1) and a split manifest, got rc $SCTL_RC — every section arm below is vacuous"
fi

# A28: THE EXEMPTION. The self-referencing pair written into a listed section copy -> silent.
sec_write "$REPDIR/sections/2.md" "$PAIR_SELF"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$REPDIR/sections/2.md" "$PAIR_SELF"; then
  ok "section copy, a pair deriving from the split document -> exit 0 (exempt until assembly)"
else
  bad "a self-referencing pair in a section copy exited $RC — the section-sharded repair cannot record a derivation of its own document"
fi

# A29: a pair in the SAME copy that does not name the document is witnessed as anywhere else.
sec_write "$REPDIR/sections/2.md" "$PAIR_GUESS"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "section copy, a guessed pair that does not name the document -> exit 2"
else
  bad "a non-self-referencing guess in a section copy exited $RC (expected 2) — the exemption covers every command in a section copy"
fi

# A30: the REAL document is never exempt.
sec_write "$SPLIT_DOC" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "the split document itself, the same pair -> exit 2"
else
  bad "the same pair written into the real document exited $RC (expected 2) — the exemption reaches the document"
fi

# A31: the remediator's PART beside sections/ carries the same exemption for the same pair. The
# part's derivation is copied into the joined record the gate re-runs; a fence naming the section
# file instead goes stale when the join's assembly removes the copies (A38 refuses that shape).
sec_write "$REPDIR/2.md" "$PAIR_SELF"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$REPDIR/2.md" "$PAIR_SELF"; then
  ok "the repair part <dir>/2.md, a pair deriving from the split document -> exit 0 (exempt until assembly)"
else
  bad "a self-referencing pair in the repair part exited $RC — a section repair cannot record a derivation that survives the join"
fi

# A36: a pair in the part that does not name the document is witnessed as anywhere else.
sec_write "$REPDIR/2.md" "$PAIR_GUESS"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "repair part, a guessed pair that does not name the document -> exit 2"
else
  bad "a non-self-referencing guess in a repair part exited $RC (expected 2) — the exemption covers every command in a part"
fi

# A37: a leading `./` on the document path is the same token; `../` is not.
PAIR_DOT="$(printf '```derived\n$ grep -c scope ./%s\n97\n```' "$SELF_REL")"
PAIR_DOTDOT="$(printf '```derived\n$ grep -c scope ../%s\n97\n```' "$SELF_REL")"
sec_write "$REPDIR/2.md" "$PAIR_DOT"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$REPDIR/2.md" "$PAIR_DOT"; then
  ok "repair part, the document spelled ./<path> -> exit 0 (the same token)"
else
  bad "a ./-prefixed document path in a repair part exited $RC — the leading ./ is not normalised"
fi
# A37b: the ./ token after a redirect, `<./<path>`. The canonical spelling (A44-A49) also resolves a
# bare `./<path>` to the document, so A37 alone is covered by two guards and a mutant of either
# survives. Here the whitespace field is `<./...`, whose directory does not exist, so only the ./
# normalisation in the token match can exempt it. Written into part 1.md, which no other arm touches.
PAIR_DOTREDIR="$(printf '```derived\n$ grep -c scope <./%s\n96\n```' "$SELF_REL")"
sec_write "$REPDIR/1.md" "$PAIR_DOTREDIR"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$REPDIR/1.md" "$PAIR_DOTREDIR"; then
  ok "repair part, the document spelled <./<path> -> exit 0 (the ./ after a redirect is the same token)"
else
  bad "a redirected ./-prefixed document path in a repair part exited $RC — the leading ./ is not normalised"
fi
sec_write "$REPDIR/2.md" "$PAIR_DOTDOT"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "repair part, the document spelled ../<path> -> exit 2 (a different file)"
else
  bad "a ../-prefixed document path in a repair part exited $RC (expected 2) — the ./ normalisation also swallows ../"
fi

# A38: a part pair that reads the SECTION COPY is refused at write time even though it reproduces
# now -- the join's assembly removes that file, so the gate would fail the correct repair. Its
# own control: the same pair reproduces under the real validator, so exit 2 here is the shape.
SEC_REL="_bmad-output/planning-artifacts/s1/shards/prd-repair-p1/sections/2.md"
SEC_N="$( ( cd "$CONSUMER" && grep -c 'scope item' "$SEC_REL" ) )" || SEC_N=0
PAIR_SECFILE="$(printf '```derived\n$ grep -c %s %s\n%s\n```' "'scope item'" "$SEC_REL" "$SEC_N")"
printf '# c\n\n%s\n' "$PAIR_SECFILE" > "$WORK/secfile-ctl.md"
SFC="$( ( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" "$WORK/secfile-ctl.md" ) 2>&1 )"
SFC_RC=$?
sec_write "$REPDIR/2.md" "$PAIR_SECFILE"
if [ "$SFC_RC" = 0 ] && [ "$SEC_N" -gt 0 ] && [ "$RC" = 2 ] && grep -q 'reads the section copy' "$ERR" \
   && grep -q 'prd-repair-p1/2.md:' "$ERR"; then
  ok "repair part, a REPRODUCING pair that reads sections/2.md -> exit 2 'reads the section copy' (validator rc 0 on the same pair)"
else
  bad "a part pair reading the section copy exited $RC (validator on it: rc $SFC_RC, count $SEC_N) — a derivation doomed at assembly is accepted"
fi

# A39: a part whose ordinal the manifest does not list is not a part.
sec_write "$REPDIR/9.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "repair part 9.md beside a manifest that lists no part 9, the same pair -> exit 2"
else
  bad "an unlisted part ordinal exited $RC (expected 2) — any .md in a repair dir is exempt"
fi

# A40: a part-shaped file whose repair dir carries no split is a user file.
sec_write "$CONSUMER/_bmad-output/planning-artifacts/s1/shards/notes-repair-p1/2.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "a part-shaped 2.md in a repair dir with no split manifest, the same pair -> exit 2"
else
  bad "a part-shaped file with no manifest exited $RC (expected 2) — the part exemption is keyed on the path alone"
fi

# A41: a `2.md` NESTED below a repair dir, beside its own copy of sections/, is not a part: the
# case pattern's `*` crosses `/`. The nesting is `shards/nested/` so that the parent-is-shards
# test passes and only the repair-dir name test keeps it out (A42 owns the other test).
mkdir -p "$REPDIR/shards/nested"; cp -R "$REPDIR/sections" "$REPDIR/shards/nested/"
sec_write "$REPDIR/shards/nested/2.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" && [ -f "$REPDIR/shards/nested/sections/.manifest" ]; then
  ok "a 2.md nested below a repair dir beside a manifest copy, the same pair -> exit 2"
else
  bad "a nested part-shaped file exited $RC (expected 2) — the part path test is not keyed on the repair dir itself"
fi

# A42: a repair-named dir that does not sit directly under shards/ is not a repair dir.
XDIR="$CONSUMER/_bmad-output/planning-artifacts/s1/shards/x/prd-repair-p1"
mkdir -p "$XDIR"; cp -R "$REPDIR/sections" "$XDIR/"
sec_write "$XDIR/2.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" && [ -f "$XDIR/sections/.manifest" ]; then
  ok "a part in shards/x/prd-repair-p1/ (not directly under shards/), the same pair -> exit 2"
else
  bad "a part under a nested repair-named dir exited $RC (expected 2) — the repair dir's parent is not checked"
fi

# A43: once the manifest records `assembled`, the document holds the edit and the part is witnessed.
ADIR="$CONSUMER/_bmad-output/planning-artifacts/s1/shards/prd-repair-p7"
mkdir -p "$ADIR"; cp -R "$REPDIR/sections" "$ADIR/"
printf 'assembled\t%064d\n' 0 >> "$ADIR/sections/.manifest"
sec_write "$ADIR/2.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" && grep -q '^assembled' "$ADIR/sections/.manifest"; then
  ok "a part beside an ASSEMBLED manifest, the same pair -> exit 2 (the exemption ends at assembly)"
else
  bad "a part after assembly exited $RC (expected 2) — the part exemption outlives the join"
fi

# A32: a matching path with NO manifest is a user file, not a section copy.
sec_write "$CONSUMER/_bmad-output/planning-artifacts/s1/shards/notes-repair-p1/sections/2.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "a sections/2.md with no manifest beside it, the same pair -> exit 2"
else
  bad "a manifest-less file at a section path exited $RC (expected 2) — the exemption is keyed on the path alone"
fi

# A33: a file beside the manifest whose ordinal the manifest does not list.
sec_write "$REPDIR/sections/9.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "sections/9.md beside a manifest that lists no part 9, the same pair -> exit 2"
else
  bad "an unlisted ordinal in a split dir exited $RC (expected 2) — any file beside a manifest is exempt"
fi

# A34: a command naming a LONGER path that merely contains the document path is not the document.
sec_write "$REPDIR/sections/3.md" "$PAIR_LONGER"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR"; then
  ok "section copy, a command naming prd.md.orig -> exit 2 (the document path is a whole token)"
else
  bad "a command naming a longer path exited $RC (expected 2) — the self-reference test is a substring match"
fi

# A35: a COPY of the split's sections/ (manifest included) outside `shards/*-repair-p*/` is not a
# section copy. The one input only the path glob separates: A30 and A31 are also kept out by the
# manifest test, so without this arm the glob could widen to every file with nothing reddening.
mkdir -p "$CONSUMER/_bmad-output/planning-artifacts/s1/scratch"
cp -R "$REPDIR/sections" "$CONSUMER/_bmad-output/planning-artifacts/s1/scratch/"
sec_write "$CONSUMER/_bmad-output/planning-artifacts/s1/scratch/sections/2.md" "$PAIR_SELF"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" \
   && [ -f "$CONSUMER/_bmad-output/planning-artifacts/s1/scratch/sections/.manifest" ]; then
  ok "a sections/2.md with a listing manifest but outside shards/*-repair-p*/, the same pair -> exit 2"
else
  bad "a manifest-carrying copy outside a repair dir exited $RC (expected 2) — the exemption is not keyed on the repair-dir path"
fi

# --- A44-A48: THE SAME DOCUMENT UNDER ANOTHER SPELLING (BL-380) ---------------------------------
# The manifest stores the document's PHYSICAL path, and the three spellings the exemption compared
# are that path, the project-relative one, and CLAUDE_PROJECT_DIR plus it. The harness's cwd is
# physical, so a command reaching the document through a symlink -- a logical /tmp path, or a
# directory that is itself a link -- matched none of them and a correct self-derivation was
# refused. Every arm writes into sections/1.md, which no earlier arm touches, silent arms first and
# near-misses last, so a file-grain mask cannot drag an earlier stale pair into a silent arm.
S1="$REPDIR/sections/1.md"
PD_PHYS="$(cd "$CONSUMER" && pwd -P)"
fire_pd() { # <project dir> <json> -> fire with the project dir spelled as given
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" >"$OUT" 2>"$ERR"
  RC=$?
}
# pair_on <path> [output]: the near-misses each record their OWN output, because a recorded output
# line in the payload touches every pair in the file that records it, and a shared `97` would drag
# an earlier near-miss's stale pair into a later arm and refuse it for the wrong reason.
pair_on() { printf '```derived\n$ grep -c scope %s\n%s\n```' "$1" "${2:-97}"; }
# A second prd.md in ANOTHER directory: the near-misses spell a path whose basename is the
# document's and whose canonical directory is not. It carries no `scope` line, so 97 is stale.
OTHER_DIR="$CONSUMER/_bmad-output/planning-artifacts/s2"
mkdir -p "$OTHER_DIR"; printf '# other\n' > "$OTHER_DIR/prd.md"
# The ancestor alias: a symlink to the project root itself, OUTSIDE it, as /tmp is to /private/tmp.
ALIAS="$WORK/alias-root"; ln -s "$CONSUMER" "$ALIAS"
# The in-project alias: a directory link inside the project, spelled relative.
ln -s _bmad-output/planning-artifacts/s1 "$CONSUMER/lnk"
ln -s _bmad-output/planning-artifacts/s2 "$CONSUMER/lnk2"

# A44: the ancestor alias, the harness handing the PHYSICAL project dir. The arm first proves the
# two spellings differ and resolve to one directory, or it compares a spelling with itself.
PAIR_ALIAS="$(pair_on "$ALIAS/$SELF_REL")"
if [ "$ALIAS/$SELF_REL" != "$PD_PHYS/$SELF_REL" ] && [ "$(cd "$ALIAS" && pwd -P)" = "$PD_PHYS" ]; then
  mkdir -p "$(dirname "$S1")"; printf '\n%s\n' "$PAIR_ALIAS" >> "$S1"
  fire_pd "$PD_PHYS" "$(edit_json "$S1" "$PAIR_ALIAS")"
  if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$S1" "$PAIR_ALIAS"; then
    ok "section copy, the document spelled through a symlinked ANCESTOR, physical project dir -> exit 0"
  else
    bad "the document spelled through a symlinked ancestor exited $RC — a logical spelling of the split document is refused"
  fi
else
  bad "FIXTURE BROKEN: the ancestor alias does not differ from, or does not resolve to, $PD_PHYS"
fi

# A45: the in-project directory link, spelled relative.
PAIR_LNK="$(pair_on "lnk/prd.md")"
sec_write "$S1" "$PAIR_LNK"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$S1" "$PAIR_LNK" && [ -L "$CONSUMER/lnk" ]; then
  ok "section copy, the document spelled through an in-project directory symlink -> exit 0"
else
  bad "the document spelled through a symlinked directory exited $RC — a path through a directory link is refused"
fi

# A46: the literal /tmp spelling. A second seed under /tmp, whose manifest therefore holds the
# /private/tmp path, driven with the physical project dir as the harness has it. Where /tmp is not
# a symlink the spelling cannot differ and the arm says so instead of passing.
if [ "$(cd /tmp && pwd -P)" != /tmp ] && TW="$(TMPDIR=/tmp bash "$HERE/seed.sh" 2>/dev/null)" && [ -f "$TW/env.sh" ]; then
  # Cleaned by the EXIT trap with the other temp dirs this run made outside $WORK.
  NOROOT_DIRS="${NOROOT_DIRS:-} $TW"
  T_CONSUMER="$( . "$TW/env.sh"; printf '%s' "$CONSUMER" )"; T_REPDIR="$( . "$TW/env.sh"; printf '%s' "$REPDIR" )"
  T_HOOK="$( . "$TW/env.sh"; printf '%s' "$HOOK" )"
  T_PHYS="$(cd "$T_CONSUMER" && pwd -P)"
  T_DOCLINE="$(sed -n 's/^document	//p' "$T_REPDIR/sections/.manifest")"
  PAIR_TMP="$(pair_on "$T_CONSUMER/$SELF_REL")"
  printf '\n%s\n' "$PAIR_TMP" >> "$T_REPDIR/sections/1.md"
  printf '%s' "$(edit_json "$T_REPDIR/sections/1.md" "$PAIR_TMP")" | CLAUDE_PROJECT_DIR="$T_PHYS" bash "$T_HOOK" >"$OUT" 2>"$ERR"
  RC=$?
  case "$T_CONSUMER" in /tmp/*) T_LOGICAL=1 ;; *) T_LOGICAL=0 ;; esac
  if [ "$T_LOGICAL" = 1 ] && [ "$T_DOCLINE" = "$T_PHYS/$SELF_REL" ] && [ "$T_PHYS" != "$T_CONSUMER" ] \
     && [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then
    ok "section copy, the document spelled /tmp/... with the manifest and project dir at /private/tmp/... -> exit 0"
  else
    bad "the /tmp spelling of a /private/tmp document exited $RC (manifest '$T_DOCLINE', project dir '$T_PHYS', command under '$T_CONSUMER')"
  fi
else
  printf '  n/a   the /tmp spelling: /tmp is not a symlink on this host, so A44 and A45 carry the mechanism\n'
fi

# A47: NEAR-MISS through the ancestor alias -- the same basename in ANOTHER directory. The
# canonical directory differs, so it is a different file and is witnessed.
PAIR_ALIAS_OTHER="$(pair_on "$ALIAS/_bmad-output/planning-artifacts/s2/prd.md" 91)"
printf '\n%s\n' "$PAIR_ALIAS_OTHER" >> "$S1"
fire_pd "$PD_PHYS" "$(edit_json "$S1" "$PAIR_ALIAS_OTHER")"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" && [ -f "$ALIAS/_bmad-output/planning-artifacts/s2/prd.md" ]; then
  ok "section copy, another prd.md spelled through the ancestor alias -> exit 2 (a different directory)"
else
  bad "another directory's prd.md through the ancestor alias exited $RC (expected 2) — the canonical spelling acquits a different file"
fi

# A48: NEAR-MISS through an in-project link to the OTHER directory.
PAIR_LNK_OTHER="$(pair_on "lnk2/prd.md" 92)"
sec_write "$S1" "$PAIR_LNK_OTHER"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" && [ -L "$CONSUMER/lnk2" ]; then
  ok "section copy, lnk2/prd.md linking to another directory -> exit 2"
else
  bad "a directory link to another prd.md exited $RC (expected 2) — the canonical spelling is keyed on the basename alone"
fi

# A49: NEAR-MISS in the document's OWN directory, through the same link: a different basename is a
# different file, though its directory canonicalises to the document's.
printf '# notes\n' > "$CONSUMER/_bmad-output/planning-artifacts/s1/notes.md"
PAIR_LNK_SIB="$(pair_on "lnk/notes.md" 93)"
sec_write "$S1" "$PAIR_LNK_SIB"
if [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" && [ -f "$CONSUMER/lnk/notes.md" ]; then
  ok "section copy, lnk/notes.md beside the document -> exit 2 (same directory, another file)"
else
  bad "a sibling of the document through the link exited $RC (expected 2) — the canonical spelling is keyed on the directory alone"
fi

# --- A50-A53: THE SECTION-COPY REFUSAL UNDER ANOTHER SPELLING ------------------------------------
# A38 refuses a part pair naming the split's sections/ dir by its three literal spellings. A command
# reaching the same file through a symlink matched none of them: accepted, 0 bytes of stderr, and
# `--assemble` then removed the file the joined record re-runs against. Every arm writes into part
# 3.md, which no earlier arm touches, silent near-misses first, and each pair records its OWN output
# so a payload line cannot touch another arm's pair. The two offenders REPRODUCE (4 and 1 under the
# real validator, A38's control), so exit 2 is the path and never a stale count.
P3="$REPDIR/3.md"
SEC2="_bmad-output/planning-artifacts/s1/shards/prd-repair-p1/sections/2.md"
# A sibling of sections/ whose name EXTENDS it, carrying a reproducing copy: the near-miss for a
# prefix test that forgets the `/`.
mkdir -p "$REPDIR/sections.bak"; cp "$REPDIR/sections/2.md" "$REPDIR/sections.bak/2.md"
ln -s _bmad-output/planning-artifacts/s1/shards/prd-repair-p1/sections "$CONSUMER/seclnk"
sec_pair() { printf '```derived\n$ grep -c %s %s\n%s\n```' "'$1'" "$2" "$3"; }

# A52: NEAR-MISS -- the reproducing pair over sections.bak/2.md, through the ancestor alias.
PAIR_BAK="$(sec_pair 'scope item' "$ALIAS/_bmad-output/planning-artifacts/s1/shards/prd-repair-p1/sections.bak/2.md" 4)"
printf '\n%s\n' "$PAIR_BAK" >> "$P3"
fire_pd "$PD_PHYS" "$(edit_json "$P3" "$PAIR_BAK")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$P3" "$PAIR_BAK" && [ -f "$REPDIR/sections.bak/2.md" ]; then
  ok "repair part, a reproducing pair over sections.bak/2.md through the ancestor alias -> exit 0 (outside sections/)"
else
  bad "a reproducing part pair over sections.bak/ through an alias exited $RC (expected 0) — the aliased refusal is a prefix match without the slash"
fi

# A53: NEAR-MISS -- the DOCUMENT through the ancestor alias, in the part: exempt (BL-380), not doomed.
PAIR_PDOC="$(pair_on "$ALIAS/$SELF_REL" 81)"
printf '\n%s\n' "$PAIR_PDOC" >> "$P3"
fire_pd "$PD_PHYS" "$(edit_json "$P3" "$PAIR_PDOC")"
if [ "$RC" = 0 ] && [ ! -s "$ERR" ] && seeded "$P3" "$PAIR_PDOC"; then
  ok "repair part, the document spelled through the ancestor alias -> exit 0 (exempt, not the section copy)"
else
  bad "the document through an alias in a repair part exited $RC (expected 0) — the aliased refusal or the part's canonical exemption is wrong"
fi

# A50: THE OFFENDER -- sections/2.md through the ancestor alias, harness handing the physical dir.
PAIR_SECALIAS="$(sec_pair 'scope item' "$ALIAS/$SEC2" 4)"
printf '\n%s\n' "$PAIR_SECALIAS" >> "$P3"
fire_pd "$PD_PHYS" "$(edit_json "$P3" "$PAIR_SECALIAS")"
if [ "$RC" = 2 ] && grep -q 'reads the section copy' "$ERR" && grep -q 'prd-repair-p1/3.md:' "$ERR" \
   && [ "$ALIAS/$SEC2" != "$PD_PHYS/$SEC2" ]; then
  ok "repair part, a reproducing pair over sections/2.md through the ancestor alias -> exit 2 'reads the section copy'"
else
  bad "the section copy reached via an aliased root exited $RC (expected 2 'reads the section copy') — a doomed pair is accepted under another spelling"
fi

# A51: THE OFFENDER -- a relative link whose target IS the sections/ dir.
PAIR_SECLNK="$(sec_pair 'second scope' "seclnk/2.md" 1)"
sec_write "$P3" "$PAIR_SECLNK"
if [ "$RC" = 2 ] && grep -q 'reads the section copy' "$ERR" && grep -q 'seclnk/2.md' "$ERR" && [ -L "$CONSUMER/seclnk" ]; then
  ok "repair part, a reproducing pair over seclnk/2.md (a link to sections/) -> exit 2 'reads the section copy'"
else
  bad "the section copy reached via a link into sections/ exited $RC (expected 2 'reads the section copy') — a doomed pair is accepted under another spelling"
fi

# --- A54-A61: A RECORD'S RE-DERIVATION IS JUDGED WITH THE GATE'S SUPERSESSION (BL-727) ----------
# The mask sits under a `mktemp -d` parent, where `is_record` never holds, and it blanks every pair
# the write did not touch -- including the LATER copy that supersedes a touched earlier one. So the
# hook passes the real file as AI_DLC_DERIV_SUPERSEDE_FROM and the validator reads the record test
# and the later copies from it. Eight rows, each in its own file so no row's payload touches
# another's pairs: A54-A57 are re-derivations the gate passes (exit 0, silent), A58-A61 are writes
# the gate fails (exit 2, FAIL (STALE) at the cited line). Every row also runs the GATE -- the real
# validator, env unset, on the real file -- so a silent arm proves its file really holds a
# superseded stale pair (SUPERSEDED, rc 0), and a refusing arm proves the gate agrees (rc 1).
SUP_PA="_bmad-output/planning-artifacts"
sup_path() { # <row> -> the row's file, relative to the project
  case "$1" in
    7) printf '%s/s1/sup7-live.md' "$SUP_PA" ;;
    8) printf '%s/sup8-repair-p1.md' "$SUP_PA" ;;
    *) printf '%s/s1/sup%s-repair-p1.md' "$SUP_PA" "$1" ;;
  esac
}
sup_body() { # <row> -> the file as it stands after the write
  case "$1" in
    1|4|7|8) printf '# r\n\n```derived\n$ echo alpha\nbeta\n```\n\nlater\n\n```derived\n$ echo alpha\nalpha\n```\n' ;;
    2) printf '# r\n\n```derived\n$ echo alpha\nbeta2\n```\n\nlater\n\n```derived\n$ echo alpha\nalpha\n```\n' ;;
    3) printf '# r\n\n```derived\n$ echo one\n1\n```\n\nlater\n\n```derived\n$ echo one\none\n```\n\n```derived\n$ echo 1\n1\n```\n' ;;
    5) printf '# r\n\n```derived\n$ echo gamma\ndelta\n```\n' ;;
    6) printf '# r\n\n```derived\n$ echo alpha\nalpha\n```\n\nlater\n\n```derived\n$ echo alpha\nbeta\n```\n' ;;
  esac
}
sup_payload() { # <row> -> the text the write carried
  case "$1" in
    1|7|8) printf 'later\n\n```derived\n$ echo alpha\nalpha\n```' ;;
    2) printf 'beta2' ;;
    3) printf '```derived\n$ echo 1\n1\n```' ;;
    4|6) printf '```derived\n$ echo alpha\nbeta\n```' ;;
    5) printf '```derived\n$ echo gamma\ndelta\n```' ;;
  esac
}
sup_line() { # <row> -> the line the hook must cite as stale, 0 for a silent row
  case "$1" in 1|2|3|4) echo 0 ;; 6) echo 11 ;; *) echo 4 ;; esac
}
sup_fire() { # <project dir> <row> -> write the row's file, fire that project's hook with its Edit
  mkdir -p "$(dirname "$1/$(sup_path "$2")")"
  sup_body "$2" > "$1/$(sup_path "$2")"
  printf '%s' "$(edit_json "$1/$(sup_path "$2")" "$(sup_payload "$2")")" \
    | CLAUDE_PROJECT_DIR="$1" bash "$1/.claude/hooks/ai-dlc-derivation-capture.sh" >"$OUT" 2>"$ERR"
  RC=$?
}
sup_ok() { # <row> -> 0 when the last fire is that row's verdict
  if [ "$(sup_line "$1")" = 0 ]; then
    [ "$RC" = 0 ] && [ ! -s "$ERR" ]
  else
    [ "$RC" = 2 ] && grep -q 'is not backed by' "$ERR" \
      && grep -qF "FAIL (STALE): $(sup_path "$1"):$(sup_line "$1") records an output" "$ERR"
  fi
}
sup_stale_at4() { # <row> -> 0 when the last fire refused the row's EARLIER pair, line 4
  [ "$RC" = 2 ] && grep -qF "FAIL (STALE): $(sup_path "$1"):4 records an output" "$ERR"
}
sup_seeded() { # <project dir> <row> -> 0 when every non-empty payload line is a line of the file
  local l
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    grep -qxF -- "$l" "$1/$(sup_path "$2")" || return 1
  done <<<"$(sup_payload "$2")"
}
sup_gate() { # <project dir> <row> -> GRC and $WORK/sup-gate.txt: the validator, env unset, on the real file
  ( cd "$1" && env -u AI_DLC_DERIV_SUPERSEDE_FROM AI_DLC_PROJECT_ROOT="$1" \
      bash "$1/scripts/ai-dlc/validate-artifact-derivations.sh" "$1/$(sup_path "$2")" ) > "$WORK/sup-gate.txt" 2>&1
  GRC=$?
}
SUP_WHAT_1="record, earlier stale \$ echo alpha/beta, Edit appends the correct copy"
SUP_WHAT_2="record, Edit rewrites only the superseded earlier pair's output to beta2"
SUP_WHAT_3="record, earlier superseded pair records 1, Edit adds an unrelated correct \$ echo 1/1"
SUP_WHAT_4="record, a stale copy inserted ABOVE a correct later identical command"
SUP_WHAT_5="record, a stale block with no later copy"
SUP_WHAT_6="record, a STALE later copy appended after a correct earlier one"
SUP_WHAT_7="LIVE document s1/sup7-live.md, earlier stale copy, Edit appends the correct copy"
SUP_WHAT_8="record-named file OUTSIDE s<N>/, earlier stale copy, Edit appends the correct copy"
for _r in 1 2 3 4 5 6 7 8; do
  sup_fire "$CONSUMER" "$_r"
  eval "_w=\$SUP_WHAT_$_r"
  sup_gate "$CONSUMER" "$_r"
  if [ "$(sup_line "$_r")" = 0 ]; then
    if sup_ok "$_r" && sup_seeded "$CONSUMER" "$_r" && [ "$GRC" = 0 ] && grep -q '^SUPERSEDED: ' "$WORK/sup-gate.txt"; then
      ok "A5$((_r + 3)): $_w -> exit 0, silent (the gate: rc 0, SUPERSEDED)"
    else
      bad "A5$((_r + 3)): $_w exited $RC (expected 0, silent; gate rc $GRC, expected 0 with SUPERSEDED): $(head -3 "$ERR")"
    fi
  else
    if sup_ok "$_r" && sup_seeded "$CONSUMER" "$_r" && [ "$GRC" = 1 ]; then
      ok "A$((_r + 53)): $_w -> exit 2, FAIL (STALE) at :$(sup_line "$_r") (the gate: rc 1)"
    else
      bad "A$((_r + 53)): $_w exited $RC (expected 2, FAIL (STALE) at :$(sup_line "$_r"); gate rc $GRC, expected 1): $(head -3 "$ERR")"
    fi
  fi
done

# --- A62-A63: THE JOIN GUARD, at the validator directly ------------------------------------------
# A62: AI_DLC_DERIV_SUPERSEDE_FROM naming a file that does not carry the argument's commands at the
# same lines is a REFUSAL (exit 2), never a verdict. The argument is row 1's file, whose earlier pair
# is stale, so a validator without the guard reads the other file's one command, skips the pre-pass
# and answers FAIL (STALE) at rc 1 -- which is why the arm requires the REFUSED text and no FAIL.
JR_TXT="$WORK/sup-join-refusal.txt"
( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" AI_DLC_DERIV_SUPERSEDE_FROM="$CONSUMER/$(sup_path 5)" \
    bash "$VALIDATOR" "$CONSUMER/$(sup_path 1)" ) > "$JR_TXT" 2>&1
JR_RC=$?
if [ "$JR_RC" = 2 ] && grep -q '^REFUSED: AI_DLC_DERIV_SUPERSEDE_FROM=.* does not carry the commands of ' "$JR_TXT" \
   && ! grep -q 'FAIL (STALE)' "$JR_TXT"; then
  ok "A62: SUPERSEDE_FROM naming a file that does not join the argument -> REFUSED, exit 2, no verdict"
else
  bad "A62: a non-joining SUPERSEDE_FROM exited $JR_RC (expected 2 with the join REFUSED line and no FAIL): $(head -2 "$JR_TXT")"
fi
# A63: the near-miss -- SUPERSEDE_FROM naming the argument itself joins, and supersession fires.
( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" AI_DLC_DERIV_SUPERSEDE_FROM="$CONSUMER/$(sup_path 1)" \
    bash "$VALIDATOR" "$CONSUMER/$(sup_path 1)" ) > "$WORK/sup-selfjoin.txt" 2>&1
_sj=$?
if [ "$_sj" = 0 ] && grep -q '^SUPERSEDED: ' "$WORK/sup-selfjoin.txt" && ! grep -q '^REFUSED' "$WORK/sup-selfjoin.txt"; then
  ok "A63: SUPERSEDE_FROM naming the argument itself -> exit 0, SUPERSEDED"
else
  bad "A63: a self-joining SUPERSEDE_FROM exited $_sj (expected 0 with SUPERSEDED): $(head -2 "$WORK/sup-selfjoin.txt")"
fi

# --- A65-A67: THE SUPERSEDE_FROM PRE-CHECK, at the validator directly ----------------------------
# SUPERSEDE_FROM names the ONE real file a single masked argument stands for, so two arguments, or a
# real file that is not there, is refused BEFORE any walk, with its own text. Without the pre-check
# the join guard refuses these too, but under the "does not carry the commands" text and after a
# walk -- so the arms key on the pre-check's own sentence, and M6 scores that difference.
SUP_PRE='^REFUSED: AI_DLC_DERIV_SUPERSEDE_FROM=.* needs exactly one file argument and a readable file to read supersession from; no verdict\.$'
# A65: env set + two file arguments -> rc 2, the pre-check text, no verdict.
( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" AI_DLC_DERIV_SUPERSEDE_FROM="$CONSUMER/$(sup_path 1)" \
    bash "$VALIDATOR" "$CONSUMER/$(sup_path 1)" "$CONSUMER/$(sup_path 5)" ) > "$WORK/sup-pre-two.txt" 2>&1
_p2=$?
if [ "$_p2" = 2 ] && grep -q "$SUP_PRE" "$WORK/sup-pre-two.txt" && ! grep -q 'FAIL' "$WORK/sup-pre-two.txt"; then
  ok "A65: SUPERSEDE_FROM with two file arguments -> REFUSED by the pre-check, exit 2, no verdict"
else
  bad "A65: SUPERSEDE_FROM with two file arguments exited $_p2 (expected 2 with the pre-check REFUSED line and no FAIL): $(head -2 "$WORK/sup-pre-two.txt")"
fi
# A66: env set to a real file that is not there -> rc 2, the pre-check text, no verdict.
( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" AI_DLC_DERIV_SUPERSEDE_FROM="$CONSUMER/$SUP_PA/s1/sup-absent.md" \
    bash "$VALIDATOR" "$CONSUMER/$(sup_path 1)" ) > "$WORK/sup-pre-missing.txt" 2>&1
_pm=$?
if [ ! -e "$CONSUMER/$SUP_PA/s1/sup-absent.md" ] && [ "$_pm" = 2 ] && grep -q "$SUP_PRE" "$WORK/sup-pre-missing.txt" \
   && ! grep -q 'FAIL' "$WORK/sup-pre-missing.txt"; then
  ok "A66: SUPERSEDE_FROM naming a missing file -> REFUSED by the pre-check, exit 2, no verdict"
else
  bad "A66: SUPERSEDE_FROM naming a missing file exited $_pm (expected 2 with the pre-check REFUSED line and no FAIL): $(head -2 "$WORK/sup-pre-missing.txt")"
fi
# A67: the near-miss -- env UNSET, the same two arguments: the normal walk runs and answers. Row 5's
# pair is stale and row 1's earlier pair is superseded, so the walk's own verdict is rc 1.
( cd "$CONSUMER" && env -u AI_DLC_DERIV_SUPERSEDE_FROM AI_DLC_PROJECT_ROOT="$CONSUMER" \
    bash "$VALIDATOR" "$CONSUMER/$(sup_path 1)" "$CONSUMER/$(sup_path 5)" ) > "$WORK/sup-pre-unset.txt" 2>&1
_pu=$?
if [ "$_pu" = 1 ] && grep -qF "FAIL (STALE): $CONSUMER/$(sup_path 5):4 records an output" "$WORK/sup-pre-unset.txt" \
   && grep -q '^SUPERSEDED: ' "$WORK/sup-pre-unset.txt" && ! grep -q '^REFUSED' "$WORK/sup-pre-unset.txt"; then
  ok "A67: env unset, the same two arguments -> the normal walk (rc 1, SUPERSEDED and FAIL (STALE)), no REFUSED"
else
  bad "A67: env unset with two arguments exited $_pu (expected 1 with SUPERSEDED, FAIL (STALE) at :4 and no REFUSED): $(head -2 "$WORK/sup-pre-unset.txt")"
fi

# --- A64: the hook's join-guard arm is a fail-open, and it SAYS so -------------------------------
# A join REFUSED is hook/validator drift no author can repair, so the hook exits 0 -- but a silent
# fail-open reads exactly like a pass, so the hook names the refusal and the gate backstop. On exit
# 0 a PostToolUse hook's stderr never reaches the model, so the line goes out as additionalContext
# JSON on stdout, and stderr stays empty. The LAST line of additionalContext is compared, so a world
# carrying the provenance library (which prepends its marker line) still matches.
# The validator's REAL refusal (A62's capture) is replayed by a stub: the hook builds its mask from
# the file it names, so the real join cannot be broken through it.
sup_replay() { # <captured text> <status> <dest> -> a stub validator replaying them
  { printf '#!/bin/sh\ncat <<'"'"'REFUSAL'"'"' >&2\n'; cat "$1"; printf 'REFUSAL\nexit %s\n' "$2"; } > "$3"
}
sup_jg_ok() { # -> 0 when the last fire is the join-guard verdict: exit 0, stderr empty, the JSON on stdout
  local ev ctx
  [ "$RC" = 0 ] && [ ! -s "$ERR" ] || return 1
  ev="$(jq -r '.hookSpecificOutput.hookEventName // empty' "$OUT" 2>/dev/null)" || return 1
  [ "$ev" = PostToolUse ] || return 1
  ctx="$(jq -r '.hookSpecificOutput.additionalContext // empty' "$OUT" 2>/dev/null)" || return 1
  grep -q "^AI/DLC derivation capture: the write-time check could not run -- the validator refused the supersession input (REFUSED: AI_DLC_DERIV_SUPERSEDE_FROM=.* does not carry the commands of .*); this edit was NOT checked, and the gate re-runs the file\.\$" <<<"$(tail -n 1 <<<"$ctx")"
}
cp "$VALIDATOR" "$WORK/validator.bak"
sup_replay "$JR_TXT" "$JR_RC" "$VALIDATOR"
sup_fire "$CONSUMER" 1
cp "$WORK/validator.bak" "$VALIDATOR"
if [ "$JR_RC" = 2 ] && sup_jg_ok && ! grep -q 'did not run to' "$ERR"; then
  ok "A64: a join-guard REFUSED from the validator -> exit 0, stderr empty, PostToolUse additionalContext on stdout naming the refusal and the gate"
else
  bad "A64: a replayed join REFUSED (capture rc $JR_RC) gave hook rc $RC with stdout: $(head -c 300 "$OUT") stderr: $(head -2 "$ERR") -- expected exit 0, empty stderr and the 'could not run' additionalContext"
fi

# --- M1-M6: MUTANTS OF THE BL-727 FIX, each a COPY in its own project, guarded by cmp -s ----------
# Each project carries the seeded hook and validator, one of them mutated. The unmutated project is
# the control: rows 1 and 5 hold there, and the join line appears, so a project whose hook or
# validator cannot run fails the control rather than scoring every mutant as a kill.
sup_world() { # <name> <hook> <validator> -> SUPW, a project carrying exactly those two
  SUPW="$WORK/sup-world-$1"
  mkdir -p "$SUPW/.claude/hooks" "$SUPW/scripts/ai-dlc" "$SUPW/$SUP_PA/s1" \
    && printf '0.0.0\n' > "$SUPW/VERSION" \
    && cp "$2" "$SUPW/.claude/hooks/ai-dlc-derivation-capture.sh" \
    && cp "$3" "$SUPW/scripts/ai-dlc/validate-artifact-derivations.sh"
}
sup_mut() { # <src> <dst> <old> <new> -> 0 when <old> is on exactly one line of <src> and the copy differs
  local n
  n="$(grep -cF -- "$3" "$1")" || n=0
  [ "$n" = 1 ] || { printf '  DID NOT APPLY: %s lines of %s carry the anchor\n' "$n" "$1"; return 1; }
  O="$3" N="$4" awk 'BEGIN { o = ENVIRON["O"]; n = ENVIRON["N"] }
    { i = index($0, o); if (i) $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); print }' "$1" > "$2" || return 1
  ! cmp -s "$1" "$2"
}
MH="$WORK/sup-mut-hook.sh"; MV="$WORK/sup-mut-validator.sh"

# CONTROL: the unmutated pair in a project of its own.
if sup_world ctl "$HOOK" "$VALIDATOR" && cmp -s "$HOOK" "$SUPW/.claude/hooks/ai-dlc-derivation-capture.sh"; then
  sup_fire "$SUPW" 1; _c1=$RC; sup_ok 1; _o1=$?
  sup_fire "$SUPW" 5; _c5=$RC; sup_ok 5; _o5=$?
  sup_replay "$JR_TXT" "$JR_RC" "$SUPW/scripts/ai-dlc/validate-artifact-derivations.sh"
  sup_fire "$SUPW" 1; sup_jg_ok; _oj=$?
  if [ "$_o1" = 0 ] && [ "$_o5" = 0 ] && [ "$_oj" = 0 ]; then
    ok "mutant control: the unmutated copies give row 1 exit 0, row 5 FAIL (STALE) at :4, and the join line"
  else
    bad "FIXTURE BROKEN: the unmutated copies gave row 1 rc $_c1, row 5 rc $_c5, join line $_oj -- every mutant verdict below is void"
  fi
else
  bad "FIXTURE BROKEN: the mutant control project could not be built"
fi

# M1: the hook drops AI_DLC_DERIV_SUPERSEDE_FROM -- the defect as filed. Rows 1-4 go red, each on
# the EARLIER pair the mask can no longer see superseded. Row 4 is scored too: A57 is silent-shaped
# and would pass against a hook that emits nothing, so it needs a mutant that reddens it.
if sup_mut "$HOOK" "$MH" 'AI_DLC_DERIV_SUPERSEDE_FROM="$FILE" bash "$VALIDATOR"' 'bash "$VALIDATOR"' \
   && sup_world m1 "$MH" "$VALIDATOR"; then
  _k=""
  for _r in 1 2 3 4; do sup_fire "$SUPW" "$_r"; sup_ok "$_r" || { sup_stale_at4 "$_r" && _k="$_k$_r"; }; done
  [ "$_k" = 1234 ] && ok "M1 killed: the hook without SUPERSEDE_FROM refuses rows 1, 2, 3 and 4 at :4" \
    || bad "M1 survived: with the env dropped only rows '$_k' of 1-4 went red at :4 -- A54-A57 do not need the real file"
else
  bad "M1 DID NOT APPLY: the hook's validator call no longer carries AI_DLC_DERIV_SUPERSEDE_FROM=\"\$FILE\""
fi

# M2: the validator keeps the ARGUMENT's parent and basename for is_record (the mask's mktemp dir),
# while the later copies still come from the real file. Row 1 goes red: no record, no supersession.
if sup_mut "$VALIDATOR" "$MV.1" 'd="${sf%/*}"; [ "$d" = "$sf" ] && d="."' 'd="${f%/*}"; [ "$d" = "$f" ] && d="."' \
   && sup_mut "$MV.1" "$MV" '-v bn="${sf##*/}"' '-v bn="${f##*/}"' \
   && sup_world m2 "$HOOK" "$MV"; then
  sup_fire "$SUPW" 1
  if ! sup_ok 1 && sup_stale_at4 1; then ok "M2 killed: is_record read off the mask's path refuses row 1 at :4"
  else bad "M2 survived: is_record keyed on the argument's path gave row 1 rc $RC -- A54 does not need the real file's identity"; fi
else
  bad "M2 DID NOT APPLY: the supersession pre-pass no longer takes par/bn from \$sf"
fi

# M3: the validator's join guard matches nothing. A62's call then reads the other file's one command,
# skips the pre-pass and answers FAIL (STALE) at rc 1 -- a verdict built on a file it never joined.
if sup_mut "$VALIDATOR" "$MV" 'substr($0, 1, 2) == "C " && !($0 in have)' 'substr($0, 1, 2) == "C " && 0' \
   && sup_world m3 "$HOOK" "$MV"; then
  sup_body 1 > "$SUPW/$(sup_path 1)"; sup_body 5 > "$SUPW/$(sup_path 5)"
  ( cd "$SUPW" && AI_DLC_PROJECT_ROOT="$SUPW" AI_DLC_DERIV_SUPERSEDE_FROM="$SUPW/$(sup_path 5)" \
      bash "$SUPW/scripts/ai-dlc/validate-artifact-derivations.sh" "$SUPW/$(sup_path 1)" ) > "$WORK/sup-m3.txt" 2>&1
  _m3=$?
  if [ "$_m3" = 1 ] && ! grep -q '^REFUSED' "$WORK/sup-m3.txt" && grep -q 'FAIL (STALE): .*:4 records an output' "$WORK/sup-m3.txt"; then
    ok "M3 killed: without the join guard a non-joining SUPERSEDE_FROM gives a verdict (rc 1, FAIL (STALE)), not REFUSED"
  else
    bad "M3 survived: without the join guard the non-joining call gave rc $_m3: $(head -2 "$WORK/sup-m3.txt")"
  fi
else
  bad "M3 DID NOT APPLY: the join guard's awk test is not on one line of the validator"
fi

# M4: the hook's join-guard arm matches nothing. The REFUSED line then falls to the generic arm and
# the write is refused under the "did not run to completion" headline -- an author blocked by drift.
if sup_mut "$HOOK" "$MH" "if _jg=\"\$(grep -m1 '^REFUSED: AI_DLC_DERIV_SUPERSEDE_FROM=' <<<\"\$OUT\")\"; then" 'if false; then' \
   && sup_world m4 "$MH" "$VALIDATOR"; then
  sup_body 1 > "$SUPW/$(sup_path 1)"
  sup_replay "$JR_TXT" "$JR_RC" "$SUPW/scripts/ai-dlc/validate-artifact-derivations.sh"
  sup_fire "$SUPW" 1
  if ! sup_jg_ok && [ "$RC" = 2 ] && grep -q 'did not run to' "$ERR"; then
    ok "M4 killed: without the join-guard arm the drift refuses the write under the 'did not run to completion' headline"
  else
    bad "M4 survived: without the join-guard arm the hook gave rc $RC: $(head -2 "$ERR")"
  fi
else
  bad "M4 DID NOT APPLY: the hook's join-guard test is not on one line"
fi

# M5: the join-guard arm still exits 0 but emits nothing -- the silent fail-open A64 exists to refuse.
# `:` swallows the jq call's arguments, so the arm emits neither the JSON nor anything on stderr.
if sup_mut "$HOOK" "$MH" 'jq -n --arg context' ': --arg context' \
   && sup_world m5 "$MH" "$VALIDATOR"; then
  sup_body 1 > "$SUPW/$(sup_path 1)"
  sup_replay "$JR_TXT" "$JR_RC" "$SUPW/scripts/ai-dlc/validate-artifact-derivations.sh"
  sup_fire "$SUPW" 1
  if ! sup_jg_ok && [ "$RC" = 0 ] && [ ! -s "$OUT" ] && [ ! -s "$ERR" ]; then
    ok "M5 killed: a join-guard arm that exits 0 silently (no stdout, no stderr) fails A64"
  else
    bad "M5 survived: the silenced join-guard arm gave rc $RC with $(wc -c < "$OUT") stdout and $(wc -c < "$ERR") stderr bytes"
  fi
else
  bad "M5 DID NOT APPLY: the hook's additionalContext jq call is not on one line"
fi

# M6: the validator's SUPERSEDE_FROM pre-check matches nothing. A65's and A66's inputs then reach
# the walk, and the join guard refuses them under ITS text -- a refusal for the wrong reason, after
# reading a file the pre-check exists to keep it from reading. Scored as the presence of that text.
if sup_mut "$VALIDATOR" "$MV" 'if [ "$#" -ne 1 ] || [ ! -f "$1" ] || [ ! -r "$SUP_FROM" ] || [ ! -f "$SUP_FROM" ]; then' 'if false; then' \
   && sup_world m6 "$HOOK" "$MV"; then
  sup_body 1 > "$SUPW/$(sup_path 1)"; sup_body 5 > "$SUPW/$(sup_path 5)"
  _MV6="$SUPW/scripts/ai-dlc/validate-artifact-derivations.sh"
  ( cd "$SUPW" && AI_DLC_PROJECT_ROOT="$SUPW" AI_DLC_DERIV_SUPERSEDE_FROM="$SUPW/$(sup_path 1)" \
      bash "$_MV6" "$SUPW/$(sup_path 1)" "$SUPW/$(sup_path 5)" ) > "$WORK/sup-m6-two.txt" 2>&1
  _m6a=$?
  ( cd "$SUPW" && AI_DLC_PROJECT_ROOT="$SUPW" AI_DLC_DERIV_SUPERSEDE_FROM="$SUPW/$SUP_PA/s1/sup-absent.md" \
      bash "$_MV6" "$SUPW/$(sup_path 1)" ) > "$WORK/sup-m6-missing.txt" 2>&1
  _m6b=$?
  _k6=""
  ! grep -q "$SUP_PRE" "$WORK/sup-m6-two.txt" && grep -q 'does not carry the commands of' "$WORK/sup-m6-two.txt" && _k6="${_k6}a"
  ! grep -q "$SUP_PRE" "$WORK/sup-m6-missing.txt" && grep -q 'does not carry the commands of' "$WORK/sup-m6-missing.txt" && _k6="${_k6}b"
  if [ "$_k6" = ab ]; then
    ok "M6 killed: without the pre-check both A65's and A66's inputs reach the walk and are refused by the join guard instead (rc $_m6a, $_m6b)"
  else
    bad "M6 survived: without the pre-check only inputs '$_k6' of ab lost the pre-check text for the join guard's (rc $_m6a, $_m6b): $(head -2 "$WORK/sup-m6-two.txt")"
  fi
else
  bad "M6 DID NOT APPLY: the validator's SUPERSEDE_FROM pre-check test is not on one line"
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

# --- S1-S5: THE SNAPSHOT STAMP CARRIER --------------------------------------------------
# A write to pipeline-snapshot.md is judged by validate-artifact-budget.sh --stamps-only over
# the lines it wrote. Now is pinned to 2026-10-16T02:00:00Z. The seeded snapshot already
# carries an OLD placeholder (`T19:3xZ`) that no arm here writes, so every silent arm also
# proves untouched text is not re-judged. Skipped, and said so, where the layout lacks the
# budget validator (a consumer that has not pulled it).
SNAP="$CONSUMER/_bmad-output/pipeline-snapshot.md"
if [ -r "$CONSUMER/scripts/ai-dlc/validate-artifact-budget.sh" ]; then
  export AI_DLC_SNAPSHOT_NOW_EPOCH=1792116000
  printf '%s\n' '## Recent Activity' '- 2026-10-16T01:00Z start' \
    '## Open Items' '- REPAIR JOIN BLOCKED (2026-10-15T19:3xZ): old text' \
    '## In-Flight Teammates' 'agent | role | deliverable | dispatched-at | status' '--- | --- | --- | --- | ---' > "$SNAP"
  printf '%s\n' '{"ts":"2026-10-16T01:58:32Z","name":"pm-escalated","role":"pm"}' > "$CONSUMER/_bmad-output/spawn-ledger.jsonl"
  snap_edit() { # <line> -> append it to the snapshot and fire the Edit that wrote it
    printf '%s\n' "$1" >> "$SNAP"; fire "$(edit_json "$SNAP" "$1")"
  }
  ra_edit() { # <line> -> insert it as the last Recent Activity line and fire the Edit
    awk -v l="$1" '/^## Open Items/ { print l } { print }' "$SNAP" > "$SNAP.new" && mv "$SNAP.new" "$SNAP"
    fire "$(edit_json "$SNAP" "$1")"
  }
  ra_undo() { awk -v l="$1" '$0 != l' "$SNAP" > "$SNAP.new" && mv "$SNAP.new" "$SNAP"; }
  # S1 control: an honest line is silent, and the old placeholder is not re-judged.
  ra_edit '- 2026-10-16T01:59Z RESUMED'
  if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then ok "snapshot: an honest written line -> exit 0, the untouched placeholder not re-judged"
  else bad "snapshot: an honest line exited $RC: $(head -2 "$ERR")"; fi
  # S2 a future leading stamp in the written Recent Activity line.
  ra_edit '- 2026-10-16T02:30Z DEPLOY DONE'
  if [ "$RC" = 2 ] && grep -q '^FUTURE .*2026-10-16T02:30Z' "$ERR"; then ok "snapshot: a future stamp written -> exit 2 FUTURE"
  else bad "snapshot: a future stamp exited $RC (expected 2 FUTURE): $(head -2 "$ERR")"; fi
  ra_undo '- 2026-10-16T02:30Z DEPLOY DONE'
  # S3 a placeholder stamp written.
  ra_edit '- 2026-10-16T01:59Z V1 advisor DONE 2026-10-16T02:2xZ'
  if [ "$RC" = 2 ] && grep -q '^MALFORMED .*2026-10-16T02:2x' "$ERR" && ! grep -q '19:3x' "$ERR"; then ok "snapshot: a placeholder stamp written -> exit 2 MALFORMED, the old one not named"
  else bad "snapshot: a placeholder stamp exited $RC (expected 2 MALFORMED on 02:2x only): $(head -3 "$ERR")"; fi
  ra_undo '- 2026-10-16T01:59Z V1 advisor DONE 2026-10-16T02:2xZ'
  # S4 a back-dated in-flight row (dispatch 01:58:32, stamped 01:56:40) -- the BL-564 shape.
  snap_edit 'fold | pm-escalated | d1 | 2026-10-16T01:56:40Z | in-flight'
  if [ "$RC" = 2 ] && grep -q '^BACKDATED .*112 s' "$ERR"; then ok "snapshot: a back-dated dispatched-at written -> exit 2 BACKDATED"
  else bad "snapshot: a back-dated row exited $RC (expected 2 BACKDATED 112 s): $(head -2 "$ERR")"; fi
  sed -i.bak '$d' "$SNAP" && rm -f "$SNAP.bak"
  # S5 the near-miss twin of S4: stamped 1 s after the dispatch, and a recorded future deadline.
  snap_edit 'fold | pm-escalated | d1 | 2026-10-16T01:58:33Z | in-flight'
  _s5=$RC
  ra_edit '- 2026-10-16T01:59Z operator set the monitor deadline 2026-10-21T16:08:54Z'
  if [ "$_s5" = 0 ] && [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then ok "snapshot: an honest row and a body deadline -> exit 0"
  else bad "snapshot: honest row exited $_s5, body deadline exited $RC (both expected 0)"; fi
  sed -i.bak '$d' "$SNAP" && rm -f "$SNAP.bak"
  # S6 a CELL-level Edit: new_string is the bare stamp alone. It reaches its row only through
  # the mask's fragment match.
  printf '%s\n' 'fold | pm-escalated | d1 | 2026-10-16T01:56:40Z | in-flight' >> "$SNAP"
  fire "$(edit_json "$SNAP" '2026-10-16T01:56:40Z')"
  if [ "$RC" = 2 ] && grep -q '^BACKDATED .*112 s' "$ERR"; then ok "snapshot: a bare back-dated stamp written into one cell -> exit 2 BACKDATED"
  else bad "snapshot: a cell-level back-dated stamp exited $RC (expected 2 BACKDATED): $(head -2 "$ERR")"; fi
  sed -i.bak '$d' "$SNAP" && rm -f "$SNAP.bak"
  # S7 a payload line shorter than a stamp that the OLD placeholder line contains (`(2026-10-15`,
  # 11 bytes) must not unmask it: the fragment floor is a full stamp.
  ra_edit '(2026-10-15'
  if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then ok "snapshot: a payload shorter than a stamp does not unmask old lines"
  else bad "snapshot: a short payload exited $RC, re-judging old text: $(head -2 "$ERR")"; fi
  ra_undo '(2026-10-15'
  # S8 an Edit whose old_string carries the OLD placeholder line as context, and whose
  # new_string keeps it and adds an honest line: only the added line is judged.
  _old='- REPAIR JOIN BLOCKED (2026-10-15T19:3xZ): old text'
  fire "$(jq -nc --arg f "$SNAP" --arg o "$_old" --arg n "$_old
- 2026-10-16T01:59Z joined" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n}}')"
  if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then ok "snapshot: an Edit keeping the old placeholder as context -> exit 0"
  else bad "snapshot: an Edit with the old placeholder as context exited $RC: $(head -2 "$ERR")"; fi
  # S9 a whole-file Write of the snapshot as it stands: the old placeholder is not re-judged.
  fire "$(write_json "$SNAP")"
  if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then ok "snapshot: a whole-file Write of unchanged text -> exit 0"
  else bad "snapshot: an unchanged whole-file Write exited $RC: $(head -2 "$ERR")"; fi
  # S10-S13 LATE AT WRITE TIME. An agentId resolves only through this session's subagents dir, which
  # wait-for-deliverable.sh finds from CLAUDE_CODE_SESSION_ID under $HOME/.claude/projects. A hook is
  # not handed that variable; its payload carries `session_id`. HOME is a scratch dir holding the one
  # meta.json, CLAUDE_CODE_SESSION_ID and AI_DLC_TEAMMATE_DIR are unset, so the meta.json is
  # reachable ONLY through the payload. The ledger row is the dispatch's, after an epoch row.
  if [ -f "$CONSUMER/scripts/ai-dlc/wait-for-deliverable.sh" ] && [ -f "$CONSUMER/scripts/ai-dlc/validate-adversarial-convergence.sh" ]; then
    LHOME="$WORK/home"; LSID="sess-605-capture"
    mkdir -p "$LHOME/.claude/projects/p/$LSID/subagents" || exit 2
    printf '{"agentType":"remediator","toolUseId":"toolu_01CaptureLateDDDDDDDD"}\n' \
      > "$LHOME/.claude/projects/p/$LSID/subagents/agent-a7ffc8dcd555207b8.meta.json"
    printf '%s\n' '{"ts":"2026-10-16T01:59:03Z","name":"","role":"remediator","tool_use_id":"toolu_01CaptureLateDDDDDDDD"}' \
      >> "$CONSUMER/_bmad-output/spawn-ledger.jsonl"
    lfire() { # <row> <session id or empty> -> append the row, fire its Edit with the payload's session_id
      printf '%s\n' "$1" >> "$SNAP"; LLN="$(wc -l < "$SNAP" | tr -d ' ')"
      printf '%s' "$(jq -nc --arg f "$SNAP" --arg s "$1" --arg sid "$2" \
          '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"IRRELEVANT",new_string:$s}} + (if $sid == "" then {} else {session_id:$sid} end)')" \
        | env -u CLAUDE_CODE_SESSION_ID HOME="$LHOME" CLAUDE_PROJECT_DIR="$CONSUMER" bash "$HOOK" >"$OUT" 2>"$ERR"
      RC=$?
      sed -i.bak '$d' "$SNAP" && rm -f "$SNAP.bak"
    }
    L_DECO='remediator (serial, pass 1 cross-part, a7ffc8dcd555207b8) | remediator | r1 | 2026-10-16T01:59:30Z | in-flight'
    l_late_line() { printf "LATE  pipeline-snapshot.md line %s: a7ffc8dcd555207b8 dispatched-at 2026-10-16T01:59:30Z is not its dispatch's ledger ts 2026-10-16T01:59:03Z" "$LLN"; }
    # S10 a bare agentId stamped 27 s late, session id in the payload: exit 2 LATE with the ts to copy.
    lfire 'a7ffc8dcd555207b8 | remediator | r1 | 2026-10-16T01:59:30Z | in-flight' "$LSID"
    if [ "$RC" = 2 ] && grep -qxF "$(l_late_line)" "$ERR"; then ok "snapshot: a LATE dispatched-at written, session_id in the payload -> exit 2 LATE naming the ledger ts"
    else bad "snapshot: a late row with session_id exited $RC (expected 2 and: $(l_late_line)): $(head -3 "$ERR")"; fi
    # S11 the motivating decorated cell, the same payload shape: LATE by its one resolving id.
    lfire "$L_DECO" "$LSID"
    if [ "$RC" = 2 ] && grep -qxF "$(l_late_line)" "$ERR"; then ok "snapshot: the decorated motivating cell written late -> exit 2 LATE naming a7ffc8dcd555207b8"
    else bad "snapshot: the decorated late row exited $RC (expected 2 and: $(l_late_line)): $(head -3 "$ERR")"; fi
    # S12 CONTROL: the identical payload with no session_id. The meta.json is unreachable, the row is
    # SKIP (filtered at write time), and the write is silent. S10 passing while this one fires would
    # mean the meta.json was reached some other way.
    lfire "$L_DECO" ""
    if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then ok "snapshot: the same late row with no session_id -> exit 0 (unresolvable, so not judged)"
    else bad "snapshot: the late row without session_id exited $RC (expected 0, silent): $(head -3 "$ERR")"; fi
    # S13 the same cell stamped EQUAL to its ledger ts, with session_id: silent.
    lfire 'remediator (serial, pass 1 cross-part, a7ffc8dcd555207b8) | remediator | r1 | 2026-10-16T01:59:03Z | in-flight' "$LSID"
    if [ "$RC" = 0 ] && [ ! -s "$ERR" ]; then ok "snapshot: the decorated row stamped equal to its ledger ts, session_id in the payload -> exit 0"
    else bad "snapshot: the equal row exited $RC (expected 0, silent): $(head -3 "$ERR")"; fi
  else
    ok "snapshot LATE arms SKIPPED: no wait-for-deliverable.sh beside the budget validator in this layout"
  fi
  unset AI_DLC_SNAPSHOT_NOW_EPOCH
else
  ok "snapshot carrier SKIPPED: no validate-artifact-budget.sh in this layout"
fi

if [ "$fails" -gt 0 ]; then
  printf '  %s assertion(s) failed\n' "$fails"
  exit 1
fi
exit 0
