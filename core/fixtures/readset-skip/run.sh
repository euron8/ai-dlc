#!/usr/bin/env bash
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
# Keyed on the EMITTING line, not on a spelling of the announce: the flag is the decision.
flag_mutant nochange_off 's|READSET_NO_CHANGE=1|READSET_NO_CHANGE=0|' "1" ':'
# Drop untracked files from the universe: arm 11's newcomer goes invisible and the suite skips
# over a tree nobody hashed. This is the soundness half of the change.
flag_mutant untracked_blind 's|git ls-files --others --exclude-standard 2>/dev/null||' \
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

# ------------------------------------------------------- the deriver's map merge ----
# `--list` exists so refreshing ONE fixture costs its own runtime instead of a full
# re-derivation. Its first version rewrote the map from only the fixtures it had just traced,
# silently dropping every other entry. That is SAFE -- an unmapped fixture always runs -- and
# therefore invisible: the suite stays correct and merely stops skipping, which reads as the
# feature underperforming rather than as a bug. These arms are why it cannot come back.
#
# THE DERIVER IS DIST-ONLY and a consumer never has it, so its absence is reported as a SKIP
# rather than passing silently. A vanished arm and a passing arm look identical in a summary.
MERGE_ARMS=0
DERIVER="$ROOT/scripts/derive-fixture-readsets.sh"
if [ ! -f "$DERIVER" ]; then
  printf '  SKIP  map-merge arms: scripts/derive-fixture-readsets.sh is not in this tree (dist-only)\n'
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
fi

# THE SUMMARY IS ALSO A COMPLETENESS CHECK. This fixture once ended mid-file after an editing
# mistake: it printed two thirds of its arms, never reached a verdict line, and exited 0 --
# which the suite's worker records as `ok`. A fixture that dies silently reads exactly like one
# that passed, so the arm count is asserted against the number this file actually carries.
EXPECTED=$(( 15 + MERGE_ARMS ))
if [ "$asserts" -lt "$EXPECTED" ]; then
  printf '  FAIL  only %s assertions ran; this fixture carries %s — it exited early and a short green run reads exactly like a passing one\n' "$asserts" "$EXPECTED"
  fails=$((fails+1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "readset-skip: PASS ($asserts assertions)"; exit 0
fi
echo "readset-skip: $fails of $asserts assertion(s) FAILED"; exit 1
