#!/usr/bin/env bash
# validate-gate3-tables.sh -- rule-table checkers for implementation gate 3, checks 4, 8, 10.
#
# Usage: validate-gate3-tables.sh <check> (--plan <g3 plan> | --story-file <p> --base <sha> --sha <sha>) [--root <repo>] [--sprint-status <path>]
#   <check>  one of 4 8 10
#   --plan   the gate-3 plan (reads `sha:`, `base:`, `story-file:`); sha is the frozen head
#   --root   the repo whose objects are read (default: the cwd's git toplevel). Only git object reads: nothing is
#            written and no worktree is needed, so a past gate can be re-judged from its plan.
#
# Output (one line, the generic gate program's native-arm protocol):
#   GATE-ARM <id> <PASS|FAIL|SKIP> examined=<n> <path:line | reason=<tok> | ok> <message>
# Exit: 0 PASS or SKIP, 1 FAIL, 2 usage/unreadable input. PASS is impossible when examined=0: that prints
# FAIL reason=examined-nothing.
# Input: --plan <g3 plan>, or --story-file <repo path> --base <sha> --sha <sha>.
#
# Each arm is the mechanical half of the check text in gate-validation.md; a check whose table cannot decide
# the whole text stays with the adjudicator (the map row says which: adjudication_by_gate).
# Wired: gates/implementation-g3.arms row 4 calls this through gate-run.sh (gate-transition.sh <story> 3). Checks 8 and 10 are proven here but
# held with the adjudicator pending an operator decision; checks 3, 7 and 19 stay with the adjudicator.
set -u

check="${1:-}"; shift || true
plan=""; root=""; ss_override=""; a_sha=""; a_base=""; a_story=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan) plan="${2:-}"; shift 2 ;;
    --root) root="${2:-}"; shift 2 ;;
    --sha) a_sha="${2:-}"; shift 2 ;;
    --base) a_base="${2:-}"; shift 2 ;;
    --story-file) a_story="${2:-}"; shift 2 ;;
    --sprint-status) ss_override="${2:-}"; shift 2 ;;
    *) echo "usage: $0 <4|8|10> (--plan <plan> | --story-file <p> --base <sha> --sha <sha>) [--root <repo>]" >&2; exit 2 ;;
  esac
done
case "$check" in 4|8|10) ;; *) echo "usage: $0 <4|8|10> ..." >&2; exit 2 ;; esac
if [ -n "$plan" ]; then [ -r "$plan" ] || { echo "REFUSED: plan unreadable: $plan" >&2; exit 2; }; fi
if [ -z "$root" ]; then root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "REFUSED: no repo" >&2; exit 2; }; fi
G() { git -C "$root" "$@"; }

field() { [ -n "$plan" ] || return 0; awk -v k="$1" 'index($0, k ":")==1 { sub(/^[^:]*:[ \t]*/, ""); print; exit }' "$plan"; }
head_sha="${a_sha:-$(field sha)}"; base_sha="${a_base:-$(field base)}"; story="${a_story:-$(field story-file)}"
[ -n "$head_sha" ] && [ -n "$base_sha" ] && [ -n "$story" ] || { echo "REFUSED: need sha, base and story-file (flags or --plan)" >&2; exit 2; }
G cat-file -e "${head_sha}^{commit}" 2>/dev/null || { echo "REFUSED: head $head_sha not in $root" >&2; exit 2; }
G cat-file -e "${base_sha}^{commit}" 2>/dev/null || { echo "REFUSED: base $base_sha not in $root" >&2; exit 2; }

verdict() { # <PASS|FAIL|SKIP> <examined> <reason>; GATE-ARM protocol: evidence is path:line (FAIL) or reason=<tok> (SKIP)
  local v="$1" n="$2" r="$3" ev="ok"
  if [ "$n" -eq 0 ] && [ "$v" != "FAIL" ]; then v="FAIL"; r="examined nothing: $r"; ev="reason=examined-nothing"; fi
  if [ "$v" = "FAIL" ] && [ "$ev" = "ok" ]; then ev="${story}:1"; fi
  if [ "$v" = "SKIP" ]; then ev="reason=not-in-scope"; fi
  echo "GATE-ARM $check $v examined=$n $ev $r"
  if [ "$v" = "FAIL" ]; then exit 1; fi
  exit 0
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/g3t.XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
G cat-file -e "${head_sha}:${story}" 2>/dev/null || { echo "REFUSED: story file $story absent at $head_sha" >&2; exit 2; }
G show "${head_sha}:${story}" > "$tmp/story.head"
G diff --name-only "$base_sha" "$head_sha" > "$tmp/changed"
G diff -U0 "$base_sha" "$head_sha" > "$tmp/diff"
awk '/^\+/ && !/^\+\+\+/' "$tmp/diff" > "$tmp/added"
n_changed="$(grep -c . "$tmp/changed")" || n_changed=0
sdir="${story%/*}"

case "$check" in
4)
  G ls-tree -r --name-only "$head_sha" -- "$sdir/" | awk '/\.md$/' > "$tmp/files"
  n="$(grep -c . "$tmp/files")" || n=0
  hits=0; empt=0
  while IFS= read -r f; do
    G show "${head_sha}:${f}" > "$tmp/f"
    h="$(grep -cE '\{\{.*\}\}|\[TODO\]|\[TBD\]|<placeholder>' "$tmp/f")" || h=0
    hits=$((hits + h))
    e="$(awk '
      /^#+[ \t]+.*Dev Agent Record/ { on=1; lv=match($0,/[^#]/); pend=""; next }
      on && /^#+[ \t]/ { l=match($0,/[^#]/); if (pend!="") bad++; pend=""; if (l<=lv) on=0; next }
      on && /^[ \t]*$/ { next }
      on { ind=match($0,/[^ \t]/); bul=($0 ~ /^[ \t]*[-*][ \t]/)
           isf=($0 ~ /^[ \t]*[-*]?[ \t]*\*{0,2}[A-Za-z][^:]{0,60}:\*{0,2}([ \t]|$)/)
           if (pend!="") { if (isf && ind<=pind && (!bul || pbul)) bad++; pend="" }
           if ($0 ~ /^[ \t]*[-*]?[ \t]*\*{0,2}[A-Za-z][^:]{0,60}:\*{0,2}[ \t]*$/) { pend=$0; pind=ind; pbul=bul } }
      END { if (pend!="") bad++; print bad+0 }' "$tmp/f")" || e=0
    empt=$((empt + e))
  done < "$tmp/files"
  if [ "$hits" -gt 0 ] || [ "$empt" -gt 0 ]; then verdict FAIL "$n" "placeholders=$hits empty_dev_record_fields=$empt"; fi
  verdict PASS "$n" "placeholders=0 empty_dev_record_fields=0"
  ;;
8)
  awk 'tolower($0) ~ /deployment (is )?complete|deployed (to|and|successfully)|deploy(ment)? (succeeded|done)/ && tolower($0) !~ /deploy-pending|not deployed|will be deployed|to be deployed|pending/' "$tmp/added" > "$tmp/claims"
  nc="$(grep -c . "$tmp/claims")" || nc=0
  [ "$n_changed" -gt 0 ] || verdict SKIP 0 "empty delta"
  if [ "$nc" -eq 0 ]; then verdict SKIP "$n_changed" "no deployment claim in added lines"; fi
  miss=""
  for k in first_run_failures transient_failures_cleared_on_retry persistent_failures per_action_attribution; do
    grep -qF "$k" "$tmp/added" || miss="$miss $k"
  done
  if [ -n "$miss" ]; then verdict FAIL "$nc" "deployment claimed ($nc line(s)); smoke fields missing:$miss"; fi
  verdict PASS "$nc" "deployment claimed with all four smoke fields"
  ;;
10)
  awk '!/^(docs\/|_bmad-output\/|\.claude\/)/ && !/(^|\/)tests?\// && !/\.md$/ && tolower($0) ~ /\.(graphql|gql|proto)$|schema|openapi|swagger|(^|\/)queries?\/|(^|\/)api\//' "$tmp/changed" > "$tmp/sch"
  ns="$(grep -c . "$tmp/sch")" || ns=0
  if [ "$ns" -eq 0 ]; then verdict SKIP "$n_changed" "no query/schema/API file in the delta"; fi
  if grep -qiE 'field[- ]by[- ]field' "$tmp/added" "$tmp/story.head"; then verdict PASS "$ns" "schema files touched; field-by-field evidence present"; fi
  verdict FAIL "$ns" "schema/API files touched ($(head -3 "$tmp/sch" | tr '\n' ' ')) with no field-by-field verification evidence"
  ;;
esac
