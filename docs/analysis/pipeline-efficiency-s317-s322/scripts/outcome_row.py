"""The efficiency outcome row with the lead seat beside the subagent seat, per sprint and per step (BL-812 item 1,
BL-819 item 3: "lead hours and lead tokens join every efficiency outcome ... per step").

usage: python3 -I outcome_row.py <OUT> <sprint> [<sprint> ...]

<OUT> is a directory written by extract.py, spawns.py, analyze.py, `roll.py > roll.txt` and `roll.py --seats >
seats.txt` (docs/analysis/pipeline-efficiency-s317-s320/README.md). Read-only; writes nothing. Stdlib only.

Per sprint, per story, the whole pipeline bucket and then every step (roll.py's step grouping, step_base: a
gate-validation[x] label is gate[x]):
  lead     active h, calls, tokens, $ token-equivalent (API beside it)   roll.py seat_sum over steps.csv
  subagent active h, $ token-equivalent (API beside it)                  roll.py seat_sum over steps.csv
  spawns, subagent $ (spawns.jsonl, all buckets)                        bl812_rederive.agg
  machine h (lead active plus agent wait; operator wait excluded)        bl812_rederive.per_step
Pricing, FALLBACK and PENDING handling are roll.py's own (imported, not restated); STORIES is roll.py's.

Controls, printed per sprint (each must read MATCH; an impossible step must read 0):
  C1 additivity: lead h, lead $, lead tokens and subagent $ summed over the steps equal the whole-bucket seat_sum.
  C2 rendering: every step's lead active h and lead $ equal the figures parsed from <OUT>/seats.txt (bl812_rederive's
     SEAT parser) at the printed precision, so a stale seats.txt or a wrong step join reads DIFFERS.
  C3 machine h summed over the steps equals roll.txt TOTAL (active + agent wait).
  C4 spawns.jsonl spawns and subagent $ summed over the steps equal the sprint's all-bucket totals.
"""
import collections, csv, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
sys.path.insert(0, HERE)
import roll            # noqa: E402
import bl812_rederive as B   # noqa: E402

IMPOSSIBLE = "QZXV-NO-SUCH-STEP-7731"


def ok(a, b):
    return "MATCH" if a == b else "DIFFERS (%s against %s)" % (a, b)


def main(out, sprints):
    rows = list(csv.DictReader(open(os.path.join(out, "steps.csv"))))
    HM = {seat: roll.hosted_mix(rows, seat) for seat in ("lead", "sub")}
    sp_rows = B.spawns(out); tot = B.totals(out); seats_txt = B.seats(out)
    print("per story; lead $ and subagent $ token-equivalent with API beside it where it differs; STORIES = %s" % roll.STORIES)
    for sp in sprints:
        n = roll.STORIES[sp]
        fb = " (lead priced at s%d's hosted mix, FALLBACK)" % roll.FALLBACK[sp] if sp in roll.FALLBACK and not sum(HM["lead"][sp].values()) else ""
        W = roll.seat_sum(rows, HM, "pipeline", None, {sp})
        print("s%d whole pipeline bucket (%d stories)%s: lead active %.2f h, %.1f calls, %.1fM tokens, lead %s; "
              "subagent active %.2f h, subagent %s" % (sp, n, fb, W["act"] / n, W["leadcalls"] / n, W["leadtok"] / n / 1e6,
                                                       roll.money(W["lead$e"] / n, W["lead$"] / n), W["subh"] / n,
                                                       roll.money(W["sub$e"] / n, W["sub$"] / n)))
        ps = B.per_step(out, sp)   # raw labels -> [lead active h, agent wait h, tokens]
        steps = sorted({roll.step_base(r["step"]) for r in rows if r["bucket"] == "pipeline" and int(r["sprint"]) == sp}
                       | {roll.step_base(r["step"]) for r in sp_rows if int(r["sprint"]) == sp})
        S = collections.defaultdict(float); c2 = [0, 0]; c2bad = []
        print("   %-34s %8s %7s %7s %16s | %8s %16s | %7s %8s | %7s" % (
            "step", "lead h", "calls", "lead M", "lead $", "sub h", "sub $ (seats)", "spawns", "sub $", "mach h"))
        for st in steps:
            T = roll.seat_sum(rows, HM, "pipeline", {st}, {sp})
            raw = {r["step"] for r in sp_rows if int(r["sprint"]) == sp and roll.step_base(r["step"]) == st}
            k = B.agg(sp_rows, sp, raw) if raw else (0, 0.0, 0.0, 0)
            m = [0.0, 0.0]
            for lab, v in ps.items():
                if roll.step_base(lab) == st:
                    m[0] += v[0]; m[1] += v[1]
            for key, v in (("act", T["act"]), ("lead$e", T["lead$e"]), ("lead$", T["lead$"]), ("leadtok", T["leadtok"]),
                           ("sub$e", T["sub$e"]), ("sp", k[0]), ("spusd", k[1]), ("ma", m[0]), ("mw", m[1])):
                S[key] += v
            print("   %-34s %8.3f %7.1f %7.2f %16s | %8.2f %16s | %7.2f %8.2f | %7.2f" % (
                st, T["act"] / n, T["leadcalls"] / n, T["leadtok"] / n / 1e6, roll.money(T["lead$e"] / n, T["lead$"] / n),
                T["subh"] / n, roll.money(T["sub$e"] / n, T["sub$"] / n), k[0] / n, k[1] / n, (m[0] + m[1]) / n))
            if T["el"] or T["subh"] or T["leadcalls"] or T["subcalls"]:
                s = seats_txt.get((sp, st))
                if s is None:
                    c2[1] += 1; c2bad.append(st + " (absent from seats.txt)")
                elif "%.2f %.1f" % (T["act"] / n, T["lead$e"] / n) == "%.2f %.1f" % (s["lead_h"], s["lead_te"]):
                    c2[0] += 1
                else:
                    c2[1] += 1; c2bad.append(st)
        print("   C1 additivity: lead h %s; lead $ %s; lead tokens %s; subagent $ %s" % (
            ok("%.2f" % S["act"], "%.2f" % W["act"]), ok("%.2f" % S["lead$e"], "%.2f" % W["lead$e"]),
            ok("%.0f" % S["leadtok"], "%.0f" % W["leadtok"]), ok("%.2f" % S["sub$e"], "%.2f" % W["sub$e"])))
        print("   C2 rendering against seats.txt: %d MATCH, %d DIFFERS%s" % (c2[0], c2[1], (": " + ", ".join(c2bad)) if c2bad else ""))
        print("   C3 machine h against roll.txt TOTAL: %s" % ok("%.1f %.1f" % (S["ma"], S["mw"]),
                                                              "%.1f %.1f" % (tot[sp]["active"], tot[sp]["agentwait"])))
        c = B.agg(sp_rows, sp)
        print("   C4 spawns.jsonl totals: spawns %s; subagent $ %s" % (ok("%d" % S["sp"], "%d" % c[0]), ok("%.2f" % S["spusd"], "%.2f" % c[1])))
    print("impossible step: steps.csv rows %d, spawns %d" % (
        sum(1 for r in rows if roll.step_base(r["step"]) == IMPOSSIBLE), B.agg(sp_rows, sprints[0], {IMPOSSIBLE})[0]))


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) < 2:
        sys.exit(__doc__)
    main(a[0], [int(x) for x in a[1:]])
