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
