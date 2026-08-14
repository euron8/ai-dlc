# Drain the graph consumer's push-candidate ledger — full sweep

## Context

`/Users/n8/git/graph` is the reference consumer. Its
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` is the queue of consumer innovations
upstream lacks and consumer-filed upstream defects. Every prior cycle drained **four entries**
and stopped; the ledger has grown faster than it has been drained. The operator has asked for
the whole thing: adjudicate every open entry against ground truth, remediate what is real, and
give graph a legitimate way to close what is not.

**The instrument that would normally answer "what is still open" cannot answer it right now,
and it says so itself.** graph's own reconcile report for the 0.370.0 → 0.372.0 pull carries
this line, and the same run reproduces from this session:

> `RECEIPTS-UNDECIDED  (theirs_has receipts)  28 of 28 'theirs_has' receipt(s) reported
> STILL-LIVE on a substring present at BASE as well as at theirs (0.372.0) … Do not treat a
> zero CLOSE-CANDIDATE count from this run as evidence that nothing was absorbed.`

So the zero-close reading is not a floor, and the 59 `STILL-LIVE` rows are not findings. Every
entry has to be taken to the working tree by hand. The measured base rate of expired premises
in this corpus is roughly **one in two** — expect about half the ledger to be dead.

## Start here

**Two repos, and the boundary is absolute.**

- **`/Users/n8/git/ai-dlc`** — WRITE. This is where remediations, CHANGELOG citations,
  `docs/backlog.md` entries and the adjudication register land.
- **`/Users/n8/git/graph`** — **READ ONLY.** `.claude/rules/consumer-boundary.md` is
  unconditional: an ai-dlc session never writes to a consumer. Do not edit, commit, or push
  there. Record `git -C /Users/n8/git/graph status --porcelain | wc -l` before the first action
  and assert it after every phase; a change is a stop-and-ping condition.

**The only two channels that reach graph** are (a) a released version of `core/` whose
`CHANGELOG.md` names the entry's `PC-` id **verbatim** — that is the consumer's `NAMED-UPSTREAM`
close signal, and it is a required part of the release, not a courtesy — and (b) a brief the
operator carries into a graph session. Nothing else.

**Never run `ledger-reverify.sh` with the process cwd at the ai-dlc root.** Measured and
recorded at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:927-948`: a distribution-root
run turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false CLOSE is the worst output
this tool has — it retires an entry that is still live. Always `cd /Users/n8/git/graph` first and
pass the **absolute** consumer root:

```
cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc <base-sha> /Users/n8/git/graph <theirs-sha>
```

**Ping the operator** on any question, on any decision, on completion, and on any early stop.
This program runs for many releases; from outside, a session that is thinking and a session that
is waiting on a human look identical. Merges are preapproved — do not stop to ask for one.

## Status record

**This is the only status record in this file.**

**Phase 0 steps 0–1 are COMPLETE.** The corpus pin, taken on the branch
`ai-dlc/graph-ledger-drain` cut from `origin/main` at `b1ee196`:

| pinned quantity | value |
|---|---|
| graph `HEAD` | `510e4d9f50192e85df54b81df7ebc70d53bdb638` |
| graph `git status --porcelain \| wc -l` **baseline** | **35** |
| ledger `md5` | `2fd444dcf406cdff728fe3c0c4352267` (4356 lines) |
| ledger archive `md5` | `8989cb668a33c6c73be429b827d9797f` (4474 lines) |
| ai-dlc `theirs` | `b1ee196`, VERSION `0.372.0` |
| ai-dlc `base` for reverify | `adec9ae` (0.370.0) |

The pinned copies live in the session scratchpad. **Every step from Phase 0 step 3 onward reads
the pin, not the live file** — a graph session is filing into the live ledger concurrently.

**Everything below Phase 0 step 1 is NOT yet executed.** The figures in the two tables that
follow were derived in the planning session against those same refs. **They are hypotheses the
moment either tree moves — re-derive rather than carrying them forward.**

**Two tiers, and only the first is trustworthy.** The upper block is what the shipping
`ledger-reverify.sh` emitted. The lower block comes from parsers written in the planning
session, and one of those parsers produced a finding that has already been shown false.

| from the shipping tool | value |
|---|---|
| distinct entries it emitted a row for | 89 |
| `STILL-LIVE` rows | 59 |
| `HAND-REVIEW` rows (`verify: manual`) | 25 |
| `NAMED-UPSTREAM` (upstream history already cites the id) | 13 |
| `NAMED-UPSTREAM-AMBIGUOUS` (sprint prefix, 2–17 entries each) | 9 |
| `theirs_has` receipts the tool itself calls undecided | **28 of 28** |
| `NEEDS-REVIEW` | 0 |
| `CLOSE-CANDIDATE` | 0 — **and the tool says not to read that as evidence** |

**Control:** these counts reproduce graph's own run, recorded at
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/reconcile-report.md:218-265`, which is the
evidence that the invocation was right and not merely that it ran.

| from a subagent census — **hypotheses until re-derived** | value |
|---|---|
| raw entry starts matched by the boundary rule | 142 |
| section scaffolding, not entries | 18 |
| already closed on the ledger's own annotation grammar | 19 |
| **OPEN** | **93** |
| open entries citing an ai-dlc path that does not exist at HEAD | ~14 |
| of those, `PC-S312-*` entries targeting the **consumer's own forked `scripts/`**, not core | 9 |

**A planning-session parser produced a false finding, and the failure is the useful part.** A
hand-rolled `awk` reported that two section headings had absorbed a `verify:` receipt belonging
to the entry below them. The shipping parser emits **no row for either heading** — control: a
known id returns 2 rows in the same invocation. The tokens that `awk` matched are
`verify: theirs_has` written inside ordinary prose, which reverify's directive parser correctly
ignores and which this ledger's own header already names as a known hazard. **A hand-written
probe is a second implementation whose bugs nobody finds.** Derive the census from the shipping
code, per Phase 0 step 3.

**The two parsers also disagree about the `push_candidate: true` extension bullets** — the
hand-rolled one counted the 12 `extensions/…-push.md` roster rows as entries, the subagent
classified them as scaffolding. The ledger's own header says that whole section was **"owed, not
done"** as of its last full pass, which argues they are entries. Resolve this at Phase 0 step 4
by reading the section, not by picking a parser.

**A live graph session is filing into this ledger while you work.** At planning time there was an
uncommitted 44-line addition (`PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG`) that
is not in graph's `HEAD`. Pin the corpus at Phase 0 and re-derive the delta at Phase 5.

## Verdict vocabulary

Two vocabularies exist and they are not the same. The **machine** statuses
(`STILL-LIVE`, `HAND-REVIEW`, `NEEDS-REVIEW`, `CLOSE-CANDIDATE`, `NAMED-UPSTREAM`,
`NAMED-UPSTREAM-AMBIGUOUS`, `RECEIPTS-UNDECIDED`) are inputs, never verdicts. The **adjudication**
verdict is what this program produces, and it follows the precedent in
`docs/plans/sprint-302-303-push-candidates.md:81-88`:

| verdict | evidence required | disposition |
|---|---|---|
| `HOLDS` | the defect re-derived against the working tree at a named sha, `path:line`, with a control in the same invocation | remediate upstream |
| `HOLDS-WIDER` | as above, plus what the filing understates | remediate at the true scope |
| `HOLDS-MECHANISM-WRONG` | as above, plus the filing's stated cause or consequence shown false | remediate the real defect; record the correction |
| `ALREADY-FIXED (vX.Y.Z)` | the release that fixed it, named, with the fix read in the tree — **not** from the CHANGELOG | close by CHANGELOG citation |
| `FALSIFIED` | the premise shown false in the tree, with a control | close by CHANGELOG refutation |
| `DUPLICATE-OF <id>` | both bodies read; the surviving id named | close by CHANGELOG citation of the dropped id |
| `NOT-UPSTREAM` | no upstream grain fits; consumer-local by nature | brief only, no upstream work |

**Adjudicate the MECHANISM, not the claim.** A defect can be real while the filing's stated cause
and consequence are both false, and the last cycle found three of four filings materially wrong
about why. **Do not trust the filing's prescribed fix** — one of them was itself broken.

## Phases

### Phase 0 — promote this file, then pin the corpus

0. ~~Promote this plan and commit it.~~ **DONE** — this file is the promoted copy.
1. ~~Pin the corpus and record the consumer baseline.~~ **DONE** — see the status record above.
2. Re-run `ledger-reverify.sh` from the graph root as shown in **Start here**, base `adec9ae`,
   theirs = current ai-dlc `origin/main`. **Control:** the row counts must reproduce graph's own
   `_bmad-output/ai-dlc-update/reconcile-report.md:218-265`. They did in planning; a divergence
   means the corpus moved and Phase 0 restarts.
3. Derive the open-entry census **from the shipping code, never from a fresh parser.** Source
   `ledger_entry_awk()` from `core/skills/ai-dlc-update/reconcile/lib.sh:274` for the boundary
   rule, and reuse `ledger-reverify.sh`'s own close predicate `entry_line_closes()`
   (`:629-631`) and its directive parser rather than restating either. The planning session
   restated them and produced a false finding within the hour. Run every `awk` under `LC_ALL=C`;
   the ledger is full of em-dashes and a byte-truncating `substr` aborts the program mid-file.
4. Reconcile the census against the tool's 89 emitted rows and **account for the difference by
   name**. The residual is the set of entries the closer cannot see at all — the ones with no
   directive — and that set is the real reason a zero-close reading means nothing. Section
   headings that are not entries belong in the residual too; classify them explicitly rather
   than letting them inflate the count.

### Phase 1 — adjudicate every open entry (subagent fan-out)

5. Partition the open entries by the ai-dlc subsystem they target. A planning-session census
   produced this split — **re-derive it, do not trust it**:

   | subsystem | entries |
   |---|---|
   | reconcile machinery (`core/skills/ai-dlc-update/reconcile/*`) | 26 |
   | `core/scripts` validators | 20 (+3 filed under pre-relocation paths) |
   | `core/skills/ai-dlc` rules and steps | 21 |
   | consumer-local `scripts/` — the `PC-S312-*` retirement probes | 9 |
   | `core/git-hooks` and `core/hooks` | 7 |
   | `ai-dlc-update` SKILL.md and steps | 5 |
   | `core/fixtures` | 2 |
   | role files and templates | 2 |

   Batch at **~4 entries per subagent**, one subsystem per batch so a subagent reads one area.

5a. **Take the cheap closes first.** ~14 open entries cite an ai-dlc path that does not exist at
   HEAD, and they split two ways. Nine `PC-S312-*` entries cite the **consumer's own forked**
   `scripts/check-*.sh`, `scripts/lib/pr-class.sh`, `scripts/tests/**` — none of which core has
   ever shipped — so they are `NOT-UPSTREAM` by construction. The rest are **stale path forms,
   not dead entries**: `core/.claude/skills/…/retro.md`, `core/scripts/ai-dlc/…`,
   `tests/fixtures/…` are all pre-relocation spellings of live files, and an entry whose subject
   moved needs a repoint, **not** a close. Do not conflate the two — a close on a repointable
   entry is the data-losing direction.

5b. **Two receipts are green for the wrong reason and must not be read as passes.**
   `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` and `PC-S297-FFCLUSTER-SHA-STALE` both
   carry `verify: sh ! git cat-file -e <path>`, and both paths are absent from core, so the
   receipt exits 0 on absence rather than on a fix. `PC-S296-H1-FIXTURE-CITATION-GAP` greps for
   the literal `tests/fixtures/check-3b-locked-anchor` in a tree that relocated to
   `core/fixtures/` — it can never match. Verify each against the tree before verdicting.

5c. **One open entry has no heading and no id** (around ledger line 2028): its title was absorbed
   into a fenced block that opens mid-entry, so `ledger-reverify.sh` cannot join it to anything.
   That is a live instance of the `ENTRY-SWALLOWED` class the ledger itself documents. Adjudicate
   its body like any other entry, and record the parser instance in the register.
6. **Spawn one adjudication subagent per batch, in parallel, in a single message.** Each returns
   one verdict row per entry: id, verdict, `path:line` evidence, the control run in the same
   invocation, and what the filing got wrong and in which direction. Give every subagent the
   verdict vocabulary above and the `consumer-boundary` prohibition verbatim.
7. **Every `ALREADY-FIXED`, `FALSIFIED` and `DUPLICATE-OF` verdict gets a second, independent
   verifier subagent whose brief is to REFUTE the close.** Those three are the data-losing
   direction: a false close retires a live defect and reads exactly like an ordinary absorption.
   `HOLDS` verdicts need no second pass — the cost of a false HOLDS is wasted work, not lost work.
8. Write the register to `docs/reviews/graph-ledger-full-adjudication.md`. One row per open
   entry, no exceptions — a missing row is indistinguishable from an entry nobody looked at.
9. The `push_candidate: true` extension blocks have **never been re-derived** since 2026-07-21.
   The ledger's own header says so — *"Owed, not done in this pass"* — and says why
   `layer-drift.sh` cannot answer the absorption question for them: its `EXTENSION-OK` arm
   compares only `base..theirs`, so a block absorbed several releases ago reports OK. Adjudicate
   them per block against core at HEAD like any other entry. **Do not use `layer-drift.sh` as the
   oracle** — that is the same check-cannot-fire trap this pass exists to find.

### Phase 2 — the close release

10. One release. `VERSION` bump, matching commit subject, one `## [X.Y.Z]` CHANGELOG heading, and
    **one `###` section per closed id, each naming the `PC-` id verbatim.** Arm C of
    `scripts/validate-release-version.sh` limits a push range to one version *heading*, not one
    section, so every close in the program can ship in this single release.
11. Include the `NAMED-UPSTREAM` set. Read each named commit and decide absorbed vs. rejected vs.
    split vs. passing mention — the tool's own header records that the author of that status got
    all four wrong in the release that shipped it, so this is a reading, not a lookup. Re-cite the
    confirmed ones so graph gets a current, unambiguous row. Resolve the
    `NAMED-UPSTREAM-AMBIGUOUS` prefixes the same way, per entry.
12. Land the accepted-but-not-yet-shipped `HOLDS` entries into `docs/backlog.md` as `BL-` entries
    in the same release, so nothing is carried only in a plan. That file's grammar and receipt
    verbs (`sh` / `has` / `lacks`, never `theirs_*`) are stated in its own header at
    `docs/backlog.md:19-40`.

### Phase 3 — remediation releases

13. Group the `HOLDS` set by subsystem into batches of **≤4 remediations per release branch**.
    One version per branch, cut from `origin/main` — a squash of two takes the first version in
    the subject and breaks the release triple. Expect **many** branches; the operator has asked
    for the full sweep, so keep cutting them until the `HOLDS` set is empty.
14. Per batch: **one subagent drafts each remediation, and a different subagent authors its
    fixture.** `.claude/rules/fixture-mutants.md` requires the fixture's author be a different
    hand from the arm's — an arm and a battery from one hand encode one understanding twice and a
    false pass has an unreachable half nobody sees. The last cycle recorded a self-authored arm
    that passed against its own mutant; do not repeat it.
15. Gate each branch with `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` and read every
    changed fixture **by name** in the full output, against an impossible-name control in the same
    invocation. `core/git-hooks/pre-push` is the consumer's hook and prints a green banner having
    run almost nothing; the content-key skip prints one too.
16. Each remediation gets its own `###` CHANGELOG section naming its `PC-` id verbatim.

### Phase 4 — the consumer brief

17. Write `docs/reviews/graph-ledger-adjudication-brief.md`. Per entry: the verdict, the evidence,
    and **either** the exact annotation string to paste —
    `**ADOPTED UPSTREAM (vX.Y.Z, verified <date>)**`, bolded, version immediately after the
    parenthesis — **or** the exact replacement `verify:` receipt.
18. The annotation form is load-bearing in two directions: *any* occurrence of the phrase makes
    `ledger-reverify.sh` skip the entry, but only the strict form lets `ledger-rotate.sh` archive
    it. A sloppy annotation makes an entry invisible **and** unarchivable. Render the exact string
    per entry; do not describe it.
19. For each of the 28 undecided `theirs_has` receipts, derive a replacement anchored on a token
    the fix **must remove** — a flag, a path, a function name — never prose describing the fix.
    Prefer converting to an `sh` predicate scoped to the span the claim is about; a file-wide
    substring cannot express "Check 5 does not consult the gate log". For every open entry the
    Phase 0 residual showed carries no directive at all, supply a receipt, or `verify: manual`
    with the reason it has no mechanical predicate.
20. Deliver the brief to the operator. **Do not apply it.** graph applies it in its own session.

### Phase 5 — close out

21. Re-run `ledger-reverify.sh` from the graph root against the new ai-dlc `origin/main`.
    **Observation point: before graph applies any annotation from the brief** — an annotated entry
    is skipped and emits no row, so this criterion is unreachable afterwards.
22. Re-derive the ledger delta against the Phase 0 pin. Entries graph filed during the run are new
    work; adjudicate them or hand them to the operator explicitly. Do not report completion over
    them silently.
23. Report to the operator: what shipped, what was closed and how, what graph must do, and
    anything left undone with the reason.

## Done when

Each of these is a command, and each was checked to be answerable at the point it is read.

1. `docs/reviews/graph-ledger-full-adjudication.md` carries one verdict row per open entry, and
   the row count equals the Phase 0 open-entry count **derived in the same invocation**.
2. Every id adjudicated `ALREADY-FIXED`, `FALSIFIED`, `DUPLICATE-OF`, or remediated appears
   **verbatim** in `CHANGELOG.md`. Control in the same invocation: an impossible id returns 0
   while a known-cited id returns non-zero.
3. `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` is green on every release branch, with each
   changed fixture read by name against an impossible-name control.
4. `git -C /Users/n8/git/graph status --porcelain | wc -l` equals the Phase 0 baseline.
5. The Phase 5 `ledger-reverify.sh` run emits a `NAMED-UPSTREAM` row for every id this program
   cited. It joins on the full slug, so each is unambiguous and none degrades to
   `NAMED-UPSTREAM-AMBIGUOUS`.
6. The `HOLDS` set is empty — every entry is either remediated and cited, or filed as a `BL-`
   entry in `docs/backlog.md`.

## Hazards

- **A false CLOSE is the worst output in this system.** It retires a live defect and is
  indistinguishable from an ordinary absorption. That is why every close verdict carries a second
  refuting verifier.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, unquoted `$var` is not word-split, and `:c`/`:t`
  eat unbraced rev-path references — always `"${sha}:core/…"`. Force `bash -c` for any loop or
  heredoc. Never feed `grep -q` from a pipe: it exits at first match and `pipefail` turns the
  writer's EPIPE into a false NOT-FOUND on large files, which this ledger is.
- **Run `awk` over the ledger under `LC_ALL=C`.** Measured in planning: a multibyte em-dash aborted
  an `awk` mid-file with `towc: multibyte conversion failure`.
- **`bash` is 3.2.** No `mapfile`, `readarray`, `declare -A`, `setsid`; an empty array under `set -u`
  is an error.
- **A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation
  that comes back non-zero, and both are reported.
- **The consumer runs its own installed engine.** Fixing `ledger-reverify.sh` here does not help
  graph until graph pulls. Run the fixed copy locally against graph's ledger for this program's
  own use, but the brief must be actionable under the engine graph has installed today.
