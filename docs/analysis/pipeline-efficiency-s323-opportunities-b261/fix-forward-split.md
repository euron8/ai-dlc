# Fix-forward split of the s317-s323 push and merge asks

Derivation for BL-972 item 9. Source: the s317-s323 lead `AskUserQuestion` pairs produced by `docs/analysis/pipeline-efficiency-s323-opportunities-b261/steps/open-items/asks317.py`. Population: graph lead transcripts 2026-10-05T13:58Z..2026-11-20T04:20Z, read only, each `AskUserQuestion` paired to its `tool_result` by id. Categories are curated by (start, header) and classified by question text. Minutes are the operator-wait of the ask.

Result: 16 asks, 586.1 minutes; the default option was taken in 16 of 16.

## Sprint-PR asks (8 asks, 211.3 minutes, default 8 of 8)

| Sprint | Start | Header | Minutes | Note |
|---|---|---|---|---|
| s317 | 10-11 15:19 | Sprint PR | 92.9 | |
| s318 | 10-14 14:39 | Push + PR | 56.9 | |
| s318 | 10-14 15:44 | Merge PR | 14.3 | |
| s319 | 10-22 21:03 | Push / PR | 1.9 | |
| s320 | 10-29 16:32 | PR #1277 | 25.1 | judgment: bundles merge and deploy |
| s321 | 11-07 14:42 | Push + PR | 0.7 | |
| s321 | 11-07 14:48 | Merge PR 1303 | 4.2 | |
| s323 | 11-19 13:24 | "2.2 reds" | 15.3 | judgment: it asks how the sprint branch carries 28 red tests, not a push or merge; excluding it gives 7 asks / 195.9 minutes (196.0 from the rounded rows above) |

## Fix-forward asks (8 asks, 374.8 minutes, default 8 of 8)

| Sprint | Start | Header | Minutes | Note |
|---|---|---|---|---|
| s317 | 10-11 23:36 | Merge PR 1207 | 0.5 | |
| s319 | 10-23 00:20 | Land fix | 69.8 | judgment |
| s321 | 10-30 18:14 | Land L2 fix | 12.1 | judgment |
| s321 | 11-07 15:41 | Fix PR | 6.7 | |
| s321 | 11-07 16:06 | Merge #1304 | 3.3 | |
| s321 | 11-07 18:48 | Push + merge | 1.5 | |
| s321 | 11-07 18:54 | Merge #1305 | 263.7 | re-ask of the 18:48 approval |
| s321 | 11-08 03:06 | Push+merge | 17.2 | |

Sum: 8 + 8 = 16 asks; 211.3 + 374.8 = 586.1 minutes.
