#!/usr/bin/env bash
# Exercise reconcile/self-update-gate.sh.
#
# THE DIFFERENTIAL IS THE WHOLE MECHANISM. `gate-defer` and `gate-broken` both exit non-zero on the
# incoming side. A gate reading the incoming exit code alone calls them the same thing — and calling
# a pre-existing failure a "defer" strands the machinery slice for a reason unrelated to the pull.
# Only comparing against the consumer's CURRENT copy separates a new finding from an old one, and
# the mutation below removes exactly that comparison.
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
row gate-broken.sh SELF-UPDATE-UNDECIDED "BOTH exit non-zero, so the failure is not attributable to this pull"

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
# gate-broken then reads as a DEFER, which is the false positive that strands a machinery slice for
# a pre-existing failure. It must ALSO leave gate-defer's real verdict intact, or the mutant is
# entangled and proves nothing about which half did the work.
MUT="$(dirname "$DIST")/mut-nodiff"
rm -rf "$MUT"; mkdir -p "$MUT"
sed 's/^  elif \[ "$rc_cur" -eq 0 \]; then$/  elif true; then/' "$GATE" > "$MUT/gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$MUT/gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s the mutation matched nothing, so the UNDECIDED assertion is unproven\n' "mutation"
else
  m="$(bash "$MUT/gate.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
  m_broken="$(printf '%s\n' "$m" | awk -F'\t' '$2 == "gate-broken.sh" {print $1; exit}')"
  m_defer="$(printf '%s\n' "$m"  | awk -F'\t' '$2 == "gate-defer.sh"  {print $1; exit}')"
  if [ "$m_broken" = SELF-UPDATE-DEFER ] && [ "$m_defer" = SELF-UPDATE-DEFER ]; then
    printf '  ok    %-16s without the differential a pre-existing failure reads as a defer\n' "mutation"
  elif [ "$m_broken" != SELF-UPDATE-DEFER ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutant still classified gate-broken as %s, so the differential assertion is vacuous\n' "mutation" "${m_broken:-<none>}"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutant also changed gate-defer to %s, so it is entangled\n' "mutation" "${m_defer:-<none>}"
  fi
fi

# THE UNMUTATED CONTROL. The mutant is a copy; a copy that cannot run emits nothing, and nothing
# would score as a kill above.
CTL="$(dirname "$DIST")/ctl"; rm -rf "$CTL"; mkdir -p "$CTL"; cp "$GATE" "$CTL/gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
c_broken="$(bash "$CTL/gate.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1 | awk -F'\t' '$2 == "gate-broken.sh" {print $1; exit}')"
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

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
