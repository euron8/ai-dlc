#!/usr/bin/env bash
# advisor-gate-deny/run.sh — drive the REAL ai-dlc-advisor-gate.sh with synthesized PreToolUse
# JSON over seeded transcripts. The worlds, the cells, the arms and the scorer are in lib.sh
# beside this file; the arms are documented there.
#
# This fixture SHIPS and runs two passes: the shipped hook must fail no arm, and an unmutated copy
# of it in the mutant directory, beside a copy of its provenance sibling, must fail none either.
# The second pass is the battery's control, run here too so a consumer sees the harness work from
# a copied hook. The mutation battery that proved each arm can fail has been retired: it
# mutated core's own hook, which a consumer is denied editing, and it is ~97% of this subject's
# wall clock.
#
# The one committed mutant is scored per push on its deciding arm and one twin; the measured matrix
# replaces an exact-vector assertion and is re-measured whenever an arm or the mutant changes.
# The arm names are the ones lib.sh documents (and `--matrix` prints).
# MUTANT-MATRIX netcap10 decides=REREAD twins=UNAV
# MUTANT-MATRIX-REMEASURE bash core/fixtures/advisor-gate-deny/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit:  0 = both passes fail no arm, 1 = an arm failed, 2 = fixture broken.
set -uo pipefail
# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE ERROR: $HERE/lib.sh is absent; no cell exists to score" >&2; exit 2; }
# shellcheck source=lib.sh
. "$HERE/lib.sh"
MATRIX=0; MROWS=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi
ARMS="PUSH REASON MCPCONSULT NOGRANT WITHDRAWN ORDER ERRCLEAR UNAV REARM MERGE CLOSE DELETE MENTION UPDATE UPDATEREF UPDATECUT WRAP STACK BASHC QUOTEDPAT QUOTEDALT PATHGIT BODY QUOTEDC QUOTEDENV GHREPO MCPNAME DETACHED MATE MATEABSENT MATEPUSH MATEPATH MATEREWRITE REDISPATCH DENIED ENVELOPE FAILED REREAD WINDOW BMADONLY SELF SELFLAST PERKIND TWRITE TWRITEREAD GATELOG NOVERIFY HDRONLY FAILOPEN EXIT"
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
printf 'HERMETIC-CONSUMED core/fixtures/lib/mutant.sh\n'
. "$HERE/matrix.sh" || { echo "FIXTURE ERROR: matrix.sh not found" >&2; exit 2; }
printf 'HERMETIC-CONSUMED core/fixtures/advisor-gate-deny/matrix.sh\n'

echo "advisor-gate-deny:"
printf '  hook  %s\n' "$HOOK"
printf '  cells %s\n' "$nc"

printf 'HERMETIC-CONSUMED %s\n' "$HOOK"
[ -x "$HOOK" ] || bad "hook is not executable: $HOOK -- settings.json invokes it as a bare path"
# NET_CELLS=1 for the shipped hook only: rr-never pays its ADVISOR_GATE_NET-shortened safety net once, here (lib.sh REREAD).
GOT="$(NET_CELLS=1 score "$HOOK" "$W/failed.shipped")"
if [ -z "$GOT" ]; then
  ok "shipped hook passes every arm (PUSH REASON NOGRANT WITHDRAWN ORDER ERRCLEAR UNAV REARM MERGE CLOSE DELETE MENTION UPDATE UPDATEREF UPDATECUT WRAP STACK BASHC QUOTEDPAT QUOTEDALT PATHGIT BODY QUOTEDC QUOTEDENV GHREPO MCPNAME DETACHED MATE MATEABSENT MATEPUSH MATEPATH MATEREWRITE REDISPATCH DENIED ENVELOPE FAILED REREAD WINDOW BMADONLY SELF SELFLAST PERKIND TWRITE TWRITEREAD GATELOG NOVERIFY HDRONLY FAILOPEN EXIT)"
else
  bad "shipped hook fails arm(s): $GOT [cells: $(cells_of "$W/failed.shipped")]"
fi

[ -f "$PROV" ] && printf 'HERMETIC-CONSUMED %s\n' "$PROV"
[ -f "$PROV" ] && cp "$PROV" "$MUT/ai-dlc-context-provenance.sh"
cp "$HOOK" "$MUT/hook-control.sh"
# The copy differs from the shipped hook in its PATH only, and the one thing the hook resolves from its
# own path is the provenance sibling (warn(), the UNAV cell). So the control scores the arms that
# reach it or are cheapest to see work: UNAV (warn through the sibling), PUSH/REASON/ORDER/NOGRANT
# (deny and silent decisions), FAILOPEN, MATEABSENT, plus the netdef read and EXIT. The shipped pass
# above already ran every cell against the same logic.
CTL="$(SCORE_ARMS="UNAV PUSH REASON ORDER NOGRANT FAILOPEN MATEABSENT" score "$MUT/hook-control.sh" "$W/failed.control")"
# WHY the other 214 cells cannot differ: the hook reads nothing keyed on its own location except the
# provenance sibling, which only warn() sources, so a cell that never reaches warn() takes the same
# code path from either copy.
[ -z "$CTL" ] && ok "unmutated copy from the mutant directory passes the 13 cells covering every arm whose verdict can depend on the hook's path or its provenance sibling" \
              || bad "unmutated copy fails [$CTL] -- the harness, not the hook, is what fails"

# BL-752 mutant: a second `_netcap=10` line after the default. rr-never runs at ADVISOR_GATE_NET=2 and
# cannot see it; the NETDEF read of the unset-knob cap must, and must name only REREAD.
awk '{ print } /^_netcap=300$/ { print "_netcap=10" }' "$HOOK" > "$MUT/hook-netcap10.sh"
if cmp -s "$HOOK" "$MUT/hook-netcap10.sh"; then bad "mutant netcap10: DID NOT APPLY -- no _netcap=300 line to follow"
else
  # The mutant changes only the unset-knob default cap, which no cell reads (rr-late appends at 3s,
  # well inside 10s; the rest set a knob): only the netdef read in score() sees it. SCORE_ARMS names
  # no arm, so no cell is driven and netdef alone decides.
  if [ "$MATRIX" = 1 ]; then
    # --matrix: the mutant against EVERY arm (all cells, net cell included). A row is TRIPPED when the
    # arm is in the failed set; the shipped hook fails no arm, so a tripped arm diverges from it.
    MXF="$(NET_CELLS=1 score "$MUT/hook-netcap10.sh" "$W/failed.matrix")"
    for _a in $ARMS; do
      case " $MXF " in *" $_a "*) _w=TRIPPED; _k=yes ;; *) _w=GREEN; _k=no ;; esac
      matrix_row netcap10 "$_a" 0 "$_w" "$_k"; MROWS=$((MROWS + 1))
    done
    ok "MATRIX netcap10 measured against $MROWS arms"
  else
    # Per push: the deciding arm REREAD (via the netdef read; SCORE_ARMS names no cell arm, so no cell
    # is driven) must fail and the twin UNAV must stay green. The base flag is the shipped pass.
    _base=0; [ -z "$GOT" ] && _base=1
    MUTD="$(SCORE_ARMS="NONE" score "$MUT/hook-netcap10.sh" "$W/failed.netcap10")"
    TWIN="$(SCORE_ARMS="UNAV" score "$MUT/hook-netcap10.sh" "$W/failed.netcap10t")"
    if [ "$MUTD" = REREAD ] && grep -qx netdef "$W/failed.netcap10"; then
      mutant_killed "$_base" netcap10 "mutant netcap10: a second _netcap=10 line fails only REREAD, at the netdef read of the unset-knob cap"
    else bad "mutant netcap10: expected REREAD via netdef, got [$MUTD] cells [$(cells_of "$W/failed.netcap10")]"; fi
    # score() always runs the netdef read, so the twin's log holds exactly `netdef` when no UNAV cell tripped.
    [ "$(cells_of "$W/failed.netcap10t")" = netdef ] && ok "T-netcap10 twin UNAV stays GREEN under mutant netcap10 (only the netdef read, REREAD, trips)" \
      || bad "T-netcap10 twin UNAV tripped cells [$(cells_of "$W/failed.netcap10t")] from [$TWIN]"
  fi
fi
if [ "$MATRIX" = 0 ]; then
  [ "$MROWS" -eq 0 ] && ok "MX plain run executed no matrix-only cell (matrix rows=0)" || bad "MX plain run executed $MROWS matrix-only rows"
else
  _na="$(printf '%s\n' $ARMS | grep -c .)" || _na=0
  [ "$MROWS" -eq "$_na" ] && ok "MX matrix run measured $MROWS mutant x arm cells (1 mutant x $_na arms)" || bad "MX matrix run measured $MROWS cells, $_na expected"
fi

echo
if [ "$fails" -eq 0 ]; then echo "advisor-gate-deny: PASS"; exit 0; fi
echo "advisor-gate-deny: $fails assertion(s) FAILED" >&2
exit 1
