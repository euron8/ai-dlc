"""BL-819 item 2(b): what the lead's `other` class is made of, per sub-class, with extract.py's classes left unchanged.

usage: EXTRACT_WIN_END=<window> python3 -I lead_other_split.py <SCRATCH_OUT> <OUT> <sprint> [<sprint> ...]
       python3 -I lead_other_split.py --self-test

extract.py is run once more, unchanged except for one injected subclass of its Classer (inserted at an anchor that must
occur exactly once, as lead_class_denied.py does), writing its usual files into <SCRATCH_OUT> plus other.jsonl: one
`call` row per usage-bearing lead message.id that extract.py classes `other` (the unit classes.jsonl counts in
`calls`), with its tokens and its fate as lead_class_denied.py defines it (DENIED: every tool_use refused by a hook,
tool_result opening "PreToolUse:"; ERRORED: every tool_use is_error, one not a hook refusal; TEXT: no tool_use; RAN:
otherwise), and one `time` row per interval key extract.py charges to `other` (a message.id, or the
message-less ("cls", "other") key), with its active and gap seconds. Each row carries the message's tool_use blocks,
each as [name, programs, targets, sibling, later, write-shape]: programs are extract.py's own invoked() over the shell
text the block runs (Bash's command, or a context-mode execute call's shell code); targets are extract.py's own
norm_paths(), sorted, over _los_target_text(): that shell text, a file tool's path field alone (never the edited or
written text), Grep's path, Glob's path and pattern, or any other tool's whole input; sibling is recorded but is no rule (see path_family()); later is
whether an Edit/Write path appears in a LATER Agent/Task prompt of the unit (extract.py's Write rule); write-shape is
a redirect onto a file, `sed -i` or `tee` in that shell text. <OUT> is the reference extraction at the same window
(extract.py, analyze.py, `roll.py --classes > classes.txt`). Read-only on the transcripts; writes only <SCRATCH_OUT>.
Stdlib only.

Target family of one path, path_family(), top-down: procedure (PROCEDURE: the lead's skill, roles, agents, hooks,
rules, scripts/ai-dlc, settings), delegate by task-output (the harness tmp `tasks/` output of a background call),
state by gate-record (gate-transition, gate-adjudication, gate-log, gate-metrics), delegate by sprint-dir (an
`_bmad-output/.../sNNN/` artifact), state (any other _bmad-output path), project (anything else). A block's family is
the one every target shares, `mixed` when they differ, `none` with no target (/dev/null and its kin dropped).

The reading of one `other` call, reading(), top-down: did-nothing (every tool_use refused by a hook or errored);
text; wait-poll; a ctx_execute call with no shell code (python, node: no write-shape reading exists) is open; one that
ran shell programs takes extract.py's own Bash precedence over them (snapshot, then
gate-run by extract.py's GATE_RUN_RE, read from its source), then wait-poll; else, unless its first program is a shell
read (bash_sub()'s shell-read or shell-builtin), it is open; a reading sub-class (READING_SUBS)
with no write shape and no non-read program (nonread(): WRITE, TEST, git, gh, sleep or a script) is merge when its block's family is delegate, procedure when it is procedure, else open; an Edit
whose every target is brief-shaped and named by a later prompt is dispatch; everything else is open. merge, gate-run,
snapshot, dispatch and wait-poll name the extract.py class the call's work belongs to; procedure and open are not
decided. Every hit set is printed (hit_sets()), because conservation cannot see a row in the wrong bucket.

A message's sub-class is decided by its FIRST tool_use block, by sub_of() below; a message with no tool_use is `text`,
and the message-less interval key is `no-message`. The rules, top-down:
  Bash: the first invoked program not in SKIP (shell keywords and builtins that do no work of their own) decides:
    wait-poll    wait-for-deliverable.sh
    sleep        sleep
    git          git, gh
    script       any other program whose basename ends .sh or .py (a project or ai-dlc script)
    inline-interp a program word that opens with "-" (extract.py's invoked() drops python/python3, so
                 `python3 -c ...` and `python3 - <<EOF` leave "-c" or "-")
    shell-read   READ (cat, grep, sed, awk, ls, wc, find, jq, diff and the like)
    shell-write  WRITE (mkdir, cp, mv, rm, touch, chmod, ln, tee)
    test-build   TEST (pytest, npm, npx, uv, make, node and the like)
    shell-builtin no program left after SKIP
    bash-other   anything else (enumerated by program in the output)
  ctx-exec     context-mode ctx_execute, ctx_execute_file, ctx_batch_execute
  ctx-search   context-mode ctx_search, ctx_index, ctx_fetch_and_index
  mcp-other    any other mcp__ tool
  read         Read, Grep, Glob (extract.py gave them neither merge nor step-reread)
  edit         Edit, Write, MultiEdit, NotebookEdit
  harness      HARNESS (ToolSearch, Skill, task and plan tools)
  operator     AskUserQuestion, PushNotification
  tool-other   anything else (enumerated by tool name in the output)

Controls (each must read MATCH):
  C1 the scratch classes.jsonl is byte-equal to <OUT>/classes.jsonl (the injection changed no class).
  C2 conservation per (lead unit, step): the call rows sum to classes.jsonl `other` calls, and the time rows to its
     active and gap seconds (|difference| < 1e-6 s).
  C3 the fate column: `other` calls whose fate is RAN or TEXT, by first tool, per story, equal lead_class_denied.py's
     committed lines in out/lead_class_denied.s<sprint>.txt, for every sprint asked that a committed file carries.
  C4 an impossible program name counts 0 beside `git` above 0.
  C5 pipeline-bucket `other` calls and active seconds per (sprint, step) equal lead_class_value.cells(), the population
     roll.classes() renders.
  C6 for BL812_STEPS, the lead classes summed per story equal out/outcome_row.s322-complete.txt's lead calls and lead $
     cells (roll.seat_sum over steps.csv, a different code path).
C2 and C5 count rows whatever their bucket, so a dropped sub-class or reading rule is caught only by --self-test, which
seeds every sub-class, family and reading, and the write-shape regex in both directions.
"""
import collections, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXTRACT = os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts", "extract.py")
sys.path.insert(0, os.path.join(HERE, "..", "..", "pipeline-efficiency-s317-s320", "scripts"))
sys.path.insert(0, HERE)
import roll  # noqa: E402  (guarded main)

ANCHOR = "GATE_EV = []   # (sprint, \"open\" | \"closed\" | \"unclosed\" | \"left\"), lead scans only\n"
TARGET_SRC = r'''
_LOS_FILE_TOOLS = ("Edit", "MultiEdit", "Write", "NotebookEdit", "Read")

def _los_target_text(name, inp, sh):
    """The text a block's targets are read from: the shell text it runs; a file tool's path field alone (never the
    edited or written text); Grep's path; Glob's path and pattern; any other tool's whole input."""
    if sh: return sh
    if name in _LOS_FILE_TOOLS: return str(inp.get("file_path") or inp.get("notebook_path") or "")
    if name == "Grep": return str(inp.get("path") or "")
    if name == "Glob": return " ".join(str(inp.get(k) or "") for k in ("path", "pattern"))
    return " ".join(str(v) for v in inp.values())
'''
exec(TARGET_SRC)
INJECT = TARGET_SRC + r'''
import collections

_LOS = open(os.path.join(OUT, "other.jsonl"), "w")

_LOSBase = Classer

_LOS_WRITE = re.compile(r"(?<![0-9&<>])>{1,2}(?!&)[ \t]*(?!/dev/null)[^\s|;&<>]|\bsed[ \t]+(-[A-Za-z]+[ \t]+)*-i|\btee\b")

def _los_shell(name, inp):
    """The shell text a tool_use runs: Bash's command, or a context-mode execute call's shell code."""
    if name == "Bash": return str(inp.get("command") or "")
    if name.startswith("mcp__") and "context-mode" in name and name.rsplit("__", 1)[-1] in ("ctx_execute", "ctx_execute_file", "ctx_batch_execute"):
        if str(inp.get("language") or "shell") in ("shell", "bash", "sh", "zsh"):
            if inp.get("code"): return str(inp.get("code"))
            cs = inp.get("commands")
            if isinstance(cs, list):
                return "\n".join(str(x.get("command") if isinstance(x, dict) else x) for x in cs)
    return ""

def _los_text(c):
    x = c.get("content")
    if isinstance(x, list):
        x = "".join(str(e.get("text", "")) for e in x if isinstance(e, dict))
    return str(x or "")

class _LOSClasser(_LOSBase):
    def __init__(self):
        _LOSBase.__init__(self); self._tools = collections.defaultdict(list); self._seen = set(); self._ids = collections.defaultdict(list); self._res = {}
        self._pdirs = set(); self._np = 0; self._edits = []
    def record(self, r, typ):
        m = r.get("message") or {}
        cwd = r.get("cwd") or ""
        if typ == "assistant" and m.get("id"):
            for c in m.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("id") not in self._seen:
                    self._seen.add(c.get("id"))
                    inp = c.get("input") if isinstance(c.get("input"), dict) else {}
                    sh = _los_shell(c.get("name") or "", inp)
                    progs = invoked(sh) if sh else []
                    paths = sorted(norm_paths(_los_target_text(c.get("name") or "", inp, sh), cwd))
                    sib = any(p in self._pdirs or os.path.dirname(p) in self._pdirs for p in paths)
                    wshape = bool(sh) and bool(_LOS_WRITE.search(strip_heredocs(sh)))
                    blk = [c.get("name"), progs, paths, sib, None, wshape]
                    if c.get("name") in ("Edit", "MultiEdit", "Write", "NotebookEdit"):
                        fp = str(inp.get("file_path") or inp.get("notebook_path") or "")
                        rel = fp[len(cwd) + 1:] if cwd and fp.startswith(cwd + "/") else fp
                        self._edits.append((blk, [x for x in {fp, rel} if x and (x == fp or "/" in x)], self.plen))
                    self._tools[m["id"]].append(blk); self._ids[m["id"]].append(c.get("id"))
        if typ == "user" and isinstance(m.get("content"), list):
            for c in m["content"]:
                if isinstance(c, dict) and c.get("type") == "tool_result":
                    self._res[c.get("tool_use_id")] = ("deny" if _los_text(c).lstrip().startswith("PreToolUse:") else "err") if c.get("is_error") else "ok"
        _LOSBase.record(self, r, typ)
        if len(self.ptoks) != self._np:
            self._np = len(self.ptoks); self._pdirs = {os.path.dirname(t) for t in self.ptoks} - {""}
    def _fate(self, mid):
        ids = self._ids.get(mid, [])
        if not ids: return "TEXT"
        fs = [self._res.get(i) for i in ids]
        if any(f is None or f == "ok" for f in fs): return "RAN"
        return "DENIED" if all(f == "deny" for f in fs) else "ERRORED"
    def write(self, unit, sess, usage, segs):
        _LOSBase.write(self, unit, sess, usage, segs)
        text = "".join(self.prompts)
        for blk, paths, off in self._edits:
            blk[4] = any(text.find(p, off) >= 0 for p in paths)
        for (s, key), (a, g) in self.iv.items():
            if self.cls(key) == "other":
                mid = key[1] if key[0] == "mid" else None
                _LOS.write(json.dumps(dict(row="time", unit=unit, step=s, sprint=sprint_of(segs[s]["first"]), mid=mid,
                                           tools=self._tools.get(mid, []) if mid else None, active=a, gap=g)) + "\n")
        for mid, (model, u, t, s) in usage.items():
            if self.cls(("mid", mid)) == "other":
                tok = [u.get("input_tokens", 0) or 0, u.get("cache_creation_input_tokens", 0) or 0,
                       u.get("cache_read_input_tokens", 0) or 0, u.get("output_tokens", 0) or 0]
                _LOS.write(json.dumps(dict(row="call", unit=unit, step=s, sprint=sprint_of(segs[s]["first"]), mid=mid,
                                           tools=self._tools.get(mid, []), model=model or "?", tok=tok,
                                           fate=self._fate(mid))) + "\n")

Classer = _LOSClasser
'''

SUBS = ("wait-poll", "sleep", "git", "script", "inline-interp", "shell-read", "shell-write", "test-build",
        "shell-builtin", "bash-other", "ctx-exec", "ctx-search", "mcp-other", "read", "edit", "harness", "operator",
        "tool-other", "text", "no-message")
SKIP = {"cd", "pushd", "popd", "export", "set", "unset", "source", ".", "true", "false", "trap", "ulimit", "umask",
        "time", "exec", "eval", "command", "builtin", "local", "declare", "readonly", "then", "do", "done", "fi", "else",
        "elif", "if", "for", "while", "until", "case", "esac", "in", "{", "}", "!", "[", "[[", "]]", "test", ":", "shopt",
        "wait", "return", "exit", "break", "continue", "nohup", "timeout", "env", "bash", "sh", "zsh"}
READ = {"cat", "head", "tail", "sed", "grep", "egrep", "rg", "ugrep", "ls", "wc", "find", "bfs", "awk", "jq", "diff",
        "cmp", "stat", "md5", "md5sum", "shasum", "echo", "printf", "date", "sort", "uniq", "cut", "tr", "xargs", "file",
        "basename", "dirname", "realpath", "readlink", "pwd", "tree", "column", "comm", "paste", "nl", "od", "xxd",
        "less", "more", "du", "df", "ps", "pgrep", "lsof", "which", "type", "hostname", "whoami", "id", "uname", "yq",
        "tac", "rev", "fold", "fmt", "join", "seq", "expr", "bc", "sw_vers", "sysctl", "printenv"}
WRITE = {"mkdir", "cp", "mv", "rm", "rmdir", "touch", "chmod", "ln", "tee", "install", "rsync", "tar", "unzip",
         "zip", "gzip", "kill", "pkill", "patch", "truncate", "mktemp"}
TEST = {"pytest", "npm", "npx", "uv", "uvx", "make", "node", "pnpm", "yarn", "cargo", "go", "ruff", "mypy", "pip",
        "pip3", "tsc", "jest", "vitest", "playwright", "docker", "perl", "ruby", "forge", "anvil", "cast", "hardhat"}
HARNESS = {"ToolSearch", "Skill", "TaskStop", "TaskOutput", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
           "TodoWrite", "Monitor", "ScheduleWakeup", "CronCreate", "CronDelete", "CronList", "EnterPlanMode",
           "ExitPlanMode", "EnterWorktree", "ExitWorktree", "ListAgents", "KillShell", "BashOutput", "SlashCommand"}
CTX_EXEC = ("ctx_execute", "ctx_execute_file", "ctx_batch_execute")
CTX_SEARCH = ("ctx_search", "ctx_index", "ctx_fetch_and_index")
IMPOSSIBLE_PROG = "qzxvnoprog4417.sh"
READING_SUBS = ("shell-read", "read", "ctx-exec", "ctx-search", "inline-interp")
PROCEDURE = (".claude/skills/", ".claude/team-roles/", ".claude/agents/", ".claude/hooks/", ".claude/rules/",
             "scripts/ai-dlc/", ".claude/settings")
SPRINT_DIR = re.compile(r"(^|/)_bmad-output/[^ ]*?/s\d{3}/")
TASK_OUT = re.compile(r"(^|/)(private/)?tmp/claude-\d+/.*/tasks/")
READINGS = ("merge", "gate-run", "snapshot", "dispatch", "wait-poll", "did-nothing", "text", "procedure", "open")
_m = re.search(r'^GATE_RUN_RE = re\.compile\(r"(.*)"\)$', open(EXTRACT).read(), re.M)
GATE_RUN_RE = re.compile(_m.group(1)) if _m else None   # extract.py's own gate-run predicate, read from its source


def ctx_ran(progs):
    """extract.py's Bash precedence (snapshot, then gate-run) applied to the programs a ctx_execute shell call ran,
    then the waiter; None when none of them applies."""
    if "snapshot-update.sh" in progs: return "snapshot"
    if GATE_RUN_RE is not None and any(GATE_RUN_RE.match(x) for x in progs): return "gate-run"
    if "wait-for-deliverable.sh" in progs: return "wait-poll"
    return None
GATE_REC = re.compile(r"/gate-transition/|/gate-adjudication/|gate-log\.md$|gate-metrics\.jsonl$")
BRIEF = re.compile(r"\.brief$|(^|/)briefs?/|-brief\.md$|(^|/)brief[^/]*\.md$")


def targets(blk):
    """The block's target paths, /dev/null and its kin dropped (a `2>/dev/null` is not a target)."""
    out = []
    for p in (blk[2] if len(blk) > 2 else []):
        q = p.lstrip("/")
        if q in ("dev/null", "dev/stdout", "dev/stderr") or q.startswith("dev/fd"):
            continue
        out.append(p)
    return out


def path_family(p):
    """(family, rule) of one target path, top-down. The sibling-of-a-prompt flag is NOT a rule: it took state files
    (snapshot, sprint-status, spawn ledger) once any prompt named a file beside them."""
    q = p.replace("/Users/n8/git/graph/", "").lstrip("/")
    if any(q.startswith(x) or ("/" + x) in p for x in PROCEDURE): return "procedure", "procedure"
    if TASK_OUT.search(p): return "delegate", "task-output"
    if GATE_REC.search(p): return "state", "gate-record"
    if SPRINT_DIR.search(p): return "delegate", "sprint-dir"
    if "_bmad-output/" in p or q.startswith("_bmad-output"): return "state", "state"
    return "project", "project"


def family(blk):
    """Family of one block: the one family every target shares, `mixed` when they differ, `none` with no target."""
    fs = {path_family(p)[0] for p in targets(blk)}
    return "none" if not fs else (fs.pop() if len(fs) == 1 else "mixed")


def nonread(progs):
    """The programs of a shell block that this file names as non-reads: WRITE, TEST, git, gh, sleep, or a script
    (.sh, .py). An unknown word is not counted: invoked() also yields words of grep patterns and inline code."""
    return [p for p in (progs or []) if p in WRITE or p in TEST or p in ("git", "gh", "sleep") or p.endswith((".sh", ".py"))]


def reading(row):
    """The step-value reading bucket of one `other` call row (see the module header)."""
    if row["row"] != "call": return None
    if row.get("fate") in ("DENIED", "ERRORED"): return "did-nothing"
    if row["sub"] == "text": return "text"
    if row["sub"] == "wait-poll": return "wait-poll"
    blk = row["tools"][0]
    wshape = len(blk) > 5 and blk[5]
    if row["sub"] == "ctx-exec":
        if not blk[1]: return "open"   # non-shell code: no write-shape reading exists for it
        k = ctx_ran(blk[1])
        if k: return k
        if bash_sub(blk[1])[0] not in ("shell-read", "shell-builtin"): return "open"
    if row["sub"] in READING_SUBS and not wshape and not nonread(blk[1]):
        f = family(blk)
        if f == "delegate": return "merge"
        if f == "procedure": return "procedure"
        return "open"
    if row["sub"] == "edit" and len(blk) > 4 and blk[4] and targets(blk) and all(BRIEF.search(p) for p in targets(blk)):
        return "dispatch"
    return "open"


def bash_sub(progs):
    """(sub-class, deciding program) for one Bash block's invoked() list."""
    for p in progs:
        if p in SKIP or not p:
            continue
        if p == "wait-for-deliverable.sh": return "wait-poll", p
        if p == "sleep": return "sleep", p
        if p in ("git", "gh"): return "git", p
        if p.endswith(".sh") or p.endswith(".py"): return "script", p
        if p.startswith("-"): return "inline-interp", p
        if p in READ: return "shell-read", p
        if p in WRITE: return "shell-write", p
        if p in TEST: return "test-build", p
        return "bash-other", p
    return "shell-builtin", None


def sub_of(tools):
    """(sub-class, detail) of one `other` message from its tool_use blocks [[name, progs], ...]; the first block decides."""
    if tools is None: return "no-message", None
    if not tools: return "text", None
    name, progs = tools[0][0] or "", tools[0][1]
    if name == "Bash": return bash_sub(progs or [])
    if name.startswith("mcp__"):
        base = name.rsplit("__", 1)[-1]
        if "context-mode" in name and base in CTX_EXEC: return "ctx-exec", base
        if "context-mode" in name and base in CTX_SEARCH: return "ctx-search", base
        return "mcp-other", name
    if name in ("Read", "Grep", "Glob"): return "read", name
    if name in ("Edit", "Write", "MultiEdit", "NotebookEdit"): return "edit", name
    if name in HARNESS: return "harness", name
    if name in ("AskUserQuestion", "PushNotification"): return "operator", name
    return "tool-other", name


def run_extract(scratch):
    src = open(EXTRACT).read()
    if src.count(ANCHOR) != 1:
        sys.exit("anchor found %d times in extract.py (must be 1): refusing" % src.count(ANCHOR))
    src2 = src.replace(ANCHOR, INJECT + ANCHOR)
    if src2 == src:
        sys.exit("injection changed nothing: refusing")
    os.makedirs(scratch, exist_ok=True)
    sys.argv = [EXTRACT, scratch]
    g = {"__name__": "__main__", "__file__": EXTRACT}
    exec(compile(src2, EXTRACT, "exec"), g)
    g["_LOS"].close()


def pipeline_key(out):
    """(unit, step) -> (sprint, step_base) over the lead seat's pipeline bucket, exactly as lead_class_value.cells()."""
    relabel, _fam = roll.analyze_defs()
    bucket = {u["sess"]: "pipeline" if any(k.split("|", 1)[0] != "pre-step" for k in u["tok"]) else "x"
              for u in (json.loads(l) for l in open(os.path.join(out, "units.jsonl"))) if u["kind"] == "lead"}
    K = {}
    for l in open(os.path.join(out, "segs.jsonl")):
        s = json.loads(l)
        if s["kind"] == "lead" and bucket.get(s["sess"]) == "pipeline" and s["sprint"] in roll.STORIES:
            K[(s["unit"], s["step"])] = (s["sprint"], roll.step_base(relabel.get((s["sess"], s["step"]), s["step"])))
    return K, _fam


def controls(scratch, out, rows):
    same = open(os.path.join(scratch, "classes.jsonl"), "rb").read() == open(os.path.join(out, "classes.jsonl"), "rb").read()
    print("C1 scratch classes.jsonl %s" % ("BYTE-EQUAL to the reference: MATCH" if same else "DIFFERS from the reference"))
    ref = collections.defaultdict(lambda: [0, 0.0, 0.0])
    for l in open(os.path.join(out, "classes.jsonl")):
        c = json.loads(l)
        if c["kind"] == "lead" and c["cls"] == "other":
            r = ref[(c["unit"], c["step"])]; r[0] += c["calls"]; r[1] += c["active"]; r[2] += c["gap"]
    mine = collections.defaultdict(lambda: [0, 0.0, 0.0])
    for r in rows:
        m = mine[(r["unit"], r["step"])]
        if r["row"] == "call": m[0] += 1
        else: m[1] += r["active"]; m[2] += r["gap"]
    keys = {k for k in set(ref) | set(mine) if any(ref[k]) or any(mine[k])}
    bad = [k for k in keys if ref[k][0] != mine[k][0] or abs(ref[k][1] - mine[k][1]) > 1e-6 or abs(ref[k][2] - mine[k][2]) > 1e-6]
    print("C2 conservation per (lead unit, step), `other` calls, active and gap: %d MATCH, %d DIFFERS%s" % (
        len(keys) - len(bad), len(bad), (" " + str(sorted(bad)[:5])) if bad else ""))
    progs = collections.Counter(p for r in rows if r["tools"] for t in r["tools"] if t[0] == "Bash" for p in (t[1] or []))
    print("C4 invoked programs: git %d, impossible %s %d (%s)" % (progs["git"], IMPOSSIBLE_PROG, progs[IMPOSSIBLE_PROG],
          "MATCH" if progs["git"] > 0 and progs[IMPOSSIBLE_PROG] == 0 else "DIFFERS"))
    return same and not bad and progs["git"] > 0 and progs[IMPOSSIBLE_PROG] == 0


def c3(prow, sprints):
    """The fate column against lead_class_denied.py's committed rendering of the same population: `other` calls whose
    fate is RAN or TEXT, by first tool name, per story, top 8 (out/lead_class_denied.s<A>.txt carries A and its B)."""
    ok = True; n_cmp = 0
    for sp in sprints:
        oc = collections.Counter((r["tools"][0][0] if r["tools"] else "(text)") for r in prow
                                 if r["sprint"] == sp and r["row"] == "call" and r["fate"] in ("RAN", "TEXT"))
        mine = "-- s%d other, RAN and TEXT calls by first tool, per story (of %.1f): %s" % (
            sp, sum(oc.values()) / roll.STORIES[sp], ", ".join("%s %.1f" % (k, v / roll.STORIES[sp]) for k, v in oc.most_common(8)))
        for f in sorted(os.listdir(os.path.join(HERE, "..", "out"))):
            if not f.startswith("lead_class_denied.s"):
                continue
            for l in open(os.path.join(HERE, "..", "out", f)):
                if l.startswith("-- s%d other, RAN and TEXT" % sp):
                    n_cmp += 1; same = l.rstrip("\n") == mine; ok = ok and same
                    print("C3 s%d fate line against out/%s: %s" % (sp, f, "MATCH" if same else "DIFFERS\n   mine: " + mine + "\n   ref:  " + l.rstrip()))
    if not n_cmp:
        print("C3 no committed fate line for %s: DIFFERS (nothing compared)" % sprints); ok = False
    return ok


def c5(out, prow):
    import lead_class_value as L
    ref = L.cells(out)
    mine = collections.defaultdict(lambda: [0.0, 0])
    for r in prow:
        m = mine[(r["sprint"], r["step"])]
        if r["row"] == "call": m[1] += 1
        else: m[0] += r["active"]
    keys = {k for k, v in ref.items() if "other" in v} | set(mine)
    bad = [k for k in keys if mine[k][1] != ref.get(k, {}).get("other", [0, 0])[1]
           or abs(mine[k][0] - ref.get(k, {}).get("other", [0, 0])[0]) > 1e-6]
    print("C5 pipeline-bucket `other` calls and active s per (sprint, step) against lead_class_value.cells(): %d MATCH, %d DIFFERS%s" % (
        len(keys) - len(bad), len(bad), (" " + str(sorted(bad)[:5])) if bad else ""))
    return not bad


def table(title, prow, sprints, fam, mix, pred, key="sub", order=SUBS):
    import lead_class_value as L
    agg = collections.defaultdict(lambda: collections.defaultdict(lambda: collections.defaultdict(float)))
    for r in prow:
        if not pred(r):
            continue
        a = agg[r["sprint"]][r[key]]
        if r["row"] == "call":
            a[1] += 1
            f = fam(r["model"])
            for i, n in enumerate(("in", "cw", "cr", "out")):
                a["lead_%s_%s" % (f, n)] += r["tok"][i]
            a["lead_%s_calls" % f] += 1
        else:
            a[0] += r["active"]
    print("-- %s, per story: calls / active h / lead token-equivalent $ (s322 at s321's hosted mix, roll.FALLBACK)" % title)
    print("   %-14s %s" % (key, "".join("%28s" % ("s%d (%d stories)" % (s, roll.STORIES[s])) for s in sprints)))
    tot = {s: [0.0, 0.0, 0.0] for s in sprints}
    for sub in order:
        if not any(sub in agg[s] for s in sprints):
            continue
        cells = []
        for s in sprints:
            a = agg[s].get(sub); n = roll.STORIES[s]
            if not a:
                cells.append("%28s" % "-"); continue
            usd = L.te_usd(a, s, mix)
            tot[s][0] += a[1]; tot[s][1] += a[0]; tot[s][2] += usd
            cells.append("%28s" % ("%.1f / %.3f / $%.2f" % (a[1] / n, a[0] / 3600 / n, usd / n)))
        print("   %-14s %s" % (sub, "".join(cells)))
    print("   %-14s %s" % ("all other", "".join("%28s" % ("%.1f / %.3f / $%.2f" % (tot[s][0] / roll.STORIES[s], tot[s][1] / 3600 / roll.STORIES[s], tot[s][2] / roll.STORIES[s])) for s in sprints)))


BL812_STEPS = ("architecture", "stories-test-strategy")


def bl812(out, prow, sprints, mix):
    """BL-812's two token-equivalent-only risers: the lead $ per story of each step, by lead class, with `other` split by
    reading. C6: the classes summed equal out/outcome_row.s322-complete.txt's lead calls and lead $ cells (the seat
    figure, a different code path: roll.seat_sum over steps.csv)."""
    import lead_class_value as L
    cells = L.cells(out)
    ref = {}; sp = None
    for l in open(os.path.join(HERE, "..", "out", "outcome_row.s322-complete.txt")):
        m = re.match(r"^s(\d{3}) whole", l)
        if m:
            sp = int(m.group(1)); continue
        m = re.match(r"^\s+(\S+)\s+[\d.]+\s+([\d.]+)\s+[\d.]+\s+\$([\d.]+)", l)
        if m and sp:
            ref[(sp, m.group(1))] = (m.group(2), m.group(3))
    ok = True
    for st in BL812_STEPS:
        print("-- BL-812 %s: lead $ per story by class (token-equivalent), `other` by reading" % st)
        for s in sprints:
            C = cells.get((s, st), {}); n = roll.STORIES[s]
            parts = {k: L.te_usd(a, s, mix) / n for k, a in C.items()}
            calls = sum(a[1] for a in C.values()) / n
            want = ref.get((s, st))
            got = ("%.1f" % calls, "%.1f" % sum(parts.values()))
            same = want == got; ok = ok and same
            print("   s%d: %s; sum $%.2f, %.1f calls | C6 against outcome_row %s: %s" % (
                s, ", ".join("%s $%.2f" % (k, parts[k]) for k in roll.CLASS_ORDER if k in parts), sum(parts.values()), calls,
                want, "MATCH" if same else "DIFFERS"))
            o = collections.defaultdict(lambda: collections.defaultdict(float))
            for r in prow:
                if r["sprint"] == s and r["step"] == st and r["row"] == "call":
                    a = o[r["reading"]]
                    fam = L._fam(r["model"])
                    for i, k in enumerate(("in", "cw", "cr", "out")):
                        a["lead_%s_%s" % (fam, k)] += r["tok"][i]
                    a["lead_%s_calls" % fam] += 1
            print("        other by reading: %s" % ", ".join("%s $%.2f" % (k, L.te_usd(o[k], s, mix) / n) for k in READINGS if k in o))
    return ok


def short(p):
    q = p.replace("/Users/n8/git/graph/", "").lstrip("/")
    q = re.sub(r"[0-9a-f]{8}-[0-9a-f-]{27,}", "<uuid>", q)
    q = re.sub(r"/s\d{3}/", "/sNNN/", q)
    return "/".join(q.split("/")[:5])


def hit_sets(prow, sprints):
    """What each rule caught, so a reader can check a bucket's population (conservation cannot)."""
    for s in sprints:
        n = roll.STORIES[s]
        rc = collections.defaultdict(collections.Counter)
        multi = mixed = wsh = runs = sibonly = nr = 0; runprog = collections.Counter(); nrprog = collections.Counter()
        sibt = collections.Counter(); mrule = collections.Counter()
        for r in prow:
            if not (r["sprint"] == s and r["row"] == "call" and r["fate"] == "RAN" and r["sub"] in READING_SUBS):
                continue
            blk = r["tools"][0]; ts = targets(blk)
            if len(blk) > 5 and blk[5]: wsh += 1
            if r["sub"] == "ctx-exec" and blk[1]:
                runs += 1; runprog[r["reading"]] += 1
            fams = {path_family(p)[0] for p in ts}
            multi += len(ts) > 1; mixed += len(fams) > 1
            for p in ts:
                rc[path_family(p)[1]][short(p)] += 1
            if fams and fams <= {"delegate", "procedure"} and len(fams) == 1 and nonread(blk[1]) and not (len(blk) > 5 and blk[5]):
                nr += 1; nrprog.update(set(nonread(blk[1])))
            if r["reading"] == "merge":
                mrule["+".join(sorted({path_family(p)[1] for p in ts}))] += 1
            if blk[3] and fams and "delegate" not in fams and "procedure" not in fams and "_bmad-output/" in " ".join(ts):
                sibonly += 1; sibt.update(short(p) for p in ts)
        print("-- s%d reading calls (RAN): %.1f per story with more than one target, %.1f spanning families (-> open), "
              "%.1f with a write shape (-> open), %.1f ctx_execute shell calls (calls by reading: %s); "
              "the retired sibling flag alone would have taken %.1f more" % (
                  s, multi / n, mixed / n, wsh / n, runs / n, ", ".join("%s %d" % kv for kv in runprog.most_common(8)) or "none", sibonly / n))
        print("   delegate- or procedure-family reads running a non-read program (-> open): %.1f per story; programs: %s" % (
            nr / n, ", ".join("%s %d" % kv for kv in nrprog.most_common(10)) or "none"))
        print("   merge calls by target rule: %s" % (", ".join("%s %d" % kv for kv in mrule.most_common()) or "none"))
        print("   retired sibling flag, targets of the calls it alone would have taken: %s" % (
            ", ".join("%s %d" % kv for kv in sibt.most_common(10)) or "none"))
        for rule in ("task-output", "sprint-dir", "gate-record", "state", "procedure"):
            c = rc.get(rule, collections.Counter())
            print("   rule %-11s %6d target hits; top: %s" % (rule, sum(c.values()), ", ".join("%s %d" % kv for kv in c.most_common(8))))
        ed = [r for r in prow if r["sprint"] == s and r["row"] == "call" and r["sub"] == "edit" and r["fate"] == "RAN"
              and len(r["tools"][0]) > 4 and r["tools"][0][4]]
        c = collections.Counter(short(p) for r in ed for p in targets(r["tools"][0]))
        nb = sum(1 for r in ed if r["reading"] == "dispatch")
        print("   edits whose path a LATER prompt names: %d, of them brief-shaped (-> dispatch) %d; targets: %s" % (
            len(ed), nb, ", ".join("%s %d" % kv for kv in c.most_common(12))))


def open_breakdown(prow, sprints):
    for s in sprints:
        c = collections.Counter()
        for r in prow:
            if r["sprint"] == s and r["row"] == "call" and r["reading"] == "open":
                c[(r["sub"], family(r["tools"][0]) if r["tools"] else "-")] += 1
        n = roll.STORIES[s]
        print("-- s%d `open` calls per story by (sub-class, target family), all %.1f: %s" % (
            s, sum(c.values()) / n, ", ".join("%s/%s %.1f" % (a, b, v / n) for (a, b), v in c.most_common())))


def main(scratch, out, sprints):
    if not os.path.exists(os.path.join(scratch, "other.jsonl")):
        run_extract(scratch)
    rows = [json.loads(l) for l in open(os.path.join(scratch, "other.jsonl"))]
    for r in rows:
        r["sub"], r["detail"] = sub_of(r["tools"])
    ok = controls(scratch, out, rows)
    K, fam = pipeline_key(out)
    prow = [dict(r, sprint=K[(r["unit"], r["step"])][0], step=K[(r["unit"], r["step"])][1]) for r in rows if (r["unit"], r["step"]) in K]
    ok = c5(out, prow) and ok
    ok = c3(prow, sprints) and ok
    print("controls: %s" % ("ALL MATCH" if ok else "FAILED"))
    rd = {}
    for r in prow:
        if r["row"] == "call":
            r["reading"] = rd[(r["unit"], r["mid"])] = reading(r)
    for r in prow:
        if r["row"] == "time":
            r["reading"] = "open" if r["mid"] is None else rd.get((r["unit"], r["mid"])) or reading(dict(r, row="call", fate="RAN"))
    mix = roll.hosted_mix(list(roll.csv.DictReader(open(os.path.join(out, "steps.csv")))), "lead")
    blocks = {s: sum(len(r["tools"]) for r in prow if r["sprint"] == s and r["row"] == "call") for s in sprints}
    calls_ = {s: sum(1 for r in prow if r["sprint"] == s and r["row"] == "call") for s in sprints}
    print("-- packaging: `other` tool_use blocks per story (blocks per call): %s" % ", ".join(
        "s%d %.1f (%.2f)" % (s, blocks[s] / roll.STORIES[s], blocks[s] / calls_[s] if calls_[s] else 0) for s in sprints))
    for s in sprints:
        fc = collections.Counter(family(r["tools"][0]) for r in prow if r["sprint"] == s and r["row"] == "call"
                                 and r["sub"] in READING_SUBS and r["fate"] == "RAN")
        print("-- s%d reading calls (RAN) by target family, per story: %s" % (s, ", ".join(
            "%s %.1f" % (k, fc[k] / roll.STORIES[s]) for k in ("delegate", "procedure", "state", "project", "mixed", "none"))))
    for s in sprints:
        ed = [r for r in prow if r["sprint"] == s and r["row"] == "call" and r["sub"] == "edit" and r["fate"] == "RAN"]
        print("-- s%d edit calls (RAN): %d, of them the edited path appears in a LATER Agent/Task prompt of the unit %d" % (
            s, len(ed), sum(1 for r in ed if len(r["tools"][0]) > 4 and r["tools"][0][4])))
    ok = bl812(out, prow, sprints, mix) and ok
    print("controls with C6: %s" % ("ALL MATCH" if ok else "FAILED"))
    table("READINGS, all steps, pipeline bucket", prow, sprints, fam, mix, lambda r: True, "reading", READINGS)
    hit_sets(prow, sprints)
    open_breakdown(prow, sprints)
    steps = sorted({r["step"] for r in prow if r["sprint"] in sprints})
    for st in steps:
        table("READINGS, " + st, prow, sprints, fam, mix, lambda r, st=st: r["step"] == st, "reading", READINGS)
    table("all steps, pipeline bucket", prow, sprints, fam, mix, lambda r: True)
    for st in steps:
        table(st, prow, sprints, fam, mix, lambda r, st=st: r["step"] == st)
    print("-- fate of `other` calls per sub-class, per story, pipeline bucket: DENIED / ERRORED / RAN (TEXT is the text row)")
    for sub in SUBS:
        if sub in ("text", "no-message"):
            continue
        cells = []
        for s in sprints:
            c = collections.Counter(r["fate"] for r in prow if r["sprint"] == s and r["row"] == "call" and r["sub"] == sub)
            n = roll.STORIES[s]
            cells.append("%28s" % ("%.1f / %.1f / %.1f" % (c["DENIED"] / n, c["ERRORED"] / n, c["RAN"] / n) if c else "-"))
        if any(x.strip() != "-" for x in cells):
            print("   %-14s %s" % (sub, "".join(cells)))
    for s in sprints:
        for sub in ("shell-read", "bash-other", "tool-other", "script", "shell-builtin"):
            c = collections.Counter(r["detail"] for r in prow if r["sprint"] == s and r["row"] == "call" and r["sub"] == sub)
            if c:
                print("-- s%d %s calls by %s (all %d, pipeline bucket): %s" % (s, sub, "tool" if sub == "tool-other" else "program",
                      sum(c.values()), ", ".join("%s %d" % kv for kv in c.most_common())))
    return 0 if ok else 1


def self_test():
    cases = [
        (None, "no-message"), ([], "text"),
        ([["Bash", ["cd", "wait-for-deliverable.sh"]]], "wait-poll"),
        ([["Bash", ["sleep"]]], "sleep"),
        ([["Bash", ["export", "git"]]], "git"),
        ([["Bash", ["snapshot-check.py"]]], "script"),
        ([["Bash", ["-c"]]], "inline-interp"),
        ([["Bash", ["cat", "rm"]]], "shell-read"),
        ([["Bash", ["mkdir", "cat"]]], "shell-write"),
        ([["Bash", ["pytest"]]], "test-build"),
        ([["Bash", ["cd"]]], "shell-builtin"),
        ([["Bash", ["frobnicate"]]], "bash-other"),
        ([["mcp__plugin_context-mode_context-mode__ctx_execute", []]], "ctx-exec"),
        ([["mcp__plugin_context-mode_context-mode__ctx_search", []]], "ctx-search"),
        ([["mcp__other__ctx_execute", []]], "mcp-other"),
        ([["Grep", []], ["Bash", ["git"]]], "read"),
        ([["Write", []]], "edit"),
        ([["ToolSearch", []]], "harness"),
        ([["AskUserQuestion", []]], "operator"),
        ([["Frobnicate", []]], "tool-other"),
    ]
    bad = 0
    for tools, want in cases:
        got = sub_of(tools)[0]
        bad += got != want
        print("  %s -> %s (want %s) %s" % (tools, got, want, "ok" if got == want else "WRONG"))
    seen = {w for _, w in cases}
    missing = [s for s in SUBS if s not in seen]
    print("  sub-classes with no seeded case: %s" % (missing or "none")); bad += bool(missing)
    fcases = [
        (["Bash", ["cat"], ["/dev/null", ".claude/skills/ai-dlc/steps/x.md"], False, None, False], "procedure"),
        (["Bash", ["tail"], ["/private/tmp/claude-501/-Users-n8-git-graph/abc/tasks/b1.output"], False, None, False], "delegate"),
        (["Read", [], ["_bmad-output/planning-artifacts/s322/shards/1.md"], False, None, False], "delegate"),
        (["Read", [], ["_bmad-output/implementation-artifacts/gate-log.md"], True, None, False], "state"),
        (["Read", [], ["_bmad-output/implementation-artifacts/s322/gate-transition/3.md"], False, None, False], "state"),
        (["Read", [], ["_bmad-output/pipeline-snapshot.md"], True, None, False], "state"),
        (["Read", [], ["docs/architecture.md"], True, None, False], "project"),
        (["Bash", ["ls"], ["/dev/null"], False, None, False], "none"),
        (["Bash", ["ls"], ["/private/tmp/claude-501/scratch/x.txt"], False, None, False], "project"),
        (["Bash", ["grep"], [".claude/skills/a.md", "_bmad-output/planning-artifacts/s322/r/1.md"], False, None, False], "mixed"),
    ]
    for blk, want in fcases:
        got = family(blk); bad += got != want
        print("  family %s -> %s (want %s) %s" % (blk[2], got, want, "ok" if got == want else "WRONG"))
    rcases = [
        (dict(row="call", sub="shell-read", fate="DENIED", tools=[["Bash", ["cat"], [".claude/skills/a"], False, None, False]]), "did-nothing"),
        (dict(row="call", sub="text", fate="TEXT", tools=[]), "text"),
        (dict(row="call", sub="wait-poll", fate="RAN", tools=[["Bash", ["wait-for-deliverable.sh"], [], False, None, False]]), "wait-poll"),
        (dict(row="call", sub="read", fate="RAN", tools=[["Read", [], ["_bmad-output/x/s322/r/1.md"], False, None, False]]), "merge"),
        (dict(row="call", sub="shell-read", fate="RAN", tools=[["Bash", ["cat"], ["_bmad-output/x/s322/r/1.brief"], False, None, True]]), "open"),
        (dict(row="call", sub="ctx-exec", fate="RAN", tools=[["mcp__plugin_context-mode_context-mode__ctx_execute", ["frob.sh"], ["_bmad-output/x/s322/r/1.md"], False, None, False]]), "open"),
        (dict(row="call", sub="ctx-exec", fate="RAN", tools=[["mcp__plugin_context-mode_context-mode__ctx_execute", ["cd", "validate-spec-join.sh"], [], False, None, False]]), "gate-run"),
        (dict(row="call", sub="ctx-exec", fate="RAN", tools=[["mcp__plugin_context-mode_context-mode__ctx_execute", ["validate-x.sh", "snapshot-update.sh"], [], False, None, False]]), "snapshot"),
        (dict(row="call", sub="ctx-exec", fate="RAN", tools=[["mcp__plugin_context-mode_context-mode__ctx_execute", [], ["_bmad-output/x/s322/r/1.md"], False, None, False]]), "open"),
        (dict(row="call", sub="ctx-exec", fate="RAN", tools=[["mcp__plugin_context-mode_context-mode__ctx_execute", ["cd", "grep"], ["_bmad-output/x/s322/r/1.md"], False, None, False]]), "merge"),
        (dict(row="call", sub="ctx-exec", fate="RAN", tools=[["mcp__plugin_context-mode_context-mode__ctx_execute", ["git"], ["_bmad-output/x/s322/r/1.md"], False, None, False]]), "open"),
        (dict(row="call", sub="shell-read", fate="RAN", tools=[["Bash", ["grep"], ["scripts/ai-dlc/x.sh"], False, None, False]]), "procedure"),
        (dict(row="call", sub="read", fate="RAN", tools=[["Read", [], ["src/app.py"], False, None, False]]), "open"),
        (dict(row="call", sub="edit", fate="RAN", tools=[["Edit", [], ["_bmad-output/b/s322/1.brief"], False, True, False]]), "dispatch"),
        (dict(row="call", sub="edit", fate="RAN", tools=[["Edit", [], ["_bmad-output/planning-artifacts/prd.md"], False, True, False]]), "open"),
        (dict(row="call", sub="edit", fate="RAN", tools=[["Edit", [], ["_bmad-output/b/s322/1.brief"], False, False, False]]), "open"),
        (dict(row="call", sub="git", fate="RAN", tools=[["Bash", ["git"], [], False, None, False]]), "open"),
        (dict(row="call", sub="shell-read", fate="RAN", tools=[["Bash", ["cat", "rm"], ["_bmad-output/x/s322/r/1.md"], False, None, False]]), "open"),
        (dict(row="call", sub="shell-read", fate="RAN", tools=[["Bash", ["grep", "frob.sh"], [".claude/skills/a.md"], False, None, False]]), "open"),
        (dict(row="call", sub="inline-interp", fate="RAN", tools=[["Bash", ["-c"], ["_bmad-output/x/s322/r/1.md"], False, None, False]]), "merge"),
    ]
    for name, inp, sh, want in (
            ("Edit", {"file_path": "/g/docs/a.md", "old_string": "x", "new_string": "see _bmad-output/x/s322/1.brief"}, "", "/g/docs/a.md"),
            ("Write", {"file_path": "/g/b.brief", "content": "read .claude/skills/s.md"}, "", "/g/b.brief"),
            ("Read", {"file_path": "/g/c.md", "offset": 1}, "", "/g/c.md"),
            ("Grep", {"pattern": "docs/x.md", "path": "/g/src"}, "", "/g/src"),
            ("Bash", {"command": "cat f", "description": "read docs/x.md"}, "cat f", "cat f")):
        got = _los_target_text(name, inp, sh); bad += got != want
        print("  target text %s -> %r (want %r) %s" % (name, got, want, "ok" if got == want else "WRONG"))
    import re as _re
    wre = _re.compile(INJECT.split("_LOS_WRITE = re.compile(r\"", 1)[1].split("\")\n", 1)[0])
    for cmd, want in (("cat > f.brief <<EOF", True), ("echo x >> log.md", True), ("sed -i '' s/a/b/ f", True),
                      ("ls | tee out.txt", True), ("grep x f 2>/dev/null", False), ("cmd >/dev/null 2>&1", False),
                      ("echo x >&2", False), ("cat f", False)):
        got = bool(wre.search(cmd)); bad += got != want
        print("  write-shape %r -> %s (want %s) %s" % (cmd, got, want, "ok" if got == want else "WRONG"))
    for row, want in rcases:
        got = reading(row); bad += got != want
        print("  reading %s %s -> %s (want %s) %s" % (row["sub"], row["fate"], got, want, "ok" if got == want else "WRONG"))
    rmiss = [x for x in READINGS if x not in {w for _, w in rcases}]
    print("  readings with no seeded case: %s" % (rmiss or "none")); bad += bool(rmiss)
    src = open(EXTRACT).read()
    print("  anchor occurrences in extract.py: %d (must be 1)" % src.count(ANCHOR)); bad += src.count(ANCHOR) != 1
    print("  GATE_RUN_RE read from extract.py: %s" % ("yes" if GATE_RUN_RE is not None else "NO")); bad += GATE_RUN_RE is None
    print("self-test: %s" % ("PASS" if not bad else "FAIL (%d)" % bad))
    return 0 if not bad else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--self-test"]:
        sys.exit(self_test())
    if len(a) < 3:
        sys.exit(__doc__)
    sys.exit(main(a[0], a[1], [int(x) for x in a[2:]]))
