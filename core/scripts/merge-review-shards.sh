#!/usr/bin/env bash
# merge-review-shards.sh -- join a sharded gate-1 code review, or a sharded gate-2 QA
# validation, into the ONE review file Check 1 reads.
#
# USAGE
#   merge-review-shards.sh <shard-dir> --gate code-review|qa --out <review-file>
#
#   Per gate:                 code-review                      qa
#     role file               code-reviewer.md                 qa.md
#     <shard-dir> basename    <idx>-code-review-<sha12>[-p<M>] <idx>-qa-validation-<sha12>[-p<M>]
#     <review-file> basename  <idx>-code-review[-p<M>].md      <idx>-qa-validation[-p<M>].md
#     worst-of order          BLOCKED > NEEDS_REWORK > APPROVED  NEEDS_REWORK > PASS
#     merged title            # Code Review: <idx> (merged...)   # QA Validation: <idx> (merged...)
#   Any other --gate is REFUSED.
#
#   <shard-dir> lives under `docs/reviews/s<N>/shards/`, written in the frozen dev worktree:
#   `.manifest` (by `partition-review-diff.sh --map ... --shard-dir`), one `<ordinal>.md` per
#   part, and the CROSS SHARDS (below). <sha12> is the first 12 characters of the manifest's
#   frozen sha.
#
# THE CROSS SHARDS. One per row of `partition-document.sh --cross-groups <K>` (K = the part
#   count of the re-derived map), named `cross-<g>.md`, and `cross.md` iff that table has
#   exactly one row (G=1, i.e. K=2). The table is read from that one speller, never restated
#   here. Every `cross-<g>` it prints is required; a `cross-<g>` it does not print, `cross.md`
#   beside any `cross-<g>.md`, `cross.md` when G>1 and `cross-<g>.md` when G=1 are each REFUSED.
#   THE OWNER RULE. The groups overlap, so each cross finding citing two or more parts is
#   accepted ONLY from the shard `partition-document.sh --cross-owner <K> <cited ordinals>`
#   names (`cross` when G=1) and REFUSED from any other, so the worst-of verdict and the
#   conserved finding count never depend on how the cover overlaps.
#   THE FIRST CROSS SHARD (`cross` when G=1, else `cross-1`) is the EXECUTION owner: it alone
#   runs in the frozen worktree, which nothing else may mutate -- the suite, mutation-red, every
#   handed-over replay -- and under --gate qa it alone carries the per-AC table and the deferred
#   record. Every other cross shard executes nothing and reports only the pair findings it owns.
#   SEAT-COMPLETE. A shard dispatched under the early-write brief ends, as its LAST NON-BLANK
#   line, in `seat-complete: <step> <seat> <shard>`. If ANY shard in the directory carries that
#   line, every shard must, and one that does not is REFUSED as unfinished. Keyed on the
#   marker's presence in the directory, as merge-adversarial-shards.sh keys it: a directory whose
#   shards predate the brief carries no marker anywhere and merges as before. Its limit: a set in
#   which NO shard has finished carries no marker either, so this is the belt and
#   `wait-for-deliverable.sh --complete` at the join is the braces. The marker line is dropped
#   from the merged body.
#   THE PASS MARKER. Pass 1 carries none; pass M (M a decimal integer >= 2, no leading zero)
#   appends `-p<M>` to BOTH the shard directory and the review file. The merge REFUSES unless
#   the two markers are equal and --out's basename is the gate's review-file shape for the
#   directory's <idx>: a shard directory partitioned for one pass is never merged into
#   another pass's review file. `-p1` is refused -- pass 1 has no marker.
#
# WHY IT EXISTS. A sharded review is N part reviewers plus one cross reviewer; Check 1 in
#   gate-validation.md keeps reading exactly one review file. This is the deterministic JOIN
#   that writes it. Shard verdicts are ADVISORY inputs; the merged verdict is RECOMPUTED as the
#   worst of them in the gate's order above. Never a count, never the cross shard alone,
#   never the last one read. Under --gate qa an unmet hand-over replay (HAND-OVERS below) also
#   forces NEEDS_REWORK.
#
# THE PART SET IS RE-DERIVED, NEVER READ OFF THE DIRECTORY. The manifest's worktree, base, sha,
#   min-files and max-parts are handed back to partition-review-diff.sh --map (sibling of this
#   file); its map must byte-match the manifest's `part` lines. A listing of the shard directory
#   is the set of shards that ARRIVED, not the set that was owed.
#
# SHARD GRAMMAR (the role file's "As a shard" clause cites this; it does not restate it).
#   Outside ``` / ~~~ fences, at column 0, each shard carries EXACTLY ONE of each:
#       reviewed-sha: <full frozen sha>        must equal the manifest's sha (40 or 64 hex
#                                              characters -- never a go-signal's short sha)
#       shard-verdict: APPROVED | NEEDS_REWORK | BLOCKED     (--gate code-review)
#       shard-verdict: PASS | NEEDS_REWORK                   (--gate qa)
#   A shard carries NO line Check 1's grep matches. Shapes that DO match, and so must not appear
#   in a shard outside a fence: any heading whose text is or ends in `Verdict` or `Decision`
#   (`## Verdict`, `### QA Decision`), a label `Verdict:` or `<Word> verdict: ...` (`QA verdict:
#   PASS`), and the same in bold (`**Verdict:** PASS`). A pipe-led table row does not match, so
#   QA's per-AC results are a table (`| AC | Verdict |`, one row per AC). The merge does not
#   police that per shard; it counts Check 1's matches over the ASSEMBLED file and refuses
#   unless there is exactly one, which is the property that matters.
#   --gate qa ONLY, counted outside fences, case-insensitively, on a `## ` or `### ` heading
#   whose text BEGINS with the section name, whatever follows it -- `## Acceptance Criteria:`,
#   `##  acceptance criteria`, `### Deferred ACs` and `## Deferred / operator-owned` all count.
#   A `#### ` heading never counts: that level is a FINDING, and a finding titled
#   `#### Acceptance criteria ...` is a finding, not a second per-AC section:
#       the FIRST cross shard carries EXACTLY ONE `## Acceptance Criteria` (the story's per-AC
#       table) and AT MOST ONE `## Deferred ACs` (every deferred-AC discharge predicate); a part
#       shard and every other cross shard carry NEITHER. The closing writer reads both from the
#       merged file, so a second copy, or one in another shard, is a second answer to one question.
#   A FINDING is a `#### ` heading inside the shard's `## Findings` section (to the next `## `),
#   under the template's `### Critical / Important / Suggestions` containers. Each finding
#   carries EXACTLY ONE line
#       parts: <ordinal>[, <ordinal>...]
#   before the next heading. A part shard cites ONLY its own ordinal; a cross shard cites two
#   or more DISTINCT ordinals that it OWNS (the owner rule above). Ordinals compare numerically
#   (`1` and `01` are one ordinal).
#   Every shard carries a `## Findings` section, even an empty one; a shard without one is
#   REFUSED. A `parts:` line anywhere else -- under another `## ` section, before the first
#   `#### `, indented, or behind a list bullet (`- parts: 3`) -- is REFUSED, never skipped: a
#   finding written as a bullet or under `## Critical Issues` would otherwise merge uncited.
#   HAND-OVERS, --gate qa ONLY (under --gate code-review these lines are not read). A part shard
#   whose mutation-RED replay for an AC cannot reach a GREEN baseline hands that AC to the FIRST
#   cross shard (the execution owner: the replay runs in the frozen worktree) with a finding
#   (under `### Important`, never `### Deferred...`) carrying its one `parts: <own ordinal>` line
#   and EXACTLY ONE column-0 line
#       handover: <AC-id>
#   The first cross shard runs each handed-over replay and records it inside a `#### ` finding as
#   one column-0 line per replay
#       handover-run: <ordinal> <AC-id> RED | GREEN-SURVIVED | NO-BASELINE
#   A cross finding carrying `handover-run:` lines cites exactly the ordinals those lines name,
#   one or more, and is exempt from the owner rule; every other cross finding still cites two or
#   more. <AC-id> is one token of
#   letters, digits, `.`, `_`, `-` that BEGINS with a letter or digit. Both lines count only
#   outside fences. REFUSED: a `handover:` line in any cross shard; a `handover-run:` line in a
#   part shard or in any cross shard but the first; either line outside a `#### ` finding,
#   indented, bulleted or in another case; a
#   MALFORMED hand-over line anywhere -- the label decorated (`**handover:**`, `*handover*:`),
#   quoted (`` `handover: AC7` ``, `> handover: AC7`), hyphenated (`hand-over:`) or, at column 0,
#   missing its colon (`handover AC7`, `handover - AC7`); a `handover:` line naming more than one
#   AC, or none; two `handover:` lines in one finding; the
#   same hand-over twice; and any hand-over (keyed `<ordinal> <AC-id>`) not matched by exactly
#   one `handover-run:`, or a `handover-run:` matching no hand-over.
#   THE DECLARED COUNT. Every PART shard carries, beside `reviewed-sha:` and `shard-verdict:`,
#   EXACTLY ONE column-0 line outside fences
#       handovers: <n>
#   with <n> a non-negative decimal integer (`0` when it handed nothing over) equal to the number
#   of `handover:` lines the merge PARSED in that shard. REFUSED: a part shard with no such line or
#   two, a non-integer <n>, an <n> that differs from the parsed count, and any `handovers:` line in
#   any cross shard. This is the fail-closed half: a hand-over spelled any way the parser does not
#   read is not counted, so it disagrees with its writer's declaration whatever the spelling. The
#   malformed-line refusals above stay, for the precise message on the common forms; the no-colon
#   form there takes any run of non-alphanumerics as its separator (` - `, an em or en dash, `=`,
#   `->`), ends at the AC-id's token boundary rather than the end of the line, and both it and the
#   decorated form allow a numbered-list prefix (`1. `). A hand-over is not a verdict
#   of its own, but its replay is a HARD GATE: a `handover-run:` result of GREEN-SURVIVED (the
#   mutation did not turn the test RED) or NO-BASELINE (the cross shard could not reach GREEN
#   either) forces the merged verdict to NEEDS_REWORK whatever the shard verdicts say.
#
# CHECK 1'S PATTERN IS DERIVED, NEVER RETYPED. It is lifted from gate-validation.md's own
#   `grep -inE '<pattern>' <review-file>` directive the way core/fixtures/gate-verdict-grep-shape
#   lifts it, and the lift must find exactly ONE directive. The verdict set is lifted from the
#   gate's role file's `## Verdict` template line by the expression render-vocabulary-index.sh
#   uses, and must be exactly the values the gate's ranking above orders -- code-reviewer.md's
#   three, qa.md's two -- so an added value refuses rather than being ranked by accident. Both
#   files are located under the project root (AI_DLC_PROJECT_ROOT, else a walk up from this
#   file, else CLAUDE_PROJECT_DIR, else a walk up from the cwd), consumer layout first.
#
# THE OUTPUT. The gate's merged title, a summary naming the range and shard count, the
#   `## Verdict` heading with the worst-of value on the next line (the template's own shape), a
#   table of shard verdicts, the part map, then every shard body in ordinal order, the cross
#   shards last in group order (`## Shard: cross` when G=1, `## Shard: cross-<g> (<ordinals>)`
#   otherwise).
#   CONSERVATION: every finding heading of every shard appears in the output, counted.
#   The assembled file must match Check 1's pattern exactly once, and the value read back Check
#   1's way (the value rule gate-validation.md Check 1 states) must equal the recomputed verdict.
#
# EXIT
#   0  merged (stdout `MERGED: ...`), or <review-file> already exists byte-identical (`UNCHANGED:`)
#   2  REFUSED (stdout `REFUSED: <reason>`) -- nothing written at <review-file>. An existing
#      <review-file> that differs is refused: a review the gate may already have read is never
#      silently overwritten.
set -u
export LC_ALL=C

refuse() { printf 'REFUSED: %s\n' "$*"; exit 2; }
USAGE="usage: merge-review-shards.sh <shard-dir> --gate code-review|qa --out <review-file>"

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
# The per-gate table in the header, as data. RANKED is the worst-of order, best first; WANT_VSET
# is the same set sorted the way the lift below sorts it.
case "$GATE" in
  code-review) ROLE_NAME="code-reviewer.md"; DSUF="code-review"; TITLE="Code Review"
               RANKED="APPROVED NEEDS_REWORK BLOCKED"; WANT_VSET="APPROVED BLOCKED NEEDS_REWORK "; NWORD="three" ;;
  qa)          ROLE_NAME="qa.md"; DSUF="qa-validation"; TITLE="QA Validation"
               RANKED="PASS NEEDS_REWORK"; WANT_VSET="NEEDS_REWORK PASS "; NWORD="two" ;;
  *) refuse "--gate '$GATE' is not code-review or qa" ;;
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
for c in "$ROOT/.claude/team-roles/$ROLE_NAME" "$ROOT/core/team-roles/$ROLE_NAME"; do
  [ -r "$c" ] && { ROLE_MD="$c"; break; }
done
[ -n "$ROLE_MD" ] || refuse "$ROLE_NAME is not readable in either layout under $ROOT"

PATS="$(sed -n "s/.*grep -inE '\(.*\)' <review-file>.*/\1/p" "$GATE_MD")"
n_pat="$(printf '%s\n' "$PATS" | grep -c .)" || n_pat=0
[ "$n_pat" = "1" ] || refuse "found $n_pat \`grep -inE '<pattern>' <review-file>\` directives in $GATE_MD (want exactly 1); Check 1's pattern is derived, never retyped"
PAT="$PATS"

# Byte-identical to vocab_extract_review_verdicts in scripts/render-vocabulary-index.sh.
VSET="$(awk '/^## Verdict$/ { on = 1; next }
       on && /^[A-Z_]+( \| [A-Z_]+)+$/ { n = split($0, m, /[[:blank:]]*\|[[:blank:]]*/)
                                         for (i = 1; i <= n; i++) print m[i]; exit }' "$ROLE_MD" \
    | LC_ALL=C sort -u | tr '\n' ' ')"
[ "$VSET" = "$WANT_VSET" ] \
  || refuse "$ROLE_NAME's ## Verdict template declares '${VSET% }', not exactly $RANKED; the worst-of ranking orders only those $NWORD"
rank() {
  case "$GATE:$1" in
    code-review:APPROVED) echo 1 ;;
    code-review:NEEDS_REWORK) echo 2 ;;
    code-review:BLOCKED) echo 3 ;;
    qa:PASS) echo 1 ;;
    qa:NEEDS_REWORK) echo 2 ;;
    *) echo 0 ;;
  esac
}

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
S12="$(printf '%s' "$M_SHA" | cut -c1-12)"
DPASS=""
case "$SB" in
  *-"$DSUF-$S12") IDX="${SB%-"$DSUF-$S12"}" ;;
  *-"$DSUF-$S12"-p*) IDX="${SB%-"$DSUF-$S12"-p*}"; DPASS="${SB##*-"$DSUF-$S12"-p}" ;;
  *) refuse "shard directory $SB is not <idx>-$DSUF-<sha12> for the manifest's sha $M_SHA (a later pass appends -p<M>)" ;;
esac
[ -n "$IDX" ] || refuse "shard directory $SB names no story index"
# A pass marker is a decimal integer >= 2 with no leading zero; pass 1 carries none.
pass_ok() { case "$1" in ""|0*|1|*[!0-9]*) return 1 ;; esac; return 0; }
[ -z "$DPASS" ] || pass_ok "$DPASS" \
  || refuse "shard directory $SB carries pass marker -p$DPASS; a pass marker is -p<M> with M an integer >= 2 (pass 1 carries none)"
OB="$(basename "$OUT")"
OPASS=""
case "$OB" in
  "$IDX-$DSUF.md") ;;
  "$IDX-$DSUF"-p*.md) OPASS="${OB#"$IDX-$DSUF"-p}"; OPASS="${OPASS%.md}"
    pass_ok "$OPASS" \
      || refuse "--out $OB carries pass marker -p$OPASS; a pass marker is -p<M> with M an integer >= 2 (pass 1 carries none)" ;;
  *) refuse "--out $OB is not $IDX-$DSUF.md or $IDX-$DSUF-p<M>.md, the --gate $GATE review file for shard directory $SB" ;;
esac
pass_name() { if [ -n "$1" ]; then printf 'pass %s' "$1"; else printf 'pass 1 (no marker)'; fi; }
[ "$OPASS" = "$DPASS" ] \
  || refuse "pass marker mismatch: shard directory $SB is $(pass_name "$DPASS") and --out $OB is $(pass_name "$OPASS"); a shard directory is merged only into its own pass's review file"

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

# ---- the cross groups, read from their one speller ----------------------------------------
# CROSS_KEYS is `cross` when the table has one row (K=2) and `cross-1 .. cross-<G>` otherwise;
# nothing here restates the construction. CROSS_FIRST is the execution owner (header).
XPART="$SELF_DIR/partition-document.sh"
[ -f "$XPART" ] || refuse "cannot read the cross groups: $XPART is absent"
bash "$XPART" --cross-groups "$K" > "$T/groups" 2> "$T/groups.err" < /dev/null; grc=$?
[ "$grc" -eq 0 ] || refuse "partition-document.sh --cross-groups $K exited $grc: $(head -1 "$T/groups.err")"
G="$(grep -c . "$T/groups")" || G=0
[ "$G" -ge 1 ] || refuse "partition-document.sh --cross-groups $K printed no group"
i=0
while IFS="$TAB" read -r gg gl; do
  i=$((i + 1))
  [ "$gg" = "$i" ] && [[ $gl =~ ^[0-9]+(,[0-9]+)+$ ]] \
    || refuse "partition-document.sh --cross-groups $K printed row $i as '$gg	$gl'; want <g>\\t<ordinal,ordinal,...> with g = 1..G in order"
done < "$T/groups"
if [ "$G" -eq 1 ]; then CROSS_KEYS="cross"
else CROSS_KEYS="$(awk '{ printf "%scross-%d", (NR > 1 ? " " : ""), NR }' "$T/groups")"; fi
CROSS_FIRST="${CROSS_KEYS%% *}"
is_cross() { case "$1" in cross|cross-*) return 0 ;; esac; return 1; }

# ---- the shard set ----------------------------------------------------------------------
: > "$T/shards" || refuse "cannot stage the shard set"
for f in "$SDIR"/*; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ -f "$f" ] || refuse "$f is not a regular file; the shard directory holds only <ordinal>.md and the cross shards ($CROSS_KEYS)"
  case "$b" in
    cross.md) key="cross" ;;
    cross-*.md)
      gn="${b#cross-}"; gn="${gn%.md}"
      case "$gn" in ""|*[!0-9]*|??????????*) refuse "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)" ;; esac
      key="cross-$((10#$gn))" ;;
    *.md)
      case "${b%.md}" in ""|*[!0-9]*) refuse "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)" ;; esac
      key="$(norm_ord "${b%.md}")"
      [ -n "$key" ] || refuse "$f names ordinal ${b%.md}, outside 1..$K" ;;
    *) refuse "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)" ;;
  esac
  printf '%s\t%s\n' "$key" "$f" >> "$T/shards" || refuse "cannot stage the shard set"
done
dup="$(cut -f1 "$T/shards" | sort | uniq -d | head -1)"
[ -z "$dup" ] || refuse "shard $dup was delivered more than once in $SDIR"
# The cross shards delivered must be EXACTLY the table's: a mix of `cross.md` and `cross-<g>.md`,
# a `cross-<g>` the table does not print, or the wrong spelling for G are each refused by name.
x_plain=0; x_num=0
while IFS="$TAB" read -r xk xf; do
  case "$xk" in
    cross) x_plain=1 ;;
    cross-*) x_num=1
      case " $CROSS_KEYS " in *" $xk "*) ;; *) refuse "$xf is $xk, which partition-document.sh --cross-groups $K does not print (the cross shards for K=$K are: $CROSS_KEYS)" ;; esac ;;
  esac
done < "$T/shards"
[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \
  && refuse "$SDIR mixes cross.md with cross-<g>.md; a shard set is one cross shape or the other (for K=$K: $CROSS_KEYS)"
[ "$x_plain" -eq 1 ] && [ "$G" -gt 1 ] \
  && refuse "$SDIR holds cross.md, but the part map has $K parts, whose cross groups are $CROSS_KEYS; a single cross shard is owed only at K=2"
for idx in $ORDINALS $CROSS_KEYS; do
  [ -n "$(awk -F'\t' -v k="$idx" '$1 == k { print; exit }' "$T/shards")" ] \
    || refuse "shard $idx is missing from $SDIR (expected: $ORDINALS and $CROSS_KEYS)"
done

# ---- seat-complete (the belt; the join beat's --complete is the braces) --------------------
# If ANY shard's last non-blank line is the marker, every shard's must be. See the header.
: > "$T/sc" || refuse "cannot stage the completion check"
while IFS="$TAB" read -r sk sf_; do
  if awk 'NF { l = $0 } END { exit !(l ~ /^seat-complete: /) }' "$sf_"; then printf 'Y\t%s\n' "$sk" >> "$T/sc"
  else printf 'N\t%s\t%s\n' "$sk" "$sf_" >> "$T/sc"; fi || refuse "cannot stage the completion check"
done < "$T/shards"
if grep -q '^Y' "$T/sc" && grep -q '^N' "$T/sc"; then
  sc_bad="$(awk -F'\t' '$1 == "N" { print $3; exit }' "$T/sc")"
  refuse "$sc_bad does not end in 'seat-complete: ' while another shard in $SDIR does; that shard is unfinished (its last non-blank line must be 'seat-complete: <step> <seat> <shard>')"
fi

# ---- per-shard parse --------------------------------------------------------------------
# Emits: R <n> <first value>   V <n> <first value>   X <line> <n-parts-lines> <parts>   C <findings>
#        F <has ## Findings>   S <first stray parts: line>   A <## Acceptance Criteria count>
#        D <## Deferred ACs count>   (A and D are read under --gate qa only)
#        HO <line> <finding line> <AC>   HR <line> <finding line> <ordinal> <AC> <result> [extra]
#        H <first stray handover:/handover-run: line>   HM <first malformed hand-over line>
#        N <handovers: count> <first value>   (HO, HR, H, HM, N and X's last two fields --
#        handover: and handover-run: lines in that finding -- are read under --gate qa only)
parse_shard() {
  awk '
    function flush() { if (fl > 0) printf "X %d %d %s %d %d\n", fl, fn, (fst == "" ? "-" : fst), fh + 0, fr + 0; fl = 0 }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^reviewed-sha:/ { nr++; if (nr == 1) { v = $0; sub(/^reviewed-sha:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); rv = v } }
    /^shard-verdict:/ { nv++; if (nv == 1) { v = $0; sub(/^shard-verdict:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); vv = v } }
    /^handovers:/ { nh++; if (nh == 1) { v = $0; sub(/^handovers:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); gsub(/[ \t]+/, "_", v); hv = v } }
    { lc = tolower($0) }
    lc ~ /^###?[ \t]+acceptance criteria/ { nac++ }
    lc ~ /^###?[ \t]+deferred/ { nda++ }
    /^## / { flush(); infind = ($0 ~ /^## Findings[ \t]*$/); if (infind) hasfind = 1; next }
    /^### / { flush(); next }
    infind && /^#### / { flush(); fl = NR; fn = 0; fst = ""; fh = 0; fr = 0; nfind++; next }
    infind && fl > 0 && /^parts:/ { fn++; v = $0; sub(/^parts:[ \t]*/, "", v); gsub(/[ \t]+/, "", v); fst = v; next }
    infind && fl > 0 && /^handover:/ { fh++; v = $0; sub(/^handover:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
                                       printf "HO %d %d %s\n", NR, fl, (v == "" ? "-" : v); next }
    infind && fl > 0 && /^handover-run:/ { fr++; v = $0; sub(/^handover-run:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
                                           printf "HR %d %d %s\n", NR, fl, (v == "" ? "-" : v); next }
    lc ~ /^[ \t]*([-*+][ \t]+)?handover(-run)?[ \t]*:/ { if (!hstray) hstray = NR; next }
    lc ~ /^[ \t>*_`+-]*([0-9]+\.[ \t]*)?[ \t>*_`+-]*hand[- ]?over(-run)?[*_` \t]*:/ \
      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over[^a-z0-9]+[a-z0-9][a-z0-9._-]*[0-9][a-z0-9._-]*([^a-z0-9._-]|$)/ \
      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over-run[^a-z0-9]+[0-9]+[^a-z0-9]+[a-z0-9]/ { if (!hbad) hbad = NR }
    /^[ \t]*([-*+][ \t]+)?parts:/ { if (!stray) stray = NR }
    END { flush(); printf "R %d %s\n", nr + 0, (rv == "" ? "-" : rv); printf "V %d %s\n", nv + 0, (vv == "" ? "-" : vv); printf "C %d\n", nfind + 0
          printf "F %d\n", hasfind + 0; printf "S %d\n", stray + 0; printf "H %d\n", hstray + 0; printf "HM %d\n", hbad + 0
          printf "N %d %s\n", nh + 0, (hv == "" ? "-" : hv)
          printf "A %d\n", nac + 0; printf "D %d\n", nda + 0 }
  ' "$1"
}
RE_CITED='^[0-9]+(,[0-9]+)*$'
RE_AC='^[A-Za-z0-9][A-Za-z0-9._-]*$'
WORST=""; WORST_R=0; NFIND=0; FORCE=""
: > "$T/hand" && : > "$T/runs" && : > "$T/runords" && : > "$T/htable" || refuse "cannot stage the hand-over set"
: > "$T/body" || refuse "cannot stage the merged body"
: > "$T/vtable" || refuse "cannot stage the verdict table"
for key in $ORDINALS $CROSS_KEYS; do
  sf="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/shards")"
  P="$T/parse.$key"
  parse_shard "$sf" > "$P" || refuse "parsing $sf did not run"
  set -- $(awk '$1 == "R" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] || refuse "$sf carries ${1:-0} 'reviewed-sha:' line(s) outside a fence; a shard carries exactly one"
  [ "${2:-}" = "$M_SHA" ] || refuse "$sf reviewed ${2:-<none>}, not the frozen sha $M_SHA; the shard reviewed another tree"
  set -- $(awk '$1 == "V" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] || refuse "$sf carries ${1:-0} 'shard-verdict:' line(s) outside a fence; a shard carries exactly one"
  v="${2:-}"; r="$(rank "$v")"
  [ "$r" -gt 0 ] || refuse "$sf shard-verdict '${v:-<none>}' is not one of $RANKED"
  if [ "$r" -gt "$WORST_R" ]; then WORST_R="$r"; WORST="$v"; fi
  printf '| %s | %s |\n' "$key" "$v" >> "$T/vtable" || refuse "cannot stage the verdict table"
  nf="$(awk '$1 == "C" { print $2 }' "$P")"; NFIND=$((NFIND + ${nf:-0}))
  [ "$(awk '$1 == "F" { print $2 }' "$P")" = "1" ] \
    || refuse "$sf carries no '## Findings' section; a shard reports its findings there, even when it has none"
  sl="$(awk '$1 == "S" { print $2 }' "$P")"
  [ "${sl:-0}" = "0" ] \
    || refuse "$sf:$sl carries a 'parts:' line outside a '#### ' finding under '## Findings' (indented, bulleted, or under another section); every finding is a '#### ' heading there"
  if [ "$GATE" = "qa" ]; then
    nac="$(awk '$1 == "A" { print $2 }' "$P")"; nda="$(awk '$1 == "D" { print $2 }' "$P")"
    if [ "$key" = "$CROSS_FIRST" ]; then
      [ "${nac:-0}" = "1" ] \
        || refuse "$sf carries ${nac:-0} '## Acceptance Criteria' section(s) outside a fence; the cross shard carries exactly one, the story's per-AC table"
      [ "${nda:-0}" -le 1 ] \
        || refuse "$sf carries ${nda:-0} '## Deferred ACs' sections outside a fence; the cross shard carries at most one"
    elif is_cross "$key"; then
      [ "${nac:-0}" = "0" ] \
        || refuse "$sf ($key) carries a '## Acceptance Criteria' section; only $CROSS_FIRST, the execution owner, writes the per-AC table"
      [ "${nda:-0}" = "0" ] \
        || refuse "$sf ($key) carries a '## Deferred ACs' section; only $CROSS_FIRST, the execution owner, writes the deferred-AC discharge predicates"
    else
      [ "${nac:-0}" = "0" ] \
        || refuse "$sf (part shard $key) carries a '## Acceptance Criteria' section; only the cross shard writes the per-AC table"
      [ "${nda:-0}" = "0" ] \
        || refuse "$sf (part shard $key) carries a '## Deferred ACs' section; only the cross shard writes the deferred-AC discharge predicates"
    fi
  fi

  if [ "$GATE" = qa ]; then
    hl="$(awk '$1 == "H" { print $2 }' "$P")"
    [ "${hl:-0}" = "0" ] \
      || refuse "$sf:$hl carries a 'handover:' or 'handover-run:' line outside a '#### ' finding under '## Findings' (indented, bulleted, another case, or under another section); each sits at column 0 inside its finding"
    hm="$(awk '$1 == "HM" { print $2 }' "$P")"
    # THE DECLARED COUNT, before the malformed-line refusal: a hand-over spelled any way the parser
    # does not read is not counted, so it disagrees with the count its writer declared, and this
    # refusal needs no list of bad spellings. A count that agrees leaves the precise message below.
    # READ, NEVER WORD-SPLIT: `set -- $(...)` globbed the value, so `handovers: ?` became `0` in a
    # cwd holding a file named `0` and merged PASS over a hidden hand-over (measured).
    nhd=""; hdv=""
    read -r nhd hdv <<<"$(awk '$1 == "N" { print $2, $3 }' "$P")"
    nhd="${nhd:-0}"; hdv="${hdv:--}"
    nho_s="$(grep -c '^HO ' "$P")" || nho_s=0
    hmnote=""; [ "${hm:-0}" = "0" ] || hmnote=" ($sf:$hm is a malformed hand-over line)"
    if is_cross "$key"; then
      [ "$nhd" = "0" ] \
        || refuse "$sf carries a 'handovers:' line; only a part shard declares a hand-over count, the cross shard records its replays as 'handover-run:'"
    else
      [ "$nhd" = "1" ] \
        || refuse "$sf (part shard $key) carries $nhd 'handovers:' line(s) outside a fence; a part shard carries exactly one column-0 'handovers: <n>', 0 when it handed nothing over"
      case "$hdv" in *[!0-9]*|??????????*) refuse "$sf (part shard $key) 'handovers: ${hdv//_/ }' is not a non-negative integer" ;; esac
      [ "$((10#$hdv))" -eq "$nho_s" ] \
        || refuse "$sf (part shard $key) declares 'handovers: $hdv' but the merge parsed $nho_s 'handover:' line(s); a hand-over is counted only as a bare column-0 'handover: <AC-id>' line inside its '#### ' finding$hmnote"
    fi
    [ "${hm:-0}" = "0" ] \
      || refuse "$sf:$hm is a malformed hand-over line (decorated, quoted, hyphenated or missing its colon); a hand-over is written bare as 'handover: <AC-id>' or 'handover-run: <ordinal> <AC-id> <result>' at column 0"
    while read -r tag hline hfl a1 a2 a3 a4; do
      case "$tag" in
        HO)
          ! is_cross "$key" || refuse "$sf:$hline carries a 'handover:' line; only a part shard hands an AC over, the cross shard records the replay as 'handover-run:'"
          [ -z "${a2:-}" ] || refuse "$sf:$hline handover: '${a1:-} ${a2:-}' names more than one AC; a hand-over line names exactly one <AC-id>"
          [[ ${a1:-} =~ $RE_AC ]] || refuse "$sf:$hline handover: '${a1:-}' is not an <AC-id> (one token beginning with a letter or digit)"
          printf '%s %s\n' "$key" "$a1" >> "$T/hand" || refuse "cannot stage the hand-over set" ;;
        HR)
          is_cross "$key" || refuse "$sf:$hline (part shard $key) carries a 'handover-run:' line; only the cross shard runs a handed-over replay"
          [ "$key" = "$CROSS_FIRST" ] \
            || refuse "$sf:$hline ($key) carries a 'handover-run:' line; only $CROSS_FIRST, the execution owner, runs a handed-over replay in the frozen worktree"
          o="$(norm_ord "${a1:-}")"
          [ -n "$o" ] && [[ ${a2:-} =~ $RE_AC ]] && [ -z "${a4:-}" ] \
            || refuse "$sf:$hline handover-run: '${a1:-} ${a2:-} ${a3:-} ${a4:-}' is not <ordinal 1..$K> <AC-id> <result>"
          case "${a3:-}" in
            RED) ;;
            GREEN-SURVIVED|NO-BASELINE) FORCE="${FORCE:-$o $a2 $a3}" ;;
            *) refuse "$sf:$hline handover-run result '${a3:-}' is not RED, GREEN-SURVIVED or NO-BASELINE" ;;
          esac
          printf '%s %s\n' "$o" "$a2" >> "$T/runs" || refuse "cannot stage the hand-over replay set"
          printf '%s %s\n' "$hfl" "$o" >> "$T/runords" || refuse "cannot stage the hand-over replay set"
          printf '| %s | %s | %s |\n' "$o" "$a2" "$a3" >> "$T/htable" || refuse "cannot stage the hand-over replay table" ;;
      esac
    done < "$P"
  fi

  while read -r tag line nlines cited nho nhr; do
    [ "$tag" = "X" ] || continue
    [ "$nlines" = "1" ] || refuse "$sf:$line finding carries $nlines 'parts:' lines; each finding carries exactly one"
    [[ $cited =~ $RE_CITED ]] || refuse "$sf:$line parts: '$cited' is not <ordinal>[, <ordinal>...]"
    distinct=""
    for c in $(printf '%s' "$cited" | tr ',' ' '); do
      o="$(norm_ord "$c")"
      [ -n "$o" ] || refuse "$sf:$line cites part $c, outside 1..$K"
      case " $distinct " in *" $o "*) ;; *) distinct="$distinct $o" ;; esac
    done
    if [ "$GATE" = qa ]; then
      [ "${nho:-0}" -le 1 ] || refuse "$sf:$line finding carries $nho 'handover:' lines; a hand-over finding names exactly one AC"
      if is_cross "$key" && [ "${nhr:-0}" -gt 0 ]; then
        want="$(awk -v f="$line" '$1 == f { print $2 }' "$T/runords" | sort -u | tr '\n' ' ')"
        got="$(printf '%s\n' $distinct | sort -u | tr '\n' ' ')"
        [ "$want" = "$got" ] \
          || refuse "$sf:$line (cross shard) cites$distinct but its 'handover-run:' lines name ${want% }; a hand-over replay finding cites exactly the parts it ran replays for"
        continue
      fi
    fi
    set -- $distinct
    if is_cross "$key"; then
      [ $# -ge 2 ] || refuse "$sf:$line (cross shard) cites only$distinct; a cross finding cites two or more parts, a one-part finding belongs to that part's shard"
      # THE OWNER RULE: the one group --cross-owner names, never any other that also covers it.
      own="$(bash "$XPART" --cross-owner "$K" "$(printf '%s' "${distinct# }" | tr ' ' ',')" 2> "$T/own.err" < /dev/null)" \
        || refuse "partition-document.sh --cross-owner $K on$distinct failed: $(head -1 "$T/own.err")"
      if [ "$G" -eq 1 ]; then ownk="cross"; else ownk="cross-$own"; fi
      [ "$ownk" = "$key" ] \
        || refuse "$sf:$line ($key) cites$distinct, a finding owned by $ownk (partition-document.sh --cross-owner); a cross shard reports only the findings it owns, or the merged verdict and finding count depend on the cover"
    else
      [ $# -eq 1 ] && [ "$1" = "$key" ] \
        || refuse "$sf:$line (shard $key) cites$distinct; a part shard reports only findings citing its own part alone"
    fi
  done < "$P"

  if [ "$key" = "cross" ]; then printf '\n## Shard: cross\n\n' >> "$T/body" || refuse "cannot stage the merged body"
  elif is_cross "$key"; then
    printf '\n## Shard: %s (%s)\n\n' "$key" "$(awk -F'\t' -v g="${key#cross-}" '$1 == g { print $2; exit }' "$T/groups")" >> "$T/body" \
      || refuse "cannot stage the merged body"
  else printf '\n## Shard: part %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  # The seat-complete marker is dropped: inside the merged file it would read as the merge's own.
  awk '!/^seat-complete: /' "$sf" >> "$T/body" || refuse "cannot stage the body of $sf"
done

# ---- the hand-over join (--gate qa) ------------------------------------------------------
# Every part hand-over is matched by EXACTLY ONE cross replay, and every replay by a hand-over.
# Keys are `<ordinal> <AC-id>`, the ordinal normalised, compared under LC_ALL=C.
if [ "$GATE" = qa ]; then
  d1="$(sort "$T/hand" | uniq -d | head -1)"
  [ -z "$d1" ] || refuse "hand-over '$d1' (<ordinal> <AC-id>) is handed over more than once"
  d1="$(sort "$T/runs" | uniq -d | head -1)"
  [ -z "$d1" ] || refuse "hand-over '$d1' has more than one 'handover-run:' line in $CROSS_FIRST.md; each hand-over is run exactly once"
  sort -u "$T/hand" > "$T/hand.s" && sort -u "$T/runs" > "$T/runs.s" || refuse "cannot sort the hand-over sets"
  d1="$(comm -23 "$T/hand.s" "$T/runs.s" | head -1)"
  [ -z "$d1" ] || refuse "hand-over '$d1' (part shard $(printf '%s' "$d1" | cut -d' ' -f1)) has no 'handover-run:' line in $CROSS_FIRST.md; the cross shard runs every handed-over replay before the merge"
  d1="$(comm -13 "$T/hand.s" "$T/runs.s" | head -1)"
  [ -z "$d1" ] || refuse "$CROSS_FIRST.md carries 'handover-run: $d1' but part shard $(printf '%s' "$d1" | cut -d' ' -f1) handed over no such AC"
  NHAND="$(grep -c . "$T/hand.s")" || NHAND=0
  # An unmet HARD GATE: the replay did not go RED, or never reached a GREEN baseline.
  if [ -n "$FORCE" ]; then WORST="NEEDS_REWORK"; WORST_R="$(rank NEEDS_REWORK)"; fi
fi

{
  printf '# %s: %s (merged from %s shards)\n\n' "$TITLE" "$IDX" "$((K + G))"
  printf '## Summary\n\n'
  if [ "$G" -eq 1 ]; then XWORD="one cross shard"; else XWORD="$G cross shards"; fi
  printf 'Merged by merge-review-shards.sh from %s part shards and %s, all reviewing\n' "$K" "$XWORD"
  printf '`%s..%s`. The verdict below is RECOMPUTED as the worst shard verdict; the\n' "$M_BASE" "$M_SHA"
  printf 'shard verdicts in the table are advisory inputs to it.\n\n'
  if [ -n "$FORCE" ]; then
    printf 'A handed-over replay is an unmet HARD GATE (%s), so the verdict is NEEDS_REWORK\n' "$FORCE"
    printf 'whatever the shard verdicts say.\n\n'
  fi
  printf '## Verdict\n%s\n\n' "$WORST"
  printf '## Shard verdicts\n\n| shard | shard-verdict |\n|---|---|\n'
  cat "$T/vtable"
  if [ -s "$T/htable" ]; then
    printf '\n## Hand-over replays\n\n| part | AC | handover-run |\n|---|---|---|\n'
    sort "$T/htable"
  fi
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
