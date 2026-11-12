# BL-514 subagent-poll classifier

`classify.sh` buckets the Bash calls in subagent transcripts (`.jsonl`) that the
foreground-budget hook (`core/hooks/ai-dlc-foreground-budget.sh`) would call a poll:
a loop that sleeps, or a `sleep` of 30 s or more. It is the classifier the BL-514 entry in
`docs/backlog.md` refers to. The rule is the hook's own: the four jq defs `cmdpos`,
`loopend`, `loopsleep` and `longsleep` are lifted from the hook at run time, each found
exactly once, and applied to the transcript's `.input.command`. The deny reason is lifted
from the hook's one REASON line, never retyped.

## Usage

    bash docs/analysis/subagent-poll-bl514/classify.sh [--hook PATH] [--budget S]
        [--from ISO] [--to ISO] [--absent TOKEN] [FILE.jsonl | DIR ...]

With no FILE or DIR it runs the self-probe only. `--budget` defaults to 120 seconds.
`--from` and `--to` window on the tool_use timestamp, compared as epoch seconds with any fractional part kept, and BOTH edges are INCLUSIVE (`from <= ts <= to`). Both must be ISO-8601 UTC ending in `Z`. A DIR is searched for `*.jsonl`, symlinked files included. Duplicate tool_use ids (the same transcript listed twice) count once and are reported as `duplicate tool_use ids: N`; a result stamped before its use is counted as `negative-wall: N` and adds no hours.

Each poll lands in one bucket, in this precedence: DENIED (its result carries the lifted
reason), HARNESS-BLOCKED, RAN-bg, RAN-notimeout, RAN-le-budget (declared timeout at or under budget x 1000
ms), RAN-fg-over-budget. Counts are by declared timeout; hours are the measured
tool_use to tool_result wall clock. NONPOLL-SLEEP counts non-polls whose command contains
`sleep`. A poll with no result is reported as unjoined and still bucketed, with 0 hours.

HARNESS-BLOCKED exists because Claude Code has its own sleep block, separate from our hook:
it returns an `is_error` tool_result without running the command, so declared timeout says
nothing about whether the call ran. Membership requires `is_error` true AND result text
(string, or joined array text) whose leading-whitespace-stripped form starts with the literal
`<tool_use_error>Blocked:`. A result starting that way with `is_error` false or absent does NOT
count (the flag is the harness's own marker), and a different `is_error` text does not count.
A result that is both a hook denial and a harness block is DENIED.

## Exit codes

- 0: self-probe passed, controls held, bucket sum equals polls, and every record carrying the reason is a poll's result.
- 1: the bucket sum differs from the polls, or a record carrying the reason is a non-poll's result or is not a tool_result at all (listed on stderr).
- 2: refusal. A def or the reason line was not matched exactly once, a listed file was not readable or jq failed on it, the self-probe mismatched (the corpus is then never read), the known-present control (Bash calls above 0) failed, or the absent-token control (`--absent`, default a token that occurs in no file here) was found in the input.

## What the probe holds

`probe/probe.jsonl` has synthetic records with the real key structure only (assistant
`message.content[]` tool_use with `input`, user `message.content[]` tool_result with
`tool_use_id`), 31 Bash calls of which 25 are polls (the probe-only run prints both): one poll per original bucket, with the DENIED result carrying the
lifted reason; extra polls `cd /x && sleep 200`, a prefixed loop
`S=/x; until test -f $S/d; do sleep 5; done`, and `sleep 45`; one poll with no result;
a non-poll `sleep 5`; and near-misses that must not be polls: `sleep 29`,
`echo sleep 300`, and a `while` loop with no sleep. The classifier asserts exact counts and
seconds per bucket, plus a carrier arm that appends a non-poll result and a stray record
carrying the reason and requires both to be seen. Seven harness-block records cover: a blocked poll, an is_error poll with other error text, a Blocked-text result with is_error false and one with the flag absent, a result that is both denial and block (must be DENIED), a blocked non-poll `sleep 5`, and a blocked poll with leading whitespace.

The self-probe pins both the classifier's bucketing and the lifted rule's shapes against the synthetic records, so a hook whose rule changes makes the classifier refuse until the probe is re-examined. It also runs a windowed pass over `probe/probe-window.jsonl` (fractional timestamps at both edges, inclusive) and a symlink-listing arm. The lifted-rule records are: `sleep 30` (threshold), `for i in 1 2; do sleep 5; done` (loopsleep alone), `( sleep 45 )` (paren), `if x; then :; else sleep 45; fi` (else), `until f; do sleep` newline `done` (sleep at end of line), `until f;do sleep 5;done` and `until  do sleep 5; done` (spacing), `until f; do echo a; done; sleep 5` (must NOT be a poll; pins loopend), `sleep 5; sleep 40` (second match; pins the global flag), a background poll with no timeout (bg before notimeout), a repeated use id and a result-before-use pair.

## Live distribution

Live run at 2026-11-10T12:47:26Z, `classify.sh` blob 096a027bf6fb, `--hook` graph's installed
`.claude/hooks/ai-dlc-foreground-budget.sh` (md5 17e1b07a77ba9e08124a62e32ef4fea7, equal to core's
at 721d4ade5). Population: 352 subagent transcripts of 4 graph lead sessions, records from
2026-11-09T00:20:57Z to 2026-11-10T12:45:50Z. This is s322, which is OPEN, so the run is a partial;
s321 closed at graph 5596361ce, 2026-11-08T20:27:32Z.

| Measure | Count |
|---|---|
| Files opened | 352 of 352 |
| Bash calls | 10995 |
| Polls | 4 |
| Bucket sum | 4 |
| Unjoined polls | 0 |
| Malformed records | 0 |
| Duplicate tool_use ids | 0 |
| Negative-wall polls | 0 |

| Bucket | Polls |
|---|---|
| DENIED | 2 |
| HARNESS-BLOCKED | 2 |
| RAN-bg | 0 |
| RAN-notimeout | 0 |
| RAN-le-budget | 0 |
| RAN-fg-over-budget | 0 |

NONPOLL-SLEEP-BLOCKED 0, NONPOLL-SLEEP-RAN 4; 0 hours of foreground poll wall clock.

Controls, same run. Reason carriers: 2, both poll results, and a plain grep also counts 2.
`<tool_use_error>Blocked:` results by plain grep: 2, equal to HARNESS-BLOCKED. Bash calls 10995 > 0.
The absent token `ZQX-BL514-NEVER-7c1e5a` counts 0, verified absent from the repo and graph's
project directory beforehand.

Pre-fix finding. An earlier live run at 2026-11-10T12:25:03Z, before HARNESS-BLOCKED existed,
had put two harness-blocked polls in the wrong buckets: a `sleep 240` with timeout 300000 and an
`is_error` result 5 ms later in RAN-fg-over-budget, and a second blocked poll with timeout 110000 in
RAN-le-budget. The pre-fix distribution was DENIED 2, RAN-le-budget 1, RAN-fg-over-budget 1; the
fixed run reads DENIED 2, HARNESS-BLOCKED 2. That is why the bucket exists. The BL-514 entry's own history line, "57 refused
by the harness", shows this shape was in the original corpus too.

## Closed-sprint outcome (s321), b255

Readings taken 2026-11-11 over graph's `~/.claude/projects/-Users-n8-git-graph`. Windows: s321
2026-10-30T00:10:03Z..2026-11-08T20:27:32Z (closed at graph 5596361ce); pre-mechanism
2026-10-05T14:00:00Z..2026-10-15T03:10:01Z (the corpus starts 2026-10-05). The classifier rows are
`classify.sh` over the whole project directory (6176 files, 6023 subagent plus 153 lead-session files, so those rows are lead plus subagent); the pair and background rows are a
one-off join over the 6023 `subagents/*.jsonl` files only, with a 120 s window after the denied
call's result and the poll predicate lifted from the installed hook's own jq defs. The whole-pipeline
rows are `roll.py --seats` over `extract.py` output (EXTRACT_WIN_END=2026-11-11T10:30:00Z), PER-STORY MEANS (s317+s318 pooled
over 34 stories, s321 over 25), whose
plain `roll.txt` is cmp-equal to `pipeline-efficiency-s317-s322/out/roll.txt`.
Rows marked "s317 truncated" pool an s317 that this extract reads short, because graph's
transcripts no longer reach back through s317: by `seat_sum` the fresh s317 reads 3.85 h and $75.6
per story against 5.37 h and $112.2 in the committed b244 pin, while s318 agrees. BL-514 item 6
in `docs/backlog.md` carries the reconciliation.

| Quantity | Before | After s321 |
|---|---|---|
| Foreground poll wall clock, all foreground buckets, lead plus subagent (classify.sh) | 15.10 h (pre-mechanism) | 0.95 h |
| Foreground poll wall clock, subagent files only (one-off scratch reader) | 14.03 h, of which 12.49 h in polls over 300 s | 0.47 h |
| Polls that ran foreground over the 120 s budget (classify.sh) | 121 calls, 13.73 h | 0 calls |
| Subagent Bash `sleep` wall clock (bash_by_sprint.txt) | 3.01 h s317, 3.88 h s318 | 0.28 h |
| Denied polls followed by a backgrounded Bash or Monitor call within 120 s | control: 20 of 117 foreground-over-budget polls | 16 of 23 DENIED |
| Denied polls followed by a poll-shaped backgrounded Bash or Monitor call within 120 s | control: 11 of 117 | 14 of 23 |
| Subagent run_in_background Bash calls, then Monitor calls (6023 subagent files) | 230 and 134 of 60514 Bash calls | 264 and 66 of 45166 Bash calls |
| Whole pipeline bucket, per story: subagent ACTIVE time, which excludes every wait over 300 s (extract.py:333), so it is not the wait | 7.09 h, $77.4 (s317 truncated, BL-514 item 6) | 6.94 h, $75.1 |
| Whole pipeline bucket, per story: lead active time | 2.38 h, $19.9 (s317 truncated, BL-514 item 6) | 2.28 h, $20.4 |
| Whole pipeline bucket, per story: gap-inclusive, both seats | 4.58 h (s317 truncated, BL-514 item 6) | 4.82 h |
| Subagent gap (waits over 300 s) per story, all buckets, unattributed scratch reading of segs.jsonl | 1.42 h pooled s317+s318, s317 truncated, BL-514 item 6 (s319 2.16, s320 1.63, s322 2.53) | 0.94 h |


## gap.py: subagent wait per story

`gap.py` reads `segs.jsonl` written by `docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py` and sums the
`kind == "sub"` rows per sprint; lead rows are excluded. There is no second attribution parser: `sprint` is extract.py's
own `sprint_of` on the segment's first record. Per story means divide by `STORIES` read from `roll.py` at run time.
`active` is time between consecutive records of 300 s or less, `gap` is time between consecutive records over 300 s,
`wait` is their sum, and the three print separately. The gap figure covers ALL subagent waits over 300 s (foreground polls,
model turns, anything that left a hole of more than 300 s), not only polls.

    EXTRACT_WIN_END=2026-11-11T10:30:00Z python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py OUT
    python3 docs/analysis/subagent-poll-bl514/gap.py OUT
    python3 docs/analysis/subagent-poll-bl514/gap.py --probe

The self-probe runs before every corpus read and exits 2 if either arm fails. Synthetic segs: a sub gap is summed, a
lead seg and a seg with no sprint are not. Synthetic transcripts through extract.py with `EXTRACT_ROOT` set to a
`mktemp` tree: a subagent record pair 300 s apart lands in `active` and one 301 s apart in `gap`, and a lead transcript
with a 400 s hole appears as `kind` lead and is not summed.

Reading at ai-dlc e3d2dfc35, fresh extract with `EXTRACT_WIN_END=2026-11-11T10:30:00Z` then `analyze.py` then `roll.py`;
that `roll.txt` is `cmp`-equal to `docs/analysis/pipeline-efficiency-s317-s322/out/roll.txt`. Hours per story:

| Population | Stories | Active | Gap | Wait |
|---|---|---|---|---|
| s317+s318 pooled | 34 | 7.09 | 1.42 | 8.50 |
| s317 | 21 | 5.31 | 1.18 | 6.49 |
| s318 | 13 | 9.96 | 1.79 | 11.75 |
| s319 | 20 | 8.73 | 2.16 | 10.89 |
| s320 | 13 | 8.95 | 1.63 | 10.58 |
| s321 | 25 | 6.94 | 0.94 | 7.89 |
| s322 | 8 | 9.79 | 2.53 | 12.32 |

The gap column reproduces BL-514's item 5 scratch reading on all seven rows. s317 is truncated in this extract: its
earliest subagent record is 2026-10-07T09:45Z, so its figure is a floor on a partly missing sprint, and
`pipeline-efficiency-s317-s320/b244-snapshot` holds no `segs.jsonl`, so s318 alone is the whole before-sprint. s322 is
open (8 planned stories, window ends 2026-11-11T10:30Z).

## lift.sh: one copy of the rule lift and the reader

`lift.sh` is sourced by `classify.sh` and `join.sh`; neither owns a copy. `bl514_lift HOOK WORK` lifts the hook's four jq
defs (`cmdpos`, `loopend`, `loopsleep`, `longsleep`, each exactly once, verbatim) and the deny reason, and refuses on a
renamed, edited or duplicated def. `bl514_extract LIST EVENTS` runs the extract program over every listed file with one
`jq` per `BL514_BATCH` files (default 500, serial, list order); rows carry `input_filename`. A file that cannot be read, or
that makes a batch fail, makes the batch fall back to one `jq` per file, which names the file and exits 2; "N of N files
opened" still has to hold. `classify.sh` also gained `--denied-ids PATH` (one `tool_use_id<TAB>file` per DENIED poll,
sorted) and `--events-out PATH` (the extracted row stream); neither changes anything printed. Its self-probe EXPECT is unchanged.

Batched against per-file, measured on a 201-file sample (154 with `api-request-blob` records, the s321 DENIED files, the
earliest-modified files, one synthetic file with its Bash tool_use records dropped; the corpus holds no real no-Bash
subagent file): `BL514_BATCH=1` and `BL514_BATCH=500` row streams are byte-equal (18715 rows) and so is the printed output.
A malformed file inside a batch exits 2 and is named; an unreadable one exits 2 and is named. Over the s321 window,
all 71 `subagents/` dirs (6158 files), `classify.sh` bucket output is byte-identical (`cmp`) between the base blob
and this revision, and the DENIED ids file is identical between the per-file and batched runs. Wall times, measured: 1080 s per-file
base blob, 840 s per-file this revision, 802 s batched. The cost is the 475k parsed rows and the summary over them,
not `jq` starts, so batching the reader does not buy wall clock; do not batch it again for that. The 71-dir `classify.sh` run exits 1 on
both blobs: one non-poll result carries the deny reason (`toolu_01PgYhR6XZYgqRxjBtXUr29K`), an INTEGRITY finding present before this change.

## join.sh: (c) denied-to-backgrounded join

    bash docs/analysis/subagent-poll-bl514/join.sh [--hook PATH] [--budget S] [--span S] [--classify PATH] \
        --window LABEL=FROM..TO [--window ...] [--absent TOKEN] [--detail PATH] DIR|FILE.jsonl ...

For each DENIED poll (the lifted deny reason in its result), a follow-up is a Bash with `run_in_background: true`, or any
Monitor, in the SAME transcript file, whose timestamp is at or after the denied result's timestamp and at most `--span`
(120) seconds after it. It is poll-shaped when it is a Monitor, or a Bash whose command the hook's own `loopsleep` or
`longsleep` accepts. The control is the same join over the `RAN-fg-over-budget` polls, which is what the pre-mechanism
window holds. The self-probe runs on synthetic jsonl first, both directions: +60 s joins, +120 s joins, +121 s does not, a different
agent's call does not, a call before the result does not, a plain bg `ls` is any-bg but not poll-shaped.
Same-invocation control: `join.sh` runs `classify.sh` over the same targets and window and refuses (exit 2) unless the two
DENIED sets are equal by tool_use id and file. The classify control shares the rule lift and the deny reason with the join,
so it controls for the bucketing of the polls, not for the parse; the parse of the transcripts is separate code in each script.
Absent token `ZQX-BL514-JOIN-NEVER-4e9a27` (assembled from two literals in `join.sh`): 0 files in the repo and 0 in graph's
project dir, with `FOREGROUND Bash call is a poll` as the positive control (4 and 62 files), in one invocation.

Reading 2026-11-12, graph `~/.claude/projects/-Users-n8-git-graph`, 71 per-session `subagents/` dirs, 6158 `*.jsonl` files
(0ec8b044 has 126; 135 are newer than 2026-11-11 10:30 and start after both windows), earliest record 2026-10-07T09:45:44Z.
Hook: graph's installed `ai-dlc-foreground-budget.sh`. Wall 1990 s for the whole run.

| Window | DENIED / control population | any bg Bash or Monitor within 120 s | poll-shaped |
|---|---|---|---|
| s321 2026-10-30T00:10:03Z..2026-11-08T20:27:32Z | 23 DENIED (ids equal to `classify.sh`'s 23) | 16 | 14 |
| pre 2026-10-05T14:00:00Z..2026-10-15T03:10:01Z | 117 RAN-fg-over-budget (`classify.sh` 117; DENIED 0 on both) | 20 | 11 |

These reproduce the b255 readings exactly (23 -> 16 / 14, 117 -> 20 / 11); the corpus did not move for these windows. No tuning was applied. `join.sh` exits 1 here only because its
`classify.sh` control exits 1 on the pre-existing INTEGRITY finding above.

## join.sh: (b) idling

Derivable from the records. Launch: an assistant `tool_use` Bash with `run_in_background: true`; its `tool_result` reads
`Command running in background with ID: <id>` (a Monitor's reads `Monitor started (task <id>`). Completion: an
`attachment` record of type `queued_command` whose prompt holds `<task-notification>` with `<status>` and either
`<tool-use-id>` (Bash) or `<task-id>` only (Monitor). Population: each `RAN-bg` poll, plus each backgrounded Bash or Monitor
the join found after a DENIED poll (`post_denied`) or after a control poll (`post_control`); `all_bg` is their union by (file, id).
Per launch, comparing timestamps and never line order (records for one launch can sit out of order in the file):

- idle: a completion exists and, between launch and completion, the agent issued no `tool_use` other than one whose command or
  path names the launch's own task id (a `Read` of its output file, a Monitor on it, a `TaskStop` of it).
- not-idle: any other `tool_use` (Edit, Write, Bash, ...) falls in that interval.
- chain: a Monitor naming the launch's id was started, so the end is the later of the launcher's and the Monitor's completion;
  reported separately (idle / not-idle inside it).
- unjoined: no task id in the launch result, or no completion notification recorded (named per reason). Not counted idle or not-idle.

`idle-wide` additionally ignores other Monitor and poll-shaped Bash calls. Idle means no OTHER tool call; the records carry no
model-thinking spans, so an agent deliberating between tool calls reads as idle. Unjoined launches have no completion notification in the records, and why is neither recorded nor tested. join.sh has a second same-invocation check, classify.sh's DENIED bucket count against the join's (join.sh:401-405); it is skipped whenever classify.sh exits non-zero, and on this corpus classify.sh always exits 1 on its pre-existing INTEGRITY line, so the id-set `cmp` (join.sh:386) is the control that actually ran, and it reads EQUAL. The idle rule does not count TaskOutput or BashOutput calls on the launch's own task as waiting: their `ref` is empty (join.sh:97-103), so they fall in `$other` and would read not-idle; the corpus files named in `join.detail` carry 0 of either. "All backgrounded" (63 in s321, 64 pre) is the union by (file, id) of the RAN-bg polls and the post-DENIED (or post-control) launches (`launchset($RB + $D.launches + $C.launches)`, `unique_by([.file, .id])`). "After DENIED (25 launches: 23 Bash, 2 Monitor)" and the join's "16 of 23 DENIED" count different things off the same rule: `follow($row)` selects, per DENIED row, every backgrounded Bash or Monitor call in the same file with `.id != $row.id` and `result ts <= call ts <= result ts + $span` (join.sh:157-158); `any_bg` counts the DENIED ROWS with at least one such candidate (16), while the 25 is the candidate LAUNCHES, flattened by `$J | map(select(...)) ... .cand[]` (join.sh:166) and deduplicated by (file, id) in `launchset` (join.sh:202). One row can carry several candidates, so 16 rows yield 25 launches.

| Window | Population | launches | idle | not-idle | unjoined | chain |
|---|---|---|---|---|---|---|
| s321 | RAN-bg polls | 54 | 10 (1720 s) | 29 (5093 s) | 14 (13 no notification, 1 chain Monitor with none) | 1 (not-idle) |
| s321 | after DENIED | 25 (23 Bash, 2 Monitor) | 3 (100 s) | 18 (2044 s) | 4 | 0 |
| s321 | all backgrounded | 63 | 12 | 32 | 18 | 1 |
| pre | RAN-bg polls | 42 | 2 (110 s) | 32 (13850 s) | 8 | 0 |
| pre | after control (RAN-fg-over-budget) | 27 (17 Bash, 10 Monitor) | 4 (294 s) | 16 (11383 s) | 7 | 0 |
| pre | all backgrounded | 64 | 5 | 46 | 13 | 0 |

Probe arms for the buckets (synthetic): idle with nothing between; not-idle with an Edit between; idle with only a Read of its own output; unjoined with no notification;
chain with an Edit inside; idle with the notification earlier in the file than the launch result.
