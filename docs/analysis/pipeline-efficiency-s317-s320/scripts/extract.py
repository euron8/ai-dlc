"""Stream graph transcripts for sprints 317-318 and emit per-unit records.

Outputs (scratchpad/out/):
  units.jsonl   one row per transcript (lead session or subagent) with totals
  segs.jsonl    one row per (lead session, step segment)
  hooks.jsonl   hook firings: session, step, hook, event, durationMs, bytes
  tools.jsonl   tool calls: unit, step, tool, latency_s, result_bytes

Two attribution rules beyond the step-file reads:
  Spawn owner. An Agent/Task call recorded inside a SUBAGENT scan at pre-step (a depth-2 spawn by a subagent that
    read no step file) is resolved before owner.json is written to the step its own subagent was spawned under,
    following the chain; a lead-recorded pre-step spawn stays pre-step.
  Gate span. In a LEAD scan an INVOCATION of gate-checkpoint.sh ... open (or a non-close gate-transition.sh <story> 3)
    opens a gate labelled gate-validation[<main at open>]; until an invocation of gate-checkpoint.sh ... close,
    gate-validation reads keep that label and a whole read of another step moves main but not step. Close sets
    step = main (also when no gate was open). With no open ever seen, behaviour is the plain read-driven rule.
"""
import json, os, re, sys, glob, datetime as dt

ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
OUT = sys.argv[1]
# WIN_START is a parameter: argv[2], else $EXTRACT_WIN_START, else just after graph's s313 close
# (commit 6a4469196, 2026-09-25T20:31-04:00), so s314 onward is selected. Records before it are dropped.
WIN_START = (sys.argv[2] if len(sys.argv) > 2 else os.environ.get("EXTRACT_WIN_START")) or "2026-09-26T00:35:00Z"
# WIN_END pins a snapshot: argv[3], else $EXTRACT_WIN_END, else unbounded. A record whose timestamp is LATER
# than it is dropped, compared as an instant (not as a string, so fractional seconds order correctly).
WIN_END = (sys.argv[3] if len(sys.argv) > 3 else os.environ.get("EXTRACT_WIN_END")) or None
os.makedirs(OUT, exist_ok=True)

STEP_RE = re.compile(r"skills/ai-dlc(?:-update)?/steps/([A-Za-z0-9_.-]+)\.md")
SUBPROC = {"_gate-procedures", "_dispatch-protocol"}

def ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
WIN_END_TS = ts(WIN_END) if WIN_END else None

# Each edge is the END of sprint n: graph's last close commit for that sprint plus a few minutes
# (36f74d63c s314 2026-09-28T15:07:38-04, 7b74011a9 s315 2026-09-30T16:55:42-04,
#  8eb9429a1 s316 2026-10-05T09:58:27-04; the s317-s319 edges follow the same rule).
# s320 ends at the lead-session handover, not at the s320 PR merge 72e1cd749 (2026-10-29T17:01Z): the retro,
# ff2-ff4 and the close sweep ran after it, in lead dd2df1d7, through graph's last s320 commit 0672c7221
# (2026-10-29T23:37:29Z, the s321 fork base) and "Sprint 320 closed" (23:39:18Z). dd2df1d7's last record is
# 2026-10-30T00:10:01.416Z; the s321 lead 2c84f6b7 (/ai-dlc for sprint 321) opens at 00:10:05.572Z. No
# transcript carries a record stamped 00:10:03, so the string compare in sprint_of() is exact here.
EDGES = [("2026-09-28T19:10:00Z",314),("2026-09-30T20:58:00Z",315),("2026-10-05T14:00:00Z",316),
         ("2026-10-12T02:30:00Z",317),("2026-10-14T22:00:00Z",318),("2026-10-23T09:53:00Z",319),
         ("2026-10-30T00:10:03Z",320),("2026-11-09T00:00:00Z",321),("2099-01-01T00:00:00Z",322)]
# s321 ends at the lead-session handover: s321's last lead df56108b (retro merge ec443477d at
# 2026-11-08T20:23Z, then the close sweep) has its last record at 2026-11-08T21:47:01.989Z; the s322 lead
# 6c14d949 (/ai-dlc "Finish Epic 5") opens at 2026-11-09T00:00:37.657Z. The spawn ledger agrees: last s321
# row 2026-11-08T20:30:46Z, first s322 row 2026-11-09T00:20:57Z.
def sprint_of(t):
    if t < WIN_START: return None
    for e, n in EDGES:
        if t < e: return n

def strip_heredocs(cmd):
    out = []; end = None
    for ln in cmd.split("\n"):
        if end is not None:
            if ln.strip() == end: end = None
            continue
        out.append(ln)
        m = re.search(r"<<-?\s*(?:'([^']+)'|\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_]*))", ln)
        if m: end = m.group(1) or m.group(2) or m.group(3)
    return "\n".join(out)

def gate_event(cmd):
    """'open' / 'close' / None for the INVOCATIONS of the gate scripts in a Bash command (heredoc bodies stripped,
    script name in command position of a pipeline / ; / && segment, after optional bash/sh/env and VAR=x words)."""
    ev = None
    for seg_ in re.split(r"\|\||&&|[|;&\n]", strip_heredocs(cmd)):
        w = [x.strip("\"'") for x in seg_.split()]
        while w and (w[0] in ("bash", "sh", "env") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])): w = w[1:]
        if not w: continue
        base = os.path.basename(w[0]); args = w[1:]
        if base == "gate-checkpoint.sh":
            if "close" in args: ev = "close"
            elif "open" in args: ev = "open"
        elif base == "gate-transition.sh":
            # usage: gate-transition.sh <story-index> 1|2|3|close ; the gate is the SECOND positional argument
            pos, skip = [], False
            for a in args:
                if skip: skip = False; continue
                if a.startswith("-"):
                    skip = "=" not in a and a in ("--pass",)
                    continue
                pos.append(a)
            if len(pos) > 1 and pos[1] == "3": ev = "open"
    return ev

def human_prompt(r):
    if r.get("type") != "user" or r.get("toolUseResult") is not None or r.get("isMeta"):
        return False
    c = r.get("message", {}).get("content")
    if isinstance(c, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c):
            return False
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
    if not isinstance(c, str): return False
    c = c.lstrip()
    return not (c.startswith("<task-notification") or c.startswith("<system-reminder")
                or c.startswith("<local-command") or c.startswith("Caveat:")
                or c.startswith("<teammate-message") or c.startswith("<cross-session"))

def rbytes(c):
    if isinstance(c, str): return len(c.encode())
    if isinstance(c, list):
        n = 0
        for x in c:
            if isinstance(x, dict):
                n += len((x.get("text") or "").encode()) if x.get("type") == "text" else len(json.dumps(x).encode())
        return n
    return len(json.dumps(c).encode()) if c is not None else 0

owner = {}   # tool_use_id of an Agent/Task call -> (session, step, ts)
rec_by = {}  # tool_use_id of an Agent/Task call -> meta.toolUseId of the recording unit (None for a lead)
fh = {k: open(os.path.join(OUT, k + ".jsonl"), "w") for k in ("units", "segs", "hooks", "tools")}
cfh = open(os.path.join(OUT, "classes.jsonl"), "w")

# Lead tool-call classes (BL-819 item 1), written to classes.jsonl: one row per (lead unit, step, class).
# A class is decided per message.id over ALL of that message's content blocks: the highest-precedence class any
# tool_use block of it earns, `other` when none earns one (text- or thinking-only messages included).
# Precedence, top-down:
#   compaction-recovery  every message first seen after an isCompactSummary record and before the first tool_use
#                        that is not Read/Grep/Glob; the message carrying that tool_use is classed by its blocks.
#   snapshot             Bash invoking snapshot-update.sh, or whose command (heredoc bodies stripped) names the file
#                        pipeline-snapshot.md under any directory prefix, or whose heredoc body is fed to an
#                        interpreter (python, python3, awk, sed, perl, ruby, node) and names it; Edit/Write whose
#                        file_path ends pipeline-snapshot.md. pipeline-snapshot-history.md and other names never match.
#   repair               Agent/Task whose description matches REPAIR_RE, or equals an earlier Agent/Task description
#                        of the same unit.
#   dispatch             any other Agent/Task; SendMessage; Write of a file whose path appears in a LATER Agent/Task
#                        prompt of the unit (the absolute path, or the cwd-relative path when that holds a slash).
#   gate-run             Bash invoking gate-checkpoint.sh, gate-slice*, gate-transition.sh, validate-*.sh or
#                        *-validator[.sh|.py].
#   step-reread          Read of a STEP_RE file the unit already read (whole or slice).
#   merge                Read/Grep/Glob/Bash whose input names a path (cwd prefix and ./ stripped, compared by
#                        leading path segments) that appeared in an EARLIER Agent/Task prompt of the unit;
#                        TaskOutput/BashOutput.
#   other                everything else.
# "Invoking" is the gate_event() reading: heredoc bodies stripped, the program in command position of a
# pipeline / ; / && segment, after optional bash/sh/env/python/python3 and VAR=x words.
# Time: the interval between consecutive records is measured on a MONOTONE clock (an out-of-order record charges 0
# and does not move the clock back), split at 300 s into active and gap exactly as segs, charged to the step segs
# charges it to, and to the class of the record that opened it: an assistant record's message.id; a tool_result's
# answered tool_use's message.id; any other record the most recent assistant message.id. From an isCompactSummary
# record until recovery ends, a non-assistant record opens a compaction-recovery interval. Tokens: each
# usage-bearing message.id to its own class, at the step segs records it under, so per (unit, step) the class
# tokens sum to segs tok exactly.
# idle-wait is a TIME-ONLY class and sits outside the precedence list above: the interval OPENED by a `system`
# record with subtype `turn_duration` (the interval closed by the next record) is charged to it, exactly
# lead_time.py's prev_end rule (pipeline-efficiency-s317-s322/scripts/lead_time.py, "if prev_end: key = idle-wait").
# `stop_hook_summary` and `compact_boundary` do NOT open one. It carries 0 calls and 0 tokens (no message.id owns it);
# an interval over 300 s is still charged to gap, as gap of this class. PRECEDENCE: compaction-recovery wins, because
# record() returns for a recovery window before the turn_duration test, so a turn end inside a recovery window
# stays compaction-recovery. Per (unit, step) the class totals of active and gap are unchanged by this class: it
# only carves seconds out of the class they were charged to before.
CLASSES = ("compaction-recovery", "snapshot", "repair", "dispatch", "gate-run", "step-reread", "merge", "other", "idle-wait")
RANK = {c: i for i, c in enumerate(CLASSES)}
REPAIR_RE = re.compile(r"(?i)\b(fix|fixes|repair|re-run|rerun|retry|redispatch|re-dispatch)\b")
GATE_RUN_RE = re.compile(r"^(gate-checkpoint\.sh|gate-slice.*|gate-transition\.sh|validate-.*\.sh|.*-validator(\.sh|\.py)?)$")
PATH_RE = re.compile(r"(?:~|\.{1,2})?/?(?:[A-Za-z0-9_@.+-]+/)+[A-Za-z0-9_@.+*-]*")

def invoked(cmd):
    """Basenames of the programs a Bash command invokes (see the class comment above)."""
    out = []
    for seg_ in re.split(r"\|\||&&|[|;&\n]", strip_heredocs(cmd)):
        w = [x.strip("\"'()") for x in seg_.split()]
        while w and (w[0] in ("bash", "sh", "env", "python", "python3") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])): w = w[1:]
        if w: out.append(os.path.basename(w[0]))
    return out

SNAP_RE = re.compile(r"(?<![A-Za-z0-9_.-])pipeline-snapshot\.md(?![A-Za-z0-9_-])")
INTERP = ("python", "python3", "awk", "sed", "perl", "ruby", "node")

def names_snapshot(cmd):
    """True when a Bash command names pipeline-snapshot.md: in the heredoc-stripped text, or in a heredoc body whose
    opening line runs an interpreter (the body is then the program that opens or writes the file)."""
    stripped = strip_heredocs(cmd)
    if SNAP_RE.search(stripped): return True
    if stripped == cmd: return False
    for seg_ in re.split(r"\|\||&&|[|;&\n]", stripped):
        w = [x.strip("\"'()") for x in seg_.split()]
        while w and (w[0] in ("bash", "sh", "env") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])): w = w[1:]
        if w and os.path.basename(w[0]) in INTERP and "<<" in seg_: return bool(SNAP_RE.search(cmd))
    return False

def norm_paths(text, cwd):
    out = set()
    for p in PATH_RE.findall(text):
        if cwd and p.startswith(cwd + "/"): p = p[len(cwd) + 1:]
        while p.startswith("./"): p = p[2:]
        p = p.rstrip("/")
        if p != cwd and "/" in p.lstrip("/"): out.add(p)
    return out

class Classer:
    def __init__(self):
        self.iv = {}          # (step, key) -> [active, gap]; key ("mid", id) or ("cls", class)
        self.best = {}        # message.id -> best (lowest) rank over its blocks
        self.rec = set()      # message.ids classed compaction-recovery
        self.tu_mid = {}      # tool_use id -> message.id
        self.last_mid = None; self.key = ("cls", "other"); self.clk = None; self.recover = False
        self.descs = set(); self.read_steps = set(); self.ptoks = set()
        self.prompts = []; self.plen = 0; self.writes = []   # (message.id, [paths], prompt offset at the Write)

    def interval(self, step, tt):
        if self.clk is not None:
            d = max(0.0, tt - self.clk)
            self.iv.setdefault((step, self.key), [0.0, 0.0])[0 if d <= 300 else 1] += d
        self.clk = tt if self.clk is None else max(self.clk, tt)

    def merge_hit(self, inp, cwd):
        for p in norm_paths(" ".join(str(v) for v in inp.values()), cwd):
            parts = p.split("/")
            for i in range(1, len(parts) + 1):
                if "/".join(parts[:i]) in self.ptoks: return True
        return False

    def block(self, c, cwd):
        name = c.get("name"); inp = c.get("input") or {}
        if not isinstance(inp, dict): inp = {}
        if name == "Bash":
            prog = invoked(str(inp.get("command") or ""))
            if "snapshot-update.sh" in prog or names_snapshot(str(inp.get("command") or "")): return "snapshot"
            if any(GATE_RUN_RE.match(x) for x in prog): return "gate-run"
            return "merge" if self.merge_hit(inp, cwd) else "other"
        if name in ("Edit", "Write") and str(inp.get("file_path") or "").endswith("pipeline-snapshot.md"):
            return "snapshot"
        if name in ("Agent", "Task"):
            d = str(inp.get("description") or ""); pr = str(inp.get("prompt") or "")
            k = "repair" if (REPAIR_RE.search(d) or d in self.descs) else "dispatch"
            self.descs.add(d); self.ptoks |= norm_paths(pr, cwd)
            self.prompts.append(pr + "\n"); self.plen += len(pr) + 1
            return k
        if name == "SendMessage": return "dispatch"
        if name == "Write":
            fp = str(inp.get("file_path") or "")
            rel = fp[len(cwd) + 1:] if cwd and fp.startswith(cwd + "/") else fp
            self.writes.append((self.cur, [x for x in {fp, rel} if x and (x == fp or "/" in x)], self.plen))
            return "other"
        if name in ("TaskOutput", "BashOutput"): return "merge"
        if name == "Read":
            mm = STEP_RE.search(json.dumps(inp))
            if mm:
                again = mm.group(1) in self.read_steps; self.read_steps.add(mm.group(1))
                if again: return "step-reread"
        if name in ("Read", "Grep", "Glob") and self.merge_hit(inp, cwd): return "merge"
        return "other"

    def record(self, r, typ):
        cwd = r.get("cwd") or ""
        if r.get("isCompactSummary"): self.recover = True
        if typ == "assistant":
            mid = (r.get("message") or {}).get("id")
            if not mid: self.key = ("cls", "other"); return
            self.cur = mid; self.last_mid = mid
            if mid not in self.best:
                self.best[mid] = RANK["other"]
                if self.recover: self.rec.add(mid)
            for c in (r.get("message") or {}).get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "tool_use" or c.get("id") in self.tu_mid: continue
                self.tu_mid[c.get("id")] = mid
                if self.recover and c.get("name") not in ("Read", "Grep", "Glob"):
                    self.recover = False; self.rec.discard(mid)
                self.best[mid] = min(self.best[mid], RANK[self.block(c, cwd)])
            self.key = ("mid", mid); return
        if self.recover: self.key = ("cls", "compaction-recovery"); return
        if typ == "system" and r.get("subtype") == "turn_duration": self.key = ("cls", "idle-wait"); return
        c =(r.get("message") or {}).get("content") if typ == "user" else None
        tid = next((x.get("tool_use_id") for x in c if isinstance(x, dict) and x.get("type") == "tool_result"), None) if isinstance(c, list) else None
        m = self.tu_mid.get(tid) if tid else None
        m = m or self.last_mid
        self.key = ("mid", m) if m else ("cls", "other")

    def cls(self, key):
        if key[0] == "cls": return key[1]
        return "compaction-recovery" if key[1] in self.rec else CLASSES[self.best.get(key[1], RANK["other"])]

    def write(self, unit, sess, usage, segs):
        text = "".join(self.prompts)
        for mid, paths, off in self.writes:
            if any(text.find(p, off) >= 0 for p in paths): self.best[mid] = min(self.best[mid], RANK["dispatch"])
        rows = {}
        def row(s, k):
            return rows.setdefault((s, k), dict(active=0.0, gap=0.0, calls=0, tok={}))
        for (s, key), (a, g) in self.iv.items():
            R = row(s, self.cls(key)); R["active"] += a; R["gap"] += g
        for mid, (model, u, t, s) in usage.items():
            R = row(s, self.cls(("mid", mid)))
            d = R["tok"].setdefault(model or "?", [0, 0, 0, 0, 0])
            d[0] += u.get("input_tokens", 0) or 0
            d[1] += u.get("cache_creation_input_tokens", 0) or 0
            d[2] += u.get("cache_read_input_tokens", 0) or 0
            d[3] += u.get("output_tokens", 0) or 0
            d[4] += 1; R["calls"] += 1
        for (s, k), R in sorted(rows.items()):
            cfh.write(json.dumps(dict(unit=unit, sess=sess, kind="lead", step=s, cls=k,
                                      sprint=sprint_of(segs[s]["first"]), **R)) + "\n")

def scan(path, kind, meta):
    usage = {}           # message.id -> (model, usage, ts, step)
    step = "pre-step"; main = "pre-step"
    gate = None          # label of the open gate segment (lead scans only)
    whole = set()        # step files this transcript has read without offset/limit
    segs = {}            # step -> dict
    pend = {}            # tool_use_id -> (name, ts, step)
    first = last = None; prev_t = None; prev_type = None
    sess = os.path.basename(os.path.dirname(os.path.dirname(path))) if kind == "sub" else os.path.basename(path)[:-6]
    unit = os.path.basename(path)[:-6]
    compactions = 0; humans = 0; skills = {}
    K = Classer() if kind == "lead" else None
    def seg(s):
        return segs.setdefault(s, dict(first=None, last=None, active=0.0, op_wait=0.0, agent_wait=0.0,
                                       reads=0, compactions=0, humans=0, tool_bytes=0, hook_bytes=0, lines=0, gap=0.0))
    for line in open(path, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < WIN_START: continue
        tt = ts(t)
        if WIN_END_TS is not None and tt > WIN_END_TS: continue
        first = first or t; last = t
        typ = r.get("type")
        S = seg(step); S["lines"] += 1
        S["first"] = S["first"] or t; S["last"] = t
        if prev_t is not None:
            gap = max(0.0, tt - prev_t)
            # "gap" is the time between consecutive records that exceeds 300 s. It is charged to op_wait or
            # agent_wait below AND recorded here on its own, so op_wait + agent_wait == gap. Hours built
            # from active + op_wait + agent_wait are therefore gap-inclusive.
            if gap <= 300: S["active"] += gap
            else: S["gap"] += gap
            if gap <= 300: pass
            elif (typ == "user" and human_prompt(r)) or any(v[0] == "AskUserQuestion" for v in pend.values()): S["op_wait"] += gap
            else: S["agent_wait"] += gap
        prev_t = tt
        if K: K.interval(step, tt)
        if r.get("isCompactSummary"):
            compactions += 1; S["compactions"] += 1
        if human_prompt(r):
            humans += 1; S["humans"] += 1
        if typ == "assistant":
            m = r.get("message", {})
            a = r.get("attributionSkill")
            if a: skills[a] = skills.get(a, 0) + 1
            if m.get("usage") and m.get("id"):
                usage[m["id"]] = (m.get("model"), m["usage"], t, step)
            for c in m.get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "tool_use": continue
                inp = json.dumps(c.get("input", {}))
                pend[c["id"]] = (c.get("name"), tt, step)
                if c.get("name") in ("Agent", "Task"):
                    owner[c["id"]] = (sess, step, t)
                    rec_by[c["id"]] = (meta or {}).get("toolUseId") if kind == "sub" else None
                if kind == "lead" and c.get("name") == "Bash":
                    ev = gate_event(str((c.get("input") or {}).get("command") or ""))
                    if ev == "open": gate = "gate-validation[" + main + "]"; step = gate
                    elif ev == "close": gate = None; step = main
                mm = STEP_RE.search(inp)
                if mm and c.get("name") == "Read":
                    name = mm.group(1)
                    S["reads"] += 1
                    # A Read with offset/limit of a step file this transcript already read WHOLE
                    # is a re-read of one passage, not entry into that step. A slice of a file
                    # not yet read whole (gate-validation is read in slices on entry) still enters.
                    isslice = "offset" in c.get("input", {}) or "limit" in c.get("input", {})
                    sliced = isslice and name in whole
                    if not isslice: whole.add(name)
                    if name not in SUBPROC and not sliced:
                        if name == "gate-validation":
                            step = gate or "gate-validation[" + main + "]"
                        else:
                            main = name
                            if gate is None: step = name
        elif typ == "user":
            c = r.get("message", {}).get("content")
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_result":
                        p = pend.pop(x.get("tool_use_id"), None)
                        b = rbytes(x.get("content"))
                        S["tool_bytes"] += b
                        if p:
                            fh["tools"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=p[2], tool=p[0],
                                lat=round(tt - p[1], 2), bytes=b, sprint=sprint_of(t))) + "\n")
        elif typ == "attachment":
            a = r.get("attachment", {})
            if a.get("type") in ("hook_success", "hook_additional_context", "hook_non_blocking_error", "hook_blocking_error"):
                b = len((a.get("content") if isinstance(a.get("content"), str) else json.dumps(a.get("content") or "")).encode())
                if a.get("type") == "hook_additional_context": S["hook_bytes"] += b
                cmd = a.get("command") or a.get("hookName")
                fh["hooks"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=step, att=a["type"],
                    hook=os.path.basename(str(cmd).split()[-1].strip('"')) if a.get("command") else a.get("hookName"),
                    event=a.get("hookEvent"), ms=float(a.get("durationMs") or 0), bytes=b, sprint=sprint_of(t))) + "\n")
        if K: K.record(r, typ)
        prev_type = typ
    if first is None: return
    if K: K.write(unit, sess, usage, segs)
    tok = {}
    for mid, (model, u, t, s) in usage.items():
        k = (s, model)
        d = tok.setdefault(k, [0, 0, 0, 0, 0])
        d[0] += u.get("input_tokens", 0) or 0
        d[1] += u.get("cache_creation_input_tokens", 0) or 0
        d[2] += u.get("cache_read_input_tokens", 0) or 0
        d[3] += u.get("output_tokens", 0) or 0
        d[4] += 1
    for (s, model), d in tok.items():
        S = seg(s); S.setdefault("tok", {})[model or "?"] = d
    fh["units"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, first=first, last=last,
        sprint=sprint_of(first), compactions=compactions, humans=humans, skills=skills, meta=meta,
        tok={f"{s}|{m}": d for (s, m), d in tok.items()})) + "\n")
    for s, S in segs.items():
        if S["first"] is None: continue
        fh["segs"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=s, sprint=sprint_of(S["first"]), **S)) + "\n")

def last_ts(path):
    """Timestamp of the last timestamped record in the file, read from its tail. None if there is none."""
    with open(path, "rb") as f:
        f.seek(0, 2); size = f.tell(); n = 1 << 16
        while True:
            f.seek(max(0, size - n)); chunk = f.read().decode("utf-8", "replace")
            for line in reversed(chunk.splitlines()):
                try: t = json.loads(line).get("timestamp")
                except Exception: continue
                if t: return t
            if n >= size: return None
            n *= 4

def in_window(p):
    # Selected by the in-file timestamp window, never by mtime: a copied or touched file keeps its records.
    t = last_ts(p)
    return t is None or t >= WIN_START

leads = [p for p in glob.glob(ROOT + "/*.jsonl") if in_window(p)]
subs = [p for p in glob.glob(ROOT + "/*/subagents/*.jsonl") if in_window(p)]
print("leads", len(leads), "subs", len(subs), file=sys.stderr)
for p in sorted(leads): scan(p, "lead", None)
for i, p in enumerate(sorted(subs)):
    mp = p[:-6] + ".meta.json"
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    scan(p, "sub", meta)
    if i % 200 == 0: print("sub", i, file=sys.stderr)
for k in list(owner):
    seen = {k}; cur = k
    while owner[k][1] == "pre-step" and rec_by.get(cur) and rec_by[cur] in owner and rec_by[cur] not in seen:
        cur = rec_by[cur]; seen.add(cur)
        owner[k] = (owner[k][0], owner[cur][1], owner[k][2])
        if rec_by.get(cur) is None: break
json.dump({k: list(v) for k, v in owner.items()}, open(os.path.join(OUT, "owner.json"), "w"))
for f in fh.values(): f.close()
cfh.close()
print("done", file=sys.stderr)
