#!/usr/bin/env bash
# validate-retro-evidence.sh
#
# Usage: ./scripts/ai-dlc/validate-retro-evidence.sh <retro-branch-name> <sprint-number>
# Example: ./scripts/ai-dlc/validate-retro-evidence.sh ai-dlc/retro/sprint-137 137
#
# Enforces that a retro branch actually invoked /bmad-party-mode (retro.md
# Step 2 MANDATORY SUB-SKILL INVOCATION) rather than simulating it inline.
# Verifies three markers, applies a non-triviality floor to the transcript,
# and (Sprint 138 extension) verifies the retro doc cites the transcript
# with a specific commit SHA (path@sha format) that still points at the
# current blob.
#
# Markers (per Story 137-5 AC2, minus the commit-subject marker -- see below):
#   1. docs/retro/s<N>/retro.md cites the canonical transcript path
#      _bmad-output/party-mode-transcripts/s<N>/retro.md
#   2. Transcript file exists at canonical path AND is committed to the
#      retro branch (verified via `git ls-tree`)
#   3. Transcript file is non-empty
#
# REMOVED: the party-mode COMMIT SUBJECT marker. It failed the blocking Step-5c
# gate with COMMIT_MISSING unless some commit on <merge-base>..<retro-branch>
# matched "Sprint <N> retro.*[Pp]arty[- ][Mm]ode" -- a contract retro.md states
# NOWHERE. Step 2 specifies the transcript's path, its commit ordering and its
# path@<sha> citation, and says nothing about the subject.
#
# It was not a naming nit. This script resolves origin/<branch>, so it cannot run
# until Step 6b has pushed; a non-conforming subject was therefore undiscoverable
# until the commit was already published, at which point rewording requires a
# force-push to a pushed branch. The only remedy left was an extra commit created
# solely to satisfy a rule nobody had written down. Observed: a retro whose
# transcript was committed in full, at the correct path, cited by SHA in the
# provenance block, still blocked -- because the subject read "sprint-294" where
# the pattern wanted a space.
#
# Deleted rather than documented, because it was a strictly weaker proxy for
# something the surviving markers already prove. Marker 2 asserts the transcript
# is committed on the branch, and 4b/4c assert the retro doc cites the exact
# commit and that its blob still matches HEAD byte-for-byte. "The party-mode
# transcript was committed on this branch and the retro cites that commit" is
# established without reference to a subject line anyone can type.
#
# Non-triviality floor (per Story 137-5 AC3):
#   - Transcript ≥ MIN_CHARS characters
#   - Transcript contains ≥ MIN_PERSONAS distinct persona markers
#     (union of emoji icons and name prefixes)
#   - Transcript contains ≥ MIN_PHASES distinct AI/DLC canonical phase labels
# Thresholds MAY be lowered to fit prior-sprint baselines but MUST NOT go
# below the floor guard (FLOOR_MIN_*) values.
#
# Transcript SHA citation sub-check (Sprint 138 Story 138-3 / Item 326 A.3,
# per LR-S138-21):
#   4a. retro doc citation has @<sha> suffix form
#       (path like _bmad-output/party-mode-transcripts/s<N>/retro.md@<sha>)
#   4b. `git cat-file -p <sha>:<path>` successfully reads the transcript at
#       the cited commit
#   4c. Blob at cited SHA matches `git show HEAD:<path>` byte-for-byte
#       (transcript immutability — any later edit to the transcript invalidates
#       the citation)
# Exit codes unchanged; the SHA sub-check is ADDITIVE to the existing
# non-triviality floor, which is PRESERVED per LR-S138-21.
#
# Exit codes:
#   0  -- gate pass (all markers + floor + SHA citation satisfied)
#   1  -- gate fail (≥1 marker missing, floor threshold unmet, OR transcript
#         SHA citation missing / mismatched)
#   2  -- usage error (missing/wrong args, invalid sprint number)
#
# This script is part of the pipeline-enforcement script layer (ADR-S138-2).
# Sibling scripts:
#   - validate-cycle-commits.sh     (Sprint 136 Story 136-5 / Item 318)
#       enforces "≥3 cycle commits per planning artifact"
#   - validate-phase-sequencing.sh  (Sprint 138 Story 138-3 / Item 326)
#       enforces phase-transition pause-point compliance
#   - validate-retro-prereq.sh      (Sprint 138 Story 138-3 / Item 326)
#       enforces deploy-validate operator actions have completion
#       timestamps BEFORE retro branch creation
#   - validate-retro-evidence.sh    (this file, Sprint 137 Story 137-5 +
#                                    Sprint 138 Story 138-3)
#       enforces retro party-mode invocation, non-triviality floor, AND
#       transcript SHA citation (path@sha format)
#
# All four scripts enforce pipeline structural integrity. Different inputs,
# different outputs, same goal: structural evidence that the pipeline was
# actually followed rather than simulated.
#
# Read-only: this script only READS retro artifacts, never writes to them
# (ADR-S138-2 principle 3 / INV-S138-4). `git cat-file -p` is a pure read.
#
# Compatible with bash 3.2+ and Python 3 (standard on macOS).
# Part of Sprint 137 Story 137-5 (Item 324) + Sprint 138 Story 138-3
# (Item 326) structural enforcement.

set -u

# ---- Usage check -----------------------------------------------------------
if [ $# -ne 2 ]; then
  echo "usage: ./scripts/ai-dlc/validate-retro-evidence.sh <retro-branch-name> <sprint-number>" >&2
  echo "example: ./scripts/ai-dlc/validate-retro-evidence.sh ai-dlc/retro/sprint-137 137" >&2
  exit 2
fi

RETRO_BRANCH="$1"
SPRINT_N="$2"

# Sprint number must be a positive integer
case "$SPRINT_N" in
  ''|*[!0-9]*)
    echo "usage: ./scripts/ai-dlc/validate-retro-evidence.sh <retro-branch-name> <sprint-number>" >&2
    echo "error: sprint-number must be a positive integer (got: $SPRINT_N)" >&2
    exit 2
    ;;
esac

# ---- Run the analysis via Python (macOS-compatible) ------------------------
python3 - "$RETRO_BRANCH" "$SPRINT_N" << 'PYEOF'
import sys
import re
import subprocess

retro_branch = sys.argv[1]
sprint_n = sys.argv[2]

# ---- Resolve the retro branch to a git ref that actually exists ------------
# The header's contract is that this runs on the PUSHED branch (origin/<branch>),
# but the branch name was fed to `git merge-base`/`git ls-tree` verbatim. On a CI
# runner, which fetches refs into origin/* and keeps NO local branch for each,
# `git ls-tree sprint-137 -- <path>` resolves nothing and the transcript reads as
# "not committed" — a false COMMIT_MISSING that has nothing to do with the retro.
# Resolve it: try the ref as given first (a local branch, or a name already
# qualified as origin/..., still works — no regression for any input that passed
# before), then fall back to origin/<name>. Fail fast naming both refs if neither
# resolves, instead of dying opaquely in merge-base 30 lines later.
def _ref_exists(ref):
    return subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", ref],
        capture_output=True, text=True
    ).returncode == 0

_candidates = [retro_branch] if retro_branch.startswith("origin/") \
    else [retro_branch, f"origin/{retro_branch}"]
_resolved = next((r for r in _candidates if _ref_exists(r)), None)
if _resolved is None:
    print("VALIDATE-RETRO-EVIDENCE: FAIL")
    print(f"  retro branch not found — tried: {', '.join(_candidates)}")
    print("  the branch must exist locally or as a pushed origin/<branch> before this runs")
    sys.exit(1)
retro_branch = _resolved

# ---- Hardcoded thresholds — EDIT HERE to tune ------------------------------
MIN_CHARS = 2000
MIN_PERSONAS = 4
MIN_PHASES = 3

# Minimum floor guard — thresholds MUST NOT go below these values (Story 137-5
# AC3 / PRD-AR2-F6). Lowering below the floor requires HARD_BLOCK escalation.
FLOOR_MIN_CHARS = 1000
FLOOR_MIN_PERSONAS = 3
FLOOR_MIN_PHASES = 2

# AI/DLC canonical phase labels — FIXED allow-list (PRD-F4 / IC-S137-13).
# EDIT HERE to add a new phase label; MUST also update CLAUDE.md.
PHASE_LABELS = ['Phase 1', 'Phase 2', 'Phase 3', 'Phase 4', 'Phase 5']

# Persona markers — union of emoji icons and name prefixes. Mixed usage is
# acceptable per Story 137-5 AC3.
# EDIT HERE to add new persona identifiers.
PERSONA_MARKERS = [
    '🏃', '💻', '🏗️', '📋', '🧪', '🧙', '🔬',
    'Bob (SM):', 'Amelia (Dev):', 'Winston (Architect):',
    'Quinn (TEA):', 'Mary (CIS):', 'Murat (TEA):', 'John (PM):',
]

# Assert floor guard invariant (guard against accidental edits).
assert MIN_CHARS >= FLOOR_MIN_CHARS, "MIN_CHARS below floor guard"
assert MIN_PERSONAS >= FLOOR_MIN_PERSONAS, "MIN_PERSONAS below floor guard"
assert MIN_PHASES >= FLOOR_MIN_PHASES, "MIN_PHASES below floor guard"

retro_doc = f"docs/retro/s{sprint_n}/retro.md"
transcript_path = f"_bmad-output/party-mode-transcripts/s{sprint_n}/retro.md"

# ---- Resolve merge-base <retro-branch> main --------------------------------
# Audit locator only. Nothing branches on it since the commit-subject marker was removed
# (see the header note); it is printed so a human reading a failure can find the range.
mb = subprocess.run(
    ["git", "merge-base", retro_branch, "main"],
    capture_output=True, text=True
)
merge_base = mb.stdout.strip() if mb.returncode == 0 else ""

# ---- Marker 1: retro doc cites canonical transcript path -------------------
# Sprint 138 Story 138-3 / LR-S138-21: citation MUST include @<sha> suffix
# form for the SHA sub-check to be runnable. Path-only citation fails with
# "missing SHA in transcript citation".
citation_line = None
citation_sha = None  # captured SHA from first path@sha match
citation_line_text = None
try:
    with open(retro_doc, encoding='utf-8') as f:
        for i, line in enumerate(f, start=1):
            if transcript_path in line:
                if citation_line is None:
                    citation_line = i
                    citation_line_text = line
                # Try to extract the SHA suffix on any citation line; the
                # first line with a valid @<sha> wins. If no line has one,
                # citation_sha remains None and the SHA sub-check will fail.
                if citation_sha is None:
                    sha_match = re.search(
                        rf"{re.escape(transcript_path)}@([a-f0-9]{{7,40}})",
                        line,
                    )
                    if sha_match:
                        citation_sha = sha_match.group(1)
    retro_doc_present = True
except FileNotFoundError:
    # DISTINCT FROM "present but does not cite". Both used to report CITATION_MISSING,
    # and after the path grammar moved this file the two are the failures an operator
    # most needs told apart: an unmigrated tree has no file at all, and "does not cite"
    # sends them looking for a missing line in a file that is not there.
    citation_line = None
    retro_doc_present = False

# ---- Marker 2: transcript file committed to retro branch -------------------
ls = subprocess.run(
    ["git", "ls-tree", retro_branch, "--", transcript_path],
    capture_output=True, text=True
)
transcript_tracked = bool(ls.stdout.strip()) and ls.returncode == 0

# ---- Marker 3: transcript file non-empty (and load for floor checks) ------
transcript_text = None
try:
    with open(transcript_path, encoding='utf-8') as f:
        transcript_text = f.read()
except FileNotFoundError:
    transcript_text = None

# ---- Sprint 138 Story 138-3 / LR-S138-21: transcript SHA citation sub-check
#
# Multi-step check:
#   (i) retro doc citation has @<sha> suffix (captured above as citation_sha)
#   (ii) `git cat-file -p <sha>:<path>` reads the transcript at cited SHA
#   (iii) `git show HEAD:<path>` reads the transcript at HEAD
#   (iv) compare blobs byte-for-byte; mismatch means the transcript was
#        edited after the citation was locked in
#
# The sub-check runs ONLY if the retro doc exists AND the citation line is
# present. If either is missing, the upstream CITATION_MISSING failure code
# already fires and the SHA sub-check is not run. Otherwise any failure of
# steps (i)-(iv) produces its own failure code: SHA_MISSING (path-only
# citation) or SHA_MISMATCH (cited SHA's blob differs from HEAD blob).
sha_citation_ok = None  # None = skipped, True = pass, False = fail
sha_failure_detail = None
cited_blob_sha = None
head_blob_sha = None
if citation_line is not None:
    # Step (i): check for @<sha> suffix
    if citation_sha is None:
        sha_citation_ok = False
        sha_failure_detail = (
            "missing SHA in transcript citation — retro doc must cite "
            "transcript path with @<sha> suffix "
            f"(e.g., {transcript_path}@<sha>)"
        )
    else:
        # Step (ii): resolve cited blob via git cat-file
        cat = subprocess.run(
            ["git", "cat-file", "-p", f"{citation_sha}:{transcript_path}"],
            capture_output=True, text=True
        )
        if cat.returncode != 0:
            sha_citation_ok = False
            sha_failure_detail = (
                f"git cat-file failed for cited SHA {citation_sha}: "
                f"{cat.stderr.strip()} — the SHA does not resolve to the "
                f"transcript path in the repo"
            )
        else:
            cited_blob = cat.stdout
            # Resolve cited blob SHA for the diagnostic message
            bsha = subprocess.run(
                ["git", "rev-parse", f"{citation_sha}:{transcript_path}"],
                capture_output=True, text=True
            )
            if bsha.returncode == 0:
                cited_blob_sha = bsha.stdout.strip()

            # Step (iii): read current HEAD blob
            head = subprocess.run(
                ["git", "show", f"HEAD:{transcript_path}"],
                capture_output=True, text=True
            )
            if head.returncode != 0:
                sha_citation_ok = False
                sha_failure_detail = (
                    f"git show failed for HEAD:{transcript_path}: "
                    f"{head.stderr.strip()}"
                )
            else:
                head_blob = head.stdout
                hb = subprocess.run(
                    ["git", "rev-parse", f"HEAD:{transcript_path}"],
                    capture_output=True, text=True
                )
                if hb.returncode == 0:
                    head_blob_sha = hb.stdout.strip()

                # Step (iv): byte-for-byte compare. We compare by blob SHA
                # when available (more efficient + structurally identical)
                # and fall back to raw content comparison otherwise.
                if cited_blob_sha and head_blob_sha:
                    if cited_blob_sha == head_blob_sha:
                        sha_citation_ok = True
                    else:
                        sha_citation_ok = False
                        byte_diff = abs(len(cited_blob) - len(head_blob))
                        sha_failure_detail = (
                            f"transcript edited after citation: cited SHA "
                            f"{citation_sha} blob ({cited_blob_sha[:12]}) "
                            f"≠ HEAD blob ({head_blob_sha[:12]}) "
                            f"({byte_diff} byte length diff)"
                        )
                elif cited_blob == head_blob:
                    sha_citation_ok = True
                else:
                    sha_citation_ok = False
                    byte_diff = abs(len(cited_blob) - len(head_blob))
                    sha_failure_detail = (
                        f"transcript edited after citation: cited SHA "
                        f"{citation_sha} content differs from HEAD "
                        f"({byte_diff} byte length diff)"
                    )

# ---- Non-triviality floor --------------------------------------------------
chars = len(transcript_text) if transcript_text else 0
personas_found = []
phases_found = []
if transcript_text:
    personas_found = [m for m in PERSONA_MARKERS if m in transcript_text]
    phases_found = [p for p in PHASE_LABELS if p in transcript_text]

# ---- Aggregate pass/fail ---------------------------------------------------
failures = []
if citation_line is None:
    if not retro_doc_present:
        failures.append(
            ("RETRO_DOC_MISSING",
             f"{retro_doc} does not exist. The retro document is composed from the "
             f"declared sprint, never searched for; a tree that has not been migrated "
             f"to the artifact path grammar still has it at docs/retro/sprint-"
             f"{sprint_n}.md.")
        )
    else:
        failures.append(
            ("CITATION_MISSING",
             f"{retro_doc} does not cite {transcript_path}")
        )
if not transcript_tracked:
    failures.append(
        ("TRANSCRIPT_MISSING",
         f"{transcript_path} not committed to {retro_branch}")
    )
if transcript_text is None or chars == 0:
    failures.append(
        ("TRANSCRIPT_EMPTY",
         f"{transcript_path} is empty or unreadable")
    )
if transcript_text is not None and chars > 0:
    if chars < MIN_CHARS:
        failures.append(
            ("FLOOR_CHARS", f"transcript char count {chars} < {MIN_CHARS}")
        )
    if len(personas_found) < MIN_PERSONAS:
        failures.append(
            ("FLOOR_PERSONAS",
             f"distinct persona markers {len(personas_found)} < {MIN_PERSONAS} "
             f"(found: {personas_found})")
        )
    if len(phases_found) < MIN_PHASES:
        failures.append(
            ("FLOOR_PHASES",
             f"distinct phase labels {len(phases_found)} < {MIN_PHASES} "
             f"(found: {phases_found})")
        )

# Sprint 138 Story 138-3 / LR-S138-21: transcript SHA citation failure codes
if sha_citation_ok is False:
    if sha_failure_detail and sha_failure_detail.startswith("missing SHA"):
        failures.append(("SHA_MISSING", sha_failure_detail))
    elif sha_failure_detail and "transcript edited" in sha_failure_detail:
        failures.append(("SHA_MISMATCH", sha_failure_detail))
    else:
        failures.append(("SHA_CHECK", sha_failure_detail or "SHA sub-check failed"))

# ---- Output ----------------------------------------------------------------
def mark(ok):
    return "OK" if ok else "FAIL"

def sha_status_line():
    """Render the SHA citation status line for both pass and fail output."""
    if sha_citation_ok is None:
        return "  transcript SHA citation: (skipped — no retro doc citation)"
    if sha_citation_ok:
        return (
            f"  transcript SHA citation: OK "
            f"(cited {citation_sha[:12] if citation_sha else '?'}, "
            f"blob {cited_blob_sha[:12] if cited_blob_sha else '?'})"
        )
    return f"  transcript SHA citation: FAIL ({sha_failure_detail})"


if failures:
    print("VALIDATE-RETRO-EVIDENCE: FAIL")
    print(f"  Sprint {sprint_n} / {retro_branch}")
    print(f"  merge-base: {merge_base[:12] if merge_base else '(missing)'}")
    print(f"  retro doc citation ({retro_doc}): {mark(citation_line is not None)}"
          + (f" line {citation_line}" if citation_line else ""))
    print(f"  transcript committed ({transcript_path}): {mark(transcript_tracked)}")
    print(f"  transcript non-empty: {mark(transcript_text is not None and chars > 0)}"
          + (f" ({chars} chars)" if transcript_text is not None else ""))
    print(sha_status_line())
    print("  non-triviality floor:")
    if transcript_text is not None and chars > 0:
        print(f"    chars:    {chars} {'>=' if chars >= MIN_CHARS else '<'} {MIN_CHARS} "
              f"{'OK' if chars >= MIN_CHARS else 'FAIL'}")
        print(f"    personas: {len(personas_found)} {'>=' if len(personas_found) >= MIN_PERSONAS else '<'} {MIN_PERSONAS} "
              f"{'OK' if len(personas_found) >= MIN_PERSONAS else 'FAIL'}")
        print(f"    phases:   {len(phases_found)} {'>=' if len(phases_found) >= MIN_PHASES else '<'} {MIN_PHASES} "
              f"{'OK' if len(phases_found) >= MIN_PHASES else 'FAIL'}")
    else:
        print("    (skipped — transcript missing or empty)")
    print()
    print("  Failure codes:", file=sys.stderr)
    for code, msg in failures:
        print(f"    [{code}] {msg}", file=sys.stderr)
    sys.exit(1)

# ---- PASS path -------------------------------------------------------------
print("VALIDATE-RETRO-EVIDENCE: PASS")
print(f"  Sprint {sprint_n} / {retro_branch}")
print(f"  merge-base: {merge_base[:12] if merge_base else '(missing)'}")
print(f"  retro doc cites transcript: {retro_doc}:{citation_line}")
print(f"  transcript file: {transcript_path} ({chars} chars)")
print(sha_status_line())
print("  non-triviality floor:")
print(f"    chars:    {chars:<6} >= {MIN_CHARS}  OK")
print(f"    personas: {len(personas_found):<6} >= {MIN_PERSONAS}     OK ({', '.join(personas_found)})")
print(f"    phases:   {len(phases_found):<6} >= {MIN_PHASES}     OK ({', '.join(phases_found)})")
sys.exit(0)
PYEOF
