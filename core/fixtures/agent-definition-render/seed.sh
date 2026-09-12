#!/usr/bin/env bash
# agent-definition-render/seed.sh — build a scratch project whose `.claude/settings.json`
# declares a role set the arms can DISCRIMINATE on. Echoes the project root.
#
# THE SEEDED SET IS FOUR ROLES AND EVERY ONE OF THEM EXISTS TO SEPARATE TWO OUTCOMES:
#
#   alpha   model + a valid effort            -> a full definition, with an `effort:` line
#   bravo   model + NO effort key             -> a definition with NO `effort:` line, which is
#                                               the near-miss for "a missing effort is rendered
#                                               as something"
#   charlie NO model, effort only             -> NO file at all (the party-persona shape: their
#                                               model is /bmad-party-mode's to choose, and a
#                                               model-less definition would bind an effort onto
#                                               a spawn the dispatch guard is told to leave
#                                               alone)
#   delta   model + an INVALID effort         -> a definition whose effort line is OMITTED, and
#                                               a stderr report
#
# `alpha` IS DELIBERATELY NOT THE ONLY MEMBER AND NOT THE ONLY INTERESTING ONE. A seeded set of
# one cannot tell "iterated the declared roles" from "rendered the first one", and `charlie` and
# `delta` sit at positions 3 and 4 so an arm that stopped after the first entry fails rather
# than passing on a shorter corpus.
#
# A HAND-WRITTEN FOREIGN DEFINITION IS SEEDED TOO. The renderer must leave a consumer's own
# `.claude/agents/*.md` alone -- neither reported nor deleted -- and the only way to establish
# that is to have one present before it runs.
set -euo pipefail

WORK="$(mktemp -d)"
mkdir -p "$WORK/project/.claude/agents"

cat > "$WORK/project/.claude/settings.json" <<'JSON'
{
  "aiDlcModels": {
    "opus": "claude-opus-5[1m]",
    "sonnet": "claude-sonnet-5[1m]"
  },
  "aiDlcRoles": {
    "alpha":   { "model": "opus",   "effort": "xhigh" },
    "bravo":   { "model": "sonnet" },
    "charlie": { "effort": "high" },
    "delta":   { "model": "opus",   "effort": "turbo" }
  },
  "env": { "SOMETHING_ELSE": "1" }
}
JSON

# The consumer's OWN agent definition, carrying no generated marker. Present before the first
# render, so "left alone" is a measurement rather than an assumption.
cat > "$WORK/project/.claude/agents/my-own-helper.md" <<'OWN'
---
name: my-own-helper
description: written by the consumer, not by ai-dlc
model: sonnet
---
Do the thing.
OWN

# ECHO THE `mktemp` DIRECTORY, NEVER THE PROJECT INSIDE IT. The caller removes what this
# prints, and a caller handed `$WORK/project` has to climb back up to find the thing to delete.
# Measured, on the first cut of this fixture: `rm -rf "$(dirname "$(dirname "$p")")"` with `$p`
# the project root resolves to the SYSTEM TMPDIR and attempts to remove it. SIP refused most of
# it and the run reported PASS on ten arms it had just destroyed the worlds of. The caller
# deletes exactly what the seed prints, and the seed prints the directory it created.
printf '%s\n' "$WORK"
