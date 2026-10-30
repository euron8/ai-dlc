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
#   join-remediator-shards.sh --agent-writes <agent_id> [--since <ISO>]
#       An EXCLUSIVE mode, like --sources and --escalations: it takes no other flag and joins
#       nothing. It prints, sorted and unique, each `path` that ONE agent wrote according to the
#       write ledger (rows `kind: "artifact-write"`, `agent_id` equal to <agent_id>, and `ts` at or
#       after --since when given), then one trailer line stating what the ledger cannot see: Bash
#       writes, and writes outside planning-artifacts/, specs/s<N>/, gate-adjudication part files
#       and the documents sections split manifests name. A handoff runs it for each
#       stopped agent, with the `TaskStop` task_id as <agent_id>, so the agent's partial edits are
#       read from the ledger and never inferred from `git status`. An agent with no rows, or a
#       missing ledger, prints the trailer alone and exits 0; a malformed id exits 2.
#
#   join-remediator-shards.sh --check-part <part.md>
#       An EXCLUSIVE mode, like --agent-writes: it takes no other flag and joins nothing. It runs
#       the join's own entry contract (contract_probe, contract_check and contract_refusals, parts
#       mode) over ONE part, so a remediator checks its part before `--mark` with the classifier the
#       join will apply. Each finding is the join's own REFUSED line (a BADSIB is byte-identical);
#       the missing-field remedy names the field and this re-check, never a re-dispatch. Exit 0
#       with one `CHECK-PART:` line when the contract holds, 2 otherwise. No ledger, seal or seat
#       file is read: disjointness and citations are the join's alone.
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
#   - an ARTIFACT that ends in `-adversarial`, in files mode and document mode (the dir or
#     --artifact): the adversarial repair record carries no round word, so its owed name is
#     `<artifact minus -adversarial>-repair-p<M>` for the shard dir and the record, and arm H of
#     validate-adversarial-convergence.sh reads only that name. --subject names are fixed by the
#     script and are untouched;
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
#   - an existing `<artifact>-repair-p<M>.md` (a join never overwrites a record);
#   - a part record or section copy whose bytes differ from its newest content-seal row, i.e. one
#     amended through Bash after its last Write or Edit (THE CONTENT SEAL; `content-seal.sh` owns it).
#     `--sources` and `--escalations` refuse the same way, at mode entry, a RECORD whose bytes differ
#     from its newest seal row (this join's program row, or the serial remediator's later Edit).
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
#     the re-run writer at all (the covering account is then the re-run's); the re-run writer with a
#     row on any file or part record outside F_P and P's own record in the outer window -- a
#     finished part's agent is not a new dispatch.
#   - THE RE-RUN WRITER. When F_P has a row at or after S_P, it is every writer of F_P at or after
#     S_P, and RECW (the agents that wrote P's own record at or after S_P) must be among them -- the
#     foreign-record refusal above. When F_P has none, the re-run is RECORD-ONLY (the cure was a
#     record change): nothing on F_P is superseded, its earlier writers' rows STAND and still need
#     exactly one writer, and the re-run writer is RECW, which must be exactly one agent that is not
#     one of F_P's writers before S_P; either refusal names the record. The record line reads
#     `rerun: <part> since <S_P>; record-only, by <id>; kept on <file>: <ids> (<n> rows, ..)`.
#     A nested writer folds into its dispatcher before any of this is read, so a re-run writer's
#     own subagent editing F_P is the re-run writer.
#     Residual, stated: the record-only decision is per PART, over all of F_P, so a re-run that edits
#     one of two cited files supersedes both, and the unedited one then reads UNWRITTEN.
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
# A NESTED WRITER IS ITS DISPATCHER'S, ONE LEVEL UP AND ONLY ON TWO LEDGER ROWS. A remediator that
#   spawns a subagent of its own gets that subagent's writes under the subagent's agent id A. The
#   join folds A into its dispatcher P when A's own chain resolves:
#     1. `<state>/subagent-context.jsonl` (ai-dlc-subagent-probe.sh) holds a row with agent_id A,
#        and every such row carries one non-empty tool_use_id T;
#     2. `<state>/spawn-ledger.jsonl` (ai-dlc-dispatch-guard.sh) holds a row with tool_use_id T that
#        HAS the `parent_agent_id` key, and its value P is one non-empty id other than A.
#   `parent_agent_id: ""` is the lead's own dispatch and folds nothing; a row with no such key was
#   written by an older guard and folds nothing either. The fold is ONE level: P's own chain is never
#   consulted. It is applied where the detailed rows are built, to every row of A (the file rows and
#   the part-record rows a --rerun reads), so the re-run, alias and distinct-writer arms all see P.
#   Every fold is named in the JOINED output and in the record: `nested: <A> is <P>'s subagent
#   (spawn <T>); its <n> rows on <files> are counted as <P>`. A writer whose chain does not resolve
#   stays its own writer, and a file it shares is refused naming, per writer, the ledger that lacked
#   the row.
#   Residual, stated: two children of one dispatcher, run in parallel and editing one file, read as
#   ONE writer. The fold cannot tell them apart, because both resolve to P.
#   No fold is owed elsewhere: merge-adversarial-shards.sh refuses a nested writer earlier, on role
#   (an adversary is a leaf and spawns nothing), and validate-gate-adjudication.sh counts no writers.
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
GAP_LINES=""; GAP_N=0
# Every variable record_tail prints has a global default: contract_refusals assigns them, and a run
# that never reaches it must print empty under `set -u`, never die naming an unbound variable.
CHAIN_LINES=""; ESC_SUP=""; ESC_LINES=""; ESC_CLOSED=""; ESC_N=0; ESC_X=0
refuse() { echo "REFUSED: $*" >&2; refuse_n=$((refuse_n + 1)); }
die() { echo "REFUSED: $*" >&2; exit 2; }
# lane_name <round-1 record basename> -> "<lane artifact>\t<pass>", the ONE derivation of a lane
# round's name (BL-716): `<x>-repair-p<M>.md` -> `<x>-serial` and `<M>`; `<x>-repair.md` (the
# subject's party and elicitation records) -> `<x>-serial` and `1`. The lane join run as
# `--artifact <lane artifact> --pass <pass>` writes `<lane artifact>-repair-p<pass>.md`, which is the
# sibling `--sources`/`--escalations` require after this record, and a `*-party-serial` name turns
# the `source:` rule on. Parts mode prints it as `LANE-ARTIFACT:` so the lead copies it: inferred
# from the subject's `requirements` it names another round's lane record. Exit 1 on a lane record
# or a name of neither shape.
lane_name() {
  case "$1" in
    *-serial-repair-p*.md) return 1 ;;
    *-repair-p*.md) _ln_p="${1##*-repair-p}"; printf '%s-serial\t%s\n' "${1%-repair-p*}" "${_ln_p%.md}" ;;
    *-repair.md) printf '%s-serial\t1\n' "${1%-repair.md}" ;;
    *) return 1 ;;
  esac
}

SPRINT=""; ARTIFACT=""; PASS=""; APATH=""; SINCE=""; UNTIL=""; DOCUMENT=""; REPDIR=""; DOCMODE=0
SUBJMODE=0; SUBJ_BASE=""; SRCMODE=0; SRC_REC=""; SRC_MORE=""; RERUN=""; AGENTMODE=0; AGENT_ID=""
PARTMODE=0; CHKPART=""
# --- THE DISPOSITION KEY (BL-823). ONE predicate, read by every site that recognises the key: src_check,
# contract_check (whose `dfull` BADDISP reads), checks_field's no-edit-line and repaired counts, the
# --escalations entry count, part_cites and esc_cites. Each awk takes it as `-v DK="$DISP_KEY_ERE"` and
# tests `$0 ~ DK`; the grep takes it as its pattern. No site spells the key itself, so none can drift.
# The key is recognised LOWERCASE in any form, as before, OR in ANY CASE on a LIST ITEM. A capitalised
# column-0 line is a SUMMARY, never a key: measured over graph main 91a665334 (1638 committed repair,
# fold and shard records under planning-artifacts), 7565 lowercase key lines, every one a list item, and
# 7 capitalised lines, none a list item -- s292 product-brief-repair-p1:7 and research-repair-p1:6
# (`**Disposition:** 4 repaired / 0 escalated.`), s302 architecture-repair-p1:424 (prose), s304
# derivation-hygiene-repair-p4:11 and s315 gate-planning-repair-p2:7, :56 and :100. Folding case on
# every line would read those as keys: a summary inside an entry overwrites its disposition. No
# backslash may enter this value: `awk -v` strips one level of escaping.
DISP_KEY_ERE='^([[:space:]-]*[*_`]*disposition|[[:space:]]*-[[:space:]]*[*_`]*[Dd][Ii][Ss][Pp][Oo][Ss][Ii][Tt][Ii][Oo][Nn])[*_`]*:'

# --- PARTY SOURCES (BL-462). Every applied entry names `source: <seat-file>#<finding-id>`, and the
# pair resolves against the sprint's seat files -- never the id alone, which collides across seats.
# src_ids <seat file>... -> "<basename>\t<finding id>" per finding heading (grammar: the header).
src_ids() {
  awk '
    FNR == 1 { fence = 0; b = FILENAME; sub(/.*\//, "", b); print b "\t" }
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { fence = 0; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ { fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
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
  toks="$(awk -v DK="$DISP_KEY_ERE" '
    function flush() { if (disp && !nsrc && !ruled) print "NOSOURCE\t" cf "\t" cur; if (disp) ne++; disp = 0; nsrc = 0; ruled = 0 }
    FNR == 1 { flush(); cur = "(before any heading)"; cf = FILENAME; sub(/.*\//, "", cf); fence = 0 }
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { fence = 0; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ { fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    fence { next }
    /^#+[ \t]/ { flush(); cur = $0; sub(/^#+[ \t]+/, "", cur); next }
    $0 ~ DK { disp = 1; v = tolower($0); sub(/^[^:]*:/, "", v); gsub(/[*_`]/, "", v); sub(/^[ \t]+/, "", v)
      sub(/[^a-z-].*$/, "", v); ruled = (v == "operator-ruling"); next }
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
# line, no carriage return, outside an unclosed fence (opened by 3+ backticks whose info string
# carries no backtick, or by 3+ tildes; closed only by the opener's character, at least as long).
# seat_marked <file> -> 0 iff it ends in the marker; prints the marker's <step> token.
SEAT_FENCE_AWK='
    function fence_line(   r) {
      if (!match($0, /^[ \t]*(```+|~~~+)/)) return 0
      r = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", r)
      if (fc == "") { if (substr(r, 1, 1) == "`" && substr($0, RSTART + RLENGTH) ~ /`/) return 0; fc = substr(r, 1, 1); fl = length(r) }
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
#   (3b) THE SUPERSEDES CHAIN (BL-565), RECORD MODES ONLY. An escalated entry restating an earlier
#       escalation carries `- supersedes: <part> <heading>`, trimmed as `closes:` is. The links make
#       chains, transitive, and a chain is counted ONCE, under its latest OPEN member; every other open
#       member prints `ESCALATED-SUPERSEDED: <part> <heading>` alone, so the line is copyable as a
#       `closes:` tail, and the chain is named on its own `CHAIN:` line. CLOSURE IS PER MEMBER, as
#       remediator.md has it ("an escalation with no `closes:` line of its own stays open"): a
#       `closes:` naming one member leaves the rest open, and that is FLAGGED on a `CHAIN-OPEN:` line
#       after ESCALATED-COUNT -- reported, never refused. A `supersedes:` naming no earlier escalation
#       in the record, a later one included, is refused as a dangling link; the count still prints.
#       Parts mode reads no `supersedes:` line. NOTE, stated: graph's filed s319 elicitation record
#       carries 0 `supersedes:` lines, so this join alone does not repair that instance; its count
#       reads the same on the base and here.
#   (4) SERIAL-REQUIRED, PARTS MODE ONLY. The count of `repaired` entries with a real edit (arm 1's
#       predicate; `edit: n/a` entries are not counted). Each one owes the serial remediator's
#       cross-file sibling grep and moved-cite check, which no shard can run, so the procedure
#       dispatches the serial remediator when it OR ESCALATED-COUNT is above 0, in every mode. Not
#       printed in --sources mode: that record may be the serial remediator's own.
#   (4b) SERIAL LANES (BL-716), PARTS MODE ONLY, printed after SERIAL-REQUIRED. One serial agent
#       working every item of a 19-part round in sequence is the cost; the serial guarantee is only
#       owed WITHIN a set of files that interact. So the join partitions the serial work into LANES:
#       connected components over FILES, never parts. A node is a file a part's `edit:` lines cite
#       (resolved as the coverage join resolves it), mapped to the file a serial remediator edits
#       after the join: itself in files mode, the assembled document in document mode, the subject
#       file in subject mode (a section copy to its file, `.memlog.md` to its SPEC). Edges: one part's
#       files are one lane; a MOVED-CITE (a cite in one file into a line another file's edit moved)
#       joins its two files. MOVED-CITE edges exist only where a worklist exists: document and
#       subject mode run `serial-remediation-worklist.sh <dir> --record <record> --keep` beside this
#       script after assembly, and files mode keeps no pre-repair copy, so it has none (the worklist
#       exits 3 there). A worklist exit other than 0, or a missing worklist, joins EVERY file into one
#       lane -- the status quo, never N lanes that might share an edge nobody measured -- and says so
#       on `LANE-EDGES: UNASSESSED`. A HIT never joins lanes: the fragment's hits all in one lane are
#       that lane's item, and hits in two or more lanes (s319's sprint-title `architecture_refs` line
#       HITs 18 stories) are ONE fan-in item. An escalation whose `edit:` files are one lane's is that
#       lane's; one naming files in two or more lanes, or a file no lane edits, or no file, goes to the
#       fan-in (s319 stories party repair: 10 of 46 escalations name two or more files). The fan-in
#       runs after every lane, so with two or more lanes it also owes one sweep over the assembled
#       files -- a lane's edit can create a hit elsewhere. Lines: `LANE-ARTIFACT: <name> --pass <M>`
#       (the lane round's `--artifact` and `--pass`, from lane_name), `LANE-EDGES:`, one `LANE: <n> files:
#       ... parts: ...` per lane, `LANE-ITEM: <n> <item>`, `FANIN: <item>`, `LANE-COUNT:`,
#       `FANIN-COUNT:`. Not printed in a record mode, nor for a lane round's own join (`--artifact
#       <name>-serial`): its escalations are the fan-in's, and lanes of lanes would recurse.
#   (6) THE DISPOSITION KEY AND ITS VOCABULARY (BL-542). Every check above keys on an entry's
#       `disposition:` line, so an entry that spells the key otherwise escaped all of them: graph's
#       s319 requirements-d-answers-fold.md renamed it `outcome:` on six entries and joined at exit
#       0. NODISP refuses an entry carrying an `edit:` line and no `disposition:` line, in every
#       mode. THE KEY IS `edit:` ALONE. A sha triple fires 474 times on legitimate record headings
#       over graph's s317-s319 corpus; `source:`, `derivation:` or `claim now asserted:` widen it
#       by three non-entries -- s317/shards/stories-adversarial-repair-serial-brief.md `## Record`,
#       s317/shards/stories-party-repair-brief.md `## Record format (exact)` and
#       s318/gate-sprint-review-repair-p2.md `### Sha-lock check` -- so they are not keyed.
#       BADDISP refuses a value outside repaired|escalated|skipped|not-reproduced|operator-ruling,
#       read with its hyphen kept (`not-reproduced`; a first-token read loses it). Before this,
#       a value such as `done` was read by no check at all. Parts mode refuses it unconditionally; a
#       record (--sources, --escalations) only from the siblings arm's positional era onward, so
#       the closed records already written are never re-checked. Graph's 60 top-level s317-s319
#       repair and fold records carry 64 off-vocabulary values in 9 of them (hyphen kept, fences
#       skipped), and every one sits before its record's era.
#       RULING: `operator-ruling` is an entry applying an operator's answer to the subject, so it
#       needs no seat `source:` (src_check exempts it from NOSOURCE) and carries `- ruling: <cite>`
#       instead, resolved by ruling_cite: an ISO stamp names an operator-requests-history.md heading
#       `## <ISO> -- (typed)`; 64 hex characters name an operator-answers-history.md `- SHA256:` line,
#       its `SHA256:` label and the blanks after it stripped first. Never a line number; an absent
#       history file resolves nothing. RECALL, STATED: a ruling given as a slash command is logged
#       `## <ISO> -- <command>`, and a typed request's `- SHA256:` line sits in the REQUESTS file;
#       neither form resolves, so such a ruling cannot be cited. No operator-ruling entry exists in
#       graph's corpus, so this refuses nothing today.
#       FALSE-POSITIVE SET, MEASURED by running this join (--escalations) over graph's 60 s317-s319
#       repair and fold records against 952b9319's, and this file's contract_check (parts mode) over
#       251 shard parts: 1 new refusal, the true positive above (6 NODISP); 0 BADDISP and 0 RULING
#       anywhere; parts mode 0. The adversary's parts-mode figure of 1 (s318
#       architecture-party-repair-p1/6.md) was a first-token read of its `not-reproduced`. Controls:
#       the same run read 1161 repaired lines in the parts, and a seeded `done` fires BADDISP.
#   (7) THE GAP-FILL TRIPWIRE (BL-556), A NOTE-TIER ARM, AND IT REPORTS, NEVER REFUSES. A `repaired`
#       entry whose `claim now asserted:` text says `gap fill` (`gap-fill`, `gapfill`) or `veto` is
#       printed as one `GAPFILL: <record> <entry> -- ...` line after the escalation count, in every
#       mode, and changes no exit code. It was a refusal first, and on graph's live s319 elicitation
#       repair record that refusal -- on the two true positives -- made --escalations exit 2 before
#       ESCALATED-COUNT, hiding all nine open escalations from the lead: a NOTE-tier arm must not
#       gate the report the lead adjudicates from. An agent that
#       applied a rule an operator decision does not state, and offered it for the lead's veto, wrote
#       an operator choice into the subject. Nothing in the record separates EXTENDING a D-/LR-/LRC-
#       decision from APPLYING one, so the arm keys on the words, and ITS RECALL DEPENDS ON THE AGENT
#       USING THOSE WORDS: a gap fill described any other way passes. THE LOCATION ONLY NARROWS IT:
#       when the entry's `edit:` cite resolves, the line gains `-- lands in <cite> under '<heading>',
#       which cites <token>` (or "cites no D-, LR- or LRC- decision"). The section is the nearest
#       heading at or above the line, to the next heading of the same or higher level; the token is
#       `D-<n>`, `LR-<x>` or `LRC-<x>`, word-bounded, outside fences, inside that section only. A live
#       file resolves as the siblings control does. Parts, --document and --subject modes run this
#       before assembly, so a `sections/<i>.md` cite is still a live copy there. In record mode the
#       copy is gone: the cite is matched by PART NUMBER (graph cites `sections/5.md`, the row and copy
#       were `05`) to the retained `.manifest`'s part row, and that row's span in its document is read,
#       said as "(span of <cite>, lines may have moved)". Neither resolves: `-- location unresolved
#       (<cite>)`. Never a refusal, and never an exit code. The FP set measured for the words above is
#       unchanged: 09.md F-4 and F-7 in the part and the same two in the joined record, all true
#       positives. Measured with this suffix on graph's real joined record, through the retained
#       manifest: F-4 lands at prd.md:1318 under 'Net P&L 24h triage and fix', which cites LR-S319-2
#       (the first decision token in the section wins, and it precedes D-5 on that line); F-7 lands at
#       prd.md:1354 under 'Merkl rewards cards', which cites no decision. So the location says where
#       an edit landed; it is no proof that the edit extended the decision the claim names.
#       FALSE-POSITIVE SET, MEASURED with this contract_check, parts mode over graph's 251 s317-s319
#       shard parts and record mode over its 60 repair and fold records: s319 requirements
#       elicitation repair 09.md F-4 and F-7, and the same two entries in the joined record, which is
#       the s319 gap-fill pair the entry was filed on; 0 others. An escalated entry saying the same
#       words is not reported (the self-probe's near-miss).
#   (8) THE CHECK FIELDS (BL-557). A remediator states under its sha triple whether the advisor ran,
#       `- advisor: called|unavailable`, and whether its derivations were replayed,
#       `- derivations: replayed <n>|not replayed|deferred to the join (section/subject shard)`;
#       checks_field reads them PER FILE, never per entry. `not replayed` is refused: the replay is
#       one validator call, and a part that skipped it hands the lead that call. Parts mode refuses
#       a part missing either line UNCONDITIONALLY, as the siblings arm does and for its reason; a
#       part holding no `repaired` entry is exempt, because it edited nothing and replayed nothing.
#       A record (--sources, --escalations) binds from its first GRAMMAR line -- a value leading
#       with `called`, `unavailable`, `replayed <n>`, `not replayed` or `deferred`, read after
#       emphasis, carriage returns and case are dropped, so a trailer the template licenses falls
#       away. A line whose value leads with no keyword is PROSE and opens nothing, because graph
#       already writes these labels as prose: `- derivations: the validator reports OK on the PRD
#       (148 derivations ...)` in s317 requirements-repair-adv-p1.md and -p2.md, and
#       `- advisor: one attempt was made ...` in four s317 adversary files. A first cut opened the
#       era on the LABEL; it refused both of those records, which the base passes, and a refusal
#       exits before ESCALATED-COUNT, so their escalations went unreported -- the tip adversary
#       found it. Inside a bound file a prose line is a value outside the grammar. NOT the siblings
#       era, either: 4 of the 60 records carry a siblings field and 0 carry a grammar line, so a
#       siblings-keyed era would refuse every live s319 record on the pull. THE LABEL IS
#       CASE-SENSITIVE, as arm H's repair_field is. Graph writes `Advisor:` capitalised in 37 files
#       beyond the 6 the lowercase label reaches; 18 of those lines lead with a keyword
#       (`Advisor: unavailable (rate-limited) ...`), and read case-insensitively they would bind
#       s317 stories-repair-p1.md and shards/stories-adversarial-repair-p1/20.md -- each carries a
#       lone advisor line and no derivations line, so each would refuse where the base passes.
#       THE SERIAL BLOCKS ARE SEGMENTED BY THEIR TERMINATORS, and the lines are counted PER SEGMENT,
#       never per file. After the last shard marker, the last part runs to the first
#       `- artifact:` triple that follows one of ITS ENTRIES -- an entry is its `disposition:`
#       line, and a non-entry `### ` heading is not one -- because the serial remediator opens
#       its block with its own triple (remediator.md) and the part's own triple sits above its
#       first entry. The serial block opens BY POSITION, never by counting triples. The first
#       block runs from that triple to the first column-0 `repair-complete:` line, and each later
#       block from the previous terminator to its own. A block closed by `repair-complete:
#       serial ...` OWES BOTH LINES whatever any era says: that line and the check-fields rule
#       shipped together, so a record carrying it was written under the rule. A
#       `repair-complete: spec-render ...` block owes neither; an unterminated tail is era-gated
#       like a part. A serial terminator before any triple that follows an entry of the last
#       part is refused by name: that block's lines cannot be told from the last part's. An
#       unmarked record owes the lines only in a block its serial terminator closes; with none
#       it is one era-gated segment, as before. The parts' lines never satisfy a serial block.
#       Each part and the text above the first marker are judged on their own, era-gated each:
#       a pre-rule part carrying neither line charges nothing, so a record whose parts predate
#       the rule is still read (graph s319 requirements-repair-p1, parts 01-12). FALSE-POSITIVE
#       SET, MEASURED with this checks_field over graph's 4 s319 records carrying
#       `repair-complete: serial` (8 blocks, c3-term.py beside it): 0 new findings; the one CHK
#       line in requirements-repair-p1 (a prose `derivations: replayed. ...` value in the
#       spec-render block) is read identically at the base. 0 of the 343 `.md` files under graph's
#       `shards/*repair*` dirs carry two triple lines (313 carry one, the control), so no part
#       carries a second triple of its own for the position rule to misread. THE DEFINITION THIS
#       REPLACES -- "the block after the last marker", in the cluster file -- still holds the last
#       part's own lines, and a last-triple read lends a block with no triple of its own
#       (requirements-repair-p1 serial 3) the lines of the block before it. HOLE, STATED: a
#       serial pass writing neither line AND no terminator is outside every era.
#       MEASURED with this join, serially, against 952b9319's over graph's 60 s317-s319 repair and
#       fold records in both record modes: 0 runs refused by a check field; the base printed an
#       escalation count and this join did not on 2 runs, both the BL-542 true positive (the
#       d-answers fold, 6 NODISP); the 11 other differing runs are --sources on a non-party record,
#       refused at the base and here, collapsed to the one --escalations line (BL-561). Over the 251
#       shard parts with this contract_check and checks_field: 230 parts lack both lines, the
#       pre-rule residual (251 minus the 21 holding no repaired entry, which are exempt); 0 values
#       outside the grammar; 0 `not replayed`. A control: the labelled lines in the corpus number 57,
#       in 43 files case-insensitively and 6 case-sensitively, and all 6 lowercase-labelled files are
#       prose-only (0 grammar-led, 0 mixing a grammar line with a prose one).
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
  awk -v src="$srcm" -v DK="$DISP_KEY_ERE" '
    BEGIN { SIBNA["n/a (insertion)"] = 1; SIBNA["n/a (deletion)"] = 1
            SIBNA["n/a (section shard; re-checked by the serial remediator after assembly)"] = 1
            VOC["repaired"] = 1; VOC["escalated"] = 1; VOC["skipped"] = 1; VOC["not-reproduced"] = 1
            VOC["operator-ruling"] = 1 }
    function trim(v) { gsub(/^[ \t`]+|[ \t`]+$/, "", v); return v }
    function vtrim(v) { gsub(/^[ \t*_`\r]+|[ \t*_`\r]+$/, "", v); return v }
    # AN OPERATOR-RULING ENTRY THAT EDITS IS HELD TO EVERY CHECK A REPAIRED EDIT IS: the siblings
    # field, the serial count, the control and the set-aside. Keyed on `repaired` alone, a ruling
    # with a real edit owed none of them (the third tip adversary). Closure and the gap-fill
    # tripwire stay keyed on `repaired`: a ruling is a rule the operator gave, never a gap fill.
    function flush(   i, k, rp) {
      if (disp != "") {
        ne++
        rp = (disp == "repaired" || dfull == "operator-ruling")
        if (edt) nedt++
        if (rp && edt) nrep++
        if (sibf) { nsib++; era = 1 }
        if (disp ~ /^escalat/) { nesc++; ef[nesc] = part; en[nesc] = cur; ex[nesc] = 0 }
        if (disp == "repaired" && src == 1)
          for (k = 1; k <= ncl; k++) for (i = 1; i <= nesc; i++) if (cl[k] == ef[i] " " en[i]) ex[i] = 1
        # A SUPERSEDES LINK names an EARLIER escalation of this record, byte-equal to its ESCALATED: tail;
        # one naming none, or a later one, is a dangling link (record modes only; sp is never filled in parts mode).
        if (disp ~ /^escalat/) for (k = 1; k <= nsp; k++) { mh = 0
          for (i = 1; i < nesc; i++) if (sp[k] == ef[i] " " en[i]) { nlk++; la[nlk] = i; lb[nlk] = nesc; mh = 1 }
          if (!mh) print "DANGLING\t" cf "\t" cur "\t" sp[k] }
        if (rp && edt && !sib) {
          if (sibf) print "BADSIB\t" cf "\t" cur
          else if (src == 0 || era) print "NOSIB\t" cf "\t" cur
          else npend++
        }
        if (rp && edt && sib && src == 0 && sfile != "") print "CTL\t" cf "\t" cur "\t" sfile "\t" stext
        if (rp && sev && claim ~ /outside (this|my|the) (shard|part|section)|not required/ \
            && claim !~ /escalat|serial remediator/) print "SETASIDE\t" cf "\t" cur "\t" hl
        if (disp == "repaired" && claim ~ /gap[- ]?fill|veto/) print "GAPFILL\t" cf "\t" cur (ecite != "" ? "\t" ecite : "")
        if ((src == 0 || era) && !(dfull in VOC)) print "BADDISP\t" cf "\t" cur "\t" draw
        if (dfull == "operator-ruling") print "RULING\t" cf "\t" cur "\t" rcite
      }
      if (disp == "" && edf) print "NODISP\t" cf "\t" cur
      disp = ""; dfull = ""; edt = 0; edf = 0; rcite = ""; sib = 0; sibf = 0; sibw = 0; sibin = 0; sfile = ""; stext = ""; claim = ""; inclaim = 0; ncl = 0; nsp = 0; ecite = ""
    }
    # THE CHAIN (BL-565): escalations joined by supersedes links, rooted at the LATEST member. The latest OPEN
    # member carries the one count of the chain; every other open member is SUP (printed ESCALATED-SUPERSEDED,
    # never counted); a chain holding a closed member and an open one is CHOPEN, reported, never refused.
    function fnd(x) { while (x in par) x = par[x]; return x }
    function chains(   k, a, b, i, rt) {
      for (k = 1; k <= nlk; k++) { a = fnd(la[k]); b = fnd(lb[k]); if (a != b) { if (a < b) par[a] = b; else par[b] = a } }
      for (i = 1; i <= nesc; i++) { rt = fnd(i); csz[rt]++
        if (ex[i]) mcl[rt] = (rt in mcl) ? mcl[rt] " ; " ef[i] " " en[i] : ef[i] " " en[i]
        else { lop[rt] = i; mop[rt] = (rt in mop) ? mop[rt] " ; " ef[i] " " en[i] : ef[i] " " en[i] }
        if (i != rt) mem[rt] = (rt in mem) ? mem[rt] " ; " ef[i] " " en[i] : ef[i] " " en[i] }
      for (i = 1; i <= nesc; i++) { rt = fnd(i); if (csz[rt] > 1 && !ex[i] && i != lop[rt]) print "SUP\t" ef[i] "\t" en[i] }
      for (rt = 1; rt <= nesc; rt++) if (csz[rt] > 1 && fnd(rt) == rt) {
        print "CHAIN\t" ef[rt] " " en[rt] "\t" mem[rt]
        if ((rt in mcl) && (rt in mop)) print "CHOPEN\t" mcl[rt] "\t" mop[rt] }
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
      ctext = substr(r, 1, i - 1); gsub(/\t/, " ", ctext); r = substr(r, i + 1); sub(/^[ \t]+/, "", r); sub(/[ \t]+$/, "", r)
      if (r != "" && r !~ /[ \t]/) cfile = r; else ctext = ""
    }
    FNR == 1 { flush(); cur = "(before any heading)"; sev = 0; hl = 0; cf = FILENAME; sub(/.*\//, "", cf); part = cf; fence = 0 }
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) {
      if (sibin) sibclose()
      fence = 0; inclaim = 0; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ {
      if (sibw) { b = $0; sub(/^[ \t]+/, "", b); sub(/[ \t]+$/, "", b); sibw = 0
                  if (b == "```text") { sibin = 1; srn = 0; sctl = 0; sn = "" } }
      fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; inclaim = 0; next }
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
    /^#+[ \t]/ { flush(); cur = $0; sub(/^#+[ \t]+/, "", cur); gsub(/[\t\r]/, " ", cur); cur = trim(cur); h = toupper($0); hl = FNR
                 sev = (h ~ /(^|[^A-Z])(CRITICAL|MAJOR)([^A-Z]|$)/); next }
    /^[ \t]*$/ { inclaim = 0; next }
    $0 ~ DK {
      v = tolower($0); sub(/^[^:]*:/, "", v); gsub(/[*_`]/, "", v); sub(/^[ \t]+/, "", v)
      split(v, a, /[^a-z]/); disp = a[1]; draw = v; gsub(/[\t\r]/, " ", draw); sub(/[ \t]+$/, "", draw); dfull = v; sub(/[^a-z-].*$/, "", dfull); inclaim = 0; next }
    /^[[:space:]-]*[*_`]*edit[*_`]*:/ {
      v = $0; sub(/^[^:]*:/, "", v); edf = 1
      if (match(v, /[A-Za-z0-9_.\/-]+[.](md|json|jsonl|yaml|yml|txt|csv)(:[0-9]+)?/)) ecite = substr(v, RSTART, RLENGTH)
      if (match(v, /[A-Za-z0-9_.\/-]+[.](md|json|jsonl|yaml|yml|txt|csv)/)) edt = 1
      inclaim = 0; next }
    /^[[:space:]-]*[*_`]*ruling[*_`]*:/ { v = $0; sub(/^[^:]*:/, "", v); rcite = vtrim(v); gsub(/\t/, " ", rcite); inclaim = 0; next }
    /^[[:space:]-]*[*_`]*siblings[*_`]*:/ { sibf = 1; v = $0; sub(/^[^:]*:/, "", v); v = vtrim(v); if (v == "") sibw = 1; else if (v in SIBNA) sib = 1; inclaim = 0; next }
    /^[[:space:]-]*[*_`]*closes[*_`]*:/ { v = $0; sub(/^[^:]*:/, "", v); sub(/^[*_`]+/, "", v); cl[++ncl] = trim(v); inclaim = 0; next }
    /^[[:space:]-]*[*_`]*supersedes[*_`]*:/ { if (src == 1) { v = $0; sub(/^[^:]*:/, "", v); sub(/^[*_`]+/, "", v); sp[++nsp] = trim(v) }; inclaim = 0; next }
    /^[[:space:]-]*[*_`]*claim now asserted[*_`]*:/ { claim = tolower($0); inclaim = 1; next }
    /^[[:space:]-]*[*_`]*[a-z][a-z _]*[*_`]*:/ { inclaim = 0 }
    inclaim { claim = claim " " tolower($0) }
    END {
      flush()
      if (nlk) chains()
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
# ruling_cite <record> <entry> <cite> -- an `operator-ruling` entry resolves its `- ruling:` cite
# against the operator's own record, never against a line number. Two forms: the ISO stamp of an
# operator-requests-history.md heading, which must exist as the exact heading `## <ISO> -- (typed)`;
# or the 64 hex characters of an operator-answers-history.md `- SHA256: <hex>` line, one literal
# `SHA256:` label stripped first as validate-scope-confirmation.sh strips it. A history file that
# is absent resolves nothing: an absent file is an unresolved cite, never nothing to check.
ruling_cite() {
  local r="$1" d="$2" c="$3" h n
  c="${c#SHA256:}"; c="${c#"${c%%[![:blank:]]*}"}"
  if [ -z "$c" ]; then
    refuse "${r}: the ${d} entry is dispositioned operator-ruling and carries no '- ruling:' cite; name the operator's answer as '- ruling: <ISO>' (an operator-requests-history.md heading) or '- ruling: <sha256>' (an operator-answers-history.md SHA256 line)"
    return
  fi
  # shellcheck disable=SC2254
  case "$c" in
    $ISO) h="${STATE}/operator-requests-history.md"
          n="$(grep -c -x -F -- "## ${c} -- (typed)" "$h" 2>/dev/null)" || n=0 ;;
    *) if [ "${#c}" = 64 ] && case "$c" in *[!0-9a-f]*) false ;; *) true ;; esac; then
         h="${STATE}/operator-answers-history.md"
         n="$(grep -c -x -F -- "- SHA256: ${c}" "$h" 2>/dev/null)" || n=0
       else
         refuse "${r}: the ${d} entry's ruling cite '${c}' is neither an ISO stamp nor 64 lowercase hex characters"; return
       fi ;;
  esac
  [ "$n" -ge 1 ] || refuse "${r}: the ${d} entry's ruling cite '${c}' resolves to nothing in ${h}; an operator-ruling applies an answer the operator gave, and the cite is how the join finds it"
}
# gap_section <file> <line> <lo> <hi> -> "<heading>\t<token>" for the section enclosing <line>: the nearest
# heading at or above it (not before <lo>), to the next heading of the same or higher level (not past <hi>);
# <token> is the first D-<n>, LR-<x> or LRC-<x> in it, word-bounded, outside fences, or empty. Nothing when
# <line> is outside [lo, hi] or the file has fewer lines.
gap_section() {
  awk -v L="$2" -v lo="$3" -v hi="$4" '
    function lvl(s) { match(s, /^#+/); return RLENGTH }
    NR < lo { next }
    NR > hi { exit }
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { fence = 0; t[NR] = ""; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ { fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; t[NR] = ""; next }
    { t[NR] = fence ? "" : $0 }
    !fence && /^#+[ \t]/ { if (NR <= L) { hs = NR; hv = lvl($0); hd = $0 } else if (hs && !he && lvl($0) <= hv) he = NR - 1 }
    END {
      if (L < lo || L > NR || L > hi) exit
      s = (hs ? hs : lo); e = (he ? he : (NR < hi ? NR : hi)); tok = ""
      for (i = s; i <= e && tok == ""; i++) {
        x = " " t[i] " "
        if (match(x, /[^[:alnum:]_-](D-[0-9]+|LRC?-[[:alnum:]][[:alnum:]-]*)[^[:alnum:]_]/)) tok = substr(x, RSTART + 1, RLENGTH - 2)
      }
      sub(/^#+[ \t]+/, "", hd); gsub(/[\t\r]/, " ", hd); sub(/[ ]+$/, "", hd)
      print (hs ? hd : "(before any heading)") "\t" tok
    }' "$1"
}
# gap_where <cite> -> the GAPFILL line's location suffix (BL-556), NOTE tier: it never refuses and changes no
# exit code. A LIVE file resolves under the project root, then the state dir's parent, then absolutely (the
# siblings control's order). A dead `<dir>/sections/<n>.md` -- assembly deletes the copies, so only the
# join itself sees them -- is looked up in `<dir>/sections/.manifest` by its PART NUMBER (5 matches a row
# 05 or 5; never a padded filename): its live copy `<row>.md` if present, else the row's span in the
# manifest's document, said to be a span. Neither: `location unresolved`.
gap_where() {
  local c="$1" f n p="" sd mf row ord a z doc out mode=live
  [ -n "$c" ] || return 0
  case "$c" in *:[0-9]*) f="${c%:*}"; n="${c##*:}" ;; *) printf ' -- location unresolved (%s, no line)' "$c"; return 0 ;; esac
  case "$f" in
    /*) [ -f "$f" ] && p="$f" ;;
    *) if [ -f "${JR_ROOT}/${f}" ]; then p="${JR_ROOT}/${f}"; elif [ -f "${STATE_PARENT}${f}" ]; then p="${STATE_PARENT}${f}"; fi ;;
  esac
  if [ -z "$p" ]; then
    case "$f" in
      */sections/*.md)
        sd="${f%/*}"; ord="${f##*/}"; ord="${ord%.md}"
        case "$ord" in ''|*[!0-9]*) ;; *)
          for mf in "${JR_ROOT}/${sd}/.manifest" "${STATE_PARENT}${sd}/.manifest" "${sd}/.manifest"; do [ -f "$mf" ] && break; done
          if [ -f "$mf" ]; then
            row="$(awk -F'\t' -v o="$ord" '$1 == "part" && ($2 + 0) == (o + 0) { print $2 "\t" $3 "\t" $4; exit }' "$mf")"
            doc="$(awk -F'\t' '$1 == "document" { print $2; exit }' "$mf")"
            if [ -n "$row" ]; then
              IFS='	' read -r ord a z <<ROWEOF
$row
ROWEOF
              if [ -f "${mf%/.manifest}/${ord}.md" ]; then p="${mf%/.manifest}/${ord}.md"
              elif [ -n "$doc" ] && [ -f "$doc" ]; then p="$doc"; mode=span; n=$((a + n - 1)); fi
            fi
          fi ;;
        esac ;;
    esac
  fi
  [ -n "$p" ] || { printf ' -- location unresolved (%s)' "$c"; return 0; }
  if [ "$mode" = span ]; then out="$(gap_section "$p" "$n" "$a" "$z")"; else out="$(gap_section "$p" "$n" 1 999999999)"; fi
  [ -n "$out" ] || { printf ' -- location unresolved (%s, line %s is outside the file)' "$c" "$n"; return 0; }
  local h="${out%%	*}" t="${out#*	}" w="$c"
  [ "$mode" = span ] && w="${doc}:${n} (span of ${c}, lines may have moved)"
  if [ -n "$t" ]; then printf " -- lands in %s under '%s', which cites %s" "$w" "$h" "$t"
  else printf " -- lands in %s under '%s', which cites no D-, LR- or LRC- decision" "$w" "$h"; fi
}
# contract_refusals <0 parts | 1 --sources> <contract_check output> -> refuse per finding;
# ESC_LINES / ESC_N carry the open escalated entries and ESC_CLOSED / ESC_X the closed ones, for the
# caller to print once the run has otherwise cleared; SERIAL_N counts the repaired entries with a
# real edit (the serial remediator's cross-file sibling grep and moved-cite check, after the join).
contract_refusals() {
  local srcm="$1" k r d l m q ne nedt nsib npend nosib="" remedy=""
  shift
  ESC_LINES=""; ESC_CLOSED=""; ESC_N=0; ESC_X=0; SERIAL_N=0; GAP_LINES=""; GAP_N=0; ne=0; nedt=0; nsib=0; npend=0
  ESC_SUP=""; CHAIN_LINES=""
  # A parts-mode refusal of a missing field is, for a round whose parts predate the install, the
  # pre-rule shape: the remedy is the re-dispatch, never a hand-added field.
  # --check-part runs on a part its remediator is still writing, so the remedy there is the field.
  if [ "$PARTMODE" = 1 ]; then remedy="; add the field to your part and run --check-part again"
  elif [ "$srcm" = 0 ]; then remedy="; parts written before the install: re-dispatch the shards"; fi
  while IFS='	' read -r k r d l m q; do
    case "$k" in
      N) ne="$r"; nedt="$d"; nsib="$l"; npend="$m"; SERIAL_N="${q:-0}" ;;
      SUP) ESC_SUP="${ESC_SUP}${r} ${d}
" ;;
      CHAIN) CHAIN_LINES="${CHAIN_LINES}CHAIN: ${r} supersedes ${d}
" ;;
      CHOPEN) CHAIN_LINES="${CHAIN_LINES}CHAIN-OPEN: closes: named ${r} and left ${d} open; one closes: line per chain member (team-roles/remediator.md)
" ;;
      DANGLING) refuse "${r}: the ${d} entry's 'supersedes: ${l}' names no earlier escalation in this record; copy it from the tail of that escalation's ESCALATED: line, which must precede it" ;;
      E) case "
${ESC_SUP}" in
           *"
${r} ${d}
"*) ESC_CLOSED="${ESC_CLOSED}ESCALATED-SUPERSEDED: ${r} ${d}
"; continue ;;
         esac
         ESC_N=$((ESC_N + 1)); ESC_LINES="${ESC_LINES}ESCALATED: ${r} ${d}
" ;;
      X) ESC_X=$((ESC_X + 1)); ESC_CLOSED="${ESC_CLOSED}ESCALATED-CLOSED: ${r} ${d}
" ;;
      NOSIB) nosib="${nosib}${r}	${d}
" ;;
      BADSIB) refuse "${r}: the ${d} entry is repaired with an edit and its 'siblings:' field is none of its four forms; write '- siblings:' then a \`\`\`text fence holding the '\$ grep -rn -F' over your shard's own files and the control '\$ grep -c -F' with its count, or 'n/a (section shard; re-checked by the serial remediator after assembly)', 'n/a (insertion)' or 'n/a (deletion)' (team-roles/remediator.md, \"Re-check every sibling of the text you replaced\")" ;;
      CTL) sib_control "$r" "$d" "$l" "$m" ;;
      SETASIDE) refuse "${r}:${l}: the ${d} entry is dispositioned repaired while its claim sets part of the fix aside as outside the shard or not required, and names no hand-off; a fix that lies outside your files is a second entry, disposition escalated, carrying the same source: token" ;;
      NODISP) refuse "${r}: the ${d} entry carries an 'edit:' line and no 'disposition:' line, so no check reads it; every entry that edits is dispositioned (team-roles/remediator.md), and a renamed key ('outcome:', 'status:') is not the field" ;;
      BADDISP) refuse "${r}: the ${d} entry is dispositioned '${l}', which is none of repaired|escalated|skipped|not-reproduced|operator-ruling; any other value is read by no check" ;;
      RULING) ruling_cite "$r" "$d" "$l" ;;
      GAPFILL) GAP_N=$((GAP_N + 1)); GAP_LINES="${GAP_LINES}GAPFILL: ${r} ${d} -- repaired while its claim calls the fix a gap fill or offers it for veto; a rule the decision's own words do not state is the operator's, so this entry should be escalated with options and the artifact keep the decision's words (team-roles/remediator.md, \"Applying such a decision\")$(gap_where "$l")
" ;;
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
  # The disposition key and its vocabulary (BL-542). Offenders: a renamed key over an edit, a value
  # outside the vocabulary, an operator-ruling with its cite. Near-misses on the same run: a
  # preamble heading with no edit:, and `not-reproduced`, whose hyphen a first-token read loses.
  printf '# preamble\n\n### F-1\n- outcome: done\n- edit: n/a\n\n### F-2\n- disposition: done\n- edit: n/a\n\n### F-3\n- disposition: not-reproduced\n- edit: n/a\n\n### F-4\n- disposition: operator-ruling\n- edit: n/a\n- ruling: 2026-01-01T00:00:00Z\n' > "$d/vocab.md"
  o="$(contract_check 0 "$d/vocab.md")"
  [ "$o" = "NODISP	vocab.md	F-1
BADDISP	vocab.md	F-2	done
RULING	vocab.md	F-4	2026-01-01T00:00:00Z
N	3	0	0	0	0" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: the disposition key and vocabulary read '${o}'; no verdict"; }
  # The gap-fill tripwire (BL-556): a repaired claim saying so fires; an escalated one does not.
  printf '### F-4\n- disposition: repaired\n- edit: n/a\n- claim now asserted: one pool down makes the total unavailable. This is a gap fill; the lead may veto it.\n\n### F-5\n- disposition: escalated\n- edit: n/a\n- claim now asserted: a gap fill the operator decides.\n' > "$d/gap.md"
  o="$(contract_check 0 "$d/gap.md")"
  [ "$o" = "GAPFILL	gap.md	F-4
E	gap.md	F-5
N	2	0	0	0	0" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: the gap-fill tripwire read '${o}'; no verdict"; }
  # The supersedes chain (BL-565), record mode: a serial escalation superseding a part escalation makes ONE
  # chain, the part member SUP and the latest the counted one; a closes: on the latest alone leaves the part
  # member open and flagged; a supersedes naming a LATER escalation is DANGLING. Near-miss: the same record
  # with no supersedes line reads two plain escalations, no chain.
  printf '<!-- shard: 01.md -->\n### F-1\n- disposition: escalated\n- edit: n/a\n\n### S-1\n- disposition: escalated\n- supersedes: 01.md F-1\n- edit: n/a\n\n### A-1\n- disposition: repaired\n- closes: 01.md S-1\n- edit: n/a\n\n### S-2\n- disposition: escalated\n- supersedes: 01.md S-3\n- edit: n/a\n\n### S-3\n- disposition: escalated\n- edit: n/a\n' > "$d/sup.md"
  o="$(contract_check 1 "$d/sup.md")"
  [ "$o" = "DANGLING	sup.md	S-2	01.md S-3
CHAIN	01.md S-1	01.md F-1
CHOPEN	01.md S-1	01.md F-1
E	01.md	F-1
X	01.md	S-1
E	01.md	S-2
E	01.md	S-3
N	5	0	0	0	0" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: the supersedes chain read '${o}'; no verdict"; }
  grep -v -e '^- supersedes:' "$d/sup.md" > "$d/nosup.md"
  o="$(contract_check 1 "$d/nosup.md")"
  [ "$o" = "E	01.md	F-1
X	01.md	S-1
E	01.md	S-2
E	01.md	S-3
N	5	0	0	0	0" ] || { rm -rf "$d"; die "the entry contract's self-probe failed: a record with no supersedes line read '${o}'; no verdict"; }
  # The gap-fill location (BL-556): an edit line under a section citing D-5 names the token; the same file
  # two lines on, in the ADJACENT section citing D-7 only in a fence and D-50x in prose, names none -- a
  # whole-file scan, an unfenced scan or an unbounded token would each read a decision there.
  printf '# Doc\n\n## A\nThe rule per D-5.\nedited here\n\n## B\nedited there\n```text\nD-7\n```\nnot D-50x\n\n### B.1\nD-9 is a child of B\n' > "$d/sec.md"
  o="$(gap_section "$d/sec.md" 5 1 999; gap_section "$d/sec.md" 8 1 13; gap_section "$d/sec.md" 8 1 999)"
  [ "$o" = "A	D-5
B	
B	D-9" ] || { rm -rf "$d"; die "the gap-fill location self-probe failed: read '${o}'; no verdict"; }
  # The two check fields (BL-557): a part with a repaired entry and neither field fires twice; a part
  # holding only an escalated entry is exempt; a record with neither field is outside the era; a
  # record that opened it and wrote `not replayed` fires once.
  printf '### F-1\n- disposition: repaired\n- edit: n/a\n' > "$d/nochk.md"
  printf '### F-1\n- disposition: escalated\n- edit: n/a\n' > "$d/esconly.md"
  printf -- '- advisor: called\n- derivations: not replayed\n\n### F-1\n- disposition: repaired\n- edit: n/a\n' > "$d/notrep.md"
  o="$(checks_field 0 "$d/nochk.md"; checks_field 0 "$d/esconly.md"; checks_field 1 "$d/nochk.md"; checks_field 1 "$d/notrep.md")"
  [ "$o" = "CHK	nochk.md	no advisor: line
CHK	nochk.md	no derivations: line
CHK	notrep.md	derivations: not replayed" ] || { rm -rf "$d"; die "the check-fields self-probe failed: read '${o}'; no verdict"; }
  # Prose and trailers (the s317 shape): a record whose only labelled lines are prose never opens
  # the era and passes; a keyword-led value with a trailer, in CRLF, reads; a prose line beside a
  # grammar line in a bound file is the value outside the grammar.
  printf -- '- derivations: the validator reports OK on the PRD\n- advisor: one attempt was made\n\n### F-1\n- disposition: repaired\n- edit: n/a\n' > "$d/prose.md"
  printf -- '- advisor: called (no concerns)\r\n- derivations: replayed 3 -- validator OK\r\n\r\n### F-1\r\n- disposition: repaired\r\n- edit: n/a\r\n' > "$d/trail.md"
  printf -- '- advisor: called\n- derivations: the validator reports OK\n\n### F-1\n- disposition: repaired\n- edit: n/a\n' > "$d/mixed.md"
  o="$(checks_field 1 "$d/prose.md"; checks_field 1 "$d/trail.md"; checks_field 1 "$d/mixed.md")"
  [ "$o" = "CHK	mixed.md	no derivations: line
CHK	mixed.md	a value outside the grammar: derivations: the validator reports ok" ] || { rm -rf "$d"; die "the check-fields self-probe failed on prose and trailers: read '${o}'; no verdict"; }
  # The serial blocks (BL-557): a joined record whose part carries both lines and whose SECOND serial
  # block, closed by its own terminator, omits both fires for that block alone; the same record with
  # the second block carrying both is quiet (the near-miss a last-part or last-triple read cannot
  # tell apart); a serial terminator with no triple after the entries of the last shard is refused
  # by name; a `spec-render` block owes neither line; an unterminated tail with no line is quiet.
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n- artifact: p\n- advisor: called\n- derivations: replayed 1\n\n### F-1\n- disposition: repaired\n- edit: n/a\n\n- artifact: s\n- advisor: called\n- derivations: replayed 2\n\n### S-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 1\n\n%s\n### S-2\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 2\n\n- artifact: m\n- derivations: replayed 1\n\n### R-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: spec-render 2\n' '' > "$d/ser.md"
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n- artifact: p\n- advisor: called\n- derivations: replayed 1\n\n### F-1\n- disposition: repaired\n- edit: n/a\n\n- artifact: s\n- advisor: called\n- derivations: replayed 2\n\n### S-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 1\n\n%s\n### S-2\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 2\n\n- artifact: m\n- derivations: replayed 1\n\n### R-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: spec-render 2\n' '- advisor: unavailable
- derivations: replayed 0
' > "$d/serok.md"
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n- artifact: p\n- advisor: called\n- derivations: replayed 1\n\n### F-1\n- disposition: repaired\n- edit: n/a\n\n### S-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 1\n' > "$d/sernt.md"
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n- artifact: p\n\n### F-1\n- disposition: repaired\n- edit: n/a\n\n- artifact: s\n\n### S-1\n- disposition: repaired\n- edit: n/a\n' > "$d/seropen.md"
  # A PART THAT WROTE NO TRIPLE (of graph's 266 s317-s319 parts, 5 repair parts with entries and no
  # triple, plus 6 one-line *-done.md markers): the serial block opens at its own triple, so it is
  # judged and passes (nonp); with no serial triple it is refused by name (nont). A count rule ("the
  # second triple") refuses nonp. The near-miss (lowp): a part triple BELOW its first entry is read as
  # the serial opener, and the block it opens owes both lines. A STATED LIMIT, FAIL-OPEN: had that part
  # triple carried BOTH lines, they would satisfy the serial block -- no signal in the position rule
  # separates it, and graph holds 0 of 266 parts with a triple below an entry and 0 with more than one.
  # A TITLE IS NOT AN ENTRY (ktitle): a non-entry `### ` heading above the own triple of the part must not
  # hand that triple to the serial block; an entry is seen at its `disposition:` line, so the serial
  # triple with neither line still fires twice. An any-`### ` rule reads it quiet.
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n### F-1\n- disposition: repaired\n- edit: n/a\n\n- artifact: s\n- advisor: called\n- derivations: replayed 0\n\n### S-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 1\n' > "$d/nonp.md"
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n### F-1\n- disposition: repaired\n- edit: n/a\n\n### S-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 1\n' > "$d/nont.md"
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n### F-1\n- disposition: repaired\n- edit: n/a\n\n- artifact: p\n\n### S-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 1\n' > "$d/lowp.md"
  printf -- '- artifact: j\n\n<!-- shard: 01.md -->\n### Repair record -- shard 01\n- artifact: p\n- advisor: called\n- derivations: replayed 1\n\n### F-1\n- disposition: repaired\n- edit: n/a\n\n- artifact: s\n\n### S-1\n- disposition: repaired\n- edit: n/a\n\nrepair-complete: serial 1\n' > "$d/ktitle.md"
  o="$(checks_field 1 "$d/ser.md"; checks_field 1 "$d/serok.md"; checks_field 1 "$d/sernt.md"; checks_field 1 "$d/seropen.md"; checks_field 1 "$d/nonp.md"; checks_field 1 "$d/nont.md"; checks_field 1 "$d/lowp.md"; checks_field 1 "$d/ktitle.md")"
  [ "$o" = "CHK	ser.md	no advisor: line (the block closed at line 27 by 'repair-complete: serial 2')
CHK	ser.md	no derivations: line (the block closed at line 27 by 'repair-complete: serial 2')
CHK	sernt.md	the serial block closed at line 16 by 'repair-complete: serial 1' opens with no sha triple of its own after the entries of the last shard, so its advisor: and derivations: lines cannot be told from those of shard 01.md
CHK	nont.md	the serial block closed at line 12 by 'repair-complete: serial 1' opens with no sha triple of its own after the entries of the last shard, so its advisor: and derivations: lines cannot be told from those of shard 01.md
CHK	lowp.md	no advisor: line (the block closed at line 14 by 'repair-complete: serial 1')
CHK	lowp.md	no derivations: line (the block closed at line 14 by 'repair-complete: serial 1')
CHK	ktitle.md	no advisor: line (the block closed at line 19 by 'repair-complete: serial 1')
CHK	ktitle.md	no derivations: line (the block closed at line 19 by 'repair-complete: serial 1')" ] \
    || { rm -rf "$d"; die "the check-fields self-probe failed on the serial blocks: read '${o}'; no verdict"; }
  rm -rf "$d"
}
# checks_field <0 parts | 1 record> <file> -> one "CHK\t<file>\t<what>" line per defect (BL-557).
# The two lines a remediator writes under its sha triple: `advisor: called|unavailable` and
# `derivations: replayed <n>|not replayed|deferred to the join (section/subject shard)`.
# A VALUE IS READ THE WAY THE DISPOSITION READER READS ITS OWN: emphasis, carriage returns and case
# dropped, then judged by its LEADING keyword in a CLOSED form: the keyword, then nothing, or a
# trailer opened by `(`, `;`, `,` or `--` -- `called (no concerns)`, `unavailable (rate-limited);
# the repair proceeded`, `replayed 3 -- validator OK` and `deferred to the join (section shard)`
# all read. A keyword followed by a WORD is prose that happens to start with it: graph writes
# `called before the first write ...` sixteen times, and `called the advisor but every call
# errored` or `replayed 3 of 5, two STALE` must not read as the keyword (the second tip adversary
# found the open form accepting both). `deferred to the join` is read only where a part may defer:
# a files-mode part may not, so there it is a value outside the grammar. A line whose value leads with no
# keyword is PROSE: graph writes `- derivations: the validator reports OK on the PRD ...` and
# `- advisor: one attempt was made ...`, and such a line neither opens a record's era nor counts as
# the field. So a record binds only from its first GRAMMAR line, and inside a bound file a prose
# line is a value outside the grammar. The LABEL stays case-sensitive, as arm H's repair_field is.
# CF_LINES=1 (off by default, so the join and its self-probes read exactly the lines above) adds one
# "NRL\t <n>..." line naming the line numbers of the `not replayed` values in the segment the file's
# LAST terminator closes (a part: the whole part). `wait-for-deliverable.sh --mark`/`--mark-repair`
# extracts this function and reads that line to replay the record before sealing it (BL-804). When
# that segment states `replayed <n>` it adds "RPL\t<first line>\t<last line>", the segment's own line
# range (its first chunk's first line through the line before the next chunk opens, or the file's
# last line), which --mark uses to attribute a validator FAIL to the segment it closes (BL-816).
# A chunk edge is never inside a fence (`fence { next }` below), so a fence lies wholly in or out.
# CF_EDITS=1 (off by default) prints ONLY one "EDT\t<value>" line per `edit:` value that is not a no-edit
# value, under any heading whose entry is not dispositioned escalated, and nothing else: the no-lane
# acceptance's key 2 (BL-807). A no-edit value is `n/a` or `none` read by val() and kw() above, so
# `n/a (escalated)`, `` `none` `` and `**n/a** (the fix was already in place)` read as no edit, and an
# extension-less path, prose, `.MD:3` or an empty value wrapped onto the next line do not -- a value is
# judged, never tokenised, so a spelling part_cites cannot tokenise still refuses. `n/a (insertion)` and
# `n/a (deletion)` are NOT no-edit here: they are the siblings field's forms, and team-roles/remediator.md
# defines them as an edit that inserted or deleted text, so on an `edit:` line they name a write. Fail closed.
# An entry dispositioned repaired or operator-ruling that carries NO `edit:` line prints
# "EDT\t(no edit: line)": an absent value is not a no-edit value, so it cannot acquit key 2 either.
checks_field() {
  awk -v rec="$1" -v dok="${CF_DEFER:-1}" -v nrl="${CF_LINES:-0}" -v ed="${CF_EDITS:-0}" -v DK="$DISP_KEY_ERE" '
    function val(  v) { v = $0; sub(/^[^:]*:/, "", v); gsub(/[*_`\r]/, "", v); v = tolower(v)
                        gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    function kw(v, re) { return v ~ ("^(" re ")[ \t]*($|[(;,]|--)") }
    # EVERY LINE LANDS IN A CHUNK, and segments are resolved in END: the serial block opens at a
    # triple that is known to be the serial one only once the LAST shard marker is known. A chunk
    # opens at line 1, at each shard marker (M), at each `- artifact:` triple line (T) and after each
    # column-0 `repair-complete:` terminator (E), which closes the chunk it ends.
    function brk(t) { nk++; ck[nk] = t; cl[nk] = FNR }
    function seg(lo, hi,   j) { sa = 0; sd = 0; sr = 0; sn = 0; sy = 0; sb = ""; sl = ""
      for (j = lo; j <= hi; j++) { sa += ca[j]; sd += cd[j]; sr += cr[j]; if (cn[j]) sn = 1; if (cy[j]) sy = 1; sb = sb cb[j]; sl = sl cnl[j] } }
    function emit(what, w) { print "CHK\t" b "\t" what w }
    # judge <chunks lo..hi> <label> <mode> <need>. Mode E: a part (or an unmarked record with no
    # terminator), bound only once it carries a grammar line, the record era per segment. Mode S: a
    # block closed by `repair-complete: serial`, which owes both lines whatever any era says. Mode V:
    # any other block, values only. need: charge nothing unless the segment holds a repaired entry --
    # A JOINED RECORD IS JUDGED PART BY PART, as the join judged it, and the parts-mode join exempted a
    # part holding none, so the record it wrote must not fail its own reader (the third tip adversary).
    function judge(lo, hi, w, mode, need) {
      seg(lo, hi)
      if (need && !sr) return
      if (mode == "E" && sa + sd == 0) return
      if (mode != "V") { if (!sa) emit("no advisor: line", w); if (!sd) emit("no derivations: line", w) }
      if (sb != "") emit("a value outside the grammar:" sb, w)
      if (sn) emit("derivations: not replayed", w)
      if (sn && nrl == 1 && own) print "NRL\t" sl
      if (sy && nrl == 1 && own) print "RPL\t" cl[lo] "\t" (hi < nk ? cl[hi + 1] - 1 : FNR)
    }
    function blk(j) { return " (the block closed at line " tl[j] " by \047" tx[j] "\047)" }
    BEGIN { nk = 1; ck[1] = "H"; cl[1] = 1 }
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { fence = 0; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ { fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    fence { next }
    function eflush(   i) { if (edp !~ /^escalat/) for (i = 1; i <= nev; i++) print "EDT\t" ev[i]
      if (edp ~ /^(repaired|operator-ruling)/ && !esaw) print "EDT\t(no edit: line)"
      nev = 0; edp = ""; esaw = 0 }
    ed == 1 && /^#+[ \t]/ { eflush() }
    ed == 1 && $0 ~ DK { edp = val() }
    ed == 1 && /^[[:space:]-]*[*_`]*edit[*_`]*:/ { esaw = 1; v = val(); if (!kw(v, "n/a|none") || v ~ /^n\/a[ \t]*\((insertion|deletion)\)/) ev[++nev] = v; next }
    rec == 1 && /^<!-- shard: [^ ]+ -->[ \t]*$/ { sawe = 0; brk("M"); cm[nk] = $0; sub(/^<!-- shard: /, "", cm[nk]); sub(/ -->.*$/, "", cm[nk]); next }
    rec == 1 && /^repair-complete:/ { tl[nk] = FNR; tx[nk] = $0; gsub(/[\t\r]/, " ", tx[nk]); sub(/[ ]+$/, "", tx[nk])
                                      split(tx[nk], tw, " "); ts[nk] = (tw[2] == "serial"); brk("E"); next }
    rec == 1 && /^[[:space:]-]*[*_`]*artifact[*_`]*:/ { brk("T"); ce[nk] = sawe }
    /^[[:space:]-]*[*_`]*advisor[*_`]*:/ { v = val()
      if (kw(v, "called|unavailable")) ca[nk]++; else cb[nk] = cb[nk] " advisor: " v; next }
    /^[[:space:]-]*[*_`]*derivations[*_`]*:/ { v = val()
      if (kw(v, "not replayed")) { cd[nk]++; cn[nk] = 1; cnl[nk] = cnl[nk] " " FNR }
      else if (kw(v, "replayed [0-9]+")) { cd[nk]++; cy[nk] = 1 }
      else if (kw(v, "deferred to the join")) { cd[nk]++; if (!dok) cb[nk] = cb[nk] " derivations: deferred in a files-mode part" }
      else cb[nk] = cb[nk] " derivations: " v
      next }
    $0 ~ DK { if (rec == 1) sawe = 1; v = tolower(val()); sub(/[^a-z-].*$/, "", v); if (v == "repaired") { nrep++; cr[nk]++ } }
    END {
      if (ed == 1) { eflush(); exit }
      b = FILENAME; sub(/.*\//, "", b)
      # A PART is one segment, bound unconditionally once it holds a repaired entry.
      if (rec == 0) { if (nrep == 0) exit; own = 1; judge(1, nk, "", "S", 0); exit }
      lm = 0; nt = 0; lt = 0
      for (j = 1; j <= nk; j++) { if (ck[j] == "M") lm = j; if (tl[j]) { nt++; lt = j } }
      lo = 1
      if (!lm) {
        # AN UNMARKED RECORD (the one unsharded remediator, or a record no join wrote) owes the lines
        # unconditionally only in a block its serial terminator closes; with no terminator it is one
        # era-gated segment, as before.
        if (!nt) { judge(1, nk, "", "E", 0); exit }
      } else {
        # The head and every shard segment, era-gated per segment. THE SERIAL BLOCK OPENS BY POSITION:
        # at the first `- artifact:` triple after the last marker that follows one of the entries of
        # that part (its `disposition:` line, outside a fence). A `### ` heading alone is not an entry: a
        # part titled `### Repair record -- shard 01` above its own triple would otherwise hand that
        # triple to the serial block, whose missing lines the part then satisfies (the ktitle probe).
        # The own triple of a part opens its record (team-roles/remediator.md:
        # the record "opens with the file it repaired"), so it sits ABOVE its first entry, and a triple
        # below an entry belongs to the serial remediator. Keyed on a COUNT ("the second triple") the rule refused a correct
        # serial block after a part that wrote no triple. Graph s317-s319 carry 266 parts: 255 whose
        # triple sits above its first entry, 0 below, and 11 with no triple -- 5 repair parts with
        # entries and no triple, plus 6 one-line *-done.md markers with no entries. THE NEAR-MISS, STATED: a part
        # whose OWN triple sat below its first entry would be read as the serial opener, so its lines
        # would be judged as the lines of a serial block -- and, closed by no terminator, as an era-gated tail.
        # A STATED LIMIT, FAIL-OPEN: such a part triple carrying BOTH lines is still read as the serial
        # opener, and its lines satisfy the serial block. No signal inside this rule separates it from a
        # serial triple; the corpus holds 0 of 266 parts with a triple below an entry and 0 with more
        # than one triple. The self-probe pins which way the engine answers it.
        s0 = 1
        for (j = 2; j <= lm; j++) if (ck[j] == "M") { judge(s0, j - 1, (s0 == 1 ? " (above the first shard marker)" : " (shard " cm[s0] ")"), "E", s0 > 1); s0 = j }
        t2 = 0
        for (j = lm + 1; j <= nk; j++) if (ck[j] == "T" && ce[j]) { t2 = j; break }
        hi = (t2 ? t2 - 1 : nk)
        # A SERIAL TERMINATOR BEFORE THAT TRIPLE closes a block with no triple of its own, whose lines
        # cannot be told from the last part, so it is refused by name, never judged.
        for (j = lm; j <= hi; j++) if (tl[j] && ts[j]) emit("the serial block closed at line " tl[j] " by \047" tx[j] "\047 opens with no sha triple of its own after the entries of the last shard, so its advisor: and derivations: lines cannot be told from those of shard " cm[lm], "")
        judge(lm, hi, " (shard " cm[lm] ")", "E", 1)
        if (!t2) exit
        lo = t2
      }
      # THE BLOCKS: each runs to the terminator that closes it; the next opens after it. A block
      # closed by `repair-complete: serial` owes both lines; any other block (`spec-render`) is judged
      # on its values alone; an unterminated tail is era-gated like a part. Parts never reach a block.
      for (j = lo; j <= nk; j++) if (tl[j]) { own = (j == lt); judge(lo, j, blk(j), (ts[j] ? "S" : "V"), (lm && !ts[j])); own = 0; lo = j + 1 }
      if (lo <= nk) judge(lo, nk, (lm ? " (the unterminated block from line " cl[lo] ")" : ""), "E", (lm > 0))
    }' "$2"
}
checks_refusals() {  # <checks_field output>
  local k b w
  while IFS='	' read -r k b w; do
    [ "$k" = CHK ] || continue
    refuse "${b}: ${w}; a remediator's record states under its sha triple whether the advisor ran ('- advisor: called|unavailable') and whether its derivations were replayed ('- derivations: replayed <n>|deferred to the join (section/subject shard)'), and the join refuses 'not replayed' (team-roles/remediator.md)"
  done <<CKEOF
$1
CKEOF
}
ISO='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'

# Sourced (the remediator-shard-join fixture's unit arms), the file stops here: everything above defines
# the entry contract's functions and constants; nothing below runs.
SPEC_RENDER_PHRASE="re-derived from memlog through"
# spec_render_scan <memlog> -> "<last render line> <decisions after it> <first such line>", 0 0 0 with no render.
spec_render_scan() {
  awk -v ph="$SPEC_RENDER_PHRASE" '
    /^[[:space:]]*[-*][[:space:]]*\(event([[:space:]][^)]*)?\)[[:space:]]+Render/ && index($0, ph) { r = NR; n = 0; f = 0; next }
    /^[[:space:]]*[-*][[:space:]]*\(decision([[:space:]][^)]*)?\)/ { if (r) { n++; if (!f) f = NR } }
    END { print r + 0, n + 0, f + 0 }' "$1"
}
# spec_render_check <memlog or empty> <why empty> -> SPEC_LINE (one SPEC-RENDER: line), or a refusal.
# NEVER CALLED INSIDE $( ): refuse() counts in this shell, and a subshell would drop the count.
spec_render_check() {
  local m="$1" s r n f
  SPEC_LINE=""
  if [ -z "$m" ]; then SPEC_LINE="SPEC-RENDER: SKIP -- $2"; return 0; fi
  # A SPEC part whose memlog does not exist yet has recorded no render and no decision to compare.
  if [ ! -f "$m" ]; then SPEC_LINE="SPEC-RENDER: SKIP -- ${m} does not exist"; return 0; fi
  s="$(spec_render_scan "$m")" || { refuse "${m}: the memlog could not be read; no render verdict"; return 0; }
  r="${s%% *}"; s="${s#* }"; n="${s%% *}"; f="${s#* }"
  if [ "$r" = 0 ]; then
    SPEC_LINE="SPEC-RENDER: SKIP -- ${m} carries no '(event) Render ... ${SPEC_RENDER_PHRASE}' line, so no render is recorded to compare against"
  elif [ "$n" -gt 0 ]; then
    refuse "${m}:${f}: ${n} (decision) entry(ies) after the last render (line ${r}), so SPEC.md does not carry them; re-derive SPEC.md whole from .memlog.md under bmad-spec and append '- (event) Render <pass>: ${SPEC_RENDER_PHRASE} <last decision>' (a change applied with Edit is '(event) Hand-edit', never Render)"
  else
    SPEC_LINE="SPEC-RENDER: ${m} -- rendered through its last decision (line ${r})"
  fi
}
# spec_memlog_of_sprint -> sets SPEC_MEMLOG to the one specs/s<N>/*/.memlog.md, or empty with SPEC_WHY.
spec_memlog_of_sprint() {
  local g c=0 hit=""
  SPEC_MEMLOG=""; SPEC_WHY=""
  if [ -z "$SPRINT" ] || [ "$SPRINT" = 0 ]; then SPEC_WHY="no --sprint, so no spec memlog is named"; return 0; fi
  for g in "${STATE}/specs/s${SPRINT}"/*/.memlog.md; do [ -f "$g" ] && { c=$((c + 1)); hit="$g"; }; done
  case "$c" in
    1) SPEC_MEMLOG="$hit" ;;
    0) SPEC_WHY="no ${STATE}/specs/s${SPRINT}/*/.memlog.md" ;;
    *) SPEC_WHY="${c} memlogs under ${STATE}/specs/s${SPRINT}/; the kernel is exactly one" ;;
  esac
}
# The self-probe, before any corpus is read, in both directions: a phrased render then a decision fires;
# a decision then a phrased render is quiet; no render skips; and THE ACQUITTAL GUARD -- an
# `(event) Render` line WITHOUT the phrase, then a decision, skips rather than reading as rendered.
spec_render_probe() {
  local d o
  d="$(mktemp -d "${TMPDIR:-/tmp}/join-specprobe.XXXXXX")" || die "mktemp failed; the SPEC render arm cannot be probed"
  printf -- '- (decision) a\n- (event) Render p1: %s a\n- (decision by pm) b\n' "$SPEC_RENDER_PHRASE" > "$d/stale.md"
  printf -- '- (decision) a\n- (event) Render p1: %s a\n' "$SPEC_RENDER_PHRASE" > "$d/fresh.md"
  printf -- '- (decision) a\n- (decision) b\n' > "$d/none.md"
  printf -- '- (event) Render (fold): ran no renderer; applied to SPEC.md by hand\n- (decision) a\n' > "$d/hand.md"
  o="$(spec_render_scan "$d/stale.md")"; [ "$o" = "2 1 3" ] || { rm -rf "$d"; die "the SPEC render arm's self-probe failed: a decision after a render read '${o}'; no verdict"; }
  o="$(spec_render_scan "$d/fresh.md")"; [ "$o" = "2 0 0" ] || { rm -rf "$d"; die "the SPEC render arm's self-probe failed: a render after its decision read '${o}'; no verdict"; }
  o="$(spec_render_scan "$d/none.md")"; [ "$o" = "0 0 0" ] || { rm -rf "$d"; die "the SPEC render arm's self-probe failed: a memlog with no render read '${o}'; no verdict"; }
  o="$(spec_render_scan "$d/hand.md")"; [ "$o" = "0 0 0" ] || { rm -rf "$d"; die "the SPEC render arm's self-probe failed: an unphrased Render line read '${o}', acquitting a hand edit; no verdict"; }
  rm -rf "$d"
}
# record_tail <record> -- the entry contract over one record no join wrote, then its escalations:
# shared by --sources and --escalations, so each line below exists once.
record_tail() {  # <record> [<lane round's record>...] -- closure is positional across them, in this order
  local _r _sp=0
  contract_probe
  contract_refusals 1 "$(contract_check 1 "$@")"
  for _r in "$@"; do
    checks_refusals "$(checks_field 1 "$_r")"
    grep -q -F "specs/s${SPRINT}/" "$_r" && _sp=1
  done
  spec_render_probe
  # ONLY A RECORD THAT REPAIRED THE SPEC IS JUDGED. Without this, a stale SPEC refuses an architecture or
  # stories record, which repaired no SPEC, and its refusal hides that record's escalation list. The test is
  # the record citing the sprint's spec dir at all (its edit: lines name `.memlog.md` or `SPEC.md` there).
  if [ "$_sp" = 1 ]; then
    spec_memlog_of_sprint
    spec_render_check "$SPEC_MEMLOG" "$SPEC_WHY"
  else
    SPEC_LINE="SPEC-RENDER: SKIP -- ${1} cites no specs/s${SPRINT}/ file, so it repaired no SPEC"
  fi
  # The header lines assert that the record checked out, so they print only on a pass.
  if [ "$refuse_n" -eq 0 ]; then
    [ "$SRCMODE" = 1 ] && echo "SOURCES: ${1} -- ${SRC_E} entries, ${SRC_S} sources, every one resolved in ${SEAT_DIR}"
    [ "$SRCMODE" = 2 ] && echo "ESCALATIONS: ${1} -- every escalated entry, open or closed by a closes: line"
  fi
  # THE ESCALATION REPORT PRINTS WHETHER OR NOT THE RECORD REFUSED. These are the LEAD's to
  # adjudicate, never a re-dispatch of the serial remediator: the record may be the serial
  # remediator's own, appended after the join, so no SERIAL-REQUIRED line is printed here. A refusal
  # of any arm is a defect in the record, never a reason to stop reporting what is still open in it.
  # THIS HOLDS IN RECORD MODE ONLY. A refused PARTS join prints no ESCALATED: line and no count, by
  # design: the refusal writes no record, so the parts it read are not a joined set and a count from
  # them may be wrong; the escalations print on the re-run that joins (arm EC32 pins the silence).
  # In record mode:
  # exiting first, as this mode once did, let one prose check line in a bound record hide every open
  # escalation from the lead (a joined record whose serial block wrote graph's own s317 prose
  # `- derivations: the validator reports OK ...` printed no count at all). The exit code still
  # carries the refusal.
  printf '%s' "$ESC_LINES"
  printf '%s' "$ESC_CLOSED"
  echo "ESCALATED-COUNT: ${ESC_N} (${ESC_X} closed by a later repaired entry's closes: line)"
  # The supersedes chains (3b) and the gap-fill tripwire (7) REPORT: neither gates the count above.
  printf '%s' "$CHAIN_LINES"
  printf '%s' "$GAP_LINES"
  [ "$refuse_n" -eq 0 ] || exit 2
  printf '%s\n' "$SPEC_LINE"
  exit 0
}

join_main() {  # everything below: argument parsing, ledger, window, writers, lanes, assembly, record write
while [ $# -gt 0 ]; do
  case "$1" in
    --check-part) [ $# -ge 2 ] || die "--check-part needs <part.md>"; CHKPART="$2"; PARTMODE=1; shift 2 ;;
    --rerun) [ $# -ge 2 ] || die "--rerun needs <part>.md@<ISO>"
             RERUN="${RERUN}${2}
"; shift 2 ;;
    --agent-writes) AGENT_ID="${2:-}"; AGENTMODE=1; SRCMODE=2; shift 2 ;;
    --sources|--escalations)
      _m=1; [ "$1" = --escalations ] && _m=2
      [ "$SRCMODE" = 0 ] || [ "$SRCMODE" = "$_m" ] || die "--sources and --escalations are two modes; pass one, once per record"
      if [ -z "$SRC_REC" ]; then SRC_REC="${2:-}"; else SRC_MORE="${SRC_MORE}${2:-}
"; fi
      SRCMODE="$_m"; shift 2 ;;
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
if [ "$AGENTMODE" = 1 ]; then
  [ "$DOCMODE$SUBJMODE$PARTMODE" = 000 ] && [ -z "$SPRINT$ARTIFACT$PASS$APATH$UNTIL$REPDIR$SRC_REC$SUBJ_BASE$RERUN$DOCUMENT" ] \
    || die "--agent-writes prints one agent's ledger writes and takes only --since <ISO>"
  case "$AGENT_ID" in ''|*[!A-Za-z0-9_-]*) die "--agent-writes needs an agent id of letters, digits, _ and - (got '${AGENT_ID}')" ;; esac
  case "$SINCE" in ''|[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;; *) die "--since must be YYYY-MM-DDTHH:MM:SSZ (got '${SINCE}')" ;; esac
  command -v jq >/dev/null 2>&1 || die "jq is not on PATH; the ledger cannot be read"
fi
if [ "$PARTMODE" = 1 ]; then
  [ "$DOCMODE$SUBJMODE$SRCMODE" = 000 ] && [ -z "$SPRINT$ARTIFACT$PASS$APATH$SINCE$UNTIL$REPDIR$SRC_REC$SUBJ_BASE$RERUN$DOCUMENT" ] \
    || die "--check-part checks one part file and takes no other flag"
  [ -n "$CHKPART" ] && [ -f "$CHKPART" ] || die "--check-part needs an existing part file (got '${CHKPART}')"
  SPRINT=0
fi
if [ "$SRCMODE" != 0 ] && [ "$AGENTMODE" = 0 ]; then
  [ "$DOCMODE$SUBJMODE$PARTMODE" = 000 ] && [ -z "$ARTIFACT$PASS$APATH$SINCE$UNTIL$REPDIR" ] \
    || die "--sources and --escalations check one record and take only --sprint <N>"
  [ -z "$RERUN" ] || die "--rerun narrows a join's ledger window; --sources and --escalations read no ledger"
  [ -n "$SRC_REC" ] && [ -f "$SRC_REC" ] || die "--sources and --escalations need an existing record (got '${SRC_REC}')"
  [ "$SRCMODE" = 1 ] && PARTY=1
  # A LANE ROUND'S RECORD IS READ WITH ITS ROUND-1 RECORD, AFTER IT (BL-716). Lane remediators close
  # round-1 escalations in `<stem>-serial-repair-p<M>.md`, so a call over either record alone reads
  # a closed escalation open, or never sees an open one. Closure is positional across the records
  # given, so the round-1 record comes first; when its lane-round sibling is on disk it must follow.
  _sb="${SRC_REC##*/}"; _sd="${SRC_REC%/*}"; [ "$_sd" = "$SRC_REC" ] && _sd="."
  case "$_sb" in
    *-serial-repair-p*.md) die "${SRC_REC} is a lane round's record; pass the round-1 record it repairs first, then this one" ;;
  esac
  _sib=""
  if _ln="$(lane_name "$_sb")"; then _sib="${_ln%%	*}-repair-p${_ln##*	}.md"; fi
  SRC_ALL="${SRC_REC}
${SRC_MORE}"
  while IFS= read -r _r; do
    [ -n "$_r" ] || continue
    [ -f "$_r" ] || die "--sources and --escalations need an existing record (got '${_r}')"
  done <<SMEOF
$SRC_MORE
SMEOF
  if [ -n "$_sib" ] && [ -f "${_sd}/${_sib}" ]; then
    _hit=0
    while IFS= read -r _r; do [ "${_r##*/}" = "$_sib" ] && _hit=1; done <<SMEOF
$SRC_MORE
SMEOF
    [ "$_hit" = 1 ] || die "${_sd}/${_sib} is the lane round's record for ${SRC_REC}, and its entries close this record's escalations; pass it after this one"
  fi
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
case "$ARTIFACT" in *-party|*-party-serial) PARTY=1 ;; esac
# Set before the mode split: the record modes read it too (an operator-ruling cite is an ISO stamp).
if [ "$SRCMODE" != 0 ] || [ "$PARTMODE" = 1 ]; then
  :
else
[ "$SUBJMODE" = 1 ] || case "$PASS" in ''|*[!0-9]*) die "--pass must be a pass number (got '${PASS}')" ;; esac
case "$ARTIFACT" in ''|*/*) die "--artifact must be a bare artifact name (got '${ARTIFACT}')" ;; esac
if [ "$SUBJMODE" = 0 ]; then
  case "$ARTIFACT" in
    *-adversarial)
      _owed="${ARTIFACT%-adversarial}-repair-p${PASS}"; _given="--artifact ${ARTIFACT}"
      [ -z "$REPDIR" ] || _given="$REPDIR"
      die "the artifact '${ARTIFACT}' ends in -adversarial (given as ${_given}): the adversarial repair record carries no round word. Name the shard dir shards/${_owed}/ and the record ${_owed}.md; arm H of validate-adversarial-convergence.sh reads only that name" ;;
  esac
fi
if [ "$SUBJMODE" = 1 ]; then
  :
elif [ "$DOCMODE" = 1 ]; then
  [ -n "$DOCUMENT" ] || die "--document needs a path"
  [ -z "$APATH" ] || die "--artifact-path does not apply with --document; the file set is the repair dir's sections/"
else
  [ -n "$APATH" ] || die "--artifact-path is required"
fi
APATH="${APATH%/}"
# shellcheck disable=SC2254
case "$SINCE" in $ISO) ;; *) die "--since must be YYYY-MM-DDTHH:MM:SSZ (got '${SINCE}')" ;; esac
# shellcheck disable=SC2254
case "$UNTIL" in $ISO) ;; *) die "--until must be YYYY-MM-DDTHH:MM:SSZ (got '${UNTIL}')" ;; esac
[ "$SINCE" \> "$UNTIL" ] && die "--since ${SINCE} is after --until ${UNTIL}"
command -v jq >/dev/null 2>&1 || die "jq is not on PATH; the ledger cannot be read"
# A FUTURE --until (BL-807). The window's upper bound is a time the lanes have already reported by, so
# one later than this join's own clock is an estimate used as fact. 120s of slack absorbs clock skew.
# The answer is read as the literal `true`/`false`: a jq that cannot evaluate refuses, never acquits.
# Both sides go through fromdateiso8601, so a jq whose parser applies a local DST offset applies it to
# both and the skew cancels (`now` alone is epoch seconds and would not carry it).
_fut="$(jq -n --arg u "$UNTIL" '($u | fromdateiso8601) > ((now | todateiso8601 | fromdateiso8601) + 120)' 2>/dev/null)" || _fut=""
case "$_fut" in
  false) ;;
  true) die "--until ${UNTIL} is later than this join's clock ($(date -u +%Y-%m-%dT%H:%M:%SZ)) by more than 120s: take --until from \`date -u\` after the last lane reports; a hand-chosen future time mis-scopes the window" ;;
  *) die "--until ${UNTIL} could not be compared with this join's clock (jq fromdateiso8601 did not answer); take --until from \`date -u\` after the last lane reports" ;;
esac
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
if [ "$AGENTMODE" = 1 ]; then
  if [ -f "$LEDGER" ]; then
    [ -r "$LEDGER" ] || die "the write ledger ${LEDGER} is not readable"
    _aw="$(jq -rn --arg a "$AGENT_ID" --arg s "$SINCE" '[inputs | select(type == "object") | select(.kind == "artifact-write" and .agent_id == $a and (.path | type) == "string" and ($s == "" or .ts >= $s)) | .path] | unique | .[]' "$LEDGER" 2>/dev/null)" \
      || die "the write ledger ${LEDGER} does not parse as JSON lines"
    [ -z "$_aw" ] || printf '%s\n' "$_aw"
  fi
  echo "not covered: Bash writes, and writes outside planning-artifacts/, specs/s<N>/, gate-adjudication part files and sections-split documents"
  exit 0
fi

# --- THE CONTENT SEAL ON A RECORD (BL-530). `--sources` and `--escalations` read one joined record,
# which is in the sealed set: this join's own write leaves a program row, and the serial remediator's
# Edit append fires the recorder, whose newer row is the one compared. A record whose bytes differ
# from its newest seal row -- a python3 rewrite, a `sed -i`, a Bash append -- is REFUSED here, at mode
# entry, before any body reads it, naming that row's writer. A record with no seal row is not
# compared. `content-seal.sh`, beside this script, owns the set and the comparison. A tree with NO
# state dir has no ledger and so no seal row: it is not compared, exactly as before seals existed,
# because the library refuses a missing state dir (exit 2) and that would refuse correct input.
SEAL="${JR_SCRIPT_DIR}/content-seal.sh"
if [ "$SRCMODE" != 0 ] && [ -d "$STATE" ]; then
  if [ -f "$SEAL" ]; then
    while IFS= read -r _r; do
      [ -n "$_r" ] || continue
      _seal_out="$(bash "$SEAL" --check "$STATE" "$_r" 2>&1)"; _seal_rc=$?
      case "$_seal_rc" in
        0) ;;
        1) die "$_seal_out" ;;
        *) die "the content-seal check over ${LEDGER} did not run (exit ${_seal_rc}): $(printf '%s\n' "$_seal_out" | head -1)" ;;
      esac
    done <<SLEOF
$SRC_ALL
SLEOF
  elif [ -f "$LEDGER" ] && grep -qE '"actor":[[:space:]]*"(agent|session)"' "$LEDGER"; then
    die "${LEDGER} carries content-seal rows but ${SEAL} is absent, so the record's bytes cannot be compared with its seal; reinstall ai-dlc"
  fi
fi

SEAT_DIR="${STATE}/party-mode/s${SPRINT}"
# THE SPEC IS NOT STALE AGAINST ITS MEMLOG (BL-560, BL-546). A SPEC part appends a `(decision)` entry
# to the spec's `.memlog.md` and re-derives `SPEC.md` whole from it, then appends one
# `- (event) Render <pass>: re-derived from memlog through <last decision>` line; a change applied with
# Edit is recorded `(event) Hand-edit`, never Render (requirements.md, "The SPEC is repaired through its
# own render path"). A `(decision)` entry AFTER the last such Render line is a SPEC that does not carry
# its own decisions, and the adversary and the gate would read it. Refused here, so the stale state
# cannot pass the join that hands the subject on.
# AN ORDER TEST, NEVER A DATE TEST. Memlog entries carry no timestamp (memlog.py writes the frontmatter
# `updated` only), so "dated after the last render" is unimplementable; line order is the record.
# THE KEY IS THE FULL PHRASE `re-derived from memlog through` ON AN `(event) Render` LINE. The reference
# consumer carries exactly one `(event) Render` line across 19 memlogs, and it is the disclosure of a
# hand edit ("loaded instructions only and ran no renderer ... applied to SPEC.md by hand"): a key on
# the word Render alone acquits the very case this arm exists for. The tag grammar is the producer
# grammar validate-spec-join.sh reads at its `(capability)` predicate: an optional qualifier after the
# type word is legal.
# A MEMLOG WITH NO SUCH LINE IS SKIPPED, VISIBLY. Measured over the reference consumer 19 committed
# memlogs: 0 carry the phrase, so all 19 SKIP and 0 fire; the unskipped form (every decision is after a
# render that never happened) fires on 18 of 19. So the firing arm has NO corpus instance; its receipt
# is the seeded self-probe below and the fixture, never this zero. A memlog joins this arm from its
# first phrased Render line onward. Stated residue: a piecemeal Edit to SPEC.md followed by a phrased
# Render line passes -- whether the rewrite was whole has no checker.
# WHERE: --sources and --escalations judge a record ONLY when it cites `specs/s<N>/` (it repaired the
# SPEC), and then resolve the sprint memlog from --sprint, `specs/s<N>/*/.memlog.md`,
# exactly one (requirements.md: the kernel is exactly one match); none or several SKIP. A refusal here
# still prints the record's ESCALATED: lines and count before its exit, as every record_tail refusal does
# (only SPEC-RENDER: is withheld). Those modes run
# AFTER the serial remediator appends, which is the case BL-560 was filed on. --subject reads it only
# when the split gave the SPEC a part (SUBJ_SET carries its memlog), the part-remediator shape.
# --sources ON A RECORD THAT IS NOT A PARTY REPAIR (BL-561). The seat dir's existence says only that
# a party round ran this sprint, never that THIS record applies one, so a non-party record resolved
# against it and read as 138 refused sources (graph s319 elicitation repair). Keyed on token SHAPE:
# every source token a non-party record carries names a part, `<N>.md` or `cross[-<N>].md`, and no
# seat file is named so (`<step>-<seat>-<ordinal>.md`). A record carrying at least one token, every
# one part-shaped, is refused with ONE line naming --escalations, before any token is resolved.
# FALSE-POSITIVE SET, MEASURED with this join over the 60 graph s317-s319 repair and fold records in
# sprints that have a party-mode dir: 0 of 9 party records refused, and no party token or seat file
# in that corpus is part-shaped. THE NARROWING: a record with NO token was keyed too, and that
# refused s317/architecture-spine-party-repair-p1.md, a party record written before the source rule
# (192 entries, 0 source: lines) -- one line naming --escalations, the wrong remedy for it, where the
# NOSOURCE arm below already refuses each entry by name. So a token-less record falls through to
# NOSOURCE. RECALL, STATED: three older elicitation records cite their own `<artifact>-elicitation.md`
# (s317/s318 architecture, carry-over-evaluation and stories elicitation repairs), which is neither
# shape; they are still refused, by NOFILE, but without the --escalations remedy. A record mixing a
# seat token with a part token is not refused here either: its part tokens refuse as NOFILE.
src_kind() {  # <record> -> "PARTY", "PART" or "NONE" from its source: tokens, outside fences
  awk '
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { fence = 0; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ { fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    fence { next }
    /^[[:space:]-]*[*_`]*source[*_`]*:/ {
      v = $0; sub(/^[^:]*:/, "", v)
      while (match(v, /[A-Za-z0-9_.\/-]+[.]md#[A-Za-z0-9][A-Za-z0-9.-]*/)) {
        t = substr(v, RSTART, RLENGTH); v = substr(v, RSTART + RLENGTH)
        t = substr(t, 1, index(t, "#") - 1); sub(/.*\//, "", t)
        if (t ~ /^([0-9]+|cross(-[0-9]+)?)[.]md$/) np++; else ns++
      }
    }
    END { print (ns ? "PARTY" : (np ? "PART" : "NONE")) }' "$1"
}
# --check-part <part>: the join's own entry contract, parts mode, over ONE part before its remediator
# returns -- the same probe, classifier and refusal text the join applies, so a BADSIB or NOSIB the join
# would refuse is refused here first, while the remediator can still fix it. No ledger, seal or seat.
if [ "$PARTMODE" = 1 ]; then
  contract_probe
  contract_refusals 0 "$(contract_check 0 "$CHKPART")"
  printf '%s' "$GAP_LINES"
  [ "$refuse_n" -eq 0 ] || exit 2
  echo "CHECK-PART: ${CHKPART} -- the join's entry contract holds; the check fields (advisor:, derivations:, derivation:) and the disposition/edit repair fields were NOT checked"
  exit 0
fi
if [ "$SRCMODE" != 0 ]; then
  set --
  while IFS= read -r _r; do [ -n "$_r" ] && set -- "$@" "$_r"; done <<SAEOF
$SRC_ALL
SAEOF
fi
if [ "$SRCMODE" = 1 ]; then
  [ -d "$SEAT_DIR" ] || die "no seat files at ${SEAT_DIR}; a party repair's sources resolve there"
  [ "$(src_kind "$SRC_REC")" = PART ] \
    && die "${SRC_REC} names only part tokens (<N>.md, cross-<N>.md) in its source: lines, so it is not a party repair; its escalations are read with --escalations ${SRC_REC} --sprint ${SPRINT}"
  src_probe
  src_refusals "$(src_check "$SEAT_DIR" "$@")"
  seat_complete_check "$SEAT_DIR" "$@"
  [ "$SRC_E" -gt 0 ] || refuse "${SRC_REC} carries no entry with a 'disposition:' line; nothing is attributed"
  record_tail "$@"
fi
# --escalations: the same contract and closure over a record with NO seat files -- an adversarial,
# elicitation or gate repair after its serial pass appended -- where --sources refuses for want of a
# party-mode/s<N> directory. Open escalations are reported, never a refusal.
if [ "$SRCMODE" = 2 ]; then
  n_disp="$(grep -c -E -e "$DISP_KEY_ERE" "$SRC_REC")" || n_disp=0
  [ "$n_disp" -gt 0 ] || die "${SRC_REC} carries no entry with a 'disposition:' line; no escalation can be read"
  record_tail "$@"
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
# root_rel <physical abs path> -> the path relative to the PHYSICAL project root, or as given when it
# lies outside it. The record's `- artifact:` line and the ledger spelling below share it.
root_rel() {
  local r
  r="$(cd "$JR_ROOT" 2>/dev/null && pwd -P)" || r=""
  if [ -n "$r" ]; then case "$1" in "$r"/*) printf '%s\n' "${1#"$r"/}"; return 0 ;; esac; fi
  printf '%s\n' "$1"
}
# ledger_rel <physical abs path> -> the write ledger's spelling of that file: `<state-dir-name>/...`
# inside the state dir, else root_rel. The recorder's manifest arm in
# `ai-dlc-gate-remediation-guard.sh` (manifest_doc_rel) spells a sections document by the same rule.
ledger_rel() {
  local s
  s="$(cd "$STATE" 2>/dev/null && pwd -P)" || s=""
  if [ -n "$s" ]; then case "$1" in "$s"/*) printf '%s/%s\n' "${STATE##*/}" "${1#"$s"/}"; return 0 ;; esac; fi
  root_rel "$1"
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

# --- THE CONTENT SEAL (BL-530): a part record or section copy amended after its last sealed write is
# refused. `content-seal.sh`, beside this script, owns the sealed set, the row and the comparison; this
# site hands it every `*.md` under the repair dir (the parts and, in document and subject mode, the
# section copies the assembler reads). Seal rows are `kind: "content-seal"` and are read there with no
# agent_id filter; every ledger read below keys on `kind == "artifact-write"`, so neither sees the
# other's rows. A file with no seal row is not compared. The joined record this program writes is
# sealed too, and compared where it is read: `--sources` and `--escalations`, at mode entry above.
if [ -f "$SEAL" ]; then
  _seal_out="$(find "$SHARD_DIR" -type f -name '*.md' | LC_ALL=C sort | bash "$SEAL" --check "$STATE" - 2>&1)"; _seal_rc=$?
  case "$_seal_rc" in
    0) ;;
    1) while IFS= read -r _sl; do [ -n "$_sl" ] && refuse "$_sl"; done <<SEALEOF
$_seal_out
SEALEOF
       ;;
    *) die "the content-seal check over ${LEDGER} did not run (exit ${_seal_rc}): $(printf '%s\n' "$_seal_out" | head -1)" ;;
  esac
elif [ -f "$LEDGER" ] && grep -qE '"actor":[[:space:]]*"(agent|session)"' "$LEDGER"; then
  # A TOOL seal row (only seal rows carry `actor`); a program row alone is record-only.
  die "${LEDGER} carries content-seal rows but ${SEAL} is absent, so no part's bytes can be compared with its seal; reinstall ai-dlc"
fi

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
  _toks="$(awk -v DK="$DISP_KEY_ERE" '
    function emit(   i) { if (disp !~ /^escalat/) for (i = 1; i <= nt; i++) print tk[i]; nt = 0; disp = "" }
    /^#+[ \t]/ { emit(); next }
    $0 ~ DK {
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

# --- SERIAL LANES (BL-716; the header's arm 4b). Printed after SERIAL-REQUIRED on a written record.
# esc_cites <part> -> "<part> <heading>\t<token>" for every token an ESCALATED entry's `edit:` names,
# and "<part> <heading>\t-" for one naming none. The heading is contract_check's own `cur` spelling,
# so the key equals the tail of its ESCALATED: line; a key that does not match routes to the fan-in.
esc_cites() {
  awk -v pt="${1##*/}" -v DK="$DISP_KEY_ERE" '
    function trim(v) { gsub(/^[ \t`]+|[ \t`]+$/, "", v); return v }
    function emit(   i) { if (disp ~ /^escalat/) { if (nt == 0) print pt " " cur "\t-"; for (i = 1; i <= nt; i++) print pt " " cur "\t" tk[i] }
                          nt = 0; disp = "" }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^#+[ \t]/ { emit(); cur = $0; sub(/^#+[ \t]+/, "", cur); gsub(/[\t\r]/, " ", cur); cur = trim(cur); next }
    $0 ~ DK {
      disp = tolower($0); sub(/^[^:]*:/, "", disp); gsub(/[*_`]/, "", disp); sub(/^[ \t]+/, "", disp); next }
    /^[[:space:]-]*[*_`]*edit[*_`]*:/ {
      line = $0; sub(/^[^:]*:/, "", line)
      while (match(line, /[A-Za-z0-9_.\/-]+[.](md|json|jsonl|yaml|yml|txt|csv)/)) {
        tok = substr(line, RSTART, RLENGTH); gsub(/\/\/+/, "/", tok); tk[++nt] = tok
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END { emit() }' "$1"
}
lane_report() {
  local _keys="" _wl="" _wrc=0 _p _k _t _e _ek _ec _la _lan _lap
  # THE LANE ROUND'S NAME, derived from this round's record by lane_name, never from --artifact:
  # the subject's records are `requirements-party-repair.md` and the like, under ARTIFACT=requirements.
  if _la="$(lane_name "${OUT##*/}")"; then
    _lan="${_la%%	*}"; _lap="${_la##*	}"
    echo "LANE-ARTIFACT: ${_lan} --pass ${_lap}"
    # THE LANE JOIN'S --artifact-path, in the ledger's spelling, so the lead copies it: the slot after
    # a files round, the document after a sections round, the state dir after a subject round.
    if [ "$SUBJMODE" = 1 ]; then echo "LANE-ARTIFACT-PATH: ${STATE_NAME}"
    elif [ "$DOCMODE" = 1 ]; then echo "LANE-ARTIFACT-PATH: $(ledger_rel "$DOC_ABS")"
    else echo "LANE-ARTIFACT-PATH: ${SHARD_REL%/shards}"; fi
  fi
  # THE NODE MAP: every written file in the ledger's spelling -> the file a serial remediator edits.
  if [ "$SUBJMODE" = 1 ]; then
    _keys="$(awk -F'\t' '$1 == "part" { print ($7 != "-" ? $7 : $4) "\t" $4
      if ($7 == "-" && $3 == "SPEC") { m = $4; sub(/SPEC\.md$/, ".memlog.md", m); print m "\t" $4 } }' "$SUBJ_REC" \
      | awk -F'\t' -v p="${SREL}/" -v n="${STATE_NAME}/" '{ for (i = 1; i <= 2; i++) if (index($i, p) == 1) $i = n substr($i, length(p) + 1); print $1 "\t" $2 }' OFS='\t')"
  elif [ "$DOCMODE" = 1 ]; then
    _keys="$(printf '%s\n' "$ROWS" | awk -F'\t' -v d="$DOC_REL" 'NF >= 2 { print $1 "\t" d }')"
  else
    _keys="$(printf '%s\n' "$ROWS" | awk -F'\t' 'NF >= 2 { print $1 "\t" $1 }')"
  fi
  # THE EDGES a worklist derives: document and subject mode only, over the assembled bytes, keeping
  # the pre-repair copies for the lead's own run. Anything but exit 0 is one lane.
  _wl="files mode keeps no pre-repair copy: no worklist, so no MOVED-CITE edge"
  if [ "$DOCMODE$SUBJMODE" != 00 ]; then
    if [ -f "${JR_SCRIPT_DIR}/serial-remediation-worklist.sh" ]; then
      _wl="$(AI_DLC_PROJECT_ROOT="$JR_ROOT" bash "${JR_SCRIPT_DIR}/serial-remediation-worklist.sh" "$SHARD_DIR" --record "$OUT" --keep 2>&1)"; _wrc=$?
    else
      _wl="serial-remediation-worklist.sh is not beside this script"; _wrc=2
    fi
  fi
  _e=""
  while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    _ec="$(esc_cites "$_p")" || die "could not read the escalated entries of ${_p##*/} for the serial lanes"
    while IFS='	' read -r _ek _t; do
      [ -n "$_ek" ] || continue
      if [ "$_t" != "-" ]; then
        _t="${_t#"$STATE_PARENT"}"; _t="${_t#"$STATE_PARENT_P"}"
        [ "$SUBJMODE" = 1 ] && case "$_t" in "${SREL}"/*) _t="${STATE_NAME}/${_t#"${SREL}"/}" ;; esac
      fi
      _e="${_e}T	${_ek}	${_t}
"
    done <<LNEOF
${_ec}
LNEOF
  done <<LPEOF
$PARTS
LPEOF
  { printf '%s\n' "$_keys" | sed '/^$/d; s/^/K\t/'
    printf '%s' "$CITES"
    printf '%s' "$_e"
    printf '%s' "$ESC_LINES" | sed -n 's/^ESCALATED: /S\t/p'
    if [ "$DOCMODE$SUBJMODE" = 00 ]; then printf 'F\t%s\n' "$_wl"
    elif [ "$_wrc" = 0 ]; then printf '%s\n' "$_wl" | sed 's/^/W\t/'
    else printf 'U\texit %s: %s\n' "$_wrc" "$(printf '%s\n' "$_wl" | grep -m1 -E '^(UNASSESSABLE|ERROR)' || printf '%s\n' "$_wl" | head -1)"; fi
  } | awk -F'\t' '
    function fnd(x) { while (x in par) x = par[x]; return x }
    function uni(a, b) { a = fnd(a); b = fnd(b); if (a != b) { if (a < b) par[b] = a; else par[a] = b } }
    # A path names a node when it equals the node, or either ends in "/" + the other: the ledger and a
    # root-relative spelling differ only by a leading state-dir prefix.
    function keyof(p,   k, n, h) { n = 0; h = ""
      for (k in isk) if (k == p || (length(k) > length(p) && substr(k, length(k) - length(p)) == "/" p) \
                         || (length(p) > length(k) && substr(p, length(p) - length(k)) == "/" k)) { n++; h = (h == "" ? k : h SUBSEP k) }
      return h }
    function wkey(p,   i, n, a) { n = 0; for (i = 1; i <= nw; i++) { if (W[i] == p || (length(W[i]) > length(p) && substr(W[i], length(W[i]) - length(p)) == "/" p)) { n++; a = W[i] } }
      return (n == 1) ? node[a] : "" }
    function lanes_of(list,   n, a, i, s, l, out) { n = split(list, a, SUBSEP); out = ""; delete seenl
      # Every list opens with SUBSEP, so a[1] is empty by construction; a later empty member is an
      # entry that named no file, which no lane owns.
      for (i = 2; i <= n; i++) { if (a[i] == "") { l = "out" } else { s = keyof(a[i]); l = (s == "" || index(s, SUBSEP)) ? "out" : lane[fnd(s)]; if (l == "") l = "out" }
        if (!(l in seenl)) { seenl[l] = 1; out = out (out == "" ? "" : " ") l } }
      return out }
    function frag(   ls) { if (ft == "") return; if (fh != "") { ls = lanes_of(fh)
        if (ls ~ /^[0-9]+$/) item[ls] = item[ls] "LANE-ITEM: " ls " HIT \"" ft "\" at " fhs "\n"
        else fan = fan "FANIN: HIT \"" ft "\" at " fhs " (lanes " ls ")\n" }
      ft = ""; fh = ""; fhs = "" }
    $1 == "K" { node[$2] = $3; isk[$3] = 1; W[++nw] = $2; next }
    $1 == "C" { k = wkey($3); if (k == "") next; if (!(($2, k) in pk)) { pk[$2, k] = 1; pks[$2] = pks[$2] SUBSEP k }
                if ($2 in first) uni(first[$2], k); else first[$2] = k; next }
    $1 == "T" { et[$2] = et[$2] SUBSEP ($3 == "-" ? "" : $3); next }
    $1 == "S" { es[++ne] = $2; next }
    $1 == "F" { edges = "files, by edit set (" $2 ")"; next }
    $1 == "U" { unassessed = $2; next }
    $1 == "W" { wl[++nwl] = $2; if ($2 ~ /^MOVED-CITE /) { split($2, m, " "); sub(/:[0-9]+$/, "", m[2]); sub(/:[0-9,-]+$/, "", m[3])
                  mvf[nwl] = m[2]; mvt[nwl] = m[3] }; next }
    END {
      if (unassessed != "") { edges = "UNASSESSED -- the worklist did not run clean (" unassessed "); every file is ONE lane"
        for (k in isk) { if (r == "") r = k; else uni(r, k) } }
      else if (edges == "") { nmv = 0
        for (i = 1; i <= nwl; i++) if (i in mvf) { ma = keyof(mvf[i]); mb = keyof(mvt[i])
          if (ma != "" && mb != "" && !index(ma, SUBSEP)) { nb = split(mb, bb, SUBSEP); for (j = 1; j <= nb; j++) uni(ma, bb[j]); nmv++ } }
        edges = "files, by edit set and " nmv " MOVED-CITE edge(s) from serial-remediation-worklist.sh" }
      # Lanes, numbered in sorted node order; only nodes some part cites are lanes.
      nk = 0; for (k in isk) ks[++nk] = k
      for (i = 2; i <= nk; i++) { v = ks[i]; for (j = i - 1; j >= 1 && ks[j] > v; j--) ks[j + 1] = ks[j]; ks[j + 1] = v }
      for (p in pks) { n = split(pks[p], a, SUBSEP); for (i = 2; i <= n; i++) cited[fnd(a[i])] = 1 }
      nl = 0; for (i = 1; i <= nk; i++) { rt = fnd(ks[i]); if (!(rt in cited)) continue
        if (!(rt in lane)) lane[rt] = ++nl; lf[lane[rt]] = lf[lane[rt]] " " ks[i] }
      for (p in pks) { n = split(pks[p], a, SUBSEP); l = lane[fnd(a[2])]; lp[l] = lp[l] " " p }
      # The worklist routed: a fragment by the lanes its hits land in, a moved cite by its file.
      for (i = 1; i <= nwl; i++) { x = wl[i]
        if (x ~ /^  text: /) { frag(); ft = substr(x, 9); continue }
        if (x ~ /^    HIT /) { h = substr(x, 9); fhs = fhs (fhs == "" ? "" : ", ") h; sub(/:[0-9]+$/, "", h); fh = fh SUBSEP h; continue }
        frag()
        if (i in mvf) { ls = lanes_of(SUBSEP mvf[i] SUBSEP mvt[i])
          if (ls ~ /^[0-9]+$/) item[ls] = item[ls] "LANE-ITEM: " ls " " x "\n"; else fan = fan "FANIN: " x " (lanes " ls ")\n" } }
      frag()
      # Escalations: one lane when every file it names is that lane`s; otherwise the fan-in.
      for (i = 1; i <= ne; i++) { ls = (es[i] in et) ? lanes_of(et[es[i]]) : "out"
        if (ls ~ /^[0-9]+$/) item[ls] = item[ls] "LANE-ITEM: " ls " ESCALATED: " es[i] "\n"; else fan = fan "FANIN: ESCALATED: " es[i] " (lanes " ls ")\n" }
      if (nl >= 2) fan = fan "FANIN: sweep -- after every lane, grep -rn -F the text each lane replaced over the assembled files; a lane edit can leave a hit in another lane\n"
      print "LANE-EDGES: " edges
      for (l = 1; l <= nl; l++) { s = lp[l]; ns = split(s, sp, " "); for (i = 2; i <= ns; i++) { v = sp[i]; for (j = i - 1; j >= 1 && sp[j] > v; j--) sp[j + 1] = sp[j]; sp[j + 1] = v }
        s = ""; for (i = 1; i <= ns; i++) s = s " " sp[i]
        print "LANE: " l " files:" lf[l] " parts:" s; printf "%s", item[l] }
      printf "%s", fan
      print "LANE-COUNT: " nl
      nf = gsub(/FANIN: /, "&", fan); print "FANIN-COUNT: " nf
    }'
}

# --- THE DETAILED ROWS: every row (not unique per writer) with its ts and the hook's evidence keys.
# Read only when a --rerun narrows the window or the distinct-writer arm already has an overlap to
# test for an alias; otherwise ROWS above is the whole input and the default join is unchanged.
# Fields: path, agent, ts, session, tool_use_id, transcript_path, agent_transcript; `-` for empty.
DROWS=""; RR_SUPERSEDED=0; RR_LINES=""; AL_LINES=""; AL_N=0

# --- NESTED WRITERS (see "A NESTED WRITER IS ITS DISPATCHER'S"). FOLD_MAP holds one
# `<A>\t<P>\t<T>` line per writer that folds, FOLD_WHY one `<A>\t<reason>` line per writer that
# does not; every agent id with an artifact-write row in the window is resolved, so the part-record
# rows a re-run reads are folded by the same map.
PROBE_LEDGER="${STATE}/subagent-context.jsonl"; SPAWN_LEDGER="${STATE}/spawn-ledger.jsonl"
FOLD_MAP=""; FOLD_WHY=""; NEST_LINES=""
_fwr="$(jq -rn --arg since "$SINCE" --arg until "$UNTIL" '
  inputs | select(type == "object") | select(.kind == "artifact-write")
  | select((.agent_id // "") != "") | select((.ts | type) == "string")
  | select(.ts >= $since and .ts <= $until) | .agent_id | tostring' "$LEDGER" 2>/dev/null | sort -u)"
if [ -n "$_fwr" ]; then
  _fpr=""; _fsp=""
  [ -f "$PROBE_LEDGER" ] && _fpr="$(jq -nrR 'inputs | fromjson? | select(type == "object")
    | select((.agent_id // "") != "") | [(.agent_id | tostring), (.tool_use_id // "" | tostring)] | @tsv' "$PROBE_LEDGER" 2>/dev/null)"
  [ -f "$SPAWN_LEDGER" ] && _fsp="$(jq -nrR 'inputs | fromjson? | select(type == "object")
    | select((.tool_use_id // "") != "")
    | [(.tool_use_id | tostring), (if has("parent_agent_id") then "K" else "N" end), (.parent_agent_id // "" | tostring)]
    | @tsv' "$SPAWN_LEDGER" 2>/dev/null)"
  _fres="$({ printf '%s\n' "$_fwr" | sed '/^$/d; s/^/W\t/'
             printf '%s\n' "$_fpr" | sed '/^$/d; s/^/P\t/'
             printf '%s\n' "$_fsp" | sed '/^$/d; s/^/S\t/'; } | awk -F'\t' \
      -v pl="$PROBE_LEDGER" -v sl="$SPAWN_LEDGER" -v hp="$([ -f "$PROBE_LEDGER" ] && echo 1)" -v hs="$([ -f "$SPAWN_LEDGER" ] && echo 1)" '
    $1 == "W" { W[++nw] = $2; next }
    $1 == "P" { np[$2]++; if ($3 != "" && !(($2, $3) in pt)) { pt[$2, $3] = 1; nt[$2]++; tu[$2] = $3 }; next }
    $1 == "S" { ns[$2]++
                if ($3 == "K") { nk[$2]++; if (!(($2, $4) in sp)) { sp[$2, $4] = 1; npar[$2]++; par[$2] = $4 } }
                next }
    END {
      for (i = 1; i <= nw; i++) { a = W[i]
        if (!(a in np)) { print "U\t" a "\t" (hp ? "no row for " a " in " pl : pl " is absent"); continue }
        if (!(a in nt)) { print "U\t" a "\tits row in " pl " carries no tool_use_id"; continue }
        if (nt[a] > 1) { print "U\t" a "\tits rows in " pl " carry " nt[a] " different tool_use_ids"; continue }
        t = tu[a]
        if (!(t in ns)) { print "U\t" a "\t" (hs ? "no row for its spawn " t " in " sl : sl " is absent"); continue }
        if (!(t in nk)) { print "U\t" a "\tits spawn " t " in " sl " carries no parent_agent_id key (an older guard)"; continue }
        if (npar[t] > 1) { print "U\t" a "\tits spawn " t " in " sl " carries " npar[t] " different parent_agent_id values"; continue }
        p = par[t]
        if (p == "") { print "U\t" a "\tits spawn " t " in " sl " is the lead\047s own dispatch (parent_agent_id \"\")"; continue }
        if (p == a) { print "U\t" a "\tits spawn " t " in " sl " names " a " as its own parent"; continue }
        print "F\t" a "\t" p "\t" t
      }
    }')"
  FOLD_MAP="$(printf '%s\n' "$_fres" | sed -n 's/^F	//p')"
  FOLD_WHY="$(printf '%s\n' "$_fres" | sed -n 's/^U	//p')"
fi

_ovl0="$(printf '%s\n' "$ROWS" | awk -F'\t' 'NF >= 2 { n[$1]++ } END { for (f in n) if (n[f] > 1) { print f; exit } }')"
if [ -n "$RERUN" ] || [ -n "$_ovl0" ] || [ -n "$FOLD_MAP" ]; then
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
  # Subject mode kept only the subject's file set; keep the same paths here. A NESTED writer's agent
  # id (column 2) becomes its dispatcher's HERE, before the re-run, alias and distinct-writer arms
  # read a row, and each fold is named once: `N\t<line>` comes back beside the rows.
  _dm="$({ printf '%s\n' "$FOLD_MAP" | sed '/^$/d; s/^/M\t/'; printf '%s\n' "$ROWS" | sed '/^$/d; s/^/K\t/'
           printf '%s\n' "$DROWS" | sed '/^$/d; s/^/D\t/'; } | awk -F'\t' '
    BEGIN { OFS = "\t" }
    $1 == "M" { fm[$2] = $3; ft[$2] = $4; next }
    $1 == "K" { k[$2] = 1; next }
    ($2 in k) { $0 = substr($0, 3)
      if ($2 in fm) { a = $2; nr[a]++; if (!((a, $1) in fs)) { fs[a, $1] = 1; fl[a] = (a in fl) ? fl[a] ", " $1 : $1; if (!(a in seen)) { seen[a] = 1; A[++na] = a } }
                      $2 = fm[a] }
      print "R", $0 }
    END { for (i = 1; i <= na; i++) { a = A[i]
            print "N", "nested: " a " is " fm[a] "\047s subagent (spawn " ft[a] "); its " nr[a] " rows on " fl[a] " are counted as " fm[a] } }')"
  DROWS="$(printf '%s\n' "$_dm" | sed -n 's/^R	//p')"
  NEST_LINES="$(printf '%s\n' "$_dm" | sed -n 's/^N	//p')"
  [ -z "$NEST_LINES" ] || NEST_LINES="${NEST_LINES}
"
  ROWS="$(printf '%s\n' "$DROWS" | awk -F'\t' 'NF >= 2 { print $1 "\t" $2 }' | sort -u)"
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
    # The same nested-writer fold as the file rows, so a record written by the re-run writer's own
    # subagent is the re-run writer's. Each such fold is NAMED, on the same `nested:` output as the file
    # rows' folds: `N\t<line>` comes back beside the rows, one line per nested agent with part-record rows.
    if [ -n "$FOLD_MAP" ]; then
      _prq="$({ printf '%s\n' "$FOLD_MAP" | sed '/^$/d; s/^/M\t/'; printf '%s\n' "$_prrows" | sed '/^$/d; s/^/Q\t/'; } | awk -F'\t' -v px="$_prpfx" '
        BEGIN { OFS = "\t" }
        $1 == "M" { fm[$2] = $3; ft[$2] = $4; next }
        { $0 = substr($0, 3)
          if ($2 in fm) { a = $2; nr[a]++; f = px $1
                          if (!((a, f) in fs)) { fs[a, f] = 1; fl[a] = (a in fl) ? fl[a] ", " f : f; if (!(a in seen)) { seen[a] = 1; A[++na] = a } }
                          $2 = fm[a] }
          print "Q", $0 }
        END { for (i = 1; i <= na; i++) { a = A[i]
                print "N", "nested: " a " is " fm[a] "\047s subagent (spawn " ft[a] "); its " nr[a] " rows on " fl[a] " are counted as " fm[a] } }')"
      _prrows="$(printf '%s\n' "$_prq" | sed -n 's/^Q	//p')"
      _prn="$(printf '%s\n' "$_prq" | sed -n 's/^N	//p')"
      [ -z "$_prn" ] || NEST_LINES="${NEST_LINES}${_prn}
"
    fi
    _rres="$({ printf '%s' "$_rspec"; printf '%s\n' "$DROWS" | sed '/^$/d; s/^/D\t/'; printf '%s\n' "$_prrows" | sed '/^$/d; s/^/Q\t/'; } | awk -F'\t' -v px="$_prpfx" '
      $1 == "R" { if (!($2 in S)) { S[$2] = $3; PP[++npp] = $2 }; inF[$2, $4] = 1; nf[$2]++; F[$2, nf[$2]] = $4; fp[$4] = $2; next }
      $1 == "D" { nr++; for (j = 2; j <= NF; j++) r[nr, j - 1] = $j; next }
      $1 == "Q" { nq++; qb[nq] = $2; qa[nq] = $3; qt[nq] = $4; next }
      END {
        # Pass 0, RECORD-ONLY: P is record-only when no row on F_P falls at or after S_P. Its files then leave
        # fp, so pass 1 supersedes none of their rows, and its re-run writer is RECW, the agents that wrote P own
        # record at or after S_P: exactly one, and not one of the writers of F_P before S_P.
        for (i = 1; i <= nr; i++) {
          f = r[i, 1]; a = r[i, 2]; t = r[i, 3]
          if (!(f in fp)) continue
          p = fp[f]
          if (t >= S[p]) { post[p] = 1; continue }
          pre[p, a] = 1; k = p SUBSEP f; kn[k]++
          if (!((k, a) in kid)) { kid[k, a] = 1; kids[k] = (k in kids) ? kids[k] " " a : a }
          if (!(k in kf) || t < kf[k]) kf[k] = t
          if (!(k in kl) || t > kl[k]) kl[k] = t
        }
        for (i = 1; i <= nq; i++) {
          b = qb[i]; a = qa[i]; t = qt[i]
          if ((b in S) && t >= S[b] && !((b, a) in recw)) { recw[b, a] = 1; nrw[b]++; rwl[b, nrw[b]] = a; rws[b] = (b in rws) ? rws[b] " " a : a }
        }
        for (q = 1; q <= npp; q++) { p = PP[q]
          if (p in post) continue
          ro[p] = 1
          for (m = 1; m <= nf[p]; m++) delete fp[F[p, m]]
          if (nrw[p] == 0) continue
          if (nrw[p] > 1) print "RECMANY\t" p "\t" rws[p] "\t" px p
          else if ((p, rwl[p, 1]) in pre) print "RECOLD\t" p "\t" rwl[p, 1] "\t" px p
          else continue
          # Refused here, so the foreign-record and no-record lines, which presume a re-run writer, stand down.
          own[p] = 1; for (m = 1; m <= nrw[p]; m++) pq[p, rwl[p, m], "F"] = 1
        }
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
        # A record-only P: its one record writer, not an earlier writer of F_P, is its re-run writer.
        for (q = 1; q <= npp; q++) { p = PP[q]; if ((p in ro) && nrw[p] == 1 && !((p, rwl[p, 1]) in pre)) rw[p, rwl[p, 1]] = 1 }
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
          if (p in ro) { ln = ln "; record-only, by " rws[p]
            for (m = 1; m <= nf[p]; m++) { f = F[p, m]; k = p SUBSEP f
              ln = ln "; kept on " f ": " ((k in kn) ? kids[k] " (" kn[k] " rows, " kf[k] ".." kl[k] ")" : "none") }
            print "L\t" ln; continue }
          for (m = 1; m <= nf[p]; m++) { f = F[p, m]; k = p SUBSEP f
            if (k in sn) { ln = ln "; superseded on " f ": " sids[k] " (" sn[k] " rows, " sf[k] ".." sl[k] ")"; ns += sn[k] }
            else ln = ln "; superseded on " f ": none" }
          print "L\t" ln }
        print "N\t" ns + 0
      }')"
    _rres_nk="$(printf '%s\n' "$_rres" | grep -v '^K	')"
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
        RECMANY) refuse "--rerun ${_a}: no file ${_a} cites was written at or after the re-run start, so this is a record-only re-run, and its own part record ${_c} was written after the start by more than one agent (${_b}); a record-only re-run has exactly one writer" ;;
        RECOLD) refuse "--rerun ${_a}: no file ${_a} cites was written at or after the re-run start, so this is a record-only re-run, and its own part record ${_c} was written after the start by ${_b}, which wrote ${_a}'s files before it; the re-run is a NEW dispatch, never the writer it re-runs" ;;
        L) RR_LINES="${RR_LINES}${_a}
" ;;
        N) RR_SUPERSEDED="$_a" ;;
      esac
    done <<RROUT
${_rres_nk}
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
# AN EMPTY LEDGER IS DECIDED AFTER THE PARTS ARE READ (BL-807), never refused here: a round in which no
# lane wrote the subject is trivially disjoint, and only the parts' own `edit:` lines can say so.
NOLANE=0; NOLANE_LINE=""
[ -n "$ROWS" ] || NOLANE=1

OVERLAPS="$(printf '%s\n' "$ROWS" | awk -F'\t' '
  { n[$1]++; w[$1] = (w[$1] == "" ? $2 : w[$1] ", " $2) }
  END { for (f in n) if (n[f] > 1) print f "\t" w[f] }' | sort)"
if [ -n "$OVERLAPS" ]; then
  while IFS='	' read -r f w; do
    # Each writer that did not fold as a nested writer, and the ledger that lacked the link.
    _nf="$(printf '%s\n' "$FOLD_WHY" | awk -F'\t' -v w=", ${w}, " 'NF >= 2 && index(w, ", " $1 ", ") { printf "%s%s (%s)", (n++ ? "; " : ""), $1, $2 }')"
    refuse "${f} was written by more than one agent in the window: ${w}${_nf:+; not folded as a nested writer: ${_nf}}"
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
EDITS=""
CF_DEFER=1; [ "$DOCMODE$SUBJMODE" = 00 ] && CF_DEFER=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  for fld in disposition edit derivation; do
    repair_field "$fld" "$p" || refuse "$(basename "$p") has no '${fld}:' field as arm H reads it; the joined record would read structured on another part's labels"
  done
  checks_refusals "$(checks_field 0 "$p")"
  EDITS="${EDITS}$(CF_EDITS=1 checks_field 0 "$p")"
  _pc="$(part_cites "$p")"
  while IFS= read -r _t; do
    [ -n "$_t" ] || continue
    CITES="${CITES}C	$(basename "$p")	${_t}
"
  done <<TOKEOF
${_pc}
TOKEOF
done <<PAREOF
$PARTS
PAREOF

# --- A ROUND IN WHICH NO LANE WROTE THE SUBJECT (BL-807). Accepted only on THREE keys together:
#   1. no in-window row under the artifact path (ROWS empty, decided above);
#   2. no part cites an edited file: every non-escalated entry's `edit:` VALUE is n/a or none as
#      checks_field's val()/kw() read it (EDITS empty), and no token was cited (CITES empty). Keyed on
#      CITES alone it was keyed on TOKENS, and a lane that wrote through Bash with an off-grammar `edit:`
#      (`.../story-2.1` with no extension, prose, `.MD:3`, `.markdown:3`, a cite wrapped onto the next
#      line) cited nothing part_cites can spell and was accepted under a header saying no lane wrote;
#   3. no LANE AGENT has a subject row at ANY time. The lane agents are the writers of the part records
#      themselves (`<repair dir>/<part>.md`, non-recursive, the rows the re-run arm reads), and a subject
#      row is one ROWS' own path filters keep with the time filter dropped, a part record excepted. A
#      lane that wrote and failed to ledger its write cites it (key 2); a lane whose write fell outside a
#      mis-chosen window still holds the row (key 3). Every part must hold a row of its own, or the lane
#      set is not the round's and key 3 would pass over nothing.
# A part citing a file over an empty window falls through to the coverage join, where every citation
# is UNWRITTEN with the ledger's own remedy (BL-803), beside the refusal this line always gave.
if [ "$NOLANE" = 1 ]; then
  if [ -n "$CITES" ] || [ -n "$EDITS" ]; then
    refuse "the ledger records no dispatched write under ${APATH} in [${SINCE}, ${UNTIL}]; disjointness is unproven"
  else
    _nlpx="${SHARD_REL}/${SHARD_DIR##*/}/"
    _nlr="$(jq -rn --arg ap "$APATH" --arg sh "$SHARD_REL" --arg doc "$_jdoc" --arg px "$_nlpx" '
      inputs | select(type == "object") | select(.kind == "artifact-write")
       | select((.agent_id // "") != "") | select((.path | type) == "string")
       | (.path | ltrimstr($px)) as $b
       | if (.path | startswith($px)) and ($b | contains("/") | not) and ($b | endswith(".md"))
         then ["P", $b, (.agent_id | tostring)] | @tsv
         elif (.path == $ap or (.path | startswith($ap + "/"))) and ($doc == "1" or ((.path | startswith($sh + "/")) | not))
         then ["S", .path, (.agent_id | tostring), (.ts // "-" | tostring)] | @tsv
         else empty end' "$LEDGER" 2>/dev/null)" \
      || die "the write ledger ${LEDGER} does not parse as JSON lines"
    # Subject mode: APATH is the whole state dir, so a subject row is one on the split's own file set
    # (the K, S and O paths ROWS' subject filter reads), never another sprint's or seat's file.
    _nlk=""
    [ "$SUBJMODE" = 1 ] && _nlk="$(printf '%s\n%s\n%s\n' "$SUBJ_SET" "$SUBJ_SECTIONED" "$SUBJ_OUTSIDE" | sed '/^$/d; s/^/K	/')"
    _nlres="$({ printf '%s\n' "$PARTS" | sed '/^$/d; s@.*/@B	@'; printf '%s\n' "$_nlk" | sed '/^$/d'; printf '%s\n' "$_nlr" | sed '/^$/d'; } | awk -F'\t' -v sj="$SUBJMODE" '
      $1 == "B" { pb[++nb] = $2; next }
      $1 == "K" { ks[$2] = 1; next }
      $1 == "P" { has[$2] = 1; la[$3] = 1; next }
      $1 == "S" { if (sj == "1" && !($2 in ks)) next; s[++ns] = $2 "\t" $3 "\t" $4; next }
      END {
        for (i = 1; i <= nb; i++) if (!(pb[i] in has)) print "NOROW\t" pb[i]
        for (i = 1; i <= ns; i++) { split(s[i], f, "\t"); if (f[2] in la) print "WROTE\t" s[i] }
        n = 0; for (a in la) n++; print "LANES\t" n
      }')"
    _nll=0
    while IFS='	' read -r _k _a _b _c; do
      case "$_k" in
        NOROW) refuse "no lane wrote under ${APATH} in the window and no part cites a file, but ${_nlpx}${_a} has no ledger row, so its writer is unknown and cannot be shown to have written nothing; re-dispatch that lane writing its part record through Edit, Write or MultiEdit" ;;
        WROTE) refuse "no lane wrote under ${APATH} in [${SINCE}, ${UNTIL}], but lane agent ${_b} wrote ${_a} at ${_c}, outside that window and cited by no part: take --since from the lane dispatch and --until from \`date -u\` after the last lane reports, and cite the edit in that lane's part" ;;
        LANES) _nll="$_a" ;;
      esac
    done <<NLEOF
$_nlres
NLEOF
    NOLANE_LINE="no lane wrote the subject: 0 ledger rows under ${APATH} in [${SINCE}, ${UNTIL}], and every part cites no edited file (${_nll} lane agent(s), none with a subject row at any time)"
  fi
fi

# THE COVERAGE JOIN. Ledger side: file -> writers (harness ids). Part side: part -> cited files.
# A cited token resolves to the ledger path it equals or is a `/`-suffix of, so a bare basename,
# a `stories/<file>` spelling and a full `_bmad-output/...` path all land on the same file.
#   UNWRITTEN  a part cites a file no agent wrote under the artifact in the window. This is also
#              how a LOST LEDGER ROW surfaces: the hook's append is silent on failure (it must
#              never block the Edit), so a write it failed to record reads here as a claimed
#              edit with no write, and the join refuses rather than acquits. Its remedy is read
#              from the ledger with the time filter dropped: a write of that path set aside by
#              this join, a last write before --since or a first write after --until is named
#              with its ts and agent, and only a path with no row at all keeps the Bash cause.
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

# THE UNWRITTEN REMEDY (BL-803). Read only when JOINRES carries an UNWRITTEN row: ONE jq pass over the
# ledger under ROWS' own kind / agent_id / APATH / SHARD_REL-DOCMODE filters, the time filter dropped.
# Each UNWRITTEN token resolves by the coverage join's rule (a path equal to it, or it a `/`-suffix of
# the path); a token resolving to no path or to more than one keeps the two-cause text. For the one
# path P: ASIDE = its earliest in-window row (in the window, yet absent from ROWS: this join set it
# aside); BEFORE = its LATEST row before SINCE; AFTER = its EARLIEST row after UNTIL. `-` is empty.
# Lines: token, P, aside ts, aside agent, before ts, before agent, after ts, after agent.
UW_LOOK=""
_uw="$(printf '%s\n' "$JOINRES" | awk -F'\t' '$1 == "UNWRITTEN" { print $3 }' | sort -u)"
if [ -n "$_uw" ]; then
  UW_LOOK="$({ printf '%s\n' "$_uw" | sed '/^$/d; s/^/T\t/'
               jq -rn --arg ap "$APATH" --arg sh "$SHARD_REL" --arg doc "$_jdoc" '
    inputs | select(type == "object") | select(.kind == "artifact-write")
     | select((.agent_id // "") != "") | select((.ts | type) == "string")
     | select(.path == $ap or (.path | startswith($ap + "/")))
     | select($doc == "1" or ((.path | startswith($sh + "/")) | not))
     | ["R", .path, (.agent_id | tostring), .ts] | @tsv' "$LEDGER" 2>/dev/null; } | awk -F'\t' -v s="$SINCE" -v u="$UNTIL" '
    $1 == "T" { nt++; TK[nt] = $2; next }
    $1 == "R" { p = $2; ag = $3; ts = $4
                if (!(p in seen)) { seen[p] = 1; np++; P[np] = p }
                if (ts >= s && ts <= u) { if (!(p in at) || ts < at[p]) { at[p] = ts; aa[p] = ag } }
                else if (ts < s)        { if (!(p in bt) || ts > bt[p]) { bt[p] = ts; ba[p] = ag } }
                else                    { if (!(p in ft) || ts < ft[p]) { ft[p] = ts; fa[p] = ag } }
                next }
    function d(x) { return (x == "" ? "-" : x) }
    END {
      for (k = 1; k <= nt; k++) {
        tok = TK[k]; n = 0; hit = ""
        for (i = 1; i <= np; i++) {
          p = P[i]
          if (p == tok || (length(p) > length(tok) && substr(p, length(p) - length(tok)) == "/" tok)) { n++; hit = p }
        }
        if (n != 1) continue
        print tok "\t" hit "\t" d(at[hit]) "\t" d(aa[hit]) "\t" d(bt[hit]) "\t" d(ba[hit]) "\t" d(ft[hit]) "\t" d(fa[hit])
      }
    }')"
fi
unwritten_remedy() { # <token> -> the remedy clause after " -- "
  local _l _x _p _at _aa _bt _ba _ft _fa _r=""
  _l="$(printf '%s\n' "$UW_LOOK" | awk -F'\t' -v t="$1" '$1 == t { print; exit }')"
  if [ -n "$_l" ]; then
    IFS='	' read -r _x _p _at _aa _bt _ba _ft _fa <<UWEOF
$_l
UWEOF
    if [ "$_at" != "-" ]; then
      if [ -n "$RERUN" ]; then
        printf '%s' "${_p} was written in the window at ${_at} by ${_aa}, but this join set that write aside (a --rerun supersedes it): the re-run writes it after its start, or the part stops citing it"
      else
        printf '%s' "${_p} was written in the window at ${_at} by ${_aa}, but this join set that write aside: see the join's other refusal for that file, or the part stops citing it"
      fi
      return 0
    fi
    [ "$_bt" != "-" ] && _r="the ledger's last write of ${_p} was at ${_bt} by ${_ba}, before --since ${SINCE}: the part cites an edit it did not make in this window; rewrite the part record through a re-dispatch writing with Write, an entry whose fix was already in place taking \`edit: n/a\`, then re-run the join with the same --since and a new --until, or re-dispatch that shard if the edit is still owed"
    if [ "$_ft" != "-" ]; then
      _x="the ledger's first write of ${_p} after the window was at ${_ft} by ${_fa}, after --until ${UNTIL}: take a new --until after the shard reports and re-run the join"
      _r="${_r:+${_r}; also }${_x}"
    fi
  fi
  [ -n "$_r" ] || _r="the file was written through Bash or another tool that reaches no Edit matcher, or it was never written; re-dispatch that shard writing through Edit, Write or MultiEdit"
  printf '%s' "$_r"
}

if [ -n "$JOINRES" ]; then
  while IFS='	' read -r kind a b c; do
    case "$kind" in
      UNWRITTEN) refuse "${a} cites ${b}, which no dispatched agent wrote under ${APATH} in the window -- $(unwritten_remedy "$b")" ;;
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

# The SPEC render arm (above record_tail), subject mode: only when the split gave the SPEC a part, whose
# memlog SUBJ_SET carries in the ledger spelling. Every other mode prints nothing for it.
SPEC_LINE=""
if [ "$SUBJMODE" = 1 ]; then
  spec_render_probe
  _sm="$(printf '%s\n' "$SUBJ_SET" | awk '/(^|\/)specs\/s[0-9]+\/[^\/]+\/\.memlog\.md$/ { print; exit }')"
  if [ -n "$_sm" ]; then spec_render_check "${STATE_PARENT}${_sm}" ""
  else SPEC_LINE="SPEC-RENDER: SKIP -- the split gave the SPEC no part, so no SPEC was repaired in this join"; fi
fi

[ -e "$OUT" ] && refuse "${OUT} already exists; a join never overwrites a repair record"

[ "$refuse_n" -eq 0 ] || exit 2

# --- document mode: assemble BEFORE the record. A refusal here writes nothing -- the assembler
# refuses without touching the document, and no record is written after it.
ASM_LINE=""
SUBJ_BEFORE=""; SUBJ_AFTER=""
if [ "$SUBJMODE" = 1 ]; then
  # The pair separator: `@` only when the sibling merge's --pair-sep exits 0 printing exactly `@`
  # (an old merge prints REFUSED and exits 2); anything else is `=`. Asked once.
  if JR_PS="$(bash "${JR_SCRIPT_DIR}/merge-adversarial-shards.sh" --pair-sep 2>/dev/null)" && [ "$JR_PS" = "@" ]; then JR_SEP='@'; else JR_SEP='='; fi
  SUBJ_BEFORE="$(awk -F'\t' -v sep="$JR_SEP" '$1 == "sha" { printf " %s%s%s", $2, sep, $3 }' "$SUBJ_REC")"
  ASM_LINE="$(bash "$PSUBJ" --assemble "$SHARD_DIR" 2>&1)" || {
    printf '%s\n' "$ASM_LINE" >&2
    die "the sections of the sprint ${SPRINT} subject did not assemble; no repair record was written"
  }
  for _st in product-brief SPEC prd architecture-impact; do
    _rel="$(awk '/REQUIREMENTS_SUBJECT v1/ { inb = 1; next } /REQUIREMENTS_SUBJECT_END/ { inb = 0 } inb && $1 == "file:" && $2 == s { print $3 }' s="$_st" "${JR_ROOT}/${_srm}")"
    if command -v shasum >/dev/null 2>&1; then _h="$(shasum -a 256 "${JR_ROOT}/${_rel}" | cut -d' ' -f1)"
    else _h="$(sha256sum "${JR_ROOT}/${_rel}" | cut -d' ' -f1)"; fi
    SUBJ_AFTER="${SUBJ_AFTER} ${_st}${JR_SEP}${_h}"
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
  DOC_REL="$(root_rel "$DOC_ABS")"
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
  [ -z "$NEST_LINES" ] || printf '%s' "$NEST_LINES"
  if [ "$SUBJMODE" = 1 ]; then
    if [ -n "$NOLANE_LINE" ]; then echo "${NOLANE_LINE};"; else echo "every subject file and section copy was written by exactly one agent ${_inwin};"; fi
    printf '%s\n' "$ASM_LINE" | sed 's/^/partition-subject.sh: /'
    echo ""
    echo "- artifact: ${_srm}"
    echo "- artifact_sha_before:${SUBJ_BEFORE}"
    echo "- artifact_sha_after:${SUBJ_AFTER}"
  elif [ "$DOCMODE" = 1 ]; then
    if [ -n "$NOLANE_LINE" ]; then echo "${NOLANE_LINE};"; else echo "every section under ${APATH} was written by exactly one agent ${_inwin};"; fi
    echo "partition-document.sh: ${ASM_LINE}"
    echo ""
    echo "- artifact: ${DOC_REL}"
    echo "- artifact_sha_before: ${DOC_BEFORE}"
    echo "- artifact_sha_after: ${DOC_AFTER}"
  else
    if [ -n "$NOLANE_LINE" ]; then echo "${NOLANE_LINE}."; else echo "every file under ${APATH} outside ${SHARD_REL}/ was written by exactly one agent ${_inwin}."; fi
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
# The program's own seal row: the joined record is sealed, and `--sources`/`--escalations` compare it
# (content-seal.sh, PROGRAM ROWS). A failed append leaves the record with no row, which is never
# compared, so it changes no outcome.
[ -f "$SEAL" ] && { bash "$SEAL" --record "$STATE" program:join-remediator-shards "$OUT" \
  || echo "NOTE: the program seal row for ${OUT} was not appended" >&2; }
_jx=""
[ -z "$RERUN" ] || _jx=", ${RR_SUPERSEDED} superseded rows"
[ "$AL_N" = 0 ] || _jx="${_jx}, ${AL_N} alias rows"
echo "JOINED: ${OUT} ($(printf '%s\n' "$PARTS" | grep -c .) parts, $(printf '%s\n' "$WRITERS" | grep -c .) writers${_jx})"
[ -z "$NEST_LINES" ] || printf '%s' "$NEST_LINES"
# Every escalated entry, by part, and the count; then the repaired edits whose cross-file siblings
# and moved cites only the serial remediator can check. Either count above 0 dispatches the serial
# remediator, in every mode, with every ESCALATED: line in its brief (_gate-procedures.md,
# "Adversarial repair dispatch").
printf '%s' "$ESC_LINES"
echo "ESCALATED-COUNT: ${ESC_N}"
printf '%s' "$GAP_LINES"
echo "SERIAL-REQUIRED: ${SERIAL_N}"
case "$ARTIFACT" in *-serial) ;; *) lane_report ;; esac
[ -z "$SPEC_LINE" ] || printf '%s\n' "$SPEC_LINE"
exit 0
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
join_main "$@"
