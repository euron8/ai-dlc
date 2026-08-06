# Retire graph's consumer layer by absorbing upstream into core

---

# RESUME HERE — state as of 2026-08-06

## Start here

**This file is the plan of record. Everything above `## Context` is current; everything below
it is the original design record, kept for rationale. Where they disagree, the top wins.**

Working repo: `/Users/n8/git/ai-dlc` (the distribution). Reference consumer:
`/Users/n8/git/graph` — **read it, never write it.** The operator owns every consumer-side
action: running `/ai-dlc-update`, merging its PR, retiring layer entries. House rules for this
repo are in `/Users/n8/git/ai-dlc/CLAUDE.md` and they bind: one version per branch cut from
`origin/main`; commit subject + `VERSION` + CHANGELOG heading are one claim; every absence
carries a same-run control; every mutant is a `cmp -s`-guarded copy with an unmutated control;
measure a new check's false-positive set before shipping it.

**OPERATOR STANDING DECISIONS, 2026-08-06. These override the per-step "ask first" notes
below, and a session following this file must not re-ask them.**

- **Merges are preapproved for the duration of this plan.** Cut the branch from `origin/main`,
  open the PR, and merge it. Do not stop for merge approval on any release in this file.
- **Do not pause between releases.** Run release to release without checking in unless the
  operator is genuinely needed for a decision this file does not already record. Starting a
  fresh session when context fidelity degrades is expected and cheap; pausing is not.
- **s301 is being CLOSED and re-run from scratch as s302**, the way s300 was, and s302 does not
  start until everything in this plan has landed and been pulled. The operator accepts the
  rework because the re-run is itself the control test: it measures whether these changes have
  their intended effect on a sprint that has already failed once without them. A close-out
  prompt for the graph session is owed as part of this work.

**Do these in order. Stop and ask if a step's premise no longer holds — several below were
true at 2026-08-06T20:05Z and are worth re-verifying before acting.**

1. ~~Confirm with the operator whether the two-hop graph pull has happened yet.~~
   **ANSWERED 2026-08-06: it has not, and it is now sequenced AFTER this plan's releases**, so
   that s302 starts on a fully-updated consumer. Still the operator's to run; still two hops
   (§*pull graph in TWO hops*). graph's stamp was re-measured at `0.274.0 @ 9036e0d`.
2. ~~**Fix `validate-locked-anchor.sh`.**~~ **COMPLETED — shipped as v0.280.0.** All three OPEN
   `PC-S297-LOCKED-ANCHOR-*` candidates discharged. See §*What v0.280.0 measured*.
2b. **Absorb Rule 930's count-control discipline and give it an enforcer** — one layer earlier
   than the citation drift: a bare `grep -c` yields a false number that becomes an AC, which
   the adversary then spends a pass falsifying. **Do NOT build a shell-file linter for this.**
   Measured: the defects are in markdown derivations, not in `*.sh`. See §*The shell-idiom
   family IS in this sprint*. **Measured since:** core's shipped `SKILL.md` carries 30 rules
   and ZERO count-control discipline (control: the same grep finds all 30 rule headings), so
   the absorption target is a new core rule, numbered in core's band — not 930, which is
   inside the consumer band I45 reserves. Whether a mechanical enforcer is viable at all is
   under measurement; if its false-positive set is large and unclassifiable, **ship the rule
   and say so** rather than shipping a lint the operator turns off.
3. **Make the adversarial STALL rung reachable mid-cycle.** It fires correctly at p7 and goes
   silent once the cycle converges, so today it caught nothing.
4. ~~**R4 — snapshot ceiling.**~~ **COMPLETED — shipped as v0.281.0 (#369).**
5. ~~**R3 — auto-handoff.**~~ **COMPLETED — shipped as v0.282.0 (#370)**, carrying the
   multi-key `settings_env_keys:` mechanism with it.
6. **R6 — promote LC-E6/LC-O15 to ADJUDICATED.** Was blocked until graph burned down its
   `EXTENSION-TITLE-MATCHES-CORE` set. **s301's closure changes the sequencing, not the
   gate**: the burn-down still has to happen on the two-hop pull before promotion, or first
   contact wedges on ~13 blocking rows. Ship it last.
7. **Audit the steps s301 never reached** for the defect classes v0.280.0 found in the steps it
   did reach. s301 stalled at `stories-test-strategy.md` §4, so every downstream step is
   unexercised. The five measured classes are listed in §*What v0.280.0 measured*.
8. **Triage graph's push-candidate ledger** — 123 `## PC-` entries, of which roughly 57 are
   upstream-facing and OPEN. Re-run each `verify:` receipt against the current core tree
   before proposing anything; several are documented as having gone blind, meaning the
   substring is absent at base AND at theirs, so the entry can never close.
9. **Write the s301 close-out prompt** for the operator to paste into the graph session,
   mirroring what the s300 close-out did. Owed as a deliverable, not optional.

**Do NOT redo R1, R2 or R5** — they are merged as v0.275.0/v0.276.0/v0.277.0, and their
sections in the design record below are labelled SHIPPED.

## Where things stand

**ai-dlc is at `0.278.0`, `contract_version` 16.** Four releases shipped and merged to `main`:

| release | PR | what it does |
|---|---|---|
| v0.275.0 | #361 | **enablers.** Unnumbered headings now join (`EXTENSION-TITLE-MATCHES-CORE`, LC-E19, WARN) — 27 of graph's 38 entries were previously invisible. Env-keyless `override_supersessions:` can fire, so "core adopted your prose" is declarable. |
| v0.276.0 | #362 | absorbs Check 7 non-vacuity, carry-over item-5 sprint boundary, `dev.md` conditional local-launch → **3 overrides retirable** |
| v0.277.0 | #363 | absorbs qa gate-2 go-signal, code-reviewer context-*shape* severity, pm probabilistic-AC + numeric anchor → **2 extensions retirable** |
| v0.278.0 | #364 | `ai-dlc-update <ref>` / `<ref> apply` target-ref argument, plus `self-update-gate.sh --safe-stop` and a `SELF-UPDATE-SAFE-STOP` row on every DEFER |
| v0.279.0 | #365 | plans that must survive a session live in `docs/plans/`; `scripts/validate-plan-shape.sh` enforces a resumable shape and pre-push runs it. **This file is its first subject.** |
| v0.280.0 | #367 | Check 3b resolves the `requires_context:` load pointer, scopes the byte-match to the cited anchor, and stops spelling a zero-verification PASS like a verified one. Discharges all three OPEN `PC-S297-LOCKED-ANCHOR-*` candidates. |
| v0.281.0 | #369 | `validate-artifact-budget.sh --fail-on <artifact>` plus a supersession-marker arm. Retires `steps__retro__pipeline-snapshot-ceiling` as a CONFIGURED supersession (`AI_DLC_SNAPSHOT_STRIKETHROUGH`). |
| v0.282.0 | #370 | `AI_DLC_AUTO_HANDOFF_MODE` + `AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED`, and the `settings_env_keys:` multi-key supersession mechanism. Retires `SKILL__auto_handoff_mode`. |

**Two absorptions did NOT come up wholesale, and both refusals are worth carrying forward.**
A consumer override is evidence that a consumer needed something; it is not evidence that core
is wrong. In v0.281.0 the override's bare-`~~strikethrough~~` arm turned `inflight-row-shape`
red — a fixture that already held a struck line outside the dispatch ledger is out of scope,
because Recent Activity legitimately strikes superseded entries. Core's position predated the
work and had a fixture behind it, so it won by default and the stricter posture became a key.
That is the better outcome anyway: it turns an adopted retirement into a CONFIGURED one, which
is the shape the whole mechanism was built for. **Run the absorbing change against the full
fixture suite before believing the absorption is clean** — the conflict surfaced as a
red fixture, not as anything visible while reading the override.

**graph has received NONE of it.** Its stamp is still `version: 0.274.0 / commit: 9036e0d`,
re-measured 2026-08-06 from `_bmad-output/ai-dlc-update/reconcile-report.md:3`.

## What v0.280.0 measured, and the five defect classes it names

Recorded here because item 7 above audits the unreached steps against exactly these, and
because the numbers are the reason the release was worth cutting.

Against graph's whole story corpus, with the SHIPPING script, before any edit:

```
998 story files
  PASS, 0 claims verified   196     <- including 10 of 10 in the LIVE sprint
  PASS, >=1 claim verified    0     <- never once, in the entire corpus
  FAIL                      802
```

Every s301 block cited only `requires_context:`, which the script recognised as a presence and
never resolved. The sprint's adversary hand-verified citations across eight passes because
nothing mechanical did. **34 of 47 pointers in the corpus named an anchor absent from the
artifact they cite.** The change moves 992 of 998 verdicts not at all; all six that move are
dangling anchors confirmed with a same-file control returning non-zero.

The classes, each measured rather than hypothesised:

1. **Zero-verification PASS** — success has two roads, "everything verified" and "nothing to
   check", sharing one exit code AND one report line.
2. **A check that cannot fire** — an extractor that silently matches nothing.
   `core/scripts/validate-ac-falsifiability.sh:244` extracts `prior_evidence:` citations
   line-initial only, so a mid-sentence one is invisible.
3. **Co-presence mistaken for anchoring** — a match scoped wider than the claim, succeeding on
   text the claim does not name.
4. **A count with no control** — a bare `grep -c` whose zero is indistinguishable from a
   pattern that cannot match, whose false number becomes an AC. This is item 2b.
5. **Entangled or cross-product assertions** — the bullet loop sat inside the citation loop,
   demanding every bullet be present at every anchor.

**One arm of the original plan was REFUTED by measurement and must not be rebuilt.** The plan's
§*Findings* attributes the eight-pass cost to `validate-locked-anchor.sh` on the strength of
p3's `MAJ-p3-2`. That finding actually names class 2 in a *different* script,
`validate-ac-falsifiability.sh`, and the defect it reports **is already repaired in graph's
tree**. Building the obvious fix — disarm on a `prior_evidence:` token that is not line-initial
— was measured against the live sprint first: **8 occurrences, 8 of them false positives**, all
prose quoting the token inside repair-history sections. It was not built. Class 2 is real and
belongs in the item-7 audit; that particular enforcer is not the way to catch it.

## The one thing that must not be forgotten: pull graph in TWO hops

A bundled `0.274.0 → 0.278.0` pull returns `SELF-UPDATE-DEFER`, so the machinery slice lands at
step 7 — *after* step 3's classify. The stale engine then classifies, and the three absorbed
overrides come back as ordinary `HARD-OVERRIDE-DRIFT-SECTION` ("re-adopt the new wording"),
with **zero** `OVERRIDE-SUPERSEDED` and **zero** `EXTENSION-TITLE-MATCHES-CORE` rows. Measured,
not predicted.

```
git -C /Users/n8/git/ai-dlc checkout d4df7c0    # v0.275.0 — machinery only, gate returns SELF-UPDATE-OK
# /ai-dlc-update apply
git -C /Users/n8/git/ai-dlc checkout main
# /ai-dlc-update apply
```

Second hop then yields **3 `OVERRIDE-SUPERSEDED`** + **13 `EXTENSION-TITLE-MATCHES-CORE`**
(verified on a scratch copy). v0.278.0's `--safe-stop` derives `d4df7c0` automatically, but
**cannot help this pull** — step 2 runs graph's own installed gate, which is at 0.274.0 and
emits zero SAFE-STOP rows. This one split is manual; after it, it is permanent.

## Mid-sprint safety (asked and answered with evidence)

Nothing in the tree gates the pull on sprint state (grep + control: zero hits). Steps 6–7
branch before any write and require **explicit operator approval** to merge, separate from the
`apply` arg — so a reconcile cannot mutate the sprint branch. Measured blast radius for the
whole range: **0 of 40 `core/scripts/` validators change**; 6 rulebook files change; exactly
one live-gate behaviour change (Check 7 non-vacuity, +7 lines).

Practical split: **hop 1 is safe mid-sprint** (machinery only, nothing a sprint executes).
**Hop 2 carries all six rulebook files** — take it at a sprint boundary, or `apply` and leave
the reconcile PR unmerged until retro.

## Still open

- **R3 auto-handoff** — blocked on a decision: `override_supersessions` allows one
  `settings_env_key` and auto-handoff needs two (`AI_DLC_AUTO_HANDOFF_MODE` +
  `AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED`). Prefer a `settings_env_keys:` list rendering N ATOMIC
  worklist rows. Retires `SKILL__auto_handoff_mode`.
- **R4 snapshot ceiling** — `validate-artifact-budget.sh --fail-on <artifact>` + a
  supersession-marker arm. Retires `steps__retro__pipeline-snapshot-ceiling`.
- **R6 promote LC-E6/LC-O15 to ADJUDICATED** — only after graph burns down the 13-row
  `EXTENSION-TITLE-MATCHES-CORE` set, or first contact wedges on ~13 blocking rows.

## Known gaps, deliberately not closed

- Both absorption arms join on **markdown headings**. `pm-domain.md` is all bullets (0
  headings), so its retirement can never be reported; retire it by hand. Bold-prose anchors
  were scoped out of v0.275.0.
- `self-update-gate.sh`'s advisory re-entry guard (`AI_DLC_GATE_IN_SAFE_STOP`) is a **cost**
  measure, not a termination one, and is deliberately uncovered by any assertion — no
  observable output distinguishes the two. Documented in the script and the fixture.

## Open thread at the end of the session

The operator issued a handoff in graph and the sprint has not reached implementation after
hours. Sprint 301 (`eth-rewards-base-v4-pool-indexing`, variant `carry-over`, intensity
`full`), at `stories-test-strategy.md` Section 4 Story Validation Cycle, **mid-cycle**;
`_bmad-output/.beat-inflight` present, 15 dirty paths, `core.hooksPath` unset so the pre-push
hook is not armed.

### Findings (investigated 2026-08-06T20:05Z)

**The stall is the story-validation adversarial cycle, and it is repair-induced.** 44 spawns
on 2026-08-06, of which **15 adversary + 13 remediator = 28 (64%)**. Eight adversarial passes
`p1…p8` (06:51 → 15:02) plus eight repair/resolution artifacts; spawn churn continued to 19:33.
Never left `stories-test-strategy.md`.

Verdict series from `validate-adversarial-convergence.sh --series`:

```
p1 NOT_MET  c=0 m=4      p5 NOT_MET  c=0 m=1
p2 DIVERGENT_HARD_BLOCK  p6 NOT_MET  c=0 m=2
   c=1 m=2               p7 NOT_MET  c=0 m=2
p3 NOT_MET  c=0 m=2      p8 MET      c=0 m=0
p4 NOT_MET  c=0 m=1
```

p3–p7 is a **five-pass plateau at zero CRITICAL / one-to-two MAJOR** — the exact shape the
STALL rung was built for: neither converging nor diverging, so every other rung says "run
another pass". The later passes are almost entirely citation drift, and each repair moves the
line ranges the previous pass verified (p7: *"the two ADR edits shifted two `requires_context`
ranges that p6 had [corrected]"*).

**The detector works and nobody ran it.** Re-running the validator over `p1…p7` only:

```
FAIL (E -- STALL): the cycle held a nonzero MAJOR at ZERO CRITICAL across 4
consecutive passes (from p5 through p7). It is neither converging nor diverging.
```

It fires at **p7 (14:22)**. Once p8 stamped `EXIT_CONDITION_MET` the rung goes silent by
design (no false fire on a converged cycle) — so post-hoc it says nothing. **Operational
lesson: run `validate-adversarial-convergence.sh --series` MID-cycle, not at the end.**

**A second live violation, still open:**

```
FAIL (F -- RESOLUTION): p3 claims to resolve p2, but resolution-p2.md cites
operator_authorization, and no readable transcript was provided (--transcript).
```

**The broken machine check underneath** is `validate-locked-anchor.sh` — p3's MAJ-p3-2 reads
*"both new `prior_evidence:` citations are unresolvable, and clear the validator only by line
position."* graph's own ledger already carries three OPEN candidates for it:
`PC-S297-LOCKED-ANCHOR-BYTE-MATCH-IGNORES-THE-ANCHOR`, `-VALIDATOR-VACUOUS`,
`-EXEMPTED-BY-SILENCE`. Because the mechanical citation check clears on line position, the
adversary had to verify citations **by hand, eight times**.

### Do the four staged releases fix any of this? NO.

Checked one by one, and the honest answer is none of them touch it:

| release | bearing on this stall |
|---|---|
| v0.275.0, v0.278.0 | pull-time layer tooling — zero effect on sprint execution |
| v0.276.0 | Check 7 non-vacuity ADDS a gate assertion; carry-over item 5 is the bug-variant boundary; `dev.md` is a launch bullet |
| v0.277.0 | closest is pm.md's probabilistic-AC rule, but p1's findings were citation accuracy and Rule 26 waiver suppressors — not probabilistic ACs |

### The shell-idiom family IS in this sprint — in the derivations, not the scripts

Operator correction, checked and confirmed. A first probe over graph's **committed shell**
found almost nothing: 183 consumer-owned files, 2 benign bracket-class hits, and **zero files
even enable `pipefail`**, so the I54/I54b precondition never applies. That result is real and
it is also the wrong corpus.

The defects live in the **derivation commands the agents run and cite**, which sit in markdown
prose, not in `*.sh`. In the s301 record: `grep -c` appears 214 times, `sed` 428, `wc -l` 85,
`awk` 45 — and the passes are full of them going wrong:

- `s301-epics-repair-p5d.md:115` — *"BSD `grep` has no `-P`; the first attempt at this
  enumeration returned a vacuous `0`"*
- `s301-stories-adversarial-p6.md:252` — *"not by the label grep whose zero could not be told
  from a vacuous pattern"*
- `s301-stories-repair-p5.md:581` — *"the grep would have produced a false finding. This is the
  same silent-zero shape…"*
- `s301-stories-adversarial-p2.md:327` — a confirming grep *"scoped to the wrong file"*

**This changes what v0.280.0 should be, and the fresh session must not build the version
described in the session transcript.** A shell-idiom validator over `*.sh` would have caught
**none** of the above, because none of it is in a shell file. Every count and range citation in
a story is produced by one of these commands; a vacuous grep yields a false number, the number
becomes an AC, and the adversary then spends a pass falsifying it. That is the same loop as the
citation drift — one layer earlier.

The consumer already has the right rule and no enforcer: `SKILL-domain.md` Rule 930 says *"Pair
every count with a control that proves the pattern CAN match. `grep -c` counts LINES, not
entries… a bare count is indistinguishable from having examined nothing."* Unabsorbed, and
unenforced on either side.

**The real next work, in priority order:**

1. **Fix `validate-locked-anchor.sh`** (three OPEN candidates above) — anchor-scoped matching
   instead of line-position, non-vacuous claim counting, and no pass-by-silence on a
   zero-bullet block. This is the mechanism whose absence cost eight hand passes.
2. **Make the STALL rung reachable mid-cycle** — a rung that only speaks after the cycle ends
   is a rung nobody hears. Either the story-validation loop runs the validator every pass, or
   the step file mandates it at pass 3+.
3. Discharge the p2→p3 `--transcript` resolution violation.

---

## Context

`/Users/n8/git/graph` is the reference consumer of this distribution. It carries **11
overrides** and **38 extensions** in `.claude/skills/ai-dlc/{overrides,extensions}/`. Every
one of those is a divergence core has to be pulled through by hand on every release, and an
override freezes its *entire shadowed span* at `base_sha` — so unrelated core fixes stop
reaching the consumer. That failure is already documented: v0.268.0's Check 14 fix never
reached graph because an override shadowed the whole check.

The question asked was what to bring upstream so those entries can be retired. Reading the
drift detection produced a harder answer first: **the detector that is supposed to report
retirements is structurally unable to see most of them, and core has no way to say "I
absorbed your prose."** Both were measured, not inferred. Until they are fixed, absorbing
prose upstream retires nothing, because nothing tells the consumer it happened.

So this plan ships the enablers first, then the absorptions that are cheap and unambiguous,
and ends with a verification that the next `/ai-dlc-update` on graph *actually* surfaces the
retirements — run against a scratch copy of the real consumer, not predicted.

### What the drift detection currently reports

`_bmad-output/ai-dlc-update/reconcile-report.md` at 0.273.0 → 0.274.0: 0 HARD blockers,
**1** `EXTENSION-RESTATES-CORE`, 2 `OVERRIDE-DELEGATES-INTO-SHADOW`, 2
`OVERRIDE-DOUBLE-SHADOW`, 1 `OVERRIDE-ASSERTS-SHADOW-SURVIVES`. Layer debt: OPEN 0,
UNDECLARED 6. The register holds 61 rows — 58 `still-additive`, 3 `contradicts-core`,
**0 `retire`**. In the register's whole history the pull has never once said "retire this."

### Blocker 1 — the absorption detector is blind to 27 of 38 extension entries (MEASURED)

`core/skills/ai-dlc-update/reconcile/layer-drift.sh:879` gates the entire absorption pass on
`[ -n "$ext_anchors" ]`, and `anchors_of_file()` (`:470`) harvests only headings matching
`ANCHOR_RE` (`:441`) — which requires a leading integer or a short uppercase id — plus
`bold_anchors_of_file()`, whose awk requires `^\*\*(Check[ \t]+)?[0-9]+`. An entry whose
headings are prose produces zero anchors, and the block is skipped entirely.

I ran the shipping functions verbatim against graph's 38 entries:

```
VISIBLE(has>=1 anchor)=11  BLIND(zero anchors)=27  TOTAL=38
CONTROL: same function on core/skills/ai-dlc/steps/gate-validation.md -> 42 anchors
```

The control is non-zero, so the harvester works; the 27 is a real absence. **Every one of the
8 role entries and every `SKILL-*` entry is blind.** This matches the consumer's own filing,
`PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS` ("both duplications found this
pull were found by hand"). At least four already-absorbed entries sit unreported behind it.

### Blocker 2 — core cannot declare "I absorbed your prose" (MEASURED)

`override_supersessions:` (`core/skills/ai-dlc/layer-contract.yaml:281`) is the one mechanism
by which core says an override is no longer NEEDED. It works — the v0.271.0/0.272.0 arc used
it, and graph's Check 14 override is gone as a result. But:

- `layer-drift.sh:648` — `[ -n "$sup_env" ] && emit OVERRIDE-SUPERSEDED ...`. Emission is
  gated on `settings_env_key`. A supersession that needs **no configuration** — core simply
  adopted the clause — can never fire.
- `supersessions_of()` (`:262-278`) already emits a TSV row with an empty env field, and
  `apply.sh:319-325` already has the else-branch that renders the single-row worklist item
  (`env_key=""` → `"core supersedes this entry: $detail"`). **Both ends already work. Only
  the one-line guard blocks it.**
- One `settings_env_key` per row, so a supersession needing two keys (Rule 8's two path
  lists) cannot be expressed.

Consequence: the cheapest, safest retirement class — "core took your paragraph verbatim" —
is currently *undeclarable*. It gates at least three of the eleven overrides.

### Third finding, which drives the release shape

`self-update-gate.sh` runs each incoming script the consumer's `.githooks/pre-push` invokes,
twice, and returns `SELF-UPDATE-DEFER` if the incoming one finds something new. On DEFER the
machinery slice folds into the operator-gated apply at step 7 — which runs *after* step 3's
classify. So on a mixed release, the new detector does not classify that pull.

**Therefore R1 must be machinery-only.** `layer-drift.sh` is not invoked by graph's pre-push,
so a machinery-only R1 returns `SELF-UPDATE-OK`, lands autonomously, and SKILL.md step 2
re-invokes the skill on the fresh engine — the retirements surface in the same invocation.
Mixing a rulebook edit into R1 pushes them a whole pull later.

---

## Status

Superseded — see **RESUME HERE** at the top of this file, which is the single current record.

## Release sequence

House rules apply throughout (`CLAUDE.md`): one version per branch cut from `origin/main`;
subject + `VERSION` + CHANGELOG heading are one claim; every mutant is a copy guarded by
`cmp -s` with an unmutated control; every absence carries a control in the same invocation.

### R1 — the enablers (MACHINERY ONLY) — **SHIPPED as v0.275.0**

Landed larger than planned, in three ways worth carrying forward:

- The title match got its **own status**, `EXTENSION-TITLE-MATCHES-CORE` (LC-E19, WARN), rather
  than reusing `EXTENSION-RESTATES-CORE`. A prose heading is not an identity claim, so the
  stronger status would have told the operator to delete entries that were merely *naming* the
  core section they augment — 6 of the 20 first-contact rows were exactly that.
- **`contract_version` 14 → 15 happens here**, not in R2. R2 and later renumber accordingly.
- `apply.sh` gained an `extension-title-match` worklist arm. Ground truth caught this: the
  classifier emitted 12 rows and `apply` emitted none, so they were an instruction with no
  owner.

Measured false-positive set: 20 rows on first contact → 12 after three derived exclusions, and
all 12 hand-verified true. Six mutants, unmutated control 0/0. The original plan text follows.


`core/skills/ai-dlc-update/reconcile/layer-drift.sh`

1. **Env-keyless supersession.** Change the `:648` guard from `[ -n "$sup_env" ]` to fire
   whenever the row matched at all (`sup_since` is present on every row). When `sup_env` is
   empty, emit a detail string carrying **no** `replaces_with=` token, so `apply.sh`'s
   existing else-branch renders the single "core supersedes this entry" row rather than the
   two ATOMIC rows. Do not touch `apply.sh` — it already handles both shapes.
2. **Title-only absorption pass.** Add a second harvest beside `anchors_of_file()`: the
   normalized TEXT of every `##`/`###`/`####` heading that `ANCHOR_RE` did *not* claim. Run
   it through the existing `same_section()` Jaccard predicate against theirs' heading texts
   and emit only `EXTENSION-RESTATES-CORE` / `EXTENSION-RETIRE-CANDIDATE` — **never**
   `EXTENSION-CHECK-NUMBER-COLLISION`, which has no meaning without a number. Restrict the
   pass to headings; bold-prose anchors (`**Falsification ladder.**`) stay out of scope and
   are named as such in the header comment.
3. **Measure the false-positive set before shipping** (`CLAUDE.md`: "Before adding a check,
   measure its false-positive set"). Run the modified script against graph and enumerate
   every new row. The `:440` comment names the exact hazard — a heading called "Scope"
   diffing against unrelated core prose. If the set is not empty and enumerable, raise
   `same_section`'s floor for the unnumbered arm rather than shipping a noisy detector.

Both stay at their existing WARN levels (`LC-E5`, `LC-E6`, `LC-O15`). No blocking on first
contact; that promotion is R6.

Fixtures: extend `core/fixtures/layer-readopt-gate/run.sh` with an env-keyless supersession
arm, and add an unnumbered-heading absorption arm. Two mutants — revert the `:648` guard,
revert the title pass — each must fail **only** its own assertion.

### R2 — the three free retirements — **SHIPPED as v0.276.0 (#362). Do not redo.**

Each is a delta core should simply carry; none is graph-specific; each retires one override.

| core edit | retires |
|---|---|
| `steps/gate-validation.md` Check 7 — add the fourth bullet: an artifact-consistency pass over an EMPTY referenced set is not a pass. This is the non-vacuity discipline core already applies in Check 5 ("exit 4 … is never a pass") — a core-consistency gap, not a graph fact. | `overrides/steps__gate-validation__check-7.md` |
| `steps/carry-over-evaluation.md` item 5 — add the sprint-boundary clause: reaching PVC on the bug variant closes the interrupted sprint; carry-over evaluation re-enters fresh next sprint, not mid-stream. Zero graph vocabulary; the entry itself records "Removal condition: none anticipated." | `overrides/steps__carry-over-evaluation__item-5-bug-sprint-boundary.md` |
| `team-roles/dev.md` `## Identity` — delete the `Local (Ollama)` launch bullet. It **contradicts the two lines directly above it**, which say `aiDlcRoles.dev` "is the only source; do not infer either value from anywhere else." v0.175.0 moved model/effort into settings and left this orphan. | `team-roles__dev__identity.md` |

Plus three `override_supersessions:` rows with `since_core_version`, `reason`, `verify`, and
**no** `settings_env_key` — the shape R1 unblocked. Bump `contract_version` 14 → 15 (this is
`LC-C2`/`W6`, a WARN, so it will not wedge graph on contact).

### R3 — auto-handoff becomes configuration

`SKILL.md:506` currently reads "projects override the default in this section directly" —
core is *inviting* the shadow, and graph took the invitation for a value (`off`) that equals
core's own default. The entry says so: "operatively null today."

- Declare `AI_DLC_AUTO_HANDOFF_MODE` (`off|deploy-only|safe-seam`) and
  `AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED`, read at `steps/_gate-procedures.md:397` (the actual
  reader — "Read `auto_handoff_mode` from SKILL.md Handoff…").
- Delete the invitation sentence at `SKILL.md:506`.
- Supersession row on `SKILL.md#Auto-handoff (configurable via auto_handoff_mode)`. Two keys
  are needed, so this release also carries the **multi-key** extension to
  `override_supersessions` (`settings_env_keys:` list; `supersessions_of` emits one row,
  `apply.sh` renders 1/N…N/N ATOMIC rows).

Retires `overrides/SKILL__auto_handoff_mode.md` — the cleanest v0.271.0-shaped retirement of
the eleven.

### R4 — the snapshot ceiling becomes a core verdict

`overrides/steps__retro__pipeline-snapshot-ceiling.md` restates **zero** core text; it exists
only because core's retro budget run is `--warn-only` and because arm (2) depends on core's
`6000`-token budget constant, which an extension (no `base_sha`) could not track.

- `core/scripts/validate-artifact-budget.sh`: add the supersession-marker arm for
  `pipeline-snapshot.md` scoped outside `## In-Flight Teammates`, and add `--fail-on
  <artifact>` so retro takes a hard verdict on one artifact while staying warn-only overall.
- Env-keyless supersession row.

This is the entry's own stated removal condition; the `base_sha` dependency then evaporates.

### R5 — the three role-file absorptions — **SHIPPED as v0.277.0 (#363). Do not redo.**

| core edit | retires |
|---|---|
| `team-roles/qa.md`, new `## Gate-2 Start Condition (HARD)` — gate-2 validation MUST NOT begin until the lead sends `gate-2 go-signal: <story-id> @ <SHA>`; task-graph completion is not approval. 17 lines, zero domain content. | `extensions/roles/qa-push.md` |
| `team-roles/pm.md` — probabilistic-AC tagging at story-creation ("unverifiable BY CONSTRUCTION, not merely unverified") and prior-artifact numeric anchors linked at authorship. Also discharges the OPEN ledger item `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION`. | `extensions/roles/pm-domain.md` (currently misfiled as `push_candidate: false`) |
| `team-roles/code-reviewer.md` — return-type / context-shape changes are **Critical**, never downgraded, with a mandatory Consumer Audit (grep every caller, log the command); unverified-API-field is **Important** with the 4-step Field Verification. Genericize the two graph function names. | `extensions/roles/code-reviewer-push.md` |

All three are currently invisible to the detector (roles carry no numbered headings), so R1 is
what makes their retirement reportable at all.

### R6 — promote the retirement signals to ADJUDICATED (gated on R1's measurement)

`LC-E6` (`EXTENSION-RETIRE-CANDIDATE`) and `LC-O15` (`OVERRIDE-SUPERSEDED`) are WARN. A WARN
reaches the report and the worklist but records no verdict, which is why the register holds
0 `retire` rows across 61 adjudications. Raising both to `ADJUDICATED` makes an unrecorded
retirement **block the apply** (`LC-A1`), which is what "surfaced *and* adjudicated" means.

Ship this only after R1's fired set has been measured on graph and is small enough not to
wedge first contact — core's own documented promotion path (`layer-contract.yaml:136-152`;
`LC-N5`'s warn-tier → `E15` at contract_version 8 is the worked example). If the set is
large, R6 splits: promote `LC-O15` first (bounded by the supersession list core controls),
leave `LC-E6` at WARN one release longer.

---

## Verification — ground truth, not a resolver dry-run

Per the standing rule, a read-only probe is not a consumer verification. For **every** release
above, before calling it done:

1. **Commit first.** An uncommitted edit is absent from `git diff BASE THEIRS`, so a delivery
   check on a dirty tree reports a false negative.
2. **Scratch consumer.** Copy graph's `.claude/ scripts/ tests/ .githooks/` into the
   scratchpad. Never write into `/Users/n8/git/graph`.
3. **Baseline with the OLD engine.** Run the scratch tree's *own installed*
   `reconcile/layer-drift.sh` (0.274.0) with `DIST=/Users/n8/git/ai-dlc`, `BASE=9036e0d`,
   `THEIRS=<new release>`. This is the control: it must **not** show the new rows. Without it
   you have shown that the new rows appear, not that the fix produced them.
4. **Run the real apply.** `reconcile/apply.sh <dist> <base> <scratch> <theirs>` from the
   scratch tree, then the consumer's fixture suite the way `.githooks/pre-push` drives it
   (`tests/fixtures/*/run.sh`, no positional args).
5. **Assert the named rows, per release.** R1: the enumerated new
   `EXTENSION-RESTATES-CORE`/`RETIRE-CANDIDATE` set, plus the FP count. R2–R5: exactly one
   `OVERRIDE-SUPERSEDED` per retired override, and an `override-retire` WORKLIST row from
   `apply.sh` for each. R6: `HARD-LAYER-ADJUDICATION-MISSING` on an unrecorded retirement,
   and clean once a `retire` row is written to the register.
6. **Two-repo layout.** Anything touching path resolution is re-verified on a tree built by
   running `scripts/install.sh` into an empty directory, not only in `core/` (invariant I33).
7. **Bootstrap limit, stated not implied.** The consumer runs its own installed engine. R1
   takes effect via the step-2 self-update + automatic re-invoke — but **only because R1 is
   machinery-only** and `self-update-gate.sh` therefore returns `SELF-UPDATE-OK`. If any
   rulebook file lands in R1, the gate defers and the fix classifies one pull later. Verify
   the gate's verdict explicitly; do not assume it.

Build-time, every release: `scripts/validate-enforcement-map.sh` (I36 both directions — a new
code must have a clause and a clause must have an emitter; I42 no clause above
`contract_version`; I63 `absorbed_from:` roles still hold), and
`scripts/validate-release-version.sh`.

---

## Deliberately out of scope, with the reason

Enumerated so the operator can scale the work up, not silently dropped.

**Needs machinery this plan does not build:**
- `overrides/SKILL__Rule-8.md` — the live delta is graph's service/infra path lists
  (`server/ rebalancer/ web/ subgraph/ infra/`). Needs `AI_DLC_SERVICE_PATHS` +
  `AI_DLC_INFRA_PATHS` read at `steps/route.md:351` where intensity is *assigned*. Note the
  entry's stated "three guarantees upstream lacks" are all in core Rule 8 verbatim today, and
  it freezes a paragraph core has since deleted — it is doing net harm, not net good.
- `overrides/steps__gate-validation__check-5.md` — needs a real corpus-glob leg in
  `sprint-status.sh check-stories` (fail closed when the story-file count disagrees with the
  yaml, and on frontmatter `sprint:` mismatch), plus `AI_DLC_CHECK5_EXTRA_VALIDATOR`.

**Genuinely domain-local, do not absorb:**
- `team-roles__tea__consumer-drift.md` — graph's TEA owns test strategy; core's TEA is a
  party-mode advisory lens. Core cannot adopt ownership without breaking every unlayered
  consumer. Worth *narrowing* (drop `#Identity` and `#Escalation` from `shadows:` — both are
  core text verbatim), not retiring.
- `steps__retro__domain-sections.md` — 4 anchors, 608 lines. §3's only delta is the
  finding-class taxonomy citation (an `AI_DLC_FINDING_CLASS_EXTRA` candidate); §5's Stop-hook
  rationale is general; §4a and §7 are genuinely graph-local. It should be **split**, not
  retired.
- `steps__retro__ci-gates-enforcement-surface.md` — core has partly caught up; the residue is
  graph's disabled-GHA operational state and belongs in `extensions/`, not a shadow.

**Large generalizable backlog, already located:** SKILL.md Rules 929/930/931/932 and the
party-mode inline-relay clause; `retro-deferral-expiry` (three fully general rules, misfiled
as domain); the bug-investigation adversarial-verify pass; `attribution-provenance` and
`validator-honesty` as new gate checks. Roughly 57 upstream-facing items are already OPEN in
graph's `push-candidate-ledger.md` — the largest single cluster (5) is defects in
`ledger-reverify.sh` itself, the tool that closes that ledger.

**One consistency gap worth a one-line release:** `known-skills.json` has
`AI_DLC_KNOWN_SKILLS_EXT`; `protected-paths.json` has no equivalent and hardcodes its path at
`core/hooks/ai-dlc-protect.sh:132`. Both JSON extensions are permanent by design and retire
nothing — this just closes the asymmetry.
