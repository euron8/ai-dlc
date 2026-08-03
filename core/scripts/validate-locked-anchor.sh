#!/usr/bin/env bash
# validate-locked-anchor.sh
#
# Usage: ./scripts/ai-dlc/validate-locked-anchor.sh <story-file> [--sor <path-or-basename>]
# Example: ./scripts/ai-dlc/validate-locked-anchor.sh _bmad-output/planning-artifacts/stories/s288-p1.md
#          ./scripts/ai-dlc/validate-locked-anchor.sh <story> --sor docs/requirements-of-record.md
#
# Gate-validation Check 3b enforcer. Complements the LLM-adjudicated Check 3
# ("Requirement anchor integrity"), which does INTRA-artifact drift detection
# (a LOCKED block vs. its own body). Check 3 never compares a story's LOCKED
# block against the PARENT source-of-record, so a story whose block AND body
# both carry the same lossy summary passes Check 3 while still being a
# mis-anchored, summarized propagation. This script closes that hole
# deterministically.
#
# It fires ONLY on a LOCKED_REQUIREMENTS block that makes a FULL-TEXT CLAIM via
# a `full_text_source:` line. Honest cite-by-reference (`requires_context:`) is
# a load pointer, not a full-text claim, and is never byte-matched — so honest
# citation cannot fail this check.
#
# Block schema (discovery.md §4a / stories-test-strategy.md §2a):
#   <!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
#   <!-- Source: <user input | carry-over item #N | escalation spec path> -->
#   full_text_source: <artifact>:<anchor>     # optional; a verbatim-text claim
#   requires_context: <artifact>#<anchor>     # optional; a load pointer only
#   - <verbatim requirement 1>
#   - <verbatim requirement 2>
#   <!-- END LOCKED_REQUIREMENTS -->
#
# For each `full_text_source: <artifact>:<anchor>` in a block, three checks:
#   (a) Source-of-record — the artifact must be the byte-verbatim source of
#       record (default basename `product-brief.md`, overridable via --sor).
#       A citation resolving to any other artifact, or to one that self-declares
#       `locked_requirements_fidelity: index` / a "condensed index" provenance,
#       FAILS. Catches "cite prd.md for full text" when prd.md is an index.
#   (b) Anchor existence — the <anchor> token must appear in the cited artifact.
#   (c) Byte-verbatim — every requirement bullet in the block must be present in
#       the cited artifact after whitespace collapse (a summarized/≤N-char
#       restatement will not match). Catches tooling-threshold-driven
#       summarization; the motive is unprovable from the file, but the lossy
#       RESULT is deterministic, and lossy propagation is independently
#       forbidden by Rule 13.
#
# NOTE — category error this guards against: context/tool thresholds (e.g. the
# ctx INTENT_SEARCH_THRESHOLD) gate what re-enters the conversation on an
# intent-bearing tool call; they never gate what is written to a file. Never
# shape durable artifact content to satisfy a tooling constraint.
#
# Exit codes:
#   0  -- no full_text_source claims, or all claims resolve verbatim to the SoR
#   1  -- a full_text_source cites a non-SoR / index artifact, a dangling
#         anchor, or a bullet not byte-present at the SoR
#   2  -- usage error
#
# Compatible with bash 3.2+ and Python 3 (standard on macOS).

set -u

STORY_PATH="${1:-}"
SOR_OVERRIDE=""

shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sor)
            SOR_OVERRIDE="${2:-}"
            shift 2
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$STORY_PATH" ]]; then
    echo "usage: ./scripts/ai-dlc/validate-locked-anchor.sh <story-file> [--sor <path>]" >&2
    exit 2
fi

if [[ ! -f "$STORY_PATH" ]]; then
    echo "ERROR: story file not found: $STORY_PATH" >&2
    exit 1
fi

python3 - "$STORY_PATH" "$SOR_OVERRIDE" <<'PYEOF'
import os
import re
import sys

story_path = sys.argv[1]
sor_override = sys.argv[2] or None

# Default source-of-record basename: the artifact where discovery.md §4a
# extracts the byte-verbatim LOCKED_REQUIREMENTS block by construction.
DEFAULT_SOR_BASENAME = "product-brief.md"
sor_basename = os.path.basename(sor_override) if sor_override else DEFAULT_SOR_BASENAME

# THE SENTINEL HAS SIX SPELLINGS IN THE FIELD AND THIS USED TO RECOGNISE ONE.
#
# `steps/discovery.md` templates `<!-- END LOCKED_REQUIREMENTS -->` and assumes ONE block
# "at the top of the artifact". Real briefs accumulate one block per sprint, so consumers
# invented per-block discriminators to tell them apart — a need the template never met.
# Measured across a reference consumer's live brief and its history file (198 openers):
#
#     <!-- END LOCKED_REQUIREMENTS -->                168     core's form
#     <!-- END S<N> LOCKED requirements -->            15
#     <!-- END LOCKED_REQUIREMENTS S<N> … -->           8
#     <!-- END S<N> LOCKED_REQUIREMENTS -->             5
#     <!-- LOCKED_REQUIREMENTS_END -->                  1
#     <!-- LOCKED_REQUIREMENTS_BEGIN -->                1     (opener variant)
#
# WHY THAT WAS NOT COSMETIC. A block whose closer this could not see extracted as NOTHING,
# and `blocks == []` fell straight through the per-block loop to the PASS line with
# `claims_checked = 0`. Measured with a same-run control: one story file, one FABRICATED
# requirement, two closer spellings —
#
#     <!-- END S1 LOCKED requirements -->   PASS (0 block(s), 0 claim(s) verified)   exit 0
#     <!-- END LOCKED_REQUIREMENTS -->      FAIL — not byte-present at full_text_source
#
# One word in a comment silently disarmed a `hard_block: true` check. And because the
# match is non-greedy across the whole file, an unrecognised closer also let a block
# SWALLOW everything up to the next closer it did recognise: 4 such blocks in the
# reference history, the largest 151 KB spanning dozens of real ones, every bullet in it
# then attributed to a single block.
#
# So the grammar admits every measured form, and the guard below makes a zero-block
# extraction over a file that plainly carries sentinels impossible to report as a pass.
# EXTRACTION IS LINE-ORIENTED, NOT A SPAN REGEX, AND THAT IS A BUG FIX NOT A STYLE
# CHOICE. A span regex has to say "anything up to the closer", and every spelling of
# "anything" is wrong here: `.` with DOTALL crosses block boundaries, and `[^>]` — the
# obvious repair — still crosses NEWLINES, so `<!-- LOCKED_REQUIREMENTS` followed by
# eight content lines and `END LOCKED_REQUIREMENTS -->` matched as ONE OPENER and left
# no closer behind it. Matching an opener LINE and then scanning forward for a closer
# LINE cannot express that mistake.
OPEN_RE = re.compile(
    r"^<!--[ \t]*LOCKED_REQUIREMENTS(?:_BEGIN)?\b[^\n]*$")
CLOSE_RE = re.compile(
    r"^(?:<!--[ \t]*)?(?:END[ \t]+[^\n]*LOCKED[^\n]*|LOCKED_REQUIREMENTS_END\b[^\n]*)-->[ \t]*$")


def extract_blocks(text):
    """Yield (body, opener_lineno) for each delimited LOCKED_REQUIREMENTS block.

    Also returns the openers that never found a closer, so a block this cannot parse
    is reported rather than silently contributing nothing."""
    lines = text.splitlines()
    out, dangling, i = [], [], 0
    while i < len(lines):
        if OPEN_RE.match(lines[i]):
            j = i + 1
            while j < len(lines) and not CLOSE_RE.match(lines[j]):
                # A second opener before any closer means the first was never closed.
                if OPEN_RE.match(lines[j]):
                    break
                j += 1
            if j < len(lines) and CLOSE_RE.match(lines[j]):
                out.append("\n".join(lines[i + 1:j]))
                i = j + 1
                continue
            dangling.append(i + 1)
        i += 1
    return out, dangling
FULL_TEXT_RE = re.compile(r"^\s*full_text_source:\s*(\S+)\s*$")
REQUIRES_CTX_RE = re.compile(r"^\s*requires_context:\s*\S")
BULLET_RE = re.compile(r"^\s*[-*]\s+(.*\S)\s*$")
# An artifact that self-declares it is NOT the verbatim record.
INDEX_MARKER_RE = re.compile(
    r"locked_requirements_fidelity:\s*index|condensed index|INDEXING, not weakening",
    re.IGNORECASE,
)


def collapse_ws(s):
    return re.sub(r"\s+", " ", s).strip()


def resolve_artifact(cited, story_path):
    """Resolve a cited artifact path/basename to an existing file."""
    story_dir = os.path.dirname(os.path.abspath(story_path))
    candidates = []
    if os.path.isabs(cited):
        candidates.append(cited)
    else:
        candidates.append(os.path.join(os.getcwd(), cited))
        candidates.append(os.path.join(story_dir, cited))
        # Walk up from the story dir looking for the bare basename (stories
        # typically sit one level below the planning-artifacts dir that holds
        # the brief).
        base = os.path.basename(cited)
        d = story_dir
        for _ in range(6):
            candidates.append(os.path.join(d, base))
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


with open(story_path, "r", encoding="utf-8") as fh:
    content = fh.read()

blocks, dangling = extract_blocks(content)
failures = []
claims_checked = 0

# THE UNMATCHED-SENTINEL GUARD. An opener with no closer is not "nothing to check" — it
# is this script failing to parse a block that is right there, and it used to be
# indistinguishable from a clean story because both roads end at the same PASS line.
# Reporting the openers that found no closer is what makes the two roads separable.
if dangling:
    print(f"VALIDATE-LOCKED-ANCHOR: FAIL ({story_path})", file=sys.stderr)
    print(f"  - {len(dangling)} LOCKED_REQUIREMENTS opener(s) with no closing sentinel, "
          f"at line(s) {', '.join(str(n) for n in dangling)}.", file=sys.stderr)
    print(f"    Close each block with `<!-- END LOCKED_REQUIREMENTS -->`. A per-block "
          f"discriminator is allowed (`<!-- END S<N> LOCKED_REQUIREMENTS -->`), and so is "
          f"the whole-block-in-one-comment form (`END LOCKED_REQUIREMENTS -->`).",
          file=sys.stderr)
    print(f"    This is not a formatting nit. An unparsed block contributed NOTHING, and "
          f"zero blocks reached the PASS line with zero claims verified — measured with a "
          f"same-run control, a fabricated requirement passed this check on one word's "
          f"difference in a comment.", file=sys.stderr)
    sys.exit(1)

for bidx, block in enumerate(blocks, start=1):
    lines = block.splitlines()
    sources = [FULL_TEXT_RE.match(ln).group(1) for ln in lines if FULL_TEXT_RE.match(ln)]

    # Requirement bullets = block bullets that are not schema key:value lines.
    # Computed BEFORE the no-sources guard below, which needs them.
    bullets = []
    for ln in lines:
        m = BULLET_RE.match(ln)
        if not m:
            continue
        text = m.group(1)
        if re.match(r"^\s*(full_text_source|requires_context|Source)\s*:", text):
            continue
        bullets.append(text)

    if not sources:
        # A block with requirement bullets and NEITHER citation form is
        # UNCHECKABLE: there is nothing to byte-verify it against. Passing it
        # with claims_checked=0 makes PASS reachable by two structurally
        # different roads -- "every claim verified" and "there was nothing to
        # check" -- sharing one exit code. That is the check-that-cannot-fire
        # class: a block that names requirements it never has to substantiate
        # scores exactly like one whose every requirement was verified verbatim.
        #
        # The guard fires on `bullets and no requires_context`, NOT on
        # `not sources`. An honest cite-by-reference block (requires_context:)
        # is a load pointer, not a full-text claim, and this script's own
        # contract (header) is that it is never byte-matched -- so honest
        # citation cannot fail this check. Failing it too would red every
        # cite-by-reference block in the repo, and a validator that always
        # fails is indistinguishable from one that works. A legacy block with
        # no bullets and no citation is left to the LLM Check 3.
        if bullets and not any(REQUIRES_CTX_RE.match(ln) for ln in lines):
            failures.append(
                f"block #{bidx}: {len(bullets)} requirement bullet(s) but no parseable "
                f"full_text_source: or requires_context: line -- the block is "
                f"uncheckable and cannot be byte-verified against the source of record"
            )
        continue

    for cited in sources:
        claims_checked += 1
        # Split on the LAST colon: <artifact>:<anchor>. Artifact paths do not
        # contain ':' in this repo; the anchor (e.g. LR-S288-1) never does.
        if ":" not in cited:
            failures.append(
                f"block #{bidx}: full_text_source '{cited}' is not in "
                f"<artifact>:<anchor> form"
            )
            continue
        artifact, anchor = cited.rsplit(":", 1)

        # (a) Source-of-record.
        if os.path.basename(artifact) != sor_basename:
            failures.append(
                f"block #{bidx}: full_text_source cites '{artifact}' but the "
                f"byte-verbatim source of record is '{sor_basename}'. A full-text "
                f"citation must resolve to the source of record, not a condensed "
                f"index (e.g. prd.md). Use requires_context: for a load pointer."
            )
            continue

        resolved = resolve_artifact(artifact, story_path)
        if resolved is None:
            failures.append(
                f"block #{bidx}: full_text_source artifact '{artifact}' not found "
                f"on disk (searched relative to the story file)"
            )
            continue

        with open(resolved, "r", encoding="utf-8") as afh:
            source_text = afh.read()

        if INDEX_MARKER_RE.search(source_text):
            failures.append(
                f"block #{bidx}: full_text_source '{artifact}' self-declares as a "
                f"condensed index (not the byte-verbatim record). Cite the "
                f"source of record for full text."
            )
            continue

        # (b) Anchor existence.
        if anchor not in source_text:
            failures.append(
                f"block #{bidx}: anchor '{anchor}' not found in '{artifact}' "
                f"(dangling full_text_source citation)"
            )
            continue

        # (c) Byte-verbatim (whitespace-collapsed substring).
        source_norm = collapse_ws(source_text)
        for btext in bullets:
            bnorm = collapse_ws(btext)
            if bnorm and bnorm not in source_norm:
                snippet = btext if len(btext) <= 80 else btext[:77] + "..."
                failures.append(
                    f"block #{bidx}: requirement not byte-present at "
                    f"full_text_source '{cited}' — lossy/summarized propagation: "
                    f"\"{snippet}\""
                )

if failures:
    print(f"VALIDATE-LOCKED-ANCHOR: FAIL ({story_path})", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)

print(
    f"VALIDATE-LOCKED-ANCHOR: PASS ({story_path}, {len(blocks)} block(s), "
    f"{claims_checked} full_text_source claim(s) verified against '{sor_basename}')"
)
sys.exit(0)
PYEOF
