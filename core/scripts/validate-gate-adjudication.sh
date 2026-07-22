#!/usr/bin/env bash
# validate-gate-adjudication.sh — the READER of GATE_ADJUDICATION_VERDICT v1, and the
# DERIVER of the escalated check set.
#
# Usage:
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --expected <gate_type>
#        → prints the derived escalated check_ids (one per line) for that gate type.
#          This is the adjudicator's worklist AND the completeness check's expected set,
#          from ONE derivation, so the two can never disagree.
#   ./scripts/ai-dlc/validate-gate-adjudication.sh <gate_type> <verdict_path>
#        → completeness adjudication of the verdict at <verdict_path>.
#
# THE SET IS DERIVED, NOT LISTED. The escalated set is
#   escalate(check, gate_type) := check.adjudication == escalated_class
#                                 AND (gate_type ∈ check.gate_types OR "universal" ∈ ...)
# read straight from enforcement-map.yaml. There is no second list to drift from it — the
# whole reason this exists is that a hand-maintained escalation list is a check that cannot
# fire the day it rots, and a check that cannot fire reads exactly like one that passed.
#
# THE SHAPE IS THE SCHEMA. The envelope, the fields, the enums, the rules, and the escalation
# taxonomy (adjudication_classes / escalated_class) all come from
# schemas/gate-adjudication-verdict.json, which this script LOADS. No built-in copy; it fails
# closed if it cannot find the schema, exactly like validate-provenance-block.sh.
#
# FAIL-CLOSED (MALFORMED == ABSENT == BLOCK):
#   - an enforcement-map check whose adjudication value is outside adjudication_classes (a typo
#     like "lmm") is a hole in the derivation, not a fourth class → exit 2 at the derivation
#     layer, before any verdict is read.
#   - absent or unparseable verdict → exit 2.
#   - envelope mismatch (schema_id / gate_type / gate_nonce / generated_at) → exit 1.
#   - any escalated id missing, unexpected, duplicated, or malformed; any empty evidence;
#     any verdict == FAIL → exit 1.
#   - exit 0 IFF the escalated set is exactly covered, well-formed, and every verdict is PASS.
#   - an empty escalated set prints an AFFIRMATIVE "0 escalated checks for <gate_type>" and
#     exits 0 — a mis-derivation that empties the set is visible, never a silent vacuous pass.
#
# Exit codes:
#   0  — expected-set printed, OR verdict fully covers a well-formed, all-PASS escalated set
#   1  — a defect: malformed/mismatched envelope, coverage gap, or a FAIL verdict
#   2  — usage error, or a derivation-layer failure (unknown adjudication value, absent verdict)
#
# The lead runs the adjudicate form through verdict.sh so the exit code is not swallowed by a
# pipe. Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — the map is regex-parsed).

set -u

MODE=""
GATE_TYPE=""
VERDICT_PATH=""

case "${1:-}" in
    --expected)
        MODE="expected"
        GATE_TYPE="${2:-}"
        if [ -z "$GATE_TYPE" ]; then
            echo "usage: $0 --expected <gate_type>" >&2
            exit 2
        fi
        ;;
    "" )
        echo "usage: $0 --expected <gate_type>   |   $0 <gate_type> <verdict_path>" >&2
        exit 2
        ;;
    -*)
        echo "ERROR: unknown flag: $1" >&2
        exit 2
        ;;
    *)
        MODE="adjudicate"
        GATE_TYPE="$1"
        VERDICT_PATH="${2:-}"
        if [ -z "$VERDICT_PATH" ]; then
            echo "usage: $0 <gate_type> <verdict_path>" >&2
            exit 2
        fi
        ;;
esac

GA_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GA_ROOT="$(cd "$GA_SCRIPT_DIR/.." && pwd)"

SCHEMA="${AI_DLC_VERDICT_SCHEMA:-}"
if [ -z "$SCHEMA" ]; then
    for cand in \
        "$GA_ROOT/core/schemas/gate-adjudication-verdict.json" \
        "$GA_ROOT/.claude/schemas/gate-adjudication-verdict.json" \
        "$GA_SCRIPT_DIR/../schemas/gate-adjudication-verdict.json"; do
        [ -f "$cand" ] && { SCHEMA="$cand"; break; }
    done
fi
if [ -z "$SCHEMA" ] || [ ! -f "$SCHEMA" ]; then
    # FAIL CLOSED, LOUDLY. A reader that cannot find its schema must never guess a built-in
    # copy — that is the drift this design removed.
    echo "FAIL: schemas/gate-adjudication-verdict.json not found. The schema is the source of" >&2
    echo "      truth; this validator has no built-in copy and will not guess. Reinstall ai-dlc." >&2
    exit 2
fi

MAP="${AI_DLC_ENFORCEMENT_MAP:-}"
if [ -z "$MAP" ]; then
    for cand in \
        "$GA_ROOT/core/skills/ai-dlc/enforcement-map.yaml" \
        "$GA_ROOT/.claude/skills/ai-dlc/enforcement-map.yaml" \
        "$GA_SCRIPT_DIR/../skills/ai-dlc/enforcement-map.yaml"; do
        [ -f "$cand" ] && { MAP="$cand"; break; }
    done
fi
if [ -z "$MAP" ] || [ ! -f "$MAP" ]; then
    echo "FAIL: enforcement-map.yaml not found. The escalated set is DERIVED from it; this" >&2
    echo "      validator has no built-in list and will not guess. Reinstall ai-dlc." >&2
    exit 2
fi

python3 - "$MODE" "$GATE_TYPE" "$VERDICT_PATH" "$SCHEMA" "$MAP" <<'PYEOF'
import json
import os
import re
import sys

mode = sys.argv[1]
gate_type = sys.argv[2]
verdict_path = sys.argv[3]
schema_path = sys.argv[4]
map_path = sys.argv[5]

with open(schema_path, "r", encoding="utf-8") as fh:
    S = json.load(fh)

DERIV = S["derivation"]
CLASSES = set(DERIV["adjudication_classes"])
ESCALATED_CLASS = DERIV["escalated_class"]
MARKER = S["envelope"]["marker"]
PATTERNS = S["patterns"]


# ---------------------------------------------------------------- derive the escalated set
def parse_map(path):
    """Regex block-parse enforcement-map.yaml's `checks:` section (no PyYAML). Returns a list
    of (check_id, adjudication, [gate_types]) in file order, and the id of any check whose
    adjudication value is outside the closed class set."""
    checks = []
    in_checks = False
    cur_id = None
    cur_adj = None
    cur_gts = None

    def flush():
        if cur_id is not None:
            checks.append((cur_id, cur_adj, cur_gts if cur_gts is not None else []))

    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if re.match(r"^checks:\s*$", line):
                in_checks = True
                continue
            if re.match(r"^non_catalog_units:\s*$", line):
                flush()
                in_checks = False
                cur_id = None
                break
            if not in_checks:
                continue
            m = re.match(r'^  - id:\s*"?([^"\n]+?)"?\s*$', line)
            if m:
                flush()
                cur_id = m.group(1)
                cur_adj = None
                cur_gts = None
                continue
            m = re.match(r"^    adjudication:\s*([A-Za-z0-9_]+)", line)
            if m and cur_id is not None:
                cur_adj = m.group(1)
                continue
            m = re.match(r"^    gate_types:\s*\[(.*)\]\s*$", line)
            if m and cur_id is not None:
                cur_gts = [t.strip() for t in m.group(1).split(",") if t.strip()]
                continue
        else:
            flush()
    return checks


checks = parse_map(map_path)

# Enum / coverage guard — runs over EVERY check, independent of gate_type: a typo anywhere is
# a hole in the taxonomy, and the honest failure is at the derivation layer, exit 2.
unknown = [(cid, adj) for cid, adj, _ in checks if adj is None or adj not in CLASSES]
if unknown:
    for cid, adj in unknown:
        sys.stderr.write(
            f"FAIL (derivation): check '{cid}' has adjudication '{adj}', which is not one of "
            f"{sorted(CLASSES)}. An unknown value is not a fourth class — it is a hole the "
            f"escalation predicate falls through, so a check that should be judged is judged by "
            f"no one. Fix the enforcement-map value.\n"
        )
    sys.exit(2)


def escalated_for(gt):
    out = []
    for cid, adj, gts in checks:
        if adj != ESCALATED_CLASS:
            continue
        if gt in gts or "universal" in gts:
            out.append(cid)
    return out


E = escalated_for(gate_type)

if mode == "expected":
    if not E:
        print(f"0 escalated checks for {gate_type}")
    else:
        for cid in E:
            print(cid)
    sys.exit(0)


# --------------------------------------------------------------------- adjudicate a verdict
def block(exit_code, msg):
    sys.stderr.write(f"VALIDATE-GATE-ADJUDICATION: FAIL ({verdict_path})\n")
    sys.stderr.write(f"  - {msg}\n")
    sys.exit(exit_code)


if not os.path.isfile(verdict_path):
    # ABSENT is not a soft pass. The bounded-join could not find the verdict at the nonce path,
    # which — with the nonce derived from gate_type + timestamp — means no fresh verdict exists.
    sys.stderr.write(
        f"VALIDATE-GATE-ADJUDICATION: FAIL — verdict absent at {verdict_path}.\n"
        f"  A missing verdict is non-delivery (Rule 20), not a clean gate. Dispatch the "
        f"gate-adjudicator, join its deliverable, then re-run. HARD_BLOCK if it does not land.\n"
    )
    sys.exit(2)

try:
    with open(verdict_path, "r", encoding="utf-8") as fh:
        V = json.load(fh)
except (ValueError, OSError) as exc:
    sys.stderr.write(
        f"VALIDATE-GATE-ADJUDICATION: FAIL — verdict at {verdict_path} is not parseable JSON "
        f"({exc}). MALFORMED == ABSENT: an unreadable verdict blocks.\n"
    )
    sys.exit(2)

if not isinstance(V, dict):
    block(1, "verdict is valid JSON but not an object.")

# --- envelope (exit 1 on any mismatch) ---
if V.get("schema_id") != f"{MARKER}":
    block(1, f"schema_id is {V.get('schema_id')!r}, not {MARKER!r}. This is not a "
             f"GATE_ADJUDICATION_VERDICT.")

for f in ("gate_type", "gate_nonce", "generated_at"):
    val = V.get(f)
    if val is None or (isinstance(val, str) and not val.strip()):
        block(1, f"required envelope field '{f}' is missing or empty.")

if V["gate_type"] != gate_type:
    block(1, f"gate_type {V['gate_type']!r} does not match the adjudicated gate type "
             f"{gate_type!r}. A verdict for another gate type is not evidence about this gate.")

# gate_nonce MUST equal the verdict filename stem — this is the freshness anchor. A stale
# verdict from an earlier gate lives at a different path and carries a different nonce.
stem = os.path.basename(verdict_path)
for suffix in (".verdict.json", ".json"):
    if stem.endswith(suffix):
        stem = stem[: -len(suffix)]
        break
if V["gate_nonce"] != stem:
    block(1, f"gate_nonce {V['gate_nonce']!r} does not match the verdict filename stem "
             f"{stem!r}. The nonce is the freshness anchor; a mismatch means this file is stale "
             f"or foreign and must not read as this gate's verdict.")

if not re.match(PATTERNS["gate_nonce"], V["gate_nonce"]):
    block(1, f"gate_nonce {V['gate_nonce']!r} does not match the required "
             f"<gate_type>-<UTC-timestamp> shape.")
if not re.match(PATTERNS["iso8601_utc"], str(V["generated_at"])):
    block(1, f"generated_at {V['generated_at']!r} is not ISO 8601 UTC.")

for f in ("adjudicator_agent_id", "catalog"):
    val = V.get(f)
    if val is None or (isinstance(val, str) and not val.strip()):
        block(1, f"required field '{f}' is missing or empty.")

# --- verdicts (exit 1 on any coverage/shape/FAIL defect) ---
verdicts = V.get("verdicts")
if not isinstance(verdicts, list):
    block(1, "required field 'verdicts' is missing or not an array.")

seen = []
fails = []
for i, entry in enumerate(verdicts):
    if not isinstance(entry, dict):
        block(1, f"verdicts[{i}] is not an object.")
    cid = entry.get("check_id")
    if cid is None or (isinstance(cid, str) and not cid.strip()):
        block(1, f"verdicts[{i}] has a missing or empty check_id.")
    cid = str(cid)
    if cid in seen:
        block(1, f"check_id {cid!r} appears more than once — a duplicated verdict is ambiguous.")
    seen.append(cid)
    vd = entry.get("verdict")
    if vd not in ("PASS", "FAIL"):
        block(1, f"check_id {cid!r} has verdict {vd!r}, not PASS or FAIL. There is no third "
                 f"value: a check you cannot evaluate is FAIL-with-reason.")
    ev = entry.get("evidence")
    if ev is None or (isinstance(ev, str) and not ev.strip()):
        block(1, f"check_id {cid!r} has empty evidence. An unjustified verdict — even a PASS — "
                 f"is the failure this path exists to prevent.")
    if vd == "FAIL":
        fails.append(cid)

expected = set(E)
got = set(seen)
missing = sorted(expected - got, key=lambda x: (len(x), x))
extra = sorted(got - expected, key=lambda x: (len(x), x))
if missing:
    block(1, f"escalated check(s) NOT adjudicated: {missing}. Every escalated check must carry "
             f"a verdict — an omitted check is an unadjudicated check, which reads as clean.")
if extra:
    block(1, f"verdict names check(s) {extra} that are not in the escalated set for "
             f"'{gate_type}'. The adjudicator evaluates exactly the derived worklist.")

if not E:
    print(f"VALIDATE-GATE-ADJUDICATION: PASS — 0 escalated checks for {gate_type}; verdict "
          f"envelope well-formed.")
    sys.exit(0)

if fails:
    block(1, f"gate check(s) FAILED per the adjudicator: {sorted(fails, key=lambda x: (len(x), x))}. "
             f"The lead owns the block; this verdict is what it adopts.")

print(f"VALIDATE-GATE-ADJUDICATION: PASS ({verdict_path}, {len(E)} escalated check(s) for "
      f"{gate_type}, all PASS)")
sys.exit(0)
PYEOF
