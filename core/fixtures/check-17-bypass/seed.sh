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
#
# V1-V4 must FAIL validate-provenance-block.sh.
# V5 must PASS validate-provenance-block.sh and FAIL validate-retro-evidence.sh.
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
cat > "$OUT/docs/retro/sprint-905.md" <<EOF
# Sprint 905 Retrospective

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-party-mode
invoked_at: ${TS}
tool_use_id: ${TID}
mode: subagent
lead_role: retro.md
transcript_path: ${TRANSCRIPT}@deadbee
SKILL_INVOCATION_PROVENANCE_END -->

Every field is well-formed and this block is still a forgery: SHA 'deadbee' does not
name the blob actually at ${TRANSCRIPT} on HEAD. Only
validate-retro-evidence.sh, which resolves the SHA against git, can see that.
EOF

echo "$OUT"
