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
#       `chore(ai-dlc-update):` reconcile commit (the SUBJECT arm), or carries a
#       reconcile's exact content (the CONTENT arm, below), or an operator-authorization
#       citation is present -- or the tree is DORMANT (see below)
#
# THE CONTENT ARM, and how its acquittal set was narrowed. A consumer that squash-merges its
# update PR lands the reconcile's tree under the PR's own subject, so the subject arm FAILs
# every pull it exists to pass (BL-939). The content arm acquits a touch of core path p by a
# non-reconcile commit t iff (mode, blob) at t:p EQUALS r:p for some r in R(t), where R(t) is
# the `chore(ai-dlc-update):` commits reachable from any branch or remote ref (a squashed
# pull's own commit survives only on its update ref), MINUS every commit in
# <base-ref>..<head-ref> (an in-range reconcile must not acquit the range it sits in), keyed
# on `.claude/.ai-dlc-version`: only an r whose stamp blob equals t's is eligible. A deletion
# is acquitted only when p is absent at t AND at that r. What it acquits: the installed
# reconcile's exact bytes and modes, and its own deletions -- nothing else. The stamp key is
# what makes an OLD reconcile's blob restored under the CURRENT stamp flag; the mode is
# compared so a chmod-only touch flags; an unparseable tree listing acquits nothing for that
# commit. Known acquittal: a downgrade that reverts the stamp along with the files carries an
# older reconcile's exact content and passes. When R(t) is empty -- typically because the
# update refs were pruned -- the FAIL says so rather than reading as an ordinary edit.
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
  echo "       core-paths.sh --map   (distribution-relative paths on stdin, consumer-relative paths on stdout)" >&2
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
    rules/*)          printf '.claude/%s\n' "$e" ;;   # Claude Code's own loader reads .claude/rules/, a fixed path
    skills/*)         printf '.claude/%s\n' "$e" ;;   # ai-dlc/, ai-dlc-setup/ and ai-dlc-update/ all sit under .claude/skills/
    *)                printf '.claude/skills/ai-dlc/%s\n' "$e" ;;
  esac
}
# --- END SHARED WITH hooks/ai-dlc-core-guard.sh -------------------------------

# MODE_DISPATCH_BEGIN
MODE="${1:-}"
case "$MODE" in
  --is-core|--list|--audit-diff|--map) ;;
  *) usage; exit 2 ;;
esac
# MODE_DISPATCH_END

# --map: THE DISTRIBUTION-TO-CONSUMER PATH MAP, for declarations. Reads distribution-relative paths on
# stdin (one per line), prints one consumer-relative path per line, in order. A path not under `core/`
# is printed unchanged; a trailing `/` is kept. It answers from the tops below and consults no
# manifest, so it runs on a tree that has none. An unrecognised top (`ci-templates`, which install.sh
# does not place), a bare `core` and `core/` are exit 2 with nothing mapped after them, so no path is
# ever sent through to_consumer_glob's catch-all arm. scripts/, fixtures/ and git-hooks/ are spelled
# here because to_consumer_glob answers a manifest GLOB (scripts/* stays scripts/*), not the place
# install.sh puts a file; every other recognised top is exactly to_consumer_glob's answer.
if [ "$MODE" = "--map" ]; then
  map_one() { # <path> -> prints the consumer path, or returns 2
    local p="$1" e
    case "$p" in
      core|core/) return 2 ;;
      core/*) ;;
      *) printf '%s\n' "$p"; return 0 ;;
    esac
    e="${p#core/}"
    case "$e" in
      scripts/*)   printf 'scripts/ai-dlc/%s\n' "${e#scripts/}" ;;
      fixtures/*)  printf 'tests/fixtures/%s\n' "${e#fixtures/}" ;;
      git-hooks/*) printf '.githooks/%s\n' "${e#git-hooks/}" ;;
      team-roles/*|hooks/*|session-driver/*|schemas/*|rules/*|skills/*) to_consumer_glob "$e" ;;
      *) return 2 ;;
    esac
  }
  while IFS= read -r line || [ -n "$line" ]; do
    map_one "$line" || { echo "core-paths: --map: no consumer location for '${line}' (an unrecognised top under core/, or a bare core)" >&2; exit 2; }
  done
  exit 0
fi

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
  # ANCHORED AT THE TOPLEVEL (BL-945). An ls-tree pathspec is cwd-relative: run from a subdirectory
  # the layer dir matches nothing and a layered consumer reads as DORMANT, exit 0. `<rev>:<path>`
  # above is already root-relative; this call is not, so it runs from AUDIT_ROOT.
  for d in overrides extensions; do
    [ -n "$dormant_why" ] && break
    [ -n "$(git -C "$AUDIT_ROOT" ls-tree -d --name-only "${BASE_REF}" ".claude/skills/ai-dlc/${d}" 2>/dev/null)" ] \
      || dormant_why="no .claude/skills/ai-dlc/${d}/ layer directory"
  done
  if [ -n "$dormant_why" ]; then
    echo "DORMANT: EXAMINED NOTHING — not a layered consumer at ${BASE_REF} (${dormant_why})."
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
# In --audit-diff mode the working-tree fallback is read from the toplevel (BL-945), not from the
# caller's cwd; AUDIT_ROOT is empty in every other mode, so their candidates are unchanged.
CANDIDATES=""
WT_PFX="${AUDIT_ROOT:+${AUDIT_ROOT}/}"
if [ -n "$EXPLICIT" ]; then
  CANDIDATES="$EXPLICIT"
else
  CANDIDATES="$(printf '%s\n' \
    "${WT_PFX}.claude/skills/ai-dlc/core-manifest.md" \
    "${WT_PFX}core/skills/ai-dlc/core-manifest.md" \
    "${WT_PFX}.claude/skills/ai-dlc-update/reconcile/setup-sites.md" \
    "${WT_PFX}core/skills/ai-dlc-update/reconcile/setup-sites.md")"
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
# A setup-sites.md copy carries no fixture entries: they sit in the skill-root
# fixture-manifest.md beside its reconcile/ directory, so that fallback is both blocks.
case "$USED" in
  */reconcile/setup-sites.md)
    RAW_ENTRIES="${RAW_ENTRIES}
$(parse_manifest "${USED%/reconcile/setup-sites.md}/fixture-manifest.md" 2>/dev/null || true)" ;;
esac

if [ -z "$RAW_ENTRIES" ]; then
  echo "core-paths: FAIL -- no parseable core_manifest list found. Tried:" >&2
  printf '%s\n' "$CANDIDATES" | sed 's/^/  /' >&2
  echo "  Refusing to answer. 'no manifest' is not 'not core': a caller that reads" >&2
  echo "  this as a clean negative would treat every path as consumer-owned." >&2
  exit 2
fi

# One command substitution around the whole loop, not one per entry: to_consumer_glob prints with a
# builtin, so the per-entry `$( )` was a fork per manifest line for the same bytes.
CORE_GLOBS="$(while IFS= read -r e; do
  [ -n "$e" ] || continue
  to_consumer_glob "$e"
done <<EOF
$RAW_ENTRIES
EOF
)
"

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
  # `-c diff.relative=false`: a config of diff.relative=true makes --name-only answer relative to
  # the cwd, so from a subdirectory CHANGED is empty and the range reads N/A, exit 0 (BL-945).
  CHANGED="$(git -c diff.relative=false diff --name-only "${BASE_REF}...${HEAD_REF}" 2>/dev/null || true)"
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
  #
  # ONE WALK OF THE RANGE, joined to TOUCHED in awk (BL-945): a per-path `git log -- "$p"` was a
  # cwd-relative pathspec (from a subdirectory it matched nothing and the range PASSed) and ~99% of
  # the gate's git calls. Run from AUDIT_ROOT, so a diff.relative=true config still prints
  # root-relative names; default core.quotePath, so its keys are spelled as CHANGED spells them.
  # Each flag is measured against the per-path walk it replaces:
  #   -c            a merge lists a path only when it differs from EVERY parent -- the per-path
  #                 walk's own TREESAME rule -- so an evil merge is listed and a --no-ff merge of a
  #                 reconcile is not (`-m` lists that merge against its first parent: a false FAIL);
  #   --no-renames  a rename out of a core path is listed under the core path's name (with renames
  #                 on it is listed only under the new name and joins to nothing: a false PASS);
  #   --root        a root commit lists its files under log.showRoot=false too, so an unrelated
  #                 history root merged with --allow-unrelated-histories keeps its offender pair
  #                 (without it that config drops the pair: a false PASS);
  #   --no-show-signature  log.showSignature=true prints verification lines above a signed
  #                 commit's \001 line, read as paths of the commit before it;
  #   --encoding=UTF-8     i18n.logOutputEncoding=UTF-16 re-encodes every line, so no \001
  #                 marker or path matches and each offender loses its sha.
  # Measured inert on this walk (output byte-identical over the fixture's ranges): format.pretty,
  # log.decorate, log.abbrevCommit, log.graph, log.follow, log.diffMerges, color.*, diff.noprefix,
  # diff.mnemonicPrefix, diff.relative, diff.external, diff.dirstat, core.pager. core.quotePath
  # moves it, in step with CHANGED, which reads the same config.
  # DECLARED DIVERGENCE, stricter: an identical edit of a path on both sides of a merge. The
  # per-path walk's history simplification follows one side and drops the other's commit; this
  # walk lists both. One OFFENDERS line per (sha, path) pair, in TOUCHED order then walk order.
  # The commit line is marked by a leading \001, which no --name-only line can begin with: a path
  # carrying a control byte is C-quoted by core.quotePath.
  OFFENDERS="$(printf '%s\n--\n%s\n' "$TOUCHED" \
    "$(git -C "$AUDIT_ROOT" log -c --no-renames --root --no-show-signature --encoding=UTF-8 --format='%x01%H %s' --name-only "${BASE_REF}..${HEAD_REF}" 2>/dev/null)" \
    | awk '
      $0 == "--" && !s { s = 1; next }
      !s { if ($0 != "" && !($0 in want)) { want[$0] = 1; order[++n] = $0 }; next }
      substr($0, 1, 1) == "\001" {
        sha = substr($0, 2); sub(/ .*/, "", sha)
        subj = substr($0, 2); sub(/^[^ ]* ?/, "", subj)
        rec = (index(subj, "chore(ai-dlc-update):") == 1)
        next
      }
      $0 != "" && ($0 in want) && !rec && !((sha, $0) in seen) {
        seen[sha, $0] = 1; c[$0]++; line[$0, c[$0]] = "  " sha " " $0 " :: " subj
      }
      END { for (i = 1; i <= n; i++) { p = order[i]; for (j = 1; j <= c[p]; j++) print line[p, j] } }')"
  [ -z "$OFFENDERS" ] || OFFENDERS="${OFFENDERS}
"

  if [ -z "$OFFENDERS" ]; then
    echo "PASS: core path(s) touched, every touching commit is an /ai-dlc-update reconcile:"
    printf '%s' "$TOUCHED" | sed 's/^/  /'
    exit 0
  fi

  # THE CONTENT ARM (header: "THE CONTENT ARM"). Batched: one log over the refs, one
  # rev-list for the range, one cat-file --batch-check for every stamp, then one ls-tree per
  # offending commit and one per eligible reconcile tried -- never a git call per path.
  # tree_keys <commit> <newline-separated paths> -> `path<TAB>mode blob` per entry. Returns 1
  # when the listing failed or any line did not parse: a path that cannot be read back must
  # never look ABSENT, because absent-at-both is the deletion acquittal.
  tree_keys() {
    local raw IFS='
'
    set -f
    raw="$(git -c core.quotePath=false ls-tree -r --full-tree "$1" -- $2 </dev/null 2>/dev/null)" || { set +f; return 1; }
    set +f
    [ -n "$raw" ] || return 0
    printf '%s\n--\n%s\n' "$2" "$raw" | awk -F'\t' '
      $0 == "--" && !s { s = 1; next }
      !s { if ($0 != "") want[$0] = 1; next }
      NF == 2 && substr($2, 1, 1) != "\"" { if ($2 in want) { split($1, a, " "); print $2 "\t" a[1] " " a[3] }; next }
      { bad = 1 }
      END { exit bad }'
  }
  CONTENT_ACQ=""
  CONTENT_NOREF=""
  content_arm() {
    local cands inrange rset tlist tagged sout stamps t ts rt paths remaining tk rk r now acqpairs
    cands="$(git log --branches --remotes --format='%H %s' 2>/dev/null | awk '{ s = $0; sub(/^[^ ]+ /, "", s); if (index(s, "chore(ai-dlc-update):") == 1) print $1 }')"
    inrange="$(git rev-list "${BASE_REF}..${HEAD_REF}" 2>/dev/null)"
    rset="$(printf '%s\n--\n%s\n' "$inrange" "$cands" | awk '$0 == "--" { s = 1; next } !s { x[$0] = 1; next } $0 != "" && !($0 in x)')"
    tlist="$(printf '%s' "$OFFENDERS" | awk 'NF && !($1 in s) { s[$1] = 1; print $1 }')"
    tagged="$(printf '%s\n--\n%s\n' "$rset" "$tlist" | awk '$0 == "--" { s = 1; next } NF { print (s ? "T" : "R"), $1 }')"
    sout="$(printf '%s\n' "$tagged" | awk '{ print $2 ":.claude/.ai-dlc-version" }' \
      | git cat-file --batch-check='%(objecttype) %(objectname)' 2>/dev/null)"
    stamps="$(printf '%s\n--\n%s\n' "$tagged" "$sout" | awk '$0 == "--" { s = 1; next } !s { n++; k[n] = $0; next } { m++; if ($1 == "blob") print k[m], $2 }')"
    acqpairs=""
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      ts="$(printf '%s\n' "$stamps" | awk -v k="$t" '$1 == "T" && $2 == k { print $3; exit }')"
      [ -n "$ts" ] || continue
      rt="$(printf '%s\n' "$stamps" | awk -v ts="$ts" '$1 == "R" && $3 == ts { print $2 }')"
      if [ -z "$rt" ]; then
        CONTENT_NOREF="${CONTENT_NOREF}    ${t} (installed stamp blob ${ts})
"
        continue
      fi
      paths="$(printf '%s' "$OFFENDERS" | awk -v k="$t" '$1 == k { s = $0; sub(/^ *[^ ]+ /, "", s); i = index(s, " :: "); if (i > 1) print substr(s, 1, i - 1) }')"
      [ -n "$paths" ] || continue
      tk="$(tree_keys "$t" "$paths")" || continue
      remaining="$paths"
      while IFS= read -r r; do
        [ -n "$r" ] && [ -n "$remaining" ] || continue
        rk="$(tree_keys "$r" "$remaining")" || continue
        now="$(printf '%s\n--\n%s\n--\n%s\n' "$remaining" "$tk" "$rk" | awk -F'\t' '
          $0 == "--" { s++; next }
          s == 0 { if ($0 != "") want[$0] = 1; next }
          s == 1 { tv[$1] = $2; next }
          { rv[$1] = $2 }
          END { for (p in want) { a = (p in tv) ? tv[p] : "ABSENT"; b = (p in rv) ? rv[p] : "ABSENT"; if (a == b) print p } }')"
        [ -n "$now" ] || continue
        acqpairs="${acqpairs}$(printf '%s\n' "$now" | awk -v t="$t" '{ print t " " $0 }')
"
        CONTENT_ACQ="${CONTENT_ACQ}$(printf '%s\n' "$now" | awk -v t="$t" -v r="$r" '{ print "    " t " " $0 " == reconcile " r }')
"
        remaining="$(printf '%s\n--\n%s\n' "$now" "$remaining" | awk '$0 == "--" { s = 1; next } !s { x[$0] = 1; next } $0 != "" && !($0 in x)')"
      done <<EOR
$rt
EOR
    done <<EOT
$tlist
EOT
    [ -n "$acqpairs" ] || return 0
    OFFENDERS="$(printf '%s\n--\n%s' "$acqpairs" "$OFFENDERS" | awk '$0 == "--" { s = 1; next } !s { if ($0 != "") a[$0] = 1; next } NF { s = $0; sub(/^ *[^ ]+ /, "", s); i = index(s, " :: "); if (i > 1 && (($1 " " substr(s, 1, i - 1)) in a)) next; print }')"
    [ -z "$OFFENDERS" ] || OFFENDERS="${OFFENDERS}
"
  }
  [ -z "$OFFENDERS" ] || content_arm

  if [ -z "$OFFENDERS" ]; then
    echo "PASS (content arm): core path(s) touched; each non-reconcile touch carries the exact (mode, blob) of a"
    echo "  chore(ai-dlc-update): reconcile reachable from a ref outside the range, at the same installed stamp:"
    printf '%s' "$TOUCHED" | sed 's/^/  /'
    echo "  acquitted by the CONTENT arm (commit path == reconcile):"
    printf '%s' "$CONTENT_ACQ"
    exit 0
  fi

  # The operator's escape hatch. PRESENCE only: this cannot tell whether the
  # citation covers THIS touch, and says so rather than letting a caller read the
  # exit code as adjudication.
  #
  # WHETHER A CITATION EXISTS AT ALL IS NOT THIS SCRIPT'S QUESTION TO ANSWER. This arm used to
  # be `grep -q 'Operator authorization:'` over the whole file, which is a second definition of
  # "the operator authorized something" living next to the one `escalations.md` states and
  # `validate-escalation-resolution.sh` enforces. Two definitions of one predicate drift, and
  # this one had: measured on the reference consumer, half the lines satisfying that grep were
  # not citations -- a preamble line belonging to no entry, prose quoting the convention, and
  # one sentence stating that no citation exists or is required. Delegate to the owner instead.
  # The delegate resolves beside this script in BOTH layouts (core/scripts/, scripts/ai-dlc/),
  # the same way it resolves its own sibling; a missing delegate is exit 2, never a pass.
  ESC="${AUDIT_ROOT}/docs/escalations/pending.md"
  # The delegate is named in FULL at the call, not held in a variable, so the mode it is asked
  # for is a literal string in this file. I53 joins that spelling to the modes the delegate
  # dispatches, and a call assembled out of a variable is one the join cannot see -- which
  # would leave the invariant guarding the prose that describes this call and not the call.
  ESC_DIR="$(cd "$(dirname "$0")" && pwd)"
  AUTH_OUT=""
  if [ ! -f "$ESC_DIR/validate-escalation-resolution.sh" ]; then
    echo "core-paths: cannot classify the range -- $ESC_DIR/validate-escalation-resolution.sh is" >&2
    echo "  missing, so whether the operator authorized these touches cannot be decided." >&2
    echo "  Reinstall ai-dlc. Findings:" >&2
    printf '%s' "$OFFENDERS" >&2
    exit 2
  fi
  if AUTH_OUT="$(bash "$ESC_DIR/validate-escalation-resolution.sh" --any-authorized "$ESC" 2>&1)"; then
    echo "PASS (with citation): core path(s) touched by non-reconcile commit(s), and the WORKING"
    echo "  TREE's docs/escalations/pending.md carries an operator citation that"
    echo "  validate-escalation-resolution.sh accepts -- the working tree and not <head-ref>,"
    echo "  because at a live gate the operator has usually not committed the citation yet. A"
    echo "  sweep over historical ranges therefore reads today's citations against yesterday's"
    echo "  diffs. This mode detects PRESENCE only -- whether the citation covers these touches"
    echo "  is the adjudicator's call, not this exit code's:"
    printf '%s\n' "$AUTH_OUT" | sed 's/^/  /'
    printf '%s' "$OFFENDERS"
    exit 0
  fi

  echo "FAIL: core path(s) edited in place by non-reconcile commit(s), no operator-authorization citation:"
  printf '%s' "$OFFENDERS"
  if [ -n "$CONTENT_NOREF" ]; then
    echo "  content arm: no chore(ai-dlc-update): reconcile ref carrying the installed stamp was found for:"
    printf '%s' "$CONTENT_NOREF"
    echo "  (for example because the update refs were pruned); a squash-merged pull is acquitted only"
    echo "  while its reconcile commit is still reachable from a branch or remote ref."
  fi
  printf '%s\n' "$AUTH_OUT" | sed 's/^/  /'
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
