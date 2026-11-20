# deploy-validate step analysis, scripts and outputs (all read only; run with python3 -I)
timeline.py SESSION A B        compact event timeline of a lead transcript window (GAP env = gap threshold s). Outputs: s321a.tl, s322.tl, s323.tl
asks.py SESSION A B            one row per AskUserQuestion: wait, header, options, result. Outputs: s321a/s321b/s322/s323 .asks.tsv
phases.py SESSION A B "l=ISO,.." SPRINT   per-phase wall/active/op-gap/agent-gap/asks/spawns/agent-min/usd. Outputs: s321.phases.txt, s323.phases.txt
reads_and_tools.py SESSION A B ok tool counts (paired with tool_result, errors dropped), Read counts, latency. Outputs: s32x.tools.txt
bashcls.py SESSION A B         Bash calls by purpose and latency. Outputs: s32x.bashcls.txt
leadtime.py SESSION A B        lead generation time by tool category (covers ~48% of active min; proportional use only). Outputs: s32x.leadtime.txt
Windows: s321 = 4f12d1d9 (2026-11-07T14:39Z..11-08T16:22Z) + df56108b (to 11-08T18:43Z); s322 = e444bf13; s323 = 64926214.
Controls: phases.py totals vs MONO/steps.csv (s323 5.3 h wall, 3.7 h active vs 4.03); spawn usd 100.18/5.16/20.43 = spawns.jsonl;
s321 uuid overlap check: 183 of 183 records in 4f12d1d9 15:25-16:20 are also in df56108b (double counted window).
