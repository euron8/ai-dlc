#!/usr/bin/env bash
# Receipt: a wide leaf round is run by ONE foreground round-dispatcher that ends in a return file, and
# the lead joins that file alone. Usage: receipt-bl538.sh [<root>]
# 0 = every r28-rd-* and dp-rd-* row of process-rule-pins reads `pinned` in a copy of <root>'s
#     rulebook: the Rule 28(a) carve-out, the scope (adversarial, elicitation and sharded party rounds
#     in; an unsharded party round on the Skill; repair, code review and QA out, each as its own
#     sentence), the sharded party round as per-seat role-bound spawns whose seat record is the
#     spawn-ledger row and the `--mark` line with no provenance block (gp-party-*, r20-*, gv17-*,
#     coe-* and srev-* rows), the FOREGROUND member join with
#     `AI_DLC_WAIT_BEAT_SECS=540` and `timeout: 600000`, `MISSING <path> <agentId> <kind>`, the return
#     grammar with REJECTED and UNLAUNCHED, the `rejected: ... cap=<N>` line, the return path outside
#     `shards/`, the lead's `--reset` re-arm and its STALLED path, the `--since`-alone return beat, the
#     covered-notification clause and its `failed` exception, and _dispatch-protocol.md's
#     "Round-dispatcher brief" with its brief files, its never-glob rule and its no-`name` spawns.
# 1 = a row is not pinned. The s321 shape is a lead woken once per member exit with no dispatcher.
# 9 = no verdict: the subject is absent or the pin report could not run.
# The pins are read by process-rule-pins' OWN --report, run from a copy, never re-implemented here.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
P="$ROOT/core/fixtures/process-rule-pins/run.sh"
for f in "$ROOT/core/skills/ai-dlc/rule-bodies/rule-28.md" "$ROOT/core/skills/ai-dlc/steps/_dispatch-protocol.md" "$P"; do
  [ -f "$f" ] || { echo "REFUSED: subject absent: $f" >&2; exit 9; }
done
T="$(mktemp -d)" || exit 9
mkdir -p "$T/core/skills" "$T/core/fixtures/process-rule-pins" || exit 9
cp -R "$ROOT/core/skills/ai-dlc" "$T/core/skills/" && cp -R "$ROOT/core/team-roles" "$T/core/" \
  && cp "$P" "$T/core/fixtures/process-rule-pins/run.sh" || { echo "REFUSED: the copy failed" >&2; exit 9; }
OUT="$(bash "$T/core/fixtures/process-rule-pins/run.sh" --report 2>&1)"; prc=$?
case "$prc" in 0|1) : ;; *) echo "REFUSED: the pin report exited $prc: $(printf '%s\n' "$OUT" | head -2)" >&2; exit 9 ;; esac
rc=0
for id in r28-rd-carveout r28-rd-scope-in r28-rd-repair-out r28-rd-review-out r28-rd-foreground r28-rd-beatsecs \
          r28-rd-timeout r28-rd-missing r28-rd-grammar r28-rd-rejected r28-rd-return-path r28-rd-reset r28-rd-stalled \
          r28-rd-return-dispatch r28-rd-covered r28-rd-covered-failed dp-rd-head dp-rd-briefs dp-rd-noglob dp-rd-noname \
          dp-rd-tpl-noname dp-rd-tpl-foreground dp-rd-tpl-shard-header dp-rd-tpl-dispatch-each \
          r28-rd-shard-header r28-rd-dispatch-each r28-rd-party-skill gp-party-shape gp-party-writer \
          gp-party-noblock r20-i-unsharded r20-v-writer r20-v-noblock gv17-seat-record gv17-seat-join coe-party-per-seat \
          srev-party-per-seat srev-waves-cite; do
  case "$OUT" in *"ok    $id: pinned"*) : ;; *) echo "FAIL: $id is not pinned"; rc=1 ;; esac
done
[ "$rc" -eq 0 ] && echo "PASS: a wide leaf round is run by one foreground round-dispatcher and joined on its return file"
exit "$rc"
