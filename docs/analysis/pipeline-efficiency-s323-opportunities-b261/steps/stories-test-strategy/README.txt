stories-test-strategy step analysis (C10 round 2). All scripts read only; outputs beside them.
s1_spawns.py N        -> out_s32{1,2,3}_spawn_groups.txt   spawn groups by role/description (step + its gate), sprint N
s2_segs.py N          -> out_s323_segs.txt                 lead/sub time segments (step + gate)
s3_lead_calls.py      -> out_s323_leadcalls.txt            lead EXECUTED tool calls (paired with result, errors dropped), 1110
s4_phase_calls.py     -> (stdout)                          lead calls per round window
s5_survival.py        -> out_survival.txt/.json            AC text at planning commit vs story gate vs sprint pin, per story
s6_seat_reads.py, s17_touch.py, s19_prompt_ts.py -> out_seat_reads.txt, out_touch.txt, out_prompt_ts.txt  what dev/QA/reviewer/adjudicator touch
s7_findings.py        -> out_findings_per_story.json       C/M/MINOR per round per story
s9/s15_*.py           -> out_cluster.txt                   per-story planning yield vs downstream cost/rework, by routing tag
s10_round_cost.py, s11_tails.py, s12_dispatcher_lag.py -> out_round_cost.txt, out_tails.txt, out_dispatcher_lag.txt
s13/s14/s18/s20       -> out_survival_repairs.txt, out_party_seats.txt, out_survivors_by_story.txt, out_repair_introduced.txt
s21_dispatcher_trace.py, s22_stall.py -> out_disp_elicrepair_trace.txt (elicitation-repair dispatcher), shard 06 stall
Controls: impossible span absent (s13/s20); positive control dev prompts name test-strategy 9/25 (s19); s16 lead-active failed its control (445 vs 355) and is not reported.
