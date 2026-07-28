#!/usr/bin/env bash
# Exercise the anchor-declaration checks in validate-layer-entries.sh: E7 (a `shadows:` anchor
# must FORWARD-match a heading), E8 (`reason:` required), E9 (`push_candidate:` required), and
# E3's widening to every comma-part of `shadows:`.
#
# TWO OF THESE ASSERTIONS EXIST BECAUSE THE FIRST DRAFT SHIPPED THE BUG:
#
#   1. The old code ran `sed 's/,.*//'` on `shadows:` and validated only the FIRST comma-part.
#      Measured on the reference consumer, one override declares five anchors and got one file
#      check and ZERO anchor checks. `multi` below is valid in part one and broken in part two, so
#      a first-part-only reader calls it clean.
#
#   2. The loop was written as `printf | tr | while`, and a pipeline runs its last stage in a
#      SUBSHELL — so every err() incremented a counter in a child process and threw it away. The
#      ERROR lines printed and the footer counted ONE of THREE: a validator that reports a real
#      violation and then exits zero. `count-matches-lines` is the guard, and it is not a style
#      check — loud and non-blocking is the worst of the two failure directions.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Both layouts: distribution has the validator at core/scripts/, a consumer at scripts/ai-dlc/
# (install.sh relocates it, and fixtures move to tests/fixtures/, which is THREE levels up).
VLE=""; LOOKED=""
for cand in \
  "$DIR/../../scripts/validate-layer-entries.sh" \
  "$DIR/../../../core/scripts/validate-layer-entries.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-layer-entries.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && VLE="$cand" && break
done
[ -n "$VLE" ] || { printf 'FAIL: cannot locate validate-layer-entries.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }

CONS="$(bash "$DIR/seed.sh")"
trap 'rm -rf "$(dirname "$CONS")"' EXIT

OUT="$(bash "$VLE" "$CONS" 2>&1)"

FAILURES=0
ASSERTIONS=0

# $1 entry-substring  $2 expected-substring in the row (or "CLEAN")  $3 why
row() {
  local ent="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | grep -F "$ent" | grep '^ERROR' || true)"
  if [ "$want" = CLEAN ]; then
    if [ -z "$got" ]; then
      printf '  ok    %-26s no error  (%s)\n' "$ent" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-26s errored but must not  (%s)\n' "$ent" "$why"
      printf '%s\n' "$got" | sed 's/^/          | /'
    fi
  elif printf '%s\n' "$got" | grep -qF "$want"; then
    printf '  ok    %-26s %s  (%s)\n' "$ent" "$want" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s wanted "%s"  (%s)\n' "$ent" "$want" "$why"
    printf '%s\n' "${got:-<no error row>}" | sed 's/^/          | /'
  fi
}

echo "layer-anchor-declaration fixture"
echo

# THE DIFFERENTIAL. Same file, same kind of anchor, opposite verdicts — and the ONLY difference is
# which direction the containment resolves.
row "SKILL__Rule-8.md"                 CLEAN \
  "a heading CONTAINING the anchor is the legitimate id-prefix grain"
row "team-roles__tea__escalation.md"   "Escalation" \
  "an anchor CONTAINING the heading resolves only by the reverse arm and silently widens the shadow"

# The error must hand over the fix, not just the diagnosis: a consumer cannot act on "wrong" but
# can act on "write it as this".
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'team-roles__tea__escalation.md' | grep -q "Write the anchor as 'Escalation'"; then
  printf '  ok    %-26s names the exact heading to substitute\n' "remedy-is-actionable"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s reported the defect without the heading to replace it with\n' "remedy-is-actionable"
fi

row "steps__retro__ghost.md"           "matches no heading" \
  "an anchor matching nothing means the body never reaches the lead while checks report green"

# THE BLIND SPOT. Part one is valid; part two is not. A first-part-only reader sees nothing.
row "steps__retro__multi.md"           "Empirical gate validation" \
  "every comma-part is validated, not just the first"

# THE SECOND BLIND SPOT, inside the fix for the first. The per-part widening still computed the
# target per part, so a part that inherits its file computed an EMPTY one and was skipped before
# any anchor check ran. Measured on the reference consumer: 1 of 4 anchors checked, 3 skipped.
# The wanted substring is the ANCHOR arm's wording, not the anchor text. The target-less arm below
# quotes the whole part — `#No Such Inherited Heading` — so a bare anchor-text match is satisfied by
# an entry that resolved no file at all, and the assertion would pass while the fix was reverted.
# Mutation 3 caught exactly that.
row "steps__retro__inherit.md"         "Inherited Heading' matches no heading in steps/retro.md" \
  "a bare '#anchor' part inherits the file from the part before it and is still anchor-checked"
row "steps__retro__orphan.md"          "names no target file" \
  "a first part with no file has nothing to inherit, and silence there skips every check on the entry"

row "SKILL__Rule-9.md"                 "missing 'reason:'" \
  "reason: was declared by the contract and read by nothing"
row "no-flag.md"                       "missing 'push_candidate:'" \
  "push_candidate: was declared by the contract and read by nothing"
row "ok-extension.md"                  CLEAN \
  "a well-formed extension stays silent, so the two above are attributable"

# THE COUNTER GUARD. Every ERROR line must be counted, or the exit code does not match what the
# operator was just shown.
ASSERTIONS=$((ASSERTIONS + 1))
lines="$(printf '%s\n' "$OUT" | grep -c '^ERROR' || true)"
counted="$(printf '%s\n' "$OUT" | sed -n 's/^validate-layer-entries: \([0-9]*\) error(s).*/\1/p')"
bash "$VLE" "$CONS" >/dev/null 2>&1; rc=$?
if [ "$lines" = "$counted" ] && [ "$rc" -ne 0 ]; then
  printf '  ok    %-26s %s ERROR lines, footer says %s, exit %s\n' "count-matches-lines" "$lines" "$counted" "$rc"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s %s ERROR lines but footer says %s and exit is %s — a reported violation that does not block\n' "count-matches-lines" "$lines" "$counted" "$rc"
fi

# --- MUTATION 1: restore the first-part-only read ------------------------------------
# THE FIRST VERSION OF THIS MUTANT WAS A BYTE-DIFFERENT NO-OP, and `cmp -s` passed it. It inserted
# a `sed 's/,.*//'` on `$part` — but by then the value has ALREADY been comma-split, so there was
# no comma left to strip and the mutant behaved exactly like the original. The fixture caught it
# ("still caught part two"), which is the whole reason a mutant asserts a CHANGE in outcome and
# not merely that the bytes moved. `cmp -s` proves a mutation happened; only the assertion proves
# it mutated the thing under test.
#
# The honest mutation is to stop iterating after the first part, which is what the old code did.
# `_seen_part` is reset per ENTRY, not once globally: a global reset would also blind the checker
# to the single anchors of every later entry, and a mutant that breaks four assertions instead of
# one is entangled and proves none of them.
MUT1="$(dirname "$CONS")/mut-firstpart"
rm -rf "$MUT1"; mkdir -p "$MUT1"
awk '
  /^    while IFS= read -r part; do$/ {
    print "    _seen_part=\"\""
    print
    print "      [ -z \"$_seen_part\" ] || continue"
    print "      _seen_part=1"
    next
  }
  { print }
' "$VLE" > "$MUT1/vle.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$VLE" "$MUT1/vle.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s the mutation matched nothing, so the multi-anchor assertion is unproven\n' "mutation-firstpart"
else
  m1all="$(bash "$MUT1/vle.sh" "$CONS" 2>&1)"
  m1="$(printf '%s\n' "$m1all" | grep -F 'steps__retro__multi.md' | grep -c '^ERROR' || true)"
  # It must lose part two AND nothing else: the single-anchor entries still error.
  m1keep="$(printf '%s\n' "$m1all" | grep -F 'team-roles__tea__escalation.md' | grep -c '^ERROR' || true)"
  if [ "$m1" -eq 0 ] && [ "$m1keep" -gt 0 ]; then
    printf '  ok    %-26s first-part-only read goes blind to the second anchor, and only that\n' "mutation-firstpart"
  elif [ "$m1" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s the mutant still caught part two, so the assertion above is vacuous\n' "mutation-firstpart"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s the mutant also lost a single-anchor entry, so it is entangled and proves nothing\n' "mutation-firstpart"
  fi
fi

# --- MUTATION 2: restore the pipeline, losing the counter to a subshell ---------------
MUT2="$(dirname "$CONS")/mut-subshell"
rm -rf "$MUT2"; mkdir -p "$MUT2"
awk '
  /^    while IFS= read -r part; do$/ { print "    printf \"%s\\n\" \"$shadows\" | tr \",\" \"\\n\" | while IFS= read -r part; do"; inloop=1; next }
  inloop && /^    done <<EOF$/ { print "    done"; skip=2; inloop=0; next }
  skip > 0 { skip--; next }
  { print }
' "$VLE" > "$MUT2/vle.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$VLE" "$MUT2/vle.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s the mutation matched nothing, so the counter assertion is unproven\n' "mutation-subshell"
else
  m2out="$(bash "$MUT2/vle.sh" "$CONS" 2>&1)"
  m2lines="$(printf '%s\n' "$m2out" | grep -c '^ERROR' || true)"
  m2count="$(printf '%s\n' "$m2out" | sed -n 's/^validate-layer-entries: \([0-9]*\) error(s).*/\1/p')"
  if [ -n "$m2count" ] && [ "$m2lines" != "$m2count" ]; then
    printf '  ok    %-26s pipeline loses the count in a subshell (%s lines, footer %s)\n' "mutation-subshell" "$m2lines" "$m2count"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s the pipeline mutant counted correctly (%s lines, footer %s), so the guard is vacuous\n' "mutation-subshell" "$m2lines" "${m2count:-<none>}"
  fi
fi

# --- MUTATION 3: stop carrying the target forward, restoring the inheriting-form skip -----
# The honest revert is to make an inheriting part resolve to an EMPTY target again, which is what
# `tgt="${part%%#*}"` produced for it before the carry-forward. It must lose the inherited anchor
# and NOTHING else: `multi` (file repeated per part) and `orphan` (no file anywhere) are the two
# neighbours this could take with it, and both are asserted to survive. A mutant that also
# silenced them would be entangled and would prove none of the three.
MUT3="$(dirname "$CONS")/mut-noinherit"
rm -rf "$MUT3"; mkdir -p "$MUT3"
awk '{ sub(/^        tgt="\$inherited_tgt"$/, "        tgt=\"\""); print }' "$VLE" > "$MUT3/vle.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$VLE" "$MUT3/vle.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s the mutation matched nothing, so the inheriting-form assertion is unproven\n' "mutation-noinherit"
else
  m3all="$(bash "$MUT3/vle.sh" "$CONS" 2>&1)"
  m3="$(printf '%s\n' "$m3all" | grep -F 'steps__retro__inherit.md' | grep -cF "Inherited Heading' matches no heading in steps/retro.md" || true)"
  m3keep="$(printf '%s\n' "$m3all" | grep -F 'steps__retro__multi.md' | grep -c '^ERROR' || true)"
  m3orph="$(printf '%s\n' "$m3all" | grep -F 'steps__retro__orphan.md' | grep -c '^ERROR' || true)"
  if [ "$m3" -eq 0 ] && [ "$m3keep" -gt 0 ] && [ "$m3orph" -gt 0 ]; then
    printf '  ok    %-26s an inheriting part loses its anchor check, and only that\n' "mutation-noinherit"
  elif [ "$m3" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s the mutant still anchor-checked the inherited part, so the assertion above is vacuous\n' "mutation-noinherit"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s the mutant also silenced a neighbour (multi=%s orphan=%s), so it is entangled\n' "mutation-noinherit" "$m3keep" "$m3orph"
  fi
fi

# --- MUTATION 4: drop the no-inheritable-target diagnostic -------------------------------
# Deleting only the err() leaves the `continue` in place, which is exactly the old behaviour: the
# part is skipped and nobody is told. `inherit` must keep erroring, or the two arms are one arm.
MUT4="$(dirname "$CONS")/mut-noorphan"
rm -rf "$MUT4"; mkdir -p "$MUT4"
awk '/names no target file/ { next } { print }' "$VLE" > "$MUT4/vle.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$VLE" "$MUT4/vle.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s the mutation matched nothing, so the orphan assertion is unproven\n' "mutation-noorphan"
else
  m4all="$(bash "$MUT4/vle.sh" "$CONS" 2>&1)"
  m4="$(printf '%s\n' "$m4all" | grep -F 'steps__retro__orphan.md' | grep -c '^ERROR' || true)"
  m4keep="$(printf '%s\n' "$m4all" | grep -F 'steps__retro__inherit.md' | grep -c '^ERROR' || true)"
  if [ "$m4" -eq 0 ] && [ "$m4keep" -gt 0 ]; then
    printf '  ok    %-26s a target-less first part disappears in silence, and only that\n' "mutation-noorphan"
  elif [ "$m4" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s the mutant still reported the orphan, so the assertion above is vacuous\n' "mutation-noorphan"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s the mutant also silenced the inheriting entry, so it is entangled\n' "mutation-noorphan"
  fi
fi

# --- THE UNMUTATED CONTROL ------------------------------------------------------------
# Both mutants are copies into fresh directories. A copy that cannot run emits nothing, and
# "nothing" would score as a kill for BOTH mutants above. This copy is byte-identical to the
# detector, so it must reproduce the real verdict exactly.
CTL="$(dirname "$CONS")/ctl"
rm -rf "$CTL"; mkdir -p "$CTL"; cp "$VLE" "$CTL/vle.sh"
ASSERTIONS=$((ASSERTIONS + 1))
ctl_lines="$(bash "$CTL/vle.sh" "$CONS" 2>&1 | grep -c '^ERROR' || true)"
if [ "$ctl_lines" = "$lines" ]; then
  printf '  ok    %-26s unmutated copy reproduces %s ERROR lines (harness is sound)\n' "mutation-control" "$ctl_lines"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s unmutated copy emitted %s ERROR lines, want %s — a copy that cannot run scores as a kill\n' "mutation-control" "$ctl_lines" "$lines"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
