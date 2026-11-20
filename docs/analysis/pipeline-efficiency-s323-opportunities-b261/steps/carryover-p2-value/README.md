# carryover-p2-value (read only)
- heads.py -> heads.txt : every CRITICAL/MAJOR heading in coe-adversarial-p1/p2/p3 of graph s320, s322, s323 (regex handles the em dash and the p3 "--" form; no CRITICAL exists in any p2/p3 file, grep -c CRITICAL hits are prose).
- bodies.py -> bodies.txt : first 1500 chars of the BODY of each p2/p3 MAJOR (provenance lines "Introduced by" are read from here).
- s320 provenance by blob (git cat-file in graph, tokens counted with grep -c -F, control ZZ-NEVER-TOKEN-x9 = 0 in all five blobs): 'not actually fee-inclusive' r1=0 r2=0 r2b=1 r3=1 r4=0.
- Cost: spawns.jsonl description/time windows (s322 listing printed inline in the session); s323 matches rounds_t.py of the step reader (n=13, $19.5).
