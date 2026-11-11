"""Raw per-shard yield of stories elicitation (BL-811): CRITICAL+MAJOR finding headings and subagent dollars per shard type.

usage: python3 elicitation_yield.py <OUT dir holding spawns.jsonl> [<graph repo>] [--ref <graph ref for s321>]

The s321 shards are read at --ref (default da6cadadd), never at a moving HEAD. Read-only: `git show` of committed graph shard files, and <OUT>/spawns.jsonl. Writes nothing.

This is the MECHANICAL half of docs/analysis/step-value-stories-elicitation-s319-s320.md (its "Yield" table columns C/M, and
its "Cost" table dollars). It does NOT classify REFOUND, REPAIR-INTRODUCED or UNIQUE-SURVIVED: those are manual judgments in
that document and no script for them is committed, so a unique-survivor count or a "$ per survivor" is not produced here.
C/M = every `### ` heading in a shard file that carries the whole word CRITICAL or MAJOR.
Dollars = the round's `adversary` spawns whose description contains "licit", split by "cross" in the description, at the
rates spawns.py applied; a round is a [start, end) window on the spawn start time (UTC).
Controls printed beside every case: the document's own C/M and dollar figures for s319 r1 and r2.
"""
import json, os, re, subprocess, sys

G_DEFAULT = os.path.expanduser("~/git/graph")
REF_DEFAULT = "da6cadadd"
D = "_bmad-output/planning-artifacts/%s/shards/stories-elicitation"
# label, sprint, graph ref, shard dir, window start, window end, document figures {type: (C/M, dollars)} or None
CASES = [
    ("s319 r1", 319, "91d0e2f65", D % "s319", "2026-10-20T00:00:00", "2026-10-20T12:00:00", {"per-story": (54, 40.89), "cross": (14, 32.19)}),
    ("s319 r2", 319, "7abfe3b9e", D % "s319", "2026-10-20T22:00:00", "2026-10-21T06:00:00", {"per-story": (22, 34.58), "cross": (4, 18.94)}),
    ("s321", 321, None, D % "s321", "2026-01-01T00:00:00", "2099-01-01T00:00:00", None),
]
HEAD = re.compile(r"^### .*\b(CRITICAL|MAJOR)\b")

def git(g, *a):
    return subprocess.run(["git", "-C", g] + list(a), capture_output=True, text=True, check=True).stdout

def main():
    if len(sys.argv) < 2:
        sys.exit("usage: elicitation_yield.py <OUT dir> [<graph repo>]")
    argv = list(sys.argv); s321_ref = REF_DEFAULT
    if "--ref" in argv:
        i = argv.index("--ref"); s321_ref = argv[i + 1]; del argv[i:i + 2]
    out = argv[1]; g = argv[2] if len(argv) > 2 else G_DEFAULT
    rows = [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]
    for label, sprint, ref, sdir, w0, w1, doc in CASES:
        ref = ref or s321_ref
        files = [f for f in git(g, "ls-tree", "--name-only", ref, sdir + "/").split("\n") if f.endswith(".md")]
        if not files:
            sys.exit("no shard files for %s at %s" % (label, ref))
        cm = {"per-story": 0, "cross": 0}; nsh = {"per-story": 0, "cross": 0}; per = {}
        for f in files:
            t = "cross" if os.path.basename(f).startswith("cross") else "per-story"
            n = sum(1 for ln in git(g, "show", "%s:%s" % (ref, f)).split("\n") if HEAD.match(ln))
            cm[t] += n; nsh[t] += 1; per[os.path.basename(f)] = n
        usd = {"per-story": 0.0, "cross": 0.0}; ns = {"per-story": 0, "cross": 0}
        for r in rows:
            d = r.get("description") or ""
            if int(r["sprint"]) != sprint or r["role"] != "adversary" or "licit" not in d or r["step"] not in ("stories-test-strategy", "gate-validation[stories-test-strategy]"): continue
            if not (w0 <= r["start"][:19] < w1): continue
            t = "cross" if "cross" in d.lower() else "per-story"
            usd[t] += r.get("usd") or 0; ns[t] += 1
        for t in ("per-story", "cross"):
            line = "%s %-9s shards %2d  spawns %2d  C/M %3d  $%7.2f  $/CM %s" % (label, t, nsh[t], ns[t], cm[t], usd[t], ("%.2f" % (usd[t] / cm[t])) if cm[t] else "n/a")
            if doc: line += "   | document: C/M %d  $%.2f  %s" % (doc[t][0], doc[t][1], "MATCH" if (cm[t] == doc[t][0] and abs(usd[t] - doc[t][1]) < 0.5) else "DIFFERS")
            print(line)
        if not doc:
            print("  per-shard C/M:", per)

main()
