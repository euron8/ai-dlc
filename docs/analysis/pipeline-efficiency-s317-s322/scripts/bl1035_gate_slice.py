"""BL-1035: the s322 spawns that keep gate-validation[carry-over-evaluation] after the planning gate's terminal record.

usage:
  [EXTRACT_WIN_END=<instant>] python3 -I bl1035_gate_slice.py <OUT> <lead transcript .jsonl> <extract.py> [<OUT2>]
      <OUT> is a directory written by extract.py and spawns.py (docs/analysis/pipeline-efficiency-s317-s320/README.md).
      The lead transcript is graph s322's 6c14d949. extract.py is the extractor that wrote <OUT>; only its
      gate_event() and strip_heredocs() are loaded (the text between those two definitions and human_prompt), so the
      lead's gate-checkpoint.sh calls are classified exactly as the extractor classifies them.

Prints, in order:
  1. The lead's gate-checkpoint.sh invocations (open / verb / close as gate_event() reads them) and its Reads of step files
     between 13:30Z and 15:10Z on 2026-11-09, each Read marked WHOLE or SLICE (offset or limit present, the extractor's
     isslice rule).
  2. The s322 spawns labelled gate-validation[carry-over-evaluation], split by subagent start: before 14:00Z, from
     14:00Z to the first WHOLE read of requirements.md, and after it. Count, subagent $ (sum of spawns.jsonl usd) and
     agent-h (sum of minutes / 60), and every description in the middle bucket.
  3. Controls: the whole label and the before-14:00Z bucket against the figures docs/backlog.md records for this window
     (BL-812 b257 re-derivation: 52 spawns, $84.45, 6.87 agent-h; 20 spawns, $7.06, 0.37 agent-h), and an impossible
     label, which must read 0 spawns.
  4. Every `record 26 <verdict>` in the graph lead transcripts beside the given one, 2026-10-05 to EXTRACT_WIN_END
     (default 2026-11-12T10:16:23Z), with each non-PASS one named.
  5. With <OUT2>, an extractor variant's output over the same window (BL-1035's candidate-1 mutant, a scratch copy
     never committed): every spawn owner that differs, where the 14:00Z bucket lands, and the 20 before 14:00Z.
Read-only; writes nothing. Stdlib only.
"""
import collections, glob, json, os, re, sys

OUT, LEAD, X = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(X).read()
ns = {"re": re, "os": os}
exec(src[src.index("def strip_heredocs"):src.index("def human_prompt")], ns)
gate_event, strip = ns["gate_event"], ns["strip_heredocs"]
STEP_RE = re.compile(r"skills/ai-dlc(?:-update)?/steps/([A-Za-z0-9_.-]+)\.md")
LABEL = "gate-validation[carry-over-evaluation]"
IMPOSSIBLE = "gate-validation[QZXV-NO-SUCH-STEP-1035]"
LO, HI = "2026-11-09T13:30", "2026-11-09T15:10"

print("== 1. lead %s, gate-checkpoint.sh calls and step-file Reads, %sZ to %sZ" % (os.path.basename(LEAD)[:8], LO, HI))
first_whole_req = None
for line in open(LEAD, errors="replace"):
    try: r = json.loads(line)
    except Exception: continue
    t = r.get("timestamp") or ""
    if r.get("type") != "assistant" or not (LO <= t <= HI): continue
    for c in (r.get("message") or {}).get("content") or []:
        if not isinstance(c, dict) or c.get("type") != "tool_use": continue
        inp = c.get("input") or {}
        if c.get("name") == "Bash":
            cmd = str(inp.get("command") or "")
            ev = gate_event(cmd)
            if ev:
                calls = re.findall(r"gate-checkpoint\.sh[^;&|\n]*", strip(cmd))
                print("%s %-5s %s" % (t[:19] + "Z", ev, " | ".join(x.strip()[:60] for x in calls)))
        elif c.get("name") == "Read":
            m = STEP_RE.search(json.dumps(inp))
            if not m: continue
            sl = "offset" in inp or "limit" in inp
            print("%s READ  %s.md %s offset=%s limit=%s" % (t[:19] + "Z", m.group(1), "SLICE" if sl else "WHOLE",
                                                          inp.get("offset"), inp.get("limit")))
            if m.group(1) == "requirements" and not sl and first_whole_req is None:
                first_whole_req = t[:19] + "Z"
print("first WHOLE read of requirements.md: %s" % first_whole_req)

rows = [json.loads(l) for l in open(os.path.join(OUT, "spawns.jsonl"))]
s322 = [r for r in rows if int(r["sprint"]) == 322]

def agg(rs):
    return len(rs), round(sum(r.get("usd") or 0 for r in rs), 2), round(sum(r.get("minutes") or 0 for r in rs) / 60, 2)

lab = sorted((r for r in s322 if r["step"] == LABEL), key=lambda r: r["start"])
pre = [r for r in lab if r["start"] < "2026-11-09T14:00"]
mid = [r for r in lab if "2026-11-09T14:00" <= r["start"] < (first_whole_req or "9")]
post = [r for r in lab if r["start"] >= (first_whole_req or "9")]
print("== 2. s322 spawns labelled %s, by subagent start" % LABEL)
print("before 14:00Z: %d spawns, $%.2f, %.2f agent-h" % agg(pre))
print("14:00Z to %s: %d spawns, $%.2f, %.2f agent-h" % ((first_whole_req,) + agg(mid)))
if mid: print("  first start %s, last start %s" % (mid[0]["start"][:19] + "Z", mid[-1]["start"][:19] + "Z"))
print("from %s on: %d spawns, $%.2f, %.2f agent-h" % ((first_whole_req,) + agg(post)))
for r in mid:
    print("  %s %-16s %-6s $%6.3f %6.1f min  %s" % (r["start"][:19] + "Z", r.get("role"), r.get("model_ran"),
                                                  r.get("usd") or 0, r.get("minutes") or 0, (r.get("description") or "")[:80]))
print("== 3. controls")
want = {"whole label": ((52, 84.45, 6.87), agg(lab)), "before 14:00Z": ((20, 7.06, 0.37), agg(pre))}
bad = 0
for k, (rec, got) in want.items():
    ok = rec == got; bad += not ok
    print("CONTROL %s %s: recorded %s, derived %s" % ("OK  " if ok else "FAIL", k, rec, got))
n_imp = sum(1 for r in s322 if r["step"] == IMPOSSIBLE)
print("CONTROL %s impossible label %s: %d spawns (must be 0); s322 spawns in <OUT>: %d (must be > 0)"
      % ("OK  " if n_imp == 0 and s322 else "FAIL", IMPOSSIBLE, n_imp, len(s322)))
bad += not (n_imp == 0 and s322)

# 4. Every `record 26 <verdict>` in a graph LEAD transcript (the *.jsonl files beside the given one), Bash calls stamped
#    from 2026-10-05 through the window end, heredoc bodies stripped. Whether a terminal-record rule must key on the verdict.
WEND = os.environ.get("EXTRACT_WIN_END") or "2026-11-12T10:16:23Z"
v = collections.Counter(); fails = []
for p in sorted(glob.glob(os.path.join(os.path.dirname(LEAD), "*.jsonl"))):
    for line in open(p, errors="replace"):
        if "record 26" not in line: continue
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp") or ""
        if r.get("type") != "assistant" or not ("2026-10-05" <= t <= WEND.rstrip("Z")): continue
        for c in (r.get("message") or {}).get("content") or []:
            if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Bash":
                for m in re.findall(r"record 26 ([A-Z_]+)", strip(str((c.get("input") or {}).get("command") or ""))):
                    v[m] += 1
                    if m != "PASS": fails.append("%s %s %s" % (os.path.basename(p)[:8], t[:19] + "Z", m))
print("== 4. record 26 verdicts in lead Bash calls, 2026-10-05 to %s: %s" % (WEND, dict(sorted(v.items()))))
for f in fails: print("  " + f)

# 5. With a second <OUT> (an extractor variant over the same window): every spawn owner that differs, by
#    (old label -> new label), with its owner-timestamp range; where the 14:00Z bucket lands; the 20 before 14:00Z.
if len(sys.argv) > 4:
    O2 = sys.argv[4]
    a = json.load(open(os.path.join(OUT, "owner.json"))); b = json.load(open(os.path.join(O2, "owner.json")))
    print("== 5. owner.json against %s: %d and %d owners, same keys %s" % (O2, len(a), len(b), set(a) == set(b)))
    ch = collections.Counter(); rng = {}
    for k in a:
        if k in b and a[k][1] != b[k][1]:
            kk = (a[k][1], b[k][1]); ch[kk] += 1
            lo, hi = rng.get(kk, (a[k][2], a[k][2])); rng[kk] = (min(lo, a[k][2]), max(hi, a[k][2]))
    for kk, n in ch.most_common(): print("CHANGED %d %s -> %s, %s to %s" % ((n,) + kk + rng[kk]))
    print("owners changed: %d" % sum(ch.values()))
    rb = {r["unit"]: r for r in (json.loads(l) for l in open(os.path.join(O2, "spawns.jsonl")))}
    land = collections.Counter(rb[r["unit"]]["step"] for r in mid if r["unit"] in rb)
    print("the %d 14:00Z-bucket spawns land on: %s" % (len(mid), dict(land)))
    stay = collections.Counter(rb[r["unit"]]["step"] for r in pre if r["unit"] in rb)
    print("CONTROL the %d spawns before 14:00Z land on: %s" % (len(pre), dict(stay)))
sys.exit(1 if bad else 0)
