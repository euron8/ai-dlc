"""BL-843: cost of the gate-2 passes the record-metadata rework class caused, graph s320 (before) and s323 (after).

Usage: python3 -I cost.py <OUT>
  <OUT> is an extract.py + spawns.py output directory (docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py
  and docs/analysis/pipeline-efficiency-s317-s318/scripts/spawns.py, scripts and clock as committed at af44929cc,
  EXTRACT_MONOTONE_SEGS=1). Transcripts are read from $EXTRACT_ROOT, else ~/.claude/projects/-Users-n8-git-graph
  (read only).

A class pass is a gate-2 NEEDS_REWORK pass whose Critical or Important findings are record metadata only (the strict
reading of BL-843's batch-256 and batch-261 paragraphs). The pass it CAUSED is the next gate-2 pass of that story, and
its window runs from the end of the class pass's last QA seat to the end of the caused pass's last QA seat, so it
holds the rework and any gate-1 re-review as well as the re-validation. Window edges are the `end` of the named QA
seats in spawns.jsonl, written out in WINDOWS below.

Per window:
  seats     subagent units of the story (description regex; s320 4.2's gate-2 p2..p7 seats carry no story id and
            are matched by their `QA gate-2 p<N>` description), role not gate-adjudicator, with at least one record in
            the window.
  active    sum of the gaps of 300 s or less between consecutive records of one unit inside the window (the
            extractor's active rule applied to a time window; not the extractor's per-(unit, step) segs clock, which
            cannot be cut at a window edge). CONTROL: for every unit lying wholly inside a window the same sum is
            compared with that unit's segs.jsonl `active` on the monotone clock.
  gap-incl  first to last in-window record per unit (subagent units and lead transcripts), gaps of any length kept.
  tokens    in + cache-write + cache-read + out of every message.id whose last usage record is in the window.
  $         spawns.py's price table (per million: in, cache-write, cache-read, out). API: a local-model call is $0.
            token-equivalent: a local-model lead call is priced as sonnet (roll.py LOCAL_REPLACED_BY for the lead
            seat); subagent seats ran hosted models only, so their two figures are equal.
  lead      every non-sidechain record inside the window of each lead transcript that segs.jsonl puts in
            `implementation` or `gate-validation[implementation]` in that sprint, read in first-record order with a
            record uuid already read from an earlier transcript skipped (the extractor's fork dedupe), same rules. The
            lead's hours are a window cut, not the extractor's segs clock. A pass-k seat (one ending within 1 s of the
            window start) is not a seat of the caused pass. The lead
            serves any other story in flight in that window too, so this is the lead's whole window cost, an upper
            bound on what the class caused it.
"""
import json, os, sys, glob, re, collections, datetime as dt

OUT = sys.argv[1]
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
P = {"opus": (4, 8, 0.20, 20), "sonnet": (2, 4, 0.20, 10), "haiku": (0.10, 0.20, 0.01, 0.50), "fable": (10, 20, 0.25, 50)}
LOCAL = ("qwen", "deepseek")
GAP = 300
T = lambda s: dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()

# (sprint, story, class pass, caused pass, unit description regex, window start, window end)
WINDOWS = [
    (320, "1.3", "p1", "p2", r"(^|[^0-9.])1[.-]3([^0-9]|$)", "2026-10-27T21:53:10.268Z", "2026-10-27T22:14:31Z"),
    (320, "1.3", "p2", "p3", r"(^|[^0-9.])1[.-]3([^0-9]|$)", "2026-10-27T22:14:31Z", "2026-10-28T02:37:26.159Z"),
    (320, "4.1", "p2", "p3", r"(^|[^0-9.])4[.-]1([^0-9]|$)", "2026-10-27T13:35:21.135Z", "2026-10-27T13:59:04Z"),
    (320, "4.1", "p3", "p4", r"(^|[^0-9.])4[.-]1([^0-9]|$)", "2026-10-27T13:59:04Z", "2026-10-27T14:07:32.676Z"),
    (320, "4.2", "p2", "p3", r"(^|[^0-9.])4[.-]2([^0-9]|$)|^QA gate-2 p[0-9]", "2026-10-27T16:18:17Z", "2026-10-27T17:44:26Z"),
    (320, "4.2", "p3", "p4", r"(^|[^0-9.])4[.-]2([^0-9]|$)|^QA gate-2 p[0-9]", "2026-10-27T17:44:26Z", "2026-10-27T17:58:45Z"),
    (320, "4.2", "p5", "p6", r"(^|[^0-9.])4[.-]2([^0-9]|$)|^QA gate-2 p[0-9]", "2026-10-27T19:03:34Z", "2026-10-27T19:17:12Z"),
    (323, "5.4", "p1", "p2", r"(^|[^0-9.])5[.-]4([^0-9]|$)", "2026-11-18T14:25:54Z", "2026-11-18T14:47:26Z"),
    (323, "5.5", "p2", "p3", r"(^|[^0-9.])5[.-]5([^0-9]|$)", "2026-11-18T21:20:18Z", "2026-11-18T21:33:13Z"),
]
STORIES = {320: 13, 323: 18}   # roll.py STORIES at af44929cc

def fam(m):
    m = (m or "").lower()
    for k in P:
        if k in m: return k
    return "local" if any(x in m for x in LOCAL) else "?"

def price(f, d):
    return sum(d[i] * P[f][i] for i in range(4)) / 1e6

def read(path, a, b, lead, seen=None):
    ts, usage = [], {}
    for l in open(path, errors="replace"):
        try: r = json.loads(l)
        except Exception: continue
        t = r.get("timestamp")
        if not t: continue
        if lead and r.get("isSidechain"): continue
        x = T(t)
        if x < a or x > b: continue
        if seen is not None:
            u = r.get("uuid")
            if u in seen: continue
            if u: seen.add(u)
        ts.append(x)
        m = r.get("message") if isinstance(r.get("message"), dict) else {}
        if m.get("usage") and m.get("id"): usage[m["id"]] = (m.get("model"), m["usage"])
    ts.sort()
    act = sum(d for d in (q - p for p, q in zip(ts, ts[1:])) if 0 < d <= GAP)
    tok, api, te = 0, 0.0, 0.0
    for model, u in usage.values():
        d = (u.get("input_tokens", 0) or 0, u.get("cache_creation_input_tokens", 0) or 0,
             u.get("cache_read_input_tokens", 0) or 0, u.get("output_tokens", 0) or 0)
        tok += sum(d); f = fam(model)
        if f in P: api += price(f, d); te += price(f, d)
        elif f == "local": te += price("sonnet", d)
    el = (ts[-1] - ts[0]) if ts else 0.0
    return len(ts), act, tok, api, te, el

spawns = [json.loads(l) for l in open(os.path.join(OUT, "spawns.jsonl"))]
segact = collections.Counter(); impl_leads = {}
for l in open(os.path.join(OUT, "segs.jsonl")):
    s = json.loads(l)
    if s["kind"] == "sub": segact[s["unit"]] += s.get("active", 0) or 0
    elif s["kind"] == "lead" and s["step"] in ("implementation", "gate-validation[implementation]"):
        impl_leads.setdefault(s["sprint"], set()).add(s["sess"])
path_of = {os.path.basename(p)[:-6]: p for p in glob.glob(ROOT + "/*/subagents/*.jsonl")}
first = {u["sess"]: u["first"] for u in (json.loads(l) for l in open(os.path.join(OUT, "units.jsonl"))) if u["kind"] == "lead"}
lead_path = {os.path.basename(p)[:-6]: p for p in glob.glob(ROOT + "/*.jsonl")}

tot = collections.defaultdict(lambda: collections.Counter())
ctl_w = ctl_s = 0.0; ctl_n = 0
print("sprint story class->caused | seats | subagent active h | subagent $ | subagent tokens M | lead active h | lead $ token-eq (API) | lead tokens M")
for sp, story, kp, cp, rx, ws, we in WINDOWS:
    a, b = T(ws), T(we); rgx = re.compile(rx)
    seats = 0; sel = 0.0; lel = 0.0; sa = 0.0; stok = 0; susd = 0.0; roles = collections.Counter()
    for s in spawns:
        if s["sprint"] != sp or (s["role"] or "") == "gate-adjudicator": continue
        if not rgx.search(s["description"] or ""): continue
        if T(s["end"]) <= a + 1 or T(s["start"]) > b: continue   # a pass-k seat ends at the window start
        p = path_of.get(s["unit"])
        if not p: print("  UNREAD unit", s["unit"]); continue
        n, act, tok, api, te, el = read(p, a, b, False)
        if n == 0: continue
        seats += 1; sel += el; sa += act; stok += tok; susd += api; roles[s["role"]] += 1
        if T(s["start"]) >= a and T(s["end"]) <= b:
            ctl_w += act; ctl_s += segact[s["unit"]]; ctl_n += 1
    la = 0.0; ltok = 0; lapi = 0.0; lte = 0.0
    seen = set(); used = []; skipped = []
    for sess in sorted(lead_path, key=lambda k: first.get(k, "9")):
        if sess not in impl_leads.get(sp, set()):
            if read(lead_path[sess], a, b, True)[0]: skipped.append(sess[:8])
            continue
        n, act, tok, api, te, el = read(lead_path[sess], a, b, True, seen)
        if n: used.append(sess[:8])
        lel += el; la += act; ltok += tok; lapi += api; lte += te
    print(f"  lead transcripts read {used}; with in-window records but no implementation segs row in s{sp}, not read {skipped}")
    print(f"s{sp} {story} {kp}->{cp} | {seats} {dict(roles)} | {sa/3600:.2f} | ${susd:.2f} | {stok/1e6:.1f} | {la/3600:.2f} | ${lte:.2f} (${lapi:.2f}) | {ltok/1e6:.1f}")
    c = tot[sp]; c["passes"] += 1; c["seats"] += seats; c["sa"] += sa; c["susd"] += susd; c["stok"] += stok
    c["sel"] += sel; c["lel"] += lel; c["la"] += la; c["lte"] += lte; c["lapi"] += lapi; c["ltok"] += ltok
for sp in sorted(tot):
    c = tot[sp]; n = STORIES[sp]
    h = (c["sa"] + c["la"]) / 3600; te = c["susd"] + c["lte"]; api = c["susd"] + c["lapi"]; tk = (c["stok"] + c["ltok"]) / 1e6
    gi = (c["sel"] + c["lel"]) / 3600
    print(f"s{sp} GAP-INCLUSIVE {gi:.2f} h (subagent {c['sel']/3600:.2f} h, lead {c['lel']/3600:.2f} h); "
          f"per story {gi/n:.3f} h (subagent {c['sel']/3600/n:.3f} h, lead {c['lel']/3600/n:.3f} h)")
    print(f"s{sp} TOTAL caused gate-2 passes {c['passes']:.0f}, seats {c['seats']:.0f}; agent-hours {h:.2f} h (subagent {c['sa']/3600:.2f} h, lead {c['la']/3600:.2f} h); "
          f"token-equivalent ${te:.2f} (API ${api:.2f}; subagent ${c['susd']:.2f}, lead ${c['lte']:.2f} token-eq / ${c['lapi']:.2f} API); {tk:.1f}M tokens")
    print(f"s{sp} PER STORY ({n}): passes {c['passes']/n:.2f}, seats {c['seats']/n:.2f}, {h/n:.3f} h (subagent {c['sa']/3600/n:.3f} h, lead {c['la']/3600/n:.3f} h), "
          f"token-equivalent ${te/n:.2f} (API ${api/n:.2f}; subagent ${c['susd']/n:.2f}, lead ${c['lte']/n:.2f}), {tk/n:.2f}M tokens")
print(f"CONTROL window-active vs segs-active (monotone) over {ctl_n} units wholly inside a window: {ctl_w/3600:.3f} h vs {ctl_s/3600:.3f} h")
