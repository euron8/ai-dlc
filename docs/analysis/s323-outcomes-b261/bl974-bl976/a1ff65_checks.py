"""Bash calls of one subagent transcript that run --check-part or --mark, paired with their results (exit/refusal text).

usage: python3 -I a1ff65_checks.py TRANSCRIPT [PATTERN]   (PATTERN default: check-part|--mark|wait-for-deliverable)
Pairs each Bash tool_use with its tool_result by id; prints time, command head and result head.
"""
import json, re, sys
p = sys.argv[1]; pat = re.compile(sys.argv[2] if len(sys.argv) > 2 else r"check-part|--mark|wait-for-deliverable")
uses = {}; n = 0
for l in open(p, errors="replace"):
    try: r = json.loads(l)
    except Exception: continue
    c = (r.get("message") or {}).get("content")
    if not isinstance(c, list): continue
    for x in c:
        if not isinstance(x, dict): continue
        if x.get("type") == "tool_use" and x.get("name") == "Bash" and pat.search((x.get("input") or {}).get("command", "")):
            uses[x["id"]] = (r.get("timestamp"), x["input"]["command"][:240].replace("\n", " "))
        elif x.get("type") == "tool_result" and x.get("tool_use_id") in uses:
            cc = x.get("content"); cc = cc if isinstance(cc, str) else json.dumps(cc)
            t, cmd = uses.pop(x["tool_use_id"]); n += 1
            print(f"{t} err={bool(x.get('is_error'))}\n  CMD {cmd}\n  RES {cc[:400].replace(chr(10), ' ')}")
print("paired calls:", n, "unpaired:", len(uses))
