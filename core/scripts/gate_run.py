# gate_run.py -- every decision gate-run.sh makes. The shell wrapper resolves the root and
# runs this file; usage and the output grammar are in gate-run.sh's header.
import datetime
import glob
import json
import os
import re
import shlex
import subprocess
import sys

SELF = os.environ.get("GR_SELF") or os.path.dirname(os.path.abspath(__file__))
KINDS = ("script", "rule", "judgment", "multi", "lead")
COUNTS = ("native", "legacy", "-")
RES = ("PASS", "FAIL", "SKIP", "PENDING")
DEFAULT_TOKEN = "EXAMINED NOTHING"


class Exit(Exception):
    def __init__(self, code, msg=""):
        Exception.__init__(self, msg)
        self.code = code
        self.msg = msg


def die(code, msg):
    raise Exit(code, msg)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc)


def run(argv, cwd=None, env=None, timeout=1800):
    e = dict(os.environ)
    if env:
        e.update(env)
    p = subprocess.run(argv, cwd=cwd, env=e, stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    return p.returncode, p.stdout.decode("utf-8", "replace")


# ------------------------------------------------------------------ arms file
def skill_dirs(root):
    return [os.path.join(root, ".claude/skills/ai-dlc"), os.path.join(root, "core/skills/ai-dlc")]


def find_skill_dir(root):
    for d in skill_dirs(root):
        if os.path.isdir(os.path.join(d, "gates")):
            return d
    die(2, "gate-run: no gates/ directory under .claude/skills/ai-dlc or core/skills/ai-dlc in %s" % root)


def load_arms(root, gate):
    if not re.match(r"^[a-z][a-z0-9-]*$", gate or ""):
        die(2, "gate-run: --gate %r is not a gate id" % gate)
    sd = find_skill_dir(root)
    path = os.path.join(sd, "gates", gate + ".arms")
    if not os.path.isfile(path):
        die(2, "gate-run: unknown gate id %r: no %s" % (gate, path))
    gtype, rows, seen = None, [], set()
    for n, line in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        if not line.strip():
            continue
        m = re.match(r"^#\s*gate_type:\s*(\S+)\s*$", line)
        if m:
            gtype = m.group(1)
            continue
        if line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) < 4 or len(f) > 5:
            die(2, "gate-run: %s:%d: %d column(s), want 4 or 5" % (path, n, len(f)))
        cid, kind, arm, count = f[0], f[1], f[2], f[3]
        skips = []
        if len(f) == 5 and f[4].strip():
            m = re.match(r"^skip=([A-Za-z0-9_,-]+)$", f[4].strip())
            if not m:
                die(2, "gate-run: %s:%d: 5th column must be skip=<tok>[,<tok>]" % (path, n))
            skips = m.group(1).split(",")
        if kind not in KINDS or count not in COUNTS or not cid or cid in seen:
            die(2, "gate-run: %s:%d: bad kind %r, count %r or duplicate/empty id %r" % (path, n, kind, count, cid))
        if kind in ("judgment", "lead") and (arm != "-" or skips):
            die(2, "gate-run: %s:%d: a %s row carries arm '-' and no skip" % (path, n, kind))
        seen.add(cid)
        rows.append({"id": cid, "kind": kind, "arm": arm, "count": count, "skip": skips, "line": n})
    if gtype is None:
        die(2, "gate-run: %s has no '# gate_type:' header" % path)
    if not rows:
        die(2, "gate-run: %s declares no rows" % path)
    ids = {r["id"] for r in rows}
    for r in rows:
        if r["kind"] == "multi":
            tgt = r["arm"][1:] if r["arm"].startswith("@") else ""
            tr = [x for x in rows if x["id"] == tgt]
            if not tr or tr[0]["kind"] != "script":
                die(2, "gate-run: %s:%d: multi row %s must name a script row as @<row-id>" % (path, r["line"], r["id"]))
    return {"path": path, "gate_type": gtype, "rows": rows, "skill_dir": sd}


def map_titles(sd):
    t, tok = {}, DEFAULT_TOKEN
    p = os.path.join(sd, "enforcement-map.yaml")
    if os.path.isfile(p):
        cur = None
        for line in open(p, encoding="utf-8"):
            m = re.match(r'^  - id: "?([^"\s]+)"?\s*$', line)
            if m:
                cur = m.group(1)
                continue
            m = re.match(r"^    title: (.*)$", line)
            if m and cur:
                t[cur] = m.group(1).strip()
            m = re.match(r"^  token: (.+)$", line)
            if m:
                tok = m.group(1).strip()
    return t, tok


def slice_plan(root, gtype):
    rc, out = run(["bash", os.path.join(SELF, "gate-slice.sh"), "--type", gtype, "--root", root, "--format", "json"],
                  cwd=root)
    try:
        txt = out[out.index("{"):out.rindex("}") + 1]
        return json.loads(txt)
    except ValueError:
        die(2, "gate-run: gate-slice.sh could not derive the %s set: %s" % (gtype, out.strip()[:300]))


# ------------------------------------------------------------------ placeholders
PH_GRAMMAR = {
    "SPRINT": r"[0-9]+", "SHA": r"[0-9a-f]{7,64}", "BASE": r"[0-9a-fA-F]{7,64}|[A-Za-z0-9_./~^-]+",
    "NONCE": r"[a-z-]+-[0-9]{8}T[0-9]{6}Z", "WORKTREE": r"/[A-Za-z0-9_./+@:~-]+",
}


def ph_ok(name, val):
    if val == "" or val.startswith("-") or "\n" in val or "\0" in val:
        return False
    g = PH_GRAMMAR.get(name)
    return re.fullmatch(g, val) is not None if g else True


def build_argv(row, ctx, story=None):
    try:
        words = shlex.split(row["arm"])
    except ValueError as e:
        die(2, "gate-run: row %s: arm does not split: %s" % (row["id"], e))
    if not words:
        die(2, "gate-run: row %s: empty arm" % row["id"])
    first = words[0]
    if "/" in first or ".." in first:
        die(2, "gate-run: row %s: first word %r must be a bare script name" % (row["id"], first))
    vals = dict(ctx)
    if story is not None:
        vals["STORY"] = story
    out = []
    for w in words:
        ms = re.fullmatch(r"\{STORIES(?::(-{1,2}[a-z][a-z-]*))?\}", w)
        if ms:
            lst = ctx.get("STORIES") or []
            if not lst:
                die(2, "gate-run: row %s: {STORIES} has no story file" % row["id"])
            for st_ in lst:
                if not ph_ok("STORY", st_):
                    die(2, "gate-run: row %s: story path outside its grammar: %r" % (row["id"], st_))
                out.extend(([ms.group(1)] if ms.group(1) else []) + [st_])
            continue
        def sub(m):
            name = m.group(1)
            if name not in vals or vals[name] in (None, ""):
                die(2, "gate-run: row %s: placeholder {%s} is unfilled; pass the flag that supplies it" % (row["id"], name))
            if not ph_ok(name, vals[name]):
                die(2, "gate-run: row %s: value for {%s} is outside its grammar: %r" % (row["id"], name, vals[name]))
            return vals[name]
        if re.search(r"\{[A-Z_]+\}", w) and w == words[0]:
            die(2, "gate-run: row %s: the first word carries a placeholder" % row["id"])
        w2 = re.sub(r"\{([A-Z_]+)\}", sub, w)
        if "*" in w2:
            hits = sorted(h for h in glob.glob(os.path.join(ctx["ROOT"], w2)) if os.path.isdir(h))
            if not hits:
                die(2, "gate-run: row %s: %s matches no directory under the root" % (row["id"], w2))
            w2 = os.path.relpath(hits[0], ctx["ROOT"])
        out.append(w2)
    return out


def uses_story(row):
    return "{STORY}" in row["arm"]


def uses_stories(row):
    return "{STORIES" in row["arm"]


def script_cmd(argv):
    name = argv[0]
    path = os.path.join(SELF, name)
    if not os.path.isfile(path):
        die(2, "gate-run: %s is not beside gate-run.sh at %s" % (name, SELF))
    if name.endswith(".py"):
        return ["python3", path] + argv[1:]
    return ["bash", path] + argv[1:]


# ------------------------------------------------------------------ classification
def first_line(out, pats):
    lines = out.split("\n")
    for i, l in enumerate(lines, 1):
        if re.match(r"^\s*(%s)" % pats, l):
            return i, l.strip()
    for i, l in enumerate(lines, 1):
        if l.strip():
            return i, l.strip()
    return 1, ""


def classify_legacy(out, rc, row, token):
    """-> (res, reason, line, msg). SKIP only for a reason this row declared."""
    ok = r"ok|OK|PASS|WARN|warn"
    bad = r"FAIL|ERROR|REFUSED|OVER|BLOCK|VIOLATION"
    if rc == 0:
        reason = None
        if token in out:
            reason = "empty"
        elif "SKIPPED-PRE-ADOPTION" in out:
            reason = "pre-adoption"
        if reason:
            n, l = first_line(out, re.escape(token) + "|SKIPPED-PRE-ADOPTION")
            if reason in row["skip"]:
                return "SKIP", reason, n, l
            return "FAIL", "undeclared-skip:" + reason, n, l
        n, l = first_line(out, ok)
        return "PASS", None, n, l
    if ("rc%d" % rc) in row["skip"]:
        n, l = first_line(out, bad)
        return "SKIP", "rc%d" % rc, n, l
    n, l = first_line(out, bad)
    return "FAIL", "rc=%d" % rc, n, l


def parse_native(out, rc, row, declared, skips):
    """GATE-ARM lines -> {id: (res, examined, evidence, msg)}; an id no row declares is exit 2."""
    got = {}
    for l in out.split("\n"):
        if not l.startswith("GATE-ARM "):
            continue
        t = l.split(None, 3)
        if len(t) < 3:
            continue
        cid, res = t[1], t[2]
        rest = t[3] if len(t) > 3 else ""
        if cid not in declared:
            die(2, "gate-run: %s emitted GATE-ARM for undeclared id %r" % (row["id"], cid))
        m = re.match(r"^examined=(\d+)\s*(.*)$", rest)
        if res not in ("PASS", "FAIL", "SKIP"):
            got[cid] = ("FAIL", "-", "-", "no-verdict")
            continue
        if not m:
            got[cid] = ("FAIL", "-", "-", "no-count")
            continue
        ex, tail = m.group(1), m.group(2)
        ev, _, msg = tail.partition(" ")
        if res == "PASS" and int(ex) == 0:
            got[cid] = ("FAIL", ex, ev or "-", "examined-nothing")
        elif res == "SKIP":
            tok = ev[len("reason="):] if ev.startswith("reason=") else ""
            if tok and tok in skips.get(cid, []):
                got[cid] = ("SKIP", ex, ev, msg)
            else:
                got[cid] = ("FAIL", ex, ev or "-", "undeclared-skip:" + (tok or "none"))
        else:
            got[cid] = (res, ex, ev or "-", msg)
    for cid in declared:
        if cid not in got:
            got[cid] = ("FAIL", "-", "-", "arm-error rc=%d" % rc if rc != 0 else "no-verdict")
    if rc != 0 and not any(v[0] == "FAIL" for v in got.values()):
        for cid in got:
            got[cid] = ("FAIL", "-", "-", "arm-error rc=%d" % rc)
    return got


def eval_rule(root, row):
    path = row["arm"]
    p = path if os.path.isabs(path) else os.path.join(root, path)
    if not os.path.isfile(p):
        die(2, "gate-run: rule table %s not found" % path)
    n_examined, first_bad = 0, None
    for line in open(p, encoding="utf-8").read().split("\n"):
        if not line.strip() or line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) != 5 or f[0] != row["id"]:
            continue
        for fp in sorted(glob.glob(os.path.join(root, f[1]), recursive=True)):
            if not os.path.isfile(fp):
                continue
            n_examined += 1
            rel = os.path.relpath(fp, root)
            lines = open(fp, encoding="utf-8", errors="replace").read().split("\n")
            hit = next((i for i, l in enumerate(lines, 1) if re.search(f[3], l)), 0)
            if f[2] == "absent" and hit and not first_bad:
                first_bad = ("%s:%d" % (rel, hit), f[4])
            if f[2] == "present" and not hit and not first_bad:
                first_bad = ("%s:0" % rel, f[4])
    if n_examined == 0:
        return ("FAIL", "0", "-", "examined-nothing")
    if first_bad:
        return ("FAIL", str(n_examined), first_bad[0], first_bad[1])
    return ("PASS", str(n_examined), "-", "rule table held")


def pre_adoption(root, sprint, cache):
    """A row declaring skip=pre-adoption does not run when Check 28's validator says the sprint is
    below the spec-layer floor; the token is reported as the row's SKIP reason."""
    if "v" not in cache:
        rc, out = run(["bash", os.path.join(SELF, "validate-spec-adoption.sh"), "--verdict", sprint], cwd=root,
                      env={"AI_DLC_PROJECT_ROOT": root})
        m = next((l.strip() for l in out.split("\n") if "SKIPPED-PRE-ADOPTION" in l), "")
        cache["v"] = rc == 0 and bool(m)
        cache["line"] = m[:140]
    return cache["v"]


# ------------------------------------------------------------------ arms
class Ctx:
    pass


def arg_parse(argv, spec, multi=("story",)):
    o = {k: ([] if k in multi else None) for k in spec}
    i = 0
    while i < len(argv):
        a = argv[i]
        if not a.startswith("--") or a[2:] not in spec or i + 1 >= len(argv):
            die(2, "gate-run: unknown or valueless argument %r (see --help)" % a)
        k = a[2:]
        if k in multi:
            o[k].append(argv[i + 1])
        else:
            o[k] = argv[i + 1]
        i += 2
    return o


GATE_RUN_REL = "_bmad-output/gate-run"
WORKLIST_TMPL = "/<nonce>.worklist"


def gate_run_dir(root):
    """The per-run staging directory under the pipeline state directory."""
    return os.path.join(root, GATE_RUN_REL.replace("_bmad-output", os.environ.get("AI_DLC_STATE_DIR", "_bmad-output"), 1))


def state_dir(root):
    return os.path.join(root, os.environ.get("AI_DLC_STATE_DIR", "_bmad-output"))


def stories_for(root, sprint, given):
    if given:
        return [g if os.path.isabs(g) else os.path.join(root, g) for g in given]
    return sorted(glob.glob(os.path.join(root, "_bmad-output/planning-artifacts/s%s/stories/*.md" % sprint)))


def ext_checks(plan):
    return [(c["id"], c["entry"]) for c in plan.get("extension_checks", [])]


def cmd_arms(argv, root):
    o = arg_parse(argv, ["gate", "sprint", "step", "story", "base", "sha", "transcript", "transcript-dir", "series", "root", "worktree"])
    if o["root"]:
        root = os.path.abspath(o["root"])
    if not (o["sprint"] and re.fullmatch(r"[0-9]+", o["sprint"])):
        die(2, "gate-run: --sprint N is required")
    if not (o["step"] and re.fullmatch(r"[A-Za-z0-9_.-]+\.md", o["step"])):
        die(2, "gate-run: --step <step-file basename>.md is required")
    arms = load_arms(root, o["gate"])
    titles, token = map_titles(arms["skill_dir"])
    plan = slice_plan(root, arms["gate_type"])
    st = state_dir(root)
    now = utc_now()
    run_id = now.strftime("%Y%m%dT%H%M%S") + "-%d" % os.getpid()
    stage = os.path.join(gate_run_dir(root), run_id)
    os.makedirs(stage, exist_ok=True)
    ctx = {"STORIES": None, "ROOT": root, "SPRINT": o["sprint"], "BASE": o["base"], "SHA": o["sha"],
           "TRANSCRIPT": o["transcript"], "TRANSCRIPT_DIR": o["transcript-dir"],
           "SERIES": o["series"], "STATE": st, "WORKTREE": o["worktree"]}
    stories = stories_for(root, o["sprint"], o["story"])
    ctx["STORIES"] = [os.path.relpath(x, root) for x in stories]
    rows = arms["rows"]
    skips = {r["id"]: r["skip"] for r in rows}
    results = {}
    script_out = {}
    preado = {}

    def outfile(rid, suffix=""):
        return os.path.join(stage, re.sub(r"[^A-Za-z0-9_.-]", "_", rid) + suffix + ".out")

    def cite(path, n):
        return "%s:%d" % (os.path.relpath(path, root), n)

    # pass 1: validate every row's argv before running anything, so an unfilled placeholder is exit 2
    plans = {}
    for r in rows:
        if r["kind"] == "script" and r["arm"] != "@close":
            if "pre-adoption" in r["skip"] and not r["arm"].startswith("validate-spec-adoption.sh") and pre_adoption(root, o["sprint"], preado):
                plans[r["id"]] = None
            elif uses_story(r):
                plans[r["id"]] = [build_argv(r, ctx, s) for s in stories]
            elif uses_stories(r) and not stories:
                plans[r["id"]] = []
            else:
                plans[r["id"]] = [build_argv(r, ctx)]
    for r in rows:
        if r["kind"] == "script" and r["arm"] != "@close" and plans[r["id"]] is not None:
            for a in plans[r["id"]]:
                script_cmd(a)
    # pass 2: run
    for r in rows:
        rid = r["id"]
        if r["kind"] == "judgment":
            results[rid] = ("PENDING", "-", "-", "adjudicator")
        elif r["kind"] == "lead":
            results[rid] = ("PENDING", "-", "-", "lead")
        elif r["kind"] == "script" and r["arm"] == "@close":
            results[rid] = ("PENDING", "-", "-", "runs at close")
        elif r["kind"] == "rule":
            results[rid] = eval_rule(root, r)
        elif r["kind"] == "script" and "pre-adoption" in r["skip"] and not r["arm"].startswith("validate-spec-adoption.sh") and pre_adoption(root, o["sprint"], preado):
            results[rid] = ("SKIP", "-", "reason=pre-adoption", preado["line"])
        elif r["kind"] == "script":
            if (uses_story(r) or uses_stories(r)) and not stories:
                results[rid] = ("SKIP", "0", "reason=no-stories", "no story files")
                if "no-stories" not in r["skip"]:
                    results[rid] = ("FAIL", "0", "-", "examined-nothing")
                continue
            sub = []
            for k, a in enumerate(plans[rid]):
                rc, out = run(script_cmd(a), cwd=root, env={"AI_DLC_PROJECT_ROOT": root})
                of = outfile(rid, "" if len(plans[rid]) == 1 else ".%d" % k)
                open(of, "w").write(out)
                if r["count"] == "native":
                    script_out[rid] = (rc, out, of)
                    sub.append(("native", rc, out, of))
                else:
                    res, reason, n, msg = classify_legacy(out, rc, r, token)
                    ev = "reason=" + reason if res == "SKIP" else cite(of, n)
                    m = msg[:140] if res != "FAIL" or not reason else ("%s %s" % (reason, msg))[:160]
                    sub.append((res, "-", ev, m))
            if r["count"] == "native":
                rc, out, of = script_out[rid]
                declared = [rid] + [x["id"] for x in rows if x["kind"] == "multi" and x["arm"] == "@" + rid]
                got = parse_native(out, rc, r, declared, skips)
                for cid, v in got.items():
                    ev = v[2]
                    if v[0] == "FAIL" and ev == "-":
                        ev = cite(of, 1)
                    results[cid] = (v[0], v[1], ev, v[3])
            else:
                fails = [s for s in sub if s[0] == "FAIL"]
                if fails:
                    results[rid] = fails[0]
                elif all(s[0] == "SKIP" for s in sub):
                    results[rid] = sub[0]
                else:
                    results[rid] = ("PASS", str(len(sub)) if uses_story(r) else "-", sub[0][2], sub[0][3])
    for r in rows:
        if r["kind"] == "multi" and r["id"] not in results:
            results[r["id"]] = ("FAIL", "-", "-", "no-verdict")
    # extension checks: judgment rows, never a script row
    ext = ext_checks(plan)
    for cid, entry in ext:
        results.setdefault(cid, ("PENDING", "-", "-", "lead (extension %s)" % entry))
    order = [r["id"] for r in rows] + [c for c, _ in ext if c not in {r["id"] for r in rows}]
    kind_of = {r["id"]: r["kind"] for r in rows}
    for c, _ in ext:
        kind_of.setdefault(c, "lead")
    tally = {"PASS": 0, "FAIL": 0, "SKIP": 0, "PENDING": 0}
    for cid in order:
        res, ex, ev, msg = results[cid]
        tally[res] += 1
        print("GATE-RESULT %s %s examined=%s evidence=%s %s" % (cid, res, ex, ev, msg))
    if tally["FAIL"]:
        for cid in order:
            if results[cid][0] == "FAIL":
                print("REMEDY %s take Check %s through gate-validation.md Gate Failure now, while no adjudicator runs (%s); then re-run gate-run.sh arms" % (cid, cid, results[cid][3]))
        print("GATE-RUN %s arms FAIL nonce=- pass=%d fail=%d skip=%d pending=%d" % (o["gate"], tally["PASS"], tally["FAIL"], tally["SKIP"], tally["PENDING"]))
        return 1
    judg = [c for c in order if kind_of[c] == "judgment"]
    # the worklist is the escalated set: the ONE derivation, unioned with extension checks
    rc, out = run(["bash", os.path.join(SELF, "validate-gate-adjudication.sh"), "--expected", arms["gate_type"]], cwd=root,
                  env={"AI_DLC_PROJECT_ROOT": root})
    if rc != 0:
        die(2, "gate-run: validate-gate-adjudication.sh --expected %s exited %d: %s" % (arms["gate_type"], rc, out.strip()[:200]))
    expected = [l.strip() for l in out.split("\n") if l.strip()]
    want = set(expected)
    have = set(judg)
    if o["gate"] == arms["gate_type"]:
        bad = want ^ have
    else:
        bad = have - want
    if bad:
        die(2, "gate-run: the .arms judgment rows disagree with the derived escalated set (--expected %s) in %s: %s" % (
            arms["gate_type"], ",".join(sorted(bad)), arms["path"]))
    nonce = "%s-%s" % (arms["gate_type"], now.strftime("%Y%m%dT%H%M%SZ"))
    gck = os.path.join(SELF, "gate-checkpoint.sh")

    def gck_run(*a):
        rc, out = run(["bash", gck, "--root", root, "--nonce", nonce] + list(a), cwd=root)
        if rc != 0:
            die(2, "gate-run: gate-checkpoint.sh %s failed: %s" % (" ".join(a), out.strip()[:200]))
    gck_run("open")
    for cid in order:
        res, ex, ev, msg = results[cid]
        if kind_of[cid] in ("script", "rule", "multi") and rows_by(rows, cid) != "@close":
            gck_run("record", cid, res, ev)
        elif kind_of[cid] == "judgment":
            gck_run("record", cid, "PENDING")
    wl = "none"
    if judg:
        d = os.path.join(st, "gate-adjudication")
        os.makedirs(d, exist_ok=True)
        wl = d + WORKLIST_TMPL.replace("<nonce>", nonce)
        spans = {}
        for rd in plan.get("reads", []):
            for c in rd.get("checks", []):
                spans[c] = "%d:%d" % (rd["offset"], rd["limit"])
        ent = dict(ext)
        with open(wl, "w") as fh:
            for c in judg:
                fh.write("%s\t%s\t%s\n" % (c, spans.get(c, "-"), ent.get(c, "-")))
    meta = {"gate": o["gate"], "gate_type": arms["gate_type"], "sprint": o["sprint"], "step": o["step"],
            "nonce": nonce, "ts": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "judgment": judg, "stories": stories,
            "ext": ext, "results": {c: list(results[c]) for c in order}, "order": order,
            "kinds": kind_of, "arms": arms["path"]}
    json.dump(meta, open(os.path.join(gate_run_dir(root), nonce + ".json"), "w"), indent=1)
    final = "ADJUDICATE" if judg else "PASS"
    if judg:
        print("ADJUDICATE %s nonce=%s" % (wl, nonce))
    else:
        print("ADJUDICATE none")
    print("GATE-RUN %s arms %s nonce=%s pass=%d fail=0 skip=%d pending=%d" % (o["gate"], final, nonce, tally["PASS"], tally["SKIP"], tally["PENDING"]))
    return 0


def rows_by(rows, cid):
    for r in rows:
        if r["id"] == cid:
            return r["arm"]
    return None


# ------------------------------------------------------------------ close
def snapshot_apply(root, snapshot, gate_label, ts, step, nonce):
    """The snapshot-update.sh `--gate-passed` op: one atomic call per nonce. It is not idempotent on its
    Recent Activity line, so a retry skips it when the snapshot already carries `(nonce <n>)`, the text
    the op itself wrote. Returns (rc, message)."""
    su = os.path.join(SELF, "snapshot-update.sh")
    if not os.path.isfile(snapshot):
        return 1, "no pipeline snapshot at %s" % snapshot
    cur = open(snapshot, encoding="utf-8", errors="replace").read()
    if ("(nonce %s)" % nonce) in cur:
        return 0, "already written by this nonce's earlier close"
    rc, out = run(["bash", su, "--snapshot", snapshot, "--gate-passed", gate_label, nonce, ts, step], cwd=root)
    msg = out.strip()[:300]
    if rc != 0 and "REFUSED by the budget" in out:
        msg += " -- trim the snapshot with snapshot-update.sh --move-to-history, then re-run close"
    return rc, msg


def cmd_close(argv, root):
    o = arg_parse(argv, ["gate", "nonce", "sprint", "step", "verdict", "transcript", "transcript-dir", "root"], multi=())
    if o["root"]:
        root = os.path.abspath(o["root"])
    for k in ("gate", "nonce", "sprint", "step"):
        if not o[k]:
            die(2, "gate-run: close needs --%s" % k)
    nonce = o["nonce"]
    st = state_dir(root)
    mp = os.path.join(gate_run_dir(root), nonce + ".json")
    if not os.path.isfile(mp):
        print("gate-run: no arms record for nonce %s (%s): run `gate-run.sh arms` first" % (nonce, mp), file=sys.stderr)
        return 1
    meta = json.load(open(mp))
    if meta["gate"] != o["gate"] or meta["sprint"] != o["sprint"] or meta["step"] != o["step"]:
        print("gate-run: close flags (gate %s, sprint %s, step %s) differ from the arms record (gate %s, sprint %s, step %s)" % (
            o["gate"], o["sprint"], o["step"], meta["gate"], meta["sprint"], meta["step"]), file=sys.stderr)
        return 1
    arms = load_arms(root, o["gate"])
    titles, _ = map_titles(arms["skill_dir"])
    gtype = meta["gate_type"]
    order, kinds = meta["order"], meta["kinds"]
    results = {k: tuple(v) for k, v in meta["results"].items()}
    gck = os.path.join(SELF, "gate-checkpoint.sh")
    refused = []

    # ledger rows the lead recorded (13, H1)
    rc, led = run(["bash", gck, "--root", root, "--nonce", nonce, "list"], cwd=root)
    ledger = {}
    for l in led.split("\n"):
        f = l.split("\t")
        if len(f) >= 2:
            ledger[f[0]] = f[1]
    lead_ids = [r["id"] for r in arms["rows"] if r["kind"] == "lead" and r["id"] not in ("12", "14", "15", "failure")]
    lead_ids += [c for c, _ in meta["ext"]]
    for c in lead_ids:
        if ledger.get(c) not in ("PASS", "SKIP"):
            refused.append((c, "the lead has not recorded %s PASS or SKIP at this nonce" % c))

    # Check 26: the worklist equals the derived set, then the verdict is adopted fail-closed
    wl = os.path.join(st, "gate-adjudication") + WORKLIST_TMPL.replace("<nonce>", nonce)
    verdict = o["verdict"] or os.path.join(st, "gate-adjudication", nonce + ".verdict.json")
    judg = meta["judgment"]
    if judg:
        have = [l.split("\t")[0] for l in open(wl).read().split("\n") if l.strip()] if os.path.isfile(wl) else None
        if have is None:
            refused.append(("26", "the worklist %s is missing" % wl))
        else:
            rc, out = run(["bash", os.path.join(SELF, "validate-gate-adjudication.sh"), "--expected", gtype], cwd=root,
                          env={"AI_DLC_PROJECT_ROOT": root})
            want = set(l.strip() for l in out.split("\n") if l.strip())
            if rc != 0 or (o["gate"] == gtype and set(have) != want) or not set(have) <= want:
                refused.append(("26", "the worklist ids differ from the derived escalated set"))
    if not os.path.isfile(verdict) and judg:
        refused.append(("26", "no verdict at %s" % verdict))
    vdoc = None
    if judg and os.path.isfile(verdict):
        a = ["bash", os.path.join(SELF, "validate-gate-adjudication.sh"), gtype, verdict]
        if o["transcript"]:
            a += ["--transcript", o["transcript"]]
        if o["transcript-dir"]:
            a += ["--transcript-dir", o["transcript-dir"]]
        rc, out = run(a, cwd=root, env={"AI_DLC_PROJECT_ROOT": root})
        n, l = first_line(out, r"FAIL|BLOCK|REFUSED|VALIDATE-GATE-ADJUDICATION")
        if rc != 0:
            refused.append(("26", "validate-gate-adjudication.sh exited %d: %s" % (rc, l)))
        else:
            try:
                vdoc = json.load(open(verdict))
            except ValueError:
                refused.append(("26", "the verdict is not JSON"))
    if refused:
        for c, why in refused:
            print("GATE-RESULT %s FAIL examined=- evidence=- %s" % (c, why))
            print("REMEDY %s %s; fix it and re-run gate-run.sh close" % (c, why))
        print("GATE-RUN %s close FAIL nonce=%s pass=0 fail=%d skip=0 pending=0" % (o["gate"], nonce, len(refused)))
        return 1
    vrows = {v["check_id"]: v for v in (vdoc or {}).get("verdicts", [])}
    for c in judg:
        v = vrows.get(c)
        if v:
            fin = "PASS" if v.get("verdict") == "PASS" else "FAIL" if v.get("verdict") == "FAIL" else "PASS"
            results[c] = (fin, "-", "verdict.json", "%s: %s" % (v.get("verdict"), str(v.get("evidence", ""))[:300]))
    for c, _ in meta["ext"]:
        results[c] = (ledger.get(c, "PASS"), "-", "ledger", "recorded by the lead")
    # snapshot op FIRST: a refusal changes nothing else
    snap = os.path.join(root, "_bmad-output/pipeline-snapshot.md")
    label = o["gate"]
    ts = meta["ts"]
    rc, msg = snapshot_apply(root, snap, label, ts, o["step"], nonce)
    if rc != 0:
        print("GATE-RESULT 14 FAIL examined=- evidence=- snapshot update refused (rc=%d): %s" % (rc, msg.replace("\n", " ")))
        print("REMEDY 14 repair the snapshot refusal (%s), then re-run gate-run.sh close (nothing else was written)" % msg.replace("\n", " "))
        print("GATE-RUN %s close FAIL nonce=%s pass=0 fail=1 skip=0 pending=0" % (o["gate"], nonce))
        return 1
    # budget evidence for Check 14
    brc, bout = run(["bash", os.path.join(SELF, "verdict.sh"), "validate-artifact-budget", "--only", "pipeline-snapshot.md", "--root", root], cwd=root)
    bline = " / ".join(re.sub(r"^\s*\d+:", "", l).strip() for l in bout.split("\n") if l.strip())[:300]
    if brc != 0:
        print("GATE-RESULT 14 FAIL examined=- evidence=- snapshot over budget: %s" % bline)
        print("REMEDY 14 trim the snapshot (Check 14 budget), then re-run gate-run.sh close")
        print("GATE-RUN %s close FAIL nonce=%s pass=0 fail=1 skip=0 pending=0" % (o["gate"], nonce))
        return 1
    gl = os.path.join(root, "_bmad-output/implementation-artifacts/gate-log.md")
    gm = os.path.join(root, "_bmad-output/implementation-artifacts/gate-metrics.jsonl")
    os.makedirs(os.path.dirname(gl), exist_ok=True)
    existing = open(gl, encoding="utf-8").read() if os.path.isfile(gl) else "# Gate Log\n"
    already = ("nonce: %s" % nonce) in existing
    if not already:
        entry = compose_entry(root, meta, o, results, order, titles, bline, ledger)
        cand = existing.rstrip("\n") + "\n\n" + entry
        tmp = gl + ".candidate"
        open(tmp, "w").write(cand)
        crc, cout = run(["bash", os.path.join(SELF, "validate-artifact-budget.sh"), "--root", root, "--check-evidence", "--gate-log", tmp], cwd=root)
        os.remove(tmp)
        if crc != 0:
            n, l = first_line(cout, r"FAIL|ERROR|OVER")
            print("GATE-RESULT 15 FAIL examined=- evidence=- check-evidence refused the candidate entry: %s" % l)
            print("REMEDY 15 the Check 14 row must carry the budget verdict line; re-run gate-run.sh close")
            print("GATE-RUN %s close FAIL nonce=%s pass=0 fail=1 skip=0 pending=0" % (o["gate"], nonce))
            return 1
        write_metrics(root, meta, results, order, kinds, gm, arms, ledger, bool(judg))
        open(gl, "w").write(cand)
    for c in ("12", "14", "15", "26"):
        if c in kinds or c in ("12", "14", "15"):
            run(["bash", gck, "--root", root, "--nonce", nonce, "record", c, "PASS"], cwd=root)
    for c in judg:
        run(["bash", gck, "--root", root, "--nonce", nonce, "record", c, results[c][0]], cwd=root)
    rc, out = run(["bash", gck, "--root", root, "--nonce", nonce, "close"], cwd=root)
    if rc != 0:
        die(2, "gate-run: gate-checkpoint.sh close failed: %s" % out.strip()[:200])
    tally = {"PASS": 0, "FAIL": 0, "SKIP": 0, "PENDING": 0}
    for c in order:
        r = results[c]
        res = "PASS" if (r[0] == "PENDING" and c in ("12", "14", "15", "26")) else r[0]
        if r[0] == "PENDING" and c in ledger:
            res = ledger[c]
        elif r[0] == "PENDING" and kinds.get(c) == "lead":
            continue
        tally[res if res in tally else "PASS"] += 1
        print("GATE-RESULT %s %s examined=%s evidence=%s %s" % (c, res, r[1], r[2], r[3]))
    print("GATE-RUN %s close PASS nonce=%s pass=%d fail=0 skip=%d pending=0" % (o["gate"], nonce, tally["PASS"], tally["SKIP"]))
    return 0


def story_status(path):
    t = open(path, encoding="utf-8", errors="replace").read()
    m = re.match(r"^---\n(.*?)\n---", t, re.S)
    if m:
        mm = re.search(r"^status:\s*(\S+)", m.group(1), re.M)
        if mm:
            return mm.group(1).strip("\"'")
    mm = re.search(r"^\*\*Status:\*\*\s*(\S+)", t, re.M)
    return mm.group(1) if mm else "absent"


def compose_entry(root, meta, o, results, order, titles, bline, ledger):
    sprint, gate, ts, nonce = meta["sprint"], meta["gate"], meta["ts"], meta["nonce"]
    sv = "SKIP"
    r25 = results.get("25")
    if r25 and r25[0] == "PASS":
        m = re.search(r"\d+", r25[3] or "")
        sv = m.group(0) if m else "SKIP"
    ss = ["%s: %s" % (os.path.basename(s)[:-3], story_status(s)) for s in meta["stories"] if os.path.isfile(s)]
    vi = "unknown"
    try:
        sn = open(os.path.join(root, "_bmad-output/pipeline-snapshot.md"), encoding="utf-8", errors="replace").read()
        mv = re.search(r"^[-*]\s*\**validation_intensity:?\**:?\s*(\S+)", sn, re.M)
        vi = mv.group(1) if mv else vi
    except OSError:
        pass
    lines = ["## Gate Log: Sprint %s — %s gate (%s)" % (sprint, gate, meta["step"][:-3]), "",
             "Timestamp: %s" % ts,
             "Gate: %s | nonce: %s" % (gate, nonce),
             "validation_intensity: %s" % vi,
             "steering_violations: %s" % sv,
             "hard_block_fail: %s" % ("true" if any(results[c][0] == "FAIL" for c in order) else "false")]
    lines += ["story_status:"] + ["  %s" % s for s in ss] if ss else ["story_status: none"]
    lines += ["", "| Check | Result | Evidence |", "|---|---|---|"]
    word = {"PASS": "PASSED", "FAIL": "FAILED", "SKIP": "SKIPPED", "PENDING": "PENDING"}
    ext = dict(meta["ext"])
    last = None
    for c in order:
        res, ex, ev, msg = results[c]
        if c == "14":
            last = c
            continue
        if c in ext:
            label = "[ext:%s] %s" % (os.path.basename(ext[c]).rsplit(".", 1)[0], c)
        else:
            label = "[core] %s — %s" % (c, titles.get(c, c))
        if c == "14":
            res, ev = "PASS", "snapshot updated through snapshot-update.sh; verdict.sh validate-artifact-budget --only pipeline-snapshot.md: %s" % bline
        elif c == "12":
            res, ev = "PASS", "this entry, nonce %s" % nonce
        elif c == "15":
            res, ev = "PASS", "validate-artifact-budget.sh --check-evidence passed on this entry before it was appended"
        elif c == "26":
            res, ev = "PASS", "validate-gate-adjudication.sh %s %s.verdict.json: exit 0" % (meta["gate_type"], nonce)
        elif c == "failure" and c not in ledger:
            res, ev = "SKIP", "no Gate Failure was recorded at this nonce"
        elif c in ("13", "H1", "failure") or c in ext:
            res = ledger.get(c, "PASS")
            ev = "recorded by the lead at this nonce"
        else:
            ev = ("%s %s %s" % (ev, msg, "examined=" + ex if ex != "-" else "")).strip()
        lines.append(mkrow(label, res, ev))
    if True:
        lines.append("")
        lines.append(mkrow("[core] 14 — %s" % titles.get("14", "Update pipeline snapshot"), "PASS",
                           "snapshot updated through snapshot-update.sh; verdict.sh validate-artifact-budget --only pipeline-snapshot.md: %s" % bline))
    return "\n".join(lines) + "\n"


def mkrow(label, res, ev):
    word = {"PASS": "PASSED", "FAIL": "FAILED", "SKIP": "SKIPPED", "PENDING": "PENDING"}
    tag = ""
    if res == "SKIP" and "reason=" in ev:
        tag = " (%s)" % ev.split("reason=")[1].split()[0]
    return "| %s | %s | %s |" % (label, word.get(res, res) + tag, ev.replace("|", "/"))


def write_metrics(root, meta, results, order, kinds, gm, arms, ledger, validated):
    existing = open(gm).read() if os.path.isfile(gm) else ""
    for l in existing.split("\n"):
        if '"ts":"%s"' % meta["ts"] in l and '"gate":"%s"' % meta["gate_type"] in l and '"sprint":%s,' % meta["sprint"] in l:
            return
    gv = os.path.join(arms["skill_dir"], "steps/gate-validation.md")
    spans = {}
    if os.path.isfile(gv):
        lines = open(gv, encoding="utf-8").read().split("\n")
        idx = [(i, m.group(1)) for i, l in enumerate(lines) for m in [re.match(r"^<!-- CHECK_LOADED: (\S+) -->\s*$", l)] if m]
        for k, (i, c) in enumerate(idx):
            j = idx[k + 1][0] if k + 1 < len(idx) else len(lines)
            spans[c] = len("\n".join(lines[i:j])) // 4
    rc, sha = run(["git", "-C", root, "rev-parse", "HEAD"])
    sha = sha.strip() if rc == 0 else "unknown"
    ext = dict(meta["ext"])
    out = []
    titles, _ = map_titles(arms["skill_dir"])
    for c in order:
        if c in ("12", "13", "14", "15"):
            continue
        res = results[c][0]
        if c == "26" and res == "PENDING":
            res = "PASS" if validated else "SKIP"
        elif c == "H1" and res == "PENDING":
            res = ledger["H1"]
        elif c == "failure" and res == "PENDING":
            continue
        v = {"PASS": "PASS", "FAIL": "FAIL", "SKIP": "NA"}.get(res, "DEFERRED")
        if c in ext:
            cat, tok = "extension:%s" % os.path.basename(ext[c]).rsplit(".", 1)[0], 1
            try:
                tok = max(1, os.path.getsize(os.path.join(arms["skill_dir"], ext[c])) // 4)
            except OSError:
                pass
        else:
            cat, tok = "core", max(1, spans.get(c, 1))
        out.append(json.dumps({"v": 1, "sprint": int(meta["sprint"]), "gate": meta["gate_type"], "phase": meta["step"][:-3],
                               "ts": meta["ts"], "sha": sha, "catalog": cat, "check": c,
                               "title": titles.get(c, c)[:60], "verdict": v, "defect_class": None,
                               "evidence": results[c][2], "tok_slice": tok}, separators=(",", ":")))
    with open(gm, "a") as fh:
        fh.write("\n".join(out) + "\n")


# ------------------------------------------------------------------ self-probe
def self_probe():
    row = {"id": "x", "skip": ["empty"], "arm": "", "count": "legacy"}
    assert classify_legacy("ok fine\n", 0, row, DEFAULT_TOKEN)[0] == "PASS"
    assert classify_legacy("EXAMINED NOTHING: none\n", 0, row, DEFAULT_TOKEN)[:2] == ("SKIP", "empty")
    row2 = dict(row, skip=[])
    assert classify_legacy("EXAMINED NOTHING: none\n", 0, row2, DEFAULT_TOKEN)[0] == "FAIL"
    assert classify_legacy("FAIL x\n", 1, row, DEFAULT_TOKEN)[0] == "FAIL"
    g = parse_native("GATE-ARM x PASS examined=0 a:1 m\n", 0, row, ["x"], {"x": []})
    assert g["x"][0] == "FAIL" and g["x"][3] == "examined-nothing"
    g = parse_native("GATE-ARM x PASS a:1 m\n", 0, row, ["x"], {"x": []})
    assert g["x"][3] == "no-count"
    g = parse_native("", 3, row, ["x"], {"x": []})
    assert g["x"][3] == "arm-error rc=3"
    g = parse_native("GATE-ARM x PASS examined=2 a:1 m\n", 0, row, ["x"], {"x": []})
    assert g["x"][0] == "PASS"
    try:
        parse_native("GATE-ARM y PASS examined=2 a:1 m\n", 0, row, ["x"], {})
        raise AssertionError("undeclared id accepted")
    except Exit as e:
        assert e.code == 2
    try:
        build_argv({"id": "x", "arm": "foo.sh {SPRINT}"}, {"SPRINT": None})
        raise AssertionError("unfilled placeholder accepted")
    except Exit as e:
        assert e.code == 2
    try:
        build_argv({"id": "x", "arm": "../foo.sh"}, {})
        raise AssertionError("slash first word accepted")
    except Exit as e:
        assert e.code == 2
    print("gate-run SELF-PROBE PASS: refuses examined-nothing, no-count, arm-error, undeclared id, unfilled placeholder, path-bearing first word; classifies declared SKIP")
    return 0


def main(argv):
    root = os.environ.get("GR_ROOT") or os.getcwd()
    if not argv:
        print("usage: gate-run.sh arms|close ... | --help | --self-probe", file=sys.stderr)
        return 2
    try:
        if argv[0] == "--self-probe":
            return self_probe()
        if argv[0] == "arms":
            return cmd_arms(argv[1:], root)
        if argv[0] == "close":
            return cmd_close(argv[1:], root)
        die(2, "gate-run: unknown command %r" % argv[0])
    except Exit as e:
        if e.msg:
            print(e.msg, file=sys.stderr)
        return e.code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
