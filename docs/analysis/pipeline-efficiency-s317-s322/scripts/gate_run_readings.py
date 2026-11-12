"""BL-819 item 2(a) readings that gate_run_evidence.py does not print.  Records-only, stdlib.
gate_run_evidence.py is IMPORTED (its scan(), outcome(), resolve_tuple(), parse_gt(), gt_parse() and predicates), never
restated, so a row here is exactly one of its in-step hand-run rows.

usage: python3 -I gate_run_readings.py [--self-test]           (honours $EXTRACT_ROOT, $EXTRACT_WIN_END)
       python3 -I gate_run_readings.py --totals <OUT>          (roll.py --classes with every STORIES value 1: totals)

(A) RESOLVABILITY of each in-step hand-run row's verdict (the denominator of "found something").  The command is split
    on `||` `&&` `|` `;` `&` and newline after strip_heredocs(), with `N>&M` and `&>` read as redirects.  The row's
    validator is the segment at ITS OWN index (one row per invocation, in order).  Classes:
      resolvable        resolved result, and nothing non-blank follows the validator's segment: its exit is the
                        command's exit.
      echo-resolved     the next segment, after `;` or newline, is an `echo` carrying `$?`, and the output carries the
                        echo's literal label followed by a number: that number is the validator's exit.
      masked-and        only `&&` separators follow (`v.sh && cmd2`): a non-zero exit may be cmd2's, so the row is
                        unresolved unless echo-resolved.
      masked-pipe / masked-sequence / masked-or / masked-background / masked-substitution
                        the exit status the transcript records is not the validator's.
      UNRESOLVED-*      gate_run_evidence.outcome(): background, persisted output, no result in the window.
    Of the resolvable and echo-resolved rows, the exit is read with the tuple's recorded codes (outcome noop set) as
    gate_run_evidence does: found / clean / recorded.
(B) RECONCILIATION of hand-run CALL counts under alternative predicates, per sprint (the uncommitted b255 probe's
    167/52 had no recorded predicate).
(C) gate-transition.sh invocations that carry a LITERAL story index and gate (the only ones the repeat join can use).
"""
import collections, importlib.util, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("gate_run_evidence", os.path.join(HERE, "gate_run_evidence.py"))
g = importlib.util.module_from_spec(_spec)
_argv = sys.argv; sys.argv = [_spec.origin]; _spec.loader.exec_module(g); sys.argv = _argv

SEP = re.compile(r"(\|\||&&|[|;&\n])")
LEAD_WORDS = ("bash", "sh", "env", "python", "python3")


def segments(cmd):
    """[(basename or None, raw segment, separator after it or None)], the separator None when nothing non-blank follows."""
    c = re.sub(r"\d?>&\d|&>", " ", g.strip_heredocs(cmd))
    parts = SEP.split(c)
    out = []
    for i in range(0, len(parts), 2):
        w = [x.strip("\"'()") for x in parts[i].split()]
        while w and (w[0] in LEAD_WORDS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])):
            w = w[1:]
        rest = [x for x in parts[i + 2::2] if x.strip()]
        out.append((os.path.basename(w[0]) if w else None, parts[i], parts[i + 1] if (i + 1 < len(parts) and rest) else None))
    return out


def classify(cmd, script, occurrence, text):
    """(class, exit or None) for the `occurrence`-th invocation of `script` in cmd (0-based)."""
    ss = segments(cmd)
    idx = [k for k, s in enumerate(ss) if s[0] == script]
    if occurrence >= len(idx):
        # a validator inside `$(...)` or backticks is not in command position of any segment
        if any(re.search(r"(\$\(|`)[^`)]*" + re.escape(script), s[1]) for s in ss):
            return "masked-substitution", None
        return "unparsed", None
    k = idx[occurrence]
    b, raw, after = ss[k]
    if re.search(r"(\$\(|`)[^`)]*" + re.escape(script), raw):
        return "masked-substitution", None
    trailing = [s[2] for s in ss[k:] if s[2] is not None]
    if not trailing:
        return "resolvable", None
    if all(x == "&&" for x in trailing):
        # `v.sh && cmd2`: when v.sh passes, the recorded exit is cmd2's, so a non-zero exit is not the validator's
        return "masked-and", None
    if after == "&&":
        after = next(x for x in trailing if x != "&&")
    if after in (";", "\n") and k + 1 < len(ss):
        nxt = ss[k + 1][1]
        m = re.match(r"""\s*echo\s+(?:-e\s+)?["']?([^"'$]*)\$\?""", nxt)
        if m and m.group(1).strip():
            lab = m.group(1)
            # the text carries the tool_result content AND toolUseResult stdout, so one echo can appear twice:
            # resolved iff every hit agrees
            hit = set(re.findall(re.escape(lab) + r"(\d+)", text))
            if len(hit) == 1:
                return "echo-resolved", int(hit.pop())
        return "masked-sequence", None
    return {"|": "masked-pipe", "||": "masked-or", "&": "masked-background"}.get(after, "masked-other"), None


def verdict(code, tup):
    return "clean" if code == 0 else ("recorded" if code in tup["noop"] else "found")


def readings(W):
    tuples, sibs = g.parse_gt(g.GT_PATH)
    known = {t["script"] for t in tuples}
    calls, st = g.scan(g.ROOT, W)
    A = collections.defaultdict(collections.Counter)
    V = collections.defaultdict(collections.Counter)
    B = collections.defaultdict(lambda: collections.defaultdict(set))
    C = collections.defaultdict(collections.Counter)
    found_rows = collections.defaultdict(list)
    for c in calls:
        if c["side"] or c["t"] > W or c["t"] < g.BBS_WIN_START:
            continue
        s = g.sprint_of(c["t"])
        if s not in g.SPRINTS:
            continue
        bases = [b for b, _ in c["invs"]]
        gate = any(b in g.GATE_SCRIPTS for b in bases)
        for b, a in c["invs"]:
            if b == "gate-transition.sh":
                ix, gt, _ = g.gt_parse(a)
                C[s]["invocations"] += 1
                if ix is not None and gt is not None:
                    C[s]["index and gate present"] += 1
                    if not ix.startswith("$") and not gt.startswith("$"):
                        C[s]["index and gate both literal"] += 1
        if not gate:
            if any(b in sibs for b in bases):
                B[s]["any :136 sibling script in command position"].add(c["id"])
            if any(k in c["cmd"] for k in known if k not in g.GATE_SCRIPTS) and "gate-checkpoint.sh" not in c["cmd"] \
                    and "gate-transition.sh" not in c["cmd"]:
                B[s]["any parsed-tuple script as a substring"].add(c["id"])
        if gate:
            continue
        seen = collections.Counter()
        for b, a in c["invs"]:
            occ = seen[b]; seen[b] += 1
            if b in g.GATE_SCRIPTS or b not in known:
                continue
            tup = g.resolve_tuple(b, a, tuples)
            if tup is None or tup["bookkeeping"]:
                continue
            B[s]["hand-run (gate_run_evidence), all steps"].add(c["id"])
            if c["step"] not in g.STEPS_IN:
                continue
            B[s]["hand-run (gate_run_evidence), in-step"].add(c["id"])
            A[s]["rows"] += 1
            kind, code, text = g.outcome(c, W)
            if kind != "resolved":
                A[s][kind] += 1
                continue
            cl, ecode = classify(c["cmd"], b, occ, text)
            A[s][cl] += 1
            if cl == "resolvable":
                v = verdict(code, tup)
            elif cl == "echo-resolved":
                v = verdict(ecode, tup)
            else:
                continue
            V[s][v] += 1
            if v == "found":
                found_rows[s].append((b, tup["mode"], c["step"], cl, code if cl == "resolvable" else ecode))
    out = [f"window {g.BBS_WIN_START} .. {W}   root {g.ROOT}   (rows = gate_run_evidence.py's in-step hand-run rows)"]
    for s in g.SPRINTS:
        out.append(f"== s{s}")
        out.append("(A) in-step hand-run rows by verdict resolvability: " + ", ".join(f"{k} {v}" for k, v in sorted(A[s].items())))
        out.append(f"    resolvable + echo-resolved {A[s]['resolvable'] + A[s]['echo-resolved']} of {A[s]['rows']}; "
                   "their verdicts: " + ", ".join(f"{k} {V[s][k]}" for k in ("found", "clean", "recorded")))
        for r in found_rows[s]:
            out.append(f"    found row: {r[0]} {r[1]} step {r[2]} via {r[3]} exit {r[4]}")
        for k in sorted(B[s]):
            out.append(f"(B) calls, {k}: {len(B[s][k])}")
        out.append("(C) gate-transition.sh " + ", ".join(f"{k} {v}" for k, v in C[s].items()))
    return out


def totals(OUT):
    sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
    import roll
    roll.STORIES = {k: 1 for k in roll.STORIES}
    print("roll.py --classes with STORIES set to 1 for every sprint: every per-story cell below is a sprint TOTAL")
    roll.classes(OUT)


def selftest():
    fails = []
    def chk(name, got, want):
        ok = got == want
        print(("  PASS  " if ok else "  FAIL  ") + f"{name}: {got!r}" + ("" if ok else f" (want {want!r})"))
        if not ok: fails.append(name)
    v = "validate-x.sh"
    chk("bare invocation is resolvable", classify(f"scripts/{v} --a", v, 0, "")[0], "resolvable")
    chk("2>&1 is a redirect, not a background separator (near-miss)", classify(f"scripts/{v} 2>&1", v, 0, "")[0], "resolvable")
    chk("v && cmd2 is masked-and: cmd2's exit is not the validator's", classify(f"{v} && echo ok && echo done", v, 0, "")[0], "masked-and")
    chk("a validator LAST in an && chain is resolvable (near-miss)", classify(f"cd x && {v} --a", v, 0, "")[0], "resolvable")
    chk("&& then ; is masked", classify(f"{v} && echo ok; echo done", v, 0, "")[0], "masked-sequence")
    chk("pipe is masked", classify(f"{v} | tail -3", v, 0, "")[0], "masked-pipe")
    chk("|| is masked", classify(f"{v} || true", v, 0, "")[0], "masked-or")
    chk("substitution is masked", classify(f"x=$({v} --q)", v, 0, "")[0], "masked-substitution")
    chk("a substitution in an ARGUMENT does not mask (near-miss)", classify(f'{v} --f "$(cat f)"', v, 0, "")[0], "resolvable")
    chk("per-occurrence: first piped, second last",
        [classify(f"sprint-status.sh check-stories | tail; sprint-status.sh derive-stories --check", "sprint-status.sh", i, "")[0] for i in (0, 1)],
        ["masked-pipe", "resolvable"])
    chk("echo label resolves the exit", classify(f'{v} > /tmp/o 2>&1; echo "c22 rc=$?"; grep X /tmp/o', v, 0, "noise\nc22 rc=3\n"), ("echo-resolved", 3))
    chk("echo duplicated in content and stdout still resolves", classify(f'{v}; echo "rc=$?"', v, 0, "rc=1\n\nrc=1\n"), ("echo-resolved", 1))
    chk("two different values under one label stay masked", classify(f'{v}; echo "rc=$?"', v, 0, "rc=1\nrc=0\n"), ("masked-sequence", None))
    chk("echo label absent from output stays masked", classify(f'{v}; echo "c22 rc=$?"', v, 0, "nothing"), ("masked-sequence", None))
    chk("echo after a pipe is not the validator's", classify(f'{v} | head -1; echo "rc=$?"', v, 0, "rc=0"), ("masked-pipe", None))
    chk("verdict: 0 clean, recorded code, other found",
        [verdict(c, {"noop": {4}}) for c in (0, 4, 1)], ["clean", "recorded", "found"])
    print("SELF-TEST " + ("OK" if not fails else "FAILED: " + ", ".join(fails)))
    sys.exit(0 if not fails else 1)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        selftest()
    if "--totals" in sys.argv:
        totals(sys.argv[sys.argv.index("--totals") + 1]); sys.exit(0)
    print("\n".join(readings(g.WIN_END)))
