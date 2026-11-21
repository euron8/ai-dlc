"""BL-812 owed item: the s323 parts whose reading is "no measured value", per part, for the builder (batch 263, J).

usage: python3 -I novalue_parts_s323.py OUT      (OUT = the extraction the README names; spawns.jsonl only)

For each part: spawns, subagent $ (spawns.jsonl `usd`, API pricing; a local-model row is $0 there and is counted
apart), agent-hours (summed spawn minutes, idle included) and tokens (`tok`), with per-story figures over 18
stories. The parts are selected by label and exact description, the same rows the yield readers put in them:
  gate-validation[requirements]       every row of the label (req_yield_s323.py section 1)
  research-requirements PRD walk      every row of the label (req_yield_s323.py)
  gate-validation[sprint-review]      the 8 gate adjudicator shards plus the gate-failure remediator
                                      (tail_yield_s323.py; the label's 4 story-2.2/2.3 rows are story work by clock)
  carry-over routing rows             analyst draft, party dispatcher, live reads, adjudication/closure, OQ fold
                                      (co_yield_s323.py "routing, dispatcher, draft and adjudication/closure rows")
Controls: each part's spawns and $ equal the figure its yield reader prints (MATCH/DIFFERS); an impossible
description reads 0 rows.
"""
import json, os, sys

OUT = sys.argv[1]
rows = [json.loads(l) for l in open(os.path.join(OUT, "spawns.jsonl"))]
S323 = [r for r in rows if int(r["sprint"]) == 323]
N = 18
PARTS = [
    ("gate-validation[requirements]", lambda r: r["step"] == "gate-validation[requirements]", (3, 1.80)),
    ("research-requirements PRD walk", lambda r: r["step"] == "research-requirements", (1, 0.74)),
    ("gate-validation[sprint-review] gate (shards + remediator)",
     lambda r: r["step"] == "gate-validation[sprint-review]" and (r["description"].startswith("Gate adjudicator shard")
                                                                  or r["description"] == "Gate-failure remediator sprint-review"), (9, 5.62)),
    ("carry-over routing, dispatcher, draft, adjudication/closure rows",
     lambda r: r["step"] == "carry-over-evaluation" and (
         r["description"] in ("Sprint 323 carry-over evaluation draft", "Read-only Base task-def APP_ENV check",
                              "Verify Merkl Base distributor address", "Day-0 live reads for s323", "Read live Base config keys",
                              "Adjudication remediator for CoE", "Dispatch closure-writer remediator",
                              "Fold answered OQs into requirements artifacts")
         or ("dispatch" in r["description"].lower() and "party" in r["description"].lower())), (9, 30.96)),
    # BL-810's amended width rule: a cross group with no unique surviving catch is narrowed or merged
    # (co_yield_s323.py: p2 cross UNIQUE-SURVIVED 0, p3 cross 0 C/M)
    ("carry-over adversarial p2 cross", lambda r: r["step"] == "carry-over-evaluation" and r["description"] == "Adversarial p2 cross shard", (1, 4.33)),
    ("carry-over adversarial p3 cross", lambda r: r["step"] == "carry-over-evaluation" and r["description"] == "Adversarial p3 cross shard", (1, 3.13)),
]
for name, pred, (ref_n, ref_usd) in PARTS:
    rs = [r for r in S323 if pred(r)]
    n = len(rs); usd = sum(r.get("usd") or 0 for r in rs); mn = sum(r.get("minutes") or 0 for r in rs)
    tok = sum(r.get("tok") or 0 for r in rs); loc = sum(1 for r in rs if r.get("model_ran") == "local")
    print("%-62s %2d spawns  $%6.2f API (%d local-model row(s) at $0)  %.2f agent-h  %.1fM tokens | per story %.2f spawns  $%.2f  %.3f agent-h  %.2fM"
          % (name, n, usd, loc, mn / 60, tok / 1e6, n / N, usd / N, mn / 60 / N, tok / 1e6 / N))
    print("   control against its yield reader (%d spawns, $%.2f): %s" % (
        ref_n, ref_usd, "MATCH" if (n, "%.2f" % usd) == (ref_n, "%.2f" % ref_usd) else "DIFFERS"))
    for r in sorted(rs, key=lambda r: r["start"]):
        print("     %s  %-50s $%.3f  %.1f min  %.2fM  %s" % (r["start"][:16], r["description"][:50], r.get("usd") or 0,
                                                       r.get("minutes") or 0, (r.get("tok") or 0) / 1e6, r.get("model_ran")))
print("impossible description: %d rows" % sum(1 for r in S323 if r["description"] == "QZXV-NO-SUCH-DESC-7731"))
