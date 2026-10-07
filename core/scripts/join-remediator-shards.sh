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
#   - THE RECORD opens with `- artifact:` (the document, root-relative), `- artifact_sha_before:`
#     (the sha the split recorded in the manifest) and `- artifact_sha_after:` (the assembled
#     document, re-hashed), so arm J2 reads the join as one repair link. The serial cross-section
#     remediator appends its own triple after it, its before equal to this after.
#   Files mode also refuses a repair dir that carries `sections/.manifest`: its section writes are
#   under shards/ and would all be dropped, so a files-mode join would record a repair whose
#   document was never assembled.
#
# SUBJECT MODE -- THE REQUIREMENTS SUBJECT REPAIRED BY PART.
#   join-remediator-shards.sh --subject <N> --pass <M>|party|elicitation [--artifact gate-<type>]
#       [<repair-dir>] [--base <sha>] --since <ISO> --until <ISO>
#
#   The lead has run `partition-subject.sh --split <N> <repair-dir>`, which wrote
#   `<repair-dir>/.subject` (every part: its stem, its file, its section copy or `-` for a
#   WHOLE-FILE part) and `<repair-dir>/<stem>/sections/` for every stem mapped into sections.
#     --pass <M>           <repair-dir> s<N>/shards/requirements-repair-p<M>/  -> s<N>/requirements-repair-p<M>.md
#     --pass party         s<N>/shards/requirements-party-repair/       -> s<N>/requirements-party-repair.md
#     --pass elicitation   s<N>/shards/requirements-elicitation-repair/ -> s<N>/requirements-elicitation-repair.md
#     --artifact gate-<type> --pass <M>   (the requirements gate's FAILURE repair; <M> numeric)
#                          s<N>/shards/gate-<type>-repair-p<M>/ -> s<N>/gate-<type>-repair-p<M>.md,
#                          the non-subject path's own naming, so arm H never reads it as an
#                          adversarial pass's repair.
#   The party and elicitation records sit OUTSIDE `*-repair-p<M>.md`, so neither can stand in for
#   an adversarial pass's repair record in arm H.
#   What changes, and nothing else does:
#   - THE FILE SET is the four subject files, the spec kernel's sibling `.memlog.md` (the SPEC's
#     owner repairs through `bmad-spec`, which writes both), and the section copies `.subject`
#     names. Ledger rows anywhere else are not this join's. Slot confinement is not applied: the
#     subject spans `planning-artifacts/`, `planning-artifacts/s<N>/` and `specs/s<N>/`.
#   - A SECTIONED file written in place is REFUSED by name: its parts edit section copies, and
#     a write to the file itself is a write to out-of-scope text (the assembler would refuse it
#     too, as a moved document; this says which file and who). A subject file with NO part in
#     the split -- unchanged since the base -- written in the window is refused the same way.
#   - The manifest the split recorded must be the sprint's subject manifest, and `--base`, when
#     given, must equal its base: the base is read, never re-chosen.
#   - ASSEMBLY (`partition-subject.sh --assemble`) runs after every refusal has cleared and
#     before the record is written; WHOLE-FILE parts are never reassembled. The record opens with
#     `- artifact:` (the manifest) and per-stem `- artifact_sha_before:` / `- artifact_sha_after:`
#     lists, every stem on both sides.
#   Distinct-writer, UNWRITTEN, AMBIG, UNCITED, DOUBLE and SPAN are the same code.
#
# PARTY REPAIRS -- EVERY ENTRY NAMES THE SEAT FINDING IT APPLIES (BL-462).
#   A party round's seats write findings and edit nothing; one repair writer applies them. So a
#   party repair is joined like any other repair, and in addition every entry carries
#   `source: <seat-file>#<finding-id>` naming the seat finding it applied. A party repair is:
#     --subject <N> --pass party                          (the requirements subject)
#     --artifact <name>-party --pass 1 [files | --document]  (seats x parts, seats x sections)
#   and its seat files are `<state>/party-mode/s<N>/*.md`, DERIVED, never passed in. The files and
#   document forms keep the `<name>-party-repair-p1` dir and record name graph already writes, so
#   the document-mode dir parse and the derivation-capture hook's `*/shards/*-repair-p*/` section
#   exemption hold unchanged; arm H reads such a record for an adversarial series only as FOREIGN.
#
#   join-remediator-shards.sh --sources <record> --sprint <N>
#   checks one record that no join wrote -- the unsharded round's single repair writer, the
#   one-part subject, the serial remediator's appended entries -- and writes nothing.
#
#   FINDING IDS COLLIDE ACROSS SEATS (graph s317, read by src_ids below: 19 ids, `F-1` among them,
#   appear in more than one `architecture-*` seat file), so a source resolves on the PAIR (seat file, id), never the id alone. The refusals:
#   an entry carrying `disposition:` and no `source:` line; a `source:` line with no
#   `<file>.md#<id>` token; a token whose file is not a seat file of sprint <N> (a path that is not
#   a suffix of `<state>/party-mode/s<N>/<file>` names another sprint's seat); a token whose seat
#   file carries no finding of that id. A SELF-PROBE runs the resolver on a seeded pair before the
#   corpus is read: a resolving source must pass and an id another seat carries must refuse.
#
#   THE ID GRAMMAR IS GRAPH'S, MEASURED. A finding id is the first token of a `##`..`######`
#   heading, emphasis and a leading `Finding ` dropped, trailing `.`/`-` trimmed, holding a digit:
#   `## A1-1 (major) sections: 1`, `## Finding D4-1 (MAJOR) ...`, `## F-5.1 MAJOR`,
#   `## Finding 1 (minor), sections: 3`, `### F1 (MAJOR) ...`, `## X-1 — MINOR — ...`. Fenced
#   lines are skipped. Over graph's 55 seat files carrying `sections:` in s315-s317, this grammar
#   reads fewer ids than `sections:` lines on 2: one counts a `sections:` legend line, and
#   `carry-over-evaluation-architect-2.md` writes its findings as bullets with no id at all -- an
#   unattributable seat file, which is what the procedure now forbids.
#   FALSE-POSITIVE SET: ZERO, and how it got there. No real record carries `source:` yet, so the
#   set was measured on scratch copies of graph's twelve s317 party parts (architecture spine 1-8,
#   carry-over evaluation 1-4), each entry's OWN attribution rewritten as a `source:` line --
#   `### architect A1-1`, `### dev-5 F-1`, `### F-6.1 (dev)`, `### carry-over-evaluation-pm-1:F1`,
#   `### Architect-1 / TEA F-T7-01 / PM-1` (one entry, three findings: one line, three tokens) --
#   against a copy of graph's real `party-mode/s317/`. 279 entries; 278 carry 287 sources, 279 of
#   which resolve, and 217 of the 287 carry an id that ANOTHER seat file also carries, which an
#   id-only key cannot attribute. The narrowings, in order: a `Finding ` lead is dropped (`## Finding D4-1`); `.`
#   is an id character (`F-5.1`); a seat file with headings but no id is told apart from a wrong
#   id. What still refuses is graph's own attribution gap, not the grammar: 8 sources name
#   `carry-over-evaluation-architect-2.md`, whose findings are `- **MAJOR. ...**` bullets carrying
#   no id at all, and 1 entry (`### ADR-S317-9 alignment`) is an edit no seat finding asked for.
#   A heading such as `### 3.1.1 ladder` reads as an id `3.1.1`: that widens the accept set and
#   never refuses a correct source.

set -u
export LC_ALL=C

refuse_n=0
refuse() { echo "REFUSED: $*" >&2; refuse_n=$((refuse_n + 1)); }
die() { echo "REFUSED: $*" >&2; exit 2; }

SPRINT=""; ARTIFACT=""; PASS=""; APATH=""; SINCE=""; UNTIL=""; DOCUMENT=""; REPDIR=""; DOCMODE=0
SUBJMODE=0; SUBJ_BASE=""; SRCMODE=0; SRC_REC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sources) SRC_REC="${2:-}"; SRCMODE=1; shift 2 ;;
    --subject) SPRINT="${2:-}"; SUBJMODE=1; shift 2 ;;
    --base) SUBJ_BASE="${2:-}"; shift 2 ;;
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    --artifact) ARTIFACT="${2:-}"; shift 2 ;;
    --pass) PASS="${2:-}"; shift 2 ;;
    --artifact-path) APATH="${2:-}"; shift 2 ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --until) UNTIL="${2:-}"; shift 2 ;;
    --document) DOCUMENT="${2:-}"; DOCMODE=1; shift 2 ;;
    -h|--help) sed -n '2,188p' "$0"; exit 0 ;;
    -*) die "unknown argument '$1' (see --help)" ;;
    *) { [ "$DOCMODE" = 1 ] || [ "$SUBJMODE" = 1 ]; } && [ -z "$REPDIR" ] || die "unknown argument '$1' (see --help)"
       REPDIR="$1"; shift ;;
  esac
done
# A party repair: its entries must each name the seat finding they apply.
PARTY=0
if [ "$SRCMODE" = 1 ]; then
  [ "$DOCMODE$SUBJMODE" = 00 ] && [ -z "$ARTIFACT$PASS$APATH$SINCE$UNTIL$REPDIR" ] \
    || die "--sources checks one record and takes only --sprint <N>"
  [ -n "$SRC_REC" ] && [ -f "$SRC_REC" ] || die "--sources needs an existing record (got '${SRC_REC}')"
  PARTY=1
fi
[ "$SUBJMODE" = 1 ] && [ "$PASS" = party ] && [ -z "$ARTIFACT" ] && PARTY=1
if [ "$SUBJMODE" = 1 ]; then
  [ "$DOCMODE" = 0 ] || die "--subject and --document are two modes; pass one"
  GATE_ART=""
  case "$ARTIFACT" in
    "") ;;
    gate-?*) case "${ARTIFACT#gate-}" in *[!a-z0-9-]*) die "--artifact ${ARTIFACT} is not gate-<type> (lowercase, digits, hyphens)" ;; esac
             GATE_ART="$ARTIFACT" ;;
    *) die "--artifact applies with --subject only as gate-<type>, the requirements gate's failure repair; the artifact is the requirements subject" ;;
  esac
  [ -z "$APATH" ] || die "--artifact-path does not apply with --subject; the file set is the subject's"
  case "$PASS" in
    party) SUBJ_DIRNAME="requirements-party-repair"; SUBJ_RECNAME="requirements-party-repair.md" ;;
    elicitation) SUBJ_DIRNAME="requirements-elicitation-repair"; SUBJ_RECNAME="requirements-elicitation-repair.md" ;;
    ''|*[!0-9]*) die "--pass must be a pass number, party or elicitation in subject mode (got '${PASS}')" ;;
    *) SUBJ_DIRNAME="requirements-repair-p${PASS}"; SUBJ_RECNAME="requirements-repair-p${PASS}.md" ;;
  esac
  if [ -n "$GATE_ART" ]; then
    case "$PASS" in ''|*[!0-9]*) die "--artifact ${GATE_ART} names a gate repair, which needs a numeric --pass (got '${PASS}')" ;; esac
    SUBJ_DIRNAME="${GATE_ART}-repair-p${PASS}"; SUBJ_RECNAME="${GATE_ART}-repair-p${PASS}.md"
  fi
  ARTIFACT="requirements"
fi

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
case "$ARTIFACT" in *-party) PARTY=1 ;; esac
if [ "$SRCMODE" = 1 ]; then
  :
else
[ "$SUBJMODE" = 1 ] || case "$PASS" in ''|*[!0-9]*) die "--pass must be a pass number (got '${PASS}')" ;; esac
case "$ARTIFACT" in ''|*/*) die "--artifact must be a bare artifact name (got '${ARTIFACT}')" ;; esac
if [ "$SUBJMODE" = 1 ]; then
  :
elif [ "$DOCMODE" = 1 ]; then
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
fi

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

# --- PARTY SOURCES (BL-462). Every applied entry names `source: <seat-file>#<finding-id>`, and the
# pair resolves against the sprint's seat files -- never the id alone, which collides across seats.
SEAT_DIR="${STATE}/party-mode/s${SPRINT}"
# src_ids <seat file>... -> "<basename>\t<finding id>" per finding heading (grammar: the header).
src_ids() {
  awk '
    FNR == 1 { fence = 0; b = FILENAME; sub(/.*\//, "", b); print b "\t" }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^##+[ \t]/ {
      s = $0; sub(/^#+[ \t]+/, "", s); gsub(/[*`_]/, "", s); gsub(/[][]/, "", s); sub(/^[ \t]+/, "", s)
      sub(/^[Ff]inding[ \t]+/, "", s)
      if (match(s, /^[A-Za-z0-9][A-Za-z0-9.-]*/)) {
        t = substr(s, 1, RLENGTH); sub(/[.-]+$/, "", t)
        if (t ~ /[0-9]/) print b "\t" t
      }
    }' "$@"
}
# src_check <seat dir> <record>... -> one "<KIND>\t<record>\t<detail>" line per defect, then
# "N\t<entries>\t<sources>". An ENTRY is the text under one heading; it needs a source only if
# it carries a `disposition:` line (the label arm H reads), so a preamble or a "for the lead"
# section is not an entry. No `{n,m}` interval in these regexes: the macOS awk is not assumed to
# carry them.
src_check() {
  local sd="$1" sdp ids toks; shift
  sdp="$(cd "$sd" 2>/dev/null && pwd -P)" || sdp="$sd"
  toks="$(awk '
    function flush() { if (disp && !nsrc) print "NOSOURCE\t" cf "\t" cur; if (disp) ne++; disp = 0; nsrc = 0 }
    FNR == 1 { flush(); cur = "(before any heading)"; cf = FILENAME; sub(/.*\//, "", cf); fence = 0 }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^#+[ \t]/ { flush(); cur = $0; sub(/^#+[ \t]+/, "", cur); next }
    /^[[:space:]-]*[*_`]*disposition[*_`]*:/ { disp = 1; next }
    /^[[:space:]-]*[*_`]*source[*_`]*:/ {
      nsrc++; v = $0; sub(/^[^:]*:/, "", v); n = 0
      while (match(v, /[A-Za-z0-9_.\/-]+[.]md#[A-Za-z0-9][A-Za-z0-9.-]*/)) {
        t = substr(v, RSTART, RLENGTH); v = substr(v, RSTART + RLENGTH); sub(/[.-]+$/, "", t); n++; ns++
        gsub(/\/\/+/, "/", t); print "T\t" cf "\t" t
      }
      if (!n) { l = $0; sub(/^[ \t]+/, "", l); print "BADFORM\t" cf "\t" l }
      next }
    END { flush(); print "N\t" ne + 0 "\t" ns + 0 }' "$@")"
  # One awk over every seat file of the sprint; a glob that matched nothing leaves no file, and
  # every source then reads NOFILE -- a refusal, never a pass.
  set -- "$sd"/*.md
  ids=""
  [ -f "$1" ] && ids="$(src_ids "$@")"
  { printf '%s\n' "$ids" | sed '/^$/d; s/^/I\t/'; printf '%s\n' "$toks"; } | awk -F'\t' -v sd="$sd" -v sdp="$sdp" '
    $1 == "I" && $3 == "" { f[$2] = 1; next }
    $1 == "I" { has[$2 SUBSEP $3] = 1; nid[$2]++; who[$3] = (($3 in who) ? who[$3] " " : "") $2; next }
    $1 == "T" {
      t = $3; i = index(t, "#"); p = substr(t, 1, i - 1); id = substr(t, i + 1)
      b = p; sub(/.*\//, "", b); full = sd "/" b; fullp = sdp "/" b
      ok = (p == b || p == full || p == fullp \
            || (length(full) > length(p) && substr(full, length(full) - length(p)) == "/" p) \
            || (length(fullp) > length(p) && substr(fullp, length(fullp) - length(p)) == "/" p))
      if (!ok) { print "FOREIGN\t" $2 "\t" t; next }
      if (!(b in f)) { print "NOFILE\t" $2 "\t" t "\t" b; next }
      if (!((b SUBSEP id) in has)) { print "UNRESOLVED\t" $2 "\t" t "\t" b "\t" id "\t" ((id in who) ? who[id] : "no seat file") "\t" (nid[b] + 0); next }
      next }
    { print }'
}
# src_refusals <src_check output> -> calls refuse per defect; SRC_E / SRC_S carry the counts.
src_refusals() {
  local k r d b i w c
  SRC_E=0; SRC_S=0
  while IFS='	' read -r k r d b i w c; do
    case "$k" in
      N) SRC_E="$r"; SRC_S="$d" ;;
      NOSOURCE)   refuse "${r}: the entry '${d}' carries a disposition and no 'source:' line; a party repair names the seat finding it applies as 'source: <seat-file>#<finding-id>'" ;;
      BADFORM)    refuse "${r}: '${d}' names no <seat-file>.md#<finding-id>" ;;
      FOREIGN)    refuse "${r}: source ${d} names a file outside ${SEAT_DIR}; a party repair applies its own sprint's seat findings" ;;
      NOFILE)     refuse "${r}: source ${d} names no seat file (${SEAT_DIR}/${b} does not exist)" ;;
      UNRESOLVED) if [ "${c:-0}" = 0 ]; then
                    refuse "${r}: source ${d} is UNRESOLVED -- ${b} carries no finding id at all (no '## <id> ...' heading); the seat wrote findings nothing can attribute"
                  else
                    refuse "${r}: source ${d} is UNRESOLVED -- ${b} carries no finding ${i}; a source is keyed on the seat file AND the id, because ids collide across seats (${i} is in: ${w})"
                  fi ;;
    esac
  done <<SRCEOF
$1
SRCEOF
}
# THE SEAT-COMPLETE BELT. Every seat writes its findings file early and closes it with ONE final
# `seat-complete: <step> <seat> <shard> findings=<n>` line (`_gate-procedures.md` "Validation cycle"
# item 1); the join beat's `--complete` is the braces. Scoped to the seat files the records' `source:`
# tokens CITE. THE ERA IS DECIDED PER STEP, over the whole seat directory: a step is in the marker
# era when ANY of its seat files there (`<step>-*.md`) ends in a marker naming that step, and then
# every CITED seat file of that step must end in one, or a repair is applying a seat that had not
# finished. Deciding it over the cited set alone acquitted a lone cited unmarked seat whose siblings
# had all finished; deciding it over the whole dir convicted an earlier step's seat written before
# the instruction. A cited file of a step with no marker anywhere is accepted unchecked -- exactly
# as the merges treat an unmarked directory. The marker predicate is the beat's: last non-blank
# line, no carriage return, outside an unclosed fence (closed only by the opener's character, at
# least as long).
# seat_marked <file> -> 0 iff it ends in the marker; prints the marker's <step> token.
SEAT_FENCE_AWK='
    function fence_line(   r) {
      if (!match($0, /^[ \t]*(```+|~~~+)/)) return 0
      r = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", r)
      if (fc == "") { fc = substr(r, 1, 1); fl = length(r) }
      else if (substr(r, 1, 1) == fc && length(r) >= fl && substr($0, RSTART + RLENGTH) ~ /^[ \t\r]*$/) { fc = ""; fl = 0 }
      return 1
    }'
seat_marked() {
  awk "$SEAT_FENCE_AWK"'
    { fence_line() }
    NF { l = $0 }
    END { if (fc == "" && l !~ /\r/ && index(l, "seat-complete: ") == 1) { split(l, w, " "); print w[2]; exit 0 }; exit 1 }' "$1" 2>/dev/null
}
# seat_complete_check <seat dir> <record>... -> refuse once per cited seat file that is unfinished.
seat_complete_check() {
  local sd="$1" cited b steps="" f st m
  shift
  cited="$(awk "$SEAT_FENCE_AWK"'
    FNR == 1 { fc = ""; fl = 0 }
    fence_line() { next }
    fc != "" { next }
    /^[[:space:]-]*[*_`]*source[*_`]*:/ {
      v = $0; sub(/^[^:]*:/, "", v)
      while (match(v, /[A-Za-z0-9_.\/-]+[.]md#/)) {
        t = substr(v, RSTART, RLENGTH - 1); v = substr(v, RSTART + RLENGTH); sub(/.*\//, "", t); print t
      }
    }' "$@" | LC_ALL=C sort -u)"
  # The steps in the marker era: every marker's own <step> token, over the WHOLE directory.
  for f in "$sd"/*.md; do
    [ -f "$f" ] || continue
    st="$(seat_marked "$f")" && [ -n "$st" ] && steps="$steps $st"
  done
  [ -n "$steps" ] || return 0
  while IFS= read -r b; do
    [ -n "$b" ] && [ -f "$sd/$b" ] || continue
    seat_marked "$sd/$b" >/dev/null && continue
    for st in $steps; do
      case "$b" in "$st"-*)
        m="$(cd "$sd" && for f in "$st"-*.md; do seat_marked "$f" >/dev/null && printf '%s ' "$f"; done)"
        refuse "seat file ${b} does not end in its 'seat-complete:' line while its step '${st}' is in the marker era (${m% }); that seat had not finished, and a repair applying it applies unfinished findings"
        break ;;
      esac
    done
  done <<SCEOF
$cited
SCEOF
}
# The self-probe, before any corpus is read: a resolving source passes, and an id that only ANOTHER
# seat carries refuses. Both directions, or a resolver keyed on the id alone reads as working.
src_probe() {
  local d o
  d="$(mktemp -d "${TMPDIR:-/tmp}/join-srcprobe.XXXXXX")" || die "mktemp failed; the source resolver cannot be probed"
  mkdir -p "$d/seats" || die "the source probe could not stage"
  printf '# seat a\n\n## F-1 (major) sections: 1\n' > "$d/seats/a-1.md"
  printf '# seat b\n\n## Finding A1-2 (MAJOR) sections: 1\n' > "$d/seats/b-1.md"
  printf '### F-1\n- disposition: repaired\n- source: a-1.md#F-1\n' > "$d/good.md"
  printf '### F-1\n- disposition: repaired\n- source: b-1.md#F-1\n' > "$d/bad.md"
  o="$(src_check "$d/seats" "$d/good.md")"
  [ "$o" = "N	1	1" ] || { rm -rf "$d"; die "the source resolver's self-probe failed: a resolving source read '${o}'; no verdict"; }
  o="$(src_check "$d/seats" "$d/bad.md")"
  case "$o" in UNRESOLVED*"b-1.md#F-1"*) ;; *) rm -rf "$d"; die "the source resolver's self-probe failed: an id only another seat carries read '${o}'; no verdict" ;; esac
  rm -rf "$d"
}
if [ "$SRCMODE" = 1 ]; then
  [ -d "$SEAT_DIR" ] || die "no seat files at ${SEAT_DIR}; a party repair's sources resolve there"
  src_probe
  src_refusals "$(src_check "$SEAT_DIR" "$SRC_REC")"
  seat_complete_check "$SEAT_DIR" "$SRC_REC"
  [ "$SRC_E" -gt 0 ] || refuse "${SRC_REC} carries no entry with a 'disposition:' line; nothing is attributed"
  [ "$refuse_n" -eq 0 ] || exit 2
  echo "SOURCES: ${SRC_REC} -- ${SRC_E} entries, ${SRC_S} sources, every one resolved in ${SEAT_DIR}"
  exit 0
fi

SHARD_DIR="${PA}/s${SPRINT}/shards/${ARTIFACT}-repair-p${PASS}"
OUT="${PA}/s${SPRINT}/${ARTIFACT}-repair-p${PASS}.md"
if [ "$SUBJMODE" = 1 ]; then
  SHARD_DIR="${PA}/s${SPRINT}/shards/${SUBJ_DIRNAME}"
  OUT="${PA}/s${SPRINT}/${SUBJ_RECNAME}"
fi
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
SUBJ_SET=""; SUBJ_SECTIONED=""; SUBJ_OUTSIDE=""
if [ "$SUBJMODE" = 1 ]; then
  SUBJ_REC="${SHARD_DIR}/.subject"
  if [ -n "$REPDIR" ]; then
    _rd="$(phys "$REPDIR")" || die "the repair dir ${REPDIR} does not exist"
    _sd="$(phys "$SHARD_DIR")" || die "the repair dir ${SHARD_DIR} does not exist"
    [ "$_rd" = "$_sd" ] || die "the repair dir ${REPDIR} is not ${SHARD_DIR}, the one --subject/--pass name"
  fi
  [ -f "$SUBJ_REC" ] || die "no subject split record at ${SUBJ_REC}; run partition-subject.sh --split ${SPRINT} ${SHARD_DIR} before dispatching the remediators"
  PSUBJ="${JR_SCRIPT_DIR}/partition-subject.sh"
  [ -f "$PSUBJ" ] || die "partition-subject.sh is not beside this script (${PSUBJ}); reinstall ai-dlc"
  _srm="$(awk -F'\t' '$1 == "manifest" { print $2; exit }' "$SUBJ_REC")"
  # partition-subject.sh records every path ROOT-relative (`<state dir relative to the root>/...`),
  # computed exactly as below; the ledger spells the same paths from the state dir's BASENAME. The
  # two differ for a nested state dir, so the recorded spelling is compared as recorded and every
  # path that meets the ledger is converted once, by to_ledger.
  _rootp="$(cd "$JR_ROOT" 2>/dev/null && pwd -P)" || die "the project root ${JR_ROOT} does not exist"
  case "$_STATE_DIR" in
    /*) _sdp="$(cd "$_STATE_DIR" 2>/dev/null && pwd -P)" || die "the state dir ${_STATE_DIR} does not exist"
        case "$_sdp" in "$_rootp"/*) SREL="${_sdp#"$_rootp"/}" ;; *) die "the state dir ${_STATE_DIR} is not under the project root ${_rootp}" ;; esac ;;
    *) SREL="${_STATE_DIR%/}" ;;
  esac
  STATE_NAME="${STATE##*/}"
  to_ledger() { awk -v p="${SREL}/" -v n="${STATE_NAME}/" 'index($0, p) == 1 { print n substr($0, length(p) + 1); next } { print }'; }
  _want_mf="${SREL}/planning-artifacts/s${SPRINT}/requirements-subject.md"
  [ "$_srm" = "$_want_mf" ] || die "${SUBJ_REC} was split against ${_srm:-no manifest}, not sprint ${SPRINT}'s subject manifest ${_want_mf}"
  [ -f "${JR_ROOT}/${_srm}" ] || die "the subject manifest ${JR_ROOT}/${_srm} is gone"
  SUBJ_MF_BASE="$(awk '/REQUIREMENTS_SUBJECT v1/ { inb = 1; next } inb && /^base: / { print $2; exit }' "${JR_ROOT}/${_srm}")"
  [ "$(awk -F'\t' '$1 == "base" { print $2; exit }' "$SUBJ_REC")" = "$SUBJ_MF_BASE" ] \
    || die "${SUBJ_REC} was split under a base other than the manifest's (${SUBJ_MF_BASE:-none}); the base is read, never re-chosen"
  if [ -n "$SUBJ_BASE" ]; then
    _bf="$(git -C "$JR_ROOT" rev-parse --verify --quiet "${SUBJ_BASE}^{commit}" 2>/dev/null)" || _bf=""
    [ -n "$_bf" ] && [ "$_bf" = "$SUBJ_MF_BASE" ] || die "--base ${SUBJ_BASE} is not the subject manifest's base ${SUBJ_MF_BASE}"
  fi
  # The file set, in the ledger's spelling: section copies, the subject files with a WHOLE-FILE
  # part, and the spec's .memlog.md beside its SPEC.md when the SPEC has a part.
  SUBJ_SET="$(awk -F'\t' '
    $1 == "part" && $7 != "-" { print $7 }
    $1 == "part" && $7 == "-" { print $4; if ($3 == "SPEC") { m = $4; sub(/SPEC\.md$/, ".memlog.md", m); print m } }' "$SUBJ_REC" | to_ledger | awk '!seen[$0]++')"
  SUBJ_SECTIONED="$(awk -F'\t' '$1 == "part" && $7 != "-" { print $4 }' "$SUBJ_REC" | to_ledger | awk '!seen[$0]++')"
  # A subject file with no part at all: unchanged since the base, so nobody owns a write to it.
  SUBJ_OUTSIDE="$(awk 'FILENAME == ARGV[1] { split($0, c, "\t"); if (c[1] == "part") h[c[4]] = 1; next }
    /REQUIREMENTS_SUBJECT v1/ { inb = 1; next } /REQUIREMENTS_SUBJECT_END/ { inb = 0 }
    inb && /^file: / && !($3 in h) { print $3 }' "$SUBJ_REC" "${JR_ROOT}/${_srm}" | to_ledger)"
  [ -n "$SUBJ_SET" ] || die "${SUBJ_REC} lists no part"
  APATH="${STATE_NAME}"
elif [ "$DOCMODE" = 1 ]; then
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
_jdoc="$DOCMODE"; [ "$SUBJMODE" = 1 ] && _jdoc=1
ROWS="$(jq -rn --arg since "$SINCE" --arg until "$UNTIL" --arg ap "$APATH" --arg sh "$SHARD_REL" --arg doc "$_jdoc" '
  [inputs | select(type == "object") | select(.kind == "artifact-write")
   | select((.agent_id // "") != "") | select((.ts | type) == "string")
   | select(.ts >= $since and .ts <= $until)
   | select(.path == $ap or (.path | startswith($ap + "/")))
   | select($doc == "1" or ((.path | startswith($sh + "/")) | not))
   | [.path, .agent_id]] | unique | .[] | @tsv' "$LEDGER" 2>/dev/null)" \
  || die "the write ledger ${LEDGER} does not parse as JSON lines"
if [ "$SUBJMODE" = 1 ]; then
  # Keep the subject's file set; name every in-place write to a sectioned or part-less subject
  # file; drop everything else (the parts themselves, other agents' unrelated writes).
  _subjf="$(mktemp "${TMPDIR:-/tmp}/join-subject.XXXXXX")" || die "mktemp failed"
  { printf '%s\n' "$SUBJ_SET" | sed 's/^/K\t/'
    printf '%s\n' "$SUBJ_SECTIONED" | sed '/^$/d; s/^/S\t/'
    printf '%s\n' "$SUBJ_OUTSIDE" | sed '/^$/d; s/^/O\t/'; } > "$_subjf"
  _bad="$(printf '%s\n' "$ROWS" | awk -F'\t' -v sf="$_subjf" '
    BEGIN { while ((getline l < sf) > 0) { split(l, a, "\t"); C[a[2]] = a[1] } }
    NF >= 2 && C[$1] == "S" { print "S\t" $1 "\t" $2 }
    NF >= 2 && C[$1] == "O" { print "O\t" $1 "\t" $2 }')"
  ROWS="$(printf '%s\n' "$ROWS" | awk -F'\t' -v sf="$_subjf" '
    BEGIN { while ((getline l < sf) > 0) { split(l, a, "\t"); C[a[2]] = a[1] } }
    NF >= 2 && C[$1] == "K"')"
  rm -f "$_subjf"
  if [ -n "$_bad" ]; then
    while IFS='	' read -r _k _p _a; do
      case "$_k" in
        S) refuse "${_p} was written IN PLACE by ${_a}, but the split sectioned it: its parts edit section copies, and an in-place write is a write to text outside every in-scope part (the serial remediator edits it AFTER the join)" ;;
        O) refuse "${_p} has no part in this split (unchanged since the base) and was written in the window by ${_a}; no shard owns it" ;;
      esac
    done <<BADEOF
$_bad
BADEOF
  fi
fi
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
    # Subject mode: a part may cite the root-relative spelling `.subject` records; the ledger spells
    # the state dir by its basename.
    [ "$SUBJMODE" = 1 ] && case "$_t" in "${SREL}"/*) _t="${STATE_NAME}/${_t#"${SREL}"/}" ;; esac
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

# A party repair: every entry of every part names the seat finding it applied, resolved on the
# pair (seat file, id). Reported beside every other reason, before anything is assembled.
if [ "$PARTY" = 1 ]; then
  if [ -d "$SEAT_DIR" ]; then
    src_probe
    set --
    while IFS= read -r p; do [ -n "$p" ] && set -- "$@" "$p"; done <<SRCPEOF
$PARTS
SRCPEOF
    src_refusals "$(src_check "$SEAT_DIR" "$@")"
    seat_complete_check "$SEAT_DIR" "$@"
  else
    refuse "no seat files at ${SEAT_DIR}; a party repair's sources resolve there"
  fi
fi

[ -e "$OUT" ] && refuse "${OUT} already exists; a join never overwrites a repair record"

[ "$refuse_n" -eq 0 ] || exit 2

# --- document mode: assemble BEFORE the record. A refusal here writes nothing -- the assembler
# refuses without touching the document, and no record is written after it.
ASM_LINE=""
SUBJ_BEFORE=""; SUBJ_AFTER=""
if [ "$SUBJMODE" = 1 ]; then
  SUBJ_BEFORE="$(awk -F'\t' '$1 == "sha" { printf " %s=%s", $2, $3 }' "$SUBJ_REC")"
  ASM_LINE="$(bash "$PSUBJ" --assemble "$SHARD_DIR" 2>&1)" || {
    printf '%s\n' "$ASM_LINE" >&2
    die "the sections of the sprint ${SPRINT} subject did not assemble; no repair record was written"
  }
  for _st in product-brief SPEC prd architecture-impact; do
    _rel="$(awk '/REQUIREMENTS_SUBJECT v1/ { inb = 1; next } /REQUIREMENTS_SUBJECT_END/ { inb = 0 } inb && $1 == "file:" && $2 == s { print $3 }' s="$_st" "${JR_ROOT}/${_srm}")"
    if command -v shasum >/dev/null 2>&1; then _h="$(shasum -a 256 "${JR_ROOT}/${_rel}" | cut -d' ' -f1)"
    else _h="$(sha256sum "${JR_ROOT}/${_rel}" | cut -d' ' -f1)"; fi
    SUBJ_AFTER="${SUBJ_AFTER} ${_st}=${_h}"
  done
elif [ "$DOCMODE" = 1 ]; then
  # The document's sha before is the one the split recorded (the bytes the shards were cut from);
  # after is re-hashed off the assembled document, so the record is a J2 repair link.
  DOC_BEFORE="$(awk -F'\t' '$1 == "sha256" { print $2; exit }' "$MANIFEST")"
  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)" || {
    printf '%s\n' "$ASM_LINE" >&2
    die "the sections of ${DOC_ABS} did not assemble; no repair record was written"
  }
  if command -v shasum >/dev/null 2>&1; then DOC_AFTER="$(shasum -a 256 "$DOC_ABS" | cut -d' ' -f1)"
  else DOC_AFTER="$(sha256sum "$DOC_ABS" | cut -d' ' -f1)"; fi
  _rootp="$(cd "$JR_ROOT" 2>/dev/null && pwd -P)" || _rootp=""
  DOC_REL="$DOC_ABS"
  [ -n "$_rootp" ] && case "$DOC_ABS" in "$_rootp"/*) DOC_REL="${DOC_ABS#"$_rootp"/}" ;; esac
fi

# --- write the single record every reader globs for.
TMP="${OUT}.join.$$"
{
  echo "# ${ARTIFACT} repair — sprint ${SPRINT}, pass ${PASS} (joined from $(printf '%s\n' "$PARTS" | grep -c .) shard records)"
  echo ""
  echo "Joined by join-remediator-shards.sh from ${SHARD_DIR#"${JR_ROOT}"/}; window ${SINCE} .. ${UNTIL};"
  if [ "$SUBJMODE" = 1 ]; then
    echo "every subject file and section copy was written by exactly one agent in that window;"
    printf '%s\n' "$ASM_LINE" | sed 's/^/partition-subject.sh: /'
    echo ""
    echo "- artifact: ${_srm}"
    echo "- artifact_sha_before:${SUBJ_BEFORE}"
    echo "- artifact_sha_after:${SUBJ_AFTER}"
  elif [ "$DOCMODE" = 1 ]; then
    echo "every section under ${APATH} was written by exactly one agent in that window;"
    echo "partition-document.sh: ${ASM_LINE}"
    echo ""
    echo "- artifact: ${DOC_REL}"
    echo "- artifact_sha_before: ${DOC_BEFORE}"
    echo "- artifact_sha_after: ${DOC_AFTER}"
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
