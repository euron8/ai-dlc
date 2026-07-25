#!/usr/bin/env bash
# core-write-guard/seed.sh — build a LAYERED-CONSUMER tree so run.sh can drive the
# real ai-dlc-core-guard.sh hook and prove it denies in-place core edits while
# leaving overrides/extensions, /ai-dlc-setup config fills, shell writes, and the
# distribution untouched.
#
# The consumer copies the REAL core-manifest.md and reconcile/setup-sites.md and the
# REAL token-bearing role files, so the derivation and the config-region exemption are
# tested against the actual declarations — rename a heading or drop a manifest entry and
# this fixture breaks loudly, exactly as the shipped hook would misbehave.
#
# Also builds a NO-STAMP tree (the distribution shape) to prove the activation-gate no-op.
#
# Prints the WORK dir on stdout. Idempotent: a fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the distribution root (fixtures live at core/fixtures/<name>/ upstream, or
# tests/fixtures/<name>/ in a consumer) and the real source files.
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/hooks/ai-dlc-core-guard.sh" ]; then
  HOOK="$D_ROOT/core/hooks/ai-dlc-core-guard.sh"
  SRC_MANIFEST="$D_ROOT/core/skills/ai-dlc/core-manifest.md"
  SRC_SITES="$D_ROOT/core/skills/ai-dlc-update/reconcile/setup-sites.md"
  SRC_ARCHITECT="$D_ROOT/core/team-roles/architect.md"
  SRC_DEV="$D_ROOT/core/team-roles/dev.md"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/hooks/ai-dlc-core-guard.sh" ]; then
  HOOK="$C_ROOT/.claude/hooks/ai-dlc-core-guard.sh"
  SRC_MANIFEST="$C_ROOT/.claude/skills/ai-dlc/core-manifest.md"
  SRC_SITES="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/setup-sites.md"
  SRC_ARCHITECT="$C_ROOT/.claude/team-roles/architect.md"
  SRC_DEV="$C_ROOT/.claude/team-roles/dev.md"
else
  echo "FIXTURE ERROR: ai-dlc-core-guard.sh not found in either layout" >&2
  exit 2
fi
for f in "$SRC_MANIFEST" "$SRC_SITES" "$SRC_ARCHITECT" "$SRC_DEV"; do
  [ -r "$f" ] || { echo "FIXTURE ERROR: missing source $f" >&2; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/core-write-guard.XXXXXX")" || exit 2
# Resolve to a stable absolute path (macOS /tmp is a symlink) so the hook's
# project-prefix strip lines up with the paths run.sh constructs.
WORK="$(cd "$WORK" && pwd)"

CONSUMER="$WORK/consumer"
NOSTAMP="$WORK/dist"        # distribution shape: has core files, no .ai-dlc-version stamp

SKILL="$CONSUMER/.claude/skills/ai-dlc"
mkdir -p "$SKILL/steps" "$SKILL/overrides" "$SKILL/extensions" \
         "$CONSUMER/.claude/team-roles" \
         "$CONSUMER/.claude/skills/ai-dlc-update/reconcile"

# --- the layered-consumer markers (activation gate) --------------------------
cat > "$CONSUMER/.claude/.ai-dlc-version" <<EOF
version: 0.68.0
commit: fixture
skill_version: 0.68.0
skill_commit: fixture
EOF
echo "# overrides"  > "$SKILL/overrides/README.md"
echo "# extensions" > "$SKILL/extensions/README.md"

# --- the derivation sources (real, so the hook parses real declarations) -----
cp "$SRC_MANIFEST" "$SKILL/core-manifest.md"
cp "$SRC_SITES"    "$CONSUMER/.claude/skills/ai-dlc-update/reconcile/setup-sites.md"

# --- core-manifest files ------------------------------------------------------
# A no-site rulebook step file (any in-place edit must be denied).
cat > "$SKILL/steps/gate-validation.md" <<'EOF'
# Gate validation (fixture stub)

Fixed rulebook prose. A layered consumer MUST NOT edit this in place — it is
upstream-owned and /ai-dlc-update overwrites it wholesale.
EOF
# Real token-bearing role files (config sites: model lines + dev ## Ownership block).
cp "$SRC_ARCHITECT" "$CONSUMER/.claude/team-roles/architect.md"
cp "$SRC_DEV"       "$CONSUMER/.claude/team-roles/dev.md"

# --- non-core layer files (edits here must be allowed) -----------------------
cat > "$SKILL/overrides/example-shadow.md" <<'EOF'
---
shadows: steps/gate-validation.md
base_sha: fixture
reason: fixture override
---
Consumer-owned override body.
EOF
cat > "$SKILL/extensions/example-rule.md" <<'EOF'
---
id: consumer-example
---
Consumer-owned additive extension body.
EOF

# --- installed fixtures: one of ours, one of theirs, at adjacent names ---------
# tests/fixtures/ is SHARED — core ships its adversarial self-tests there and the
# consumer's own sit beside them, both using the `check-` prefix. Created rather than
# merely named, so the tree is the shape the hook meets on a real consumer: the deny path
# does not stat the target today, but the config-region branch DOES read it, and a
# name-only fixture would go silently fail-open the day a core_key() case is added here.
mkdir -p "$CONSUMER/tests/fixtures/check-15-bypass" \
         "$CONSUMER/tests/fixtures/check-15-bypass-local"
printf '# TODO reword this marker\n' > "$CONSUMER/tests/fixtures/check-15-bypass/seed.sh"
printf 'consumer fixture body\n'     > "$CONSUMER/tests/fixtures/check-15-bypass-local/seed.sh"

# --- distribution shape: core files, NO stamp (activation gate must no-op) ----
mkdir -p "$NOSTAMP/.claude/skills/ai-dlc/steps" \
         "$NOSTAMP/.claude/skills/ai-dlc/overrides" \
         "$NOSTAMP/.claude/skills/ai-dlc/extensions"
cp "$SKILL/core-manifest.md" "$NOSTAMP/.claude/skills/ai-dlc/core-manifest.md"
cp "$SKILL/steps/gate-validation.md" "$NOSTAMP/.claude/skills/ai-dlc/steps/gate-validation.md"
# deliberately NO .claude/.ai-dlc-version here

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
CONSUMER="$CONSUMER"
NOSTAMP="$NOSTAMP"
SKILL="$SKILL"
ENV

printf '%s\n' "$WORK"
