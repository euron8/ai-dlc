#!/usr/bin/env bash
# readopt-override.sh — carry the operator through a HARD-OVERRIDE-DRIFT-SECTION.
#
# `layer-drift.sh` says the shadowed core section changed, so the override is now
# shadowing a rule that no longer exists upstream. Blocking there is necessary and
# not sufficient: stopping is not landing. This is the workflow that ends the block.
#
# THE TRAP THIS SCRIPT EXISTS TO CLOSE. Drift is computed as
# `core@base_sha[section] != core@theirs[section]`, so re-stamping `base_sha :=
# theirs` makes the two sides equal and the HARD status evaporates — WITHOUT the
# operator having merged one word of the new core text into the override body. The
# lead reads the OVERRIDE, not core. A bare re-stamp is "proceed by doing nothing"
# wearing a stamp, and it is precisely how a core fix lands on disk while the
# pipeline goes on running the rule it replaced.
#
# So `--stamp` is GATED. It refuses while the override body still contains a line
# that core carried at `base_sha` and does NOT carry at `theirs` — a superseded
# core line, copied into the override, now stale. That test is mechanical (set
# difference over lines), it fails RED on the real defect today, and it can only
# be cleared by actually editing the body or by an explicit, recorded re-affirm.
#
# Usage:
#   readopt-override.sh <dist> <theirs> <consumer> <override>            # dossier (default)
#   readopt-override.sh <dist> <theirs> <consumer> <override> --check    # gate only; exit 1 if stale
#   readopt-override.sh <dist> <theirs> <consumer> <override> --stamp <outcome> [--note "..."]
#     <outcome> = readopt   body re-adopted; --check must pass; re-stamps base_sha
#                 reaffirm  old core text deliberately kept; REQUIRES --note; re-stamps
#                 retire    upstream absorbed it; deletes the override file
#
# Exit: 0 ok / 1 blocked (stale core text still in the body) / 2 usage.
set -uo pipefail

DIST="${1:?usage: readopt-override.sh <dist> <theirs> <consumer> <override> [--check|--stamp <outcome>]}"
THEIRS="${2:?}"
CONSUMER="${3:?}"
OVR="${4:?}"
MODE="${5:-}"
OUTCOME="${6:-}"

[ -f "$OVR" ] || { echo "readopt-override: no such override: $OVR" >&2; exit 2; }

NOTE=""
prev=""
for arg in "$@"; do
  [ "$prev" = "--note" ] && NOTE="$arg"
  prev="$arg"
done

fm() { sed -n '/^---$/,/^---$/p' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

SHADOWS="$(fm "$OVR" shadows)"
BASE_SHA="$(fm "$OVR" base_sha)"
TARGET="$(printf '%s' "${SHADOWS%%#*}" | tr -d ' ' | sed 's/,.*//')"

# Same mapping layer-drift.sh uses. Getting this wrong does not error — it makes
# `git show` return nothing, both sides of the set difference come back empty, and
# the gate reports OK on a live defect. A check that cannot fire, reading as a
# check that passed.
case "$TARGET" in
  team-roles/*) CORE="core/${TARGET}" ;;
  *)            CORE="core/skills/ai-dlc/${TARGET}" ;;
esac

[ -n "$BASE_SHA" ] || { echo "readopt-override: override has no base_sha:" >&2; exit 2; }

# Section resolver — byte-for-byte the one in layer-drift.sh, deliberately.
#
# A WEAKER resolver here is not a cosmetic divergence: layer-drift decides the
# section DRIFTED and blocks, this script then fails to resolve the same anchor,
# finds no stale lines, and clears the block. Two resolvers means the gate and its
# remedy can disagree, and the remedy always wins. (Caught live: the anchor
# "Empirical gate validation (the `Enforcement:` paragraph)" is a descriptive
# label whose heading is just "## Empirical gate validation" — layer-drift's
# bidirectional-substring match resolves it; an exact/prefix match does not.)
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '`*' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g'; }

section_of() {
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

# Does every anchor in `shadows:` resolve in BOTH base and theirs?
#
# If an anchor resolves nowhere, `stale_lines` compares two empty sets, finds
# nothing, and reports the body clean — a check that CANNOT FAIL, gating the very
# re-stamp it exists to withhold. So an unresolvable anchor is not "clean", it is
# UNDECIDABLE, and `--stamp readopt` is refused on it. The operator can still get
# past with `--stamp reaffirm --note`, which puts a human's name on the decision.
anchors_resolve() {
  local id ok=yes
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ -z "$(git -C "$DIST" show "${THEIRS}:${CORE}" 2>/dev/null | section_of "$id")" ] \
    || [ -z "$(git -C "$DIST" show "${BASE_SHA}:${CORE}" 2>/dev/null | section_of "$id")" ]; then
      ok=no
      printf 'UNRESOLVED-ANCHOR  #%s does not resolve to a heading in %s at %s/%s\n' \
        "$id" "$CORE" "$BASE_SHA" "$THEIRS_SHA" >&2
    fi
  done < <(printf '%s\n' "$SHADOWS" | tr ',' '\n' | sed -n 's/.*#//p' | sed 's/^ *//; s/ *$//')
  printf '%s' "$ok"
}

THEIRS_SHA="$(git -C "$DIST" rev-parse --short "$THEIRS")"

# ---------------------------------------------------------------------------
# The gate: superseded core lines still sitting in the override body.
#
# A line qualifies iff it is (a) substantive, (b) present in core@base_sha's
# shadowed section, (c) ABSENT from core@theirs' section, and (d) still present
# in the override body. That is a line the override copied from a core rule that
# upstream has since rewritten — the split-brain, stated as a set.
#
# Trivial lines (blank, punctuation, fence markers, short fragments) are excluded:
# they collide by coincidence, not by copying, and a gate that trips on "```" is a
# gate someone comments out.
# ---------------------------------------------------------------------------
stale_lines() {
  local ids
  ids="$(printf '%s' "$SHADOWS" | tr ',' '\n' | sed -n 's/.*#//p' | sed 's/^ *//; s/ *$//')"
  local id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    comm -23 \
      <(git -C "$DIST" show "${BASE_SHA}:${CORE}" 2>/dev/null | section_of "$id" \
          | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -vE '^.{0,24}$' | sort -u) \
      <(git -C "$DIST" show "${THEIRS}:${CORE}"   2>/dev/null | section_of "$id" \
          | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -vE '^.{0,24}$' | sort -u) \
    | while IFS= read -r line; do
        [ -n "$line" ] || continue
        grep -Fqx -- "$line" <(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$OVR") && printf '%s\n' "$line"
      done
  done <<< "$ids"
}

STALE="$(stale_lines)"
N_STALE=0
[ -n "$STALE" ] && N_STALE="$(printf '%s\n' "$STALE" | grep -c .)"
RESOLVE="$(anchors_resolve 2>/dev/null)"

# ---------------------------------------------------------------------------
case "$MODE" in
  --check)
    if [ "$RESOLVE" != yes ]; then
      echo "UNDECIDABLE  $(basename "$OVR"): a shadowed anchor does not resolve to a heading in core."
      anchors_resolve >/dev/null
      echo "  The stale-text test compares two empty sections and would pass on ANY body."
      echo "  Repoint \`shadows:\` at a real heading, or --stamp reaffirm --note \"<why>\"."
      exit 1
    fi
    if [ "$N_STALE" -gt 0 ]; then
      echo "STALE-CORE-TEXT  $(basename "$OVR"): ${N_STALE} line(s) copied from core@${BASE_SHA} that core@${THEIRS_SHA} NO LONGER CONTAINS."
      printf '%s\n' "$STALE" | sed 's/^/    | /'
      echo "  The lead obeys this override, not core. Re-adopt the new core text into the body,"
      echo "  or --stamp reaffirm --note \"<why the old clause still stands>\"."
      exit 1
    fi
    echo "OK  $(basename "$OVR"): body carries no superseded core text."
    exit 0
    ;;

  --stamp)
    case "$OUTCOME" in
      retire)
        rm -f "$OVR"
        echo "RETIRED  $(basename "$OVR") deleted — upstream absorbed it."
        exit 0
        ;;
      readopt)
        if [ "$RESOLVE" != yes ]; then
          echo "REFUSED  $(basename "$OVR"): a shadowed anchor resolves to no heading, so the stale-text test is VACUOUS." >&2
          anchors_resolve >/dev/null
          echo "  Refusing to clear a HARD block with a check that cannot fail. Repoint \`shadows:\`," >&2
          echo "  or --stamp reaffirm --note \"<why the old clause still stands>\"." >&2
          exit 1
        fi
        if [ "$N_STALE" -gt 0 ]; then
          echo "REFUSED  $(basename "$OVR"): ${N_STALE} superseded core line(s) still in the body." >&2
          printf '%s\n' "$STALE" | sed 's/^/    | /' >&2
          echo "  A bare re-stamp would clear the HARD block while leaving the lead obeying the OLD rule." >&2
          echo "  Edit the body to carry core@${THEIRS_SHA}'s text, then re-run. Or: --stamp reaffirm --note \"...\"" >&2
          exit 1
        fi
        ;;
      reaffirm)
        [ -n "$NOTE" ] || { echo "REFUSED  reaffirm REQUIRES --note \"<why the old clause still stands>\" — the record must show a human decided." >&2; exit 1; }
        ;;
      *) echo "readopt-override: --stamp needs one of: readopt | reaffirm | retire" >&2; exit 2;;
    esac

    tmp="$(mktemp)"
    if [ "$OUTCOME" = reaffirm ]; then
      awk -v s="$THEIRS_SHA" -v n="RE-AFFIRMED against ${THEIRS_SHA}: ${NOTE}" '
        BEGIN{done_sha=0}
        /^base_sha:/ && !done_sha { print "base_sha: " s; done_sha=1; next }
        /^reason:/ && !done_r { print $0 " " n; done_r=1; next }
        { print }
      ' "$OVR" > "$tmp"
    else
      awk -v s="$THEIRS_SHA" '
        BEGIN{done_sha=0}
        /^base_sha:/ && !done_sha { print "base_sha: " s; done_sha=1; next }
        { print }
      ' "$OVR" > "$tmp"
    fi
    mv "$tmp" "$OVR"
    echo "STAMPED  $(basename "$OVR"): base_sha ${BASE_SHA} -> ${THEIRS_SHA} (${OUTCOME})"
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Default: the dossier. Everything the operator needs to answer ONE question.
# ---------------------------------------------------------------------------
cat <<EOF
================================================================================
RE-ADOPTION DOSSIER — $(basename "$OVR")
================================================================================
shadows   : ${SHADOWS}
base_sha  : ${BASE_SHA}  ->  theirs: ${THEIRS_SHA}
core file : ${CORE}

--- WHY THIS OVERRIDE EXISTS (its own stated reason) --------------------------
$(fm "$OVR" reason | fold -s -w 78 | sed 's/^/  /' | head -20)

--- WHAT UPSTREAM CHANGED IN THE SHADOWED SECTION (${BASE_SHA}..${THEIRS_SHA}) ---
EOF

# `printf '%s\n'`, not `printf '%s'`. Without the trailing newline `while read`
# fails its condition on the final line and the loop body NEVER RUNS -- the dossier
# then prints an EMPTY "what upstream changed" panel and reads as "nothing changed"
# on a section that changed. Silent, and exactly the class of defect this release
# is about. (`stale_lines` escaped it only because a here-string appends one.)
printf '%s\n' "$SHADOWS" | tr ',' '\n' | sed -n 's/.*#//p' | sed 's/^ *//; s/ *$//' \
| while IFS= read -r id; do
    [ -n "$id" ] || continue
    echo "  ## ${id}"
    diff -u \
      <(git -C "$DIST" show "${BASE_SHA}:${CORE}" 2>/dev/null | section_of "$id") \
      <(git -C "$DIST" show "${THEIRS}:${CORE}"   2>/dev/null | section_of "$id") \
      | tail -n +3 | sed 's/^/    /'
  done

cat <<EOF

--- SUPERSEDED CORE TEXT STILL IN THIS OVERRIDE'S BODY -------------------------
EOF
if [ "$N_STALE" -gt 0 ]; then
  printf '%s\n' "$STALE" | sed 's/^/    | /'
  echo ""
  echo "  ${N_STALE} line(s) above are core text from ${BASE_SHA} that ${THEIRS_SHA} REPLACED."
  echo "  The lead obeys this override, not core: un-migrated, the fix is INERT here."
else
  echo "    (none — the body carries no text upstream has superseded)"
fi

cat <<EOF

--- THE ONE QUESTION -----------------------------------------------------------
  Does upstream's change SUPERSEDE the reason this override exists?

  YES, entirely      -> retire    the override is redundant; core now does this.
       readopt-override.sh <dist> ${THEIRS} <consumer> ${OVR} --stamp retire

  NO, but core's new text must be carried into it
                     -> readopt   merge the new core text into the body, preserving
                                  the consumer's delta, THEN stamp. The stamp is
                                  REFUSED while superseded core lines remain.
       \$EDITOR ${OVR}
       readopt-override.sh <dist> ${THEIRS} <consumer> ${OVR} --stamp readopt

  NO, and the old clause still stands as written
                     -> reaffirm  requires a note; it goes into the record.
       readopt-override.sh <dist> ${THEIRS} <consumer> ${OVR} --stamp reaffirm --note "..."

  DOING NOTHING IS NOT AN OUTCOME. The HARD block persists until base_sha is
  re-stamped, and a bare re-stamp is refused while the body is stale.
================================================================================
EOF
