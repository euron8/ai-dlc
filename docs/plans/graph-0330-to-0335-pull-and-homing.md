# EXECUTE THIS in a graph session — the 0.330.0 → 0.335.0 pull, then two homing jobs

## Start here

**You are working in `/Users/n8/git/graph`. WRITE THERE.** `/Users/n8/git/ai-dlc` is the
distribution: **read it, never write it** — and you should not need to open it at all, because
everything this file needs from it is already quoted below, measured from that side on 2026-08-09.

**THE NUMBERED ACTION LIST. Do these in order:**

1. **Confirm graph's stamp reads `0.330.0 / 65c572f` on all four fields** — the derivation is
   directly below, and a different answer means STOP and ping the operator, because every scope
   figure in §1 is keyed to that base.
2. **Take the pull — §1.** Expect one hop, `0 HARD-*`, 0 new adjudications, and 12 new `W11`
   warnings that are real and block nothing.
3. **Home the S299 LOCKED block — §2.** Not blocked by anything, including step 2.
4. **Home the brief's `## Changelog` section — §3.** Not blocked by anything, including step 3.
5. **Ping the operator** with the four facts listed under *When you are done*, including if you
   stopped early.

**NOTHING IN THIS LIST IS BLOCKED.** Steps 3 and 4 do not depend on step 2; they are here in one
file because opening a graph session is the expensive part. Stopping after step 2 is a complete
outcome.

**EVERY NUMBER BELOW WAS MEASURED, NOT PREDICTED FROM THE DIFF.** Where a figure could have gone
stale between writing and running, the derivation is given beside it — **run the derivation and
believe that, not the number.** This plan's predecessors were wrong about hop counts twice by
predicting from the distribution side.

### The one thing to get right before anything else

**graph's stamp says `0.330.0 / 65c572f` on all four fields.** Confirm it:

```
sed -n '1,4p' /Users/n8/git/graph/.claude/.ai-dlc-version
```

**If it does not say `0.330.0 / 65c572f`, STOP and ping the operator.** Everything in §1 is scoped
to that range, and a different base means the scope below is not yours.

### Ping the operator

**On any question, on any decision this file does not already record, and when you finish —
including if you stop early.** From outside this session, "still working" and "stopped, waiting on
you" look identical, so silence is a stall the operator can only find by polling. Say something
when you need a decision, when a premise here does not hold, and when you are done.

---

## Current status — what is true as of 2026-08-09

| | |
|---|---|
| graph stamp | `0.330.0 / 65c572f`, all four fields agreeing |
| ai-dlc HEAD | `0.335.0` |
| hop | **ONE**, and the dry run is what decides that, not this row |
| expected `HARD-*` blockers | **0** |
| expected new adjudications | **0** |
| expected NEW warnings | **12**, all `W11`, all real, none blocking |
| homing jobs open | **2** (§2 and §3), both verified still open |

**s302 IS THE LIVE SPRINT** (`sprint: 302` in `_bmad-output/implementation-artifacts/sprint-status.yaml`)
and nothing here is on its critical path.

---

## §1 — Take the pull

Run `/ai-dlc-update` and work its worklist top to bottom. What follows is what to expect, so that
a surprise reads as a surprise rather than as normal.

### The scope, and the derivation that produces it

```
git -C /Users/n8/git/ai-dlc diff --name-only 65c572f HEAD
```

Measured 2026-08-09: **14 `core/` files, 2 under `scripts/`, plus `VERSION` and `CHANGELOG.md`**
(control: the same command puts 2 paths under `docs/`, so it separates the two kinds rather than
reporting everything). The 2 under `scripts/` are **distribution-only and do not ship** —
`uninstall.sh` and `validate-enforcement-map.sh`.

**NO RULEBOOK FILE MOVES.** Zero paths under `core/skills/ai-dlc/steps/`, `core/skills/ai-dlc/SKILL.md`
or `core/team-roles/`. What moves is `ai-dlc-update`'s own machinery
(`SKILL.md`, `reconcile/layer-drift.sh`), two `core/scripts/` validators, five fixtures, and four
declaration files (`layer-contract.yaml`, `core-manifest.md`, `extensions/README.md`,
`overrides/README.md`).

**Expect the clean split.** But **run the dry run and read what the gate says** — this plan's
predecessors predicted hop counts from the distribution side twice and were wrong both times.

### Adjudications: expect none, and here is why that is not a guess

A verdict's `subject_digest` covers **the entry blob at this consumer PLUS the core file it hooks,
at theirs**. This range touches **no file any layer entry hooks** — verified by the derivation
above returning empty for `steps/`, `SKILL.md` and `team-roles/`. So every recorded verdict in
`_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` still keys, and no
`HARD-LAYER-ADJUDICATION-MISSING` row should appear.

**If one appears anyway, do not clear it by editing an entry.** Editing an entry after recording
its verdict SPENDS that verdict, because the digest covers the entry — that is the digest design
working, and it cost a previous pull a re-record. Read the row, decide, record.

### NEW: you can now read a `subject_digest` without breaking your gate state

This is the answer to the report that you had to **withhold the register to re-fire the block**,
read the key, restore the file and check it byte-identical by sha256.

```
.claude/skills/ai-dlc-update/reconcile/layer-drift.sh --list-adjudications \
    /Users/n8/git/ai-dlc <base> <theirs> .
```

One `ADJUDICABLE` row per keyed subject — entry, target, `subject_digest`, and the recorded verdict
if there is one. No classification rows, no blockers, no dependence on whether the row still blocks.
**Pass the SAME base the pull uses**: base decides which rows the pass produces, so a degenerate
range gives a short listing rather than a visibly missing one (the mode says so on stderr).

Measured against graph's layer from the distribution side: **10 keyed subjects, all 10 already
carrying a verdict** — every one of which was unreadable before. Use it whenever you need to update
an `owed` object or re-verify a subject.

### NEW: `OVERRIDE-SUPERSEDED` now tells you the SIZE of what a narrowing drops

Your `OWED-RETRO-4A-NARROW` row used to say only that narrowing "releases every unrelated line that
anchor's span froze at base_sha". It now carries a number, computed against **your entry's own
`base_sha`**, which is what an override actually froze:

```
MEASURED: your span under that anchor is 285 non-blank line(s) against core's 199 at f9b8aa4,
and 119 of yours appear nowhere in core's -- that is what this action drops out of the
rendered rulebook.
```

**119 is the number you reported, confirmed independently from the distribution side.** Nothing
about the decision changes: the deferral stands, `still-additive` is recorded, and
`OWED-RETRO-4A-NARROW` continues to track it. **Core will NOT be declaring the arm** — that was
asked and answered: `override_supersessions` keys on `<file>#<anchor>` with no span vocabulary,
core's 231-line 4a span carries exactly ONE sub-heading with the superseded machinery on **both
sides** of it, and the other superseded arm (`strikethrough`) is not in that file at all. The
number is the mechanism; the reading stays yours.

### EXPECT 12 NEW `W11` WARNINGS. THEY ARE REAL, THEY ARE NOT A REGRESSION, AND NOTHING BLOCKS

`LC-R4` / `W11` is new at `contract_version` 18: an artifact path a layer entry **prescribes** is
held to `artifact-path-grammar.md`. Run from the distribution side against your layer:
**76 prescriptions read across 4 scan roots, 12 non-conforming in 10 entries, 0 false positives.**

**It does not test whether the path exists, deliberately.** The case that produced the clause is
`tea-consumer.md`'s, which you reported as a stale path — and it *resolves*. It names the 50-file
residue the story migration left at `_bmad-output/planning-artifacts/stories/` while the live
corpus moved to 233 `s<N>/stories/` directories. An agent following that entry reads a residue of
earlier sprints **and nothing fails**. Testing existence would have missed it and scored 157 false
positives out of 309 tokens on the way.

The twelve, with the remedy for each. **Every replacement below was verified to exist in your tree
on 2026-08-09:**

| entry | prescribes | rewrite as |
|---|---|---|
| `extensions/roles/tea-consumer.md` | `_bmad-output/planning-artifacts/stories/` | `_bmad-output/planning-artifacts/s<N>/stories/` |
| `overrides/steps__retro__domain-sections.md` | `_bmad-output/planning-artifacts/stories/` | same |
| `extensions/steps-domain/carry-over-evaluation-domain.md` | `…/s<N>-carry-over-evaluation.md` | `…/s<N>/carry-over-evaluation.md` |
| `extensions/checks/gate-validation-domain.md` | `…/config-integrity-snapshot-s<N>.json` | `…/s<N>/config-integrity-snapshot.json` |
| `extensions/checks/gate-validation-domain.md` | `docs/retro/sprint-<N>.md` | `docs/retro/s<N>/retro.md` |
| `extensions/roles/dev-domain.md` | `docs/retro/sprint-294.md` | `docs/retro/s294/retro.md` |
| `extensions/roles/qa-domain.md` | `docs/retro/sprint-176.md` | `docs/retro/s176/retro.md` |
| `extensions/roles/qa-domain.md` | `docs/retro/sprint-294.md` | `docs/retro/s294/retro.md` |
| `extensions/steps-domain/deploy-validate-push.md` | `docs/retro/sprint-249.md` | `docs/retro/s249/retro.md` |
| `extensions/steps-domain/discovery-prior-decision-corpus.md` | `docs/retro/sprint-*.md` | `docs/retro/s*/retro.md` |
| `extensions/steps-domain/sprint-review-domain.md` | `docs/reviews/sprint-<N>/**` | `docs/reviews/s<N>/**` |
| `overrides/steps__retro__ci-gates-enforcement-surface.md` | `docs/retro/sprint-168/171/174.md` | three separate `docs/retro/s168|s171|s174/retro.md` |

**EIGHT OF THE TWELVE ARE PROSE YOUR OWN MIGRATION LEFT BEHIND.** Your `docs/retro/` is already
294 `s<N>/` directories and `validate-artifact-paths.sh` reports PASS over your tree — the
FILENAMES are right; only the prose that cites them was never updated. Each cited file is gone and
each slotted form exists (checked, all six).

**The last row is prose shorthand for three retros** that the extractor reads as one path. It is a
true finding with an ugly quotation, not a false positive: all three spellings are dead and the
remedy is right for all three.

**Fixing them is optional and not part of this pull.** They are WARN. If you fix them, do it as its
own commit after the pull merges, so a pull-review diff stays a pull-review diff.

**`contract_version` also goes 17 → 18**, so all 43 entries report `behind`. They already did
(`at_current=0`); the delta is one clause added to the migration worklist.

### Done-when for §1

- [ ] `/ai-dlc-update` worklist worked top to bottom, PR merged
- [ ] **`0 HARD-*` blockers**, asserted from the post-merge re-run and not remembered from the dry run
- [ ] the stamp reads `0.335.0` on all four fields
- [ ] `scripts/ai-dlc/audit-layer-debt.sh` OPEN and UNDECLARED lists in the report, as every pull
- [ ] the 12 `W11` rows present and **recorded in the report as expected, not as a finding**

---

## §2 — Home the S299 LOCKED block into `s299/locked-requirements.md`

**VERIFIED STILL OPEN 2026-08-09.** `_bmad-output/planning-artifacts/s299/locked-requirements.md`
does not exist, and the live brief still carries **6** `LOCKED_REQUIREMENTS` mentions.

### What moves

`_bmad-output/planning-artifacts/product-brief.md`:

- `## In-Force LOCKED_REQUIREMENTS Blocks` — **lines 244–807, 564 lines**
- inside it, `### LOCKED block: S299` — **lines 251–430, 180 lines**

**Move the S299 block. Leave the section heading and its pointer.** The brief keeps a pointer to
the slotted file; it stops carrying the block.

### Why this is safe, and it is a mechanism rather than a hope

**99 files cite an `LR-S299-` anchor.** They keep resolving because v0.323.0 shipped
`resolve_artifact` taking the anchor and trying the sibling `s<n>/` first when it carries
`LR-S<n>-`. **Your tree has that resolver** (confirmed: `scripts/ai-dlc/` carries the `LR-S`
handling). Without it this move would break 99 files; with it, nothing moves but the bytes.

**The SoR is a PAIR, on purpose.** `locked-requirements.md` AND the legacy `product-brief.md` are
both accepted sources of record — refusing the legacy name would have failed **31 of 62** anchored
citations, all resolvable and none defective. **So nothing breaks before this is done, and nothing
breaks after.** The legacy name has a removal TEST, not a date: the PASS line counts the claims
still at it.

### Done-when for §2

- [ ] `_bmad-output/planning-artifacts/s299/locked-requirements.md` exists and carries the block **byte-identical** to what the brief held
- [ ] the brief's `## In-Force LOCKED_REQUIREMENTS Blocks` section carries a pointer, not the block
- [ ] `scripts/ai-dlc/validate-locked-anchor.sh` green
- [ ] spot-check **three** of the 99 citing files, from three different directories, and confirm each still resolves

---

## §3 — Home the brief's `## Changelog` section into `s<N>/changelog-product-brief.md`

**VERIFIED STILL OPEN 2026-08-09.** The brief carries `## Changelog` at **line 808, running to line
1031 — 224 lines**, and no `s<N>/changelog-product-brief.md` exists anywhere.

### What moves and where

Move the section to `_bmad-output/planning-artifacts/s<N>/changelog-product-brief.md`, where `<N>`
is the sprint that **produced** the content — not necessarily the live sprint. **If the section
spans several sprints, split it by sprint rather than filing all of it under s302.** A byproduct's
sprint is never in its content, so derive it from the adding commit's own subject:

```
git log --follow --format='%h %s' -- _bmad-output/planning-artifacts/product-brief.md
```

**Do not use a DATE join to decide the sprint** — graph starts more than one sprint on some days,
so a date is too coarse. That was measured.

### The size claim, and why it is not the reason to do this

**`## Changelog` is 224 lines of the brief's 1031.** But across ALL live durable artifacts the
changelog total is only **260 lines** (223 brief, 37 `docs/architecture.md`, **0** `prd.md`) — the
other ~9,800 changelog lines are in `-history.md` files the budget already exempts.

**So this is a CORRECTNESS change, not a size one**: nothing reads a changelog, and a durable
artifact that is read whole should not carry 224 lines nobody reads. **It governs future passes
only.** Do not expect a budget row to move.

### Done-when for §3

- [ ] `_bmad-output/planning-artifacts/s<N>/changelog-product-brief.md` exists, per the sprint each entry belongs to
- [ ] the brief no longer carries `## Changelog`, and points at the slotted file(s)
- [ ] `scripts/ai-dlc/validate-artifact-budget.sh` green
- [ ] the sprint attribution derived from the ADDING COMMIT, and the derivation recorded in the commit message

---

## Deliberately NOT in this file

**These are carried in graph's own ledger and none is this repo's to schedule work behind.** Named
here only so you do not read their absence as an oversight:

- **`PC-S329`'s disposition** — unblocked by v0.330.0, which resolved the contradiction that made
  it ambiguous.
- **`PC-S312`'s receipt** — needs re-anchoring at `docs/retro/s249/retro.md` or it reports
  `NEEDS-REVIEW` on every pull.
- **the `921.`/`20.` retire-or-refile call** — open across five reports now.
- **the `dev-push.md` split** behind `OWED-DEVPUSH-RESTATES-CORE`, and the other open obligations
  in the debt audit. Consumer-side, bounded, blocking nothing.
- **the 48 refused artifact-path migrations** — 45 AMBIGUOUS, 3 NO-AREA. Renaming basenames and
  deciding an area. Nobody's critical path.
- **the 33 byproduct files at the area root** — a MOVE into the sprint slot of the pass that
  produced them, **never a delete**: older coverage reports cite draft paths as their no-loss
  evidence.

## When you are done

**Ping the operator** with: the hop count the dry run actually took, the `HARD-*` count from the
post-merge re-run, whether the 12 `W11` rows appeared as described, and which of §2 and §3 you
completed. **If you stopped early, say where and why** — an early stop reported is a result; an
early stop unreported is a stall.
