#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-record.sh -- the RECORD-MODE (--escalations) entry-contract cells, asked IN PROCESS.
# Driven by run.sh. The join is sourced ONCE (its BASH_SOURCE guard stops it after the contract functions),
# and each cell runs the join's own record_tail in a SUBSHELL, with the globals the top level would have set
# for that world (SRCMODE=2, SPRINT, JR_ROOT, STATE, STATE_PARENT), so `exit`, refuse_n and every ESC_*/GAP_*
# global reset per cell. record_tail and the SPEC-render functions it calls sit above the source guard, so
# sourcing defines them; no join logic is copied here. What stays end to end in run.sh: DK1 and DK2 (the CLI's one refusal and one pass,
# and the cells the DKm mutant is gated on), EC39a (gates EC39m), LN6 (gates LN6m; two records and the lane-name
# die live in the argument block, not in record_tail), and every parts-mode, --sources and spec-memlog cell.
# The CLI entry (argument parse, content-seal check, the n_disp die) is not reached here; ER0 pins the seam.
#
# The predicates are lib.sh's own: esc_rec and ruling_world are redefined below to call the seam, and each
# p_* cell then runs unchanged. p_gaploc calls the join directly, so its in-process twin is restated here.
#
# Exit: 0 every cell passed, 1 a cell failed, 2 the fixture could not run.
set -u
NAME="remediator-shard-join-record"
UR_HERE="$(cd "$(dirname "$0")" && pwd)"
broken() { echo "FIXTURE BROKEN: $NAME: $1" >&2; exit 2; }
[ -f "$UR_HERE/lib.sh" ] || broken "lib.sh is absent beside $0"
# lib.sh resolves JOIN by walking UP in both layouts, scrubs AI_DLC_*, owns WORK and the one EXIT trap.
# shellcheck source=/dev/null
. "$UR_HERE/lib.sh" > /dev/null || broken "sourcing lib.sh failed"
JO="$WORK/unit.out"
# shellcheck source=/dev/null
. "$JOIN" || broken "sourcing $JOIN failed"
for _f in contract_check checks_field record_tail spec_render_probe spec_memlog_of_sprint spec_render_check spec_render_scan; do
  declare -F "$_f" >/dev/null || broken "$JOIN defined no $_f when sourced"
done

# uenter <root> <record> -> RC, $JO: what `AI_DLC_PROJECT_ROOT=<root> join --escalations <record> --sprint 305`
# prints, in a subshell. The values are the top level's own for that command line (join lines ~1469 and 1529-1550).
uenter() {
  (
    SRCMODE=2; SPRINT=305; PARTY=0; refuse_n=0
    JR_ROOT="$1"; _STATE_DIR="_bmad-output"; STATE="${JR_ROOT}/${_STATE_DIR}"
    STATE_PARENT="${STATE%/*}/"; STATE_PARENT_P="$STATE_PARENT"
    PA="${STATE}/planning-artifacts"; SEAT_DIR="${STATE}/party-mode/s${SPRINT}"
    record_tail "$2"
  ) > "$JO" 2>&1; RC=$?
}
esc_rec() { # <join, unused> <body> -> RC, $JO
  local w; w="$(mktemp -d "$WORK/esc.XXXXXX")" && mkdir -p "$w/.claude" || return 1
  printf '%b' "$2" > "$w/stories-repair-p1.md"
  [ ! -e "$w/_bmad-output/party-mode" ] || return 1
  uenter "$w" "$w/stories-repair-p1.md"
}
ruling_world() { # <join, unused> <body> -> RC, $JO
  local w; w="$(mktemp -d "$WORK/rul.XXXXXX")" && mkdir -p "$w/.claude" "$w/_bmad-output" || return 1
  printf '# log\n\n## 2026-10-15T23:51:50Z -- (typed)\n- SHA256: 1111111111111111111111111111111111111111111111111111111111111111\n' > "$w/_bmad-output/operator-requests-history.md"
  printf '# answers\n\n## Q1\n- SHA256: 2222222222222222222222222222222222222222222222222222222222222222\n' > "$w/_bmad-output/operator-answers-history.md"
  printf '%b' "$2" > "$w/rec.md"
  uenter "$w" "$w/rec.md"
}
# p_gaploc's world, driven through the seam (lib.sh's p_gaploc calls the join directly).
u_gaploc() {
  local w; w="$(mktemp -d "$WORK/gap.XXXXXX")" && mkdir -p "$w/.claude" "$w/d/sections" || return 1
  printf '# PRD\n\n## Net P&L\nShow - per D-5.\nThe card line.\n\n## Collect\nThe collect line.\n```text\nD-6\n```\n' > "$w/d/prd.md"
  printf 'document\t%s\npart\t05\t3\t6\t## Net P&L\npart\t06\t7\t11\t## Collect\n' "$w/d/prd.md" > "$w/d/sections/.manifest"
  printf '%b' '### F-4\n- disposition: repaired\n- edit: d/prd.md:5\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-5\n- disposition: repaired\n- edit: d/prd.md:8\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-7\n- disposition: repaired\n- edit: d/sections/5.md:2\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-8\n- disposition: repaired\n- edit: d/gone/9.md:2\n- siblings: n/a (insertion)\n- claim now asserted: a gap fill the lead may veto.\n\n### F-9\n- disposition: escalated\n- edit: n/a\n' > "$w/stories-repair-p1.md"
  uenter "$w" "$w/stories-repair-p1.md"
  [ "$RC" -eq 0 ] && ! has "$JO" "REFUSED" && has "$JO" "ESCALATED-COUNT: 1 (0 closed" \
    && has "$JO" "F-4 -- repaired while" && has "$JO" "-- lands in d/prd.md:5 under 'Net P&L', which cites D-5" \
    && has "$JO" "-- lands in d/prd.md:8 under 'Collect', which cites no D-, LR- or LRC- decision" \
    && has "$JO" "-- lands in $w/d/prd.md:4 (span of d/sections/5.md:2, lines may have moved) under 'Net P&L', which cites D-5" \
    && has "$JO" "-- location unresolved (d/gone/9.md:2)" \
    && [ "$(grep -n 'ESCALATED-COUNT' "$JO" | cut -d: -f1)" -lt "$(grep -n '^GAPFILL:' "$JO" | head -1 | cut -d: -f1)" ]
}

# ER0: the seam equals the CLI. One refusing and one passing record, run both ways on the SAME file; stdout+stderr
# (merged as the CLI cells merge them) and the exit code must be byte-identical, and the two worlds must differ.
sw="$(mktemp -d "$WORK/seam.XXXXXX")" && mkdir -p "$sw/.claude" || broken "cannot make the seam world"
printf '%b' '### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- siblings: n/a (insertion)\n\n### F-2 — MINOR\n- **Disposition:** frobnicated\n- edit: n/a\n' > "$sw/refuse.md"
printf '%b' '### F-1 — MAJOR\n- disposition: escalated\n- edit: n/a\n' > "$sw/pass.md"
seam_ok=1
for _k in refuse pass; do
  uenter "$sw" "$sw/$_k.md"; cp "$JO" "$sw/$_k.unit"; echo "$RC" > "$sw/$_k.unit.rc"
  AI_DLC_PROJECT_ROOT="$sw" bash "$JOIN" --escalations "$sw/$_k.md" --sprint 305 > "$sw/$_k.cli" 2>&1; echo "$?" > "$sw/$_k.cli.rc"
  cmp -s "$sw/$_k.unit" "$sw/$_k.cli" && cmp -s "$sw/$_k.unit.rc" "$sw/$_k.cli.rc" || seam_ok=0
done
if [ "$seam_ok" = 1 ] && ! cmp -s "$sw/refuse.unit" "$sw/pass.unit" && [ "$(cat "$sw/refuse.unit.rc")" = 2 ] && [ "$(cat "$sw/pass.unit.rc")" = 0 ]; then
  ok "ER0: the in-process record_tail answers byte-for-byte what --escalations prints and exits with, on a refusing record (rc 2) and a passing one (rc 0), and the two differ"
else
  bad "ER0: the in-process seam differs from the CLI, or the two worlds do not differ (seam_ok=$seam_ok refuse=$(cat "$sw/refuse.unit.rc")/$(cat "$sw/refuse.cli.rc") pass=$(cat "$sw/pass.unit.rc")/$(cat "$sw/pass.cli.rc"))"
fi

p_escopen "$JOIN" && ok "EC20: --escalations, no seat dir, one escalation open and one closed -> rc 0, the open one reported, ESCALATED-COUNT: 1, no SERIAL-REQUIRED" \
  || bad "EC20: --escalations did not report an open escalation on a non-party record (rc=$RC): $(cat "$JO")"
p_escclosed "$JOIN" && ok "EC21: --escalations, every escalation closed and a shard fence whose text the serial pass rewrote -> rc 0, ESCALATED-COUNT: 0" \
  || bad "EC21: --escalations did not pass a fully closed record (rc=$RC): $(cat "$JO")"
p_dispkey "$JOIN" && ok "EC22: an entry carrying edit: under a renamed key (outcome:) -> REFUSED, NODISP named; the dispositioned entry beside it is not" \
  || bad "EC22: an entry with edit: and no disposition: was not refused (rc=$RC): $(cat "$JO")"
p_dispvocab "$JOIN" && ok "EC23: a disposition outside the vocabulary in era -> REFUSED; not-reproduced and the pre-era value accepted" \
  || bad "EC23: the disposition vocabulary did not discriminate (rc=$RC): $(cat "$JO")"
p_dispruling "$JOIN" && ok "EC24: operator-ruling resolves by ISO heading and by SHA256 line with no source:; an unresolved and a missing cite REFUSED" \
  || bad "EC24: the operator-ruling cite did not discriminate (rc=$RC): $(cat "$JO")"
p_gapfill "$JOIN" && ok "EC26: a repaired claim calling the fix a gap fill for veto -> REPORTED after the escalation count, rc 0; the escalated entry in the same words is counted open, not reported" \
  || bad "EC26: the gap-fill tripwire did not discriminate (rc=$RC): $(cat "$JO")"
p_chkrec "$JOIN" && ok "EC28: --escalations -- a record with neither field is outside the era (rc 0); one that opened it without derivations: is REFUSED" \
  || bad "EC28: the check-fields era did not discriminate in record mode (rc=$RC): $(cat "$JO")"
p_rulingedit "$JOIN" && ok "EC29: an operator-ruling entry with a real edit and no siblings: in the era -> REFUSED as a repaired edit is; the ruling with edit: n/a beside it is not" \
  || bad "EC29: an operator-ruling edit escaped the repaired-edit checks (rc=$RC): $(cat "$JO")"
p_rulingtab "$JOIN" && ok "EC30: a TAB in a heading is not read as the ruling cite (the cite-less entry refused for that); a CRLF cite resolves" \
  || bad "EC30: a tab-split heading or a CRLF cite was misread (rc=$RC): $(cat "$JO")"
p_chkjoined "$JOIN" && ok "EC31: --escalations over a joined record -- an unrepaired shard's not replayed is exempt as the join exempted it; the repaired shard's is REFUSED" \
  || bad "EC31: the check fields were not judged per shard segment (rc=$RC): $(cat "$JO")"
p_chkserial "$JOIN" && ok "EC33: --escalations over a joined record with two serial blocks -- the second omitting both check lines is REFUSED naming its own terminator, the count still printed; stating both, rc 0" || bad "EC33: the serial blocks were not segmented by their terminators (rc=$RC): $(cat "$JO")"
p_supchain "$JOIN" && ok "EC34: --escalations, a supersedes: chain counts once under its latest member, the superseded one on its own ESCALATED-SUPERSEDED line; a closes: leaving a member open is FLAGGED after the count; a link to a later escalation is REFUSED as dangling" || bad "EC34: the supersedes chain did not dedupe, flag or refuse as specified (rc=$RC): $(cat "$JO")"
u_gaploc && ok "EC35:--escalations, a gap-fill edit's location is REPORTED after the count, rc 0 -- a section citing D-5 named, the adjacent section of the same file not, a dead section copy mapped through its manifest span, an unresolvable cite said so" || bad "EC35: the gap-fill location did not resolve as specified (rc=$RC): $(cat "$JO")"

if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
