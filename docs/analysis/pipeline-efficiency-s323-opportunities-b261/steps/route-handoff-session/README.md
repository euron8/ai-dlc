# route-handoff-session (read-only measurements, s321-s323)

- measure.py handoff     : per-handoff elapsed, in-session minutes (handoff.md read to .driver/handoff touch), push window. Out: s321 197 min/12, s322 434/4 (361 in one session), s323 36/4.
- measure.py stophook    : forced-continuation Stop hook feedback counts per sprint (pipeline-active vs HANDOFF GUARD). Out: 39/64/63 and 4/15/6.
- measure.py compaction  : compact_boundary postTokens per sprint. Out: median 32K/23K/45K.
- measure.py advisor     : advisor attempts, paired latency. Out: s323 224 attempts, 31 s median, 2.10 h.
- measure.py snapshot    : snapshot-update.sh calls by kind. Out: s323 1343 calls, 98 --help, 363 move-to-history ops.
- measure.py startup     : first route read, first step-file read, first Agent per s323 pipeline session. Out: 4.7+12.6+17.0+6.7+5.5 = 46.5 min.
- adv323.json            : the 239 s323 advisor consult results with the lead text before each (input to the catch reading).
Other figures (phase-A attribution, post-compact window reads, owed-derivations results, Read bytes by file) were computed inline in ctx_execute and are described in the report; not re-run from files.
Run: python3 -I measure.py <name>. Population note: lead sessions labelled s321-s323 in segs.jsonl; s323 compactions read 149 here vs 134 in the roll.
