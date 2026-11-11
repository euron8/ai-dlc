"""Which subagents hold the lead's wall clock, per sprint and step.

Reads spawns.jsonl from an extract.py + spawns.py output dir for each spawn's sprint, step and role,
and the subagent transcripts themselves for its BUSY intervals. A spawn's first-to-last timestamp is
not its run time: a finished agent the lead later resumes with a message sits idle in between (measured:
an 8-minute serial-lane remediator read as 5.7 h). So a subagent's timeline is cut at every gap over
300 s that is closed by a user record carrying no tool_result (a resume message); the idle span is
dropped and reported per sprint as resume-idle. Gaps closed by a model response or a tool result stay
busy. For each (sprint, step):
  busy_h     union of all spawn [start, end] intervals: wall clock during which >=1 subagent ran
  serial_h   sum of spawn durations (what the step would take one at a time)
  width      serial_h / busy_h, the mean parallelism actually achieved
  solo_h     per role: wall clock during which EVERY running spawn had that role. This is the
             role that alone held the step open -- the tail the lead waits on.
  tail1_h    wall clock during which exactly ONE spawn ran (a single agent was the whole frontier)

usage: python3 -I poles.py OUT [sprint,sprint,...]
"""
import collections, datetime as dt, glob, json, os, sys
OUT = sys.argv[1]
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
SPR = {int(x) for x in sys.argv[2].split(",")} if len(sys.argv) > 2 else None
def T(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
PATH = {os.path.basename(p)[:-6]: p for p in glob.glob(ROOT + "/*/subagents/*.jsonl")}
def busy_intervals(path):
    out = []; a = last = None; idle = 0.0
    for l in open(path, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t > WIN_END: continue
        now = T(t)
        if a is None: a = last = now; continue
        if now - last > 300 and r.get("type") == "user":
            c = (r.get("message") or {}).get("content")
            if not (isinstance(c, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c)):
                out.append((a, last)); idle += now - last; a = now
        last = now
    if a is not None and last > a: out.append((a, last))
    return out, idle
by = collections.defaultdict(list); resume_idle = collections.Counter(); missing = 0
for l in open(OUT + "/spawns.jsonl"):
    r = json.loads(l)
    if not r.get("start") or not r.get("end") or (SPR and r["sprint"] not in SPR): continue
    if r["unit"] not in PATH: missing += 1; continue
    iv, idle = busy_intervals(PATH[r["unit"]]); resume_idle[r["sprint"]] += idle
    for a, b in iv:
        if b > a: by[(r["sprint"], r["step"])].append((a, b, r.get("role") or "?", r.get("usd") or 0))
print(f"spawns with no transcript under {ROOT}: {missing}")
tot = collections.defaultdict(collections.Counter)
for (s, st), sp in sorted(by.items()):
    ev = sorted([(a, 1, i) for i, (a, b, ro, u) in enumerate(sp)] + [(b, -1, i) for i, (a, b, ro, u) in enumerate(sp)])
    live = set(); last = None; busy = 0.0; tail1 = 0.0; solo = collections.Counter()
    for t, d, i in ev:
        if last is not None and live:
            dtm = t - last; busy += dtm
            if len(live) == 1: tail1 += dtm
            roles = {sp[j][2] for j in live}
            if len(roles) == 1: solo[next(iter(roles))] += dtm
        if d > 0: live.add(i)
        else: live.discard(i)
        last = t
    serial = sum(b - a for a, b, ro, u in sp)
    tot[s]["busy"] += busy; tot[s]["serial"] += serial; tot[s]["tail1"] += tail1
    for ro, v in solo.items(): tot[s]["solo:" + ro] += v
    top = ", ".join(f"{ro} {v/3600:.1f}" for ro, v in solo.most_common(3))
    print(f"s{s} {st:38} intervals {len(sp):4d} busy {busy/3600:6.1f} h serial {serial/3600:6.1f} h "
          f"width {serial/max(busy,1):4.1f} one-agent {tail1/3600:5.1f} h | solo-role h: {top}")
print()
for s in sorted(tot):
    c = tot[s]; solo = sorted(((k[5:], v) for k, v in c.items() if k.startswith("solo:")), key=lambda x: -x[1])
    print(f"s{s} resume-idle dropped {resume_idle[s]/3600:.1f} h")
    print(f"s{s} TOTAL busy {c['busy']/3600:.1f} h serial {c['serial']/3600:.1f} h one-agent {c['tail1']/3600:.1f} h | solo-role h: "
          + ", ".join(f"{ro} {v/3600:.1f}" for ro, v in solo[:6]))
