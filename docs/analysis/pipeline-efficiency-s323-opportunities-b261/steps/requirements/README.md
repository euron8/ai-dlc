# requirements step analysis (C10 round 2) - scripts and outputs
All read only; population graph s321-s323 (s318-s320 spawns in phases3.out); MONO extraction, python3 -I.
- timeline.py <uuid> <startZ> <endZ>  -> tl1.txt (lead 68cf8de7), tl2.txt (lead 4b34031d): lead tool_use timeline s323 requirements, with gaps.
- asks.py -> asks.out: every AskUserQuestion in requirements lead windows s321-s323, ask-to-answer minutes (tool_use/tool_result paired by id).
- readers.py -> readers.jsonl (+ agg.py, agg2.py): who READ prd/brief/SPEC/locked/arch-impact; 3,102 transcripts s321-s323; ok-result reads only.
- phases.py -> phases.out: s323 phases by spawn start window (spawns, agent-h, usd, lead calls, lead gap proxy; proxy 442 min vs segs 286: relative only).
- phases3.py -> phases3.out: per-sprint round table s318-s323 by first-dispatch boundaries.
- steprefs.py -> steprefs.out: reads of discovery.md / research-requirements.md / requirements.md / _gate-procedures.md by lead and authoring chain.
- chain.txt: tool_use list of the s323 authoring-chain agent (agent-ac9daf2c922ae6d69).
Controls: steps.csv elapsed 11.14/9.90/13.52 h reproduces the lead figures; asks.py ask count nonzero; readers.py locked-requirements reads >0 in stories.
