# EXECUTE THIS in a graph session — the 0.335.0 → 0.337.0 pull

## Start here

**You are working in `/Users/n8/git/graph`. WRITE THERE.** `/Users/n8/git/ai-dlc` is the
distribution: **read it, never write it** — and you should not need to open it at all. Everything
this file needs from that side was measured from that side on 2026-08-09 and is quoted below with
the command that produced it.

**THE NUMBERED ACTION LIST. Do these in order:**

1. **Confirm graph's stamp reads `0.335.0 / b324779` on all four fields.** The command is under
   *The one thing to get right before anything else*. A different answer means STOP and ping the
   operator: every scope figure in §2 is keyed to that base.
2. **Read §1 and decide the roll-forward question.** It is one decision, it is yours, and the
   recommendation is **do nothing** — the measurements are all there. It changes no files if you
   accept the recommendation. It is first because the previous handoff called it the first todo,
   not because it blocks the pull; it does not.
3. **Take the pull — §2.** Expect the whole range to land in step 2's self-update, `0 HARD-*`,
   0 new adjudications, and **no new warnings at all**.
4. **Ping the operator** with the facts listed under *When you are done* — including if you stop
   early, and including a plain "nothing needed doing" on step 2.

**NOTHING IN THIS LIST IS BLOCKED.** Step 3 does not depend on step 2. Stopping after step 3 is a
complete outcome; so is stopping after step 2 with the pull untaken, if the stamp does not match.

**EVERY NUMBER BELOW WAS MEASURED ON 2026-08-09, NOT PREDICTED FROM A DIFF.** Where a figure could
go stale between writing and running, the derivation is beside it — **run the derivation and
believe that, not the number.** Two predecessors of this file predicted hop counts from the
distribution side and were wrong both times.

### The one thing to get right before anything else

```
sed -n '1,4p' /Users/n8/git/graph/.claude/.ai-dlc-version
```

Measured 2026-08-09, after graph's own 0.330.0 → 0.335.0 pull landed:

```
version: 0.335.0
commit: b324779
skill_version: 0.335.0
skill_commit: b324779
```

**If it does not say `0.335.0 / b324779` on all four, STOP and ping the operator.** Everything in
§2 is scoped to that base. The paragraph in the parent plan that names this base has now been wrong
twice — once carrying a version a pull had already superseded, once naming a range that started two
releases too early — which is why this file makes you read it rather than trust it.

### Ping the operator

**On any question, on any decision this file does not already record, and when you finish —
including if you stop early.** From outside this session, "still working" and "stopped, waiting on
you" look identical, so silence is a stall the operator can only find by polling. Say something when
you need a decision, when a premise here does not hold, and when you are done.

---

## Current status — what is true as of 2026-08-09

| | |
|---|---|
| graph stamp | `0.335.0 / b324779`, all four fields agreeing |
| ai-dlc HEAD | `0.337.0` |
| hops | the dry run decides, not this row. The range is two releases and both are `ai-dlc-update` machinery |
| expected `HARD-*` blockers | **0**, derived below rather than assumed |
| expected new adjudications | **0** — 10 keyed subjects, 10 with a recorded verdict, and this range touches none of their targets |
| expected NEW warnings | **0**. `contract_version` stays 18; `W11` already fires 12/43 there and this range does not move it |
| destructive defect live on graph today | **yes** — their installed `ledger-rotate.sh --apply` would archive `PC-S330`, a live entry |
| open homing jobs | **0** — both landed in graph #900 |

**s302 HAS NOT STARTED.** `sprint: 302` in both `sprint-status.yaml` copies is what the roll-forward
left, not evidence of activity: `_bmad-output/planning-artifacts/s302/` does not exist and `stories:`
is empty. Nothing in this file is on its critical path.

---

## §1 — The roll-forward question. The recommendation is DO NOTHING, and here is the measurement

**WHAT HAPPENED.** `docs/plans/s301-close-out.md` told the graph session to run `sprint-status.sh
close` and then `roll`, and it did (graph `d1f3a1fe4`). That instruction contradicts core's own rule,
which is stated in the script it invokes — `core/scripts/sprint-status.sh:63`: *"ROTATION HAPPENS AT
PIPELINE START, NOT AT CLOSE… Rotating at start keeps the predecessor's terminal state readable
exactly until its successor exists."* `core/skills/ai-dlc/steps/route.md:400` is where the roll
belongs. So the roll is early. **The question this file had to settle before it could ask you to
reverse anything was whether a reversal has a source to restore from, and what it costs at
kickoff.** Both are settled, and the answer changed the recommendation.

**1. NOTHING WAS LOST. The migration RENAMED the frozen files; it did not delete them.** The parent
plan recorded *"the artifact-path migration deleted both (128 deletions each)"* — that is a rename
read without rename detection. With it on:

```
git -C /Users/n8/git/graph show -M --stat --oneline dbe755181 | grep sprint-301
  .../{sprint-status/sprint-301.yaml => s301/sprint-status.yaml}   | 0
  .../{sprint-status/sprint-301.yaml => s301/sprint-status.yaml}   | 0
```

Both views' copies exist today at `_bmad-output/{planning,implementation}-artifacts/s301/sprint-status.yaml`,
128 lines each, `| 0` content change. **A reversal is possible.** Order confirmed: the roll is an
ancestor of the migration, so the migration moved what the roll wrote.

**2. THE MOVE WAS INTENDED.** It is core's own mapping, not an accident of a glob —
`core/scripts/migrate-artifact-paths.sh:375` says the destination *"remains a directory:
`sprint-status/sprint-187.yaml` becomes `s187/sprint-status.yaml`."* The tree graph is in now is the
grammar-conforming one.

**3. THE KICKOFF NO-OP IS NOT SILENT, and the parent plan was wrong about that too.** Probed on a
scratch tree with core's own script — subject: both canonicals already at 302, which is graph today:

```
$ SPRINT=… sprint-status.sh roll --sprint 302
sprint-status: already at sprint 302 (no-op)          exit 0
# CONTROL, same tree, canonicals reset to `sprint: 301 / status: done`:
sprint-status: rolled forward to sprint 302
  …/implementation-artifacts/sprint-status/sprint-301.yaml
  …
```

The `if moved:` guard has an `else` — `core/scripts/sprint-status.sh:402`. An operator watching for
a roll at s302's kickoff gets an explicit no-op line, not silence.

**4. AND THE CONTROL ABOVE IS WHERE THE REAL DEFECT IS. It is CORE's, and it is why reversing is a
round trip.** Look at what the control froze: `sprint-status/sprint-301.yaml` — the pre-migration
form. `core/scripts/sprint-status.sh:384` still composes it, while core's own grammar moved it.
Probed against core's validator with a control in the same run (subject: the old form; control: the
migrated form, in the same tree):

```
BLOCKING — 1 path(s) carry a sprint token outside the reserved `s<N>/` slot:
  _bmad-output/planning-artifacts/sprint-status/sprint-301.yaml
VERDICT: FAIL — 1 blocking, 0 ambiguous …
# the control, _bmad-output/planning-artifacts/s302/sprint-status.yaml, was not reported
```

**And graph's own pre-push runs that validator** (`.githooks/pre-push`, the `artifact paths` step,
which invokes `scripts/ai-dlc/validate-artifact-paths.sh`). So: revert the roll → s302's kickoff
rolls for real → it writes the old form → your own pre-push blocks the push → you migrate it back to
`s301/sprint-status.yaml` → you are exactly where you are now, having spent a wedged push to get
there.

**THE RECOMMENDATION, and it is the operator's call to accept or refuse — core may not write your
tree.** **Leave it.** The roll is early against the rule, but its OUTCOME is the state a correct
kickoff roll would have produced, and the migration has already put the frozen file on the
conforming path. Reversing costs a wedged push and lands back here.

**WHAT IS ACTUALLY OWED IS A CORE FIX, and it is not in this pull.** `sprint-status.sh` must freeze
into `<area>/s<N>/sprint-status.yaml`, and its `max_frozen` reader (`core/scripts/sprint-status.sh:276`)
must read both spellings — on a migrated consumer that reader currently globs a directory holding
only `_preamble.yaml`, so it returns nothing. **That is dormant on graph today** and only fires if a
canonical ever becomes preamble-only, where the fallback would return sprint 1 — the exact outcome
the code's own comment calls out. **Nothing on graph is broken by it until the next genuine roll**,
which is s302's close. It has been reported to the operator from the distribution side; do not try to
fix it in your tree.

---

## §2 — Take the pull

Run `/ai-dlc-update` and work its worklist top to bottom. What follows is what to expect, so that a
surprise reads as a surprise rather than as normal.

### The reason to take it is a live destructive defect, not housekeeping

**Your installed `ledger-rotate.sh --apply` would archive `PC-S330`, a live push candidate.**
Measured 2026-08-09, both copies run in report mode against your own ledger — writes nothing:

```
# YOUR copy, .claude/skills/ai-dlc-update/reconcile/ledger-rotate.sh
ledger-rotate: 1 closed entries would move (69 of 3883 lines, leaving 3814).
  PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-THE-SKIP-RULE-IT-CITES — the new

# the DISTRIBUTION copy at 0.337.0, same ledger, same invocation
ledger-rotate: 0 closed entries — nothing to rotate (3883 lines stay).
```

The entry is archived **on its own quotation of the close rule** — a candidate filed about the rule
naturally writes the form the rule matches. v0.336.0 requires a version digit after the parenthesis,
which a quotation does not carry. The stuck-set row goes 8 → 9 with `PC-S330` joining it, and that is
the correct place for it. **Until this pull lands, do not run `ledger-rotate.sh --apply`.**

### The scope, derived, with a control that separates the two kinds

```
git -C /Users/n8/git/ai-dlc diff --name-only b324779 HEAD
```

Measured 2026-08-09: **5 `core/` files**, plus `VERSION`, `CHANGELOG.md`, `CLAUDE.md`, and **2 under
`docs/`** — the control, since it shows the command separates distribution-only paths from shipped
ones rather than reporting everything. The 5:

| file | what changed |
|---|---|
| `core/skills/ai-dlc-update/reconcile/ledger-rotate.sh` | the strict close predicate (v0.336.0) |
| `core/skills/ai-dlc-update/reconcile/apply.sh` | says on every successful run that it does NOT write the reconcile log (v0.337.0) |
| `core/skills/ai-dlc-update/SKILL.md` | step 7 gains its own bullet for the log, `core/skills/ai-dlc-update/SKILL.md:1478` |
| `core/fixtures/ledger-rotate/run.sh` | the mutation arm for the version digit |
| `core/fixtures/apply-restamp-theirs/run.sh` | two arms: the run must NAME the log and must not report it as written |

**NO RULEBOOK FILE MOVES.** Zero paths under `core/skills/ai-dlc/steps/`,
`core/skills/ai-dlc/SKILL.md` or `core/team-roles/`. Both fixtures ship (neither carries a
`.dist-only` marker), so both arrive in your `tests/fixtures/`.

**EXPECT THE WHOLE RANGE TO LAND IN STEP 2's SELF-UPDATE.** Every shipped path is `ai-dlc-update`'s
own machinery or a fixture covering it, and nothing in it is under `core/scripts/`, which is the
slice `core/skills/ai-dlc-update/SKILL.md:296` warns can install a check that fails its own push.
**But run the dry run and read what the gate says** rather than believing this paragraph. If the gate
returns `SELF-UPDATE-DEFER` or `SELF-UPDATE-UNDECIDED`, follow `core/skills/ai-dlc-update/SKILL.md:305`
— carry the machinery slice into the step-7 apply and pass `--carried-machinery-slice`. Do not set
the two skill fields by hand.

### Adjudications: expect none, and it is derived rather than guessed

```
.claude/skills/ai-dlc-update/reconcile/layer-drift.sh --list-adjudications \
    /Users/n8/git/ai-dlc b324779 HEAD .
```

Measured 2026-08-09: **10 keyed subjects, 10 with a recorded verdict, 0 without.** Their targets are
`team-roles/dev.md`, `steps/retro.md`, `steps/route.md`, `SKILL.md` and
`steps/stories-test-strategy.md` — **and this range touches none of them**, which the scope
derivation above shows directly. So every recorded verdict still keys and no
`HARD-LAYER-ADJUDICATION-MISSING` row should appear. A full `layer-drift.sh` run over the same base
returned **47 rows, 0 of them `HARD-`**.

**If one appears anyway, do not clear it by editing an entry.** Editing an entry after recording its
verdict SPENDS that verdict, because the digest covers the entry. Read the row, decide, record.

### NO NEW WARNINGS. This is the part most likely to be misread as a regression, so it is measured

`contract_version` is **18 on both sides** (`core/skills/ai-dlc/layer-contract.yaml:159`, and your
own installed copy), and `layer-contract.yaml` is not in the range — the same `git diff --name-only`
over `'*layer-contract.yaml'` returns 0, where the control over `'*ledger-rotate.sh'` returns 1.

Your tree today, from your own installed validator (`scripts/ai-dlc/validate-layer-entries.sh`),
measured 2026-08-09 **before** the pull:

```
validate-layer-entries: 0 error(s), 14 warning(s)
LAYER_CONFORMANCE v1 contract_version=18 entries=43 at_current=0 behind=43 undeclared=0
  76 artifact-path prescription(s) read across 4 scan root(s); 12 non-conforming.
LAYER_MEASURED … W11=LC-R4:12/43 … W7=LC-R2:1/43 … W6=LC-C2:1/43
```

**Expect the same 14 after.** The 12 `W11` rows and the 43 `behind` entries are the state v0.333.0
introduced and you already absorbed; **do not re-describe them as new, and do not treat 14 warnings
as a finding of this pull.** If the count moves, that IS a finding — report it.

### What the ledger will say, quoted from the shipped reader rather than predicted

`ledger-reverify.sh` is **byte-identical between your installed copy and the distribution at
0.337.0** (`cmp -s` — control: `ledger-rotate.sh` and `apply.sh` both differ). So these rows are
exactly what your own copy prints:

```
CLOSE-CANDIDATE  PC-S329-APPLY-SH-NEVER-WRITES-THE-RECONCILE-LOG-STEP-7-MANDATES
                 theirs:…/apply.sh now CONTAINS "reconcile-log" — upstream absorbed this at 0.337.0
CLOSE-CANDIDATE  PC-S331-LEDGER-ROTATE-ARCHIVES-A-LIVE-ENTRY-THAT-QUOTES-THE-STRICT-CLOSE-FORM
                 verify sh: no longer reproduces at theirs (0.337.0) — likely absorbed
NAMED-UPSTREAM   PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-THE-SKIP-RULE-IT-CITES
                 upstream's own history NAMES this entry's id at v0.336.0 (fc193e0)
NAMED-UPSTREAM   PC-S331-…  (same, v0.336.0)
```

Full run: 55 `STILL-LIVE`, 20 `HAND-REVIEW`, 13 `NAMED-UPSTREAM`, 8 `NAMED-UPSTREAM-AMBIGUOUS`,
2 `CLOSE-CANDIDATE`, 1 `NEEDS-REVIEW`, 1 `RECEIPTS-UNDECIDED`.

**ONE PREDICTION IN THE PARENT PLAN IS REFUTED, and reading it would have made you distrust a
correct row.** It said `PC-S331` would report `STILL-LIVE` because its verify anchors on a prefix the
fix keeps. It does not: the shipped reader returns `CLOSE-CANDIDATE`. Confirm and annotate as
normal — **`ADOPTED UPSTREAM (v0.337.0, verified <date>)`, with the version digit**, which is now the
only form `ledger-rotate.sh` will archive on.

**`PC-S329` names TWO live candidates**, so spell the full slug when you disposition either. Only
`…-APPLY-SH-NEVER-WRITES-THE-RECONCILE-LOG-…` is closed by this range;
`…-NAMED-UPSTREAM-DETAIL-INSTRUCTS-THE-CLOSE-ITS-OWN-STATUS-FORBIDS` is still `STILL-LIVE`.

**AND THE `RECEIPTS-UNDECIDED` ROW IS A CLASS, NOT TWO ENTRIES.** The run says **26 of 26**
`theirs_has` receipts reported `STILL-LIVE` on a substring present at base as well as at theirs, so
those verdicts are restatements of the previous run rather than new measurements. **Do not read a
`STILL-LIVE` from that set as evidence a defect survives**, and do not read the low
`CLOSE-CANDIDATE` count as evidence nothing was absorbed. Re-anchoring them is not this pull's work;
it is an open question on the distribution side.

### Done-when for §2 — every PASS below was RUN from the distribution side on 2026-08-09

- `sed -n '1,4p' .claude/.ai-dlc-version` reads **`0.337.0`** and theirs' sha **on all four fields**.
  Step 2's self-update writes `skill_version`/`skill_commit`; the step-7 apply writes
  `version`/`commit`. If step 2 deferred, the one run that may claim both is
  `apply.sh --carried-machinery-slice`, and all four still end equal.
- `bash tests/fixtures/ledger-rotate/run.sh` prints `ledger-rotate: PASS`, and
  `bash tests/fixtures/apply-restamp-theirs/run.sh` exits 0. **Both were run at the distribution
  HEAD from the repo root and both are green**, so a red on your side is environmental or a real
  regression, never the fixture being new.
- `ledger-rotate.sh <your ledger>` (report mode, no `--apply`) prints **`0 closed entries — nothing
  to rotate`** and lists **9** in the stuck set. **Run it before the pull too** — it says
  `1 closed entries would move` today, and a before/after pair is the only reading that shows the
  fix did something rather than that the tool was always quiet.
- `validate-layer-entries.sh` prints **`0 error(s), 14 warning(s)`** and
  `contract_version=18 entries=43`. Measured before the pull; unchanged is the PASS.
- `layer-drift.sh --list-adjudications` prints **10 keyed subjects, 10 with a verdict, 0 without**,
  and the apply reports **0 `HARD-*`**.
- **You write `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`; `apply.sh` does not.** It will now
  say so on the successful run (`apply: NOT WRITTEN BY THIS TOOL — …`,
  `core/skills/ai-dlc-update/reconcile/apply.sh:1128`). Write it LAST, after the post-apply re-runs,
  because it records them. That message is v0.337.0's whole subject; if you do not see it, the apply
  did not carry this range.

---

## Deliberately NOT in this file

- **The 12 `W11` repaths.** The operator chose to leave them to their own commit so a pull-review
  diff stays a pull-review diff. The rewrite for each is tabulated in the SPENT
  [`graph-0330-to-0335-pull-and-homing.md`](graph-0330-to-0335-pull-and-homing.md) and every
  replacement was verified to exist. They are outstanding, not work for this session.
- **The `sprint-status.sh` freeze-path fix.** Core's, reported, not in this range. §1.
- **Consumer-side ledger items**, none of which this pull touches: `PC-S329-NAMED-UPSTREAM-…`'s
  disposition, `PC-S312`'s receipt (it reports `NEEDS-REVIEW` on every pull until re-anchored at
  `docs/retro/s249/retro.md`), the `921.`/`20.` retire-or-refile call, the 48 refused artifact-path
  migrations, and the 33 byproduct files at the area root.
- **Both homing jobs.** DONE in graph #900; the brief went 1030 → 648 lines.

---

## When you are done

**Ping the operator** with:

1. **The stamp**, all four fields, and how many hops it took.
2. **`ledger-rotate.sh` before and after** — the `1 closed entries would move / PC-S330` line and
   the `0 closed entries` line. That pair is the whole reason this pull was urgent.
3. **The two `CLOSE-CANDIDATE` dispositions** — full slugs — and whether you annotated them.
4. **`validate-layer-entries.sh`'s warning count**, and explicitly whether it is still 14.
5. **Your §1 decision**: left as-is (the recommendation), or reversed and why.
6. **Anything this file predicted that did not happen.** Two of its predecessors' predictions have
   already been wrong; the record of a wrong one is worth more than a clean report.
