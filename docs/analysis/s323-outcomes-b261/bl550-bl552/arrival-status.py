"""Count lead status lines posted per finished party / elicitation seat (BL-552).

Usage:
  python3 -I arrival-status.py START END [--root DIR] [--detail FILE]

  START, END  ISO-8601 instants, [START, END): a notification record belongs to the window by its own timestamp.
  --root      the consumer's Claude transcript directory (default ~/.claude/projects/-Users-n8-git-graph).
  --detail    write one TSV row per arrival: reader, transcript, ts, kind, step, status_lines, signature_lines.

An ARRIVAL is a `type: user` record whose message.content is (or whose text block starts with) a
`<task-notification>` carrying a `<task-id>` that is the agentId of a party or elicitation seat. The seat is
classified by count.py's classify() (../../bl550-missing-path-counter/count.py, unmodified) from the seat's own
meta.json and dispatch prompt: party = a seat role whose prompt names a party-mode deliverable, the step being
the deliverable prefix; elicitation = adversary with an /elicit/i description. A background-Bash beat's task-id
is not an agentId and is counted as `other`. Duplicated records (same uuid) count once; the `queue-operation`
and `api-request-blob` copies of a notification are never read.

Its STATUS LINES are the non-empty `text` blocks of the `assistant` records from the arrival to the next
`user` record (a tool_result record is a user record, so only text posted before the reader's first tool call
counts, the BL-552 definition). A SIGNATURE line is a status line matching `join beat|delivered|still armed|armed`
(case-insensitive).

READERS: `lead` is a top-level transcript (file directly under the root); `dispatcher` is a subagent
transcript whose first user record carries `You are a round-dispatcher` in its first 3000 characters. Every other subagent transcript
is not read.

NOT established: that a live `--complete` join covered each arrival. Coverage is approximated by round
membership (every party and elicitation arrival counts as covered), as in the BL-552 batch 256 reading.

Exit 0 on a scan, 2 when the root holds no transcript or the window holds no notification.
"""
import glob, importlib.util, json, os, re, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "count", os.path.join(HERE, "..", "..", "bl550-missing-path-counter", "count.py"))
count = importlib.util.module_from_spec(spec)
spec.loader.exec_module(count)

SIG = re.compile(r"join beat|delivered|still armed|armed", re.I)
TASK = re.compile(r"<task-notification>\s*<task-id>([^<]+)</task-id>")


def notification_id(r):
    """The task-id when r is a user record that is a task notification, else None."""
    if r.get("type") != "user":
        return None
    c = (r.get("message") or {}).get("content")
    if isinstance(c, str):
        texts = [c]
    elif isinstance(c, list):
        texts = [b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text"]
    else:
        return None
    for t in texts:
        m = TASK.search(t[:1500])
        if m:
            return m.group(1)
    return None


def status_blocks(recs, i):
    """Non-empty assistant text blocks after recs[i] up to the next user record."""
    out = []
    for r in recs[i + 1:]:
        if r.get("type") == "user":
            break
        if r.get("type") != "assistant":
            continue
        c = (r.get("message") or {}).get("content")
        if isinstance(c, str):
            c = [{"type": "text", "text": c}]
        for b in c or []:
            if isinstance(b, dict) and b.get("type") == "text" and (b.get("text") or "").strip():
                out.append(b["text"])
    return out


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
    start, end = count.instant(args[0]), count.instant(args[1])
    bad = [0]
    seat = {}   # agentId -> (kind, step)
    dispatchers = []
    for m in sorted(glob.glob(os.path.join(root, "*", "subagents", "*.meta.json"))):
        p = m[:-len(".meta.json")] + ".jsonl"
        if not os.path.exists(p):
            continue
        aid = os.path.basename(p)[len("agent-"):-len(".jsonl")]
        meta = json.load(open(m))
        prompt = count.first_prompt(p, bad)
        kind, step = count.classify(meta, prompt)
        if kind in ("party", "elicitation"):
            seat[aid] = (kind, step)
        if "You are a round-dispatcher" in prompt[:3000]:
            dispatchers.append(p)
    readers = [("lead", p) for p in sorted(glob.glob(os.path.join(root, "*.jsonl")))]
    readers += [("dispatcher", p) for p in sorted(dispatchers)]
    if not readers:
        print("arrival-status.py: no transcript under %s" % root, file=sys.stderr)
        return 2
    arr = defaultdict(lambda: [0, 0, 0])    # (reader, kind, step) -> [arrivals, status lines, signature lines]
    notif = defaultdict(int)                # reader -> notification records of any task-id, in the window
    out = open(detail, "w") if detail else None
    for reader, p in readers:
        recs, seen = [], set()
        for r in count.records(p, bad):
            u = r.get("uuid")
            if r.get("type") == "user" and u:
                if u in seen:
                    continue
                seen.add(u)
            recs.append(r)
        for i, r in enumerate(recs):
            tid = notification_id(r)
            ts = r.get("timestamp")
            if tid is None or not ts or not (start <= count.instant(ts) < end):
                continue
            notif[reader] += 1
            kind, step = seat.get(tid, ("other", "-"))
            blocks = status_blocks(recs, i)
            sig = sum(1 for b in blocks if SIG.search(b))
            a = arr[(reader, kind, step)]
            a[0] += 1; a[1] += len(blocks); a[2] += sig
            if out:
                out.write("\t".join([reader, os.path.basename(p)[:-6], ts, kind, step, str(len(blocks)), str(sig)]) + "\n")
    if out:
        out.close()
    if not notif:
        print("arrival-status.py: the window holds no task-notification", file=sys.stderr)
        return 2
    print("scan: seats=%d dispatcher_transcripts=%d lead_transcripts=%d unparseable_lines=%d"
          % (len(seat), len(dispatchers), len(readers) - len(dispatchers), bad[0]))
    for reader in ("lead", "dispatcher"):
        print("notifications %-10s all=%d" % (reader, notif[reader]))
        tot = [0, 0, 0]
        for (rd, kind, step), v in sorted(arr.items()):
            if rd != reader or kind == "other":
                continue
            print("arrivals %-10s %-12s %-24s arrivals=%d status=%d signature=%d" % (rd, kind, step, v[0], v[1], v[2]))
            if kind == "elicitation" or step in count.PLANNING:
                for j in range(3):
                    tot[j] += v[j]
        a, s, g = tot
        print("covered  %-10s party(planning)+elicitation arrivals=%d status=%d (%.3f per arrival) signature=%d (%.3f per arrival)"
              % (reader, a, s, s / a if a else 0.0, g, g / a if a else 0.0))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
