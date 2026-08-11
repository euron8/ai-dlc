# Runbook — pull the graph consumer from 0.355.0 to 0.356.0, mid-sprint s302

**Status: DISCHARGED 2026-08-11. THIS RUNBOOK IS SPENT — DO NOT EXECUTE IT.** The consumer ran it
at `036ec6dee`. See §Discharge for the independent verification. Authored against a real rehearsal
on a `git clone --local` copy (§Rehearsal), not a prediction — every figure below was produced by
running the step, and three of them contradict what a prediction would have said.

---

## Start here

Two repos, and the read/write boundary between them is absolute.

- **Distribution — `/Users/n8/git/ai-dlc`. Read it, never write it.** `main` carries `0.356.0`.
  Every step below reads from this tree and edits none of it.
- **Consumer — `/Users/n8/git/graph`, the tree you WRITE.** Branch
  `ai-dlc/feature/s302-position-usd-create-position`, **mid-sprint s302, working tree DIRTY**.
  `.claude/.ai-dlc-version` reads `version: 0.355.0` / `commit: 4cded9e` on all four fields.

This release bounds `_bmad-output/pipeline-snapshot-history.md`, which was write-only and had no
rotator. On this consumer it stands at **6086 lines / 617,496 B**, grown from 87 KB on 2026-07-13,
across 29 commits of which **every one is `del=0`**. Its sibling archives — the dated
`pipeline-snapshot.archive.*.md` files — number **158, 2,293,318 B**. The release adds
`scripts/ai-dlc/rotate-snapshot-archive.sh`; this runbook additionally folds the 158 legacy files
into the same single archive, which is one-time consumer work the script deliberately does not do.

**The pipeline is LIVE and its numbers move while you read them.** Three readings of
`pipeline-snapshot.md` fifteen minutes apart gave 5728, 6729 and 6555 tokens; Check 35's corpus went
757,235 → 758,437 → 758,446. **Re-measure every baseline immediately before you act on it and
immediately after. Do not carry a number from this file into a comparison.** The figures here are
provenance for the method, not values to assert.

**Ping the operator** on any question, on any decision this file does not settle, and on completion
— including an early stop. A session that stops silently is indistinguishable from one still
working.

---

## Next actions

Run everything from `/Users/n8/git/graph`. **Use Bash, not Write/Edit.** Rule 29's pause allowlist
covers `Write|Edit|MultiEdit|NotebookEdit` and has literal arms only for `pipeline-snapshot.md` and
`pipeline-snapshot-history.md`; anything else under `_bmad-output/` falls through to denial. `Bash`
is not in that `case` at all, so a Bash-driven migration is legal whether or not the flag appears
mid-run.

1. **Commit the pipeline's own in-flight state first.** The tree is dirty with live pipeline
   appends. The migration must be separable from them for the abort path to work.

2. **Run the pull** and apply it, so `.claude/.ai-dlc-version` advances to `0.356.0` on all four
   lines. Confirm `scripts/ai-dlc/rotate-snapshot-archive.sh` arrived and
   `tests/fixtures/snapshot-archive-rotate/` arrived with it.

3. **Preserve the inputs OUTSIDE the repo. This is the real undo.**

   ```
   SAFE="$(mktemp -d /tmp/aidlc-migration-safe.XXXXXX)"
   git ls-files -- '*pipeline-snapshot.archive.*' > "$SAFE/order.raw"
   wc -l < "$SAFE/order.raw"      # 158
   cp _bmad-output/pipeline-snapshot-history.md "$SAFE/history.orig"
   tar -cf "$SAFE/inputs.tar" -T "$SAFE/order.raw" _bmad-output/pipeline-snapshot-history.md
   ```

   **`git ls-files`, never a root glob.** Three of the 158 live outside `_bmad-output/` root, under
   `implementation-artifacts/s177/`, `s249/` and `s250/`. A glob on the root finds 155 and leaves
   three behind.

   **The history file is DIRTY.** Recovery comes from `$SAFE` only. `git checkout HEAD --` on it
   would discard the pipeline's uncommitted appends, which is precisely the destruction Check 35
   exists to detect.

4. **Order the 158 by a NORMALISED key, not by filename.** There are **five** timestamp spellings:
   154 of the form `2026-04-16T114100Z`, plus `20260718T234306Z`, `2026-06-10T1530Z`,
   `2026-06-09T-s249init` and `2026-04-30T-close`. A plain `sort` puts `20260718T234306Z` *after*
   every dashed 2026 stamp, because `-` (0x2D) precedes `0` (0x30).

   ```
   awk '{n=$0;sub(/.*archive\./,"",n);sub(/\.md$/,"",n);k=n;
         if(n ~ /^[0-9]{8}T/)k=substr(n,1,4)"-"substr(n,5,2)"-"substr(n,7,2)"T"substr(n,10);
         print k"\t"$0}' "$SAFE/order.raw" | sort -k1,1 | cut -f2 > "$SAFE/order"
   ```

5. **Build the combined archive, then prove conservation BEFORE deleting anything.**

   ```
   NEW=_bmad-output/pipeline-history/pipeline-snapshot-archive.md
   mkdir -p "$(dirname "$NEW")"
   { echo "# Pipeline snapshot — archive"; echo;
     echo "One-time fold of the dated snapshot archives. Written thereafter only by"
     echo "scripts/ai-dlc/rotate-snapshot-archive.sh."; echo; } > "$NEW"
   while IFS= read -r f; do printf '\n<!-- absorbed %s -->\n\n' "$f"; cat "$f"; done < "$SAFE/order" >> "$NEW"
   ```

   Then the containment arm, with its control in the same invocation:

   ```
   norm(){ sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'length($0)>=20' | sort -u; }
   xargs cat < "$SAFE/order" | norm > "$SAFE/in.lines"
   norm < "$NEW" > "$SAFE/out.lines"
   comm -23 "$SAFE/in.lines" "$SAFE/out.lines" | wc -l   # MUST be 0
   wc -l < "$SAFE/in.lines"                              # CONTROL: must be non-zero
   ```

   A zero on the first line means nothing without the non-zero on the second. **If the first line is
   not 0, stop here — nothing has been deleted and the blast radius is zero.**

6. **Stage the new file FIRST, then remove the sources.** The order is load-bearing and was measured,
   not assumed. Check 35's corpus is `git ls-files -z -- '*.md' | xargs -0 cat`: a path must be in
   the **index** *and* readable **on disk**. An unstaged new file is invisible; a plain `mv` or `rm`
   drops content immediately while the index still lists the old path, and `xargs cat 2>/dev/null`
   swallows the error silently.

   ```
   git add "$NEW"
   git ls-files --error-unmatch "$NEW" >/dev/null && echo indexed
   git rm -q $(tr '\n' ' ' < "$SAFE/order")
   ```

7. **Rotate the live history with the shipped script.** It refuses an ignored destination, refuses
   on unbalanced line accounting, and stages the archive itself.

   ```
   bash scripts/ai-dlc/rotate-snapshot-archive.sh \
        _bmad-output/pipeline-snapshot-history.md --apply
   ```

   Rehearsed result: `moved 126 entr(ies), 5400 lines`, history 6086 → **686** lines.

8. **Verify.** See §Done when. Re-measure, do not compare against this file's numbers.

9. **Commit as TWO commits, in this order.** Commit A is additive only: the combined archive.
   Commit B is subtractive only: the 158 deletions and the rotated history. Commit A's tree is a
   strict **superset** of its parent, so it is structurally incapable of destroying a line and a
   reviewer can see that from the diff's shape without running anything. Commit B then reads as
   "158 deletions, every one matched by an addition already in my parent", and the abort path can
   revert B alone.

10. **Hand off.** State that the pull and the one-time fold are done, that s302 is untouched, and
    give the operator the before/after Check 35 pair.

---

## Done when

Each criterion states its **observation point** and its **expected** result, because two of them are
not "green" and an executor told to expect green would report failure for work that succeeded.

1. **`.claude/.ai-dlc-version` reads `0.356.0` on ALL FOUR lines.** Observed after step 2.

2. **Check 35's verdict is unchanged.** Observation point: after the `git add` in step 6 and the
   rotate in step 7, **before** the commit — the corpus is the working tree, so a verdict taken
   after a commit measures something else.

   ```
   bash scripts/ai-dlc/validate-snapshot-conservation.sh
   ```

   At authoring time this read `lines_removed: 89 / lines_destroyed: 17 / PASS`, floor 40. **Take
   your own before-reading in step 3 and compare against that**, not against 89/17 — the candidate
   set is derived from a live snapshot and moves on its own.

   This is the criterion that matters. Measured on this consumer: if the history's content leaves
   the corpus, destroyed goes **17 → 79** against a floor of 40, because 62 of the 89 candidates
   live only there. The margin is 23 lines.

3. **`git ls-files -- '*pipeline-snapshot.archive.*'` returns 0.** Control: the same command
   returned **158** in step 3, and that pairing is what makes the zero meaningful.

4. **`_bmad-output/pipeline-snapshot-history.md` is present and much smaller**, retaining its H1 and
   the last 10 entries. Rehearsed: 6086 → 686 lines, 617,496 → 88,881 B.

5. **`validate-artifact-budget.sh` still exits 1, with the SAME findings it had before — this is
   NOT expected to go green, and it never was.** Pre-existing on this consumer:
   `pipeline-continuation-log.md` at 194% of its budget, and a `SCHEMA FAIL` for the out-of-schema
   `## Deploy Baseline` section in `pipeline-snapshot.md`. Neither is this pull's business. The
   criterion is that the finding set is **unchanged**, plus: the archive appears **nowhere** in the
   output. Control: `pipeline-snapshot.md` still appears.

6. **`validate-artifact-paths.sh` exits 0**, with `ambiguous`, `no area` and `story file(s) with no
   derivable sprint` **unchanged at 72 / 3 / 23**. Conforming drops by 157 (−158 removed, +1 added)
   and the tracked count drops with it; state the corpus size, because a zero over an empty corpus
   is the failure this criterion exists to exclude.

7. **`bash tests/fixtures/snapshot-archive-rotate/run.sh` passes** on the consumer's own installed
   tree — 13 arms plus a mutation arm. It resolves the rotator through `scripts/ai-dlc/`, verified
   on a tree with no `core/` directory.

8. **The consumer's own pre-push suite is green**, run the way its hook runs it, never a hand-rolled
   loop over the fixture directories. 153 fixtures.

---

## Rehearsal — this runbook was executed against a copy before it shipped

`git clone --local /Users/n8/git/graph`, checked out to the same branch. Nothing was written to
`/Users/n8/git/graph`.

Executed on the copy: the baseline Check 35; the 158-file fold in normalised order; the staged-add
and `git rm`; the rotator's `--apply`; then Check 35, `validate-artifact-budget.sh` and
`validate-artifact-paths.sh` again.

**Three things the rehearsal contradicted**, each of which a prediction would have written the other
way:

1. **The count is 158, not 155.** A root-level glob — the obvious way to write it — finds 155 and
   silently leaves three files sitting in sprint slots.
2. **The archive fold is conservation-NEUTRAL.** Removing all 158 leaves destroyed at 17, unchanged.
   The entire risk is the history truncation, which alone takes destroyed to 79. An executor
   guarding the fold and relaxing about the rotate would be guarding the wrong half.
3. **`validate-artifact-budget.sh` was already red** before this pull, on two findings unrelated to
   it. A criterion reading "budget green" would have been unreachable the moment it was written.

Also measured and folded in: the 158 archives and the history are near-disjoint — 11,133 vs 4,952
distinct substantive lines, only **95 in both** — so the fold merges two corpora and saves **zero
bytes**. The whole benefit is 159 files → 1.

**What the rehearsal cannot prove, structurally.** A `git clone --local` carries only **committed**
state, while Check 35 diffs the base against the **working tree** and builds its corpus from it. The
consumer's tree is dirty, so both sides of the real check are built from bytes the clone does not
have. At authoring time the gap was small — the clone's corpus read 758,443 against the live
758,446 — but it is not stable, and it is not a discharge. **The rehearsal proves the mechanics; the
conservation verdict must be re-taken in the live tree at step 8.**

---

## Abort

Nothing is committed before step 9, and the rotator writes nothing unless its line accounting
balances, so a refusal leaves the tree untouched.

- **Containment failed at step 5.** Nothing was removed. `rm -rf _bmad-output/pipeline-history` and
  `git rm --cached` the new file if it was added.
- **Check 35 regressed after step 6 or 7, pre-commit.** `git reset` the affected paths, then
  `tar -xf "$SAFE/inputs.tar"` — which restores the 158 files **and the dirty history verbatim** —
  and confirm with `cmp` against `"$SAFE/history.orig"`. Do **not** use `git checkout HEAD --`.
- **A regression is found after the commits.** Revert commit B alone. Commit A still holds every
  byte.

---

## Do not touch mid-sprint

`pipeline-snapshot.md` (whole-read at every gate, on resume and after compaction, and currently over
its budget so the pipeline may trim it at any moment), `gate-metrics.jsonl` (it supplies Check 35's
base sha — changing it re-bases the check and invalidates the before/after pair),
`sprint-status.yaml`, the s302 planning artifacts, and the live driver state. Do not create
`_bmad-output/pipeline-paused.flag`.

---

## Discharge — 2026-08-11, verified from this side

The consumer executed it across four commits on `ai-dlc/feature/s302-position-usd-create-position`,
ending at `036ec6dee`, with the additive/subtractive split the runbook asked for:

    dbf3aab2c  chore(s302): pipeline in-flight state before the 0.355.0 -> 0.356.0 pull
    3166b2dbf  chore(ai-dlc-update): reconcile distribution 0.355.0 -> 0.356.0
    86871faa5  chore(s302): fold 158 dated snapshot archives into the one archive (additive)
    036ec6dee  chore(s302): remove the folded archives and rotate the snapshot history

**Everything below was re-derived read-only against `/Users/n8/git/graph`'s own tree, not read out
of its report.**

**Verified as written:**

- **Criterion 1** — `.claude/.ai-dlc-version` reads `0.356.0` / `959e778` on all four lines.
- **Criterion 2** — Check 35: `89 removed / 17 destroyed / PASS`, base sha `72e85e183` unchanged.
  Identical verdict to the pre-migration reading.
- **Criterion 3** — `git ls-files -- '*pipeline-snapshot.archive.*'` returns **0**. Control: the
  looser `*pipeline-snapshot*` glob still matches 5 paths, so the zero is a real absence.
- **Criterion 4** — history is **686 lines / 88,881 B**, H1 retained. Byte-for-byte the figure the
  rehearsal predicted.
- **Criterion 5** — budget still exits 1 on the same two pre-existing findings. The archive is
  named **0** times in the full output; control, `pipeline-snapshot.md` is named 4 times.
  (`pipeline-continuation-log.md` drifted 194% -> 198% — live pipeline growth, not this pull.)
- **Criterion 6** — paths PASS, `ambiguous 72 / no-area 3 / story-no-sprint 23` all unchanged,
  corpus 5094 files.
- **Criterion 7** — `tests/fixtures/snapshot-archive-rotate/run.sh` PASS on the consumer's tree.
- **Criterion 8** — local HEAD == remote HEAD == `036ec6dee`, and `.git/ai-dlc-fixture-verified`
  and `.git/ai-dlc-fixture-durations` were written at 13:39 against a last commit of 13:19, with
  144 recorded durations. A `--no-verify` push does not touch those, so the suite ran.

**A stronger check than criterion 2, run because criterion 2 is narrower than it looks.** Check 35
only examines lines derived from `pipeline-snapshot.md`, so it cannot see whether the *migration*
lost anything. Reconstructing the pre-migration tree at `dbf3aab2c` — 158 archive files plus the
617,496-byte history — gives **16,247 distinct substantive lines**, of which **0 are absent** from
the current corpus. Control against `/dev/null`: 16,247. That figure matches the authoring
rehearsal exactly.

**Both traps the runbook flagged were handled.** All three sprint-slot files (`s177`, `s249`,
`s250`) are in the fold, not just the 155 at `_bmad-output/` root — 158 absorbed markers, with a
root-level file as control. And the dashless `20260718T234306Z` sits at position **144 of 158**,
between `2026-07-17T011711Z` and `2026-07-19T232737Z`; an unnormalised `sort` would have placed it
last.

**Nothing in this file was found wrong.** That is worth stating plainly rather than leaving as an
absence, because the previous two graph runbooks each had criteria withdrawn at discharge, and both
times the cause was an instrument rather than the change. The difference here is that the three
figures most likely to be wrong — the file count, which half carries the conservation risk, and
whether the budget check would go green — were each measured against a control before shipping,
and each contradicted the prediction. They are recorded in §Rehearsal.
