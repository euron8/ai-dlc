#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Drives the pre-push suite's per-fixture READ-SET SKIP.
#
# WHAT IS BEING PROVEN, and why each arm has to exist. The skip decides which fixtures do not
# run. Its failure mode is not a slow suite -- it is a SILENTLY SHORT one: a fixture that never
# ran reports nothing and the summary still says green. So every arm below asserts a POSITIVE
# outcome (this exact set was selected) rather than the absence of an old failure, and the
# mutants each declare the exact arms they must move.
#
# THE DEFECT THIS FIXTURE EXISTS BECAUSE OF. During development the selection injected each
# changed path's synthesised PARENT DIRECTORY into the `.changed` set, which then failed the
# "changed path no fixture reads" test -- so the skip fell back to the full suite in EVERY
# scenario while announcing it in wording that read like caution. It was inert, green, and
# indistinguishable from a working skip by any test asserting "nothing regressed". Arm 2 is
# the one that catches it, and it catches it only because it asserts a subset was selected.
set -u

# A consumer that tunes AI_DLC_FIXTURE_JOBS or AI_DLC_FIXTURE_NO_SKIP in settings.json would
# otherwise have that value decide these arms, and the fixture would be testing the CONFIG
# rather than the CODE. Arms needing a value set it on their own command.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

asserts=0; fails=0
ok()     { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad()    { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "readset-skip: FIXTURE BROKEN" >&2; exit 2; }

echo "readset-skip:"

# BOTH LAYOUTS, NAMED RATHER THAN DERIVED FROM ONE ANOTHER (I33). install.sh splits what
# shares a parent here, so walking up from one file to find the other is the thing that
# invariant fails the build on.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "not in a git repo"
HOOK=""
for c in "$ROOT/.githooks/pre-push" "$ROOT/core/git-hooks/pre-push"; do
  [ -f "$c" ] && { HOOK="$c"; break; }
done
[ -n "$HOOK" ] || broken "no pre-push hook found in either layout"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-skip.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# The block is extracted rather than the whole hook sourced: the hook runs a full gate on
# source. I66 holds the two copies of this block to one program, so proving it here proves it
# for the consumer's hook as well.
POOL="$WORK/pool.sh"
sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$HOOK" > "$POOL"
[ -s "$POOL" ] || broken "extracted an empty FIXTURE_POOL block from $HOOK"
grep -q 'apply_readset_skip' "$POOL" || broken "the extracted block carries no apply_readset_skip"

# ---------------------------------------------------------------------------- seed ----
# alpha reads a.sh and shared.sh; beta reads b.sh and shared.sh; gamma is DELIBERATELY absent
# from the map, which is the fail-closed subject.
seed() {
  local t="$1"
  mkdir -p "$t/core/fixtures/alpha" "$t/core/fixtures/beta" "$t/core/fixtures/gamma" "$t/src"
  local f
  for f in alpha beta gamma; do printf 'exit 0\n' > "$t/core/fixtures/$f/run.sh"; done
  # beta also names the src/ DIRECTORY, the way a fixture that globs a directory records it.
  # Without a directory entry anywhere in the map, `.match` and `.changed` are equivalent and
  # the parentdir mutant below cannot move -- it would report a kill for the wrong reason.
  printf 'alpha\tsrc/a.sh\nalpha\tsrc/shared.sh\nbeta\tsrc/b.sh\nbeta\tsrc/shared.sh\nbeta\tsrc\n' \
    > "$t/.ai-dlc-fixture-readsets.tsv"
  for f in a b shared orphan; do printf 'v1\n' > "$t/src/$f.sh"; done
  ( cd "$t" && git init -q . && git add -A && \
    git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 || return 1
}

# Run the selection in a seeded tree and echo the selected fixture names, space separated.
# SCRATCH LIVES OUTSIDE THE TREE. With it inside, `git ls-files` sweeps it into the manifest
# and the orphan branch fires on the harness's own files -- measured, it made all four
# development cases report "running all" and proved nothing.
select_in() {
  local t="$1" scratch; shift
  scratch="$(mktemp -d "$WORK/s.XXXXXX")" || return 1
  ( cd "$t" || exit 1
    # shellcheck disable=SC1090
    . "$POOL" 2>/dev/null
    for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$scratch/list"
    readset_manifest "$scratch"
    cp "$scratch/.now" .git/ai-dlc-fixture-verified 2>/dev/null
    eval "$*"                                   # the caller's mutation of the tree
    cp "$scratch/list" "$scratch/l"
    apply_readset_skip "$scratch/l" "$scratch" > "$scratch/msg" 2>&1
    sed 's|core/fixtures/||g; s|/$||' "$scratch/l" | tr '\n' ' '
    printf '\n---MSG---\n'
    cat "$scratch/msg"
    # THE DECISION, NOT THE PROSE. The whole-suite skip leaves the fixture list UNTOUCHED --
    # it is carried by a flag, because an empty list is a hard FAIL in run_fixtures by design.
    # So "skipped everything" and "ran everything" produce the SAME selected set, and an arm
    # scoring only on that set cannot tell them apart. Report the flag.
    printf '\n---FLAG---\n'
    printf '%s\n' "${READSET_NO_CHANGE:-0}"
  )
}
sel_of()  { printf '%s' "$1" | sed -n '1p' | tr -s ' ' | sed 's/ $//'; }
msg_of()  { printf '%s' "$1" | sed -n '/---MSG---/,/---FLAG---/p' | tail -n +2 | sed '$d'; }
flag_of() { printf '%s' "$1" | sed -n '/---FLAG---/,$p' | tail -n +2 | tr -d '[:space:]'; }

# ------------------------------------------------------------------------- arm 1-6 ----
T="$WORK/t1"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha gamma" ]; then
  ok "a change to src/a.sh selects alpha (reads it) and gamma (unmapped) — beta is SKIPPED"
else
  bad "expected 'alpha gamma', got '$(sel_of "$R")' — the skip selected the wrong set: $(msg_of "$R" | tr -d '\n')"
fi
case "$(msg_of "$R")" in
  *SKIPPING*) ok "  and the run ANNOUNCES the skip rather than performing it silently" ;;
  *)          bad "  the skip was applied with no announcement naming what it skipped" ;;
esac

T="$WORK/t2"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/shared.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "a change to a SHARED path selects both its readers, so the map is not merely per-fixture"
else
  bad "expected all three for src/shared.sh, got '$(sel_of "$R")'"
fi

T="$WORK/t3"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/orphan.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ] && printf '%s' "$(msg_of "$R")" | grep -q 'NO fixture read-set'; then
  ok "a changed path NO fixture reads runs the whole suite — a stale map and a harmless file are indistinguishable from here"
else
  bad "an unmapped changed path did not force a full run: '$(sel_of "$R")' / $(msg_of "$R" | tr -d '\n')"
fi

T="$WORK/t4"; seed "$T" || broken "seed failed"
R="$(AI_DLC_FIXTURE_NO_SKIP=1 select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "AI_DLC_FIXTURE_NO_SKIP=1 runs everything — the drift sweep the map cannot check itself with"
else
  bad "AI_DLC_FIXTURE_NO_SKIP=1 still skipped: '$(sel_of "$R")'"
fi

T="$WORK/t5"; seed "$T" || broken "seed failed"
rm -f "$T/.ai-dlc-fixture-readsets.tsv"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "no map at all runs everything, so an uninstalled map cannot silently disable the suite"
else
  bad "a missing map did not force a full run: '$(sel_of "$R")'"
fi

T="$WORK/t6"; seed "$T" || broken "seed failed"
R="$( cd "$T" && scratch="$(mktemp -d "$WORK/n.XXXXXX")" && . "$POOL" 2>/dev/null && \
      for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$scratch/list" && \
      rm -f .git/ai-dlc-fixture-verified && cp "$scratch/list" "$scratch/l" && \
      apply_readset_skip "$scratch/l" "$scratch" 2>&1 | tr -d '\n' )"
case "$R" in
  *"no verified-state record"*) ok "with no verified state the suite runs whole and says so — the skip cannot bootstrap itself into silence" ;;
  *)                            bad "a missing verified-state record did not force a full run: $R" ;;
esac

T="$WORK/t7"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'rm -f src/a.sh')"
if [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "DELETING src/a.sh also selects beta, which globs src/ — a vanished entry changes what a listing returns"
else
  bad "a deletion did not select the directory's reader: '$(sel_of "$R")'"
fi

T="$WORK/t8"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha gamma" ]; then
  ok "  and EDITING the same file does NOT select beta — a parent rides along only on appearance"
else
  bad "  editing a file selected the directory's reader too ('$(sel_of "$R")'), which turns the skip back into a full run"
fi

T="$WORK/t9"; seed "$T" || broken "seed failed"
# THE SUBJECT IS THE REF FILE, NOT `.git/HEAD`. HEAD holds `ref: refs/heads/<branch>` and does
# NOT change when you commit -- only the ref it points at does. An earlier version of this arm
# mapped `.git/HEAD` and passed even with the exclusion removed from BOTH sites, i.e. it could
# not fail. Derived here rather than hard-coded because the seed's default branch name is
# whatever the machine's git is configured for.
T9_REF=".git/$( cd "$T" && git symbolic-ref HEAD 2>/dev/null )"
case "$T9_REF" in
  .git/refs/heads/*) : ;;
  *) broken "could not resolve the seeded repo's ref file (got '$T9_REF'); the .git-scope arm would test nothing" ;;
esac
[ -f "$T/$T9_REF" ] || broken "resolved ref file '$T9_REF' does not exist in the seed"
printf 'gamma\t%s\n' "$T9_REF" >> "$T/.ai-dlc-fixture-readsets.tsv"
R="$(select_in "$T" 'git -c user.email=f@f -c user.name=f commit -q --allow-empty -m moveHEAD')"
if [ "$(flag_of "$R")" = "1" ] && [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "a commit moves the branch ref and the map sees NOTHING — git internals move on every push, and honouring them would select their readers every time"
else
  bad "a branch-ref move was visible to the selection ('$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

# ------------------------------------------------------------------------ arms 10-11 ----
# THE WHOLE-SUITE SKIP, AND THE ONE THING THAT MAKES IT SOUND.
#
# Arm 10 is the behaviour itself: when NOTHING in the universe moved, the suite does not run.
# This branch used to defer to the content key, and the two instruments deadlocked -- the key
# announced "changed, running the suite" while this announced "nothing changed", and neither
# ever skipped. Measured on the real repo, a commit touching only files under `docs/` -- a top
# the content key itself EXCLUDES -- ran all 161 fixtures.
#
# Arm 11 is the reason that skip is not reckless. `git ls-files` answers about the COMMITTED
# tree; a fixture reads the WORKING one. An untracked, unignored file is in no read-set by
# construction, so without it in the manifest universe `.changed` would be empty and arm 10
# would skip the suite over a tree nobody hashed. With it, the file is a CHANGED path no
# fixture reads -- the orphan case -- and the whole suite runs. The two arms pull in opposite
# directions on purpose: 10 says "skip when nothing moved", 11 says "and an untracked file IS
# something moving".
T="$WORK/t10"; seed "$T" || broken "seed failed"
R="$(select_in "$T" ':')"
if [ "$(flag_of "$R")" = "1" ] && printf '%s' "$(msg_of "$R")" | grep -q 'skipping all'; then
  ok "NOTHING changed since the last green run — the suite is SKIPPED WHOLE, not run whole"
else
  bad "an unchanged tree did not skip the suite (flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

T="$WORK/t11"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v1 > src/untracked-newcomer.sh')"
if [ "$(flag_of "$R")" = "0" ] && [ "$(sel_of "$R")" = "alpha beta gamma" ]; then
  ok "  an UNTRACKED, unignored new file is NOT nothing — it blocks the skip and runs the whole suite"
else
  bad "  an untracked file was invisible to the manifest (flag $(flag_of "$R"), sel '$(sel_of "$R")') — the skip would run over a tree nobody hashed"
fi

# A GIT-IGNORED file must NOT block the skip, or the skip could never fire on a real tree:
# hooks and fixtures write into ignored paths WHILE the suite runs, so a universe covering
# them would differ from itself across the very run it is keyed on. This is the near-miss for
# arm 11 -- same shape, opposite required answer.
T="$WORK/t12"; seed "$T" || broken "seed failed"
printf 'ignored-scratch/\n' > "$T/.gitignore"
( cd "$T" && git add -A && git -c user.email=f@f -c user.name=f commit -qm ignore ) >/dev/null 2>&1   || broken "could not seed a .gitignore"
R="$(select_in "$T" 'mkdir -p ignored-scratch && printf v1 > ignored-scratch/noise.txt')"
if [ "$(flag_of "$R")" = "1" ]; then
  ok "  and a GIT-IGNORED file does NOT block it — fixtures write into ignored paths as they run"
else
  bad "  an ignored file blocked the skip (flag $(flag_of "$R")): the skip could never fire on a real tree"
fi

# ------------------------------------------------------------------------- arms 13-14 ----
# THE MAP'S STALENESS IS ANNOUNCED, because nothing else can see it. A fixture directory with
# no entry runs on every push and the cost is invisible; a mapped path that gained a reader
# after the derivation is skipped for that reader and nothing reports it. Measured on the
# distribution: 510 commits between two derivations, 41 of 194 directories unmapped, 74 paths
# with untraced readers. The announce is the only mechanism -- the deriver needs root, so the
# hook cannot re-derive -- and an announce that cannot fire reads exactly like one that did.
# The seed maps alpha and beta and leaves gamma out, so the line must say 1 of 3 and name it.
T="$WORK/t13"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
case "$(msg_of "$R")" in
  *"1 of 3 fixture dir(s) UNMAPPED (always run): gamma"*)
    ok "the run ANNOUNCES the map's coverage gap by count and by name — an unmapped fixture is not a silent always-run" ;;
  *)
    bad "the coverage gap was not announced (expected '1 of 3 ... UNMAPPED ... gamma'): $(msg_of "$R" | tr -d '\n')" ;;
esac
# Near-miss: a map covering every directory announces ZERO unmapped and names nothing. The
# seed's map is tracked in its own repo, so the age half must resolve to a sha, never to
# 'UNTRACKED' -- the arm asserts both halves so an announce that lost its age cannot pass.
T="$WORK/t14"; seed "$T" || broken "seed failed"
printf 'gamma\tsrc/b.sh\n' >> "$T/.ai-dlc-fixture-readsets.tsv"
( cd "$T" && git add -A && git -c user.email=f@f -c user.name=f commit -qm mapall ) >/dev/null 2>&1 || broken "could not commit the full map"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
M14="$(msg_of "$R")"
if grep -qE 'read-set map: derived at [0-9a-f]{7,}, 0 commit\(s\) ago; 0 of 3 fixture dir\(s\) UNMAPPED' <<< "$M14" \
   && ! grep -q 'trace them' <<< "$M14"; then
  ok "  and a map covering every directory announces its age and ZERO unmapped, with no remedy printed"
else
  bad "  a fully-mapped tree did not announce 'derived at <sha>, 0 commit(s) ago; 0 of 3 ... UNMAPPED' cleanly: $(printf '%s' "$M14" | tr -d '\n')"
fi

# -------------------------------------------------------------------------- mutants ----
# Each mutant is a COPY, guarded by `cmp -s` so a sed that matched nothing cannot pass as a
# mutation, and each declares the EXACT arm it must move. A mutant that moves an arm it did
# not declare means the assertions are entangled and at least one of them is vacuous.
mutant() {
  local name="$1" expr="$2" want="$3" t m out
  m="$WORK/pool.$name.sh"
  sed "$expr" "$POOL" > "$m"
  if cmp -s "$POOL" "$m"; then
    bad "MUTANT $name: the edit matched nothing, so this mutant tests the unmutated program"
    return
  fi
  t="$WORK/m.$name"; seed "$t" || { bad "MUTANT $name: seed failed"; return; }
  local saved="$POOL"; POOL="$m"
  out="$(select_in "$t" "$4")"
  POOL="$saved"
  if [ "$(sel_of "$out")" = "$want" ]; then
    bad "MUTANT $name: still produced '$want' — the arm it should break does not depend on the mutated line"
  else
    ok "MUTANT $name moves its arm: '$want' became '$(sel_of "$out")'"
  fi
}

# Drop the fail-closed loop that adds map-less fixtures: gamma must stop being selected.
mutant unmapped 's|if ! grep -qxF "$b" "$out/.mapped"; then printf .*$|:|' \
  "alpha gamma" 'printf v2 > src/a.sh'
# Match on `.changed` instead of `.match` -- the real development defect, restored.
mutant parentdir 's|"$out/.match" "$READSET_MAP"|"$out/.changed" "$READSET_MAP"|' \
  "alpha beta gamma" 'rm -f src/a.sh'
# Remove the orphan fallback: an unreadable change must stop forcing a full run.
mutant orphan 's|if \[ -s "$out/.orphan" \]; then|if false; then|' \
  "alpha beta gamma" 'printf v2 > src/orphan.sh'
# NO MUTANT FOR THE .git EXCLUSION, and the reason is structural rather than an omission.
# The exclusion is applied in TWO places that must agree. Removing it from the universe alone
# changes nothing -- the path is already absent from the manifest, so it is never hashed.
# Removing it from the manifest alone makes `.git/HEAD` an ORPHAN, which forces a full run and
# therefore produces the SAME selection a working exclusion produces. A mutant scored on the
# selected set cannot tell those apart. The t9 arm above carries the falsifiability instead: it
# asserts the MESSAGE ('nothing changed') as well as the set, and honouring .git would make
# gamma -- which that arm maps to `.git/HEAD` -- the only selected fixture.
# Remove the NO_SKIP escape hatch.
mutant noskip 's|if \[ "${AI_DLC_FIXTURE_NO_SKIP:-}" = "1" \]; then|if false; then|' \
  "alpha beta gamma" 'printf v2 > src/a.sh'

# THESE TWO ARE SCORED ON THE FLAG, NOT THE SELECTED SET, because both failure modes leave the
# set at the full list -- which is exactly why `mutant()` above cannot express them.
flag_mutant() {
  local name="$1" expr="$2" want="$3" mut="$4" t m out
  m="$WORK/pool.$name.sh"
  sed "$expr" "$POOL" > "$m"
  if cmp -s "$POOL" "$m"; then
    bad "FLAG MUTANT $name: the edit matched nothing, so this mutant tests the unmutated program"
    return
  fi
  t="$WORK/fm.$name"; seed "$t" || { bad "FLAG MUTANT $name: seed failed"; return; }
  local saved="$POOL"; POOL="$m"
  out="$(select_in "$t" "$mut")"
  POOL="$saved"
  if [ "$(flag_of "$out")" = "$want" ]; then
    bad "FLAG MUTANT $name: flag is still '$want' — the arm it should break does not depend on the mutated line"
  else
    ok "FLAG MUTANT $name moves its arm: flag '$want' became '$(flag_of "$out")'"
  fi
}
# SCORED ON THE MESSAGE, because the staleness announce changes no decision -- it is the only
# arm whose whole subject is a line of output, so its mutant must be too. Keyed on the line
# that EMITS the unmapped names: with it gone the count still prints, the name does not, and
# arm 13 (which demands the name) is the only one that moves; arm 14 names nothing and stays.
msg_mutant() {
  local name="$1" expr="$2" needle="$3" mut="$4" t m out
  m="$WORK/pool.$name.sh"
  sed "$expr" "$POOL" > "$m"
  if cmp -s "$POOL" "$m"; then
    bad "MSG MUTANT $name: the edit matched nothing, so this mutant tests the unmutated program"
    return
  fi
  t="$WORK/mm.$name"; seed "$t" || { bad "MSG MUTANT $name: seed failed"; return; }
  local saved="$POOL"; POOL="$m"
  out="$(select_in "$t" "$mut")"
  POOL="$saved"
  case "$(msg_of "$out")" in
    *"$needle"*) bad "MSG MUTANT $name: the announce still carries '$needle' — arm 13 does not depend on the mutated line" ;;
    *)           ok "MSG MUTANT $name moves arm 13: '$needle' is gone from the announce" ;;
  esac
}
msg_mutant unnamed "s|printf ': %s' \"\$unmapped_names\"|:|" "UNMAPPED (always run): gamma" 'printf v2 > src/a.sh'

# Keyed on the EMITTING line, not on a spelling of the announce: the flag is the decision.
flag_mutant nochange_off 's|READSET_NO_CHANGE=1|READSET_NO_CHANGE=0|' "1" ':'
# Drop untracked files from the universe: arm 11's newcomer goes invisible and the suite skips
# over a tree nobody hashed. This is the soundness half of the change.
# The optional `-c core.quotePath=false` keeps the anchor matching whether or not the listing
# disables git's path quoting; without it the mutant matched nothing on the hook that does.
flag_mutant untracked_blind 's|git \(-c core\.quotePath=false \)\{0,1\}ls-files --others --exclude-standard 2>/dev/null||' \
  "0" 'printf v1 > src/untracked-newcomer.sh'

# UNMUTATED CONTROL, from the same directory and driven the same way. Without it a mutant that
# dies for a harness reason -- a copy that cannot source, a seed that failed -- emits nothing,
# and "no output" otherwise scores as a kill.
T="$WORK/ctl"; seed "$T" || broken "seed failed"
R="$(select_in "$T" 'printf v2 > src/a.sh')"
if [ "$(sel_of "$R")" = "alpha gamma" ]; then
  ok "CONTROL: an unmutated copy still selects 'alpha gamma', so the kills above are attributable"
else
  bad "CONTROL: the unmutated copy did not reproduce the baseline ('$(sel_of "$R")') — every mutant above is unattributable"
fi

# ------------------------------------- the manifest's population and the bookkeeping exemption ----
# TWO DEFECTS, ONE SEED. The manifest fed its path list to `xargs` without `-0`, and `xargs`
# aborts at the first apostrophe in a name: every file sorted after it went unhashed, so an
# edit to any of them read as "nothing changed" and the whole suite was skipped. Separately, a
# commit touching only the update skill's own bookkeeping -- the version stamp and the flat
# files under `_bmad-output/ai-dlc-update/` -- hit the orphan branch and ran everything.
#
# THE SEED IS SHAPED BY THE FIRST DEFECT'S MECHANICS. `xargs -n 200` runs each batch it has
# finished reading, so an apostrophe inside the FIRST batch hashes nothing, empties the manifest
# and falls into "could not hash -- running all", which is safe and hides the defect. Two hundred
# and ten filler files under `aaa/` push the apostrophe into the second batch, where the first
# batch is hashed and the rest silently is not. That position is asserted before any verdict.
#
# Fixtures: alpha reads src/a.sh, apos reads the apostrophe file, beta reads zzz/b.sh (sorts
# after it), stamp reads the version stamp, delta is unmapped (always selected).
APOS="src/x's.snap"
CAFE="src/caf$(printf '\303\251').md"
BK='printf "version: 2\n" > .claude/.ai-dlc-version; printf "l2\n" >> _bmad-output/ai-dlc-update/ledger.md; printf "r\n" > _bmad-output/ai-dlc-update/reconcile-log-1.md'
ALL5="alpha apos beta delta stamp"
NEW_ARMS=0
seed2() {
  local t="$1" i=0 f
  mkdir -p "$t/aaa" "$t/src" "$t/zzz" "$t/.claude" "$t/sub/.claude" "$t/_bmad-output/ai-dlc-update/sub" || return 1
  for f in alpha apos beta delta stamp; do
    mkdir -p "$t/core/fixtures/$f" && printf 'exit 0\n' > "$t/core/fixtures/$f/run.sh" || return 1
  done
  printf 'alpha\tsrc/a.sh\napos\t%s\nbeta\tzzz/b.sh\nstamp\t.claude/.ai-dlc-version\n' "$APOS" \
    > "$t/.ai-dlc-fixture-readsets.tsv"
  while [ "$i" -lt 210 ]; do printf '%s\n' "$i" > "$t/aaa/f$i"; i=$((i+1)); done
  printf 'v1\n' > "$t/src/a.sh"; printf 'v1\n' > "$t/zzz/b.sh"; printf 'q\n' > "$t/$APOS"; printf 'c\n' > "$t/$CAFE"
  printf 's\n' > "$t/.claude/settings.json"; printf 'version: 1\n' > "$t/.claude/.ai-dlc-version"
  printf 'version: 1\n' > "$t/sub/.claude/.ai-dlc-version"
  printf 'o\n' > "$t/_bmad-output/other.md"; printf 'x\n' > "$t/_bmad-output/ai-dlc-update/sub/x.md"
  printf 'l\n' > "$t/_bmad-output/ai-dlc-update/ledger.md"
  ( cd "$t" && git init -q . && git add -A && \
    git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 || return 1
}
TPL="$WORK/tpl"; seed2 "$TPL" || broken "the manifest seed failed"

# THE SEED MUST CARRY EVERY PROPERTY BEFORE ANY VERDICT IS READ. A global excludesFile that
# ignores `.claude/` or `_bmad-output/` would leave the bookkeeping arms passing over files git
# never listed; and an apostrophe in the first batch, or one sorting after zzz/b.sh, would make
# the "after it" arm agree with the broken manifest.
N_TR="$( cd "$TPL" && git ls-files | grep -c . )" || N_TR=0
[ "$N_TR" -eq 226 ] || broken "the manifest seed tracks $N_TR files, not 226 — something (a global excludesFile?) dropped seeded paths"
( cd "$TPL" && git check-ignore -q _bmad-output/ai-dlc-update/reconcile-log-1.md ) \
  && broken "the untracked bookkeeping file the bookkeeping arm creates is git-ignored here, so the manifest would never list it"
SP0="$(mktemp -d "$WORK/p.XXXXXX")" || broken "mktemp failed"
( cd "$TPL" && . "$POOL" 2>/dev/null && readset_manifest "$SP0" )
IA="$(grep -nxF "$APOS" "$SP0/.files" | cut -d: -f1)"
IB="$(grep -nxF "zzz/b.sh" "$SP0/.files" | cut -d: -f1)"
[ -n "$IA" ] && [ -n "$IB" ] && [ "$IA" -gt 200 ] && [ "$IA" -lt "$IB" ] \
  || broken "the apostrophe file is not past the first 200-path batch and before zzz/b.sh in the hook's own sort (at '${IA:-absent}', zzz/b.sh at '${IB:-absent}') — the arms below could not express the xargs defect"

# drive <pool> <name> <mutation> [stale] [extra seed] -- fresh world per call, scratch at
# $WORK/x.<name>. `stale` writes a non-empty record no manifest produced, so a world whose
# manifest is empty from the first run still reaches the "could not hash" guard rather than
# stopping at "no verified-state record".
drive() {
  local pool="$1" name="$2" mut="$3" mode="${4:-}" extra="${5:-}" t="$WORK/w.$2" sc="$WORK/x.$2"
  cp -Rp "$TPL" "$t" && mkdir -p "$sc" || return 1
  if [ -n "$extra" ]; then
    ( cd "$t" && eval "$extra" && git add -A && \
      git -c user.email=f@f -c user.name=f commit -qm extra ) >/dev/null 2>&1 || return 1
  fi
  ( cd "$t" || exit 1
    # shellcheck disable=SC1090
    . "$pool" 2>/dev/null
    for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$sc/list"
    readset_manifest "$sc"
    cp "$sc/.now" "$sc/seed.now"; cp "$sc/.files" "$sc/seed.files"
    if [ "$mode" = stale ]; then printf 'seed\tstale\n' > "$GITDIR/ai-dlc-fixture-verified"
    else cp "$sc/.now" "$GITDIR/ai-dlc-fixture-verified"; fi
    eval "$mut"
    READSET_NO_CHANGE=0
    apply_readset_skip "$sc/list" "$sc" > "$sc/msg" 2>&1
    sed 's|core/fixtures/||g; s|/$||' "$sc/list" | tr '\n' ' '
    printf '\n---MSG---\n'; cat "$sc/msg"
    printf '\n---FLAG---\n%s\n' "${READSET_NO_CHANGE:-0}"
  )
}
# holds <result> <selected> <flag> <message needle>: the selected set, the decision flag and a
# line of the announce, all three. The flag alone cannot tell "skipped whole" from "ran whole";
# the set alone cannot either, since a whole-suite skip leaves the list untouched.
holds() {
  [ "$(sel_of "$1")" = "$2" ] && [ "$(flag_of "$1")" = "$3" ] && grep -qF -- "$4" <<< "$(msg_of "$1")"
}
# hashed <scratch>: the seed manifest carries exactly one row for the apostrophe file, one for
# zzz/b.sh, and as many rows as files it listed.
hashed() {
  local na nb nn nf
  na="$(grep -cF "$APOS	" "$1/seed.now")" || na=0
  nb="$(grep -c '^zzz/b\.sh	' "$1/seed.now")" || nb=0
  nn="$(grep -c . "$1/seed.now")" || nn=0
  nf="$(grep -c . "$1/seed.files")" || nf=0
  [ "$na" -eq 1 ] && [ "$nb" -eq 1 ] && [ "$nn" -eq "$nf" ] && [ "$nf" -gt 200 ]
}
NM1() { printf '1 changed path(s) are in NO fixture read-set (e.g. %s)' "$1"; }
UNHASH="could not hash the working tree -- running all"
WHY="$(id -u)"

R="$(drive "$POOL" n1 'printf "q2\n" > "$APOS"')"
NEW_ARMS=$((NEW_ARMS+1))
if hashed "$WORK/x.n1"; then
  ok "the APOSTROPHE-named file is hashed, and so is zzz/b.sh after it — the manifest has a row for every file it listed ($(grep -c . "$WORK/x.n1/seed.now"))"
else
  bad "the manifest lost the apostrophe file or what sorts after it: $(grep -c . "$WORK/x.n1/seed.now") hashed of $(grep -c . "$WORK/x.n1/seed.files") listed, apostrophe rows $(grep -cF "$APOS	" "$WORK/x.n1/seed.now")"
fi
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "apos delta" 0 "SKIPPING"; then
  ok "  and an edit to the apostrophe file selects its reader (apos) plus the unmapped delta"
else
  bad "  an edit to the apostrophe file did not select 'apos delta' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

R="$(drive "$POOL" n2 'printf "v2\n" > zzz/b.sh')"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "beta delta" 0 "SKIPPING"; then
  ok "an edit to a mapped file sorting AFTER the apostrophe selects its reader (beta) — it was hashed, so it is not 'nothing changed'"
else
  bad "an edit to zzz/b.sh did not select 'beta delta' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

R="$(drive "$POOL" n3 "$BK")"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "delta stamp" 0 "SKIPPING"; then
  ok "a BOOKKEEPING-ONLY change (version stamp, ledger edit, new reconcile log) selects only the stamp's reader and the unmapped fixture — neither all, nor nothing"
else
  bad "a bookkeeping-only change did not select exactly 'delta stamp' with the suite running (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

# THE FLAT `_bmad-output/` WAIVER. A consumer's pipeline commits flat state files directly under
# `_bmad-output/`, the map names no reader for them, and each one used to force the whole suite. The waiver covers ONLY the "unknown reader" verdict for a FLAT root file: a
# deeper path, a nested `_bmad-output/` under another top, and a non-bookkeeping `.claude/` file
# still run all (below), and a flat file the map DOES name still selects its reader.
# `mkdir -p` sits in the mutation, not in seed2, so the seed's tracked count and the apostrophe
# position asserted above stay exactly as they were.
BMNEAR=".claude/settings.json _bmad-output/ai-dlc-update/sub/x.md _bmad-output/sub/x.md sub/_bmad-output/pipeline-continuation-log.md"
NMK() { printf "%s; mkdir -p \"\$(dirname '%s')\"; printf 'n2\\\\n' > '%s'" "$BK" "$1" "$1"; }
for _nm in $BMNEAR; do
  _nn="n4.$(printf '%s' "$_nm" | tr '/.' '__')"
  R="$(drive "$POOL" "$_nn" "$(NMK "$_nm")")"
  NEW_ARMS=$((NEW_ARMS+1))
  if [ -f "$WORK/w.$_nn/$_nm" ] && holds "$R" "$ALL5" 0 "$(NM1 "$_nm")"; then
    ok "  NEAR-MISS $_nm beside the bookkeeping is still an orphan and runs all — the exemption is exact"
  else
    bad "  near-miss $_nm beside the bookkeeping did not run all as the single named orphan, or was not written (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
  fi
done
# POSITIVE: a flat root file beside the bookkeeping is WAIVED, so the run selects exactly what
# the bookkeeping alone selects. Before the widening this was a near-miss that ran all.
R="$(drive "$POOL" n4.flat "$BK; printf 'n2\n' > _bmad-output/other.md")"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "delta stamp" 0 "SKIPPING"; then
  ok "  a FLAT _bmad-output/other.md beside the bookkeeping is waived — 'delta stamp', the bookkeeping's own selection, not all"
else
  bad "  a flat _bmad-output/other.md beside the bookkeeping did not select exactly 'delta stamp' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# POSITIVE: an edit to a zero-reader flat state file ALONE selects only the unmapped fixture.
PCL="_bmad-output/pipeline-continuation-log.md"
R="$(drive "$POOL" n4.pcl "printf 'p2\n' > '$PCL'" "" "printf 'p1\n' > '$PCL'")"
NEW_ARMS=$((NEW_ARMS+1))
if [ -f "$WORK/w.n4.pcl/$PCL" ] && holds "$R" "delta" 0 "SKIPPING"; then
  ok "an edit to a zero-reader flat $PCL selects only the unmapped delta — the pipeline's state file no longer forces the suite"
else
  bad "an edit to the zero-reader flat $PCL did not select exactly 'delta', or was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# POSITIVE, TWO MORE SHAPES: the waiver is `[^/]+`, so it covers a flat file of ANY extension and a
# flat DOTFILE. With only `.md` seeds, a `[^/]+\.md` waiver and a `[^/.][^/]*` one both passed every
# arm here on behaviour. Each of these two is the one input that separates one of them.
for _fp in _bmad-output/arm-log.jsonl _bmad-output/.pipeline-state; do
  _fn="n4.fp$(printf '%s' "$_fp" | tr '/.' '__')"
  R="$(drive "$POOL" "$_fn" "printf 'f2\n' > '$_fp'" "" "printf 'f1\n' > '$_fp'")"
  NEW_ARMS=$((NEW_ARMS+1))
  if [ -f "$WORK/w.$_fn/$_fp" ] && holds "$R" "delta" 0 "SKIPPING"; then
    ok "an edit to a zero-reader flat $_fp selects only the unmapped delta — the waiver is not limited to .md or to non-dotfiles"
  else
    bad "an edit to the zero-reader flat $_fp did not select exactly 'delta', or was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
  fi
done
# POSITIVE: a flat file the map NAMES still selects its reader. This is what separates the waiver
# from dropping `_bmad-output` out of the manifest or the read-sets, which loses alpha here.
MAPPED="_bmad-output/mapped-state.md"
R="$(drive "$POOL" n4.mapped "printf 'm2\n' > '$MAPPED'" "" \
       "printf 'm1\n' > '$MAPPED'; printf 'alpha\t%s\n' '$MAPPED' >> .ai-dlc-fixture-readsets.tsv")"
NEW_ARMS=$((NEW_ARMS+1))
if grep -qxF "alpha	$MAPPED" "$WORK/w.n4.mapped/.ai-dlc-fixture-readsets.tsv" && holds "$R" "alpha delta" 0 "SKIPPING"; then
  ok "an edit to a MAPPED flat $MAPPED still selects its reader (alpha) plus delta — the waiver touches only unknown readers"
else
  bad "an edit to the mapped flat $MAPPED did not select 'alpha delta', or its map row was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# THE NESTED NEAR-MISS is the only input for the version stamp that separates an anchored pattern
# from one that lost its `^`: the near-misses above differ from the stamp at its START or past its
# last `/` (the nested `sub/_bmad-output/` one guards the flat waiver's anchor, not the stamp's),
# so an unanchored stamp alternative drops none of them. A version stamp under a
# subdirectory ENDS like the real one and must still run all.
NESTED="sub/.claude/.ai-dlc-version"
R="$(drive "$POOL" n4.nested "$BK; printf 'version: 2\n' > '$NESTED'")"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "$ALL5" 0 "$(NM1 "$NESTED")"; then
  ok "  NEAR-MISS $NESTED beside the bookkeeping is still an orphan and runs all — the exemption is anchored at the root"
else
  bad "  near-miss $NESTED beside the bookkeeping did not run all as the single named orphan (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

R="$(drive "$POOL" n5 'printf "c2\n" > "$CAFE"')"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "$ALL5" 0 "$(NM1 "$CAFE")"; then
  ok "an edit to an unmapped NON-ASCII file is listed by its real name, reads as an orphan and runs all"
else
  bad "an edit to the unmapped non-ASCII file did not run all as a named orphan (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

if [ "$WHY" = 0 ]; then
  printf '  SKIP  unreadable-file arm and its mutant: running as root, where chmod 000 does not stop a read\n'
else
  R="$(drive "$POOL" n6 'chmod 000 aaa/f5')"
  NEW_ARMS=$((NEW_ARMS+1))
  if holds "$R" "$ALL5" 0 "$UNHASH"; then
    ok "an UNREADABLE file fails the hash and the manifest is emptied — 'could not hash', all run"
  else
    bad "an unreadable file did not fail closed through 'could not hash' (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
  fi
fi

R="$(drive "$POOL" n7 'printf "v2\n" > src/a.sh' stale "printf t > 'src/tab	name'")"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "$ALL5" 0 "$UNHASH"; then
  ok "a TAB-named file git still quotes fails closed — 'could not hash', all run"
else
  bad "a tab-named file did not fail closed (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
R="$(drive "$POOL" n8 'printf "v2\n" > src/a.sh' stale 'printf t > "src/back\\slash"')"
NEW_ARMS=$((NEW_ARMS+1))
if [ -f "$WORK/w.n8/src/back\\slash" ] && holds "$R" "$ALL5" 0 "$UNHASH"; then
  ok "  and so does a BACKSLASH-named one"
else
  bad "  a backslash-named file did not fail closed, or was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi
# AN OPTION-SHAPED NAME. Without `--`, shasum reads a top-level `-x.sh` as an unknown option,
# exits non-zero, and the manifest is emptied on every push: correct, and the skip never fires.
DASH_SEED='printf t > ./-x.sh'
R="$(drive "$POOL" n9 'printf "v2\n" > src/a.sh' "" "$DASH_SEED")"
NEW_ARMS=$((NEW_ARMS+1))
if [ -f "$WORK/w.n9/-x.sh" ] && holds "$R" "alpha delta" 0 "SKIPPING"; then
  ok "a top-level file named -x.sh is hashed as a file, and an edit to a mapped sibling still selects its reader (alpha) plus delta"
else
  bad "with a top-level -x.sh present an edit to src/a.sh did not select 'alpha delta', or -x.sh was not seeded (got '$(sel_of "$R")', flag $(flag_of "$R")): $(msg_of "$R" | tr -d '\n')"
fi

# MUTANTS of the manifest and the exemption, each a LITERAL replacement with an exact expected
# occurrence count, so a lost anchor reads as DID NOT APPLY rather than as a kill. The strings
# travel through ENVIRON, not `-v`, which would strip a level of backslashes. Every mutant run
# must also print the map announce, so a copy that could not be sourced cannot score a kill.
lit_mut() { # <name> <count> <from> <to>; sets LM. Never call it inside $( ): its `bad` must count.
  local m="$WORK/pool.lit.$1.sh"; LM=""
  MF="$3" MT="$4" MC="$WORK/lit.$1.n" awk '
    BEGIN { f = ENVIRON["MF"]; t = ENVIRON["MT"]; n = 0 }
    { line = $0; o = ""
      while ((p = index(line, f)) > 0) { o = o substr(line, 1, p - 1) t; line = substr(line, p + length(f)); n++ }
      print o line }
    END { print n > ENVIRON["MC"] }' "$POOL" > "$m" || { bad "MANIFEST MUTANT $1: awk DID NOT APPLY"; return 1; }
  if [ "$(cat "$WORK/lit.$1.n" 2>/dev/null)" != "$2" ] || cmp -s "$POOL" "$m"; then
    bad "MANIFEST MUTANT $1: anchor matched $(cat "$WORK/lit.$1.n" 2>/dev/null) time(s), not $2 — DID NOT APPLY"; return 1
  fi
  LM="$m"
}
# kill <mutant> <arm label> <result> <sel> <flag> <needle>
killed() {
  if ! grep -q 'read-set map: derived at' <<< "$(msg_of "$3")"; then
    bad "MANIFEST MUTANT $1: the copy never reached apply_readset_skip — no verdict, not a kill"
  elif holds "$3" "$4" "$5" "$6"; then
    bad "MANIFEST MUTANT $1 SURVIVED $2: '$(sel_of "$3")' flag $(flag_of "$3")"
  else
    ok "MANIFEST MUTANT $1 is KILLED by $2: got '$(sel_of "$3")' flag $(flag_of "$3") — $(grep -v 'derived at' <<< "$(msg_of "$3")" | sed 's/^ *\.\. *//' | tr -d '\n' | cut -c1-90)"
  fi
}

NEW_ARMS=$((NEW_ARMS+1))
if lit_mut noz 1 "tr '\\n' '\\000' < \"\$out/.files\" | xargs -0 -n 200 shasum -a 256 --" \
                    "xargs -n 200 shasum -a 256 -- < \"\$out/.files\""; then M="$LM"
  killed noz "the after-apostrophe arm" "$(drive "$M" m.noz 'printf "v2\n" > zzz/b.sh')" "beta delta" 0 "SKIPPING"
fi
NEW_ARMS=$((NEW_ARMS+1))
if lit_mut quotepath 2 "git -c core.quotePath=false ls-files" "git ls-files"; then M="$LM"
  killed quotepath "the non-ASCII arm" "$(drive "$M" m.quotepath 'printf "c2\n" > "$CAFE"')" "$ALL5" 0 "$(NM1 "$CAFE")"
fi
if lit_mut nofailclosed 1 ': > "$out/.now"' ':'; then M="$LM"
  if [ "$WHY" != 0 ]; then
    NEW_ARMS=$((NEW_ARMS+1))
    killed nofailclosed "the unreadable-file arm" "$(drive "$M" m.nfc6 'chmod 000 aaa/f5')" "$ALL5" 0 "$UNHASH"
  fi
  NEW_ARMS=$((NEW_ARMS+1))
  killed nofailclosed "the tab-name arm" "$(drive "$M" m.nfc7 'printf "v2\n" > src/a.sh' stale "printf t > 'src/tab	name'")" "$ALL5" 0 "$UNHASH"
else
  NEW_ARMS=$((NEW_ARMS+1))
fi
NEW_ARMS=$((NEW_ARMS+1))
if lit_mut aposdrop 1 '| readset_drop_excluded | sort -u > "$out/.paths"' \
                         "| grep -v \"'\" | readset_drop_excluded | sort -u > \"\$out/.paths\""; then M="$LM"
  if [ -n "$(drive "$M" m.aposdrop ':')" ] && ! hashed "$WORK/x.m.aposdrop"; then
    ok "MANIFEST MUTANT aposdrop is KILLED by the apostrophe-hashed arm: $(grep -cF "$APOS	" "$WORK/x.m.aposdrop/seed.now") apostrophe row(s) in the manifest"
  else
    bad "MANIFEST MUTANT aposdrop SURVIVED the apostrophe-hashed arm, or never ran"
  fi
fi
BKRE="'^(\\.claude/\\.ai-dlc-version|_bmad-output/ai-dlc-update/[^/]+|_bmad-output/[^/]+)\$'"
BROADK=".claude/settings.json _bmad-output/ai-dlc-update/sub/x.md _bmad-output/sub/x.md"
if lit_mut broad 1 "$BKRE" "'^(\\.claude/|_bmad-output/)'"; then M="$LM"
  for _nm in $BROADK; do
    NEW_ARMS=$((NEW_ARMS+1))
    killed broad "the near-miss arm for $_nm" "$(drive "$M" "m.broad.$(printf '%s' "$_nm" | tr '/.' '__')" "$(NMK "$_nm")")" "$ALL5" 0 "$(NM1 "$_nm")"
  done
else
  NEW_ARMS=$((NEW_ARMS+3))
fi
if lit_mut somebk 1 'if [ -s "$out/.orphan" ]; then' \
         "if [ -s \"\$out/.orphan\" ] && ! grep -qE $BKRE \"\$out/.changed\"; then"; then M="$LM"
  for _nm in $BMNEAR; do
    NEW_ARMS=$((NEW_ARMS+1))
    killed somebk "the near-miss arm for $_nm" "$(drive "$M" "m.somebk.$(printf '%s' "$_nm" | tr '/.' '__')" "$(NMK "$_nm")")" "$ALL5" 0 "$(NM1 "$_nm")"
  done
else
  NEW_ARMS=$((NEW_ARMS+4))
fi
# THE FLAT WAIVER'S TWO SHAPE LIMITS, each its own mutant. `.*` in place of `[^/]+` crosses a `/`
# and waives every path under `_bmad-output/`; the alternation with BOTH anchors removed waives a
# deeper path by its prefix and a nested `_bmad-output/` under another top by its suffix. Each is
# killed by a near-miss above that the shipped pattern still runs all on.
NEW_ARMS=$((NEW_ARMS+1))
if lit_mut dotstar 1 "|_bmad-output/[^/]+)\$'" "|_bmad-output/.*)\$'"; then M="$LM"
  killed dotstar "the near-miss arm for _bmad-output/sub/x.md" "$(drive "$M" m.dotstar "$(NMK _bmad-output/sub/x.md)")" "$ALL5" 0 "$(NM1 _bmad-output/sub/x.md)"
fi
if lit_mut unanch 1 "$BKRE" "'(\\.claude/\\.ai-dlc-version|_bmad-output/ai-dlc-update/[^/]+|_bmad-output/[^/]+)'"; then M="$LM"
  for _nm in _bmad-output/sub/x.md sub/_bmad-output/pipeline-continuation-log.md; do
    NEW_ARMS=$((NEW_ARMS+1))
    killed unanch "the near-miss arm for $_nm" "$(drive "$M" "m.unanch.$(printf '%s' "$_nm" | tr '/.' '__')" "$(NMK "$_nm")")" "$ALL5" 0 "$(NM1 "$_nm")"
  done
else
  NEW_ARMS=$((NEW_ARMS+2))
fi
# THE WAIVER'S TWO NARROWER SHAPES, each killed on BEHAVIOUR by its own flat positive above: the
# mutant applies (exact count 1), the copy reaches apply_readset_skip, and the flat file it no
# longer waives runs all instead of selecting 'delta'.
for _wm in "mdonly|_bmad-output/[^/]+\\.md|_bmad-output/arm-log.jsonl" "nodot|_bmad-output/[^/.][^/]*|_bmad-output/.pipeline-state"; do
  _wn="${_wm%%|*}"; _wr="${_wm#*|}"; _wf="${_wr#*|}"; _wr="${_wr%|*}"
  NEW_ARMS=$((NEW_ARMS+1))
  if lit_mut "$_wn" 1 "|_bmad-output/[^/]+)\$'" "|$_wr)\$'"; then M="$LM"
    killed "$_wn" "the flat positive for $_wf" \
      "$(drive "$M" "m.$_wn" "printf 'f2\n' > '$_wf'" "" "printf 'f1\n' > '$_wf'")" "delta" 0 "SKIPPING"
  fi
done
# ONLY ONE HOOK WIDENED. This fixture drives whichever hook it resolved first, so a waiver
# present in one copy alone reads green here and reaches only half the population. I66 is the
# binding; this arm proves it fires on exactly that edit. Run in a copy holding just what
# `--arms I66` reads, with the unmutated copy first as a presence-shaped control. The validator
# is distribution-only, so on a consumer this is a SKIP, not a pass.
VEM="$ROOT/scripts/validate-enforcement-map.sh"
if [ ! -f "$VEM" ] || [ ! -f "$ROOT/.githooks/pre-push" ] || [ ! -f "$ROOT/core/git-hooks/pre-push" ]; then
  printf '  SKIP  one-hook-widened I66 arm: validate-enforcement-map.sh or one of the two hooks is absent (a consumer tree)\n'
else
  I66T="$WORK/i66"
  for _f in scripts/validate-enforcement-map.sh scripts/render-invariant-index.sh \
            core/skills/ai-dlc/steps/gate-validation.md core/skills/ai-dlc/enforcement-map.yaml \
            core/skills/ai-dlc/core-manifest.md core/skills/ai-dlc-update/reconcile/setup-sites.md \
            .githooks/pre-push core/git-hooks/pre-push; do
    mkdir -p "$I66T/$(dirname "$_f")" && cp -p "$ROOT/$_f" "$I66T/$_f" || broken "could not copy $_f for the I66 arm"
  done
  I66C="$(bash "$I66T/scripts/validate-enforcement-map.sh" --arms I66 2>&1)"; I66C_RC=$?
  NEW_ARMS=$((NEW_ARMS+1))
  if [ "$I66C_RC" -eq 0 ] && grep -q '^OK: enforcement-map.yaml in sync' <<< "$I66C"; then
    ok "I66 CONTROL: the unmutated copy reads OK at rc 0, so the verdict below is attributable"
  else
    bad "I66 CONTROL: the unmutated copy did not read OK at rc 0 (rc $I66C_RC): $(printf '%s' "$I66C" | head -3 | tr '\n' ' ')"
  fi
  I66F="$I66T/core/git-hooks/pre-push"
  MF="|_bmad-output/ai-dlc-update/[^/]+|_bmad-output/[^/]+)\$'" MT="|_bmad-output/ai-dlc-update/[^/]+)\$'" \
    awk '{ p = index($0, ENVIRON["MF"]); if (p) { $0 = substr($0, 1, p - 1) ENVIRON["MT"] substr($0, p + length(ENVIRON["MF"])) } print }' \
    "$I66F" > "$I66F.mut"
  NEW_ARMS=$((NEW_ARMS+1))
  if cmp -s "$I66F" "$I66F.mut"; then
    bad "MANIFEST MUTANT onehook: the consumer hook carries no widened alternation to revert — DID NOT APPLY"
  else
    mv "$I66F.mut" "$I66F"
    I66M="$(bash "$I66T/scripts/validate-enforcement-map.sh" --arms I66 2>&1)"; I66M_RC=$?
    if [ "$I66M_RC" -eq 1 ] && grep -q 'I66 the two pre-push fixture-suite runners have forked' <<< "$I66M" \
       && grep -qF '.orphan' <<< "$I66M"; then
      ok "MANIFEST MUTANT onehook is KILLED by I66: the waiver widened in .githooks/pre-push alone exits 1 naming the forked orphan line"
    else
      bad "MANIFEST MUTANT onehook SURVIVED I66: one hook widened read rc $I66M_RC: $(printf '%s' "$I66M" | head -3 | tr '\n' ' ')"
    fi
  fi
fi
NEW_ARMS=$((NEW_ARMS+1))
if lit_mut wholeskip 1 'if [ -s "$out/.orphan" ]; then' \
         "if ! grep -qvE $BKRE \"\$out/.changed\"; then READSET_NO_CHANGE=1; return 0; fi; if [ -s \"\$out/.orphan\" ]; then"; then M="$LM"
  killed wholeskip "the bookkeeping-only arm" "$(drive "$M" m.wholeskip "$BK")" "delta stamp" 0 "SKIPPING"
fi
# The exemption pattern without its leading `^` drops a nested stamp too; only the nested
# near-miss can see it.
NEW_ARMS=$((NEW_ARMS+1))
if lit_mut nocaret 1 "grep -vE '^(\\.claude" "grep -vE '(\\.claude"; then M="$LM"
  killed nocaret "the nested near-miss arm" "$(drive "$M" m.nocaret "$BK; printf 'version: 2\n' > '$NESTED'")" "$ALL5" 0 "$(NM1 "$NESTED")"
fi
# Without the quoted-path test a tab-named file is listed in its quoted spelling, never reaches
# `.files`, and the line counts still agree, so the manifest is NOT emptied.
NEW_ARMS=$((NEW_ARMS+1))
if lit_mut noquote 1 " || grep -q '^\"' \"\$out/.paths\"" ""; then M="$LM"
  killed noquote "the tab-name arm" "$(drive "$M" m.noquote 'printf "v2\n" > src/a.sh' stale "printf t > 'src/tab	name'")" "$ALL5" 0 "$UNHASH"
fi
# Without `--`, a top-level -x.sh is an unknown option to shasum and the manifest is emptied.
NEW_ARMS=$((NEW_ARMS+1))
if lit_mut nodashdash 1 "shasum -a 256 -- >" "shasum -a 256 >"; then M="$LM"
  killed nodashdash "the option-shaped-name arm" "$(drive "$M" m.nodashdash 'printf "v2\n" > src/a.sh' "" "$DASH_SEED")" "alpha delta" 0 "SKIPPING"
fi

# UNMUTATED CONTROL for the battery above, driven by the same helper: a baseline row must be
# THERE, so a drive that died for a harness reason cannot pass as the clean case.
R="$(drive "$POOL" ctl2 'printf "v2\n" > zzz/b.sh')"
NEW_ARMS=$((NEW_ARMS+1))
if holds "$R" "beta delta" 0 "SKIPPING" && grep -q 'read-set map: derived at' <<< "$(msg_of "$R")"; then
  ok "CONTROL: the unmutated block, driven the same way, selects 'beta delta' and announces the map — the manifest kills are attributable"
else
  bad "CONTROL: the unmutated block did not reproduce 'beta delta' through drive() — every manifest mutant is unattributable"
fi

# ------------------------------------------------------- the deriver's map merge ----
# `--list` exists so refreshing ONE fixture costs its own runtime instead of a full
# re-derivation. Its first version rewrote the map from only the fixtures it had just traced,
# silently dropping every other entry. That is SAFE -- an unmapped fixture always runs -- and
# therefore invisible: the suite stays correct and merely stops skipping, which reads as the
# feature underperforming rather than as a bug. These arms are why it cannot come back.
#
# THE DERIVER NOW SHIPS, and it lands under a different parent on each side: install.sh copies
# `core/scripts/<x>` to `scripts/ai-dlc/<x>`, so neither path can be assumed and neither may be
# located by walking up from the other (I33). The CONSUMER layout is probed first and the
# distribution second, which is the order every other two-layout resolver here uses.
#
# ITS ABSENCE IS STILL A SKIP RATHER THAN A FAILURE, and that is not leniency. A core fixture
# ships ahead of its subject: this fixture reaches a consumer in one pull and the deriver in
# the next, so an installed tree between those two pulls has the fixture and not the file. A
# SKIP says so; passing silently would make a vanished arm and a satisfied arm identical.
MERGE_ARMS=0
CONTROL_ARMS=0
TRACE_ARMS=0
BOTH_ARMS=0
DERIVER=""
for _d in "$ROOT/scripts/ai-dlc/derive-fixture-readsets.sh" "$ROOT/core/scripts/derive-fixture-readsets.sh"; do
  [ -f "$_d" ] && DERIVER="$_d" && break
done
if [ -z "$DERIVER" ]; then
  printf '  SKIP  map-merge arms: derive-fixture-readsets.sh is in neither layout yet (core fixtures ship ahead of their subject)\n'
else
  M="$WORK/merge.sh"
  sed -n '/# READSET_MERGE_BEGIN/,/# READSET_MERGE_END/p' "$DERIVER" > "$M"
  grep -q 'readset_merge_map()' "$M" || broken "extracted no readset_merge_map from $DERIVER"
  # shellcheck disable=SC1090
  . "$M"
  printf 'alpha\tsrc/a\nalpha\tsrc/x\nbeta\tsrc/b\ngamma\tsrc/g\n' > "$WORK/old.map"
  printf 'alpha\tsrc/NEW\n' > "$WORK/new.map"
  : > "$WORK/empty.map"

  G="$(readset_merge_map "$WORK/old.map" "$WORK/new.map" "alpha" | LC_ALL=C sort | tr '\n' ' ')"
  MERGE_ARMS=$((MERGE_ARMS+1))
  case "$G" in
    *"beta	src/b"*) ok "a --list run leaves an UNTRACED fixture's entries alone — refreshing one fixture does not cost the rest of the map" ;;
    *) bad "merging dropped an untraced fixture's entries: $G" ;;
  esac
  MERGE_ARMS=$((MERGE_ARMS+1))
  case "$G" in
    *"alpha	src/x"*) bad "merging kept a STALE entry for the fixture it just re-traced: $G" ;;
    *"alpha	src/NEW"*) ok "  and it REPLACES the traced fixture's entries rather than adding to them" ;;
    *) bad "the traced fixture's new entry is missing after the merge: $G" ;;
  esac
  # The case that matters most: a fixture that WAS mapped and is now omitted must lose its
  # read-set, or the map keeps asserting a dependency set nothing re-verified.
  G2="$(readset_merge_map "$WORK/old.map" "$WORK/empty.map" "beta" | LC_ALL=C sort | tr '\n' ' ')"
  MERGE_ARMS=$((MERGE_ARMS+1))
  case "$G2" in
    *"beta	"*) bad "a traced fixture that produced NO read-set kept its stale entries — it would go on being skipped on evidence nothing re-verified: $G2" ;;
    *"gamma	src/g"*) ok "a traced fixture that produced nothing loses its entries and becomes unmapped, which means it always runs" ;;
    *) bad "the merge lost an untraced fixture while dropping the omitted one: $G2" ;;
  esac

  # THE CALLER PASSES A NEWLINE-SEPARATED LIST, AND EVERY ARM ABOVE PASSES A SINGLE TOKEN.
  # That gap shipped a live defect: `LIST` is built by a `for` loop over core/fixtures/*/, so it
  # arrives newline-separated, and `awk -v traced=" $traced "` cannot carry a newline — awk died
  # with `newline in string` on line 1, the old-map branch emitted nothing, and every UNTRACED
  # fixture silently lost its entries. Invisible under --all, which re-traces everything; under
  # --list it unmaps the rest of the suite. Observed in a real `sudo ... --all` run.
  #
  # The arms above could not see it because a one-word list has no newline in it. This one
  # drives the shape the caller actually produces.
  G3="$(readset_merge_map "$WORK/old.map" "$WORK/new.map" "$(printf 'alpha\ndelta')" 2>"$WORK/g3.err" | LC_ALL=C sort | tr '\n' ' ')"
  MERGE_ARMS=$((MERGE_ARMS+1))
  if [ -s "$WORK/g3.err" ]; then
    bad "a NEWLINE-separated traced list — the form the caller builds — made the merge write to stderr: $(tr '\n' ' ' < "$WORK/g3.err")"
  else
    case "$G3" in
      *"beta	src/b"*)
        case "$G3" in
          *"alpha	src/x"*) bad "newline-separated list: the re-traced fixture kept a stale entry: $G3" ;;
          *) ok "a NEWLINE-separated traced list behaves as a space-separated one — untraced entries kept, traced ones replaced" ;;
        esac ;;
      *) bad "a NEWLINE-separated traced list dropped an untraced fixture's entries — the whole rest of the map: $G3" ;;
    esac
  fi

  # MUTANTS on the merge, each a cmp -s guarded copy of the extracted block.
  merge_mutant() {
    local name="$1" expr="$2" mm="$WORK/merge.$1.sh"
    sed "$expr" "$M" > "$mm"
    if cmp -s "$M" "$mm"; then bad "MERGE MUTANT $name: the edit matched nothing"; return; fi
    ( . "$mm"; readset_merge_map "$WORK/old.map" "$WORK/new.map" "alpha" | LC_ALL=C sort | tr '\n' ' ' ) > "$WORK/mm.out" 2>/dev/null
  }
  MERGE_ARMS=$((MERGE_ARMS+1))
  merge_mutant rewrite 's|if \[ -s "$old" \]; then|if false; then|'
  if grep -q 'beta' "$WORK/mm.out"; then
    bad "MERGE MUTANT rewrite: untraced entries survived a merge that no longer reads the old map — arm 1 does not depend on that read"
  else
    ok "MERGE MUTANT rewrite moves arm 1: dropping the old-map read loses every untraced fixture"
  fi
  MERGE_ARMS=$((MERGE_ARMS+1))
  merge_mutant keepstale 's|if (index(traced, " " fx " ") == 0) print|print|'
  if grep -q 'src/x' "$WORK/mm.out"; then
    ok "MERGE MUTANT keepstale moves arm 2: without the traced filter the re-traced fixture keeps its stale entry"
  else
    bad "MERGE MUTANT keepstale: the stale entry did not survive — arm 2 does not depend on the traced filter"
  fi

  # mut_line <src> <dst> <exact old line> <new text> -- an exact-line replacement, never `sed`: the
  # deriver lines mutated below carry `&&`, `$(` and quotes a sed replacement would re-expand. The
  # caller derives <old> from the file by an anchored grep and guards with cmp -s, so a vanished
  # anchor reads as DID NOT APPLY rather than as a kill.
  mut_line() {
    local l
    : > "$2"
    while IFS= read -r l || [ -n "$l" ]; do
      if [ -n "$3" ] && [ "$l" = "$3" ]; then printf '%s\n' "$4"; else printf '%s\n' "$l"; fi
    done < "$1" >> "$2"
  }

  # ------------------------- the --all subject list and the untraced-loss guard ----
  # THE `--all` LIST WAS BUILT NEWLINE-SEPARATED, AND TWO GUARDS SILENTLY NEVER MATCHED A NAME. Every
  # membership test on it is `case " $LIST " in *" $f "*)`, so under `--all` every fixture read as
  # untraced: one OMITTED fixture made the merge check die "merge dropped" and discard every good
  # trace, and the plan-shape controls never ran on any `--all` derivation. Three layers normalise
  # the list now -- the builder, the loss guard's own argument, and the merge -- and each is driven
  # here from its own sentinels with its own mutant, because a layered fix with one layer reverted
  # passes on the layers left in place.
  #
  # The SEED is the consumer's fixture-root shape, `tests/fixtures`, and it carries a directory with
  # no run.sh. The membership arms test the MIDDLE member: a list joined by any other separator still
  # starts and ends with a name, so only a middle member separates a space join from a tab join.
  AL="$WORK/alllist.sh"; UL="$WORK/untraced.sh"
  sed -n '/^# READSET_ALLLIST_BEGIN$/,/^# READSET_ALLLIST_END$/p' "$DERIVER" > "$AL"
  sed -n '/^# READSET_UNTRACED_BEGIN$/,/^# READSET_UNTRACED_END$/p' "$DERIVER" > "$UL"
  MERGE_ARMS=$((MERGE_ARMS+1))
  if ! grep -q '^readset_all_list()' "$AL" || ! grep -q '^readset_untraced_lost()' "$UL"; then
    bad "extracted no readset_all_list (READSET_ALLLIST) or no readset_untraced_lost (READSET_UNTRACED) from $DERIVER — the --all list and the untraced-loss guard cannot be driven, and nothing below them ran"
  else
    ok "the deriver carries both the READSET_ALLLIST and READSET_UNTRACED spans, each defining its function"
    ALR="$WORK/allroot/tests/fixtures"
    mkdir -p "$ALR/aa" "$ALR/mid" "$ALR/zz" "$ALR/norun" || broken "mkdir failed"
    : > "$ALR/aa/run.sh"; : > "$ALR/mid/run.sh"; : > "$ALR/zz/run.sh"; : > "$ALR/norun/other.sh"
    NLC='
'
    allist_with() { ( . "$1"; readset_all_list "$ALR" ) 2>/dev/null; }
    # al_newline / al_middle / al_exact: one verdict word each, so a mutant is scored by the SAME
    # predicate as the arm it must move.
    al_newline() { case "$1" in *"$NLC"*) echo newline ;; '') echo empty ;; *) echo clean ;; esac; }
    al_middle()  { case " $1 " in *" mid "*) echo member ;; *) echo absent ;; esac; }
    al_exact()   { if [ "$1" = "aa mid zz" ]; then echo exact; else echo wrong; fi; }
    allist_with "$AL" > "$WORK/al.raw"
    AV="$(cat "$WORK/al.raw")"
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ "$(al_newline "$AV")" = clean ] && [ "$(wc -c < "$WORK/al.raw" | tr -d ' ')" -eq "${#AV}" ]; then
      ok "readset_all_list on a tests/fixtures root: the command-substitution value carries no newline, and the raw output has no trailing one either"
    else
      bad "readset_all_list output is not one newline-free line ('$AV', $(wc -c < "$WORK/al.raw" | tr -d ' ') raw bytes for ${#AV} chars) — every case \" \$LIST \" membership test in the deriver misses"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ "$(al_middle "$AV")" = member ]; then
      ok "  and its MIDDLE member is space-delimited on both sides — case \" \$LIST \" in *\" mid \"*) matches"
    else
      bad "  the middle member 'mid' is not space-delimited in '$AV' — a list joined by another separator passes the first and last names only"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    if [ "$(al_exact "$AV")" = exact ]; then
      ok "  and it is EXACTLY 'aa mid zz': the directory with no run.sh is excluded"
    else
      bad "  expected exactly 'aa mid zz' (norun/ has no run.sh), got '$AV'"
    fi

    # readset_untraced_lost: the omitted fixture is NOT first in a NEWLINE-separated list -- the shape
    # the base `--all` builder produced, where only the first name could ever have matched.
    printf 'traced-a\tp1\nfx-om\tp2\nkeep\tp3\ntraced-c\tp4\n' > "$WORK/ul.old"
    printf 'traced-a\tp1\nkeep\tp3\ntraced-c\tp4\n' > "$WORK/ul.m1"
    printf 'traced-a\tp1\ntraced-c\tp4\n' > "$WORK/ul.m2"
    printf 'fx\tp1\nfx-b\tp2\n' > "$WORK/ul.old3"; printf 'fx-b\tp2\n' > "$WORK/ul.m3"
    UL_NL="traced-a${NLC}fx-om${NLC}traced-c"
    ul_with() { # $1 span copy, $2 old, $3 merged, $4 traced; prints "<rc>|<output, space-joined>"
      local o r
      o="$( . "$1"; readset_untraced_lost "$2" "$3" "$4" 2>/dev/null )"; r=$?
      printf '%s|%s' "$r" "$(printf '%s' "$o" | tr '\n' ' ' | sed 's/ $//')"
    }
    MERGE_ARMS=$((MERGE_ARMS+1))
    U1="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.m1" "$UL_NL")"
    if [ "$U1" = "0|" ]; then
      ok "m1: a newline-separated traced list whose OMITTED fixture is not first reports no loss — the omitted fixture was traced, and the untouched one was kept"
    else
      bad "m1: expected rc 0 and no lost fixture, got '$U1' — under --all one omitted fixture would make the merge check die and discard every good trace"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U2="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.m2" "$UL_NL")"
    if [ "$U2" = "0|keep" ]; then
      ok "m2: an UNTOUCHED fixture missing from the merged map is printed ('keep') — the guard still fires"
    else
      bad "m2: expected rc 0 printing exactly 'keep', got '$U2' — a merge losing an untraced fixture would be written"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U3="$(ul_with "$UL" "$WORK/ul.old3" "$WORK/ul.m3" "fx-b")"
    if [ "$U3" = "0|fx" ]; then
      ok "m3: traced 'fx-b' does not count 'fx' as traced — membership is by exact name, so the lost 'fx' is printed"
    else
      bad "m3: expected 'fx' printed with only 'fx-b' traced, got '$U3' — a substring membership test reports 'fx' kept while it is gone"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U4="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.no-such-merged" "x")"
    if [ "$U4" = "2|" ]; then
      ok "an UNREADABLE merged map returns 2 with nothing printed, so the caller can tell 'did not look' from 'lost nothing'"
    else
      bad "an unreadable merged map did not return 2 with empty output: '$U4'"
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    U5="$(ul_with "$UL" "$WORK/ul.old" "$WORK/ul.m2" "traced-a fx-om traced-c")"
    if [ "$U5" = "$U2" ] && [ "$U5" = "0|keep" ]; then
      ok "  and a SPACE-separated list gives the same answer as the newline-separated one"
    else
      bad "  the space-separated list answers '$U5' where the newline-separated one answers '$U2'"
    fi

    # D4 -- ONE MUTANT PER NORMALISATION LAYER, plus the emptied guard (W1) and the two wrong shapes
    # D2 names. Each is scored by the predicate of the arm it must move; a mutant whose value does
    # not carry the property it was built to inject is reported as such, not as a kill.
    MERGE_ARMS=$((MERGE_ARMS+1))
    _o="$(grep -m1 '^    out="\${out}\${out:+ }' "$AL")"
    mut_line "$AL" "$WORK/al.newline.sh" "$_o" '    out="${out}${out:+'"$NLC"'}${d##*/}"'
    if cmp -s "$AL" "$WORK/al.newline.sh"; then bad "ALLLIST MUTANT newline-join did not apply"
    else
      _v="$(allist_with "$WORK/al.newline.sh")"
      case "$(al_newline "$_v")" in
        newline) ok "ALLLIST MUTANT newline-join (the base builder's shape) moves the no-newline arm: its value carries a newline" ;;
        *) bad "ALLLIST MUTANT newline-join: the value '$_v' carries no newline, so the no-newline arm is not what it moves" ;;
      esac
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    mut_line "$AL" "$WORK/al.tab.sh" "$_o" '    out="${out}${out:+	}${d##*/}"'
    if cmp -s "$AL" "$WORK/al.tab.sh"; then bad "ALLLIST MUTANT tab-join did not apply"
    else
      _v="$(allist_with "$WORK/al.tab.sh")"
      if [ "$(al_newline "$_v")" = clean ] && [ "$(al_middle "$_v")" = absent ]; then
        ok "ALLLIST MUTANT tab-join moves the middle-member arm only: no newline, but ' mid ' no longer matches"
      else
        bad "ALLLIST MUTANT tab-join: expected a newline-free value whose middle member does not match, got '$_v'"
      fi
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    _o="$(grep -m1 '^    \[ -f "\${d}run.sh" \] || continue$' "$AL")"
    mut_line "$AL" "$WORK/al.norun.sh" "$_o" '    :'
    if cmp -s "$AL" "$WORK/al.norun.sh"; then bad "ALLLIST MUTANT no-run.sh-check did not apply"
    else
      _v="$(allist_with "$WORK/al.norun.sh")"
      case "$(al_exact "$_v"):$(al_middle "$_v")" in
        wrong:member) ok "ALLLIST MUTANT no-run.sh-check moves the exact-list arm: '$_v' names the directory with no run.sh" ;;
        *) bad "ALLLIST MUTANT no-run.sh-check: expected a list naming norun with mid still a member, got '$_v'" ;;
      esac
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    _o="$(grep -m1 '^  traced="\$(printf .%s. "\$traced" | tr .\\n\\t. .  .)"$' "$UL")"
    mut_line "$UL" "$WORK/ul.nonorm.sh" "$_o" '  :'
    if cmp -s "$UL" "$WORK/ul.nonorm.sh"; then bad "UNTRACED MUTANT no-arg-normalisation did not apply"
    else
      _v="$(ul_with "$WORK/ul.nonorm.sh" "$WORK/ul.old" "$WORK/ul.m2" "$UL_NL")"
      _s="$(ul_with "$WORK/ul.nonorm.sh" "$WORK/ul.old" "$WORK/ul.m2" "traced-a fx-om traced-c")"
      if [ "$_v" != "0|keep" ] && [ "$_s" = "0|keep" ]; then
        ok "UNTRACED MUTANT no-arg-normalisation moves m2 for the NEWLINE list only ('$_v'), the space list still answering '$_s' — the guard's own normalisation is load-bearing"
      else
        bad "UNTRACED MUTANT no-arg-normalisation: newline list '$_v', space list '$_s' — expected the newline list alone to lose 'keep'"
      fi
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    _o="$(grep -m1 '^      if (index(traced, " " \$1 " ") == 0 && (\$1 in have) == 0) print \$1$' "$UL")"
    mut_line "$UL" "$WORK/ul.substr.sh" "$_o" '      if (index(traced, $1) == 0 && ($1 in have) == 0) print $1'
    if cmp -s "$UL" "$WORK/ul.substr.sh"; then bad "UNTRACED MUTANT substring-membership did not apply"
    else
      _v="$(ul_with "$WORK/ul.substr.sh" "$WORK/ul.old3" "$WORK/ul.m3" "fx-b")"
      if [ "$_v" != "0|fx" ] && [ "$(ul_with "$WORK/ul.substr.sh" "$WORK/ul.old" "$WORK/ul.m2" "$UL_NL")" = "0|keep" ]; then
        ok "UNTRACED MUTANT substring-membership moves m3 only ('$_v'): 'fx' inside 'fx-b' reads as traced, while m2 still prints 'keep'"
      else
        bad "UNTRACED MUTANT substring-membership: m3 answered '$_v' — expected it to lose 'fx' with m2 unmoved"
      fi
    fi
    MERGE_ARMS=$((MERGE_ARMS+1))
    mut_line "$UL" "$WORK/ul.empty.sh" "$_o" '      next'
    if cmp -s "$UL" "$WORK/ul.empty.sh"; then bad "UNTRACED MUTANT empty-guard (W1) did not apply"
    else
      _v="$(ul_with "$WORK/ul.empty.sh" "$WORK/ul.old" "$WORK/ul.m2" "$UL_NL")"
      if [ "$_v" = "0|" ]; then
        ok "UNTRACED MUTANT empty-guard (W1) moves m2: a guard that prints nothing writes a merge that lost 'keep'"
      else
        bad "UNTRACED MUTANT empty-guard (W1): expected rc 0 and nothing printed, got '$_v'"
      fi
    fi
    # The merge layer: driven with the NEWLINE list, the shape G3 drives -- merge_mutant above passes
    # a single token, which no normalisation can move.
    MERGE_ARMS=$((MERGE_ARMS+1))
    _o="$(grep -m1 '^  traced="\$(printf .%s. "\$traced" | tr .\\n. . .)"$' "$M")"
    mut_line "$M" "$WORK/merge.nonorm.sh" "$_o" '  :'
    if cmp -s "$M" "$WORK/merge.nonorm.sh"; then bad "MERGE MUTANT no-normalisation did not apply"
    else
      _v="$( . "$WORK/merge.nonorm.sh"; readset_merge_map "$WORK/old.map" "$WORK/new.map" "$(printf 'alpha\ndelta')" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ' )"
      case "$_v" in
        *"beta	src/b"*) bad "MERGE MUTANT no-normalisation: the newline-list merge still kept beta ('$_v'), so the newline arm does not depend on the merge's normalisation" ;;
        *"alpha	src/NEW"*) ok "MERGE MUTANT no-normalisation moves the newline-list merge arm: the untraced fixture's entries are lost" ;;
        *) bad "MERGE MUTANT no-normalisation: the merge emitted neither beta nor the traced entry ('$_v'), so the mutant scored nothing" ;;
      esac
    fi
  fi

  # ------------------------------------------- the deriver's discrimination control ----
  # WHAT THIS CONTROL IS FOR. The map exists to let fixtures be SKIPPED. A map in which every
  # read-set covers every path the map names selects the whole suite on every change and skips
  # nothing -- correct, useless, and indistinguishable from a working map by any arm that reads
  # the suite's verdict. The deriver refuses to WRITE such a map, and this is the arm that says
  # so.
  #
  # THE DEFECT THESE ARMS EXIST BECAUSE OF, AND WHY IT COULD NOT BE SEEN. The control built its
  # universe from the entries the run had just TRACED. Under `--list "<one fixture>"` that
  # universe IS that one fixture's read-set: the subset test is false for every possible input,
  # so the control refused every single-fixture refresh -- the mode the deriver's own header
  # advertises -- while printing the same FAIL line a genuinely non-discriminating map produces.
  # A wrong refusal and a right one read identically from outside, and the workaround (name more
  # fixtures) made the refusal go away without anyone learning why. Arm (d) below is the
  # motivating case and it is the one that would have been RED at base.
  #
  # THE CONTROL IS DRIVEN, NOT GREPPED. The rest of the deriver needs root and cannot run here,
  # so the shipped logic is extracted between its own sentinels and called -- a line-order grep
  # over the script would pass against a control that is present, correctly ordered, and wrong.
  #
  # A DERIVER PRESENT WITHOUT ITS CONTROL SPAN IS A FAILURE, NOT A SKIP, and the asymmetry with
  # the block above is deliberate. The ships-ahead-of-its-subject case is the deriver being
  # ABSENT, which is what a consumer sees between two pulls; a consumer never sees a deriver that
  # arrived without part of itself, because install.sh copies core/scripts and core/fixtures in
  # the same pull. Here, that state is a revision of this repo where the control has not landed.
  CTL="$WORK/control.sh"
  sed -n '/# READSET_CONTROL_BEGIN/,/# READSET_CONTROL_END/p' "$DERIVER" > "$CTL"
  if ! grep -q 'readset_discrimination_control()' "$CTL"; then
    bad "extracted no readset_discrimination_control from $DERIVER — the READSET_CONTROL span is absent, so the deriver's discrimination control cannot be driven and nothing below it ran"
  else
  # shellcheck disable=SC1090
  . "$CTL"

  # An independent recomputation of the control's own verdict, in shell rather than awk, so a
  # number the function PRINTS can be compared against one derived some other way. Echoes the
  # count of fixtures whose read-set is a PROPER subset of the map's union.
  ctl_proper_by_hand() {
    local map="$1" u f n p=0
    u="$(cut -f2 "$map" | LC_ALL=C sort -u | grep -c .)" || u=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      n="$(awk -F'\t' -v x="$f" '$1 == x { print $2 }' "$map" | LC_ALL=C sort -u | grep -c .)" || n=0
      [ "$n" -lt "$u" ] && p=$((p+1))
    done < <(cut -f1 "$map" | LC_ALL=C sort -u)
    printf '%s' "$p"
  }
  ctl_universe_of() { local n; n="$(cut -f2 "$1" | LC_ALL=C sort -u | grep -c .)" || n=0; printf '%s' "$n"; }
  ctl_fixtures_of() { local n; n="$(cut -f1 "$1" | LC_ALL=C sort -u | grep -c .)" || n=0; printf '%s' "$n"; }

  # SEEDS, each asserted to carry the property its arm turns on BEFORE any verdict is read. A
  # seed that quietly lost its property produces an arm that agrees with every implementation.
  printf 'alpha\tsrc/a\nalpha\tsrc/shared\nbeta\tsrc/b\nbeta\tsrc/shared\nbeta\tsrc/extra\n' > "$WORK/ctl.disc.map"
  printf 'alpha\tsrc/a\nalpha\tsrc/b\nbeta\tsrc/a\nbeta\tsrc/b\n' > "$WORK/ctl.cover.map"
  printf 'alpha\tsrc/NEW\n' > "$WORK/ctl.single.map"
  printf 'alpha\tsrc/a\nalpha\tsrc/x\nbeta\tsrc/b\ngamma\tsrc/g\n' > "$WORK/ctl.old.map"
  printf 'alpha\tsrc/ONLY\n' > "$WORK/ctl.new.map"
  [ "$(ctl_fixtures_of "$WORK/ctl.disc.map")" -ge 2 ] && [ "$(ctl_proper_by_hand "$WORK/ctl.disc.map")" -gt 0 ] \
    || broken "the discriminating seed carries no proper subset over >=2 fixtures; arm (a) would pass against a control that never compares anything"
  [ "$(ctl_proper_by_hand "$WORK/ctl.cover.map")" -eq 0 ] && [ "$(ctl_fixtures_of "$WORK/ctl.cover.map")" -ge 2 ] \
    || broken "the all-cover seed is not all-cover; arm (b) would be asserting a refusal of an input that ought to pass"
  [ "$(ctl_fixtures_of "$WORK/ctl.single.map")" -eq 1 ] \
    || broken "the single-fixture seed names more than one fixture; arm (c) tests the wrong shape"
  # THE PROPERTY ARM (d) AND MUTANT m1 TURN ON. If the two maps' unions were equal, driving the
  # control on the merged map and on the traced map would return the same verdict and neither
  # arm could tell base from tip.
  [ "$(ctl_universe_of "$WORK/ctl.old.map")" -gt "$(ctl_universe_of "$WORK/ctl.new.map")" ] \
    || broken "the --list seeds' unions do not differ ($(ctl_universe_of "$WORK/ctl.old.map") vs $(ctl_universe_of "$WORK/ctl.new.map")); arm (d) and mutant m1 would agree on every implementation"
  [ "$(ctl_proper_by_hand "$WORK/ctl.new.map")" -eq 0 ] \
    || broken "the traced-alone seed already discriminates, so the base defect it stands in for cannot be expressed"

  # (a) A MERGED MAP THAT DISCRIMINATES PASSES, and the verdict LINE is asserted, not just the
  # status: a control replaced by `true` returns 0 with nothing printed, which an rc-only arm
  # cannot tell from a control that looked.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CA="$(readset_discrimination_control "$WORK/ctl.disc.map" 2>&1)"; CA_RC=$?
  case "$CA_RC:$CA" in
    0:*"PASS  CONTROL"*) ok "the deriver's control ACCEPTS a map in which a read-set is a proper subset of the union — the map can skip something" ;;
    *) bad "a discriminating map was not accepted (rc $CA_RC): $(printf '%s' "$CA" | tr -d '\n')" ;;
  esac

  # (b) EVERY READ-SET EQUAL TO THE UNION IS REFUSED. This is the map the control exists to
  # stop: it is written, it is correct, and it skips nothing.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CB="$(readset_discrimination_control "$WORK/ctl.cover.map" 2>&1)"; CB_RC=$?
  case "$CB_RC:$CB" in
    1:*"FAIL  CONTROL"*) ok "  and it REFUSES a map in which every read-set covers the whole universe — that map would select the whole suite on every change" ;;
    *) bad "a map that discriminates nothing was not refused (rc $CB_RC): $(printf '%s' "$CB" | tr -d '\n')" ;;
  esac

  # (c) THE FIX BOUGHT THE PASS BY MERGING, NOT BY DISABLING THE CONTROL. A one-fixture map is
  # its own universe, so it still fails -- which is what makes arm (d) evidence about the merge
  # rather than about a control that was loosened until `--list` stopped complaining.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CC="$(readset_discrimination_control "$WORK/ctl.single.map" 2>&1)"; CC_RC=$?
  case "$CC_RC:$CC" in
    1:*"FAIL  CONTROL"*) ok "  and a ONE-FIXTURE map still fails, so the single-fixture refresh was fixed by merging rather than by relaxing the control" ;;
    *) bad "a single-fixture map was accepted (rc $CC_RC) — the control was loosened, not the input widened: $(printf '%s' "$CC" | tr -d '\n')" ;;
  esac

  # (d) THE MOTIVATING CASE, COMPOSED FROM THE TWO SHIPPED BLOCKS. `--list "<one fixture>"`
  # traces one fixture, merges its entries over the committed map, and the control judges the
  # map the run will WRITE. Judged on the traced entries alone -- the base behaviour, which
  # mutant m1 below reproduces -- this returns 1 and refuses a refresh that is entirely correct.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  readset_merge_map "$WORK/ctl.old.map" "$WORK/ctl.new.map" "alpha" | LC_ALL=C sort -u > "$WORK/ctl.merged.map"
  if [ "$(ctl_fixtures_of "$WORK/ctl.merged.map")" -lt 2 ]; then
    bad "the composed --list merge produced fewer than 2 fixtures, so arm (d) would test the single-fixture shape again instead of the merged one"
  else
    CD="$(readset_discrimination_control "$WORK/ctl.merged.map" 2>&1)"; CD_RC=$?
    case "$CD_RC:$CD" in
      0:*"PASS  CONTROL"*) ok "a --list refresh of ONE fixture is judged on the MERGED map and passes — the mode the deriver advertises is reachable" ;;
      *) bad "a --list refresh of one fixture was refused on its merged map (rc $CD_RC): $(printf '%s' "$CD" | tr -d '\n')" ;;
    esac
  fi

  # MUTANT m1 -- THE BASE DEFECT, REPRODUCED AS AN INPUT RATHER THAN AN EDIT. The base built the
  # universe from the traced entries; driving the shipped function on the traced map alone is
  # exactly that computation. It must refuse, or arm (d) is passing for a reason that has
  # nothing to do with the merge and would have been green before the fix.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CM1="$(readset_discrimination_control "$WORK/ctl.new.map" 2>&1)"; CM1_RC=$?
  if [ "$CM1_RC" -eq 0 ]; then
    bad "MUTANT m1: the traced map ALONE was accepted, so arm (d) cannot tell the merged judgement from the base one and would have been green at base"
  else
    ok "MUTANT m1 moves arm (d): judged on the TRACED entries alone the same refresh is refused — which is the base behaviour, and the arm discriminates base from tip"
  fi

  # MUTANT m2 -- AN ALWAYS-ACCEPTING CONTROL. Keyed on the verdict the function RETURNS, not on
  # a spelling: a control that cannot refuse is the failure mode every arm above would otherwise
  # score as a pass.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CM2="$WORK/control.alwayspass.sh"
  sed 's|exit 1|exit 0|' "$CTL" > "$CM2"
  if cmp -s "$CTL" "$CM2"; then
    bad "CONTROL MUTANT alwayspass: the edit matched nothing, so this mutant tests the unmutated function"
  else
    CM2_OUT="$( . "$CM2"; readset_discrimination_control "$WORK/ctl.cover.map" 2>&1 )"; CM2_RC=$?
    if [ "$CM2_RC" -eq 0 ]; then
      ok "CONTROL MUTANT alwayspass moves arm (b): a control that cannot refuse accepts the map that covers everything"
    else
      bad "CONTROL MUTANT alwayspass: the all-cover map was still refused (rc $CM2_RC) — arm (b) does not depend on the verdict the function returns"
    fi
  fi

  # MUTANT m3 -- THE mC SHAPE: each fixture's own path count taken from a SMALLER map while the
  # universe comes from the merged one. That is not a subset test at all. The smaller count is
  # below the larger union for every input, so the mutant accepts the very map arm (b) refuses,
  # and the fix would have shipped a control that judges nothing while reading as repaired.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CM3="$WORK/control.splitsource.sh"
  sed 's|if ((($1 SUBSEP $2) in seen) == 0)|if (FNR != NR) if ((($1 SUBSEP $2) in seen) == 0)|; s|if (($2 in path) == 0)|if (FNR == NR) if (($2 in path) == 0)|; s|"\$1"$|"$1" "${2:-$1}"|' "$CTL" > "$CM3"
  if cmp -s "$CTL" "$CM3"; then
    bad "CONTROL MUTANT splitsource: the edit matched nothing, so this mutant tests the unmutated function"
  else
    printf 'alpha\tsrc/a\n' > "$WORK/ctl.traced.map"
    CM3_OUT="$( . "$CM3"; readset_discrimination_control "$WORK/ctl.cover.map" "$WORK/ctl.traced.map" 2>&1 )"; CM3_RC=$?
    if [ "$CM3_RC" -eq 0 ]; then
      ok "CONTROL MUTANT splitsource moves arm (b): counting each fixture's own paths from a smaller map than the universe ACQUITS the map that covers everything"
    else
      bad "CONTROL MUTANT splitsource: the all-cover map was still refused (rc $CM3_RC) — arm (b) does not depend on both counts coming from one file"
    fi
  fi

  # AND THE SHIPPED FUNCTION'S OWN ANSWER IS DERIVED FROM ONE FILE. The mutant above proves the
  # split-source shape is reachable; this proves the shipped one is not in it, by comparing the
  # number the function PRINTS against the same number recomputed in shell over the same map --
  # two independently derived values rather than one value read twice.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CP_FN="$(readset_discrimination_control "$WORK/ctl.disc.map" 2>&1 | sed -n 's/.*CONTROL: \([0-9][0-9]*\) of .*/\1/p')"
  CP_HAND="$(ctl_proper_by_hand "$WORK/ctl.disc.map")"
  if [ -n "$CP_FN" ] && [ "$CP_FN" = "$CP_HAND" ]; then
    ok "  and the proper-subset count it reports ($CP_FN) equals one recomputed independently over that same file — both sides of the comparison come from one map"
  else
    bad "  the reported proper-subset count ('$CP_FN') does not match the hand-derived one ($CP_HAND) over the same map — the two sides are not being counted from the same file"
  fi

  # UNMUTATED CONTROL FOR THE MUTANTS ABOVE, re-sourced from the extracted span after the
  # mutants have been sourced in subshells. Presence-shaped on purpose: a function replaced by
  # nothing returns 0 and prints nothing, which is what a `bad` here catches and an rc-only
  # assertion would not.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CTL_OUT="$( . "$CTL"; readset_discrimination_control "$WORK/ctl.disc.map" 2>&1 )"; CTL_RC=$?
  case "$CTL_RC:$CTL_OUT" in
    0:*"PROPER subset of the 4-path universe"*)
      ok "CONTROL: the unmutated span still reports the baseline verdict over the 4-path universe, so the kills above are attributable" ;;
    *)
      bad "CONTROL: the unmutated span did not reproduce the baseline (rc $CTL_RC): $(printf '%s' "$CTL_OUT" | tr -d '\n') — every control mutant above is unattributable" ;;
  esac

  # (e) THE CALL SITE, WHICH EVERY ARM ABOVE IS BLIND TO. Arms (a)-(d) and the three mutants
  # all drive the EXTRACTED function; none of them reads the line that CALLS it. A non-fix that
  # leaves the function byte-identical and passes the TRACED map at the call site --
  # `readset_discrimination_control "$WORK/map"` instead of `"$MERGED"` -- reproduces the
  # original defect exactly (every single-fixture `--list` refresh dies) and is green on all of
  # them. Text about a program is not the program: the span proves what the function DOES, and
  # this arm proves what the deriver ASKS it. Both halves of the fix are one shipped behaviour.
  #
  # DERIVED, NEVER HAND-LISTED. Line numbers move on every edit above them, so the facts are
  # computed by one awk pass over the shipped file: the sentinel span is skipped so the
  # definition's own name is not counted as a call, `#` comments and quoted text are stripped
  # so neither a mention in prose nor one inside a string is counted as a call, and the
  # remaining invocations are counted. Exactly one must survive, its argument must be the
  # MERGED map, and both the assignment and the merge that fills it must sit above it -- a call
  # above `MERGED=` reads an unset variable under `set -u` and one above the merge judges an
  # empty file.
  #
  # THE QUOTE STATE IS CARRIED ACROSS LINES, which is the only correct model here: this deriver
  # embeds a multi-line awk program, a multi-line `python3 -c`, and a `die` message wrapped over
  # two lines. A per-line scanner calls all six of those lines unbalanced and then reports
  # nothing about the call site. Balance is asserted at END instead, so a genuinely unterminated
  # quote still refuses to answer rather than answering wrongly.
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CS="$(awk '
    BEGIN { TOK = "readset_discrimination_control"; L = length(TOK); SQ = sprintf("%c", 39); BS = "\\" }
    index($0, "# READSET_CONTROL_BEGIN") { span = 1; next }
    span { if (index($0, "# READSET_CONTROL_END")) span = 0; next }
    {
      code = ""; skel = ""; prev = ""; n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (q == SQ) {
          code = code c
          if (c == SQ) { skel = skel c; q = "" }
        } else if (q == "\"") {
          code = code c
          if (c == BS && i < n) { i++; code = code substr($0, i, 1); prev = c; continue }
          if (c == "\"") { skel = skel c; q = "" }
        } else {
          if (c == "#" && (i == 1 || prev == " " || prev == "\t")) break
          code = code c; skel = skel c
          if (c == BS && i < n) { i++; code = code substr($0, i, 1); skel = skel substr($0, i, 1) }
          else if (c == "\"" || c == SQ) q = c
        }
        prev = c
      }
      s = skel
      while ((p = index(s, TOK)) > 0) {
        ncall++; calls = calls " " FNR
        if (ncall == 1) {
          t = substr(code, index(code, TOK) + L)
          sub(/^[[:blank:]]+/, "", t)
          if (match(t, /^[^[:blank:]]+/)) arg = substr(t, 1, RLENGTH)
          cline = FNR
        }
        s = substr(s, p + L)
      }
      if (mline == 0 && code ~ /^[[:blank:]]*MERGED=/) mline = FNR
      if (rline == 0 && index(code, "readset_merge_map") && code ~ />[[:blank:]]*"\$MERGED"/) rline = FNR
      if (dline == 0 && index(code, "die \"controls failed")) dline = FNR
    }
    END {
      printf "%d %d %s %d %d %d %s\n", ncall, cline + 0, (arg == "" ? "-" : arg), \
        mline + 0, rline + 0, dline + 0, (q == "" ? "-" : "UNTERMINATED-QUOTE")
      printf "%s\n", (calls == "" ? "-" : calls)
    }
  ' "$DERIVER")"
  CS_HEAD="$(printf '%s\n' "$CS" | sed -n 1p)"
  CS_AT="$(printf '%s\n' "$CS" | sed -n 2p)"
  read -r E_N E_CALL E_ARG E_MERGED E_RUN E_DIE E_UNBAL <<EOF
$CS_HEAD
EOF
  if [ "$E_UNBAL" != "-" ]; then
    bad "(e) the call-site scan could not parse $DERIVER — a quote is left unterminated at end of file, so its comment and string stripping is unreliable and its counts are not evidence"
  elif [ "${E_N:-0}" -ne 1 ]; then
    bad "(e) the deriver makes $E_N calls to readset_discrimination_control outside the READSET_CONTROL span (lines$CS_AT) — exactly one is expected, and a second call site is judged by nothing here"
  elif [ "$E_ARG" != '"$MERGED"' ]; then
    bad "(e) the deriver's only call passes $E_ARG at line $E_CALL, not \"\$MERGED\" — the control is being driven on a map other than the merged one, which is the base defect (a single-fixture --list refresh is refused) with the function left byte-identical"
  elif [ "${E_MERGED:-0}" -eq 0 ] || [ "${E_RUN:-0}" -eq 0 ]; then
    bad "(e) the deriver has no MERGED= assignment (line ${E_MERGED:-0}) or no 'readset_merge_map ... > \"\$MERGED\"' (line ${E_RUN:-0}) — the argument named at line $E_CALL is not filled by the merge at all"
  elif [ "$E_MERGED" -ge "$E_CALL" ] || [ "$E_RUN" -ge "$E_CALL" ]; then
    bad "(e) the call at line $E_CALL runs before MERGED= (line $E_MERGED) or before the merge that fills it (line $E_RUN) — it would judge an unset or empty map"
  elif [ "${E_DIE:-0}" -eq 0 ] || [ "$E_CALL" -ge "$E_DIE" ]; then
    bad "(e) the call at line $E_CALL does not precede the 'die \"controls failed' at line ${E_DIE:-0} — its verdict is read after the run has already decided, or that die is gone and no verdict stops the write"
  else
    ok "the deriver's ONLY call of the control (line $E_CALL) passes the MERGED map, built by the merge at line $E_RUN into the variable assigned at line $E_MERGED, and is read by the die at line $E_DIE — the call site is bound, not just the function"
  fi
  fi

  # (f) THE CALL SITES OF THE TWO NEW SPANS. Every arm on readset_all_list and readset_untraced_lost
  # above drives the EXTRACTED function; a deriver that defines both and calls neither -- `--all`
  # back on its inline loop, the loss check deleted or demoted to a warning -- is green on all of
  # them. This scan reads what the deriver ASKS.
  #
  # THE (e) SCANNER CANNOT SEE `LIST="$(readset_all_list ...)"`: it drops quoted text, and that call
  # sits inside a double-quoted command substitution. This one carries a frame STACK, so a `$(`
  # inside double quotes returns to code until its own `)` and then back to the quote; balance of
  # both the quote state and the stack is asserted at END, so an unparseable file refuses to answer.
  # Both definition spans are skipped, so a definition is never counted as a call.
  rs_callscan() { # $1 deriver file; prints KEY<TAB>VALUE lines
    awk '
      BEGIN { SQ = sprintf("%c", 39); BS = "\\"; k = 0 }
      index($0, "# READSET_ALLLIST_BEGIN") == 1 || index($0, "# READSET_UNTRACED_BEGIN") == 1 { span = 1; next }
      span { if (index($0, "# READSET_ALLLIST_END") == 1 || index($0, "# READSET_UNTRACED_END") == 1) span = 0; next }
      {
        code = ""; skel = ""; prev = ""; n = length($0)
        for (i = 1; i <= n; i++) {
          c = substr($0, i, 1)
          if (q == SQ) {
            code = code c
            if (c == SQ) q = ""
          } else if (q == "\"") {
            code = code c
            if (c == BS && i < n) { i++; code = code substr($0, i, 1); prev = c; continue }
            if (c == "\"") q = ""
            else if (c == "$" && substr($0, i + 1, 1) == "(") { i++; code = code "("; k++; fr[k] = "\""; dep[k] = 0; q = "" }
          } else {
            if (c == "#" && (i == 1 || prev == " " || prev == "\t")) break
            code = code c; skel = skel c
            if (c == BS && i < n) { i++; code = code substr($0, i, 1); skel = skel substr($0, i, 1) }
            else if (c == "\"" || c == SQ) q = c
            else if (c == "$" && substr($0, i + 1, 1) == "(") { i++; code = code "("; skel = skel "("; k++; fr[k] = ""; dep[k] = 0 }
            else if (c == "(" && k > 0) dep[k]++
            else if (c == ")" && k > 0) { if (dep[k] == 0) { q = fr[k]; k-- } else dep[k]-- }
          }
          prev = c
        }
        if (index(skel, "readset_all_list")) { nal++; if (nal == 1) { alline = FNR; altext = code } }
        if (index(skel, "readset_untraced_lost")) { nul++; if (nul == 1) { ulline = FNR; ultext = code } }
        if (rline == 0 && index(code, "readset_merge_map") && code ~ />[[:blank:]]*"\$MERGED"/) rline = FNR
        if (cline == 0 && index(code, "die \"could not compare")) cline = FNR
        if (dline == 0 && index(code, "die \"merge dropped " SQ)) dline = FNR
        if (wline == 0 && code ~ /^}[[:blank:]]*>[[:blank:]]*"\$MAP"/) wline = FNR
      }
      END {
        printf "BAL\t%s\n", (q == "" && k == 0) ? "ok" : "UNBALANCED"
        printf "NAL\t%d\nALLINE\t%d\nALTEXT\t%s\n", nal, alline, altext
        printf "NUL\t%d\nULLINE\t%d\nULTEXT\t%s\n", nul, ulline, ultext
        printf "RLINE\t%d\nCLINE\t%d\nDLINE\t%d\nWLINE\t%d\n", rline, cline, dline, wline
      }
    ' "$1"
  }
  cs_get() { printf '%s\n' "$1" | sed -n "s/^$2	//p"; }
  # rs_callverdict <scan> -> one word per span: AL:<verdict> UL:<verdict>
  rs_callverdict() {
    local s="$1" alv ulv t n
    if [ "$(cs_get "$s" BAL)" != ok ]; then printf 'AL:unparsed UL:unparsed'; return; fi
    n="$(cs_get "$s" NAL)"; t="$(cs_get "$s" ALTEXT)"
    if [ "${n:-0}" -ne 1 ]; then alv="calls=$n"
    else case "$t" in
      *'--all)'*'LIST="$(readset_all_list "$TREE/$FIXTURE_ROOT")"'*) alv=bound ;;
      *) alv=wrongcall ;;
    esac; fi
    n="$(cs_get "$s" NUL)"; t="$(cs_get "$s" ULTEXT)"
    local ul r c d w; ul="$(cs_get "$s" ULLINE)"; r="$(cs_get "$s" RLINE)"; c="$(cs_get "$s" CLINE)"; d="$(cs_get "$s" DLINE)"; w="$(cs_get "$s" WLINE)"
    if [ "${n:-0}" -ne 1 ]; then ulv="calls=$n"
    else case "$t" in
      *'readset_untraced_lost "$MAP" "$MERGED" "$LIST"'*)
        if [ "$r" -eq 0 ] || [ "$r" -ge "$ul" ]; then ulv=beforemerge
        elif [ "$c" -eq 0 ] || [ "$c" -lt "$ul" ] || [ "$c" -gt $((ul+1)) ]; then ulv=unrefused
        elif [ "$d" -eq 0 ] || [ "$d" -le "$ul" ] || [ "$w" -eq 0 ] || [ "$d" -ge "$w" ]; then ulv=nodie
        else ulv=bound; fi ;;
      *) ulv=wrongcall ;;
    esac; fi
    printf 'AL:%s UL:%s' "$alv" "$ulv"
  }
  CONTROL_ARMS=$((CONTROL_ARMS+1))
  CSN="$(rs_callscan "$DERIVER")"
  CSV="$(rs_callverdict "$CSN")"
  case "$CSV" in
    "AL:bound UL:bound") ok "(f) the deriver's only readset_all_list call (line $(cs_get "$CSN" ALLINE)) builds LIST under --all from \$TREE/\$FIXTURE_ROOT, and its only readset_untraced_lost call (line $(cs_get "$CSN" ULLINE)) compares the merged map after the merge (line $(cs_get "$CSN" RLINE)), refuses on a failed compare (line $(cs_get "$CSN" CLINE)) and dies 'merge dropped' (line $(cs_get "$CSN" DLINE)) before the write (line $(cs_get "$CSN" WLINE))" ;;
    *) bad "(f) the call sites of the two new spans are not bound: $CSV — scan: $(printf '%s' "$CSN" | tr '\n\t' ' =')" ;;
  esac
  # Three deriver-copy mutants, each scored by the scan: --all back on the base inline loop (W2/W4
  # shape: the builder exists and nothing calls it), the loss check's call deleted, and its die
  # demoted to a warning (W1).
  _o="$(grep -m1 '^  --all)  LIST="\$(readset_all_list ' "$DERIVER")"
  mut_line "$DERIVER" "$WORK/cs.inline.sh" "$_o" '  --all)  LIST="$(cd "$TREE" && for d in "$FIXTURE_ROOT"/*/; do [ -f "$d/run.sh" ] && basename "$d"; done)" ;;'
  _o2="$(grep -m1 '^  readset_untraced_lost "\$MAP" "\$MERGED" "\$LIST" > ' "$DERIVER")"
  mut_line "$DERIVER" "$WORK/cs.nocall.sh" "$_o2" '  : > "$WORK/untraced.lost" \'
  _o3="$(grep -m1 "^    die \"merge dropped '" "$DERIVER")"
  mut_line "$DERIVER" "$WORK/cs.warn.sh" "$_o3" "    echo \"WARNING: merge dropped '\$f'\" >&2"
  for _cm in inline:AL:calls=0 nocall:UL:calls=0 warn:UL:nodie; do
    _n="${_cm%%:*}"; _want="${_cm#*:}"
    CONTROL_ARMS=$((CONTROL_ARMS+1))
    if cmp -s "$DERIVER" "$WORK/cs.$_n.sh"; then bad "CALL-SITE MUTANT $_n did not apply"; continue; fi
    _cv="$(rs_callverdict "$(rs_callscan "$WORK/cs.$_n.sh")")"
    case " $_cv " in
      *" $_want "*) ok "CALL-SITE MUTANT $_n moves (f): the scan reads '$_cv'" ;;
      *) bad "CALL-SITE MUTANT $_n: expected '$_want' in the scan verdict, got '$_cv'" ;;
    esac
  done

  # ------------------------------------------------------- the trace tree's POPULATION ----
  # WHAT THE TRACE TREE HOLDS DECIDES WHAT A FIXTURE CAN READ WHILE IT IS TRACED. It was `cp -a`
  # of the whole working tree; it is now `.git/` plus `git ls-files --cached --others
  # --exclude-standard`. The copy is extracted between its own sentinels and DRIVEN on a seeded
  # repo carrying one member per property the copy must get right, and the population is
  # compared EXACTLY -- a count or a presence check would accept a copy that carries extra files.
  #
  # THREE PLAUSIBLE WRONG COPIES ARE KILLED, EACH BY A NAMED MEMBER, which is what shows the seed
  # can express every way the copy goes wrong:
  #   `cp -a` then remove the ignored files -- the populated SUBMODULE's files survive
  #   `git archive HEAD`                      -- the untracked-not-ignored file is missing
  #   `rsync --exclude-from=.gitignore`       -- the `.claude/rules/` NEGATION is not honoured
  # A mutant that survives means the seed lacks the input that separates it; the repair is a
  # member, never a dropped mutant.
  CP="$WORK/copy.sh"
  sed -n '/# READSET_COPY_BEGIN/,/# READSET_COPY_END/p' "$DERIVER" > "$CP"
  CSEED="$WORK/copyseed"
  TRACE_ARMS=$((TRACE_ARMS+1))
  if ! grep -q 'readset_copy_tree()' "$CP"; then
    bad "extracted no readset_copy_tree from $DERIVER — the READSET_COPY span is absent, so the trace tree's population cannot be driven"
  else
    mkdir -p "$CSEED/inner" "$CSEED/src" || broken "mkdir failed"
    ( cd "$CSEED/inner" && git init -q . && echo i > in.txt && git add in.txt \
        && git -c user.email=f@f -c user.name=f commit -qm i ) >/dev/null 2>&1 || broken "could not seed the submodule's origin"
    ( cd "$CSEED/src" && git init -q . \
        && printf 'ignored.log\n.claude/*\n!.claude/rules/\n' > .gitignore \
        && echo t > tracked.txt && echo x > exec.sh && chmod 755 exec.sh && echo s > 'sp ace.txt' \
        && ln -s tracked.txt link && ln -s nowhere dangling \
        && mkdir -p .claude/rules && echo r > .claude/rules/x.md && echo '{}' > .claude/settings.local.json \
        && echo gone > deleted.txt \
        && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed \
        && git -c protocol.file.allow=always submodule -q add "file://$CSEED/inner" lib/sub \
        && git -c user.email=f@f -c user.name=f commit -qm sub \
        && echo u > untracked.txt && echo i > ignored.log && rm deleted.txt \
        && touch -m -t 200501010000 tracked.txt ) >/dev/null 2>&1 || broken "could not seed the copy's source repo"
    # THE SEED MUST CARRY EVERY PROPERTY BEFORE ANY VERDICT IS READ: a submodule that was not
    # populated cannot kill `cp -a`+rm, and an unignored settings file cannot test the negation.
    [ -f "$CSEED/src/lib/sub/in.txt" ] && [ -f "$CSEED/src/.claude/settings.local.json" ] \
      && [ -f "$CSEED/src/untracked.txt" ] && [ -f "$CSEED/src/ignored.log" ] \
      && ( cd "$CSEED/src" && git ls-files -s | grep -q '^160000' ) \
      && ( cd "$CSEED/src" && git check-ignore -q .claude/settings.local.json ) \
      && ! ( cd "$CSEED/src" && git check-ignore -q .claude/rules/x.md ) \
      || broken "the copy seed lost a property (populated gitlink, ignored settings file, negated rules file, untracked file) — the arms below could not tell a right copy from a wrong one"

    # The one population a correct copy produces: every regular file and symlink outside `.git/`.
    printf '%s\n' ./.claude/rules/x.md ./.gitignore ./.gitmodules ./dangling ./exec.sh ./link \
      './sp ace.txt' ./tracked.txt ./untracked.txt | LC_ALL=C sort > "$CSEED/expected"

    # copy_with <impl-file> <label> -> leaves the tree at $CSEED/dst.<label>, its stdout in .out,
    # and prints the DEFECTS found: population diff lines and named property failures.
    copy_with() {
      local impl="$1" label="$2" dst="$CSEED/dst.$2" scr="$CSEED/scr.$2" v=""
      mkdir -p "$dst" "$scr"
      ( . "$impl"; readset_copy_tree "$CSEED/src" "$dst" "$scr" ) > "$CSEED/$label.out" 2>&1
      ( cd "$dst" && find . -path ./.git -prune -o \( -type f -o -type l \) -print ) | LC_ALL=C sort > "$CSEED/$label.pop"
      v="$(LC_ALL=C comm -3 "$CSEED/expected" "$CSEED/$label.pop" | sed 's/^\t/EXTRA:/; s/^\.\//MISSING:.\//' | tr '\n' ' ')"
      [ -L "$dst/link" ] && [ "$(readlink "$dst/link")" = tracked.txt ] || v="$v link-not-a-symlink"
      [ -L "$dst/dangling" ] || v="$v dangling-symlink-lost"
      [ -x "$dst/exec.sh" ] || v="$v exec-bit-lost"
      [ -n "$(find "$dst/tracked.txt" -newer "$CSEED/src/tracked.txt" 2>/dev/null)" ] && v="$v mtime-not-preserved"
      [ -d "$dst/lib/sub" ] || v="$v gitlink-dir-absent"
      [ -d "$dst/.git/modules/lib/sub" ] || v="$v git-dir-not-copied"
      printf '%s' "$v"
    }

    CV="$(copy_with "$CP" shipped)"
    if [ -z "$CV" ]; then
      ok "the shipped copy lands EXACTLY the tracked and untracked-not-ignored files — exec bit, mtime, a space in a name, a symlink and a dangling symlink kept; the ignored file, the ignored .claude/settings.local.json and the submodule's contents absent; the negated .claude/rules/x.md present; .git/ whole"
    else
      bad "the shipped copy's population is wrong: $CV"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ -d "$CSEED/dst.shipped/lib/sub" ] && [ -z "$(ls -A "$CSEED/dst.shipped/lib/sub" 2>/dev/null)" ] \
       && grep -q "deleted.txt" "$CSEED/shipped.out"; then
      ok "  and the GITLINK lands as an EMPTY directory, and the deleted-unstaged path is skipped and NAMED rather than aborting the copy"
    else
      bad "  the gitlink is not an empty directory, or the deleted-unstaged path was not named: $(tr '\n' ' ' < "$CSEED/shipped.out")"
    fi

    # The three wrong copies, each written as a whole replacement of the function.
    cat > "$CSEED/m.cprm.sh" <<'MUT'
readset_copy_tree() {
  cp -a "$1/." "$2/" || return 1
  ( cd "$2" && git ls-files -z --others --ignored --exclude-standard | xargs -0 rm -f )
  echo "copied"
}
MUT
    cat > "$CSEED/m.archive.sh" <<'MUT'
readset_copy_tree() {
  ( cd "$1" && git archive HEAD ) | ( cd "$2" && tar -xf - ) || return 1
  cp -a "$1/.git" "$2/.git" || return 1
  echo "copied"
}
MUT
    cat > "$CSEED/m.rsync.sh" <<'MUT'
readset_copy_tree() {
  rsync -a --exclude-from="$1/.gitignore" "$1/" "$2/" || return 1
  echo "copied"
}
MUT
    for _m in "cprm:./lib/sub/in.txt:EXTRA" "archive:./untracked.txt:MISSING" "rsync:./.claude/rules/x.md:MISSING"; do
      _n="${_m%%:*}"; _rest="${_m#*:}"; _member="${_rest%:*}"; _dir="${_rest##*:}"
      TRACE_ARMS=$((TRACE_ARMS+1))
      if [ "$_n" = rsync ] && ! command -v rsync >/dev/null 2>&1; then
        bad "COPY MUTANT rsync: no rsync on PATH, so this mutant cannot be built and its kill is unproven"; continue
      fi
      _v="$(copy_with "$CSEED/m.$_n.sh" "$_n")"
      case " $_v " in
        *"$_dir:$_member"*) ok "COPY MUTANT $_n is killed by its named member ($_dir $_member)" ;;
        *) bad "COPY MUTANT $_n was not killed by $_dir $_member — the seed lacks the input that separates it (defects seen: ${_v:-none})" ;;
      esac
    done
  fi

  # ---------------------------------------------- submodule rows and the ignore filter ----
  # `git check-ignore --stdin` REFUSES A WHOLE BATCH -- exit 128, "is in submodule" -- when one
  # row lies inside a submodule, and drop_ignored's fail-open branch then keeps every row. On a
  # tree with a gitlink the ignore filter never ran. The shipped filter collapses submodule rows
  # to the gitlink path before asking. Driven from its sentinels, on the same seeded repo.
  DR="$WORK/drop.sh"
  sed -n '/# READSET_DROP_BEGIN/,/# READSET_DROP_END/p' "$DERIVER" > "$DR"
  TRACE_ARMS=$((TRACE_ARMS+1))
  if ! grep -q 'drop_ignored()' "$DR"; then
    bad "extracted no drop_ignored from $DERIVER — the READSET_DROP span is absent"
  elif [ ! -d "$CSEED/src/.git" ]; then
    bad "the submodule arm has no seeded repo to run on (the copy arm above did not seed one)"
  else
    printf '%s\n' tracked.txt ignored.log .claude/settings.local.json lib/sub/in.txt untracked.txt .claude/rules/x.md > "$CSEED/batch"
    printf '%s\n' .claude/rules/x.md lib/sub tracked.txt untracked.txt | LC_ALL=C sort > "$CSEED/batch.expected"
    # THE SEED MUST REPRODUCE THE REFUSAL, or the arm proves a filter that was never at risk.
    ( cd "$CSEED/src" && git check-ignore --stdin --non-matching --verbose < "$CSEED/batch" ) >/dev/null 2>&1
    CI_RC=$?
    [ "$CI_RC" -ne 0 ] || broken "raw check-ignore on the submodule batch exited 0 — the seed no longer reproduces the refusal"
    DO="$( TREE="$CSEED/src"; . "$DR"; drop_ignored < "$CSEED/batch" )"
    if [ "$(printf '%s\n' "$DO" | LC_ALL=C sort)" = "$(cat "$CSEED/batch.expected")" ]; then
      ok "a batch carrying a SUBMODULE row still filters (raw check-ignore exits $CI_RC on it): both ignored rows dropped, tracked, untracked and negated rows kept, the inner row collapsed to the gitlink"
    else
      bad "the submodule batch did not filter to exactly the non-ignored rows (raw check-ignore rc $CI_RC): got $(printf '%s' "$DO" | tr '\n' ' ')"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    sed 's|substr($1, 1, 7) == "160000 "|0|' "$DR" > "$CSEED/drop.mut.sh"
    if cmp -s "$DR" "$CSEED/drop.mut.sh"; then
      bad "DROP MUTANT nogitlink: the edit matched nothing"
    else
      DM="$( TREE="$CSEED/src"; . "$CSEED/drop.mut.sh"; drop_ignored < "$CSEED/batch" )"
      case "$DM" in
        *ignored.log*) ok "DROP MUTANT nogitlink: without the gitlink collapse the batch is refused and the ignored rows survive — the arm above depends on it" ;;
        *) bad "DROP MUTANT nogitlink: the ignored row was still dropped, so the arm above does not depend on the gitlink collapse: $(printf '%s' "$DM" | tr '\n' ' ')" ;;
      esac
    fi
  fi

  # ------------------------------------------ the sandbox tracer refuses a LOSSY window ----
  # `log stream` drops reports when it cannot keep up and prints `=== Messages dropped during
  # live streaming`. The reports it dropped are gone, so the set that remains is short by an
  # unknown amount -- the silent-skip direction. The deriver must OMIT such a fixture.
  #
  # LOSS IS FORCED, NOT AWAITED: an UNSCOPED profile reports every operation the fixture makes
  # anywhere, and a burst of it overflows the stream. It is still probabilistic -- measured, 4
  # of 5 unscoped bursts dropped -- so the arm checks an INVARIANT on every attempt, in both
  # directions: a window WITH a drop notice is omitted naming the drop, and a window without one
  # is mapped. It needs at least one lossy window to count as proven; with none in three
  # attempts it SKIPS, naming why. It never passes on attempts that forced nothing.
  #
  # IT SKIPS where the stream cannot run: no sandbox-exec, no /usr/bin/log, running as root (the
  # sandbox tracer refuses root), or INSIDE a sandbox -- `log stream` answers "Cannot run while
  # sandboxed", which is exactly this fixture's state while `--tracer sandbox` traces it.
  LS_WHY=""
  if ! command -v sandbox-exec >/dev/null 2>&1; then LS_WHY="no sandbox-exec (not macOS)"
  elif [ ! -x /usr/bin/log ]; then LS_WHY="no /usr/bin/log"
  elif [ "$(id -u)" = 0 ]; then LS_WHY="running as root, which --tracer sandbox refuses"
  else
    /usr/bin/log stream --style compact --timeout 1s --predicate 'sender == "readset-skip-probe"' >/dev/null 2>"$WORK/ls.err" \
      || LS_WHY="log stream unavailable here: $(head -1 "$WORK/ls.err")"
  fi
  if [ -n "$LS_WHY" ]; then
    printf '  SKIP  sandbox-tracer loss arm and deriver width arm: %s\n' "$LS_WHY"
  else
    PR="$WORK/lossprobe"
    mkdir -p "$PR/core/fixtures/burst" "$PR/core/scripts" "$PR/.githooks" "$PR/d" || broken "mkdir failed"
    _i=0; while [ "$_i" -lt 400 ]; do _i=$((_i+1)); echo "$_i" > "$PR/d/f$_i"; done
    printf '#!/bin/bash\nfor d in core/fixtures/*/; do :; done\n' > "$PR/.githooks/pre-push"
    # The probe fixture also ECHOES the width knob, which the width arm below reads from its log.
    printf '#!/bin/bash\necho "width=${VAS_INNER_POOL_WIDTH:-unset}"\necho "ems=${EMS_POOL_WIDTH:-unset}"\ncat d/f* >/dev/null\nls -lR /usr/share >/dev/null 2>&1\ncat d/f* >/dev/null\necho burst ok\n' > "$PR/core/fixtures/burst/run.sh"
    # The width mutant's repo is the same seed with the deriver's env injection removed from both
    # launch lines. It is seeded BEFORE the original's `git init`, so it copies no `.git`.
    PRM="$WORK/widthmut"
    mkdir -p "$PRM" || broken "mkdir failed"
    cp -R "$PR/." "$PRM/" || broken "could not copy the probe repo for the width mutant"
    cp "$DERIVER" "$PR/core/scripts/derive-fixture-readsets.sh"
    sed 's| env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash | bash |' "$DERIVER" > "$PRM/core/scripts/derive-fixture-readsets.sh"
    ( cd "$PR" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm probe ) >/dev/null 2>&1 \
      || broken "could not seed the loss probe repo"
    ( cd "$PRM" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm probe ) >/dev/null 2>&1 \
      || broken "could not seed the width mutant repo"
    printf '(version 3)\n(allow default (with report))\n' > "$WORK/unscoped.sb"
    L_FORCED=0; L_CLEAN=0; L_BAD=""; _a=0
    while [ "$_a" -lt 3 ] && [ "$L_FORCED" -eq 0 ]; do
      _a=$((_a+1)); _tr="$WORK/losstr.$_a"
      # The exit status is NOT read: a one-fixture run can never pass the discrimination control
      # (arm (c) above), so the deriver dies after the per-fixture line. That line is the verdict.
      # `env -u` so the width arm below reads what the DERIVER set, never a value inherited from
      # whatever ran this fixture -- under the deriver itself the knob is already 1 out here.
      ( cd "$PR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH AI_DLC_READSET_TRACE_ROOT="$_tr" AI_DLC_READSET_SANDBOX_PROFILE="$WORK/unscoped.sb" \
          bash core/scripts/derive-fixture-readsets.sh --list burst --tracer sandbox ) > "$WORK/loss.$_a.out" 2>&1
      _line="$(grep -E '^  burst ' "$WORK/loss.$_a.out")"
      _win="$(find "$_tr" -name burst.win 2>/dev/null | head -1)"
      _d=0; [ -n "$_win" ] && { _d="$(grep -c 'dropped during' "$_win")" || _d=0; }
      case "$_d:$_line" in
        0:*" paths"*) L_CLEAN=$((L_CLEAN+1)) ;;
        0:*"dropped reports"*) L_BAD="$L_BAD attempt $_a omitted for a drop its window does not carry;" ;;
        0:*) : ;;   # omitted for another reason (settle/flush) -- neither direction observed
        *:*"dropped reports"*) L_FORCED=$((L_FORCED+1)) ;;
        *) L_BAD="$L_BAD attempt $_a had $_d drop notice(s) in its window and was not omitted for it: '$_line';" ;;
      esac
    done
    if [ -n "$L_BAD" ]; then
      TRACE_ARMS=$((TRACE_ARMS+1))
      bad "the sandbox tracer's loss refusal is wrong:$L_BAD"
    elif [ "$L_FORCED" -eq 0 ]; then
      printf '  SKIP  sandbox-tracer loss arm: no attempt of %s forced a drop notice into the window (%s clean), so the refusal was not exercised\n' "$_a" "$L_CLEAN"
    else
      TRACE_ARMS=$((TRACE_ARMS+1))
      ok "the sandbox tracer OMITS a fixture whose window carries a 'dropped during' notice ($L_FORCED forced, $L_CLEAN clean window(s) mapped, over $_a attempt(s)) — a lossy trace never becomes a smaller read-set"
    fi

    # ------------------------------ the deriver runs a traced fixture at inner pool width 1 ----
    # BL-375: validator-arm-selection's 6-way inner pool outruns `log stream` and its trace drops
    # reports, so the deriver launches every fixture as `... env VAS_INNER_POOL_WIDTH=1 bash`.
    # There are TWO EMITTING LINES, one per launch path, and each is bound by running it. This arm
    # binds the `sandboxed` line under `--tracer sandbox`: the probe fixture echoes the knob, and the
    # log the deriver captured for attempt 1 above must read `width=1`. The same `sandboxed` line
    # under `--tracer both` goes through sudo and is bound in the stub world further down. The
    # `fs_usage` line runs only as root, so no unprivileged fixture can drive it; it stays covered
    # only by the operator's own `sudo` run. Two controls here, each presence-shaped
    # (`burst ok` must appear, so a run that never reached the fixture cannot score):
    #   * the same probe run OUTSIDE the deriver reads `width=unset`, so the 1 came from the deriver
    #     and not from the probe or the environment;
    #   * a deriver copy with the injection removed from both launch lines yields `width=unset`, so
    #     the arm fails when the injection is gone.
    W_LOG="$WORK/losstr.1/w/burst.log"
    TRACE_ARMS=$((TRACE_ARMS+1))
    if grep -qx 'burst ok' "$W_LOG" 2>/dev/null && grep -qx 'width=1' "$W_LOG" && grep -qx 'ems=1' "$W_LOG"; then
      ok "WIDTH: the deriver ran the traced probe fixture with VAS_INNER_POOL_WIDTH=1 and EMS_POOL_WIDTH=1 (its captured log reads width=1, ems=1)"
    else
      bad "WIDTH: the deriver's traced run of the probe fixture did not see VAS_INNER_POOL_WIDTH=1 — log reads '$(grep -m1 '^width=' "$W_LOG" 2>/dev/null)', burst ok present: $(grep -cx 'burst ok' "$W_LOG" 2>/dev/null || :). validator-arm-selection would trace at full width and drop reports"
    fi
    W_OUT="$( cd "$PR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH bash core/fixtures/burst/run.sh 2>/dev/null )"
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$W_OUT" in
      *"width=unset"*"ems=unset"*"burst ok"*) ok "WIDTH CONTROL: the same probe run outside the deriver reads width=unset, so the 1 above is the deriver's" ;;
      *) bad "WIDTH CONTROL: the probe run outside the deriver did not read width=unset: '$(printf '%s' "$W_OUT" | tr '\n' ' ')'" ;;
    esac
    TRACE_ARMS=$((TRACE_ARMS+1))
    if cmp -s "$DERIVER" "$PRM/core/scripts/derive-fixture-readsets.sh"; then
      bad "WIDTH MUTANT did not apply: removing the env injection changed nothing in the deriver copy, so this control would test an unmutated deriver"
    else
      _trm="$WORK/widthmut.tr"
      ( cd "$PRM" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH AI_DLC_READSET_TRACE_ROOT="$_trm" \
          bash core/scripts/derive-fixture-readsets.sh --list burst --tracer sandbox ) > "$WORK/widthmut.out" 2>&1
      WM_LOG="$_trm/w/burst.log"
      if grep -qx 'burst ok' "$WM_LOG" 2>/dev/null && grep -qx 'width=unset' "$WM_LOG" && grep -qx 'ems=unset' "$WM_LOG"; then
        ok "WIDTH MUTANT: with the env injection removed from both launch lines the traced probe reads width=unset — the arm above depends on that line"
      else
        bad "WIDTH MUTANT: the injection-free deriver's traced run did not read width=unset with 'burst ok' present: '$(tr '\n' ' ' < "$WM_LOG" 2>/dev/null | cut -c1-120)' — $(tail -2 "$WORK/widthmut.out" | tr '\n' ' ')"
      fi
    fi

    # ------------------------------- the LOSS CANARY against a REAL stream that loses reads ----
    # 1500 files read by 8 concurrent readers. Under an UNSCOPED profile the stream loses reads,
    # and the canary must name them in the OMITTED line. The SCOPED side traces its OWN small
    # burst, 1 reader over 100 files: the 8x1500 burst lost reads under the scoped profile too, in
    # every attempt measured (0 of 8 clean at 1-minute load 8.3-26.8, and 4 of 4 SKIPs at load 2-8),
    # so a scoped side on the big burst could never be exercised and the arm always skipped.
    # Probabilistic in both directions, so each side gets up to three attempts
    # and the arm SKIPS, naming why, when no attempt exercised that side -- it never passes on
    # attempts that forced nothing. The deterministic proof is the stub-world canary arm, which runs
    # wherever this fixture runs unprivileged; this one is the real-kernel confirmation.
    #   unscoped: forced = an attempt whose fxa.canary is non-empty; that attempt must be OMITTED
    #             with `LOSS CANARY: <n>` where n is the canary file's line count.
    #   scoped:   clean  = an attempt with 0 drop notices and an empty canary; it must be MAPPED.
    #   mutant:   the guard deleted, unscoped: a forced attempt's line must NOT carry the token.
    CP="$WORK/canaryprobe"
    mkdir -p "$CP/core/fixtures/burst8" "$CP/core/fixtures/small1" "$CP/core/scripts" "$CP/.githooks" "$CP/d" "$CP/s" || broken "mkdir failed"
    _i=0; while [ "$_i" -lt 1500 ]; do _i=$((_i+1)); echo "$_i" > "$CP/d/f$_i"; done
    _i=0; while [ "$_i" -lt 100 ]; do _i=$((_i+1)); echo "$_i" > "$CP/s/f$_i"; done
    printf '#!/bin/bash\nfor d in core/fixtures/*/; do :; done\n' > "$CP/.githooks/pre-push"
    printf '#!/bin/bash\nfor _r in 1 2 3 4 5 6 7 8; do cat d/f* >/dev/null & done\nwait\necho burst8 ok\n' > "$CP/core/fixtures/burst8/run.sh"
    printf '#!/bin/bash\ncat s/f* >/dev/null\necho small1 ok\n' > "$CP/core/fixtures/small1/run.sh"
    cp "$DERIVER" "$CP/core/scripts/derive-fixture-readsets.sh"
    sed '/^  \[ "\$canary" = 0 \]    || why=/d' "$DERIVER" > "$WORK/deriver.nocanary.real.sh"
    ( cd "$CP" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm probe ) >/dev/null 2>&1 \
      || broken "could not seed the canary probe repo"
    canary_try() { # $1 tag  $2 profile ("" = the deriver's scoped one)  $3 fixture (default burst8); prints "<line>|<canary n>|<drops>"
      local tr="$WORK/cantr.$1" c d f="${3:-burst8}"
      ( cd "$CP" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH AI_DLC_READSET_TRACE_ROOT="$tr" \
          ${2:+AI_DLC_READSET_SANDBOX_PROFILE="$2"} bash core/scripts/derive-fixture-readsets.sh --list "$f" --tracer sandbox ) > "$WORK/can.$1.out" 2>&1
      c="$(grep -c . "$tr/w/$f.canary" 2>/dev/null)" || c=0
      d="$(grep -c 'dropped during' "$tr/w/$f.win" 2>/dev/null)" || d=0
      printf '%s|%s|%s' "$(grep -m1 -E "^  $f " "$WORK/can.$1.out" | tr -s ' ')" "$c" "$d"
    }
    C_FORCED=0; C_BAD=""; _a=0
    while [ "$_a" -lt 3 ] && [ "$C_FORCED" -eq 0 ]; do
      _a=$((_a+1)); _r="$(canary_try "u$_a" "$WORK/unscoped.sb")"
      _l="${_r%%|*}"; _c="${_r#*|}"; _c="${_c%%|*}"
      if [ "$_c" -gt 0 ]; then
        case "$_l" in
          *"OMITTED ("*"LOSS CANARY: $_c path(s)"*) C_FORCED=$((C_FORCED+1)) ;;
          *) C_BAD="$C_BAD unscoped attempt $_a lost $_c read(s) and its line does not name them: '$_l';" ;;
        esac
      fi
    done
    S_CLEAN=0; _s=0
    while [ "$_s" -lt 3 ] && [ "$S_CLEAN" -eq 0 ]; do
      _s=$((_s+1)); _r="$(canary_try "s$_s" "" small1)"
      _l="${_r%%|*}"; _rest="${_r#*|}"; _c="${_rest%%|*}"; _d="${_rest#*|}"
      if [ "$_c" -eq 0 ] && [ "$_d" -eq 0 ]; then
        case "$_l" in
          *" paths") S_CLEAN=$((S_CLEAN+1)) ;;
          *"LOSS CANARY"*) C_BAD="$C_BAD scoped attempt $_s had an empty canary and was omitted for it: '$_l';" ;;
          *) : ;;   # omitted for another reason (settle/flush) -- neither direction observed
        esac
      fi
    done
    TRACE_ARMS=$((TRACE_ARMS+1))
    if [ -n "$C_BAD" ]; then
      bad "REAL CANARY:$C_BAD"
    elif [ "$C_FORCED" -eq 0 ] || [ "$S_CLEAN" -eq 0 ]; then
      printf '  SKIP  real-stream canary arm: %s of %s unscoped attempt(s) lost a read, %s of %s scoped attempt(s) traced clean -- a side was not exercised (the stub-world canary arm is the deterministic proof)\n' "$C_FORCED" "$_a" "$S_CLEAN" "$_s"
      TRACE_ARMS=$((TRACE_ARMS-1))
    else
      ok "REAL CANARY: an unscoped 8-reader burst over 1500 files that lost reads is OMITTED naming the LOSS CANARY count (attempt $_a), and the scoped profile maps a 1-reader burst over 100 files (attempt $_s)"
      cp "$WORK/deriver.nocanary.real.sh" "$CP/core/scripts/derive-fixture-readsets.sh"
      TRACE_ARMS=$((TRACE_ARMS+1))
      if cmp -s "$DERIVER" "$WORK/deriver.nocanary.real.sh"; then
        bad "REAL CANARY MUTANT did not apply: deleting the canary guard changed nothing"
      else
        _m=0; _mv=""
        while [ "$_m" -lt 3 ] && [ -z "$_mv" ]; do
          _m=$((_m+1)); _r="$(canary_try "m$_m" "$WORK/unscoped.sb")"
          _l="${_r%%|*}"; _c="${_r#*|}"; _c="${_c%%|*}"
          [ "$_c" -gt 0 ] || continue
          case "$_l" in *"LOSS CANARY"*) _mv="named" ;; *) _mv="silent" ;; esac
        done
        case "$_mv" in
          silent) ok "REAL CANARY MUTANT: with the guard deleted an unscoped attempt that lost reads carries no LOSS CANARY in its line — the arm depends on that line" ;;
          named)  bad "REAL CANARY MUTANT: with the guard deleted the line still names the LOSS CANARY: '$_l'" ;;
          *)      printf '  SKIP  real-stream canary mutant: no unscoped attempt of %s lost a read\n' "$_m"; TRACE_ARMS=$((TRACE_ARMS-1)) ;;
        esac
      fi
    fi
  fi

  # ------------------------------------------------- `--tracer both`: the comparison mode ----
  # The operator runs `sudo bash core/scripts/derive-fixture-readsets.sh --all --tracer both` to
  # decide whether the sandbox tracer may replace fs_usage. Its verdict must never read clean
  # having compared nothing, its refusals must never read as a verdict, and it must never write
  # the map. None of that needs root to prove: the verdict logic is driven from its sentinels, the
  # refusals are reached before any tracer starts, and the no-write guarantee is driven through
  # the WHOLE script in a stub world (stub fs_usage, sandbox-exec, sudo, id, and log stream).
  BOTH_SPAN="$WORK/both.sh"
  sed -n '/# READSET_BOTH_BEGIN/,/# READSET_BOTH_END/p' "$DERIVER" > "$BOTH_SPAN"
  BOTH_ARMS=$((BOTH_ARMS+1))
  if ! grep -q 'readset_both_verdict()' "$BOTH_SPAN" || ! grep -q 'readset_both_compare()' "$BOTH_SPAN"; then
    bad "extracted no readset_both_verdict/readset_both_compare from $DERIVER — the READSET_BOTH span is absent, so --tracer both cannot be driven"
  else
    ok "the READSET_BOTH span carries the comparison and the verdict"
    BW="$WORK/both"
    mkdir -p "$BW/r" || broken "mkdir failed"
    printf '*.log\n' > "$BW/r/.gitignore"
    ( cd "$BW/r" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm s ) >/dev/null 2>&1 \
      || broken "could not seed the --tracer both comparison repo"
    # fs_usage saw five paths; the sandbox saw two of them plus one fs_usage did not. Exactly ONE
    # is a sandbox miss: `.git` and `.git/HEAD` go by prefix, `build.log` by the ignore filter.
    printf '%s\n' .git .git/HEAD build.log src/a.sh src/miss.sh | LC_ALL=C sort > "$BW/fs"
    printf '%s\n' src/a.sh src/neg.sh | LC_ALL=C sort > "$BW/sb"
    both_compare_with() { # $1 span file; prints "<counts>|<sandbox-missed paths>"
      ( TREE="$BW/r"; . "$DR"; . "$1"
        c="$(readset_both_compare "$BW/fs" "$BW/sb" "$BW/cmp")" || c="rc=$?"
        printf '%s|%s' "$c" "$(tr '\n' ' ' < "$BW/cmp.sbmiss" 2>/dev/null)" )
    }
    BC="$(both_compare_with "$BOTH_SPAN")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    if [ "$BC" = "1 1|src/miss.sh " ]; then
      ok "a sandbox miss is fs_usage MINUS sandbox, outside .git/** and the ignored set: exactly src/miss.sh (1 sandbox-missed, 1 fs_usage-missed)"
    else
      bad "the comparison did not isolate exactly src/miss.sh as the one sandbox miss: got '$BC'"
    fi
    # One verdict driver; the results rows are the shape the loop writes.
    both_verdict_with() { # $1 span  $2 list  $3 results file; prints "<rc>|<line>"
      ( . "$1"; l="$(readset_both_verdict "$2" "$3" "$BW/missed" "$BW")"; printf '%s|%s' "$?" "$l" )
    }
    printf 'fa\tcompared\t0\t2\t\nfb\tcompared\t0\t0\t\n' > "$BW/res.clean"
    printf 'fa\tcompared\t2\t0\t\nfb\tcompared\t1\t0\t\nfc\tcompared\t0\t0\t\n' > "$BW/res.miss"
    printf 'fa\tcompared\t0\t0\t\nfb\tuncompared\t-\t-\tsandbox set empty\n' > "$BW/res.part"
    V="$(both_verdict_with "$BOTH_SPAN" "fa fb" "$BW/res.clean")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "0|SANDBOX-MISSES-NOTHING"*"2 of 2"*) ok "every listed fixture compared with no sandbox miss reads SANDBOX-MISSES-NOTHING, exit 0 — fs_usage-missed paths do not count against it" ;;
      *) bad "a clean comparison did not read SANDBOX-MISSES-NOTHING at exit 0: '$V'" ;;
    esac
    V="$(both_verdict_with "$BOTH_SPAN" "fa fb fc" "$BW/res.miss")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "1|SANDBOX-MISSES 3 path(s) across 2 fixture(s)"*) ok "misses read SANDBOX-MISSES <n> path(s) across <m> fixture(s), exit 1 — summed over fixtures, counting only those that missed" ;;
      *) bad "misses did not read 'SANDBOX-MISSES 3 path(s) across 2 fixture(s)' at exit 1: '$V'" ;;
    esac
    # THE MOTIVATING CASE: three listed, one compared, one uncompared, one with no row at all.
    V="$(both_verdict_with "$BOTH_SPAN" "fa fb fc" "$BW/res.part")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "2|REFUSED: compared 1 of 3"*"fb (sandbox set empty)"*"fc (no result row"*) ok "compared < listed REFUSES at exit 2, naming the uncompared fixture with its reason AND the one the loop never reached" ;;
      *) bad "a partial comparison was not refused at exit 2 naming fb and fc: '$V'" ;;
    esac
    V="$(both_verdict_with "$BOTH_SPAN" "" "$BW/res.clean")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V" in
      "2|REFUSED: EXAMINED NOTHING -- no fixture was listed"*) ok "an empty fixture list REFUSES at exit 2 rather than reading clean over nothing" ;;
      *) bad "an empty list was not refused at exit 2: '$V'" ;;
    esac
    # MUTANTS on the span, each a cmp -s guarded copy. Each names the one arm it must move.
    both_mut() { # $1 name  $2 sed expr; leaves $BW/m.$1.sh or reports DID NOT APPLY
      sed "$2" "$BOTH_SPAN" > "$BW/m.$1.sh" 2>/dev/null || { bad "BOTH MUTANT $1: sed DID NOT APPLY"; return 1; }
      cmp -s "$BOTH_SPAN" "$BW/m.$1.sh" && { bad "BOTH MUTANT $1: the edit matched nothing"; return 1; }
      return 0
    }
    BOTH_ARMS=$((BOTH_ARMS+1))
    if both_mut gitprefix 's|$0 != ".git" && index($0, ".git/") != 1|$0 != ""|'; then
      case "$(both_compare_with "$BW/m.gitprefix.sh")" in
        "1 1|"*) bad "BOTH MUTANT gitprefix: dropping the .git prefix exclusion left the miss count at 1 — the arm does not depend on it" ;;
        *) ok "BOTH MUTANT gitprefix moves the comparison arm: without the prefix exclusion .git rows count as sandbox misses" ;;
      esac
    fi
    BOTH_ARMS=$((BOTH_ARMS+1))
    if both_mut noignore 's/ | drop_ignored$//'; then
      case "$(both_compare_with "$BW/m.noignore.sh")" in
        *build.log*) ok "BOTH MUTANT noignore moves the comparison arm: without the ignore filter an ignored path counts as a sandbox miss" ;;
        *) bad "BOTH MUTANT noignore: the ignored path still did not count — the arm does not depend on drop_ignored" ;;
      esac
    fi
    BOTH_ARMS=$((BOTH_ARMS+1))
    if both_mut direction 's|comm -23 "$out.fs.cmp" "$out.sb.cmp" > "$out.sbmiss"|comm -13 "$out.fs.cmp" "$out.sb.cmp" > "$out.sbmiss"|'; then
      case "$(both_compare_with "$BW/m.direction.sh")" in
        *"|src/miss.sh "*) bad "BOTH MUTANT direction: reversing the miss direction still named src/miss.sh — the arm reads a count, not the set" ;;
        *) ok "BOTH MUTANT direction moves the comparison arm: a reversed miss names what the SANDBOX alone saw" ;;
      esac
    fi
    BOTH_ARMS=$((BOTH_ARMS+1))
    if both_mut partial 's|if (c < n) {|if (0) {|'; then
      case "$(both_verdict_with "$BW/m.partial.sh" "fa fb fc" "$BW/res.part")" in
        2*) bad "BOTH MUTANT partial: without the compared < listed guard the partial run was still refused — the arm does not depend on it" ;;
        *) ok "BOTH MUTANT partial moves the refusal arm: without compared < listed, a run that compared one of three reads as a verdict" ;;
      esac
    fi
  fi

  # Arguments and refusals, driven through the WHOLE script in a seeded repo, as a normal user.
  # Base dies at the parse with `unknown --tracer 'both'`; the near-misses are the same refusal in
  # the other modes, which must stay at exit 1, and a fixture NAMED `both` in a --list.
  if [ "$(id -u)" = 0 ]; then
    printf '  SKIP  --tracer both refusal arms: running as root, so the not-root refusal cannot be reached\n'
  else
    BR="$WORK/bothrepo"
    mkdir -p "$BR/core/fixtures/fxa" "$BR/core/scripts" "$BR/.githooks" "$BR/src" || broken "mkdir failed"
    printf '#!/bin/bash\nfor d in core/fixtures/*/; do :; done\n' > "$BR/.githooks/pre-push"
    # fxa echoes the width knob, which the stub-world width arm below reads from its log.
    printf '#!/bin/bash\necho "width=${VAS_INNER_POOL_WIDTH:-unset}"\necho "ems=${EMS_POOL_WIDTH:-unset}"\ncat src/a.sh >/dev/null\necho fxa ok\n' > "$BR/core/fixtures/fxa/run.sh"
    printf 'a\n' > "$BR/src/a.sh"; printf 'o\n' > "$BR/src/other.sh"
    # PRESENT names the pseudo-path arm below must keep: one whose angle pair does not span its last
    # component, and one that IS a whole `<...>` component but exists in the tree.
    mkdir -p "$BR/d" || broken "mkdir failed"
    printf 'x\n' > "$BR/a<b>c"; printf 'x\n' > "$BR/d/<real>"
    # A PRESENT file whose name leads with `-`: the option-shaped arm must keep it, as it keeps d/<real>.
    printf 'x\n' > "$BR/d/-p"
    # A DANGLING symlink with a whole `<...>` name: present by `-L`, absent by `-e`, so it is kept
    # only by a filter that tests both. Tracked, so readset_copy_tree carries it as a symlink.
    ln -s nowhere-at-all "$BR/<link>" || broken "could not seed the dangling symlink"
    printf '*.log\n' > "$BR/.gitignore"
    printf 'other\tsrc/other.sh\nother\tcore/fixtures/other/run.sh\n' > "$BR/.ai-dlc-fixture-readsets.tsv"
    cp "$DERIVER" "$BR/core/scripts/derive-fixture-readsets.sh"
    ( cd "$BR" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 \
      || broken "could not seed the --tracer both repo"
    drive_in() { # $1 dir; rest = args. prints "<rc>|<first ERROR line>"
      local d="$1" r; shift
      ( cd "$d" && bash core/scripts/derive-fixture-readsets.sh "$@" ) > "$WORK/br.out" 2>&1; r=$?
      printf '%s|%s' "$r" "$(grep -m1 'ERROR' "$WORK/br.out")"
    }
    V1="$(drive_in "$BR" --all --tracer both)"
    V2="$(drive_in "$BR" --all --tracer=both)"
    V3="$(drive_in "$BR" --all --tracer fs_usage)"
    V4="$(drive_in "$BR" --list both --tracer fs_usage)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V1" in
      "2|ERROR: must run as root"*"--tracer both"*) ok "--all --tracer both PARSES and refuses a normal user at exit 2, naming the sudo command" ;;
      *) bad "--all --tracer both without root did not refuse at exit 2 for root: '$V1'" ;;
    esac
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V2|$V3|$V4" in
      "2|ERROR: must run as root"*"|1|ERROR: must run as root"*"|1|ERROR: must run as root"*) ok "  --tracer=both refuses at 2 too, and the same refusal stays at exit 1 in fs_usage mode — including for a fixture NAMED 'both'" ;;
      *) bad "the refusal exit codes do not separate both-mode from the others: '=both' $V2 / fs_usage $V3 / --list both $V4" ;;
    esac
    # A REPEATED --tracer: the parser keeps the LAST value, so the refusal code must follow the
    # last one too. Both orders, so a pre-scan that latches on any `both` and one that ignores
    # `both` entirely each fail one half.
    V5="$(drive_in "$BR" --all --tracer both --tracer fs_usage)"
    V6="$(drive_in "$BR" --all --tracer fs_usage --tracer both)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$V5|$V6" in
      "1|ERROR: must run as root"*"--tracer fs_usage"*"|2|ERROR: must run as root"*"--tracer both"*) ok "  a repeated --tracer refuses at the LAST value's code: 'both then fs_usage' at 1, 'fs_usage then both' at 2" ;;
      *) bad "a repeated --tracer did not refuse at the last value's exit code: both,fs_usage $V5 / fs_usage,both $V6" ;;
    esac
    # A LINKED WORKTREE dies before the arguments are parsed, so it is the case the raw pre-scan
    # exists for: 2 under both, still 1 otherwise.
    ( cd "$BR" && git worktree add -q "$WORK/bothwt" -b bothwt ) >/dev/null 2>&1 || broken "could not add a linked worktree to the --tracer both repo"
    W1="$(drive_in "$WORK/bothwt" --all --tracer both)"
    W2="$(drive_in "$WORK/bothwt" --all --tracer fs_usage)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$W1|$W2" in
      "2|ERROR:"*"LINKED worktree"*"|1|ERROR:"*"LINKED worktree"*) ok "a LINKED worktree refuses --tracer both at exit 2 before any parse, and the same refusal stays at 1 in fs_usage mode" ;;
      *) bad "a linked worktree did not refuse at 2 under both / 1 otherwise: both $W1 / fs_usage $W2" ;;
    esac

    # THE NO-WRITE GUARANTEE, DRIVEN THROUGH THE WHOLE SCRIPT. Stubs stand in for every privileged
    # or kernel-backed tool; `/usr/bin/log` is called by absolute path and cannot be PATH-stubbed,
    # so a COPY of the deriver has its one LOG_BIN line pointed at a stub. The stub fs_usage sees
    # five paths and the stub sandbox two, so the real loop must report exactly 1 sandbox miss.
    # The seeded map carries a SECOND fixture's rows so that, with the guard deleted, the script
    # passes every control and reaches the write -- the md5 arm is then about the guard, not about
    # a control that happened to stop the run first.
    SB="$WORK/bothstub"; mkdir -p "$SB" || broken "mkdir failed"
    BOTH_TR="$(cd "$WORK" && pwd -P)/both.tr"
    cat > "$SB/id" <<'STUB'
#!/bin/bash
[ "$#" -eq 1 ] && [ "$1" = -u ] && { echo 0; exit 0; }
exec /usr/bin/id "$@"
STUB
    # The stub sudo models env_reset for the one variable that matters here: a VAS_INNER_POOL_WIDTH
    # exported or prefixed in FRONT of sudo does not reach the command it runs.
    cat > "$SB/sudo" <<'STUB'
#!/bin/bash
while [ "$#" -gt 0 ]; do case "$1" in -n) shift ;; -u) shift 2 ;; *) break ;; esac; done
exec env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH "$@"
STUB
    cat > "$SB/sandbox-exec" <<'STUB'
#!/bin/bash
[ "$1" = -f ] && shift 2
# The deriver launches a fixture as `env VAS_INNER_POOL_WIDTH=1 bash <run.sh>`; look past that.
_c=1; [ "$1" = env ] && { _c=2; for _w in "${@:2}"; do case "$_w" in *=*) _c=$((_c+1)) ;; *) break ;; esac; done; }
if [ "${!_c}" = bash ]; then
  while IFS= read -r p; do [ -n "$p" ] && printf 'x Sandbox: bash(1) allow file-read-data %s/%s\n' "$PWD" "$p"; done < "$STUB_SB" >> "$STUB_FEED"
else
  for a in "$@"; do case "$a" in /*) printf 'x Sandbox: cat(1) allow file-read-data %s\n' "$a" >> "$STUB_FEED" ;; esac; done
fi
exec "$@"
STUB
    cat > "$SB/fs_usage" <<'STUB'
#!/bin/bash
# Exits on its own once nobody reads it: `git push` runs hooks with SIGPIPE ignored, and the
# deriver kills grep (the pipeline's last element), not this.
emit() { printf '%s\n' "$1" || exit 0; }
emit "00:00:00  open  F=3  (R_____)  $STUB_ROOT/m/.readset-sentinel  0.000010  cat.1"
while IFS= read -r p; do [ -n "$p" ] && emit "00:00:00  open  F=3  (R_____)  $STUB_ROOT/t/$p  0.000010  bash.2"; done < "$STUB_FS"
n=0; while [ "$n" -lt 300 ]; do sleep 0.2; emit heartbeat; n=$((n+1)); done
STUB
    cat > "$SB/logstream" <<'STUB'
#!/bin/bash
exec tail -n 0 -f "$STUB_FEED"
STUB
    chmod +x "$SB/id" "$SB/sudo" "$SB/sandbox-exec" "$SB/fs_usage" "$SB/logstream"
    : > "$SB/feed"
    # The eleven PSEUDO seeds go into BOTH lists, so they cancel in the miss count and every tracer's
    # set carries them to the one call site where the sets meet (the pseudo-path arm below).
    PSEUDO_SEEDS='<string>
sub/<unknown>
src/missing.sh
a<b>c
d/<real>
e<f>g.sh
<link>
x/y/<z>
<>
q/-x
d/-p'
    { printf '%s\n' core/fixtures/fxa/run.sh src/a.sh src/miss.sh .git/HEAD build.log; printf '%s\n' "$PSEUDO_SEEDS"; } > "$SB/fs.list"
    { printf '%s\n' core/fixtures/fxa/run.sh src/a.sh; printf '%s\n' "$PSEUDO_SEEDS"; } > "$SB/sb.list"
    : > "$SB/empty.list"
    STUB_DERIVER="$BR/core/scripts/derive-fixture-readsets.sh"
    sed "s|^LOG_BIN=/usr/bin/log\$|LOG_BIN=\"$SB/logstream\"|" "$DERIVER" > "$SB/deriver.sh"
    cmp -s "$DERIVER" "$SB/deriver.sh" && broken "the LOG_BIN line is gone from $DERIVER, so the stub world cannot point the stream at a stub"
    sed '/^  exit "\$BOTH_RC"$/d' "$SB/deriver.sh" > "$SB/deriver.nowrite.sh"
    cmp -s "$SB/deriver.sh" "$SB/deriver.nowrite.sh" && broken "the both-mode exit line is gone, so the no-write mutant cannot be built"
    sum_of() { md5 -q "$1" 2>/dev/null || cksum < "$1"; }
    stub_run() { # $1 deriver copy  $2 sandbox path list; prints "<rc>|<verdict line>|<fxa line>|<map moved?>"
      local before after r
      cp "$1" "$STUB_DERIVER"
      before="$(sum_of "$BR/.ai-dlc-fixture-readsets.tsv")"
      ( cd "$BR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SB:$PATH" SUDO_USER="$(id -un)" STUB_ROOT="$BOTH_TR" STUB_FEED="$SB/feed" \
          STUB_FS="$SB/fs.list" STUB_SB="$2" AI_DLC_READSET_TRACE_ROOT="$BOTH_TR" \
          bash core/scripts/derive-fixture-readsets.sh --list fxa --tracer both ) > "$WORK/stub.out" 2>&1 </dev/null
      r=$?
      after="$(sum_of "$BR/.ai-dlc-fixture-readsets.tsv")"
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s|%s' "$r" "$(grep -m1 -E '^(SANDBOX-MISSES|REFUSED)' "$WORK/stub.out")" \
        "$(grep -m1 -E '^  fxa ' "$WORK/stub.out" | tr -s ' ')" "$([ "$before" = "$after" ] && echo same || echo MOVED)"
    }
    S1="$(stub_run "$SB/deriver.sh" "$SB/sb.list")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$S1" in
      "1|SANDBOX-MISSES 1 path(s) across 1 fixture(s)"*"| fxa sandbox-missed 1 fs_usage-missed 0|same")
        ok "a full stub-world --tracer both run reports 'fxa sandbox-missed 1 fs_usage-missed 0', reads SANDBOX-MISSES at exit 1, and leaves the map's md5 unchanged" ;;
      *) bad "the stub-world --tracer both run did not read exactly one miss with the map unchanged: '$S1' — $(tail -3 "$WORK/stub.out" | tr '\n' ' ')" ;;
    esac
    # S1's own fxa log, captured NOW: the pseudo mutants below each re-run the stub world, and the
    # width arm further down must read the UNMUTATED run, not whichever mutant ran last.
    S1_LOG="$WORK/s1.fxa.log"; cp "$BOTH_TR/w/fxa.log" "$S1_LOG" 2>/dev/null || : > "$S1_LOG"
    # THE PSEUDO-PATH FILTER, read off the set the S1 run just wrote, where all three tracers' sets
    # meet. Nine seeds, in seed order: `<string>` and `sub/<unknown>` (absent, last component a whole
    # `<...>` token) must be DROPPED; `src/missing.sh` (absent, ordinary), `a<b>c` and `d/<real>`
    # (present), `e<f>g.sh` (absent, brackets inside the component) and `<link>` (a dangling
    # symlink) must be KEPT; `x/y/<z>` (absent, two directories deep) and `<>` (absent, empty
    # token) must be DROPPED. Each of the last four separates the fix from one wrong filter:
    # `e<f>g.sh` from an unanchored `<[^/]*>`, `<link>` from `-e` without `-L`, `x/y/<z>` from a
    # first-component strip `${p#*/}`, and `<>` from a non-empty token `'<'?*'>'`. Then the
    # option-shaped pair: `q/-x` (absent, last component leads with `-`, the shape of a grep option
    # read as an operand) must be DROPPED, and `d/-p` (present, same shape) must be KEPT.
    # Presence-shaped: six rows must APPEAR, so a run that wrote no set cannot score.
    pseudo_sig() { # prints one 0/1 per seed: is it in the last stub run's fxa.set
      local s out=""
      while IFS= read -r s; do
        if grep -qxF -- "$s" "$BOTH_TR/w/fxa.set" 2>/dev/null; then out="${out}1"; else out="${out}0"; fi
      done <<< "$PSEUDO_SEEDS"
      printf '%s' "$out"
    }
    PS0="$(pseudo_sig)"
    BOTH_ARMS=$((BOTH_ARMS+1))
    if [ "$PS0" = 00111110001 ]; then
      ok "PSEUDO: the merged set drops '<string>' and 'sub/<unknown>' (absent whole-<...> last component) and keeps src/missing.sh, a<b>c, d/<real>, e<f>g.sh and the dangling <link>; x/y/<z> and <> go too; absent option-shaped q/-x goes and present d/-p stays"
    else
      bad "PSEUDO: expected seed signature 00111110001 in fxa.set, got '$PS0' (order: <string> sub/<unknown> src/missing.sh a<b>c d/<real> e<f>g.sh <link> x/y/<z> <> q/-x d/-p) — $(tail -2 "$WORK/stub.out" | tr '\n' ' ')"
    fi
    # TEN MUTANTS, each a cmp -s guarded copy of the stub-world deriver, each a wrong filter:
    #   nofilter   the call removed from the meeting point;
    #   wholepath  the anchor on the whole path, `^<...>$`, so `sub/<unknown>` survives;
    #   unanch     an unanchored `<[^/]*>` inside the last component, so absent `e<f>g.sh` goes too;
    #   existonly  the existence test with no shape test, so absent `src/missing.sh` goes too;
    #   sbonly     the filter on the sandbox set only, so the fs_usage set carries the pseudo rows back.
    sed 's/ | readset_drop_pseudo | drop_ignored > / | drop_ignored > /' "$SB/deriver.sh" > "$SB/deriver.p.nofilter.sh"
    sed 's/^    case "\${p##\*\/}" in$/    case "$p" in/' "$SB/deriver.sh" > "$SB/deriver.p.wholepath.sh"
    sed "s/^      '<'\*'>') if /      *'<'*'>'*) if /" "$SB/deriver.sh" > "$SB/deriver.p.unanch.sh"
    sed "s/^      '<'\*'>') if /      *) if /" "$SB/deriver.sh" > "$SB/deriver.p.existonly.sh"
    sed -e 's/ | readset_drop_pseudo | drop_ignored > / | drop_ignored > /' \
        -e 's/^    sandbox_paths < "\$WORK\/\$fx.win" | grep -v /    sandbox_paths < "$WORK\/$fx.win" | readset_drop_pseudo | grep -v /' \
        "$SB/deriver.sh" > "$SB/deriver.p.sbonly.sh"
    #   eonly      `-e` without `-L`, so the dangling `<link>` goes;
    #   firststrip `${p#*/}` strips only the FIRST component, so `x/y/<z>` survives;
    #   nonempty   `'<'?*'>'`, so the empty token `<>` survives;
    #   dashgone   the `-*` arm deleted, so the absent option-shaped `q/-x` survives;
    #   dashany    the `-*` arm dropping with no existence test, so the present `d/-p` goes too.
    # eonly is ADDRESSED to the `'<'*'>') if ` line: the `-*` arm carries the identical existence
    # test, and an unaddressed edit would rewrite both arms and score a kill on two subjects.
    sed "/^      '<'\*'>') if /s/if \[ -e \"\$TREE\/\$p\" \] || \[ -L \"\$TREE\/\$p\" \]; then/if [ -e \"\$TREE\/\$p\" ]; then/" "$SB/deriver.sh" > "$SB/deriver.p.eonly.sh"
    sed 's/^    case "\${p##\*\/}" in$/    case "${p#*\/}" in/' "$SB/deriver.sh" > "$SB/deriver.p.firststrip.sh"
    sed "s/^      '<'\*'>') if /      '<'?*'>') if /" "$SB/deriver.sh" > "$SB/deriver.p.nonempty.sh"
    sed '/^      -\*) if /d' "$SB/deriver.sh" > "$SB/deriver.p.dashgone.sh"
    sed 's/^      -\*) if .*$/      -*) ;;/' "$SB/deriver.sh" > "$SB/deriver.p.dashany.sh"
    for _pm in nofilter wholepath unanch existonly sbonly eonly firststrip nonempty dashgone dashany; do
      BOTH_ARMS=$((BOTH_ARMS+1))
      if cmp -s "$SB/deriver.sh" "$SB/deriver.p.$_pm.sh"; then
        bad "PSEUDO MUTANT $_pm did not apply: the edit matched nothing in the deriver copy"
        continue
      fi
      stub_run "$SB/deriver.p.$_pm.sh" "$SB/sb.list" >/dev/null
      _ps="$(pseudo_sig)"
      case "$_ps" in
        00111110001) bad "PSEUDO MUTANT $_pm: the set still reads 00111110001, so the pseudo arm does not depend on what this mutant removed" ;;
        *1*) ok "PSEUDO MUTANT $_pm: the set reads '$_ps', not 00111110001 — the pseudo arm refuses it" ;;
        *) bad "PSEUDO MUTANT $_pm: the set carries none of the seeds ('$_ps'), so the run wrote no set and scored nothing — $(tail -2 "$WORK/stub.out" | tr '\n' ' ')" ;;
      esac
      # With no filter at all the absent option-shaped seed must reach the set: otherwise its drop
      # in the unmutated run came from somewhere other than the `-*` arm, and the arm is unproven.
      if [ "$_pm" = nofilter ]; then
        BOTH_ARMS=$((BOTH_ARMS+1))
        case "$_ps" in
          ?????????1?) ok "PSEUDO MUTANT nofilter: the absent option-shaped q/-x reaches fxa.set ('$_ps'), so its drop in the unmutated run is the filter's" ;;
          *) bad "PSEUDO MUTANT nofilter: the absent q/-x did not reach fxa.set even with the filter removed ('$_ps'), so the -* arm's drop is not proven to be its own" ;;
        esac
      fi
    done
    # THE WIDTH KNOB UNDER `--tracer both`. This path runs the fixture through `sudo -n -u ...
    # sandbox-exec`, and the stub sudo strips VAS_INNER_POOL_WIDTH the way env_reset does, so only an
    # `env KNOB=1` placed AFTER sudo reaches the fixture. The log is read straight after each run,
    # before the next run clears the trace root. Presence-shaped: `fxa ok` must appear too.
    # EMS_POOL_WIDTH rides the same `env` and is read the same way, as a second field.
    stub_width() { # prints "<width line>|<ems line>|<fxa ok count>" from $1, default the last stub run's fxa log
      local l="${1:-$BOTH_TR/w/fxa.log}"
      printf '%s|%s|%s' "$(grep -m1 '^width=' "$l" 2>/dev/null)" "$(grep -m1 '^ems=' "$l" 2>/dev/null)" \
        "$(grep -cx 'fxa ok' "$l" 2>/dev/null || :)"
    }
    SW0="$(stub_width "$S1_LOG")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$SW0" in
      "width=1|ems=1|1") ok "WIDTH under --tracer both: the stub-world run of fxa, launched through sudo's env_reset, logs width=1 and ems=1" ;;
      *) bad "WIDTH under --tracer both: fxa's log did not read width=1 and ems=1 with 'fxa ok' present: '$SW0' — a knob does not survive the sudo launch" ;;
    esac
    # THREE MUTANT DERIVERS, each a cmp -s guarded copy of the stub-world deriver, each a wrong
    # fix that the --tracer sandbox width arm above cannot see because no sudo sits on that path:
    #   m2      the injection moved in FRONT of sudo: into both branches of sandboxed(), ahead of
    #           `sudo -n -u` and ahead of the bare `sandbox-exec`, and ahead of sudo on the fs_usage
    #           line, so --tracer sandbox still reads width=1;
    #   m4      the `sandboxed` launch dropping the knob under `--tracer both` only;
    #   prefix  `VAS_INNER_POOL_WIDTH=1 sandboxed ...`, a prefix in front of the function.
    # Each must log width=unset and ems=unset with `fxa ok` present: both knobs move together.
    sed -e 's|sudo -n -u "$RUN_AS" sandbox-exec -f "$PROFILE" "$@"|env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 sudo -n -u "$RUN_AS" sandbox-exec -f "$PROFILE" "$@"|' \
        -e 's|^    sandbox-exec -f "$PROFILE" "$@"$|    env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 sandbox-exec -f "$PROFILE" "$@"|' \
        -e 's|sudo -n -u "$RUN_AS" env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash |env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 sudo -n -u "$RUN_AS" bash |' \
        -e 's|sandboxed env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash |sandboxed bash |' "$SB/deriver.sh" > "$SB/deriver.m2.sh"
    sed 's|( cd "$TREE" \&\& sandboxed env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash "$FIXTURE_ROOT/$fx/run.sh" )|( cd "$TREE" \&\& if [ "$TRACER" = both ]; then sandboxed bash "$FIXTURE_ROOT/$fx/run.sh"; else sandboxed env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash "$FIXTURE_ROOT/$fx/run.sh"; fi )|' \
      "$SB/deriver.sh" > "$SB/deriver.m4.sh"
    sed 's|sandboxed env VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash |VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 sandboxed bash |' "$SB/deriver.sh" > "$SB/deriver.prefix.sh"
    for _wm in m2 m4 prefix; do
      BOTH_ARMS=$((BOTH_ARMS+1))
      if cmp -s "$SB/deriver.sh" "$SB/deriver.$_wm.sh"; then
        bad "BOTH WIDTH MUTANT $_wm did not apply: the edit matched nothing in the deriver copy"
        continue
      fi
      stub_run "$SB/deriver.$_wm.sh" "$SB/sb.list" >/dev/null
      _sw="$(stub_width)"
      case "$_sw" in
        "width=unset|ems=unset|1") ok "BOTH WIDTH MUTANT $_wm: the stub-world run logs width=unset and ems=unset with 'fxa ok' present — the --tracer both width arm refuses it" ;;
        *) bad "BOTH WIDTH MUTANT $_wm: expected width=unset and ems=unset with 'fxa ok' present, got '$_sw' — $(tail -2 "$WORK/stub.out" | tr '\n' ' ')" ;;
      esac
    done
    S2="$(stub_run "$SB/deriver.sh" "$SB/empty.list")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$S2" in
      "2|REFUSED: compared 0 of 1"*"fxa ("*"sandbox set empty)"*"|same") ok "  and a sandbox that reported nothing for the fixture — how an unseen sudo -u child would look — is REFUSED at exit 2, not compared" ;;
      *) bad "an empty sandbox set was not refused at exit 2 naming fxa: '$S2'" ;;
    esac
    # THE LOSS CANARY UNDER `--tracer both`. The same empty-stream run: fxa really read run.sh and
    # src/a.sh, the stream reported neither, so its reason must also carry `LOSS CANARY: 2 path(s)`
    # -- a read both tracers lost would otherwise be invisible to the fs_usage comparison. The
    # mutant scopes the canary back to `--tracer sandbox` and must lose the token.
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$S2" in
      *"fxa (LOSS CANARY: 2 path(s)"*) ok "CANARY under --tracer both: the empty-stream run's UNCOMPARED reason names 'LOSS CANARY: 2 path(s)'" ;;
      *) bad "CANARY under --tracer both: the empty-stream run's reason does not name 'LOSS CANARY: 2 path(s)': '$S2'" ;;
    esac
    sed 's/^  if \[ "\$TRACER" != fs_usage \]; then$/  if [ "$TRACER" = sandbox ]; then/' "$SB/deriver.sh" > "$SB/deriver.cboth.sh"
    BOTH_ARMS=$((BOTH_ARMS+1))
    if cmp -s "$SB/deriver.sh" "$SB/deriver.cboth.sh"; then
      bad "CANARY BOTH MUTANT did not apply: scoping the canary to --tracer sandbox changed nothing"
    else
      S2M="$(stub_run "$SB/deriver.cboth.sh" "$SB/empty.list")"
      case "$S2M" in
        *"LOSS CANARY"*) bad "CANARY BOTH MUTANT: scoped to --tracer sandbox, the --tracer both run still names the canary: '$S2M'" ;;
        "2|REFUSED: compared 0 of 1"*"fxa (sandbox set empty)"*) ok "CANARY BOTH MUTANT: scoped to --tracer sandbox, the --tracer both run is refused for the empty set alone, with no canary — the arm above depends on the scope" ;;
        *) bad "CANARY BOTH MUTANT: the scoped-back run did not read a plain empty-set refusal: '$S2M'" ;;
      esac
    fi
    S3="$(stub_run "$SB/deriver.nowrite.sh" "$SB/sb.list")"
    BOTH_ARMS=$((BOTH_ARMS+1))
    case "$S3" in
      *"|MOVED") ok "NOWRITE MUTANT: with the both-mode exit deleted the same run WRITES the map (md5 moved) — that exit is the guard the arm above depends on" ;;
      *) bad "NOWRITE MUTANT: the map did not move with the exit deleted, so the no-write arm proves nothing about it: '$S3' — $(tail -3 "$WORK/stub.out" | tr '\n' ' ')" ;;
    esac

    # THE LOSS CANARY, DETERMINISTICALLY, UNDER `--tracer sandbox`. The real-stream probe further
    # down needs `log stream` and skips where it cannot run; this arm needs neither, so the canary
    # is proven on every non-root run of this fixture and is never a check that cannot fire. The
    # stub sandbox-exec reports ONLY the paths in the list it is handed, while fxa really reads
    # run.sh and src/a.sh, so the atime leg sees both:
    #   lossy list  run.sh alone      -> fxa OMITTED naming `LOSS CANARY: 1 path(s)`, 0 drop notices;
    #   whole list  run.sh + src/a.sh -> fxa MAPPED;
    #   mutant      the canary guard deleted, lossy list -> fxa MAPPED, so the arm depends on it.
    # Its own PATH dir carries ONLY the sandbox-exec stub: the `id` stub above answers uid 0, which
    # `--tracer sandbox` refuses.
    SX="$WORK/sbxstub"; mkdir -p "$SX" || broken "mkdir failed"
    cp "$SB/sandbox-exec" "$SX/sandbox-exec" || broken "could not copy the sandbox-exec stub"
    printf '%s\n' core/fixtures/fxa/run.sh > "$SX/lossy.list"
    printf '%s\n' core/fixtures/fxa/run.sh src/a.sh > "$SX/whole.list"
    : > "$SX/feed"
    SX_TR="$(cd "$WORK" && pwd -P)/sbx.tr"
    sbx_run() { # $1 deriver copy  $2 stream list; prints "<fxa line>|<drop notices>"
      local d
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$2" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" bash core/scripts/derive-fixture-readsets.sh --list fxa --tracer sandbox ) > "$WORK/sbx.out" 2>&1 </dev/null
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      d="$(grep -c 'dropped during' "$SX_TR/w/fxa.win" 2>/dev/null)" || d=0
      printf '%s|%s' "$(grep -m1 -E '^  fxa ' "$WORK/sbx.out" | tr -s ' ')" "$d"
    }
    sed '/^  \[ "\$canary" = 0 \]    || why=/d' "$SB/deriver.sh" > "$SX/deriver.nocanary.sh"
    CL="$(sbx_run "$SB/deriver.sh" "$SX/lossy.list")"
    CW="$(sbx_run "$SB/deriver.sh" "$SX/whole.list")"
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$CL" in
      " fxa OMITTED ("*"LOSS CANARY: 1 path(s)"*"|0") ok "CANARY: a sandbox-tracer window that lost a read with NO drop notice OMITS the fixture, naming 'LOSS CANARY: 1 path(s)'" ;;
      *) bad "CANARY: the lossy stub window was not omitted naming 'LOSS CANARY: 1 path(s)' with 0 drop notices: '$CL' — $(tail -2 "$WORK/sbx.out" | tr '\n' ' ')" ;;
    esac
    TRACE_ARMS=$((TRACE_ARMS+1))
    case "$CW" in
      " fxa "*" paths|0") ok "CANARY CONTROL: the same run with the stream reporting every read MAPS fxa — the canary does not fire on a whole window" ;;
      *) bad "CANARY CONTROL: the whole stub window did not map fxa: '$CW' — atime extras: $(LC_ALL=C comm -23 "$SX_TR/w/fxa.at" "$SX_TR/w/fxa.fs" 2>/dev/null | tr '\n' ' ')" ;;
    esac
    TRACE_ARMS=$((TRACE_ARMS+1))
    if cmp -s "$SB/deriver.sh" "$SX/deriver.nocanary.sh"; then
      bad "CANARY MUTANT did not apply: deleting the canary guard changed nothing in the deriver copy"
    else
      CM="$(sbx_run "$SX/deriver.nocanary.sh" "$SX/lossy.list")"
      case "$CM" in
        " fxa "*" paths|0") ok "CANARY MUTANT: with the guard deleted the lossy window MAPS fxa — the canary arm depends on that line" ;;
        *) bad "CANARY MUTANT: with the guard deleted the lossy window did not map fxa: '$CM' — $(tail -2 "$WORK/sbx.out" | tr '\n' ' ')" ;;
      esac
    fi

    # THE CANARY'S UNREADABLE BRANCH, driven from its sentinels. No real trace produces an
    # unreadable stream set on demand, so the shipped readset_loss_canary is called on a missing
    # $fx.fs: it must print `unreadable`, and the deriver's guard must turn that into an OMITTED
    # reason. Two wrong builds each fail this arm and only this arm:
    #   C1  `unreadable` replaced by `0`, the fail-open direction;
    #   C2  comm's status discarded (`; then` -> `|| :; then`), so the empty output counts 0.
    CAN_SPAN="$WORK/canary.sh"
    sed -n '/^# READSET_CANARY_BEGIN$/,/^# READSET_CANARY_END$/p' "$DERIVER" > "$CAN_SPAN"
    printf 'a\nb\n' > "$WORK/can.at"
    can_with() { ( . "$1"; readset_loss_canary "$WORK/can.at" "$WORK/can.no-such-fs" "$WORK/can.out" ) 2>/dev/null; }
    can_why() { # $1 canary value; runs the deriver's own guard line on it
      local canary="$1" why="" fx=fxa WORK="$WORK" g
      g="$(grep -m1 '^  \[ "\$canary" = 0 \]    || why=' "$DERIVER")"
      eval "$g"; printf '%s' "$why"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    CU="$(can_with "$CAN_SPAN")"; CUW="$(can_why "$CU")"
    if [ "$CU" = unreadable ] && case "$CUW" in "LOSS CANARY: unreadable path(s)"*) true ;; *) false ;; esac; then
      ok "CANARY UNREADABLE: a missing stream set makes readset_loss_canary print 'unreadable', and the deriver's guard omits the fixture for it"
    else
      bad "CANARY UNREADABLE: expected 'unreadable' and an omission reason, got '$CU' / '$CUW' (span lines: $(grep -c . "$CAN_SPAN"))"
    fi
    sed 's/^    printf .unreadable\\n.$/    printf '"'"'0\\n'"'"'/' "$CAN_SPAN" > "$WORK/canary.c1.sh"
    sed 's/^  if LC_ALL=C comm -23 "\$1" "\$2" > "\$3" 2>\/dev\/null; then$/  if LC_ALL=C comm -23 "$1" "$2" > "$3" 2>\/dev\/null || :; then/' "$CAN_SPAN" > "$WORK/canary.c2.sh"
    for _cm in c1 c2; do
      TRACE_ARMS=$((TRACE_ARMS+1))
      if cmp -s "$CAN_SPAN" "$WORK/canary.$_cm.sh"; then bad "CANARY MUTANT $_cm did not apply"; continue; fi
      _cv="$(can_with "$WORK/canary.$_cm.sh")"
      case "$_cv" in
        0) ok "CANARY MUTANT $_cm: a missing stream set reads '0', which maps the fixture — the unreadable arm refuses it" ;;
        *) bad "CANARY MUTANT $_cm: expected the fail-open '0', got '$_cv'" ;;
      esac
    done

    # A ONE-FIXTURE `--list` WHOSE FIXTURE IS OMITTED STILL WRITES THE MAP, DROPPING ITS STALE ROWS.
    # Seed a stale `fxa` row the trace can never produce, trace fxa with a lossy stream (the canary
    # omits it), and read the map: the stale row must be GONE, `other`'s rows kept, and the header
    # must name fxa as OMITTED. The mutant restores the traced-count control under --list and must
    # leave the stale row in place (the run dies before the write).
    printf 'other\tsrc/other.sh\nother\tcore/fixtures/other/run.sh\nthird\tcore/fixtures/third/run.sh\nfxa\tsrc/STALE-ROW\n' > "$BR/.ai-dlc-fixture-readsets.tsv"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm stale ) >/dev/null 2>&1 || broken "could not seed the stale map row"
    omit_run() { # $1 deriver copy; prints "<stale rows>|<other rows>|<OMITTED header rows>"
      local s o h
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/lossy.list" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" bash core/scripts/derive-fixture-readsets.sh --list fxa --tracer sandbox ) > "$WORK/omit.out" 2>&1 </dev/null
      s="$(grep -c 'STALE-ROW' "$BR/.ai-dlc-fixture-readsets.tsv")" || s=0
      o="$(grep -c '^other	' "$BR/.ai-dlc-fixture-readsets.tsv")" || o=0
      h="$(grep -c '^# OMITTED by the last run (always run): fxa$' "$BR/.ai-dlc-fixture-readsets.tsv")" || h=0
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s' "$s" "$o" "$h"
    }
    sed 's/^if \[ "\$MODE" != --list \]; then$/if true; then/' "$SB/deriver.sh" > "$SX/deriver.mappedctl.sh"
    TRACE_ARMS=$((TRACE_ARMS+1))
    OR="$(omit_run "$SB/deriver.sh")"
    if [ "$OR" = "0|2|1" ]; then
      ok "OMITTED --list: a one-fixture refresh whose fixture is omitted writes the map, drops its stale row, keeps the other fixture's rows and names it OMITTED"
    else
      bad "OMITTED --list: expected stale 0, other 2, OMITTED header 1, got '$OR' — $(tail -2 "$WORK/omit.out" | tr '\n' ' ')"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    if cmp -s "$SB/deriver.sh" "$SX/deriver.mappedctl.sh"; then
      bad "OMITTED --list MUTANT did not apply"
    else
      OM="$(omit_run "$SX/deriver.mappedctl.sh")"
      case "$OM" in
        "1|2|0") ok "OMITTED --list MUTANT: with the traced-count control restored under --list the run dies unwritten and the stale row survives — the arm depends on that change" ;;
        *) bad "OMITTED --list MUTANT: expected stale 1, other 2, header 0, got '$OM'" ;;
      esac
    fi

    # `--all` WITH ONE FIXTURE OMITTED, END TO END. The function arms above drive the extracted spans;
    # this drives the whole deriver the way the operator runs it. The stale-row map above is still
    # committed, and a `plan-shape` fixture reading its own subject is seeded beside fxa, so the
    # world has TWO fixture directories -- with one, the base newline list has no newline and base
    # does not die. The stub sandbox-exec reports ONE stream list for every launch, so each world is
    # a union list:
    #   world O  {fxa/run.sh, plan-shape/run.sh, validate-plan-shape.sh}: fxa's src/a.sh read is
    #            unreported, so the canary omits fxa and plan-shape maps. The fix writes the map with
    #            the OMITTED header naming fxa and prints the plan-shape PRESENCE line; base dies
    #            "merge dropped 'fxa'" and never reaches the plan-shape pair.
    #   world S  {fxa/run.sh, src/a.sh, plan-shape/run.sh}: plan-shape is the omitted one, fxa maps
    #            (with both omitted, `--all` dies "zero fixtures mapped"). The fix prints the SKIP
    #            line and writes the map naming plan-shape OMITTED.
    #            A MAPPED `plan-shape-x` sibling sits in both worlds: its rows begin with the string
    #            `plan-shape`, so a D1 guard that greps `^plan-shape` without the tab reads them as
    #            plan-shape's own and runs the pair on an omitted plan-shape. Without the sibling
    #            that mutant passed every arm.
    mkdir -p "$BR/core/fixtures/plan-shape" "$BR/core/fixtures/plan-shape-x" "$BR/scripts" || broken "mkdir failed"
    printf '#!/bin/bash\ncat scripts/validate-plan-shape.sh >/dev/null\n' > "$BR/core/fixtures/plan-shape/run.sh"
    printf '#!/bin/bash\nexit 0\n' > "$BR/core/fixtures/plan-shape-x/run.sh"
    printf '#!/bin/bash\nexit 0\n' > "$BR/scripts/validate-plan-shape.sh"
    printf '%s\n' core/fixtures/fxa/run.sh core/fixtures/plan-shape/run.sh core/fixtures/plan-shape-x/run.sh scripts/validate-plan-shape.sh > "$SX/allO.list"
    printf '%s\n' core/fixtures/fxa/run.sh src/a.sh core/fixtures/plan-shape/run.sh core/fixtures/plan-shape-x/run.sh > "$SX/allS.list"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm plan-shape ) >/dev/null 2>&1 || broken "could not seed the plan-shape fixture"
    [ "$(find "$BR/core/fixtures" -mindepth 2 -maxdepth 2 -name run.sh | grep -c .)" -ge 2 ] \
      || broken "the --all world holds fewer than two fixture directories, so the base newline list cannot carry a newline and the arm cannot discriminate"
    all_run() { # $1 deriver copy  $2 stream list  $3 header name; prints "<rc>|<header rows>|<presence>|<skip>|<merge dropped>"
      local r h p k m
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$2" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" bash core/scripts/derive-fixture-readsets.sh --all --tracer sandbox ) > "$WORK/all.out" 2>&1 </dev/null
      r=$?
      h="$(grep -cx "# OMITTED by the last run (always run): $3" "$BR/.ai-dlc-fixture-readsets.tsv")" || h=0
      p="$(grep -c "^  PASS  plan-shape's read-set names its own subject" "$WORK/all.out")" || p=0
      k="$(grep -cxF '  SKIP  plan-shape controls: plan-shape OMITTED this run' "$WORK/all.out")" || k=0
      m="$(grep -c "merge dropped 'fxa'" "$WORK/all.out")" || m=0
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      printf '%s|%s|%s|%s|%s' "$r" "$h" "$p" "$k" "$m"
    }
    TRACE_ARMS=$((TRACE_ARMS+1))
    AO="$(all_run "$SB/deriver.sh" "$SX/allO.list" fxa)"
    if [ "$AO" = "0|1|1|0|0" ]; then
      ok "--all, fxa OMITTED: the deriver writes the map with the OMITTED header naming fxa, and the plan-shape pair RUNS under --all (its presence line printed)"
    else
      bad "--all, fxa OMITTED: expected rc 0, OMITTED header 1, plan-shape presence 1, skip 0, merge-dropped 0; got '$AO' — $(grep -m1 -E 'ERROR|merge dropped' "$WORK/all.out" | tr '\n' ' ')$(tail -2 "$WORK/all.out" | tr '\n' ' ')"
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    AS="$(all_run "$SB/deriver.sh" "$SX/allS.list" plan-shape)"
    if [ "$AS" = "0|1|0|1|0" ]; then
      ok "--all, plan-shape OMITTED: the deriver prints the exact SKIP line for the plan-shape pair and writes the map naming plan-shape OMITTED"
    else
      bad "--all, plan-shape OMITTED: expected rc 0, header 1, presence 0, SKIP line 1, merge-dropped 0; got '$AS' — $(tail -2 "$WORK/all.out" | tr '\n' ' ')"
    fi
    # Two whole-deriver mutants. inline: `--all` back on the base newline loop while the fixed guard
    # stays -- the merge no longer dies, so only the plan-shape PRESENCE line separates it (W2/W4).
    # noskip: the D1 guard disabled, so an omitted plan-shape fails its own positive control and the
    # whole --all run dies unwritten.
    _o="$(grep -m1 '^  --all)  LIST="\$(readset_all_list ' "$SB/deriver.sh")"
    mut_line "$SB/deriver.sh" "$SX/deriver.inline.sh" "$_o" '  --all)  LIST="$(cd "$TREE" && for d in "$FIXTURE_ROOT"/*/; do [ -f "$d/run.sh" ] && basename "$d"; done)" ;;'
    _o="$(grep -m1 '^if \[ "\${FIXTURE_HAS_PLAN_SHAPE:-yes}" = yes \] && ! grep -q ' "$SB/deriver.sh")"
    mut_line "$SB/deriver.sh" "$SX/deriver.noskip.sh" "$_o" 'if false; then'
    # notab: the D1 guard greps `^plan-shape` without the tab, so plan-shape-x's rows count as
    # plan-shape's and the pair runs on an omitted plan-shape -- the world S arm refuses it.
    mut_line "$SB/deriver.sh" "$SX/deriver.notab.sh" "$_o" "$(printf '%s' "$_o" | sed "s/'^plan-shape	'/'^plan-shape'/")"
    TRACE_ARMS=$((TRACE_ARMS+1))
    if cmp -s "$SB/deriver.sh" "$SX/deriver.inline.sh"; then bad "--all MUTANT inline did not apply"
    else
      AM="$(all_run "$SX/deriver.inline.sh" "$SX/allO.list" fxa)"
      case "$AM" in
        "0|1|0|0|0") ok "--all MUTANT inline: with --all back on the newline loop the map is still written, but the plan-shape presence line is gone — the pair is skipped on every --all run, and the world O arm refuses it" ;;
        *) bad "--all MUTANT inline: expected rc 0, header 1, presence 0; got '$AM'" ;;
      esac
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    if cmp -s "$SB/deriver.sh" "$SX/deriver.noskip.sh"; then bad "--all MUTANT noskip did not apply"
    else
      AN="$(all_run "$SX/deriver.noskip.sh" "$SX/allS.list" plan-shape)"
      case "$AN" in
        [1-9]*"|0|0|0|0") if grep -q 'controls failed' "$WORK/all.out"; then
            ok "--all MUTANT noskip: with the D1 guard disabled an omitted plan-shape fails its own control and the --all run dies 'controls failed', unwritten — the world S arm refuses it"
          else bad "--all MUTANT noskip: the run died ('$AN') but not on 'controls failed'"; fi ;;
        *) bad "--all MUTANT noskip: expected a non-zero exit with no header, presence or SKIP line; got '$AN'" ;;
      esac
    fi
    TRACE_ARMS=$((TRACE_ARMS+1))
    if cmp -s "$SB/deriver.sh" "$SX/deriver.notab.sh"; then bad "--all MUTANT notab did not apply"
    else
      AT="$(all_run "$SX/deriver.notab.sh" "$SX/allS.list" plan-shape)"
      case "$AT" in
        "0|1|0|1|0") bad "--all MUTANT notab SURVIVED: the tab-less D1 guard still printed the SKIP line, so the plan-shape-x sibling did not discriminate ('$AT')" ;;
        *"|0|0") if grep -q 'controls failed' "$WORK/all.out"; then
            ok "--all MUTANT notab: with the D1 guard grepping '^plan-shape' untabbed, plan-shape-x's rows pass for plan-shape's, the pair runs on an omitted plan-shape and the run dies 'controls failed' — the world S arm refuses it"
          else bad "--all MUTANT notab: no SKIP line, but the run did not die on 'controls failed' ('$AT')"; fi ;;
        *) bad "--all MUTANT notab: expected no SKIP line and a 'controls failed' death; got '$AT'" ;;
      esac
    fi

    # THE UNREAD CONTROL. A fixture that reads the planted control file is the stand-in for a reset
    # that did not hold (the file's atime moves either way): it must be OMITTED naming the control.
    # The ordinary stub run above is the near-miss and already maps (CANARY CONTROL). The mutant
    # deletes the guard line and must map the reading fixture.
    mkdir -p "$BR/core/fixtures/fxu" || broken "mkdir failed"
    printf '#!/bin/bash\ncat .git/readset-unread-control >/dev/null\ncat src/a.sh >/dev/null\n' > "$BR/core/fixtures/fxu/run.sh"
    printf '%s\n' core/fixtures/fxu/run.sh src/a.sh > "$SX/fxu.list"
    ( cd "$BR" && git add -A && git -c user.email=f@f -c user.name=f commit -qm fxu ) >/dev/null 2>&1 || broken "could not seed fxu"
    unread_run() { # $1 deriver copy; prints the fxu line
      cp "$1" "$STUB_DERIVER"
      ( cd "$BR" && env -u VAS_INNER_POOL_WIDTH -u EMS_POOL_WIDTH PATH="$SX:$PATH" STUB_FEED="$SX/feed" STUB_SB="$SX/fxu.list" \
          AI_DLC_READSET_TRACE_ROOT="$SX_TR" bash core/scripts/derive-fixture-readsets.sh --list fxu --tracer sandbox ) > "$WORK/unread.out" 2>&1 </dev/null
      ( cd "$BR" && git checkout -q -- . ) >/dev/null 2>&1
      grep -m1 -E '^  fxu ' "$WORK/unread.out" | tr -s ' '
    }
    sed '/^  \[ "\$unread_moved" -eq 0 \] || why=/d' "$SB/deriver.sh" > "$SX/deriver.nounread.sh"
    TRACE_ARMS=$((TRACE_ARMS+1))
    UR="$(unread_run "$SB/deriver.sh")"
    case "$UR" in
      " fxu OMITTED ("*"UNREAD CONTROL"*) ok "UNREAD CONTROL: a fixture whose window moved the planted control's atime is OMITTED naming the control" ;;
      *) bad "UNREAD CONTROL: expected fxu OMITTED naming the UNREAD CONTROL, got '$UR' — $(tail -2 "$WORK/unread.out" | tr '\n' ' ')" ;;
    esac
    TRACE_ARMS=$((TRACE_ARMS+1))
    if cmp -s "$SB/deriver.sh" "$SX/deriver.nounread.sh"; then
      bad "UNREAD CONTROL MUTANT did not apply"
    else
      UM="$(unread_run "$SX/deriver.nounread.sh")"
      case "$UM" in
        " fxu "*" paths") ok "UNREAD CONTROL MUTANT: with the guard deleted the same fixture MAPS — the arm depends on that line" ;;
        *) bad "UNREAD CONTROL MUTANT: expected fxu mapped, got '$UM'" ;;
      esac
    fi
  fi
fi

# THE SUMMARY IS ALSO A COMPLETENESS CHECK. This fixture once ended mid-file after an editing
# mistake: it printed two thirds of its arms, never reached a verdict line, and exited 0 --
# which the suite's worker records as `ok`. A fixture that dies silently reads exactly like one
# that passed, so the arm count is asserted against the number this file actually carries.
EXPECTED=$(( 18 + NEW_ARMS + MERGE_ARMS + CONTROL_ARMS + TRACE_ARMS + BOTH_ARMS ))
if [ "$asserts" -lt "$EXPECTED" ]; then
  printf '  FAIL  only %s assertions ran; this fixture carries %s — it exited early and a short green run reads exactly like a passing one\n' "$asserts" "$EXPECTED"
  fails=$((fails+1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "readset-skip: PASS ($asserts assertions)"; exit 0
fi
echo "readset-skip: $fails of $asserts assertion(s) FAILED"; exit 1
