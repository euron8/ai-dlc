#!/usr/bin/env bash
# Seed material for retro-compliance-workflow. Prints the seed dir on stdout.
#
# Emits, under $OUT:
#
#   probe-legacy.yml   a SYNTHETIC workflow carrying the pre-migration shape at all
#                      five sites. The self-probe's offender.
#   probe-fixed.yml    the same workflow with all five sites migrated AND the
#                      `--require-skill bmad-party-mode` declaration added. The
#                      self-probe's near-miss: every arm must stay quiet on it.
#   docs/blockless.md      a retro doc with no provenance block at all
#   docs/notranscript.md   a well-formed bmad-party-mode block with `transcript_path`
#                          DELETED — the variant that separates the flag from the path
#   docs/compliant.md      the known-good block, unmodified
#
# THE THREE DOCS ARE NOT HAND-WRITTEN HERE. `compliant.md` is lifted from
# check-17-bypass/seed.sh's V5, which is this repo's maintained known-good block and is
# already joined to schemas/provenance-block.json. `notranscript.md` is that file with one
# line removed. Hand-writing a block here would seed from what the reader accepts —
# a seed whose only author is the same understanding that wrote the arm — and it would
# stay green through a change to both. If a schema change breaks V5, it must break this
# fixture too; that is the point of the lift.
#
# check-17-bypass ships, so on a consumer the seed is reached at tests/fixtures/. If it is
# absent in BOTH layouts this script exits 3 and run.sh reports SKIP by name rather than ok.
set -uo pipefail

OUT="${1:-${OUT:-$(mktemp -d)}}"
mkdir -p "$OUT/docs"

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- locate check-17-bypass's seed in either layout ----------------------------
# Siblings, so this is a sideways walk and not the forbidden "walk up from one core file
# to another" (I33): both candidates are named in full from the fixture root.
C17=""
for cand in "$HERE/../check-17-bypass/seed.sh"; do
    [ -f "$cand" ] && { C17="$cand"; break; }
done
if [ -z "$C17" ]; then
    echo "seed: check-17-bypass/seed.sh not found beside this fixture" >&2
    exit 3
fi

C17OUT="$OUT/.c17"
mkdir -p "$C17OUT"
bash "$C17" "$C17OUT" >/dev/null 2>&1 || { echo "seed: check-17-bypass seed failed" >&2; exit 3; }
V5="$C17OUT/docs/retro/s905/retro.md"
[ -f "$V5" ] || { echo "seed: check-17-bypass V5 not at docs/retro/s905/retro.md" >&2; exit 3; }

cp "$V5" "$OUT/docs/compliant.md"

# transcript_path stripped. Guarded: a delete that matched nothing would hand the arms two
# identical docs and both would agree, which reads as a pass.
grep -v '^transcript_path:' "$OUT/docs/compliant.md" > "$OUT/docs/notranscript.md"
if cmp -s "$OUT/docs/compliant.md" "$OUT/docs/notranscript.md"; then
    echo "seed: stripping transcript_path changed nothing — the lifted block has no such field" >&2
    exit 3
fi
if grep -q 'transcript_path' "$OUT/docs/notranscript.md"; then
    echo "seed: transcript_path survived the strip" >&2
    exit 3
fi

cat > "$OUT/docs/blockless.md" <<'EOF'
# Sprint 302 Retrospective

Party mode was convened and the personas agreed the sprint went well.

There is no provenance block anywhere in this document. At a MIGRATED retro path the
validator must reject this; at the LEGACY path, byte-for-byte identical, it exits 0.
EOF

# --- probe-legacy.yml: the pre-migration shape at all five sites ---------------
cat > "$OUT/probe-legacy.yml" <<'EOF'
name: Probe Legacy

# Site 1 (header): retros live at docs/retro/sprint-<n>.md.

on:
  pull_request:
    paths:
      - "docs/retro/sprint-*.md"

jobs:
  probe:
    runs-on: ubuntu-latest
    steps:
      - name: Determine sprint number from touched retro files
        id: sprint
        run: |
          set -euo pipefail
          base_sha="${{ github.event.pull_request.base.sha }}"
          head_sha="${{ github.event.pull_request.head.sha }}"
          changed=$(git diff --name-only "$base_sha" "$head_sha" -- 'docs/retro/sprint-*.md' || true)
          if [[ -z "$changed" ]]; then
              echo "No retro files touched. Skipping."
              echo "sprint=" >> "$GITHUB_OUTPUT"
              exit 0
          fi
          sprint=""
          for f in $changed; do
              n=$(basename "$f" .md | sed 's/^sprint-//')
              if [[ "$n" =~ ^[0-9]+$ ]]; then
                  sprint="$n"
              fi
          done
          echo "sprint=$sprint" >> "$GITHUB_OUTPUT"

      - name: Run validate-provenance-block.sh on retro doc
        if: steps.sprint.outputs.sprint != ''
        run: |
          set -euo pipefail
          chmod +x scripts/ai-dlc/validate-provenance-block.sh
          ./scripts/ai-dlc/validate-provenance-block.sh "docs/retro/sprint-${{ steps.sprint.outputs.sprint }}.md"
EOF

# --- probe-fixed.yml: all five sites migrated + the flag -----------------------
cat > "$OUT/probe-fixed.yml" <<'EOF'
name: Probe Fixed

# Site 1 (header): retros live at docs/retro/s<n>/retro.md.

on:
  pull_request:
    paths:
      - "docs/retro/s*/retro.md"

jobs:
  probe:
    runs-on: ubuntu-latest
    steps:
      - name: Determine sprint number from touched retro files
        id: sprint
        run: |
          set -euo pipefail
          base_sha="${{ github.event.pull_request.base.sha }}"
          head_sha="${{ github.event.pull_request.head.sha }}"
          changed=$(git diff --name-only "$base_sha" "$head_sha" -- 'docs/retro/s*/retro.md' || true)
          if [[ -z "$changed" ]]; then
              echo "No retro files touched. Skipping."
              echo "sprint=" >> "$GITHUB_OUTPUT"
              exit 0
          fi
          sprint=""
          for f in $changed; do
              n=$(basename "$(dirname "$f")" | sed 's/^s//')
              if [[ "$n" =~ ^[0-9]+$ ]]; then
                  sprint="$n"
              fi
          done
          # A7's subject. Present in the FIXED probe only: the legacy probe writes an empty
          # sprint here and exits 0, which is the silent-skip the arm exists to reject.
          if [[ -z "$sprint" ]]; then
              echo "ERROR: retro files changed but no sprint number could be extracted." >&2
              echo "       Changed: $changed" >&2
              exit 1
          fi
          echo "sprint=$sprint" >> "$GITHUB_OUTPUT"

      - name: Run validate-provenance-block.sh on retro doc
        if: steps.sprint.outputs.sprint != ''
        run: |
          set -euo pipefail
          chmod +x scripts/ai-dlc/validate-provenance-block.sh
          ./scripts/ai-dlc/validate-provenance-block.sh \
            "docs/retro/s${{ steps.sprint.outputs.sprint }}/retro.md" \
            --require-skill bmad-party-mode
EOF

echo "$OUT"
