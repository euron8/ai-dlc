"""BL-812 item 3 on s323: each projection row of the entry read against the measured sprint (batch 263, J).

usage: python3 -I projection_s323.py OUT CLASSES
  OUT     = extract.py + spawns.py + analyze.py + roll.py + roll.py --seats output (clock sha af44929cc, monotone)
  CLASSES = `roll.py OUT --classes` output over the same OUT

Per story. Token-equivalent dollars from roll.py --seats (pipeline bucket; s323's lead ran local and is priced at
s321's hosted mix, FALLBACK), API dollars beside them; spawns and subagent dollars from spawns.jsonl (all buckets).
The readers are bl812_rederive's `seats` and `agg`, imported; STORIES[323] = 18 as in rose_s323.py.
The projected figures are quoted from docs/backlog.md BL-812's projection table, never computed here.

Controls (printed last): C1 each s319 baseline the table quotes re-derives from the same OUT; C2 the lead calls by
class sum to the outcome-row lead calls; C3 an impossible description token reads 0 spawns.
"""
import os, re, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s322", "scripts"))
import bl812_rederive as R
R.STORIES[323] = 18
out, classes = sys.argv[1], sys.argv[2]
rows = R.spawns(out); S = R.seats(out)
N = R.STORIES
IMPL = {"implementation", "gate-validation[implementation]"}


def te(sp, *steps):
    return sum(S[(sp, k)]["te"] for k in steps), sum(S[(sp, k)]["api"] if "api" in S[(sp, k)] else S[(sp, k)]["te"] for k in steps)


def sp_ps(sp, steps, pred=None):
    rs = [r for r in rows if int(r["sprint"]) == sp and r["step"] in steps and (pred is None or pred(r))]
    return len(rs) / N[sp], sum(r.get("usd") or 0 for r in rs) / N[sp], len(rs), sum(r.get("usd") or 0 for r in rs)


def lead_calls(path):
    """{sprint: {class: calls per story summed over steps}} from roll.py --classes."""
    d = collections.defaultdict(collections.Counter); sp = None
    for l in open(path):
        m = re.match(r"^== s(\d+) ", l)
        if m:
            sp = int(m.group(1)); continue
        m = re.match(r"^\s+(\S+)\s+active\s+[\d.]+ h\s+gap\s+[\d.]+ h\s+calls\s+([\d.]+)\s", l)
        if m and sp:
            d[sp][m.group(1)] += float(m.group(2))
    return d


print("== (a) implementation + gate-validation[implementation], per story")
for sp in (319, 322, 323):
    t, a = te(sp, "implementation", "gate[implementation]")
    n, usd, cnt, tot = sp_ps(sp, IMPL)
    print("  s%d: token-equivalent $%.1f (API $%.1f); spawns %.2f (%d); subagent $%.2f" % (sp, t, a, n, cnt, usd))
print("  projected (BL-808 row): $23.4 token-eq (API same), 20.2 spawns; combined row: at least $15.8 fall to <= $25.5, at least 6.8 spawns fall")
print("== (b) carry-over-evaluation alone, per story (subagent, spawns.jsonl)")
for sp in (319, 320, 322, 323):
    n, usd, cnt, tot = sp_ps(sp, {"carry-over-evaluation"})
    print("  s%d: %.2f spawns (%d), subagent $%.2f ($%.2f)" % (sp, n, cnt, usd, tot))
print("  projected: s319 basis 2.90 spawns, $2.98; s320 basis 7.30 spawns, $8.20")
print("== (b') four planning steps, per story (roll.py --seats)")
for sp in (319, 322, 323):
    t, a = te(sp, "carry-over-evaluation", "requirements", "architecture", "stories-test-strategy")
    print("  s%d: token-equivalent $%.1f (API $%.1f)" % (sp, t, a))
print("  projected: s319 basis $55.05, s320 basis $74.9 (API same)")
print("== (c) stories-test-strategy, BL-811 row, per story")
LIC = lambda r: "licit" in (r.get("description") or "")
for sp in (319, 323):
    t, a = te(sp, "stories-test-strategy")
    n1, u1, c1, t1 = sp_ps(sp, {"stories-test-strategy"}, LIC)
    n2, u2, c2, t2 = sp_ps(sp, {"stories-test-strategy", "gate-validation[stories-test-strategy]"}, LIC)
    print("  s%d: token-equivalent $%.1f (API $%.1f); elicitation ('licit' in description) step only %d spawns $%.2f "
          "($%.2f per story); step plus gate %d spawns $%.2f (%.2f spawns, $%.2f per story)" % (sp, t, a, c1, t1, u1, c2, t2, n2, u2))
print("  projected: $24.0 token-eq (API same); elicitation, step plus gate, 4.10 spawns and $6.11 per story")
print("== (d) lead calls, whole pipeline bucket, per story, by class (roll.py --classes)")
LC = lead_calls(classes)
for sp in (319, 323):
    tot = sum(LC[sp].values())
    print("  s%d: %.1f lead calls per story; %s" % (sp, tot, ", ".join("%s %.1f" % (k, v) for k, v in sorted(LC[sp].items(), key=lambda kv: -kv[1]) if v)))
print("  projected: s319 basis 310.9 lead calls per story (318.3 - 7.35, BL-819 L3)")
print("== controls")
t, a = te(319, "implementation", "gate[implementation]")
n, usd, cnt, tot = sp_ps(319, IMPL)
print("C1 s319 implementation pair token-eq $%.1f (recorded $41.3): %s; spawns %.2f (recorded 31.50): %s" % (
    t, R.verdict("%.1f" % t, "41.3"), n, R.verdict("%.2f" % n, "31.50")))
n, usd, cnt, tot = sp_ps(319, {"carry-over-evaluation"})
print("C1 s319 carry-over %d spawns $%.2f (recorded 88, $86.66): %s" % (cnt, tot, R.verdict("%d %.2f" % (cnt, tot), "88 86.66")))
t, a = te(319, "stories-test-strategy")
print("C1 s319 stories-test-strategy token-eq $%.1f (recorded $25.0): %s" % (t, R.verdict("%.1f" % t, "25.0")))
n2, u2, c2, t2 = sp_ps(319, {"stories-test-strategy", "gate-validation[stories-test-strategy]"}, LIC)
print("C1 s319 elicitation step plus gate %d spawns $%.0f (recorded 92, $162): %s" % (c2, t2, R.verdict("%d %.0f" % (c2, t2), "92 162")))
NT = collections.Counter()
sp_ = None
for l in open(classes):
    m = re.match(r"^== s(\d+) ", l)
    if m:
        sp_ = int(m.group(1))
    elif sp_ and re.match(r"^\s+\S+\s+active\s+[\d.]+ h\s+gap", l):
        NT[sp_] += 1
for sp in (319, 323):
    # each class cell is printed to 0.1, so the sum of NT[sp] cells may sit up to 0.05 * NT[sp] from the unrounded total
    ref = {319: 318.7, 323: 652.4}[sp]; d = abs(sum(LC[sp].values()) - ref); tol = 0.05 * NT[sp]
    print("C2 s%d lead calls by class %.1f (%d rounded cells, tolerance %.2f) against outcome_row's whole bucket %.1f: %s" % (
        sp, sum(LC[sp].values()), NT[sp], tol, ref, "MATCH" if d <= tol else "DIFFERS"))
print("note: (b') is a sum of four rounded seat figures; the unrounded group is group_four_steps.py's ($55.47 s323, $55.38 s319)")
print("C3 impossible description token: %d spawns; present token 'licit' s323: %d" % (
    sum(1 for r in rows if "QZXV-NO-SUCH-DESC-7731" in (r.get("description") or "")),
    sum(1 for r in rows if int(r["sprint"]) == 323 and LIC(r))))
