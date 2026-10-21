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
#   merge-adversarial-shards.sh --check-header <shard-file> --axis convergence|elicitation
#                                                   ONE shard's header, by the merge's own checks
#                                                   (THE HEADER CHECK, below): exit 0 and nothing
#                                                   printed on pass; exit 1 and the merge's own
#                                                   `REFUSED: <reason>` line on the first failure;
#                                                   exit 2 on bad arguments. Reads no sibling, no
#                                                   harness record and no shard dir, so a delivery
#                                                   join can call it on one file while its agent lives.
#   Every merge mode (not --map) also reads the three harness records named under THE DISPATCH ID,
#   and refuses a shard set they do not cover: a caller seeding shards by hand seeds the records too.
#
#   <shard-dir> is `<planning>/s<N>/shards/<artifact>-p<M>/`. Everything else is DERIVED from
#   that one path, so the placement cannot be mis-spelled by a caller:
#     stories   <planning>/s<N>/<artifact>/          (the multi-file artifact under review)
#     output    <planning>/s<N>/<artifact>-adversarial-p<M>.md
#   No project root is resolved: the siblings read are the convergence validator and, in
#   section mode, partition-document.sh, both located beside this script (both layouts put them
#   in one directory). A shard's relative `artifact:` is resolved by walking UP from s<N>/ for
#   the first directory it names a file under -- a walk, never a root. The three harness records
#   the dispatch ids come from (THE DISPATCH ID, below) are found the same way: `<planning>` must
#   be named `planning-artifacts`, and the state directory is its parent.
#     write ledger    <planning>/.artifact-writes.jsonl
#     spawn ledger    <state>/spawn-ledger.jsonl
#     probe ledger    <state>/subagent-context.jsonl     (corroborates every meta file; sole source for a pre-upgrade row)
#
# THE DISPATCH ID IS DERIVED, NEVER SELF-REPORTED. A dispatched model cannot know the
#   `tool_use_id` of the Agent call that spawned it, so a shard's own `tool_use_id:` is whatever
#   someone typed. Measured on the reference consumer, sprints 315-319: of 413 convergence shard
#   files, 360 carried a final id written by someone other than the adversary; the lead hand-filled
#   whole shard sets; a hand-copied typo merged; 12 fabricated ids passed the old `toolu_` shape
#   check and 13 carried `NOT_ACCESSIBLE`. So each shard's id is derived from records the harness
#   wrote, in three hops:
#     1. shard -> writing agent: the write ledger's `kind: "artifact-write"` rows whose `path` is
#        `<state-dir-name>/planning-artifacts/s<N>/shards/<artifact>-p<M>/<file>` (the spelling
#        ai-dlc-gate-remediation-guard.sh normalises every payload path to). Each gives `agent_id`.
#     2. agent -> dispatch id: `<transcript_path minus .jsonl>/subagents/agent-<agent_id>.meta.json`,
#        field `toolUseId`, from that row's own `transcript_path`. A row with no `transcript_path`
#        (written before the hook recorded one) falls back to the probe ledger's `agent_id ->
#        tool_use_id` row, and to nothing else.
#     3. dispatch id -> role: every spawn-ledger row carrying that `tool_use_id` names role
#        `adversary`.
#   THE META FILE IS CORROBORATED. The lead can Write `agent-<id>.meta.json`; it cannot Write the
#   probe ledger, a guarded root that ai-dlc-subagent-probe.sh fills at SubagentStop with the
#   `toolUseId` it read from that same meta file. So a credited writer resolved through its meta file
#   must also have a probe row, and every probe row for it must carry the meta's id (a writer --rerun
#   supersedes is held to the second half only; see RE-DISPATCH). Measured on the reference
#   consumer: 44 of 44 shard writers resolved through a meta file had a probe row carrying the same id,
#   and 0 of the 732 agents with a row on an adversary shard lacked a probe row. The probe row
#   lands after the agent's last write (p50 7s, p99 52s, max 150s on that corpus). A `sha=` seal is
#   DELIVERED with no window (wait-for-deliverable.sh), so the merge can run ahead of the row; the
#   refusal then names the wait. The hook has silent no-row paths (unreadable transcript, peak 0, no
#   jq), so an absent row on a CREDITED writer is refused, never trusted: merge once the adversary
#   has stopped, and if it has stopped with no row, re-dispatch the shard and merge with --rerun,
#   which makes the row-less writer a superseded one (RE-DISPATCH, below).
#   REFUSED (exit 2, nothing written): a shard with no write-ledger row; a writer whose meta file
#   or `toolUseId` is absent; a writer whose meta file names a dispatch the probe ledger has no row
#   for, or names another dispatch than its probe rows; a pre-upgrade writer with no probe row; a
#   dispatch id with no spawn row; a writer of any role other than `adversary` (a remediator, an sm,
#   ...); two or more adversary dispatches writing one shard; one dispatch deriving for two shards;
#   one dispatch writing in this shard dir and under any OTHER `shards/<x>-p<M>/` dir; a row under
#   this shard dir written in ANOTHER TREE (ONE TREE, below); and a self-reported id that is REAL
#   (`DISPATCH_ID_ERE`, declared beside the ceilings in validate-adversarial-convergence.sh and read
#   from there: `toolu_` and 24 base62 characters, `toolu_` with 13 digits and a counter, or `call_`
#   and 32 hex characters under a local-model lead) and differs from the derived one. Any other self
#   value -- `NOT_ACCESSIBLE`, `unavailable`, absent, or a fabricated `toolu_cross1_g1_dispatch` -- is
#   ignored: the derived id is written. NOTHING FALLS BACK TO THE SELF-REPORT. There is no
#   zero-writer refusal of its own: a shard with no writer has no row, and a shard whose writers
#   are all of another role is refused on the role.
#   The merged `tool_use_id` is the derived id of the first cross shard, and `shard_tool_use_ids`
#   lists the derived ids.
#   THE CONTENT SEAL. A shard whose bytes differ from its newest `kind: "content-seal"` row (taken
#   by ai-dlc-content-seal.sh after every Write or Edit) is REFUSED, naming that row's writer and the
#   remedy; a shard with no seal row is not compared. content-seal.sh owns the set and the check.
#   A shard whose LAST TOOL seal row (actor `agent` or `session`, in file order; program rows such as
#   `--mark`'s skipped; `content-seal.sh --last-tool-row`, one call over all shards) is the top-level
#   session's is REFUSED in the same phase, naming its tool and ts and the remedy: re-dispatch the
#   adversary and merge with `--rerun <shard>.md@<ISO>`. A later agent row clears it. A shard with no
#   tool row is not judged. An agent-teams teammate writes with no `agent_id` and so reads as `session`
#   here; such a shard is already refused at the write-ledger join, whose rows need an agent_id, so this
#   adds no new refusal for it.
#   LIMITS. A shard written with Bash (a redirect, `sed -i`, a script's open) leaves no row and is
#   refused: write shards with Write or Edit. A shard AMENDED with Bash after a Write is refused by
#   the seal. A row is an ATTEMPT recorded at PreToolUse, not proof
#   that the recorded agent authored the bytes on disk. A lead Bash write to any of the three
#   records, or to `subagent-context.jsonl`, can forge the join; the hook denies Write/Edit to all
#   four, and BL-530's second half owns the Bash floor. No second ledger is kept here.
#   Rows are keyed on the FULL path under this shard dir (the prefix above), never on a basename:
#   a row for `2.md` under another shard dir or another sprint is not a row for this shard.
#   ONE DISPATCH, ONE SHARD DIR: the agents with a row in this dir, superseded writers included, are
#   then looked up across the whole write ledger, and a row of theirs under another `shards/*-p<M>/`
#   dir refuses. Rows outside every `-p<M>` dir are not read, so a `.draft` beside its shard is this
#   dir's. False-positive set, measured on the reference consumer's ledger as it stood: 71 (agent,
#   shard dir) pairs would refuse, every one a remediator the role hop already refuses, and 0 an
#   adversary. The write ledger is transient, so that is one snapshot and a floor, not a census.
#   ONE TREE. A row's `path` is normalised to start at the state dir's name, so a write to a
#   worktree's or a scratch clone's copy of this shard reads byte-identical to one in this tree. The
#   hook records `root`, the physical directory holding the state dir the write landed in; a row
#   under this shard dir whose `root` is not this tree's is refused by name. A row with no `root`
#   predates the field and is read as this tree's, so a ledger written before it still merges.
#   The meta file supplies the id whenever the row carries `transcript_path`, and the probe ledger
#   corroborates it (above); the probe row SUPPLIES the id only for a row without one. A dispatch id with two spawn rows is refused if ANY of
#   them names a role other than `adversary`.
#
# RE-DISPATCH OF ONE SHARD -- `--rerun <shard>.md@<ISO>`, repeatable; every merge mode.
#   Write-ledger rows never expire, so when the lead re-dispatches a stalled adversary the shard
#   carries rows from two dispatches and the join above refuses it as two adversaries. The grammar
#   and messages parallel `join-remediator-shards.sh --rerun`. For each named shard P with start S:
#   - rows on P (and on `P.draft`, the adversary's draft path) with ts < S are dropped; their
#     writers are P's SUPERSEDED writers. Every refusal of the join then runs unchanged on the
#     narrowed rows, so P needs exactly one adversary dispatch writing it at or after S, and that
#     dispatch must have written no other shard.
#   - Every superseded writer is resolved through the same chain as a shard writer (meta file or
#     probe row, the spawn ledger), and refused unless it is an `adversary` dispatch: a non-adversary
#     write on a shard is a role violation, not a stale dispatch. Its probe corroboration is
#     EQUALITY ONLY: a stalled adversary never reached SubagentStop, so it has no probe row, and
#     requiring one would make a re-dispatched shard unmergeable. A probe row it does have must carry
#     its meta file's id.
#     RESIDUAL, ACQUITTED: a forged meta on a superseded writer that never stopped resolves to
#     whatever dispatch id the lead typed into it, so a non-adversary that never reached SubagentStop
#     can be passed off as an adversary and set aside. Narrower than before this check existed,
#     which acquitted every superseded writer whatever its role.
#   - Refused: <ISO> malformed; P not a shard in the dir; P named twice; a superseded writer with
#     ANY row in the shard dir on a file other than P or `P.draft` (it was not only P's writer --
#     another shard's adversary that edited P is a cross-shard write, never a stale dispatch); a
#     superseded writer with any row on P at or after S (the re-run is a NEW dispatch, never one of
#     the writers it supersedes); an S further than BACKDATE_TOL_S (read from
#     validate-artifact-budget.sh, the BACKDATED arm's own tolerance) from any spawn-ledger `ts` of
#     the dispatch the join credits for P, or a `ts` that does not parse. `--map` with `--rerun` is
#     refused.
#   - The merged block adds one `rerun: <shard> since <S>; superseded: <agent ids> (<n> rows,
#     <first>..<last>)` line per re-run after `shard_tool_use_ids:`, and MERGED adds `superseded=<n>`.
#   S is the re-dispatch's dispatched-at, and is checked against the time its dispatch recorded, so a
#   typed S binds to nothing (BL-598). Without --rerun nothing above runs and the output is the
#   bytes it was.
#
# THE SERIES STEM IS NOT THE ARTIFACT. A shard dir whose <artifact> ends in `-adversarial`
#   (`shards/coe-adversarial-p1/`) names the SERIAL file's stem, not the artifact, and was merged
#   silently into `coe-adversarial-adversarial-p1.md`, a series no gate reads. It is REFUSED
#   right after <artifact> is derived, in every mode, before anything is read or written.
#   False-positive set: 0 of the 82 shard directories on disk in the reference consumer (75
#   committed) end in `-adversarial-p<M>`, against 73 ending in `-p<M>` as the control. Narrowing: the test keys on the stem SUFFIX only, so a stem that merely
#   contains the word (`adversarial-notes-p1`) stays legal. Limit: it does not catch the
#   full-step-name shape (`carry-over-evaluation-p<M>`), which the generic `<artifact>` of
#   `_gate-procedures.md` literally yields; the step file names the `coe` stem for that.
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
#   re-dispatch written beside the original must not be silently ignored. The one exception is
#   `<shard name>.draft` where `<shard name>` is itself a valid shard name (`2.md.draft`,
#   `cross-1.md.draft`): the adversary's unfinished copy, which the write ledger already accepts
#   beside its shard (RE-DISPATCH, and ONE DISPATCH, ONE SHARD DIR). It is skipped and reported on
#   stderr as `NOTE: ignored draft <name>`, never read and never merged. `notes.md`, and a draft of a
#   name that is no shard, still refuse.
#
# THE OWNER RULE. The cross groups overlap (every unordered pair of units is in at least one
#   group, some pairs in several), so a finding two groups both see would be summed twice. Each
#   cross finding has one owner, the group `partition-document.sh --cross-owner <K> <cited
#   ordinals>` names. A cross shard reads the WHOLE document and may cite any ordinal, so a
#   finding outside its owner's shard is accepted, and REFUSED only when the owner's shard
#   carries a finding citing the IDENTICAL set -- the one case the two are the same finding.
#
# SEAT-COMPLETE. A shard dispatched under the early-write brief ends, as its LAST NON-BLANK line,
#   in `seat-complete: <step> adversary <shard> findings=<n>`, written once as its final write.
#   If ANY shard in the directory ends in that line, every shard must, and one
#   that does not is REFUSED as unfinished; a marker whose `findings=<n>` differs from the
#   findings parsed in its shard is REFUSED as truncated. Keyed on the marker's
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
# THE HEADER CHECK (check_header; `--check-header` runs it on one file, the merge loop calls the
#   same functions at their own sites, so one source decides both and a shard defective twice prints
#   the refusal it always printed). Per shard: exactly one provenance block; integer
#   findings_critical and findings_major, prior_scope and underived within them; on the convergence
#   axis a verdict of EXIT_CONDITION_MET / EXIT_CONDITION_NOT_MET / DIVERGENT_HARD_BLOCK (so
#   `PENDING-LEAD`, absent, or the template's `<EXIT_CONDITION_MET|...>` placeholder fails), on the
#   elicitation axis no verdict and `skill: bmad-advanced-elicitation`; invoked_at per RE_ISO;
#   skill, mode and lead_role each present and not an unfilled `<...>` placeholder; the
#   CRITICAL/MAJOR heading counts; the `### ` reservation (FINDING GRAMMAR); and, when the shard
#   ends in `seat-complete: ... findings=<n>`, that <n> equals the findings parsed.
#   MERGE-ONLY, never in --check-header: the derived dispatch id and the self-reported tool_use_id
#   (they need the harness records), the same skill/mode/lead_role across shards, a unique id per
#   shard, the mode-dependent artifact/artifact_sha checks (they need the map, the stories or the
#   document), citations against the ordinal set, and the seat-complete set rule.
#   COMMENTS ARE STRIPPED, per `provenance-block.json` `parser.comments`, spelled as
#   validate-provenance-block.sh spells it (`\s+#.*$`): parse_shard cuts `[ \t]+#.*$` from the RAW
#   value, before the leading trim, so `findings_major: 2 # x` reads 2, `verdict: EXIT_CONDITION_MET # x`
#   reads EXIT_CONDITION_MET, and `verdict:   # none` reads empty (refused as `<none>`). Whitespace
#   before `#` is required: `findings_major: 1#x` is still not an integer and `artifact_sha: abc#def`
#   is untouched. One site, so every header field goes through it. Downstream: a commented real
#   `tool_use_id` is now compared with the derived id (as it should be), and the skill, mode,
#   lead_role and resolves_divergence values the merge writes carry no comment.
#
# FINDING GRAMMAR (the partition this script checks; `adversary.md` cites it, not restates it)
#   A finding is a `### ` heading carrying a severity word inside the shard `## Findings` section (up to the next
#   `## ` heading); lines inside ``` or ~~~ fences are not headings. A fence opens on a run of 3+ backticks whose info string carries no backtick, or 3+ tildes, and closes only on a bare run of its own character. Its severity is the FIRST
#   of CRITICAL / MAJOR / MINOR / NIT in the heading. Each finding carries EXACTLY ONE line
#       stories: <ordinal>[, <ordinal>...]          e.g. `stories: 03` or `stories: 01, 04`
#   outside a fence, citing ordinals from `--map`. A per-ordinal shard may cite ONLY its own
#   ordinal; a cross shard only findings citing two or more DISTINCT ordinals (the owner rule
#   above). Every cited ordinal must be within 1..K.
#   Per shard, the CRITICAL-heading count must equal `findings_critical` and the MAJOR-heading
#   count `findings_major` -- otherwise the partition is checked over findings that are not
#   the ones the counts describe.
#   The severity word is UPPERCASE: `sev()` is case-sensitive, so `### F-1 (major)` carries no
#   severity.
#   `### ` UNDER `## Findings` IS RESERVED FOR A FINDING. A `### ` heading there opens a finding
#   ONLY if it carries one of CRITICAL / MAJOR / MINOR / NIT (the `sev()` rule above); the `F-<n>`
#   prefix is not required (`### F-1 (MAJOR)` and `### MAJOR: x` each count 1). Any other unfenced
#   `### ` heading there -- `### Probes run (no finding)`, `### F-7 — INFO`, `### F-1 (major)` -- is
#   REFUSED, never skipped and never counted, with a message naming the reserved form and the fix:
#   move it under its own `## ` section, or demote it to `#### `. Fenced lines stay ignored. The
#   refusal runs AFTER the CRITICAL/MAJOR count check, so a severity-less heading whose declared
#   counts disagree is still refused on the count, and BEFORE the seat-complete count.
#   Narrowing, and how the false-positive set reached zero: a census over the reference consumer's
#   934 committed shard files found 0 offenders in convergence `<artifact>-p<M>` dirs (the only
#   dirs this merge reads) and 16 elsewhere -- 9 lowercase `— major` headings in
#   `carry-over-evaluation-party-repair-p1/4.md`, 5 lowercase `E-<n> (major)` in
#   `stories-elicitation/05.md`, and 2 `F-7/F-8 — INFO`. The first 14 are outside this merge's
#   population by PROCEDURE: party-repair shards are joined by join-remediator-shards.sh
#   (`_gate-procedures.md`, "Shard by file" for the party round), and `<artifact>-elicitation/` is
#   read by no merge (`--map` refuses it, and `--elicitation` merges only the requirements
#   subject). Nothing MECHANICAL keeps them out: `carry-over-evaluation-party-repair-p1` parses as
#   `<artifact>-p<M>`, and only the absent `s<N>/<artifact>/` dir refuses it in files mode. Matching
#   severity case-insensitively was weighed and NOT taken: a lowercase heading would then count
#   toward findings_critical/findings_major, refusing on the count shards that merge today, and the
#   step files teach the UPPERCASE word. So the refusal names the UPPERCASE requirement instead.
#   `INFO` is not a severity: an INFO note is a non-finding the shard moves out of `## Findings` or
#   demotes, and the remedy text says so.
#   A finding is NEVER a `## ` heading. An unfenced `## ` heading outside the provenance block whose
#   first token is a finding id (`F-1`, `M1`: capital letters, an optional `-`, digits) is REFUSED
#   wherever it sits -- under `## Findings`, after it, or in a shard with no `## Findings` section at
#   all. That is the seat-file style of "Validation cycle" item 1, which ends the section here and
#   would otherwise merge the shard as zero findings.
#
# THE MERGE
#   Sums findings_critical, findings_major, findings_minor, findings_critical_prior_scope and
#   findings_major_underived with the CONVERGENCE VALIDATOR defaults: prior_scope absent means
#   ALL of that shard CRITICALs (fail-closed), underived absent means zero. Verdict:
#     DIVERGENT_HARD_BLOCK   if any shard declared it, or (convergence axis, never --elicitation)
#                            if the SUMMED prior_scope exceeds PREV_CRIT, the findings_critical of the
#                            nearest earlier pass in this series that declares one -- arm C's test
#                            (validate-adversarial-convergence.sh, `prior -gt PREV_CRIT`, with PREV_CRIT
#                            rolled only over passes whose count reads), applied to the sum no shard saw;
#     EXIT_CONDITION_MET     iff summed critical <= CRITICAL_EXIT_CEILING and summed blocking
#                            MAJOR (major - underived) <= MAJOR_EXIT_CEILING;
#     EXIT_CONDITION_NOT_MET otherwise.
#   Both ceilings are READ from validate-adversarial-convergence.sh, never restated here. So are the
#   pieces of the summed-divergence walk: `order_key` (the `(pass|p)N` key), `block_field` and
#   `severity_count` (the FIRST provenance block's count, as arm C reads it) are extracted from the
#   validator as at_key is; only its `--series` exclusions (`*-resolution-p*`, `*-repair-p*`, `*-repair-*`, validator :187) are
#   restated, being a `case` inside its loop. The earlier passes are `<artifact>-adversarial-p*` beside
#   the output whose key is below <M>, nearest first; one with no readable count is skipped. No earlier
#   pass, or none readable, stamps nothing and leaves the series to the validator. The walk runs only
#   when the summed prior_scope is above 0. A DIVERGENT_HARD_BLOCK merge adds one body line under the
#   RECOMPUTED sentence naming the rule (`shard-declared`, or the summed count against the file and
#   its count); every other merge's bytes are unchanged. A stamped pass needs nothing a shard writes:
#   arms D and F read only its verdict, its own artifact_sha and the NEXT pass's resolves_divergence.
#   artifact_sha is `<basename-stem>=<sha> ...` in ordinal order (each per-ordinal shard claim,
#   each checked against the story bytes on disk); tool_use_id is the FIRST cross shard's DERIVED
#   id (`cross` or `cross-1`); shard_tool_use_ids is `<ordinal>=<id> ... cross-1=<id> ... cross-<G>=<id>`
#   (`cross=<id>` when G=1), every id derived; invoked_at is the EARLIEST shard. The merged body opens with the
#   ordinal map (the `--map` output, fenced), then every shard body in ordinal order, the cross
#   shards last in group order under one header per group, each with its own provenance block
#   stripped, so the output carries exactly ONE provenance block.
#
# EXIT
#   0  merged (stdout `MERGED: ...`), or the output already exists byte-identical (`UNCHANGED:`)
#   2  REFUSED (stdout `REFUSED: <reason>`) -- nothing written. Includes an existing output that
#      differs: a pass file a remediator may already have read is never silently overwritten.
#
# --dry-run (every merge mode, not --map): the same checks, nothing written, and the refusals of the
#   FIRST FAILING PHASE all printed, one `REFUSED: <reason>` line each, instead of the first only. It
#   does NOT print every refusal of the merge: the phases are barriers, and a later phase is not
#   reached while an earlier one refuses. In order:
#     1. arguments, placement, the map, the ceilings          exit at once, one line
#     2. the shard-set walk (names, duplicates, cross shape, missing shards)   all collected
#     2b. the content seal (every shard whose bytes differ from its seal row)  all collected
#     3. the dispatch ids from the harness records (--rerun staging included)  exit at once, one line
#     4. the seat-complete set check                          exit at once, one line
#     5. per shard: a structural refusal (provenance block, counts, verdict, invoked_at, dispatch id,
#        skill, sha, artifact) skips the rest of THAT shard; finding-level refusals and the count
#        checks are all collected
#     6. an existing output that differs                      exit at once, one line
#   Exit 2 when any line was printed; 0 with `DRY-RUN: clean` otherwise. Without --dry-run the first
#   refusal exits, as it always did.
set -u
export LC_ALL=C
# The separator class this merge's own pair parser READS (validate-adversarial-convergence.sh's).
PAIR_SEP='[=@]'

refuse() { printf 'REFUSED: %s\n' "$*"; exit 2; }
# collect: a refusal inside a phase that --dry-run walks to its end. Without --dry-run it IS refuse,
# so every merge without the flag exits at its first refusal, as before.
DRY=0; DRY_N=0
collect() {
  [ "$DRY" -eq 1 ] || refuse "$@"
  printf 'REFUSED: %s\n' "$*"; DRY_N=$((DRY_N + 1))
}
# phase_barrier: --dry-run stops here when the phase just walked collected anything.
phase_barrier() { [ "$DRY_N" -eq 0 ] || exit 2; }

# ---- THE HEADER CHECK: the shard grammar, shared by the merge loop and --check-header -----------
# One awk pass per shard. Emits:  B <starts> <ends>  /  F <key> <value>  /  X <line> <sev> <n-stories-lines> <stories>
# /  Y <line of a wrong-axis citation, 0 none>  /  H <line of the first unfenced `## <ID>` heading outside the block, 0 none>
# /  R <line of the first unfenced `### ` heading under `## Findings` with no severity word, 0 none>
# Reads $CITE and $OTHER, which every caller sets first.
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
        sub(/[ \t]+#.*$/, "", v)
        sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
        if (!(k in seen)) { seen[k] = 1; printf "F %s %s\n", k, v }
      }
      next
    }
    fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { fence = 0; next } }
    !fence && /^[ \t]*(```+[^`]*|~~~+.*)$/ { fence = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    fence { next }
    /^## [A-Z]+-?[0-9]+([^A-Za-z0-9]|$)/ { if (hline == 0) hline = NR }
    /^## / { flush(); infind = ($0 ~ /^## Findings[ \t]*$/); next }
    infind && /^### / { flush(); if (sev($0) == "NONE") { if (rline == 0) rline = NR; next } fl = NR; fs = sev($0); fn = 0; fst = ""; next }
    infind && fl > 0 && index($0, cite ":") == 1 {
      fn++; v = substr($0, length(cite) + 2); sub(/^[ \t]*/, "", v); gsub(/[ \t]+/, "", v); fst = v; next
    }
    infind && fl > 0 && other != "" && index($0, other ":") == 1 { if (wrong == 0) wrong = NR; next }
    END { flush(); printf "B %d %d\n", starts + 0, ends + 0; printf "Y %d\n", wrong + 0; printf "H %d\n", hline + 0; printf "R %d\n", rline + 0 }
  ' cite="$CITE" other="$OTHER" "$1"
}

field() { # $1 parse file, $2 key
  awk -v k="$2" '$1 == "F" && $2 == k { sub(/^F [^ ]+ ?/, ""); print; exit }' "$1"
}
digits() { case "$1" in ""|*[!0-9]*) ;; *) printf '%s' "$1" ;; esac; }
# Held in variables: bash 3.2 reads an unquoted `[[ =~ $var ]]` regex as ERE, fork-free.
# invoked_at: to the second, optionally with a fraction -- the reference consumer stamps both.
RE_ISO='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?Z$'

# Each check below returns 0 on pass, or sets HDR_MSG (the refusal text, without `REFUSED: `) and
# returns 1. They are called in the MAIN shell, never inside `$( )`: check_header_core sets the
# shard's crit/major/prior/under/minor/v/at for the merge to sum, and ANY_DIVERGENT.
# check_header_core <parse file> <shard file> <axis: convergence|elicitation>
#   the block count, the integer counts and their bounds, the verdict (or its absence), invoked_at.
check_header_core() {
  local P="$1" sf="$2" ax="$3"
  set -- $(awk '$1 == "B" { print $2, $3 }' "$P")
  [ "${1:-0}" = "1" ] && [ "${2:-0}" = "1" ] \
    || { HDR_MSG="$sf carries ${1:-0} provenance block opening(s) and ${2:-0} closing(s); a shard carries exactly one block"; return 1; }
  crit="$(digits "$(field "$P" findings_critical)")"
  major="$(digits "$(field "$P" findings_major)")"
  [ -n "$crit" ] && [ -n "$major" ] \
    || { HDR_MSG="$sf does not declare integer findings_critical and findings_major"; return 1; }
  prior="$(digits "$(field "$P" findings_critical_prior_scope)")"
  [ -n "$prior" ] || prior="$crit"
  [ "$prior" -le "$crit" ] || { HDR_MSG="$sf declares findings_critical_prior_scope=$prior above findings_critical=$crit"; return 1; }
  under="$(digits "$(field "$P" findings_major_underived)")"
  [ -n "$under" ] || under=0
  [ "$under" -le "$major" ] || { HDR_MSG="$sf declares findings_major_underived=$under above findings_major=$major"; return 1; }
  minor="$(digits "$(field "$P" findings_minor)")"
  [ -n "$minor" ] || minor=0

  if [ "$ax" = elicitation ]; then
    # Elicitation is not a convergence pass: a verdict here would be read as one by every gate.
    [ -z "$(field "$P" verdict)" ] || { HDR_MSG="$sf declares a verdict; an elicitation shard carries none"; return 1; }
  else
  v="$(field "$P" verdict | tr '[:lower:]' '[:upper:]' | sed -e 's/[^A-Z]\{1,\}/_/g' -e 's/^_//' -e 's/_$//')"
  case "$v" in
    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET) ;;
    DIVERGENT_HARD_BLOCK) ANY_DIVERGENT=1 ;;
    *) HDR_MSG="$sf declares verdict '${v:-<none>}', not one of EXIT_CONDITION_MET EXIT_CONDITION_NOT_MET DIVERGENT_HARD_BLOCK"; return 1 ;;
  esac
  fi

  at="$(field "$P" invoked_at)"
  [[ $at =~ $RE_ISO ]] || { HDR_MSG="$sf invoked_at '${at:-<none>}' is not ISO 8601 UTC to the second (an optional .<fraction> before Z is accepted)"; return 1; }
  return 0
}
# hdr_role <parse file> <shard file> <skill|mode|lead_role> <axis> -> HDR_VAL
#   present, not an unfilled `<...>` template placeholder, and on the elicitation axis skill is
#   bmad-advanced-elicitation. Agreement ACROSS shards is the merge's, never this check's.
hdr_role() {
  HDR_VAL="$(field "$1" "$3")"
  [ -n "$HDR_VAL" ] || { HDR_MSG="$2 declares no $3"; return 1; }
  case "$HDR_VAL" in
    "<"*) HDR_MSG="$2 declares $3 '$HDR_VAL', an unfilled template placeholder; the shard states the value it ran with"; return 1 ;;
  esac
  if [ "$3" = skill ] && [ "$4" = elicitation ] && [ "$HDR_VAL" != "bmad-advanced-elicitation" ]; then
    HDR_MSG="$2 declares skill '$HDR_VAL'; an elicitation shard runs bmad-advanced-elicitation"; return 1
  fi
  return 0
}
# check_reserved <parse file> <shard file>: no `### ` heading under `## Findings` without a severity
#   word (FINDING GRAMMAR, the reservation).
check_reserved() {
  local rl; rl="$(awk '$1 == "R" { print $2 }' "$1")"
  [ "${rl:-0}" = "0" ] || { HDR_MSG="$2:$rl is a \`### \` heading under \`## Findings\` with no severity word; there a \`### \` heading is reserved for a finding and carries one of CRITICAL / MAJOR / MINOR / NIT, UPPERCASE (FINDING GRAMMAR in merge-adversarial-shards.sh) -- move it under its own \`## \` section, or demote it to \`#### \`"; return 1; }
  return 0
}
# check_counts <parse file> <shard file>: the CRITICAL-heading count equals findings_critical and the
#   MAJOR-heading count findings_major (crit and major as check_header_core set them).
check_counts() {
  local nc nm
  nc="$(awk '$1 == "X" && $3 == "CRITICAL"' "$1" | grep -c .)" || nc=0
  nm="$(awk '$1 == "X" && $3 == "MAJOR"' "$1" | grep -c .)" || nm=0
  [ "$nc" -eq "$crit" ] && [ "$nm" -eq "$major" ] \
    || { HDR_MSG="$2 declares $crit CRITICAL / $major MAJOR but its ## Findings section heads $nc CRITICAL / $nm MAJOR findings"; return 1; }
  return 0
}
# ends_in_marker <shard file>: its last non-blank line opens `seat-complete: `.
ends_in_marker() { awk 'NF { l = $0 } END { exit !(l ~ /^seat-complete: /) }' "$1"; }
# marker_n <shard file>: the marker's declared `findings=<n>`, `-` when the marker carries none.
marker_n() { awk 'NF { l = $0 } END { if (match(l, /findings=[0-9]+[ \t]*$/)) { v = substr(l, RSTART + 9); sub(/[ \t]+$/, "", v); print v } else print "-" }' "$1"; }
# check_marker <parse file> <shard file> <declared n, empty when the shard ends in no marker>
#   the marker's count against the findings parsed here: a shard truncated after its marker, or
#   marked before its findings, disagrees.
check_marker() {
  local scn="$3" nfx
  if [ -n "$scn" ]; then
    nfx="$(grep -c '^X ' "$1")" || nfx=0
    [ "$scn" = "$nfx" ] \
      || { HDR_MSG="$2 ends in 'seat-complete: ... findings=$scn' but its ## Findings section heads $nfx finding(s); the marker is written once, last, counting the shard's findings"; return 1; }
  fi
  return 0
}
# check_header <parse file> <shard file> <axis>: every single-shard check, in the merge's order.
#   --check-header runs exactly this. The merge loop calls the same pieces at their own sites, so a
#   shard failing two of them prints the refusal it printed before this function existed.
check_header() {
  local k
  check_header_core "$1" "$2" "$3" || return 1
  for k in skill mode lead_role; do hdr_role "$1" "$2" "$k" "$3" || return 1; done
  check_counts "$1" "$2" || return 1
  check_reserved "$1" "$2" || return 1
  if ends_in_marker "$2"; then check_marker "$1" "$2" "$(marker_n "$2")" || return 1; fi
  return 0
}

USAGE="usage: merge-adversarial-shards.sh [--dry-run] [--rerun <shard>.md@<ISO> ...] [--map | --document <path> | --subject <N> [--base <sha>] [--elicitation]] <planning>/s<N>/shards/<artifact>-p<M>"
MAP_ONLY=0; DOCUMENT=""; SUBJECT=""; SUBJ_BASE=""; ELICIT=0
# --rerun is taken out of the argument list wherever it sits, so the mode parse below is unchanged
# for every call that carries none. Each value is checked once the shard set is known.
RERUN=""; _rest=()
while [ $# -gt 0 ]; do
  case "$1" in
    --rerun) [ $# -ge 2 ] || refuse "--rerun needs <shard>.md@<ISO>"
             RERUN="${RERUN}${2}
"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) _rest[${#_rest[@]}]="$1"; shift ;;
  esac
done
set -- ${_rest[@]+"${_rest[@]}"}
# The separator a pair is EMITTED with: `@` only when every reader installed beside this script
# accepts it, else `=`. Any absent or unreadable reader answers `=`. Siblings are found from $0,
# never from $VALIDATOR, so the answer is the installed tree's own.
pair_sep() {
  local d
  d="$(cd "$(dirname "$0")" && pwd)" || { printf '='; return 0; }
  [ "$(grep -cxF "PAIR_SEP='[=@]'" "$d/validate-adversarial-convergence.sh" 2>/dev/null)" = 1 ] || { printf '='; return 0; }
  [ "$(grep -cxF "PAIR_SEP='[=@]'" "$d/partition-subject.sh" 2>/dev/null)" = 1 ] || { printf '='; return 0; }
  bash "$d/validate-provenance-block.sh" --accepts-at-pair >/dev/null 2>&1 || { printf '='; return 0; }
  printf '@'
}
case "${1:-}" in
  -h|--help) awk 'NR > 1 && /^set -u/ { exit } NR > 1' "$0"; exit 0 ;;
  --pair-sep)
    [ $# -eq 1 ] && [ -z "$RERUN" ] && [ "$DRY" -eq 0 ] || { printf '%s\n' "REFUSED: --pair-sep takes no other argument"; exit 2; }
    pair_sep; exit 0 ;;
  --check-header)
    # One shard, one header; exits here, before any sibling, VALIDATOR, subject or base is read.
    [ $# -eq 4 ] && [ "$3" = "--axis" ] || { printf '%s\n' "usage: merge-adversarial-shards.sh --check-header <shard-file> --axis convergence|elicitation"; exit 2; }
    [ -z "$RERUN" ] && [ "$DRY" -eq 0 ] || { printf '%s\n' "REFUSED: --check-header reads one shard; --rerun and --dry-run belong to a merge"; exit 2; }
    case "$4" in convergence|elicitation) ;; *) printf 'REFUSED: --axis takes convergence or elicitation (got %s)\n' "$4"; exit 2 ;; esac
    [ -f "$2" ] && [ -r "$2" ] || { printf 'REFUSED: %s is not a readable file\n' "$2"; exit 2; }
    CITE=stories; OTHER=""; ANY_DIVERGENT=0
    CH_P="$(mktemp "${TMPDIR:-/tmp}/merge-adversarial-shards.ch.XXXXXX")" || { printf '%s\n' "REFUSED: mktemp failed"; exit 2; }
    parse_shard "$2" > "$CH_P" || { rm -f "$CH_P"; printf 'REFUSED: parsing %s did not run\n' "$2"; exit 2; }
    if check_header "$CH_P" "$2" "$4"; then rm -f "$CH_P"; exit 0; fi
    rm -f "$CH_P"; printf 'REFUSED: %s\n' "$HDR_MSG"; exit 1 ;;
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
# Computed once per run; every emitted `<stem><sep><sha>` pair below uses it.
PAIR_OUT='='; [ "$MAP_ONLY" -eq 1 ] || [ -n "$DOCUMENT" ] || PAIR_OUT="$(pair_sep)"
# The CITATION AXIS: the one line name a finding cites its unit by. A line of the OTHER axis is
# refused explicitly (below), never merely ignored -- ignored, a `stories:` line in a document
# shard is invisible, and the finding is then judged on whatever `sections:` line sits beside it.
# Files mode keeps no second axis, so its behaviour on every input is what it was before sections.
if [ -n "$DOCUMENT" ] || [ -n "$SUBJECT" ]; then CITE=sections; OTHER=stories; NOUN=section; else CITE=stories; OTHER=""; NOUN=story; fi
if [ -n "$SUBJECT" ]; then NOUN=part; fi
# The header axis check_header reads: elicitation carries no verdict, every other merge one.
if [ "$ELICIT" -eq 1 ]; then AXIS=elicitation; else AXIS=convergence; fi

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
case "$ARTIFACT" in *-adversarial) refuse "shard directory $SHARD_BASE names the series, not the artifact: the dir is s<N>/shards/<artifact>-p<M>/ and this would write ${ARTIFACT}-adversarial-p$PASS.md (carry-over-evaluation.md: s<N>/shards/coe-p<M>/)" ;; esac
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
SUBJ_SHA_LIST="$(awk -F'\t' -v sep="$PAIR_OUT" '{ printf " %s%s%s", $1, sep, $2 }' "$T/stems")"
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
if [ "$MAP_ONLY" -eq 1 ]; then
  [ -z "$RERUN" ] || refuse "--rerun supersedes write-ledger rows at a merge; --map reads no ledger"
  [ "$DRY" -eq 0 ] || refuse "--dry-run checks a merge; --map reads no shard and writes nothing"
  cat "$T/map"; exit 0
fi
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
# THE DISPATCH-ID GRAMMAR, read from the same declaration file as the ceilings, so arm K and this
# merge accept one set of id shapes (BL-597). A single-quoted ERE declared exactly once, else empty.
read_grammar() { # $1 name -> the quoted value, or empty unless declared exactly once
  local hits
  hits="$(grep -E "^$1='[^']+'\$" "$VALIDATOR")" || return 0
  [ "$(printf '%s\n' "$hits" | wc -l | tr -d ' ')" = "1" ] || return 0
  # The grep above fixed the form NAME='value': drop the name and `=`, then the two quotes.
  hits="${hits#*=}"; hits="${hits#?}"; printf '%s' "${hits%?}"
}
[ -n "$MAJOR_CEIL" ] && [ -n "$CRIT_CEIL" ] \
  || refuse "MAJOR_EXIT_CEILING / CRITICAL_EXIT_CEILING are not each declared exactly once as an integer in $VALIDATOR"

# ---- the shard set ------------------------------------------------------------------------
: > "$T/shards" || refuse "cannot stage the shard set"
# Dotfiles are not walked: no shard name begins with a dot, and a Finder `.DS_Store` (one exists
# in the reference consumer's _bmad-output) would otherwise refuse a healthy shard set.
for f in "$SHARD_DIR"/*; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  [ -f "$f" ] || { collect "$f is not a regular file; the shard directory holds only <ordinal>.md and the cross shards ($CROSS_KEYS)"; continue; }
  # `<shard name>.draft` is the adversary's unfinished copy (the write ledger accepts it beside its
  # shard): judged by the shard name it hangs off, skipped when that is valid, never merged.
  bn="$b"; is_draft=0
  case "$b" in *.md.draft) bn="${b%.draft}"; is_draft=1 ;; esac
  case "$bn" in
    cross.md) key="cross" ;;
    cross-*.md)
      gn="${bn#cross-}"; gn="${gn%.md}"
      case "$gn" in ""|*[!0-9]*) collect "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)"; continue ;; esac
      key="cross-$((10#$gn))" ;;
    *.md)
      case "${bn%.md}" in ""|*[!0-9]*) collect "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)"; continue ;; esac
      key="$(norm_ord "${bn%.md}")"
      [ -n "$key" ] || { collect "$f names ordinal ${bn%.md}, outside 1..$K (the $UNIT_COUNT)"; continue; } ;;
    *) collect "$f is not a shard name (<ordinal>.md, cross.md or cross-<g>.md)"; continue ;;
  esac
  if [ "$is_draft" -eq 1 ]; then
    # Only a draft of a shard this set OWES is skipped: `cross-9.md.draft` hangs off no shard.
    case " $ORDINALS $CROSS_KEYS " in
      *" $key "*) printf 'NOTE: ignored draft %s\n' "$b" >&2 ;;
      *) collect "$f is a draft of $key, which is no shard of this set (the shards are: $ORDINALS and $CROSS_KEYS)" ;;
    esac
    continue
  fi
  printf '%s\t%s\n' "$key" "$f" >> "$T/shards" || refuse "cannot stage the shard set"
done
cut -f1 "$T/shards" | sort | uniq -d > "$T/dups" || refuse "cannot stage the duplicate check"
while IFS= read -r dup; do
  [ -n "$dup" ] || continue
  collect "shard $dup was delivered more than once in $SHARD_DIR"
done < "$T/dups"
# The cross shards delivered must be EXACTLY the table's: a mix of `cross.md` and `cross-<g>.md`,
# a `cross-<g>` the table does not print, or the wrong spelling for G are each refused by name.
x_plain=0; x_num=0
while IFS="$(printf '\t')" read -r xk xf; do
  case "$xk" in
    cross) x_plain=1 ;;
    cross-*) x_num=1
      case " $CROSS_KEYS " in *" $xk "*) ;; *) collect "$xf is $xk, which partition-document.sh --cross-groups $K does not print (the cross shards for K=$K are: $CROSS_KEYS)" ;; esac ;;
  esac
done < "$T/shards"
[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \
  && collect "$SHARD_DIR mixes cross.md with cross-<g>.md; a shard set is one cross shape or the other (for K=$K: $CROSS_KEYS)"
[ "$x_plain" -eq 1 ] && [ "$G" -gt 1 ] \
  && collect "$SHARD_DIR holds cross.md, but the $UNIT_COUNT is $K, whose cross groups are $CROSS_KEYS; a single cross shard is owed only at K=2"
for idx in $ORDINALS $CROSS_KEYS; do
  [ -n "$(awk -F'\t' -v k="$idx" '$1 == k { print; exit }' "$T/shards")" ] || collect "shard $idx is missing from $SHARD_DIR (expected: $ORDINALS and $CROSS_KEYS)"
done
phase_barrier

# ---- the dispatch ids, DERIVED from the harness records (see THE DISPATCH ID in the header) ----
# After the set-level refusals above, so a duplicate, unknown or missing shard keeps its own
# message; before any shard is parsed. Writes $T/ids: one `<key>\t<derived id>` row per shard, in
# the shard-set order, the id EMPTY for a shard with no write-ledger row (refused per shard in the
# loop below, naming the file), or a single `REFUSE\t<reason>` row.
command -v jq >/dev/null 2>&1 \
  || refuse "jq is not on PATH; each shard's dispatch id is derived from the harness's JSON records and cannot be read without it"
REC_PLAN="$(dirname "$SPRINT_DIR")"
[ "$(basename "$REC_PLAN")" = "planning-artifacts" ] \
  || refuse "$SPRINT_DIR is not under a planning-artifacts/ directory; each shard's writer is read from <state>/planning-artifacts/.artifact-writes.jsonl, so the shard dir is <state>/planning-artifacts/s<N>/shards/<artifact>-p<M>/"
REC_STATE="$(dirname "$REC_PLAN")"
REC_WRITES="$REC_PLAN/.artifact-writes.jsonl"
REC_SPAWNS="$REC_STATE/spawn-ledger.jsonl"
REC_PROBES="$REC_STATE/subagent-context.jsonl"
REC_PREFIX="$(basename "$REC_STATE")/planning-artifacts/$(basename "$SPRINT_DIR")/shards/$SHARD_BASE/"
# ---- THE CONTENT SEAL (BL-530): a shard amended after its last sealed write is refused ---------
# `content-seal.sh`, beside this script, owns the sealed set, the row and the comparison; this site
# only hands it the shard files. Its seal rows (`kind: "content-seal"`) are read there with no
# agent_id filter, and every write-ledger read below keys on `kind == "artifact-write"`, so neither
# sees the other's rows. A shard with no seal row is not compared, so a tree written before the
# recorder existed merges as it did. With the sibling absent the merge refuses only when the ledger
# holds a TOOL seal row (`"actor":"agent"` or `"session"`; only seal rows carry `actor`); otherwise
# there is nothing it could have compared, and a program row alone is record-only.
SEAL="$(cd "$(dirname "$0")" && pwd)/content-seal.sh"
if [ -f "$SEAL" ]; then
  cut -f2 "$T/shards" | bash "$SEAL" --check "$REC_STATE" - > "$T/seal" 2> "$T/seal.err"; SEAL_RC=$?
  case "$SEAL_RC" in
    0) ;;
    1) while IFS= read -r _sl; do [ -n "$_sl" ] && collect "$_sl"; done < "$T/seal" ;;
    *) refuse "the content-seal check over $REC_WRITES did not run (exit $SEAL_RC): $(head -1 "$T/seal.err")" ;;
  esac
  phase_barrier
  # THE LAST TOOL WRITE (BL-669): a shard whose last agent/session seal row is the top-level session's
  # carries the lead's bytes, re-sealed. Program rows are skipped by content-seal.sh, so a --mark after
  # the session's Edit cannot hide it. One call over every shard, as --check.
  _us="$(printf '\037')"
  cut -f2 "$T/shards" | bash "$SEAL" --last-tool-row "$REC_STATE" - > "$T/ltr" 2> "$T/ltr.err" \
    || refuse "the content-seal last-tool-row read over $REC_WRITES did not run: $(head -1 "$T/ltr.err")"
  while IFS="$_us" read -r _lf _la _laid _lt _lts; do
    [ "$_la" = session ] && collect "$_lf was last written by the top-level session (${_lt:-tool} at ${_lts:-<no ts>}), which carries no agent_id; only an adversary writes an adversary shard, so the lead's bytes would merge as the adversary's -- re-dispatch the adversary for $(basename "$_lf") and merge with --rerun $(basename "$_lf")@<the re-dispatch's ISO start>"
  done < "$T/ltr"
  phase_barrier
elif [ -f "$REC_WRITES" ] && grep -qE '"actor":[[:space:]]*"(agent|session)"' "$REC_WRITES"; then
  refuse "$REC_WRITES carries content-seal rows but $SEAL is absent, so no shard's bytes can be compared with its seal; reinstall ai-dlc"
fi
# One jq per record. Write rows: `<file under the shard dir>\t<agent_id>\t<meta path, empty when
# the row carries no transcript_path>`.
: > "$T/wrows" && : > "$T/spawns" && : > "$T/probes" && : > "$T/metas" || refuse "cannot stage the harness records"
# ONE TREE (BL-596). The hook records `root`, the physical directory holding the state dir the write
# landed in, because the row's `path` is normalised and reads byte-identical for a worktree's or a
# clone's shard. A row under this shard dir whose root is another tree is refused by name, never
# silently dropped. A row with no `root` predates the field and is read as this tree's.
REC_ROOT="$(cd "$REC_STATE/.." 2>/dev/null && pwd -P)" || refuse "cannot resolve the tree holding $REC_STATE"
if [ -f "$REC_WRITES" ]; then
  OT="$(jq -rn --arg p "$REC_PREFIX" --arg r "$REC_ROOT" '
      first(inputs | select(type == "object") | select(.kind == "artifact-write")
        | select((.path // "") | type == "string" and startswith($p))
        | select((.root // "") | type == "string" and . != "" and . != $r)
        | [.path, (.agent_id // ""), (.ts // "" | tostring), .root] | @tsv)' "$REC_WRITES" 2>/dev/null)" \
    || refuse "the write ledger $REC_WRITES does not parse as JSON lines"
  if [ -n "$OT" ]; then
    IFS="$(printf '\t')" read -r _op _oa _ot _or <<< "$OT"
    refuse "${_op} carries a write-ledger row by agent ${_oa} at ${_ot} written under ${_or}, not this tree (${REC_ROOT}); a worktree's or a clone's write is not this tree's shard -- write the shard in this tree"
  fi
fi
if [ -f "$REC_WRITES" ]; then
  jq -rn --arg p "$REC_PREFIX" '[inputs | select(type == "object") | select(.kind == "artifact-write")
      | select((.path // "") | type == "string" and startswith($p)) | select((.agent_id // "") != "")
      | [(.path | ltrimstr($p)), .agent_id,
         (if (.transcript_path // "") == "" then ""
          else (.transcript_path | rtrimstr(".jsonl")) + "/subagents/agent-" + .agent_id + ".meta.json" end)]]
    | unique | .[] | @tsv' "$REC_WRITES" > "$T/wrows" 2>/dev/null \
    || refuse "the write ledger $REC_WRITES does not parse as JSON lines"
fi
# Every agent with a row in this shard dir, taken BEFORE --rerun narrows the rows, so a superseded
# writer is still one of them for the cross-dir check (ONE DISPATCH, ONE SHARD DIR, below).
cut -f2 "$T/wrows" | sort -u > "$T/wagents" || refuse "cannot stage the shard dir's writers"
if [ -f "$REC_SPAWNS" ]; then
  jq -rn '[inputs | select(type == "object") | select((.tool_use_id // "") | type == "string" and . != "")
      | [.tool_use_id, (.role // "" | tostring)]] | unique | .[] | @tsv' "$REC_SPAWNS" > "$T/spawns" 2>/dev/null \
    || refuse "the spawn ledger $REC_SPAWNS does not parse as JSON lines"
fi
if [ -f "$REC_PROBES" ]; then
  jq -rn '[inputs | select(type == "object") | select((.agent_id // "") != "" and (.tool_use_id // "") != "")
      | [.agent_id, .tool_use_id]] | unique | .[] | @tsv' "$REC_PROBES" > "$T/probes" 2>/dev/null \
    || refuse "the probe ledger $REC_PROBES does not parse as JSON lines"
fi
# ---- RE-RUN OF ONE SHARD (--rerun <shard>.md@<ISO>; see RE-DISPATCH in the header) ----------
# Without --rerun nothing here runs and $T/wrows is the jq output above, unchanged. With it, the
# rows are re-read WITH their ts, the superseded rows are dropped, and $T/wrows is rebuilt from what
# remains, so every refusal of the join below runs unchanged on the narrowed rows.
RR_LINES=""; RR_SUPERSEDED=0
if [ -n "$RERUN" ]; then
  RE_RR_ISO='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
  printf '%s' "$RERUN" > "$T/rerun.in" && : > "$T/rspec" || refuse "cannot stage the re-run starts"
  while IFS= read -r _r; do
    [ -n "$_r" ] || continue
    case "$_r" in *@*) ;; *) refuse "--rerun ${_r} is not <shard>.md@<ISO>" ;; esac
    _rp="${_r%@*}"; _rs="${_r##*@}"
    [[ $_rs =~ $RE_RR_ISO ]] || refuse "--rerun ${_r}: the re-run start must be YYYY-MM-DDTHH:MM:SSZ (got '${_rs}')"
    [ -n "$(awk -F'\t' -v b="$_rp" '{ n = $2; sub(/.*\//, "", n) } n == b { print; exit }' "$T/shards")" ] \
      || refuse "--rerun ${_r}: ${_rp} is not a shard under ${SHARD_DIR}"
    [ -z "$(awk -F'\t' -v b="$_rp" '$1 == b { print; exit }' "$T/rspec")" ] \
      || refuse "--rerun names ${_rp} twice; one shard has one re-run start"
    printf '%s\t%s\n' "$_rp" "$_rs" >> "$T/rspec" || refuse "cannot stage the re-run starts"
  done < "$T/rerun.in"
  : > "$T/drows" || refuse "cannot stage the write ledger rows"
  if [ -f "$REC_WRITES" ]; then
    jq -rn --arg p "$REC_PREFIX" '[inputs | select(type == "object") | select(.kind == "artifact-write")
        | select((.path // "") | type == "string" and startswith($p)) | select((.agent_id // "") != "")
        | [(.path | ltrimstr($p)), .agent_id, (.ts // "" | tostring),
           (if (.transcript_path // "") == "" then ""
            else (.transcript_path | rtrimstr(".jsonl")) + "/subagents/agent-" + .agent_id + ".meta.json" end)
          ]] | .[] | @tsv' "$REC_WRITES" > "$T/drows" 2>/dev/null \
      || refuse "the write ledger $REC_WRITES does not parse as JSON lines"
  fi
  # Pass 1: a row on a re-run shard before its start is superseded, and its writer is a superseded
  # writer of that shard. Pass 2: every row a superseded writer has in the shard dir must be on that
  # shard or its `.draft` and before the start. The first violation is the one refusal printed.
  awk -F'\t' -v fr="$T/rspec" '
    FILENAME == fr { S[$1] = $2; RP[++np] = $1; next }
    { n++; f[n] = $1; a[n] = $2; t[n] = $3; m[n] = $4 }
    END {
      for (i = 1; i <= n; i++) {
        p = f[i]
        if (!(p in S) || !(t[i] < S[p])) continue
        drop[i] = 1; sw[p, a[i]] = 1; sn[p]++
        if (!((p, a[i]) in sid)) { sid[p, a[i]] = 1; sids[p] = (p in sids) ? sids[p] " " a[i] : a[i] }
        if (!(p in sf) || t[i] < sf[p]) sf[p] = t[i]
        if (!(p in sl) || t[i] > sl[p]) sl[p] = t[i]
      }
      for (i = 1; i <= n; i++)
        for (q = 1; q <= np; q++) {
          p = RP[q]
          if (!((p, a[i]) in sw)) continue
          if (f[i] != p && f[i] != p ".draft") { print "OUT\t" p "\t" a[i] "\t" f[i] "\t" t[i]; exit }
          if (t[i] >= S[p]) { print "SAME\t" p "\t" a[i] "\t" f[i] "\t" t[i]; exit }
        }
      for (q = 1; q <= np; q++) {
        p = RP[q]; ln = "rerun: " p " since " S[p]
        if (p in sn) { ln = ln "; superseded: " sids[p] " (" sn[p] " rows, " sf[p] ".." sl[p] ")"; ns += sn[p] }
        else ln = ln "; superseded: none"
        print "L\t" ln
      }
      print "N\t" ns + 0
      for (i = 1; i <= n; i++) if (!(i in drop)) print "K\t" f[i] "\t" a[i] "\t" m[i]
      for (i = 1; i <= n; i++) if (i in drop) print "S\t" f[i] "\t" a[i] "\t" m[i]
    }' "$T/rspec" "$T/drows" > "$T/rres" || refuse "the re-run narrowing over $REC_WRITES did not run"
  IFS="$(printf '\t')" read -r _k _a _b _c _d < "$T/rres"
  case "$_k" in
    OUT) refuse "--rerun ${_a}: ${_b} is a superseded writer of ${_a} and also wrote ${REC_PREFIX}${_c} at ${_d}, another file in the shard dir; it was not only ${_a}'s writer, so its earlier writes cannot be set aside" ;;
    SAME) refuse "--rerun ${_a}: ${_b} wrote ${REC_PREFIX}${_c} both before the re-run start and at ${_d}, after it; the re-run is a NEW dispatch, and its writer must not be one of the writers it supersedes" ;;
  esac
  RR_LINES="$(awk -F'\t' '$1 == "L" { print $2 }' "$T/rres")"
  RR_SUPERSEDED="$(awk -F'\t' '$1 == "N" { print $2 }' "$T/rres")"
  # A superseded row stays in $T/wrows tagged `S` in a fourth column: the join resolves its writer's
  # dispatch and role like any other (a non-adversary is refused), and only then sets it aside.
  awk -F'\t' 'BEGIN { OFS = "\t" } $1 == "K" { print $2, $3, $4 } $1 == "S" { print $2, $3, $4, "S" }' "$T/rres" | sort -u > "$T/wrows" \
    || refuse "cannot stage the narrowed write rows"
fi
# The meta files the rows name, read in one jq over those that exist; one that does not is absent
# from $T/metas and refused by name in the join.
read_metas() {
  local mp
  set --
  while IFS= read -r mp; do [ -n "$mp" ] && [ -f "$mp" ] && set -- "$@" "$mp"; done < "$T/mpaths"
  [ "$#" -gt 0 ] || return 0
  jq -r '[input_filename, (if type == "object" then (.toolUseId // "" | tostring) else "" end)] | @tsv' "$@"
}
cut -f3 "$T/wrows" | sort -u > "$T/mpaths" || refuse "cannot stage the meta paths"
read_metas > "$T/metas" 2>/dev/null || refuse "a subagent meta file named by $REC_WRITES does not parse as JSON"
# THE JOIN. One awk over the four tables and the shard set; it stops at the first refusal.
awk -F'\t' -v fm="$T/metas" -v fp="$T/probes" -v fs="$T/spawns" -v fw="$T/wrows" \
    -v lw="$REC_WRITES" -v ls="$REC_SPAWNS" -v lp="$REC_PROBES" '
  function no(m) { print "REFUSE\t" m; bad = 1; exit 3 }
  FILENAME == fm { meta[$1] = $2; next }
  FILENAME == fp {
    if (!($1 in probe)) probe[$1] = $2
    if (!(($1, $2) in sp)) { sp[$1, $2] = 1; pall[$1] = pall[$1] "\t" $2 }
    next
  }
  FILENAME == fs { role[$1] = (($1 in role) ? role[$1] "\t" : "") $2; next }
  FILENAME == fw {
    # A fourth column `S` marks a row --rerun superseded: its writer is resolved below like any
    # other, and is then set aside rather than counted as the shard dispatch.
    if ($4 == "S") { if (!(($1, $2) in ss)) { ss[$1, $2] = 1; sup[$1] = sup[$1] " " $2 } }
    else if (!(($1, $2) in sw)) { sw[$1, $2] = 1; wr[$1] = wr[$1] " " $2 }
    if ($3 != "" && !(($2, $3) in sm)) { sm[$2, $3] = 1; am[$2] = am[$2] "\t" $3 }
    next
  }
  {
    key = $1; sf = $2; b = sf; sub(/.*\//, "", b)
    nsup = (b in sup) ? split(substr(sup[b], 2), SA, " ") : 0
    if (!(b in wr) && nsup == 0) { print key "\t"; next }
    n = (b in wr) ? split(substr(wr[b], 2), A, " ") : 0
    for (i = 1; i <= nsup; i++) A[n + i] = SA[i]
    did = ""
    for (i = 1; i <= n + nsup; i++) {
      a = A[i]; id = ""
      if (a in am) {
        m = split(substr(am[a], 2), M, "\t")
        for (j = 1; j <= m; j++) {
          if (!(M[j] in meta)) no(sf " was written by agent " a ", whose meta file " M[j] " is absent; its dispatch id cannot be derived")
          if (meta[M[j]] == "") no(sf " was written by agent " a ", whose meta file " M[j] " carries no toolUseId; its dispatch id cannot be derived")
          if (id != "" && id != meta[M[j]]) no(sf " was written by agent " a ", whose meta files name two dispatch ids (" id ", " meta[M[j]] ")")
          id = meta[M[j]]
        }
        # THE META FILE IS CORROBORATED BY THE PROBE LEDGER. The lead can Write a meta file; it
        # cannot Write the probe ledger (a guarded root), which ai-dlc-subagent-probe.sh fills at
        # SubagentStop from that same meta. No row: the writer has not stopped, so it has not delivered.
        # A CREDITED writer (i <= n) needs the row AND its agreement. A SUPERSEDED writer (i > n, set
        # aside by --rerun) is most often a stalled adversary that never reached SubagentStop, so it is
        # held to agreement only: a row it has must carry the meta id, and with none the meta alone
        # resolves its role, which the role loop below still requires to be adversary.
        if (i <= n || (a in probe)) {
        if (!(a in probe)) no(sf " was written by agent " a ", whose meta file names dispatch " id " but " lp " has no row for that agent; an adversary that has not stopped has not delivered -- if it has stopped, the probe hook recorded nothing for it: re-run the merge once the SubagentStop row for that agent lands, seconds after its seal; if the row stays absent, re-dispatch the shard and merge with --rerun " b "@<the re-dispatch dispatched-at>")
        if (pall[a] != "\t" id) { pl = pall[a]; gsub(/\t/, " ", pl); no(sf " was written by agent " a ", whose meta file names dispatch " id " but " lp " records" pl " for that agent; the meta file was rewritten after the agent stopped") }
        }
      } else if (a in probe) id = probe[a]
      else no(sf " was written by agent " a " in a row that predates transcript_path, and " lp " has no tool_use_id row for that agent; its dispatch id cannot be derived")
      if (!(id in role)) no(sf " was written by agent " a ", dispatch " id ", which has no row in " ls "; a dispatch the guard never recorded is not an adversary")
      r = split(role[id], R, "\t")
      for (j = 1; j <= r; j++) {
        if (i > n && R[j] != "adversary") no(sf " carries rows --rerun would supersede from agent " a ", dispatch " id ", dispatched as role " (R[j] == "" ? "<none>" : R[j]) "; a non-adversary write on a shard is a role violation, not a stale dispatch, and --rerun never sets it aside")
        if (R[j] != "adversary") no(sf " was written by agent " a ", dispatch " id ", dispatched as role " (R[j] == "" ? "<none>" : R[j]) "; only an adversary writes an adversary shard")
      }
      if (i > n) continue
      if (did != "") no(sf " was written by more than one adversary dispatch (" did ", " id "); one shard is one adversary -- after a re-dispatch, merge with --rerun <shard>.md@<the re-dispatch dispatched-at>")
      did = id
    }
    if (did == "") { print key "\t"; next }
    if (did in used) no(sf " derives dispatch " did ", which also wrote shard " used[did] "; one dispatch delivered two shards")
    used[did] = key; print key "\t" did
  }' "$T/metas" "$T/probes" "$T/spawns" "$T/wrows" "$T/shards" > "$T/ids"
JOIN_RC=$?
# A refusal is the LAST line written (the awk exits on it), after any rows already joined.
JOIN_LAST="$(tail -1 "$T/ids")"
case "$JOIN_LAST" in REFUSE*) refuse "${JOIN_LAST#REFUSE	}" ;; esac
[ "$JOIN_RC" -eq 0 ] || refuse "the dispatch-id join over $REC_WRITES did not run (awk exit $JOIN_RC)"
# ONE DISPATCH, ONE SHARD DIR. Every row of every agent that wrote in this dir -- a superseded
# writer included -- must sit under this dir: a row under ANOTHER `shards/<x>-p<M>/` (another pass,
# another artifact, another sprint) means one dispatch delivered for two merges, which the per-shard
# join above cannot see because it reads this dir's prefix only. Rows outside every `-p<M>` shard
# dir are not read, and a `.draft` sibling in this dir is this dir.
if [ -s "$T/wagents" ] && [ -f "$REC_WRITES" ]; then
  XD="$(jq -rn --rawfile ag "$T/wagents" --arg p "$REC_PREFIX" '
      ($ag | split("\n") | map(select(. != "")) | map({key: ., value: 1}) | from_entries) as $A
      | first(inputs | select(type == "object") | select(.kind == "artifact-write")
        | select((.agent_id // "") | type == "string" and $A[.] == 1)
        | (.path // "") as $q | select($q | type == "string")
        | ($q | capture("^(?<d>.*/shards/[^/]+-p[0-9]+/)")? | .d) as $d
        | select($d != null and $d != $p)
        | [.agent_id, $q, (.ts // "" | tostring)] | @tsv)' "$REC_WRITES" 2>/dev/null)" \
    || refuse "the write ledger $REC_WRITES does not parse as JSON lines"
  if [ -n "$XD" ]; then
    IFS="$(printf '\t')" read -r _xa _xp _xt <<< "$XD"
    refuse "agent ${_xa} wrote in ${REC_PREFIX} and also wrote ${_xp} at ${_xt}, under another shard dir; one dispatch delivers one shard of one pass, never shards for two merges"
  fi
fi
# ---- the re-run start binds to a recorded dispatch time (BL-598) ---------------------------
# S is the re-dispatch's dispatched-at, so it must sit within the BACKDATED tolerance of every
# spawn-ledger row of the dispatch the join credited for that shard. The tolerance is read from its
# one declaration, `BACKDATE_TOL_S` in validate-artifact-budget.sh, and only when --rerun is given.
# A shard with no credited dispatch is left to its own per-shard refusal below.
if [ -n "$RERUN" ]; then
  RR_TOL_FILE="$(dirname "$VALIDATOR")/validate-artifact-budget.sh"
  RR_TOL="$(grep -E '^BACKDATE_TOL_S=[0-9]+$' "$RR_TOL_FILE" 2>/dev/null)"
  [ "$(printf '%s\n' "$RR_TOL" | grep -c .)" = 1 ] \
    || refuse "--rerun binds each re-run start to a recorded dispatch time within BACKDATE_TOL_S, which is not declared exactly once as an integer in $RR_TOL_FILE"
  RR_TOL="${RR_TOL#*=}"
  while IFS="$(printf '\t')" read -r _rp _rs; do
    [ -n "$_rp" ] || continue
    _rk="$(awk -F'\t' -v b="$_rp" '{ n = $2; sub(/.*\//, "", n) } n == b { print $1; exit }' "$T/shards")"
    _rd="$(awk -F'\t' -v k="$_rk" '$1 == k { print $2; exit }' "$T/ids")"
    [ -n "$_rd" ] || continue
    _rb="$(jq -rn --arg id "$_rd" --arg s "$_rs" --argjson tol "$RR_TOL" '
        ($s | fromdateiso8601) as $se
        | [inputs | select(type == "object") | select(.tool_use_id == $id) | (.ts // "" | tostring)] as $t
        | if ($t | length) == 0 then "NONE"
          else ([$t[] | (try fromdateiso8601 catch null)] | if any(. == null) then "UNREADABLE\t" + ($t | join(" "))
                else (map(. - $se | if . < 0 then -. else . end) | max) as $d
                     | if $d > $tol then "FAR\t" + ($d | tostring) + "\t" + ($t | join(" ")) else "OK" end end) end' \
        "$REC_SPAWNS" 2>/dev/null)" || refuse "--rerun ${_rp}@${_rs}: the spawn ledger $REC_SPAWNS could not be read for dispatch ${_rd}'s recorded time"
    case "$_rb" in
      OK) ;;
      UNREADABLE*) refuse "--rerun ${_rp}@${_rs}: dispatch ${_rd}'s spawn-ledger ts is not ISO 8601 (${_rb#UNREADABLE	}); the start cannot be bound to it" ;;
      FAR*) _rf="${_rb#FAR	}"
            refuse "--rerun ${_rp}@${_rs}: the start is ${_rf%%	*} s from dispatch ${_rd}'s recorded dispatch time (${_rf#*	}) in $REC_SPAWNS, past BACKDATE_TOL_S=${RR_TOL}; the re-run start is that dispatch's dispatched-at, never a typed time" ;;
      *) refuse "--rerun ${_rp}@${_rs}: the start binding over $REC_SPAWNS did not run" ;;
    esac
  done < "$T/rspec"
fi
# A REAL self id: one of the harness's id shapes, read from the grammar's declaration (above). Only
# such a value is compared.
RE_REAL_TUID="$(read_grammar DISPATCH_ID_ERE)"
[ -n "$RE_REAL_TUID" ] || refuse "DISPATCH_ID_ERE is not declared exactly once as a single-quoted ERE in $VALIDATOR"

# ---- seat-complete (the belt; the join beat's --complete is the braces) --------------------
# If ANY shard's last non-blank line is the marker, every shard's must be. See the header.
: > "$T/sc" || refuse "cannot stage the completion check"
while IFS="$(printf '\t')" read -r sk sf_; do
  # Y carries the marker's declared count (`findings=<n>`, `-` when absent), checked per shard below.
  if ends_in_marker "$sf_"; then
    printf 'Y\t%s\t%s\n' "$sk" "$(marker_n "$sf_")" >> "$T/sc"
  else printf 'N\t%s\t%s\n' "$sk" "$sf_" >> "$T/sc"; fi
done < "$T/shards"
if grep -q '^Y' "$T/sc" && grep -q '^N' "$T/sc"; then
  sc_bad="$(awk -F'\t' '$1 == "N" { print $3; exit }' "$T/sc")"
  refuse "$sc_bad does not end in 'seat-complete: ' while another shard in $SHARD_DIR does; that shard is unfinished (its last non-blank line must be 'seat-complete: <step> <adversary> <shard>')"
fi

# ---- per-shard parse ----------------------------------------------------------------------
# parse_shard, field, digits, RE_ISO and the header checks are defined above the argument parse
# (THE HEADER CHECK), because --check-header uses them and exits before anything below runs.
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

# same_set <file> <label> <ordinals, blank-separated> -> 0 when a column-0 `<label>:` line outside
# a fence in <file> cites exactly that set of ordinals (order, padding and repeats free).
same_set() {
  awk -v lab="$2:" -v want="$3" '
    BEGIN { n = split(want, w, /[ \t]+/); for (i = 1; i <= n; i++) if (w[i] != "") { W[w[i] + 0] = 1; nw++ } }
    f && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ { frr = $0; gsub(/[ \t]/, "", frr); if (substr(frr, 1, 1) == fc && length(frr) >= fln) { f = 0; next } }
    !f && /^[ \t]*(```+[^`]*|~~~+.*)$/ { f = 1; fc = ($0 ~ /^[ \t]*~/) ? "~" : "`"; frr = $0; sub(/^[ \t]*/, "", frr); match(frr, /^(```+|~~~+)/); fln = RLENGTH; next }
    f { next }
    /^## / { inf = ($0 ~ /^## Findings[ \t]*$/); next }
    !inf || index($0, lab) != 1 { next }
    { v = substr($0, length(lab) + 1); m = split(v, a, /[ ,\t]+/); delete G; ng = 0; ok = 1
      for (i = 1; i <= m; i++) if (a[i] ~ /^[0-9]+$/ && !((a[i] + 0) in G)) { G[a[i] + 0] = 1; ng++; if (!((a[i] + 0) in W)) ok = 0 }
      if (ok && ng == nw) { hit = 1; exit } }
    END { exit !hit }' "$1"
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
  # THE HEADER CHECK (defined above the argument parse; --check-header runs the same functions).
  check_header_core "$P" "$sf" "$AXIS" || { collect "$HDR_MSG"; continue; }
  at_key "$at"
  if [ -z "$EARLIEST" ] || [[ "$AT_KEY" < "$EARLIEST_KEY" ]]; then EARLIEST="$at"; EARLIEST_KEY="$AT_KEY"; fi

  # The DERIVED id (the pre-pass above). The self-report is read only to be compared: a real-shaped
  # value that differs refuses; any other value is ignored and never written.
  tid="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/ids")"
  [ -n "$tid" ] || { collect "$sf has no row in $REC_WRITES; a shard written with Bash (or by the lead) has no harness record of its writer, so its dispatch id cannot be derived -- the adversary writes its shard with Write or Edit"; continue; }
  self="$(field "$P" tool_use_id)"
  if [[ $self =~ $RE_REAL_TUID ]] && [ "$self" != "$tid" ]; then
    { collect "$sf self-reports tool_use_id $self, but the harness records derive $tid for the dispatch that wrote it; the shard's id was written by someone else"; continue; }
  fi
  case " $ALL_IDS " in *" $tid "*) { collect "$sf repeats tool_use_id $tid of another shard; one dispatch delivered twice"; continue; } ;; esac
  ALL_IDS="$ALL_IDS $tid"
  ID_LIST="$ID_LIST $key=$tid"

  # skill / mode / lead_role are batch-invariant: every shard ran the same evaluation.
  # Presence and value per shard are the header check's (hdr_role); agreement ACROSS shards is here.
  hdr_role "$P" "$sf" skill "$AXIS" || { collect "$HDR_MSG"; continue; }; val="$HDR_VAL"
  [ -z "$SKILL" ] || [ "$SKILL" = "$val" ] || { collect "$sf declares skill '$val' where another shard declares '$SKILL'"; continue; }
  SKILL="$val"
  hdr_role "$P" "$sf" mode "$AXIS" || { collect "$HDR_MSG"; continue; }; val="$HDR_VAL"
  [ -z "$MODE" ] || [ "$MODE" = "$val" ] || { collect "$sf declares mode '$val' where another shard declares '$MODE'"; continue; }
  MODE="$val"
  hdr_role "$P" "$sf" lead_role "$AXIS" || { collect "$HDR_MSG"; continue; }; val="$HDR_VAL"
  [ -z "$LEAD_ROLE" ] || [ "$LEAD_ROLE" = "$val" ] || { collect "$sf declares lead_role '$val' where another shard declares '$LEAD_ROLE'"; continue; }
  LEAD_ROLE="$val"
  rd="$(field "$P" resolves_divergence)"
  if [ -n "$rd" ]; then
    if [ "$RESOLVES_SET" -eq 1 ] && [ "$rd" != "$RESOLVES" ]; then { collect "$sf resolves_divergence disagrees with another shard"; continue; }; fi
    RESOLVES="$rd"; RESOLVES_SET=1
  fi

  # The wrong-axis guard. It runs BEFORE the one-citation count below, and on purpose: a finding
  # carrying one `sections:` line AND a `stories:` line has exactly one line of this axis, so the
  # count passes it and only this line refuses it.
  wrong="$(awk '$1 == "Y" { print $2 }' "$P")"
  [ "${wrong:-0}" = "0" ] || { collect "$sf:$wrong carries a '$OTHER:' line; a document merge cites sections only, and a finding citing both axes is never keyed on one of them"; continue; }

  # A finding opened with `## ` (the seat-file style) ends the `## Findings` section for this parse, so
  # the shard would merge as zero findings. It is refused wherever it sits, `## Findings` or not.
  hl="$(awk '$1 == "H" { print $2 }' "$P")"
  [ "${hl:-0}" = "0" ] || { collect "$sf:$hl opens a finding with \`## \`; findings are \`### \` headings inside \`## Findings\` (FINDING GRAMMAR in merge-adversarial-shards.sh), each severity word UPPERCASE"; continue; }

  if [ -n "$SUBJECT" ]; then
    # Every shard -- cross included -- notarizes ALL FOUR stems at their disk bytes, and names the
    # subject manifest. Order-free: the list is compared stem by stem.
    sha="$(field "$P" artifact_sha)"
    [ -n "$sha" ] || { collect "$sf declares no artifact_sha; a subject shard notarizes <stem>=<sha> for every subject file"; continue; }
    # A pair is `<stem>=<sha>` or `<stem>@<sha>` (PAIR_SEP: readers accept both; this merge emits
    # the separator --pair-sep prints). PAIR_SEP is unquoted in each pattern, so it is a class.
    nt=0
    for tok in $sha; do
      nt=$((nt + 1))
      st="${tok%%$PAIR_SEP*}"; sv="$(printf '%s' "${tok#*$PAIR_SEP}" | tr 'A-F' 'a-f')"
      case "$tok" in ?*$PAIR_SEP*) ;; *) { collect "$sf artifact_sha token '$tok' is not <stem>=<sha> or <stem>@<sha>"; continue 2; } ;; esac
      want="$(awk -F'\t' -v s="$st" '$1 == s { print $2 }' "$T/stems")"
      [ -n "$want" ] || { collect "$sf artifact_sha names stem '$st', not a subject stem ($(cut -f1 "$T/stems" | tr '\n' ' '))"; continue 2; }
      [ "$sv" = "$want" ] || { collect "$sf notarizes $st=$sv but that file is $want on disk; the shard reviewed other bytes"; continue 2; }
    done
    [ "$nt" -eq 4 ] && [ "$(printf '%s\n' $sha | sed "s/$PAIR_SEP.*//" | sort -u | grep -c .)" -eq 4 ] \
      || { collect "$sf artifact_sha carries $nt token(s); a subject shard notarizes each of the four stems once"; continue; }
    art="$(field "$P" artifact)"
    [ -n "$art" ] || { collect "$sf declares no artifact; a subject shard names the subject manifest"; continue; }
    resolve_artifact "$art"
    [ "$ART_ABS" = "$SUBJ_MF" ] \
      || { collect "$sf names artifact '$art', which resolves to ${ART_ABS:-nothing}, not the subject manifest $SUBJ_MF"; continue; }
    if [ "$key" = "$CROSS_FIRST" ]; then CROSS_ID="$tid"; CROSS_ARTIFACT="$art"; fi
  elif [ -n "$DOCUMENT" ]; then
    # Every shard -- cross included -- reviewed the WHOLE document's bytes, so every shard
    # notarizes the one whole-document sha and names the one document.
    sha="$(field "$P" artifact_sha)"
    [ "$sha" = "$DOC_SHA" ] || { collect "$sf notarizes ${sha:-<none>} but $DOCUMENT is $DOC_SHA on disk; the shard reviewed other bytes"; continue; }
    art="$(field "$P" artifact)"
    [ -n "$art" ] || { collect "$sf declares no artifact; a section shard names the document it reviewed"; continue; }
    resolve_artifact "$art"
    [ "$ART_ABS" = "$DOCUMENT" ] \
      || { collect "$sf names artifact '$art', which resolves to ${ART_ABS:-nothing}, not --document $DOCUMENT; the shard reviewed another file"; continue; }
    if [ "$key" = "$CROSS_FIRST" ]; then CROSS_ID="$tid"; CROSS_ARTIFACT="$art"; fi
    mt="$(date -u -r "$sf" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
    [[ $mt =~ $RE_ISO ]] || { collect "cannot read the modification time of $sf"; continue; }
    WALL_LIST="$WALL_LIST $key=$at/$mt"
  elif [ "$is_x" -eq 1 ]; then
    xa="$(field "$P" artifact)"
    [ -n "$xa" ] || { collect "$sf (cross-story) declares no artifact"; continue; }
    if [ "$key" = "$CROSS_FIRST" ]; then CROSS_ID="$tid"; CROSS_ARTIFACT="$xa"
    else [ "$xa" = "$CROSS_ARTIFACT" ] || { collect "$sf (cross-story) names artifact '$xa' where $CROSS_FIRST names '$CROSS_ARTIFACT'"; continue; }; fi
  else
    sha="$(field "$P" artifact_sha)"
    [[ $sha =~ $RE_SHA ]] || { collect "$sf artifact_sha '${sha:-<none>}' is not one sha256"; continue; }
    sb="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$T/map")"
    disk="$(sha_of "$STORIES_DIR/$sb")" || { collect "story file $STORIES_DIR/$sb is unreadable"; continue; }
    [ "$sha" = "$disk" ] || { collect "$sf notarizes $sha but $sb is $disk on disk; the shard reviewed other bytes"; continue; }
    SHA_LIST="$SHA_LIST ${sb%.md}${PAIR_OUT}$sha"
  fi

  # --- the partition ---
  while read -r tag line s nlines cited; do
    [ "$tag" = "X" ] || continue
    [ "$nlines" = "1" ] || { collect "$sf:$line finding carries $nlines $CITE: lines; each finding carries exactly one"; continue; }
    [[ $cited =~ $RE_CITED ]] || { collect "$sf:$line $CITE: '$cited' is not <ordinal>[, <ordinal>...]"; continue; }
    distinct=""
    for c in $(printf '%s' "$cited" | tr ',' ' '); do
      o="$(norm_ord "$c")"
      [ -n "$o" ] || { collect "$sf:$line cites ordinal $c, outside 1..$K"; continue 2; }
      case " $distinct " in *" $o "*) ;; *) distinct="$distinct $o" ;; esac
    done
    set -- $distinct
    if [ "$is_x" -eq 1 ]; then
      [ $# -ge 2 ] || { collect "$sf:$line (cross-$NOUN shard) cites only$distinct; a cross-$NOUN finding cites two or more ordinals, a single-$NOUN one belongs to that $NOUN shard"; continue; }
      # THE OWNER RULE: the one group --cross-owner names, never any other that also covers it.
      own="$(bash "$XPART" --cross-owner "$K" "$(printf '%s' "${distinct# }" | tr ' ' ',')" 2> "$T/own.err")" \
        || { collect "partition-document.sh --cross-owner $K on$distinct failed: $(head -1 "$T/own.err")"; continue; }
      [ "$G" -eq 1 ] && ownk="cross" || ownk="cross-$own"
      # A cross shard reads the whole document and may cite any ordinal, so a finding outside its
      # owner's shard is accepted -- unless the owner's shard carries the IDENTICAL cited set, the
      # one case the two are the same finding and would be summed twice.
      if [ "$ownk" != "$key" ]; then
        osf="$(awk -F'\t' -v k="$ownk" '$1 == k { print $2; exit }' "$T/shards")"
        ! same_set "$osf" "$CITE" "$distinct" \
          || { collect "$sf:$line ($key) cites$distinct, a finding owned by $ownk (partition-document.sh --cross-owner), whose shard carries the identical set; one finding is reported once, or the summed counts depend on the cover"; continue; }
      fi
    else
      [ $# -eq 1 ] && [ "$1" = "$key" ] \
        || { collect "$sf:$line (shard $key) cites$distinct; a per-ordinal shard reports only findings citing its own ordinal alone"; continue; }
    fi
  done < "$P"
  check_counts "$P" "$sf" || collect "$HDR_MSG"
  # The reservation, after the count check (a severity-less heading whose counts disagree is
  # refused on the count, as before) and before the marker count.
  check_reserved "$P" "$sf" || collect "$HDR_MSG"
  scn="$(awk -F'\t' -v k="$key" '$1 == "Y" && $2 == k { print $3; exit }' "$T/sc")"
  check_marker "$P" "$sf" "$scn" || collect "$HDR_MSG"

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

phase_barrier
if grep -q 'SKILL_INVOCATION_PROVENANCE' "$T/body"; then
  refuse "a shard body mentions SKILL_INVOCATION_PROVENANCE outside its block; the merged file must carry exactly one"
fi

BLOCKING=$((S_MAJOR - S_UNDER))
if [ "$ANY_DIVERGENT" -eq 1 ]; then VERDICT="DIVERGENT_HARD_BLOCK"
elif [ "$S_CRIT" -le "$CRIT_CEIL" ] && [ "$BLOCKING" -le "$MAJOR_CEIL" ]; then VERDICT="EXIT_CONDITION_MET"
else VERDICT="EXIT_CONDITION_NOT_MET"; fi
# THE SUMMED DIVERGENCE (BL-670): arm C of the convergence validator, applied by the program that owns
# the summed prior-scope count, which no shard could see. Convergence axis only. A stamp needs
# S_PRIOR > PREV_CRIT >= 0, so a merge with S_PRIOR 0 reads no earlier pass and stays byte-identical.
# The series grammar (glob, exclusions, order_key) and the count reader (severity_count over
# block_field: the FIRST block's value) are the VALIDATOR's own definitions, extracted as at_key is.
DIV_LINE=""
if [ "$ELICIT" -eq 0 ] && [ "$ANY_DIVERGENT" -eq 0 ] && [ "$S_PRIOR" -gt 0 ]; then
  for _fn in order_key block_field severity_count; do
    n_fn="$(grep -c "^$_fn() {" "$VALIDATOR")" || n_fn=0
    [ "$n_fn" = "1" ] || refuse "found ${n_fn} '$_fn() {' definitions in $VALIDATOR (want exactly 1)"
    eval "$(awk -v h="$_fn() {" 'index($0, h) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$VALIDATOR")"
  done
  _EXCL='      *-resolution-p*|*-repair-p*|*-repair-*) continue ;;'
  n_ex="$(grep -cF -- "$_EXCL" "$VALIDATOR")" || n_ex=0
  [ "$n_ex" = "1" ] || refuse "found ${n_ex} copies of the series exclusion line '${_EXCL#      }' in $VALIDATOR (want exactly 1); restated below, so the validator's exclusions have drifted"
  : > "$T/prev" || refuse "cannot stage the earlier passes"
  for _pf in "$SPRINT_DIR/$ARTIFACT-adversarial-p"*; do
    [ -f "$_pf" ] || continue
    # validate-adversarial-convergence.sh's EXCLUSIONS (its `--series` loop), restated: they are a
    # `case` inside that loop, not a function this script can extract.
    case "$(basename "$_pf")" in *-resolution-p*|*-repair-p*|*-repair-*) continue ;; esac
    _k="$(order_key "$_pf")"
    [ -n "$_k" ] && [ "$((10#$_k))" -lt "$PASS" ] && printf '%s\t%s\n' "$((10#$_k))" "$_pf" >> "$T/prev"
  done
  PREV_CRIT=""; PREV_FILE=""
  while IFS="$(printf '\t')" read -r _k _pf; do
    # A pass with no readable CRITICAL count is skipped, as arm C skips it when PREV_CRIT rolls.
    _c="$(severity_count "$_pf" CRITICAL)"
    [ -n "$_c" ] && { PREV_CRIT="$((10#$_c))"; PREV_FILE="$_pf"; break; }
  done < <(sort -t "$(printf '\t')" -k1,1nr -k2,2 "$T/prev")
  if [ -n "$PREV_CRIT" ] && [ "$S_PRIOR" -gt "$PREV_CRIT" ]; then
    VERDICT="DIVERGENT_HARD_BLOCK"
    DIV_LINE="summed findings_critical_prior_scope $S_PRIOR > $(basename "$PREV_FILE") findings_critical $PREV_CRIT"
  fi
elif [ "$ANY_DIVERGENT" -eq 1 ]; then
  DIV_LINE="shard-declared"
fi

{
  if [ "$ELICIT" -eq 1 ]; then
  printf '# %s -- advanced elicitation (merged from %s shards)\n' "$ARTIFACT" "$(wc -l < "$T/shards" | tr -d ' ')"
  printf '\nMerged by merge-adversarial-shards.sh --elicitation; elicitation is not a convergence pass and carries no verdict.\n'
  else
  printf '# %s -- adversarial pass %s (merged from %s shards)\n' "$ARTIFACT" "$PASS" "$(wc -l < "$T/shards" | tr -d ' ')"
  printf '\nVerdict RECOMPUTED by merge-adversarial-shards.sh from the summed residue; shard verdicts are advisory.\n'
  [ -z "$DIV_LINE" ] || printf 'DIVERGENT_HARD_BLOCK stamped by: %s.\n' "$DIV_LINE"
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
  [ -z "$RR_LINES" ] || printf '%s\n' "$RR_LINES"
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

if [ "$DRY" -eq 1 ]; then
  # --dry-run writes nothing: an existing output that differs still refuses at once, as below.
  if [ -e "$OUT" ] && ! cmp -s "$T/out" "$OUT"; then
    refuse "$OUT already exists and differs from this merge; a pass file is never overwritten"
  fi
  printf 'DRY-RUN: clean\n'; exit 0
fi
if [ -e "$OUT" ]; then
  if cmp -s "$T/out" "$OUT"; then
    printf 'UNCHANGED: %s verdict=%s\n' "$OUT" "$VERDICT"; exit 0
  fi
  refuse "$OUT already exists and differs from this merge; a pass file is never overwritten"
fi
cp "$T/out" "$OUT.merge-tmp.$$" && mv "$OUT.merge-tmp.$$" "$OUT" || refuse "writing $OUT failed"
# The program's own seal row, RECORD-ONLY: the pass file is outside the sealed set. This merge reads an
# existing pass file twice: the `cmp -s` above (which refuses any byte difference), and an EARLIER
# pass's findings_critical for the summed-divergence stamp. LIMIT: a Bash edit of a prior pass's count
# can move that stamp, and nothing here compares it with a seal; Check 24 reads the same bytes
# (content-seal.sh, PROGRAM ROWS). A failed append changes no outcome.
[ -f "$SEAL" ] && { bash "$SEAL" --record "$REC_STATE" program:merge-adversarial-shards "$OUT" \
  || printf 'NOTE: the program seal row for %s was not appended\n' "$OUT" >&2; }
if [ "$ELICIT" -eq 1 ]; then
  printf 'MERGED: %s elicitation shards=%s critical=%s major=%s minor=%s (no verdict)%s\n' \
    "$OUT" "$(wc -l < "$T/shards" | tr -d ' ')" "$S_CRIT" "$S_MAJOR" "$S_MINOR" \
    "$([ -z "$RERUN" ] || printf ' superseded=%s' "$RR_SUPERSEDED")"
  exit 0
fi
printf 'MERGED: %s verdict=%s shards=%s critical=%s major=%s underived=%s blocking=%s ceiling=%s%s\n' \
  "$OUT" "$VERDICT" "$(wc -l < "$T/shards" | tr -d ' ')" "$S_CRIT" "$S_MAJOR" "$S_UNDER" "$BLOCKING" "$MAJOR_CEIL" \
  "$([ -z "$RERUN" ] || printf ' superseded=%s' "$RR_SUPERSEDED")"
exit 0
