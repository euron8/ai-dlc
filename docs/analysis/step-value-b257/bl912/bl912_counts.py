"""BL-912 counts on graph's lead transcripts: lead snapshot Edit/Write attempts, `snapshot-update.sh` Bash calls,
and the entry's lead-active-hours heuristic per (sprint, step), each step's snapshot-Edit and snapshot-update.sh
class hours beside its total.

Usage: python3 -I bl912_counts.py [WIN_END]   (WIN_END: argv[1], else $EXTRACT_WIN_END, else unbounded)
Root: $EXTRACT_ROOT, else ~/.claude/projects/-Users-n8-git-graph (read only; the lead transcripts are its *.jsonl).

The rules are the batch-256 reading's own (BL-912 "Reading on s322 (batch b256 ...)"), carried here verbatim so that
the b256 figures re-derive from the tree:
  - Records: every lead transcript (*.jsonl at the root), non-sidechain, timestamped, at or before WIN_END.
  - Sprint of a record by timestamp: s319 from 2026-10-23T09:53:00Z, s320 from that to 2026-10-29T23:20:00Z (the
    filing commit d44b83ca7's s320 edge), s321 to 2026-11-09T00:00:00Z, s322 after.
  - Step: the last whole (or first-slice) Read of a step file under skills/ai-dlc(-update)/steps/, excluding
    _gate-procedures, _dispatch-protocol and gate-validation (so a gate span stays in its main step).
  - Heuristic time: each interval between consecutive records of one transcript, 0 to 300 s inclusive, is charged to
    the sprint of the record opening it, the step current then, and the class of the LAST lead tool_use seen before
    it: snapEdit (Edit/Write/MultiEdit/NotebookEdit whose file_path contains pipeline-snapshot.md, case-folded),
    snapUpd (Bash whose command contains snapshot-update.sh), other.
  - Calls: tool_use blocks deduped by id per transcript; is_error read from the matching tool_result.
The s321 file-tool baseline (435 = 428 Edit + 7 Write) is the 8 s321 lead transcripts named in BL-912, over
assistant records, deduped by tool_use id.

Controls printed in the same invocation: the impossible tokens pipeline-snapshot-QZX9.md and snapshot-update-QZX9.sh
(must read 0), and the latest record read with its transcript (window evidence).
"""
import json, os, re, sys, datetime as dt, collections as C

P = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = (sys.argv[1] if len(sys.argv) > 1 else os.environ.get("EXTRACT_WIN_END")) or None
STEP_RE = re.compile(r"skills/ai-dlc(?:-update)?/steps/([A-Za-z0-9_.-]+)\.md")
SUBPROC = {"_gate-procedures", "_dispatch-protocol"}
EDGES = [("2026-10-23T09:53:00Z", 319), ("2026-10-29T23:20:00Z", 320), ("2026-11-09T00:00:00Z", 321), ("2099", 322)]
EIGHT = ["2c84f6b7", "59a855bd", "d9d2b30c", "38d6a63b", "189712ad", "df04e9cd", "c2d27b66", "98b5c1da"]


def T(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


WIN_END_TS = T(WIN_END) if WIN_END else None


def sprint(t):
    if t < "2026-10-23T09:53:00Z": return None
    for e, n in EDGES:
        if t < e: return n


files = sorted(f for f in os.listdir(P) if f.endswith(".jsonl"))
act = C.defaultdict(float)      # (sprint, step, cls) -> seconds
edits = []                      # (t, file, id, name, step) per sprint-322 snapshot file-tool attempt
results = {}                    # tool_use_id -> is_error
rtext = {}                      # tool_use_id -> head of the tool_result text
su = []                         # (sprint, id, step)
imp_e = imp_s = 0
eight = C.Counter()
maxts = None; maxts_file = None; dropped = 0
for f in files:
    step = "pre-step"; whole = set(); prev = None; prev_t = None; cls = "other"; seen = set()
    for l in open(os.path.join(P, f), errors="replace"):
        try: d = json.loads(l)
        except Exception: continue
        t = d.get("timestamp")
        if not t: continue
        if WIN_END_TS is not None and T(t) > WIN_END_TS:
            dropped += 1; continue
        if maxts is None or t > maxts: maxts, maxts_file = t, f[:8]
        if d.get("isSidechain"): continue
        tt = T(t)
        if prev is not None:
            g = tt - prev
            s = sprint(prev_t)
            if s and 0 <= g <= 300: act[(s, step, cls)] += g
        prev = tt; prev_t = t
        c = (d.get("message") or {}).get("content")
        if not isinstance(c, list): continue
        for b in c:
            if not isinstance(b, dict): continue
            if b.get("type") == "tool_result":
                results[b.get("tool_use_id")] = bool(b.get("is_error"))
                tc = b.get("content")
                rtext[b.get("tool_use_id")] = (tc if isinstance(tc, str) else json.dumps(tc))[:160].replace("\n", " ")
            if b.get("type") != "tool_use" or d.get("type") != "assistant": continue
            if b.get("id") in seen: continue
            seen.add(b.get("id"))
            name = b.get("name"); inp = b.get("input") or {}
            fp = str(inp.get("file_path", "") or inp.get("notebook_path", "")).lower()
            cmd = str(inp.get("command", "")) if name == "Bash" else ""
            if name in ("Edit", "Write", "MultiEdit", "NotebookEdit") and "pipeline-snapshot-qzx9.md" in fp: imp_e += 1
            if name == "Bash" and "snapshot-update-QZX9.sh" in cmd: imp_s += 1
            if name in ("Edit", "Write", "MultiEdit", "NotebookEdit") and "pipeline-snapshot.md" in fp:
                cls = "snapEdit"
                if sprint(t) == 322: edits.append((t, f[:8], b.get("id"), name, step))
                if f[:8] in EIGHT: eight[name] += 1
            elif name == "Bash" and "snapshot-update.sh" in cmd:
                cls = "snapUpd"; su.append((sprint(t), b.get("id"), step))
            else:
                cls = "other"
            if name == "Read":
                mm = STEP_RE.search(json.dumps(inp))
                if mm:
                    nm = mm.group(1); isl = "offset" in inp or "limit" in inp
                    sl = isl and nm in whole
                    if not isl: whole.add(nm)
                    if nm not in SUBPROC and not sl and nm != "gate-validation": step = nm

print("WIN_END", WIN_END, "| latest record read", maxts, "in", maxts_file, "| records dropped after WIN_END", dropped)
print("lead transcripts", len(files))
print("impossible tokens: pipeline-snapshot-QZX9.md", imp_e, "snapshot-update-QZX9.sh", imp_s)
print("s321 eight-transcript snapshot file-tool calls", dict(eight), sum(eight.values()))
print("== s322 snapshot file-tool attempts", len(edits),
      "is_error", dict(C.Counter(results.get(i) for _, _, i, _, _ in edits)),
      "by step", dict(C.Counter(st for *_, st in edits)))
DENY = "PreToolUse:Edit hook error: AI/DLC: pipeline-snapshot.md is written only by"
lab = {i: ("deny" if rtext.get(i, "").startswith(DENY) else "other") for _, _, i, _, _ in edits}
print("s322 attempts by result: deny", sum(v == "deny" for v in lab.values()), "other", sum(v == "other" for v in lab.values()))
for t, f, i, n, st in edits: print("  ", t, f, n, st, "is_error", results.get(i), lab[i])
print("== snapshot-update.sh Bash calls per sprint", dict(sorted(C.Counter(s for s, _, _ in su).items(), key=lambda x: str(x[0]))))
print("s322 is_error split", dict(C.Counter(results.get(i) for s, i, _ in su if s == 322)))
print("snapshot-update.sh calls per (sprint, step):")
for (s, st), n in sorted(C.Counter((s, st) for s, _, st in su).items(), key=lambda x: (str(x[0][0]), x[0][1])):
    if s in (320, 321, 322): print("  ", s, st, n)
print("== active hours by sprint/step (heuristic): total, snapEdit, snapUpd")
tot = C.defaultdict(float)
for (s, st, cl), v in act.items(): tot[(s, st)] += v
for (s, st), v in sorted(tot.items(), key=lambda x: (str(x[0][0]), x[0][1])):
    if v < 360: continue
    print(s, st, "total %.2f" % (v / 3600), "snapEdit %.2f" % (act[(s, st, "snapEdit")] / 3600),
          "snapUpd %.2f" % (act[(s, st, "snapUpd")] / 3600))

# Groups, summed in seconds over every step of the group (no 360 s display floor). "planning" is the b256 reading's
# group: its s320 4.57 h of 19.18 h, s321 4.34 h and s322 3.87 h of 17.31 h are these five steps; bug-investigation
# is printed on its own. STORIES is roll.py's per-sprint story count.
PLAN = ("architecture", "carry-over-evaluation", "requirements", "stories-test-strategy", "ui-direction")
VERDICT4 = ("carry-over-evaluation", "requirements", "architecture", "stories-test-strategy")   # the Verdict: field's group
GROUPS = [("verdict-group-4", VERDICT4), ("planning", PLAN),("planning+bug-investigation", PLAN + ("bug-investigation",)),
          ("implementation", ("implementation",)), ("planning+implementation", PLAN + ("implementation",)),
          ("planning+bug-investigation+implementation", PLAN + ("bug-investigation", "implementation")),
          ("stories-test-strategy", ("stories-test-strategy",)), ("bug-investigation", ("bug-investigation",))]
STORIES = {320: 13, 321: 25, 322: 8}
print("== groups (heuristic h): total, snapEdit, snapUpd, snapEdit+snapUpd, and per story")
for s in (320, 321, 322):
    for g, steps in GROUPS:
        a = sum(tot[(s, x)] for x in steps) / 3600
        e = sum(act[(s, x, "snapEdit")] for x in steps) / 3600
        u = sum(act[(s, x, "snapUpd")] for x in steps) / 3600
        n = STORIES[s]
        print(s, g, "total %.2f snapEdit %.2f snapUpd %.2f snap %.2f | per story (%d) total %.3f snapEdit %.3f snapUpd %.3f snap %.3f"
              % (a, e, u, e + u, n, a / n, e / n, u / n, (e + u) / n))

# Window control: the s323 lead 0ef7ba46 (its first /ai-dlc turn) must open AFTER WIN_END. Read unfiltered.
for f in files:
    if not f.startswith("0ef7ba46"): continue
    first = None
    for l in open(os.path.join(P, f), errors="replace"):
        try: t = json.loads(l).get("timestamp")
        except Exception: continue
        if t: first = t; break
    print("window control: s323 lead", f[:8], "first record", first, "after WIN_END:",
          bool(first and WIN_END_TS is not None and T(first) > WIN_END_TS))
