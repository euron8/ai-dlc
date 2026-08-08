# graph: pull 0.300.0 → 0.314.0 — DISCHARGED 2026-08-08, DO NOT EXECUTE

**THIS RUNBOOK IS SPENT. It ran, and graph is at `0.314.0 / f9b8aa4`.** Two hops, graph PRs
#882/#883/#884, 18 adjudications recorded. Verified from the distribution, not taken on the
report: `layer-drift.sh` over `2bc7aa4..f9b8aa4` returns **0 `HARD-*`** with 49 rows across 9
statuses and no `DRIFT-RANGE-DEGENERATE`.

**Its `## Current status` section below still says nothing has been started. That sentence was
true when written and is now false** — it is left in place because a superseded section that
disappears takes its reasoning with it, but a session acting on it would redo a landed pull.
Read the rest as a record of how the pull was taken, never as work outstanding.

## Start here

**You are in `/Users/n8/git/graph`. That is the tree you WRITE.**

`/Users/n8/git/ai-dlc` is the distribution. **READ IT, NEVER WRITE IT.** Everything below that
cites a `core/…` path is a path in ai-dlc, quoted so you can check a claim; nothing in this plan
asks you to change a byte there. If you believe a fix belongs upstream, say so in your report and
stop — it is a separate session in a separate repo.

**This file is the plan of record for this pull.** Work `## Next actions` in order. Do not
improvise a different order; two of the steps exist because the obvious order produced a
clean-looking wrong result once already.

**PING THE OPERATOR — on any question, on any decision, and when this is done, including if you
stop early.** The operator cannot see this session. From outside, "still working" and "stopped,
waiting on you" look identical, so silence is a stall they can only find by polling. Every
consumer-session stall in this project's history ended with the operator asking rather than the
session reporting — including one sitting on a blocking question and one that had already
finished. Do not batch your questions to the end.

## Current status — 2026-08-08, and this is the only status record in this file

- **graph is at `0.300.0` / `2bc7aa4`**, on `main`, migrated onto the artifact path grammar.
- **ai-dlc `main` is at `0.314.0`.** Nothing is in flight there; every release is merged.
- **The gap is 14 releases and 55 changed files**, and it touches **7 rulebook step files** plus
  `core/team-roles/pm.md` — so the self-update gate will split it. See §*How many hops*.
- **Nothing has been started.** No branch is cut, no dry run has been taken in graph.

**THE REASON THIS PULL IS WORTH TAKING NOW IS NOT THE DIFF SIZE.** graph migrated 2667 artifacts
onto the path grammar and **has no validator enforcing it** — that shipped in ai-dlc v0.305.0 and
graph is at 0.300.0. Measured, with a control:

```
ai-dlc  core/scripts/validate-artifact-paths.sh            present
graph   scripts/ai-dlc/validate-artifact-paths.sh          ABSENT
graph   .githooks/pre-push                                 0 references to it
control graph scripts/ai-dlc/validate-draft-stamps.sh      present   <- the walk works
```

Every artifact written in graph since the migration is unchecked, and s302 would start that way.
Landing the validator is the point; the other 13 releases come along with it.

## Next actions

1. **Confirm the tree is clean and on `main`.** `git -C /Users/n8/git/graph status --short`.
   Runtime state under `_bmad-output/` (`.context-sensor-state`, `.driver/turns`,
   `subagent-context.jsonl`, `pipeline-continuation-log.md`) is normally dirty and is not your
   problem — commit or stash it, but say which you did. **Any OTHER dirty file: stop and ping.**
   A pull that starts on unexplained local edits cannot tell your edits from upstream's.
2. **Take the DRY RUN.** `/ai-dlc-update` — **bare is a dry run.** It stops unconditionally at
   step 5 (`core/skills/ai-dlc-update/SKILL.md:800`) and writes nothing. **`apply` is the word
   that makes it act**; a previous session got this backwards and told the operator to run the
   bare form expecting it to apply.
3. **Read what the gate says about hops — do not compute it yourself.** See §*How many hops*.
   Report the verdict and, if it defers, the ref it names as the stop.
4. **Work the dry run's `HARD-*` rows before applying anything.** `hard-blockers.sh` selects on
   the PREFIX (`core/skills/ai-dlc-update/reconcile/hard-blockers.sh:48`), so the list is whatever
   is prefixed `HARD-`, not a set of names anyone remembers. **One of them is expected and is not
   a regression** — see §*The one blocker this pull raises on purpose*.
5. **Apply.** `/ai-dlc-update apply`. Step 7 is `core/skills/ai-dlc-update/SKILL.md:967`. It
   branches before any write; do not pre-create a branch for it.
6. **Dispose of every `WORKLIST` and `DECISION` row.** The run is not done while one is
   outstanding. **Read the third and fourth fields** — see §*Worklist rows now carry an
   instruction*.
7. **Repeat 2–6 for each remaining hop** until a dry run reports the consumer is at `0.314.0`.
8. **Verify the landing** — §*Done when*. In particular re-run the measurement at the top of this
   file and confirm the artifact-path validator is now present AND wired.
9. **Report.** Ping the operator with: the hop count actually taken, the PR numbers, every
   adjudication you recorded with its verdict, and anything you left open. **Name what you did
   not do.**

**NOT IN SCOPE for this pull, and each is deliberately parked:**

- **The 48 refused artifact-path migrations.** Still owed, from the earlier migration: 45
  `AMBIGUOUS`, 3 `NO-AREA`. Each needs a basename renamed and an area decided, which is judgement,
  not mechanism. They block nothing. Do not start them here.
- **`OWED-DEVPUSH-RESTATES-CORE` and `OWED-STS-DOMAIN-AB-ABSORBED`.** Two consumer obligations
  already recorded in graph's adjudication register. They gate nothing and are re-raised by every
  pull. If you have appetite after the pull lands, the `dev-push.md` split is the real work behind
  the first — but ping before starting it, and never fold it into a pull commit.

## The one blocker this pull raises on purpose

**Expect exactly one NEW `HARD-LAYER-ADJUDICATION-MISSING`, on
`overrides/steps__retro__domain-sections.md`. It is the mechanism working, not a regression.**

ai-dlc v0.314.0 promoted `LC-O15` (`OVERRIDE-SUPERSEDED`) to `level: ADJUDICATED`
(`core/skills/ai-dlc/layer-contract.yaml:591`), so the row now needs a recorded verdict before the
pull applies. Measured against graph's current tree, `HARD-LAYER-ADJUDICATION-MISSING` goes
**12 → 13**. If you see materially more than that, stop and ping — something else moved.

**WHY IT NEVER FIRED BEFORE.** The clause's join compared the WHOLE `shadows:` string, so an entry
bundling four anchors could never match a declaration naming one. That entry shadows
`steps/retro.md#4a. Close-Out Sweep` among four anchors, and core declared exactly that anchor
superseded at **0.281.0** (`core/skills/ai-dlc/layer-contract.yaml:366`). ai-dlc v0.312.0 fixed the
join. The entry's own `reason:` records two successive re-adoptions of that same section, one of
which it calls WRONG — so this is a signal it has needed for a while.

**THE REMEDY IS NOT `--stamp retire`, AND GETTING THIS WRONG DESTROYS YOUR OWN TEXT.**
`readopt-override.sh --stamp retire` **deletes the whole override file**
(`core/skills/ai-dlc-update/reconcile/readopt-override.sh:335`) — there is no per-anchor retire.
That entry shadows three anchors core has NOT superseded, and deleting it silently reverts every
section they cover to core.

Two verdicts are legitimate. **Pick one, record it, and say in the reason WHY:**

- **`retire`** — set `AI_DLC_SNAPSHOT_STRIKETHROUGH` in `.claude/settings.json` `"env"` FIRST
  (derive its value from the entry you are narrowing; do not copy an example), **then remove ONLY
  the `#4a. Close-Out Sweep` anchor from that entry's `shadows:`** and leave the other three
  byte-untouched. The order is a safety property, not a preference: narrowing before the key is
  written re-imposes the core rule on a tree that already violates it and reds the next gate. The
  worklist prints these as `1/2 ATOMIC` and `2/2 ATOMIC`; do both in one commit.
- **`still-additive`** — you want to keep the shadow for graph's own reasons. Entirely valid. The
  clause blocks on the ABSENCE of an answer, never on the answer.

**Record it in `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`**
(`core/skills/ai-dlc-update/reconcile/layer-drift.sh:394`), one JSON object per line, with the
`subject_digest` **the blocking row itself prints**. The vocabulary is
`still-additive | contradicts-core | retire` and it lives once, in
`core/schemas/layer-adjudication-register.json:34`; a verdict outside it does not clear the row.

**DO NOT COPY A DIGEST OUT OF THIS FILE.** The digest covers the entry file AND the core file it
targets at THEIRS, so it MOVES when either side moves — which is exactly what a multi-hop pull
does between hops. Copy the value from the row in front of you. (For cross-checking only: against
graph's tree today it is `6c91b446871cd9ec494354ceec7985dad95abca5`. If yours differs, yours is
right.)

## How many hops

**DO NOT PREDICT THE HOP COUNT, INCLUDING FROM THIS FILE.** This project has been wrong on it in
both directions, most recently telling the operator a pull was one hop when it was three. The gate
is the only authority.

The range touches rulebook files, so a `SELF-UPDATE-DEFER` is likely. A defer is correct and is
also a dead end unless something names the ref that ends it, which is what `--safe-stop` is for
(`core/skills/ai-dlc-update/reconcile/self-update-gate.sh:80`). Read the verdict the dry run
prints and follow the ref it names. Report the actual count when you are done — the plan in ai-dlc
records it.

## Worklist rows now carry an instruction — this is new in this range

Until ai-dlc v0.311.0, `apply.sh` printed **three** fields while eighteen of its call sites passed
four, so **every `WORKLIST` and `DECISION` detail was computed and discarded**. The row you used to
see was `WORKLIST<TAB>override-retire<TAB><path>` and nothing else. A second defect meant a
one-key `ATOMIC` sequence printed only its LAST step (`2/2 … --stamp retire`) while its own
numbering advertised a `1/2` that was never emitted — the exact reverse of the safe order.

Both are fixed. **So read field 4, and when a row says `<i>/<n> ATOMIC`, do every step of that
subject in the printed order and commit them together.** If you have pulled this repo before and
learned to ignore that column, unlearn it.

## Traps — each returns a clean-looking result that is wrong

- **A clean `hard-blockers.sh` sheet from the wrong base.** Most `ADJUDICATED` clauses are computed
  `base..theirs`, so passing `theirs` as the base makes them structurally unable to fire and prints
  zero blockers on a tree where every verdict is owed. `layer-drift.sh` now emits
  `DRIFT-RANGE-DEGENERATE` when the two refs resolve to the same commit — **if you see that row,
  your run answered nothing.** Pass the PULL's base to `layer-drift.sh` and `theirs` to
  `unregistered-drift.sh`; they are different questions and the step file says so per script.
- **`CORE-AT-SELF-UPDATE` rows read as consumer drift on a multi-hop pull.** They are not. A
  self-update hop advances `skill_commit`, so files byte-identical to the distribution at that
  intermediate ref are upstream content, not your edits. Do not "revert" them.
- **A zero with a working control is still not a measurement.** Both of the counts that produced
  this range's last four releases came back zero with a healthy control, and both were wrong — one
  false, one a silence. If a check you are relying on reports nothing, ask whether it COULD have
  reported something before you treat the zero as evidence.

## Done when

All of these, checked rather than remembered:

1. A dry run reports the consumer at **`0.314.0`** with no remaining hop.
2. `hard-blockers.sh` prints **zero** `HARD-*` rows, on a run taken with the PULL's base, and that
   run did **not** emit `DRIFT-RANGE-DEGENERATE`.
3. Every `WORKLIST` and `DECISION` row from every hop is disposed of, and the LC-O15 adjudication
   is recorded with a verdict from the schema's vocabulary.
4. `scripts/ai-dlc/validate-artifact-paths.sh` **exists in graph** and `.githooks/pre-push`
   **references it** — both, because a validator that lands unwired is the failure this pull is
   being taken to end.
5. graph's own `git push` gate is green.
6. The operator has been pinged with the hop count, the PRs, every verdict recorded, and whatever
   you left open.
