# Sprint 301 close-out — EXECUTE THIS

## Start here

**You are working in `/Users/n8/git/graph`. Every write below lands there.** This file lives in
the ai-dlc distribution: read `/Users/n8/git/ai-dlc`, and do not write to it.

**This file is self-contained. Follow it top to bottom.** Every number in it was measured
against graph on 2026-08-07 and is stated inline on purpose — a procedure whose figures live in
another document gets followed literally and wrongly. The derivation, and why each step exists,
is in [`s301-close-out-derivation.md`](s301-close-out-derivation.md); you do not need it to act.

**Sprint 301 is being ABANDONED, not completed.** It stalled at `stories-test-strategy.md` §4
after eight adversarial passes and never reached implementation. It is re-run from scratch as
s302. There is **no `abandoned` status value and no documented abandonment procedure** — the
machinery knows only `in_progress` and `done`, and the abandonment lives in `closure_evidence`
prose. The only precedent is s300's close-out, commits `7ecd99dd1` and `ff490ebd0`.

**Three commits. s300's close-out was two, and skipping the third is why `main` is now two
sprints stale.** Do not reorder them.

**`core.hooksPath` is unset in graph**, so git hooks will not fire on any of the three commits.
Nothing here is checked mechanically. The per-file verification in commit 1 is the only thing
standing in for it.

## Next actions

1. Read §*Before you start* and confirm all four preconditions.
2. Run §*Commit 1 — archive*.
3. Run §*Commit 2 — envelope*.
4. Run §*Commit 3 — land on main*.
5. Confirm §*Done when*. **Do not start s302 until every line there passes.**

## Before you start

Confirm all four. If any disagrees, stop and report rather than adapting.

```
branch            ai-dlc/carry-over/s301-eth-rewards-base-indexing
origin/main       3cf225628   (s299 retro, 2026-08-02)
branch vs main    143 commits ahead, 0 behind — a clean fast-forward
pause flag        _bmad-output/pipeline-paused.flag  PRESENT
                  _bmad-output/.beat-inflight        ABSENT (do not create or look for it)
```

## Three traps. Each returns a clean-looking result that is wrong.

1. **A prefix glob undercounts.** `ls _bmad-output/planning-artifacts/s301-*` gives **69**.
   `find _bmad-output -name '*s301*' -type f` gives **99**. **Use the substring form.** Control
   that it is not over-matching: the same two forms over s300 give **0** and **91** — zero for
   the prefix because those files already sit in `archive/s300-*`, which is the state this
   close-out is trying to reach for s301.
2. **`gate-metrics.jsonl` stores `sprint` as an INTEGER.** `grep '"sprint": "301"'` returns
   **0** and looks clean. `grep '"sprint": *301'` returns **75**, out of 736 rows.
3. **Grepping for `RESTART_CYCLE` returns 1, and it is a NEGATION.** The hit is in
   `s301-carry-over-evaluation-resolution-p4.md` and reads *"RESTART_CYCLE was not warranted."*
   Control: `EXIT_CONDITION_MET` appears **22** times in the same corpus. **Write no
   `RESTART_CYCLE` record.**

## Commit 1 — archive

`git mv` only. **Never delete.**

1. Enumerate with `find _bmad-output -name '*s301*' -type f`, **not** a prefix glob. Record
   both counts (69 and 99) in the commit body so the gap is on the record.
2. Create one `archive/s301-<series>` directory per series and `git mv` its artifacts in.
   **Nine directories** — s300 needed six:

   ```
   s301-stories (17)   s301-coe (8)   s301-architecture (7)   s301-prd (6)
   s301-product-brief (5)   s301-epics   s301-carry-over-evaluation
   and the two s301-test-strategy-* files
   ```

3. **Verify per file, not by count.** For each moved file assert
   `source-absent AND dest-readable AND sha256-identical`, and record that phrasing. "99 files
   moved" proves nothing about *which* 99.
4. **Empty the gate log.** Its headings are `## Gate: planning — Sprint 301 (…)`, **NOT**
   `## Gate Log: Sprint N`. A sweep keyed on the latter matches nothing and exits clean. The
   file is 293 lines.
5. **Reduce `gate-metrics.jsonl`** — 75 rows of 736 (integer field, see trap 2). Report
   before/after totals.
6. **Excise the S301 LOCKED block from `product-brief.md`, reversibly. S301's block is an ALIAS
   of S299's, and S299's is the sole surviving in-force block (`product-brief.md:33`). Do not
   touch S299's.** Diff afterwards and confirm the S299 body is byte-unchanged.
7. **Clear `_bmad-output/pipeline-paused.flag`.**

**Two deliberate NON-actions. State both in the commit body as decisions, not omissions:**

- **No Check 33 `NOT-IN-SCOPE` disposition** — writing one asserts a scope decision nobody made.
- **No `RESTART_CYCLE` record** — see trap 3.

## Commit 2 — envelope

1. Run `sprint-status.sh close` **first**, then `roll`. `roll` exits 3 while the prior sprint is
   not `done`.
2. Let the script regenerate the snapshot. **Do not hand-author it.**
3. **Do not cut the s302 branch yet.** That is commit 3's job.
4. Write `closure_evidence` prose stating: s301 is **abandoned, not completed**; where it
   stalled; that it re-runs as s302; and — **restate, do not cite** — s300's reasoning for
   leaving `LR-S299-0..11` undispositioned. s302 is the **third** sprint carrying that same
   unbuilt ask, and a reader will not go hunting for the reasoning in a commit body two sprints
   back.

## Commit 3 — land on main

**This is the step s300 skipped, and skipping it is the whole reason `main` is stale.** s300 cut
its successor from HEAD because `main` was behind; repeating that makes s302 the third sprint
built on a base nothing merges to.

1. **Merge the branch to `main`.** Clean **fast-forward** — `main` is a strict ancestor.
2. What reaches `main` is the **archived** state, not two sprints of live artifacts, because
   commit 1 `git mv`'d them into `archive/s301-*` and `archive/s300-*` is already on the branch.
3. Confirm both directory sets are present on `main` after the merge.

## Done when

Every line passes. **If any fails, do not start s302** — the base is still stale and the problem
has recurred rather than been fixed.

```
git merge-base --is-ancestor <commit-1-sha> origin/main     succeeds
origin/main contains archive/s300-*                          yes
origin/main contains archive/s301-*                          yes
_bmad-output/pipeline-paused.flag                            gone
sprint-status.yaml                                           status: done, s301 housekeeping block present
grep '"sprint": *301' gate-metrics.jsonl                     0   (control: total row count dropped by 75)
find _bmad-output -name '*s301*' -not -path '*/archive/*'    0   (control: the same find WITH archive still returns 99)
```

**Then, and only then: cut s302 from `main`.** After that, the operator runs the two-hop
ai-dlc pull — graph is at `0.274.0` against the distribution's `0.288.0` — before s302 begins.
