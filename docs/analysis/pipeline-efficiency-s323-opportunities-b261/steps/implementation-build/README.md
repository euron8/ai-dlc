# implementation-build (s323 lead 53b4296a 11-18T12:45Z..11-19T03:10Z + 2.x session 64926214; read-only)
Run each as `python3 -I <script>` from this directory (they read ../../MONO and ~/.claude/projects/-Users-n8-git-graph/).
- extract_lead.py   -> lead_calls.jsonl: every lead tool call, tool_use paired with tool_result by id (5,001 rows, 3,899 calls)
- classify.py       -> classify.out: lead think/tool minutes per activity class; importable (classify.timeline)
- story_spawns.py   -> story_spawns.tsv/.out: all 315 spawns of the window by role x story ($436.4)
- dev_activity.py   -> dev_activity.tsv; dev_agg.py -> dev_agg.out (dev+dev-escalated minutes/tokens by activity, standby); cost_by_activity.py ($ apportioned)
- dev_writes.py / dev_testruns.py / dev_git.py / dev_errors.py / admission.py(+_all) : bytes written by class, test+wait minutes, shell/git call mix, errored results, pytest admission refusals
- story_diffs.py, story_diffs2.py, spawn_commits.py, story_sections.py, top_files/capture_sizes.out : branch diff composition (graph git, read-only)
- story_timeline.py -> story_timeline.out (per-story dispatch->first commit->last dev commit->g1->qa->merge); waves_all.py (dev dispatch clusters s321-s323)
- pickup_lag.py, handoff_refusals.py, wave-dag.copy.md (copy of graph's s323 wave plan), bl1166.copy.txt (pre-reviewer record)
Controls: dev spawn out-tokens 1,208,180 (own dedupe by message id) vs 1,208,231 (spawns.jsonl) over the same 32 spawns; $ apportioned 162.5 = story_spawns dev 58.8 + dev-escalated 103.7.
Caveat: naive datetime.timestamp() in classify.py/dev_activity.py is local time; only differences are used (the per-hour busy table was shifted +5 h, read as UTC-5).
