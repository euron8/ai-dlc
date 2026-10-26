#!/usr/bin/env bash
# BL-807 receipt. Usage: bash receipt-bl807.sh [<join to drive>]     Run from the repo root.
# Drives the REAL join (or the copy named by $1) through this fixture's own world builders (lib.sh, the p_nl*
# and p_untilfut predicates): every ledger row is the REAL remediation-guard hook's, its clock pinned. Both claims:
#   claim 1  a lane round whose parts cite no file, over an empty ledger window, JOINS with the no-lane header
#            (graph's two-lane `edit: n/a` shape and the n/a + escalated shape); a lane citing an unledgered
#            edit, a lane agent whose only subject write lies outside the window, and a part record with no
#            ledger row each still REFUSE.
#   claim 2  an --until one hour past the join's clock REFUSES with the take-it-from-date remedy; one at the
#            join's clock joins.
# 0 = every world reads as above.
# 1 = a no-edit lane round (two lanes, or n/a + escalated) did not join with the no-lane header.
# 3 = a lane citing an unledgered edit was not refused with the 'records no dispatched write' line.
# 4 = a lane agent's subject write outside the window was not refused.
# 5 = a part record with no ledger row was not refused.
# 6 = an --until one hour in the future was not refused with the remedy.
# 7 = an --until at the join's clock did not join.
# 8 = a lane citing its unledgered edit in a spelling the token grammar cannot tokenise (no extension,
#     `.MD`, prose) was not refused: key 2 read tokens, not `edit:` values.
# 9 = the receipt could not run.
# 10 = a lane whose repaired (or operator-ruling) entry carries NO edit: line was not refused: an absent value read as no edit.
#      (Its twin, the entry `skipped (nit)`, must join, else exit 1.) The key is matched case-insensitively: `Disposition: Repaired` refuses too.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
FJ=core/fixtures/remediator-shard-join
[ -f "$FJ/lib.sh" ] && [ -f core/scripts/join-remediator-shards.sh ] \
  || { echo "REFUSED: run from the distribution root" >&2; exit 9; }
command -v jq >/dev/null 2>&1 || { echo "REFUSED: jq absent; the hook records nothing" >&2; exit 9; }
NAME=receipt-bl807
. "$FJ/lib.sh" > /dev/null || exit 9
J="${1:-$JOIN}"
[ -f "$J" ] || { echo "REFUSED: no join at $J" >&2; exit 9; }
command -v p_nl2lane >/dev/null 2>&1 && command -v p_nlnoedit >/dev/null 2>&1 && command -v p_untilfut >/dev/null 2>&1 \
  || { echo "REFUSED: lib.sh carries no BL-807 predicates" >&2; exit 9; }

p_nl2lane "$J" && p_nlesc "$J" || { echo "FAIL 1: a no-edit lane round did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; exit 1; }
p_nlcites "$J" || { echo "FAIL 3: a lane citing an unledgered edit (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; exit 3; }
for _sp in "\`$REL/story-2.1-positions-on-demand\` line 3" "\`$REL/story-2.1-positions-on-demand.MD:3\`" 'story 2.1, line 3 (positions on demand)'; do
  p_nlnoext "$J" "$_sp" || { echo "FAIL 8: a lane citing its unledgered edit off the token grammar ($_sp) (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; exit 8; }
done
p_nloutside "$J" || { echo "FAIL 4: a lane agent's out-of-window write (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; exit 4; }
p_nlnoedit "$J" || { echo "FAIL 10: a lane's repaired entry with no edit: line (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; exit 10; }
p_nlnoedit "$J" 'operator-ruling (F-3 is ruled)' || { echo "FAIL 10: a lane's operator-ruling entry with no edit: line (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; exit 10; }
p_nlnoedit "$J" 'Repaired' 'Disposition' || { echo "FAIL 10: a lane's capitalised 'Disposition: Repaired' entry with no edit: line (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; exit 10; }
p_nlnoedit "$J" 'skipped (nit)'
[ "$RC" -eq 0 ] || { echo "FAIL 1: a lane's skipped (nit) entry with no edit: line did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; exit 1; }
p_nlnorow "$J" || { echo "FAIL 5: a part with no ledger row (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; exit 5; }
p_untilfut "$J" 3600
[ "$RC" -eq 2 ] && has "$JO" "$FUT_TXT" || { echo "FAIL 6: --until now+1h (rc=$RC): $(head -1 "$JO")"; exit 6; }
p_untilfut "$J" 0
[ "$RC" -eq 0 ] && has "$JO" "JOINED:" || { echo "FAIL 7: --until now (rc=$RC): $(head -1 "$JO")"; exit 7; }
echo "OK: no-edit rounds join; cited, out-of-window and row-less lanes refuse; a future --until refuses and a current one joins"
exit 0
