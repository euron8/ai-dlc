import json, os, sys, re, collections as C
TX = sys.argv[1]; ags = [l.strip() for l in open(sys.argv[2]) if l.strip()] + ["aQZX9impossible000"]
hits = C.defaultdict(list)
for f in sorted(os.listdir(TX)):
    if not f.endswith(".jsonl"): continue
    for l in open(os.path.join(TX, f), errors="replace"):
        if not any(a in l for a in ags): continue
        try: d = json.loads(l)
        except Exception: continue
        if d.get("isSidechain"): continue
        t = d.get("timestamp", "")
        c = (d.get("message") or {}).get("content")
        if isinstance(c, str): c = [{"type": "text", "text": c}]
        if not isinstance(c, list): continue
        for b in c:
            if not isinstance(b, dict): continue
            s = json.dumps(b, ensure_ascii=False)
            for a in ags:
                if a not in s: continue
                if b.get("type") == "tool_use":
                    inp = b.get("input") or {}
                    kind = b.get("name")
                    cmd = str(inp.get("command", ""))[:0]
                    if kind == "Bash":
                        c2 = inp.get("command", "")
                        kind += ":" + ("row-status" if "--row-status" in c2 else "row-replace" if "--row-replace" in c2 else "row-add" if "--row-add" in c2 else "row-delete" if "--row-delete" in c2 else "wait" if "wait-for-deliverable" in c2 else "other")
                    hits[a].append((t, f[:8], d.get("type"), kind))
                elif b.get("type") == "tool_result":
                    hits[a].append((t, f[:8], "result", ""))
                else:
                    hits[a].append((t, f[:8], d.get("type"), b.get("type")))
tot = C.Counter()
for a in ags:
    k = C.Counter(x[3] for x in hits[a] if x[2] == "assistant")
    tot.update(k)
    print(a, "records", len(hits[a]), dict(k))
print("TOTAL assistant tool kinds", dict(tot))
