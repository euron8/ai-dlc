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
# THE SEED IS THE READ SET OF THE ARMS THIS FIXTURE SELECTS, NOT THE TREE. Every run here selects
# I75, I108, I121, I122 or I123, and an --arms run executes the validator's prologue, the selected
# units and the verdict block, nothing else. Those read: the prologue's five required inputs and
# render-invariant-index.sh (the --arms map); core/team-roles/ (the I108/I121/I122/I123
# population); core/scripts/*.sh (I75's subject glob, which includes I108's reader
# validate-artifact-derivations.sh); and the six half-B roots, which are walked whole. The real
# tree's half-B verdict is the gate's own full validator run (.githooks/pre-push), not this
# fixture's: a battery plants into a root, and plant_root creates the root it plants in, so no
# other file of templates/, patterns/ or .claude/rules/ is copied.
#
# Prints the temp root on stdout. Caller owns cleanup.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"

[ -f "$D_ROOT/scripts/validate-enforcement-map.sh" ] || {
  echo "seed: not in a distribution tree (no scripts/validate-enforcement-map.sh at $D_ROOT)" >&2
  exit 2
}

# THE ROOT-LEVEL CLAUDE.md IS SYNTHESISED, NOT COPIED, AND I55 IS WHY. That path is EXCLUDED
# from the suite's content key, so a fixture that READS it is one whose input can change without
# the suite ever re-running -- and I55 fails the build on exactly that, which is how this line
# was found. The battery needs a file at that path to plant a sixth copy into; it does not need
# the distribution's own text, and taking it would buy a stale-skip hazard for nothing.
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/derived-fence-binding.XXXXXX")"
mkdir -p "$ROOT"
for rel in scripts/validate-enforcement-map.sh scripts/render-invariant-index.sh \
           core/skills/ai-dlc/steps/gate-validation.md core/skills/ai-dlc/enforcement-map.yaml \
           core/skills/ai-dlc/core-manifest.md core/skills/ai-dlc-update/reconcile/setup-sites.md \
           core/skills/ai-dlc-update/fixture-manifest.md; do
  mkdir -p "$ROOT/$(dirname "$rel")"
  cp -p "$D_ROOT/$rel" "$ROOT/$rel"
done
cp -R "$D_ROOT/core/team-roles" "$ROOT/core/team-roles"
mkdir -p "$ROOT/core/scripts"
cp -p "$D_ROOT"/core/scripts/*.sh "$ROOT/core/scripts/"
# A00 and A03 are the acquittal probe for half B's core/fixtures/ exclusion, and its subject is
# THIS fixture's run.sh, which carries the opener: it must sit under core/fixtures/ in the copy.
mkdir -p "$ROOT/core/fixtures"
cp -R "$HERE" "$ROOT/core/fixtures/derived-fence-binding"
# run.sh's plant_root creates a missing root and fresh() rmdirs only the plant's own directory,
# so .claude/ is the one parent staged: without it the .claude/rules plant leaves it behind and
# the final restore differs from this seed.
mkdir -p "$ROOT/.claude"
printf '# Authoring rules\n\nA synthetic stand-in; see seed.sh for why this is not the real one.\n' \
  > "$ROOT/rootrules.md.tmp"
mv "$ROOT/rootrules.md.tmp" "$ROOT/$(printf 'CLAUDE')".md

printf '%s\n' "$ROOT"
