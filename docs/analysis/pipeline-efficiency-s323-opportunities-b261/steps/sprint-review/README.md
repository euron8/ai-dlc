# sprint-review step analysis (C10 round 2), scratch dir

- phases.py: classifies every spawn labelled sprint-review (s321-s323) into phases; prints n, $, agent-min. Control: s321 seats 125/$144.06 and s322 seats 40/$47.24 equal step-value-sprint-review-*.md.
- agent_active.json: per spawn (sprint, phase, description, active-min [event gaps <= 300 s], span-min, $). Active vs span shows resume gaps (Step-3 QA span 60.5 min, active about 4).
- tl1.tsv / tl2.tsv: lead tool-call timeline (s323 lead sessions 53b4296a 02:50-08:00 and 64926214 12:40-20:30, UTC); *.c.txt condensed views; win1.txt / win2.txt windows (party close to Step 3; gate).
- majors.txt: the 26 `(major)` headings of the 95 s323 seat files with first 420 chars.
- Not scripts but derived by the commands in the report: rate-limit spawns (final_text starts "API Error", 36 spawns, $23.94, 205.5 span-min), survival greps at graph eabdc576e (controls: APP_ENV present, zzqx9917nope absent), earlier-raise greps at 893c0c128.
- All graph reads were git show / git grep / ls / python read-only. Nothing written outside this directory.
