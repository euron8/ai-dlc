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
#   HARD-OVERRIDE-DRIFT-SECTION      shadowed section's text changed base..theirs, so
#                                    the override is now shadowing a rule that NO LONGER
#                                    EXISTS upstream. BLOCKS `apply` until adjudicated:
#                                    re-adopt the new clause into the override and
#                                    re-stamp base_sha, or confirm the old text still
#                                    applies and re-stamp anyway. Either way, LOOK.
#                                    Was advisory until v0.52.0, and that is precisely
#                                    how a core fix could land while the consumer went
#                                    on running the rule it replaced -- the lead reads
#                                    the OVERRIDE, not core. Distinct from
#                                    EXTENSION-CHECK-NUMBER-COLLISION below, which is
#                                    cosmetic, consumer-fixable, and must NOT block:
#                                    this one changes the RULES THE LEAD OBEYS.
#   OVERRIDE-DRIFT-FILE              anchor is not a locatable heading AND the file
#                                    changed -> cannot prove the section is safe;
#                                    surface for re-confirmation (never skip)
#   OVERRIDE-ANCHOR-UNRESOLVED       anchor not found in theirs (upstream restructured)
#   OVERRIDE-OK                      shadowed section unchanged
#   EXTENSION-HOOK-MISSING           hooks: target absent in theirs
#   EXTENSION-RETIRE-CANDIDATE       theirs' core file NEWLY defines a section this
#                                    extension also defines, matched by TITLE (at the
#                                    same number or a different one) -> upstream
#                                    absorbed it this pull; the consumer copy is now
#                                    a duplicate. THE absorption-retirement signal.
#   EXTENSION-RESTATES-CORE          same, but core already had it AT BASE. The
#                                    consumer has been carrying a duplicate of a core
#                                    section for some number of releases and was never
#                                    told, because the old detector only fired on the
#                                    single pull that landed the absorption. Rule 27(c)
#                                    forbids restating core: retire it, or refile as an
#                                    override with a base_sha if it hardens core.
#   EXTENSION-CHECK-NUMBER-COLLISION theirs' core file defines this extension's check
#                                    NUMBER with a DIFFERENT title -> one integer now
#                                    names two unrelated checks in the merged document,
#                                    so the bare "Check N" the lead commits to the gate
#                                    log has no referent. The exact complement of the
#                                    absorption signal. Report-only: a collision is
#                                    decidable and consumer-fixable, so it must not
#                                    block a pull (a consumer must never be unable to
#                                    take a security fix because its own catalog needs
#                                    relabelling). Tagged NEW-THIS-PULL / PRE-EXISTING.
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
#
# Three tolerances, each paid for by a real miss:
#   `Check `  core wrote one check as `### Check 24.` while every other is
#             `### 24.`; a digit-anchored regex skipped it, so the v0.48.0 number
#             collision was invisible to the tool built to surface layer drift.
#   letter    two consumer extensions head their checks `## Check AP — …` /
#             `## Check VH — …`, which yielded ZERO anchors. Both are
#             `push_candidate: true` — they ARE the push queue, the entries most
#             likely to be absorbed — so absorption of either could never fire.
#   `—`       those same headings separate id from title with an em-dash, not a dot.
#
# The id shape stays deliberately narrow -- `24`, `3b`, `11a`, `H1`, `AP` -- and is
# NOT a general word. A permissive `[A-Z]*[a-z-]*` would read `### Scope.` as an
# anchor named "Scope" and start diffing prose sections against each other.
ANCHOR_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]'
strip_anchor() { sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//; s/[[:space:]]*[.—]$//'; }
anchors_of_stream() {
  { grep -Eho "$ANCHOR_RE" | strip_anchor
  } 2>/dev/null | grep -E '.' | sort -u
}
anchors_of_file() {
  { grep -Eho "$ANCHOR_RE" "$1" 2>/dev/null | strip_anchor
    grep -Eho '^\*\*(Check[[:space:]]+)?[0-9]+[a-z-]*\.' "$1" 2>/dev/null \
      | sed -E 's/^\*\*(Check[[:space:]]+)?//; s/\.$//'
  } | grep -E '.' | sort -u
}

norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '`*' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g'; }

# Normalized heading TEXT for a given anchor, from a stream on stdin.
# e.g. anchor "1a" in "### 1a. Prior-Decision Search (settled corpus)" -> "prior decision search settled corpus"
heading_text_for() { # heading_text_for <anchor>  < stream
  awk -v a="$1" '
    function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "[.—]") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      h=$0; sub(/^#+[ \t]+/,"",h); sub(/^\*\*/,"",h); sub(/^Check[ \t]+/,"",h)
      sub("^" a "[.—][ \t]*","",h)
      # Strip the catalog label before normalizing, or "[ext:foo]" becomes part of the
      # title and a correctly-labelled heading can never match the core title.
      gsub(/\[ext:[A-Za-z0-9_.-]+\][ \t]*/, "", h); gsub(/\[core\][ \t]*/, "", h)
      print nrm(h); exit
    }' 2>/dev/null
}

# Does the heading at <anchor> carry an explicit catalog label?
#
# A labelled heading is the RESOLVED state of a number collision, not a violation:
# `### 25. [ext:foo] …` and core's `### 25.` name their catalogs at the point of use,
# which is exactly what the v0.49.0 crosswalk asks for.
#
# `validate-layer-entries.sh` learned this in v0.53.0. THIS script did not, so after a
# consumer correctly relabelled all 16 of its colliding headings, layer-drift went on
# reporting 11 collisions — on every pull, forever, for entries that are FIXED. It is
# report-only, so it corrupts nothing; it just trains the operator to stop reading the
# reconcile report. A report that is always wrong is a report nobody reads.
#
# Third instance in this project of the same defect: TWO implementations of one
# predicate, drifting apart. (readopt-override's resolver vs layer-drift's;
# register-drift's resolver vs layer-drift's; now this.)
heading_labelled_for() { # heading_labelled_for <anchor>  < stream
  awk -v a="$1" '
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "[.—]") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      print ($0 ~ /\[ext:[A-Za-z0-9_.-]+\]|\[core\]/) ? "yes" : "no"; exit
    }' 2>/dev/null
}

# Do two normalized headings describe the same section? Jaccard over significant
# tokens (>=0.6), OR near-total containment of the shorter title in the longer
# (>=0.75, which forgives an appended provenance tag like "[PI-S259-1 addendum]").
#
# The old rule -- >=2 shared tokens among the first 4 significant words -- was far
# too loose to carry the weight now placed on it. Verified: consumer check 22
# "Smoke test evidence (deploy-validate gate only)" and core check 11 "Smoke test
# coverage for user-facing changes?" share {smoke, test} and were judged the SAME
# section. Since a title match now drives EXTENSION-RETIRE-CANDIDATE, that pair
# would have told a consumer to delete a live deploy-validate check. A loose title
# match is worse than no title match: it turns a reporting tool into a data-loss bug.
#
# Consumer gate-validation check NUMBERS remain a sanctioned separate namespace
# (core's "Consumer-catalog crosswalk"), so a bare number match is never evidence
# of absorption on its own — the titles must agree too.
same_section() { # same_section <textA> <textB>
  [ -n "$1" ] && [ -n "$2" ] || return 1
  awk -v A="$1" -v B="$2" '
    BEGIN {
      split("the a an of and for to in on this its only gate gates", s, " ")
      for (i in s) stop[s[i]] = 1
      n = split(A, x, " "); for (i = 1; i <= n; i++) if (!(x[i] in stop)) a[x[i]] = 1
      n = split(B, y, " "); for (i = 1; i <= n; i++) if (!(y[i] in stop)) b[y[i]] = 1
      for (k in a) { na++; u++; if (k in b) inter++ }
      for (k in b) { nb++; if (!(k in a)) u++ }
      if (u == 0 || na == 0 || nb == 0) exit 1
      smaller = (na < nb) ? na : nb
      # NOTE: this awk is a single-quoted string. No apostrophes below, ever.
      #
      # Containment forgives an appended provenance tag -- but it DEGENERATES when the
      # shorter title has ONE significant token: inter/smaller is then 1/1 = 1.00 for any
      # title containing that word, and the OR short-circuits the jaccard test. The core
      # heading "### 2. Deploy" reduces to {deploy} (the stoplist eats gate/gates), so
      # every consumer heading naming deploy matched it at jaccard 0.12-0.20. Twelve of
      # the 166 anchored core headings reduce to one token: not a one-file accident.
      #
      # Requiring smaller >= 2 is the same rule as "containment needs >=2 shared
      # significant tokens": at 0.75, smaller=2 already forces inter=2.
      #
      # The cost is a real false NEGATIVE, not the impossibility it looks like: with a
      # 1-token core title and inter=1, jaccard is 1/nb, so a 2-token ext title scores
      # 0.5 and is now missed. That is the correct trade here -- this predicate drives
      # EXTENSION-RETIRE-CANDIDATE, which proposes DELETION, and a loose title match is
      # worse than no title match (see above).
      exit (inter / u >= 0.6 || (smaller >= 2 && inter / smaller >= 0.75)) ? 0 : 1
    }'
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

  # A multi-anchor override must report EVERY affected anchor, not just the last
  # one examined. Accumulate per category and compose the detail after the loop:
  # a single-section message on an override shadowing eight sections invites the
  # operator to reconcile that one and silently drop the rest.
  worst=OVERRIDE-OK
  drifted=""; unprovable=""; unresolved=""; whole_file=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ "$id" = "__file__" ]; then
      [ "$file_changed" = yes ] && { worst=OVERRIDE-DRIFT-FILE; whole_file="yes"; }
      continue
    fi
    s_theirs="$(git_show "$THEIRS" "$cp" | section_of "$id")"
    if [ -z "$s_theirs" ]; then
      if [ "$file_changed" = yes ]; then
        [ "$worst" = HARD-OVERRIDE-DRIFT-SECTION ] || worst=OVERRIDE-DRIFT-FILE
        unprovable="${unprovable:+$unprovable, }#$id"
      else
        [ "$worst" = OVERRIDE-OK ] && worst=OVERRIDE-ANCHOR-UNRESOLVED
        unresolved="${unresolved:+$unresolved, }#$id"
      fi
      continue
    fi
    s_base="$(git_show "$base_sha" "$cp" | section_of "$id")"
    if [ "$s_base" != "$s_theirs" ]; then
      worst=HARD-OVERRIDE-DRIFT-SECTION
      drifted="${drifted:+$drifted, }#$id"
    fi
  done <<< "$ids"

  # `emit` writes one tab-separated line, so the detail stays on one line.
  n_of() { printf '%s' "$1" | awk -F', ' '{print NF}'; }
  detail=""
  [ -n "$whole_file" ] && detail="whole-file shadow; file changed"
  if [ -n "$drifted" ]; then
    detail="${detail:+$detail; }$(n_of "$drifted") shadowed section(s) changed ${base_sha}..${THEIRS}: ${drifted}"
  fi
  if [ -n "$unprovable" ]; then
    detail="${detail:+$detail; }$(n_of "$unprovable") anchor(s) not a locatable heading in theirs; file changed -> cannot prove section safe: ${unprovable}"
  fi
  if [ -n "$unresolved" ]; then
    detail="${detail:+$detail; }$(n_of "$unresolved") anchor(s) not found in theirs: ${unresolved}"
  fi
  [ -n "$detail" ] || detail="shadowed section(s) unchanged"
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

  # Catalog reconciliation between this extension and the core file it hooks.
  #
  # The old rule tested ONE thing -- "is a section this extension defines NEWLY
  # defined upstream (present at theirs, absent at base)?" -- and reported nothing
  # otherwise. That is edge-triggered: it can only fire on the single pull that
  # lands an absorption, and never again. Miss that one report and the duplicate
  # rots forever, which is exactly what happened. A real consumer has carried the
  # SAME check as core since v0.13.0 (core says so in its own prose: "This is
  # graph's Check 21 absorbed as distribution Check 20") across ~35 minor versions
  # of pulls, and this tool said nothing on any of them, because by the time anyone
  # looked the section was no longer "new".
  #
  # Absorption is a STATE ("upstream now defines this section"), not an EVENT. So
  # test the state on every pull and use $BASE only to TAG the finding. And join on
  # BOTH axes, because the old number-keyed join was blind in both directions:
  #
  #   same number, same title   -> RESTATES-CORE / RETIRE-CANDIDATE (a duplicate)
  #   same number, diff  title  -> CHECK-NUMBER-COLLISION  (one integer, two checks)
  #   diff number, same title   -> absorbed-but-RENUMBERED (invisible to a number
  #                                join -- this is how the v0.13.0 duplicate hid)
  #   diff number, diff title   -> nothing; the catalogs are simply disjoint here
  ext_anchors="$(anchors_of_file "$f")"
  if [ -n "$ext_anchors" ]; then
    base_anchors="$(git_show "$BASE" "$cp" | anchors_of_stream)"
    theirs_blob="$(git_show "$THEIRS" "$cp")"
    theirs_anchors="$(printf '%s' "$theirs_blob" | anchors_of_stream)"

    while IFS= read -r a; do
      [ -n "$a" ] || continue
      t_ext="$(heading_text_for "$a" < "$f")"
      [ -n "$t_ext" ] || continue

      if printf '%s\n' "$theirs_anchors" | grep -Fxq -- "$a"; then
        # -- same NUMBER upstream. Title decides which defect this is.
        t_up="$(printf '%s' "$theirs_blob" | heading_text_for "$a")"
        if printf '%s\n' "$base_anchors" | grep -Fxq -- "$a"; then tag=PRE-EXISTING; else tag=NEW-THIS-PULL; fi

        if same_section "$t_ext" "$t_up"; then
          if [ "$tag" = NEW-THIS-PULL ]; then
            emit EXTENSION-RETIRE-CANDIDATE "$entry" "$hooks" \
              "NEW-THIS-PULL: upstream ${BASE}..${THEIRS} now defines '$a. $t_up', which this entry also defines — absorbed; retire the consumer copy"
          else
            emit EXTENSION-RESTATES-CORE "$entry" "$hooks" \
              "PRE-EXISTING: defines '$a. $t_ext', which core already defines at the SAME number and title — and did so at base, so the absorption signal never fired. Rule 27(c): an extension MUST NOT restate a core section; the copy cannot drift-check against the original, so it forks silently. If it only duplicates core, retire it; if it hardens or restricts core, refile it in overrides/ with a base_sha so drift is tracked."
          fi
          continue
        fi

        # A labelled heading is the RESOLVED state. Reporting it anyway means the
        # remedy this very message prescribes can never silence the message.
        if [ "$(heading_labelled_for "$a" < "$f")" = yes ]; then
          continue
        fi

        emit EXTENSION-CHECK-NUMBER-COLLISION "$entry" "$hooks" \
          "${tag}: '$a' names TWO different checks — here \"$t_ext\", in core \"$t_up\". Extensions are ADDITIVE, so both render into ONE merged list under ONE integer: the bare \"Check $a\" the lead writes into the gate log has no referent. Label the catalogs at the point of use (core \"### $a. [core] …\" vs this entry \"### $a. [ext:<id>] …\") and never attribute fire history across catalogs by number."
        # NO `continue` here. A number collision does NOT mean upstream lacks this
        # CHECK -- it may carry it under a DIFFERENT number, and then the entry is
        # both a collision and a duplicate. That is not hypothetical: a consumer's
        # push check 21 collides with core's 21 (test-strategy presence) AND *is*
        # core's 20 (validation-intensity), which core's own prose records as
        # "graph's Check 21 absorbed as distribution Check 20". Returning early here
        # would report the collision and silently drop the absorption -- the single
        # most important fact about that entry. Fall through to the title search.
      fi

      # -- is the same CHECK upstream under a DIFFERENT number?
      while IFS= read -r b; do
        [ "$b" = "$a" ] && continue
        [ -n "$b" ] || continue
        t_up="$(printf '%s' "$theirs_blob" | heading_text_for "$b")"
        same_section "$t_ext" "$t_up" || continue
        if printf '%s\n' "$base_anchors" | grep -Fxq -- "$b"; then
          emit EXTENSION-RESTATES-CORE "$entry" "$hooks" \
            "PRE-EXISTING (renumbered): this entry's '$a. $t_ext' IS core's '$b. $t_up'. Upstream absorbed it under a DIFFERENT number, so a number-keyed retirement signal could never fire and the duplicate has been carried silently ever since. Retire it, or refile as an override if it hardens core."
        else
          emit EXTENSION-RETIRE-CANDIDATE "$entry" "$hooks" \
            "NEW-THIS-PULL (renumbered): upstream now defines this entry's '$a. $t_ext' as core '$b' — absorbed under a different number; retire the consumer copy"
        fi
        break
      done <<< "$theirs_anchors"
    done <<< "$ext_anchors"
  fi

  if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- "$cp" 2>/dev/null; then
    emit EXTENSION-OK "$entry" "$hooks" "hooked core file unchanged"
  else
    emit EXTENSION-HOOK-DRIFT "$entry" "$hooks" "hooked core file changed ${BASE}..${THEIRS} — extensions have no section anchor; re-read this entry against the new core text"
  fi
done < <(layer_files "$EXT_DIR")
