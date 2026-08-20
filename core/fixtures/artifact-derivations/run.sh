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

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails assertion(s) wrong."
  exit 1
fi
echo "PASS: all assertions correct."
exit 0
