"""Bytes the lead actually receives from Reads of ai-dlc core files (step files, SKILL.md, rule bodies)."""
import json, glob, os, re, collections, datetime as dt
ROOT = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
cut = dt.datetime(2026, 10, 5, 9, 0).timestamp()
RX = re.compile(r"(skills/ai-dlc[^\"]*?/(?:steps|rule-bodies)/[A-Za-z0-9_.-]+\.md|skills/ai-dlc/SKILL\.md|team-roles/[a-z-]+\.md)")
def rb(c):
    if isinstance(c, str): return len(c.encode())
    if isinstance(c, list): return sum(len((x.get("text") or "").encode()) for x in c if isinstance(x, dict))
    return 0
n = collections.Counter(); b = collections.Counter()
for kind, pat in (("lead", ROOT + "/*.jsonl"), ("sub", ROOT + "/*/subagents/*.jsonl")):
    for p in glob.glob(pat):
        if os.path.getmtime(p) < cut: continue
        pend = {}
        for l in open(p, errors="replace"):
            try: r = json.loads(l)
            except Exception: continue
            t = r.get("timestamp")
            if not t or t < "2026-10-05T14:00:00Z": continue
            sp = 317 if t < "2026-10-12T02:30:00Z" else 318
            if r.get("type") == "assistant":
                for c in r["message"].get("content") or []:
                    if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Read":
                        m = RX.search(c.get("input", {}).get("file_path", ""))
                        if m: pend[c["id"]] = (sp, kind, re.sub(r".*/", "", m.group(1)))
            elif r.get("type") == "user" and isinstance(r.get("message", {}).get("content"), list):
                for x in r["message"]["content"]:
                    if isinstance(x, dict) and x.get("tool_use_id") in pend:
                        k = pend.pop(x["tool_use_id"]); n[k] += 1; b[k] += rb(x.get("content"))
tot = collections.Counter()
for k in sorted(b, key=lambda k: -b[k]):
    tot[(k[0], k[1])] += b[k]
    if b[k] > 150_000: print(*k, n[k], "reads", round(b[k] / 1024), "KB", round(b[k] / n[k] / 1024, 1), "KB/read")
print({f"{k[0]} {k[1]}": f"{v/1024/1024:.1f} MB" for k, v in sorted(tot.items())})
