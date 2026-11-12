"""BL-514 (a): subagent WAIT per story, per sprint, from extract.py's own segs.jsonl.

Usage:
  gap.py <EXTRACT_OUT>     read <EXTRACT_OUT>/segs.jsonl, print the per-sprint table
  gap.py --probe           self-probe only (also runs before every corpus read)

segs.jsonl is written by pipeline-efficiency-s317-s320/scripts/extract.py: one row per (transcript, step segment),
kind "lead" or "sub", with `active` (seconds between consecutive records of 300 s or less) and `gap` (seconds between
consecutive records over 300 s) and `sprint` (sprint_of the segment's first record). This script only sums the
kind == "sub" rows; there is no second attribution parser. Story divisors are read from roll.py's STORIES, never
retyped. wait = active + gap. The gap figure covers ALL subagent waits over 300 s (polls, model turns, anything
that left a 300 s hole between two records), not only polls.
"""
import importlib.util, json, os, subprocess, sys, tempfile, collections

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "..", "pipeline-efficiency-s317-s320", "scripts")

def load_stories():
    spec = importlib.util.spec_from_file_location("roll", os.path.join(SCRIPTS, "roll.py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return dict(m.STORIES)

def sub_totals(rows):
    """{sprint: [active_s, gap_s, nsegs]} over kind == "sub" rows. Lead rows are not counted."""
    t = collections.defaultdict(lambda: [0.0, 0.0, 0])
    for r in rows:
        if r.get("kind") != "sub" or r.get("sprint") is None: continue
        x = t[int(r["sprint"])]
        x[0] += float(r["active"]); x[1] += float(r["gap"]); x[2] += 1
    return t

def table(rows, stories):
    t = sub_totals(rows); out = []
    for label, ns in [("s317+s318 pooled", (317, 318))] + [("s%d" % n, (n,)) for n in sorted(stories)]:
        if any(n not in stories for n in ns): continue
        sn = sum(stories[n] for n in ns)
        a = sum(t[n][0] for n in ns if n in t); g = sum(t[n][1] for n in ns if n in t)
        k = sum(t[n][2] for n in ns if n in t)
        out.append((label, sn, k, a / 3600 / sn, g / 3600 / sn, (a + g) / 3600 / sn))
    return out

def render(tab):
    s = "%-18s %7s %8s %14s %14s %14s\n" % ("population", "stories", "sub segs", "active h/story", "gap h/story", "wait h/story")
    for label, sn, k, a, g, w in tab:
        s += "%-18s %7d %8d %14.2f %14.2f %14.2f\n" % (label, sn, k, a, g, w)
    return s

def probe_synthetic():
    """Sub gap is summed, lead segs are excluded, a seg with no sprint is dropped."""
    rows = [dict(kind="sub", sprint=319, active=3600.0, gap=7200.0),
            dict(kind="sub", sprint=319, active=0.0, gap=3600.0),
            dict(kind="lead", sprint=319, active=99999.0, gap=99999.0),
            dict(kind="sub", sprint=None, active=99999.0, gap=99999.0)]
    t = sub_totals(rows)
    ok = list(t[319]) == [3600.0, 10800.0, 2] and list(t) == [319]
    tab = {x[0]: x for x in table(rows, {319: 3})}
    ok = ok and abs(tab["s319"][4] - 1.0) < 1e-9 and abs(tab["s319"][3] - 1 / 3) < 1e-9 and abs(tab["s319"][5] - 4 / 3) < 1e-9
    return ok

def jl(path, recs):
    with open(path, "w") as f:
        for r in recs: f.write(json.dumps(r) + "\n")

def probe_extract():
    """Synthetic subagent transcripts through extract.py (EXTRACT_ROOT = a mktemp tree): a 300 s gap lands in
    active, a 301 s gap in gap; a lead transcript with a 400 s gap is in segs.jsonl as kind lead and is not summed."""
    root = tempfile.mkdtemp(prefix="gap-probe-root."); out = tempfile.mkdtemp(prefix="gap-probe-out.")
    def rec(sec, typ="assistant"):
        return {"type": typ, "timestamp": "2026-10-20T%02d:%02d:%02dZ" % (sec // 3600, sec % 3600 // 60, sec % 60),
                "message": {"content": []}}
    sess = "11111111-aaaa"
    os.makedirs(os.path.join(root, sess, "subagents"))
    jl(os.path.join(root, sess, "subagents", "agent-300.jsonl"), [rec(0), rec(300)])
    jl(os.path.join(root, sess, "subagents", "agent-301.jsonl"), [rec(0), rec(301)])
    jl(os.path.join(root, sess + ".jsonl"), [rec(0), rec(400)])
    env = dict(os.environ, EXTRACT_ROOT=root); env.pop("EXTRACT_WIN_END", None); env.pop("EXTRACT_WIN_START", None)
    p = subprocess.run([sys.executable, os.path.join(SCRIPTS, "extract.py"), out], env=env, capture_output=True, text=True)
    if p.returncode != 0: return False, "extract.py exit %d: %s" % (p.returncode, p.stderr[-200:])
    rows = [json.loads(l) for l in open(os.path.join(out, "segs.jsonl"))]
    by = {r["unit"]: r for r in rows}
    got = {u: (by[u]["kind"], by[u]["active"], by[u]["gap"]) for u in by}
    want = {"agent-300": ("sub", 300.0, 0.0), "agent-301": ("sub", 0.0, 301.0), "11111111-aaaa": ("lead", 0.0, 400.0)}
    ok = got == want and list(sub_totals(rows)[319]) == [300.0, 301.0, 2]
    return ok, "got %s" % got

def probe():
    a = probe_synthetic(); b, why = probe_extract()
    print("probe synthetic segs (sub gap summed, lead and sprint-less excluded): %s" % ("PASS" if a else "FAIL"))
    print("probe extract.py via EXTRACT_ROOT (300 s -> active, 301 s -> gap, lead excluded): %s" % ("PASS" if b else "FAIL " + why))
    return a and b

def main(argv):
    if not probe(): return 2
    if len(argv) < 2 or argv[1] == "--probe": return 0
    path = os.path.join(argv[1], "segs.jsonl")
    rows = [json.loads(l) for l in open(path)]
    if not rows: print("segs.jsonl empty"); return 2
    stories = load_stories()
    nsub = sum(1 for r in rows if r.get("kind") == "sub"); nlead = len(rows) - nsub
    print("segs.jsonl: %d rows, %d sub (summed), %d lead (excluded); STORIES from roll.py = %s" % (len(rows), nsub, nlead, stories))
    print(render(table(rows, stories)))
    print("Covers ALL subagent waits over 300 s (any two consecutive records of a subagent transcript more than\n"
          "300 s apart), not only polls. wait = active + gap.")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
