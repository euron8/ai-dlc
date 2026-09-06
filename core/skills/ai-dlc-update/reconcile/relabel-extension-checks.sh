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

# core headings -> bare anchor ids, one per line. Reads a stream on stdin.
#
# This grammar is layer-drift.sh's ANCHOR_RE, byte for byte, and MUST stay that way:
# layer-drift REPORTS the collision and this script FIXES it, so a narrower grammar here
# means layer-drift names a collision the operator is told to relabel with a tool that
# cannot see it. The old regex was narrower on three counts, and one of them is live in
# core today -- `### H1.` / `### H2.` in gate-validation.md yielded NO anchor at all, so
# an extension colliding on H1 was unrelabellable. `validate-enforcement-map.sh` asserts
# the two definitions are identical; widen there and here together, or not at all.
#
# It is now bound to a THIRD and FOURTH copy as well — `CHECK_HEAD_RE` in
# validate-layer-entries.sh and validate-gate-manifest.sh, by I47. That edge exists because
# this pair widened for `### H1.` and that pair did not, and no check compared the pairs: a
# rewriter that could already relabel `## Check AP — …` alongside a detector that could not
# report it, green for four releases. Any widening now moves all four in one release.
ANCHOR_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*(\.|—)'
core_num_stream() { grep -oE "$ANCHOR_RE" | sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//; s/[[:space:]]*(\.|—)$//'; }

# RULE numbers are a SECOND namespace and need their own grammar: a rule heading
# (`### Rule 29 -- Steering budget`) carries no `(\.|—)` terminator, so ANCHOR_RE
# above matches none of the 31 rules in core's SKILL.md — verified, 0 of 31. That
# is why this pass exists separately rather than as a widened ANCHOR_RE: teaching
# the check grammar the word `Rule` would fold `Rule 29` and check `29` into one
# id and start relabelling across two unrelated catalogs.
#
# Byte-identical to `RULE_RE` in `core/scripts/validate-layer-entries.sh`, which
# REPORTS what this FIXES. Invariant I34 in validate-enforcement-map.sh asserts it:
# a narrower grammar here means the linter names a collision this tool cannot see,
# and the operator is handed a remedy that does not run.
RULE_RE='^#{2,4}[[:space:]]+Rule[[:space:]]+([0-9]+[a-z]*)[[:space:]]*(\[[^]]*\][[:space:]]*)?(--|—|:)'
core_rule_stream() { grep -oE "$RULE_RE" | sed -E 's/^#+[[:space:]]+Rule[[:space:]]+//; s/[^0-9a-z].*$//' | grep -E '.'; }

fm() { sed -n '/^---$/,/^---$/p' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

found=0
applied=0

while IFS= read -r ext; do
  [ -n "$ext" ] || continue
  kind="$(fm "$ext" kind)"
  # step-domain extensions collide on core step numbers exactly as check extensions
  # collide on core check numbers -- and every collision this tool was built to fix
  # turned out to live in a step-domain file, where the old `= check` filter never
  # looked. It reported "no unlabelled collisions" over six live ones while
  # layer-drift.sh reported them correctly. Widen to the kinds that carry numbered
  # headings, not to everything: a `role` entry has no anchor namespace to collide in.
  case "$kind" in check|step-domain) ;; *) continue ;; esac
  id="$(fm "$ext" id)"
  hooks="$(fm "$ext" hooks)"
  [ -n "$id" ] && [ -n "$hooks" ] || continue

  # Numbers core defines in the file this extension hooks — the UNION of the installed core
  # (present today) and, when given, theirs (what the pull will add). The union is what makes a
  # pull-introduced collision visible during the dry-run instead of only after the write.
  core_file="$SKILL_DIR/$hooks"
  theirs_blob=""
  if [ -n "$DIST" ] && [ -n "$THEIRS" ]; then
    tp="core/skills/ai-dlc/${hooks}"
    if git -C "$DIST" cat-file -e "${THEIRS}:${tp}" 2>/dev/null; then
      theirs_blob="$(git -C "$DIST" show "${THEIRS}:${tp}")"
    fi
  fi

  nums_installed=""
  [ -f "$core_file" ] && nums_installed="$(core_num_stream < "$core_file")"
  nums_theirs=""
  [ -n "$theirs_blob" ] && nums_theirs="$(printf '%s\n' "$theirs_blob" | core_num_stream)"
  core_nums="$(printf '%s\n%s\n' "$nums_installed" "$nums_theirs" | grep -E '.' | sort -u)"

  rules_installed=""
  [ -f "$core_file" ] && rules_installed="$(core_rule_stream < "$core_file")"
  rules_theirs=""
  [ -n "$theirs_blob" ] && rules_theirs="$(printf '%s\n' "$theirs_blob" | core_rule_stream)"
  core_rules="$(printf '%s\n%s\n' "$rules_installed" "$rules_theirs" | grep -E '.' | sort -u)"

  # NOT `[ -n "$core_nums" ] || continue`. Core's SKILL.md defines 31 rules and ZERO
  # check anchors, so gating both passes on the check set skipped every SKILL.md-hooking
  # entry — which is exactly where every rule collision lives. The gate has to admit an
  # entry that collides in either namespace, or the rule pass can never fire.
  [ -n "$core_nums" ] || [ -n "$core_rules" ] || continue

  while IFS= read -r n; do
    [ -n "$n" ] || continue
    # This extension's heading at that anchor, if any, and not already labelled. The
    # separator class matches ANCHOR_RE, so `### 24. T`, `### Check 24. T` and
    # `## Check AP — T` all resolve; requiring a literal `. ` skipped the last two.
    anchor_at="^#{2,4}[[:space:]]+(Check[[:space:]]+)?${n}[[:space:]]*(\.|—)[[:space:]]*"
    hd="$(grep -nE "$anchor_at" "$ext" | grep -v '\[ext:' | grep -v '\[core\]' | head -1)"
    [ -n "$hd" ] || continue

    lineno="${hd%%:*}"
    text="${hd#*:}"
    # INSERT the label; do not rebuild the heading from parts. The old form re-emitted a
    # hardcoded `<hashes> <n>. `, which silently rewrote an em-dash separator or dropped
    # a `Check ` prefix -- mangling the very headings the widened grammar just taught it
    # to see. Everything left of the title is carried through untouched.
    # NO sed here, on purpose. The anchor grammar's terminator is an ALTERNATION, `(\.|—)`,
    # so it CARRIES a `|` -- and this line used `|` as its `s|…|…|` delimiter, so sed read
    # `s|(^#...(\.|` as the whole pattern, refused it, and `new` came back EMPTY; three
    # fixtures went red on the first push of the rewrite. Changing the delimiter only moved the
    # exposure: the REPLACEMENT side interpolates `${id}`, no validator constrains an extension
    # `id:`, an `&` in it is the whole match to sed (measured: `id=a&b` wrote
    # `[ext:a## Check 24. b]` into the heading, a label the readers' `\[ext:[A-Za-z0-9_.-]+\]`
    # strip can never see again), and whatever character is the delimiter is one more. A
    # string splice has no delimiter and no metacharacter: `grep -oE` returns the anchored
    # prefix the grammar matched, and bash removes exactly that literal prefix (quoted, so a
    # glob character in it is literal too) and re-emits it with the label after it.
    pre="$(printf '%s' "$text" | grep -oE "$anchor_at" | head -1)"
    new="${pre}[ext:${id}] ${text#"$pre"}"

    found=$((found+1))
    printf '%s:%s\n  -  %s\n  +  %s\n' "${ext#$CONSUMER/}" "$lineno" "$text" "$new"

    if [ "$APPLY" = "--apply" ]; then
      tmp="$(mktemp)"
      awk -v ln="$lineno" -v repl="$new" 'NR==ln { print repl; next } { print }' "$ext" > "$tmp"
      mv "$tmp" "$ext"
      applied=$((applied+1))
    fi
  done <<< "$core_nums"

  # --- the same rewrite, one namespace over -------------------------------------
  # The label goes BEFORE the separator (`## Rule 29 [ext:id] -- Title`), not after
  # the number-terminator as in the check form — a rule heading has no terminator to
  # put it after. Same discipline either way: INSERT into the matched prefix and
  # carry everything right of it through untouched, so an em-dash or a `:` separator
  # survives the rewrite.
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    rule_at="^#{2,4}[[:space:]]+Rule[[:space:]]+${n}[[:space:]]*"
    hd="$(grep -nE "${rule_at}(--|—|:)" "$ext" | grep -v '\[ext:' | grep -v '\[core\]' | head -1)"
    [ -n "$hd" ] || continue

    lineno="${hd%%:*}"
    text="${hd#*:}"
    # Same splice as the check pass above, for the same reasons; `rule_at` carries no `|`
    # today, and the day it does this line must not be the one that finds out.
    pre="$(printf '%s' "$text" | grep -oE "$rule_at" | head -1)"
    new="${pre}[ext:${id}] ${text#"$pre"}"

    found=$((found+1))
    printf '%s:%s\n  -  %s\n  +  %s\n' "${ext#$CONSUMER/}" "$lineno" "$text" "$new"

    if [ "$APPLY" = "--apply" ]; then
      tmp="$(mktemp)"
      awk -v ln="$lineno" -v repl="$new" 'NR==ln { print repl; next } { print }' "$ext" > "$tmp"
      mv "$tmp" "$ext"
      applied=$((applied+1))
    fi
  done <<< "$core_rules"
done < <(find "$EXT_DIR" -name '*.md' -type f | sort)

echo ""
if [ "$found" -eq 0 ]; then
  echo "relabel-extension-checks: no unlabelled core-number collisions."
  exit 0
fi
if [ "$APPLY" = "--apply" ]; then
  echo "relabel-extension-checks: labelled ${applied} colliding heading(s)."
  exit 0
fi
echo "relabel-extension-checks: ${found} colliding heading(s) need the [ext:<id>] label."
echo "  Re-run with --apply to write them. The integer never moves; only the label is added."
exit 1
