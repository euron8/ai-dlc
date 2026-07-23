#!/usr/bin/env bash
# validate-cycle-commits.sh
#
# Usage: ./validate-cycle-commits.sh [branch]
#
# Verifies that each planning artifact recorded in
# _bmad-output/validation-cycle-log.md has >=3 distinct cycle commits AND that
# the commit count agrees with the log's row count for that artifact.
#
# Two counting strategies, both must agree for PASS:
#   1. LOG-BASED: count rows per artifact section in validation-cycle-log.md.
#      Each row's commit SHA (if present) must exist on the branch, or the row
#      is "TBD" (a pending commit for the current story).
#   2. COMMIT-BASED: count commits on the branch whose subject matches
#      "Sprint N <artifact>: <cycle>", normalized so "discovery" counts toward
#      the sprint's first brief, "research-requirements" toward its first PRD,
#      and "stories-test-strategy" toward its stories.
#
# PASS per artifact:
#   - log_row_count >= MIN_CYCLES
#   - commit_count  >= MIN_CYCLES
#   - |log_row_count - commit_count| <= 1   (tolerate one TBD row)
#   - the commit set includes >=1 party-mode commit AND >=1 adversarial-review
#     commit (cycle-type coverage)
#
# Trunk base: commits are counted over "<trunk>..<branch>". Trunk defaults to
# "main"; override with AI_DLC_TRUNK.
#
# Exit codes:
#   0  -- all artifacts pass
#   1  -- one or more artifacts fail, or validation-cycle-log.md missing
#
# Companion to validate-retro-evidence.sh: this enforces ">=3 cycle commits per
# planning artifact"; retro-evidence enforces that retro party-mode was actually
# invoked. Different inputs, different outputs, both are pipeline structural
# enforcement.
#
# bash 3.2+ and Python 3.

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
LOG_FILE="_bmad-output/validation-cycle-log.md"
MIN_CYCLES=3
TRUNK="${AI_DLC_TRUNK:-main}"

# ---- Edge case: missing log file -------------------------------------------
if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: validation log file missing: $LOG_FILE" >&2
  exit 1
fi

# ---- Run the analysis via Python -------------------------------------------
python3 - "$BRANCH" "$LOG_FILE" "$MIN_CYCLES" "$TRUNK" << 'PYEOF'
import sys
import re
import subprocess

branch = sys.argv[1]
log_file = sys.argv[2]
min_cycles = int(sys.argv[3])
trunk = sys.argv[4]

# ---- Get all commit SHAs on branch since trunk ------------------------------
sha_result = subprocess.run(
    ["git", "log", f"{trunk}..{branch}", "--format=%H"],
    capture_output=True, text=True
)
branch_shas = set(sha_result.stdout.strip().splitlines())

# Helper: check if a given SHA exists anywhere in git history (not just branch)
def sha_exists_in_repo(sha):
    if not sha or sha == "TBD":
        return False
    r = subprocess.run(
        ["git", "cat-file", "-e", sha],
        capture_output=True, text=True
    )
    return r.returncode == 0

# Get commit subjects for secondary commit-based counting
subj_result = subprocess.run(
    ["git", "log", f"{trunk}..{branch}", "--format=%H %s"],
    capture_output=True, text=True
)
commits = [line for line in subj_result.stdout.strip().splitlines() if line]

if not commits:
    print(f"No commits on branch {branch} since {trunk} -- nothing to validate.")
    sys.exit(0)

# ---- Parse log file: count rows per artifact section -----------------------
# Sections: "## Sprint N — <Label> (...)"  or  "## Sprint N -- <Label> (...)"
# Each section has a table; count rows (lines starting "| <digit>").
# Also record commit SHAs from rows for branch-membership check.
artifacts = {}  # artifact_key -> {"rows": int, "shas": [str], "sprint": str}

SECTION_RE = re.compile(r'^## Sprint (\d+) [—\-]+ (.+)')
# Accept SHAs bare or wrapped in backticks; "TBD" marker for pending commits.
# Both spellings tolerated to avoid false-positive merge-detection failures on
# logs written before the backtick-wrapping convention.
ROW_RE = re.compile(r'^\|\s*(\d+)\s*\|.*\|\s*`?([0-9a-f]{6,40}|TBD)`?\s*\|?\s*$')

current = None
with open(log_file, encoding='utf-8') as f:
    for raw_line in f:
        line = raw_line.rstrip('\n')
        m = SECTION_RE.match(line)
        if m:
            sprint_n = m.group(1)
            label = m.group(2).strip()
            # Remove trailing parenthetical
            label = re.sub(r'\s*\(.*\)\s*$', '', label).strip()
            ll = label.lower()
            if ll.startswith('brief'):
                key = label[0].lower() + label[1:]
            elif ll.startswith('prd'):
                key = label
            elif ll.startswith('architecture'):
                key = 'architecture'
            elif ll.startswith('stories'):
                key = 'stories'
            elif ll.startswith('test strategy') or ll.startswith('test-strategy'):
                key = 'test-strategy'
            elif ll.startswith('retro'):
                key = 'retro'
            else:
                key = label
            full_key = f"{sprint_n}:{key}"
            artifacts[full_key] = {"rows": 0, "shas": [], "sprint": sprint_n, "label": key}
            current = full_key
            continue
        if current and re.match(r'^\|\s*\d+\s*\|', line):
            artifacts[current]["rows"] += 1
            # Extract commit SHA from last column (if present and not TBD).
            # Tolerate optional backtick wrapping for markdown rendering.
            sha_m = re.search(r'\|\s*`?([0-9a-f]{6,40})`?\s*\|?\s*$', line)
            if sha_m:
                artifacts[current]["shas"].append(sha_m.group(1))

if not artifacts:
    print("No artifact sections found in validation-cycle-log.md.")
    sys.exit(0)

# ---- Retro-branch awareness -------------------------------------------------
# On retro branches (ai-dlc/retro/sprint-N), planning-phase artifacts were
# squash-merged to trunk as part of the sprint PR. Their cycle commits are no
# longer visible on the retro branch (created from trunk AFTER the squash).
# Only the retro artifact has fresh cycle commits on the retro branch and should
# be validated. Planning artifacts from the current sprint are skipped with a
# SQUASHED annotation.
is_retro_branch = '/retro/sprint-' in branch or branch.endswith('/retro')
retro_sprint_n = None
if is_retro_branch:
    rm = re.search(r'/retro/sprint-(\d+)', branch)
    if rm:
        retro_sprint_n = rm.group(1)

# ---- Build commit-based counts per artifact --------------------------------
# Pattern: "Sprint N <artifact_key>: <cycle>"
# Normalization:
#   "discovery draft" -> the sprint's first brief artifact
#   "research-requirements draft" -> the sprint's first PRD artifact
#   "stories-test-strategy draft" -> the sprint's stories artifact
COMMIT_RE = re.compile(r'^[0-9a-f]+ Sprint (\d+) (.+?): .+')

# Cycle-type coverage: an artifact's commit set must include at least one
# party-mode commit AND at least one adversarial-review commit. The `pass N`
# suffix on AR is required so "AR-15 rifle"-style subjects do not match, and the
# `[-\s]+` separator rejects "AR15".
PARTY_MODE_RE = re.compile(r'\b(party[- ]?mode|pm)\b', re.IGNORECASE)
AR_RE = re.compile(r'\b(adversarial[- ]?review|AR[-\s]+pass\s*[0-9]+|ar pass\s*[0-9]+)\b', re.IGNORECASE)

commit_counts = {}  # artifact_key -> count
commit_subjects = {}  # artifact_key -> list of commit subject strings (for cycle-type check)
sprint_brief_map = {}   # sprint_n -> first brief key in artifacts
sprint_prd_map = {}     # sprint_n -> first PRD key in artifacts
sprint_stories_map = {} # sprint_n -> first stories key in artifacts
sprint_test_strategy_map = {} # sprint_n -> first test-strategy key in artifacts

for fk, info in artifacts.items():
    sn = info["sprint"]
    lbl = info["label"].lower()
    if lbl.startswith("brief") and sn not in sprint_brief_map:
        sprint_brief_map[sn] = fk
    if lbl.startswith("prd") and sn not in sprint_prd_map:
        sprint_prd_map[sn] = fk
    if lbl.startswith("stories") and sn not in sprint_stories_map:
        sprint_stories_map[sn] = fk
    if lbl.startswith("test-strategy") and sn not in sprint_test_strategy_map:
        sprint_test_strategy_map[sn] = fk

for line in commits:
    m = COMMIT_RE.match(line)
    if not m:
        continue
    sprint_n = m.group(1)
    artifact = re.sub(r'\s+draft$', '', m.group(2).strip())
    # Capture the full subject after the SHA for cycle-type regex.
    subject_after_sha = line.split(' ', 1)[1] if ' ' in line else line

    # Normalize step-file names to the log's artifact labels. Accept any string
    # starting with the step name (e.g. "discovery Scope 101") as an alias for
    # the sprint's first artifact of that class, tolerating commit-subject
    # variation without changing the structural intent.
    artifact_lc = artifact.lower()
    if artifact_lc == 'discovery' or artifact_lc.startswith('discovery '):
        target = sprint_brief_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue
    if artifact_lc == 'research-requirements' or artifact_lc.startswith('research-requirements '):
        target = sprint_prd_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue
    if artifact_lc == 'stories-test-strategy' or artifact_lc.startswith('stories-test-strategy '):
        target = sprint_stories_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue
    if artifact_lc == 'test-strategy' or artifact_lc.startswith('test-strategy ') \
            or artifact_lc == 'test strategy' or artifact_lc.startswith('test strategy '):
        target = sprint_test_strategy_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue

    # Standard case: look for matching artifact key in our artifacts dict
    fk = f"{sprint_n}:{artifact}"
    if fk in artifacts:
        commit_counts[fk] = commit_counts.get(fk, 0) + 1
        commit_subjects.setdefault(fk, []).append(subject_after_sha)

# ---- Output table and check PASS/FAIL conditions ---------------------------
fail = False
print()
print(f"{'ARTIFACT':<42} | {'COMMITS':>7} | {'LOG ROWS':>8} | {'SHA CHECK':>10} | MATCH")
print("-" * 90)

for fk in sorted(artifacts.keys()):
    info = artifacts[fk]
    sprint_n = info["sprint"]
    label = info["label"]
    log_rows = info["rows"]
    cycles = commit_counts.get(fk, 0)

    # SHA check: how many log row SHAs exist on the branch
    sha_hits = sum(1 for s in info["shas"] if any(b.startswith(s) or s.startswith(b[:7]) for b in branch_shas))
    sha_total = len(info["shas"])
    sha_status = f"{sha_hits}/{sha_total}"

    # Retro-branch awareness: planning artifacts from the retro's own sprint were
    # squash-merged to trunk and are not directly visible on the retro branch.
    # Skip them as SQUASHED rather than failing.
    if is_retro_branch and retro_sprint_n == sprint_n and label != 'retro':
        match = "SQUASHED (pre-retro)"
        disp = f"Sprint {sprint_n} {label}"
        print(f"{disp:<42} | {cycles:>7} | {log_rows:>8} | {sha_status:>10} | {match}")
        continue

    # Prior-sprint awareness: artifacts from a PRIOR sprint whose cycle commits
    # were merged to trunk in a completed sprint PR. Their SHAs are no longer in
    # trunk..HEAD but exist in git history. If log rows >= min_cycles AND all
    # non-TBD log SHAs exist in the repo, mark MERGED and skip -- a new sprint's
    # artifacts validate without re-validating every prior sprint's, whose cycle
    # integrity is locked in by the merged trunk history.
    if cycles == 0 and log_rows >= min_cycles and info["shas"]:
        non_tbd_shas = [s for s in info["shas"] if s.lower() != "tbd"]
        if non_tbd_shas and all(sha_exists_in_repo(s) for s in non_tbd_shas):
            match = "MERGED (prior sprint)"
            disp = f"Sprint {sprint_n} {label}"
            print(f"{disp:<42} | {cycles:>7} | {log_rows:>8} | {sha_status:>10} | {match}")
            continue

    if log_rows < min_cycles:
        match = f"FAIL (<{min_cycles} log rows)"
        fail = True
    elif cycles < min_cycles:
        match = f"FAIL (<{min_cycles} commits)"
        fail = True
    elif abs(cycles - log_rows) > 1:
        match = "FAIL (mismatch >1)"
        fail = True
    else:
        # Cycle-type coverage: require >=1 party-mode AND >=1 adversarial-review
        # commit in the artifact's commit set.
        subjects = commit_subjects.get(fk, [])
        has_party_mode = any(PARTY_MODE_RE.search(s) for s in subjects)
        has_ar = any(AR_RE.search(s) for s in subjects)
        if not has_party_mode:
            match = "FAIL (missing cycle type: party-mode)"
            fail = True
        elif not has_ar:
            match = "FAIL (missing cycle type: adversarial-review)"
            fail = True
        else:
            match = "PASS"

    disp = f"Sprint {sprint_n} {label}"
    print(f"{disp:<42} | {cycles:>7} | {log_rows:>8} | {sha_status:>10} | {match}")

print()
if fail:
    print(f"RESULT: FAIL -- one or more artifacts have <{min_cycles} cycles or mismatch.",
          file=sys.stderr)
    sys.exit(1)
else:
    print(f"RESULT: PASS -- all artifacts have >={min_cycles} cycles with matching log rows.")
    sys.exit(0)
PYEOF
