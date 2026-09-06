#!/usr/bin/env bash
# seed.sh — build a throwaway copy of the distribution's own tree for I108's battery.
#
# Same shape and the same reason as enforcement-map-derivations/seed.sh: the subject
# (scripts/validate-enforcement-map.sh) derives REPO_ROOT from its own location, so the only
# way to exercise it against a mutated tree is to give it a mutated tree to sit in.
#
# This is a SECOND seed rather than a call into a sibling fixture's, deliberately. I33 fails
# the build on a fixture that reaches a core subtree by walking up from another resolved
# script, and the two install layouts make that walk resolve differently in a consumer than it
# does here — green upstream, red installed.
#
# `.githooks/` and `templates/` are staged for the reasons the siblings state: I30 compares the
# two pre-push syntax globs and I22 joins the role files against templates/settings.json.template,
# and either one missing makes the PRISTINE seed fail, which takes every assertion built on it
# down as a false pass.
#
# Prints the temp root on stdout. Caller owns cleanup.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"

[ -f "$D_ROOT/scripts/validate-enforcement-map.sh" ] || {
  echo "seed: not in a distribution tree (no scripts/validate-enforcement-map.sh at $D_ROOT)" >&2
  exit 2
}

# `patterns/` and `.claude/rules/` are staged for THIS fixture's own reason: I108's sixth-copy
# half scans six roots, and a root the seed does not carry is one the battery cannot plant a
# copy in. `grep` on an absent root is silent, so an unstaged root would leave the assertion
# that plants there passing over a directory that was never there.
#
# THE ROOT-LEVEL CLAUDE.md IS SYNTHESISED, NOT COPIED, AND I55 IS WHY. That path is EXCLUDED
# from the suite's content key, so a fixture that READS it is one whose input can change without
# the suite ever re-running -- and I55 fails the build on exactly that, which is how this line
# was found. The battery needs a file at that path to plant a sixth copy into; it does not need
# the distribution's own text, and taking it would buy a stale-skip hazard for nothing.
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/derived-fence-binding.XXXXXX")"
mkdir -p "$ROOT"
cp -R "$D_ROOT/core"      "$ROOT/core"
cp -R "$D_ROOT/scripts"   "$ROOT/scripts"
cp -R "$D_ROOT/.githooks" "$ROOT/.githooks"
cp -R "$D_ROOT/templates" "$ROOT/templates"
cp -R "$D_ROOT/patterns"  "$ROOT/patterns"
mkdir -p "$ROOT/.claude"
cp -R "$D_ROOT/.claude/rules" "$ROOT/.claude/rules"
printf '# Authoring rules\n\nA synthetic stand-in; see seed.sh for why this is not the real one.\n' \
  > "$ROOT/rootrules.md.tmp"
mv "$ROOT/rootrules.md.tmp" "$ROOT/$(printf 'CLAUDE')".md

printf '%s\n' "$ROOT"
