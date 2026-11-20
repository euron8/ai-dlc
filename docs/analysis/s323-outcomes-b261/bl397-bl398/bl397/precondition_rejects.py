"""BL-397: count QA Handoff Evidence Precondition citations and rejects per sprint, read-only over a graph clone.

Usage: python3 precondition_rejects.py <graph-clone> <ref> [sprint ...]   (default sprints 315 317 318 319 320 321 322)

Population: the primary QA reports, docs/reviews/s<N>/*qa*.md at <ref>, any depth, excluding every path with a
`shards/` component. This is the population and filter of BL-397's b255 "Value evidence searched" paragraph.
A report CITES the precondition when some line names `Handoff Evidence Precondition` in any letter case. A report
REJECTS on it when such a line also carries one of REJECT_WORDS after the NEAR_MISS phrases are removed from it.
`reject` matches in any case (s317 2-6:191 "process rejects" is one of b255's seven); every other word is
case-SENSITIVE, so `failed 0` in a count line and `xfail` are not rejects. That case rule is the one that
reproduces b255 exactly; b255's text did not state it.

The counts are read from QA report TEXT, never from extract.py's step labels, so BL-1003 (an unclosed gate
charging later spawns to gate-validation[<step>]) cannot move them.

Controls printed in the same run:
  positive   s317..s321 must reproduce b255: rejects 7, 0, 0, 2, 1; citing 23/27, 13/19, 33/43, 23/30, 26/46.
             Any mismatch prints REPRODUCE-MISMATCH and the script exits 3.
  near-miss  s319 2-2-qa-validation.md carries "not a REJECT" on a precondition line and must NOT be a reject.
  zero       s315 must cite 0 (the heading did not exist before 0.674.0), beside s315's non-zero report count.
"""
import re, subprocess, sys

G, REF = sys.argv[1], sys.argv[2]
SPRINTS = [int(x) for x in sys.argv[3:]] or [315, 317, 318, 319, 320, 321, 322]
B255 = {317: (7, 23, 27), 318: (0, 13, 19), 319: (0, 33, 43), 320: (2, 23, 30), 321: (1, 26, 46)}
HEAD = "Handoff Evidence Precondition"
REJECT_WORDS = re.compile(r"(?i:reject)|NEEDS_REWORK|FAIL|not met|unmet|absent|rejected|bare heading|empty body|still fail")
NEAR_MISS = re.compile(r"not a REJECT|do not reject", re.I)

def git(*a):
    return subprocess.run(["git", "-C", G] + list(a), capture_output=True, text=True, errors="replace").stdout

def reports(n):
    names = git("ls-tree", "-r", "--name-only", REF, f"docs/reviews/s{n}/").split("\n")
    return sorted(p for p in names if p and "qa" in p.rsplit("/", 1)[-1] and p.endswith(".md") and "/shards/" not in p)

def classify(text):
    cites = False; rej = []
    for i, ln in enumerate(text.split("\n"), 1):
        if HEAD.lower() not in ln.lower(): continue
        cites = True
        if REJECT_WORDS.search(NEAR_MISS.sub("", ln)): rej.append(i)
    return cites, rej

bad = 0; near_seen = False
print(f"graph ref {REF}; population docs/reviews/s<N>/**/*qa*.md outside shards/")
for n in SPRINTS:
    rs = reports(n); cite = 0; rejs = []
    for p in rs:
        t = git("show", f"{REF}:{p}")
        c, r = classify(t)
        cite += c
        if r: rejs.append(p.rsplit("/", 1)[-1] + ":" + ",".join(map(str, r)))
        if n == 319 and p.endswith("/2-2-qa-validation.md"):
            near = [i for i, ln in enumerate(t.split("\n"), 1) if HEAD.lower() in ln.lower() and NEAR_MISS.search(ln)]
            near_seen = bool(near)
            print(f"  near-miss control s319 2-2-qa-validation.md: precondition lines carrying a near-miss phrase {near}; counted as reject: {bool(r)}")
            if r or not near: bad += 1; print("  NEAR-MISS-CONTROL-FAILED")
    print(f"s{n}: reports {len(rs)}, citing {cite}/{len(rs)}, rejects {len(rejs)}" + (f" ({'; '.join(rejs)})" if rejs else ""))
    if n in B255 and (len(rejs), cite, len(rs)) != B255[n]:
        bad += 1; print(f"  REPRODUCE-MISMATCH s{n}: b255 rejects {B255[n][0]}, citing {B255[n][1]}/{B255[n][2]}")
    if n == 315 and (cite != 0 or len(rs) == 0):
        bad += 1; print("  ZERO-CONTROL-FAILED: s315 must cite 0 of a non-empty report set")
if 319 in SPRINTS and not near_seen: bad += 1
sys.exit(3 if bad else 0)
