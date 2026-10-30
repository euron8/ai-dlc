#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-parts.sh -- the PARTS-MODE and --sources ENTRY-CONTRACT refusals, asked IN PROCESS. Driven by run.sh.
#
# join-remediator-shards.sh is sourced once (its BASH_SOURCE guard stops it after the entry-contract functions), and
# every cell writes the PART FILES only -- no world, no hook drive, no ledger -- and calls the functions the join calls,
# in the order the join calls them:
#   parts mode  checks_refusals "$(checks_field 0 "$p")" per part; party only: src_refusals "$(src_check ...)" and
#               seat_complete_check; then contract_refusals 0 "$(contract_check 0 "$@")" over every part.
#   --sources   src_refusals, seat_complete_check, then record_tail's own calls: contract_refusals 1 over the record(s)
#               and checks_refusals "$(checks_field 1 "$r")" per record.
# Top-level globals the join sets are set the way it sets them (PARTMODE=0, CF_DEFER=0 in files mode, JR_ROOT,
# STATE_PARENT, SEAT_DIR); sib_control reads the first three for its file lookup.
#
# WHAT STAYS END TO END in run.sh, one per mode: EC32 (a parts-mode refusal: rc 2, nothing written, silence), PS1 (a
# parts-mode join), PS7 (--sources passes) and PS8 (--sources refuses). The unit cells cannot see that a refusal wrote
# nothing, that the path is this world's, or what record_tail PRINTS (the ESCALATED-COUNT line, SOURCES: header); EC9,
# EC12 and EC13 therefore assert the globals record_tail prints from (ESC_LINES, ESC_CLOSED, ESC_N, ESC_X).
#
# Exit: 0 every cell passed, 1 a cell failed, 2 the fixture could not run.
set -u
NAME="remediator-shard-join-unit"
UP_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$UP_HERE/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
# lib.sh walks UP for the join in both layouts, scrubs AI_DLC_*, owns WORK, the EXIT trap, ok/bad/fails.
. "$UP_HERE/lib.sh"
broken() { echo "FIXTURE BROKEN: $NAME: $1" >&2; exit 2; }
# shellcheck source=/dev/null
. "$JOIN" || broken "sourcing $JOIN failed"
for _f in contract_check contract_refusals checks_field checks_refusals src_check src_refusals seat_complete_check sib_control; do
  declare -F "$_f" >/dev/null || broken "$JOIN defined no $_f when sourced; nothing was asserted"
done

UN=0
# uw -> UW (root), UD (stories-repair-p1 part dir), UP (stories-party-repair-p1 part dir), the s305 seat dir
uw() {
  UN=$((UN + 1)); UW="$WORK/u$UN"; UD="$UW/$SLOT/shards/stories-repair-p1"; UP="$UW/$PRD"
  mkdir -p "$UD" "$UP" "$UW/_bmad-output/party-mode/s305" "$UW/$REL" || broken "cannot make a world"
  # the story files a siblings control names: sib_control looks them up under JR_ROOT
  local s; for s in "$S21" "$S22" "$S31"; do cp "$HERE/seed.$s" "$UW/$REL/$s" || broken "cannot seed $s"; done
}
# ustamp <dir>... -- stamp() of lib.sh in pure bash: append both check lines to each part lacking either field.
ustamp() {
  local d f c
  for d in "$@"; do
    for f in "$d"/*.md; do
      [ -f "$f" ] || continue
      c="$(<"$f")"
      [[ "$c" =~ (^|$'\n')[[:space:]-]*[\*_\`]*(advisor|derivations)[\*_\`]*: ]] && continue
      printf '\n%s\n' "$CHK_LINES" >> "$f"
    done
  done
}
# useam_parts <party 0|1> <part>... -> stdout+stderr of the join's entry-contract calls over those parts, in the join's order
useam_parts() {
  local party="$1" p; shift
  (
    refuse_n=0; PARTMODE=0; CF_DEFER=0
    JR_ROOT="$UW"; STATE_PARENT="$UW/"; SEAT_DIR="$UW/_bmad-output/party-mode/s305"
    for p in "$@"; do checks_refusals "$(checks_field 0 "$p")"; done
    if [ "$party" = 1 ]; then
      src_refusals "$(src_check "$SEAT_DIR" "$@")"
      seat_complete_check "$SEAT_DIR" "$@"
    fi
    contract_refusals 0 "$(contract_check 0 "$@")"
    printf '%s' "$ESC_LINES"
    echo "ESC_N=$ESC_N SERIAL_N=$SERIAL_N"
    echo "USEAM-REFUSED: $refuse_n"
  ) 2>&1
}
# useam_src <record>... -> the --sources calls (src_refusals, seat_complete_check, then record_tail's contract and check fields)
useam_src() {
  local r
  (
    refuse_n=0; PARTMODE=0
    JR_ROOT="$UW"; STATE_PARENT="$UW/"; SEAT_DIR="$UW/_bmad-output/party-mode/s305"
    src_refusals "$(src_check "$SEAT_DIR" "$@")"
    seat_complete_check "$SEAT_DIR" "$@"
    contract_refusals 1 "$(contract_check 1 "$@")"
    for r in "$@"; do checks_refusals "$(checks_field 1 "$r")"; done
    printf '%s' "$ESC_LINES"; printf '%s' "$ESC_CLOSED"
    echo "ESC_N=$ESC_N ESC_X=$ESC_X"
    echo "USEAM-REFUSED: $refuse_n"
  ) 2>&1
}
O=""
ohas() { case "$O" in *"$1"*) return 0 ;; esac; return 1; }
# ocount <line prefix> -> the number of output lines opening with it
ocount() { local l n=0; while IFS= read -r l; do case "$l" in "$1"*) n=$((n + 1)) ;; esac; done <<OCEOF
$O
OCEOF
  printf '%s' "$n"; }
oclean() { ohas "USEAM-REFUSED: 0"; }
orefused() { ! oclean && ohas "REFUSED: $1"; }

# ---------------------------------------------------------------------------------- the entry contract, parts mode
uw; rawpart "$UW" 01 2.1; rawpart "$UW" 02 2.2; rawpart "$UW" 03 3.1; ustamp "$UD"
O="$(useam_parts 0 "$UD"/*.md)"
if orefused "01.md: the N9 — MINOR entry is repaired with an edit and carries no 'siblings:' field" \
   && ohas "03.md: the M6 — MAJOR entry is repaired with an edit and carries no 'siblings:' field" && ! ohas "PENDING:" \
   && ohas "parts written before the install: re-dispatch the shards"; then
  ok "EC1: every part omits siblings: (total omission) -> REFUSED, each repaired edit named, no PENDING (the era is the install, not the parts)"
else bad "EC1: a part set omitting siblings: everywhere was not refused: $O"; fi

uw; sibpart "$UW" 01 "$S21"; sibpart "$UW" 02 "$S22"; sibpart "$UW" 03 "$S31"; ustamp "$UD"
O="$(useam_parts 0 "$UD"/*.md)"
if oclean && ! ohas "PENDING:" && ohas "ESCALATED: 01.md F-2 — MINOR" && ohas "ESCALATED: 03.md F-2 — MINOR" \
   && ohas "ESC_N=3 SERIAL_N=3"; then
  ok "EC2: every part carries siblings: -> contract holds, no PENDING, each escalated entry by part, ESC_N 3 and SERIAL_N 3 (the edit: n/a repairs not counted)"
else bad "EC2: a post-rule part set was refused, or its escalated entries were not read: $O"; fi

uw; sibpart "$UW" 01 "$S21"; sibpart "$UW" 02 "$S22"; rawpart "$UW" 03 3.1; ustamp "$UD"
O="$(useam_parts 0 "$UD"/*.md)"
orefused "03.md: the M6 — MAJOR entry is repaired with an edit and carries no 'siblings:' field" \
  && ok "EC3: EC2 one property apart, part 03 a repaired MAJOR with an edit and no siblings: -> REFUSED by name" \
  || bad "EC3: a repaired edit with no siblings: beside post-rule parts was not refused: $O"

uw; cp "$HERE/seed.block-setaside.md" "$UD/01.md"; ustamp "$UD"
O="$(useam_parts 0 "$UD"/*.md)"
orefused "01.md:1: the stories-sm-05.md#F-3 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside" \
  && ok "EC4: graph's s318 sm-05 F-3 entry, a repaired MAJOR set aside as outside this shard and not required -> REFUSED at its heading" \
  || bad "EC4: a set-aside MAJOR was not refused: $O"

uw; cp "$HERE/seed.block-handoff.md" "$UD/01.md"; ustamp "$UD"
O="$(useam_parts 0 "$UD"/*.md)"
if oclean && ohas "ESCALATED: 01.md stories-sm-05.md#F-3 (remainder) — MAJOR" && ohas "ESC_N=1 SERIAL_N=1"; then
  ok "EC5: the same entry split, the remainder escalated under the same source -> contract holds, ESCALATED: 01.md ... (remainder), ESC_N 1"
else bad "EC5: a handed-off split pair was refused or its escalated entry was not read: $O"; fi

sa_part() { # <claim tail> -- saworld's one part: a repaired MAJOR with an edit, its siblings line, the claim
  uw
  printf -- '### F-4 — MAJOR\n- disposition: repaired\n- edit: %s/%s:4\n- siblings: n/a (insertion)\n- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand. %s\n' \
    "$REL" "$S21" "$1" > "$UD/01.md"
  ustamp "$UD"
  O="$(useam_parts 0 "$UD"/*.md)"
}
sa_part 'The dashboard display in Story 1.4 is outside this shard.'
orefused "01.md:1: the F-4 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside" \
  && ok "EC10: a repaired MAJOR set aside only as 'outside this shard' -> REFUSED (the regex's first half)" \
  || bad "EC10: an 'outside this shard' set-aside was not refused: $O"
sa_part 'The dashboard display in Story 1.4 is not required for the AC to hold.'
orefused "01.md:1: the F-4 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside" \
  && ok "EC11: a repaired MAJOR set aside only as 'not required' -> REFUSED (the regex's second half)" \
  || bad "EC11: a 'not required' set-aside was not refused: $O"

sib_part() { # <siblings text, printf %b> -- sibworld's one part, in a world holding the story the control names
  uw
  printf '### F-4 — MAJOR\n- disposition: repaired\n%s\n%b- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand.\n' \
    "$SIBW_EDIT" "$1" > "$UD/01.md"
  ustamp "$UD"
  O="$(useam_parts 0 "$UD"/*.md)"
}
ec15=1
for _s in '- siblings: checked\n' \
          '- siblings:\n- note: re-checked by hand\n' \
          "- siblings:\n\n\`\`\`derived\n$SB_RN\n$SB_CTL\n1\n\`\`\`\n\n" \
          "- siblings:\n\n\`\`\`text\n$SB_CTL\n1\n\`\`\`\n\n" \
          "- siblings:\n\n\`\`\`text\n$SB_RN\n$SB_CTL\n0\n\`\`\`\n\n"; do
  sib_part "$_s"
  orefused "01.md: the F-4 — MAJOR entry is repaired with an edit and its 'siblings:' field is none of its four forms" || { ec15=0; EC15_O="$O"; }
done
[ "$ec15" = 1 ] \
  && ok "EC15: five wrong siblings spellings (checked, an empty value with no fence, a derived fence, a text fence missing its grep -rn, a control count of 0) -> each REFUSED as none of the four forms" \
  || bad "EC15: a wrong siblings spelling was accepted, or refused under another reason: ${EC15_O:-}"

uw
printf '### F-4 — MAJOR\n- disposition: repaired\n%s\n- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand; no sibling copy of the old title remains.\n' \
  "$SIBW_EDIT" > "$UD/01.md"; ustamp "$UD"
O="$(useam_parts 0 "$UD"/*.md)"
orefused "01.md: the F-4 — MAJOR entry is repaired with an edit and carries no 'siblings:' field" \
  && ok "EC16: no siblings: field, the word sibling in the claim prose -> REFUSED as a missing field (the reader keys on the field, never the word)" \
  || bad "EC16: an entry mentioning a sibling only in prose was not refused as NOSIB: $O"

sib_part "- siblings:\n\n\`\`\`text\n$SB_RN\n\$ grep -c -F 'loads lazily' $REL/$S21\n1\n\`\`\`\n\n"
orefused "01.md: the F-4 — MAJOR entry's siblings control counts 'loads lazily' in $REL/$S21, which holds it 0 times at the join" \
  && ok "EC17: a text fence whose control text was never written to the file -> REFUSED at the join, 0 times" \
  || bad "EC17: a siblings control naming absent text was not refused: $O"

uw; part "$UW" 01 2.1; part "$UW" 02 2.2; part "$UW" 03 3.1
{ printf -- '- advisor: called\n- derivations: not replayed\n\n'; cat "$UD/02.md"; } > "$UD/02.x" && mv "$UD/02.x" "$UD/02.md"
printf -- '- advisor: unavailable\n\n' > "$UD/03.x"; cat "$UD/03.md" >> "$UD/03.x"; mv "$UD/03.x" "$UD/03.md"
ustamp "$UD"
O="$(useam_parts 0 "$UD"/*.md)"
orefused "02.md: derivations: not replayed" && ohas "03.md: no derivations: line" && ! ohas "01.md: no" \
  && ok "EC27: parts mode -- a part stating derivations not replayed and a part with no derivations: line -> REFUSED by name; the stamped part beside them is not" \
  || bad "EC27: the check-fields arm did not discriminate in parts mode: $O"

# ---------------------------------------------------------------------------------- party repairs, parts mode
party_u() { uw; seat_seed "$UW" 305 || broken "cannot seed the seats"; }
party_run() { ustamp "$UP"; O="$(useam_parts 1 "$UP"/*.md)"; }

party_u
ppart "$UW" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"
ppart "$UW" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
ppart "$UW" 03 3.1 "architecture-dev-1.md#F-4"
party_run
orefused "03.md: source architecture-dev-1.md#F-4 is UNRESOLVED -- architecture-dev-1.md carries no finding F-4" && ohas "(F-4 is in: architecture-tea-1.md)" \
  && ok "PS2: the same world with F-4 cited under dev-1 (only tea-1 carries F-4) -> REFUSED 'is UNRESOLVED', naming the seat that does" \
  || bad "PS2: a source whose id only another seat carries was not refused as UNRESOLVED: $O"

party_u
ppart "$UW" 01 2.1 "architecture-dev-1.md#F-1"
ppart "$UW" 02 2.2 "architecture-dev-1.md#F-2"
part "$UW" 03 3.1; mv "$UD/03.md" "$UP/03.md" || broken "cannot move the sourceless part"
party_run
orefused "03.md: the entry 'M6 — MAJOR' carries a disposition and no 'source:' line" \
  && ok "PS3: a party part entry with a disposition and no source line -> REFUSED naming the entry" \
  || bad "PS3: a sourceless party entry was not refused: $O"

party_u
ppart "$UW" 01 2.1 "architecture-dev-1.md#F-1"
ppart "$UW" 02 2.2 "_bmad-output/party-mode/s304/architecture-dev-4.md#D4-1"
ppart "$UW" 03 3.1 "architecture-tea-1.md#F-4"
party_run
orefused "02.md: source _bmad-output/party-mode/s304/architecture-dev-4.md#D4-1 names a file outside" \
  && ok "PS4: a source naming the same seat file under party-mode/s304 (another sprint) -> REFUSED 'names a file outside'" \
  || bad "PS4: another sprint's seat file was accepted as a source: $O"

party_u; seat_mark "$UW" dev-1 tea-1 || broken "cannot mark the seats"
ppart "$UW" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"
ppart "$UW" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
ppart "$UW" 03 3.1 "architecture-tea-1.md#F-4"
party_run
orefused "seat file architecture-dev-4.md does not end in its 'seat-complete:' line" \
  && ok "PS10: every cited seat but dev-4 marked -> REFUSED naming dev-4" \
  || bad "PS10: a cited unfinished seat file beside finished ones was not refused: $O"

party_u; seat_mark "$UW" dev-1 tea-1 dev-4 || broken "cannot mark the seats"
ppart "$UW" 01 2.1 "architecture-architect-1.md#A1-1"
ppart "$UW" 02 2.2 "architecture-architect-1.md#A1-2"
ppart "$UW" 03 3.1 "architecture-architect-1.md#A1-3"
party_run
orefused "seat file architecture-architect-1.md does not end in its 'seat-complete:' line while its step 'architecture' is in the marker era" \
  && ok "PS11: the only cited seat (architect-1) unmarked, its step's uncited siblings marked -> REFUSED (the era is per step over the dir)" \
  || bad "PS11: a lone cited unmarked seat whose step is in the marker era was not refused: $O"

# ---------------------------------------------------------------------------------- --sources
src_u() { # <body, printf %b> -- a record no join wrote, in a world with the s305 seats
  uw; seat_seed "$UW" 305 || broken "cannot seed the seats"
  printf '%b' "$1" > "$UW/rec.md"
  O="$(useam_src "$UW/rec.md")"
}
src_u '### F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: n/a (no edit)\n- claim now asserted: the rest is outside this shard and not required.\n'
orefused "rec.md:1: the F-1 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside" \
  && ok "EC6: --sources on a record whose resolving entry sets a MAJOR aside -> REFUSED, the set-aside refusal named (PS7 is its ALLOW twin)" \
  || bad "EC6: --sources did not apply the set-aside arm: $O"

src_u '### F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: s305/stories/a.md:3\n'
if oclean && [ "$(ocount 'PENDING: 1 repaired edit(s) of this record precede its first entry carrying')" = 1 ]; then
  ok "EC7: --sources over a pre-rule record (a repaired edit, no siblings: anywhere) -> not refused, one PENDING line"
else bad "EC7: a pre-rule --sources record was refused or did not print one PENDING line: $O"; fi

src_u '### F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: s305/stories/a.md:3\n\n### F-2 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-2\n- edit: s305/stories/a.md:9\n- siblings: n/a (insertion)\n\n### F-3 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-3\n- edit: s305/stories/a.md:12\n'
if orefused "rec.md: the F-3 — MAJOR entry is repaired with an edit and carries no 'siblings:' field" \
   && ! ohas "the F-1 — MAJOR entry is repaired with an edit" && ! ohas "re-dispatch the shards"; then
  ok "EC8: --sources positional era: pre-rule entry, carrier, omitting entry -> REFUSED naming only the entry after the carrier"
else bad "EC8: the --sources positional era did not bind from its first carrier: $O"; fi

src_u '### F-1 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-1\n- edit: n/a\n\n### F-2 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-2\n- edit: n/a\n\n### F-3 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-3\n- edit: n/a (no edit)\n\n### F-3 (remainder) — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-3\n- edit: n/a\n\n### serial F-1 — MAJOR\n- disposition: repaired\n- source: _bmad-output/party-mode/s305/architecture-dev-1.md#F-1\n- edit: n/a (no edit)\n- closes: rec.md F-1 — MAJOR\n'
if oclean && ohas "ESCALATED: rec.md F-2 — MAJOR" && ohas "ESCALATED: rec.md F-3 (remainder) — MAJOR" \
   && ! ohas "ESCALATED: rec.md F-1 — MAJOR" && ohas "ESCALATED-CLOSED: rec.md F-1 — MAJOR" && ohas "ESC_N=2 ESC_X=1"; then
  ok "EC9: --sources: an escalated entry a later repaired entry names on closes: is CLOSED; the open one and the split remainder are open, ESC_N 2 ESC_X 1"
else bad "EC9: --sources escalated-entry closure answered wrongly: $O"; fi

src_u '<!-- shard: 01.md -->\n### F-2 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-2\n- edit: n/a (no edit)\n- closes: 01.md F-3 — MAJOR\n\n### F-3 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-3\n- edit: n/a (escalated: the other conjunct lies in 02.md)\n\n<!-- shard: 02.md -->\n### F-3 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-3\n- edit: n/a (no edit)\n'
if oclean && ohas "ESCALATED: 01.md F-3 — MAJOR" && ! ohas "ESCALATED-CLOSED:" && ohas "ESC_N=1 ESC_X=0"; then
  ok "EC12: --sources over a joined record: a LATER half-repair under the same source token in another part, and a closes: written BEFORE the escalation -> the escalation stays open (graph s318 dev-05#F-3)"
else bad "EC12: a token-sharing half repair or an earlier closes: closed an escalation: $O"; fi

src_u '<!-- shard: 01.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-1\n- edit: n/a\n\n<!-- shard: 02.md -->\n### F-1 — MAJOR\n- disposition: escalated\n- source: architecture-dev-1.md#F-1\n- edit: n/a\n\n### serial F-1 — MAJOR\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n- edit: n/a (no edit)\n- **closes:** `01.md F-1 — MAJOR`\n'
if oclean && ohas "ESCALATED-CLOSED: 01.md F-1 — MAJOR" && ohas "ESCALATED: 02.md F-1 — MAJOR" \
   && ! ohas "ESCALATED: 01.md F-1 — MAJOR" && ohas "ESC_N=1 ESC_X=1"; then
  ok "EC13: --sources: one heading escalated in 01.md AND 02.md, closes: names 01.md -> 01.md CLOSED, 02.md open, ESC_N 1"
else bad "EC13: a closes: line did not close exactly the part it names: $O"; fi

echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
