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

The pair proves the check is load-bearing: it fails the mis-anchored /
summarized propagation and passes honest verbatim citation and honest
cite-by-reference. Run `run.sh` to reproduce.
