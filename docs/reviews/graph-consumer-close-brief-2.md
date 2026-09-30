# BRIEF — close thirteen push candidates upstream already fixed

**For the operator to carry into a graph session.** This is not a runbook and it authorizes no
pull. It asks the graph session to do one thing: annotate thirteen entries in its own
push-candidate ledger as adopted upstream, then rotate them to the archive. Nothing here was
written to graph; every graph figure below was read with read-only commands or measured on a
`file://` clone of graph.

## Start here

- **The session's project root is `/Users/n8/git/graph`.** Every command below runs there.
- **The ledger is `_bmad-output/ai-dlc-update/push-candidate-ledger.md`.** Line numbers below are
  at graph's carry-over branch commit `3326caca` (`ai-dlc/carry-over/phase-315-aggregator-ui-cutover`),
  with the installed engine at 0.667.0 (`.claude/.ai-dlc-version`). If the file has moved, find
  each entry by its `## PC-…` heading, not by line.
- **Edit only the thirteen entries named below.** Do not reword their bodies, do not delete them,
  and do not touch any other entry. A close is an annotation line, never a deletion.
- **PING THE OPERATOR** before step 4 (`--apply`) and on completion. Report which ids archived and
  which did not.

## Why these thirteen close: each fix is in the engine graph already runs

Every one of the thirteen was fixed upstream and named in a release commit, and every fix is
present in graph's installed 0.667.0 tree. None of the thirteen has a `verify:` receipt except
`PC-S297-…` (see below), so `ledger-reverify.sh` skips them and no pull will ever close them.
They stay live until graph annotates them.

Each close was established by CONTENT, not by a commit message: a token the fix introduced is
present at the named release and absent at the release before it, and present in graph's
installed file. Upstream measurements were taken in the ai-dlc repo at `origin/main` `7a325bb6`;
the installed counts were read from graph's working tree at `3326caca`. An impossible token
(`zq9x-no-such-token-7w`) returned 0 in both trees in the same run.

**Four entries carry an upstream ruling that the annotation states.** Upstream built something
other than the filed remedy for these, so the annotation says what shipped:

- `PC-S309-ADR-DEFERRED-WORK-HAS-NO-CARRIER-INTO-BACKLOG`: the filing's headline is refuted, and
  the narrowed finding is what stands (BL-215).
- `PC-S309-RETRO-CLOSURE-QUOTATION-NOT-VERBATIM-BOUND`: the ellipsis-ban remedy was refuted (BL-216).
- `PC-S314-H2-ATTESTATION-…`: the widen-the-tail remedy was refuted (BL-340).
- `PC-S315-CHECK-15-…`: the `head -1` remedy was refuted (BL-369).

**`PC-S310-GATE-ADJUDICATION-…` closes, and the backfill itself stays graph's.** 0.544.0 shipped
the refusal and the `--legacy-through` escape that make a multi-sprint backfill safe to run. Its
CHANGELOG says the backfill "has not been run on any consumer … running it is the consumer's
call." Running `rotate-gate-adjudication.sh` over the pre-mechanism sprints is graph-local work
with a script graph already has. It is not an upstream request, and this brief does not do it.

**`PC-S297-CHECK17-…` closes because the fix moved Check 17, not Rule 20.** Its STAYS OPEN note
reasons that `rule-20.md` was untouched by `77f5213a`, which is true and beside the point. The
contradiction had two sides. 0.609.0 resolved it on the Check 17 side: `gate-validation.md` gained
a validate-only arm pinned to `<run-folder>/validation-report.md --require-skill bmad-prd`, which
is the artifact Rule 20 places the block in, and it covers `requirements.md` §4 as well. So a
compliant run no longer needs the `prd.md` hand-carry that the entry calls "the actual defect."
The entry's own receipt cannot see this. It asserts only that `rule-20.md` does not name `prd.md`,
and it exits 0 at 0.608.0, at 0.609.0 and at 0.667.0 alike. Upstream BL-042's receipt counts the
Check 17 `--require-skill bmad-prd` arms and requires one not pinned to `prd.md`, and it
discriminates: exit 1 at `77f5213a~1`, exit 0 at `77f5213a` and at `origin/main`. So this is
ADOPTED at v0.609.0. It does not need a re-anchored receipt, because the annotation retires the
receipt. The STAYS OPEN and Re-checked lines stay in the entry as filed; the annotation says they
are superseded.

**Two versions differ from the commit a reader might cite first.**

- `PC-S309-RETRO-CLOSURE-…` is **v0.566.0**. BL-216 says "verified edc30c9c", but that is a branch
  commit whose `VERSION` still reads 0.565.0, and it is not on `main`'s first-parent line. The
  release commit carrying the fix is `4bab02b6` (0.566.0): its `validate-locked-anchor.sh` has
  `carry-over-backlog.md` in `DEFAULT_SOR_BASENAMES`, and `cfa75199` (0.565.0) has 0.
  `60a2beac` (0.567.0) only names the id, in a commit about receipts.
- `PC-S309-VALIDATE-MANDATORY-…` is **v0.542.0**. The release commit `732db5a5` changes only
  `CHANGELOG.md` and `VERSION`, because the fix arrived through the branch commits `7c6d7da4` and
  `e8476f85`. By content: `test-only` occurs 2 times in `validate-mandatory-rules.sh` at `732db5a5`
  and 0 times at `274efdae` (0.541.0).

## The thirteen, and the exact line to add to each

Add the annotation as a **new line directly under the entry's `## PC-…` heading**, after the
blank line that follows the heading, bold, on its own line, exactly as written, with a blank line
after it. `ledger-rotate.sh` archives an entry on a line that opens `**` and reaches `ADOPTED
UPSTREAM` with no backtick in between. None of these lines carries a backtick; do not add one.

| Line | Id | Annotation line to add |
|---|---|---|
| 355 | `PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20-BLOCK-PLACEMENT` | `**ADOPTED UPSTREAM (v0.609.0, verified 2026-09-30) — the fix moved Check 17, not Rule 20: gate-validation.md Check 17 now carries a validate-only arm pinned to the run folder's validation-report.md, the artifact Rule 20 places the block in, so a compliant run no longer needs the prd.md hand-carry. The STAYS OPEN note below reasoned from rule-20.md being untouched and is superseded; the receipt below exits 0 at 0.608.0, 0.609.0 and 0.667.0 alike, so it cannot discriminate. Upstream BL-042.**` |
| 636 | `PC-S309-ADR-DEFERRED-WORK-HAS-NO-CARRIER-INTO-BACKLOG` | `**ADOPTED UPSTREAM (v0.666.0, verified 2026-09-30) — the filing's headline is refuted and the narrowed finding is what stands: requirements.md already mandates the docs/adr grep at intake, and what was missing was a disposition slot. requirements.md and discovery.md now carry deferred-unfiled, and such a hit must be filed as a carry-over backlog item before the gate passes. Upstream BL-215.**` |
| 672 | `PC-S309-RETRO-CLOSURE-QUOTATION-NOT-VERBATIM-BOUND` | `**ADOPTED UPSTREAM (v0.566.0, verified 2026-09-30) — validate-locked-anchor.sh adds carry-over-backlog.md to its byte-verbatim source-of-record set, so a closure condition quoted under full_text_source is byte-compared. The filed ellipsis-ban remedy was refuted upstream as a false negative on this entry's own case; the source-of-record join is what shipped. Upstream BL-216.**` |
| 702 | `PC-S309-VALIDATE-MANDATORY-RULES-CHECK5-TEST-ONLY-WEB-DIFF-FALSE-FAIL` | `**ADOPTED UPSTREAM (v0.542.0, verified 2026-09-30) — validate-mandatory-rules.sh Check 5 SKIPs a web diff whose every member is a test file, with a skip reason that says test-only.**` |
| 751 | `PC-S310-GATE-ADJUDICATION-ROTATION-HAS-NO-BACKFILL-PATH-FOR-PRE-MECHANISM-SPRINTS` | `**ADOPTED UPSTREAM (v0.544.0, verified 2026-09-30) — rotate-gate-adjudication.sh refuses a rotation that would strand a FAILing legacy verdict and ships --legacy-through, the escape that makes a multi-sprint backfill closeable. Running the backfill is graph's own work with the installed script, not an upstream request. Upstream BL-228.**` |
| 849 | `PC-S310-CHECK5-GATE-LOG-HEADER-CONVENTION-UNDOCUMENTED-AND-UNSATISFIABLE` | `**ADOPTED UPSTREAM (v0.548.0, verified 2026-09-30) — gate-validation.md no longer cites the nonexistent CLAUDE.md Autonomous Gate Protocol section and states the Gate Log: Sprint N header inline as Check 5's join key. The has-never-used arm was already stale per the 2026-09-25 correction below. Upstream BL-232.**` |
| 934 | `PC-S310-RETRO-PERSONA-MARKER-VOCABULARY-NOT-DOCUMENTED-IN-STEP-FILE` | `**ADOPTED UPSTREAM (v0.548.0, verified 2026-09-30) — retro.md names PERSONA_MARKERS and PHASE_LABELS in validate-retro-evidence.sh as the lists to read before authoring, and the validator prints the accepted set when a floor fails. Upstream BL-233.**` |
| 996 | `PC-S310-RETRO-STEP6A-COMMIT-LIST-OMITS-AMBIENT-SESSION-LOGS` | `**ADOPTED UPSTREAM (v0.548.0, verified 2026-09-30) — retro.md Step 6a gains an Ambient pipeline state category naming the hook-written files under _bmad-output that a sprint dirties. Upstream BL-233.**` |
| 1066 | `PC-S314-H2-ATTESTATION-PLACEMENT-GRAIN-REJECTS-THE-STEP-FILES-OWN-STYLE` | `**ADOPTED UPSTREAM (v0.648.0, verified 2026-09-30) — --verify now names the line that quotes an attestation instead of calling the gate the sprint's first, and --attest and gate-validation.md H2 state the column-1 placement. The filed widen-the-tail remedy was refuted upstream because every such tail also grants a FAIL sentence. Upstream BL-340.**` |
| 1120 | `PC-S314-ROUTE-STEP6-RATIFIES-PHASE-SPLIT-WITHOUT-DURABLE-BACKLOG-WRITE` | `**ADOPTED UPSTREAM (v0.659.0, verified 2026-09-30) — route.md Step 6 files every deferred part of a confirmed scope, a phase split included, as a carry-over backlog item before leaving the step. Upstream BL-363.**` |
| 1145 | `PC-S314-SPRINT-STATUS-NO-DEFERRED-ACS-MARKER-EXISTENTIAL-ACS-INVISIBLE-AT-DONE` | `**ADOPTED UPSTREAM (v0.659.0, verified 2026-09-30) — sprint-status.json carries a deferred_acs list on the story and sprint-status.sh reads it, so a done story that still owes ACs is distinguishable from a fully closed one. Upstream BL-361.**` |
| 1167 | `PC-S314-DEPLOY-VALIDATE-SMOKE-EVIDENCE-NO-TRANSIENT-PERSISTENT-CLASSIFICATION` | `**ADOPTED UPSTREAM (v0.659.0, verified 2026-09-30) — deploy-validate.md section 3 smoke_run_evidence carries first_run_failures, transient_failures_cleared_on_retry and persistent_failures, and an entry without them fails the gate. Upstream BL-362.**` |
| 1188 | `PC-S315-CHECK-15-BUDGET-EVIDENCE-VERIFIER-READS-OLDEST-ROW-OF-A-NEWEST-FIRST-GATE-LOG` | `**ADOPTED UPSTREAM (v0.662.0, verified 2026-09-30) — validate-artifact-budget.sh --check-evidence selects the newest gate's Check 14 row by heading timestamp, never by position. The filed head -1 remedy was refuted upstream: this repo's committed s312 to s314 logs append oldest-first. Upstream BL-369.**` |

## The evidence, one command per id

The first column runs in graph's own tree and is the check the session can repeat. The last two
columns ran in the ai-dlc repo as `git show "<sha>:<core path>" | grep -cF '<token>'`, at the
release that names the fix and at the release before it.

| Id (short) | Command in graph (count at `3326caca`) | At release | At prior release |
|---|---|---|---|
| S297-CHECK17 | `grep -cF 'validation-report.md --require-skill bmad-prd' .claude/skills/ai-dlc/steps/gate-validation.md` → 1 | 0.609.0 `77f5213a`: 1 | 0.608.0: 0 |
| S309-ADR-DEFERRED | `grep -cF 'deferred-unfiled' .claude/skills/ai-dlc/steps/requirements.md` → 2 | 0.666.0 `d41d47d0`: 2 | 0.665.0: 0 |
| S309-RETRO-CLOSURE | `grep -cF '"product-brief.md", "carry-over-backlog.md")' scripts/ai-dlc/validate-locked-anchor.sh` → 1 | 0.566.0 `4bab02b6`: 1 | 0.565.0 `cfa75199`: 0 |
| S309-VALIDATE-MANDATORY | `grep -cF 'test-only' scripts/ai-dlc/validate-mandatory-rules.sh` → 2 | 0.542.0 `732db5a5`: 2 | 0.541.0 `274efdae`: 0 |
| S310-GATE-ADJUDICATION | `grep -cF -- '--legacy-through' scripts/ai-dlc/rotate-gate-adjudication.sh` → 16 | 0.544.0 `5b829554`: 16 | 0.543.0: 0 |
| S310-CHECK5-GATE-LOG | `grep -cF 'MACHINE JOIN KEY' .claude/skills/ai-dlc/steps/gate-validation.md` → 1; `grep -cF 'format defined in CLAUDE.md Autonomous Gate Protocol'` same file → 0 | 0.548.0 `e26a1c7b`: 1 and 0 | 0.547.0: 0 and 1 |
| S310-RETRO-PERSONA | `grep -cF 'PERSONA_MARKERS' .claude/skills/ai-dlc/steps/retro.md` → 1 | 0.548.0 `e26a1c7b`: 1 | 0.547.0: 0 |
| S310-RETRO-STEP6A | `grep -cF 'Ambient pipeline state' .claude/skills/ai-dlc/steps/retro.md` → 1 | 0.548.0 `e26a1c7b`: 1 | 0.547.0: 0 |
| S314-H2-ATTESTATION | `grep -cF 'QUOTES an H2_ATTESTED span' scripts/ai-dlc/validate-h2-attestation.sh` → 1 | 0.648.0 `6af89fd1`: 1 | 0.647.0: 0 |
| S314-ROUTE-STEP6 | `grep -cF 'File every deferred part of the ask BEFORE leaving Step 6' .claude/skills/ai-dlc/steps/route.md` → 1 | 0.659.0 `87043915`: 1 | 0.658.0: 0 |
| S314-SPRINT-STATUS | `grep -cF 'deferred_acs' .claude/schemas/sprint-status.json` → 8 | 0.659.0 `87043915`: 8 | 0.658.0: 0 |
| S314-DEPLOY-VALIDATE | `grep -cF 'transient_failures_cleared_on_retry' .claude/skills/ai-dlc/steps/deploy-validate.md` → 1 | 0.659.0 `87043915`: 1 | 0.658.0: 0 |
| S315-CHECK-15 | `grep -cF 'audit the NEWEST gate' scripts/ai-dlc/validate-artifact-budget.sh` → 1 | 0.662.0 `9b84f6f6`: 1 | 0.661.0: 0 |

Each upstream BL receipt was also run from a `git archive` of each tree. Ten discriminate (exit 0
at the release, exit 1 at the release before, exit 0 at `origin/main`): BL-232, BL-233, BL-216,
BL-340, BL-361, BL-362, BL-363, BL-369, BL-215 and BL-042. BL-228's receipt exits 0 at 0.543.0 as
well, so it cannot discriminate, and the `--legacy-through` count above is that row's evidence.

## Steps

1. Add the thirteen annotation lines above, each on its own line with a blank line above and
   below it. Nothing else in the file changes.
2. Dry run, which writes nothing. The rotator has no `--check` flag: `--check` exits 2 with
   `unknown argument '--check'`. The default invocation IS the dry run:

   ```
   cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-rotate.sh \
     _bmad-output/ai-dlc-update/push-candidate-ledger.md
   ```

   Expect `13 closed entries would move (653 of 1284 lines, leaving 631).` and exactly the
   thirteen ids in its move list. **If the count is not 13, or the list names any id not in this
   brief, or any of the thirteen appears under `CLOSED … but NOT archivable`, stop and ping the
   operator.** Do not reword a line to make it pass.
3. **Ping the operator with the dry-run move list.**
4. Re-run the same command with `--apply` appended. Expect `moved 13 closed entries (653 lines)`
   and `ledger is now 631 lines.` If the moved count differs from 13, stop and ping.
5. Verify, and report these numbers to the operator: the live ledger's `^#{2,6} PC-` heading
   count fell from 16 to 3, the archive's rose by 13, and the thirteen ids are present in
   `push-candidate-ledger.archive.md`. The three remaining entries
   (`PC-S315-AUDIT-LAYER-DEBT-…`, `PC-S315-ARTIFACT-WRITE-LEDGER-…`, `PC-S315-NO-AMENDMENT-PATH-…`)
   stay live. A second dry run reports `0 closed entries`. The rotator's output tells you to
   check that `ledger-reverify.sh` emits the same row set. Compare the ANNOTATED ledger with the
   rotated one; both give the same 15 rows. The pristine ledger gives 17, and the two rows that
   go, both `PC-S297-…`, disappear when you annotate, not when you rotate. That drop is the close,
   not a sweep. Any other row that appears, disappears or changes status is a sweep: stop and ping.
6. Commit on graph's current branch with graph's own commit conventions. Upstream does not push
   anything to graph and does not need a reply beyond the operator's report.

## What the rehearsal measured

This was rehearsed on a `git clone --no-hardlinks file:///Users/n8/git/graph` at `3326caca`, with
graph's installed rotator. Its `ledger-rotate.sh` and `lib.sh` are byte-identical to upstream's
0.667.0 copies, and the clone's ledger is byte-identical to graph's live one.

- **Baseline, before annotating:** `0 closed entries — nothing to rotate (1258 lines stay).`
  So nothing else in the ledger is already movable, and the expectation is exactly 13.
- **After annotating the thirteen:** dry run and `--apply` each moved 13, those listed above. The
  live heading ids went from 16 to 3. The removed set and the archive's added set each equal the
  thirteen annotated ids (`cmp` exit 0 on both), and no id was added to the live ledger.
- **Nothing else moved.** The post-apply ledger is byte-identical to the annotated ledger with
  those thirteen entry ranges deleted (`cmp` exit 0, fence-aware). The archive's original bytes
  are an unchanged prefix of the new archive (`cmp` exit 0). All thirteen annotation lines are in
  the appended text, and the two bullet-form entries are unchanged.
- **Re-verification row set:** `ledger-reverify.sh` on the annotated ledger and on the rotated
  ledger emits the same 15 rows (`cut -f1,2 | sort`, `cmp` exit 0). Annotating drops the two
  `PC-S297-…` rows (`NAMED-UPSTREAM`, `STILL-LIVE`) from 17 to 15, and that drop is the close.
  Rotating afterwards moves no row.
