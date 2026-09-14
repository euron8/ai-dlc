#!/usr/bin/env bash
# validate-no-dead-doc-refs.sh — no core/** file may cite a dev-repo docs/ file, at any
# depth, that install.sh does not ship. Such a reference resolves for a maintainer in the
# dev repo but is DEAD in every consumer tree, where core/ is installed under .claude/ and
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
#   a docs/<P> markdown file, at ANY depth, is dead-in-consumer iff it is referenced
#   anywhere in core/ AND install.sh does not ship it. Consumer-runtime docs
#   (architecture.md and the like) are install-created, so a consumer's own copy is not the
#   dev-repo file this arm is about.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

INSTALL="scripts/install.sh"
fail=0

# A SITE INSIDE A .dist-only FIXTURE IS NOT DEAD ANYWHERE, because install.sh derives its
# fixture copy loop from that same marker and never copies the directory — there is no
# consumer tree holding the file, so there is no consumer tree in which its pointer 404s.
# Derived from the marker, never a hand-list, and deliberately NOT the blanket
# `core/fixtures/` exclusion the schema arm below uses: a SHIPPED fixture citing a dev-repo
# doc is dead in the consumer exactly like any other shipped file, and must still be caught.
site_is_dist_only() {
  case "$1" in
    core/fixtures/*)
      _fx="${1#core/fixtures/}"; _fx="${_fx%%/*}"
      [ -f "core/fixtures/${_fx}/.dist-only" ] && return 0 ;;
  esac
  return 1
}

# THE CORPUS IS EVERY `docs/**` MARKDOWN FILE, AND THE KEY IS THE PATH RELATIVE TO `docs/`.
# Both halves are load-bearing and either alone is a NON-FIX. The loop was `docs/*.md` (32 of
# 122 files on the tree this was widened against) and the key was `$(basename "$doc")`, so a
# citation written `docs/analysis/x.md` was never matched by the key `docs/x.md`: widening the
# loop alone changes nothing about what is SEARCHED.
#
# THE LOOP FORM IS `for doc in $(find … | sort)` AND THE TWO OBVIOUS ALTERNATIVES BOTH SHIP
# GREEN WHILE COVERING LESS:
#   `docs/**/*.md` IS A COVERAGE REDUCTION. This runs under bash 3.2.57, where `shopt globstar`
#   does not exist, so `**` is an ordinary `*` and the pattern means `docs/*/*.md` -- ONE level,
#   which DROPS THE TOP LEVEL the validator covers today. Measured on this tree: 75 of 122 files,
#   blind to all 32 top-level ones, at exit 0.
#   `find … | while read` SWALLOWS THE VERDICT. The loop body runs in a SUBSHELL, so `fail=1`
#   is lost and `exit "$fail"` reads 0. Measured: findings printed to stderr, exit 0.
# A hand-written multi-level glob under-covers too -- this tree has files at depth 4. `find` is
# the only form that does not need revisiting when a directory is added.
for doc in $(find docs -type f -name '*.md' | sort); do
  [ -f "$doc" ] || continue
  base="${doc#docs/}"
  # shipped by install.sh ?  (install names the doc, or archives/creates it)
  grep -qF "$base" "$INSTALL" 2>/dev/null && continue
  live_sites=""
  while IFS= read -r site; do
    [ -n "$site" ] || continue
    site_is_dist_only "$site" && continue
    live_sites="${live_sites}${site}
"
  done <<<"$(grep -rlF "docs/$base" core/ 2>/dev/null || true)"
  if [ -n "$live_sites" ]; then
    echo "DEAD-DOC-REF: core/ cites 'docs/$base', a dev-repo doc install.sh does not ship —" >&2
    echo "  dead in every consumer tree. Drop the reference, relativize it to an installed" >&2
    echo "  path, or ship the doc under core/. Sites:" >&2
    printf '%s' "$live_sites" | sed 's/^/    /' >&2
    fail=1
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
