#!/usr/bin/env bash
# layer-adjudication-tier — assert `level: ADJUDICATED` is a mechanism and not a declaration.
#
# Usage: run.sh [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS THE TRIPLE IN PARTS 1-3: no record blocks, a record clears, and
# ONE BYTE of change to the entry blocks again. A register keyed by PATH passes the first two and
# fails the third, and a path-keyed register is a permanent exemption wearing an adjudication's
# clothes — the failure this tier exists to foreclose. Parts 1 and 2 alone are satisfied by it.
#
# EVERY "a blocking row appeared" ASSERTION HAS A SAME-RUN CONTROL: the seeded contract also
# carries a clause at WARN, and Part 5 flips the adjudicable clause's LEVEL and re-runs. Without
# that, a classifier that had started emitting the blocking row unconditionally would score as a
# pass on all of Parts 1-4.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
DRIFT="$(pick "${1:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
[ -n "$DRIFT" ] || { echo "FIXTURE ERROR: cannot locate layer-drift.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"
ENTRY=".claude/skills/ai-dlc/extensions/adjudicable.md"
REG="$CONS/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
CONTRACT="$DIST/core/skills/ai-dlc/layer-contract.yaml"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

run()    { bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
blocks() { run | grep -c '^HARD-LAYER-ADJUDICATION-MISSING'; }
drifts() { run | grep -c '^EXTENSION-HOOK-DRIFT'; }
digest() { run | awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING"' \
                 | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{print $2}' | head -1; }

# EVERY PART RE-DERIVES ITS OWN DIGEST FROM A CLEARED REGISTER. Threading one `$DIG` through the
# file made Part 4b's precondition depend on Part 3's outcome: a mutant that broke the digest
# KEYING left Part 3 unblocked, `digest()` then returned empty, and Part 4b recorded against an
# empty key and reported a second failure for the first mutant's defect. Two failures from one
# mutation mean the assertions are entangled and one of them is measuring the other.
fresh_digest() { rm -f "$REG"; digest; }
need_digest() { # $1 part label -> echoes a 40-hex digest or records the failure
  local d; d="$(fresh_digest)"
  if [ ${#d} -ne 40 ]; then
    bad "$1 could not obtain a subject digest from a cleared register, so its own assertion below would measure the wrong thing. Read the earlier parts first: this is a consequence, not an independent finding"
    return 1
  fi
  printf '%s' "$d"
}

record() { # $1 digest, $2 verdict, [$3 supersedes]
  if [ -n "${3:-}" ]; then
    printf '{"clause":"LC-E4","entry":"%s","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded","supersedes":"%s"}\n' \
      "$ENTRY" "$1" "$2" "$3"
  else
    printf '{"clause":"LC-E4","entry":"%s","subject_digest":"%s","verdict":"%s","recorded_utc":"2026-01-01T00:00:00Z","reason":"seeded"}\n' \
      "$ENTRY" "$1" "$2"
  fi
}

echo "layer-adjudication-tier:"

command -v jq >/dev/null 2>&1 || { echo "  SKIP  jq is not on PATH; the register cannot be read and every assertion below would be vacuous" >&2; exit 0; }

# --- Part 0: the seed is a real range and the classifier ran ------------------
# Parts 2 and 5 assert a blocking row is ABSENT. A run that emitted nothing at all satisfies
# both, so the presence of the candidate row is established first.
if [ "$(drifts)" -eq 1 ]; then
  ok "the classifier emits exactly 1 EXTENSION-HOOK-DRIFT row (the candidate every absence assertion below is measured against)"
else
  bad "expected exactly 1 EXTENSION-HOOK-DRIFT row, got $(drifts) — the seeded range is not producing the candidate, so every absence assertion in this file would pass vacuously"
fi
if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/skills/ai-dlc/steps/demo.md; then
  bad "the seeded range does not change the hooked file, so the re-read duty has nothing to fire on"
else
  ok "the seeded range really does change the hooked file"
fi

# --- Part 1: unrecorded BLOCKS ------------------------------------------------
[ -f "$REG" ] && rm -f "$REG"
if [ "$(blocks)" -eq 1 ]; then
  ok "no register: 1 HARD-LAYER-ADJUDICATION-MISSING — an adjudicable row with no verdict blocks"
else
  bad "no register produced $(blocks) blocking rows, expected 1 — the level is declared and not acted on, so ADJUDICATED is a WARN with extra prose"
fi

DIG="$(digest)"
if [ ${#DIG} -eq 40 ]; then
  ok "the blocking row carries a 40-hex subject_digest (the operator copies a value; nobody re-derives one)"
else
  bad "the blocking row carries no usable subject_digest ('$DIG') — an operator cannot record a verdict against a key the row does not print"
fi

# --- Part 2: recorded CLEARS, and the candidate row SURVIVES ------------------
record "$DIG" still-additive > "$REG"
if [ "$(blocks)" -eq 0 ]; then
  ok "verdict recorded: 0 blocking rows — the duty is discharged by the record"
else
  bad "a matching record left $(blocks) blocking rows — the register is not being read, or the digest the row prints is not the digest it looks up"
fi
if [ "$(drifts)" -eq 1 ]; then
  ok "the EXTENSION-HOOK-DRIFT row still prints once adjudicated — its clause's code stays live, so I36 is joining a code that is actually emitted"
else
  bad "recording a verdict suppressed the candidate row itself. Then LC-E4's declared code is emitted by nothing, its clause cannot fire, and I36's grep over this script would still pass on the string in a comment"
fi

# --- Part 3: ONE BYTE of entry change RE-FIRES it -----------------------------
# The arm a path-keyed register fails. Nothing about the register changes here.
printf '\n' >> "$CONS/$ENTRY"
if [ "$(blocks)" -eq 1 ]; then
  ok "entry body +1 byte: blocking again — the verdict was keyed to the subject STATE, not to the path"
else
  bad "the entry's body changed and the recorded verdict still cleared it. That record is a permanent exemption for the path: every future core change inherits a verdict made against text that no longer exists"
fi
# --- Part 4a: a verdict OUTSIDE the schema's enum does not discharge it -------
if DIG="$(need_digest 'Part 4a')"; then
record "$DIG" looks-fine-to-me > "$REG"
if [ "$(blocks)" -eq 1 ]; then
  ok "off-vocabulary verdict: still blocking — a record only counts when its verdict is one the schema defines"
else
  bad "the string 'looks-fine-to-me' cleared a blocking row. Any value would, and the adjudication is then a formality a typo passes"
fi
fi

# --- Part 4b: the vocabulary is READ from the schema, not restated ------------
# Mutate the schema's enum in the seeded distribution and re-commit: a verdict that WAS valid
# must stop discharging the duty. A reader with the three strings baked in passes Part 4a and
# fails only here.
if DIG="$(need_digest 'Part 4b')"; then
record "$DIG" retire > "$REG"
sed 's/"retire"/"retired-under-a-different-name"/' "$DIST/core/schemas/layer-adjudication-register.json" > "$DIST/core/schemas/x.json"
if cmp -s "$DIST/core/schemas/layer-adjudication-register.json" "$DIST/core/schemas/x.json"; then
  bad "the enum mutation matched nothing, so Part 4b's silence proves nothing about where the vocabulary comes from"
else
  mv "$DIST/core/schemas/x.json" "$DIST/core/schemas/layer-adjudication-register.json"
  git -C "$DIST" add -A && git -C "$DIST" commit -qm "mutate the verdict enum"
  THEIRS_M="$(git -C "$DIST" rev-parse --short HEAD)"
  n="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_M" "$CONS" 2>/dev/null | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')"
  if [ "$n" -ge 1 ]; then
    ok "the enum moved in the schema and 'retire' stopped discharging the duty — the vocabulary is read from the schema, not restated in the reader"
  else
    bad "'retire' still cleared the row after the schema's enum no longer contains it, so the reader carries its own copy of the vocabulary and the schema is decoration"
  fi
  git -C "$DIST" reset -q --hard HEAD~1
fi
fi

# --- Part 5: THE LEVEL IS WHAT DECIDES ---------------------------------------
# Flip the adjudicable clause to WARN in the seeded contract. Same code, same row, same
# register, no duty. This is the control for every "a blocking row appeared" assertion above.
rm -f "$REG"
[ "$(blocks)" -eq 1 ] || bad "Part 5's precondition failed: the row is not blocking before the level is flipped, so flipping it proves nothing"
sed 's/^    level: ADJUDICATED$/    level: WARN/' "$CONTRACT" > "$CONTRACT.mut"
if cmp -s "$CONTRACT" "$CONTRACT.mut"; then
  bad "the level mutation matched nothing in the seeded contract, so Part 5's silence proves nothing"
else
  mv "$CONTRACT.mut" "$CONTRACT"
  git -C "$DIST" add -A && git -C "$DIST" commit -qm "flip LC-E4 to WARN"
  THEIRS_W="$(git -C "$DIST" rev-parse --short HEAD)"
  n="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_W" "$CONS" 2>/dev/null | grep -c '^HARD-LAYER-ADJUDICATION-MISSING')"
  d="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS_W" "$CONS" 2>/dev/null | grep -c '^EXTENSION-HOOK-DRIFT')"
  if [ "$n" -eq 0 ] && [ "$d" -eq 1 ]; then
    ok "clause flipped to WARN: 0 blocking rows and the candidate row unchanged — the CONTRACT's level decides, so migrating a clause needs no edit to the classifier"
  else
    bad "flipping the level to WARN left $n blocking row(s) and $d candidate row(s), expected 0 and 1 — the adjudicable set is not derived from the contract, so it is a hand-list somewhere and this tier has a second home"
  fi
  git -C "$DIST" reset -q --hard HEAD~1
fi

# --- Part 6: LC-A2, the contradiction arm ------------------------------------
# The contradiction is a property of the REGISTER, so this part needs a well-formed key but does
# not depend on whether any earlier part cleared its row.
DIG="$(need_digest 'Part 6')" || DIG=""
{ record "$DIG" still-additive; record "$DIG" retire; } > "$REG"
if [ "$(run | grep -c '^HARD-REGISTER-CONTRADICTION')" -ge 1 ]; then
  ok "two verdicts under one key with no supersedes: HARD-REGISTER-CONTRADICTION — a lookup would otherwise answer with whichever record was read last"
else
  bad "two records under one key state different verdicts and nothing reported it. Which one wins then depends on file order, and so does whether the pull blocks"
fi

{ record "$DIG" still-additive; record "$DIG" retire "the earlier reading missed core's new paragraph"; } > "$REG"
if [ "$(run | grep -c '^HARD-REGISTER-CONTRADICTION')" -eq 0 ]; then
  ok "the same pair WITH supersedes and a reason: no contradiction — retraction stays available, it just has to be declared"
else
  bad "a properly declared supersession still reported a contradiction. An operator who cannot change their mind will stop recording verdicts at all"
fi

# --- Part 7: the digest survives a RELATIVE consumer root -------------------------------
# `adj_digest` hashes the consumer's entry with `git -C "$DIST" hash-object "$CONSUMER/$1"`,
# and `-C` moves git into the DISTRIBUTION before that path is read. So a relative consumer
# root resolved there, the hash failed, and every ADJUDICATED row degraded to "subject digest
# could not be computed" instead of carrying the key the operator records a verdict against.
#
# WHAT MAKES IT ASSERTABLE RATHER THAN COSMETIC: the BLOCKING ROW COUNT IS THE SAME either
# way, so the run looks identical while the messages have gone unactionable. Measured on the
# reference consumer at 0.263.0 — 11 degraded messages under a relative root, 0 under an
# absolute one, 13 HARD- rows in both. Both halves are asserted here: the message must be
# actionable AND the count must not move, because a fix that changed the count would be
# suppressing rows rather than keying them.
: > "$REG"
abs_deg="$(run | grep -c 'could not be computed')"
abs_hard="$(run | grep -c '^HARD-')"
rel_deg="$( (cd "$CONS" && bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" . 2>/dev/null) | grep -c 'could not be computed')"
rel_hard="$((cd "$CONS" && bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" . 2>/dev/null) | grep -c '^HARD-')"
if [ "$rel_deg" -eq "$abs_deg" ] && [ "$rel_hard" -eq "$abs_hard" ]; then
  ok "a RELATIVE consumer root yields the same digests and the same $abs_hard HARD- row(s) as an absolute one"
else
  bad "consumer-root FORM changed the result: degraded messages abs=$abs_deg rel=$rel_deg, HARD- rows abs=$abs_hard rel=$rel_hard. The operator cannot record a verdict against a digest that was never computed"
fi

# MUTATION: remove the absolutization and require the relative form to degrade. Without it
# the assertion above is satisfied by any build in which BOTH forms happen to work.
# THE MUTANT IS BUILT INSIDE A COPY OF THE WHOLE reconcile/ DIRECTORY, not as a lone file.
# `layer-drift.sh` sources `lib.sh` from its own directory, so a copy anywhere else dies at
# the source line and emits NOTHING — and zero degraded messages from a script that never ran
# reads exactly like a mutant that survived. That is this repo's lone-copy trap arriving from
# the opposite direction, so the unmutated control below comes from the same copied directory.
MUTDIR="$ROOT/reconcile-mutant"; mkdir -p "$MUTDIR"
cp "$(dirname "$DRIFT")"/* "$MUTDIR"/ 2>/dev/null
MUT="$MUTDIR/layer-drift.sh"
CTL="$MUTDIR/layer-drift-unmutated.sh"; cp "$DRIFT" "$CTL" 2>/dev/null
MUT_OLD='CONSUMER="$(cd "$CONSUMER" 2>/dev/null && pwd)" || { echo "layer-drift: consumer-root not a directory: ${4}" >&2; exit 2; }'
MUT_OLD="$MUT_OLD" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],"true",1))' \
  "$DRIFT" "$MUT" 2>/dev/null
ctl_abs="$(bash "$CTL" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null | grep -c '^HARD-')"
if [ ! -s "$MUT" ] || cmp -s "$DRIFT" "$MUT"; then
  bad "FIXTURE ERROR: the absolutization mutation matched nothing — Part 7 proves nothing. Update MUT_OLD to match layer-drift.sh's real parse-time absolutization"
elif [ "$ctl_abs" -ne "$abs_hard" ]; then
  bad "FIXTURE ERROR: the UNMUTATED copy in $MUTDIR reports $ctl_abs HARD- rows against $abs_hard in place — the copied directory is not a working harness, so no verdict below is attributable"
else
  ok "CONTROL: an unmutated copy in the same directory still reports $ctl_abs HARD- row(s) — the mutant verdicts below are its edit, not the copy"
  mut_rel="$( (cd "$CONS" && bash "$MUT" "$DIST" "$BASE" "$THEIRS" . 2>/dev/null) | grep -c 'could not be computed')"
  mut_abs="$(bash "$MUT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null | grep -c 'could not be computed')"
  if [ "$mut_rel" -ge 1 ]; then
    ok "MUTATION — without the absolutization the relative form degrades ($mut_rel message(s)): the parse-time fix is what Part 7 tests"
  else
    bad "MUTATION — the relative form still resolved without the absolutization, so Part 7's assertion is vacuous"
  fi
  # Pairing: the mutant must still be CORRECT under an absolute root. A mutant that degrades
  # both ways would satisfy the assertion above while testing nothing about the root FORM.
  if [ "$mut_abs" -eq "$abs_deg" ]; then
    ok "MUTATION PAIRING — the same mutant is unaffected under an absolute root: it died of the FORM, not of the edit"
  else
    bad "MUTATION PAIRING — the mutant also degraded under an absolute root ($mut_abs vs $abs_deg), so its verdict cannot be attributed to the consumer-root form"
  fi
fi

# --- Part 8: a DEGENERATE RANGE disarms every ADJUDICATED arm, and must say so --------------
#
# THE SEEDED contract puts ONE clause at ADJUDICATED and it is computed base..theirs, which is
# the shape this arm is about; the REAL contract's set is derived and must not be restated here
# (v0.314.0 added a clause that is NOT range-keyed, and every hand-list of that set went stale
# the same day). LC-A1's duty is demanded only on rows an ADJUDICATED clause produces. So `base == theirs` yields no drift, no duty, and a clean sheet on a tree where
# every verdict is owed — reported by the reference consumer as `0 HARD blockers.` against
# eighteen unrecorded adjudications, and reproduced here.
#
# THE PAIR IS THE TEST. Asserting only that the degenerate run emits the row would pass against a
# script that emits it always; asserting only that the real run does not would pass against one
# that never emits it. Both arms, same seed, same tree.
echo
echo "Part 8 — a degenerate base..theirs range announces the arms it cannot fire"

deg_out="$(bash "$DRIFT" "$DIST" "$THEIRS" "$THEIRS" "$CONS" 2>/dev/null)"
real_out="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"

deg_row="$(printf '%s\n' "$deg_out"  | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
real_row="$(printf '%s\n' "$real_out" | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
deg_hard="$(printf '%s\n' "$deg_out"  | awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING"{c++} END{print c+0}')"
real_hard="$(printf '%s\n' "$real_out" | awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING"{c++} END{print c+0}')"
deg_rows="$(printf '%s\n' "$deg_out" | grep -c .)"

# The disarm itself, with the control that makes the zero readable: the degenerate run still
# emits rows, so a missing adjudication duty is a real absence and not a dead invocation.
if [ "$real_hard" -ge 1 ] && [ "$deg_hard" -eq 0 ] && [ "$deg_rows" -ge 2 ]; then
  ok "the disarm reproduces: pull's base demands $real_hard adjudication(s), theirs-as-base demands 0 — and the degenerate run still emitted $deg_rows row(s), so the zero is a real absence"
else
  bad "the disarm did not reproduce (real=$real_hard degenerate=$deg_hard rows=$deg_rows) — Part 8's remaining assertions cannot be attributed"
fi

if [ "$deg_row" -eq 1 ]; then
  ok "the degenerate run emits exactly one DRIFT-RANGE-DEGENERATE row"
else
  bad "the degenerate run emitted $deg_row DRIFT-RANGE-DEGENERATE row(s), want 1 — a silent disarm reads exactly like a clean layer"
fi

if [ "$real_row" -eq 0 ]; then
  ok "CONTROL: a real base..theirs range emits none, so the row discriminates rather than always firing"
else
  bad "a real range also emitted the row, so the assertion above is satisfied by a script that always emits it"
fi

# RESOLVED COMMIT IDS, NOT ARGUMENT STRINGS. In every real invocation `theirs` is a ref name and
# `base` a sha, so a string comparison would never fire on the one case this exists for.
git -C "$DIST" branch -f fixture-tip "$THEIRS" >/dev/null 2>&1
ref_row="$(bash "$DRIFT" "$DIST" "$THEIRS" fixture-tip "$CONS" 2>/dev/null | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
if [ "$ref_row" -eq 1 ]; then
  ok "fires when the same commit is named as a sha on one side and a REF on the other"
else
  bad "did not fire on sha-vs-ref ($ref_row rows) — a string compare would miss every real invocation"
fi

# MUTATION — compare the argument strings instead of the resolved ids. The sha-vs-ref arm must go
# dark and the sha-vs-sha arm must not, or the mutant is testing something else.
MUT8DIR="$MUTDIR-degenerate"
rm -rf "$MUT8DIR"; mkdir -p "$MUT8DIR"
cp "$(dirname "$DRIFT")"/*.sh "$MUT8DIR/" 2>/dev/null
MUT8="$MUT8DIR/layer-drift.sh"
sed 's@^  if \[ -n "\$_b" \] && \[ "\$_b" = "\$_t" \]; then@  if [ -n "$BASE" ] \&\& [ "$BASE" = "$THEIRS" ]; then@' "$DRIFT" > "$MUT8"
if cmp -s "$DRIFT" "$MUT8"; then
  bad "FIXTURE ERROR: the resolved-id mutation matched nothing, so the sha-vs-ref assertion is unproven"
else
  m8_ref="$(bash "$MUT8" "$DIST" "$THEIRS" fixture-tip "$CONS" 2>/dev/null | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
  m8_sha="$(bash "$MUT8" "$DIST" "$THEIRS" "$THEIRS" "$CONS" 2>/dev/null | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{c++} END{print c+0}')"
  if [ "$m8_ref" -ne 0 ]; then
    bad "MUTATION — the string compare still fired on sha-vs-ref, so the resolved-id assertion is vacuous"
  elif [ "$m8_sha" -ne 1 ]; then
    bad "MUTATION — the string compare also lost the sha-vs-sha case ($m8_sha), so it is not a clean mutation of the resolution alone"
  else
    ok "MUTATION — comparing the argument strings loses sha-vs-ref and keeps sha-vs-sha: resolving the ids is load-bearing"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "layer-adjudication-tier: PASS"
  exit 0
fi
echo "layer-adjudication-tier: FAIL ($fails)"
exit 1
