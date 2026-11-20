# m2_escalations.py -- BL-972 item 1 (work item 5): count graph's Tier 2 DECIDED_AUTONOMOUSLY entries dated within s323
# and the entries whose Decision/Question line opens `source: recommendation`.
# usage: python3 -I m2_escalations.py <graph-repo> <sha> <window-start-iso> <window-end-iso>
# s323 = [2026-11-13T08:00:00Z, 2026-11-20T04:20:00Z) (extract.py EDGES). Reads git objects only.
import re, subprocess, sys
repo, sha, w0, w1 = sys.argv[1:5]
def show(p): return subprocess.run(["git", "-C", repo, "show", "%s:%s" % (sha, p)], capture_output=True, text=True, check=True).stdout
def show_at(rev, p): return subprocess.run(["git", "-C", repo, "show", "%s:%s" % (rev, p)], capture_output=True, text=True).stdout
tot = {}
for f in ("docs/escalations/pending.md", "docs/escalations/pending-archive.md"):
    txt = show(f)
    parts = re.split(r"(?m)^(?=## )", txt)
    da = [p for p in parts if p.startswith("## ") and "DECIDED_AUTONOMOUSLY" in p.split("\n", 1)[0]]
    inwin = []
    for p in da:
        h = p.split("\n", 1)[0]
        m = re.search(r"(2026-\d\d-\d\d)(T\d\d:\d\d:\d\dZ)?\s*$", h)
        if not m: continue
        d = m.group(1) + (m.group(2) or "T00:00:00Z")
        if w0 <= d < w1: inwin.append((d, h, p))
    tagged = [x for x in inwin if re.search(r"(?m)^\*\*Decision/Question:\*\*\s*source: recommendation", x[2])]
    anywhere = len(re.findall(r"source: recommendation", txt))
    print("%s @ %s: %d lines, %d headings with DECIDED_AUTONOMOUSLY (all dates; CONTROL non-zero), %d dated in s323, %d open Decision/Question with `source: recommendation`, `source: recommendation` anywhere in file %d" % (f, sha[:9], txt.count("\n"), len(da), len(inwin), len(tagged), anywhere))
    for d, h, p in inwin: print("  %s  %s" % (d, re.sub(r"^## ", "", h)[:110]))
    tot[f] = len(inwin)
print("TOTAL Tier 2 DECIDED_AUTONOMOUSLY entries dated in s323:", sum(tot.values()))
# when did the tagging rule reach graph: the sha that first carries it in graph's installed SKILL.md
out = subprocess.run(["git", "-C", repo, "log", "--format=%h %aI %s", "-S", "source: recommendation", "--", ".claude/skills/ai-dlc/SKILL.md"], capture_output=True, text=True).stdout.strip()
print("first graph commit carrying `source: recommendation` in .claude/skills/ai-dlc/SKILL.md:", out[:150])
