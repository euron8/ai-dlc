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
| `MUT8` + pairing | the validator with `carry-over-backlog.md` dropped | the carry-over story reds while `locked-requirements.md` is still accepted |
| `MUT6` + pairing | the validator collapsed to one name | the legacy citation reds while `locked-requirements.md` is still accepted |

The `prd.md` control and the PASS-line arm are the two that separate a correct
widening from the two plausible wrong ones: accepting every basename fails the
first, and putting the third name first in the tuple fails only the second.
