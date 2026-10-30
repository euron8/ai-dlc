# Fixtures to in-process unit tests: handoff

## RESUME HERE

You were started with one sentence: `READ and FOLLOW docs/plans/fixture-unit-tests-handoff.md`.
Read `## Start here` first, then work through `### Next actions` from action 0. Handed from
session `fixtures-to-unit-tests-pilot` to `ai-dlc-b3` on 2026-10-30. Every branch below is LOCAL
and unpushed; this file itself lives on `exp/fixture-unit-tests` until action 8 merges it.

## Start here

**Read/write boundary.** This plan writes only this repo (`/Users/n8/git/ai-dlc`), and only on
`exp/*` branches until the release push in action 7. A consumer tree is never written: read it,
never write it. A consumer pull is not preapproved (`.claude/rules/operator-rulings.md`).

**The proven pattern** is BL-878's done-criteria (`docs/backlog.md:1846`) and the enforcer is
BL-879 (`docs/backlog.md:1865`). The pilots' in-process cell files are
`core/fixtures/content-seal/unit-arms.sh` and `core/fixtures/remediator-shard-join/unit-parts.sh`.

### Ping the operator

Ping the operator on every question or decision that the rulings below do not already settle,
and when execution completes or stops early. Silence and progress look the same from outside.

## Operator rulings that bind this work

- The goal is wall clock and box load. It was stated once; never ask the operator to restate it.
- No de-scoping. Every cell of every fixture is converted. Where a pure move cannot reach a
  decision, the larger change is made (a module port, a new shipped file, a `BASH_SOURCE` self
  path), with the same equivalence proof. A cell stays end to end only where the mechanism it
  tests cannot exist in a subshell, with the reason written beside it.
- Mutant cells and `--matrix` scoring are converted too: each mutant's copy is sourced once and
  only its owning cell runs against it.
- No timing runs and no process or start counts, in work or in briefs. `invocations.decl` is
  re-measured only because the gate requires it.
- No per-fixture before-and-after wall clock or CPU comparisons after a conversion.
- Go/no-go is the operator's. Write no verdicts.
- Where the standing rulings already settle a choice, act; do not ask.
- All work goes on branches, never `main`. A hand verifies only its own change (`bash -n`, its
  fixture once, its `--matrix`); dependent fixtures are left to the push gate.
- No test may depend on load (BL-868). A load-sensitive timeout is fixed in the test, never
  retried.

## Branches

The integration branch is `exp/fixture-unit-tests`. Its worktree is
`/private/tmp/claude-501/-Users-n8-git-ai-dlc/5489b741-44f9-4138-8e89-fb3e4a5b686f/scratchpad/wt-fut`.
It carries both pilots, the BL-850 measurement history, BL-878 to BL-881, the BL-850 close, and
the executable-bit fix.

| Branch | Base | Fixture or work | State |
|---|---|---|---|
| `exp/fut-content-seal` | d54b3c1be | content-seal (all but gate cells); merge-adversarial-shards.sh seam | done |
| `exp/fut-gate-adjudication` | d3945157b | content-seal gate cells; `gate_adjudication.py` module port | done |
| `exp/fut-adversarial-shard-merge` | d3945157b | adversarial-shard-merge; `merge_main` seam | done |
| `exp/fut-review-shard-merge` | d3945157b | review-shard-merge; seams in merge-review-shards, partition-review-diff, partition-document | done |
| `exp/fut-wait-beat-liveness` | d3945157b | wait-beat-liveness; wfd beat seam; content-seal CS-A2 | see report status below |
| `exp/fut-rsj-mark` | d54b3c1be | rsj EC37, EC40-EC43 marks; `wfd_mark_main` seam | partial; superseded by artifact-derivations |
| `exp/fut-artifact-derivations` | eec2805ec | validate-artifact-derivations seam; artifact-derivations fixture; rsj EC41-43 | see report status below |
| `exp/fut-rsj-reader` | d54b3c1be | `join_main` and `hook_pretool_head` seams only | done (base for -a and -b) |
| `exp/fut-rsj-reader-a` | 305a663b4 | rsj RR SJ LN LP AL NL NW1 EC14/18/19/25/32/36-38 | done |
| `exp/fut-rsj-reader-b` | 305a663b4 | rsj J D A U UF H L AW B CP DX PLAIN PS SP | see report status below |
| `exp/fut-story-evidence-scaffold` | d9c2e3128 | story-evidence-scaffold; three seams; r-pointer gap closed | done |
| `exp/fut-ledger-reverify` | d9c2e3128 | ledger-reverify, -unfalsifiable; `core/fixtures/lib/inproc.sh`; drop-strip gap closed | done |
| `exp/fut-backlog-receipts` | d9c2e3128 | backlog-receipt-binding, push-drain-refusals; two seams | done |
| `exp/fut-postcompact-recovery` | d9c2e3128 | postcompact-rulebook-recovery; matrix block written | done |
| `exp/fut-readset` | d9c2e3128 | readset-stage1-verdict, readset-skip family; load-dependent timeout fix | see report status below |
| `exp/fut-presuite` | a2b7db09b | pre-suite per-step skip with absent-path census (`.githooks/pre-push` only) | done |

Delete without merging: `exp/fut-cs-wfd`, `exp/fut-cs-merge`, `exp/fut-cs-gate`, which are the
content-seal hand's abandoned forks.

### Next actions

0. DESIGNATE THE LEAD
   Run the `ListAgents` roll call first. The session that receives this plan is the lead.
   - The lead never builds: it scopes, merges by content, cuts the release and pings.
   - Owners build through hands (Agent subagents), each on its own branch. Owners make no edits
     themselves: every edit goes to a hand.
   - Every brief opens with the time sentence: "Time matters here: do not spend time that can be avoided, and the earlier a correct result is obtained, the better."
   - The train rules:
     - RELEASES BEFORE MEASUREMENTS.
     - SHORTEST GATE FIRST.
     - NO IDLE SESSIONS.
     - NO TIMING RUNS: no wall clock and no process counts, per the operator.
     - RELEASE TEXT IS PREPARED IN ADVANCE.

1. Read the final report status of `exp/fut-wait-beat-liveness`, `exp/fut-artifact-derivations`,
   `exp/fut-rsj-reader-b` and `exp/fut-readset` from the section below. If a branch's tip
   commit starts `WIP:`, finish it under the rulings above before merging it.
2. Merge, in this order, into `exp/fixture-unit-tests`: content-seal, gate-adjudication,
   adversarial-shard-merge, review-shard-merge, wait-beat-liveness, artifact-derivations (it
   contains rsj-mark), rsj-reader-a, rsj-reader-b, story-evidence-scaffold, ledger-reverify,
   backlog-receipts, postcompact-recovery, readset, presuite. Resolve conflicts by content.
   - The known overlaps are `remediator-shard-join/run.sh` and `lib.sh` (five branches);
     reader-a reports conflicts at old `run.sh` lines 339|340, 421|422 and 590|591.
   - `core/fixtures/content-seal/lib.sh` and `merge-arms.sh` are also shared.
   - `wait-for-deliverable.sh` is seamed on rsj-mark, wait-beat-liveness and
     artifact-derivations; keep one seam.
3. On the merged tree:
   - run `bash -n` on every changed script;
   - run each converted fixture once from the repo root, plus its `--matrix`;
   - run `validate-fixture-hygiene.sh`, `validate-shell-portability.sh`,
     `validate-enforcement-map.sh` and the backlog validators.
4. Re-measure every converted fixture's `invocations.decl` with counted hermetic runs. Also
   re-measure `backlog-real-ledger`'s (BL-872: the backlog edits re-key it).
5. Re-trace the converted fixtures' read sets with
   `bash core/scripts/derive-fixture-readsets.sh --list "<names>" --tracer sandbox` and commit
   the map.
6. Remove each sibling-script process start that the converted fixtures still make. Where the
   subject sources the sibling, use a pure move; otherwise declare an `e2e` with its reason:
   - `merge-review-shards.sh`: partition, `--cross-groups`, `--cross-owner`, `--review-shard`
     and `record-only-diff.sh`;
   - `--mark`'s own `--check-shard` and seal check;
   - LN3m, LPm1 and LPm4 still re-drive the hook inside their scoring.
7. Push the merged branch as one release under the repo's release rules (CLAUDE.md "Releases",
   `AI_DLC_PRESUITE_SKIP=1`, advisor before the push, confirm with `git ls-remote`). Merges are
   preapproved. Then BL-878 batches proceed from BL-879's allowlist.

8. Re-derive this file's `## RESUME HERE` block and `### Next actions` after the merge, so that
   no action describes finished work. Then commit that docs change and merge it.

9. FRESH-RESUME CHECK: from a fresh checkout of origin/main, read this plan as a stranger would.
   Confirm that the next-action list names no work that has already shipped.

10. Hand off: run `ListAgents`. If a local ai-dlc session (never a graph-* one) is found, use SendMessage to send it exactly `READ and FOLLOW docs/plans/fixture-unit-tests-handoff.md`, then stop. If none is found, there is nothing further to do.

## Facts recorded

- Two expected fixtures had pre-existing coverage gaps, now closed: `r-pointer` in
  story-evidence-scaffold and `drop-strip` in ledger-reverify-unfalsifiable.
- `reconcile/lib.sh` exports its memo only at `BASH_SUBSHELL` 0. So one memo drive each in
  backlog-receipt-binding and ledger-reverify stays end to end, and its reason is written beside
  the cell.
- The `content-seal` measurement on a loaded box, origin/main against d3945157b, four alternating
  runs per side: wall 52.2s to 32.8s, CPU 44.6s to 28.7s, with no range overlap. No further
  timings are to be taken.

## Final report status of the last four hands

- **`exp/fut-rsj-reader-b` at bf3385a0e: done.** 222 ok, `--matrix` reproduces all 34 rows.
  It changed one shipped file: `validate-adversarial-convergence.sh` now resolves its siblings from
  `${BASH_SOURCE[0]}` (4 lines).
  - Open: each mutant's owning predicate still rebuilds its world per mutant. Fold this into action 6.
- **`exp/fut-wait-beat-liveness` at 355515ebb: plain run PASS (351 ok), `--matrix` NOT finished.**
  - Seams in `wait-for-deliverable.sh`: `wfd_beat_main` (pure move) and `WD_SELF_PID`
    (`WFD_SELF_PID`, default `$$`, at 8 lease sites). The `--mark` path is untouched.
  - The injected clock is in-process shell functions; no subject seam was needed.
  - Content-seal `--matrix` matches its header. CS-A2 is converted, with the CS-A2s equivalence cell.
  - Owed: re-run `bash core/fixtures/wait-beat-liveness/run.sh --matrix` and check it against the
    header rows. The partial output is in
    `/private/tmp/claude-501/-Users-n8-git-ai-dlc/5489b741-44f9-4138-8e89-fb3e4a5b686f/scratchpad/wbl/mx.out`.
- **`exp/fut-readset` at 12e6c9931 (tip commit is WIP): all four readset fixtures converted.**
  - readset-stage1-verdict `--matrix` passed at 80bdefcdc (221 ok, 32 rows).
  - The BL-868 load-dependent no-progress nets are replaced by process-state checks that load
    cannot move: `aw_group_settled` and `aw_overslept`. This covers readset-skip, slot-world.sh and
    readset-stage1-verdict.
  - Deriver seam: `READSET_SLEEP_CMD` injected wait, plus three `$0` to `${BASH_SOURCE[0]}`.
    `READSET_*` spans are byte-identical.
  - Shards b, c and d pass on 12e6c9931.
  - Owed:
    - the `--matrix` of both fixtures on 12e6c9931, whose partial output is in
      `/private/tmp/claude-501/-Users-n8-git-ai-dlc/5489b741-44f9-4138-8e89-fb3e4a5b686f/scratchpad/rs.pE1wKb/`;
    - shard a on 12e6c9931;
    - re-record readset-skip's matrix header if the rows moved;
    - `validate-fixture-hygiene.sh`;
    - review the remaining 3000-poll bounds against BL-868;
    - decide whether the four shard directories can collapse;
    - the process-identity cells (RT driver, PJ judge, slot-world derivers) stay as processes,
      with their reasons in the report.
- **`exp/fut-artifact-derivations` at 774736d56 (WIP): seams only, no cells converted.**
  - `validate-artifact-derivations.sh` is wrapped as `vad_cli`, `vad_load` (tables plus startup
    self-probes) and `vad_invoke <args>` (per call). It removes 0 lines and adds 94.
  - The `--mark` path in `wait-for-deliverable.sh` calls `vad_invoke` in process when the loaded
    functions came from `$MK_VAL`. It removes 0 lines and adds 23. The CLI lines are
    byte-identical in the `else`.
  - Next steps, in order:
    1. Write `core/fixtures/artifact-derivations/unit.sh` with
       `vad_call <copy> <env> -- <args>`, which runs `( . copy; vad_load; vad_invoke args )`.
    2. Repoint `run`, `l_run`, `mrun`, `nrun`, `o_run`, `prun`, `qrun`, `r_run`, `s_run` and
       `t_ex`, plus the inline sites at `run.sh` lines 357, 434, 483, 509, 846, 855, 1059, 1065,
       1957, 1982, 2028, 2347 and 2348.
    3. Keep one CLI run per outcome: OK, STALE FAIL, UNRUN, walk refusal, startup refusal,
       missing file, usage, `--list` and `--explain-cmd`.
    4. Add an equivalence cell, plus a recording `bash` shim proving the in-process side made no
       `bash` call.
    5. In rsj `lib.sh`, have `wfd_run` source the validator and call `vad_load`, reloading after
       EC43's `mv -f`.
    6. Split the EC41m, EC42m and EC43m scoring to each mutant's own case, and rewrite their five
       matrix rows.
    7. Run each fixture once, each `--matrix` once, and `validate-fixture-hygiene.sh`.
  - The fixture-local names `fails`, `rc` and `out` collide with the validator's, so every
    in-process call stays in a subshell.
  - The scratch helpers are `seam-vad.py`, `msdiff.sh`, `vad.base` and `wfd.base` in
    `/private/tmp/claude-501/-Users-n8-git-ai-dlc/5489b741-44f9-4138-8e89-fb3e4a5b686f/scratchpad/`.
