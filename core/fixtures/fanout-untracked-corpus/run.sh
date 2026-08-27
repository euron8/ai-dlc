#!/usr/bin/env bash
# fanout-untracked-corpus — report-propagation-fanout.sh's corpus is tracked PLUS
# untracked-not-ignored, and each of those three words is load-bearing.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# The corpus was sourced from `git ls-files`, which lists TRACKED files only. The
# reference consumer never `git add`s planning/implementation artifacts mid-sprint —
# they are committed at PR time — so every artifact a remediator writes DURING a sprint
# is untracked at the moment this script runs. Reproduced by that consumer at sprint 306,
# with two real files on disk under `_bmad-output/planning-artifacts/s306/`:
#
#     mutable corpus: 1 files
#       of those, from the current sprint: 0
#     SCOPING FAILURE: sprint 306 was declared, but not one corpus file came from its
#       artifact directory. The tree this root resolved to does not hold that sprint.
#     rc=3
#
# That is exit 3 — the WRONG-TREE exit — fired on the right tree, over files sitting at
# exactly the path the script was looking for. And the script's only caller is the gate
# remediation loop, which runs mid-sprint by construction: the broken state was not an
# edge case, it was the tool's sole operating condition.
#
# WHY THE FIX HAS A SECOND HALF THAT ALSO NEEDS GUARDING. `--exclude-standard` is what
# keeps the union from admitting build output and caches. Measured on that same consumer:
# `git ls-files --others` alone lists 84309 files, 12641 of them under `docs/` or
# `_bmad-output/`, against a legitimate corpus of a few hundred. Dropping the flag is a
# one-word edit that turns an advisory worklist into noise, and no arm here existed to
# see it. So the arms below are a THREE-WAY partition — the untracked half is admitted,
# the ignored files are not, and the tracked half is still there — because a fix that
# lands any one of the three and drops another reads exactly like a fix that worked.
#
# AND THE WRONG-TREE EXIT MUST SURVIVE THE FIX. A change that satisfies a check by
# deleting the check's subject reads as green forever. `SCOPING FAILURE` is the only
# thing standing between this tool and an empty worklist off an unrelated repository, so
# assertion 4 drives a genuinely wrong tree and requires exit 3 to still come back.
#
# WHY THE MUTANTS ARE A `git` SHIM AND NOT A `sed`.
#
# The union can be spelled at least two ways a competent author would write — two
# `ls-files` calls joined, or one `git ls-files --cached --others --exclude-standard`.
# A `sed` keyed on either spelling matches nothing against the other, and a mutation that
# applied to no line scores a kill it never earned. So the mutants intercept `git` itself
# and rewrite the ARGUMENTS of any `ls-files` invocation, which is the location the
# behaviour actually lives at and is the same location under both spellings. Each shim
# records that it really did alter an invocation; an arm whose shim changed nothing
# reports itself unproven rather than passing.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking anything (I10). AI_DLC_PROJECT_ROOT
# is set explicitly per invocation below, and a leaked one would pin every run to the same
# tree and make every comparison here vacuous.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Both install layouts, derived from install.sh's mapping: core/scripts/<x> lands at
# scripts/ai-dlc/<x> on a consumer. A fixture that only knew the distribution path would
# ship inert to the one tree it is written to defend.
SUBJ=""
for cand in "$ROOT/core/scripts/report-propagation-fanout.sh" \
            "$ROOT/scripts/ai-dlc/report-propagation-fanout.sh"; do
  [ -f "$cand" ] && { SUBJ="$cand"; break; }
done
[ -n "$SUBJ" ] || {
  echo "FIXTURE ERROR: report-propagation-fanout.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts (distribution), $ROOT/scripts/ai-dlc (consumer)" >&2
  exit 2
}
# Printed because a mutant applied to a copy the run never loads leaves every arm green,
# and that reads exactly like an arm that cannot fire.
echo "  subject resolved: $SUBJ"

command -v python3 >/dev/null 2>&1 || {
  echo "FIXTURE ERROR: python3 not on PATH; the subject's scanner is a python3 heredoc" >&2
  exit 2
}
REAL_GIT="$(command -v git)" || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/fanout-untracked.XXXXXX")" \
  || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# ============================================================================
# THE TREES
# ============================================================================
# A consumer mid-sprint. `docs/architecture.md` is the SHIFT TARGET: tracked, then given a
# two-line insertion in the working tree, which is the uncommitted state a remediator is
# actually in. Three citing files, one per corpus-membership class, each citing a DIFFERENT
# line so a worklist row names its own class unambiguously:
#
#   docs/tracked-cite.md                             tracked            MUST be scanned
#   _bmad-output/planning-artifacts/s306/…​           untracked, listed  MUST be scanned
#   docs/junk/ignored-cite.md                        untracked, IGNORED must NOT be
#
# `docs/junk/` is gitignored, so it is the only thing separating `--others` from
# `--others --exclude-standard`, and without it that flag would be unobservable here.
mktree() { # mktree <dir> <with-sprint-artifacts: yes|no>
  local d="$1" want="$2" i=1
  mkdir -p "$d/docs/junk" "$d/_bmad-output/planning-artifacts/s306" || return 2
  ( cd "$d" && "$REAL_GIT" init -q . ) || return 2
  printf 'docs/junk/\n' > "$d/.gitignore" || return 2
  printf 'sprint: 306\n' > "$d/_bmad-output/planning-artifacts/sprint-status.yaml" || return 2
  while [ "$i" -le 20 ]; do printf 'line %d\n' "$i" >> "$d/docs/architecture.md"; i=$((i+1)); done
  # Backticks are written via printf \140: a citation is backtick-delimited by the
  # subject's own grammar, and a literal backtick inside a double-quoted string here
  # would be command substitution against a hole.
  printf 'cites \140docs/architecture.md:15\140 from a tracked file\n' > "$d/docs/tracked-cite.md" || return 2
  ( cd "$d" && "$REAL_GIT" -c user.email=f@f -c user.name=fixture add -A \
      && "$REAL_GIT" -c user.email=f@f -c user.name=fixture commit -q -m base ) || return 2
  # The working-tree insertion. Two lines added at the top, so the first shifted OLD line
  # is 1 and every citation in the file is at or below it.
  { printf 'INSERTED\nINSERTED\n'; cat "$d/docs/architecture.md"; } > "$d/.tmp" || return 2
  mv -f "$d/.tmp" "$d/docs/architecture.md" || return 2
  printf 'cites \140docs/architecture.md:17\140 from an IGNORED file\n' > "$d/docs/junk/ignored-cite.md" || return 2
  if [ "$want" = yes ]; then
    printf 'cites \140docs/architecture.md:16\140 from an UNTRACKED sprint artifact\n' \
      > "$d/_bmad-output/planning-artifacts/s306/story-1.md" || return 2
  else
    # The WRONG-TREE shape: the sprint is declared but its directory holds nothing, in
    # neither tracked nor untracked form. `docs/` still supplies a plausible corpus, which
    # is what makes this the case that reads most like a clean result.
    rmdir "$d/_bmad-output/planning-artifacts/s306" || return 2
  fi
  return 0
}

TREE="$WORK/consumer"
mktree "$TREE" yes || { echo "FIXTURE ERROR: could not build the mid-sprint tree" >&2; exit 2; }
BASE="$( cd "$TREE" && "$REAL_GIT" rev-parse HEAD )" || { echo "FIXTURE ERROR: no base rev" >&2; exit 2; }

WRONG="$WORK/wrongtree"
mktree "$WRONG" no || { echo "FIXTURE ERROR: could not build the wrong tree" >&2; exit 2; }
WBASE="$( cd "$WRONG" && "$REAL_GIT" rev-parse HEAD )" || { echo "FIXTURE ERROR: no base rev" >&2; exit 2; }

# Sanity: the three citing files must be in the membership classes the arms assume, or
# every assertion below is about a tree that cannot express the defect.
tracked_ok=$( cd "$TREE" && "$REAL_GIT" ls-files | grep -c '^docs/tracked-cite\.md$' )
untr_ok=$(    cd "$TREE" && "$REAL_GIT" ls-files --others --exclude-standard \
                | grep -c '^_bmad-output/planning-artifacts/s306/story-1\.md$' )
ign_ok=$(     cd "$TREE" && "$REAL_GIT" ls-files --others --exclude-standard \
                | grep -c '^docs/junk/ignored-cite\.md$' )
if [ "$tracked_ok" != 1 ] || [ "$untr_ok" != 1 ] || [ "$ign_ok" != 0 ]; then
  echo "FIXTURE ERROR: the seed tree is not in the three membership classes the arms assume" >&2
  echo "  tracked=$tracked_ok (want 1)  untracked-listed=$untr_ok (want 1)  ignored-listed=$ign_ok (want 0)" >&2
  exit 2
fi

# ============================================================================
# THE HARNESS
# ============================================================================
# `run <subject> <tree> <base> [shimdir]` -> prints the subject's output with a trailing
# `rc=<n>` line. The rc is appended INSIDE the substitution because zsh has no PIPESTATUS
# and a caller reading $? after a pipe would read the wrong program's status.
run() {
  local subj="$1" tree="$2" base="$3" shim="${4:-}" out rc
  if [ -n "$shim" ]; then
    out="$( PATH="$shim:$PATH" AI_DLC_REAL_GIT="$REAL_GIT" AI_DLC_SHIM_MARK="$shim/.fired" \
            AI_DLC_PROJECT_ROOT="$tree" bash "$subj" "$base" 2>&1 )"; rc=$?
  else
    out="$( AI_DLC_PROJECT_ROOT="$tree" bash "$subj" "$base" 2>&1 )"; rc=$?
  fi
  printf '%s\nrc=%d\n' "$out" "$rc"
}
# Every predicate below reads a captured string with a here-string, never a pipe: `grep -q`
# leaves at its first match, and under pipefail a pipeline then answers with the writer's
# EPIPE and reports NOT-FOUND on input that contains the pattern.
has()  { grep -qF -- "$2" <<<"$1"; }
rows() { grep -cE '^  [^ ].*  ->  ' <<<"$1"; }

# Build a `git` shim whose `ls-files` argument rewriting is described by <awk-filter>.
# The shim marks itself as FIRED only when the rewritten argument list actually differs
# from the original, which is this battery's `cmp -s`: a mutation that altered no
# invocation must not be readable as a kill.
mkshim() { # mkshim <dir> <sed-program applied to the space-joined args>
  local d="$1" prog="$2"
  mkdir -p "$d" || return 2
  cat > "$d/git" <<SHIM
#!/usr/bin/env bash
orig="\$*"
case " \$orig " in
  *" ls-files "*)
      new="\$(printf '%s' "\$orig" | sed '$prog')"
      [ "\$new" != "\$orig" ] && : > "\$AI_DLC_SHIM_MARK"
      exec "\$AI_DLC_REAL_GIT" \$new ;;
  *)  exec "\$AI_DLC_REAL_GIT" "\$@" ;;
esac
SHIM
  chmod +x "$d/git" || return 2
  rm -f "$d/.fired"
  return 0
}
fired() { [ -f "$1/.fired" ]; }

OUT="$(run "$SUBJ" "$TREE" "$BASE")"

# ============================================================================
# 1. THE FILED DEFECT — an untracked sprint artifact is IN the corpus.
# ============================================================================
# Presence-shaped on purpose: it demands the worklist row and the sprint count, so a
# subject that emitted nothing at all would fail it rather than pass on an absence.
if has "$OUT" "rc=0" \
   && ! has "$OUT" "SCOPING FAILURE" \
   && has "$OUT" "_bmad-output/planning-artifacts/s306/story-1.md:1  ->  docs/architecture.md:16"; then
  ok "an UNTRACKED file under the current sprint's artifact root is scanned, and its stale citation reaches the worklist"
else
  bad "an untracked sprint artifact is invisible to the corpus — the filed sprint-306 defect: $(grep -c 'SCOPING FAILURE' <<<"$OUT") scoping failure(s), $(grep -o 'rc=[0-9]*' <<<"$OUT")"
fi
# The in-band control the header owes its reader. `>= 1`, not `== 1`, deliberately: the
# exact count is arm 2's subject, and an arm that also pinned it would go red on arm 2's
# mutant and leave two failures where one defect exists.
n_untracked="$(sed -n 's/.*untracked (not yet git-added): \([0-9][0-9]*\).*/\1/p' <<<"$OUT" | head -1)"
if [ -n "$n_untracked" ] && [ "$n_untracked" -ge 1 ]; then
  ok "the header states the untracked contribution ($n_untracked), so a consumer can see what its .gitignore admitted"
else
  bad "the header does not report an untracked corpus contribution ('${n_untracked:-<absent>}') — the cost of the union is invisible on the run that pays it"
fi

# ============================================================================
# 2. `--exclude-standard` HOLDS — a gitignored file is NOT in the corpus.
# ============================================================================
# The other side of the union, and the one a one-word edit removes. Its own positive
# conjunct — the worklist must be non-empty — is what stops this arm scoring a kill
# against a subject that produced no worklist at all.
if [ "$(rows "$OUT")" -ge 1 ] && ! has "$OUT" "docs/junk/ignored-cite.md"; then
  ok "a gitignored file under a corpus root stays OUT of the corpus — the union is --exclude-standard, not bare --others"
else
  bad "a gitignored file reached the worklist (or the worklist was empty and this arm proved nothing): rows=$(rows "$OUT")"
fi

# ============================================================================
# 3. THE TRACKED HALF IS STILL THERE.
# ============================================================================
# A union written as a replacement rather than an addition passes assertions 1 and 2 and
# silently stops scanning every artifact the consumer HAS committed — which on the
# reference consumer is 10666 files against a handful of uncommitted ones.
if has "$OUT" "docs/tracked-cite.md:1  ->  docs/architecture.md:15"; then
  ok "TRACKED files are still scanned — the untracked set was added to the corpus, not substituted for it"
else
  bad "a tracked citing file no longer reaches the worklist: the untracked half replaced the tracked half instead of joining it"
fi

# ============================================================================
# 4. THE WRONG-TREE EXIT SURVIVED THE FIX.
# ============================================================================
# What does this change make always-true downstream? If admitting untracked files could
# make `SCOPING FAILURE` unreachable, the fix would have satisfied the check by deleting
# its subject, and every later run over an unrelated repository would read as clean.
WOUT="$(run "$SUBJ" "$WRONG" "$WBASE")"
if has "$WOUT" "rc=3" && has "$WOUT" "SCOPING FAILURE"; then
  ok "a tree whose declared sprint has no artifact directory in EITHER tracked or untracked form still exits 3 — the wrong-tree exit is still reachable"
else
  bad "SCOPING FAILURE can no longer fire: the corpus fix made the wrong-tree exit unreachable, so an empty worklist off an unrelated repository now reads as a clean result. $(grep -o 'rc=[0-9]*' <<<"$WOUT")"
fi

# ============================================================================
# 5. THE MUTANTS.
# ============================================================================
# Each rewrites `git ls-files` arguments, so it lands under either spelling of the union.
# Each must fail ONLY its own assertion; two failures would mean the arms are entangled
# and one of them is vacuous.

# M1 — strip the untracked flags. This is the shipped defect exactly: whatever the author
# wrote, ls-files comes back tracked-only. Owns assertion 1.
M1="$WORK/m1"
mkshim "$M1" 's/ --others//g; s/ --exclude-standard//g' || { echo "FIXTURE ERROR: mkshim m1" >&2; exit 2; }
M1OUT="$(run "$SUBJ" "$TREE" "$BASE" "$M1")"
if ! fired "$M1"; then
  bad "MUTANT tracked-only: the shim altered no ls-files invocation, so assertion 1 is UNPROVEN — an arm nothing can turn red is not an assertion"
elif has "$M1OUT" "_bmad-output/planning-artifacts/s306/story-1.md"; then
  bad "MUTANT tracked-only: the untracked artifact reached the worklist anyway, so assertion 1 passes over a corpus rule it is not measuring"
else
  ok "MUTANT tracked-only turns assertion 1 red — the untracked artifact vanishes from the worklist, reproducing the filed defect"
  has "$M1OUT" "docs/tracked-cite.md:1  ->  docs/architecture.md:15" \
    && ok "MUTANT tracked-only leaves assertion 3 GREEN — the two arms are not entangled" \
    || bad "MUTANT tracked-only also took assertion 3 down; one of the two arms is vacuous"
fi

# M2 — strip only `--exclude-standard`, leaving `--others`. Owns assertion 2.
M2="$WORK/m2"
mkshim "$M2" 's/ --exclude-standard//g' || { echo "FIXTURE ERROR: mkshim m2" >&2; exit 2; }
M2OUT="$(run "$SUBJ" "$TREE" "$BASE" "$M2")"
if ! fired "$M2"; then
  bad "MUTANT no-exclude-standard: the shim altered no ls-files invocation, so assertion 2 is UNPROVEN"
elif ! has "$M2OUT" "docs/junk/ignored-cite.md"; then
  bad "MUTANT no-exclude-standard: the gitignored file stayed out of the worklist even with the flag gone, so assertion 2 passes over a filter it is not measuring"
else
  ok "MUTANT no-exclude-standard turns assertion 2 red — the gitignored file reaches the worklist"
  has "$M2OUT" "_bmad-output/planning-artifacts/s306/story-1.md" \
    && ok "MUTANT no-exclude-standard leaves assertion 1 GREEN — the two arms are not entangled" \
    || bad "MUTANT no-exclude-standard also took assertion 1 down; one of the two arms is vacuous"
fi

# M3 — make the TRACKED listing come back empty, by forcing every ls-files call to list
# untracked files only. Owns assertion 3.
M3="$WORK/m3"
mkshim "$M3" 's/$/ --others --exclude-standard/; s/--cached//g' \
  || { echo "FIXTURE ERROR: mkshim m3" >&2; exit 2; }
M3OUT="$(run "$SUBJ" "$TREE" "$BASE" "$M3")"
if ! fired "$M3"; then
  bad "MUTANT untracked-only: the shim altered no ls-files invocation, so assertion 3 is UNPROVEN"
elif has "$M3OUT" "docs/tracked-cite.md"; then
  bad "MUTANT untracked-only: the tracked citing file reached the worklist anyway, so assertion 3 passes over a corpus rule it is not measuring"
else
  ok "MUTANT untracked-only turns assertion 3 red — the tracked citing file vanishes from the worklist"
  has "$M3OUT" "_bmad-output/planning-artifacts/s306/story-1.md" \
    && ok "MUTANT untracked-only leaves assertion 1 GREEN — the two arms are not entangled" \
    || bad "MUTANT untracked-only also took assertion 1 down; one of the two arms is vacuous"
fi

# THE UNMUTATED CONTROL, through the same shim mechanism. A shim that broke `git` outright
# would make every mutant above look like a kill, and the arms it kills are absence-shaped
# by nature — so the control passes ls-files through untouched and DEMANDS the baseline
# rows are present, rather than merely asserting nothing went wrong.
CTL="$WORK/ctl"
mkshim "$CTL" 's/^$//' || { echo "FIXTURE ERROR: mkshim ctl" >&2; exit 2; }
COUT="$(run "$SUBJ" "$TREE" "$BASE" "$CTL")"
if fired "$CTL"; then
  bad "CONTROL: the pass-through shim reported altering an invocation, so it is not a control"
elif has "$COUT" "docs/tracked-cite.md:1  ->  docs/architecture.md:15" \
  && has "$COUT" "_bmad-output/planning-artifacts/s306/story-1.md:1  ->  docs/architecture.md:16" \
  && has "$COUT" "rc=0"; then
  ok "CONTROL: an unaltered git through the same shim still yields BOTH baseline worklist rows — the kills above are the mutations, not the harness"
else
  bad "CONTROL: a pass-through shim loses the baseline rows, so every mutant above scored a kill against a broken harness rather than against its mutation"
fi

echo
if [ "$fails" -eq 0 ]; then echo "fanout-untracked-corpus: PASS"; exit 0; fi
echo "fanout-untracked-corpus: $fails assertion(s) FAILED" >&2
exit 1
