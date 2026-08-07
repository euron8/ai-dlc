#!/usr/bin/env bash
# plan-shape — assert every arm of validate-plan-shape.sh can FAIL, and that a
# conforming plan trips none of them.
#
# A prose linter is the genre most likely to ship inert: its subject is text, so an arm
# whose regex never matches looks exactly like an arm with nothing to report, and the
# corpus (one plan) is far too small for a green run to mean anything on its own. So
# each arm gets a seeded defect that MUST fire and a conforming control that MUST NOT.
#
# The control is not decoration. Four of the six arms are absence checks — a validator
# that errored on every file would satisfy every positive assertion here and be useless.
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
conforming() {
  cat <<'MD'
# Some plan

## Start here

Working repo: `/some/repo`. Reference consumer: `/other/repo` — read it, never write it.

Ping the operator on any question or decision, and when this plan completes.

1. Do the first thing.
2. Do the second thing.

## Where things stand

Evidence: `scripts/validate-plan-shape.sh:1` is the subject of this fixture.

### R1 — the enabler — **SHIPPED as v0.1.0**
MD
}

run() { bash "$V" "$1" 2>&1; }

conforming > "$T/good.md"
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
conforming | grep -v '^Ping the operator' > "$T/p3b.md"
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
conforming | grep -v '^## Start here$' > "$T/p1.md"
grep -q "no '## Start here' section" <<<"$(run "$T/p1.md")" \
  && ok "P1 fires when the entry point is missing" \
  || bad "P1 silent on a plan with no '## Start here' — a resuming session acts on whatever it reads first"

# --- P2 ordered next action -------------------------------------------------------
conforming | grep -vE '^[12]\. ' > "$T/p2.md"
grep -q 'no numbered action list' <<<"$(run "$T/p2.md")" \
  && ok "P2 fires when there is nothing to follow" \
  || bad "P2 silent on a plan with no numbered action — 'FOLLOW this plan' has no referent"

# --- P3 read/write boundary (WARN, never an error) --------------------------------
conforming | sed 's/ — read it, never write it\.//' > "$T/p3.md"
o3="$(run "$T/p3.md")"
grep -q 'states no read/write boundary' <<<"$o3" \
  && ok "P3 warns when the boundary is unstated" \
  || bad "P3 silent on a plan that never says which tree must not be written"
grep -q '0 error(s)' <<<"$o3" \
  && ok "  and P3 is a WARNING, not a blocker" \
  || bad "P3 escalated to an error — a plan touching one tree only would then be unpushable"

# --- P4 citations resolve ---------------------------------------------------------
conforming | sed 's|scripts/validate-plan-shape\.sh:1|scripts/no-such-file.sh:1|' > "$T/p4a.md"
grep -q 'does not exist' <<<"$(run "$T/p4a.md")" \
  && ok "P4 fires on a citation whose file is gone" \
  || bad "P4 silent on a citation to a nonexistent file"

conforming | sed 's|scripts/validate-plan-shape\.sh:1|scripts/validate-plan-shape.sh:999999|' > "$T/p4b.md"
grep -q 'resolves to nothing' <<<"$(run "$T/p4b.md")" \
  && ok "  and on one whose line number is past EOF" \
  || bad "P4 checks existence but not bounds — a citation can point past the end and pass"

# --- P5 contradictory status ------------------------------------------------------
# THE DEFECT THIS VALIDATOR WAS WRITTEN FOR: a shipped release still described as work
# to do. A session told to FOLLOW the plan redoes it.
{ conforming; printf '\n| R1 | not started | something |\n'; } > "$T/p5.md"
grep -q 'BOTH shipped and not-started' <<<"$(run "$T/p5.md")" \
  && ok "P5 fires when one identifier is both shipped and not-started" \
  || bad "P5 silent on a contradiction — this is the exact defect the validator exists for"

# --- P6 one current status record -------------------------------------------------
{ conforming; printf '\n## Status\n\nA second record with no marker.\n'; } > "$T/p6.md"
grep -q 'status sections' <<<"$(run "$T/p6.md")" \
  && ok "P6 fires on two unmarked status records" \
  || bad "P6 silent on duplicate status sections — the reader believes whichever comes first"

# CONTROL for P6, and the one that keeps it honest: marking the second as superseded is
# the remedy the message prescribes, so it MUST silence the row. An arm that cannot be
# quieted by following its own advice teaches the operator to stop reading it.
{ conforming; printf '\n## Status\n\nSuperseded — see the Start here section above.\n'; } > "$T/p6b.md"
grep -q '0 error(s)' <<<"$(run "$T/p6b.md")" \
  && ok "  and a second record marked superseded is accepted" \
  || bad "P6 fires even on a correctly-marked superseded section — the remedy does not silence it"

# --- empty corpus is not a pass ---------------------------------------------------
# `for f in docs/plans/*.md` over an empty directory reads exactly like a clean run.
mkdir -p "$T/empty/docs/plans" "$T/empty/scripts"
cp "$V" "$T/empty/scripts/"
( cd "$T/empty" && bash scripts/validate-plan-shape.sh >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] \
  && ok "an empty docs/plans/ exits 2, not 0 — no corpus is not the same as no findings" \
  || bad "an empty corpus exited $rc; a repo that lost its plans would report a clean run"

echo ""
if [ "$fails" -eq 0 ]; then echo "plan-shape: PASS"; exit 0; fi
echo "plan-shape: FAIL ($fails)"; exit 1
