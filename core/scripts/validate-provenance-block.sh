#!/usr/bin/env bash
# validate-provenance-block.sh — the READER of SKILL_INVOCATION_PROVENANCE v1.
#
# Usage: ./scripts/ai-dlc/validate-provenance-block.sh <artifact-path> [--require-skill <skill-name>]
#
# THE SCHEMA IS NOT IN THIS FILE. It is in schemas/provenance-block.json, which this script
# LOADS: the envelope, the field list, the enums, the patterns, and the cross-field rules all
# come from there, and so does every example any agent is taught (rendered by
# sync-taught-schema.sh). Adding a field there reaches this parser and every doc at once.
#
# It used to be otherwise, and that is the whole reason this file looks like this. The block
# was described in FOUR places -- a regex here, a schema comment in this very header, an
# example in gate-validation.md, an example in team-roles/adversary.md -- with nothing
# comparing them. They diverged. The role file taught a bare ``` fence with no terminator;
# the adversary emitted exactly what it was shown; the regex here matched nothing; and this
# script printed "no provenance block required or present" and exited 0. Two full adversarial
# passes of the reference consumer's sprint 290 went unadjudicated and the gate called them
# clean, because an unparseable block scores exactly like a clean artifact.
#
# Exit codes:
#   0  -- every block present is well-formed, and any required block is present
#   1  -- missing block, MALFORMED block, malformed field, unknown skill, or a rule violation
#   2  -- usage error
#
# Forgeability: this is pattern-match validation, not cryptographic attestation. A motivated
# forger can paste a well-formed block without invoking anything. validate-retro-evidence.sh
# adds a transcript-file + byte-matched SHA citation for retro party-mode to narrow that
# surface. Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — hence JSON).

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
    echo "usage: ./scripts/ai-dlc/validate-provenance-block.sh <artifact-path> [--require-skill <skill-name>]" >&2
    exit 2
fi

if [[ ! -f "$ARTIFACT_PATH" ]]; then
    echo "ERROR: artifact not found: $ARTIFACT_PATH" >&2
    exit 1
fi

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts —
# here that put both the schema and the known-skills extension out of reach.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
    local d="$1"
    while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
        if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
            printf '%s\n' "$d"; return 0
        fi
        d="$(dirname "$d")"
    done
    return 1
}
PB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PB_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$PB_ROOT" ] || PB_ROOT="$(ai_dlc_resolve_root "$PB_SCRIPT_DIR" || true)"
[ -n "$PB_ROOT" ] || PB_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$PB_ROOT" ] || PB_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
PB_ROOT="${PB_ROOT:-/nonexistent}"
# --- end AI_DLC_ROOT --------------------------------------------------------

SCHEMA=""
for cand in \
    "$PB_ROOT/core/schemas/provenance-block.json" \
    "$PB_ROOT/.claude/schemas/provenance-block.json" \
    "$PB_SCRIPT_DIR/../schemas/provenance-block.json"; do
    [ -f "$cand" ] && { SCHEMA="$cand"; break; }
done

if [ -z "$SCHEMA" ]; then
    # FAIL CLOSED, LOUDLY. A reader that cannot find its schema must never fall back to a
    # built-in copy — a built-in copy is exactly the drift this design removed, and a check
    # that silently degrades to a stale schema reads exactly like a check that passed.
    echo "FAIL: schemas/provenance-block.json not found. The schema is the source of truth;" >&2
    echo "      this validator has no built-in copy and will not guess. Reinstall ai-dlc." >&2
    exit 1
fi

# Consumer-extension point for known_skills. The core list names the skills the DISTRIBUTION
# ships; a layered consumer with its OWN party-persona or sub-skill (whose real invocation emits a
# provenance block citing it) registers the extra name HERE — an ADDITIVE extensions/ file, per
# Rule 27 (consumers never edit core; they add a layer entry). Absent in the distribution and in a
# pre-layer consumer, so the core list stands alone there. Unioned into the enum below when present.
if [ -n "${AI_DLC_KNOWN_SKILLS_EXT+x}" ]; then
    # Explicitly set (even to empty): use it verbatim, no path search. Empty or nonexistent = none.
    KNOWN_SKILLS_EXT="$AI_DLC_KNOWN_SKILLS_EXT"
else
    KNOWN_SKILLS_EXT=""
    for cand in \
        "$PB_ROOT/.claude/skills/ai-dlc/extensions/known-skills.json" \
        "$PB_ROOT/skills/ai-dlc/extensions/known-skills.json" \
        "$PB_SCRIPT_DIR/../skills/ai-dlc/extensions/known-skills.json"; do
        [ -f "$cand" ] && { KNOWN_SKILLS_EXT="$cand"; break; }
    done
fi
# A nonexistent path is "no extension"; a present-but-malformed one fails closed in python.
[ -n "$KNOWN_SKILLS_EXT" ] && [ ! -f "$KNOWN_SKILLS_EXT" ] && KNOWN_SKILLS_EXT=""

# shellcheck source=/dev/null
[ -r "${PB_SCRIPT_DIR}/lib/meta-gate.sh" ] && . "${PB_SCRIPT_DIR}/lib/meta-gate.sh"

python3 - "$ARTIFACT_PATH" "$REQUIRE_SKILL" "$SCHEMA" "$KNOWN_SKILLS_EXT" <<'PYEOF'
import json
import re
import sys

artifact_path = sys.argv[1]
require_skill = sys.argv[2] or None
schema_path = sys.argv[3]
ext_path = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None

with open(schema_path, "r", encoding="utf-8") as fh:
    S = json.load(fh)

# Union the consumer known_skills extension (additive layer). Fail closed on a present-but-broken
# extension: a malformed layer file must not silently degrade to the core-only list, because then a
# legitimately-registered consumer skill would wrongly read as a forged/unknown one.
if ext_path:
    try:
        with open(ext_path, "r", encoding="utf-8") as fh:
            ext = json.load(fh)
    except (ValueError, OSError) as exc:
        print(
            f"FAIL: known_skills extension {ext_path} is present but not parseable JSON ({exc}). "
            f"It must be a JSON list of skill names, or an object with a 'known_skills' list. "
            f"Fix or remove it — a broken layer file must not be treated as empty.",
            file=sys.stderr,
        )
        sys.exit(1)
    extra = ext.get("known_skills") if isinstance(ext, dict) else ext
    if not isinstance(extra, list) or not all(isinstance(x, str) and x for x in extra):
        print(
            f"FAIL: known_skills extension {ext_path} must be a JSON list of non-empty strings, or "
            f"an object with a 'known_skills' list of them.",
            file=sys.stderr,
        )
        sys.exit(1)
    S["known_skills"] = list(dict.fromkeys(list(S["known_skills"]) + extra))

ENV = S["envelope"]
PATTERNS = S["patterns"]
FIELDS = {f["name"]: f for f in S["fields"]}
KNOWN_SKILLS = set(S["known_skills"])

BLOCK_RE = re.compile(
    re.escape(ENV["open"]) + r"\s*\n(.*?)\n\s*" + re.escape(ENV["close"]),
    re.DOTALL,
)
MARKER_RE = re.compile(re.escape(ENV["marker"]))

with open(artifact_path, "r", encoding="utf-8") as fh:
    content = fh.read()

blocks = BLOCK_RE.findall(content)
is_retro = bool(re.search(r"docs/retro/sprint-\d+\.md$", artifact_path))

# MALFORMED != ABSENT, and they must never share an exit code.
#
# This is the check that was not here. A marker the grep SEES and the parser CANNOT READ is
# a malformed block, not an absent one. Without this, a block in a ``` fence fell through to
# "no provenance block required or present", exit 0 — and every rung below (the enum, the
# solo rejection, the verdict rules) sat downstream of a parse that never happened.
if not blocks and MARKER_RE.search(content):
    print(
        f"FAIL: {artifact_path} carries a {ENV['marker']} marker that this validator CANNOT "
        f"PARSE. The block is MALFORMED, not absent.\n"
        f"      A provenance block MUST open with the literal '{ENV['open']}' and close with "
        f"the literal '{ENV['close']}'. A ``` code fence is not a provenance block: nothing "
        f"parses it, so every field inside it goes unadjudicated and the gate reports the "
        f"artifact as clean because it never read a word of it.\n"
        f"      FIX: re-wrap the existing block in those delimiters. Do not delete it and do "
        f"not restate its fields — the content is fine; the envelope is not.",
        file=sys.stderr,
    )
    sys.exit(1)

if not blocks:
    if is_retro:
        print(
            f"FAIL: {artifact_path} has no {ENV['marker']} block. "
            f"Retro docs MUST cite at least one bmad-party-mode invocation.",
            file=sys.stderr,
        )
        sys.exit(1)
    if require_skill:
        print(
            f"FAIL: {artifact_path} has no {ENV['marker']} block. "
            f"--require-skill {require_skill} was specified.",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"OK: no provenance block required or present in {artifact_path}.")
    sys.exit(0)


def parse_block(block_text):
    """Tokenise per schema['parser']: flat `key: value`; an INDENTED line continues the key
    above it (a folded value, or a YAML list). Unknown fields are recorded, not rejected."""
    fields = {}
    last_key = None
    for raw in block_text.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if re.match(r"^\s+", raw) and last_key is not None:
            fields[last_key] = f"{fields[last_key]} {stripped}".strip()
            continue
        m = re.match(r"^([a-z_]+):\s*(.*?)\s*$", raw)
        if not m:
            return None, (
                f"malformed line: {stripped!r} — a provenance block is flat `key: value` "
                f"lines. A continuation or a list item must be INDENTED under the key it "
                f"belongs to."
            )
        key, val = m.group(1), m.group(2)
        # Strip a trailing ' # comment', as YAML does (schema.parser.comments). The taught
        # examples carry their teaching in inline comments; a parser that did not strip them
        # made every faithfully-copied example unparseable — the enum saw the comment text as
        # part of the value. That was true for as long as the examples have existed, and
        # nothing noticed, because nothing had ever run a taught example through this parser.
        val = re.sub(r"\s+#.*$", "", val).strip()
        fields[key] = val
        last_key = key
    return fields, None


def check_value(idx, name, value, failures):
    """Enum and pattern checks, both taken from the schema."""
    spec = FIELDS.get(name)
    if spec is None:
        return  # unknown field: permitted and recorded (schema['parser']['unknown_fields'])

    # A declared sentinel is a sanctioned literal that bypasses the shape checks. The one
    # sentinel is tool_use_id: NOT_ACCESSIBLE, written per retro.md when the Skill/Agent tool's
    # id is not retrievable (common after a compact) — the honest alternative to inventing an
    # id, which would be a forged block. It is NOT a placeholder (those are `forbidden`, and
    # pretend to be a real id): the sentinel names its own absence. Schema-declared so the
    # allowance lives in the schema, not a per-field code branch.
    if spec.get("sentinel") is not None and value == spec["sentinel"]:
        return

    enum = spec.get("enum")
    if enum is None and spec.get("enum_ref"):
        enum = S[spec["enum_ref"]]
    if enum and value not in enum:
        failures.append(
            f"block #{idx}: {name} '{value}' is not one of {sorted(enum)}"
        )
        return

    pat_ref = spec.get("pattern_ref")
    if pat_ref and not re.match(PATTERNS[pat_ref], value):
        failures.append(
            f"block #{idx}: {name} '{value}' does not match the schema's {pat_ref} pattern"
        )
        return

    # Forbidden literals, from the schema. A value can satisfy the SHAPE (enum/pattern)
    # and still be one the schema names as never-legitimate: mode: solo (Rule 20), or a
    # tool_use_id placeholder literal (toolu_PLACEHOLDER) that passes the charset pattern
    # but cannot have come from a real Skill/Agent call — the forgeable-evidence-cell
    # class. ONE mechanism for every field that declares `forbidden`, so the rule lives in
    # the schema, not in a per-field code branch. Written `name: value` so a solo
    # rejection still reads `mode: solo` verbatim (Check 17's fixture greps for it).
    forbidden = spec.get("forbidden")
    if forbidden and value in forbidden:
        reason = spec.get("forbidden_reason")
        msg = f"block #{idx}: {name}: {value} is forbidden"
        if reason:
            msg += f" — {reason}"
        failures.append(msg)


failures = []
party_mode_blocks = []

for idx, raw_block in enumerate(blocks, start=1):
    fields, err = parse_block(raw_block)
    if err is not None:
        failures.append(f"block #{idx}: {err}")
        continue

    # --- required fields, straight from the schema ---
    for name, spec in FIELDS.items():
        if not spec.get("required"):
            continue
        if name not in fields:
            failures.append(f"block #{idx}: missing required field '{name}'")
        elif not fields[name]:
            # rules.required_non_empty — the parser accepts `key:` with the value on the
            # lines below, so "present" and "answered" are different questions.
            failures.append(f"block #{idx}: required field '{name}' is present but EMPTY")

    for name, value in fields.items():
        if value:
            check_value(idx, name, value, failures)

    # --- rules.no_solo (mode: solo) and forbidden placeholder literals are enforced by
    #     check_value above, which honours every field's schema `forbidden` list. The
    #     rejection is unconditional: check_value runs for every present, non-empty field,
    #     and mode is required — so a solo value cannot slip past it, with or without a
    #     skill field (Check 17's V8). ---

    # --- rules.verdict_requires_counts ---
    if fields.get("verdict"):
        for name, spec in FIELDS.items():
            if not spec.get("required_for_verdict"):
                continue
            if not fields.get(name):
                failures.append(
                    f"block #{idx}: verdict '{fields['verdict']}' is stamped without '{name}'. "
                    f"{S['rules']['verdict_requires_counts']['why']}"
                )

    # --- rules.counts_always ---
    # Keyed on membership in known_skills, NOT on the presence of a verdict. An
    # evaluation that records no residue cannot be scored, and an unscoreable
    # evaluation is indistinguishable from one that found nothing — which is how
    # 831 sub-skill invocations accumulated on the reference consumer with 16
    # carrying any counts. Unknown skills are left alone: this asserts a contract
    # on the evaluations the pipeline defines, not on every block an author writes.
    if fields.get("skill") in KNOWN_SKILLS:
        missing_counts = [
            name for name, spec in FIELDS.items()
            if spec.get("required_for_evaluation") and not fields.get(name)
        ]
        # ONE failure naming all of them. Three near-identical lines each repeating
        # the same rationale paragraph is the output shape verdict.sh exists to
        # stop; a validator should not need wrapping to be readable.
        if missing_counts:
            failures.append(
                f"block #{idx}: skill '{fields['skill']}' is missing "
                f"{', '.join(repr(n) for n in missing_counts)} (rules.counts_always). "
                f"Every known evaluation records its residue, verdict-bearing or not — "
                f"an evaluation that records nothing cannot be told apart from one that "
                f"found nothing. Emit the three counts; `verdict` stays optional, and "
                f"stamping one here would enrol this pass in a convergence cycle "
                f"(Check 24) it is not part of."
            )

    if fields.get("skill") == "bmad-party-mode":
        party_mode_blocks.append((idx, fields))
        if is_retro and not fields.get("transcript_path"):
            failures.append(
                f"block #{idx}: retro party-mode requires transcript_path "
                f"({FIELDS['transcript_path']['placeholder']})"
            )

if require_skill:
    cited = {f.get("skill") for _, f in [(i, parse_block(b)[0] or {}) for i, b in enumerate(blocks, 1)]}
    if require_skill not in cited:
        failures.append(
            f"--require-skill {require_skill} was specified, but no block cites it "
            f"(blocks cite: {sorted(s for s in cited if s)})"
        )
    # v0.58.0: the Rule 8 convergence cycle is ai-dlc-native. A pin on the retired bmad skill
    # can never be satisfied by a compliant pass, so it fails as a RETIRED PIN, not as a
    # missing block — the remedy is to repoint the pin, not to forge the provenance.
    if require_skill == "bmad-review-adversarial-general" and "ai-dlc-adversary-review" in cited:
        failures.append(
            f"--require-skill bmad-review-adversarial-general is a RETIRED PIN. This artifact "
            f"correctly cites ai-dlc-adversary-review (the native convergence review). Repoint "
            f"the pin — an override or a step file still names the retired skill."
        )

if is_retro and not party_mode_blocks:
    failures.append(
        f"{artifact_path} is a retro doc but cites no bmad-party-mode invocation."
    )

if failures:
    print(f"VALIDATE-PROVENANCE-BLOCK: FAIL ({artifact_path})", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)

print(
    f"VALIDATE-PROVENANCE-BLOCK: PASS ({artifact_path}, {len(blocks)} block(s), "
    f"{len(party_mode_blocks)} party-mode)"
)
sys.exit(0)
PYEOF
