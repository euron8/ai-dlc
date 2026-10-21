# Batch 238 close checklist (lead ai-dlc-fc)

- Re-anchor every batch-238 LANDED line to its release's squash sha in the batch-close docs commit, then delete its -dev ref:
  - 0.891.0: BL-687, BL-688 say `verified 9595dc4ef` (b238-r2-dev) -> squash `01de3123d` (PR #1234). Then delete b238-r2-dev.
  - 0.892.0: BL-678, 708, 712, 714, 720, 724 will say `verified 9d89a4cd2` (b238-s1-dev) -> the 0.892.0 squash. Keep b238-s1-dev until then. (superseded below)
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
- Graph brief item for the operator: replacement receipt for PC-S319-SELF-UPDATE-FIXTURES-… : (superseded below)
  `verify: theirs_has core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh "DISPATCH: hermetic"`.
- Batch-237 figure correction (derive grammar): DISCHARGED 1 -> 0, unfiled 0 -> 1.
- Plan: write the batch-238 resume block, rotate if P8 fires (`scripts/plan-rotate.sh`, then `--apply`).
- Graph boundary: porcelain 11, ledger md5 a1b4741c…, HEAD ae1fafcf8 — re-assert at close.

## Lead ai-dlc-1a (batch 238, continued)

### Landed under this lead
- 0.892.0 `0877fe65f` (#1236), owner ai-dlc-e3: BL-678, 708, 712, 714, 720, 724. LANDED lines say `verified 9d89a4cd2`; re-anchor to `0877fe65f`, then delete `b238-s1-dev`.
- Filings `1c41de9e3` (#1237), docs-only: BL-725..BL-733 filed; BL-716 note appended. Next free id BL-734.
- BL-735 is the next free backlog id (allocated by the lead).

### Re-anchors (all in docs/backlog.archive.md now), then delete the -dev refs
- 0.891.0: BL-687, 688 `9595dc4ef` -> `01de3123d`; delete b238-r2-dev.
- 0.892.0: BL-678, 708, 712, 714, 720, 724 `9d89a4cd2` -> `0877fe65f`; delete b238-s1-dev. (Resolves the S1 line above that said "the 0.892.0 squash".)
- 0.893.0: BL-715 `d80edf0e5` -> `b55dc53fa`; delete b238-s-715-dev.
- 0.894.0: BL-674, 697, 707 `b62ebc721` -> `39fb06be9`; delete b238-r3-dev.
- 0.895.0: BL-721 `2149322d5` -> `599da0aef`; delete b238-d-721-dev.
- Later releases (d-719, 238-h): add as they land.

### Close duties
- Re-anchor BL-687/688 `9595dc4ef` -> `01de3123d`; delete `b238-r2-dev`.
- BL-701 receipt re-scope (from the hand-off).
- BL-727, BL-728, BL-731: `sh` receipts that `validate-backlog-receipts.sh` lists UNSCORABLE (R3 allows). The rotator cannot close on them; re-scope at close or in their build.
- Drop the PC-S319-SELF-UPDATE-FIXTURES replacement receipt from the operator brief: graph archived that id at its 0.891.0 reconcile (`cf8e10c78`) under its own receipt, and the handed receipt was inverted (theirs_has on a token the fix deleted). (Supersedes the "Graph brief item for the operator" line above.)
- Plan edit: add a GRAPH-WATCH role to action 0 (a session assigned by the operator, read-only, findings not instructions, polls graph every 10 minutes per operator ruling "the watch should be set to 10 minute intervals. current interval is far too aggressive."). The plan currently has no watcher section (`grep -ci watch` = 0 per ai-dlc-1b).

### To file at close
- NOTE (BL-735 or next free): the recover hook's worst real gate-in-flight output (BL-457 WC world) is 9980 bytes against a 10000 bound at 39fb06be9, which leaves 20 bytes of headroom. Any line added to `core/hooks/ai-dlc-recover.sh`'s emitted text silently drops the "Mechanical state captured immediately before this compaction" sidecar note for a compacted lead. Measured by ai-dlc-e3 while 238-d-721's dress was failing (gate-resume, mutant (e)). Sweep cliff at nonce n=120 (under) .. 132 (over).

### Plan corrections owed in the resume block
- BL-719's join emitter cites are stale: now `join-remediator-shards.sh:2360` (SUBJ_BEFORE) and `:2369` (SUBJ_AFTER), echoed at `:2407-2408`, at 39fb06be9 (not :2330/:2339). The merge emitters are unchanged at :701 and :1328. partition-subject.sh declares no PAIR_SEP (it spells `[=@]` inline at :271-276), so the design's key (b) adds the declaration. Rewrite or drop the "Unfinished build" bullet according to how d-719 lands.

### Adjudications this batch (the four exit-0 receipts) — all PARTIAL
- BL-584: surviving = trace-stream drop cause undiagnosed (ai-dlc side), README sentence. The hand-off's reason "consumer measurement first" is wrong.
- BL-605: surviving = no arm judges an existing In-Flight row. "No join key" premise stale: `--dispatch-ts <agentId>` resolves; the graph row joins by tool_use_id; the graph lead ran `--dispatch-ts` 0 of 229 Bash calls. Buildable binary late arm.
- BL-695: a367e62c was a party-REPAIR fan-out, not seats (now BL-732); claim (c) NOT met.
- BL-699: (d) the durations before/after and (e) the pcv_latarm reading are owed.

### Timing (r3, validate-enforcement-map.sh)
- Run 1 (load 3-6): base 27.29-27.67 vs tip 717e0d856 28.80-28.86 CPU-s, +4.9%, user-time only. Cause: BL-674's i55_reach_scan, a five-pattern regex over 13 MB, run twice.
- Prefilter c37afbb76: byte-identical output, seeded + live proof.
- Run 2 (load 9-16): unresolvable (base spread 2.57s vs 1.35s effect).
- Run 3 (load 4.3-5.7, started at 2.46), base vs b62ebc721: base 27.36-27.58, tip 27.93-28.26, non-overlapping. +0.63 CPU-s (+2.3%), user-time only. The prefilter recovered about half; the rest is the second scan plus the awk. This cost ships in 0.894.0 and is reported in its text.

### Graph observations (ai-dlc-1b)
- s319 gate[story] refused 22:44:38Z on arm L (K=19 vs 20 after the 2.3 split) -> BL-733; graph re-ran K=20 (26 adversaries).
- The BL-723 series PASSes after the post-MET amendment: intended per `_gate-procedures.md:855-857` (repair on unchanged scope). Open policy question for the operator: does a story split count as a scope change for the strategy?
- s319 K=20 elicitation joined and committed at graph 7abfe3b9e; arm L OK, stories and test-strategy series PASS 23:39:04Z.
- BL-715 second instance (graph 23:38:15Z `--escalations`): 2 REFUSED, "siblings: field is none of its four forms" (08.md F-3, 20.md F-2). 0.893.0 does NOT cover it (record mode); filed as BL-734 (DEFECT), landed at 791895504.
- 0.895.0's dress 2 ran 7 fixtures as `stale` (committed # digest mismatch), all ok: changelog-sprint-slot, context-sensor, dispatch-model-guard, divergence-hard-block and 3 more. The remedy is `derive-fixture-readsets.sh --reconcile` (sandbox tracer), plus the owed `story-evidence-scaffold` re-trace.
- s319 gate[story] PASS at graph 0592d78b1, nonce story-20261020T235042Z: 4 adjudicator shards, 8 escalated checks all PASS, COVERAGE-OK, no refusal. NOTE: the lead's draft gate-log row cited the PLANNING gate's verdict (10 checks) and was corrected to story/8 before commit. That is a hand-typed evidence cell; a candidate for "render, don't retype" if it recurs.
- The post-MET strategy policy question now applies TWICE: test-strategy-repair-p4 makes the strategy 52 lettered cases / 132 rows, again with no adversarial pass over the current bytes. It strengthens the case for asking the operator.
- BL-716 lane components: edit 19, edit ∪ MOVED-CITE 18, edit ∪ HIT 1 (one shared sprint-title line merges every lane).
