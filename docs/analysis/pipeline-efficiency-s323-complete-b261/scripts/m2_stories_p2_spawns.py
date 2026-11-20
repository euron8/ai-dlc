# m2_stories_p2_spawns.py -- list s323 stories-test-strategy adversary spawns after 2026-11-18T08:00Z, to find the 20th stories-p2 spawn
# (transcript count 20 against the 19 shards in stories-adversarial-p2.md's provenance).
# usage: python3 -I m2_stories_p2_spawns.py <extract OUT dir with spawns.jsonl>
import json, os, sys
rows = [json.loads(l) for l in open(os.path.join(sys.argv[1], "spawns.jsonl"))]
print("fields:", sorted(rows[0].keys()))
sel = [r for r in rows if r.get("sprint") == 323 and r.get("role") == "adversary" and r.get("step", "").startswith("stories-test-strategy")]
print("s323 stories-test-strategy adversary spawns:", len(sel))
for r in sorted(sel, key=lambda r: r.get("start", "")):
    if r.get("start", "") >= "2026-11-18T07:30": print(r.get("start", "")[:19], r.get("end", "")[:19], (r.get("desc") or r.get("description") or "")[:70])
