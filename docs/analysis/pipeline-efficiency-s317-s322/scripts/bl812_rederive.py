"""BL-812's recorded readings, re-derived from one or two extractor output directories (BL-812 item 1; BL-1003 item 3).

usage:
  python3 -I bl812_rederive.py readings <OUT_old> <OUT_cur> <set>
      <set> is one of b255 (the b255 whole-sprint, per-step and "Against the projections" figures), b256 (the sprint-review
      "both labels" figures) or projc (Projection (c), carry-over-evaluation against s322). Prints, per reading, the
      recorded figure, the old extractor's value, the current extractor's value, and two verdicts: old against recorded
      (the control: the old extractor must reproduce the recorded figure at the recorded window) and current against old
      (the BL-1003 differential). split is the 18:53:06Z split Projection (c) records (20 / 61 spawns).
  python3 -I bl812_rederive.py rose <OUT> <sprint A> <sprint B>
      Every step label whose per-story cost in A exceeds B's, on subagent $ (spawns.jsonl) and token-equivalent $ (seats).
  python3 -I bl812_rederive.py cmp-spawns <OUT_old> <OUT_cur> <N>
      Whether spawns.jsonl rows of sprints <= N are identical between the two extractors.
  python3 -I bl812_rederive.py window <OUT> <transcript dir> <transcript prefix> [...]
      The window control: latest unit end, sprints held, and each named transcript's first record (must be later).
  python3 -I bl812_rederive.py row <OUT> <sprint> [<sprint> ...]
      The item 1 row for each sprint: machine hours (lead active plus agent wait, operator wait excluded), tokens,
      subagent dollars and spawns, per story, whole sprint and per step. Control: s321 against s319 re-derives the figures
      BL-812's b255 paragraph records for them (`roll.py --seats` pipeline bucket $75.1 against $88.1 among them).

Each <OUT> is a directory written by extract.py, spawns.py, analyze.py, `roll.py > roll.txt` and `roll.py --seats >
seats.txt` (docs/analysis/pipeline-efficiency-s317-s320/README.md). Read-only; writes nothing. Stdlib only.
"""
import json, os, re, sys, collections

STORIES = {317: 21, 318: 13, 319: 20, 320: 13, 321: 25, 322: 8}
IMPOSSIBLE = "QZXV-NO-SUCH-STEP-5512"
STEPS = ["implementation", "gate-validation[implementation]", "stories-test-strategy", "requirements", "architecture",
         "sprint-review", "deploy-validate", "carry-over-evaluation"]


def spawns(out):
    return [json.loads(l) for l in open(os.path.join(out, "spawns.jsonl"))]


def agg(rows, sprint, steps=None):
    s = [r for r in rows if int(r["sprint"]) == sprint and (steps is None or r["step"] in steps)]
    return len(s), sum(r.get("usd") or 0 for r in s), sum(r.get("minutes") or 0 for r in s), sum(r.get("tok") or 0 for r in s)


TOTAL = re.compile(r"^s(\d+) TOTAL elapsed ([\d.]+)h gap-inclusive \(active ([\d.]+)h \+ gap ([\d.]+)h = agentwait ([\d.]+)h \+ opwait ([\d.]+)h\).*?token-eq \$(\d+) .*?per story \((\d+)\): ([\d.]+)h, API \$([\d.]+), token-eq \$([\d.]+)")


def totals(out):
    t = {}
    for l in open(os.path.join(out, "roll.txt")):
        m = TOTAL.match(l)
        if m:
            t[int(m.group(1))] = dict(active=float(m.group(3)), agentwait=float(m.group(5)), opwait=float(m.group(6)),
                                      api_ps=float(m.group(10)), te_ps=float(m.group(11)))
    return t


SEAT = re.compile(r"^\s+s(\d+) (?:pipeline (\S+) )?\((\d+) stories\): ([\d.]+) h gap-inclusive \(gap ([\d.]+) h\), token-equivalent \$([\d.]+) \(API \$([\d.]+)\), ([\d.]+)M tokens; lead active ([\d.]+) h, lead \$([\d.]+)(?: \(API \$([\d.]+)\))?, subagent active ([\d.]+) h, subagent \$([\d.]+)")


def seats(out):
    """{(sprint, step or 'ALL'): dict} from seats.txt; 'ALL' is the '-- the whole pipeline bucket [pipeline]' block."""
    d = {}; block = None
    for l in open(os.path.join(out, "seats.txt")):
        if l.startswith("--"):
            block = "ALL" if "whole pipeline bucket" in l else None
            continue
        m = SEAT.match(l)
        if not m:
            continue
        key = m.group(2) or (block if block else None)
        if key is None:
            continue
        v = dict(h=float(m.group(4)), te=float(m.group(6)), api=float(m.group(7)), mtok=float(m.group(8)),
                 lead_h=float(m.group(9)), lead_te=float(m.group(10)), sub_h=float(m.group(12)), sub=float(m.group(13)))
        d.setdefault((int(m.group(1)), key), v)
    return d


def f2(x):
    return "%.2f" % x


def verdict(a, b):
    return "MATCH" if a == b else "DIFFERS"


def readings(set_, o_old, o_cur):
    """[(label, recorded, fn(out) -> str)] for one reading set."""
    R = []
    if set_ == "b255":
        for sp in (321, 319):
            n = STORIES[sp]
            rec = {321: ("75.18", "49.36", "3.82", "95.5", "94.7", "202.0", "75.1"),
                   319: ("88.27", "78.05", "4.65", "111.7", "111.7", "255.3", "88.1")}[sp]
            R.append(("s%d subagent $/story, spawns.jsonl all buckets" % sp, rec[0], lambda o, sp=sp, n=n: f2(agg(spawns(o), sp)[1] / n)))
            R.append(("s%d spawns/story" % sp, rec[1], lambda o, sp=sp, n=n: f2(agg(spawns(o), sp)[0] / n)))
            R.append(("s%d machine h/story (active + agentwait)" % sp, rec[2],
                      lambda o, sp=sp, n=n: f2((totals(o)[sp]["active"] + totals(o)[sp]["agentwait"]) / n)))
            R.append(("s%d token-eq $/story, roll.txt TOTAL" % sp, rec[3], lambda o, sp=sp: "%.1f" % totals(o)[sp]["te_ps"]))
            R.append(("s%d API $/story, roll.txt TOTAL" % sp, rec[4], lambda o, sp=sp: "%.1f" % totals(o)[sp]["api_ps"]))
            R.append(("s%d pipeline-bucket M tokens/story, seats ALL" % sp, rec[5], lambda o, sp=sp: "%.1f" % seats(o)[(sp, "ALL")]["mtok"]))
            R.append(("s%d subagent $/story, roll.py --seats pipeline bucket" % sp, rec[6], lambda o, sp=sp: "%.1f" % seats(o)[(sp, "ALL")]["sub"]))
        per = {"implementation": ("6.16", "11.46", "24.80", "26.08"), "gate-validation[implementation]": ("5.04", "6.43", "6.70", "4.61"),
               "stories-test-strategy": ("17.12", "23.59", "15.55", "22.06"), "requirements": ("6.56", "10.29", "7.80", "11.70"),
               "architecture": ("4.72", "10.41", "6.75", "9.48"), "sprint-review": ("6.60", "8.25", "3.65", "1.93"),
               "deploy-validate": ("1.80", "4.01", "0.45", "0.56"), "carry-over-evaluation": (None, None, "4.40", "4.33")}
        for st in STEPS:
            r = per[st]
            for sp, (ns, ds) in ((321, (r[0], r[1])), (319, (r[2], r[3]))):
                if ns is None:
                    R.append(("s%d %s spawns (recorded: not run)" % (sp, st), "0", lambda o, sp=sp, st=st: "%d" % agg(spawns(o), sp, {st})[0]))
                    continue
                n = STORIES[sp]
                R.append(("s%d %s spawns/story" % (sp, st), ns, lambda o, sp=sp, st=st, n=n: f2(agg(spawns(o), sp, {st})[0] / n)))
                R.append(("s%d %s subagent $/story" % (sp, st), ds, lambda o, sp=sp, st=st, n=n: f2(agg(spawns(o), sp, {st})[1] / n)))
        IMP = {"implementation", "gate-validation[implementation]"}
        R.append(("s321 combined row spawns/story", "11.20", lambda o: f2(agg(spawns(o), 321, IMP)[0] / 25)))
        R.append(("s319 combined row spawns/story", "31.50", lambda o: f2(agg(spawns(o), 319, IMP)[0] / 20)))
        R.append(("s319 combined row subagent $/story", "30.68", lambda o: f2(agg(spawns(o), 319, IMP)[1] / 20)))
        R.append(("s321 implementation token-eq $/story (seats)", "15.8", lambda o: "%.1f" % seats(o)[(321, "implementation")]["te"]))
        R.append(("s321 gate[implementation] token-eq $/story (seats)", "9.7", lambda o: "%.1f" % seats(o)[(321, "gate[implementation]")]["te"]))
        R.append(("s321 implementation h gap-incl/story (seats)", "0.68", lambda o: f2(seats(o)[(321, "implementation")]["h"])))
        R.append(("s321 gate[implementation] h gap-incl/story (seats)", "0.45", lambda o: f2(seats(o)[(321, "gate[implementation]")]["h"])))
        R.append(("s319 implementation h gap-incl/story (seats)", "1.24", lambda o: f2(seats(o)[(319, "implementation")]["h"])))
        R.append(("s319 gate[implementation] h gap-incl/story (seats)", "0.85", lambda o: f2(seats(o)[(319, "gate[implementation]")]["h"])))
        R.append(("s321 combined agent-minutes/story (spawn minutes)", "125.1", lambda o: "%.1f" % (agg(spawns(o), 321, IMP)[2] / 25)))
        R.append(("s319 combined agent-minutes/story (spawn minutes)", "321.6", lambda o: "%.1f" % (agg(spawns(o), 319, IMP)[2] / 20)))
        R.append(("s321 stories-test-strategy token-eq $/story (seats)", "26.9", lambda o: "%.1f" % seats(o)[(321, "stories-test-strategy")]["te"]))
        R.append(("s321 stories-test-strategy API $/story (seats)", "26.1", lambda o: "%.1f" % seats(o)[(321, "stories-test-strategy")]["api"]))
        R.append(("s321 stories-test-strategy h gap-incl/story (seats)", "0.79", lambda o: f2(seats(o)[(321, "stories-test-strategy")]["h"])))
        R.append(("s319 stories-test-strategy h gap-incl/story (seats)", "0.78", lambda o: f2(seats(o)[(319, "stories-test-strategy")]["h"])))
    elif set_ == "b256":
        SR = {"sprint-review"}; GSR = {"gate-validation[sprint-review]"}; BOTH = SR | GSR
        for sp, rec in ((319, ("73", "148", "98.99", "75", "60.49", "4.95")), (321, ("165", "169", "209.09", "4", "2.78", "8.36"))):
            n = STORIES[sp]
            R.append(("s%d sprint-review only spawns" % sp, rec[0], lambda o, sp=sp: "%d" % agg(spawns(o), sp, SR)[0]))
            R.append(("s%d both labels spawns" % sp, rec[1], lambda o, sp=sp: "%d" % agg(spawns(o), sp, BOTH)[0]))
            R.append(("s%d both labels $" % sp, rec[2], lambda o, sp=sp: f2(agg(spawns(o), sp, BOTH)[1])))
            R.append(("s%d gate-validation[sprint-review] spawns" % sp, rec[3], lambda o, sp=sp: "%d" % agg(spawns(o), sp, GSR)[0]))
            R.append(("s%d gate-validation[sprint-review] $" % sp, rec[4], lambda o, sp=sp: f2(agg(spawns(o), sp, GSR)[1])))
            R.append(("s%d both labels $/story" % sp, rec[5], lambda o, sp=sp, n=n: f2(agg(spawns(o), sp, BOTH)[1] / n)))
        R.append(("s321 deploy-validate spawns, $", "45, 100.18", lambda o: "%d, %s" % (agg(spawns(o), 321, {"deploy-validate"})[0], f2(agg(spawns(o), 321, {"deploy-validate"})[1]))))
    elif set_ == "projc":
        CO = {"carry-over-evaluation"}; GCO = {"gate-validation[carry-over-evaluation]"}
        R.append(("s322 carry-over-evaluation spawns/story", "11.50", lambda o: f2(agg(spawns(o), 322, CO)[0] / 8)))
        R.append(("s322 carry-over-evaluation $/story", "23.02", lambda o: f2(agg(spawns(o), 322, CO)[1] / 8)))
        R.append(("s322 carry-over-evaluation spawns", "92", lambda o: "%d" % agg(spawns(o), 322, CO)[0]))
        R.append(("s322 carry-over-evaluation agent-h", "24.29", lambda o: f2(agg(spawns(o), 322, CO)[2] / 60)))
        R.append(("s322 gate-validation[carry-over-evaluation] spawns", "81", lambda o: "%d" % agg(spawns(o), 322, GCO)[0]))
        R.append(("s322 gate-validation[carry-over-evaluation] $", "174.47", lambda o: f2(agg(spawns(o), 322, GCO)[1])))
        R.append(("s322 gate-validation[carry-over-evaluation] agent-h", "27.19", lambda o: f2(agg(spawns(o), 322, GCO)[2] / 60)))
        R.append(("s319 carry-over-evaluation spawns, $", "88, 86.66", lambda o: "%d, %s" % (agg(spawns(o), 319, CO)[0], f2(agg(spawns(o), 319, CO)[1]))))
        R.append(("s320 carry-over-evaluation spawns, $", "132, 158.55", lambda o: "%d, %s" % (agg(spawns(o), 320, CO)[0], f2(agg(spawns(o), 320, CO)[1]))))
        R.append(("s322 requirements spawns, $", "(not recorded)", lambda o: "%d, %s" % (agg(spawns(o), 322, {"requirements"})[0], f2(agg(spawns(o), 322, {"requirements"})[1]))))
    elif set_ == "split":
        GCO = {"gate-validation[carry-over-evaluation]"}; CUT = "2026-11-09T14:00:00"

        def part(o, early):
            s = [r for r in spawns(o) if int(r["sprint"]) == 322 and r["step"] in GCO and ((r["start"] < CUT) == early)]
            return len(s), sum(r.get("usd") or 0 for r in s), sum(r.get("minutes") or 0 for r in s)
        R.append(("s322 gate-validation[carry-over-evaluation] spawns, $, agent-h", "81, 174.47, 27.19",
                  lambda o: "%d, %s, %s" % (agg(spawns(o), 322, GCO)[0], f2(agg(spawns(o), 322, GCO)[1]), f2(agg(spawns(o), 322, GCO)[2] / 60))))
        R.append(("  of it starting before 14:00Z (planning-gate work)", "20, 7.06, 0.37",
                  lambda o: "%d, %s, %s" % (part(o, True)[0], f2(part(o, True)[1]), f2(part(o, True)[2] / 60))))
        R.append(("  of it starting 14:00Z or later (requirements work)", "61, 167.41, 26.82",
                  lambda o: "%d, %s, %s" % (part(o, False)[0], f2(part(o, False)[1]), f2(part(o, False)[2] / 60))))
        R.append(("s322 requirements spawns, $", "(not recorded)",
                  lambda o: "%d, %s" % (agg(spawns(o), 322, {"requirements"})[0], f2(agg(spawns(o), 322, {"requirements"})[1]))))
        R.append(("s319 carry-over-evaluation spawns, $", "88, 86.66",
                  lambda o: "%d, %s" % (agg(spawns(o), 319, {"carry-over-evaluation"})[0], f2(agg(spawns(o), 319, {"carry-over-evaluation"})[1]))))
    else:
        sys.exit(__doc__)
    R.append(("impossible step spawns (must be 0)", "0", lambda o: "%d" % agg(spawns(o), 321 if set_ != "projc" else 322, {IMPOSSIBLE})[0]))
    nm = no = nd = 0
    for label, rec, fn in R:
        a, b = fn(o_old), fn(o_cur)
        v1 = verdict(a, rec) if not rec.startswith("(") else "n/a"
        v2 = verdict(b, a)
        nm += v1 == "MATCH"; no += v1 == "DIFFERS"; nd += v2 == "DIFFERS"
        print("%-58s recorded %-12s old %-12s cur %-12s old-vs-recorded %-7s cur-vs-old %s" % (label, rec, a, b, v1, v2))
    print("SUMMARY set=%s readings=%d old-vs-recorded MATCH=%d DIFFERS=%d; cur-vs-old DIFFERS=%d" % (set_, len(R), nm, no, nd))


def row(out, sprints):
    rows = spawns(out); t = totals(out); s = seats(out)
    for sp in sprints:
        n = STORIES[sp]; c = agg(rows, sp); a = s[(sp, "ALL")]
        print("s%d whole sprint, per story (%d stories): machine h %.2f ((active %.1f + agentwait %.1f) / %d; opwait %.1f excluded); "
              "subagent $%.2f (spawns.jsonl, all buckets) / $%.1f (roll.py --seats pipeline bucket); spawns %.2f; "
              "token-eq $%.1f API $%.1f (roll.txt TOTAL); pipeline-bucket tokens %.1fM; seats: %.2f h gap-inclusive, "
              "lead active %.2f h lead $%.1f, subagent active %.2f h subagent $%.1f" % (
                  sp, n, (t[sp]["active"] + t[sp]["agentwait"]) / n, t[sp]["active"], t[sp]["agentwait"], n, t[sp]["opwait"],
                  c[1] / n, a["sub"], c[0] / n, t[sp]["te_ps"], t[sp]["api_ps"], a["mtok"], a["h"], a["lead_h"], a["lead_te"], a["sub_h"], a["sub"]))
        ps = per_step(out, sp)
        steps = sorted(set(ps) | {r["step"] for r in rows if int(r["sprint"]) == sp})
        sa = sw = 0.0
        for st in steps:
            k = agg(rows, sp, {st}); m = ps.get(st, [0.0, 0.0, 0.0])
            sa += m[0]; sw += m[1]
            print("   s%d %-40s machine h/story %5.2f  tokens/story %6.1fM  subagent $/story %7.2f  spawns/story %6.2f" % (
                sp, st, (m[0] + m[1]) / n, m[2] / 1e6 / n, k[1] / n, k[0] / n))
        print("   control s%d per-step machine h summed %.1f + %.1f against roll.txt TOTAL %.1f + %.1f  %s" % (
            sp, sa, sw, t[sp]["active"], t[sp]["agentwait"],
            "MATCH" if ("%.1f %.1f" % (sa, sw)) == ("%.1f %.1f" % (t[sp]["active"], t[sp]["agentwait"])) else "DIFFERS"))
    print("impossible step spawns: %d" % agg(rows, sprints[0], {IMPOSSIBLE})[0])


def per_step(out, sp):
    """{step: [lead active h, agent wait h, tokens]} over steps.csv's pipeline-bucket rows (roll.py's own population;
    tokens are every _in/_out/_cr/_cw column, lead and subagent seats, as roll.py's TOTAL sums them)."""
    import csv
    d = {}
    for r in csv.DictReader(open(os.path.join(out, "steps.csv"))):
        if r["bucket"] != "pipeline" or int(r["sprint"]) != sp:
            continue
        a = d.setdefault(r["step"], [0.0, 0.0, 0.0])
        a[0] += float(r["active_h"]); a[1] += float(r["agent_wait_h"])
        a[2] += sum(float(v or 0) for c, v in r.items() if c.endswith(("_in", "_out", "_cr", "_cw")))
    return d


def window(out, transcript_dir, first_after):
    """The s322 window control (contract F-B1): the latest unit end in <out>/units.jsonl, the sprints it holds, and the
    first timestamped record of each named transcript prefix, which must fall AFTER the window."""
    import glob
    last = None; sprints = collections.Counter()
    for l in open(os.path.join(out, "units.jsonl")):
        u = json.loads(l); sprints[u["sprint"]] += 1
        if u.get("last") and (last is None or u["last"] > last):
            last = u["last"]
    print("latest unit end %s; units per sprint %s" % (last, dict(sorted(sprints.items(), key=lambda kv: str(kv[0])))))
    for pre in first_after:
        fs = glob.glob(os.path.join(transcript_dir, pre + "*.jsonl"))
        for f in fs:
            ts = None
            for l in open(f, errors="replace"):
                try:
                    r = json.loads(l)
                except Exception:
                    continue
                if r.get("timestamp"):
                    ts = r["timestamp"]; break
            print("transcript %s first record %s  %s" % (os.path.basename(f)[:8], ts, "AFTER the latest unit end" if ts and last and ts > last else "NOT after"))
        if not fs:
            print("transcript %s: no file (a missing control is not a pass)" % pre)


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) == 4 and a[0] == "readings":
        readings(a[3], a[1], a[2])
    elif len(a) >= 3 and a[0] == "row":
        row(a[1], [int(x) for x in a[2:]])
    elif len(a) >= 4 and a[0] == "window":
        window(a[1], a[2], a[3:])
    elif len(a) == 4 and a[0] == "rose":
        # every step whose per-story cost in sprint A exceeds sprint B's, on two measures: subagent $ (spawns.jsonl,
        # all buckets) and token-equivalent $ (roll.py --seats, pipeline bucket; its gate[x] is gate-validation[x])
        o, A, B = a[1], int(a[2]), int(a[3]); rows = spawns(o); s = seats(o)
        steps = sorted({r["step"] for r in rows if int(r["sprint"]) in (A, B)})
        for st in steps:
            x = agg(rows, A, {st})[1] / STORIES[A]; y = agg(rows, B, {st})[1] / STORIES[B]
            k = "gate[" + st[16:-1] + "]" if st.startswith("gate-validation[") else st
            te = (s.get((A, k), {}).get("te"), s.get((B, k), {}).get("te"))
            print("%-40s subagent $/story s%d %7.2f s%d %7.2f %-5s | token-eq s%d %s s%d %s %s" % (
                st, A, x, B, y, "ROSE" if x > y else "", A, te[0], B, te[1],
                "ROSE" if te[0] is not None and te[1] is not None and te[0] > te[1] else ("" if None not in te else "n/a")))
    elif len(a) == 4 and a[0] == "cmp-spawns":
        # spawns.jsonl rows of sprints <= N, old against current: equal row sets mean no spawn-label reading over those
        # sprints can move between the two extractors at that window. The rows of sprints > N are counted beside it.
        mx = int(a[3]); sides = []
        for o in (a[1], a[2]):
            rs = [json.dumps(r, sort_keys=True) for r in spawns(o)]
            sides.append((sorted(x for x in rs if json.loads(x)["sprint"] <= mx), sum(1 for x in rs if json.loads(x)["sprint"] > mx)))
        print("spawns.jsonl rows of sprint <= %d: old %d, current %d, %s; rows of later sprints: old %d, current %d; "
              "rows whose step differs among the later ones: %d" % (
                  mx, len(sides[0][0]), len(sides[1][0]), "IDENTICAL" if sides[0][0] == sides[1][0] else "DIFFER",
                  sides[0][1], sides[1][1],
                  len({(json.loads(x)["unit"], json.loads(x)["step"]) for x in [r for r in (json.dumps(q, sort_keys=True) for q in spawns(a[1])) if json.loads(r)["sprint"] > mx]}
                      ^ {(json.loads(x)["unit"], json.loads(x)["step"]) for x in [r for r in (json.dumps(q, sort_keys=True) for q in spawns(a[2])) if json.loads(r)["sprint"] > mx]}) // 2))
    else:
        sys.exit(__doc__)
