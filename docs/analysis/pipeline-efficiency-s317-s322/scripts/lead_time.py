"""Where the lead's ACTIVE wall clock goes: model generation against tool execution, per sprint.

Walks every lead transcript in record order. Each inter-record interval of <= 300 s (the same
"active" bound extract.py uses) is charged by the record that CLOSES it:
  model          the closing record is an assistant record, OR the previous record is the harness's
                 api-request record: the lead was waiting on its own model. (The first record
                 written when a response arrives is often an attachment, not the assistant record;
                 without the api-request rule that generation time reads as harness time.)
  tool:<family>  the closing record is a tool_result: the lead was blocked on that tool call
                 (Bash is split by the bash_by_sprint.py command family; other tools by name)
  wake           the closing record is a user record that is not a tool_result (a task
                 notification, a hook prompt, a human prompt)
  idle-wait      the PREVIOUS record is the harness's end-of-turn marker (system/turn_duration): the
                 lead's turn had ended and it sat idle until something woke it. Under 300 s this is
                 inside extract.py's "active" column, but it is time spent waiting on subagents.
  harness:<type> any other non-assistant, non-user record (queue-operation, attachment, ...)
Also prints, per sprint: assistant API calls (unique message.id), output tokens, and the mean
model seconds per call, so "fewer lead calls" can be priced in hours.

usage: python3 -I lead_time.py [TOP]     (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
"""
import ast, collections, datetime as dt, glob, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
EX = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
EDGES = next(ast.literal_eval(n.value) for n in ast.parse(open(EX).read()).body
             if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", None) == "EDGES")
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_START = "2026-10-05T14:00:00Z"
WIN_END = os.environ.get("EXTRACT_WIN_END") or "2099"
TOP = int(sys.argv[1]) if len(sys.argv) > 1 else 14
FAM = re.compile(r"(?:pytest|npm (?:run )?\w+|npx \w+|[\w.-]+\.sh|git (?:push|fetch|merge|pull|rebase|commit|log|diff|status|worktree)|cargo \w+|python3? -m \w+|sleep|until|while)")

def sprint_of(t):
    for e, n in EDGES:
        if t < e: return n
def T(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()

sec = collections.defaultdict(collections.Counter); cnt = collections.defaultdict(collections.Counter)
mids = collections.defaultdict(set); outtok = collections.Counter(); files = 0; ends = collections.Counter()
for p in glob.glob(ROOT + "/*.jsonl"):
    files += 1; last = None; names = {}; seen_out = {}; prev_end = False; prev_api = False
    for l in open(p, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < WIN_START or t > WIN_END or r.get("isSidechain"): continue
        s = sprint_of(t); now = T(t); typ = r.get("type"); key = "harness:" + str(typ)
        msg = r.get("message") if isinstance(r.get("message"), dict) else {}
        if typ == "assistant":
            key = "model"
            mid = msg.get("id")
            if mid:
                mids[s].add(mid); seen_out[mid] = (s, (msg.get("usage") or {}).get("output_tokens", 0))
            for c in msg.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    n = c.get("name") or "?"
                    if n == "Bash":
                        cmd = (c.get("input") or {}).get("command", "") or ""
                        m = FAM.findall(cmd)
                        n = "Bash:" + re.sub(r"^.*/", "", m[0] if m else (cmd.split()[0] if cmd.split() else "?"))
                    names[c.get("id")] = n
        elif typ == "user":
            c = msg.get("content"); key = "wake"
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_result":
                        key = "tool:" + names.get(x.get("tool_use_id"), "?"); break
        if prev_api and not key.startswith("tool:"): key = "model"
        if prev_end: key = "idle-wait"
        if last is not None and 0 <= now - last <= 300:
            sec[s][key] += now - last; cnt[s][key] += 1
        last = now; prev_api = (typ == "api-request"); prev_end = (typ == "system" and r.get("subtype") == "turn_duration"); ends[s] += prev_end
    for mid, (s, o) in seen_out.items(): outtok[s] += o
print(f"root {ROOT}; lead transcripts {files}; window {WIN_START} .. {WIN_END}")
for s in sorted(k for k in sec if k):
    tot = sum(sec[s].values()); model = sec[s]["model"]; tools = sum(v for k, v in sec[s].items() if k.startswith("tool:"))
    calls = len(mids[s])
    print(f"s{s}: active {tot/3600:.1f} h = model {model/3600:.1f} h ({100*model/tot:.0f}%) + tool {tools/3600:.1f} h ({100*tools/tot:.0f}%) "
          f"+ idle-wait {sec[s]['idle-wait']/3600:.1f} h ({100*sec[s]['idle-wait']/tot:.0f}%, {ends[s]} turn ends) + wake {sec[s]['wake']/3600:.1f} h "
          f"+ harness {sum(v for k, v in sec[s].items() if k.startswith('harness:'))/3600:.1f} h | API calls {calls}, output {outtok[s]/1e6:.1f}M tok, "
          f"model s/call {model/max(1,calls):.1f}, output tok/call {outtok[s]/max(1,calls):.0f}")
    for k, v in sec[s].most_common(TOP):
        print(f"   {k[:46]:46} {cnt[s][k]:6d} intervals {v/3600:6.2f} h {v/max(1,cnt[s][k]):6.1f} s each")
