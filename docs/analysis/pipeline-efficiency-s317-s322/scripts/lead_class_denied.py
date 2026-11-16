"""BL-819 item 2(b) on s322: what the lead classes that rose are made of, per lead call, on extract.py's own classifier.

usage: EXTRACT_WIN_END=<window> python3 -I lead_class_denied.py <SCRATCH_OUT> <OUT> <sprint A> <sprint B>
       python3 -I lead_class_denied.py --self-test

extract.py is run once more, unchanged except for one injected subclass of its Classer (inserted at an anchor that must
occur exactly once), writing its usual files into <SCRATCH_OUT> plus calls.jsonl: one row per usage-bearing lead
message.id (a "call", exactly the unit classes.jsonl counts in `calls`), with its sprint, step and class as extract.py's
own write() assigns them, the tool names of its tool_use blocks, and the fate of each block's tool_result:
  DENIED   every tool_use of the call was refused by a hook (tool_result is_error and its text opens with "PreToolUse:")
  ERRORED  every tool_use returned is_error, and at least one was not a hook refusal
  TEXT     the call carried no tool_use (an end-of-turn or narration message)
  RAN      at least one tool_use returned a non-error result, or has no tool_result inside the window
<OUT> is the reference extraction at the same window (extract.py, analyze.py, `roll.py --classes > classes.txt`).
Read-only on the transcripts; writes only <SCRATCH_OUT>. Stdlib only.

Printed, per sprint A and B, per story, for every lead class and for the classes summed:
  calls, and of them DENIED / ERRORED / TEXT / RAN, and RAN calls per story (the calls that did something).
  The call-rate arm: each class's per-story calls in A over B, against the whole lead seat's ratio. A class whose ratio
  is at or below the lead seat's grew no faster than the lead as a whole, so its rise is the lead's call rate (a model
  property in s322, whose lead ran local models only), not more of that class's work.
  For implementation and gate[implementation] the same cells, and for every step the merge and other cells.
  For `other`, its RAN calls by first tool name.
Controls (each must read MATCH):
  C1 calls.jsonl summed per (sprint, step, class) equals <OUT>/classes.jsonl calls on every cell, and the scratch
     classes.jsonl is byte-equal to <OUT>/classes.jsonl (the injection changed no class).
  C2 an impossible tool name counts 0 beside Read above 0.
  C3 the pipeline-bucket calls per (sprint, step, class) equal lead_class_value.cells(), roll.classes()'s population.
"""
import collections, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXTRACT = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
sys.path.insert(0, HERE)
import roll  # noqa: E402  (guarded main)

ANCHOR = "GATE_EV = []   # (sprint, \"open\" | \"closed\" | \"unclosed\" | \"left\"), lead scans only\n"
INJECT = r'''
import collections

def _lcd_text(c):
    x = c.get("content")
    if isinstance(x, list):
        x = "".join(str(e.get("text", "")) for e in x if isinstance(e, dict))
    return str(x or "")

def _lcd_fate(tools, res):
    if not tools: return "TEXT"
    fs = [res.get(tid) for tid, _ in tools]
    if any(f is None or f == "ok" for f in fs): return "RAN"
    return "DENIED" if all(f == "deny" for f in fs) else "ERRORED"

_LCD = open(os.path.join(OUT, "calls.jsonl"), "w")

_LCDBase = Classer

class _LCDClasser(_LCDBase):
    def __init__(self):
        _LCDBase.__init__(self); self._res = {}; self._tools = collections.defaultdict(list)
    def record(self, r, typ):
        m = r.get("message") or {}
        if typ == "assistant" and m.get("id"):
            for c in m.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("id") not in self.tu_mid:
                    self._tools[m["id"]].append((c.get("id"), c.get("name")))
        if typ == "user" and isinstance(m.get("content"), list):
            for c in m["content"]:
                if isinstance(c, dict) and c.get("type") == "tool_result":
                    self._res[c.get("tool_use_id")] = ("deny" if _lcd_text(c).lstrip().startswith("PreToolUse:") else "err") if c.get("is_error") else "ok"
        _LCDBase.record(self, r, typ)
    def write(self, unit, sess, usage, segs):
        _LCDBase.write(self, unit, sess, usage, segs)
        for mid, (model, u, t, s) in usage.items():
            tl = self._tools.get(mid, [])
            _LCD.write(json.dumps(dict(unit=unit, step=s, sprint=sprint_of(segs[s]["first"]), cls=self.cls(("mid", mid)),
                                       tools=[n for _, n in tl], fate=_lcd_fate(tl, self._res))) + "\n")

Classer = _LCDClasser
'''
FATES = ("DENIED", "ERRORED", "TEXT", "RAN")
IMPOSSIBLE_TOOL = "QzxvNoSuchTool4417"


def run_extract(scratch):
    src = open(EXTRACT).read()
    if src.count(ANCHOR) != 1:
        sys.exit("anchor found %d times in extract.py (must be 1): refusing" % src.count(ANCHOR))
    src2 = src.replace(ANCHOR, INJECT + ANCHOR)
    if src2 == src:
        sys.exit("injection changed nothing: refusing")
    os.makedirs(scratch, exist_ok=True)
    sys.argv = [EXTRACT, scratch]
    g = {"__name__": "__main__", "__file__": EXTRACT}
    exec(compile(src2, EXTRACT, "exec"), g)
    g["_LCD"].close()


def report(scratch, out, A, B):
    calls = [json.loads(l) for l in open(os.path.join(scratch, "calls.jsonl"))]
    ref = collections.Counter(); mine = collections.Counter()
    for l in open(os.path.join(out, "classes.jsonl")):
        c = json.loads(l)
        if c["kind"] == "lead":
            ref[(c["sprint"], c["step"], c["cls"])] += c["calls"]
    for c in calls:
        mine[(c["sprint"], c["step"], c["cls"])] += 1
    keys = {k for k in set(ref) | set(mine) if ref[k] or mine[k]}
    bad = [k for k in keys if ref[k] != mine[k]]
    same = open(os.path.join(scratch, "classes.jsonl"), "rb").read() == open(os.path.join(out, "classes.jsonl"), "rb").read()
    print("C1 calls.jsonl against classes.jsonl calls: %d MATCH, %d DIFFERS%s; scratch classes.jsonl %s" % (
        len(keys) - len(bad), len(bad), (" " + str(sorted(bad)[:5])) if bad else "",
        "BYTE-EQUAL to the reference" if same else "DIFFERS from the reference"))
    tools = collections.Counter(t for c in calls for t in c["tools"])
    print("C2 tool names: Read %d, impossible %s %d" % (tools["Read"], IMPOSSIBLE_TOOL, tools[IMPOSSIBLE_TOOL]))
    return calls


def cells(calls, sprint, pred):
    d = collections.defaultdict(collections.Counter)
    for c in calls:
        if c["sprint"] == sprint and pred(c):
            d[c["cls"]][c["fate"]] += 1
    return d


def print_block(title, calls, A, B, pred):
    na, nb = roll.STORIES[A], roll.STORIES[B]
    a = cells(calls, A, pred); b = cells(calls, B, pred)
    ta = sum(sum(v.values()) for v in a.values()); tb = sum(sum(v.values()) for v in b.values())
    lead_ratio = (ta / na) / (tb / nb) if tb else float("nan")
    print("-- %s, per story; lead seat calls s%d %.1f against s%d %.1f, ratio %.2f" % (title, A, ta / na, B, tb / nb, lead_ratio))
    print("   %-20s %-5s %8s %8s %8s %8s %8s | %s" % ("class", "s", "calls", "DENIED", "ERRORED", "TEXT", "RAN", "call ratio A/B against the lead seat"))
    for cls in roll.CLASS_ORDER:
        if cls == "idle-wait":
            continue
        for sp, d, n in ((B, b, nb), (A, a, na)):
            v = d.get(cls, collections.Counter())
            tail = ""
            if sp == A:
                ca = sum(a.get(cls, {}).values()) / na; cb = sum(b.get(cls, {}).values()) / nb
                if cb:
                    r = ca / cb
                    tail = "%.2f, %s" % (r, "AT-OR-BELOW the lead seat's %.2f" % lead_ratio if r <= lead_ratio else "ABOVE the lead seat's %.2f" % lead_ratio)
                    ra = v["RAN"] / na; rb = b.get(cls, collections.Counter())["RAN"] / nb
                    tail += "; RAN calls %.1f against %.1f" % (ra, rb)
                elif ca:
                    tail = "absent in s%d" % B
            print("   %-20s s%-4d %8.1f %8.1f %8.1f %8.1f %8.1f | %s" % (cls, sp, sum(v.values()) / n, v["DENIED"] / n,
                                                                    v["ERRORED"] / n, v["TEXT"] / n, v["RAN"] / n, tail))


def main(scratch, out, A, B):
    if not os.path.exists(os.path.join(scratch, "calls.jsonl")):
        run_extract(scratch)
    calls = report(scratch, out, A, B)
    # roll.classes()'s population, exactly as lead_class_value.cells() takes it: the session's bucket from units.jsonl,
    # the sprint from segs, the step relabelled and grouped by step_base. Each call row is re-keyed onto it.
    relabel, _fam = roll.analyze_defs()
    bucket = {u["sess"]: "pipeline" if any(k.split("|", 1)[0] != "pre-step" for k in u["tok"]) else "x"
              for u in (json.loads(l) for l in open(os.path.join(out, "units.jsonl"))) if u["kind"] == "lead"}
    segs = {}
    for l in open(os.path.join(out, "segs.jsonl")):
        s = json.loads(l)
        if s["kind"] == "lead":
            segs[(s["unit"], s["step"])] = s
    pipe = []
    for c in calls:
        s = segs.get((c["unit"], c["step"]))
        if s is None or bucket.get(s["sess"]) != "pipeline" or s["sprint"] not in roll.STORIES:
            continue
        pipe.append(dict(c, sprint=s["sprint"], step=roll.step_base(relabel.get((s["sess"], c["step"]), c["step"]))))
    import lead_class_value as L
    ref = L.cells(out); mine = collections.Counter((c["sprint"], c["step"], c["cls"]) for c in pipe)
    keys = {(k[0], k[1], cl) for k, v in ref.items() for cl, a in v.items() if a[1]} | set(mine)
    bad = [k for k in keys if mine[k] != ref.get((k[0], k[1]), {}).get(k[2], [0, 0])[1]]
    print("C3 pipeline-bucket calls per (sprint, step, class) against lead_class_value.cells(): %d MATCH, %d DIFFERS%s" % (
        len(keys) - len(bad), len(bad), (" " + str(sorted(bad)[:5])) if bad else ""))
    print("pipeline-bucket lead calls: %d of %d" % (len(pipe), len(calls)))
    print_block("all steps, pipeline bucket", pipe, A, B, lambda c: True)
    for st in ("implementation", "gate[implementation]"):
        print_block(st, pipe, A, B, lambda c, st=st: c["step"] == st)
    print("-- merge and other, every step, per story: calls (RAN) s%d -> s%d, with each cell's call ratio against its step's" % (B, A))
    na, nb = roll.STORIES[A], roll.STORIES[B]
    steps = sorted({c["step"] for c in pipe if c["sprint"] in (A, B)})
    for st in steps:
        sel = [c for c in pipe if c["step"] == st]
        sa = sum(1 for c in sel if c["sprint"] == A) / na; sb = sum(1 for c in sel if c["sprint"] == B) / nb
        for cls in ("merge", "other"):
            ca = [c for c in sel if c["sprint"] == A and c["cls"] == cls]; cb = [c for c in sel if c["sprint"] == B and c["cls"] == cls]
            if not ca and not cb:
                continue
            ra = sum(1 for c in ca if c["fate"] == "RAN") / na; rb = sum(1 for c in cb if c["fate"] == "RAN") / nb
            ratio = (len(ca) / na) / (len(cb) / nb) if cb else None
            sr = sa / sb if sb else None
            print("   %-28s %-6s %6.1f (%5.1f) -> %6.1f (%5.1f)  ratio %s, step %s  %s" % (
                st, cls, len(cb) / nb, rb, len(ca) / na, ra, "%.2f" % ratio if ratio else "n/a", "%.2f" % sr if sr else "n/a",
                "" if ratio is None or sr is None else ("AT-OR-BELOW" if ratio <= sr else "ABOVE")))
    for sp in (B, A):
        oc = collections.Counter((c["tools"][0] if c["tools"] else "(text)") for c in pipe if c["sprint"] == sp and c["cls"] == "other" and c["fate"] in ("RAN", "TEXT"))
        tot = sum(oc.values())
        print("-- s%d other, RAN and TEXT calls by first tool, per story (of %.1f): %s" % (
            sp, tot / roll.STORIES[sp], ", ".join("%s %.1f" % (k, v / roll.STORIES[sp]) for k, v in oc.most_common(8))))


def self_test():
    ns = {"collections": collections, "json": json, "os": os, "OUT": "/nonexistent"}
    body = INJECT.split("_LCD = open")[0]
    exec(body, ns)
    fate = ns["_lcd_fate"]; text = ns["_lcd_text"]
    cases = [([], {}, "TEXT"), ([("a", "Read")], {"a": "deny"}, "DENIED"), ([("a", "Read")], {"a": "err"}, "ERRORED"),
             ([("a", "Read"), ("b", "Bash")], {"a": "deny", "b": "ok"}, "RAN"), ([("a", "Read"), ("b", "Bash")], {"a": "deny", "b": "err"}, "ERRORED"),
             ([("a", "Read")], {}, "RAN")]
    bad = 0
    for tl, res, want in cases:
        got = fate(tl, res)
        bad += got != want
        print("  fate %s %s -> %s (want %s) %s" % (tl, res, got, want, "ok" if got == want else "WRONG"))
    for c, want in (({"content": [{"type": "text", "text": " PreToolUse:Read hook error"}]}, True), ({"content": "Error: no such file"}, False)):
        got = text(c).lstrip().startswith("PreToolUse:")
        bad += got != want
        print("  deny-text %r -> %s (want %s)" % (c["content"] if isinstance(c["content"], str) else "list", got, want))
    src = open(EXTRACT).read()
    print("  anchor occurrences in extract.py: %d (must be 1)" % src.count(ANCHOR)); bad += src.count(ANCHOR) != 1
    print("self-test: %s" % ("PASS" if not bad else "FAIL (%d)" % bad))
    return 0 if not bad else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--self-test"]:
        sys.exit(self_test())
    if len(a) != 4:
        sys.exit(__doc__)
    main(a[0], a[1], int(a[2]), int(a[3]))
