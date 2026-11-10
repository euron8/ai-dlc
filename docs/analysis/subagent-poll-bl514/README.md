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
