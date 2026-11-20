architecture step analysis (C10 round 2), read-only. Population: s321, s322, s323 on MONO extraction (monotone clock).
agg.py        lead segs/classes and spawns for steps architecture + ui-direction (control: s323 spawns 60 = brief's 67 with gate)
tl.py         per-sprint spawn timeline -> tl321.txt tl322.txt tl323.txt
evlog.py      condensed lead event log from a transcript window -> ev_a.txt (s323 session 4b34031d), ev_b.txt (53b4296a gate), ev_ui.txt
phases.py     lead calls per phase (boundaries read off ev_a/ev_b text) -> phases.txt
readers.py    who reads spine/arch doc/impact/index/mockups: scans every s321-s323 subagent transcript, non-errored tool_use only -> readers.json
prompts.py    same patterns in each s323 spawn's first user message (the brief) -> prompts.txt
leadreads.py  lead's own reads/writes of the same paths per step label (s323) -> leadreads.txt
refused.py    Agent dispatches that errored in the step window (hook refusals) -> refused.txt
cat.py        Bash script-name census of ev_*.txt -> cat_a.txt cat_b.txt
txt_a.txt txt_b.txt txt_ui.txt  lead narrative (TEXT/Agent/advisor lines) used for the phase table
