# graph: pull 0.300.0, then migrate every artifact path — DISCHARGED, DO NOT EXECUTE

**BOTH STEPS RAN.** The pull landed graph at `0.300.0` and the migration applied 2667 moves
(48 refused, verified per file). The story corpus that this file left DEFERRED was migrated
later, in the 0.306.0 → 0.314.0 pull, as 951 further moves. **The header below says step 1 is
done and to start at step 2; that was true when written and is now false.**

**STEP 1 (the pull) IS DONE as of 2026-08-08. Merge the one unpushed commit, then start at
STEP 2.** See §*STATE AS OF 2026-08-08* and §*Two things already settled*.

## Start here

**You are working in `/Users/n8/git/graph`. Every write below lands there.** This file lives in
the ai-dlc distribution: read `/Users/n8/git/ai-dlc`, and **do not write to it**.

**This file is self-contained. Follow it top to bottom.** Every number in it was measured on
2026-08-07 and is stated inline on purpose — a procedure whose figures live in another document
gets followed literally and wrongly. Where a number is a PRE-PULL baseline rather than a
prediction, it says so.

**TWO STEPS, IN THIS ORDER, AND THE ORDER IS NOT A PREFERENCE.** The migration script
(`scripts/ai-dlc/migrate-artifact-paths.sh`) and the grammar it reads
(`.claude/skills/ai-dlc/artifact-path-grammar.md`) BOTH ship in the pull. The script refuses to
run without the grammar. So the pull lands first, or step 2 cannot start.

**WHAT THIS IS FOR.** ai-dlc now declares ONE artifact path convention: the directory is the only
sprint slot (`<area>/s<N>/<name>.md`), and no basename may carry a sprint token. Core's own
prescriptions and readers moved in 0.299.0. graph's ~2700 existing files have not, and until they
do, graph's gate-time readers compose paths that do not exist.

## STATE AS OF 2026-08-08 — STEP 1 IS DONE. START AT STEP 2.

**Everything below §*Step 1* is kept for the record; do not re-run it.** Observed directly in
graph:

```
e1de29bc9  chore(ai-dlc-update): self-update 0.297.0 -> 0.298.0   (#880)  merged
471de36dc  chore(ai-dlc-update): reconcile distribution 0.292.0 -> 0.297.0 (#879)  merged
b074ba4e1  chore(ai-dlc-update): reconcile distribution 0.297.0 -> 0.300.0  COMMITTED, NOT PUSHED
           on branch ai-dlc-update/0.300.0-reconcile-20260808T003916Z
.claude/.ai-dlc-version -> 0.300.0 / 2bc7aa4
```

**IT TOOK THREE HOPS, NOT TWO.** This file predicted two and was already once wrong in the other
direction ("one hop, not two"). Twice now the hop count has been reasoned from the distribution
side and been wrong. **Do not predict it again — run the dry run and read what the gate says.**

**YOUR NEXT ACTION IS TO MERGE `b074ba4e1`**, then go to §*Step 2*. Until it is on `main`,
`migrate-artifact-paths.sh` and the grammar are not on your default branch.

**Then clear the tree.** Four files are modified, all session runtime state —
`_bmad-output/.context-sensor-state`, `_bmad-output/.driver/turns`,
`_bmad-output/pipeline-continuation-log.md`, `_bmad-output/subagent-context.jsonl`. Commit them as
you have before (`chore: context-sensor state`) or stash. `--apply` refuses on a dirty tree.

**ai-dlc HAS MOVED TO 0.303.0 while you were pulling** — 0.301.0, 0.302.0 and 0.303.0 all landed
after you started. **Do NOT chase them now.** Finish the migration on 0.300.0 first; a further hop
is owed afterwards and is out of scope for this file.

**graph is QUIESCENT — s301 is closed and s302 has not started. That is why this is safe now and
will not be later.** Between step 1 and step 2 graph's gate-time readers expect the new layout
while the tree is still old. They fail LOUDLY by construction rather than finding nothing
silently, and nothing exercises them while no sprint is running. **Do not start s302 in that
gap.** If s302 starts first it writes ~100 more non-conforming files and the migration is paid
twice.

**One observed wrinkle, and it is not a blocker.** The continuation log shows `sprint-id resolved:
'302'` while `_bmad-output/planning-artifacts/s302/` does not exist, so the hooks report the Rule 8
divergence/stall block as NOT ARMED. That is 0.299.0's scoping behaving correctly — it refuses to
glob across every sprint by mtime and says so — and with no sprint running there is nothing for it
to adjudicate. It does mean **the declared sprint and the tree disagree**: if 302 is intended, its
directory simply does not exist yet; if the envelope should still read 301, fix the envelope. Do
not create `s302/` to silence it — that starts s302 inside the gap this file forbids.

**`core.hooksPath` is UNSET in graph** (verified 2026-08-07), so git hooks do not fire on any
commit you make here. Nothing below is checked mechanically at commit time. The migration's own
per-file verification is what stands in for it.

**graph's working tree had 6 uncommitted changes when this was written; at 2026-08-08 it has 4,
all session runtime state.** `--apply` REFUSES to run on a dirty tree, deliberately: a clean tree
is what makes `git checkout -- .` a complete undo of a partial run. Commit or stash them before
step 2.


**PING THE OPERATOR — on any question, on any decision, and when this plan completes.** The
operator cannot see this session. From outside, "still working" and "stopped, waiting on you"
look identical, so silence is not a neutral state: it is a stall the operator can only find by
polling. Say something when you need a decision, when you hit a premise that does not hold, and
when you are done — including when "done" means you stopped early. **This instruction is carried
forward into every plan in this repo and is enforced by `scripts/validate-plan-shape.sh`; a new
plan that omits it fails the build.**

## Next actions

~~1. Read §*Before you start* and confirm all three preconditions.~~ **DONE.**
~~2. Run §*Step 1 — take the pull*.~~ **DONE — three hops. See §*STATE AS OF 2026-08-08*.**

1. **Merge `b074ba4e1`** (branch `ai-dlc-update/0.300.0-reconcile-20260808T003916Z`) to graph's
   `main`. It is committed and unpushed.
2. **Clear the four runtime-state files** so the tree is clean.
3. Run §*Step 2 — dry run* and read the refusals against §*Dispositioning the refusals*.
   **Re-measure — do not trust 2667/48/1001.** Those are this file's PRE-PULL baseline and the
   tree has moved three times since.
4. Run §*Step 3 — apply and commit*.
5. Confirm the second dry run exits **3**. A `0` means work was left behind.
6. Report to the operator per §*Done when*, including the four numbers.

**Nothing here is blocked.** All of it is yours end to end.

## Two things already settled — do NOT re-derive them

**1. The ci-gates enforcement surface is COMPLETE and GREEN. There is no work here.** A session
stopped on this and reached a wrong conclusion; the analysis is finished and the answer is that
nothing needs doing.

- `scripts/ai-dlc-ci-alias-table.txt` is **already committed on `origin/main`** with all six rows.
  It was written in #769 and moved in #845, in July. Nothing needs authoring.
- Invoked as the pre-push chain invokes it, the validator passes:

```
bare                                              VACUOUS: 6 declared, 0 adjudicable   exit 78
as check_ci_gates() invokes it (both env vars)    6 gates declared, 0 dormant          exit 0
```

  `VACUOUS` fires only when the surface AND the alias table are both absent. Bare, it falls back to
  `.github/workflows`, which graph does not have. **A bare run is not the run the chain makes.**

- **`pytest-integration-recorded` is NOT dormant.** Both alias legs resolve:
  `/Users/n8/git/graph/scripts/ci-local.sh:1555` registers `run_check "server-subgraph-contract-pytest"`, and the
  anchor `-m "integration"` occurs exactly once at `/Users/n8/git/graph/scripts/ci-local.sh:732`, inside
  `check_server_subgraph_contract_pytest()`, which runs pytest against
  `tests/test_subgraph_fixture_recorded.py`. **Do not retire it.**
- Why the earlier grep said otherwise, kept because the predicate looks convincing: it searched for
  the gate NAME, and the enforcer is registered under a DIFFERENT name — which is the one thing the
  alias table exists to bridge. Applied to all six as a control, `auto-merge-prohibition` scores 1,
  `deployability-preflight` 2, `validate-story-status-consistency` 2, and **three score zero** —
  `pytest-integration-recorded`, `validate-server-fixture-manifest` and
  `validate-subgraph-schema-pin`. The last two are agreed to be correctly aliased. A predicate that
  scores zero on correct rows cannot be used to condemn one.

  What IS true: the override `overrides/steps__retro__ci-gates-enforcement-surface.md` has a stale
  body. It says *"Stock now reports `8 gates declared, 2 dormant`"* (now **6 declared, 0 dormant** —
  the angle-bracket skip landed upstream, so that push-candidate is ABSORBED and should be closed)
  and *"The script exits 1 on this repository today, red-by-inheritance"* (now **exit 0**). Both
  errors point the same way: the override is closer to retirable than its own text claims. That is
  the ATOMIC retire's real first step — **after** the migration, not now.

**2. If you re-run the layer checks, pass the PULL's base to `layer-drift.sh`, not `theirs`.**
SKILL.md step 7 at 0.300.0 tells you to pass `theirs` to both drift scripts. That is right for
`unregistered-drift.sh` and **wrong for `layer-drift.sh`**: both its `ADJUDICATED` clauses are
computed over `base..theirs`, so `base == theirs` means no drift, no adjudication demanded, and
`hard-blockers.sh` prints a clean sheet on a tree where every verdict is owed. Fixed upstream in
0.303.0, which you do not have yet — so this one is on you to remember until the next hop.

## Before you start

1. **graph is on `main`, up to date with `origin/main`, and the tree is CLEAN.**
   `git checkout main && git pull --ff-only && git status --porcelain` → empty.
2. **No sprint is in flight.** `_bmad-output/implementation-artifacts/sprint-status.yaml` shows
   s301 `done` and no s302. If a sprint IS running, STOP and ping the operator — the ordering
   argument above no longer holds.
3. ~~**graph's installed ai-dlc is 0.292.0**~~ — **STALE. It is now `0.300.0 / 2bc7aa4`**, which is
   step 1 having succeeded. `contract_version` was 16 on both sides, so the pull carried **no
   contract migration**.

## Step 1 — take the pull

**TWO HOPS, AND `apply` IS REQUIRED ON BOTH.** An earlier revision of this file said "one hop,
not two" and told you to run bare `/ai-dlc-update`. **Both were wrong**, and a real dry run
against graph on 2026-08-07T23:38Z is what corrected them:

- **Bare `/ai-dlc-update` is a DRY RUN.** It writes nothing, branches nothing, commits nothing.
  The word `apply` is what makes it act.
- **The gate DEFERRED this pull's machinery slice**, on `rulebook-coupled-fixtures`: the range
  changes fourteen rulebook files and 26 fixtures assert against a rulebook file resolved in the
  live tree, so the machinery cannot be green on its own. `--safe-stop` then did its job and
  NAMED the split. It exists to identify the two-hop, not to remove it — which is the inference
  the earlier revision got backwards.

Run exactly this:

    /ai-dlc-update ef37564caa437f29409229a40c197ff048462023 apply     # engine to 0.297.0, auto-re-invokes
    /ai-dlc-update apply                                              # then the rest

`ef37564` is v0.297.0, the SAFE-STOP the gate derived itself — its slice self-updates cleanly, so
the engine lands and step 2 re-invokes on it. **Merge the PR each hop opens before starting the
next.**

**A single `/ai-dlc-update apply` from 0.292.0 is not wrong, only BLIND**: it would classify
0.293.0→0.300.0 using the 0.292.0 classifier, so any detector improvement in the range does not
run and the signal it would have raised reports as nothing. graph's own ledger already carries two
live entries describing exactly that failure surface.

**The range is 0.293.0 → 0.300.0.** `contract_version` is **16 on both sides** (verified), so no
contract migration. The semantic worklist came back at **1 file** — `deploy-validate.md`, bucket
*apply via mask/reinject*, no conflict, no operator confirmation needed.

**Two things that should NOT alarm you.**

- The self-update gate probes each gating script bare. `validate-provenance-block.sh` exits 2 that
  way on BOTH sides, which 0.288.0 made its own `OK` arm — that is not the defer above.
- `validate-provenance-block.sh`'s retro classifier now matches `docs/retro/s<N>/retro.md`. On the
  unmigrated tree it matches nothing, so retro-specific provenance requirements do not apply
  during this window. Not a failure; the pull lands through it.

## Step 2 — dry run, and READ IT

    scripts/ai-dlc/migrate-artifact-paths.sh

**It writes nothing without `--apply`.** Expect roughly this shape. **These are PRE-PULL baseline
figures measured on a clone of graph at `655fd3acf` — use the numbers YOUR run prints, not these.**
They are here so a wildly different answer is visible as wildly different:

```
tracked files scanned                  5145
moves planned                          2667
REFUSED                                  48      45 ambiguous, 3 with no derivable area
DEFERRED (stories/)                    1001
destinations still carrying a token        0      <- must be 0; non-zero aborts the apply
```

**If `moves planned` is 0 and `REFUSED` is 0, STOP.** That is either an already-migrated tree or a
scan that resolved nothing, and the script distinguishes them in its verdict line — read it.

**If the self-check line is not 0, STOP and ping the operator.** It means the script would write
paths its own grammar rejects. `--apply` refuses in that state anyway.

## Dispositioning the refusals

**Refused files are NOT migrated and remain non-conforming. They are not blockers for step 3** —
apply the 2667, then come back to these. Measured breakdown of the 48:

**A. 28 × `s253-execution-health-evidence.md`**, one under each of
`sprint-254 … sprint-281`, `sprint-287`. The DIRECTORY names the sprint whose smoke run it is; the
`s253` in the basename is a stale copy artifact from whenever the file was first cloned forward.
**The directory is right.** Rename the basename to drop `s253-` and re-run; they then migrate
normally. Do not "resolve" them by trusting the basename.

**B. 3 × genuinely multi-sprint log archives** —
`_bmad-output/context-mode-protection-log-archive-s294-s295.md`,
`_bmad-output/implementation-artifacts/gate-log-archive-s291-s292.md`,
`.../gate-log-archive-s293-s294.md`. These really do cover two sprints. Under the grammar
(0.299.0) an archive covering more than its own sprint is filed under the sprint it was rotated at
— the LATER number — and **states the span in its first line**, e.g. `<!-- covers s291..s292 -->`.
Add that line, rename to drop the first sprint token, re-run.

**C. 14 × a low `s1`–`s99` token that is part of a SLUG, not a sprint** —
`s289-10-s9-ack-resets-timer.md`, `sprint-246/pvc-s11-strip.md`,
`s295-safeguard-state-s7.md` and siblings. The real sprint is the large number; the small one
names a story or a state. **Rename the slug fragment** (`s9-ack-resets-timer` → `ack-resets-timer`,
`pvc-s11-strip` → `pvc-strip`) rather than guessing which token is the sprint.

**D. 3 × NO-AREA** — `_bmad-output/sprint-177/ac5-graphql-gap-density-evidence.md`,
`.../sprint-177/wave-1-dispatch-status.md`, `_bmad-output/sprint-178/carry-over-evaluation-step2.md`.
A sprint directory sitting directly under `_bmad-output/`, which is declared NOT an area (it holds
live singletons). **Decide which area they belong to** — most likely
`_bmad-output/implementation-artifacts/` — `git mv` them under it, and re-run.

**The 1001 DEFERRED story files are a KNOWN gap, not an oversight.** `planning-artifacts/stories/`
carries the sprint in two spellings, one of which (`story-297-1-slug.md`) uses a bare number the
transform cannot tell from a story index. Migrating would move `story-S298-1-…` and leave
`story-297-1-…`, splitting one sprint's stories across two conventions. **Leave them. Do not
hand-migrate them.** They move in a later ai-dlc release that also moves the `stories_dir` schema
declaration and Check 5's story-id join.

**The AREAS INFERRED list is a message for the distribution, not a problem for you.** The grammar
declares eight areas; graph holds sprint-tokened files in eight more (`brainstorming`,
`test-artifacts`, `party-mode`, `gate-adjudication`, `party-verdicts-retro`, `party-review`,
`ai-dlc-update`, `sprint-review-transcripts`). They migrate correctly under a derived area.
**Report the list back to the operator** so the grammar can declare them.

## Step 3 — apply and commit

    scripts/ai-dlc/migrate-artifact-paths.sh --apply

It moves with `git mv` only, never deletes, and never edits a file's content. Every move is
verified as *source absent AND destination readable AND sha256 identical to the pre-move source*,
and it aborts at the first failure. **If it aborts, `git checkout -- .` restores the tree** — that
is what the clean-tree precondition buys.

Then verify independently, because the script's own verdict is not evidence:

    git status --porcelain=1 | cut -c1-2 | sort | uniq -c     # expect ONLY R (renames)
    git diff --cached --numstat | awk '$1!="0"&&$1!="-"'       # expect empty (no content change)
    git ls-files | wc -l                                       # expect UNCHANGED from before

**`-` in numstat is git's BINARY marker, not a content change.** Two `.png` files under
`smoke-evidence/` show it and are pure renames. An `awk` that treats `-` as non-zero reports two
false positives; the command above excludes it deliberately.

Then commit:

    git add -A
    git commit -m "chore(artifact-paths): migrate every artifact onto the s<N>/ path grammar"

**Historical traceability breaks here, and that is ACCEPTED by operator directive.** Citations
into the old paths stop resolving. Nothing rewrites links: the declared convention is the guide to
where to look, and a link-rewriting pass over 2600 files would be a second, unverifiable migration
riding on this one.

## Two traps. Each returns a clean-looking result that is wrong.

**A count is not verification.** "2667 moved" cannot see whether the right bytes arrived. The
per-file sha256 check is the only thing that can, which is why the independent `git status` /
`numstat` / `ls-files` triple above exists and why you run it rather than reading the summary.

**A second run must exit 3, and a 0 means work was left behind.** After committing, run the dry
run once more:

    scripts/ai-dlc/migrate-artifact-paths.sh; echo "rc=$?"

`rc=3` is "nothing to migrate" and is the pass. `rc=0` means the transform is not idempotent and
something did not move — ping the operator with the plan it printed.

## Done when

- The reconcile PR is merged and `git log` shows it on `main`.
- The migration is committed, and the independent triple showed **only renames, no content
  changes, an unchanged tracked-file count**.
- A second dry run exits **3**.

**Report these five things to the operator**, because the distribution needs them:

1. `moves applied` and `tracked files scanned` from your run.
2. `REFUSED` count, and which of classes A–D you dispositioned versus left.
3. `DEFERRED` count.
4. The full **AREAS INFERRED** list.
5. Anything in the pull's classify you had to adjudicate.

**Then s302 may start.** Not before — a sprint started mid-migration writes into the old layout.
