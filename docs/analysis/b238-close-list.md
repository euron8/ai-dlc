# Batch 238 close checklist (lead ai-dlc-fc)

- Re-anchor every batch-238 LANDED line to its release's squash sha in the batch-close docs commit, then delete its -dev ref:
  - 0.891.0: BL-687, BL-688 say `verified 9595dc4ef` (b238-r2-dev) -> squash `01de3123d` (PR #1234). Then delete b238-r2-dev.
  - 0.892.0: BL-678, 708, 712, 714, 720, 724 will say `verified 9d89a4cd2` (b238-s1-dev) -> the 0.892.0 squash. Keep b238-s1-dev until then.
  - later releases: add here as they land.
- S1 release text: lead-written s1-cl-block.md / s1-relmsg.txt used; the b238-s1-reltext hand's draft was compared and its
  content folded (BL-712 both sites, BL-714 6e + light receipt, BL-708 two-already-red, BL-724 NOTE).
- File BL-725 (NOTE or DEFECT): recover gate ENOSPC stage-write wedge — `[ -w "$STATE_DIR" ]` passes on a writable dir whose
  stage write fails (full disk); gate stays at `snapshot`, denies FIRST. 0.891.0's CHANGELOG promises this filing.
- BL-701: receipt re-scope (its `n` half measures committed `# digest` freshness the in-pool trace never writes; direction 1
  shipped in 0.881.0, 829011111). Lead's to re-scope at close.
- Not built, with measured reasons, into the resume block: BL-538, 583, 584, 587, 616, 706 (consumer measurement/gate log);
  553(b) (not shippable as specified); 685 (owner ai-dlc-69 absent), 699 (owner ai-dlc-77 absent); 695 (graph's next stories
  round); 691 (design deferred); 692 (first-wins record needs graph HEAD-movement measurement); 716 (lane key = components;
  needs S319 component count); 605 (only the late arm remains, ruled out by lead c8; premise "no join key" stale).
- Graph brief item for the operator: replacement receipt for PC-S319-SELF-UPDATE-FIXTURES-… :
  `verify: theirs_has core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh "DISPATCH: hermetic"`.
- Batch-237 figure correction (derive grammar): DISCHARGED 1 -> 0, unfiled 0 -> 1.
- Plan: write the batch-238 resume block, rotate if P8 fires (`scripts/plan-rotate.sh`, then `--apply`).
- Graph boundary: porcelain 11, ledger md5 a1b4741c…, HEAD ae1fafcf8 — re-assert at close.
