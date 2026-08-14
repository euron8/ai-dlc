#!/usr/bin/env bash
# render-path-mapping.sh -- the `## Path mapping (core/ -> consumer)` section of
# core/skills/ai-dlc-update/SKILL.md is DERIVED from map_consumer() in
# core/skills/ai-dlc-update/reconcile/preclassify.sh, and byte-compared at pre-push so it
# cannot drift.
#
# WHY THIS EXISTS. The section was a hand-written restatement of a six-arm `case`, and it
# had been wrong in FOUR independent ways at once, filed by the reference consumer as
# PC-S330-PATH-MAPPING-TABLE-OMITS-THE-GIT-HOOKS-DESTINATION after only ONE of the four cost
# it a silent no-op self-update:
#
#   - `core/git-hooks/*` was absent, so a reader resolving a destination from the section
#     writes the pre-push hook to `.claude/git-hooks/pre-push`. That path is an inert orphan
#     on a consumer: the self-update commits, its fixtures go green, the full pre-push suite
#     passes BECAUSE THE LIVE HOOK WAS NEVER TOUCHED, and the machinery update the cycle
#     exists to deliver did not land. Nothing in the cycle disagrees.
#   - `core/fixtures/*` was absent.
#   - `core/ci-templates/*` was absent.
#   - `core/scripts/<x>` claimed `scripts/<x>`, stale since v0.126.0 moved the validators to
#     `scripts/ai-dlc/`. A WRONG row is worse than a missing one: the reader does not go and
#     look, because the section answered.
#
# WHY NOTHING CAUGHT IT. I16 is the only invariant that reads path prose, and it puts
# `core/skills/ai-dlc-update/**` out of scope BY NAME -- correctly, because that subtree
# reasons about the distribution layout by design and comparing core/ to .claude/ is its
# whole job. The section sat in the one file every path invariant is told to skip. This
# renderer does not reopen that carve-out: it binds ONE generated region, and I16 still
# never reads the file.
#
# WHY RENDERED AND NOT MERELY CHECKED. A check that compares a hand-written table to
# map_consumer() catches a fifth omission AFTER someone writes it. Rendering makes the fifth
# omission unconstructible -- a new arm in the `case` appears in the section on the next
# render, and the gate fails until it does. Same posture as scripts/render-invariant-index.sh
# and scripts/render-vocabulary-index.sh, and the same posture core/scripts/sync-taught-schema.sh
# takes for its provenance examples.
#
# THE SOURCE IS SCRAPED, NEVER RESTATED. `map_consumer()` is read out of preclassify.sh with
# awk and eval'd -- the idiom reconcile/apply.sh:169 established and four other reconcile
# scripts follow, for the reason apply.sh states in its own error text: falling back to a
# private table "would apply some subtrees, skip others, and re-stamp as though everything
# landed". A second copy of the mapping in THIS file would be the exact defect the section
# already had, moved one file over.
#
# WHY THE ARM SET IS DERIVED FROM THE `case` PATTERNS AND NOT FROM A LIST HERE. The pattern
# list and the destination list are the same join, and hand-holding either half reintroduces
# the drift. The patterns are extracted from the function body; each is then RESOLVED by
# CALLING map_consumer() on a probe path built from that pattern, so the destination column
# is the function's own answer rather than a reading of it. An arm this script cannot probe
# is a FAILURE, never a skipped row.
#
# Usage:
#   render-path-mapping.sh            # print the canonical region to stdout
#   render-path-mapping.sh --write    # rewrite the region in place
#   render-path-mapping.sh --check    # exit 1 if the region is stale, missing or hand-written
#
# Exit codes:
#   0  region matches (--check), or rendered (default/--write)
#   1  region drifted/missing, or the source could not be read (fail-closed)
#   2  usage error
#
# Compatible with bash 3.2: no mapfile, no readarray, no declare -A.

set -uo pipefail

BEGIN_MARK='<!-- BEGIN GENERATED: path-mapping — source: reconcile/preclassify.sh map_consumer() -->'
END_MARK='<!-- END GENERATED: path-mapping -->'
HEADING='## Path mapping (core/ → consumer)'

# --- repo root: walk UP for a marker, never count `..` hops ------------------------------
# A validator that counts hops answers differently from the repo root, from a subdirectory,
# and from a fixture sandbox that copied it -- and the sandbox answer is the silent one.
ROOT=""
d="$(cd "$(dirname "$0")" && pwd)"
while [ "$d" != "/" ]; do
  if [ -f "$d/VERSION" ]; then ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "render-path-mapping: FAIL — no VERSION marker above $0; cannot resolve the repo root." >&2; exit 1; }

SKILL="$ROOT/core/skills/ai-dlc-update/SKILL.md"
PRECLASS="$ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"

[ -f "$PRECLASS" ] || { echo "render-path-mapping: FAIL — source missing: $PRECLASS" >&2; exit 1; }
[ -f "$SKILL" ]    || { echo "render-path-mapping: FAIL — target missing: $SKILL" >&2; exit 1; }

# --- load the ONE definition -------------------------------------------------------------
# Scraped and eval'd, exactly as reconcile/apply.sh:169 does. A private table here would be
# the second writer this whole file exists to delete.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$PRECLASS" 2>/dev/null)"
command -v map_consumer >/dev/null 2>&1 || {
  echo "render-path-mapping: FAIL — could not load map_consumer() from $PRECLASS. Refusing to guess consumer paths: a private fallback table is the exact bug this renderer removes." >&2
  exit 1
}

# --- the arms, derived from the function's own `case` patterns ---------------------------
# Every `<pattern>)` at the head of a case arm, in source order. Source order is the
# semantic order -- a `case` takes the FIRST match, so the catch-alls must render last, and
# re-sorting this list would render a table that lies about precedence.
PATTERNS="$(awk '
  /^map_consumer\(\) \{/ { inf=1; next }
  inf && /^\}/           { exit }
  inf && /^[[:space:]]*[^[:space:]#][^)]*\)[[:space:]]*echo/ {
    line=$0
    sub(/^[[:space:]]*/, "", line)
    sub(/\).*$/, "", line)
    print line
  }
' "$PRECLASS")"

n_arms="$(printf '%s\n' "$PATTERNS" | grep -c . || true)"
# A ZERO IS NOT A FINDING. An extraction that yields nothing renders an empty table and
# byte-compares clean against a target someone emptied -- indistinguishable from a correct
# run. The floor is the arm count the function has carried since core/git-hooks/ was added.
if [ "${n_arms:-0}" -lt 5 ]; then
  echo "render-path-mapping: FAIL — extracted only ${n_arms:-0} case arm(s) from map_consumer(). The extractor lost the function's grammar; rendering would emit a table that is clean and wrong." >&2
  exit 1
fi

# Turn a case pattern into a probe path this script can actually feed to map_consumer(),
# and into the prose form the table shows. `core/scripts/*` probes as `core/scripts/X`.
probe_for() {
  case "$1" in
    \*) printf 'not-core/X\n' ;;
    *\*) printf '%sX\n' "${1%\*}" ;;
    *)  printf '%s\n' "$1" ;;
  esac
}
display_for() {
  case "$1" in
    \*)  printf '`<anything else>`\n' ;;
    *\*) printf '`%s<x>`\n' "${1%\*}" ;;
    *)   printf '`%s`\n' "$1" ;;
  esac
}

render() {
  printf '%s\n' "$HEADING"
  printf '\n'
  printf '%s\n' "$BEGIN_MARK"
  printf 'DERIVED from `map_consumer()`. Do not hand-edit: run `render-path-mapping.sh --write`.\n'
  printf '\n'
  printf '| core path | consumer destination |\n'
  printf '|-----------|----------------------|\n'
  printf '%s\n' "$PATTERNS" | while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    probe="$(probe_for "$pat")"
    dest="$(map_consumer "$probe")"
    # RESOLVED, not read: `dest` is what the function answered for `probe`. Strip the probe's
    # own leaf back to the `<x>` placeholder so the row reads as a rule, not as one example.
    case "$pat" in
      \*)  disp_dest='`<unchanged>`' ;;
      *\*) disp_dest="\`${dest%X}<x>\`" ;;
      *)   disp_dest="\`${dest}\`" ;;
    esac
    printf '| %s | %s |\n' "$(display_for "$pat")" "$disp_dest"
  done
  printf '\n'
  printf 'First match wins, so the rows are in the order `map_consumer()` tests them: the\n'
  printf 'specific subtrees are decided before the `core/` catch-all reaches them.\n'
  printf '%s\n' "$END_MARK"
}

extract_region() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v h="$HEADING" '
    $0 == h { started=1 }
    started { print }
    $0 == e { exit }
  ' "$SKILL"
}

MODE="${1:-render}"
case "$MODE" in
  render|"")
    render
    ;;
  --write)
    tmp="$(mktemp)"
    # The region runs from the HEADING to the END marker. Everything before and after is
    # untouched -- this rewrites a region, never the file.
    awk -v h="$HEADING" -v e="$END_MARK" -v b="$BEGIN_MARK" '
      $0 == h && !done { skipping=1; print "@@RENDER@@"; done=1; next }
      # The region ENDS at the marker, and the blank line after it is eaten with the region
      # so the renderer can re-emit exactly one. Without this the write is not idempotent:
      # a second --write leaves the old separator in place and adds a second one.
      skipping && $0 == e { skipping=0; eat_blank=1; next }
      skipping && /^## / { skipping=0 }   # legacy hand-written section: ends at the next heading
      skipping { next }
      eat_blank { eat_blank=0; if ($0 == "") next }
      { print }
    ' "$SKILL" > "$tmp"
    grep -qF '@@RENDER@@' "$tmp" || { rm -f "$tmp"; echo "render-path-mapping: FAIL — heading not found in $SKILL: $HEADING" >&2; exit 1; }
    out="$(mktemp)"
    while IFS= read -r line; do
      # The blank line that separated the old section from the next heading was consumed
      # with the section, so the region re-emits one. Without it the END marker abuts the
      # next `## `, which every other section in this file does not do.
      if [ "$line" = '@@RENDER@@' ]; then render; printf '\n'; else printf '%s\n' "$line"; fi
    done < "$tmp" > "$out"
    mv "$out" "$SKILL"
    rm -f "$tmp"
    echo "render-path-mapping: wrote the path-mapping region into ${SKILL#$ROOT/} (${n_arms} arm(s))."
    ;;
  --check)
    have="$(extract_region)"
    want="$(render)"
    if [ -z "$have" ]; then
      echo "render-path-mapping: FAIL — no generated path-mapping region in ${SKILL#$ROOT/}. Run render-path-mapping.sh --write." >&2
      exit 1
    fi
    if [ "$have" != "$want" ]; then
      echo "render-path-mapping: FAIL — the path-mapping region in ${SKILL#$ROOT/} does not match what map_consumer() renders today." >&2
      diff <(printf '%s\n' "$have") <(printf '%s\n' "$want") >&2 || true
      echo "render-path-mapping: run scripts/render-path-mapping.sh --write and commit the result." >&2
      exit 1
    fi
    echo "render-path-mapping: OK — path-mapping region matches map_consumer() (${n_arms} arm(s))."
    ;;
  *)
    echo "usage: render-path-mapping.sh [--write|--check]" >&2
    exit 2
    ;;
esac
exit 0
