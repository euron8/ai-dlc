#!/usr/bin/env bash
set -euo pipefail

# audit-rule-files.sh — the mechanical half of retro's rule-file audit
# (steps/retro.md Step 4). Detection is deterministic and belongs in a script;
# disposition is the lead's and stays in the retro.
#
# usage:
#   audit-rule-files.sh              # audit the repo rooted at $PWD
#   audit-rule-files.sh --list       # print the scan corpus and exit 0
#
# exit 0 = every mechanized scan clean
# exit 1 = at least one finding
# exit 2 = usage or environment error
#
# Scans reported:
#   Class 1   narrative drift        (Rule 18)
#   Class 1b  incomplete Rule 26(c) triple
#   Class 2   rule weakness          (Rule 18)
#   Class 3   complexity accretion   — NOT MECHANIZED, always DID-NOT-RUN
#   Pointers  relocation-pointer resolution (retro.md invariant 1)
#   Dormancy  path-filter dormancy of CI jobs
#
# Class 3 prints DID-NOT-RUN rather than CLEAN on purpose. It requires the
# catch/false-positive history of each gate, which no static scan holds; a
# CLEAN there would be a check that cannot fire reporting as one that passed.

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  ""|--list) ;;
  *) echo "usage: audit-rule-files.sh [--list]" >&2; exit 2 ;;
esac
command -v python3 >/dev/null 2>&1 || { echo "audit-rule-files: FAIL — python3 required" >&2; exit 2; }

MODE="${1:-audit}"
export AUDIT_MODE="$MODE"

# `gh` is resolved here, not in python, so an absent binary is reported as
# SKIPPED-with-reason instead of silently scoring the dormancy scan clean.
if command -v gh >/dev/null 2>&1; then export AUDIT_HAVE_GH=1; else export AUDIT_HAVE_GH=0; fi

python3 - "$SELF_DIR" <<'PY'
import os, re, subprocess, sys, glob

MODE = os.environ.get("AUDIT_MODE", "audit")
HAVE_GH = os.environ.get("AUDIT_HAVE_GH") == "1"
SKILL = ".claude/skills/ai-dlc"

def tree(root):
    out = []
    for dirpath, _, names in os.walk(root):
        for n in sorted(names):
            if n.endswith(".md"):
                out.append(os.path.join(dirpath, n))
    return sorted(out)

# Scan corpus. The layer directories are NOT an afterthought: Rule 27 forbids a
# consumer to hand-edit core, so a corpus naming only core scans exactly the
# text the consumer cannot author and stays silent on all the text it does.
corpus = []
for p in ("CLAUDE.md", "docs/coding-conventions.md", f"{SKILL}/SKILL.md"):
    if os.path.isfile(p):
        corpus.append(p)
for root in (f"{SKILL}/steps", ".claude/team-roles",
             f"{SKILL}/extensions", f"{SKILL}/overrides"):
    corpus.extend(tree(root))
corpus = [p for p in dict.fromkeys(corpus) if os.path.isfile(p)]

if MODE == "--list":
    for p in corpus:
        print(p)
    sys.exit(0)

if not corpus:
    sys.stderr.write(
        "audit-rule-files: FAIL — scan corpus is empty. Run from the repo root of an\n"
        "  installed project. An empty corpus would report every class CLEAN by\n"
        "  scanning nothing, which is the failure this refuses to perform.\n")
    sys.exit(2)

findings = 0
print("=== Rule File Audit ===")
print(f"corpus: {len(corpus)} files")
print()

def emit(label, hits, total_note=""):
    """One class result. An enumerated n=[...] is the evidence; a bare CLEAN is not."""
    global findings
    for f, ln, msg in hits:
        print(f"  {f}:{ln}  {label}  {msg}")
    enum = ",".join(f"{f}:{ln}" for f, ln, _ in hits)
    verdict = "CLEAN" if not hits else "FLAGGED"
    print(f"  {label}: {verdict}  n=[{enum}]  (of {len(corpus)} files scanned){total_note}")
    findings += len(hits)
    print()

def lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read().split("\n")
    except OSError:
        return []

QUOTED = re.compile(r"`[^`]*`|\"[^\"]*\"|'[^']{2,}'")

def used(text):
    """Blank out quoted spans. A phrase inside quotes or backticks is being
    MENTIONED, not used — the line that defines narrative drift by listing
    '"because we" justification' is the audit's own spec, not a violation of it.
    Measured: without this, every class scored its own definition site and the
    rule-weakness class returned 5 hits, all false."""
    return QUOTED.sub(lambda m: " " * len(m.group(0)), text)

def scannable(path):
    """Yield (lineno, text) skipping fenced code, HTML comments and frontmatter —
    a rule audit judges rule prose, and a regex that reads a code block scores
    the machinery as the drift it is meant to find."""
    src = lines(path)
    in_fence = False
    in_fm = src[:1] == ["---"]
    for i, raw in enumerate(src, 1):
        s = raw.strip()
        if in_fm:
            if i > 1 and s == "---":
                in_fm = False
            continue
        if s.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or s.startswith("<!--") or s.startswith("#"):
            continue
        yield i, raw

# ---------------------------------------------------------------- Class 1
# Narrative drift: rule text carrying the story of its own origin.
print("--- Class 1: Narrative Drift ---")
NARRATIVE = re.compile(
    r"(because we\b|got burned|after the .{0,40}incident|when we found|learned that\b)", re.I)
hits = [(p, n, t.strip()) for p in corpus for n, t in scannable(p)
        if NARRATIVE.search(used(t))]
emit("NARRATIVE_DRIFT", hits)

# --------------------------------------------------------------- Class 1b
# A Rule 26(c) block that opens "Failure caught:" and supplies neither of the
# other two fields is the middle ground Rule 18 exists to close, and Class 1's
# colloquial-phrase regex cannot see it. Section-scoped, not line-scoped: these
# blocks wrap mid-word across lines ("False-\npositive cost:"), so a per-line
# regex reports a complete triple as incomplete.
print("--- Class 1b: Incomplete Rule 26(c) Triple ---")
FP = re.compile(r"false[-\s]*positive", re.I)
RM = re.compile(r"removal\s+condition|retired?s?\s+when|removed?\s+when|drop\s+this\s+gate\s+once", re.I)
hits = []
for p in corpus:
    src = lines(p)
    buf, fc_line, fc_text = [], None, None
    def flush():
        global hits
        if fc_line is not None:
            blob = " ".join(buf)
            if not (FP.search(blob) and RM.search(blob)):
                hits.append((p, fc_line, fc_text.strip()))
    for i, raw in enumerate(src, 1):
        if raw.startswith("#"):
            flush(); buf, fc_line, fc_text = [], None, None
            continue
        if "Failure caught:" in raw and fc_line is None:
            fc_line, fc_text = i, raw
        buf.append(raw)
    flush()
emit("INCOMPLETE_26C", sorted(hits))

# ---------------------------------------------------------------- Class 2
# Rule weakness: soft language inside a line that is trying to mandate.
print("--- Class 2: Rule Weakness ---")
SOFT = re.compile(r"\b(should|try to|consider|prefer|in most cases|when possible|ideally)\b", re.I)
MANDATE = re.compile(r"(MUST|SHALL|mandate|enforce|require|violation|gate.FAIL)")
# `should not`/`should never` are mandates in the negative, not soft language.
# `Do NOT try to` likewise. A rule saying something is NOT a mandate is exempt.
EXEMPT = re.compile(r"(should (be|not|never|contain)|the user should|"
                    r"(do not|don't|never) (try to|consider|prefer)|not a .{0,20}mandate)", re.I)
hits = [(p, n, "soft language near mandate: " + t.strip())
        for p in corpus for n, t in scannable(p)
        if SOFT.search(used(t)) and MANDATE.search(used(t)) and not EXEMPT.search(t)]
emit("RULE_WEAKNESS", hits)

# ---------------------------------------------------------------- Class 3
print("--- Class 3: Complexity Accretion ---")
print("  COMPLEXITY_ACCRETION: DID-NOT-RUN  n=[]  (reason=needs each gate's")
print("    catch/false-positive history since introduction, which no static scan")
print("    holds. Lead-dispositioned in retro Step 4; a CLEAN here would be a")
print("    check that cannot fire reporting as one that passed.)")
print()

# --------------------------------------------------------------- Pointers
# Invariant 1: every pointer to skill-loadable content resolves to a live file.
print("--- Relocation-pointer resolution ---")
POINTER = re.compile(
    r"(?:READ AND FOLLOW|lives in|defined in|canonical(?:\s+\w+){0,3}\s+in|schema in|see)\s+`([^`]+)`",
    re.I)
# Runtime artifacts and project files exist only in an installed project, not in
# the skill source. Flagging them would fail every clean tree.
OUT_OF_SCOPE = re.compile(
    r"^(_bmad-output/|docs/|CLAUDE\.md$|prd\.md$|product-brief\.md$|carry-over-backlog\.md$|"
    r"gate-log|pipeline-snapshot|compaction-log\.md$|audit-anchors\.md$)")
IN_SCOPE = re.compile(r"^(steps/|schemas/|team-roles/|"
                      r"rule-authoring\.md$|escalations\.md$|core-manifest\.md$|"
                      r"enforcement-map\.yaml$|research-citations\.md$|escalations\.md$)")

def resolve(target):
    """A pointer's path is skill-dir-relative; team-roles/ resolves outside it."""
    if target.startswith("team-roles/"):
        return [f".claude/{target}"]
    if target.startswith("schemas/"):
        return [f".claude/{target}", f"{SKILL}/{target}"]
    return [f"{SKILL}/{target}", target]

sources = [p for p in corpus if p.startswith(f"{SKILL}/")]
hits = []
for p in sources:
    for n, t in scannable(p):
        for m in POINTER.finditer(t):
            tgt = m.group(1).strip().split("#")[0].strip()
            if not tgt or " " in tgt or not tgt.endswith((".md", ".json", ".yaml", ".sh")):
                continue
            if OUT_OF_SCOPE.match(tgt) or not IN_SCOPE.match(tgt):
                continue
            if not any(os.path.isfile(c) for c in resolve(tgt)):
                hits.append((p, n, f"dangling skill-content pointer -> {tgt}"))
emit("DANGLING_POINTER", hits, f"  [{len(sources)} skill files searched]")

# --------------------------------------------------------------- Dormancy
# Path-filter dormancy: a CI job gated behind paths:/paths-ignore: that has not
# actually run on main for ≥3 sprints is enforcement nobody is paying for.
print("--- Path-filter dormancy ---")
wf = sorted(glob.glob(".github/workflows/*.yml") + glob.glob(".github/workflows/*.yaml"))
if not os.path.isdir(".github/workflows"):
    print("  PATH_DORMANCY: N/A  n=[]  (reason=no .github/workflows/ — a script-based")
    print("    consumer runs validators directly; an empty workflow set is the")
    print("    expected state, not a dormancy finding)")
elif not wf:
    print("  PATH_DORMANCY: N/A  n=[]  (reason=.github/workflows/ holds no workflow files)")
elif not HAVE_GH:
    print(f"  PATH_DORMANCY: SKIPPED  n=[]  (reason=`gh` not on PATH; {len(wf)} workflow")
    print("    file(s) carry path filters that went unchecked. This is an unrun scan,")
    print("    NOT a clean one — install `gh` or record the gap in the retro.)")
else:
    filtered = []
    for f in wf:
        body = "\n".join(lines(f))
        if re.search(r"^\s*paths(-ignore)?\s*:", body, re.M):
            filtered.append(f)
    dormant = []
    for f in filtered:
        try:
            out = subprocess.run(
                ["gh", "run", "list", "--workflow", os.path.basename(f),
                 "--branch", "main", "--limit", "30"],
                capture_output=True, text=True, timeout=60).stdout
        except Exception as e:                      # noqa: BLE001 — report, never swallow
            dormant.append((f, 0, f"gh run list failed: {e}"))
            continue
        ran = [l for l in out.splitlines() if l.strip() and "skipped" not in l.lower()]
        if not ran:
            dormant.append((f, 0, "zero non-SKIPPED runs on main in the last 30"))
    if not filtered:
        print(f"  PATH_DORMANCY: CLEAN  n=[]  (of {len(wf)} workflows; none use path filters)")
        print()
    else:
        emit("PATH_DORMANCY", dormant, f"  [{len(filtered)} path-filtered workflow(s)]")

sys.exit(1 if findings else 0)
PY
