# ask_split.py -- BL-841 / BL-972: where the lead's AskUserQuestion wait goes, split by what the lanes did.
#
# usage: EXTRACT_WIN_END=<iso> python3 -I ask_split.py [<extract-out-dir>]   (EXTRACT_ROOT overrides the root)
#
# Pairs every lead AskUserQuestion tool_use with its tool_result exactly as operator_asks.py does, and
# assigns the sprint from extract.py's EDGES (read out of its source, as operator_asks.py does). Records
# later than $EXTRACT_WIN_END are ignored everywhere (asks, subagent records, queue records), so a
# committed output reproduces after graph has moved on; unset, the window is open-ended.
# For each ask it reads the SAME lead session's subagent transcripts (<session>/subagents/*.jsonl: first
# and last record timestamp) and puts the wait in one bucket:
#   FINISHED-INSIDE    a subagent that had started before the ask wrote its last record inside the wait
#   NONE-RUNNING       no subagent was active at the ask (last record within 300 s, extract.py's active
#                      rule) and none finished inside it
#   RUNNING-NO-FINISH  something was active at the ask and nothing finished inside it
# "Last record" is not "finished": an agent that finished inside the wait and was RESUMED later has its
# last record after the ask, so FINISHED-INSIDE UNDERCOUNTS. The FIN-NOTE-ELSEWHERE line counts the asks
# in the other two buckets that nonetheless had an agent `finished` notification enqueued inside.
#
# NOTIFICATIONS. A task notification that arrives while the lead's turn is busy is written as a
# `queue-operation` record with operation `enqueue`; when the lead takes it, a `remove` record
# (`absorbed_mid_turn` / `delivered_to_agent`), an `attachment` record or a `user` record carries it.
#   ENQ-INSIDE  notifications ENQUEUED with a timestamp inside the wait, of every kind (agent, background
#               Bash, Monitor); ENQ-AGENT-INSIDE counts only agent notifications (task-id `a...`)
#   RMV-INSIDE  notification `remove` queue records POSITIONED in the file between the ask's tool_use and
#               its tool_result. Queue bookkeeping: no record shows the lead's model receiving them there.
#   DLV-INSIDE  notification-carrying attachment/user records positioned inside: what reaches the model.
#   ACT-INSIDE  lead assistant records positioned inside, every record of the ask's own message.id
#               excluded: the lead acting while its question is open. A lead that HOLDS a question back
#               until its lanes drain produces none, so the figure cannot be moved by deferring an ask.
#               It is POSITIONAL: a harness that returned the tool_result at once and delivered the answer
#               some other way would read 0 here whatever the lead did -- re-check this column's meaning
#               against the harness before reading it on a sprint run under a changed ask mechanism.
#
# With <extract-out-dir> (an extract.py OUT), each ask's step is read from tools.jsonl -- the row of the
# same session with tool AskUserQuestion and the same latency to 0.05 s -- else "-".
#
# CONTROLS, each exits 1 when it does not hold:
#   (p) SELF-PROBE, run before the corpus on a seeded root built under a fresh temp dir: an ask whose window
#       holds an agent enqueue, a notification attachment and an assistant record of ANOTHER message.id
#       reads ENQ 1, ENQ-AGENT 1, DLV 1, ACT 1 and FINISHED-INSIDE; a near-miss whose window holds only more
#       records of the ask's OWN message.id and a Bash notification reads ACT 0, DLV 0, ENQ-AGENT 0.
#   (a) the 2026-10-27T06:57Z ask, BL-841's own motivating case (95 min, 2 finished inside), is exactly
#       one FINISHED-INSIDE row -- catches an UNDER-classifying finish rule;
#   (b) the 2026-11-08T04:34:54Z ask (645 min, "Router PUT", nothing running) is exactly one NONE-RUNNING
#       row -- catches an OVER-classifying one;
#   (e) the 2026-11-08T04:02:44Z ask (4 min, one subagent finished inside) is exactly one FINISHED-INSIDE
#       row -- catches a rule needing more than one finisher, which (a), with 2, cannot see;
#   (f) TAIL-ROWS: the asks active ONLY through the 300 s tail (no subagent record at or after the ask's
#       start, one within 300 s before it) are printed and must number at least one and all read
#       RUNNING-NO-FINISH or FINISHED-INSIDE -- catches a rule that drops the tail;
#   (c) every FINISHED-INSIDE ask has ENQ-AGENT-INSIDE above 0: a lane that finished inside a wait
#       notified the lead, so a FINISHED-INSIDE row with no agent notification is a bucket the rule made up;
#   (d) at least one notification enqueue was seen at all, else ENQ-INSIDE cannot fire;
#   (i) the (a) ask reads 89 +/-1 lane-idle minutes, BL-841's recorded figure (95 waited, 89 idle). The
#       self-probe (p) also seeds two overlapping lanes and one split lane, and must read lane-idle
#       (claim, bucket, first-to-last, tail) = (5, 0, 4, 0) minutes.
# (a), (b), (e) and (i) apply only when the window contains them.
#
# LANE-IDLE (BL-841 claim 1, docs/backlog.md's "lane-idle minutes" definition). lane_idle_min is the ask's
# wait (tool_use to tool_result, the pairing above) minus the part of it covered by the UNION of the same
# lead session's subagent ACTIVE intervals. One subagent's active intervals are its record timestamps
# merged wherever consecutive records are at most TAIL (300 s) apart -- extract.py's active rule. TAIL is
# the MERGE GAP only: nothing is added after an interval's last record. Same session = a transcript under
# the lead transcript's <session>/subagents/; with no tail this gives the same figures as joining every
# session's subagents on every control population, so the narrower join is kept. Per-ask minutes print to
# 0.1; every total sums the SECONDS and rounds once (summing per-ask rounded minutes drifts by several).
# The per-sprint LANE-IDLE line also prints three definitions that are NOT claim 1, so a reader can see the
# definition move the number: (b) the whole wait when the ask is NONE-RUNNING, else 0 (the bucket rule);
# (c) one interval per subagent, first record to last, no 300 s split; tail: (a) with TAIL added to each
# interval's end (the `active` test's tail), which counts up to 300 s of silence after a record as busy.
# DEDUP: an ask whose tool_use id appears in more than one lead file (a session carried into a second file)
# is counted ONCE, its subagent intervals the union of every file's session, so the per-sprint call count
# differs from operator_asks.py's by the DEDUP line's rows.
#
# WHAT THIS CANNOT SAY. Whether a READY action existed undispatched at an ask is not in a transcript, and
# a ready, undispatched lane can sit inside a wait of ANY bucket: the buckets say what was dispatched,
# never what could have been. Lane-idle minutes say a lane was not RUNNING, never that one was ready.
import ast, json, glob, os, sys, tempfile, datetime as dt, collections
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END") or "9999"
# extract.py's literal 300 s gap (its :203, :324, :326); extract.py exposes no constant and cannot be imported
# (it reads sys.argv at import), so the value is restated here. The active test below uses it as a tail; the
# lane-idle intervals use it ONLY as the merge gap.
TAIL = 300
HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")).read()
EDGES = next(ast.literal_eval(n.value) for n in ast.parse(_src).body
             if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", None) == "EDGES")
E = [("2026-10-05T14:00:00Z", None)] + [(e, n) for e, n in EDGES if n >= 317]
def sp(t):
    for e, n in E:
        if t < e: return n
def ts(s): return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
TN = "<task-notification>"
def is_agent_note(content): return "<task-id>a" in content

def session_asks(path, win_end):
    """One lead session -> (list of ask dicts, notification enqueues seen)."""
    sid = os.path.basename(path)[:-6]
    pend = {}; enq = []; asks = []
    for line in open(path, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < E[0][0] or t > win_end: continue
        typ = r.get("type"); m = r.get("message") or {}
        if typ == "queue-operation":
            content = str(r.get("content") or "")
            if TN in content and r.get("operation") == "enqueue":
                enq.append((ts(t), is_agent_note(content), is_agent_note(content) and "finished" in content))
            elif TN in content and r.get("operation") == "remove":
                for k in pend: pend[k]["rmv"] += 1
            continue
        if typ == "attachment" and TN in json.dumps(r.get("attachment")):
            for k in pend: pend[k]["dlv"] += 1
        if typ == "assistant":
            for k in pend:
                if m.get("id") != pend[k]["mid"]: pend[k]["act"] += 1
            for c in m.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "AskUserQuestion":
                    qs = (c.get("input") or {}).get("questions") or [{}]
                    pend[c["id"]] = dict(t=t, hdr=str(qs[0].get("header") or "-").replace("\t", " "),
                                         dlv=0, rmv=0, act=0, mid=m.get("id"))
        elif typ == "user":
            cont = m.get("content")
            done = [x.get("tool_use_id") for x in cont if isinstance(x, dict) and x.get("tool_use_id") in pend] if isinstance(cont, list) else []
            for k in done:
                a = pend.pop(k); a["a0"] = ts(a["t"]); a["a1"] = ts(t); a["id"] = k; asks.append(a)
            if TN in (cont if isinstance(cont, str) else json.dumps(cont)):
                for k in pend: pend[k]["dlv"] += 1
    subs = []; ivs = []
    for sp_ in glob.glob(os.path.join(os.path.dirname(path), sid, "subagents", "*.jsonl")):
        f = l = None; tl = []
        for line in open(sp_, errors="replace"):
            try: t = json.loads(line).get("timestamp")
            except Exception: continue
            if t and t <= win_end: f = f or t; l = t; tl.append(ts(t))
        if f: subs.append((ts(f), ts(l)))
        cur = None
        for x in sorted(tl):
            if cur and x - cur[1] <= TAIL: cur[1] = x
            else:
                if cur: ivs.append(tuple(cur))
                cur = [x, x]
        if cur: ivs.append(tuple(cur))
    out = []
    for a in asks:
        a0, a1 = a["a0"], a["a1"]
        active = sum(1 for f, l in subs if f <= a0 <= l + TAIL)
        tail_only = active > 0 and not any(f <= a0 <= l for f, l in subs)
        fin = [l for f, l in subs if a0 < l < a1 and f < a0]
        b = "FINISHED-INSIDE" if fin else ("NONE-RUNNING" if active == 0 else "RUNNING-NO-FINISH")
        ein = [x for x in enq if a0 < x[0] < a1]
        out.append(dict(sess=sid, t=a["t"], w=a1 - a0, b=b, active=active, tail_only=tail_only, fin=len(fin),
                        enq=len(ein), enqa=sum(1 for x in ein if x[1]), enqfin=sum(1 for x in ein if x[2]),
                        rmv=a["rmv"], dlv=a["dlv"], act=a["act"], hdr=a["hdr"], id=a["id"],
                        a0=a0, a1=a1, ivs=list(ivs), fl=list(subs)))
    return out, len(enq)

def covered(ivs, a0, a1):
    """Seconds of [a0, a1] inside the union of the intervals."""
    u = []
    for s, e in sorted(ivs):
        if u and s <= u[-1][1]: u[-1][1] = max(u[-1][1], e)
        else: u.append([s, e])
    return sum(max(0.0, min(e, a1) - max(s, a0)) for s, e in u)

def lane_idle(r):
    """Sets r['idle'] (claim 1) and the three non-claim definitions, all in seconds."""
    a0, a1 = r["a0"], r["a1"]
    r["idle"] = r["w"] - covered(r["ivs"], a0, a1)
    r["idle_b"] = r["w"] if r["b"] == "NONE-RUNNING" else 0.0
    r["idle_c"] = r["w"] - covered(r["fl"], a0, a1)
    r["idle_t"] = r["w"] - covered([(s, e + TAIL) for s, e in r["ivs"]], a0, a1)

# (p) SELF-PROBE, before the corpus.
def _probe():
    d = tempfile.mkdtemp(prefix="ask_split_probe.")
    J = json.dumps
    def ask(q, mid, t): return J(dict(type="assistant", timestamp=t, message=dict(id=mid, content=[dict(
        type="tool_use", id=q, name="AskUserQuestion", input=dict(questions=[dict(header="P")]))])))
    def ans(q, t): return J(dict(type="user", timestamp=t, message=dict(content=[dict(type="tool_result", tool_use_id=q, content="x")])))
    fire = [ask("q1", "m1", "2026-11-01T00:00:00Z"),
            J(dict(type="queue-operation", operation="enqueue", timestamp="2026-11-01T00:01:00Z",
                   content=TN + "<task-id>aP</task-id> Agent finished")),
            J(dict(type="attachment", timestamp="2026-11-01T00:02:00Z", attachment=dict(type="queued_command", prompt=TN))),
            J(dict(type="assistant", timestamp="2026-11-01T00:03:00Z", message=dict(id="m2", content=[dict(type="text", text="x")]))),
            ans("q1", "2026-11-01T00:10:00Z")]
    near = [ask("q2", "n1", "2026-11-01T00:00:00Z"),
            J(dict(type="assistant", timestamp="2026-11-01T00:00:01Z", message=dict(id="n1", content=[dict(type="text", text="x")]))),
            J(dict(type="queue-operation", operation="enqueue", timestamp="2026-11-01T00:01:00Z",
                   content=TN + "<task-id>bP</task-id> Background command completed")),
            ans("q2", "2026-11-01T00:10:00Z")]
    open(os.path.join(d, "fire.jsonl"), "w").write("\n".join(fire) + "\n")
    open(os.path.join(d, "near.jsonl"), "w").write("\n".join(near) + "\n")
    os.makedirs(os.path.join(d, "fire", "subagents"))
    open(os.path.join(d, "fire", "subagents", "a.jsonl"), "w").write(
        J(dict(timestamp="2026-10-31T23:59:00Z")) + "\n" + J(dict(timestamp="2026-11-01T00:05:00Z")) + "\n")
    # Two lanes that start inside the wait and OVERLAP ([00:01,00:04] and [00:02,00:06]): the union covers 5 min
    # where a per-lane sum covers 7, and lane a's two records 6 min apart are two points under the 300 s merge
    # gap but 23:59-00:05 first-to-last. Lane-idle minutes (claim, bucket, first-to-last, tail) must read
    # (5, 0, 4, 0): a per-lane sum gives 3, a merge gap that never splits gives 4, a tail gives 0.
    for nm, tl in (("b", ("00:01", "00:03", "00:04")), ("c", ("00:02", "00:05", "00:06"))):
        open(os.path.join(d, "fire", "subagents", nm + ".jsonl"), "w").write(
            "".join(J(dict(timestamp=f"2026-11-01T{x}:00Z")) + "\n" for x in tl))
    (f,), _ = session_asks(os.path.join(d, "fire.jsonl"), "9999")
    (n,), _ = session_asks(os.path.join(d, "near.jsonl"), "9999")
    lane_idle(f)
    got = [(f["enq"], f["enqa"], f["dlv"], f["act"], f["b"]), (n["enq"], n["enqa"], n["dlv"], n["act"]),
           tuple(round(f[k] / 60, 6) for k in ("idle", "idle_b", "idle_c", "idle_t"))]
    want = [(1, 1, 1, 1, "FINISHED-INSIDE"), (1, 0, 0, 0), (5.0, 0.0, 4.0, 0.0)]
    if got != want:
        print(f"CONTROL FAIL (p) self-probe: got {got}, want {want}"); sys.exit(1)
    print(f"CONTROL (p) OK: self-probe fired {want[0]} on the seeded ask and {want[1]} on the near-miss;"
          f" lane-idle (claim, bucket, first-to-last, tail) minutes {want[2]}")
_probe()

STEPS = collections.defaultdict(list)
if len(sys.argv) > 1:
    for line in open(os.path.join(sys.argv[1], "tools.jsonl")):
        r = json.loads(line)
        if r.get("tool") == "AskUserQuestion" and r.get("kind") == "lead":
            STEPS[r["sess"]].append((r["lat"], r["step"]))
def step_of(sess, w):
    for lat, st in STEPS.get(sess, []):
        if abs(lat - w) <= 0.05: return st
    return "-"
rows = []
ALLENQ = 0
for p in glob.glob(ROOT + "/*.jsonl"):
    if os.path.getmtime(p) < ts(E[0][0]): continue
    got, ne = session_asks(p, WIN_END)
    ALLENQ += ne
    for r in got:
        r["n"] = sp(r["t"])
        if r["n"] is None: continue
        r["step"] = step_of(r["sess"], r["w"]); rows.append(r)
# DEDUP by tool_use id: keep the copy from the lowest session id, its intervals the union of every copy's.
byid = collections.defaultdict(list)
for r in rows: byid[r["id"]].append(r)
DUPS = []
rows = []
for k, R in byid.items():
    R.sort(key=lambda r: r["sess"]); keep = R[0]
    if len(R) > 1:
        DUPS.append((keep, [r["sess"] for r in R]))
        keep["ivs"] = [iv for r in R for iv in r["ivs"]]; keep["fl"] = [iv for r in R for iv in r["fl"]]
    rows.append(keep)
for r in rows: lane_idle(r)
rows.sort(key=lambda r: (r["t"], r["sess"]))
print("sprint\task_start\twait_min\tlane_idle_min\tbucket\tactive_at_ask\tfinished_inside\tenq_inside\tenq_agent_inside\trmv_inside\tdlv_inside\tact_inside\tstep\theader")
for r in rows:
    print(f"s{r['n']}\t{r['t']}\t{r['w']/60:.0f}\t{r['idle']/60:.1f}\t{r['b']}\t{r['active']}\t{r['fin']}\t{r['enq']}\t{r['enqa']}\t{r['rmv']}\t{r['dlv']}\t{r['act']}\t{r['step']}\t{r['hdr']}")
print()
for keep, ss in DUPS:
    print(f"DEDUP: s{keep['n']} ask {keep['id']} at {keep['t']} ({keep['w']/60:.1f} min) is in {len(ss)} lead files"
          f" ({', '.join(s[:8] for s in ss)}); counted once, so s{keep['n']}'s call count is operator_asks.py's minus {len(ss) - 1}")
if not DUPS: print("DEDUP: no ask id appears in more than one lead file")
def tot(R): return sum(r["w"] for r in R)
for n in sorted({r["n"] for r in rows}):
    R = [r for r in rows if r["n"] == n]; T = tot(R)
    parts = []
    for b in ("FINISHED-INSIDE", "NONE-RUNNING", "RUNNING-NO-FINISH"):
        B = [r for r in R if r["b"] == b]
        parts.append(f"{b} {len(B)} asks {tot(B)/60:.0f} min ({100*tot(B)/T if T else 0:.0f}%)")
    W = [r for r in R if r["enq"]]
    print(f"s{n}: {len(R)} asks, total answer wait {T/3600:.1f}h ({T/60:.0f} min); " + "; ".join(parts)
          + f"; ENQ-INSIDE {sum(r['enq'] for r in R)} ({sum(r['enqa'] for r in R)} agent) over {len(W)} asks;"
          f" ACT-INSIDE on those asks {sum(r['act'] for r in W)}; RMV-INSIDE {sum(r['rmv'] for r in R)};"
          f" DLV-INSIDE {sum(r['dlv'] for r in R)}; ACT-INSIDE {sum(r['act'] for r in R)}")
    def li(k): return sum(r[k] for r in R)
    print(f"s{n}: LANE-IDLE {li('idle')/60:.1f} of {T/60:.1f} min ({100*li('idle')/T if T else 0:.1f}%) over {len(R)} asks,"
          f" covered {(T - li('idle'))/3600:.2f} h; not claim 1, for comparison: (b) NONE-RUNNING bucket {li('idle_b')/60:.1f},"
          f" (c) first-to-last {li('idle_c')/60:.1f}, tail +{TAIL} s {li('idle_t')/60:.1f}")
    for b in ("FINISHED-INSIDE", "NONE-RUNNING"):
        fs = collections.Counter()
        for r in R:
            if r["b"] == b: fs[r["step"]] += r["w"]
        if fs: print(f"s{n}: {b} minutes by step: " + ", ".join(f"{k} {v/60:.0f}" for k, v in fs.most_common()))
E2 = [r for r in rows if r["b"] != "FINISHED-INSIDE" and r["enqfin"]]
print(f"all: {len(rows)} asks; ENQ-INSIDE {sum(r['enq'] for r in rows)} notifications ({sum(r['enqa'] for r in rows)} agent)"
      f" over {sum(1 for r in rows if r['enq'])} asks; RMV-INSIDE {sum(r['rmv'] for r in rows)};"
      f" DLV-INSIDE {sum(r['dlv'] for r in rows)}; ACT-INSIDE {sum(r['act'] for r in rows)}; notification enqueues seen {ALLENQ}")
print(f"FIN-NOTE-ELSEWHERE: {len(E2)} asks outside FINISHED-INSIDE carry an enqueued agent 'finished' notification inside "
      f"({tot(E2)/60:.0f} min) -- the undercount from resumed agents")
TR = [r for r in rows if r["tail_only"]]
print(f"TAIL-ROWS: {len(TR)} asks active only through the {TAIL} s tail: " + ", ".join(f"{r['t']} {r['b']}" for r in TR))
fail = []
if ALLENQ == 0: fail.append("(d) no notification enqueue seen at all; ENQ-INSIDE cannot fire")
c = [r for r in rows if r["b"] == "FINISHED-INSIDE" and r["enqa"] == 0]
if c: fail.append(f"(c) FINISHED-INSIDE rows with no agent notification enqueued inside: {[r['t'] for r in c]}")
if not TR or any(r["b"] == "NONE-RUNNING" for r in TR):
    fail.append(f"(f) tail rows must be at least one and none NONE-RUNNING, got {[(r['t'], r['b']) for r in TR]}")
for pre, want, tag in (("2026-10-27T06:57", "FINISHED-INSIDE", "(a)"), ("2026-11-08T04:34:54", "NONE-RUNNING", "(b)"),
                       ("2026-11-08T04:02:44", "FINISHED-INSIDE", "(e)")):
    if pre > WIN_END: continue
    k = [r for r in rows if r["t"].startswith(pre)]
    if len(k) != 1 or k[0]["b"] != want:
        fail.append(f"{tag} the {pre} ask must be exactly one {want} row, got {[(r['t'], r['b']) for r in k]}")
    else:
        print(f"CONTROL {tag} OK: {k[0]['t']} is {want} ({k[0]['w']/60:.0f} min, {k[0]['fin']} finished inside, {k[0]['enqa']} agent notifications enqueued inside)")
# (i) the same 06:57Z ask is BL-841's lane-idle known row: 95 min waited, 89 idle (+/-1 for minute rounding).
k = [r for r in rows if r["t"].startswith("2026-10-27T06:57")]
if "2026-10-27T06:57" <= WIN_END:
    if len(k) != 1 or not 88 <= k[0]["idle"] / 60 <= 90:
        fail.append(f"(i) the 2026-10-27T06:57 ask must read 89 +/-1 lane-idle min, got {[(r['t'], round(r['idle']/60, 2)) for r in k]}")
    else:
        r = k[0]
        print(f"CONTROL (i) OK: {r['t']} lane-idle {r['idle']/60:.2f} of {r['w']/60:.2f} min (BL-841 records 89 of 95);"
              f" (b) bucket {r['idle_b']/60:.2f}, (c) first-to-last {r['idle_c']/60:.2f}, tail {r['idle_t']/60:.2f}")
if fail:
    for f in fail: print("CONTROL FAIL " + f)
    sys.exit(1)
print(f"CONTROL (f) OK: {len(TR)} tail rows, none NONE-RUNNING; CONTROL (c) OK: every FINISHED-INSIDE ask has an agent notification enqueued inside; CONTROL (d) OK")
