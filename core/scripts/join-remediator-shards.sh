#!/bin/bash
#
# join-remediator-shards.sh -- the deterministic JOIN for a sharded adversarial repair.
#
# A repair pass may be split across several remediators only on DISJOINT FILE SETS, edited in
# place. This script is what makes that disjointness a measured fact rather than a promise in a
# dispatch brief: it reads the planning-artifact write ledger that
# `ai-dlc-gate-remediation-guard.sh` appends on every dispatched agent's Edit/Write/MultiEdit
# (`<state>/planning-artifacts/.artifact-writes.jsonl`, rows `kind: "artifact-write"`), and it
# REFUSES when any file under the artifact was written by more than one distinct `agent_id`
# inside the repair window. Only then does it concatenate the shard repair records into the one
# record every existing reader globs for.
#
# USAGE
#   join-remediator-shards.sh --sprint <N> --artifact <name> --pass <M> \
#       --artifact-path <path under the project root> --since <ISO> --until <ISO>
#
#   --artifact        the artifact NAME, as in `<artifact>-repair-p<M>.md` (e.g. `stories`)
#   --artifact-path   the SPRINT SLOT, relative to the project root, in the ledger's own spelling
#                     (`_bmad-output/planning-artifacts/s172`). A stories repair edits the stories
#                     AND their slot siblings -- `epics/epics.md` above all -- so the slot, not
#                     `s<N>/stories`, is the set of files a repair may write. One directory the
#                     ledger already spells, never a hand-listed set of paths: the file set stays
#                     DERIVED from the ledger. Files outside the slot (`docs/`, a top-level
#                     `planning-artifacts/prd.md`) are not a stories repair's to edit, and a part
#                     citing one is refused as a claimed edit with no write.
#   --since/--until   the repair window, `YYYY-MM-DDTHH:MM:SSZ`, inclusive both ends. Explicit
#                     and required: an mtime or a "last N minutes" default is a window the
#                     filesystem or the clock can move.
#
# READS   <state>/planning-artifacts/.artifact-writes.jsonl
#         <state>/planning-artifacts/s<N>/shards/<artifact>-repair-p<M>/*.md   (placement rule P1)
#         NOT `shards/<artifact>-p<M>/`: that directory holds the ADVERSARY shards for the review
#         of the same pass, and `merge-adversarial-shards.sh` refuses any entry in it that is not
#         `<digits>.md` or `cross.md`. The two programs never share a directory.
# WRITES  <state>/planning-artifacts/s<N>/<artifact>-repair-p<M>.md       (placement rule P5)
#
# EXIT  0 joined; 2 REFUSED (one `REFUSED:` line on stderr per reason, nothing written).
#
# WHAT IT REFUSES, AND THE ORDER IS NOT SIGNIFICANT -- every reason is reported:
#   - an empty shard directory (a glob that matched nothing is not a join of zero parts);
#   - no ledger, or no ledger row under the artifact in the window (disjointness unproven);
#     a row under `s<N>/shards/` is a shard's OWN record (a remediator writing its part, or an
#     adversary its shard), never an artifact write, and is dropped from the file set first --
#     otherwise every part a remediator writes reads as a written file no part cites;
#   - any file under the artifact written by two or more distinct agent_ids in the window;
#   - a written file that no part's `edit:` lines cite (the missing shard -- the file set is
#     DERIVED from the ledger, never passed in);
#   - a file cited by two parts, or one part citing files written by two different agents;
#   - a part citing a file no agent wrote in the window -- including a write whose ledger row
#     was lost, because the hook's append is silent on failure and this is where that surfaces;
#   - a part that arm H would not read as structured on its own (see below);
#   - an existing `<artifact>-repair-p<M>.md` (a join never overwrites a record).
#
# PARTS ARE KEYED ON THE FILES THEY CITE, NEVER ON AN AGENT ID THEY REPORT. The ledger's
# `agent_id` is the harness's attribution and no dispatched model is shown it, so the join
# compares harness ids only with harness ids, and joins a part to a writer through the files the
# part's `edit:` lines name. A cited token is a path-shaped run ending in a document extension
# (`:<line>` suffixes and prose fall away); an absolute one under the state dir's parent is cut to
# the ledger's spelling; then it resolves to the written file it equals or is a `/`-suffix of.
# Only the `edit:` line is read; a wrapped citation names a file that reads UNCITED -- a refusal.
#
# "STRUCTURED IFF EVERY PART IS". Arm H of `validate-adversarial-convergence.sh` reads a record as
# structured when each of `disposition:`, `edit:`, `derivation:` opens a line ANYWHERE in it, so a
# concatenation of one structured part and one narrative part reads structured. The join therefore
# tests EVERY part and refuses if any fails, and it tests with arm H's own `repair_field()`,
# extracted from the sibling and evaluated -- the same move `check-24-adversarial-convergence` and
# `validate-gate-adjudication.sh` make -- so the predicate cannot drift from the gate's.
#
# WHAT IT CANNOT SEE. A remediator that edited nothing AND delivered no part is invisible: the
# file set is derived from edits, and an agent with none contributes nothing to it. A part that
# cites no file at all is accepted (an all-escalated shard is legitimate). The ledger rows
# are PreToolUse attempts, not completed writes, so an attempted overlap refuses -- the
# conservative direction. Writes made through Bash reach no Edit matcher and no ledger row.
# The slot is wide on purpose, so ANY other dispatched agent writing in it inside the window is
# an uncited file and a refusal: the window must be the repair window alone.
#
# NOT A MODE OF THE ADVERSARY MERGE. A separate program on purpose: the adversary-shard fix and
# this one close different backlog entries, and a shared mode would let either close both.
#
# DOCUMENT MODE -- ONE DOCUMENT REPAIRED BY SECTION.
#   join-remediator-shards.sh --document <path> <repair-dir> --since <ISO> --until <ISO>
#   (--sprint/--artifact/--pass may replace or accompany <repair-dir>; when both are given the
#   dir must be the one the flags name. Omitted flags are read off `s<N>/shards/<artifact>-repair-p<M>`.)
#
#   The lead has run `partition-document.sh --split <doc> <repair-dir>`, so the repair dir holds
#   `sections/<ordinal>.md` (the copies each remediator edits) and `sections/.manifest`. Each
#   remediator edits ONLY its `sections/<i>.md` and writes its part `<repair-dir>/<i>.md`, whose
#   `edit:` lines cite the section file. What changes, and nothing else does:
#   - THE FILE SET is the ledger rows under `<repair-dir>/sections/`. Files mode drops every row
#     under `s<N>/shards/` (a shard's own record); here those section rows ARE the artifact writes,
#     so the shards exclusion does not apply and `--artifact-path` is refused -- the sections dir
#     is the path. Distinct-writer, UNWRITTEN, AMBIG, UNCITED, DOUBLE and SPAN are the same code.
#   - PARTS stay `<repair-dir>/*.md`, non-recursive, so no section copy is ever read as a part.
#   - `--document` must be the manifest's `document` (both resolved to a physical absolute path;
#     a relative `--document` is taken under the project root). `<repair-dir>`, when given, must
#     be the dir the flags name -- it is accepted so a caller can spell what it split into.
#   - ASSEMBLY RUNS BEFORE THE RECORD IS WRITTEN. After every refusal above has cleared, the join
#     runs the sibling `partition-document.sh --assemble <repair-dir>`; if that refuses (the
#     document moved in place, a section is missing or foreign, a section lost its trailing
#     newline) the join exits 2 with its line and writes NOTHING. A re-run after a record-write
#     failure is safe: the assembler answers UNCHANGED for a document it already assembled.
#   Files mode also refuses a repair dir that carries `sections/.manifest`: its section writes are
#   under shards/ and would all be dropped, so a files-mode join would record a repair whose
#   document was never assembled.

set -u
export LC_ALL=C

refuse_n=0
refuse() { echo "REFUSED: $*" >&2; refuse_n=$((refuse_n + 1)); }
die() { echo "REFUSED: $*" >&2; exit 2; }

SPRINT=""; ARTIFACT=""; PASS=""; APATH=""; SINCE=""; UNTIL=""; DOCUMENT=""; REPDIR=""; DOCMODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    --artifact) ARTIFACT="${2:-}"; shift 2 ;;
    --pass) PASS="${2:-}"; shift 2 ;;
    --artifact-path) APATH="${2:-}"; shift 2 ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --until) UNTIL="${2:-}"; shift 2 ;;
    --document) DOCUMENT="${2:-}"; DOCMODE=1; shift 2 ;;
    -h|--help) sed -n '2,105p' "$0"; exit 0 ;;
    -*) die "unknown argument '$1' (see --help)" ;;
    *) [ "$DOCMODE" = 1 ] && [ -z "$REPDIR" ] || die "unknown argument '$1' (see --help)"
       REPDIR="$1"; shift ;;
  esac
done

# Document mode may name the repair dir instead of the three flags: `.../s<N>/shards/<artifact>-repair-p<M>`.
if [ "$DOCMODE" = 1 ] && [ -n "$REPDIR" ]; then
  _rb="$(basename "${REPDIR%/}")"; _rs="$(basename "$(dirname "$(dirname "${REPDIR%/}")")")"
  case "$_rb" in *-repair-p*) ;; *) die "the repair dir ${REPDIR} is not named <artifact>-repair-p<M>" ;; esac
  [ -n "$ARTIFACT" ] || ARTIFACT="${_rb%-repair-p*}"
  [ -n "$PASS" ] || PASS="${_rb##*-repair-p}"
  [ -n "$SPRINT" ] || SPRINT="$_rs"
fi
SPRINT="${SPRINT#s}"
case "$SPRINT" in ''|*[!0-9]*) die "--sprint must be a sprint number (got '${SPRINT}')" ;; esac
case "$PASS" in ''|*[!0-9]*) die "--pass must be a pass number (got '${PASS}')" ;; esac
case "$ARTIFACT" in ''|*/*) die "--artifact must be a bare artifact name (got '${ARTIFACT}')" ;; esac
if [ "$DOCMODE" = 1 ]; then
  [ -n "$DOCUMENT" ] || die "--document needs a path"
  [ -z "$APATH" ] || die "--artifact-path does not apply with --document; the file set is the repair dir's sections/"
else
  [ -n "$APATH" ] || die "--artifact-path is required"
fi
APATH="${APATH%/}"
ISO='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'
# shellcheck disable=SC2254
case "$SINCE" in $ISO) ;; *) die "--since must be YYYY-MM-DDTHH:MM:SSZ (got '${SINCE}')" ;; esac
# shellcheck disable=SC2254
case "$UNTIL" in $ISO) ;; *) die "--until must be YYYY-MM-DDTHH:MM:SSZ (got '${UNTIL}')" ;; esac
[ "$SINCE" \> "$UNTIL" ] && die "--since ${SINCE} is after --until ${UNTIL}"
command -v jq >/dev/null 2>&1 || die "jq is not on PATH; the ledger cannot be read"

# --- AI_DLC_ROOT ------------------------------------------------------------
# Walk UP for a marker, never count `..` hops. The canonical block, precedence bound by I75:
# override -> walk up from this script -> CLAUDE_PROJECT_DIR -> walk up from cwd -> exit 2.
# Inline on purpose: locating a shared lib is the same unsolved problem.
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
JR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JR_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$JR_ROOT" ] || JR_ROOT="$(ai_dlc_resolve_root "$JR_SCRIPT_DIR" || true)"
[ -n "$JR_ROOT" ] || JR_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$JR_ROOT" ] || JR_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$JR_ROOT" ] || {
  echo "REFUSED: cannot resolve the project root from ${JR_SCRIPT_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

_STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"
case "$_STATE_DIR" in /*) STATE="$_STATE_DIR" ;; *) STATE="${JR_ROOT}/${_STATE_DIR}" ;; esac
STATE="${STATE%/}"
# The state dir's PARENT, logical and physical, slash-terminated: an absolute citation under it
# is cut to the ledger's `<state-dir-name>/...` spelling (the token loop below). Never the root:
# a nested or absolute state dir has a parent that is not the root. `pwd` collapses the `//` a
# trailing-slash root leaves in STATE; `pwd -P` is the spelling a resolved symlink gives.
STATE_PARENT="${STATE%/*}/"; STATE_PARENT_P="$STATE_PARENT"
if _sl="$(cd "$STATE" 2>/dev/null && pwd)"; then STATE_PARENT="${_sl%/*}/"; fi
if _sp="$(cd "$STATE" 2>/dev/null && pwd -P)"; then STATE_PARENT_P="${_sp%/*}/"; fi
PA="${STATE}/planning-artifacts"
LEDGER="${PA}/.artifact-writes.jsonl"
SHARD_DIR="${PA}/s${SPRINT}/shards/${ARTIFACT}-repair-p${PASS}"
OUT="${PA}/s${SPRINT}/${ARTIFACT}-repair-p${PASS}.md"
# The shards root in the LEDGER's spelling: the hook writes `<basename of the state dir>/...`
# (its STATE_DIR_NAME), so this is derived the same way, whether AI_DLC_STATE_DIR is absolute or not.
SHARD_REL="${_STATE_DIR##*/}/planning-artifacts/s${SPRINT}/shards"
MANIFEST="${SHARD_DIR}/sections/.manifest"
phys() { # <path> -> physical absolute path of an existing file or dir, rc 1 if its parent is gone
  local d b
  if [ -d "$1" ]; then (cd "$1" 2>/dev/null && pwd -P); return; fi
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
  b="$(basename "$1")"; printf '%s/%s\n' "$d" "$b"
}
if [ "$DOCMODE" = 1 ]; then
  # The section copies are the file set, in the ledger's spelling.
  APATH="${SHARD_REL}/${ARTIFACT}-repair-p${PASS}/sections"
  PARTITION="${JR_SCRIPT_DIR}/partition-document.sh"
  [ -f "$PARTITION" ] || die "partition-document.sh is not beside this script (${PARTITION}); reinstall ai-dlc"
  [ -f "$MANIFEST" ] || die "no split manifest at ${MANIFEST}; run partition-document.sh --split <doc> ${SHARD_DIR} before dispatching the section remediators"
  case "$DOCUMENT" in /*) ;; *) DOCUMENT="${JR_ROOT}/${DOCUMENT}" ;; esac
  [ -f "$DOCUMENT" ] || die "--document ${DOCUMENT} is not a file"
  DOC_ABS="$(phys "$DOCUMENT")" || die "cannot resolve --document ${DOCUMENT}"
  MF_DOC="$(awk -F'\t' '$1 == "document" { print $2; exit }' "$MANIFEST")"
  [ "$DOC_ABS" = "$MF_DOC" ] || die "--document ${DOC_ABS} is not the document ${MANIFEST} was split from (${MF_DOC:-none recorded})"
  if [ -n "$REPDIR" ]; then
    _rd="$(phys "$REPDIR")" || die "the repair dir ${REPDIR} does not exist"
    _sd="$(phys "$SHARD_DIR")" || die "the repair dir ${SHARD_DIR} does not exist"
    [ "$_rd" = "$_sd" ] || die "the repair dir ${REPDIR} is not ${SHARD_DIR}, the one --sprint/--artifact/--pass name"
  fi
else
  [ -e "$MANIFEST" ] && die "${SHARD_DIR} was split by section (${MANIFEST}); join it with --document, or its document is never assembled"
fi

# Arm H's own predicate, from the sibling. Same dir in both layouts (core/scripts/ and
# scripts/ai-dlc/ each hold both files), so no walk from one core file to another.
SIBLING="${JR_SCRIPT_DIR}/validate-adversarial-convergence.sh"
[ -f "$SIBLING" ] || die "arm H's validator is not beside this script (${SIBLING}); reinstall ai-dlc"
n_fn="$(grep -c '^repair_field() {' "$SIBLING")" || n_fn=0
[ "$n_fn" = "1" ] || die "found ${n_fn} 'repair_field() {' definitions in ${SIBLING} (want exactly 1)"
eval "$(grep -m1 '^repair_field() {' "$SIBLING")"

# --- the parts. A glob that matches nothing is a refusal, never a join of zero parts.
PARTS=""
for p in "$SHARD_DIR"/*.md; do
  [ -f "$p" ] || continue
  PARTS="${PARTS}${p}
"
done
PARTS="$(printf '%s' "$PARTS" | sort)"
[ -n "$PARTS" ] || die "no shard records at ${SHARD_DIR}/*.md"

# --- the ledger: per-file distinct writers inside the window, under the artifact path.
[ -f "$LEDGER" ] || die "no write ledger at ${LEDGER}; disjointness cannot be proven"
ROWS="$(jq -rn --arg since "$SINCE" --arg until "$UNTIL" --arg ap "$APATH" --arg sh "$SHARD_REL" --arg doc "$DOCMODE" '
  [inputs | select(type == "object") | select(.kind == "artifact-write")
   | select((.agent_id // "") != "") | select((.ts | type) == "string")
   | select(.ts >= $since and .ts <= $until)
   | select(.path == $ap or (.path | startswith($ap + "/")))
   | select($doc == "1" or ((.path | startswith($sh + "/")) | not))
   | [.path, .agent_id]] | unique | .[] | @tsv' "$LEDGER" 2>/dev/null)" \
  || die "the write ledger ${LEDGER} does not parse as JSON lines"
[ -n "$ROWS" ] || die "the ledger records no dispatched write under ${APATH} in [${SINCE}, ${UNTIL}]; disjointness is unproven"

OVERLAPS="$(printf '%s\n' "$ROWS" | awk -F'\t' '
  { n[$1]++; w[$1] = (w[$1] == "" ? $2 : w[$1] ", " $2) }
  END { for (f in n) if (n[f] > 1) print f "\t" w[f] }' | sort)"
if [ -n "$OVERLAPS" ]; then
  while IFS='	' read -r f w; do
    refuse "${f} was written by more than one agent in the window: ${w}"
  done <<OVEOF
$OVERLAPS
OVEOF
fi
WRITERS="$(printf '%s\n' "$ROWS" | awk -F'\t' '{print $2}' | sort -u)"

# --- each part: structured by arm H's own reading, and the FILES its `edit:` lines cite.
# The part is keyed on what it says it EDITED, never on an agent id it reports about itself:
# the ledger's `agent_id` is the harness's attribution, which no dispatched model is shown, so a
# self-reported id could only ever match it by luck (measured on the reference consumer: 1 of 29
# verdict stems carried an `adjudicator_agent_id` equal to the harness id that wrote it).
# A cited token is a path-shaped run ending in a document extension; a `:<line>` suffix, prose
# and backticks around it fall away because the token grammar cannot spell them.
CITES=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  for fld in disposition edit derivation; do
    repair_field "$fld" "$p" || refuse "$(basename "$p") has no '${fld}:' field as arm H reads it; the joined record would read structured on another part's labels"
  done
  # A run of slashes in a cited token is squeezed to one before the strip below: a TMPDIR ending in
  # `/` spells every path under it `T//x`, while STATE_PARENT comes from `pwd`, which collapses it,
  # so the literal prefix strip never matched and an absolute citation under the root refused.
  _toks="$(awk '
    /^[[:space:]-]*[*_`]*edit[*_`]*:/ {
      line = $0; sub(/^[^:]*:/, "", line)
      while (match(line, /[A-Za-z0-9_.\/-]+[.](md|json|jsonl|yaml|yml|txt|csv)/)) {
        tok = substr(line, RSTART, RLENGTH); gsub(/\/\/+/, "/", tok); print tok
        line = substr(line, RSTART + RLENGTH)
      }
    }' "$p" | sort -u)"
  while IFS= read -r _t; do
    [ -n "$_t" ] || continue
    _t="${_t#"$STATE_PARENT"}"; _t="${_t#"$STATE_PARENT_P"}"
    CITES="${CITES}C	$(basename "$p")	${_t}
"
  done <<TOKEOF
$_toks
TOKEOF
done <<PAREOF
$PARTS
PAREOF

# THE COVERAGE JOIN. Ledger side: file -> writers (harness ids). Part side: part -> cited files.
# A cited token resolves to the ledger path it equals or is a `/`-suffix of, so a bare basename,
# a `stories/<file>` spelling and a full `_bmad-output/...` path all land on the same file.
#   UNWRITTEN  a part cites a file no agent wrote under the artifact in the window. This is also
#              how a LOST LEDGER ROW surfaces: the hook's append is silent on failure (it must
#              never block the Edit), so a write it failed to record reads here as a claimed
#              edit with no write, and the join refuses rather than acquits.
#   AMBIG      a cited token matches more than one written file -- the citation names no file.
#   UNCITED    a written file no part cites: its writer delivered no record (the missing shard).
#   DOUBLE     one written file cited by two parts: two records claim one region.
#   SPAN       one part cites files written by two different agents: the part is not one shard.
JOINRES="$({ printf '%s\n' "$ROWS" | awk -F'\t' 'NF >= 2 { print "W\t" $1 "\t" $2 }'
             printf '%s' "$CITES"; } | awk -F'\t' '
  $1 == "W" { if (!($2 in wr)) { np++; P[np] = $2 }
              if (!(($2, $3) in ws)) { ws[$2, $3] = 1; wr[$2] = ($2 in wr) ? wr[$2] " " $3 : $3 }
              next }
  $1 == "C" { part = $2; tok = $3; n = 0; hit = ""
              for (i = 1; i <= np; i++) {
                p = P[i]
                if (p == tok || (length(p) > length(tok) && substr(p, length(p) - length(tok)) == "/" tok)) {
                  n++; hit = (hit == "" ? p : hit " " p) }
              }
              if (n == 0) { print "UNWRITTEN\t" part "\t" tok; next }
              if (n > 1)  { print "AMBIG\t" part "\t" tok "\t" hit; next }
              if (!((hit, part) in cs)) { cs[hit, part] = 1; cov[hit] = (hit in cov) ? cov[hit] " " part : part; ncov[hit]++ }
              k = split(wr[hit], a, " ")
              for (j = 1; j <= k; j++) if (!((part, a[j]) in pw)) {
                pw[part, a[j]] = 1; npw[part]++; pwl[part] = (part in pwl) ? pwl[part] " " a[j] : a[j] }
              next }
  END {
    for (i = 1; i <= np; i++) {
      p = P[i]
      if (!(p in cov)) print "UNCITED\t" p "\t" wr[p]
      else if (ncov[p] > 1) print "DOUBLE\t" p "\t" cov[p]
    }
    for (q in npw) if (npw[q] > 1) print "SPAN\t" q "\t" pwl[q]
  }' | sort)"

if [ -n "$JOINRES" ]; then
  while IFS='	' read -r kind a b c; do
    case "$kind" in
      UNWRITTEN) refuse "${a} cites ${b}, which no dispatched agent wrote under ${APATH} in the window -- the file was written through Bash or another tool that reaches no Edit matcher, or it was never written; re-dispatch that shard writing through Edit, Write or MultiEdit" ;;
      AMBIG)     refuse "${a} cites ${b}, which matches more than one written file (${c}); cite the path, not the basename" ;;
      UNCITED)   refuse "${a} was written in the window by ${b} and is cited by no shard record -- a missing shard" ;;
      DOUBLE)    refuse "${a} is cited by more than one shard record (${b}); one file belongs to one shard" ;;
      SPAN)      refuse "${a} cites files written by more than one agent (${b}); a shard record covers one writer's files" ;;
    esac
  done <<JREOF
$JOINRES
JREOF
fi

[ -e "$OUT" ] && refuse "${OUT} already exists; a join never overwrites a repair record"

[ "$refuse_n" -eq 0 ] || exit 2

# --- document mode: assemble BEFORE the record. A refusal here writes nothing -- the assembler
# refuses without touching the document, and no record is written after it.
ASM_LINE=""
if [ "$DOCMODE" = 1 ]; then
  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)" || {
    printf '%s\n' "$ASM_LINE" >&2
    die "the sections of ${DOC_ABS} did not assemble; no repair record was written"
  }
fi

# --- write the single record every reader globs for.
TMP="${OUT}.join.$$"
{
  echo "# ${ARTIFACT} repair — sprint ${SPRINT}, pass ${PASS} (joined from $(printf '%s\n' "$PARTS" | grep -c .) shard records)"
  echo ""
  echo "Joined by join-remediator-shards.sh from ${SHARD_DIR#"${JR_ROOT}"/}; window ${SINCE} .. ${UNTIL};"
  if [ "$DOCMODE" = 1 ]; then
    echo "every section under ${APATH} was written by exactly one agent in that window;"
    echo "partition-document.sh: ${ASM_LINE}"
  else
    echo "every file under ${APATH} outside ${SHARD_REL}/ was written by exactly one agent in that window."
  fi
  echo ""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    echo "<!-- shard: $(basename "$p") -->"
    cat "$p"
    echo ""
  done <<CATEOF
$PARTS
CATEOF
} > "$TMP" || { echo "REFUSED: could not write ${TMP}" >&2; exit 2; }
mv "$TMP" "$OUT" || { echo "REFUSED: could not move the joined record into ${OUT}" >&2; exit 2; }
echo "JOINED: ${OUT} ($(printf '%s\n' "$PARTS" | grep -c .) parts, $(printf '%s\n' "$WRITERS" | grep -c .) writers)"
exit 0
