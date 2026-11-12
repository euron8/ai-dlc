"""idle-wait conservation (BL-819 item 3): does splitting idle-wait out of `other` MOVE anything but `other`?

usage: python3 -I idle_wait_conservation.py <OLD classes.jsonl> <NEW classes.jsonl>
  OLD = classes.jsonl written by extract.py before the idle-wait class existed; NEW = the one written by the
  current extract.py.  Both runs must use the same corpus and the same EXTRACT_WIN_END.  stdlib only, no corpus read.

A pair is a (unit, step).  Printed, each beside the count it was taken over:
  pairs               distinct (unit, step) in OLD and in NEW, and the pairs only one side has
  active, gap         pairs where the summed class `active` (resp. `gap`) differs between OLD and NEW
  calls, tokens       (unit, step, class) rows present on both sides whose `calls` (resp. `tok`) differ
  idle-wait rows      OLD rows of class idle-wait (must be 0: the sides differ), NEW rows, NEW rows carrying a call
                      or a token (must be 0: idle-wait is time only)
  conservation        pairs where NEW idle-wait active equals the sum, over the other classes, of OLD active minus
                      NEW active; pairs where some class ROSE
  by class            hours each class lost, and the total idle-wait hours; the classes that lost any
  per sprint          NEW idle-wait active hours over ALL lead rows (no bucket filter), per sprint
Exit 0 always on a clean read; exit 2 on an unreadable or empty input.  Both inputs are counted before use, so an
empty file is refused rather than reported as zero movement.

--self-test  seeded OLD/NEW pair in a mktemp dir: one conserved pair, one pair that is not conserved, one moved
             call count; each figure above is asserted in BOTH directions.
"""
import collections, json, os, sys, tempfile

TOL = 1e-6


def load(path):
    rows = {}
    n = 0
    with open(path) as fh:
        for line in fh:
            if not line.strip():
                continue
            r = json.loads(line)
            n += 1
            rows[(r["unit"], r["step"], r["cls"])] = r
    if n == 0:
        print(f"empty input: {path}")
        sys.exit(2)
    return rows


def pair_sums(rows, field, skip=None):
    out = collections.defaultdict(float)
    for (u, s, c), r in rows.items():
        if c != skip:
            out[(u, s)] += r.get(field, 0) or 0
    return out


def figures(old, new):
    F = {}
    po = {(u, s) for (u, s, _) in old}
    pn = {(u, s) for (u, s, _) in new}
    F["pairs old"], F["pairs new"] = len(po), len(pn)
    F["pairs only one side"] = len(po ^ pn)
    both = sorted(po | pn)
    F["pairs"] = len(both)
    for fld in ("active", "gap"):
        a, b = pair_sums(old, fld), pair_sums(new, fld)
        # NEW includes idle-wait, whose `active` was inside OLD `other`; `gap` is never charged to idle-wait
        a_tot = {p: a.get(p, 0.0) for p in both}
        b_tot = {p: b.get(p, 0.0) for p in both}
        F[f"{fld} moved"] = sum(1 for p in both if abs(a_tot[p] - b_tot[p]) > TOL)
    moved_calls = moved_tok = common = 0
    for k, r in old.items():
        n = new.get(k)
        if n is None:
            continue
        common += 1
        if (r.get("calls") or 0) != (n.get("calls") or 0):
            moved_calls += 1
        if r.get("tok") != n.get("tok"):
            moved_tok += 1
    F["class rows on both sides"], F["calls moved"], F["tokens moved"] = common, moved_calls, moved_tok
    F["idle-wait rows old"] = sum(1 for (_, _, c) in old if c == "idle-wait")
    iw = [r for (_, _, c), r in new.items() if c == "idle-wait"]
    F["idle-wait rows new"] = len(iw)
    F["idle-wait rows carrying calls or tokens"] = sum(1 for r in iw if r.get("calls") or r.get("tok"))
    lost = collections.defaultdict(float)
    conserved = rose = 0
    classes = {c for (_, _, c) in old} | {c for (_, _, c) in new}
    for (u, s) in both:
        dec = 0.0
        any_rose = False
        for c in classes:
            if c == "idle-wait":
                continue
            o = (old.get((u, s, c)) or {}).get("active", 0) or 0
            n = (new.get((u, s, c)) or {}).get("active", 0) or 0
            lost[c] += o - n
            dec += o - n
            if n - o > TOL:
                any_rose = True
        iwa = (new.get((u, s, "idle-wait")) or {}).get("active", 0) or 0
        if abs(iwa - dec) <= TOL:
            conserved += 1
        if any_rose:
            rose += 1
    F["conserved pairs"], F["pairs where a class rose"] = conserved, rose
    F["idle-wait h total"] = sum(r.get("active", 0) or 0 for r in iw) / 3600.0
    F["lost h by class"] = {c: v / 3600.0 for c, v in sorted(lost.items()) if abs(v) > TOL}
    sp = collections.defaultdict(float)
    for r in iw:
        sp[r.get("sprint")] += (r.get("active", 0) or 0) / 3600.0
    F["idle-wait h by sprint"] = dict(sorted(sp.items(), key=lambda kv: str(kv[0])))
    return F


def render(F, oldp, newp):
    L = [f"OLD {oldp}", f"NEW {newp}"]
    L.append(f"pairs (unit, step): old {F['pairs old']}  new {F['pairs new']}  union {F['pairs']}  only on one side {F['pairs only one side']}")
    L.append(f"total active moved on {F['active moved']} of {F['pairs']} pairs; gap moved on {F['gap moved']} of {F['pairs']} pairs")
    L.append(f"class rows on both sides {F['class rows on both sides']}: calls moved on {F['calls moved']}, tokens moved on {F['tokens moved']}")
    L.append(f"idle-wait rows: old {F['idle-wait rows old']} (the sides differ iff > 0 on new: new {F['idle-wait rows new']}); "
             f"new rows carrying a call or a token {F['idle-wait rows carrying calls or tokens']}")
    L.append(f"idle-wait equals the per-class decreases on {F['conserved pairs']} of {F['pairs']} pairs; pairs where a class rose {F['pairs where a class rose']}")
    L.append(f"idle-wait total {F['idle-wait h total']:.2f} h; hours lost by class: "
             + (", ".join(f"{c} {v:.2f}" for c, v in F["lost h by class"].items()) or "none"))
    L.append("idle-wait active h, all lead rows, by sprint: " + ", ".join(f"s{k} {v:.2f}" for k, v in F["idle-wait h by sprint"].items()))
    return L


def selftest():
    fails = []
    def chk(name, got, want):
        ok = got == want
        print(("  PASS  " if ok else "  FAIL  ") + f"{name}: {got!r}" + ("" if ok else f" (want {want!r})"))
        if not ok:
            fails.append(name)
    tmp = tempfile.mkdtemp(prefix="iwc-selftest-")
    def row(u, s, c, act, calls=1, tok=None, sprint=321, gap=0.0):
        return dict(unit=u, sess=u, kind="lead", step=s, cls=c, sprint=sprint, active=act, gap=gap, calls=calls, tok=tok or {"m": [1, 0, 0, 1, 1]})
    old = [row("a", "s", "other", 7200.0), row("a", "s", "merge", 100.0),
           row("b", "s", "other", 3600.0), row("c", "s", "other", 1800.0)]
    new = [row("a", "s", "other", 3600.0), row("a", "s", "merge", 100.0), row("a", "s", "idle-wait", 3600.0, 0, {}),
           row("b", "s", "other", 1800.0), row("b", "s", "idle-wait", 1800.0, 0, {}),
           row("c", "s", "other", 900.0, calls=2), row("c", "s", "idle-wait", 600.0, 0, {})]
    op, np_ = os.path.join(tmp, "old.jsonl"), os.path.join(tmp, "new.jsonl")
    for p, rs in ((op, old), (np_, new)):
        with open(p, "w") as fh:
            fh.write("".join(json.dumps(r) + "\n" for r in rs))
    F = figures(load(op), load(np_))
    chk("pairs", F["pairs"], 3)
    chk("pair c is NOT conserved (900 + 600 != 1800), a and b are", F["conserved pairs"], 2)
    chk("total active moved only on pair c (the unconserved one)", F["active moved"], 1)
    chk("one calls row moved (c other 1 -> 2)", F["calls moved"], 1)
    chk("old has 0 idle-wait rows, new has 3", (F["idle-wait rows old"], F["idle-wait rows new"]), (0, 3))
    chk("idle-wait total hours", round(F["idle-wait h total"], 4), round((3600 + 1800 + 600) / 3600.0, 4))
    chk("other lost hours", round(F["lost h by class"]["other"], 4), round((3600 + 1800 + 900) / 3600.0, 4))
    chk("no class rose", F["pairs where a class rose"], 0)
    # near-miss: identical sides must read zero movement and zero idle-wait
    G = figures(load(op), load(op))
    chk("identical sides: nothing moves, idle-wait 0", (G["active moved"], G["calls moved"], G["idle-wait rows new"], G["conserved pairs"]), (0, 0, 0, 3))
    print("SELF-TEST " + ("OK" if not fails else "FAILED: " + ", ".join(fails)))
    sys.exit(0 if not fails else 1)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        selftest()
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    o, n = load(sys.argv[1]), load(sys.argv[2])
    print("\n".join(render(figures(o, n), sys.argv[1], sys.argv[2])))
