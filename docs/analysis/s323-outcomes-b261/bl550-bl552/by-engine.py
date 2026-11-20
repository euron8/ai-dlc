"""BL-550 close reading helper: split count.py's populations by the engine version in force at dispatch.

Usage: python3 -I by-engine.py START END OUT_TSV [--root DIR]

Reuses count.py (../../bl550-missing-path-counter/count.py) unchanged: same window rule, same classify(),
same scan(). Per classified seat prints one TSV row: transcript, first_ts, kind, step, lines, has_cited,
engine. has_cited is 1 when the dispatch prompt carries a `cited-paths:` line (the 0.1135.0 seat-brief block).
engine is the version of ENGINE_TIMELINE in force at the seat's first timestamp (the stamp the graph lead
applied; evidence lines in engine-timeline.md). Then prints rows grouped by (kind, step, engine).
Exit 0, 2 on no seats.
"""
import glob, importlib.util, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("count", os.path.join(HERE, "..", "..", "bl550-missing-path-counter", "count.py"))
count = importlib.util.module_from_spec(spec)
spec.loader.exec_module(count)

# (effective-from UTC, version). A stamp is effective from the record that wrote it; see engine-timeline.md.
ENGINE_TIMELINE = [
    ("2026-11-12T12:33:00Z", "0.1101.0"),
    ("2026-11-14T14:26:24Z", "0.1128.0"),
    ("2026-11-15T23:11:54Z", "0.1142.0"),
    ("2026-11-16T13:36:48Z", "0.1143.0"),
    ("2026-11-16T18:12:15Z", "0.1157.0"),
    ("2026-11-16T22:12:02Z", "0.1160.0"),
    ("2026-11-18T01:43:13Z", "0.1164.0"),
    ("2026-11-19T08:32:00Z", "0.1167.0"),
    ("2026-11-19T12:01:46Z", "0.1174.0"),
]


def engine_at(ts):
    t = count.instant(ts)
    cur = None
    for frm, ver in ENGINE_TIMELINE:
        if count.instant(frm) <= t:
            cur = ver
    return cur


def main(argv):
    args = list(argv)
    root = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
    if "--root" in args:
        i = args.index("--root")
        root = args[i + 1]
        del args[i:i + 2]
    if len(args) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    start, end = count.instant(args[0]), count.instant(args[1])
    bad = [0]
    rows = []
    for m in sorted(glob.glob(os.path.join(root, "*", "subagents", "*.meta.json"))):
        p = m[:-len(".meta.json")] + ".jsonl"
        if not os.path.exists(p):
            continue
        t0 = count.first_ts(p, bad)
        if not t0 or not (start <= count.instant(t0) < end):
            continue
        import json
        meta = json.load(open(m))
        prompt = count.first_prompt(p, bad)
        kind, step = count.classify(meta, prompt)
        if kind is None:
            continue
        n = len(list(count.scan(p, end, bad)))
        rows.append((os.path.basename(p)[:-6], t0, kind, step, n, 1 if "cited-paths:" in prompt else 0, engine_at(t0)))
    if not rows:
        return 2
    with open(args[2], "w") as out:
        for r in rows:
            out.write("\t".join(str(x) for x in r) + "\n")
    g = defaultdict(lambda: [0, 0, 0, "9", ""])
    for tr, t0, kind, step, n, cited, eng in rows:
        k = (kind, step, eng)
        v = g[k]
        v[0] += 1; v[1] += n; v[2] += cited
        v[3] = min(v[3], t0) if v[4] else t0
        v[4] = max(v[4], t0)
    for (kind, step, eng), v in sorted(g.items()):
        print("%-13s %-22s %s seats=%d lines=%d with_cited_paths=%d first=%s last=%s" % (kind, step, eng, v[0], v[1], v[2], v[3], v[4]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
