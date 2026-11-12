"""BL-1016: how many s317..s322 handoffs record a `Full-collection run:` that is not a repo-root full collection.

Usage: python3 handoff_runs.py <graph-clone> [ref]      (ref default ed61de745; read only)

Population: every PRIMARY QA report docs/reviews/s<N>/<story>-qa-validation.md (no `-p<k>` pass suffix, outside
shards/) at <ref>, N in 317..322, joined to its story file _bmad-output/planning-artifacts/s<N>/stories/story-<story>-*.md
(s322 reports are named `<M>-qa-validation.md` for story 1.<M>). The story file is read at the HANDOFF SHA: the first
40-hex sha in the report's first 60 lines that names a commit in the clone (the go-signal / reviewed-sha line), else
the commit that first added the report (method printed per story as `sha` or `add`).

Reports whose name is not a story key (sprint-review fixes, party fixes, `-ff`) are counted as NOT-A-STORY-REPORT.
The handoff sha prefers a sha on a go-signal / reviewed-sha / frozen / HEAD / range line (the right side of a range).
The record: the LAST line of that file matching RECORD (dev.md's column-0 `Full-collection run:` or the earlier bullet
form `- Full-collection run, cwd ...`), joined with the next two lines when it has no backticked span. Its invocation
is its first backticked span, else the text before " (", " from " or ", ". Classification (dev.md: "repo root, full
collection, no test-name filter, marker filter or deselect"):
  NONE-CLAIM   `Full-collection run: none, ...`
  COLLECT-ONLY --collect-only / --co (runs no test)
  NON-PYTEST   no pytest invocation (a bash harness): not judged, counted apart
  PARTIAL      a pytest invocation naming a .py file or node id, or carrying -k, -m or --deselect
  FULL         any other pytest invocation (a directory such as rebalancer/tests, or none); a footprint-watchdog
               wrapper is judged on the arguments after its ` -- `
"Not a repo-root full collection" = PARTIAL + COLLECT-ONLY.
Cruder than core's RUN-FILTER (core/scripts/record-only-diff.sh run-filter): any `-m` is PARTIAL here, with no read of
the project's coding conventions. graph declares one `-m` run canonical (the repo-root `-m unit` run); none of the
s317..s322 PARTIAL rows is that run, so the crudeness moves no count on this population.

Controls (same run; exit 3 on failure):
  positive  s322 story 1.8 (watchdog `... -- -n 8 -q --tb=short`) must read FULL
  known     s322 story 1.3 (three named server test files; docs/reviews/s322/3-qa-validation.md:14) must read PARTIAL
  synthetic classify() on `pytest -m "not integration" server/tests` reads PARTIAL, on `pytest rebalancer/tests -n 8`
            reads FULL
"""
import collections, re, subprocess, sys

G = sys.argv[1]; REF = sys.argv[2] if len(sys.argv) > 2 else "ed61de745"
INVOKED = re.compile(r"-m\s+pytest\b|(^|[;&|(\s/])pytest(\s|$)|watchdog\.py\s")

HANDOFF_LINE = re.compile(r"go-signal|reviewed-sha|frozen|HEAD|[0-9a-f]\.\.[0-9a-f]", re.I)
# The record line: column-0 `Full-collection run:` (dev.md's current form) or the earlier bullet form
# `- Full-collection run, cwd ...` / `- Pass-2 full-collection run ...`. The LAST such line is the handoff's record.
RECORD = re.compile(r"^(- )?(\*\*)?(Pass-\d+ )?[Ff]ull-collection run\b")

def record(L, i):
    """The record line, joined with the next four lines when it carries no pytest invocation itself (the older
    bullet form puts the command in a fenced block or on the following line)."""
    line = L[i]
    if not INVOKED.search(line) and not re.search(r":\s*none\b", line, re.I):
        line = line + " " + " ".join(L[i + 1:i + 5])
    return line

def git(*a): return subprocess.run(["git", "-C", G] + list(a), capture_output=True, text=True, errors="replace").stdout

def invocation(line):
    """The first backticked span that invokes pytest; else the raw text from the first pytest invocation to the next
    backtick; else the first backticked span; else the text before " (", " from " or ", "."""
    bt = re.findall(r"`([^`]+)`", line)
    for b in bt:
        if INVOKED.search(b): return b
    m = INVOKED.search(line)
    if m: return line[m.start():].split("`")[0]
    return bt[0] if bt else re.split(r" \(| from |, ", line.split(":", 1)[-1])[0]

def classify(line):
    body = line.split(":", 1)[-1].strip()
    if re.match(r"none\b", body, re.I): return "NONE-CLAIM"
    inv = invocation(line)
    if re.search(r"--collect-only|(^|\s)--co(\s|$)", inv): return "COLLECT-ONLY"
    if not INVOKED.search(inv): return "NON-PYTEST"
    if "watchdog" in inv and " -- " in inv: args = inv.split(" -- ", 1)[1]
    else:
        m = re.search(r"(?:-m\s+pytest|\bpytest)(?![-\w.])(.*)", inv, re.S); args = m.group(1) if m else ""
    if re.search(r"\S+\.py\b|::|(^|\s)(-k|-m|--deselect)(\s|=|$)", args): return "PARTIAL"
    return "FULL"

bad = 0
for s, want in (('`.venv/bin/python -m pytest -m "not integration" server/tests -q`', "PARTIAL"),
                ("`.venv-ci/bin/python -m pytest rebalancer/tests -q -n 8`", "FULL")):
    got = classify("Full-collection run: " + s); bad += got != want
    print(f"synthetic control {s}: {got} ({'ok' if got == want else 'CONTROL-FAILED'})")
tally = collections.defaultdict(collections.Counter); rows = {}
for n in range(317, 323):
    reps = [p for p in git("ls-tree", "-r", "--name-only", REF, f"docs/reviews/s{n}/").split()
            if p.endswith("-qa-validation.md") and "/shards/" not in p]
    stories = git("ls-tree", "--name-only", REF, f"_bmad-output/planning-artifacts/s{n}/stories/").split()
    for rp in sorted(reps):
        key = rp.rsplit("/", 1)[-1][:-len("-qa-validation.md")]
        if not re.fullmatch(r"\d+(-\d+[a-z]?)?", key): tally[n]["NOT-A-STORY-REPORT"] += 1; continue
        if n == 322: key = "1-" + key
        sf = [p for p in stories if p.rsplit("/", 1)[-1].startswith(f"story-{key}-")]
        if not sf: tally[n]["NO-STORY-FILE"] += 1; continue
        head = git("show", f"{REF}:{rp}").split("\n")[:60]
        cand = [c for l in head if HANDOFF_LINE.search(l) for c in reversed(re.findall(r"\b[0-9a-f]{40}\b", l))]
        cand += [c for l in head for c in re.findall(r"\b[0-9a-f]{40}\b", l)]
        sha = next((c for c in dict.fromkeys(cand) if git("cat-file", "-t", c).strip() == "commit"), None)
        how = "sha"
        if not sha:
            sha = (git("log", "--all", "--diff-filter=A", "--reverse", "--format=%H", "--", rp).split() or [None])[0]; how = "add"
        t = git("show", f"{sha}:{sf[0]}") if sha else ""
        L = t.split("\n")
        ix = [i for i, l in enumerate(L) if RECORD.match(l)]
        line = record(L, ix[-1]) if ix else ""
        k = classify(line) if ix else "NO-LINE"
        tally[n][k] += 1; rows[(n, key)] = (k, how, sha[:9] if sha else "-", invocation(line)[:110] if ix else "")
for (n, key), (k, how, sha, inv) in sorted(rows.items()):
    if k in ("PARTIAL", "COLLECT-ONLY", "NONE-CLAIM") or (n, key) in ((322, "1-8"), (322, "1-3")):
        print(f"  s{n} {key} @{sha} ({how}): {k} :: {inv}")
tot = collections.Counter()
for n in sorted(tally):
    c = tally[n]; tot.update(c)
    print(f"s{n}: " + ", ".join(f"{k} {v}" for k, v in sorted(c.items())))
withline = sum(v for k, v in tot.items() if k not in ("NO-LINE", "NO-STORY-FILE", "NOT-A-STORY-REPORT"))
notfull = tot["PARTIAL"] + tot["COLLECT-ONLY"]
print(f"TOTAL s317..s322: primary QA reports {sum(tot.values())}; with a Full-collection run line {withline}; "
      f"not a repo-root full collection (PARTIAL + COLLECT-ONLY) {notfull}; FULL {tot['FULL']}; NON-PYTEST {tot['NON-PYTEST']}; "
      f"NONE-CLAIM {tot['NONE-CLAIM']}; NO-LINE {tot['NO-LINE']}; NO-STORY-FILE {tot['NO-STORY-FILE']}; NOT-A-STORY-REPORT {tot['NOT-A-STORY-REPORT']}")
for key, want in (("1-8", "FULL"), ("1-3", "PARTIAL")):
    got = rows.get((322, key), ("MISSING",))[0]; bad += got != want
    print(f"control s322 story {key}: {got} ({'ok' if got == want else 'CONTROL-FAILED'})")
sys.exit(3 if bad else 0)
