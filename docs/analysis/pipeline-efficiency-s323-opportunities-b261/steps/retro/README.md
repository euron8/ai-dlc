# retro step analysis (scripts and outputs; read-only on transcripts, MONO and graph)
timeline.py SESS START END OUT   per-tool-call timeline of a lead transcript window (tool_use paired with tool_result; err flag). Outputs tl_s323.tsv, tl_s322.tsv, tl_s321.tsv, tl_s320.tsv, tl_s319a.tsv, tl_s319b.tsv, tl_s318.tsv
phases_s323.py                    hand-set phase boundaries over tl_s323.tsv -> wall minutes, calls, re-read calls per phase (control: total wall 161.6 min = segs window 01:36:11-04:17:36)
readers.py SESS START END         next sprint's first lead session: executed calls touching previous retro outputs. Outputs readers_s323_first.txt, readers_s322_first.txt
readers_all.py SPRINT EXCL        same over every lead session of the sprint (control: the retro session itself, run with EXCL=zzzz, shows next-inputs 14 hits)
arch.py SPRINT EXCL               reads of rotated archives (gate-log, continuation, compaction, pending, carry-over-backlog archives)
ctx.py ctx2.py first.py tail.py pushres.py  small context printers (hit context, first user message, transcript tail, push result tail)
Inputs: MONO/steps.csv, segs.jsonl, spawns.jsonl (not modified); graph docs/retro/s318-s323 at a9b015557; core/skills/ai-dlc/steps/retro.md at e7a82151e.
Control for step-file facts: retro.md 1739 lines / 101094 bytes (wc), code fences 8 / 170 lines / 10205 bytes.
