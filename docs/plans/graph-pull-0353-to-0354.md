# Runbook — pull the graph consumer from 0.353.0 to 0.354.0, mid-sprint s302

**Status: DISCHARGED 2026-08-11.** Executed on the consumer; every criterion re-verified from
the distribution side, read-only, against the consumer's tree rather than against its report.
See §Discharge. Authored against a real rehearsal (§Rehearsal), not a prediction.

## Start here

Two repos, and the read/write boundary between them is absolute.

- **Distribution — `/Users/n8/git/ai-dlc`. Read it, never write it.** `main` is at `0.354.0`,
  commit `017668d`. Every step below reads from this tree and edits none of it; the two
  upstream filings this run owes (steps 7 and 8) are written into the CONSUMER's push-candidate
  ledger, not into the distribution.
- **Consumer — `/Users/n8/git/graph`, the tree you WRITE.** Branch
  `ai-dlc/feature/s302-position-usd-create-position`, HEAD `3bbd00ce1`.
  `.claude/.ai-dlc-version` reads `version: 0.353.0` / `commit: 6e6598a`.

Sprint s302 story-validation has **converged**: `stories-adversarial-p7.md` stamps
`findings_critical: 0`, `findings_major: 0`, `verdict: EXIT_CONDITION_MET`. The pipeline is
paused before test-strategy §5, and `_bmad-output/pipeline-paused.flag` is raised. The seam is
past: `--cycle-state` on that series returns `CONVERGED`, and nothing below writes a story
file or a pass artifact — steps 4 and 5 touch only resolution and repair records.

**Ping the operator** on any question, on any decision this file does not settle, and on
completion — including an early stop. A session that stops silently is indistinguishable
from one still working, and every stall in this repo's history ended with the operator asking
rather than the session reporting.

---

## Next actions

1. **Commit the pipeline telemetry state.** Same preamble as `f10638d1f`
   ("chore(s302): pipeline telemetry state before resuming the 0.348.0 → 0.353.0 pull").
   Currently dirty: `_bmad-output/.context-sensor-state`, `_bmad-output/.driver/turns`,
   `_bmad-output/pipeline-continuation-log.md`.

2. **Run the pull.** `ai-dlc-update` bare for the dry-run report, review, then
   `ai-dlc-update apply`.

   **Expect `SELF-UPDATE-DEFER`, and do NOT reach for the `<ref> apply` form.** Measured:

   ```
   bash .claude/skills/ai-dlc-update/reconcile/self-update-gate.sh \
        /Users/n8/git/ai-dlc 6e6598a 017668d "$PWD"
   ```

   returns `SELF-UPDATE-DEFER rulebook-coupled-fixtures`, a second `SELF-UPDATE-DEFER`
   saying "Do NOT cut the self-update branch", and
   `SELF-UPDATE-SAFE-STOP - no intermediate release in 6e6598a..017668d self-updates
   cleanly`. The `<ref> apply` form exists for when the gate NAMES a safe stop; here it
   reports there is none. Fold the machinery slice into one gated apply.

   The coupling is real: 0.354.0 changes eight rulebook files in the same pull as a new
   fixture, and 33 fixtures resolve a rulebook file out of the live tree.

3. **Re-read two extension entries and record a verdict for each.** The apply emits these
   as `WORKLIST extension-reread` (measured, §Rehearsal):

   - `.claude/skills/ai-dlc/extensions/roles/pm-domain.md`
   - `.claude/skills/ai-dlc/extensions/roles/tea-consumer.md`

   Both hook a core role file that 0.354.0 changed (`pm.md`, `tea.md` each gain an "evidence
   contract" section). Record `still-additive` / `contradicts-core` / `retire` per entry.

   The apply also emits one `NOTE override-adjudicated` for
   `overrides/steps__retro__domain-sections.md`. **That one needs no action** — this project
   already recorded a `still-additive` verdict for that exact subject, and the note exists so
   the supersession stays visible.

4. **Backfill three resolution records.** Arm F7 (new in 0.354.0) fails any
   `ADVERSARIAL_RESOLUTION v1` record with `adjudicated_by: operator` that lacks
   `options_presented` (>= 2) and `recommended_option`. Values below were extracted from
   `~/.claude/projects/-Users-n8-git-graph/*.jsonl`; **re-derive each before writing it** —
   confirm the `tool_use` id and answer timestamp yourself. Take the field grammar from the
   pulled `_gate-procedures.md`, not from this file.

   | record | tool_use | answered | fields |
   |---|---|---|---|
   | `product-brief-resolution-p3.md` | `toolu_01UfpFpUa3ZHCaBFQazDnHx2` | 2026-08-10T16:37:13.517Z | `options_presented: 3` · `recommended_option: Fix both sentences (Recommended)` |
   | `product-brief-resolution-p4.md` | `toolu_015sjpZKvxUzAWK4yyCkKWf2` | 2026-08-10T16:56:44.773Z | `options_presented: 2` · `recommended_option: Apply the three deletions (Recommended)` |
   | `stories-resolution-p4.md` | `toolu_01X2tK2vJionn9av6rp2vtdi` | 2026-08-11T09:37:22.011Z | `options_presented: 2` · `recommended_option: Yes, proceed (Recommended)` |

   All three live under `_bmad-output/planning-artifacts/s302/`.

   **`stories-resolution-p4.md` needs two prose corrections as well.** Its text says three
   `AskUserQuestion` rounds; there were **five** (3/3/2/2/2 options), and **in all five the
   operator answered free-form and never selected an option label** — the
   `operator_authorization` quote is the first sentence of a longer round-5 answer. Record
   the authorizing round's numbers and say the adjudication was free-form. A record implying
   a menu selection that did not happen is a false claim written to satisfy a validator,
   which is the defect 0.354.0 exists to stop.

   For `product-brief-resolution-p4.md`, note option 2 (`Stop the cycle here`) declares
   itself an operator override rather than one of the five sanctioned kinds. If the record
   characterises it as a choice between two kinds, correct that.

5. **Restructure `stories-repair-p6.md` so arm H can read it.** This is a **PRE-EXISTING**
   failure, not caused by 0.354.0 — it reproduces against graph's current 0.353.0 validator
   today (§Rehearsal). Root cause, measured:

   Arm H tests `grep -q '^[[:space:]-]*derivation:'`
   (`core/scripts/validate-adversarial-convergence.sh:1284-1286`). That bracket class does
   not contain `*`, so a line written as `- **derivation:**` fails it. Every derivation
   heading in `stories-repair-p6.md` is bolded that way, so the record reads UNSTRUCTURED to
   the validator even though a human sees all three fields.

   Write the three field headings unbolded — `- disposition:`, `- edit:`, `- derivation:` —
   matching the template in the pulled `core/team-roles/remediator.md`.

6. **Verify.** See §Done when.

7. **File an upstream push candidate for arm H.** The taught form in `remediator.md` is
   plain; every real record this consumer writes is bolded; arm H reads only the plain form.
   So the arm is a **false positive against the house style**, and nothing joins the two.
   File it in `_bmad-output/ai-dlc-update/push-candidate-ledger.md` with a machine-checkable
   `verify:` predicate, not `verify: manual`.

8. **Close `PC-S302-ADVERSARY-RECIPE-PRESENT-IS-NOT-RECIPE-RUN`.** 0.354.0's new
   `adversary.md` rung ("a recipe you did not RUN is a claim you did not review") satisfies
   it. The entry carries `verify: manual`, so `ledger-reverify.sh` cannot close it — give it
   an `sh` or `theirs_has` predicate **scoped to the new rung's own span** in
   `.claude/team-roles/adversary.md`, never a file-wide substring. The ledger's own header
   records why: a file-wide substring test produced a false CLOSE, *"the worst output this
   tool has, because it retires an entry that is still live."* Mutation-test both directions
   — seed the marker into a copy and it must report CLOSE-CANDIDATE; the unmutated file must
   report STILL-LIVE.

9. **Hand off.** Resume point is test-strategy §5. State in the handoff that steps 1–8 are
   done and the stories series is frozen at p7.

---

## Done when

Each criterion states its **observation point** and its **expected** result, because two of
them are not "green" and an executor told to expect green would report failure for work that
succeeded.

1. **After step 2** — `.claude/.ai-dlc-version` reads `version: 0.354.0` / `commit: 017668d`,
   and `skill_version` / `skill_commit` advance with it. The apply emits
   `RESOLVED restamp-machinery 6e6598a -> 017668d` when it carries the machinery slice; if it
   does not, the next pull reads every machinery file this run wrote as consumer drift.

2. **After step 4, before step 5** — the convergence validator's arm-F row is GONE and
   **exactly one FAIL remains, arm H**. Do not expect rc=0 here.

   ```
   bash scripts/ai-dlc/validate-adversarial-convergence.sh \
     --series _bmad-output/planning-artifacts/s302/stories-adversarial-p \
     --transcript-dir ~/.claude/projects/-Users-n8-git-graph
   echo "rc=$?"
   ```

   Expected at this point: `rc=1`, output containing `FAIL (H -- REPAIR-RECORD)` and **no**
   `FAIL (F -- RESOLUTION)`. Measured in rehearsal. **Do not read the exit code through a
   pipe** — `... | tail` reports `tail`'s status, not the validator's.

3. **After step 5** — the same command returns `rc=0` and prints no FAIL row.

4. **The derivation checker is installed and is not blind.**

   ```
   bash scripts/ai-dlc/validate-artifact-derivations.sh --list _bmad-output/planning-artifacts/s302
   ```

   Expected: `0 derivation(s) in 0 block(s) across 93 file(s)` — nothing in this consumer uses
   the ` ```derived ` grammar yet, so zero is the correct answer.

   **The control must be a scratch file, not the shipped fixture directory.**
   `tests/fixtures/artifact-derivations/` contains no `.md` files — it generates its subjects
   into a temp dir at runtime — so pointing `--list` at it returns `0 derivation(s) ... across
   0 file(s)`, which proves nothing. Write a scratch file containing one ` ```derived ` block
   and confirm `--list` reports `1 derivation(s)`.

5. **After step 5** — `bash tests/fixtures/artifact-derivations/run.sh` prints
   `PASS: all assertions correct.`

6. **Before the handoff** — `git push` runs the fixture suite through the pre-push hook and
   it passes. Do not hand-roll a loop over the fixture directories: several fixtures resolve
   the repo root from the process working directory, and a `cd` into the fixture dir
   fabricates failures.

---

## Rehearsal — this runbook was executed against a copy before it shipped

Run 2026-08-11 against a `git clone --local` of graph at `3bbd00ce1`, in the session
scratchpad, with the real distribution at `017668d`. The consumer tree itself was not
touched. What the rehearsal changed in this file, versus the version written from prediction:

- **`preclassify.sh` classified all 17 changed files `UPSTREAM-ONLY` / `UPSTREAM-ONLY-ADD`** —
  no `CLASSIFY` rows, so there is no semantic merge and no operator adjudication in this pull.
- **`apply.sh --carried-machinery-slice` emitted two `WORKLIST extension-reread` rows** that
  the prediction missed entirely. They are step 3, and they exist because this release edits
  five author role files.
- **Arm H fails, and it is pre-existing** — reproduced against graph's own 0.353.0 validator,
  which is what separates "the pull broke it" from "it was already broken." Root cause traced
  to the bold-markdown/bracket-class mismatch in step 5.
- **The control originally given for criterion 4 was vacuous** — the fixture directory holds
  no `.md` files, so the "control" returned 0 exactly like the subject.
- **Criterion 2 was originally written as `rc=0` and is unreachable at that observation
  point.** The migration was applied on the copy and re-measured: the F row disappears and
  arm H remains.

---

## Discharge — 2026-08-11, verified from this side

The consumer reported completion. Everything below was re-measured against
`/Users/n8/git/graph` read-only rather than taken from that report.

| # | criterion | measured |
|---|---|---|
| 1 | version stamp | `version: 0.354.0` / `commit: b9428e8`, `skill_version` and `skill_commit` advanced with it |
| 2–3 | convergence validator on the stories series | `rc=0`, **no FAIL row** — the arm-F migration and the arm-H restructure both landed |
| 4 | derivation checker | `0 derivation(s) ... across 93 file(s)`; the CONTROL (a scratch file with one fenced block) returns `1 derivation(s)`, so the zero is a real absence |
| 5 | shipped fixture | `PASS: all assertions correct.` |

And the three steps that produce artifacts rather than exit codes:

- **Step 3 — extension rereads.** `layer-adjudication-register.jsonl` gained **exactly two rows
  in the `bb1fff8d4~1..HEAD` range**, one per worklist item, both `still-additive`. Range-scoped
  on purpose: `pm-domain.md` already carried three historical rows, and reading those as this
  run's work is the trap where a fix's own prior receipts look like its output.
- **Step 7 — the arm-H filing.** `PC-S302-ARM-H-READS-ONLY-THE-UNBOLDED-FIELD-HEADING-...` is
  filed with a two-conjunct `verify: sh` predicate (core still carries the `[[:space:]-]*`
  class AND `remediator.md` still says nothing about bold), and the entry carries its own
  control — `bold` reads 0 in a file where `derivation` reads 8.
- **Step 8 — PC-S302 closed.** `verify: manual` was **re-anchored to an `sh` predicate** scoped
  to the new rung's own sentence, and the entry closed `NAMED-UPSTREAM` at v0.354.0 and rotated
  to `push-candidate-ledger.archive.md`. That is the closure the runbook asked for: the entry
  can now close itself, which `manual` never could.

**One correction to this file's own record.** The stamp reads `b9428e8`, not the `017668d` named
throughout the steps above. That is correct, not drift: `017668d` was `main` when this runbook was
authored, and two docs-only commits (#525, #526 — this file and a trim to it) landed before the
pull ran. No consumer-visible file differs between the two refs.

**Nothing here is owed forward.** The one open thread is upstream, not consumer-side: the arm-H
defect this run filed is real, unfixed in core, and its predicate will report CLOSE-CANDIDATE the
moment core's bracket class changes.
