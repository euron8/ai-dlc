# reconcile (read-only; run each as `python3 -I`, EXTRACT_WIN_END=2026-11-20T04:20:00Z)
- extract_dump.py D   : copy of extract.py (leads only) that also writes D/recs.jsonl, one row per lead record from 2026-10-14T22:00Z (uuid, old label, gap, class a/o/g, tool_use/result ids, usage). Control: D/segs.jsonl == MONO/segs.jsonl lead rows (500 of 500, 0 diffs).
- lib.py              : loaders, sprint edges (copied from extract.py), session bucket rule (analyze.py).
- build_true.py       : rows.pkl, transitions.json. B1 relabel (SET current_step_file, planning-gate close, gate nonce override), B2 operator spans (AskUserQuestion pairs, pause-flag touch -> next human prompt), B3 fork copies, B4 idle tail (gap>300 s after last tool_use).
- report_b.py         : B_tables.txt (stage totals, class hours, per-sprint per-step old -> new; spawns and sub $ re-attributed by owner tool_use id). Control: sub $ from units == spawns.jsonl usd.
- refusals.py (+ refused_files.txt from grep -rl 'admission: REFUSED|GiB: REFUSED') : refusals.jsonl, one row per result block. A1.
- a3_gaps.py -> a3_gaps.txt : A3 per-story gaps by type.  c_admission_waits.py -> c_waits.txt : C.
