"""b259 consolidating reader: tables that no committed script prints, taken over the pinned OUT dir.

usage: EXTRACT_WIN_END=2026-11-12T14:41:00Z python3 -I tables_s322_complete.py OUT ROLL_TXT ROLL_CLASSES_TXT ASK_SPLIT_TXT
  OUT               extract.py/spawns.py output dir (units.jsonl segs.jsonl spawns.jsonl classes.jsonl)
  ROLL_TXT          roll.py OUT           stdout
  ROLL_CLASSES_TXT  roll.py OUT --classes stdout
  ASK_SPLIT_TXT     ask_split.py OUT      stdout
Prints: per-step elapsed h / token-eq $ with each step's own gate folded in; lead call classes per story;
the stories party round; longest asks and spawns in s322; the control counts (token sums, join, past-pin).
Reads the transcript root only for the past-pin count (read-only)."""
import json, os, re, sys, glob, collections, datetime as dt

OUT, ROLL, CLS, ASK = sys.argv[1:5]
PIN = os.environ.get("EXTRACT_WIN_END") or sys.exit("EXTRACT_WIN_END unset")
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
EDGE = "2026-11-13T08:00:00Z"   # extract.py EDGES: s322 ends here
STO = {317: 21, 318: 13, 319: 20, 320: 13, 321: 25, 322: 8}
T = lambda s: dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
SP = list(range(317, 323))

# 1. per-step, step + own gate
rows = {}
for l in open(ROLL):
    c = [x.strip() for x in l.rstrip("\n").split("|")]
    if len(c) == 7 and c[0] and c[0] != "step" and not c[0].startswith(("extractor", "hours", "lead-seat", "s3")):
        v = []
        for x in c[1:]:
            m = re.match(r"([\d.]+)/\s*([\d.]+)\s+\$\s*(\d+)/\$\s*(\d+)", x)
            v.append((float(m.group(1)), float(m.group(2)), int(m.group(3)), int(m.group(4))) if m else None)
        rows[c[0]] = v
print("== per step, elapsed h / token-eq $, step plus gate[step]; STORIES", STO)
for st in ["carry-over-evaluation", "requirements", "architecture", "stories-test-strategy", "implementation",
           "sprint-review", "deploy-validate", "retro", "bug-investigation", "handoff", "route", "pre-step"]:
    cells = []
    for i, s in enumerate(SP):
        a = rows.get(st, [None] * 6)[i]; g = rows.get("gate[" + st + "]", [None] * 6)[i]
        if not (a or g): cells.append("-".rjust(12)); continue
        h = (a[0] if a else 0) + (g[0] if g else 0); d = (a[3] if a else 0) + (g[3] if g else 0)
        cells.append(f"{h:5.1f} / {d:4d}")
    print(st.ljust(24), " | ".join(cells))

# 2. lead call classes per story
agg = collections.defaultdict(lambda: collections.defaultdict(lambda: [0.0] * 4)); cur = None
for l in open(CLS):
    m = re.match(r"== s(\d+) ", l)
    if m: cur = int(m.group(1)); continue
    m = re.match(r"\s+([a-z-]+)\s+active\s+([\d.]+) h\s+gap\s+([\d.]+) h\s+calls\s+([\d.]+)\s+tok\s+([\d.]+)M\s+lead token-eq \$([\d.]+)", l)
    if m and cur:
        a = agg[cur][m.group(1)]; a[0] += float(m.group(2)); a[1] += float(m.group(3)); a[2] += float(m.group(4)); a[3] += float(m.group(6))
print("\n== lead call classes per planned story: active h | calls | token-eq $   (x STORIES for the sprint total)")
for c in ["dispatch", "merge", "repair", "gate-run", "step-reread", "compaction-recovery", "snapshot", "other", "idle-wait"]:
    print(c.ljust(20), " | ".join(f"s{s} {agg[s][c][0]:.3f} {agg[s][c][2]:6.1f} ${agg[s][c][3]:5.1f}" for s in SP[1:]))
print("sprint total lead class-sum active h:", {s: round(sum(agg[s][c][0] for c in agg[s]) * STO[s], 1) for s in SP[1:]})

# 3. party round
sp = [json.loads(l) for l in open(OUT + "/spawns.jsonl")]
print("\n== stories party round: roles sm,tea,dev,architect in stories-test-strategy; cluster = starts with no >10 min gap")
for s in SP[1:]:
    r = sorted([x for x in sp if x["sprint"] == s and x["step"] == "stories-test-strategy" and x["role"] in ("sm", "tea", "dev", "architect")], key=lambda x: x["start"])
    if not r: continue
    cl = [[r[0]]]
    for x in r[1:]:
        (cl.append([x]) if T(x["start"]) - T(cl[-1][-1]["start"]) > 600 else cl[-1].append(x))
    spans = [(len(c), round((max(T(x["end"]) for x in c) - T(c[0]["start"])) / 60, 1)) for c in cl]
    big = max(cl, key=len)
    print(f"s{s}: seats {len(r)}, sessions {len({x['sess'] for x in r})}, clusters (seats, min) {spans}, largest {len(big)} seats "
          f"{(max(T(x['end']) for x in big) - T(big[0]['start'])) / 60:.1f} min, starts spread in it {(T(big[-1]['start']) - T(big[0]['start'])) / 60:.1f} min, "
          f"$ {sum(x['usd'] for x in r):.1f} = {sum(x['usd'] for x in r) / STO[s]:.2f}/planned story")

# 4. longest asks and spawns in s322
print("\n== s322 longest AskUserQuestion waits (min), from ask_split")
asks = []
for l in open(ASK):
    f = l.rstrip("\n").split("\t")
    if len(f) > 13 and f[0] == "s322" and f[2].replace(".", "").isdigit(): asks.append((float(f[2]), f[1][:16], f[4], f[12]))
for a in sorted(asks, reverse=True)[:6]: print("  ", a)
print("   asks:", len(asks), "over 60 min:", sum(a[0] > 60 for a in asks))
print("\n== s322 longest subagent first-to-last spans (min; includes resume idle), role, step, description")
for x in sorted([x for x in sp if x["sprint"] == 322], key=lambda x: -x["minutes"])[:8]:
    print(f"   {x['minutes']:6.1f} {x['role']:18} {x['step'][:30]:30} {(x['description'] or '')[:50]}  ${x['usd']:.1f}")

# 5. controls
units = [json.loads(l) for l in open(OUT + "/units.jsonl")]; segs = [json.loads(l) for l in open(OUT + "/segs.jsonl")]
tk = lambda rs: sum(sum(d[:4]) for r in rs for d in (r.get("tok") or {}).values())
print("\n== controls")
print(f"(c1) segment tokens {tk(segs)} vs per-transcript (units) tokens {tk(units)}: {'EQUAL' if tk(segs) == tk(units) else 'DIFF'}")
nsub = sum(1 for u in units if u["kind"] == "sub" and u["sprint"] is not None)
print(f"(c2) subagents joined to a parent step: {sum(1 for x in sp if x['step'] != 'unjoined')} of {nsub} (spawns rows {len(sp)})")
mx = max(max(u["last"] for u in units), max(s["last"] for s in segs), max(x["end"] for x in sp))
print(f"(b1) max timestamp in units/segs/spawns {mx}; pin {PIN}; fields past pin {sum(1 for u in units if T(u['last']) > T(PIN))}+{sum(1 for s in segs if T(s['last']) > T(PIN))}+{sum(1 for x in sp if T(x['end']) > T(PIN))}")
c = collections.Counter()
for p in glob.glob(ROOT + "/*.jsonl") + glob.glob(ROOT + "/*/subagents/*.jsonl"):
    kind = "sub" if "/subagents/" in p else "lead"
    for l in open(p, errors="replace"):
        try: t = json.loads(l).get("timestamp")
        except Exception: continue
        if t and T(t) > T(PIN): c[(kind, "pin..edge" if T(t) <= T(EDGE) else "after edge")] += 1
print("(b2) records in the corpus past the pin (top-level timestamp):", dict(c))
