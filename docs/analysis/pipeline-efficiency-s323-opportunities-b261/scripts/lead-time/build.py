import sys, os
SRC = "/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/wt-c5/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
D = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(D, "x")
src = open(SRC).read()
def sub_once(a, b):
    global src
    assert src.count(a) == 1, (a, src.count(a))
    src = src.replace(a, b)
sub_once("        if K: K.interval(step, tt)\n", "        COLLECT(r, typ, step, tt, t) if K else None\n        if K: K.interval(step, tt)\n")
sub_once("    if K: K.write(unit, sess, usage, segs)\n", "    if K: K.write(unit, sess, usage, segs); FINISH(unit, K)\n")
sub_once("subs = [p for p in glob.glob(ROOT + \"/*/subagents/*.jsonl\") if in_window(p)]", "subs = []")
pre = r'''
EV = []
REC = open(os.path.join(OUT, "rec.jsonl"), "w")
def _sum(c):
    n = c.get("name"); i = c.get("input") or {}
    if not isinstance(i, dict): return str(i)[:300]
    if n == "Bash": return str(i.get("command") or "")[:900]
    if n in ("Read", "Edit", "Write", "MultiEdit", "NotebookEdit"): return str(i.get("file_path") or i.get("notebook_path") or "")[:300] + (" |o%s l%s" % (i.get("offset"), i.get("limit")) if n == "Read" else "")
    if n in ("Grep",): return (str(i.get("pattern") or "")[:120] + " @ " + str(i.get("path") or ""))[:300]
    if n in ("Glob",): return (str(i.get("pattern") or "") + " @ " + str(i.get("path") or ""))[:300]
    if n and "ctx_" in n: return (str(i.get("language") or "") + ": " + str(i.get("code") or i.get("queries") or i.get("file") or i.get("path") or json.dumps(i)))[:500]
    if n in ("Agent", "Task"): return str(i.get("description") or "")[:200] + " |" + str(i.get("subagent_type") or "") + "|plen=" + str(len(str(i.get("prompt") or "")))
    return json.dumps(i)[:300]
def COLLECT(r, typ, step, tt, t):
    e = {"t": t, "f": tt, "ty": typ, "st": step}
    if r.get("isCompactSummary"): e["cs"] = 1
    if typ == "assistant":
        m = r.get("message") or {}
        e["mid"] = m.get("id"); e["model"] = m.get("model"); u = m.get("usage") or {}
        e["u"] = [u.get("input_tokens", 0) or 0, u.get("cache_creation_input_tokens", 0) or 0, u.get("cache_read_input_tokens", 0) or 0, u.get("output_tokens", 0) or 0]
        bl = []
        for c in m.get("content") or []:
            if not isinstance(c, dict): continue
            ct = c.get("type")
            if ct == "tool_use": bl.append(["tu", c.get("name"), c.get("id"), _sum(c)])
            elif ct == "text": bl.append(["tx", len(c.get("text") or "")])
            elif ct == "thinking": bl.append(["th", len(c.get("thinking") or ""), len(c.get("signature") or "")])
            else: bl.append([str(ct)])
        e["b"] = bl
    elif typ == "user":
        c = (r.get("message") or {}).get("content")
        res = []; txt = None; sz = 0
        if isinstance(c, list):
            for x in c:
                if not isinstance(x, dict): continue
                if x.get("type") == "tool_result":
                    b = rbytes(x.get("content")); sz += b
                    cc = x.get("content")
                    if isinstance(cc, list): cc = " ".join((y.get("text") or "") for y in cc if isinstance(y, dict))
                    res.append([x.get("tool_use_id"), b, 1 if x.get("is_error") else 0, str(cc or "")[:90]])
                elif x.get("type") == "text":
                    txt = (txt or "") + (x.get("text") or "");
            if txt is not None: sz += len(txt.encode())
        elif isinstance(c, str):
            txt = c; sz = len(c.encode())
        if res: e["res"] = res
        if txt is not None: e["tx"] = txt[:100]
        e["sz"] = sz
        if r.get("isMeta"): e["meta"] = 1
        if human_prompt(r): e["hum"] = 1
    elif typ == "system":
        e["sub"] = r.get("subtype")
        if r.get("subtype") == "compact_boundary": e["cm"] = r.get("compactMetadata") and {k: v for k, v in r["compactMetadata"].items() if k in ("trigger", "preTokens", "postTokens", "durationMs", "cumulativeDroppedTokens")}
        if r.get("subtype") == "turn_duration": e["dur"] = r.get("durationMs")
    elif typ == "attachment":
        a = r.get("attachment", {}); e["at"] = a.get("type");
        try: e["sz"] = len(json.dumps(a))
        except Exception: e["sz"] = 0
        if a.get("type", "").startswith("hook_"):
            cmd = a.get("command") or a.get("hookName")
            e["hk"] = os.path.basename(str(cmd).split()[-1].strip('"')) if a.get("command") else a.get("hookName")
            e["hev"] = a.get("hookEvent"); e["ms"] = a.get("durationMs")
            cc = a.get("content"); e["hb"] = len((cc if isinstance(cc, str) else json.dumps(cc or "")).encode())
            e["hh"] = str(cc if isinstance(cc, str) else json.dumps(cc or ""))[:100]
    elif typ == "queue-operation":
        e["op"] = r.get("operation"); e["tx"] = str(r.get("content") or "")[:100]
    elif typ == "api-request":
        e["qs"] = r.get("querySource")
    EV.append(e)
def FINISH(unit, K):
    global EV
    for e in EV:
        e["u0"] = unit
        e["s"] = sprint_of(e["t"])
        if e["ty"] == "assistant" and e.get("mid"): e["cls"] = K.cls(("mid", e["mid"]))
        for x in e.get("res") or []:
            m = K.tu_mid.get(x[0]); x.append(K.cls(("mid", m)) if m else None); x.append(m)
        REC.write(json.dumps(e) + "\n")
    EV = []
'''
sub_once("leads = [p for p in glob.glob(ROOT", pre + "\nleads = [p for p in glob.glob(ROOT")
sys.argv = ["extract", OUT]
os.makedirs(OUT, exist_ok=True)
g = {"__name__": "__main__"}
exec(compile(src, "extract_patched", "exec"), g)
g["REC"].close()
