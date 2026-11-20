"""BL-819 item 2(b) on s321: which lead classes did not fall from s319, and what the step-reread class reads.

usage: EXTRACT_WIN_END=<window> python3 -I lead_class_value.py <OUT> [<sprint A> <sprint B>]   (default A=321, B=319)
       python3 -I lead_class_value.py --self-test

Read-only. <OUT> is a directory written by extract.py, analyze.py and `roll.py --classes > classes.txt`
(docs/analysis/pipeline-efficiency-s317-s320/README.md). The lead transcripts are read from $EXTRACT_ROOT, default
~/.claude/projects/-Users-n8-git-graph, top-level *.jsonl. Writes nothing. Stdlib only.

Block 1, the fell rule. Per sprint, step and lead class (lead seat, pipeline bucket), per story active h and calls are
summed from classes.jsonl with roll.py's own bucket, relabel and step_base helpers (imported). BL-819's rule (its
"Closing reading" paragraph): a class's cost DID NOT FALL from B to A if its per-story active hours OR its per-story
calls did not fall. Every (step, class) cell present in A is printed with FELL or DID-NOT-FALL. idle-wait is
time-only and is ruled on hours alone.
Control: the same cells parsed from <OUT>/classes.txt (roll.py's rendering) must agree to the printed precision on
every cell (MATCH count against DIFFERS count), so the figures here are derived twice.

Block 2, step-reread. extract.py's predicate: a lead Read of a STEP_RE file (skills/ai-dlc[-update]/steps/<name>.md)
that the unit already read. Every such Read in sprints A and B whose tool_result is not an error is listed and
classed. Each Read carries its unit's compaction EPOCH (the number of isCompactSummary records before it); the
earlier Reads of the same file are split into those of the current epoch and those of earlier epochs, and only
ranges that share at least one line with this Read count ("overlapping"). First rule that applies:
  NEW-RANGE         no earlier Read of the file, in any epoch, overlaps this range: every line returned is unread.
  AFTER-COMPACTION  earlier Reads overlap it, but none in the current epoch: the lead lost that text in a compaction,
                    which is normal operation (operator ruling), so this is the recovery read.
  REPEAT            a current-epoch Read had this exact range and the same tool_result text: nothing new.
  CHANGED           a current-epoch Read had this exact range and different text (the file changed on disk).
  COVERED           a current-epoch Read of a wider range contains this one: the lines were read this epoch.
  OVERLAP           current-epoch Reads overlap it without containing it: part of it was read this epoch.
Ranges: a Read with no offset/limit covers the whole file; (o, l) covers lines o..o+l-1 (offset 1-based, 0 read as 1;
no limit reads to the end). The sprint is extract.py's sprint_of() on the record stamp.
Control: the count of listed re-reads per sprint against classes.jsonl's step-reread calls for that sprint (all
buckets). They can differ only where one message carries a step-reread Read beside a block of higher precedence
(extract.py classes a message by its best block), which is printed as the difference.
An impossible step file name counts 0, and a known step name (implementation) counts above 0.
"""
import collections, glob, hashlib, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROLL_DIR = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts")
sys.path.insert(0, ROLL_DIR)
import roll  # noqa: E402  (roll.py guards its main; importing it runs nothing)

ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
WIN_END = os.environ.get("EXTRACT_WIN_END")
STEP_RE = re.compile(r"skills/ai-dlc(?:-update)?/steps/([A-Za-z0-9_.-]+)\.md")   # extract.py:42, byte-equal
EDGES = [("2026-09-28T19:10:00Z", 314), ("2026-09-30T20:58:00Z", 315), ("2026-10-05T14:00:00Z", 316),
         ("2026-10-12T02:30:00Z", 317), ("2026-10-14T22:00:00Z", 318), ("2026-10-23T09:53:00Z", 319),
         ("2026-10-30T00:10:03Z", 320), ("2026-11-09T00:00:00Z", 321), ("2026-11-13T08:00:00Z", 322),
         ("2026-11-20T04:20:00Z", 323), ("2099-01-01T00:00:00Z", 324)]   # extract.py EDGES
IMPOSSIBLE_STEP = "qzxv-never-step-6630"
ROW = re.compile(r"^\s+(\S+)\s+active\s+([\d.]+) h\s+gap\s+([\d.]+) h\s+calls\s+([\d.]+)\s+tok")


def sprint_of(t):
    for e, n in EDGES:
        if t < e:
            return n


# ---------------- block 1 ----------------
def cells(out):
    """{(sprint, step): {class: [act_s, calls]}} over the lead seat, pipeline bucket, as roll.classes() sums it."""
    relabel, _fam = roll.analyze_defs()
    units = [json.loads(l) for l in open(os.path.join(out, "units.jsonl"))]
    bucket = {u["sess"]: "pipeline" if any(k.split("|", 1)[0] != "pre-step" for k in u["tok"]) else "x"
              for u in units if u["kind"] == "lead"}
    segs = {}
    for l in open(os.path.join(out, "segs.jsonl")):
        s = json.loads(l)
        if s["kind"] == "lead":
            segs[(s["unit"], s["step"])] = s
    cls = collections.defaultdict(list)
    for l in open(os.path.join(out, "classes.jsonl")):
        c = json.loads(l)
        cls[(c["unit"], c["step"])].append(c)
    A = collections.defaultdict(lambda: collections.defaultdict(lambda: collections.defaultdict(float)))
    for (unit, st), s in segs.items():
        if bucket.get(s["sess"]) != "pipeline" or s["sprint"] not in roll.STORIES:
            continue
        key = (s["sprint"], roll.step_base(relabel.get((s["sess"], st), st)))
        for c in cls.get((unit, st), []):
            a = A[key][c["cls"]]
            a[0] += c["active"]; a[1] += c["calls"]
            for m, d in c["tok"].items():
                f = _fam(m)
                for i, n in enumerate(("in", "cw", "cr", "out", "calls")):
                    a["lead_%s_%s" % (f, n)] += d[i]
    return A


def te_usd(a, sprint, mix):
    """roll.classes()'s token-equivalent lead $ for one cell (API $ when the sprint has no local lead call)."""
    m = mix[sprint]
    if sum(m.values()) <= 0 and sprint in roll.FALLBACK:
        m = mix[roll.FALLBACK[sprint]]
    api = roll.usd(a, "lead"); te = roll.usd(a, "lead", True, m)
    return api if te is None else te


_relabel, _fam = roll.analyze_defs()


def rendered(out):
    """{(sprint, step): {class: (h, calls)}} parsed from classes.txt, the control side."""
    d = {}; sp = st = None
    for l in open(os.path.join(out, "classes.txt")):
        m = re.match(r"^== s(\d+) ", l)
        if m:
            sp = int(m.group(1)); continue
        m = re.match(r"^  -- (\S+): segs active", l)
        if m:
            st = m.group(1); continue
        m = ROW.match(l)
        if m and sp and st:
            d.setdefault((sp, st), {})[m.group(1)] = (m.group(2), m.group(4))
    return d


def fell_rule(a_h, a_c, b_h, b_c, cls):
    if cls == "idle-wait":
        return "FELL" if a_h < b_h else "DID-NOT-FALL"
    return "FELL" if (a_h < b_h and a_c < b_c) else "DID-NOT-FALL"


def block1(out, A_, B_):
    A = cells(out); R = rendered(out)
    match = differs = 0
    for (sp, st), C in A.items():
        n = roll.STORIES[sp]
        for k, a in C.items():
            act, calls = a[0], a[1]
            want = R.get((sp, st), {}).get(k)
            got = ("%.3f" % (act / 3600 / n), "%.1f" % (calls / n))
            if want == got:
                match += 1
            else:
                differs += 1
                if differs <= 5:
                    print("  DIFFERS s%d %s %s computed %s rendered %s" % (sp, st, k, got, want))
    print("control: (sprint, step, class) cells, computed against classes.txt: %d MATCH, %d DIFFERS" % (match, differs))
    mix = roll.hosted_mix(list(roll.csv.DictReader(open(os.path.join(out, "steps.csv")))), "lead")
    print("== fell rule, s%d against s%d, per story: active h / calls / lead token-eq $ (lead seat, pipeline bucket)"
          % (A_, B_))
    nf = collections.Counter(); nf_usd = collections.Counter(); out_rows = []; tot = collections.defaultdict(lambda: [0.0, 0.0, 0.0])
    for st in sorted({s for (p, s) in A if p == A_}):
        for k in roll.CLASS_ORDER:
            a = A.get((A_, st), {}).get(k)
            if not a:
                continue
            b = A.get((B_, st), {}).get(k, {})
            ah, ac, au = a[0] / 3600 / roll.STORIES[A_], a[1] / roll.STORIES[A_], te_usd(a, A_, mix) / roll.STORIES[A_]
            bh, bc = b.get(0, 0.0) / 3600 / roll.STORIES[B_], b.get(1, 0.0) / roll.STORIES[B_]
            bu = te_usd(b, B_, mix) / roll.STORIES[B_] if b else 0.0
            v = fell_rule(round(ah, 3), round(ac, 1), round(bh, 3), round(bc, 1), k)
            nf[v] += 1; nf_usd[v] += au * roll.STORIES[A_]
            out_rows.append((st, k, v))
            t = tot[k]; t[0] += a[0]; t[1] += a[1]; t[2] += te_usd(a, A_, mix)
            print("  %-24s %-20s s%d %.3f / %5.1f / $%.2f   s%d %.3f / %5.1f / $%.2f   %s"
                  % (st, k, B_, bh, bc, bu, A_, ah, ac, au, v))
    print("cells: %d FELL ($%.2f s%d lead token-eq, whole sprint), %d DID-NOT-FALL ($%.2f) (rule applied at the printed precision)"
          % (nf["FELL"], nf_usd["FELL"], A_, nf["DID-NOT-FALL"], nf_usd["DID-NOT-FALL"]))
    for k in roll.CLASS_ORDER:
        if k in tot:
            t = tot[k]
            print("  s%d all steps %-20s active %.2f h  calls %d  lead token-eq $%.2f" % (A_, k, t[0] / 3600, t[1], t[2]))
    return out_rows, tot


# ---------------- block 2 ----------------
INF = float("inf")


def lines(rng):
    """(first line, last line) a normalised range reads; no limit reads to the end of the file."""
    o, l = rng
    lo = 1 if o is None else o
    return lo, (INF if l is None else lo + l - 1)


def overlaps(a, b):
    (a0, a1), (b0, b1) = lines(a), lines(b)
    return a0 <= b1 and b0 <= a1


def contains(outer, inner):
    (o0, o1), (i0, i1) = lines(outer), lines(inner)
    return o0 <= i0 and i1 <= o1


def norm_range(inp):
    o = inp.get("offset"); l = inp.get("limit")
    if o is None and l is None:
        return (None, None)
    o = int(o or 1) or 1
    return (o, int(l) if l is not None else None)


def result_text(c):
    x = c.get("content")
    if isinstance(x, list):
        x = "".join(y.get("text", "") for y in x if isinstance(y, dict))
    return x if isinstance(x, str) else json.dumps(x)


RCLASSES = ("NEW-RANGE", "AFTER-COMPACTION", "CHANGED", "OVERLAP", "COVERED", "REPEAT")


def classify(prev_reads, epoch, rng, txt_hash):
    """prev_reads: [(range, hash, epoch)] earlier Reads of this file in the unit; epoch: this Read's epoch."""
    ov = [(r, h, e) for r, h, e in prev_reads if overlaps(r, rng)]
    cur = [(r, h) for r, h, e in ov if e == epoch]
    if not ov:
        return "NEW-RANGE"
    if not cur:
        return "AFTER-COMPACTION"
    same = [h for r, h in cur if lines(r) == lines(rng)]
    if same:
        return "REPEAT" if txt_hash in same else "CHANGED"
    if any(contains(r, rng) for r, _ in cur):
        return "COVERED"
    return "OVERLAP"


# A block outranks step-reread when extract.py's Classer.block() gives it compaction-recovery, snapshot, repair,
# dispatch or gate-run: every Agent/Task/SendMessage; a Bash invoking snapshot-update.sh or a GATE_RUN_RE program,
# or naming pipeline-snapshot.md; an Edit/Write of pipeline-snapshot.md. The dispatch Write (a path a LATER prompt
# names) is not reproduced here; the control line counts what that leaves out.
GATE_RUN_RE = re.compile(r"^(gate-checkpoint\.sh|gate-slice.*|gate-transition\.sh|validate-.*\.sh|.*-validator(\.sh|\.py)?)$")  # extract.py:181
SNAP_RE = re.compile(r"(?<![A-Za-z0-9_.-])pipeline-snapshot\.md(?![A-Za-z0-9_-])")   # extract.py:193


def invoked(cmd):
    """extract.py:184 invoked(), without heredoc stripping (a heredoc body can only add programs here)."""
    out = []
    for seg_ in re.split(r"\|\||&&|[|;&\n]", cmd):
        w = [x.strip("\"'()") for x in seg_.split()]
        while w and (w[0] in ("bash", "sh", "env", "python", "python3") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])):
            w = w[1:]
        if w:
            out.append(os.path.basename(w[0]))
    return out


def outranks(c):
    name = c.get("name"); inp = c.get("input") or {}
    if not isinstance(inp, dict):
        inp = {}
    if name in ("Agent", "Task", "SendMessage"):
        return True
    if name == "Bash":
        cmd = str(inp.get("command") or "")
        prog = invoked(cmd)
        return "snapshot-update.sh" in prog or any(GATE_RUN_RE.match(x) for x in prog) or bool(SNAP_RE.search(cmd))
    if name in ("Edit", "Write"):
        return str(inp.get("file_path") or "").endswith("pipeline-snapshot.md")
    return False


def scan(sprints):
    """Per Read: (sprint, unit, step file, range, class, stamp, message.id, outranked). `outranked` is True when the
    Read's message falls in a compaction-recovery window (extract.py: from an isCompactSummary record to the first
    tool_use that is not Read/Grep/Glob) or carries a tool_use that can earn a higher-precedence class."""
    rows = []
    for f in sorted(glob.glob(os.path.join(ROOT, "*.jsonl"))):
        pend = {}; reads = collections.defaultdict(list); epoch = 0
        recover = False; mid_rec = {}; mid_hi = collections.defaultdict(bool)
        for line in open(f, errors="replace"):
            try:
                r = json.loads(line)
            except ValueError:
                continue
            t = r.get("timestamp") or ""
            if WIN_END and t and t > WIN_END:
                continue
            if r.get("isCompactSummary"):
                recover = True
                epoch += 1
            m = r.get("message") or {}
            if r.get("type") == "assistant":
                mid = m.get("id")
                if mid not in mid_rec:
                    mid_rec[mid] = recover
                for c in m.get("content") or []:
                    if not (isinstance(c, dict) and c.get("type") == "tool_use"):
                        continue
                    if recover and c.get("name") not in ("Read", "Grep", "Glob"):
                        recover = False; mid_rec[mid] = False
                    if outranks(c):
                        mid_hi[mid] = True
                    if c.get("name") == "Read":
                        inp = c.get("input") or {}
                        mm = STEP_RE.search(json.dumps(inp))
                        if mm:
                            pend[c.get("id")] = (mm.group(1), norm_range(inp), t, mid, epoch)
            elif r.get("type") == "user" and isinstance(m.get("content"), list):
                for c in m["content"]:
                    if not (isinstance(c, dict) and c.get("type") == "tool_result" and c.get("tool_use_id") in pend):
                        continue
                    name, rng, t0, mid, ep = pend.pop(c["tool_use_id"])
                    if c.get("is_error"):
                        continue
                    h = hashlib.md5(result_text(c).encode()).hexdigest()
                    sp = sprint_of(t0)
                    if reads[name]:
                        v = classify(reads[name], ep, rng, h)
                        if sp in sprints:
                            rows.append([sp, os.path.basename(f)[:8], name, rng, v, t0, mid, None])
                    reads[name].append((rng, h, ep))
        for row in rows:
            if row[7] is None and row[1] == os.path.basename(f)[:8]:
                row[7] = bool(mid_rec.get(row[6]) or mid_hi.get(row[6]))
    return rows


def block2(out, A_, B_, tot):
    rows = scan({A_, B_})
    ctl = collections.Counter()
    for l in open(os.path.join(out, "classes.jsonl")):
        c = json.loads(l)
        if c["kind"] == "lead" and c["cls"] == "step-reread":
            ctl[c["sprint"]] += c["calls"]
    for sp in (B_, A_):
        rs = [r for r in rows if r[0] == sp]
        k = collections.Counter(r[4] for r in rs)
        mids = {r[6] for r in rs if not r[7]}
        print("== step-reread s%d: %d re-read Reads in %d messages; %d messages neither in a recovery window nor "
              "carrying a higher-precedence block, against classes.jsonl step-reread calls (lead, all buckets) %d: %s"
              % (sp, len(rs), len({r[6] for r in rs}), len(mids), ctl[sp], "MATCH" if len(mids) == ctl[sp] else
                 "DIFFERS by %d" % (len(mids) - ctl[sp])))
        for v in RCLASSES:
            km = len({r[6] for r in rs if r[4] == v})
            print("  %-17s %4d Reads in %4d messages" % (v, k[v], km))
        # the messages the class is charged for, each classed by the Read in it that returns the most unread text
        # (RCLASSES order); REPEAT and COVERED messages returned nothing the lead had not read in this epoch
        per = collections.defaultdict(set)
        for r in rs:
            if not r[7]:
                per[r[6]].add(r[4])
        mk = collections.Counter(next(v for v in RCLASSES if v in s) for s in per.values())
        print("  class-charged messages: " + ", ".join("%s %d" % (v, mk[v]) for v in RCLASSES))
        if sp == A_ and "step-reread" in tot and per:
            t = tot["step-reread"]; nothing = mk["REPEAT"] + mk["COVERED"]
            print("  s%d step-reread class, all steps: %.2f h, %d calls, lead token-eq $%.2f; REPEAT or COVERED (nothing "
                  "unread this epoch) %d of its %d charged messages, so at most %.2f h and $%.2f by call share (an "
                  "apportionment, not a per-message measurement)" % (sp, t[0] / 3600, t[1], t[2], nothing, len(per),
                                                                     t[0] / 3600 * nothing / len(per), t[2] * nothing / len(per)))
        byf = collections.Counter((r[2], r[4]) for r in rs)
        for (name, v), n in sorted(byf.items(), key=lambda x: (-x[1], x[0])):
            print("    %-28s %-17s %3d" % (name, v, n))
        bursts = collections.Counter((r[1], r[2], r[6]) for r in rs if r[4] == "REPEAT")
        first = {}
        for r in rs:
            if r[4] == "REPEAT":
                first.setdefault((r[1], r[2], r[6]), r[5])
        for key, n in sorted(bursts.items(), key=lambda x: first[x[0]]):
            print("    REPEAT message %s unit %s %s: %d Reads" % (first[key], key[0], key[1], n))
    names = collections.Counter(r[2] for r in rows)
    print("control: impossible step file %s re-reads %d; known step implementation re-reads %d"
          % (IMPOSSIBLE_STEP, names[IMPOSSIBLE_STEP], names["implementation"]))


def self_test():
    ok = True
    def chk(got, want, what):
        nonlocal ok
        if got != want:
            ok = False; print("FAIL %s: %s != %s" % (what, got, want))
    W = (None, None)
    chk(classify([(W, "a", 0)], 1, W, "a"), "AFTER-COMPACTION", "whole file read again after a compaction")
    chk(classify([(W, "a", 0)], 0, W, "a"), "REPEAT", "same whole read, same epoch")
    chk(classify([(W, "a", 0)], 0, W, "b"), "CHANGED", "same range, new text")
    chk(classify([((1, 80), "a", 0)], 0, (81, 80), "c"), "NEW-RANGE", "next slice, disjoint")
    chk(classify([((1, 80), "a", 0)], 0, (1, 80), "a"), "REPEAT", "same slice")
    chk(classify([(W, "a", 0)], 0, (1, 80), "d"), "COVERED", "slice of a whole read, same epoch")
    chk(classify([((1, 200), "a", 0)], 0, (150, 100), "e"), "OVERLAP", "partial overlap, same epoch")
    chk(classify([((1, 80), "a", 0)], 0, (81, None), "f"), "NEW-RANGE", "offset with no limit after a slice")
    # two slices, a compaction, then both slices again: each re-read is a recovery read, not a REPEAT
    seq = [((1, 80), "a", 0), ((81, 80), "b", 0)]
    chk(classify(seq, 1, (1, 80), "a"), "AFTER-COMPACTION", "first slice after a compaction")
    seq.append(((1, 80), "a", 1))
    chk(classify(seq, 1, (81, 80), "b"), "AFTER-COMPACTION", "second slice after a compaction")
    seq.append(((81, 80), "b", 1))
    chk(classify(seq, 1, (81, 80), "b"), "REPEAT", "the same slice a third time, same epoch")
    chk(classify([(W, "a", 0), ((1, 80), "a", 1)], 1, (200, 10), "g"), "AFTER-COMPACTION",
        "lines read only before the compaction")
    chk(fell_rule(0.1, 5.0, 0.2, 4.0, "merge"), "DID-NOT-FALL", "calls rose")
    chk(fell_rule(0.1, 3.0, 0.2, 4.0, "merge"), "FELL", "both fell")
    chk(fell_rule(0.2, 3.0, 0.2, 4.0, "merge"), "DID-NOT-FALL", "hours flat")
    chk(fell_rule(0.1, 0.0, 0.2, 0.0, "idle-wait"), "FELL", "idle-wait on hours")
    print("self-test", "ok" if ok else "FAILED")
    return 0 if ok else 1


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out = sys.argv[1]
    A_ = int(sys.argv[2]) if len(sys.argv) > 2 else 321
    B_ = int(sys.argv[3]) if len(sys.argv) > 3 else 319
    print("# lead_class_value.py window EXTRACT_WIN_END=%s, transcripts %s, sprints %d against %d" % (WIN_END, ROOT, A_, B_))
    _rows, tot = block1(out, A_, B_)
    block2(out, A_, B_, tot)


if __name__ == "__main__":
    main()
