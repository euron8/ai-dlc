"""BL-819's Known gap (batch 254), the row-add decision: does ai-dlc-inflight-row.sh's hand-written `--row-add`
remedy (say_unwritten, `AI/DLC in-flight row NOT written ...`) still fire once the dispatch guard's DELIVERABLE-LINE
deny is installed, and what does each firing cost the lead?

usage: python3 -I rowadd_decision.py <transcript dir> <period label>=<start>..<end> [...]
       python3 -I rowadd_decision.py --self-test

<transcript dir> is graph's lead transcript directory (top-level *.jsonl; subagent transcripts are not read). Each
period is a half-open UTC interval [start, end) on the record timestamp. Read-only; writes nothing. Stdlib only.

Per period it prints:
  NOT-WRITTEN  distinct dispatches (tool_use id) the hook answered "in-flight row NOT written", split by the hook's
               `Why:` reason (no Deliverable line; no ledger ts; snapshot-update.sh missing; a snapshot-update.sh
               refusal), counted once per dispatch however many records carry the text.
  DENY         lead Agent/Task calls the dispatch guard refused for a missing `Deliverable:` line (its deny text).
  ROW-OPS      lead Bash calls running snapshot-update.sh with --row-add or --row-replace, and how many of them
               name a NOT-WRITTEN dispatch's id: the hand calls the remedy cost.
  AGENT        lead Agent/Task tool_use calls (the population both hooks judge).
Controls: an impossible phrase counts 0 beside the hook's own phrase, and the Agent count is above 0 in every
period that has lead records.
"""
import glob, json, os, re, sys, collections

PHRASE = "AI/DLC in-flight row NOT written for dispatch"
DENY = "because its brief carries no `Deliverable: <path>` line"
IMPOSSIBLE = "AI/DLC qzxv-no-such-hook-phrase 8812"
DISPATCH_RE = re.compile(re.escape(PHRASE) + r" ((?:[A-Za-z0-9_@.-]+ )?(toolu_[A-Za-z0-9_]+))")
WHY_RE = re.compile(r"Why: ([^\n\\]*)")


def why_class(w):
    if "Deliverable" in w:
        return "no-deliverable-line"
    if "--dispatch-ts" in w:
        return "no-ledger-ts"
    if "not installed under scripts/ai-dlc" in w:
        return "snapshot-update-missing"
    if "snapshot-update.sh --row" in w:
        return "snapshot-update-refused"
    return "other"


def texts(obj):
    """Every string inside a record, so a hook message is found wherever the harness put it."""
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from texts(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from texts(v)


def scan(tdir, periods):
    P = {lab: dict(nw={}, deny=set(), rowops=0, rowops_named=0, agent=0, recs=0, imp=0, phrase=0) for lab, _, _ in periods}
    for f in sorted(glob.glob(os.path.join(tdir, "*.jsonl"))):
        rows = []
        for line in open(f, errors="replace"):
            try:
                r = json.loads(line)
            except ValueError:
                continue
            t = r.get("timestamp") or ""
            lab = next((l for l, a, b in periods if a <= t < b), None)
            if lab is None:
                continue
            rows.append((lab, r, line))
        tu_name = {}
        for lab, r, line in rows:
            p = P[lab]; p["recs"] += 1
            if IMPOSSIBLE in line:
                p["imp"] += 1
            m = r.get("message") or {}
            if r.get("type") == "assistant":
                for c in m.get("content") or []:
                    if not (isinstance(c, dict) and c.get("type") == "tool_use"):
                        continue
                    tu_name[c.get("id")] = c.get("name")
                    if c.get("name") in ("Agent", "Task"):
                        p["agent"] += 1
                    if c.get("name") == "Bash":
                        cmd = str((c.get("input") or {}).get("command") or "")
                        if "snapshot-update.sh" in cmd and re.search(r"--row-(add|replace)\b", cmd):
                            p["rowops"] += 1
                            if any(d in cmd for d in p["nw"]):
                                p["rowops_named"] += 1
            for s in texts(r):
                if PHRASE in s:
                    p["phrase"] += 1
                    for mm in DISPATCH_RE.finditer(s):
                        tui = mm.group(2)
                        w = WHY_RE.search(s[mm.end():mm.end() + 600])
                        p["nw"].setdefault(tui, why_class(w.group(1) if w else ""))
                if DENY in s and r.get("type") == "user":
                    for c in m.get("content") or [] if isinstance(m.get("content"), list) else []:
                        if isinstance(c, dict) and c.get("type") == "tool_result" and DENY in "".join(texts(c)):
                            if tu_name.get(c.get("tool_use_id")) in ("Agent", "Task"):
                                p["deny"].add(c.get("tool_use_id"))
    return P


def report(P, periods):
    for lab, a, b in periods:
        p = P[lab]
        k = collections.Counter(p["nw"].values())
        print("%s [%s, %s): lead records %d; AGENT %d; DENY %d; NOT-WRITTEN %d dispatches (%s); ROW-OPS %d, %d naming a "
              "NOT-WRITTEN dispatch; controls: hook phrase in %d strings, impossible phrase %d" % (
                  lab, a, b, p["recs"], p["agent"], len(p["deny"]), len(p["nw"]),
                  ", ".join("%s %d" % kv for kv in sorted(k.items())) or "none", p["rowops"], p["rowops_named"],
                  p["phrase"], p["imp"]))
        if p["recs"] and not p["agent"]:
            print("  CONTROL FAILED: lead records but no Agent call in %s" % lab)


def self_test():
    s = (PHRASE + " a1b2 toolu_01ABC. The dispatch ran\nWhy: the brief carries no `Deliverable: <path>` line with a path\n"
         "Write the row with this one call:")
    ok = 0; n = 0
    m = DISPATCH_RE.search(s); n += 1; ok += bool(m and m.group(2) == "toolu_01ABC")
    w = WHY_RE.search(s[m.end():]); n += 1; ok += why_class(w.group(1)) == "no-deliverable-line"
    n += 1; ok += why_class("wait-for-deliverable.sh --dispatch-ts toolu_x printed no ledger ts") == "no-ledger-ts"
    n += 1; ok += why_class("snapshot-update.sh --row-add exited 2: x") == "snapshot-update-refused"
    n += 1; ok += DISPATCH_RE.search("in-flight row written for dispatch toolu_1") is None
    print("self-test: %d of %d %s" % (ok, n, "PASS" if ok == n else "FAIL"))
    return 0 if ok == n else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--self-test"]:
        sys.exit(self_test())
    if len(a) < 2:
        sys.exit(__doc__)
    periods = []
    for x in a[1:]:
        lab, rng = x.split("=", 1); s, e = rng.split("..", 1); periods.append((lab, s, e))
    report(scan(a[0], periods), periods)
