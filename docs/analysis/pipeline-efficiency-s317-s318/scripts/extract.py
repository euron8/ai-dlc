"""Stream graph transcripts for sprints 317-318 and emit per-unit records.

Outputs (scratchpad/out/):
  units.jsonl   one row per transcript (lead session or subagent) with totals
  segs.jsonl    one row per (lead session, step segment)
  hooks.jsonl   hook firings: session, step, hook, event, durationMs, bytes
  tools.jsonl   tool calls: unit, step, tool, latency_s, result_bytes
"""
import json, os, re, sys, glob, datetime as dt

ROOT = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
OUT = sys.argv[1]
WIN_START = "2026-10-05T14:00:00Z"          # s316 close, 10:00 -0400
S318_START = "2026-10-12T02:30:00Z"         # after the s317 retro segment ends (02:28Z)
os.makedirs(OUT, exist_ok=True)

STEP_RE = re.compile(r"skills/ai-dlc(?:-update)?/steps/([A-Za-z0-9_.-]+)\.md")
SUBPROC = {"_gate-procedures", "_dispatch-protocol"}

def ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()

def sprint_of(t):
    if t < WIN_START: return None
    return 317 if t < S318_START else 318

def human_prompt(r):
    if r.get("type") != "user" or r.get("toolUseResult") is not None or r.get("isMeta"):
        return False
    c = r.get("message", {}).get("content")
    if isinstance(c, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c):
            return False
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
    if not isinstance(c, str): return False
    c = c.lstrip()
    return not (c.startswith("<task-notification") or c.startswith("<system-reminder")
                or c.startswith("<local-command") or c.startswith("Caveat:")
                or c.startswith("<teammate-message") or c.startswith("<cross-session"))

def rbytes(c):
    if isinstance(c, str): return len(c.encode())
    if isinstance(c, list):
        n = 0
        for x in c:
            if isinstance(x, dict):
                n += len((x.get("text") or "").encode()) if x.get("type") == "text" else len(json.dumps(x).encode())
        return n
    return len(json.dumps(c).encode()) if c is not None else 0

owner = {}   # tool_use_id of an Agent/Task call -> (session, step, ts)
fh = {k: open(os.path.join(OUT, k + ".jsonl"), "w") for k in ("units", "segs", "hooks", "tools")}

def scan(path, kind, meta):
    usage = {}           # message.id -> (model, usage, ts, step)
    step = "pre-step"; main = "pre-step"
    segs = {}            # step -> dict
    pend = {}            # tool_use_id -> (name, ts, step)
    first = last = None; prev_t = None; prev_type = None
    sess = os.path.basename(os.path.dirname(os.path.dirname(path))) if kind == "sub" else os.path.basename(path)[:-6]
    unit = os.path.basename(path)[:-6]
    compactions = 0; humans = 0; skills = {}
    def seg(s):
        return segs.setdefault(s, dict(first=None, last=None, active=0.0, op_wait=0.0, agent_wait=0.0,
                                       reads=0, compactions=0, humans=0, tool_bytes=0, hook_bytes=0, lines=0))
    for line in open(path, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < WIN_START: continue
        tt = ts(t)
        first = first or t; last = t
        typ = r.get("type")
        S = seg(step); S["lines"] += 1
        S["first"] = S["first"] or t; S["last"] = t
        if prev_t is not None:
            gap = max(0.0, tt - prev_t)
            if gap <= 300: S["active"] += gap
            elif typ == "user" and human_prompt(r): S["op_wait"] += gap
            else: S["agent_wait"] += gap
        prev_t = tt
        if r.get("isCompactSummary"):
            compactions += 1; S["compactions"] += 1
        if human_prompt(r):
            humans += 1; S["humans"] += 1
        if typ == "assistant":
            m = r.get("message", {})
            a = r.get("attributionSkill")
            if a: skills[a] = skills.get(a, 0) + 1
            if m.get("usage") and m.get("id"):
                usage[m["id"]] = (m.get("model"), m["usage"], t, step)
            for c in m.get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "tool_use": continue
                inp = json.dumps(c.get("input", {}))
                pend[c["id"]] = (c.get("name"), tt, step)
                if c.get("name") in ("Agent", "Task"):
                    owner[c["id"]] = (sess, step, t)
                mm = STEP_RE.search(inp)
                if mm and c.get("name") == "Read":
                    name = mm.group(1)
                    S["reads"] += 1
                    if name not in SUBPROC:
                        if name == "gate-validation":
                            step = "gate-validation[" + main + "]"
                        else:
                            main = name; step = name
        elif typ == "user":
            c = r.get("message", {}).get("content")
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_result":
                        p = pend.pop(x.get("tool_use_id"), None)
                        b = rbytes(x.get("content"))
                        S["tool_bytes"] += b
                        if p:
                            fh["tools"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=p[2], tool=p[0],
                                lat=round(tt - p[1], 2), bytes=b, sprint=sprint_of(t))) + "\n")
        elif typ == "attachment":
            a = r.get("attachment", {})
            if a.get("type") in ("hook_success", "hook_additional_context", "hook_non_blocking_error", "hook_blocking_error"):
                b = len((a.get("content") if isinstance(a.get("content"), str) else json.dumps(a.get("content") or "")).encode())
                if a.get("type") == "hook_additional_context": S["hook_bytes"] += b
                cmd = a.get("command") or a.get("hookName")
                fh["hooks"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=step, att=a["type"],
                    hook=os.path.basename(str(cmd).split()[-1].strip('"')) if a.get("command") else a.get("hookName"),
                    event=a.get("hookEvent"), ms=float(a.get("durationMs") or 0), bytes=b, sprint=sprint_of(t))) + "\n")
        prev_type = typ
    if first is None: return
    tok = {}
    for mid, (model, u, t, s) in usage.items():
        k = (s, model)
        d = tok.setdefault(k, [0, 0, 0, 0, 0])
        d[0] += u.get("input_tokens", 0) or 0
        d[1] += u.get("cache_creation_input_tokens", 0) or 0
        d[2] += u.get("cache_read_input_tokens", 0) or 0
        d[3] += u.get("output_tokens", 0) or 0
        d[4] += 1
    for (s, model), d in tok.items():
        S = seg(s); S.setdefault("tok", {})[model or "?"] = d
    fh["units"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, first=first, last=last,
        sprint=sprint_of(first), compactions=compactions, humans=humans, skills=skills, meta=meta,
        tok={f"{s}|{m}": d for (s, m), d in tok.items()})) + "\n")
    for s, S in segs.items():
        if S["first"] is None: continue
        fh["segs"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=s, sprint=sprint_of(S["first"]), **S)) + "\n")

cut = dt.datetime(2026, 10, 5, 9, 0).timestamp()
leads = [p for p in glob.glob(ROOT + "/*.jsonl") if os.path.getmtime(p) >= cut]
subs = [p for p in glob.glob(ROOT + "/*/subagents/*.jsonl") if os.path.getmtime(p) >= cut]
print("leads", len(leads), "subs", len(subs), file=sys.stderr)
for p in sorted(leads): scan(p, "lead", None)
for i, p in enumerate(sorted(subs)):
    mp = p[:-6] + ".meta.json"
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    scan(p, "sub", meta)
    if i % 200 == 0: print("sub", i, file=sys.stderr)
json.dump({k: list(v) for k, v in owner.items()}, open(os.path.join(OUT, "owner.json"), "w"))
for f in fh.values(): f.close()
print("done", file=sys.stderr)
