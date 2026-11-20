"""Join/merge refusals seen by s323 LEAD sessions: executed Bash calls (tool_use paired with tool_result by id, is_error kept
because a refusal exits non-zero) running join-remediator-shards.sh or merge-adversarial-shards.sh whose result carries
"REFUSED:". Prints per call: time, session, command head, first REFUSED line. s321 is run in the same invocation as control.
usage: python3 -I join_refusals_lead.py   (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
"""
import collections, glob, json, os, re
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
CMD = re.compile(r"join-remediator-shards\.sh|merge-adversarial-shards\.sh")
uses = {}; rows = []
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    for l in open(p, errors="replace"):
        if "join-remediator-shards" not in l and "merge-adversarial-shards" not in l and "REFUSED" not in l: continue
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp") or ""
        if t > WIN_END: continue
        c = (r.get("message") or {}).get("content")
        if not isinstance(c, list): continue
        for x in c:
            if not isinstance(x, dict): continue
            if x.get("type") == "tool_use" and x.get("name") == "Bash":
                cmd = (x.get("input") or {}).get("command", "")
                if CMD.search(cmd) and "--check-part" not in cmd and "--check-shard" not in cmd:
                    uses[x["id"]] = (t, os.path.basename(p)[:8], cmd[:160].replace("\n", " "))
            elif x.get("type") == "tool_result" and x.get("tool_use_id") in uses:
                cc = x.get("content"); cc = cc if isinstance(cc, str) else json.dumps(cc)
                m = re.search(r"REFUSED:[^\n]{0,260}", cc)
                u = uses.pop(x["tool_use_id"])
                if m: rows.append((u, m.group(0)))
def sp(t): return "s321" if "2026-10-30T00:10" <= t < "2026-11-09" else "s323" if t >= "2026-11-13T08" else "other"
cnt = collections.Counter(sp(u[0]) for u, _ in rows)
for u, m in rows:
    if sp(u[0]) in ("s321", "s323"): print(sp(u[0]), u[0], u[1], "|", u[2][:110], "|", m[:230])
print(dict(cnt))
