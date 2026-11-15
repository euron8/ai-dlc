#!/usr/bin/env python3
"""BL-508: count MAJOR findings an adversarial pass labels repair-introduced.

Usage: python3 -I count_repair_introduced.py --graph <file:// clone of graph>

Reads each pass file with `git show <ref>:<path>` from the clone; writes nothing.
A finding is a markdown heading (## to #####) that carries MAJOR and a finding
marker (F-n, [MAJOR], or "MAJOR —"); its body runs to the next heading of the same
or a higher level. It is repair-introduced when its heading or body matches POS
after NEG phrases ("not repair-introduced", "introduced no") are removed.
"""
import argparse, re, subprocess, sys

PASSES = [
    ("s317", "refs/heads/ai-dlc/retro/sprint-317", "stories-adversarial-p1.md"),
    ("s317", "refs/heads/ai-dlc/retro/sprint-317", "stories-adversarial-p2.md"),
    ("s317", "refs/heads/ai-dlc/retro/sprint-317", "stories-adversarial-p3.md"),
    ("s318", "refs/heads/ai-dlc/retro/sprint-318", "stories-adversarial-p1.md"),
    ("s318", "refs/heads/ai-dlc/retro/sprint-318", "stories-adversarial-p2.md"),
    ("s318", "refs/heads/ai-dlc/retro/sprint-318", "stories-adversarial-p3.md"),
    ("s322", "refs/remotes/origin/ai-dlc/retro/sprint-322", "stories-adversarial-p1.md"),
    ("s322", "refs/remotes/origin/ai-dlc/retro/sprint-322", "stories-adversarial-p2.md"),
    ("s322", "refs/remotes/origin/ai-dlc/retro/sprint-322", "test-strategy-adversarial-p1.md"),
    ("s322", "refs/remotes/origin/ai-dlc/retro/sprint-322", "test-strategy-adversarial-p2.md"),
    ("s322", "refs/remotes/origin/ai-dlc/retro/sprint-322", "test-strategy-adversarial-p3.md"),
]
RECORDED = {  # BL-508's filing: s317 p1 0/11, p2 2/9, p3 2/4; s318 p1 16/30, p2 8/19, p3 1/2
    ("s317", "stories-adversarial-p1.md"): (0, 11), ("s317", "stories-adversarial-p2.md"): (2, 9),
    ("s317", "stories-adversarial-p3.md"): (2, 4), ("s318", "stories-adversarial-p1.md"): (16, 30),
    ("s318", "stories-adversarial-p2.md"): (8, 19), ("s318", "stories-adversarial-p3.md"): (1, 2),
}
HEAD = re.compile(r'^(#{2,5})\s+(.*)$')
MARK = re.compile(r'(\bF-?\d|\[MAJOR\]|MAJOR\s*[\]—:-])')
POS = re.compile(r'(repair[- ]introduced|introduced by[^.\n]{0,40}repair|repair[- ]made|'
                 r'written by (the|a)[^.\n]{0,20}repair|(the|its|pass-\d|p\d)[^.\n]{0,20}repair (wrote|introduced|injected))', re.I)
NEG = re.compile(r'(not|never|no)\s+(a\s+)?repair[- ]introduced|not introduced by[^.\n]{0,40}repair|introduced no', re.I)
IMPOSSIBLE = 'zqxv-repair-introduced-9931'


def show(graph, ref, sprint, name):
    path = f"{ref}:_bmad-output/planning-artifacts/{sprint}/{name}"
    r = subprocess.run(["git", "-C", graph, "show", path], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"REFUSE: cannot read {path}: {r.stderr.strip()}")
    return r.stdout


def majors(text):
    lines, out, i = text.split('\n'), [], 0
    while i < len(lines):
        m = HEAD.match(lines[i])
        if m and re.search(r'\bMAJOR\b', m.group(2)) and MARK.search(m.group(2)):
            j = i + 1
            while j < len(lines):
                n = HEAD.match(lines[j])
                if n and len(n.group(1)) <= len(m.group(1)):
                    break
                j += 1
            out.append((i + 1, m.group(2), '\n'.join(lines[i + 1:j])))
            i = j
        else:
            i += 1
    return out


def ri(s):
    return bool(POS.search(NEG.sub('', s)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--graph', required=True)
    a = ap.parse_args()
    corpus = []
    print("sprint pass | majors repair-introduced | recorded (BL-508 filing)")
    for sprint, ref, name in PASSES:
        t = show(a.graph, ref, sprint, name)
        corpus.append(t)
        fs = majors(t)
        hits = [(ln, h) for ln, h, b in fs if ri(h + '\n' + b)]
        rec = RECORDED.get((sprint, name))
        rec_s = f"{rec[0]}/{rec[1]}" if rec else "-"
        print(f"  {sprint} {name:34s} | {len(fs):3d} {len(hits):3d} | {rec_s}")
        if sprint == "s322":
            for ln, h in hits:
                print(f"      line {ln}: {h[:150]}")
    imp = sum(t.count(IMPOSSIBLE) for t in corpus)
    present = sum(len(re.findall(r'repair-introduced', t, re.I)) for t in corpus)
    print(f"CONTROL impossible token {IMPOSSIBLE}: {imp} (must be 0); present token 'repair-introduced': {present} (must be > 0)")
    seeds = {"### F-1 [MAJOR]: x (repair-introduced)": True, "### F-2 [MAJOR]: x (not repair-introduced)": False,
             "### F-3 [MINOR]: x (repair-introduced)": None}
    got = {}
    for s, want in seeds.items():
        fs = majors(s + "\nbody\n")
        got[s] = (ri(fs[0][1] + fs[0][2]) if fs else None)
    print("SELF-PROBE", "OK" if got == seeds else f"FAIL {got}")


if __name__ == '__main__':
    main()
