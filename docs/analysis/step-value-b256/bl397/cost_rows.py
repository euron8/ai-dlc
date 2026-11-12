"""BL-397: per-story cost of implementation plus gate-validation[implementation], and the fixed fell/did-not-fall rule.

Usage: python3 cost_rows.py <extract-OUT> [<second extract-OUT for the s322 identity check>]
  <extract-OUT> holds steps.csv from extract.py + the s317-s318 analyze.py (EXTRACT_WIN_END pinned by the caller).
  The before side is read from the committed pin docs/analysis/pipeline-efficiency-s317-s320/b244-snapshot/steps.csv.

Every figure is roll.py's own seat_sum / usd / hosted_mix / FALLBACK (imported from
docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py, never edited or restated), summed over the step group
{implementation, gate[implementation]} of the pipeline bucket and divided per story.

Story counts: roll.py STORIES for s317..s322 (s322 8, re-derived by story_count.py), and s314 4, s315 5 for the
before (BL-397 b255, per `story-<N>-<M>:` keys). Where done differs from planned (s321: 24 of 25) both are printed.

s322's lead seat ran only local models, so its token-equivalent uses roll.py FALLBACK {322: 321}: s321's hosted lead
mix. The bracket prices every local call at sonnet and at opus (roll.py's main bracket rule), per seat.

Rule, fixed before any number was read (contract FOLD D4): FELL iff s322 per story is below the before AND below
min(s317..s321) on token-equivalent AND on tokens. Otherwise DID NOT FALL. Evaluated at the FALLBACK figure and at
both bracket ends; if the three disagree the bracket decides and that is printed.

Controls in the same run:
  before    must reproduce BL-397's b255 line: 2.00 h (gap 0.86 h), token-equivalent $29.0 (API $23.1), 71.4M tokens,
            lead active 1.14 h, lead $8.0 (API $2.0), subagent active 1.76 h, subagent $21.1. Mismatch exits 3.
  after     s317..s321 must reproduce b255's fresh-extract figures (token-equivalent, h): s317 $37.0 2.02, s318 $32.5 0.91, s319 $41.3
            2.09, s320 $20.7 1.94, s321 $25.5 1.13. Mismatch is printed as CORPUS-MOVED (the transcript corpus shrinks).
  s317      printed from the fresh extract AND from the b244 pin; a fresh s317 below the pin marks a truncated corpus.
"""
import csv, importlib.util, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROLL = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "roll.py")
PIN = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "b244-snapshot", "steps.csv")
spec = importlib.util.spec_from_file_location("roll", ROLL); roll = importlib.util.module_from_spec(spec)
spec.loader.exec_module(roll)
GROUP = {"implementation", "gate[implementation]"}
STORIES = dict(roll.STORIES); STORIES.update({314: 4, 315: 5})
DONE = {321: 24}

def load(p): return list(csv.DictReader(open(p)))

def bracket(rows, n):
    """(sonnet, opus) token-equivalent: every local call on either seat priced at one model."""
    out = []
    for pin in ("sonnet", "opus"):
        t = 0.0
        for r in rows:
            if r["bucket"] != "pipeline" or int(r["sprint"]) not in n or roll.step_base(r["step"]) not in GROUP: continue
            for seat in ("lead", "sub"): t += roll.usd(r, seat, True, {pin: 1.0})
        out.append(t)
    return out

def fig(rows, ns):
    HM = {seat: roll.hosted_mix(rows, seat) for seat in ("lead", "sub")}
    T = roll.seat_sum(rows, HM, "pipeline", GROUP, set(ns))
    b = bracket(rows, set(ns))
    return T, b

def show(label, rows, ns, sn=None):
    sn = sn or sum(STORIES[n] for n in ns)
    T, b = fig(rows, ns)
    te = (T["lead$e"] + T["sub$e"]) / sn; tok = (T["leadtok"] + T["subtok"]) / sn / 1e6
    print(f"{label} ({sn} stories): {roll.seat_line(T, sn)}; bracket sonnet ${b[0]/sn:.1f} .. opus ${b[1]/sn:.1f}")
    return dict(te=te, tok=tok, h=T["el"] / sn, b=(b[0] / sn, b[1] / sn), T=T, sn=sn)

pin = load(PIN); fresh = load(sys.argv[1] + "/steps.csv")
bad = 0
print("group: implementation plus gate-validation[implementation], pipeline bucket, per story")
print("-- before, b244 pin (EXTRACT_WIN_END=2026-10-27T13:08:00Z, pre-BL-927 extractor)")
B = show("before s314+s315", pin, (314, 315))
want = "2.00 h gap-inclusive (gap 0.86 h), token-equivalent $29.0 (API $23.1), 71.4M tokens; lead active 1.14 h, lead $8.0 (API $2.0), subagent active 1.76 h, subagent $21.1"
print("   before control:", "REPRODUCED" if roll.seat_line(B["T"], 9).startswith(want) else "MISMATCH"); bad += not roll.seat_line(B["T"], 9).startswith(want)
P317 = show("s317 at the b244 pin", pin, (317,))
print(f"-- after, fresh extract in {os.path.basename(os.path.normpath(sys.argv[1]))}/ (window: the caller's EXTRACT_WIN_END)")
A = {}
for n in (317, 318, 319, 320, 321, 322):
    A[n] = show(f"s{n}", fresh, (n,))
    if n in DONE: show(f"s{n} per DONE story", fresh, (n,), DONE[n])
B255 = {317: (37.0, 2.02), 318: (32.5, 0.91), 319: (41.3, 2.09), 320: (20.7, 1.94), 321: (25.5, 1.13)}
for n, (te, h) in B255.items():
    got = (round(A[n]["te"], 1), round(A[n]["h"], 2))
    print(f"   after control s{n}: b255 ${te} {h} h, now ${got[0]} {got[1]} h -> {'REPRODUCED' if got == (te, h) else 'CORPUS-MOVED'}")
trunc = A[317]["te"] < P317["te"] - 0.05
print(f"   s317 fresh ${A[317]['te']:.1f} against pin ${P317['te']:.1f}: {'TRUNCATED corpus, the pin is used' if trunc else 'fresh used'}")
R = {n: A[n] for n in (318, 319, 320, 321)}; R[317] = P317 if trunc else A[317]
mte = min(r["te"] for r in R.values()); mtok = min(r["tok"] for r in R.values())
s = A[322]
print(f"-- rule (FOLD D4): before ${B['te']:.1f} {B['tok']:.1f}M; min(s317..s321) ${mte:.1f} {mtok:.1f}M "
      f"(te from s{min(R, key=lambda k: R[k]['te'])}, tokens from s{min(R, key=lambda k: R[k]['tok'])})")
verdicts = []
for lab, te in (("FALLBACK", s["te"]), ("bracket sonnet", s["b"][0]), ("bracket opus", s["b"][1])):
    fell = te < B["te"] and te < mte and s["tok"] < B["tok"] and s["tok"] < mtok
    verdicts.append(fell)
    print(f"   s322 {lab}: ${te:.1f}, {s['tok']:.1f}M tokens -> {'FELL' if fell else 'DID NOT FALL'}")
for n in (317, 320, 322):
    T = A[n]["T"]
    print(f"   unrounded s{n}: elapsed {T['el']:.4f} h, gap {T['gap']:.4f} h, lead active {T['act']:.4f} h, "
          f"tokens {T['leadtok'] + T['subtok']:.0f} over {A[n]['sn']} stories")
print("   RULE: " + ("FELL" if all(verdicts) else "DID NOT FALL" if not any(verdicts) else "BRACKET DECIDES (ends disagree)"))
import json
last = ""
for l in open(sys.argv[1] + "/segs.jsonl"):
    g = json.loads(l)
    if g["kind"] == "lead" and g["sprint"] == 322 and roll.step_base(g["step"]) in GROUP: last = max(last, g["last"] or "")
spawn = max((t for _, st, t in json.load(open(sys.argv[1] + "/owner.json")).values()
             if roll.step_base(st) in GROUP and t >= "2026-11-09T00:00:00Z"), default=None)
print(f"   s322 group's last lead record in this window {last}, last spawn charged to it {spawn}")
if len(sys.argv) > 2:
    s2 = show("s322 at the second window", load(sys.argv[2] + "/steps.csv"), (322,))
    same = roll.seat_line(s2["T"], 8) == roll.seat_line(s["T"], 8) and s2["b"] == s["b"]
    print(f"   s322 identity across windows: {'IDENTICAL' if same else 'DIFFERS'}")
sys.exit(3 if bad else 0)
