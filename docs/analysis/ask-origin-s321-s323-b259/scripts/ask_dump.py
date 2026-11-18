"""ask_dump.py -- BL-972 origin split, step 1: the text of every pipeline AskUserQuestion in the named sprints.

usage: python3 -I ask_dump.py ASK_SPLIT_TXT SPRINTS > asks.jsonl      e.g. ... out/ask_split.txt s321,s322,s323
Reads ask_split.py's committed output for the population (sprint, ask_start, wait_min, step, bucket,
lanes_running_at_ask, dispatched_at_ask) and drops rows whose step is `pre-step` (asks in update sessions).
Reads graph's lead transcripts READ ONLY for the question text, joined on the AskUserQuestion tool_use
timestamp, and for the answer (the paired tool_result; a denied or is_error result is dropped).
Each question also gets `answer_kind` (see answer_kind()), which needs no judgment.
Prints one JSON object per ask on stdout and the join control on stderr; exits 1 unless every population row
joined exactly one tool_use."""
import glob, json, os, re, sys

def answer_kind(q, ans):
    """How the operator answered one question, from the tool_result text (`"<question>"="<answer>"` pairs):
    took-recommended | other-option | free-text when an option label carries "recommend";
    unbadged:first-option | unbadged:other-option | unbadged:free-text when none does."""
    labels = [(o.get("label") or "").strip() for o in (q.get("options") or [])]
    recs = [l for l in labels if "recommend" in l.lower()]
    qt = q.get("question") or ""; i = ans.find(qt[:80]); chosen = None
    if i >= 0:
        m = re.search(r'"\s*=\s*"', ans[i:])
        if m:
            rest = ans[i + m.end():]; chosen = (rest[:rest.find('"')] if '"' in rest else rest).strip()
    if chosen is None: return "unparsed"
    if recs: return "took-recommended" if chosen in recs else ("other-option" if chosen in labels else "free-text")
    if chosen in labels: return "unbadged:first-option" if labels.index(chosen) == 0 else "unbadged:other-option"
    return "unbadged:free-text"
ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
split, sprints = sys.argv[1], set(sys.argv[2].split(","))
pop = {}; hdr = None
for l in open(split):
    f = l.rstrip("\n").split("\t")
    if f[0] == "sprint": hdr = f; continue
    if hdr and len(f) == len(hdr) and f[0] in sprints:
        d = dict(zip(hdr, f))
        if d["step"] != "pre-step": pop[d["ask_start"]] = d
found = {}; res = {}
for p in sorted(glob.glob(ROOT + "/*.jsonl")):
    for l in open(p, errors="replace"):
        if "AskUserQuestion" not in l and "tool_result" not in l: continue
        try: r = json.loads(l)
        except Exception: continue
        c = (r.get("message") or {}).get("content")
        if not isinstance(c, list): continue
        for b in c:
            if not isinstance(b, dict): continue
            if b.get("type") == "tool_use" and b.get("name") == "AskUserQuestion" and r.get("timestamp") in pop:
                # a resumed session copies its parent's records, so one tool_use id can sit in two transcripts: keep one
                found.setdefault(r["timestamp"], {}).setdefault(b["id"], ((b.get("input") or {}).get("questions") or [], os.path.basename(p)[:8]))
            elif b.get("type") == "tool_result":
                x = b.get("content")
                txt = x if isinstance(x, str) else " ".join(y.get("text", "") for y in x if isinstance(y, dict)) if isinstance(x, list) else ""
                res[b.get("tool_use_id")] = (bool(b.get("is_error")), txt)
n = 0; bad = 0
for t in sorted(pop):
    d = pop[t]; hits = found.get(t, {})
    if len(hits) != 1: bad += 1; continue
    (uid, (qs, sess)), = hits.items(); err, ans = res.get(uid, (True, ""))
    if err: bad += 1; continue
    n += 1
    print(json.dumps(dict(n=n, sprint=d["sprint"], ask_start=t, sess=sess, step=d["step"], wait_min=d["wait_min"], bucket=d["bucket"],
                          lanes_running=d["lanes_running_at_ask"], dispatched=d["dispatched_at_ask"],
                          questions=[dict(header=q.get("header"), question=q.get("question"),
                                          options=[o.get("label") for o in (q.get("options") or [])],
                                          answer_kind=answer_kind(q, ans)) for q in qs],
                          answer=ans)))
print(f"population rows {len(pop)}; joined and answered {n}; not joined or errored {bad}", file=sys.stderr)
sys.exit(1 if bad else 0)
