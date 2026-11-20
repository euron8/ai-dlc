# update-and-minor-steps: scripts and outputs (read-only measurement, s317-s323)

- dump_sessions.py -> sess/, sess_early/: one TSV per lead session that loaded the ai-dlc-update skill (H human, A text, T tool_use, R result, Q ask, QA answer). Population: MONO/units.jsonl kind lead + skill ai-dlc-update (s321-s323: 29 sessions; s317-s320: 55).
- stage_time.py -> stage_time.out: gap time by stage x kind. KNOWN LIMITATION: stage is "last script keyword seen" and sticks, so its ask column is wrong (use asks.py); lead/script hours are approximate.
- asks.py -> asks.out, asks.json, asks_early.out/.json: every AskUserQuestion, Q->QA wait, answer kind (took-rec / first / chose-other / declined). s321 "declined" deletion is a parser artifact (file was git rm'd 10 min later).
- bg_durations.py -> bg_durations.out: background Bash wall time per script, joined by tool_use id to the task-notification.
- minor_reads.py -> minor_reads.out: lead tool_use Reads of steps/<minor>.md (controls: implementation.md many, zz-nonexistent 0). Hits in update sessions are git-diff commands, not runs.
- Dollar control: roll.py usd() on steps.csv bucket ai-dlc-update reproduces s321 lead API $89.73 + sub $1.64 = my $91.37 (confirms token order [in,cw,cr,out,calls]).
- s323_a.txt: compact timeline of one s323 update session (0e678bad).
