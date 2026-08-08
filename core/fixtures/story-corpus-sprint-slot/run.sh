#!/usr/bin/env bash
# story-corpus-sprint-slot — the story corpus lives under the sprint's OWN directory, and every
# reader resolves it from one declaration rather than restating it.
#
# Exit: 0 = every assertion holds, 1 = an assertion regressed, 2 = fixture broken.
#
# THE DEFECT CLASS THIS EXISTS TO CATCH, and it is the one this repo keeps shipping: a reader that
# finds nothing and reports it as clean. Every arm below distinguishes THREE states that used to
# print the same line —
#
#   the corpus is empty                 -> SKIP     (a project before its first story)
#   the corpus exists, elsewhere        -> FAIL     (unmigrated, or written to the wrong sprint)
#   the corpus location did not resolve -> FAIL     (the schema is unreadable)
#
# — because collapsing any two of them is how sprints 298 and 299 had their Dev Agent Record
# compliance "verified" against zero files. The measured history is in validate-mandatory-rules.sh
# at Check 6.
#
# ARM 4 IS THE ONE THAT WAS ACTUALLY WRONG DURING DEVELOPMENT, and it is why the corpus control
# spans the whole area instead of the declared slot. Written the obvious way — count stories under
# `s*/stories/` — the control is BLIND to a tree that has not migrated yet, so an unmigrated
# consumer holding 988 story files reported "the corpus is empty" and SKIPped. The fix's own
# blind spot had the same shape as the defect it was fixing.
set -uo pipefail

# No distribution-root walk here: this file needs none. It had one — assigned, never read — and a
# dead `../../..` beside a seed that really did depend on one is how the next reader concludes the
# resolution is fine because two files agree. The seed names its sources in both layouts; this
# file resolves nothing but itself.
HERE="$(cd "$(dirname "$0")" && pwd)"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

PRISTINE="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$PRISTINE" "$WORK"' EXIT

# A fresh COPY of the pristine seed, never an edit of it: a layout change applied in place leaks
# into every later arm, and the one that leaks reads as the one that fired.
#
# THE TOOLS ARE INSTALLED INTO THE TREE, not driven from beside it, and that is not tidiness. Both
# of them resolve the schema RELATIVE TO THE TREE THEY ARE IN; a copy run from outside resolves
# the pristine seed's schema instead, so A10 — which moves the declaration — silently tested
# nothing, and every mutant copy resolved no schema at all and failed four arms for a reason that
# had nothing to do with its mutation. The control caught it, which is what the control is for.
fresh() { # <dir holding the two tools>
  rm -rf "$WORK/t"; cp -R "$PRISTINE" "$WORK/t"
  cp "$1/sprint-status.sh" "$1/validate-mandatory-rules.sh" "$WORK/t/scripts/ai-dlc/"
  chmod +x "$WORK/t/scripts/ai-dlc"/*.sh
  printf '%s' "$WORK/t"
}

story() { # <dir> <basename> <status>
  mkdir -p "$1"
  printf -- '---\nstatus: %s\n---\n\n# story\n\n## Dev Agent Record\n\ndev (delegated) did it.\n' \
    "$3" > "$1/$2.md"
}

# The two tools under test, driven exactly as a consumer drives them: validate-mandatory-rules.sh
# from the project root (every path in it is cwd-relative), sprint-status.sh with --root.
check6() { # <root> [tool-dir] -> the Check 6 verdict line
  local r="$1" td="${2:-$1/scripts/ai-dlc}"
  ( cd "$r" && bash "$td/validate-mandatory-rules.sh" 302 2>&1 ) | grep -E '^  CHECK 6:'
}
stories_check() { # <root> [tool] -> stdout+stderr, sets SC_RC
  local r="$1" tool="${2:-$1/scripts/ai-dlc/sprint-status.sh}"
  SC_OUT="$(bash "$tool" check-stories --root "$r" 2>&1)"; SC_RC=$?
}

MIG="_bmad-output/planning-artifacts/s302/stories"
FLAT="_bmad-output/planning-artifacts/stories"

# =============================================================================
# THE BATTERY. One function, so the same assertions can be re-run against a mutated copy of
# either tool. A mutant is accepted only if it fails EXACTLY its own assertion.
# =============================================================================
battery() { # $1 = the directory holding the two tools under test
  local TOOLS="$1"

  # --- A1: a migrated tree resolves, and says how many comparisons it made.
  t="$(fresh "$TOOLS")"
  story "$t/$MIG" story-1-alpha done
  story "$t/$MIG" story-2-beta  in_progress
  stories_check "$t"
  if [ "$SC_RC" -eq 0 ] && grep -q 'PASS — 4 comparison(s)' <<<"$SC_OUT"; then
    echo "A1 PASS"; else echo "A1 FAIL"; fi

  # --- A2: and Check 6 verifies the files rather than a name-matching subset of them. The file
  # names carry NO sprint token, which is the whole point: the old glob keyed on one.
  t="$(fresh "$TOOLS")"
  story "$t/$MIG" story-1-alpha done
  story "$t/$MIG" story-2-beta  in_progress
  if [[ "$(check6 "$t")" == *"PASS — 2 story file(s) verified"* ]]; then
    echo "A2 PASS"; else echo "A2 FAIL"; fi

  # --- A3: an UNMIGRATED tree is a FINDING on the story join, and the finding names the remedy.
  # Silence here is the pull reporting success on a consumer whose readers see nothing.
  t="$(fresh "$TOOLS")"
  story "$t/$FLAT" story-302-1-alpha done
  story "$t/$FLAT" story-302-2-beta  in_progress
  stories_check "$t"
  if [ "$SC_RC" -eq 1 ] && grep -q 'names no readable story file' <<<"$SC_OUT" \
     && grep -q 'migrate-artifact-paths.sh' <<<"$SC_OUT"; then
    echo "A3 PASS"; else echo "A3 FAIL"; fi

  # --- A4: and Check 6 FAILS on it rather than SKIPping. THE ARM THAT MATTERS. A corpus control
  # counted only under the declared slot cannot see these files at all and reports an empty
  # corpus, which is a skip, which is a green gate over an unverified sprint.
  t="$(fresh "$TOOLS")"
  story "$t/$FLAT" story-302-1-alpha done
  story "$t/$FLAT" story-302-2-beta  in_progress
  if [[ "$(check6 "$t")" == *"FAIL — 0 of 2 story file(s)"* ]]; then
    echo "A4 PASS"; else echo "A4 FAIL"; fi

  # --- A5: a corpus that is genuinely empty is a SKIP, not a failure. A greenfield consumer has
  # no stories on its first sprint and a gate that fails it makes the grammar unadoptable.
  t="$(fresh "$TOOLS")"
  if [[ "$(check6 "$t")" == *"SKIP — the story corpus is empty"* ]]; then
    echo "A5 PASS"; else echo "A5 FAIL"; fi

  # --- A6: an UNRESOLVABLE corpus location fails closed. Asserted on the distinct verdict, not on
  # the absence of a pass: "I could not find out" and "there is nothing wrong" are different
  # answers and this check used to spell them the same way.
  t="$(fresh "$TOOLS")"
  story "$t/$MIG" story-1-alpha done
  rm -f "$t/.claude/schemas/sprint-status.json"
  if [[ "$(check6 "$t")" == *"FAIL — the corpus location did not resolve"* ]]; then
    echo "A6 PASS"; else echo "A6 FAIL"; fi

  # --- A7: ANOTHER sprint's stories are not this sprint's. The directory is the selector, so a
  # populated s301 cannot make s302 look verified — and it must not read as empty either.
  t="$(fresh "$TOOLS")"
  story "$t/_bmad-output/planning-artifacts/s301/stories" story-1-old done
  if [[ "$(check6 "$t")" == *"FAIL — 0 of 1 story file(s)"* ]]; then
    echo "A7 PASS"; else echo "A7 FAIL"; fi

  # --- A8: the KEY still spells the sprint and the FILE does not, so the join strips the DECLARED
  # sprint from the key to get the index. A capital-S legacy key resolves to the same file, which
  # is what makes the 298/299 spelling split unable to come back.
  t="$(fresh "$TOOLS")"
  story "$t/$MIG" story-1-alpha done
  sed -i.bak 's/^  story-302-1:$/  story-S302-1:/; /^  story-302-2:$/,+1d' \
    "$t/_bmad-output/implementation-artifacts/sprint-status.yaml"
  sed -i.bak 's/^  story-302-1:$/  story-S302-1:/; /^  story-302-2:$/,+1d' \
    "$t/_bmad-output/planning-artifacts/sprint-status.yaml"
  rm -f "$t"/_bmad-output/*/sprint-status.yaml.bak
  stories_check "$t"
  if [ "$SC_RC" -eq 0 ] && grep -q 'PASS — 2 comparison(s)' <<<"$SC_OUT"; then
    echo "A8 PASS"; else echo "A8 FAIL"; fi

  # --- A9: index-prefix collision. Key `story-302-1` must never resolve to `story-10-…`. Asserted
  # on the identity of the file read, not on the finding text A3 also carries — two assertions
  # reading one string is how one of them ends up proving nothing.
  t="$(fresh "$TOOLS")"
  story "$t/$MIG" story-10-late-arrival review
  stories_check "$t"
  if ! grep -q 'story-10-late-arrival' <<<"$SC_OUT"; then echo "A9 PASS"; else echo "A9 FAIL"; fi

  # --- A10: the corpus location is the SCHEMA's. Move the declaration and both tools follow it;
  # a tool that had kept its own copy of the literal would go on reading the old place and report
  # a clean sheet over a tree it is not looking at.
  t="$(fresh "$TOOLS")"
  sed -i.bak 's|"_bmad-output/planning-artifacts/s{sprint}/stories"|"_bmad-output/elsewhere/s{sprint}/tales"|' \
    "$t/.claude/schemas/sprint-status.json"
  rm -f "$t/.claude/schemas/sprint-status.json.bak"
  story "$t/_bmad-output/elsewhere/s302/tales" story-1-alpha done
  story "$t/_bmad-output/elsewhere/s302/tales" story-2-beta  in_progress
  stories_check "$t"
  if [ "$SC_RC" -eq 0 ] && grep -q 'PASS — 4 comparison(s)' <<<"$SC_OUT"; then
    echo "A10 PASS"; else echo "A10 FAIL"; fi
}

echo "story-corpus-sprint-slot:"

TD_REAL="$PRISTINE/scripts/ai-dlc"

FAILED="$(battery "$TD_REAL" | awk '$2=="FAIL"{printf "%s ", $1}')"
if [ -n "$FAILED" ]; then
  bad "battery failed on the SHIPPING tools: $FAILED"
else
  ok "all 10 assertions pass on the shipping tools"
fi

# =============================================================================
# MUTANTS. Each is a COPY with one change, guarded by `cmp -s` so a sed that matched nothing
# cannot pass as a mutation, and each must fail EXACTLY its own assertion.
# =============================================================================
mutant() { # <expected-assertion> <label> <target: ss|vmr> <sed expr>
  local want="$1" label="$2" which="$3" expr="$4"
  local mdir="$WORK/mut-$want"
  rm -rf "$mdir"; cp -R "$TD_REAL" "$mdir"
  local target
  case "$which" in
    ss)  target="$mdir/sprint-status.sh" ;;
    vmr) target="$mdir/validate-mandatory-rules.sh" ;;
    *)   bad "FIXTURE BROKEN — unknown mutant target '$which'"; return ;;
  esac
  sed "$expr" "$target" > "$target.mut"
  if cmp -s "$target" "$target.mut"; then
    bad "FIXTURE BROKEN — MUTANT $want ($label) changed nothing; the assertion below would test the original"
    rm -f "$target.mut"; return
  fi
  mv "$target.mut" "$target"; chmod +x "$target"
  local got
  got="$(battery "$mdir" | awk '$2=="FAIL"{printf "%s ", $1}')"
  got="${got% }"
  if [ "$got" = "$want" ]; then
    ok "MUTANT $want ($label) fails exactly $want"
  else
    bad "MUTANT $want ($label) failed [${got:-nothing}], expected exactly [$want] — entangled assertions, or the mutation is not reached"
  fi
}

# A4: narrow Check 6's corpus control back to the declared slot — the blind spot the arm exists
# for. The unmigrated tree then reports an empty corpus and SKIPs.
mutant A4 "corpus control narrowed to the declared slot" vmr \
  's/^  if \[ "\$CHECK6_AREA_CORPUS" -eq 0 \]; then$/  if [ "$CHECK6_CORPUS" -eq 0 ]; then/'
# A6: turn the unresolvable-location failure into a skip, which is what it used to be.
mutant A6 "unresolved corpus location skips instead of failing" vmr \
  's/^if \[ "\$CHECK6_UNRESOLVED" -eq 1 \]; then$/if [ "$CHECK6_UNRESOLVED" -eq 2 ]; then/'
# A8: drop the optional sprint-token prefix from the key matcher, so only a BARE number is
# stripped. Deliberately narrower than "stop stripping at all", which was the first mutant here
# and was ENTANGLED: it also broke A1 and A10, both of which already assert the stripping. What
# A8 alone claims is that a capital-S legacy key resolves, so that is what this removes.
mutant A8 "capital-S key form no longer recognised" ss \
  's/r"\[sS\]?0\*%d"/r"0*%d"/'
# A9: widen the index glob to a prefix match, the collision that compares story-1 against story-10.
mutant A9 "index glob widened to a prefix match" ss \
  's/stories.glob(stem + "-\*.md")/stories.glob(stem + "*.md")/'
# A10: put the corpus literal back into sprint-status.sh instead of resolving the template, which
# is the restatement I84 bans. It then cannot follow the declaration when it moves.
mutant A10 "corpus literal restated instead of resolved" ss \
  's|^    return STORIES_DIR_T.replace(SPRINT_SLOT, str(sprint))$|    return "_bmad-output/planning-artifacts/s%s/stories" % sprint|'

# --- Unmutated control -------------------------------------------------------
# A copy in the same directory shape as the mutants, mutated not at all. Without it, a harness
# that breaks every copy for a reason of its own — a schema a copy cannot resolve, a lost exec
# bit — scores all five mutants above as kills.
CTRL="$WORK/mutant-control"
rm -rf "$CTRL"; cp -R "$TD_REAL" "$CTRL"
CTRL_FAILED="$(battery "$CTRL" | awk '$2=="FAIL"{printf "%s ", $1}')"
if [ -z "$CTRL_FAILED" ]; then
  ok "CONTROL: an unmutated copy beside the mutants passes the whole battery"
else
  bad "CONTROL: an unmutated copy failed [$CTRL_FAILED] — the harness itself is what breaks a copy, so every mutant verdict above is meaningless"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "story-corpus-sprint-slot: PASS"
  exit 0
fi
echo "story-corpus-sprint-slot: $fails assertion(s) FAILED" >&2
exit 1
