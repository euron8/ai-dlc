#!/usr/bin/env bash
# artifact-path-conformance — validate-artifact-paths.sh holds a consumer's REAL filenames to
# the declared grammar, blocks on exactly the set the migration would move, and reports the rest
# rather than wedging a tree nobody can clean.
#
# WHAT THIS EXISTS TO CATCH, and the first two were measured on the reference consumer while the
# validator was being written -- neither was found by reading it.
#
#  - THE SLOT RESOLVED AGAINST DECLARED AREAS ALONE. 92 already-conforming paths under areas the
#    consumer had never declared (`_bmad-output/brainstorming/s166/…`) were reported as
#    violations, on a tree whose migration planned ZERO moves. An undeclared area is a paperwork
#    gap the migration REPORTS; it is not a path defect, and blocking on it would have wedged
#    first contact on a tree whose operator had already done everything core asked.
#  - A PREDICATE THAT CANNOT FIRE. The whole verdict rides on one expression resolved at runtime
#    out of a file on disk. An expression matching nothing returns the same empty blocking set as
#    a fully-migrated tree. The validator therefore probes itself every run, and the
#    `token-re-dead` mutant below is that probe's proof.
#  - AN EMPTY SUBJECT SPELLED LIKE A PASS. A greenfield consumer has no artifact under any scan
#    root. Failing it makes the grammar unadoptable; printing PASS is a zero-verification pass.
#
# THE VERDICT IS NEVER TAKEN FROM THE SUMMARY LINE. The blocking set is read row by row and
# joined against what the MIGRATION actually moved, in both directions, so neither program can
# drift into disagreeing with the other about which paths this convention governs.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }

# install.sh maps core/scripts/<x> -> scripts/ai-dlc/<x>; core/skills/ai-dlc/ -> .claude/skills/ai-dlc/.
VAL="$(pick "$HERE/../../scripts/validate-artifact-paths.sh" \
            "$HERE/../../../scripts/ai-dlc/validate-artifact-paths.sh" \
            "$HERE/../../core/scripts/validate-artifact-paths.sh")"
MIG="$(pick "$HERE/../../scripts/migrate-artifact-paths.sh" \
            "$HERE/../../../scripts/ai-dlc/migrate-artifact-paths.sh" \
            "$HERE/../../core/scripts/migrate-artifact-paths.sh")"
CONFIG="$(pick "$HERE/../../scripts/artifact-path-config.sh" \
               "$HERE/../../../scripts/ai-dlc/artifact-path-config.sh" \
               "$HERE/../../core/scripts/artifact-path-config.sh")"
GRAMMAR="$(pick "$HERE/../../skills/ai-dlc/artifact-path-grammar.md" \
                "$HERE/../../../.claude/skills/ai-dlc/artifact-path-grammar.md" \
                "$HERE/../../core/skills/ai-dlc/artifact-path-grammar.md")"
[ -n "$VAL" ] && [ -n "$MIG" ] && [ -n "$CONFIG" ] && [ -n "$GRAMMAR" ] \
  || { echo "FIXTURE ERROR: cannot locate validate-artifact-paths.sh, migrate-artifact-paths.sh, artifact-path-config.sh and/or artifact-path-grammar.md" >&2; exit 2; }

fails=0; asserts=0
ok()  { asserts=$((asserts+1)); printf '  ok    %s\n' "$1"; }
bad() { asserts=$((asserts+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }

# The validator prints one indented path per blocking row. Read the PATHS, never the count line.
blocking_of() { sed -n '/^BLOCKING —/,/^$/p' <<<"$1" | sed -n 's/^  \([^ ].*\)$/\1/p' | grep -v '^(' | sort; }

echo "artifact-path-conformance:"

# =============================================================================
# 1. A PRE-MIGRATION TREE. Every class must land in the right one, and the three
#    that must NOT block are as load-bearing as the ones that must.
# =============================================================================
W="$(bash "$HERE/seed.sh" "$GRAMMAR")"
OUT="$(bash "$VAL" --root "$W" 2>&1)"; RC=$?

[ "$RC" -eq 1 ] && ok "a tree with migratable violations exits 1" \
                || bad "expected exit 1 on a non-conforming tree, got $RC"

# $1 path  $2 expected substring context  — asserted against the BLOCKING block, not the summary
blocks() {
  if grep -qxF "$1" <<<"$(blocking_of "$OUT")"; then ok "BLOCKS  $1 — $2"
  else bad "did NOT block  $1 — $2"; fi
}
allows() {
  if grep -qxF "$1" <<<"$(blocking_of "$OUT")"; then bad "BLOCKED  $1 — $2, so it must not block"
  else ok "allows  $1 — $2"; fi
}

blocks "_bmad-output/planning-artifacts/s301-research-notes.md"                  "basename token in the prefix position"
blocks "_bmad-output/implementation-artifacts/gate-log-archive-s301.md"          "basename token in the SUFFIX position, which a whole-component match misses"
blocks "docs/retro/sprint-301.md"                                                "the sprint-<N> word form"
blocks "docs/reviews/S301-1-code-review.md"                                      "uppercase S, which a case-sensitive read would miss"
blocks "_bmad-output/implementation-artifacts/sprint-301/smoke-evidence/shot.png" "a DIRECTORY token, with a clean basename inside"
blocks "_bmad-output/planning-artifacts/s301/s301-cycle-1/notes.md"              "a token BELOW a correct slot: the exemption is positional, not per-spelling"

allows "_bmad-output/planning-artifacts/s301/architecture-context.md"            "conforming under a DECLARED area"
allows "docs/retro/s300/retro.md"                                                "conforming under a DECLARED area"
allows "_bmad-output/brainstorming/s301/discovery-brainstorming.md"              "conforming under an INFERRED area — the 92-false-positive case"
allows "_bmad-output/planning-artifacts/prd.md"                                  "durable at an area root, no sprint anywhere"
allows "_bmad-output/implementation-artifacts/gate-log-archive-s298-s299.md"     "AMBIGUOUS: the migration refuses it, so nothing here can clear it"
allows "_bmad-output/s177/wave-1-dispatch-status.md"                             "NO-AREA: the migration refuses it, so nothing here can clear it"
allows "_bmad-output/planning-artifacts/stories/bug-mobile-layout.md"            "STORY-NO-SPRINT: the migration cannot place it, so nothing here can clear it"
allows "_bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md"       "a conforming story under s<N>/ — its leading number is not a sprint slot"

blocks "_bmad-output/planning-artifacts/stories/story-S301-1-alpha.md"           "a story outside the slot, explicit token"
blocks "_bmad-output/planning-artifacts/stories/story-297-1-beta.md"             "and its BARE-number sibling, or the corpus blocks by half"

# The non-blocking classes are REPORTED. Silence about them is this repo's own named defect one
# layer out, so each is asserted to appear with its own name.
for cls in AMBIGUOUS NO-AREA STORY-NO-SPRINT; do
  grep -q "$cls" <<<"$OUT" && ok "$cls is reported by name, not silently exempted" \
                           || bad "$cls does not appear in the output at all"
done

# THE CONTROL ON EVERY ZERO ABOVE. A run that read no file would produce the same 'allows'
# verdicts, and they would all be vacuous.
grep -qE 'under the scan roots:   *[1-9]' <<<"$OUT" \
  && ok "the subject count is reported and non-zero — the control on every 'allows' above" \
  || bad "no non-zero subject count: every negative assertion above could be an empty read"

# =============================================================================
# 2. THE JOIN WITH THE MIGRATION, DERIVED IN BOTH DIRECTIONS. These are two
#    programs reading one grammar; the failure that matters is not either being
#    wrong on its own but the two disagreeing, which leaves a push blocked on a
#    path its remedy will not move.
# =============================================================================
BLOCK_SET="$(blocking_of "$OUT")"
bash "$MIG" --root "$W" --apply >/dev/null 2>&1
MOVED_SET="$(cd "$W" && git status --porcelain -M | sed -n 's/^R[ M]*\(.*\) -> .*$/\1/p' | sort)"

n_block="$(grep -c . <<<"$BLOCK_SET")"; n_moved="$(grep -c . <<<"$MOVED_SET")"
if [ "$n_block" -gt 0 ] && [ "$n_moved" -gt 0 ]; then
  ok "both sides of the join are non-empty ($n_block blocked, $n_moved moved) — the control on the comparison below"
else
  bad "one side of the join is EMPTY ($n_block blocked, $n_moved moved); set equality would hold vacuously"
fi
if [ "$BLOCK_SET" = "$MOVED_SET" ]; then
  ok "every path the validator blocked is one the migration moved, and vice versa"
else
  bad "the validator and the migration disagree about the governed set"
  diff <(printf '%s\n' "$BLOCK_SET") <(printf '%s\n' "$MOVED_SET") | sed 's/^/        /'
fi

# ...and after the remedy has run, the gate is green. A blocking arm whose own remedy does not
# clear it is a gate with no exit.
OUT2="$(bash "$VAL" --root "$W" 2>&1)"; RC2=$?
[ "$RC2" -eq 0 ] && ok "after the migration applies, the validator exits 0 — the remedy clears the gate" \
                 || { bad "the migration ran and the validator still exits $RC2"; blocking_of "$OUT2" | sed 's/^/        /'; }
grep -q 'VERDICT: PASS' <<<"$OUT2" && ok "...and says PASS in its own words" \
                                   || bad "exit 0 without a PASS verdict line"
# The refusals and the deferral are STILL reported after the migration. That is the state the
# reference consumer is in, and a validator that went quiet about 1072 non-conforming files the
# moment it stopped blocking would be worse than one that never mentioned them.
grep -q 'REPORTED —' <<<"$OUT2" \
  && ok "the refused and deferred classes are still reported on a green run" \
  || bad "a green run went silent about the paths the migration could not move"

# =============================================================================
# 3. AN EMPTY SUBJECT IS NOT A PASS. A greenfield consumer, first push.
# =============================================================================
WE="$(bash "$HERE/seed.sh" "$GRAMMAR" --empty)"
OUTE="$(bash "$VAL" --root "$WE" 2>&1)"; RCE=$?
[ "$RCE" -eq 0 ] && ok "a tree with no artifact under any scan root does not FAIL" \
                 || bad "a greenfield consumer exits $RCE, which makes the grammar unadoptable"
grep -q 'NOT-APPLICABLE' <<<"$OUTE" && ok "...and says NOT-APPLICABLE rather than PASS" \
                                    || bad "an empty subject was spelled like a verified pass"
grep -q 'VERDICT: PASS' <<<"$OUTE" && bad "an empty subject printed a PASS verdict it did not earn" \
                                   || ok "no PASS verdict is printed over an empty subject"

# =============================================================================
# 4. --report ADDS DETAIL AND CHANGES NO VERDICT. A reporting flag that also
#    relaxes the gate is a gate with an off switch in its own usage line.
# =============================================================================
W3="$(bash "$HERE/seed.sh" "$GRAMMAR")"
bash "$VAL" --root "$W3" >/dev/null 2>&1; R_PLAIN=$?
R_OUT="$(bash "$VAL" --root "$W3" --report 2>&1)"; R_REP=$?
[ "$R_PLAIN" -eq "$R_REP" ] && ok "--report leaves the exit code alone ($R_PLAIN both ways)" \
                            || bad "--report changed the exit code: $R_PLAIN -> $R_REP"
grep -q 'REPORT —' <<<"$R_OUT" && ok "--report actually adds the census" \
                               || bad "--report added nothing, so the flag is inert"
grep -q 'Story-corpus spelling split' <<<"$R_OUT" \
  && ok "the census names the story-corpus spelling split the migration has to read" \
  || bad "the census omits the story spelling split"
rm -rf "$W3"

# =============================================================================
# 5. RELATIVE INVOCATION. The resolver is found BESIDE this script, and resolving
#    that after the cd into the consumer looks for it inside a tree it does not
#    live in. Measured on the migration: the absolute call a fixture makes worked
#    and the relative call every operator types died at `cd: core/scripts`.
# =============================================================================
W4="$(bash "$HERE/seed.sh" "$GRAMMAR")"
VDIR="$(dirname "$VAL")"; VBASE="$(basename "$VAL")"; MBASE="$(basename "$MIG")"
( cd "$VDIR" && bash "./$VBASE" --root "$W4" >/dev/null 2>&1 ); RREL=$?
[ "$RREL" -eq 1 ] && ok "the validator run by a RELATIVE path still judges the tree (exit 1)" \
                  || bad "relative invocation of the validator gave $RREL, expected 1"
( cd "$VDIR/.." && bash "$(basename "$VDIR")/$MBASE" --root "$W4" >/dev/null 2>&1 ); RREL2=$?
[ "$RREL2" -eq 0 ] && ok "the migration run by a relative path from one level up still plans (exit 0)" \
                   || bad "relative invocation of the migration gave $RREL2, expected 0"
rm -rf "$W4"

# =============================================================================
# 6. MUTANTS. Each removes ONE mechanism and must flip exactly its own arm.
#    Every mutant is a guarded COPY laid down as a PAIR — validator plus the
#    resolver it calls — because a lone copy exits 2 at its first line, emits
#    nothing, and "no output" otherwise scores as a kill.
# =============================================================================
MUT="$(mktemp -d "${TMPDIR:-/tmp}/apconf-mut-XXXXXX")"
lay_pair() { mkdir -p "$1"; cp "$VAL" "$1/m.sh"; cp "$CONFIG" "$1/artifact-path-config.sh"; }

# $1 tag  $2 file to mutate: val|config  $3 sed program  $4 seed args  $5 test over $out/$rc  $6 claim
mutate() {
  local tag="$1" which="$2" prog="$3" seedargs="$4" test_expr="$5" claim="$6"
  local d="$MUT/$tag" src dst w out rc
  asserts=$((asserts+1))
  lay_pair "$d"
  if [ "$which" = "val" ]; then src="$VAL"; dst="$d/m.sh"; else src="$CONFIG"; dst="$d/artifact-path-config.sh"; fi
  sed -E "$prog" "$src" > "$dst.new" && mv "$dst.new" "$dst"
  if cmp -s "$src" "$dst"; then
    fails=$((fails+1)); printf '  FAIL  MUTANT %-20s sed matched NOTHING — the mutant IS the original\n' "$tag"; return
  fi
  # shellcheck disable=SC2086
  w="$(bash "$HERE/seed.sh" "$GRAMMAR" $seedargs)"
  out="$(bash "$d/m.sh" --root "$w" 2>&1)"; rc=$?
  if eval "$test_expr"; then printf '  ok    MUTANT %-20s %s\n' "$tag" "$claim"
  else fails=$((fails+1)); printf '  FAIL  MUTANT %-20s did NOT flip: %s\n' "$tag" "$claim"; fi
  rm -rf "$w"
}

# Resolve the slot against DECLARED areas only. The conforming path under an undeclared area
# becomes a violation — 92 of them on the reference consumer, against a migration planning zero.
mutate 'declared-areas-only' val \
  's@^      area = r "/" first .*$@      area = ""@' '' \
  'grep -q "_bmad-output/brainstorming/s301/discovery-brainstorming.md" <<<"$out"' \
  'without the inferred-area anchor, an already-conforming path under an undeclared area blocks'

# Drop the positional slot exemption. Every correctly-filed artifact becomes a violation, and
# the probe reaches that conclusion BEFORE the tree is read -- which is the point of running it
# first. The two probe mutants are told apart by DIRECTION: this one turns a conforming path
# into a violation, `token-re-dead` below turns every violation into a conforming path. An
# assertion on "the probe fired" alone would be satisfied by either and prove neither.
mutate 'slot-not-exempt' val \
  's@if \(i == slotidx && c\[i\] ~ /\^s\[0-9\]\+\$/\) continue@if (0) continue@' '' \
  '[ "$rc" -eq 2 ] && grep -q "expected CONFORMING, got NONCONFORMING" <<<"$out"' \
  'without the slot exemption the reserved slot itself reads as a violation, and the probe refuses the run'

# Make the empty-subject guard unable to fire. The greenfield tree then prints a PASS it did not
# earn — the zero-verification pass this repo keeps finding.
mutate 'empty-subject-passes' val \
  's@if \[ "\$N_SUBJECT" -eq 0 \]; then@if [ "$N_SUBJECT" -lt 0 ]; then@' '--empty' \
  'grep -q "VERDICT: PASS" <<<"$out"' \
  'with the guard disarmed a tree holding NO artifact reports a verified pass'

# Kill the sprint-token expression in the RESOLVER. Without the self-probe the validator would
# report a fully-conforming tree; with it, the run refuses to answer at all.
mutate 'token-re-dead' config \
  "s@^TOKEN_RE='.*'\$@TOKEN_RE='ZZZ-NOT-A-SPRINT-TOKEN-ZZZ'@" '' \
  '[ "$rc" -eq 2 ] && grep -q "expected NONCONFORMING, got CONFORMING" <<<"$out"' \
  'a token expression that matches nothing is caught by the probe instead of reporting a clean tree'

# UNMUTATED CONTROL, from the same directory. The harness itself must not be what fails.
asserts=$((asserts+1))
lay_pair "$MUT/control"
wc="$(bash "$HERE/seed.sh" "$GRAMMAR")"
ctl_out="$(bash "$MUT/control/m.sh" --root "$wc" 2>&1)"; ctl_rc=$?
if [ "$ctl_rc" -eq 1 ] && grep -q "BLOCKING —" <<<"$ctl_out"; then
  ok "CONTROL: an unmutated pair in the mutant directory still judges the tree"
else
  bad "CONTROL: an unmutated pair FAILED (rc=$ctl_rc) — the mutant harness is what is broken, not the mutants"
fi
rm -rf "$wc" "$MUT" "$W" "$WE"

echo
if [ "$fails" -eq 0 ]; then echo "artifact-path-conformance: PASS ($asserts assertions)"; exit 0; fi
echo "artifact-path-conformance: $fails of $asserts assertion(s) FAILED" >&2
exit 1
