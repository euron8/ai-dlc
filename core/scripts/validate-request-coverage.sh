#!/bin/bash
#
# validate-request-coverage.sh — every identifier the OPERATOR named reaches this sprint's
# LOCKED block, or is dispositioned there by name.
#
# THE FAILURE THIS EXISTS FOR. A sprint's LOCKED block is authored by the lead from the
# operator's request across a hop with no mechanical join at all. Every byte-level guarantee
# downstream — Check 3b's anchor, Check 30's spec join — terminates at `product-brief.md`,
# which is the lead's own restatement of the ask. So a plan can be internally consistent from
# the brief forward while sharing nothing with what was asked for, and every gate reads green.
#
# Measured, on the reference consumer: the operator's request named `ETH-REWARDS`, `CO-S293`,
# `CO-S295`, `LR-S299-0..11`, `CAP-1..10` and `Epic-FVS`. The sprint's own LOCKED block
# contained NONE of them. Three stories were planned, four consecutive gates passed, and the
# dominant work of the sprint was simply absent. Nothing in the pipeline compared the two.
#
# WHY IDENTIFIERS AND NOT PROSE. Comparing an ask to a plan in general is a judgement, and a
# judgement needs an adjudicator — which is what Check 27 already was, `hard_block: true` with
# `enforcer: []`, passing on a routing record that pointed at the PREVIOUS sprint. But
# operators write identifiers: across 23 substantive `/ai-dlc` asks on the reference consumer,
# 18 named at least one `CO-`, `LR-`, `CAP-` or `Epic-` id, mean 3.13 and max 13. Those are
# machine-comparable, and that subset is enough to catch a sprint that dropped its own topic.
#
# HONEST LIMIT, stated rather than papered over: 5 of those 23 asks name ZERO identifiers.
# This check has no subject there and says so — `identifiers_scanned: 0` with a NOT-APPLICABLE
# verdict. It is not a general scope-fidelity check and must not be read as one.
#
# A MENTION IS NOT A COMMITMENT, and getting that wrong makes the check pass the very failure
# it exists for. A brief accumulates one LOCKED block per sprint, and blocks cite each other
# constantly: the reference sprint's own block refers to the PREVIOUS sprint's `LR-S299-` ids
# repeatedly, as background for why one of its defects matters. The first draft of this check
# asked "does the identifier appear in this sprint's block", scored those references as
# coverage, and reported the dropped work as covered — the same confusion between referring to
# work and committing to it that produced the failure.
#
# So coverage is measured against DECLARED scope only: bullets of the form
#
#     - **LR-S300-0 (`CO-S299-Q96-PRECISION-ROUNDING`, determinism defect):** ...
#
# each running to the next LR bullet of any sprint. What such a bullet cites is committed;
# what the surrounding prose mentions is not. This also removes any need to attribute a whole
# block to a sprint — the previous sprint's bullets are headed by its own ids and contribute
# nothing. If NO bullet declares an id for this sprint there is no declared scope to compare
# against, and that exits 2: an unanswerable question, never a pass.
#
# The block grammar itself is NOT re-derived here. The LOCKED sentinel has six measured
# spellings and an unrecognised closer extracts as zero blocks, which once read as a clean
# pass; that grammar lives in validate-locked-anchor.sh and this calls it via --emit-blocks.
#
# USAGE
#   validate-request-coverage.sh --requests <file> --brief <file> --sprint <n> [--cite-sha <sha>]
#
#     --requests   operator-requests-history.md, written by the UserPromptSubmit hook
#     --brief      product-brief.md carrying the LOCKED blocks
#     --sprint     sprint number, selecting which block is this sprint's
#     --cite-sha   pin the entry by its recorded SHA256 instead of taking the newest
#
# A DISPOSITION, not a silence, is how an identifier is excluded. Inside the LOCKED block:
#
#     <!-- NOT-IN-SCOPE: CO-S299-PROMOTION-MANDATE-ENFORCEMENT-GAP — operator marked stretch -->
#
# EXIT
#   0  every named identifier is covered or dispositioned; or the ask named none
#   1  an identifier the operator named reaches neither the block nor a disposition
#   2  the requests file, the brief, or the sprint's block could not be resolved
#
# Compatible with bash 3.2+ and Python 3 (standard on macOS).

set -u

REQUESTS=""
BRIEF=""
SPRINT=""
CITE_SHA=""

while [ $# -gt 0 ]; do
    case "$1" in
        --requests) REQUESTS="${2:-}"; shift 2 ;;
        --brief)    BRIEF="${2:-}";    shift 2 ;;
        --sprint)   SPRINT="${2:-}";   shift 2 ;;
        --cite-sha) CITE_SHA="${2:-}"; shift 2 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$REQUESTS" ] || [ -z "$BRIEF" ] || [ -z "$SPRINT" ]; then
    echo "usage: validate-request-coverage.sh --requests <file> --brief <file> --sprint <n> [--cite-sha <sha>]" >&2
    exit 2
fi

# FAIL CLOSED on an absent capture. A missing requests file means the hook is not installed or
# the request predates it -- either way this check has no evidence, and "no evidence" must not
# render as "no problem". That direction is the whole defect being repaired: a routing record
# nothing could contradict.
if [ ! -r "$REQUESTS" ]; then
    echo "ERROR: operator-requests file not readable: $REQUESTS" >&2
    echo "       Without it there is no record of what was asked, and this check cannot" >&2
    echo "       distinguish a faithful plan from the reference failure. Install the" >&2
    echo "       UserPromptSubmit hook (ai-dlc-pause.sh), or record why it is absent." >&2
    exit 2
fi
if [ ! -r "$BRIEF" ]; then
    echo "ERROR: brief not readable: $BRIEF" >&2
    exit 2
fi

# Resolve this script's directory so the sibling grammar is found in BOTH layouts
# (core/scripts/ in the distribution, scripts/ai-dlc/ in a consumer).
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ANCHOR="$SELF_DIR/validate-locked-anchor.sh"
if [ ! -x "$ANCHOR" ] && [ ! -f "$ANCHOR" ]; then
    echo "ERROR: validate-locked-anchor.sh not found beside this script at $ANCHOR." >&2
    echo "       It owns the LOCKED block grammar; re-deriving it here would be two" >&2
    echo "       grammars in two files, which is the drift this call avoids." >&2
    exit 2
fi

BLOCKS="$(bash "$ANCHOR" "$BRIEF" --emit-blocks)" || {
    echo "ERROR: could not extract LOCKED blocks from $BRIEF (see above)." >&2
    exit 2
}

# The harness-origin declaration is resolved HERE, in bash, and passed in. The Python below
# runs from a heredoc, so it has no `__file__` to walk from -- a path derived there resolves
# against the caller's cwd and finds nothing. Both layouts are tried, because install.sh
# splits what shares a parent in core/.
HARNESS_ORIGIN=""
for _hoc in "$SELF_DIR/../schemas/harness-origin.json" \
            "$SELF_DIR/../../.claude/schemas/harness-origin.json" \
            "$SELF_DIR/../../core/schemas/harness-origin.json"; do
  [ -f "$_hoc" ] && { HARNESS_ORIGIN="$_hoc"; break; }
done

REQUESTS="$REQUESTS" BLOCKS="$BLOCKS" SPRINT="$SPRINT" CITE_SHA="$CITE_SHA" BRIEF="$BRIEF" HARNESS_ORIGIN="$HARNESS_ORIGIN" python3 <<'PYEOF'
import json
import os
import re
import sys

requests_path = os.environ["REQUESTS"]
blocks_raw = os.environ["BLOCKS"]
sprint = os.environ["SPRINT"]
cite_sha = os.environ["CITE_SHA"]

text = open(requests_path, encoding="utf-8", errors="replace").read()

# ---- select the request entry ----------------------------------------------
# Entries are `## <ts> -- <command>` followed by fields and a ```text fence.
ENTRY_RE = re.compile(r"^## (\S+) -- (.*)$")
entries, cur = [], None
for line in text.splitlines():
    m = ENTRY_RE.match(line)
    if m:
        cur = {"ts": m.group(1), "cmd": m.group(2), "sha": "", "body": [], "in": False}
        entries.append(cur)
        continue
    if cur is None:
        continue
    if line.startswith("- SHA256: "):
        cur["sha"] = line[len("- SHA256: "):].strip()
    elif line.strip() == "```text":
        cur["in"] = True
    elif line.strip() == "```" and cur["in"]:
        cur["in"] = False
    elif cur["in"]:
        cur["body"].append(line)

if not entries:
    sys.stderr.write(
        "ERROR: %s carries no operator-request entries.\n"
        "       An empty capture is not an empty ask -- it means nothing was recorded.\n"
        % requests_path)
    sys.exit(2)

# ---- entries the HARNESS wrote are not requests -----------------------------
# The capture hook records every UserPromptSubmit, and until v0.265.0 that included the
# events the harness raises when a backgrounded task completes. Those entries are shaped
# exactly like a typed one -- same `(typed)` command, same SHA -- so `entries[-1]` picked
# them, and a background-completion body names no identifier, so this check answered
# NOT-APPLICABLE and exited 0.
#
# MEASURED, because "would have" is not a finding: on the reference consumer's live capture,
# 4 of 6 entries were harness-raised and the newest three in a row were. Against a seeded
# brief the two paths were run side by side -- newest entry: `NOT-APPLICABLE ... rc=0`;
# pinned to the operator's real ask: `rc=1`, naming an uncovered CAP-. A background command
# finishing before the gate ran turned the check off, in the quiet direction.
#
# The hook no longer writes them, but this filter is not redundant with that fix and must not
# be removed as though it were: the file is APPEND-ONLY by design, so every consumer that
# ever ran an older hook still carries those entries at the end of its history, and they stay
# newest until the operator happens to type again.
#
# Prefixes come from schemas/harness-origin.json -- the same declaration the hook reads. A
# second copy here in Python is the drift this release exists to end.
_prefix_home = os.environ.get("HARNESS_ORIGIN", "")
_prefixes = []
if _prefix_home and os.path.isfile(_prefix_home):
    with open(_prefix_home, encoding="utf-8") as fh:
        _prefixes = json.load(fh).get("prefixes") or []
if not _prefixes:
    # A zero here would silently restore the defect: no prefixes means nothing is filtered,
    # and the run would look identical to one with nothing to filter.
    sys.stderr.write(
        "ERROR: schemas/harness-origin.json could not be resolved, so harness-raised entries\n"
        "       cannot be told from operator requests. Refusing to pick an entry: the failure\n"
        "       this guards against is a background task disarming the check, and it is\n"
        "       invisible in the output. Reinstall ai-dlc.\n")
    sys.exit(2)

def _harness_raised(e):
    body = "\n".join(e["body"]).lstrip()
    return any(body.startswith(p) for p in _prefixes)

operator_entries = [e for e in entries if not _harness_raised(e)]

if cite_sha:
    picked = [e for e in entries if e["sha"] == cite_sha]
    if not picked:
        sys.stderr.write(
            "ERROR: no captured request carries SHA256 %s.\n"
            "       The routing record cites a hash that resolves to nothing.\n" % cite_sha)
        sys.exit(2)
    entry = picked[-1]
    if _harness_raised(entry):
        # A pinned hash is deliberate, which is exactly why this must be loud rather than
        # silently re-picked: the routing record asserts the operator asked for this.
        sys.stderr.write(
            "ERROR: SHA256 %s resolves to a HARNESS-RAISED entry, not an operator request\n"
            "       (its body starts with a prefix declared in %s).\n"
            "       The routing record cites a background event as the sprint's ask.\n"
            % (cite_sha, os.path.basename(_prefix_home)))
        sys.exit(2)
else:
    if not operator_entries:
        sys.stderr.write(
            "ERROR: %s carries %d entr(ies), and every one of them was raised by the harness\n"
            "       rather than typed by an operator. There is no ask to compare the plan\n"
            "       against. This is not NOT-APPLICABLE -- it is a capture with no operator in it.\n"
            % (requests_path, len(entries)))
        sys.exit(2)
    entry = operator_entries[-1]

ask = "\n".join(entry["body"])

# ---- the identifiers an operator writes ------------------------------------
# Derived from 23 substantive asks on the reference consumer. A range (`LR-S299-0..11`,
# `CAP-1..10`) is satisfied by ANY member of its series -- the operator named a span, and a
# block citing one of them has plainly not dropped the topic.
PATTERNS = [
    (re.compile(r"\bCO-S\d+-[A-Z0-9][A-Z0-9-]*"), None),
    (re.compile(r"\bLR-S\d+-\d+(?:\.\.\d+)?"), re.compile(r"^(LR-S\d+-)")),
    (re.compile(r"\bCAP-\d+(?:\.\.\d+)?"), re.compile(r"^(CAP-)")),
    (re.compile(r"\bEpic-[A-Z]{2,}\b"), None),
]

wanted = []   # (as_written, satisfying_prefix_or_literal)
seen = set()
for pat, series in PATTERNS:
    for raw in pat.findall(ask):
        if raw in seen:
            continue
        seen.add(raw)
        if series and ".." in raw:
            m = series.match(raw)
            wanted.append((raw, m.group(1) if m else raw))
        else:
            wanted.append((raw, raw))

# ---- this sprint's DECLARED scope ------------------------------------------
# Scope is not "anywhere in the block". A brief accumulates one block per sprint and blocks
# cite each other constantly -- the reference sprint's own block mentions the PREVIOUS
# sprint's `LR-S299-` ids repeatedly, as background for why one of its defects matters. A
# check reading the whole block scores those mentions as coverage and passes the exact
# failure it exists to catch, for the exact reason the failure happened: confusing a
# reference to work with a commitment to do it.
#
# Scope is DECLARED, in bullets of the form
#
#     - **LR-S300-0 (`CO-S299-Q96-PRECISION-ROUNDING`, determinism defect):** ...
#
# so a bullet headed by an LR of THIS sprint, up to the next LR bullet of ANY sprint, is one
# committed item. What such a bullet cites is committed; what the surrounding prose mentions
# is not. This also removes the need to attribute a whole block to a sprint: the previous
# sprint's bullets are headed by its own ids and contribute nothing here.
blocks = [b for b in blocks_raw.split("\f") if b.strip()] if blocks_raw else []
LR_BULLET_RE = re.compile(r"^\s*[-*]\s+\**\s*LR-S(\d+)-\d+")


def bullet_header(bullet):
    """The declaring part of a LOCKED bullet: everything up to and including the first `:**`.

    A bullet's HEADER is where it says what it covers --

        - **LR-S299-9 (CO-S295, folded in, operator-specified):** ...

    -- and its body is prose that cites whatever it needs to explain itself, including other
    sprints' requirements. Measuring coverage over the body scores those citations as scope:
    a bullet that mentions `LR-S41-2` only to say "the failure mode resembles it" was enough
    to mark the operator's whole `LR-S41-0..7` span as covered. That is the same
    reference-versus-commitment confusion one level down, and the fixture's assertion 3 is
    what found it. Fall back to the first line when a bullet uses no `:**` terminator."""
    idx = bullet.find(":**")
    return bullet[:idx + 3] if idx != -1 else bullet.splitlines()[0]

own_bullets = []
for b in blocks:
    cur_sprint, buf = None, []
    for line in b.splitlines():
        m = LR_BULLET_RE.match(line)
        if m:
            if cur_sprint == sprint and buf:
                own_bullets.append(bullet_header("\n".join(buf)))
            cur_sprint, buf = m.group(1), [line]
            continue
        if cur_sprint is not None:
            buf.append(line)
    if cur_sprint == sprint and buf:
        own_bullets.append(bullet_header("\n".join(buf)))

if not own_bullets:
    sys.stderr.write(
        "ERROR: no LOCKED bullet in %s declares an LR-S%s- id (%d block(s) scanned).\n"
        "       This sprint has no declared scope to compare the request against. That is\n"
        "       not a pass -- it is an unanswerable question, and the failure this check\n"
        "       exists for looked exactly like a clean run.\n"
        % (os.path.basename(os.environ.get("BRIEF", "the brief")), sprint, len(blocks)))
    sys.exit(2)

scope = "\n".join(own_bullets)
# A disposition is authoritative wherever it appears in the LOCKED blocks -- it is an explicit
# statement ABOUT an identifier, so it does not need to live inside a committed bullet.
all_blocks_text = "\n".join(blocks)

# ---- dispositions ----------------------------------------------------------
DISPO_RE = re.compile(r"<!--\s*NOT-IN-SCOPE:\s*(\S+)")
dispositioned = set(DISPO_RE.findall(all_blocks_text))

covered, uncovered = [], []
for raw, needle in wanted:
    if needle in scope or raw in scope or raw in dispositioned:
        covered.append(raw)
    else:
        uncovered.append(raw)

# ---- report ----------------------------------------------------------------
# identifiers_scanned is printed on EVERY path, including the not-applicable one. A regex that
# matched nothing otherwise prints the same clean line as full coverage -- and a check whose
# clean line is indistinguishable from a check that had no subject is the failure class this
# whole release is about.
print("identifiers_scanned: %d" % len(wanted))
print("identifiers_covered: %d" % len(covered))
print("locked_blocks: %d  committed_bullets_for_sprint_%s: %d" % (len(blocks), sprint, len(own_bullets)))
print("request: %s (%s)" % (entry["ts"], entry["cmd"]))

if not wanted:
    print("NOT-APPLICABLE: the operator's request named no CO-/LR-/CAP-/Epic- identifier.")
    print("  This check has no subject here and is NOT evidence that scope is faithful;")
    print("  5 of 23 measured asks fall in this class.")
    sys.exit(0)

if uncovered:
    print("")
    print("FAIL: %d identifier(s) the operator named reach neither this sprint's LOCKED"
          % len(uncovered))
    print("      block nor a disposition inside it:")
    for u in uncovered:
        print("        %s" % u)
    print("")
    print("      Either the work is in scope -- in which case the LOCKED block must say so --")
    print("      or it is not, in which case say THAT, inside the block, by name:")
    print("        <!-- NOT-IN-SCOPE: %s — <reason> -->" % uncovered[0])
    print("      Do NOT resolve this by editing the operator's captured request. Rule 13")
    print("      reserves WHAT-changes to the operator.")
    sys.exit(1)

print("PASS: every identifier the operator named is covered or dispositioned.")
sys.exit(0)
PYEOF
