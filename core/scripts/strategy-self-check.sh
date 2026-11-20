#!/usr/bin/env bash
# strategy-self-check.sh -- the stories checks the gate runs, run once at the end of authoring, one verdict.
#
# Dev handoff: strategy-self-check.sh --handoff --story <story file>   (judges that story alone; runs ac-falsifiability,
#          locked-anchor and the Kind arm; never INCOMPLETE for planning inputs)
# Authoring: strategy-self-check.sh --sprint <N> --stories-dir <dir> [--spec <spec-folder> --prd <prd.md>
#          [--spine <file>] [--spine-lint <json>] [--locked-requirements <file>]]
#          [--series <path-prefix> [--transcript-dir <dir>] [--transcript <file>]] [--handoff]
#
# Run from the project root. It runs, over every story file in --stories-dir:
#   1. validate-spec-join.sh   (gate Check 30)   -- needs --spec and --prd
#   2. sprint-status.sh check-stories (Check 5)  -- the canonical yaml against the story files
#   3. validate-adversarial-convergence.sh (Check 24, the J2 terminal-drift chain with every other arm)
#                                                -- needs --series; owed once a pass of the stories series exists
#   4. validate-ac-falsifiability.sh (Check 31)
#   5. validate-locked-anchor.sh (Check 3b), once per story
#   6. the `Kind` vocabulary of every `## Strategy Test IDs` row: a non-empty Kind cell is exactly one of `test`,
#      `predicate`, `deploy-time`; under --handoff no Kind or Resolves-to cell may be empty either. FORWARD-ONLY: only a story whose
#      Strategy Test IDs section carries the era token line (strategy-rows.sh --bind writes it) is judged; every other story prints
#      `SKIP pre-era` and is never refused. validate-handoff-evidence.sh does NOT enforce this vocabulary.
#
# VERDICT: the last line is `STRATEGY-SELF-CHECK: PASS`, `FAIL` or `INCOMPLETE`. PASS needs every check to have RUN and
# exited 0; INCOMPLETE means no check failed but one could not run (its flag was not given, or no series pass exists yet)
# and names it; FAIL names every failing check. It replaces no gate check: the gate still runs them.
# Exit: 0 PASS, 1 FAIL, 4 INCOMPLETE, 2 usage.
ss_main() {
set -u
LC_ALL=C; export LC_ALL
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

SPRINT=""; DIR=""; SPEC=""; PRD=""; SPINE=""; LINT=""; LOCKED=""; SERIES=""; TDIR=""; TFILE=""; HANDOFF=0; STORYF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    --stories-dir) DIR="${2:-}"; shift 2 ;;
    --spec) SPEC="${2:-}"; shift 2 ;;
    --prd) PRD="${2:-}"; shift 2 ;;
    --spine) SPINE="${2:-}"; shift 2 ;;
    --spine-lint) LINT="${2:-}"; shift 2 ;;
    --locked-requirements) LOCKED="${2:-}"; shift 2 ;;
    --series) SERIES="${2:-}"; shift 2 ;;
    --transcript-dir) TDIR="${2:-}"; shift 2 ;;
    --transcript) TFILE="${2:-}"; shift 2 ;;
    --handoff) HANDOFF=1; shift ;;
    --story) STORYF="${2:-}"; shift 2 ;;
    *) echo "strategy-self-check: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
if [ -n "$STORYF" ]; then
  [ "$HANDOFF" = 1 ] || { echo "strategy-self-check: --story is a flag of --handoff" >&2; exit 2; }
  [ -f "$STORYF" ] || { echo "strategy-self-check: --story '$STORYF' is not a file" >&2; exit 2; }
  [ -n "$DIR" ] || DIR="$(dirname "$STORYF")"
fi
# --sprint is the authoring run's (check-stories reads it); the dev handoff runs none of the arms that need it.
[ "$HANDOFF" = 1 ] || case "$SPRINT" in ''|*[!0-9]*) echo "strategy-self-check: --sprint <N> is required and numeric" >&2; exit 2 ;; esac
[ -d "$DIR" ] || { echo "strategy-self-check: --stories-dir '$DIR' is not a directory" >&2; exit 2; }

STORIES=""
if [ -n "$STORYF" ]; then STORIES="
$STORYF"; else
for f in "$DIR"/*.md; do [ -f "$f" ] && STORIES="$STORIES
$f"; done
fi
[ -n "$STORIES" ] || { echo "strategy-self-check: no story file under $DIR" >&2; exit 2; }

OUT="$(mktemp "${TMPDIR:-/tmp}/strategy-self-check.XXXXXX")" || exit 2
trap 'rm -f "$OUT"' EXIT
FAILS=""; SKIPS=""; RAN=0

# run <label> <cmd...>: report rc and the last output lines.
run() {
  label="$1"; shift
  "$@" > "$OUT" 2>&1; rc=$?
  RAN=$((RAN + 1))
  if [ "$rc" -eq 0 ]; then
    echo "  ok      $label"
  else
    echo "  FAILED  $label (exit $rc)"; tail -n 6 "$OUT" | sed 's/^/            /'
    FAILS="$FAILS $label"
  fi
}
skip() { echo "  SKIPPED $1 ($2)"; SKIPS="$SKIPS $1"; }

echo "strategy-self-check: ${SPRINT:+sprint $SPRINT, }stories in $DIR${STORYF:+, story ${STORYF##*/} alone}"

# Arms 1-3 read planning inputs (the spec, the canonical yaml, the stories series) that a dev handoff does not own, and a
# handoff is never INCOMPLETE for want of them: under --handoff only arms 4-6 run, over the story or stories named.
if [ "$HANDOFF" = 1 ]; then
  echo "  not owed at handoff: spec-join, check-stories, convergence (planning arms; run without --handoff)"
else
# 1. spec join
if [ -n "$SPEC" ] && [ -n "$PRD" ]; then
  set -- --spec "$SPEC" --prd "$PRD"
  [ -z "$SPINE" ] || set -- "$@" --spine "$SPINE"
  [ -z "$LINT" ] || set -- "$@" --spine-lint "$LINT"
  [ -z "$LOCKED" ] || set -- "$@" --locked-requirements "$LOCKED"
  for f in $STORIES; do set -- "$@" --story "$f"; done
  run "spec-join" bash "$HERE/validate-spec-join.sh" "$@"
else
  skip "spec-join" "--spec and --prd not given"
fi

# 2. check-stories
run "check-stories" bash "$HERE/sprint-status.sh" check-stories --sprint "$SPRINT"

# 3. convergence series (J2 and every other arm)
if [ -n "$SERIES" ]; then
  n=0; for p in "$SERIES"*; do [ -e "$p" ] && n=$((n + 1)); done
  if [ "$n" -gt 0 ]; then
    set -- --series "$SERIES"
    [ -z "$TDIR" ] || set -- "$@" --transcript-dir "$TDIR"
    [ -z "$TFILE" ] || set -- "$@" --transcript "$TFILE"
    run "convergence" bash "$HERE/validate-adversarial-convergence.sh" "$@"
  else
    skip "convergence" "no pass of $SERIES exists yet"
  fi
else
  skip "convergence" "--series not given"
fi
fi

# 4. falsifiability
set --
for f in $STORIES; do set -- "$@" "$f"; done
run "ac-falsifiability" bash "$HERE/validate-ac-falsifiability.sh" "$@"

# 5. locked anchor, once per story
bad=""
for f in $STORIES; do
  bash "$HERE/validate-locked-anchor.sh" "$f" > "$OUT" 2>&1 || { bad="$bad ${f##*/}"; tail -n 3 "$OUT" | sed 's/^/            /'; }
done
RAN=$((RAN + 1))
if [ -z "$bad" ]; then echo "  ok      locked-anchor"; else echo "  FAILED  locked-anchor:$bad"; FAILS="$FAILS locked-anchor"; fi

# 6. Kind vocabulary, FORWARD-ONLY by era token. strategy-rows.sh --bind stamps every table it writes with the comment line
# its own whole line `AI_DLC_ERA_TOKEN` (core/scripts/era-token.sh, the one definition). Only a story whose
# Strategy Test IDs section carries that line is judged; any other story, however late it is edited, prints `SKIP pre-era` and is
# never refused. A judged story FAILS on a non-empty Kind that is not one of test, predicate, deploy-time, and under --handoff on
# an empty Kind or Resolves-to cell.
# shellcheck source=era-token.sh
. "$HERE/era-token.sh" || { echo "strategy-self-check: cannot source era-token.sh beside this script" >&2; exit 2; }
ERA_TOKEN="$AI_DLC_ERA_TOKEN"
[ -n "$ERA_TOKEN" ] || { echo "strategy-self-check: era-token.sh defines no AI_DLC_ERA_TOKEN" >&2; exit 2; }
rm -f "$OUT.kind"
kind_judged=0; kind_skipped=0
for f in $STORIES; do
  stamped="$(awk -v tok="$ERA_TOKEN" '/^## Strategy Test IDs[ \t]*$/ { sec = 1; next } /^## / { sec = 0 } sec && $0 == tok { print "Y"; exit }' "$f")"
  if [ -z "$stamped" ]; then kind_skipped=$((kind_skipped + 1)); continue; fi
  kind_judged=$((kind_judged + 1))
  awk -v hand="$HANDOFF" -v file="${f##*/}" -F'|' '
    function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
    /^## Strategy Test IDs[ \t]*$/ { sec = 1; next }
    /^## / { sec = 0 }
    sec && /^\|/ {
      c1 = trim($2)
      if (c1 == "Strategy id" || c1 ~ /^-+$/) next
      kind = trim($4); res = trim($5)
      if (kind != "" && kind != "test" && kind != "predicate" && kind != "deploy-time") { printf "%s: %s case %s: Kind \"%s\" is not one of test, predicate, deploy-time\n", file, c1, trim($3), kind; bad = 1 }
      if (hand == 1 && (kind == "" || res == "")) { printf "%s: %s case %s: Kind or Resolves-to is empty\n", file, c1, trim($3); bad = 1 }
    }
    END { exit bad }
  ' "$f" >> "$OUT.kind"
  # The awk exits 1 exactly when it printed a violation (those lines are the verdict); any other status is a real failure.
  kind_rc=$?
  if [ "$kind_rc" -gt 1 ]; then echo "${f##*/}: the Kind scan failed (awk exit $kind_rc)" >> "$OUT.kind"; fi
done
RAN=$((RAN + 1))
if [ -s "$OUT.kind" ]; then
  echo "  FAILED  kind-vocabulary"; head -n 12 "$OUT.kind" | sed 's/^/            /'; FAILS="$FAILS kind-vocabulary"
elif [ "$kind_judged" -eq 0 ]; then
  echo "  SKIP pre-era  kind-vocabulary ($kind_skipped story file(s) carry no '$ERA_TOKEN' line)"
else
  echo "  ok      kind-vocabulary ($kind_judged judged, $kind_skipped SKIP pre-era)"
fi
rm -f "$OUT.kind"

if [ -n "$FAILS" ]; then echo "STRATEGY-SELF-CHECK: FAIL --$FAILS"; exit 1; fi
if [ -n "$SKIPS" ]; then echo "STRATEGY-SELF-CHECK: INCOMPLETE -- not run:$SKIPS"; exit 4; fi
echo "STRATEGY-SELF-CHECK: PASS ($RAN checks)"; exit 0
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
ss_main "$@"
