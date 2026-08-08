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
D_ROOT="$(cd "$HERE/../../.." && pwd)"

for f in core/scripts/sprint-status.sh core/scripts/validate-mandatory-rules.sh \
         core/schemas/sprint-status.json; do
  [ -f "$D_ROOT/$f" ] || { echo "seed: missing $f under $D_ROOT" >&2; exit 2; }
done

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/story-corpus-sprint-slot.XXXXXX")"
mkdir -p "$ROOT/.claude/schemas" "$ROOT/scripts/ai-dlc" \
         "$ROOT/_bmad-output/implementation-artifacts" \
         "$ROOT/_bmad-output/planning-artifacts"

cp "$D_ROOT/core/schemas/sprint-status.json"          "$ROOT/.claude/schemas/"
cp "$D_ROOT/core/scripts/sprint-status.sh"            "$ROOT/scripts/ai-dlc/"
cp "$D_ROOT/core/scripts/validate-mandatory-rules.sh" "$ROOT/scripts/ai-dlc/"
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
