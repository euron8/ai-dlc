#!/usr/bin/env bash
# Exercise reconcile/self-update-gate.sh.
#
# THE DIFFERENTIAL IS THE WHOLE MECHANISM. `gate-defer`, `gate-broken` and `gate-agree` all exit
# non-zero on the incoming side. A gate reading the incoming exit code alone calls them the same
# thing — and calling a pre-existing failure a "defer" strands the machinery slice for a reason
# unrelated to the pull. Only comparing against the consumer's CURRENT copy separates a new finding
# from an old one, and the mutation below removes exactly that comparison.
#
# The three then split by what the comparison SAYS: 0 -> 1 is a new finding (DEFER), 1 -> 1 is
# agreement and therefore no signal at all (OK, v0.297.0), 1 -> 2 is a real change nobody can
# attribute (UNDECIDED).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

GATE=""; LOOKED=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/self-update-gate.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/self-update-gate.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/self-update-gate.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && GATE="$cand" && break
done
[ -n "$GATE" ] || { printf 'FAIL: cannot locate self-update-gate.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }

read -r DIST BASE THEIRS CONS < <(bash "$DIR/seed.sh")
trap 'rm -rf "$(dirname "$DIST")"' EXIT

OUT="$(bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
RC=$?

FAILURES=0
ASSERTIONS=0

# $1 script  $2 expected STATUS (or ABSENT)  $3 why
row() {
  local s="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v s="$s" '$2 == s {print $1; exit}')"
  if [ "$want" = ABSENT ]; then
    if [ -z "$got" ]; then
      printf '  ok    %-16s no row  (%s)\n' "$s" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-16s got=%s want=no-row  (%s)\n' "$s" "$got" "$why"
    fi
  elif [ "$got" = "$want" ]; then
    printf '  ok    %-16s %s  (%s)\n' "$s" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s got=%s want=%s  (%s)\n' "$s" "${got:-<none>}" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  fi
}

echo "self-update-gate fixture"
echo

row gate-pass.sh   SELF-UPDATE-OK        "incoming passes against the consumer tree, so installing it cannot block the push"
row gate-defer.sh  SELF-UPDATE-DEFER     "current 0, incoming 1 — a genuinely new finding on pre-existing state"
# v0.297.0: agreement is not a differential signal, whatever the code. Both sides exit 1 here, so
# the incoming version fails nowhere the current one passes. Falsified by MUTANT C in
# self-update-join-gate, which narrows the arm back to 2-and-2 and watches 1,1 defer again.
row gate-broken.sh SELF-UPDATE-OK        "both exit 1 — equal codes carry no differential, and this bare probe cannot pass what the pre-push passes"
# ...and DISAGREEING non-zero codes are the only remaining route to UNDECIDED. Without this row
# that verdict would have no subject at all.
row gate-agree.sh  SELF-UPDATE-UNDECIDED "current 1, incoming 2 — two non-zero codes that DISAGREE, so the change is real but unattributable"

# The gating set comes from the HOOK, not from the changed-path list. not-invoked.sh changed AND its
# incoming version exits 1, so a gate deriving the set from the diff would emit a spurious defer.
row not-invoked.sh ABSENT "changed but the pre-push never invokes it, so it cannot block a push"
# ...and a script the hook DOES invoke but which this pull does not change is equally out of scope.
row unchanged.sh   ABSENT "invoked but unchanged base->theirs, so the self-update does not replace it"

# UNDECIDED must be treated as a defer, or the caller proceeds autonomously on a failure nobody
# could attribute — the one thing this gate exists to prevent.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1 == "SELF-UPDATE-DEFER" && $2 == "-" {f=1} END{exit !f}'; then
  printf '  ok    %-16s a summary DEFER row is emitted, so the caller cannot read past a per-script verdict\n' "summary-defer"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s no summary DEFER row — a caller scanning only the last line would proceed\n' "summary-defer"
fi

# Classifier, not a gate: the CALLER decides, same posture as layer-drift.sh.
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$RC" -eq 0 ]; then
  printf '  ok    %-16s exit 0  (classifier never blocks; the caller decides)\n' "exit-code"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s exit=%s want=0\n' "exit-code" "$RC"
fi

# --- MUTATION: drop the differential, read the incoming exit code alone --------------
# gate-agree then reads as a DEFER, which is the false positive that strands a machinery slice for
# a failure nobody can attribute. It must ALSO leave gate-defer's real verdict intact, or the mutant
# is entangled and proves nothing about which half did the work.
#
# THE SUBJECT MOVED IN v0.297.0, from gate-broken to gate-agree, and the reason is that gate-broken
# is no longer reachable by this mutation: 1-and-1 now settles on the equality arm ABOVE the
# differential, so dropping the differential cannot move it. Aiming a mutant at a case the mutation
# can no longer reach is how a kill becomes a coincidence.
MUT="$(dirname "$DIST")/mut-nodiff"
rm -rf "$MUT"; mkdir -p "$MUT"
sed 's/^  elif \[ "$rc_cur" -eq 0 \]; then$/  elif true; then/' "$GATE" > "$MUT/gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$MUT/gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s the mutation matched nothing, so the UNDECIDED assertion is unproven\n' "mutation"
else
  m="$(bash "$MUT/gate.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
  m_broken="$(printf '%s\n' "$m" | awk -F'\t' '$2 == "gate-agree.sh" {print $1; exit}')"
  m_defer="$(printf '%s\n' "$m"  | awk -F'\t' '$2 == "gate-defer.sh"  {print $1; exit}')"
  if [ "$m_broken" = SELF-UPDATE-DEFER ] && [ "$m_defer" = SELF-UPDATE-DEFER ]; then
    printf '  ok    %-16s without the differential a pre-existing failure reads as a defer\n' "mutation"
  elif [ "$m_broken" != SELF-UPDATE-DEFER ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutant still classified gate-agree as %s, so the differential assertion is vacuous\n' "mutation" "${m_broken:-<none>}"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutant also changed gate-defer to %s, so it is entangled\n' "mutation" "${m_defer:-<none>}"
  fi
fi

# THE UNMUTATED CONTROL. The mutant is a copy; a copy that cannot run emits nothing, and nothing
# would score as a kill above.
CTL="$(dirname "$DIST")/ctl"; rm -rf "$CTL"; mkdir -p "$CTL"; cp "$GATE" "$CTL/gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
c_broken="$(bash "$CTL/gate.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1 | awk -F'\t' '$2 == "gate-agree.sh" {print $1; exit}')"
if [ "$c_broken" = SELF-UPDATE-UNDECIDED ]; then
  printf '  ok    %-16s unmutated copy reproduces UNDECIDED (harness is sound)\n' "mutation-control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s unmutated copy gave %s — a copy that cannot run scores as a kill\n' "mutation-control" "${c_broken:-<none>}"
fi

# --- --safe-stop: a DEFER must name the ref that ends it -------------------------------
#
# A DEFER is correct and it is a dead end. The deferred slice lands at step 7, AFTER step 3's
# classify, so a classifier improvement anywhere in the range cannot classify the pull that
# delivers it — the operator gets a report written by the engine they were replacing. The way
# out is to stop at a release whose slice IS machinery-only, and that ref is derivable only by
# running this gate per release. These arms assert it is derived, and derived CORRECTLY.
#
# Own miniature distribution: the seeded one has no release history, and `--safe-stop`'s
# candidate set IS the release history.
SS="$(dirname "$DIST")/ss"; rm -rf "$SS"; mkdir -p "$SS/dist/core/skills/ai-dlc/steps" "$SS/cons/.claude/skills/ai-dlc/steps"
gvv() { printf '# gate\n'; for a in "$@"; do printf '<!-- CHECK_LOADED: %s -->\n' "$a"; done; }
gvv 1 2 > "$SS/cons/.claude/skills/ai-dlc/steps/gate-validation.md"
# The consumer's hook is the authority on what can block ITS push, and its ABSENCE is
# UNDECIDED, not OK — correctly, since a gate that cannot see the hook cannot say what the
# self-update would install. Without this the whole section ran on UNDECIDED and two arms
# passed for a reason unrelated to what they assert; the precondition arms below exist
# because that is exactly what happened.
mkdir -p "$SS/cons/.githooks"
printf '#!/usr/bin/env bash\n# invokes no scripts/ai-dlc/ validator, so the gating set is empty\nexit 0\n' > "$SS/cons/.githooks/pre-push"
git -C "$SS/dist" init -q
printf '1.0.0\n' > "$SS/dist/VERSION"; gvv 1 2 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1
SS_BASE="$(git -C "$SS/dist" rev-parse HEAD)"
# r1 — a release that moves VERSION and nothing the consumer's rulebook is joined against.
printf '1.1.0\n' > "$SS/dist/VERSION"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r1 >/dev/null 2>&1
SS_R1="$(git -C "$SS/dist" rev-parse HEAD)"
# r2 — a release that declares a check anchor the consumer's rulebook does not carry (ARM R1).
printf '1.2.0\n' > "$SS/dist/VERSION"; gvv 1 2 3 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r2 >/dev/null 2>&1
SS_R2="$(git -C "$SS/dist" rev-parse HEAD)"
# r3 — the coupling is gone again, so base→r3 is a CLEAN single hop even though base→r2 is not.
# This is the shape that proves the walk evaluates every candidate instead of stopping at the
# first defer: r3 lands strictly more than r1 and an early-stopping walk can never name it.
printf '1.3.0\n' > "$SS/dist/VERSION"; gvv 1 2 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r3 >/dev/null 2>&1
SS_R3="$(git -C "$SS/dist" rev-parse HEAD)"
# d3 — a NON-release commit after the last clean release, and the only reason it exists.
# The candidate set is release commits because the stamp records a VERSION, so a mid-release
# stop is not a state a consumer can hold. Without a commit that is clean, later than r3 and
# NOT a release, "candidates are releases" and "candidates are all commits" pick the same ref
# and the property is untestable — a mutation widening the candidate set came back green until
# this commit existed.
printf 'docs only, no VERSION change\n' > "$SS/dist/NOTES.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm d3 >/dev/null 2>&1
# r4 — THEIRS. Needed so r3 is an INTERMEDIATE candidate rather than the target itself.
printf '1.4.0\n' > "$SS/dist/VERSION"; gvv 1 2 3 4 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r4 >/dev/null 2>&1
SS_R4="$(git -C "$SS/dist" rev-parse HEAD)"

ss_assert() { # ss_assert <label> <got> <want> <why>
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$2" = "$3" ]; then printf '  ok    %-16s %s\n' "$1" "$4"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s got=[%s] want=[%s]  %s\n' "$1" "$2" "$3" "$4"; fi
}

# PRECONDITION, or every arm below is vacuous: r2 must actually defer and r1 must not.
ss_assert "safe-stop-pre" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | awk -F'\t' '$1 ~ /DEFER/ {print "defer"; exit}')" \
  "defer" "the seeded r2 really does defer (without this the walk has nothing to stop at)"
ss_assert "safe-stop-pre2" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R1" "$SS/cons" 2>&1 | awk -F'\t' '$1 ~ /DEFER|UNDECIDED/ {print "defer"; exit}')" \
  "" "and the seeded r1 does not — so a walk that returns r1 returned the CLEAN one"

ss_assert "safe-stop" "$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>/dev/null)" \
  "$SS_R1" "the furthest cleanly-self-updating release in base..r2 is r1"

# CONTROL: it is not simply echoing the newest release, nor THEIRS itself. With r1 as the
# target there is no INTERMEDIATE release, so the honest answer is nothing.
ss_out="$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R1" "$SS/cons" 2>/dev/null)"; ss_rc=$?
ss_assert "safe-stop-none" "${ss_out}|${ss_rc}" "|1" \
  "with no intermediate release the walk returns nothing and rc 1, rather than naming THEIRS"

# The advisory reaches the caller on a DEFER, and names the ref rather than restating the problem.
ss_assert "safe-stop-row" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $2; exit}')" \
  "$SS_R1" "a DEFER carries a SELF-UPDATE-SAFE-STOP row naming the ref"

# CONTROL: a clean verdict must NOT carry one. Advice attached to every run is noise, and it
# would also mean the arm above fires regardless of the verdict it claims to accompany.
ss_assert "safe-stop-quiet" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R1" "$SS/cons" 2>&1 | grep -c 'SELF-UPDATE-SAFE-STOP')" \
  "0" "a SELF-UPDATE-OK verdict carries no advisory"

# THE LATEST CLEAN CANDIDATE WINS, NOT THE ONE BEFORE THE FIRST DEFER. base..r4 contains a
# clean r1, a deferring r2 and a clean r3. Each verdict is computed BASE→candidate, so r3 is a
# single clean hop that lands strictly more than r1 — a walk that stopped at the first defer
# would answer r1 and quietly cost the operator two releases of progress.
ss_assert "safe-stop-latest" "$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R4" "$SS/cons" 2>/dev/null)" \
  "$SS_R3" "the LATEST clean release wins, even with a deferring release before it"
ss_assert "safe-stop-latest-pre" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R3" "$SS/cons" 2>&1 | awk -F'\t' '$1 ~ /DEFER|UNDECIDED/ {print "defer"; exit}')" \
  "" "and r3 really is clean from base — without this the arm above proves nothing"

# --safe-stop's stdout is a REF AND NOTHING ELSE, because the caller substitutes it into a
# command. A leaked TSV row — the advisory re-entering through a nested classify, say — would
# be pasted straight into `ai-dlc-update <ref>`.
#
# This replaced an assertion that compared "reached" to "reached", which passed whenever the
# fixture got that far and therefore asserted nothing. It was written to cover the advisory's
# re-entry guard; a mutant removing that guard came back GREEN, which is how the tautology was
# found. The guard is a COST measure — a nested walk covers a strictly shorter range, so the
# recursion terminates either way — and it is deliberately NOT covered by an assertion here,
# because no observable output distinguishes the two.
ss_assert "safe-stop-clean-stdout" \
  "$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>/dev/null | grep -c 'SELF-UPDATE-')" \
  "0" "stdout carries the ref alone, with no status row that could be pasted into a command"

# --- THE ROW IS DERIVED FROM THE RANGE, AND THE CONSUMER'S MACHINERY IS THE OTHER HALF -------
# `PC-S331-SAFE-STOP-IGNORES-THE-CONSUMERS-OWN-SKILL-COMMIT`. The row urges a split so the engine
# lands before it is used. On a consumer whose `skill_commit` is already at or past the named ref,
# the engine HAS landed and the split advances only the rulebook pair. Every arm above ran without
# a stamp at all, which is why none of them could see this.
ss_detail() { # ss_detail <theirs> -> the SAFE-STOP row's DETAIL field
  bash "$GATE" "$SS/dist" "$SS_BASE" "$1" "$SS/cons" 2>&1 |
    awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $3; exit}'
}
ss_stamp() { # ss_stamp <skill_commit|-> ; `-` removes the stamp
  if [ "$1" = "-" ]; then rm -f "$SS/cons/.claude/.ai-dlc-version"
  else printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' "$SS_BASE" "$1" \
         > "$SS/cons/.claude/.ai-dlc-version"; fi
}

# BASELINE, and it is the control that makes the next three readable: with no stamp the wording is
# unchanged from before this guard existed.
ss_stamp -
ss_assert "ss-nostamp" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "no stamp: the row keeps its original 'pull FIRST' wording"

# AT the named ref. `--is-ancestor` is true for equality, which is the "at" in "at or past".
ss_stamp "$SS_R1"
ss_assert "ss-at" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "1" \
  "skill_commit AT the named ref: the row says the split buys nothing"
ss_assert "ss-at-ref" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP"{print $2; exit}')" \
  "$SS_R1" "and it still NAMES the ref — annotated, never suppressed, so the DEFER keeps a next step"

# PAST it — the reference consumer's actual shape: `skill_commit` was one commit beyond the
# release the row named, so an equality test alone would have missed the case that was filed.
ss_stamp "$SS_R3"
ss_assert "ss-past" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "1" \
  "skill_commit PAST the named ref: still annotated (equality alone would miss the filed case)"

# CONTROL: BEHIND it. This is the case the row was written for and it must be untouched.
ss_stamp "$SS_R1"
ss_assert "ss-behind" "$(ss_detail "$SS_R4" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "skill_commit BEHIND the ref the walk names (r3): the original advice stands"

# CONTROL: a ref this distribution cannot resolve tells us nothing, and must not be read as
# "at or past" — that would silence the advice on every consumer with a foreign stamp.
ss_stamp "0000000000000000000000000000000000000000"
ss_assert "ss-unresolvable" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "an unresolvable skill_commit falls back to the original advice"

# CONTROL: `skill_commit` == `commit` means no self-update hop has run, so there is no
# intermediate machinery ref and the guard must not fire off the rulebook sha.
ss_stamp "$SS_BASE"
ss_assert "ss-equals-base" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "skill_commit == commit (no self-update hop) falls back to the original advice"
ss_stamp -

# --- ARM C: SELF-UPDATE-CARRY, one row per machinery path the consumer diverged on ----
#
# Step 2 justifies its autonomy -- no operator gate, auto-merged PR -- on the claim that the
# skill's own files are overwrite-safe, and then writes the WHOLE machinery set from
# `theirs`. For a machinery path the consumer has edited that destroys the edit with nothing
# anywhere reporting it. Filed on the reference consumer as
# PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH after that tree's
# own `.githooks/pre-push` came back BOTH-CHANGED on a live pull.
#
# ITS OWN MINIATURE DISTRIBUTION, for the same reason --safe-stop needed one: the seeded tree
# above DEFERS, and an advisory that has only ever been seen beside a DEFER cannot show that
# it leaves the verdict alone. These arms need a CARRY row and a SELF-UPDATE-OK in one output.
#
# THE POPULATION IS THE SUBJECT, NOT THE STRING `BOTH-CHANGED`. Four buckets record a consumer
# divergence on a machinery path, and a fix keyed on the modified-both-sides one catches a
# quarter of them while reading as complete. All four are seeded, and one of them carries no
# `->CLASSIFY` marker at all:
#
#   core/git-hooks/pre-push   M  BOTH-CHANGED->CLASSIFY                        literal entry
#   core/rules/edited.md      M  BOTH-CHANGED->CLASSIFY                        GLOBBED entry
#   core/rules/doomed.md      D  UPSTREAM-DELETED+consumer-modified->CLASSIFY  absent at THEIRS
#   core/schemas/fresh.json   A  BOTH-ADDED->CLASSIFY                          absent at BASE
#   core/scripts/reloc.sh     R  RELOCATE-MOVE+consumer-edited                 no marker
#
# ...and TWO NEAR-MISSES, which are the arms that a check emitting unconditionally fails.
# Each differs from a real offender in exactly one respect, so neither can be excluded by an
# accident of the tree:
#
#   core/rules/steady.md            machinery and in the pull, but the consumer is UNTOUCHED
#   .../steps/gate-validation.md    diverged, same BOTH-CHANGED bucket, but NOT machinery
AC="$(dirname "$DIST")/armc"
rm -rf "$AC"
mkdir -p "$AC/dist/core/rules" "$AC/dist/core/git-hooks" "$AC/dist/core/schemas" \
         "$AC/dist/core/scripts" "$AC/dist/core/skills/ai-dlc/steps" \
         "$AC/cons/.claude/rules" "$AC/cons/.claude/schemas" "$AC/cons/scripts" \
         "$AC/cons/.claude/skills/ai-dlc/steps" "$AC/cons/.githooks" \
         "$AC/clean/.claude/rules" "$AC/clean/.claude/skills/ai-dlc/steps" "$AC/clean/.githooks" \
         "$AC/cwd/core/rules" "$AC/cwd/core/schemas" "$AC/cwd/core/scripts/ai-dlc"

# A DECOY WORKING DIRECTORY, AND IT IS LOAD-BEARING FOR THE `set -f` MUTANT BELOW. The
# manifest entries are git PATHSPECS; without `set -f` the shell expands them against
# whatever CWD the caller happened to be in, BEFORE git sees them. That defect is therefore
# invisible from a CWD with no `core/` in it -- the globs stay literal and reach git intact --
# so a mutant run from an arbitrary directory would come back green against a real defect.
# These three files guarantee the expansion has something to bite on, which makes the kill a
# property of the mutation rather than of where the suite was launched from.
printf 'decoy\n' > "$AC/cwd/core/rules/decoy.md"
printf '{}\n'    > "$AC/cwd/core/schemas/decoy.json"
printf 'decoy\n' > "$AC/cwd/core/scripts/ai-dlc/decoy.sh"

git -C "$AC/dist" init -q
printf '0.1.0\n'          > "$AC/dist/VERSION"
printf 'hook base\n'      > "$AC/dist/core/git-hooks/pre-push"
printf 'doomed base\n'    > "$AC/dist/core/rules/doomed.md"
printf 'edited base\n'    > "$AC/dist/core/rules/edited.md"
printf 'steady base\n'    > "$AC/dist/core/rules/steady.md"
printf 'reloc base\n'     > "$AC/dist/core/scripts/reloc.sh"
gvv 1                     > "$AC/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$AC/dist" add -A >/dev/null 2>&1
git -C "$AC/dist" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1
AC_BASE="$(git -C "$AC/dist" rev-parse HEAD)"

printf '0.2.0\n'          > "$AC/dist/VERSION"
printf 'hook theirs\n'    > "$AC/dist/core/git-hooks/pre-push"
rm -f                       "$AC/dist/core/rules/doomed.md"
printf 'edited theirs\n'  > "$AC/dist/core/rules/edited.md"
printf 'steady theirs\n'  > "$AC/dist/core/rules/steady.md"
printf '{"v":"theirs"}\n' > "$AC/dist/core/schemas/fresh.json"
{ gvv 1; printf 'theirs prose\n'; } > "$AC/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$AC/dist" add -A >/dev/null 2>&1
git -C "$AC/dist" -c user.email=f@x -c user.name=f commit -qm theirs >/dev/null 2>&1
AC_THEIRS="$(git -C "$AC/dist" rev-parse HEAD)"

# The diverged consumer. `core/scripts/reloc.sh` is UNCHANGED base->theirs on purpose: its
# bucket is level-triggered off the consumer's un-migrated copy, and leaving it out of the
# range also keeps the gating set empty so the verdict below is a clean OK.
printf 'hook LOCAL EDIT\n'            > "$AC/cons/.githooks/pre-push"
printf 'doomed LOCAL EDIT\n'          > "$AC/cons/.claude/rules/doomed.md"
printf 'edited LOCAL EDIT\n'          > "$AC/cons/.claude/rules/edited.md"
printf 'steady base\n'                > "$AC/cons/.claude/rules/steady.md"
printf '{"v":"LOCAL"}\n'              > "$AC/cons/.claude/schemas/fresh.json"
printf 'reloc LOCAL EDIT\n'           > "$AC/cons/scripts/reloc.sh"
{ gvv 1; printf 'consumer prose\n'; } > "$AC/cons/.claude/skills/ai-dlc/steps/gate-validation.md"

# The undiverged consumer: every copy is BASE, so every bucket is a plain apply. It holds no
# `scripts/` and no `schemas/` at all, which is the ordinary state -- the relocation pass and
# the added-file arm both have nothing to say about it.
printf 'hook base\n'   > "$AC/clean/.githooks/pre-push"
printf 'doomed base\n' > "$AC/clean/.claude/rules/doomed.md"
printf 'edited base\n' > "$AC/clean/.claude/rules/edited.md"
printf 'steady base\n' > "$AC/clean/.claude/rules/steady.md"
gvv 1                  > "$AC/clean/.claude/skills/ai-dlc/steps/gate-validation.md"

ac_carry() { # ac_carry <gate> <consumer> <cwd> -> CARRY paths, sorted, comma-terminated
  ( cd "$3" && bash "$1" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$2" 2>/dev/null ) |
    awk -F'\t' '$1 == "SELF-UPDATE-CARRY" {print $2}' | sort | tr '\n' ','
}
AC_ALL='core/git-hooks/pre-push,core/rules/doomed.md,core/rules/edited.md,core/schemas/fresh.json,core/scripts/reloc.sh,'

# SELF-PROBE, AND IT RUNS BEFORE THE ARMS IT UNDERWRITES. Both absence arms below are claims
# about a path the bucket derivation DID see and did NOT carry. If preclassify never bucketed
# them at all, those arms are absences over an empty set: they pass, they read exactly like a
# discriminating check, and they would go on passing against a gate that emits nothing.
AC_PRE="$(bash "$(dirname "$GATE")/preclassify.sh" \
             "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/cons" 2>/dev/null)"
ac_bucket() { printf '%s\n' "$AC_PRE" | awk -F'\t' -v p="$1" '$2 == p {print $4; exit}'; }

ss_assert "carry-probe-untouched" "$(ac_bucket core/rules/steady.md)" "UPSTREAM-ONLY" \
  "the untouched machinery near-miss IS in the bucket set, so its missing CARRY row is a decision"
ss_assert "carry-probe-nonmach" "$(ac_bucket core/skills/ai-dlc/steps/gate-validation.md)" \
  "BOTH-CHANGED->CLASSIFY" \
  "the non-machinery near-miss carries a REAL offender's bucket, so only membership can separate them"

AC_OUT="$(bash "$GATE" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/cons" 2>&1)"

# The row names the CORE path and its detail names the CONSUMER path -- an advisory the
# operator cannot act on without both is a dead end of the kind advise_safe_stop exists to
# remove.
ss_assert "carry-names-path" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' \
      '$1 == "SELF-UPDATE-CARRY" && $2 == "core/git-hooks/pre-push" && $3 ~ /\.githooks\/pre-push/ {print "named"; exit}')" \
  "named" "a consumer-modified machinery path produces a CARRY row naming that path and the consumer's copy"

# THE ARM THAT SEPARATES THE SHIPPED FIX FROM THE PLAUSIBLE WRONG ONE. Exact set, not a
# count: a check keyed on `BOTH-CHANGED` alone reaches one of these five and every other
# assertion here still passes.
ss_assert "carry-population" "$(printf '%s\n' "$AC_OUT" | awk -F'\t' \
      '$1 == "SELF-UPDATE-CARRY" {print $2}' | sort | tr '\n' ',')" "$AC_ALL" \
  "every divergence bucket carries -- deleted-upstream, added-both-sides and the relocation row that has no ->CLASSIFY marker"

ss_assert "carry-quiet-untouched" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' '$1 == "SELF-UPDATE-CARRY" && $2 == "core/rules/steady.md"' | grep -c .)" \
  "0" "a machinery path in the pull the consumer has NOT touched carries no row"

ss_assert "carry-not-machinery" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' '$1 == "SELF-UPDATE-CARRY" && $2 ~ /steps\/gate-validation/' | grep -c .)" \
  "0" "a diverged NON-machinery path carries no row; this gate decides the machinery self-update only"

# ADVISORY, NOT VERDICT. Asserted as the exact verdict set: OK present AND no DEFER or
# UNDECIDED anywhere. A CARRY row that moved the verdict would stop a cycle that the rest of
# the slice can complete perfectly well.
ss_assert "carry-verdict-ok" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' \
      '$1 == "SELF-UPDATE-OK" || $1 == "SELF-UPDATE-DEFER" || $1 == "SELF-UPDATE-UNDECIDED" {print $1}' \
      | sort -u | tr '\n' ',')" \
  "SELF-UPDATE-OK," "the CARRY rows sit beside an unchanged SELF-UPDATE-OK -- the advisory does not move the verdict"

# THE ZERO CARRIES ITS CONTROL IN THE SAME BREATH. An undiverged consumer must produce no row,
# and a gate that produced no rows for any other reason would satisfy that identically -- so
# the bucket count on the SAME tree is asserted non-zero beside it.
ss_assert "carry-clean-consumer" "$(ac_carry "$GATE" "$AC/clean" "$DIR")" "" \
  "a consumer that has diverged on nothing gets no CARRY row at all"
ss_assert "carry-clean-control" \
  "$(bash "$(dirname "$GATE")/preclassify.sh" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/clean" 2>/dev/null \
     | grep -c . | awk '{print ($1 > 0) ? "buckets" : "none"}')" \
  "buckets" "...and that zero is a decision, not a derivation that never ran"

# COST GUARD WITH AN OBSERVABLE. --safe-stop reads only DEFER and UNDECIDED, so a CARRY row
# cannot change any answer it computes, and emitting one per release candidate in the range
# buys nothing. Unlike advise_safe_stop's re-entry guard this one IS observable, so it gets an
# assertion rather than a comment.
ss_assert "carry-safe-stop" \
  "$(AI_DLC_GATE_IN_SAFE_STOP=1 bash "$GATE" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/cons" 2>/dev/null \
     | grep -c 'SELF-UPDATE-CARRY')" \
  "0" "the advisory is suppressed inside a --safe-stop walk, where it could change nothing"

# CWD-INVARIANCE, ASSERTED RATHER THAN INHERITED. The pre-push runner drives this fixture from
# the repo root; the arms above therefore only ever see one CWD, and the pathspec-expansion
# defect the `set -f` mutant models is CWD-dependent by nature. Same gate, same tree, a
# directory built to make the expansion bite.
ss_assert "carry-cwd-invariant" "$(ac_carry "$GATE" "$AC/cons" "$AC/cwd")" "$AC_ALL" \
  "the shipped gate answers identically from a CWD whose own core/ would swallow every globbed entry"

# --- MUTANTS on arm C -----------------------------------------------------------------
#
# THE COPY NEEDS ITS SIBLINGS. Arm C resolves setup-sites.md and preclassify.sh by
# `dirname "$0"`, so a lone gate.sh in a bare directory has no machinery manifest and no
# bucket derivation. It would emit no CARRY row for want of a subject, every mutant would
# come back "killed", and the battery would be certifying silence.
#
# EACH MUTANT IS SCORED ON ITS EXACT CARRY SET, and the five sets are all distinct. Two
# mutants that produce the same output are one mutant: the first cut of this battery narrowed
# the bucket key and removed `set -f` and both collapsed to the same single row, so one of
# them was proving nothing. `core/rules/edited.md` is the seed that separates them -- a
# BOTH-CHANGED path reached through a GLOB, which survives the narrowed key and dies with the
# pathname expansion.
ac_mut() { # ac_mut <name> <sed-expr> -> path to the mutated gate, siblings beside it
  local d="$AC/m-$1"
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$d"/ 2>/dev/null
  sed "$2" "$GATE" > "$d/self-update-gate.sh"
  printf '%s\n' "$d/self-update-gate.sh"
}
ac_kill() { # ac_kill <label> <sed-expr> <want-carry-set> <why>
  local g got
  g="$(ac_mut "$1" "$2")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$GATE" "$g"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "$1"
    return
  fi
  got="$(ac_carry "$g" "$AC/cons" "$AC/cwd")"
  if [ "$got" = "$3" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$4"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$3" "$4"
  fi
}

# THE UNMUTATED CONTROL, and it is doing three jobs: the copy resolves its siblings, the decoy
# CWD does not change the answer, and the harness can still produce the FULL set -- so a
# mutant's shortfall below is attributable to the mutation. It is PRESENCE-shaped on purpose:
# a gate replaced by `exit 0` produces the empty set and fails it, where an arm asserting
# "nothing went wrong" would pass.
#
# It does NOT go through ac_kill: that helper refuses a sed matching nothing, which is the
# right refusal for a mutant and the wrong one for a control that must not be mutated at all.
# A control faked with a no-op substitution would trip exactly that guard.
rm -rf "$AC/m-control"; mkdir -p "$AC/m-control"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$AC/m-control"/ 2>/dev/null
ss_assert "armc-control" "$(ac_carry "$AC/m-control/self-update-gate.sh" "$AC/cons" "$AC/cwd")" \
  "$AC_ALL" \
  "an unmutated copy reproduces the FULL carry set from the decoy CWD, so a mutant's shortfall is the mutation"

ac_kill "armc-mut-bucket" \
  "s@^          \\*'->CLASSIFY'\\*|\\*consumer-edited\\*) ;;\$@          *'BOTH-CHANGED'*) ;;@" \
  'core/git-hooks/pre-push,core/rules/edited.md,' \
  "keying on the modified-both-sides bucket alone drops the deleted, the added and the relocated path"

ac_kill "armc-mut-setf" 's@^    set -f$@    : set -f removed@' \
  'core/git-hooks/pre-push,' \
  "without set -f the pathspecs expand against the CWD and the machinery set collapses to the entries carrying no glob character"

ac_kill "armc-mut-base" '/--with-tree="\$BASE"/d' \
  'core/git-hooks/pre-push,core/rules/edited.md,core/schemas/fresh.json,core/scripts/reloc.sh,' \
  "resolving the globs at THEIRS alone loses the path deleted upstream, where the consumer's copy is the only copy left"

ac_kill "armc-mut-uncond" 's@^          \*) continue ;;$@          *) ;;@' \
  'core/git-hooks/pre-push,core/rules/doomed.md,core/rules/edited.md,core/rules/steady.md,core/schemas/fresh.json,core/scripts/reloc.sh,' \
  "dropping the bucket filter carries a machinery path the consumer never touched"

# THE REMAINING TWO ARE FOR ARMS THAT PASS AGAINST A SUBJECT THAT EMITS NOTHING. Measured, by
# running this fixture against a gate replaced with `exit 0`: carry-quiet-untouched,
# carry-not-machinery, carry-clean-consumer and carry-safe-stop all reported ok. They are
# absence-shaped, so only a mutant on their OWN guard establishes that they discriminate --
# and arm C has THREE independent guards, not one. The bucket filter above reaches the first;
# these reach the other two, and neither is covered by any mutant already here: dropping the
# bucket filter does NOT carry the non-machinery path, and dropping the membership test does
# NOT carry the untouched one.
ac_kill "armc-mut-member" \
  's@^        grep -qxF "\$c_path" <<EOF || continue$@        true <<EOF || continue@' \
  'core/git-hooks/pre-push,core/rules/doomed.md,core/rules/edited.md,core/schemas/fresh.json,core/scripts/reloc.sh,core/skills/ai-dlc/steps/gate-validation.md,' \
  "dropping the machinery-membership test carries a diverged path this gate does not decide"

# Scored under the env var rather than without it, because that IS the guard's subject: the
# arm it backs asserts an absence that only exists inside a --safe-stop walk.
AC_M6="$(ac_mut safestop 's@^if \[ -z "\${AI_DLC_GATE_IN_SAFE_STOP:-}" \]; then$@if true; then@')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$AC_M6"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "armc-mut-safestop"
else
  ac_got6="$( AI_DLC_GATE_IN_SAFE_STOP=1; export AI_DLC_GATE_IN_SAFE_STOP
              ac_carry "$AC_M6" "$AC/cons" "$AC/cwd" )"
  if [ "$ac_got6" = "$AC_ALL" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "armc-mut-safestop" \
      "removing the re-entry guard emits the whole advisory inside a --safe-stop walk"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "armc-mut-safestop" "$ac_got6" "$AC_ALL" \
      "removing the re-entry guard must emit the whole advisory inside a --safe-stop walk"
  fi
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
