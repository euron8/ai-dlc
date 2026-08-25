# s305 unblock runbook — migrate the artifact paths, untrack the transient state, resume gate 3

> **DISCHARGED 2026-08-25 — ACTIONS 1–9 ARE SPENT. DO NOT EXECUTE THEM AGAIN.** They were
> executed against `/Users/n8/git/graph` and every one is verified landed, derived from that
> tree: the consumer runs `0.412.0` with all four stamp fields advanced; `.wait-beats/`,
> `.driver/` and `.context-sensor-state` are tracked 0/0/0 while the durable control
> `.audit-accepted-exceptions` is still tracked at 1; `sync-transient-ignore.sh --check`
> reports `OK: transient-state block current (13 path(s))`; `validate-artifact-paths.sh`
> reports `PASS`; the read-set map covers 168 of 168 fixtures.
>
> **RE-RUNNING THEM IS DESTRUCTIVE, NOT MERELY WASTEFUL.** Action 5 moves 22 tracked files that
> are already at their destination, and action 6 runs a migrator that refuses a dirty tree.
>
> **Action 10 — resume gate 3 on story 2.1 — is the only item still open, and it is ORDINARY
> PIPELINE WORK, not a step of this runbook.** The operator drives it from a fresh session
> through the normal skill; nothing here needs re-reading to do it.

## The procedure, retained as the record of what was run

**Superseded by the banner above.** Kept because the rehearsal figures and the three ordering
constraints below are the evidence for what was done and why in that order.

**You are the GRAPH session. You WRITE `/Users/n8/git/graph`.** That is the inversion a reader
coming from this repo's other plans must notice: `docs/plans/graph-s305-triage.md` forbids
writing the consumer because it is executed by an ai-dlc session. This file is executed by the
consumer's own session, in the consumer's own tree, and writing it is the entire point.
`/Users/n8/git/ai-dlc` is the distribution: **read it, never write it.**

**Ping the operator** on any question, on any decision, and on completion — including an early
stop. Silence and progress are indistinguishable from outside.

**There is an ai-dlc session on standby.** If a step here fails in a way this file does not
predict — a validator you cannot interpret, a pull row you cannot adjudicate, a fixture that
fails after the pull — say so to the operator rather than improvising. That session can read
the distribution and answer.

### What this fixes, and why the sprint is stopped

Sprint 305 is paused mid-gate-3 on story 2.1. Two independent things block the push:

- **24 artifact paths violate the declared path grammar**, so `validate-artifact-paths.sh`
  reports `FAIL` and the pre-push refuses.
- **138 files of transient pipeline state are tracked in git** — `.wait-beats/` (134),
  `.driver/` (3), `.context-sensor-state` (1). These are per-run coordination files that are
  created and destroyed constantly; 5 of the 25 files in the last handoff commit were this
  churn.

A third thing makes the push time out even once it passes: the pre-push takes **161 seconds**
against a **120-second** default tool timeout.

### Derive the state before you act

**Every figure in this file is a hypothesis about a tree that has moved.** Run this first. Each
probe carries a control, and the two at the end must read `FAIL` then `ok` or the block is not
discriminating and its readings mean nothing.

```sh
cd /Users/n8/git/graph
echo "installed version   $(sed -n 's/^version: //p' .claude/.ai-dlc-version)"
echo "branch              $(git rev-parse --abbrev-ref HEAD)"
echo "dirty paths         $(git status --porcelain | wc -l | tr -d ' ')"
echo "tracked .wait-beats $(git ls-files _bmad-output/.wait-beats/ | wc -l | tr -d ' ')"
echo "tracked .driver     $(git ls-files _bmad-output/.driver/ | wc -l | tr -d ' ')"
echo "tracked ctx-sensor  $(git ls-files _bmad-output/.context-sensor-state | wc -l | tr -d ' ')"
echo "party-mode misfiled $(git ls-files _bmad-output/planning-artifacts/party-mode/s305/ | wc -l | tr -d ' ')"
echo "renderer present    $([ -e scripts/ai-dlc/sync-transient-ignore.sh ] && echo yes || echo no)"
echo "readset deriver     $([ -e scripts/ai-dlc/derive-fixture-readsets.sh ] && echo yes || echo no)"
bash scripts/ai-dlc/validate-artifact-paths.sh 2>&1 | grep '^VERDICT'
echo "CONTROL must be ok  $([ -e scripts/ai-dlc/validate-artifact-paths.sh ] && echo ok || echo FAIL)"
```

**Measured 2026-08-25, before any of this ran:** version `0.403.0`, branch
`ai-dlc/feature/portfolio-dashboard-dark-theme`, 3 dirty paths, 134 / 3 / 1 tracked, 22
misfiled, renderer `no`, deriver `no`, `VERDICT: FAIL — 24 blocking, 3 ambiguous`.

**If the counts differ, STOP and ping the operator.** They differ only if somebody has been
working in this tree since, and the step order below depends on them.

### NEXT ACTIONS — numbered, in order. The ORDER is load-bearing.

Three ordering constraints were found by rehearsing this on a clone, and each one stops a step
dead if you take it out of turn. The citations are into the distribution, which you may read:

- **`migrate-artifact-paths.sh` REFUSES a dirty tree** — the refusal is at
  `core/scripts/migrate-artifact-paths.sh:127` in the distribution, and reaches you as
  `scripts/ai-dlc/migrate-artifact-paths.sh`. It performs hundreds of `git mv`s and
  aborts at the first verification failure, so it requires a clean tree to make
  `git checkout -- .` a complete undo. Actions 1–4 are what clean the tree.
- **`git commit` without `-a` does not stage `.gitignore`.** The renderer edits a file on disk;
  nothing stages it for you. Rehearsed: the commit silently omitted it.
- **The renderer and the read-set deriver do not exist in this tree yet.** They arrive with the
  pull in action 1. Do not go looking for them first.

1. **Commit the pipeline's own dirty state.** Three paths are dirty and belong to the paused
   session: `_bmad-output/.context-sensor-state`, `_bmad-output/.driver/turns`,
   `_bmad-output/pipeline-continuation-log.md`. The first two stop being dirty once action 3
   renders the ignore block, but the pull needs a tree it can reason about.

   ```sh
   git add -A _bmad-output/ && git commit -m "chore(s305): checkpoint pipeline state before the unblock"
   ```

2. **Pull the distribution to 0.410.0.** Run the skill, do not copy files by hand:

   ```
   /ai-dlc-update
   ```

   Read the dry-run report, then `/ai-dlc-update apply`. This delivers
   `scripts/ai-dlc/sync-transient-ignore.sh`, `.claude/schemas/pipeline-state-paths.json`,
   `scripts/ai-dlc/derive-fixture-readsets.sh` and the new fixtures. Commit what it places.

   **If the self-update gate reports `SELF-UPDATE-DEFER` and names a `SELF-UPDATE-SAFE-STOP`
   ref, follow it** — pull to that ref first, then run the skill again for the remainder. That
   is the skill's own instruction and it exists because a deferred machinery slice lands after
   the classify that would have used it.

   **This step is the one this runbook did NOT rehearse.** What was verified mechanically is
   that the pull's path mapping sends `core/scripts/*` to `scripts/ai-dlc/*` and `core/*` to
   `.claude/*`, and that the renderer is committed mode `100755` so it lands executable rather
   than inert. The skill's own classification of a 0.403.0 → 0.410.0 range was not run. Adjudicate
   its rows normally; ping the operator on any row you cannot.

3. **Render the ignore block.**

   ```sh
   bash scripts/ai-dlc/sync-transient-ignore.sh
   ```

   Expect `.gitignore: transient-state block written (13 path(s))` followed by a `NOTE` naming
   the three still-tracked paths with their counts. **The NOTE is not a failure — it is the
   whole point of action 4.** An ignore rule does nothing to a file git already tracks.

   Three of the thirteen patterns already exist in this repo's `.gitignore`, hand-added
   earlier: `.audit-watermark`, `pipeline-paused.flag`, `.beat-inflight`. They will appear
   twice. Duplicate ignore lines are harmless to git. Removing the hand-added copies so the
   managed block is the single source is **optional cleanup and not part of this runbook**.

4. **Untrack the 138 transient files.**

   ```sh
   git rm -r --cached _bmad-output/.wait-beats _bmad-output/.driver _bmad-output/.context-sensor-state
   git add .gitignore
   git commit -m "chore(s305): untrack transient pipeline state, render the managed ignore block"
   ```

   Then verify, with a control:

   ```sh
   for p in _bmad-output/.wait-beats/1.since _bmad-output/.driver/turns _bmad-output/.context-sensor-state; do
     printf '%-42s %s\n' "$p" "$(git check-ignore -q "$p" && echo IGNORED || echo NOT-IGNORED)"
   done
   printf 'CONTROL (durable, must be not-ignored): %s\n' \
     "$(git check-ignore -q _bmad-output/pipeline-snapshot.md && echo IGNORED || echo not-ignored)"
   printf 'CONTROL (your own file, must stay tracked): %s\n' \
     "$(git ls-files _bmad-output/.audit-accepted-exceptions | wc -l | tr -d ' ')"
   ```

   **Rehearsed result: 138 removed from the index, all three `IGNORED`, the durable control
   `not-ignored`, and `_bmad-output/.audit-accepted-exceptions` still tracked at 1.** That last
   one is deliberate — the distribution enumerates only the paths it produces, so a file this
   project chose to commit is not touched.

5. **Move the 22 misfiled party-mode artifacts, and COMMIT them.**

   ```sh
   mkdir -p _bmad-output/party-mode/s305/architecture-rounds
   git mv _bmad-output/planning-artifacts/party-mode/s305/architecture-rounds/* \
          _bmad-output/party-mode/s305/architecture-rounds/
   for f in $(git ls-files _bmad-output/planning-artifacts/party-mode/s305/ | grep -v '/architecture-rounds/'); do
     git mv "$f" "_bmad-output/party-mode/s305/$(basename "$f")"
   done
   git commit -m "chore(s305): move party-mode artifacts to the prescribed home"
   ```

   **Do NOT run `migrate-artifact-paths.sh` on these 22.** It derives
   `_bmad-output/planning-artifacts/s305/party-mode/`, which is legal under the grammar but is
   neither the prescribed home nor where sprints 297, 298 and 303 put theirs. The commit is
   required, not tidiness: action 6 refuses a dirty tree.

   Rehearsed: the verdict moves from `FAIL — 24 blocking` to `FAIL — 2 blocking` here.

6. **Migrate the 2 residual paths with the tool.**

   ```sh
   bash scripts/ai-dlc/migrate-artifact-paths.sh          # dry run first, always
   bash scripts/ai-dlc/migrate-artifact-paths.sh --apply
   git commit -am "chore(s305): migrate residual brainstorming paths into the sprint slot"
   ```

   Rehearsed: `2 move(s) planned, 3 refused`, self-check `0`, apply exit `0`. The two are under
   `_bmad-output/brainstorming/brainstorm-s305-ui-lazyload-darktheme-20260821/` and they land at
   `_bmad-output/brainstorming/s305/brainstorm-ui-lazyload-darktheme-20260821/`. The **3
   refused** are ambiguous, non-blocking, and pre-date s305 — leave them.

7. **Confirm the paths gate is green.**

   ```sh
   bash scripts/ai-dlc/validate-artifact-paths.sh 2>&1 | grep '^VERDICT'
   ```

   **Rehearsed result: `VERDICT: PASS — no MIGRATABLE non-conforming path under the scan roots.`**
   Anything else, stop and ping.

8. **Build the fixture read-set map, once.** This is what stops the pre-push running all 155
   fixtures on every push.

   ```sh
   sudo bash scripts/ai-dlc/derive-fixture-readsets.sh --all
   ```

   **It needs root and it will prompt for a password**, which is exactly why the pre-push hook
   cannot do it for you: `fs_usage` is the only tracer that sees a `stat()`-only dependency, and
   an atime-only map under-records precisely the fixtures it would then skip. Without the map
   the hook prints `no read-set map at .ai-dlc-fixture-readsets.tsv -- running all 155`, which is
   the 161-second path measured below.

9. **Push, with an explicit long timeout.**

   The pre-push was measured at **161 seconds** on a clone of this tree, exit 0, 0 FAIL, with no
   read-set map. The default tool timeout is **120 seconds**, and this sprint has already been
   SIGKILLed at that boundary twice — `2026-08-24T13:19Z` and `2026-08-25T01:41:47Z`, both
   `Exit code 143 | Command timed out after 2m 0s`.

   **Run `git push` in the FOREGROUND with a timeout of at least 600000 ms.** Do not background
   it. A backgrounded push reports the wrapper's status, not the gate's, and it lets the session
   proceed past a mutation it has not yet made.

10. **Resume gate 3 on story 2.1**, and only after actions 7 and 9 are both green. Report
    completion to the operator either way — including an early stop.

### Done when

`validate-artifact-paths.sh` reports `PASS`; `git ls-files` returns **0** for all three
transient paths while `_bmad-output/.audit-accepted-exceptions` still returns 1; the push
completes inside its timeout with the gate exiting 0; and gate 3 has resumed. Every one of those
was observed on the rehearsal clone except the push to a real remote and the gate-3 resume.

---

## Start here

**Repos and boundary.** `/Users/n8/git/graph` is yours to WRITE — you are its session.
`/Users/n8/git/ai-dlc` is the distribution: **read it, never write it**, and do not edit
anything under it even to correct an error you find in this file. Report it instead. The pull in action 2 is the sanctioned way distribution content reaches this tree.

**Never run `git checkout --`, `git restore`, `git clean`, or `git reset --hard` in either
repo.** Two of the steps here move files with `git mv` and one deletes index entries with
`git rm --cached`; both are recoverable from a commit and neither is recoverable from a
`git clean`.

## Evidence — what was rehearsed, and what was not

Everything below was measured on a `--no-hardlinks` `file://` clone of this repository at
`386a56d34`, on branch `ai-dlc/feature/portfolio-dashboard-dark-theme`. The clone matched the
source exactly at the start: same HEAD, 134 tracked wait-beats, 22 misfiled party-mode files.

**Rehearsed, in this order, and each verdict read:**

| Step | Measured |
|---|---|
| 22 `git mv` | `FAIL — 24 blocking` → `FAIL — 2 blocking`; 0 files left at the old path |
| migrator dry run | `2 move(s) planned, 3 refused`, self-check `0` |
| migrator `--apply` | exit 0 → `VERDICT: PASS` |
| render ignore block | 13 patterns; NOTE named `.context-sensor-state(1) .driver/(3) .wait-beats/(134)` |
| `git rm -r --cached` | 138 index entries removed |
| ignore verification | all three `IGNORED`; durable control `not-ignored` |
| consumer-file safety | `.audit-accepted-exceptions` still tracked, still NOT ignored |
| durable artifacts | `pipeline-snapshot.md` 1, `party-mode-transcripts` 465, `planning-artifacts` 2488 |
| pre-push | exit 0, **161s**, 0 FAIL, `no read-set map -- running all 155` |

**NOT rehearsed, and available versus unavailable are different admissions:**

- **The `/ai-dlc-update` skill run itself was not executed.** It is agent-orchestrated, so a
  shell rehearsal cannot stand in for it. What WAS verified mechanically: `map_consumer()`
  (`core/skills/ai-dlc-update/reconcile/preclassify.sh:66`) sends `core/scripts/*` →
  `scripts/ai-dlc/*` and `core/*` → `.claude/*`; the renderer is committed `100755` and
  `sync_mode_from_theirs()` (`core/skills/ai-dlc-update/reconcile/apply.sh:196`) derives the
  mode from git's own tree, so it does not land inert. This
  was available to rehearse and was not, for cost reasons — say so if it misbehaves.
- **The push to a real remote** was not performed; the 161s figure is the local gate only.
- **Gate 3's resume** was not exercised.
- **The read-set map was not built**, because `derive-fixture-readsets.sh` is not in this tree
  until action 2 and building it needs root. The 161s therefore represents the WORST case — the
  all-155 path — and the number after action 8 should be lower. It is a ceiling, not a forecast.

## Why the transient paths are classified the way they are

`.claude/schemas/pipeline-state-paths.json` arrives with the pull and classifies all 33
top-level names the AI/DLC machinery writes under `_bmad-output/` — 13 transient, 20 durable.
The 13 transient ones are what action 3 renders. The classification is not a judgement call
made here: invariant `I95` (`scripts/validate-enforcement-map.sh:5356` in the distribution)
re-derives the population from the hooks and scripts themselves and fails the distribution's
push if any path is unclassified. The renderer's `--check` mode, which reports whether the
block is current without writing anything, is at `core/scripts/sync-transient-ignore.sh:35`.

**A blanket `_bmad-output/.*` rule was considered and rejected**, and this project is the
reason. It tracks `_bmad-output/.audit-accepted-exceptions` deliberately, and the distribution
has no knowledge of that file. A glob would have silently untracked it. That is why action 4's
verification includes a control asserting it is still there.
