# m2_ask_pipeline.py -- BL-972 item 1 reading: per-sprint ask counts with and without the `pre-step` asks
# (update-session asks), from the row table of ask_split.py's output.
# usage: python3 -I m2_ask_pipeline.py <ask_split output>
import sys, collections
rows = []
hdr = None
for line in open(sys.argv[1]):
    f = line.rstrip("\n").split("\t")
    if f[0] == "sprint": hdr = f; continue
    if hdr and len(f) == len(hdr) and f[0].startswith("s3"): rows.append(dict(zip(hdr, f)))
assert hdr and rows, "no rows parsed"
print("sprint | scope | asks | wait h | FINISHED-INSIDE min | HELD>0 | DISPATCHED | ADJ-DISPATCH | DRAINED | lane-idle min of wait min")
for sp in sorted({r["sprint"] for r in rows}):
    for scope, pred in (("all", lambda r: True), ("pipeline", lambda r: r["step"] != "pre-step"), ("pre-step", lambda r: r["step"] == "pre-step")):
        s = [r for r in rows if r["sprint"] == sp and pred(r)]
        if not s: continue
        n = len(s); w = sum(float(r["wait_min"]) for r in s); li = sum(float(r["lane_idle_min"]) for r in s)
        fi = sum(float(r["wait_min"]) for r in s if r["bucket"] == "FINISHED-INSIDE")
        c = lambda k: sum(1 for r in s if r[k] not in ("0", "-"))
        print("%s | %s | %d | %.1f | %.0f | %d | %d (%.1f%%) | %d (%.1f%%) | %d | %.0f of %.0f (%.1f%%)" % (
            sp, scope, n, w / 60, fi, c("held_at_ask"), c("dispatched_at_ask"), 100.0 * c("dispatched_at_ask") / n,
            c("adj_dispatch"), 100.0 * c("adj_dispatch") / n, c("drained_at_ask"), li, w, 100.0 * li / w if w else 0))
print("total rows parsed", len(rows))
for sp in ("s322", "s323"):
    print(sp, "asks with step == pre-step:", [(r["ask_start"][:16], r["wait_min"]) for r in rows if r["sprint"] == sp and r["step"] == "pre-step"])
