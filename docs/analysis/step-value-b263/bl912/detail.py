import json, os, sys, re
TX = sys.argv[1]; ags = [l.strip() for l in open(sys.argv[2]) if l.strip()]
out = []
for f in sorted(os.listdir(TX)):
    if not f.endswith(".jsonl"): continue
    for l in open(os.path.join(TX, f), errors="replace"):
        if not any(a in l for a in ags): continue
        try: d = json.loads(l)
        except Exception: continue
        if d.get("isSidechain") or d.get("type") != "assistant": continue
        for b in (d.get("message") or {}).get("content") or []:
            if not isinstance(b, dict): continue
            s = json.dumps(b, ensure_ascii=False)
            hit = [a for a in ags if a in s]
            if not hit: continue
            if b.get("type") == "tool_use":
                inp = b.get("input") or {}
                if b.get("name") in ("SendMessage", "TaskStop"):
                    out.append((d["timestamp"], f[:8], b["name"], json.dumps(inp)[:600]))
                elif b.get("name") == "Bash" and ("--row-replace" in inp.get("command","") or "wait-for" in inp.get("command","") or "--row-delete" in inp.get("command","")):
                    c = inp["command"]
                    for a in hit:
                        for m in re.finditer(re.escape(a) + r"[^']{0,200}", c):
                            out.append((d["timestamp"], f[:8], "Bash", m.group(0)[:220]))
            elif b.get("type") in ("text", "thinking"):
                txt = b.get("text") or b.get("thinking") or ""
                for a in hit:
                    i = txt.find(a)
                    out.append((d["timestamp"], f[:8], b["type"], txt[max(0,i-250):i+150].replace("\n"," ")))
for r in sorted(out): print(" | ".join(r))
