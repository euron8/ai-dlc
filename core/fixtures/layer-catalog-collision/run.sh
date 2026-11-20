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
rp() { printf "%s/%s" "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"; }  # resolved path, no ../ segments
LINTER="$(pick "${1:-}" "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
DRIFT="$(pick "${2:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh" >&2; exit 2; }
RELABEL="$(pick "${3:-}" "$HERE/../../skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" \
                         "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" \
                         "$HERE/../../../core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh")"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found beside $HERE" >&2; exit 2; }

# IN PROCESS (BL-878). Both subjects are driven in process: `vle_ip <args>` answers what `bash "$LINTER" <args>` gives,
# in a subshell made to look like a fresh bash that sources the linter (its guard returns after defining vle_main) and
# calls vle_main (core/fixtures/lib/inproc.sh); `rec_ip <args>` does the same for the relabeller and rec_main. Their cli equivalence cells live in layer-reference-resolution (the linter) and
# relabel-theirs-collision (the relabeller), so this fixture starts neither as a program. A CORE FIXTURE SHIPS AHEAD OF
# ITS SUBJECT: a subject with neither its `<p>_main() {` line nor the column-0 source guard predates the wrap and reads
# SKIP (exit 0, never an ok); exactly one half is a respelled subject and FAILs; a subject grep cannot READ is FIXTURE
# ERROR. A missing relabeller keeps its own Part 4b FIXTURE BROKEN line below.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$LINTER" vle_main; g_vle=$?
g_rec=0; [ -z "$RELABEL" ] || { wrap_gate "$RELABEL" rec_main; g_rec=$?; }
g_ld=0; [ -z "$DRIFT" ] || { wrap_gate "$DRIFT" ld_main; g_ld=$?; }
if [ "$g_vle" = 2 ] || [ "$g_rec" = 2 ] || [ "$g_ld" = 2 ]; then exit 2; fi
if [ "$g_vle" = 1 ] || [ "$g_rec" = 1 ] || [ "$g_ld" = 1 ]; then echo "layer-catalog-collision: 1 FAILED" >&2; exit 1; fi
if [ "$g_vle" = 3 ] || [ "$g_rec" = 3 ] || [ "$g_ld" = 3 ]; then echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE"; fi
# Neither subject is inproc_load-ed: inproc_run then sources each one inside its own subshell, so every pass is logged
# under the path it sourced (a loaded subject would claim the other subject's passes as its own).
vle_ip() { inproc_run "$LINTER" vle_main "$@"; }
rec_ip() { inproc_run "$RELABEL" rec_main "$@"; }

ROOT="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT

echo "layer-catalog-collision:"

# --- Part 1: the linter classifies the same-number states ---------------------
echo "HERMETIC-CONSUMED $(rp "$LINTER")"
[ -f "$(dirname "$LINTER")/artifact-path-config.sh" ] && echo "HERMETIC-CONSUMED $(rp "$(dirname "$LINTER")/artifact-path-config.sh")"
out="$(vle_ip "$ROOT" 2>&1)"

grep -q "NUMBER COLLISION on '24\.'" <<<"$out" \
  && ok "E6 — 24 = COLLISION (core: adversarial convergence / ext: financial-display)" \
  || bad "24 not reported as a collision — a bare 'Check 24' in the gate log has no referent"

grep -q "^ERROR.*COLLISION on '24\.'" <<<"$out" \
  && ok "E6 — the collision is an ERROR, not a warning (it reaches the durable audit record)" \
  || bad "the collision is only a warning — a warning nobody reads is how this survived"

grep -q "RESTATES core section '5\.'" <<<"$out" \
  && ok "W1 — 5 = RESTATEMENT (same number AND same title), not a collision" \
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
  && ok "E1 — unterminated frontmatter is an ERROR (the body is not a body)" \
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
# IN PROCESS: the extracted definition is evaluated in a subshell with a fresh shell's -u and pipefail off (as the
# `bash -c` worker it replaces ran it), and each call is one counted in-process pass of the file it came from.
probe() { # probe <file> <fn-name> <a> <b> ; exit 0 = matched
  local f="$1" fn="$2" a="$3" b="$4"
  ( set +u +o pipefail; eval "$(extract "$f" "$fn")"
    fx_inproc "$f"; "$fn" "$a" "$b" ) 2>/dev/null
}

# The bold-anchor rule, extracted from BOTH files and run on the same input. It is a
# known drifting pair: one copy narrowed and the other not means the pull-time
# classifier and the authoring-time linter disagree about what a section even is, and
# whichever the operator did not run is the one that is wrong. Same split, three prior
# defects (readopt-override vs layer-drift; register-drift vs layer-drift; the
# heading-label rule) — so bind it here rather than trusting a comment.
BOLD_IN="$ROOT/.claude/skills/ai-dlc/extensions/steps-domain/prose.md"
echo "HERMETIC-CONSUMED $(rp "$DRIFT")"
for spec in "$LINTER|validate-layer-entries.sh" "$DRIFT|layer-drift.sh"; do
  f="${spec%%|*}"; name="${spec##*|}"
  [ -n "$f" ] && [ -f "$f" ] || { bad "$name not found — cannot test its bold-anchor rule"; continue; }
  got="$( ( set +u +o pipefail; eval "$(extract "$f" bold_anchors_of_file)"
            fx_inproc "$f"; bold_anchors_of_file "$BOLD_IN" ) 2>/dev/null | sort -u | tr '\n' ' ')"
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

grep -q "RULE NUMBER COLLISION on 'Rule 29'" <<<"$out" \
  && ok "W4 — Rule 29 = COLLISION (core: steering budget / ext: split-dispatch)" \
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
  && ok "W4 — Rule 8 = RESTATEMENT (same number AND same title), not a collision" \
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
  echo "HERMETIC-CONSUMED $(rp "$RELABEL")"
  rel_out="$(rec_ip "$ROOT" 2>&1)"
  grep -q '^  +  ## Rule 29 \[ext:rules\] -- ' <<<"$rel_out" \
    && ok "the relabeller writes '## Rule 29 [ext:rules] -- …' (label before the separator, integer unmoved)" \
    || bad "the relabeller cannot rewrite the heading the linter reports — the prescribed remedy does not run"

  grep -q 'Rule 44' <<<"$rel_out" \
    && bad "the relabeller would rewrite the extension-only 'Rule 44' — it relabels headings core does not define" \
    || ok "  and leaves the extension-only rule 44 alone"

  rec_ip "$ROOT" --apply >/dev/null 2>&1
  after="$(vle_ip "$ROOT" 2>&1)"
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
  out="$(inproc_run "$1" vle_main "$2" 2>&1)"
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
  inproc_run "$1" vle_main "$2" 2>&1 | grep -oE "(rename to '[^']+'|renumber to 'Rule [0-9]+')" | sort -u | tr '\n' ' '
}

BAND_WANT="5=COLLIDED 24=COLLIDED 30=OOB 33=OOB 40b=OOB 933=- AP=OOB XQ=- 0=OOB 7a-post=COLLIDED Rule 8=COLLIDED Rule 29=COLLIDED Rule 30=COLLIDED Rule 44=OOB Rule 931=-"
BAND_GOT="$(band_vector "$LINTER" "$ROOT")"
if [ "$BAND_GOT" = "$BAND_WANT" ]; then
  ok "E15 — the partition reports every id FORM and stays silent on every in-band one"
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
  && ok "  and the E15 band finding is an ERROR (the migration blocks, it is not advisory)" \
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

echo
report_end layer-catalog-collision
