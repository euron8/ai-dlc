#!/usr/bin/env bash
set -euo pipefail

# audit-rule-files.sh — the mechanical half of retro's rule-file audit
# (steps/retro.md Step 4). Detection is deterministic and belongs in a script;
# disposition is the lead's and stays in the retro.
#
# usage:
#   audit-rule-files.sh                          # audit the repo rooted at $PWD
#   audit-rule-files.sh --list                   # print the scan corpus, exit 0
#   audit-rule-files.sh --fail-on=deterministic  # only tier 1 sets the exit code
#
# exit 0 = no finding at or above the selected fail threshold
# exit 1 = at least one such finding
# exit 2 = usage or environment error
#
# Layout is autodetected. A consumer keeps its rule files under `.claude/`; the
# distribution keeps the same files under `core/`. Both are scanned by the same
# corpus rule, so narrative fails where it is authored rather than one release
# later in a consumer's retro.
#
# TWO TIERS, split by falsifiability:
#   tier 1  deterministic — a hit is a literal violation of a rule-authoring.md
#           prohibition. No judgement is needed to disposition it.
#   tier 2  judgement — the shape correlates with a violation, but a hit can be
#           a calibration fact the rule needs. The lead dispositions it.
# BOTH TIERS ALWAYS PRINT, with enumerated evidence. `--fail-on` selects only
# which tier sets the exit code. A tier that went silent under a flag would be
# the same defect this audit exists to find.
#
# Scans reported:
#   Class 1   narrative drift        (Rule 18)                    tier 2
#   Class 1a  origin tag / origin parenthetical / embedded date    tier 1
#   Class 1b  incomplete Rule 26(c) triple                         tier 2
#   Class 2   rule weakness          (Rule 18)                     tier 2
#   Class 3   complexity accretion   — NOT MECHANIZED, DID-NOT-RUN
#   Pointers  relocation-pointer resolution (retro.md invariant 1) tier 1
#   Dormancy  path-filter dormancy of CI jobs                      tier 2
#
# Class 3 prints DID-NOT-RUN rather than CLEAN on purpose. It requires the
# catch/false-positive history of each gate, which no static scan holds; a
# CLEAN there would be a check that cannot fire reporting as one that passed.
#
# AI_DLC_AUDIT_MUTANT=1 strips every tier-1 pattern. The fixture asserts a
# corpus seeded with tier-1 violations scores CLEAN under it — that is what
# proves the tier-1 code catches those seeds, rather than an older class
# matching them incidentally.

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="audit"
FAIL_ON="any"
for arg in "$@"; do
  case "$arg" in
    --list)                   MODE="--list" ;;
    --fail-on=any)            FAIL_ON="any" ;;
    --fail-on=deterministic)  FAIL_ON="deterministic" ;;
    *) echo "usage: audit-rule-files.sh [--list] [--fail-on=any|deterministic]" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "audit-rule-files: FAIL — python3 required" >&2; exit 2; }

export AUDIT_MODE="$MODE"
export AUDIT_FAIL_ON="$FAIL_ON"
export AUDIT_MUTANT="${AI_DLC_AUDIT_MUTANT:-0}"

# `gh` is resolved here, not in python, so an absent binary is reported as
# SKIPPED-with-reason instead of silently scoring the dormancy scan clean.
if command -v gh >/dev/null 2>&1; then export AUDIT_HAVE_GH=1; else export AUDIT_HAVE_GH=0; fi

python3 - "$SELF_DIR" <<'PY'
import os, re, subprocess, sys, glob

MODE = os.environ.get("AUDIT_MODE", "audit")
FAIL_ON = os.environ.get("AUDIT_FAIL_ON", "any")
MUTANT = os.environ.get("AUDIT_MUTANT") == "1"
HAVE_GH = os.environ.get("AUDIT_HAVE_GH") == "1"

# Layout autodetection. The consumer form is first so an installed project that
# also vendors a `core/` tree is still read as a consumer.
LAYOUTS = (
    ("consumer",     ".claude/skills/ai-dlc", ".claude/team-roles", ".claude/schemas"),
    ("distribution", "core/skills/ai-dlc",    "core/team-roles",    "core/schemas"),
)
LAYOUT, SKILL, ROLES, SCHEMAS = LAYOUTS[0][0], LAYOUTS[0][1], LAYOUTS[0][2], LAYOUTS[0][3]
for name, skill, roles, schemas in LAYOUTS:
    if os.path.isfile(os.path.join(skill, "SKILL.md")):
        LAYOUT, SKILL, ROLES, SCHEMAS = name, skill, roles, schemas
        break

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
# The skill-root files are named individually because `rule-authoring.md` scopes
# the policy to the whole skill, and a corpus of SKILL.md plus steps/ leaves the
# rest of the skill scanned by nothing.
corpus = []
for p in ("CLAUDE.md", "docs/coding-conventions.md"):
    if os.path.isfile(p):
        corpus.append(p)
for p in ("SKILL.md", "escalations.md", "rule-authoring.md", "core-manifest.md"):
    fp = f"{SKILL}/{p}"
    if os.path.isfile(fp):
        corpus.append(fp)
for root in (f"{SKILL}/steps", f"{SKILL}/templates", ROLES,
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
        "  installed project, or of the ai-dlc distribution. An empty corpus would\n"
        "  report every class CLEAN by scanning nothing, which is the failure this\n"
        "  refuses to perform.\n")
    sys.exit(2)

t1_findings = 0
all_findings = 0
print("=== Rule File Audit ===")
print(f"layout: {LAYOUT}    corpus: {len(corpus)} files")
if MUTANT:
    print("MUTANT: tier-1 patterns stripped (differential control run)")
print()

def emit(label, hits, tier, total_note=""):
    """One class result. An enumerated n=[...] is the evidence; a bare CLEAN is not."""
    global t1_findings, all_findings
    for f, ln, msg in hits:
        print(f"  {f}:{ln}  {label}  {msg}")
    enum = ",".join(f"{f}:{ln}" for f, ln, _ in hits)
    verdict = "CLEAN" if not hits else "FLAGGED"
    print(f"  {label}: {verdict}  n=[{enum}]  "
          f"(tier {tier}; of {len(corpus)} files scanned){total_note}")
    all_findings += len(hits)
    if tier == 1:
        t1_findings += len(hits)
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
    Without this, every class scored its own definition site and the
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

def paragraphs(path):
    """Yield [(lineno, text), ...] runs of scannable lines with no blank line
    between them. A directive routinely wraps across three or four lines, so a
    predicate evaluated per line cannot see a clause in its own sentence."""
    cur = []
    for i, raw in scannable(path):
        if raw.strip():
            cur.append((i, raw))
        elif cur:
            yield cur
            cur = []
    if cur:
        yield cur

# --------------------------------------------------------------- Class 1a
# The prohibitions rule-authoring.md states but nothing mechanized: sprint and
# version references, parenthetical origin notes, embedded dates. These are
# tier 1 — a version tag in rule prose is a violation on sight, with nothing for
# a lead to weigh.
print("--- Class 1a: Origin References (tier 1) ---")
ORIGIN_TAG = re.compile(r"\bv\d+\.\d+\.\d+|\bS\d{2,4}\b")
ORIGIN_PAREN = re.compile(
    r"\([^)]*\b(used to|formerly|renamed|extracted from|moved from|previously)\b[^)]*\)", re.I)
ISO_DATE = re.compile(r"\b(?:19|20)\d{2}-\d{2}-\d{2}\b")

tag_hits, paren_hits, date_hits = [], [], []
if not MUTANT:
    for p in corpus:
        for n, t in scannable(p):
            u = used(t)
            m = ORIGIN_TAG.search(u)
            if m:
                tag_hits.append((p, n, f"origin tag '{m.group(0)}' in rule prose: {t.strip()}"))
                continue                       # one line, one label — no double evidence
            m = ORIGIN_PAREN.search(u)
            if m:
                paren_hits.append((p, n, f"origin parenthetical: {m.group(0)}"))
    for p in corpus:
        for n, t in scannable(p):
            m = ISO_DATE.search(used(t))
            if m:
                date_hits.append((p, n, f"embedded date '{m.group(0)}': {t.strip()}"))
emit("ORIGIN_TAG", tag_hits, 1)
emit("ORIGIN_PARENTHETICAL", paren_hits, 1)
emit("EMBEDDED_DATE", date_hits, 1)

# ---------------------------------------------------------------- Class 1
# Narrative drift: rule text carrying the story of its own origin. Tier 2 — a
# measurement can be the calibration a rule runs on rather than a war story, and
# only the lead can tell those apart.
print("--- Class 1: Narrative Drift (tier 2) ---")
NARRATIVE = re.compile(
    r"(because we\b|got burned|after the .{0,40}incident|when we found|learned that\b"
    r"|measured:|used to\b|the reason is\b|it turned out\b|historically\b"
    r"|before it was\b)", re.I)
hits = [(p, n, t.strip()) for p in corpus for n, t in scannable(p)
        if NARRATIVE.search(used(t))]
emit("NARRATIVE_DRIFT", hits, 2)

# --------------------------------------------------------------- Class 1b
# A Rule 26(c) block missing any of the three fields is the middle ground Rule 18
# exists to close, and Class 1's colloquial-phrase regex cannot see it.
# Section-scoped, not line-scoped: these blocks wrap mid-word across lines
# ("False-\npositive cost:"), so a per-line regex reports a complete triple as
# incomplete. Anchored on the block heading, not on the first field: a block that
# supplies NONE of the three has no "Failure caught:" to anchor on, and anchoring
# there made the emptiest blocks the only ones the scan could not see.
print("--- Class 1b: Incomplete Rule 26(c) Triple (tier 2) ---")
HEAD_OPENER = re.compile(r"(\*\*|#+\s*)Minimum mechanism\b", re.I)
# `Failure caught:` opens a block only when none is open. A block whose heading is
# on one line and whose first field is on the next is ONE block; treating the field
# as a second opener left the heading alone in a block of its own and reported a
# complete triple as supplying nothing.
FIELD_OPENER = re.compile(r"Failure caught:", re.I)
FC = re.compile(r"failure\s+caught|\bcatches:", re.I)
FP = re.compile(r"false[-\s]*positive", re.I)
RM = re.compile(r"removal\s+condition|retired?s?\s+when|removed?\s+when|drop\s+this\s+gate\s+once", re.I)
hits = []
for p in corpus:
    src = lines(p)
    blocks, cur = [], None
    for i, raw in enumerate(src, 1):
        # `used()` here for the same reason every other class uses it: a line that
        # NAMES the field in backticks is documenting the contract, not opening a block.
        opener_src = used(raw)
        if HEAD_OPENER.search(opener_src) or (cur is None and FIELD_OPENER.search(opener_src)):
            if cur:
                blocks.append(cur)
            cur = [i, raw.strip(), [raw]]
        elif cur is not None:
            if raw.startswith("#"):
                blocks.append(cur)
                cur = None
            else:
                cur[2].append(raw)
    if cur:
        blocks.append(cur)
    for ln, text, buf in blocks:
        blob = " ".join(buf)
        missing = [name for name, rx in (("failure-caught", FC),
                                         ("false-positive-cost", FP),
                                         ("removal-condition", RM))
                   if not rx.search(blob)]
        if missing:
            hits.append((p, ln, f"26(c) block missing {'+'.join(missing)}: {text[:60]}"))
emit("INCOMPLETE_26C", sorted(hits), 2)

# ---------------------------------------------------------------- Class 2
# Rule weakness: soft language inside a directive that is trying to mandate.
# Paragraph-scoped, not line-scoped: a rule whose primary directive says SHOULD
# and whose exceptions say MUST wraps those tokens onto different lines, and a
# per-line predicate scored exactly that shape as clean.
print("--- Class 2: Rule Weakness (tier 2) ---")
SOFT = re.compile(r"\b(should|try to|consider|prefer|in most cases|when possible|ideally)\b", re.I)
MANDATE = re.compile(r"(MUST|SHALL|mandate|enforce|require|violation|gate.FAIL)")
# `should not`/`should never` are mandates in the negative, not soft language.
# `Do NOT try to` likewise. A rule saying something is NOT a mandate is exempt.
# `should be` is NOT exempt: it is the canonical soft-mandate form, and exempting
# it made the scan blind to the exact shape Rule 18 names first.
EXEMPT = re.compile(r"(should (not|never)|the user should|"
                    r"(do not|don't|never) (try to|consider|prefer)|not a .{0,20}mandate)", re.I)
hits = []
for p in corpus:
    for para in paragraphs(p):
        blob = used(" ".join(t for _, t in para))
        if not MANDATE.search(blob):
            continue
        for n, t in para:
            if SOFT.search(used(t)) and not EXEMPT.search(t):
                hits.append((p, n, "soft language in a mandating passage: " + t.strip()))
emit("RULE_WEAKNESS", hits, 2)

# ---------------------------------------------------------------- Class 3
print("--- Class 3: Complexity Accretion ---")
print("  COMPLEXITY_ACCRETION: DID-NOT-RUN  n=[]  (reason=needs each gate's")
print("    catch/false-positive history since introduction, which no static scan")
print("    holds. Lead-dispositioned in retro Step 4; a CLEAN here would be a")
print("    check that cannot fire reporting as one that passed.)")
print()

# --------------------------------------------------------------- Pointers
# Invariant 1: every pointer to skill-loadable content resolves to a live file.
print("--- Relocation-pointer resolution (tier 1) ---")
POINTER = re.compile(
    r"(?:READ AND FOLLOW|lives in|defined in|canonical(?:\s+\w+){0,3}\s+in|schema in|see)\s+`([^`]+)`",
    re.I)
# Runtime artifacts and project files exist only in an installed project, not in
# the skill source. Flagging them would fail every clean tree.
OUT_OF_SCOPE = re.compile(
    r"^(_bmad-output/|docs/|CLAUDE\.md$|prd\.md$|product-brief\.md$|carry-over-backlog\.md$|"
    r"gate-log|pipeline-snapshot|compaction-log\.md$|audit-anchors\.md$)")
IN_SCOPE = re.compile(r"^(steps/|schemas/|team-roles/|templates/|"
                      r"rule-authoring\.md$|escalations\.md$|core-manifest\.md$|"
                      r"enforcement-map\.yaml$|research-citations\.md$)")

def resolve(target):
    """A pointer's path is skill-dir-relative; team-roles/ resolves outside it."""
    if target.startswith("team-roles/"):
        return [os.path.join(os.path.dirname(ROLES), target), f"{ROLES}/{target.split('/', 1)[1]}"]
    if target.startswith("schemas/"):
        return [os.path.join(os.path.dirname(SCHEMAS), target), f"{SKILL}/{target}"]
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
emit("DANGLING_POINTER", hits, 1, f"  [{len(sources)} skill files searched]")

# --------------------------------------------------------------- Dormancy
# Path-filter dormancy: a CI job gated behind paths:/paths-ignore: that has not
# actually run on main for ≥3 sprints is enforcement nobody is paying for.
print("--- Path-filter dormancy (tier 2) ---")
wf = sorted(glob.glob(".github/workflows/*.yml") + glob.glob(".github/workflows/*.yaml"))
if not os.path.isdir(".github/workflows"):
    print("  PATH_DORMANCY: N/A  n=[]  (reason=no .github/workflows/ — a script-based")
    print("    consumer runs validators directly; an empty workflow set is the")
    print("    expected state, not a dormancy finding)")
    print()
elif not wf:
    print("  PATH_DORMANCY: N/A  n=[]  (reason=.github/workflows/ holds no workflow files)")
    print()
elif not HAVE_GH:
    print(f"  PATH_DORMANCY: SKIPPED  n=[]  (reason=`gh` not on PATH; {len(wf)} workflow")
    print("    file(s) carry path filters that went unchecked. This is an unrun scan,")
    print("    NOT a clean one — install `gh` or record the gap in the retro.)")
    print()
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
        emit("PATH_DORMANCY", dormant, 2, f"  [{len(filtered)} path-filtered workflow(s)]")

print(f"threshold: --fail-on={FAIL_ON}   tier-1 findings: {t1_findings}   all findings: {all_findings}")
sys.exit(1 if (t1_findings if FAIL_ON == "deterministic" else all_findings) else 0)
PY
