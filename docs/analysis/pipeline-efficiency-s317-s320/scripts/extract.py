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
    opens a gate labelled gate-validation[M], M being main at the open. While the lead is IN the gate,
    gate-validation reads keep that label and a read of another step moves main but not step, with one exception:
    a WHOLE read (no offset, no limit) of a step file S that is not gate-validation, not _gate-procedures or
    _dispatch-protocol (any name starting with an underscore), and S != M LEAVES the gate. That read ends the span:
    step = main = S. Once the gate's terminal verdict is recorded (gate-checkpoint.sh ... record 26 PASS; a FAIL
    re-dispatches the gate and does not count), a SLICED read of such a step file S leaves it as well; until then a
    slice of S moves main only. The gate stays remembered, so a later gate-validation read (sliced or whole) before any new
    open/close RETURNS to it under the same label, not one recomputed from the new main. A new open replaces the
    remembered gate; gate-checkpoint.sh ... close clears it and sets step = main (also when no gate was open).
    gate-checkpoint.sh ... done is a post-compaction read-back inside a live gate and does not end the span, and a
    gate-checkpoint.sh record, done or list after leaving RETURNS to the gate like a gate-validation read. A gate
    opened before any step was entered (M = pre-step) is never left. The recover hook applies the same rule.
    With no open ever seen, behaviour is the plain read-driven rule. Per sprint, the opens, closes, opens with no
    close (replaced by a later open or still open at the end of the scan) and LEFT events are printed to stderr as
    "gate-terminator sprint=N opens= closed= unclosed= left=" lines.
"""
import json, os, re, sys, glob, bisect, datetime as dt

ROOT = os.environ.get("EXTRACT_ROOT") or os.path.expanduser("~/.claude/projects/-Users-n8-git-graph")
OUT = sys.argv[1]
# WIN_START is a parameter: argv[2], else $EXTRACT_WIN_START, else just after graph's s313 close
# (commit 6a4469196, 2026-09-25T20:31-04:00), so s314 onward is selected. Records before it are dropped.
WIN_START = (sys.argv[2] if len(sys.argv) > 2 else os.environ.get("EXTRACT_WIN_START")) or "2026-09-26T00:35:00Z"
# WIN_END pins a snapshot: argv[3], else $EXTRACT_WIN_END, else unbounded. A record whose timestamp is LATER
# than it is dropped, compared as an instant (not as a string, so fractional seconds order correctly).
WIN_END = (sys.argv[3] if len(sys.argv) > 3 else os.environ.get("EXTRACT_WIN_END")) or None
# The segs interval is measured on a MONOTONE clock, as Classer.interval() does: an out-of-order record charges 0
# and does not move the clock back. This is the DEFAULT. EXTRACT_MONOTONE_SEGS=0 selects the old clock (prev_t =
# this record) so a committed pre-BL-1174 output can be reproduced byte for byte. The old clock overstates: s323's
# transcripts replay a burst of `attachment` records stamped BEFORE an operator pause after the record that ends
# it, and it counts the one pause once per replayed record (lead 68cf8de7: a 4.73 h pause read as 75 h).
MONOTONE_SEGS = os.environ.get("EXTRACT_MONOTONE_SEGS") != "0"
# BL-1174 corrections. Each has its own switch, ON by default; with all six OFF (EXTRACT_EDGES=hand, the others 0,
# including EXTRACT_SPLIT_SEGS=0; run as `EXTRACT_WIN_END=2026-11-20T04:20:00Z EXTRACT_EDGES=hand EXTRACT_RELABEL=0 EXTRACT_OPWAIT=0 EXTRACT_FORK_DEDUPE=0 EXTRACT_IDLE_TAIL=0 EXTRACT_SPLIT_SEGS=0`)
# the output is byte-identical to the pre-correction extractor.
# EXTRACT_EDGES: `derived` (default) takes each sprint's end from graph's first-parent log and the lead transcripts
# (see derive_edges()); `hand` selects the hand-kept EDGES list below. Derivation failure exits 2, never falls back.
EDGES_MODE = os.environ.get("EXTRACT_EDGES", "derived")
# EXTRACT_EDGE_GAP (seconds): a derived edge is the last record before the first gap longer than this in the lead
# active at the close commit, counted from the last record at or before the close.
EDGE_GAP_DEFAULT = 1800   # seconds: 30 min
EDGE_GAP = float(os.environ.get("EXTRACT_EDGE_GAP") or EDGE_GAP_DEFAULT)
GRAPH_REPO = os.environ.get("EXTRACT_GRAPH_REPO") or "/Users/n8/git/graph"
# EXTRACT_RELABEL: lead step labels follow the pipeline's own declarations (snapshot-update.sh --set current_step_file,
# an edit of pipeline-snapshot.md, gate nonce spans, the planning-gate close that advances to the next step); the
# step-file read rule stays as the fallback, and a read of an EARLIER step after a declaration does not move the label
# back. 0 keeps the read rule alone. Only moves elapsed time and tokens between steps.
RELABEL = os.environ.get("EXTRACT_RELABEL") != "0"
# EXTRACT_OPWAIT: operator wait covers the WHOLE span of an AskUserQuestion (tool_use to tool_result, every gap in it,
# not only those over 300 s) and the span from a touch of pipeline-paused.flag to the next human prompt. Moves time
# from active / agent wait to operator wait; the elapsed total is unchanged.
OPWAIT = os.environ.get("EXTRACT_OPWAIT") != "0"
# EXTRACT_FORK_DEDUPE: a lead record whose uuid is already in an EARLIER-STARTED lead transcript (a forked session
# replays its parent's records) is read for state but charged nothing; leads are scanned in first-record order.
FORK_DEDUPE = os.environ.get("EXTRACT_FORK_DEDUPE") != "0"
# EXTRACT_IDLE_TAIL: a gap over 300 s after a lead's last tool_use record, outside an AskUserQuestion span, is not
# charged (the session sits idle after its work ended).
IDLE_TAIL = os.environ.get("EXTRACT_IDLE_TAIL") != "0"
# EXTRACT_SPLIT_SEGS: a segment is keyed by (step, sprint of the RECORD), so one that crosses a sprint edge becomes one
# row per sprint, tokens and class rows split alike. 0 keys by step alone: the row takes the sprint of its first record,
# and a lead's tail after the edge stays in the sprint that segment opened in.
SPLIT_SEGS = os.environ.get("EXTRACT_SPLIT_SEGS") != "0"
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
         ("2026-10-30T00:10:03Z",320),("2026-11-09T00:00:00Z",321),("2026-11-13T08:00:00Z",322),("2026-11-20T04:20:00Z",323),
         ("2099-01-01T00:00:00Z",324)]
# s321 ends at the lead-session handover: s321's last lead df56108b (retro merge ec443477d at
# 2026-11-08T20:23Z, then the close sweep) has its last record at 2026-11-08T21:47:01.989Z; the s322 lead
# 6c14d949 (/ai-dlc "Finish Epic 5") opens at 2026-11-09T00:00:37.657Z. The spawn ledger agrees: last s321
# row 2026-11-08T20:30:46Z, first s322 row 2026-11-09T00:20:57Z.
# s323 ends at 2026-11-20T04:20:00Z, after the last s323 record. The s323 close is two commits, not one: 16fd227d9
# "finalize snapshot - sprint 323 closed" (2026-11-19T23:00:40-05:00 = 04:00:40Z) and a9b015557 "7b next-inputs
# bundle and 7d handoff snapshot - sprint 323 closed" (23:13:06-05:00 = 04:13:06Z, pushed 04:17:24Z), the last
# s323 commit on graph's main. Lead 64926214, s323's last lead, runs to 04:17:36.019Z (its final message confirms the
# a9b015557 push and the pipeline paused); its last subagent record is 04:09:53Z and the spawn ledger's last
# s323 row is 04:08:52Z. No transcript and no ledger row is stamped after 04:17:36Z, so there is no s324 lead
# record to bound the edge from above (s324 has not started); 04:20:00Z sits after the last record. An edge at
# 16fd227d9 plus a few minutes (04:05Z) would put the lead's closing 7b/7d work and three subagents' records
# (04:05:12Z to 04:09:53Z) into s324.
EDGE_CMP = None   # derived edges: [(instant, sprint)] in order; set by derive_edges() before any scan
_TS_CACHE = {}
def sprint_of(t):
    if t < WIN_START: return None
    if EDGE_CMP is not None:
        x = _TS_CACHE.get(t)
        if x is None:
            if len(_TS_CACHE) > 400000: _TS_CACHE.clear()
            x = _TS_CACHE[t] = ts(t)
        for e, n in EDGE_CMP:
            if x < e: return n
        return None
    for e, n in EDGES:
        if t < e: return n

# Step order, the planning successor and the nonce-overridden steps for RELABEL (port of build_true.py's relabel()).
STEP_ORDER = {"route": 0, "carry-over-evaluation": 1, "requirements": 2, "architecture": 3, "ui-direction": 3.5,
              "stories-test-strategy": 4, "implementation": 5, "sprint-review": 6, "deploy-validate": 7, "retro": 8, "handoff": 9}
PLAN_SUCC = {"carry-over-evaluation": "requirements", "requirements": "architecture", "architecture": "stories-test-strategy",
             "stories-test-strategy": "implementation"}
NONCE_OVR = {"implementation", "sprint-review", "deploy-validate", "retro"}
SET_RE = re.compile(r"--set\s+[\"']?current_step_file[\"']?\s+[\"']?([\w./-]+)")
SNAPLINE_RE = re.compile(r"^[ \t]*(?:[-*][ \t]+)?(?:\*\*)?`?current_step_file`?(?:\*\*)?[ \t]*[:=][ \t]*`?([\w./-]+)", re.M)

def step_name(v):
    v = os.path.basename(v)
    return v[:-3] if v.endswith(".md") else v

def nonce_prefix(cmd):
    m = re.search(r"--nonce\s+[\"']?([^\s\"']+)", cmd)
    if not m: return None
    n = m.group(1)
    if n.startswith("$"):
        m2 = re.search(r"NONCE=[\"']?([a-z][a-z-]*?)-(?:\$|\d)", cmd)
        return m2.group(1) if m2 else None
    m3 = re.match(r"([a-z][a-z-]*?)-\d{8}T", n)
    return m3.group(1) if m3 else None

def gate_kind(cmd):
    """'open' / 'close' for a gate-checkpoint.sh invocation (first segment after the script name)."""
    i = cmd.find("gate-checkpoint.sh")
    if i < 0: return None
    w = re.split(r"[;&|\n]", cmd[i:])[0].split()
    if "close" in w: return "close"
    if "open" in w: return "open"
    return None

class Rel:
    """RELABEL state of one lead: the corrected main step `tm`, ahead of the read rule's main after a declaration."""
    def __init__(self):
        self.tm = "pre-step"; self.omn = "pre-step"; self.ahead = False; self.gp = None; self.gprefix = None
        self.gateM = None; self.closed = set()
    def cur(self): return self.gp or self.tm
    def label(self, oldgate):
        return "gate-validation[" + self.cur() + "]" if (oldgate or self.gp is not None) else self.tm
    def update(self, omn, cmds, bs):
        """Advance past one record. omn is the read rule's main AFTER the record; cmds are the record's
        ("Bash", command) and ("Snap", new snapshot text) tool inputs; bs(src) counts a label change by source."""
        b = self.cur()
        if omn != self.omn:
            si, ti = STEP_ORDER.get(omn), STEP_ORDER.get(self.tm)
            if self.ahead and si is not None and ti is not None and si < ti: pass
            else: self.tm = omn; self.ahead = False
            self.omn = omn
            if self.cur() != b: bs("inferred"); b = self.cur()
        oi, ti = STEP_ORDER.get(self.omn), STEP_ORDER.get(self.tm)
        if self.ahead and oi is not None and ti is not None and oi >= ti: self.ahead = False
        def declare(v):
            nonlocal b
            if v in STEP_ORDER and v != self.tm:
                self.tm = v; self.gp = None
                oi = STEP_ORDER.get(self.omn); self.ahead = oi is not None and oi < STEP_ORDER[v]
                if self.cur() != b: bs("declared"); b = self.cur()
        for kind, text in cmds:
            if kind == "Snap":
                for m in SNAPLINE_RE.finditer(text): declare(step_name(m.group(1)))
                continue
            s = strip_heredocs(text)
            if "snapshot-update.sh" in s:
                for m in SET_RE.finditer(s): declare(step_name(m.group(1)))
            gk = gate_kind(s)
            nn = re.search(r"--nonce\s+[\"']?(\w[\w-]*\d{8}T\d{6}Z)", s)
            if nn and nn.group(1) in self.closed: gk = None if gk != "close" else gk
            elif nn and gk is None and self.gp is None:
                pf = nonce_prefix(s)
                ti = STEP_ORDER.get(self.tm)
                if pf == "implementation" and ti is not None and ti > STEP_ORDER["implementation"] and "gate-checkpoint.sh" in s:
                    self.gp = pf; self.gprefix = pf; self.gateM = self.tm
                    if self.cur() != b: bs("declared"); b = self.cur()
            if gk == "open":
                self.gateM = self.tm; self.gprefix = nonce_prefix(s)
                self.gp = self.gprefix if (self.gprefix in NONCE_OVR and self.gprefix != self.tm) else None
                if self.cur() != b: bs("declared"); b = self.cur()
            elif gk == "close":
                if nn: self.closed.add(nn.group(1))
                self.gp = None
                if self.cur() != b: bs("declared"); b = self.cur()
                ti = STEP_ORDER.get(self.tm)
                if self.gprefix == "planning" and self.gateM in PLAN_SUCC and ti is not None and ti < STEP_ORDER[PLAN_SUCC[self.gateM]]:
                    self.tm = PLAN_SUCC[self.gateM]
                    oi = STEP_ORDER.get(self.omn); self.ahead = oi is not None and oi < STEP_ORDER[self.tm]
                    if self.cur() != b: bs("declared"); b = self.cur()
                self.gprefix = None

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
    """'open' / 'close' / 'terminal' / 'verb' / None for the INVOCATIONS of the gate scripts in a Bash command
    (heredoc bodies stripped, script name in command position of a pipeline / ; / && segment, after optional
    bash/sh/env and VAR=x words). 'verb' is a gate-checkpoint.sh record, done or list with no open or close in the
    command; 'terminal' is such a verb that records the terminal verdict, `record 26 PASS`."""
    ev = None; verb = False; terminal = False
    for seg_ in re.split(r"\|\||&&|[|;&\n]", strip_heredocs(cmd)):
        w = [x.strip("\"'") for x in seg_.split()]
        while w and (w[0] in ("bash", "sh", "env") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])): w = w[1:]
        if not w: continue
        base = os.path.basename(w[0]); args = w[1:]
        if base == "gate-checkpoint.sh":
            if "close" in args: ev = "close"
            elif "open" in args: ev = "open"
            elif any(a in args for a in ("record", "done", "list")):
                verb = True
                # the terminal verdict: record 26 PASS (FAIL_WAIVED is checkpointed PASS; a FAIL re-dispatches the gate)
                i = args.index("record") if "record" in args else -1
                if i >= 0 and args[i + 1:i + 3] == ["26", "PASS"]: terminal = True
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
    return ev or ("terminal" if terminal else "verb" if verb else None)

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

    def interval(self, step, tt, mode=None):
        # mode follows what scan() charged segs for this record: None the 300 s split, "g" the gap slot whatever the
        # size (an operator span), "x" nothing (a fork copy or an idle tail). The clock moves in every case.
        if self.clk is not None and mode != "x":
            d = max(0.0, tt - self.clk)
            self.iv.setdefault((step, self.key), [0.0, 0.0])[1 if (mode == "g" or d > 300) else 0] += d
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
            cfh.write(json.dumps(dict(unit=unit, sess=sess, kind="lead", step=s[0], cls=k,
                                      sprint=sprint_of(segs[s]["first"]), **R)) + "\n")

GATE_EV = []   # (sprint, "open" | "closed" | "unclosed" | "left"), lead scans only

BSRC = {}      # sprint -> {"declared": n, "inferred": n}: RELABEL label changes by source, lead scans only
PRIOR = set()  # uuids of the lead transcripts scanned so far (FORK_DEDUPE)
PRE = {}       # lead path -> prescan() result

def scan(path, kind, meta):
    usage = {}           # message.id -> (model, usage, ts, step)
    step = "pre-step"; main = "pre-step"
    gate = None          # label of the gate segment the lead is IN (lead scans only)
    glabel = None        # label of the last opened, never closed gate; stays set after the lead leaves it
    gmain = None         # main at the open of glabel
    gopen = None         # timestamp of that open
    garmed = False       # glabel's terminal verdict is recorded (record 26 PASS): a SLICED read of another step leaves too
    whole = set()        # step files this transcript has read without offset/limit
    segs = {}            # step -> dict
    pend = {}            # tool_use_id -> (name, ts, step)
    first = last = None; prev_t = None; prev_type = None
    sess = os.path.basename(os.path.dirname(os.path.dirname(path))) if kind == "sub" else os.path.basename(path)[:-6]
    unit = os.path.basename(path)[:-6]
    compactions = 0; humans = 0; skills = {}
    K = Classer() if kind == "lead" else None
    def seg(s):   # s is the segment key (step, sprint or None)
        return segs.setdefault(s, dict(first=None, last=None, active=0.0, op_wait=0.0, agent_wait=0.0,
                                       reads=0, compactions=0, humans=0, tool_bytes=0, hook_bytes=0, lines=0, gap=0.0))
    lead = kind == "lead"
    pre = PRE.get(path) if lead else None
    rel = Rel() if (RELABEL and lead) else None
    rlab = "pre-step"    # the corrected label the NEXT record is charged to (RELABEL)
    def ST():            # the label this record is charged to
        return rlab if rel is not None else step
    ri = -1; mine = []
    for line in open(path, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t or t < WIN_START: continue
        tt = ts(t)
        if WIN_END_TS is not None and tt > WIN_END_TS: continue
        ri += 1
        dup = False
        if lead and FORK_DEDUPE:
            u = r.get("uuid")
            if u:
                dup = u in PRIOR; mine.append(u)
        if not dup:
            first = first or t; last = t
        typ = r.get("type")
        kk = (ST(), sprint_of(t) if SPLIT_SEGS else None)
        S = seg(kk) if not dup else dict(first=None, last=None, active=0.0, op_wait=0.0, agent_wait=0.0, reads=0,
                                           compactions=0, humans=0, tool_bytes=0, hook_bytes=0, lines=0, gap=0.0)
        S["lines"] += 1
        S["first"] = S["first"] or t; S["last"] = t
        mode = None
        if prev_t is not None:
            gap = max(0.0, tt - prev_t)
            ask = any(v[0] == "AskUserQuestion" for v in pend.values())
            inpause = OPWAIT and pre is not None and ri in pre["op"]
            force = OPWAIT and (ask or inpause)
            if dup or (IDLE_TAIL and pre is not None and ri > pre["lt"] and gap > 300 and not ask):
                mode = "x"    # not charged
            else:
                # "gap" is the time between consecutive records that exceeds 300 s, or any time inside an operator
                # span (EXTRACT_OPWAIT). It is charged to op_wait or agent_wait below AND recorded here on its own,
                # so op_wait + agent_wait == gap. Hours built from active + op_wait + agent_wait are therefore
                # gap-inclusive.
                if gap <= 300 and not force: S["active"] += gap
                else:
                    S["gap"] += gap
                    if gap <= 300: mode = "g"
                if gap <= 300 and not force: pass
                # EXTRACT_OPWAIT: a compaction summary is a user text record but not an operator prompt; its gap is agent wait.
                elif (typ == "user" and human_prompt(r) and not (OPWAIT and r.get("isCompactSummary"))) or ask or inpause: S["op_wait"] += gap
                else: S["agent_wait"] += gap
        prev_t = max(prev_t, tt) if (MONOTONE_SEGS and prev_t is not None) else tt
        if K: K.interval(kk, tt, mode)
        if r.get("isCompactSummary") and not dup:
            compactions += 1; S["compactions"] += 1
        if human_prompt(r) and not dup:
            humans += 1; S["humans"] += 1
        rcmds = []
        if typ == "assistant":
            m = r.get("message", {})
            a = r.get("attributionSkill")
            if a: skills[a] = skills.get(a, 0) + 1
            if m.get("usage") and m.get("id") and not dup:
                usage[m["id"]] = (m.get("model"), m["usage"], t, kk)
            for c in m.get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "tool_use": continue
                inp = json.dumps(c.get("input", {}))
                pend[c["id"]] = (c.get("name"), tt, ST())
                if c.get("name") in ("Agent", "Task") and not dup:
                    owner[c["id"]] = (sess, ST(), t)
                    rec_by[c["id"]] = (meta or {}).get("toolUseId") if kind == "sub" else None
                if rel is not None:
                    ci = c.get("input") or {}
                    if not isinstance(ci, dict): ci = {}
                    if c.get("name") == "Bash": rcmds.append(("Bash", str(ci.get("command") or "")))
                    elif c.get("name") in ("Edit", "Write", "MultiEdit") and str(ci.get("file_path") or "").endswith("pipeline-snapshot.md"):
                        rcmds.append(("Snap", "\n".join([str(ci.get("new_string") or ""), str(ci.get("content") or "")] +
                                                      [str((e or {}).get("new_string") or "") for e in (ci.get("edits") or []) if isinstance(e, dict)])))
                if kind == "lead" and c.get("name") == "Bash":
                    ev = gate_event(str((c.get("input") or {}).get("command") or ""))
                    if ev == "open":
                        if glabel is not None and not dup: GATE_EV.append((sprint_of(gopen), "unclosed"))
                        glabel = "gate-validation[" + main + "]"; gate = glabel; gmain = main; gopen = t; garmed = False
                        if not dup: GATE_EV.append((sprint_of(t), "open"))
                        step = gate
                    elif ev == "close":
                        if glabel is not None and not dup: GATE_EV.append((sprint_of(gopen), "closed"))
                        gate = None; glabel = None; garmed = False; step = main
                    elif ev in ("verb", "terminal") and glabel is not None:
                        if ev == "terminal": garmed = True
                        if gate is None:
                            gate = glabel; step = gate   # a record, done or list after leaving: back in the gate
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
                    if not (name in SUBPROC or name.startswith("_")) and not sliced:
                        if name == "gate-validation":
                            if glabel is not None: gate = glabel   # back in the gate it left; keep its label
                            step = gate or "gate-validation[" + main + "]"
                        else:
                            leave = gate is not None and (garmed or not isslice) and name != gmain and gmain != "pre-step"
                            main = name
                            if leave:
                                gate = None   # LEFT: a whole read of another step ends the span
                                if not dup: GATE_EV.append((sprint_of(t), "left"))
                            if gate is None: step = name
        elif typ == "user":
            c = r.get("message", {}).get("content")
            if isinstance(c, list):
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_result":
                        p = pend.pop(x.get("tool_use_id"), None)
                        b = rbytes(x.get("content"))
                        S["tool_bytes"] += b
                        if p and not dup:
                            fh["tools"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=p[2], tool=p[0],
                                lat=round(tt - p[1], 2), bytes=b, sprint=sprint_of(t))) + "\n")
        elif typ == "attachment":
            a = r.get("attachment", {})
            if a.get("type") in ("hook_success", "hook_additional_context", "hook_non_blocking_error", "hook_blocking_error"):
                b = len((a.get("content") if isinstance(a.get("content"), str) else json.dumps(a.get("content") or "")).encode())
                if a.get("type") == "hook_additional_context": S["hook_bytes"] += b
                cmd = a.get("command") or a.get("hookName")
                if not dup: fh["hooks"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=ST(), att=a["type"],
                    hook=os.path.basename(str(cmd).split()[-1].strip('"')) if a.get("command") else a.get("hookName"),
                    event=a.get("hookEvent"), ms=float(a.get("durationMs") or 0), bytes=b, sprint=sprint_of(t))) + "\n")
        if K: K.record(r, typ)
        if rel is not None:
            sp = sprint_of(t)
            def bs(src):
                if not dup: BSRC.setdefault(sp, {"declared": 0, "inferred": 0})[src] += 1
            rel.update(main, rcmds, bs)
            rlab = rel.label(step.startswith("gate-validation"))
        prev_type = typ
    if glabel is not None and first is not None: GATE_EV.append((sprint_of(gopen), "unclosed"))
    if lead and FORK_DEDUPE: PRIOR.update(mine)
    if first is None: return
    if K: K.write(unit, sess, usage, segs)
    tok = {}; utok = {}
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
        e = utok.setdefault(f"{s[0]}|{model}", [0, 0, 0, 0, 0])   # units.tok is per step, summed over its sprints
        for i in range(5): e[i] += d[i]
    fh["units"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, first=first, last=last,
        sprint=sprint_of(first), compactions=compactions, humans=humans, skills=skills, meta=meta,
        tok=utok)) + "\n")
    for s, S in segs.items():
        if S["first"] is None: continue
        fh["segs"].write(json.dumps(dict(unit=unit, sess=sess, kind=kind, step=s[0], sprint=sprint_of(S["first"]), **S)) + "\n")

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

def prescan(path):
    """One pass over a lead transcript, in the same record window scan() uses. Returns first / last / n over every
    timestamped record up to WIN_END (no WIN_START clip; the lead's span for derive_edges()), and for the windowed
    records, indexed as scan() indexes them: lt, the index of the last record carrying a tool_use block (IDLE_TAIL),
    and spans, one (indices, touch t, prompt t) per touch of pipeline-paused.flag through the next human prompt that
    is not a compaction summary (OPWAIT; a touch with no later human prompt has none). The module turns spans into op."""
    first = last = None; n = 0; ri = -1; lt = -1; spans = []; buf = []; pending = False; tss = []; t0 = None
    for line in open(path, errors="replace"):
        try: r = json.loads(line)
        except Exception: continue
        t = r.get("timestamp")
        if not t: continue
        tt = ts(t)
        if WIN_END_TS is not None and tt > WIN_END_TS: continue
        n += 1; tss.append(tt)
        if first is None or tt < first[0]: first = (tt, t)
        if last is None or tt >= last[0]: last = (tt, t)
        if t < WIN_START: continue
        ri += 1
        if pending:
            buf.append(ri)
            if human_prompt(r) and not r.get("isCompactSummary"): spans.append((buf, t0, t)); buf = []; pending = False
        c = (r.get("message") or {}).get("content") if r.get("type") == "assistant" else None
        if isinstance(c, list):
            for x in c:
                if not isinstance(x, dict) or x.get("type") != "tool_use": continue
                lt = ri
                cmd = str((x.get("input") or {}).get("command") or "") if x.get("name") == "Bash" else ""
                if "pipeline-paused.flag" in cmd and re.search(r"\btouch\b", cmd):
                    if not pending: t0 = t
                    pending = True
    return dict(first=first, last=last, n=n, lt=lt, spans=spans, ts=sorted(tss))

def edge_iso(x):
    s = dt.datetime.fromtimestamp(x, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    ms = int(round((x - int(x)) * 1000))
    return s + (".%03d" % ms if ms else "") + "Z"

def derive_edges(info):
    """EXTRACT_EDGES=derived. close(N) is the committer time of the LAST first-parent commit on graph's main whose
    subject matches `[Ss]print N closed` or `chore(sN): finalize snapshot`. active(N) is the lead transcript (at least
    3 records) whose first record <= close(N) <= its last record, the one with the latest last record if several.
    edge(N) = min(last record of active(N), first record of the earliest lead starting after close(N)); with no
    active lead, close(N). The open sprint ends at the 2099 sentinel. Exits 2 when git fails or finds no close commit."""
    import subprocess
    def die(m): print("extract.py: EXTRACT_EDGES=derived: " + m, file=sys.stderr); sys.exit(2)
    p = subprocess.run(["git", "-C", GRAPH_REPO, "log", "--first-parent", "main", "--format=%H|%cI|%s"],
                       capture_output=True, text=True)
    if p.returncode != 0: die("git log failed in %s: %s" % (GRAPH_REPO, p.stderr.strip()))
    close = {}
    for ln in p.stdout.splitlines():
        h, ci, subj = ln.split("|", 2)
        m = re.search(r"[Ss]print (\d+) closed", subj) or re.match(r"chore\(s(\d+)\): finalize snapshot", subj)
        if not m: continue
        x = dt.datetime.fromisoformat(ci).timestamp(); n = int(m.group(1))
        if n not in close or x > close[n][0]: close[n] = (x, h)
    if not close: die("no sprint close commit found in %s" % GRAPH_REPO)
    w0 = ts(WIN_START)
    leadsp = [(i["first"][0], i["last"][0], i["ts"]) for i in info.values() if i["n"] >= 3]
    rows = []; cmp_ = []
    for n in sorted(k for k in close if close[k][0] >= w0):
        c, sha = close[n]
        act = [(l, t) for f, l, t in leadsp if f <= c <= l]
        nxt = [f for f, l, t in leadsp if f > c]
        if act:
            la, tl = max(act, key=lambda x: x[0]); nf = min(nxt) if nxt else None
            # the active lead goes quiet: the last record before the first gap over EDGE_GAP seconds, counting from
            # the last record at or before the close; no such gap, the lead's last record
            i = max(0, bisect.bisect_right(tl, c) - 1); e = la; br = "active-lead-last"
            while i + 1 < len(tl):
                if tl[i + 1] - tl[i] > EDGE_GAP: e = tl[i]; br = "gap"; break
                i += 1
            if nf is not None and nf < e: e, br, cm = nf, "next-lead-first", nf
            else: cm = e + 0.001   # the active lead's own last record is still sprint n
        else: e, br, cm = c, "close", c
        rows.append((n, e, sha, br)); cmp_.append((cm, n))
    if not rows: die("no sprint closed inside the window")
    if any(cmp_[i][0] >= cmp_[i + 1][0] for i in range(len(cmp_) - 1)): die("derived edges are not increasing: %r" % (rows,))
    last_n = rows[-1][0]
    rows.append((last_n + 1, ts("2099-01-01T00:00:00Z"), "-", "open-sprint")); cmp_.append((ts("2099-01-01T00:00:00Z"), last_n + 1))
    hand = {n: e for e, n in EDGES}
    with open(os.path.join(OUT, "edges.tsv"), "w") as f:
        f.write("sprint\tedge\tclose_sha\trule\n")
        for n, e, sha, br in rows: f.write("%d\t%s\t%s\t%s\n" % (n, edge_iso(e), sha, br))
    for n, e, sha, br in rows:
        h = hand.get(n)
        print("edge sprint=%d derived=%s hand=%s diff_min=%s" % (n, edge_iso(e), h or "-",
              "%.1f" % ((e - ts(h)) / 60) if h else "-"), file=sys.stderr)
    return cmp_

leads = [p for p in glob.glob(ROOT + "/*.jsonl") if in_window(p)]
subs = [p for p in glob.glob(ROOT + "/*/subagents/*.jsonl") if in_window(p)]
print("leads", len(leads), "subs", len(subs), file=sys.stderr)
if EDGES_MODE not in ("derived", "hand"):
    print("extract.py: EXTRACT_EDGES must be derived or hand", file=sys.stderr); sys.exit(2)
if EDGES_MODE == "derived" or FORK_DEDUPE or IDLE_TAIL or OPWAIT:
    for p in leads: PRE[p] = prescan(p)
if EDGES_MODE == "derived": EDGE_CMP = derive_edges(PRE)
# a pause span marks operator wait only when its human prompt is in the sprint the touch was in (EXTRACT_OPWAIT): the
# prompt that ends a sprint's closing pause, arriving in the next sprint, is not charged back to the closing sprint
for _i in PRE.values():
    _i["op"] = set()
    for _idx, _a, _b in _i["spans"]:
        if sprint_of(_a) == sprint_of(_b): _i["op"].update(_idx)
if FORK_DEDUPE:
    lead_order = sorted(leads, key=lambda p: ((PRE[p]["first"][0] if PRE[p]["first"] else float("inf")), p))
else: lead_order = sorted(leads)
for p in lead_order: scan(p, "lead", None)
for i, p in enumerate(sorted(subs)):
    mp = p[:-6] + ".meta.json"
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    scan(p, "sub", meta)
    if i % 200 == 0: print("sub", i, file=sys.stderr)
gtab = {}
for sp, e in GATE_EV:
    gtab.setdefault(sp, {}).setdefault(e, 0); gtab[sp][e] += 1
for sp in sorted(gtab, key=lambda x: (x is None, x)):
    g = gtab[sp]
    print("gate-terminator sprint=%s opens=%d closed=%d unclosed=%d left=%d" % (
        sp, g.get("open", 0), g.get("closed", 0), g.get("unclosed", 0), g.get("left", 0)), file=sys.stderr)
for sp in sorted(BSRC, key=lambda x: (x is None, x)):
    print("boundary-source sprint=%s declared=%d inferred=%d" % (sp, BSRC[sp]["declared"], BSRC[sp]["inferred"]), file=sys.stderr)
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
