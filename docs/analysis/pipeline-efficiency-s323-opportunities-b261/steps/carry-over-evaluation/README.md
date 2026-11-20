# carry-over-evaluation step analysis (C10 round 2) - scripts and outputs
All read-only against ~/.claude/projects/-Users-n8-git-graph and /Users/n8/git/graph. Run with python3 -I.
- timeline.py <sid> <t0> <t1>  : condensed lead timeline; out tl1.txt (s323 session 1), tl2.txt (s323 session 2), tl322.txt (s322)
- windows.py <sid> <bounds..>  : lead active / operator wait / other gaps per window (control: whole-session op wait 210.2 min = segs.jsonl 12612 s); out roundwin.txt
- show.py <sid> <t0> <t1>      : full assistant text + results in a window (used for 08:51 stale-draft evidence, s322 cross saga)
- rounds.py, rounds_t.py       : per-round spawns / agent-min / usd from spawns.jsonl (rounds_t = by start-time window; control total 89 spawns, $173.4)
- classes.py                   : lead call classes for the step (s322, s323) from classes.jsonl
- width_s322_s323.py           : copy of step-value-carry-over width.py with ELIC[323]; out width.json/width.out (control: party 100 MAJOR+ = 4C+96M, matches lead's activity line)
- idreaders.py                 : which CO- ids named only in the cluster/aged sections are read downstream (control: head ids 37/59 found; absent token not found)
- majors.txt, sev.txt, party.txt, persec.txt, crit.txt, docstruct.txt : finding headings and counts per round/section (s323)
- list.py / sp322.txt          : s322 spawn listing
