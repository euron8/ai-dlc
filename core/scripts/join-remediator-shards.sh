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
#   --rerun <part>.md@<ISO>   (repeatable) judge that part's cited files from <ISO> on; see
#                     "RE-RUN OF ONE PART" below.
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
# RE-RUN OF ONE PART -- `--rerun <part>.md@<ISO>`, repeatable; files, --document and --subject.
#   One owner per file in its window; earlier writes on re-run files are superseded, and the
#   re-run part accounts for the whole section diff against the split slice. When one part's
#   remediator is re-run after the others finished, no single window joins: a narrow one reads the
#   other parts UNWRITTEN, a wide one gives the re-run part's files two writers. So the outer
#   window stays every other part's, and the named part P gets its own start S_P:
#   - F_P is the set of written files P's `edit:` lines cite, resolved against the UNNARROWED rows.
#     Only rows on F_P with ts < S_P are dropped; their writers are P's SUPERSEDED writers. Every
#     arm above (distinct-writer, UNWRITTEN, AMBIG, UNCITED, DOUBLE, SPAN) then runs unchanged on the
#     narrowed rows, so P's files need exactly one writer in [S_P, until] and every other part still
#     needs its own writes in [since, until].
#   - Refused: a part not among the parts; a part named twice; S_P malformed or outside
#     [since, until]; a part citing no written file; a superseded writer with ANY row on a file
#     outside F_P in the outer window (it was not only P's writer); a superseded writer with any row
#     at or after S_P (the original is still writing); P's re-run writer being one of its
#     superseded writers (the re-run is a NEW dispatch, a new agent id). Refused with --sources and
#     --escalations, which read no ledger.
#   - THE PART RECORDS `<repair dir>/<part>.md` sit outside every mode's file set, so they are read
#     separately, non-recursively, in the outer window. Refused: a superseded writer of P with a row
#     on ANY part record at or after S_P; a superseded writer with a row on ANOTHER part's record;
#     a row on P's own record at or after S_P by any agent but P's re-run writer, or no such row by
#     the re-run writer at all (the covering account is then the re-run's); the re-run writer (any
#     writer of F_P at or after S_P) with a row on any file or part record outside F_P and P's own
#     record in the outer window -- a finished part's agent is not a new dispatch.
#   - Subject mode classifies in-place writes (sectioned or part-less subject files) on the
#     unnarrowed rows, before any narrowing.
#   - The record keeps the outer `window` line and adds one `rerun: <part> since <S_P>; superseded
#     on <file>: <ids> (<n> rows, <first>..<last>)` line per re-run; JOINED counts the superseded.
#   Residual, stated: bytes a superseded writer wrote before S_P stay in the file, covered only by
#   the re-run part's own account of the whole diff against the split slice. That account's AUTHOR
#   is enforced (the part-record refusals above); its CONTENT is not checked by any program.
#
# AN ALIAS IS ONE WRITER, AND ONLY ON TRANSCRIPT EVIDENCE. The hook records, beside `agent_id`,
#   the payload's `tool_use_id`, its `transcript_path` (the PARENT session's file, which every
#   subagent of the session carries) and `agent_transcript` (whether that agent's own
#   `<session dir>/subagents/agent-<id>.jsonl` existed at write time). A row r by agent A on file f
#   is read as B's write (B another writer of f in the window) only when ALL hold:
#     1. r carries a non-empty tool_use_id and r's session is every one of B's rows' session on f;
#     2. A has no transcript: r's agent_transcript is false AND `<session dir>/subagents/agent-A.jsonl`
#        is absent at join time;
#     3. B's transcript holds EXACTLY ONE assistant `tool_use` block -- parsed with jq, so a
#        tool_result quoting the id never counts -- whose id is r's, whose name is Edit, Write or
#        MultiEdit, and whose `input.file_path` normalises to f by the hook's own normalisation;
#     4. A has no other row in the file set.
#   A shared transcript_path is NEVER evidence of one writer: it is the parent's, on every subagent.
#   A row that fails any clause still refuses, and the refusal names its tool_use_id, whether A's
#   transcript exists and which transcript, if any, holds that id. A row carrying none of the new
#   keys is judged exactly as before they existed.
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
#   join-remediator-shards.sh --escalations <record> [--sprint <N>]
#   the same entry contract and escalation closure over a record with no seat files (the entry
#   contract's arm 5); writes nothing, refuses no open escalation.
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
SUBJMODE=0; SUBJ_BASE=""; SRCMODE=0; SRC_REC=""; RERUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rerun) [ $# -ge 2 ] || die "--rerun needs <part>.md@<ISO>"
             RERUN="${RERUN}${2}
"; shift 2 ;;
    --sources) SRC_REC="${2:-}"; SRCMODE=1; shift 2 ;;
    --escalations) SRC_REC="${2:-}"; SRCMODE=2; shift 2 ;;
    --subject) SPRINT="${2:-}"; SUBJMODE=1; shift 2 ;;
    --base) SUBJ_BASE="${2:-}"; shift 2 ;;
    --sprint) SPRINT="${2:-}"; shift 2 ;;
    --artifact) ARTIFACT="${2:-}"; shift 2 ;;
    --pass) PASS="${2:-}"; shift 2 ;;
    --artifact-path) APATH="${2:-}"; shift 2 ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --until) UNTIL="${2:-}"; shift 2 ;;
    --document) DOCUMENT="${2:-}"; DOCMODE=1; shift 2 ;;
    -h|--help) awk 'NR == 1 { next } !/^#/ { exit } { print }' "$0"; exit 0 ;;
    -*) die "unknown argument '$1' (see --help)" ;;
    *) { [ "$DOCMODE" = 1 ] || [ "$SUBJMODE" = 1 ]; } && [ -z "$REPDIR" ] || die "unknown argument '$1' (see --help)"
       REPDIR="$1"; shift ;;
  esac
done
# A party repair: its entries must each name the seat finding they apply.
PARTY=0
if [ "$SRCMODE" != 0 ]; then
  [ "$DOCMODE$SUBJMODE" = 00 ] && [ -z "$ARTIFACT$PASS$APATH$SINCE$UNTIL$REPDIR" ] \
    || die "--sources and --escalations check one record and take only --sprint <N>"
  [ -z "$RERUN" ] || die "--rerun narrows a join's ledger window; --sources and --escalations read no ledger"
  [ -n "$SRC_REC" ] && [ -f "$SRC_REC" ] || die "--sources and --escalations need an existing record (got '${SRC_REC}')"
  [ "$SRCMODE" = 1 ] && PARTY=1
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
# --escalations reads one record and no seat directory, so its --sprint is optional.
[ "$SRCMODE" = 2 ] && [ -z "$SPRINT" ] && SPRINT=0
case "$SPRINT" in ''|*[!0-9]*) die "--sprint must be a sprint number (got '${SPRINT}')" ;; esac
case "$ARTIFACT" in *-party) PARTY=1 ;; esac
if [ "$SRCMODE" != 0 ]; then
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

# --- THE ENTRY CONTRACT (BL-508, BL-519). Every mode, and --sources. Three arms over every entry
# (the text under one heading that carries a `disposition:` line, as src_check reads it):
#   (1) SIBLINGS. A `repaired` entry with a real edit carries a `siblings:` field (`n/a (deletion)`
#       is one of its forms): the grep for
#       the replaced text across the artifact's own files and the control for the new text
#       (team-roles/remediator.md, "Re-check every sibling of the text you replaced"). A REAL
#       edit is one whose `edit:` line yields a path token under the coverage join's OWN token
#       grammar (the `_toks` awk below), so `edit: n/a`, `none`, `n/a (escalated)` and every
#       other prose spelling are exempt by construction rather than by a list of spellings.
#       THE FIELD IS READ IN ONE OF FOUR FORMS AND NO OTHER, the four the refusal names: the
#       values `n/a (section shard; re-checked by the serial remediator after assembly)`,
#       `n/a (insertion)` and `n/a (deletion)` (byte-equal once `*`, `_`, backticks and blanks
#       around them are trimmed), or an EMPTY value followed, blank lines aside, by a ```text fence
#       holding a `$ grep -rn -F` line and a `$ grep -c -F '<text>' <file>` line whose next line is a
#       count of 1 or more. A field present in any other spelling -- `- siblings: checked`, a value
#       with no fence, a ```derived fence, a fence missing either command -- is BADSIB, its own
#       refusal; a field absent is NOSIB. A reader keyed on the field's presence passed
#       `- siblings: checked` (the tip adversary's finding), and one keyed on the word passed any
#       entry whose prose mentions a sibling.
#       THE FENCE IS ```text, NOT ```derived, ON PURPOSE: it is a point-in-time record of the
#       remediation, and `validate-artifact-derivations.sh` (the slot-wide re-run that exits 1 for
#       "send back to the remediator") and the capture hook replay only ```derived. Replayed, its
#       control went STALE the first time a later pass legitimately rewrote the text it counts;
#       graph's s318 slot reads 3316 stale of 4475 derivations. Instead, in parts mode, THIS join
#       counts the control once (sib_control): the text must be in the named file at the join, so a
#       fence naming text that was never written is refused here, and a later rewrite is never read.
#       THE ERA IS THE INSTALL, NOT THE PARTS. In parts mode (files, --document, --subject) the arm
#       applies UNCONDITIONALLY: parts are written fresh, inside the repair window, by agents that
#       read the installed role file, so a part set written after the install that omits the
#       field EVERYWHERE is refused like one that omits it once. An era decided over the parts
#       ("PENDING when no entry carries it") could not fire on total omission, the commonest form.
#       PENDING survives only in --sources mode, which checks a RECORD with no window, possibly
#       written across a pull (the serial remediator appends to a joined record): there the era is
#       POSITIONAL -- the arm binds from the record's first entry carrying `siblings:` onward, and
#       the repaired edits before it are counted on one PENDING line. Its hole, stated: a record
#       whose every entry post-dates the install and omits the field reads PENDING; and an entry
#       before the first carrier is never checked. The install stamp (`.claude/.ai-dlc-version`
#       `installed_at`) is not used: a record carries no window to compare it to, and an mtime is
#       not one.
#       PRE-RULE PARTS, MEASURED by running this file's own contract_check (parts mode) over
#       scratch copies of graph's s317/s318 shard parts -- the arm's program, not the whole join,
#       which needs ledger rows those dirs do not carry. 202 parts, 0 carry the field; 936 NOSIB
#       entries in 193 of them (the other 9 hold only escalated or `edit: n/a` entries); the same
#       run's SETASIDE count is 1, the known `5.md:111`, as its control. These are true positives
#       that are never re-joined: 20 of the 23 dirs already have their joined record beside them (a join never
#       overwrites one, so a re-join refuses before this arm matters), the other 3 are closed
#       sprints' dirs no procedure re-joins, and no shipped program invokes this join (a grep of
#       core/scripts, core/hooks, core/git-hooks and the update skill finds only message prose).
#       The residual, stated rather than hidden: a repair round whose parts were written BEFORE a
#       pull and joined AFTER it is refused, and the shards are re-dispatched under the new role.
#   (2) SET-ASIDE. A `repaired` entry under a CRITICAL or MAJOR heading whose `claim now
#       asserted:` text matches `outside (this|my|the) (shard|part|section)|not required` and
#       names no hand-off (`escalat` or `serial remediator`) is refused: the out-of-shard part of
#       a fix is a second, `escalated` entry, never a scope ruling by the repair seat.
#       FALSE-POSITIVE SET, MEASURED over graph's s317/s318 repair shard parts (202 parts, 478
#       repaired MAJOR+ entries, counted with this awk's own heading-severity and disposition
#       grammar over `s31[78]/shards/*repair*/*.md`): 1 hit, the true positive
#       `s318/shards/stories-party-repair-p1/5.md:111` (sm-05 F-3, "outside this shard and is not
#       required"), 0 false positives; 8 further entries match the phrase and carry a hand-off,
#       and are accepted. THE NARROWING: `out of scope` was a candidate alternative and is NOT in
#       the regex, because its hits in that corpus are PRODUCT scope ("out of scope for this
#       story"), not shard scope. Severity is read off the entry HEADING (`### F-1 — MAJOR`):
#       the same corpus carries 0 `severity:` lines, so the heading is the grammar.
#   (3) ESCALATED, CLOSED IN --sources MODE ONLY, AND ONLY BY NAME. Every escalated entry is
#       printed as one `ESCALATED: <part> <heading>` line and counted. In --sources mode the record
#       may carry the serial remediator's own appended entries, so an escalated entry is CLOSED --
#       printed as `ESCALATED-CLOSED: <part> <heading>`, still visible to the lead, and left out of
#       the open count -- when a LATER entry dispositioned `repaired` carries a
#       `- closes: <part> <heading>` line naming it, byte-equal to its `ESCALATED:` line's tail
#       (whitespace and backticks around the value trimmed). <part> is the `<!-- shard: NN.md -->`
#       marker the join writes above each part, or the record's basename above the first marker.
#       NEVER keyed on the `source:` token: a later half-repair under the same token, of another
#       conjunct or in another part, closed the whole escalation (graph s318
#       architecture-party-repair-p1: dev-05#F-3 escalated in part 5.md and repaired under the same
#       token in the later part 6.md; dev-05#F-2 escalated in both 2.md and 5.md). Parts mode
#       closes nothing -- no part is later than another. Stated hole: the serial remediator's
#       appended entries sit after the LAST marker and so read as that shard's; an escalated entry
#       the serial remediator itself writes is closed only by a still later `closes:` naming that part.
#   (4) SERIAL-REQUIRED, PARTS MODE ONLY. The count of `repaired` entries with a real edit (arm 1's
#       predicate; `edit: n/a` entries are not counted). Each one owes the serial remediator's
#       cross-file sibling grep and moved-cite check, which no shard can run, so the procedure
#       dispatches the serial remediator when it OR ESCALATED-COUNT is above 0, in every mode. Not
#       printed in --sources mode: that record may be the serial remediator's own.
#   Not caught, by design: a set-aside reworded past the regex; a substantive mis-repair whose
#   prose and pin agree; whether the grepped text in the siblings fence is really the replaced
#   text (the write ledger carries no old_string); the `grep -rn -F` line's output is recorded,
#   never re-run; and a files-mode shard writing the section-shard form skips the fence (the four
#   forms are not gated by mode).
#   (5) --escalations <record> [--sprint <N>]: arms 1-3 over one record with NO seat files, after a
#   serial pass appended to an adversarial, elicitation or gate repair record. --sources needs the
#   sprint's party-mode/s<N> seat dir and refuses without it, so before this mode nothing read the
#   serial remediator's closes: lines there. Prints ESCALATED: per open escalation, ESCALATED-CLOSED:
#   per closed one and the count; an open escalation is the lead's, reported and never refused.
# contract_check <0 parts | 1 --sources> <record>... -> one line per finding, then the tail
#   "N\t<entries>\t<entries with a real edit>\t<entries carrying siblings:>\t<pre-era edits>\t<repaired real edits>".
#   E\t<part>\t<entry>         an open escalated entry (routed by the caller)
#   X\t<part>\t<entry>         an escalated entry a later repaired entry's closes: line named (--sources only)
#   NOSIB\t<rec>\t<entry>      a repaired entry with a real edit and no siblings: field
#   BADSIB\t<rec>\t<entry>     the same entry carrying the field in none of its four forms
#   CTL\t<rec>\t<entry>\t<file>\t<text>   a siblings fence's control, counted by the caller (parts mode)
#   SETASIDE\t<rec>\t<entry>\t<line>
contract_check() {
  local srcm="$1"; shift
  awk -v src="$srcm" '
    BEGIN { SIBNA["n/a (insertion)"] = 1; SIBNA["n/a (deletion)"] = 1
            SIBNA["n/a (section shard; re-checked by the serial remediator after assembly)"] = 1 }
    function trim(v) { gsub(/^[ \t`]+|[ \t`]+$/, "", v); return v }
    function vtrim(v) { gsub(/^[ \t*_`]+|[ \t*_`]+$/, "", v); return v }
    function flush(   i, k) {
      if (disp != "") {
        ne++
        if (edt) nedt++
        if (disp == "repaired" && edt) nrep++
        if (sibf) { nsib++; era = 1 }
        if (disp ~ /^escalat/) { nesc++; ef[nesc] = part; en[nesc] = cur; ex[nesc] = 0 }
        if (disp == "repaired" && src == 1)
          for (k = 1; k <= ncl; k++) for (i = 1; i <= nesc; i++) if (cl[k] == ef[i] " " en[i]) ex[i] = 1
        if (disp == "repaired" && edt && !sib) {
          if (sibf) print "BADSIB\t" cf "\t" cur
          else if (src == 0 || era) print "NOSIB\t" cf "\t" cur
          else npend++
        }
        if (disp == "repaired" && edt && sib && src == 0 && sfile != "") print "CTL\t" cf "\t" cur "\t" sfile "\t" stext
        if (disp == "repaired" && sev && claim ~ /outside (this|my|the) (shard|part|section)|not required/ \
            && claim !~ /escalat|serial remediator/) print "SETASIDE\t" cf "\t" cur "\t" hl
      }
      disp = ""; edt = 0; sib = 0; sibf = 0; sibw = 0; sibin = 0; sfile = ""; stext = ""; claim = ""; inclaim = 0; ncl = 0
    }
    # THE SIBLINGS FENCE. `- siblings:` with no value, then (blank lines aside) a ```text fence holding a
    # `$ grep -rn -F` line and the control `$ grep -c -F <quoted text> <file>` whose next line is a count of
    # 1 or more. Anything else after an empty value is a wrong spelling (BADSIB), a ```derived fence included.
    function sibclose() {
      if (srn && sctl == 2 && sn ~ /^[1-9][0-9]*$/ && ctext != "" && cfile != "") { sib = 1; sfile = cfile; stext = ctext }
      sibin = 0
    }
    function sibctl(l,   r, q, i) {
      r = substr(l, 14); q = substr(r, 1, 1); ctext = ""; cfile = ""
      if (q != "\047" && q != "\"") return
      r = substr(r, 2); i = index(r, q)
      if (i < 2) return
      ctext = substr(r, 1, i - 1); r = substr(r, i + 1); sub(/^[ \t]+/, "", r); sub(/[ \t]+$/, "", r)
      if (r != "" && r !~ /[ \t]/) cfile = r; else ctext = ""
    }
    FNR == 1 { flush(); cur = "(before any heading)"; sev = 0; hl = 0; cf = FILENAME; sub(/.*\//, "", cf); part = cf; fence = 0 }
    /^[ \t]*(```|~~~)/ {
      if (!fence && sibw) { b = $0; sub(/^[ \t]+/, "", b); sub(/[ \t]+$/, "", b); sibw = 0
                            if (b == "```text") { sibin = 1; srn = 0; sctl = 0; sn = "" } }
      else if (fence && sibin) sibclose()
      fence = !fence; inclaim = 0; next }
    fence && sibin {
      l = $0; sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l)
      if (sctl == 1) { sctl = 2; sn = l }
      else if (index(l, "$ grep -rn -F ") == 1) srn = 1
      else if (index(l, "$ grep -c -F ") == 1) { sibctl(l); sctl = 1 }
      next }
    fence { next }
    sibw && !/^[ \t]*$/ { sibw = 0 }
    /^<!-- shard: [^ ]+ -->[ \t]*$/ { flush(); cur = "(before any heading)"; sev = 0
                 part = $0; sub(/^<!-- shard: /, "", part); sub(/ -->.*$/, "", part); next }
    /^#+[ \t]/ { flush(); cur = $0; sub(/^#+[ \t]+/, "", cur); cur = trim(cur); h = toupper($0); hl = FNR
                 sev = (h ~ /(^|[^A-Z])(CRITICAL|MAJOR)([^A-Z]|$)/); next }
    /^[ \t]*$/ { inclaim = 0; next }
    /^[[:space:]-]*[*_`]*disposition[*_`]*:/ {
      v = tolower($0); sub(/^[^:]*:/, "", v); gsub(/[*_`]/, "", v); sub(/^[ \t]+/, "", v)
      split(v, a, /[^a-z]/); disp = a[1]; inclaim = 0; next }
    /^[[:space:]-]*[*_`]*edit[*_`]*:/ {
      v = $0; sub(/^[^:]*:/, "", v)
      if (match(v, /[A-Za-z0-9_.\/-]+[.](md|json|jsonl|yaml|yml|txt|csv)/)) edt = 1
      inclaim = 0; next }
    /^[[:space:]-]*[*_`]*siblings[*_`]*:/ { sibf = 1; v = $0; sub(/^[^:]*:/, "", v); v = vtrim(v); if (v == "") sibw = 1; else if (v in SIBNA) sib = 1; inclaim = 0; next }
    /^[[:space:]-]*[*_`]*closes[*_`]*:/ { v = $0; sub(/^[^:]*:/, "", v); sub(/^[*_`]+/, "", v); cl[++ncl] = trim(v); inclaim = 0; next }
    /^[[:space:]-]*[*_`]*claim now asserted[*_`]*:/ { claim = tolower($0); inclaim = 1; next }
    /^[[:space:]-]*[*_`]*[a-z][a-z _]*[*_`]*:/ { inclaim = 0 }
    inclaim { claim = claim " " tolower($0) }
    END {
      flush()
      for (i = 1; i <= nesc; i++) print (ex[i] ? "X" : "E") "\t" ef[i] "\t" en[i]
      print "N\t" ne + 0 "\t" nedt + 0 "\t" nsib + 0 "\t" npend + 0 "\t" nrep + 0
    }' "$@"
}
# sib_control <part> <entry> <file> <text> -- the siblings fence's control, counted ONCE, here, at the
# join: the text the fence says the edit wrote must be in the file it names now, which is the
# remediation moment. The fence is ```text, which validate-artifact-derivations.sh and the capture
# hook never replay, so a later legitimate rewrite of that text reads as nothing at all; a fence whose
# text was never written is refused here. Counted with the literal as an argument, never by running
# text out of a part. Parts mode only: a --sources record may hold shard entries whose text the serial
# remediator has since rewritten. The file resolves under the project root, then under the state
# dir's parent (the ledger spelling), then as an absolute path.
sib_control() {
  local r="$1" d="$2" f="$3" t="$4" p="" n
  case "$f" in
    /*) p="$f" ;;
    *) if [ -f "${JR_ROOT}/${f}" ]; then p="${JR_ROOT}/${f}"; elif [ -f "${STATE_PARENT}${f}" ]; then p="${STATE_PARENT}${f}"; fi ;;
  esac
  if [ -z "$p" ] || [ ! -f "$p" ]; then
    refuse "${r}: the ${d} entry's siblings control names ${f}, which is not a file under ${JR_ROOT}; the control counts the text you wrote in the file you edited"
    return
  fi
  n="$(grep -c -F -- "$t" "$p")" || n=0
  [ "$n" -ge 1 ] || refuse "${r}: the ${d} entry's siblings control counts '${t}' in ${f}, which holds it 0 times at the join; the control names the text your edit wrote, verbatim"
}
# contract_refusals <0 parts | 1 --sources> <contract_check output> -> refuse per finding;
# ESC_LINES / ESC_N carry the open escalated entries and ESC_CLOSED / ESC_X the closed ones, for the
# caller to print once the run has otherwise cleared; SERIAL_N counts the repaired entries with a
# real edit (the serial remediator's cross-file sibling grep and moved-cite check, after the join).
contract_refusals() {
  local srcm="$1" k r d l m q ne nedt nsib npend nosib="" remedy=""
  shift
  ESC_LINES=""; ESC_CLOSED=""; ESC_N=0; ESC_X=0; SERIAL_N=0; ne=0; nedt=0; nsib=0; npend=0
  # A parts-mode refusal of a missing field is, for a round whose parts predate the install, the
  # pre-rule shape: the remedy is the re-dispatch, never a hand-added field.
  [ "$srcm" = 0 ] && remedy="; parts written before the install: re-dispatch the shards"
  while IFS='	' read -r k r d l m q; do
    case "$k" in
      N) ne="$r"; nedt="$d"; nsib="$l"; npend="$m"; SERIAL_N="${q:-0}" ;;
      E) ESC_N=$((ESC_N + 1)); ESC_LINES="${ESC_LINES}ESCALATED: ${r} ${d}
" ;;
      X) ESC_X=$((ESC_X + 1)); ESC_CLOSED="${ESC_CLOSED}ESCALATED-CLOSED: ${r} ${d}
" ;;
      NOSIB) nosib="${nosib}${r}	${d}
" ;;
      BADSIB) refuse "${r}: the ${d} entry is repaired with an edit and its 'siblings:' field is none of its four forms; write '- siblings:' then a \`\`\`text fence holding the '\$ grep -rn -F' over your shard's own files and the control '\$ grep -c -F' with its count, or 'n/a (section shard; re-checked by the serial remediator after assembly)', 'n/a (insertion)' or 'n/a (deletion)' (team-roles/remediator.md, \"Re-check every sibling of the text you replaced\")" ;;
      CTL) sib_control "$r" "$d" "$l" "$m" ;;
      SETASIDE) refuse "${r}:${l}: the ${d} entry is dispositioned repaired while its claim sets part of the fix aside as outside the shard or not required, and names no hand-off; a fix that lies outside your files is a second entry, disposition escalated, carrying the same source: token" ;;
    esac
  done <<CTEOF
$1
CTEOF
  while IFS='	' read -r r d; do
    [ -n "$r" ] || continue
    refuse "${r}: the ${d} entry is repaired with an edit and carries no 'siblings:' field; every repaired edit carries one (team-roles/remediator.md, \"Re-check every sibling of the text you replaced\"): the fence over your shard's own files, 'n/a (section shard; ...)', 'n/a (insertion)' or 'n/a (deletion)'${remedy}"
  done <<NSEOF
$nosib
NSEOF
  if [ "${npend:-0}" -gt 0 ]; then
    echo "PENDING: ${npend} repaired edit(s) of this record precede its first entry carrying 'siblings:' (${nsib} of ${ne} entries carry it); the siblings arm binds a record from that entry onward"
  fi
}
# The self-probe, before any corpus is read. Arm (2): a set-aside refuses, and the split pair
# handing the remainder off passes. Arm (1): an entry with an edit and no siblings: is reported in
# parts mode even when NO entry carries the field, and an `edit: n/a` entry without one is not; in
# --sources mode the same record reads PENDING, and binds from its first carrier. Closure (3), on
# a record with two shard markers escalating the SAME heading: a later repaired entry naming
# `closes: 01.md <heading>` closes 01's and leaves 02's open; a later repaired entry sharing the
# escalation's `source:` token and carrying no `closes:` closes nothing; a `closes:` written BEFORE
# the escalated entry closes nothing. The siblings forms: `siblings: checked` and a ```derived fence
# are BADSIB, and a ```text fence carrying both commands and a count yields its CTL line. The tail's sixth field, the SERIAL-REQUIRED count, is read
# on every record: repaired entries with a real edit, and never one with `edit: n/a`.
contract_probe() {
  local d o
  d="$(mktemp -d "${TMPDIR:-/tmp}/join-ctprobe.XXXXXX")" || die "mktemp failed; the entry contract cannot be probed"
  printf '### F-1 — MAJOR\n- disposition: repaired\n- edit: s1/stories/a.md:3\n- siblings: n/a (insertion)\n- claim now asserted: X. Y is outside this shard and is not required.\n' > "$d/bad.md"
  printf '### F-1 — MAJOR\n- source: x/s-1.md#F-1\n- disposition: repaired\n- edit: s1/stories/a.md:3\n- siblings: n/a (insertion)\n- claim now asserted: X. Y is outside this shard; escalated below.\n\n### F-1 (remainder) — MAJOR\n- source: s-1.md#F-1\n- disposition: escalated\n- edit: n/a\n' > "$d/good.md"
  printf '### F-7 — MINOR\n- disposition: repaired\n- edit: s1/stories/a.md:3\n- siblings: checked\n\n### F-8 — MINOR\n- disposition: repaired\n- edit: s1/stories/a.md:4\n- **siblings:**\n\n```text\n$ grep -rn -F \047old\047 s1/stories/a.md\n$ grep -c -F \047new words\047 s1/stories/a.md\n1\n```\n\n### F-9 — MINOR\n- disposition: repaired\n- edit: s1/stories/a.md:5\n- siblings:\n\n```derived\n$ grep -rn -F \047old\047 s1/stories/a.md\n$ grep -c -F \047new\047 s1/stories/a.md\n1\n```\n' > "$d/forms.md"
  o="$(contract_check 0 "$d/forms.md")"
  [ "$o" = "BADSIB	forms.md	F-7 — MINOR
CTL	forms.md	F-8 — MINOR	s1/stories/a.md	new words
BADSIB	forms.md	F-9 — MINOR
N	3	3	3	0	3" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: the siblings forms read '${o}'; no verdict"; }
  printf '### F-2 — MINOR\n- disposition: repaired\n- edit: s1/stories/a.md:3\n\n### F-3 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n' > "$d/sib.md"
  printf '### F-2 — MINOR\n- disposition: repaired\n- edit: s1/stories/a.md:3\n\n### F-4 — MAJOR\n- disposition: repaired\n- edit: s1/stories/a.md:9\n- siblings: n/a (insertion)\n\n### F-5 — MAJOR\n- disposition: repaired\n- edit: s1/stories/a.md:12\n' > "$d/era.md"
  printf '<!-- shard: 01.md -->\n### F-6 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: 01.md F-6 — MAJOR\n\n### F-1 — MAJOR\n- source: s-1.md#F-1\n- disposition: escalated\n- edit: n/a\n\n### F-6 — MAJOR\n- disposition: escalated\n- edit: n/a\n\n<!-- shard: 02.md -->\n### F-1 — MAJOR\n- source: s-1.md#F-1\n- disposition: escalated\n- edit: n/a\n\n### serial F-1 by token — MAJOR\n- source: s-1.md#F-1\n- disposition: repaired\n- edit: n/a (no edit)\n\n### serial F-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n- **closes:** `01.md F-1 — MAJOR`\n' > "$d/close.md"
  o="$(contract_check 0 "$d/bad.md")"
  case "$o" in SETASIDE*"F-1 — MAJOR"*) ;; *) rm -rf "$d"; die "the entry contract's self-probe failed: a set-aside read '${o}'; no verdict" ;; esac
  o="$(contract_check 1 "$d/good.md")"
  [ "$o" = "E	good.md	F-1 (remainder) — MAJOR
N	2	1	1	0	1" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: a handed-off split pair read '${o}'; no verdict"; }
  o="$(contract_check 0 "$d/sib.md")"
  [ "$o" = "NOSIB	sib.md	F-2 — MINOR
N	2	1	0	0	1" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: the siblings reader read '${o}' in parts mode; no verdict"; }
  o="$(contract_check 1 "$d/sib.md")"
  [ "$o" = "N	2	1	0	1	1" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: a pre-rule --sources record read '${o}'; no verdict"; }
  o="$(contract_check 1 "$d/era.md")"
  [ "$o" = "NOSIB	era.md	F-5 — MAJOR
N	3	3	1	1	3" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: the --sources positional era read '${o}'; no verdict"; }
  o="$(contract_check 1 "$d/close.md")"
  [ "$o" = "X	01.md	F-1 — MAJOR
E	01.md	F-6 — MAJOR
E	02.md	F-1 — MAJOR
N	6	0	0	0	0" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: escalated-entry closure read '${o}'; no verdict"; }
  o="$(contract_check 0 "$d/close.md")"
  [ "$o" = "E	01.md	F-1 — MAJOR
E	01.md	F-6 — MAJOR
E	02.md	F-1 — MAJOR
N	6	0	0	0	0" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: parts mode closed an escalated entry ('${o}'); no verdict"; }
  rm -rf "$d"
}
# record_tail <record> -- the entry contract over one record no join wrote, then its escalations:
# shared by --sources and --escalations, so each line below exists once.
record_tail() {
  contract_probe
  contract_refusals 1 "$(contract_check 1 "$1")"
  [ "$refuse_n" -eq 0 ] || exit 2
  [ "$SRCMODE" = 1 ] && echo "SOURCES: ${1} -- ${SRC_E} entries, ${SRC_S} sources, every one resolved in ${SEAT_DIR}"
  [ "$SRCMODE" = 2 ] && echo "ESCALATIONS: ${1} -- every escalated entry, open or closed by a closes: line"
  # These are the LEAD's to adjudicate, never a re-dispatch of the serial remediator: the record may
  # be the serial remediator's own, appended after the join. So no SERIAL-REQUIRED line is printed
  # here; the closed entries stay visible to the lead.
  printf '%s' "$ESC_LINES"
  printf '%s' "$ESC_CLOSED"
  echo "ESCALATED-COUNT: ${ESC_N} (${ESC_X} closed by a later repaired entry's closes: line)"
  exit 0
}
if [ "$SRCMODE" = 1 ]; then
  [ -d "$SEAT_DIR" ] || die "no seat files at ${SEAT_DIR}; a party repair's sources resolve there"
  src_probe
  src_refusals "$(src_check "$SEAT_DIR" "$SRC_REC")"
  seat_complete_check "$SEAT_DIR" "$SRC_REC"
  [ "$SRC_E" -gt 0 ] || refuse "${SRC_REC} carries no entry with a 'disposition:' line; nothing is attributed"
  record_tail "$SRC_REC"
fi
# --escalations: the same contract and closure over a record with NO seat files -- an adversarial,
# elicitation or gate repair after its serial pass appended -- where --sources refuses for want of a
# party-mode/s<N> directory. Open escalations are reported, never a refusal.
if [ "$SRCMODE" = 2 ]; then
  n_disp="$(grep -c -E '^[[:space:]-]*[*_`]*disposition[*_`]*:' "$SRC_REC")" || n_disp=0
  [ "$n_disp" -gt 0 ] || die "${SRC_REC} carries no entry with a 'disposition:' line; no escalation can be read"
  record_tail "$SRC_REC"
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

# part_cites <part> -> the ledger-spelled tokens its `edit:` lines cite, one per line.
# A run of slashes in a cited token is squeezed to one before the strip below: a TMPDIR ending in
# `/` spells every path under it `T//x`, while STATE_PARENT comes from `pwd`, which collapses it,
# so the literal prefix strip never matched and an absolute citation under the root refused.
# AN ESCALATED ENTRY CITES NOTHING. Its `edit:` names the file the fix lies in (remediator.md pins
# that form), which is the serial remediator's to edit after the join, never this shard's: counted
# as a citation it read as a second shard claiming a sibling's file (DOUBLE) or as a claimed edit
# with no write (UNWRITTEN). So tokens are buffered per heading and dropped when the entry under it
# is dispositioned escalated. Measured over graph's s317/s318 shard parts: 15 of 66 escalated
# entries carry a path on `edit:`.
part_cites() {
  local _toks _t
  _toks="$(awk '
    function emit(   i) { if (disp !~ /^escalat/) for (i = 1; i <= nt; i++) print tk[i]; nt = 0; disp = "" }
    /^#+[ \t]/ { emit(); next }
    /^[[:space:]-]*[*_`]*disposition[*_`]*:/ {
      disp = tolower($0); sub(/^[^:]*:/, "", disp); gsub(/[*_`]/, "", disp); sub(/^[ \t]+/, "", disp); next }
    /^[[:space:]-]*[*_`]*edit[*_`]*:/ {
      line = $0; sub(/^[^:]*:/, "", line)
      while (match(line, /[A-Za-z0-9_.\/-]+[.](md|json|jsonl|yaml|yml|txt|csv)/)) {
        tok = substr(line, RSTART, RLENGTH); gsub(/\/\/+/, "/", tok); tk[++nt] = tok
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END { emit() }' "$1" | sort -u)"
  while IFS= read -r _t; do
    [ -n "$_t" ] || continue
    _t="${_t#"$STATE_PARENT"}"; _t="${_t#"$STATE_PARENT_P"}"
    # Subject mode: a part may cite the root-relative spelling `.subject` records; the ledger spells
    # the state dir by its basename.
    [ "$SUBJMODE" = 1 ] && case "$_t" in "${SREL}"/*) _t="${STATE_NAME}/${_t#"${SREL}"/}" ;; esac
    printf '%s\n' "$_t"
  done <<PCEOF
$_toks
PCEOF
}
# resolve_cites <ledger paths> <tokens> -> the written file each token names (equal, or a `/`-suffix
# of exactly one), the coverage join's own rule below; a token naming none or several prints nothing.
resolve_cites() {
  { printf '%s\n' "$1" | sed '/^$/d; s/^/W\t/'; printf '%s\n' "$2" | sed '/^$/d; s/^/C\t/'; } | awk -F'\t' '
    $1 == "W" { if (!($2 in s)) { s[$2] = 1; P[++np] = $2 }; next }
    { n = 0; for (i = 1; i <= np; i++) { p = P[i]
        if (p == $2 || (length(p) > length($2) && substr(p, length(p) - length($2)) == "/" $2)) { n++; h = p } }
      if (n == 1) print h }' | sort -u
}

# --- THE DETAILED ROWS: every row (not unique per writer) with its ts and the hook's evidence keys.
# Read only when a --rerun narrows the window or the distinct-writer arm already has an overlap to
# test for an alias; otherwise ROWS above is the whole input and the default join is unchanged.
# Fields: path, agent, ts, session, tool_use_id, transcript_path, agent_transcript; `-` for empty.
DROWS=""; RR_SUPERSEDED=0; RR_LINES=""; AL_LINES=""; AL_N=0
_ovl0="$(printf '%s\n' "$ROWS" | awk -F'\t' 'NF >= 2 { n[$1]++ } END { for (f in n) if (n[f] > 1) { print f; exit } }')"
if [ -n "$RERUN" ] || [ -n "$_ovl0" ]; then
  DROWS="$(jq -rn --arg since "$SINCE" --arg until "$UNTIL" --arg ap "$APATH" --arg sh "$SHARD_REL" --arg doc "$_jdoc" '
    def d: if . == null or . == "" then "-" else tostring end;
    inputs | select(type == "object") | select(.kind == "artifact-write")
     | select((.agent_id // "") != "") | select((.ts | type) == "string")
     | select(.ts >= $since and .ts <= $until)
     | select(.path == $ap or (.path | startswith($ap + "/")))
     | select($doc == "1" or ((.path | startswith($sh + "/")) | not))
     | [.path, .agent_id, .ts, (.session | d), (.tool_use_id | d), (.transcript_path | d),
        (if has("agent_transcript") then (.agent_transcript | tostring) else "-" end)] | @tsv' "$LEDGER" 2>/dev/null)" \
    || die "the write ledger ${LEDGER} does not parse as JSON lines"
  # Subject mode kept only the subject's file set; keep the same paths here.
  DROWS="$({ printf '%s\n' "$ROWS" | sed '/^$/d; s/^/K\t/'; printf '%s\n' "$DROWS" | sed '/^$/d; s/^/D\t/'; } | awk -F'\t' '
    $1 == "K" { k[$2] = 1; next } ($2 in k) { print substr($0, 3) }')"
fi

# --- RE-RUN NARROWING (see "RE-RUN OF ONE PART"). F_P resolves against the UNNARROWED rows.
if [ -n "$RERUN" ]; then
  _rspec=""; _rseen=" "
  _allpaths="$(printf '%s\n' "$ROWS" | awk -F'\t' 'NF >= 2 { print $1 }' | sort -u)"
  while IFS= read -r _r; do
    [ -n "$_r" ] || continue
    case "$_r" in *@*) ;; *) refuse "--rerun ${_r} is not <part>.md@<ISO>"; continue ;; esac
    _rp="${_r%@*}"; _rs="${_r##*@}"
    # shellcheck disable=SC2254
    case "$_rs" in $ISO) ;; *) refuse "--rerun ${_r}: the re-run start must be YYYY-MM-DDTHH:MM:SSZ (got '${_rs}')"; continue ;; esac
    if [ "$_rs" \< "$SINCE" ] || [ "$_rs" \> "$UNTIL" ]; then
      refuse "--rerun ${_r}: the re-run start ${_rs} is outside the window [${SINCE}, ${UNTIL}]"; continue
    fi
    case "$_rseen" in *" ${_rp} "*) refuse "--rerun names ${_rp} twice; one part has one re-run start"; continue ;; esac
    _rseen="${_rseen}${_rp} "
    _rpf="$(printf '%s\n' "$PARTS" | awk -v b="$_rp" '{ n = $0; sub(/.*\//, "", n) } n == b { print; exit }')"
    [ -n "$_rpf" ] || { refuse "--rerun ${_r}: ${_rp} is not a part under ${SHARD_DIR}"; continue; }
    _rfp="$(resolve_cites "$_allpaths" "$(part_cites "$_rpf")")"
    [ -n "$_rfp" ] || { refuse "--rerun ${_r}: ${_rp} cites no file written in the window, so it has nothing to re-run"; continue; }
    _rspec="${_rspec}$(printf '%s\n' "$_rfp" | awk -v p="$_rp" -v s="$_rs" '{ print "R\t" p "\t" s "\t" $0 }')
"
  done <<RREOF
$RERUN
RREOF
  if [ -n "$_rspec" ]; then
    # THE PART RECORDS: rows on `<repair dir>/<part>.md`, non-recursive, in the outer window. They sit
    # outside every mode's file set (shards/ is dropped in files mode; document and subject mode keep
    # only section copies and subject files), so the authorship of the account is read here alone.
    _prpfx="${SHARD_REL}/${SHARD_DIR##*/}/"
    _prrows="$(jq -rn --arg since "$SINCE" --arg until "$UNTIL" --arg px "$_prpfx" '
      inputs | select(type == "object") | select(.kind == "artifact-write")
       | select((.agent_id // "") != "") | select((.ts | type) == "string")
       | select(.ts >= $since and .ts <= $until)
       | select((.path | type) == "string" and (.path | startswith($px)))
       | (.path | ltrimstr($px)) as $b | select(($b | contains("/") | not) and ($b | endswith(".md")))
       | [$b, .agent_id, .ts] | @tsv' "$LEDGER" 2>/dev/null)" \
      || die "the write ledger ${LEDGER} does not parse as JSON lines"
    _rres="$({ printf '%s' "$_rspec"; printf '%s\n' "$DROWS" | sed '/^$/d; s/^/D\t/'; printf '%s\n' "$_prrows" | sed '/^$/d; s/^/Q\t/'; } | awk -F'\t' -v px="$_prpfx" '
      $1 == "R" { if (!($2 in S)) { S[$2] = $3; PP[++npp] = $2 }; inF[$2, $4] = 1; nf[$2]++; F[$2, nf[$2]] = $4; fp[$4] = $2; next }
      $1 == "D" { nr++; for (j = 2; j <= NF; j++) r[nr, j - 1] = $j; next }
      $1 == "Q" { nq++; qb[nq] = $2; qa[nq] = $3; qt[nq] = $4; next }
      END {
        # Pass 1: rows on a re-run file before its start are superseded; their writers are the superseded writers of P.
        for (i = 1; i <= nr; i++) {
          f = r[i, 1]; a = r[i, 2]; t = r[i, 3]
          if ((f in fp) && t < S[fp[f]]) {
            p = fp[f]; drop[i] = 1; sw[p, a] = 1
            k = p SUBSEP f; sn[k]++
            if (!((k, a) in sid)) { sid[k, a] = 1; sids[k] = (k in sids) ? sids[k] " " a : a }
            if (!(k in sf) || t < sf[k]) sf[k] = t
            if (!(k in sl) || t > sl[k]) sl[k] = t
          }
        }
        # Pass 2: every row of a superseded writer, over the whole file set.
        for (i = 1; i <= nr; i++) {
          f = r[i, 1]; a = r[i, 2]; t = r[i, 3]
          for (q = 1; q <= npp; q++) { p = PP[q]
            if (!((p, a) in sw)) continue
            if (!((p, f) in inF)) print "OUT\t" p "\t" a "\t" f "\t" t
            if (t >= S[p]) {
              if ((p, f) in inF) { if (!((p, a) in same)) { same[p, a] = 1; print "SAME\t" p "\t" a "\t" f "\t" t } }
              else print "LATE\t" p "\t" a "\t" f "\t" t
            }
          }
          if (!(i in drop)) { l = r[i, 1]; for (j = 2; j <= 7; j++) l = l "\t" r[i, j]; print "K\t" l }
        }
        # The RE-RUN WRITERS of P: every writer of a row on F_P at or after S_P.
        for (i = 1; i <= nr; i++) {
          f = r[i, 1]; a = r[i, 2]; t = r[i, 3]
          if ((f in fp) && t >= S[fp[f]]) rw[fp[f], a] = 1
        }
        # The re-run writer is a NEW dispatch: no row on a file outside F_P, in any part or none.
        for (i = 1; i <= nr; i++) {
          f = r[i, 1]; a = r[i, 2]; t = r[i, 3]
          for (q = 1; q <= npp; q++) { p = PP[q]
            if (((p, a) in rw) && !((p, f) in inF) && !((p, a, f) in rwo)) { rwo[p, a, f] = 1; print "RWOUT\t" p "\t" a "\t" f "\t" t }
          }
        }
        # The part records: who wrote which account, and when.
        for (i = 1; i <= nq; i++) {
          b = qb[i]; a = qa[i]; t = qt[i]
          for (q = 1; q <= npp; q++) { p = PP[q]
            if ((p, a) in sw) {
              if (t >= S[p] && !((p, a, b, "L") in pq)) { pq[p, a, b, "L"] = 1; print "PRLATE\t" p "\t" a "\t" px b "\t" t }
              if (b != p && !((p, a, b, "O") in pq)) { pq[p, a, b, "O"] = 1; print "PROUT\t" p "\t" a "\t" px b "\t" t }
            }
            if (b == p && t >= S[p]) {
              if ((p, a) in rw) own[p] = 1
              else if (!((p, a, "F") in pq)) { pq[p, a, "F"] = 1; print "PRFOREIGN\t" p "\t" a "\t" px b "\t" t }
            }
            if (((p, a) in rw) && b != p && !((p, a, b, "R") in pq)) { pq[p, a, b, "R"] = 1; print "RWOUT\t" p "\t" a "\t" px b "\t" t }
          }
        }
        for (q = 1; q <= npp; q++) { p = PP[q]; if (!(p in own)) print "PRNONE\t" p "\t" px p }
        for (q = 1; q <= npp; q++) { p = PP[q]; ln = "rerun: " p " since " S[p]
          for (m = 1; m <= nf[p]; m++) { f = F[p, m]; k = p SUBSEP f
            if (k in sn) { ln = ln "; superseded on " f ": " sids[k] " (" sn[k] " rows, " sf[k] ".." sl[k] ")"; ns += sn[k] }
            else ln = ln "; superseded on " f ": none" }
          print "L\t" ln }
        print "N\t" ns + 0
      }')"
    while IFS='	' read -r _k _a _b _c _d; do
      case "$_k" in
        OUT)  refuse "--rerun ${_a}: ${_b} is a superseded writer of ${_a} and also wrote ${_c} at ${_d}, outside the files ${_a} cites; it was not only ${_a}'s writer, so its earlier writes cannot be set aside" ;;
        LATE) refuse "--rerun ${_a}: ${_b} is a superseded writer of ${_a} and wrote ${_c} at ${_d}, at or after the re-run start; the original is still writing" ;;
        SAME) refuse "--rerun ${_a}: ${_b} wrote ${_c} both before the re-run start and at ${_d}, after it; the re-run is a NEW dispatch, and its writer must not be one of the writers it supersedes" ;;
        PRLATE) refuse "--rerun ${_a}: ${_b} is a superseded writer of ${_a} and wrote the part record ${_c} at ${_d}, at or after the re-run start; a superseded writer writes no account after it is superseded" ;;
        PROUT) refuse "--rerun ${_a}: ${_b} is a superseded writer of ${_a} and also wrote ${_c} at ${_d}, another part's record; it was not only ${_a}'s writer, so its earlier writes cannot be set aside" ;;
        PRFOREIGN) refuse "--rerun ${_a}: ${_b} wrote ${_a}'s own part record ${_c} at ${_d}, at or after the re-run start, and is not its re-run writer; the covering account is the re-run writer's alone" ;;
        PRNONE) refuse "--rerun ${_a}: no row on ${_a}'s own part record ${_b} at or after the re-run start was written by its re-run writer; the account covering the superseded bytes must be the re-run's" ;;
        RWOUT) refuse "--rerun ${_a}: ${_b}, the re-run writer of ${_a}, also wrote ${_c} at ${_d}, which belongs to no file ${_a} cites; the re-run is a NEW dispatch, never a finished part's agent" ;;
        L) RR_LINES="${RR_LINES}${_a}
" ;;
        N) RR_SUPERSEDED="$_a" ;;
      esac
    done <<RROUT
$(printf '%s\n' "$_rres" | grep -v '^K	')
RROUT
    DROWS="$(printf '%s\n' "$_rres" | sed -n 's/^K	//p')"
    ROWS="$(printf '%s\n' "$DROWS" | awk -F'\t' 'NF >= 2 { print $1 "\t" $2 }' | sort -u)"
  fi
fi

# --- THE ALIAS RULE (see "AN ALIAS IS ONE WRITER"). Tested only on a file the narrowed rows still
# give two or more writers; rows without the hook's evidence keys never enter it.
# hook_norm <file_path> -> the ledger spelling record_artifact_write gives it, or nothing.
# Cuts at the FIRST `<state-dir-name>/` in the path, so a nested repeat of that name mis-spells: fails safe (no alias).
hook_norm() {
  local _n="${_STATE_DIR%/}"; _n="${_n##*/}"
  case "$1" in
    "$STATE"/planning-artifacts/*|"$STATE"/specs/s[0-9]*/*) printf '%s\n' "${_n}/${1#"$STATE"/}" ;;
    */"${_n}"/planning-artifacts/*|*/"${_n}"/specs/s[0-9]*/*) printf '%s\n' "${_n}/${1#*/"${_n}"/}" ;;
    "${_n}"/planning-artifacts/*|"${_n}"/specs/s[0-9]*/*) printf '%s\n' "$1" ;;
  esac
}
# tu_blocks <transcript> <tool_use_id> -> "<name>\t<input.file_path>" per ASSISTANT tool_use block with
# that id, parsed structurally: a tool_result or any prose quoting the id is not a block.
tu_blocks() {
  [ -f "$1" ] || return 0
  jq -nrR --arg id "$2" '
    inputs | fromjson? | select(type == "object" and .type == "assistant")
    | (.message | if type == "object" then .content else null end)
    | if type == "array" then .[] else empty end
    | select(type == "object" and .type == "tool_use" and (.id // "") == $id)
    | [(.name // "" | tostring), (.input.file_path // "" | tostring)] | @tsv' "$1" 2>/dev/null
}
if [ -n "$DROWS" ]; then
  _ovl="$(printf '%s\n' "$DROWS" | awk -F'\t' 'NF >= 2 && !(($1, $2) in s) { s[$1, $2] = 1; n[$1]++ } END { for (f in n) if (n[f] > 1) print f }' | sort)"
  _drop=""; _evid=""
  while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    _ws="$(printf '%s\n' "$DROWS" | awk -F'\t' -v f="$_f" '$1 == f { print $2 }' | sort -u)"
    _fdone=0
    while IFS= read -r _A; do
      [ -n "$_A" ] && [ "$_fdone" = 0 ] || continue
      _nA="$(printf '%s\n' "$DROWS" | awk -F'\t' -v a="$_A" '$2 == a { n++ } END { print n + 0 }')"
      _rA="$(printf '%s\n' "$DROWS" | awk -F'\t' -v a="$_A" -v f="$_f" '$1 == f && $2 == a { print; exit }')"
      IFS='	' read -r _p _a _ts _sess _tuid _tpath _atr <<RAEOF
$_rA
RAEOF
      [ "$_nA" = 1 ] && [ "$_tuid" != "-" ] && [ "$_atr" = false ] && [ "$_tpath" != "-" ] && [ "$_sess" != "-" ] || continue
      _sd="${_tpath%.jsonl}"
      [ -e "${_sd}/subagents/agent-${_A}.jsonl" ] && continue
      while IFS= read -r _B; do
        [ -n "$_B" ] && [ "$_B" != "$_A" ] || continue
        _bs="$(printf '%s\n' "$DROWS" | awk -F'\t' -v f="$_f" -v b="$_B" '$1 == f && $2 == b { print $4 }' | sort -u)"
        [ "$_bs" = "$_sess" ] || continue
        _blk="$(tu_blocks "${_sd}/subagents/agent-${_B}.jsonl" "$_tuid")"
        [ "$(printf '%s\n' "$_blk" | grep -c .)" = 1 ] || continue
        _bn="${_blk%%	*}"; _bfp="${_blk#*	}"
        case "$_bn" in Edit|Write|MultiEdit) ;; *) continue ;; esac
        [ "$(hook_norm "$_bfp")" = "$_f" ] || continue
        _drop="${_drop}${_f}	${_A}
"
        AL_N=$((AL_N + 1))
        AL_LINES="${AL_LINES}alias: ${_A}'s row on ${_f} (${_ts}, tool_use_id ${_tuid}) is ${_B}'s write; its one tool_use with that id is in ${_sd}/subagents/agent-${_B}.jsonl and ${_A} has no transcript
"
        _fdone=1
        break
      done <<RBEOF
$_ws
RBEOF
    done <<RWEOF
$_ws
RWEOF
  done <<ROEOF
$_ovl
ROEOF
  if [ -n "$_drop" ]; then
    DROWS="$({ printf '%s' "$_drop" | sed 's/^/X\t/'; printf '%s\n' "$DROWS" | sed '/^$/d; s/^/D\t/'; } | awk -F'\t' '
      $1 == "X" { x[$2, $3] = 1; next } !(($2, $3) in x) { print substr($0, 3) }')"
    ROWS="$(printf '%s\n' "$DROWS" | awk -F'\t' 'NF >= 2 { print $1 "\t" $2 }' | sort -u)"
  fi
  # A file still overlapping: name the evidence of every writer whose rows carry the hook's keys.
  _ovl="$(printf '%s\n' "$DROWS" | awk -F'\t' 'NF >= 2 && !(($1, $2) in s) { s[$1, $2] = 1; n[$1]++ } END { for (f in n) if (n[f] > 1) print f }' | sort)"
  while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    _ws="$(printf '%s\n' "$DROWS" | awk -F'\t' -v f="$_f" '$1 == f { print $2 }' | sort -u)"
    while IFS= read -r _A; do
      [ -n "$_A" ] || continue
      _nA="$(printf '%s\n' "$DROWS" | awk -F'\t' -v a="$_A" '$2 == a { n++ } END { print n + 0 }')"
      _rA="$(printf '%s\n' "$DROWS" | awk -F'\t' -v a="$_A" -v f="$_f" '$1 == f && $2 == a && $5 != "-" { print; exit }')"
      [ -n "$_rA" ] || continue
      IFS='	' read -r _p _a _ts _sess _tuid _tpath _atr <<RAEOF
$_rA
RAEOF
      _ex="no transcript_path recorded"; _hold="none"
      if [ "$_tpath" != "-" ]; then
        _sd="${_tpath%.jsonl}"
        if [ -e "${_sd}/subagents/agent-${_A}.jsonl" ]; then _ex="exists (${_sd}/subagents/agent-${_A}.jsonl)"; else _ex="absent (agent_transcript ${_atr} at write time)"; fi
        _hold=""
        while IFS= read -r _B; do
          [ -n "$_B" ] || continue
          _bt="${_sd}/subagents/agent-${_B}.jsonl"
          _c="$(tu_blocks "$_bt" "$_tuid" | grep -c .)" || _c=0
          [ "$_c" -gt 0 ] && _hold="${_hold}${_hold:+, }${_bt} (${_c} block(s))"
        done <<RHEOF
$_ws
RHEOF
        [ -n "$_hold" ] || _hold="no writer's transcript"
      fi
      refuse "${_f}: ${_A}'s row at ${_ts} is not an alias of another writer (tool_use_id ${_tuid}; ${_A}'s transcript ${_ex}; ${_A} has ${_nA} row(s) in the file set; the id is held by ${_hold})"
    done <<RWEOF
$_ws
RWEOF
  done <<ROEOF
$_ovl
ROEOF
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
  while IFS= read -r _t; do
    [ -n "$_t" ] || continue
    CITES="${CITES}C	$(basename "$p")	${_t}
"
  done <<TOKEOF
$(part_cites "$p")
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

# The entry contract over every part, in every mode (BL-508 siblings, BL-519 set-aside).
contract_probe
set --
while IFS= read -r p; do [ -n "$p" ] && set -- "$@" "$p"; done <<CTPEOF
$PARTS
CTPEOF
contract_refusals 0 "$(contract_check 0 "$@")"

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
  # A re-run: one owner per file in ITS window, and every re-run's window and superseded writers named.
  _inwin="in that window"
  if [ -n "$RR_LINES" ]; then
    printf '%s' "$RR_LINES"
    echo "one owner per file in its window: a re-run part's cited files from its re-run start, every other file in the window above;"
    echo "earlier writes on re-run files are superseded, and the re-run part accounts for the whole section diff against the split slice;"
    _inwin="in its window"
  fi
  [ -z "$AL_LINES" ] || printf '%s' "$AL_LINES"
  if [ "$SUBJMODE" = 1 ]; then
    echo "every subject file and section copy was written by exactly one agent ${_inwin};"
    printf '%s\n' "$ASM_LINE" | sed 's/^/partition-subject.sh: /'
    echo ""
    echo "- artifact: ${_srm}"
    echo "- artifact_sha_before:${SUBJ_BEFORE}"
    echo "- artifact_sha_after:${SUBJ_AFTER}"
  elif [ "$DOCMODE" = 1 ]; then
    echo "every section under ${APATH} was written by exactly one agent ${_inwin};"
    echo "partition-document.sh: ${ASM_LINE}"
    echo ""
    echo "- artifact: ${DOC_REL}"
    echo "- artifact_sha_before: ${DOC_BEFORE}"
    echo "- artifact_sha_after: ${DOC_AFTER}"
  else
    echo "every file under ${APATH} outside ${SHARD_REL}/ was written by exactly one agent ${_inwin}."
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
_jx=""
[ -z "$RERUN" ] || _jx=", ${RR_SUPERSEDED} superseded rows"
[ "$AL_N" = 0 ] || _jx="${_jx}, ${AL_N} alias rows"
echo "JOINED: ${OUT} ($(printf '%s\n' "$PARTS" | grep -c .) parts, $(printf '%s\n' "$WRITERS" | grep -c .) writers${_jx})"
# Every escalated entry, by part, and the count; then the repaired edits whose cross-file siblings
# and moved cites only the serial remediator can check. Either count above 0 dispatches the serial
# remediator, in every mode, with every ESCALATED: line in its brief (_gate-procedures.md,
# "Adversarial repair dispatch").
printf '%s' "$ESC_LINES"
echo "ESCALATED-COUNT: ${ESC_N}"
echo "SERIAL-REQUIRED: ${SERIAL_N}"
exit 0
