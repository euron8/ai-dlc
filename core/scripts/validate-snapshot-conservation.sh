#!/bin/bash
#
# AI/DLC Snapshot Eviction-Conservation Validator  (Check 35)
#
# WHAT IT ASKS. Rule 25(a) says superseded content MOVES to a history file and is
# never deleted. Every mechanism around that rule verifies the file's SIZE. Nothing
# verified the MOVE. This asks the one question the byte budget cannot: of the lines
# that left pipeline-snapshot.md since the last gate, how many now exist nowhere in
# the repository at all?
#
# WHY A SIZE CHECK CANNOT ANSWER IT. validate-artifact-budget.sh passes a snapshot
# that got smaller. Getting smaller is exactly what destruction and conservation
# have in common; the budget is satisfied identically either way. The remedy that
# shrinks the file and the remedy that preserves its content are the same remedy
# only if someone checks.
#
# WHY THE PREDICATE IS SURVIVAL AND NOT COVERAGE. The obvious join -- "deletions
# from the snapshot must be matched by additions to the history file" -- was
# measured against the reference consumer and does not work. Over one sprint, SIX of
# the seven largest evictions DID write to the history file in the same commit, and
# FOUR of those six still destroyed 75% or more of what they removed. The clearest
# case deleted 244 substantive lines, moved 61, and left a note behind saying the
# cycles had been moved to the history file and could be read there. A line-count
# join scores that as a partial pass. Asking whether the text still exists scores it
# correctly, because that is the actual question Rule 25(a) asks.
#
# The history file is not where this goes wrong. Across the same corpus, 17 commits
# touch it and NOT ONE deletes a line from it: append-only holds. What fails is
# coverage, and coverage is invisible to anything that counts lines on both sides.
#
# THE MEASURED HARM. In the reference consumer's sprint 300: of 2,524 substantive
# lines removed from the snapshot, 2,141 -- 84% -- are absent from the repository
# entirely. Gate dispositions, operator override citations, adversarial pass
# verdicts. 69 of the 70 commits touching the file destroyed at least one line.
#
# WHY THE THRESHOLD IS NOT 1. That 69-of-70 is the whole design problem. A check
# firing on any destroyed line fires on essentially every snapshot commit, and an
# unmeasured lint is one the operator turns off -- which is worse than no check.
# The per-commit distribution is bimodal with a real gap: the destroyed-line counts
# run 1..35, then jump to 62, 68, 76, 100, 121, 165, 202, 231, 244, 327. Any
# threshold in 36..62 selects the SAME ten commits and covers 75% of all destroyed
# lines. 40 sits inside that gap, so the number is read off the distribution rather
# than chosen. Override AI_DLC_SNAPSHOT_CONSERVATION_FLOOR.
#
# WHAT IT DELIBERATELY DOES NOT CATCH. A line that was reworded rather than removed
# reads as destroyed here, because its old form genuinely is gone. That is the
# check's false-positive class and the threshold is what bounds it: ordinary
# rewording lands in the 1..35 band the gap excludes. It is stated here rather than
# suppressed, because a filter clever enough to tell a reworded line from a deleted
# one is also clever enough to drop a real one.
#
# USAGE
#   validate-snapshot-conservation.sh [options]
#
#   --root <dir>           project root. Default: resolved by walking up from this
#                          script, then CLAUDE_PROJECT_DIR, then the cwd.
#   --base <sha>           compare against this commit instead of the newest
#                          resolvable gate sha. The fixture drives the check this
#                          way, and it is how a gate replays an earlier interval.
#   --gate-metrics <path>  gate-metrics.jsonl to read the base sha from. Default:
#                          the first of the known artifact locations that exists.
#   --snapshot <path>      snapshot to measure, repo-relative. Default:
#                          _bmad-output/pipeline-snapshot.md, then the docs/ variant.
#   --floor <n>            destroyed-line count at which the check FAILS. Default 40,
#                          read off the measured distribution above. Env override:
#                          AI_DLC_SNAPSHOT_CONSERVATION_FLOOR.
#   --warn-only            report the breach and exit 0. For a sprint-end posture
#                          where blocking helps nobody; never at a gate.
#   --quiet                suppress the per-run measurement lines. The FAIL block
#                          still goes to stderr.
#   -h, --help             print this header.
#
# Also honoured: AI_DLC_SNAPSHOT_CONSERVATION_MIN_LEN, the character length below
# which a removed line is not treated as a record. Default 20.
#
# EXIT CODES
#   0  conserved, or not applicable (no usable base -- first sprint, no gate yet)
#   1  destruction at or above the floor
#   2  cannot evaluate (not a git repo, unparseable gate metrics, bad arguments)
#
# A zero is never printed bare. Every run emits base_sha, lines_removed and
# lines_destroyed, so "nothing was destroyed" and "nothing was examined" can be told
# apart afterwards -- they are the same clean line otherwise, which is this repo's
# recurring defect.

set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
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
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

ROOT="$AI_DLC_ROOT"
BASE=""
GATE_METRICS=""
SNAPSHOT=""
WARN_ONLY=0
QUIET=0
FLOOR="${AI_DLC_SNAPSHOT_CONSERVATION_FLOOR:-40}"
# A line shorter than this is a heading fragment, a bullet marker or a table rule.
# Matching those produces noise in both directions and none of them is a record.
MIN_LEN="${AI_DLC_SNAPSHOT_CONSERVATION_MIN_LEN:-20}"
SHOW=12

while [ $# -gt 0 ]; do
  case "$1" in
    --root)          ROOT="${2:-}"; shift 2 ;;
    --base)          BASE="${2:-}"; shift 2 ;;
    --gate-metrics)  GATE_METRICS="${2:-}"; shift 2 ;;
    --snapshot)      SNAPSHOT="${2:-}"; shift 2 ;;
    --floor)         FLOOR="${2:-}"; shift 2 ;;
    --warn-only)     WARN_ONLY=1; shift ;;
    --quiet)         QUIET=1; shift ;;
    -h|--help)
      sed -n '2,86p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2 ;;
  esac
done

case "$FLOOR" in
  ''|*[!0-9]*) echo "ERROR: --floor must be a non-negative integer, got: $FLOOR" >&2; exit 2 ;;
esac

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

[ -d "$ROOT" ] || { echo "ERROR: --root is not a directory: $ROOT" >&2; exit 2; }

git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "ERROR: not a git repository: $ROOT" >&2
  echo "  This check is a git-derived join. Without history there is no BEFORE to" >&2
  echo "  compare against, and reporting conservation from one snapshot alone would" >&2
  echo "  be reporting a verdict it never computed." >&2
  exit 2
}

# ---------------------------------------------------------------------------
# The snapshot.
# ---------------------------------------------------------------------------
if [ -z "$SNAPSHOT" ]; then
  for cand in "_bmad-output/pipeline-snapshot.md" "docs/_bmad-output/pipeline-snapshot.md"; do
    [ -f "$ROOT/$cand" ] && { SNAPSHOT="$cand"; break; }
  done
fi
SNAPSHOT="${SNAPSHOT#"$ROOT"/}"

if [ -z "$SNAPSHOT" ] || [ ! -f "$ROOT/$SNAPSHOT" ]; then
  say "snapshot            : (absent)"
  say "verdict             : NOT-APPLICABLE -- no pipeline-snapshot.md to evaluate."
  say "                      A pipeline before route.md Step 0 has not written one."
  exit 0
fi

# ---------------------------------------------------------------------------
# The base: the most recent gate sha that this repository can actually resolve.
#
# It walks BACKWARDS rather than taking the last record. Measured in the reference
# consumer, only 10 of 34 distinct recorded gate shas are resolvable -- the rest
# were written from worktrees or were rewritten afterwards. Taking the newest and
# exiting on failure would make the check unrunnable for the majority of gates
# while printing an error that looks like a repository problem.
# ---------------------------------------------------------------------------
if [ -z "$GATE_METRICS" ]; then
  for cand in "_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
              "docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
              "_bmad-output/gate-metrics.jsonl"; do
    [ -f "$ROOT/$cand" ] && { GATE_METRICS="$cand"; break; }
  done
fi
GATE_METRICS="${GATE_METRICS#"$ROOT"/}"

BASE_SOURCE="--base"
if [ -z "$BASE" ]; then
  if [ -z "$GATE_METRICS" ] || [ ! -f "$ROOT/$GATE_METRICS" ]; then
    say "snapshot            : $SNAPSHOT"
    say "base_sha            : none"
    say "lines_removed       : 0"
    say "lines_destroyed     : 0"
    say "verdict             : NOT-APPLICABLE -- no gate-metrics.jsonl, so no gate has"
    say "                      closed yet in this repository. There is no prior gate to"
    say "                      measure from. The first gate of the first sprint creates"
    say "                      the base this check reads on every gate after it."
    exit 0
  fi

  SHAS="$(grep -o '"sha"[[:space:]]*:[[:space:]]*"[0-9a-f]\{7,40\}"' "$ROOT/$GATE_METRICS" 2>/dev/null \
          | sed 's/.*"\([0-9a-f]\{7,40\}\)".*/\1/')"
  if [ -z "$SHAS" ]; then
    echo "ERROR: $GATE_METRICS exists but carries no parseable \"sha\" field." >&2
    echo "  The file is present, so this is not a first-sprint absence -- it is a" >&2
    echo "  metrics file this check cannot read, and treating that as 'nothing to" >&2
    echo "  compare' would report a clean line from a broken input." >&2
    exit 2
  fi

  # Newest-first, stopping at the first sha this repository can resolve.
  while read -r s; do
    [ -n "$s" ] || continue
    git -C "$ROOT" cat-file -e "${s}^{commit}" 2>/dev/null || continue
    git -C "$ROOT" merge-base --is-ancestor "$s" HEAD 2>/dev/null || continue
    BASE="$s"; break
  done <<< "$(printf '%s\n' "$SHAS" | awk '{a[NR]=$0} END{for(i=NR;i>0;i--) print a[i]}')"

  BASE_SOURCE="$GATE_METRICS"

  if [ -z "$BASE" ]; then
    say "snapshot            : $SNAPSHOT"
    say "base_sha            : none"
    say "gate_shas_recorded  : $(printf '%s\n' "$SHAS" | sort -u | wc -l | tr -d ' ')"
    say "lines_removed       : 0"
    say "lines_destroyed     : 0"
    say "verdict             : NOT-APPLICABLE -- none of the recorded gate shas resolves"
    say "                      to a commit reachable from HEAD. Shas written from a"
    say "                      worktree, or rewritten by a rebase, are not defects here."
    exit 0
  fi
else
  git -C "$ROOT" cat-file -e "${BASE}^{commit}" 2>/dev/null || {
    echo "ERROR: --base is not a commit in this repository: $BASE" >&2
    exit 2
  }
fi

# ---------------------------------------------------------------------------
# The lines that left, and whether they still exist anywhere.
# ---------------------------------------------------------------------------
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/aidlc-conserve.XXXXXX")" || {
  echo "ERROR: cannot create a temporary directory." >&2; exit 2; }
trap 'rm -rf "$TMPROOT"' EXIT

CAND="$TMPROOT/candidates"
CORPUS="$TMPROOT/corpus"
DESTROYED="$TMPROOT/destroyed"

# Both sides are normalised the same way -- leading and trailing whitespace
# stripped -- so that content re-indented on its way into the history file still
# reads as conserved. Normalising only one side would manufacture destruction out
# of a bullet that changed nesting depth.
git -C "$ROOT" diff "$BASE" -- "$SNAPSHOT" 2>/dev/null \
  | grep '^-' | grep -v '^---' \
  | sed 's/^-//' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | awk -v m="$MIN_LEN" 'length($0) >= m' \
  | sort -u > "$CAND"

REMOVED="$(wc -l < "$CAND" | tr -d ' ')"

say "snapshot            : $SNAPSHOT"
say "base_sha            : ${BASE:0:9}  (from ${BASE_SOURCE})"
say "floor               : $FLOOR destroyed line(s)"
say "lines_removed       : $REMOVED  (substantive, >= ${MIN_LEN} chars, deduplicated)"

if [ "$REMOVED" -eq 0 ]; then
  say "lines_destroyed     : 0"
  say "verdict             : PASS -- nothing substantive left the snapshot since the base."
  exit 0
fi

# The conservation corpus is every tracked markdown file in the WORKING TREE, which
# is what makes an uncommitted move count as a move. It includes the snapshot
# itself: content relocated within the file was never evicted.
( cd "$ROOT" && git ls-files -z -- '*.md' 2>/dev/null | xargs -0 cat 2>/dev/null ) \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | sort -u > "$CORPUS"

CORPUS_LINES="$(wc -l < "$CORPUS" | tr -d ' ')"
if [ "$CORPUS_LINES" -eq 0 ]; then
  echo "ERROR: the conservation corpus is empty -- no tracked *.md files under $ROOT." >&2
  echo "  Every removed line would score as destroyed against an empty corpus, so this" >&2
  echo "  is reported as unevaluable rather than as total destruction." >&2
  exit 2
fi
say "corpus_lines        : $CORPUS_LINES  (distinct lines, tracked *.md, working tree)"

# Set membership, not pattern matching. Both sides are sorted, normalised line sets,
# so a candidate is conserved exactly when it appears in the corpus set and the
# whole verdict is one comm.
#
# The alternative -- grepping the corpus once per removed line -- was built first
# and measured on the reference consumer at 114 SECONDS against an 87 MB corpus,
# for a check that runs at every gate. This is 3. It is also strictly more
# CONSERVATIVE, not merely faster: measured over the same 223 removed lines, it
# reports 159 destroyed against the substring method's 161, and the set of lines it
# accuses is a SUBSET -- there is no line this calls destroyed that grepping calls
# conserved. The two it clears are lines that moved and were re-indented, which the
# normalisation above sees and a raw substring match does not.
comm -23 "$CAND" "$CORPUS" > "$DESTROYED" || true

GONE="$(wc -l < "$DESTROYED" | tr -d ' ')"
say "lines_destroyed     : $GONE  (present in NO tracked markdown file)"

if [ "$GONE" -lt "$FLOOR" ]; then
  say "verdict             : PASS -- $((REMOVED - GONE)) of $REMOVED removed line(s) still exist; $GONE below the floor of $FLOOR."
  exit 0
fi

if [ "$WARN_ONLY" -eq 1 ]; then
  echo "WARN: $GONE line(s) removed from $SNAPSHOT exist nowhere in the repository."
else
  echo "FAIL: $GONE line(s) removed from $SNAPSHOT exist nowhere in the repository." >&2
fi

{
  echo ""
  echo "      Rule 25(a): superseded snapshot content is MOVED to"
  echo "      pipeline-snapshot-history.md, never deleted. These lines were removed"
  echo "      from the snapshot since ${BASE:0:9} and are not present in any tracked"
  echo "      markdown file -- not in the history file, not in an archive, not"
  echo "      elsewhere in the snapshot:"
  echo ""
  head -n "$SHOW" "$DESTROYED" | sed 's/^/        /' | cut -c1-118
  if [ "$GONE" -gt "$SHOW" ]; then
    echo "        ... and $((GONE - SHOW)) more."
  fi
  cat <<'EOF'

      REMEDY. Recover them from git and append them verbatim to
      pipeline-snapshot-history.md, then re-run:

        git show <base>:<snapshot path> > /tmp/snapshot-before.md

      and take the missing entries from it. The history file is append-only, so
      adding to it cannot break anything a later gate reads.

      This is not a size complaint. The byte budget is a separate check and it
      passes on a snapshot that got smaller either way -- getting smaller is what
      destruction and conservation have in common. What this reports is that the
      content did not go anywhere.
EOF
} >&2

[ "$WARN_ONLY" -eq 1 ] && exit 0
exit 1
