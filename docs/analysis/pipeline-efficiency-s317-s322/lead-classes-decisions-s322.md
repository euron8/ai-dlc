# BL-819: the s322 `procedure`, `open` and text-hours classes, decided

Batch 259, release C2. Decided by "A step with no measured value goes" (`.claude/rules/operator-rulings.md`):
a class is kept only on a named failure case it prevents and findings no other element catches. No s323
transcript was read. Population: graph's lead transcripts, read only, top-level `*.jsonl` (173 files in
`~/.claude/projects/-Users-n8-git-graph/` today), window 2026-11-09T00:00:00Z to 2026-11-12T14:41:00Z (s322,
8 stories). In-session time only; handoff gaps are excluded by ruling.

## Source of every class figure

`out/lead_other_split.s322.txt` (committed; first line carries the command; its controls C1 to C6 read ALL
MATCH). Per story, all steps, pipeline bucket, calls / active h / token-equivalent $ at s321's hosted mix
(s322's lead ran local models, API $0). Sprint totals are per-story figures times 8 (`STORIES[322]`, the 8
`story-322-N:` keys recorded in BL-819's batch 256 paragraph). Derivation of the totals:
`python3 -I -c` over the three rows below; recomputed, not copied.

| class | per story | sprint total (x8) |
|---|---|---|
| procedure | 67.6 / 0.118 h / $2.17 | 540.8 calls / 0.944 h / $17.36 |
| open | 289.5 / 0.901 h / $10.97 | 2,316.0 calls / 7.208 h / $87.76 |
| text, hours part | 87.6 / 0.520 h / $3.40 | 700.8 calls / 4.160 h / $27.20 |

Text's dollars were decided in batch 255 (end-of-turn calls, owned by the lead turn count, BL-975). Only its
hours were undecided.

The `open` split below is computed from the line `-- s322 \`open\` calls per story by (sub-class, target
family)` of that file: 69 (sub-class, family) cells summing to 288.9 against the line's stated 289.5 (one-decimal
rounding of each cell, 0.6 apart). Hours and dollars of a group are its call share of the class (a proxy: the
file prints calls per cell, not hours per cell), over 288.9. Group sums reproduce 288.9
(`scripts/lead_open_groups.py`, run on the committed line).

## Decisions

Every decision removes 0 h and $0 as a decision. Hours and dollars at stake are the class's own, shown so a later
sprint reads the same cell.

### procedure: MERGE into step-reread (and compaction-recovery), both KEEP

- Population: 67.6 calls per story, reads whose every target is the lead's own procedure (`.claude/skills/`,
  team roles, agents, hooks, rules, `scripts/ai-dlc/`, settings). 540.8 calls, 0.944 h, $17.36 on the sprint.
- Failure case it prevents: the lead acting on a step, validator or role text it has not read. The one instance
  on record is BL-819 L2: the 4 identical s319 validator re-runs fell in exactly the 2 windows where the lead had
  no `gate-checkpoint.sh done` record to recover from.
- Catch on record for the class itself: none. A first read of a procedure is not a re-read and is not a step, so
  the class is not kept alone; it is the same act as step-reread and compaction-recovery (both KEEP by earlier
  decisions here) with a different path to the file (shell or `ctx_execute` against `Read`).
- Rise: 3.2 to 67.6 calls per story, s319 to s322 (21.1 times, against the lead seat's 3.65). It coincides with
  118 s322 step-file Read results that are errors (4 in s319, 0 in s321) and 36 DENIED step-reread calls
  (`out/lead_class_denied.s322.txt`); that is a coincidence recorded, not a measured cause.
- Change implied: none. The overlap reading was run afterwards: see "Follow-up readings" below.

### open: no class; split by what each part is, none removed

`open` is the residual of extract.py's precedence list, not a step. Its 289.5 calls per story are 69 cells; by
sub-class group (calls per story / sprint calls / sprint h / sprint $, hours and dollars by call share):

| group | per story | sprint | h | $ | decision |
|---|---|---|---|---|---|
| read-search (shell-read, Read, ctx_search, ctx_execute, inline interpreter) | 178.1 | 1,424.8 | 4.44 | 54.10 | MERGE (below) |
| edit, lead-owned records | 24.6 | 196.8 | 0.61 | 7.47 | KEEP |
| edit, a delegate's output | 10.1 | 80.8 | 0.25 | 3.07 | MERGE into repair (KEEP) |
| git | 26.1 | 208.8 | 0.65 | 7.93 | KEEP, on consequence |
| plumbing (harness, script, shell-write, bash-other, mcp-other, operator, sleep, builtin, test-build) | 50.0 | 400.0 | 1.25 | 15.19 | KEEP, on consequence |

- **edit, lead-owned records: KEEP.** Census of every lead Edit and Write in the window (all classes; 494 of
  10,215 lead tool_use blocks): 358 under `_bmad-output`, 39 under `docs` (the retro and `docs/escalations/pending.md`
  among them), 85 to absolute scratch paths, 6 under `.claude`, 3 under `scripts`, 2 `.gitleaks.toml`, 1 `config`.
  Top paths: `gate-log.md` 50, `push-candidate-ledger.md` 28, `carry-over-backlog.md` 24, `retro.md` 18,
  `docs/escalations/pending.md` 16. Failure case: a gate record, carry-over item, retro or escalation that no
  other element writes goes unwritten. Findings no other round catches: none claimed; the class carries the
  record, not a finding.
- **edit, a delegate's output: MERGE into repair.** 10.1 per story are Edits of story, requirements and spine
  files that a delegate wrote and no later prompt names (`story-1-6-test-harness-repair-measure-and-cap.md` 11
  edits, `requirements-party-serial-repair-p1.md` 9). That is a lead hand-repair of a round's output; repair is
  KEEP with the rounds (batch 257 W9-18). If the same repair is cheaper dispatched, the owed round reading
  decides it.
- **git: KEEP, on consequence.** Failure case: lead-owned records (above) uncommitted across a compaction or
  resume. No catch measured; the commands were not read.
- **plumbing: KEEP, on consequence.** Includes sleep, 2.3 per story, tested as a REMOVE candidate for beat
  polling: of 6,397 lead Bash calls in the window 63 run a `sleep <n>` command, 11 of them beside
  `wait-for-deliverable.sh` and 52 not. The first twelve printed are `sleep 1` between a `pkill` or `kill` and a
  `pgrep` check, one `gh pr view` retry loop and one `sleep 45; tail`. They are not hand polls that L1's
  `wait-for-deliverable.sh --status` answers, so there is no residual to delete.
- **read-search: MERGE by target; nothing removed.** 178.1 per story by family: project 53.8, state 43.3,
  mixed 36.6, none 36.6, procedure 3.9, delegate 3.9.
  - procedure 3.9: into the procedure decision above. delegate 3.9: into `merge` (KEEP; failure case in batch
    257 W9-18: no other element reads a subagent's deliverable into the lead's join).
  - state 43.3: the reads of the files the lead then edits. The edit tool refuses an Edit of an unread file, and
    the most-read state files (`pipeline-snapshot.md` 47 target hits, `push-candidate-ledger.md` 40,
    `carry-over-backlog.md` 31, `prd.md` 28, `sprint-status.yaml` 25) are on the edit list above. MERGE into
    edit (KEEP). `spawn-ledger.jsonl` 22 and `pipeline-paused.flag` 24 target hits are read-only state and carry
    no catch; they ride the same MERGE.
  - project 53.8, mixed 36.6, none 36.6 (`ctx_search` with no path 20.1 of it): 127.0 per story, 1,016 calls,
    3.17 h, $38.58 on the sprint. No catch on record and no read shown that a program already answers
    ("answers" is not established: the call text was not read, so not recorded as a merge into a program, as the
    gate-run decision recorded). MERGE into `merge`'s failure case (the lead's verification of a delegate's claim
    against the repository). A REMOVE needs a deletable affordance. The one deletable thing here is the read,
    and the lead's later Edits, merges and gate calls depend on it, which the data cannot separate from the
    reads that repeat what the lead already read.
- The duplicate-read census over read-search was run afterwards: see "Follow-up readings" below.

### text, hours part: MERGE into the subagent-wait figures

- Population: 87.6 end-of-turn text calls per story, 0.520 h per story, 4.160 h on s322 (0.210 h per story in
  s321, 0.272 in s319).
- Failure case: none. A text message with no tool_use is the lead speaking or idling; the time charged to it is
  the interval until the next record. Batch 256's idle-wait split removed the part that carries a
  `turn_duration` record (10.63 h on s322, class `idle-wait`); what remains in text is the interval the harness
  gave no marker for. b255 and b256 recorded that 73% of the time charged to such messages in s319 is a
  `system` record followed by a `queue-operation` record, the lead waiting under 300 s between turns.
- Not re-derived for s322. A direct probe tried here (next-record gap after every s322 lead assistant message
  with text and no tool_use, 3,042 messages) reads 0.41 h in total, because it attributes the interval to the
  record order and not to extract.py's clock; it does not reproduce the class, so it is discarded and the 0.520
  figure stands as the class's own.
- Decision: MERGE into the subagent-wait owners, the adversary rebinding (row 1 of
  `pipeline-efficiency-s317-s322.md`) and BL-716's serial tail, as b255 merged `other`'s hours. 0 h and $0
  removed: the hours are waiting for an agent, and deleting a class label removes none of it.
- The split of text hours under extract.py's clock was run afterwards: see "Follow-up readings" below, which
  replaces this paragraph's decision.

## Window (s322 only; no s323 file is opened)

The window is `S=2026-11-09T00:00:00Z` to `E=2026-11-12T14:41:00Z`, the extraction's own `EXTRACT_WIN_END` and
s321/s322 edge (BL-819, batch 256 paragraph). All four transcript readers (`lead_edit_census.py`,
`lead_sleep_census.py`, `lead_s322_readings.py`; `lead_open_groups.py` reads only the committed
`out/lead_other_split.s322.txt`) select files by metadata and open only these: created at or before E
(`st_birthtime`; a file born later holds only later records) and modified at or after S (an older file holds no
s322 record). A read stops at the first record stamped after E. Control, printed as each script's first line:
files without the window 173, with it 14; of the 14, 1 was appended after E and is read to E only; 16 files are
born after E and are never opened, 143 were last modified before S.
The first versions of the two census readers opened all 173 files and filtered each record by timestamp, so they
did open the 16 later files; that is corrected. Re-derived on the windowed files, the figures do not move: 10,215
tool_use, 494 Edit and Write, 6,397 Bash, 63 sleep (52 and 11). Pre-fix, this was the same count read from 173
files; the 16 born-after-E files contributed 0 records at or before E.

## Follow-up readings (the three owed ones, s322 only)

`python3 -I scripts/lead_s322_readings.py` (`--self-test` exits 0 and seeds a strict duplicate, a covered read, a
near-miss after an Edit and a denied call); output `out/lead_s322_readings.txt`. Executed calls only (tool_use paired
with a non-error tool_result by id). Population is every executed lead call of the shape, not the `open` class
itself, so each figure is a proxy for the class's calls, and hours and dollars are call-share proxies of the class
group. Controls: its read-search count (923 read-kind calls in project, mixed and no-family, plus 185
`ctx_search` calls = 1,108) against the class group's 1,016 calls (127.0 per story x 8); its procedure Reads
(1,047) against the class's 540.8 calls (the class counts only calls whose every target is procedure and that ran
no other program). Same order, not equal; the difference is stated, not closed.

**Thresholds fixed before the run:** a repeat subset is REMOVED when it is at least 10% of its group's calls; below
that the MERGE stands and the subset is a recorded narrowing candidate. For text, at least 50% of the active
hours closed by a notification record confirms the merge into the waiting owners.

### (A) procedure targets, step-reread overlap: MERGE stands

1,071 path touches: FIRST 261 (24.4%), SAME-EPOCH-NEW-RANGE 374 (34.9%), AFTER-COMPACTION 244 (22.8%), SAME-EPOCH
192 (17.9%). The last class holds the touches whose range is covered or whose command repeats; 44 of them are
Reads covered by an earlier Read this epoch with the file unedited (4.1% of touches), the only ones shown to
have returned nothing unread. 4.1% is under 10%: no REMOVE. Proxy hours and dollars of the 44: 0.039 h, $0.71
(of 0.944 h, $17.36). Recorded as a narrowing candidate, as batch 257 did for step-reread's 16 messages. 82% of
touches return text not read this epoch, so the decision stands: procedure reads are the lead acquiring its
instructions, and a repeat after a compaction is normal operation by ruling.

### (B) duplicate reads over read-search: MERGE stands, no REMOVE

Project, mixed and no-family reads: 923 calls, 1 strict duplicate (same key, same epoch, no mutation between), 15
loose, 2 covered Reads, 3 strict-or-covered (0.3%). Proxy of the 3: 0.010 h, $0.13 of the group's 3.17 h, $38.58;
the 15 loose ones, $0.63 and 0.05 h, are not shown to be repeats of anything unchanged because a program may have
changed the file. All read-search together: 3,336 calls, 94 strict-or-covered (2.8%), 5 strict. Duplicate reads
are not where the cost is. 0.3% is under the 10% threshold: the 1,016-call MERGE stands and no REMOVE follows.
The cost is distinct reads, and the data shows no catch that justifies or refutes them; the MERGE into merge's
failure case (the lead verifying a delegate's claim against the repository) is unchanged.

### (C) text hours, extract.py's clock: split, both parts MERGE

Text class, all lead rows in the window (not restricted to the pipeline bucket): 4.372 h active, 1.991 h gap
(over 300 s, excluded). The committed class figure for the pipeline bucket is 4.160 h (0.520 x 8); mine is 1.05
times it, a superset, which is the control. By the record that closes the interval: queue-operation records
(enqueue 2.001 h, remove 0.326 h, dequeue 0.019 h) 2.346 h (53.7%); lead turn time (the next assistant message
1.355 h, `stop_hook_summary` 0.290 h, api-request 0.156 h, `compact_boundary` 0.125 h, other user, attachment and
pr-link 0.080 h) 2.006 h (45.9%); an operator prompt 0.018 h (0.4%); `turn_duration` 0.001 h.
- Waiting for a notification, at least 50% (53.7%): confirmed. MERGE into the subagent-wait owners (adversary
  rebinding, BL-716's serial tail). Scaled to the class's 4.160 h: 2.23 h.
- Lead turn time (45.9%): MERGE into the lead turn count, owned by BL-975 as the text dollars were in batch 255.
  Scaled: 1.91 h. It is not waiting, so it is not a subagent-wait figure.
- Dollars: the class's $27.20 on the sprint (87.6 calls x $3.40 x 8 stories at s321's hosted mix) is decided with
  the turn count; split by hours it would be $14.60 and $12.50, a proxy only. Removed: 0 h, $0.

## Totals

| class | h at stake (sprint) | $ at stake (sprint) | removed by decision | decision |
|---|---|---|---|---|
| procedure | 0.944 | 17.36 | 0 h, $0 | MERGE into step-reread |
| open | 7.208 | 87.76 | 0 h, $0 | split: 2 KEEP groups, 1 MERGE into repair, state reads and read-search MERGE |
| text hours | 4.160 | 27.20 (decided b255) | 0 h, $0 | split: 2.23 h MERGE into subagent wait, 1.91 h MERGE into the lead turn count |

No REMOVE is taken: the three follow-up readings found no repeat subset at the 10% threshold (4.1%, 0.3%) and the
text hours are waiting and lead turn time, not a deletable step. Nothing is owed from these three classes. BL-868:
no test is added and none depends on load.

## Reproduce

1. `bash -c 'cd <repo root> && grep -n "s322 .open. calls per story by" docs/analysis/pipeline-efficiency-s317-s322/out/lead_other_split.s322.txt'`
   (control: `grep -c "^-- s322 reading calls" ...` reads 1).
2. The class rows: `grep -nE "^   (procedure|open|text|all other) " .../lead_other_split.s322.txt` first
   `READINGS, all steps` block.
3. From this directory: `python3 -I scripts/lead_open_groups.py` (69 cells, sum 288.9),
   `python3 -I scripts/lead_edit_census.py` (173 files, 10,215 tool_use, 494 Edit and Write) and
   `python3 -I scripts/lead_sleep_census.py` (6,397 Bash, 63 sleep: 52 and 11). The census readers are stdlib
   Python over the lead transcripts, counting assistant `tool_use` blocks inside the window; the printed totals
   are their controls. The text probe was a scratch reader and is not committed (discarded above).
4. `python3 -I scripts/lead_s322_readings.py` (output `out/lead_s322_readings.txt`) and its `--self-test`.
