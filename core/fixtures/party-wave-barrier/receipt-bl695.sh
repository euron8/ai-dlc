#!/usr/bin/env bash
# receipt-bl695.sh [audit-party-wave-barrier.sh] -- the BL-695 item (a) receipt: the shipping detector
# FOLLOWS a lead's delegated coordinator round. Every world is seeded by the detector's own --seed and
# the detector is RUN on it (never a grep of its prose).
#
#   u     a lead whose one general-purpose call delegates the round to coordinator ac01, written at
#         <lead>/subagents/agent-ac01.jsonl; the coordinator holds a barrier. PASS when the detector
#         exits 1 with a FINDING whose transcript names `/subagents/agent-`: the followed file judged.
#   v     the same coordinator answering each delivery before its next wait. PASS on exit 0.
#   r     a LEAD file with a stray sidechain Agent call after a delivery. PASS on exit 1: the lead
#         still drops sidechain records, so the follow did not turn the filter off for leads.
#   w     u's lead with no coordinator file. PASS on exit 0 with `delegated-missing=1` on stderr.
#   side  u's coordinator file: every line carries `"isSidechain":true`, the two counts equal and > 0,
#         so a detector that kept the sidechain filter on a followed file could not have read it.
#
# Exit 0 when all five cells PASS, 1 when any FAILs, 9 when it cannot measure: no detector, or a
# world that did not build. The detector is $1, else the one found by walking up from this file for
# scripts/audit-party-wave-barrier.sh (it is distribution-only). Invoked by run.sh, which passes the
# detector it resolved.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DET="${1:-}"
if [ -z "$DET" ]; then
  d="$HERE"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -f "$d/scripts/audit-party-wave-barrier.sh" ] && { DET="$d/scripts/audit-party-wave-barrier.sh"; break; }
    d="$(dirname "$d")"
  done
fi
[ -n "$DET" ] && [ -f "$DET" ] || { echo "receipt-bl695: no detector (given: ${1:-none}; none found above $HERE)" >&2; exit 9; }

W="$(mktemp -d "${TMPDIR:-/tmp}/bl695.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
die() { echo "receipt-bl695: $1" >&2; exit 9; }
bash "$DET" --seed u "$W/u.jsonl" --seed v "$W/v.jsonl" --seed r "$W/r.jsonl" --seed w "$W/w.jsonl" || die "the detector could not seed u, v, r, w"
CO="$W/u/subagents/agent-ac01.jsonl"
[ -s "$CO" ] || die "seed u wrote no coordinator file at $CO"
fail=0

ou="$(bash "$DET" "$W/u.jsonl" 2>/dev/null)"; ru=$?
if [ "$ru" = 1 ] && grep -q '^FINDING [^ ]*/subagents/agent-' <<<"$ou"; then
  echo "CELL u PASS the barrier in the followed coordinator fires and names it: $(grep -m1 '^FINDING ' <<<"$ou" | cut -d' ' -f2)"
else
  echo "CELL u FAIL exit $ru, $(grep -m1 '^FINDING ' <<<"$ou" || echo 'no FINDING line')"; fail=1
fi

bash "$DET" "$W/v.jsonl" >/dev/null 2>&1; rv=$?
if [ "$rv" = 0 ]; then echo "CELL v PASS a coordinator refilling before each wait is quiet"
else echo "CELL v FAIL exit $rv"; fail=1; fi

bash "$DET" "$W/r.jsonl" >/dev/null 2>&1; rr=$?
if [ "$rr" = 1 ]; then echo "CELL r PASS a stray sidechain call in a LEAD file still answers nothing"
else echo "CELL r FAIL exit $rr"; fail=1; fi

ew="$(bash "$DET" "$W/w.jsonl" 2>&1 >/dev/null)"; rw=$?
if [ "$rw" = 0 ] && grep -q 'delegated-missing=1' <<<"$ew"; then
  echo "CELL w PASS an agentId with no file is counted delegated-missing, exit 0"
else
  echo "CELL w FAIL exit $rw, $(grep -m1 'given=' <<<"$ew" || echo 'no summary line')"; fail=1
fi

nl="$(grep -c . "$CO")" || nl=0
nm="$(grep -c '"isSidechain":true' "$CO")" || nm=0
if [ "$nl" -gt 0 ] && [ "$nl" = "$nm" ]; then
  echo "CELL side PASS all $nl records of the followed file are isSidechain:true"
else
  echo "CELL side FAIL $nm of $nl records carry isSidechain:true"; fail=1
fi
exit "$fail"
