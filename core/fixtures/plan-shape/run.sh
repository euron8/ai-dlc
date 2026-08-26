#!/usr/bin/env bash
# plan-shape — assert every arm of validate-plan-shape.sh can FAIL, and that a
# conforming plan trips none of them.
#
# A prose linter is the genre most likely to ship inert: its subject is text, so an arm
# whose regex never matches looks exactly like an arm with nothing to report, and the
# corpus (one plan) is far too small for a green run to mean anything on its own. So
# each arm gets a seeded defect that MUST fire and a conforming control that MUST NOT.
#
# The control is not decoration. Most arms are absence checks — a validator that errored
# on every file would satisfy every positive assertion here and be useless. P7 carries a
# second control of its own, and it is the more important one: the arm's entire defence is
# that it does not fire on a PROSE stop-condition, which is correct authoring.
#
# Usage: run.sh [path-to-validate-plan-shape.sh]
# Exit:  0 = every assertion holds, 1 = an arm regressed, 2 = the fixture could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
V="$(pick "${1:-}" "$HERE/../../../scripts/validate-plan-shape.sh" "$HERE/../../scripts/validate-plan-shape.sh")"
# A MISSING SUBJECT IS NOT A PASS: every assertion below reads the validator's output, so
# a run that cannot invoke it produces nothing and scores green on the negative arms.
[ -n "$V" ] || { echo "FIXTURE ERROR: cannot locate validate-plan-shape.sh" >&2; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/plan-shape.XXXXXX")"
trap 'rm -rf "$T"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "plan-shape:"

# A CONFORMING PLAN. Every seeded defect below is this file with ONE thing changed, so a
# firing arm is attributable to that change and to nothing else.
# THE BASENAME IS AN ARGUMENT, because P10 asks whether the plan names ITSELF. A fixed
# resume line would name one file while the seed is written as another, so every case but one
# would fail the arm for a reason that has nothing to do with what it tests.
#
# The heredoc stays QUOTED. Its body carries backticks (`/some/repo`, the citation), and an
# unquoted heredoc would COMMAND-SUBSTITUTE them -- so the resume line is printf'd ahead of it
# rather than interpolated into it. Line 1 is still the title, so `tail -n +2` at the P9b site
# keeps working.
conforming() {
  local base="${1:-plan.md}"
  printf '# Some plan\n\n'
  printf 'Resume with: `READ and FOLLOW docs/plans/%s`\n' "$base"
  cat <<'MD'

## Start here

Working repo: `/some/repo`. Reference consumer: `/other/repo` — read it, never write it.

Ping the operator on any question or decision, and when this plan completes.

1. Do the first thing.
2. Do the second thing.

After the merge, re-derive this plan's own resume block before stopping.

## Where things stand

Evidence: `scripts/validate-plan-shape.sh:1` is the subject of this fixture.

### R1 — the enabler — **SHIPPED as v0.1.0**
MD
}

run() { bash "$V" "$1" 2>&1; }

conforming good.md > "$T/good.md"
out="$(run "$T/good.md")"
if grep -q '0 error(s)' <<<"$out"; then ok "a conforming plan raises no error"
else bad "the conforming control errored — every positive assertion below is then meaningless: $(grep -m1 ERROR <<<"$out")"; fi

# NON-VACUITY for the citation arm: the control must actually CONTAIN a citation the
# validator resolves, or its silence says nothing about whether the arm works.
if grep -qE 'scripts/validate-plan-shape\.sh:[0-9]+' "$T/good.md"; then
  ok "  and it carries a resolving path:line citation, so the citation arm had a subject"
else
  bad "the control has no citation — the citation arm's silence on it proves nothing"
fi

# --- P3b the operator ping ---------------------------------------------------------
# A plan is executed by a session the operator cannot see, so "still working" and "stopped,
# waiting on you" are indistinguishable from outside and silence is a stall found only by
# polling. REQUIRED, not advisory: the instruction has to survive into plans nobody in this
# repo writes, and a convention with no enforcer is a suggestion.
conforming p3b.md | grep -v '^Ping the operator' > "$T/p3b.md"
if ! cmp -s "$T/good.md" "$T/p3b.md"; then
  grep -q 'no operator-ping instruction' <<<"$(run "$T/p3b.md")" \
    && ok "P3b fires when the plan never tells its executor to speak" \
    || bad "P3b did not fire on a plan with no ping instruction"
else
  bad "FIXTURE BROKEN: stripping the ping line changed nothing, so P3b's arm has no subject"
fi
# CONTROL: it is an ERROR and not a warning, or a plan can ship without the clause.
grep -qE '^ERROR .*operator-ping' <<<"$(run "$T/p3b.md")" \
  && ok "  and it is an ERROR — a plan that omits it fails the build rather than nagging" \
  || bad "  the ping finding is not an ERROR, so the instruction is optional in practice"

# --- P1 entry point ---------------------------------------------------------------
conforming p1.md | grep -v '^## Start here$' > "$T/p1.md"
grep -q "no '## Start here' section" <<<"$(run "$T/p1.md")" \
  && ok "P1 fires when the entry point is missing" \
  || bad "P1 silent on a plan with no '## Start here' — a resuming session acts on whatever it reads first"

# --- P2 ordered next action -------------------------------------------------------
conforming p2.md | grep -vE '^[12]\. ' > "$T/p2.md"
grep -q 'no numbered action list' <<<"$(run "$T/p2.md")" \
  && ok "P2 fires when there is nothing to follow" \
  || bad "P2 silent on a plan with no numbered action — 'FOLLOW this plan' has no referent"

# --- P3 read/write boundary (WARN, never an error) --------------------------------
conforming p3.md | sed 's/ — read it, never write it\.//' > "$T/p3.md"
o3="$(run "$T/p3.md")"
grep -q 'states no read/write boundary' <<<"$o3" \
  && ok "P3 warns when the boundary is unstated" \
  || bad "P3 silent on a plan that never says which tree must not be written"
grep -q '0 error(s)' <<<"$o3" \
  && ok "  and P3 is a WARNING, not a blocker" \
  || bad "P3 escalated to an error — a plan touching one tree only would then be unpushable"

# --- P4 citations resolve ---------------------------------------------------------
conforming p4a.md | sed 's|scripts/validate-plan-shape\.sh:1|scripts/no-such-file.sh:1|' > "$T/p4a.md"
grep -q 'does not exist' <<<"$(run "$T/p4a.md")" \
  && ok "P4 fires on a citation whose file is gone" \
  || bad "P4 silent on a citation to a nonexistent file"

conforming p4b.md | sed 's|scripts/validate-plan-shape\.sh:1|scripts/validate-plan-shape.sh:999999|' > "$T/p4b.md"
grep -q 'resolves to nothing' <<<"$(run "$T/p4b.md")" \
  && ok "  and on one whose line number is past EOF" \
  || bad "P4 checks existence but not bounds — a citation can point past the end and pass"

# --- P5 contradictory status ------------------------------------------------------
# THE DEFECT THIS VALIDATOR WAS WRITTEN FOR: a shipped release still described as work
# to do. A session told to FOLLOW the plan redoes it.
{ conforming p5.md; printf '\n| R1 | not started | something |\n'; } > "$T/p5.md"
grep -q 'BOTH shipped and not-started' <<<"$(run "$T/p5.md")" \
  && ok "P5 fires when one identifier is both shipped and not-started" \
  || bad "P5 silent on a contradiction — this is the exact defect the validator exists for"

# --- P6 one current status record -------------------------------------------------
{ conforming p6.md; printf '\n## Status\n\nA second record with no marker.\n'; } > "$T/p6.md"
grep -q 'status sections' <<<"$(run "$T/p6.md")" \
  && ok "P6 fires on two unmarked status records" \
  || bad "P6 silent on duplicate status sections — the reader believes whichever comes first"

# CONTROL for P6, and the one that keeps it honest: marking the second as superseded is
# the remedy the message prescribes, so it MUST silence the row. An arm that cannot be
# quieted by following its own advice teaches the operator to stop reading it.
{ conforming p6b.md; printf '\n## Status\n\nSuperseded — see the Start here section above.\n'; } > "$T/p6b.md"
grep -q '0 error(s)' <<<"$(run "$T/p6b.md")" \
  && ok "  and a second record marked superseded is accepted" \
  || bad "P6 fires even on a correctly-marked superseded section — the remedy does not silence it"

# --- P7 an instruction that ships its own opt-out ---------------------------------
# Seeded from the real defect: a runbook told a consumer session to run a consolidation
# pass and put a decision table beside it resolving the healthy outcome to "stop".
{ conforming p7.md; printf '\n```\nrun the budget check\n# `ok`   -> no consolidation target. Do the re-home and stop.\n```\n'; } > "$T/p7.md"
o7="$(run "$T/p7.md")"
grep -q 'opt-out inside an instruction' <<<"$o7" \
  && ok "P7 fires on a comment that maps an outcome to NOT doing the work" \
  || bad "P7 silent on an opt-out beside an instruction — the executor can skip the work and cite the plan"
grep -q '0 error(s)' <<<"$o7" \
  && ok "  and P7 is a WARNING — a legitimately conditional step must stay pushable" \
  || bad "P7 escalated to an error; a plan with a real conditional would then be unpushable"

# THE CONTROL THAT MATTERS, because this arm's whole defence is its narrowness: a PROSE
# conditional is correct authoring and must not fire. Every runbook in this repo stops on
# a stamp mismatch, and an arm that flagged that would be off within a week.
{ conforming p7b.md; printf '\nA different answer means STOP and ping the operator; do not proceed.\n'; } > "$T/p7b.md"
grep -q 'opt-out inside an instruction' <<<"$(run "$T/p7b.md")" \
  && bad "P7 fired on a prose stop-condition — that is correct authoring and the arm is too wide" \
  || ok "  and it leaves a prose stop-condition alone, which is the false-positive it must not have"

# --- P9 a live plan carries evidence ----------------------------------------------
# P4 checks that citations RESOLVE, so a plan citing nothing passes it perfectly. This arm is
# the one that can tell "evidence checked" from "no evidence offered", and the conforming
# control above is what proves it has a subject rather than being silent for lack of one.
conforming p9.md | grep -v 'scripts/validate-plan-shape\.sh:' > "$T/p9.md"
grep -q 'LIVE plan carrying no resolving' <<<"$(run "$T/p9.md")" \
  && ok "P9 fires on a live plan with no resolving citation" \
  || bad "P9 silent on a live plan citing nothing — a plan whose evidence was never checked passes P4 cleanly"

# THE SCOPING CONTROL. A discharged plan is a record, and editing a spent file to bolt
# evidence onto it would be fabrication. The scope is by construction — the banner a resuming
# session reads first — so it has to be proven to actually exempt.
{ printf -- '# Some plan — DISCHARGED\n'; conforming p9b.md | tail -n +2 | grep -v 'scripts/validate-plan-shape\.sh:'; } > "$T/p9b.md"
grep -q 'LIVE plan carrying no resolving' <<<"$(run "$T/p9b.md")" \
  && bad "P9 fired on a DISCHARGED plan — a spent record would have to be edited to add evidence it never had" \
  || ok "  and it exempts a banner-marked plan, so a spent record is not a backlog item"

# --- P10 a live plan carries its own resume one-liner -----------------------------
# THE OPERATOR RESUMES WITH ONE SENTENCE AND NOTHING ELSE. Every other arm checks a plan is
# well formed once you are reading the right part of it; this one checks what happens before
# that, when a fresh session opens the file at the top and acts on what it meets first.
conforming p10.md | grep -v 'READ and FOLLOW' > "$T/p10.md"
grep -q 'does not carry its own resume one-liner' <<<"$(run "$T/p10.md")" \
  && ok "P10 fires on a live plan with no resume one-liner" \
  || bad "P10 silent on a plan that never says how to resume it — the operator's one-line prompt has no landing point"

# THE CASE THAT ACTUALLY HAPPENS, and the reason the arm keys on the file's OWN basename: a
# plan copied from another plan inherits the ancestor's resume line and sends the session to
# the wrong file. A bare presence check would pass that.
conforming p10b.md | sed 's|docs/plans/p10b\.md|docs/plans/SOME-ANCESTOR.md|' > "$T/p10b.md"
grep -q 'does not carry its own resume one-liner' <<<"$(run "$T/p10b.md")" \
  && ok "  and on one whose resume line names a DIFFERENT plan — an inherited line is the real defect" \
  || bad "P10 accepts a resume line pointing at another file; a copied plan sends the session elsewhere"

# THE SCOPING CONTROL, the same shape as P9b. A discharged plan is a record and nobody
# resumes it; bolting a resume line onto a spent file would be fabrication.
{ printf -- '# Some plan — DISCHARGED\n'; conforming p10c.md | tail -n +2 | grep -v 'READ and FOLLOW'; } > "$T/p10c.md"
grep -q 'does not carry its own resume one-liner' <<<"$(run "$T/p10c.md")" \
  && bad "P10 fired on a DISCHARGED plan — a spent record is not resumable and must not be a backlog item" \
  || ok "  and it exempts a banner-marked plan, so only live plans owe the sentence"

# --- P11 a live plan says to re-derive its resume block after the merge -----------
# THE MERGE IS THE MOMENT A HANDOFF GOES STALE, and no other event marks it. The block a
# session followed becomes a description of finished work, and a session that stops there
# hands the next one an instruction to redo it. Measured on this repo's own plan twice in
# one session: an action still said RUN THE TRIAGE SWEEP after that sweep had merged, and a
# corrected figure was fixed in the PROSE while the command beneath it kept printing the old
# number.
#
# THE SEED IS A DELETION OF THE INSTRUCTION, WHICH IS THE REAL OFFENDER SHAPE, and it is
# anchored on the sentence rather than on a numbered-list prefix DELIBERATELY. P2's seed
# strips `^[12]\. ` to prove a plan with nothing to follow fires; if this arm's subject were
# a numbered action, that one seed would remove both subjects and a single mutant would fail
# two assertions -- entangled arms, one of which is then vacuous. Each arm gets a subject the
# other cannot see.
conforming p11.md | grep -v 're-derive this plan' > "$T/p11.md"
grep -q 'never tells its executor to re-derive' <<<"$(run "$T/p11.md")" \
  && ok "P11 fires on a live plan that never says to re-derive after the merge" \
  || bad "P11 silent on a plan that cannot tell it has gone stale — the next session redoes merged work"

# THE SCOPING CONTROL, the same shape as P9b and P10c. A discharged plan is a record; nobody
# merges against it, so it owes no re-derivation.
{ printf -- '# Some plan — DISCHARGED\n'; conforming p11b.md | tail -n +2 | grep -v 're-derive this plan'; } > "$T/p11b.md"
grep -q 'never tells its executor to re-derive' <<<"$(run "$T/p11b.md")" \
  && bad "P11 fired on a DISCHARGED plan — a spent record is not resumed and owes no re-derivation" \
  || ok "  and it exempts a banner-marked plan, so only live plans owe the instruction"

# --- empty corpus is not a pass ---------------------------------------------------
# `for f in docs/plans/*.md` over an empty directory reads exactly like a clean run.
mkdir -p "$T/empty/docs/plans" "$T/empty/scripts"
# COPY UNDER THE CANONICAL BASENAME, never `cp "$V" dir/`. The line below invokes
# `scripts/validate-plan-shape.sh` by name, so driving this fixture with an
# alternately-named copy of the validator -- which is exactly what a mutation run does --
# left nothing at that path and the arm exited 127. A 127 scored as "the empty corpus did
# not exit 2", so a harness failure read as the defect this arm exists to catch.
cp "$V" "$T/empty/scripts/validate-plan-shape.sh"
( cd "$T/empty" && bash scripts/validate-plan-shape.sh >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] \
  && ok "an empty docs/plans/ exits 2, not 0 — no corpus is not the same as no findings" \
  || bad "an empty corpus exited $rc; a repo that lost its plans would report a clean run"

echo ""
if [ "$fails" -eq 0 ]; then echo "plan-shape: PASS"; exit 0; fi
echo "plan-shape: FAIL ($fails)"; exit 1
