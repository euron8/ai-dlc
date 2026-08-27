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
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --series <dir|verdict>...
#        → THE STALL RUNG. Groups every verdict found by gate_series_id and errors when one
#          check_id holds FAIL across K consecutive passes of one gate. See "THE STALL RUNG".
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
# THE STALL RUNG (--series). The gate failure protocol already ended in "if still failing
# after remediation, escalate as HARD_BLOCK per Rule 12" — and nothing counted, so nothing
# escalated. Measured on the reference consumer: one [story] gate ran ELEVEN passes with the
# same check failing the last seven, and hard_block_count stayed at 0. The loop was not
# unbounded by design; it was unbounded because no artifact carried the series.
#
# gate_series_id is what makes the series expressible (the nonce is per-PASS: eleven passes,
# eleven nonces, one gate, and nothing in the data said so). This mode reads it.
#
# THRESHOLD, BACKTESTED (not chosen for elegance) — the placement arm E of
# validate-adversarial-convergence.sh uses for its own. Against the reference consumer's
# ENTIRE gate-adjudication corpus: 94 verdict files, of which 93 carry a schema-conforming
# gate_nonce; the 94th ("planning-20260719T0300-arch") does not and drops out of every
# grouping. gate_series_id did not exist yet, so the series was reconstructed as
# (gate_type + calendar day) — 38 groups, 20 of them multi-pass. Exactly three (series,
# check_id) pairs in the whole corpus ever reach two consecutive FAILs:
#
#   implementation 20260725  check 22   FFFFF.       run 5 of 6 passes
#   story          20260811  check 2    FF.........  run 2 of 11 passes
#   story          20260811  check 7    ....FFFFFFF  run 7 of 11 passes
#
#   K=2  fires 3x, 1 false — story/2 resolved on the very next pass; blocking there
#        interrupts a loop that was making progress.
#   K=3  fires 2x, 0 false — implementation/22 and story/7, both real stalls. The second
#        is the cascade this rung was written for; the FIRST WENT UNNOTICED ENTIRELY, so
#        the shape is recurrent, not a one-off.
#   K=4  fires 2x, 0 false — the same two, one pass later. No corpus check has a run of
#        exactly 3 or 4, so K=3 and K=4 select an identical set and K=3 costs less.
#
# K=3 SURVIVES PERTURBING THE INSTRUMENT and K=2 does not, which is the stronger reason to
# prefer it. Re-run with the passes ordered by generated_at instead of gate_nonce, and again
# with series allowed to span a calendar day (the day split understates runs — the s298
# implementation gate really did straddle 07-24/07-25, run 6 not 5), K=3 fires on the same
# two series every time; K=2 goes 3, 4, 4.
#
# FALSE FIRE is defined as "the check PASSes on the pass immediately after the rung fires" —
# the loop was converging and the block was premature. The looser reading, "resolves anywhere
# later in the series", scores implementation/22 as false too (it passed on pass 6, after five
# straight FAILs), and that reading is wrong: a five-pass stall that eventually clears is
# precisely what this rung exists to hand to the operator two passes sooner. Under the loose
# reading K=3 has 1 false fire; both numbers are reported so the choice is visible.
#
# K IS A HARD CONSTANT IN THIS FILE, not a schema field and not an env var. It is the one
# dial that turns the rung off — set it to 99 and a stalled gate reports clean forever — and
# a threshold the consumer can edit is an opt-out shipped inside the mechanism. Same posture
# as arm E's STALL_THRESHOLD. Shape belongs in the loaded schema; the number that decides
# whether a stall is visible does not.
#
# PASS ORDER IS gate_nonce, NOT generated_at. The nonce is gate entry; generated_at is when
# the adjudicator finished writing. Measured on that same 11-pass series the two orders
# DISAGREE (a later-entered pass was written first), and the generated_at order manufactures
# a fourth K=2 fire out of a check that never failed twice in a row.
#
# NOTHING IN SCOPE IS SKIPPED SILENTLY, AND THE POSTURE IS PER CLASS. A rung with a quiet
# skip path can be defeated by producing the skip, which is this release's own defect class.
# DEMONSTRATED before it was closed: five byte-identical verdicts in one series, one PASS
# re-nonced to "<ts>-arch" — the exact shape of the single non-conforming file in the
# reference corpus — re-sorts a 4-pass FAIL run into 2+2, and the rung goes from exit 1 to
# exit 0 without one verdict value changing.
#
#   - NON-CONFORMING gate_nonce → FAIL-CLOSED, exit 1, whether or not the file carries a
#     series id. The nonce is the SORT KEY here, not merely a freshness anchor, and a key
#     outside the pattern sorts wherever its bytes fall. Measured: 1 of the reference
#     corpus's 94 files ("planning-20260719T0300-arch"), and it is a genuine malformed
#     artifact rather than a legitimate form the pattern is too narrow for — the pattern
#     shipped to that consumer on 2026-07-15 and the file was written on 2026-07-19, so it
#     was already in force. It is also proof that verdicts reach the corpus without passing
#     the per-pass validator, which is why this mode re-checks rather than trusts.
#   - NONCE PREFIX ≠ gate_type → FAIL-CLOSED, exit 1. With it holding, lexicographic nonce
#     order IS chronological order within a gate, which is what makes the sort sound.
#   - A .json in scope that is not a verdict, or does not parse → FAIL-CLOSED, exit 2. Same
#     class: a file the rung cannot read is a pass it cannot count. Measured FP set on the
#     reference corpus: 0 of 94.
#   - LEGACY (no gate_series_id) → SPLIT, and this is the only fail-open in the mode. A
#     verdict that sorts strictly BEFORE the first pass of every live series of its gate_type
#     is counted, named on stdout, and does not affect the exit: a gate reset retains the
#     prior series on disk beside the new one, so the first scan after any reset sees these,
#     and failing closed would kill the mode exactly when it is meant to run. A legacy verdict
#     at or after a live series' first pass FAILS CLOSED, exit 1 — that is not a retained
#     series, it is a pass of the live one with its id missing, and it is the shape that
#     shortens a run. No flag overrides either half; a switch the lead can throw is the
#     opt-out this release exists to remove.
#
# The remaining hole is closed on the other side: the per-pass adjudicate mode treats a
# missing gate_series_id as a required-field failure, exit 1, so no NEW verdict reaches this
# mode without one.
#
# FAIL-CLOSED (MALFORMED == ABSENT == BLOCK):
#   - an enforcement-map check whose adjudication value is outside adjudication_classes (a typo
#     like "lmm") is a hole in the derivation, not a fourth class → exit 2 at the derivation
#     layer, before any verdict is read.
#   - absent or unparseable verdict → exit 2.
#   - envelope mismatch (schema_id / gate_type / gate_series_id / gate_nonce / generated_at)
#     → exit 1.
#   - any escalated id missing, unexpected, duplicated, or malformed; any empty evidence;
#     any verdict == FAIL → exit 1.
#   - exit 0 IFF the escalated set is exactly covered, well-formed, and every verdict is PASS.
#   - an empty escalated set prints an AFFIRMATIVE "0 escalated checks for <gate_type>" and
#     exits 0 — a mis-derivation that empties the set is visible, never a silent vacuous pass.
#
# Exit codes:
#   0  — expected-set printed, OR verdict fully covers a well-formed, all-PASS escalated set,
#        OR --series found no stalled check
#   1  — a defect: malformed/mismatched envelope, coverage gap, a FAIL verdict, or (--series)
#        a stalled check / a gate_series_id spanning two gate_types or a duplicated pass
#   2  — usage error, or a derivation-layer failure (unknown adjudication value, absent verdict,
#        unreadable --series path, unparseable verdict under --series)
#
# The lead runs the adjudicate form through verdict.sh so the exit code is not swallowed by a
# pipe. Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — the map is regex-parsed).

set -u

MODE=""
GATE_TYPE=""
VERDICT_PATH=""
SERIES_PATHS=()

case "${1:-}" in
    --expected)
        MODE="expected"
        GATE_TYPE="${2:-}"
        if [ -z "$GATE_TYPE" ]; then
            echo "usage: $0 --expected <gate_type>" >&2
            exit 2
        fi
        ;;
    --series)
        MODE="series"
        shift
        if [ "$#" -eq 0 ]; then
            echo "usage: $0 --series <dir|verdict>..." >&2
            exit 2
        fi
        SERIES_PATHS=("$@")
        ;;
    "" )
        echo "usage: $0 --expected <gate_type>   |   $0 <gate_type> <verdict_path>" >&2
        echo "       $0 --series <dir|verdict>..." >&2
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

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts —
# here that put both the schema and enforcement-map.yaml out of reach.
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
GA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GA_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$GA_ROOT" ] || GA_ROOT="$(ai_dlc_resolve_root "$GA_SCRIPT_DIR" || true)"
[ -n "$GA_ROOT" ] || GA_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$GA_ROOT" ] || GA_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
GA_ROOT="${GA_ROOT:-/nonexistent}"
# --- end AI_DLC_ROOT --------------------------------------------------------

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

# ${SERIES_PATHS+...} and not a bare "${SERIES_PATHS[@]}": under `set -u`, bash 3.2 treats the
# expansion of an EMPTY array as an unbound variable and aborts — which would kill every
# non-series mode on macOS's system bash.
# The repair-record arm RUNS arm H's own repair_field() rather than a copy of it, so it needs
# the sibling's path. Resolved here, where the two layouts are already worked out, and passed
# in — an empty string when absent, which the arm turns into an exit 2 rather than a guess.
SIBLING=""
for cand in \
    "$GA_ROOT/core/scripts/validate-adversarial-convergence.sh" \
    "$GA_ROOT/scripts/ai-dlc/validate-adversarial-convergence.sh" \
    "$GA_SCRIPT_DIR/validate-adversarial-convergence.sh"; do
    [ -f "$cand" ] && { SIBLING="$cand"; break; }
done

python3 - "$MODE" "$GATE_TYPE" "$VERDICT_PATH" "$SCHEMA" "$MAP" "$SIBLING" ${SERIES_PATHS+"${SERIES_PATHS[@]}"} <<'PYEOF'
import glob
import json
import os
import re
import subprocess
import sys

mode = sys.argv[1]
gate_type = sys.argv[2]
verdict_path = sys.argv[3]
schema_path = sys.argv[4]
map_path = sys.argv[5]
sibling_path = sys.argv[6]
series_paths = sys.argv[7:]

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


# ------------------------------------------------------------------ the stall rung (--series)
# Dispatched BEFORE escalated_for(): a series scan spans passes and has no single gate_type to
# derive an escalated set against. Coverage was already adjudicated per pass, at the pass; what
# this reads is the shape ACROSS passes, which no single verdict can see.
#
# It is dispatched AFTER the map enum guard on purpose, so a map with an unknown adjudication
# value exits 2 here too. This mode does not consume the derived set, but a corpus adjudicated
# against a broken taxonomy is a corpus whose FAILs may be missing checks nobody judged, and a
# run computed over it would be short. Fail closed rather than count it.
def run_series():
    # THE THRESHOLD IS A HARD CONSTANT, and deliberately not a schema field or an env var.
    # K is the one dial that turns this rung off: set it to 99 and a stalled gate reports
    # clean forever. A tunable threshold is an opt-out shipped inside the mechanism, which is
    # the defect class this whole release exists to remove — so it is not consumer-editable,
    # exactly like arm E's STALL_THRESHOLD in validate-adversarial-convergence.sh. The WHY,
    # with the backtest, is in this file's header. Shape lives in the schema; the number that
    # decides whether a stall is visible does not.
    K = 3

    # --- collect ---
    files = []
    for p in series_paths:
        if os.path.isdir(p):
            for dirpath, _, names in os.walk(p):
                for n in sorted(names):
                    if n.endswith(".json"):
                        files.append(os.path.join(dirpath, n))
        elif os.path.isfile(p):
            files.append(p)
        else:
            # An unreadable path is not an empty series. A typo'd directory that scanned zero
            # files and exited 0 is the canonical check-that-cannot-fire.
            sys.stderr.write(
                f"VALIDATE-GATE-ADJUDICATION: FAIL — --series path does not exist: {p}\n"
                "  A path that cannot be read is not a series with no stalls.\n"
            )
            sys.exit(2)
    files = sorted(set(files))

    passes = []      # (series_id, gate_type, gate_nonce, path, {check_id: verdict})
    legacy = []      # (path, gate_type, gate_nonce) — verdicts predating gate_series_id
    defects = []
    placed_sids = set()
    incomplete_sids = set()   # series that lost a pass to a malformed nonce
    for path in files:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                V = json.load(fh)
        except (ValueError, OSError) as exc:
            sys.stderr.write(
                f"VALIDATE-GATE-ADJUDICATION: FAIL — {path} is not parseable JSON ({exc}). "
                "MALFORMED == ABSENT: an unreadable verdict in a series is a pass this rung "
                "cannot count, so it blocks rather than counting a shorter run.\n"
            )
            sys.exit(2)
        if not isinstance(V, dict) or V.get("schema_id") != MARKER:
            # A .json in scope that this rung cannot interpret. Same class as unparseable:
            # the scan cannot certify it saw every pass, so it does not get to report a
            # clean series. Measured FP set on the reference consumer's 94-file corpus: 0.
            sys.stderr.write(
                f"VALIDATE-GATE-ADJUDICATION: FAIL — {path} is JSON but not a {MARKER}.\n"
                "  A file this rung cannot read is a pass it cannot count. Point --series at "
                "the verdicts, or move the file out of scope.\n"
            )
            sys.exit(2)

        sid = V.get("gate_series_id")
        is_legacy = sid is None or (isinstance(sid, str) and not sid.strip())
        for f in ("gate_type", "gate_nonce"):
            val = V.get(f)
            if val is None or (isinstance(val, str) and not val.strip()):
                sys.stderr.write(
                    f"VALIDATE-GATE-ADJUDICATION: FAIL ({path})\n"
                    f"  - required envelope field '{f}' is missing or empty, so this pass "
                    f"cannot be placed in time or in a series.\n"
                )
                sys.exit(1)
        gt, nonce = V["gate_type"], str(V["gate_nonce"])

        # THE SORT KEY MUST BE SORTABLE. This is not a restatement of the per-pass nonce
        # check — here the nonce ORDERS the series, and a nonce outside the pattern sorts
        # wherever its bytes fall. DEMONSTRATED: five byte-identical verdicts in one series,
        # one PASS re-nonced to "<ts>-arch" (the exact shape of the one non-conforming file
        # in the reference corpus), and a 4-pass FAIL run splits into 2+2 — the rung goes
        # from exit 1 to exit 0 with no verdict value changed. Blocking, legacy or not.
        if not re.match(PATTERNS["gate_nonce"], nonce):
            # Remember which series lost a pass here. The repair-record arm joins pass N to
            # pass N+1, and "N+1" means the next pass IN THE SERIES — if a pass between them
            # was excluded, that join is over a gap and would read a repair as missing when
            # the truth is a pass could not be placed.
            if not is_legacy:
                incomplete_sids.add(str(sid))
            defects.append(
                f"{path}: gate_nonce {nonce!r} does not match the required "
                f"<gate_type>-<UTC-timestamp> shape. The nonce ORDERS the passes of a series; "
                f"one that cannot be ordered silently re-sequences the run, and a re-sequenced "
                f"run is a shorter run. This blocks whether or not the file carries a series id."
            )
            continue
        # rsplit, not the pattern's capture group: 'sprint-review' contains the delimiter, and
        # the timestamp never does. With this holding, lexicographic nonce order == chronological
        # order within a gate_type, which is what makes the sort above sound.
        if nonce.rsplit("-", 1)[0] != gt:
            defects.append(
                f"{path}: gate_nonce {nonce!r} is prefixed {nonce.rsplit('-', 1)[0]!r} but "
                f"gate_type is {gt!r}. The prefix is what makes nonce order chronological "
                f"within a gate; a mismatched one sorts this pass into another gate's run."
            )
            continue

        if is_legacy:
            legacy.append((path, gt, nonce))
            continue
        if sid is not None:
            placed_sids.add(str(sid))
        entry = {}
        for e in V.get("verdicts", []) or []:
            if isinstance(e, dict) and e.get("check_id") is not None:
                entry[str(e["check_id"])] = e.get("verdict")
        passes.append((str(sid), gt, nonce, path, entry))

    # LEGACY POSTURE — fail-open ONLY for a verdict that provably cannot be a pass of a live
    # series, fail-closed otherwise, and no flag to override either way.
    #
    # Fail-closed everywhere would kill the mode at the moment it is meant to run: a gate reset
    # retains the prior series on disk beside the new one (nothing is ever deleted), so the
    # first scan after a reset always sees legacy files. Fail-open everywhere would hand over
    # the opt-out — delete one field from one verdict and its pass leaves the count.
    #
    # The discriminator needs no new data. A reset mints a new id going FORWARD, so a genuinely
    # retained prior series sorts strictly before the live series' first pass. A legacy verdict
    # at or after that point is not a retained series; it is a pass of the live one that lost
    # its id, and it is exactly the shape that shortens a run.
    live_first = {}
    for _, gt, nonce, _, _ in passes:
        if gt not in live_first or nonce < live_first[gt]:
            live_first[gt] = nonce
    benign_legacy = []
    for path, gt, nonce in sorted(legacy):
        if gt in live_first and nonce >= live_first[gt]:
            defects.append(
                f"{path}: carries no gate_series_id but its nonce {nonce!r} falls at or after "
                f"the first pass of a live {gt} series ({live_first[gt]}). A retained prior "
                f"series sorts strictly earlier; this is a pass of the live series with its "
                f"series id missing, and counting the series without it reports a short run."
            )
        else:
            benign_legacy.append(path)
    for p in benign_legacy:
        print(f"  counted, not grouped (no gate_series_id, predates every live series): {p}")

    if not passes:
        if defects:
            sys.stderr.write("VALIDATE-GATE-ADJUDICATION: FAIL (--series)\n")
            for d in defects:
                sys.stderr.write(f"  - {d}\n")
            sys.exit(1)
        # AFFIRMATIVE, never silent. Zero series is a legitimate state (a fresh gate, or a
        # corpus entirely predating gate_series_id) and it is also what a mis-aimed scan looks
        # like, so the counts that produced it are printed rather than implied.
        print(
            f"VALIDATE-GATE-ADJUDICATION: PASS — 0 series carrying a gate_series_id across "
            f"{len(files)} .json file(s) in scope, all {len(benign_legacy)} of them legacy. "
            f"EXAMINED NOTHING — nothing to count; nothing counted."
        )
        sys.exit(0)

    # --- group; order by gate_nonce (gate ENTRY), never generated_at (write completion) ---
    series = {}
    for sid, gt, nonce, path, entry in passes:
        series.setdefault(sid, []).append((nonce, gt, path, entry))
    for sid in series:
        series[sid].sort(key=lambda t: (t[0], t[2]))

    # rules.series_single_gate
    for sid in sorted(series):
        gts = sorted({gt for _, gt, _, _ in series[sid]})
        if len(gts) > 1:
            defects.append(
                f"series {sid!r} spans gate_types {gts}. A gate_series_id is ONE gate entry; "
                f"an id copied across gates makes every series-level count a union of "
                f"unrelated loops."
            )
        seen_nonce = {}
        for nonce, _, path, _ in series[sid]:
            if nonce in seen_nonce:
                defects.append(
                    f"series {sid!r} has two passes sharing gate_nonce {nonce!r} "
                    f"({seen_nonce[nonce]}, {path}). One pass overwrote the other's path, so a "
                    f"pass is missing from the count and every run in this series is short."
                )
            seen_nonce[nonce] = path

    def scan_runs(entries):
        """THE one definition of a consecutive-FAIL run, for every arm that needs one. Returns
        (peak, first_at): peak[cid] is the longest run; first_at[cid] is (pass_index, run_start
        nonce, nonce) at which it first reached K. Two implementations of 'consecutive' would
        drift, and the boundary arm below exists precisely to compare two of these."""
        run, run_from, peak, first_at = {}, {}, {}, {}
        for i, (nonce, gt, path, entry) in enumerate(entries, 1):
            for cid in list(run):
                if cid not in entry:
                    # A check absent from a pass BREAKS its run. The conservative direction:
                    # absence is not evidence of another FAIL. Never exercised on real data —
                    # the reference corpus's check set is constant across all 38 series — so
                    # this is a stated choice, not a measured one.
                    run[cid] = 0
            for cid, vd in sorted(entry.items()):
                if vd == "FAIL":
                    run[cid] = run.get(cid, 0) + 1
                    if run[cid] == 1:
                        run_from[cid] = nonce
                    if run[cid] > peak.get(cid, 0):
                        peak[cid] = run[cid]
                    if run[cid] >= K and cid not in first_at:
                        first_at[cid] = (i, run_from[cid], nonce)
                else:
                    run[cid] = 0
        return peak, first_at

    # rules.series_stall_run
    for sid in sorted(series):
        entries = series[sid]
        _, first_at = scan_runs(entries)
        for cid in sorted(first_at):
            i, first, last = first_at[cid]
            defects.append(
                f"STALLED: series {sid!r} ({entries[i - 1][1]}) — check '{cid}' has held FAIL "
                f"across {K} consecutive passes, {first} → {last} (pass {i} of {len(entries)} "
                f"in scope). Remediation is not converging on this check. Escalate as "
                f"HARD_BLOCK per Rule 12 and hand it to the operator; another pass of the same "
                f"loop is what this rung exists to stop."
            )

    # rules.repair_record — the repair between two passes was DELEGATED and recorded.
    #
    # The gate-side analogue of arm H in validate-adversarial-convergence.sh, and it exists
    # for the same reason: a lead that repairs the artifact inline and writes no record
    # produces a verdict series BYTE-IDENTICAL to a delegated one. The FAILs fall either way,
    # and every arm above passes over it. Measured on the reference consumer's stalled gate —
    # 104 main-thread edits, zero remediator dispatches, and nothing on disk could tell the
    # difference.
    #
    # WHAT THIS PROVES, AND WHAT IT DOES NOT. It proves a STRUCTURED repair record exists for
    # every pass whose FAILs a later pass shows were repaired. It does NOT prove a remediator
    # subagent rather than the lead authored it: a subagent leaves no transcript on disk.
    # Existence + structure is the honest floor, and it is exactly what separates "repaired
    # inline, no record" from "delegated". Authorship attribution is a separate mechanism.
    #
    # A REPAIR IS PROVABLE ONLY WHEN THE FAILS FELL. Pass N recorded >=1 FAIL and pass N+1
    # records fewer. No fall, nothing to demand a record for: a plateau is the stall rung's
    # business and a rise is a regression, not a repair. Firing only on the provable case is
    # the conservative floor.
    #
    # THE FIELD READER IS ARM H'S OWN, EXECUTED, NOT RE-TRANSCRIBED. The one-line definition
    # is read out of validate-adversarial-convergence.sh at runtime and run — the same bind
    # check-24-adversarial-convergence uses when it EVALs that line. A regex restated here in
    # Python could be right in one file and wrong in the other, and the version of that bug
    # that already shipped had the taught template and the reader disagreeing for nine
    # releases while both looked correct. Fail closed if the sibling or its definition is
    # missing: no built-in copy, same posture as the schema loader.
    #
    # NOT FOLDED, DELIBERATELY. A wrapped-sentence blind spot is real where the unit is a
    # record or a paragraph; here the unit genuinely IS a line. Arm H's anchor is what keeps
    # it able to fire — an unanchored predicate matches ordinary prose mentioning the word —
    # and a soft-wrapped field VALUE cannot hide its label, because the label opens the field.
    # Folding would also break the bind, since it would no longer be arm H's reader running.
    def repair_field_reader():
        if sibling_path and os.path.isfile(sibling_path):
            with open(sibling_path, "r", encoding="utf-8") as fh:
                for line in fh:
                    if line.startswith("repair_field() {"):
                        return sibling_path, line.rstrip("\n")
        return None, None

    def check_repair_records():
        _, defn = repair_field_reader()
        if defn is None:
            sys.stderr.write(
                "VALIDATE-GATE-ADJUDICATION: FAIL — cannot find arm H's repair_field() "
                "definition in validate-adversarial-convergence.sh. This arm runs that "
                "reader rather than a copy of it, and it will not guess a regex: a "
                "re-transcribed one can be right in one file and wrong in the other.\n"
            )
            sys.exit(2)

        for sid in sorted(series):
            if sid in incomplete_sids:
                continue    # a pass of this series could not be placed; N->N+1 spans a gap
            entries = series[sid]
            gt = entries[0][1]
            for n in range(len(entries) - 1):
                cur_fails = {c for c, v in entries[n][3].items() if v == "FAIL"}
                nxt_fails = {c for c, v in entries[n + 1][3].items() if v == "FAIL"}
                if not cur_fails or len(nxt_fails) >= len(cur_fails):
                    continue
                M = n + 1
                # THE RECORD IS NOT BESIDE THE VERDICTS, and assuming it was is the one bug
                # this arm shipped with. Verdicts live at
                # ${AI_DLC_STATE_DIR:-_bmad-output}/gate-adjudication/<nonce>.verdict.json
                # (_gate-procedures.md:143); the gate repair record lives at
                # _bmad-output/planning-artifacts/s<N>/gate-<type>-repair-p<M>.md (:426).
                # Two different subtrees, and nothing writes into gate-adjudication/ except
                # the adjudicator — so dirname(verdict) fires on every CORRECTLY delegated
                # repair, which is the failure mode that gets a check switched off.
                #
                # The transplant from arm H is right up to exactly this caller. Arm H's
                # dirname(pass_file) is CORRECT for the adversarial caller, because there the
                # pass artifacts and the repair records co-locate in planning-artifacts/s<N>/.
                # The gate caller is the one place that stops being true.
                state = os.path.dirname(os.path.dirname(entries[n][2])) or "."
                pa = os.path.join(state, "planning-artifacts")
                # ONE glob, and `gate-*` rather than `*-repair-p<M>.md`. The ADVERSARIAL record
                # for the same pass number, `<artifact>-repair-p<M>.md`, sits in the SAME
                # sprint directory and is usually well-structured — adopting one would pass
                # this arm with no gate record written at all. A false pass here is worse than
                # a false miss: it is the inline-repair hole, reopened by the check meant to
                # close it. Measured on the reference consumer, widening to `*-repair-p<M>.md`
                # takes the finding count from 18 to 0 on a tree holding ZERO gate records.
                #
                # It is ONE glob because `gate-*` is a strict superset of `gate-<gt>-`, so a
                # second lookup for the exact name found nothing the first did not — it only
                # made a PARTIAL path regression survivable: point one of the two at the wrong
                # directory and the other still finds the record, so the delegated case stays
                # green and only a same-name-wrong-place fixture case notices. One expression
                # cannot half-regress. Exact name first, so the message names the right file
                # when a wrong-gate-type record is also present.
                #
                # TWO SUFFIXES, ONE EXPRESSION, AND THE `gate-` ANCHOR SURVIVES BOTH. Not every
                # FAIL closes by a remediator repair. A check whose input is a file the
                # remediation guard leaves LEAD-editable — `docs/escalations/**` and
                # `*-resolution-p*.md`, ai-dlc-gate-remediation-guard.sh:284-285 — closes by a
                # lead-authored RESOLUTION, and no remediator dispatch is warranted or possible
                # for it. With one accepted suffix the lead's only ways out were to file the
                # record under a name asserting a dispatch that did not happen, or to take a
                # MISSING finding for work correctly done. `gate-<gt>-resolution-p<M>.md` is the
                # truthful name and is now accepted.
                #
                # THE ANCHOR IS WHAT MAKES THAT SAFE, and dropping it repeats the measured
                # mistake above one suffix over. `<artifact>-resolution-p<M>.md` is the
                # ADVERSARIAL resolution record (_gate-procedures.md:324) and sits in the same
                # sprint directory, exactly as `<artifact>-repair-p<M>.md` does. Measured on the
                # reference consumer, at depth 2 under planning-artifacts: `gate-*-repair-p<M>`
                # 15 files, `*-repair-p<M>` 113, `*-resolution-p<M>` 17 of which 16 are
                # adversarial and ONE is a gate record. So the unanchored form would pull in 16
                # foreign records; `gate-*` pulls in one, the one meant.
                #
                # STRUCTURE IS UNCHANGED, which is why this widens the accepted NAME and not the
                # standard. A candidate still has to carry `disposition:`, `edit:` and
                # `derivation:` under arm H's executed reader, so MISSING REPAIR RECORD keeps its
                # subject: a FAIL repaired with no record on disk still fires. Measured against
                # the same 16 adversarial resolution records, ZERO are structured under that
                # reader — so even the unanchored form could not have produced a false PASS here,
                # only a foreign file misreported as a malformed gate record. That is the reason
                # a marker check rejecting ADVERSARIAL_RESOLUTION is NOT here: it would change no
                # verdict on any tree measured, and a guard whose removal changes nothing is not
                # load-bearing.
                #
                # It is still ONE expression. The comprehension takes one `pa` and one pattern
                # TEMPLATE, so a path regression breaks both suffixes together — the half-regress
                # this comment warns about needs two independently written lookups, which is not
                # what a loop over a suffix tuple is.
                want = f"gate-{gt}-repair-p{M}.md"
                alt = f"gate-{gt}-resolution-p{M}.md"
                cands = sorted(
                    (p for kind in ("repair", "resolution")
                     for p in glob.glob(os.path.join(pa, "*", f"gate-*-{kind}-p{M}.md"))),
                    key=lambda p: (os.path.basename(p) not in (want, alt),
                                   os.path.basename(p) != want, p))
                named = next((p for p in cands if os.path.basename(p) in (want, alt)),
                             os.path.join(pa, "s<N>", want))
                structured = None
                unstructured = None
                for cand in cands:
                    if not (os.path.isfile(cand) and os.path.getsize(cand) > 0):
                        continue
                    rc = subprocess.call(
                        ["bash", "-c",
                         defn + '\nrepair_field disposition "$1" && repair_field edit "$1" '
                                '&& repair_field derivation "$1"', "_", cand],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    )
                    if rc == 0:
                        structured = cand
                        break
                    unstructured = cand
                if structured:
                    continue
                fell = f"{len(cur_fails)} FAIL(s) -> {len(nxt_fails)}"
                if unstructured:
                    defects.append(
                        f"UNSTRUCTURED REPAIR RECORD: series {sid!r} ({gt}) pass {M} was "
                        f"repaired before pass {M + 1} ({fell}), and {unstructured} exists but "
                        f"is not a structured record — it lacks one of 'disposition:', "
                        f"'edit:', 'derivation:' (remediator.md; a lead-authored "
                        f"'gate-<type>-resolution-p<M>.md' carries the same three fields). "
                        f"The label is read literally "
                        f"and must open a line with the colon immediately after; emphasis "
                        f"(**, _, backticks) is fine, RENAMING is not ('edit sites:' is not "
                        f"'edit:'; a '### Derivation' heading is not the field)."
                    )
                else:
                    defects.append(
                        f"MISSING REPAIR RECORD: series {sid!r} ({gt}) pass {M} recorded "
                        f"{len(cur_fails)} FAIL(s) that pass {M + 1} shows repaired ({fell}), "
                        f"but no record exists at {named}. The lead does not repair the "
                        f"artifact itself — one dispatched remediator per pass writes the "
                        f"record the next pass verifies against. A missing record is the lead "
                        f"having repaired inline, and the verdict series alone cannot tell "
                        f"that from a delegated repair, which is why this arm reads the "
                        f"record and not the series. Where the FAIL closed WITHOUT a "
                        f"remediator — a lead-authored escalation resolution on a file the "
                        f"remediation guard leaves lead-editable — write "
                        f"{os.path.join(pa, 's<N>', alt)} instead, carrying the same "
                        f"'disposition:', 'edit:', 'derivation:'. Do not file a repair record "
                        f"for a dispatch that did not happen."
                    )

    check_repair_records()

    # rules.series_boundary_run — a gate RESET must not launder a live stall.
    #
    # Splitting one gate across two gate_series_ids defeats the rung above: every run looks
    # short. Detecting "a split" is undecidable — it is byte-for-byte what B4 defines a
    # legitimate reset to be (mint a new id, pass count restarts at zero). So this does not
    # try. It fires only on the version that MATTERS: two temporally adjacent series of the
    # same gate_type whose concatenation produces a run >= K that NEITHER half produces alone.
    # A reset that clears the stall stays silent and B4's semantics survive intact; a reset
    # that changes no answer is invisible here. Only a reset that hides a live run is caught.
    by_type = {}
    for sid in series:
        by_type.setdefault(series[sid][0][1], []).append(
            (series[sid][0][0], series[sid][-1][0], sid)
        )
    for gt, lst in sorted(by_type.items()):
        lst.sort()
        for (a_first, a_last, a), (b_first, b_last, b) in zip(lst, lst[1:]):
            if not b_first > a_last:
                continue    # overlapping in time; concatenation would not be chronological
            peak_a, _ = scan_runs(series[a])
            peak_b, _ = scan_runs(series[b])
            peak_ab, _ = scan_runs(series[a] + series[b])
            for cid in sorted(peak_ab):
                if peak_ab[cid] >= K > max(peak_a.get(cid, 0), peak_b.get(cid, 0)):
                    defects.append(
                        f"SPLIT SERIES: check '{cid}' holds FAIL across {peak_ab[cid]} "
                        f"consecutive {gt} passes spanning the boundary between series "
                        f"{a!r} (ends {a_last}) and {b!r} (starts {b_first}), but only "
                        f"{peak_a.get(cid, 0)} and {peak_b.get(cid, 0)} within each. A new "
                        f"gate_series_id restarts the pass count; it does not repair the "
                        f"artifact. This reset did not clear the stall, and counting the two "
                        f"halves separately is what makes a live run look short."
                    )

    if defects:
        sys.stderr.write("VALIDATE-GATE-ADJUDICATION: FAIL (--series)\n")
        for d in defects:
            sys.stderr.write(f"  - {d}\n")
        sys.exit(1)

    shape = ", ".join(
        f"{sid}={len(series[sid])}p" for sid in sorted(series, key=lambda s: (-len(series[s]), s))[:6]
    )
    print(
        f"VALIDATE-GATE-ADJUDICATION: PASS (--series) — {len(series)} series / {len(passes)} "
        f"pass(es), no check_id held FAIL across {K} consecutive passes. Longest: {shape}. "
        f"{len(benign_legacy)} legacy verdict(s) named above, each predating every live series."
    )
    sys.exit(0)


if mode == "series":
    run_series()


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

for f in ("gate_type", "gate_series_id", "gate_nonce", "generated_at"):
    val = V.get(f)
    if val is None or (isinstance(val, str) and not val.strip()):
        extra = ""
        if f == "gate_series_id":
            # This is the one that closes --series. A new verdict without it is invisible to
            # the stall rung, and the rung's own skip-legacy behaviour would hide it, so the
            # per-pass gate is where it has to be caught.
            extra = (" The series id is stamped ONCE at gate entry and repeated on every pass"
                     " of this gate; it is NOT the per-pass gate_nonce. Without it this pass"
                     " cannot be counted against the stall rung.")
        block(1, f"required envelope field '{f}' is missing or empty.{extra}")

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
