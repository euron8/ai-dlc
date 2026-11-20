import json, os, re, pickle, collections, sys
D = os.path.dirname(os.path.abspath(__file__))
PLAN = {"carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}
IMPL = {"implementation", "gate-validation"}
def grp(step):
    b = step.split("[")[0]
    if b in PLAN: return "planning"
    if b in IMPL: return "impl+gate"
    if b == "sprint-review": return "sprint-review"
    return "rest"

def build():
    units = collections.OrderedDict()
    for l in open(D + "/x/rec.jsonl"):
        e = json.loads(l); units.setdefault(e["u0"], []).append(e)
    keep = set()
    for l in open(D + "/x/units.jsonl"):
        r = json.loads(l); sk = r["skills"]
        stepped = any(k.split("|", 1)[0] != "pre-step" for k in r["tok"])
        if stepped: keep.add(r["unit"])
    units = collections.OrderedDict((u, v) for u, v in units.items() if u in keep)
    calls = {}; ivs = []; res = {}; comps = []; reqs = []; flows = []; order = collections.defaultdict(list); summ = {}
    for u, evs in units.items():
        recover = False; key = ("cls", "other"); last_mid = None; tu_mid = {}; clk = None
        prev_api = False; prev_end = False; last_req = None; names = {}
        for e in evs:
            f = e["f"]; ty = e["ty"]
            # interval
            if clk is not None:
                d = max(0.0, f - clk)
                if key[0] == "cls": cls = key[1]; mid = None
                else:
                    mid = key[1]; c = calls.get(mid); cls = c["cls"] if c else "other"
                # lead_time subkind
                if ty == "assistant": sk = "model"
                elif ty == "user":
                    sk = "wake"
                    for x in e.get("res") or []:
                        sk = "tool:" + names.get(x[0], "?"); break
                else: sk = "harness"
                if prev_api and not sk.startswith("tool:"): sk = "model"
                if prev_end: sk = "idle-wait"
                ivs.append((u, e["s"], e["st"], d, cls, mid, sk, ty, (e.get("at") or e.get("op") or e.get("sub") or "") + ((":" + str(e.get("hk"))) if e.get("hk") else "")))
            clk = f if clk is None else max(clk, f)
            prev_api = (ty == "api-request"); prev_end = (ty == "system" and e.get("sub") == "turn_duration")
            if ty == "api-request": last_req = f; reqs.append((u, e["s"], f))
            if e.get("cs"):
                recover = True; comps.append(dict(u=u, s=e["s"], f=f, st=e["st"], ci=len(order[u]), cs=1))
            if ty == "system" and e.get("sub") == "compact_boundary":
                comps.append(dict(u=u, s=e["s"], f=f, st=e["st"], ci=len(order[u]), **(e.get("cm") or {})))
            if ty == "user" and e.get("tx") is not None and not e.get("res"):
                flows.append((u, e["s"], len(order[u]), "utext", e["tx"][:24], "", e.get("sz", 0)))
            if ty == "attachment" and e.get("sz"):
                flows.append((u, e["s"], len(order[u]), "att", (e.get("at") or "") + ((":" + str(e.get("hk"))) if e.get("hk") else ""), e.get("hh", ""), e.get("hb") if e.get("hb") is not None else e.get("sz")))
            if ty == "assistant":
                mid = e.get("mid")
                if not mid: key = ("cls", "other"); continue
                last_mid = mid
                c = calls.get(mid)
                if c is None:
                    order[u].append(mid); c = calls[mid] = dict(i=len(order[u]) - 1, u=u, s=e["s"], step=e["st"], cls=e.get("cls", "other"), model=e.get("model"), uu=[0, 0, 0, 0], b=[],
                                          t0=f, t1=f, treq=last_req, recov=recover)
                c["t1"] = f
                c["uu"] = [max(a, b) for a, b in zip(c["uu"], e["u"])]
                c["b"].extend(e.get("b") or [])
                for b in e.get("b") or []:
                    if b[0] == "tu":
                        tu_mid[b[2]] = mid; names[b[2]] = b[1]; summ[b[2]] = b[3]
                        if recover and b[1] not in ("Read", "Grep", "Glob"): recover = False
                key = ("mid", mid); continue
            if recover: key = ("cls", "compaction-recovery"); continue
            if ty == "system" and e.get("sub") == "turn_duration": key = ("cls", "idle-wait"); continue
            tid = None
            for x in e.get("res") or []:
                tid = x[0]; break
            m = tu_mid.get(tid) if tid else None
            m = m or last_mid
            key = ("mid", m) if m else ("cls", "other")
            for x in e.get("res") or []:
                res[x[0]] = dict(u=u, mid=tu_mid.get(x[0]), t=f, b=x[1], err=x[2], head=x[3], name=names.get(x[0]), summ=summ.get(x[0], ""), ci=len(order[u]))
                flows.append((u, e["s"], len(order[u]), "res", names.get(x[0]) or "?", summ.get(x[0], ""), x[1]))
    return units, calls, ivs, res, comps, flows, order

if __name__ == "__main__":
    units, calls, ivs, res, comps, flows, order = build()
    pickle.dump((calls, ivs, res, comps, flows, dict(order)), open(D + "/lib.pkl", "wb"))
    # control vs classes.jsonl
    a = collections.defaultdict(lambda: [0.0, 0.0])
    for u, s, st, d, cls, mid, sk, ty, det in ivs:
        a[(s, cls)][0 if d <= 300 else 1] += d / 3600
    n = collections.Counter()
    for m, c in calls.items(): n[(c["s"], c["cls"])] += 1
    for k in sorted(a, key=lambda x: (x[0] or 0, x[1])):
        if k[0] in (321, 322, 323): print(k, "act %.2f gap %.2f calls %d" % (a[k][0], a[k][1], n[k]))
