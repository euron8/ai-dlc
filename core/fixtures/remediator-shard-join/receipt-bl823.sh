#!/usr/bin/env bash
# BL-823 receipt. Usage: bash receipt-bl823.sh [<join-remediator-shards.sh to drive>]
# Run from the repo root. Drives `--escalations` over two seeded records, each in its own world, through
# a scratch copy of core/scripts (or the join named by $1, which must sit beside its siblings in a copy):
#   cap.md, an in-era entry dispositioned `- **Disposition:** frobnicated` (a capitalised LIST ITEM, an
#           out-of-set value) -> must be refused BADDISP by name;
#   sum.md, graph s292's column-0 summary `**Disposition:** 4 repaired / 0 escalated.` in the preamble and
#           inside an in-era repaired entry -> must join clean (rc 0, nothing refused).
# 0 = both hold.
# 1 = cap.md was not refused BADDISP: the capitalised list-item key is not read as the disposition.
# 3 = sum.md was refused: a summary line was read as a key (refused, or overwrote the entry's disposition).
# 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ -f core/scripts/join-remediator-shards.sh ] || { echo "REFUSED: run from the distribution root" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
mkdir -p "$T/s" || exit 9
cp core/scripts/*.sh "$T/s/" || exit 9
J="${1:-$T/s/join-remediator-shards.sh}"
[ -f "$J" ] || exit 9
run() { # <name> <body> -> rc; output in $T/<name>.out
  mkdir -p "$T/$1/.claude" || return 9
  printf '%b' "$2" > "$T/$1/rec.md" || return 9
  AI_DLC_PROJECT_ROOT="$T/$1" bash "$J" --escalations "$T/$1/rec.md" --sprint 305 > "$T/$1.out" 2>&1
}
run cap '### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- siblings: n/a (insertion)\n\n### F-2 — MINOR\n- **Disposition:** frobnicated\n- edit: n/a\n'
rc=$?
[ "$rc" = 9 ] && exit 9
[ "$rc" = 2 ] && grep -qF "the F-2 — MINOR entry is dispositioned 'frobnicated'" "$T/cap.out" || exit 1
run sum '**Disposition:** 4 repaired / 0 escalated.\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- siblings: n/a (insertion)\n\n### F-2 — MINOR\n- disposition: repaired\n- edit: n/a\n**Disposition:** 4 repaired / 0 escalated.\n'
rc=$?
[ "$rc" = 9 ] && exit 9
[ "$rc" = 0 ] && grep -qF 'ESCALATED-COUNT: 0' "$T/sum.out" && ! grep -qF 'REFUSED' "$T/sum.out" || exit 3
exit 0
