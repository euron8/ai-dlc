"""BL-543 held reading: serial-remediator pass spans, per sprint, same selection in every sprint. b261.
usage: python3 -I serial_spans.py OUT
Selection (identical for s319, s322, s323): spawns.jsonl rows (spawns.py run from the af44929cc checkout, WIN_END 2026-11-20T04:20:00Z)
with role remediator, description matching SERIAL, step (gate rows included by base) one of the four planning steps.
Span = the spawn's own first-to-last transcript record in minutes (spawns.py `minutes`); no segs clock is involved.
Control: s319 agent a4b9c05a506fc183b must read 31.1 min (BL-543 fourth timing, b256 control)."""
import json, re, sys, collections
OUT = sys.argv[1]
SERIAL = re.compile(r"serial|adjudicat|lane|fan-?in|cross-section|cross-part", re.I)
PLANS = {"carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}
base = lambda st: st[16:-1] if st.startswith("gate-validation[") else st
sp = [json.loads(l) for l in open(OUT + "/spawns.jsonl")]
for n in (319, 322, 323):
    S = sorted([x for x in sp if x["sprint"] == n and x["role"] == "remediator" and SERIAL.search(x["description"]) and base(x["step"]) in PLANS], key=lambda x: x["start"])
    m = [x["minutes"] for x in S]
    print(f"s{n}: {len(S)} serial-class remediator spawns, total {sum(m):.1f} min, mean {sum(m)/len(m):.1f} min, median {sorted(m)[len(m)//2]:.1f}, longest {max(m):.1f} min ({[x['unit'][-6:] for x in S if x['minutes']==max(m)][0]}), dollars ${sum(x['usd'] for x in S):.1f}, tool calls {sum(x['calls'] for x in S)}")
c = [x for x in sp if x["unit"] == "agent-a4b9c05a506fc183b"]
print("CONTROL a4b9c05a506fc183b minutes:", c[0]["minutes"] if c else "ABSENT", "(must read 31.1)")
print("-- s323 rows: start(UTC) step | description | minutes | calls | $ | agent")
for x in sorted([x for x in sp if x["sprint"] == 323 and x["role"] == "remediator" and SERIAL.search(x["description"]) and base(x["step"]) in PLANS], key=lambda x: x["start"]):
    print(f"{x['start'][5:16]} {base(x['step'])[:10]:10} | {x['description'][:48]:48} | {x['minutes']:5.1f} | {x['calls']:3d} | ${x['usd']:.2f} | {x['unit'][-17:]}")
