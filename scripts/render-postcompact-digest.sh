#!/usr/bin/env bash
# render-postcompact-digest.sh -- the generated region of
# core/skills/ai-dlc/postcompact-digest.md is DERIVED from the part of
# core/skills/ai-dlc/SKILL.md that a compaction throws away, and byte-compared at pre-push so
# it cannot drift from the rulebook it stands in for.
#
# WHY THIS EXISTS. Claude Code re-attaches only the first ~5,000 tokens of an invoked skill
# after a compaction. Measured over the reference consumer's 379 transcripts -- 69 carrying a
# `compact_boundary`, 261 post-boundary records carrying a real re-attach -- the cut sits at
# 20,121 bytes in every one of them, identical at p10, p25, p50, p75 and p90. SKILL.md is
# ~102 KB, so the harness keeps under a fifth of it and marks nothing. 18 of the 31 numbered
# rules, the handoff triggers and the snapshot schema are simply absent, INCLUDING the rules
# that mandate re-reading.
#
# The standing answer was `Read .claude/skills/ai-dlc/SKILL.md` IN FULL, and the measurement
# that motivates this renderer is that IT DOES NOT HAPPEN. Across the reference consumer's
# sprint 305 -- 5 transcripts, 10.4 MB, 27 compactions -- `Read` results were 51.5% of all
# conversation content and SKILL.md alone was 15.3%, while the mandated Read still lands only
# a fraction of the time. A 102 KB re-read is what brings the NEXT compaction closer, so the
# instruction that recovers the rulebook is also the instruction that destroys it again.
#
# So the mandate now names this digest instead. It is not a summary and no model wrote it: it
# is a SELECTION of SKILL.md's own bytes, rendered mechanically, carrying every heading past
# the cut with its normative opening. The lead therefore learns that every rule EXISTS and
# what it governs -- which is the failure the full-read mandate was for -- and is told, in the
# preamble the renderer does not own, to Read SKILL.md for a rule it is about to lean on.
#
# WHY A SELECTION AND NOT A SUMMARY. A summary is a second implementation of the rulebook whose
# bugs nobody finds, and it drifts the moment a rule changes. A selection cannot say anything
# SKILL.md does not say, and `--check` fails the push the moment SKILL.md moves.
#
# THE SELECTOR, AND THE FAITHFULNESS ARM THAT CONSTRAINS IT. Each heading takes its first
# paragraph. A paragraph that ends on a COLON announces content it does not carry, so the
# selector keeps taking the block it announced until the capture no longer dangles. That arm
# is not decorative: measured on this tree, first-paragraph-only left THREE entries dangling,
# and one of them was Rule 23 -- "Three controls keep the resident set lean:" with the three
# controls dropped. Rule 23 is resident-context discipline, the one rule whose absence causes
# the compaction that removed it. A digest that names it and drops its content is worse than
# one that omits it, because the lead reads the name and believes it holds the rule.
#
# `--check` therefore asserts the dangle count is ZERO over the rendered region, and that is a
# check that can fire: it reports 3 against the naive selector, in the same invocation.
#
# WHERE THE REGION STARTS. At the `## ` section that CONTAINS the cut, not at the cut byte. A
# section split by the cut would otherwise render headless -- its opening survives in context
# and its tail arrives with no heading over it. Starting at the section boundary costs a few
# hundred bytes of overlap and makes every entry self-describing.
#
# Usage:
#   render-postcompact-digest.sh            # print the canonical region to stdout
#   render-postcompact-digest.sh --write    # rewrite the region in place
#   render-postcompact-digest.sh --check    # exit 1 if the region is stale, missing or dangling
#
# Exit codes:
#   0  region matches (--check), or rendered (default/--write)
#   1  region drifted/missing, the selector lost the file's grammar, or the source is unreadable
#   2  usage error
#
# ENV OVERRIDES
#   AI_DLC_REATTACH_CUT_BYTES   measured re-attach cut in bytes   (default 20121)
#
# Compatible with bash 3.2: no mapfile, no readarray, no declare -A.

set -uo pipefail

BEGIN_MARK='<!-- BEGIN GENERATED: postcompact-digest — source: SKILL.md past the re-attach cut -->'
END_MARK='<!-- END GENERATED: postcompact-digest -->'
HEADING='## The rulebook past the re-attach cut'

CUT_BYTES="${AI_DLC_REATTACH_CUT_BYTES:-20121}"

# The floor a real render must clear. A selector that loses SKILL.md's grammar emits an empty
# region and byte-compares clean against a target someone emptied -- indistinguishable from a
# correct run. 18 numbered rules sit past the cut today; the floor is stated below that so an
# ordinary edit does not trip it, and far enough above zero that a broken extractor cannot pass.
MIN_ENTRIES=15

# --- repo root: walk UP for a marker, never count `..` hops ------------------------------
# A validator that counts hops answers differently from the repo root, from a subdirectory,
# and from a fixture sandbox that copied it -- and the sandbox answer is the silent one.
ROOT=""
d="$(cd "$(dirname "$0")" && pwd)"
while [ "$d" != "/" ]; do
  if [ -f "$d/VERSION" ]; then ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "render-postcompact-digest: FAIL — no VERSION marker above $0; cannot resolve the repo root." >&2; exit 1; }

SKILL="$ROOT/core/skills/ai-dlc/SKILL.md"
TARGET="$ROOT/core/skills/ai-dlc/postcompact-digest.md"

[ -f "$SKILL" ]  || { echo "render-postcompact-digest: FAIL — source missing: $SKILL" >&2; exit 1; }
[ -f "$TARGET" ] || { echo "render-postcompact-digest: FAIL — target missing: $TARGET" >&2; exit 1; }

# --- where the cut falls, and which section contains it ----------------------------------
# Resolved from the file's own bytes, never from a recorded line number: a line number written
# here goes stale on the next edit ABOVE it and the region then renders from the wrong place,
# which is clean and wrong.
START_LINE="$(awk -v cut="$CUT_BYTES" '
  { b += length($0) + 1 }
  /^## / { if (b <= cut) last = NR }
  b > cut && !done { done = 1 }
  END { print last + 0 }
' "$SKILL")"

if [ "${START_LINE:-0}" -lt 1 ]; then
  echo "render-postcompact-digest: FAIL — no '## ' section heading at or before the ${CUT_BYTES}-byte cut in ${SKILL#$ROOT/}. The file's grammar moved; rendering would emit a region that is clean and wrong." >&2
  exit 1
fi

# --- the selection ------------------------------------------------------------------------
# Heading, first paragraph, and -- when that paragraph dangles on a colon -- the block it
# announced. Nothing here rewrites a byte of SKILL.md's prose.
select_digest() {
  awk -v start="$START_LINE" '
    NR < start { next }
    function flush() {
      if (h == "") return
      print h
      for (i = 1; i <= nb; i++) print buf[i]
      print ""
      h = ""; nb = 0
    }
    /^#{2,4} / { flush(); h = $0; state = "para"; nb = 0; pending = 0; next }
    h == "" { next }
    {
      if (state == "done") next
      if ($0 ~ /^[[:space:]]*$/) {
        if (nb == 0) next
        if (buf[nb] ~ /:[[:space:]]*$/) { state = "list"; pending = 0; next }
        if (state == "list") { pending = 1; next }
        state = "done"; next
      }
      if (state == "list" && pending) {
        # A blank line inside an announced block is legal between list items. A blank line
        # followed by ordinary prose ends the block.
        if ($0 !~ /^([-*]|[0-9]+\.|[[:space:]]+)/) { state = "done"; next }
        pending = 0
      }
      buf[++nb] = $0
    }
    END { flush() }
  ' "$SKILL"
}

BODY="$(select_digest)"
N_ENTRIES="$(printf '%s\n' "$BODY" | grep -c '^#\{2,4\} ' || true)"

if [ "${N_ENTRIES:-0}" -lt "$MIN_ENTRIES" ]; then
  echo "render-postcompact-digest: FAIL — the selector found only ${N_ENTRIES:-0} heading(s) past the cut, under the floor of ${MIN_ENTRIES}. It lost SKILL.md's grammar; a short digest byte-compares clean and silently drops rules." >&2
  exit 1
fi

# THE FAITHFULNESS ARM. An entry whose captured text ends on a colon announces content the
# digest does not carry, and the lead reads the announcement as the rule. Measured: the naive
# first-paragraph selector leaves 3 such entries here, Rule 23 among them, so this arm has a
# demonstrated non-zero direction and is not a formality.
count_dangling() {
  printf '%s\n' "$1" | awk '
    /^#{2,4} / { if (h != "" && prev ~ /:[[:space:]]*$/) n++; h = $0; prev = ""; next }
    /^[[:space:]]*$/ { next }
    { prev = $0 }
    END { if (h != "" && prev ~ /:[[:space:]]*$/) n++; print n + 0 }
  '
}
N_DANGLING="$(count_dangling "$BODY")"
if [ "${N_DANGLING:-0}" -ne 0 ]; then
  echo "render-postcompact-digest: FAIL — ${N_DANGLING} digest entr(y/ies) end on a colon, announcing content the digest does not carry. Fix the selector, not the target: a lead reads the announcement as the rule." >&2
  exit 1
fi

render() {
  printf '%s\n' "$HEADING"
  printf '\n'
  printf '%s\n' "$BEGIN_MARK"
  printf 'DERIVED from `SKILL.md` past the %s-byte re-attach cut. Do not hand-edit: run\n' "$CUT_BYTES"
  printf '`scripts/render-postcompact-digest.sh --write`. Every line below is SKILL.md'"'"'s own\n'
  printf 'text, selected — never summarised, never rewritten.\n'
  printf '\n'
  printf '%s\n' "$BODY"
  printf '%s\n' "$END_MARK"
}

extract_region() {
  awk -v h="$HEADING" -v e="$END_MARK" '
    $0 == h { started = 1 }
    started { print }
    $0 == e { exit }
  ' "$TARGET"
}

MODE="${1:-render}"
case "$MODE" in
  render|"")
    render
    ;;
  --write)
    tmp="$(mktemp)"
    # THE REGION IS BOUNDED BY THE END MARKER ALONE, and that is the one place this renderer
    # must differ from its three siblings. Theirs carry a "stop skipping at the next `## `"
    # fallback for a legacy hand-written section; here the region is SKILL.md's own text and
    # CONTAINS `## ` headings, so that fallback ends the region at the first selected section
    # and leaves the rest of the old region behind. Measured: it made `--write` non-idempotent,
    # a second run producing a different file from the first. A missing END marker is a FAILURE
    # rather than a guess -- guessing the boundary is what corrupts the target.
    awk -v h="$HEADING" -v e="$END_MARK" '
      $0 == h && !done { skipping = 1; print "@@RENDER@@"; done = 1; next }
      # The blank line after the END marker is eaten with the region so the renderer re-emits
      # exactly one. Without this a second --write is not idempotent either.
      skipping && $0 == e { skipping = 0; seen_end = 1; eat_blank = 1; next }
      skipping { next }
      eat_blank { eat_blank = 0; if ($0 == "") next }
      { print }
      END { if (!seen_end) exit 3 }
    ' "$TARGET" > "$tmp"
    aw_rc=$?
    if [ "$aw_rc" -eq 3 ]; then
      rm -f "$tmp"
      echo "render-postcompact-digest: FAIL — no END marker in ${TARGET#$ROOT/}. Refusing to guess where the generated region stops; restore the marker pair and re-run." >&2
      exit 1
    fi
    grep -qF '@@RENDER@@' "$tmp" || { rm -f "$tmp"; echo "render-postcompact-digest: FAIL — heading not found in ${TARGET#$ROOT/}: $HEADING" >&2; exit 1; }
    out="$(mktemp)"
    while IFS= read -r line; do
      if [ "$line" = '@@RENDER@@' ]; then render; printf '\n'; else printf '%s\n' "$line"; fi
    done < "$tmp" > "$out"
    mv "$out" "$TARGET"
    rm -f "$tmp"
    echo "render-postcompact-digest: wrote the digest region into ${TARGET#$ROOT/} (${N_ENTRIES} entries, 0 dangling, from line ${START_LINE})."
    ;;
  --check)
    have="$(extract_region)"
    want="$(render)"
    if [ -z "$have" ]; then
      echo "render-postcompact-digest: FAIL — no generated digest region in ${TARGET#$ROOT/}. Run scripts/render-postcompact-digest.sh --write." >&2
      exit 1
    fi
    if [ "$have" != "$want" ]; then
      echo "render-postcompact-digest: FAIL — the digest region in ${TARGET#$ROOT/} does not match what SKILL.md renders today. The rulebook moved and the digest the lead reads after a compaction did not." >&2
      diff <(printf '%s\n' "$have") <(printf '%s\n' "$want") >&2 || true
      echo "render-postcompact-digest: run scripts/render-postcompact-digest.sh --write and commit the result." >&2
      exit 1
    fi
    echo "render-postcompact-digest: OK — digest region matches SKILL.md past the cut (${N_ENTRIES} entries, 0 dangling)."
    ;;
  *)
    echo "usage: render-postcompact-digest.sh [--write|--check]" >&2
    exit 2
    ;;
esac
exit 0
