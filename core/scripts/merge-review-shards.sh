#!/usr/bin/env bash
# merge-review-shards.sh -- join a sharded gate-1 code review into the ONE review file Check 1
# reads.
#
# USAGE
#   merge-review-shards.sh <shard-dir> --gate code-review --out <review-file>
#
#   <shard-dir> is `docs/reviews/s<N>/shards/<idx>-code-review-<sha12>/`, written in the frozen
#   dev worktree: `.manifest` (by `partition-review-diff.sh --map ... --shard-dir`), one
#   `<ordinal>.md` per part, and `cross.md` once. <sha12> is the first 12 characters of the
#   manifest's frozen sha. <review-file> is the pass-specific review path the lead names
#   (`<idx>-code-review.md`, `<idx>-code-review-p2.md`, ...).
#   `--gate qa` is REFUSED: gate 2 is dispatched serially (`shard: 1/1 <idx>`) and has no merge.
#
# WHY IT EXISTS. A sharded review is N part reviewers plus one cross reviewer; Check 1 in
#   gate-validation.md keeps reading exactly one review file. This is the deterministic JOIN
#   that writes it. Shard verdicts are ADVISORY inputs; the merged verdict is RECOMPUTED as the
#   worst of them: BLOCKED > NEEDS_REWORK > APPROVED. Never a count, never the cross shard alone,
#   never the last one read.
#
# THE PART SET IS RE-DERIVED, NEVER READ OFF THE DIRECTORY. The manifest's worktree, base, sha,
#   min-files and max-parts are handed back to partition-review-diff.sh --map (sibling of this
#   file); its map must byte-match the manifest's `part` lines. A listing of the shard directory
#   is the set of shards that ARRIVED, not the set that was owed.
#
# SHARD GRAMMAR (the role file's "As a shard" clause cites this; it does not restate it).
#   Outside ``` / ~~~ fences, at column 0, each shard carries EXACTLY ONE of each:
#       reviewed-sha: <full frozen sha>        must equal the manifest's sha
#       shard-verdict: APPROVED | NEEDS_REWORK | BLOCKED
#   A shard carries NO line Check 1's grep matches -- no `## Verdict`, no `Verdict:`. The merge
#   does not police that per shard; it counts Check 1's matches over the ASSEMBLED file and
#   refuses unless there is exactly one, which is the property that matters.
#   A FINDING is a `#### ` heading inside the shard's `## Findings` section (to the next `## `),
#   under the template's `### Critical / Important / Suggestions` containers. Each finding
#   carries EXACTLY ONE line
#       parts: <ordinal>[, <ordinal>...]
#   before the next heading. A part shard cites ONLY its own ordinal; the cross shard cites two
#   or more DISTINCT ordinals. Ordinals compare numerically (`1` and `01` are one ordinal).
#
# CHECK 1'S PATTERN IS DERIVED, NEVER RETYPED. It is lifted from gate-validation.md's own
#   `grep -inE '<pattern>' <review-file>` directive the way core/fixtures/gate-verdict-grep-shape
#   lifts it, and the lift must find exactly ONE directive. The verdict set is lifted from
#   code-reviewer.md's `## Verdict` template line by the expression render-vocabulary-index.sh
#   uses, and must be exactly the three values the ranking above orders -- a fourth value
#   refuses rather than being ranked by accident. Both files are located under the project
#   root (AI_DLC_PROJECT_ROOT, else a walk up from this file, else CLAUDE_PROJECT_DIR, else a
#   walk up from the cwd), consumer layout first.
#
# THE OUTPUT. `# Code Review: <idx> (merged ...)`, a summary naming the range and shard count, the
#   `## Verdict` heading with the worst-of value on the next line (the template's own shape), a
#   table of shard verdicts, the part map, then every shard body in ordinal order, cross last.
#   CONSERVATION: every finding heading of every shard appears in the output, counted.
#   The assembled file must match Check 1's pattern exactly once, and the value read back Check
#   1's way (text after `:`, else the next non-blank line) must equal the recomputed verdict.
#
# EXIT
#   0  merged (stdout `MERGED: ...`), or <review-file> already exists byte-identical (`UNCHANGED:`)
#   2  REFUSED (stdout `REFUSED: <reason>`) -- nothing written at <review-file>. An existing
#      <review-file> that differs is refused: a review the gate may already have read is never
#      silently overwritten.
set -u
export LC_ALL=C

refuse() { printf 'REFUSED: %s\n' "$*"; exit 2; }
USAGE="usage: merge-review-shards.sh <shard-dir> --gate code-review --out <review-file>"

SDIR=""; GATE=""; OUT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;;
    --gate) [ "$#" -ge 2 ] || refuse "$USAGE"; GATE="$2"; shift 2 ;;
    --out) [ "$#" -ge 2 ] || refuse "$USAGE"; OUT="$2"; shift 2 ;;
    --*) refuse "unknown flag $1; $USAGE" ;;
    *) [ -z "$SDIR" ] || refuse "unexpected argument $1; $USAGE"; SDIR="$1"; shift ;;
  esac
done
[ -n "$SDIR" ] && [ -n "$GATE" ] && [ -n "$OUT" ] || refuse "$USAGE"
case "$GATE" in
  code-review) ;;
  qa) refuse "--gate qa: gate 2 is dispatched serially as 'shard: 1/1 <idx>' and has no shard merge" ;;
  *) refuse "--gate '$GATE' is not code-review" ;;
esac
SDIR="${SDIR%/}"
[ -d "$SDIR" ] || refuse "shard directory $SDIR does not exist"
SDIR="$(cd "$SDIR" && pwd -P)" || refuse "shard directory is not enterable"
case "$OUT" in */) refuse "--out $OUT names a directory" ;; esac
OUT_DIR="$(dirname "$OUT")"
[ -d "$OUT_DIR" ] || refuse "the directory of --out ($OUT_DIR) does not exist"
OUT="$(cd "$OUT_DIR" && pwd -P)/$(basename "$OUT")" || refuse "the directory of --out is not enterable"
case "$OUT" in "$SDIR"/*) refuse "--out $OUT is inside the shard directory" ;; esac

T="$(mktemp -d "${TMPDIR:-/tmp}/merge-review-shards.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$T"' EXIT
TAB="$(printf '\t')"

# ---- the project root and the two files the merge derives from --------------------------
# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "REFUSED: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or"
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root."
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
SELF_DIR="$AI_DLC_SELF_DIR"; ROOT="$AI_DLC_ROOT"
GATE_MD=""
for c in "$ROOT/.claude/skills/ai-dlc/steps/gate-validation.md" "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"; do
  [ -r "$c" ] && { GATE_MD="$c"; break; }
done
[ -n "$GATE_MD" ] || refuse "gate-validation.md is not readable in either layout under $ROOT"
ROLE_MD=""
for c in "$ROOT/.claude/team-roles/code-reviewer.md" "$ROOT/core/team-roles/code-reviewer.md"; do
  [ -r "$c" ] && { ROLE_MD="$c"; break; }
done
[ -n "$ROLE_MD" ] || refuse "code-reviewer.md is not readable in either layout under $ROOT"

PATS="$(sed -n "s/.*grep -inE '\(.*\)' <review-file>.*/\1/p" "$GATE_MD")"
n_pat="$(printf '%s\n' "$PATS" | grep -c .)" || n_pat=0
[ "$n_pat" = "1" ] || refuse "found $n_pat \`grep -inE '<pattern>' <review-file>\` directives in $GATE_MD (want exactly 1); Check 1's pattern is derived, never retyped"
PAT="$PATS"

# Byte-identical to vocab_extract_review_verdicts in scripts/render-vocabulary-index.sh.
VSET="$(awk '/^## Verdict$/ { on = 1; next }
       on && /^[A-Z_]+( \| [A-Z_]+)+$/ { n = split($0, m, /[[:blank:]]*\|[[:blank:]]*/)
                                         for (i = 1; i <= n; i++) print m[i]; exit }' "$ROLE_MD" \
    | LC_ALL=C sort -u | tr '\n' ' ')"
[ "$VSET" = "APPROVED BLOCKED NEEDS_REWORK " ] \
  || refuse "code-reviewer.md's ## Verdict template declares '${VSET% }', not exactly APPROVED NEEDS_REWORK BLOCKED; the worst-of ranking orders only those three"
rank() { case "$1" in APPROVED) echo 1 ;; NEEDS_REWORK) echo 2 ;; BLOCKED) echo 3 ;; *) echo 0 ;; esac; }

# ---- the manifest, and the re-derived part map ------------------------------------------
MF="$SDIR/.manifest"
[ -f "$MF" ] || refuse "no manifest at $MF (partition-review-diff.sh --map ... --shard-dir writes it)"
for k in worktree base sha min-files max-parts; do
  n="$(awk -F'\t' -v k="$k" '$1 == k { n++ } END { print n + 0 }' "$MF")"
  [ "$n" = "1" ] || refuse "$MF carries $n '$k' line(s); want exactly 1"
done
mf() { awk -F'\t' -v k="$1" '$1 == k { sub(/^[^\t]*\t/, ""); print; exit }' "$MF"; }
M_WT="$(mf worktree)"; M_BASE="$(mf base)"; M_SHA="$(mf sha)"; M_MIN="$(mf min-files)"; M_MAX="$(mf max-parts)"
case "$M_SHA" in *[!0-9a-f]*|"") refuse "$MF sha '$M_SHA' is not a full hex object name" ;; esac
[ "${#M_SHA}" -eq 40 ] || [ "${#M_SHA}" -eq 64 ] || refuse "$MF sha '$M_SHA' is not a FULL object name (40 or 64)"
awk -F'\t' '$1 == "part" { sub(/^part\t/, ""); print }' "$MF" > "$T/mfmap" || refuse "cannot stage the manifest map"
grep -q . "$T/mfmap" || refuse "$MF lists no part"
SB="$(basename "$SDIR")"
case "$SB" in
  *-code-review-"$(printf '%s' "$M_SHA" | cut -c1-12)") IDX="${SB%-code-review-*}" ;;
  *) refuse "shard directory $SB is not <idx>-code-review-<sha12> for the manifest's sha $M_SHA" ;;
esac
[ -n "$IDX" ] || refuse "shard directory $SB names no story index"

PART="$SELF_DIR/partition-review-diff.sh"
[ -f "$PART" ] || refuse "cannot re-derive the part map: $PART is absent"
bash "$PART" --map "$M_WT" "$M_BASE" "$M_SHA" --min-files "$M_MIN" --max-parts "$M_MAX" > "$T/map" 2> "$T/map.err"; prc=$?
[ "$prc" -eq 0 ] || refuse "partition-review-diff.sh --map re-run exited $prc: $(head -1 "$T/map") $(head -1 "$T/map.err")"
cmp -s "$T/map" "$T/mfmap" || refuse "the part map re-derived from $MF's inputs differs from the map it records; the shards were briefed on another partition"
K="$(grep -c . "$T/map")" || K=0
[ "$K" -ge 2 ] || refuse "the part map has $K part(s); a merge needs two or more"
W=${#K}
ORDINALS="$(cut -f1 "$T/map" | tr '\n' ' ')"; ORDINALS="${ORDINALS% }"
norm_ord() { # "003" -> 03 at width W; empty unless digits within 1..K
  case "$1" in ""|*[!0-9]*) return 0 ;; esac
  local n=$((10#$1))
  [ "$n" -ge 1 ] && [ "$n" -le "$K" ] || return 0
  printf '%0*d' "$W" "$n"
}

# ---- the shard set ----------------------------------------------------------------------
: > "$T/shards" || refuse "cannot stage the shard set"
for f in "$SDIR"/*; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ -f "$f" ] || refuse "$f is not a regular file; the shard directory holds only <ordinal>.md and cross.md"
  case "$b" in
    cross.md) key="cross" ;;
    *.md)
      case "${b%.md}" in ""|*[!0-9]*) refuse "$f is not a shard name (<ordinal>.md or cross.md)" ;; esac
      key="$(norm_ord "${b%.md}")"
      [ -n "$key" ] || refuse "$f names ordinal ${b%.md}, outside 1..$K" ;;
    *) refuse "$f is not a shard name (<ordinal>.md or cross.md)" ;;
  esac
  printf '%s\t%s\n' "$key" "$f" >> "$T/shards" || refuse "cannot stage the shard set"
done
dup="$(cut -f1 "$T/shards" | sort | uniq -d | head -1)"
[ -z "$dup" ] || refuse "shard $dup was delivered more than once in $SDIR"
for idx in $ORDINALS cross; do
  [ -n "$(awk -F'\t' -v k="$idx" '$1 == k { print; exit }' "$T/shards")" ] \
    || refuse "shard $idx is missing from $SDIR (expected: $ORDINALS and cross)"
done

# ---- per-shard parse --------------------------------------------------------------------
# Emits: R <n> <first value>   V <n> <first value>   X <line> <n-parts-lines> <parts>   C <findings>
parse_shard() {
  awk '
    function flush() { if (fl > 0) printf "X %d %d %s\n", fl, fn, (fst == "" ? "-" : fst); fl = 0 }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^reviewed-sha:/ { nr++; if (nr == 1) { v = $0; sub(/^reviewed-sha:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); rv = v } }
    /^shard-verdict:/ { nv++; if (nv == 1) { v = $0; sub(/^shard-verdict:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); vv = v } }
    /^## / { flush(); infind = ($0 ~ /^## Findings[ \t]*$/); next }
    /^### / { flush(); next }
    infind && /^#### / { flush(); fl = NR; fn = 0; fst = ""; nfind++; next }
    infind && fl > 0 && /^parts:/ { fn++; v = $0; sub(/^parts:[ \t]*/, "", v); gsub(/[ \t]+/, "", v); fst = v; next }
    END { flush(); printf "R %d %s\n", nr + 0, (rv == "" ? "-" : rv); printf "V %d %s\n", nv + 0, (vv == "" ? "-" : vv); printf "C %d\n", nfind + 0 }
  ' "$1"
}
RE_CITED='^[0-9]+(,[0-9]+)*$'
WORST=""; WORST_R=0; NFIND=0
: > "$T/body" || refuse "cannot stage the merged body"
: > "$T/vtable" || refuse "cannot stage the verdict table"
for key in $ORDINALS cross; do
  sf="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/shards")"
  P="$T/parse.$key"
  parse_shard "$sf" > "$P" || refuse "parsing $sf did not run"
  set -- $(awk '$1 == "R" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] || refuse "$sf carries ${1:-0} 'reviewed-sha:' line(s) outside a fence; a shard carries exactly one"
  [ "${2:-}" = "$M_SHA" ] || refuse "$sf reviewed ${2:-<none>}, not the frozen sha $M_SHA; the shard reviewed another tree"
  set -- $(awk '$1 == "V" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] || refuse "$sf carries ${1:-0} 'shard-verdict:' line(s) outside a fence; a shard carries exactly one"
  v="${2:-}"; r="$(rank "$v")"
  [ "$r" -gt 0 ] || refuse "$sf shard-verdict '${v:-<none>}' is not one of APPROVED NEEDS_REWORK BLOCKED"
  if [ "$r" -gt "$WORST_R" ]; then WORST_R="$r"; WORST="$v"; fi
  printf '| %s | %s |\n' "$key" "$v" >> "$T/vtable" || refuse "cannot stage the verdict table"
  nf="$(awk '$1 == "C" { print $2 }' "$P")"; NFIND=$((NFIND + ${nf:-0}))

  while read -r tag line nlines cited; do
    [ "$tag" = "X" ] || continue
    [ "$nlines" = "1" ] || refuse "$sf:$line finding carries $nlines 'parts:' lines; each finding carries exactly one"
    [[ $cited =~ $RE_CITED ]] || refuse "$sf:$line parts: '$cited' is not <ordinal>[, <ordinal>...]"
    distinct=""
    for c in $(printf '%s' "$cited" | tr ',' ' '); do
      o="$(norm_ord "$c")"
      [ -n "$o" ] || refuse "$sf:$line cites part $c, outside 1..$K"
      case " $distinct " in *" $o "*) ;; *) distinct="$distinct $o" ;; esac
    done
    set -- $distinct
    if [ "$key" = "cross" ]; then
      [ $# -ge 2 ] || refuse "$sf:$line (cross shard) cites only$distinct; a cross finding cites two or more parts, a one-part finding belongs to that part's shard"
    else
      [ $# -eq 1 ] && [ "$1" = "$key" ] \
        || refuse "$sf:$line (shard $key) cites$distinct; a part shard reports only findings citing its own part alone"
    fi
  done < "$P"

  if [ "$key" = "cross" ]; then printf '\n## Shard: cross\n\n' >> "$T/body" || refuse "cannot stage the merged body"
  else printf '\n## Shard: part %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  cat "$sf" >> "$T/body" || refuse "cannot stage the body of $sf"
done

{
  printf '# Code Review: %s (merged from %s shards)\n\n' "$IDX" "$((K + 1))"
  printf '## Summary\n\n'
  printf 'Merged by merge-review-shards.sh from %s part shards and one cross shard, all reviewing\n' "$K"
  printf '`%s..%s`. The verdict below is RECOMPUTED as the worst shard verdict; the\n' "$M_BASE" "$M_SHA"
  printf 'shard verdicts in the table are advisory inputs to it.\n\n'
  printf '## Verdict\n%s\n\n' "$WORST"
  printf '## Shard verdicts\n\n| shard | shard-verdict |\n|---|---|\n'
  cat "$T/vtable"
  printf '\n## Part map\n\n```text\n'
  cat "$T/map"
  printf '```\n'
  cat "$T/body"
} > "$T/out" || refuse "cannot stage the merged review"

# ---- conservation and the Check 1 read-back ---------------------------------------------
n_out="$(parse_shard "$T/out" | awk '$1 == "C" { print $2 }')"
[ "$n_out" = "$NFIND" ] || refuse "the merged review carries $n_out finding heading(s) where the shards carry $NFIND; a finding was lost or invented"
n1="$(grep -ciE -- "$PAT" "$T/out")" || n1=0
[ "$n1" = "1" ] || refuse "the merged review matches Check 1's verdict pattern $n1 time(s), want exactly 1 (a shard body carrying a verdict line such as '## Verdict' is the usual cause; shards write 'shard-verdict:')"
VAL="$(grep -inE -- "$PAT" "$T/out" | head -1)"
VLINE="${VAL%%:*}"; VTXT="${VAL#*:}"
case "$VTXT" in
  *:*) READ="${VTXT#*:}" ;;
  *) READ="$(awk -v s="$VLINE" 'NR > s && /[^ \t]/ { print; exit }' "$T/out")" ;;
esac
READ="$(printf '%s' "$READ" | sed -e 's/^[ \t*]*//' -e 's/[ \t*]*$//')"
[ "$READ" = "$WORST" ] || refuse "Check 1 would read '$READ' from the merged review, not the recomputed $WORST"

if [ -e "$OUT" ]; then
  if cmp -s "$T/out" "$OUT"; then printf 'UNCHANGED: %s verdict=%s\n' "$OUT" "$WORST"; exit 0; fi
  refuse "$OUT already exists and differs from this merge; a review file is never overwritten"
fi
cp "$T/out" "$OUT.merge-tmp.$$" && mv "$OUT.merge-tmp.$$" "$OUT" || { rm -f "$OUT.merge-tmp.$$"; refuse "writing $OUT failed"; }
printf 'MERGED: %s verdict=%s parts=%s findings=%s sha=%s\n' "$OUT" "$WORST" "$K" "$NFIND" "$M_SHA"
exit 0
