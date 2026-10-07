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
# SUBJECT MODE (--subject <N> [--base <sha>] [--elicitation] <shard-dir>)
#   The requirements step's SUBJECT -- brief, SPEC, PRD, architecture-impact, mapped over what
#   changed since one base -- reviewed as one artifact. The ordinal set is the parts
#   `partition-subject.sh --map <N> --manifest <s<N>/requirements-subject.md>` prints, and the base
#   is the one that manifest RECORDS: this merge never derives a base and never writes the
#   manifest (no manifest refuses). `--base` is an assertion against it. A subject the map calls
#   SERIAL is refused, as a SERIAL document is: one adversary writes that pass itself.
#     shard dir  `s<N>/shards/requirements-p<M>/` -> `s<N>/requirements-adversarial-p<M>.md`;
#                with --elicitation `s<N>/shards/requirements-elicitation/` ->
#                `s<N>/requirements-elicitation.md`. The sprint in the path must be <N>.
#     citation   `sections: <ordinal>[, ...]`, the document-mode grammar over SUBJECT ordinals.
#     sha        every shard notarizes `artifact_sha:` as `<stem>=<sha>` for ALL FOUR subject
#                stems (any order), each equal to that file on disk; the merged block carries the
#                list in subject order. `artifact:` must resolve to the subject manifest.
#     elicitation  no shard may carry `verdict:` and the merge writes none -- elicitation is not
#                a convergence pass -- and every shard declares `skill: bmad-advanced-elicitation`.
#   `--document` and files mode REFUSE a shard dir named `requirements-p<M>`, so subject mode is
#   the only writer of that series.
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
#   `<ordinal>.md` one per story, plus the CROSS SHARDS: one per row of
#   `partition-document.sh --cross-groups <K>` (K = the unit count, in EVERY mode), named
#   `cross-<g>.md` -- and `cross.md` iff that table has exactly one row (G=1, i.e. K=2). The
#   table is read from that one speller, never restated here. Every `cross-<g>` the table prints
#   is required; a `cross-<g>` it does not print, `cross.md` beside any `cross-<g>.md`, `cross.md`
#   when G>1 and `cross-<g>.md` when G=1 are each REFUSED. Any other non-dot entry is REFUSED -- a
#   re-dispatch written beside the original must not be silently ignored.
#
# THE OWNER RULE. The cross groups overlap (every unordered pair of units is in at least one
#   group, some pairs in several), so a finding two groups both see would be summed twice. Each
#   cross-shard finding is therefore accepted ONLY from the group that owns it -- the one
#   `partition-document.sh --cross-owner <K> <cited ordinals>` names -- and refused from any
#   other, so the summed counts do not depend on how the cover overlaps.
#
# SEAT-COMPLETE. A shard dispatched under the early-write brief ends, as its LAST NON-BLANK line,
#   in `seat-complete: <step> <adversary> <shard>`. If ANY shard in the directory carries that
#   line, every shard must, and one that does not is REFUSED as unfinished. Keyed on the marker's
#   presence in the directory, not on an install stamp: this merge resolves no root and reads no
#   git, and a directory whose shards predate the brief carries no marker anywhere and merges as
#   before. Its limit: a set in which NO shard has finished yet carries no marker either, so this
#   is the belt; `wait-for-deliverable.sh --complete` at the join is the braces. The marker line is
#   dropped from the merged body.
#   THE KEY IS THE ORDINAL, NEVER THE FILENAME. Every `*.md` directly in
#   `<planning>/s<N>/<artifact>/` is a story whatever it is called (`story-<n>-`, `story-<e>-<n>-`,
#   `bug-`, `hotfix-`, ...); its ordinal is its 1-based position in the `LC_ALL=C` sorted listing,
#   zero-padded to the width of the story count K (`01.md` .. `12.md`). A slug never reaches a
#   shard path, because a slug can carry a sprint token the consumer's push guard refuses.
#   Ordinals compare numerically (`1.md` and `01.md` are the same shard, so both is a duplicate).
#
# REFUSED KEYS: a shard ordinal outside 1..K, a duplicate shard, a missing ordinal or cross
#   shard, an unreadable story file, fewer than two story files (a one-file artifact is never
#   sharded), a cross shard the group table does not name, and a shard-directory entry that is
#   none of `<digits>.md`, `cross.md`, `cross-<digits>.md`.
#
# FINDING GRAMMAR (the partition this script checks; `adversary.md` cites it, not restates it)
#   A finding is a `### ` heading inside the shard `## Findings` section (up to the next
#   `## ` heading); lines inside ``` or ~~~ fences are not headings. Its severity is the FIRST
#   of CRITICAL / MAJOR / MINOR / NIT in the heading. Each finding carries EXACTLY ONE line
#       stories: <ordinal>[, <ordinal>...]          e.g. `stories: 03` or `stories: 01, 04`
#   outside a fence, citing ordinals from `--map`. A per-ordinal shard may cite ONLY its own
#   ordinal; a cross shard only findings citing two or more DISTINCT ordinals that it OWNS (the
#   owner rule above). Every cited ordinal must be within 1..K.
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
#   each checked against the story bytes on disk); tool_use_id is the FIRST cross shard's
#   (`cross` or `cross-1`); shard_tool_use_ids is `<ordinal>=<id> ... cross-1=<id> ... cross-<G>=<id>`
#   (`cross=<id>` when G=1); invoked_at is the EARLIEST shard. The merged body opens with the
#   ordinal map (the `--map` output, fenced), then every shard body in ordinal order, the cross
#   shards last in group order under one header per group, each with its own provenance block
#   stripped, so the output carries exactly ONE provenance block.
#
# EXIT
#   0  merged (stdout `MERGED: ...`), or the output already exists byte-identical (`UNCHANGED:`)
#   2  REFUSED (stdout `REFUSED: <reason>`) -- nothing written. Includes an existing output that
#      differs: a pass file a remediator may already have read is never silently overwritten.
set -u
export LC_ALL=C

refuse() { printf 'REFUSED: %s\n' "$*"; exit 2; }

USAGE="usage: merge-adversarial-shards.sh [--map | --document <path> | --subject <N> [--base <sha>] [--elicitation]] <planning>/s<N>/shards/<artifact>-p<M>"
MAP_ONLY=0; DOCUMENT=""; SUBJECT=""; SUBJ_BASE=""; ELICIT=0
case "${1:-}" in
  -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;;
  --map) MAP_ONLY=1; shift ;;
  --subject)
    [ $# -ge 2 ] || refuse "$USAGE"
    SUBJECT="${2#s}"; shift 2
    case "$SUBJECT" in ""|*[!0-9]*) refuse "--subject takes a sprint number (got '$SUBJECT')" ;; esac
    while [ $# -gt 1 ]; do
      case "$1" in
        --base) [ -n "${2:-}" ] || refuse "--base needs a value"; SUBJ_BASE="$2"; shift 2 ;;
        --elicitation) ELICIT=1; shift ;;
        *) break ;;
      esac
    done ;;
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
if [ -n "$DOCUMENT" ] || [ -n "$SUBJECT" ]; then CITE=sections; OTHER=stories; NOUN=section; else CITE=stories; OTHER=""; NOUN=story; fi
if [ -n "$SUBJECT" ]; then NOUN=part; fi

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
if [ -n "$SUBJECT" ] && [ "$ELICIT" -eq 1 ]; then
  [ "$SHARD_BASE" = "requirements-elicitation" ] \
    || refuse "an elicitation merge reads s<N>/shards/requirements-elicitation/, not $SHARD_BASE"
  ARTIFACT="requirements"; PASS=""
  OUT="$SPRINT_DIR/requirements-elicitation.md"
else
ARTIFACT="$(printf '%s' "$SHARD_BASE" | sed -n 's/^\(.*[^-]\)-p\([0-9][0-9]*\)$/\1/p')"
PASS="$(printf '%s' "$SHARD_BASE" | sed -n 's/^\(.*[^-]\)-p\([0-9][0-9]*\)$/\2/p')"
[ -n "$ARTIFACT" ] && [ -n "$PASS" ] || refuse "shard directory name $SHARD_BASE is not <artifact>-p<M>"
PASS=$((10#$PASS))
OUT="$SPRINT_DIR/$ARTIFACT-adversarial-p$PASS.md"
fi
STORIES_DIR="$SPRINT_DIR/$ARTIFACT"
# B4: the requirements series is the SUBJECT's. A whole-PRD `--document` merge (or a files merge)
# into it would write a pass K3 then has to fail; refuse it here, before anything is read.
if [ -z "$SUBJECT" ] && [ "$ARTIFACT" = "requirements" ]; then
  refuse "$SHARD_BASE is the requirements subject's series; merge it with --subject <N>, never --document or files mode"
fi
# B4, by DOCUMENT as well as by name: in a sprint with a subject manifest, a `--document` merge of
# ANY file the manifest names (brief, SPEC, prd.md, architecture-impact.md) would write a
# `<stem>-adversarial-p<M>` series over a quarter of the subject under another name. Refuse it;
# the subject is merged with --subject. The manifest is rooted as arm K3 roots it: walk up from
# the sprint dir for the first `file:` row, then compare physical paths row by row.
if [ -n "$DOCUMENT" ] && [ -f "$SPRINT_DIR/requirements-subject.md" ]; then
  B4_MF="$SPRINT_DIR/requirements-subject.md"
  B4_FIRST="$(awk '/^file: / { print $3; exit }' "$B4_MF")"; B4_ROOT=""; B4_W="$(cd "$SPRINT_DIR" && pwd -P)"
  while [ -n "$B4_W" ] && [ "$B4_W" != "/" ]; do
    if [ -n "$B4_FIRST" ] && [ -f "$B4_W/$B4_FIRST" ]; then B4_ROOT="$B4_W"; break; fi
    B4_W="${B4_W%/*}"
  done
  # A manifest whose rows resolve under no parent names no file, so it refuses nothing here; the
  # subject merge itself refuses such a manifest when it is run.
  [ -n "$B4_ROOT" ] && while read -r b4_k b4_st b4_rel; do
    [ "$b4_k" = "file:" ] && [ -n "$b4_rel" ] && [ -f "$B4_ROOT/$b4_rel" ] || continue
    [ "$(cd "$(dirname "$B4_ROOT/$b4_rel")" && pwd -P)/${b4_rel##*/}" = "$DOCUMENT" ] \
      && refuse "--document $DOCUMENT is the '$b4_st' file of the requirements subject ($B4_MF); merge the subject with --subject $(basename "$SPRINT_DIR" | sed 's/^s//'), never one of its files by --document"
  done < "$B4_MF"
fi
if [ -n "$SUBJECT" ]; then
  [ "$ARTIFACT" = "requirements" ] || refuse "--subject merges s<N>/shards/requirements-p<M>/ or requirements-elicitation/, not $SHARD_BASE"
  [ "$(basename "$SPRINT_DIR")" = "s$SUBJECT" ] || refuse "$SHARD_DIR is not under s$SUBJECT/; --subject $SUBJECT names another sprint"
fi
if [ -z "$DOCUMENT" ] && [ -z "$SUBJECT" ]; then
  [ -d "$STORIES_DIR" ] || refuse "the artifact under review $STORIES_DIR is not a directory; a single-file artifact is sharded only by section, with --document"
fi

T="$(mktemp -d "${TMPDIR:-/tmp}/merge-adversarial-shards.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$T"' EXIT

sha_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

if [ -n "$SUBJECT" ]; then
# ---- the ordinal map, derived from the subject partition under the MANIFEST's base ----------
# The manifest is found beside the series (s<N>/requirements-subject.md); partition-subject.sh
# reads the base and the four paths from it alone (--manifest), so this merge derives no root,
# no trunk and no base, and a missing manifest refuses rather than being written here.
SUBJ_PS="$(cd "$(dirname "$0")" && pwd)/partition-subject.sh"
[ -f "$SUBJ_PS" ] || refuse "cannot read the subject partition: $SUBJ_PS is absent"
SUBJ_MF="$SPRINT_DIR/requirements-subject.md"
[ -f "$SUBJ_MF" ] || refuse "no subject manifest at $SUBJ_MF; the subject's first partition-subject.sh --map writes it"
SUBJ_MF="$(cd "$(dirname "$SUBJ_MF")" && pwd -P)/$(basename "$SUBJ_MF")"
if [ -n "$SUBJ_BASE" ]; then
  bash "$SUBJ_PS" --map "$SUBJECT" --manifest "$SUBJ_MF" --base "$SUBJ_BASE" > "$T/smap" 2> "$T/map.err"; prc=$?
else
  bash "$SUBJ_PS" --map "$SUBJECT" --manifest "$SUBJ_MF" > "$T/smap" 2> "$T/map.err"; prc=$?
fi
if [ "$prc" -eq 3 ]; then
  refuse "the sprint $SUBJECT subject maps to one part ($(head -1 "$T/smap")); a one-part subject is reviewed by one adversary and never merged"
fi
[ "$prc" -eq 0 ] || refuse "partition-subject.sh --map $SUBJECT exited $prc: $(head -1 "$T/map.err")"
cp "$T/smap" "$T/map" || refuse "cannot stage the ordinal map"
K="$(grep -c . "$T/map")" || K=0
[ "$K" -ge 2 ] || refuse "partition-subject.sh --map $SUBJECT printed $K part(s); a subject merge needs two or more"
W=${#K}
i=0
while IFS="$(printf '\t')" read -r o f a z h; do
  i=$((i + 1))
  case "$o" in ""|*[!0-9]*) refuse "partition-subject.sh --map printed ordinal '$o' on row $i" ;; esac
  [ "$((10#$o))" -eq "$i" ] || refuse "partition-subject.sh --map printed ordinal $o on row $i; ordinals run 1..K in order"
done < "$T/map"
# The four stems and their disk shas, in manifest order: `<stem>\t<sha>`.
SUBJ_ROOT=""
SUBJ_FIRST="$(awk '/^file: / { print $3; exit }' "$SUBJ_MF")"
_d="$(dirname "$SUBJ_MF")"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  if [ -f "$_d/$SUBJ_FIRST" ]; then SUBJ_ROOT="$_d"; break; fi
  _d="$(dirname "$_d")"
done
[ -n "$SUBJ_ROOT" ] || refuse "no directory above $SUBJ_MF holds $SUBJ_FIRST"
: > "$T/stems" || refuse "cannot stage the subject shas"
awk '/REQUIREMENTS_SUBJECT v1/ { inb = 1; next } /REQUIREMENTS_SUBJECT_END/ { inb = 0 } inb && /^file: /' "$SUBJ_MF" > "$T/mfiles" \
  || refuse "cannot read $SUBJ_MF"
while read -r _k _st _rel; do
  [ "$_k" = "file:" ] || continue
  _s="$(sha_of "$SUBJ_ROOT/$_rel")" || refuse "cannot hash $_rel"
  [[ $_s =~ ^[a-f0-9]{64}$ ]] || refuse "cannot hash $_rel"
  printf '%s\t%s\n' "$_st" "$_s" >> "$T/stems" || refuse "cannot stage the subject shas"
done < "$T/mfiles"
[ "$(grep -c . "$T/stems")" = "4" ] || refuse "$SUBJ_MF does not list four subject files"
SUBJ_SHA_LIST="$(awk -F'\t' '{ printf " %s=%s", $1, $2 }' "$T/stems")"
elif [ -n "$DOCUMENT" ]; then
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
if [ -n "$SUBJECT" ]; then UNIT_COUNT="part count of the sprint $SUBJECT subject"
elif [ -n "$DOCUMENT" ]; then UNIT_COUNT="part count of $DOCUMENT"; else UNIT_COUNT="story count of $STORIES_DIR"; fi
ORDINALS="$(cut -f1 "$T/map" | tr '\n' ' ')"
ORDINALS="${ORDINALS% }"
norm_ord() { # "003" -> 03 at width W; empty unless digits within 1..K
  case "$1" in ""|*[!0-9]*) return 0 ;; esac
  local n=$((10#$1))
  [ "$n" -ge 1 ] && [ "$n" -le "$K" ] || return 0
  printf '%0*d' "$W" "$n"
}

# ---- the cross groups, read from their one speller ----------------------------------------
# In EVERY mode the cross shards are the rows of `partition-document.sh --cross-groups <K>`, the
# sibling this merge already resolves for section mode. CROSS_KEYS is `cross` when the table has
# one row (K=2) and `cross-1 .. cross-<G>` otherwise; nothing here restates the construction.
XPART="$(cd "$(dirname "$0")" && pwd)/partition-document.sh"
[ -f "$XPART" ] || refuse "cannot read the cross groups: $XPART is absent"
bash "$XPART" --cross-groups "$K" > "$T/groups" 2> "$T/groups.err"; grc=$?
[ "$grc" -eq 0 ] || refuse "partition-document.sh --cross-groups $K exited $grc: $(head -1 "$T/groups.err")"
G="$(grep -c . "$T/groups")" || G=0
[ "$G" -ge 1 ] || refuse "partition-document.sh --cross-groups $K printed no group"
i=0
RE_GROUP='^[0-9]+(,[0-9]+)+$'   # held in a variable for bash 3.2, as RE_ISO and RE_CITED are
while IFS="$(printf '\t')" read -r gg gl; do
  i=$((i + 1))
  [ "$gg" = "$i" ] && [[ $gl =~ $RE_GROUP ]] \
    || refuse "partition-document.sh --cross-groups $K printed row $i as '$gg	$gl'; want <g>\\t<ordinal,ordinal,...> with g = 1..G in order"
done < "$T/groups"
if [ "$G" -eq 1 ]; then CROSS_KEYS="cross"
else CROSS_KEYS="$(awk '{ printf "%scross-%d", (NR > 1 ? " " : ""), NR }' "$T/groups")"; fi
CROSS_FIRST="${CROSS_KEYS%% *}"

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
  [ -f "$f" ] || refuse "$f is not a regular file; the shard directory holds only <ordinal>.md and the cross shards ($CROSS_KEYS)"
  case "$b" in
    cross.md) key="cross" ;;
    cross-*.md)
      gn="${b#cross-}"; gn="${gn%.md}"
      case "$gn" in ""|*[!0-9]*) refuse "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)" ;; esac
      key="cross-$((10#$gn))" ;;
    *.md)
      case "${b%.md}" in ""|*[!0-9]*) refuse "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)" ;; esac
      key="$(norm_ord "${b%.md}")"
      [ -n "$key" ] || refuse "$f names ordinal ${b%.md}, outside 1..$K (the $UNIT_COUNT)" ;;
    *) refuse "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)" ;;
  esac
  printf '%s\t%s\n' "$key" "$f" >> "$T/shards" || refuse "cannot stage the shard set"
done
dup="$(cut -f1 "$T/shards" | sort | uniq -d | head -1)"
[ -z "$dup" ] || refuse "shard $dup was delivered more than once in $SHARD_DIR"
# The cross shards delivered must be EXACTLY the table's: a mix of `cross.md` and `cross-<g>.md`,
# a `cross-<g>` the table does not print, or the wrong spelling for G are each refused by name.
x_plain=0; x_num=0
while IFS="$(printf '\t')" read -r xk xf; do
  case "$xk" in
    cross) x_plain=1 ;;
    cross-*) x_num=1
      case " $CROSS_KEYS " in *" $xk "*) ;; *) refuse "$xf is $xk, which partition-document.sh --cross-groups $K does not print (the cross shards for K=$K are: $CROSS_KEYS)" ;; esac ;;
  esac
done < "$T/shards"
[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \
  && refuse "$SHARD_DIR mixes cross.md with cross-<g>.md; a shard set is one cross shape or the other (for K=$K: $CROSS_KEYS)"
[ "$x_plain" -eq 1 ] && [ "$G" -gt 1 ] \
  && refuse "$SHARD_DIR holds cross.md, but the $UNIT_COUNT is $K, whose cross groups are $CROSS_KEYS; a single cross shard is owed only at K=2"
for idx in $ORDINALS $CROSS_KEYS; do
  [ -n "$(awk -F'\t' -v k="$idx" '$1 == k { print; exit }' "$T/shards")" ] || refuse "shard $idx is missing from $SHARD_DIR (expected: $ORDINALS and $CROSS_KEYS)"
done

# ---- seat-complete (the belt; the join beat's --complete is the braces) --------------------
# If ANY shard's last non-blank line is the marker, every shard's must be. See the header.
: > "$T/sc" || refuse "cannot stage the completion check"
while IFS="$(printf '\t')" read -r sk sf_; do
  if awk 'NF { l = $0 } END { exit !(l ~ /^seat-complete: /) }' "$sf_"; then printf 'Y\t%s\n' "$sk" >> "$T/sc"
  else printf 'N\t%s\t%s\n' "$sk" "$sf_" >> "$T/sc"; fi
done < "$T/shards"
if grep -q '^Y' "$T/sc" && grep -q '^N' "$T/sc"; then
  sc_bad="$(awk -F'\t' '$1 == "N" { print $3; exit }' "$T/sc")"
  refuse "$sc_bad does not end in 'seat-complete: ' while another shard in $SHARD_DIR does; that shard is unfinished (its last non-blank line must be 'seat-complete: <step> <adversary> <shard>')"
fi

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
# The ordering KEY for an invoked_at RE_ISO accepted (sets AT_KEY). It is OWNED by the convergence
# validator, whose arm G orders passes by the same key, and taken from it here as its one-line
# definition -- never restated, so the merge's earliest-shard pick and arm G cannot disagree.
n_fn="$(grep -c '^at_key() {' "$VALIDATOR")" || n_fn=0
[ "$n_fn" = "1" ] || refuse "found ${n_fn} 'at_key() {' definitions in $VALIDATOR (want exactly 1)"
eval "$(grep -m1 '^at_key() {' "$VALIDATOR")"
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

for key in $ORDINALS $CROSS_KEYS; do
  case "$key" in cross|cross-*) is_x=1 ;; *) is_x=0 ;; esac
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

  if [ "$ELICIT" -eq 1 ]; then
    # Elicitation is not a convergence pass: a verdict here would be read as one by every gate.
    [ -z "$(field "$P" verdict)" ] || refuse "$sf declares a verdict; an elicitation shard carries none"
  else
  v="$(field "$P" verdict | tr '[:lower:]' '[:upper:]' | sed -e 's/[^A-Z]\{1,\}/_/g' -e 's/^_//' -e 's/_$//')"
  case "$v" in
    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET) ;;
    DIVERGENT_HARD_BLOCK) ANY_DIVERGENT=1 ;;
    *) refuse "$sf declares verdict '${v:-<none>}', not one of EXIT_CONDITION_MET EXIT_CONDITION_NOT_MET DIVERGENT_HARD_BLOCK" ;;
  esac
  fi

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
  if [ "$ELICIT" -eq 1 ] && [ "$val" != "bmad-advanced-elicitation" ]; then
    refuse "$sf declares skill '$val'; an elicitation shard runs bmad-advanced-elicitation"
  fi
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

  if [ -n "$SUBJECT" ]; then
    # Every shard -- cross included -- notarizes ALL FOUR stems at their disk bytes, and names the
    # subject manifest. Order-free: the list is compared stem by stem.
    sha="$(field "$P" artifact_sha)"
    [ -n "$sha" ] || refuse "$sf declares no artifact_sha; a subject shard notarizes <stem>=<sha> for every subject file"
    nt=0
    for tok in $sha; do
      nt=$((nt + 1))
      st="${tok%%=*}"; sv="$(printf '%s' "${tok#*=}" | tr 'A-F' 'a-f')"
      case "$tok" in *=*) ;; *) refuse "$sf artifact_sha token '$tok' is not <stem>=<sha>" ;; esac
      want="$(awk -F'\t' -v s="$st" '$1 == s { print $2 }' "$T/stems")"
      [ -n "$want" ] || refuse "$sf artifact_sha names stem '$st', not a subject stem ($(cut -f1 "$T/stems" | tr '\n' ' '))"
      [ "$sv" = "$want" ] || refuse "$sf notarizes $st=$sv but that file is $want on disk; the shard reviewed other bytes"
    done
    [ "$nt" -eq 4 ] && [ "$(printf '%s\n' $sha | sed 's/=.*//' | sort -u | grep -c .)" -eq 4 ] \
      || refuse "$sf artifact_sha carries $nt token(s); a subject shard notarizes each of the four stems once"
    art="$(field "$P" artifact)"
    [ -n "$art" ] || refuse "$sf declares no artifact; a subject shard names the subject manifest"
    resolve_artifact "$art"
    [ "$ART_ABS" = "$SUBJ_MF" ] \
      || refuse "$sf names artifact '$art', which resolves to ${ART_ABS:-nothing}, not the subject manifest $SUBJ_MF"
    if [ "$key" = "$CROSS_FIRST" ]; then CROSS_ID="$tid"; CROSS_ARTIFACT="$art"; fi
  elif [ -n "$DOCUMENT" ]; then
    # Every shard -- cross included -- reviewed the WHOLE document's bytes, so every shard
    # notarizes the one whole-document sha and names the one document.
    sha="$(field "$P" artifact_sha)"
    [ "$sha" = "$DOC_SHA" ] || refuse "$sf notarizes ${sha:-<none>} but $DOCUMENT is $DOC_SHA on disk; the shard reviewed other bytes"
    art="$(field "$P" artifact)"
    [ -n "$art" ] || refuse "$sf declares no artifact; a section shard names the document it reviewed"
    resolve_artifact "$art"
    [ "$ART_ABS" = "$DOCUMENT" ] \
      || refuse "$sf names artifact '$art', which resolves to ${ART_ABS:-nothing}, not --document $DOCUMENT; the shard reviewed another file"
    if [ "$key" = "$CROSS_FIRST" ]; then CROSS_ID="$tid"; CROSS_ARTIFACT="$art"; fi
    mt="$(date -u -r "$sf" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
    [[ $mt =~ $RE_ISO ]] || refuse "cannot read the modification time of $sf"
    WALL_LIST="$WALL_LIST $key=$at/$mt"
  elif [ "$is_x" -eq 1 ]; then
    xa="$(field "$P" artifact)"
    [ -n "$xa" ] || refuse "$sf (cross-story) declares no artifact"
    if [ "$key" = "$CROSS_FIRST" ]; then CROSS_ID="$tid"; CROSS_ARTIFACT="$xa"
    else [ "$xa" = "$CROSS_ARTIFACT" ] || refuse "$sf (cross-story) names artifact '$xa' where $CROSS_FIRST names '$CROSS_ARTIFACT'"; fi
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
    if [ "$is_x" -eq 1 ]; then
      [ $# -ge 2 ] || refuse "$sf:$line (cross-$NOUN shard) cites only$distinct; a cross-$NOUN finding cites two or more ordinals, a single-$NOUN one belongs to that $NOUN shard"
      # THE OWNER RULE: the one group --cross-owner names, never any other that also covers it.
      own="$(bash "$XPART" --cross-owner "$K" "$(printf '%s' "${distinct# }" | tr ' ' ',')" 2> "$T/own.err")" \
        || refuse "partition-document.sh --cross-owner $K on$distinct failed: $(head -1 "$T/own.err")"
      [ "$G" -eq 1 ] && ownk="cross" || ownk="cross-$own"
      [ "$ownk" = "$key" ] \
        || refuse "$sf:$line ($key) cites$distinct, a finding owned by $ownk (partition-document.sh --cross-owner); a cross shard reports only the findings it owns, or the summed counts depend on the cover"
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
  # One header per cross GROUP: `cross-story` at G=1 (the bytes before cross groups existed),
  # `cross-story group <g> (<ordinals>)` otherwise, so a reader sees which pairs each group saw.
  xh=""
  if [ "$is_x" -eq 1 ] && [ "$key" != "cross" ]; then
    xh=" group ${key#cross-} ($(awk -F'\t' -v g="${key#cross-}" '$1 == g { print $2; exit }' "$T/groups"))"
  fi
  if [ -n "$SUBJECT" ]; then
    if [ "$is_x" -eq 1 ]; then printf '\n## Shard: cross-part%s\n\n' "$xh" >> "$T/body" || refuse "cannot stage the merged body"
    else printf '\n## Shard: part %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  elif [ -n "$DOCUMENT" ]; then
    if [ "$is_x" -eq 1 ]; then printf '\n## Shard: cross-section%s\n\n' "$xh" >> "$T/body" || refuse "cannot stage the merged body"
    else printf '\n## Shard: section %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  elif [ "$is_x" -eq 1 ]; then printf '\n## Shard: cross-story%s\n\n' "$xh" >> "$T/body" || refuse "cannot stage the merged body"
  else printf '\n## Shard: story %s\n\n' "$key" >> "$T/body" || refuse "cannot stage the merged body"; fi
  # The provenance block and the seat-complete marker are both stripped: the merged file carries
  # one block of its own, and a marker inside it would read as the merge's own completion line.
  awk '/SKILL_INVOCATION_PROVENANCE v1/ { skip = 1; next }
       /SKILL_INVOCATION_PROVENANCE_END/ { skip = 0; next }
       !skip && !/^seat-complete: /' "$sf" >> "$T/body" || refuse "cannot stage the body of $sf"
done

if grep -q 'SKILL_INVOCATION_PROVENANCE' "$T/body"; then
  refuse "a shard body mentions SKILL_INVOCATION_PROVENANCE outside its block; the merged file must carry exactly one"
fi

BLOCKING=$((S_MAJOR - S_UNDER))
if [ "$ANY_DIVERGENT" -eq 1 ]; then VERDICT="DIVERGENT_HARD_BLOCK"
elif [ "$S_CRIT" -le "$CRIT_CEIL" ] && [ "$BLOCKING" -le "$MAJOR_CEIL" ]; then VERDICT="EXIT_CONDITION_MET"
else VERDICT="EXIT_CONDITION_NOT_MET"; fi

{
  if [ "$ELICIT" -eq 1 ]; then
  printf '# %s -- advanced elicitation (merged from %s shards)\n' "$ARTIFACT" "$(wc -l < "$T/shards" | tr -d ' ')"
  printf '\nMerged by merge-adversarial-shards.sh --elicitation; elicitation is not a convergence pass and carries no verdict.\n'
  else
  printf '# %s -- adversarial pass %s (merged from %s shards)\n' "$ARTIFACT" "$PASS" "$(wc -l < "$T/shards" | tr -d ' ')"
  printf '\nVerdict RECOMPUTED by merge-adversarial-shards.sh from the summed residue; shard verdicts are advisory.\n'
  fi
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
  if [ -n "$SUBJECT" ]; then
    printf 'artifact_sha:%s\n' "$SUBJ_SHA_LIST"
  elif [ -n "$DOCUMENT" ]; then
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
  [ "$ELICIT" -eq 1 ] || printf 'verdict: %s\n' "$VERDICT"
  printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
} > "$T/out" || refuse "cannot stage the merged pass file"

if [ -e "$OUT" ]; then
  if cmp -s "$T/out" "$OUT"; then
    printf 'UNCHANGED: %s verdict=%s\n' "$OUT" "$VERDICT"; exit 0
  fi
  refuse "$OUT already exists and differs from this merge; a pass file is never overwritten"
fi
cp "$T/out" "$OUT.merge-tmp.$$" && mv "$OUT.merge-tmp.$$" "$OUT" || refuse "writing $OUT failed"
if [ "$ELICIT" -eq 1 ]; then
  printf 'MERGED: %s elicitation shards=%s critical=%s major=%s minor=%s (no verdict)\n' \
    "$OUT" "$(wc -l < "$T/shards" | tr -d ' ')" "$S_CRIT" "$S_MAJOR" "$S_MINOR"
  exit 0
fi
printf 'MERGED: %s verdict=%s shards=%s critical=%s major=%s underived=%s blocking=%s ceiling=%s\n' \
  "$OUT" "$VERDICT" "$(wc -l < "$T/shards" | tr -d ' ')" "$S_CRIT" "$S_MAJOR" "$S_UNDER" "$BLOCKING" "$MAJOR_CEIL"
exit 0
