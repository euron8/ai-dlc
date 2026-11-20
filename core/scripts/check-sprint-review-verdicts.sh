#!/usr/bin/env bash
# check-sprint-review-verdicts.sh -- gate-validation.md Check 1's verdict-line grammar, as a program.
#
# USAGE
#   check-sprint-review-verdicts.sh [--gate 1|2|both] <review-file> [<review-file> ...]
#       --gate 1     read each value against code-reviewer.md's set (the default)
#       --gate 2     read each value against qa.md's set
#       --gate both  the file is cited for both gates; it passes only when its value is in both sets
#   Prints one line per file, `PASS <file> <value>` or `FAIL <file> <reason>`.
#   Exit 0 = every file PASS, 1 = at least one FAIL, 2 = refusal (no file, bad option, unreadable file).
#
# THE GRAMMAR (the single source; gate-validation.md Check 1 cites this file).
#   - A verdict line is a line matching VERDICT_PAT below.
#   - Value: start after the first `:` on the matched line, or at the start of the next non-blank line when the
#     line has no `:` or nothing after it; skip spaces and `*`. Take the run of capital letters and underscores.
#     It is the value only when the character after it is the end of the line, a space, `.`, `,`, `(`, `)` or
#     `*`; otherwise the WHOLE whitespace-delimited token is the value and lies outside every set.
#   - Zero matches FAIL. Two matches FAIL only when their values differ.
#   - A tracked-or-on-disk `-p<M>` sibling of the file's stem with a higher M supersedes it (M compared as a
#     number); both files are named in the output line.
#   - A file read at M >= 2 also runs validate-carried-findings.sh on the pair (M-1, M) when that program sits
#     beside this one: exit 1 or 2 there is a FAIL (an open carried finding under an approval, a prior finding
#     with no carried: line). Its output line is repeated.
# The value sets are the ones code-reviewer.md and qa.md declare under `## Verdict`.
set -uo pipefail

VERDICT_PAT='^[-#*[:space:]]*([A-Za-z][A-Za-z-]*[[:space:]]+)?(verdict|decision)[*[:space:]]*(:.*)?$'
CODE_PASS="APPROVED"
QA_PASS="PASS"

gate=1
while [ $# -gt 0 ]; do
  case "$1" in
    --gate) shift; gate="${1:-}"; shift || true ;;
    --) shift; break ;;
    -*) echo "check-sprint-review-verdicts: unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
case "$gate" in 1|2|both) ;; *) echo "check-sprint-review-verdicts: --gate takes 1, 2 or both" >&2; exit 2 ;; esac
[ $# -ge 1 ] || { echo "usage: check-sprint-review-verdicts.sh [--gate 1|2|both] <review-file>..." >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# read_values <file>: prints one value per verdict-line match.
read_values() {
  local f="$1" line n text rest tail run after c
  while IFS= read -r line; do
    n="${line%%:*}"; text="${line#*:}"
    rest=""
    case "$text" in *:*) rest="${text#*:}" ;; esac
    tail="$(printf '%s' "$rest" | sed 's/^[ *]*//')"
    if [ -z "$tail" ]; then
      tail="$(sed -n "$((n + 1)),\$p" "$f" | sed -n '/[^[:space:]]/{p;q;}' | sed 's/^[ *]*//')"
    fi
    run="$(printf '%s' "$tail" | sed -n 's/^\([A-Z_]*\).*/\1/p')"
    after="${tail#"$run"}"
    c="${after:0:1}"
    case "$c" in
      ""|" "|"."|","|"("|")"|"*") [ -n "$run" ] && { printf '%s\n' "$run"; continue; } ;;
    esac
    printf '%s\n' "${tail%%[[:space:]]*}"
  done < <(grep -inE "$VERDICT_PAT" "$f")
}

in_set() { # in_set <value> <gate-1|gate-2>
  case "$2" in
    gate-1) [ "$1" = "$CODE_PASS" ] ;;
    gate-2) [ "$1" = "$QA_PASS" ] ;;
  esac
}

# resolve <file>: prints the file Check 1 reads (highest -p<M> sibling of its stem), with M.
resolve() {
  local f="$1" d b stem best bestm cur m cand
  d="$(dirname "$f")"; b="$(basename "$f" .md)"
  stem="$b"; cur=1
  case "$b" in *-p[0-9]*) m="${b##*-p}"; case "$m" in *[!0-9]*) ;; *) stem="${b%-p*}"; cur="$m" ;; esac ;; esac
  best="$f"; bestm="$cur"
  for cand in "$d/$stem"-p[0-9]*.md; do
    [ -f "$cand" ] || continue
    m="${cand##*-p}"; m="${m%.md}"
    case "$m" in ''|*[!0-9]*) continue ;; esac
    if [ "$((10#$m))" -gt "$bestm" ]; then best="$cand"; bestm="$((10#$m))"; fi
  done
  printf '%s %s %s\n' "$best" "$bestm" "$stem"
}

rc=0
for f in "$@"; do
  [ -r "$f" ] || { echo "check-sprint-review-verdicts: cannot read $f" >&2; exit 2; }
  read -r rf rnum stem < <(resolve "$f")
  vals="$(read_values "$rf")"
  nvals=0; first=""; differ=0
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    nvals=$((nvals + 1))
    if [ "$nvals" -eq 1 ]; then first="$v"; elif [ "$v" != "$first" ]; then differ=1; fi
  done <<< "$vals"
  label="$f"; [ "$rf" != "$f" ] && label="$f -> $rf"
  if [ "$nvals" -eq 0 ]; then
    echo "FAIL $label zero verdict lines"; rc=1; continue
  fi
  if [ "$differ" -eq 1 ]; then
    echo "FAIL $label two verdict lines read different values"; rc=1; continue
  fi
  ok=1
  case "$gate" in
    1) in_set "$first" gate-1 || ok=0 ;;
    2) in_set "$first" gate-2 || ok=0 ;;
    both) in_set "$first" gate-1 && in_set "$first" gate-2 || ok=0 ;;
  esac
  if [ "$ok" -eq 0 ]; then
    echo "FAIL $label value '$first' is not in the gate $gate set"; rc=1; continue
  fi
  if [ "$rnum" -ge 2 ] && [ -x "$HERE/validate-carried-findings.sh" ]; then
    d="$(dirname "$rf")"
    if [ "$rnum" -eq 2 ]; then prev="$d/$stem.md"; else prev="$d/$stem-p$((rnum - 1)).md"; fi
    if [ -f "$prev" ]; then
      out="$("$HERE/validate-carried-findings.sh" "$prev" "$rf" 2>&1)"; crc=$?
      if [ "$crc" -ne 0 ]; then
        echo "FAIL $label carried findings: $(printf '%s' "$out" | head -1)"; rc=1; continue
      fi
    fi
  fi
  echo "PASS $label $first"
done
exit "$rc"
