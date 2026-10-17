<!-- RECORD, not an instruction. The live gate log of batch 236, appended by the lead at every gate, slot, landing and ruling. Times are local EDT from `date`. -->

# Batch 236 release train (lead and gate scheduler: ai-dlc-c8)

Started by ai-dlc-71's handoff one-liner at `origin/main` `cc3c113f` (`VERSION` 0.822.0), accepted 4:22 PM. No
`graph-*` session is messaged. Releases are built by `Agent` hands in their own worktrees; every gate is the lead's
and runs serially on one box.

## Opening sweep (4:25 PM)

- Live 1, unfiled 0, worklist 1 (BL-530 against `PC-S319-CONVERGENCE-ADVERSARY-CANNOT-KNOW-ITS-OWN-TOOL-USE-ID`),
  DISCHARGED 0 after the overlap correction (1 raw), invisible 0, TERMINAL 246, archive 369, 165 qualifying refs, union
  minus archives 1. Every control passed.
- graph: `main` `d82236ce` installed 0.789.0; checked-out `ai-dlc/carry-over/offramp-config-and-rewards` installed
  0.818.0. Porcelain 82 (graph's own work). Working-tree ledger equals HEAD's. Ledger md5 `e37d4b06…`.
- The checked-out branch's ledger adds a section `S319 party repair: two push candidates` carrying no `PC-` id; its two
  targets are `join-remediator-shards.sh` and `ai-dlc-gate-remediation-guard.sh`, which 0.790.0 (BL-532, BL-533)
  closed. No sweep grammar can see it. Recorded, not acted on.

## Whole-backlog adjudication (four opus hands, 53 entries incl. intakes 28-29)

- CLOSE 1 (BL-650). PARTIAL 13. LIVE 39. DEAD-PREMISE 0 at entry level. No remedy recorded as refuted.
- Not buildable without a measurement or a ruling: BL-646 (profile), BL-655 (3-rep pair), BL-616 (item 8), BL-647
  (FP set under bash 3.2), BL-611, BL-639, BL-654 (design rulings), BL-632 (folds into BL-639/640/641?), BL-587
  (f7 half).
- Bootstrapping: BL-620, BL-621 (ai-dlc-update skill, `apply.sh`).

## R1 — 0.823.0 (docs)

- Intakes 28+29 (c9, `cc3c113f..4c664c04`, 3 commits, `docs/backlog.md` +62/-0) and BL-650's close.
