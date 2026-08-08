#!/usr/bin/env bash
# seed.sh — build a throwaway consumer tree whose story corpus can be put into either layout.
#
# Prints the temp root on stdout. Caller owns cleanup.
#
# Shaped like an installed consumer, not like the distribution: `.claude/schemas/` and
# `scripts/ai-dlc/` are where install.sh puts them, because the schema resolution under test is
# exactly the thing that differs between the two layouts (I33). A seed built in the distribution
# shape would exercise the arm a consumer never runs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT_OF="$(cd "$HERE/../../.." && pwd)"

# THE SEED'S SHAPE AND THE SEED'S SOURCES ARE TWO DIFFERENT LAYOUT QUESTIONS, AND THIS FILE GOT
# THE FIRST RIGHT AND THE SECOND WRONG. The tree it BUILDS is consumer-shaped, deliberately, for
# the reason in the header. The files it builds that tree FROM were resolved only as
# `<root>/core/...`, which exists in the distribution and nowhere else. Installed, this fixture
# lives at `tests/fixtures/story-corpus-sprint-slot/`, so the same walk lands on the consumer's
# repo root, `core/` is absent, and the seed exits 2 before a single assertion runs -- on EVERY
# consumer, byte-identical to upstream, with nothing for the operator to fix locally. Reported
# from the reference consumer during the 0.306.0 -> 0.314.0 pull and reproduced here: run from
# the distribution rc=0, run from an install-shaped tree `seed: missing core/scripts/
# sprint-status.sh`.
#
# This is invariant I33's rule -- never locate one core file by walking up from another -- and it
# is the SAME defect `layer-title-join`'s seed carries a paragraph about having been burned by,
# reintroduced in a fixture written eight releases later. Each source is now named outright in
# BOTH layouts rather than derived from the other.
pick() { for c in "$@"; do [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SPRINT_STATUS="$(pick "$ROOT_OF/core/scripts/sprint-status.sh"            "$ROOT_OF/scripts/ai-dlc/sprint-status.sh")"
MANDATORY="$(pick    "$ROOT_OF/core/scripts/validate-mandatory-rules.sh"  "$ROOT_OF/scripts/ai-dlc/validate-mandatory-rules.sh")"
SCHEMA="$(pick       "$ROOT_OF/core/schemas/sprint-status.json"           "$ROOT_OF/.claude/schemas/sprint-status.json")"
for v in "$SPRINT_STATUS" "$MANDATORY" "$SCHEMA"; do
  [ -n "$v" ] || { echo "seed: sprint-status.sh, validate-mandatory-rules.sh and sprint-status.json were not all found under $ROOT_OF in either the distribution layout (core/scripts, core/schemas) or the installed layout (scripts/ai-dlc, .claude/schemas)" >&2; exit 2; }
done

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/story-corpus-sprint-slot.XXXXXX")"
mkdir -p "$ROOT/.claude/schemas" "$ROOT/scripts/ai-dlc" \
         "$ROOT/_bmad-output/implementation-artifacts" \
         "$ROOT/_bmad-output/planning-artifacts"

cp "$SCHEMA"         "$ROOT/.claude/schemas/sprint-status.json"
cp "$SPRINT_STATUS"  "$ROOT/scripts/ai-dlc/sprint-status.sh"
cp "$MANDATORY"      "$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh"
# The three siblings Check 1/2/4 delegate to. Stubs: this fixture's subject is Check 6 and the
# story join, and a missing sibling makes the whole run exit before either is reached.
for s in validate-retro-evidence.sh validate-cycle-commits.sh validate-retro-prereq.sh; do
  printf '#!/bin/sh\nexit 0\n' > "$ROOT/scripts/ai-dlc/$s"
done
chmod +x "$ROOT/scripts/ai-dlc"/*.sh

# Both canonical copies, holding sprint 302 with two story entries keyed the way the schema's own
# header prescribes (`story-<sprint>-<M>:`). The KEY keeps the sprint; the FILE is what loses it.
for v in implementation-artifacts planning-artifacts; do
  cat > "$ROOT/_bmad-output/$v/sprint-status.yaml" <<'EOF'
sprint: 302
status: in_progress
stories:
  story-302-1:
    status: done
  story-302-2:
    status: in_progress
EOF
done

printf '%s\n' "$ROOT"
