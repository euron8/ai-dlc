gate-validation step analysis (C10 round 2). All scripts read-only; run with python3 -I.
metrics.py    gate-metrics.jsonl (graph) tally per check/verdict for s321-s323 (core + extension catalogs). Output: stdout.
verdicts.py   adjudication verdict.json FAIL rows s321-s323 (all gate types) with evidence head. Output: stdout.
parts.py      verdict + part files merged per stem; non-implementation gates only. Output: parts.out.
timeline.py   <session> <start> <end> [width]: lead tool calls in a window. Outputs: retro_tl.txt (s323 retro gate), stories_tl.txt (s323 stories gate).
gatereads.py  lead Reads of gate-validation.md / _gate-procedures.md / extension checks per gate window, bytes and compactions. Output: gatereads.out.
sizes.py      byte size per heading of both step files. Output: sizes.out.
Controls: gatereads total (188 impl + 200 non-impl = 388 reads of gate-validation.md) matches the brief's 391; segs compactions in gate windows
(26 non-impl + 39 impl = 65) match the brief's 65. gate-slice.sh --type sprint-review gives 101515 of 245350 B on graph's copy, while the s323
SR gate-log H1 row says 71628 B loaded: the lead loaded fewer bytes than the plan (unexplained, see unmeasured list).
Not re-run: extraction (MONO), roll.py.
