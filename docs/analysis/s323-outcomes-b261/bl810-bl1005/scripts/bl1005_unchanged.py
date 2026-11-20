"""BL-1005 reading: stories adversarial shards whose artifact_sha equals the same ordinal's in the prior pass.

usage: python3 -I bl1005_unchanged.py <graph clone> <ref> <sprint> [<spawns.jsonl>]

Same comparison as adversarial_yield.py:355-361 (cross.md excluded; shard file equal on `artifact_sha:`), same C/M
heading rule (HEAD, adversarial_yield.py:48). Cost per shard is read from spawns.jsonl by the description pattern
"Pass N shard K" (or, when none matches, printed as UNMATCHED so a zero cannot hide a description change).
Read-only; writes nothing.
"""
import json, os, re, subprocess, sys

HEAD = re.compile(r"^### .*\b(CRITICAL|MAJOR)\b")
g, ref, sprint = sys.argv[1], sys.argv[2], sys.argv[3]
spawns = sys.argv[4] if len(sys.argv) > 4 else None
P = "_bmad-output/planning-artifacts/s%s" % sprint

def git(*a):
    return subprocess.run(["git", "-C", g] + list(a), capture_output=True, check=True).stdout.decode("utf-8", "replace")

def shards(p):
    d = "%s/shards/stories-p%d" % (P, p)
    out = {}
    for n in git("ls-tree", "--name-only", ref, d + "/").split("\n"):
        if n.endswith(".md"):
            out[os.path.basename(n)] = git("show", "%s:%s" % (ref, n))
    return out

rows = []
if spawns:
    for l in open(spawns):
        r = json.loads(l)
        if int(r["sprint"]) == int(sprint) and r["step"] == "stories-test-strategy":
            rows.append(r)
PASS_RE = re.compile(r"^Pass (\d) (cross )?shard(?: (\d+))?")
# s323 spelling: "Adversary shard NN", "Adversary cross shard", "Adversary shard cross", pass = the n-th occurrence of
# the shard key in start order (s323 dispatched each pass as one wave); "p2 adversary shard NN re-run" is a re-dispatch
# and is not counted as a pass read (printed separately).
ADV_RE = re.compile(r"^Adversary (?:(cross) shard|shard (cross|\d+))$")
cost = {}; seen = {}; rerun = []
for r in sorted(rows, key=lambda r: r["start"]):
    d = r.get("description") or ""
    m = PASS_RE.match(d)
    if m:
        k = (int(m.group(1)), "cross.md" if m.group(2) else "%02d.md" % int(m.group(3)))
    else:
        m = ADV_RE.match(d)
        if not m:
            if re.match(r"^p\d adversary shard", d): rerun.append((d, r.get("usd"), r.get("minutes")))
            continue
        f = "cross.md" if (m.group(1) or m.group(2) == "cross") else "%02d.md" % int(m.group(2))
        seen[f] = seen.get(f, 0) + 1; k = (seen[f], f)
    c = cost.setdefault(k, [0, 0.0, 0.0]); c[0] += 1; c[1] += r.get("usd") or 0; c[2] += r.get("minutes") or 0
if rerun: print("re-dispatches (not pass reads):", rerun)
for p in (1, 2, 3):
    ks = [k for k in cost if k[0] == p]
    if ks: print("spawn cost pass %d: %d shard rows (incl cross) $%.2f %.2f spawn-hours" % (p, len(ks), sum(cost[k][1] for k in ks), sum(cost[k][2] for k in ks) / 60))

prev = None; tot = [0, 0.0, 0.0, 0, 0]
for p in (1, 2, 3):
    sh = shards(p)
    if not sh:
        print("p%d: no shards at %s" % (p, ref)); prev = None; continue
    shas = {f: (re.search(r"^artifact_sha: (\S+)", t, re.M) or [None, None])[1] for f, t in sh.items()}
    cm = {f: sum(1 for l in t.split("\n") if HEAD.match(l)) for f, t in sh.items()}
    n_part = sum(1 for f in sh if f != "cross.md")
    print("p%d: %d part shards, %d with a sha, C/M total %d, spawn rows matched %d" % (
        p, n_part, sum(1 for f in sh if f != "cross.md" and shas[f]), sum(cm.values()), sum(1 for k in cost if k[0] == p)))
    if prev is not None:
        same = sorted(f for f in sh if f != "cross.md" and shas.get(f) and shas[f] == prev.get(f))
        u = sum(cost.get((p, f), [0, 0, 0])[1] for f in same)
        mi = sum(cost.get((p, f), [0, 0, 0])[2] for f in same)
        miss = [f for f in same if (p, f) not in cost]
        c = sum(cm[f] for f in same)
        print("   p%d shards on the same bytes as p%d: %d of %d: %s | $%.2f, %.2f spawn-hours (sum of spawn minutes) | C/M %d%s" % (
            p, p - 1, len(same), n_part, ",".join(same), u, mi / 60, c,
            ("| UNMATCHED cost for %s" % miss) if (spawns and miss) else ""))
        tot[0] += len(same); tot[1] += u; tot[2] += mi; tot[3] += c; tot[4] += n_part
    prev = shas
print("TOTAL p2+p3 unchanged shard reads %d of %d, $%.2f, %.2f spawn-hours, C/M %d" % (tot[0], tot[4], tot[1], tot[2] / 60, tot[3]))
