"""b261: join graph's spawn ledger at a9b015557 (s323 rows) against the extract's sprint-323 subagent units (units.jsonl of c5main).
usage: python3 -I ledger.py <graph clone> <extract OUT>
Both set differences are printed. Control: the same join for s322 on the same corpus must also be printed (a join that
is empty on both sides for every sprint is a join that cannot see rows)."""
import json, subprocess, sys, collections
G, OUT = sys.argv[1], sys.argv[2]
raw = subprocess.run(["git", "-C", G, "show", "a9b015557:_bmad-output/spawn-ledger.jsonl"], capture_output=True, text=True).stdout.split("\n")
rows = []
for l in raw:
    l = l.strip()
    if not l: continue
    try: rows.append(json.loads(l))
    except Exception: pass

units = [json.loads(l) for l in open(OUT + "/units.jsonl")]
by = collections.defaultdict(lambda: [set(), set()])
for r in rows:
    if r.get("tool_use_id"): by[r.get("sprint")][0].add(r["tool_use_id"])
for u in units:
    if u["kind"] == "sub" and (u.get("meta") or {}).get("toolUseId"): by[u["sprint"]][1].add(u["meta"]["toolUseId"])
for n in (321, 322, 323):
    L, U = by[n]
    print(f"s{n}: ledger rows with a tool_use_id {len(L)}, extract subagent units with a toolUseId {len(U)}, in both {len(L & U)}, "
          f"ledger-only {len(L - U)}, extract-only {len(U - L)}")
    if n == 323:
        lo = sorted(L - U); eo = sorted(U - L)
        ts = {r["tool_use_id"]: r["ts"] for r in rows if r.get("tool_use_id")}
        print("   ledger-only (first 5):", [(x[-8:], ts[x]) for x in lo[:5]])
        uu = {(u.get("meta") or {}).get("toolUseId"): u for u in units if u["kind"] == "sub"}
        print("   extract-only (first 5):", [(x[-8:], uu[x]["first"][:19], (uu[x]["meta"].get("agentType"))) for x in eo[:5]])

# b261 follow-up: where the 323 differences sit
L, U = by[323]
rows323 = [r for r in rows if r.get("sprint") == 323 and r.get("tool_use_id")]
print("   s323 ledger ts range", min(r["ts"] for r in rows323), max(r["ts"] for r in rows323))
lo = L - U; eo = U - L
other = {n: len(eo & by[n][0]) for n in by if n != 323 and n is not None and (eo & by[n][0])}
print("   extract-only s323 units that the ledger carries under another sprint label:", other, "; carried by no ledger row:", len(eo - set().union(*[by[n][0] for n in by if n != 323])))
print("   ledger-only suffix shapes:", collections.Counter(("_" + x.split("_")[-1]) if x.count("_") > 1 or x.endswith("_0") else "plain" for x in lo).most_common(4))
print("   ledger-only whose bare id (suffix stripped) matches an extract unit:", sum(1 for x in lo if x.rsplit("_", 1)[0] in U))
print("   s323 extract-only agentTypes:", collections.Counter(((u.get("meta") or {}).get("agentType")) for u in units if u["kind"] == "sub" and (u.get("meta") or {}).get("toolUseId") in eo))
