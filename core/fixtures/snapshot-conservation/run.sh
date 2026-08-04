#!/usr/bin/env bash
# snapshot-conservation/run.sh — prove Check 35 can tell a snapshot whose content
# was MOVED from one whose content was destroyed.
#
# THE DEFECT. Rule 25(a) says superseded snapshot content moves to a history file
# and is never deleted. Everything built around that rule measures the file's SIZE,
# and a file that got smaller looks identical whether the bytes were moved or
# dropped. Measured in the reference consumer over one sprint: 2,141 of 2,524
# substantive lines removed from the snapshot exist nowhere in the repository —
# gate dispositions, operator override citations, adversarial verdicts — while the
# byte budget passed throughout.
#
# THE ASSERTIONS THAT MATTER MOST are 2 and 7, both places where the comfortable
# reading fails OPEN:
#   2. Deleting content without moving it must FAIL. If this passes, the check is
#      decoration: every real eviction in the corpus that motivated it deleted.
#   7. A gate-metrics file that exists but cannot be parsed must exit 2, not 0.
#      Returning "nothing to compare" from a broken input is a clean line reporting
#      a verdict that was never computed.
#
# ASSERTION 1 IS NOT A FORMALITY. A conservation check that cannot go green wedges
# every sprint that legitimately trims, which is how a check gets turned off.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json.
# A fixture that drives a validator while inheriting them tests the CONFIG, not the
# code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

LAST_OUT=""
# Each case gets its own copy of the seeded repository, so a working-tree edit in one
# case cannot leak into the next.
case_dir() {
  d="$WORK/case-$1"
  rm -rf "$d"
  cp -R "$PROJ" "$d" || return 1
  printf '%s' "$d"
}
# NOT a command substitution. Capturing the runner's output with `r=$(run_on ...)`
# puts it in a subshell, LAST_OUT never reaches the caller, and every message that
# quotes it prints an empty string -- which reads like the validator said nothing.
RC=""
run_on() {
  LAST_OUT="$(bash "$VALIDATOR" --root "$1" "${@:2}" 2>&1)"
  RC="$?"
}
field() { printf '%s\n' "$LAST_OUT" | sed -n "s/^$1 *: *\([^ ]*\).*/\1/p" | head -1; }

# Drop the last N of the 60 seeded OI lines out of the snapshot.
#
# The guard is not decoration. The first version of this matched on a date pattern
# that did not match what the seed writes, so it cut NOTHING -- and a fixture whose
# every case leaves the snapshot untouched reports the validator passing everything,
# which is indistinguishable from a validator with no teeth.
cut_lines() { # <dir> <count>
  d="$1"; n="$2"
  grep -- '^- OI-' "$d/_bmad-output/pipeline-snapshot.md" | tail -n "$n" > "$WORK/cut.txt"
  cut_n="$(wc -l < "$WORK/cut.txt" | tr -d ' ')"
  if [ "$cut_n" -ne "$n" ]; then
    bad "FIXTURE BROKEN: cut_lines was asked for $n lines and selected $cut_n — the case below would run against an unmodified snapshot"
    return 1
  fi
  grep -v -F -x -f "$WORK/cut.txt" "$d/_bmad-output/pipeline-snapshot.md" > "$d/snap.tmp"
  mv "$d/snap.tmp" "$d/_bmad-output/pipeline-snapshot.md"
  remaining="$(grep -c -- '^- OI-' "$d/_bmad-output/pipeline-snapshot.md" || true)"
  if [ "$remaining" -ne "$(( 60 - n ))" ]; then
    bad "FIXTURE BROKEN: after cutting $n lines the snapshot holds $remaining of the 60, not $(( 60 - n ))"
    return 1
  fi
  return 0
}

echo "snapshot-conservation:"

# --- Seed sanity: without this every assertion below compares against nothing -----
seeded="$(grep -c -- '- OI-' "$PROJ/_bmad-output/pipeline-snapshot.md" 2>/dev/null || echo 0)"
if [ "$seeded" -ne 60 ]; then
  bad "SEED BROKEN: expected 60 substantive snapshot lines, found $seeded"
  echo; echo "snapshot-conservation: $fails assertion(s) FAILED" >&2; exit 1
fi

# --- Assertion 1: content MOVED to the history file passes ----------------------
d="$(case_dir moved)"
cut_lines "$d" 50
cat "$WORK/cut.txt" >> "$d/_bmad-output/pipeline-snapshot-history.md"
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "50 lines moved to pipeline-snapshot-history.md passes"
else
  bad "the conserved case did not pass (rc=$r) — a check that cannot go green wedges every legitimate trim: $LAST_OUT"
fi

# --- Assertion 2: content DELETED fails -----------------------------------------
# The whole release is this line. Every eviction in the corpus that motivated the
# check looked exactly like this one.
d="$(case_dir deleted)"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "1" ]; then
  ok "50 lines deleted without moving them FAILS"
else
  bad "DELETION PASSED (rc=$r) — the check does not distinguish a move from a deletion, which is the only thing it exists to do: $LAST_OUT"
fi

# --- Assertion 3: the count it reports is the count that was destroyed -----------
if [ "$(field lines_destroyed)" = "50" ]; then
  ok "the deleted case reports lines_destroyed: 50"
else
  bad "expected lines_destroyed: 50, got '$(field lines_destroyed)' — the number in the message is not the number it measured"
fi

# --- Assertion 4: below the floor, destruction does not block -------------------
# Bounds the false-positive class. Rewording a handful of lines is indistinguishable
# from deleting them, and blocking on that is how a check gets switched off.
d="$(case_dir belowfloor)"
cut_lines "$d" 10
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "10 destroyed lines stay below the floor of 40 and do not block"
else
  bad "the below-floor case blocked (rc=$r) — the floor is not bounding the false-positive class: $LAST_OUT"
fi

# --- Assertion 5: relocation WITHIN the snapshot is conservation -----------------
d="$(case_dir within)"
cut_lines "$d" 50
{ echo; echo "## Recent Activity"; cat "$WORK/cut.txt"; } >> "$d/_bmad-output/pipeline-snapshot.md"
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "content moved to another section of the same snapshot is conserved"
else
  bad "relocation within the snapshot read as destruction (rc=$r) — the corpus excludes the file being measured: $LAST_OUT"
fi

# --- Assertion 6: a re-indented move is still a move ----------------------------
d="$(case_dir indent)"
cut_lines "$d" 50
sed 's/^/    /' "$WORK/cut.txt" >> "$d/_bmad-output/pipeline-snapshot-history.md"
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "a move that re-indents the content is conserved"
else
  bad "re-indenting on the way to history read as destruction (rc=$r) — only one side of the comparison is normalised: $LAST_OUT"
fi

# --- Assertion 7: a metrics file that cannot be parsed is exit 2, not a pass -----
d="$(case_dir unparseable)"
printf 'not json at all\nstill not json\n' > "$d/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "2" ]; then
  ok "gate-metrics.jsonl present but unparseable exits 2"
else
  bad "an unreadable metrics file returned rc=$r — a broken input must not produce a verdict: $LAST_OUT"
fi

# --- Assertion 8: no metrics file at all is NOT-APPLICABLE, and says so ----------
d="$(case_dir nometrics)"
rm -f "$d/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "0" ] && grep -q 'NOT-APPLICABLE' <<<"$LAST_OUT"; then
  ok "a repository with no closed gate is NOT-APPLICABLE, not a silent pass"
else
  bad "expected rc=0 with an explicit NOT-APPLICABLE, got rc=$r: $LAST_OUT"
fi

# --- Assertion 9: the zero-control ----------------------------------------------
# `CLAUDE.md`: a run whose answer is an absence must say what it examined. Without
# these fields "nothing was destroyed" and "nothing was scanned" print the same line.
if grep -q '^base_sha' <<<"$LAST_OUT" && grep -q '^lines_destroyed' <<<"$LAST_OUT"; then
  ok "the NOT-APPLICABLE path still emits base_sha and lines_destroyed"
else
  bad "the NOT-APPLICABLE path printed no base_sha/lines_destroyed — an absence that does not report its scope"
fi

# --- Assertion 10: recorded shas that do not resolve are not an error ------------
# Measured in the reference consumer: only 10 of 34 recorded gate shas resolve. If
# an unresolvable newest sha were fatal, the check would be unrunnable at most gates.
d="$(case_dir unresolvable)"
printf '{"v":1,"sprint":300,"gate":"planning","sha":"%s","check":"14","verdict":"PASS"}\n' \
  "0000000000000000000000000000000000000000" > "$d/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "0" ] && grep -q 'NOT-APPLICABLE' <<<"$LAST_OUT"; then
  ok "gate shas that resolve to nothing degrade to NOT-APPLICABLE"
else
  bad "an unresolvable gate sha returned rc=$r instead of NOT-APPLICABLE: $LAST_OUT"
fi

# --- Assertion 11: outside a git repository, exit 2 ------------------------------
d="$(case_dir nogit)"
rm -rf "$d/.git"
run_on "$d"
r="$RC"
if [ "$r" = "2" ]; then
  ok "outside a git repository the check exits 2 rather than reporting conservation"
else
  bad "a non-repository returned rc=$r — a git-derived join cannot have an opinion without history: $LAST_OUT"
fi

# --- Assertion 12: --floor is honoured ------------------------------------------
d="$(case_dir floorflag)"
cut_lines "$d" 10
run_on "$d" --floor 5
r="$RC"
if [ "$r" = "1" ]; then
  ok "--floor 5 makes the 10-line case block, so the floor is a real parameter"
else
  bad "--floor 5 did not change the verdict (rc=$r) — the floor is not wired to the comparison: $LAST_OUT"
fi

# =============================================================================
# MUTANTS. Copies, never in-place edits. `cmp -s` proves the mutation landed and
# `bash -n` proves the result is still a program — a copy that dies on a syntax
# error emits nothing, and "no output" otherwise scores as a kill.
# =============================================================================

# The unmutated control. This validator resolves its own root by walking up from its
# own location, so a copy placed elsewhere must still behave identically before any
# mutant verdict below means anything.
CTRL="$WORK/validator-control.sh"
cp "$VALIDATOR" "$CTRL"
d="$(case_dir ctrl_moved)"; cut_lines "$d" 50; cat "$WORK/cut.txt" >> "$d/_bmad-output/pipeline-snapshot-history.md"
c1="$(LAST_OUT=""; LAST_OUT="$(bash "$CTRL" --root "$d" 2>&1)"; printf '%s' "$?")"
d="$(case_dir ctrl_deleted)"; cut_lines "$d" 50
c2="$(LAST_OUT=""; LAST_OUT="$(bash "$CTRL" --root "$d" 2>&1)"; printf '%s' "$?")"
if [ "$c1" = "0" ] && [ "$c2" = "1" ]; then
  ok "CONTROL: an unmutated copy reproduces 0 (moved) and 1 (deleted)"
else
  bad "CONTROL FAILED: an unmutated copy returned $c1/$c2 instead of 0/1, so no mutant result below means anything"
fi

# --- Assertion 13: MUTANT A — the corpus stops including the history file --------
# Proves assertion 1 is load-bearing: if the history file is not searched, moving
# content there is indistinguishable from deleting it.
MUT_A="$WORK/validator-mutant-a.sh"
if [ "$(grep -c -- "ls-files -z -- '\*.md'" "$VALIDATOR")" -ne 1 ]; then
  bad "FIXTURE STALE: mutant A's anchor is not unique in the validator, so the mutation could land somewhere else and come out green"
else
  sed "s|ls-files -z -- '\*.md'|ls-files -z -- '*pipeline-snapshot.md'|" "$VALIDATOR" > "$MUT_A"
  if cmp -s "$VALIDATOR" "$MUT_A"; then
    bad "FIXTURE STALE: mutant A is byte-identical to the original — the corpus glob was reworded"
  elif ! bash -n "$MUT_A" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant A is not a valid shell script, so a 'kill' below would only mean the copy could not run"
  else
    d="$(case_dir mutA_moved)"; cut_lines "$d" 50; cat "$WORK/cut.txt" >> "$d/_bmad-output/pipeline-snapshot-history.md"
    ra="$(bash "$MUT_A" --root "$d" >/dev/null 2>&1; printf '%s' "$?")"
    if [ "$ra" = "1" ]; then
      ok "mutant A: dropping the history file from the corpus makes a real move read as destruction — assertion 1 has teeth"
    else
      bad "MUTANT A DID NOT FAIL (rc=$ra) — assertion 1 is not testing whether the history file is searched"
    fi
    d="$(case_dir mutA_below)"; cut_lines "$d" 10
    rb="$(bash "$MUT_A" --root "$d" >/dev/null 2>&1; printf '%s' "$?")"
    if [ "$rb" = "0" ]; then
      ok "mutant A leaves the below-floor assertion intact — the arms are not entangled"
    else
      bad "mutant A ALSO broke the below-floor case (rc=$rb) — two failures mean one of the assertions is vacuous"
    fi
  fi
fi

# --- Assertion 14: MUTANT B — the floor stops being consulted --------------------
MUT_B="$WORK/validator-mutant-b.sh"
if [ "$(grep -c 'GONE" -lt "\$FLOOR' "$VALIDATOR")" -ne 1 ]; then
  bad "FIXTURE STALE: mutant B's anchor is not unique in the validator"
else
  # The floor becomes 1, not 0. At 0 the mutant fails the CONSERVED case too --
  # nothing destroyed is not less than nothing -- and a mutant that breaks two
  # assertions proves neither of them.
  sed 's|GONE" -lt "\$FLOOR"|GONE" -lt 1|' "$VALIDATOR" > "$MUT_B"
  if cmp -s "$VALIDATOR" "$MUT_B"; then
    bad "FIXTURE STALE: mutant B is byte-identical to the original — the floor comparison was reworded"
  elif ! bash -n "$MUT_B" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant B is not a valid shell script"
  else
    d="$(case_dir mutB_below)"; cut_lines "$d" 10
    rb="$(bash "$MUT_B" --root "$d" >/dev/null 2>&1; printf '%s' "$?")"
    if [ "$rb" = "1" ]; then
      ok "mutant B: ignoring the floor makes 10 destroyed lines block — the floor is what bounds the false-positive class"
    else
      bad "MUTANT B DID NOT FAIL (rc=$rb) — the floor comparison is not what decides the below-floor case"
    fi
    d="$(case_dir mutB_moved)"; cut_lines "$d" 50; cat "$WORK/cut.txt" >> "$d/_bmad-output/pipeline-snapshot-history.md"
    rc2="$(bash "$MUT_B" --root "$d" >/dev/null 2>&1; printf '%s' "$?")"
    if [ "$rc2" = "0" ]; then
      ok "mutant B leaves the conserved case intact — the arms are not entangled"
    else
      bad "mutant B ALSO broke the conserved case (rc=$rc2) — the assertions are entangled"
    fi
  fi
fi

# --- Assertion 15: MUTANT C — a broken metrics file becomes a clean pass ---------
# Anchored on a backslash-free string. `awk -v` processes escape sequences in the
# assigned value, so an anchor carrying a backslash arrives stripped and the mutation
# silently does nothing while scoring as a kill.
MUT_C="$WORK/validator-mutant-c.sh"
if [ "$(grep -c 'carries no parseable' "$VALIDATOR")" -ne 1 ]; then
  bad "FIXTURE STALE: mutant C's anchor is not unique in the validator"
else
  awk '
    /carries no parseable/ { seen = 1 }
    seen && /^    exit 2$/ && !done { sub(/exit 2/, "exit 0"); done = 1 }
    { print }
  ' "$VALIDATOR" > "$MUT_C"
  if cmp -s "$VALIDATOR" "$MUT_C"; then
    bad "FIXTURE STALE: mutant C is byte-identical to the original — the unparseable-metrics arm was reworded or re-indented"
  elif ! bash -n "$MUT_C" 2>/dev/null; then
    bad "FIXTURE BROKEN: mutant C is not a valid shell script"
  else
    d="$(case_dir mutC)"
    printf 'not json at all\n' > "$d/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
    cut_lines "$d" 50
    rc3="$(bash "$MUT_C" --root "$d" >/dev/null 2>&1; printf '%s' "$?")"
    if [ "$rc3" != "2" ]; then
      ok "mutant C: letting an unparseable metrics file through stops it exiting 2 — assertion 7 has teeth"
    else
      bad "MUTANT C DID NOT CHANGE THE VERDICT (rc=$rc3) — assertion 7 is not testing the unparseable arm"
    fi
    d="$(case_dir mutC_deleted)"; cut_lines "$d" 50
    rc4="$(bash "$MUT_C" --root "$d" >/dev/null 2>&1; printf '%s' "$?")"
    if [ "$rc4" = "1" ]; then
      ok "mutant C leaves the deletion assertion intact — the arms are not entangled"
    else
      bad "mutant C ALSO broke the deletion case (rc=$rc4) — the assertions are entangled"
    fi
  fi
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "snapshot-conservation: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "snapshot-conservation: all assertions passed"
