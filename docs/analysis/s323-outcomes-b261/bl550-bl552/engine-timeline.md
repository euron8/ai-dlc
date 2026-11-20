Engine version in force, graph s323 (lead transcripts under ~/.claude/projects/-Users-n8-git-graph/, UTC).
The version is the `skill_version` stamp the graph lead wrote, at the record named; `ENGINE_TIMELINE` in by-engine.py is
this table. Release under test for BL-550 and BL-552: 0.1135.0.

| effective from | version | evidence (transcript, line, record timestamp) |
|---|---|---|
| s323 start | 0.1101.0 | 0ef7ba46 l24 (11-13T08:17Z); 0e678bad l44 (11-14T13:53Z) stamp read |
| 11-14T14:26:24Z | 0.1128.0 | 0e678bad l491 reconcile ledger `skill_version ... advance to 0.1128.0 @ c75a7c32` |
| 11-15T23:11:54Z | 0.1142.0 | f7ff0ac0 l1228 `advance to 0.1142.0 @ ec906232` |
| 11-16T13:36:48Z | 0.1143.0 | 4104f33b l837 `skill_version=0.1143.0` stamp step |
| 11-16T18:12:15Z | 0.1157.0 | 0604f29f l1444 `=== stamp === ... skill_version: 0.1157.0` |
| 11-16T22:12:02Z | 0.1160.0 | f8934707 l222 `set skill_version: 0.1160.0` |
| 11-18T01:43:13Z | 0.1164.0 | 17d27721 l1347 `=== stamp now: ... skill_version: 0.1164.0` |
| 11-19T08:32:00Z | 0.1167.0 | 70834da1 l802 stamp step |
| 11-19T12:01:46Z | 0.1174.0 | 70834da1 l3055 `--- stamp --- ... skill_version: 0.1174.0` |

Round -> engine (by-engine-s323.txt, seats first timestamps; window 2026-11-12T12:33:00Z to 2026-11-20T04:20:00Z):

| round | seats first..last (UTC) | engine | at or after 0.1135.0 | seats whose prompt carries `cited-paths:` |
|---|---|---|---|---|
| party carry-over-evaluation | 11-13T08:36..08:38 | 0.1101.0 | NO (outside the population) | 0 of 28 |
| party requirements | 11-17T07:21..07:26 | 0.1160.0 | yes | 30 of 30 |
| party architecture | 11-17T21:15..21:18 | 0.1160.0 | yes | 20 of 20 |
| party stories | 11-18T04:00..04:16 | 0.1164.0 | yes | 76 of 76 |
| elicitation | 11-16T23:40..11-17T22:40 | 0.1160.0 | yes | 10 of 26 |
| elicitation | 11-18T05:56..06:03 | 0.1164.0 | yes | 19 of 19 |
| adversary round | 11-17T00:34..11-18T00:15 | 0.1160.0 | yes | 53 of 53 |
| adversary round | 11-18T07:42..10:53 | 0.1164.0 | yes | 10 of 48 |
| party sprint-review | 11-19T17:24..18:08 | 0.1174.0 | yes | 71 of 110 |

Caveat: the stamp is the version the lead's worktree carried, not a per-seat read of the engine; the `cited-paths:` column
is per-seat evidence that the 0.1135.0 seat-brief block reached the brief.
