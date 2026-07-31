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

grep -q "NUMBER COLLISION on '24\.'" <<<"$out" \
  && ok "24 = COLLISION (core: adversarial convergence / ext: financial-display)" \
  || bad "24 not reported as a collision — a bare 'Check 24' in the gate log has no referent"

grep -q "^ERROR.*COLLISION on '24\.'" <<<"$out" \
  && ok "the collision is an ERROR, not a warning (it reaches the durable audit record)" \
  || bad "the collision is only a warning — a warning nobody reads is how this survived"

grep -q "RESTATES core section '5\.'" <<<"$out" \
  && ok "5 = RESTATEMENT (same number AND same title), not a collision" \
  || bad "5 misclassified — same number and same title is a restatement"

grep -q "'7\.'" <<<"$out" \
  && bad "core-only check 7 flagged — the detector is comparing the wrong sets" \
  || ok "core-only check 7 correctly silent"

# --- Part 1b: a bold PROSE LIST is not a section catalog -----------------------
# `**1. Narrative drift.** Rule text continues...` is a sentence. Reading it as an
# anchor collides it with core's step 1 and reports a defect in text that defines
# no section at all — and the remedy the message prescribes ("label the heading
# `### 1. [ext:prose]`") cannot be applied to a list item. A detector that cannot
# be silenced by following its own advice trains the operator to stop reading it.
for n in 1 2; do
  grep -q "COLLISION on '$n\.'" <<<"$out" \
    && bad "bold prose list item '**$n. …**' read as a section anchor — it collides with core step $n, and the fix the message asks for cannot be applied to a sentence" \
    || ok "bold prose list item '**$n. …**' correctly not an anchor"
done

# THE POSITIVE CONTROL, and it must be able to fail. The bold tolerance exists for
# a real anchor; narrowing it must not take `**7a-post.**` with it. Core defines
# 7a-post with a DIFFERENT title, so a collision is reported only if the bold
# anchor was extracted — the assertion goes silent the moment the arm is cut too
# deep. Without this, "no findings" would score as a pass for a detector that had
# simply stopped looking.
grep -q "COLLISION on '7a-post\.'" <<<"$out" \
  && ok "bold anchor '**7a-post. …**' still extracted (collides with core's 7a-post, as it must)" \
  || bad "bold anchor '**7a-post. …**' no longer extracted — the tolerance was cut too deep, re-opening the miss it was added for"

# --- Part 1c: frontmatter that never closes ------------------------------------
# The readers are tolerant by design (they scan to EOF for their keys), so an entry
# whose `---` never closes yields its shadows/base_sha and satisfies every other
# check. Nothing asked whether the block CLOSED, so the shape linted clean while the
# body it was supposed to carry sat inside the YAML.
grep -q "unterminated\.md: frontmatter opens with '---' but never closes" <<<"$out" \
  && ok "unterminated frontmatter is an ERROR (the body is not a body)" \
  || bad "unterminated frontmatter accepted — the entry lints clean while its '### …' body parses as a YAML comment"

# NB: match the full basename — "terminated.md" is a substring of "unterminated.md",
# so a looser pattern reports the trap as the control and always fails.
grep -q "steps__retro__terminated\.md: frontmatter opens" <<<"$out" \
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

# --- Part 4: the RULE namespace (W4) ------------------------------------------
#
# The check-number collision has had a detector since v0.49.0. Rule numbers have
# exactly the same property -- extensions are additive, so an extension's
# `## Rule 29` and core's `### Rule 29` render into one merged rulebook under one
# integer -- and had none, because the anchor grammar the collision arm uses
# matches only ids terminated by `[.—]` and a rule heading has no terminator.
# Measured on the reference consumer when W4 was written: EIGHT live collisions,
# reported by nothing.

RELABEL="$(pick "${3:-}" "$HERE/../../skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" \
                         "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" \
                         "$HERE/../../../core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh")"

grep -q "RULE NUMBER COLLISION on 'Rule 29'" <<<"$out" \
  && ok "Rule 29 = COLLISION (core: steering budget / ext: split-dispatch)" \
  || bad "Rule 29 not reported — a bare 'Rule 29' in a gate log has two referents and nothing says so"

grep -q "^WARN.*RULE NUMBER COLLISION on 'Rule 29'" <<<"$out" \
  && ok "  and it is a WARN, never an ERROR (a consumer must not be blocked from taking a fix)" \
  || bad "  but the rule collision is an ERROR — eight on first contact is a linter that gets switched off"

# The remedy must silence the message. Asserted directly, because a detector whose
# own prescribed fix does not clear it is the defect heading_labelled was added for.
grep -q "RULE NUMBER COLLISION on 'Rule 30'" <<<"$out" \
  && bad "the ALREADY-LABELLED 'Rule 30 [ext:rules]' still reports — the fix the message asks for cannot clear the message" \
  || ok "a labelled rule heading is the resolved state and is silent"

grep -q "RESTATES core 'Rule 8'" <<<"$out" \
  && ok "Rule 8 = RESTATEMENT (same number AND same title), not a collision" \
  || bad "Rule 8 misclassified — same number and same title is a Rule 27(c) restatement"

grep -q "COLLISION on 'Rule 8'" <<<"$out" \
  && bad "Rule 8 reported as a collision as well as a restatement — the split on title is not happening" \
  || ok "  and it is not ALSO reported as a collision"

# ANCHORED ON THE ARM'S OWN WORDING, not on the shared subject. E15 (Part 5) reports
# Rule 44 too, by a different clause and for the opposite reason, so the old bare
# `grep -q "'Rule 44'"` here would fail the moment the band arm shipped — and it would
# have failed pointing at the collision detector, which is not what changed. Two arms
# naming one string is row 4's recorded trap; assert on the wording that distinguishes
# them.
grep -q "RULE NUMBER COLLISION on 'Rule 44'" <<<"$out" \
  && bad "extension-only 'Rule 44' flagged as a COLLISION — core defines no rule 44, so every consumer rule would report" \
  || ok "extension-only rule 44 correctly silent for the collision arm"

# NAMESPACE SEPARATION, and it can fail. Core defines `Rule 24` in SKILL.md and
# check `24.` in gate-validation.md. A grammar that learned the word `Rule` would
# fold them into one id and start joining a rule to a check by integer.
grep -q "RULE NUMBER COLLISION on 'Rule 24'" <<<"$out" \
  && bad "'Rule 24' reported although no extension defines it — the rule grammar is matching core's CHECK 24, i.e. the two catalogs have merged" \
  || ok "core's Rule 24 and core's check 24 stay separate catalogs"

# --- Part 4b: the reporter and the rewriter agree on what a rule heading is ----
# I34 binds their RULE_RE textually. This binds them BEHAVIOURALLY, on a real
# input: the linter reports Rule 29, and applying the relabeller must make the
# linter stop reporting it. A detector that names a heading the rewriter cannot
# see hands the operator a remedy that does not run.
if [ -z "$RELABEL" ]; then
  bad "FIXTURE BROKEN — cannot locate relabel-extension-checks.sh; Part 4b would pass by not running"
else
  rel_out="$(bash "$RELABEL" "$ROOT" 2>&1)"
  grep -q '^  +  ## Rule 29 \[ext:rules\] -- ' <<<"$rel_out" \
    && ok "the relabeller writes '## Rule 29 [ext:rules] -- …' (label before the separator, integer unmoved)" \
    || bad "the relabeller cannot rewrite the heading the linter reports — the prescribed remedy does not run"

  grep -q 'Rule 44' <<<"$rel_out" \
    && bad "the relabeller would rewrite the extension-only 'Rule 44' — it relabels headings core does not define" \
    || ok "  and leaves the extension-only rule 44 alone"

  bash "$RELABEL" "$ROOT" --apply >/dev/null 2>&1
  after="$(bash "$LINTER" "$ROOT" 2>&1)"
  if grep -q "RULE NUMBER COLLISION" <<<"$after"; then
    bad "applying the relabeller did not clear the collision report — reporter and rewriter disagree about the heading"
  else
    ok "applying the relabeller clears every rule collision (remedy closes its own report)"
  fi
  # And the control: the apply must not have silenced the linter wholesale.
  grep -q "RESTATES core section '5\.'" <<<"$after" \
    && ok "  and the unrelated check-side findings survive the apply (the linter still runs)" \
    || bad "  but the check-side findings vanished too — the 'cleared' result above is a dead linter, not a fix"
fi

# --- Part 5: the TOTAL naming partition (E15) -----------------------------------
#
# Parts 1 and 4 test COLLISION detectors, and both join the entry's id against the ids
# core defines today. That join is why neither can see the defect this part covers: a
# consumer allocating an id core has NOT reached matches nothing and reports clean,
# until the release where core allocates it and the collision appears retroactively
# across gate logs that are already the audit record.
#
# THE PARTITION IS TOTAL, and this part is the record of what that replaced. It shipped
# with three exclusions — suffixed ids, alphabetic ids, and ids core already defines —
# plus a `kind: check` scope, and on the reference consumer those four together were
# hiding SEVEN live collisions and thirty-nine subjects. Each is now a governed id form
# with its own remedy, and the seed carries one of every form so that removing any arm
# moves a named cell rather than merely lowering a count.
#
# Scored as a VECTOR over every seeded id, never per row. Four of the five arms are
# occupied by more than one subject, so a per-row assertion would report entanglement on
# every mutant; the vector states the whole expected table positively and no mutant can
# satisfy another's assertion by going quiet.
band_vector() { # band_vector <linter> <root> -> "<id>=<OOB|COLLIDED|-> …" over every seeded id
  local out cell v=''
  out="$(bash "$1" "$2" 2>&1)"
  for s in "5." "24." "30." "33." "40b." "933." "AP." "XQ." "0." "7a-post." \
           "Rule 8" "Rule 29" "Rule 30" "Rule 44" "Rule 931"; do
    cell='-'
    grep -qF "OUT OF BAND — '$s'" <<<"$out" && cell=OOB
    grep -qF "OUT OF BAND, ALREADY COLLIDED — '$s'" <<<"$out" && cell=COLLIDED
    v="$v${v:+ }${s%.}=$cell"
  done
  printf '%s' "$v"
}
band_remedies() { # band_remedies <linter> <root> -> every remedy it offers, sorted
  bash "$1" "$2" 2>&1 | grep -oE "(rename to '[^']+'|renumber to 'Rule [0-9]+')" | sort -u | tr '\n' ' '
}

BAND_WANT="5=COLLIDED 24=COLLIDED 30=OOB 33=OOB 40b=OOB 933=- AP=OOB XQ=- 0=OOB 7a-post=COLLIDED Rule 8=COLLIDED Rule 29=COLLIDED Rule 30=COLLIDED Rule 44=OOB Rule 931=-"
BAND_GOT="$(band_vector "$LINTER" "$ROOT")"
if [ "$BAND_GOT" = "$BAND_WANT" ]; then
  ok "the partition reports every id FORM and stays silent on every in-band one"
else
  bad "the band vector moved.
          got  '$BAND_GOT'
          want '$BAND_WANT'
        Each cell is a separate arm: 30/33 bare-below-floor, 5/24 core-defined, 40b suffixed, AP alphabetic, 0 step-domain, 7a-post a bold anchor core also defines. 933/XQ/Rule 931 are the in-band controls and a non-'-' there means the arm fires on a conformant entry, so following its own advice cannot clear it."
fi

# ERROR, not WARN. The partition is a hard invariant now: the consumer's pre-push refuses
# until it migrates, which is what makes the collision unrepresentable rather than merely
# reported. A WARN here would leave the migration optional forever.
grep -q "^ERROR.*OUT OF BAND" <<<"$out" \
  && ok "  and the band finding is an ERROR (the migration blocks, it is not advisory)" \
  || bad "  but the band finding is not an ERROR — a reported-only partition is the label-not-a-namespace state the band exists to replace"
grep -q "^WARN.*OUT OF BAND" <<<"$out" \
  && bad "  a band finding was emitted at WARN — two severities for one clause means one of them is not the contract" \
  || ok "  and no band finding is emitted at WARN"

# THE REMEDY IS PART OF THE FINDING, and it has its own failure mode: a remedy that is
# itself out of band. `0` -> `90` and `5c-table` -> `95c-table` are both below the floor,
# which is a message that tells an author to move somewhere the same arm will report.
BAND_REM="$(band_remedies "$LINTER" "$ROOT")"
bad_rem=''
for r in $(grep -oE "'[0-9][0-9a-z-]*\.'" <<<"$BAND_REM" | tr -d "'."); do
  n="${r%%[!0-9]*}"
  [ "$((10#$n))" -ge 900 ] || bad_rem="$bad_rem $r"
done
if [ -z "$bad_rem" ]; then
  ok "  and every remedy it offers is itself in band (no message sends an author somewhere this arm reports)"
else
  bad "  a remedy is itself OUT OF BAND:$bad_rem — the zero-padding is what keeps '0b' from becoming '90b', and without it the message prescribes a move to a range the same arm governs"
fi

# --- Part 5b: E16's zero guard, which this seed is the negative control for -----
#
# The seeded tree is a mktemp dir with no git in it, so E16 CANNOT read an id history —
# and an unreadable history and a clean one produce the same empty retired-set. The arm
# must therefore refuse out loud here. This fixture is where that is asserted because
# the condition is free: every other fixture that seeds a bare tree has it too.
grep -q "RETIRED-ID HISTORY UNREADABLE" <<<"$out" \
  && ok "E16 REFUSES on a tree with no id history rather than reporting it clean" \
  || bad "E16 was silent on a tree it cannot read an id history from. An unreadable history and a clean one now produce identical output, which is the defect the arm was built to end."
grep -q "not inside a git work tree" <<<"$out" \
  && ok "  and it names WHY it could not read it, so the operator can tell a refusal from a pass" \
  || bad "  but it did not name the reason, so a refusal is indistinguishable from a finding-free run"

# --- Part 6: every arm of the partition is load-bearing, proved by mutation ------
#
# Part 5 proves the partition FIRES. What it cannot prove is that each ARM is doing its
# own work — and three of the four exclusions this release removed were unfalsifiable in
# exactly that way. The suffix exclusion is the worked example: with it removed but the
# numeric comparison unchanged, `[ 40b -lt 900 ]` ERRORS and reports nothing, which is
# indistinguishable from excluding it on purpose. Only a mutation that moves a NAMED CELL
# tells the two apart.
#
# ONE ASSERTION PER MUTANT: the complete expected vector, stated positively and distinct
# from every other mutant's. A mutant that broke the linter outright fails its own
# assertion instead of passing it.
#
# MUTATION DISCIPLINE. Every mutant is a COPY of the linter, `cmp -s`-guarded so a sed
# that matched nothing cannot pass as a mutation, run against a FRESH seed (Part 4b's
# `--apply` rewrote the shared one), with an unmutated control copy from the same
# directory so a copy that simply fails to run cannot score as a kill.
MROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: mutant seed failed" >&2; exit 2; }
MDIR="$MROOT/.fixture-mutants"
mkdir -p "$MDIR"

cp "$LINTER" "$MDIR/control.sh"
CTRL="$(band_vector "$MDIR/control.sh" "$MROOT")"
if [ "$CTRL" = "$BAND_WANT" ]; then
  ok "CONTROL: an unmutated copy reproduces the shipped vector (the mutants below run against a live linter)"
else
  bad "CONTROL FAILED — an unmutated COPY of the linter does not reproduce the shipped vector.
          copy '$CTRL'
          ship '$BAND_WANT'
        Every mutant below would be scored against a linter that is not working, and a copy that cannot run scores as a kill for all of them."
fi

mutant() { # mutant <label> <sed> <want-vector> <why>
  local label="$1" prog="$2" want="$3" why="$4" f="$MDIR/m.sh" got
  sed "$prog" "$LINTER" > "$f"
  if cmp -s "$LINTER" "$f"; then
    bad "MUTATION VACUOUS ($label) — the sed matched nothing in the linter, so the assertion below would score an unchanged run as a kill"
    return
  fi
  got="$(band_vector "$f" "$MROOT")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT killed: $label"
  else
    bad "MUTANT '$label' did not produce its expected vector, so what it is meant to prove is unproven.
          got  '$got'
          want '$want'
        $why"
  fi
}

# M1 — the floor is what decides, not a hardcoded subject list. Raising it past 933 must
# pull the two in-band NUMERIC controls in and leave the alphabetic one out, because the
# alphabetic half is a prefix and has no floor.
mutant "raising BAND_FLOOR past 933 pulls in the in-band numeric controls and ONLY those" \
  's|^BAND_FLOOR=900$|BAND_FLOOR=1000|' \
  "5=COLLIDED 24=COLLIDED 30=OOB 33=OOB 40b=OOB 933=OOB AP=OOB XQ=- 0=OOB 7a-post=COLLIDED Rule 8=COLLIDED Rule 29=COLLIDED Rule 30=COLLIDED Rule 44=OOB Rule 931=OOB" \
  "If 933 and Rule 931 do not move, the arm is keyed on something other than BAND_FLOOR and I45's binding to the same constant proves nothing. If XQ moves too, the alphabetic half is reading the floor, which it must not."

# M2 — the alphabetic half is a real arm, not decoration. Without it `AP` goes silent and
# nothing else moves: the numeric cells are produced by a different branch entirely.
mutant "removing the alphabetic branch silences 'AP' and nothing else" \
  's|^    \[A-Za-z\]\*) printf .*|    [A-Za-z]*) return 1 ;;|' \
  "5=COLLIDED 24=COLLIDED 30=OOB 33=OOB 40b=OOB 933=- AP=- XQ=- 0=OOB 7a-post=COLLIDED Rule 8=COLLIDED Rule 29=COLLIDED Rule 30=COLLIDED Rule 44=OOB Rule 931=-" \
  "A band is numeric and cannot order 'AP', so the alphabetic half is a reserved prefix instead. This is the arm that found the reference consumer's own 'H1' colliding with core's after four releases of a numeric-only band."

# M3 — the already-collided split is a real split. Forcing the membership test false must
# turn every COLLIDED cell into a plain OOB while the verdict itself is unchanged: the
# two messages are one clause, and the difference is what has already happened, not
# whether it is reported.
mutant "forcing the core-membership test false turns every COLLIDED cell into OOB and changes no verdict" \
  's#if grep -Fxq -- "\$a" <<<"\$core_anchors"; then#if false; then#; s#if grep -Fxq -- "\$n" <<<"\$core_rules"; then#if false; then#' \
  "5=OOB 24=OOB 30=OOB 33=OOB 40b=OOB 933=- AP=OOB XQ=- 0=OOB 7a-post=OOB Rule 8=OOB Rule 29=OOB Rule 30=OOB Rule 44=OOB Rule 931=-" \
  "Every cell must stay reported. If one goes to '-', the membership test is gating the VERDICT and not just the message — which is the exclusion this release removed, growing back."

# M4 — the step-domain scope really is gone. Restoring `kind: check` must silence exactly
# the two ids that come from step-domain entries and leave every check-side cell alone.
mutant "restoring the kind: check scope silences ONLY the step-domain ids" \
  's|^  while IFS= read -r a; do$|  if [ "$kind" = check ]; then while IFS= read -r a; do|; s|^  done < <(defined_anchors "\$f")$|  done < <(defined_anchors "$f"); fi|' \
  "5=COLLIDED 24=COLLIDED 30=OOB 33=OOB 40b=OOB 933=- AP=OOB XQ=- 0=- 7a-post=- Rule 8=COLLIDED Rule 29=COLLIDED Rule 30=COLLIDED Rule 44=OOB Rule 931=-" \
  "'0.' and '7a-post.' are prose.md's, which is kind: step-domain. The rule cells must not move — rules were never kind-scoped — and no check-side cell may move either, or the scope is doing more than it claims."

rm -rf "$MROOT"

echo
if [ "$fails" -eq 0 ]; then echo "layer-catalog-collision: PASS"; exit 0; fi
echo "layer-catalog-collision: $fails assertion(s) FAILED" >&2
exit 1
