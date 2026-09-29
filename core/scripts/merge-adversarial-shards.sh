#!/usr/bin/env bash
# merge-adversarial-shards.sh -- join a sharded adversarial pass into the ONE pass file every
# gate reads.
#
# USAGE
#   merge-adversarial-shards.sh <shard-dir>
#   merge-adversarial-shards.sh --map <shard-dir>   print `<ordinal>\t<basename>`, one per story,
#                                                   for the lead to put in each shard brief
#   merge-adversarial-shards.sh --document <path> <shard-dir>
#                                                   SECTION mode: one single-file artifact, sharded
#                                                   by the parts partition-document.sh --map prints
#
#   <shard-dir> is `<planning>/s<N>/shards/<artifact>-p<M>/`. Everything else is DERIVED from
#   that one path, so the placement cannot be mis-spelled by a caller:
#     stories   <planning>/s<N>/<artifact>/          (the multi-file artifact under review)
#     output    <planning>/s<N>/<artifact>-adversarial-p<M>.md
#   No project root is resolved: the siblings read are the convergence validator and, in
#   section mode, partition-document.sh, both located beside this script (both layouts put them
#   in one directory). A shard's relative `artifact:` is resolved by walking UP from s<N>/ for
#   the first directory it names a file under -- a walk, never a root.
#
# SECTION MODE (--document)
#   The unit is a SECTION of one document, not a story file. The ordinal set is the parts
#   `partition-document.sh --map <path>` prints -- never a listing of the shard directory -- and a
#   document it calls SERIAL is REFUSED: a SERIAL document is reviewed by one adversary, so a
#   shard set for it is a dispatch that should not have happened. The shard set, the finding
#   partition, the count check, the sums and the recomputed verdict are the files-mode ones
#   below, with three differences:
#     citation   each finding carries exactly one `sections: <ordinal>[, ...]`; a `stories:`
#                line is REFUSED by its own guard, which runs before the one-citation count --
#                a finding carrying one of each passes the count and is refused only there.
#     sha        EVERY shard, cross included, reviewed the whole document and notarizes the
#                sha256 of the whole document, which must equal the bytes on disk; the merged
#                block carries that ONE `artifact_sha`, because the convergence validator's
#                arms read one sha per pass.
#     artifact   every shard's `artifact:` must resolve to the same absolute path as
#                --document; the same bytes under another name are another artifact.
#   The merged block adds `shard_wall: <key>=<invoked_at>/<mtime> ...`, each shard's claimed
#   start and its file's modification time (UTC), so the wall clock a section fan-out actually
#   bought is readable from the pass file rather than argued about.
#
# WHY IT EXISTS
#   A multi-file artifact is reviewed by one adversary per story ORDINAL plus one cross-story
#   adversary. Each writes a shard; the convergence validator, the hooks and every other
#   reader keep reading exactly one `<artifact>-adversarial-p<M>.md`. This script is the
#   deterministic JOIN that writes it. Shard verdicts are ADVISORY: the merged verdict is
#   RECOMPUTED from the summed residue, because three shards each holding 2 blocking MAJOR
#   may each honestly stamp EXIT_CONDITION_MET while the artifact holds 6.
#
# SHARD FILES (non-recursive, `<shard-dir>/*`)
#   `<ordinal>.md` one per story, `cross.md` once. Any other non-dot entry is REFUSED -- a
#   re-dispatch written beside the original must not be silently ignored.
#   THE KEY IS THE ORDINAL, NEVER THE FILENAME. Every `*.md` directly in
#   `<planning>/s<N>/<artifact>/` is a story whatever it is called (`story-<n>-`, `story-<e>-<n>-`,
#   `bug-`, `hotfix-`, ...); its ordinal is its 1-based position in the `LC_ALL=C` sorted listing,
#   zero-padded to the width of the story count K (`01.md` .. `12.md`). A slug never reaches a
#   shard path, because a slug can carry a sprint token the consumer's push guard refuses.
#   Ordinals compare numerically (`1.md` and `01.md` are the same shard, so both is a duplicate).
#
# REFUSED KEYS: a shard ordinal outside 1..K, a duplicate shard, a missing ordinal or cross
#   shard, an unreadable story file, fewer than two story files (a one-file artifact is never
#   sharded), and a shard-directory entry that is neither `<digits>.md` nor `cross.md`.
#
# FINDING GRAMMAR (the partition this script checks; `adversary.md` cites it, not restates it)
#   A finding is a `### ` heading inside the shard `## Findings` section (up to the next
#   `## ` heading); lines inside ``` or ~~~ fences are not headings. Its severity is the FIRST
#   of CRITICAL / MAJOR / MINOR / NIT in the heading. Each finding carries EXACTLY ONE line
#       stories: <ordinal>[, <ordinal>...]          e.g. `stories: 03` or `stories: 01, 04`
#   outside a fence, citing ordinals from `--map`. A per-ordinal shard may cite ONLY its own
#   ordinal; the cross-story shard only findings citing two or more DISTINCT ordinals. Every
#   cited ordinal must be within 1..K.
#   Per shard, the CRITICAL-heading count must equal `findings_critical` and the MAJOR-heading
#   count `findings_major` -- otherwise the partition is checked over findings that are not
#   the ones the counts describe.
#
# THE MERGE
#   Sums findings_critical, findings_major, findings_minor, findings_critical_prior_scope and
#   findings_major_underived with the CONVERGENCE VALIDATOR defaults: prior_scope absent means
#   ALL of that shard CRITICALs (fail-closed), underived absent means zero. Verdict:
#     DIVERGENT_HARD_BLOCK   if any shard declared it;
#     EXIT_CONDITION_MET     iff summed critical <= CRITICAL_EXIT_CEILING and summed blocking
#                            MAJOR (major - underived) <= MAJOR_EXIT_CEILING;
#     EXIT_CONDITION_NOT_MET otherwise.
#   Both ceilings are READ from validate-adversarial-convergence.sh, never restated here.
#   artifact_sha is `<basename-stem>=<sha> ...` in ordinal order (each per-ordinal shard claim,
#   each checked against the story bytes on disk); tool_use_id is the cross shard;
#   shard_tool_use_ids is `<ordinal>=<id> ... cross=<id>`; invoked_at is the EARLIEST shard. The
#   merged body opens with the ordinal map (the `--map` output, fenced), then every shard body in
#   ordinal order, cross last, each with its own provenance block stripped, so the output
#   carries exactly ONE provenance block.
#
# EXIT
#   0  merged (stdout `MERGED: ...`), or the output already exists byte-identical (`UNCHANGED:`)
#   2  REFUSED (stdout `REFUSED: <reason>`) -- nothing written. Includes an existing output that
#      differs: a pass file a remediator may already have read is never silently overwritten.
set -u
export LC_ALL=C

refuse() { printf 'REFUSED: %s\n' "$*"; exit 2; }

USAGE="usage: merge-adversarial-shards.sh [--map | --document <path>] <planning>/s<N>/shards/<artifact>-p<M>"
MAP_ONLY=0; DOCUMENT=""
case "${1:-}" in
  -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;;
  --map) MAP_ONLY=1; shift ;;
  --document)
    [ $# -ge 2 ] || refuse "$USAGE"
    DOCUMENT="$2"; shift 2
    [ -n "$DOCUMENT" ] && [ -f "$DOCUMENT" ] && [ -r "$DOCUMENT" ] || refuse "--document ${DOCUMENT:-<empty>} is not a readable file"
    DOCUMENT="$(cd "$(dirname "$DOCUMENT")" && pwd -P)/$(basename "$DOCUMENT")" || refuse "--document's directory is not enterable" ;;
esac
[ $# -eq 1 ] || refuse "$USAGE"
# The CITATION AXIS: the one line name a finding cites its unit by. A line of the OTHER axis is
# refused explicitly (below), never merely ignored -- ignored, a `stories:` line in a document
# shard is invisible, and the finding is then judged on whatever `sections:` line sits beside it.
# Files mode keeps no second axis, so its behaviour on every input is what it was before sections.
if [ -n "$DOCUMENT" ]; then CITE=sections; OTHER=stories; NOUN=section; else CITE=stories; OTHER=""; NOUN=story; fi

SHARD_DIR="${1%/}"
[ -d "$SHARD_DIR" ] || refuse "shard directory $SHARD_DIR does not exist"
SHARD_DIR="$(cd "$SHARD_DIR" && pwd)" || refuse "shard directory $1 is not enterable"

SHARD_BASE="$(basename "$SHARD_DIR")"
SHARDS_PARENT="$(dirname "$SHARD_DIR")"
[ "$(basename "$SHARDS_PARENT")" = "shards" ] \
  || refuse "$SHARD_DIR is not under a shards/ directory (placement: s<N>/shards/<artifact>-p<M>/)"
SPRINT_DIR="$(dirname "$SHARDS_PARENT")"
case "$(basename "$SPRINT_DIR")" in
  s[0-9]*) ;;
  *) refuse "$SPRINT_DIR is not a sprint directory s<N>" ;;
esac
ARTIFACT="$(printf '%s' "$SHARD_BASE" | sed -n 's/^\(.*[^-]\)-p\([0-9][0-9]*\)$/\1/p')"
PASS="$(printf '%s' "$SHARD_BASE" | sed -n 's/^\(.*[^-]\)-p\([0-9][0-9]*\)$/\2/p')"
[ -n "$ARTIFACT" ] && [ -n "$PASS" ] || refuse "shard directory name $SHARD_BASE is not <artifact>-p<M>"
PASS=$((10#$PASS))
STORIES_DIR="$SPRINT_DIR/$ARTIFACT"
OUT="$SPRINT_DIR/$ARTIFACT-adversarial-p$PASS.md"
if [ -z "$DOCUMENT" ]; then
  [ -d "$STORIES_DIR" ] || refuse "the artifact under review $STORIES_DIR is not a directory; a single-file artifact is sharded only by section, with --document"
fi

T="$(mktemp -d "${TMPDIR:-/tmp}/merge-adversarial-shards.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$T"' EXIT

sha_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

if [ -n "$DOCUMENT" ]; then
# ---- the ordinal map, derived from the partition of the document -------------------------
# partition-document.sh is the ONLY speller of the section grammar; its --map is read here and
# never re-derived, and never replaced by a listing of the shard directory -- a listing is the
# set of shards that ARRIVED, not the set that was owed.
PARTITION="$(cd "$(dirname "$0")" && pwd)/partition-document.sh"
[ -f "$PARTITION" ] || refuse "cannot read the section partition: $PARTITION is absent"
bash "$PARTITION" --map "$DOCUMENT" > "$T/map" 2> "$T/map.err"; prc=$?
if [ "$prc" -eq 3 ]; then
  refuse "$DOCUMENT does not partition ($(grep -m1 '^SERIAL:' "$T/map" "$T/map.err" 2>/dev/null | sed 's/^[^:]*:SERIAL:/SERIAL:/')); a SERIAL document is reviewed by one adversary and never merged"
fi
[ "$prc" -eq 0 ] || refuse "partition-document.sh --map $DOCUMENT exited $prc: $(head -1 "$T/map") $(head -1 "$T/map.err")"
K="$(grep -c . "$T/map")" || K=0
[ "$K" -ge 2 ] || refuse "partition-document.sh --map $DOCUMENT printed $K part(s); a section merge needs two or more"
W=${#K}
i=0
while IFS="$(printf '\t')" read -r o a z h; do
  i=$((i + 1))
  case "$o" in ""|*[!0-9]*) refuse "partition-document.sh --map printed ordinal '$o' on row $i; want <ordinal>\\t<first>\\t<last>\\t<heading>" ;; esac
  [ "$((10#$o))" -eq "$i" ] || refuse "partition-document.sh --map printed ordinal $o on row $i; ordinals run 1..K in order"
done < "$T/map"
DOC_SHA="$(sha_of "$DOCUMENT")" || refuse "cannot hash $DOCUMENT"
[[ $DOC_SHA =~ ^[a-f0-9]{64}$ ]] || refuse "cannot hash $DOCUMENT"
else
# ---- the ordinal map, derived from the artifact directory ---------------------------------
# The glob expands in the C collation (LC_ALL=C above); it is re-sorted explicitly anyway so the
# order never depends on the shell's glob implementation.
: > "$T/listing" || refuse "cannot stage the story listing"
for f in "$STORIES_DIR"/*.md; do
  [ -e "$f" ] || continue
  printf '%s\n' "$(basename "$f")" >> "$T/listing" || refuse "cannot stage the story listing"
done
sort "$T/listing" > "$T/listing.sorted" || refuse "cannot order the story listing"
K="$(wc -l < "$T/listing.sorted" | tr -d ' ')"
[ "$K" -ge 2 ] || refuse "$STORIES_DIR holds $K story file(s); sharding applies to two or more"
W=${#K}
: > "$T/map" || refuse "cannot stage the ordinal map"
i=0
while IFS= read -r b; do
  i=$((i + 1))
  [ -f "$STORIES_DIR/$b" ] && [ -r "$STORIES_DIR/$b" ] || refuse "story file $STORIES_DIR/$b is unreadable"
  printf '%0*d\t%s\n' "$W" "$i" "$b" >> "$T/map" || refuse "cannot stage the ordinal map"
done < "$T/listing.sorted"
[ "$i" -eq "$K" ] || refuse "read $i of $K story files"
fi
if [ "$MAP_ONLY" -eq 1 ]; then cat "$T/map"; exit 0; fi
if [ -n "$DOCUMENT" ]; then UNIT_COUNT="part count of $DOCUMENT"; else UNIT_COUNT="story count of $STORIES_DIR"; fi
ORDINALS="$(cut -f1 "$T/map" | tr '\n' ' ')"
ORDINALS="${ORDINALS% }"
norm_ord() { # "003" -> 03 at width W; empty unless digits within 1..K
  case "$1" in ""|*[!0-9]*) return 0 ;; esac
  local n=$((10#$1))
  [ "$n" -ge 1 ] && [ "$n" -le "$K" ] || return 0
  printf '%0*d' "$W" "$n"
}

# ---- the exit ceilings, read from their one declaration ----------------------------------
VALIDATOR="$(cd "$(dirname "$0")" && pwd)/validate-adversarial-convergence.sh"
[ -f "$VALIDATOR" ] || refuse "cannot read the exit ceilings: $VALIDATOR is absent"
read_ceiling() { # $1 name -> the value, or empty unless declared exactly once as an integer
  local hits
  hits="$(grep -E "^$1=[0-9]+\$" "$VALIDATOR")" || return 0
  [ "$(printf '%s\n' "$hits" | wc -l | tr -d ' ')" = "1" ] || return 0
  printf '%s' "${hits#*=}"
}
MAJOR_CEIL="$(read_ceiling MAJOR_EXIT_CEILING)"
CRIT_CEIL="$(read_ceiling CRITICAL_EXIT_CEILING)"
[ -n "$MAJOR_CEIL" ] && [ -n "$CRIT_CEIL" ] \
  || refuse "MAJOR_EXIT_CEILING / CRITICAL_EXIT_CEILING are not each declared exactly once as an integer in $VALIDATOR"

# ---- the shard set ------------------------------------------------------------------------
: > "$T/shards" || refuse "cannot stage the shard set"
# Dotfiles are not walked: no shard name begins with a dot, and a Finder `.DS_Store` (one exists
# in the reference consumer's _bmad-output) would otherwise refuse a healthy shard set.
for f in "$SHARD_DIR"/*; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ -f "$f" ] || refuse "$f is not a regular file; the shard directory holds only <ordinal>.md and cross.md"
  case "$b" in
    cross.md) key="cross" ;;
    *.md)
      case "${b%.md}" in ""|*[!0-9]*) refuse "$f is not a shard name (<ordinal>.md or cross.md)" ;; esac
      key="$(norm_ord "${b%.md}")"
      [ -n "$key" ] || refuse "$f names ordinal ${b%.md}, outside 1..$K (the $UNIT_COUNT)" ;;
    *) refuse "$f is not a shard name (<ordinal>.md or cross.md)" ;;
  esac
  printf '%s\t%s\n' "$key" "$f" >> "$T/shards" || refuse "cannot stage the shard set"
done
dup="$(cut -f1 "$T/shards" | sort | uniq -d | head -1)"
[ -z "$dup" ] || refuse "shard $dup was delivered more than once in $SHARD_DIR"
for idx in $ORDINALS cross; do
  [ -n "$(awk -F'\t' -v k="$idx" '$1 == k { print; exit }' "$T/shards")" ] || refuse "shard $idx is missing from $SHARD_DIR (expected: $ORDINALS and cross)"
done

# ---- per-shard parse ----------------------------------------------------------------------
# One awk pass per shard. Emits:  B <starts> <ends>  /  F <key> <value>  /  X <line> <sev> <n-stories-lines> <stories>
parse_shard() {
  awk '
    function sev(h,   best, bp, i, w, p) {
      best = ""; bp = 0
      split("CRITICAL MAJOR MINOR NIT", w, " ")
      for (i = 1; i <= 4; i++) {
        p = index(h, w[i])
        if (p > 0 && (bp == 0 || p < bp)) { bp = p; best = w[i] }
      }
      return best == "" ? "NONE" : best
    }
    function flush() {
      if (fl > 0) printf "X %d %s %d %s\n", fl, fs, fn, (fst == "" ? "-" : fst)
      fl = 0
    }
    /SKILL_INVOCATION_PROVENANCE v1/ { starts++; inblk = 1; next }
    /SKILL_INVOCATION_PROVENANCE_END/ { ends++; inblk = 0; next }
    inblk {
      if (match($0, /^[a-z_]+:/)) {
        k = substr($0, 1, RLENGTH - 1); v = substr($0, RLENGTH + 1)
        sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
        if (!(k in seen)) { seen[k] = 1; printf "F %s %s\n", k, v }
      }
      next
    }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^## / { flush(); infind = ($0 ~ /^## Findings[ \t]*$/); next }
    infind && /^### / { flush(); fl = NR; fs = sev($0); fn = 0; fst = ""; next }
    infind && fl > 0 && index($0, cite ":") == 1 {
      fn++; v = substr($0, length(cite) + 2); sub(/^[ \t]*/, "", v); gsub(/[ \t]+/, "", v); fst = v; next
    }
    infind && fl > 0 && other != "" && index($0, other ":") == 1 { if (wrong == 0) wrong = NR; next }
    END { flush(); printf "B %d %d\n", starts + 0, ends + 0; printf "Y %d\n", wrong + 0 }
  ' cite="$CITE" other="$OTHER" "$1"
}

field() { # $1 parse file, $2 key
  awk -v k="$2" '$1 == "F" && $2 == k { sub(/^F [^ ]+ ?/, ""); print; exit }' "$1"
}
digits() { case "$1" in ""|*[!0-9]*) ;; *) printf '%s' "$1" ;; esac; }
# Held in variables: bash 3.2 reads an unquoted `[[ =~ $var ]]` regex as ERE, fork-free.
# invoked_at: to the second, optionally with a fraction -- the reference consumer stamps both.
RE_ISO='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?Z$'
# The ordering KEY for an invoked_at RE_ISO accepted. The raw strings do not order across the two
# forms: `.` sorts before `Z`, so `...:19.497Z` compares EARLIER than `...:19Z`. The key is the
# seconds prefix plus the fraction right-padded to nine digits, so both forms order by time.
at_key() { # sets AT_KEY; fork-free, called once per shard
  local f="${1:19}"
  f="${f#.}"; f="${f%Z}"; f="${f}000000000"
  AT_KEY="${1:0:19}.${f:0:9}"
}
RE_SHA='^[a-f0-9]{64}$'
RE_CITED='^[0-9]+(,[0-9]+)*$'

# A shard's `artifact:` token, resolved to the absolute path it names (sets ART_ABS, empty when it
# names no file). An absolute token is taken as written; a relative one is tried against the
# sprint directory and each directory above it, nearest first, because a shard writes it relative
# to the project root and the merge resolves no root of its own. Both sides pass through
# `pwd -P`, so a symlinked parent (macOS `/tmp` is `/private/tmp`) never refuses a correct path.
resolve_artifact() {
  local t="$1" d
  ART_ABS=""
  case "$t" in
    /*) [ -f "$t" ] && ART_ABS="$(cd "$(dirname "$t")" && pwd -P)/$(basename "$t")"; return 0 ;;
  esac
  d="$SPRINT_DIR"
  while [ -n "$d" ]; do
    if [ -f "$d/$t" ]; then ART_ABS="$(cd "$(dirname "$d/$t")" && pwd -P)/$(basename "$t")"; return 0; fi
    [ "$d" = "/" ] && return 0
    d="$(dirname "$d")"
  done
  return 0
}

S_CRIT=0; S_PRIOR=0; S_MAJOR=0; S_UNDER=0; S_MINOR=0; WALL_LIST=""
ANY_DIVERGENT=0; EARLIEST=""; EARLIEST_KEY=""; SHA_LIST=""; ID_LIST=""; ALL_IDS=""; CROSS_ID=""; CROSS_ARTIFACT=""
SKILL=""; MODE=""; LEAD_ROLE=""; RESOLVES=""; RESOLVES_SET=0
: > "$T/body" || refuse "cannot stage the merged body"

for key in $ORDINALS cross; do
  sf="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/shards")"
  P="$T/parse.$key"
  parse_shard "$sf" > "$P" || refuse "parsing $sf did not run"
  set -- $(awk '$1 == "B" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] && [ "${2:-0}" = "1" ] \
    || refuse "$sf carries ${1:-0} provenance block opening(s) and ${2:-0} closing(s); a shard carries exactly one block"

  crit="$(digits "$(field "$P" findings_critical)")"
  major="$(digits "$(field "$P" findings_major)")"
  [ -n "$crit" ] && [ -n "$major" ] \
    || refuse "$sf does not declare integer findings_critical and findings_major"
  prior="$(digits "$(field "$P" findings_critical_prior_scope)")"
  [ -n "$prior" ] || prior="$crit"
  [ "$prior" -le "$crit" ] || refuse "$sf declares findings_critical_prior_scope=$prior above findings_critical=$crit"
  under="$(digits "$(field "$P" findings_major_underived)")"
  [ -n "$under" ] || under=0
  [ "$under" -le "$major" ] || refuse "$sf declares findings_major_underived=$under above findings_major=$major"
  minor="$(digits "$(field "$P" findings_minor)")"
  [ -n "$minor" ] || minor=0

  v="$(field "$P" verdict | tr '[:lower:]' '[:upper:]' | sed -e 's/[^A-Z]\{1,\}/_/g' -e 's/^_//' -e 's/_$//')"
  case "$v" in
    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET) ;;
    DIVERGENT_HARD_BLOCK) ANY_DIVERGENT=1 ;;
    *) refuse "$sf declares verdict '${v:-<none>}', not one of EXIT_CONDITION_MET EXIT_CONDITION_NOT_MET DIVERGENT_HARD_BLOCK" ;;
  esac

  at="$(field "$P" invoked_at)"
  [[ $at =~ $RE_ISO ]] || refuse "$sf invoked_at '${at:-<none>}' is not ISO 8601 UTC to the second (an optional .<fraction> before Z is accepted)"
  at_key "$at"
  if [ -z "$EARLIEST" ] || [[ "$AT_KEY" < "$EARLIEST_KEY" ]]; then EARLIEST="$at"; EARLIEST_KEY="$AT_KEY"; fi

  tid="$(field "$P" tool_use_id)"
  case "$tid" in toolu_?*) ;; *) refuse "$sf tool_use_id '${tid:-<none>}' is not a toolu_ id" ;; esac
  case " $ALL_IDS " in *" $tid "*) refuse "$sf repeats tool_use_id $tid of another shard; one dispatch delivered twice" ;; esac
  ALL_IDS="$ALL_IDS $tid"
  ID_LIST="$ID_LIST $key=$tid"

  # skill / mode / lead_role are batch-invariant: every shard ran the same evaluation.
  val="$(field "$P" skill)"; [ -n "$val" ] || refuse "$sf declares no skill"
  [ -z "$SKILL" ] || [ "$SKILL" = "$val" ] || refuse "$sf declares skill '$val' where another shard declares '$SKILL'"
  SKILL="$val"
  val="$(field "$P" mode)"; [ -n "$val" ] || refuse "$sf declares no mode"
  [ -z "$MODE" ] || [ "$MODE" = "$val" ] || refuse "$sf declares mode '$val' where another shard declares '$MODE'"
  MODE="$val"
  val="$(field "$P" lead_role)"; [ -n "$val" ] || refuse "$sf declares no lead_role"
  [ -z "$LEAD_ROLE" ] || [ "$LEAD_ROLE" = "$val" ] || refuse "$sf declares lead_role '$val' where another shard declares '$LEAD_ROLE'"
  LEAD_ROLE="$val"
  rd="$(field "$P" resolves_divergence)"
  if [ -n "$rd" ]; then
    if [ "$RESOLVES_SET" -eq 1 ] && [ "$rd" != "$RESOLVES" ]; then refuse "$sf resolves_divergence disagrees with another shard"; fi
    RESOLVES="$rd"; RESOLVES_SET=1
  fi

  # The wrong-axis guard. It runs BEFORE the one-citation count below, and on purpose: a finding
  # carrying one `sections:` line AND a `stories:` line has exactly one line of this axis, so the
  # count passes it and only this line refuses it.
  wrong="$(awk '$1 == "Y" { print $2 }' "$P")"
  [ "${wrong:-0}" = "0" ] || refuse "$sf:$wrong carries a '$OTHER:' line; a document merge cites sections only, and a finding citing both axes is never keyed on one of them"

  if [ -n "$DOCUMENT" ]; then
    # Every shard -- cross included -- reviewed the WHOLE document's bytes, so every shard
    # notarizes the one whole-document sha and names the one document.
    sha="$(field "$P" artifact_sha)"
    [ "$sha" = "$DOC_SHA" ] || refuse "$sf notarizes ${sha:-<none>} but $DOCUMENT is $DOC_SHA on disk; the shard reviewed other bytes"
    art="$(field "$P" artifact)"
    [ -n "$art" ] || refuse "$sf declares no artifact; a section shard names the document it reviewed"
    resolve_artifact "$art"
    [ "$ART_ABS" = "$DOCUMENT" ] \
      || refuse "$sf names artifact '$art', which resolves to ${ART_ABS:-nothing}, not --document $DOCUMENT; the shard reviewed another file"
    if [ "$key" = "cross" ]; then CROSS_ID="$tid"; CROSS_ARTIFACT="$art"; fi
    mt="$(date -u -r "$sf" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
    [[ $mt =~ $RE_ISO ]] || refuse "cannot read the modification time of $sf"
    WALL_LIST="$WALL_LIST $key=$at/$mt"
  elif [ "$key" = "cross" ]; then
    CROSS_ID="$tid"; CROSS_ARTIFACT="$(field "$P" artifact)"
    [ -n "$CROSS_ARTIFACT" ] || refuse "$sf (cross-story) declares no artifact"
  else
    sha="$(field "$P" artifact_sha)"
    [[ $sha =~ $RE_SHA ]] || refuse "$sf artifact_sha '${sha:-<none>}' is not one sha256"
    sb="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/map")"
    disk="$(sha_of "$STORIES_DIR/$sb")" || refuse "story file $STORIES_DIR/$sb is unreadable"
    [ "$sha" = "$disk" ] || refuse "$sf notarizes $sha but $sb is $disk on disk; the shard reviewed other bytes"
    SHA_LIST="$SHA_LIST ${sb%.md}=$sha"
  fi

  # --- the partition ---
  n_crit_h=0; n_major_h=0
  while read -r tag line s nlines cited; do
    [ "$tag" = "X" ] || continue
    [ "$s" = "CRITICAL" ] && n_crit_h=$((n_crit_h + 1))
    [ "$s" = "MAJOR" ] && n_major_h=$((n_major_h + 1))
    [ "$nlines" = "1" ] || refuse "$sf:$line finding carries $nlines $CITE: lines; each finding carries exactly one"
    [[ $cited =~ $RE_CITED ]] || refuse "$sf:$line $CITE: '$cited' is not <ordinal>[, <ordinal>...]"
    distinct=""
    for c in $(printf '%s' "$cited" | tr ',' ' '); do
      o="$(norm_ord "$c")"
      [ -n "$o" ] || refuse "$sf:$line cites ordinal $c, outside 1..$K"
      case " $distinct " in *" $o "*) ;; *) distinct="$distinct $o" ;; esac
    done
    set -- $distinct
    if [ "$key" = "cross" ]; then
      [ $# -ge 2 ] || refuse "$sf:$line (cross-$NOUN shard) cites only$distinct; a cross-$NOUN finding cites two or more ordinals, a single-$NOUN one belongs to that $NOUN shard"
    else
      [ $# -eq 1 ] && [ "$1" = "$key" ] \
        || refuse "$sf:$line (shard $key) cites$distinct; a per-ordinal shard reports only findings citing its own ordinal alone"
    fi
  done < "$P"
  [ "$n_crit_h" -eq "$crit" ] && [ "$n_major_h" -eq "$major" ] \
    || refuse "$sf declares $crit CRITICAL / $major MAJOR but its ## Findings section heads $n_crit_h CRITICAL / $n_major_h MAJOR findings"

  S_CRIT=$((S_CRIT + crit)); S_PRIOR=$((S_PRIOR + prior)); S_MAJOR=$((S_MAJOR + major))
  S_UNDER=$((S_UNDER + under)); S_MINOR=$((S_MINOR + minor))

  # --- the body, provenance block stripped ---
  if [ -n "$DOCUMENT" ]; then
    if [ "$key" = "cross" ]; then printf '\n## Shard: cross-section\n\n' >> "$T/body" || refuse "cannot stage the merged body"
    else printf '\n## Shard: section %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  elif [ "$key" = "cross" ]; then printf '\n## Shard: cross-story\n\n' >> "$T/body" || refuse "cannot stage the merged body"
  else printf '\n## Shard: story %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  awk '/SKILL_INVOCATION_PROVENANCE v1/ { skip = 1; next }
       /SKILL_INVOCATION_PROVENANCE_END/ { skip = 0; next }
       !skip' "$sf" >> "$T/body" || refuse "cannot stage the body of $sf"
done

if grep -q 'SKILL_INVOCATION_PROVENANCE' "$T/body"; then
  refuse "a shard body mentions SKILL_INVOCATION_PROVENANCE outside its block; the merged file must carry exactly one"
fi

BLOCKING=$((S_MAJOR - S_UNDER))
if [ "$ANY_DIVERGENT" -eq 1 ]; then VERDICT="DIVERGENT_HARD_BLOCK"
elif [ "$S_CRIT" -le "$CRIT_CEIL" ] && [ "$BLOCKING" -le "$MAJOR_CEIL" ]; then VERDICT="EXIT_CONDITION_MET"
else VERDICT="EXIT_CONDITION_NOT_MET"; fi

{
  printf '# %s -- adversarial pass %s (merged from %s shards)\n' "$ARTIFACT" "$PASS" "$(wc -l < "$T/shards" | tr -d ' ')"
  printf '\nVerdict RECOMPUTED by merge-adversarial-shards.sh from the summed residue; shard verdicts are advisory.\n'
  printf '\n## Shard ordinal map\n\n```text\n'
  cat "$T/map"
  printf '```\n'
  cat "$T/body"
  printf '\n<!-- SKILL_INVOCATION_PROVENANCE v1\n'
  printf 'skill: %s\n' "$SKILL"
  printf 'invoked_at: %s\n' "$EARLIEST"
  printf 'tool_use_id: %s\n' "$CROSS_ID"
  printf 'shard_tool_use_ids:%s\n' "$ID_LIST"
  printf 'mode: %s\n' "$MODE"
  printf 'lead_role: %s\n' "$LEAD_ROLE"
  printf 'artifact: %s\n' "$CROSS_ARTIFACT"
  if [ -n "$DOCUMENT" ]; then
    printf 'artifact_sha: %s\n' "$DOC_SHA"
    printf 'shard_wall:%s\n' "$WALL_LIST"
  else
    printf 'artifact_sha:%s\n' "$SHA_LIST"
  fi
  printf 'findings_critical: %s\n' "$S_CRIT"
  printf 'findings_critical_prior_scope: %s\n' "$S_PRIOR"
  printf 'findings_major: %s\n' "$S_MAJOR"
  printf 'findings_major_underived: %s\n' "$S_UNDER"
  printf 'findings_minor: %s\n' "$S_MINOR"
  [ "$RESOLVES_SET" -eq 1 ] && printf 'resolves_divergence: %s\n' "$RESOLVES"
  printf 'verdict: %s\n' "$VERDICT"
  printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
} > "$T/out" || refuse "cannot stage the merged pass file"

if [ -e "$OUT" ]; then
  if cmp -s "$T/out" "$OUT"; then
    printf 'UNCHANGED: %s verdict=%s\n' "$OUT" "$VERDICT"; exit 0
  fi
  refuse "$OUT already exists and differs from this merge; a pass file is never overwritten"
fi
cp "$T/out" "$OUT.merge-tmp.$$" && mv "$OUT.merge-tmp.$$" "$OUT" || refuse "writing $OUT failed"
printf 'MERGED: %s verdict=%s shards=%s critical=%s major=%s underived=%s blocking=%s ceiling=%s\n' \
  "$OUT" "$VERDICT" "$(wc -l < "$T/shards" | tr -d ' ')" "$S_CRIT" "$S_MAJOR" "$S_UNDER" "$BLOCKING" "$MAJOR_CEIL"
exit 0
