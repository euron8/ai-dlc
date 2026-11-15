#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
#
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
VALIDATOR="$(pick "$HERE/../../scripts/validate-artifact-derivations.sh" \
                  "$HERE/../../../scripts/ai-dlc/validate-artifact-derivations.sh" \
                  "$HERE/../../../core/scripts/validate-artifact-derivations.sh")"
[ -n "$VALIDATOR" ] || { echo "FIXTURE ERROR: cannot locate validate-artifact-derivations.sh" >&2; exit 2; }
# The REQUIRED input of inputs.decl: every assertion below drives this file.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[ -f "$HERE/unit.sh" ] || { echo "FIXTURE ERROR: unit.sh not found in $HERE" >&2; exit 2; }
. "$HERE/unit.sh"
echo "HERMETIC-CONSUMED core/fixtures/artifact-derivations/unit.sh"

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

run() { vad_call "$VALIDATOR" AI_DLC_PROJECT_ROOT="$WORK" -- "$@" 2>&1; }

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
            "git diff --output=src/x HEAD|writes a file or runs a command" \
            "echo \`touch canary\`|backtick outside single quotes, which bash runs as command substitution" \
            "echo \"\`touch canary\`\"|backtick outside single quotes, which bash runs as command substitution" \
            "echo 'a'\`touch canary\`'b'|backtick outside single quotes, which bash runs as command substitution"; do
  rm -f "$WORK/canary"
  c="${pair%%|*}"; want="${pair##*|}"
  mkdir -p "$WORK/c-refuse"
  { printf '```derived\n$ %s\n2\n```\n' "$c"; } > "$WORK/c-refuse/story.md"
  out="$(run "$WORK/c-refuse/story.md")"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q "$want" <<< "$out"; then
    ok "c-refuse               exit=1  ($c)"
  else
    bad "c-refuse expected exit 1 naming '$want' for '$c', got $rc: $out"
  fi
  # The eval runs from the project root, so a backtick that executed leaves `$WORK/canary`.
  if [ -e "$WORK/canary" ]; then
    bad "c-refuse '$c' was refused AFTER it ran -- the canary exists"
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
  ( cd "$WORK/h" && vad_call "$VALIDATOR" AI_DLC_PROJECT_ROOT="$WORK/h" -- "$WORK/h/story.md" ) >/dev/null 2>&1
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

# SED'S OWN WRITING VERBS LIVE INSIDE THE SCRIPT ARGUMENT. The allowlist's write predicates
# iterate `$seg` matching `${first}:${w}`, so they read OPTION WORDS and are structurally
# blind to `w file`, `W file` and the `w file` FLAG on `s///` -- none of which is an option.
# Measured on this machine, pre-fix: every one of these created its canary at exit 0 with
# the validator in the loop. The canary is the assertion, exactly as above.
exec_contained sed-w-cmd     "sed -n 'w canary' data.txt"
exec_contained sed-s-w-flag  "sed 's/a/b/w canary' data.txt"
exec_contained sed-addr-w    "sed '/a/w canary' data.txt"
exec_contained sed-brace-w   "sed -n '1{w canary
}' data.txt"
exec_contained sed-s-gw-flag "sed 's/a/b/gw canary' data.txt"
# `-f` PUTS THE VERB IN A FILE, SO NO SCAN OF THE SEGMENT CAN SEE IT. The segment carries no
# `w` at all; the script does. This is why the option is refused outright rather than
# followed. The canary name differs because the sed script in the file names it.
#
# THE TWO SEEDS ARE NAMED DIFFERENTLY ON PURPOSE. With both named `evil.sed`, a mutant that
# removed the `-f` refusal was still killed -- by the VERB rule, reading the leading `e` of
# the filename as GNU's exec command -- so one arm of the pair passed for a reason unrelated to
# `-f`. Measured: renaming the seed to `prog.sed` swapped which arm fired. `prog.sed` opens
# with `p`, a harmless verb, so the arm below is refused by the `-f` rule or by nothing.
mkdir -p "$WORK/h"
printf 'w canaryF\n' > "$WORK/h/evil.sed"
exec_contained sed-script-file "sed -n -f evil.sed data.txt"
printf 'w canaryF\n' > "$WORK/h/prog.sed"
exec_contained sed-script-file-joined "sed -n -fprog.sed data.txt"
# ARBITRARY WHITESPACE SITS BETWEEN THE VERB AND ITS FILENAME, in both forms, and both write.
# A grammar keyed on `w<space><name>` misses these; this one returns at the verb in command
# position and never parses the filename, so the whitespace cannot matter -- which is a claim
# these two arms settle rather than assert.
exec_contained sed-w-spaces   "sed -n 'w   canary' data.txt"
exec_contained sed-s-w-spaces "sed 's/a/b/w   canary' data.txt"
exec_contained sed-w-tab      "sed -n 'w	canary' data.txt"
# `-u` (BSD) AND `-z` (GNU) PASS THE SCRIPT THROUGH UNTOUCHED, on either side of `-n`. The
# predicate is sited on the SEGMENT and models option arity, so an unknown option cannot
# shift which word it reads as the script -- seeded because "handled automatically" is a
# claim about the implementation, not a measurement.
exec_contained sed-u-before   "sed -u -n 'w canary' data.txt"
exec_contained sed-u-after    "sed -n -u 'w canary' data.txt"

# A `w` TARGET ON AN ABSOLUTE PATH WRITES OUTSIDE THE ARTIFACT'S OWN DIRECTORY. The eval runs
# from the project root and sed resolves the path itself, so containment inside the story's
# directory is not the property -- the property is that the write does not happen at all.
# `exec_contained` globs `$WORK/h/canary*` and structurally cannot see an absolute target, so
# this arm names the target and checks it directly.
abs_contained() { # $1 label  $2 command-with-$ABS  (ABS is the absolute canary path)
  mkdir -p "$WORK/h-abs"
  ABS="$WORK/h-abs/abs-canary"
  rm -f "$ABS"
  printf 'a\nb\nc\n' > "$WORK/h-abs/data.txt"
  local c; c="$(printf '%s' "$2" | "${SED:-sed}" "s#@ABS@#$ABS#g")"
  ( cd "$WORK/h-abs" && bash -c "$c" ) >/dev/null 2>&1
  if [ ! -e "$ABS" ]; then
    bad "h-$1 CONTROL: bash itself did not write the absolute target, so containing it proves nothing: $c"
    return
  fi
  rm -f "$ABS"
  { printf '```derived\n$ %s\n0\n```\n' "$c"; } > "$WORK/h-abs/story.md"
  ( cd "$WORK/h-abs" && vad_call "$VALIDATOR" AI_DLC_PROJECT_ROOT="$WORK/h-abs" -- "$WORK/h-abs/story.md" ) >/dev/null 2>&1
  if [ -e "$ABS" ]; then
    bad "h-$1 WROTE an ABSOLUTE path through the validator: $c"
  else
    ok "h-$1        bash writes the absolute target; the checker does not"
  fi
  rm -f "$ABS"
}
abs_contained sed-w-abspath "sed -n 'w @ABS@' data.txt"

# A PIPELINE PUTS THE WRITER IN A LATER SEGMENT. A predicate written against the whole
# COMMAND rather than against `$seg` passes the first of these -- the bar and the leading
# `sed -n 'p'` change nothing about the second stage -- and the second, where `sed` is not
# even the command's first word. Both write today.
exec_contained sed-pipe-second "sed -n 'p' data.txt | sed -n 'w canary'"
exec_contained sed-pipe-after-cat "cat data.txt | sed -n 'w canary'"
# `{` AND `}` RESET COMMAND POSITION, THEY DO NOT CONSUME IT. A `-e` pair can split a brace
# block across two script arguments, so the `w` sits immediately after the `{` in the FIRST
# one. A grammar that treats `{` as a command and steps past the next character swallows the
# `w` and allows this -- and it writes.
exec_contained sed-brace-split-e "sed -n -e '1{w canary' -e '}' data.txt"
# AND EVERY `-e` ARGUMENT IS SCANNED, not just the first. The verb here is in the first of
# two, which a scan keyed on the LAST script argument misses.
exec_contained sed-e-first-of-two "sed -n -e 'w canary' -e 'p' data.txt"
# ALTERNATE `s` DELIMITERS. `s/` is not the only spelling: any character after `s` is the
# delimiter, so a grammar hard-coding `/` sees no s/// at all and never reaches its flags.
exec_contained sed-s-comma-delim "sed 's,a,b,w canary' data.txt"
exec_contained sed-s-letter-delim "sed 'sXaXbXw canary' data.txt"
exec_contained sed-s-hash-delim  "sed 's#a#b#w canary' data.txt"

# --- H2. `-i` REWRITES THE INPUT, AND A JOINED SUFFIX WITH NO DOT IS THE MISSED FORM ------
# `sed -i.bak` was refused; `sed -ibak`, `sed -iX`, `sed -nibak` and `sed -ni.bak` were not,
# because the shipped table listed `sed:-i` and `sed:-i.*` and neither pattern spells a
# joined suffix with no dot or a BUNDLED `-ni`. These cannot be scored by a canary whose
# name the fixture chooses -- `-i` creates `data.txtbak`, not `canary` -- so the observable
# is the INPUT FILE ITSELF: bash rewrites it, and the validator must not.
inplace_contained() { # $1 label  $2 command
  # Reset per call and again after the control, never copied from one build: the control's bash rewrites data.txt.
  mkdir -p "$WORK/h2"
  printf 'a\nb\nc\n' > "$WORK/h2/data.txt"
  cp "$WORK/h2/data.txt" "$WORK/h2/.orig"
  ( cd "$WORK/h2" && bash -c "$2" ) >/dev/null 2>&1
  if cmp -s "$WORK/h2/.orig" "$WORK/h2/data.txt"; then
    bad "h2-$1 CONTROL: bash itself did not rewrite data.txt, so containing it proves nothing: $2"
    return
  fi
  rm -rf "$WORK/h2"; mkdir -p "$WORK/h2"
  printf 'a\nb\nc\n' > "$WORK/h2/data.txt"
  cp "$WORK/h2/data.txt" "$WORK/h2/.orig"
  { printf '```derived\n$ %s\n0\n```\n' "$2"; } > "$WORK/h2/story.md"
  ( cd "$WORK/h2" && vad_call "$VALIDATOR" AI_DLC_PROJECT_ROOT="$WORK/h2" -- "$WORK/h2/story.md" ) >/dev/null 2>&1
  if cmp -s "$WORK/h2/.orig" "$WORK/h2/data.txt"; then
    ok "h2-$1            bash rewrites data.txt in place; the checker does not"
  else
    bad "h2-$1 REWROTE data.txt through the validator -- the in-place option was not refused: $2"
  fi
}
inplace_contained i-joined-nodot  "sed -ibak 's/a/b/' data.txt"
inplace_contained i-joined-letter "sed -iX 's/a/b/' data.txt"
inplace_contained i-bundled       "sed -nibak 's/a/b/' data.txt"
inplace_contained i-bundled-dot   "sed -ni.bak 's/a/b/' data.txt"
inplace_contained i-dot-suffix    "sed -i.bak 's/a/b/' data.txt"

# --- H3. THE FORMS BSD CANNOT RUN ARE ASSERTED BY VERDICT, NOT BY CANARY ------------------
# `W`, GNU's `e` command and the `s///e` flag DO NOT write or exec on the BSD sed this
# machine ships -- it exits 1 on each -- so `exec_contained`'s bash-runs-it control cannot
# fire and putting them there reports FIXTURE BROKEN. They are refused anyway because a
# CONSUMER may run GNU sed, where `e` is arbitrary execution. The observable is therefore
# the validator's own refusal message. `/alpha/w/p` is here for the opposite reason: it is
# a genuine write (to a file named `/p`) that only a command-position parser separates from
# the read-only `/w/p`, and on this machine it fails on the unwritable path rather than on
# the grammar.
sed_refused() { # $1 command  [$2 expected refusal text, default the write/exec one]
  mkdir -p "$WORK/h3"
  printf 'a\nb\nc\n' > "$WORK/h3/data.txt"
  { printf '```derived\n$ %s\n0\n```\n' "$1"; } > "$WORK/h3/story.md"
  out="$(vad_call "$VALIDATOR" AI_DLC_PROJECT_ROOT="$WORK/h3" -- "$WORK/h3/story.md" 2>&1)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "${2:-writes a file or runs a command}" <<< "$out"; then
    ok "h3-verdict             exit=1  refused by verdict ($1)"
  else
    bad "h3-verdict expected exit 1 naming the write/exec refusal for '$1', got $rc: $out"
  fi
}
sed_refused "sed -n 'W canary' data.txt"
sed_refused "sed '1e touch canary' data.txt"
sed_refused "sed 's/a/b/e' data.txt"
sed_refused "sed -n '/alpha/w/p' data.txt"
sed_refused "sed -n '/alpha/wp' data.txt"
# `--expression` is not on sed's option table, so the walker refuses it as unlisted before the
# script grammar reads its value; the arm asserts THAT refusal, which still names the option.
sed_refused "sed --expression='w canary' data.txt" "'sed --expression' is not an option this checker admits"
sed_refused "sed -n '\$w canary' data.txt"
sed_refused "sed -n '1,3w canary' data.txt"
sed_refused "sed -n '2!w canary' data.txt"
sed_refused "sed 's|a|b|w canary' data.txt"
sed_refused "sed 's/a/b/pw canary' data.txt"
sed_refused "sed --file=script.sed data.txt"
# NOT A VECTOR, and recorded so it is not seeded later as one: `sed -n 'w' canary data.txt`
# does NOT write. The script is the bare `w`, whose filename operand is missing, so `canary`
# is read as an INPUT file and sed exits 1. The predicate refuses it anyway -- a bare `w` in
# command position is a write verb whatever follows it -- but a canary arm for it would fail
# as a BROKEN CONTROL, because bash creates nothing.
sed_refused "sed -n 'w' canary data.txt"

# --- H4. THE MUST-ALLOW SET, ASSERTED BY VERDICT -----------------------------------------
# THE OVER-BROAD FIX IS THE ONE THIS ARM EXISTS TO KILL. A blanket `sed:*` deny closes the
# filed receipt and refuses every legitimate sed derivation in the reference corpus -- 1652
# of them measured by `fp-sweep.sh`. A canary cannot express "ran and was permitted", so the
# observable is the VERDICT: each of these must reproduce and exit 0, and the pair with a
# wrong recorded value must come back STALE so the green half is shown to have executed.
#
# THE `w` IS IN EVERY LEGITIMATE POSITION A REGEX CANNOT TELL FROM COMMAND POSITION: inside
# an address regex (`/w/p`), inside an s/// pattern (`s/wow/wew/`), inside a replacement
# (`s/x/\w/`), and inside a FILENAME. `-n '/w/p'` is the only read-only form of that shape --
# `/alpha/wp` writes a file named `p` and `/alpha/w/p` writes `/p`, both asserted above.
printf 'alpha\n  beta\nwow\nwidget\n' > "$WORK/src/w-forms.txt"
printf 'alpha\nwow\n'                 > "$WORK/src/has-w-in-name.txt"
sed_allowed() { # $1 label  $2 command  $3 true output  $4 wrong output
  mkdir -p "$WORK/h4"
  { printf '```derived\n$ %s\n%s\n```\n' "$2" "$3"; } > "$WORK/h4/$1-true.md"
  out="$(run "$WORK/h4/$1-true.md")"; rc=$?
  [ "$rc" -eq 0 ] && ok "h4-$1 (allowed)   exit=0  $2" \
    || bad "h4-$1 MUST BE ALLOWED and reproduce -- a blanket sed deny or a wrong grammar refuses it. got $rc: $out"
  { printf '```derived\n$ %s\n%s\n```\n' "$2" "$4"; } > "$WORK/h4/$1-stale.md"
  out="$(run "$WORK/h4/$1-stale.md")"; rc=$?
  [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" \
    && ok "h4-$1 (twin)      exit=1  STALE -- so the allowed half really executed" \
    || bad "h4-$1 twin must be STALE for '$2', got $rc: $out"
}
sed_allowed blank-strip "sed 's/^[[:blank:]]*//' src/w-forms.txt | wc -l"   "       4" 9
sed_allowed w-in-regex  "sed -n '/w/p' src/w-forms.txt | wc -l"            "       2" 9
sed_allowed w-in-pat    "sed 's/wow/WOW/' src/w-forms.txt | wc -l"         "       4" 9
sed_allowed w-in-repl   "sed 's/alpha/\\\\w/' src/w-forms.txt | wc -l"     "       4" 9
sed_allowed s-X-p       "sed -n 's/alph//p' src/w-forms.txt"               "a"       9
sed_allowed last-line-d "sed '\$d' src/w-forms.txt | wc -l"                "       3" 9
sed_allowed w-in-fname  "sed -n '2p' src/has-w-in-name.txt"                "wow"     9
sed_allowed y-transform "sed 'y/abc/xyz/' src/has-w-in-name.txt | wc -l"   "       2" 9
sed_allowed range-p     "sed -n '1,3p' src/w-forms.txt | wc -l"            "       3" 9
# NOT SEEDED HERE, and stated rather than left to be found: a `{` block and a `;`-joined
# script are both UNREACHABLE through this validator. The metacharacter ban refuses a `;`
# before any segment is scanned, and a literal newline splits the `$ ` line so the quote
# scanner refuses the fragment. The grammar models both positions -- `1{w canary<NL>}` and
# `p;;w canary` are in the exec set above by way of `bash -c`, where they ARE reachable --
# but a must-allow seed using either would be asserting about the ban, not about sed.
sed_allowed not-matched "sed -n '/ZZ_NO_SUCH/p' src/w-forms.txt | wc -l"    "       0" 9
# `-e` IS NOT REFUSED AS A FAMILY, and this is the arm that holds that open. A `-e` can carry
# a write verb (seeded as an exec arm above), so the tempting fix is to refuse the option --
# but the reference consumer's corpus carries 33 legitimate `-e` sed derivations and 0 `-f`
# ones, measured by `fp-sweep.sh`. `-f` is therefore refused outright while every `-e`
# argument is COLLECTED and scanned, and these two seeds fail the moment that inverts.
sed_allowed multi-e      "sed -n -e '1p' -e '3p' src/w-forms.txt | wc -l"    "       2" 9
sed_allowed joined-e     "sed -n -e'1p' src/w-forms.txt"                     "alpha"   9
# NOT SEEDED AS A MUST-ALLOW, and stated so the gap is visible rather than found: BSD sed
# rejects `--expression` outright (`illegal option -- -`, exit 1), so a green must-allow arm
# for it is unobtainable on this machine and a red one would assert about sed's option parser
# rather than about this grammar. `sed --expression='w canary'` IS in the verdict-refusal set
# above, which is the direction that matters -- the grammar collects a long-form script
# argument, and a consumer on GNU sed gets that coverage.
# AND THE ALTERNATE DELIMITERS MUST STAY ALLOWED when their flags are read-only. The write
# forms of the same spellings are exec arms above, so these two separate "parses alternate
# delimiters" from "refuses anything that is not `s/`".
sed_allowed s-pipe-delim "sed 's|wow|WOW|' src/w-forms.txt | wc -l"          "       4" 9
sed_allowed s-comma-del  "sed 's,wow,WOW,g' src/w-forms.txt | wc -l"         "       4" 9

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
# indent reproduces it -- the shed-all mutant fails THIS arm and no other. The stale twin
# records the bare digit and is STALE under both readers (the comparison runs against the
# unshed actual output); it is here so the green half is shown to have executed, not to
# discriminate the rule. The padding is produced by `printf '%8s'` rather than by `wc` itself
# so the pair holds on GNU platforms too, where `wc -l` pads nothing.
{ printf -- '- item\n\n  ```derived\n  $ %s\n  %s\n  ```\n' "printf '%8s\\n' 2" "       2"; } > "$WORK/i-pad-true.md"
out="$(run "$WORK/i-pad-true.md")"; rc=$?
[ "$rc" -eq 0 ] && ok "i-pad-true             exit=0  (indent shed EXACTLY: the output's own padding survives)" \
                || bad "i-pad-true expected exit 0 -- the reader is shedding more than the fence indent: $out"
{ printf -- '- item\n\n  ```derived\n  $ %s\n  %s\n  ```\n' "printf '%8s\\n' 2" "2"; } > "$WORK/i-pad-stale.md"
out="$(run "$WORK/i-pad-stale.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" \
  && ok "i-pad-stale            exit=1  STALE (the bare digit is not what the command printed)" \
  || bad "i-pad-stale expected exit 1 STALE, got $rc: $out"
# A `$ ` LINE INDENTED DEEPER THAN ITS FENCE IS OUTPUT, NOT A COMMAND. The shed form decides:
# under a two-space fence a six-space `$ x` sheds to four spaces and a dollar, which is not a
# command line, so it is the recorded output of the pair above it and the block holds ONE
# derivation. A reader shedding all leading blanks reads it as a second command and fails the
# block twice. The same shape closes the hook-side half of this property in derivation-capture.
{ printf -- '- item\n\n  ```derived\n  $ %s\n  %s\n  ```\n' "printf '      \$ x\\n'" "      \$ x"; } > "$WORK/i-deep-cmd.md"
out="$(run "$WORK/i-deep-cmd.md")"; rc=$?
[ "$rc" -eq 0 ] && grep -q '1 derivation(s) in 1 block(s)' <<< "$out" \
  && ok "i-deep-cmd             exit=0  one derivation (a deeper-indented \$ line is OUTPUT)" \
  || bad "i-deep-cmd expected exit 0 with 1 derivation -- a deeper \$ line was read as a command: $rc: $out"

# An unclosed INDENTED block is reported, not skipped -- E's arm has to reach this form too.
{ printf -- '- item\n\n  ```derived\n  $ grep -c needle src/two-needles.txt\n  2\n'; } > "$WORK/i-unclosed.md"
out="$(run "$WORK/i-unclosed.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'never closed' <<< "$out" \
  && ok "i-unclosed             exit=1  (an unclosed indented block is reported)" \
  || bad "i-unclosed expected exit 1 naming 'never closed', got $rc: $out"

# --- J. A PROSE LINE THAT BEGINS WITH THE TOKEN IS NOT AN OPENER --------------------
# The opener accepted `'```derived '*` -- any trailing text -- and over the reference
# consumer's 2795 openers that arm matched nothing but two wrapped SENTENCES whose
# continuation begins with the token. Each opened a phantom block that ran to the next real
# opener, read it as a closer, and left the real block's pairs outside any fence: three
# derivations silently unchecked in one file, found the moment the indent rule made the
# list-item form reachable. The stale twins are the arms -- a reader that swallows the real
# block reports 0 checked and exits 0 on both of them.
jemit() { # $1 file  $2 indent  $3 recorded-output
  { printf '# Story\n\n%sA sentence that wraps so its continuation begins with the fence token, so a\n' "$2"
    printf '%s```derived would promise a machine check the command cannot keep -- this claim stays unfenced.\n\n' "$2"
    printf '%s```derived\n%s$ grep -c needle src/two-needles.txt\n%s%s\n%s```\n' "$2" "$2" "$2" "$3" "$2"; } > "$1"
}
jemit "$WORK/j-col0-true.md" "" 2
out="$(run "$WORK/j-col0-true.md")"; rc=$?
[ "$rc" -eq 0 ] && grep -q '1 derivation(s) in 1 block(s)' <<< "$out" \
  && ok "j-col0-true            exit=0  and the REAL block after the prose line is counted" \
  || bad "j-col0-true expected exit 0 counting 1 block, got $rc: $out"
jemit "$WORK/j-col0-stale.md" "" 1
out="$(run "$WORK/j-col0-stale.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" \
  && ok "j-col0-stale           exit=1  STALE (the prose line opened nothing; the real block ran)" \
  || bad "j-col0-stale expected exit 1 STALE -- the prose line swallowed the real block: $rc: $out"
jemit "$WORK/j-ind-stale.md" "   " 1
out="$(run "$WORK/j-ind-stale.md")"; rc=$?
[ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" \
  && ok "j-ind-stale            exit=1  STALE (the same, wrapped inside a list item)" \
  || bad "j-ind-stale expected exit 1 STALE -- the indented prose line swallowed the real block: $rc: $out"

mkdir -p "$WORK/k"
VBASE="$(basename "$VALIDATOR")"

# --- THE ARM HARNESS --------------------------------------------------------------------------
# Every battery below (K through T, and the awk self-probe) is an ARM FUNCTION
# `<x>_arms <validator> <quiet>`. Run on the shipped validator with quiet 0 it prints each arm's ok
# line once; ARMS_RAN and ARMS_FAILED record which arms ran and which failed. WANT (space-separated
# arm ids; empty = every arm) names the only arms to run.
WANT=""; ARMS_RAN=""; ARMS_BAD=""; ARMS_FAILED=""; ARM_Q=0
want() { [ -z "$WANT" ] && return 0; local w_; for w_ in "$@"; do case " $WANT " in *" $w_ "*) return 0 ;; esac; done; return 1; }
sorted_set() { printf '%s\n' $* | sed '/^$/d' | LC_ALL=C sort -u | tr '\n' ' '; }
arm_begin() { ARMS_RAN=""; ARMS_BAD=""; ARM_Q="$1"; }
arm() { # $1 id  $2 status (0 = the arm holds)  $3 message  [$4 label to print in place of the id]
  ARMS_RAN="$ARMS_RAN $1"
  if [ "$2" -eq 0 ]; then [ "$ARM_Q" = 1 ] || ok "${4:-$1} $3"
  else ARMS_BAD="$ARMS_BAD $1"; [ "$ARM_Q" = 1 ] || bad "${4:-$1} $3 (rc=${rc:-?}): ${out:-}"; fi
}
arm_end() { ARMS_FAILED="$(sorted_set $ARMS_BAD)"; }

# bat_base <control label> <battery letter> -- called right after `<fn> "$VALIDATOR" 0`: the shipped
# validator must run the battery's arms and fail none of them.
bat_base() {
  local ran_
  ran_="$(sorted_set $ARMS_RAN)"
  if [ -z "$ran_" ]; then bad "$1 no $2 arm ran on the shipped validator -- nothing above is readable"
  elif [ -z "$ARMS_FAILED" ]; then ok "$1 the shipped validator fails no $2 arm"
  else bad "$1 the shipped validator failed $2 arm(s): $ARMS_FAILED"; fi
}

# --- K. THE WRITE FORM OF `sed` IS CONTAINED, AND THE MUST-ALLOW FORM IS NOT REFUSED ------------
# THE FILED RECEIPT IS CLOSED BY A BLANKET `sed:*` DENY, which refuses all 1652 legitimate
# sed derivations in the reference corpus. The two arms below separate that non-fix from the real
# one on the shipped validator: k-allow holds a must-allow `sed -n '/w/p'` and k-exec holds the
# write form `sed -n 'w canary'` contained.
mkdir -p "$WORK/k/m1w" "$WORK/k/m1e"
{ printf '```derived\n$ sed -n '"'"'/w/p'"'"' src/w-forms.txt | wc -l\n       2\n```\n'; } > "$WORK/k/m1w/story.md"
printf 'a\nb\nc\n' > "$WORK/k/m1e/data.txt"
{ printf '```derived\n$ sed -n '"'"'w canary'"'"' data.txt\n0\n```\n'; } > "$WORK/k/m1e/story.md"
k_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" kx
  arm_begin "$q"
  # k-allow: THE MUST-ALLOW HALF. The shipped validator ALLOWS the seed; without this the exec arm
  if want k-allow; then
    out="$(vad_call "$V" AI_DLC_PROJECT_ROOT="$WORK" -- "$WORK/k/m1w/story.md" 2>&1)"; rc=$?
    [ "$rc" -eq 0 ] && grep -q '^OK: 1 derivation' <<< "$out"
    arm k-allow $? "exit=0  the validator ALLOWS the must-allow \`sed -n '/w/p'\` (a blanket sed deny refuses it)"
  fi
  # k-exec: THE EXEC HALF. The write form of sed is contained: no canary file appears. Together with
  # the arm above it says a blanket deny is not what holds the boundary.
  if want k-exec; then
    rm -f "$WORK/k/m1e/canary"*
    ( cd "$WORK/k/m1e" && vad_call "$V" AI_DLC_PROJECT_ROOT="$WORK/k/m1e" -- "$WORK/k/m1e/story.md" ) >/dev/null 2>&1
    if ls "$WORK/k/m1e/canary"* >/dev/null 2>&1; then kx=1; else kx=0; fi
    rm -f "$WORK/k/m1e/canary"*
    out="canary-present=$kx"; rc=$kx
    arm k-exec "$kx" "the write form \`sed -n 'w canary'\` is contained: no canary file appears"
  fi
  arm_end
}
k_arms "$VALIDATOR" 0
bat_base "k-control" K


# --- L. A DERIVATION THAT READS STDIN DERIVES FROM NOTHING, AND MUST NOT SWALLOW THE REST ---
# run_pair is called inside check_file's `while read … done < "$f"`, so an eval that inherits
# stdin hands a stdin reader THE REST OF THE ARTIFACT. Measured before the fix: a first
# derivation `grep -c WRONG` (no file operand) read the later blocks, matched its recorded
# value, and the stale block after it was never checked -- exit 0, `OK: 1 derivation(s)`.
#
# THE RECORDED VALUE IS 0 ON PURPOSE. It is the correct answer over an EMPTY stdin, so a fix
# that merely closed stdin (`</dev/null`) passes the reader -- a derivation from nothing,
# reported OK. The validator hands the eval a one-line sentinel and refuses a consumed one as
# READS-STDIN; l-reader's READS-STDIN conjunct is what separates that from a bare close.
#
# EVERY ARM ASSERTS "2 checked" OR "2 derivation(s)", which is the swallow's observable: a
# validator whose later block went unread counts 1. A redirect placed outside the eval's
# subshell rather than on the eval is an equally valid fix and nothing here keys on where it
# sits -- every assertion is behavioural.
mkdir -p "$WORK/l"
lemit() { # $1 file  $2 first command  $3 its recorded output ("" = none)  $4 second block's recorded count
  { printf '# Story\n\n```derived\n$ %s\n' "$2"
    [ -n "$3" ] && printf '%s\n' "$3"
    printf '```\n\nAC2 -- a later claim, in its own block.\n\n'
    printf '```derived\n$ grep -c needle src/two-needles.txt\n%s\n```\n' "$4"; } > "$1"
}
lemit "$WORK/l/reader.md" "grep -c WRONG" 0 1
lemit "$WORK/l/pipe.md"   "grep needle src/two-needles.txt | wc -l" "       2" 2
lemit "$WORK/l/cat.md"    "cat" "" 2
l_run() { vad_call "$1" AI_DLC_PROJECT_ROOT="$WORK" -- "$2" 2>&1; } # $1 validator  $2 artifact
l_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" nfail
  arm_begin "$q"
  # l-reader: the stdin reader is refused BY NAME, and the stale block after it is still reported.
  if want l-reader l-reader-rest; then
    out="$(l_run "$V" "$WORK/l/reader.md")"; rc=$?
    [ "$rc" -eq 1 ] && grep -q 'FAIL (READS-STDIN)' <<< "$out"
    arm l-reader $? "exit=1  a first derivation reading stdin is refused as READS-STDIN"
    grep -q 'FAIL (STALE)' <<< "$out" && grep -q 'of 2 checked' <<< "$out"
    arm l-reader-rest $? "the stale block AFTER the reader is still checked (2 checked, STALE reported)"
  fi
  # l-pipe: the NEAR-MISS. A pipeline whose first stage names a file reads no stdin of its own;
  # its later stages read the pipe. It must not be flagged, and both blocks must reproduce.
  if want l-pipe; then
    out="$(l_run "$V" "$WORK/l/pipe.md")"; rc=$?
    [ "$rc" -eq 0 ] && grep -q '^OK: 2 derivation(s)' <<< "$out" && ! grep -q 'READS-STDIN' <<< "$out"
    arm l-pipe $? "exit=0  a pipeline whose first stage names a file is not flagged (2 reproduce)"
  fi
  # l-cat: `cat` first, then a TRUE block. READS-STDIN is the ONLY finding -- not STALE, which is
  # what `cat` over an inherited artifact or over the sentinel produces instead.
  if want l-cat; then
    out="$(l_run "$V" "$WORK/l/cat.md")"; rc=$?
    nfail="$(grep -c '^FAIL (' <<< "$out")" || nfail=0
    [ "$rc" -eq 1 ] && [ "$nfail" -eq 1 ] && grep -q 'FAIL (READS-STDIN)' <<< "$out" && grep -q 'of 2 checked' <<< "$out"
    arm l-cat $? "exit=1  \`cat\` first is READS-STDIN and nothing else; the true block after it passes"
  fi
  arm_end
}
l_arms "$VALIDATOR" 0
bat_base "l-control" L


# --- M. A DERIVATION THAT NEVER RAN IS UNRUN, NEVER STALE ----------------------------------
# The output file is empty both when a command printed nothing and when it never executed, and
# an empty actual against a recorded value scored STALE. On the base side of
# `derivation-differential.sh` that turned a real break into STALE-BOTH and the helper exited 0.
# The validator now reads a MARKER the subshell writes after eval returns, and any derivation
# whose marker is empty, or records SIGKILL/SIGTERM, makes the run exit 2 with an UNRUN line.
#
# THE FAULTS ARE FORCED, NEVER WAITED FOR, AND EACH TARGETS ONE COMMAND. `shasum` is on the
# allowlist and the validator itself never calls it, so a shim of it on PATH reaches the eval and
# nothing else:
#   m-kill-cmd   the shim SIGKILLs itself -- the command dies, the subshell survives (marker 137)
#   m-kill-sub   the shim SIGKILLs its parent, the eval subshell (marker empty)
# Each carries a TRUE recorded value, so the only way to exit 1 is to score the fault as STALE.
#
# THE NEAR-MISSES ARE THE STATUSES A REAL DERIVATION PRODUCES ON ITS OWN, and they are why no
# exit-status rule can replace the marker: `git show` on a missing ref exits 128 (a genuine
# fatal), and a `cat | head -1` over a large file exits 141 under the inherited `pipefail`. Both
# ran, both must be verdicts, and each has a twin that must come back STALE.
mkdir -p "$WORK/m/bin"
printf 'm-data\n' > "$WORK/src/m-data.txt"
mshim() { # $1 body of the shasum shim
  printf '#!/bin/bash\n%s\n' "$1" > "$WORK/m/bin/shasum"; chmod +x "$WORK/m/bin/shasum"
}
mrun() { # $1 validator  $2 story -> sets out, rc
  out="$(cd "$WORK" && vad_call "$1" PATH="$WORK/m/bin:$PATH" AI_DLC_PROJECT_ROOT="$WORK" -- "$2" 2>&1)"; rc=$?
}
{ printf '```derived\n$ shasum src/m-data.txt\nfeedface  src/m-data.txt\n```\n\n'
  printf '```derived\n$ grep -c needle src/two-needles.txt\n2\n```\n'; } > "$WORK/m/fault.md"

# The near-misses. git needs a repository for its fatal to be about the ref, not the cwd.
#
# THE 141 IS PRODUCED BY `awk ... exit 141`, NOT BY THE PIPE. A `cat | head -1` exits 141 only
# when SIGPIPE is at its default disposition. `git push` runs its hooks with SIGPIPE IGNORED, and
# bash cannot un-ignore a signal ignored on entry, so under the gate the writer gets EPIPE and the
# pipe exits 1 -- measured: plain run pipe=141, `trap "" PIPE; exec bash run.sh` pipe=1. A control
# pinned to the pipe's 141 was red under the gate and green by hand. The awk program is on the
# allowlist, needs no `;` (two BEGIN blocks), and exits 141 under either disposition, so the
# above-128-not-137/143 near-miss holds everywhere. The pipe is kept as a third near-miss with NO
# pinned status: whichever it produces, it ran, so it must be a verdict.
mkdir -p "$WORK/m/repo"
git -C "$WORK/m/repo" init -q 2>/dev/null
awk 'BEGIN { for (i = 0; i < 20000; i++) print "line-" i }' > "$WORK/m/repo/big.txt"
( cd "$WORK/m/repo" && awk 'BEGIN { print "line-0" } BEGIN { exit 141 }' >/dev/null ); arc=$?
( cd "$WORK/m/repo" && git show ZZ_NO_SUCH_REF_ZZ >/dev/null 2>&1 ); grc=$?
( cd "$WORK/m/repo" && set -o pipefail && cat big.txt | head -1 >/dev/null ); prc=$?
[ "$arc" -eq 141 ] && [ "$grc" -eq 128 ] \
  && ok "m-natural CONTROL      awk exits 141 and git 128 on their own, so the near-misses carry those statuses (pipe gave $prc here)" \
  || bad "m-natural CONTROL the near-misses do not produce the statuses they stand for (awk=$arc git=$grc)"
[ "$prc" -ne 0 ] \
  && ok "m-natural pipe         the pipe near-miss exits non-zero ($prc) on its own, so it is a status a derivation produced" \
  || bad "m-natural pipe the cat|head near-miss exited 0, so it no longer carries a non-zero status of its own"
# M-UNBOUND. The validator's own `set -u` used to reach the eval subshell, abort it on an unbound
# `$VAR` before the marker was written, and score an ordinary stale derivation UNRUN, exit 2. The
# capture hook then read that 2 as infrastructure and hid every real STALE in the same write. The
# quote scan now refuses every `$` bash expands (section S carries one arm per class), so no name
# reaches the eval at all, and each seed below is an ALLOWLIST refusal, exit 1, never UNRUN:
#   m-unbound-stale  `grep -c "needle$FILE_ZZ_UNSET"` recording a wrong 9
#   m-unbound-true   the same command recording its true 2 -- refused all the same
#   m-arith          `$[1/0]`, arithmetic
M_DOLLAR='it carries a $ that bash expands'
[ -z "${FILE_ZZ_UNSET+x}" ] \
  && ok "m-unbound CONTROL      FILE_ZZ_UNSET is unset in this environment, so the seeds are about an unbound name" \
  || bad "m-unbound CONTROL FILE_ZZ_UNSET is set, so no unbound arm below is about an unbound variable"
printf '```derived\n$ grep -c "needle$FILE_ZZ_UNSET" src/two-needles.txt\n9\n```\n' > "$WORK/m/unbound-stale.md"
printf '```derived\n$ grep -c "needle$FILE_ZZ_UNSET" src/two-needles.txt\n2\n```\n' > "$WORK/m/unbound-true.md"
printf '```derived\n$ grep -c "needle$[1/0]" src/two-needles.txt\n2\n```\n' > "$WORK/m/arith.md"
# EACH ARM SETS THE SHIM IT NEEDS ITSELF, because the shim is one file on the eval's PATH and the
# arms run in any subset.
m_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" mu
  arm_begin "$q"
  munrun() { # $1 arm id  $2 validator
    mrun "$2" "$WORK/m/fault.md"
    [ "$rc" -eq 2 ] && grep -q '^UNRUN: .*fault.md:2 ' <<< "$out" && grep -q '^REFUSED: 1 derivation' <<< "$out" \
      && ! grep -q 'FAIL (STALE)' <<< "$out"
    arm "$1" $? "exit=2  UNRUN names the derivation; no STALE was scored"
  }
  # POSITIVE CONTROL for the shim itself: with a shim that prints the recorded line, the SAME file
  # reproduces. Without it, UNRUN below could be the shim failing to be found at all.
  if want m-control; then
    mshim 'echo "feedface  src/m-data.txt"'
    mrun "$V" "$WORK/m/fault.md"
    [ "$rc" -eq 0 ] && grep -q '^OK: 2 derivation' <<< "$out"
    arm m-control $? "exit=0  the shasum shim is on the eval's PATH and the file reproduces"
  fi
  if want m-kill-cmd; then mshim 'kill -9 $$'; munrun m-kill-cmd "$V"; fi
  if want m-kill-sub; then mshim 'kill -9 $PPID'; munrun m-kill-sub "$V"; fi
  mnear_arm() { # $1 label  $2 command  $3 true output ("" = none)  $4 wrong output
    if want "m-$1-verdict"; then
      { printf '```derived\n$ %s\n' "$2"; [ -n "$3" ] && printf '%s\n' "$3"; printf '```\n'; } > "$WORK/m/repo/$1-true.md"
      out="$(cd "$WORK/m/repo" && vad_call "$V" AI_DLC_PROJECT_ROOT="$WORK/m/repo" -- "$WORK/m/repo/$1-true.md" 2>&1)"; rc=$?
      [ "$rc" -eq 0 ] && ! grep -q 'UNRUN' <<< "$out"
      arm "m-$1-verdict" $? "  exit=0  a status the command produced itself is not UNRUN" "m-$1 (verdict)"
    fi
    if want "m-$1-twin"; then
      { printf '```derived\n$ %s\n%s\n```\n' "$2" "$4"; } > "$WORK/m/repo/$1-stale.md"
      out="$(cd "$WORK/m/repo" && vad_call "$V" AI_DLC_PROJECT_ROOT="$WORK/m/repo" -- "$WORK/m/repo/$1-stale.md" 2>&1)"; rc=$?
      [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" && ! grep -q 'UNRUN' <<< "$out"
      arm "m-$1-twin" $? "  exit=1  STALE, not UNRUN -- the verdict path is live" "m-$1 (twin)"
    fi
  }
  mnear_arm git-128  "git show ZZ_NO_SUCH_REF_ZZ"                          ""       "9"
  mnear_arm awk-141  "awk 'BEGIN { print \"line-0\" } BEGIN { exit 141 }'" "line-0" "9"
  mnear_arm pipe     "cat big.txt | head -1"                               "line-0" "9"
  for mu in unbound-stale unbound-true arith; do
    want "m-$mu" || continue
    mrun "$V" "$WORK/m/$mu.md"
    [ "$rc" -eq 1 ] && grep -q "^FAIL (ALLOWLIST): .*$mu.md:2 " <<< "$out" && grep -qF "$M_DOLLAR" <<< "$out" \
      && ! grep -q 'UNRUN' <<< "$out" && ! grep -q 'FAIL (STALE)' <<< "$out"
    arm "m-$mu" $? "exit=1  an expanding \$ is an ALLOWLIST refusal, never UNRUN or STALE"
  done
  arm_end
}
m_arms "$VALIDATOR" 0
bat_base "m-control-arms" M


# --- N. A COMPARISON OR A WALK THAT COULD NOT RUN IS A REFUSAL, NEVER A VERDICT ------------------
# Three verdict-bearing steps AROUND the derivation used to discard their own status:
#   - the comparison was `if ! diff -q <(norm ...) <(norm ...)`, so `diff` exiting 2 -- bash 3.2's
#     `/dev/fd/63: Bad file descriptor` under concurrent workers -- took the `!` branch and a TRUE
#     derivation scored STALE, exit 1, which the gate sends to a remediator;
#   - `norm` (two `sed` stages) ran inside those substitutions, so a failing `sed` emptied BOTH
#     sides and a STALE derivation compared equal: OK, exit 0, a silent false clear;
#   - a directory target was walked by `done < <(find ...)`, so a failing `find` read as an empty
#     directory: `OK: 0 derivation(s)`, exit 0.
# Each is FORCED here with a PATH stub, never sampled. The seed command is `grep -c`, never `diff`,
# `sed` or `find`, so no stub can leak into the derivation itself and move its output.
#
# EVERY STUB ARM HAS A PASS-THROUGH TWIN in the same world: the same stub file, writing the same
# sentinel, but handing the call to the real binary. The twin must reach the ordinary verdict and
# leave its sentinel -- which proves the stub is on the validator's PATH and is reached by the step
# under test, so the failing arm is about that step and not about a stub nobody called.
#
# THE ARMS ARE A FUNCTION OF THE VALIDATOR, and each fails only the step it names: an arm that fails
# an arm it does not own means two arms are entangled.
N="$WORK/n"
mkdir -p "$N/nostub" "$N/dir"
printf 'nn\nxx\nnn\n' > "$WORK/src/n-data.txt"
{ printf '```derived\n$ grep -c nn src/n-data.txt\n2\n```\n'; } > "$N/good.md"
{ printf '```derived\n$ grep -c nn src/n-data.txt\n7\n```\n'; } > "$N/stale.md"
{ printf '```derived\n$ grep -c nn src/n-data.txt\n2\n```\n'; } > "$N/dir/good.md"
REAL_DIFF="$(command -v diff)"; REAL_SED="$(command -v sed)"; REAL_FIND="$(command -v find)"
[ -n "$REAL_DIFF" ] && [ -n "$REAL_SED" ] && [ -n "$REAL_FIND" ] \
  || { echo "FIXTURE ERROR: diff, sed or find is not on PATH, so no stub below can pass through" >&2; exit 2; }
# nstub <dir> <tool> <real path> <fail: 1|0> <sed args that fail, or empty = every call>
# The stub appends one line to <dir>/SENT per call it CLAIMS (fails, or would have failed in the
# pass-through twin), then fails or execs the real tool.
nstub() {
  local d="$1" tool="$2" real="$3" failing="$4" match="$5" act
  mkdir -p "$d"; : > "$d/SENT"
  if [ "$failing" = 1 ]; then act='echo "'"$tool"': forced failure" >&2; exit 2'; else act=':'; fi
  [ "$tool" = find ] && [ "$failing" = 1 ] && act='echo "find: forced failure" >&2; exit 1'
  {
    printf '#!/bin/bash\n'
    if [ -n "$match" ]; then
      printf 'case "$*" in\n  %s) echo "$*" >> "%s/SENT"; %s ;;\nesac\n' "$match" "$d" "$act"
    else
      printf 'echo "$*" >> "%s/SENT"; %s\n' "$d" "$act"
    fi
    printf 'exec "%s" "$@"\n' "$real"
  } > "$d/$tool"
  chmod +x "$d/$tool"
}
nstub "$N/diff-fail" diff "$REAL_DIFF" 1 ""
nstub "$N/diff-pass" diff "$REAL_DIFF" 0 ""
# Only norm's two exact scripts fail. The allowlist scan and the STALE message call sed too, with
# other scripts, and must keep working, or the arm would be about them.
nstub "$N/sed-fail"  sed  "$REAL_SED"  1 "'s/[[:space:]]*\$//'|'/^\$/d'"
nstub "$N/sed-pass"  sed  "$REAL_SED"  0 "'s/[[:space:]]*\$//'|'/^\$/d'"
nstub "$N/find-fail" find "$REAL_FIND" 1 ""
nstub "$N/find-pass" find "$REAL_FIND" 0 ""
# ONE SIDE OF THE COMPARISON AT A TIME. The stubs above fail norm on EVERY call, so the recorded
# side's check fires first and the actual side's check is never reached -- a build that drops only
# that second check passes every arm above, and it is a real false clear: recorded output empty,
# actual output non-empty, the actual side's norm failing, both staged files empty, `OK`, exit 0.
# This stub fails norm only when its INPUT is non-empty, so which side fails is chosen by the seed
# rather than by call order (a norm spelled as one `sed -e ... -e ...` is reached the same way):
#   act.md  recorded EMPTY, actual `2`  -> only the ACTUAL side's norm fails
#   rec.md  recorded `2`, actual EMPTY  -> only the RECORDED side's norm fails
# Each is STALE under the pass-through twin, and the twin's sentinel proves the non-empty side
# reached the stub -- for act.md that is the second norm call, the one under test.
{ printf '```derived\n$ grep -c nn src/n-data.txt\n```\n'; } > "$N/act.md"
{ printf '```derived\n$ grep ZZ_NO_SUCH_ZZ src/n-data.txt\n2\n```\n'; } > "$N/rec.md"
nstub_side() { # <dir> <fail: 1|0> -- claims only norm calls whose stdin is non-empty
  local d="$1" act=':'
  mkdir -p "$d"; : > "$d/SENT"
  [ "$2" = 1 ] && act='echo "sed: forced failure" >&2; rm -f "$t"; exit 2'
  {
    printf '#!/bin/bash\n'
    printf 'case "$*" in\n'
    printf "  's/[[:space:]]*\$//'|'/^\$/d')\n"
    printf '    t="$(mktemp)" || exit 3; cat > "$t"\n'
    printf '    if [ -s "$t" ]; then echo "$*" >> "%s/SENT"; %s; fi\n' "$d" "$act"
    printf '    "%s" "$@" < "$t"; r=$?; rm -f "$t"; exit $r ;;\n' "$REAL_SED"
    printf 'esac\n'
    printf 'exec "%s" "$@"\n' "$REAL_SED"
  } > "$d/sed"
  chmod +x "$d/sed"
}
nstub_side "$N/side-fail" 1
nstub_side "$N/side-pass" 0

nrun() { # $1 validator  $2 stub dir  $3 target -> sets out, rc
  : > "$2/SENT" 2>/dev/null
  out="$(cd "$WORK" && vad_call "$1" PATH="$2:$PATH" AI_DLC_PROJECT_ROOT="$WORK" -- "$3" 2>&1)"; rc=$?
}
sent() { [ -s "$1/SENT" ]; }
# n_arms <validator> <quiet> -> ARMS_FAILED. Each group is one validator invocation and gates on the
# arm ids it carries.
n_arms() {
  local V="$1" q="$2"
  arm_begin "$q"
  # CONTROL: the pass-through diff stub is reached by the comparison and the file reproduces.
  if want n-diff-ctl; then
    nrun "$V" "$N/diff-pass" "$N/good.md"
    [ "$rc" -eq 0 ] && grep -q '^OK: 1 derivation' <<< "$out" && sent "$N/diff-pass"
    arm n-diff-ctl $? "      exit=0  a pass-through diff stub is reached by the comparison and the derivation reproduces"
  fi
  # THE SUBJECT: diff exits 2 on a derivation that reproduces.
  if want n-diff-verdict n-diff-names; then
    nrun "$V" "$N/diff-fail" "$N/good.md"
    [ "$rc" -eq 2 ] && ! grep -q 'STALE' <<< "$out" && grep -q '^REFUSED: 1 derivation' <<< "$out" && sent "$N/diff-fail"
    arm n-diff-verdict $? "  exit=2  diff exiting 2 on a TRUE derivation is a refusal, never STALE"
    grep -q '^UNRUN: .*/n/good\.md:2 ' <<< "$out"
    arm n-diff-names $? "    the UNRUN line names the derivation as <file>:<line>"
  fi
  # THE CONTROL THAT THE ARMS CAN SEE A STALE: the real diff on a genuinely stale derivation.
  if want n-stale; then
    nrun "$V" "$N/nostub" "$N/stale.md"
    [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" && grep -q 'recorded: 7' <<< "$out" \
      && grep -q 'actual:   2' <<< "$out" && ! grep -q '^UNRUN' <<< "$out"
    arm n-stale $? "         exit=1  a genuinely stale derivation is STALE under the real diff"
  fi
  # CONTROL: the pass-through sed stub is reached by norm and the stale derivation is still STALE.
  if want n-sed-ctl; then
    nrun "$V" "$N/sed-pass" "$N/stale.md"
    [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" && sent "$N/sed-pass"
    arm n-sed-ctl $? "       exit=1  a pass-through sed stub is reached by norm and STALE still reads STALE"
  fi
  # THE SUBJECT: norm fails on a STALE derivation. Before, both sides were empty and compared equal.
  if want n-sed n-sed-names; then
    nrun "$V" "$N/sed-fail" "$N/stale.md"
    [ "$rc" -eq 2 ] && grep -q '^UNRUN: ' <<< "$out" && ! grep -q '^OK:' <<< "$out" \
      && ! grep -q 'STALE' <<< "$out" && sent "$N/sed-fail"
    arm n-sed $? "           exit=2  a failing norm is UNRUN, never OK and never STALE"
    grep -q '^UNRUN: .*/n/stale\.md:2 ' <<< "$out"
    arm n-sed-names $? "     the UNRUN line names the derivation as <file>:<line>"
  fi
  # CONTROL: the side-keyed pass-through stub sees the ACTUAL side (the only non-empty input).
  if want n-sed-act-ctl; then
    nrun "$V" "$N/side-pass" "$N/act.md"
    [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" && grep -q 'actual:   2' <<< "$out" && sent "$N/side-pass"
    arm n-sed-act-ctl $? "   exit=1  the side-keyed stub is reached by the ACTUAL side's norm and the empty record is STALE"
  fi
  # THE SUBJECT: only the actual side's norm fails, with the recorded output empty.
  if want n-sed-act; then
    nrun "$V" "$N/side-fail" "$N/act.md"
    [ "$rc" -eq 2 ] && grep -q '^UNRUN: .*/n/act\.md:2 ' <<< "$out" && ! grep -q '^OK:' <<< "$out" \
      && ! grep -q 'STALE' <<< "$out" && sent "$N/side-fail"
    arm n-sed-act $? "       exit=2  the ACTUAL side's norm failing is UNRUN naming <file>:<line>, never OK"
  fi
  # CONTROL, mirrored: the same stub sees only the RECORDED side when the actual output is empty.
  if want n-sed-rec-ctl; then
    nrun "$V" "$N/side-pass" "$N/rec.md"
    [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out" && grep -q 'recorded: 2' <<< "$out" && sent "$N/side-pass"
    arm n-sed-rec-ctl $? "   exit=1  the side-keyed stub is reached by the RECORDED side's norm and the empty actual is STALE"
  fi
  if want n-sed-rec; then
    nrun "$V" "$N/side-fail" "$N/rec.md"
    [ "$rc" -eq 2 ] && grep -q '^UNRUN: .*/n/rec\.md:2 ' <<< "$out" && ! grep -q '^OK:' <<< "$out" \
      && ! grep -q 'STALE' <<< "$out" && sent "$N/side-fail"
    arm n-sed-rec $? "       exit=2  the RECORDED side's norm failing is UNRUN naming <file>:<line>, never OK"
  fi
  # CONTROL: the pass-through find stub walks the directory and finds its one derivation.
  if want n-find-ctl; then
    nrun "$V" "$N/find-pass" "$N/dir"
    [ "$rc" -eq 0 ] && grep -q '^OK: 1 derivation' <<< "$out" && sent "$N/find-pass"
    arm n-find-ctl $? "      exit=0  a pass-through find stub walks the directory and finds 1 derivation"
  fi
  # THE SUBJECT: the walk fails on a directory target. Before: `OK: 0 derivation(s)`, exit 0.
  if want n-find; then
    nrun "$V" "$N/find-fail" "$N/dir"
    [ "$rc" -eq 2 ] && grep -q "^REFUSED: could not list the markdown files under $N/dir " <<< "$out" \
      && ! grep -q '^OK:' <<< "$out" && sent "$N/find-fail"
    arm n-find $? "          exit=2  a failed walk of a directory target is REFUSED naming it, never OK: 0"
  fi
  arm_end
}
n_arms "$VALIDATOR" 0

bat_base "n-control" N

# --- O. A `--stat` GRAPH IS A FACT ABOUT THE TREE, NOT ABOUT THE INVOKER'S TERMINAL ---------------
# `git diff --stat` scales its +/- graph to COLUMNS even with no tty. Before the pin, a block
# recorded at one width read STALE whenever the validator ran at another: the same tree, the same
# artifact, a verdict decided by the invoking shell. The world is its OWN repo, never $WORK, so no
# other arm's `cd "$AI_DLC_ROOT"` meets a repository it was not seeded against. COLUMNS is set
# explicitly on every invocation here: the preamble scrubs GIT_* and AI_DLC_*, not COLUMNS, so an
# unset one would leak the operator's terminal into the verdict.
O="$WORK/o"
mkdir -p "$O/w"
( cd "$O/w" && git init -q . && git config user.email o@o && git config user.name o \
  && printf 'x\n' > big.txt && git add big.txt && git commit -qm one ) >/dev/null 2>&1
awk 'BEGIN { for (i = 0; i < 200; i++) print "line " i }' >> "$O/w/big.txt"
( cd "$O/w" && git add big.txt && git commit -qm two ) >/dev/null 2>&1
o_stat() { ( cd "$O/w" && COLUMNS="$1" git diff --stat HEAD~1 HEAD ); }
O80="$(o_stat 80)"; O200="$(o_stat 200)"; O60="$(o_stat 60)"
# THE SEED MUST EXPRESS THE DEFECT: at 200 columns the graph must be a different text, or both
# halves below pass against an unpinned validator and the arm proves nothing.
if [ -n "$O80" ] && [ "$O80" != "$O200" ] && [ "$O80" != "$O60" ]; then
  ok "o-seed                 the 200-line change draws a different --stat graph at 60, 80 and 200 columns"
else
  bad "o-seed the seeded diff does not scale with COLUMNS (80 agrees with 200 or 60, or is empty) -- O cannot discriminate"
fi
o_emit() { # $1 file  $2 recorded output
  { printf '```derived\n$ git diff --stat HEAD~1 HEAD\n%s\n```\n' "$2"; } > "$1"
}
o_emit "$O/true.md" "$O80"
o_emit "$O/at60.md" "$O60"
o_emit "$O/stale.md" "$(printf '%s\n' "$O80" | sed 's/ \([0-9][0-9]*\) insertion/ 9\1 insertion/')"
o_run() { # $1 validator  $2 artifact  $3 COLUMNS -- a width the block was NOT recorded at
  out="$(vad_call "$1" COLUMNS="$3" AI_DLC_PROJECT_ROOT="$O/w" -- "$2" 2>&1)"; rc=$?
}
o_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" _w
  arm_begin "$q"
  for _w in 200 40; do
    want "o-width-$_w" || continue
    o_run "$V" "$O/true.md" "$_w"
    [ "$rc" -eq 0 ] && grep -q '^OK: 1 derivation' <<< "$out"
    arm "o-width-$_w" $? "exit=0  recorded at COLUMNS=80, validated at COLUMNS=$_w, reproduces" "o-width-$_w          "
  done
  # The twins: the same command with a record the pinned run cannot reproduce. Without them the arms
  # above pass against a validator that stopped comparing. One records a genuinely wrong insertion
  # count; the other was recorded at 60 columns, which the pin does not rescue -- the pin fixes the
  # width, it does not make the graph width-blind.
  if want o-stale; then
    if [ "$(cat "$O/stale.md")" != "$(cat "$O/true.md")" ]; then
      o_run "$V" "$O/stale.md" 200
      [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out"
      arm o-stale $? "exit=1  the same block with a wrong insertion count is still STALE" "o-stale               "
    else
      rc=99; out="the twin's count edit matched nothing"; arm o-stale 1 "no stale twin was seeded"
    fi
  fi
  if want o-at60; then
    o_run "$V" "$O/at60.md" 200
    [ "$rc" -eq 1 ] && grep -q 'FAIL (STALE)' <<< "$out"
    arm o-at60 $? "exit=1  a block recorded at COLUMNS=60 stays STALE under the pin" "o-at60                "
  fi
  arm_end
}
o_arms "$VALIDATOR" 0
bat_base "o-control" O

# --- P. A DIRECTORY TARGET WALKS THE LIVE SET; FROZEN RECORDS ARE SKIPPED, VISIBLY ------------
# `_gate-procedures.md` used to re-run this validator over `s<N>/` after every repair join; it now
# names FILE targets (the joined repair record, the assembled document, `.memlog.md`), and a
# directory target is for a human or a sweep. The slot also holds records no remediator may edit -- seats,
# parts and section copies under `shards/`, review and repair records -- and a stale command in
# one of those kept the required run at exit 1 for the rest of the sprint (the reference
# consumer's s319: 12 stale in 27 files, all in seat and part records). So a directory target
# skips them by path and says how many; `--all` walks them; a FILE target is never skipped,
# because the differential and the capture hook pass files. This REDUCES the slot run; the
# input digests, `changelog-*` and record-like names core does not write stay walked, and the
# validator's walk comment says why.
#
# The slot below is s319's SHAPE: one live document and the carry-over evaluation, clean, plus a
# stale fence in a member of every frozen class the walk names. The near-misses carry the record
# grammar OUTSIDE a slot (the area root), and the slot's documents.
P="$WORK/p"; mkdir -p "$P/.claude" "$P/src"
printf 'x\nx\n' > "$P/src/two.txt"
PS=_bmad-output/planning-artifacts/s319
pfence() { mkdir -p "$(dirname "$P/$1")"; printf '# r\n\n```derived\n$ grep -c x src/two.txt\n%s\n```\n' "$2" > "$P/$1"; }
pfence "$PS/architecture-impact.md" 2
pfence "$PS/carry-over-evaluation.md" 2
# A Rule 24 digest is LIVE: repairs edit digests, so the walk keeps it (near-miss to the records).
pfence "$PS/requirements-context.md" 2
P_FROZEN="shards/coe-p1/1.md shards/requirements-elicitation/cross-1.md shards/prd-repair-p1/sections/2.md
  coe-adversarial-p1.md carry-over-evaluation-party-repair-p1.md gate-planning-repair-p2.md
  requirements-party-repair.md requirements-elicitation-repair.md requirements-elicitation.md"
for _f in $P_FROZEN; do pfence "$PS/$_f" 9; done
P_NFROZEN="$(printf '%s\n' $P_FROZEN | grep -c .)"
# Near-miss: the record grammar at the AREA root is not in a slot, so it is walked.
pfence _bmad-output/planning-artifacts/prd-repair-p1.md 2

prun() { # $1 validator  $2.. args -> out, rc
  local v="$1"; shift
  out="$(cd "$P" && vad_call "$v" AI_DLC_PROJECT_ROOT="$P" -- "$@" 2>&1)"; rc=$?
}
p_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" total seen exc
  arm_begin "$q"
  # p-frozen: every stale fence is in a frozen record; the live set is clean -> exit 0, visibly.
  # p-count reads the SAME run, so the two share one invocation.
  if want p-frozen p-count; then
    prun "$V" "$PS/"
    [ "$rc" -eq 0 ] && grep -q "^EXCLUDED: $P_NFROZEN frozen file(s) under $PS/ " <<< "$out" \
      && grep -q '^OK: 3 derivation(s) in 3 block(s) across 3 file(s)' <<< "$out"
    arm p-frozen $? "        exit=0  stale only in shards/ and records: $P_NFROZEN EXCLUDED, the 3 live files (a digest among them) reproduce" "p-frozen"
    # p-count: what was excluded plus what was walked is every .md under the target.
    total="$(find "$P/$PS" -type f -name '*.md' | grep -c .)" || total=0
    exc="$(sed -n 's/^EXCLUDED: \([0-9]*\) .*/\1/p' <<< "$out")"; seen="$(sed -n 's/.* across \([0-9]*\) file(s).*/\1/p' <<< "$out")"
    [ -n "$exc" ] && [ -n "$seen" ] && [ "$((exc + seen))" -eq "$total" ] && [ "$total" -gt 3 ]
    arm p-count $? "         EXCLUDED (${exc:-?}) + walked (${seen:-?}) = every .md under the slot ($total)" "p-count"
  fi
  # p-all: --all walks the frozen records too -> every one of them is stale.
  if want p-all; then
    prun "$V" --all "$PS/"
    [ "$rc" -eq 1 ] && grep -q "^FAIL: $P_NFROZEN stale or unrunnable derivation(s) of $((P_NFROZEN + 3)) checked" <<< "$out" \
      && ! grep -q '^EXCLUDED:' <<< "$out"
    arm p-all $? "           exit=1  --all walks all $((P_NFROZEN + 3)) files and fails the $P_NFROZEN frozen ones" "p-all"
  fi
  # p-file: a frozen record named as a FILE is never excluded.
  if want p-file; then
    prun "$V" "$PS/shards/coe-p1/1.md"
    [ "$rc" -eq 1 ] && grep -q '^FAIL: 1 stale or unrunnable derivation(s) of 1 checked' <<< "$out"
    arm p-file $? "          exit=1  a shard part named as a FILE target is checked, never excluded" "p-file"
  fi
  # p-shardtarget: a target that IS a shard dir is walked; the component counts only BELOW it.
  if want p-shardtarget; then
    prun "$V" "$PS/shards/coe-p1/"
    [ "$rc" -eq 1 ] && grep -q '^FAIL: 1 stale or unrunnable derivation(s) of 1 checked' <<< "$out"
    arm p-shardtarget $? "   exit=1  a shards/ dir named as the target is walked, never read as OK: 0" "p-shardtarget"
  fi
  # p-area: the AREA as target skips the same slot records and walks the area-root near-miss.
  if want p-area; then
    prun "$V" _bmad-output/planning-artifacts/
    [ "$rc" -eq 0 ] && grep -q "^EXCLUDED: $P_NFROZEN frozen file(s)" <<< "$out" \
      && grep -q '^OK: 4 derivation(s) in 4 block(s) across 4 file(s)' <<< "$out"
    arm p-area $? "          exit=0  the area target skips the same $P_NFROZEN and walks the area-root prd-repair-p1.md" "p-area"
  fi
  # p-live: the SAME tree with the live document stale -> exit 1. Restored after.
  if want p-live; then
    pfence "$PS/architecture-impact.md" 3
    prun "$V" "$PS/"
    [ "$rc" -eq 1 ] && grep -q '^FAIL: 1 stale or unrunnable derivation(s) of 3 checked' <<< "$out" \
      && grep -q "FAIL (STALE): $PS/architecture-impact.md:4" <<< "$out"
    arm p-live $? "          exit=1  a stale LIVE document in the slot still fails, named" "p-live"
    pfence "$PS/architecture-impact.md" 2
  fi
  arm_end
}
p_arms "$VALIDATOR" 0
bat_base "p-control" P

# --- Q. A RECORD'S LATER BYTE-IDENTICAL RE-DERIVATION SUPERSEDES ITS EARLIER FENCE --------------
# A review or repair record is append-only, so a stale figure is re-derived by writing the same
# command again further down. Measured on the reference consumer's s319 `requirements-repair-p1.md`:
# 9 stale of 105, every one re-derived in a later block, and the record still failed. So inside a
# record (the walk's own record grammar) an earlier `$ ` command is skipped when a LATER command
# line in the same file is byte-identical, and the skip is printed as `SUPERSEDED: <f>:<n> by
# <f>:<m>`. The later copy runs and its verdict stands.
#
# WHAT IT MUST NOT ACQUIT, each its own world and each held at exit 1 with its FAIL named: a later
# copy that is itself stale, the same text in a LIVE document, a record-named file OUTSIDE
# `s<digits>/`, a later command that differs by one byte, a stale fence with no later copy at all,
# and a stale fence whose only "later copies" sit in a `text` fence, in prose, or as an output line
# indented deeper than its fence -- the block grammar reads none of those as a command.
#
# Its own tree, so the P arms' slot counts are not moved.
Q="$WORK/q"; mkdir -p "$Q/.claude" "$Q/src"
printf 'x\nx\n' > "$Q/src/two.txt"
printf 'x\nx\n' > "$Q/src/tw0.txt"
QS=_bmad-output/planning-artifacts/s320
qtwo() { # $1 path  $2 early recorded  $3 later command  $4 later recorded -- the s319 shape, lines 4 and 11
  mkdir -p "$(dirname "$Q/$1")"
  printf '# r\n\n```derived\n$ grep -c x src/two.txt\n%s\n```\n\nRe-derived after the edit.\n\n```derived\n$ %s\n%s\n```\n' \
    "$2" "$3" "$4" > "$Q/$1"
}
qtwo "$QS/prd-repair-p1.md" 9 'grep -c x src/two.txt' 2                       # supersedes
qtwo "$QS/coe-adversarial-p1.md" 9 'grep -c x src/two.txt' 7                  # the later copy is stale too
qtwo "$QS/prd.md" 9 'grep -c x src/two.txt' 2                                 # a LIVE document
qtwo _bmad-output/planning-artifacts/prd-repair-p1.md 9 'grep -c x src/two.txt' 2   # a record name outside a slot
qtwo "$QS/architecture-repair-p1.md" 9 'grep -c x src/tw0.txt' 2              # one byte different
mkdir -p "$Q/$QS"
printf '# r\n\n```derived\n$ grep -c x src/two.txt\n9\n```\n' > "$Q/$QS/stories-repair-p1.md"   # no later copy
cat > "$Q/$QS/epics-repair-p1.md" <<'QTEXT'
# r

```derived
$ grep -c x src/two.txt
9
```

```text
$ grep -c x src/two.txt
```

$ grep -c x src/two.txt

- item

  ```derived
  $ printf '    $ grep -c x src/two.txt\n'
      $ grep -c x src/two.txt
  ```
QTEXT

qrun() { # $1 validator  $2.. args -> out, rc
  local v="$1"; shift
  out="$(cd "$Q" && vad_call "$v" AI_DLC_PROJECT_ROOT="$Q" -- "$@" 2>&1)"; rc=$?
}
q_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" f nsup
  arm_begin "$q"
  # q-sup: the earlier stale copy is superseded by the later reproducing one -> exit 0, ONE
  # SUPERSEDED line keyed exactly as a FAIL line is, and only the later copy counted.
  if want q-sup; then
    f="$QS/prd-repair-p1.md"; qrun "$V" "$f"
    nsup="$(grep -c '^SUPERSEDED: ' <<< "$out")" || nsup=0
    [ "$rc" -eq 0 ] && [ "$nsup" -eq 1 ] && grep -qxF "SUPERSEDED: $f:4 by $f:11" <<< "$out" \
      && grep -q '^OK: 1 derivation(s) in 2 block(s) across 1 file(s)' <<< "$out"
    arm q-sup $? "           exit=0  the earlier stale copy is SUPERSEDED by its later byte-identical copy, which runs" "q-sup"
  fi
  # q-laterstale: the later copy is stale too -> its FAIL stands; supersession hides no failure.
  if want q-laterstale; then
    f="$QS/coe-adversarial-p1.md"; qrun "$V" "$f"
    [ "$rc" -eq 1 ] && grep -qxF "SUPERSEDED: $f:4 by $f:11" <<< "$out" \
      && grep -q "^FAIL (STALE): $f:11 " <<< "$out" && ! grep -q "^FAIL (STALE): $f:4 " <<< "$out" \
      && grep -q '^FAIL: 1 stale or unrunnable derivation(s) of 1 checked' <<< "$out"
    arm q-laterstale $? "    exit=1  a stale LATER copy keeps its FAIL; the superseded one is named, not run" "q-laterstale"
  fi
  # q-live: the identical text in a live document supersedes nothing.
  if want q-live; then
    f="$QS/prd.md"; qrun "$V" "$f"
    [ "$rc" -eq 1 ] && grep -q "^FAIL (STALE): $f:4 " <<< "$out" && ! grep -q '^SUPERSEDED:' <<< "$out" \
      && grep -q '^FAIL: 1 stale or unrunnable derivation(s) of 2 checked' <<< "$out"
    arm q-live $? "          exit=1  the same repeat in a LIVE document supersedes nothing" "q-live"
  fi
  # q-outside: a record name outside s<digits>/ is not a record, matching the walk.
  if want q-outside; then
    f=_bmad-output/planning-artifacts/prd-repair-p1.md; qrun "$V" "$f"
    [ "$rc" -eq 1 ] && grep -q "^FAIL (STALE): $f:4 " <<< "$out" && ! grep -q '^SUPERSEDED:' <<< "$out"
    arm q-outside $? "       exit=1  a record-named file outside a sprint slot supersedes nothing" "q-outside"
  fi
  # q-byte: a later command one byte different (its file operand) is not a copy.
  if want q-byte; then
    f="$QS/architecture-repair-p1.md"; qrun "$V" "$f"
    [ "$rc" -eq 1 ] && grep -q "^FAIL (STALE): $f:4 " <<< "$out" && ! grep -q '^SUPERSEDED:' <<< "$out" \
      && grep -q '^FAIL: 1 stale or unrunnable derivation(s) of 2 checked' <<< "$out"
    arm q-byte $? "          exit=1  a later command differing by one byte supersedes nothing" "q-byte"
  fi
  # q-open: STAYS OPEN -- a stale record fence with no later copy still fails, named.
  if want q-open; then
    f="$QS/stories-repair-p1.md"; qrun "$V" "$f"
    [ "$rc" -eq 1 ] && grep -q "^FAIL (STALE): $f:4 " <<< "$out" && ! grep -q '^SUPERSEDED:' <<< "$out"
    arm q-open $? "          exit=1  a stale record fence with no later copy stays open" "q-open"
  fi
  # q-text: the only later copies are in a text fence, in prose and as a deeper-indented output
  # line, none of which the block grammar reads as a command -> no supersession.
  if want q-text; then
    f="$QS/epics-repair-p1.md"; qrun "$V" "$f"
    [ "$rc" -eq 1 ] && grep -q "^FAIL (STALE): $f:4 " <<< "$out" && ! grep -q '^SUPERSEDED:' <<< "$out" \
      && grep -q '^FAIL: 1 stale or unrunnable derivation(s) of 2 checked' <<< "$out"
    arm q-text $? "          exit=1  a later \`\$ \` line in a text fence, in prose or as indented output is no copy" "q-text"
  fi
  # q-list: --list still lists every command, the superseded one included.
  if want q-list; then
    f="$QS/prd-repair-p1.md"; qrun "$V" --list "$f"
    [ "$rc" -eq 0 ] && grep -q '^2 derivation(s) in 2 block(s) across 1 file(s)' <<< "$out" \
      && grep -qF "  $f:4  grep -c x src/two.txt" <<< "$out" && ! grep -q '^SUPERSEDED:' <<< "$out"
    arm q-list $? "          exit=0  --list lists the superseded command too" "q-list"
  fi
  arm_end
}
q_arms "$VALIDATOR" 0
bat_base "q-control" Q

# --- R. A BACKTICK IS JUDGED BY ITS QUOTE STATE, AND ONE `git -C` STAYS INSIDE THE REPOSITORY ----
# A substring ban on the backtick refused `grep -c -F 'a`b' d.txt`, which bash runs with no
# substitution, and reading git's subcommand as word 2 refused `git -C sub rev-parse ...`. Both
# were correct derivations rewritten at write time. The fix moves the backtick into the quote
# scan and skips ONE leading `-C <dir>` under three conditions: a plain path, inside the
# physical root when RELATIVE, and the root's own common dir. An ABSOLUTE <dir> need not sit under
# the root -- the capture hook roots fences at the edited file's linked worktree -- so for it the
# common dir is the whole boundary, and its refusal names that reason: r-abs-wt/-link/-root are
# admitted, r-abs (/tmp), r-abs-for (a foreign repo), r-abs-bare and r-abs-nest are refused.
#
# EVERY REFUSED ROW ASSERTS ITS MESSAGE, NOT ITS RC. With the backtick test deleted outright,
# `echo 'a'`touch canary`'b'` runs, prints a line, and fails STALE with rc 1 -- the refusal's rc
# exactly, after the canary was created. So each backtick row carries a message arm AND a canary
# arm, and each repo row a canary where its world holds a `diff.external`.
#
# THE WORLD HOLDS ONE REPO OF EACH KIND THE COMMON-DIR CHECK MUST EXCLUDE, and both carry a
# canary `diff.external`. The bare clone is driven with `diff HEAD~1 HEAD` because an argless
# `diff` in a bare repo compares nothing and never calls the external, so it cannot fire. The
# NESTED NON-BARE repo is the subject that proves the common-dir check by itself: the eval's own
# safe.bareRepository=explicit still blocks the bare clone with the check removed, and it does
# not block a non-bare repo.
R="$WORK/r"; RP="$R/p"
mkdir -p "$RP/.claude" "$RP/sub" "$R/o" "$R/x" "$R/src"
( git -C "$RP" init -q . && git -C "$RP" -c user.email=r@r -c user.name=r commit -q --allow-empty -m p \
  && git -C "$RP" worktree add -q "$R/wt" -b r-wt \
  && ln -s "$R/wt" "$R/wtlink" \
  && git -C "$R/o" init -q . && git -C "$R/o" -c user.email=r@r -c user.name=r commit -q --allow-empty -m o \
  && git -C "$R/x" init -q . && git -C "$R/x" -c user.email=r@r -c user.name=r commit -q --allow-empty -m x \
  && ln -s "$R/o" "$RP/sub/sub" \
  && mkdir -p "$RP/nested" && git -C "$RP/nested" init -q . \
  && printf 'one\n' > "$RP/nested/f" && git -C "$RP/nested" add f \
  && git -C "$RP/nested" -c user.email=r@r -c user.name=r commit -q -m 1 \
  && printf 'two\n' > "$RP/nested/f" && git -C "$RP/nested" -c user.email=r@r -c user.name=r commit -q -am 2 \
  && git -C "$RP/nested" config diff.external "$R/ext-nested.sh" \
  && git -C "$R/src" init -q . && printf 'one\n' > "$R/src/f" && git -C "$R/src" add f \
  && git -C "$R/src" -c user.email=r@r -c user.name=r commit -q -m 1 \
  && printf 'two\n' > "$R/src/f" && git -C "$R/src" -c user.email=r@r -c user.name=r commit -q -am 2 \
  && git clone -q --bare "$R/src" "$RP/evil" \
  && git --git-dir="$RP/evil" config diff.external "$R/ext-bare.sh" \
  && mkdir -p "$R/f/sub" && git -C "$R/f" init -q . && printf 'one\n' > "$R/f/t" && printf 's\n' > "$R/f/sub/s" \
  && git -C "$R/f" add -A && git -C "$R/f" -c user.email=r@r -c user.name=r commit -q -m f \
  && printf 'two\n' > "$R/f/t" && git -C "$R/f" config diff.external "$R/ext-sym.sh" \
  && ln -s "$R/f/sub" "$RP/lnk" ) >/dev/null 2>&1 \
  || bad "r-world could not be built -- no R verdict below is readable"
printf '#!/bin/bash\ntouch %s/canary-nested\n' "$R" > "$R/ext-nested.sh"
printf '#!/bin/bash\ntouch %s/canary-bare\n' "$R" > "$R/ext-bare.sh"
printf '#!/bin/bash\ntouch %s/canary-sym\n' "$R" > "$R/ext-sym.sh"
chmod +x "$R/ext-nested.sh" "$R/ext-bare.sh" "$R/ext-sym.sh"
printf 'a`b\n' > "$RP/d.txt"

R_BT="it carries a backtick outside single quotes, which bash runs as command substitution"
r_run() { # $1 validator  $2 label  $3 command  $4 recorded output -> out, rc
  { printf '# r\n\n```derived\n$ %s\n%s\n```\n' "$3" "$4"; } > "$RP/$2.md"
  rm -f "$RP/canary" "$R/canary-nested" "$R/canary-bare" "$R/canary-sym"
  out="$(cd "$RP" && vad_call "$1" AI_DLC_PROJECT_ROOT="$RP" -- "$2.md" 2>&1)"; rc=$?
}
r_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2"
  arm_begin "$q"
  racc() { # $1 label  $2 command  $3 recorded
    want "$1" || return 0
    r_run "$V" "$1" "$2" "$3"
    [ "$rc" -eq 0 ] && grep -q '^OK: 1 derivation(s)' <<< "$out"
    arm "$1" $? "exit=0  runs and reproduces: $2"
  }
  rref() { # $1 label  $2 command  $3 expected message  $4 canary path or ""
    want "$1-msg" "$1-can" || return 0
    r_run "$V" "$1" "$2" ""
    if want "$1-msg"; then
      [ "$rc" -eq 1 ] && grep -qF "$3" <<< "$out"
      arm "$1-msg" $? "exit=1  refused naming the reason: $2"
    fi
    if [ -n "$4" ] && want "$1-can"; then
      ! [ -e "$4" ]
      arm "$1-can" $? "the refused command never ran (no canary): $2"
    fi
  }
  racc r-acc-sq    "grep -c -F 'a\`b' d.txt" 1
  racc r-acc-dq    'grep -c "a\`b" d.txt' 1
  racc r-acc-c     'git -C sub rev-parse --is-inside-work-tree' true
  racc r-acc-cdot  'git -C ./sub rev-parse --is-inside-work-tree' true
  rref r-bt-uq     'echo `touch canary`'           "$R_BT" "$RP/canary"
  rref r-bt-dq     'echo "`touch canary`"'         "$R_BT" "$RP/canary"
  rref r-bt-sqcat  "echo 'a'\`touch canary\`'b'"   "$R_BT" "$RP/canary"
  racc r-abs-wt    "git -C $R/wt rev-parse --is-inside-work-tree" true
  racc r-abs-link  "git -C $R/wtlink rev-parse --is-inside-work-tree" true
  racc r-abs-root  "git -C $RP rev-parse --is-inside-work-tree" true
  rref r-abs       'git -C /tmp log'               "'git -C /tmp' names a directory that is not a worktree of this repository" ""
  rref r-abs-for   "git -C $R/o log"               "'git -C $R/o' names a directory that is not a worktree of this repository" ""
  rref r-abs-bare  "git -C $RP/evil diff HEAD~1 HEAD" "'git -C $RP/evil' names a directory that is not a worktree of this repository" "$R/canary-bare"
  rref r-abs-nest  "git -C $RP/nested diff HEAD~1 HEAD" "'git -C $RP/nested' names a directory that is not a worktree of this repository" "$R/canary-nested"
  rref r-dotdot    'git -C ../x log'               "'git -C ../x' is not a read-only git subcommand" ""
  # `lnk` is an untracked symlink in the root to a FOREIGN repo's `sub`. A logical `cd lnk/..` lands
  # in the root; `git -C lnk/..` chdirs physically and lands in the foreign repo, whose diff.external
  # writes the canary. Both spellings must be refused before anything runs.
  rref r-sym-rel   'git -C lnk/.. diff'            "'git -C lnk/..' is not a read-only git subcommand" "$R/canary-sym"
  rref r-sym-abs   "git -C $RP/lnk/.. diff"        "'git -C $RP/lnk/..' names a directory that is not a worktree of this repository" "$R/canary-sym"
  rref r-chain     'git -C sub -C sub log'        "'git -C sub -C' is not a read-only git subcommand" ""
  rref r-bare      'git -C evil diff HEAD~1 HEAD'  "'git -C evil' is not a read-only git subcommand" "$R/canary-bare"
  rref r-nested    'git -C nested diff HEAD~1 HEAD' "'git -C nested' is not a read-only git subcommand" "$R/canary-nested"
  rref r-dashc     'git -C sub -c core.pager=x log' "'git -c' is not a read-only git subcommand" ""
  arm_end
}
# The absolute rows put $R into the fence text, so $R must sit inside the -C character class, or an
# admit row goes red for the class rather than for the common-dir logic.
case "$R" in
  /*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./-]*|[!/]*)
    bad "r-world path $R is outside the -C character class -- the r-abs admit rows are unreadable" ;;
  *) ok "r-world path            \$R is an absolute path inside the -C character class" ;;
esac
[ -f "$R/wt/.git" ] && [ -L "$R/wtlink" ] \
  && ok "r-world worktree        \$R/wt is a LINKED worktree of the root (a .git FILE), reached also by a symlink" \
  || bad "r-world worktree: \$R/wt is not a linked worktree or \$R/wtlink is not a symlink -- r-abs-wt/r-abs-link unreadable"
r_arms "$VALIDATOR" 0
bat_base "r-control" R


a_arms() { # <validator> <quiet> -> ARMS_FAILED
  arm_begin "$2"
  want a-ctl && {
    r_run "$1" a-ctl 'grep -c a d.txt' 1
    [ "$rc" -eq 0 ] && grep -q '^OK: 1 derivation(s)' <<< "$out"
    arm a-ctl $? "exit=0  the unmutated validator passes its self-probe and runs a benign derivation"; }
  arm_end
}
a_arms "$VALIDATOR" 0
bat_base "a-control" A

# --- S. ONLY A LISTED OPTION IS ADMITTED, READ FROM THE ARGV BASH BUILDS ------------------------
# Every allowed command carries an exact table of the options it may use (OPT_TABLE, rows
# `cmd|sub|token|arity|note`), and the walker reads the NUL argv bash builds for the segment, so a
# form not on its command's table is refused as "is not an option this checker admits". Each
# command with a table gets a pair, one property apart: a LISTED option accepted, and an UNLISTED
# option refused with the text naming it. Every refused example is HARMLESS -- an option that only
# changes formatting or diagnostics, or a token no tool defines (`--zz-not-an-option`) -- so the
# boundary is shown to be an allowlist and not a list of known-bad forms.
#
# The pairs go through ONE `--explain-cmd -` batch per validator copy (it reads the same argv and
  # prints the first refusal line), and two arms go through the REAL check path, so a gate that
  # worked but whose explain output did not cannot pass.
#
# The `$` arms (contract rev 3a): the scan refuses a `$` bash expands -- a name, a digit, a special
# parameter, `$[`, and `$"` outside double quotes -- and `$'` as ANSI-C quoting; the end-anchor in
# "^x$" is admitted. `${` and `$(` are absent from the scan's class, because the substring ban
# refuses both first; s-dl-brace and s-dl-paren hold that ban to its message.
S="$WORK/s"; mkdir -p "$S/.claude"
printf 'x\ny\nx\n' > "$S/d.txt"
printf 'x\n' > "$S/pats.txt"
S_OPT="is not an option this checker admits"
: > "$S/cases.tsv"; : > "$S/expect.tsv"
scase() { # $1 label  $2 expected: OK, or a substring of the first refusal line  $3 command
  printf '%s\t%s\n' "$1" "$3" >> "$S/cases.tsv"
  printf '%s\t%s\n' "$1" "$2" >> "$S/expect.tsv"
}
spair() { # $1 label stem  $2 accepted command  $3 refused option (as the message names it)  $4 refused command
  scase "$1-acc" OK "$2"
  scase "$1-ref" "'$3' $S_OPT" "$4"
}
spair s-awk        "awk -F: '{print \$1}' d.txt"     "awk --zz-not-an-option"   "awk --zz-not-an-option '{print}' d.txt"
spair s-basename   "basename -a d.txt"               "basename -z"              "basename -z d.txt"
spair s-cat        "cat -n d.txt"                    "cat -A"                   "cat -A d.txt"
spair s-comm       "comm -12 d.txt d.txt"            "comm --total"             "comm --total d.txt d.txt"
spair s-cut        "cut -c1 d.txt"                   "cut --complement"         "cut --complement -c1 d.txt"
spair s-difftool   "diff -q d.txt d.txt"            "diff --zz-not-an-option"  "diff --zz-not-an-option d.txt d.txt"
spair s-echo       "echo -n x"                       "echo -e"                  "echo -e x"
spair s-find       "find . -empty"                   "find -daystart"           "find . -daystart"
spair s-git-catfile "git cat-file -t HEAD"           "git cat-file --zz-not-an-option" "git cat-file --zz-not-an-option HEAD"
spair s-git-describe "git describe --tags"           "git describe --zz-not-an-option" "git describe --zz-not-an-option"
spair s-git-diff   "git diff --stat"                 "git diff --color-moved"   "git diff --color-moved"
spair s-git-grep   "git grep -c x"                   "git grep --line-buffered" "git grep --line-buffered x"
spair s-git-log    "git log --oneline"               "git log --zz-not-an-option" "git log --zz-not-an-option"
spair s-git-lsfiles "git ls-files -c"                "git ls-files --zz-not-an-option" "git ls-files --zz-not-an-option"
spair s-git-revparse "git rev-parse --verify HEAD"   "git rev-parse --zz-not-an-option" "git rev-parse --zz-not-an-option HEAD"
spair s-git-show   "git show --stat HEAD"            "git show --zz-not-an-option" "git show --zz-not-an-option HEAD"
spair s-git-status "git status -s"                   "git status --zz-not-an-option" "git status --zz-not-an-option"
spair s-grep       "grep -c x d.txt"                 "grep --zz-not-an-option"  "grep --zz-not-an-option x d.txt"
spair s-head       "head -n 2 d.txt"                 "head --verbose"           "head --verbose d.txt"
spair s-ls         "ls -1"                           "ls -G"                    "ls -G"
spair s-nl         "nl -ba d.txt"                    "nl --number-width"        "nl --number-width=3 d.txt"
spair s-rg         "rg -c x d.txt"                   "rg --debug"               "rg --debug x d.txt"
spair s-sed        "sed -n p d.txt"                  "sed --debug"              "sed --debug -n p d.txt"
spair s-sha256sum  "sha256sum -b d.txt"              "sha256sum --zero"         "sha256sum --zero d.txt"
spair s-shasum     "shasum --tag d.txt"              "shasum --zz-not-an-option" "shasum --zz-not-an-option d.txt"
spair s-sort       "sort -r d.txt"                   "sort --debug"             "sort --debug d.txt"
spair s-tail       "tail -n 1 d.txt"                 "tail -z"                  "tail -z d.txt"
spair s-test       "test -f d.txt"                   "test -t"                  "test -t 1"
spair s-uniq       "uniq -c d.txt"                   "uniq --zero-terminated"   "uniq --zero-terminated d.txt"
spair s-wc         "wc -l d.txt"                     "wc --libxo"               "wc --libxo d.txt"
# ROWS TAKEN FROM THE REFERENCE CONSUMER'S CORPUS, one acceptance arm each.
# shasum -a: _bmad-output/gate-adjudication/s303/story6-authoring.repair.md:86
scase s-row-shasum-a OK                                "shasum -a 256 d.txt"
# grep -f: _bmad-output/planning-artifacts/s312/gate-sprint-review-repair-p1.md:189
scase s-row-grep-f OK                                  "grep -c -f pats.txt d.txt"
# grep -P: _bmad-output/planning-artifacts/s311/consolidation-coverage-carry-over-backlog.md:102
scase s-row-grep-P OK                                  "grep -c -P 'a' d.txt"
# EXACT MATCH: a unique prefix of a listed long option is not that option.
scase s-exact-acc OK                                   "sort --dictionary-order d.txt"
scase s-exact-ref "'sort --dictionary' $S_OPT"         "sort --dictionary d.txt"
# SHORT CLUSTER: every letter is looked up, not only the first.
scase s-cluster-acc OK                                 "ls -1a"
scase s-cluster-ref "'ls -G' $S_OPT"                   "ls -1G"
# STANDALONE `--`: an operand after it is admitted; a dash word after it is not, on a command
# that is not on the end-of-options list (sha256sum is not).
scase s-endop-acc OK                                   "sort -- d.txt"
scase s-endop-ref "'sha256sum -- --debug (a dash word after a standalone --)' $S_OPT" "sha256sum -- --debug d.txt"
# END OF OPTIONS IS PER COMMAND (OPT_ENDOPTS). grep is listed, so a dash word after `--` is its
# pattern operand; head is not listed, so the same word after `--` is still refused.
scase s-eo-acc OK                                      "grep -n -- '--debug' d.txt"
scase s-eo-ref "'head -- --debug (a dash word after a standalone --)' $S_OPT" "head -n 1 -- --debug d.txt"
# VALUES: a required value as the next word is admitted; `=x` on a no-value option is not.
scase s-value-acc OK                                   "cut -d : -f 1 d.txt"
scase s-value-ref "'sort --reverse=x (it takes no value)' $S_OPT" "sort --reverse=x d.txt"
# SED AND UNIQ STOP AT THEIR FIRST OPERAND (BSD getopt, no permutation): a dash word after it is
# an operand to the tool, so the walker refuses it rather than read it as an option. The accepted
# twins carry the same options before the operand.
S_FIRSTOP="after its first operand (sed and uniq stop reading options at their first operand"
scase s-sedfirst-acc OK                                "sed -e p f"
scase s-sedfirst-ref "'sed -e $S_FIRSTOP"              "sed 'k' -e p f"
scase s-uniqfirst-acc OK                               "uniq -c f"
scase s-uniqfirst-ref "'uniq -c $S_FIRSTOP"            "uniq f -c"
# OPTIONAL ARITY TAKES ONLY AN ATTACHED VALUE. The word after `--stat` is an unlisted option, so a
# walker that let `optional` take the next word would swallow it unchecked; with a listed option
# there the segment is accepted either way.
scase s-optional-acc OK                                "git show --stat --oneline HEAD"
scase s-optional-ref "'git show --zz-not-an-option' $S_OPT" "git show --stat --zz-not-an-option HEAD"
# A VALUE-TAKING OPTION AT THE END OF ARGV has no value, so it is refused.
scase s-pendend-acc OK                                 "head -n 1 d.txt"
scase s-pendend-ref "'head -n (it takes a value and none follows)' $S_OPT" "head -n"
# UNIQ TAKES ONE OPERAND: an option argument is not one, a second operand is.
scase s-uniqtwo-acc OK                                 "uniq -f 1 d.txt"
scase s-uniqtwo-ref "'uniq d2.txt, a second operand"   "uniq -c d.txt d2.txt"
# `-<digits>` IS ACCEPTED ONLY WHERE THE COMMAND HAS A `-NUM` ROW: head has one, sort has none.
scase s-num-acc OK                                     "head -2 d.txt"
scase s-num-ref "'sort -2' $S_OPT"                     "sort -2 d.txt"
# QUOTED AND BRACE-EXPANDED spellings of one unlisted option: bash builds `--debug` from both, and
# the walker reads what bash builds, not the raw text.
scase s-quoted "'sort --debug' $S_OPT"                 "sort '--debug' d.txt"
scase s-brace  "'sort --debug' $S_OPT"                 "sort --{debug,} d.txt"
# THE `$` CLASSES (M_DOLLAR is section M's refusal text).
scase s-dl-end OK                                      'grep -c "^x$" d.txt'
scase s-dl-name    "$M_DOLLAR"                         'grep -c "x$ZZ_NAME" d.txt'
scase s-dl-digit   "$M_DOLLAR"                         'grep -c x$1 d.txt'
scase s-dl-special "$M_DOLLAR"                         'grep -c x$? d.txt'
scase s-dl-bracket "$M_DOLLAR"                         'grep -c x$[1] d.txt'
scase s-dl-dq      "$M_DOLLAR"                         'grep -c $"x" d.txt'
scase s-dl-ansi    "uses \$'...' ANSI-C quoting"       "grep -c \$'x' d.txt"
scase s-dl-brace   'it can chain, redirect or substitute' 'grep -c ${ZZ_NAME} d.txt'
scase s-dl-paren   'it can chain, redirect or substitute' 'grep -c $(echo x) d.txt'
S_NCASES="$(grep -c . "$S/cases.tsv")" || S_NCASES=0

# THE DIFFERENTIAL: the walker's argv (read back from --explain-cmd's ARGV line) against the NUL
# argv bash itself prints for the same text, from the same directory.
s_argv_bash() { ( c="$1"; cd "$S" && set -- && eval "set -- $c" && printf '%s\0' "$@" ); }
s_argv_split() { ( c="$1"; set -f; set -- $c; printf '%s\0' "$@" ); }
s_argv_walker() { # $1 validator  $2 command
  local all line
  all="$(cd "$S" && vad_call "$1" AI_DLC_PROJECT_ROOT="$S" -- --explain-cmd "$2" 2>/dev/null)"
  line="$(grep -m1 "^-	ARGV	" <<< "$all")" || return 1
  line="${line#*	ARGV	}"
  ( eval "set -- $line" && printf '%s\0' "$@" )
}
S_DIFF_IN='grep -c "a b" d.txt'
s_argv_bash "$S_DIFF_IN" > "$S/seed.bash"; s_argv_split "$S_DIFF_IN" > "$S/seed.split"
if [ -s "$S/seed.bash" ] && [ -s "$S/seed.split" ] && ! cmp -s "$S/seed.bash" "$S/seed.split"; then
  ok "s-diff-seed            the two argv sides DIFFER on a seeded input (bash's argv vs a whitespace split), so agreement below is a reading"
else
  bad "s-diff-seed the comparison cannot tell bash's argv from a whitespace split -- no s-diff verdict below is readable"
fi

s_run() { # $1 validator  $2 label  $3 command  $4 recorded -> out, rc
  { printf '# s\n\n```derived\n$ %s\n%s\n```\n' "$3" "$4"; } > "$S/$2.md"
  out="$(cd "$S" && vad_call "$1" AI_DLC_PROJECT_ROOT="$S" -- "$2.md" 2>&1)"; rc=$?
}
s_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" lbl exp line nv c need=0 sdiff_bad=0
  arm_begin "$q"
  # THE ONE --explain-cmd BATCH answers every case arm. It runs once per validator copy, and only when
  # some case arm (or s-batch) is among the arms wanted.
  if [ -z "$WANT" ] || want s-batch; then need=1
  else for lbl in $WANT; do grep -q "^$lbl	" "$S/expect.tsv" && need=1; done; fi
  if [ "$need" -eq 1 ]; then
    out="$(cd "$S" && vad_call "$V" AI_DLC_PROJECT_ROOT="$S" -- --explain-cmd - < "$S/cases.tsv" 2>&1)"; rc=$?
    nv="$(grep -c '	VERDICT	' <<< "$out")" || nv=0
    if want s-batch; then
      [ "$rc" -eq 0 ] && [ "$nv" -eq "$S_NCASES" ] && [ "$nv" -gt 0 ]
      arm s-batch $? "exit=0  --explain-cmd printed one VERDICT for each of the $S_NCASES cases"
    fi
    S_BATCH_OUT="$out"
    while IFS=$'\t' read -r lbl exp; do
      want "$lbl" || continue
      line="$(grep -m1 "^$lbl	VERDICT	" <<< "$S_BATCH_OUT")" || line=""
      out="$line"; rc=0
      if [ "$exp" = OK ]; then
        [ "$line" = "$lbl	VERDICT	OK" ]
        arm "$lbl" $? "accepted: $(grep -m1 "^$lbl	" "$S/cases.tsv" | cut -f2-)"
      else
        case "$line" in "$lbl	VERDICT	REFUSED	"*"$exp"*) true ;; *) false ;; esac
        arm "$lbl" $? "refused naming [$exp]: $(grep -m1 "^$lbl	" "$S/cases.tsv" | cut -f2-)"
      fi
    done < "$S/expect.tsv"
  fi
  # The real check path, one accepted and one refused.
  if want s-real-acc; then
    s_run "$V" s-real-acc 'sort -r d.txt' "$(printf 'y\nx\nx')"
    [ "$rc" -eq 0 ] && grep -q '^OK: 1 derivation(s)' <<< "$out"
    arm s-real-acc $? "exit=0  a listed option runs and reproduces through the check path"
  fi
  if want s-real-ref; then
    s_run "$V" s-real-ref 'sort --debug d.txt' x
    [ "$rc" -eq 1 ] && grep -q '^FAIL (ALLOWLIST): .*s-real-ref.md:4 ' <<< "$out" && grep -qF "'sort --debug' $S_OPT" <<< "$out"
    arm s-real-ref $? "exit=1  an unlisted option is an ALLOWLIST refusal naming it through the check path"
  fi
  # The differential, on the real inputs: the walker's argv equals bash's for each.
  if want s-diff; then
    for c in "sort '--debug' d.txt" "sort --{debug,} d.txt" "$S_DIFF_IN"; do
      s_argv_bash "$c" > "$S/d.bash"
      if s_argv_walker "$V" "$c" > "$S/d.walk" && [ -s "$S/d.walk" ] && cmp -s "$S/d.bash" "$S/d.walk"; then :; else
        sdiff_bad=1; out="the walker's argv differs from bash's for: $c"; fi
    done
    [ "$sdiff_bad" -eq 0 ] && out=""
    rc=$sdiff_bad
    arm s-diff "$sdiff_bad" "the walker's argv equals bash's printf '%s\\0' argv on quoted, brace and spaced inputs" "s-diff                "
  fi
  # THE STARTUP INTERSECTION. The option table admits no NEVER-set row: the same invocation runs clean.
  if want s-never; then
    out="$(cd "$S" && vad_call "$V" AI_DLC_PROJECT_ROOT="$S" -- --explain-cmd 'sort -r d.txt' 2>&1)"; rc=$?
    [ "$rc" -eq 0 ] && ! grep -q '^REFUSED: ' <<< "$out" && grep -q '	VERDICT	OK$' <<< "$out"
    arm s-never $? "exit=0  the option table admits no NEVER-set option: the same invocation runs clean, VERDICT OK"
  fi
  arm_end
}
s_arms "$VALIDATOR" 0
bat_base "s-control" S


# --- T. --explain-cmd EXPLAINS EVERY SEGMENT OF A REFUSED CHAIN, AND NOTHING ELSE MOVES ------------
# A chain is refused by the substring ban before any scan, so --explain-cmd printed only its VERDICT
# and the owed-derivations sweep, which asks only ARGV/WORD lines, never saw a chain's operands
# (BL-799). explain_chain now prints each SAFE segment's ARGV/WORD lines before base's VERDICT line.
# Every segment is re-gated before seg_check's eval -- the substring ban minus the operators split
# on, the segment's own scan status, and the pipe scan over the segment alone -- because that eval
# executes `$(…)`, `> f` and `<(…)` when nothing stands in front of it.
T="$WORK/t"; mkdir -p "$T/.claude"
printf 'x\n' > "$T/f.txt"; printf 'b\n' > "$T/g.txt"
T_REFUSED='-	VERDICT	REFUSED	it can chain, redirect or substitute (one of ; & > < $( ${ ||)'
T_TWO="grep -c 'a;b' f.txt && grep -c b g.txt"
T_RETRO='grep -n x .claude/skills/ai-dlc/steps/retro.md; echo "exit:$?"'
T_NEAR="grep -c 'a;b' f.txt"
T_PIPE='a | b; c'
# The substitutions come BEFORE the safe `cat g.txt`, so the arm also proves splitting resumes after
# each one closes.
T_CAN='echo $(touch CANARY1); cat f.txt > CANARY2; cat <(touch CANARY3); echo ${X:-y}; cat g.txt'
# THE SPLIT TABLE: `<label>|<command>|<expected ARGV values, comma-joined, in order>`. EVERY EXPECTED
# SPLIT CAME FROM BASH, NOT FROM THE SCANNER: each command was run with every top-level segment
# prefixed by a marker `echo SEGk` (substitution bodies only `echo`), in an empty scratch dir, and
# the markers bash printed are the segments. A segment carrying a substitution, an ANSI-C quote or an
# expanding `$` contributes no ARGV line; every other segment contributes its own. Each substitution
# body carries a `touch` canary, which t-failclosed asserts never ran.
#   t-subst-resume   splitting resumes after `$( )` closes
#   t-nested         `$( $( ) )` closes twice; the `;` between is inside the outer frame
#   t-bt-in-subst    a backtick frame inside `$( )`, carrying its own `;`
#   t-sqparen/dqparen a `)` inside single or double quotes within `$( )` does not close it
#   t-brace-semi     a `;` inside `${X:-a;b}` is not a split
#   t-procsub        `<( )` is a frame
#   t-arith          `$((1+2))`: a bare `(` inside a frame nests
#   t-nested-esc     an escaped `\)` inside nested frames closes nothing; a tracker that drops to
#                    depth 0 at the inner `)` splits `cat g.txt` out of the outer body (t-m5)
#   t-ansi-*         `$'...'`: a backslash takes the next character, the first other `'` ends it --
#                    `\'`, `\\`, a `;` inside, `\x27`, and an `\'` hiding a `; touch ...; echo '`
#                    that a backslash-blind end would split out (t-m6)
T_SPLIT="t-subst-resume|cat f.txt; echo \$(touch CANARY1); cat g.txt|cat f.txt,cat g.txt
t-nested|cat f.txt; echo \$(echo \$(touch CANARY4); cat f.txt); cat g.txt|cat f.txt,cat g.txt
t-bt-in-subst|cat f.txt; echo \$(echo \`touch CANARY5; cat f.txt\`); cat g.txt|cat f.txt,cat g.txt
t-sqparen|cat f.txt; echo \$(echo ')'; touch CANARY6); cat g.txt|cat f.txt,cat g.txt
t-dqparen|cat f.txt; echo \$(echo \")\"; touch CANARY7); cat g.txt|cat f.txt,cat g.txt
t-brace-semi|cat f.txt; echo \${X:-a;b}; cat g.txt|cat f.txt,cat g.txt
t-procsub|cat f.txt; cat <(touch CANARY3; cat f.txt); cat g.txt|cat f.txt,cat g.txt
t-arith|cat f.txt; echo \$((1+2)); cat g.txt|cat f.txt,cat g.txt
t-nested-esc|cat f.txt; echo \$(echo \$(touch CANARY8); cat g.txt; echo \\)); cat f.txt|cat f.txt,cat f.txt
t-ansi-esc|grep -c \$'a\\'b' f.txt; cat g.txt|cat g.txt
t-ansi-bsbs|grep -c \$'a\\\\' f.txt; cat g.txt|cat g.txt
t-ansi-semi|grep -c \$'a;b' f.txt ; cat g.txt|cat g.txt
t-ansi-x27|grep -c \$'a\\x27b' f.txt; cat g.txt|cat g.txt
t-ansi-trap|grep -c \$'a\\'; touch CANARY9; echo '; cat g.txt|cat g.txt"
#   t-cd          the carried prefix, applied to the raw word before %q
#   t-cd-dyn      a dynamic cd (status 6) explains nothing after it, itself included
#   t-cd-up       a cd above the root explains nothing after it
#   t-cd-abs      an absolute cd explains nothing after it
#   t-cd-compose  successive literal cds compose
#   t-pushd       pushd explains nothing after it
#   t-cd-before   a segment before the cd is root-relative, one after `cd web &&` is prefixed
#   t-cd-norm     `./` and `//` collapse, `..` resolves inside the path, an absolute operand stays
#   t-cd-gitc     git is off CD_LIST: `git -C` under a prefix ends the explanation
#   t-cd-gitgrep  git is off CD_LIST: `git grep` under a prefix ends the explanation
#   t-cd-file, t-cd-pattern, t-cd-epat, t-cd-drec  grep is off CD_LIST (this machine's BSD grep takes
#                 `--label <v>` and `--context[=num]`, which the option table does not know), so every
#                 grep shape under a prefix ends the explanation -- the -f, pattern, -e and joined-value
#                 shapes the position-aware rule once covered
#   t-cd-dash     an operand that is exactly `-` is stdin and printed unprefixed: `scripts/ai-dlc/-`
#                 would match the core glob `scripts/ai-dlc/*`
#   t-cd-core     a slash-free word after a cd into core is still prefixed (no blanket slash-free skip)
#   t-cd-semi     `;` after a cd ends the explanation (a failed cd leaves the root)
#   t-cd-or       `||` after a cd ends it (the next segment runs only when the cd FAILED)
#   t-cd-bg       `&` after a cd ends it (the cd ran in a background subshell)
#   t-cd-mixed    the prefix crosses `&&`, and a later `||` ends the explanation
#   t-cd-glob     an unquoted glob under a prefix ends it (the eval would glob in the root)
#   t-cd-qglob    a QUOTED or escaped `*` is not a glob, so the segment is explained
#   t-cd-tilde    an unquoted `~` under a prefix ends it (the eval would expand it from the root's shell)
#   t-cd-orleft   a `||` before the cd in its and-or list: the cd may be skipped, so it is not carried
#   t-cd-orleft2  the same with `&&` first and the `||` just before the cd
#   t-cd-orleft3  `grep -q x f.txt || cd web && cat P` (the filed shape)
#   t-cd-andleft  only `&&` before the cd: carried
#   t-cd-orreset  a `||` before a `;` does not reach a cd after the `;`
#   CD_LIST, one arm per listed command, each asserting every operand is prefixed and no option value
#   is: t-cd-cat (t-cd), t-cd-wc, t-cd-head (`-n 5` keeps 5), t-cd-cut (`-d :` and `-f 1` kept: the
#   reader asks any command's `-f` value, and cut's `1` is printed as base prints it, unprefixed), t-cd-nl
#   (`-b a` kept), t-cd-comm, t-cd-sha256sum.
#   Off the list, each ends the explanation: t-cd-rg, t-cd-echo, t-cd-sed, t-cd-printf, t-cd-test,
#   t-cd-awk, t-cd-tail, t-cd-sort, t-cd-ls (`-D <format>`), t-cd-diff (`-L`, `-A`, `-X` ...), the grep
#   rows above, and t-cd-pipeoff (an off-list stage in a pipe ends it too).
#   t-cd-pipe     a pipe of two listed commands is explained, prefixed
# Fields are `^`-separated: the commands themselves carry `|` and `||`.
T_CD="t-cd^cd web && cat .claude/skills/ai-dlc/SKILL.md^cd web,cat .claude/skills/ai-dlc/SKILL.md^web/.claude/skills/ai-dlc/SKILL.md
t-cd-dyn^cd \"\$D\" && cat x^^
t-cd-up^cd .. && cat y^cd ..^
t-cd-abs^cd /tmp && cat y^cd /tmp^
t-cd-compose^cd a && cd b && cat z^cd a,cd b,cat z^a/b/z
t-pushd^pushd web && cat .claude/skills/ai-dlc/SKILL.md^pushd web^
t-cd-before^cat f.txt; cd web && cat g.txt^cat f.txt,cd web,cat g.txt^f.txt,web/g.txt
t-cd-norm^cd ./web//src/ && cat ../x /abs/y^cd ./web//src/,cat ../x /abs/y^web/x,/abs/y
t-cd-file^cd web && grep -f pats.txt -c x ../g.txt^cd web^
t-cd-gitc^cd web && git -C sub log x; cat g.txt^cd web^
t-cd-pattern^cd .claude/skills && grep -c ai-dlc README.md^cd .claude/skills^
t-cd-epat^cd web && grep -c a.md -e x && grep -e x -c f.txt^cd web^
t-cd-gitgrep^cd web && git grep -n x f.txt^cd web^
t-cd-core^cd .claude/skills/ai-dlc && cat SKILL.md^cd .claude/skills/ai-dlc,cat SKILL.md^.claude/skills/ai-dlc/SKILL.md
t-cd-semi^cat f.txt; cd web; cat g.txt^cat f.txt,cd web^f.txt
t-cd-or^cd web || cat P^cd web^
t-cd-bg^cd web & cat P^cd web^
t-cd-mixed^cd web && cat P || cat Q^cd web,cat P^web/P
t-cd-glob^cd .claude/skills/ai-dlc && cat *.md^cd .claude/skills/ai-dlc^
t-cd-qglob^cd web && cat '*.md' && cat g.txt^cd web,cat \\*.md,cat g.txt^web/\\*.md,web/g.txt
t-cd-tilde^cd web && cat ~/x && cat g.txt^cd web^
t-cd-orleft^cat a || cd web && cat x^cat a,cd web^a
t-cd-orleft2^cat a && cat b || cd web && cat x^cat a,cat b,cd web^a,b
t-cd-orleft3^grep -q x f.txt || cd web && cat P^grep -q x f.txt,cd web^x,f.txt
t-cd-andleft^cat a && cd web && cat x^cat a,cd web,cat x^a,web/x
t-cd-orreset^cat a || cat b; cd web && cat x^cat a,cat b,cd web,cat x^a,b,web/x
t-cd-wc^cd web && wc -l f.txt g.txt^cd web,wc -l f.txt g.txt^web/f.txt,web/g.txt
t-cd-head^cd web && head -n 5 f.txt^cd web,head -n 5 f.txt^web/f.txt
t-cd-cut^cd web && cut -d : -f 1 g.txt^cd web,cut -d : -f 1 g.txt^1,web/g.txt
t-cd-nl^cd web && nl -b a f.txt^cd web,nl -b a f.txt^web/f.txt
t-cd-ls^cd web && ls -1 sub^cd web^
t-cd-diff^cd web && diff -q a b^cd web^
t-cd-dash^cd scripts/ai-dlc && cat -^cd scripts/ai-dlc,cat -^-
t-cd-comm^cd web && comm -12 a b^cd web,comm -12 a b^web/a,web/b
t-cd-sha256sum^cd web && sha256sum f.txt^cd web,sha256sum f.txt^web/f.txt
t-cd-pipe^cd web && cat f.txt | wc -l^cd web,cat f.txt,wc -l^web/f.txt
t-cd-pipeoff^cd web && cat f.txt | sort^cd web^
t-cd-rg^cd .claude/skills && rg -c ai-dlc README.md^cd .claude/skills^
t-cd-echo^cd scripts && echo ai-dlc^cd scripts^
t-cd-sed^cd web && sed -n 1p f.txt^cd web^
t-cd-printf^cd scripts && printf ai-dlc^cd scripts^
t-cd-test^cd scripts && test -n ai-dlc^cd scripts^
t-cd-awk^cd scripts && awk 1 f.txt^cd scripts^
t-cd-tail^cd web && tail -n 1 f.txt^cd web^
t-cd-sort^cd web && sort f.txt^cd web^
t-cd-drec^cd scripts && grep -drecurse ai-dlc x.txt && grep -Dread ai-dlc y.txt^cd scripts^"
t_ex() { ( cd "$2" && vad_call "$1" AI_DLC_PROJECT_ROOT="$2" -- --explain-cmd "$3" 2>&1 ); } # validator root cmd
t_argvs() { grep -c '^-	ARGV	' <<< "$1" || true; }
T_A1_CMDS="grep -c x f.txt && cat g.txt
grep -c x f.txt; cat g.txt
grep -c x f.txt || cat g.txt
grep -c x f.txt & cat g.txt
cat f.txt | wc -l; cat g.txt
grep -c x f.txt;# cat g.txt
cat f.txt > T_OUT1
cat < f.txt
echo \$(cat f.txt)
echo \${X:-y}
grep -c x f.txt 2>&1; cat g.txt
grep -c x f.txt |& cat
$T_TWO
$T_NEAR"
t_arms() { # <validator> <quiet> -> ARMS_FAILED
  local V="$1" q="$2" o r i c ro rr tc lbl cmd want_v got gops st_all=0 fc_bad=0 t_wanted
  arm_begin "$q"
  # t-two: a quoted `;` is not split on, so exactly two segments, both operands asked, base's verdict.
  if want t-two; then
    o="$(t_ex "$V" "$T" "$T_TWO")"
    [ "$(t_argvs "$o")" = 2 ] && grep -qx -e '-	WORD	grep		operand		f.txt' <<< "$o" \
      && grep -qx -e '-	WORD	grep		operand		g.txt' <<< "$o" && [ "$(sed -n '$p' <<< "$o")" = "$T_REFUSED" ]
    rr=$?; out="$o"; arm t-two $rr "two ARGV lines (operands f.txt, g.txt) and base's VERDICT for: $T_TWO"
  fi
  # t-retro: the graph shape -- a `$?` segment contributes nothing, the grep is asked.
  if want t-retro; then
    o="$(t_ex "$V" "$T" "$T_RETRO")"
    [ "$(t_argvs "$o")" = 1 ] && grep -qx -e '-	ARGV	grep -n x .claude/skills/ai-dlc/steps/retro.md' <<< "$o" \
      && grep -qx -e '-	WORD	grep		operand		.claude/skills/ai-dlc/steps/retro.md' <<< "$o" && [ "$(sed -n '$p' <<< "$o")" = "$T_REFUSED" ]
    rr=$?; out="$o"; arm t-retro $rr "exactly one ARGV line, the grep, operand asked, for: $T_RETRO"
  fi
  # t-near: no top-level operator, so the VERDICT line alone.
  if want t-near; then
    o="$(t_ex "$V" "$T" "$T_NEAR")"
    [ "$o" = "$T_REFUSED" ]
    rr=$?; out="$o"; arm t-near $rr "a quoted ; alone prints only the REFUSED verdict line: $T_NEAR"
  fi
  # t-pipe: a segment's own pipe stages are walked, in source order.
  if want t-pipe; then
    o="$(t_ex "$V" "$T" "$T_PIPE")"
    [ "$(grep '^-	ARGV	' <<< "$o" | cut -f3 | tr '\n' ' ')" = "a b c " ]
    rr=$?; out="$o"; arm t-pipe $rr "ARGV lines a, b, c in order for: $T_PIPE"
  fi
  # t-canary: no segment carrying a substitution or a redirection reaches the eval, and the safe
  # segment after them is still explained. WHAT IT DISCRIMINATES IS NARROWER THAN THE CANARY LIST:
  # under a ban-skipping validator only CANARY2 appears. `$(`, `<(` and `${` are stopped by the
  # segment's own scan status as well as by the ban, so for those three the arm cannot tell the two
  # gates apart; the BAN's only ban-alone subject here is the redirection. The status gate's own
  # subjects are the `$?` in t-retro and the backtick, which the ban does not carry.
  if want t-canary; then
    # Built fresh per use, never copied from one build: a canary body that ran would dirty the root it ran in.
    tc="$(mktemp -d "$T/canary.XXXXXX")"; mkdir -p "$tc/.claude"; printf 'x\n' > "$tc/f.txt"; printf 'b\n' > "$tc/g.txt"
    o="$(t_ex "$V" "$tc" "$T_CAN")"
    [ ! -e "$tc/CANARY1" ] && [ ! -e "$tc/CANARY2" ] && [ ! -e "$tc/CANARY3" ] \
      && [ "$(grep '^-	ARGV	' <<< "$o" | cut -f3 | tr '\n' ',')" = "cat g.txt," ] && [ "$(sed -n '$p' <<< "$o")" = "$T_REFUSED" ]
    rr=$?; out="$(ls "$tc" | tr '\n' ' ') $o"; arm t-canary $rr "no CANARY file created, the safe segment after the substitutions still explained"
  fi
  # THE SPLIT TABLE, each row its own arm, all in ONE fresh scratch root. t-failclosed then asserts
  # that root holds exactly what was seeded: whatever a tracker mis-split, no substitution body ran.
  # Every row runs when t-failclosed is wanted, because the root it inspects is what all the rows touched.
  t_wanted=0
  while IFS='|' read -r lbl cmd want_v; do want "$lbl" && t_wanted=1; done <<< "$T_SPLIT"
  if [ "$t_wanted" -eq 1 ] || want t-failclosed; then
    # Built fresh per use, never copied from one build: t-failclosed asserts this root holds only what was seeded.
    tc="$(mktemp -d "$T/split.XXXXXX")"; mkdir -p "$tc/.claude"; printf 'x\n' > "$tc/f.txt"; printf 'b\n' > "$tc/g.txt"
    while IFS='|' read -r lbl cmd want_v; do
      o="$(t_ex "$V" "$tc" "$cmd")"; got="$(grep '^-	ARGV	' <<< "$o" | cut -f3 | tr '\n' ',')"
      [ "$got" = "$want_v," ] && [ "$(sed -n '$p' <<< "$o")" = "$T_REFUSED" ]; rr=$?
      if want "$lbl"; then out="got [$got] $o"; arm "$lbl" "$rr" "ARGV [$want_v] for: $cmd"; fi
    done <<< "$T_SPLIT"
    if want t-failclosed; then
      [ "$(ls -A "$tc" | tr '\n' ' ')" = ".claude f.txt g.txt " ]
      rr=$?; out="$(ls -A "$tc" | tr '\n' ' ')"; arm t-failclosed $rr "after every split row the scratch root holds only what was seeded (no substitution body ran)"
    fi
  fi
  # THE cd TABLE: `<label>|<command>|<ARGV lines>|<operand-class words>`, both comma-joined in order. A
  # literal relative `cd` is carried: later operands read `<dir>/<word>`; anything else that changes
  # directory leaves every later segment unexplained (the ARGV column then stops at the cd).
  t_wanted=0
  while IFS='^' read -r lbl cmd want_v gops; do want "$lbl" && t_wanted=1; done <<< "$T_CD"
  if [ "$t_wanted" -eq 1 ]; then
    # BUILT ONCE, COPIED PER USE (fixture-mutants.md clause 4): the cd root is read only through --explain-cmd, which
    # executes nothing, so every use starts from the same three entries. $T/cd-tpl is built by the first use.
    if [ ! -d "$T/cd-tpl" ]; then mkdir -p "$T/cd-tpl/.claude"; printf 'x\n' > "$T/cd-tpl/f.txt"; printf 'b\n' > "$T/cd-tpl/g.txt"; fi
    tc="$(mktemp -d "$T/cd.XXXXXX")"; cp -Rp "$T/cd-tpl/." "$tc/"
    while IFS='^' read -r lbl cmd want_v wops; do
      want "$lbl" || continue
      o="$(t_ex "$V" "$tc" "$cmd")"; got="$(grep '^-	ARGV	' <<< "$o" | cut -f3 | tr '\n' ',')"
      gops="$(awk -F'\t' '$2 == "WORD" && ($5 == "operand" || ($5 == "val" && ($6 == "-f" || $6 == "--file"))) { printf "%s,", $7 }' <<< "$o")"
      [ "$got" = "${want_v:+$want_v,}" ] && [ "$gops" = "${wops:+$wops,}" ] && [ "$(sed -n '$p' <<< "$o")" = "$T_REFUSED" ]
      rr=$?; out="got ARGV [$got] operands [$gops]"; arm "$lbl" $rr "ARGV [$want_v] operands [$wops] for: $cmd"
    done <<< "$T_CD"
  fi
  # t-a1: the CHECK path refuses every chain, redirect and substitution form with exit 1 and the
  # ALLOWLIST failure (a presence, so silence cannot pass).
  if want t-a1; then
    # BUILT ONCE, COPIED PER USE (fixture-mutants.md clause 4): the a1-<i>.md files depend only on T_A1_CMDS, so they
    # are rendered into $T/a1-tpl by the first use and copied into $T by every use.
    if [ ! -d "$T/a1-tpl" ]; then
      mkdir -p "$T/a1-tpl"; i=0
      while IFS= read -r c; do i=$((i + 1)); printf '# t\n\n```derived\n$ %s\n1\n```\n' "$c" > "$T/a1-tpl/a1-$i.md"; done <<< "$T_A1_CMDS"
    fi
    cp -Rp "$T/a1-tpl/." "$T/"
    i=0; fc_bad=0; out=""
    while IFS= read -r c; do
      i=$((i + 1))
      ro="$(cd "$T" && vad_call "$V" AI_DLC_PROJECT_ROOT="$T" -- "a1-$i.md" 2>&1)"; rr=$?
      if [ "$rr" != 1 ] || ! grep -q '^FAIL (ALLOWLIST): ' <<< "$ro"; then
        fc_bad=1; out="the check path did not refuse with exit 1 and FAIL (ALLOWLIST) for: $c"
      fi
    done <<< "$T_A1_CMDS"
    [ "$i" -ge 10 ] || { fc_bad=1; out="only $i chain commands were driven"; }
    arm t-a1 "$fc_bad" "the check path refuses all $i chain/redirect/substitution commands with exit 1 and FAIL (ALLOWLIST)" "t-a1                  "
  fi
  arm_end
}
t_arms "$VALIDATOR" 0
bat_base "t-control" T


# --- U. THE IN-PROCESS CALL IS THE CLI ---------------------------------------------------------
# Every cell above asks the validator through vad_call (unit.sh): the file sourced in a subshell,
# vad_load, one vad_invoke. That is only the same question as `bash validate-artifact-derivations.sh
# <args>` if the two answer alike, so this section runs ONE CLI call per outcome the validator has --
# OK, STALE, UNRUN, a refused walk, a missing file, usage, --list and --explain-cmd --
# beside its in-process call and asserts the merged output and the status equal. The eight outcomes must
# also differ from one another, or equal answers would be one answer eight times. A recording `bash`
# shim on PATH then shows the CLI side executed `bash` and the in-process side executed none.
U="$WORK/u"; mkdir -p "$U/bin"
UREAL_BASH="$(command -v bash)"
printf '#!/bin/bash\necho call >> "%s/bash.log"\nexec "%s" "$@"\n' "$U" "$UREAL_BASH" > "$U/bin/bash"; chmod +x "$U/bin/bash"
u_norm() { sed -e "s#$U_VALP#VAL#g" -e "s#$0#VAL#g"; }
u_pair() { # $1 validator  $2 cwd  $3 root  $4 PATH prefix ("" = none)  $5.. args -> UP_IN UP_CLI UP_RIN UP_RCLI
  local val="$1" cwd="$2" root="$3" pp="$4"; shift 4
  U_VALP="$val"
  UP_IN="$(cd "$cwd" && vad_call "$val" AI_DLC_PROJECT_ROOT="$root" PATH="${pp:+$pp:}$PATH" -- "$@" 2>&1 | u_norm)"
  UP_RIN="$(cd "$cwd" && vad_call "$val" AI_DLC_PROJECT_ROOT="$root" PATH="${pp:+$pp:}$PATH" -- "$@" >/dev/null 2>&1; echo $?)"
  UP_CLI="$(cd "$cwd" && AI_DLC_PROJECT_ROOT="$root" PATH="${pp:+$pp:}$PATH" "$UREAL_BASH" "$val" "$@" 2>&1 | u_norm)"
  UP_RCLI="$(cd "$cwd" && AI_DLC_PROJECT_ROOT="$root" PATH="${pp:+$pp:}$PATH" "$UREAL_BASH" "$val" "$@" >/dev/null 2>&1; echo $?)"
}
mshim 'kill -9 $$'
U_ALL=""; U_RCS=""; u_bad=0
while IFS="|" read -r u_lbl u_val u_cwd u_root u_pp u_args; do
  [ -n "$u_lbl" ] || continue
  eval "set -- $u_args"
  u_pair "$u_val" "$u_cwd" "$u_root" "$u_pp" "$@"
  if [ "$UP_IN" = "$UP_CLI" ] && [ "$UP_RIN" = "$UP_RCLI" ] && [ -n "$UP_IN" ]; then
    ok "u-$u_lbl  the in-process call and the CLI give the same output and status ($UP_RIN)"
  else
    bad "u-$u_lbl the in-process call (rc $UP_RIN) and the CLI (rc $UP_RCLI) differ: [$UP_IN] against [$UP_CLI]"; u_bad=1
  fi
  U_ALL="$U_ALL$UP_RIN:$(printf '%s' "$UP_IN" | cksum)
"; U_RCS="$U_RCS $UP_RIN"
done <<EOF
ok|$VALIDATOR|$WORK|$WORK||"$WORK/a-true/story.md"
stale|$VALIDATOR|$WORK|$WORK||"$WORK/a-stale/story.md"
unrun|$VALIDATOR|$WORK|$WORK|$WORK/m/bin|"$WORK/m/fault.md"
walk|$VALIDATOR|$WORK|$WORK|$N/find-fail|"$N/dir"
missing|$VALIDATOR|$WORK|$WORK||"$WORK/u-no-such-file.md"
usage|$VALIDATOR|$WORK|$WORK||
list|$VALIDATOR|$WORK|$WORK||--list "$WORK/a-true/story.md"
explain|$VALIDATOR|$S|$S||--explain-cmd 'sort -r d.txt'
EOF
u_distinct="$(printf '%s' "$U_ALL" | sed '/^$/d' | sort -u | grep -c .)"
case " $U_RCS " in *" 0 "*" 1 "*|*" 1 "*" 0 "*) u_rcs=ok ;; *) u_rcs=no ;; esac
[ "$u_distinct" -ge 7 ] && [ "$u_rcs" = ok ] && case " $U_RCS " in *" 2 "*) true ;; *) false ;; esac \
  && ok "u-distinct  the eight outcomes give $u_distinct distinct answers and statuses 0, 1 and 2 all occur, so the equalities above compare different things" \
  || bad "u-distinct the eight outcomes gave only $u_distinct distinct answers or lack a status of 0, 1 or 2 (statuses:$U_RCS)"
# The recording shim: the CLI side calls `bash` through PATH once per run, the in-process side never.
rm -f "$U/bash.log"
( cd "$WORK" && AI_DLC_PROJECT_ROOT="$WORK" PATH="$U/bin:$PATH" bash "$VALIDATOR" "$WORK/a-true/story.md" ) >/dev/null 2>&1
u_cli_calls="$(grep -c call "$U/bash.log" 2>/dev/null)" || u_cli_calls=0
rm -f "$U/bash.log"
( cd "$WORK" && vad_call "$VALIDATOR" AI_DLC_PROJECT_ROOT="$WORK" PATH="$U/bin:$PATH" -- "$WORK/a-true/story.md" ) >/dev/null 2>&1
u_in_calls="$(grep -c call "$U/bash.log" 2>/dev/null)" || u_in_calls=0
[ "$u_cli_calls" -ge 1 ] && [ "$u_in_calls" -eq 0 ] \
  && ok "u-noproc  the recording bash shim saw the CLI run call bash and saw the in-process call make no bash call" \
  || bad "u-noproc the recording bash shim saw $u_cli_calls call(s) from the CLI run (want at least 1) and $u_in_calls from the in-process call (want 0)"


echo
report_end artifact-derivations
