#!/usr/bin/env bash
# h2-attest-scripts-dir — validate-h2-attestation.sh --attest must DRIVE its fixture in
# a real consumer layout, where the core validators live at scripts/ai-dlc/ and bare
# scripts/ holds only consumer-authored tooling.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# v0.138.0 and every release before it computed the validator directory here:
#
#   SCRIPTS_DIR="$PROJECT_DIR/scripts"
#   [ -f "$SCRIPTS_DIR/validate-provenance-block.sh" ] || SCRIPTS_DIR="$PROJECT_DIR/core/scripts"
#   ...
#   bash "$RUN" --scripts "$SCRIPTS_DIR"
#
# Both faults matter, and the second is what made it fatal. The pair predates the
# v0.126.0 relocation, so it never names scripts/ai-dlc/ — and the fallback is assigned
# with NO existence test, so "not found" is indistinguishable from "found at
# core/scripts". That unchecked guess was then ASSERTED to the fixture runner as an
# explicit --scripts override, overriding check-17-bypass/run.sh's own candidate list,
# which has included scripts/ai-dlc/ since v0.126.0 and was right all along.
#
# The result in a consumer: --attest died on
#
#   FAIL: cannot locate validate-provenance-block.sh (pass --scripts DIR)
#
# while the very same fixture, run by hand with no --scripts, self-located and passed
# the full matrix. H2 could not attest, so the sprint's gate log could carry no
# H2_ATTESTED line and the harness self-test had no mechanical result at all.
#
# WHY THIS IS A FIXTURE OF ITS OWN, AND NOT A SECTION IN validator-path-resolution.
#
# That fixture already enumerates every core/scripts/*.sh, including this one, and is the
# obvious home. It cannot host this proof. To compare layouts it installs all ~26
# validators into BOTH scripts/ and scripts/ai-dlc/ — and in that tree the BROKEN line
# finds $WORK/scripts/validate-provenance-block.sh and succeeds. The assertion would be
# green against the exact bug it was written for.
#
# The proof needs a tree where bare scripts/ is what a real consumer's is: present,
# populated, and holding no core validator. That is the whole design of this fixture,
# and it is why the decoy below is not decoration.
#
# (validator-path-resolution never reaches this code by another route either: its default
# bare invocation exits at the usage line, the blind spot its own comments name.)

set -uo pipefail

# The validators inherit every AI_DLC_* tunable a consumer sets in settings.json, and the
# script under test reads CLAUDE_PROJECT_DIR directly. Either one, left set, pins the run
# to the REAL repo instead of the synthetic consumer below — where the distribution's
# core/scripts/ exists and the bug cannot reproduce. Scrubbed, not trusted.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
FIXSRC="$(cd "$HERE/.." && pwd)"

# Where the core validators live, in each layout this fixture can run from. Same
# resolution validator-path-resolution uses; bare scripts/ is deliberately not a
# candidate, because in a consumer it is exactly the directory that must NOT hold them.
SRC=""
for cand in "$ROOT/core/scripts" "$ROOT/scripts/ai-dlc"; do
  [ -d "$cand" ] && { SRC="$cand"; break; }
done
[ -n "$SRC" ] || {
  echo "FIXTURE ERROR: core validators not found under $ROOT" >&2
  echo "  looked in: $ROOT/core/scripts (distribution), $ROOT/scripts/ai-dlc (consumer)" >&2
  exit 2; }

SUT="$SRC/validate-h2-attestation.sh"
[ -f "$SUT" ] || { echo "FIXTURE ERROR: $SUT not found" >&2; exit 2; }

# validate-provenance-block.sh loads schemas/provenance-block.json and refuses to guess
# without it, so the synthetic consumer needs a real .claude/schemas/. Omit it and the
# whole check-17 matrix fails on the schema, not on validator location — a red fixture
# that says nothing about the defect under test.
SCHEMAS=""
for cand in "$ROOT/core/schemas" "$ROOT/.claude/schemas"; do
  [ -d "$cand" ] && { SCHEMAS="$cand"; break; }
done
[ -n "$SCHEMAS" ] || { echo "FIXTURE ERROR: schemas directory not found under $ROOT" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# --- a FAITHFUL installed consumer ---------------------------------------------
# .git is the walk-up marker. The core validators go to scripts/ai-dlc/ and NOWHERE
# else; scripts/ carries a consumer-authored decoy, the shape core-manifest.md
# describes (ai-dlc ships audit-rule-files.sh, the consumer owns audit-dormant-gates.sh).
# tests/scripts/ is deliberately never created, so check-17-bypass/run.sh's first
# candidate ($HERE/../../scripts) cannot win by accident and mask a wrong answer.
mkdir -p "$WORK/.git" "$WORK/.claude/schemas" "$WORK/scripts/ai-dlc" "$WORK/tests/fixtures" || exit 2
cp "$SCHEMAS"/*.json "$WORK/.claude/schemas/" 2>/dev/null || {
  echo "FIXTURE ERROR: no schemas to copy from $SCHEMAS" >&2; exit 2; }

n_installed=0
for f in "$SRC"/*.sh "$SRC"/*.js; do
  [ -f "$f" ] || continue
  cp "$f" "$WORK/scripts/ai-dlc/" || exit 2
  n_installed=$((n_installed + 1))
done
[ "$n_installed" -ge 10 ] || {
  echo "FIXTURE ERROR: only $n_installed core scripts found in $SRC" >&2; exit 2; }

printf '#!/usr/bin/env bash\n# consumer-authored, not core\nexit 0\n' \
  > "$WORK/scripts/audit-dormant-gates.sh"

# The decoy must not accidentally BE the file the broken derivation looks for.
[ ! -f "$WORK/scripts/validate-provenance-block.sh" ] || {
  echo "FIXTURE ERROR: bare scripts/ holds a core validator — the tree is not a faithful" >&2
  echo "  consumer and the mutation control below would pass against the real bug." >&2
  exit 2; }

# The three fixture dirs --attest needs: all three feed the digest, and check-17-bypass
# is the one it drives (so its seed.sh must travel with its run.sh).
for d in check-h1-recursion check-17-bypass check-manifest-bypass; do
  [ -d "$FIXSRC/$d" ] || { echo "FIXTURE ERROR: missing source fixture $FIXSRC/$d" >&2; exit 2; }
  cp -R "$FIXSRC/$d" "$WORK/tests/fixtures/" || exit 2
done
chmod +x "$WORK/tests/fixtures"/*/*.sh 2>/dev/null || true

echo "h2-attest-scripts-dir"
echo "  subject: ${SUT#"$ROOT/"}"
echo "  consumer tree: scripts/ai-dlc/ ($n_installed core), scripts/ (1 consumer decoy),"
echo "                 tests/fixtures/ (3), no core/, no tests/scripts/"
echo ""

# --- D. the fixture set resolves at all, in a consumer --------------------------
DIG_OUT="$( cd "$WORK" && bash "$SUT" --digest 2>&1 )"
DIG_RC=$?
if [ "$DIG_RC" -eq 0 ] && grep -qE '^[0-9a-f]{16}$' <<<"$DIG_OUT"; then
  ok "--digest resolves tests/fixtures/ in a consumer ($DIG_OUT)"
else
  bad "--digest failed in a consumer tree (rc=$DIG_RC)"
  printf '%s\n' "$DIG_OUT" | sed 's/^/        /'
fi

# --- A. THE ASSERTION. --attest must drive the fixture end to end ---------------
# This is the run that failed in every consumer for the life of the derivation. It is
# also this fixture's only real cost: one full check-17-bypass drive.
ATT_OUT="$( cd "$WORK" && bash "$SUT" --attest --sprint 999 2>&1 )"
ATT_RC=$?
if [ "$ATT_RC" -ne 0 ]; then
  bad "--attest FAILED in a consumer layout (rc=$ATT_RC) — H2 cannot attest"
  printf '%s\n' "$ATT_OUT" | sed 's/^/        /'
elif grep -qE '^H2_ATTESTED v1 sprint=999 digest=[0-9a-f]{16} at=.+ items=1,2,3 mechanical=check-17-bypass:PASS$' \
     <<<"$ATT_OUT"; then
  ok "--attest drove check-17-bypass and printed the H2_ATTESTED v1 line"
else
  bad "--attest exited 0 but printed no well-formed H2_ATTESTED v1 line"
  printf '%s\n' "$ATT_OUT" | tail -5 | sed 's/^/        /'
fi

# --- B. non-vacuity: a WRONG explicit --scripts must be fatal -------------------
# $WORK/core/scripts is precisely what the shipped derivation computed in a consumer,
# and it does not exist. If A passed while this also passes, A proves nothing about
# locating the validators — the drive would be succeeding regardless.
B_OUT="$( cd "$WORK" && bash "$SUT" --attest --sprint 999 --scripts "$WORK/core/scripts" 2>&1 )"
B_RC=$?
if [ "$B_RC" -ne 0 ]; then
  ok "CONTROL: a wrong explicit --scripts is fatal (so A's pass is about resolution)"
else
  bad "CONTROL: --attest PASSED with --scripts pointed at a nonexistent directory"
  echo "        The drive does not depend on locating the validators. A proves nothing." >&2
  printf '%s\n' "$B_OUT" | tail -5 | sed 's/^/        /' >&2
fi

# --- C. MUTATION: reinstate the pre-v0.139.0 derivation, require it to break ----
# The assertion that goes red the day someone re-adds a guessed SCRIPTS_DIR.
MUT="$WORK/h2-attestation.mutant.sh"
sed 's@^if ! bash "$RUN" .*then$@SCRIPTS_DIR="$PROJECT_DIR/scripts"; [ -f "$SCRIPTS_DIR/validate-provenance-block.sh" ] || SCRIPTS_DIR="$PROJECT_DIR/core/scripts"; if ! bash "$RUN" --scripts "$SCRIPTS_DIR"; then@' \
  "$SUT" > "$MUT"
if cmp -s "$SUT" "$MUT"; then
  bad "MUTATION matched nothing — the fixture runner invocation was renamed or reshaped"
  echo "        Nothing below this line is being tested. Re-anchor the sed on the new form." >&2
else
  MUT_OUT="$( cd "$WORK" && bash "$MUT" --attest --sprint 999 2>&1 )"
  MUT_RC=$?
  if [ "$MUT_RC" -eq 0 ]; then
    bad "MUTATION: the pre-relocation derivation PASSED — this tree is not a faithful consumer"
    echo "        Bare scripts/ or core/scripts/ must hold no core validator, or the guess" >&2
    echo "        lands on a real one and the regression is invisible here." >&2
  elif grep -q 'cannot locate validate-provenance-block.sh' <<<"$MUT_OUT"; then
    ok "MUTATION: the pre-relocation derivation fails exactly as it did in the consumer"
  else
    bad "MUTATION: the derivation failed, but not on validator location (rc=$MUT_RC)"
    printf '%s\n' "$MUT_OUT" | tail -5 | sed 's/^/        /' >&2
  fi
fi

# --- E-J. THE READER. --verify must admit a TRANSCRIBED line -------------------
# A and C above assert the EMITTER. They are structurally blind to the reader: the
# H2_ATTESTED line is printed for a human to paste into a markdown gate log, and what
# comes back through that hand is not what --attest printed. A consumer pasted it into
# the H2 row's Evidence cell of a markdown table; --verify reported "this is the
# sprint's first gate" and the fixture drive re-ran on every later gate, silently.
#
# ONE GRAMMAR, THREE SITES, so the arms below must cover BOTH --verify branches. The
# half-widened fix — widen the digest arm, leave the CHANGED arm at `^` — passes E and
# F and fails G, which is the whole reason G asserts the MESSAGE and not just the exit.
#
# H, I and J are the acquittal half. A grammar that admits a table cell by dropping the
# anchor outright also admits `XH2_ATTESTED` and `NOT_H2_ATTESTED`, so a line DENYING an
# attestation would grant one, and a prose mention of another sprint's line would too.
# Every arm here is PRESENCE- or MESSAGE-shaped: a subject that emits nothing fails them.
[ "$DIG_RC" -eq 0 ] && [ -n "$DIG_OUT" ] || DIG_OUT=""
if [ -z "$DIG_OUT" ]; then
  bad "READER ARMS SKIPPED: --digest gave no digest, so no attestation line can be built"
else
  VLOG="$WORK/verify-logs"
  mkdir -p "$VLOG" || exit 2
  V_OK="H2_ATTESTED v1 sprint=311 digest=${DIG_OUT} at=2026-01-01T00:00:00Z items=1,2,3 mechanical=check-17-bypass:PASS"
  V_BAD="H2_ATTESTED v1 sprint=311 digest=0000000000000000 at=2026-01-01T00:00:00Z items=1,2,3 mechanical=check-17-bypass:PASS"
  V_OTHER="H2_ATTESTED v1 sprint=310 digest=${DIG_OUT} at=2026-01-01T00:00:00Z items=1,2,3 mechanical=check-17-bypass:PASS"
  TBL='| Check | Layer | Verdict | Evidence |
|---|---|---|---|'

  # The consumer's exact shape, verbatim: the line inside the H2 row's Evidence cell,
  # backtick-wrapped, with the row's trailing period and pipe after it.
  printf '%s\n| H2 | core | PASS | \140%s\140. |\n' "$TBL" "$V_OK"    > "$VLOG/cell.md"
  printf '%s\n| H2 | core | PASS | \140%s\140. |\n' "$TBL" "$V_BAD"   > "$VLOG/cell-stale.md"
  printf '%s\n| H2 | core | PASS | \140X%s\140. |\n' "$TBL" "$V_OK"   > "$VLOG/cell-xprefix.md"
  printf '%s\n| H2 | core | PASS | \140NOT_%s\140. |\n' "$TBL" "$V_OK" > "$VLOG/cell-notprefix.md"
  printf '## Gate 1\n%s\n' "$V_OK"                                    > "$VLOG/col1.md"
  printf '## Gate 1\nSprint 310 attested as \140%s\140.\n' "$V_OTHER" > "$VLOG/other-sprint.md"
  # A real table row whose cell is followed by a further numeric column. Anchoring the
  # tail on END OF LINE rather than on the cell delimiter refuses this, and it is not a
  # hypothetical: it is the only record sprint 309's second digest has.
  printf '%s\n| H2 | core | PASSED | \140%s\140. | 1033 |\n' "$TBL" "$V_OK" > "$VLOG/cell-numcol.md"
  # THE FORGERY SEEDS. Same sprint, same digest, inside a sentence REPORTING A FAILURE.
  # This is the consumer's own committed finding, and under a lead-only boundary it exits
  # 0 — a sentence saying the gate FAILED manufacturing an attestation nobody drove.
  printf '2. **H2 citation is not machine-verifiable across gates**, because the \140%s\140 line from the requirements gate was embedded in a table cell rather than at column 1. THIS GATE FAILED -- re-drive required.\n' \
    "$V_OK" > "$VLOG/prose-failure.md"
  # Its column-1 twin: the emitted line at the start of a line, then prose. The `^` anchor
  # accepts this, so the tail guard is the ONLY thing that can refuse it.
  printf '%s but this gate FAILED and the attestation was never driven.\n' "$V_OK" > "$VLOG/col1-then-prose.md"

  # The seeds must actually DIFFER, or the comparisons below read as agreement.
  cmp -s "$VLOG/cell.md" "$VLOG/cell-stale.md" && {
    echo "FIXTURE ERROR: the live and stale seeds are byte-identical" >&2; exit 2; }
  cmp -s "$VLOG/cell.md" "$VLOG/col1.md" && {
    echo "FIXTURE ERROR: the cell and column-1 seeds are byte-identical" >&2; exit 2; }

  v_run() {  # v_run <seed> -> sets V_RC, V_OUT
    V_OUT="$( cd "$WORK" && bash "$SUT" --verify --sprint 311 --gate-log "$VLOG/$1.md" 2>&1 )"
    V_RC=$?
  }

  # E. the motivating case: a table-cell attestation VERIFIES.
  v_run cell
  if [ "$V_RC" -eq 0 ] && grep -q 'PASS  H2 attested for sprint 311' <<<"$V_OUT"; then
    ok "--verify accepts the attestation inside a markdown table cell"
  else
    bad "--verify REJECTED a table-cell attestation (rc=$V_RC) — the consumer's case"
    printf '%s\n' "$V_OUT" | head -3 | sed 's/^/        /'
  fi

  # F. the line-start form must keep working — a widening that breaks column 1 is a
  # regression, and E alone cannot see it.
  v_run col1
  if [ "$V_RC" -eq 0 ] && grep -q 'PASS  H2 attested for sprint 311' <<<"$V_OUT"; then
    ok "--verify still accepts the canonical column-1 attestation"
  else
    bad "--verify REJECTED a column-1 attestation (rc=$V_RC) — the canonical form regressed"
    printf '%s\n' "$V_OUT" | head -3 | sed 's/^/        /'
  fi

  # G. THE ARM THAT KILLS THE HALF-WIDENED FIX. A table-cell attestation at a MOVED
  # digest must reach the "fixture set CHANGED" branch. Asserting only rc=1 here would
  # pass against the first-gate message, which is the wrong diagnostic and the one the
  # consumer actually got.
  v_run cell-stale
  if [ "$V_RC" -eq 1 ] && grep -q 'the fixture set CHANGED' <<<"$V_OUT"; then
    ok "--verify reports CHANGED for a table-cell attestation at a moved digest"
  elif [ "$V_RC" -eq 1 ]; then
    bad "--verify refused the stale table cell with the WRONG message (the CHANGED arm"
    echo "        is still anchored at line start, so only the digest arm was widened)" >&2
    printf '%s\n' "$V_OUT" | head -2 | sed 's/^/        /'
  else
    bad "--verify ACCEPTED a table-cell attestation at a moved digest (rc=$V_RC)"
  fi

  # H. absent: the first-gate branch, so G's message assertion is discriminating.
  v_run other-sprint
  if [ "$V_RC" -eq 1 ] && grep -q "this is the sprint's first gate" <<<"$V_OUT"; then
    ok "--verify reports first-gate when only ANOTHER sprint's line is present"
  else
    bad "--verify did not report first-gate for sprint 311 (rc=$V_RC) — a prose mention"
    echo "        of sprint 310's line must not attest sprint 311." >&2
    printf '%s\n' "$V_OUT" | head -2 | sed 's/^/        /'
  fi

  # I + J. the LEADING acquittal: a token boundary, not a bare substring.
  for seed in cell-xprefix cell-notprefix; do
    v_run "$seed"
    if [ "$V_RC" -eq 1 ]; then
      ok "--verify refuses ${seed#cell-} (the match is token-bounded, not a substring)"
    else
      bad "--verify ACCEPTED ${seed#cell-} (rc=$V_RC) — the anchor was dropped outright,"
      echo "        so a line that DENIES an attestation grants one." >&2
    fi
  done

  # L + M. THE TRAILING ACQUITTAL, and it is the half that makes a widened reader WORSE
  # than the anchored one. A gate log's own narrative QUOTES the line it complains about,
  # at the same sprint and the same digest. Both seeds must reach the FIRST-GATE message,
  # not merely exit 1: routing prose to the CHANGED branch still tells an operator the
  # sprint attested and the fixtures moved, when neither happened.
  for seed in prose-failure col1-then-prose; do
    v_run "$seed"
    if [ "$V_RC" -eq 1 ] && grep -q "this is the sprint's first gate" <<<"$V_OUT"; then
      ok "--verify refuses $seed (a span followed by WORDS is prose, not an attestation)"
    elif [ "$V_RC" -eq 1 ]; then
      bad "--verify refused $seed with the WRONG message — prose reached the CHANGED arm,"
      echo "        so only the accepting arm carries the tail guard." >&2
      printf '%s\n' "$V_OUT" | head -2 | sed 's/^/        /'
    else
      bad "--verify ACCEPTED $seed (rc=$V_RC) — a sentence reporting that THIS GATE FAILED"
      echo "        manufactured an attestation nobody drove." >&2
    fi
  done

  # N. and the acquittal must not reach the arm's own subject: a legitimate cell followed
  # by a FURTHER table column still verifies. Without this, the tail guard could be
  # anchored on end of line and the fixture would read identically.
  v_run cell-numcol
  if [ "$V_RC" -eq 0 ]; then
    ok "--verify accepts a cell followed by another table column (tail is cell-bounded)"
  else
    bad "--verify REJECTED a cell followed by a further column (rc=$V_RC) — the tail guard"
    echo "        is anchored on end of line, which moves the defect one column right." >&2
  fi

  # O. THE CITATION IS THE SPAN, NOT THE ROW. --verify's second line is copy text an
  # operator pastes into the next gate log; once the reader admits a table cell the
  # matching LINE is the whole markdown row. Asserted as a VALUE, not a length: the
  # citation must be byte-identical whichever placement the attestation was written in.
  v_run col1; C1="$(printf '%s\n' "$V_OUT" | sed -n '2p')"
  v_run cell; CC="$(printf '%s\n' "$V_OUT" | sed -n '2p')"
  if [ -n "$C1" ] && [ "$C1" = "$CC" ] && [ "$C1" = "$V_OK" ]; then
    ok "--verify cites the token span itself, identically from column 1 and from a cell"
  else
    bad "--verify's citation is not the emitted span (column 1 vs cell differ, or carry"
    echo "        the surrounding row). col1=${#C1} bytes, cell=${#CC} bytes, span=${#V_OK}." >&2
  fi

  # K. MUTATION: the two most plausible WRONG fixes, built as copies.
  #   (a) anchor dropped outright -> XH2_ATTESTED and NOT_H2_ATTESTED verify (I/J die)
  #   (b) only the digest arm widened -> a stale cell never reaches CHANGED (G dies)
  # Both are guarded by cmp -s, and each is required to fail the arm it OWNS while the
  # motivating case E still passes — a mutant that breaks everything proves nothing about
  # which arm is load-bearing.
  MA="$WORK/h2-lead-bare.mutant.sh"
  sed "s@^ATTEST_LEAD=.*@ATTEST_LEAD=''@" "$SUT" > "$MA"
  MB="$WORK/h2-lead-half.mutant.sh"
  sed 's@^  if grep -qE "${ATTEST_LEAD}${ATTEST_ANY}${ATTEST_TAIL}" @  if grep -qE "^H2_ATTESTED v1 sprint=${SPRINT} " @' "$SUT" > "$MB"
  # (c) THE TAIL GUARD REMOVED — a widening with no trailing bound, which is the shape
  # that grants an attestation to a sentence reporting the gate FAILED. Arms L/M own it.
  MC="$WORK/h2-tail-open.mutant.sh"
  sed "s@^ATTEST_TAIL=.*@ATTEST_TAIL=''@" "$SUT" > "$MC"

  mut_verify() {  # mut_verify <mutant> <seed> -> echoes "<rc> <first line>"
    local o r
    o="$( cd "$WORK" && bash "$1" --verify --sprint 311 --gate-log "$VLOG/$2.md" 2>&1 )"
    r=$?
    printf '%s\n' "$r|$(printf '%s\n' "$o" | head -1)"
  }

  if cmp -s "$SUT" "$MA"; then
    bad "MUTATION (a) matched nothing — ATTEST_LEAD was renamed or the grammar re-inlined"
    echo "        Nothing about the token boundary is being tested. Re-anchor the sed." >&2
  else
    ma_x="$(mut_verify "$MA" cell-xprefix)"; ma_e="$(mut_verify "$MA" cell)"
    if [ "${ma_x%%|*}" = "0" ] && [ "${ma_e%%|*}" = "0" ]; then
      ok "MUTATION (a): dropping the anchor accepts XH2_ATTESTED — arms I/J own that kill"
    elif [ "${ma_e%%|*}" != "0" ]; then
      bad "MUTATION (a) broke the motivating case too — it is not the fix it models"
      echo "        cell=${ma_e}" >&2
    else
      bad "MUTATION (a) SURVIVED: the bare-substring grammar refused XH2_ATTESTED anyway,"
      echo "        so arms I/J are not what makes the shipped anchor load-bearing." >&2
      echo "        xprefix=${ma_x}" >&2
    fi
  fi

  if cmp -s "$SUT" "$MB"; then
    bad "MUTATION (b) matched nothing — the CHANGED branch was renamed or reshaped"
    echo "        The half-widened fix is not being tested. Re-anchor the sed." >&2
  else
    mb_g="$(mut_verify "$MB" cell-stale)"; mb_e="$(mut_verify "$MB" cell)"
    if [ "${mb_e%%|*}" = "0" ] && [ "${mb_g%%|*}" = "1" ] \
       && ! grep -q 'the fixture set CHANGED' <<<"${mb_g#*|}"; then
      ok "MUTATION (b): widening only the digest arm loses CHANGED — arm G owns that kill"
    elif [ "${mb_e%%|*}" != "0" ]; then
      bad "MUTATION (b) broke the motivating case too — it is not the fix it models"
      echo "        cell=${mb_e}" >&2
    else
      bad "MUTATION (b) SURVIVED: a stale table cell still reported CHANGED with only the"
      echo "        digest arm widened, so arm G is not keyed on what separates the two." >&2
      echo "        stale=${mb_g}" >&2
    fi
  fi

  if cmp -s "$SUT" "$MC"; then
    bad "MUTATION (c) matched nothing — ATTEST_TAIL was renamed or folded into the pattern"
    echo "        The trailing bound is not being tested. Re-anchor the sed." >&2
  else
    mc_p="$(mut_verify "$MC" prose-failure)"; mc_e="$(mut_verify "$MC" cell)"
    if [ "${mc_p%%|*}" = "0" ] && [ "${mc_e%%|*}" = "0" ]; then
      ok "MUTATION (c): an unbounded tail attests a FAILURE sentence — arms L/M own that kill"
    elif [ "${mc_e%%|*}" != "0" ]; then
      bad "MUTATION (c) broke the motivating case too — it is not the fix it models"
      echo "        cell=${mc_e}" >&2
    else
      bad "MUTATION (c) SURVIVED: removing the trailing bound did NOT attest the consumer's"
      echo "        own failure sentence, so arms L/M are not what refuses prose." >&2
      echo "        prose=${mc_p}" >&2
    fi
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "h2-attest-scripts-dir: PASS"
  echo "  --attest drives its fixture from an installed consumer layout; a wrong explicit"
  echo "  --scripts is fatal; the pre-relocation derivation is one. --verify admits a"
  echo "  transcribed line in a table cell and at column 1, refuses a non-token prefix,"
  echo "  and reaches the CHANGED branch from either placement."
  exit 0
fi
echo "h2-attest-scripts-dir: FAIL ($fails assertion(s))" >&2
exit 1
