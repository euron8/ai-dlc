#!/usr/bin/env bash
# BL-877 receipt. Usage: bash receipt-bl877.sh [<join-remediator-shards.sh to drive>]
# Run from the repo root. The join named by $1 (default core/scripts/join-remediator-shards.sh) must sit beside
# its siblings; that whole directory is copied once per case under mktemp. Each case breaks ONE shared grammar
# function INSIDE ITS OWN DEFINITION (so a private copy elsewhere in the file is left whole), then drives the
# join's cheapest mode that reaches a self-probe call site:
#   ct   contract_check's `not-reproduced` vocabulary key renamed -> --escalations (record_tail, :1417) and
#        --check-part (:1756) must each refuse rc 2 with contract_probe's vocabulary die text;
#   sr   spec_render_scan's decision count dropped              -> --escalations (record_tail, :1423) must refuse
#        rc 2 with spec_render_probe's stale-render die text;
#   src  src_check's source count dropped                       -> --sources (:1773) must refuse rc 2 with
#        src_probe's resolving-source die text.
# The unbroken copy must reach each mode's verdict first (ESCALATED-COUNT, CHECK-PART, SOURCES; rc 0).
# The parts-mode sites (:2755, :2768, :2779) are owned by remediator-shard-join's PC cells.
# 0 = every probe fired on its broken grammar, and the unbroken join reached every verdict.
# 1 = a probe stayed quiet over its broken grammar: a call site removed or neutered, a probe that does not
#     check, or a probe reading a private copy of the grammar.
# 9 = the receipt could not run: a missing file, a break that matched nothing, or the unbroken join failed.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
J="${1:-core/scripts/join-remediator-shards.sh}"
[ -f "$J" ] || { echo "REFUSED: no $J (run from the distribution root)" >&2; exit 9; }
SD="$(cd "$(dirname "$J")" && pwd)" || exit 9
JB="$(basename "$J")"
T="$(mktemp -d)" || exit 9
trap 'rm -rf "$T"' EXIT
# brk <case> <function> <grammar text> <replacement> -- a whole-dir copy with that ONE line of <function> changed
brk() {
  mkdir -p "$T/$1" && cp -R "$SD"/. "$T/$1/" || exit 9
  F="$2" K="$3" N="$4" awk 'BEGIN { f = ENVIRON["F"] "() {"; k = ENVIRON["K"]; r = ENVIRON["N"] }
    $0 == f { in_ = 1 } in_ && $0 == "}" { in_ = 0 }
    in_ && (i = index($0, k)) { $0 = substr($0, 1, i - 1) r substr($0, i + length(k)) } { print }' "$J" > "$T/$1/$JB" || exit 9
  cmp -s "$J" "$T/$1/$JB" && exit 9
}
brk ct contract_check 'VOC["not-reproduced"] = 1' 'VOC["not-reproduced-x"] = 1'
brk sr spec_render_scan '{ if (r) { n++; if (!f) f = NR } }' '{ }'
brk src src_check 'n++; ns++' 'n++'
mkdir -p "$T/ok" && cp -R "$SD"/. "$T/ok/" || exit 9
W="$T/w"; mkdir -p "$W/.claude" "$W/_bmad-output/party-mode/s305" || exit 9
printf '### F-1 — MAJOR\n- disposition: escalated\n- edit: n/a\n' > "$W/rec.md" || exit 9
printf '# seat\n\n## F-1 (major) sections: 1\n' > "$W/_bmad-output/party-mode/s305/architecture-dev-1.md" || exit 9
printf '### F-1\n- disposition: repaired\n- source: architecture-dev-1.md#F-1\n' > "$W/src.md" || exit 9
esc() { AI_DLC_PROJECT_ROOT="$W" bash "$T/$1/$JB" --escalations "$W/rec.md" --sprint 305 > "$T/$1.esc" 2>&1; }
chk() { AI_DLC_PROJECT_ROOT="$W" bash "$T/$1/$JB" --check-part "$W/rec.md" > "$T/$1.chk" 2>&1; }
srcs() { AI_DLC_PROJECT_ROOT="$W" bash "$T/$1/$JB" --sources "$W/src.md" --sprint 305 > "$T/$1.src" 2>&1; }
# The unbroken join reaches every verdict, or nothing below is evidence.
esc ok && grep -qF 'ESCALATED-COUNT: 1' "$T/ok.esc" || exit 9
chk ok && grep -qF 'CHECK-PART:' "$T/ok.chk" || exit 9
srcs ok && grep -qF 'SOURCES:' "$T/ok.src" || exit 9
fired() { [ "$1" -eq 2 ] && grep -qF "$3" "$2" && ! grep -qF "$4" "$2"; }
esc ct; fired $? "$T/ct.esc" "the entry contract's self-probe failed: the disposition key and vocabulary read" 'ESCALATED-COUNT:' || exit 1
chk ct; fired $? "$T/ct.chk" "the entry contract's self-probe failed: the disposition key and vocabulary read" 'CHECK-PART:' || exit 1
esc sr; fired $? "$T/sr.esc" "the SPEC render arm's self-probe failed: a decision after a render read" 'ESCALATED-COUNT:' || exit 1
srcs src; fired $? "$T/src.src" "the source resolver's self-probe failed: a resolving source read" 'SOURCES:' || exit 1
exit 0
