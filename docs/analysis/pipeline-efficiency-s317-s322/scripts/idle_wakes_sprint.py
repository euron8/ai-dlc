#!/usr/bin/env python3
"""BL-538 per-sprint wake reading over every lead transcript of one graph sprint (stdlib only; read only).

Wraps idle_wakes.py (the wake/idle definition is ITS count(), imported, not restated) with three things it lacks:

  Identification. The lead transcripts of sprint N are the lead units that extract.py + analyze.py, run at the
    same WIN_END into OUT, bucket as `pipeline` (analyze.py's rule: a token key on a step other than pre-step)
    and that own a sprint-N segment in segs.jsonl. That is the population `roll.py --seats` sums its pipeline
    bucket over, so the wake reading and the seat figures cover one set. Every other top-level transcript with a
    record inside the window is printed as EXCLUDED with its analyze.py bucket, so the exclusion is visible.
  Line window. Sprint N's window is [edge(N-1), edge(N)) by extract.py's EDGES, read from extract.py's source
    (not restated), cut at --win-end (a record stamped exactly at it is inside, as in extract.py). Per transcript,
    the wakes counted are those whose 1-based line lies in [first non-sidechain line stamped inside the window,
    last such line]; idle_wakes.count(--upto) supplies the upper bound and the lower bound filters. A wake's idle
    test still reads to the next user line (idle_wakes.py's rule).
  Split. Agent-exit vs background-command wakes (idle_wakes.py's _kind), and dispatcher vs non-dispatcher
    transcripts: a DISPATCHER transcript is one where any of its subagents' meta files carries spawnDepth 2 (a
    nested spawn, which only a round-dispatcher makes).

Usage:
  idle_wakes_sprint.py --sprint N --out OUT [--win-end ISO] [--only ID8,...] [--bound ID8=LINE,...]
--only restricts the reading to the named 8-char ids, all of which must be in the identified set (else refused).
--bound replaces one transcript's upper line bound (a recorded-control reconstruction; printed as BOUND).
"""
import ast
import datetime as dt
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import idle_wakes  # noqa: E402

ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
EXTRACT = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
ANALYZE = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s318", "scripts", "analyze.py")


def edges():
    tree = ast.parse(open(EXTRACT).read())
    for n in tree.body:
        if isinstance(n, ast.Assign) and any(getattr(t, "id", None) == "EDGES" for t in n.targets):
            return ast.literal_eval(n.value)
    raise SystemExit("EDGES not found in " + EXTRACT)


def ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def window(n, win_end):
    lo = hi = None
    for e, k in edges():
        if k == n - 1:
            lo = e
        if k == n:
            hi = e
    if lo is None or hi is None:
        raise SystemExit("no edge pair for sprint %d" % n)
    hi_ts = ts(hi)
    if win_end:
        hi_ts = min(hi_ts, ts(win_end) + 1e-6)
    return ts(lo), hi_ts


def lines_in(path, lo, hi):
    """(first, last) 1-based line of a non-sidechain record stamped inside [lo, hi), or (None, None)."""
    first = last = None
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            try:
                d = json.loads(line)
            except ValueError:
                continue
            t = d.get("timestamp")
            if not t or d.get("isSidechain"):
                continue
            if lo <= ts(t) < hi:
                if first is None:
                    first = n
                last = n
    return first, last


def dispatcher(path):
    for m in glob.glob(os.path.join(path[:-len(".jsonl")], "subagents", "*.meta.json")):
        try:
            if json.load(open(m)).get("spawnDepth") == 2:
                return True
        except (ValueError, OSError):
            pass
    return False


def buckets(out):
    """analyze.py's lead-session bucket, by its own rule (read from its source by name, not restated)."""
    units = [json.loads(l) for l in open(os.path.join(out, "units.jsonl"))]
    tree = ast.parse(open(ANALYZE).read())
    src = None
    for i, node in enumerate(tree.body):
        if isinstance(node, ast.Assign) and any(getattr(t, "id", None) == "bucket" for t in node.targets):
            src = ast.Module(tree.body[i:i + 2], [])  # `bucket = {}` and the `for u in units:` loop after it
            break
    if src is None:
        raise SystemExit("bucket rule not found in " + ANALYZE)
    ns = {"units": units}
    exec(compile(src, ANALYZE, "exec"), ns)
    return {k[:8]: v for k, v in ns["bucket"].items()}


def main(argv):
    n = win_end = out = only = None
    bound = {}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--sprint": n = int(argv[i + 1]); i += 2
        elif a == "--win-end": win_end = argv[i + 1]; i += 2
        elif a == "--out": out = argv[i + 1]; i += 2
        elif a == "--only": only = argv[i + 1].split(","); i += 2
        elif a == "--bound":
            for kv in argv[i + 1].split(","):
                k, v = kv.split("=")
                bound[k] = int(v)
            i += 2
        else:
            sys.stderr.write(__doc__); return 2
    if n is None or out is None:
        sys.stderr.write(__doc__); return 2
    lo, hi = window(n, win_end)
    iso = lambda x: dt.datetime.fromtimestamp(x, dt.timezone.utc).isoformat()
    print("sprint %d window [%s, %s) root %s" % (n, iso(lo), iso(hi), ROOT))
    B = buckets(out)
    segs = [json.loads(l) for l in open(os.path.join(out, "segs.jsonl"))]
    pipe = {s["sess"][:8] for s in segs if s["kind"] == "lead" and int(s["sprint"]) == n and B.get(s["sess"][:8]) == "pipeline"}
    ids, excluded = [], []
    for p in sorted(glob.glob(os.path.join(ROOT, "*.jsonl"))):
        id8 = os.path.basename(p)[:8]
        first, last = lines_in(p, lo, hi)
        if first is None:
            if id8 in pipe:
                print("REFUSED: %s is in the extractor set but has no record in the window" % id8); return 2
            continue
        (ids if id8 in pipe else excluded).append((id8, p, first, last))
    if not ids or len(ids) != len(pipe):
        print("REFUSED: identified %d of an extractor set of %d" % (len(ids), len(pipe))); return 2
    print("identified %d (extractor pipeline bucket, sprint-%d segments): %s" % (len(ids), n, " ".join(x[0] for x in ids)))
    print("EXCLUDED %d with a record in the window: %s" % (len(excluded), " ".join("%s(%s)" % (x[0], B.get(x[0], "no-unit")) for x in excluded)))
    if only:
        missing = [o for o in only if o not in {x[0] for x in ids}]
        if missing:
            print("REFUSED: --only names ids outside the identified set: %s" % missing); return 2
        ids = [x for x in ids if x[0] in only]
        print("subset (--only) %d: %s" % (len(ids), " ".join(x[0] for x in ids)))
    T = {k: [0] * 6 for k in ("all", "disp", "nodisp")}
    for id8, p, first, last in ids:
        hi_line = bound.get(id8, last)
        w = [x for x in idle_wakes.count(p, hi_line) if x[0] >= first]
        idle = [x for x in w if not x[2]]
        ag = [x for x in w if x[1] == "agent"]
        agi = [x for x in ag if not x[2]]
        disp = dispatcher(p)
        row = [len(w), len(idle), len(ag), len(agi), len(w) - len(ag), len(idle) - len(agi)]
        for k in ("all", "disp" if disp else "nodisp"):
            T[k] = [a + b for a, b in zip(T[k], row)]
        print("%s lines %d-%d%s dispatcher=%s wakes=%d idle=%d agent=%d/%d cmd=%d/%d" % (
            id8, first, hi_line, " (BOUND)" if id8 in bound else "", "yes" if disp else "no",
            row[0], row[1], row[3], row[2], row[5], row[4]))
    # Window control: the earliest and latest top-level record naming sprint_id N and N+1 (a sprint_id field, never
    # a bare "s<N+1>" mention, which prose inside sprint N carries). Sprint N+1's earliest must fall after the window.
    sid = re.compile(r'sprint[_-]?id(?:\\?["\'])?\s*[:=]\s*(?:\\?["\'])?(%d|%d)\b' % (n, n + 1))
    seen = {}
    for p in sorted(glob.glob(os.path.join(ROOT, "*.jsonl"))):
        with open(p, encoding="utf-8") as fh:
            for ln, line in enumerate(fh, 1):
                m = sid.search(line)
                if not m:
                    continue
                try:
                    t = json.loads(line).get("timestamp")
                except ValueError:
                    continue
                if not t:
                    continue
                k = int(m.group(1))
                e = seen.setdefault(k, [0, None, None])
                e[0] += 1
                if e[1] is None or ts(t) < ts(e[1][0]): e[1] = (t, os.path.basename(p)[:8], ln)
                if e[2] is None or ts(t) > ts(e[2][0]): e[2] = (t, os.path.basename(p)[:8], ln)
    for k in (n, n + 1):
        e = seen.get(k)
        print("window control sprint_id %d: %s" % (k, "0 records" if not e else "%d records, earliest %s %s:%d, latest %s %s:%d" % (
            e[0], e[1][0], e[1][1], e[1][2], e[2][0], e[2][1], e[2][2])))
    nxt = seen.get(n + 1)
    if win_end and nxt:
        print("window control: first sprint_id %d record %s the window end" % (n + 1, "AFTER" if ts(nxt[1][0]) >= hi else "BEFORE (FAIL)"))
    pc = lambda a, b: ("%.0f%%" % (100.0 * a / b)) if b else "n/a"
    for k, lab in (("all", "TOTAL"), ("disp", "DISPATCHER"), ("nodisp", "NON-DISPATCHER")):
        r = T[k]
        print("%s wakes=%d idle=%d (%s); agent-exit idle %d of %d (%s); background-command idle %d of %d" % (
            lab, r[0], r[1], pc(r[1], r[0]), r[3], r[2], pc(r[3], r[2]), r[5], r[4]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
