"""Classify every s320 carry-over elicitation/adversarial MAJOR+ by where its quoted text first appears.

Usage: python3 -I cls.py <graph-root> <revs-dir> <out.json>
  <graph-root>  the graph checkout (read only); shard records are read from its _bmad-output/
  <revs-dir>    a directory holding the evaluation revisions under these names:
                  s320-r0-analyst-final.md        analyst draft (reconstructed from the analyst's writes)
                  s320-r1-post-party-repair.md    graph blob 2a209ae17ea51182f5f092405eaf99f7b6f6ddf0
                  s320-r2-post-elic-repair.md     graph blob c7318d0f12ef998c2b32aa63b928060016fc9465
                  s320-r3-post-p1-serial-repair.md graph blob a4010b9891ee2c14e113cb045133e53999adb972
                  s320-r4-SHIPPED.md              graph blob 1106438812b568edbd549e53f41f00506919f267
                (`git -C <graph-root> cat-file -p <blob> > <revs-dir>/<name>`)
Classes: PRESENT-IN-PRIOR (MISSED-BY-PRIOR), NEW-SINCE-PRIOR (REPAIR-INTRODUCED),
NOQUOTE-IN-REVIEWED (no quote located in the reviewed revision).
"""
import re, glob, os, json, sys, collections
G = sys.argv[1].rstrip("/") + "/_bmad-output"
B = sys.argv[2]
OUTF = sys.argv[3]
rd = lambda n: open(f"{B}/{n}", errors="replace").read()
R = {k: rd(v) for k, v in dict(r0="s320-r0-analyst-final.md", r1="s320-r1-post-party-repair.md", r2="s320-r2-post-elic-repair.md",
     r3="s320-r3-post-p1-serial-repair.md", r4="s320-r4-SHIPPED.md").items()}
norm = lambda s: re.sub(r"\s+", " ", s)
RN = {k: norm(v) for k, v in R.items()}
rounds = {
  "elic": (G+"/planning-artifacts/s320/shards/coe-elicitation", "r1", "r0"),
  "p1": (G+"/planning-artifacts/s320/shards/coe-p1", "r2", "r1"),
  "p2": (G+"/planning-artifacts/s320/shards/coe-p2", "r3", "r2"),
  "p3": (G+"/planning-artifacts/s320/shards/coe-p3", "r4", "r3"),
}
HEAD = re.compile(r"^#{2,4}\s+(.*?)\b(CRITICAL|MAJOR)\b", re.I)
ANY = re.compile(r"^#{1,4}\s")
QUOTE = re.compile(r'"([^"\n]{18,200})"|“([^”\n]{18,200})”')
out = []
for rnd, (d, rev, prior) in rounds.items():
    for f in sorted(glob.glob(d + "/*.md")):
        lines = open(f, errors="replace").read().split("\n")
        i = 0
        while i < len(lines):
            m = HEAD.match(lines[i])
            if not m: i += 1; continue
            j = i + 1
            while j < len(lines) and not ANY.match(lines[j]): j += 1
            body = "\n".join(lines[i:j])
            qs = [a or b for a, b in QUOTE.findall(body)]
            qs = [q.strip() for q in qs if "$ " not in q]
            res = []
            for q in qs[:6]:
                nq = norm(q)
                res.append((q[:60], int(nq in RN[rev]), int(nq in RN[prior]), int(nq in RN["r4"])))
            ins = [r for r in res if r[1]]
            if not ins: cls = "NOQUOTE-IN-REVIEWED"
            elif any(r[2] for r in ins): cls = "PRESENT-IN-PRIOR"
            else: cls = "NEW-SINCE-PRIOR"
            out.append(dict(rnd=rnd, shard=os.path.basename(f), head=lines[i][:110], cls=cls, q=res))
            i = j
json.dump(out, open(OUTF, "w"), indent=1)
c = collections.Counter((o["rnd"], "cross" if o["shard"].startswith("cross") else "part", o["cls"]) for o in out)
for k in sorted(c): print(k, c[k])
print("control r0 len", len(R["r0"]), "r4 len", len(R["r4"]))
