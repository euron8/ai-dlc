#!/usr/bin/env bash
# install-scaffold-ignore.sh -- install.sh's report of create-once scaffold paths the target's git
# ignore rules hide (BL-992). SOURCED, never run: it holds only function definitions and comments,
# so install.sh can load it under its `set -e` with no side effect. DISTRIBUTION-ONLY, like install.sh
# beside it: install.sh loads it from its own directory and nothing installs it into a consumer.
#
# THE DECISION AND THE REMEDY ARE NOT HERE. Both live in core/skills/ai-dlc-update/reconcile/
# scaffold-ignore.sh (`scaffold_ignore_state`, `scaffold_ignore_remedy`), the one file apply.sh
# reads for the same question. install.sh sources that file before this one; these functions
# only CALL it, so an install and a pull cannot give one path two answers or two remedy texts.
#
# ai_dlc_once_paths <dist_root>
#   Prints every create-once, consumer-owned path install.sh scaffolds, project-relative, one per
#   line: each `consumer_*_file:` value of <dist_root>/core/skills/ai-dlc/layer-contract.yaml,
#   then the two rulebook-layer READMEs, then the feedback log. DERIVED from the declaration
#   install.sh itself reads, so a new declared file joins the report without an edit here.
#   Returns 2, printing nothing on stdout, when the declaration yields no key: an empty population
#   would report a clean tree having checked nothing.
#
# ai_dlc_scaffold_ignore_report <project_root> <dist_root>
#   Prints the report and returns 0, or returns 2 when the population has no key. Outside a
#   git WORK TREE (no repository, a bare one, a cwd inside .git) it prints only
#   `  scaffold ignore check SKIPPED: <project_root> is not a git work tree`: there `check-ignore`
#   answers 128 for every path, which is no fact about the consumer's rules. Inside one it prints
#   the header and `  (git work tree: <top>)`, then, for each population path that EXISTS:
#     ignored        `  WARNING scaffold-ignored <rel> "<remedy>"`
#     unchecked:<rc> `  WARNING scaffold-ignore-unchecked <rel> (git check-ignore exited <rc>)`
#     exact          nothing: the consumer ignored this exact path on purpose
#     untracked-ok   nothing: not ignored, or tracked
#   and, after any `scaffold-ignored` line, `  Run the git commands above from <project_root>.`
#     any other word, an EMPTY one included
#                    `  WARNING scaffold-ignore-unchecked <rel> (scaffold_ignore_state answered '<word>')`
#   Only `exact` and `untracked-ok` acquit a path. A missing or renamed decision function answers
#   an empty word, and reading that as "not ignored" would print a clean report over no check; it
#   is a row, never a non-zero return, so install.sh's `set -e` cannot end the install on it.
#
# GIT_DIR AND ITS SIBLINGS ARE UNSET around the whole report, as install.sh's ai_dlc_src_git does
# for its own calls: an inherited GIT_DIR (install.sh run from a hook) would answer every
# `git -C <project_root>` question about the CALLING repository's rules.
ai_dlc_once_paths() { # <dist_root>
  local keys layer
  keys="$(sed -n 's/^consumer_[a-z_]*_file:[[:space:]]*//p' \
    "$1/core/skills/ai-dlc/layer-contract.yaml" 2>/dev/null | sed 's/[[:space:]]*$//')" || keys=""
  if [ -z "$keys" ]; then
    echo "  ERROR: $1/core/skills/ai-dlc/layer-contract.yaml declares no 'consumer_*_file:' key; the scaffold ignore check has no population." >&2
    return 2
  fi
  printf '%s\n' "$keys"
  for layer in extensions overrides; do
    printf '.claude/skills/ai-dlc/%s/README.md\n' "$layer"
  done
  printf '%s\n' "docs/ai-dlc-feedback.md"
}

ai_dlc_scaffold_ignore_report() { # <project_root> <dist_root>
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    ai_dlc_scaffold_ignore_report_ "$@" )
}

ai_dlc_scaffold_ignore_report_() { # <project_root> <dist_root>
  local root="$1" dist="$2" paths rel line st prov hits=0
  if [ "$(git -C "$root" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
    echo "  scaffold ignore check SKIPPED: $root is not a git work tree"
    return 0
  fi
  paths="$(ai_dlc_once_paths "$dist")" || return 2
  echo "Checking scaffolded files against git ignore rules..."
  echo "  (git work tree: $(git -C "$root" rev-parse --show-toplevel 2>/dev/null))"
  while IFS= read -r rel; do
    [ -e "$root/$rel" ] || continue
    line="$(scaffold_ignore_state "$root" "$rel")" || line=""
    st="${line%%$'\t'*}"
    prov="${line#*$'\t'}"
    case "$st" in
      ignored)
        echo "  WARNING scaffold-ignored $rel \"$(scaffold_ignore_remedy "$rel" "$prov")\""
        hits=$((hits + 1)) ;;
      unchecked:*)
        echo "  WARNING scaffold-ignore-unchecked $rel (git check-ignore exited ${st#unchecked:})" ;;
      exact|untracked-ok) : ;;
      *)
        echo "  WARNING scaffold-ignore-unchecked $rel (scaffold_ignore_state answered '$st')" ;;
    esac
  done <<EOF
$paths
EOF
  if [ "$hits" -gt 0 ]; then
    echo "  Run the git commands above from $root."
  fi
  return 0
}
