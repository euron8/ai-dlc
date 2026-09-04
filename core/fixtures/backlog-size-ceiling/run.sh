#!/usr/bin/env bash
# backlog-size-ceiling -- exercise scripts/validate-backlog-size.sh, the live-entry ceiling
# over docs/backlog.md.
#
# SIXTEEN PROBES PLUS AN UNMUTATED CONTROL, each a throwaway repo under a temp dir.
# Exit 0 iff the control is green AND every probe holds.
#
# THE CEILING IS ENTRY-DENOMINATED AND THERE IS NO BYTE CLAUSE. A byte ceiling was proposed
# and withdrawn on measurement -- archived entries average 7193 bytes against a live mean of
# 3758, so rotation is the byte lever and it is denominated in entries. Nothing here seeds or
# asserts a byte size, and a probe that did would be testing a clause that does not exist.
#
# WHY A SEPARATE DIRECTORY RATHER THAN AN ARM INSIDE core/fixtures/claude-rules-joins/.
# The subject is a different program. That fixture's seed builds a `.claude/rules/` corpus and
# its mutants edit frontmatter; this one seeds a ledger and sabotages a loaded predicate.
# Sharing a seed would make every claude-rules mutant carry a backlog corpus it does not use.
#
# FIVE THINGS HERE ARE A DELIBERATE COPY FROM core/fixtures/claude-rules-joins/run.sh, NOT AN
# INDEPENDENT INVENTION, AND THE COPY IS THE POINT. `seed()`, the env-passing runner, the
# `kill_check` shape, the `cmp -s` guard on every mutation, and the "assert the FAIL-line
# COUNT, not just the message" rule are that file's, worked out against eleven mutants over
# several releases. Re-deriving them here would produce a second, weaker harness whose bugs
# nobody finds. They are copied rather than sourced because a fixture that sources a sibling
# cannot be run alone, and the suite's pool dispatches directories independently.
#
# EVERY MUTATION IS BYTE-COMPARED BEFORE ITS VERDICT IS READ. A mutant keyed on a token the
# target does not contain is a NO-OP that comes back green and reads exactly like a mutant
# that survived. Measured in this very file's development: a `sed` anchored on a spelling
# `lib.sh` does not carry changed nothing and the run passed. Every probe below that edits a
# file asserts the file CHANGED, and the self-probe pair asserts the arm's BEHAVIOUR moved.
#
# WHY THE CONTROL IS NOT DECORATION. Each probe is a fresh seed plus one edit, and the
# validator resolves its own root by walking up for VERSION. A seed that fails to build makes
# the validator exit 2 and print nothing, and "no output" would otherwise score as a kill on
# every probe below.
#
# Usage: run.sh
# Exit:  0 = every probe holds, 1 = one regressed, 2 = fixture broken.
set -u

# CLEAR EVERY AMBIENT AI_DLC_* KEY BEFORE ANY PROBE RUNS, and I87 fails the push without it.
# This fixture parameterises the ceiling by passing `AI_DLC_BACKLOG_MAX_ENTRIES=<n>` into each
# run, but it passes them as double-quoted `env` words -- `"AI_DLC_...=..."` -- which I87's
# assignment scan does not recognise as an assignment, and correctly so: an assignment inside
# ONE invocation says nothing about the probes that do NOT set it. Those read the operator's
# `.claude/settings.json` otherwise, so a probe asserting the DEFAULT would assert whatever
# that file happens to say -- passing for the wrong reason here and failing on a build machine
# set differently. v0.289.0 fixed three fixtures in exactly that state.
#
# NOTE what this does and does not establish: with the environment cleared, a probe that runs
# the arm with no ceiling set proves the arm's compiled-in default is 100. Without the clearing
# it would only have proved that the variable was unset on this machine, which is a different
# claim and one that passes against an arm whose default is anything at all.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-backlog-size.sh" \
  "$DIR/../../../scripts/validate-backlog-size.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "run.sh: could not locate validate-backlog-size.sh" >&2; exit 2
fi

# The entry-boundary rule the validator loads. Self-rooted at $DIR and naming BOTH layouts,
# the way VALIDATOR is resolved above -- I33c.
LIBSRC=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/lib.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/lib.sh"; do
  [ -f "$cand" ] && LIBSRC="$cand" && break
done
if [ -z "$LIBSRC" ]; then
  echo "run.sh: could not locate reconcile/lib.sh" >&2; exit 2
fi

# The shipping classifier and the rotator, for the two join probes. Resolved the same way.
REVERIFY=""; ROTATOR=""; REAL_LEDGER=""
for cand in "$DIR/../../../scripts/backlog-reverify.sh" "$DIR/../../scripts/backlog-reverify.sh"; do
  [ -f "$cand" ] && REVERIFY="$cand" && break
done
for cand in "$DIR/../../../scripts/backlog-rotate.sh" "$DIR/../../scripts/backlog-rotate.sh"; do
  [ -f "$cand" ] && ROTATOR="$cand" && break
done
for cand in "$DIR/../../../docs/backlog.md" "$DIR/../../docs/backlog.md"; do
  [ -f "$cand" ] && REAL_LEDGER="$cand" && break
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

# BL_K IS 7 AND ARBITRARY. What matters is that the seed writes exactly BL_K entries and the
# arm says BL_K.
BL_K=7

bl_seed_entries() { # bl_seed_entries <file> <n>
  local f="$1" n="$2" i=1
  printf '# Carry-over backlog\n\nPreamble prose mentioning BL- ids.\n\n' > "$f"
  while [ "$i" -le "$n" ]; do
    printf '## BL-%03d\n\nBody of entry %d.\n\nverify: sh exit 1\n\n' "$i" "$i" >> "$f"
    i=$(( i + 1 ))
  done
}

seed() { # seed <dir> [<n-entries>]
  local d="$1" n="${2:-$BL_K}"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-backlog-size.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  [ -n "$REVERIFY" ] && cp "$REVERIFY" "$d/scripts/backlog-reverify.sh"
  bl_seed_entries "$d/docs/backlog.md" "$n"
}

# The validator takes a whitespace-separated env list because some probes pin the ceiling.
# The split is the point of the function, not an oversight.
# shellcheck disable=SC2086
run_v() { # run_v <env-string-or-empty> <dir> [<extra-args>...]
  local e="$1" d="$2"; shift 2
  ( cd "$d" && env $e bash scripts/validate-backlog-size.sh "$@" 2>&1 )
}

# Reads the count back out of the arm's OWN ok line. Empty if the arm did not speak, which
# every caller treats as a failure rather than as a zero.
# Anchored on the SHIPPED arm's ok line, which is a single `OK: ... B1 <n>/<max> entries in
# <ledger>` and NOT the indented two-column form this fixture was first written against. The
# mismatch cost a full red run: every count_check read an empty string and reported "the arm
# observed nothing", which is the right message for the wrong reason.
bl_reported() { printf '%s\n' "$1" | sed -n 's|^OK: validate-backlog-size -- B1 \([0-9][0-9]*\)/[0-9]* entries in .*|\1|p'; }

# THE STRONGEST ASSERTION IN THIS FILE, AND IT IS NOT A KILL. A near-miss battery that only
# asserts "the validator stayed quiet" cannot tell a predicate that correctly ignored four
# decoys from one that counted two of them and missed two real entries -- both are silent at
# a slack ceiling. Worse, it cannot see the mis-implementations that raise nothing anywhere:
# reading the ARCHIVE instead of the live file, or globbing `docs/backlog*.md`. Asserting the
# arm reported the number the seed WROTE catches every one of those in one comparison, and
# the fixture never restates the predicate -- it reads the arm's own output back.
count_check() { # count_check <name> <dir> <env> <want> [<extra-args>...]
  local n="$1" d="$2" e="$3" want="$4"; shift 4
  local out rc_v got
  out="$(run_v "$e" "$d" "$@")"; rc_v=$?
  if [ "$rc_v" -ne 0 ]; then
    note "FAIL  $n -- validator exited $rc_v on a tree that must pass"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1; return
  fi
  got="$(bl_reported "$out")"
  if [ -z "$got" ]; then
    note "FAIL  $n -- the arm printed no ok line, so it observed nothing and the quiet is not a reading"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1; return
  fi
  if [ "$got" -ne "$want" ]; then
    note "FAIL  $n -- the arm reports $got live entries; the seed wrote $want. Quiet at a slack ceiling is not evidence the predicate read the right file."
    rc=1; return
  fi
  note "ok    $n -- quiet, and the arm counted exactly the $want entries the seed wrote"
}

kill_check() { # kill_check <name> <dir> <env> <nfail> <substr>
  local n="$1" d="$2" e="$3" want="$4" pat="$5" out rc_v nfail
  out="$(run_v "$e" "$d")"; rc_v=$?
  nfail="$(printf '%s\n' "$out" | grep -c '^FAIL:')"
  if [ "$rc_v" -eq 0 ]; then note "FAIL  $n -- probe SURVIVED (validator exited 0)"; rc=1; return; fi
  if [ "$rc_v" -eq 2 ]; then
    note "FAIL  $n -- validator exited 2 (environment/self-probe), which is not this probe's assertion"
    printf '%s\n' "$out" | sed 's/^/      /' | head -3; rc=1; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    note "FAIL  $n -- validator failed, but not on this probe's assertion (wanted: $pat)"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1; return
  fi
  if [ "$nfail" -ne "$want" ]; then
    note "FAIL  $n -- $nfail FAIL lines, expected $want"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/      /' | head -4; rc=1; return
  fi
  note "ok    $n -- killed by its own assertion, and by exactly that many"
}

# --- unmutated control ------------------------------------------------------
seed "$TMP/control"
if out="$(run_v "" "$TMP/control")" && [ -n "$out" ]; then
  note "ok    control -- clean seed passes, harness is live"
else
  note "FIXTURE BROKEN: the unmutated control did NOT pass. Every probe verdict below is meaningless."
  printf '%s\n' "$out" | sed 's/^/      /'
  exit 1
fi

# ===== THE BOUNDARY. No override, so these are the only probes that can see a typo in 100. =

# b01 -- PASSING side: exactly 100. "exceeds 100" means 100 is legal, and an off-by-one written
# as `-ge` is green on b02 alone. This is the probe that catches it, and the amendment named
# it the likeliest real defect.
#
# THESE TWO NUMBERS TRACK THE ARM'S COMPILED-IN DEFAULT AND ARE THE ONLY THING THAT CAN SEE IT
# CHANGE. They were 75/76 until the operator raised the ceiling to 100; a raise that moved the
# arm and not this pair would leave the fixture asserting a bound nothing enforces, which is
# green and says nothing.
seed "$TMP/b01" 100
count_check "b01 exactly AT the ceiling (100) passes" "$TMP/b01" "" 100

# b02 -- FAILING side: 101.
seed "$TMP/b02" 101
kill_check "b02 one over the ceiling (101) fails" "$TMP/b02" "" 1 \
  "carries 101 entries against a ceiling of 100"

# b03 -- the override must actually override, or every pinned probe below is silently testing
# the shipped 100 against a tiny seed and passing vacuously.
seed "$TMP/b03"
kill_check "b03 the ceiling override is live" "$TMP/b03" \
  "AI_DLC_BACKLOG_MAX_ENTRIES=$(( BL_K - 1 ))" 1 \
  "carries $BL_K entries against a ceiling of $(( BL_K - 1 ))"

# ===== VACUITY. The states where the ceiling passes having observed nothing. ==============

# b04 -- the corpus is gone. `grep -c` on a missing file yields an EMPTY string with rc 2 and
# `wc -c` yields empty with rc 1; `[ "${n:-0}" -gt 100 ]` is then FALSE and the ceiling passes.
seed "$TMP/b04"; rm -f "$TMP/b04/docs/backlog.md"
# EXIT 2, NOT 1, AND THAT IS THE SHIPPED CONTRACT. The arm declares 1 = over the ceiling or a
# zero parse, 2 = usage/environment; an absent ledger is an environment fact. What matters to
# this probe is only that no path returns 0 -- `grep -c` and `wc -c` on a missing file both
# yield an EMPTY string rather than 0, and `[ "${n:-0}" -gt 100 ]` is then FALSE.
b04_out="$(run_v "" "$TMP/b04")"; b04_rc=$?
if [ "$b04_rc" -eq 0 ]; then
  note "FAIL  b04 absent corpus -- the arm exited 0 having observed nothing"; rc=1
elif ! grep -qF "is not a file" <<<"$b04_out"; then
  note "FAIL  b04 absent corpus -- exited $b04_rc but not on the absent-corpus assertion"
  printf '%s\n' "$b04_out" | sed 's/^/      /' | head -3; rc=1
elif grep -qF "OK: validate-backlog-size" <<<"$b04_out"; then
  note "FAIL  b04 absent corpus -- the arm reported a count anyway"; rc=1
else
  note "ok    b04 absent corpus is a finding (exit $b04_rc), not a pass"
fi

# b05 -- the file exists and is empty.
seed "$TMP/b05"; : > "$TMP/b05/docs/backlog.md"
kill_check "b05 an empty file is a finding, not a pass" "$TMP/b05" "" 1 \
  "parsed to ZERO entries"

# b06 -- non-empty prose that parses to ZERO entries. An empty parse and a fully-rotated
# ledger are the same zero.
seed "$TMP/b06"
printf '# Carry-over backlog\n\nEntries were renamed to a shape the predicate does not know.\n\n## BACKLOG-001\n\nBody.\n' \
  > "$TMP/b06/docs/backlog.md"
kill_check "b06 a ledger of prose with no entries is a finding" "$TMP/b06" "" 1 \
  "parsed to ZERO entries"

# ===== THE GRAMMAR, IN BOTH DIRECTIONS. ==================================================
# The trap pulls both ways, which is why this is two probes. A predicate that gets one right
# and the other wrong is the likely implementation, and only firing in both directions
# separates them.

# b07 -- OFFENDER. An entry filed as `### BL-9xx` or `- **BL-9xx**` MUST count. Measured on
# the live file: appending exactly these two shapes leaves `grep -c '^## BL-'` reading 65
# while the shared shape rule sees 67. A ceiling a heading level can evade is not a ceiling.
seed "$TMP/b07"
printf '### BL-901 — filed at h3\n\nBody.\n\n- **BL-902** — filed as a list entry\n\nBody.\n\n' \
  >> "$TMP/b07/docs/backlog.md"
kill_check "b07 h3 and list-form entries DO count" "$TMP/b07" \
  "AI_DLC_BACKLOG_MAX_ENTRIES=$(( BL_K + 1 ))" 1 \
  "carries $(( BL_K + 2 )) entries against a ceiling of $(( BL_K + 1 ))"

# b08 -- NEAR-MISS, and every shape is drawn from the live file. Three classes, each of which
# a plausible predicate gets wrong:
#   - prose and a `verify:` line that QUOTE the heading pattern. docs/backlog.md:91/94/116 do
#     this inside BL-091, and they are why `grep -cE '^[^#]*## BL-'` reads 68 against 65.
#   - a backtick-quoted id opening a prose bullet. docs/backlog.md:174/181/186 do this, and
#     they are why `ledger_entry_id()` -- backtick-tolerant BY DESIGN -- reads 68 here.
#     Control for that measurement: over the archive the two rules agree at 27.
#   - the legend preamble, whose one `^## ` heading is `## Receipts`.
# None may count. The seed keeps BL_K entries and the arm must still say BL_K.
seed "$TMP/b08"
{
  printf '## Receipts\n\n'
  printf 'Entry ids are `BL-`, never `PC-`.\n'
  printf '**52 of the 64 headings in this file carry no title, so an extractor keyed on `## BL-0NN ` gets\n'
  printf '`^## BL-[0-9]+[ \\t]*$` and **12** matching `^## BL-[0-9]+[ \\t]+`, against a total of 64.\n'
  printf -- '- **`BL-081`'"'"'s receipt** returned exit 1 until this sweep re-read it.\n'
  printf -- '- **`BL-066`'"'"'s receipt** exits 9, for a structural reason.\n'
  printf 'verify: sh t="$(grep -cE '"'"'^## BL-[0-9]+'"'"' docs/backlog.md)"; [ "$t" -gt 0 ]\n'
  printf 'See ## BL-903 for the shape this receipt probes.\n'
  printf '  ## BL-904\n'
} >> "$TMP/b08/docs/backlog.md"
count_check "b08 quoted patterns, backticked ids and the legend stay uncounted" "$TMP/b08" "" "$BL_K"

# ===== THE ARCHIVE, BOTH DIRECTIONS. ====================================================

# b09 -- the archive's entries may not reach the clause. Sized so that summing WOULD be
# visible: 40 entries against a ceiling pinned at BL_K.
seed "$TMP/b09"
bl_seed_entries "$TMP/b09/docs/backlog.archive.md" 40
count_check "b09 the archive does not reach the ceiling" "$TMP/b09" \
  "AI_DLC_BACKLOG_MAX_ENTRIES=$BL_K" "$BL_K"

# b10 -- b09's offender twin. Without it, "the archive is excluded" and "the arm reads
# nothing" are the same green.
seed "$TMP/b10" 40
kill_check "b10 the same 40 entries in the LIVE file DO count" "$TMP/b10" \
  "AI_DLC_BACKLOG_MAX_ENTRIES=$BL_K" 1 \
  "carries 40 entries against a ceiling of $BL_K"

# ===== THE POSITIONAL ARGUMENT, BOTH DIRECTIONS. ========================================

# b11 -- the arm reads the ledger it is GIVEN.
seed "$TMP/b11"
bl_seed_entries "$TMP/b11/docs/other-ledger.md" 3
count_check "b11 the positional ledger argument is honoured" "$TMP/b11" "" 3 docs/other-ledger.md

# b12 -- and its twin: the SAME tree with no argument must report the default corpus. Without
# it, an arm that read the argument and an arm that read nothing both satisfy b11 whenever the
# two seeded files happen to agree.
count_check "b12 with no argument the default corpus is read" "$TMP/b11" "" "$BL_K"

# ===== THE SELF-PROBE, BOTH DIRECTIONS. =================================================
# The arm's predicate is LOADED from lib.sh at runtime, so it can be broken by something that
# is not in the arm at all. An arm reporting "65 entries, under the ceiling" over a predicate
# that silently stopped matching reads exactly like a healthy ledger.

# b13 -- OFFENDER. Sabotage `ledger_entry_shape()` in the SEED's copy of lib.sh and the arm
# must exit 2 -- environment error, distinct from 1 for a finding -- and must say the corpus
# was not read. Keyed on the LOCATION (the heading branch of the shape rule) and byte-compared
# before the verdict is read, because a sed anchored on a spelling lib.sh does not carry is a
# no-op that comes back green.
seed "$TMP/b13"
b13_lib="$TMP/b13/core/skills/ai-dlc-update/reconcile/lib.sh"
cp "$b13_lib" "$b13_lib.orig"
# RE-ANCHORED when the shape rule became fence-aware: the branch is now an assignment
# (`else if (… ) sh = "heading"`) inside a larger function, not a bare `return`. Same
# location, same observable -- the heading branch stops matching.
sed 's|else if (l ~ /\^#{2,6}\[ \\t\]/) sh = "heading"|else if (0) sh = "heading"|' "$b13_lib.orig" > "$b13_lib"
if cmp -s "$b13_lib" "$b13_lib.orig"; then
  note "FAIL  b13 -- the sabotage was a NO-OP: lib.sh is byte-identical, so the green below would mean nothing"
  rc=1
else
  b13_out="$(run_v "" "$TMP/b13")"; b13_rc=$?
  if [ "$b13_rc" -ne 2 ]; then
    note "FAIL  b13 -- a sabotaged predicate exited $b13_rc, not 2. The arm must refuse before reading the corpus, not report a count."
    printf '%s\n' "$b13_out" | sed 's/^/      /' | head -4; rc=1
  elif ! grep -qF "SELF-PROBE FAILED" <<<"$b13_out"; then
    note "FAIL  b13 -- exited 2 but not on the self-probe's assertion"
    printf '%s\n' "$b13_out" | sed 's/^/      /' | head -4; rc=1
  elif grep -qF "OK: validate-backlog-size" <<<"$b13_out"; then
    note "FAIL  b13 -- the arm reported a count anyway; the self-probe ran AFTER the corpus"
    rc=1
  else
    note "ok    b13 -- a sabotaged predicate refuses with exit 2, before the corpus is read"
  fi
fi
rm -f "$b13_lib.orig"

# b14 -- NEAR-MISS, and without it b13 proves nothing. A self-probe that trips on ANY edit to
# lib.sh is as useless as one that never trips: it would make every unrelated change to a
# shared library look like a broken predicate. An edit that does not change discrimination
# must leave the arm reporting normally.
seed "$TMP/b14"
b14_lib="$TMP/b14/core/skills/ai-dlc-update/reconcile/lib.sh"
cp "$b14_lib" "$b14_lib.orig"
printf '\n# an unrelated comment appended by the fixture\nledger_unrelated_helper() { :; }\n' >> "$b14_lib"
if cmp -s "$b14_lib" "$b14_lib.orig"; then
  note "FAIL  b14 -- the near-miss edit was a NO-OP, so its quiet proves nothing"; rc=1
else
  count_check "b14 an edit that does not break discrimination is NOT flagged" "$TMP/b14" "" "$BL_K"
fi
rm -f "$b14_lib.orig"

# ===== THE CROSS-CHECK JOINS. ===========================================================
# Bind the arm's local label rule to the SHIPPING classifiers, at fixture time rather than on
# the gate's hot path. NO NUMBER IS HARDCODED in either: a literal would go stale on the next
# filed entry, and equality alone is satisfied by two broken predicates that both return 0, so
# both sides are asserted non-zero as well.

# b15 -- against `scripts/backlog-reverify.sh`, on a 12-entry seed. Reverify emits one row per
# entry with the id in field 2, so its distinct-id count is its view of the population.
if [ -n "$REVERIFY" ]; then
  seed "$TMP/b15" 12
  b15_out="$(run_v "AI_DLC_BACKLOG_MAX_ENTRIES=1000" "$TMP/b15")"
  b15_arm="$(bl_reported "$b15_out")"
  b15_rev="$( cd "$TMP/b15" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null \
    | cut -f2 | sort -u | grep -c . )"
  if [ -z "$b15_arm" ] || [ -z "$b15_rev" ]; then
    note "FAIL  b15 -- a side produced no value (arm='$b15_arm' reverify='$b15_rev')"; rc=1
  elif [ "$b15_arm" -eq 0 ] || [ "$b15_rev" -eq 0 ]; then
    note "FAIL  b15 -- a side counted ZERO (arm=$b15_arm reverify=$b15_rev); two predicates that both find nothing agree perfectly and prove nothing"; rc=1
  elif [ "$b15_arm" -ne "$b15_rev" ]; then
    note "FAIL  b15 -- the ceiling counts $b15_arm entries and backlog-reverify.sh classifies $b15_rev. The ceiling and the classifier disagree about the population."; rc=1
  else
    note "ok    b15 -- ceiling count agrees with backlog-reverify.sh's population at $b15_arm entries"
  fi
else
  note "FAIL  b15 -- backlog-reverify.sh not resolvable, so the classifier join could not be evaluated. A skip here reads exactly like agreement."
  rc=1
fi

# b16 -- the same join against the REAL ledger, which is the one that catches a drift filed
# after this fixture was written.
if [ -n "$REVERIFY" ] && [ -n "$REAL_LEDGER" ]; then
  seed "$TMP/b16"; cp "$REAL_LEDGER" "$TMP/b16/docs/backlog.md"
  b16_out="$(run_v "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/b16")"
  b16_arm="$(bl_reported "$b16_out")"
  b16_rev="$( cd "$TMP/b16" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null \
    | cut -f2 | sort -u | grep -c . )"
  if [ -z "$b16_arm" ] || [ -z "$b16_rev" ] || [ "$b16_arm" -eq 0 ] || [ "$b16_rev" -eq 0 ]; then
    note "FAIL  b16 -- a side produced no usable value (arm='$b16_arm' reverify='$b16_rev')"; rc=1
  elif [ "$b16_arm" -ne "$b16_rev" ]; then
    note "FAIL  b16 -- on the REAL ledger the ceiling counts $b16_arm and backlog-reverify.sh classifies $b16_rev"; rc=1
  else
    note "ok    b16 -- on the real ledger the ceiling and the classifier agree at $b16_arm entries"
  fi
else
  note "FAIL  b16 -- reverify or the real ledger not resolvable; a skip here reads exactly like agreement."
  rc=1
fi

# b17 WAS HERE AND IS DELETED ON PURPOSE. It asserted that the ceiling's label rule and the
# ROTATOR's agreed on the real ledger. That drift is no longer CONSTRUCTIBLE: the rule moved
# into reconcile/lib.sh as `backlog_entry_label_awk()` and both readers now source it, so the
# join has one side and two names for it. A partition beat the check, and a check whose
# subject cannot differ is a guard whose removal changes nothing -- keeping it would have left
# a green arm asserting a tautology.

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-size-ceiling -- control green, 16/16 probes hold"
fi
exit "$rc"
