"""BL-812 item 1 on s323: which steps' per-story cost did NOT fall, s323 against a baseline sprint (batch 263, J).

usage: python3 -I rose_s323.py OUT A B      (OUT = extract.py + spawns.py + analyze.py + roll.py + roll.py --seats output)

It is `bl812_rederive.py rose` with the one thing that reader lacks, the s323 story count (18 story files under
graph `_bmad-output/planning-artifacts/s323/stories` at 16fd227d9, the same STORIES[323] roll.py carries at the
clock sha af44929cc). The reader is imported, never copied: the per-step figures are its `agg` (spawns.jsonl,
all buckets, subagent $) and its `seats` (roll.py --seats, pipeline bucket, token-equivalent $).

Controls printed after the table:
  C1 the patched story map leaves every other sprint's count as bl812_rederive carries it;
  C2 the per-step subagent $ summed over the steps equals the sprint total in spawns.jsonl (A and B);
  C3 an impossible step reads 0 spawns in spawns.jsonl.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s322", "scripts"))
import bl812_rederive as R

BEFORE = dict(R.STORIES)
R.STORIES[323] = 18
out, A, B = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
rows = R.spawns(out); s = R.seats(out)
steps = sorted({r["step"] for r in rows if int(r["sprint"]) in (A, B)})
rose_sub, rose_te = [], []
for st in steps:
    x = R.agg(rows, A, {st})[1] / R.STORIES[A]; y = R.agg(rows, B, {st})[1] / R.STORIES[B]
    k = "gate[" + st[16:-1] + "]" if st.startswith("gate-validation[") else st
    te = (s.get((A, k), {}).get("te"), s.get((B, k), {}).get("te"))
    rs = x > y
    rt = te[0] is not None and te[1] is not None and te[0] > te[1]
    if rs: rose_sub.append(st)
    if rt: rose_te.append(st)
    print("%-40s subagent $/story s%d %7.2f s%d %7.2f %-5s | token-eq s%d %s s%d %s %s" % (
        st, A, x, B, y, "ROSE" if rs else "", A, te[0], B, te[1], "ROSE" if rt else ("" if None not in te else "n/a")))
print("ROSE on subagent $ (%d): %s" % (len(rose_sub), ", ".join(rose_sub)))
print("ROSE on token-equivalent $ only (%d): %s" % (len([x for x in rose_te if x not in rose_sub]),
                                                    ", ".join(x for x in rose_te if x not in rose_sub)))
ok1 = all(R.STORIES[k] == v for k, v in BEFORE.items())
print("C1 story map unchanged for %s: %s" % (sorted(BEFORE), "MATCH" if ok1 else "DIFFERS"))
for sp in (A, B):
    tot = R.agg(rows, sp)[1]; by = sum(R.agg(rows, sp, {st})[1] for st in steps)
    print("C2 s%d per-step subagent $ sum %.2f, sprint total %.2f: %s" % (sp, by, tot, "MATCH" if abs(by - tot) < 0.005 else "DIFFERS"))
print("C3 impossible step %s: %d spawns" % (R.IMPOSSIBLE, R.agg(rows, A, {R.IMPOSSIBLE})[0] + R.agg(rows, B, {R.IMPOSSIBLE})[0]))
