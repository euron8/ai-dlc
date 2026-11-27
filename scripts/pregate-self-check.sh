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
#      the gate judges them; named `d:fork-budget`. On a clean tree it runs through scripts/seed-verdict-store.sh,
#      so its pass is recorded in the counted store the push reads and the push does not run it again.
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
# The hook run is the one git resolves for a push (core.hooksPath honoured); it must exist and be byte-identical to
# $ROOT/.githooks/pre-push, else exit 2. A scratch root with no core.hooksPath therefore refuses (no hook would run).
#
# Usage: pregate-self-check.sh [--member] [<base>]     (default base: origin/main)
# A STACKED BASE (BL-1156): when <base> is absent from origin/main and a proper ancestor of HEAD (a release stacked on
# an unlanded one; pass the predecessor's sha), section a's prefix runs with AI_DLC_PREGATE_RV_BASE=<base sha>, and the
# hook's release-version step ranges from it rather than origin/main. That run scopes out arm D (local-main
# inheritance); the push still judges in default mode. Any other <base> runs the step exactly as a ref-less run does.
# Exit: 0 = clean, 1 = at least one finding (the check and the lines are named), 2 = cannot run.
# MANDATORY: .githooks/pre-push refuses a push of any tree this script has not recorded green (PREGATE_GATE span).
#
# --member: THE MEMBER MODE, for a release that edits .githooks/pre-push, whose tree hook can never equal the hook a
# push runs until the main checkout holds it. Section a runs the TREE's own hook prefix ($ROOT/.githooks/pre-push, the
# same cut) in place of the resolved one, and the byte-identity refusal is not applied; sections c and d run as above.
# It NEVER writes the pregate record, so its pass never stands in for the gate: the push still needs a run without
# --member where the resolved hook equals the tree's.
psc_main() {
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

MEMBER=0
if [ "${1:-}" = --member ]; then MEMBER=1; shift; fi
BASE="${1:-origin/main}"
[ "$#" -le 1 ] || { echo "usage: $(basename "${BASH_SOURCE[0]}") [--member] [<base>]" >&2; exit 2; }

# Walk UP for the marker, never count `..` hops.
walk_up() {
  local d="$1"
  while [ "$d" != "/" ] && [ ! -f "$d/VERSION" ]; do d="$(dirname "$d")"; done
  [ -f "$d/VERSION" ] || return 1
  printf '%s\n' "$d"
}
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_ROOT="$(walk_up "$SELF_DIR")" || { echo "pregate-self-check: no VERSION marker above ${BASH_SOURCE[0]}" >&2; exit 2; }
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
# rv_base -> the base sha when it is a stacked base (see the usage block), else nothing.
rv_base() {
  local b h
  b="$(git rev-parse --verify --quiet "${BASE}^{commit}")" || return 0
  h="$(git rev-parse --verify --quiet 'HEAD^{commit}')" || return 0
  git rev-parse --verify --quiet 'origin/main^{commit}' >/dev/null 2>&1 || return 0
  [ "$b" != "$h" ] || return 0
  git merge-base --is-ancestor "$b" origin/main 2>/dev/null && return 0
  git merge-base --is-ancestor "$b" "$h" 2>/dev/null || return 0
  printf '%s\n' "$b"
}
RV_BASE="$(rv_base)"

W="$(mktemp -d)" || exit 2
# THE PREGATE RECORD (BL-1055). .githooks/pre-push refuses a push that delivers a tree with no record written here.
# One is written only on exit 0, and only when $ROOT's work tree is clean (no tracked change, no untracked
# non-ignored path) at the start AND at the end of this run with the same HEAD tree, so the record names exactly the
# tree every section judged. Path: <verdict store base>/pregate-green/<root commit>/<HEAD tree>; body `#format pg1`, then the
# tree, the base commit and the UTC time.
pg_state() { local t s; t="$(git rev-parse --verify --quiet 'HEAD^{tree}')" || return 1
  s="$(GIT_OPTIONAL_LOCKS=0 git status --porcelain --untracked-files=normal)" || return 1; printf '%s\n%s' "$t" "$s"; }
PG_START="$(pg_state)" || PG_START=""
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
# HOOK-RESOLVE-BEGIN
# The hook a push from $ROOT would run is git's own answer (core.hooksPath honoured, absolute or relative, from a
# linked worktree too), never a hand-built $ROOT/.githooks path. A relative answer is relative to the cwd `-C` sets,
# so it is joined to $ROOT. That join is DEFENSIVE: the script has already `cd "$ROOT"`, so git's relative answer
# would resolve the same either way, and no receipt cell can fail it. When the resolved hook equals the base blob and
# only the tree hook differs, the tree hook is also compared with the MERGE-BASE copy of the hook: equal means the
# branch is behind ("rebase onto <base>"); different means the branch EDITED the hook, so rebasing would repeat the
# refusal, and the message says the push runs the resolved hook, not the edit, and that the checkout holding it must be
# updated or the push made from it. When no merge-base (or no hook blob at it) exists, the message says so and gives
# both remedies. When only the resolved hook moved, the message names the checkout holding it and three readings:
# <BASE> is an unlanded predecessor release that edited the hook (wait for it to land, then rebase and rerun); the
# checkout is detached at an unlanded hook-editing release for that release's push (wait for it to land and the
# re-detach at origin/main, then rerun); or it is stale or locally edited (ask the lead to re-detach it at origin/main).
# When both hooks moved, the message gives the same waits (an unlanded release the checkout is detached at, or a
# stacked <BASE>), --member for gating the branch's own edit, and the re-detach for a stale or edited checkout. An ABSENT resolved hook means a push runs no pre-push hook: refused. A resolved hook that
# is not byte-identical to $ROOT/.githooks/pre-push is refused, naming both paths and which side moved relative to
# <BASE>:.githooks/pre-push (BASE is the positional argument; when that blob is absent the side is reported unknown).
TREE_HOOK="$ROOT/.githooks/pre-push"
HOOK_REL="$(git -C "$ROOT" rev-parse --git-path hooks/pre-push 2>/dev/null)" && [ -n "$HOOK_REL" ] \
  || { printf 'pregate-self-check: git could not resolve the pre-push hook path of %s\n' "$ROOT" >&2; exit 2; }
case "$HOOK_REL" in /*) HOOK="$HOOK_REL" ;; *) HOOK="$ROOT/$HOOK_REL" ;; esac
[ -f "$HOOK" ] \
  || { printf 'pregate-self-check: a push from %s would run no pre-push hook (resolved %s is absent; set core.hooksPath .githooks)\n' "$ROOT" "$HOOK" >&2; exit 2; }
if [ "$MEMBER" = 0 ] && ! cmp -s "$HOOK" "$TREE_HOOK"; then
  if git -C "$ROOT" show "${BASE}:.githooks/pre-push" > "$W/base-hook" 2>/dev/null; then
    r_moved=1; t_moved=1; remedy=""
    cmp -s "$HOOK" "$W/base-hook" && r_moved=0
    cmp -s "$TREE_HOOK" "$W/base-hook" && t_moved=0
    if [ "$r_moved" = 1 ] && [ "$t_moved" = 0 ]; then
      side="the resolved hook moved"
      remedy="; the push will run ${HOOK}, held by the checkout whose hooks git resolves (in this repo's setup, the main checkout): if ${BASE} is an unlanded predecessor release that edited the hook (a stacked base), wait for it to land, then rebase and rerun; if that checkout is detached at an unlanded hook-editing release for that release's push, wait for that push to land and the main checkout to be re-detached at origin/main, then rerun; otherwise it is stale or its hook is locally edited: ask the lead to re-detach it at origin/main"
    elif [ "$r_moved" = 0 ] && [ "$t_moved" = 1 ]; then
      side="the tree hook moved"
      mb="$(git -C "$ROOT" merge-base HEAD "$BASE" 2>/dev/null)" || mb=""
      if [ -n "$mb" ] && git -C "$ROOT" show "${mb}:.githooks/pre-push" > "$W/mb-hook" 2>/dev/null; then
        if cmp -s "$TREE_HOOK" "$W/mb-hook"; then remedy="; the branch is behind: rebase onto ${BASE}"
        else remedy="; the branch edited the hook, but the push will run ${HOOK}, not the edit: update the checkout holding it (the main checkout) or push from that checkout; before READY run this script with --member, which runs the tree's own hook and records nothing"; fi
      else
        remedy="; the merge-base with ${BASE} is unavailable, so behind cannot be told from edited: rebase onto ${BASE}, or update the checkout holding ${HOOK} if the edit is intended"
      fi
    else
      side="both hooks moved"
      remedy="; the branch edited the hook while the checkout holding ${HOOK} (in this repo's setup, the main checkout) holds a different hook: if that checkout is detached at an unlanded hook-editing release for its push, or ${BASE} is a stacked base not yet landed, wait for it to land, then rebase and rerun; if the edit is this branch's own and must be gated, the push runs ${HOOK}, not the edit, so before READY run this script with --member, which runs the tree's own hook and records nothing; otherwise the checkout is stale or locally edited: ask the lead to re-detach it at origin/main"
    fi
    side="$side relative to ${BASE}:.githooks/pre-push${remedy}"
  else
    side="which side moved is unknown: ${BASE}:.githooks/pre-push is absent"
  fi
  printf 'pregate-self-check: the hook a push would run (%s) is not byte-identical to the tree hook (%s): %s\n' "$HOOK" "$TREE_HOOK" "$side" >&2
  exit 2
fi
# HOOK-RESOLVE-END
# THE MEMBER MODE runs the tree's own hook, named by path here, outside the HOOK-RESOLVE block.
if [ "$MEMBER" = 1 ]; then # member: the tree's own hook
  m_rel="same bytes as"; cmp -s "$HOOK" "$ROOT/.githooks/pre-push" || m_rel="NOT the bytes of"
  printf '   member mode: running the tree'"'"'s own hook %s (%s the hook a push would run, %s); no pregate record will be written\n' "$ROOT/.githooks/pre-push" "$m_rel" "$HOOK"
  HOOK="$ROOT/.githooks/pre-push"
fi
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
# No store override (BL-1066): the prefix runs under the caller's verdict store, as a push runs it. No step above
# the cut writes a verdict (hermetic-run.sh is the store's only writer and runs below it), so this writes none.
[ -z "$RV_BASE" ] || printf '   stacked base %s: the release-version step ranges from it, not origin/main (arm D scoped out)\n' "$RV_BASE"
arm_start
AI_DLC_PREGATE_RV_BASE="$RV_BASE" bash "$W/prefix.sh" < /dev/null > "$W/a.out" 2>&1
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
# FXCOUNT_* variables the hook's fxcount_arm sets. hermetic-run.sh runs UNCOUNTED if any of the three is unset
# and says nothing, so `ok` needs the judge's own pass line for the fixture as well as exit 0; exit 0 without it
# is a refusal. Runner and judge come from $ROOT, so under AI_DLC_PREGATE_ROOT this judges that tree's fixture by
# that tree's judge. About 40s solo.
# ON A CLEAN TREE THE PASS IS THE PUSH'S OWN (BL-1064): the run goes through this script's own tree's
# scripts/seed-verdict-store.sh from $ROOT, which arms with the hook's fxcount_arm (extracted from $ROOT's hook,
# never restated) and so records the pass in the counted store the push reads; the push then skips the fixture.
# ON A DIRTY TREE THE SAME SEED RUNS WITH --dirty-ok (BL-1066): hermetic-run.sh copies the sandbox from the work tree
# and keys the entry on that same work tree, so the pass lands in the counted store under the content that ran, and
# only a push of a tree holding the same bytes reuses it.
# A red unit's output, indented under its FAIL line: lines matching <drop ERE> are skipped; every evidence line
# (`      | `, seed-verdict-store.sh's own pattern) prints, in source order, with the line directly above its block; the
# other lines are capped to their last <cap>, since a red with no verdict line prints its whole output.
red_print() { # <drop ERE> <cap> <file>
  awk -v drop="$1" -v cap="$2" '$0 ~ drop { next }
    { L[++n] = $0; if ($0 ~ /^      [|] /) E[n] = 1; else m++ }
    END { k = 0; for (i = 1; i <= n; i++) { if (!E[i]) k++; if (E[i] || E[i + 1] || k > m - cap) print "     " L[i] } }' "$3"
}
printf '== d. validator fork budget (core/fixtures/validator-fork-budget, counted, about 40s)\n'
FB="$ROOT/core/fixtures/validator-fork-budget/run.sh"
HR="$ROOT/core/scripts/hermetic-run.sh"
FXJ="$ROOT/scripts/validate-fixture-invocations.sh"
SEED="$SELF_ROOT/scripts/seed-verdict-store.sh"
for f in "$FB" "$HR" "$FXJ" "$SEED"; do
  [ -s "$f" ] || { printf 'pregate-self-check: missing sibling %s\n' "$f" >&2; exit 2; }
done
if [ -n "$PG_START" ] && [ "$PG_START" = "${PG_START%%
*}" ]; then
  d_dok=""; d_tree="clean tree: a pass is the push's own"
else
  d_dok="--dirty-ok"; d_tree="dirty tree: a pass is keyed on the work tree's bytes"
fi
mkdir -p "$W/fx/keep" || exit 2
arm_start
bash "$SEED" --keep "$W/fx/keep" ${d_dok:+"$d_dok"} validator-fork-budget > "$W/d.seed" 2>&1
arm_took
d_rc="$(sed -n 's/^validator-fork-budget rc=\([0-9][0-9]*\)$/\1/p' "$W/d.seed")"
[ -n "$d_rc" ] || d_rc=2
if [ -f "$W/fx/keep/validator-fork-budget.out" ]; then cp "$W/fx/keep/validator-fork-budget.out" "$W/d.out" || exit 2
else cp "$W/d.seed" "$W/d.out" || exit 2; fi
printf '   %s (%s)\n' "$(sed -n 's/^counted store: /counted store /p' "$W/d.seed")" "$d_tree"
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
  red_print '^HERMETIC-CONSUMED|^ *ok ' 12 "$W/d.out"
  note_fail "d:fork-budget"
fi

# THE PREDICTION, run at most once and read by sections e and f: $ROOT's scripts/predict-push-set.sh, the hook's own
# composer, into $W/e/pred. P_OK=1 when it printed its `RUN <n>` line; $W/e/predrun then holds the units it would run.
E_PRED="$ROOT/scripts/predict-push-set.sh"
P_DONE=0; P_OK=0
pred_once() {
  [ "$P_DONE" = 1 ] && return 0
  P_DONE=1
  mkdir -p "$W/e" || exit 2
  if [ -f "$E_PRED" ] && bash "$E_PRED" "$ROOT" "$W/e/pred" > "$W/e/pred.out" 2> "$W/e/pred.err" < /dev/null \
     && grep -q '^RUN [0-9][0-9]*$' "$W/e/pred.out"; then
    sed -n 's/^run //p' "$W/e/pred.out" | sort -u > "$W/e/predrun"; P_OK=1
  fi
}
# THE SEED of one section's units, $1/torun, through this tree's seed-verdict-store.sh into the counted store a push
# reads: one rc line per unit (a unit with none is a refusal), and any red is a finding under $4. The one exception
# is the seeder's own non-failure line for an @consumer unit the selection no longer holds,
# `<fx>@consumer not-selected (record current; nothing ran)`: it is printed as not-selected and counted neither as
# red nor as a run or recorded pass.
# THE UNDECLARED DROP: core/scripts/hermetic-run.sh refuses (exit 2) a fixture whose directory has no inputs.decl, so
# such a unit cannot be counted-seeded; the push runs it plain. It leaves $1/torun, printed as undeclared, and
# u_drop counts it. An `<fx>@consumer` unit is run by the consumer census, not hermetic-run.sh, and stays. Builtins only.
drop_undeclared() { # <section dir>
  local d="$1" u; u_drop=0
  { while IFS= read -r u; do
      case "$u" in *@consumer) ;; *)
        [ -f "core/fixtures/$u/inputs.decl" ] || { printf '     %s undeclared: runs plain in the push\n' "$u" >&3; u_drop=$((u_drop + 1)); continue; } ;;
      esac
      printf '%s\n' "$u"
    done < "$d/torun"; } 3>&1 > "$d/torun.kept"
  while IFS= read -r u; do printf '%s\n' "$u"; done < "$d/torun.kept" > "$d/torun"
}
seed_set() { # <section dir> <jobs> <unit count> <finding name> [<why nothing ran, when nothing does>] [<ok line, when nothing ran because every unit is a reused pass>]
  local d="$1" j="$2" k="$3" s_rc s_red="" s_rec=0 s_ns=0 n r
  arm_start
  if [ "$k" -gt 0 ]; then
    bash "$SEED" --keep "$d/keep" --jobs "$j" ${d_dok:+"$d_dok"} $(cat "$d/torun") > "$d/seed" 2>&1
    s_rc=$?
  else
    : > "$d/seed"; s_rc=0
  fi
  arm_took
  while IFS= read -r n; do
    r="$(sed -n "s/^${n} rc=\([0-9][0-9]*\)\$/\1/p" "$d/seed")"
    if [ -z "$r" ]; then
      case "$n" in
        *@consumer)
          if grep -qxF "$n not-selected (record current; nothing ran)" "$d/seed"; then
            printf '     %s not-selected (record current)\n' "$n"; s_ns=$((s_ns + 1)); continue
          fi ;;
      esac
    fi
    [ -n "$r" ] || { printf '   cannot run: seed-verdict-store.sh (exit %s) gave %s no rc:\n' "$s_rc" "$n" >&2; tail -5 "$d/seed" | sed 's/^/     /' >&2; exit 2; }
    printf '     %s rc=%s\n' "$n" "$r"
    [ "$r" = 0 ] || s_red="$s_red $n"
    grep -q "^hermetic-run: ${n}: verdict recorded in " "$d/keep/$n.out" 2>/dev/null && s_rec=$((s_rec + 1))
  done < "$d/torun"
  if [ -n "$s_red" ]; then
    printf '   FAIL: red:%s\n' "$s_red"
    red_print '^[A-Za-z0-9._-]+ rc=[0-9]+$|^counted store: ' 20 "$d/seed"
    note_fail "$4"
  elif [ "$((k - s_ns))" -eq 0 ] && [ -n "${6:-}" ]; then
    # Nothing ran because the prediction holds every selected unit as a reused counted pass: those are passes.
    printf '   ok: %s\n' "$6"
  elif [ "$((k - s_ns))" -eq 0 ]; then
    # Nothing ran, so nothing passed: reported as section c reports an empty diff, never as ok and never as a finding.
    printf '   EXAMINED NOTHING -- %s' "${5:-no unit was left to run}"
    [ "$s_ns" -eq 0 ] || printf '; %s not-selected (record current)' "$s_ns"
    printf ' (this is not a pass)\n'
  else
    printf '   ok: %s fixture(s) run green; %s pass(es) recorded in the counted store (%s)' "$((k - s_ns))" "$s_rec" "$(sed -n 's/^counted store: //p' "$d/seed")"
    [ "$s_ns" -eq 0 ] || printf '; %s not-selected (record current)' "$s_ns"
    printf '\n'
  fi
}

# --- (e) the hook-driving fixtures, when the diff touches a hook or a script a hook names (BL-1069) -------------
# A change to either pre-push hook, or to a script either hook names, can break a fixture world that drives the
# hook, and the gate finds that only in the bundle. So when the diff from the merge-base with <base> to the work
# tree touches one of them, every hook-driving fixture runs here, through this tree's seed-verdict-store.sh at
# AI_DLC_FIXTURE_JOBS (the hook's default 12), and any red is a finding. Every pass lands in the counted store.
#   TRIGGER: .githooks/pre-push, core/git-hooks/pre-push, and every tracked path under scripts/ or core/scripts/
#     that either hook of $ROOT names (core/scripts/<x> also when named as the consumer's scripts/ai-dlc/<x>). A
#     name is a whole path: a letter, digit, `_`, `.` or `-` on either side, or a `/` after it, makes it part of a
#     longer name; a `/` before it is a directory prefix (`$ROOT/`). Its self-probe runs first.
#   SET: the fixtures whose shell files name a pre-push hook, plus backlog-real-ledger and hermetic-runner, kept
#     only where core/fixtures/<name>/run.sh exists; then, until a round adds none, every fixture whose shell files
#     name `<member>/run.sh` (a wrapper drives the hook through another fixture's run.sh).
printf '== e. hook-driving fixtures (when the diff touches a pre-push hook or a script one names)\n'
E_AWK='FNR == NR { C[++n] = $0; next }
{ T = T $0 "\n" }
function named(t, p,   s, k, b, a) {
  s = t
  while ((k = index(s, p)) > 0) {
    b = (k > 1) ? substr(s, k - 1, 1) : ""; a = substr(s, k + length(p), 1)
    if (b !~ /[A-Za-z0-9_.-]/ && a !~ /[A-Za-z0-9_.-]/) return 1
    s = substr(s, k + 1)
  }
  return 0
}
END { for (i = 1; i <= n; i++) { p = C[i]; q = p; if (sub(/^core\/scripts\//, "scripts/ai-dlc/", q) == 0) q = ""
        if (named(T, p) || (q != "" && named(T, q))) print p } }'
mkdir -p "$W/e/keep" || exit 2
printf '%s\n' core/scripts/x.sh core/scripts/y.sh core/scripts/z.sh core/scripts/w.sh > "$W/e/probe.cand"
printf '%s\n' 'bash core/scripts/x.sh' '"$ROOT/scripts/ai-dlc/y.sh" --check' 'cat core/scripts/z.shx' 'bash xcore/scripts/w.sh' > "$W/e/probe.hook"
e_probe="$(awk "$E_AWK" "$W/e/probe.cand" "$W/e/probe.hook" | tr '\n' ' ')"
if [ "$e_probe" != "core/scripts/x.sh core/scripts/y.sh " ]; then
  printf '   cannot run: the path matcher read "%s" on its seeded probe, expected "core/scripts/x.sh core/scripts/y.sh " -- it cannot be trusted on the hooks\n' "$e_probe" >&2
  exit 2
fi
E_MB="$(git merge-base HEAD "$BASE" 2>/dev/null)" \
  || { printf 'pregate-self-check: no merge-base between HEAD and %s, so the diff section e reads is unknown\n' "$BASE" >&2; exit 2; }
git diff --name-only "$E_MB" -- > "$W/e/changed" 2> "$W/e/err" \
  || { printf 'pregate-self-check: git diff against %s failed: %s\n' "$E_MB" "$(head -1 "$W/e/err")" >&2; exit 2; }
git ls-files -- scripts core/scripts > "$W/e/cand" || exit 2
: > "$W/e/hooks"
for h in .githooks/pre-push core/git-hooks/pre-push; do [ -f "$ROOT/$h" ] && printf '%s\n' "$h" >> "$W/e/hooks"; done
if [ -s "$W/e/cand" ]; then
  ( cd "$ROOT" && awk "$E_AWK" "$W/e/cand" $(cat "$W/e/hooks") ) > "$W/e/named" || exit 2
else : > "$W/e/named"; fi
e_hits="$(cat "$W/e/hooks" "$W/e/named" | awk 'NR == FNR { T[$0] = 1; next } ($0 in T)' - "$W/e/changed" | tr '\n' ' ')"
if [ -z "$e_hits" ]; then
  printf '   SKIPPED: the diff from %s touches neither pre-push hook nor any of the %s script(s) they name\n' \
    "$(git rev-parse --short "$E_MB")" "$(awk 'END { print NR }' "$W/e/named")"
else
  printf '   triggered by: %s\n' "$e_hits"
  git ls-files -- 'core/fixtures/*/run.sh' > "$W/e/runs" || exit 2
  e_ctl="$(git grep -l -e '' -- 'core/fixtures/*/run.sh' | awk 'END { print NR }')"
  if [ ! -s "$W/e/runs" ] || [ "$e_ctl" -ne "$(awk 'END { print NR }' "$W/e/runs")" ]; then
    printf '   cannot run: git grep over core/fixtures/*/run.sh read %s file(s), git lists %s\n' "$e_ctl" "$(awk 'END { print NR }' "$W/e/runs")" >&2
    exit 2
  fi
  { git grep -l -E 'githooks/pre-push|git-hooks/pre-push' -- 'core/fixtures/*/run.sh' 'core/fixtures/*/*.sh' | awk -F/ '{ print $3 }'
    printf '%s\n' backlog-real-ledger hermetic-runner
  } | sort -u | while IFS= read -r n; do [ -f "core/fixtures/$n/run.sh" ] && printf '%s\n' "$n"; done > "$W/e/set"
  e_base="$(awk 'END { print NR }' "$W/e/set")"
  [ "$e_base" -ge 1 ] || { printf '   cannot run: no fixture names a pre-push hook\n' >&2; exit 2; }
  # The wrapper pattern's self-probe, both directions: it must flag the two spellings a wrapper uses and pass over a
  # longer name and a different file.
  printf '%s\n' 'IMPL="$HERE/../m-1/run.sh"' '. "$EDIR/../m-1/run.sh"' 'x core/fixtures/m-1/run.sh' 'IMPL="$HERE/../m-1x/run.sh"' 'cat ../m-1/seed.sh' > "$W/e/probe.wrap"
  e_wp="$(grep -nE "(\.\./|core/fixtures/)(m-1)/run\.sh" "$W/e/probe.wrap" | cut -d: -f1 | tr '\n' ' ')"
  [ "$e_wp" = "1 2 3 " ] || { printf '   cannot run: the wrapper pattern read lines "%s" of its seeded probe, expected "1 2 3 "\n' "$e_wp" >&2; exit 2; }
  e_rounds=0
  while :; do
    e_pat="$(sed 's/[.]/\\./g' "$W/e/set" | paste -sd '|' -)"
    git grep -l -E "(\.\./|core/fixtures/)(${e_pat})/run\.sh" -- 'core/fixtures/*/*.sh' | awk -F/ '{ print $3 }' \
      | sort -u | while IFS= read -r n; do [ -f "core/fixtures/$n/run.sh" ] && printf '%s\n' "$n"; done > "$W/e/wrap"
    sort -u "$W/e/set" "$W/e/wrap" > "$W/e/next"
    e_rounds=$((e_rounds + 1))
    cmp -s "$W/e/next" "$W/e/set" && break
    mv "$W/e/next" "$W/e/set" || exit 2
  done
  e_n="$(awk 'END { print NR }' "$W/e/set")"
  E_JOBS="${AI_DLC_FIXTURE_JOBS:-12}"
  printf '   %s fixture(s): %s naming a hook or named by the ruling, %s wrapper(s) in %s round(s); %s-way\n' \
    "$e_n" "$e_base" "$((e_n - e_base))" "$e_rounds" "$E_JOBS"
  # ONLY WHAT THE PUSH WOULD RUN: $ROOT's scripts/predict-push-set.sh decides with the hook's own composer which of
  # the set lack a counted pass on their current key rows; the rest reuse theirs, as the push does. With no
  # prediction the whole set runs, and the line says so.
  pred_once
  if [ "$P_OK" = 1 ]; then
    awk 'NR == FNR { R[$0] = 1; next } ($0 in R)' "$W/e/predrun" "$W/e/set" > "$W/e/torun"
    e_k="$(awk 'END { print NR }' "$W/e/torun")"
    printf '   predict-push-set.sh: %s of %s hold a counted pass on their current key rows (reused); %s to run\n' \
      "$((e_n - e_k))" "$e_n" "$e_k"
  else
    cp "$W/e/set" "$W/e/torun" || exit 2
    e_k="$e_n"
    printf '   PREDICTION UNAVAILABLE (%s): running all %s\n' \
      "$( [ -f "$E_PRED" ] && { head -1 "$W/e/pred.err" 2>/dev/null; true; } || echo "no $E_PRED")" "$e_n"
  fi
  e_reused=""
  [ "$P_OK" = 1 ] && e_reused="all $e_n selected unit(s) hold a counted pass on their current key rows (reused); 0 to run"
  seed_set "$W/e" "$E_JOBS" "$e_k" e:hook-fixtures "" "$e_reused"
fi

# --- (f) every fixture the push would run that reaches a changed script or fixture path (BL-1122, BL-1129) ----------------------
# A change to a script's child starts moves the `<n> *` J3 row of EVERY fixture that runs the script, whether its
# invocations.decl rows the child or not, and whether it names the script or sweeps its whole directory. So when the
# diff from the merge-base with <base> to the work tree touches a `*.sh` path under core/scripts, scripts, core/hooks, core/skills (nested included: a git pathspec `*` matches `/`), core/session-driver (added,
# modified or deleted), every fixture of predict-push-set's RUN set that reaches one runs here, through this tree's
# seed-verdict-store.sh at AI_DLC_FIXTURE_JOBS, and any red is a finding. Every pass lands in the counted store, so the
# push reuses it. The member set (a `<fx>@consumer` unit by its fixture's routes) is the RUN fixtures with any route:
#   DIR       a D row of the composer's own parse (predict-push-set's out/.dparse, readset_decl_parse) is a directory
#             holding a changed path;
#   DECLFILE  an F row of that parse is a changed path;
#   OWN       a changed path under core/fixtures/<base>/ (a D row never names a fixture's own directory); every changed
#             core/fixtures path also feeds DECLFILE (a shard's F row for its parent's run.sh), changed cells.decl paths
#             DIR (another fixture's inputs.decl is not keyed through a directory), never NAME;
#   NAME      a shell file under core/fixtures/<fx>/ names a changed script's basename, bounded as section e bounds a
#             name (a `/` before it is a directory prefix).
# Units section e already ran are not run again. Its self-probe runs first, both directions. With no prediction, or a
# non-empty RUN set and no parse, the section cannot know what the push measures: a refusal.
printf '== f. fixtures that reach a changed script or fixture path (when the diff touches a *.sh under core/scripts, scripts, core/hooks, core/skills, core/session-driver, or any path under core/fixtures)\n'
F_AWK='FILENAME == ARGV[1] { C[++nc] = $0; B[nc] = $0; sub(/.*\//, "", B[nc]); K[++nk] = $0; L[++nl] = $0; next }
FILENAME == ARGV[2] { X[++nx] = $0; K[++nk] = $0; if ($0 ~ /\/cells\.decl$/) L[++nl] = $0; next }
FILENAME == ARGV[3] { u = $0; b = u; sub(/@consumer$/, "", b); if (!(u in U)) { U[u] = 1; O[++no] = u; OB[no] = b; R[b] = 1 }; next }
FILENAME == ARGV[4] { n = split($0, f, "\t"); if (n < 3 || !(f[1] in R)) next
  for (i = 1; i <= nl; i++) if (f[2] == "D" && index(L[i], f[3] "/") == 1 && !((f[1], "D", f[3]) in G)) { G[f[1], "D", f[3]] = 1; why[f[1]] = why[f[1]] " DIR:" f[3] }
  for (i = 1; i <= nk; i++) if (f[2] == "F" && K[i] == f[3] && !((f[1], "F", f[3]) in G)) { G[f[1], "F", f[3]] = 1; why[f[1]] = why[f[1]] " DECLFILE:" f[3] }
  next }
{ split(FILENAME, q, "/"); x = q[3]; if (q[1] != "core" || q[2] != "fixtures" || !(x in R)) next
  for (i = 1; i <= nc; i++) if (!((x, "N", B[i]) in G) && named($0, B[i])) { G[x, "N", B[i]] = 1; why[x] = why[x] " NAME:" B[i] } }
function named(t, p,   s, k, b, a) {
  s = t
  while ((k = index(s, p)) > 0) {
    b = (k > 1) ? substr(s, k - 1, 1) : ""; a = substr(s, k + length(p), 1)
    if (b !~ /[A-Za-z0-9_.-]/ && a !~ /[A-Za-z0-9_.-]/) return 1
    s = substr(s, k + 1)
  }
  return 0
}
END { for (i = 1; i <= nx; i++) { split(X[i], q, "/")
    # OWN: a changed path under core/fixtures/<base>/ selects that RUN unit (narrow to inputs.decl and cells.decl by testing q[4]).
    if (q[1] == "core" && q[2] == "fixtures" && q[4] != "" && (q[3] in R) && !((q[3], "O", X[i]) in G)) { G[q[3], "O", X[i]] = 1; why[q[3]] = why[q[3]] " OWN:" X[i] } }
  for (k = 1; k <= no; k++) {
  ud = ((getline l < ("core/fixtures/" OB[k] "/.undeclarable")) >= 0); close("core/fixtures/" OB[k] "/.undeclarable")
  if (OB[k] in why) print O[k] "\t" substr(why[OB[k]], 2) (ud ? " UNDECLARABLE" : "")
  else if (ud) print O[k] "\tUNDECLARABLE" } }'
mkdir -p "$W/f/keep" "$W/f/probe/core/fixtures/fname" "$W/f/probe/core/fixtures/fnear" "$W/f/probe/core/fixtures/fout" "$W/f/probe/core/fixtures/fund" || exit 2
# fund is undeclarable and names no changed path: selected by UNDECLARABLE alone. fout carries .undeclarable too but is not in the RUN set.
# The probe: fnear sorts LAST in the RUN set and carries every near-miss (a longer directory, a longer file name, a
# longer basename on both sides); fout reaches x.sh by all three routes but is not in the RUN set.
printf '%s\n' core/scripts/x.sh > "$W/f/probe.changed"
printf '%s\n' fdir ffile fname fname@consumer fund fnear > "$W/f/probe.run0"; : > "$W/f/probe.nochanged"
printf 'fdir\tN\nfdir\tD\tcore/scripts\t1\tcore/scripts\nffile\tF\tcore/scripts/x.sh\t0\tcore/scripts/x.sh\nfnear\tD\tcore/scriptsx\t1\tcore/scriptsx\nfnear\tF\tcore/scripts/x.shx\t1\tcore/scripts/x.shx\nfout\tD\tcore/scripts\t1\tcore/scripts\nfout\tF\tcore/scripts/x.sh\t1\tcore/scripts/x.sh\nfhold\tF\tcore/fixtures/fdecl/inputs.decl\t1\tx\nfnh\tF\tcore/fixtures/fdecl/inputs.decls\t1\tx\nfdh\tD\tcore/fixtures/fcell\t1\tx\nfdn\tD\tcore/fixtures/fcellx\t1\tx\nfdi\tD\tcore/fixtures/fdecl\t1\tx\nfshard\tF\tcore/fixtures/fpar/run.sh\t1\tx\n' > "$W/f/probe.dparse"
printf '%s\n' 'bash "$ROOT/core/scripts/x.sh" --check' > "$W/f/probe/core/fixtures/fname/run.sh"
printf '%s\n' 'bash core/scripts/wx.sh' 'cat core/scripts/x.shy' > "$W/f/probe/core/fixtures/fnear/run.sh"
printf '%s\n' 'bash core/scripts/x.sh' > "$W/f/probe/core/fixtures/fout/run.sh"
printf '%s\n' 'true' > "$W/f/probe/core/fixtures/fund/run.sh"
: > "$W/f/probe/core/fixtures/fund/.undeclarable"; : > "$W/f/probe/core/fixtures/fout/.undeclarable"
f_probe="$( cd "$W/f/probe" && awk "$F_AWK" "$W/f/probe.changed" "$W/f/probe.nochanged" "$W/f/probe.run0" "$W/f/probe.dparse" core/fixtures/fname/run.sh core/fixtures/fnear/run.sh core/fixtures/fout/run.sh core/fixtures/fund/run.sh | cut -f1 | tr '\n' ' ')"
# The DECLFILE feed: fhold holds an F row for fdecl/inputs.decl, fshard one for its parent fpar/run.sh (both selected), fnh a near-miss F.
# The DIR feed: fdh holds a D row over fcell, whose cells.decl changed (selected); fdn is a near-miss D, and fdi a D over fdecl, whose
# changed inputs.decl must not feed DIR (not selected).
# The OWN probe (.sh list empty): fdecl, fcell, fcell@consumer, finv, frun are RUN units; fdeclx and fnone are not. Own inputs.decl,
# cells.decl, invocations.decl and run.sh select their unit; a neighbour fdeclx and an outside-RUN fnone select nothing, and
# fdecl/run.sh naming inputs.decl is no NAME hit.
mkdir -p "$W/f/probe/core/fixtures/fdecl" || exit 2
printf '%s\n' 'cat core/fixtures/fdeclx/inputs.decl inputs.decl' > "$W/f/probe/core/fixtures/fdecl/run.sh"
printf '%s\n' fdir ffile fname fname@consumer fund fnear fdecl fcell fcell@consumer finv frun fhold fnh fdh fdn fdi fshard > "$W/f/probe.run"
printf '%s\n' core/fixtures/fdecl/inputs.decl core/fixtures/fcell/cells.decl core/fixtures/finv/invocations.decl core/fixtures/frun/run.sh core/fixtures/fpar/run.sh > "$W/f/probe.decl1"
printf '%s\n' core/fixtures/fdeclx/inputs.decl core/fixtures/fnone/inputs.decl > "$W/f/probe.decl2"
f_probe="$f_probe|$( cd "$W/f/probe" && awk "$F_AWK" "$W/f/probe.nochanged" "$W/f/probe.decl1" "$W/f/probe.run" "$W/f/probe.dparse" core/fixtures/fdecl/run.sh | cut -f1 | tr '\n' ' ')"
f_probe="$f_probe|$( cd "$W/f/probe" && awk "$F_AWK" "$W/f/probe.nochanged" "$W/f/probe.decl2" "$W/f/probe.run" "$W/f/probe.dparse" core/fixtures/fdecl/run.sh | cut -f1 | tr '\n' ' ')"
f_want="fdir ffile fname fname@consumer fund |fund fdecl fcell fcell@consumer finv frun fhold fdh fshard |fund "
if [ "$f_probe" != "$f_want" ]; then
  printf '   cannot run: the route matcher read "%s" on its seeded probe, expected "%s" -- it cannot be trusted on the RUN set\n' "$f_probe" "$f_want" >&2
  exit 2
fi
git diff --name-only --no-renames "$E_MB" -- 'core/scripts/*.sh' 'scripts/*.sh' 'core/hooks/*.sh' 'core/skills/*.sh' 'core/session-driver/*.sh' > "$W/f/changed" 2> "$W/f/err" \
  || { printf 'pregate-self-check: git diff against %s failed: %s\n' "$E_MB" "$(head -1 "$W/f/err")" >&2; exit 2; }
git diff --name-only --no-renames "$E_MB" -- 'core/fixtures/*' > "$W/f/decl" 2> "$W/f/err" \
  || { printf 'pregate-self-check: git diff against %s failed: %s\n' "$E_MB" "$(head -1 "$W/f/err")" >&2; exit 2; }
f_nc="$(awk 'END { print NR }' "$W/f/changed")"
f_nd="$(awk 'END { print NR }' "$W/f/decl")"
if [ "$f_nc" -eq 0 ] && [ "$f_nd" -eq 0 ]; then
  printf '   SKIPPED: the diff from %s touches no shell path a fixture can reach (core/scripts, scripts, core/hooks, core/skills, core/session-driver: *.sh) and no fixture path under core/fixtures, so no changed script or fixture path is reached\n' "$(git rev-parse --short "$E_MB")"
else
  printf '   %s changed script(s): %s\n' "$f_nc" "$(tr '\n' ' ' < "$W/f/changed")"
  printf '   %s changed fixture path(s)\n' "$f_nd"
  pred_once
  [ "$P_OK" = 1 ] || { printf '   cannot run: no prediction of the RUN set (%s), so the fixtures a push measures are unknown\n' \
    "$( [ -f "$E_PRED" ] && { head -1 "$W/e/pred.err" 2>/dev/null; true; } || echo "no $E_PRED")" >&2; exit 2; }
  f_run="$(awk 'END { print NR }' "$W/e/predrun")"
  if [ "$f_run" -gt 0 ] && [ ! -f "$W/e/pred/out/.dparse" ]; then
    printf '   cannot run: predict-push-set.sh named %s RUN unit(s) but wrote no parse (%s), so no DIR or DECLFILE route can be read\n' "$f_run" "$W/e/pred/out/.dparse" >&2
    exit 2
  fi
  if [ -f "$W/e/pred/out/.dparse" ]; then cp "$W/e/pred/out/.dparse" "$W/f/dparse" || exit 2; else : > "$W/f/dparse"; fi
  sed 's/@consumer$//' "$W/e/predrun" | sort -u | sed 's|.*|core/fixtures/&/*.sh|' > "$W/f/globs"
  set -f
  if [ -s "$W/f/globs" ]; then git ls-files -- $(cat "$W/f/globs") > "$W/f/sh" || { set +f; exit 2; }; else : > "$W/f/sh"; fi
  awk "$F_AWK" "$W/f/changed" "$W/f/decl" "$W/e/predrun" "$W/f/dparse" $(cat "$W/f/sh") > "$W/f/sel" || { set +f; exit 2; }
  set +f
  f_sel="$(awk 'END { print NR }' "$W/f/sel")"
  : > "$W/f/done"; [ -f "$W/e/torun" ] && cp "$W/e/torun" "$W/f/done"
  # Keyed on FILENAME, never NR == FNR: an empty done file (section e ran nothing) would read the selection as itself.
  cut -f1 "$W/f/sel" | awk 'FILENAME == ARGV[1] { D[$0] = 1; next } !($0 in D)' "$W/f/done" - > "$W/f/torun"
  f_k="$(awk 'END { print NR }' "$W/f/torun")"
  F_JOBS="${AI_DLC_FIXTURE_JOBS:-12}"
  # The drop runs before the count line, so "to run" excludes undeclared units; its lines print after the selection.
  drop_undeclared "$W/f" > "$W/f/undeclared"
  printf '   predict-push-set.sh: %s of %s RUN unit(s) reach a changed script or fixture path (DIR %s, DECLFILE %s, NAME %s, OWN %s); %s already run in section e; %s to run, %s-way\n' \
    "$f_sel" "$f_run" "$(grep -c 'DIR:' "$W/f/sel")" "$(grep -c 'DECLFILE:' "$W/f/sel")" "$(grep -c 'NAME:' "$W/f/sel")" "$(grep -c 'OWN:' "$W/f/sel")" \
    "$((f_sel - f_k))" "$((f_k - u_drop))" "$F_JOBS"
  awk -F'\t' '{ printf "     %s  %s\n", $1, $2 }' "$W/f/sel"
  while IFS= read -r u_line; do printf '%s\n' "$u_line"; done < "$W/f/undeclared"
  f_why="no RUN unit that reaches a changed script is left to run"
  [ "$u_drop" -eq 0 ] || f_why="every selected unit is undeclared and runs plain in the push"
  seed_set "$W/f" "$F_JOBS" "$((f_k - u_drop))" f:reached-fixtures "$f_why"
  # An `.undeclarable` fixture has no inputs.decl, so the drop above leaves it out of the seed: it runs plain here, as
  # the push runs it, from the repo root.
  awk -F'\t' '$2 ~ /UNDECLARABLE/ && $1 !~ /@consumer$/ { print $1 }' "$W/f/sel" > "$W/f/plain"
  f_pl_red=""
  while IFS= read -r u_pl; do
    if bash "core/fixtures/$u_pl/run.sh" < /dev/null > "$W/f/keep/$u_pl.plain.out" 2>&1; then printf '     %s plain rc=0\n' "$u_pl"
    else printf '     %s plain rc=1\n' "$u_pl"; f_pl_red="$f_pl_red $u_pl"; tail -5 "$W/f/keep/$u_pl.plain.out" | sed 's/^/       /'; fi
  done < "$W/f/plain"
  [ -z "$f_pl_red" ] || { printf '   FAIL: undeclarable fixture(s) red:%s\n' "$f_pl_red"; note_fail f:undeclarable-fixtures; }
fi

printf '\n'
done_=1
if [ "$fail" -ne 0 ]; then
  printf 'pregate-self-check: FINDINGS in %s\n' "$fail_checks" >&2
  exit 1
fi
printf 'pregate-self-check: clean against %s\n' "$BASE"
if [ "$MEMBER" = 1 ]; then # member: no pregate record
  printf 'pregate-self-check: member mode wrote no pregate record: this pass is not the gate; a push of this tree still needs a green run without --member where the hook a push runs equals the tree'"'"'s\n'
  exit 0
fi
PG_END="$(pg_state)" || PG_END=""
# A clean state is the tree line alone (an empty status adds nothing once $( ) strips the trailing newline).
pg_tree="${PG_START%%
*}"
if [ -n "$PG_START" ] && [ "$PG_START" = "$pg_tree" ] && [ "$PG_END" = "$PG_START" ]; then
  # THE RECORD'S HOME IS THE HOOK'S OWN RECORD_HOME span (the hook a push runs equals $ROOT's here), so the gate and
  # this writer resolve one path. A record that cannot be written is a refusal (exit 2), never a clean exit.
  pg_dir=""
  eval "$(sed -n '/^# READSET_VS_BEGIN$/,/^# READSET_VS_END$/p;/^# RECORD_HOME_BEGIN$/,/^# RECORD_HOME_END$/p' "$ROOT/.githooks/pre-push")"
  { rec_home pg_dir pregate-green && [ "$pg_dir" != "$REC_OFF" ]; } 2>/dev/null && mkdir -p "$pg_dir" \
    && printf '#format pg1\ntree %s\nbase %s\nwhen %s\n' "$pg_tree" "$(git rev-parse "${BASE}^{commit}")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$pg_dir/$pg_tree.tmp" \
    && mv -f "$pg_dir/$pg_tree.tmp" "$pg_dir/$pg_tree" \
    && printf 'pregate-self-check: recorded green for tree %s in %s; a push delivering it may proceed\n' "$pg_tree" "$pg_dir" \
    || { printf 'pregate-self-check: could not write the pregate record for tree %s under %s (the verdict store is OFF when that reads %s); a push of it will be refused\n' "$pg_tree" "${pg_dir:-<unresolved>}" "${REC_OFF:-<no RECORD_HOME span>}" >&2; exit 2; }
else
  printf 'pregate-self-check: NO RECORD written: the work tree was not clean, or moved, during this run; a push of it will be refused\n' >&2
fi
exit 0
}
# Loadable: sourced, this file defines psc_main and runs nothing; executed, it runs it (core/fixtures/lib/inproc.sh).
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
psc_main "$@"
