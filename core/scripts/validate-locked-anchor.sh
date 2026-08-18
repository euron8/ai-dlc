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
# The BYTE-MATCH fires ONLY on a LOCKED_REQUIREMENTS block that makes a FULL-TEXT
# CLAIM via a `full_text_source:` line. Honest cite-by-reference (`requires_context:`)
# is a load pointer, not a full-text claim, and its bullets are never byte-matched —
# so honest citation cannot fail this check.
#
# THE POINTER ITSELF IS RESOLVED, AND THAT IS NOT THE SAME THING. A
# `requires_context:` citation asserts exactly one fact — that the named artifact and
# anchor are there for a dev to load — and until this checked it, a block could cite
# nothing that exists and score identically to one that cited correctly. Measured on a
# reference consumer: every story of the live sprint passed reporting `0 claim(s)
# verified`, and across its 998-story corpus a nonzero claim count had never once
# occurred, while 34 of 47 pointers named an absent anchor. Resolving the pointer
# leaves the stated contract intact — an honest pointer resolves.
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
#       record: basename `locked-requirements.md` (the sprint slot, where
#       discovery.md §4a now writes the block) or, transitionally, the legacy
#       `product-brief.md`. `--sor` replaces both with one name.
#       A citation resolving to any other artifact, or to one that self-declares
#       `locked_requirements_fidelity: index` / a "condensed index" provenance,
#       FAILS. Catches "cite prd.md for full text" when prd.md is an index.
#   (b) Anchor existence and SCOPE — the <anchor> must resolve in the cited
#       artifact, either as a token appearing in it or as a line range within
#       its length. What it resolves TO is the window (c) searches.
#   (c) Byte-verbatim — every requirement bullet in the block must be present,
#       after whitespace collapse, WITHIN THE UNION OF THE ANCHORS THE BLOCK
#       CITES (a summarized/≤N-char restatement will not match). Catches
#       tooling-threshold-driven summarization; the motive is unprovable from
#       the file, but the lossy RESULT is deterministic, and lossy propagation
#       is independently forbidden by Rule 13. Searching the whole artifact
#       instead — what this did until the anchor window existed — proves
#       co-presence, not anchoring: a bullet matched text the citation does not
#       name and the check reported the citation verified.
#
# Exit code 0 has TWO roads and they now print DIFFERENT lines. A story that
# verified nothing (no resolvable citation of either form) is reported as
# `PASS — EXAMINED NOTHING`. It is not failed: a block that claims nothing has
# nothing to substantiate. It is no longer spelled like a verified story.
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
EMIT_BLOCKS=0

shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sor)
            SOR_OVERRIDE="${2:-}"
            shift 2
            ;;
        --emit-blocks)
            # Print the delimited LOCKED_REQUIREMENTS block bodies of <file> and exit.
            #
            # WHY THIS MODE EXISTS HERE rather than in the caller. The sentinel has SIX
            # measured spellings (see the grammar note above), an unrecognised closer
            # extracts as NOTHING, and a non-greedy span match lets one block SWALLOW
            # dozens of real ones. That grammar cost a release to get right. A second
            # reader of the same blocks re-deriving it would be two grammars in two files
            # drifting apart -- so validate-request-coverage.sh calls this instead.
            EMIT_BLOCKS=1
            shift
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$STORY_PATH" ]]; then
    echo "usage: ./scripts/ai-dlc/validate-locked-anchor.sh <story-file> [--sor <path>]" >&2
    echo "       ./scripts/ai-dlc/validate-locked-anchor.sh <file> --emit-blocks" >&2
    exit 2
fi

if [[ ! -f "$STORY_PATH" ]]; then
    echo "ERROR: story file not found: $STORY_PATH" >&2
    exit 1
fi

python3 - "$STORY_PATH" "$SOR_OVERRIDE" "$EMIT_BLOCKS" <<'PYEOF'
import os
import re
import sys

story_path = sys.argv[1]
sor_override = sys.argv[2] or None

# Source-of-record basenames: where discovery.md §4a writes the byte-verbatim
# LOCKED_REQUIREMENTS block by construction.
#
# TWO NAMES, AND THE SECOND ONE IS TRANSITIONAL BY DESIGN. §4a used to append the
# block to the durable brief, one per sprint; it now writes it to that sprint's own
# slot as `s<N>/locked-requirements.md`. Accepting ONLY the new name would fail every
# story already carrying `full_text_source: product-brief.md#LR-...` -- measured on
# the reference consumer at 31 of 62 anchored citations, all resolvable, none
# defective. Refusing them would be this check reporting a migration as a fabrication.
#
# `prd.md` and every other condensed index stay refused, which is the property this
# test exists for; widening from one name to two does not weaken it.
#
# REMOVE `product-brief.md` WHEN, and not before: a consumer's brief holds no
# LOCKED_REQUIREMENTS block (`--emit-blocks` over it returns none) and its story
# corpus carries no `full_text_source` naming it. Both are measurable in one run, so
# this deprecation has a test rather than a date.
DEFAULT_SOR_BASENAMES = ("locked-requirements.md", "product-brief.md")
LEGACY_SOR_BASENAME = "product-brief.md"
if sor_override:
    sor_basenames = (os.path.basename(sor_override),)
else:
    sor_basenames = DEFAULT_SOR_BASENAMES
# The name a message NAMES when it has to name one: the override if given, else the
# current source of record. Never the legacy name -- a remedy telling an author to
# cite the artifact this release moved the block out of is the wrong instruction.
sor_basename = sor_basenames[0]

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


if sys.argv[3] == "1":
    # --emit-blocks. Print each block body, separated by a form feed so a caller can split
    # on a byte that cannot occur in a requirement bullet. A DANGLING opener is reported on
    # stderr and exits 1 rather than silently contributing nothing: the whole reason this
    # grammar admits six spellings is that an unrecognised closer once extracted as zero
    # blocks and read as a clean pass.
    _text = open(story_path, encoding="utf-8", errors="replace").read()
    _blocks, _dangling = extract_blocks(_text)
    if _dangling:
        sys.stderr.write(
            "ERROR: %d LOCKED_REQUIREMENTS opener(s) with no recognised closer at line(s) %s\n"
            % (len(_dangling), ", ".join(str(n) for n in _dangling)))
        sys.exit(1)
    sys.stdout.write("\f".join(_blocks))
    sys.exit(0)


FULL_TEXT_RE = re.compile(r"^\s*full_text_source:\s*(\S+)\s*$")
REQUIRES_CTX_RE = re.compile(r"^\s*requires_context:\s*\S")
# The citation VALUE of a load pointer, as distinct from its mere PRESENCE above.
# `requires_context:` was recognised only as a presence and its target was never
# resolved -- see the pointer-resolution loop below for what that cost.
REQUIRES_CTX_CITE_RE = re.compile(r"^\s*requires_context:\s*(\S+)\s*$")
BULLET_RE = re.compile(r"^\s*[-*]\s+(.*\S)\s*$")
LINE_RANGE_RE = re.compile(r"^(\d+)-(\d+)$")
HEADING_RE = re.compile(r"^(#{1,6})\s")
# An artifact that self-declares it is NOT the verbatim record.
INDEX_MARKER_RE = re.compile(
    r"locked_requirements_fidelity:\s*index|condensed index|INDEXING, not weakening",
    re.IGNORECASE,
)


def collapse_ws(s):
    return re.sub(r"\s+", " ", s).strip()


def split_citation(cite):
    """Split a citation into (artifact, anchor); anchor is "" when there is no separator.

    `#` WINS OVER `:` AND BOTH ARE ACCEPTED FOR BOTH KEYS. The schema spells a load
    pointer `<artifact>#<anchor>` and a full-text claim `<artifact>:<anchor>`, but both
    separators are in the field for both keys -- a story block citing
    `product-brief.md#LR-S299-4` and a body line citing
    `docs/architecture-proposed.md:440-806` were measured in the same sprint. Splitting
    on the LAST separator is what makes a path containing neither ambiguous rather than
    silently truncated.
    """
    cite = cite.strip("`")
    if "#" in cite:
        artifact, _, anchor = cite.rpartition("#")
        return artifact, anchor
    if ":" in cite:
        artifact, _, anchor = cite.rpartition(":")
        return artifact, anchor
    return cite, ""


def anchor_window(source_text, anchor):
    """The section(s) an anchor names, or None when the anchor is not in the artifact.

    THE BYTE-MATCH USED TO SEARCH THE WHOLE FILE, AND THAT IS WHY THIS EXISTS. The
    anchor was consumed by the existence check at (b) and then discarded, so a
    requirement bullet satisfied check (c) by matching text ANYWHERE in the source --
    including a paragraph the citation does not name. A citation that resolves only
    because the brief happens to contain the words somewhere is not an anchored
    citation, and the check that was supposed to prove anchoring proved co-presence.

    A LINE-RANGE anchor (`2423-2433`) selects exactly those lines, and a range that
    runs past EOF is a dangling citation rather than a silently clamped one. A TOKEN
    anchor selects, for every line carrying it, that line through the next markdown
    heading at the same-or-shallower depth (EOF when there is none) -- so an anchor in
    an unstructured brief widens to the whole remainder rather than to nothing.
    """
    lines = source_text.splitlines()
    ranged = LINE_RANGE_RE.match(anchor)
    if ranged:
        lo, hi = int(ranged.group(1)), int(ranged.group(2))
        if lo < 1 or lo > hi or hi > len(lines):
            return None
        return "\n".join(lines[lo - 1:hi])
    hits = [i for i, ln in enumerate(lines) if anchor in ln]
    if not hits:
        return None
    sections = []
    for i in hits:
        depth = 99
        for j in range(i, -1, -1):
            hm = HEADING_RE.match(lines[j])
            if hm:
                depth = len(hm.group(1))
                break
        end = len(lines)
        for j in range(i + 1, len(lines)):
            hm = HEADING_RE.match(lines[j])
            if hm and len(hm.group(1)) <= depth:
                end = j
                break
        sections.append("\n".join(lines[i:end]))
    return "\n".join(sections)


ANCHOR_SPRINT_RE = re.compile(r"\bLR-S(\d+)-")


def resolve_artifact(cited, story_path, anchor=""):
    """Resolve a cited artifact path/basename to an existing file.

    THE ANCHOR CAN NAME A SPRINT, AND WHEN IT DOES IT DECIDES WHICH SLOT TO READ.
    Rule 13 makes locked requirements cumulative, so a story can honestly cite a
    requirement locked in an EARLIER sprint -- and since discovery.md §4a writes each
    sprint's block to `s<N>/locked-requirements.md`, the walk-up below would otherwise
    reach the STORY'S OWN sprint slot and report `anchor not found`. That is a true
    statement about the wrong file, which is the failure mode this whole function was
    reordered in v0.263.0 to stop producing.

    Measured on the reference consumer at the time this shipped: `LR-S<n>-` tokens in
    stories name a sprint other than the story's own **260** times out of 4019, and
    **0** of the 62 ANCHORED citations did. So the corpus was correct by accident --
    nothing forbade a cross-sprint anchor, and the first one written would have been
    rejected for the wrong reason. `s<n>/` is tried FIRST when the anchor names one,
    because a same-basename file in the story's own slot would otherwise shadow it.
    """
    story_dir = os.path.dirname(os.path.abspath(story_path))
    candidates = []
    sprint_m = ANCHOR_SPRINT_RE.search(anchor or "")
    if sprint_m and not os.path.isabs(cited):
        slot = "s%s" % sprint_m.group(1)
        base = os.path.basename(cited)
        d = story_dir
        for _ in range(6):
            candidates.append(os.path.join(d, slot, base))
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
    if os.path.isabs(cited):
        candidates.append(cited)
    else:
        # THE STORY'S OWN DIRECTORY IS TRIED FIRST, AND THE ORDER IS THE WHOLE POINT.
        # A citation is a claim about the brief that sits BESIDE THE STORY; the process
        # working directory is a property of whoever invoked the validator and has no
        # relationship to either file. With `os.getcwd()` first -- the shipped order from
        # v0.40.0 until v0.263.0 -- a bare `product-brief.md` resolved against the caller's
        # cwd, so the same story verified against a DIFFERENT brief depending on where the
        # command was typed.
        #
        # That is not hypothetical: `core/fixtures/check-3b-locked-anchor/` ships its own
        # `product-brief.md` (carrying `LR-1`/`LR-2`) in the directory the fixture runs
        # from, and the spelling matrix writes its stories to a tempdir holding a brief
        # with `LR-S1-1`. Run from the repo root the fixture was green; run from its own
        # directory the seven honest cases went red on `anchor not found`, and -- worse --
        # the seven FABRICATED cases were rejected for the missing anchor rather than for
        # the fabrication, so half the matrix asserted nothing. A check whose verdict
        # depends on the caller's cwd reads exactly like one that passed.
        #
        # cwd is KEPT as a later candidate rather than dropped: it costs nothing once the
        # story-relative reading has had its turn, and dropping it would be an unmeasured
        # narrowing. Reordering was measured instead -- 59 real citation-bearing artifacts
        # on the reference consumer, 0 verdict changes from either cwd, because 28 of the
        # story citations carry the full relative path and only 3 are bare basenames.
        candidates.append(os.path.join(story_dir, cited))
        candidates.append(os.path.join(os.getcwd(), cited))
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
pointers_checked = 0
# Claims still anchored at the legacy source of record. Reported on the PASS line so a
# consumer can see its own migration burn down -- and so the removal condition in the
# DEFAULT_SOR_BASENAMES comment is something a run ANSWERS rather than something an
# operator estimates. Never a failure: an unmigrated citation is behind, not wrong.
legacy_claims = 0

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

    # RESOLVE THE LOAD POINTERS. A `requires_context:` citation is correctly never
    # byte-matched -- its bullets are an abridged restatement by design, and matching
    # them would red every honest cite-by-reference block. But the POINTER ITSELF makes
    # one falsifiable assertion, that the named artifact and anchor are there to load,
    # and nothing checked it. Measured on a reference consumer before this was added:
    # all ten stories of the live sprint reported PASS with `0 claim(s) verified`,
    # because every block in that sprint cited only `requires_context:`; across its
    # whole 998-story corpus `claims_checked >= 1` had NEVER ONCE occurred. Meanwhile
    # 34 of 47 pointers in the corpus named an anchor absent from the artifact.
    #
    # Resolving the pointer keeps this script's stated contract intact -- "honest
    # citation cannot fail this check" -- because an honest pointer resolves. What it
    # removes is the road by which a block substantiates nothing and scores as clean.
    for cite in [REQUIRES_CTX_CITE_RE.match(ln).group(1)
                 for ln in lines if REQUIRES_CTX_CITE_RE.match(ln)]:
        artifact, anchor = split_citation(cite)
        resolved = resolve_artifact(artifact, story_path, anchor)
        if resolved is None:
            failures.append(
                f"block #{bidx}: requires_context artifact '{artifact}' not found on "
                f"disk (searched relative to the story file). A dev told to load this "
                f"at implementation time gets nothing."
            )
            continue
        pointers_checked += 1
        if not anchor:
            continue
        with open(resolved, "r", encoding="utf-8") as pfh:
            if anchor_window(pfh.read(), anchor) is None:
                failures.append(
                    f"block #{bidx}: requires_context anchor '{anchor}' is absent from "
                    f"'{artifact}' (dangling load pointer). The file resolves and the "
                    f"anchor does not, so the pointer names a section the artifact no "
                    f"longer has."
                )

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

    # The anchor windows every full-text claim in THIS block resolved to. The byte-match
    # at (c) runs once against their UNION, not once per citation.
    #
    # WHY THE UNION, AND IT IS NOT A LOOSENING. The bullet loop used to sit INSIDE the
    # citation loop, so a block with N citations and N bullets demanded that EVERY
    # bullet be present at EVERY anchor. Whole-file matching hid that: the file contains
    # all of them, so it passed. Scoping to the anchor exposes it -- measured, two
    # two-citation blocks on a reference consumer went red because bullet 1 is not at
    # anchor 2, one line above it in the brief. That is the cross-product, not a
    # mis-anchored story. A block's bullets must be present in what the block CITES,
    # which is the union; requiring each at each is a defect of the old loop shape.
    windows = []
    for cited in sources:
        claims_checked += 1
        artifact, anchor = split_citation(cited)
        if not anchor:
            failures.append(
                f"block #{bidx}: full_text_source '{cited}' is not in "
                f"<artifact>:<anchor> form"
            )
            continue

        # (a) Source-of-record.
        cited_base = os.path.basename(artifact)
        if cited_base not in sor_basenames:
            accepted = " or ".join(f"'{b}'" for b in sor_basenames)
            failures.append(
                f"block #{bidx}: full_text_source cites '{artifact}' but the "
                f"byte-verbatim source of record is {accepted}. A full-text "
                f"citation must resolve to the source of record, not a condensed "
                f"index (e.g. prd.md). Use requires_context: for a load pointer."
            )
            continue
        if not sor_override and cited_base == LEGACY_SOR_BASENAME:
            legacy_claims += 1

        resolved = resolve_artifact(artifact, story_path, anchor)
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

        # (b) Anchor existence -- and, now, anchor SCOPE. The window this returns is
        # what (c) matches against; a None is the dangling citation check.
        window = anchor_window(source_text, anchor)
        if window is None:
            failures.append(
                f"block #{bidx}: anchor '{anchor}' not found in '{artifact}' "
                f"(dangling full_text_source citation)"
            )
            continue
        windows.append(window)

    # (c) Byte-verbatim (whitespace-collapsed substring) WITHIN THE CITED ANCHORS.
    if windows:
        source_norm = collapse_ws("\n".join(windows))
        cited_list = ", ".join(sources)
        for btext in bullets:
            bnorm = collapse_ws(btext)
            if bnorm and bnorm not in source_norm:
                snippet = btext if len(btext) <= 80 else btext[:77] + "..."
                failures.append(
                    f"block #{bidx}: requirement not byte-present at the cited "
                    f"anchor(s) '{cited_list}' — lossy/summarized propagation, or "
                    f"text that lives elsewhere in the artifact than where this "
                    f"block says it does: \"{snippet}\""
                )

if failures:
    print(f"VALIDATE-LOCKED-ANCHOR: FAIL ({story_path})", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)

# THE TWO ROADS TO PASS NOW SAY WHICH ONE THEY TOOK. "Every claim verified" and "there
# was nothing to check" still share exit code 0 -- a block that claims nothing has
# nothing to substantiate, and failing it would red every legacy block in a consumer's
# history for a defect it does not have. What was wrong was that they also shared one
# REPORT LINE, so an operator reading a green gate could not tell a verified story from
# an unverified one. They are separable now without moving the exit code.
if claims_checked == 0 and pointers_checked == 0:
    print(
        f"VALIDATE-LOCKED-ANCHOR: PASS — EXAMINED NOTHING ({story_path}, "
        f"{len(blocks)} block(s) carried no resolvable citation). This is not a "
        f"defect on its own; it is the absence of evidence, and it is reported "
        f"rather than spelled the same as a verified story."
    )
else:
    legacy_note = (
        f", {legacy_claims} of them still at the legacy '{LEGACY_SOR_BASENAME}'"
        if legacy_claims else ""
    )
    print(
        f"VALIDATE-LOCKED-ANCHOR: PASS ({story_path}, {len(blocks)} block(s), "
        f"{claims_checked} full_text_source claim(s) verified against "
        f"'{sor_basename}'{legacy_note}, {pointers_checked} requires_context "
        f"pointer(s) resolved)"
    )
sys.exit(0)
PYEOF
