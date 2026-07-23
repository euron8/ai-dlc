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
