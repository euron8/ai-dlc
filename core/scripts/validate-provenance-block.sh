#!/usr/bin/env bash
# validate-provenance-block.sh
#
# Usage: ./scripts/validate-provenance-block.sh <artifact-path> [--require-skill <skill-name>]
# Example: ./scripts/validate-provenance-block.sh docs/retro/sprint-156.md
#          ./scripts/validate-provenance-block.sh _bmad-output/planning-artifacts/prd.md --require-skill bmad-validate-prd
#
# Parses SKILL_INVOCATION_PROVENANCE v1 blocks in the given artifact and
# asserts required fields are present and well-formed. Complementary to
# validate-retro-evidence.sh (heavyweight, retro-specific transcript +
# SHA enforcement). This script is lightweight and artifact-agnostic —
# it enforces the provenance block exists regardless of whether a
# transcript file exists.
#
# Schema (see SKILL.md Rule 3):
#   <!-- SKILL_INVOCATION_PROVENANCE v1
#   skill: <bmad-party-mode|bmad-advanced-elicitation|bmad-review-adversarial-general|bmad-validate-prd|ai-dlc-adversary-review>
#   invoked_at: <ISO 8601 UTC timestamp>
#   tool_use_id: <toolu_... from the Skill tool response -- or, for ai-dlc-adversary-review,
#                 from the Agent dispatch that spawned the adversary. Both tools return one.>
#   mode: <solo|subagent>
#   lead_role: <step-file-name>
#   transcript_path: <path@sha>   # required when artifact is docs/retro/sprint-*.md
#   SKILL_INVOCATION_PROVENANCE_END -->
#
# `ai-dlc-adversary-review` is the Rule 8 CONVERGENCE review: no Skill runs, the
# `adversary` role runs the native method in team-roles/adversary.md. It is tracked
# here for exactly the reason the four sub-skills are -- the block is the only evidence
# the evaluation was independent of the context that authored the artifact.
#
# Retro docs at docs/retro/sprint-*.md MUST contain at least one block
# with skill=bmad-party-mode. Other artifacts: --require-skill flag
# specifies which skill must be cited (for PRDs, architecture docs,
# stories).
#
# Exit codes:
#   0  -- all required blocks present and well-formed
#   1  -- missing block, malformed field, or unknown skill
#   2  -- usage error
#
# Forgeability: this is pattern-match validation, not cryptographic
# attestation. A motivated forger can paste a well-formed block
# without invoking the Skill. validate-retro-evidence.sh adds a
# transcript-file + byte-matched SHA citation for retro party-mode
# to narrow that surface.
#
# Part of the skill-invocation hardening PR (post-Sprint-155 close).
# Compatible with bash 3.2+ and Python 3 (standard on macOS).

set -u

ARTIFACT_PATH="${1:-}"
REQUIRE_SKILL=""

shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --require-skill)
            REQUIRE_SKILL="$2"
            shift 2
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$ARTIFACT_PATH" ]]; then
    echo "usage: ./scripts/validate-provenance-block.sh <artifact-path> [--require-skill <skill-name>]" >&2
    exit 2
fi

if [[ ! -f "$ARTIFACT_PATH" ]]; then
    echo "ERROR: artifact not found: $ARTIFACT_PATH" >&2
    exit 1
fi

python3 - "$ARTIFACT_PATH" "$REQUIRE_SKILL" <<'PYEOF'
import re
import sys

artifact_path = sys.argv[1]
require_skill = sys.argv[2] or None

KNOWN_SKILLS = {
    "bmad-party-mode",
    "bmad-advanced-elicitation",
    "bmad-review-adversarial-general",
    "bmad-validate-prd",
    # v0.58.0. The Rule 8 CONVERGENCE cycle no longer invokes a Skill: it dispatches the
    # `adversary` role, which runs the native method in team-roles/adversary.md. The block
    # it emits still IS a provenance block -- the tool_use_id is the Agent dispatch's -- so
    # it names the evaluation that ran, not a Skill that did not. bmad stays in the enum:
    # the ONE-SHOT reviews still invoke it.
    "ai-dlc-adversary-review",
}

BLOCK_RE = re.compile(
    r"<!--\s*SKILL_INVOCATION_PROVENANCE\s+v1\s*\n(.*?)\n\s*SKILL_INVOCATION_PROVENANCE_END\s*-->",
    re.DOTALL,
)

ISO_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(\.\d+)?(Z|[+-]\d{2}:?\d{2})$"
)

TOOL_USE_ID_RE = re.compile(r"^toolu_[A-Za-z0-9_-]{6,}$")

TRANSCRIPT_CITATION_RE = re.compile(
    r"^[^\s@]+@[a-f0-9]{7,40}$"
)

with open(artifact_path, "r", encoding="utf-8") as fh:
    content = fh.read()

blocks = BLOCK_RE.findall(content)

# For retro docs, a block is mandatory; for other artifacts it's only
# mandatory when --require-skill is set.
is_retro = bool(re.search(r"docs/retro/sprint-\d+\.md$", artifact_path))

if not blocks:
    if is_retro:
        print(
            f"FAIL: {artifact_path} has no SKILL_INVOCATION_PROVENANCE v1 block. "
            f"Retro docs MUST cite at least one bmad-party-mode invocation.",
            file=sys.stderr,
        )
        sys.exit(1)
    if require_skill:
        print(
            f"FAIL: {artifact_path} has no SKILL_INVOCATION_PROVENANCE v1 block. "
            f"--require-skill {require_skill} was specified.",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"OK: no provenance block required or present in {artifact_path}.")
    sys.exit(0)


def parse_block(block_text):
    fields = {}
    for line in block_text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([a-z_]+):\s*(.+?)\s*$", line)
        if not m:
            return None, f"malformed line: {line!r}"
        key, val = m.group(1), m.group(2)
        fields[key] = val
    return fields, None


failures = []
party_mode_blocks = []

for idx, raw_block in enumerate(blocks, start=1):
    fields, err = parse_block(raw_block)
    if err is not None:
        failures.append(f"block #{idx}: {err}")
        continue

    required = ["skill", "invoked_at", "tool_use_id", "mode", "lead_role"]
    for r in required:
        if r not in fields:
            failures.append(f"block #{idx}: missing required field '{r}'")

    if "skill" in fields and fields["skill"] not in KNOWN_SKILLS:
        failures.append(
            f"block #{idx}: skill '{fields['skill']}' is not in the known set "
            f"{sorted(KNOWN_SKILLS)}"
        )

    if "invoked_at" in fields and not ISO_RE.match(fields["invoked_at"]):
        failures.append(
            f"block #{idx}: invoked_at '{fields['invoked_at']}' is not a valid "
            f"ISO 8601 UTC timestamp"
        )

    if "tool_use_id" in fields and not TOOL_USE_ID_RE.match(fields["tool_use_id"]):
        failures.append(
            f"block #{idx}: tool_use_id '{fields['tool_use_id']}' does not match "
            f"the toolu_<id> format emitted by the Skill tool"
        )

    if "mode" in fields and fields["mode"] not in ("solo", "subagent"):
        failures.append(
            f"block #{idx}: mode must be 'solo' or 'subagent' (got '{fields['mode']}')"
        )

    # Rule 20: ALL validation evaluations must run in real independent subagents.
    # mode: solo (lead roleplayed the validation in its own context) is forbidden
    # for every tracked evaluation, not only party-mode.
    #
    # THIS ASSERTION USED TO BE GATED ON `fields.get("skill") in KNOWN_SKILLS`, AND THAT
    # GATE WAS A LOADED GUN. It was vacuous -- an unknown skill already fails the enum
    # above -- so it changed no outcome and looked harmless. What it actually did was
    # couple the ONLY teeth Check 17 has to the enum's membership: the moment anyone
    # added a provenance-emitting evaluation without adding its name, or made `skill:`
    # optional, `fields.get("skill")` fell out of the set and the solo rejection SILENTLY
    # STOPPED FIRING -- an adversary roleplayed inline in the lead would emit `mode: solo`
    # and pass. v0.58.0 nearly shipped exactly that: the tempting way to express a role
    # dispatch is "skill: names no skill here, drop the field."
    # Unconditional now. mode: solo is forbidden, full stop, on any block that exists.
    # Fixture: check-17-bypass V8 (solo with NO skill field) is its only witness.
    if fields.get("mode") == "solo":
        failures.append(
            f"block #{idx}: skill '{fields.get('skill', '<absent>')}' emitted mode: solo — "
            f"Rule 20 requires mode: subagent (dispatch the evaluation to a real subagent; "
            f"single-voice sub-skills go to a Rule-19-bound teammate; the convergence review "
            f"goes to the `adversary` role). Solo defeats independent evaluation."
        )

    if fields.get("skill") == "bmad-party-mode":
        party_mode_blocks.append((idx, fields))
        if is_retro:
            tp = fields.get("transcript_path", "")
            if not tp:
                failures.append(
                    f"block #{idx}: retro party-mode requires transcript_path "
                    f"(expected _bmad-output/party-mode-transcripts/sprint-<N>-retro.md@<sha>)"
                )
            elif not TRANSCRIPT_CITATION_RE.match(tp):
                failures.append(
                    f"block #{idx}: transcript_path '{tp}' must be in path@<sha> format "
                    f"(7-40 hex chars after @)"
                )

if require_skill:
    cited = {
        fields.get("skill")
        for raw in blocks
        for fields, _ in [parse_block(raw)]
        if fields is not None
    }
    if require_skill not in cited:
        # THE RETIRED PIN (v0.58.0). The convergence cycle used to invoke
        # bmad-review-adversarial-general and now dispatches the `adversary` role, so the
        # artifacts it produces -- stories, above all -- cite ai-dlc-adversary-review. A
        # consumer that pinned the old name in a pre-submission override (dev / qa /
        # code-reviewer are the usual sites) breaks HERE, mid-sprint, on the first story.
        #
        # A CHANGELOG note is not a mechanism -- ai-dlc-update/SKILL.md says so in as many
        # words: "a migration note in a CHANGELOG is how it never gets done." Nothing else
        # can catch this: the reconcile sees unbroken anchors, and a consumer check that
        # asserts only "the --require-skill flag is present" is blind to WHICH skill it
        # names. So the one place that CAN see it -- the failure itself -- says what to do.
        if (require_skill == "bmad-review-adversarial-general"
                and "ai-dlc-adversary-review" in cited):
            failures.append(
                f"--require-skill bmad-review-adversarial-general is a RETIRED PIN. This "
                f"artifact was reviewed by the ai-dlc-native convergence cycle and cites "
                f"'ai-dlc-adversary-review'. As of v0.58.0 the Rule 8 cycle dispatches the "
                f"`adversary` role and invokes no skill; bmad is kept for ONE-SHOT reviews "
                f"only. FIX: repoint this call site to "
                f"`--require-skill ai-dlc-adversary-review`. (If you are a consumer, the "
                f"site is most likely a dev/qa/code-reviewer pre-submission override.)"
            )
        else:
            failures.append(
                f"--require-skill {require_skill} specified but no block cites that skill"
            )

if is_retro and not party_mode_blocks:
    failures.append(
        f"{artifact_path} has SKILL_INVOCATION_PROVENANCE block(s) but none "
        f"cite bmad-party-mode (required for retro docs)"
    )

if failures:
    print(f"VALIDATE-PROVENANCE-BLOCK: FAIL ({artifact_path})", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)

print(
    f"VALIDATE-PROVENANCE-BLOCK: PASS ({artifact_path}, "
    f"{len(blocks)} block(s), {len(party_mode_blocks)} party-mode)"
)
sys.exit(0)
PYEOF
