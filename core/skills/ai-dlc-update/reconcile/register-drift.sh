#!/usr/bin/env bash
# register-drift.sh — pull an unregistered in-place core edit INTO the layer system.
#
# `unregistered-drift.sh` finds a core file the consumer edited in place: no override
# entry, no base_sha, invisible to layer-drift.sh, and DELETED without a word by the
# next `apply` (core is upstream-owned and overwritten). Detecting that was half the
# job. Telling the operator "refile the delta as an override with a base_sha" and
# leaving them to hand-author the YAML, pick the anchor, and copy the right section out
# is the other half, undone — and a hand-authored anchor that resolves to no heading is
# how drift detection dies silently (this repo has repointed four such overrides).
#
# This authors the entry, extracts the consumer's own section verbatim, and reverts
# core. The operator confirms and writes the `reason:`; they do not do the surgery.
#
# The `base_sha` is stamped at BASE -- the sha the consumer's text actually forked
# from, not the sha being pulled. If upstream ALSO changed that section in this pull,
# the new entry is immediately reported as HARD-OVERRIDE-DRIFT-SECTION and goes through
# `readopt-override.sh --merge` like any other. Stamping `theirs` here would silently
# claim the consumer had already read upstream's change. It has not.
#
# Usage: register-drift.sh <dist-repo> <base-sha> <consumer-root> <core-rel-path> [--apply]
#          core-rel-path e.g. team-roles/tea.md  |  skills/ai-dlc/steps/retro.md
#        (default: dry-run -- print the override it WOULD write)
# Exit:  0 ok / 1 nothing to register / 2 usage
set -uo pipefail

DIST="${1:?usage: register-drift.sh <dist-repo> <base-sha> <consumer-root> <core-rel-path> [--apply]}"
BASE="${2:?}"
CONSUMER="${3:?}"
REL="${4:?}"
APPLY="${5:-}"

case "$REL" in
  skills/ai-dlc/*) CONS_FILE="$CONSUMER/.claude/skills/ai-dlc/${REL#skills/ai-dlc/}"; SHADOW_TGT="${REL#skills/ai-dlc/}" ;;
  team-roles/*)    CONS_FILE="$CONSUMER/.claude/team-roles/${REL#team-roles/}";       SHADOW_TGT="$REL" ;;
  hooks/*)
    echo "register-drift: $REL is a HOOK. The layer system has no override grain for hooks —" >&2
    echo "  overrides shadow rulebook headings. Keep the consumer hook (accept per-entry) or" >&2
    echo "  upstream the change. This is a known gap, not something to paper over here." >&2
    exit 2 ;;
  *) echo "register-drift: unrecognized core path: $REL" >&2; exit 2 ;;
esac

CORE="core/${REL}"
[ -f "$CONS_FILE" ] || { echo "register-drift: consumer file absent: $CONS_FILE" >&2; exit 2; }
git -C "$DIST" cat-file -e "${BASE}:${CORE}" 2>/dev/null || { echo "register-drift: $CORE absent at $BASE" >&2; exit 2; }

OVR_DIR="$CONSUMER/.claude/skills/ai-dlc/overrides"
mkdir -p "$OVR_DIR"

# Top-level heading names in the consumer's file.
headings_of() { grep -nE '^#{2,3} ' "$1" | sed 's/:.*#\{2,3\} /:/'; }

# Extract one heading's section (same grammar layer-drift resolves with).
section_of() {
  awk -v want="$1" '
    function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
    /^#{2,6}[ \t]/ {
      match($0, /^#+/); lvl = RLENGTH
      h = $0; sub(/^#+[ \t]+/, "", h); h = nrm(h)
      if (inside) { if (lvl <= mylvl) exit }
      else if (nrm(want) == h) { inside = 1; mylvl = lvl; print; next }
    }
    inside { print }
  '
}

# Which sections did the consumer actually change? Only those go in the override —
# an override that restates unchanged core is a fork waiting to happen (Rule 27(c)).
#
# A section whose ONLY difference is a `{token}` template site is NOT a consumer change:
# that is install.sh doing its job. Pulling it into the override would shadow core text
# the consumer never touched, and every future upstream edit to it would be discarded
# unseen. Same asymmetric test unregistered-drift.sh uses — the DIST side must carry the
# token, so a consumer cannot manufacture an exemption by typing "{foo}" into its copy.
substitution_only() { # <consumer-section-text> <dist-section-text>
  diff <(printf '%s\n' "$2") <(printf '%s\n' "$1") | awk '
    /^[0-9]/ { if (hunk && !tok) bad=1; hunk=1; tok=0; next }
    /^</     { if ($0 ~ /\{[a-z_][a-z0-9_]*\}/) tok=1 }
    END      { if (hunk && !tok) bad=1; print (bad ? "no" : "yes") }
  '
}

changed=""
skipped=""
while IFS= read -r line; do
  h="${line#*:}"
  [ -n "$h" ] || continue
  a="$(section_of "$h" < "$CONS_FILE")"
  b="$(git -C "$DIST" show "${BASE}:${CORE}" | section_of "$h")"
  [ "$a" = "$b" ] && continue
  if [ "$(substitution_only "$a" "$b")" = yes ]; then
    skipped="${skipped}${skipped:+, }${h}"
    continue
  fi
  changed="${changed}${changed:+$'\n'}${h}"
done < <(headings_of "$CONS_FILE")

[ -n "$skipped" ] && echo "── skipped (template substitution only, not a consumer change): ${skipped}"

if [ -z "$changed" ]; then
  echo "register-drift: $REL differs from ${BASE}, but no ## / ### section differs."
  echo "  The delta is outside any heading (frontmatter, preamble, or a token site)."
  echo "  An override anchors to a heading, so this cannot be registered as one. Revert it,"
  echo "  or take it upstream."
  exit 1
fi

n_changed="$(printf '%s\n' "$changed" | grep -c .)"
slug="$(printf '%s' "$REL" | sed 's|/|__|g; s|\.md$||')"
first="$(printf '%s\n' "$changed" | head -1)"
OUT="$OVR_DIR/$(printf '%s' "$slug" | sed 's|skills__ai-dlc__||')__consumer-drift.md"

shadow_line="$SHADOW_TGT#$(printf '%s\n' "$changed" | paste -sd '@' - | sed "s|@|, ${SHADOW_TGT}#|g")"

body="$(printf '%s\n' "$changed" | while IFS= read -r h; do
          [ -n "$h" ] || continue
          section_of "$h" < "$CONS_FILE"; echo
        done)"

render() {
  cat <<EOF
---
shadows: ${shadow_line}
base_sha: ${BASE}
reason: TODO — one line: why this consumer changes the core rule. Registered by register-drift.sh; this text was carried as an UNREGISTERED in-place edit of core/${REL} (no override entry, no base_sha, invisible to layer-drift.sh, and destroyed by the next apply). Content is unchanged from what the consumer was already running; only its registration is new.
---

${body}
EOF
}

if [ "$APPLY" != "--apply" ]; then
  echo "── would write: ${OUT#$CONSUMER/}"
  echo "── would revert: .claude/${REL#skills/ai-dlc/} to ${BASE}"
  echo "── ${n_changed} changed section(s): $(printf '%s' "$changed" | tr '\n' ';')"
  echo ""
  render
  echo ""
  echo "register-drift: DRY RUN. Re-run with --apply to write it."
  exit 0
fi

render > "$OUT"
git -C "$DIST" show "${BASE}:${CORE}" > "$CONS_FILE"

echo "REGISTERED  ${OUT#$CONSUMER/}"
echo "  shadows      : ${shadow_line}"
echo "  base_sha     : ${BASE}  (where the delta forked from, NOT the sha being pulled)"
echo "  core reverted: .claude/${REL#skills/ai-dlc/} restored to ${BASE}"
echo ""
echo "  WRITE THE reason: LINE. It says TODO. An override whose reason nobody stated is"
echo "  one nobody can ever retire — the next pull cannot ask 'does upstream supersede this?'"
echo "  about a reason that was never given."
