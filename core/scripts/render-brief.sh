#!/usr/bin/env bash
# render-brief.sh -- render a dispatch brief file whose Deliverable, shard and --mark lines are written by this
# script, never retyped by the lead. The dispatch prompt then carries one line, `Brief: <printed path>`, and the
# dispatch guard and ai-dlc-inflight-row.sh read the file's text for those lines (brief_expand in both hooks).
#
#   render-brief.sh --role <role> --step <step> [--shard <id>] --deliverable <path> --mark-step <step>
#                   [--field k=v ...] [--plan <join output>] --out DIR
#
# Writes DIR/<role>-<step>[-<shard>].md, prints its path. Exit 2 on a refusal: an empty deliverable, a missing
# argument, or a brief over 16384 bytes (context-mode cannot Read a larger file verbatim). The printed path must sit
# under <project>/_bmad-output/planning-artifacts/ for the guard to expand it. A `*.json` or `*.jsonl` deliverable gets
# no closing --mark line: a marker appended to it is not JSON and unseals a gate part; --mark-step is still required.
set -uo pipefail

# deliverable_of: byte-identical to the copies in ai-dlc-dispatch-guard.sh and ai-dlc-inflight-row.sh (I33 forbids
# sourcing one core file from another; the dispatch-model-guard fixture binds the three).
deliverable_of() {
  LC_ALL=C awk '
    /^Deliverable:/ {
      sub(/^Deliverable:[[:blank:]]*/, "")
      n = split($0, w, /[[:blank:]]+/)
      for (i = 1; i <= n; i++) {
        t = w[i]; gsub(/`/, "", t); sub(/^[(]+/, "", t); sub(/[.,;:)]+$/, "", t)
        if (t == "" || index(t, "|")) continue
        if (t ~ /\// || t ~ /\.[A-Za-z0-9]+$/) { print t; exit }
      }
      exit
    }'
}

die() { printf 'render-brief: %s\n' "$*" >&2; exit 2; }

ROLE=""; STEP=""; SHARD=""; DELIV=""; MSTEP=""; PLAN=""; OUT=""; FIELDS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --role|--step|--shard|--deliverable|--mark-step|--field|--plan|--out)
      [ $# -ge 2 ] || die "$1 needs a value" ;;
  esac
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --step) STEP="$2"; shift 2 ;;
    --shard) SHARD="$2"; shift 2 ;;
    --deliverable) DELIV="$2"; shift 2 ;;
    --mark-step) MSTEP="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --field)
      case "$2" in [A-Za-z_]*=*) ;; *) die "--field wants k=v, got '$2'" ;; esac
      FIELDS="${FIELDS}${2%%=*}: ${2#*=}
"; shift 2 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

[ -n "$ROLE" ] || die "--role is required"
[ -n "$STEP" ] || die "--step is required"
[ -n "$MSTEP" ] || die "--mark-step is required"
[ -n "$OUT" ] || die "--out is required"
[ -n "$DELIV" ] || die "--deliverable is empty: a brief with no deliverable would write no In-Flight row"
case "$ROLE$STEP$SHARD$MSTEP" in *[!A-Za-z0-9_./\ -]*) die "role, step, shard and mark-step take letters, digits and _ . / - only" ;; esac
case "$DELIV" in *[[:space:]]*|*'`'*|*'|'*) die "--deliverable must be one path with no blank, backtick or pipe" ;; esac
[ "$(printf '%s\n' "Deliverable: $DELIV" | deliverable_of)" = "$DELIV" ] \
  || die "--deliverable '$DELIV' is not a path the dispatch guard reads (needs a / or a dotted extension)"
if [ -n "$PLAN" ]; then
  case "$PLAN" in *[[:space:]]*) die "--plan is one path with no blank" ;; esac
fi

mkdir -p "$OUT" || die "cannot create $OUT"
SH_TAG=""; [ -n "$SHARD" ] && SH_TAG="-$(printf '%s' "$SHARD" | tr '/ ' '--')"
F="$OUT/${ROLE}-${STEP}${SH_TAG}.md"
MSH="${SHARD:-none}"

{
  printf '# Brief: %s, %s%s\n\n' "$ROLE" "$STEP" "${SHARD:+, shard $SHARD}"
  printf 'Deliverable: %s\n' "$DELIV"
  [ -n "$SHARD" ] && printf 'shard: %s\n' "$SHARD"
  [ -n "$PLAN" ] && printf 'gate-plan: %s\n' "$PLAN"
  [ -n "$FIELDS" ] && printf '%s' "$FIELDS"
  case "$DELIV" in
    *.json|*.jsonl) ;;
    *) printf '\nWhen the deliverable is written, run `scripts/ai-dlc/wait-for-deliverable.sh --mark %s %s %s %s findings=<n>` with <n> the number of findings in it (0 when none).\n' \
         "$DELIV" "$MSTEP" "$ROLE" "$MSH" ;;
  esac
} > "$F" || die "cannot write $F"

SZ="$(wc -c < "$F" | tr -d ' ')"
if [ "$SZ" -gt 16384 ]; then
  rm -f "$F"
  die "the brief is $SZ bytes, over the 16384-byte Read ceiling; shorten the fields or the plan"
fi
printf '%s\n' "$F"
