#!/usr/bin/env bash
# BL-1030: which gate passes of a graph sprint ran on which ai-dlc engine version.
# Read ONLY from committed graph refs (git ls-tree / git show / git log). No fetch, no checkout.
#
# Usage: bash engine-at-pass.sh <graph repo path> <ref> <sprint, e.g. s323>
#
# One row per `<idx>-g<gate>-p<pass>.plan` under `_bmad-output/implementation-artifacts/<sprint>/gate-transition/`:
# the plan's `sha:` is the commit that pass judged; the engine version is `version:` of graph's
# `.claude/.ai-dlc-version` AT THAT COMMIT (graph's installed-engine record), `skill_version:` printed beside it.
# Row: plan | gate | sha7 | committer time | version | skill_version | route head | GATE1/GATE2 SKIP or RERUN marks
# Then a summary: plan count, and the count per version.
set -u
GRAPH="${1:?graph path}"; REF="${2:?ref}"; SPR="${3:?sprint}"
P="_bmad-output/implementation-artifacts/${SPR}/gate-transition"
git -C "$GRAPH" rev-parse --verify -q "${REF}^{commit}" >/dev/null || { echo "engine-at-pass.sh: cannot resolve ${REF}" >&2; exit 2; }
LIST="$(git -C "$GRAPH" ls-tree -r --name-only "$REF" -- "$P" | grep '\.plan$')"
[ -n "$LIST" ] || { echo "engine-at-pass.sh: no .plan under ${P} at ${REF}" >&2; exit 2; }
echo "plan | gate | sha7 | committer time | version | skill_version | route | marks"
ROWS="$(printf '%s\n' "$LIST" | while IFS= read -r f; do
  body="$(git -C "$GRAPH" show "${REF}:${f}")"
  sha="$(printf '%s\n' "$body" | sed -n 's/^sha: //p' | head -1)"
  gt="$(printf '%s\n' "$body" | sed -n 's/^gate: //p' | head -1)"
  rt="$(printf '%s\n' "$body" | sed -n 's/^route: //p' | head -1 | cut -c1-40)"
  mk="$(printf '%s\n' "$body" | grep -oE 'GATE[12]-(SKIP|RERUN)' | sort -u | tr '\n' ,)"
  if git -C "$GRAPH" cat-file -e "${sha}^{commit}" 2>/dev/null; then
    vf="$(git -C "$GRAPH" show "${sha}:.claude/.ai-dlc-version" 2>/dev/null)"
    v="$(printf '%s\n' "$vf" | sed -n 's/^version: //p' | head -1)"
    sv="$(printf '%s\n' "$vf" | sed -n 's/^skill_version: //p' | head -1)"
    t="$(git -C "$GRAPH" log -1 --format=%cI "$sha")"
  else v=NOSHA; sv=NOSHA; t=-; fi
  echo "${f##*/} | gate:${gt} | ${sha:0:7} | ${t} | ${v:-NOFILE} | ${sv:-NOFILE} | ${rt} | ${mk:--}"
done)"
printf '%s\n' "$ROWS"
echo "== plans: $(printf '%s\n' "$ROWS" | grep -c .)"
echo "== by version (field 5):"
printf '%s\n' "$ROWS" | awk -F' [|] ' '{ c[$5]++ } END { for (k in c) print "  " k " " c[k] }' | sort
