#!/usr/bin/env bash
# relabel-extension-checks.sh — mechanize the v0.49.0 consumer-catalog label.
#
# Extensions render ADDITIVELY into one numbered list with core. When a consumer's
# extension defines `### 25.` and core also defines `### 25.`, the merged document
# has one integer naming two unrelated checks, and the bare "Check 25" the lead
# writes into the gate log has no referent — permanently, because gate logs are the
# audit record.
#
# v0.49.0 defined the fix (label the catalog at the point of use: `### 25. [ext:<id>]
# <title>`) and shipped a detector for the violation. It shipped nothing that DOES
# the relabelling, so across three releases the reference consumer adopted the label
# on exactly zero of its extension checks. This closes that.
#
# The integer NEVER moves. The label is added; nothing is renumbered. Existing gate
# history maps by identity, so no consumer has to renumber on an upstream release.
#
# Usage: relabel-extension-checks.sh <consumer-root> [--apply]
#        (default: dry-run — print the rewrites it WOULD make)
# Exit:  0 = nothing to do, or --apply succeeded
#        1 = collisions found and NOT applied (dry-run with work outstanding)
set -uo pipefail

CONSUMER="${1:?usage: relabel-extension-checks.sh <consumer-root> [--apply]}"
APPLY="${2:-}"

SKILL_DIR="$CONSUMER/.claude/skills/ai-dlc"
EXT_DIR="$SKILL_DIR/extensions"
[ -d "$EXT_DIR" ] || { echo "relabel: no extensions/ under $SKILL_DIR"; exit 0; }

fm() { sed -n '/^---$/,/^---$/p' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

found=0
applied=0

while IFS= read -r ext; do
  [ -n "$ext" ] || continue
  kind="$(fm "$ext" kind)"
  [ "$kind" = check ] || continue
  id="$(fm "$ext" id)"
  hooks="$(fm "$ext" hooks)"
  [ -n "$id" ] && [ -n "$hooks" ] || continue

  core_file="$SKILL_DIR/$hooks"
  [ -f "$core_file" ] || continue

  # Numbers core defines in the file this extension hooks.
  core_nums="$(grep -oE '^#{2,4} [0-9]+[a-z]*\.' "$core_file" | sed 's/^#* //; s/\.$//' | sort -u)"
  [ -n "$core_nums" ] || continue

  while IFS= read -r n; do
    [ -n "$n" ] || continue
    # This extension's heading at that number, if any, and not already labelled.
    hd="$(grep -nE "^#{2,4} ${n}\. " "$ext" | grep -v '\[ext:' | grep -v '\[core\]' | head -1)"
    [ -n "$hd" ] || continue

    lineno="${hd%%:*}"
    text="${hd#*:}"
    title="$(printf '%s' "$text" | sed -E "s/^(#{2,4}) ${n}\. //")"
    hashes="$(printf '%s' "$text" | grep -oE '^#{2,4}')"
    new="${hashes} ${n}. [ext:${id}] ${title}"

    found=$((found+1))
    printf '%s:%s\n  -  %s\n  +  %s\n' "${ext#$CONSUMER/}" "$lineno" "$text" "$new"

    if [ "$APPLY" = "--apply" ]; then
      tmp="$(mktemp)"
      awk -v ln="$lineno" -v repl="$new" 'NR==ln { print repl; next } { print }' "$ext" > "$tmp"
      mv "$tmp" "$ext"
      applied=$((applied+1))
    fi
  done <<< "$core_nums"
done < <(find "$EXT_DIR" -name '*.md' -type f | sort)

echo ""
if [ "$found" -eq 0 ]; then
  echo "relabel-extension-checks: no unlabelled core-number collisions."
  exit 0
fi
if [ "$APPLY" = "--apply" ]; then
  echo "relabel-extension-checks: labelled ${applied} colliding check heading(s)."
  exit 0
fi
echo "relabel-extension-checks: ${found} colliding check heading(s) need the [ext:<id>] label."
echo "  Re-run with --apply to write them. The integer never moves; only the label is added."
exit 1
