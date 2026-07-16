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
# THEIRS-AWARENESS — the collision a pull CREATES.
#
# The collision set is defined against core. Without a distribution ref, "core" is the
# consumer's INSTALLED core — which, during a dry-run BEFORE apply, does not yet carry the
# numbers the pull is about to add. So a NEW-THIS-PULL collision (upstream adds `### 26.`; the
# consumer's extension already has `### 26.`) is INVISIBLE to a plain dry-run: the tool reports
# "no collisions" while the reconcile report's needs-confirmation list — which DOES compare
# against theirs — flags it. The relabel option is missing at the one moment the operator wants
# to decide it. Pass `--dist <repo> --theirs <ref>` and the incoming core's numbers are UNIONED
# in, so the dry-run previews exactly the collisions apply will materialise. (Backward compatible:
# with neither flag, "core" is the installed core, as before — correct at step 7, after the write.)
#
# Usage: relabel-extension-checks.sh <consumer-root> [--apply] [--dist <repo> --theirs <ref>]
#        (default: dry-run — print the rewrites it WOULD make)
# Exit:  0 = nothing to do, or --apply succeeded
#        1 = collisions found and NOT applied (dry-run with work outstanding)
#        2 = usage error
set -uo pipefail

CONSUMER=""
APPLY=""
DIST=""
THEIRS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)  APPLY="--apply"; shift ;;
    --dist)   DIST="${2:?--dist needs a path}"; shift 2 ;;
    --theirs) THEIRS="${2:?--theirs needs a ref}"; shift 2 ;;
    -*)       echo "relabel: unknown arg: $1" >&2; exit 2 ;;
    *)        if [ -z "$CONSUMER" ]; then CONSUMER="$1"; shift
              else echo "relabel: unexpected arg: $1" >&2; exit 2; fi ;;
  esac
done
[ -n "$CONSUMER" ] || { echo "usage: relabel-extension-checks.sh <consumer-root> [--apply] [--dist <repo> --theirs <ref>]" >&2; exit 2; }

SKILL_DIR="$CONSUMER/.claude/skills/ai-dlc"
EXT_DIR="$SKILL_DIR/extensions"
[ -d "$EXT_DIR" ] || { echo "relabel: no extensions/ under $SKILL_DIR"; exit 0; }

# core headings -> bare numbers, one per line. Reads a stream on stdin.
core_num_stream() { grep -oE '^#{2,4} [0-9]+[a-z]*\.' | sed 's/^#* //; s/\.$//'; }

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

  # Numbers core defines in the file this extension hooks — the UNION of the installed core
  # (present today) and, when given, theirs (what the pull will add). The union is what makes a
  # pull-introduced collision visible during the dry-run instead of only after the write.
  core_file="$SKILL_DIR/$hooks"
  nums_installed=""
  [ -f "$core_file" ] && nums_installed="$(core_num_stream < "$core_file")"
  nums_theirs=""
  if [ -n "$DIST" ] && [ -n "$THEIRS" ]; then
    tp="core/skills/ai-dlc/${hooks}"
    if git -C "$DIST" cat-file -e "${THEIRS}:${tp}" 2>/dev/null; then
      nums_theirs="$(git -C "$DIST" show "${THEIRS}:${tp}" | core_num_stream)"
    fi
  fi
  core_nums="$(printf '%s\n%s\n' "$nums_installed" "$nums_theirs" | grep -E '.' | sort -u)"
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
