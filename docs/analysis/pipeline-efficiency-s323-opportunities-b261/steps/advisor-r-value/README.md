# advisor-r-value (read-only; transcripts under ~/.claude/projects/-Users-n8-git-graph/)
Run order: python3 -I seg.py; dossier.py; (hand classification -> cls.json via cls.py/show.py); table.py; control.py; dupdispatch.py
- seg.py        : 134 compact_boundary rows in the 5 s323 pipeline lead sessions -> segs.json (advisor attempts+latency, first dispatch/write = first Agent/Task/Write/Edit that is not is_error, digest Reads, R-gate denials)
- dossier.py    : per compaction, first non-error advisor result: lead text/thinking/tool calls since compaction, advice, next 10 actions -> dossiers.json
- show.py/cls.py: viewer and recorder used for the hand reading; cls.json = the class per dossier index (116 rows)
- table.py      : joins to MONO/segs.jsonl steps -> table.tsv / table.json (full per-compaction table)
- control.py    : the no-advisor-first compactions: 20 actions after first dispatch/write, flagged denials and correction cues -> control.json
- dupdispatch.py: re-dispatch probe: same (subagent_type, description) successful Agent dispatch as in the previous segment -> dupdispatch.json
Control for seg.py: 134 boundaries = 2+11+15+76+30, equals the roll count.
