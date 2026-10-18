#!/usr/bin/env bash
# Receipt: a repair part closes with --mark, every axis's part join beat passes --complete, and the
# serial remediator renders SPEC.md before its --mark-repair. Usage: receipt-bl553.sh [<root>]
# 0 = the prose pins hold in a copy of <root>'s rulebook and the shipped beat reads an unmarked part
#     UNFINISHED under --complete and the marked part DELIVERED.
# 1 = a property failed.  9 = the subject is absent or the receipt could not run (no verdict).
# The pins are read by process-rule-pins' OWN --report, run from a copy, never re-implemented here.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
G="$ROOT/core/skills/ai-dlc/steps/_gate-procedures.md"; R="$ROOT/core/team-roles/remediator.md"
P="$ROOT/core/fixtures/process-rule-pins/run.sh"; WFD="$ROOT/core/scripts/wait-for-deliverable.sh"
for f in "$G" "$R" "$P" "$WFD"; do [ -f "$f" ] || { echo "REFUSED: subject absent: $f" >&2; exit 9; }; done
T="$(mktemp -d)" || exit 9
mkdir -p "$T/core/skills" "$T/core/fixtures/process-rule-pins" || exit 9
cp -R "$ROOT/core/skills/ai-dlc" "$T/core/skills/" && cp -R "$ROOT/core/team-roles" "$T/core/" \
  && cp "$P" "$T/core/fixtures/process-rule-pins/run.sh" || { echo "REFUSED: the copy failed" >&2; exit 9; }
OUT="$(bash "$T/core/fixtures/process-rule-pins/run.sh" --report 2>&1)"; prc=$?
case "$prc" in 0|1) : ;; *) echo "REFUSED: the pin report exited $prc: $(printf '%s\n' "$OUT" | head -2)" >&2; exit 9 ;; esac
rc=0
for id in gp-part-complete-files gp-part-complete-doc gp-part-complete-subj gp-part-mark gp-render-before-mark rem-part-mark rem-render-before-mark; do
  case "$OUT" in *"ok    $id: pinned"*) : ;; *) echo "FAIL: $id is not pinned"; rc=1 ;; esac
done
# The beat the prose prescribes, on the shipped engine: unmarked UNFINISHED, marked DELIVERED.
W="$(mktemp -d)" || exit 9
mkdir -p "$W/_bmad-output"
printf -- '- artifact: a.md\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: a.md:4\n' > "$W/04.md"
SI=$(( $(date +%s) - 30 ))
st() { ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_TEAMMATE_DIR="$W/none" AI_DLC_PROJECT_ROOT="$W" \
  bash "$WFD" --status --complete --since "$SI" 04.md 2>&1 ); }
o1="$(st)"
bash "$WFD" --mark "$W/04.md" stories remediator 04 findings=1 >/dev/null 2>&1 || { echo "FAIL: --mark refused the part"; rc=1; }
o2="$(st)"
case "$o1" in *"UNFINISHED 04.md"*) : ;; *) echo "FAIL: an unmarked part was not UNFINISHED under --complete: $o1"; rc=1 ;; esac
case "$o2" in *"DELIVERED 04.md"*) : ;; *) echo "FAIL: a marked part was not DELIVERED under --complete: $o2"; rc=1 ;; esac
[ "$rc" -eq 0 ] && echo "PASS: parts close with --mark and join under --complete; the serial render precedes --mark-repair"
exit "$rc"
