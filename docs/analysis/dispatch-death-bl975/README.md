# BL-975 measuring script: dispatched-agent deaths

`scan.sh` counts, for a window of a Claude Code project directory, every dispatched subagent that died before
delivering, and how long the lead took to hear of it. It is the measuring script BL-975's exit condition names.

```
bash docs/analysis/dispatch-death-bl975/scan.sh --project ~/.claude/projects/-Users-n8-git-graph \
  --from 2026-11-11T22:16:06Z --to 2026-11-16T00:00:00Z
```

It reads the project directory and writes nothing there. Its detection rules are not its own. Both DISPATCH FAILED
arms of `core/scripts/wait-for-deliverable.sh` (`df_scan`) are lifted from that file at run time: arm B's
per-agent awk and arm A's lead-transcript awk. A lift that does not match exactly once refuses. The header of
`scan.sh` states how each arm is applied to a historical corpus, the output columns, and the limits.

The report token (`DISPATCH FAILED agent-`, from `say_dispatch_failed`) and the arm B bound
(`OPEN_REQUEST_SECS`) are lifted from the same file, each with a count-of-one refusal.

Before reading the corpus, the self-probe runs over a synthetic project in both directions:
- arm A names a failed agent that was later resumed, with its open request as of the notice as the death time;
- arm B names an agent whose transcript ends in an open request, and reads the lead's report line;
- an arm-B-only row whose lead ended within the bound reads CANDIDATE;
- an answered request, an out-of-window death, a failure before the window seen at an in-window cut, a
  symlinked transcript and a failed non-agent task stay quiet.

Controls in the same run:
- the agent-file count equals `/usr/bin/find`'s;
- at least one agent file exists;
- an absent token counts 0 files, beside a known-present `api-request` count.

The columns of a `DEATH` or `CANDIDATE` line are listed in the header of `scan.sh`: the last send and the notice
(either may be `-`), the report and the resume with seconds from the death, and the seconds the lead ran on after
the death. A CANDIDATE is an arm-B-only row whose lead session ran on for less than the bound after the last send.
No beat of that session could have named it, and it may be a lead that ended mid-request.
