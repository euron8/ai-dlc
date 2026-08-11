# Runbook — pull the graph consumer from 0.354.0 to 0.355.0, mid-sprint s302

**Status: DISCHARGED 2026-08-11.** Executed on the consumer; every criterion re-verified from
the distribution side, read-only, against the consumer's tree rather than against its report.
See §Discharge — **three criteria below were WRONG and are corrected there**, all three from
broken instruments on the distribution side. Authored against a real rehearsal (§Rehearsal).

## Start here

Two repos, and the read/write boundary between them is absolute.

- **Distribution — `/Users/n8/git/ai-dlc`. Read it, never write it.** `main` is at `0.355.0`,
  commit `4cded9e`. Every step below reads from this tree and edits none of it.
- **Consumer — `/Users/n8/git/graph`, the tree you WRITE.** Branch
  `ai-dlc/feature/s302-position-usd-create-position`, HEAD `2fdace418`.
  `.claude/.ai-dlc-version` reads `version: 0.354.0` / `commit: b9428e8`.

0.355.0 is one defect fix: `validate-adversarial-convergence.sh` arm H read only the
UNBOLDED repair-record field heading, so `- **derivation:**` — the form this consumer writes —
read as UNSTRUCTURED. It is this consumer's own filing,
`PC-S302-ARM-H-READS-ONLY-THE-UNBOLDED-FIELD-HEADING-WHILE-THE-TAUGHT-FORM-GOES-UNENFORCED`.

**The seam is past and this pull touches no artifact.** Sprint s302 story-validation has
converged (`stories-adversarial-p7.md` stamps `EXIT_CONDITION_MET`); the pipeline is paused
before test-strategy §5. Six distribution files change, all `UPSTREAM-ONLY`; the semantic
worklist is empty; no deletions and no script relocations. Nothing below writes a story file,
a pass artifact or a repair record.

**Ping the operator** on any question, on any decision this file does not settle, and on
completion — including an early stop. A session that stops silently is indistinguishable from
one still working, and every stall in this repo's history ended with the operator asking
rather than the session reporting.

---

## Next actions

1. **Commit the pipeline telemetry state.** Same preamble as `974a823f5`
   ("chore(s302): pipeline telemetry state after the 0.353.0 → 0.354.0 merge").
   Dirty at the time of writing: `_bmad-output/.context-sensor-state`,
   `_bmad-output/.driver/turns`, `_bmad-output/pipeline-continuation-log.md`. Re-derive the
   list yourself; it moves with every session.

2. **Run the pull.** `ai-dlc-update` bare for the dry-run report, review, then apply.

   **Expect `SELF-UPDATE-DEFER`, and do NOT reach for the `<ref> apply` form.** Measured on
   the rehearsal copy:

   ```
   bash .claude/skills/ai-dlc-update/reconcile/self-update-gate.sh \
        /Users/n8/git/ai-dlc b9428e8 4cded9e "$PWD"
   ```

   returns `SELF-UPDATE-DEFER rulebook-coupled-fixtures` naming
   `[gate-validation.md remediator.md]` and 35 fixtures, a second `SELF-UPDATE-DEFER` saying
   "Do NOT cut the self-update branch", and `SELF-UPDATE-SAFE-STOP - no intermediate release
   in b9428e8..4cded9e self-updates cleanly`. Fold the machinery slice into one gated apply.

3. **The apply MUST carry `--carried-machinery-slice`.** This is the step a prediction gets
   wrong, and it is silent when wrong. Rehearsed both ways on separate clones:

   | apply form | `.claude/.ai-dlc-version` after |
   |---|---|
   | without the flag | `version: 0.355.0` / `commit: 4cded9e`, **`skill_version: 0.354.0` / `skill_commit: b9428e8`** |
   | with the flag | all four advance to `0.355.0` / `4cded9e` |

   The flagged run says why, in its own `RESOLVED restamp-machinery` row: *"Without this the
   next pull reads every machinery file this run wrote as consumer drift."*
   `core/skills/ai-dlc-update/reconcile/apply.sh:1154`. Step 2 deferred, so the slice IS
   carried, so the flag applies.

4. **Re-read FOUR extension entries and record a verdict for each.** All four hook
   `steps/gate-validation.md`, which 0.355.0 changed:

   - `.claude/skills/ai-dlc/extensions/checks/attribution-provenance.md`
   - `.claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md`
   - `.claude/skills/ai-dlc/extensions/checks/gate-validation-push.md`
   - `.claude/skills/ai-dlc/extensions/checks/validator-honesty.md`

   Record `still-additive` / `contradicts-core` / `retire` per entry. The core change they
   must be read against is one paragraph: the two new fixture cases named in the arm-H
   section of `core/skills/ai-dlc/steps/gate-validation.md`.

   **These appear as `HARD-LAYER-ADJUDICATION-MISSING` in the DRY-RUN report and as
   `WORKLIST extension-reread` in the apply. They do NOT block the apply** — the rehearsed
   apply exited 0 with all six files written. Do not stop and ask for an unblock.

   The apply also emits one `NOTE override-adjudicated` for
   `overrides/steps__retro__domain-sections.md`. **That one needs no action** — this project
   already recorded a `still-additive` verdict for that exact subject; the note exists so the
   supersession stays visible.

5. **Close `PC-S302-ARM-H-...-GOES-UNENFORCED` BY HAND.** Read §Done when criterion 4 first:
   the tool will NOT hand you a `CLOSE-CANDIDATE` for it, and the reason is mechanical, not a
   sign the fix missed.

   Confirm the absorption yourself against the distribution — the entry's own two conjuncts,
   each with its control:

   ```
   git -C /Users/n8/git/ai-dlc show 4cded9e:core/scripts/validate-adversarial-convergence.sh \
     | grep -cF '[[:space:]-]*derivation:'          # 0   (at b9428e8: 1 — the CONTROL)
   git -C /Users/n8/git/ai-dlc show 4cded9e:core/team-roles/remediator.md \
     | grep -ciF bold                               # 1   (at b9428e8: 0 — the CONTROL)
   ```

   Both conjuncts flip, so the entry's `verify: sh` predicate is false = absorbed. Annotate it
   **`**ADOPTED UPSTREAM (v0.355.0, verified 2026-08-11)**`** — bolded, version immediately
   after the parenthesis. That exact form is the only one `ledger-rotate.sh` can archive; any
   looser phrasing makes `ledger-reverify` skip the entry forever without making it
   archivable. Do NOT delete the entry, and do NOT rotate it in this run (see criterion 4's
   observation point).

   While you are in the entry, **re-anchor its receipt** so the next reader is not sent
   through the same guard: the predicate names `core/scripts/validate-adversarial-convergence.sh`,
   and the substring `scripts/validate-adversarial-convergence.sh` inside it is read as a
   consumer path that does not exist (the installed path is `scripts/ai-dlc/...`).

6. **Verify.** See §Done when.

7. **Hand off.** Resume point is test-strategy §5. State in the handoff that steps 1–6 are
   done and the stories series is frozen at p7.

---

## Done when

Each criterion states its **observation point** and its **expected** result, because three of
them are not "green" and an executor told to expect green would report failure for work that
succeeded.

1. **`.claude/.ai-dlc-version` reads `0.355.0` / `4cded9e` on ALL FOUR lines.** Observed after
   step 3. Two of the four is the unflagged apply and means step 3 was run without
   `--carried-machinery-slice`; re-run it with the flag rather than hand-editing the stamp.

2. **The check-24 fixture passes 80 of 80 on the consumer's own installed tree.**

   ```
   bash tests/fixtures/check-24-adversarial-convergence/run.sh
   ```

   **Run it in your NORMAL shell.** Under a scrubbed environment (`env -i PATH=/usr/bin:/bin`)
   **7 of the 80 go red** — `divergent-resolved`, the three `F7-*` arms, `cross-session`,
   `ceiling-converged`, `I-remedy` — and they read exactly like a regression from the pull.
   The variable is `node` on `PATH`, nothing else: adding only node's directory back to that
   same scrubbed PATH restores 80 of 80. The validator anticipates it in its own comment,
   `core/scripts/validate-adversarial-convergence.sh:831` (*"Tooling error (e.g. node absent),
   not a NOMATCH"*). This is the measurement that misled the author of this runbook first.

3. **Arm H fires on 5 of the consumer's 46 adversarial series — NOT 0.** Observed after step 3,
   against the newly installed `scripts/ai-dlc/validate-adversarial-convergence.sh`. Before the
   pull it fires on 10. **The 5 survivors are the control that arm H still fires at all**; a 0
   here would mean the reader had been widened into a check that cannot fire, which is the
   failure this release exists to avoid. They are, by path under
   `_bmad-output/planning-artifacts/`:

   | series | why it still fails |
   |---|---|
   | `s292/stories-adversarial-` | no repair record on disk at all — a true positive |
   | `s293/coe-adversarial-` | record says `- **edit sites:**`, not `edit:` |
   | `s300/archive/architecture-adversarial-cycle-1/architecture-adversarial-` | `**Method:** / **Where:**` vocabulary |
   | `s300/archive/stories-adversarial-cycle-1/stories-adversarial-` | `**Edit scope:**` vocabulary |
   | `s301/archive/architecture-adversarial-cycle-1/architecture-adversarial-` | `**derivation 1 — ...**`, no colon |

   All five are ARCHIVED past sprints and gate nothing; the live sprint s302 fires arm H on
   nothing, before or after. **Leave them.** Total convergence FAIL lines across all 46 go
   41 → 30.

4. **The ledger reports the arm-H entry as `NAMED-UPSTREAM` + `NEEDS-REVIEW`, and NOT as
   `CLOSE-CANDIDATE`.** Observation point: `ledger-reverify` run at any time after step 3 and
   **before** any `ledger-rotate` — a rotated entry emits no row, so a criterion read after
   rotation reads 0 for a reason that has nothing to do with this pull.

   Expected, verbatim in shape:

   - `NAMED-UPSTREAM ... upstream's own history NAMES this entry's id at v0.355.0 (4cded9e)`
   - `NEEDS-REVIEW ... the receipt exited 1, but consumer-relative path(s) it names DO NOT
     EXIST: scripts/validate-adversarial-convergence.sh`

   **The `NEEDS-REVIEW` is correct behaviour, not a miss.** The receipt names the DISTRIBUTION
   path `core/scripts/validate-adversarial-convergence.sh`; the guard's extraction regex
   (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:472`) matches the substring
   `scripts/validate-adversarial-convergence.sh` and resolves it against the consumer, where
   the installed path is `scripts/ai-dlc/...`. So it refuses to certify a close on an exit it
   cannot attribute — deliberately, because the guard exists to stop a false close, and
   `ledger-reverify.sh:964` records the run where a distribution-side session wrote a
   `CLOSE-CANDIDATE` into a runbook that the consumer's own run contradicted. Step 5 closes
   the entry by hand instead. Re-anchoring the receipt (step 5) is what clears the row.

5. **`CLOSE-CANDIDATE PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK` is PRE-EXISTING — do
   not attribute it to this pull, and do not act on it here.** Control, rehearsed: the same
   report generated with `theirs = b9428e8` (a no-op pull) emits the identical single
   `CLOSE-CANDIDATE` row. It is out of scope for this runbook; leave it for whoever drains it.

6. **The consumer's own pre-push suite is green**, run the way its hook runs it, never a
   hand-rolled loop over the fixture directories.

7. **`s302/stories-adversarial-p*` still fails arm F, not arm H — before AND after.** The
   message is `F -- RESOLUTION: stories-adversarial-p5.md claims to resolve ... 1 convergence
   violation(s)`, and it is `stories-resolution-p4.md`'s `operator_authorization` failing to
   verify. Pre-existing, unrelated to 0.355.0, and untouched by it. Do not fold it into this
   pull.

---

## Rehearsal — this runbook was executed against a copy before it shipped

`git clone --local /Users/n8/git/graph` (two clones: one for the unflagged apply, one for the
flagged), checked out to the same branch and HEAD `2fdace418`. Nothing was written to
`/Users/n8/git/graph`.

Executed on the copy: the self-update gate, `emit-report.sh` (twice — once for 0.355.0 and
once with `theirs = base` as the control), `apply.sh` both with and without
`--carried-machinery-slice`, `ledger-reverify.sh` (twice, same control), the check-24 fixture,
and a 46-series arm-H sweep with the newly installed validator.

**Five things the rehearsal contradicted**, each of which a prediction would have written the
other way:

1. `--carried-machinery-slice` is required. Without it two of the four stamp lines silently
   stay at 0.354.0.
2. The four `HARD-LAYER-ADJUDICATION-MISSING` rows in the dry-run are `WORKLIST
   extension-reread` rows at apply and do **not** block it. `apply.sh` exited 0.
3. The arm-H entry reads `NEEDS-REVIEW`, not `CLOSE-CANDIDATE`, because of a path-substring
   guard — so criterion 4 states the guard rather than a green.
4. The `PC-S312` `CLOSE-CANDIDATE` is pre-existing. Only the `theirs = base` control shows
   that; the 0.355.0 report alone reads as if the pull produced it.
5. The fixture needs `node` on `PATH`. The first rehearsal run scrubbed the environment and
   produced 7 failures that looked exactly like a regression in the change under test.

Also measured and folded in: the semantic worklist is EMPTY (0 rows), the six changed files
are all `UPSTREAM-ONLY`, and the three `CORE-TEMPLATE-SUBSTITUTED` drift rows
(`deploy-validate.md`, `dev.md`, `qa.md`) are unchanged by this pull and appear in the control
too.

---

## Discharge — 2026-08-11, verified from this side

The consumer executed it at `a086bac68` ("chore(ai-dlc-update): reconcile distribution
0.354.0 → 0.355.0", #917), after `340da8fc7` for the telemetry state. Everything below was
re-derived read-only against `/Users/n8/git/graph`'s own tree, not read out of its report.

**Verified as written:**

- All FOUR stamp lines read `0.355.0` / `4cded9e`, so the apply carried
  `--carried-machinery-slice`.
- `tests/fixtures/check-24-adversarial-convergence/run.sh` — **PASS, 80 of 80**.
- Arm H fires on **5 of 46**, down from 10, and the five are exactly the five this file names.
- The ledger entry carries `**ADOPTED UPSTREAM (v0.355.0, verified 2026-08-11)**` in the exact
  bolded form, is still in the live ledger, and is **not** in the archive — rotation deferred
  as instructed.
- Four `still-additive` verdicts in `layer-adjudication-register.jsonl`, each with its own
  derivation command and result, plus a 72-line blocker-adjudication record.
- **No planning artifact was touched.** `git log 2fdace418..HEAD -- .../planning-artifacts/`
  is empty.

### Three criteria in this file were WRONG. All three are distribution-side instrument errors

**Criterion 7 was false and is withdrawn.** `s302/stories-adversarial-p*` does **not** fail
arm F. It is clean before AND after — its resolution record was already backfilled by the
0.354.0 pull's own step 4. Two separate broken instruments produced the claim, and the second
one was built while correcting the first:

- the rehearsal sweep ran under `env -i PATH=/usr/bin:/bin` — **node absent**, which is the
  very hazard criterion 2 warns about. Arm F's citation check needs it.
- the re-measurement ran a `/tmp` COPY of the pre-pull validator, and
  `validate-adversarial-convergence.sh:120` resolves `validate-steering-budget.sh` from
  `$(dirname "$0")`. In `/tmp` that sibling does not exist, the sub-validator returns rc=1,
  and arm F reports `operator_authorization could not be verified` — a missing FILE reading
  as a failed CHECK. This is the copy-run-from-`/tmp` trap `CLAUDE.md` names, quoted in this
  work's own plan and then walked into anyway.

Correct instrument: the full `scripts/ai-dlc/` directory copied so the sibling resolves, with
node on `PATH`. The consumer session reproduced the claim because this file told it to expect
it, and recorded it honestly under "Deliberately not done".

**Criterion 3's totals were node-less.** Correct figures, same instrument both sides:
**39 → 28** total FAIL lines, not 41 → 30. **The arm-H headline is unaffected: 10 → 5 holds
under every instrument tried**, because arm H shells out to nothing.

**Criterion 5 was a CLONE ARTIFACT.** On the live consumer that receipt reads
`STILL-LIVE ... [receipt 2/2]`, not `CLOSE-CANDIDATE`; the row this file told the executor to
expect never appeared. **`git clone --local` carries COMMITTED state only, so a `verify: sh`
receipt whose predicate reads an untracked or gitignored path gets a different verdict on the
rehearsal copy than on the consumer.** A rehearsal is still worth its cost — it caught five
real things — but a ledger receipt's verdict is not one of the things it can certify.
(The consumer's own log explains the absence as "#916 rotated it out"; that is also wrong —
`PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK` is still open in the live ledger. #916
rotated `PC-S302-ADVERSARY-RECIPE-PRESENT-IS-NOT-RECIPE-RUN`.)

**The pattern across all three: every wrong criterion came from an instrument, not from the
change.** The pull itself did exactly what it claimed.
