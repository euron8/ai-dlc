"""Cross-agent spawns per story, per sprint (BL-811).

usage: python3 cross_spawns.py <OUT dir holding spawns.jsonl> [--broad]

Reads <OUT>/spawns.jsonl (written by pipeline-efficiency-s317-s318/scripts/spawns.py) and nothing else; writes nothing.

Default population (the BL-811 entry's regex, case-insensitive): description matches
  cross g\\d|cross-\\d|cross shard|cross-part|cross-story|cross/|cross remediator
and not cross-section|cross seat. It is a floor: a description naming no such token is not counted.
--broad: any description containing "cross", less cross-section and cross seat.
STORIES is roll.py's, imported so the two cannot drift.
"""
import json, os, re, sys, collections

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
from roll import STORIES   # roll.py owns STORIES; it runs nothing on import

INC = re.compile(r"cross g\d|cross-\d|cross shard|cross-part|cross-story|cross/|cross remediator", re.I)
EXC = re.compile(r"cross-section|cross seat", re.I)

args = [a for a in sys.argv[1:] if a != "--broad"]
broad = "--broad" in sys.argv[1:]
if len(args) != 1:
    sys.exit("usage: cross_spawns.py <OUT dir> [--broad]")
path = os.path.join(args[0], "spawns.jsonl")
n = collections.Counter(); usd = collections.Counter(); tot = collections.Counter(); totusd = collections.Counter()
step = collections.defaultdict(collections.Counter)
for line in open(path):
    r = json.loads(line)
    s = int(r["sprint"]); d = r.get("description") or ""
    tot[s] += 1; totusd[s] += r.get("usd") or 0
    hit = ("cross" in d.lower() and not EXC.search(d)) if broad else bool(INC.search(d) and not EXC.search(d))
    if hit:
        n[s] += 1; usd[s] += r.get("usd") or 0; step[s][r.get("step")] += 1
if not tot:
    sys.exit("no rows in " + path)
for s in sorted(STORIES):
    if not tot[s]:
        continue
    print(f"s{s}: spawns {tot[s]} cross {n[s]} per-story {n[s]/STORIES[s]:.2f} usd {usd[s]:.1f} usd/story {usd[s]/STORIES[s]:.2f} share {100*usd[s]/max(totusd[s], 1e-9):.0f}% stories {STORIES[s]} ({'broad' if broad else 'regex'})")
    print("   by step:", dict(step[s]))
