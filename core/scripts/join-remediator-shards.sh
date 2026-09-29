#!/bin/bash
#
# join-remediator-shards.sh -- the deterministic JOIN for a sharded adversarial repair.
#
# A repair pass may be split across several remediators only on DISJOINT FILE SETS, edited in
# place. This script is what makes that disjointness a measured fact rather than a promise in a
# dispatch brief: it reads the planning-artifact write ledger that
# `ai-dlc-gate-remediation-guard.sh` appends on every dispatched agent's Edit/Write/MultiEdit
# (`<state>/planning-artifacts/.artifact-writes.jsonl`, rows `kind: "artifact-write"`), and it
# REFUSES when any file under the artifact was written by more than one distinct `agent_id`
# inside the repair window. Only then does it concatenate the shard repair records into the one
# record every existing reader globs for.
#
# USAGE
#   join-remediator-shards.sh --sprint <N> --artifact <name> --pass <M> \
#       --artifact-path <path under the project root> --since <ISO> --until <ISO>
#
#   --artifact        the artifact NAME, as in `<artifact>-repair-p<M>.md` (e.g. `stories`)
#   --artifact-path   the file or directory under repair, relative to the project root, in the
#                     ledger's own spelling (`_bmad-output/planning-artifacts/s172/stories`)
#   --since/--until   the repair window, `YYYY-MM-DDTHH:MM:SSZ`, inclusive both ends. Explicit
#                     and required: an mtime or a "last N minutes" default is a window the
#                     filesystem or the clock can move.
#
# READS   <state>/planning-artifacts/.artifact-writes.jsonl
#         <state>/planning-artifacts/s<N>/shards/<artifact>-p<M>/*.md   (placement rule P1)
# WRITES  <state>/planning-artifacts/s<N>/<artifact>-repair-p<M>.md       (placement rule P5)
#
# EXIT  0 joined; 2 REFUSED (one `REFUSED:` line on stderr per reason, nothing written).
#
# WHAT IT REFUSES, AND THE ORDER IS NOT SIGNIFICANT -- every reason is reported:
#   - an empty shard directory (a glob that matched nothing is not a join of zero parts);
#   - no ledger, or no ledger row under the artifact in the window (disjointness unproven);
#   - any file under the artifact written by two or more distinct agent_ids in the window;
#   - a part with no `remediator_agent_id:` line, or two parts naming the same agent;
#   - a WRITER with no part: an agent the ledger saw editing the artifact delivered no record
#     (the missing-shard case -- the writer set is DERIVED from the ledger, never passed in);
#   - a part that arm H would not read as structured on its own (see below);
#   - an existing `<artifact>-repair-p<M>.md` (a join never overwrites a record).
#
# "STRUCTURED IFF EVERY PART IS". Arm H of `validate-adversarial-convergence.sh` reads a record as
# structured when each of `disposition:`, `edit:`, `derivation:` opens a line ANYWHERE in it, so a
# concatenation of one structured part and one narrative part reads structured. The join therefore
# tests EVERY part and refuses if any fails, and it tests with arm H's own `repair_field()`,
# extracted from the sibling and evaluated -- the same move `check-24-adversarial-convergence` and
# `validate-gate-adjudication.sh` make -- so the predicate cannot drift from the gate's.
#
# WHAT IT CANNOT SEE. A remediator that edited nothing AND delivered no part is invisible: the
# writer set is derived from edits, and an agent with none contributes nothing to it. A part from
# an agent that wrote nothing is accepted (an all-escalated shard is legitimate). The ledger rows
# are PreToolUse attempts, not completed writes, so an attempted overlap refuses -- the
# conservative direction. Writes made through Bash reach no Edit matcher and no ledger row.
#
# NOT A MODE OF THE ADVERSARY MERGE. A separate program on purpose: the adversary-shard fix and
# this one close different backlog entries, and a shared mode would let either close both.

set -u
export LC_ALL=C

refuse_n=0
refuse() { echo "REFUSED: $*" >&2; refuse_n=$((refuse_n + 1)); }
die() { echo "REFUSED: $*" >&2; exit 2; }

SPRINT=""; ARTIFACT=""; PASS=""; APATH=""; SINCE=""; UNTIL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    --artifact) ARTIFACT="${2:-}"; shift 2 ;;
    --pass) PASS="${2:-}"; shift 2 ;;
    --artifact-path) APATH="${2:-}"; shift 2 ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --until) UNTIL="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,60p' "$0"; exit 0 ;;
    *) die "unknown argument '$1' (see --help)" ;;
  esac
done

SPRINT="${SPRINT#s}"
case "$SPRINT" in ''|*[!0-9]*) die "--sprint must be a sprint number (got '${SPRINT}')" ;; esac
case "$PASS" in ''|*[!0-9]*) die "--pass must be a pass number (got '${PASS}')" ;; esac
case "$ARTIFACT" in ''|*/*) die "--artifact must be a bare artifact name (got '${ARTIFACT}')" ;; esac
[ -n "$APATH" ] || die "--artifact-path is required"
APATH="${APATH%/}"
ISO='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'
# shellcheck disable=SC2254
case "$SINCE" in $ISO) ;; *) die "--since must be YYYY-MM-DDTHH:MM:SSZ (got '${SINCE}')" ;; esac
# shellcheck disable=SC2254
case "$UNTIL" in $ISO) ;; *) die "--until must be YYYY-MM-DDTHH:MM:SSZ (got '${UNTIL}')" ;; esac
[ "$SINCE" \> "$UNTIL" ] && die "--since ${SINCE} is after --until ${UNTIL}"
command -v jq >/dev/null 2>&1 || die "jq is not on PATH; the ledger cannot be read"

# --- AI_DLC_ROOT ------------------------------------------------------------
# Walk UP for a marker, never count `..` hops. The canonical block, precedence bound by I75:
# override -> walk up from this script -> CLAUDE_PROJECT_DIR -> walk up from cwd -> exit 2.
# Inline on purpose: locating a shared lib is the same unsolved problem.
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
JR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JR_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$JR_ROOT" ] || JR_ROOT="$(ai_dlc_resolve_root "$JR_SCRIPT_DIR" || true)"
[ -n "$JR_ROOT" ] || JR_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$JR_ROOT" ] || JR_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$JR_ROOT" ] || {
  echo "REFUSED: cannot resolve the project root from ${JR_SCRIPT_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

_STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"
case "$_STATE_DIR" in /*) STATE="$_STATE_DIR" ;; *) STATE="${JR_ROOT}/${_STATE_DIR}" ;; esac
PA="${STATE}/planning-artifacts"
LEDGER="${PA}/.artifact-writes.jsonl"
SHARD_DIR="${PA}/s${SPRINT}/shards/${ARTIFACT}-p${PASS}"
OUT="${PA}/s${SPRINT}/${ARTIFACT}-repair-p${PASS}.md"

# Arm H's own predicate, from the sibling. Same dir in both layouts (core/scripts/ and
# scripts/ai-dlc/ each hold both files), so no walk from one core file to another.
SIBLING="${JR_SCRIPT_DIR}/validate-adversarial-convergence.sh"
[ -f "$SIBLING" ] || die "arm H's validator is not beside this script (${SIBLING}); reinstall ai-dlc"
n_fn="$(grep -c '^repair_field() {' "$SIBLING")" || n_fn=0
[ "$n_fn" = "1" ] || die "found ${n_fn} 'repair_field() {' definitions in ${SIBLING} (want exactly 1)"
eval "$(grep -m1 '^repair_field() {' "$SIBLING")"

# --- the parts. A glob that matches nothing is a refusal, never a join of zero parts.
PARTS=""
for p in "$SHARD_DIR"/*.md; do
  [ -f "$p" ] || continue
  PARTS="${PARTS}${p}
"
done
PARTS="$(printf '%s' "$PARTS" | sort)"
[ -n "$PARTS" ] || die "no shard records at ${SHARD_DIR}/*.md"

# --- the ledger: per-file distinct writers inside the window, under the artifact path.
[ -f "$LEDGER" ] || die "no write ledger at ${LEDGER}; disjointness cannot be proven"
ROWS="$(jq -rn --arg since "$SINCE" --arg until "$UNTIL" --arg ap "$APATH" '
  [inputs | select(type == "object") | select(.kind == "artifact-write")
   | select((.agent_id // "") != "") | select((.ts | type) == "string")
   | select(.ts >= $since and .ts <= $until)
   | select(.path == $ap or (.path | startswith($ap + "/")))
   | [.path, .agent_id]] | unique | .[] | @tsv' "$LEDGER" 2>/dev/null)" \
  || die "the write ledger ${LEDGER} does not parse as JSON lines"
[ -n "$ROWS" ] || die "the ledger records no dispatched write under ${APATH} in [${SINCE}, ${UNTIL}]; disjointness is unproven"

OVERLAPS="$(printf '%s\n' "$ROWS" | awk -F'\t' '
  { n[$1]++; w[$1] = (w[$1] == "" ? $2 : w[$1] ", " $2) }
  END { for (f in n) if (n[f] > 1) print f "\t" w[f] }' | sort)"
if [ -n "$OVERLAPS" ]; then
  while IFS='	' read -r f w; do
    refuse "${f} was written by more than one agent in the window: ${w}"
  done <<OVEOF
$OVERLAPS
OVEOF
fi
WRITERS="$(printf '%s\n' "$ROWS" | awk -F'\t' '{print $2}' | sort -u)"

# --- each part: an agent id, unique, structured by arm H's own reading.
PART_IDS=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  rid="$(sed -n 's/^[[:space:]-]*[*_`]*remediator_agent_id[*_`]*:[[:space:]]*//p' "$p" | head -1 | sed 's/[`[:space:]]*$//')"
  if [ -z "$rid" ]; then
    refuse "$(basename "$p") carries no 'remediator_agent_id:' line; a part must name its writer"
  else
    PART_IDS="${PART_IDS}${rid}
"
  fi
  for fld in disposition edit derivation; do
    repair_field "$fld" "$p" || refuse "$(basename "$p") has no '${fld}:' field as arm H reads it; the joined record would read structured on another part's labels"
  done
done <<PAREOF
$PARTS
PAREOF

DUPS="$(printf '%s' "$PART_IDS" | sort | uniq -d)"
[ -z "$DUPS" ] || refuse "more than one part names remediator_agent_id: $(printf '%s' "$DUPS" | tr '\n' ' ')"
MISSING="$(printf '%s\n' "$WRITERS" | while IFS= read -r a; do
  [ -n "$a" ] || continue
  grep -qxF -- "$a" <<<"$PART_IDS" || printf '%s\n' "$a"
done)"
[ -z "$MISSING" ] || refuse "agent(s) the ledger saw writing under ${APATH} delivered no shard record: $(printf '%s' "$MISSING" | tr '\n' ' ')"

[ -e "$OUT" ] && refuse "${OUT} already exists; a join never overwrites a repair record"

[ "$refuse_n" -eq 0 ] || exit 2

# --- write the single record every reader globs for.
TMP="${OUT}.join.$$"
{
  echo "# ${ARTIFACT} repair — sprint ${SPRINT}, pass ${PASS} (joined from $(printf '%s\n' "$PARTS" | grep -c .) shard records)"
  echo ""
  echo "Joined by join-remediator-shards.sh from ${SHARD_DIR#"${JR_ROOT}"/}; window ${SINCE} .. ${UNTIL};"
  echo "every file under ${APATH} was written by exactly one agent in that window."
  echo ""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    echo "<!-- shard: $(basename "$p") -->"
    cat "$p"
    echo ""
  done <<CATEOF
$PARTS
CATEOF
} > "$TMP" || { echo "REFUSED: could not write ${TMP}" >&2; exit 2; }
mv "$TMP" "$OUT" || { echo "REFUSED: could not move the joined record into ${OUT}" >&2; exit 2; }
echo "JOINED: ${OUT} ($(printf '%s\n' "$PARTS" | grep -c .) parts, $(printf '%s\n' "$WRITERS" | grep -c .) writers)"
exit 0
