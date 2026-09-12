#!/usr/bin/env bash
# backlog-receipt-binding -- exercise scripts/validate-backlog-receipts.sh, the arm that scores
# every live `verify: sh` receipt against a comment carrying that receipt's own grep literals.
#
# AN UNMUTATED CONTROL PLUS EIGHT MUTANTS, each driven against a throwaway repository under a
# temp dir. Exit 0 iff the control is green AND every mutant is killed by its own assertion.
#
# EVERY MUTANT IS KILLED BY A BEHAVIOURAL ARM AND NOT BY A BYTE-LOCK ON A SPELLING. What each
# one asserts is a VERDICT the subject produces over a seeded ledger -- a receipt classified,
# a count moved, an exit code -- so any implementation that gets the behaviour right passes and
# any that does not fails, whatever it looks like.
#
# FIVE THINGS HERE ARE A DELIBERATE COPY FROM core/fixtures/backlog-size-ceiling/run.sh, NOT AN
# INDEPENDENT INVENTION, AND THE COPY IS THE POINT. `seed()`, the env-passing runner, the
# `kill_check` shape, the `cmp -s` guard on every mutation, and the "assert the FAIL-line COUNT,
# not just the message" rule are that file's, worked out against sixteen probes over several
# releases -- and they are that file's copy of claude-rules-joins/run.sh in turn. Re-deriving
# them here would produce a third, weaker harness whose bugs nobody finds. They are copied
# rather than sourced because a fixture that sources a sibling cannot be run alone, and the
# suite's pool dispatches directories independently.
#
# EVERY MUTATION IS BYTE-COMPARED BEFORE ITS VERDICT IS READ. A mutant keyed on a token the
# target does not contain is a NO-OP that comes back green and reads exactly like a mutant that
# survived. Measured in this very file's development: two `sed` anchors matched nothing after
# the subject was reshaped, and both runs passed until the guard was added.
#
# WHY THE CONTROL IS NOT DECORATION. Each probe is a fresh seed plus one edit, and the subject
# resolves its own root by walking up for VERSION and sources reconcile/lib.sh beside it. A
# seed that fails to build makes the subject exit 2 having printed nothing, and "no output"
# would otherwise score as a kill on every probe below. The control is also PRESENCE-shaped --
# it demands the OK line and a named classification -- because a control asserting only
# rc=0-and-no-findings passes against a subject replaced by `exit 0`.
#
# THE PROBE LEDGERS ARE SEEDED FROM WHAT AN AUTHOR WRITES, NEVER FROM WHAT THE SUBJECT ACCEPTS.
# Each receipt below is a shape that exists in the real ledger: a literal grep against a file,
# a receipt that drives a script and reads its output, a precondition guard that exits 9, a
# predicate built from a variable.
#
# Usage: run.sh
# Exit:  0 = every probe holds, 1 = one regressed, 2 = fixture broken.
set -u

# CLEAR EVERY AMBIENT AI_DLC_* KEY BEFORE ANY PROBE RUNS, and I87 fails the push without it.
# This fixture parameterises the ceilings by passing them as `env` words into each run, but it
# passes them double-quoted, which I87's assignment scan does not recognise as an assignment --
# and correctly so: an assignment inside ONE invocation says nothing about the probes that do
# NOT set it. Those would otherwise read the operator's .claude/settings.json, so a probe
# asserting a DEFAULT would assert whatever that file happens to say: passing for the wrong
# reason here and failing on a build machine set differently.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# SCRUB THE REPOSITORY ENVIRONMENT BEFORE THIS FIXTURE BUILDS ANYTHING. Every probe below runs
# `git init` in a `mktemp` tree and relies on git's upward DISCOVERY to find it. Git exports
# GIT_DIR, ABSOLUTE, into any hook running from a linked worktree, so a suite dispatched by an
# unscrubbed caller -- or an operator running this file by hand, which is what the repo's own
# rules say to do when debugging a fixture -- has `git init` SILENTLY SUCCEED WITHOUT CREATING
# A REPOSITORY and every later git call write the CALLER's index. This fixture's subject then
# adds worktrees to the caller's repository rather than to the probe's, which is the same
# defect with a larger blast radius.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

DIR="$(cd "$(dirname "$0")" && pwd)"

# Both install layouts named, the way I33c requires: a chain rooted at the fixture's own
# location and naming only one layout passes I33 and I33b and is the identical consumer-side
# failure.
VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-backlog-receipts.sh" \
  "$DIR/../../../scripts/validate-backlog-receipts.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FIXTURE BROKEN: could not locate validate-backlog-receipts.sh" >&2; exit 2
fi

LIBSRC=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/lib.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/lib.sh"; do
  [ -f "$cand" ] && LIBSRC="$cand" && break
done
if [ -z "$LIBSRC" ]; then
  echo "FIXTURE BROKEN: could not locate reconcile/lib.sh" >&2; exit 2
fi

# The file the subject's R0 arm binds its path-split class to. Resolved here because a probe
# tree without it makes the subject exit 2 for a reason no probe below is about.
REVSRC=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
  [ -f "$cand" ] && REVSRC="$cand" && break
done
if [ -z "$REVSRC" ]; then
  echo "FIXTURE BROKEN: could not locate reconcile/ledger-reverify.sh" >&2; exit 2
fi

# The shipping classifier and the real ledger, for the population join.
REVERIFY=""; REAL_LEDGER=""
for cand in "$DIR/../../../scripts/backlog-reverify.sh" "$DIR/../../scripts/backlog-reverify.sh"; do
  [ -f "$cand" ] && REVERIFY="$cand" && break
done
for cand in "$DIR/../../../docs/backlog.md" "$DIR/../../docs/backlog.md"; do
  [ -f "$cand" ] && REAL_LEDGER="$cand" && break
done

TMP="$(mktemp -d)"
# A PROBE REPOSITORY REGISTERS ITS OWN WORKTREES, and the subject removes them; this catches
# a subject that did not, so a leak is cleaned up rather than left in $TMPDIR.
cleanup() {
  for _r in "$TMP"/*; do
    [ -d "$_r/.git" ] && git -C "$_r" worktree prune >/dev/null 2>&1
  done
  rm -rf "$TMP"
}
trap cleanup EXIT
rc=0
note() { printf '%s\n' "$*"; }

# --- the seed ---------------------------------------------------------------
# A throwaway REPOSITORY, because the subject checks each receipt out of HEAD. A plain
# directory would make every receipt exit 2 for a reason no probe here is about.
#
# THE LEDGER'S SIX RECEIPTS ARE SIX BRANCHES OF THE SCORER, and each names a different
# subject file so no two probes can cover each other:
#   BL-801  greps a literal        -> PROSE-CLOSABLE   (the finding)
#   BL-802  drives a script        -> BOUND            (the near-miss)
#   BL-803  exits 9 at a guard     -> OUT-OF-POPULATION
#   BL-804  pattern from a var     -> UNSCORABLE
#   BL-805  base 0                 -> ALREADY-PASSING  (a 0 -> 1 flip is not a finding)
#   BL-806  reads git              -> PROSE-CLOSABLE, and its base exit proves the checkout
#                                     is a real repository rather than a bare extraction
seed() { # seed <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile" "$d/probe"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-backlog-receipts.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVSRC" "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
  printf 'alpha\nbeta\n' > "$d/probe/subject.txt"
  printf 'gamma\n' > "$d/probe/driven.txt"
  printf 'delta\n' > "$d/probe/guarded.txt"
  printf 'epsilon\n' > "$d/probe/varpat.txt"
  printf 'zeta\n' > "$d/probe/passing.txt"
  printf 'eta\n' > "$d/probe/gitsub.txt"
  printf '#!/usr/bin/env bash\nprintf %%s\\\\n WAIT\n' > "$d/probe/tool.sh"
  bl_seed_ledger "$d/docs/backlog.md"
  (
    cd "$d" && git init -q . >/dev/null 2>&1 \
      && git add -A >/dev/null 2>&1 \
      && git -c user.email=p@local -c user.name=p commit -q -m seed >/dev/null 2>&1
  )
  # ASSERT THE REPOSITORY EXISTS rather than assuming `git init` worked: under an inherited
  # GIT_DIR it exits 0 and creates nothing, and every probe would then run against the caller.
  [ -d "$d/.git" ] || { echo "FIXTURE BROKEN: the probe repository at $d has no .git" >&2; exit 2; }
}

bl_seed_ledger() { # bl_seed_ledger <file>
  {
    printf '# Probe backlog\n\nPreamble prose mentioning BL- ids.\n\n'
    printf '## BL-801\n\nBody.\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'MARK801'"
    printf '## BL-802\n\nBody.\n\nverify: sh o="$(bash probe/tool.sh)"; grep -q %s <<<"$o"\n\n' "'READY802'"
    printf '## BL-803\n\nBody.\n\nverify: sh grep -q %s probe/guarded.txt || exit 9\n\n' "'MARK803'"
    printf '## BL-804\n\nBody.\n\nverify: sh S=%s; grep -q "$S" probe/varpat.txt\n\n' "MARK804"
    printf '## BL-805\n\nBody.\n\nverify: sh ! grep -q %s probe/passing.txt\n\n' "'MARK805'"
    printf '## BL-806\n\nBody.\n\nverify: sh git rev-parse HEAD >/dev/null 2>&1 || exit 9; grep -q %s probe/gitsub.txt\n\n' "'MARK806'"
  } > "$1"
}

# The subject takes a whitespace-separated env list because some probes pin a ceiling. The
# split is the point of the function, not an oversight.
# shellcheck disable=SC2086
run_v() { # run_v <env-string-or-empty> <dir> [<extra-args>...]
  local e="$1" d="$2"; shift 2
  ( cd "$d" && env $e bash scripts/validate-backlog-receipts.sh "$@" 2>&1 )
}

# The default arguments every probe uses unless it is pinning something. The seeded ledger has
# TWO prose-closable receipts -- BL-801 and BL-806 -- so 2 is the AT-the-ceiling passing state
# and 1 is one over. Both sides are exercised, because an off-by-one written as `-ge` is green
# on the failing side alone.
BL_PC=2
DEF="--max-prose-closable $BL_PC --max-unscorable 9 --max-out-of-population 9 --min-sh-receipts 6 --min-entries 6"

# Reads a receipt's classification back out of the subject's OWN row grammar. Empty if the
# subject never classified it, which every caller treats as a failure rather than as a zero.
cls() { # cls <output> <id>
  printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$2 == id { print $1 }' | sed -n '1p'
}

# THE STRONGEST ASSERTION IN THIS FILE, AND IT IS NOT A KILL. A battery that only asserts "the
# subject stayed quiet" cannot tell a scorer that classified six receipts correctly from one
# that classified two and missed four -- both are silent at a slack ceiling. Asserting the
# CLASSIFICATION of every seeded receipt catches every one of those in one comparison, and the
# fixture never restates the predicate: it reads the subject's own rows back.
class_check() { # class_check <name> <dir> <env> [<extra-args>...]
  local n="$1" d="$2" e="$3"; shift 3
  local out rc_v bad=""
  out="$(run_v "$e" "$d" $DEF "$@")"; rc_v=$?
  if [ "$rc_v" -ne 0 ]; then
    note "FAIL  $n -- the subject exited $rc_v on a tree that must pass"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  if ! grep -qF "OK: validate-backlog-receipts" <<<"$out"; then
    note "FAIL  $n -- no OK line, so the subject observed nothing and the quiet is not a reading"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  for want in "BL-801=PROSE-CLOSABLE" "BL-803=OUT-OF-POPULATION" \
              "BL-804=UNSCORABLE" "BL-805=ALREADY-PASSING" "BL-806=PROSE-CLOSABLE"; do
    id="${want%%=*}"; exp="${want#*=}"; got="$(cls "$out" "$id")"
    [ "$got" = "$exp" ] || bad="$bad $id(want=$exp got=${got:-NONE})"
  done
  # BL-802 IS ASSERTED BY ITS ABSENCE FROM THE ROWS AND ITS PRESENCE IN THE COUNT, because a
  # BOUND receipt is deliberately not reported by name -- naming every honest receipt would
  # bury the findings. Absence alone would be satisfied by a subject that never scored it at
  # all, so the count from the subject's own OK line is asserted too, and it is the conjunct
  # that a dropped receipt fails.
  [ -z "$(cls "$out" BL-802)" ] || bad="$bad BL-802(a bound receipt must not be reported by name, got $(cls "$out" BL-802))"
  local nbound
  nbound="$(printf '%s\n' "$out" | sed -n 's/^SUMMARY .*bound=\([0-9][0-9]*\) .*/\1/p')"
  [ "${nbound:-0}" -eq 1 ] || bad="$bad bound-count(want=1 got=${nbound:-NONE})"
  if [ -n "$bad" ]; then
    note "FAIL  $n -- the subject misclassified:$bad"
    rc=1; return
  fi
  note "ok    $n -- all six seeded receipts classified as the seed wrote them"
}

kill_check() { # kill_check <name> <dir> <env> <nfail> <substr> [<extra-args>...]
  local n="$1" d="$2" e="$3" want="$4" pat="$5"; shift 5
  local out rc_v nfail
  out="$(run_v "$e" "$d" $DEF "$@")"; rc_v=$?
  nfail="$(printf '%s\n' "$out" | grep -c '^FAIL:')"
  if [ "$rc_v" -eq 0 ]; then note "FAIL  $n -- probe SURVIVED (the subject exited 0)"; rc=1; return; fi
  if [ "$rc_v" -eq 2 ]; then
    note "FAIL  $n -- the subject exited 2 (environment/self-probe), which is not this probe's assertion"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    note "FAIL  $n -- the subject failed, but not on this probe's assertion (wanted: $pat)"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1; return
  fi
  if [ "$nfail" -ne "$want" ]; then
    note "FAIL  $n -- $nfail FAIL lines, expected $want"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/      /' | head -4; rc=1; return
  fi
  note "ok    $n -- killed by its own assertion, and by exactly that many"
}

# mut <dir> <sed-expression> -- mutate the seeded copy of the subject IN PLACE and assert the
# edit applied. A `sed` that matched nothing is a mutant that never existed, and its "survived"
# reads exactly like a guard that does not work.
mut() { # mut <dir> <sed-expr>
  # TWO STATEMENTS, NOT ONE. `local` is a COMMAND, so every word on its line is expanded
  # before any of its assignments takes effect -- `local d="$1" f="$d/x"` reads `$d` from the
  # enclosing scope, which under `set -u` is an unbound-variable abort with no verdict.
  local d="$1" expr="$2"
  local f="$d/scripts/validate-backlog-receipts.sh"
  cp "$f" "$f.orig"
  sed "$expr" "$f.orig" > "$f" || { note "FAIL  mutation sed DIED, so no mutant exists"; rc=1; rm -f "$f.orig"; return 1; }
  if cmp -s "$f" "$f.orig"; then
    note "FAIL  the mutation was a NO-OP: the subject is byte-identical, so any verdict below means nothing"
    rc=1; rm -f "$f.orig"; return 1
  fi
  rm -f "$f.orig"
  return 0
}

# --- unmutated control ------------------------------------------------------
seed "$TMP/control"
class_check "control -- clean seed passes and every receipt is classified" "$TMP/control" ""

# The control above is the harness's liveness proof. If it did not hold, every mutant below
# would be scored against a subject that never ran, and two inert runs compare equal.
if [ "$rc" -ne 0 ]; then
  note "FIXTURE BROKEN: the unmutated control did NOT pass. Every probe verdict below is meaningless."
  exit 1
fi

# ===== M1. THE SEED DROPS THE RECEIPT'S OWN TOKENS. ========================================
# A generic comment flips nothing -- measured at zero of the live receipts -- so a subject
# seeding one is an arm that cannot fire, reading exactly like a clean ledger. Its own R1
# self-probe must refuse before the corpus is reached, which is why the assertion is exit 2
# and a SELF-PROBE message, not a changed count.
seed "$TMP/m1"
if mut "$TMP/m1" 's|^  GENERIC_LINE="# probe"|  GENERIC_LINE="# probe"; SEED_LINE="# probe"|'; then
  m1_out="$(run_v "" "$TMP/m1" $DEF)"; m1_rc=$?
  if [ "$m1_rc" -ne 2 ]; then
    note "FAIL  m1 seed drops the tokens -- the subject exited $m1_rc, not 2. A seed carrying no token flips nothing, so this must be refused before the corpus, not reported as a clean one."
    printf '%s\n' "$m1_out" | sed 's/^/      /' | head -4; rc=1
  elif ! grep -qF "SELF-PROBE FAILED" <<<"$m1_out"; then
    note "FAIL  m1 seed drops the tokens -- exited 2 but not on the self-probe's assertion"
    printf '%s\n' "$m1_out" | sed 's/^/      /' | head -4; rc=1
  elif grep -qF "OK: validate-backlog-receipts" <<<"$m1_out"; then
    note "FAIL  m1 seed drops the tokens -- the subject reported an OK line anyway; the self-probe ran AFTER the corpus"; rc=1
  else
    note "ok    m1 -- a token-free seed is refused by the self-probe, before the corpus"
  fi
fi

# ===== M2. THE CEILING COMPARISON IS `-ge`. ================================================
# "exceeds the ceiling" means a corpus AT the ceiling is legal. Both directions are asserted in
# the same probe: an off-by-one is green on the failing side alone.
seed "$TMP/m2a"
class_check "m2a exactly AT the ceiling ($BL_PC) passes" "$TMP/m2a" ""
seed "$TMP/m2b"
kill_check "m2b one OVER the ceiling ($(( BL_PC - 1 ))) fails" "$TMP/m2b" "" 1 \
  "are satisfied by a COMMENT" --max-prose-closable "$(( BL_PC - 1 ))"
seed "$TMP/m2c"
if mut "$TMP/m2c" 's|^if \[ "$N_PC" -gt "$MAX_PC" \]; then|if [ "$N_PC" -ge "$MAX_PC" ]; then|'; then
  m2_out="$(run_v "" "$TMP/m2c" $DEF)"; m2_rc=$?
  if [ "$m2_rc" -eq 0 ]; then
    note "FAIL  m2c -ge instead of -gt SURVIVED: a corpus exactly AT the ceiling still passed, so the comparison is not what decides."; rc=1
  elif ! grep -qF "are satisfied by a COMMENT" <<<"$m2_out"; then
    note "FAIL  m2c -ge instead of -gt -- the subject failed, but not on the prose-closable ceiling"
    printf '%s\n' "$m2_out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1
  else
    note "ok    m2c -- an off-by-one at the ceiling is killed by the AT-the-ceiling case"
  fi
fi

# ===== M3. A BASE EXIT OF 9 IS COUNTED AS POPULATION. ======================================
# A receipt that never reached its question is not reproducing, and seeding it scores a flip
# that is not about prose. THIS MUTANT HAS A SUBJECT ONLY BECAUSE THE CHECKOUT IS A REAL
# REPOSITORY: BL-806 reads git and its base exit proves it, which m3b asserts directly.
#
# IT IS KILLED BY THE SUBJECT'S OWN SELF-PROBE AND NOT BY THE CORPUS, and that is the stronger
# kill rather than a weaker one: the subject REFUSES (exit 2, nothing reported) instead of
# publishing a count computed over the wrong population. The probe asserts the refusal names
# the exit-9 receipt, so an unrelated exit 2 cannot score here.
seed "$TMP/m3"
if mut "$TMP/m3" 's|^  if \[ "$BASE_RC" -ne 0 \] && \[ "$BASE_RC" -ne 1 \]; then|  if false; then|'; then
  m3_out="$(run_v "" "$TMP/m3" $DEF)"; m3_rc=$?
  if [ "$m3_rc" -eq 0 ]; then
    note "FAIL  m3 exit-9 counted as population SURVIVED: the subject exited 0 with the exclusion branch gone, so nothing depends on it."; rc=1
  elif grep -qF "OK: validate-backlog-receipts" <<<"$m3_out"; then
    note "FAIL  m3 exit-9 counted as population SURVIVED: the subject reported a count anyway."; rc=1
  elif ! grep -qF "base-exit-9 receipt" <<<"$m3_out"; then
    note "FAIL  m3 -- the subject refused, but not on the exit-9 receipt's assertion"
    printf '%s\n' "$m3_out" | sed 's/^/      /' | head -4; rc=1
  else
    note "ok    m3 -- with the exclusion gone the exit-9 receipt is scored, and the self-probe refuses before any corpus count"
  fi
fi

# m3b -- THE EXTRACTION IS FAITHFUL, asserted directly rather than inferred. A `git archive`
# extraction has no `.git`, and BL-806's receipt would exit 9 there and be excluded -- the
# population would be silently wrong and every count below it computed over the wrong set.
seed "$TMP/m3b"
m3b_out="$(run_v "" "$TMP/m3b" $DEF)"
m3b_806="$(cls "$m3b_out" BL-806)"
if [ "$m3b_806" != "PROSE-CLOSABLE" ]; then
  note "FAIL  m3b the checkout is not a faithful repository -- the git-reading receipt was classified '${m3b_806:-NONE}', not PROSE-CLOSABLE. Its guard exits 9 where there is no .git, so the whole git-reading population would be silently excluded."
  rc=1
else
  note "ok    m3b -- a receipt that runs git has base exit 1 in the checkout, so the subject tree is a real repository"
fi

# ===== M4. A 0 -> 1 FLIP IS COUNTED AS A FINDING. ==========================================
# BL-805 passes at base and the token seed drives it to 1. That is a receipt a comment BREAKS,
# a different defect with an unrelated remedy, and counting it inflates the ratchet with
# entries nobody can discharge.
seed "$TMP/m4"
if mut "$TMP/m4" 's|^    wr ALREADY-PASSING "base-exit=$BASE_RC-seed-exit=$SEED_RC"|    wr PROSE-CLOSABLE "base-exit=$BASE_RC-seed-exit=$SEED_RC"|'; then
  m4_out="$(run_v "" "$TMP/m4" $DEF)"; m4_rc=$?
  m4_805="$(cls "$m4_out" BL-805)"
  if [ "$m4_805" = "ALREADY-PASSING" ]; then
    note "FAIL  m4 a 0 -> 1 flip counted SURVIVED: the base-0 receipt is still ALREADY-PASSING, so the mutated line is not what classifies it."; rc=1
  elif [ "$m4_rc" -eq 0 ]; then
    note "FAIL  m4 a 0 -> 1 flip counted SURVIVED: the count did not move past the ceiling, so a wrong-direction flip costs nothing."; rc=1
  else
    note "ok    m4 -- counting a 0 -> 1 flip moves the count and breaks the ceiling, so the direction is load-bearing"
  fi
fi

# ===== M5. THE SEED SKIPS ITS `cmp -s` APPLIED-CHECK. ======================================
# A seed that changed nothing is a no-op whose "no flip" is indistinguishable from a receipt
# that resisted it. The probe makes one subject file UNWRITABLE in the checkout -- through the
# probe repository's own post-checkout hook, because git records no mode beyond the executable
# bit -- so the append genuinely fails and the guard has a real subject.
seed "$TMP/m5"
mkdir -p "$TMP/m5/.probehooks"
{ echo '#!/usr/bin/env bash'
  echo '[ -f probe/subject.txt ] && chmod 444 probe/subject.txt'
  echo 'exit 0'
} > "$TMP/m5/.probehooks/post-checkout"
chmod +x "$TMP/m5/.probehooks/post-checkout"
git -C "$TMP/m5" config core.hooksPath "$TMP/m5/.probehooks"
m5_base="$(run_v "" "$TMP/m5" $DEF)"
m5_801="$(cls "$m5_base" BL-801)"
if [ "$m5_801" != "UNSEEDED" ]; then
  note "FAIL  m5 -- with its subject unwritable the literal-grep receipt was classified '${m5_801:-NONE}', not UNSEEDED. An unapplied seed must be reported as unseeded; reported as 'no flip' it is a silent acquittal."
  rc=1
else
  note "ok    m5 -- a seed that could not be applied is reported UNSEEDED, not read as a bound receipt"
fi
# ...and the mutant: with the applied-check gone, that same receipt must stop being UNSEEDED.
if mut "$TMP/m5" 's|^      if cmp -s "$_st_d/$_p" "$_st_d/$_p.brpre"; then|      if false; then|'; then
  m5_out="$(run_v "" "$TMP/m5" $DEF)"; m5m_rc=$?
  m5m_801="$(cls "$m5_out" BL-801)"
  if [ "$m5m_801" = "UNSEEDED" ]; then
    note "FAIL  m5b the cmp -s guard removed SURVIVED: the receipt is still UNSEEDED, so cmp -s is not what detects the unapplied seed."; rc=1
  elif [ "$m5m_rc" -eq 0 ] && [ -z "$m5m_801" ]; then
    note "FAIL  m5b the cmp -s guard removed SURVIVED: the subject exited 0 and said nothing about the receipt, which is the silent acquittal this probe exists to prevent."; rc=1
  else
    note "ok    m5b -- without cmp -s the unapplied seed is no longer reported UNSEEDED (exit $m5m_rc, class '${m5m_801:-refused}'), so the guard is what catches it"
  fi
fi

# ===== M6. THE PATH-SPLIT CLASS DRIFTS BETWEEN ITS TWO COPIES. =============================
# The class exists in two files by necessity, and a drift is silent in both directions at
# once. The subject must REFUSE (exit 2), not score a corpus with an unbound grammar.
#
# THE DRIFT IS SEEDED IN THE BOUND FILE, NOT IN THE SUBJECT. Mutating the subject's own
# `PATH_CLASS` trips its R0 self-probe first -- correctly, since that probe asserts the
# comparator accepts an unmutated class -- and the run then refuses for a reason that is not
# the drift. Editing the OTHER copy is the state R0 exists to catch and the one a real drift
# produces, and it reaches R0's corpus arm rather than its probe.
seed "$TMP/m6"
m6_rev="$TMP/m6/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
cp "$m6_rev" "$m6_rev.orig"
# AWK, NOT SED, BECAUSE THE SUBJECT LINE CONTAINS A PIPE. Every `sed` delimiter that is
# comfortable here (`|`, `/`, `,`) occurs inside the text being matched, and `s|...|` with an
# unescaped pipe in the pattern is a `bad flag in substitute command` -- which exits non-zero
# and leaves an EMPTY target file, so the drift the probe wanted becomes a missing function and
# R0 refuses for the wrong reason. Measured exactly that way on this probe's first cut.
awk '
  index($0, "receipt_path_tokens() {") == 1 && index($0, "A-Za-z0-9_./$-") > 0 {
    sub(/A-Za-z0-9_\.\/\$-/, "A-Za-z0-9_.-"); print; next
  }
  { print }
' "$m6_rev.orig" > "$m6_rev"
if cmp -s "$m6_rev" "$m6_rev.orig"; then
  note "FAIL  m6 -- the drift mutation was a NO-OP, so any verdict below means nothing"; rc=1
else
  m6_out="$(run_v "" "$TMP/m6" $DEF)"; m6_rc=$?
  if [ "$m6_rc" -ne 2 ]; then
    note "FAIL  m6 R0 class drift -- the subject exited $m6_rc, not 2. A drifted split grammar must be a refusal, not a finding and not a pass."
    printf '%s\n' "$m6_out" | sed 's/^/      /' | head -4; rc=1
  elif ! grep -qF "DRIFTED" <<<"$m6_out"; then
    note "FAIL  m6 R0 class drift -- exited 2 but not on R0's assertion"
    printf '%s\n' "$m6_out" | sed 's/^/      /' | head -4; rc=1
  elif grep -qF "OK: validate-backlog-receipts" <<<"$m6_out"; then
    note "FAIL  m6 R0 class drift -- the subject reported a count anyway, so R0 ran after the corpus"; rc=1
  else
    note "ok    m6 -- a drifted path-split class is refused with exit 2, naming both copies"
  fi
fi
rm -f "$m6_rev.orig"

# m6b -- R0's NEAR-MISS TWIN, and without it m6 proves nothing. An R0 that refused ANY edit to
# either file would be as useless as one that never refuses: an unrelated change to
# ledger-reverify.sh must leave the subject reporting normally.
seed "$TMP/m6b"
m6b_rev="$TMP/m6b/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
cp "$m6b_rev" "$m6b_rev.orig"
printf '\n# an unrelated comment appended by the fixture\n' >> "$m6b_rev"
if cmp -s "$m6b_rev" "$m6b_rev.orig"; then
  note "FAIL  m6b -- the near-miss edit was a NO-OP, so its quiet proves nothing"; rc=1
else
  class_check "m6b an unrelated edit to the bound file is NOT a drift" "$TMP/m6b" ""
fi
rm -f "$m6b_rev.orig"

# ===== M7. THE SUBJECT RUNS AGAINST THE WORKING TREE. ======================================
# Two assertions, because they fail differently: the caller's tree must be unchanged, and the
# seed must not be visible in it afterwards. A subject that seeded in place would leave the
# receipt's own literal in a probe file.
seed "$TMP/m7"
m7_porc_before="$(git -C "$TMP/m7" status --porcelain | grep -c . )"
m7_wt_before="$(git -C "$TMP/m7" worktree list | grep -c . )"
m7_sum_before="$(cksum "$TMP/m7/probe/subject.txt" | awk '{print $1}')"
m7_out="$(run_v "" "$TMP/m7" $DEF)"; m7_rc=$?
m7_porc_after="$(git -C "$TMP/m7" status --porcelain | grep -c . )"
m7_wt_after="$(git -C "$TMP/m7" worktree list | grep -c . )"
m7_sum_after="$(cksum "$TMP/m7/probe/subject.txt" | awk '{print $1}')"
if [ "$m7_rc" -ne 0 ]; then
  note "FAIL  m7 -- the subject exited $m7_rc on a tree that must pass, so nothing about its writes is established"
  printf '%s\n' "$m7_out" | sed 's/^/      /' | head -4; rc=1
elif [ "$m7_porc_after" -ne "$m7_porc_before" ]; then
  note "FAIL  m7 the seed escaped -- the probe repo went from $m7_porc_before to $m7_porc_after dirty paths"; rc=1
elif [ "$m7_sum_after" != "$m7_sum_before" ]; then
  note "FAIL  m7 the seed escaped -- probe/subject.txt changed on disk, so a receipt was scored against a tree the arm had written"; rc=1
elif [ "$m7_wt_after" -ne "$m7_wt_before" ]; then
  note "FAIL  m7 checkouts leaked -- the probe repo has $m7_wt_after registered worktrees, was $m7_wt_before. Each is removed on every exit path or the repository fills with them."; rc=1
else
  note "ok    m7 -- the caller's tree, its files and its worktree registry are all unchanged across a run"
fi

# m7b -- THE OFFENDER TWIN. Without it, "the seed is confined" and "the subject never seeded
# anything" are the same green: m7 asserts an ABSENCE, and an absence passes for a program
# that never wrote anywhere. This makes the subject seed the SUBJECT ROOT -- the probe repo's
# own working tree -- and m7's two assertions must then both fire.
#
# THE MUTATION IS ON THE SEED HELPER'S TARGET, NOT ON ITS CALL. Replacing the call's result
# with `$SR` leaves `seed_tree` still creating and writing a checkout, so the escape would be
# partial and the arm would be scoring a shape nobody ships. Redirecting the helper's own
# target directory is the whole of the property: every append it makes then lands in the
# caller's tree.
seed "$TMP/m7b"
if mut "$TMP/m7b" 's|^    _st_d="$(mktree "$1")"|    _st_d="$SR"|'; then
  m7b_sum_before="$(cksum "$TMP/m7b/probe/subject.txt" | awk '{print $1}')"
  m7b_out="$(run_v "" "$TMP/m7b" $DEF 2>&1)"; m7b_rc=$?
  m7b_sum_after="$(cksum "$TMP/m7b/probe/subject.txt" | awk '{print $1}')"
  m7b_porc="$(git -C "$TMP/m7b" status --porcelain | grep -c . )"
  if [ "$m7b_sum_after" != "$m7b_sum_before" ] || [ "$m7b_porc" -gt 0 ]; then
    # The seed escaped, which is what this probe seeds for -- AND the shipped arm must have
    # noticed. An escape the arm reports as a clean run is the failure m7 exists to catch.
    if [ "$m7b_rc" -eq 0 ]; then
      note "FAIL  m7b the escape went UNREPORTED: the seed reached the caller's tree and the subject still exited 0."; rc=1
    else
      note "ok    m7b -- with the seed redirected at the caller's tree it DOES escape and the subject refuses (exit $m7b_rc), so m7's silence is a measurement"
    fi
  else
    note "FAIL  m7b seeding the working tree SURVIVED: probe/subject.txt and the porcelain are both unchanged, so the mutated line is not where the seed lands and m7 is asserting nothing."; rc=1
  fi
fi

# ===== M8. A ZERO POPULATION EXITS 0. ======================================================
# An empty parse, a fully-rotated ledger and a corpus of perfectly bound receipts all print
# the same zero. A ceiling that passes over it has stopped observing anything.
seed "$TMP/m8"
printf '# Probe backlog\n\nEntries were renamed to a shape the predicate does not know.\n\n## BACKLOG-001\n\nBody.\n' \
  > "$TMP/m8/docs/backlog.md"
( cd "$TMP/m8" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m empty >/dev/null 2>&1 )
kill_check "m8 a ledger that parses to ZERO receipts is a finding" "$TMP/m8" "" 1 \
  "produced ZERO scored receipts"

# ===== THE RATCHETS THAT EXIST BECAUSE THE FIRST ONE IS ESCAPABLE. =========================
# Each of these is an edit that LOWERS the prose-closable count and fixes nothing. Without
# their own ceilings the headline number falls and the gate reports an improvement.

# m9 -- the pattern moves into a variable. BL-801 leaves the scored population entirely.
seed "$TMP/m9"
sed "s|verify: sh grep -q 'MARK801' probe/subject.txt|verify: sh S=MARK801; grep -q \"\$S\" probe/subject.txt|" \
  "$TMP/m9/docs/backlog.md" > "$TMP/m9/docs/backlog.md.new"
if cmp -s "$TMP/m9/docs/backlog.md" "$TMP/m9/docs/backlog.md.new"; then
  note "FAIL  m9 -- the evasion edit was a NO-OP, so its verdict means nothing"; rc=1
else
  mv "$TMP/m9/docs/backlog.md.new" "$TMP/m9/docs/backlog.md"
  ( cd "$TMP/m9" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m evade >/dev/null 2>&1 )
  kill_check "m9 moving the pattern into a variable is caught by the unscored ceiling" "$TMP/m9" "" 1 \
    "could not be scored at all" --max-unscorable 1
fi

# m10 -- the receipt's verb becomes `manual`. It leaves the `sh` population, which no ceiling
# above can see, and only the floor does.
seed "$TMP/m10"
sed "s|verify: sh grep -q 'MARK801' probe/subject.txt|verify: manual|" \
  "$TMP/m10/docs/backlog.md" > "$TMP/m10/docs/backlog.md.new"
if cmp -s "$TMP/m10/docs/backlog.md" "$TMP/m10/docs/backlog.md.new"; then
  note "FAIL  m10 -- the evasion edit was a NO-OP, so its verdict means nothing"; rc=1
else
  mv "$TMP/m10/docs/backlog.md.new" "$TMP/m10/docs/backlog.md"
  ( cd "$TMP/m10" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m evade >/dev/null 2>&1 )
  kill_check "m10 a sh -> manual rewrite is caught by the population floor" "$TMP/m10" "" 1 \
    "receipt population fell by"
fi

# m11 -- the floor's NEAR-MISS, and without it m10 proves nothing. A floor that fired whenever
# the count moved would fire on ROTATION, which is the ledger's sanctioned remedy and its most
# common edit -- wedging the push on ordinary work. An entry removed WITH its receipt moves
# both sides and must stay quiet.
seed "$TMP/m11"
awk '/^## BL-801/{skip=1} /^## BL-802/{skip=0} !skip' "$TMP/m11/docs/backlog.md" > "$TMP/m11/docs/backlog.md.new"
if cmp -s "$TMP/m11/docs/backlog.md" "$TMP/m11/docs/backlog.md.new"; then
  note "FAIL  m11 -- the rotation edit was a NO-OP, so its quiet proves nothing"; rc=1
else
  mv "$TMP/m11/docs/backlog.md.new" "$TMP/m11/docs/backlog.md"
  ( cd "$TMP/m11" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m rotate >/dev/null 2>&1 )
  m11_out="$(run_v "" "$TMP/m11" --max-prose-closable 1 --max-unscorable 9 --max-out-of-population 9 --min-sh-receipts 6 --min-entries 6)"
  m11_rc=$?
  if [ "$m11_rc" -ne 0 ]; then
    note "FAIL  m11 rotation must be QUIET -- the subject exited $m11_rc. An entry removed with its receipt moves both counts; a floor that fires on it wedges the ledger's only sanctioned remedy."
    printf '%s\n' "$m11_out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1
  else
    note "ok    m11 -- removing an entry AND its receipt moves both counts and the floor stays quiet"
  fi
fi

# ===== THE POPULATION JOIN. ================================================================
# Bind the subject's `sh` population to the SHIPPING classifier's view of the same ledger, at
# fixture time rather than on the gate's hot path. NO NUMBER IS HARDCODED: a literal would go
# stale on the next filed entry, and equality alone is satisfied by two broken predicates that
# both return 0, so both sides are asserted non-zero as well.
if [ -n "$REVERIFY" ] && [ -n "$REAL_LEDGER" ]; then
  seed "$TMP/j1"
  cp "$REVERIFY" "$TMP/j1/scripts/backlog-reverify.sh"
  cp "$REAL_LEDGER" "$TMP/j1/docs/backlog.md"
  ( cd "$TMP/j1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m real >/dev/null 2>&1 )
  j1_out="$(run_v "" "$TMP/j1" --max-prose-closable 9999 --max-unscorable 9999 --max-out-of-population 9999 --min-sh-receipts 0 --min-entries 0)"
  j1_arm="$(printf '%s\n' "$j1_out" | sed -n 's/^SUMMARY .*sh-receipts=\([0-9][0-9]*\) .*/\1/p')"
  # Reverify's own view: one row per entry, id in field 2, restricted to the rows whose verb
  # it resolved as `sh` -- which are exactly the ones it reports STILL-LIVE or CLOSE-CANDIDATE
  # from an sh receipt. Counting its distinct ids for those statuses is its population.
  j1_rev="$( cd "$TMP/j1" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null \
    | awk -F'\t' '$3 ~ /^sh receipt exited/ { print $2 }' | sort -u | grep -c . )"
  if [ -z "$j1_arm" ] || [ -z "$j1_rev" ]; then
    note "FAIL  j1 -- a side produced no value (arm='$j1_arm' reverify='$j1_rev')"; rc=1
  elif [ "$j1_arm" -eq 0 ] || [ "$j1_rev" -eq 0 ]; then
    note "FAIL  j1 -- a side counted ZERO (arm=$j1_arm reverify=$j1_rev); two predicates that both find nothing agree perfectly and prove nothing"; rc=1
  elif [ "$j1_arm" -lt "$j1_rev" ]; then
    note "FAIL  j1 -- the arm sees $j1_arm sh receipts and backlog-reverify.sh resolves $j1_rev. The arm's population is SMALLER than the classifier's, so receipts exist that it never scores."; rc=1
  else
    note "ok    j1 -- on the real ledger the arm's sh population ($j1_arm) covers the classifier's resolved set ($j1_rev)"
  fi
else
  note "FAIL  j1 -- backlog-reverify.sh or the real ledger is not resolvable, so the population join could not be evaluated. A skip here reads exactly like agreement."
  rc=1
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-receipt-binding -- control green, every mutant killed by its own assertion"
fi
exit "$rc"
