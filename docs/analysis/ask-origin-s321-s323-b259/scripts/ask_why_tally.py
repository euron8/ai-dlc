"""ask_why_tally.py -- why the operator was asked: tables from out/why.tsv.

usage: python3 -I ask_why_tally.py WHY_TSV
One row per question: ask, q, sprint, ask_start, step, wait_min, lanes_running, header, why, rule_cited,
answer_kind, reason. `why` is a reader's judgment of what stopped the lead deciding (RULE, INFO, AMBIG, ACT,
DEFECT, NONE; defined in the report). `answer_kind` is mechanical (ask_dump.py). An ask's wait is counted once,
on the ask; "asks made only of X" are the asks whose every question is in X, which is the wait a change to X
alone could remove."""
import collections, csv, sys
rows = list(csv.DictReader(open(sys.argv[1]), delimiter="\t"))
W = ("RULE", "ACT", "NONE", "INFO", "AMBIG", "DEFECT"); SP = sorted({r["sprint"] for r in rows})
asks = collections.OrderedDict()
for r in rows: asks.setdefault(r["ask"], dict(sprint=r["sprint"], wait=float(r["wait_min"]), step=r["step"], qs=[]))["qs"].append(r)
T = sum(a["wait"] for a in asks.values())
print(f"questions {len(rows)}; asks {len(asks)}; wait minutes {T:.0f}")
print("\n== how the operator answered (mechanical)")
c = collections.Counter(r["answer_kind"] for r in rows); badged = [r for r in rows if not r["answer_kind"].startswith("unbadged")]
print(", ".join(f"{k} {v}" for k, v in c.most_common()))
print(f"questions with a recommended option {len(badged)}; operator took it {c['took-recommended']}; other option {c['other-option']}; free text {c['free-text']}")
allrec = [a for a in asks.values() if all(r["answer_kind"] == "took-recommended" for r in a["qs"])]
print(f"asks in which every answer was the recommended option: {len(allrec)} asks, {sum(a['wait'] for a in allrec):.0f} min ({100 * sum(a['wait'] for a in allrec) / T:.0f}%)")
print("not taken:", [(r["ask"], r["q"], r["why"], r["answer_kind"], r["header"]) for r in badged if r["answer_kind"] != "took-recommended"])
def cover(pred):
    full = [a for a in asks.values() if all(pred(r) for r in a["qs"])]
    part = [a for a in asks.values() if any(pred(r) for r in a["qs"]) and not all(pred(r) for r in a["qs"])]
    return sum(1 for r in rows if pred(r)), full, part
print("\n== what stopped the lead (judgment), with the wait on asks made only of that class")
for k in W:
    n, full, part = cover(lambda r: r["why"] == k)
    by = ", ".join(f"{s} {sum(1 for a in full if a['sprint'] == s)} asks {sum(a['wait'] for a in full if a['sprint'] == s):.0f} min" for s in SP)
    print(f"{k}: {n} questions ({100 * n / len(rows):.0f}%); only-{k} asks {len(full)} waiting {sum(a['wait'] for a in full):.0f} min ({100 * sum(a['wait'] for a in full) / T:.0f}%); in {len(part)} more asks beside other classes | {by}")
print("\n== class by sprint")
for s in SP: print(s + ": " + ", ".join(f"{k} {sum(1 for r in rows if r['sprint'] == s and r['why'] == k)}" for k in W))
print("\n== class by reader (odd asks one reader, even asks the other)")
for nm, m in (("odd", 1), ("even", 0)): print(nm + ": " + ", ".join(f"{k} {sum(1 for r in rows if int(r['ask']) % 2 == m and r['why'] == k)}" for k in W))
print("\n== class by answer kind")
for k in W: print(k + ": " + ", ".join(f"{a} {v}" for a, v in collections.Counter(r["answer_kind"] for r in rows if r["why"] == k).most_common()))
print("\n== combinations")
for nm, pred in (("NONE", lambda r: r["why"] == "NONE"), ("NONE or DEFECT", lambda r: r["why"] in ("NONE", "DEFECT")),
                 ("NONE, or any class answered with the recommended option", lambda r: r["why"] == "NONE" or r["answer_kind"] == "took-recommended"),
                 ("INFO or AMBIG", lambda r: r["why"] in ("INFO", "AMBIG"))):
    n, full, part = cover(pred)
    print(f"{nm}: {n} questions; asks made only of them {len(full)} waiting {sum(a['wait'] for a in full):.0f} min ({100 * sum(a['wait'] for a in full) / T:.0f}%); partly {len(part)}")
print("\n== NONE questions not answered with the recommended or the first option")
for r in rows:
    if r["why"] == "NONE" and r["answer_kind"] not in ("took-recommended", "unbadged:first-option"): print(f"ask {r['ask']}.{r['q']} {r['sprint']} {r['step']} [{r['header']}] {r['answer_kind']}")
print("\n== rules the questions cite as the reason to ask (reader's reading; '-' means none named)")
print(", ".join(f"{k} {v}" for k, v in collections.Counter(r["rule_cited"] for r in rows if r["rule_cited"] != "-").most_common()))
print(f"RULE questions naming no rule: {sum(1 for r in rows if r['why'] == 'RULE' and r['rule_cited'] == '-')} of {sum(1 for r in rows if r['why'] == 'RULE')}")
print("\n== the ten asks over 60 minutes")
for k, a in asks.items():
    if a["wait"] > 60: print(f"ask {k} {a['sprint']} {a['step']} {a['wait']:.0f} min: " + "; ".join(f"{r['why']}/{r['answer_kind']}" for r in a["qs"]))
