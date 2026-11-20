# gate_qa_s323.py -- BL-1141 part 2: per story, the gate-1 code-review verdict and the gate QA verdict on s323.
# usage: python3 -I gate_qa_s323.py <graph clone checked out at the s323 close> > gate_qa_s323.txt
# Reads <clone>/docs/reviews/s323/*.md (tracked files). Verdict = the first PASS / APPROVED / NEEDS_REWORK /
# CHANGES_REQUESTED / BLOCKED token on the line after a "## Verdict" heading, else the first `Verdict:` or
# `shard-verdict:` line (sharded stories: the worst shard verdict, cross shard included, read from shards/<dir>/*.md).
# A story is REWORKED-AFTER-QA when a -p2 QA file exists. Severity counts are the lines of the form
# "- **Critical" / "**Finding (Critical" etc. are NOT counted (free prose); the QA verdict is the reading.
import glob, os, re, sys
R = os.path.join(sys.argv[1], "docs", "reviews", "s323")
TOK = re.compile(r"\b(NEEDS_REWORK|CHANGES_REQUESTED|BLOCKED|REJECTED|PASS|APPROVED)\b")
def verdict(path):
    t = open(path, errors="replace").read()
    m = re.search(r"^## Verdict\s*\n+(.*)", t, re.M)
    if m:
        k = TOK.search(m.group(1))
        if k: return k.group(1)
    for rx in (r"^\**shard-verdict:?\**\s*(\S+)", r"^\**Verdict:?\**\s*\**(\S+?)\**\b"):
        m = re.search(rx, t, re.M | re.I)
        if m:
            k = TOK.search(m.group(1))
            if k: return k.group(1)
    k = TOK.search(t)
    return k.group(1) if k else "?"
def shard_dirs(story, kind):
    return sorted(glob.glob(os.path.join(R, "shards", story + "-" + kind + "-*")))
def worst(vs):
    for bad in ("BLOCKED", "REJECTED", "NEEDS_REWORK", "CHANGES_REQUESTED"):
        if bad in vs: return bad
    return vs[0] if vs else "-"
stories = sorted({re.match(r"(\d+-\d+)-", os.path.basename(p)).group(1) for p in glob.glob(os.path.join(R, "*-*-qa-validation*.md")) + glob.glob(os.path.join(R, "*-*-code-review*.md")) if re.match(r"\d+-\d+-", os.path.basename(p))})
print("story\tcode-review p1\tQA p1\tQA p2 exists\tcode-review p2 exists")
n_rework_qa = 0
for s in stories:
    out = {}
    for kind, key in (("code-review", "cr"), ("qa-validation", "qa")):
        f = os.path.join(R, "%s-%s.md" % (s, kind))
        vs = []
        if os.path.exists(f): vs.append(verdict(f))
        for d in shard_dirs(s, kind):
            if d.endswith("-p2") or "-p2" in os.path.basename(d): continue
            for sf in sorted(glob.glob(d + "/*.md")): vs.append(verdict(sf))
        out[key] = worst(vs) if vs else "-"
    q2 = os.path.exists(os.path.join(R, "%s-qa-validation-p2.md" % s)) or any("-p2" in os.path.basename(d) for d in shard_dirs(s, "qa-validation"))
    c2 = os.path.exists(os.path.join(R, "%s-code-review-p2.md" % s))
    n_rework_qa += out["qa"] in ("NEEDS_REWORK", "CHANGES_REQUESTED", "BLOCKED")
    print("%s\t%s\t%s\t%s\t%s" % (s, out["cr"], out["qa"], "yes" if q2 else "no", "yes" if c2 else "no"))
print("stories listed", len(stories), "QA p1 NEEDS_REWORK-class", n_rework_qa)
