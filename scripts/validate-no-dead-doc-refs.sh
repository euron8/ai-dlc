#!/usr/bin/env bash
# validate-no-dead-doc-refs.sh — no core/** file may cite a top-level docs/ design doc
# that install.sh does not ship. Such a reference resolves for a maintainer in the dev
# repo but is DEAD in every consumer tree, where core/ is installed under .claude/ and
# the dev-repo docs/ never travels with it.
#
# WHY (v0.87.0). SKILL.md cited `docs/v0.24.0-gate-validation-slicing-spec.md`, a design
# spec that lives at the dev-repo docs/ root — OUTSIDE core/ — so install never copied it;
# the relative pointer was dead in every consumer. The sweep found the same class in five
# more sites (v0.70.0-sonnet-lead-ab.md, context-hardening-notes.md). Surfaced by the graph
# consumer's Sprint 292 CLAUDE.md audit.
#
# This is a dist-side guard (like validate-enforcement-map.sh): it runs at pre-push in the
# distribution repo, never ships to consumers. It DERIVES the dead set — no hand-list:
#   a top-level docs/<X>.md is dead-in-consumer iff it is referenced anywhere in core/
#   AND install.sh does not ship it. Consumer-runtime docs (architecture.md, docs/reviews/…,
#   docs/escalations/…) are not in the dev-repo docs/ root or are install-created, so they
#   are correctly excluded.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

INSTALL="scripts/install.sh"
fail=0

for doc in docs/*.md; do
  [ -f "$doc" ] || continue
  base="$(basename "$doc")"
  # referenced anywhere in core/ ?
  if grep -rqF "docs/$base" core/ 2>/dev/null; then
    # shipped by install.sh ?  (install names the doc, or archives/creates it)
    if ! grep -qF "$base" "$INSTALL" 2>/dev/null; then
      echo "DEAD-DOC-REF: core/ cites 'docs/$base', a dev-repo doc install.sh does not ship —" >&2
      echo "  dead in every consumer tree. Drop the reference, relativize it to an installed" >&2
      echo "  path, or ship the doc under core/. Sites: grep -rn 'docs/$base' core/" >&2
      fail=1
    fi
  fi
done

# --- Schema pointers must carry the consumer-tree prefix ----------------------
# Same class, second shape: the file IS shipped, but the pointer names a path that does not
# exist where the reader stands. install.sh writes core/schemas/*.json to `.claude/schemas/`,
# while every bare relative pointer in `.claude/skills/ai-dlc/**` resolves against the skill
# root — so a bare `schemas/X.json` resolves to `.claude/skills/ai-dlc/schemas/X.json`, which
# never exists. Measured on the reference consumer: `schemas/provenance-block.json` resolved
# from neither the repo root nor the skill root, in 10 sites across 6 files, while 2 sibling
# sites already carried the correct `.claude/schemas/` form. A rule file that tells the
# reader to load a schema, at a path the reader cannot resolve, teaches nothing and reports
# no error.
#
# The subject set is DERIVED from core/schemas/ — the directory is the list, so a new schema
# is covered the day it lands.
for schema in core/schemas/*.json; do
  [ -f "$schema" ] || continue
  base="$(basename "$schema")"
  # A bare hit is `schemas/<base>` NOT preceded by `.claude/` or `core/`.
  hits="$(grep -rnE "(^|[^.a-z/])schemas/${base}" core/ --include='*.md' 2>/dev/null \
          | grep -v '^core/fixtures/' || true)"
  if [ -n "$hits" ]; then
    echo "DEAD-SCHEMA-REF: core/ cites bare 'schemas/$base'. install.sh writes it to" >&2
    echo "  .claude/schemas/$base, and a bare pointer resolves against the skill root, so it" >&2
    echo "  is dead in every consumer tree. Write '.claude/schemas/$base'. Sites:" >&2
    printf '%s\n' "$hits" | sed 's/^/    /' >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "validate-no-dead-doc-refs: PASS — no core/ file cites an unshipped dev-repo doc or a bare schemas/ path."
fi
exit "$fail"
