#!/usr/bin/env python3
"""BL-510: per-verdict rework class count for s321 (stdlib only).

Population is DERIVED from the consumer repo at a pinned sha through
`git --no-optional-locks -C <graph> ls-tree|show "<sha>:path"` only (read only).
Exit 0 = counted, 2 = refused (unknown verdict token, empty population, join
mismatch, baseline or control not reproduced, self-probe failure).
"""
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict

GRAPH = os.environ.get("BL510_GRAPH", "/Users/n8/git/graph")
SHA = "ed61de74574b4b1e6649a672373ab49d7eeb9199"
HERE = os.path.dirname(os.path.abspath(__file__))
EXP_PY = os.path.join(HERE, "..", "pipeline-efficiency-s317-s318", "role-efficacy", "impl", "exp.py")
KNOWN = ("APPROVED", "PASS", "NEEDS_REWORK")
GATE_NAME = {1: "CR", 2: "QA"}
# controls pinned at SHA (owner measurements, impl_passes.txt and contract D1)
S321_DIST = [(1, 8), (2, 10), (3, 4), (4, 1), (7, 1)]
S321_POP = (34, 23, 11)  # total, gate-1 CR, gate-2 QA
BASE_POP = {"s317": 18, "s318": 15}
BASE_CLASSES = {"E": 12, "B": 10, "S": 10, "?": 1}


class Refuse(Exception):
    pass


class _ProbeFail(Exception):
    """Self-probe failure; main() maps it to exit 2."""


# ---------------------------------------------------------------- derivation
NAME_RES = (
    ("cr", re.compile(r"^(\d+)[.-](\d+[a-z]?)-code-review(?:-p(\d+))?\.md$")),
    ("qa", re.compile(r"^(\d+)-(\d+[a-z]?)-qa-validation(?:-p(\d+))?\.md$")),
    ("ff-cr", re.compile(r"^(\d+)[.-](\d+[a-z]?)-ff-code-review(?:-p(\d+))?\.md$")),
    ("ff-qa", re.compile(r"^(\d+)-(\d+[a-z]?)-ff-qa-validation(?:-p(\d+))?\.md$")),
    ("sr-cr", re.compile(r"^sr-(.+)-code-review(?:-p(\d+))?\.md$")),
    ("sr-qa", re.compile(r"^sr-(.+)-qa-validation(?:-p(\d+))?\.md$")),
)
# not review verdicts: dev reports, drafts, closing writers/reports
EXCLUDE = re.compile(r"dev-report|\.draft$|closing-(writer|report)")


def git(*args):
    r = subprocess.run(["git", "--no-optional-locks", "-C", GRAPH] + list(args),
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise Refuse("git %s failed: %s" % (" ".join(args[:2]), r.stderr.strip()))
    return r.stdout


def first_verdict(text):
    """(token, 1-based line) of the first verdict. Grammar: `## Verdict: X`,
    `## Verdict` + token on the next non-blank line, `Verdict: X`. `Verdict rationale:`
    is prose and skipped."""
    lines = text.split("\n")
    for i, l in enumerate(lines):
        m = re.match(r"^\s*(?:#+\s*)?\**Verdict(:?)\**\s*(.*)$", l)
        if not m or (not m.group(1) and m.group(2).strip()):
            continue
        rest = m.group(2).strip().strip("*").strip()
        if rest:
            t = re.match(r"^[A-Za-z_]+", rest)
            return (t.group(0) if t else rest), i + 1
        for j in range(i + 1, min(i + 4, len(lines))):
            if lines[j].strip():
                t = re.match(r"^\**\s*([A-Za-z_]+)", lines[j].strip())
                return (t.group(1) if t else lines[j].strip()), j + 1
        return None, i + 1
    return None, 0


def classify_name(base):
    """(kind, story, pass) or None when the file is not a review file."""
    if EXCLUDE.search(base):
        return None
    for kind, rx in NAME_RES:
        m = rx.match(base)
        if m:
            g = m.groups()
            if kind in ("cr", "qa", "ff-cr", "ff-qa"):
                return kind, "%s.%s" % (g[0], g[1]), int(g[2] or 1)
            return kind, g[0], int(g[1] or 1)
    return "other", base, 1


def derive(prefix, listing, reader):
    """Files under one review dir (top level only; shards/ skipped). Kind filter happens
    BEFORE the unknown-token refusal. Returns (files, unknown)."""
    out, unknown = [], []
    for p in listing:
        rel = p[len(prefix):]
        if "/" in rel:
            continue
        k = classify_name(rel)
        if k is None:
            continue
        tok, line = first_verdict(reader(p))
        if k[0] == "other" and tok is None:
            continue
        d = dict(kind=k[0], story=k[1], pas=k[2], token=tok, path=p, line=line)
        out.append(d)
        if k[0] != "other" and tok not in KNOWN:
            unknown.append(d)
    return out, unknown


def population(files):
    """Story-level (cr/qa) NEEDS_REWORK keyed (story, gate, pass); gate 1 = CR, 2 = QA."""
    pop = {}
    for d in files:
        if d["token"] == "NEEDS_REWORK" and d["kind"] in ("cr", "qa"):
            key = (d["story"], 1 if d["kind"] == "cr" else 2, d["pas"])
            if key in pop:
                raise Refuse("duplicate population key %r" % (key,))
            pop[key] = d
    return pop


def require_derivable(files, unknown, pop, what):
    """Returns (matched-kind files, those carrying a verdict token). The coverage arm runs
    BEFORE the unknown-token arm: a matched file with NO token (None) would otherwise be
    swallowed by the unknown arm, leaving the coverage arm unreachable."""
    matched = [d for d in files if d["kind"] != "other"]
    carrying = [d for d in matched if d["token"] is not None]
    if len(matched) != len(carrying):
        raise Refuse("%s: coverage: %d matched review files but %d carry a verdict token (no token: %s)" % (
            what, len(matched), len(carrying),
            ", ".join(d["path"].split("/")[-1] for d in matched if d["token"] is None)))
    if unknown:
        raise Refuse("%s: unknown verdict token(s): %s" % (what, ", ".join(
            "%s=%r" % (u["path"].split("/")[-1], u["token"]) for u in unknown)))
    if not files or not pop:
        raise Refuse("%s: empty population (%d files, %d rework)" % (what, len(files), len(pop)))
    tok = Counter(d["token"] for d in matched)
    if tok["APPROVED"] + tok["PASS"] <= 0:
        raise Refuse("%s: no APPROVED/PASS verdict found, the grammar cannot see passes" % what)
    return len(matched), len(carrying)


def two_way_join(pop_keys, label_keys, what):
    missing = sorted(set(pop_keys) - set(label_keys))
    extra = sorted(set(label_keys) - set(pop_keys))
    if missing or extra:
        raise Refuse("%s join: missing labels %r; extra labels %r" % (what, missing, extra))


def graph_sprint(sprint, sha=None):
    sha = sha or SHA
    prefix = "docs/reviews/%s/" % sprint
    listing = git("ls-tree", "-r", "--name-only", sha, "--", prefix).splitlines()
    cache = {}

    def reader(p):
        if p not in cache:
            cache[p] = git("show", "%s:%s" % (sha, p))
        return cache[p]
    files, unknown = derive(prefix, listing, reader)
    return files, unknown, reader


# ------------------------------------------------------------------- labels
# class definitions, exp.py lines 5-6 verbatim:
#   S = substantive code/test defect, E = evidence/capture/record format, B = bookkeeping/status/headings
# MIXED RULE (stated before labelling): a pass is labelled by its verdict-flipping finding(s),
# i.e. every finding under that review's `### Critical` or `### Important` heading (checked below).
#   only S -> S;  S plus any E/B -> SM (S-mixed, counted in "other", reported separately);
#   only E -> E;  only B -> B;  E plus B, no S -> EB (counted in the E+B share, reported separately).
# Each finding: (class, line, title prefix). The script re-reads the line at SHA and refuses if the
# title does not start with the quote or the nearest `### ` heading above is not Critical/Important.
L = {}


def lab(story, gate, pas, cls, *findings):
    L[(story, gate, pas)] = (cls, list(findings))


lab("1.1", 1, 1, "E", ("E", 23, "PROVENANCE records no capture command"))
lab("1.2", 1, 1, "SM",
    ("S", 54, "AC2 guard is a token search"), ("S", 159, "Predicate applied to lists"),
    ("S", 185, "The main.py 2456 anchor"), ("S", 285, "AC7 does not red against"),
    ("S", 343, "The all_chains_in_process fixture is a disposition"),
    ("E", 366, "The 47-red claim"), ("S", 478, "Permit2 status report left unfiltered"),
    ("S", 497, "The all_chains_in_process fixture is a requirement divergence"),
    ("S", 524, "Four loops are filtered twice"))
lab("1.2", 1, 2, "S", ("S", 248, "Two subject tests whose control moved"),
    ("S", 375, "A fixture-removed test stays green"), ("S", 433, "Fixture removal left matic-instance tests"))
lab("1.2", 1, 3, "S", ("S", 84, "Three skip branches in api.py"))
lab("1.2", 1, 5, "S", ("S", 25, "The canary-restore silence assertion"))
lab("1.2", 2, 1, "SM", ("S", 60, "AC3 no-WARNING assertion"), ("S", 182, "test_s317 AC6 dropped-base"),
    ("B", 319, "Story header status disagrees"), ("B", 336, "The lead-checkout story copy diverges"))
lab("1.2", 2, 2, "S", ("S", 86, "test_s317_1_4_decimals_chain_context.py errors"),
    ("S", 96, "REBALANCER_CHAIN is absent from the environment template"))
lab("1.3", 1, 1, "S", ("S", 23, "AC1 enable-window"))
lab("1.4", 1, 1, "S", ("S", 21, "Idle-instance S9 exemption"))
lab("2.1", 1, 1, "B", ("B", 23, "Offramp rows and F-3"))
lab("2.3", 1, 1, "S", ("S", 19, "The reserve cap clamps"))
lab("2.4", 2, 1, "B", ("B", 90, "Story file lost its SKILL_INVOCATION_PROVENANCE"),
    ("B", 97, "Three story derived fences"))
lab("3.1", 1, 1, "SM", ("S", 27, "rb_all_idle aborts under set -e"), ("B", 51, "AC5 allow-list is not met"),
    ("S", 74, "Unreadable or degenerate record"))
lab("3.1", 1, 2, "E", ("E", 35, "Mutation-RED record for the absent-skip guard"))
lab("3.2", 1, 1, "SM", ("S", 23, "Case 14i does not discriminate"), ("E", 36, "Smoke Test Updates derivation"))
lab("3.2", 2, 1, "B", ("B", 104, "Strategy Test IDs rows ST321-74"))
lab("3.3", 1, 1, "SM", ("S", 129, "Repaired retention arms"), ("S", 146, "Retention test inherits"),
    ("S", 161, "AC3 abort-decision copy"), ("S", 177, "T14 retirement"),
    ("E", 193, "No mutation-RED capture covers"), ("S", 413, "run-deployed-ranges.sh exits 0"),
    ("S", 521, "Idle gate and roll set parse"))
lab("3.4", 1, 1, "S", ("S", 19, "A silent default-fill"), ("S", 31, "A probe thread that dies"),
    ("S", 41, "The post-response failure arms"))
lab("3.4", 1, 2, "S", ("S", 23, "The post-response failure arms"))
lab("3.4", 2, 1, "E", ("E", 61, "Discriminators named by the story"), ("E", 76, "Mutation captures carry a head"))
lab("4.1", 1, 1, "S", ("S", 19, "AC9 test does not discriminate"))
lab("4.1", 2, 1, "E", ("E", 82, "Discriminator ACs AC1"))
lab("4.3", 1, 1, "S", ("S", 50, "AC3 has no Matic collect-rewards POST control"),
    ("S", 67, "AC2 first-listed-disabled-pool"), ("S", 86, "AC5(b)"), ("S", 145, "Dead `pools` locals"))
lab("4.3", 2, 1, "SM", ("B", 58, "Strategy Test IDs rows cite"), ("S", 146, "Per-chain segment on two"),
    ("S", 237, "AC6 discriminator gap"))
lab("4.3", 2, 2, "EB", ("E", 199, "collect-post mutation anchor"), ("B", 272, "Strategy Test IDs rows cite"))
lab("5.1", 1, 1, "S", ("S", 23, "AC4 default-path test is circular"))
lab("5.2", 2, 1, "E", ("E", 56, "AC3 has no committed mutation-RED"))
lab("5.3", 1, 1, "S", ("S", 25, "The committed layers block"))
lab("5.4", 1, 1, "B", ("B", 23, "AC6 path list omits"))
lab("5.4", 1, 2, "B", ("B", 62, "AC6 path list does not name"))
lab("6.1", 1, 1, "EB", ("E", 48, "Row 14"), ("E", 54, "F7 and F9 negatives"), ("E", 59, "Row 21"),
    ("E", 64, "AC3 reviewer checklist"), ("B", 71, "AC6 scope text omits"), ("B", 76, "AC4 section 5 names"))
lab("6.1", 1, 2, "EB", ("E", 56, "F7 and F9 negatives"), ("B", 63, "AC6 scope text omits"))
lab("6.1", 2, 1, "B", ("B", 57, "AC1: state cells contradict"), ("B", 64, "AC2: live Base"),
    ("B", 71, "AC3: citations"), ("B", 80, "Dev Agent Record validator line"))
lab("6.1", 2, 2, "B", ("B", 59, "AC3: citations"), ("B", 68, "Dev Agent Record judgement calls"))
LABELS = L


def rule_class(findings):
    cs = set(f[0] for f in findings)
    if not cs or not cs <= set("SEB"):
        raise Refuse("finding classes %r outside S/E/B" % sorted(cs))
    if "S" in cs:
        return "S" if cs == {"S"} else "SM"
    return "".join(sorted(cs)) if cs != {"E", "B"} else "EB"


def check_labels(labels, pop, reader, verify_text=True):
    two_way_join(pop.keys(), labels.keys(), "label")
    for key, (cls, fnd) in sorted(labels.items()):
        if cls != rule_class(fnd) and cls != "?":
            raise Refuse("%r: class %s disagrees with the mixed rule (%s)" % (key, cls, rule_class(fnd)))
        if not verify_text:
            continue
        path = pop[key]["path"]
        t = reader(path).split("\n")
        for fc, ln, quote in fnd:
            if ln > len(t) or not re.sub(r"^#+\s*", "", t[ln - 1]).startswith(quote):
                raise Refuse("%r: line %d of %s does not start with %r" % (key, ln, path, quote))
            j = ln - 1
            while j >= 0 and not re.match(r"^### ", t[j]):
                j -= 1
            if j < 0 or not re.match(r"^### (Critical|Important)", t[j]):
                raise Refuse("%r: line %d is not under a Critical/Important heading" % (key, ln))


# ----------------------------------------------------------------- baseline
def parse_baseline(path):
    """exp.py lines 7-26 AS TEXT. -> {(sprint-label, story, gate, pass): class}"""
    lines = open(path).read().split("\n")[6:26]
    out = {}
    for l in lines:
        m = re.match(r"^\s*\((\d+),'([^']+)'\): '(.*)',\s*$", l)
        if not m:
            continue
        sprint, story, body = "s%s" % m.group(1), m.group(2), m.group(3)
        prev = None
        while prev != body:  # strip parenthesised text, innermost first
            prev, body = body, re.sub(r"\([^()]*\)", "", body)
        for seg in body.split(";"):
            g = re.match(r"^\s*(CR|QA)\b", seg)
            if not g:
                raise Refuse("baseline segment without CR/QA: %r" % seg)
            gate = 1 if g.group(1) == "CR" else 2
            for pn, c in re.findall(r"p(\d+)\s+([SEB?])", seg):
                k = (sprint, story, gate, int(pn))
                if k in out:
                    raise Refuse("baseline duplicate %r" % (k,))
                out[k] = c
    return out


# ------------------------------------------------------- H1v second labelling
# Blind opus labeller (H1v): one class per verdict file, keyed (sprint, file), file under
# docs/reviews/<sprint>/ at graph sha G. Columns: sprint file gate class line. Classes S, SM, E,
# B, EB, ?; a `[D]` suffix marks a no-code story whose wrong claim sat in the deliverable
# document, which H1v read as S. Primary reading maps [D] rows as their class (S[D] -> S,
# SM[D] -> SM); the alternate reading maps every [D] row to E (the S part becomes E).
# H1v saw reviewers' own `Class:` tags in s321 files, so it is not fully blind there.
H1V_TEXT = (
    "s317 1-2-code-review.md 1 SM 58\n"
    "s317 1-2-code-review-p2.md 1 EB 156\n"
    "s317 1-2-code-review-p3.md 1 E 138\n"
    "s317 1-3-code-review.md 1 SM 20\n"
    "s317 1-4-qa-validation.md 2 B 60\n"
    "s317 1-7-code-review.md 1 S[D] 14\n"
    "s317 2-3-code-review.md 1 SM 20\n"
    "s317 2-3-qa-validation.md 2 E 76\n"
    "s317 2-5-code-review.md 1 SM 700\n"
    "s317 2-6-code-review.md 1 SM 55\n"
    "s317 2-6-code-review-p2.md 1 SM 127\n"
    "s317 2-6-code-review-p3.md 1 EB 225\n"
    "s317 2-6-code-review-p4.md 1 S 52\n"
    "s317 2-6-qa-validation.md 2 EB 164\n"
    "s317 4-2a-qa-validation-p2.md 2 E 80\n"
    "s317 4-2a-qa-validation.md 2 EB 61\n"
    "s317 4-3a-code-review.md 1 S[D] 38\n"
    "s317 4-3b-qa-validation.md 2 E 12\n"
    "s318 1-1-code-review.md 1 SM 59\n"
    "s318 1-1-code-review-p2.md 1 E 101\n"
    "s318 1-1-code-review-p3.md 1 E 107\n"
    "s318 1-2-code-review.md 1 SM 19\n"
    "s318 1-5-code-review.md 1 B 19\n"
    "s318 1-5-qa-validation.md 2 E 43\n"
    "s318 2-3-code-review.md 1 E 637\n"
    "s318 2-3-code-review-p2.md 1 E 199\n"
    "s318 2-4-code-review.md 1 SM 55\n"
    "s318 2-4-code-review-p2.md 1 E 96\n"
    "s318 2-5-qa-validation.md 2 E 57\n"
    "s318 2-6-code-review.md 1 SM 114\n"
    "s318 2-6-code-review-p2.md 1 E 888\n"
    "s318 2-6-code-review-p3.md 1 E 60\n"
    "s318 2-7-qa-validation.md 2 SM 13\n"
    "s321 1-2-qa-validation.md 2 SM 60\n"
    "s321 1-2-qa-validation-p2.md 2 S 86\n"
    "s321 1.1-code-review.md 1 E 23\n"
    "s321 1.2-code-review.md 1 SM 54\n"
    "s321 1.2-code-review-p2.md 1 S 248\n"
    "s321 1.2-code-review-p3.md 1 S 84\n"
    "s321 1.2-code-review-p5.md 1 S 25\n"
    "s321 1.3-code-review.md 1 S 23\n"
    "s321 1.4-code-review.md 1 S 21\n"
    "s321 2-4-qa-validation.md 2 B 90\n"
    "s321 2.1-code-review.md 1 S[D] 23\n"
    "s321 2.3-code-review.md 1 S 19\n"
    "s321 3-2-qa-validation.md 2 B 104\n"
    "s321 3-3-code-review.md 1 SM 129\n"
    "s321 3-4-qa-validation.md 2 E 61\n"
    "s321 3.1-code-review.md 1 SM 27\n"
    "s321 3.1-code-review-p2.md 1 E 35\n"
    "s321 3.2-code-review.md 1 SM 23\n"
    "s321 3.4-code-review.md 1 S 19\n"
    "s321 3.4-code-review-p2.md 1 S 23\n"
    "s321 4-1-qa-validation.md 2 E 82\n"
    "s321 4-3-qa-validation.md 2 SM 146\n"
    "s321 4-3-qa-validation-p2.md 2 EB 199\n"
    "s321 4.1-code-review.md 1 S 19\n"
    "s321 4.3-code-review.md 1 S 50\n"
    "s321 5-2-qa-validation.md 2 E 56\n"
    "s321 5.1-code-review.md 1 S 23\n"
    "s321 5.3-code-review.md 1 S 25\n"
    "s321 5.4-code-review.md 1 B 23\n"
    "s321 5.4-code-review-p2.md 1 B 62\n"
    "s321 6-1-qa-validation.md 2 SM[D] 57\n"
    "s321 6-1-qa-validation-p2.md 2 EB 59\n"
    "s321 6.1-code-review.md 1 EB 48\n"
    "s321 6.1-code-review-p2.md 1 EB 56\n"
)
H1V_CLASSES = ("S", "SM", "E", "B", "EB", "?")
H1V_SPRINTS = ("s317", "s318", "s321")
FAMILY = ("E", "B", "EB")  # the E+B family; S, SM and ? are "other" in every binary comparison


def parse_h1v(text):
    """-> {(sprint, file): dict(gate, line, primary, alt, d)}. Refuses malformed, duplicate or unknown."""
    out = {}
    for raw in text.split("\n"):
        if not raw.strip():
            continue
        parts = raw.split()
        if len(parts) != 5:
            raise Refuse("H1v row without 5 columns: %r" % raw)
        sprint, fn, gate, cls, line = parts
        m = re.match(r"^(S|SM|E|B|EB|\?)(\[D\])?$", cls)
        if sprint not in H1V_SPRINTS or not m or gate not in ("1", "2") or not line.isdigit():
            raise Refuse("H1v row not in the grammar: %r" % raw)
        key = (sprint, fn)
        if key in out:
            raise Refuse("H1v duplicate key %r" % (key,))
        d = bool(m.group(2))
        out[key] = dict(gate=int(gate), line=int(line), primary=m.group(1),
                        alt="E" if d else m.group(1), d=d)
    return out


def h1v_join(h1v, pops):
    """pops: {sprint: {file: gate}} derived from the graph. Two-way join, then the gate column."""
    want = set((sp, fn) for sp in pops for fn in pops[sp])
    two_way_join(want, h1v.keys(), "H1v")
    for sp in pops:
        for fn, gate in pops[sp].items():
            if h1v[(sp, fn)]["gate"] != gate:
                raise Refuse("H1v %s %s: gate %d != derived gate %d" % (sp, fn, h1v[(sp, fn)]["gate"], gate))


def fam(c):
    return 1 if c in FAMILY else 0


def binary_agreement(pairs):
    """pairs: [(key, a, b)] -> (n, agreeing, [disagreeing (key, a, b)]) on E+B family vs other."""
    dis = [p for p in pairs if fam(p[1]) != fam(p[2])]
    return len(pairs), len(pairs) - len(dis), dis


def report_agreement(title, pairs, la, lb):
    n, ag, dis = binary_agreement(pairs)
    print("   %s: %d/%d agree (E+B family vs other); disagree %d" % (title, ag, n, len(dis)))
    for k, a, b in dis:
        print("      %s  %s=%s %s=%s" % (" ".join(str(x) for x in k), la, a, lb, b))


# --------------------------------------------------------------- self-probe
def _probe():
    """Both directions on synthetic input before the corpus is touched."""
    pre = "docs/reviews/sX/"
    docs = {
        pre + "1.1-code-review.md": "## Verdict\nNEEDS_REWORK\n",
        pre + "1-1-qa-validation.md": "Verdict: PASS\n",
        pre + "1.1-code-review-p2.md": "## Verdict: APPROVED\n",
        pre + "2.1-code-review.md": "Verdict rationale: prose\n\n## Verdict\n\nNEEDS_REWORK\n",
        pre + "2.1-code-review-p2.md": "## Verdict\nAPPROVED\n",
        pre + "2.1-rework-dev-report.md": "## Verdict\nBOGUS_TOKEN\n",       # excluded kind
        pre + "shards/1.md": "## Verdict\nBOGUS_TOKEN\n",                   # excluded dir
        pre + "sr-a-qa-validation.md": "## Verdict: NEEDS_REWORK\n",       # outside the population
    }
    listing = sorted(docs)
    rd = docs.__getitem__

    def expect_refuse(fn, label, via=None):
        try:
            fn()
        except Refuse as e:
            if via is not None and via not in str(e):
                raise _ProbeFail("self-probe FAILED: %s refused via the wrong arm: %s" % (label, e))
            return
        raise _ProbeFail("self-probe FAILED: %s did not refuse" % label)

    files, unk = derive(pre, listing, rd)
    pop = population(files)
    if require_derivable(files, unk, pop, "probe") != (6, 6):
        raise _ProbeFail("self-probe FAILED: coverage control on a fully-tokened set")
    if sorted(pop) != [("1.1", 1, 1), ("2.1", 1, 1)]:
        raise _ProbeFail("self-probe FAILED: synthetic population %r" % sorted(pop))
    exact = {("1.1", 1, 1): ("E", [("E", 1, "x")]), ("2.1", 1, 1): ("S", [("S", 1, "x")])}
    check_labels(exact, pop, rd, verify_text=False)                      # exact match passes
    expect_refuse(lambda: check_labels({k: v for k, v in exact.items() if k[0] == "1.1"},
                                       pop, rd, False), "missing label")
    extra = dict(exact)
    extra[("9.9", 1, 1)] = ("S", [("S", 1, "x")])
    expect_refuse(lambda: check_labels(extra, pop, rd, False), "extra label")
    bad = dict(docs)
    bad[pre + "3.1-code-review.md"] = "## Verdict\nMAYBE\n"
    f2, u2 = derive(pre, sorted(bad), bad.__getitem__)
    expect_refuse(lambda: require_derivable(f2, u2, population(f2), "probe"), "unknown verdict token",
                  via="unknown verdict token")
    notok = dict(docs)
    notok[pre + "3.1-code-review.md"] = "no verdict heading here\n"
    f4, u4 = derive(pre, sorted(notok), notok.__getitem__)
    expect_refuse(lambda: require_derivable(f4, u4, population(f4), "probe"), "matched file with no token",
                  via="coverage")
    expect_refuse(lambda: require_derivable([], [], {}, "probe"), "empty population")
    nopass = {pre + "1.1-code-review.md": "## Verdict\nNEEDS_REWORK\n"}
    f3, u3 = derive(pre, sorted(nopass), nopass.__getitem__)
    expect_refuse(lambda: require_derivable(f3, u3, population(f3), "probe"), "no APPROVED/PASS")
    expect_refuse(lambda: rule_class([("X", 1, "q")]), "unknown finding class")
    txt = {pre + "1.1-code-review.md": "## Verdict\nNEEDS_REWORK\n### Important\n#### Real title here\n"
           "### Suggestions\n#### Soft title\n"}
    tp = {("1.1", 1, 1): dict(path=pre + "1.1-code-review.md")}
    tr = txt.__getitem__
    check_labels({("1.1", 1, 1): ("S", [("S", 4, "Real title")])}, tp, tr)            # accepted
    expect_refuse(lambda: check_labels({("1.1", 1, 1): ("S", [("S", 4, "Other title")])}, tp, tr),
                  "quote not at line")
    expect_refuse(lambda: check_labels({("1.1", 1, 1): ("S", [("S", 6, "Soft title")])}, tp, tr),
                  "finding under Suggestions")
    if rule_class([("S", 1, "q"), ("B", 2, "q")]) != "SM" or rule_class([("E", 1, "q"), ("B", 2, "q")]) != "EB":
        raise _ProbeFail("self-probe FAILED: mixed rule")
    # baseline parser: a bare letter after a stripped parenthesis, and a '?' pass
    tmp = ["#"] * 6 + [" (317,'9.9'): 'CR p1 S(x (nested) y) p2 E; QA p1 B p2 B(z)',",
                       " (318,'8.8'): 'CR p1 ?(cross-shard)',"] + ["#"] * 18
    fd, p = tempfile.mkstemp(prefix="bl510-probe-exp-", suffix=".txt")
    with os.fdopen(fd, "w") as fh:
        fh.write("\n".join(tmp) + "\n")
    try:
        got = parse_baseline(p)
    finally:
        os.remove(p)
    want = {("s317", "9.9", 1, 1): "S", ("s317", "9.9", 1, 2): "E", ("s317", "9.9", 2, 1): "B",
            ("s317", "9.9", 2, 2): "B", ("s318", "8.8", 1, 1): "?"}
    if got != want:
        raise _ProbeFail("self-probe FAILED: baseline parser %r" % got)
    # H1v table: grammar, [D] mapping, two-way join (missing key refuses), gate column, agreement
    ht = ("s317 a.md 1 S[D] 5\ns317 b.md 2 SM 6\ns318 c.md 1 EB 7\ns318 d.md 1 ? 3\n"
          "s321 e.md 1 SM[D] 9\n")
    hp = parse_h1v(ht)
    if (hp[("s317", "a.md")]["primary"], hp[("s317", "a.md")]["alt"]) != ("S", "E") or \
            (hp[("s321", "e.md")]["primary"], hp[("s321", "e.md")]["alt"]) != ("SM", "E") or \
            (hp[("s317", "b.md")]["primary"], hp[("s317", "b.md")]["alt"]) != ("SM", "SM"):
        raise _ProbeFail("self-probe FAILED: H1v [D] mapping")
    pops = {"s317": {"a.md": 1, "b.md": 2}, "s318": {"c.md": 1, "d.md": 1}, "s321": {"e.md": 1}}
    h1v_join(hp, pops)                                                              # exact passes
    miss = dict(hp)
    del miss[("s318", "d.md")]
    expect_refuse(lambda: h1v_join(miss, pops), "missing H1v key")
    expect_refuse(lambda: h1v_join(hp, {"s317": {"a.md": 1, "b.md": 2}, "s318": {"c.md": 1},
                                        "s321": {"e.md": 1}}), "extra H1v key")
    expect_refuse(lambda: h1v_join(hp, dict(pops, s321={"e.md": 2})), "H1v gate mismatch")
    expect_refuse(lambda: parse_h1v(ht + "s317 a.md 1 S 5\n"), "duplicate H1v key")
    expect_refuse(lambda: parse_h1v("s317 z.md 1 XX 5\n"), "unknown H1v class")
    expect_refuse(lambda: parse_h1v("s317 z.md 1 S\n"), "short H1v row")
    n, ag, dis = binary_agreement([("k1", "E", "EB"), ("k2", "SM", "S"), ("k3", "S", "B"), ("k4", "?", "E")])
    if (n, ag, [d[0] for d in dis]) != (4, 2, ["k3", "k4"]):
        raise _ProbeFail("self-probe FAILED: binary agreement %r" % ((n, ag, dis),))
    # the shipped table itself must parse and carry the pinned row counts
    sh = parse_h1v(H1V_TEXT)
    if Counter(k[0] for k in sh) != Counter({"s317": 18, "s318": 15, "s321": 34}):
        raise _ProbeFail("self-probe FAILED: shipped H1v table row counts %r" % dict(Counter(k[0] for k in sh)))
    print("self-probe: ok (missing/extra label, unknown token, empty population, no-pass, mixed rule, baseline parser,"
          " H1v grammar/[D]/join/gate/agreement)")


# --------------------------------------------------------------------- main
def main():
    _probe()
    print("graph sha G = %s (read only: ls-tree/show)" % SHA)

    # 1. verdict-token tabulation, every review file kind at G under s321
    files, unknown, reader = graph_sprint("s321")
    print("\n== s321 verdict tokens by file kind (docs/reviews/s321/, top level, shards/ and dev reports/drafts excluded)")
    tab = Counter((d["kind"], d["token"]) for d in files)
    for (k, t), n in sorted(tab.items()):
        print("  %-6s %-13s %3d" % (k, t, n))
    print("  verdict-bearing files: %d" % len(files))
    pop = population(files)
    n_matched, n_carry = require_derivable(files, unknown, pop, "s321")
    tok = Counter(d["token"] for d in files if d["kind"] != "other")
    print("  control: matched cr/qa/ff/sr review files %d == files carrying a verdict token %d; APPROVED+PASS = %d (>0)" % (
        n_matched, n_carry, tok["APPROVED"] + tok["PASS"]))
    outside = [d for d in files if d["token"] == "NEEDS_REWORK" and d["kind"] not in ("cr", "qa")]
    print("  NEEDS_REWORK in ff-/sr-/other kinds (outside the population by scope rule): %d" % len(outside))
    cr_n = sum(1 for k in pop if k[1] == 1)
    qa_n = sum(1 for k in pop if k[1] == 2)
    print("  population: %d NEEDS_REWORK = %d gate-1 CR + %d gate-2 QA" % (len(pop), cr_n, qa_n))
    if (len(pop), cr_n, qa_n) != S321_POP:
        raise Refuse("s321 population %r != pinned %r" % ((len(pop), cr_n, qa_n), S321_POP))

    # 2. independent control: gate-1 CR passes per story
    per = Counter(d["story"] for d in files if d["kind"] == "cr")
    dist = sorted(Counter(per.values()).items())
    print("  control: gate-1 CR pass distribution (passes-per-story, stories) = %s over %d stories, %d passes"
          % (dist, len(per), sum(per.values())))
    if dist != S321_DIST:
        raise Refuse("gate-1 CR distribution %r != impl_passes.txt %r" % (dist, S321_DIST))

    # 3. outside-scope _bmad-output verdicts, reported separately
    bprefix = "_bmad-output/implementation-artifacts/s321/"
    blist = git("ls-tree", "-r", "--name-only", SHA, "--", bprefix).splitlines()
    cache = {}

    def breader(p):
        if p not in cache:
            cache[p] = git("show", "%s:%s" % (SHA, p))
        return cache[p]
    bfiles, bunk = derive(bprefix, blist, breader)
    bnr = [d for d in bfiles if d["token"] == "NEEDS_REWORK"]
    bcr = [d for d in bnr if d["path"].endswith("-code-review.md")]
    bother = [d for d in bnr if d not in bcr]
    print("\n== outside the population (scope D2): %s" % bprefix)
    print("  NEEDS_REWORK in *-code-review.md = %d (%s)" % (
        len(bcr), ", ".join(d["path"].split("/")[-1] for d in bcr)))
    print("  NEEDS_REWORK in other verdict-bearing files there = %d (%s)" % (
        len(bother), ", ".join(d["path"].split("/")[-1] for d in bother)))
    if len(bcr) != 2:
        raise Refuse("expected 2 _bmad-output code-review NEEDS_REWORK, found %d" % len(bcr))

    # 4. baseline: exp.py text vs derived s317+s318
    base = parse_baseline(EXP_PY)
    bc = Counter(base.values())
    print("\n== baseline (exp.py lines 7-26 parsed as text): %d passes; %s" % (len(base), dict(bc)))
    if len(base) != 33 or any(bc[c] != n for c, n in BASE_CLASSES.items()):
        raise Refuse("baseline %r != E=12 B=10 S=10 ?=1 total 33" % dict(bc))
    bpop = {}
    for sp in ("s317", "s318"):
        f, u, _ = graph_sprint(sp)
        p = population(f)
        require_derivable(f, u, p, sp)
        print("  derived %s: %d NEEDS_REWORK (expected %d)" % (sp, len(p), BASE_POP[sp]))
        if len(p) != BASE_POP[sp]:
            raise Refuse("%s population %d != %d" % (sp, len(p), BASE_POP[sp]))
        for k in p:
            bpop[(sp,) + k] = p[k]
    two_way_join(bpop.keys(), base.keys(), "baseline")
    print("  derived s317+s318 = %d, joined to exp.py CLS two ways: exact" % len(bpop))
    be, bb = bc["E"], bc["B"]
    print("  baseline E+B = %d/33 = %.1f%%" % (be + bb, 100.0 * (be + bb) / 33))

    # 5. labels
    check_labels(LABELS, pop, reader)
    print("\n== labels: %d keys joined to the derived population two ways, every quoted finding re-read at G"
          " and confirmed under Critical/Important" % len(LABELS))
    print("\n   story gate pass class path:line  finding (also: other findings)")
    for key in sorted(LABELS, key=lambda k: (k[1], [int(x) if x.isdigit() else x for x in re.split(r"[.]", k[0])], k[2])):
        cls, fnd = LABELS[key]
        lead = next((f for f in fnd if f[0] == "S"), fnd[0]) if cls == "SM" else fnd[0]
        also = ["%s@%d" % (f[0], f[1]) for f in fnd if f is not lead]
        print("   %-5s %s %d %-2s %s:%d  %s%s" % (key[0], GATE_NAME[key[1]], key[2], cls,
              pop[key]["path"], lead[1], lead[2], ("  (also " + ", ".join(also) + ")") if also else ""))

    # 6. counts
    cc = Counter(v[0] for v in LABELS.values())
    n = len(LABELS)
    ebs = cc["E"] + cc["B"] + cc["EB"]
    print("\n== s321 per-class counts (n=%d): S=%d E=%d B=%d EB=%d (E-and-B mixed) SM=%d (S-mixed) ?=%d"
          % (n, cc["S"], cc["E"], cc["B"], cc["EB"], cc["SM"], cc["?"]))
    print("   other = S + SM + ? = %d  (S-mixed reported separately: %d)" % (cc["S"] + cc["SM"] + cc["?"], cc["SM"]))
    print("   E+B share: s321 %d/%d = %.1f%%  vs baseline s317-s318 22/33 = 66.7%%" % (ebs, n, 100.0 * ebs / n))
    print("   by gate: CR %s ; QA %s" % (
        dict(Counter(v[0] for k, v in LABELS.items() if k[1] == 1)),
        dict(Counter(v[0] for k, v in LABELS.items() if k[1] == 2))))

    # 7. H1v second (blind opus) labelling: joined two ways to the derived population, all three sprints
    h1v = parse_h1v(H1V_TEXT)
    pops = {"s321": dict((d["path"].split("/")[-1], k[1]) for k, d in pop.items()),
            "s317": {}, "s318": {}}
    for k, d in bpop.items():
        pops[k[0]][d["path"].split("/")[-1]] = k[2]
    h1v_join(h1v, pops)
    print("\n== H1v blind second labelling: %d rows joined two ways to the derived population "
          "(s317 %d, s318 %d, s321 %d), gate column agrees" % (
              len(h1v), len(pops["s317"]), len(pops["s318"]), len(pops["s321"])))
    print("   [D] rows (no-code story, deliverable-document claim): %d; primary reading maps them as S/SM, "
          "alternate reading maps them to E" % sum(1 for r in h1v.values() if r["d"]))
    print("   caveat: H1v saw reviewers' own `Class:` tags in s321 files (not fully blind there)")
    order = ("S", "SM", "E", "B", "EB", "?")
    for reading in ("primary", "alt"):
        print("   -- %s reading" % ("primary ([D] as S)" if reading == "primary" else "alternate ([D] as E)"))
        for sp in H1V_SPRINTS:
            rs = [r for k, r in h1v.items() if k[0] == sp]
            c = Counter(r[reading] for r in rs)
            e = sum(c[x] for x in FAMILY)
            print("      %s n=%d  %s  E+B family (E,B,EB) = %d/%d = %.1f%%" % (
                sp, len(rs), " ".join("%s=%d" % (x, c[x]) for x in order), e, len(rs), 100.0 * e / len(rs)))
        rs = [r for k, r in h1v.items() if k[0] in ("s317", "s318")]
        e = sum(1 for r in rs if r[reading] in FAMILY)
        print("      s317+s318 pooled n=%d  E+B family = %d/%d = %.1f%%  (exp.py CLS baseline 22/33 = 66.7%%)" % (
            len(rs), e, len(rs), 100.0 * e / len(rs)))

    # 8. binary agreement, E+B family vs other (S, SM and ? are other)
    print("\n== binary agreement, E+B family vs other (S, SM, ? = other)")
    for reading in ("primary", "alt"):
        print("   -- H1v %s reading" % reading)
        pairs = []
        for key in sorted(LABELS):
            fn = pop[key]["path"].split("/")[-1]
            pairs.append((("s321", fn), LABELS[key][0], h1v[("s321", fn)][reading]))
        report_agreement("H1 (sonnet) vs H1v on s321", pairs, "H1", "H1v")
        cpairs = []
        for bk in sorted(base):
            fn = bpop[bk]["path"].split("/")[-1]
            cpairs.append(((bk[0], fn), base[bk], h1v[(bk[0], fn)][reading]))
        report_agreement("H1v vs exp.py CLS on the baseline, out of 33 ('?' counted as other)", cpairs, "CLS", "H1v")
        report_agreement("H1v vs exp.py CLS on the baseline, out of 32 (excluding CLS '?')",
                         [p for p in cpairs if p[1] != "?"], "CLS", "H1v")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except _ProbeFail as e:
        print("REFUSE: %s" % e)
        sys.exit(2)
    except Refuse as e:
        print("REFUSE: %s" % e)
        sys.exit(2)
