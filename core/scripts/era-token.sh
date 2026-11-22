#!/usr/bin/env bash
# era-token.sh -- the ONE definition of the E4 forward-only marker and of the ONE era resolve. SOURCE this file; it prints
# nothing and runs nothing.
# The producer that OPENS a unit under the new engine writes this exact line into the unit's opening artifact; a refusal
# judges only a unit whose opening artifact carries it (`grep -qxF "$AI_DLC_ERA_TOKEN"`). It is a fixed string, never a
# version: a re-stamp of VERSION or .claude/.ai-dlc-version moves nothing. A unit with no such line reads `SKIP pre-era <unit>`.
# Sourced by: partition-document.sh, join-remediator-shards.sh, validate-adversarial-convergence.sh,
# merge-adversarial-shards.sh, strategy-rows.sh, strategy-self-check.sh (each resolves it beside itself, as it resolves its
# other siblings).
AI_DLC_ERA_TOKEN="ai-dlc-era: e4-forward-1"
# THE RESTART MARKER: partition-document.sh --shard-dir writes `$AI_DLC_ERA_RESTART <M>` as a second whole line of the
# `.era` it writes for a restarted cycle's first pass M (M >= 2); a restart stamped before this marker existed carries the
# token alone. Check 24 arm P1J and the coe sources rule in join-remediator-shards.sh judge a restart's opening pass M only
# when that line names M. Every other reader of `.era` matches the token as a whole line and ignores this one.
AI_DLC_ERA_RESTART="ai-dlc-era-restart:"
# THE ERA RESOLVE, asked by every reader of a review series' era (the per-round commit in partition-document.sh --shard-dir
# and join-remediator-shards.sh, the coe opening-pass sources rule, merge-adversarial-shards.sh --check-keys, Check 24 arm
# P1J and arm ATTESTATION): ai_dlc_era_open <sprint dir> <stem> <pass>.
#   OPENING PASS  the highest p <= <pass> whose shard dir `<sprint dir>/shards/<stem>-p<p>/` holds a `.era` file. Only
#                 partition-document.sh --shard-dir writes one, at pass 1 and at a restarted cycle's first pass (a pass
#                 M >= 2 opened while no adversarial, repair or serial-repair record of a pass below M stands in the
#                 sprint dir), SERIAL passes included. A pass of a dead cycle below the restart reads the dead cycle's
#                 own pass 1.
#   NO .era FILE  at or below <pass>: pass 1's `.era` path when `shards/<stem>-p1/` exists, else the pass-1 file, for a
#                 series whose pass 1 has no shard dir.
#   ANSWER        AI_DLC_ERA_OPEN is the opening pass and the return is 0 when that file carries the token as a whole
#                 line; AI_DLC_ERA_OPEN is empty and the return is 1 otherwise. One grep per call, none when the token
#                 is empty.
ai_dlc_era_open() {
  AI_DLC_ERA_OPEN=""
  local d="$1" s="$2" p="$3" f=""
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  p=$((10#$p))
  while [ "$p" -ge 1 ]; do
    [ -f "$d/shards/$s-p$p/.era" ] && { f="$d/shards/$s-p$p/.era"; break; }
    p=$((p - 1))
  done
  if [ -z "$f" ]; then
    p=1; f="$d/shards/$s-p1/.era"
    [ -d "$d/shards/$s-p1" ] || f="$d/$s-adversarial-p1.md"
  fi
  [ -n "${AI_DLC_ERA_TOKEN:-}" ] && grep -qxF -- "$AI_DLC_ERA_TOKEN" "$f" 2>/dev/null || return 1
  AI_DLC_ERA_OPEN="$p"
  return 0
}
