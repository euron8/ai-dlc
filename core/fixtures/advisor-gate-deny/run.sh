#!/usr/bin/env bash
# advisor-gate-deny/run.sh — drive the REAL ai-dlc-advisor-gate.sh with synthesized PreToolUse
# JSON over seeded transcripts. The worlds, the cells, the arms and the scorer are in lib.sh
# beside this file; the arms are documented there.
#
# This fixture SHIPS and runs two passes: the shipped hook must fail no arm, and an unmutated copy
# of it in the mutant directory, beside a copy of its provenance sibling, must fail none either.
# The second pass is the battery's control, run here too so a consumer sees the harness work from
# a copied hook. The mutation battery that proves each arm can fail lives in the distribution-only
# directories advisor-gate-deny-mutants (shard a) and advisor-gate-deny-mutants-<x> beside it: it
# mutates core's own hook, which a consumer is denied editing, and it is ~97% of this subject's
# wall clock.
#
# Usage: run.sh
# Exit:  0 = both passes fail no arm, 1 = an arm failed, 2 = fixture broken.
set -uo pipefail
# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE ERROR: $HERE/lib.sh is absent; no cell exists to score" >&2; exit 2; }
# shellcheck source=lib.sh
. "$HERE/lib.sh"

echo "advisor-gate-deny:"
printf '  hook  %s\n' "$HOOK"
printf '  cells %s\n' "$nc"

printf 'HERMETIC-CONSUMED %s\n' "$HOOK"
[ -x "$HOOK" ] || bad "hook is not executable: $HOOK -- settings.json invokes it as a bare path"
GOT="$(score "$HOOK" "$W/failed.shipped")"
if [ -z "$GOT" ]; then
  ok "shipped hook passes every arm (PUSH REASON NOGRANT WITHDRAWN ORDER ERRCLEAR UNAV REARM MERGE CLOSE DELETE MENTION UPDATE UPDATEREF UPDATECUT WRAP STACK BASHC QUOTEDPAT PATHGIT BODY QUOTEDC QUOTEDENV GHREPO MCPNAME DETACHED MATE MATEABSENT MATEPUSH MATEPATH MATEREWRITE REDISPATCH DENIED ENVELOPE FAILED REREAD SELF SELFLAST PERKIND TWRITE TWRITEREAD GATELOG FAILOPEN EXIT)"
else
  bad "shipped hook fails arm(s): $GOT [cells: $(cells_of "$W/failed.shipped")]"
fi

[ -f "$PROV" ] && printf 'HERMETIC-CONSUMED %s\n' "$PROV"
[ -f "$PROV" ] && cp "$PROV" "$MUT/ai-dlc-context-provenance.sh"
cp "$HOOK" "$MUT/hook-control.sh"
CTL="$(score "$MUT/hook-control.sh" "$W/failed.control")"
[ -z "$CTL" ] && ok "unmutated copy from the mutant directory passes every arm" \
              || bad "unmutated copy fails [$CTL] -- the harness, not the hook, is what fails"

echo
if [ "$fails" -eq 0 ]; then echo "advisor-gate-deny: PASS"; exit 0; fi
echo "advisor-gate-deny: $fails assertion(s) FAILED" >&2
exit 1
