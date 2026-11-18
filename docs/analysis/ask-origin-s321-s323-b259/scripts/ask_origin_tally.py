"""ask_origin_tally.py -- BL-972 origin split, step 2: tables from the classified questions.

usage: python3 -I ask_origin_tally.py CLASSIFICATION_TSV
CLASSIFICATION_TSV has one row per question: ask, q, sprint, ask_start, step, wait_min, lanes_running, dispatched,
header, class, blocking, reason. class is P (planning-knowable), E (emergent evidence), M (pipeline mechanics) or
A (authorization); the definitions are in the report. An ask's wait is counted once, on the ask, under the set of
classes its questions carry."""
import collections, csv, sys
rows = list(csv.DictReader(open(sys.argv[1]), delimiter="\t"))
PLAN = {"route", "carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}
def phase(st):
    b = st.split("[")[0] if not st.startswith("gate-validation") else st[16:-1]
    return "planning" if b in PLAN else ("implementation" if b == "implementation" else "after")
asks = collections.OrderedDict()
for r in rows:
    a = asks.setdefault(r["ask"], dict(sprint=r["sprint"], phase=phase(r["step"]), step=r["step"], wait=float(r["wait_min"]),
                                       lanes=r["lanes_running"], cls=set(), hdr=[]))
    a["cls"].add(r["class"]); a["hdr"].append(r["header"])
SP = sorted({r["sprint"] for r in rows}); PH = ("planning", "implementation", "after")
print(f"questions {len(rows)}; asks {len(asks)}; wait minutes {sum(a['wait'] for a in asks.values()):.0f}")
print("\n== questions by class")
for s in SP + ["all"]:
    c = collections.Counter(r["class"] for r in rows if s in ("all", r["sprint"]))
    n = sum(c.values()); print(f"{s}: " + ", ".join(f"{k} {c[k]} ({100 * c[k] / n:.0f}%)" for k in "PEMA") + f"; total {n}")
print("\n== questions by sprint, phase and class")
for s in SP:
    for p in PH:
        c = collections.Counter(r["class"] for r in rows if r["sprint"] == s and phase(r["step"]) == p)
        if c: print(f"{s} {p}: " + ", ".join(f"{k} {c[k]}" for k in "PEMA") + f"; total {sum(c.values())}")
print("\n== ask wait minutes by the classes an ask carries (an ask with any P question is 'has P')")
for s in SP + ["all"]:
    A = [a for a in asks.values() if s in ("all", a["sprint"])]
    w = lambda f: sum(a["wait"] for a in A if f(a)); n = lambda f: sum(1 for a in A if f(a)); t = w(lambda a: True)
    print(f"{s}: {len(A)} asks, {t:.0f} min | P only {n(lambda a: a['cls'] == {'P'})} asks {w(lambda a: a['cls'] == {'P'}):.0f} min"
          f" | has P {n(lambda a: 'P' in a['cls'])} asks {w(lambda a: 'P' in a['cls']):.0f} min ({100 * w(lambda a: 'P' in a['cls']) / t:.0f}%)"
          f" | no P: E-led {n(lambda a: 'P' not in a['cls'] and 'E' in a['cls'])} asks {w(lambda a: 'P' not in a['cls'] and 'E' in a['cls']):.0f} min,"
          f" M only {n(lambda a: a['cls'] == {'M'})} asks {w(lambda a: a['cls'] == {'M'}):.0f} min, A only {n(lambda a: a['cls'] == {'A'})} asks {w(lambda a: a['cls'] == {'A'}):.0f} min")
print("\n== ask wait minutes for asks carrying a P or an A question (what a checkpoint declared at planning could name)")
for s_ in SP + ["all"]:
    A = [a for a in asks.values() if s_ in ("all", a["sprint"])]; t = sum(a["wait"] for a in A)
    pa = [a for a in A if a["cls"] & {"P", "A"}]; pure = [a for a in A if a["cls"] <= {"P", "A"}]
    print(f"{s_}: has P or A {len(pa)} asks {sum(a['wait'] for a in pa):.0f} of {t:.0f} min ({100 * sum(a['wait'] for a in pa) / t:.0f}%);"
          f" only P and A questions {len(pure)} asks {sum(a['wait'] for a in pure):.0f} min ({100 * sum(a['wait'] for a in pure) / t:.0f}%)")
print("\n== M questions asked in a planning step, per sprint (s323 has planning only)")
print(", ".join(f"{s_} {sum(1 for r in rows if r['sprint'] == s_ and r['class'] == 'M' and phase(r['step']) == 'planning')}" for s_ in SP))
print("\n== blocking flag by classifier half (asks 1-40 one reader, 41-79 the other)")
for nm, lo, hi in (("asks 1-40", 1, 40), ("asks 41-79", 41, 79)):
    c2 = collections.Counter(r["blocking"] for r in rows if lo <= int(r["ask"]) <= hi)
    sp_ = sorted({r["sprint"] for r in rows if lo <= int(r["ask"]) <= hi})
    print(f"{nm} ({'/'.join(sp_)}): " + ", ".join(f"{b} {c2[b]}" for b in "YNU"))
print("\n== asks that waited over 60 minutes")
big = [(k, a) for k, a in asks.items() if a["wait"] > 60]
for k, a in big:
    print(f"ask {k} {a['sprint']} {a['step']}: {a['wait']:.0f} min, classes {'+'.join(sorted(a['cls']))}, lanes running at ask {a['lanes']}, headers {a['hdr']}")
print(f"over-60 asks: {len(big)} holding {sum(a['wait'] for _, a in big):.0f} of {sum(a['wait'] for a in asks.values()):.0f} min; with a P question {sum(1 for _, a in big if 'P' in a['cls'])}; with a P or A question {sum(1 for _, a in big if a['cls'] & {'P', 'A'})}")
print("\n== class by blocking flag (Y the text says nothing can continue, N other work continues, U cannot tell)")
c = collections.Counter((r["class"], r["blocking"]) for r in rows)
for k in "PEMA": print(f"{k}: " + ", ".join(f"{b} {c[(k, b)]}" for b in "YNU"))
print("\n== veto-style questions (the lead already decided and asks only for a veto): reason or header contains 'veto'")
v = [r for r in rows if "veto" in (r["reason"] + " " + r["header"]).lower()]
print(f"{len(v)} questions in {len({r['ask'] for r in v})} asks; wait of those asks {sum(asks[k]['wait'] for k in {r['ask'] for r in v}):.0f} min")
