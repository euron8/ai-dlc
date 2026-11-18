#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# consumer-presuite-steps -- the CONSUMER's pre-push hook runs its tree-level steps through the queue and flush it holds
# byte-identical (I66, the PRESUITE_UNITS span) to the distribution's: queued where written, run together at one flush
# before the applying guard and the fixture suite, printed in declaration order with their elapsed seconds.
#
# WHAT IT DRIVES. The consumer hook itself, copied to .githooks/pre-push in an installed-layout world: a git repository
# whose scripts/ai-dlc/ holds stub validators for the tree-level steps. A stub prints its own name and is RED while a file
# of that name sits under .red/. Nothing here re-implements the hook; every arm reads what the hook printed and exited.
#
# THE ARMS (no arm reads an elapsed value or a clock: the elapsed line is asserted PRESENT, never its number).
#   green    no tests/fixtures anywhere: every tree-level step still runs, prints PASS and a `step elapsed` line, in
#            declaration order, and the push exits 0 (a flush placed inside the tests/fixtures branch runs none of them)
#   rerun    the same tree pushed again: no step is skipped on a recorded pass, the key line reads 0 skipped (a consumer
#            keys no step)
#   red      one red step: the push exits 1 with the BLOCKED trailer, the red step prints FAIL, and every other step
#            still ran and printed its own verdict
#   applying the mid-pull marker present: the push refuses (exit 1, the mid-pull text) and the tree-level steps ran first
#   skipenv  AI_DLC_PRESUITE_SKIP=1 on a tree with a red step: nothing is skipped, the red step still blocks the push
#
# THE SUBJECT. core/git-hooks/pre-push in the distribution, the installed .githooks/pre-push on a consumer. A hook that
# is absent on a consumer (this fixture ships ahead of its subject) prints SKIP; in the distribution it is FIXTURE BROKEN; one present without the consumer policy FAILs.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/hook-drive.sh" || { echo "FIXTURE BROKEN: cannot source lib/hook-drive.sh" >&2; exit 2; }
. "$HERE/../lib/world.sh" || { echo "FIXTURE BROKEN: cannot source lib/world.sh" >&2; exit 2; }
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/report.sh"
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "consumer-presuite-steps: FIXTURE BROKEN" >&2; exit 2; }

. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# The subject is chosen by LAYOUT: core/git-hooks/pre-push in the distribution, the installed .githooks/pre-push on a consumer.
if fx_dist_layout "$HERE"; then SUBJ="$HERE/../../git-hooks/pre-push"; else SUBJ="$HERE/../../../.githooks/pre-push"; fi
if [ ! -f "$SUBJ" ]; then
  echo "SKIP: consumer-presuite-steps -- no consumer pre-push hook at $SUBJ; nothing was checked"
  fx_skip_exit "$HERE"
fi
# A present hook that lacks the consumer span or policy is a red assertion, never a skip.
if grep -q '^PS_SKIP_OK=0$' "$SUBJ"; then ok "the consumer hook carries the consumer policy (PS_SKIP_OK=0)"; else bad "$SUBJ lacks the line PS_SKIP_OK=0: the consumer PRESUITE_UNITS span or policy is absent"; report_end consumer-presuite-steps 14; fi
case "$SUBJ" in */core/git-hooks/pre-push|*/../../git-hooks/pre-push) echo "HERMETIC-CONSUMED core/git-hooks/pre-push" ;; *) echo "HERMETIC-CONSUMED .githooks/pre-push" ;; esac
WORK="$(mktemp -d "${TMPDIR:-/tmp}/consumer-presuite-steps.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# The tree-level steps in the order the hook declares them, as the titles it prints. The two absent validators
# (agent definitions, hook registration) are not part of the queued set here.
STUBS="validate-layer-entries validate-compact-window sync-taught-schema validate-provenance-block audit-rule-files validate-artifact-paths validate-write-format-steering"
EXPECT="layer entries
compact-window invariant
taught schema
stray party-mode
rule-file audit
artifact paths
write-format steering
shell syntax"

# world <dir>: a repository holding the hook copy and one stub per tree-level validator.
world() {
  local w="$1" s
  world_repo "$w" || return 1
  mkdir -p "$w/.githooks" "$w/scripts/ai-dlc" "$w/.red" || return 1
  cp "$SUBJ" "$w/.githooks/pre-push" || return 1
  for s in $STUBS; do
    printf '%s\n' '#!/usr/bin/env bash' "printf 'stub %s\\n' \"\${0##*/}\"" "[ ! -f \".red/\${0##*/}\" ]" > "$w/scripts/ai-dlc/$s.sh" || return 1
  done
  world_commit "$w" stubs >/dev/null 2>&1
  [ -d "$w/.git" ] || return 1
}
# titles <out>: the step titles the hook printed, each cut to its first words, in print order.
titles() { sed -n 's/^── //p' "$1"; }
# each_has_elapsed <out>: prints the number of `── ` blocks that are queued steps and the number of those that carry a
# `step elapsed` line (the inline hook-registration notice is no step).
each_has_elapsed() {
  awk '/^── /{ if (t) { n++; if (e) m++ } t = ($0 !~ /^── hook registration/); e = 0; next }
       /^   \.\.    step elapsed [0-9]+s$/ { e = 1 }
       END { if (t) { n++; if (e) m++ } print n + 0, m + 0 }' "$1"
}
want_order() { # <out> <tag>: the declared titles appear in order, each exactly once
  local o="$1" got exp
  got="$(titles "$o" | grep -E '^(layer entries|compact-window invariant|taught schema|stray party-mode|rule-file audit|artifact paths|write-format steering|shell syntax)' | sed -E 's/^(layer entries|compact-window invariant|taught schema|stray party-mode|rule-file audit|artifact paths|write-format steering|shell syntax).*/\1/')"
  exp="$EXPECT"
  [ "$got" = "$exp" ]
}

# green + rerun
W="$WORK/green"; world "$W" || broken "could not build the green world"
rc="$(hook_drive "$W" "$W.out1")"
if [ "$rc" = 0 ] && [ -d "$W/.git" ] && [ ! -d "$W/tests" ]; then ok "a tree with no tests/fixtures: the push exits 0"; else bad "no-fixtures tree: rc=$rc (want 0)"; fi
if want_order "$W.out1"; then ok "the eight tree-level steps print in declaration order, none missing, none twice"; else bad "step order was: $(titles "$W.out1" | tr '\n' '|')"; fi
set -- $(each_has_elapsed "$W.out1")
if [ "$1" = 8 ] && [ "$2" = 8 ]; then ok "every queued step prints a step elapsed line ($2 of $1)"; else bad "$2 of $1 queued steps carry a step elapsed line (want 8 of 8)"; fi
np="$(grep -c '^   PASS$' "$W.out1")"; nf="$(grep -c '^   FAIL$' "$W.out1")"
if [ "$np" = 8 ] && [ "$nf" = 0 ]; then ok "all eight steps report PASS and none FAIL"; else bad "PASS=$np FAIL=$nf (want 8 and 0)"; fi
rc="$(hook_drive "$W" "$W.out2")"
if [ "$rc" = 0 ] && ! grep -q 'skipped on a recorded pass:' "$W.out2" && ! grep -q 'pre-suite keys: [1-9]' "$W.out2"; then ok "a second push of the unchanged tree skips no step: a consumer keys nothing"; else bad "second push rc=$rc; skip lines: $(grep -c 'skipped on a recorded pass' "$W.out2")"; fi
set -- $(each_has_elapsed "$W.out2")
if [ "$1" = 8 ] && [ "$2" = 8 ]; then ok "the second push runs and times every step again ($2 of $1)"; else bad "second push: $2 of $1 steps carry a step elapsed line (want 8 of 8)"; fi

# red
W="$WORK/red"; world "$W" || broken "could not build the red world"
: > "$W/.red/validate-compact-window.sh"
rc="$(hook_drive "$W" "$W.out")"
if [ "$rc" = 1 ] && grep -q '^pre-push: BLOCKED' "$W.out"; then ok "a red step blocks the push: exit 1 with the BLOCKED trailer"; else bad "red step: rc=$rc, BLOCKED trailer present: $(grep -c '^pre-push: BLOCKED' "$W.out") (want 1 and 1)"; fi
np="$(grep -c '^   PASS$' "$W.out")"; nf="$(grep -c '^   FAIL$' "$W.out")"
if [ "$np" = 7 ] && [ "$nf" = 1 ] && want_order "$W.out"; then ok "the other seven steps still ran and printed their own verdict, in order"; else bad "red world: PASS=$np FAIL=$nf (want 7 and 1); order ok: $(want_order "$W.out" && echo yes || echo no)"; fi
if awk '/^── compact-window invariant/{ f = 1; next } /^── /{ f = 0 } f && /^   FAIL$/{ ok = 1 } END { exit ok ? 0 : 1 }' "$W.out"; then ok "the FAIL line sits under the red step's own title"; else bad "the red step's title is not followed by its FAIL"; fi

# applying marker
W="$WORK/applying"; world "$W" || broken "could not build the applying world"
mkdir -p "$W/.claude" && : > "$W/.claude/.ai-dlc-applying"
rc="$(hook_drive "$W" "$W.out")"
if [ "$rc" = 1 ] && grep -q 'mid-pull' "$W.out" && grep -q '^pre-push: BLOCKED' "$W.out"; then ok "the mid-pull marker still refuses the push"; else bad "applying marker: rc=$rc (want 1 with the mid-pull text and BLOCKED)"; fi
if want_order "$W.out"; then ok "the tree-level steps ran before the guard refused"; else bad "applying world step order was: $(titles "$W.out" | tr '\n' '|')"; fi

# the operator's skip switch on a consumer
W="$WORK/skipenv"; world "$W" || broken "could not build the skipenv world"
: > "$W/.red/validate-artifact-paths.sh"
rc="$(hook_drive "$W" "$W.out" AI_DLC_PRESUITE_SKIP=1)"
if [ "$rc" = 1 ] && ! grep -q 'SKIPPED (AI_DLC_PRESUITE_SKIP=1)' "$W.out" && grep -q '^pre-push: BLOCKED' "$W.out"; then ok "AI_DLC_PRESUITE_SKIP=1 skips no step on a consumer: the red step still blocks"; else bad "AI_DLC_PRESUITE_SKIP=1: rc=$rc, SKIPPED lines: $(grep -c 'SKIPPED (AI_DLC_PRESUITE_SKIP=1)' "$W.out") (want rc 1 and none)"; fi
set -- $(each_has_elapsed "$W.out")
if [ "$1" = 8 ] && [ "$2" = 8 ]; then ok "every step ran under AI_DLC_PRESUITE_SKIP=1 ($2 of $1)"; else bad "under AI_DLC_PRESUITE_SKIP=1 $2 of $1 steps ran (want 8 of 8)"; fi
report_end consumer-presuite-steps 14
