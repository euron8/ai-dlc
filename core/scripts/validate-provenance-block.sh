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
#   skill: <bmad-party-mode|bmad-advanced-elicitation|bmad-review-adversarial-general|bmad-validate-prd>
#   invoked_at: <ISO 8601 UTC timestamp>
#   tool_use_id: <toolu_... from Skill tool response>
#   mode: <solo|subagent>
#   lead_role: <step-file-name>
#   transcript_path: <path@sha>   # required when artifact is docs/retro/sprint-*.md
#   SKILL_INVOCATION_PROVENANCE_END -->
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

    # Rule 20: ALL validation sub-skills must run in real independent subagents.
    # mode: solo (lead roleplayed the validation in its own context) is forbidden
    # for every tracked skill, not only party-mode.
    if fields.get("skill") in KNOWN_SKILLS and fields.get("mode") == "solo":
        failures.append(
            f"block #{idx}: skill '{fields['skill']}' emitted mode: solo — Rule 20 "
            f"requires mode: subagent (dispatch the evaluation to a real subagent; "
            f"single-voice sub-skills go to a Rule-19-bound teammate). Solo defeats "
            f"independent evaluation."
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
    match = any(
        fields.get("skill") == require_skill
        for raw in blocks
        for fields, _ in [parse_block(raw)]
        if fields is not None
    )
    if not match:
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
