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
mkdir -p "$WORK/h"
printf 'w canaryF\n' > "$WORK/h/evil.sed"
exec_contained sed-script-file "sed -n -f evil.sed data.txt"
printf 'w canaryF\n' > "$WORK/h/evil.sed"
exec_contained sed-script-file-joined "sed -n -fevil.sed data.txt"
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
  ( cd "$WORK/h-abs" && AI_DLC_PROJECT_ROOT="$WORK/h-abs" bash "$VALIDATOR" "$WORK/h-abs/story.md" ) >/dev/null 2>&1
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
  ( cd "$WORK/h2" && AI_DLC_PROJECT_ROOT="$WORK/h2" bash "$VALIDATOR" "$WORK/h2/story.md" ) >/dev/null 2>&1
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
sed_refused() { # $1 command
  mkdir -p "$WORK/h3"
  printf 'a\nb\nc\n' > "$WORK/h3/data.txt"
  { printf '```derived\n$ %s\n0\n```\n' "$1"; } > "$WORK/h3/story.md"
  out="$(AI_DLC_PROJECT_ROOT="$WORK/h3" bash "$VALIDATOR" "$WORK/h3/story.md" 2>&1)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'writes a file or runs a command' <<< "$out"; then
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
sed_refused "sed --expression='w canary' data.txt"
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

# --- K. THE MUTANTS: WHAT SEPARATES THE FIX FROM THE OVER-BROAD NON-FIX -------------------
# THE FILED RECEIPT IS CLOSED BY A BLANKET `sed:*` DENY, which refuses all 1652 legitimate
# sed derivations in the reference corpus. Nothing else in this repo separates that non-fix
# from the real one: the receipt passes under it and so do the other four fixtures that drive
# this validator. So the separation lives HERE, and it is the reason section H4 scores the
# must-allow set by verdict rather than trusting the exec arms alone.
#
# Two mutants, each a COPY guarded by `cmp -s` so a `sed` that matched nothing cannot pass as
# a mutation, and each asserted on a DIFFERENT observable:
#
#   M1  blanket `sed:*` deny replacing the new predicate  -> H4 must go RED, H must stay green
#   M2  the new predicate DELETED                         -> H must go RED
#
# M1's assertion is not merely a flipped exit. A flipped exit is produced by any breakage;
# the assertion is that the failure names the ALLOWLIST refusal, which is what an over-broad
# deny produces and what a STALE or a crash does not.
mkdir -p "$WORK/k"
VBASE="$(basename "$VALIDATOR")"

mut_copy() { # $1 dest  $2..  sed expressions -> 0 mutated, 1 DID NOT APPLY
  local dest="$1"; shift
  cp "$VALIDATOR" "$dest" || return 1
  local e
  for e in "$@"; do
    "${SED:-sed}" "$e" "$dest" > "$dest.new" 2>/dev/null || { rm -f "$dest.new"; return 1; }
    mv "$dest.new" "$dest"
  done
  if cmp -s "$VALIDATOR" "$dest"; then return 1; fi
  return 0
}

# M1 — the blanket deny. Every `sed` segment is refused, whatever its script. The mutation
# REPLACES the predicate's guard line with one that always fires, so the predicate's body
# becomes unreachable and its narrowness is gone.
M1="$WORK/k/m1-$VBASE"
if mut_copy "$M1" 's|^    if \[ "\$first" = "sed" \]; then$|    if [ "$first" = "sed" ]; then printf "BADOPT:sed (blanket)\\n"; break; fi; if false; then|'; then
  ok "k-m1 applied          (cmp -s: the blanket-deny mutation changed the file)"
  # The must-ALLOW half must go RED, and name the allowlist refusal.
  mkdir -p "$WORK/k/m1w"
  { printf '```derived\n$ sed -n '"'"'/w/p'"'"' src/w-forms.txt | wc -l\n       2\n```\n'; } > "$WORK/k/m1w/story.md"
  out="$(AI_DLC_PROJECT_ROOT="$WORK" bash "$M1" "$WORK/k/m1w/story.md" 2>&1)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL (ALLOWLIST)' <<< "$out" \
     && grep -q 'writes a file or runs a command' <<< "$out"; then
    ok "k-m1 KILLED           the blanket deny refuses a legitimate \`sed -n '/w/p'\` as an ALLOWLIST failure"
  else
    bad "k-m1 SURVIVED: a blanket \`sed:*\` deny did not make the must-allow case fail as an ALLOWLIST refusal (rc=$rc): $out"
  fi
  # UNMUTATED CONTROL, same seed, same invocation shape: the real fix ALLOWS it. Without this
  # the arm above passes against a validator that refuses everything for any reason at all.
  out="$(AI_DLC_PROJECT_ROOT="$WORK" bash "$VALIDATOR" "$WORK/k/m1w/story.md" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && ok "k-m1 CONTROL          the unmutated validator ALLOWS the same seed (so the kill is the mutation's)" \
    || bad "k-m1 CONTROL: the unmutated validator also refused the must-allow seed (rc=$rc): $out"
  # AND THE EXEC HALF MUST STAY GREEN UNDER M1. A mutant that broke the whole boundary would
  # also pass the arm above; this says the blanket deny is over-broad, not simply broken.
  mkdir -p "$WORK/k/m1e"
  printf 'a\nb\nc\n' > "$WORK/k/m1e/data.txt"
  rm -f "$WORK/k/m1e/canary"*
  { printf '```derived\n$ sed -n '"'"'w canary'"'"' data.txt\n0\n```\n'; } > "$WORK/k/m1e/story.md"
  ( cd "$WORK/k/m1e" && AI_DLC_PROJECT_ROOT="$WORK/k/m1e" bash "$M1" "$WORK/k/m1e/story.md" ) >/dev/null 2>&1
  if ls "$WORK/k/m1e/canary"* >/dev/null 2>&1; then
    bad "k-m1 the blanket deny let the write EXECUTE -- the mutation broke the boundary instead of widening it"
  else
    ok "k-m1 exec half        still contained (the blanket deny is OVER-BROAD, not broken)"
  fi
  rm -f "$WORK/k/m1e/canary"*
else
  bad "k-m1 DID NOT APPLY -- the blanket-deny mutation matched nothing, so no verdict was scored"
fi

# M2 — the predicate DELETED. The `if [ "$first" = "sed" ]` guard is made unreachable with
# its body intact, which is the shape of "this fix was never written": the write must then
# execute through the validator.
M2="$WORK/k/m2-$VBASE"
if mut_copy "$M2" 's|^    if \[ "\$first" = "sed" \]; then$|    if false; then|'; then
  ok "k-m2 applied          (cmp -s: the predicate-deleted mutation changed the file)"
  mkdir -p "$WORK/k/m2e"
  printf 'a\nb\nc\n' > "$WORK/k/m2e/data.txt"
  rm -f "$WORK/k/m2e/canary"*
  { printf '```derived\n$ sed -n '"'"'w canary'"'"' data.txt\n0\n```\n'; } > "$WORK/k/m2e/story.md"
  ( cd "$WORK/k/m2e" && AI_DLC_PROJECT_ROOT="$WORK/k/m2e" bash "$M2" "$WORK/k/m2e/story.md" ) >/dev/null 2>&1
  if ls "$WORK/k/m2e/canary"* >/dev/null 2>&1; then
    ok "k-m2 KILLED           with the predicate gone, \`sed -n 'w canary'\` EXECUTES through the validator"
  else
    bad "k-m2 SURVIVED: deleting the sed predicate did not re-open the write -- the exec arms are not keyed on it"
  fi
  rm -f "$WORK/k/m2e/canary"*
  # UNMUTATED CONTROL on the identical seed, so "no canary" above cannot be a dead harness.
  mkdir -p "$WORK/k/m2c"
  printf 'a\nb\nc\n' > "$WORK/k/m2c/data.txt"
  rm -f "$WORK/k/m2c/canary"*
  { printf '```derived\n$ sed -n '"'"'w canary'"'"' data.txt\n0\n```\n'; } > "$WORK/k/m2c/story.md"
  ( cd "$WORK/k/m2c" && AI_DLC_PROJECT_ROOT="$WORK/k/m2c" bash "$VALIDATOR" "$WORK/k/m2c/story.md" ) >/dev/null 2>&1
  if ls "$WORK/k/m2c/canary"* >/dev/null 2>&1; then
    bad "k-m2 CONTROL: the UNMUTATED validator also executed the write -- the fix is not in the tree being tested"
  else
    ok "k-m2 CONTROL          the unmutated validator contains the same seed (so the kill is the mutation's)"
  fi
  rm -f "$WORK/k/m2c/canary"*
else
  bad "k-m2 DID NOT APPLY -- the predicate-deleted mutation matched nothing, so no verdict was scored"
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails assertion(s) wrong."
  exit 1
fi
echo "PASS: all assertions correct."
exit 0
