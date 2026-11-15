"""BL-912 in-flight-row hook gap, its close by the BL-819 deliverable-line deny, and the snapshot-update.sh remainder.

Usage: python3 -I bl912_hookgap.py <lead-transcript-dir> <graph-clone>
  <lead-transcript-dir>  a scratch COPY of graph's lead transcripts (the *.jsonl at the root of graph's Claude
                         project directory). Only the *.jsonl directly inside it are read.
  <graph-clone>          a scratch file:// clone of graph; read with `git log --all` and `git show` only.
No default path: the script reads nothing it is not given.

Population, every figure: the given *.jsonl, records with isSidechain false, tool_use blocks of assistant records
deduped by tool_use id per transcript, is_error read from the matching tool_result. Windows by record timestamp:
  s322      2026-11-09T00:00:00Z .. 2026-11-12T12:32:58Z (BL-912's s322-complete window)
  pre-cut   2026-11-09T00:00:00Z .. 2026-11-12T07:39:59Z
  post-cut  2026-11-12T07:40:00Z .. end
The cut is graph commit e0ebaf019 (2026-11-12T02:39:38-05:00 = 07:39:38Z), the first graph commit whose
.claude/hooks/ai-dlc-dispatch-guard.sh carries "THE DELIVERABLE-LINE DENY" (core 0.1052.0, 643447869).

Rules:
  - A hook refusal: the text `in-flight row NOT written for dispatch <agentId> <toolu_id>. ... Why: the brief
    carries no` in a record; counted once per toolu_id.
  - A guard deny: a tool_result carrying "carries no `Deliverable: <path>` line, so ai-dlc-inflight-row.sh".
  - A snapshot-update call: a Bash tool_use whose command contains snapshot-update.sh. Adjacent: the previous lead
    tool_use in the same transcript is also one. A --help call: `snapshot-update.sh --help` or `-h`.
  - Lead truth cell: the deliverable cell (third) of the first lead `--row-add` / `--row-replace` naming the agentId.
  - Grammar (a): `deliverable:` anywhere in a line, case-insensitive, then the hook's own path-token rule.
    Grammar (b): the prompt's first `<path>.brief` token, read from the clone at the last commit touching it, then
    (a) on that file. A fan group is the toolu_id less its last `_<n>`.
Controls printed in the same run: the impossible token toolu_QZX9impossible (must read 0); the latest record read.
"""
import json, os, re, subprocess, sys, collections as C

if len(sys.argv) != 3:
    sys.exit("usage: bl912_hookgap.py <lead-transcript-dir> <graph-clone>")
TX, G = sys.argv[1], sys.argv[2]
S322 = ("2026-11-09T00:00:00Z", "2026-11-12T12:32:58Z")
PRE = ("2026-11-09T00:00:00Z", "2026-11-12T07:39:59Z")
POST = ("2026-11-12T07:40:00Z", "9999")
NOTW = re.compile(r"in-flight row NOT written for dispatch ([A-Za-z0-9_@.-]+) (toolu_[A-Za-z0-9_]+)\. .{0,200}?Why: the brief carries no")
DENY = "carries no `Deliverable: <path>` line, so ai-dlc-inflight-row.sh"
ROWCMD = re.compile(r"--row-(?:add|replace)\s+(?:[A-Za-z0-9_]+\s+)?'([^']*)'")
HELP = re.compile(r"snapshot-update\.sh\s+(--help|-h)\b")
CTRL = "toolu_QZX9impossible"


def inw(t, w): return w[0] <= t <= w[1]


files = sorted(f for f in os.listdir(TX) if f.endswith(".jsonl"))
if not files:
    sys.exit("no *.jsonl in " + TX)
refused = {}            # toolu -> (agentId, ts)
deny = set()            # toolu ids
prompts = {}            # toolu -> prompt
truth = {}              # agentId -> deliverable cell
calls = []              # per transcript: [(ts, name, id, cmd)]
results = {}
ctl = 0; maxt = ""
for f in files:
    seen = set(); seq = []
    for l in open(os.path.join(TX, f), errors="replace"):
        if CTRL in l: ctl += 1
        try: d = json.loads(l)
        except Exception: continue
        if d.get("isSidechain"): continue
        t = d.get("timestamp") or ""
        if not t: continue
        maxt = max(maxt, t)
        for m in NOTW.finditer(l.replace("\\n", " ")):
            refused.setdefault(m.group(2), (m.group(1), t))
        c = (d.get("message") or {}).get("content")
        if not isinstance(c, list): continue
        for b in c:
            if not isinstance(b, dict): continue
            if b.get("type") == "tool_result":
                results[b.get("tool_use_id")] = bool(b.get("is_error"))
                if DENY in json.dumps(b.get("content"), ensure_ascii=False):
                    deny.add((b.get("tool_use_id"), t))
            if d.get("type") != "assistant" or b.get("type") != "tool_use" or b.get("id") in seen: continue
            seen.add(b.get("id"))
            inp = b.get("input") or {}
            name = b.get("name"); cmd = str(inp.get("command", "")) if name == "Bash" else ""
            if name in ("Agent", "Task"): prompts.setdefault(b.get("id"), inp.get("prompt", ""))
            if "snapshot-update.sh" in cmd:
                for m in ROWCMD.finditer(cmd):
                    cells = [x.strip() for x in m.group(1).split("|")]
                    if len(cells) >= 5: truth.setdefault(cells[0].split()[0], cells[2].strip("`"))
            seq.append((t, name, b.get("id"), cmd))
    calls.append(seq)

print("lead transcripts", len(files), "| latest record", maxt, "| control", CTRL, ctl)


def window(w, label):
    ag = su = ra = ra_after = 0
    for seq in calls:
        prev = None
        for t, name, i, cmd in seq:
            if inw(t, w):
                if name in ("Agent", "Task"): ag += 1
                if "snapshot-update.sh" in cmd:
                    su += 1
                    if "--row-add" in cmd:
                        ra += 1
                        if prev in ("Agent", "Task"): ra_after += 1
            prev = name
    nr = sum(1 for a, t in refused.values() if inw(t, w))
    nd = sum(1 for i, t in deny if inw(t, w))
    print(f"{label} {w[0]}..{w[1]}: lead Agent calls {ag}, hook refusals (distinct dispatch) {nr}, guard deliverable denies {nd}, snapshot-update calls {su}, --row-add {ra}, --row-add right after an Agent call {ra_after}")


window(PRE, "pre-cut")
window(POST, "post-cut")

# s322 remainder: adjacent snapshot-update calls and --help calls
tot = adj = 0; hk = C.Counter()
for seq in calls:
    prev_su = False; last_rc = None
    for t, name, i, cmd in seq:
        is_su = "snapshot-update.sh" in cmd
        if inw(t, S322) and is_su:
            tot += 1
            if prev_su: adj += 1
            if HELP.search(cmd):
                hk["no earlier call" if last_rc is None else ("after rc!=0" if last_rc else "after rc 0")] += 1
        if is_su and not HELP.search(cmd): last_rc = results.get(i, False)
        prev_su = is_su
print(f"s322 snapshot-update calls {tot}, directly after another snapshot-update call {adj}, --help {sum(hk.values())} {dict(hk)}")


# grammar replay on the s322 hook refusals
def tok(rest):
    for t in re.split(r"[ \t]+", rest):
        t = t.replace("`", ""); t = re.sub(r"^[(]+", "", t); t = re.sub(r"[.,;:)]+$", "", t)
        if not t or "|" in t: continue
        if "/" in t or re.search(r"\.[A-Za-z0-9]+$", t): return t
    return ""


DL_ANY = re.compile(r"(?i)(?<![A-Za-z])deliverable\**:\**")


def g_any(p):
    for ln in p.splitlines():
        m = DL_ANY.search(ln)
        if m: return tok(ln[m.end():])
    return ""


def norm(x): return re.sub(r"^/Users/n8/git/graph/", "", x.strip().strip("`"))


def same(a, b): a, b = norm(a), norm(b); return a == b or a.endswith(b) or b.endswith(a)


def show(p):
    p = re.sub(r"^/Users/n8/git/graph[^/]*/", "", p.strip("`").rstrip(".,;:)"))
    h = subprocess.run(["git", "-C", G, "log", "--all", "-1", "--format=%H", "--", p], capture_output=True, text=True).stdout.strip()
    if not h: return None
    r = subprocess.run(["git", "-C", G, "show", f"{h}:{p}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


BR = re.compile(r"(\S+\.brief)\b")
res = C.Counter(); groups = C.defaultdict(lambda: ([], []))
s322_ref = {k: v for k, v in refused.items() if inw(v[1], S322)}
for tui, (ag, t) in s322_ref.items():
    if tui not in prompts: res["no prompt"] += 1; continue
    p = prompts[tui]; gt = truth.get(ag)
    v = g_any(p); how = "a"
    if not v:
        m = BR.search(p)
        if not m: res["unresolved: no .brief reference"] += 1; continue
        body = show(m.group(1))
        if body is None: res["unresolved: .brief not in clone history"] += 1; continue
        v = g_any(body); how = "b"
        if not v: res["unresolved: .brief has no deliverable line"] += 1; continue
    if gt is None: res[f"({how}) resolved, no lead row"] += 1; continue
    res[f"({how}) {'agree' if same(v, gt) else 'DISAGREE'}"] += 1
    if how == "b":
        g = groups[tui.rsplit("_", 1)[0]]; g[0].append(norm(v)); g[1].append(norm(gt))
print("s322 hook refusals", len(s322_ref), "| with a lead truth row", sum(1 for a, t in s322_ref.values() if a in truth))
for k, v in sorted(res.items()): print(" ", v, k)
fan = {k: g for k, g in groups.items() if len(g[0]) > 1}
diff = [k for k, g in fan.items() if sorted(g[0]) != sorted(g[1])]
dis_in_fan = sum(1 for g in fan.values() for a, b in zip(*g) if not same(a, b))
print(f"(b) fan groups {len(fan)}, groups whose brief deliverable set differs from the lead's set {len(diff)}, (b) disagreements inside fan groups {dis_in_fan}")
