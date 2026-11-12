r"""BL-512: count DISCARDED gate nonces per gate, per sprint, normalised per verdict, with a reason class,
and count dispatch-guard refusals of a gate-adjudicator dispatch SEPARATELY.

One counter, applied identically to every sprint it prints (s317, s318, s321 and s322 are the rule's rows;
s319 and s320 print for context). Read-only on both inputs: graph is read through `git ls-tree` and
`git show` on a clone, never a checkout, and the transcripts are only opened for reading.

usage:
  python3 count_discards.py --graph <graph clone> --ref <rev> --win-end <ISO Z> [--transcripts DIR]
                            [--extract <extract.py>] [--sprints 317,318,319,320,321,322]
exit: 0 every control held; 1 a control failed (the figures are then not to be used); 2 the self-probe failed.

Inputs.
  ARTIFACTS, in the graph tree at --ref, excluding `tests/` and `scripts/`:
    - `gate-adjudication/<gate_type>-<YYYYMMDDTHHMMSSZ>.(part-KofN.jsonl|verdict.json)`, wherever the
      directory sits (the live one and each `s<N>/` archive). A nonce in two places is one nonce.
    - `_bmad-output/**/gate-log*.md` (the Check 12 log and its per-sprint archives). Each `## ` entry's own
      nonce is the first `nonce <n>` its prose names (the field spelling varies by sprint: "nonce `<n>`",
      "nonce: <n>", "Nonce: <n>"); its `| FAILED |` table rows are FAIL rows ("FAILED (WAIVED)" is not).
      The lead can amend a log entry to FAILED after an all-PASS verdict merged and re-issue the gate
      (s317 `implementation-20261009T192841Z`, Check 1), which no verdict file shows.
  TRANSCRIPTS: the top-level lead `*.jsonl` under --transcripts (default ~/.claude/projects/-Users-n8-git-graph),
    sidechain records skipped, records later than --win-end ignored. A nonce is ISSUED by the lead when
      - a Bash tool_result prints `gate-checkpoint: opened <n>` (this resolves the `$N` the lead passes), or
      - a Bash tool_use runs `gate-checkpoint.sh --nonce <literal n> open`, or
      - an Agent/Task tool_use input carries <n> (the adjudicator dispatch, and gate-transition's minted nonce),
    and the record is within 24 h after the nonce's own timestamp, so a later sprint reading an old verdict
    issues nothing. A nonce `gate-checkpoint` opened in a non-canonical form (`implementation-2026-10-11T083048Z`)
    is kept, normalised to the canonical key, and flagged `malformed`.
  SPRINT: sprint_of(<nonce timestamp>), with the EDGES list read (ast.literal_eval, not imported) from --extract.

Definitions. The DISCARDED rule, the reason classes and the decision rule were fixed before the first run.
The gate-log channel, the `opened` channel and the malformed-nonce handling were added AFTER the first run, to
reach the before side's documented discards (`192841Z`, `083048Z`, `232108Z`) that it missed. They raised the
before side (implementation 4/26 -> 6/26, planning 0/6 -> 1/6), which makes LOWER easier to read, not harder.
`exception` was dropped from the waiver pattern after the first run, because it matched `invalid-exception`
(no class moved: all four Check 22 FAILs name an OVERRIDDEN entry). The successor requirement and the rule that a
refused dispatch issues nothing were also added after it, and they LOWERED the after side: s321 implementation
8 -> 6 and s320 4 -> 3 (Check 9 FAILs each gate-logged as PASSED under an in-force suppression, Check 26 PASSED,
and no later nonce for the story), s322 implementation 8/15 -> 7/15 (`implementation-20261112T015713Z`, carried
only by a refused call and re-minted as `...T015823Z`). Every before-side discard has no story slug, so its
successor test is the same-type fallback, which any later nonce of the gate type satisfies: the requirement
cannot remove a before-side discard. No LOWER/NOT LOWER reading changed.
  Gate types counted: planning and story (the planning gates) and implementation. sprint-review and retro are
    not counted: the every-gate total waits for s322's retro.
  ISSUED nonce: in ARTIFACTS or ISSUED in TRANSCRIPTS, with its own timestamp <= --win-end.
  VERDICT: a nonce with a merged `.verdict.json`. This is the per-verdict denominator.
  DISCARDED: an issued nonce that did not pass: no merged verdict (abandoned, or re-issued before the merge),
    a verdict carrying at least one FAIL check row, or a gate-log entry for it carrying a FAILED row.
    A re-adjudication at the SAME nonce is not a new nonce and not a discard. It must also have a SUCCESSOR:
    a later nonce in the same sprint for the same story where its series id carries a story slug
    (`implementation-story1x4-s322-...`), else a later nonce of the same gate type. A non-passing nonce with no
    successor settled its gate, was neither abandoned nor re-issued, and is listed apart, not counted.
    An unclosed gate (BL-1003: `gate-checkpoint.sh close` never run) is not itself a discard here: this counter
    reads nonces and verdicts, never the open..close span.
  REASON CLASS of a discard, from its FAIL rows (verdict, else the union of its parts, plus its gate-log rows):
    c22-waiver  a Check 22 FAIL whose evidence names a waiver or an OVERRIDDEN entry      (lead-caused)
    lead-other  no FAIL row at all: the lead abandoned or re-issued the pass with no adjudicator finding
                (malformed nonce, lapsed window, re-mint)                                (lead-caused)
    other       any other FAIL row (the failing check ids are printed per nonce, so a reader can re-class)
  REFUSAL: a lead Agent/Task tool_use whose tool_result is an error carrying the dispatch guard's refusal of a
    gate-adjudicator dispatch ("dispatch guard: refused a gate-adjudicator dispatch", with or without the
    backticks). Counted per sprint by the record's timestamp, and never folded into the discard count: a
    refused dispatch mints no verdict and writes no spawn-ledger row.

Controls printed in the same invocation:
  SELF-PROBE  the classifier functions on seeded in-memory records: a seeded refusal counts 1; a concurrency-cap
              error and another role's refusal count 0; a seeded Check 22 waiver classes c22-waiver; an all-PASS
              verdict does not discard; an abandoned nonce classes lead-other; a Check 21 FAIL classes other.
  POSITIVE    the three measured Check 22 discards, resolved to FULL nonces: every nonce carrying each bare
              suffix is listed, and the one in the stated sprint must class c22-waiver.
  IMPOSSIBLE  a nonce token absent from the transcripts and the tree reads 0, beside a present token, non-zero.
"""
import ast, collections, datetime as dt, glob, json, os, re, subprocess, sys

GATES = ("planning", "story", "implementation")
TYPES = r"(?:planning|story|implementation|sprint-review|retro)"
NONCE_RX = re.compile(r"(?<![A-Za-z-])(" + TYPES[3:-1] + r")-(20\d{6}T\d{6}Z)(?![0-9A-Za-z])")
CANON_RX = re.compile(TYPES + r"-20\d{6}T\d{6}Z")
ART_RX = re.compile(r"(?:^|/)gate-adjudication/(" + TYPES[3:-1] + r")-(20\d{6}T\d{6}Z)"
                    r"\.(part-\d+of\d+\.jsonl|verdict\.json)$")
OPEN_RX = re.compile(r"gate-checkpoint\.sh\s+(?:--root\s+\S+\s+)?--nonce\s+[\"']?([^\s\"']+)[\"']?\s+open\b")
OPENED_RX = re.compile(r"gate-checkpoint: opened (" + TYPES + r"-[0-9T:-]+Z)")
GATELOG_RX = re.compile(r"^_bmad-output/.*gate-log[^/]*\.md$")
ENTRY_NONCE_RX = re.compile(r"(?i)\bnonce\W{1,3}(" + TYPES + r"-20\d{6}T\d{6}Z)")
LOG_FAIL_RX = re.compile(r"^\|\s*(?:\[[A-Za-z0-9_-]+\]\s*)?([0-9]+[a-z]?|H\d+)\b[^|]*\|\s*FAILED\s*\|(.*)$")
REFUSAL_RX = re.compile(r"dispatch guard: refused an? `?gate-adjudicator`? dispatch, because ([^.]{0,60})")
WAIVER_RX = re.compile(r"waiv|OVERRIDDEN", re.I)
SLUG_RX = re.compile(TYPES + r"-(story[a-z0-9]+)-s\d+-")
IMPOSSIBLE = "implementation-20991231T235959Z"
PRESENT = "implementation-20261010T230257Z"


def arg(name, default=None):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


def iso_of_nonce_ts(ts):  # 20261009T124524Z -> 2026-10-09T12:45:24Z
    return "%s-%s-%sT%s:%s:%sZ" % (ts[0:4], ts[4:6], ts[6:8], ts[9:11], ts[11:13], ts[13:15])


def pt(s):
    return dt.datetime.fromisoformat(s[:19] + "+00:00")


def canon(n):
    """implementation-2026-10-11T083048Z -> (implementation-20261011T083048Z, True)."""
    if CANON_RX.fullmatch(n):
        return n, False
    m = re.fullmatch("(" + TYPES + r")-(\d{4})-?(\d{2})-?(\d{2})T(\d{2}):?(\d{2}):?(\d{2})Z", n)
    if not m:
        return None, True
    return "%s-%s%s%sT%s%s%sZ" % m.groups(), True


def load_edges(path):
    tree = ast.parse(open(path).read())
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "EDGES" for t in node.targets):
            return ast.literal_eval(node.value)
    raise SystemExit("EDGES not found in %s" % path)


def sprint_of(edges, t):
    for e, n in edges:
        if t < e:
            return n
    return None


def classify(has_verdict, rows):
    """-> (discarded, reason, failing check ids). rows: per-check dicts {check_id, verdict, evidence}."""
    f = [r for r in rows if str(r.get("verdict", "")).upper() in ("FAIL", "FAILED")]
    if has_verdict and not f:
        return False, None, []
    ids = sorted({str(r.get("check_id")) for r in f}, key=lambda x: (len(x), x))
    if any(str(r.get("check_id")) == "22" and WAIVER_RX.search(json.dumps(r.get("evidence", ""))) for r in f):
        return True, "c22-waiver", ids
    if not f:
        return True, "lead-other", ids
    return True, "other", ids


def successor(r, peers):
    """A later nonce for the SAME story where the series id names one, else any later nonce of the gate type.
    peers: the rows of r's sprint and gate type. -> same-story | same-type | none."""
    k = r["nonce"].rsplit("-", 1)[1]
    later = [x for x in peers if x["nonce"].rsplit("-", 1)[1] > k]
    if r["story"]:
        return "same-story" if any(x["story"] == r["story"] for x in later) else "none"
    return "same-type" if later else "none"


def is_refusal(tool_use, result_text, is_error):
    if tool_use is None or tool_use.get("name") not in ("Agent", "Task"):
        return False
    return bool(is_error) and bool(REFUSAL_RX.search(result_text or ""))


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(c.get("text", "") if isinstance(c, dict) else str(c) for c in content)
    return ""


def strings_in(o):
    if isinstance(o, str):
        yield o
    elif isinstance(o, dict):
        for v in o.values():
            for s in strings_in(v):
                yield s
    elif isinstance(o, list):
        for v in o:
            for s in strings_in(v):
                yield s


def _probe_rows(story, others):
    """A subject row at minute 1 with `story`, and peers (story, minute); minute 0 is EARLIER than the subject."""
    def row(st, minute):
        return {"nonce": "implementation-20261111T00%02d00Z" % minute, "story": st}
    subject = row(story, 1)
    return subject, [subject] + [row(st, m) for st, m in others]


def self_probe():
    tu = {"name": "Agent", "input": {"subagent_type": "gate-adjudicator"}}
    got = dict(
        refusal=int(is_refusal(tu, "PreToolUse:Agent hook error: AI/DLC dispatch guard: refused a gate-adjudicator "
                                   "dispatch, because the gate would discard its pass.", True)),
        refusal_backtick=int(is_refusal(tu, "AI/DLC dispatch guard: refused a `gate-adjudicator` dispatch, because "
                                            "its brief carries no line", True)),
        cap_error=int(is_refusal(tu, "Concurrent subagent limit reached. Do not retry", True)),
        other_role=int(is_refusal(tu, "AI/DLC dispatch guard: refused a `dev` dispatch, because", True)),
        read_of_guard=int(is_refusal({"name": "Read"}, "refused a gate-adjudicator dispatch, because x", False)),
        c22=classify(True, [{"check_id": "1", "verdict": "PASS"},
                            {"check_id": "22", "verdict": "FAIL", "evidence": "OVERRIDDEN waiver names no spawn"}])[1],
        allpass_discarded=int(classify(True, [{"check_id": "1", "verdict": "PASS"}])[0]),
        abandoned=classify(False, [])[1],
        other=classify(True, [{"check_id": "21", "verdict": "FAIL", "evidence": "Strategy Test ID"}])[1],
        c22_no_waiver=classify(True, [{"check_id": "22", "verdict": "FAIL",
                                       "evidence": "3 remediator rows shard=invalid-exception, no exception cited"}])[1],
        succ_same_story=successor(*_probe_rows("story1x4", [("story9", 2), ("story1x4", 3)])),
        succ_other_story_only=successor(*_probe_rows("story1x4", [("story9", 2), ("story1x4", 0)])),
        succ_no_slug=successor(*_probe_rows(None, [("story9", 2)])),
        succ_none_no_slug=successor(*_probe_rows(None, [(None, 0)])),
        entry_nonce=(ENTRY_NONCE_RX.search("Gate: planning | nonce: planning-20261109T134906Z | series: x") or
                     [None, None])[1],
        log_row=(LOG_FAIL_RX.match("| [core] 1 — Validation cycle complete | FAILED | gate-1 x |") or [None, None])[1],
        log_pass=int(bool(LOG_FAIL_RX.match("| [core] 1 — Validation cycle complete | PASSED | x |"))),
        canon=canon("implementation-2026-10-11T083048Z")[0])
    want = dict(refusal=1, refusal_backtick=1, cap_error=0, other_role=0, read_of_guard=0, c22="c22-waiver",
                allpass_discarded=0, abandoned="lead-other", other="other", c22_no_waiver="other",
                entry_nonce="planning-20261109T134906Z", log_row="1", log_pass=0,
                succ_same_story="same-story", succ_other_story_only="none", succ_no_slug="same-type",
                succ_none_no_slug="none",
                canon="implementation-20261011T083048Z")
    ok = all(got[k] == want[k] for k in want)
    print("SELF-PROBE %s %s" % ("OK" if ok else "FAILED", " ".join("%s=%s" % (k, got[k]) for k in sorted(got))))
    return ok


def git(graph, *a):
    return subprocess.run(["git", "-C", graph] + list(a), check=True, capture_output=True).stdout


def main():
    graph = arg("--graph")
    ref = arg("--ref")
    win_end = arg("--win-end")
    tdir = arg("--transcripts", os.path.expanduser("~/.claude/projects/-Users-n8-git-graph"))
    extract = arg("--extract", "docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py")
    sprints = [int(x) for x in arg("--sprints", "317,318,319,320,321,322").split(",")]
    if not (graph and ref and win_end):
        raise SystemExit(__doc__)
    edges = load_edges(extract)
    if not self_probe():
        sys.exit(2)

    # ---------- artifacts
    full = git(graph, "rev-parse", ref).decode().strip()
    names = git(graph, "ls-tree", "-r", "--name-only", "--full-tree", full).decode().splitlines()
    art = collections.defaultdict(lambda: {"verdict": None, "parts": []})
    logrows = collections.defaultdict(list)
    logcells = collections.Counter()
    nfiles = nlogs = nentries = 0
    for p in names:
        if p.startswith("tests/") or p.startswith("scripts/"):
            continue
        m = ART_RX.search(p)
        if m:
            nfiles += 1
            n = "%s-%s" % (m.group(1), m.group(2))
            if m.group(3) == "verdict.json":
                art[n]["verdict"] = p
            else:
                art[n]["parts"].append(p)
        elif GATELOG_RX.match(p):
            nlogs += 1
            cur, seen = None, False
            for ln in git(graph, "show", "%s:%s" % (full, p)).decode(errors="replace").splitlines():
                if re.search(r"\|\s*FAILED\s*\|", ln):
                    logcells["raw"] += 1
                if ln.startswith("## "):
                    cur, seen = None, False
                elif not seen and not ln.startswith("|"):
                    em = ENTRY_NONCE_RX.search(ln)
                    if em:  # the entry's own nonce is the first one its prose names
                        cur, seen = em.group(1), True
                        nentries += 1
                        logrows[cur]  # an entry with no FAILED row still records the nonce
                elif cur is not None:
                    fm = LOG_FAIL_RX.match(ln)
                    if fm:
                        logcells["matched"] += 1
                        logrows[cur].append({"check_id": fm.group(1), "verdict": "FAIL", "evidence": fm.group(2),
                                             "src": "log"})
    print("POPULATION artifacts: graph clone %s (git clone file:///Users/n8/git/graph, then fetch "
          "+refs/*:refs/remotes/all/*), ref %s = %s; %d gate-adjudication files over %d nonces; %d gate-log files "
          "with %d nonce entries (tests/ and scripts/ excluded). The ref survives only until graph prunes it."
          % (graph, ref, full, nfiles, len(art), nlogs, nentries))
    print("POPULATION gate-log cells: %d `| FAILED |` cells in the gate-log files, %d of them inside an entry with a "
          "nonce and read as a FAIL row" % (logcells["raw"], logcells["matched"]))

    # ---------- transcripts
    files = sorted(glob.glob(os.path.join(tdir, "*.jsonl")))
    issued = {}            # canonical nonce -> first issuing record timestamp
    malformed = {}         # canonical nonce -> raw form, for an opened non-canonical nonce
    refusals = []          # (ts, file, reason head, nonces the refused call carried)
    uncounted = collections.Counter()  # refusal text in a result that is not an errored Agent/Task result
    hits = collections.Counter()
    earliest = None

    def issue(n, ts):
        c, bad = canon(n)
        if not c:
            return
        nts = iso_of_nonce_ts(c.rsplit("-", 1)[1])
        if nts <= ts[:19] + "Z" and (pt(ts) - pt(nts)).total_seconds() <= 86400:
            if bad:
                malformed[c] = n
            if c not in issued or ts < issued[c]:
                issued[c] = ts

    for f in files:
        pending = {}
        for line in open(f, errors="replace"):
            if IMPOSSIBLE in line:
                hits["impossible"] += 1
            if PRESENT in line:
                hits["present"] += 1
            try:
                r = json.loads(line)
            except ValueError:
                continue
            ts = r.get("timestamp")
            if not ts:
                continue
            if earliest is None or ts < earliest:
                earliest = ts
            if ts > win_end or r.get("isSidechain"):
                continue
            content = (r.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for c in content:
                if not isinstance(c, dict):
                    continue
                if c.get("type") == "tool_use":
                    inp = c.get("input", {})
                    ns = []
                    if c.get("name") in ("Agent", "Task"):
                        ns = sorted({m.group(0) for s in strings_in(inp) for m in NONCE_RX.finditer(s)})
                    elif c.get("name") == "Bash":
                        for m in OPEN_RX.finditer(inp.get("command", "") if isinstance(inp, dict) else ""):
                            issue(m.group(1), ts)
                    pending[c.get("id")] = (c, ns, ts)
                elif c.get("type") == "tool_result":
                    tu, ns, uts = pending.pop(c.get("tool_use_id"), (None, [], ts))
                    txt = text_of(c.get("content"))
                    if tu is not None and tu.get("name") == "Bash":
                        for m in OPENED_RX.finditer(txt):
                            issue(m.group(1), ts)
                    if is_refusal(tu, txt, c.get("is_error")):
                        # a refused dispatch issues nothing: its nonces are reported beside the refusal
                        refusals.append((ts, os.path.basename(f)[:8], REFUSAL_RX.search(txt).group(1).strip(), ns))
                        continue
                    if REFUSAL_RX.search(txt):
                        uncounted[(tu.get("name") if tu else "no-tool_use") + ("/is_error" if c.get("is_error")
                                                                               else "/not-error")] += 1
                    for n in ns:
                        issue(n, uts)
        for tu, ns, uts in pending.values():  # a dispatch whose result the file never recorded
            for n in ns:
                issue(n, uts)
    print("POPULATION transcripts: %s, %d top-level *.jsonl, earliest record %s, records > %s ignored. "
          "s317 opened 2026-10-05T14:00Z, before the earliest record, so s317's transcript side is partial "
          "(its artifacts are whole)." % (tdir, len(files), earliest, win_end))
    print("CONTROL impossible token %s: %d transcript records, %d in tree (both must be 0); present token %s: "
          "%d transcript records (must be > 0)"
          % (IMPOSSIBLE, hits["impossible"], int(IMPOSSIBLE in art or IMPOSSIBLE in logrows), PRESENT, hits["present"]))

    # ---------- join
    allnonces = set(art) | set(issued) | set(logrows)
    rows = []
    for n in sorted(allnonces, key=lambda x: x.rsplit("-", 1)[1]):
        gtype, ts = n.rsplit("-", 1)
        nts = iso_of_nonce_ts(ts)
        if nts > win_end:
            continue
        a = art.get(n)
        checks, has_v, series = [], False, None
        if a and a["verdict"]:
            has_v = True
            vd = json.loads(git(graph, "show", "%s:%s" % (full, a["verdict"])))
            series = vd.get("gate_series_id")
            checks = list(vd.get("verdicts", []))
        elif a:
            for p in a["parts"]:
                for ln in git(graph, "show", "%s:%s" % (full, p)).decode(errors="replace").splitlines():
                    try:
                        o = json.loads(ln)
                    except ValueError:
                        continue
                    if isinstance(o, dict) and "check_id" in o:
                        checks.append(o)
                        series = series or o.get("gate_series_id")
                    elif isinstance(o, dict) and isinstance(o.get("verdicts"), list):
                        checks += o["verdicts"]
                        series = series or o.get("gate_series_id")
        checks += logrows.get(n, [])
        d, reason, ids = classify(has_v, checks)
        src = ("A" if a else "") + ("L" if n in logrows else "") + ("T" if n in issued else "")
        sm = SLUG_RX.match(series or "")
        rows.append(dict(nonce=n, gate=gtype, sprint=sprint_of(edges, nts), verdict=has_v, discarded=d, reason=reason,
                         fails=ids, src=src, parts=len(a["parts"]) if a else 0, story=sm.group(1) if sm else None,
                         logfail=any(x.get("src") == "log" for x in checks), malformed=malformed.get(n)))
    by = collections.defaultdict(list)
    for r in rows:
        by[(r["sprint"], r["gate"])].append(r)
    for r in rows:
        r["succ"] = successor(r, by[(r["sprint"], r["gate"])])
        if r["discarded"] and r["succ"] == "none":
            # a non-passing pass nothing replaced settled the gate (a Check 26 suppression, or the sprint's end):
            # it was neither abandoned nor re-issued, so it is listed apart and not counted as a discard
            r["discarded"], r["settled_fail"] = False, True

    print("\nDISCARDS  (src: A artifact, L gate-log entry, T issued in a lead transcript; succ: the successor nonce, "
          "keyed on the series id's story slug where it has one)")
    for r in rows:
        if r.get("settled_fail") and r["gate"] in GATES and r["sprint"] in sprints:
            print("  NOT COUNTED, no successor (a FAIL that settled its gate): s%s %s %s fails=%s story=%s"
                  % (r["sprint"], r["gate"], r["nonce"], ",".join(r["fails"]), r["story"]))
    for r in rows:
        if r["discarded"] and r["gate"] in GATES and r["sprint"] in sprints:
            print("  s%s %-14s %-32s src=%-3s verdict=%s parts=%d logFAILED=%s %-10s fails=%s succ=%s%s%s"
                  % (r["sprint"], r["gate"], r["nonce"], r["src"], "Y" if r["verdict"] else "N", r["parts"],
                     "Y" if r["logfail"] else "N", r["reason"], ",".join(r["fails"]) or "-", r["succ"],
                     (" story=" + r["story"]) if r["story"] else "",
                     (" malformed-as=" + r["malformed"]) if r["malformed"] else ""))

    print("\nTABLE  sprint gate | issued verdicts discarded | c22-waiver lead-other other | discards/verdict"
          " | issued only in a transcript | gate-log entries")
    fig = {}
    for sp in sprints:
        for g in GATES:
            rs = by.get((sp, g), [])
            v = sum(r["verdict"] for r in rs)
            ds = [r for r in rs if r["discarded"]]
            c = collections.Counter(r["reason"] for r in ds)
            fig[(sp, g)] = (len(ds), v)
            print("  s%s %-14s | %3d %3d %3d | %3d %3d %3d | %s | %d | %d" % (
                sp, g, len(rs), v, len(ds), c["c22-waiver"], c["lead-other"], c["other"],
                ("%.3f" % (len(ds) / v)) if v else "n/a", sum(1 for r in rs if r["src"] == "T"),
                sum(1 for r in rs if "L" in r["src"])))

    print("\nREFUSALS of a gate-adjudicator dispatch by the dispatch guard (separate from discards):")
    rc = collections.Counter(sprint_of(edges, x[0]) for x in refusals)
    rb = collections.defaultdict(set)
    for x in refusals:
        rb[sprint_of(edges, x[0])].add(x[0][:19])
    for sp in sprints:
        print("  s%s %d records in %d distinct seconds" % (sp, rc.get(sp, 0), len(rb.get(sp, ()))))
    print("  corpus total %d %s" % (len(refusals), dict(sorted(rc.items()))))
    rg = collections.Counter((sprint_of(edges, x[0]), ",".join(sorted({n.rsplit("-", 1)[0] for n in x[3]})) or "none")
                             for x in refusals)
    print("  by sprint and the gate type of the nonce the refused call carried: %s"
          % ", ".join("s%s %s %d" % (k[0], k[1], v) for k, v in sorted(rg.items())))
    print("  refusal text in a result NOT counted (not an errored Agent/Task result): %s"
          % (dict(uncounted) or "none"))
    for ts, f, why, ns in refusals:
        st = ["%s:%s" % (n, "issued-elsewhere" if n in issued else "not-issued") for n in ns]
        print("  refusal %s s%s lead %s: because %s | nonces carried %s" % (ts[:19], sprint_of(edges, ts), f, why,
                                                                           st or "none"))

    print("\nPOSITIVE CONTROL: the three measured Check 22 discards, by full nonce")
    pc = 0
    for suf, sp in (("T230257Z", 317), ("T124524Z", 317), ("T011534Z", 318)):
        cands = sorted(n for n in allnonces if n.endswith(suf))
        print("  suffix %s: every nonce carrying it %s; issued in a lead transcript %s"
              % (suf, cands, sorted(n for n in issued if n.endswith(suf))))
        for r in rows:
            if r["nonce"].endswith(suf) and r["sprint"] == sp:
                print("    s%s %s discarded=%s reason=%s fails=%s" % (sp, r["nonce"], r["discarded"], r["reason"],
                                                                  ",".join(r["fails"])))
                pc += int(r["discarded"] and r["reason"] == "c22-waiver")
    print("  POSITIVE CONTROL %s (%d of 3 class c22-waiver)" % ("OK" if pc == 3 else "FAILED", pc))

    print("\nRULE (FOLD D4): per gate, discards per verdict on s321 AND on s322 below s317+s318 pooled -> LOWER")
    for g in GATES:
        bd = sum(fig.get((s, g), (0, 0))[0] for s in (317, 318))
        bv = sum(fig.get((s, g), (0, 0))[1] for s in (317, 318))
        before = bd / bv if bv else None
        reads = [(sp,) + fig.get((sp, g), (0, 0)) for sp in (321, 322)]
        lower = before is not None and all(v and d / v < before for _, d, v in reads)
        print("  %-14s before s317+s318 %d/%d=%s | %s -> %s" % (
            g, bd, bv, ("%.3f" % before) if before is not None else "n/a",
            " | ".join("s%d %d/%d=%s" % (sp, d, v, ("%.3f" % (d / v)) if v else "n/a") for sp, d, v in reads),
            "LOWER" if lower else "NOT LOWER"))
    if pc != 3 or hits["impossible"] or not hits["present"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
