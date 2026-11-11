"""BL-808: findings only one gate-1 shard raised, read from graph's merged code-review records.

usage: python3 -I shard_unique.py <graph-reviews-sprint-dir> [--ref <graph ref>] [--selftest] [--examples]
e.g.   python3 -I shard_unique.py ~/git/graph/docs/reviews/s321
The records are read at a graph ref through `git -C <graph> ls-tree` and `git show <ref>:<path>`, default da6cadadd, so
a figure does not move with graph's working tree. `--ref WORKTREE` globs the directory as it is on disk instead.

A merged review (`# Code Review: <story> (merged from N shards)`) embeds every shard under
`## Shard: part N` / `## Shard: cross` (s319 spells cross groups `cross-N (a,b)`). A finding is a `#### <title>`
heading under a `### Critical` or `### Important` heading (Minor is not classified). Its anchors are the paths on
its `Files:` line plus every `path.ext:NNN` token in its text.

ANCHOR FORM. Anchors are spelled three ways in the records: repo-relative (`rebalancer/main.py`), absolute into
another worktree (`/Users/n8/git/graph-s321-story-3.3/scripts/x.sh`) and a bare basename (`useRewards.js`).
Every anchor is compared by its BASENAME alone, so all three spellings of one file are equal. This is the most
generous join (two files of one basename in different directories also match), so it can only lower the unique
count. The displayed example anchor keeps the spelling the record used.

A finding is RAISED BY ANOTHER SHARD when some finding of a different shard in the same pass shares an anchor
basename with it. It is UNIQUE when no other shard's finding shares one. A finding with no anchor is unscored.
Part shards read disjoint file sets, so a part-shard finding is unique by construction unless a cross shard
touched the same file; the cross shard is the one reader that can raise a duplicate, which is why the output
splits unique findings into part-shard and cross-shard and counts the cross shards. A merged review naming fewer
than 2 shards is serial and is not scored.
Read-only; stdlib only. The result is a count of findings one shard raised alone; it cannot say that a serial
reviewer would have missed them.
"""
import os, re, sys, glob, subprocess, fnmatch

REF_DEFAULT = "da6cadadd"

PATH_RE = re.compile(r"[A-Za-z0-9_./-]+\.(?:py|ts|tsx|js|sol|sh|md|yaml|yml|json|toml|txt)")
LINE_RE = re.compile(r"([A-Za-z0-9_./-]+\.(?:py|ts|tsx|js|sol|sh|md|yaml|yml|json|toml)):(\d+)")


def base(p):
    return p.rstrip("/").split("/")[-1]


def parse(text):
    """-> (shard_names, [finding dict]) ; a finding's `files` holds anchor BASENAMES, `anchor` the first path:line."""
    shard = None; sev = None; out = []; cur = None; names = []
    for l in text.split("\n"):
        m = re.match(r"^## Shard: (.+?)\s*$", l)
        if m:
            shard = m.group(1); names.append(shard); sev = None; cur = None; continue
        if shard is None:
            continue
        m = re.match(r"^### (Critical|Important|Minor)\b", l)
        if m:
            sev = m.group(1); cur = None; continue
        if re.match(r"^##? ", l) or re.match(r"^### ", l):
            sev = None; cur = None; continue
        m = re.match(r"^#### (.+?)\s*$", l)
        if m and sev in ("Critical", "Important"):
            cur = {"shard": shard, "sev": sev, "title": m.group(1), "files": set(), "anchor": "", "path": ""}
            out.append(cur); continue
        if cur is not None:
            m = re.match(r"^Files:\s*(.*)$", l)
            if m:
                for p in PATH_RE.findall(m.group(1)):
                    cur["files"].add(base(p))
                    if not cur["path"]:
                        cur["path"] = p
            for p, n in LINE_RE.findall(l):
                cur["files"].add(base(p))
                if not cur["anchor"]:
                    cur["anchor"] = "%s:%s" % (p, n)
    return names, out


def kind(shard):
    return "cross" if shard.startswith("cross") else "part"


def score(findings):
    for f in findings:
        other = [g for g in findings if g["shard"] != f["shard"] and g["files"] & f["files"]]
        f["unique"] = bool(f["files"]) and not other
        f["noanchor"] = not f["files"]
    return findings


def _git(top, *a):
    return subprocess.run(["git", "-C", top] + list(a), capture_output=True, text=True, check=True).stdout


def _read_set(d, ref):
    """-> [(name, text)] of the *code-review*.md files in d, from the working tree or at a graph ref."""
    if ref == "WORKTREE":
        return [(os.path.basename(p), open(p, encoding="utf-8", errors="replace").read())
                for p in sorted(glob.glob(os.path.join(d, "*code-review*.md")))]
    d = os.path.abspath(d)
    top = _git(d, "rev-parse", "--show-toplevel").strip()
    rel = os.path.relpath(os.path.realpath(d), os.path.realpath(top))
    names = sorted(n for n in _git(top, "ls-tree", "--name-only", ref, rel + "/").split("\n")
                   if n and fnmatch.fnmatch(os.path.basename(n), "*code-review*.md"))
    return [(os.path.basename(n), _git(top, "show", "%s:%s" % (ref, n))) for n in names]


def run(d, ref=REF_DEFAULT):
    rows = []; serial = 0
    for pname, t in _read_set(d, ref):
        p = pname
        m = re.search(r"merged from (\d+) shards", t.split("\n", 1)[0])
        if not m:
            serial += 1; continue
        names, fs = parse(t)
        rows.append((os.path.basename(p), int(m.group(1)), names, score(fs)))
    return rows, serial


def selftest():
    t = ("# Code Review: X (merged from 3 shards)\n\n## Shard: part 1\n\n### Important\n\n#### dup finding\nClass: CODE\n"
         "Files: a/x.py\n\n#### only-p1\nClass: CODE\nFiles: a/y.py\n\n#### abs-dup\nFiles: /Users/u/graph-s9-story-1/a/w.py\n\n"
         "## Shard: cross\n\n### Important\n\n#### re-raise\nFiles: other/x.py\n\n#### only-cross\nFiles: b/z.py\n\n"
         "#### abs-dup-cross\nFiles: w.py\n\n## Shard: part 2\n\n### Critical\n\nNone.\n")
    names, fs = parse(t)
    got = {f["title"]: f["unique"] for f in score(fs)}
    want = {"dup finding": False, "only-p1": True, "re-raise": False, "only-cross": True, "abs-dup": False, "abs-dup-cross": False}
    assert got == want, (got, want)
    assert names == ["part 1", "cross", "part 2"], names
    print("selftest OK: seeded duplicate pairs (same path, different directory, absolute against bare basename) scored non-unique, singles unique")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
    ref = REF_DEFAULT
    if "--ref" in sys.argv:
        i = sys.argv.index("--ref")
        ref = sys.argv[i + 1]
        del sys.argv[i:i + 2]
    if len(sys.argv) > 1 and not sys.argv[1].startswith("--"):
        d = sys.argv[1]
        rows, serial = run(d, ref)
        print("dir %s (ref %s): %d merged (sharded) code-review files, %d serial/other files not scored" % (d, ref, len(rows), serial))
        tot = {"part": 0, "cross": 0}; nsh = {"part": 0, "cross": 0}; totf = 0; noa = 0; ex = []
        for name, n, names, fs in rows:
            u = [f for f in fs if f["unique"]]
            for k in ("part", "cross"):
                nsh[k] += sum(1 for s in names if kind(s) == k)
                tot[k] += sum(1 for f in u if kind(f["shard"]) == k)
            totf += len(fs); noa += sum(1 for f in fs if f["noanchor"])
            print("  %-34s shards %2d findings(C+I) %2d unique %2d (cross %d, part %d)" % (
                name, n, len(fs), len(u), sum(1 for f in u if kind(f["shard"]) == "cross"),
                sum(1 for f in u if kind(f["shard"]) == "part")))
            for f in u:
                ex.append((name, f))
        c = nsh["cross"]
        print("TOTAL: %d sharded passes, %d part shards, %d cross shards, %d Critical+Important findings, %d unique (part %d, cross %d), %d unanchored (unscored)" % (
            len(rows), nsh["part"], c, totf, tot["part"] + tot["cross"], tot["part"], tot["cross"], noa))
        print("RATE: cross-unique per cross shard %d/%d = %.4f ; part-unique per part shard %d/%d = %.4f" % (
            tot["cross"], c, tot["cross"] / c if c else 0.0, tot["part"], nsh["part"], tot["part"] / nsh["part"] if nsh["part"] else 0.0))
        if "--examples" in sys.argv:
            for name, f in ex:
                print("  EX %s | %s | %s | %s | %s" % (name, f["shard"], f["sev"], f["anchor"] or f["path"], f["title"][:90]))
