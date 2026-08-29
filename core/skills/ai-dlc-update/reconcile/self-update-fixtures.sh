#!/usr/bin/env bash
# self-update-fixtures.sh — run step 2's derived covering fixtures AND persist their
# output, so a red self-update leaves evidence behind instead of a discarded branch.
#
# WHY THIS EXISTS. Step 2's cycle cuts a branch, writes the machinery slice, runs the
# derived fixtures, and ON RED discards the branch and restores the tree — writing
# nothing. `reconcile-log-<ts>.md` is step-7 only; `reconcile-report.md` is not written
# until step 5, by which time the tree state the fixtures ran against is gone. So the
# one cycle in this skill that runs a TEST SUITE was the only one that persisted no
# record of it: the failing output survived in the operating agent's context and
# nowhere else, and no command in the report reproduced the state that produced it.
#
# MEASURED ON THE REFERENCE CONSUMER, TWICE. On the `0.249.0 -> 0.262.0` run the
# evidence had to be recovered afterwards by re-staging the discarded slice on a second
# throwaway branch. On `0.249.0 -> 0.263.0` the operator captured it by hand from inside
# the cycle — which is not something the skill instructs, and is therefore not something
# the next operator will do. Both runs turned on ONE fixture's output; without it the
# only available conclusion was "the self-update failed".
#
# SO THE FIX IS A CARRIER, NOT A SENTENCE. Step 2 previously said "report the fixture
# name and its output", and that instruction was obeyed by an agent that then discarded
# the tree. A prose duty with no artifact behind it is the class this repo keeps
# re-learning: prefer a mechanism the step INVOKES over a rule it must remember.
#
# Usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...
#   dist-repo      path to the distribution git checkout. READ AS A REPO, not decoration:
#                  the coverage join below derives its side from `base..theirs` in it.
#   base-sha       the `commit` field from the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref
#   consumer-root  the consumer project root (contains .claude/)
#   fixture...     the derived covering fixture DIRECTORY NAMES, as step 2 derived them
#
# Step 2 derives that set in TWO terms and this file treats them differently.
#
# The FIRST term — fixtures whose `*.sh` name a machinery path the diff moved — is passed
# IN rather than re-derived here. It is grepped from the fixtures themselves, and a second
# derivation of it in this file would be two derivations to keep in agreement — the exact
# drift `lib.sh` exists to end for the section resolver.
#
# The SECOND term — the fixtures the diff ITSELF touches — is derived HERE, and joined
# against the named set rather than added to it. That is not the duplication the paragraph
# above refuses: one side comes from `base..theirs`, the other is what step 2 passed, and a
# disagreement is the finding. It exists because the first term cannot see a fixture the
# pull REPAIRS: such a fixture's only change is its own driver, so it names no moved
# machinery path and falls outside the grep by construction — while the consumer's pre-push
# runs the WHOLE suite, so the unrepaired copy stays red and blocks the very push this
# cycle is making. Measured over 69 release-to-release ranges of the distribution: 16 carry
# at least one SHIPPING fixture in exactly that state.
#
# Output: a per-fixture verdict line on stdout, then the log path.
# Exit:   0 all green · 1 at least one red · 2 the harness could not run
#         (no fixtures named, fixture root underivable, log unwritable, the `base..theirs`
#         range unresolvable, or the named set omitting a fixture the diff changes). A run
#         that could not happen must NOT exit 0: "no failures" and "no assertions" are the
#         same byte to the caller, and this whole file exists because that difference
#         was invisible once already. An INCOMPLETE set is the same class — a slice missing
#         the fixture that guards it reports green over the gap.
set -u

DIST="${1:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
BASE="${2:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
THEIRS="${3:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
CONSUMER="${4:?usage: self-update-fixtures.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> <fixture>...}"
shift 4

# Absolutized for the same reason layer-drift.sh absolutizes it: readers here run with a
# changed working directory, and a relative root would resolve against whichever one is
# current at the time.
CONSUMER="$(cd "$CONSUMER" 2>/dev/null && pwd)" || {
  echo "self-update-fixtures: consumer-root not a directory: ${4}" >&2; exit 2; }

if [ $# -eq 0 ]; then
  echo "self-update-fixtures: no fixtures named — refusing to report a green run over an empty set." >&2
  echo "  pass the derived covering fixture directory names as arguments." >&2
  exit 2
fi

SELF="$(cd "$(dirname "$0")" && pwd)"

# The consumer's fixture root, DERIVED from the mapper rather than written here — the
# same probe `retired-fixtures.sh` uses, and for the same reason: `install.sh` splits
# what shares a parent in `core/`, and I33 fails the build on anything that reaches one
# core path by walking up from another.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)"
if ! command -v map_consumer >/dev/null 2>&1; then
  echo "self-update-fixtures: could not load map_consumer() from preclassify.sh — refusing to" >&2
  echo "  fall back to a private path table, which would answer for one layout and be silently" >&2
  echo "  wrong in the other." >&2
  exit 2
fi
fx_rel="$(map_consumer "core/fixtures/__probe__/run.sh")"
FX_ROOT="${fx_rel%/__probe__/run.sh}"
if [ "$FX_ROOT" = "$fx_rel" ] || [ -z "$FX_ROOT" ]; then
  echo "self-update-fixtures: map_consumer() did not map a core fixture path to a consumer one," >&2
  echo "  so the consumer's fixture root could not be derived. Nothing was run." >&2
  exit 2
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$CONSUMER/_bmad-output/ai-dlc-update"
# `.md`, DELIBERATELY. A reference consumer's .gitignore carries `*.log` and `*.txt`, so
# either extension would produce an artifact that exists on disk and vanishes from every
# `git status` the operator reads afterwards.
LOG="$OUT_DIR/self-update-fixtures-${TS}.md"
mkdir -p "$OUT_DIR" 2>/dev/null || { echo "self-update-fixtures: cannot create $OUT_DIR" >&2; exit 2; }
: > "$LOG" 2>/dev/null || { echo "self-update-fixtures: cannot write $LOG" >&2; exit 2; }

{
  echo "# ai-dlc-update step-2 self-update — derived fixture run"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# base $BASE -> theirs $THEIRS"
  echo "# consumer: $CONSUMER   dist: $DIST"
  echo "# fixture root: $FX_ROOT   fixtures named: $#"
  echo "# The tree this ran against is the machinery slice, and step 2 DISCARDS it on red."
  echo "# Nothing below is reproducible from the tree once that has happened."
  echo ""
} >> "$LOG"

# --- The COVERAGE join: every fixture the DIFF changes must be in the named set ----------
# One side derived here from `base..theirs`, the other passed in by step 2. Run BEFORE the
# fixtures, because an incomplete set that runs green is the state this arm exists to refuse
# and running it first would only produce a plausible green above the finding.
#
# THE TERM IS JOINED AGAINST THE NAMED SET, NEVER ADDED TO IT, and the reason is that this
# file cannot write a fixture into the consumer — only step 2's slice can, and nothing here
# copies into `$CONSUMER`. So ADDING a diff-touched dir to the run set would execute the
# consumer's STALE copy: red with no remedy, because nothing here can reach step 2 to tell it
# what to carry, or green over a repair that was never delivered — which is the
# "no failures and no assertions are the same byte" collapse this whole file exists to refuse.
#
# Both refs are resolved first. An unresolvable range means the join did not run, and a join
# that did not run reads exactly like one that found nothing — so it is exit 2, never a
# silent skip. In the real cycle `$DIST` is the checkout the slice was computed from and
# both refs are the ones that computed it, so this arm is unreachable on correct input.
for r in "$BASE" "$THEIRS"; do
  git -C "$DIST" rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1 && continue
  echo "self-update-fixtures: cannot resolve '${r}' in $DIST, so the diff-side coverage join" >&2
  echo "  could not run. A coverage check that did not run reads exactly like one that passed." >&2
  { echo "COVERAGE: UNRESOLVABLE — '${r}' does not name a commit in $DIST. Nothing was run."; } >> "$LOG"
  exit 2
done

# AND `$DIST` MUST BE THE DISTRIBUTION, not merely a git repo. A checkout with no
# `core/fixtures/` at `theirs` returns an EMPTY diff, `uncovered` stays empty, and the join
# reports nothing having observed nothing — a pass that is indistinguishable from a complete
# set. That state is reachable, not theoretical: a caller resolving `$DIST` by walking up from
# a CONSUMER-layout copy of this script lands on the consumer root, which is a git repo whose
# `theirs` carries no `core/fixtures` tree.
#
# IT IS THE PAIR THAT CLOSES THIS, NOT THIS ARM ALONE. This one asks whether the repo has the
# right SHAPE; the ref resolution above asks whether it has the right HISTORY, `$BASE` being
# the consumer's own stamp sha. Either alone admits a wrong repo that satisfies it. Do NOT
# also require the diff-side set to be NON-EMPTY: a pull touching no fixture at all is an
# ordinary pull, and failing it would be a check firing on correct data.
if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures" 2>/dev/null; then
  echo "self-update-fixtures: '${THEIRS}' in $DIST has no core/fixtures tree, so \$DIST is not" >&2
  echo "  the distribution and the coverage join would pass over an empty set. Nothing was run." >&2
  { echo "COVERAGE: WRONG-REPO — '${THEIRS}:core/fixtures' does not resolve in $DIST."; } >> "$LOG"
  exit 2
fi

# The diff is taken into a variable, not straight into the loop, so its STATUS is readable:
# inside a `$( )` fed to a heredoc it would be lost to a subshell, and a diff that failed
# would arrive as an empty set — the coverage join reporting nothing to cover, which is the
# exact silent pass the ref resolution above refuses.
cov_raw="$(git -C "$DIST" diff --name-only "$BASE" "$THEIRS" -- core/fixtures/)" || {
  echo "self-update-fixtures: git diff ${BASE}..${THEIRS} failed in $DIST, so the diff-side" >&2
  echo "  coverage join could not run. Nothing was run." >&2
  { echo "COVERAGE: UNRESOLVABLE — git diff ${BASE}..${THEIRS} failed in $DIST."; } >> "$LOG"
  exit 2
}

# Exemptions, and each one is a state where the slice is RIGHT to omit the directory:
#   `.dist-only` at theirs — never shipped, so it cannot exist on a consumer to run;
#   no `run.sh` at theirs  — deleted upstream, so there is nothing to write.
# Both are read AT THEIRS. Reading them from the distribution checkout instead answers for
# whatever is on disk, which is a different tree from the one being delivered.
#
# The `grep` before the `sed` is not decoration: a path directly under `core/fixtures/` with
# no directory component does not match the substitution, and `sed` passes a non-match through
# UNCHANGED — so the whole path would enter the set as a bogus directory name. It would then
# be swallowed by the deleted-upstream exemption and report as nothing at all.
uncovered=""
while IFS= read -r d; do
  [ -n "$d" ] || continue
  git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/.dist-only" 2>/dev/null && continue
  git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/run.sh" 2>/dev/null || continue
  case " $* " in *" ${d} "*) continue ;; esac
  uncovered="$uncovered $d"
done <<COVEOF
$(printf '%s\n' "$cov_raw" | grep -E '^core/fixtures/[^/]+/' \
  | sed -E 's#^core/fixtures/([^/]+)/.*#\1#' | sort -u)
COVEOF

if [ -n "$uncovered" ]; then
  { echo "COVERAGE: the diff changes these shippable fixtures and the named set omits them:"
    for d in $uncovered; do echo "  $d"; done
    echo ""; } >> "$LOG"
  echo "self-update-fixtures: the slice omits fixtures this diff CHANGES:${uncovered}" >&2
  echo "  Step 2's first fixture term greps the fixtures for machinery paths the diff moved." >&2
  echo "  A fixture the pull REPAIRS names none of them, so that term cannot see it — and the" >&2
  echo "  consumer's pre-push runs the whole suite, so its unrepaired copy blocks the push this" >&2
  echo "  cycle is making. Add the diff-touched fixtures to the slice and re-run." >&2
  echo "  log: $LOG" >&2
  exit 2
fi

n_run=0; n_ok=0; n_fail=0; n_missing=0; reds=""
for name in "$@"; do
  dir="$CONSUMER/$FX_ROOT/$name"
  {
    echo "===== FIXTURE $name ====="
  } >> "$LOG"
  if [ ! -f "$dir/run.sh" ]; then
    # A named fixture with no driver is NOT a pass. It means the slice did not write what
    # the derivation said it would, which is a finding about the cycle rather than about
    # the fixture.
    n_missing=$((n_missing + 1)); reds="$reds $name"
    echo "self-update-fixtures: MISSING $FX_ROOT/$name/run.sh" >&2
    { echo "MISSING: $FX_ROOT/$name/run.sh — the slice did not write this fixture's driver."
      echo "----- rc=missing -----"; echo ""; } >> "$LOG"
    printf '   MISS  %s\n' "$name"
    continue
  fi
  # cwd is the CONSUMER ROOT, because that is where both pre-push hooks run a fixture
  # from (`bash "$d/run.sh"` with the repo root current). A fixture whose verdict depends
  # on the caller's directory has been shipped before — see v0.263.0 — so the runner that
  # decides a self-update must stand exactly where the gate that decides a push stands.
  ( cd "$CONSUMER" && bash "$FX_ROOT/$name/run.sh" ) >> "$LOG" 2>&1
  rc=$?
  { echo "----- rc=$rc -----"; echo ""; } >> "$LOG"
  n_run=$((n_run + 1))
  if [ "$rc" -eq 0 ]; then
    n_ok=$((n_ok + 1)); printf '   ok    %s\n' "$name"
  else
    n_fail=$((n_fail + 1)); reds="$reds $name"; printf '   FAIL  %s\n' "$name"
  fi
done

{
  echo "# summary: $n_ok green, $n_fail red, $n_missing missing, of $# named"
  [ -n "$reds" ] && echo "# red:${reds}"
} >> "$LOG"

echo ""
echo "self-update fixtures: $n_ok green, $n_fail red, $n_missing missing, of $# named"
echo "log: $LOG"

# The completeness assertion, and it is not decoration: a loop that silently skipped a
# fixture would otherwise report every fixture it DID run as green and exit 0.
if [ $((n_run + n_missing)) -ne $# ]; then
  echo "self-update-fixtures: ran $n_run + $n_missing missing, but $# were named — the loop did not reach every fixture." >&2
  exit 2
fi

[ "$n_fail" -eq 0 ] && [ "$n_missing" -eq 0 ]
