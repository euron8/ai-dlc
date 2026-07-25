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
# COMMENT-PREFIX STRIPPING. Element 4's regex is `^`-anchored but the text it inspects
# is a COMMENT BLOCK, where every line carries a `#`/`//`/`--` prefix — so the anchor
# matches nothing until the prefix is stripped. The check body now says to strip it;
# `decomment()` below is that step. This fixture is what surfaced the omission: the
# anchor had been unmatchable-as-written for the life of the check, invisible because
# an LLM adjudicator strips the prefix without being told to.
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

# --- the scope filter: upstream-owned paths are dropped before the marker grep.
# Resolve the real core-paths.sh by walking UP for either layout, same as seed.sh.
RESOLVER=""
d="$HERE"
while [ "$d" != "/" ]; do
  if [ -x "$d/core/scripts/core-paths.sh" ]; then RESOLVER="$d/core/scripts/core-paths.sh"; break
  elif [ -x "$d/scripts/ai-dlc/core-paths.sh" ]; then RESOLVER="$d/scripts/ai-dlc/core-paths.sh"; break; fi
  d="$(dirname "$d")"
done
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. `core-paths.sh` reaches a consumer on the pull
# that carries this file, and may land later in the same pull. "Resolver not installed" is
# NOT "exemption broken", and treating it as a hard error deadlocked the reference consumer:
# ai-dlc-update's self-update requires its derived fixtures green, so failing here blocked
# the very cycle that installs the resolver.
#
# In the DISTRIBUTION the resolver is always present, so its absence stays a hard exit 2 and
# upstream can never go green without running the scope filter. Only a consumer skips, and
# only the four ownership variants that need it (V8/V9/V10/V11) — every other variant is
# unaffected and still runs.
IS_DIST=0; [ -d "$HERE/../../../core/skills/ai-dlc" ] && IS_DIST=1
SKIP_OWNERSHIP=0
if [ -z "$RESOLVER" ]; then
  if [ "$IS_DIST" = 1 ]; then
    echo "FAIL: no core-paths.sh found walking up from $HERE — in the distribution the scope filter MUST be evaluable, and passing without it would report the exemption as working when it was never run." >&2
    exit 2
  fi
  SKIP_OWNERSHIP=1
fi

# in_scope <tree-relative-path> -> 0 in scope, 1 exempt (upstream-owned).
# Exit 2 from the resolver is NOT an exemption: the path stays in scope, per the
# check body ("could not determine ... the path stays in scope").
in_scope() {
  local rel="$1" rc
  ( cd "$TREE" && bash "$RESOLVER" --is-core "$rel" >/dev/null 2>&1 )
  rc=$?
  [ "$rc" -eq 0 ] && return 1
  return 0
}

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

expect() { # expect <tree-relative-path> <want-element-or-ok|exempt-upstream> <label>
  local got
  if in_scope "$1"; then got="$(audit_file "$TREE/$1")"; else got="exempt-upstream"; fi
  if [ "$got" = "$2" ]; then
    if [ "$2" = "ok" ]; then note "ok" "$3" "passes all four elements"
    elif [ "$2" = "exempt-upstream" ]; then note "ok" "$3" "dropped from scope — upstream-owned"
    else note "ok" "$3" "rejected on $got"; fi
  else
    note "BAD" "$3" "wanted '$2', got '$got'"
    fails=$((fails + 1))
  fi
}

echo "check-15-bypass: evaluating Check 16's published elements against the seed"
echo

expect src/v1_item_absent.py    element2-item-open "V1 item-absent"
expect src/v2_reason_tbd.py     element4-reason    "V2 reason-tbd"
expect src/v3_no_file_line.sh   element3-file-line "V3 no-file-line"
expect src/v4_reason_padding.py element4-reason    "V4 reason-padding"
expect src/v6_file_no_digits.py element3-file-line "V6 file-no-digits"
expect src/v7_item_closed.py    element2-item-open "V7 item-closed"

# The positive control. Break any element into always-rejecting and this goes red;
# without it, all four adversaries would still be "correctly" rejected.
expect src/v5_honest.py         ok                 "V5 honest control"

# The exemption pair. V8 satisfies zero elements and must NEVER reach the elements
# at all; V9 satisfies zero elements at a core-ADJACENT path and must reach them.
# Drop the exemption and V8 flips to element1-item-ref. Widen it to all of
# `.claude/` and V9 flips to exempt-upstream — a consumer stub going unaudited.
if [ "$SKIP_OWNERSHIP" = 1 ]; then
  printf '  SKIP   V8/V9/V10/V11 ownership pairs -- core-paths.sh is not installed in this\n'
  printf '         consumer yet; the resolver lands with this same pull. Every other variant ran.\n'
else
expect .claude/skills/ai-dlc-update/reconcile/apply.sh \
                                exempt-upstream    "V8 upstream-owned"
expect .claude/hooks/my-own-hook.sh \
                                element1-item-ref  "V9 consumer hook (control)"

# The FIXTURE-ownership pair, the same shape one directory over. tests/fixtures/ is
# SHARED: core ships its self-tests there and the consumer's own sit beside them. Drop
# the fixtures/ arm from to_consumer_glob() and V10 flips to element1-item-ref — a core
# fixture audited as consumer-authored, whose only remediation VACATES it, because those
# markers are what its own assertions read. Collapse the entries to a bare
# tests/fixtures/* and V11 flips to exempt-upstream — a consumer's own unaudited stub
# riding out on our exemption.
expect tests/fixtures/check-15-bypass/seed.sh \
                                exempt-upstream    "V10 core fixture"
expect tests/fixtures/check-15-bypass-local/seed.sh \
                                element1-item-ref  "V11 consumer fixture (control)"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  check-15-bypass: 11 variants correct. Each adversary is rejected on its"
  echo "      intended element (absent item, short reason, no file:line, padded reason,"
  echo "      digitless file ref, CLOSED item), the honest stub satisfies all four, and"
  echo "      both ownership pairs discriminate: the upstream-owned file and the core"
  echo "      fixture are dropped from scope while their consumer-owned neighbours at"
  echo "      adjacent paths are still audited."
  exit 0
fi
echo "FAIL  check-15-bypass: $fails variant(s) audited wrong." >&2
exit 1
