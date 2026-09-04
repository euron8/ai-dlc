#!/bin/bash
#
# AI/DLC Derivation Capture Hook
#
# PURPOSE
# A ```derived block promises that its recorded output CAME FROM the command above
# it. This hook makes that true at the moment the block is written, by running the
# command itself and refusing the write when the two disagree.
#
# WHAT WAS MISSING, AND WHY THE EXISTING CHECK COULD NOT SEE IT.
# `validate-artifact-derivations.sh` re-runs a block's command and diffs it against
# the recorded output. It runs at the GATE -- `steps/_gate-procedures.md` invokes it
# after a repair and before the next adversarial pass. Its own header says what it
# is: "re-run the derivations a planning artifact carries". A re-run establishes
# REPRODUCIBILITY. It cannot establish PROVENANCE, because by the time it runs, the
# two states it would have to tell apart -- an output the author OBSERVED and an
# output the author GUESSED correctly -- are the same bytes on disk. The file is
# identical either way, so no later reader, human or script, can separate them.
#
# Measured, on the reference consumer, sprint 304: an author wrote two ```derived
# blocks into `stories-adversarial-repair-p3.md` -- one `find ... | wc -l`, one
# `find ... -name stories-adversarial-repair-p2.md` -- without invoking the tool
# first. Plausible text, not observed text. Both happened to match the tree when
# finally run, so every downstream check reported green and the incident is known
# only because the author reported it. Had either been wrong it would have been
# caught, one gate late, after the passes that read the number had already reasoned
# from it. The check is not weak; it runs at the wrong TIME to see the thing it
# needs to see.
#
# THIS HOOK CANNOT TELL A GUESS FROM AN OBSERVATION EITHER. It makes the question
# moot by performing the observation ITSELF, within the tool call that wrote the
# block, before any other pass can read the artifact. After it passes, the recorded
# output agrees with an execution that the author did not perform and could not
# influence -- which is the property the fence was always claiming, and the only
# form of it that is establishable from a file.
#
# WHY IT DOES NOT OVERWRITE THE BLOCK. The obvious stronger move -- have the hook
# replace the recorded output with what it captured -- was rejected, and this is the
# reason. An author writes command X expecting output E, and X is the WRONG command,
# producing A. Today, and under this hook, that mismatch stops the write and the
# author discovers X does not measure the claim. Under overwrite, A is silently
# written in, the sentence beside the block still asserts what E implied, and the
# artifact now carries a contradiction that reads as machine-verified. Overwrite
# converts a visible mismatch into a permanent green, which is the one direction a
# provenance mechanism must never fail in.
#
# WHY ONLY THE PAIRS THIS EDIT TOUCHED. Measured on the reference consumer's ACTIVE
# sprint, over the 40 artifact files carrying at least one fence: 12 of them already
# fail whole-file derivation validation. Blocking a write on a stale derivation the
# edit did not touch would refuse an unrelated edit in 30% of live files, and an
# author who cannot save a file gets the hook turned off. So the mask below blanks
# every command/output pair whose lines the payload does not contain, and the
# validator judges what is left. The pairs this edit did not touch stay the gate's
# job, unchanged.
#
# WHY IT DELEGATES RATHER THAN PARSING. The grammar, the read-only allowlist and
# the verdict all live in `validate-artifact-derivations.sh`. A hook with its own
# copy of any of them would be a second implementation whose disagreements nobody
# finds -- and the allowlist in particular is a SAFETY boundary: it is what keeps
# text out of a markdown file from becoming an arbitrary command. This hook decides
# only WHICH pairs to submit; it never decides whether one passes.
#
# IT BLOCKS ONLY ON A MISMATCH IT CAN NAME. Every other path exits 0 and prints
# nothing: no jq, not a Write/Edit, not markdown, no fence in the file, no validator
# installed (a consumer that has not pulled it yet), an unusable temp dir, or the
# validator itself failing to start. A capture hook that can fail a tool call for an
# infrastructure reason makes the pipeline's ability to write a file depend on the
# hook's ability to run, and that is not a trade this check is worth.
#
# OUTPUT
# - stdout: nothing, ever.
# - stderr + exit 2: the validator's own FAIL text, with the mask path rewritten to
#   the real file, when a pair this edit wrote does not reproduce, is refused by the
#   read-only allowlist, or opens a fence it never closes. The headline is class-neutral
#   because the validator already names the class, and a headline that said "does not
#   reproduce" would misdescribe the other two.
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-derivation-capture.sh
# 2. chmod +x .claude/hooks/ai-dlc-derivation-capture.sh
# 3. Add to .claude/settings.json hooks:
#      "PostToolUse": [
#        {
#          "matcher": "Write|Edit|MultiEdit",
#          "hooks": [{
#            "type": "command",
#            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-derivation-capture.sh"
#          }]
#        }
#      ]
# 4. Restart Claude Code
# 5. Verify with /hooks

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
VALIDATOR="${PROJECT_DIR}/scripts/ai-dlc/validate-artifact-derivations.sh"

INPUT=$(cat)

# jq reads the payload or nothing does. Absent it the hook is inert rather than
# guessing at the shape of its own input.
command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null)
case "$TOOL_NAME" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE=$(jq -r '.tool_input.file_path // empty' <<<"$INPUT" 2>/dev/null)
[ -n "$FILE" ] || exit 0
case "$FILE" in *.md) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0

# THE FENCE IS THE SCOPE, not a path list. `validate-artifact-derivations.sh` checks
# whatever file it is handed; keying this hook on a directory declaration instead
# would give the two programs different populations and one of them would be wrong
# about a file the other checks.
#
# AND A FENCE MAY BE INDENTED. A ```derived block written inside a list item opens with
# `  ```derived`, and until v0.500.0 this reject, the mask below and the validator all
# matched the opener at column 0 only -- so an indented block was never witnessed here and
# never checked at the gate, with no error from either. The validator carries the rule
# (CommonMark: the opener's leading blanks are the block's indent and each content line
# sheds that prefix); this hook applies the same rule in the three places it reads a
# fence line, because the two programs are one population by the contract above.
# PC-S308-VALIDATE-ARTIFACT-DERIVATIONS-INDENTED-FENCE-BLIND-SPOT.
grep -q '^[[:blank:]]*```derived' "$FILE" 2>/dev/null || exit 0

[ -r "$VALIDATOR" ] || exit 0

# The text THIS tool call wrote. `content` for Write, `new_string` for Edit, every
# `edits[].new_string` for MultiEdit -- whichever the payload carries.
PAYLOAD=$(jq -r '
  [ (.tool_input.content // empty),
    (.tool_input.new_string // empty),
    ((.tool_input.edits // []) | map(.new_string // empty) | join("\n"))
  ] | map(select(. != "")) | join("\n")
' <<<"$INPUT" 2>/dev/null)
[ -n "$PAYLOAD" ] || exit 0

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/ai-dlc-derivcap.XXXXXX" 2>/dev/null) || exit 0
trap 'rm -rf "$TMPD"' EXIT

printf '%s\n' "$PAYLOAD" > "$TMPD/payload.txt" 2>/dev/null || exit 0

# The mask keeps the file's line numbering byte-for-byte -- an untouched pair becomes
# blank lines, never deleted ones -- so the validator's `file:line` still points at
# the real artifact once the path is rewritten below.
#
# A pair is TOUCHED when the payload contains one of its lines, whole and exact:
# its `$ ` command line (a newly written block) or one of its recorded output lines
# (an edit that rewrote only the output). Empty lines are excluded from the payload
# index because nearly every payload has one and it would touch every pair.
MASK="$TMPD/$(basename "$FILE")"
awk '
# lead(s): the leading blanks of s. shed(s, ind): s with the block indent removed -- exactly
# `ind` when s carries it, else whatever leading blanks s has. The same two rules as
# `fence_indent` / `shed_indent` in the validator; a line is a fence delimiter or a `$ `
# command line by its SHED form, so the two programs agree on which lines are which.
function lead(s) { match(s, /^[ \t]*/); return substr(s, 1, RLENGTH) }
function shed(s, ind) {
  if (ind == "") return s
  if (substr(s, 1, length(ind)) == ind) return substr(s, length(ind) + 1)
  return substr(s, length(lead(s)) + 1)
}
FNR==NR { if ($0 != "") PAY[$0]=1; next }
{ L[FNR]=$0; N=FNR }
END {
  i=1
  while (i<=N) {
    ind = lead(L[i]); b = substr(L[i], length(ind) + 1)
    if (b=="```derived" || index(b,"```derived ")==1) {
      j=i+1
      while (j<=N && index(shed(L[j], ind),"```")!=1) j++
      split("", pid); split("", tch)
      cur=0
      for (k=i+1;k<j;k++) {
        if (index(shed(L[k], ind),"$ ")==1) cur=k
        pid[k]=cur
        if (cur>0 && (L[k] in PAY)) tch[cur]=1
      }
      any=0
      for (k=i+1;k<j;k++) if (pid[k]>0 && tch[pid[k]]) any=1
      print (any ? L[i] : "")
      for (k=i+1;k<j;k++) print ((pid[k]>0 && tch[pid[k]]) ? L[k] : "")
      if (j<=N) print (any ? L[j] : "")
      i=j+1
    } else {
      print L[i]
      i++
    }
  }
}
' "$TMPD/payload.txt" "$FILE" > "$MASK" 2>/dev/null || exit 0

# Nothing this edit wrote is a derivation -- the common case for an edit to prose in
# a file that happens to carry fences elsewhere. Indent-tolerant for the reason above.
grep -q '^[[:blank:]]*\$ ' "$MASK" 2>/dev/null || exit 0

OUT=$( ( cd "$PROJECT_DIR" 2>/dev/null && AI_DLC_PROJECT_ROOT="$PROJECT_DIR" \
         bash "$VALIDATOR" "$MASK" ) 2>&1 )
RC=$?

# 0 reproduces, 2 is the validator refusing to start (bad usage, unresolvable root) --
# an infrastructure state, not an author's mistake. Only 1 is a verdict about the text.
[ "$RC" = 1 ] || exit 0

REL="${FILE#"$PROJECT_DIR"/}"
{
  echo "AI/DLC derivation capture: a \`\`\`derived block this edit wrote is not backed by"
  echo "its own command. The checker's verdict follows."
  echo
  # Literal, left-to-right, CONSUMING replacement. An in-place rewrite that re-searches
  # the whole line does not terminate when the replacement contains the needle, and awk
  # gives no literal gsub to reach for instead.
  printf '%s\n' "$OUT" | awk -v m="$MASK" -v r="$REL" '
    { out=""; rest=$0; i=index(rest,m)
      while (i>0) { out=out substr(rest,1,i-1) r; rest=substr(rest,i+length(m)); i=index(rest,m) }
      print out rest }'
  echo
  echo "Only the block(s) this edit touched were re-run; the rest of the file was masked out."
  echo "Run the command yourself, record its output verbatim, and rewrite the sentence it"
  echo "supports if the real number is not the one you expected. Do NOT adjust the output to"
  echo "match the prose -- the block is the evidence, the prose is the claim."
} >&2
exit 2
