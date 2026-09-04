#!/usr/bin/env bash
# artifact-derivations — validate-artifact-derivations.sh must FAIL on a stale claim.
#
# WHY THIS FIXTURE IS SHAPED AS A DIFFERENTIAL. The validator's whole value is that it
# comes back RED on a fact that stopped being true. A checker that reads a ```derived
# block, executes nothing, and exits 0 prints a line indistinguishable from a real pass —
# "OK: N derivation(s) ... reproduce at HEAD" — and this repo has shipped that shape
# before. So no assertion here is on the exit code alone: every red case is paired with a
# green case whose ONLY difference is the recorded output, and the messages are asserted.
#
# The subject is a SHIPPED validator, so this fixture ships too (no .dist-only).
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
VALIDATOR="$(pick "$HERE/../../scripts/validate-artifact-derivations.sh" \
                  "$HERE/../../../scripts/ai-dlc/validate-artifact-derivations.sh" \
                  "$HERE/../../../core/scripts/validate-artifact-derivations.sh")"
[ -n "$VALIDATOR" ] || { echo "FIXTURE ERROR: cannot locate validate-artifact-derivations.sh" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The tree the derivations are ABOUT. Self-contained: the fixture owns the facts it
# asserts, so the case cannot go red because the repo around it changed.
mkdir -p "$WORK/src"
printf 'alpha\nbeta\ngamma\n' > "$WORK/src/three-lines.txt"
printf 'needle\nhay\nneedle\n'  > "$WORK/src/two-needles.txt"

emit() { # $1 file  $2 recorded-output-for-the-count
  mkdir -p "$(dirname "$1")"
  {
    printf '# Story\n\n'
    printf 'AC1 — the number of needles in the source file is asserted here.\n\n'
    printf '```derived\n'
    printf '$ grep -c needle src/two-needles.txt\n'
    printf '%s\n' "$2"
    printf '```\n'
  } > "$1"
}

run() { AI_DLC_PROJECT_ROOT="$WORK" bash "$VALIDATOR" "$@" 2>&1; }

echo "artifact-derivations fixture"

# --- A. THE DIFFERENTIAL --------------------------------------------------------
# Byte-identical artifacts but for the recorded integer. If the validator does not run
# the command, BOTH exit 0 and the second assertion goes red. That is the mutation proof
# and it is baked into the pair -- there is no way to satisfy both without executing.
emit "$WORK/a-true/story.md" 2
out="$(run "$WORK/a-true/story.md")"; rc=$?
[ "$rc" -eq 0 ] && ok "a-true                 exit=0  (recorded 2, the tree holds 2)" \
                || bad "a-true expected exit 0, got $rc: $out"

emit "$WORK/a-stale/story.md" 1
out="$(run "$WORK/a-stale/story.md")"; rc=$?
[ "$rc" -eq 1 ] && ok "a-stale                exit=1  (recorded 1, the tree holds 2 -- STALE)" \
                || bad "a-stale expected exit 1, got $rc: $out"
grep -q 'FAIL (STALE)' <<< "$out" \
  && grep -q 'recorded: 1' <<< "$out" \
  && grep -q 'actual:   2' <<< "$out" \
  && ok "a-stale-message       names the recorded value AND the actual one" \
  || bad "a-stale message must contrast recorded with actual: $out"

# --- B. THE EDIT THAT MOVES WHAT THE NUMBER COUNTED -----------------------------
# The measured dominant failure shape: derive -> write -> edit -> never re-derive. The
# artifact is UNTOUCHED here; the tree moved under it. Nothing in the artifact's own text
# can reveal this, which is exactly why a reader cannot catch it and a runner can.
emit "$WORK/b-drift/story.md" 2
out="$(run "$WORK/b-drift/story.md")"; rc=$?
[ "$rc" -eq 0 ] || bad "b-drift must start green, got $rc: $out"
printf 'needle\n' >> "$WORK/src/two-needles.txt"
out="$(run "$WORK/b-drift/story.md")"; rc=$?
[ "$rc" -eq 1 ] && ok "b-drift                exit=1  (artifact unchanged, the TREE moved)" \
                || bad "b-drift expected exit 1 after the tree moved, got $rc: $out"
sed -i.bak '$d' "$WORK/src/two-needles.txt" && rm -f "$WORK/src/two-needles.txt.bak"

# --- C. THE ALLOWLIST IS A BOUNDARY, NOT A SKIP ---------------------------------
# A refused command must FAIL. If it were skipped, an author could move any claim out of
# the checker's reach by writing it in a language the checker does not run -- and the
# suite would report the same clean line over a corpus it no longer checks.
#
# THE WRITE PREDICATES OF THE ALLOWED TOOLS ARE PART OF THAT BOUNDARY. `find`, `sed`,
# `sort`, `awk` and `git` are read-only PROGRAMS with one option each that writes a file
# or runs a command, and none of those options needs a shell metacharacter -- so the
# chain/redirect refusal above never sees them. They ran only at gate time until
# `ai-dlc-derivation-capture.sh` began re-running a block inside the tool call that wrote
# it; from there on the boundary holds with no human in the loop, or it does not hold.
for pair in "python3 -c 'print(2)'|not on the read-only allowlist" \
            "grep -c needle src/two-needles.txt > /tmp/x|chain, redirect or substitute" \
            "grep -c needle src/two-needles.txt; ls|chain, redirect or substitute" \
            "find src -name two-needles.txt -delete|writes a file or runs a command" \
            "find src -name x -exec ls {} +|writes a file or runs a command" \
            "sed -i.bak s/needle/x/ src/two-needles.txt|writes a file or runs a command" \
            "sort -o src/two-needles.txt src/two-needles.txt|writes a file or runs a command" \
            "git diff --output=src/x HEAD|writes a file or runs a command"; do
  c="${pair%%|*}"; want="${pair##*|}"
  mkdir -p "$WORK/c-refuse"
  { printf '```derived\n$ %s\n2\n```\n' "$c"; } > "$WORK/c-refuse/story.md"
  out="$(run "$WORK/c-refuse/story.md")"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q "$want" <<< "$out"; then
    ok "c-refuse               exit=1  ($c)"
  else
    bad "c-refuse expected exit 1 naming '$want' for '$c', got $rc: $out"
  fi
done

# THE REFUSAL HAS TO BE WHY THE FILE SURVIVED, not the seed's luck. Two of the rows above
# would delete or rewrite `src/two-needles.txt` if they ran; a refusal that merely exits 1
# after doing the damage is not a boundary.
if [ -s "$WORK/src/two-needles.txt" ] && ! [ -e "$WORK/src/two-needles.txt.bak" ]; then
  ok "c-refuse               the refused writers never touched the tree"
else
  bad "c-refuse a refused command still wrote to the tree — the refusal happens after execution"
fi

# --- D. A NEGATIVE IS A LEGITIMATE DERIVATION -----------------------------------
# `grep` exits 1 on NO HITS. A checker that treats a non-zero rc as failure cannot
# express "this token appears nowhere", which is one of the four claim shapes the
# adversary's underived-claim rung names. It must pass, and it must still FAIL when the
# token is actually present.
{ printf '```derived\n$ grep -c ZZ_ABSENT_ZZ src/two-needles.txt\n0\n```\n'; } > "$WORK/d-neg.md"
out="$(run "$WORK/d-neg.md")"; rc=$?
[ "$rc" -eq 0 ] && ok "d-negative             exit=0  (a zero-hit grep is a real derivation)" \
                || bad "d-negative expected exit 0, got $rc: $out"
{ printf '```derived\n$ grep -c needle src/two-needles.txt\n0\n```\n'; } > "$WORK/d-neg-false.md"
out="$(run "$WORK/d-neg-false.md")"; rc=$?
[ "$rc" -eq 1 ] && ok "d-negative-false       exit=1  (claiming 0 where the tree holds 2)" \
                || bad "d-negative-false expected exit 1, got $rc: $out"

# --- E. GRAMMAR: AN UNCLOSED BLOCK IS NOT A SILENT ZERO -------------------------
# A malformed block that simply yields no derivations reads exactly like a file with
# nothing to check.
{ printf '```derived\n$ grep -c needle src/two-needles.txt\n2\n'; } > "$WORK/e-unclosed.md"
out="$(run "$WORK/e-unclosed.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'never closed' <<< "$out" \
  && ok "e-unclosed             exit=1  (an unclosed block is reported, not skipped)" \
  || bad "e-unclosed expected exit 1 naming 'never closed', got $rc: $out"

# --- F. THE ZERO CARRIES A CONTROL ----------------------------------------------
# A file with no ```derived block must report 0 -- and the SAME invocation must be able
# to see a block, or "0 derivations" proves only that the reader is broken.
printf 'A story with no fenced derivations at all.\n' > "$WORK/f-none.md"
out="$(run --list "$WORK/f-none.md")"
grep -q '^0 derivation' <<< "$out" \
  && ok "f-none                 0 derivations (the subject)" \
  || bad "f-none expected '0 derivation(s)', got: $out"
out="$(run --list "$WORK/a-true/story.md")"
grep -q '^1 derivation' <<< "$out" \
  && ok "f-control              1 derivation  (the CONTROL: the reader is not simply blind)" \
  || bad "f-control expected '1 derivation(s)', got: $out"

# --- G. A `|` IS A PIPE ONLY WHERE THE SHELL SAYS IT IS -------------------------
# The allowlist splits a command into pipeline segments and checks each segment's first
# word. That split used to be `tr '|' '\n'`, which is quote-blind, so a read-only command
# carrying a quoted ERE alternation was torn in two and the fragment after the bar was
# refused as an unknown command -- a false refusal on correct data, now enforced with no
# human in the loop by `ai-dlc-derivation-capture.sh`.
#
# EVERY GREEN CASE HERE IS PAIRED WITH A STALE TWIN carrying the SAME command and a wrong
# recorded value. A validator that stopped splitting altogether, or that exits 0 without
# executing, passes the green half and fails the twin -- so no arm below can be satisfied
# by a subject that merely emits nothing.
gpair() { # $1 label  $2 command  $3 true-output  $4 wrong-output
  mkdir -p "$WORK/g"
  { printf '```derived\n$ %s\n%s\n```\n' "$2" "$3"; } > "$WORK/g/$1-true.md"
  out="$(run "$WORK/g/$1-true.md")"; rc=$?
  [ "$rc" -eq 0 ] && ok "g-$1 (runs)            exit=0  $2" \
                  || bad "g-$1 expected exit 0 for '$2', got $rc: $out"
  { printf '```derived\n$ %s\n%s\n```\n' "$2" "$4"; } > "$WORK/g/$1-stale.md"
  out="$(run "$WORK/g/$1-stale.md")"; rc=$?
  [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" \
    && ok "g-$1 (twin)            exit=1  STALE -- so the green half really executed" \
    || bad "g-$1 twin must be STALE for '$2', got $rc: $out"
}
gpair alternation  "grep -cE 'alpha|beta' src/three-lines.txt"   2 9
gpair alt-dquoted  "grep -cE \"alpha|beta\" src/three-lines.txt" 2 9
gpair alt-escaped  "grep -cE alpha\\|beta src/three-lines.txt"   2 9
gpair alt-piped    "grep -E 'alpha|beta' src/three-lines.txt | wc -l" "       2" 9
gpair hash-comment "grep -c alpha src/three-lines.txt # the trailing comment is not a quote" 1 9

# THE LOOSENING MUST NOT REACH A REAL PIPE. Each of these hides a NON-allowlisted command
# behind a quoted bar; a splitter that simply stopped splitting would admit every one.
#
# THESE TAKE TWO ARGUMENTS RATHER THAN A `|`-PACKED PAIR, and that is the point of the
# case. Section C above packs `command|expected-message` into one string because none of
# ITS commands contains a bar. Every command here does, so the same encoding truncated
# each one at its first bar -- and one of the truncations still exited 1, for a reason
# that had nothing to do with what the arm claimed to test.
grefuse() { # $1 command  $2 expected message
  mkdir -p "$WORK/g"
  { printf '```derived\n$ %s\n2\n```\n' "$1"; } > "$WORK/g/hidden.md"
  out="$(run "$WORK/g/hidden.md")"; rc=$?
  [ "$rc" -eq 1 ] && grep -q "$2" <<< "$out" \
    && ok "g-refused              exit=1  ($1)" \
    || bad "g-refused expected exit 1 naming '$2' for '$1', got $rc: $out"
}
grefuse "grep -E 'a|b' src/three-lines.txt | xargs echo" "not on the read-only allowlist"
grefuse "grep -E 'a|b' src/three-lines.txt | sed -i.bak s/a/b/ src/three-lines.txt" "writes a file or runs a command"
grefuse "grep -cE \"a|b\" src/three-lines.txt | python3 -c 'print(1)'" "not on the read-only allowlist"

# AN UNRESOLVED QUOTE IS REFUSED RATHER THAN SPLIT, and that refusal is load-bearing
# rather than tidy. `$'...'` is ANSI-C quoting: bash reads it as ONE word and would run
# the pipe after it, while a parity scan sees an odd number of quotes. Dropping the
# refusal and simply not splitting inside an open quote admits `xargs` here -- measured
# against a copy of the fix with the refusal deleted, which is the only thing that
# distinguishes this arm from decoration.
# ANSI-C quoting has its own refusal and its own message: it is not an unbalanced quote but
# a quote this scan deliberately declines to model, because bash and a parity scan disagree
# about where it ends. Keying this arm on the unbalanced wording would pass only by accident.
grefuse "grep \$'a\\'b' src/three-lines.txt | xargs rm" "ANSI-C quoting"
grefuse "grep -cE 'alpha src/three-lines.txt"          "unbalanced quote"
grefuse "grep 'a src/three-lines.txt | xargs rm"       "unbalanced quote"

# --- H. THE BOUNDARY IS ABOUT EXECUTION, SO ASSERT EXECUTION -----------------------
# Section G asserts VERDICTS. A verdict arm cannot see the failure that actually shipped:
# `v0.474.0` made the split quote-aware and, in the same edit, ACQUITTED five arbitrary-
# execution paths the quote-blind `tr '|' '\n'` had been refusing by accident. Every arm in
# this file stayed green, and the gate stayed green, because nothing here ran a command and
# looked at the tree afterwards.
#
# So each case below is scored by a CANARY: a file the command creates if it executes. The
# verdict is not the assertion; the absence of the canary is, and a case that is refused for
# the wrong reason still passes only if nothing ran.
# EACH CASE CARRIES ITS OWN POSITIVE CONTROL, IN THE SAME ARM. The command is first run
# by bash DIRECTLY and must create the canary -- that is what makes it an exec vector rather
# than a string that merely looks like one. Only then is it put through the validator, where
# the canary must NOT appear. Without the first half, "no canary" is satisfied by a command
# that could never have executed anyway, and the arm proves nothing.
#
# The legitimate forms are NOT scored here: the allowlist admits only read-only programs, so
# an allowed command cannot create a file by construction and no canary can express "ran and
# was permitted". Section G scores those, by verdict.
exec_contained() { # $1 label  $2 command
  mkdir -p "$WORK/h"
  rm -f "$WORK/h/canary"*
  ( cd "$WORK/h" && cp "$WORK/src/three-lines.txt" data.txt 2>/dev/null; bash -c "$2" ) >/dev/null 2>&1
  if ! ls "$WORK/h/canary"* >/dev/null 2>&1; then
    bad "h-$1 CONTROL: bash itself did not execute this, so containing it proves nothing: $2"
    rm -f "$WORK/h/canary"*; return
  fi
  rm -f "$WORK/h/canary"*
  { printf '```derived\n$ %s\n0\n```\n' "$2"; } > "$WORK/h/story.md"
  ( cd "$WORK/h" && AI_DLC_PROJECT_ROOT="$WORK/h" bash "$VALIDATOR" "$WORK/h/story.md" ) >/dev/null 2>&1
  if ls "$WORK/h/canary"* >/dev/null 2>&1; then
    bad "h-$1 EXECUTED through the validator -- the allowlist was bypassed: $2"
  else
    ok "h-$1               bash runs it; the checker does not"
  fi
  rm -f "$WORK/h/canary"*
}

# ANSI-C quoting: bash reads an escaped quote inside $'...' as a literal where a parity scan
# reads a toggle, so the two disagree about where the quote ends and a pipe lands in the gap.
exec_contained ansic-1  "grep -c \$'a\\'b' data.txt | xargs touch canary \\'"
exec_contained ansic-2  "grep -c \$'\\''   data.txt | xargs touch canary \\'"
exec_contained ansic-3  "grep -c \$'a\\'b' data.txt | xargs touch canary\\'"

# awk's own pipes to a shell. No shell metacharacter is involved, so the chain/redirect ban
# never sees them, and `awk:*system(*` covers only one of the three exec forms.
exec_contained awk-print   "awk 'BEGIN{print \"\" | \"touch canary\"}'"
exec_contained awk-getline "awk 'BEGIN{\"touch canary\" | getline x}'"

# The refused writers above must not have run, exactly as section C asserts for its own.
if [ -s "$WORK/src/three-lines.txt" ] && ! [ -e "$WORK/src/three-lines.txt.bak" ]; then
  ok "g-hidden               the refused writers never touched the tree"
else
  bad "g-hidden a command hidden behind a quoted bar still wrote to the tree"
fi

# --- I. AN INDENTED FENCE IS A FENCE ----------------------------------------------
# A ```derived block written inside a list item opens with `  ```derived`, and the reader
# matched the opener at column 0 only -- so the block never opened, its pair never ran, and the
# file printed "0 derivation(s) in 0 block(s)" with exit 0. That line is the ONE output this
# validator must never produce over a fence: the author fenced the claim to make it checkable
# and got no check and no error. Reported by the reference consumer as
# PC-S308-VALIDATE-ARTIFACT-DERIVATIONS-INDENTED-FENCE-BLIND-SPOT, whose own reproduction is
# the `--list` pair below: indented reports 0 blocks, the unindented control reports 1.
#
# EVERY GREEN CASE HAS A STALE TWIN, as in G: a reader that opens the block and executes
# nothing passes the green half and fails the twin. The `wc -l` pair is the one that
# separates the CORRECT rule (shed exactly the fence's indent) from the OBVIOUS one (shed all
# leading blanks): `wc -l` prints seven spaces before its digit, an author writing under a
# two-space fence records nine, and shedding all of them turns a true derivation STALE.
iemit() { # $1 file  $2 indent  $3 recorded-output  -- one block inside a list item
  { printf '# Story\n\n- AC1, with its derivation fenced beneath it:\n\n'
    printf '%s```derived\n%s$ grep -c needle src/two-needles.txt\n%s%s\n%s```\n' "$2" "$2" "$2" "$3" "$2"; } > "$1"
}
iemit "$WORK/i-true.md" "  " 2
out="$(run "$WORK/i-true.md")"; rc=$?
[ "$rc" -eq 0 ] && grep -q '1 derivation(s) in 1 block(s)' <<< "$out" \
  && ok "i-true                 exit=0  and the block is COUNTED (the filing's observable was '0 block(s)')" \
  || bad "i-true expected exit 0 counting 1 block, got $rc: $out"
out="$(run --list "$WORK/i-true.md")"
grep -q '^1 derivation(s) in 1 block' <<< "$out" \
  && ok "i-list                 --list sees the indented block (control: f-control saw the flat one)" \
  || bad "i-list expected '1 derivation(s) in 1 block(s)', got: $out"
iemit "$WORK/i-stale.md" "  " 1
out="$(run "$WORK/i-stale.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" && grep -q 'recorded: 1' <<< "$out" && grep -q 'actual:   2' <<< "$out" \
  && ok "i-stale                exit=1  STALE -- so the indented block really executed" \
  || bad "i-stale expected exit 1 STALE contrasting 1 with 2, got $rc: $out"
# Three spaces -- an ordered-list item's content offset -- opens a fence too.
iemit "$WORK/i-three.md" "   " 2
out="$(run "$WORK/i-three.md")"; rc=$?
[ "$rc" -eq 0 ] && grep -q '1 derivation(s) in 1 block(s)' <<< "$out" \
  && ok "i-three                exit=0  (a three-space indent opens the fence)" \
  || bad "i-three expected exit 0 counting 1 block, got $rc: $out"
# THE INDENT IS SHED EXACTLY. BSD `wc -l` right-aligns its count in eight columns, so a
# derivation of it carries seven leading spaces that are OUTPUT, not indent; the true twin
# records the fence indent PLUS that padding, and only a reader shedding exactly the fence
# indent reproduces it. The stale twin records the bare digit, which a reader shedding ALL
# blanks would wrongly accept as well. The padding is produced by `printf '%8s'` rather than
# by `wc` itself so the pair discriminates on GNU platforms too, where `wc -l` pads nothing
# and the two twins would collapse into one.
{ printf -- '- item\n\n  ```derived\n  $ %s\n  %s\n  ```\n' "printf '%8s\\n' 2" "       2"; } > "$WORK/i-pad-true.md"
out="$(run "$WORK/i-pad-true.md")"; rc=$?
[ "$rc" -eq 0 ] && ok "i-pad-true             exit=0  (indent shed EXACTLY: the output's own padding survives)" \
                || bad "i-pad-true expected exit 0 -- the reader is shedding more than the fence indent: $out"
{ printf -- '- item\n\n  ```derived\n  $ %s\n  %s\n  ```\n' "printf '%8s\\n' 2" "2"; } > "$WORK/i-pad-stale.md"
out="$(run "$WORK/i-pad-stale.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" \
  && ok "i-pad-stale            exit=1  STALE (the bare digit is not what the command printed)" \
  || bad "i-pad-stale expected exit 1 STALE, got $rc: $out"
# An unclosed INDENTED block is reported, not skipped -- E's arm has to reach this form too.
{ printf -- '- item\n\n  ```derived\n  $ grep -c needle src/two-needles.txt\n  2\n'; } > "$WORK/i-unclosed.md"
out="$(run "$WORK/i-unclosed.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'never closed' <<< "$out" \
  && ok "i-unclosed             exit=1  (an unclosed indented block is reported)" \
  || bad "i-unclosed expected exit 1 naming 'never closed', got $rc: $out"

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails assertion(s) wrong."
  exit 1
fi
echo "PASS: all assertions correct."
exit 0
