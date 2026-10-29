#!/usr/bin/env bash
# BL-844 receipt (the gate-2 record-only route). Usage: bash receipt-bl844-route.sh <path to partition-review-diff.sh>
# Drives --route over a QA validation prior and merge-review-shards.sh --check-serial --gate qa, with
# validate-carried-findings.sh, merge-review-shards.sh, record-only-diff.sh and artifact-path-config.sh
# beside the given script, over this fixture's world (world.sh):
#   (a) QA prior EVIDENCE|BOOKKEEPING + a records-only delta                     -> ROUTE, exit 0
#   (b) the same + a part shard's hand-over finding (column-0 handover:, no Class) -> ROUTE, exit 0
#   (c) the same finding carrying only handover-run:                              -> FULL, exit 1
#   (d) a QA prior with a CODE finding + the records-only delta                   -> FULL, exit 1
#   (e) --check-serial --gate qa, qa.md declaring the Class template: Class: FOO REFUSED (exit 2),
#       Class: EVIDENCE on a routed serial file SERIAL-OK; qa.md with no template: FOO SERIAL-OK
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "REFUSED: usage: bash receipt-bl844-route.sh <path to partition-review-diff.sh>" >&2; exit 9; }
P="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
SD="$(dirname "$P")"; HERE="$(cd "$(dirname "$0")" && pwd)"
for f in validate-carried-findings.sh merge-review-shards.sh record-only-diff.sh artifact-path-config.sh; do
  [ -f "$SD/$f" ] || { echo "REFUSED: $f is not beside $P" >&2; exit 9; }
done
GR=""; GV=""; CR=""; QA=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for l in core .claude; do
    [ -n "$GR" ] || [ ! -f "$d/$l/skills/ai-dlc/artifact-path-grammar.md" ] || GR="$d/$l/skills/ai-dlc/artifact-path-grammar.md"
    [ -n "$GV" ] || [ ! -f "$d/$l/skills/ai-dlc/steps/gate-validation.md" ] || GV="$d/$l/skills/ai-dlc/steps/gate-validation.md"
    [ -n "$CR" ] || [ ! -f "$d/$l/team-roles/code-reviewer.md" ] || CR="$d/$l/team-roles/code-reviewer.md"
    [ -n "$QA" ] || [ ! -f "$d/$l/team-roles/qa.md" ] || QA="$d/$l/team-roles/qa.md"
  done
  d="$(dirname "$d")"
done
[ -n "$GR" ] && [ -n "$GV" ] && [ -n "$CR" ] && [ -n "$QA" ] || { echo "REFUSED: the grammar, gate-validation.md, code-reviewer.md or qa.md is not above the receipt" >&2; exit 9; }
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl844-route.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
. "$HERE/world.sh" || exit 9
rr_world "$W" "$GR" || exit 9
rr_qroot "$W/qroot" "$GV" "$CR" "$QA" || exit 9
rr_qserial "$W/qs-ev.md" EVIDENCE; rr_qserial "$W/qs-foo.md" FOO
fails=0
r() { bash "$P" --route "$W/repo" "$W/$1" "$(rr_ref "$W" "$2")" --exclude-captures "$W/captures" > "$W/o" 2>&1; echo $?; }
s() { AI_DLC_PROJECT_ROOT="$W/qroot/$1" bash "$SD/merge-review-shards.sh" --check-serial "$W/$2" --gate qa > "$W/o" 2>&1; echo $?; }
[ "$(r qprior-evidence.md RECORDS)" = 0 ] && grep -q '^ROUTE: ' "$W/o" || { echo "FAIL a: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(r qprior-handover.md RECORDS)" = 0 ] && grep -q '^ROUTE: ' "$W/o" || { echo "FAIL b: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(r qprior-horun.md RECORDS)" = 1 ] && grep -q '^FULL: ' "$W/o" || { echo "FAIL c: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(r qprior-code.md RECORDS)" = 1 ] && grep -q '^FULL: .*Class CODE' "$W/o" || { echo "FAIL d: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(s tpl qs-foo.md)" = 2 ] && grep -q "^REFUSED: .*'Class: FOO'" "$W/o" || { echo "FAIL e1: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(s tpl qs-ev.md)" = 0 ] && grep -q '^SERIAL-OK: ' "$W/o" || { echo "FAIL e2: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(s none qs-foo.md)" = 0 ] && grep -q '^SERIAL-OK: ' "$W/o" || { echo "FAIL e3: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$fails" -eq 0 ] || exit 1
exit 0
