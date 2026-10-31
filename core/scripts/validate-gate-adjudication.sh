#!/usr/bin/env bash
# validate-gate-adjudication.sh — the READER of GATE_ADJUDICATION_VERDICT v1, and the
# DERIVER of the escalated check set.
#
# Usage:
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --expected <gate_type>
#        → prints the derived escalated check_ids (one per line) for that gate type.
#          This is the adjudicator's worklist AND the completeness check's expected set,
#          from ONE derivation, so the two can never disagree.
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --expected <gate_type> --shard <i>/<N>
#        → shard i of N of that same list: a contiguous, balanced slice, disjoint from every
#          other shard, the N slices concatenating to the bare output. Refuses (exit 2,
#          `REFUSED:`) a malformed i/N, i > N, or N above the list's length. See "SHARDING".
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --merge <gate_type> <verdict_path> <part>...
#        → joins the shards' parts into the ONE verdict at <verdict_path>, then runs the
#          --coverage arms on it and returns their exit. Refuses (exit 2, `REFUSED:`, nothing
#          written) unless the parts are exactly this nonce's 1..N, every line carries this
#          nonce, no check_id appears twice, and the union equals --expected. See "SHARDING".
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --check-part <part>
#        → THE SHARD'S SELF-CHECK, run on its part before returning the path. The per-row
#          checks --merge makes that need no other part (filename shape, JSON object, exact key
#          set, gate_nonce equal to the filename's stem, non-empty envelope fields, the schema's
#          non_empty/enum item checks), by the SAME functions --merge calls, so a refusal is
#          --merge's text under a `--check-part:` label; exit 2 `REFUSED:`, exit 0 `PART-OK`.
#          Cross-part checks (shard count, indices, duplicates, union, series/catalog agreement,
#          the content seal) stay merge-only. See "THE PER-PART CONTRACT".
#   ./scripts/ai-dlc/validate-gate-adjudication.sh <gate_type> <verdict_path> \
#        [--transcript PATH] [--transcript-dir DIR]
#        → completeness adjudication of the verdict at <verdict_path>. The transcript
#          corpus is what the SUPPRESSED carve-out verifies an entry's operator citation
#          against (see "the SUPPRESSED carve-out" below); --transcript-dir takes
#          precedence, for the reason validate-escalation-resolution.sh gives. With a FAIL
#          under an in-force entry and NO readable corpus the carve-out applies to nothing.
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --coverage <gate_type> <verdict_path>
#        → THE ADJUDICATOR'S SELF-CHECK. The envelope and coverage arms of the mode above and
#          nothing else, so it exits 0 whatever the per-check verdicts say. See "THE COVERAGE
#          MODE".
#   ./scripts/ai-dlc/validate-gate-adjudication.sh --series <dir|verdict>...
#        → THE STALL RUNG. Groups every verdict found by gate_series_id and errors when one
#          check_id holds FAIL across K consecutive passes of one gate. See "THE STALL RUNG".
#
# FAIL_WAIVED (rules.waiver_id, rules.all_pass). A third verdict value: the check FAILED and the
# operator waived it through the escalation entry `waiver_id` names. Every reader here treats it
# as a FAIL -- the coverage arm, the repair-record arm (FAIL -> FAIL_WAIVED owes no repair
# record) -- except two. The --series stall run is BROKEN by a FAIL_WAIVED pass whose waiver
# RESOLVES through `validate-suppression-lifetime.sh --waivers` by Check 26's own join
# (`waiver_covers`), not cite-verified there; a later FAIL then starts a new run from 1. A
# FAIL_WAIVED whose waiver does not resolve, or that cannot be resolved for want of the sibling or
# the escalations file, continues the run as FAIL. And the
# carve-out, which lets it pass only when the waiver resolves through
# `validate-suppression-lifetime.sh --waivers` to an OVERRIDDEN entry, or to an in-force
# SUPPRESSED entry naming this check, and that entry's citation verifies by the same loop the
# SUPPRESSED rows take. THE WAIVER IS SPRINT-SCOPED: the waiving entry's header must carry the
# verdict's sprint as `S<N>` (the verdict's sprint is the `s<N>` of its gate_series_id), so an
# entry left in pending.md by an earlier sprint, or one whose header names no sprint, waives
# nothing. The join runs here, not in the sibling's --waivers, which stays unchanged for its
# only other reader. MID-PULL, MEASURED on the ea44b9bde engine with a seeded FAIL_WAIVED row:
# this validator refused it at the enum arm (exit 1), `--series` did not count it toward a stall
# (it fired the repair-record arm instead, reading FAIL -> FAIL_WAIVED as a repair), and
# validate-suppression-lifetime.sh read it as clean in both its terminal and its expiry arm (exit
# 0 where the plain-FAIL control exits 1), which is no worse than the PASS the same gate records
# today. A consumer that DEFERs the engine but merges the rulebook writes FAIL_WAIVED into that
# old enum arm, so every waived gate blocks there: it fails closed.
#
# THE COVERAGE MODE (--coverage). WHAT IT IS FOR: the gate-adjudicator runs it on the verdict
# it just wrote, before returning the path, so a coverage gap costs a same-dispatch fix
# instead of a full re-dispatch. There is no partial re-adjudication to fall back on — a gap
# found by the lead's run above throws the whole dispatch away — and the gap the motivating
# case produced was a dropped `adjudication: llm` check that ALSO carries `enforcer:` scripts,
# which the adjudicator read as already decided by the lead's script arm.
#
# IT IS THE SAME PROGRAM, NOT A SECOND ONE. It runs the same envelope arms and calls the same
# `coverage_arms()` the adjudicate mode calls, so the derivation (`escalated_for`) and every
# `block()` message are one text. A mode with its own grammar would drift tighter or looser
# than the gate that actually decides, and the adjudicator would be self-checking against a
# rule the lead does not apply.
#
# WHAT IT DOES NOT CHECK, and the adjudicator is told so where it is told to run it: the
# DISPATCH BINDING, the SUPPRESSED carve-out, and whether any per-check verdict is FAIL. A
# legitimate all-FAIL verdict exits 0 here. This mode answers one question — is this verdict
# shaped right and does it cover exactly the derived set — and the lead's full run still
# decides the gate.
#
# THE BINDING ARM IS EXCLUDED BECAUSE NO EDIT TO A VERDICT CAN SATISFY IT. It asks whether a
# dispatch produced this file and whether that dispatch postdates the nonce, from records the
# adjudicator does not write; its remedy is "re-run the gate", not "fix this file". An exit 1
# an adjudicator cannot clear is an instruction to keep editing a correct file.
#
# AND IT MASKS THE DEFECT THIS MODE EXISTS TO FIND, which is the stronger reason. Measured
# over the reference consumer's 197 verdict files by the arm each block NAMES, not by its exit
# code — 157 blocked, of which 94 envelope, 39 per-check FAIL, 13 binding, 10 coverage, 1
# nonce/stem. Of the 13 binding blocks, FOUR carry a coverage defect underneath it that the
# full mode never reaches and never prints: three `implementation` verdicts naming a `2a` that
# is not in the escalated set, and one `sprint-review` short of check `20`. This mode reports
# all four. A verdict is short and unbound at the same time more often than either alone,
# because both are what a hand-assembled verdict looks like.
#
# THE NONCE/STEM ARM RUNS BEFORE THE COVERAGE JOIN, and it is the reason the PASS line names
# the path. The mode is handed a path and cannot know which file its caller wrote, so an
# adjudicator that self-checks the wrong verdict gets an answer about the wrong verdict. What
# the mode can establish is that the file it read carries the nonce its own filename claims —
# so the path in the PASS line IS the nonce that was checked, and a lead holding the dispatch's
# nonce can read one against the other. The role file closes the rest by naming the path
# verbatim.
#
# SHARDING (--expected --shard, --merge). One adjudicator judging the whole worklist is the
# gate's longest serial step. A sharded gate dispatches N adjudicators under ONE nonce; each
# derives its own slice with --shard, so no shard is handed a list someone typed, and writes
#   <gate_nonce>.part-<i>of<N>.jsonl
# beside the verdict path — one JSON object per line, per check judged, carrying the v1
# per-check fields (check_id, verdict, evidence) plus gate_nonce, gate_series_id, catalog and
# adjudicator_agent_id. The extension is `.jsonl` BECAUSE --series walks this directory
# recursively and exits 2 on any `.json` that is not a verdict. The lead then runs --merge,
# which writes the single v1 verdict every reader already reads — the schema, the path and
# Check 26 are unchanged — and refuses rather than writes on an incomplete or overlapping
# union, since a merge that accepts a short union reads exactly like a passing gate. The
# merged adjudicator_agent_id lists every shard's id -- DERIVED from the part's content seal where it
# carries one (THE CONTENT SEAL, at the merge) -- and its generated_at is the merge time.
# No write-ledger row is ever produced for a merged file, so it binds through the spawn
# ledger's dispatch window alone.
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
#        unreadable --series path, unparseable verdict under --series), or a `REFUSED:` shard
#        spec, merge or part
#
# The lead runs the adjudicate form through verdict.sh so the exit code is not swallowed by a
# pipe. Compatible with bash 3.2+ and Python 3 stdlib (no PyYAML — the map is regex-parsed).

set -u

MODE=""
GATE_TYPE=""
VERDICT_PATH=""
SERIES_PATHS=()
MERGE_PARTS=()
GA_SHARD=""

case "${1:-}" in
    --expected)
        MODE="expected"
        GATE_TYPE="${2:-}"
        if [ -z "$GATE_TYPE" ]; then
            echo "usage: $0 --expected <gate_type> [--shard <i>/<N>]" >&2
            exit 2
        fi
        if [ "$#" -gt 2 ]; then
            # `--shard` is the ONLY word accepted after the gate type. An unknown one used to be
            # ignored, and a mistyped shard flag then printed the WHOLE worklist to every shard.
            if [ "${3:-}" != "--shard" ] || [ "$#" -ne 4 ] || [ -z "${4:-}" ]; then
                echo "usage: $0 --expected <gate_type> [--shard <i>/<N>]" >&2
                exit 2
            fi
            GA_SHARD="$4"
        fi
        ;;
    --merge)
        MODE="merge"
        GATE_TYPE="${2:-}"
        VERDICT_PATH="${3:-}"
        if [ -z "$GATE_TYPE" ] || [ -z "$VERDICT_PATH" ] || [ "$#" -lt 4 ]; then
            echo "usage: $0 --merge <gate_type> <verdict_path> <part>..." >&2
            exit 2
        fi
        shift 3
        MERGE_PARTS=("$@")
        ;;
    --check-part)
        # FIXED ARITY: the part line's key set comes from the schema's `verdicts` item_fields,
        # which do not vary by gate type, and the part's nonce is its own filename's stem.
        MODE="check-part"
        if [ "$#" -ne 2 ] || [ -z "${2:-}" ]; then
            echo "usage: $0 --check-part <part>" >&2
            exit 2
        fi
        MERGE_PARTS=("$2")
        ;;
    --coverage)
        MODE="coverage"
        GATE_TYPE="${2:-}"
        VERDICT_PATH="${3:-}"
        if [ -z "$GATE_TYPE" ] || [ -z "$VERDICT_PATH" ]; then
            echo "usage: $0 --coverage <gate_type> <verdict_path>" >&2
            exit 2
        fi
        if [ "$#" -gt 3 ]; then
            # No transcript flags here: this mode reads no transcript, because the only arm
            # that would consume one is the SUPPRESSED carve-out, which it does not run.
            echo "ERROR: unknown argument: $4" >&2
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
        echo "       $0 --expected <gate_type> --shard <i>/<N>" >&2
        echo "       $0 --merge <gate_type> <verdict_path> <part>..." >&2
        echo "       $0 --check-part <part>" >&2
        echo "       $0 --coverage <gate_type> <verdict_path>" >&2
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
            echo "usage: $0 <gate_type> <verdict_path> [--transcript PATH] [--transcript-dir DIR]" >&2
            exit 2
        fi
        ;;
esac

# --- the transcript corpus (adjudicate mode) ---------------------------------------------
# The SUPPRESSED carve-out below verifies each in-force entry's operator citation against a
# transcript corpus, and this is the only channel by which the caller can name one. The
# directory is the corpus the citation actually lives in and takes precedence over the single
# file, for the reason validate-escalation-resolution.sh's header gives: an operator authorizes
# a suppression in one session and the gate that leans on it runs in another, so the calling
# session's own `transcript_path` is never the file the words are in. Neither flag is required
# by the parser; what the carve-out does when neither resolves is stated where it is asked.
TRANSCRIPT=""
TRANSCRIPT_DIR=""
if [ "$MODE" = "adjudicate" ]; then
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --transcript)
                [ "$#" -ge 2 ] || { echo "usage: $0 <gate_type> <verdict_path> [--transcript PATH] [--transcript-dir DIR]" >&2; exit 2; }
                TRANSCRIPT="$2"; shift 2 ;;
            --transcript-dir)
                [ "$#" -ge 2 ] || { echo "usage: $0 <gate_type> <verdict_path> [--transcript PATH] [--transcript-dir DIR]" >&2; exit 2; }
                TRANSCRIPT_DIR="$2"; shift 2 ;;
            *)
                echo "ERROR: unknown argument: $1" >&2
                exit 2 ;;
        esac
    done
fi

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

# The INSTALL root, walked up from this script's own directory, is the LAST candidate for both
# the schema and enforcement-map.yaml: in the consumer layout the script-relative ones sit under
# scripts/, where neither exists, so an override naming a root with no .claude/ copy failed closed
# (BL-300). Last, as in BL-299's pair, so a root carrying its own copy still wins. An empty walk
# adds no candidate.
GA_INSTALL_ROOT="$(ai_dlc_resolve_root "$GA_SCRIPT_DIR" || true)"
GA_INSTALL_SCHEMA=""
GA_INSTALL_MAP=""
if [ -n "$GA_INSTALL_ROOT" ]; then
    GA_INSTALL_SCHEMA="$GA_INSTALL_ROOT/.claude/schemas/gate-adjudication-verdict.json"
    GA_INSTALL_MAP="$GA_INSTALL_ROOT/.claude/skills/ai-dlc/enforcement-map.yaml"
fi

SCHEMA="${AI_DLC_VERDICT_SCHEMA:-}"
if [ -z "$SCHEMA" ]; then
    for cand in \
        "$GA_ROOT/core/schemas/gate-adjudication-verdict.json" \
        "$GA_ROOT/.claude/schemas/gate-adjudication-verdict.json" \
        "$GA_SCRIPT_DIR/../schemas/gate-adjudication-verdict.json" \
        "$GA_INSTALL_SCHEMA"; do
        [ -n "$cand" ] && [ -f "$cand" ] && { SCHEMA="$cand"; break; }
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
# THE ESCALATIONS COME FROM THE TREE THE MAP CAME FROM (BL-326). The escalated set is derived from
# the map and the suppression join pairs it with that tree's `docs/escalations/pending.md`; a map
# taken from the install while the escalations were read from a foreign root joined one tree's
# escalated set to another tree's suppressions. So the root the map resolved under is recorded
# beside it: the root's own two candidates keep GA_ROOT, and the script-relative and install
# candidates — both the package this copy shipped in — move it to the install root. An explicit
# AI_DLC_ENFORCEMENT_MAP names no tree, so it keeps GA_ROOT, as AI_DLC_ESCALATIONS still wins.
GA_MAP_ROOT="$GA_ROOT"
if [ -z "$MAP" ]; then
    for cand in \
        "$GA_ROOT/core/skills/ai-dlc/enforcement-map.yaml" \
        "$GA_ROOT/.claude/skills/ai-dlc/enforcement-map.yaml" \
        "$GA_SCRIPT_DIR/../skills/ai-dlc/enforcement-map.yaml" \
        "$GA_INSTALL_MAP"; do
        [ -n "$cand" ] && [ -f "$cand" ] && { MAP="$cand"; break; }
    done
    case "$MAP" in
        "$GA_ROOT/core/skills/ai-dlc/enforcement-map.yaml"|"$GA_ROOT/.claude/skills/ai-dlc/enforcement-map.yaml") ;;
        ?*) [ -n "$GA_INSTALL_ROOT" ] && GA_MAP_ROOT="$GA_INSTALL_ROOT" ;;
    esac
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

# A DIRECTORY IS NOT A CORPUS. `-d` answers whether the path EXISTS, never whether it holds
# any ground truth. The corpus reader selects `*.jsonl` (`validate-steering-budget.sh:427`),
# so a directory holding only sidecar files is exactly as blind as an empty one and this counts
# what that reader would count. This predicate is byte-identical in
# `core/scripts/validate-adversarial-convergence.sh`,
# `core/scripts/validate-escalation-resolution.sh` and
# `core/hooks/ai-dlc-gate-remediation-guard.sh`; invariant I92 holds the four copies to one
# text and refuses a fifth.
steer_dir_has_transcript() { # $1 dir -> 0 if it holds a readable *.jsonl
  [ -n "${1:-}" ] && [ -d "$1" ] || return 1
  for _sdht in "$1"/*.jsonl; do
    [ -r "$_sdht" ] && return 0
  done
  return 1
}

# THE CITED SUBSTRING IS A FIELD, NOT A LINE. These two are byte-identical in
# `core/scripts/validate-escalation-resolution.sh`,
# `core/scripts/validate-adversarial-convergence.sh` and
# `core/hooks/ai-dlc-gate-remediation-guard.sh`; invariant I103 holds the four copies to one
# text and refuses a fifth. Read the escalation validator's header for the measurement behind
# the segment split.
cite_segments() { # $1 authline -> one quoted segment per line
  printf '%s\n' "$1" | LC_ALL=C awk '
    { n = split($0, p, /"/)
      # split on `"` yields quotecount+1 fields, and the inside-quote ones are the EVEN
      # indices. An odd quote count leaves the final field unterminated; it is even-indexed
      # too, so one loop covers both shapes.
      for (i = 2; i <= n; i += 2) if (p[i] != "") print p[i] }'
}

# The quote as `validate-steering-budget.sh --cite` measures it: every run of ECMAScript `\s`
# whitespace one space, the ends trimmed. The 12-character floor is measured on THIS, never on
# the raw bytes -- a raw `${#quote}` scored `"          yes"` as 13 and twelve spaces as 12, and
# the predicate then matched 3 characters and the empty string against any operator turn. The
# predicate owns the floor and refuses a short needle itself (NOMATCH-SHORT); a caller's check
# is the message, and for `--any-authorized`, which never calls the predicate, the whole check.
#
# THE SET IS NODE'S, RENDERED AS UTF-8 BYTE SEQUENCES, because bash cannot run the predicate's
# regex without a node fork per segment and `[[:space:]]` under LC_ALL=C is ASCII only: an NBSP-
# or U+2000-padded `yes` counted AUTHORIZED. The non-ASCII members are U+00A0, U+1680,
# U+2000-U+200A, U+2028, U+2029, U+202F, U+205F, U+3000 and U+FEFF. Invariant I120 derives the
# set from node and drives this body against every member and against the near-misses node
# excludes (U+0085, U+180E, U+200B), so the rendering cannot drift from the definition silently.
cite_norm() { # $1 text -> ECMAScript-\s runs collapsed to one space, ends trimmed
  printf '%s' "$1" | LC_ALL=C awk '
    { s = s (NR > 1 ? " " : "") $0 }
    END {
      gsub("\302\240|\341\232\200|\342\200[\200-\212]|\342\200\250|\342\200\251|\342\200\257|\342\201\237|\343\200\200|\357\273\277", " ", s)
      gsub("[ \t\013\014\015]+", " ", s)
      sub("^ ", "", s); sub(" $", "", s)
      printf "%s", s }'
}

# The length the predicate's floor reads: UTF-16 code units, which is JavaScript's `.length`.
# `${#}` is neither -- bytes under LC_ALL=C, characters under a UTF-8 locale -- so a six-letter
# accented quote was 12 to one caller and 6 to the predicate. Every byte that is not a UTF-8
# continuation byte starts one character, and a four-byte lead starts one that JS counts twice.
cite_nlen() { # $1 text -> length in UTF-16 code units
  _cn_c="$(printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c)"
  _cn_a="$(printf '%s' "$1" | LC_ALL=C tr -cd '\360-\367' | wc -c)"
  printf '%s' "$((_cn_c + _cn_a))"
}

cite_quote() { # $1 authline
  _cq_segs="$(cite_segments "$1")"
  [ -n "$_cq_segs" ] || _cq_segs="$(printf '%s' "${1#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  _cq_pick=""
  _cq_long=""
  while IFS= read -r _cq_seg; do
    [ "${#_cq_seg}" -gt "${#_cq_long}" ] && _cq_long="$_cq_seg"
    _cq_n="$(cite_nlen "$(cite_norm "$_cq_seg")")"
    [ "$_cq_n" -ge 12 ] || continue
    [ -n "$_cq_pick" ] || _cq_pick="$_cq_seg"
  done <<CITEEOF
$_cq_segs
CITEEOF
  # Nothing verifiable. Name the LONGEST segment anyway, so the "too short" message quotes
  # something the reader can find in the file instead of a fragment between two quotes.
  [ -n "$_cq_pick" ] || _cq_pick="$_cq_long"
  printf '%s' "$_cq_pick"
}

# The citation's own TIMESTAMP -- the `<ISO ts>` half of `<ISO ts> | "<verbatim quote>"`, which
# is what says WHEN the record claims the operator spoke. Without it the --cite corpus is the
# project's entire session history, and any twelve-character phrase the operator ever typed
# verifies a citation filed today; the sibling prints `MATCH <ts>` and every caller sent it to
# /dev/null, so the one output that could have refuted the claim was the one nobody read.
# Callers pass it as `--authorized-at`, and the sibling owns the tolerance.
#
# EMPTY WHEN THE FIELD CARRIES NO PARSEABLE TIMESTAMP, and the caller then passes no bound and
# gets the unbounded answer. The grammar of this field is enforced elsewhere and not every
# producer requires the timestamp -- on the reference consumer 1 of 26 authorization rows is
# written `2026-08-26, this session, verbatim: "..."` and cites a real operator turn. Refusing
# that row here would fail a genuine citation for a reason that is not about whether the
# operator spoke, which is a check that wedges live work.
cite_ts() { # $1 authline
  printf '%s\n' "$1" | LC_ALL=C awk '
    got { next }
    { if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?/)) {
        printf "%s", substr($0, RSTART, RLENGTH); got = 1 } }'
}

# --- the SUPPRESSED carve-out: asked of the script that OWNS "in force", never restated ---
# escalations.md defines SUPPRESSED as an authorization to proceed past a failing check, with
# a lifetime, and Check 2 says such an entry does not block while in force. Every
# `adjudication: llm` check is adopted through THIS script, so without this join a
# suppression could cover a lead-evaluated check and never an escalated one — measured on the
# reference consumer: a well-formed, in-force entry naming `[core] 16` and the gate still
# exiting 1 on that FAIL. The predicate (well-formed, catalog-known, within lifetime) lives in
# validate-suppression-lifetime.sh --in-force; this script consumes its rows and joins them on
# (catalog, check_id) against the verdict's own `catalog` field. FAIL-CLOSED on every
# absence: no escalations file, no sibling, or a sibling refusal all mean NO carve-out and the
# FAIL blocks exactly as before, with the reason printed beside the block.
GA_IN_FORCE=""
GA_IN_FORCE_STATUS="not-asked"
GA_UNVERIFIED_CITES=0
GA_VERIFIER_ERRORS=0
# ROWS VERIFIED WITH NO TIMESTAMP BOUND. `cite_ts` requires `T` between the date and the time,
# so a space, a lowercase `t` or a date-only value yields no bound and the row is verified
# against the project's whole session history -- an unbounded pass that reads byte-identically
# to a bounded one. On THIS path that count is held at zero by a DIFFERENT PROGRAM:
# `validate-suppression-lifetime.sh` refuses a SUPPRESSED entry whose `**Operator
# authorization:**` line carries no `<date>T<time>` as malformed, so a non-canonical row is
# never listed in force and never reaches the verifier here. The count is printed anyway,
# because that zero is a property of the sibling's shape guard and not of this file: if that
# guard ever widens, this number moves instead of the bound disappearing in silence.
GA_UNBOUNDED_CITES=0
if [ "$MODE" = "adjudicate" ]; then
    ESC="${AI_DLC_ESCALATIONS:-$GA_MAP_ROOT/docs/escalations/pending.md}"
    # The sibling is named IN FULL at its call sites below, never through a variable holding
    # the whole path: I107 in scripts/validate-enforcement-map.sh joins the mode spelled here
    # to the mode the sibling dispatches, and it reads the literal beside the basename.
    SUPP_DIR=""
    for cand in "$GA_SCRIPT_DIR" "$GA_ROOT/core/scripts" "$GA_ROOT/scripts/ai-dlc"; do
        [ -f "$cand/validate-suppression-lifetime.sh" ] && { SUPP_DIR="$cand"; break; }
    done
    # A verdict carrying no FAIL has nothing to cover, so the sibling's parse of the whole
    # escalations file (hundreds of KB on the reference consumer) is skipped on the common
    # all-PASS gate. The token test is a superset of the JSON test: any FAIL verdict carries
    # the string, and a false hit only costs the parse. An absent verdict falls through to
    # the python block's own exit 2.
    # FAIL_WAIVED needs the escalations parse too (its waiver is verified below), and `"FAIL"`
    # does not match it, so the token test is widened rather than added beside.
    if [ ! -f "$VERDICT_PATH" ] || ! grep -qE '"FAIL(_WAIVED)?"' "$VERDICT_PATH"; then
        GA_IN_FORCE_STATUS="not-needed:no FAIL token in the verdict"
    elif [ ! -f "$ESC" ]; then
        GA_IN_FORCE_STATUS="no-escalations-file:$ESC"
    elif [ -z "$SUPP_DIR" ]; then
        GA_IN_FORCE_STATUS="no-sibling:validate-suppression-lifetime.sh not found beside $GA_SCRIPT_DIR"
    else
        # AI_DLC_GATE_METRICS is the fixture's channel; a live gate lets the sibling locate
        # the timeline itself. It resolves that under ITS root, which is this script's root
        # (same directory, same walk-up, same inherited AI_DLC_PROJECT_ROOT), and never under
        # the cwd the lead ran verdict.sh in.
        if [ -n "${AI_DLC_GATE_METRICS:-}" ]; then
            GA_IN_FORCE="$(bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
                --escalations "$ESC" --enforcement-map "$MAP" --gate-metrics "$AI_DLC_GATE_METRICS")"
        else
            GA_IN_FORCE="$(bash "$SUPP_DIR/validate-suppression-lifetime.sh" --in-force \
                --escalations "$ESC" --enforcement-map "$MAP")"
        fi
        supp_rc=$?
        # THE WAIVING ENTRIES, asked of the same owner. A FAIL_WAIVED verdict's waiver_id must name
        # one of these rows, and each row's citation is verified by the SAME loop below as the
        # in-force rows: the rows are tagged `waiver:` in their first field, which no catalog is
        # spelled with, verified together, and split apart after. Asked only when the verdict
        # carries the token; a refusal here is a refusal of the whole carve-out, as above.
        GA_WAIVER_ROWS=""
        if [ "$supp_rc" -eq 0 ] && grep -qF '"FAIL_WAIVED"' "$VERDICT_PATH"; then
            if [ -n "${AI_DLC_GATE_METRICS:-}" ]; then
                GA_WAIVER_ROWS="$(bash "$SUPP_DIR/validate-suppression-lifetime.sh" --waivers \
                    --escalations "$ESC" --enforcement-map "$MAP" --gate-metrics "$AI_DLC_GATE_METRICS")"
            else
                GA_WAIVER_ROWS="$(bash "$SUPP_DIR/validate-suppression-lifetime.sh" --waivers \
                    --escalations "$ESC" --enforcement-map "$MAP")"
            fi
            supp_rc=$?
            if [ -n "$GA_WAIVER_ROWS" ]; then
                GA_IN_FORCE="${GA_IN_FORCE}${GA_IN_FORCE:+
}$(printf '%s\n' "$GA_WAIVER_ROWS" | sed 's/^/waiver:/')"
            fi
        fi
        if [ "$supp_rc" -eq 0 ]; then
            GA_IN_FORCE_STATUS="ok:$ESC"
            # --- THE CITATION IS VERIFIED BEFORE A ROW CAN COVER ANYTHING -------------------
            # Each row's fifth field is the entry's `**Operator authorization:**` line,
            # forwarded verbatim by the sibling. The sibling checks that the line carries a
            # timestamp and a quote; it does not decide whether the words were said, and
            # until this block existed nothing here did either — the field was read and
            # discarded, so a lead could write its own gate passage into pending.md and this
            # validator adopted it. Measured on the shipped fixture seed: a well-formed
            # in-force entry with no transcript corpus anywhere exited 0 with the SUPPRESSED
            # line. The predicate is the one `ai-dlc-gate-remediation-guard.sh` arm 7b already
            # applies to the SAME rows: `validate-steering-budget.sh --cite`, THE
            # genuine-operator predicate, over the corpus the caller named above. FAIL-CLOSED
            # on every absence, exactly as the escalations file is: no corpus, no verifier, a
            # quote too short to be evidence, or a quote no genuine operator turn carries all
            # mean that row suppresses NOTHING, and the block names which. Rows are only ever
            # NARROWED here; a row that verifies is kept and one that does not is dropped and
            # counted, so a forged entry beside a genuine one costs the genuine one nothing.
            if [ -n "$GA_IN_FORCE" ]; then
                STEER_SCRIPT="$GA_SCRIPT_DIR/validate-steering-budget.sh"
                STEER_FLAG=""; STEER_ARG=""
                if steer_dir_has_transcript "$TRANSCRIPT_DIR"; then
                    STEER_FLAG="--dir"; STEER_ARG="$TRANSCRIPT_DIR"
                elif [ -n "$TRANSCRIPT" ] && steer_dir_has_transcript "$(dirname "$TRANSCRIPT")"; then
                    # THE DIRECTORY, for the guard's reason (ai-dlc-gate-remediation-guard.sh
                    # arm 7b widens the session transcript it is handed the same way): an
                    # operator authorizes a suppression in one session and the gate that leans
                    # on it runs in another, so the calling session's own file is never the one
                    # the words are in. Measured: given only the current session's file, the
                    # single-file scan read NOMATCH on an entry the guard had just accepted from
                    # the sibling file. The two readers of these rows scan the same corpus from
                    # the same argument, or they disagree about the same entry.
                    STEER_FLAG="--dir"; STEER_ARG="$(dirname "$TRANSCRIPT")"
                elif [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
                    STEER_FLAG="--transcript"; STEER_ARG="$TRANSCRIPT"
                fi
                if [ -z "$STEER_FLAG" ]; then
                    GA_IN_FORCE=""
                    GA_IN_FORCE_STATUS="no-transcript:no readable transcript corpus was given (--transcript-dir '${TRANSCRIPT_DIR:-unset}' holds no *.jsonl; --transcript '${TRANSCRIPT:-unset}' is not a readable file), so no operator citation can be verified and no in-force entry covers anything"
                elif [ ! -f "$STEER_SCRIPT" ]; then
                    GA_IN_FORCE=""
                    GA_IN_FORCE_STATUS="no-verifier:$STEER_SCRIPT is missing, so no operator citation can be verified and no in-force entry covers anything. Reinstall ai-dlc."
                else
                    GA_VERIFIED=""
                    while IFS= read -r ga_row; do
                        [ -n "$ga_row" ] || continue
                        # `awk -F'\t'` and not `IFS`+`read`: TAB is IFS-whitespace, so a shell
                        # read collapses the empty leading field a bare-catalog row carries.
                        # A line with fewer than six fields is NOT a row — the python reader
                        # below skips it on the same count — so it is neither verified nor
                        # counted as unverified: a stray line is not a citation that failed.
                        ga_nf="$(printf '%s' "$ga_row" | LC_ALL=C awk -F'\t' '{ print NF }')"
                        [ "${ga_nf:-0}" -ge 6 ] || continue
                        ga_auth="$(printf '%s' "$ga_row" | LC_ALL=C awk -F'\t' '{ print $5 }')"
                        ga_quote="$(cite_quote "$ga_auth")"
                        ga_header="$(printf '%s' "$ga_row" | cut -f6-)"
                        case "$ga_row" in
                            waiver:*) ga_kind="a waiving escalation entry" ;;
                            *)        ga_kind="an in-force SUPPRESSED entry" ;;
                        esac
                        # Measured after whitespace is collapsed and trimmed, as --cite matches it.
                        ga_nquote="$(cite_norm "$ga_quote")"
                        if [ "$(cite_nlen "$ga_nquote")" -lt 12 ]; then
                            GA_UNVERIFIED_CITES=$((GA_UNVERIFIED_CITES + 1))
                            echo "VALIDATE-GATE-ADJUDICATION: UNVERIFIED — ${ga_kind}'s operator citation is too short to be evidence (under 12 characters once whitespace is collapsed: '${ga_nquote}'), so it suppresses nothing: ${ga_header}"
                            continue
                        fi
                        # THE VERIFIER'S EXIT IS READ IN THREE TIERS, never as a boolean. 0 is
                        # MATCH; 2 is the verifier's own NOMATCH, the finding about the citation;
                        # anything else is the verifier failing before it could answer (node off
                        # PATH returns 1, measured against a control of 0 with node present). The
                        # last is a tooling failure and still covers nothing -- fail closed -- but
                        # it is reported as one, because printing it as forgery accuses the
                        # operator's own authorization of being invented, which is the reading
                        # validate-escalation-resolution.sh and the convergence validator both
                        # refuse to make on the same status.
                        # BOUND THE SCAN TO WHEN THE ENTRY SAYS THE OPERATOR SPOKE.
                        # Unbounded, the corpus is the project's entire session history
                        # and any phrase the operator ever typed verifies a suppression
                        # filed today. `cite_ts` is empty for a field with no parseable
                        # timestamp and the bound is then omitted -- though a SUPPRESSED
                        # entry cannot reach here in that state: the sibling that produced
                        # this row refuses one with no `**Operator authorization:**`
                        # timestamp as malformed and never lists it in force.
                        # Passed unconditionally, empty meaning no bound, so the
                        # literal sits on the invocation where **I109** joins it
                        # to `--cite`.
                        ga_ts="$(cite_ts "$ga_auth")"
                        bash "$STEER_SCRIPT" "$STEER_FLAG" "$STEER_ARG" --cite "$ga_quote" --authorized-at "$ga_ts" --quiet >/dev/null 2>&1
                        ga_rc=$?
                        if [ "$ga_rc" -eq 0 ]; then
                            [ -n "$ga_ts" ] || GA_UNBOUNDED_CITES=$((GA_UNBOUNDED_CITES + 1))
                            GA_VERIFIED="${GA_VERIFIED}${ga_row}
"
                        elif [ "$ga_rc" -eq 2 ]; then
                            GA_UNVERIFIED_CITES=$((GA_UNVERIFIED_CITES + 1))
                            echo "VALIDATE-GATE-ADJUDICATION: UNVERIFIED — ${ga_kind} cites an operator message that no genuine operator turn in ${STEER_ARG} carries${ga_ts:+ within the tolerance of its own authorization time ${ga_ts}}, so it suppresses nothing: ${ga_header}"
                        else
                            GA_VERIFIER_ERRORS=$((GA_VERIFIER_ERRORS + 1))
                            echo "VALIDATE-GATE-ADJUDICATION: UNVERIFIABLE — the citation verifier failed (validate-steering-budget.sh rc=${ga_rc}) before it could say whether a genuine operator turn carries this entry's quote, so the entry suppresses nothing until it can be verified. This is a tooling failure, not a finding about the citation (is node on PATH?): ${ga_header}"
                        fi
                    done <<GAROWEOF
$GA_IN_FORCE
GAROWEOF
                    GA_IN_FORCE="$GA_VERIFIED"
                fi
            fi
        else
            GA_IN_FORCE=""
            GA_IN_FORCE_STATUS="refused:validate-suppression-lifetime.sh --in-force or --waivers exited $supp_rc"
        fi
    fi
fi
# --- THE WAIVING ENTRIES FOR THE STALL RUNG (--series) ------------------------------------------
# A FAIL_WAIVED breaks its check's stall run only under a waiver that resolves (run_series, by
# `waiver_covers`). The rows come from the same owner Check 26 asks, and are NOT cite-verified
# here: citation verification is Check 26's and the guard's. Asked only when a verdict in scope
# carries the token, so a series with no FAIL_WAIVED makes no sibling call. FAIL CLOSED: no
# escalations file, no sibling, or a sibling exit other than 0 lists no waiver, and every
# FAIL_WAIVED then continues its run as a FAIL.
GA_SERIES_WAIVERS=""
if [ "$MODE" = "series" ] && grep -rqF '"FAIL_WAIVED"' -- "${SERIES_PATHS[@]}" 2>/dev/null; then
    # The escalations path Check 26 reads (`ESC=` above, BL-326), spelled with a default on its own
    # line so the two assignments are not one literal.
    S_ESC="${AI_DLC_ESCALATIONS:-}"
    [ -n "$S_ESC" ] || S_ESC="$GA_MAP_ROOT/docs/escalations/pending.md"
    S_SUPP=""
    for cand in "$GA_SCRIPT_DIR" "$GA_ROOT/core/scripts" "$GA_ROOT/scripts/ai-dlc"; do
        [ -f "$cand/validate-suppression-lifetime.sh" ] && { S_SUPP="$cand"; break; }
    done
    S_STATUS=""
    if [ ! -f "$S_ESC" ]; then
        S_STATUS="no escalations file at $S_ESC"
    elif [ -z "$S_SUPP" ]; then
        S_STATUS="validate-suppression-lifetime.sh not found beside $GA_SCRIPT_DIR"
    else
        if [ -n "${AI_DLC_GATE_METRICS:-}" ]; then
            GA_SERIES_WAIVERS="$(bash "$S_SUPP/validate-suppression-lifetime.sh" --waivers \
                --escalations "$S_ESC" --enforcement-map "$MAP" --gate-metrics "$AI_DLC_GATE_METRICS" 2>/dev/null)"
        else
            GA_SERIES_WAIVERS="$(bash "$S_SUPP/validate-suppression-lifetime.sh" --waivers \
                --escalations "$S_ESC" --enforcement-map "$MAP" 2>/dev/null)"
        fi
        s_rc=$?
        if [ "$s_rc" -ne 0 ]; then
            GA_SERIES_WAIVERS=""
            S_STATUS="validate-suppression-lifetime.sh --waivers exited $s_rc"
        fi
    fi
    [ -z "$S_STATUS" ] || echo "VALIDATE-GATE-ADJUDICATION: NOTE (--series) — no waiver could be resolved (${S_STATUS}), so every FAIL_WAIVED in scope counts as FAIL in its stall run." >&2
fi
export GA_SERIES_WAIVERS
# Split the verified rows back apart. A waiver row never reaches the in-force reader, whose
# dict would otherwise absorb any six-field row as a suppression of its third field.
GA_WAIVERS="$(printf '%s\n' "$GA_IN_FORCE" | sed -n 's/^waiver://p')"
GA_IN_FORCE="$(printf '%s\n' "$GA_IN_FORCE" | grep -v '^waiver:')"
export GA_IN_FORCE GA_IN_FORCE_STATUS GA_UNVERIFIED_CITES GA_VERIFIER_ERRORS GA_UNBOUNDED_CITES GA_WAIVERS
export GA_SHARD
# The content seal (--merge only): the sibling that owns the sealed set and the comparison. Empty when absent; the merge then refuses
# only a ledger that carries seal rows it cannot compare.
GA_SEAL=""
[ -f "$GA_SCRIPT_DIR/content-seal.sh" ] && GA_SEAL="$GA_SCRIPT_DIR/content-seal.sh"
export GA_SEAL

# At most one of the two arrays is non-empty, and each is read only by its own mode.
# Every decision is in gate_adjudication.py beside this script (its own header says what it owns).
# stdin is /dev/null, as it was when the program arrived as a heredoc on `python3 -`: the children
# it spawns (content-seal.sh) never inherit the caller's stdin.
python3 "$GA_SCRIPT_DIR/gate_adjudication.py" "$MODE" "$GATE_TYPE" "$VERDICT_PATH" "$SCHEMA" "$MAP" "$SIBLING" ${SERIES_PATHS+"${SERIES_PATHS[@]}"} ${MERGE_PARTS+"${MERGE_PARTS[@]}"} </dev/null
