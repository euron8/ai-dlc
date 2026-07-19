#!/usr/bin/env bash
# Seed the check-17-bypass fixture.
#
# THIS FIXTURE WRITES FILES. It did not always: for several releases seed.sh was
# two `echo` statements describing, in English, five variants that were never
# created. H2 "re-drove" it at every gate and adjudicated the prose. A meta-check
# that reads a description of a test instead of running one cannot fail -- which is
# why it never did. Before shrinking this back to echoes, read the H2
# minimum-mechanism note in gate-validation.md.
#
# Emits five provenance-block variants into $OUT (default: a fresh temp dir) and
# prints the dir on stdout. run.sh drives the real validators against them and
# asserts the pass/fail matrix.
#
#   V1  retro doc, NO provenance block at all
#   V2  block present, tool_use_id stripped
#   V3  block present, skill field names an unknown skill
#   V4  retro party-mode block, transcript_path missing the @<sha> suffix
#   V5  retro party-mode block, WELL-FORMED, citing a transcript SHA that does
#       not byte-match the file on HEAD
#   V6  adversarial pass artifact, skill: ai-dlc-adversary-review, mode: solo
#       -- the lead roleplayed the convergence review in its own context (v0.58.0)
#   V7  the same block with mode: subagent -- the honest native review; must PASS
#
# V1-V4, V6 must FAIL validate-provenance-block.sh.
# V5, V7 must PASS validate-provenance-block.sh. V5 must then FAIL validate-retro-evidence.sh.
#
# V6/V7 EXIST AS A PAIR, AND V6'S ASSERTION IS ON THE MESSAGE, NOT THE EXIT CODE.
# v0.58.0 made the Rule 8 convergence cycle native (no Skill) and added
# `ai-dlc-adversary-review` to KNOWN_SKILLS. The naive fixture -- "a solo native block
# must exit non-zero" -- PASSES WHETHER OR NOT THE CHANGE IS CORRECT: if the name is
# absent from the enum it fails on "unknown skill", and if it is present it fails on
# the Rule 20 solo rung. Same exit code, opposite meanings, and only one of them is
# Check 17 doing its job. So run.sh asserts V6 fails ON THE SOLO MESSAGE, and V7
# asserts the honest block is ACCEPTED -- together they pin both halves.
#
# V5 is the forgery floor: the variant that proves the lightweight pattern-match
# script cannot be the only gate (see its own header: "a motivated forger can paste
# a well-formed block without invoking the Skill"). If V5 fails the lightweight
# script, the heavyweight byte-match it exists to reach is never executed and the
# floor is untested.

set -euo pipefail

OUT="${1:-${OUT:-$(mktemp -d)}}"
mkdir -p "$OUT/docs/retro"

TS="2026-07-11T12:00:00Z"
TID="toolu_01ABCDEFGHIJKLMNOPQRSTUV"
TRANSCRIPT="_bmad-output/party-mode-transcripts/sprint-999-retro.md"

# --- V1: no provenance block at all ------------------------------------------
cat > "$OUT/docs/retro/sprint-901.md" <<'EOF'
# Sprint 901 Retrospective

Party mode was convened and the personas agreed the sprint went well.

There is no SKILL_INVOCATION_PROVENANCE block anywhere in this document.
"The findings are real" is not a substitute for the block -- Rule 20,
"Forbidden failure mode".
EOF

# --- V2: tool_use_id stripped -------------------------------------------------
cat > "$OUT/docs/retro/sprint-902.md" <<EOF
# Sprint 902 Retrospective

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-party-mode
invoked_at: ${TS}
mode: subagent
lead_role: retro.md
transcript_path: ${TRANSCRIPT}@abc1234
SKILL_INVOCATION_PROVENANCE_END -->

The tool_use_id is absent: nothing ties this block to a real Skill tool response.
EOF

# --- V3: unknown skill --------------------------------------------------------
cat > "$OUT/docs/retro/sprint-903.md" <<EOF
# Sprint 903 Retrospective

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-vibes-check
invoked_at: ${TS}
tool_use_id: ${TID}
mode: subagent
lead_role: retro.md
transcript_path: ${TRANSCRIPT}@abc1234
SKILL_INVOCATION_PROVENANCE_END -->

'bmad-vibes-check' is not one of the four tracked validation sub-skills.
EOF

# --- V4: transcript_path missing the @<sha> suffix ----------------------------
cat > "$OUT/docs/retro/sprint-904.md" <<EOF
# Sprint 904 Retrospective

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-party-mode
invoked_at: ${TS}
tool_use_id: ${TID}
mode: subagent
lead_role: retro.md
transcript_path: ${TRANSCRIPT}
SKILL_INVOCATION_PROVENANCE_END -->

Path-only citation. Without @<sha> the SHA sub-check is not runnable at all, so the
transcript could be rewritten after the fact and this citation would still "match".
EOF

# --- V5: well-formed, but the cited SHA does not name the blob -----------------
#
# NOTE THE `mode: subagent`. This variant MUST pass validate-provenance-block.sh.
# It previously carried `mode: solo`, which trips that script's Rule 20 solo
# assertion -- so V5 failed the LIGHTWEIGHT validator and the heavyweight byte-match
# it exists to reach was never executed. The README claimed "V5 passes that script".
# It did not. A fixture that short-circuits before the property it is testing is
# worse than no fixture: it reports PASS.
#
# NOTE THE findings_* COUNTS, for the same reason, one rung later. rules.counts_always
# requires them of every known evaluation, so a countless party-mode block now fails
# the lightweight validator -- and V5 would again never reach the byte-match. The
# counts are deliberately NON-ZERO: a forgery that reports having found something is
# the interesting one, and it must still be caught by the SHA rung and not by looking
# suspicious. V5 tests the forgery floor, never the counts rule; check-17-counts owns
# that.
cat > "$OUT/docs/retro/sprint-905.md" <<EOF
# Sprint 905 Retrospective

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-party-mode
invoked_at: ${TS}
tool_use_id: ${TID}
mode: subagent
lead_role: retro.md
transcript_path: ${TRANSCRIPT}@deadbee
findings_critical: 0
findings_major: 2
findings_minor: 4
SKILL_INVOCATION_PROVENANCE_END -->

Every field is well-formed and this block is still a forgery: SHA 'deadbee' does not
name the blob actually at ${TRANSCRIPT} on HEAD. Only
validate-retro-evidence.sh, which resolves the SHA against git, can see that.
EOF

# --- V6/V7: the native convergence review (v0.58.0) ---------------------------
#
# These are planning pass artifacts, NOT retro docs -- is_retro is false, so no
# transcript_path is owed and the retro arms of the validator do not apply.
mkdir -p "$OUT/_bmad-output/planning-artifacts"

# V6: the lead ran the convergence review INLINE and said so. This is the exact
# failure Rule 20 exists to catch, expressed in the new vocabulary. It must be
# rejected BY THE SOLO RUNG -- see the header note on why the exit code alone is
# not an assertion.
cat > "$OUT/_bmad-output/planning-artifacts/s999-brief-adversarial-p2.md" <<EOF
# S999 brief — adversarial pass 2 (V6: solo)

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: ${TS}
tool_use_id: ${TID}
mode: solo
lead_role: discovery.md
findings_critical: 0
findings_major: 0
findings_minor: 1
verdict: EXIT_CONDITION_MET
SKILL_INVOCATION_PROVENANCE_END -->

No adversary was spawned. The lead reviewed the artifact its own context authored and
stamped a clean verdict on it. Every field is well-formed; \`mode: solo\` is the whole
violation, and it must be caught as one.
EOF

# V7: the honest native review -- a real adversary subagent, no Skill invoked. This
# is what the Rule 8 cycle now emits on every pass, and it MUST be accepted. If
# ai-dlc-adversary-review is not in KNOWN_SKILLS, this fails on the enum and the
# whole convergence cycle is un-gateable.
cat > "$OUT/_bmad-output/planning-artifacts/s999-brief-adversarial-p3.md" <<EOF
# S999 brief — adversarial pass 3 (V7: the honest native review)

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: ${TS}
tool_use_id: ${TID}
mode: subagent
lead_role: discovery.md
findings_critical: 0
findings_major: 0
findings_minor: 1
verdict: EXIT_CONDITION_MET
SKILL_INVOCATION_PROVENANCE_END -->

A real \`adversary\` teammate, dispatched via the Agent tool, running the native method
in team-roles/adversary.md. No Skill was invoked and none is claimed. tool_use_id is
the Agent dispatch's. This block is the shape every convergence pass now carries.
EOF

# V8: mode: solo with NO skill field at all.
#
# This variant guards the decoupling, and it is the ONLY thing that can. The Rule 20
# solo rejection used to read `if fields.get("skill") in KNOWN_SKILLS and mode == solo`.
# That guard was vacuous -- an unknown skill already fails the enum -- so it looked free.
# What it actually did was make the solo rung UNREACHABLE for any block whose `skill:`
# fell outside the set, including a block with no `skill:` at all. And "drop the skill
# field, it names no skill" is the obvious way to model a role dispatch: v0.58.0's own
# planning prompt proposed exactly that.
#
# Under the old gated code this block fails on the missing REQUIRED field and the solo
# rung never evaluates. Under the decoupled code it fails on BOTH. Same exit status --
# so, again, run.sh asserts the MESSAGE names solo.
cat > "$OUT/_bmad-output/planning-artifacts/s999-brief-adversarial-p4.md" <<EOF
# S999 brief — adversarial pass 4 (V8: solo, no skill field)

<!-- SKILL_INVOCATION_PROVENANCE v1
invoked_at: ${TS}
tool_use_id: ${TID}
mode: solo
lead_role: discovery.md
findings_critical: 0
findings_major: 0
findings_minor: 0
verdict: EXIT_CONDITION_MET
SKILL_INVOCATION_PROVENANCE_END -->

Solo, and carrying no \`skill:\` to be recognised by. \`mode: solo\` must be rejected on
its own terms, not because some other field happened to be in an allowlist.
EOF

# V9: a v0.58.0 story, driven with a consumer's RETIRED --require-skill pin.
#
# The migration mechanism. Stories are produced by a CONVERGENCE cycle, so they now cite
# ai-dlc-adversary-review. A consumer that pinned bmad-review-adversarial-general in a
# pre-submission override breaks here, mid-sprint, on the first story -- and nothing else
# can see it coming: the reconcile finds the anchors unbroken, and a consumer check that
# asserts only "the --require-skill flag is present" is blind to WHICH skill it names.
# ai-dlc-update/SKILL.md: "a migration note in a CHANGELOG is how it never gets done."
# So the failure itself has to carry the repair. run.sh asserts it says RETIRED PIN.
cat > "$OUT/_bmad-output/planning-artifacts/s999-story-1.md" <<EOF
# S999 Story 1 (V9: reviewed natively, pinned by a consumer to the old bmad name)

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: ${TS}
tool_use_id: ${TID}
mode: subagent
lead_role: stories-test-strategy.md
findings_critical: 0
findings_major: 0
findings_minor: 1
verdict: EXIT_CONDITION_MET
SKILL_INVOCATION_PROVENANCE_END -->

A well-formed, honestly-reviewed story. The ONLY thing wrong is the caller's pin.
EOF

echo "$OUT"
