#!/usr/bin/env bash
# snapshot-conservation/seed.sh — a real git repository, because Check 35 is a
# git-derived join and a simulated one would prove nothing about the part that
# actually runs. The base sha is read back out of git after the commit rather than
# invented, so gate-metrics.jsonl points at a commit that genuinely exists.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-snapshot-conservation.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-snapshot-conservation.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-snapshot-conservation.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-snapshot-conservation.sh"
else
  echo "FIXTURE ERROR: validate-snapshot-conservation.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/snap-conserve.XXXXXX")" || exit 2
PROJ="$WORK/proj"
mkdir -p "$PROJ/_bmad-output/implementation-artifacts"

git -C "$PROJ" init --quiet 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git -C "$PROJ" config user.email "fixture@example.invalid"
git -C "$PROJ" config user.name "fixture"

SNAP="$PROJ/_bmad-output/pipeline-snapshot.md"
HIST="$PROJ/_bmad-output/pipeline-snapshot-history.md"

# 60 substantive lines. Each is well past the 20-character floor and each is unique,
# so a case that moves 50 of them cannot accidentally be satisfied by another line
# that happens to look the same.
{
  echo "# Pipeline Snapshot"
  echo
  echo "## Pipeline Position"
  echo "- Sprint 300 planning, architecture gate open, adversarial cycle at pass 3."
  echo
  echo "## Open Items"
  i=1
  while [ "$i" -le 60 ]; do
    printf -- '- OI-%02d gate disposition recorded, operator citation 2026-08-0%d, HARD_BLOCK resolved.\n' \
      "$i" "$(( (i % 9) + 1 ))"
    i=$((i+1))
  done
  echo
  echo "## Locked Decisions"
  echo "- The ETH-REWARDS Base v4 pool indexing track is the sprint's headline epic."
} > "$SNAP"

printf '# Pipeline Snapshot History\n\nWrite-only, Rule 25(a). Superseded snapshot content lands here.\n\n' > "$HIST"

git -C "$PROJ" add -A >/dev/null 2>&1
git -C "$PROJ" commit --quiet -m "seed: snapshot at the base gate" >/dev/null 2>&1 \
  || { echo "FIXTURE ERROR: base commit failed" >&2; exit 2; }

BASE="$(git -C "$PROJ" rev-parse HEAD)"
[ -n "$BASE" ] || { echo "FIXTURE ERROR: could not read the base sha back from git" >&2; exit 2; }

# gate-metrics.jsonl carries the base sha, exactly as a closed gate would have left
# it. The newest record is last, which is the order the validator walks backwards from.
GM="$PROJ/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
{
  printf '{"v":1,"sprint":300,"gate":"planning","ts":"2026-08-03T00:00:00Z","sha":"%s","check":"14","verdict":"PASS"}\n' "$BASE"
  printf '{"v":1,"sprint":300,"gate":"planning","ts":"2026-08-03T00:00:01Z","sha":"%s","check":"15","verdict":"PASS"}\n' "$BASE"
} > "$GM"

git -C "$PROJ" add -A >/dev/null 2>&1
git -C "$PROJ" commit --quiet -m "seed: close the base gate" >/dev/null 2>&1

cat > "$WORK/env.sh" <<EOF
VALIDATOR="$VALIDATOR"
WORK="$WORK"
PROJ="$PROJ"
BASE="$BASE"
export VALIDATOR WORK PROJ BASE
EOF

printf '%s\n' "$WORK"
