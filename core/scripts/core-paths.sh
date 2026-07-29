#!/usr/bin/env bash
set -uo pipefail

# core-paths.sh — resolve whether a project-relative path is upstream-owned CORE.
#
# WHY THIS EXISTS. Check 16 (stub audit) greps changed hot-path files for stub
# markers and requires four elements in the surrounding comment block, one of
# which is an `Item N` resolvable in the CONSUMER's carry-over-backlog.md. A
# core-owned file can satisfy none of them: it cannot carry a consumer's backlog
# item number, and `ai-dlc-core-guard.sh` DENIES the in-place edit that would add
# one -- there is no overrides/ shadow and no extensions/ entry for a hook or a
# validator. So a core file caught by the marker regex was a gate FAIL with no
# clearing path short of forking core (Rule 27 forbids it) or an operator waiver
# on every pull. Observed on the reference consumer at ai-dlc 0.156.0: a prose
# comment in `reconcile/apply.sh` reading "Phase 3's layer-drift.sh does NOT
# belong here" matched `Phase [0-9]` and failed a §6 gate four times. 19
# core-distributed hot-path files carry 45 such marker lines; each one is the
# same failure waiting for a pull that touches it.
#
# Stub discipline for core files is not abandoned -- it MOVES to the distribution
# repo, where the edit and the backlog item number both exist. This resolver is
# what lets the consumer-side check say "not mine" mechanically instead of the
# adjudicator being trusted to eyeball it.
#
# usage:
#   core-paths.sh --is-core <project-relative-path> [<manifest>]
#   core-paths.sh --list [<manifest>]
#   core-paths.sh --audit-diff <base-ref> [<head-ref>]
#
# exit (--is-core):
#   0 = the path IS core-manifest-owned
#   1 = the path is NOT core (consumer-authored, or a layer/doc/source path)
#   2 = cannot determine -- no readable manifest in either layout. NEVER degrades
#       to a 0 or a 1: "no manifest found" and "not core" are different answers
#       and a caller that cannot tell them apart will exempt the whole tree.
#
# exit (--list): 0 with one consumer-relative glob per line, 2 if unparseable.
#
# --audit-diff: THE BACKSTOP, AS AN EXECUTABLE. The core-layer-immutability check
# in `steps/gate-validation.md` states the whole procedure in prose -- diff the
# sprint range, ask `--is-core` per path, exempt the recognized cases -- and calls
# itself "the BACKSTOP for whatever reached disk anyway: a shell write, a
# `git push --no-verify`, or a consumer without the hook wired." Every word of it
# was adjudicated by an agent reading the paragraph. A prohibition whose only
# backstop is prose is a suggestion (CLAUDE.md), and this one guards the rule that
# keeps a consumer's core tree pullable at all. The derivation is not re-invented:
# the mode runs the SAME glob set the two arms above build, so the keystroke guard,
# the gate check and this audit cannot disagree about what core is.
#
# THE MANIFEST IS RESOLVED AT <base-ref>, NOT FROM THE WORKING TREE. A diff that
# shrinks `core-manifest.md` in order to move its own edit out of the core set is
# classified against the manifest as it stood BEFORE that diff. Reading the working
# tree would let the diff under audit define its own scope.
#
# exit (--audit-diff):
#   0 = no core path touched in range, or every commit touching one is a recognized
#       `chore(ai-dlc-update):` reconcile commit, or an operator-authorization
#       citation is present -- or the tree is DORMANT (see below)
#   1 = a core path is touched by a non-reconcile commit with no citation
#   2 = the core set could not be resolved, so nothing was classified. Fail-closed,
#       for the same reason --is-core exits 2: an empty result from a scan that did
#       not run is not a clean tree.
#
# DORMANT IS NOT A PASS, AND IT SAYS SO. The gate check is "active only on a layered
# consumer" -- a `.claude/.ai-dlc-version` stamp plus the `overrides/` and
# `extensions/` layer dirs. In the distribution source repo core lives at `core/`,
# no consumer-relative glob can match anything, and a silent "no core path touched"
# would be a false clean in the one tree where every path IS core. So the activation
# condition is evaluated at <base-ref> and a dormant run prints DORMANT and the
# reason it is dormant, rather than the word every caller reads as coverage.
#
# The path set is DERIVED from core-manifest.md (fallback: setup-sites.md's
# I5-synced copy). Nothing is hand-listed here.
#
# ON THE DUPLICATE PARSER. `parse_manifest()` and `to_consumer_glob()` below are
# byte-identical copies of the same functions in `hooks/ai-dlc-core-guard.sh`,
# and `validate-enforcement-map.sh` FAILS the build if they ever diverge. The
# copy is deliberate and the binding is what makes it safe: the guard must stay
# self-contained, because a guard that sources a helper stops denying core writes
# entirely if that helper is missing from a partial install -- it fails open, and
# a silently-disabled write guard is worse than a duplicated 25-line parser. Two
# copies bound byte-for-byte cannot drift; one copy with a fragile load path can
# vanish.

usage() {
  echo "usage: core-paths.sh --is-core <path> [<manifest>]" >&2
  echo "       core-paths.sh --list [<manifest>]" >&2
  echo "       core-paths.sh --audit-diff <base-ref> [<head-ref>]" >&2
}

# --- BEGIN SHARED WITH hooks/ai-dlc-core-guard.sh (byte-identical; I20) -------
parse_manifest() {   # <file> -> raw core_manifest entries, one per line
  local f="$1"
  [ -r "$f" ] || return 1
  awk '
    /^core_manifest:[ \t]*$/ { inlist=1; next }
    inlist && /^[ \t]*-[ \t]+/ {
      line=$0
      sub(/^[ \t]*-[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      next
    }
    inlist && /^[^ \t]/ { inlist=0 }     # dedent (incl. a closing ``` fence) ends the list
  ' "$f"
}

to_consumer_glob() {  # <manifest entry> -> consumer-relative glob
  local e="${1#core/}"                    # setup-sites.md form carries a core/ prefix
  case "$e" in
    team-roles/*)     printf '.claude/%s\n' "$e" ;;
    hooks/*)          printf '.claude/%s\n' "$e" ;;   # hooks live at .claude/hooks/, outside the skill dir
    scripts/*)        printf '%s\n' "$e" ;;           # scripts/ai-dlc/* is at the project root, not under .claude/
    fixtures/*)       printf 'tests/%s\n' "$e" ;;     # install.sh copies core/fixtures/<n>/ to tests/fixtures/<n>/
    git-hooks/*)      printf '.githooks/%s\n' "${e#git-hooks/}" ;;  # .githooks/, where core.hooksPath points
    session-driver/*) printf '.claude/%s\n' "$e" ;;   # machinery, outside the skill dir
    schemas/*)        printf '.claude/%s\n' "$e" ;;   # machinery, outside the skill dir
    skills/*)         printf '.claude/%s\n' "$e" ;;   # ai-dlc/, ai-dlc-setup/ and ai-dlc-update/ all sit under .claude/skills/
    *)                printf '.claude/skills/ai-dlc/%s\n' "$e" ;;
  esac
}
# --- END SHARED WITH hooks/ai-dlc-core-guard.sh -------------------------------

# MODE_DISPATCH_BEGIN
MODE="${1:-}"
case "$MODE" in
  --is-core|--list|--audit-diff) ;;
  *) usage; exit 2 ;;
esac
# MODE_DISPATCH_END

TARGET=""
BASE_REF=""
HEAD_REF=""
if [ "$MODE" = "--is-core" ]; then
  TARGET="${2:-}"
  [ -n "$TARGET" ] || { usage; exit 2; }
  EXPLICIT="${3:-}"
elif [ "$MODE" = "--audit-diff" ]; then
  BASE_REF="${2:-}"
  [ -n "$BASE_REF" ] || { usage; exit 2; }
  HEAD_REF="${3:-HEAD}"
  EXPLICIT=""
else
  EXPLICIT="${2:-}"
fi

# --- --audit-diff pre-flight: git, activation, and the base-ref manifest --------
AUDIT_TMP=""
AUDIT_SRC=""
AUDIT_ROOT=""
cleanup() { [ -n "$AUDIT_TMP" ] && rm -f "$AUDIT_TMP"; return 0; }
if [ "$MODE" = "--audit-diff" ]; then
  AUDIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || AUDIT_ROOT=""
  [ -n "$AUDIT_ROOT" ] || {
    echo "core-paths: FAIL -- --audit-diff needs a git repository (none here)." >&2
    echo "  Refusing to answer: an audit that could not read history has classified nothing." >&2
    exit 2
  }
  for r in "$BASE_REF" "$HEAD_REF"; do
    git rev-parse --verify "${r}^{commit}" >/dev/null 2>&1 || {
      echo "core-paths: FAIL -- ref not resolvable: ${r}" >&2
      exit 2
    }
  done

  # ACTIVATION, evaluated at <base-ref>, mirroring the gate check's own condition:
  # a version stamp AND both layer directories. Absent any of the three this is not
  # a layered consumer and no consumer-relative glob can match -- which would render
  # as a clean scan rather than as "did not apply here".
  dormant_why=""
  git cat-file -e "${BASE_REF}:.claude/.ai-dlc-version" 2>/dev/null \
    || dormant_why="no .claude/.ai-dlc-version stamp"
  for d in overrides extensions; do
    [ -n "$dormant_why" ] && break
    [ -n "$(git ls-tree -d --name-only "${BASE_REF}" ".claude/skills/ai-dlc/${d}" 2>/dev/null)" ] \
      || dormant_why="no .claude/skills/ai-dlc/${d}/ layer directory"
  done
  if [ -n "$dormant_why" ]; then
    echo "DORMANT: not a layered consumer at ${BASE_REF} (${dormant_why})."
    echo "  Nothing was classified. This is the gate check's own activation rule; a"
    echo "  distribution checkout and a pre-layer-split consumer both land here, and"
    echo "  neither is evidence that no core file was edited."
    exit 0
  fi

  # The manifest as of BASE_REF. Fall back to the working tree only if the base has
  # none, and say so -- answering from the diff's own manifest is the hole this closes.
  trap cleanup EXIT
  AUDIT_TMP="$(mktemp)" || { echo "core-paths: FAIL -- mktemp" >&2; exit 2; }
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    if git show "${BASE_REF}:${c}" > "$AUDIT_TMP" 2>/dev/null && [ -s "$AUDIT_TMP" ]; then
      EXPLICIT="$AUDIT_TMP"; AUDIT_SRC="${BASE_REF}:${c}"; break
    fi
  done <<EOF
.claude/skills/ai-dlc/core-manifest.md
.claude/skills/ai-dlc-update/reconcile/setup-sites.md
EOF
  if [ -z "$EXPLICIT" ]; then
    echo "NOTE: no core-manifest at ${BASE_REF}; classifying against the working-tree manifest."
  fi
fi

# Manifest resolution. An explicit argument wins; otherwise try the consumer
# layout first, then the distribution layout, then each layout's setup-sites.md
# copy. Both layouts are searched because this script runs in both: installed as
# `scripts/ai-dlc/core-paths.sh` in a consumer, and read straight out of
# `core/scripts/` by the distribution's own fixtures and gates.
CANDIDATES=""
if [ -n "$EXPLICIT" ]; then
  CANDIDATES="$EXPLICIT"
else
  CANDIDATES="$(printf '%s\n' \
    ".claude/skills/ai-dlc/core-manifest.md" \
    "core/skills/ai-dlc/core-manifest.md" \
    ".claude/skills/ai-dlc-update/reconcile/setup-sites.md" \
    "core/skills/ai-dlc-update/reconcile/setup-sites.md")"
fi

RAW_ENTRIES=""
USED=""
while IFS= read -r c; do
  [ -n "$c" ] || continue
  RAW_ENTRIES="$(parse_manifest "$c" 2>/dev/null || true)"
  if [ -n "$RAW_ENTRIES" ]; then USED="$c"; break; fi
done <<EOF
$CANDIDATES
EOF

if [ -z "$RAW_ENTRIES" ]; then
  echo "core-paths: FAIL -- no parseable core_manifest list found. Tried:" >&2
  printf '%s\n' "$CANDIDATES" | sed 's/^/  /' >&2
  echo "  Refusing to answer. 'no manifest' is not 'not core': a caller that reads" >&2
  echo "  this as a clean negative would treat every path as consumer-owned." >&2
  exit 2
fi

CORE_GLOBS=""
while IFS= read -r e; do
  [ -n "$e" ] || continue
  CORE_GLOBS="${CORE_GLOBS}$(to_consumer_glob "$e")
"
done <<EOF
$RAW_ENTRIES
EOF

if [ "$MODE" = "--list" ]; then
  printf '%s' "$CORE_GLOBS"
  exit 0
fi

# --- --audit-diff: classify a range against that glob set ---------------------
if [ "$MODE" = "--audit-diff" ]; then
  # `...` for the file set (what this range CHANGED, against the merge base) and
  # `..` for the commits (what this range CONTAINS). The two spellings answer
  # different questions and a single one for both mis-attributes either the paths
  # or the commit that touched them.
  CHANGED="$(git diff --name-only "${BASE_REF}...${HEAD_REF}" 2>/dev/null || true)"
  echo "core set: ${AUDIT_SRC:-working tree}"
  if [ -z "$CHANGED" ]; then
    echo "N/A: no diff in range ${BASE_REF}...${HEAD_REF}"
    exit 0
  fi

  TOUCHED=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    rel="${p#./}"
    while IFS= read -r g; do
      [ -n "$g" ] || continue
      # shellcheck disable=SC2254
      case "$rel" in
        $g) TOUCHED="${TOUCHED}${rel}
"; break ;;
      esac
    done <<EOG
$CORE_GLOBS
EOG
  done <<EOF
$CHANGED
EOF

  if [ -z "$TOUCHED" ]; then
    echo "PASS: no core path touched in ${BASE_REF}...${HEAD_REF}"
    exit 0
  fi

  # A pull EDITS core in place -- that is what /ai-dlc-update is for -- so the
  # reconcile commit is the one legitimate author of a core edit. Recognized by
  # the subject convention `ai-dlc-update/SKILL.md` itself writes, and checked
  # BEFORE the citation fallback so a routine pull never needs an escalation.
  OFFENDERS=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    while IFS= read -r sha; do
      [ -n "$sha" ] || continue
      subj="$(git log -1 --format='%s' "$sha" 2>/dev/null)"
      case "$subj" in
        'chore(ai-dlc-update):'*) ;;
        *) OFFENDERS="${OFFENDERS}  ${sha} ${p} :: ${subj}
" ;;
      esac
    done <<EOG
$(git log --format='%H' "${BASE_REF}..${HEAD_REF}" -- "$p" 2>/dev/null)
EOG
  done <<EOF
$TOUCHED
EOF

  if [ -z "$OFFENDERS" ]; then
    echo "PASS: core path(s) touched, every touching commit is an /ai-dlc-update reconcile:"
    printf '%s' "$TOUCHED" | sed 's/^/  /'
    exit 0
  fi

  # The operator's escape hatch. PRESENCE only: this cannot tell whether the
  # citation covers THIS touch, and says so rather than letting a caller read the
  # exit code as adjudication.
  ESC="${AUDIT_ROOT}/docs/escalations/pending.md"
  if [ -f "$ESC" ] && grep -q 'Operator authorization:' "$ESC"; then
    echo "PASS (with citation): core path(s) touched by non-reconcile commit(s), and an"
    echo "  'Operator authorization:' line exists in the WORKING TREE's"
    echo "  docs/escalations/pending.md -- the working tree and not <head-ref>, because at a"
    echo "  live gate the operator has usually not committed the citation yet. A sweep over"
    echo "  historical ranges therefore reads today's citations against yesterday's diffs."
    echo "  This mode detects PRESENCE only -- whether the citation covers these touches is"
    echo "  the adjudicator's call, not this exit code's:"
    printf '%s' "$OFFENDERS"
    exit 0
  fi

  echo "FAIL: core path(s) edited in place by non-reconcile commit(s), no operator-authorization citation:"
  printf '%s' "$OFFENDERS"
  exit 1
fi

# Normalise the probe the same way the guard does: strip a leading ./ so
# `./scripts/ai-dlc/verdict.sh` and `scripts/ai-dlc/verdict.sh` agree.
REL="${TARGET#./}"

while IFS= read -r g; do
  [ -n "$g" ] || continue
  # shellcheck disable=SC2254
  case "$REL" in
    $g) echo "core: ${REL} (matches core-manifest glob '${g}' via ${USED})"; exit 0 ;;
  esac
done <<EOF
$CORE_GLOBS
EOF

echo "not-core: ${REL} (no core-manifest glob matches; manifest read from ${USED})"
exit 1
