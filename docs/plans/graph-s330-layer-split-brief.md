# BRIEF — the S330 layer split, rehearsed on a clone. SUPERSEDED IN PART; READ THIS HEADER.

**OUTCOME (2026-08-14).** The consumer took **end-state 3** and did NOT apply the split on the
criterion as written. `OWED-S330-921-SPLIT-RELAXATION-TO-OVERRIDE` was superseded by a `-V2`
that restates the debt as **partial by construction**: 921's gate membership
(`planning|story|implementation|sprint-review`) strictly exceeds core Check 20's (`planning`),
so the relaxation must exist at three gate types where core has no section to shadow and no
`overrides/` entry can follow it. Relocation cannot discharge it. §2's mechanics and §1's
figures still hold; §3's three end-states are resolved.

**DEFECT IN THIS BRIEF, recorded rather than quietly fixed.** §6 called the §3 findings
"reasoning about prose semantics, not a measurement". That was written as honesty and it
functioned as a false structural limit — the measurement was available in the rehearsal clone
and was not taken. The consumer's committed gate logs carry `menu_skip_provenance` in
**31 files**, and `s277/gate-log-archive.md:120` records the sprint-review gate PASSING on
exactly the clause §3 was about. "Could fail after this lands" should have read "has been the
sole basis for a PASS at that gate across ten sprints." Same conclusion, different force, and
the corrected rule now lives in `.claude/rules/consumer-boundary.md`.

Discharges `OWED-S330-921-SPLIT-RELAXATION-TO-OVERRIDE` and `OWED-S330-914-RETRO-SCOPE`.

## Start here

**Repos and the boundary.** This brief was written in `/Users/n8/git/ai-dlc` (the
distribution). The consumer `/Users/n8/git/graph` is READ-ONLY from here — **do not write it**
from an ai-dlc session. Everything below was rehearsed on a `file://` clone at
`9a4dac917`, never in place. The original was asserted untouched before and after:
**5 dirty lines, HEAD `9a4dac917`, unchanged.**

**Who applies this.** The graph session. It owns that tree, it has a live paused pipeline on
`ai-dlc/carry-over/create-execution-seam`, and one-dev-per-worktree applies. Nothing here
should be applied by the distribution session.

**PING THE OPERATOR before applying**, because §3 is a decision this brief deliberately does
not make, and applying the mechanical part without settling it changes gate behaviour.

**Every figure below is measured on the rehearsal**, at distribution `b146417` (v0.368.0) —
which is also the consumer's installed stamp — and re-derivable by repeating the run. They are
hypotheses again the moment either tree moves.

## 1. The mechanical result: all four acceptance criteria met on the clone

| criterion | result |
|---|---|
| `validate-layer-entries.sh` no new errors | **0 errors**, 1 pre-existing W6 warning (44 of 45 entries at `conforms_to: 13`) |
| `validate-gate-manifest.sh` PASS both directions | **PASS — both directions resolve** |
| 914 resolves to a set including `retro` | `914->planning\|story\|implementation\|sprint-review\|retro` |
| 921/918/902s/903a have not gained `retro` | all four unchanged at `planning\|story\|implementation\|sprint-review` |
| `hard-blockers.sh` still clean | `0 HARD blockers.` |
| `audit-layer-debt.sh` OPEN drops | **15 → 13** |

The `hard-blockers.sh` run also emitted `DRIFT-RANGE-DEGENERATE`, correctly — base and theirs
were the same commit in the rehearsal, so that run was silent about the layer rather than clean
on it. That row is v0.367.0's and the consumer already has it.

## 2. What to apply — three files and two register rows

**(a) NEW `overrides/steps__gate-validation__check-20.md`.** Carries the two relaxations,
verbatim from 921. Frontmatter exactly:

    shadows: steps/gate-validation.md#20. Validation-intensity compliance (all planning gates).
    base_sha: b146417
    conforms_to: 13
    reason: |
      ...

Body: the `Sanctioned skips under carry-over-single` paragraph and the
`Carry-over-provenance menu-skip clause (PI-S271-3)` paragraph, moved unaltered, plus the
Rule-8-shadow note. The rehearsed file is complete and can be copied as-is.

**(b) NEW `extensions/checks/gate-validation-snapshot-fields.md`.** Check 914 moved into its
own entry, `gate_types: [planning, story, implementation, sprint-review, retro]`, and
`extends: steps/gate-validation.md#14. Update pipeline snapshot.`

It could not be fixed in place: `gate_types` is ENTRY frontmatter and its union covers every
check in the file — `core/scripts/validate-gate-manifest.sh:265` reads it off the whole file
and keys it by file — so adding `retro` to the existing entry carries 902s, 903a, 918 and 921
to the retro gate, and 921's body says it skips retro. Splitting also lets the entry declare
`extends:`, which the five-check entry could not: E11 permits exactly one anchor
(`core/scripts/validate-layer-entries.sh:1226`) and 914 extends core 14 while 918 extends
core 18.

**(c) EDIT `extensions/checks/gate-validation-push.md`.** Remove the `### 914.` section and its
`## Check 914` heading; remove the two relaxation paragraphs from 921; add a pointer in 921
naming the override. `gate_types` keeps `sprint-review`. **Do not retire this entry** — core's
Check 20 is in the `planning` row only, `sprint-review` is `18, 21`, so retiring deletes
coverage core structurally cannot load.

**(d) TWO register rows** closing the debts, `closes_owed` **as a list**:

    "closes_owed":["OWED-S330-921-SPLIT-RELAXATION-TO-OVERRIDE"]
    "closes_owed":["OWED-S330-914-RETRO-SCOPE"]

A bare string iterates character by character and closes nothing. The consumer's own register
carried one such row for weeks. v0.367.0 coerces and reports it as `MISTYPED_CLOSES_OWED`, and
the consumer has that fix at 0.368.0.

## 3. TWO BEHAVIOUR CHANGES THE ACCEPTANCE CRITERIA PRODUCE — read before applying

The `closes_when` clauses are satisfiable exactly as written, and satisfying them changes
what runs at two gates. Neither change is visible in any validator's output, which is why it is
here rather than in the results table.

**At a planning gate, two loaded checks now disagree.** The override IS core's Check 20 for
this consumer and sanctions the four absences. Check 921 still loads at planning and, with its
sanctions removed, reads as requiring every evaluation Rule 8's table names. A lead reads both.
Resolution order (`overrides > extensions > core`) governs which TEXT wins for a shadowed
section — it does not adjudicate between two differently-numbered checks that are both loaded.

**At the sprint-review gate, the check gets strictly stricter.** Core Check 20 is in the
`planning` row and `sprint-review` is `18, 21` — the manifest is at
`core/skills/ai-dlc/steps/gate-validation.md:59` and the loader contract that reads it is
directly below — so the override does not load at sprint-review. Check 921 does, and it no
longer carries the sanctions. Gates that pass today under the `carry-over-single` or `PI-S271-3`
sanctions could fail there after this lands.

Three end-states, and the choice is the operator's:

1. **Apply as specified.** Both changes above are accepted as intended tightening.
2. **921 keeps the sanctions, the override carries them too.** Sprint-review behaviour is
   preserved. Cost: the duplication the ruling objected to, partly reinstated — though the
   override now drift-checks against core, which is what was actually missing.
3. **Rewrite the `closes_when`** so the debt is discharged by a split that preserves
   sprint-review behaviour, and re-record it. The criterion is a decision, not a detail.

This brief does not choose. Nothing in the rehearsal distinguishes them mechanically — all
three pass every validator.

## 4. Authoring requirements the rehearsal surfaced

Three, and the third cost a failed run before it was known:

- **E8** — an override requires a `reason:` key.
- **E17** — every layer entry requires `conforms_to:`. The first rehearsal failed on exactly
  this. Use `13` to match the rest of that corpus.
- **`layer-contract.yaml`** must be present in the skill dir or E17 reports the install broken.

The `shadows:` anchor was confirmed against the shipping validator, not guessed:
`anchor_arm` matches by normalized containment, the exact heading text resolves FORWARD, and a
string wider than the heading fires `E7 REVERSE` — that fourth probe is the control.

## 5. The numbered action list

1. Ping the operator with §3 and get an end-state decision. **Do not apply before this.**
2. Cut a branch off `ai-dlc/carry-over/create-execution-seam`. Do not `git checkout` in the
   shared tree, do not clear the pause flag, do not commit the dirty `_bmad-output/` state.
3. Apply (a), (b), (c) per the chosen end-state.
4. Append the two register rows, `closes_owed` as a list.
5. Re-run the six checks in §1 and compare against the table. A figure that differs is a
   finding — report it rather than reconciling it.
6. Open a PR into the sprint branch. The graph operator merges; the distribution session does
   not, and neither does the graph session self-merge.
7. Report back, including anything in this brief that did not survive contact with the tree.

## 6. What I could NOT verify, stated rather than left to read as verified

- **Runtime loading was not observed.** Every claim about what loads where is derived from the
  `GATE_MANIFEST` rows and the loader contract in `steps/gate-validation.md`, plus
  `validate-gate-manifest.sh`'s resolution output. No gate was actually run.
- **The clone carries committed state only.** The consumer's uncommitted pipeline state was not
  present, so nothing here is tested against a live paused pipeline.
- **§3's MECHANISM is measured; its SEVERITY was available and I did not take it.** Both
  changes follow from manifest membership, which is derived. That a lead would find the
  planning-gate pair contradictory is a judgement. **But how much the sprint-review change
  costs was measurable from the rehearsal clone and was not measured** — see the header. This
  bullet originally stopped at the judgement, which read as "cannot be measured from here" and
  was wrong.
- **The 914 coverage claim remains suggestive.** Core's Check 14 sits in the `universal` row
  and carries no `**Scope.**` line at all (`core/skills/ai-dlc/steps/gate-validation.md:760`),
  so it does run at retro — that much is measured. `hard_block_count` is documented cumulative
  this sprint and retro is where it would be read, but nothing establishes that the retro
  snapshot is materially worse without it.
