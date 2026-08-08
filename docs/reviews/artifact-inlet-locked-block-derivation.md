# Does the `LOCKED_REQUIREMENTS` source-of-record move into `s<N>/`?

Item 23c of [`docs/plans/retire-graph-consumer-layer.md`](../plans/retire-graph-consumer-layer.md),
first step. The item forbids opening with code: *"`LOCKED_REQUIREMENTS` is read by four core
validators and ten step files … whether the other thirteen sites move is UNDERIVED, and deriving it
is the whole of 23c's first step. If the derivation says they do not move cheaply, say so and
stop."*

Measured 2026-08-08 against ai-dlc `main` at `0.320.0` and against `/Users/n8/git/graph` at
`54e71012a`, read-only. Every figure below was derived in this pass; none is inherited from the
plan.

---

## The answer

**The sites move cheaply — and that was the wrong question on its own.** Four validators touch the
chain; **one is not a site at all**, two move for free, and the fourth moves on a one-word default
plus one prose edit. The read side is not what makes 23c hard.

What makes it hard is that **the instrument that would report 23c's success is exempt from the new
location by construction.** `validate-artifact-budget.sh` excludes every `s<N>/` path from the
whole-read pool (`is_sprint_slotted`, called at `core/scripts/validate-artifact-budget.sh:859`).
Move the sprint's LOCKED block from `product-brief.md` into `s<N>/` and the pooled sum falls by
three quarters of the brief **without one byte less being read at gate time** — the analyst still
reads the current sprint's block whole. A 23c that reports its win from the budget row is measuring
its own exemption.

So: proceed, but the pool set is part of the change, not a follow-up.

---

## What the move is worth, measured

The plan carried item 19's datum — *"7 of 7 headings added to `product-brief.md` in the six days
after its 08-02 pass are sprint-scoped"*. That understates it. Partitioning the whole live brief by
heading, span-to-next-same-or-shallower:

```
_bmad-output/planning-artifacts/product-brief.md   1030 lines, 16 headings

  ## Synthesized Current-State (derived — Step-2 sanctioned)      182   17%   DURABLE
  ## In-Force LOCKED_REQUIREMENTS Blocks (verbatim)               564   54%   SPRINT
       ### LOCKED block: S299                                     180
       ### Discovery Findings & Implementation Sequence — S301     377
  ## Changelog  (4 entries, all 2026-08-05, all S301)             223   21%   SPRINT
                                                          ------------------
  sprint-scoped                                                   787   76%
```

**17% of the durable artifact is durable.** The two other pooled artifacts, by the coarser
sprint-token-heading measure:

```
  carry-over-backlog.md   58 sprint-token headings covering  1528 of 1647   92%
  prd.md                   7 sprint-token headings covering   265 of 1530   17%
```

The `Discovery Findings & Implementation Sequence — S301` section is worth naming separately: 377
lines, 36% of the brief, filed **under** the LOCKED-blocks heading while not being a LOCKED block.
The delimited block itself is lines 253–421, 169 lines. Any 23c edit keyed on the sentinels moves
169 lines and leaves 377 behind.

### The changelog has no reader anywhere in core

Core prescribes appending one at six sites — the rule at `core/skills/ai-dlc/SKILL.md:554`
(*"After each validation cycle, append a brief changelog to the artifact"*), the generic step
instruction at `core/skills/ai-dlc/steps/_gate-procedures.md:205`, and four convergence lines that
name a durable target: `discovery.md:245` (the brief), `research-requirements.md:127` (the PRD),
`architecture.md:289` (the architecture doc), `doc-repair-backfill.md:45` (all modified artifacts).
Three further sites append to story files, which already sit in a sprint slot and are not the
inlet.

**Nothing reads any of it.** `change[ -]?log` over `core/scripts/` and `core/hooks/` matches five
lines, all of them in `validate-mandatory-rules.sh`, all about the *validation-cycle-log* model
rather than the artifact changelog — and one says so outright: *"in per-artifact changelogs
(freeform prose, not countable here)"* (`:139`). Positive control on the same paths:
`LOCKED_REQUIREMENTS` matches in five files. **21% of graph's brief is write-only content inside a
pooled whole-read artifact.**

> A false zero was caught producing this figure and is worth carrying: `git grep -in 'change ?log'`
> without `-E` treats `?` literally in BRE and returned **nothing**, and the fabricated-token
> control returned rc=1 as well — so the control agreed with a zero it could not distinguish. The
> `-E` form returns matches in twenty files. A control has to be a token you know is PRESENT.

---

## The site table, derived

The plan's *"four core validators and ten step files"* is right on the validators and does not
match either measurable step-file set. **8** step files name the `LOCKED_REQUIREMENTS` token; **13**
name one of the durable artifacts by path. Ten is neither.

### Validators — 4 named, 3 real

| site | what it does with the SoR | move cost |
|---|---|---|
| `core/scripts/validate-locked-anchor.sh` | The pin is a **basename equality test** at `:475` against `DEFAULT_SOR_BASENAME` at `:129`, already overridable by `--sor`. `resolve_artifact` (`:301-346`) tries the story's own directory first, then cwd, then walks up six levels for the bare basename. | **One-word default + one caller edit.** A story in `s<N>/stories/` reaches `s<N>/<sor>` before the area root, so per-sprint resolution is what the existing walk-up already does. |
| `core/scripts/validate-request-coverage.sh` | Takes `--brief <file>` from the caller (`:79`) and delegates block extraction to the anchor script's `--emit-blocks` (`:118`). | **Free.** Its only caller is prose — `gate-validation.md:2248` — and that already writes `--brief <brief>` as a placeholder rather than a path. |
| `core/scripts/validate-spec-join.sh` | Anchors join (1) on the spec folder's `.memlog.md` (`:132`), deliberately, never on the brief. | **Not a site.** It names the token in two comments and reads no artifact the move touches. |
| `core/scripts/validate-artifact-budget.sh` | `WHOLE_READ_SET` (`:271`) is basename-keyed over a recursive `find` (`:856`), minus `is_archive`, `is_not_artifact` and `is_sprint_slotted` (`:859`). | **Free — and that is the defect.** See below. |

### The pool exemption is the real work

`is_sprint_slotted()` (`:429-437`) exists for a good reason and v0.317.0 shipped it for a good
reason: after item 10's migration every historical `architecture-s251.md` became
`s251/architecture.md`, and the pool started summing 26 archived copies as live. Excluding every
`s<N>/` component fixed a 2.35x overstatement.

But it is path-shaped, not sprint-aware. It cannot say *"the CURRENT sprint's slot is live, every
other slot is archive"*. So under 23c:

- the brief shrinks by ~76% and the pooled sum falls with it;
- the current sprint's LOCKED block, still read whole by the analyst, is counted **zero**;
- the row goes green for a reason unrelated to anything getting smaller.

That is the inert-instrument class this plan keeps finding, arriving through the change meant to
fix the thing the instrument measures. **Any 23c release must make the pool sum the live sprint's
slot**, which means resolving the current sprint inside the budget validator — the one 23a already
had to fix twice.

### Steps and roles — where the pin is restated in prose

The basename pin is mechanised once and restated twice, and both restatements are normative:

- `core/skills/ai-dlc/steps/stories-test-strategy.md:372-373` — *"`full_text_source` still resolves
  to the product brief and nothing else."*
- `core/skills/ai-dlc/steps/gate-validation.md:411-415` — restates the default and names
  `discovery.md` §4a as where the block is extracted.

Both must move with the default or 23c re-creates item 27's defect exactly: contradicting prose over
one mechanised branch. The remaining token sites are propagation or policy and do not name a path —
`discovery.md` (7, the writer, §4a at `:114-134`), `research-requirements.md:93` (copies the block
into the PRD), `stories-test-strategy.md:338` (copies the PRD's block into each story),
`carry-over-evaluation.md:207`, `implementation.md:364`, `retro.md:76,475`,
`_gate-procedures.md:249,365`, plus `team-roles/remediator.md` (4) and `pm-escalated.md` (1) and
three hooks, all of which say only *do not delete a locked requirement*.

**Core already prescribes the accumulation.** `discovery.md:127-128`: *"A brief accumulates one
block per sprint, and the closer may carry a discriminator so they can be told apart."* The inlet is
not consumer drift; it is written down as the design.

---

## Two things that make the move safe today, one of them by accident

**Cross-sprint LR references exist in prose and not in anchors.** Across graph's 988 story files,
`LR-S<n>-` tokens resolve to the story's own sprint slot **3759** times and to a *different* sprint
**260** times (141 more in stories not under a slot) — so cross-sprint reference is real. But the
anchored citations are a much smaller set: **62 citation lines in 46 of 988 story files** (26
`full_text_source:`, 36 `requires_context:`), and **0 of them cross a sprint**. Per-sprint walk-up
resolution is therefore correct on today's corpus.

It is correct by accident. Nothing forbids a cross-sprint `full_text_source:`, and Rule 13 makes
locked requirements cumulative, so the first story that anchors an older sprint's LR resolves to the
wrong file or to none. **A 23c that splits the SoR owes an explicit rule about cross-sprint
anchoring** — either forbid it at the validator with a message, or resolve `LR-S<n>-` to `s<n>/`.

**31 historical citations name the full area-root path.** Of the 62, 31 cite
`_bmad-output/planning-artifacts/product-brief.md` outright rather than a bare basename, so they
dangle after a move. They are not re-validated — Check 3b runs per-story at the current sprint's
gate — so this is a recorded acceptance, not a blocker. The same acceptance item 10 already took.

**And no sprint slot holds a competing copy today**: `s<N>/product-brief.md` = 0,
`s<N>/prd.md` = 0, `s<N>/carry-over-backlog.md` = 0, `s<N>/architecture.md` = 23 (the migrated
archives `is_sprint_slotted` exists to exclude). So the walk-up cannot currently pick a per-sprint
brief over the live one, and the first thing 23c writes is also the first thing that could.

---

## What 23c is, restated from the derivation

Not *"move `LOCKED_REQUIREMENTS`"*. Four changes, and the plan's framing carries only the first:

1. **The writer.** `discovery.md` §4a writes the sprint's block to the sprint slot instead of
   appending to the brief; the brief keeps a pointer.
2. **The pin.** `DEFAULT_SOR_BASENAME` and the two prose restatements move together, with a stated
   answer for cross-sprint anchoring.
3. **The changelog.** Six prescribing sites, zero readers, 21% of the live brief. This is
   separable from 1 and 2 and is the cheapest real reduction available.
4. **The pool.** `is_sprint_slotted` must stop exempting the live sprint, or the change grades
   itself.

Item 23c's own stop condition is not met: the sites move. But **(4) is not optional and is not
small**, and (3) would stand alone as a release if (1) and (2) turn out to cost more than they
look.
