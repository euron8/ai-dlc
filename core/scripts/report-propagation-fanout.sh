#!/usr/bin/env bash
# report-propagation-fanout.sh — the citations a repair may have just invalidated
#
# Usage: ./scripts/ai-dlc/report-propagation-fanout.sh <base-ref> [<head-ref>]
#                                                      [--sprint sNNN] [--no-frozen]
#
# With one ref, the diff is <base-ref> against the WORKING TREE — which is the state
# a remediator is actually in when it has just repaired an artifact and has not
# committed. With two, it is <base-ref>..<head-ref>.
#
# THIS IS ADVISORY ABOUT THE CITATIONS, WHICH IS NOT THE SAME AS UNABLE TO FAIL. It
# prints a WORKLIST, never a verdict: a worklist item is a citation that COULD be stale,
# to be checked by an agent that reads both ends. It is not a gate check and must not be
# wired in as one. There is no false-positive concept because there is no judgment; a
# verdict-grade version would need an FP measurement that has not been made.
#
# But it DOES fail when it could not look. An unusable scope exits non-zero (see below),
# because a tool whose only failure mode is a usage error cannot tell a remediator that
# it read the wrong tree — and an empty worklist off the wrong tree is this release's own
# signature defect, a check that cannot fire reading exactly like one that passed.
#
# WHY IT EXISTS.
#
# The reference consumer ran a `[story]` gate for ELEVEN adjudication passes and
# stopped. Pass 11's own verdict named the generator: an 18-line insertion into
# `docs/architecture.md` (`@@ -1476,0 +1477,18 @@`) shifted every line below it by +18,
# and "every prior sweep (all of which scoped only `docs/escalations/pending.md`) read
# clean." Pass 9 had corrected two citations in `traceability-matrix.md` and left the
# identical two in `test-strategy.md` — a file-local fix for a corpus-wide defect.
# Each pass rediscovered one more hop by hand, at the cost of a full adversary dispatch
# to find it and a full remediator dispatch to fix it.
#
# The sweeps were hand-scoped because nobody derived the scope. The scope is derivable:
# the diff already says which files moved and where the movement starts. That is the
# whole of this script.
#
# `validate-artifact-derivations.sh` cannot reach this class — it re-runs claims the
# author fenced as ```derived```, and pass 6's defect was prose outside the fences while
# pass 8's was a JSON file. A `path:line` citation is not a fenced derivation; it is a
# bare cross-reference, and there are thousands of them.
#
# WHAT IT DOES, in three steps.
#
#   1. `git diff -U0 <base>` -> every LINE-SHIFTING hunk, i.e. one whose old line count
#      differs from its new line count. A hunk that replaces 3 lines with 3 lines moves
#      nothing below it and is ignored. Per shifted file it keeps the FIRST shifted old
#      line number: everything at or below that line has moved.
#   2. Scan the MUTABLE current-sprint corpus for citations of the form `path:N`,
#      backtick-delimited, the path carrying a known source/doc extension.
#   3. Emit every citation whose target is a shifted file and whose N is at or below
#      that file's first shift. "Below" is document order — a LARGER line number.
#
# THE FROZEN SET IS A DECLARATION, NOT A HEURISTIC, and it is declared once below
# rather than scattered through the code. Its members are artifacts that are immutable
# by construction — a review record, an adversarial pass, an archived cycle, a history
# file, a verdict. A stale citation inside one of those is not a defect: it is an
# accurate record of what an earlier pass read. Repairing it would falsify the record.
#
# Measured on the reference consumer at commit 0fd25d10d, base HEAD~1, sprint s302, over a
# TRACKED-ONLY corpus — the rule in force at the time, and the one the untracked-file defect
# below replaced. Both figures are floors under the current rule:
#
#     shifting files 31   mutable corpus 455 files   WORKLIST 10
#     with --no-frozen:   corpus 1956 files          WORKLIST 48
#
# The pairing is the point. A worklist of 10 out of a corpus of 455 is only evidence
# that the filter is doing work if the same run without the filter returns a bigger
# number over a bigger corpus. Ten items is a size a remediator can check; forty-eight,
# most of them frozen review records, is a size it will skim.
#
# CONTROLS ARE PRINTED IN BAND, because a zero here is the failure mode. An empty
# worklist is the same output whether nothing moved, nothing was scanned, or everything
# is genuinely consistent. So the header always states the shifting-file count and the
# corpus file count, and a zero in either is called out as an instrument reading rather
# than a clean result. The header also states how much of the corpus is UNTRACKED, for the
# same reason in the other direction: that half is admitted on the strength of a consumer's
# .gitignore, and a number nobody prints is a cost nobody can see.
#
# AND THE SCOPING ZERO IS WIRED TO THE EXIT CODE, not only to a printed note. The two
# are different readers: a note is for an agent that reads the output, an exit code is
# for the step that runs this and moves on. Measured, from a real hand-run against the
# reference consumer's cwd using the DISTRIBUTION copy of this script: it resolved to
# the ai-dlc repo instead, printed `shifting files: 1, corpus 51, worklist 0`, and
# exited 0. Every number there is garbage and the shape is indistinguishable from a
# consumer whose citations are all sound.
#
# Exit: 0  the scope resolved; the worklist below is meaningful, EMPTY OR NOT
#       2  usage, an unresolvable ref, or not a git repository
#       3  SCOPING FAILURE — no current sprint, or the current sprint contributed no
#          corpus. Nothing was judged and nothing can be concluded from the empty
#          worklist. This is the wrong-tree exit.
set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

# ============================================================================
# DECLARATIONS — the three sets this script is defined by. Change behaviour here,
# not in the scanner.
# ============================================================================

# 1. THE CITATION GRAMMAR. A citation is `path:N` inside backticks, where the path
#    ends in one of these. Anything else is prose that happens to contain a colon.
CITED_EXTS="md json jsonl sh ts tsx js jsx py yaml yml sql txt toml"

# 2. THE CORPUS ROOTS. Where a live cross-artifact citation can live. Each is
#    relative to the project root; `!` marks a root scanned NON-recursively (its
#    depth-1 files only). `@SPRINT@` expands to the current sprint directory name.
#
#    `_bmad-output` is depth-1 only on purpose: its top level holds the live pipeline
#    records (the snapshot, the continuation log), while its subtrees hold 280-odd
#    prior sprints, party-mode transcripts and retro archives that are all frozen by
#    construction. Naming the two current-sprint subtrees explicitly is narrower and
#    cheaper than admitting the whole subtree and then excluding 99% of it.
CORPUS_ROOTS="
docs
_bmad-output/planning-artifacts/@SPRINT@
_bmad-output/implementation-artifacts/@SPRINT@
!_bmad-output
"

# 3. THE FROZEN SET — excluded from the corpus because these artifacts are immutable
#    review records. A stale citation in one of them is a true record of what an
#    earlier pass read, and repairing it destroys evidence.
#
#    Path components: a directory anywhere in the path with this name freezes the file.
#    `reviews` is here for `docs/reviews/`, the completed sprint-review record set.
FROZEN_PATH_COMPONENTS="archive gate-adjudication stories-party-mode reviews advanced-elicitation"

#    Basename globs, matched against the file name only.
FROZEN_NAME_GLOBS="
*-adversarial-p*.md
*-ar-pass*.md
*-repair*.md
verdict-*
*.pre.*
*-history.md
*-archive.md
*-archive-*.md
*advelicit*
*advanced-elicitation*
"

#    And: any sprint directory other than the current one. A path component matching
#    `s<digits>` or `sprint-<digits>` that is not the current sprint is frozen —
#    that sprint is closed, and its artifacts cite the tree as it stood then.
FROZEN_SPRINT_DIRS_OTHER_THAN_CURRENT=1

# ============================================================================

usage() {
  cat >&2 <<'USAGE'
usage: report-propagation-fanout.sh <base-ref> [<head-ref>] [--sprint sNNN] [--no-frozen]

  <base-ref>     the state the citations were valid against
  <head-ref>     optional; omit to diff <base-ref> against the working tree
  --sprint sNNN  override current-sprint detection (default: sprint-status.yaml)
  --no-frozen    scan the frozen set too. This is the CONTROL: run it beside the
                 default and compare. It is not a more thorough mode.
USAGE
  exit 2
}

BASE=""; HEAD_REF=""; SPRINT=""; APPLY_FROZEN=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --sprint) [ "$#" -ge 2 ] || usage; SPRINT="$2"; shift 2 ;;
    --no-frozen) APPLY_FROZEN=0; shift ;;
    -h|--help) usage ;;
    -*) echo "ERROR: unknown option $1" >&2; usage ;;
    *)
      if [ -z "$BASE" ]; then BASE="$1"
      elif [ -z "$HEAD_REF" ]; then HEAD_REF="$1"
      else echo "ERROR: too many refs ($1)" >&2; usage
      fi
      shift ;;
  esac
done
[ -n "$BASE" ] || usage

cd "$AI_DLC_ROOT" || { echo "ERROR: cannot cd to $AI_DLC_ROOT" >&2; exit 2; }

git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "ERROR: $AI_DLC_ROOT is not a git repository; this script derives its scope" >&2
  echo "  from a diff and has nothing to derive it from here." >&2
  exit 2
}
git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null || {
  echo "ERROR: base ref '${BASE}' does not resolve to a commit." >&2
  exit 2
}
if [ -n "$HEAD_REF" ]; then
  git rev-parse --verify --quiet "${HEAD_REF}^{commit}" >/dev/null || {
    echo "ERROR: head ref '${HEAD_REF}' does not resolve to a commit." >&2
    exit 2
  }
fi

# Current sprint. Declared in sprint-status.yaml; the directory-scan fallback exists
# so a consumer mid-restructure still gets a scope rather than an empty corpus.
if [ -z "$SPRINT" ]; then
  for f in _bmad-output/planning-artifacts/sprint-status.yaml \
           _bmad-output/implementation-artifacts/sprint-status.yaml; do
    [ -f "$f" ] || continue
    n="$(sed -n 's/^sprint:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$f" | head -1)"
    [ -n "$n" ] && { SPRINT="s${n}"; break; }
  done
fi
if [ -z "$SPRINT" ] && [ -d _bmad-output/planning-artifacts ]; then
  SPRINT="$(ls -1 _bmad-output/planning-artifacts 2>/dev/null \
            | sed -n 's/^s\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)"
  [ -n "$SPRINT" ] && SPRINT="s${SPRINT}"
fi

if [ -n "$HEAD_REF" ]; then
  DIFF="$(git -c core.quotepath=false diff -U0 "$BASE" "$HEAD_REF")"
  RANGE="${BASE}..${HEAD_REF}"
else
  DIFF="$(git -c core.quotepath=false diff -U0 "$BASE")"
  RANGE="${BASE}..<working tree>"
fi

# THE CORPUS IS TRACKED **PLUS** UNTRACKED-NOT-IGNORED, and the second half is here
# because the first half alone produced this script's own signature failure.
#
# The original text read: "The corpus is the tracked file set. Untracked scratch under
# docs/ is not an artifact anyone cites, and including it made the corpus 47% larger
# without moving the worklist." That measurement was real, and it was taken over one
# consumer's untracked set at one instant — which is the population that varies most.
# It is a COST argument, never a correctness one, and it was superseded by a measurement
# of the correctness cost.
#
# Filed by the reference consumer, sprint 306: this project never `git add`s
# planning/implementation artifacts mid-sprint (they are committed at PR time), so every
# artifact a remediator writes DURING the sprint is untracked at the moment this script
# runs. `git ls-files` could not see them, the sprint-scoped roots contributed nothing,
# and the run exited 3 with `SCOPING FAILURE: sprint 306 was declared, but not one
# corpus file came from its artifact directory` — over a tree that held those files at
# exactly the right path. The wrong-tree exit, fired on the right tree. The caller is
# the gate remediation loop, which runs mid-sprint by construction, so this is not an
# edge case: it is the tool's ONLY operating condition.
#
# `--exclude-standard` is load-bearing and not decoration. Measured on the reference
# consumer: `git ls-files --others` alone lists 84309 files, 12641 of them under `docs/`
# or `_bmad-output/` — build output, caches and node_modules that would swamp a corpus of
# a few hundred. With `--exclude-standard` that same tree contributes 0, because neither
# corpus root is gitignored there (`git check-ignore` exits 1 on a probe under each).
#
# The admitted set is REPORTED IN BAND rather than argued about here, because a one-instant
# measurement of somebody else's untracked set cannot be carried across consumers. The
# header prints how many corpus files came from the untracked half, so a consumer whose
# .gitignore is imperfect sees the number on the run that matters instead of in a comment.
CORPUS_TRACKED="$(git ls-files -z | tr '\0' '\n')"
CORPUS_UNTRACKED="$(git ls-files --others --exclude-standard -z | tr '\0' '\n')"
CORPUS_FILES="$(printf '%s\n%s\n' "$CORPUS_TRACKED" "$CORPUS_UNTRACKED")"

# THE THREE UNBOUNDED PAYLOADS TRAVEL BY FILE, NEVER BY THE ENVIRONMENT.
#
# `execve` charges its combined argv+envp ceiling on the environment block the CHILD
# INHERITS, so reading the python program from a heredoc on stdin buys nothing at all
# while the data it parses is exported: the exec fails with `Argument list too long`
# before python3's first line runs, and bash reports that as 126 — a code this script's
# own contract above does not list. Filed twice by the reference consumer against one
# script (`PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF`,
# `PC-S303-FANOUT-SCRIPT-ARG-MAX-VIA-EXPORTED-DIFF-ENV-VAR`), from two different sprint
# steps, on a real 274-file / +64,540-line range.
#
# THE CORPUS IS THE FIXED COST AND THE DIFF IS ONLY WHAT TIPS IT OVER, which is why all
# three payloads move and not just the one the first filing named. Measured: on the
# reference consumer `git ls-files` alone is 607945 bytes across 10146 paths against an
# `ARG_MAX` of 1048576 — 58% of the ceiling consumed before a single byte of diff
# exists. A fix that relocates `FANOUT_DIFF` alone leaves that 58% in place and leaves
# the ceiling reachable, so it would close the filing and not the defect.
#
# The remaining `FANOUT_*` variables stay on the environment deliberately: each is a
# short scalar or a fixed declaration from this file, none scales with the tree, and
# moving them would trade a real bound for churn.
FANOUT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/fanout.XXXXXX")" || {
  echo "SCOPING FAILURE: could not create a temporary directory for the payloads" >&2
  exit 3
}
trap 'rm -rf "$FANOUT_TMP"' EXIT
# `printf '%s'` and NOT `'%s\n'`: each of these three held the value of a command
# substitution, which has already stripped its trailing newlines, and the python side
# splits on lines. Adding one back here would be a second, silently different corpus.
printf '%s' "$DIFF"              > "$FANOUT_TMP/diff"      || exit 3
printf '%s' "$CORPUS_FILES"      > "$FANOUT_TMP/files"     || exit 3
printf '%s' "$CORPUS_UNTRACKED"  > "$FANOUT_TMP/untracked" || exit 3

export FANOUT_DIFF_FILE="$FANOUT_TMP/diff" \
       FANOUT_FILES_FILE="$FANOUT_TMP/files" \
       FANOUT_UNTRACKED_FILE="$FANOUT_TMP/untracked" \
       FANOUT_SPRINT="$SPRINT" \
       FANOUT_RANGE="$RANGE" FANOUT_APPLY_FROZEN="$APPLY_FROZEN" \
       FANOUT_EXTS="$CITED_EXTS" FANOUT_ROOTS="$CORPUS_ROOTS" \
       FANOUT_FROZEN_COMPONENTS="$FROZEN_PATH_COMPONENTS" \
       FANOUT_FROZEN_GLOBS="$FROZEN_NAME_GLOBS" \
       FANOUT_FROZEN_SPRINTS="$FROZEN_SPRINT_DIRS_OTHER_THAN_CURRENT"

python3 - <<'PYEOF'
import os, re, sys, fnmatch

def payload(var):
    """Read one of the three large payloads the shell wrote to a file.

    A missing or unreadable file EXITS, and never returns "". An empty diff and an
    empty corpus are both legal inputs that print a clean, plausible zero, so a
    permissive read failure here would delete every finding and still exit 0 — the
    exact shape this script's own header calls its signature defect. 3 is the
    contract's wrong-tree code and is the closest true statement: nothing was judged.

    `sys.getfilesystemencoding()` with `surrogateescape` is what `os.environ` itself
    used to decode these values when they travelled on the environment, so a path
    that is not valid UTF-8 survives the move unchanged.
    """
    path = os.environ[var]
    try:
        with open(path, "r", encoding=sys.getfilesystemencoding(),
                  errors="surrogateescape") as fh:
            return fh.read()
    except OSError as exc:
        sys.stderr.write("SCOPING FAILURE: could not read %s (%s): %s\n"
                         % (var, path, exc))
        sys.exit(3)

diff       = payload("FANOUT_DIFF_FILE")
sprint     = os.environ["FANOUT_SPRINT"]
rng        = os.environ["FANOUT_RANGE"]
apply_frz  = os.environ["FANOUT_APPLY_FROZEN"] == "1"
exts       = tuple(os.environ["FANOUT_EXTS"].split())
components = set(os.environ["FANOUT_FROZEN_COMPONENTS"].split())
globs      = [g for g in os.environ["FANOUT_FROZEN_GLOBS"].split() if g]
frz_sprint = os.environ["FANOUT_FROZEN_SPRINTS"] == "1"

roots_rec, roots_flat, roots_sprint = [], [], []
for r in os.environ["FANOUT_ROOTS"].split():
    sprint_scoped = "@SPRINT@" in r
    r = r.replace("@SPRINT@", sprint) if sprint else r
    if "@SPRINT@" in r:
        continue
    flat = r.startswith("!")
    r = r.lstrip("!").rstrip("/")
    (roots_flat if flat else roots_rec).append(r)
    if sprint_scoped:
        roots_sprint.append(r)

# --- step 1: the line-shifting hunks -----------------------------------------
# A hunk shifts when its old and new line counts differ. `@@ -a,b +c,d @@` with the
# count omitted means 1, and a count of 0 means a pure insertion/deletion point —
# both of which shift. Per file we keep the SMALLEST shifted old line number: it is
# the highest point in the file below which nothing can be trusted.
hunk = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
first_shift = {}
cur = None
for line in diff.splitlines():
    if line.startswith("+++ "):
        p = line[4:]
        cur = None if p == "/dev/null" else (p[2:] if p.startswith("b/") else p)
        if cur and cur.startswith('"') and cur.endswith('"'):
            # git quotes paths carrying control or non-ASCII bytes even with
            # core.quotepath=false. Unquote enough to match; exotic escapes are rare
            # enough here that a miss costs a worklist entry, not a wrong verdict.
            try:
                cur = cur[1:-1].encode().decode("unicode_escape")
            except Exception:
                pass
    elif cur and line.startswith("@@"):
        m = hunk.match(line)
        if not m:
            continue
        old_start = int(m.group(1))
        old_count = 1 if m.group(2) is None else int(m.group(2))
        new_count = 1 if m.group(4) is None else int(m.group(4))
        if old_count != new_count:
            if cur not in first_shift or old_start < first_shift[cur]:
                first_shift[cur] = old_start

# Only files a citation could name. A shifted file with no citable extension can
# never be a worklist target, so counting it in the header would overstate the scope.
first_shift = {p: n for p, n in first_shift.items()
               if p.rsplit(".", 1)[-1] in exts and "." in os.path.basename(p)}

# --- step 2: the mutable corpus ----------------------------------------------
sprint_dir = re.compile(r"^(?:s\d+|sprint-\d+)$")

def in_corpus_roots(p):
    for r in roots_rec:
        if p == r or p.startswith(r + "/"):
            return True
    for r in roots_flat:
        if p.startswith(r + "/") and "/" not in p[len(r) + 1:]:
            return True
    return False

def is_frozen(p):
    parts = p.split("/")
    for c in parts[:-1]:
        if c in components or c.startswith("archive-"):
            return True
        if frz_sprint and sprint_dir.match(c) and c != sprint:
            return True
    base = parts[-1]
    return any(fnmatch.fnmatch(base, g) for g in globs)

def under_sprint_root(p):
    return any(p == r or p.startswith(r + "/") for r in roots_sprint)

# The untracked half of the corpus, as its own set. It is counted separately and printed
# in band: a consumer whose .gitignore is imperfect admits junk here, and the only honest
# place to say how much is the run itself. `git ls-files` can emit the same path twice
# (an unmerged path lists once per stage), so the corpus is de-duplicated while keeping
# document order — a duplicate would double-count a citation into the worklist.
untracked = set(p for p in payload("FANOUT_UNTRACKED_FILE").splitlines() if p)

corpus = []
seen = set()
n_sprint_scoped = 0
n_untracked = 0
for p in payload("FANOUT_FILES_FILE").splitlines():
    if not p or p in seen or not in_corpus_roots(p):
        continue
    if "." not in os.path.basename(p) or p.rsplit(".", 1)[-1] not in exts:
        continue
    if apply_frz and is_frozen(p):
        continue
    seen.add(p)
    corpus.append(p)
    if under_sprint_root(p):
        n_sprint_scoped += 1
    if p in untracked:
        n_untracked += 1

# --- step 3: the citations ---------------------------------------------------
cite = re.compile(r"`\.?/?([A-Za-z0-9._][A-Za-z0-9._/+-]*\.(?:%s)):(\d+)`"
                  % "|".join(re.escape(e) for e in exts))

# A citation may be written repo-root-relative or as a bare filename. Index the
# shifted files by every path suffix so both resolve, and emit ALL matches when a
# bare name is ambiguous — this returns work to check, so over-inclusion is correct.
by_suffix = {}
for p, n in first_shift.items():
    parts = p.split("/")
    for i in range(len(parts)):
        by_suffix.setdefault("/".join(parts[i:]), []).append((p, n))

work = set()
unreadable = 0
for f in corpus:
    try:
        with open(f, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        unreadable += 1
        continue
    if "`" not in text:
        continue
    for lineno, line in enumerate(text.splitlines(), 1):
        for m in cite.finditer(line):
            target, n = m.group(1), int(m.group(2))
            for path, shift in by_suffix.get(target, ()):
                if n >= shift:
                    work.add((f, lineno, path, n, shift))

# --- report ------------------------------------------------------------------
out = sys.stdout.write
out("propagation fan-out worklist — %s\n" % rng)
out("  sprint:         %s\n" % (sprint or "UNDETECTED"))
out("  shifting files: %d\n" % len(first_shift))
out("  mutable corpus: %d files%s\n"
    % (len(corpus), "" if apply_frz else "   [--no-frozen: this is the CONTROL run]"))
out("    of those, from the current sprint: %d\n" % n_sprint_scoped)
out("    of those, untracked (not yet git-added): %d\n" % n_untracked)
out("  frozen set:     %s\n" % ("applied" if apply_frz else "DISABLED"))
if unreadable:
    out("  unreadable:     %d file(s) skipped\n" % unreadable)
out("\n")

# THE SCOPING FAILURE. Three ways the scope can be unusable, and all three produce the
# same empty worklist a healthy corpus produces, so all three exit 3 rather than 0.
#
# "No sprint" is a scoping failure and not a legitimate empty: a consumer running this
# is mid-sprint by construction — the caller is the gate remediation loop — and
# sprint-status.yaml declares the number on every real one. No sprint means the root
# resolved somewhere that is not a consumer.
#
# A sprint that contributes NO corpus is the same failure one level in: the number was
# read from somewhere, but the tree it names is not here. That is the wrong-tree case
# that reads most like a clean result, because `docs/` still supplies a plausible corpus.
scope_fail = []
if not sprint:
    scope_fail.append(
        "no current sprint could be detected. sprint-status.yaml was not found or\n"
        "  carries no sprint number, so the sprint-scoped corpus roots dropped out\n"
        "  entirely. Either the resolved project root is not a consumer, or you must\n"
        "  pass --sprint.")
elif roots_sprint and n_sprint_scoped == 0:
    scope_fail.append(
        "sprint %s was declared, but not one corpus file came from its artifact\n"
        "  directory. The tree this root resolved to does not hold that sprint."
        % sprint)
if not corpus:
    scope_fail.append(
        "the corpus is empty — every candidate was filtered out. Re-run with\n"
        "  --no-frozen to see whether the frozen set swallowed it.")

for msg in scope_fail:
    out("SCOPING FAILURE: %s\n\n" % msg)

# This one is NOT a scoping failure. The scope was established and the diff genuinely
# moved nothing, which is a real and common answer.
if first_shift == {} and not scope_fail:
    out("NOTE: the diff contains no line-shifting hunk in a citable file. An empty\n"
        "  worklist here means nothing moved, NOT that the citations were checked.\n\n")

out("WORKLIST (%d)\n" % len(work))
if work:
    for f, lineno, path, n, shift in sorted(work):
        out("  %s:%d  ->  %s:%d   (first shift %d)\n" % (f, lineno, path, n, shift))
    out("\nEach line is a citation whose target moved at or above the cited line. Open\n"
        "both ends and re-derive it. This is a worklist, not a verdict — a citation\n"
        "here may still be correct.\n")
else:
    out("  (none — subject to the controls above)\n")

if scope_fail:
    out("\nExiting 3: the scope was never established, so the worklist above is not a\n"
        "statement about this repository's citations. Nothing here was judged.\n")
    sys.exit(3)
PYEOF

exit $?
