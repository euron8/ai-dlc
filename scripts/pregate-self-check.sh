#!/usr/bin/env bash
# pregate-self-check.sh -- a builder's own diff, checked in seconds, before a push asks for a gate slot.
#
# WHY. The pre-push hook finds three classes of red only after minutes: an enforcement-map invariant
# (I54 and I54b among them), a shell-portability arm, and the diff-scoped spelling arm r1-r4 of the
# procsub-staged-refusal fixture, which runs inside the fixture pool. This runs the first two as the
# hook runs them and the third from the SAME grammar file the fixture loads, so a builder sees all
# three before the push.
#
#   a. bash scripts/validate-enforcement-map.sh
#   b. bash scripts/validate-shell-portability.sh
#   c. core/fixtures/procsub-staged-refusal/procsub-spell.awk over `git diff -U0 <base> -- 'core/*.sh' ':(exclude)core/fixtures/**'`
#      -- the diff the fixture builds, with <base> in place of its PIN. The grammar and its seeded
#      probe (procsub-spell-probe.diff beside it) are SINGLE-SOURCED: the fixture reads the same two
#      files, and neither reader restates them.
#   d. bash core/fixtures/validator-fork-budget/run.sh -- the fork-budget fixture itself, the most frequent
#      catcher in the failure captures; named `d:fork-budget`.
#
# THE SPELLING ARM'S SELF-PROBE RUNS FIRST, in both directions (the seeded offenders flagged r1-r4,
# the six correct spellings not flagged). A grammar that cannot flag its seed has not scanned the diff.
# A diff that adds ZERO lines to core/*.sh is reported as "EXAMINED NOTHING", never as a pass of the grammar.
#
# DISTRIBUTION-ONLY. This reads scripts/validate-*.sh and the enforcement map, none of which a consumer has.
#
# AI_DLC_PREGATE_ROOT, when set, names the tree whose validators (a, b) are run and whose diff (c) is taken;
# the grammar and probe are always loaded from THIS script's own tree. That split is what lets the self-check
# be pointed at an older checkout (its validators judge that tree) while the grammar stays the current one.
#
# Usage: pregate-self-check.sh [<base>]     (default base: origin/main)
# Exit:  0 = clean, 1 = at least one finding (the check and the lines are named), 2 = cannot run.
set -uo pipefail
export LC_ALL=C

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
for f in "$AWK_FILE" "$PROBE_FILE" "$ROOT/scripts/validate-enforcement-map.sh" "$ROOT/scripts/validate-shell-portability.sh"; do
  [ -s "$f" ] || { echo "pregate-self-check: missing or empty sibling $f" >&2; exit 2; }
done
cd "$ROOT" || exit 2
git rev-parse --git-dir >/dev/null 2>&1 || { echo "pregate-self-check: $ROOT is not a git work tree" >&2; exit 2; }
git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null 2>&1 \
  || { echo "pregate-self-check: base '$BASE' does not resolve to a commit in $ROOT" >&2; exit 2; }

W="$(mktemp -d)" || exit 2
trap 'rm -rf "$W"' EXIT
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

# --- (a) enforcement map ---------------------------------------------------------------------------
printf '== a. enforcement map (I54, I54b and the rest)\n'
arm_start
bash scripts/validate-enforcement-map.sh > "$W/a.out" 2>&1
a_rc=$?
arm_took
if [ "$a_rc" -eq 2 ]; then
  printf '   cannot run: the validator refused (exit 2):\n' >&2
  head -5 "$W/a.out" | sed 's/^/     /' >&2
  exit 2
elif [ "$a_rc" -eq 0 ]; then
  printf '   ok\n'
else
  printf '   FAIL (exit %s):\n' "$a_rc"
  grep -E 'FAIL|^ERROR|I[0-9]+[a-z]?[ :]' "$W/a.out" | head -20 | sed 's/^/     /'
  note_fail "a:enforcement-map"
fi

# --- (b) shell portability -------------------------------------------------------------------------
printf '== b. shell portability (S1-S12, S13, S14)\n'
arm_start
bash scripts/validate-shell-portability.sh --quiet > "$W/b.out" 2>&1
b_rc=$?
arm_took
if [ "$b_rc" -eq 2 ]; then
  printf '   cannot run: the validator refused (exit 2):\n' >&2
  head -5 "$W/b.out" | sed 's/^/     /' >&2
  exit 2
elif [ "$b_rc" -eq 0 ]; then
  printf '   ok\n'
else
  printf '   FAIL (exit %s):\n' "$b_rc"
  head -20 "$W/b.out" | sed 's/^/     /'
  note_fail "b:shell-portability"
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
# The fixture IS the reader of FORK_BUDGET (arms A0-A5 and its mutants); this runs it the way the hook does
# (from the repo root, `bash <path>`), so neither the budget nor the arithmetic is restated here. It resolves
# its own root from its own path, so under AI_DLC_PREGATE_ROOT it judges that tree's validator. About 32s solo.
printf '== d. validator fork budget (core/fixtures/validator-fork-budget, about 32s)\n'
FB="$ROOT/core/fixtures/validator-fork-budget/run.sh"
if [ ! -s "$FB" ]; then
  printf 'pregate-self-check: missing sibling %s\n' "$FB" >&2
  exit 2
fi
arm_start
bash "$FB" > "$W/d.out" 2>&1
d_rc=$?
arm_took
if [ "$d_rc" -eq 0 ]; then
  printf '   ok\n'
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
if [ "$fail" -ne 0 ]; then
  printf 'pregate-self-check: FINDINGS in %s\n' "$fail_checks" >&2
  exit 1
fi
printf 'pregate-self-check: clean against %s\n' "$BASE"
exit 0
