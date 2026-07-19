#!/usr/bin/env bash
# Drive the check-15-bypass fixture (Check 16 — stub audit) and assert, for each seeded
# variant, WHICH element rejects it. Exit 0 = each adversary fails on its intended
# element and the honest control passes all four.
#
# WHAT THIS DOES NOT PROVE. Check 16 is `adjudication: llm` with `enforcer: []` — there
# is no validator script to drive, unlike check-17-bypass whose run.sh calls the real
# `validate-provenance-block.sh`. So this driver evaluates the check's OWN PUBLISHED
# ELEMENT REGEXES (gate-validation.md, `CHECK_LOADED: 16`) against the seed. It proves
# the FIXTURE's claim, not the ADJUDICATOR's behaviour: an LLM that ignores the
# published elements is not detected here and cannot be, from a script. Saying so is
# the point — a driver that implied otherwise would be a worse lie than the echo it
# replaces.
#
# WHY ASSERT THE ELEMENT AND NOT THE VERDICT. All five variants would be "rejected" by
# a check that rejected everything. Asserting only pass/fail passes on that bug. Each
# adversary here is built to satisfy every element but one, so the driver can name the
# element that fired — and the honest control (V5) is the mutant-detector that goes red
# if any element is broken into always-rejecting.
#
# ONE INTERPRETATION IS MADE EXPLICIT. Element 4's regex is `^`-anchored
# (`^deferral-reason:\s+\S.{19,}`) but the text it inspects is a COMMENT BLOCK, where
# every line carries a `#`/`//` prefix. Read literally the anchor can never match in a
# real source file. This driver strips a leading comment prefix before applying the
# anchored regex — the reading an adjudicator would take. If the check body is ever
# tightened, tighten this with it.
#
# Usage: run.sh

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- the check's published regexes, quoted from gate-validation.md CHECK_LOADED: 16
STUB_MARKER='(stub|TODO|FIXME|wired later|Phase [0-9]|NotImplementedError)'
E1_ITEM='Item [0-9]+'
E3_FILE_LINE='(^|[[:space:]])[^[:space:]]+:[0-9]+([[:space:]]|$)'
E4_REASON='^deferral-reason:[[:space:]]+[^[:space:]].{19,}'
CONTEXT_LINES=5           # "preceding 5 lines + the matched line"
DENSITY_MIN=10            # ">=10 non-whitespace characters" in the reason body

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TREE="$(bash "$HERE/seed.sh" "$WORK")"
BACKLOG="$TREE/_bmad-output/planning-artifacts/carry-over-backlog.md"
[ -f "$BACKLOG" ] || { echo "FAIL: seed did not produce a backlog at '$BACKLOG'" >&2; exit 2; }

fails=0
note() { printf '  %-6s %-30s %s\n' "$1" "$2" "$3"; }

# Strip a leading comment prefix so the ^-anchored element-4 regex can see the key.
decomment() { sed -E 's/^[[:space:]]*(#+|\/\/|--)[[:space:]]?//'; }

# audit_file <path> -> prints the name of the FIRST failing element, or "ok"
audit_file() {
  local f="$1" nlines n start block dec item backlog_line reason density
  nlines="$(wc -l < "$f")"
  for (( n = 1; n <= nlines; n++ )); do
    sed -n "${n}p" "$f" | grep -qE "$STUB_MARKER" || continue
    start=$(( n - CONTEXT_LINES )); [ "$start" -lt 1 ] && start=1
    block="$(sed -n "${start},${n}p" "$f")"
    dec="$(printf '%s\n' "$block" | decomment)"

    # element 1 — a numbered carry-over item reference
    printf '%s\n' "$block" | grep -qE "$E1_ITEM" || { echo "element1-item-ref"; return; }

    # element 2 — that item is OPEN or IN SPRINT in the backlog
    item="$(printf '%s\n' "$block" | grep -oE "$E1_ITEM" | head -1 | grep -oE '[0-9]+')"
    backlog_line="$(grep -E "^- Item ${item}[^0-9]" "$BACKLOG" || true)"
    printf '%s\n' "$backlog_line" | grep -qE '^- Item [0-9]+.*(OPEN|IN SPRINT [0-9]+)' \
      || { echo "element2-item-open"; return; }

    # element 3 — a file:line reference
    printf '%s\n' "$block" | grep -qE "$E3_FILE_LINE" || { echo "element3-file-line"; return; }

    # element 4 — deferral-reason length floor AND non-whitespace density
    printf '%s\n' "$dec" | grep -qE "$E4_REASON" || { echo "element4-reason"; return; }
    reason="$(printf '%s\n' "$dec" | sed -nE 's/^deferral-reason:[[:space:]]+//p' | head -1)"
    density="$(printf '%s' "$reason" | tr -d '[:space:]' | wc -c | tr -d ' ')"
    [ "$density" -ge "$DENSITY_MIN" ] || { echo "element4-reason"; return; }
  done
  echo "ok"
}

expect() { # expect <file> <want-element-or-ok> <label>
  local got; got="$(audit_file "$TREE/src/$1")"
  if [ "$got" = "$2" ]; then
    if [ "$2" = "ok" ]; then note "ok" "$3" "passes all four elements"
    else note "ok" "$3" "rejected on $got"; fi
  else
    note "BAD" "$3" "wanted '$2', got '$got'"
    fails=$((fails + 1))
  fi
}

echo "check-15-bypass: evaluating Check 16's published elements against the seed"
echo

expect v1_item_absent.py    element2-item-open "V1 item-absent"
expect v2_reason_tbd.py     element4-reason    "V2 reason-tbd"
expect v3_no_file_line.sh   element3-file-line "V3 no-file-line"
expect v4_reason_padding.py element4-reason    "V4 reason-padding"
expect v6_file_no_digits.py element3-file-line "V6 file-no-digits"
expect v7_item_closed.py    element2-item-open "V7 item-closed"

# The positive control. Break any element into always-rejecting and this goes red;
# without it, all four adversaries would still be "correctly" rejected.
expect v5_honest.py         ok                 "V5 honest control"

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  check-15-bypass: 7 variants correct. Each adversary is rejected on its"
  echo "      intended element (absent item, short reason, no file:line, padded reason,"
  echo "      digitless file ref, CLOSED item) and the honest stub satisfies all four."
  exit 0
fi
echo "FAIL  check-15-bypass: $fails variant(s) audited wrong." >&2
exit 1
