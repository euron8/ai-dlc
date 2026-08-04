#!/usr/bin/env bash
# self-update-join-gate/seed.sh — two consumer trees and a real distribution clone.
#
# REAL TREES, NOT SIMULATED ONES. The gate diffs a git range and reads the consumer's own
# gate-validation.md, so a hand-built stand-in would prove nothing about the part that
# actually runs. Both consumers are produced by install.sh from a real checkout, which is
# also what makes the CHECK_LOADED anchor sets genuine rather than authored here.
#
# The two consumers are the fixture's whole discrimination:
#   CONS_OLD      installed from a ref BEFORE a check was added -> its gate-validation.md
#                 has no anchor for that check, so the map/anchor join is broken.
#   CONS_CURRENT  installed from the SAME ref the pull targets on the rulebook side, so a
#                 machinery-only pull against it must NOT defer.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"

[ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/self-update-gate.sh" ] || {
  echo "seed: not a distribution tree (no self-update-gate.sh)" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/su-join-gate.XXXXXX")" || exit 2

# A clone, never the live repo: the gate runs `git -C "$DIST" checkout`-free reads, but a
# fixture that points a tool at the working repository can be perturbed by it.
DIST="$WORK/dist"
git clone -q --no-hardlinks "$D_ROOT" "$DIST" 2>/dev/null || {
  echo "FIXTURE ERROR: could not clone the distribution" >&2; exit 2; }

# BASE/THEIRS are DERIVED from the range that actually adds a check, never hardcoded to a
# release number. The subject is "a pull that crosses a check-adding commit", so the seed
# finds one: the newest commit that adds a CHECK_LOADED anchor, and its parent.
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
ADDED="$(git -C "$DIST" log --format=%H -S'<!-- CHECK_LOADED:' --pickaxe-regex \
           -- core/skills/ai-dlc/steps/gate-validation.md | head -1)"
if [ -z "$ADDED" ]; then
  echo "FIXTURE ERROR: no commit in history adds a CHECK_LOADED anchor, so there is no" >&2
  echo "  check-adding range to test and every assertion would pass vacuously." >&2
  exit 2
fi
BASE="$(git -C "$DIST" rev-parse "${ADDED}^")"

# A range that adds no anchor would make assertion 1 vacuous. Prove it adds at least one.
n_base="$(git -C "$DIST" show "${BASE}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null \
          | grep -c '^<!-- CHECK_LOADED:' || true)"
n_theirs="$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null \
          | grep -c '^<!-- CHECK_LOADED:' || true)"
if [ "${n_theirs:-0}" -le "${n_base:-0}" ]; then
  echo "FIXTURE ERROR: the derived range adds no anchor (base=$n_base theirs=$n_theirs);" >&2
  echo "  assertion 1 would test a pull with nothing to defer on." >&2
  exit 2
fi

install_at() { # install_at <ref> <dest>
  local ref="$1" dest="$2" src="$WORK/src-${ref:0:8}"
  rm -rf "$src"; git clone -q --no-hardlinks "$DIST" "$src" 2>/dev/null || return 1
  git -C "$src" checkout -q "$ref" || return 1
  mkdir -p "$dest/_bmad"
  ( cd "$dest" && git init --quiet . ) || return 1
  ( cd "$dest" && bash "$src/scripts/install.sh" . >/dev/null 2>&1 ) || return 1
}

CONS_OLD="$WORK/cons-old"
CONS_CURRENT="$WORK/cons-current"
install_at "$BASE"   "$CONS_OLD"     || { echo "FIXTURE ERROR: install at BASE failed" >&2; exit 2; }
install_at "$THEIRS" "$CONS_CURRENT" || { echo "FIXTURE ERROR: install at THEIRS failed" >&2; exit 2; }

for d in "$CONS_OLD" "$CONS_CURRENT"; do
  [ -f "$d/.claude/skills/ai-dlc/steps/gate-validation.md" ] || {
    echo "FIXTURE ERROR: $d has no installed gate-validation.md; the anchor join has no subject" >&2
    exit 2; }
done

cat > "$WORK/env.sh" <<EOF
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONS_OLD="$CONS_OLD"
CONS_CURRENT="$CONS_CURRENT"
EOF

printf '%s\n' "$WORK"
