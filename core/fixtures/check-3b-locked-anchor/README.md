# Check 3b (Locked-Requirement Full-Text Anchor Integrity) Fixture

Discriminating fixture for `core/scripts/validate-locked-anchor.sh`.

Files:
- `product-brief.md` — the byte-verbatim source of record (basename SoR default).
- `prd.md` — a condensed index; self-declares "INDEXING, not weakening".
- `bad-story.md` — a story whose LOCKED block cites `prd.md:LR-1` as
  `full_text_source:` and carries a ≤250-char summary. MUST FAIL
  (mis-anchor at (a); also not byte-present at (c)).
- `good-story.md` — cites `product-brief.md:LR-1` with the requirement
  bullet verbatim, plus an honest `requires_context:` pointer. MUST PASS.
- `uncheckable-story.md` — a LOCKED block with requirement bullets but
  NEITHER a `full_text_source:` nor a `requires_context:`. Stock
  `continue`d on the absent full_text_source and passed it with
  `claims_checked=0` — PASS by "nothing to check", indistinguishable from
  PASS by "every claim verified". MUST FAIL (the uncheckable guard).
- `requires-context-story.md` — bullets plus an in-block `requires_context:`
  and no full-text claim. MUST PASS: honest cite-by-reference is a load
  pointer this script never byte-matches, so the guard must not red it.

The set proves the check is load-bearing AND discriminating. `run.sh` also
carries a MUTATION control: it neuters the uncheckable-guard condition in a
copy of the validator and requires `uncheckable-story.md` to go green — a
FAIL is evidence for THIS guard only if removing the guard removes the FAIL.
Run `run.sh` to reproduce.

`run.sh` builds further worlds under `mktemp`. The source-of-record arms:

| Arm | World | Asserts |
|-----|-------|---------|
| `SoR` new / legacy / index | `s302/` slot beside a brief and a `prd.md` | the sprint slot and the legacy brief are accepted, the legacy one is counted on the PASS line, `prd.md` is refused |
| `carry-over` accepted | `carry-over-backlog.md` two directories above the story, `## [CO-S302-PROBE]` heading | a byte-verbatim closure-condition quotation PASSES |
| `carry-over` elided | the same bullet with the operative clause replaced by `...` | FAILS, and fails at the BYTE-MATCH — a refusal at (a) would mean the quotation was never adjudicated |
| `carry-over` CONTROL | `prd.md` carrying the SAME anchor and the SAME text | still refused, so the NAME SET is what admits the backlog rather than the resolver |
| `carry-over` PASS line | the new-SoR story's PASS text | still prescribes `locked-requirements.md` — a tuple that merely REORDERS admits an identical set and changes no exit code, so only the string can see it |
| `carry-over` cross-section | a bullet from the `## [CO-S302-DECOY]` section, cited under the PROBE id | REFUSED, and refused at the byte-match — the window is the cited heading's section, not every line mentioning the id |
| `carry-over` FALLBACK | an anchor carried by no heading at all | still resolves, so the narrowing did not break the unstructured-brief case it must preserve |
| `carry-over` FALLBACK cross-region | a bullet past a later heading of any depth, under that same heading-less anchor | REFUSED — a mention's window stops at the next heading of ANY depth, so the fallback is bounded rather than whole-file |
| `MUT10` + pairing | the fallback bound reverted to same-or-shallower | the cross-region quotation passes (the whole-file window on demand) while the honest flat one still passes |
| `MUT8` + pairing | the validator with `carry-over-backlog.md` dropped | the carry-over story reds while `locked-requirements.md` is still accepted |
| `MUT9` + pairing | the anchor-window narrowing reverted | the cross-section quotation PASSES (the defect on demand) while the in-section one still passes |
| `MUT6` + pairing | the validator collapsed to one name | the legacy citation reds while `locked-requirements.md` is still accepted |
| SoR cwd-invariance | five SoR cases × two cwds, one of them this directory | every SoR arm answers the same from any cwd — this directory ships a `product-brief.md` decoy, and the block answered differently from here until its brief was seeded beside the story |

The carry-over world is deliberately PREAMBLE-SHAPED: the probe id appears once in a
summary sentence above the first `##` and once as its own heading. A preamble mention
sits at depth 1, so a window built from every hit line runs to EOF and the byte-match
degenerates to co-presence — the arms above are what hold that closed, and `run.sh`
refuses if the world ever loses that shape.

The `prd.md` control and the PASS-line arm are the two that separate a correct
widening from the two plausible wrong ones: accepting every basename fails the
first, and putting the third name first in the tuple fails only the second.

## The `requires_context:` road's report-only bullet observation

`run.sh` builds a fourth world under `mktemp` — a two-section brief and four stories
differing only in the bullet — and asserts the COUNT FIELDS on the PASS line, never the
first line as a whole.

| Arm | World | Asserts |
|-----|-------|---------|
| verbatim | the bullet byte-present under the cited anchor | `1 byte-present / 0 not`, rc 0 |
| fabricated | a bullet the brief never says | `0 / 1`, **rc still 0** |
| abridged honest | a bullet shortened from the source sentence | `0 / 1`, **rc still 0** — this is what proves report-only is report-only |
| cross-section | a bullet verbatim under the section the pointer does NOT name | `0 / 1` — the observation is scoped to the resolved window |
| the SPLIT | the verbatim and fabricated stories together | they disagree on the COUNT FIELDS, and their exit codes do not move |
| `MB1` + pairing | the count fields replaced by a per-story run marker | the count arms go red while the mutant's FIRST LINES still differ — a receipt closing on a line split closes on it, and only a count-keyed arm sees through it |
| `MB2` + pairing | the observation appended to `failures` | the ABRIDGED HONEST story reds, so an enforcing regression is visible; the verbatim one stays green |
| `MB3` + pairing | the match widened to the whole artifact | the cross-section bullet counts as byte-present, so the window is what scopes it; a fabricated bullet still counts absent |
| designated-honest assertion | `requires-context-story.md` | it reports `1 / 0`, so its false-positive set is EMPTY BY CONSTRUCTION and no FP figure may be taken there |
| ctx cwd-invariance | three stories × two cwds, one of them this directory | the observation resolves its window story-relative, like every other arm |

**`requires-context-story.md` cannot measure the false-positive set.** Its bullet is
verbatim at the anchor, so it scores `1 / 0` and an FP measured on it is a false zero.
The abridged world is the shape the corpus lacked, and the arm above asserts the
designated file's `1 / 0` directly so that fact cannot go stale silently.

**The exit code does not move on this road, and every count arm carries the rc assertion
beside it.** An abridged cite-by-reference restatement is the honest shape here: over a
reference consumer checkout with `.claude/worktrees/` excluded, 4 of the 5 stories that
reach the observation carry at least one non-verbatim bullet. As a failure condition that
reds most of the honest blocks the observation can see, which is the regression `MB2`
makes visible. `validate-locked-anchor.sh` carries the full partition and the tree it was
taken in; re-derive there rather than quoting this file.
