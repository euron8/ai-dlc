#!/usr/bin/env bash
# core/fixtures/suppression-lifetime/receipt-bl889.sh [<validator>] -- the BL-889 backlog receipt: a FAIL_WAIVED
# row is owned by the waiver it names. It re-fires an expired SUPPRESSED entry only when that entry
# IS the named waiver (C1), and an OVERRIDDEN entry naming the check stands down when the named
# waiver resolves to an OVERRIDDEN entry, or to a SUPPRESSED entry targeting that check (C2).
#
# Drives core/scripts/validate-suppression-lifetime.sh (or <validator>) on six worlds. Every world
# has one check, 22, recorded at three gates after the authorization, the latest FAIL_WAIVED (or a
# plain FAIL for c) under the waiver id W. The naming entries name Check 22 in prose.
#
#   a  an expired SUPPRESSED entry of 22, and W an OVERRIDDEN entry. Want: no expiry FAIL.
#   b  the expired SUPPRESSED entry IS W. Want: the expiry FAIL.
#   c  as a, latest row a plain FAIL. Want: the expiry FAIL.
#   d  an OVERRIDDEN entry naming 22, W an OVERRIDDEN entry written BELOW it. Want: no terminal FAIL.
#   e  a RESOLVED entry naming 22, W an OVERRIDDEN entry. Want: the terminal FAIL (exact match only).
#   f  an OVERRIDDEN entry naming 22, W a SUPPRESSED entry of check 16. Want: the terminal FAIL.
#
# Each verdict keys on its own message, never on the exit: C1's expiry line and C2's terminal line
# for the naming entry. Exit 0 when all six hold, 1 when any does not, 9 when it cannot measure
# (no validator, mktemp failed, or the control world -- an in-force run that must print its OK
# line with entries_scanned=2 -- did not). Behaviour only: no validator text is read.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
r889_root() { # walk up from $1 for a repository marker; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/scripts/validate-suppression-lifetime.sh" ] || [ -e "$d/.git" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
cant() { echo "receipt-bl889: cannot measure: $*" >&2; exit 9; }
ROOT="$(r889_root "$HERE")" || cant "no repository root above $HERE"
V="${1:-$ROOT/core/scripts/validate-suppression-lifetime.sh}"
[ -f "$V" ] || cant "no validator at $V"

P="$(mktemp -d "${TMPDIR:-/tmp}/bl889-receipt.XXXXXX" 2>/dev/null)" || P=""
[ -n "$P" ] && [ -d "$P" ] || cant "mktemp -d failed"
trap 'case "$P" in */bl889-receipt.??????) rm -rf "$P" ;; esac' EXIT

A0="2026-10-01T00:00:00Z"
W="[S320 gate] [lead] - 2026-10-28T01:00:00Z — the operator waiver for spawn row X"
NAMING="[S320 gate] [lead] - 2026-10-28T01:30:00Z — a second disposition"
SUPP="[S305 gate] [lead] - ${A0} — an old suppression"
printf 'checks:\n  - id: 16\n    title: gate-dormancy\n  - id: 22\n    title: spawn-ledger\n' > "$P/map.yaml"

gm() { # <file> <latest verdict> -- three gates after A0, the latest under waiver W
  local i=1 t
  : > "$1"
  for t in 2026-10-27T01:00:00Z 2026-10-27T02:00:00Z 2026-10-28T03:00:00Z; do
    if [ "$i" -lt 3 ]; then
      printf '{"ts":"%s","catalog":"core","check":"22","verdict":"FAIL_WAIVED","waiver_id":"%s"}\n' "$t" "$W" >> "$1"
    elif [ "$2" = FAIL ]; then
      printf '{"ts": "%s", "catalog": "core", "check": "22", "verdict": "FAIL"}\n' "$t" >> "$1"
    else
      printf '{"ts": "%s", "catalog": "core", "check": "22", "verdict": "FAIL_WAIVED", "waiver_id": "%s"}\n' "$t" "$W" >> "$1"
    fi
    i=$((i + 1))
  done
}
ent() { # <header> <status> [<suppresses> <expires>]
  printf '## %s\n**Status:** %s\n' "$1" "$2"
  [ -z "${3:-}" ] || printf '**Suppresses:** [core] %s — target\n**Expires after:** %s gates\n' "$3" "$4"
  printf '**Operator authorization:** %s | "Override, proceed"\n\n' "$A0"
}
named() { ent "$1" "$2"; printf 'Check 22 failed on another spawn row; output verified.\n\n'; }

OUT=""
run() { # <world> <latest verdict>
  gm "$P/$1.jsonl" "$2"
  OUT="$(bash "$V" --escalations "$P/$1.md" --gate-metrics "$P/$1.jsonl" --enforcement-map "$P/map.yaml" 2>&1)"
}
EXP_MSG='is past its lifetime and the check is'
TERM_MSG="names check(s) 22, which are recorded FAILING"

# The control: the same SUPPRESSED entry inside its lifetime, beside W. A validator that cannot
# read these worlds prints no OK line, and every absence below would read as a pass.
{ ent "$SUPP" SUPPRESSED 22 3; ent "$W" OVERRIDDEN; } > "$P/ctl.md"
run ctl FAIL_WAIVED
case "$OUT" in *"OK: entries_scanned=2 suppressed=1 "*) ;; *) cant "the control world printed no OK line over 2 entries" ;; esac

fails=0
want() { # <case> <present|absent> <message> [<entry line the message must carry>]
  local got=absent ctx
  case "$OUT" in *"$3"*) got=present ;; esac
  if [ "$got" = present ] && [ -n "${4:-}" ]; then
    ctx="$(grep -A1 -F -- "$3" <<<"$OUT")"
    case "$ctx" in *"entry: ## $4"*) ;; *) got=present-for-another-entry ;; esac
  fi
  if [ "$got" = "$2" ]; then echo "receipt-bl889: ok   $1: '$3' $got"
  else echo "receipt-bl889: FAIL $1: '$3' $got, want $2"; fails=$((fails + 1)); fi
}

{ ent "$SUPP" SUPPRESSED 22 1; ent "$W" OVERRIDDEN; } > "$P/a.md"; run a FAIL_WAIVED
want a absent "$EXP_MSG"
{ ent "$W" SUPPRESSED 22 1; } > "$P/b.md"; run b FAIL_WAIVED
want b present "$EXP_MSG"
{ ent "$SUPP" SUPPRESSED 22 1; ent "$W" OVERRIDDEN; } > "$P/c.md"; run c FAIL
want c present "$EXP_MSG"
{ named "$NAMING" OVERRIDDEN; ent "$W" OVERRIDDEN; } > "$P/d.md"; run d FAIL_WAIVED
want d absent "$TERM_MSG"
{ named "$NAMING" RESOLVED; ent "$W" OVERRIDDEN; } > "$P/e.md"; run e FAIL_WAIVED
want e present "$TERM_MSG" "${NAMING:0:89}"
{ named "$NAMING" OVERRIDDEN; ent "$W" SUPPRESSED 16 3; } > "$P/f.md"; run f FAIL_WAIVED
want f present "$TERM_MSG" "${NAMING:0:89}"

[ "$fails" -eq 0 ] || exit 1
exit 0
