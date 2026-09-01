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
SS="$(dirname "$DIST")/ss"; rm -rf "$SS"
mkdir -p "$SS/dist/core/skills/ai-dlc/steps" "$SS/cons/.claude/skills/ai-dlc/steps" "$SS/dist/core/rules"
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
# ONE MACHINERY PATH, NEVER TOUCHED AGAIN, AND IT IS A PRECONDITION RATHER THAN DECORATION. Arm C
# now resolves its population by `eval`ing `machinery_paths()` out of preclassify.sh, and reports
# SELF-UPDATE-UNDECIDED when that set comes back EMPTY -- correctly, since a membership test over
# an empty set rejects every path and its silence is byte-identical to a clean pull. A dist tree
# holding only VERSION and a rulebook file resolves to nothing, so without this file every arm
# below runs against an UNDECIDED verdict it never asked for. Unchanged across all five commits,
# so it enters no base..theirs diff and produces no bucket and no CARRY row of its own.
printf 'ss machinery\n' > "$SS/dist/core/rules/ss.md"
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

# PRECONDITION FOR THE PRECONDITIONS. An empty machinery set makes every classify run here answer
# UNDECIDED, which the two arms below read as "defer" — they would then fail, or worse pass, for a
# reason that has nothing to do with the walk they exist to underwrite.
ss_assert "ss-machinery-set" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | grep -c 'SELF-UPDATE-UNDECIDED')" \
  "0" "the seeded tree resolves a NON-empty machinery set, so no arm below runs against a set-empty UNDECIDED"

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

# --- THE STAMP IS AHEAD AND THE TREE IS PARTIAL, SO THE ACQUITTAL IS WITHHELD -----------------
# Every arm above scores the acquittal on the stamp FIELD alone, which is all
# `machinery_at_or_past` reads -- a `merge-base --is-ancestor` against `skill_commit`. A FIELD
# THAT IS AHEAD IS NOT EVIDENCE THAT THE TREE MATCHING IT IS COMPLETE. `apply.sh` writes
# `.claude/.ai-dlc-applying` at the start of every apply and removes it only on the success path;
# a run that WITHHOLDS the re-stamp writes no stamp at all, leaves that marker deliberately in
# place, and calls the tree partial in as many words. Because such a run writes nothing, a
# `skill_commit` an earlier step 2 advanced survives beside a `commit` still at base -- split
# stamp plus marker on disk -- and in that state the acquittal FIRED on a partial tree.
#
# SCORED BY EFFECT, NOT BY ROW COUNT, AND THE `row=` CONJUNCT IS THE REASON. A gate replaced by
# `exit 0` scores acq=0 wh=0 pf=0, which is most of what the offender arm below wants to see;
# requiring the SAFE-STOP row to EXIST in the same tuple is what stops silence passing for
# discrimination. Measured, by running this fixture against such a gate: with the conjunct the
# three arms below fail, and every other cell of the tuple agrees with a clean run.
ss_marker() { # ss_marker on|off -- the interrupted-apply marker on the seeded consumer
  if [ "$1" = on ]; then : > "$SS/cons/.claude/.ai-dlc-applying"
  else rm -f "$SS/cons/.claude/.ai-dlc-applying"; fi
}
# ss_ack <gate> <theirs> -> "row=<0|1> acq=<n> wh=<n> pf=<n>" off the SAFE-STOP row's DETAIL.
#
# `pf` KEYS ON "its slice self-updates cleanly", NOT ON "pull to ... FIRST". The withheld wording
# opens with that same phrase on purpose -- it is still telling the operator to pull first -- so
# the shorter token cannot separate the withheld row from the untouched one and arm C, whose
# whole job is that separation, would have passed against a guard sited anywhere.
ss_ack() {
  local d
  d="$(bash "$1" "$SS/dist" "$SS_BASE" "$2" "$SS/cons" 2>&1 |
         awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $3; exit}')"
  printf 'row=%s acq=%s wh=%s pf=%s\n' \
    "$([ -n "$d" ] && printf 1 || printf 0)" \
    "$(printf '%s' "$d" | grep -c 'SPLIT BUYS NOTHING')" \
    "$(printf '%s' "$d" | grep -c 'ACQUITTAL IS WITHHELD')" \
    "$(printf '%s' "$d" | grep -c 'its slice self-updates cleanly')"
}

# A -- OFFENDER. `skill_commit` at r1, which is at-or-past the ref the walk names, and the
# interrupted-apply marker on disk.
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-A" "$(ss_ack "$GATE" "$SS_R2")" "row=1 acq=0 wh=1 pf=0" \
  "stamp ahead + .ai-dlc-applying on disk: the acquittal is replaced by the withheld row"

# B -- NEAR-MISS, IN THE SAME RUN AND ONE PROPERTY APART. Same stamp, marker removed. Without
# this the guard could be refusing blanket and A would read identically.
ss_marker off
ss_assert "ss-partial-B" "$(ss_ack "$GATE" "$SS_R2")" "row=1 acq=1 wh=0 pf=0" \
  "stamp ahead with no marker: the acquittal is untouched, so the guard reads the marker"

# C -- THE NEAR-MISS THAT SITES THE GUARD. Marker on disk, but `skill_commit` BEHIND the ref the
# walk names for r4, so `machinery_at_or_past` is false and the acquittal branch is never
# entered. A guard sited ABOVE that branch -- refusing on the marker alone -- would replace this
# pull-first row too, and A and B together cannot tell the two sitings apart.
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-C" "$(ss_ack "$GATE" "$SS_R4")" "row=1 acq=0 wh=0 pf=1" \
  "marker on disk but stamp BEHIND: the original pull-first advice stands, so the guard is INSIDE the acquittal branch"

# --- MUTANT: REMOVE THE MARKER GUARD -----------------------------------------------------
# ss-partial-A is ABSENCE-shaped on the acquittal token, and that is the shape that survives a
# subject which never ran. The `row=` conjunct blocks the silent case; only a mutant establishes
# that the arm discriminates at all.
#
# THE COPY NEEDS ITS SIBLINGS. `machinery_paths()` resolves `$(dirname "$0")/setup-sites.md`, so
# a lone gate in a bare directory gets an EMPTY machinery set, answers UNDECIDED with no
# SAFE-STOP row, and every mutant would score as killed off a harness failure rather than a
# mutation.
SSM="$(dirname "$DIST")/ssmut"
rm -rf "$SSM"; mkdir -p "$SSM/mut" "$SSM/ctl"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$SSM/mut"/ 2>/dev/null
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$SSM/ctl"/ 2>/dev/null

# ONE STRING SERVES THE GREP AND THE SED, so the uniqueness proved below is a property of the
# expression that actually mutates. Written apart they drift, and the arm then proves that some
# OTHER expression is unique.
SS_ANCHOR='^      if \[ -f "\$CONSUMER/\.claude/\.ai-dlc-applying" \]; then$'
ss_assert "ss-partial-anchor" "$(grep -c "$SS_ANCHOR" "$GATE")" "1" \
  "the mutation's anchor matches exactly ONE line, so the sed below cannot move a second cell"
# CONTROL, and it is what makes the 1 above mean something: a grammar that cannot spell its own
# subject returns 0 on the real anchor too, and a 1 with no 0 beside it does not separate the two.
ss_assert "ss-partial-anchor-ctl" \
  "$(grep -c '^      if \[ -f "\$CONSUMER/\.claude/\.ai-dlc-NOT-A-MARKER" \]; then$' "$GATE")" "0" \
  "an impossible anchor of the SAME shape returns 0, so the match above is a match and not a grammar artefact"

# THE UNMUTATED CONTROL, PRESENCE-SHAPED ON PURPOSE. It runs before the mutant and demands the
# withheld row from a plain copy: a copy that dies sourcing its siblings emits nothing, and
# "nothing" is what the mutant is expected to stop producing. An rc-and-no-error control would
# pass against `exit 0` here.
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-control" "$(ss_ack "$SSM/ctl/self-update-gate.sh" "$SS_R2")" \
  "row=1 acq=0 wh=1 pf=0" \
  "an UNMUTATED copy beside its siblings reproduces the withheld row, so a mutant's shift is the mutation"

sed "s@${SS_ANCHOR}@      if false; then@" "$GATE" > "$SSM/mut/self-update-gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$SSM/mut/self-update-gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "ss-partial-mut"
else
  ss_stamp "$SS_R1"; ss_marker on
  ssm_got="$(ss_ack "$SSM/mut/self-update-gate.sh" "$SS_R2")"
  if [ "$ssm_got" = "row=1 acq=1 wh=0 pf=0" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "ss-partial-mut" \
      "with the marker guard gone the acquittal returns on the partial tree and the withheld row disappears"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]\n' "ss-partial-mut" "$ssm_got" "row=1 acq=1 wh=0 pf=0"
  fi
fi

# THE MUTANT MOVES ONE CELL AND NO OTHER, which is how ss-partial-A is shown to OWN the case
# rather than sharing it. Two arms moving under one mutation means one of them is vacuous.
ss_marker off
ss_assert "ss-partial-mut-B" "$(ss_ack "$SSM/mut/self-update-gate.sh" "$SS_R2")" \
  "row=1 acq=1 wh=0 pf=0" "the mutant leaves B where it was -- B never entered the guard"
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-mut-C" "$(ss_ack "$SSM/mut/self-update-gate.sh" "$SS_R4")" \
  "row=1 acq=0 wh=0 pf=1" "and C where it was -- C never reaches the acquittal branch at all"

ss_marker off
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

# THE NEXT TWO MUTATE preclassify.sh, NOT THE GATE, AND THAT IS WHERE THEIR SUBJECT MOVED. This
# arm's population used to be resolved inline here; it is now `machinery_paths()`, eval'd out of
# preclassify.sh so that one derivation serves both the CARRY population and the `skill_commit`
# suppression scope. A mutant aimed at the gate's old inline copy matches nothing today, which
# reads as a broken fixture rather than as the relocation it is — and mutating the file the run
# actually RESOLVES is the whole point.
ac_mut_pre() { # ac_mut_pre <name> <sed-expr on preclassify.sh> -> path to a GATE beside it
  local d="$AC/mp-$1"
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$d"/ 2>/dev/null
  sed "$2" "$(dirname "$GATE")/preclassify.sh" > "$d/preclassify.sh"
  printf '%s\n' "$d"
}
ac_kill_pre() { # ac_kill_pre <label> <sed-expr> <want-carry-set> <why>
  local d got
  d="$(ac_mut_pre "$1" "$2")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$(dirname "$GATE")/preclassify.sh" "$d/preclassify.sh"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing in preclassify.sh, so the arm it scores is unproven\n' "$1"
    return
  fi
  got="$(ac_carry "$d/self-update-gate.sh" "$AC/cons" "$AC/cwd")"
  if [ "$got" = "$3" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$4"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$3" "$4"
  fi
}

ac_kill_pre "armc-mut-setf" 's@^  set -f$@  : set -f removed@' \
  'core/git-hooks/pre-push,' \
  "without set -f the pathspecs expand against the CWD and the machinery set collapses to the entries carrying no glob character"

ac_kill_pre "armc-mut-base" '/--with-tree="\$BASE"/d' \
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

# --- ARM D: THE THIRD SHA. A SPLIT PULL LEAVES THE CONSUMER AT A REF NEITHER ENDPOINT KNOWS --
#
# Arm C above reads preclassify's buckets and carries every machinery path that shows a consumer
# divergence. That is correct only if the bucket derivation can TELL a divergence from a carry.
# It could not. Every `ours_h` comparison in preclassify's M and A branches measured the consumer
# against `base` and `theirs` alone, and on a SPLIT pull step 2's autonomous self-update has
# already rewritten the machinery set from an INTERMEDIATE ref -- so the consumer's copy is
# byte-identical to the distribution at a THIRD sha, the stamp's `skill_commit`, and against that
# pair it reads as a consumer edit. The path fell to a `->CLASSIFY` bucket, arm C carried it, and
# `apply.sh`'s own `*CLASSIFY*` arm -- which never invokes this gate -- turned it into a
# `WORKLIST semantic-merge` row that WITHHELD the re-stamp. Filed by the reference consumer as
# `PC-S307-SELF-UPDATE-CARRY-ARM-HAS-NO-CORE-AT-SELF-UPDATE-SUPPRESSION`.
#
# THE SUBJECT IS preclassify.sh AND ARM C IS THE READER, which is why these arms live here rather
# than in a new directory: this fixture is the only one that drives both halves of that join in
# one run, and the assertion that matters is that arm C goes QUIET without a line of its own
# changing behaviour.
#
# THE PREDICATE IS `at_self_update`, NOT AN `elif`, and the mutants below are keyed on the
# function for that reason. It has THREE conjuncts and each is a separate way to be wrong:
# a self-update ref exists, the consumer's bytes match the distribution AT that ref, and the path
# is in the MACHINERY set -- the only set step 2's self-update writes. Two branch arms call it.
#
# ITS OWN MINIATURE DISTRIBUTION, WITH THREE REFS. Every tree above has exactly two, and a two-ref
# tree cannot express the defect at all -- the third sha IS the bug.
#
#   core/rules/carried.md    M  ours == dist@MID, differs at BASE and THEIRS  -> UPSTREAM-ONLY
#   core/rules/added.md      A  absent at BASE, ours == dist@MID              -> UPSTREAM-ONLY-ADD
#   core/rules/edited.md     M  ours matches NOTHING -- a real consumer edit   -> ->CLASSIFY
#   core/rules/steady.md     M  ours == BASE                                  -> UPSTREAM-ONLY
#   core/rules/indexed.md    M  ours == the dist repo INDEX and no ref         -> ->CLASSIFY
#   core/rules/doomed.md     D  deleted at THEIRS, ours == dist@MID           -> ->CLASSIFY
#   core/skills/ai-dlc/artifact-path-grammar.md
#                            M  ours == dist@MID but NOT machinery            -> ->CLASSIFY
#   core/session-driver/modeflip.sh  content fixed, 644->755, consumer HAS the bit -> ALREADY-AT-THEIRS
#   core/session-driver/modeneed.sh  same, consumer LACKS the bit                  -> UPSTREAM-ONLY
#
# THE NEGATIVES SIT IN THE SAME TREE AND THE SAME RUN AS THE POSITIVES, and there are three of
# them, each differing from a real carry in exactly ONE respect. `edited.md` differs in the BYTES.
# `artifact-path-grammar.md` differs only in MEMBERSHIP -- same status, same three-way hash
# relation, byte-identical to the distribution at the same ref, and not machinery. `doomed.md`
# differs only in STATUS. A near-miss run separately is an ADJACENT input: it can only ask whether
# the arm fires, never whether it fires on the RIGHT paths, and this repo has shipped that mistake
# and paid three rounds for it. Every arm scores one EXACT bucket set, so a mutant that widens the
# predicate cannot pass by satisfying the positives alone.
#
# `artifact-path-grammar.md` IS THE SCOPING SUBJECT AND NOTHING ELSE REACHES IT. Unscoped, a
# non-machinery core file at an intermediate ref is reclassified to UPSTREAM-ONLY and `apply.sh`
# writes theirs over it with no operator review -- an exemption with no reason attached, since
# only the machinery set has a story for how it got to that ref. Every OTHER seeded path here is
# machinery, so dropping the `is_machinery` conjunct moves this cell and no other.
#
# `doomed.md` CARRIES THE DELIBERATE ABSENCE. There is no `D`-branch arm, measured rather than
# forgotten, and its verdict must stay `UPSTREAM-DELETED+consumer-modified->CLASSIFY`. Asserting
# it here means a D-branch arm added later cannot land silently.
#
# `indexed.md` IS THE INDEX HAZARD'S SUBJECT AND IT EXISTS FOR NOTHING ELSE. `self_update_hash`
# returns a sentinel rather than calling `blob_hash ""` because an empty rev makes the underlying
# `git rev-parse -q --verify ":<path>"` read the dist repo's INDEX, which resolves for every
# tracked path. The seed stages a content for that path that is committed at NO ref and gives the
# consumer the same bytes -- so a build that drops the sentinel matches on it and NOTHING ELSE
# does. Without that staged blob the hazard is unreachable: a clean index answers with THEIRS,
# which an earlier arm has already claimed.
#
# `modeflip.sh` IS THE ORDERING SUBJECT. All three content hashes are equal there, so the
# predicate holds -- and `ALREADY-AT-THEIRS`, which carries the `mode_at_theirs` conjunct, is the
# only arm that can tell a consumer holding the exec bit from one that still needs it. Moving the
# new arm above it answers UPSTREAM-ONLY for both, which is the regression the shipped comment
# warns about and which no other seeded path can see.
SU="$(dirname "$DIST")/su"
rm -rf "$SU"
mkdir -p "$SU/dist/core/rules" "$SU/dist/core/session-driver" "$SU/dist/core/skills/ai-dlc" \
         "$SU/cons/.claude/rules" "$SU/cons/.claude/session-driver" "$SU/cons/.claude/skills/ai-dlc" "$SU/cons/.githooks" \
         "$SU/nostamp/.claude/rules" "$SU/nostamp/.claude/session-driver" "$SU/nostamp/.claude/skills/ai-dlc" "$SU/nostamp/.githooks"

# A probe repo is only a probe if git agrees. `GIT_DIR` outranks `git -C`, so an exported one
# would send every write below into whatever repository the caller was standing in.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
git -C "$SU/dist" init -q
# Compared PHYSICALLY on both sides. `$TMPDIR` carries a trailing slash and macOS resolves it
# through /private, so a textual compare here fails on a probe that is perfectly isolated -- which
# would be an arm that fires on the state it exists to bless.
ss_assert "su-probe-isolated" "$(git -C "$SU/dist" rev-parse --absolute-git-dir 2>/dev/null)" \
  "$( cd "$SU/dist" && pwd -P )/.git" \
  "the probe repo is its own, so nothing below can reach the caller's repository"

su_commit() { git -C "$SU/dist" add -A >/dev/null 2>&1
              git -C "$SU/dist" -c user.email=f@x -c user.name=f commit -qm "$1" >/dev/null 2>&1
              git -C "$SU/dist" rev-parse HEAD; }

printf '0.1.0\n'        > "$SU/dist/VERSION"
printf 'carried base\n' > "$SU/dist/core/rules/carried.md"
printf 'edited base\n'  > "$SU/dist/core/rules/edited.md"
printf 'steady base\n'  > "$SU/dist/core/rules/steady.md"
printf 'indexed base\n' > "$SU/dist/core/rules/indexed.md"
printf 'doomed base\n'  > "$SU/dist/core/rules/doomed.md"
printf 'grammar base\n' > "$SU/dist/core/skills/ai-dlc/artifact-path-grammar.md"
printf 'driver body\n'  > "$SU/dist/core/session-driver/modeflip.sh"
printf 'driver body\n'  > "$SU/dist/core/session-driver/modeneed.sh"
chmod 644 "$SU/dist/core/session-driver/modeflip.sh" "$SU/dist/core/session-driver/modeneed.sh"
SU_BASE="$(su_commit base)"

# MID -- the ref step 2's autonomous self-update wrote the machinery set from. A release commit,
# because a VERSION is the only state a stamp can record. `added.md` is born here, which is what
# puts it in the `A` branch with no `base_h` arm able to catch it.
printf '0.2.0\n'        > "$SU/dist/VERSION"
printf 'carried mid\n'  > "$SU/dist/core/rules/carried.md"
printf 'edited mid\n'   > "$SU/dist/core/rules/edited.md"
printf 'steady mid\n'   > "$SU/dist/core/rules/steady.md"
printf 'indexed mid\n'  > "$SU/dist/core/rules/indexed.md"
printf 'doomed mid\n'   > "$SU/dist/core/rules/doomed.md"
printf 'added mid\n'    > "$SU/dist/core/rules/added.md"
printf 'grammar mid\n'  > "$SU/dist/core/skills/ai-dlc/artifact-path-grammar.md"
chmod 755 "$SU/dist/core/session-driver/modeflip.sh" "$SU/dist/core/session-driver/modeneed.sh"
SU_MID="$(su_commit mid)"

printf '0.3.0\n'          > "$SU/dist/VERSION"
printf 'carried theirs\n' > "$SU/dist/core/rules/carried.md"
printf 'edited theirs\n'  > "$SU/dist/core/rules/edited.md"
printf 'steady theirs\n'  > "$SU/dist/core/rules/steady.md"
printf 'indexed theirs\n' > "$SU/dist/core/rules/indexed.md"
printf 'added theirs\n'   > "$SU/dist/core/rules/added.md"
printf 'grammar theirs\n' > "$SU/dist/core/skills/ai-dlc/artifact-path-grammar.md"
rm -f "$SU/dist/core/rules/doomed.md"
SU_THEIRS="$(su_commit theirs)"

# Committed at no ref, present only in the index. See `indexed.md` above.
printf 'indexed STAGED\n' > "$SU/dist/core/rules/indexed.md"
git -C "$SU/dist" add core/rules/indexed.md >/dev/null 2>&1

# A TREE sha resolves as an OBJECT and not as a COMMIT, and `<tree>:<path>` resolves a blob
# perfectly well -- so it is the input that separates the shipped `^{commit}` guard from its
# absence. An all-zeros sha cannot do that job: `blob_hash` answers MISSING for it either way.
SU_TREE="$(git -C "$SU/dist" rev-parse "${SU_MID}^{tree}")"

# Writes NO stamp. `$SU/nostamp` is this tree with nothing else done to it, and `$SU/cons` gets
# whichever stamp the arm under test needs; the two are byte-identical apart from that one file,
# so the gate differential below is the stamp read and nothing else.
su_seed_cons() {
  printf 'carried mid\n'       > "$1/.claude/rules/carried.md"
  printf 'edited LOCAL EDIT\n' > "$1/.claude/rules/edited.md"
  printf 'steady base\n'       > "$1/.claude/rules/steady.md"
  printf 'indexed STAGED\n'    > "$1/.claude/rules/indexed.md"
  printf 'added mid\n'         > "$1/.claude/rules/added.md"
  printf 'doomed mid\n'        > "$1/.claude/rules/doomed.md"
  printf 'grammar mid\n'       > "$1/.claude/skills/ai-dlc/artifact-path-grammar.md"
  printf 'driver body\n' > "$1/.claude/session-driver/modeflip.sh"; chmod 755 "$1/.claude/session-driver/modeflip.sh"
  printf 'driver body\n' > "$1/.claude/session-driver/modeneed.sh"; chmod 644 "$1/.claude/session-driver/modeneed.sh"
  printf '#!/usr/bin/env bash\n# invokes no scripts/ai-dlc/ validator, so the gating set is empty\nexit 0\n' \
    > "$1/.githooks/pre-push"; chmod 755 "$1/.githooks/pre-push"
}
su_seed_cons "$SU/cons"
su_seed_cons "$SU/nostamp"

su_stamp() { # su_stamp <skill_commit> ; `-` removes the stamp, `+` writes one with no such field
  case "$1" in
    -) rm -f "$SU/cons/.claude/.ai-dlc-version" ;;
    +) printf 'version: 0.1.0\ncommit: %s\nskill_version: 0.2.0\n' "$SU_BASE" \
         > "$SU/cons/.claude/.ai-dlc-version" ;;
    *) printf 'version: 0.1.0\ncommit: %s\nskill_version: 0.2.0\nskill_commit: %s\n' "$SU_BASE" "$1" \
         > "$SU/cons/.claude/.ai-dlc-version" ;;
  esac
}

SU_PC="$(dirname "$GATE")/preclassify.sh"
su_buckets() { # su_buckets <preclassify> <consumer> -> "<core-path>=<bucket>," sorted
  bash "$1" "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$2" 2>/dev/null |
    awk -F'\t' '$2 ~ /^core\// {print $2 "=" $4}' | sort | tr '\n' ','
}

# Composed cell by cell rather than written out eight times: every expectation below differs from
# SU_LIVE in one or two cells, and spelling each set in full hides which cell a mutant moved.
SU_A_ADD='core/rules/added.md=UPSTREAM-ONLY-ADD,'
SU_A_CL='core/rules/added.md=BOTH-ADDED->CLASSIFY,'
SU_CA_UO='core/rules/carried.md=UPSTREAM-ONLY,'
SU_CA_CL='core/rules/carried.md=BOTH-CHANGED->CLASSIFY,'
SU_DO='core/rules/doomed.md=UPSTREAM-DELETED+consumer-modified->CLASSIFY,'
SU_ED_CL='core/rules/edited.md=BOTH-CHANGED->CLASSIFY,'
SU_ED_UO='core/rules/edited.md=UPSTREAM-ONLY,'
SU_IX_CL='core/rules/indexed.md=BOTH-CHANGED->CLASSIFY,'
SU_IX_UO='core/rules/indexed.md=UPSTREAM-ONLY,'
SU_ST='core/rules/steady.md=UPSTREAM-ONLY,'
SU_MF_OK='core/session-driver/modeflip.sh=ALREADY-AT-THEIRS,'
SU_MF_UO='core/session-driver/modeflip.sh=UPSTREAM-ONLY,'
SU_MN='core/session-driver/modeneed.sh=UPSTREAM-ONLY,'
SU_GR_CL='core/skills/ai-dlc/artifact-path-grammar.md=BOTH-CHANGED->CLASSIFY,'
SU_GR_UO='core/skills/ai-dlc/artifact-path-grammar.md=UPSTREAM-ONLY,'
SU_TAIL="${SU_DO}${SU_ED_CL}${SU_IX_CL}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_CL}"
SU_LIVE="${SU_A_ADD}${SU_CA_UO}${SU_TAIL}"                       # both branch arms reach their subject
SU_INERT="${SU_A_CL}${SU_CA_CL}${SU_TAIL}"                       # the predicate is unreachable
SU_NO_M="${SU_A_ADD}${SU_CA_CL}${SU_TAIL}"                       # the M-branch arm is gone
SU_NO_A="${SU_A_CL}${SU_CA_UO}${SU_TAIL}"                        # the A-branch arm is gone
SU_WIDE="${SU_A_ADD}${SU_CA_UO}${SU_DO}${SU_ED_UO}${SU_IX_UO}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_CL}"
SU_UNSCOPED="${SU_A_ADD}${SU_CA_UO}${SU_DO}${SU_ED_CL}${SU_IX_CL}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_UO}"
SU_ORDER="${SU_A_ADD}${SU_CA_UO}${SU_DO}${SU_ED_CL}${SU_IX_CL}${SU_ST}${SU_MF_UO}${SU_MN}${SU_GR_CL}"
SU_IDXH="${SU_A_CL}${SU_CA_CL}${SU_DO}${SU_ED_CL}${SU_IX_UO}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_CL}"

# PRECONDITION. The mode seed is the whole subject of the ordering mutant, and git records a mode
# only if the filesystem carried one -- a tree where both refs read 100644 makes that mutant
# unkillable and reads exactly like a mutant that was scored.
ss_assert "su-seed-mode" \
  "$(git -C "$SU/dist" ls-tree "$SU_BASE" -- core/session-driver/modeflip.sh | cut -d' ' -f1)->$(git -C "$SU/dist" ls-tree "$SU_THEIRS" -- core/session-driver/modeflip.sh | cut -d' ' -f1)" \
  "100644->100755" "the seeded mode really flips base->theirs, so ALREADY-AT-THEIRS has a subject"

# PRECONDITION. The staged blob is the index hazard's only subject, and a `git add` that silently
# did nothing would leave the index answering THEIRS -- a value an earlier arm already claims.
ss_assert "su-seed-index" \
  "$(git -C "$SU/dist" rev-parse -q --verify ':core/rules/indexed.md')" \
  "$(git -C "$SU/dist" hash-object "$SU/cons/.claude/rules/indexed.md")" \
  "the dist INDEX holds the consumer's bytes for indexed.md at no ref at all"
ss_assert "su-seed-index-control" \
  "$(git -C "$SU/dist" rev-parse -q --verify ":core/rules/indexed.md" 2>/dev/null | grep -cx "$(git -C "$SU/dist" rev-parse "${SU_THEIRS}:core/rules/indexed.md")")" \
  "0" "...and it is NOT the blob at theirs, so a match on it can only have come from the index"

# PRECONDITION FOR THE SCOPING NEGATIVE. `artifact-path-grammar.md` separates the shipped arm from
# an unscoped one ONLY if it is genuinely outside the machinery set while every other seeded path
# is inside it. Both halves are derived from the shipped function rather than read off the
# manifest by eye, and both are asserted, because an arm that named a machinery path by mistake
# would score the unscoped mutant as surviving and read as a coverage gap.
#
# LOADED THE WAY THE GATE LOADS IT, out of a directory holding preclassify's siblings, and NOT by
# eval-ing into this shell. `machinery_paths()` resolves its manifest as `$(dirname "$0")/…`, and
# `$0` is not assignable — an eval here reads THIS fixture's directory, finds no setup-sites.md,
# returns EMPTY, and both arms below then score a zero that means nothing. Measured: the first cut
# did exactly that, and only the control arm caught it.
mkdir -p "$SU/mach"
cp "$(dirname "$SU_PC")"/*.sh "$(dirname "$SU_PC")"/*.md "$SU/mach"/ 2>/dev/null
cat > "$SU/mach/list-machinery.sh" <<'MACHEOF'
DIST="$1"; BASE="$2"; THEIRS="$3"
eval "$(awk '/^machinery_paths\(\) \{/,/^\}/' "$(dirname "$0")/preclassify.sh")"
machinery_paths
MACHEOF
SU_MACH="$(bash "$SU/mach/list-machinery.sh" "$SU/dist" "$SU_BASE" "$SU_THEIRS" 2>/dev/null)"
ss_assert "su-seed-scope" \
  "$(printf '%s\n' "$SU_MACH" | grep -cx 'core/skills/ai-dlc/artifact-path-grammar.md')" "0" \
  "the scoping near-miss is NOT machinery, so only the is_machinery conjunct can separate it"
ss_assert "su-seed-scope-control" \
  "$(printf '%s\n' "$SU_MACH" | grep -cx 'core/rules/carried.md')" "1" \
  "...and the carried path IS, so that zero is a membership decision rather than an empty set"

# THE POSITIVES AND THEIR THREE NEGATIVES, ONE EXACT SET, ONE RUN. Both branch arms, the D-branch
# deliberate absence, the bytes near-miss and the membership near-miss are all in this one cell
# comparison.
su_stamp "$SU_MID"
ss_assert "su-carried" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_LIVE" \
  "M and A both suppress a copy identical to the distribution at the stamp's skill_commit, while a real edit, a non-machinery path and a deleted path in the same tree all still reach ->CLASSIFY"

# THE THREE GUARDS ON THE STAMP READ, EACH WITH ITS OWN SUBJECT. In every one of them the arms must
# be unreachable and every OTHER bucket unchanged -- which is why the whole set is asserted rather
# than the two cells. A guard that also moved `steady.md` or `modeflip.sh` would be a regression
# wearing the shape of a fix.
ss_assert "su-guard-nostamp" "$(su_buckets "$SU_PC" "$SU/nostamp")" "$SU_INERT" \
  "no stamp at all: nothing to read, so both arms are inert and every other bucket is untouched"
su_stamp +
ss_assert "su-guard-nofield" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_INERT" \
  "a stamp with no skill_commit field -- the ordinary pre-split shape -- is inert too"
su_stamp "$SU_BASE"
ss_assert "su-guard-eqbase" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_INERT" \
  "skill_commit == commit: no self-update hop ran, so the question collapses into the base_h arm"
su_stamp "$SU_TREE"
ss_assert "su-guard-unresolvable" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_INERT" \
  "a skill_commit this distribution cannot resolve to a COMMIT compares against nothing"

# --- MUTANTS on the preclassify predicate ---------------------------------------------
#
# THE COPY NEEDS ITS SIBLINGS, for the same reason arm C's battery does: preclassify resolves
# setup-sites.md by `dirname "$0"` in TWO places -- the setup-substitution list and
# `machinery_paths()` -- and a lone copy in a bare directory derives an empty machinery set, which
# makes every arm inert and scores every mutant as killed. Mutated with awk rather than sed
# because two of these REORDER or REWRITE a block, which sed cannot express portably, and a
# battery whose mutants are written two ways is a battery with two things to review.
#
# EACH IS SCORED ON ITS EXACT BUCKET SET AND THE SEVEN SETS ARE DISTINCT. Two mutants producing
# the same output are one mutant, and every seed above earns its place by separating one pair.
su_mut() { # su_mut <name> <awk-program> -> path to the mutated preclassify, siblings beside it
  local d="$SU/m-$1"
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$SU_PC")"/*.sh "$(dirname "$SU_PC")"/*.md "$d"/ 2>/dev/null
  awk "$2" "$SU_PC" > "$d/preclassify.sh" 2>/dev/null
  printf '%s\n' "$d/preclassify.sh"
}
su_kill() { # su_kill <label> <awk> <stamp> <want-set> <why>
  local g got
  g="$(su_mut "$1" "$2")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$SU_PC" "$g"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "$1"
    return
  fi
  su_stamp "$3"
  got="$(su_buckets "$g" "$SU/cons")"
  if [ "$got" = "$4" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$5"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$4" "$5"
  fi
}

# The two branch call sites open with byte-identical text and differ only in the bucket they
# assign, so each mutation is anchored on the BUCKET, never on the shared condition. Anchoring on
# `at_self_update` alone edits both, moves two cells, and scores a kill neither arm earned.
SU_M_NOARM_M='index($0,"at_self_update \"$path\" \"$ours_h\"") && index($0,"bucket=\"UPSTREAM-ONLY\"") { next } { print }'
SU_M_NOARM_A='index($0,"at_self_update \"$path\" \"$ours_h\"") && index($0,"bucket=\"UPSTREAM-ONLY-ADD\"") { next } { print }'
SU_M_WIDE='index($0,"[ \"$2\" = \"$(self_update_hash \"$1\")\" ] || return 1") { next } { print }'
SU_M_UNSCOPED='{ if (index($0,"at_self_update() {")) inf=1
  if (inf && index($0,"  is_machinery \"$1\"")) { print "  return 0"; inf=0; next } print }'
SU_M_ORDER='{ L[NR]=$0
  if (index($0,"at_self_update \"$path\" \"$ours_h\"") && index($0,"bucket=\"UPSTREAM-ONLY\"")) A=NR
  if (index($0,"ALREADY-AT-THEIRS") && index($0,"mode_at_theirs")) B=NR }
END { if (!A || !B) exit 1
  for (i=1;i<=NR;i++) { if (i==A) continue; if (i==B) print L[A]; print L[i] } }'
SU_M_UNRES='{ if (index($0,"if [ -n \"$SELF_UPDATE_REF\" ] \\")) d=4; if (d>0) { d--; next } print }'
SU_M_EQBASE='index($0,"= \"$BASE\" ] && SELF_UPDATE_REF=") { next } { print }'
# THE SENTINEL IS THE THIRD LAYER, so a mutant that removes it ALONE changes nothing and would
# score as a survivor. Two guards above it already refuse an empty ref -- `at_self_update`'s own
# first conjunct, and the fact that MACHINERY_PATHS is only populated when a ref exists, which
# makes `is_machinery` reject everything. Both layers are stripped in the pair below; the first
# keeps the sentinel and the second does not, so the difference between them is the sentinel and
# nothing else.
SU_M_LAYERS='index($0,"[ -n \"$SELF_UPDATE_REF\" ] && MACHINERY_PATHS=") { print "MACHINERY_PATHS=\"$(machinery_paths)\""; next }
index($0,"at_self_update() {") { print; getline; next }
{ print }'
SU_M_INDEX='index($0,"[ -n \"$SELF_UPDATE_REF\" ] && MACHINERY_PATHS=") { print "MACHINERY_PATHS=\"$(machinery_paths)\""; next }
index($0,"at_self_update() {") { print; getline; next }
index($0,"NO-SELF-UPDATE-REF") { next }
{ print }'
# THE SECOND SPELLING OF THE CORRECT PREDICATE, and it must PASS every arm above. A fixture that
# rejects a competent author's other phrasing is as broken as one that accepts a regression: it
# turns the next repair into a fixture edit and the author into someone who edits fixtures to go
# green. This one streams the blob and hashes stdin instead of comparing two recorded blob shas,
# and it orders its conjuncts the other way round.
SU_M_SPELL='index($0,"at_self_update() {") {
  print "at_self_update() { # <core-rel-path> <ours-hash>"
  print "  [ -n \"$SELF_UPDATE_REF\" ] || return 1"
  print "  is_machinery \"$1\" || return 1"
  print "  git -C \"$DIST\" show \"${SELF_UPDATE_REF}:$1\" 2>/dev/null | git -C \"$DIST\" hash-object --stdin | grep -qxF \"$2\""
  print "}"
  s=4; next }
s>0 { s--; next }
{ print }'

# THE UNMUTATED CONTROL, and it is PRESENCE-shaped: a copy that cannot resolve its siblings, or
# one replaced by `exit 0`, emits the EMPTY set and fails this outright. An arm asserting "nothing
# went wrong" would pass for both.
rm -rf "$SU/m-control"; mkdir -p "$SU/m-control"
cp "$(dirname "$SU_PC")"/*.sh "$(dirname "$SU_PC")"/*.md "$SU/m-control"/ 2>/dev/null
su_stamp "$SU_MID"
ss_assert "su-mut-control" "$(su_buckets "$SU/m-control/preclassify.sh" "$SU/cons")" "$SU_LIVE" \
  "an unmutated copy beside its siblings reproduces the FULL live set, so a mutant's shift is the mutation"

su_kill "su-mut-noarm-m" "$SU_M_NOARM_M" "$SU_MID" "$SU_NO_M" \
  "deleting the M-branch arm sends the carried path back to the semantic-merge obligation that was filed, and touches the added path not at all"
su_kill "su-mut-noarm-a" "$SU_M_NOARM_A" "$SU_MID" "$SU_NO_A" \
  "and deleting the A-branch arm reaches the file BORN at the intermediate ref, which no base_h arm can catch"
su_kill "su-mut-wide" "$SU_M_WIDE" "$SU_MID" "$SU_WIDE" \
  "a predicate that stops comparing BYTES swallows the genuine consumer edit beside it -- the negative is what catches this"
su_kill "su-mut-unscoped" "$SU_M_UNSCOPED" "$SU_MID" "$SU_UNSCOPED" \
  "dropping the is_machinery conjunct suppresses a NON-machinery path, which apply.sh then overwrites with no operator review"
su_kill "su-mut-order" "$SU_M_ORDER" "$SU_MID" "$SU_ORDER" \
  "moved above ALREADY-AT-THEIRS the arm pre-empts the mode conjunct and calls a consumer that HAS the bit indistinguishable from one that needs it"
su_kill "su-mut-unresolvable" "$SU_M_UNRES" "$SU_TREE" "$SU_LIVE" \
  "without the ^{commit} guard a stamp naming a TREE resolves blobs and BOTH arms fire on a ref that means nothing"
su_kill "su-mut-index" "$SU_M_INDEX" "-" "$SU_IDXH" \
  "with its two upper layers stripped, dropping the sentinel makes an empty rev read the dist repo INDEX, which resolves for every tracked path"

# THE OTHER HALF OF THAT PAIR, AND IT IS WHAT MAKES THE KILL ABOVE ATTRIBUTABLE. Same two layers
# stripped, sentinel INTACT: the index is not read and nothing moves. Without this arm the kill
# above could be crediting the sentinel for a change either of the other two guards produced.
SU_G_LAYERS="$(su_mut su-layers "$SU_M_LAYERS")"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_LAYERS"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the sentinel kill above is unattributed\n' "su-mut-layers"
else
  su_stamp -
  su_layers_got="$(su_buckets "$SU_G_LAYERS" "$SU/nostamp")"
  if [ "$su_layers_got" = "$SU_INERT" ]; then
    printf '  ok    %-16s HELD (the sentinel alone stops the index read once both layers above it are gone)\n' "su-mut-layers"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s got=[%s] want=[%s] -- the layers mutant moved a bucket on its own, so su-mut-index credits the sentinel for something else\n' \
      "su-mut-layers" "$su_layers_got" "$SU_INERT"
  fi
fi

# NOT A KILL, AND SAYING SO IS THE POINT. `skill_commit == commit` clears the ref, and with it left
# in place `self_update_hash` returns `base_h` -- which the `ours_h = base_h` arm ABOVE has already
# claimed, so no bucket can move. Measured across all four stamp states rather than reasoned: the
# guard is a COST and a clarity guard with no behavioural subject, and an arm claiming to kill it
# would be scoring the states either side of it. What IS asserted is su-guard-eqbase above.
SU_G_EQBASE="$(su_mut su-eqbase "$SU_M_EQBASE")"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_EQBASE"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the inertness below is unproven\n' "su-mut-eqbase"
else
  su_stamp "$SU_BASE"
  su_eq_got="$(su_buckets "$SU_G_EQBASE" "$SU/cons")"
  if [ "$su_eq_got" = "$SU_INERT" ]; then
    printf '  ok    %-16s INERT BY CONSTRUCTION (the base_h arm above already claims every state it could reach)\n' "su-mut-eqbase"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s got=[%s] want=[%s] -- removing the equality guard MOVED a bucket, so it has a subject after all and needs an arm\n' \
      "su-mut-eqbase" "$su_eq_got" "$SU_INERT"
  fi
fi

# NOT SCORED THROUGH su_kill, because it is not a kill: this build must AGREE with the shipped one
# everywhere, and a helper that prints KILLED on agreement would read as its opposite.
SU_G_SPELL="$(su_mut su-spelling "$SU_M_SPELL")"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_SPELL"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s the re-spelling matched nothing, so the two arms below compare the shipped file with itself\n' "su-spelling"
else
  printf '  ok    %-16s the alternative spelling really is a different file\n' "su-spelling"
fi
su_stamp "$SU_MID"
ss_assert "su-spelling-live" "$(su_buckets "$SU_G_SPELL" "$SU/cons")" "$SU_LIVE" \
  "a predicate written with git show piped into hash-object answers identically, so these arms bind the BEHAVIOUR and not one phrasing"
ss_assert "su-spelling-inert" "$(su_buckets "$SU_G_SPELL" "$SU/nostamp")" "$SU_INERT" \
  "...and it is inert on an unstamped consumer too, so it satisfies the guards and not only the happy path"

# --- THE GATE GOES QUIET WITH NO CHANGE TO ITS OWN ARM --------------------------------
# The filing named arm C, and arm C's filter is not what was wrong. These two runs are the same
# gate over the same tree, differing only in whether the consumer's stamp records the ref.
su_stamp "$SU_MID"
SU_GATE_MID="$(bash "$GATE" "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$SU/cons" 2>&1)"
SU_GATE_NO="$(bash "$GATE" "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$SU/nostamp" 2>&1)"
su_carry() { printf '%s\n' "$1" | awk -F'\t' '$1 == "SELF-UPDATE-CARRY" {print $2}' | sort | tr '\n' ','; }

ss_assert "su-gate-quiet" "$(su_carry "$SU_GATE_MID")" \
  'core/rules/doomed.md,core/rules/edited.md,core/rules/indexed.md,' \
  "both carried paths drop out of the advisory while the edited one, the deleted one and the non-machinery one behave exactly as before"
ss_assert "su-gate-differential" "$(su_carry "$SU_GATE_NO")" \
  'core/rules/added.md,core/rules/carried.md,core/rules/doomed.md,core/rules/edited.md,core/rules/indexed.md,' \
  "...and the SAME gate on a consumer with no stamp still carries both, so the quiet above is the stamp read and not a gate that went silent"

# THE ZERO CARRIES ITS CONTROL. A gate emitting nothing satisfies the absence above identically.
ss_assert "su-gate-verdict" \
  "$(printf '%s\n' "$SU_GATE_MID" | awk -F'\t' \
      '$1 == "SELF-UPDATE-OK" || $1 == "SELF-UPDATE-DEFER" || $1 == "SELF-UPDATE-UNDECIDED" {print $1}' \
      | sort -u | tr '\n' ',')" \
  "SELF-UPDATE-OK," "...and it still emits its own verdict, so the missing CARRY rows are a decision rather than a dead gate"

# --- THE JOIN ITSELF: arm C now EVALS machinery_paths() out of preclassify.sh ----------
# The population and the suppression scope are one derivation with one owner, loaded across a file
# boundary by an `awk` range on the function's own text. That join has a failure mode no other arm
# here can see: rename the function, or move it off column 0, and the extraction yields nothing,
# `C_PATHS` is EMPTY, the membership test rejects every path, and the arm reports no divergence
# having compared nothing -- output byte-identical to a clean pull. Scored on the GATE, not on the
# buckets, because the row it must emit is the gate's.
SU_G_MACHFN="$(su_mut su-machfn 'index($0,"machinery_paths() {") { print " machinery_paths() {"; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_MACHFN"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the set-empty row is unproven\n' "su-mut-machfn"
else
  su_machfn_out="$(bash "$(dirname "$SU_G_MACHFN")/self-update-gate.sh" \
                     "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$SU/cons" 2>&1)"
  su_machfn_row="$(printf '%s\n' "$su_machfn_out" | awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" {print $2; exit}')"
  su_machfn_carry="$(su_carry "$su_machfn_out")"
  if [ "$su_machfn_row" = "setup-sites.md" ] && [ -z "$su_machfn_carry" ]; then
    printf '  ok    %-16s KILLED (a function the extraction cannot find yields an EMPTY population, and the gate says so instead of going quiet)\n' "su-mut-machfn"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: row=[%s] carry=[%s] -- an unreadable machinery set must report UNDECIDED, never an empty advisory\n' \
      "su-mut-machfn" "${su_machfn_row:-<none>}" "$su_machfn_carry"
  fi
fi
# CONTROL: the SHIPPED gate over the same tree carries rows and emits no such verdict, so the row
# above is the mutation and not a property of this probe.
ss_assert "su-machfn-control" \
  "$(printf '%s\n' "$SU_GATE_MID" | grep -c 'SELF-UPDATE-UNDECIDED')" "0" \
  "the unmutated gate resolves a non-empty machinery set on this tree, so the UNDECIDED above is the mutation"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
