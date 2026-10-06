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
#   BL-804  pattern assembled from -> UNSCORABLE       (`MARK'804'`: the literal grep receives
#           two quoted pieces                             is in no text the arm can seed. A pattern
#                                                         in a VARIABLE is not this shape any more:
#                                                         the receipt-text seed carries it, and m9b
#                                                         asserts that it flips.)
#   BL-805  base 0                 -> ALREADY-PASSING  (a 0 -> 1 flip is not a finding)
#   BL-806  reads git              -> PROSE-CLOSABLE, and its base exit proves the checkout
#                                     is a real repository rather than a bare extraction
#   BL-807  TWO files, TWO greps   -> PROSE-CLOSABLE only when EVERY path is seeded and EVERY
#                                     literal is extracted
#   BL-808  exit 9 then exit 1     -> UNSTABLE, never OUT-OF-POPULATION
#
# BL-808 COUNTS THROUGH A FILE OUTSIDE THE CHECKOUT, and it has to: each reading gets its own
# fresh tree, so state kept inside one cannot reach the next and the receipt could not differ
# between them. Its counter is initialised to a literal `0` rather than truncated -- an EMPTY
# file makes `$(cat)` yield the empty string, which is not `0`, so the first-reading branch
# never fires and the seeded non-determinism is not non-deterministic. Measured while building
# this: the probe read stable-at-1 and the arm it exists to exercise went untested while every
# other probe passed.
#
# BL-807 EXISTS BECAUSE EVERY OTHER RECEIPT HERE NAMES ONE FILE AND CARRIES ONE GREP, WHICH
# MAKES TWO WHOLE CLASSES OF WRONG SCORER INVISIBLE. A scorer that seeds only the first named
# path, and one that extracts only the first grep, satisfy every single-subject probe above --
# and on the real ledger they take a correct nine findings to six and to three, silently, in
# the direction that reads as a cleaner ledger. Neither literal is present at base, so the
# receipt reproduces at 1 and can only reach 0 when both halves of the seed arrive.
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
  # BL-807's two subjects. Neither carries its own literal, so the receipt reproduces at 1.
  printf 'theta\n' > "$d/probe/one.txt"
  printf 'iota\n' > "$d/probe/two.txt"
  printf '#!/usr/bin/env bash\nprintf %%s\\\\n WAIT\n' > "$d/probe/tool.sh"
  bl_seed_ledger "$d/docs/backlog.md"
  # A literal 0, never a truncation -- see BL-808's note above.
  printf 0 > "$BL_UNSTABLE_COUNTER"
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
    printf '## BL-804\n\nBody.\n\nverify: sh grep -q MARK%s probe/varpat.txt\n\n' "'804'"
    printf '## BL-805\n\nBody.\n\nverify: sh ! grep -q %s probe/passing.txt\n\n' "'MARK805'"
    printf '## BL-806\n\nBody.\n\nverify: sh git rev-parse HEAD >/dev/null 2>&1 || exit 9; grep -q %s probe/gitsub.txt\n\n' "'MARK806'"
    printf '## BL-807\n\nBody.\n\nverify: sh grep -q %s probe/one.txt && grep -q %s probe/two.txt\n\n' "'MARK807A'" "'MARK807B'"
    printf '## BL-808\n\nBody.\n\nverify: sh C="$BL_UNSTABLE_COUNTER"; n=$(cat "$C" 2>/dev/null || echo 0); printf %%s $((n+1)) > "$C"; [ "$n" = "0" ] && exit 9; exit 1\n\n'
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
# THREE prose-closable receipts -- BL-801, BL-806 and BL-807 -- so 3 is the AT-the-ceiling
# passing state and 2 is one over. Both sides are exercised, because an off-by-one written as
# `-ge` is green on the failing side alone.
BL_PC=3
# The floor pair tracks the SEED: seven entries, each carrying one `sh` receipt. Both numbers
# move with `bl_seed_ledger` and a stale pair makes the floor unable to fire -- measured, when
# BL-807 was added and this still read 6, m10's evasion dropped the count to exactly the floor
# and the probe came back SURVIVED.
BL_N=8

# BL-808's counter, outside every checkout and reset by `seed` so each probe's tree starts at
# a first reading. Exported because the receipt reads it by name through `eval`.
BL_UNSTABLE_COUNTER="$TMP/unstable.counter"
export BL_UNSTABLE_COUNTER
# `--max-unstable 1` because the seed carries BL-808 deliberately. The SHIPPED default is 0,
# which m17b asserts against this same seed -- so the flag here parameterises a probe corpus
# rather than relaxing the standard.
DEF="--max-prose-closable $BL_PC --max-unscorable 9 --max-out-of-population 9 --max-unstable 1 --min-sh-receipts $BL_N --min-entries $BL_N"

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
              "BL-804=UNSCORABLE" "BL-805=ALREADY-PASSING" "BL-806=PROSE-CLOSABLE" \
              "BL-807=PROSE-CLOSABLE" "BL-808=UNSTABLE"; do
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
  elif ! grep -qE 'base-exit-9 receipt|exits 9 on' <<<"$m3_out"; then
    note "FAIL  m3 -- the subject refused, but not on an exit-9 receipt's assertion"
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
# SCRUBBED AT THE CALL, not only at the top of this file. Line 60 unsets the repository
# environment for THIS process, which is enough while nobody re-exports it -- but the arm below
# deliberately DOES, to drive the subject under an inherited GIT_DIR, and `git -C` does not
# override that variable for reads or for writes. Scrubbing here makes the site correct however
# the surrounding file evolves, rather than correct-by-distance from one unset.
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  git -C "$TMP/m5" config core.hooksPath "$TMP/m5/.probehooks" )
# Read BY PATH: a read through GIT_DIR would confirm the write by consulting the repository the
# write may wrongly have gone to.
[ "$(git config --file "$TMP/m5/.git/config" --get core.hooksPath 2>/dev/null)" = "$TMP/m5/.probehooks" ] || {
  note "FAIL  m5 -- the probe repository's own .git/config does not carry core.hooksPath, so its unwritable-subject seed has no subject and the UNSEEDED assertion below would pass for the wrong reason."
  rc=1; }
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

# ===== M8B-M8F. AN ACCOUNTED-FOR ZERO IS NOT A ZERO THAT OBSERVED NOTHING. ==================
# R2's unconditional zero wedged the ledger's PREFERRED state: receipts that DRIVE their
# subject carry no grep literal, score UNSCORABLE `tokens=0`, and a ledger of nothing else --
# plus a fixed receipt reading ALREADY-PASSING -- scored 0 and failed the push. The narrowed
# predicate passes that state on a DISTINCT OK line and still fails every zero holding a receipt
# that is not behavioural. Each ledger below is written whole and passes its own ceilings and
# floor sized to it, so R3 and R5 are never what decides.
#   m8b  all-behavioural: one runs a script it names, one runs a script the tree lacks,
#        and one ALREADY-PASSING                                                          -> OK
#   m8c  the only sh receipt does not parse                                               -> R2 FAIL
#   m8d  the only sh receipt is an empty one-liner                                        -> R2 FAIL
#   m8e  the only sh receipt greps a literal at a path the seed cannot name               -> R2 FAIL
#   m8f  live entries and no sh receipt at all                                            -> OK
# The behavioural seed carries BOTH literal-free shapes -- one naming a script the tree holds,
# which must hold its own text appended AND be seen to run, and one naming a script the tree does
# not hold, which must run as a created stub and still fail -- so a predicate granting only one
# of the two signals cannot pass it.
r8_seed() { # r8_seed <dir> <nsh> <nentries> <ledger-body...> -> seeds, writes the ledger, commits
  local d="$1"; shift
  seed "$d"
  { printf '# Probe backlog\n\n'; printf '%s\n' "$@"; } > "$d/docs/backlog.md"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m r8 >/dev/null 2>&1 )
}
r8_run() { # r8_run <dir> <nsh> <nentries>
  run_v "" "$1" --max-prose-closable 9 --max-unscorable 9 --max-out-of-population 9 \
    --max-unstable 0 --min-sh-receipts "$2" --min-entries "$3"
}
R8_BEHAV_PATH='## BL-831

verify: sh o="$(bash probe/tool.sh)"; [ "$o" = READY831 ]
'
# Names a script the tree does not hold: the only no-seedable-path shape that can be
# behavioural, because the execution test creates it as a stub and sees it run and still fail.
R8_BEHAV_NOPATH='## BL-832

verify: sh o="$(bash probe/new832.sh 2>/dev/null)"; [ "$o" = READY832 ]
'
R8_PASSING="## BL-833

verify: sh ! grep -q 'MARK833' probe/passing.txt
"
R8_MALFORMED='## BL-834

verify: sh if true; then echo 834
'
R8_EMPTY='## BL-835

verify: sh
'
R8_NOPATH_TOK="## BL-836

verify: sh grep -q 'MARK836' probe/*.txt
"
R8_MANUAL='## BL-837

verify: manual -- no mechanical predicate
'
# r8_ok <name> <dir> <nsh> <nent> <state> <want-substr>
r8_ok() {
  local n="$1" d="$2" ns="$3" ne="$4" st="$5" want="$6" out rc_v
  out="$(r8_run "$d" "$ns" "$ne")"; rc_v=$?
  if [ "$rc_v" -ne 0 ]; then
    note "FAIL  $n -- exited $rc_v on an accounted-for zero that must pass"
    printf '%s\n' "$out" | grep -E '^FAIL|SELF-PROBE' | sed 's/^/      /' | head -3; rc=1; return
  fi
  if ! grep -qF "OK: validate-backlog-receipts -- R2 $st: 0 scored receipts" <<<"$out"; then
    note "FAIL  $n -- exit 0 but not on the distinct R2 $st line, so this pass is not this state's"
    printf '%s\n' "$out" | tail -2 | sed 's/^/      /'; rc=1; return
  fi
  if ! grep -qF "$want" <<<"$out"; then
    note "FAIL  $n -- the R2 $st line does not carry its counts (wanted: $want)"; rc=1; return
  fi
  note "ok    $n -- an accounted-for zero passes on its own R2 $st line, with its counts"
}
# r8_fail <name> <dir> <nsh> <nent> <class-id> <want-class>
r8_fail() {
  local n="$1" d="$2" ns="$3" ne="$4" id="$5" wc="$6" out rc_v nf
  out="$(r8_run "$d" "$ns" "$ne")"; rc_v=$?
  nf="$(printf '%s\n' "$out" | grep -c '^FAIL:')" || nf=0
  if [ "$rc_v" -ne 1 ]; then
    note "FAIL  $n -- exited $rc_v, not 1: a zero holding a non-behavioural receipt must stay R2's finding"
    printf '%s\n' "$out" | tail -2 | sed 's/^/      /'; rc=1; return
  fi
  if ! grep -qF "produced ZERO scored receipts" <<<"$out" || [ "$nf" -ne 1 ]; then
    note "FAIL  $n -- exit 1 but not on R2's zero alone ($nf FAIL lines)"
    printf '%s\n' "$out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1; return
  fi
  # The receipt must have been classified as the seed wrote it, or this FAIL is about the parse
  # and not about the predicate. The rows are dropped on the FAIL path, so the class is read
  # from R2's own FAIL text.
  if ! grep -qF "$wc" <<<"$out"; then
    note "FAIL  $n -- R2 failed, but its counts do not show $id as $wc"; rc=1; return
  fi
  note "ok    $n -- a zero whose only sh receipt is $id ($wc) is still R2's finding"
}

r8_seed "$TMP/m8b" "$R8_BEHAV_PATH" "$R8_BEHAV_NOPATH" "$R8_PASSING"
r8_ok "m8b an all-behavioural ledger is accounted for" "$TMP/m8b" 3 3 all-behavioural \
  "(3 sh receipts over 3 live entries in docs/backlog.md: 2 behavioural with no grep literal to seed, 1 already passing)"
r8_seed "$TMP/m8c" "$R8_MALFORMED"
r8_fail "m8c a malformed receipt" "$TMP/m8c" 1 1 BL-834 "sh receipts 1, unscorable 1,"
r8_seed "$TMP/m8d" "$R8_EMPTY"
r8_fail "m8d an empty sh one-liner" "$TMP/m8d" 1 1 BL-835 "sh receipts 1, unscorable 1,"
r8_seed "$TMP/m8e" "$R8_NOPATH_TOK"
r8_fail "m8e a literal at an unseedable path" "$TMP/m8e" 1 1 BL-836 "sh receipts 1, unscorable 1,"
r8_seed "$TMP/m8f" "$R8_MANUAL"
r8_ok "m8f live entries with no sh receipt" "$TMP/m8f" 0 1 no-sh-receipts \
  "(0 sh receipts over 1 live entries in docs/backlog.md"

# ===== M8G-M8M. WHAT AN ACCOUNTED-FOR ZERO MAY NOT ABSORB. ===================================
#   m8g  one behavioural receipt + one UNSEEDED receipt                       -> R2 FAIL
#   m8h  one behavioural receipt + one `|| exit 9` OUT-OF-POPULATION receipt  -> R2 FAIL
#   m8i  live entries whose verify line this parser cannot see, one per spelling -> R2 FAIL
#   m8j  `has` and `lacks` beside `manual`: every verb the parser reads        -> OK
#   m8k  `verify:<TAB>sh ...` -- the parser strips blanks after the colon, so it IS an sh receipt
#        and is scored. It is asserted SCORED, because it cannot reach the no-sh state at all.
# m8g's receipt is UNSEEDED for a real reason, the way R1's BL-906 is: a `post-checkout` hook in
# the probe repository makes its subject unwritable in every checkout. Each receipt has its own
# subject file, so no seed reaches another receipt's.
R8_UNSEEDED="## BL-838

verify: sh grep -q 'MARK838' probe/locked.txt
"
R8_OOP="## BL-839

verify: sh grep -q 'MARK839' probe/guarded.txt || exit 9
"
r8_seed "$TMP/m8g" "$R8_BEHAV_PATH" "$R8_UNSEEDED"
printf 'locked\n' > "$TMP/m8g/probe/locked.txt"
( cd "$TMP/m8g" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m locked >/dev/null 2>&1 )
mkdir -p "$TMP/m8g/.probehooks"
{ echo '#!/usr/bin/env bash'
  echo '[ -f probe/locked.txt ] && chmod 444 probe/locked.txt'
  echo 'exit 0'
} > "$TMP/m8g/.probehooks/post-checkout"
chmod +x "$TMP/m8g/.probehooks/post-checkout"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  git -C "$TMP/m8g" config core.hooksPath "$TMP/m8g/.probehooks" )
[ "$(git config --file "$TMP/m8g/.git/config" --get core.hooksPath 2>/dev/null)" = "$TMP/m8g/.probehooks" ] || {
  note "FAIL  m8g -- the probe repository does not carry its hooks path, so its receipt cannot be UNSEEDED"; rc=1; }
r8_fail "m8g a behavioural receipt beside an UNSEEDED one" "$TMP/m8g" 2 2 BL-838 "sh receipts 2, unscorable 1, unseeded 1,"
r8_seed "$TMP/m8h" "$R8_BEHAV_PATH" "$R8_OOP"
r8_fail "m8h a behavioural receipt beside an exit-9 one" "$TMP/m8h" 2 2 BL-839 "out of population 1,"

# m8i -- one ledger per spelling, each the ledger's only entry. Every one parses to no `sh`
# receipt (or, for `sh<TAB>`, to a verb of `sh<TAB>grep`), so without the verb census each read as
# the no-sh-receipts state and passed. R2's FAIL text is unchanged; the entry is named on its own
# line, which is what each arm keys on.
r8_spell() { # r8_spell <tag> <id> <verify line>
  r8_seed "$TMP/m8i-$1" "## $2

$3
"
  r8_fail "m8i-$1 a verify line spelled '$3'" "$TMP/m8i-$1" 0 1 "$2" \
    "live entry $2 carries a verify verb this parser does not read"
}
r8_spell dash    BL-841 "- verify: sh grep -q 'MARK841' probe/subject.txt"
r8_spell capital BL-842 "Verify: sh grep -q 'MARK842' probe/subject.txt"
r8_spell bold    BL-843 "**verify:** sh grep -q 'MARK843' probe/subject.txt"
r8_spell upper   BL-844 "verify: SH grep -q 'MARK844' probe/subject.txt"
r8_spell shtab   BL-845 "verify: sh	grep -q 'MARK845' probe/subject.txt"

r8_seed "$TMP/m8j" "$R8_MANUAL" '## BL-846

verify: has probe/subject.txt "alpha"
' '## BL-847

verify: lacks probe/subject.txt "MARK847"
'
r8_ok "m8j manual, has and lacks are all read" "$TMP/m8j" 0 3 no-sh-receipts \
  "(0 sh receipts over 3 live entries in docs/backlog.md"

r8_seed "$TMP/m8k" "## BL-848

verify:	sh grep -q 'MARK848' probe/subject.txt
"
m8k_out="$(r8_run "$TMP/m8k" 1 1)"; m8k_rc=$?
m8k_row="$(cls "$m8k_out" BL-848)"
if [ "$m8k_rc" -eq 0 ] && [ "$m8k_row" = "PROSE-CLOSABLE" ] && grep -q '^SUMMARY .* sh-receipts=1 scored=1 ' <<<"$m8k_out"; then
  note "ok    m8k -- 'verify:<TAB>sh' is read as an sh receipt and scored, so it can never reach the no-sh state"
else
  note "FAIL  m8k -- 'verify:<TAB>sh' read '${m8k_row:-NONE}' (exit $m8k_rc), not one scored PROSE-CLOSABLE sh receipt"; rc=1
fi

# THE MUTANTS. Each is ONE line of the subject, anchored on text that occurs once, and each must
# die on exactly the arm that owns it.
#   mR2a  R2 relaxed unconditionally      -> must die on m8c (malformed still FAILs)
#   mR2b  the old unconditional predicate -> must die on m8b (all-behavioural passes)
#   mR2c  behavioural keyed on STATUS     -> must die on m8c (malformed is not behavioural)
#   mR2d  no-sh state drops ENTRIES > 0   -> must die on m8 (an empty parse is not a ledger)
#   mW11  the sum also absorbs UNSEEDED   -> must die on m8g
#   mW10  the sum also absorbs OUT-OF-POP -> must die on m8h
#   mR2v  the verb census dropped         -> must die on m8i-dash
#   mX1   the execution test always true  -> must die at R1 (BL-915)
#   mX3   a named text file skipped, not failing (round 3's "any ran") -> must die on m8r-tailvar
#   mX2   created stub: "ran" without "still fails" -> must die on m8l-stub
#   mG1-3, mT1: the grammar and the receipt-text seed, each killed at the subject's own R1 probe
r8_mut() { # r8_mut <name> <src-dir> <sed> <check: ok|fail|m8> <args for the check...>
  local n="$1" src="$2" ex="$3" kind="$4"; shift 4
  local md="$TMP/$n"
  mkdir -p "$md"; cp -R "$src/." "$md/"
  if ! mut "$md" "$ex"; then return; fi
  local f="$md/scripts/validate-backlog-receipts.sh" out rc_v
  ( cd "$md" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m mut >/dev/null 2>&1 )
  case "$kind" in
    ok)
      out="$(r8_run "$md" "$1" "$2")"; rc_v=$?
      if [ "$rc_v" -eq 1 ] && grep -qF "produced ZERO scored receipts" <<<"$out"; then
        note "ok    $n -- killed: the all-behavioural ledger fails R2 under the mutant"
      else
        note "FAIL  $n SURVIVED -- exit $rc_v, the accounted-for zero still passed"; rc=1
      fi ;;
    fail)
      out="$(r8_run "$md" "$1" "$2")"; rc_v=$?
      if [ "$rc_v" -eq 0 ] && grep -qF "OK: validate-backlog-receipts" <<<"$out"; then
        note "ok    $n -- killed: a ledger that must fail R2 passes under the mutant"
      else
        note "FAIL  $n SURVIVED -- exit $rc_v, the ledger that must fail R2 still failed"; rc=1
      fi ;;
    m8)
      out="$(run_v "" "$md" $DEF)"; rc_v=$?
      if [ "$rc_v" -eq 0 ] && ! grep -qF "produced ZERO scored receipts" <<<"$out"; then
        note "ok    $n -- killed: the empty parse passes under the mutant"
      else
        note "FAIL  $n SURVIVED -- exit $rc_v, the empty parse still failed"; rc=1
      fi ;;
  esac
}
r8_mut mR2a "$TMP/m8c" 's|^if \[ "$SCORED" -eq 0 \] && \[ -z "$R2_ZERO_STATE" \]; then|if false; then|' fail 1 1
r8_mut mR2b "$TMP/m8b" 's|^if \[ "$SCORED" -eq 0 \] && \[ -z "$R2_ZERO_STATE" \]; then|if [ "$SCORED" -eq 0 ]; then|' ok 3 3
r8_mut mR2c "$TMP/m8c" 's@$1 == "UNSCORABLE" \&\& $3 ~ /^behavioural-executes-named-file/@$1 == "UNSCORABLE"@' fail 1 1
r8_mut mR2d "$TMP/m8" 's|^  elif \[ "$SH_RECEIPTS" -eq 0 \] && \[ "$ENTRIES" -gt 0 \]; then|  elif [ "$SH_RECEIPTS" -eq 0 ]; then|' m8
# W11 and W10: the accounted-for sum widened to absorb an UNSEEDED receipt, and an exit-9 one.
# Each was a wrong predicate the whole fixture let through; m8g and m8h are their subjects.
r8_mut mW11 "$TMP/m8g" 's|\$(( N_BEHAV + N_PASS ))|$(( N_BEHAV + N_PASS + N_UNSEED ))|' fail 2 2
r8_mut mW10 "$TMP/m8h" 's|\$(( N_BEHAV + N_PASS ))|$(( N_BEHAV + N_PASS + N_OOP ))|' fail 2 2
# The verb census dropped from the zero-state predicate: a ledger whose only entry is spelled
# `- verify: sh` reads as having no sh receipt and passes again.
r8_mut mR2v "$TMP/m8i-dash" 's|^if \[ "$SCORED" -eq 0 \] && \[ "$UNREAD_VERBS" -eq 0 \]; then|if [ "$SCORED" -eq 0 ]; then|' fail 0 1

# ===== M8L-M8Z. ROUND 3: A READER THAT HOLDS EVERY SEED IS STILL A READER. =====================
# Round 2 granted "behavioural" to a literal-free receipt that held its own text appended, or
# that named no path and read the same exit twice. An adversary closed every one of the shapes
# below with a prose edit placed where the receipt reads -- a leading line, a trailing exact line,
# a padding of lines, a file the receipt reaches through a variable, a glob or `find`. Each is now
# a reader that RUNS nothing it names, and must block R2's zero. Every arm is its own one-receipt
# ledger at the gate's ceilings with the floor sized to it, so R2's zero is the only thing that
# can decide, and each was measured to PASS (the acquittal) on the round-2 tip 303f030f.
# m8l_shape <tag> <id> <receipt> <file> <file-content> -- seeds the file, asserts R2's zero FAIL.
m8l_shape() {
  local t="$1" id="$2" rcp="$3" f="$4" body="$5" out rc_v
  r8_seed "$TMP/m8l-$t" "## $id

verify: sh $rcp
"
  mkdir -p "$(dirname "$TMP/m8l-$t/$f")"
  printf '%s' "$body" > "$TMP/m8l-$t/$f"
  ( cd "$TMP/m8l-$t" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m shape >/dev/null 2>&1 )
  out="$(run_v "" "$TMP/m8l-$t" --max-prose-closable 1 --max-unscorable 28 --max-out-of-population 1 \
    --max-unstable 0 --min-sh-receipts 1 --min-entries 1)"; rc_v=$?
  if [ "$rc_v" -eq 1 ] && grep -qF "produced ZERO scored receipts" <<<"$out" \
     && ! grep -qF "OK: validate-backlog-receipts" <<<"$out"; then
    note "ok    m8l-$t -- the reader '$rcp' runs nothing it names, so it blocks R2's zero"
  else
    note "FAIL  m8l-$t -- '$rcp' exited $rc_v without R2's zero FAIL: a reader a prose edit closes was accounted for"
    printf '%s\n' "$out" | grep -E '^(FAIL|OK)' | sed 's/^/      /' | head -2; rc=1
  fi
}
m8l_shape sed1p    BL-851 'test "$(sed -n 1p probe/g.txt)" = ZZFIRST'                    probe/g.txt     $'plain\n'
m8l_shape head1    BL-852 'head -1 probe/f.txt | grep -q ZZONE'                          probe/f.txt     $'plain\n'
m8l_shape headn1   BL-853 'head -n 1 probe/f.txt | grep -q ZZLEAD'                       probe/f.txt     $'plain\n'
m8l_shape tail1    BL-854 'tail -1 probe/f.txt | grep -qx ZZLAST'                        probe/f.txt     $'plain\n'
m8l_shape grepcx   BL-855 'grep -c alpha probe/a.txt | grep -qx 3'                       probe/a.txt     $'alpha\n'
m8l_shape wcl      BL-856 '[ "$(wc -l < probe/lines.txt)" -gt 5 ]'                       probe/lines.txt $'a\nb\nc\n'
m8l_shape grepcdot BL-857 '[ "$(grep -c . probe/lines.txt)" = 5 ]'                       probe/lines.txt $'a\nb\nc\n'
m8l_shape varpath  BL-858 'D=probe/sub; test "$(cat "$D/x.txt")" = ZZVAR'                probe/sub/x.txt $'plain\n'
m8l_shape glob     BL-859 'test "$(cat probe/sub/*.txt)" = ZZGLOB'                       probe/sub/x.txt $'plain\n'
m8l_shape find     BL-860 'test "$(find probe/sub -name "*.txt" | xargs cat)" = ZZFIND'  probe/sub/x.txt $'plain\n'
# ...and a receipt that runs a script the tree does not hold, which a comment-only stub SATISFIES.
m8l_shape stub     BL-861 'bash probe/new861.sh >/dev/null 2>&1 || exit 1'               probe/other.txt $'x\n'

# THE MUTANT: the execution test answers yes unconditionally, so every reader is granted
# behavioural. It is killed at the subject's own R1 probe, before any corpus -- BL-915, the
# first-line reader -- which is the stronger kill: the run refuses instead of publishing a zero
# that accounts for a reader. Measured on this arm's first cut, which expected the corpus arm to
# fire and read the refusal as a survival.
mX1_check() {
  local out rc_v
  mkdir -p "$TMP/mX1"; cp -R "$TMP/m8l-sed1p/." "$TMP/mX1/"
  mut "$TMP/mX1" 's/^    \[ -z "\$EX_WHY" \] || return 1$/    return 0/' || return
  ( cd "$TMP/mX1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m mut >/dev/null 2>&1 )
  out="$(run_v "" "$TMP/mX1" --max-prose-closable 1 --max-unscorable 28 --max-out-of-population 1 \
    --max-unstable 0 --min-sh-receipts 1 --min-entries 1)"; rc_v=$?
  if [ "$rc_v" -eq 2 ] && grep -qF "SELF-PROBE FAILED" <<<"$out" && grep -qF "the first-line reader" <<<"$out" \
     && ! grep -qF "OK: validate-backlog-receipts" <<<"$out"; then
    note "ok    mX1 -- killed at R1 on the first-line reader: with the execution test always true it is granted behavioural"
  else
    note "FAIL  mX1 SURVIVED or died elsewhere -- exit $rc_v"
    printf '%s\n' "$out" | grep -E 'SELF-PROBE|^FAIL|^OK' | sed 's/^/      /' | head -2; rc=1
  fi
}
mX1_check

# ===== M8R. ROUND 4: A RECEIPT THAT RUNS A SCRIPT AND READS TEXT IS A READER OF THAT TEXT. ======
# Round 3 granted the execution signal when ANY named file ran. Each receipt below runs a named
# script and decides on a named text file, and an adversary closed every one 1 -> 0 with a
# one-line edit to that text. The rule now needs EVERY named existing file to be a script whose
# sentinel fired, so each is `UNSCORABLE reads-named-text=<file>` and blocks R2's zero. Every arm
# here was measured to PASS -- the acquittal -- on ad86c0ae; m8r-bound read BOUND there.
# m8r_shape <tag> <id> <receipt> -- the world holds a runnable t.sh, a sourceable lib.sh and two
# text files, so only the receipt varies between arms.
m8r_shape() {
  local t="$1" id="$2" rcp="$3" out rc_v d="$TMP/m8r-$1"
  r8_seed "$d" "## $id

verify: sh $rcp
"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/probe/t.sh"
  printf 'LIBLOADED=1\n' > "$d/probe/lib.sh"
  printf 'plain\n' > "$d/probe/doc.md"
  printf 'plain\n' > "$d/probe/doc2.md"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m shape >/dev/null 2>&1 )
  out="$(run_v "" "$d" --max-prose-closable 1 --max-unscorable 28 --max-out-of-population 1 \
    --max-unstable 0 --min-sh-receipts 1 --min-entries 1)"; rc_v=$?
  if [ "$rc_v" -eq 1 ] && grep -qF "produced ZERO scored receipts" <<<"$out" \
     && ! grep -qF "OK: validate-backlog-receipts" <<<"$out"; then
    note "ok    m8r-$t -- '$rcp' runs a script but reads named text, so it blocks R2's zero"
  else
    note "FAIL  m8r-$t -- '$rcp' exited $rc_v without R2's zero FAIL: a run-and-read receipt a text edit closes was accounted for"
    printf '%s\n' "$out" | grep -E '^(FAIL|OK)' | sed 's/^/      /' | head -2; rc=1
  fi
}
m8r_shape tailvar  BL-871 'P=MARKA; bash probe/t.sh && tail -1 probe/doc.md | grep -qx "$P"'
m8r_shape failpath BL-872 'test "$(sed -n 1p probe/doc.md)" = "$(printf MARKB)" || { bash probe/t.sh; exit 1; }'
m8r_shape seqread  BL-873 'bash probe/t.sh; test "$(sed -n 1p probe/doc2.md)" = "$(printf MARKC)"'
m8r_shape sourced  BL-874 '. probe/lib.sh; test "$(sed -n 1p probe/doc.md)" = "$(printf MARKD)"'
m8r_shape bound    BL-875 '[ -f probe/doc.md ] && bash probe/t.sh && tail -1 probe/doc.md | grep -qx MARKF'

# THE MUTANT: round 3's "any named file ran" -- a data file is skipped instead of failing the
# test. The run-and-read receipt is then granted on t.sh alone; it must die on m8r-tailvar.
mkdir -p "$TMP/mX3"; cp -R "$TMP/m8r-tailvar/." "$TMP/mX3/"
if mut "$TMP/mX3" 's/^            \*) if \[ -f "\$_ex_d\/\$_p" \]; then EX_WHY="\${EX_WHY:-\$_p}"; continue; fi$/            *) if [ -f "$_ex_d\/$_p" ]; then continue; fi/'; then
  ( cd "$TMP/mX3" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m mut >/dev/null 2>&1 )
  mX3_out="$(run_v "" "$TMP/mX3" --max-prose-closable 1 --max-unscorable 28 --max-out-of-population 1 \
    --max-unstable 0 --min-sh-receipts 1 --min-entries 1)"; mX3_rc=$?
  # Either observable is a kill. The first reached is R1: with text skipped, BL-915 names no
  # file that failed, its detail loses `probe/first.txt`, and the subject refuses before any
  # corpus -- measured on this arm's first cut. The corpus acquittal is accepted too, so the arm
  # does not depend on which site fires first.
  if { [ "$mX3_rc" -eq 0 ] && grep -qF "R2 all-behavioural" <<<"$mX3_out"; } \
     || { [ "$mX3_rc" -eq 2 ] && grep -qF "SELF-PROBE FAILED -- the first-line reader" <<<"$mX3_out"; }; then
    note "ok    mX3 -- killed (exit $mX3_rc): a named text file skipped rather than failing the execution test"
  else
    note "FAIL  mX3 SURVIVED or died elsewhere -- exit $mX3_rc"
    printf '%s\n' "$mX3_out" | grep -E 'SELF-PROBE|^FAIL|^OK' | sed 's/^/      /' | head -2; rc=1
  fi
fi

# THE MUTANT on the created-stub branch: "ran" alone, without "still failed with only the stub".
mkdir -p "$TMP/mX2"; cp -R "$TMP/m8l-stub/." "$TMP/mX2/"
if mut "$TMP/mX2" 's|^      if executed \&\& \[ "\$EX_RC" != "0" \]; then|      if executed; then|'; then
  ( cd "$TMP/mX2" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m mut >/dev/null 2>&1 )
  mX2_out="$(run_v "" "$TMP/mX2" --max-prose-closable 1 --max-unscorable 28 --max-out-of-population 1 \
    --max-unstable 0 --min-sh-receipts 1 --min-entries 1)"; mX2_rc=$?
  if [ "$mX2_rc" -eq 0 ] && grep -qF "R2 all-behavioural" <<<"$mX2_out"; then
    note "ok    mX2 -- killed: without the stub-still-fails check a receipt a comment-only file satisfies is accounted for"
  else
    note "FAIL  mX2 SURVIVED -- exit $mX2_rc"; rc=1
  fi
fi

# ===== D5. A LIVE ENTRY WITH NO VERIFY LINE AT ALL BLOCKS THE NO-SH ZERO. =====================
r8_seed "$TMP/m8n" "$R8_MANUAL" '## BL-862

Body with no verify line.
'
r8_fail "m8n a live entry with no verify line" "$TMP/m8n" 0 2 BL-862 \
  "live entry BL-862 carries a verify verb this parser does not read (no verify line"

# ===== D4. THE VERB CENSUS AT THE GATE'S ARGV, BESIDE ONE REAL SH RECEIPT. =====================
# One behavioural receipt keeps sh-receipts at 1, so R5's floor of 1 holds and cannot be what
# decides; the dash-spelled entry is the only thing standing between this ledger and the
# all-behavioural pass. At the gate argv, so the arm is what the push actually runs.
r8_seed "$TMP/m8o" "$R8_BEHAV_PATH" "## BL-863

- verify: sh grep -q 'MARK863' probe/subject.txt
"
m8o_out="$(run_v "" "$TMP/m8o" --max-prose-closable 1 --max-unscorable 28 --max-out-of-population 1 \
  --max-unstable 0 --min-sh-receipts 1 --min-entries 1)"; m8o_rc=$?
m8o_nf="$(printf '%s\n' "$m8o_out" | grep -c '^FAIL:')" || m8o_nf=0
if [ "$m8o_rc" -eq 1 ] && [ "$m8o_nf" -eq 1 ] && grep -qF "produced ZERO scored receipts" <<<"$m8o_out" \
   && grep -qF "live entry BL-863 carries a verify verb this parser does not read" <<<"$m8o_out"; then
  note "ok    m8o -- at the gate argv, one behavioural receipt beside a '- verify: sh' entry fails R2 alone and names the entry"
else
  note "FAIL  m8o -- exit $m8o_rc, $m8o_nf FAIL lines: the unread verb beside a real sh receipt was not R2's sole finding"
  printf '%s\n' "$m8o_out" | grep -E '^(FAIL|OK)' | sed 's/^/      /' | head -3; rc=1
fi

# ===== N2. A RECEIPT THAT HANGS IS A REFUSAL, AND ITS WHOLE PROCESS TREE IS KILLED. ===========
# The receipt starts a grandchild that would outlive a leader-only kill; the timeout is 2s. The
# subject must refuse (exit 2, BROKEN naming the limit), and no process carrying the marker may
# survive it -- asserted through the receipt's own pid file, never a process-table grep.
r8_seed "$TMP/m8p" "## BL-864

verify: sh ( sleep 300 & echo \$! > \"\$R8_HANG_PIDS\"; wait ) ; exit 1
"
R8_HANG_PIDS="$TMP/hang.pids"; export R8_HANG_PIDS; : > "$R8_HANG_PIDS"
m8p_out="$(run_v "AI_DLC_BACKLOG_RECEIPT_TIMEOUT=2" "$TMP/m8p" --max-prose-closable 1 --max-unscorable 28 \
  --max-out-of-population 1 --max-unstable 0 --min-sh-receipts 1 --min-entries 1)"; m8p_rc=$?
m8p_live=0
for m8p_pid in $(cat "$R8_HANG_PIDS" 2>/dev/null); do kill -0 "$m8p_pid" 2>/dev/null && m8p_live=$((m8p_live + 1)); done
m8p_seen="$(grep -c . "$R8_HANG_PIDS")" || m8p_seen=0
if [ "$m8p_rc" -eq 2 ] && grep -qF "receipt-timed-out-after-2s" <<<"$m8p_out" && [ "$m8p_seen" -ge 1 ] && [ "$m8p_live" -eq 0 ]; then
  note "ok    m8p -- a hanging receipt is refused at its timeout, and the $m8p_seen grandchild(ren) it started are dead"
else
  note "FAIL  m8p -- exit $m8p_rc, grandchildren recorded $m8p_seen, still alive $m8p_live: a hanging receipt was not refused, or its tree outlived it"
  for m8p_pid in $(cat "$R8_HANG_PIDS" 2>/dev/null); do kill -9 "$m8p_pid" 2>/dev/null; done
  rc=1
fi

# ===== THE GRAMMAR AND THE RECEIPT-TEXT SEED, KILLED AT THE SUBJECT'S OWN SELF-PROBE. ==========
# Each mutant removes one piece of how a literal-free receipt earns "behavioural", and the R1
# probe that owns that piece must refuse, naming its receipt -- before any corpus is scored.
# r1_mut <name> <sed> <the R1 message that must appear>
r1_mut() {
  local n="$1" ex="$2" want="$3" out rc_v
  seed "$TMP/$n"
  mut "$TMP/$n" "$ex" || return
  out="$(run_v "" "$TMP/$n" $DEF)"; rc_v=$?
  if [ "$rc_v" -eq 2 ] && grep -qF "SELF-PROBE FAILED" <<<"$out" && grep -qF "$want" <<<"$out" \
     && ! grep -qF "OK: validate-backlog-receipts" <<<"$out"; then
    note "ok    $n -- killed at R1, on its own probe ($want)"
  else
    note "FAIL  $n SURVIVED or died elsewhere -- exit $rc_v; wanted a SELF-PROBE refusal carrying '$want'"
    printf '%s\n' "$out" | grep -E 'SELF-PROBE|^FAIL' | sed 's/^/      /' | head -3; rc=1
  fi
}
# The grammar stops emitting BARE patterns: the bare grep is then closed only by its receipt text.
r1_mut mG1 's|^  if (K\[idx\] == "b") {|  if (0) {|' "not on its TOKEN seed"
# The command-substitution depth check removed: `printf` is read as the pattern and seeded.
r1_mut mG2 's|^      if (D\[q\] != D\[p\]) break|      if (0) break|' 'the grep carrying `-m 1`'
# The option-argument skip removed: `1` (the argument of `-m`) is read as the pattern.
r1_mut mG3 's|^        if (b ~ /^-\[a-zA-Z\]\*\[mABCd\]$/) { q = q + 2; continue }|        if (0) { q = q + 2; continue }|' 'the grep carrying `-m 1`'
# The receipt-text seed removed: a literal-free receipt is appended a bare `#`, flips nothing,
# and is granted behavioural -- the acquittal this round exists to remove.
r1_mut mT1 's|^  \[ "$SEED_KIND" = receipt-text \] && SEED_LINE="# $REST"|  :|' "the awk-body receipt"

# ===== THE RATCHETS THAT EXIST BECAUSE THE FIRST ONE IS ESCAPABLE. =========================
# Each of these is an edit that LOWERS the prose-closable count and fixes nothing. Without
# their own ceilings the headline number falls and the gate reports an improvement.

# m9 -- the pattern is ASSEMBLED from quoted pieces, so the literal grep receives appears in no
# text the arm can seed. BL-801 leaves the scored population, and only R3 sees it go.
seed "$TMP/m9"
sed "s|verify: sh grep -q 'MARK801' probe/subject.txt|verify: sh grep -q MARK'801' probe/subject.txt|" \
  "$TMP/m9/docs/backlog.md" > "$TMP/m9/docs/backlog.md.new"
if cmp -s "$TMP/m9/docs/backlog.md" "$TMP/m9/docs/backlog.md.new"; then
  note "FAIL  m9 -- the evasion edit was a NO-OP, so its verdict means nothing"; rc=1
else
  mv "$TMP/m9/docs/backlog.md.new" "$TMP/m9/docs/backlog.md"
  ( cd "$TMP/m9" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m evade >/dev/null 2>&1 )
  kill_check "m9 assembling the pattern from pieces is caught by the unscored ceiling" "$TMP/m9" "" 1 \
    "could not be scored at all" --max-unscorable 1
fi

# m9b -- the pattern moves into a VARIABLE. That was m9's evasion until the receipt-text seed:
# the receipt's own text carries `MARK801`, so a comment carrying it closes the receipt and R2,
# not R3, must see it -- PROSE-CLOSABLE with no token extracted, which is only reachable through
# that seed.
seed "$TMP/m9b"
sed "s|verify: sh grep -q 'MARK801' probe/subject.txt|verify: sh S=MARK801; grep -q \"\$S\" probe/subject.txt|" \
  "$TMP/m9b/docs/backlog.md" > "$TMP/m9b/docs/backlog.md.new"
if cmp -s "$TMP/m9b/docs/backlog.md" "$TMP/m9b/docs/backlog.md.new"; then
  note "FAIL  m9b -- the evasion edit was a NO-OP, so its verdict means nothing"; rc=1
else
  mv "$TMP/m9b/docs/backlog.md.new" "$TMP/m9b/docs/backlog.md"
  ( cd "$TMP/m9b" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m evade >/dev/null 2>&1 )
  # One more prose-closable receipt than the seed carries, so the ceiling is sized to it rather
  # than taken from $DEF: R2 passing here is the count being right, not slack.
  m9b_out="$(run_v "" "$TMP/m9b" --max-prose-closable "$(( BL_PC + 1 ))" --max-unscorable 9 \
    --max-out-of-population 9 --max-unstable 1 --min-sh-receipts "$BL_N" --min-entries "$BL_N")"; m9b_rc=$?
  m9b_row="$(printf '%s\n' "$m9b_out" | awk -F'\t' '$2 == "BL-801" { print $1 " " $4 }' | sed -n '1p')"
  if [ "$m9b_rc" -eq 0 ] && [ "$m9b_row" = "PROSE-CLOSABLE tokens=none" ]; then
    note "ok    m9b -- a pattern moved into a variable is still closed by a comment carrying the receipt's own text, and R2 counts it"
  else
    note "FAIL  m9b -- the variable-pattern receipt read '${m9b_row:-NONE}' (exit $m9b_rc), not 'PROSE-CLOSABLE tokens=none'. A comment carrying the receipt's text satisfies it; anything else acquits it."; rc=1
  fi
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
  # ROTATION REMOVES A PROSE-CLOSABLE RECEIPT TOO, so this probe's ceilings follow the ledger
  # it actually seeds -- BL-801 is gone, taking one finding with it. Passing the shared $DEF
  # here would fail on the PROSE-CLOSABLE ceiling, which is not what this probe asserts, and
  # its red would read as a floor that fires on rotation.
  m11_out="$(run_v "" "$TMP/m11" --max-prose-closable "$(( BL_PC - 1 ))" \
    --max-unscorable 9 --max-out-of-population 9 --max-unstable 1 \
    --min-sh-receipts "$BL_N" --min-entries "$BL_N")"
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
# R2 REFUSES BEFORE THE SUMMARY when this tree can score none of the real ledger's receipts, and
# that is a property of THIS tree, not of the ledger: it carries only the validator, lib.sh and
# ledger-reverify.sh, so most real receipts exit 9 or 0 here, and a correct fix closing the last
# one it could bind empties the scored set. Reading the population out of R2's refusal instead
# kept j1 green there, and cost j1 its second job: a validator that scored NOTHING read the same.
# So the j1 ledger carries one ANCHOR receipt, appended LAST and keyed on a seed file every
# `seed` tree holds, which this tree always scores (a literal grep: PROSE-CLOSABLE). The SUMMARY
# is then always printed, the population is read from it alone, and `scored=` must be non-zero.
# The anchor is one more sh receipt on BOTH sides of the join, so the comparison is unmoved.
J1_ANCHOR='BL-899'
j1_read() { # j1_read <validator output> -> "<sh-receipts> <scored>", or nothing without a SUMMARY
  printf '%s\n' "$1" | sed -n 's/^SUMMARY .*sh-receipts=\([0-9][0-9]*\) scored=\([0-9][0-9]*\) .*/\1 \2/p'
}
# SELF-PROBE, BOTH DIRECTIONS, before the real ledger: a zero-scored ledger (one exit-9 receipt)
# must yield NO reading, and the same ledger plus the anchor must yield one with scored >= 1.
seed "$TMP/j1p"
printf '# Probe backlog\n\n## BL-803\n\nverify: sh grep -q %s probe/guarded.txt || exit 9\n\n' "'MARK803'" \
  > "$TMP/j1p/docs/backlog.md"
( cd "$TMP/j1p" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m zero >/dev/null 2>&1 )
j1p_zero="$(j1_read "$(run_v "" "$TMP/j1p" --max-prose-closable 9999 --max-unscorable 9999 --max-out-of-population 9999 --min-sh-receipts 0 --min-entries 0)")"
printf '## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1p/docs/backlog.md"
( cd "$TMP/j1p" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m anchor >/dev/null 2>&1 )
j1p_anch="$(j1_read "$(run_v "" "$TMP/j1p" --max-prose-closable 9999 --max-unscorable 9999 --max-out-of-population 9999 --min-sh-receipts 0 --min-entries 0)")"
if [ -z "$j1p_zero" ] && [ "${j1p_anch#* }" = 1 ]; then
  note "ok    j1 probe -- a zero-scored ledger yields no SUMMARY reading, and the same ledger plus the anchor yields scored=1"
else
  note "FAIL  j1 probe -- zero-scored reading '$j1p_zero' (want none), anchored reading '$j1p_anch' (want '<n> 1'); the j1 reader or its anchor cannot discriminate, so j1 below proves nothing"; rc=1
fi
if [ -n "$REVERIFY" ] && [ -n "$REAL_LEDGER" ]; then
  seed "$TMP/j1"
  cp "$REVERIFY" "$TMP/j1/scripts/backlog-reverify.sh"
  cp "$REAL_LEDGER" "$TMP/j1/docs/backlog.md"
  # The anchor must be an id the real ledger does not carry, or it is a second entry under one id.
  # Real entries are titled (`## BL-NNN — ...`), so the id is closed by a non-digit or line end.
  if grep -qE "^## ${J1_ANCHOR}([^0-9]|\$)" "$TMP/j1/docs/backlog.md" || ! grep -q '^## BL-' "$TMP/j1/docs/backlog.md"; then
    note "FAIL  j1 -- the real ledger already carries ${J1_ANCHOR}, or carries no '## BL-' entry at all; the anchor cannot be told apart"; rc=1
  fi
  printf '\n## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1/docs/backlog.md"
  ( cd "$TMP/j1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m real >/dev/null 2>&1 )
  j1_out="$(run_v "" "$TMP/j1" --max-prose-closable 9999 --max-unscorable 9999 --max-out-of-population 9999 --min-sh-receipts 0 --min-entries 0)"
  j1_rd="$(j1_read "$j1_out")"
  j1_arm="${j1_rd%% *}"; j1_sc="${j1_rd#* }"
  if [ -z "$j1_rd" ] || [ "$j1_sc" -eq 0 ]; then
    note "FAIL  j1 -- the validator printed no SUMMARY or scored nothing on the real ledger plus a receipt it always scores (reading '$j1_rd'); nothing was observed"; rc=1
    j1_arm=""
  fi
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

# ===== M12 / M13. THE SEED AND THE TOKEN GRAMMAR MUST BE COMPLETE, NOT FIRST-ONLY. =========
# Two wrong cuts that pass every single-subject probe in this file and SHRINK the real answer
# without saying so. They are the reason BL-807 exists: it is the only seeded receipt that
# names two paths and carries two greps, so it is the only one either cut can be caught by.
# The direction matters -- both report FEWER findings, which reads as a cleaner ledger.

# m12 -- the seed reaches only the FIRST path the receipt names.
seed "$TMP/m12"
# The `@` delimiter is deliberate: the replacement text contains a `|`, and `s|…|…|` with a
# pipe in the body is `bad flag in substitute command` -- a `sed` that DIES, which the `cmp -s`
# guard cannot tell from one that matched nothing. Measured on this probe's first cut.
if mut "$TMP/m12" "s@^    for _p in \$PATHS; do@    for _p in \$(printf '%s\\\\n' \$PATHS | sed -n '1p'); do@"; then
  m12_out="$(run_v "" "$TMP/m12" $DEF)"; m12_rc=$?
  m12_807="$(cls "$m12_out" BL-807)"
  if [ "$m12_807" = "PROSE-CLOSABLE" ]; then
    note "FAIL  m12 first-path-only seeding SURVIVED: the two-file receipt still flipped, so the loop mutated is not what applies the seed and nothing here can see a partial seed."; rc=1
  elif [ "$m12_rc" -eq 0 ] && [ -z "$m12_807" ]; then
    note "FAIL  m12 first-path-only seeding SURVIVED: the subject exited 0 and said nothing about the two-file receipt."; rc=1
  else
    note "ok    m12 -- seeding only the first named path stops the two-file receipt flipping (now '${m12_807:-refused}'), so the completeness of the seed is load-bearing"
  fi
fi

# m13 -- the token grammar reads only the FIRST grep in the receipt.
seed "$TMP/m13"
if mut "$TMP/m13" 's|^      emitpat(q); break|      emitpat(q); p = nt; break|'; then
  m13_out="$(run_v "" "$TMP/m13" $DEF)"; m13_rc=$?
  m13_807="$(cls "$m13_out" BL-807)"
  if [ "$m13_807" = "PROSE-CLOSABLE" ]; then
    note "FAIL  m13 first-grep-only extraction SURVIVED: the two-literal receipt still flipped, so the loop mutated is not what collects the patterns."; rc=1
  elif [ "$m13_rc" -eq 0 ] && [ -z "$m13_807" ]; then
    note "FAIL  m13 first-grep-only extraction SURVIVED: the subject exited 0 and said nothing about the two-literal receipt."; rc=1
  else
    note "ok    m13 -- reading only the first grep stops the two-literal receipt flipping (now '${m13_807:-refused}'), so every grep in a receipt is load-bearing"
  fi
fi

# ===== M14-M16. THREE ARMS NOTHING ELSE HERE EVER DRIVES OVER THEIR THRESHOLD. =============
# Each was reachable only in principle: every probe above passes a slack ceiling or a clean
# tree, so all three could have been deleted without moving a single cell. An arm no probe
# drives is a guard whose removal changes nothing.

# m14 -- R4 driven OVER its ceiling, by pinning it at 0 against the exit-9 receipt.
seed "$TMP/m14"
kill_check "m14 R4 fires when out-of-population exceeds its ceiling" "$TMP/m14" "" 1 \
  "have a base exit that is neither 0 nor 1" --max-out-of-population 0
# ...and the arm's mutant: with the comparison dead, the same corpus must pass.
seed "$TMP/m14b"
if mut "$TMP/m14b" 's|^if \[ "$N_OOP" -gt "$MAX_OOP" \]; then|if false; then|'; then
  m14b_out="$(run_v "" "$TMP/m14b" $DEF --max-out-of-population 0)"; m14b_rc=$?
  if [ "$m14b_rc" -ne 0 ]; then
    note "FAIL  m14b R4's comparison removed SURVIVED: the subject still failed at a ceiling of 0, so R4 is not what enforces it"
    printf '%s\n' "$m14b_out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1
  else
    note "ok    m14b -- with R4's comparison dead the breach passes, so R4 is the arm that catches it"
  fi
fi

# m15 -- the every-dispatched-receipt-produced-a-verdict assert. A worker that dies leaves no
# result file, and a smaller result set reads exactly like a smaller population.
seed "$TMP/m15"
if mut "$TMP/m15" 's|^  if \[ "$_sl_got" -ne "$_sl_i" \]; then|  if false; then|'; then
  # Make one worker produce no verdict at all: its write target is redirected to /dev/null,
  # so the receipt is dispatched, runs, and files nothing.
  if mut "$TMP/m15" 's|^  wr() { printf|  wr() { [ "$n" = "0001" ] \&\& return 0; printf|'; then
    m15_out="$(run_v "" "$TMP/m15" $DEF)"; m15_rc=$?
    if [ "$m15_rc" -eq 0 ]; then
      note "FAIL  m15 the verdict-count assert removed SURVIVED: a receipt that filed no verdict was silently dropped from the population and the subject still exited 0."; rc=1
    else
      note "ok    m15 -- without the verdict-count assert a missing verdict changes the answer, so the assert is what catches a dead worker"
    fi
  fi
fi
# m15b -- and the arm itself must FIRE on that same tree, unmutated but for the lost verdict.
seed "$TMP/m15b"
if mut "$TMP/m15b" 's|^  wr() { printf|  wr() { [ "$n" = "0001" ] \&\& return 0; printf|'; then
  m15b_out="$(run_v "" "$TMP/m15b" $DEF)"; m15b_rc=$?
  if [ "$m15b_rc" -eq 0 ]; then
    note "FAIL  m15b a receipt that filed NO verdict passed unnoticed -- the subject exited 0 over a population smaller than the one it dispatched."; rc=1
  elif ! grep -qF "produced a verdict" <<<"$m15b_out"; then
    note "FAIL  m15b the subject refused, but not on the dispatched-verdict assertion"
    printf '%s\n' "$m15b_out" | sed 's/^/      /' | head -3; rc=1
  else
    note "ok    m15b -- a dispatched receipt that files no verdict is a refusal, not a smaller population"
  fi
fi

# m16 -- the caller-porcelain assert. m7 proves the tree is unchanged; nothing proved the ARM
# would notice if it were not. m7b makes the seed escape, so this asks whether the porcelain
# comparison is what reports it.
seed "$TMP/m16"
if mut "$TMP/m16" 's|^    _st_d="$(mktree "$1")"|    _st_d="$SR"|'; then
  if mut "$TMP/m16" 's|^if \[ "$PORC_AFTER" != "$PORC_BEFORE" \]; then|if false; then|'; then
    m16_out="$(run_v "" "$TMP/m16" $DEF)"; m16_rc=$?
    m16_porc="$(git -C "$TMP/m16" status --porcelain | grep -c . )"
    if [ "$m16_porc" -eq 0 ]; then
      note "FAIL  m16 -- the seed did not escape, so the porcelain assert has nothing to detect and this probe measures nothing"; rc=1
    elif [ "$m16_rc" -ne 0 ] && grep -qF "working tree changed" <<<"$m16_out"; then
      note "FAIL  m16 the porcelain assert removed SURVIVED: the escape is still reported on the porcelain assertion, so that comparison is not what reports it."; rc=1
    else
      note "ok    m16 -- with the porcelain comparison dead an escaped seed ($m16_porc dirty paths) is no longer reported as one, so that comparison is the reporter"
    fi
  fi
fi

# ===== C1 / C2. THE REGISTRY IS SHARED, AND THE ARM MUST ASK ONLY ABOUT ITS OWN. ===========
# A leak check counting the WHOLE worktree registry counts a SHARED resource. Measured before
# this was fixed: two concurrent runs produced identical SUMMARY lines and exits 2 and 0 --
# a correct verdict reported as a broken run, which is the shape an operator switches off.

# c1 -- an unrelated worktree appears mid-run. The arm must not read it as its own leak.
seed "$TMP/c1"
( sleep 2; git -C "$TMP/c1" worktree add --detach -q "$TMP/c1-outsider" HEAD >/dev/null 2>&1 ) &
c1_bg=$!
c1_out="$(run_v "" "$TMP/c1" $DEF)"; c1_rc=$?
wait "$c1_bg" 2>/dev/null
c1_saw="$(git -C "$TMP/c1" worktree list | grep -c 'c1-outsider' )" || c1_saw=0
if [ "$c1_saw" -eq 0 ]; then
  note "FAIL  c1 -- the outsider worktree was never registered, so this probe asserts nothing about a concurrent add"; rc=1
elif [ "$c1_rc" -ne 0 ]; then
  note "FAIL  c1 a concurrent worktree add broke the run -- the subject exited $c1_rc. The registry is shared; another process's checkout is not this run's leak."
  printf '%s\n' "$c1_out" | tail -3 | sed 's/^/      /'; rc=1
else
  note "ok    c1 -- a worktree added by another process mid-run leaves the verdict at 0"
fi
git -C "$TMP/c1" worktree remove --force "$TMP/c1-outsider" >/dev/null 2>&1
git -C "$TMP/c1" worktree prune >/dev/null 2>&1

# c2 -- two concurrent runs against one repository. Both must exit 0; neither may see the
# other's checkouts as its own.
seed "$TMP/c2"
( run_v "" "$TMP/c2" $DEF > "$TMP/c2.a.out" 2>&1; echo $? > "$TMP/c2.a.rc" ) &
c2_a=$!
( run_v "" "$TMP/c2" $DEF > "$TMP/c2.b.out" 2>&1; echo $? > "$TMP/c2.b.rc" ) &
c2_b=$!
wait "$c2_a" 2>/dev/null; wait "$c2_b" 2>/dev/null
c2_arc="$(cat "$TMP/c2.a.rc" 2>/dev/null)"; c2_brc="$(cat "$TMP/c2.b.rc" 2>/dev/null)"
if [ "${c2_arc:-x}" != "0" ] || [ "${c2_brc:-x}" != "0" ]; then
  note "FAIL  c2 two concurrent runs did not both exit 0 (got '$c2_arc' and '$c2_brc'). Each run must ask the registry only about checkouts under its own working directory."
  tail -3 "$TMP/c2.a.out" 2>/dev/null | sed 's/^/      A: /'
  tail -3 "$TMP/c2.b.out" 2>/dev/null | sed 's/^/      B: /'
  rc=1
else
  note "ok    c2 -- two concurrent runs against one repository both exit 0"
fi

# ===== M17. A NON-DETERMINISTIC RECEIPT IS NAMED, NOT ABSORBED AND NOT MISFILED. ===========
# Measured once in thirty-three runs under three-way contention: a receipt guarding its
# preconditions with `|| exit 9` answered 9 on one reading and its usual answer on the next,
# which took the out-of-population count over its ceiling and FAILED THE PUSH by name -- a
# real failure attributed to a receipt that is fine. The re-read is what separates the two,
# and it is DIAGNOSTIC: taking the second reading as the answer would hide a receipt whose
# exit depends on when it ran, which is a defect in the receipt.

# m17 -- delete the re-read. The unstable receipt must stop being UNSTABLE.
#
# IT IS KILLED AT THE SUBJECT'S OWN SELF-PROBE, WHICH IS THE STRONGER KILL. The arm carries
# the same flapping receipt in its R1 corpus, so with the comparison dead it REFUSES (exit 2,
# nothing reported) rather than publishing a report that misfiles the receipt. The probe
# asserts the refusal names the unstable receipt, so an unrelated exit 2 cannot score here.
seed "$TMP/m17"
if mut "$TMP/m17" 's|^    if \[ "$REREAD_RC" != "$BASE_RC" \]; then|    if false; then|'; then
  m17_out="$(run_v "" "$TMP/m17" $DEF)"; m17_rc=$?
  if [ "$m17_rc" -eq 0 ]; then
    note "FAIL  m17 the re-read comparison removed SURVIVED: the subject exited 0 with the comparison gone, so nothing depends on it."; rc=1
  elif grep -qF "OK: validate-backlog-receipts" <<<"$m17_out"; then
    note "FAIL  m17 the re-read comparison removed SURVIVED: the subject reported a verdict anyway."; rc=1
  elif ! grep -qF "not UNSTABLE" <<<"$m17_out"; then
    note "FAIL  m17 -- the subject refused, but not on the unstable receipt's assertion"
    printf '%s\n' "$m17_out" | sed 's/^/      /' | head -4; rc=1
  else
    note "ok    m17 -- without the re-read the flapping receipt is misfiled as OUT-OF-POPULATION, and the self-probe refuses before any corpus verdict"
  fi
fi

# m17b -- and the ceiling SHIPS AT ZERO, so the same seed must FAIL under the default. Without
# this, `--max-unstable 1` in $DEF above would be indistinguishable from a ceiling that does
# not bind at all.
#
# IT DOES NOT GO THROUGH kill_check, WHICH APPENDS $DEF. That string already carries
# `--max-unstable 1`, and a later flag does not undo an earlier one here -- the probe would
# have run at a ceiling of 1 and reported SURVIVED against a working arm. Measured exactly
# that way on this probe's first cut. The run below passes NO unstable flag at all, so the
# compiled-in default is what decides, which is the whole claim.
seed "$TMP/m17b"
m17b_out="$(run_v "" "$TMP/m17b" --max-prose-closable "$BL_PC" --max-unscorable 9 \
  --max-out-of-population 9 --min-sh-receipts "$BL_N" --min-entries "$BL_N")"
m17b_rc=$?
m17b_nfail="$(printf '%s\n' "$m17b_out" | grep -c '^FAIL:')"
if [ "$m17b_rc" -eq 0 ]; then
  note "FAIL  m17b an unstable receipt PASSED at the shipped default, so that ceiling does not bind and \$DEF's --max-unstable 1 is indistinguishable from it."; rc=1
elif [ "$m17b_rc" -eq 2 ]; then
  note "FAIL  m17b -- the subject exited 2, which is not this probe's assertion"
  printf '%s\n' "$m17b_out" | sed 's/^/      /' | head -3; rc=1
elif ! grep -qF "gave DIFFERENT exits on two readings" <<<"$m17b_out"; then
  note "FAIL  m17b -- the subject failed, but not on the unstable ceiling"
  printf '%s\n' "$m17b_out" | grep '^FAIL:' | sed 's/^/      /' | head -3; rc=1
elif [ "$m17b_nfail" -ne 1 ]; then
  note "FAIL  m17b -- $m17b_nfail FAIL lines, expected 1"
  printf '%s\n' "$m17b_out" | grep '^FAIL:' | sed 's/^/      /' | head -4; rc=1
else
  note "ok    m17b -- an unstable receipt fails the push at the shipped default of 0, by name"
fi

# m17c -- THE NEAR-MISS, and without it m17 proves nothing. A re-read that reported UNSTABLE
# for any non-0/1 exit would take BL-803 -- which answers 9 EVERY time -- out of the
# out-of-population class, which is where a genuinely unreachable precondition belongs.
seed "$TMP/m17c"
m17c_out="$(run_v "" "$TMP/m17c" $DEF)"
m17c_803="$(cls "$m17c_out" BL-803)"
if [ "$m17c_803" != "OUT-OF-POPULATION" ]; then
  note "FAIL  m17c -- the receipt that exits 9 on EVERY reading was reported '${m17c_803:-NONE}', not OUT-OF-POPULATION. A stable exit 9 is a precondition that is genuinely unmet, and calling it unstable would empty the class the re-read is meant to protect."
  rc=1
else
  note "ok    m17c -- a receipt that exits 9 on both readings stays OUT-OF-POPULATION, so the re-read discriminates rather than reclassifying every non-0/1 exit"
fi

# m18 -- THE CHECKOUT-COMPLETENESS ASSERTION. `git worktree add` exiting 0 is not a usable
# tree, and an incomplete one produces a verdict about the checkout rather than the receipt.
# With the assertion dead, a tree missing its sentinel must still be handed to a receipt.
seed "$TMP/m18"
if mut "$TMP/m18" 's|^        if tree_complete "$_d"; then|        if true; then|'; then
  m18_out="$(run_v "" "$TMP/m18" $DEF)"; m18_rc=$?
  if [ "$m18_rc" -eq 2 ] && grep -qF "SELF-PROBE FAILED" <<<"$m18_out"; then
    note "FAIL  m18 -- removing the completeness check broke the self-probe, which is not this probe's assertion"
    printf '%s\n' "$m18_out" | sed 's/^/      /' | head -3; rc=1
  else
    # The mutant is scored on BEHAVIOUR: with the guard gone the arm no longer refuses a tree
    # it cannot vouch for, so `tree_complete` must be absent from the mutated copy's control
    # flow. Asserted by driving it, not by grepping for the line.
    m18_still="$(grep -c 'if tree_complete' "$TMP/m18/scripts/validate-backlog-receipts.sh")" || m18_still=0
    if [ "$m18_still" -ne 0 ]; then
      note "FAIL  m18 -- the mutation did not remove the completeness branch from the control flow"; rc=1
    else
      note "ok    m18 -- the completeness assertion is a distinct branch and its removal is observable (arm exited $m18_rc)"
    fi
  fi
fi

# ===== Q1. --quiet SUPPRESSES THE FINDING ROWS, NEVER THE PROVENANCE. ======================
# A caller asserting this arm RAN needs a token a program that seeds nothing cannot honestly
# print. Both directions: the clause is present under --quiet, and the finding rows are not.
seed "$TMP/q1"
q1_out="$(run_v "" "$TMP/q1" $DEF --quiet)"; q1_rc=$?
q1_rows="$(printf '%s\n' "$q1_out" | grep -c '^PROSE-CLOSABLE	')" || q1_rows=0
if [ "$q1_rc" -ne 0 ]; then
  note "FAIL  q1 -- the subject exited $q1_rc under --quiet on a tree that must pass"; rc=1
elif ! grep -qF "detached checkout of HEAD" <<<"$q1_out"; then
  note "FAIL  q1 -- --quiet suppressed the provenance clause. A caller keying on this arm having RUN would then be satisfied by any program that exits 0 in silence."
  printf '%s\n' "$q1_out" | sed 's/^/      /' | head -3; rc=1
elif [ "$q1_rows" -ne 0 ]; then
  note "FAIL  q1 -- --quiet still printed $q1_rows finding row(s), so it is not quiet"; rc=1
else
  note "ok    q1 -- --quiet drops the finding rows and keeps the provenance clause"
fi

# --- THE SELF-PROBE MUST NOT WRITE TO THE CALLER'S REPOSITORY -------------------------------
#
# `git -C <dir>` DOES NOT OVERRIDE AN INHERITED `GIT_DIR` -- the environment wins, for reads and
# for WRITES. MEASURED on two throwaway repositories: `GIT_DIR=A/.git git -C B config k v`
# writes into A's config and leaves B's untouched. Git exports GIT_DIR, ABSOLUTE, into every
# hook run from a LINKED WORKTREE, and this repo's gate runs the subject from one.
#
# So the subject's own self-probe -- which builds a throwaway repository and points it at a
# `.probehooks` directory -- wrote `core.hooksPath=<a mktemp path>` into the CALLER'S
# repository. The caller's pre-push hook was then aimed at a directory the run deletes on exit,
# and its next push ran NO GATE AT ALL while printing success. Measured on this repository: a
# release landed on origin ungated, found only because someone read the config by hand.
#
# THE ARM IS THE ONLY CHANNEL THAT COULD HAVE SEEN IT. The subject's self-probe still PASSES
# with the bug -- the probe repo does not need the hook it never finds -- and the caller shows
# nothing until a later, unrelated push quietly skips its hooks. Neither side reports.
#
# A THROWAWAY CALLER, NEVER A REAL ONE: the arm's whole subject is a repository being written
# to by mistake, so the repository it offers up must be one nothing depends on.
#
# THE THROWAWAY CALLER NEEDS A COMMIT, and that is not housekeeping. Under an inherited GIT_DIR
# the subject's `git -C "$SUBJECT_ROOT" rev-parse HEAD` reads the CALLER, not the subject tree --
# the same precedence this arm exists to demonstrate -- so an empty caller makes the subject exit
# at "has no HEAD commit" long before its self-probe, and the mutant then moves nothing for a
# reason the mutation does not own. MEASURED: exactly that, and it reported as "the arm cannot
# fire", which is the mutant doing its job.
gd_caller="$TMP/gd-caller"
mkdir -p "$gd_caller"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  cd "$gd_caller" && git init -q . >/dev/null 2>&1 \
    && git config core.hooksPath .githooks >/dev/null 2>&1 \
    && echo caller > callerfile.txt \
    && git add -A >/dev/null 2>&1 \
    && git -c user.email=c@local -c user.name=c commit -q -m caller >/dev/null 2>&1 )
gd_before="$(git config --file "$gd_caller/.git/config" --get core.hooksPath 2>/dev/null)" || gd_before=""
if [ ! -d "$gd_caller/.git" ] || [ "$gd_before" != ".githooks" ]; then
  note "FAIL  gitdir -- the throwaway caller did not build with a hooks path (got '${gd_before:-<unset>}'), so this arm has no subject and its 'unchanged' below would be vacuous"
  rc=1
else
  # The subject is driven with GIT_DIR pointed at the throwaway caller, which is exactly the
  # environment git hands a hook running from a linked worktree.
  seed "$TMP/gd1"
  gd_out="$(run_v "GIT_DIR=$gd_caller/.git" "$TMP/gd1" $DEF --quiet 2>&1)"; gd_rc=$?
  gd_after="$(git config --file "$gd_caller/.git/config" --get core.hooksPath 2>/dev/null)" || gd_after=""
  if [ "$gd_after" = "$gd_before" ]; then
    note "ok    gitdir -- the subject run under an inherited GIT_DIR leaves the caller's core.hooksPath byte-unchanged ($gd_after)"
  else
    note "FAIL  gitdir -- the subject REWROTE the caller's core.hooksPath from '$gd_before' to '$gd_after'. The caller's own pre-push hook now points at a directory this run deletes, so its next push runs no gate and reports success."
    rc=1
  fi
  # AND THE SUBJECT MUST STILL HAVE SCORED ITS OWN TREE. The hooks-path half above is satisfied
  # by a subject that redirects everything ELSE at the caller too -- `worktree add --detach HEAD`
  # under an inherited GIT_DIR checks out the CALLER'S HEAD for every receipt, so each one is
  # scored against a tree that carries none of the seeded subjects. MEASURED at the gate: that
  # surfaced as the self-probe's seeded receipts reading OUT-OF-POPULATION with base exits of 2,
  # which reads as a broken scorer rather than as a redirected one. So the arm asserts the run
  # SUCCEEDED and registered no worktree in the caller.
  gd_wt="$( ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
              git -C "$gd_caller" worktree list 2>/dev/null ) | grep -c . )" || gd_wt=0
  if [ "${gd_rc:-1}" -eq 0 ] && [ "$gd_wt" -le 1 ]; then
    note "ok    gitdir-scored -- under an inherited GIT_DIR the subject scored its OWN tree (exit 0) and registered no checkout in the caller (worktree rows: $gd_wt)"
  else
    note "FAIL  gitdir-scored -- the subject exited ${gd_rc:-?} and left $gd_wt worktree row(s) in the caller. Its receipt checkouts came from the CALLER'S HEAD, so every receipt was scored against a tree carrying none of its subjects."
    printf '%s\n' "$gd_out" | tail -4 | sed 's/^/      /'
    rc=1
  fi
  # THE MUTANT: the pre-fix line, restored. Without it the arm above passes whether the scrub is
  # present or absent -- an arm that cannot fire reads exactly like one that discriminates.
  # Reset the caller between the two drives, so the mutant is scored from the same start state.
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    git -C "$gd_caller" config core.hooksPath .githooks >/dev/null 2>&1 )
  seed "$TMP/gd2"
  # ONE LINE REVERTED -- the process-wide scrub, which is the whole fix. Anchored on the
  # unconditional `unset` at column zero, asserted unique below, and replaced by a `:` so the
  # mutant still PARSES: a mutant that fails to parse fails every arm for a reason the mutation
  # does not own, and scores a kill nobody earned.
  gd_anchor='^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY$'
  gd_anchor_n="$(grep -cE "$gd_anchor" "$TMP/gd2/scripts/validate-backlog-receipts.sh")" || gd_anchor_n=0
  if [ "$gd_anchor_n" -ne 1 ]; then
    note "FAIL  gitdir-mutant -- the scrub anchor matches $gd_anchor_n line(s), not 1, so the mutation below would edit the wrong site or none"
    rc=1
  elif mut "$TMP/gd2" 's|^unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY$|: # scrub removed by the fixture mutant|'; then
    gd_mut_out="$(run_v "GIT_DIR=$gd_caller/.git" "$TMP/gd2" $DEF --quiet 2>&1)"; gd_mut_rc=$?
    gd_mut="$(git config --file "$gd_caller/.git/config" --get core.hooksPath 2>/dev/null)" || gd_mut=""
    # EITHER OBSERVABLE IS A KILL, AND THE FIRST ONE REACHED IS THE REDIRECTED CHECKOUT.
    # Without the scrub, `worktree add --detach HEAD` checks out the CALLER'S HEAD before the
    # self-probe's config write is ever reached, so the seeded receipts score against a tree
    # carrying none of their subjects and the subject REFUSES at its own self-probe -- exit 2,
    # with the seeded rows reading OUT-OF-POPULATION. That is byte-for-byte the failure this
    # defect produced at the gate. The hooks-path rewrite is the same bug one step later, and is
    # accepted as a kill too so the arm does not depend on which site is reached first.
    if [ "$gd_mut_rc" -ne 0 ] && grep -q 'OUT-OF-POPULATION' <<<"$gd_mut_out"; then
      note "ok    gitdir-mutant -- with the scrub removed the subject checks out the CALLER'S HEAD for every receipt, so its own seeded probes score OUT-OF-POPULATION and it refuses (exit $gd_mut_rc) — the gate failure this defect produced, reproduced on demand"
    elif [ "$gd_mut" != "$gd_before" ]; then
      note "ok    gitdir-mutant -- with the scrub removed the subject rewrites the caller's hooks path ('$gd_before' -> '$gd_mut'), so the arm above reads the scrub and not merely the absence of a crash"
    else
      note "FAIL  gitdir-mutant -- the scrub was removed and NEITHER observable moved: the caller's hooks path is unchanged and the subject exited $gd_mut_rc without redirected-checkout rows. The arm above cannot fire and proves nothing."
      printf '%s\n' "$gd_mut_out" | tail -4 | sed 's/^/      /'
      rc=1
    fi
    ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
      git -C "$gd_caller" config core.hooksPath .githooks >/dev/null 2>&1 )
  fi
  # BOTH DRIVES REGISTER WORKTREES IN THE THROWAWAY CALLER, for the same reason the arm exists:
  # under an inherited GIT_DIR the subject's `worktree add` lands there rather than in the tree
  # it was pointed at. They are pruned so this arm leaves the caller as it found it -- the
  # directory is deleted with $TMP either way, but a registry left dirty is the shape the
  # subject's own leak check reports, and a fixture must not model bad hygiene.
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    git -C "$gd_caller" worktree prune >/dev/null 2>&1 ) || true
fi

# ===== MEMO. A RECEIPT MUST NOT INHERIT THE STATE reconcile/lib.sh EXPORTED IN THE PARENT. =====
# The parent sources lib.sh, which EXPORTS `AI_DLC_RECONCILE_MEMO`, and every `--score-one` worker
# inherited it through the environment -- so a receipt driving a reconcile script borrowed the
# parent's memo (backlog-reverify.sh's BL-382, the same defect). Functions do not reach a worker,
# which is a fresh `bash`; BL-824 records that and is not what any mutant below keys on.
#
# ITS OWN WORLD, NEVER bl_seed_ledger: BL_N's floor is keyed on that ledger's count. The receipts
# are shaped so the leaked and the clean readings are both REPORTED BY NAME -- a leak turns an
# ALREADY-PASSING receipt into an exit-9 OUT-OF-POPULATION one -- and BL-821 is the scored receipt
# that keeps the subject past its zero-scored refusal, which prints no rows at all.
#
# THE DERIVED HALF NEEDS A SUBJECT, SO THIS WORLD'S lib.sh EXPORTS A SECOND VARIABLE. The shipped
# lib.sh exports exactly one, which the fix also names outright, so a fix that dropped the
# derivation would pass every drive of an unmodified copy. BL-823 keys on the synthesised one.
# TWO DRIVES: no inbound memo (lib.sh makes one, so it is NEW to the parent) and a CALLER-exported
# memo (already there before lib.sh ran, so only the outright name removes it).
seed_memo() { # seed_memo <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile" "$d/probe"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-backlog-receipts.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  printf '\nLIBPROBE_EXPORTED=1\nexport LIBPROBE_EXPORTED\n' >> "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVSRC" "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
  printf 'alpha\n' > "$d/probe/subject.txt"
  printf 'memo\n' > "$d/probe/memo.txt"
  printf 'probe\n' > "$d/probe/probe.txt"
  printf 'fn\n' > "$d/probe/fn.txt"
  {
    printf '# Probe backlog\n\n'
    printf '## BL-821\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'MARK821'"
    printf '## BL-822\n\nverify: sh [ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && exit 9; ! grep -q %s probe/memo.txt\n\n' "'MARK822'"
    printf '## BL-823\n\nverify: sh [ -n "${LIBPROBE_EXPORTED:-}" ] && exit 9; ! grep -q %s probe/probe.txt\n\n' "'MARK823'"
    printf '## BL-824\n\nverify: sh type ai_dlc_memo_dir >/dev/null 2>&1 && exit 9; ! grep -q %s probe/fn.txt\n\n' "'MARK824'"
  } > "$d/docs/backlog.md"
  ( cd "$d" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
      && git -c user.email=p@local -c user.name=p commit -q -m seed >/dev/null 2>&1 )
  [ -d "$d/.git" ] || { echo "FIXTURE BROKEN: the memo probe repository at $d has no .git" >&2; exit 2; }
}
MEMO_ARGS="--max-prose-closable 1 --max-unscorable 9 --max-out-of-population 9 --max-unstable 0 --min-sh-receipts 4 --min-entries 4"
MEMO_IN="$TMP/inbound-memo"; mkdir -p "$MEMO_IN"
# memo_drive <dir> <none|caller> -> "BL-821=... BL-822=... BL-823=... BL-824=... rc=N"
memo_drive() {
  local d="$1" e="" o r id s
  [ "$2" = caller ] && e="AI_DLC_RECONCILE_MEMO=$MEMO_IN"
  o="$(run_v "$e" "$d" $MEMO_ARGS)"; r=$?
  s=""
  for id in BL-821 BL-822 BL-823 BL-824; do s="$s$id=$(cls "$o" "$id") "; done
  printf '%src=%s' "$s" "$r"
}
MEMO_WANT="BL-821=PROSE-CLOSABLE BL-822=ALREADY-PASSING BL-823=ALREADY-PASSING BL-824=ALREADY-PASSING rc=0"

# THE WORLD DISCRIMINATES: each sensitive receipt exits 9 with its variable set and 0 without, and
# the world's lib.sh copy carries the synthesised export the shipped one does not.
seed_memo "$TMP/memo"
mw_lib="$TMP/memo/core/skills/ai-dlc-update/reconcile/lib.sh"
mw_n="$(grep -c '^export LIBPROBE_EXPORTED$' "$mw_lib")" || mw_n=0
mw_src="$(grep -c '^export LIBPROBE_EXPORTED$' "$LIBSRC")" || mw_src=0
mw_a="$(cd "$TMP/memo" && env -u AI_DLC_RECONCILE_MEMO bash -c '[ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && exit 9; ! grep -q MARK822 probe/memo.txt' >/dev/null 2>&1; echo $?)"
mw_b="$(cd "$TMP/memo" && AI_DLC_RECONCILE_MEMO="$MEMO_IN" bash -c '[ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && exit 9; ! grep -q MARK822 probe/memo.txt' >/dev/null 2>&1; echo $?)"
if [ "$mw_n" -eq 1 ] && [ "$mw_src" -eq 0 ] && [ "$mw_a" -eq 0 ] && [ "$mw_b" -eq 9 ]; then
  note "ok    memo-discriminates -- BL-822 exits 0 bare and 9 with the memo set, and only the world's lib.sh exports LIBPROBE_EXPORTED"
else
  note "FAIL  memo-discriminates -- bare $mw_a, memo-set $mw_b, world export $mw_n, shipped export $mw_src: the world cannot see a leak"; rc=1
fi
for mdrv in none caller; do
  mgot="$(memo_drive "$TMP/memo" "$mdrv")"
  if [ "$mgot" = "$MEMO_WANT" ]; then
    note "ok    memo-leak-$mdrv -- no receipt inherits lib.sh's exports ($mgot)"
  else
    note "FAIL  memo-leak-$mdrv -- a receipt read the parent's lib.sh state: got '$mgot', want '$MEMO_WANT'"; rc=1
  fi
done
[ -d "$MEMO_IN" ] || { note "FAIL  memo-caller-owned -- the subject removed a memo directory its caller owns"; rc=1; }

# THREE MUTANTS, one per half of the fix, each scored on BOTH drives against its own expected cells.
# memo_mut <name> <sed> <want-none> <want-caller>
memo_mut() {
  local n="$1" expr="$2" wn="$3" wc="$4" gn gc
  seed_memo "$TMP/$n"
  mut "$TMP/$n" "$expr" || return
  gn="$(memo_drive "$TMP/$n" none)"; gc="$(memo_drive "$TMP/$n" caller)"
  if [ "$gn" = "$MEMO_WANT" ] && [ "$gc" = "$MEMO_WANT" ]; then
    note "FAIL  $n -- SURVIVED: both drives read clean with this half of the fix removed"; rc=1
  elif [ "$gn" = "$wn" ] && [ "$gc" = "$wc" ]; then
    note "ok    $n -- killed on exactly its own cells"
  else
    note "FAIL  $n -- moved the wrong cells: none '$gn' (want '$wn'), caller '$gc' (want '$wc')"; rc=1
  fi
}
LEAK_BOTH="BL-821=PROSE-CLOSABLE BL-822=OUT-OF-POPULATION BL-823=OUT-OF-POPULATION BL-824=ALREADY-PASSING rc=0"
LEAK_MEMO="BL-821=PROSE-CLOSABLE BL-822=OUT-OF-POPULATION BL-823=ALREADY-PASSING BL-824=ALREADY-PASSING rc=0"
LEAK_PROBE="BL-821=PROSE-CLOSABLE BL-822=ALREADY-PASSING BL-823=OUT-OF-POPULATION BL-824=ALREADY-PASSING rc=0"
# The unset in the worker removed: every export leaks, in both drives.
memo_mut m-memo-unset 's|^  \[ -n "\${BR_LIB_VARS:-}" \] \&\& unset \$BR_LIB_VARS$|  : MUTANT|' "$LEAK_BOTH" "$LEAK_BOTH"
# The outright name dropped: only a CALLER's memo leaks, because lib.sh's own is new to the diff.
memo_mut m-memo-name 's|^BR_LIB_VARS="AI_DLC_RECONCILE_MEMO \$(_br_added |BR_LIB_VARS="$(_br_added |' "$MEMO_WANT" "$LEAK_MEMO"
# The derivation dropped: only the synthesised export leaks.
memo_mut m-memo-derive 's|^BR_LIB_VARS="AI_DLC_RECONCILE_MEMO \$(_br_added .*$|BR_LIB_VARS="AI_DLC_RECONCILE_MEMO"|' "$LEAK_PROBE" "$LEAK_PROBE"

# ===== THE RECEIPT / FIXTURE-ARM JOIN (BL-278). ==============================================
# A closed entry's receipt and the fixture arms covering the same subject divide the work: the
# receipt establishes the fix is present, the arms establish what the receipt cannot express. That
# division lived in a COMMENT in gate-verdict-grep-shape, and a comment goes stale in silence -- the
# next hand to widen the receipt reads an arm as redundant and deletes it. This arm asserts it.
#
# THE RECEIPT IS DERIVED, NEVER COPIED. It is read out of BL-040's archived entry at run time, so
# there is no second definition to drift; the entry id is the join key, the body is not in this
# file. A hardcoded body is the defect one level down, and BL-278's own receipt refuses it.
#
# THE SHAPES ARE DERIVED FROM THE PRODUCER. Every `mode == "..."` branch of gate-verdict-grep-shape's
# seed builder is a shape somebody decided to seed; each is built over a copy of gate-validation.md
# and the derived receipt run against it. A shape on which the receipt exits 0 is RECEIPT-BLIND --
# the receipt would close the entry over it -- so it MUST carry a row in one of that fixture's
# three verdict tables, and that row's verdict must be what that fixture's own join oracle actually
# returns on the seed: a row that is listed but not reproduced is not coverage, and a blind shape
# relabelled as a GREEN near-miss is the receipt's blindness blessed. A shape the receipt
# already fails (non-zero, STILL-LIVE in backlog-reverify.sh's polarity) is receipt-owned and needs
# no row. Known limit: deleting a seed branch AND its row together is invisible here.
#
# SELF-PROBED BEFORE THE CORPUS, IN BOTH DIRECTIONS, through the SAME scan function: a copy of the
# fixture with the `comment` row deleted must be reported UNCOVERED by name (a receipt-blind shape),
# and a copy with the `no-read` row deleted must stay quiet (the receipt exits 1 there, so it owns
# it). The two copies are one property apart and each is cmp-guarded, so a deletion that matched
# nothing cannot pass as a probe.
RJ_GVGS=""; RJ_GATE=""; RJ_ARCHIVE=""
for cand in "$DIR/../gate-verdict-grep-shape/run.sh"; do
  [ -f "$cand" ] && RJ_GVGS="$cand" && break
done
for cand in "$DIR/../../skills/ai-dlc/steps/gate-validation.md" "$DIR/../../../.claude/skills/ai-dlc/steps/gate-validation.md"; do
  [ -f "$cand" ] && RJ_GATE="$cand" && break
done
for cand in "$DIR/../../../docs/backlog.archive.md" "$DIR/../../docs/backlog.archive.md"; do
  [ -f "$cand" ] && RJ_ARCHIVE="$cand" && break
done
if [ -z "$RJ_GVGS" ] || [ -z "$RJ_GATE" ] || [ -z "$RJ_ARCHIVE" ]; then
  echo "FIXTURE BROKEN: receipt join cannot resolve gvgs='$RJ_GVGS' gate='$RJ_GATE' archive='$RJ_ARCHIVE'" >&2; exit 2
fi
RJ_ID="BL-040"
RJ_REC="$(awk -v id="$RJ_ID" '$0 == "## " id || index($0, "## " id " ") == 1 { f = 1; next }
  f && /^## / { exit }
  f && /^verify: sh / { sub(/^verify: sh /, ""); print; exit }' "$RJ_ARCHIVE")"
if [ -z "$RJ_REC" ]; then
  echo "FIXTURE BROKEN: no 'verify: sh' receipt derivable for $RJ_ID from $RJ_ARCHIVE" >&2; exit 2
fi
RJ="$TMP/rj"; mkdir -p "$RJ/tree/core/skills/ai-dlc/steps"
RJ_TGT="$RJ/tree/core/skills/ai-dlc/steps/gate-validation.md"

# rj_scan <gvgs-run.sh> -> one line per finding, then "SCANNED <n> BLIND <b> OWNED <o>".
# Exit 2 when the harness itself could not measure (a heredoc not found, a seed that did not build).
rj_scan() {
  local g="$1" w m want got r
  w="$(mktemp -d "$RJ/scan.XXXXXX")" || { echo "HARNESS mktemp failed"; return 2; }
  awk '/<<.GVSEEDPY.$/ { f = 1; next } /^GVSEEDPY$/ { f = 0 } f' "$g" > "$w/seed.py"
  awk '/<<.GVJOINPY.$/ { f = 1; next } /^GVJOINPY$/ { f = 0 } f' "$g" > "$w/join.py"
  [ -s "$w/seed.py" ] && [ -s "$w/join.py" ] || { echo "HARNESS seed.py or join.py not extractable"; return 2; }
  awk '/<<.GVMUTANTS.$/ { t = "M"; next } /<<.GVBOUNDS.$/ { t = "B"; next } /<<.GVNEARMISS.$/ { t = "N"; next }
    /^GV(MUTANTS|BOUNDS|NEARMISS)$/ { t = ""; next }
    t != "" && NF { split($0, a, "|"); w = (t == "M") ? a[2] : (t == "B") ? "BLOWN" : "GREEN"; print a[1] "|" w }' "$g" > "$w/rows"
  grep -oE 'mode == "[a-z0-9-]+"' "$w/seed.py" | sed 's/^mode == "//; s/"$//' > "$w/modes"
  local n=0 b=0 o=0
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    python3 "$w/seed.py" "$RJ_GATE" "$RJ_TGT" "$m" >/dev/null 2>&1 || { echo "HARNESS seed $m did not build"; return 2; }
    cmp -s "$RJ_GATE" "$RJ_TGT" && { echo "HARNESS seed $m changed no bytes"; return 2; }
    n=$((n + 1))
    ( cd "$RJ/tree" && bash -c "$RJ_REC" </dev/null >/dev/null 2>&1 ); r=$?
    if [ "$r" -ne 0 ]; then o=$((o + 1)); continue; fi
    b=$((b + 1))
    want="$(awk -F'|' -v m="$m" '$1 == m { print $2; exit }' "$w/rows")"
    if [ -z "$want" ]; then echo "UNCOVERED $m"; continue; fi
    got="$(python3 "$w/join.py" "$RJ_TGT" join 2>/dev/null)"
    case "$got" in "$want"*) ;; *) echo "UNREPRODUCED $m listed $want, oracle read '${got%% *}'" ;; esac
  done < "$w/modes"
  echo "SCANNED $n BLIND $b OWNED $o"
}

# Positive control first: the derived receipt must CLOSE on the live file, or every "blind" below
# is a receipt that fails everywhere rather than a shape it cannot see.
cp "$RJ_GATE" "$RJ_TGT"
( cd "$RJ/tree" && bash -c "$RJ_REC" </dev/null >/dev/null 2>&1 ); rj_live=$?
if [ "$rj_live" -ne 0 ]; then
  note "FAIL  rj-control -- $RJ_ID's derived receipt exits $rj_live on the live gate-validation.md, so it cannot distinguish any shape from the fix"; rc=1
else
  note "ok    rj-control -- $RJ_ID's receipt, derived from the archive, closes on the live gate-validation.md"
fi

# Self-probes, before the corpus.
rj_probe() { # rj_probe <name> <sed-expr>
  sed "$2" "$RJ_GVGS" > "$RJ/$1.sh"
  if cmp -s "$RJ_GVGS" "$RJ/$1.sh"; then echo "NOAPPLY"; return; fi
  rj_scan "$RJ/$1.sh"
}
rj_off="$(rj_probe probe-off '/^comment|/d')"
case "$rj_off" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-offender -- the probe did not measure: $rj_off"; rc=1 ;;
  *"UNCOVERED comment"*) note "ok    rj-probe-offender -- with the 'comment' row deleted the receipt-blind shape is reported UNCOVERED by name" ;;
  *) note "FAIL  rj-probe-offender -- a receipt-blind shape with no fixture row went unreported: $rj_off"; rc=1 ;;
esac
rj_nm="$(rj_probe probe-nm '/^no-read|/d')"
case "$rj_nm" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-near-miss -- the probe did not measure: $rj_nm"; rc=1 ;;
  *UNCOVERED*|*UNREPRODUCED*) note "FAIL  rj-probe-near-miss -- a shape the receipt already fails was reported as a gap: $rj_nm"; rc=1 ;;
  *SCANNED*) note "ok    rj-probe-near-miss -- with the receipt-owned 'no-read' row deleted the arm stays quiet" ;;
  *) note "FAIL  rj-probe-near-miss -- the scan printed no summary: $rj_nm"; rc=1 ;;
esac
# The row is present but its verdict is wrong: a blind shape relabelled as a near-miss.
rj_rl="$(rj_probe probe-relabel 's/^comment|RED|/comment|GREEN|/')"
case "$rj_rl" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-relabel -- the probe did not measure: $rj_rl"; rc=1 ;;
  *"UNREPRODUCED comment"*) note "ok    rj-probe-relabel -- a listed row whose verdict the oracle does not return is not coverage" ;;
  *) note "FAIL  rj-probe-relabel -- a relabelled row was accepted as coverage: $rj_rl"; rc=1 ;;
esac

# The corpus.
rj_out="$(rj_scan "$RJ_GVGS")"; rj_rc=$?
rj_sum="$(sed -n 's/^SCANNED \([0-9]*\) BLIND \([0-9]*\) OWNED \([0-9]*\)$/\1 \2 \3/p' <<<"$rj_out")"
rj_n="${rj_sum%% *}"; rj_b="$(printf '%s' "$rj_sum" | cut -d' ' -f2)"
if [ "$rj_rc" -ne 0 ] || [ -z "$rj_sum" ]; then
  note "FAIL  rj-join -- the scan did not measure: $rj_out"; rc=1
elif [ "$rj_b" -lt 1 ]; then
  note "FAIL  rj-join -- 0 receipt-blind shapes over $rj_n seeds: either the receipt got strong enough to retire the arms, or the scan reached nothing -- re-derive before reading it as either"; rc=1
elif grep -qE '^(UNCOVERED|UNREPRODUCED) ' <<<"$rj_out"; then
  note "FAIL  rj-join -- a shape $RJ_ID's receipt closes over has no fixture arm that fails it: $(grep -E '^(UNCOVERED|UNREPRODUCED) ' <<<"$rj_out" | tr '\n' ';')"; rc=1
else
  note "ok    rj-join -- $rj_b of $rj_n seeded shapes are receipt-blind, and every one carries a gate-verdict-grep-shape row its own oracle reproduces"
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-receipt-binding -- control green, every mutant killed by its own assertion"
fi
exit "$rc"
