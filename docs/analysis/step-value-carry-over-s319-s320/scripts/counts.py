"""CRITICAL/MAJOR/MINOR heading counts per carry-over round, and s320 `route` rows (BL-813).

Usage: python3 -I counts.py <graph-root> <extract-out-dir>
  <graph-root>       the graph checkout (read only), e.g. ~/git/graph
  <extract-out-dir>  output directory of pipeline-efficiency-s317-s320/scripts/extract.py
"""
import re, glob, os, sys, json, collections
G = sys.argv[1].rstrip("/") + "/_bmad-output"
OUT = sys.argv[2]
# 1) route-step rows in s320 that belong to coe
rows = [json.loads(l) for l in open(OUT + "/spawns.jsonl")]
print("== s320 'route' rows (all)")
for r in rows:
    if r["sprint"] == 320 and r["step"] == "route":
        print("  ", r.get("role"), str(r.get("start"))[:16], round(r.get("usd") or 0, 2), r.get("description"))
print("== s319 'route' rows count", sum(1 for r in rows if r["sprint"] == 319 and r["step"] == "route"))

HEAD = re.compile(r"^#{2,4}\s.*?\b(CRITICAL|MAJOR|MINOR)\b", re.I)
def count(paths):
    c = collections.Counter(); per = {}
    for p in paths:
        pc = collections.Counter()
        for l in open(p, errors="replace"):
            m = HEAD.match(l)
            if m: pc[m.group(1).upper()] += 1
        per[os.path.basename(p)] = dict(pc); c.update(pc)
    return c, per

sets = {
 "s319 party part": sorted(set(glob.glob(G+"/party-mode/s319/carry-over-evaluation-*-[0-9].md"))),
 "s319 party cross": sorted(glob.glob(G+"/party-mode/s319/carry-over-evaluation-*-cross-*.md")),
 "s319 elic part": sorted(glob.glob(G+"/planning-artifacts/s319/shards/carry-over-evaluation-elicitation/[0-9].md")),
 "s319 elic cross": sorted(glob.glob(G+"/planning-artifacts/s319/shards/carry-over-evaluation-elicitation/cross-*.md")),
 "s319 adv p1 part": sorted(glob.glob(G+"/planning-artifacts/s319/shards/coe-p1/[0-9].md")),
 "s319 adv p1 cross": sorted(glob.glob(G+"/planning-artifacts/s319/shards/coe-p1/cross-*.md")),
 "s320 party part": sorted(glob.glob(G+"/party-mode/s320/carry-over-evaluation-*-[0-9].md")),
 "s320 party cross": sorted(glob.glob(G+"/party-mode/s320/carry-over-evaluation-*-cross-*.md")),
 "s320 elic part": sorted(glob.glob(G+"/planning-artifacts/s320/shards/coe-elicitation/[0-9].md")),
 "s320 elic cross": sorted(glob.glob(G+"/planning-artifacts/s320/shards/coe-elicitation/cross-*.md")),
}
for p in (1, 2, 3):
    sets[f"s320 adv p{p} part"] = sorted(glob.glob(G+f"/planning-artifacts/s320/shards/coe-p{p}/[0-9].md"))
    sets[f"s320 adv p{p} cross"] = sorted(glob.glob(G+f"/planning-artifacts/s320/shards/coe-p{p}/cross-*.md"))
for k, ps in sets.items():
    c, per = count(ps)
    print(f"{k:20s} files={len(ps):3d} C={c['CRITICAL']:3d} M={c['MAJOR']:3d} m={c['MINOR']:3d}")
# provenance-block counts for adversarial shards as a cross-check
PB = re.compile(r"^findings_(critical|major):\s*(\d+)")
for k, ps in sets.items():
    if "adv" not in k and "elic" not in k: continue
    c = collections.Counter()
    for p in ps:
        for l in open(p, errors="replace"):
            m = PB.match(l)
            if m: c[m.group(1)] += int(m.group(2))
    print(f"  provenance {k:20s} C={c['critical']} M={c['major']}")
