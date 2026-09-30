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
# - stderr + exit 2: the validator's UNRUN and REFUSED lines, with any STALE it reached,
#   when a pair this edit wrote did not run to completion. The validator exits 2 then, and
#   the hook tells that apart from a refusal to start by those lines, never by the status.
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

# A SECTION COPY MAY CARRY A DERIVATION OF THE DOCUMENT IT WAS CUT FROM. A section-sharded repair
# (`partition-document.sh --split <doc> s<N>/shards/<artifact>-repair-p<M>`) has each remediator
# edit `sections/<i>.md`, a copy, while the real document stays at its split bytes until the join
# assembles it. A fence in that copy whose command reads the DOCUMENT therefore cannot reproduce at
# write time: it describes the document after assembly, which does not exist yet. That pair -- and
# ONLY that pair -- is exempt here; the gate re-runs it against the assembled document.
#
# THE REMEDIATOR'S PART `<repair-dir>/<ordinal>.md` IS EXEMPT FOR THE SAME PAIR, AND ONLY WHILE THE
# DOCUMENT IS UNASSEMBLED. The part records the derivation of the edit, and the join copies it into
# the one repair record the gate re-runs. A fence naming the section file passes here and goes
# stale at the join, because `--assemble` removes the section copies by design; so the part must
# name the DOCUMENT, which does not yet hold the edit. Measured on a graph copy: 0 derivation
# failures over the sprint dir before the join, 2 after (the joined record and the part).
#
# THE EXEMPTION IS NARROW, each axis probed in derivation-capture:
#   - the path is `*/shards/*-repair-p*/sections/<ordinal>.md` (a section copy) or
#     `*/shards/*-repair-p*/<ordinal>.md` (its part): never the real document, never any other file;
#   - the split's `.manifest` (beside the copy; under `sections/` beside the part) lists that
#     ordinal as a `part` -- a user file at a matching path with no split behind it is neither;
#   - for a part, the manifest carries no `assembled` line: once the join has assembled the
#     document, a fence naming it reproduces or is wrong, and is witnessed as anywhere else;
#   - the pair's `$ ` command names the manifest's `document` path, absolute or project-relative
#     with or without a leading `./`, as a whole path token (a longer path that merely contains
#     it does not count);
#   - every OTHER pair this edit wrote is witnessed exactly as anywhere else, so a guessed
#     `grep -c` over some other file is still refused at write time.
#
# AND A PART'S PAIR THAT NAMES THE SPLIT'S `sections/` DIR IS REFUSED OUTRIGHT, reproducing or not:
# that file is removed at assembly, so the derivation is stale by construction at the gate.
SELF_DOC=""; SELF_REL=""; SELF_LOG=""; SEC_DIR=""
case "$FILE" in
  */shards/*-repair-p*/sections/*.md)
    SEC_MF="$(dirname "$FILE")/.manifest"
    SEC_ORD="$(basename "$FILE" .md)"
    if [ -f "$SEC_MF" ] && awk -F'\t' -v o="$SEC_ORD" '$1 == "part" && $2 == o { f = 1 } END { exit !f }' "$SEC_MF" 2>/dev/null; then
      SELF_DOC="$(awk -F'\t' '$1 == "document" { print $2; exit }' "$SEC_MF" 2>/dev/null)"
    fi ;;
  */shards/*-repair-p*/*.md)
    # Only a file DIRECTLY in the repair dir: `*` crosses `/` in a case pattern.
    PART_DIR="$(dirname "$FILE")"
    case "$(basename "$PART_DIR")" in *-repair-p*) ;; *) PART_DIR="" ;; esac
    [ "$(basename "$(dirname "${PART_DIR:-/}")")" = shards ] || PART_DIR=""
    SEC_MF="${PART_DIR}/sections/.manifest"
    SEC_ORD="$(basename "$FILE" .md)"
    if [ -n "$PART_DIR" ] && [ -f "$SEC_MF" ] && awk -F'\t' -v o="$SEC_ORD" '$1 == "part" && $2 == o { f = 1 } $1 == "assembled" { a = 1 } END { exit !(f && !a) }' "$SEC_MF" 2>/dev/null; then
      SELF_DOC="$(awk -F'\t' '$1 == "document" { print $2; exit }' "$SEC_MF" 2>/dev/null)"
      SEC_DIR="${PART_DIR}/sections"
    fi ;;
esac
# Resolved only inside a split: a write anywhere else pays no fork for it.
PD_PHYS=""
[ -n "$SELF_DOC$SEC_DIR" ] && PD_PHYS="$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)"
rel_of() { # <path> -> project-relative when under the project dir (physical or logical), else as given
  case "$1" in
    "$PD_PHYS"/*) printf '%s' "${1#"$PD_PHYS"/}" ;;
    "$PROJECT_DIR"/*) printf '%s' "${1#"$PROJECT_DIR"/}" ;;
    *) printf '%s' "$1" ;;
  esac
}
if [ -n "$SELF_DOC" ]; then
  SELF_REL="$(rel_of "$SELF_DOC")"
  # The manifest stores the PHYSICAL path; an author spells the project dir as the harness does.
  SELF_LOG="${PROJECT_DIR%/}/${SELF_REL}"
fi
SEC_REL=""; SEC_LOG=""; SEC_PHYS=""
if [ -n "$SEC_DIR" ]; then
  SEC_PHYS="$(cd "$SEC_DIR" 2>/dev/null && pwd -P)"
  SEC_REL="$(rel_of "${SEC_PHYS:-$SEC_DIR}")"
  SEC_LOG="${PROJECT_DIR%/}/${SEC_REL}"
fi
# THE SAME DOCUMENT UNDER ANOTHER SPELLING (BL-380). The three spellings above are the manifest's
# physical path, the project-relative one, and PROJECT_DIR plus that. A command reaching the
# document through a symlink is none of them: a logical /tmp path where the harness hands a
# physical project dir (its cwd is physical), or a path through a symlinked directory. Such a
# token is the document when its DIRECTORY canonicalises, with `pwd -P`, to the document's own
# and its basename is the document's -- the same directory entry, so nothing else can pass. The
# directory is canonicalised rather than the file, because the file may not exist under that
# spelling alone. Relative tokens resolve against PROJECT_DIR, where the validator runs them; a
# directory that does not exist there (`../<path>` from the project dir) resolves to nothing and
# names nothing. Only the file's `$ ` tokens ending in the document's basename are tried, and
# only inside a split, so a write anywhere else pays no fork for it.
dollar_tokens() { # [<basename>] -> the file's `$ ` tokens, quotes trimmed, one per line
  # With a basename: only the tokens ending in it. Without: every token carrying a `/`, with a
  # leading redirection (`<`, `>`) removed, since `grep x <dir/f` reads dir/f.
  awk -v b="${1:-}" -v q="'" '
    function trim(t,   qs) {
      qs = "\"" q "`"
      while (length(t) && index(qs, substr(t, 1, 1))) t = substr(t, 2)
      while (length(t) && index(qs, substr(t, length(t), 1))) t = substr(t, 1, length(t) - 1)
      return t
    }
    /^[ \t]*\$ / {
      for (f = 2; f <= NF; f++) {
        t = trim($f)
        if (b == "") { sub(/^[<>]+/, "", t); if (index(t, "/") && !seen[t]++) print t; continue }
        if (t == b || substr(t, length(t) - length(b)) == "/" b) if (!seen[t]++) print t
      }
    }' "$FILE" 2>/dev/null
}
canon_dir() { # <token> -> `pwd -P` of the token's directory, relative tokens against PROJECT_DIR
  # The directory part by expansion, never `dirname`: a token is command text, and one that opens
  # with `-` is read as an option and prints a usage error onto the hook's stderr. Called inside
  # `$( )`, so the `cd` is the substitution's own and costs no second fork.
  local d
  case "$1" in */*) d="${1%/*}" ;; *) d=. ;; esac
  case "$1" in /*) d="${d:-/}" ;; *) d="${PROJECT_DIR%/}/${d}" ;; esac
  cd "$d" 2>/dev/null && pwd -P
}
self_aliases() { # -> the file's `$ ` tokens that name SELF_DOC under another spelling, one per line
  local base ddir tok c
  base="$(basename "$SELF_DOC")"
  ddir="$(cd "$(dirname "$SELF_DOC")" 2>/dev/null && pwd -P)" || return 0
  [ -n "$ddir" ] || return 0
  dollar_tokens "$base" |
  while IFS= read -r tok; do
    c="$(canon_dir "$tok")" || continue
    [ -n "$c" ] && [ "$c" = "$ddir" ] && printf '%s\n' "$tok"
  done
}
SELF_ALIASES=""
[ -n "$SELF_DOC" ] && SELF_ALIASES="$(self_aliases)"
# THE REFUSAL SEES THE SAME SPELLINGS. A part's pair naming the split's `sections/` dir is doomed
# at assembly (above), and the three literal spellings of that dir miss a command reaching it
# through a symlink exactly as they missed the document: `<alias>/.../sections/2.md` and a link
# INTO sections/ were accepted with no stderr, and `--assemble` then removed the file the joined
# record re-runs against. A token is the section copy when its directory canonicalises to
# SEC_PHYS or below it -- with the `/`, so a sibling `sections.bak/` is not.
sec_aliases() { # -> the file's `$ ` tokens under the split's sections/ dir by another spelling
  local tok c
  [ -n "$SEC_PHYS" ] || return 0
  dollar_tokens |
  while IFS= read -r tok; do
    c="$(canon_dir "$tok")" || continue
    case "$c" in "$SEC_PHYS"|"$SEC_PHYS"/*) printf '%s\n' "$tok" ;; esac
  done
}
SEC_ALIASES=""
[ -n "$SEC_DIR" ] && SEC_ALIASES="$(sec_aliases)"

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
DOOMED="$TMPD/doomed"
SELF_ALIASES="$SELF_ALIASES" SEC_ALIASES="$SEC_ALIASES" awk -v sa="$SELF_DOC" -v sr="$SELF_REL" -v sl="$SELF_LOG" \
    -v da="${SEC_PHYS:+$SEC_PHYS/}" -v dr="${SEC_REL:+$SEC_REL/}" -v dl="${SEC_LOG:+$SEC_LOG/}" -v dout="$DOOMED" '
# lead(s): the leading blanks of s. shed(s, ind): s with the block indent removed -- exactly
# `ind` when s carries it, else whatever leading blanks s has. The same two rules the
# validator applies inline in check_file; a line is a fence delimiter or a `$ ` command line
# by its SHED form, so the two programs agree on which lines are which.
function lead(s) { match(s, /^[ \t]*/); return substr(s, 1, RLENGTH) }
function shed(s, ind) {
  if (ind == "") return s
  if (substr(s, 1, length(ind)) == ind) return substr(s, length(ind) + 1)
  return substr(s, length(lead(s)) + 1)
}
# preok(s, i): a path token may START at byte i of s -- the byte before is not a path
# character, or it is the `/` of a leading `./` that is itself preceded by none (so `./x`
# counts and `../x` does not).
function preok(s, i,   pre, pp) {
  pre = (i > 1 ? substr(s, i - 1, 1) : "")
  if (pre == "/" && i > 2 && substr(s, i - 2, 1) == ".") {
    pp = (i > 3 ? substr(s, i - 3, 1) : "")
    if (pp !~ /[A-Za-z0-9_.\/-]/) return 1
  }
  return pre !~ /[A-Za-z0-9_.\/-]/
}
# names(s, p): s carries p as a whole path token -- preok before it, and the byte after is not a
# path character. Empty p names nothing, so outside a split no pair is ever exempt.
function names(s, p,   i, off, post) {
  if (p == "") return 0
  off = 0
  while ((i = index(substr(s, off + 1), p)) > 0) {
    i += off
    post = substr(s, i + length(p), 1)
    if (preok(s, i) && post !~ /[A-Za-z0-9_.\/-]/) return 1
    off = i
  }
  return 0
}
# under(s, d): s carries a path token that begins with the directory prefix d (ending in `/`).
function under(s, d,   i, off) {
  if (d == "") return 0
  off = 0
  while ((i = index(substr(s, off + 1), d)) > 0) {
    i += off
    if (preok(s, i)) return 1
    off = i
  }
  return 0
}
# aliased(s): s names the document under one of the canonicalised spellings self_aliases found.
# Read from ENVIRON, not -v, which would strip one level of backslashes from each spelling.
function aliased(s,   a) {
  for (a = 1; a <= NAL; a++) if (names(s, AL[a])) return 1
  return 0
}
# secaliased(s): s names a file under the split sections/ dir by a spelling sec_aliases found.
function secaliased(s,   a) {
  for (a = 1; a <= NSA; a++) if (names(s, SA[a])) return 1
  return 0
}
BEGIN {
  NAL = (ENVIRON["SELF_ALIASES"] == "" ? 0 : split(ENVIRON["SELF_ALIASES"], AL, "\n"))
  NSA = (ENVIRON["SEC_ALIASES"] == "" ? 0 : split(ENVIRON["SEC_ALIASES"], SA, "\n"))
}
FNR==NR { if ($0 != "") PAY[$0]=1; next }
{ L[FNR]=$0; N=FNR }
END {
  i=1
  while (i<=N) {
    ind = lead(L[i]); b = substr(L[i], length(ind) + 1)
    # The info string is EXACTLY derived, as the validator requires: a wrapped sentence whose
    # continuation begins with the token used to open a phantom block that swallowed the real
    # one after it (measured in the validator header). No apostrophe in this comment: it sits
    # inside a single-quoted awk program.
    if (b ~ /^```derived[ \t]*$/) {
      j=i+1
      while (j<=N && index(shed(L[j], ind),"```")!=1) j++
      split("", pid); split("", tch)
      cur=0
      for (k=i+1;k<j;k++) {
        if (index(shed(L[k], ind),"$ ")==1) cur=k
        pid[k]=cur
        if (cur>0 && (L[k] in PAY)) tch[cur]=1
      }
      # A part pair naming the split sections/ dir is doomed at assembly: recorded, refused below.
      for (k in tch) if (tch[k] && (under(L[k], da) || under(L[k], dr) || under(L[k], dl) || secaliased(L[k]))) print k > dout
      # The section-copy exemption: a touched pair whose command names the split document.
      for (k in tch) if (tch[k] && (names(L[k], sa) || names(L[k], sr) || names(L[k], sl) || aliased(L[k]))) tch[k]=0
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

# A part's derivation over the section copy: refused whether or not it reproduces now.
if [ -s "$DOOMED" ]; then
  REL="${FILE#"$PROJECT_DIR"/}"
  {
    echo "AI/DLC derivation capture: a \`\`\`derived block this edit wrote in a section repair part"
    echo "reads the section copy under ${SEC_REL}/, which the join's assembly removes -- so the"
    echo "gate re-runs it against a file that no longer exists and fails the repair."
    echo
    awk -v r="$REL" 'FNR == NR { want[$1] = 1; next } FNR in want { printf "  %s:%s  %s\n", r, FNR, $0 }' "$DOOMED" "$FILE"
    echo
    echo "Name the DOCUMENT by its project-relative path, ${SELF_REL}, in the command instead."
    echo "At write time the document does not hold your edit yet, so that pair is not re-run"
    echo "here; the gate re-runs it against the assembled document after the join."
  } >&2
  exit 2
fi

# Nothing this edit wrote is a derivation -- the common case for an edit to prose in
# a file that happens to carry fences elsewhere. Indent-tolerant for the reason above.
grep -q '^[[:blank:]]*\$ ' "$MASK" 2>/dev/null || exit 0

OUT=$( ( cd "$PROJECT_DIR" 2>/dev/null && AI_DLC_PROJECT_ROOT="$PROJECT_DIR" \
         bash "$VALIDATOR" "$MASK" ) 2>&1 )
RC=$?

# 0 reproduces and 1 is a verdict about the text. 2 has TWO meanings, and the exit status
# cannot separate them, so the validator's own output lines do:
#   - an `^UNRUN:` line (and the `^REFUSED:` summary after it) names a derivation this edit
#     wrote that did not run to completion. The validator withholds every verdict in the file
#     then, STALE findings included, so exiting 0 here would hide a real mismatch behind one
#     unrunnable block in the same write. It is surfaced, with any STALE lines beside it.
#   - anything else at 2 is the validator refusing to START -- bad usage, a root it cannot
#     resolve, a target that is not there. That is an infrastructure state, not an author's
#     mistake, and it stays exit 0 for the reason in the header.
# Any other status (a validator that crashed) is infrastructure too.
UNRUN_SEEN=0
case "$RC" in
  1) ;;
  2) grep -qE '^(UNRUN|REFUSED):' <<<"$OUT" || exit 0
     UNRUN_SEEN=1 ;;
  *) exit 0 ;;
esac

REL="${FILE#"$PROJECT_DIR"/}"
{
  if [ "$UNRUN_SEEN" = 1 ]; then
    echo "AI/DLC derivation capture: a \`\`\`derived block this edit wrote did not run to"
    echo "completion, so the checker withheld its verdict on every block this edit touched."
    echo "Its output, including any stale finding it reached, follows."
  else
    echo "AI/DLC derivation capture: a \`\`\`derived block this edit wrote is not backed by"
    echo "its own command. The checker's verdict follows."
  fi
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
