# ask_split_late_write_probe.py -- BL-972 / BL-994: does ask_split.py read an ask the same way when the harness
# writes the ask's assistant record at ANSWER time instead of at issue time?
#
# usage: python3 -I ask_split_late_write_probe.py        (exit 0: the close columns agree; 1: they do not)
#
# BL-994 measured Claude Code 2.1.325 writing the AskUserQuestion assistant record directly before its
# tool_result, stamped at issue time. This builds two seeded lead sessions with the same records and the same
# timestamps. They differ only in file order. EARLY writes the ask record when it was issued. LATE writes it
# directly before its answer, after the records stamped inside the wait. ask_split.py's own session_asks() reads
# both. Only the definitions are loaded, by ast, out of ask_split.py's source, so the corpus and its controls
# do not run and nothing is restated here.
#
# ASSERTED equal on both orders, each with a non-zero anchor so the comparison cannot pass on two empty rows:
#   the ask count, the wait, the bucket, ENQ and ENQ-AGENT (timestamp-scored), ADJ-DISPATCH (keyed on
#   message.id), HELD-AT-ASK (api and fallback anchors, and the race count), the lanes running at the ask
#   (DISPATCHED-AT-ASK's input) and DRAINED-AT-ASK. Each is keyed on (timestamp, file index) or on message.id.
# REPORTED, never asserted: RMV, DLV and ACT. They are POSITIONAL in file order between the ask record and its
#   result, as ask_split.py's header says. Under a late write they read 0 by construction.
# CONTROL: the two seeded files must differ in bytes and hold the same multiset of lines, else exit 1.
import ast, json, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "ask_split.py")
WANT_ASSIGN = {"ROOT", "WIN_END", "TAIL", "HERE", "_src", "EDGES", "E", "TN", "TERMINAL", "NOENQ"}
WANT_DEF = {"sp", "ts", "is_agent_note", "agent_terminal", "bg_flag", "session_asks"}
tree = ast.parse(open(SRC).read())
body = [n for n in tree.body if isinstance(n, (ast.Import, ast.ImportFrom))
        or (isinstance(n, ast.FunctionDef) and n.name in WANT_DEF)
        or (isinstance(n, ast.Assign) and any(getattr(t, "id", None) in WANT_ASSIGN for t in n.targets))]
got_names = {n.name for n in body if isinstance(n, ast.FunctionDef)}
if got_names != WANT_DEF:
    print(f"FAIL: ask_split.py lacks {sorted(WANT_DEF - got_names)}; the probe cannot run the shipping reader"); sys.exit(1)
NS = {"__file__": SRC, "__name__": "ask_split_defs"}
exec(compile(ast.Module(body=body, type_ignores=[]), SRC, "exec"), NS)
session_asks, TN = NS["session_asks"], NS["TN"]

J = json.dumps
def T(s): return f"2026-11-01T00:{s}Z"
def usr(s): return J(dict(type="user", timestamp=T(s), message=dict(content="x")))
def api(s): return J(dict(type="api-request", timestamp=T(s)))
def say(mid, s): return J(dict(type="assistant", timestamp=T(s), message=dict(id=mid, content=[dict(type="text", text="x")])))
def tu(mid, s, *uses): return J(dict(type="assistant", timestamp=T(s), message=dict(id=mid, content=list(uses))))
def agent(uid): return dict(type="tool_use", id=uid, name="Agent", input=dict(prompt="p", run_in_background=True))
def askc(q): return dict(type="tool_use", id=q, name="AskUserQuestion", input=dict(questions=[dict(header="P")]))
def res(s, uid, tur): return J(dict(type="user", timestamp=T(s), toolUseResult=tur,
                                    message=dict(content=[dict(type="tool_result", tool_use_id=uid, content="x")])))
NOTE = f"{TN}\n<task-id>aL</task-id>\n<status>completed</status>\n<summary>x</summary>\n</task-notification>"
def A(aid): return dict(isAsync=True, status="async_launched", agentId=aid)

# One lane (aL) launched in an earlier message and still running at the ask; a background dispatch (aN) in the
# ask's own message (ADJ 1); aL finishes inside the wait (enqueue, remove, attachment carrier stamped inside).
pre = [usr("00:00.000"), api("00:00.500"), tu("m0", "00:01.000", agent("u1")), res("00:01.100", "u1", A("aL")),
       say("m1", "00:02.000"), usr("00:03.000"), api("00:04.000"), say("m2", "00:04.500"),
       tu("m2", "00:05.000", agent("u2")), res("00:05.100", "u2", A("aN"))]
ask = tu("m2", "00:05.500", askc("q"))
inside = [J(dict(type="queue-operation", operation="enqueue", timestamp=T("03:00.000"), content=NOTE)),
          J(dict(type="queue-operation", operation="remove", timestamp=T("03:01.000"), content=NOTE)),
          J(dict(type="attachment", timestamp=T("03:02.000"), attachment=dict(type="queued_command", prompt=NOTE)))]
answer = res("09:00.000", "q", None)
# late: the ask record directly before its answer. late_attach: the same, with the notification attachment
# written after the answer's tool_result as well (BL-994's queued_command shape on 2.1.325).
ORDERS = {"early": pre + [ask] + inside + [answer],
          "late": pre + inside + [ask, answer],
          "late_attach": pre + inside[:2] + [ask, answer, inside[2]]}

d = tempfile.mkdtemp(prefix="ask_split_late_write.")
rows = {}; txt = {}
for nm, recs in ORDERS.items():
    p = os.path.join(d, nm + ".jsonl")
    open(p, "w").write("\n".join(recs) + "\n")
    txt[nm] = open(p).read()
    os.makedirs(os.path.join(d, nm, "subagents"))
    open(os.path.join(d, nm, "subagents", "aL.jsonl"), "w").write(
        "".join(J(dict(timestamp=T(x))) + "\n" for x in ("00:01.200", "01:00.000", "02:59.000")))
    asks, _ = session_asks(p, "9999")
    rows[nm] = asks
LATE = [n for n in ORDERS if n != "early"]
for nm in LATE:
    if txt[nm] == txt["early"] or sorted(txt[nm].splitlines()) != sorted(txt["early"].splitlines()):
        print(f"CONTROL FAIL: early and {nm} must hold the same lines in a different order"); sys.exit(1)
    print(f"CONTROL OK: early and {nm} hold the same lines in a different order")

KEYS = ("w", "b", "enq", "enqa", "adj", "adj_flag", "held_api", "held_fb", "race", "running", "drained")
POSITIONAL = ("rmv", "dlv", "act")
fail = 0
if any(len(rows[n]) != 1 for n in ORDERS):
    print("FAIL: ask count " + ", ".join(f"{n} {len(rows[n])}" for n in ORDERS) + "; want 1 each"); sys.exit(1)
e = rows["early"][0]
# Anchors: the seeded early row must actually carry the signal each column reads, or "equal" proves nothing.
anchors = dict(w=e["w"] > 0, b=e["b"] == "FINISHED-INSIDE", enq=e["enq"] == 1, enqa=e["enqa"] == 1, adj=e["adj"] == 1,
               running=e["running"] == ["aL", "aN"], held_api=e["held_api"] == 0, race=e["race"] == 0)
for k, ok in anchors.items():
    if not ok:
        print(f"ANCHOR FAIL: early {k} = {e[k]!r}"); fail = 1
for nm in LATE:
    l = rows[nm][0]
    for k in KEYS:
        same = e[k] == l[k]
        print(f"{'OK  ' if same else 'FAIL'} {nm} {k}: early {e[k]!r}, {nm} {l[k]!r}")
        fail |= not same
    for k in POSITIONAL:
        print(f"REPORTED {nm} {k} (positional, not asserted): early {e[k]!r}, {nm} {l[k]!r}")
print("RESULT:", "FAIL" if fail else "OK -- every close column reads the same under a late-written ask record")
sys.exit(1 if fail else 0)
