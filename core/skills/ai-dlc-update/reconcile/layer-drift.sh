#!/usr/bin/env bash
# ai-dlc-update — layer-drift detection for the Rule 27 consumer layers.
#
# Mechanizes what was previously PROSE ONLY. `SKILL.md`'s "Layered consumers"
# section told the agent to check, per override, whether upstream changed the
# core rule it shadows. Nothing implemented it: `preclassify.sh` never referenced
# `extensions`/`overrides`/`base_sha`/`shadows`/`hooks`. So the check depended on
# an agent remembering to run `git diff` twelve times, and in practice it never
# ran. A real consumer accumulated 5 overrides whose `base_sha` pointed at the
# CONSUMER's own repo (so any diff would have died on `fatal: bad revision`), and
# two shipped upstream changes were silently discarded by a stale override.
#
# Self-contained per the skill's HARD CONSTRAINT: shells to git, reads only layer
# FRONTMATTER and markdown headings. It classifies text; it never interprets a
# pipeline rule.
#
# Usage: layer-drift.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#   dist-repo      path to the distribution git checkout (source of core/)
#   base-sha       the `commit` field from the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref (e.g. main, HEAD, a tag)
#   consumer-root  the consumer project root (contains .claude/)
#
# Output: TSV to stdout — STATUS<TAB>ENTRY<TAB>TARGET<TAB>DETAIL
# Exit:   0 always (a classifier, not a gate). The CALLER decides; statuses
#         prefixed HARD- must block `apply` until the operator adjudicates.
#
# Statuses
#   HARD-OVERRIDE-BASE-CONSUMER-SHA  base_sha resolves in the CONSUMER repo, so it
#                                    is the wrong repo's sha; drift undecidable
#   HARD-OVERRIDE-BASE-UNRESOLVABLE  base_sha resolves in neither repo
#   OVERRIDE-DRIFT-SECTION           shadowed section's text changed base..theirs
#   OVERRIDE-DRIFT-FILE              anchor is not a locatable heading AND the file
#                                    changed -> cannot prove the section is safe;
#                                    surface for re-confirmation (never skip)
#   OVERRIDE-ANCHOR-UNRESOLVED       anchor not found in theirs (upstream restructured)
#   OVERRIDE-OK                      shadowed section unchanged
#   EXTENSION-HOOK-MISSING           hooks: target absent in theirs
#   EXTENSION-RETIRE-CANDIDATE       a section this extension defines is NEWLY
#                                    defined by theirs' core file (absent at base)
#                                    -> upstream absorbed it; the consumer copy is
#                                    now a duplicate. THE absorption-retirement signal.
#   EXTENSION-HOOK-DRIFT             hooked core file changed base..theirs
#                                    (file-grain: extensions carry no finer anchor)
#   EXTENSION-OK                     hooked core file unchanged

set -uo pipefail

[ $# -eq 4 ] || { echo "usage: layer-drift.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>" >&2; exit 2; }
DIST="$1"; BASE="$2"; THEIRS="$3"; CONSUMER="$4"

SKILL_DIR="$CONSUMER/.claude/skills/ai-dlc"
EXT_DIR="$SKILL_DIR/extensions"
OVR_DIR="$SKILL_DIR/overrides"

emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# core/-relative layer target -> path INSIDE the distribution tree.
dist_path() {
  case "$1" in
    team-roles/*) printf 'core/%s' "$1" ;;
    *)            printf 'core/skills/ai-dlc/%s' "$1" ;;
  esac
}

fm() { # fm <file> <key>
  awk -v k="$2" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf && index($0, k":")==1 { sub("^"k":[[:space:]]*", ""); print; exit }
  ' "$1"
}

layer_files() { [ -d "$1" ] || return 0; find "$1" -type f -name '*.md' ! -name 'README.md' 2>/dev/null | sort; }
rel() { printf '%s' "${1#"$CONSUMER"/}"; }

git_show() { git -C "$DIST" show "$1:$2" 2>/dev/null; }
have()     { git -C "$DIST" cat-file -e "$1:$2" 2>/dev/null; }

# Section anchors a markdown STREAM defines: `### 5c. T` headings + `**7a-post. T**`
# bold anchors (an override defines 7a-post the bold way).
anchors_of_stream() {
  { grep -Eho '^#{2,4}[[:space:]]+[0-9]+[a-z-]*\.' | sed -E 's/^#+[[:space:]]+//'
  } 2>/dev/null | sed -E 's/\.$//' | sort -u
}
anchors_of_file() {
  { grep -Eho '^#{2,4}[[:space:]]+[0-9]+[a-z-]*\.' "$1" 2>/dev/null | sed -E 's/^#+[[:space:]]+//'
    grep -Eho '^\*\*[0-9]+[a-z-]*\.'               "$1" 2>/dev/null | sed -E 's/^\*\*//'
  } | sed -E 's/\.$//' | sort -u
}

norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '`*' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g'; }

# Normalized heading TEXT for a given anchor number, from a stream on stdin.
# e.g. anchor "1a" in "### 1a. Prior-Decision Search (settled corpus)" -> "prior decision search settled corpus"
heading_text_for() { # heading_text_for <anchor>  < stream
  awk -v a="$1" '
    function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
    $0 ~ ("^#{2,4}[ \t]+" a "\\.") || $0 ~ ("^\\*\\*" a "\\.") {
      h=$0; sub(/^#+[ \t]+/,"",h); sub(/^\*\*/,"",h); sub("^" a "\\.[ \t]*","",h)
      print nrm(h); exit
    }' 2>/dev/null
}

# Do two normalized headings describe the same section? Require >=2 shared tokens
# among the first 4 significant words. Consumer gate-validation check NUMBERS are
# a sanctioned separate namespace (core's "Consumer-catalog crosswalk"), so a bare
# number match is NOT evidence of absorption — the titles must agree too.
same_section() { # same_section <textA> <textB>
  [ -n "$1" ] && [ -n "$2" ] || return 1
  local shared=0 w
  for w in $(printf '%s' "$1" | tr ' ' '\n' | grep -vE '^(the|a|an|of|and|for|to|in|on)$' | head -4); do
    printf '%s\n' $2 | grep -Fxq -- "$w" && shared=$((shared+1))
  done
  [ "$shared" -ge 2 ]
}

# Extract the section named by <id> from a markdown stream on stdin.
# Prints nothing (rc 1) if no heading matches.
section_of() { # section_of <id>  < stream
  awk -v want="$(norm "$1")" '
    function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
    /^#{2,6}[ \t]/ {
      match($0, /^#+/); lvl = RLENGTH
      h = $0; sub(/^#+[ \t]+/, "", h); h = nrm(h)
      if (inside) { if (lvl <= mylvl) exit }
      else if (want != "" && (index(h, want) > 0 || (length(h) > 3 && index(want, h) > 0))) {
        inside = 1; mylvl = lvl; print; next
      }
    }
    inside { print }
  '
}

# ---------------------------------------------------------------------------
# Overrides
# ---------------------------------------------------------------------------
while IFS= read -r f; do
  [ -n "$f" ] || continue
  entry="$(rel "$f")"
  shadows="$(fm "$f" shadows)"; base_sha="$(fm "$f" base_sha)"
  tgt="$(printf '%s' "${shadows%%#*}" | tr -d ' ' | sed 's/,.*//')"
  [ -n "$tgt" ] || { emit OVERRIDE-ANCHOR-UNRESOLVED "$entry" "?" "no shadows: target"; continue; }
  cp="$(dist_path "$tgt")"

  # base_sha provenance — fail LOUD, never skip (this is the whole point).
  if [ -z "$base_sha" ]; then
    emit HARD-OVERRIDE-BASE-UNRESOLVABLE "$entry" "$tgt" "no base_sha in frontmatter"; continue
  fi
  if ! git -C "$DIST" rev-parse -q --verify "${base_sha}^{commit}" >/dev/null 2>&1; then
    if git -C "$CONSUMER" rev-parse -q --verify "${base_sha}^{commit}" >/dev/null 2>&1; then
      subj="$(git -C "$CONSUMER" log -1 --format='%s' "$base_sha" 2>/dev/null | cut -c1-40)"
      emit HARD-OVERRIDE-BASE-CONSUMER-SHA "$entry" "$tgt" "base_sha $base_sha is a CONSUMER commit (${subj}); must be a distribution sha"
    else
      emit HARD-OVERRIDE-BASE-UNRESOLVABLE "$entry" "$tgt" "base_sha $base_sha resolves in neither repo"
    fi
    continue
  fi

  have "$THEIRS" "$cp" || { emit OVERRIDE-ANCHOR-UNRESOLVED "$entry" "$tgt" "target absent at $THEIRS"; continue; }

  file_changed=no
  if ! git -C "$DIST" diff --quiet "$base_sha" "$THEIRS" -- "$cp" 2>/dev/null; then file_changed=yes; fi

  # Evaluate every anchor in a possibly multi-anchor `shadows:` value.
  ids="$(printf '%s' "$shadows" | tr ',' '\n' | sed -n 's/.*#//p' | sed 's/^ *//; s/ *$//')"
  [ -n "$ids" ] || ids="__file__"

  worst=OVERRIDE-OK
  detail=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ "$id" = "__file__" ]; then
      [ "$file_changed" = yes ] && { worst=OVERRIDE-DRIFT-FILE; detail="whole-file shadow; file changed"; }
      continue
    fi
    s_theirs="$(git_show "$THEIRS" "$cp" | section_of "$id")"
    if [ -z "$s_theirs" ]; then
      if [ "$file_changed" = yes ]; then
        [ "$worst" = OVERRIDE-DRIFT-SECTION ] || worst=OVERRIDE-DRIFT-FILE
        detail="anchor '#$id' not a locatable heading in theirs; file changed -> cannot prove section safe"
      else
        [ "$worst" = OVERRIDE-OK ] && { worst=OVERRIDE-ANCHOR-UNRESOLVED; detail="anchor '#$id' not found in theirs"; }
      fi
      continue
    fi
    s_base="$(git_show "$base_sha" "$cp" | section_of "$id")"
    if [ "$s_base" != "$s_theirs" ]; then
      worst=OVERRIDE-DRIFT-SECTION
      detail="shadowed section '#$id' changed ${base_sha}..${THEIRS}"
    fi
  done <<< "$ids"

  [ "$worst" = OVERRIDE-OK ] && detail="shadowed section(s) unchanged"
  emit "$worst" "$entry" "$tgt" "$detail"
done < <(layer_files "$OVR_DIR")

# ---------------------------------------------------------------------------
# Extensions
#
# The comparison base here is $BASE (the consumer's stamp commit — the last core
# it received), NOT any per-override base_sha. Unset that loop-local so a stale
# value can never leak in: reusing it silently made every hooked file look
# drifted, because a poisoned override sha does not resolve in the distribution.
# ---------------------------------------------------------------------------
unset base_sha
while IFS= read -r f; do
  [ -n "$f" ] || continue
  entry="$(rel "$f")"
  hooks="$(fm "$f" hooks | awk '{print $1}')"
  [ -n "$hooks" ] || { emit EXTENSION-HOOK-MISSING "$entry" "?" "no hooks: frontmatter"; continue; }
  cp="$(dist_path "$hooks")"

  have "$THEIRS" "$cp" || { emit EXTENSION-HOOK-MISSING "$entry" "$hooks" "hooks target absent at $THEIRS"; continue; }

  # Retirement signal: a section this extension defines is NEWLY defined upstream
  # (present at theirs, absent at base) -> upstream absorbed it.
  ext_anchors="$(anchors_of_file "$f")"
  if [ -n "$ext_anchors" ]; then
    base_anchors="$(git_show "$BASE" "$cp" | anchors_of_stream)"
    theirs_anchors="$(git_show "$THEIRS" "$cp" | anchors_of_stream)"
    theirs_blob="$(git_show "$THEIRS" "$cp")"
    absorbed=""
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      printf '%s\n' "$theirs_anchors" | grep -Fxq -- "$a" || continue
      printf '%s\n' "$base_anchors"   | grep -Fxq -- "$a" && continue
      # Number match alone is not absorption: consumer gate-check numbers are a
      # sanctioned separate namespace. Require the titles to agree too.
      t_ext="$(heading_text_for "$a" < "$f")"
      t_up="$(printf '%s' "$theirs_blob" | heading_text_for "$a")"
      same_section "$t_ext" "$t_up" && absorbed="$absorbed $a"
    done <<< "$ext_anchors"
    if [ -n "$absorbed" ]; then
      emit EXTENSION-RETIRE-CANDIDATE "$entry" "$hooks" "upstream newly defines section(s)${absorbed} that this extension also defines — absorbed; retire the consumer copy"
      continue
    fi
  fi

  if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- "$cp" 2>/dev/null; then
    emit EXTENSION-OK "$entry" "$hooks" "hooked core file unchanged"
  else
    emit EXTENSION-HOOK-DRIFT "$entry" "$hooks" "hooked core file changed ${BASE}..${THEIRS} — extensions have no section anchor; re-read this entry against the new core text"
  fi
done < <(layer_files "$EXT_DIR")
