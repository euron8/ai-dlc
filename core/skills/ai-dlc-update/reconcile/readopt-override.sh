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

# fm_block — the same read for a field that may be a YAML BLOCK SCALAR (`|` / `>`).
#
# `fm()` is `… | head -1`, which on `reason: |` captures the indicator character and nothing
# else, so the dossier's "WHY THIS OVERRIDE EXISTS" panel rendered a bare `|`. Eight of the
# reference consumer's overrides declare `reason:` as a block; every one printed empty. SKILL.md
# step 7's retire / readopt / reaffirm decision turns on exactly that field, so the operator was
# adjudicating a re-adoption against a blank rationale.
#
# The `--note` WRITER in this same file has tracked block scalars since the corruption it
# documents at its `inreason` loop; only the reader never got the treatment. The block-END rule
# here is that writer's rule — an unindented `key:` closes it — so reader and writer cannot
# disagree about where a reason stops.
#
# fm() keeps its single-line semantics for `shadows` and `base_sha`: widening the shared reader
# would change how two fields parse to fix a third.
fm_block() { # fm_block <file> <key>
  awk -v k="$2" '
    NR==1 && /^---$/                       { fm=1; next }
    fm && /^---$/                          { exit }
    fm && !inb && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v)
      if (v ~ /^[|>][0-9]*[-+]?$/) { inb = 1; next }
      print v; exit
    }
    fm && inb && /^[A-Za-z_][A-Za-z0-9_]*:/ { exit }
    fm && inb                              { sub(/^[ \t]+/, "", $0); print }
  ' "$1"
}

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

# section_of()/norm() — the ONE resolver, from lib.sh.
#
# A WEAKER resolver here is not a cosmetic divergence: layer-drift decides the
# section DRIFTED and blocks, this script then fails to resolve the same anchor,
# finds no stale lines, and clears the block. Two resolvers means the gate and its
# remedy can disagree, and the remedy always wins. That shipped, in v0.52.0.
# (Caught live: the anchor "Empirical gate validation (the `Enforcement:`
# paragraph)" is a descriptive label whose heading is just "## Empirical gate
# validation" — the bidirectional-substring match resolves it; an exact/prefix
# match does not.)
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "readopt-override: cannot source $SELF/lib.sh" >&2; exit 1; }

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

  --merge)
    # Re-adoption is a THREE-WAY MERGE, not a hand edit.
    #
    #   base   = the core section at the override's base_sha  (what it forked from)
    #   ours   = the override body                            (base + the consumer delta)
    #   theirs = the core section at theirs                   (base + the upstream change)
    #
    # git merge-file applies the upstream change to the consumer's copy and keeps the
    # delta. Telling the operator to "merge the new core text in, preserving your
    # delta" by hand is asking them to run this algorithm in their head, on prose, and
    # a hand-merge is where a consumer silently drops half an upstream clause.
    #
    # A real conflict leaves standard <<<<<<< markers and exits 1 — the ONE spot that
    # genuinely needs a human. Everything else lands clean.
    # PER ANCHOR, not per file. A multi-anchor override used to be refused outright and
    # sent back for a hand-merge, which is the one procedure this mode exists to remove
    # and step 7 warns about. It is also more work than the drift justifies: an override
    # shadowing four sections typically has ONE that moved.
    #
    # The removed message is deliberately NOT quoted here. A consumer's ledger receipt is
    # a substring test against this file, so a comment that repeats a string the fix
    # deleted keeps the receipt matching forever and the entry never closes. Measured:
    # PC-S298-READOPT-MERGE-REFUSES-MULTI-ANCHOR-OVERRIDES reported STILL-LIVE against
    # 0.142.0 on this comment alone. Describe a deleted string; do not reproduce it.
    # Each anchor is merged in its own span; anchors whose core section is byte-identical
    # between base and theirs are left ALONE, so the diff stays scoped to what drifted.
    if [ "$RESOLVE" != yes ]; then
      echo "REFUSED  $(basename "$OVR"): a shadowed anchor resolves to no heading; cannot merge what cannot be located." >&2
      anchors_resolve >/dev/null
      exit 1
    fi

    ids="$(printf '%s\n' "$SHADOWS" | tr ',' '\n' | sed -n 's/.*#//p' | sed 's/^ *//; s/ *$//' | grep -v '^$')"

    fmf="$(mktemp)"; body="$(mktemp)"
    awk 'NR==1 && /^---$/ {infm=1; print; next}
         infm && /^---$/ {print; infm=0; done=1; next}
         infm {print}' "$OVR" > "$fmf"
    awk 'BEGIN{fm=0; started=0}
         NR==1 && /^---$/ {fm=1; next}
         fm && /^---$/ {fm=0; started=1; next}
         fm {next}
         started {print}' "$OVR" > "$body"

    # Locate each anchor's span IN THE BODY, then walk the body in line order.
    plan="$(mktemp)"; : > "$plan"
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      sp="$(span_of "$id" < "$body")"
      [ -n "$sp" ] && printf '%s %s\n' "$sp" "$id" >> "$plan"
    done <<EOF
$ids
EOF

    # A body that restates no shadowed heading is the single-anchor shape: the whole body
    # IS the section. Treat it as one span so that case merges exactly as it always has.
    if [ ! -s "$plan" ]; then
      if [ "$(printf '%s\n' "$ids" | grep -c .)" -ne 1 ]; then
        echo "REFUSED  $(basename "$OVR"): shadows $(printf '%s\n' "$ids" | grep -c .) anchors and the body restates none of their headings, so no span can be located." >&2
        echo "  anchors: $(printf '%s' "$ids" | tr '\n' ' ')" >&2
        rm -f "$fmf" "$body" "$plan"
        exit 2
      fi
      printf '1 %s %s\n' "$(grep -c '' "$body")" "$ids" >> "$plan"
      WHOLE_BODY=1
    else
      WHOLE_BODY=0
    fi
    sort -n -k1,1 "$plan" -o "$plan"

    out="$(mktemp)"; : > "$out"
    prev=0; n_merged=0; n_conflict=0; n_unchanged=0
    while read -r s e id; do
      [ -n "$id" ] || continue
      # Everything between the previous span and this one is consumer prose no anchor
      # covers -- a preamble, a section core never had. It is copied byte-for-byte.
      [ "$s" -gt $((prev + 1)) ] && sed -n "$((prev + 1)),$((s - 1))p" "$body" >> "$out"
      prev="$e"

      ours="$(mktemp)"; base="$(mktemp)"; theirs="$(mktemp)"
      sed -n "${s},${e}p" "$body" > "$ours"
      git -C "$DIST" show "${BASE_SHA}:${CORE}" | section_of "$id" > "$base"
      git -C "$DIST" show "${THEIRS}:${CORE}"   | section_of "$id" > "$theirs"

      if cmp -s "$base" "$theirs"; then
        cat "$ours" >> "$out"
        n_unchanged=$((n_unchanged + 1))
        echo "  UNCHANGED  #${id} — core is byte-identical base..theirs; body left untouched."
        rm -f "$ours" "$base" "$theirs"
        continue
      fi

      # Align the three inputs before merging. On the whole-body path the extractor emits a
      # leading blank line (the one after the frontmatter fence) while `section_of` starts
      # flush at the heading. That one-line offset makes `git merge-file` mis-align ours
      # against base and report a CONFLICT on a paragraph BYTE-IDENTICAL to base -- a clean
      # re-adoption handed back as prose to merge by hand, the exact failure this mode
      # removes. Strip the blank runs off all three, then RESTORE ours' own counts after:
      # the alignment is a merge concern, not a licence to reformat the operator's file.
      lead="$(awk '{ if (NF) exit; c++ } END { print c+0 }' "$ours")"
      tail_n="$(awk '{a[NR]=$0} END {n=NR; c=0; while (n>0 && a[n]=="") {c++; n--}; print c+0}' "$ours")"
      for f in "$ours" "$base" "$theirs"; do
        awk 'NF {p=1} p' "$f" | awk '{a[NR]=$0} END {n=NR; while (n>0 && a[n]=="") n--; for(i=1;i<=n;i++) print a[i]}' > "$f.n"
        mv "$f.n" "$f"
      done

      merged="$(mktemp)"; cp "$ours" "$merged"
      if git merge-file -L "override (yours)" -L "core@${BASE_SHA}" -L "core@${THEIRS_SHA}" \
           "$merged" "$base" "$theirs"; then
        n_merged=$((n_merged + 1))
        echo "  MERGED     #${id} — upstream's change applied, the consumer delta preserved."
      else
        n_conflict=$((n_conflict + 1))
        echo "  CONFLICT   #${id} — upstream and the consumer changed the same lines." >&2
      fi
      i=0; while [ "$i" -lt "$lead" ]; do echo >> "$out"; i=$((i + 1)); done
      cat "$merged" >> "$out"
      i=0; while [ "$i" -lt "$tail_n" ]; do echo >> "$out"; i=$((i + 1)); done
      rm -f "$ours" "$base" "$theirs" "$merged"
    done < "$plan"

    # Trailing body after the last span.
    total="$(grep -c '' "$body")"
    [ "$total" -gt "$prev" ] && sed -n "$((prev + 1)),\$p" "$body" >> "$out"

    # No separator line is invented here. Overrides do not agree on whether a blank follows
    # the `---` fence -- the reference consumer's has none -- and emitting one unconditionally
    # is a whitespace edit to a file whose whole promise is that sections core did not touch
    # come out byte-for-byte. The body extractor already starts at the byte after the fence,
    # so concatenating reproduces whatever the file had.
    { cat "$fmf"; cat "$out"; } > "$OVR"
    rm -f "$fmf" "$body" "$plan" "$out"

    echo "$(basename "$OVR"): ${n_merged} merged, ${n_unchanged} unchanged, ${n_conflict} conflicted."
    if [ "$n_conflict" -gt 0 ]; then
      echo "  Conflict markers are in the body. Resolve them, then: --stamp readopt" >&2
      echo "  (--stamp readopt is refused while superseded core text remains, so an" >&2
      echo "   unresolved conflict cannot be stamped away.)" >&2
      exit 1
    fi
    echo "  Review the body, then: --stamp readopt"
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
        if grep -qE '^(<{7}|={7}|>{7})' "$OVR"; then
          echo "REFUSED  $(basename "$OVR"): unresolved merge conflict markers in the body." >&2
          grep -nE '^(<{7}|={7}|>{7})' "$OVR" | sed 's/^/    /' >&2
          echo "  Stamping now would ship <<<<<<< into the rulebook the lead reads." >&2
          exit 1
        fi
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
      # Append the note at the END of the `reason:` block, as a continuation line.
      #
      # NEVER append to the `reason:` LINE. A reason is routinely a multi-line YAML
      # block (six of the reference consumer's overrides have one; the longest runs 99
      # lines), so appending to line 1 splices the note INTO THE MIDDLE OF A SENTENCE
      # and mangles the text. That shipped, and it corrupted a live override: the reason
      # read `... "runs on RE-AFFIRMED against 6c5e55e: ... still stands. every pull
      # request via ...`. The reason is what the NEXT pull reads to decide "does upstream
      # supersede this?" — corrupting it is corrupting the record the whole re-adoption
      # workflow turns on.
      awk -v s="$THEIRS_SHA" -v n="RE-AFFIRMED against ${THEIRS_SHA}: ${NOTE}" '
        BEGIN{ fm=0; inreason=0; done_sha=0 }
        NR==1 && /^---$/ { fm=1; print; next }
        fm && /^---$/ {
          if (inreason) { print "  " n; inreason=0 }
          fm=0; print; next
        }
        fm && /^base_sha:/ && !done_sha {
          if (inreason) { print "  " n; inreason=0 }
          print "base_sha: " s; done_sha=1; next
        }
        fm && /^reason:/ { inreason=1; print; next }
        fm && inreason && /^[A-Za-z_][A-Za-z0-9_]*:/ {
          print "  " n; inreason=0; print; next
        }
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
$(fm_block "$OVR" reason | fold -s -w 78 | sed 's/^/  /' | head -20)

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
