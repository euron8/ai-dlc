"""BL-543: count a serial remediator's fixed-string sweeps and worklist runs, executed calls only. b261.
usage: SPRINTS=323 python3 -I count_serial_sweeps.py OUT CSV     (SPRINTS=319,322 for the same selection on the comparison sprints)
OUT = extract.py + spawns.py output. For every s323 planning-step spawn that is a serial/adjudicator/lane/fan-in
remediator (role remediator, description matches SERIALRE), reads <~/.claude/projects/-Users-n8-git-graph>/<lead>*/subagents/agent-<id>.jsonl.
A call is EXECUTED when its tool_use id pairs with a tool_result that is not is_error (a denied call counts nothing).
sweep  = Bash or ctx_execute call whose text carries `grep` with an F flag and an r/R/n flag (b257's key).
worklist = executed call whose text names serial-remediation-worklist.sh.
Controls (same invocation): s319 requirements elicitation repair agent-a4b9c05a506fc183b (BL-543 b257 control, 129 sweeps by
the first key, 32 by the second) and the impossible token QXJ-ABSENT-b261-zz9 (must be 0)."""
import csv, json, os, re, sys, glob
OUT, CSV = sys.argv[1:3]
R = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
SERIALRE = re.compile(r"serial|adjudicat|lane|fan-?in|cross-section|cross-part", re.I)
PLANS = {"carry-over-evaluation", "requirements", "architecture", "stories-test-strategy"}
def sweep_call(t):
    """True when some grep in the call text carries F (or --fixed-strings) and one of r R n (or --recursive/--line-number)."""
    for m in re.finditer(r"grep((?:\s+-{1,2}[A-Za-z][A-Za-z-]*)+)", t):
        fl = m.group(1).split()
        short = "".join(x[1:] for x in fl if not x.startswith("--"))
        longs = [x for x in fl if x.startswith("--")]
        f = "F" in short or "--fixed-strings" in longs
        rn = any(c in short for c in "rRn") or "--recursive" in longs or "--line-number" in longs
        if f and rn: return True
    return False
def read(path):
    uses, errs, resu, tot = {}, set(), set(), 0
    for ln in open(path):
        try: d = json.loads(ln)
        except Exception: continue
        c = (d.get("message") or {}).get("content")
        if not isinstance(c, list): continue
        for b in c:
            if b.get("type") == "tool_use": uses[b["id"]] = (b.get("name"), json.dumps(b.get("input")))
            elif b.get("type") == "tool_result":
                resu.add(b.get("tool_use_id"))
                if b.get("is_error"): errs.add(b.get("tool_use_id"))
    ex = [i for i in uses if i in resu and i not in errs]
    s = w = imp = 0
    for i in ex:
        n, t = uses[i]
        if n in ("Bash", "ctx_execute", "mcp__plugin_context-mode_context-mode__ctx_execute"):
            if sweep_call(t): s += 1
            if "serial-remediation-worklist.sh" in t: w += 1
            if "QXJ-ABSENT-b261-zz9" in t: imp += 1
    return len(uses), len(ex), s, w, imp
def find(aid):
    g = glob.glob(f"{R}/*/subagents/agent-{aid}.jsonl")
    return g[0] if g else None
sp = [json.loads(l) for l in open(OUT + "/spawns.jsonl")]
SPR = [int(v) for v in os.environ.get("SPRINTS", "323").split(",")]
sel = [x for x in sp if x["sprint"] in SPR and x["role"] == "remediator" and SERIALRE.search(x["description"])
       and (x["step"][16:-1] if x["step"].startswith("gate-validation[") else x["step"]) in PLANS]
sel.sort(key=lambda x: x["start"])
ctrl = "a4b9c05a506fc183b"
with open(CSV, "w", newline="") as f:
    wr = csv.writer(f); wr.writerow(["agent_id", "lead_session", "step", "description", "tool_calls", "executed", "fixed_string_sweeps", "worklist_runs", "usd_api"])
    tot = [0, 0, 0, 0]; unread = 0
    for x in sel:
        aid = x["unit"].replace("agent-", ""); p = find(aid)
        if not p: unread += 1; wr.writerow([aid, x["sess"], x["step"], x["description"], "UNREADABLE", "", "", "", x["usd"]]); continue
        a, e, s, w, _ = read(p); tot[0] += 1; tot[1] += e; tot[2] += s; tot[3] += w
        wr.writerow([aid, x["sess"], x["step"], x["description"], a, e, s, w, "%.2f" % x["usd"]])
print(f"sprints {SPR} planning serial/adjudicator/lane/fan-in remediator spawns {len(sel)}, readable {tot[0]}, unreadable {unread}; executed calls {tot[1]}, fixed-string sweeps {tot[2]}, worklist runs {tot[3]}")
cp = find(ctrl); a, e, s, w, imp = read(cp)
print(f"CONTROL s319 agent-{ctrl}: calls {a}, executed {e}, sweeps {s}, worklist runs {w} (b257 recorded 129 by the first key / 32 by the second; the key here is the second)")
tp = find("a37305a67843ee413"); a, e, s, w, imp = read(tp)
print(f"CONTROL s323 agent-a37305a67843ee413 (b257 recorded 146 of 150 executed, 4 sweep calls, worklist 1): calls {a}, executed {e}, sweeps {s}, worklist runs {w}; impossible token {imp} (must be 0)")
