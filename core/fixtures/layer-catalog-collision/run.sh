#!/usr/bin/env bash
# layer-catalog-collision — assert the layer detectors tell the four catalog states
# apart, and that the title matcher is tight enough to be trusted as a join key.
#
# Usage: run.sh [path-to-validate-layer-entries.sh] [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = a detector regressed.
#
# NOTE ON PART 2. The obvious way to test the false-absorption regression — seed an
# extension-only check whose title merely overlaps a core check, and assert the linter
# stays quiet — is VACUOUS. `validate-layer-entries.sh` only consults the title for a
# number core ALSO defines, so an extension-only number never reaches the matcher and
# the assertion passes no matter how loose the matcher is (verified: it passes against
# the old 2-shared-token rule). The dangerous path is the CROSS-NUMBER title search in
# `layer-drift.sh`, which compares a title against EVERY upstream anchor. So Part 2
# tests the matching predicates themselves, directly. A fixture that cannot fail is
# not a fixture.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "${1:-}" "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
DRIFT="$(pick "${2:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "layer-catalog-collision:"

# --- Part 1: the linter classifies the same-number states ---------------------
out="$(bash "$LINTER" "$ROOT" 2>&1)"

printf '%s' "$out" | grep -q "NUMBER COLLISION on '24\.'" \
  && ok "24 = COLLISION (core: adversarial convergence / ext: financial-display)" \
  || bad "24 not reported as a collision — a bare 'Check 24' in the gate log has no referent"

printf '%s' "$out" | grep -q "^ERROR.*COLLISION on '24\.'" \
  && ok "the collision is an ERROR, not a warning (it reaches the durable audit record)" \
  || bad "the collision is only a warning — a warning nobody reads is how this survived"

printf '%s' "$out" | grep -q "RESTATES core section '5\.'" \
  && ok "5 = RESTATEMENT (same number AND same title), not a collision" \
  || bad "5 misclassified — same number and same title is a restatement"

printf '%s' "$out" | grep -q "'7\.'" \
  && bad "core-only check 7 flagged — the detector is comparing the wrong sets" \
  || ok "core-only check 7 correctly silent"

# --- Part 1b: a bold PROSE LIST is not a section catalog -----------------------
# `**1. Narrative drift.** Rule text continues...` is a sentence. Reading it as an
# anchor collides it with core's step 1 and reports a defect in text that defines
# no section at all — and the remedy the message prescribes ("label the heading
# `### 1. [ext:prose]`") cannot be applied to a list item. A detector that cannot
# be silenced by following its own advice trains the operator to stop reading it.
for n in 1 2; do
  printf '%s' "$out" | grep -q "COLLISION on '$n\.'" \
    && bad "bold prose list item '**$n. …**' read as a section anchor — it collides with core step $n, and the fix the message asks for cannot be applied to a sentence" \
    || ok "bold prose list item '**$n. …**' correctly not an anchor"
done

# THE POSITIVE CONTROL, and it must be able to fail. The bold tolerance exists for
# a real anchor; narrowing it must not take `**7a-post.**` with it. Core defines
# 7a-post with a DIFFERENT title, so a collision is reported only if the bold
# anchor was extracted — the assertion goes silent the moment the arm is cut too
# deep. Without this, "no findings" would score as a pass for a detector that had
# simply stopped looking.
printf '%s' "$out" | grep -q "COLLISION on '7a-post\.'" \
  && ok "bold anchor '**7a-post. …**' still extracted (collides with core's 7a-post, as it must)" \
  || bad "bold anchor '**7a-post. …**' no longer extracted — the tolerance was cut too deep, re-opening the miss it was added for"

# --- Part 1c: frontmatter that never closes ------------------------------------
# The readers are tolerant by design (they scan to EOF for their keys), so an entry
# whose `---` never closes yields its shadows/base_sha and satisfies every other
# check. Nothing asked whether the block CLOSED, so the shape linted clean while the
# body it was supposed to carry sat inside the YAML.
printf '%s' "$out" | grep -q "unterminated\.md: frontmatter opens with '---' but never closes" \
  && ok "unterminated frontmatter is an ERROR (the body is not a body)" \
  || bad "unterminated frontmatter accepted — the entry lints clean while its '### …' body parses as a YAML comment"

# NB: match the full basename — "terminated.md" is a substring of "unterminated.md",
# so a looser pattern reports the trap as the control and always fails.
printf '%s' "$out" | grep -q "steps__retro__terminated\.md: frontmatter opens" \
  && bad "the well-formed override was flagged too — the check fires on every entry, not the broken one" \
  || ok "the well-formed override stays silent (the check discriminates)"

# --- Part 2: the title predicates, tested directly -----------------------------
# Extract each matcher from its own file and exercise it. Both implement the same
# rule; both are load-bearing; both must agree.
TRAP_A='smoke test evidence deploy validate gate only'                                  # consumer check
TRAP_B='smoke test coverage for user facing changes implementation gates only'          # core check — DIFFERENT
ABS_A='cross story test strategy 3 deliverable presence sprint review gate only'        # consumer check 33
ABS_B='test strategy deliverable presence sprint review gate'                           # core check 21 — SAME check

# The containment arm needs BOTH directions or a broken guard scores a clean run.
#
# DEGEN is the bug: core `### 2. Deploy` reduces to the single token {deploy} (the
# stoplist eats gate/gates), so inter/smaller is 1/1 = 1.00 against ANY title naming
# deploy and the OR short-circuits the jaccard test at 0.20.
#
# CONT is the control, and it is the load-bearing one. ABS above CANNOT stand in for
# it: ABS scores jaccard 0.667, so it passes on the JACCARD arm and never exercises
# containment at all — delete the containment arm outright and ABS still reports a
# match. CONT scores jaccard 0.545, under the 0.6 gate, so ONLY containment can carry
# it. It is the single vector here that fails when a guard is drawn too wide.
DEGEN_A='deploy'                                                                        # core step 2 — one significant token
DEGEN_B='deploy freshness gate hard gate non skippable'                                 # consumer 2d — na=1 nb=5 jaccard=0.200 containment=1.000
CONT_A='cross story test strategy 3 deliverable presence sprint review gate only s281 1' # consumer check 33 + provenance tag
CONT_B='test strategy deliverable presence sprint review gate'                          # core check 21 — na=11 nb=6 inter=6 jaccard=0.545 containment=1.000

extract() { # extract <file> <fn-name> — awk, not sed: BSD sed mis-parses the `{` in the address
  awk -v fn="$2" '$0 ~ "^" fn "\\(\\) \\{" {p=1} p {print} p && /^\}/ {exit}' "$1"
}
probe() { # probe <file> <fn-name> <a> <b> ; exit 0 = matched
  local f="$1" fn="$2" a="$3" b="$4"
  bash -c "
    $(extract "$f" "$fn")
    ${fn} \"\$1\" \"\$2\"
  " _ "$a" "$b" 2>/dev/null
}

# The bold-anchor rule, extracted from BOTH files and run on the same input. It is a
# known drifting pair: one copy narrowed and the other not means the pull-time
# classifier and the authoring-time linter disagree about what a section even is, and
# whichever the operator did not run is the one that is wrong. Same split, three prior
# defects (readopt-override vs layer-drift; register-drift vs layer-drift; the
# heading-label rule) — so bind it here rather than trusting a comment.
BOLD_IN="$ROOT/.claude/skills/ai-dlc/extensions/steps-domain/prose.md"
for spec in "$LINTER|validate-layer-entries.sh" "$DRIFT|layer-drift.sh"; do
  f="${spec%%|*}"; name="${spec##*|}"
  [ -n "$f" ] && [ -f "$f" ] || { bad "$name not found — cannot test its bold-anchor rule"; continue; }
  got="$(bash -c "
    $(extract "$f" bold_anchors_of_file)
    bold_anchors_of_file \"\$1\"
  " _ "$BOLD_IN" 2>/dev/null | sort -u | tr '\n' ' ')"
  got="${got% }"
  if [ "$got" = "7a-post" ]; then
    ok "$name/bold_anchors_of_file: extracts the anchor and only the anchor ('7a-post')"
  else
    bad "$name/bold_anchors_of_file: returned '$got', expected '7a-post' — the two copies disagree about what a bold anchor is, or the prose list leaked back in"
  fi
done

for spec in "$LINTER|same_title|validate-layer-entries.sh" "$DRIFT|same_section|layer-drift.sh"; do
  f="${spec%%|*}"; rest="${spec#*|}"; fn="${rest%%|*}"; name="${rest##*|}"
  [ -n "$f" ] && [ -f "$f" ] || { bad "$name not found — cannot test its title matcher"; continue; }

  # SANITY FIRST. probe() reports "no match" for a function that failed to load, and
  # "no match" is what the near-miss assertion below WANTS — so a broken extraction
  # would score a false pass on the very regression this fixture exists to catch.
  # Identical titles must match; if they do not, the harness is broken, not the code.
  if ! probe "$f" "$fn" "$TRAP_A" "$TRAP_A"; then
    bad "$name/$fn: FIXTURE BROKEN — could not load the matcher (identical titles did not match). Every result below it would be a false pass."
    continue
  fi

  if probe "$f" "$fn" "$TRAP_A" "$TRAP_B"; then
    bad "$name/$fn: matched 'Smoke test evidence' to 'Smoke test coverage' on {smoke,test} — as a join key this proposes DELETING a live deploy-validate check"
  else
    ok "$name/$fn: rejects the {smoke,test} near-miss (a loose title match is worse than none)"
  fi

  if probe "$f" "$fn" "$ABS_A" "$ABS_B"; then
    ok "$name/$fn: matches the renumbered absorption (consumer 33 IS core 21)"
  else
    bad "$name/$fn: missed the renumbered absorption — a duplicate upstream already absorbed stays invisible, which is how two survived ~35 minor versions"
  fi

  if probe "$f" "$fn" "$DEGEN_A" "$DEGEN_B"; then
    bad "$name/$fn: matched core's one-token '2. Deploy' to 'Deploy freshness gate' on {deploy} at jaccard 0.20 — containment degenerated to 1/1, so every consumer heading naming deploy restates core"
  else
    ok "$name/$fn: rejects the one-token containment degeneration (jaccard 0.20 is not a section match)"
  fi

  if probe "$f" "$fn" "$CONT_A" "$CONT_B"; then
    ok "$name/$fn: still matches a 6-shared-token containment pair at jaccard 0.545 (the arm survives the guard)"
  else
    bad "$name/$fn: lost the provenance-tagged absorption at jaccard 0.545 — the guard was drawn too wide and took the containment arm with it"
  fi
done

echo
if [ "$fails" -eq 0 ]; then echo "layer-catalog-collision: PASS"; exit 0; fi
echo "layer-catalog-collision: $fails assertion(s) FAILED" >&2
exit 1
