"""Count "No such file or directory" lines in party, elicitation and adversary seat transcripts (BL-550).

Usage:
  python3 -I count.py START END [--root DIR] [--detail FILE]

  START, END  ISO-8601 instants bounding one sprint window, [START, END). A subagent transcript belongs to the
              window when its first timestamped record falls inside it; inside a member transcript only records
              stamped before END are scanned.
  --root      the consumer's Claude transcript directory (default ~/.claude/projects/-Users-n8-git-graph).
  --detail    write one TSV row per counted line: transcript, kind, step, tool, is_error, line.

A seat is classified from its meta.json (agentType, description) and its dispatch prompt (the first user
record), never from a step label:
  elicitation  agentType adversary and a description matching /elicit/i.
  adversary    agentType adversary, every other description: a ROUND seat when the description names a
               shard, part or cross dispatch, OFF-ROUND otherwise (one-shot, root-cause, sprint-level reviews).
  party        agentType architect, dev, pm, tea, sm, ux or analyst (an "-escalated" suffix is stripped) and a
               prompt naming a deliverable under `_bmad-output/party-mode/sNNN/<step>-...`. The step is the
               deliverable's prefix before the seat's role name. A prompt that names no such deliverable but
               says "party" is PARTY-UNKEYED, printed by name and kept out of the party row.
The headline party row is the four planning steps (carry-over-evaluation, requirements, architecture,
stories / test-strategy); sprint-review party seats print as their own row.

A counted line is a line of a `tool_result` block inside a user record's message.content, joined by
tool_use_id to the `tool_use` that produced it, containing "No such file or directory". Prompts, assistant
text and top-level toolUseResult copies are never scanned. Read and Grep tool misses carry other error
strings, so the count is a floor biased to Bash.

Exit 0 on a scan; 2 when the root holds no subagent transcript or the window selects none.
"""
import glob, json, os, re, sys, datetime as dt
from collections import Counter, defaultdict

PHRASE = "No such file or directory"
SEAT_ROLES = {"architect", "dev", "pm", "tea", "sm", "ux", "analyst"}
PLANNING = {"carry-over-evaluation", "requirements", "architecture", "stories", "test-strategy"}
ROUND_RE = re.compile(r"\b(?:shard|part|cross)\b", re.I)
DELIV_RE =re.compile(r"party-mode/s\d+/([A-Za-z0-9-]+?)-(?:architect|dev|pm|tea|sm|ux|analyst)\b")


def instant(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def records(path, bad):
    with open(path, errors="replace") as f:
        for ln in f:
            try:
                yield json.loads(ln)
            except ValueError:
                bad[0] += 1


def first_prompt(path, bad):
    for r in records(path, bad):
        if r.get("type") == "user":
            c = (r.get("message") or {}).get("content")
            if isinstance(c, str):
                return c
            return " ".join(x.get("text", "") for x in c or [] if isinstance(x, dict) and x.get("type") == "text")
    return ""


def first_ts(path, bad):
    for r in records(path, bad):
        if r.get("timestamp"):
            return r["timestamp"]
    return None


def classify(meta, prompt):
    role = (meta.get("agentType") or "").replace("-escalated", "")
    desc = meta.get("description") or ""
    if role == "adversary":
        if re.search(r"elicit", desc, re.I):
            return "elicitation", "-"
        return "adversary", ("round" if ROUND_RE.search(desc) else "off-round")
    if role in SEAT_ROLES:
        m = DELIV_RE.search(prompt)
        if m:
            return "party", m.group(1)
        if re.search(r"party", prompt, re.I):
            return "party-unkeyed", "-"
    return None, None


def scan(path, end, bad):
    """Yield (tool, is_error, line) for every counted line in records stamped before end."""
    uses = {}
    for r in records(path, bad):
        t = r.get("timestamp")
        if t and instant(t) >= end:
            break
        c = (r.get("message") or {}).get("content")
        if not isinstance(c, list):
            continue
        for b in c:
            if not isinstance(b, dict):
                continue
            if r.get("type") == "assistant" and b.get("type") == "tool_use":
                uses[b.get("id")] = b.get("name")
            elif r.get("type") == "user" and b.get("type") == "tool_result":
                body = b.get("content")
                if isinstance(body, list):
                    body = "\n".join(x.get("text", "") for x in body if isinstance(x, dict))
                for ln in (body or "").split("\n"):
                    if PHRASE in ln:
                        yield uses.get(b.get("tool_use_id"), "UNJOINED"), bool(b.get("is_error")), ln


def main(argv):
    args = list(argv)
    root = os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
    detail = None
    for flag in ("--root", "--detail"):
        if flag in args:
            i = args.index(flag)
            val = args[i + 1]
            del args[i:i + 2]
            if flag == "--root":
                root = val
            else:
                detail = val
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    start, end = instant(args[0]), instant(args[1])
    metas = sorted(glob.glob(os.path.join(root, "*", "subagents", "*.meta.json")))
    if not metas:
        print("count.py: no subagent transcript under %s" % root, file=sys.stderr)
        return 2
    bad = [0]
    no_jsonl = 0
    rows = defaultdict(lambda: [0, 0])     # (kind, step) -> [transcripts, lines]
    family = defaultdict(lambda: [0, 0])   # (kind, description family) -> [transcripts, lines]
    unkeyed = []
    tools = Counter()
    members = 0
    max_ts = ""
    out = open(detail, "w") if detail else None
    for m in metas:
        p = m[:-len(".meta.json")] + ".jsonl"
        if not os.path.exists(p):
            no_jsonl += 1
            continue
        t0 = first_ts(p, bad)
        if not t0 or not (start <= instant(t0) < end):
            continue
        members += 1
        max_ts = max(max_ts, t0)
        meta = json.load(open(m))
        kind, step = classify(meta, first_prompt(p, bad))
        if kind is None:
            continue
        hits = list(scan(p, end, bad))
        rows[(kind, step)][0] += 1
        rows[(kind, step)][1] += len(hits)
        fam = re.sub(r"\s+", " ", re.sub(r"\d+(?:[./]\d+)*", "N", (meta.get("description") or "").lower())).strip()
        family[(kind, fam)][0] += 1
        family[(kind, fam)][1] += len(hits)
        if kind == "party-unkeyed":
            unkeyed.append((os.path.basename(p)[:-6], meta.get("agentType"), meta.get("description"), len(hits)))
        for tool, err, ln in hits:
            tools[(kind, tool, err)] += 1
            if out:
                out.write("\t".join([os.path.basename(p)[:-6], kind, step, tool, str(err), ln.strip()[:300]]) + "\n")
    if out:
        out.close()
    if members == 0:
        print("count.py: the window selects no transcript", file=sys.stderr)
        return 2

    def agg(pred):
        tr = sum(v[0] for k, v in rows.items() if pred(k))
        li = sum(v[1] for k, v in rows.items() if pred(k))
        return tr, li

    print("scan: meta=%d no_jsonl=%d window_members=%d max_first_ts=%s unparseable_lines=%d"
          % (len(metas), no_jsonl, members, max_ts, bad[0]))
    for label, pred in (
            ("party(planning)", lambda k: k[0] == "party" and k[1] in PLANNING),
            ("party(sprint-review)", lambda k: k[0] == "party" and k[1] == "sprint-review"),
            ("party(other-step)", lambda k: k[0] == "party" and k[1] not in PLANNING and k[1] != "sprint-review"),
            ("elicitation", lambda k: k[0] == "elicitation"),
            ("adversary(round)", lambda k: k[0] == "adversary" and k[1] == "round"),
            ("adversary(off-round)", lambda k: k[0] == "adversary" and k[1] == "off-round"),
            ("party-unkeyed", lambda k: k[0] == "party-unkeyed")):
        tr, li = agg(pred)
        print("row %-22s transcripts=%d lines=%d" % (label, tr, li))
    for (kind, step), v in sorted(rows.items()):
        if kind == "party":
            print("step party %-24s transcripts=%d lines=%d" % (step, v[0], v[1]))
    for (kind, fam), v in sorted(family.items()):
        print("family %-13s %-50s transcripts=%d lines=%d" % (kind, fam[:50], v[0], v[1]))
    for (kind, tool, err), n in sorted(tools.items()):
        print("tool %-13s %-10s is_error=%s lines=%d" % (kind, tool, err, n))
    for u in unkeyed:
        print("unkeyed %s %s %s lines=%d" % u)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
