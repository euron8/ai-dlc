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
#   (q) BL-972 SELF-PROBE on its own seeded files, both directions per counter: HELD fires on a visible agent
#       notice, a killed one, and stays 0 on a race, a Bash notice and a notice already followed by a lead message;
#       DISPATCHED fires on a lane launched in the ask's own response (old active_at_ask 0 there) and stays 0 on a
#       drained lane (old active_at_ask 1 through the tail); a resumed agent runs and an unresumed one does not;
#       ADJ stays 0 on a foreground dispatch and fires on a background one. KNOWN LIMIT, asserted and printed:
#       defer_plus_bg, a lead that drains its lanes and then dispatches a background Agent in the ask's own
#       message, reads ADJ 1 and HELD 0, so ADJ does not exclude it. DRAINED-AT-ASK (reported, never a close
#       guard) reads 1 on that seed, 0 on a compliant dispatch-then-ask seed and 0 on an ask with no lanes.
#   (r) real asks: s319 10-15T10:44:03 DISPATCHED 1 and ADJ 1; s321 10-30T03:20:41 DISPATCHED 0; four s321 race
#       asks HELD 0. (s) exactly one api-anchored ask reads HELD > 0, named. (t) s321 reads 56 deduplicated asks.
# (a), (b), (e) and (i) apply only when the window contains them; (q)-(t) print after every old line.
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
import ast, json, glob, os, re, sys, tempfile, datetime as dt, collections
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
TERMINAL = ("completed", "failed", "killed")
def agent_terminal(s):
    """Agent task notifications in s whose <status> is terminal -> [task-id]. Keyed on the status tag, never on
    the word 'finished' (281 completed and every killed notice in the corpus lack it). Agent = task-id 'a...'."""
    out = []
    for mm in re.finditer(r"<task-id>([^<]*)</task-id>(.*?)</task-notification>", s, re.S):
        st = re.search(r"<status>([^<]*)</status>", mm.group(2))
        if mm.group(1).startswith("a") and st and st.group(1) in TERMINAL: out.append(mm.group(1))
    return out
def bg_flag(v): return v is True or str(v).lower() == "true"

def session_asks(path, win_end):
    """One lead session -> (list of ask dicts, notification enqueues seen)."""
    sid = os.path.basename(path)[:-6]
    pend = {}; enq = []; asks = []
    # BL-972 columns. Every position is (timestamp, file index): file order is not time order (an api-request
    # record can sit before attachments stamped earlier), so time decides and the index breaks ties.
    ENQT = []; NOTE = []; ASST = []; DISP = {}; SM = {}; RES = {}
    first = {}; anchor = {}; fallback = {}; prev_mid = {}
    last_api = last_user = last_mid = None
    i = -1
    for line in open(path, errors="replace"):
        i += 1
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < E[0][0] or t > win_end: continue
        typ = r.get("type"); m = r.get("message") or {}
        pos = (ts(t), i)
        if typ == "api-request": last_api = pos
        if typ == "queue-operation" and r.get("operation") == "enqueue":
            for tid in agent_terminal(str(r.get("content") or "")):
                ENQT.append(pos); NOTE.append((pos, tid, "enqueue"))
        if typ == "attachment":
            for tid in agent_terminal(json.dumps(r.get("attachment"))): NOTE.append((pos, tid, "carrier"))
        if typ == "user":
            last_user = pos
            cont = m.get("content")
            txt = cont if isinstance(cont, str) else "".join(
                str(x.get("text") or "") for x in (cont or []) if isinstance(x, dict) and x.get("type") == "text")
            for tid in agent_terminal(txt): NOTE.append((pos, tid, "carrier"))
            if isinstance(cont, list):
                for x in cont:
                    if isinstance(x, dict) and (x.get("tool_use_id") in DISP or x.get("tool_use_id") in SM):
                        RES[x["tool_use_id"]] = (r.get("toolUseResult"), pos)
        if typ == "assistant":
            mid = m.get("id"); ASST.append((pos, mid))
            if mid not in first:
                # the anchor is the api-request taken since the previous message.id began, so it cannot be stale
                first[mid] = pos; anchor[mid] = last_api; fallback[mid] = last_user; prev_mid[mid] = last_mid
                last_api = None; last_mid = mid
            for c in m.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    if c.get("name") in ("Agent", "Task"):
                        DISP[c["id"]] = (pos, mid, bg_flag((c.get("input") or {}).get("run_in_background")))
                    elif c.get("name") == "SendMessage": SM[c["id"]] = pos
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
                                         dlv=0, rmv=0, act=0, mid=m.get("id"), pos=pos)
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
    # LANES from harness records only: an interval opens at an Agent/Task tool_use whose tool_result confirms a
    # launch (toolUseResult.agentId; a refused dispatch returns an error string and opens nothing) or at a
    # SendMessage whose result names toolUseResult.resumedAgentId, and closes at the agent's first terminal
    # notice carrier (enqueue, attachment or user record) after it opened. A launch that is not async closes at
    # its own tool_result. Subagent record timestamps and the 300 s tail are not used.
    ev = []
    for k, (p0, _mid, _fl) in DISP.items():
        u, rp = RES.get(k, (None, None))
        if isinstance(u, dict) and u.get("agentId"):
            ev.append((p0, 1, u["agentId"]))
            if u.get("isAsync") is not True: ev.append((rp, 0, u["agentId"]))
    for k, p0 in SM.items():
        u, _rp = RES.get(k, (None, None))
        if isinstance(u, dict) and u.get("resumedAgentId"): ev.append((p0, 1, u["resumedAgentId"]))
    for p0, tid, _kind in NOTE: ev.append((p0, 0, tid))
    ev.sort(key=lambda e: e[0])
    def bl972(a):
        ap = a["pos"]; mid = a["mid"]
        L = max([p for p, md in ASST if md != mid and p < ap], default=(float("-inf"), -1))
        def held(anc):
            if anc is None: return None, None
            h = sum(1 for p in ENQT if L < p < anc)
            return h, sum(1 for p in ENQT if L < p and anc <= p < ap)
        ha, race = held(anchor.get(mid)); hf, _ = held(fallback.get(mid))
        st = {}; opened = {}
        for p, op, aid in ev:
            if p >= ap: break
            st[aid] = bool(op)
            if op: opened[aid] = p
        run = sorted(k for k, v in st.items() if v)
        mids = {mid, prev_mid.get(mid)}
        ds = [(RES.get(k, (None, None))[0], fl) for k, (_p, md, fl) in DISP.items() if md in mids]
        adj = int(any(isinstance(u, dict) and u.get("isAsync") is True for u, _fl in ds))
        # DRAINED-AT-ASK (reported only, never a close guard). The adjacency window is the ask's own message and the
        # lead message just before it (ADJ's window), beginning at the earlier one's first record. The lead RECEIVED
        # a terminal agent notice when one (enqueue, or an attachment/user record carrying it) sits after the last
        # lead assistant record outside that window and before the ask's anchor (api-request, else the fallback,
        # else the message's first record). DRAINED: received, and no lane opened before the window still running.
        ws = first.get(prev_mid.get(mid)) or first.get(mid)
        L2 = max([p for p, md in ASST if md not in mids and p < ap], default=(float("-inf"), -1))
        anc = anchor.get(mid) or fallback.get(mid) or first.get(mid)
        rcv = [k for p, _t, k in NOTE if L2 < p < anc]
        old_run = [k for k in run if opened[k] < ws]
        drained = int(bool(rcv) and not old_run)
        return dict(held_api=ha, held_fb=hf, race=race, running=run, adj=adj, adj_flag=int(any(fl for _u, fl in ds)),
                    drained=drained, drained_carrier=int(drained and "carrier" in rcv))
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
                        a0=a0, a1=a1, ivs=list(ivs), fl=list(subs), **bl972(a)))
    nofenq = {t for _p, t, k in NOTE if k == "enqueue"}
    NOENQ[0] += sum(1 for _p, t, k in NOTE if k == "carrier" and t not in nofenq)
    return out, len(enq)
NOENQ = [0]   # agent terminal-notice carriers (attachment/user) whose task-id has no enqueue in the same file

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

# (q) BL-972 SELF-PROBE, before the corpus, on its own seeded files (the (p) seeds above are untouched).
def _probe972():
    d = tempfile.mkdtemp(prefix="ask_split_probe972.")
    J = json.dumps
    def T(s): return f"2026-11-01T00:{s}Z"
    def usr(s, txt="x"): return J(dict(type="user", timestamp=T(s), message=dict(content=txt)))
    def api(s): return J(dict(type="api-request", timestamp=T(s)))
    def say(mid, s): return J(dict(type="assistant", timestamp=T(s), message=dict(id=mid, content=[dict(type="text", text="x")])))
    def enq(s, tid, status="completed"): return J(dict(type="queue-operation", operation="enqueue", timestamp=T(s),
        content=f"{TN}\n<task-id>{tid}</task-id>\n<status>{status}</status>\n<summary>x</summary>\n</task-notification>"))
    def tu(mid, s, *uses): return J(dict(type="assistant", timestamp=T(s), message=dict(id=mid, content=list(uses))))
    def agent(uid, bg): return dict(type="tool_use", id=uid, name="Agent", input=dict(prompt="p", **({"run_in_background": True} if bg else {})))
    def sendm(uid, to): return dict(type="tool_use", id=uid, name="SendMessage", input=dict(to=to, message="m"))
    def askc(q): return dict(type="tool_use", id=q, name="AskUserQuestion", input=dict(questions=[dict(header="P")]))
    def res(s, uid, tur): return J(dict(type="user", timestamp=T(s), toolUseResult=tur,
        message=dict(content=[dict(type="tool_result", tool_use_id=uid, content="x")])))
    def ans(s, q): return res(s, q, None)
    A = lambda aid: dict(isAsync=True, status="async_launched", agentId=aid)
    files = {
        # visible: an agent notice enqueued before the api-request began the ask's response -> held 1; an older
        # notice followed by a lead message of another id was already answered -> not held
        "hv": [enq("00:00.000", "aOld"), say("m0", "00:01.000"), enq("00:03.000", "aV"), usr("00:03.500"),
               api("00:04.000"), tu("m1", "00:05.000", askc("q")), ans("09:00.000", "q")],
        # race: the notice is enqueued after the api-request began -> held 0
        "hr": [usr("00:02.000"), api("00:03.000"), enq("00:04.000", "aR"), tu("m1", "00:05.000", askc("q")), ans("09:00.000", "q")],
        # killed counts; a Bash (b...) completion does not
        "hk": [enq("00:02.500", "aK", "killed"), enq("00:02.600", "bB", "completed"), usr("00:02.800"), api("00:03.000"),
               tu("m1", "00:05.000", askc("q")), ans("09:00.000", "q")],
        # dispatched in the ask's own response, subagent's first record 0.3 s after the ask -> running
        "dd": [usr("00:02.000"), api("00:03.000"), tu("m1", "00:04.900", agent("u1", True)), tu("m1", "00:05.000", askc("q")),
               res("00:05.100", "u1", A("aD")), ans("09:00.000", "q")],
        # deferral: lane drained, completion notice before the ask, last subagent record 60 s before the ask
        "df": [usr("00:00.000"), api("00:00.500"), tu("m0", "00:01.000", agent("u1", True)), res("00:01.100", "u1", A("aE")),
               say("m1", "00:02.000"), enq("01:00.000", "aE"), usr("01:00.100"), api("01:00.200"), say("m2", "01:01.000"),
               usr("01:02.000"), api("01:03.000"), tu("m3", "02:05.000", askc("q")), ans("09:00.000", "q")],
        # KNOWN LIMIT (defer_plus_bg): the same drained deferral, then a background Agent dispatched in the ask's
        # own message -> ADJ 1 and HELD 0. ADJ cannot tell this lead from one that kept working.
        "dp": [usr("00:00.000"), api("00:00.500"), tu("m0", "00:01.000", agent("u1", True)), res("00:01.100", "u1", A("aE")),
               say("m1", "00:02.000"), enq("01:00.000", "aE"), usr("01:00.100"), api("01:00.200"), say("m2", "01:01.000"),
               usr("01:02.000"), api("01:03.000"), tu("m3", "02:04.000", agent("u9", True)), res("02:04.100", "u9", A("aTriv")),
               tu("m3", "02:05.000", askc("q")), ans("09:00.000", "q")],
        # DRAINED, compliant dispatch-then-ask: an earlier lane (aL1) still running at the ask, a finished lane (aL2)
        # joined by an attachment carrying its notice, a new background dispatch in the ask's own message -> 0
        "cp": [usr("00:00.000"), api("00:00.500"), tu("m0", "00:01.000", agent("u1", True), agent("u2", True)),
               res("00:01.100", "u1", A("aL1")), res("00:01.200", "u2", A("aL2")), say("m1", "00:02.000"),
               enq("01:00.000", "aL2"), J(dict(type="attachment", timestamp=T("01:00.050"), attachment=dict(type="queued_command",
               prompt=f"{TN}\n<task-id>aL2</task-id>\n<status>completed</status>\n</task-notification>"))),
               usr("01:00.100"), api("01:00.200"), say("m2", "01:01.000"), usr("01:02.000"), api("01:03.000"),
               tu("m3", "02:04.000", agent("u9", True)), res("02:04.100", "u9", A("aNew")),
               tu("m3", "02:05.000", askc("q")), ans("09:00.000", "q")],
        # DRAINED, no lanes at all: nothing received, nothing running -> 0
        "nl": [usr("00:00.000"), api("00:00.500"), tu("m1", "00:05.000", askc("q")), ans("09:00.000", "q")],
        # resumed: two agents complete, one is resumed by SendMessage, then the ask
        "rs": [usr("00:00.000"), api("00:00.500"), tu("m0", "00:01.000", agent("u1", True), agent("u2", True)),
               res("00:01.100", "u1", A("aR1")), res("00:01.200", "u2", A("aR2")), say("m1", "00:02.000"),
               enq("00:30.000", "aR1"), enq("00:31.000", "aR2"), usr("00:31.100"), api("00:31.200"),
               tu("m2", "00:32.000", sendm("s1", "aR1")), res("00:32.100", "s1", dict(success=True, resumedAgentId="aR1")),
               api("00:32.200"), say("m3", "00:33.000"), usr("00:34.000"), api("00:35.000"),
               tu("m4", "00:36.000", askc("q")), ans("09:00.000", "q")],
        # adj: a foreground Agent in the previous message (sync result, no isAsync) -> 0; a background one -> 1
        "a0": [usr("00:00.000"), api("00:00.500"), tu("m0", "00:01.000", agent("u1", False)),
               res("00:02.000", "u1", dict(status="completed", agentId="aF")), api("00:02.500"),
               tu("m1", "00:05.000", askc("q")), ans("09:00.000", "q")],
        "a1": [usr("00:00.000"), api("00:00.500"), tu("m0", "00:01.000", agent("u1", True)),
               res("00:01.100", "u1", A("aB")), api("00:02.500"), tu("m1", "00:05.000", askc("q")), ans("09:00.000", "q")],
    }
    for nm, recs in files.items(): open(os.path.join(d, nm + ".jsonl"), "w").write("\n".join(recs) + "\n")
    for nm, tl in (("dd", ("00:05.300",)), ("df", ("00:01.200", "01:05.000"))):
        os.makedirs(os.path.join(d, nm, "subagents"))
        open(os.path.join(d, nm, "subagents", "x.jsonl"), "w").write("".join(J(dict(timestamp=T(x))) + "\n" for x in tl))
    g = {}
    for nm in files:
        (g[nm],), _ = session_asks(os.path.join(d, nm + ".jsonl"), "9999")
    def H(nm): return g[nm]["held_api"]
    def D(nm): return int(H(nm) == 0 and bool(g[nm]["running"]))
    got = dict(held_visible=H("hv"), held_race=(H("hr"), g["hr"]["race"]), held_killed_not_bash=H("hk"),
               held_fb_agrees=all(g[n]["held_fb"] == g[n]["held_api"] for n in g),
               dispatched=(D("dd"), g["dd"]["adj"], g["dd"]["active"]), deferral=(D("df"), g["df"]["adj"], g["df"]["active"]),
               resumed=g["rs"]["running"], adj_fg_bg=((g["a0"]["adj"], g["a0"]["adj_flag"]), (g["a1"]["adj"], g["a1"]["adj_flag"])),
               defer_plus_bg=(g["dp"]["adj"], H("dp"), g["dp"]["running"]),
               drained_defer_plus_bg=g["dp"]["drained"], drained_compliant=(g["cp"]["drained"], g["cp"]["adj"], g["cp"]["running"]),
               drained_no_lanes=g["nl"]["drained"])
    want = dict(held_visible=1, held_race=(0, 1), held_killed_not_bash=1, held_fb_agrees=True,
                dispatched=(1, 1, 0), deferral=(0, 0, 1), resumed=["aR1"], adj_fg_bg=((0, 0), (1, 1)),
                defer_plus_bg=(1, 0, ["aTriv"]), drained_defer_plus_bg=1, drained_compliant=(0, 1, ["aL1", "aNew"]),
                drained_no_lanes=0)
    got_df = g["df"]["drained"]   # pure deferral: reported, not asserted
    if got != want:
        print(f"CONTROL FAIL (q) BL-972 self-probe: got {got}, want {want}"); sys.exit(1)
    Q_MSG.append("CONTROL (q) OK: BL-972 self-probe " + "; ".join(f"{k} {v}" for k, v in got.items()
                                                                     if k in ("held_visible", "held_race", "held_killed_not_bash",
                                                                              "held_fb_agrees", "dispatched", "deferral", "resumed", "adj_fg_bg"))
          + " (dispatched/deferral = (DISPATCHED, ADJ, old active_at_ask); adj = (isAsync, input flag) for foreground, background)")
    Q_MSG.append(f"CONTROL (q) KNOWN LIMIT: defer_plus_bg (ADJ, HELD, running) {got['defer_plus_bg']}: a lead that drains"
                 " its lanes and then dispatches a background Agent in the ask's own message reads ADJ 1 and HELD 0;"
                 " ADJ does not exclude a lead that drains its lanes and then dispatches")
    Q_MSG.append(f"CONTROL (q) OK: DRAINED-AT-ASK self-probe defer_plus_bg {got['drained_defer_plus_bg']}; compliant"
                 f" dispatch-then-ask (DRAINED, ADJ, running) {got['drained_compliant']}; no lanes {got['drained_no_lanes']};"
                 f" pure deferral (reported, not asserted) {got_df}")
Q_MSG = []   # printed after every old line, so the old output keeps its line order
_probe972()

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
print("sprint\task_start\twait_min\tlane_idle_min\tbucket\tactive_at_ask\tfinished_inside\tenq_inside\tenq_agent_inside\trmv_inside\tdlv_inside\tact_inside\tstep\theader"
      "\theld_at_ask\tlanes_running_at_ask\tdispatched_at_ask\tadj_dispatch\tadj_dispatch_input_flag\theld_anchor\tdrained_at_ask")
# BL-972 per-ask values. HELD uses the api-request anchor; an ask with none (an older harness) uses the fallback,
# the last user record before its message began, which is admitted only if it agrees with the api anchor on EVERY
# api-anchored ask (FB-DISAGREE below); otherwise those asks read "-" for HELD and DISPATCHED.
FBD = [r for r in rows if r["held_api"] is not None and r["held_fb"] is not None and r["held_api"] != r["held_fb"]]
for r in rows:
    if r["held_api"] is not None: r["held"], r["anc"] = r["held_api"], "api"
    elif r["held_fb"] is not None and not FBD: r["held"], r["anc"] = r["held_fb"], "fallback"
    else: r["held"], r["anc"] = None, "none"
    r["disp"] = None if r["held"] is None else int(r["held"] == 0 and bool(r["running"]))
def dash(v): return "-" if v is None else v
for r in rows:
    print(f"s{r['n']}\t{r['t']}\t{r['w']/60:.0f}\t{r['idle']/60:.1f}\t{r['b']}\t{r['active']}\t{r['fin']}\t{r['enq']}\t{r['enqa']}\t{r['rmv']}\t{r['dlv']}\t{r['act']}\t{r['step']}\t{r['hdr']}"
          f"\t{dash(r['held'])}\t{len(r['running'])}\t{dash(r['disp'])}\t{r['adj']}\t{r['adj_flag']}\t{r['anc']}\t{r['drained']}")
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

# ---- BL-972: HELD-AT-ASK, DISPATCHED-AT-ASK, ADJ-DISPATCH (every line below is new; the lines above are unchanged)
# HELD-AT-ASK   agent task notifications (task-id a..., <status> completed/failed/killed, queue-operation enqueue)
#               stamped after the lead's last assistant record of another message.id before the ask and before the
#               `api-request` record that began the response carrying the ask. One enqueued after that api-request
#               began is a RACE: the lead could not have seen it, and it is not held. A regression guard: reads 0.
# DISPATCHED-AT-ASK  asks with HELD 0 and at least one lane running at the ask's tool_use (the LANES rule above).
# ADJ-DISPATCH  asks whose own message.id, or the lead message just before it, carries an Agent/Task dispatch the
#               harness launched in the background (toolUseResult.isAsync true). The input flag run_in_background
#               is printed beside it for comparison only: 1099 of 1140 unflagged dispatches returned isAsync true,
#               and the 41 that did not are hook refusals.
for m in Q_MSG: print(m)
print(f"BL-972 anchors: {sum(1 for r in rows if r['anc'] == 'api')} asks on the api-request anchor,"
      f" {sum(1 for r in rows if r['anc'] == 'fallback')} on the fallback, {sum(1 for r in rows if r['anc'] == 'none')} on none;"
      f" FB-DISAGREE {len(FBD)} api-anchored asks where the fallback anchor gives a different HELD"
      + (": " + ", ".join(f"{r['t']} api {r['held_api']} fb {r['held_fb']}" for r in FBD) if FBD else ""))
for keep, ss in DUPS:
    print(f"BL-972 DEDUP: kept copy {keep['sess'][:8]} of {keep['id']} is on anchor {keep['anc']}")
print(f"BL-972 NOTICE-NO-ENQUEUE: {NOENQ[0]} agent terminal-notice attachment/user carriers whose task-id has no enqueue"
      " in the same file (HELD reads enqueues only; lanes close on any carrier)")
for n in sorted({r["n"] for r in rows}):
    R = [r for r in rows if r["n"] == n]; N = len(R)
    H = [r for r in R if r["held"]]; D = [r for r in R if r["disp"]]; A = [r for r in R if r["adj"]]
    print(f"s{n}: BL-972 {N} asks; HELD-AT-ASK {len(H)} asks > 0 (sum {sum(r['held'] for r in H)}, races {sum(r['race'] or 0 for r in R)},"
          f" {sum(1 for r in R if r['held'] is None)} unmeasured); DISPATCHED-AT-ASK {len(D)} of {N} ({100*len(D)/N:.1f}%);"
          f" ADJ-DISPATCH {len(A)} of {N} ({100*len(A)/N:.1f}%), input-flag {sum(r['adj_flag'] for r in R)}")
# DRAINED-AT-ASK, reported only and never a close guard (definition at bl972() in session_asks).
for n in sorted({r["n"] for r in rows}):
    R = [r for r in rows if r["n"] == n]; N = len(R); DR = [r for r in R if r["drained"]]
    print(f"s{n}: BL-972 DRAINED-AT-ASK {len(DR)} of {N} ({100*len(DR)/N:.1f}%), {sum(r['drained_carrier'] for r in DR)} of them"
          f" received by an attachment/user carrier; ADJ-DISPATCH AND DRAINED-AT-ASK {sum(1 for r in DR if r['adj'])} of {N}")
fail = []
for pre, k_, want in (("2026-10-15T10:44:03", "disp", 1), ("2026-10-15T10:44:03", "adj", 1), ("2026-10-30T03:20:41", "disp", 0),
                      ("2026-10-30T02:38:16", "held", 0), ("2026-11-07T15:41:25", "held", 0), ("2026-11-07T18:07:52", "held", 0),
                      ("2026-11-07T00:00:08", "held", 0)):
    if pre > WIN_END: continue
    k = [r for r in rows if r["t"].startswith(pre)]
    if len(k) != 1 or k[0][k_] != want:
        fail.append(f"(r) the {pre} ask must be one row with {k_} {want}, got {[(r['t'], r.get(k_)) for r in k]}")
    else:
        r = k[0]
        print(f"CONTROL (r) OK: s{r['n']} {r['t']} {k_} {want} (held {r['held']}, races {r['race']}, lanes {len(r['running'])},"
              f" adj {r['adj']}, old active_at_ask {r['active']})")
HP = [r for r in rows if r["held"] and r["anc"] == "api"]
if "2026-11-11" > WIN_END: pass   # the (s) population is s317-s322 at the pinned window
elif len(HP) != 1: fail.append(f"(s) exactly one api-anchored ask must read HELD > 0, got {[(r['t'], r['held']) for r in HP]}")
else: print(f"CONTROL (s) OK: the one api-anchored ask with HELD > 0 is s{HP[0]['n']} {HP[0]['t']} ({HP[0]['sess'][:8]}, HELD {HP[0]['held']}, {HP[0]['hdr']})")
HF = [r for r in rows if r["held"] and r["anc"] != "api"]
print(f"BL-972 FALLBACK-HELD: {len(HF)} fallback-anchored asks read HELD > 0" + (": " + ", ".join(f"s{r['n']} {r['t']} {r['held']}" for r in HF) if HF else ""))
n321 = sum(1 for r in rows if r["n"] == 321)
if "2026-11-11" <= WIN_END and n321 != 56: fail.append(f"(t) s321 must read 56 deduplicated asks, got {n321}")
elif "2026-11-11" <= WIN_END: print("CONTROL (t) OK: s321 reads 56 deduplicated asks")
if fail:
    for f in fail: print("CONTROL FAIL " + f)
    sys.exit(1)
