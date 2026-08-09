# EXECUTE THIS in a graph session — the pull from `0.335.0` to distribution HEAD

**HEAD WAS `0.338.0` WHEN THIS LINE WAS LAST TOUCHED, AND THE FILENAME SAYS `0337` BECAUSE IT WAS
`0.337.0` WHEN THE FILE WAS CREATED.** The filename is not renamed on every release — chasing it is
a treadmill and it breaks the links pointing here. **Derive the upper bound from
`/Users/n8/git/ai-dlc/VERSION` when you run**; the scope derivation in §2 takes `HEAD` and does not
depend on the number in this heading.

**`v0.338.0` SHIPS NOTHING TO YOU**, and that is derived rather than asserted: its whole diff is
`scripts/validate-plan-shape.sh` (distribution-only), `core/fixtures/plan-shape/` (carries a
`.dist-only` marker), `CLAUDE.md`, `CHANGELOG.md` and `VERSION`. **The shipped set is the same five
files §2 lists.** Control: the same classification puts the other two fixtures in the range on the
SHIPS side, so it separates the two rather than calling everything dist-only.

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
4. **Repath the 12 `W11` prescriptions — §3.** Its own commit, **after step 3's PR has merged**,
   and that ordering is the one real constraint in this file: one of the ten entries is an
   adjudicated subject and editing it mid-pull re-fires a block you just cleared.
5. **§4 — re-home the 32 consolidation byproducts, THEN run a consolidation pass on
   `carry-over-backlog.md`.** That order matters: the re-home first, so the pass's own four files
   are not counted as residue. Independent of everything above — the core work behind it shipped at
   v0.319.0, which your base already carries.
6. **Ping the operator** with the facts listed under *When you are done* — including if you stop
   early, and including a plain "nothing needed doing" on step 2.

**TWO THINGS IN THIS LIST ARE ORDERED AND NOTHING ELSE IS: step 4 comes after step 3, and inside
step 5 the re-home comes before the pass.** Step 3 does not depend on step 2. Stopping after step 3
is a complete outcome; so is stopping after step 2 with the pull untaken, if the stamp does not
match.

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
| ai-dlc HEAD | `0.338.0` — and `v0.338.0` ships nothing to you. Read `VERSION`, do not carry this |
| hops | the dry run decides, not this row. Everything shipped in the range is `ai-dlc-update` machinery |
| expected `HARD-*` blockers | **0**, derived below rather than assumed |
| expected new adjudications | **0** — 10 keyed subjects, 10 with a recorded verdict, and this range touches none of their targets |
| expected NEW warnings | **0**. `contract_version` stays 18; `W11` already fires 12/43 there and this range does not move it |
| destructive defect live on graph today | **yes** — their installed `ledger-rotate.sh --apply` would archive `PC-S330`, a live entry |
| open homing jobs | **0** — both landed in graph #900 |
| consolidation pass | **run it** — target `carry-over-backlog.md`, §4. Nothing gates it |
| consolidation residue | **32** byproduct files at the planning-artifacts area root. §4 drains them |

**s302 HAS NOT STARTED.** `sprint: 302` in both `sprint-status.yaml` copies is what the roll-forward
left, not evidence of activity: `_bmad-output/planning-artifacts/s302/` does not exist and `stories:`
is empty. Nothing in this file is on its critical path.

**AND STEP 5 SPENDS THE FIRST HALF OF THAT EVIDENCE, DELIBERATELY.** The consolidation pass writes
its working files into `s302/`, so the directory will exist afterwards. **The sprint still will not
have started**, and the empty `stories:` mapping is what says so from then on. Do not let the new
directory be read as a kickoff, here or in your report.

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
HEAD** (`cmp -s` — control: `ledger-rotate.sh` and `apply.sh` both differ). So these rows are
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

- `sed -n '1,4p' .claude/.ai-dlc-version` reads **the version you pulled to** — `0.338.0` unless the
  distribution moved again — and theirs' sha **on all four fields**.
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

## §3 — The 12 `W11` repaths. IN SCOPE for this session, as their OWN COMMIT, AFTER §2 merges

**THE DEFERRAL WAS NEVER "ANOTHER SESSION", IT WAS "ANOTHER COMMIT"** — the reason on record is
that a pull-review diff should stay a pull-review diff, and a separate commit in this same session
satisfies that completely. Opening a graph session is the expensive part; these are prose edits to
layer entries you own. **Operator direction 2026-08-09: take them here.**

**ONE ORDERING RULE, AND IT IS THE ONLY THING THAT MAKES THE ORDER MATTER.** Editing a layer entry
changes its blob, and `adj_digest` keys a recorded verdict on **the entry file's hash plus the core
file it hooks at theirs** (`core/skills/ai-dlc-update/reconcile/layer-drift.sh:519`). So an edit
SPENDS the verdict. **Exactly one of the ten `W11` entries is an adjudicated subject** —
`overrides/steps__retro__domain-sections.md`, which appears in both the `W11` list and the
`--list-adjudications` list; the other nine appear in neither. Therefore:

- **Do §3 after §2's PR has merged.** Editing that entry mid-pull re-fires a block you already
  cleared.
- **Expect ONE `HARD-LAYER-ADJUDICATION-MISSING` row on the NEXT pull**, for that entry only. That
  is the digest design working, not damage, and re-recording the verdict is the remedy. If you would
  rather not carry it, leave that one row and take the other eleven — nothing couples them.

`LC-R4` / `W11` holds a path a layer entry **prescribes** to `artifact-path-grammar.md`. It does not
test whether the path exists, deliberately: the case that produced the clause is `tea-consumer.md`'s,
which *resolves* — it names the residue the story migration left at
`_bmad-output/planning-artifacts/stories/` while the live corpus moved to **233** `s<N>/stories/`
directories. An agent following it reads old sprints and nothing fails.

The twelve, with the remedy for each. **Every replacement below was RE-VERIFIED to exist in your
tree on 2026-08-09, with the control that every cited original is gone:**

| entry | prescribes | rewrite as |
|---|---|---|
| `extensions/roles/tea-consumer.md` | `_bmad-output/planning-artifacts/stories/` | `_bmad-output/planning-artifacts/s<N>/stories/` |
| `overrides/steps__retro__domain-sections.md` | `_bmad-output/planning-artifacts/stories/` | same — **this is the adjudicated one** |
| `extensions/steps-domain/carry-over-evaluation-domain.md` | `…/s<N>-carry-over-evaluation.md` | `…/s<N>/carry-over-evaluation.md` |
| `extensions/checks/gate-validation-domain.md` | `…/config-integrity-snapshot-s<N>.json` | `…/s<N>/config-integrity-snapshot.json` |
| `extensions/checks/gate-validation-domain.md` | `docs/retro/sprint-<N>.md` | `docs/retro/s<N>/retro.md` |
| `extensions/roles/dev-domain.md` | `docs/retro/sprint-294.md` | `docs/retro/s294/retro.md` |
| `extensions/roles/qa-domain.md` | `docs/retro/sprint-176.md` | `docs/retro/s176/retro.md` |
| `extensions/roles/qa-domain.md` | `docs/retro/sprint-294.md` | `docs/retro/s294/retro.md` |
| `extensions/steps-domain/deploy-validate-push.md` | `docs/retro/sprint-249.md` | `docs/retro/s249/retro.md` |
| `extensions/steps-domain/discovery-prior-decision-corpus.md` | `docs/retro/sprint-*.md` | `docs/retro/s*/retro.md` |
| `extensions/steps-domain/sprint-review-domain.md` | `docs/reviews/sprint-<N>/**` | `docs/reviews/s<N>/**` |
| `overrides/steps__retro__ci-gates-enforcement-surface.md` | `docs/retro/sprint-168/171/174.md` | three separate `docs/retro/s168\|s171\|s174/retro.md` |

**EIGHT OF THE TWELVE ARE PROSE YOUR OWN MIGRATION LEFT BEHIND.** The FILENAMES are right —
`validate-artifact-paths.sh` reports PASS over your tree (5071 conforming of 5169 tracked read) —
only the prose citing them was never updated. Re-verified today: all six of
`docs/retro/s{294,176,249,168,171,174}/retro.md` exist, and the control says
`docs/retro/sprint-{294,176,249,168}.md` are all gone.

**The `docs/reviews/` row has the same shape and is worth one extra line**, because 9 legacy
`docs/reviews/sprint-<N>/` directories still exist and could make the rewrite look wrong: they hold
**zero tracked files** (`git ls-files docs/reviews/ | grep -c '^docs/reviews/sprint-'` returns 1, and
that hit is `sprint-status-generator-side-by-side.md`, a filename with no sprint token). The live
corpus is **135** `docs/reviews/s<N>/` directories. The old form is dead; the empty directories are
residue.

**The last row is prose shorthand for three retros** that the extractor reads as one path. A true
finding with an ugly quotation, not a false positive: all three spellings are dead and the remedy is
right for all three.

### Done-when for §3

- `validate-layer-entries.sh` prints **`W11=LC-R4:0/43`** in its `LAYER_MEASURED` line and the
  warning count drops **14 → 2**. Both numbers come from the same line, so read the line rather than
  the count alone. **The before-reading is `W11=LC-R4:12/43` and 14 warnings, measured 2026-08-09** —
  take it yourself before you edit anything, or you cannot tell a fix from a tool that was always
  quiet.
- The two survivors are `W7` (a dangling "Check 11b" pointer in `deploy-validate-domain.md`) and
  `W6` (43 entries below `contract_version` 18). **Neither is `W11` work and neither is in scope
  here** — that is the expected non-zero, stated so a 2 does not read as a failure.
- `validate-artifact-paths.sh` still reports **PASS**. It reads FILES, not prescriptions, so this
  section cannot move it; a change there means you edited something you did not mean to.

---

## §4 — Re-home the 32 consolidation byproducts. This is the artifact-consolidation work reaching your tree

**IS THE CORE WORK COMPLETE? YES, AND YOU ALREADY HAVE ALL OF IT.** The last change to
`steps/artifact-consolidation.md` was **v0.319.0**, and your base is 0.335.0, so nothing in this
section waits on the pull. What shipped:

- **v0.319.0** closed both defects the consolidation review found: the step prescribed AREA-ROOT
  paths for per-sprint work products, and it wrote four working files while never saying what became
  of them. It now writes all four into `_bmad-output/planning-artifacts/s<N>/` and retires the two
  drafts at a new Step 6.
- **v0.321.0 – v0.323.0** took the methodology half — the durable artifacts refilled because
  sprint-scoped content was written into them, so the LOCKED block and the changelog moved into
  `s<N>/`. **You took that half already, in #900.**

**WHAT HAS NEVER HAPPENED IS A RUN.** No sprint has executed on your tree since v0.319.0, so the
changed step has never written a file here. Its fixture covers it; a fixture is not a pass.

### RUN A CONSOLIDATION PASS — target `_bmad-output/planning-artifacts/carry-over-backlog.md`

**This is an instruction, not a recommendation, and nothing gates it.** Do not run a budget check, a
threshold check or a size test to decide whether to proceed — the step is operator-invoked on demand
and the operator has named the target. Work `steps/artifact-consolidation.md` end to end, Steps 1
through 6.

**IT WRITES TO `s302/`**, because `sprint-id` returns 302 and the step says to use the `sprint_id`
the snapshot holds when the pass runs. That creates `_bmad-output/planning-artifacts/s302/`, which
today does not exist — and the parent plan uses that directory's absence as its evidence that s302
has not started. **After this pass that instrument is spent**; the sprint still has not started, and
the empty `stories:` mapping is what says so afterwards. Say this in your report so nobody reads the
new directory as a kickoff.

**Do not consolidate `_bmad-output/pipeline-continuation-log.md`.** The step excludes it by
name-class: *"Not a consolidation target: `gate-log.md` (and any similar append-only log). Logs are
bounded by rotation, not consolidation."* It is over its budget and its remedy is `rotate`, which is
separate work and not part of this pull.

### The 32, re-derived 2026-08-09, with the instrument warnings that decide the method

**THE PARENT PLAN SAYS THIS TABLE IS ALREADY WRITTEN DOWN AND IT IS NOT.** Its item-23b section
carries the aggregate (33 files, 24 direct, 9 inferred, 0 refused) and the list of destination slots,
but **not the per-file mapping** — so the table below was derived fresh rather than copied.
**It disagrees with the plan's aggregate and you should expect that**: the count is **32, not 33**
(the plan measured at an older sha), and the DIRECT/INFERRED split comes out **15/17, not 24/9**,
because the plan resolved INFERRED rows against a subject-derived sprint timeline by first-parent
ancestry position and the derivation below simply walks first-parent to the nearest sprint-naming
subject. **The SLOT is what you act on, and 11 of the plan's 13 slots reappear here unchanged**
(`s272` and `s298` do not, and those are the two files no longer at the root).

**TWO INSTRUMENTS ARE FALSE HERE, both measured, and using either produces a confident wrong answer:**

- **Content frequency.** A byproduct's content IS other sprints — that is what it consolidates — so
  the modal sprint token is the sprint being consolidated, not the one doing it.
  `consolidation-manifest-carry-over-backlog.md` was first committed 2026-06-05 and its modal token
  is S297, which began 2026-07-22.
- **`git log --follow`.** A draft is a near-copy of the live artifact, so rename detection walks it
  into its SOURCE's history: three drafts report creation dates months before consolidation existed.
  **Bare `--diff-filter=A` is correct for these files** because the migration did not move them.

```
# the derivation, run from /Users/n8/git/graph
git log --diff-filter=A --format='%H%x09%s' -- <path> | tail -1     # the adding commit
# DIRECT   = that subject names a sprint
# INFERRED = walk `git rev-list --first-parent` from it to the nearest subject that does
```

| file (at `_bmad-output/planning-artifacts/`) | slot | how |
|---|---|---|
| `consolidation-manifest-gate-log.md` | `s243` | DIRECT |
| `consolidation-manifest-carry-over-backlog.md` | `s244` | inferred, distance 1 |
| `consolidation-manifest-prd.md` | `s244` | inferred, distance 1 |
| `consolidation-validation-report.md` | `s244` | inferred, distance 1 |
| `consolidation-coverage-carry-over-backlog.md` | `s247` | DIRECT |
| `consolidation-coverage-prd.md` | `s247` | DIRECT |
| `consolidation-validation-prd.md` | `s248` | DIRECT |
| `prd-consolidation-validation-report.md` | `s249` | DIRECT |
| `consolidation-manifest-product-brief.md` | `s268` | inferred, distance 1 |
| `consolidation-validation-report-2026-06-24.md` | `s268` | inferred, distance 1 |
| `prd.coverage-report.md` | `s268` | inferred, distance 1 |
| `product-brief.coverage-report.md` | `s268` | inferred, distance 1 |
| `consolidation-coverage-product-brief.md` | `s274` | DIRECT |
| `review-consolidation-prd.md` | `s280` | DIRECT |
| `consolidation-manifest-architecture.md` | `s287` | inferred, distance 1 |
| `consolidation-draft-carry-over-backlog-history.md` | `s293` | DIRECT |
| `consolidation-draft-carry-over-backlog-live.md` | `s293` | DIRECT |
| `consolidation-draft-prd-history.md` | `s293` | DIRECT |
| `consolidation-draft-prd-live.md` | `s293` | DIRECT |
| `consolidation-draft-product-brief-history.md` | `s293` | DIRECT |
| `consolidation-draft-product-brief-live.md` | `s293` | DIRECT |
| `consolidation-validation-carry-over-backlog.md` | `s293` | DIRECT |
| `consolidation-validation-product-brief.md` | `s293` | DIRECT |
| `consolidation-coverage-architecture.md` | `s301` | inferred, distance 1 |
| `consolidation-draft-architecture-history-append.md` | `s301` | inferred, distance 1 |
| `consolidation-draft-architecture-live.md` | `s301` | inferred, distance 1 |
| `consolidation-draft-architecture-proposed.md` | `s301` | inferred, distance 1 |
| `consolidation-draft-prd-history-append.md` | `s301` | inferred, distance 1 |
| `consolidation-draft-prd-live-superseded-20260805T122645Z.md` | `s301` | inferred, distance 1 |
| `consolidation-manifest-architecture-baseline-20260802.md` | `s301` | inferred, distance 1 |
| `consolidation-validation-architecture.md` | `s301` | inferred, distance 1 |
| `consolidation-validation-prd-superseded-20260805T123052Z.md` | `s301` | inferred, distance 1 |

**MOVE, NEVER DELETE.** Older coverage reports cite draft paths as their no-loss evidence, so
removing a byproduct breaks a record that was already written. `git mv`, with a per-file sha check —
the same discipline the artifact-path migration used.

**ALL 32 DESTINATIONS ARE FREE**, checked 2026-08-09, and the check has a control:
`s300/consolidation-manifest-prd.md` DOES exist, so a collision is detectable rather than assumed.
**Re-run the collision check before moving anything** — 13 byproducts are already in slots and a
second pass at any of these basenames would change that.

### Done-when for the consolidation PASS

- **Step 3's no-loss gate passed.** Every Step 1 manifest entry appears in exactly one of the two
  drafts; no Rule 13 locked requirement left the live draft. The step makes an unaccounted entry a
  HARD_BLOCK, so this is its own assertion — **report the manifest entry count**, because a gate
  over an empty manifest passes the same way a real one does.
- **ZERO byproducts at the area root from this pass.** Every working file under
  `_bmad-output/planning-artifacts/s302/`: the manifest, both drafts, the coverage report.
  **This is the actual test of v0.319.0** and it is one `git status` away.
- **Both drafts gone after the step's Step 6**, which is the other half of v0.319.0 —
  `consolidation-draft-carry-over-backlog-{live,history}.md` must not survive the pass.
- **Rule 20 validation passed** on the consolidated live draft.
- **`validate-artifact-paths.sh` still PASS**, and `s302/` is a conforming slot so it should be
  untouched by this.
- **The whole-read pool reading after the pass, reported.**

### Done-when for the §4 re-home

- `git ls-files '_bmad-output/' | awk -F/ 'NF==3' | grep -cE 'consolidation-|coverage-report'`
  returns **0**. **It returns 32 today** — take that reading first, or a zero afterwards is
  indistinguishable from a filter that matches nothing. The control is the same expression with
  `NF>3`, which returns **13** now and **45** after. **Run the re-home BEFORE the pass, or the
  pass's own four files land inside the count and you cannot tell the residue from the new work.**
- `validate-artifact-paths.sh` still reports **PASS**. Every path involved conforms both before and
  after — a syntactic grammar cannot tell a durable artifact from a per-sprint one that omitted its
  sprint, which is exactly why this is a hand-derived re-home and not a migration run.
- **No file deleted.** `git diff --stat` for the commit shows renames only, zero deletions.

---

## Deliberately NOT in this file

- **Rotating `pipeline-continuation-log.md`** (314% of budget, remedy `rotate`). Real, yours, and
  not this pull's — and explicitly NOT a consolidation target.
- **Consolidating the other three artifacts.** One pass, one named target, per the step's own
  invocation rule.
- **The `sprint-status.sh` freeze-path fix.** Core's, reported, not in this range. §1.
- **Consumer-side ledger items**, none of which this pull touches: `PC-S329-NAMED-UPSTREAM-…`'s
  disposition, `PC-S312`'s receipt (it reports `NEEDS-REVIEW` on every pull until re-anchored at
  `docs/retro/s249/retro.md`), the `921.`/`20.` retire-or-refile call, the 48 refused artifact-path
  migrations. (The byproducts are NOT on that list — they are §4 and you are doing them.)
- **Both homing jobs.** DONE in graph #900; the brief went 1030 → 648 lines.

---

## When you are done

**Ping the operator** with:

1. **The stamp**, all four fields, and how many hops it took.
2. **`ledger-rotate.sh` before and after** — the `1 closed entries would move / PC-S330` line and
   the `0 closed entries` line. That pair is the whole reason this pull was urgent.
3. **The two `CLOSE-CANDIDATE` dispositions** — full slugs — and whether you annotated them.
4. **`validate-layer-entries.sh`'s warning count at three points**: before anything (expect 14),
   after the pull (expect 14 — unchanged is the PASS), and after §3 (expect 2, with `W7` and `W6`
   the named survivors).
5. **Whether you took `overrides/steps__retro__domain-sections.md`** in §3, since that one costs a
   re-adjudication on the next pull.
6. **The byproduct count before and after §4** — 32 → 0 at the area root, 13 → 45 in slots, zero
   deletions.
7. **The consolidation pass**: the manifest entry count, that no working file landed at the area
   root, that both drafts are gone, and the pool before/after. **And say plainly that `s302/` now
   exists because the pass created it** — the sprint still has not started.
8. **Your §1 decision**: left as-is (the recommendation), or reversed and why.
9. **Anything this file predicted that did not happen.** Two of its predecessors' predictions have
   already been wrong; the record of a wrong one is worth more than a clean report.
