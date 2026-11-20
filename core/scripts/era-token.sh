#!/usr/bin/env bash
# era-token.sh -- the ONE definition of the E4 forward-only marker. SOURCE this file; it prints nothing and runs nothing.
# The producer that OPENS a unit under the new engine writes this exact line into the unit's opening artifact; a refusal
# judges only a unit whose opening artifact carries it (`grep -qxF "$AI_DLC_ERA_TOKEN"`). It is a fixed string, never a
# version: a re-stamp of VERSION or .claude/.ai-dlc-version moves nothing. A unit with no such line reads `SKIP pre-era <unit>`.
# Sourced by: partition-document.sh, join-remediator-shards.sh, validate-adversarial-convergence.sh,
# merge-adversarial-shards.sh, strategy-rows.sh (each resolves it beside itself, as it resolves its other siblings).
AI_DLC_ERA_TOKEN="ai-dlc-era: e4-forward-1"
