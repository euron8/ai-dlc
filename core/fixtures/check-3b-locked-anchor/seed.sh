#!/usr/bin/env bash
# Seed the check-3b-locked-anchor fixture (static files; idempotent).
set -euo pipefail
echo "Fixture: check-3b-locked-anchor (locked-requirement full-text anchor integrity)"
echo "Files are static in this directory: product-brief.md (SoR), prd.md (index),"
echo "bad-story.md (must FAIL), good-story.md (must PASS)."
