#!/usr/bin/env bash
# pregate-self-check.sh -- a builder's own diff, checked in seconds, before a push asks for a gate slot.
#
# WHY. The pre-push hook finds its classes of red only after minutes: every `step` above the fixture
# suite (the enforcement map with I54 and I54b, shell portability, the fixture git-env scrub, and the rest),
# and the diff-scoped spelling arm r1-r4 of the procsub-staged-refusal fixture, which runs inside the
# fixture pool. A hand-written list of the first class drifted from the hook: a self-check rc 0 went red at
# the gate on an above-pool step it never ran. So the list is DERIVED, not written.
#
#   a. the hook's own prefix: `.githooks/pre-push` of $ROOT from line 1 up to, NOT including, the single
#      `step "fixture suite` line, with `exit $fail` appended, run as `bash <prefix> </dev/null` from $ROOT.
#      Every above-pool step, its flags and its wrapper functions are the hook's own bytes, so "a step in the
#      hook that the self-check does not run" is unconstructible. Guards, each a refusal (exit 2): the hook
#      carries no NUL byte; the cut marker occurs exactly once; the prefix passes `bash -n`; it declares >= 1 `step` call; the PASS/FAIL
#      verdicts printed equal the `step` calls declared (a run that stopped early is not a pass of the steps
#      it never reached). The prefix's top-level code (function definitions, and `ssh_keepalive_warn` with no
#      arguments, which returns at once) writes nothing into the tree.
#   c. core/fixtures/procsub-staged-refusal/procsub-spell.awk over `git diff -U0 <base> -- 'core/*.sh' ':(exclude)core/fixtures/**'`
#      -- the diff the fixture builds, with <base> in place of its PIN. The grammar and its seeded
#      probe (procsub-spell-probe.diff beside it) are SINGLE-SOURCED: the fixture reads the same two
#      files, and neither reader restates them.
#   d. core/scripts/hermetic-run.sh validator-fork-budget, invocation counter armed -- the fork-budget fixture
#      itself, the most frequent catcher in the failure captures, with its invocations.decl rows judged (J3) as
#      the gate judges them; named `d:fork-budget`.
#
# THE SPELLING ARM'S SELF-PROBE RUNS FIRST, in both directions (the seeded offenders flagged r1-r4,
# the six correct spellings not flagged). A grammar that cannot flag its seed has not scanned the diff.
# A diff that adds ZERO lines to core/*.sh is reported as "EXAMINED NOTHING", never as a pass of the grammar.
#
# DISTRIBUTION-ONLY. This reads scripts/validate-*.sh and the enforcement map, none of which a consumer has.
#
# AI_DLC_PREGATE_ROOT, when set, names the tree whose hook prefix (a) is run and whose diff (c) is taken;
# the grammar and probe are always loaded from THIS script's own tree. That split is what lets the self-check
# be pointed at an older checkout (its validators judge that tree) while the grammar stays the current one.
#
# Usage: pregate-self-check.sh [<base>]     (default base: origin/main)
# Exit:  0 = clean, 1 = at least one finding (the check and the lines are named), 2 = cannot run.
set -uo pipefail
export LC_ALL=C

# NO -e, SO AN EXPANSION DEATH IS NOT A REFUSAL BY ITSELF. Under bash 3.2 a fatal arithmetic-expansion error
# under -u ends the script with the PREVIOUS command's status, which is usually 0, and the steps never run: a
# false clean. So exit 0 or 1 is honoured only once `done_` is set, as the last act before the verdict; any
# exit before it that is not an explicit refusal (2) becomes exit 2 here, with this message.
done_=0
W=""
on_exit() {
  local rc=$?
  [ -n "$W" ] && rm -rf "$W"
  if [ "$done_" != 1 ] && [ "$rc" -ne 2 ]; then
    printf 'pregate-self-check: the run died before its verdict (shell status %s) -- an early death is a refusal, never a clean run\n' "$rc" >&2
    exit 2
  fi
}
trap on_exit EXIT

BASE="${1:-origin/main}"
[ "$#" -le 1 ] || { echo "usage: $(basename "$0") [<base>]" >&2; exit 2; }

# Walk UP for the marker, never count `..` hops.
walk_up() {
  local d="$1"
  while [ "$d" != "/" ] && [ ! -f "$d/VERSION" ]; do d="$(dirname "$d")"; done
  [ -f "$d/VERSION" ] || return 1
  printf '%s\n' "$d"
}
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_ROOT="$(walk_up "$SELF_DIR")" || { echo "pregate-self-check: no VERSION marker above $0" >&2; exit 2; }
if [ -n "${AI_DLC_PREGATE_ROOT:-}" ]; then
  ROOT="$(cd "$AI_DLC_PREGATE_ROOT" 2>/dev/null && pwd)" || { echo "pregate-self-check: AI_DLC_PREGATE_ROOT is not a directory" >&2; exit 2; }
  [ -f "$ROOT/VERSION" ] || { echo "pregate-self-check: no VERSION marker in AI_DLC_PREGATE_ROOT $ROOT" >&2; exit 2; }
else
  ROOT="$SELF_ROOT"
fi

command -v git >/dev/null 2>&1 || { echo "pregate-self-check: git is not on PATH" >&2; exit 2; }
AWK_FILE="$SELF_ROOT/core/fixtures/procsub-staged-refusal/procsub-spell.awk"
PROBE_FILE="$SELF_ROOT/core/fixtures/procsub-staged-refusal/procsub-spell-probe.diff"
for f in "$AWK_FILE" "$PROBE_FILE" "$ROOT/.githooks/pre-push"; do
  [ -s "$f" ] || { echo "pregate-self-check: missing or empty sibling $f" >&2; exit 2; }
done
cd "$ROOT" || exit 2
git rev-parse --git-dir >/dev/null 2>&1 || { echo "pregate-self-check: $ROOT is not a git work tree" >&2; exit 2; }
git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null 2>&1 \
  || { echo "pregate-self-check: base '$BASE' does not resolve to a commit in $ROOT" >&2; exit 2; }

W="$(mktemp -d)" || exit 2
fail=0
fail_checks=""
note_fail() { fail=1; fail_checks="${fail_checks}${fail_checks:+, }$1"; }
# Per-arm wall seconds, from bash's own SECONDS (no fork): the figure BL-585 owes for each catcher alone.
t0=0
arm_start() { t0=$SECONDS; }
arm_took() { printf '   (%ss)\n' "$((SECONDS - t0))"; }

# --- (c) first, the part that is not already a script: the grammar's self-probe ------------------
printf '== c0. spelling grammar self-probe (seeded diff, both directions)\n'
PROBE_GOT="$(awk -f "$AWK_FILE" "$PROBE_FILE" | cut -d: -f1 | tr '\n' ' ')"
if [ "$PROBE_GOT" = "r1 r2 r3 r4 " ]; then
  printf '   ok: r1-r4 each flagged once, the six correct spellings not flagged\n'
else
  printf '   FAIL: the grammar read "%s" on its seeded probe, expected "r1 r2 r3 r4 " -- it cannot be trusted on a real diff\n' "$PROBE_GOT" >&2
  exit 2
fi

# --- (a) every hook step above the fixture suite, DERIVED from the hook ---------------------------------
# The prefix is cut from $ROOT's own hook, so AI_DLC_PREGATE_ROOT judges that tree's hook.
printf '== a. hook steps above the fixture suite (derived from .githooks/pre-push)\n'
HOOK="$ROOT/.githooks/pre-push"
# A NUL byte makes grep read the hook as binary: -c still counts the marker, but -n prints "Binary file ...
# matches" in place of the line number. Refuse it before either grep runs.
tr -d '\000' < "$HOOK" | cmp -s - "$HOOK" \
  || { printf 'pregate-self-check: %s carries a NUL byte, so grep reads it as binary; refusing to cut it\n' "$HOOK" >&2; exit 2; }
nm="$(grep -c '^step "fixture suite' "$HOOK")" || nm=0
[ "$nm" -eq 1 ] || { printf 'pregate-self-check: the fixture-suite step marker occurs %s times in %s, expected exactly 1\n' "$nm" "$HOOK" >&2; exit 2; }
cut="$(grep -n '^step "fixture suite' "$HOOK" | cut -d: -f1)"
head -n "$((cut - 1))" "$HOOK" > "$W/prefix.sh"
printf '\nexit $fail\n' >> "$W/prefix.sh"
bash -n "$W/prefix.sh" 2> "$W/prefix.err" || { printf 'pregate-self-check: the extracted hook prefix does not parse: %s\n' "$(head -1 "$W/prefix.err")" >&2; exit 2; }
ns="$(grep -cE '^[[:space:]]*step "' "$W/prefix.sh")" || ns=0
[ "$ns" -ge 1 ] || { printf 'pregate-self-check: no step calls above the fixture suite in %s\n' "$HOOK" >&2; exit 2; }
arm_start
AI_DLC_VERDICT_STORE="$W/vs" bash "$W/prefix.sh" < /dev/null > "$W/a.out" 2>&1
a_rc=$?
arm_took
# One verdict per step: the hook prints "── <name>" then, after the step's own output, "   PASS" or "   FAIL".
awk '/^── / { if (name != "") print "NOVERDICT\t" name; name = $0; sub(/^── /, "", name); next }
     /^   PASS$/ && name != "" { print "PASS\t" name; name = ""; next }
     /^   FAIL$/ && name != "" { print "FAIL\t" name; name = ""; next }
     END { if (name != "") print "NOVERDICT\t" name }' "$W/a.out" > "$W/a.verdicts"
nv="$(grep -cE '^(PASS|FAIL)	' "$W/a.verdicts")" || nv=0
nf="$(grep -cE '^(FAIL|NOVERDICT)	' "$W/a.verdicts")" || nf=0
if [ "$nv" -ne "$ns" ]; then
  printf 'pregate-self-check: %s step call(s) declared above the fixture suite, %s verdict(s) printed -- the run did not reach every step:\n' "$ns" "$nv" >&2
  tail -8 "$W/a.out" | sed 's/^/     /' >&2
  exit 2
fi
if [ "$nf" -eq 0 ] && [ "$a_rc" -eq 0 ]; then
  printf '   ok: %s step(s), every one PASS\n' "$ns"
else
  printf '   FAIL (prefix exit %s, %s of %s step(s) failing):\n' "$a_rc" "$nf" "$ns"
  awk -F'\t' '$1 == "FAIL" || $1 == "NOVERDICT" { printf "     %s: %s\n", $1, $2 }' "$W/a.verdicts"
  note_fail "a:hook-steps"
fi

# --- (c) the spelling grammar over this diff ---------------------------------------------------------
printf '== c. procsub spelling arm r1-r4 over the diff against %s\n' "$BASE"
if git diff -U0 "$BASE" -- 'core/*.sh' ':(exclude)core/fixtures/**' > "$W/c.diff" 2> "$W/c.err"; then
  n_added="$(grep -c '^+[^+]' "$W/c.diff")" || n_added=0
  hits="$(awk -f "$AWK_FILE" "$W/c.diff")"
  if [ -n "$hits" ]; then
    printf '   FAIL: added line(s) discard a producer status (rule named first):\n'
    printf '%s\n' "$hits" | sed 's/^/     /'
    note_fail "c:spelling"
  elif [ "$n_added" -eq 0 ]; then
    printf '   EXAMINED NOTHING -- the diff adds no lines to core/*.sh outside core/fixtures/ (this is not a pass of the grammar)\n'
  else
    printf '   ok: %s added line(s), none reintroduces a discarded status\n' "$n_added"
  fi
else
  printf '   cannot run: git diff against %s failed: %s\n' "$BASE" "$(head -1 "$W/c.err")" >&2
  exit 2
fi

# --- (d) the validator fork budget, single-sourced -----------------------------------------------------
# The fixture IS the reader of FORK_BUDGET (arms A0-A5 and its mutants); this runs it the way the gate does,
# through core/scripts/hermetic-run.sh with the invocation counter ARMED, so neither the budget, the arithmetic
# nor the invocations.decl rows are restated here. Run plainly, the fixture's J3 rows were never judged: the
# self-check printed ok on a tree whose gate went red on that fixture's `*` row (BL-1026). Armed means the three
# FXCOUNT_* variables the hook's fxcount_arm sets, the rc generated by the judge into this run's own scratch
# dir, and a scratch verdict store, so nothing reaches the shared store. hermetic-run.sh runs UNCOUNTED if any
# of the three is unset and says nothing, so `ok` needs the judge's own pass line for the fixture as well as
# exit 0; exit 0 without it is a refusal. The judge's self-probe is not repeated here: section a runs the
# hook's arming step, which runs it. Runner and judge come from $ROOT, so under AI_DLC_PREGATE_ROOT this judges
# that tree's fixture by that tree's judge. About 40s solo.
printf '== d. validator fork budget (core/fixtures/validator-fork-budget, counted, about 40s)\n'
FB="$ROOT/core/fixtures/validator-fork-budget/run.sh"
HR="$ROOT/core/scripts/hermetic-run.sh"
FXJ="$ROOT/scripts/validate-fixture-invocations.sh"
for f in "$FB" "$HR" "$FXJ"; do
  [ -s "$f" ] || { printf 'pregate-self-check: missing sibling %s\n' "$f" >&2; exit 2; }
done
mkdir -p "$W/fx/log" "$W/fx/vs" || exit 2
FXRC="$(bash "$FXJ" --gen-rc "$W/fx")" && [ -s "$FXRC" ] \
  || { printf 'pregate-self-check: the invocation judge %s did not generate its rc into %s\n' "$FXJ" "$W/fx" >&2; exit 2; }
arm_start
FXCOUNT_RC="$FXRC" FXCOUNT_DIR="$W/fx/log" FXCOUNT_JUDGE="$FXJ" AI_DLC_VERDICT_STORE="$W/fx/vs" \
  bash "$HR" --root "$ROOT" validator-fork-budget > "$W/d.out" 2>&1
d_rc=$?
arm_took
d_judged="$(grep -c '^validator-fork-budget: invocation budget ok: ' "$W/d.out")" || d_judged=0
if [ "$d_rc" -eq 0 ] && [ "$d_judged" -eq 1 ]; then
  printf '   ok: %s\n' "$(grep '^validator-fork-budget: invocation budget ok: ' "$W/d.out")"
elif [ "$d_rc" -eq 0 ]; then
  printf '   cannot run: the counted run exited 0 but the judge printed no pass line for validator-fork-budget, so its invocations.decl rows were not judged:\n' >&2
  tail -5 "$W/d.out" | sed 's/^/     /' >&2
  exit 2
elif [ "$d_rc" -eq 2 ]; then
  printf '   cannot run: the fixture refused (exit 2):\n' >&2
  head -5 "$W/d.out" | sed 's/^/     /' >&2
  exit 2
else
  printf '   FAIL (exit %s):\n' "$d_rc"
  grep -Ev '^HERMETIC-CONSUMED|^ *ok ' "$W/d.out" | tail -12 | sed 's/^/     /'
  note_fail "d:fork-budget"
fi

printf '\n'
done_=1
if [ "$fail" -ne 0 ]; then
  printf 'pregate-self-check: FINDINGS in %s\n' "$fail_checks" >&2
  exit 1
fi
printf 'pregate-self-check: clean against %s\n' "$BASE"
exit 0
