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
# A2. THE PLACEMENT SENTENCE --attest prints above the line. It is the writer half of the
# contract --verify's locating branch enforces: a lead transcribes where this says, so a
# reverted or reworded instruction reopens the bullet-with-prose shape the reader refuses.
# Keyed on the two clauses that carry the rule, never on the wrap.
if grep -qF 'on its own line at column 1, with nothing' <<<"$ATT_OUT" \
   && grep -qF 'Any prose AFTER the line makes it unverifiable' <<<"$ATT_OUT"; then
  ok "--attest tells the lead to append the line alone at column 1, and why"
else
  bad "--attest no longer prints the column-1 placement rule above the H2_ATTESTED line"
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

  # vx <script> <seed> <sprint> -> X_RC, X_OUT (stdout), X_ERR (stderr), kept apart
  # because the located diagnostic goes to stderr and "no PASS" is a claim about stdout.
  # Every predicate below takes the SCRIPT as its argument, so the same predicate is the
  # arm against the subject and the kill test against each mutant further down.
  vx() {
    ( cd "$WORK" && bash "$1" --verify --sprint "$3" --gate-log "$VLOG/$2.md" ) \
      >"$WORK/vx.out" 2>"$WORK/vx.err"
    X_RC=$?
    X_OUT="$(cat "$WORK/vx.out")"; X_ERR="$(cat "$WORK/vx.err")"
  }
  located() { grep -qF "$VLOG/$1.md:$2 QUOTES" <<<"$X_ERR"; }  # located <seed> <line>
  vx_show() { printf '%s\n%s\n' "$X_OUT" "$X_ERR" | head -3 | sed 's/^/        /' >&2; }

  # L + M. THE TRAILING ACQUITTAL, and it is the half that makes a widened reader WORSE
  # than the anchored one. A gate log's own narrative QUOTES the line it complains about,
  # at the same sprint and the same digest. Both seeds must be refused WITHOUT a PASS and
  # WITHOUT the CHANGED message — routing prose to CHANGED still tells an operator the
  # sprint attested and the fixtures moved, when neither happened — and must be LOCATED:
  # the span is there, so "this is the sprint's first gate" is the wrong diagnostic too.
  p_lm() {  # p_lm <script> <seed>
    vx "$1" "$2" 311
    [ "$X_RC" -eq 1 ] && ! grep -q 'PASS' <<<"$X_OUT" \
      && ! grep -q 'CHANGED' <<<"$X_OUT$X_ERR" && located "$2" 1
  }
  for seed in prose-failure col1-then-prose; do
    if p_lm "$SUT" "$seed"; then
      ok "--verify refuses $seed and LOCATES it (a span followed by WORDS is prose)"
    else
      bad "--verify on $seed (rc=$X_RC): wanted rc 1, no PASS, no CHANGED, and"
      echo "        '$seed.md:1 QUOTES' on stderr." >&2
      vx_show
    fi
  done

  # P-V. THE CONSUMER'S BULLET. Line 89 of the consumer's gate log (graph, ref
  # ai-dlc/carry-over/telv3-upgrade, _bmad-output/implementation-artifacts/gate-log.md),
  # byte for byte except the digest, which is this tree's so the span is LIVE. The reader
  # refuses it by design — every tail that admits it also admits FAIL sentences of the
  # same shape (the six seeds below) — so what these arms pin is the DIAGNOSTIC: refused,
  # located at <log>:<line>, never "first gate" (the span is there) and never CHANGED.
  # The bullet sits on line 2, never line 1, so a hardcoded or off-by-one number fails.
  B_FMT='- [core] H2 — Harness self-test: **PASS**. \140validate-h2-attestation.sh --attest --sprint 314\140 → \140H2_ATTESTED v1 sprint=314 digest=%s at=2026-09-26T21:11:09Z items=1,2,3 mechanical=check-17-bypass:PASS\140; item 1 recursion guard fires (H1_DEPTH=1 → immediate PASS, no re-enumeration); item 3 manifest-bypass seed correctly FAILs (missing implementation anchors).\n'
  B_LIVE="$(printf -- "$B_FMT" "$DIG_OUT")"
  B_MOVED="$(printf -- "$B_FMT" 0000000000000000)"
  C314="H2_ATTESTED v1 sprint=314 digest=${DIG_OUT} at=2026-09-27T02:06:52Z items=1,2,3 mechanical=check-17-bypass:PASS"
  printf '# gate log\n%s\n' "$B_LIVE"  > "$VLOG/bullet-live.md"
  printf '# gate log\n%s\n' "$B_MOVED" > "$VLOG/bullet-moved.md"
  printf '## Gate 1\nno attestation here\n' > "$VLOG/empty-log.md"
  # Both placements in one log: the bullet on line 3, the canonical line on line 5. The
  # ACCEPTING arm must win — a diagnostic branch hoisted above it would refuse this log.
  printf '## Gate 1\nnotes\n%s\nmore notes\n%s\n' "$B_LIVE" "$C314" > "$VLOG/bullet-then-col1.md"
  # Two quoted bullets, lines 2 and 4: the message names the LAST (4), not the first.
  printf '## Gate 1\n%s\n## Gate 2\n%s\n' "$B_LIVE" "$B_LIVE" > "$VLOG/two-bullets.md"
  cmp -s "$VLOG/bullet-live.md" "$VLOG/bullet-moved.md" && {
    echo "FIXTURE ERROR: the live and moved bullet seeds are byte-identical" >&2; exit 2; }

  p_bullet_live() {
    vx "$1" bullet-live 314
    [ "$X_RC" -eq 1 ] && located bullet-live 2 && ! grep -q 'PASS' <<<"$X_OUT"
  }
  p_bullet_moved() {
    vx "$1" bullet-moved 314
    [ "$X_RC" -eq 1 ] && located bullet-moved 2 \
      && ! grep -q 'first gate' <<<"$X_OUT$X_ERR" && ! grep -q 'CHANGED' <<<"$X_OUT$X_ERR"
  }
  p_empty() { vx "$1" empty-log 314; [ "$X_RC" -eq 1 ] && grep -q "this is the sprint's first gate" <<<"$X_OUT"; }
  p_order() { vx "$1" bullet-then-col1 314; [ "$X_RC" -eq 0 ] && grep -q 'PASS  H2 attested for sprint 314' <<<"$X_OUT"; }
  p_two()   { vx "$1" two-bullets 314; [ "$X_RC" -eq 1 ] && located two-bullets 4 && ! located two-bullets 2; }

  if p_bullet_live "$SUT"; then
    ok "--verify refuses the consumer's bullet at the live digest and names bullet-live.md:2"
  else
    bad "--verify on the consumer's live bullet (rc=$X_RC): wanted rc 1, no PASS on stdout,"
    echo "        and 'bullet-live.md:2 QUOTES' on stderr." >&2; vx_show
  fi
  if p_bullet_moved "$SUT"; then
    ok "--verify LOCATES the bullet at a moved digest (not first-gate, not CHANGED)"
  else
    bad "--verify on the moved-digest bullet (rc=$X_RC): wanted rc 1 and 'bullet-moved.md:2"
    echo "        QUOTES', with neither 'first gate' nor 'CHANGED'." >&2; vx_show
  fi
  if p_empty "$SUT"; then
    ok "--verify still reports first-gate for a log with no line for the sprint"
  else
    bad "--verify on a log with no attestation (rc=$X_RC) lost the first-gate message"; vx_show
  fi
  if p_order "$SUT"; then
    ok "--verify ACCEPTS a log with a bullet on line 3 and the column-1 line on line 5"
  else
    bad "--verify refused a log that carries a column-1 attestation (rc=$X_RC) — the"
    echo "        diagnostic branch pre-empted the accepting arm." >&2; vx_show
  fi
  if p_two "$SUT"; then
    ok "--verify names the LAST quoted line (two-bullets.md:4, not :2)"
  else
    bad "--verify on two quoted bullets (rc=$X_RC) did not name line 4 alone"; vx_show
  fi
  # THE REMEDY. A located refusal that does not say what to do sends the lead back to the
  # same bullet; the arm demands the instruction, not just the line number.
  p_remedy() {
    vx "$1" bullet-live 314
    located bullet-live 2 && grep -qF 'OWN line at column 1, nothing before or after it.' <<<"$X_ERR"
  }
  if p_remedy "$SUT"; then
    ok "--verify's located refusal carries the remedy: re-drive, append alone at column 1"
  else
    bad "--verify located the bullet but gave no column-1 remedy"; vx_show
  fi

  # W. THE SIX ADVERSARIAL FAIL LINES. Each quotes a live span at the right sprint and
  # digest inside a sentence that reports a FAILURE. Every widening that admits the
  # bullet above admits some of these; the reader must grant none of them.
  ADV_SPAN="$C314"
  printf '2. **H2 citation is not machine-verifiable across gates**, because the \140%s\140 line from the requirements gate was embedded in a table cell. THIS GATE FAILED -- re-drive required.\n' "$ADV_SPAN" > "$VLOG/adv-311-sentence.md"
  printf 'Do not cite \140%s\140; it was pasted before item 3 was judged.\n' "$ADV_SPAN" > "$VLOG/adv-do-not-cite.md"
  printf -- '- [core] H2 — **FAIL**: \140%s\140 — item 1 recursion guard did NOT fire.\n' "$ADV_SPAN" > "$VLOG/adv-emdash-fail.md"
  printf -- '- [core] H2 — Harness self-test: **FAIL**. \140validate-h2-attestation.sh --attest --sprint 314\140 → \140%s\140; item 3 manifest-bypass seed PASSED H1 (H1 blind to the slice) — H2 FAILS, do not cite.\n' "$ADV_SPAN" > "$VLOG/adv-item3-fail-bullet.md"
  printf -- '- [core] H2: \140NOT_%s\140; re-drive.\n' "$ADV_SPAN" > "$VLOG/adv-notprefix-bullet.md"
  printf -- '- [core] H2 — Harness self-test: **PASS** claimed at requirements as \140%s\140; retracted: item 3 re-judged FAIL.\n' "$ADV_SPAN" > "$VLOG/adv-pass-then-retract.md"
  ADV_SEEDS="adv-311-sentence adv-do-not-cite adv-emdash-fail adv-item3-fail-bullet adv-notprefix-bullet adv-pass-then-retract"
  p_adv() { vx "$1" "$2" 314; [ "$X_RC" -eq 1 ] && ! grep -q 'PASS' <<<"$X_OUT"; }
  for seed in $ADV_SEEDS; do
    [ -s "$VLOG/$seed.md" ] || { echo "FIXTURE ERROR: adversarial seed $seed is empty" >&2; exit 2; }
    if p_adv "$SUT" "$seed"; then
      ok "--verify grants nothing to $seed"
    else
      bad "--verify GRANTED $seed (rc=$X_RC) — a FAIL sentence produced an attestation"; vx_show
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

  # P. PLACEMENT AND VERDICT. The span must stand ALONE on its line or ALONE in its cell,
  # with decoration from a CLOSED set on each side, and a table row must sit under a header
  # whose Result/Verdict/Status/Outcome column reads PASS. Every refusal below is asserted
  # LOCATED at its exact <log>:<line>, never first-gate and never CHANGED, because the span
  # IS there: the wrong message tells an operator the sprint never attested or that the
  # fixtures moved. Seeds are the shapes a lead actually transcribes, and the five rb-bl*
  # lines are the defect report's own, verbatim except for the live digest.
  BT="$(printf '\140')"
  V_LATER="H2_ATTESTED v1 sprint=311 digest=${DIG_OUT} at=2026-02-02T00:00:00Z items=1,2,3 mechanical=check-17-bypass:PASS"
  HR='| Check | Result | Evidence |
|---|---|---|'
  sd() { printf '%s\n' "$2" > "$VLOG/$1.md" || exit 2; }
  # must verify
  sd vb-col1       "$V_OK"
  sd vb-bullet     "- ${BT}${V_OK}${BT}"
  sd vb-hdr-pass   "$HR
| H2 | PASS | ${BT}${V_OK}${BT} |"
  sd vb-hdr-numcol "| Check | Result | Evidence | n |
|---|---|---|---|
| H2 | PASS | ${BT}${V_OK}${BT} | 1033 |"
  sd vb-hdr-dnrd   "$HR
| H2 | **PASS (attested, cite — do not re-drive)** | ${BT}${V_OK}${BT} |"
  sd vb-core-label "| Check | Verdict | Evidence | Note |
|---|---|---|---|
| [core] H2_ATTESTED | PASS | ${BT}${V_OK}${BT} | — |"
  VB_SEEDS="vb-col1 vb-bullet vb-hdr-pass vb-hdr-numcol vb-hdr-dnrd vb-core-label"
  # must refuse: <seed>|<line>|<reason substring or empty>
  sd rb-bl1   "| H2 | core | FAIL | refused, re-drive owed: ${BT}${V_OK}${BT} |"
  sd rb-bl2   "| H2 | core | ${BT}${V_OK}${BT} | FAIL — item 3 seed passed H1 |"
  sd rb-bl3   "| Check | Evidence |
|---|---|
| H2 (INVALID, do not cite) | ${BT}${V_OK}${BT} |"
  sd rb-bl4   "| H2 | core | FAIL -- re-drive required | ${BT}${V_OK}${BT} |"
  sd rb-bl5   "H2 FAILED, re-drive owed: $V_OK"
  # The same rows UNDER a header, so the placement and verdict rules are what refuse them
  # rather than the missing header alone.
  sd rb-bl1h  "$TBL
| H2 | core | FAIL | refused, re-drive owed: ${BT}${V_OK}${BT} |"
  sd rb-bl2h  "$TBL
| H2 | core | ${BT}${V_OK}${BT} | FAIL — item 3 seed passed H1 |"
  sd rb-bl4h  "$TBL
| H2 | core | FAIL -- re-drive required | ${BT}${V_OK}${BT} |"
  # A PASS row whose evidence cell carries prose BEFORE the span: only the cell lead refuses it.
  sd rb-cell-prose "$TBL
| H2 | core | PASS | refused, re-drive owed: ${BT}${V_OK}${BT} |"
  sd rb-cross    "❌ ${BT}${V_OK}${BT}"
  sd rb-strike   "~~${V_OK}~~"
  sd rb-comment  "<!-- ${V_OK} -->"
  sd rb-quote    "> ${V_OK}"
  sd rb-voided   "$HR
| H2 | VOIDED | ${BT}${V_OK}${BT} |"
  sd rb-emdash   "$HR
| H2 | — | ${BT}${V_OK}${BT} |"
  sd rb-headerless "| H2 | PASS | ${BT}${V_OK}${BT} |"
  sd rb-noverdict "| Check | Owner | Evidence |
|---|---|---|
| H2 | core | ${BT}${V_OK}${BT} |"
  sd rb-fail-hdr  "$HR
| H2 | FAIL | ${BT}${V_OK}${BT} |"
  sd rb-fail-moved "$HR
| H2 | FAIL | ${BT}${V_BAD}${BT} |"
  # The emitted line with the MECHANICAL item recording a failure, at column 1. --attest only
  # ever prints `mechanical=check-17-bypass:PASS`; an open value class granted this line.
  sd rb-mech-fail "${V_OK%:PASS}:FAIL"
  [ "${V_OK%:PASS}:FAIL" != "$V_OK" ] || { echo "FIXTURE ERROR: the :FAIL seed equals V_OK" >&2; exit 2; }
  # THE TWO CELL READINGS. A pipe inside a backtick code span is part of the cell under the
  # code-span reading and a cell border under the GFM reading, which is how GitHub renders
  # the row; a table row verifies only when BOTH accept it. Each seed below is accepted by
  # exactly one reading, so it separates the two:
  #   (i)   code-span hole: `| PASS` inside a code span. Split on every pipe, the Result
  #         column reads PASS; read as code, it reads FAIL. Refused by the code-span reading.
  #   (ii)  GFM mirror: `a| FAIL |b` inside a code span before a PASS cell. Read as code, the
  #         Result column reads PASS; GitHub renders FAIL there. Refused by the GFM reading,
  #         and the message must say so.
  #   (iii) a genuine PASS row carrying `a|b` in its label cell: the pipe shifts every later
  #         cell under the GFM reading, so it is refused BY DESIGN — a false refusal costs one
  #         re-drive, a false grant attests a check nobody drove.
  sd rb-cs-hole "$HR
| H2 ${BT}| PASS${BT} | FAIL | ${BT}${V_OK}${BT} |"
  sd rb-gfm-mirror "| Check | Note | Result | Evidence |
|---|---|---|---|
| H2 | ${BT}a| FAIL |b${BT} | PASS | ${BT}${V_OK}${BT} |"
  sd rb-pipe-in-code "$HR
| H2 ${BT}a|b${BT} | PASS | ${BT}${V_OK}${BT} |"
  RB_ROWS="rb-cs-hole|3|does not begin PASS
rb-gfm-mirror|3|(reading every pipe as a cell border
rb-pipe-in-code|3|(reading every pipe as a cell border
rb-bl1|1|
rb-bl2|1|
rb-bl3|3|
rb-bl4|1|
rb-bl5|1|inside other text
rb-bl1h|3|inside other text
rb-bl2h|3|does not begin PASS
rb-bl4h|3|does not begin PASS
rb-cell-prose|3|inside other text
rb-cross|1|inside other text
rb-strike|1|inside other text
rb-comment|1|inside other text
rb-quote|1|inside other text
rb-voided|3|does not begin PASS
rb-emdash|3|does not begin PASS
rb-headerless|1|no header row
rb-noverdict|3|names no Result, Verdict, Status or Outcome
rb-fail-hdr|3|does not begin PASS
rb-fail-moved|3|does not begin PASS
rb-mech-fail|1|inside other text"
  # controls on the other two messages, so the refusal arms' "never CHANGED, never first
  # gate" conjuncts are shown to be able to fire
  sd cb-moved-pass "$HR
| H2 | PASS | ${BT}${V_BAD}${BT} |"
  sd cb-none "## Gate 1
no attestation here"
  # THE CITATION'S SOURCE LINE: an accepted column-1 span, then a REFUSED span at a different
  # at=. The citation must be the accepted one, never the last span in the log.
  sd cb-cite-last "## Gate 1
${V_OK}
- H2 re-driven: ${BT}${V_LATER}${BT} — FAIL, do not cite."
  # A seventh FAIL line, and the only one the closed LEAD admits: the span opens the line in
  # backticks and the failure follows the closing backtick. The six above are refused by the
  # lead before the tail is read, so without this seed no adversarial arm can see the tail.
  printf '\140%s\140 — item 3 manifest-bypass seed PASSED H1, H2 FAILED, do not cite.\n' "$C314" \
    > "$VLOG/adv-col1-bt-fail.md" || exit 2
  ADV_SEEDS="$ADV_SEEDS adv-col1-bt-fail"
  if p_adv "$SUT" adv-col1-bt-fail; then ok "--verify grants nothing to adv-col1-bt-fail"
  else bad "--verify GRANTED adv-col1-bt-fail (rc=$X_RC) — prose after the closing backtick"; vx_show; fi
  cmp -s "$VLOG/cb-moved-pass.md" "$VLOG/vb-hdr-pass.md" && {
    echo "FIXTURE ERROR: the live and moved PASS-row seeds are byte-identical" >&2; exit 2; }
  [ "$V_OK" != "$V_LATER" ] || { echo "FIXTURE ERROR: the citation seeds do not differ" >&2; exit 2; }

  p_verify() { vx "$1" "$2" 311; [ "$X_RC" -eq 0 ] && grep -q '^PASS  H2 attested for sprint 311' <<<"$X_OUT"; }
  p_refuse() {  # p_refuse <script> <seed> <line> [<reason>]
    vx "$1" "$2" 311
    [ "$X_RC" -eq 1 ] && ! grep -q '^PASS' <<<"$X_OUT" \
      && ! grep -q 'CHANGED' <<<"$X_OUT$X_ERR" && ! grep -q 'first gate' <<<"$X_OUT$X_ERR" \
      && located "$2" "$3" && { [ -z "${4:-}" ] || grep -qF -- "$4" <<<"$X_ERR"; }
  }
  p_changed() { vx "$1" "$2" 311; [ "$X_RC" -eq 1 ] && grep -q 'the fixture set CHANGED' <<<"$X_ERR"; }
  p_first()   { vx "$1" "$2" 311; [ "$X_RC" -eq 1 ] && grep -q "this is the sprint's first gate" <<<"$X_OUT"; }
  p_cite() {
    vx "$1" cb-cite-last 311
    [ "$X_RC" -eq 0 ] && [ "$(printf '%s\n' "$X_OUT" | sed -n '2p')" = "$V_OK" ]
  }
  p_all_vb() { local s; for s in $VB_SEEDS; do p_verify "$1" "$s" || return 1; done; }
  p_all_rb() {
    local row s l r
    while IFS='|' read -r s l r; do
      [ -n "$s" ] || continue
      p_refuse "$1" "$s" "$l" "$r" || return 1
    done <<<"$RB_ROWS"
  }

  for s in $VB_SEEDS; do
    if p_verify "$SUT" "$s"; then ok "--verify accepts $s"
    else bad "--verify REFUSED $s (rc=$X_RC) — an accepted placement regressed"; vx_show; fi
  done
  n_rb=0
  while IFS='|' read -r s l r; do
    [ -n "$s" ] || continue
    n_rb=$((n_rb + 1))
    if p_refuse "$SUT" "$s" "$l" "$r"; then ok "--verify refuses $s and LOCATES it at :$l${r:+ ($r)}"
    else
      bad "--verify on $s (rc=$X_RC): wanted rc 1, no PASS, no CHANGED, no first-gate,"
      echo "        '$s.md:$l QUOTES' on stderr${r:+ and the reason '$r'}." >&2; vx_show
    fi
  done <<<"$RB_ROWS"
  [ "$n_rb" -ge 23 ] || bad "only $n_rb refusal rows were driven — the RB_ROWS list was truncated"
  if p_changed "$SUT" cb-moved-pass; then ok "CONTROL: a PASS row at a moved digest reports CHANGED"
  else bad "CONTROL: a PASS row at a moved digest did not report CHANGED (rc=$X_RC)"; vx_show; fi
  if p_first "$SUT" cb-none; then ok "CONTROL: a log with no span reports first-gate"
  else bad "CONTROL: a log with no span did not report first-gate (rc=$X_RC)"; vx_show; fi
  if p_cite "$SUT"; then ok "--verify cites the ACCEPTED span, not a later refused one"
  else
    bad "--verify's citation (rc=$X_RC) is not the accepted column-1 span; it came from"
    echo "        another line of the log." >&2; vx_show
  fi

  # K + X. THE MUTATION BATTERY. Every mutant is a COPY of the subject with named lines
  # replaced, and every replacement is keyed on ONE line of the subject: mut_sub refuses an
  # anchor matching zero lines or two, and mut_mk then requires the copy to DIFFER (cmp -s)
  # and to PARSE (bash -n). A mutant that fails any of the three is reported as DID NOT
  # APPLY — BROKEN, never KILLED. The awk program inside the copy is NOT checked by bash -n,
  # so every mutant must also pass a SANITY predicate — a copy whose awk does not parse
  # refuses everything and would otherwise score every refusal arm as a kill.
  #
  # Anchor and replacement travel through FILES, never `awk -v`, which strips a level of
  # escaping; the anchor is matched against the line with leading spaces removed.
  mut_sub() {  # mut_sub <in> <out> <anchor> <replacement>
    printf '%s\n' "$3" > "$WORK/mut.anchor" || return 2
    printf '%s\n' "$4" > "$WORK/mut.repl" || return 2
    awk -v af="$WORK/mut.anchor" -v rf="$WORK/mut.repl" '
      BEGIN { if ((getline a < af) <= 0) { bad = 1; exit 3 }
              nr = 0; while ((getline l < rf) > 0) { r = r (nr ? "\n" : "") l; nr++ }
              if (nr == 0) { bad = 1; exit 3 } }
      { t = $0; sub(/^[ ]+/, "", t)
        if (index(t, a) == 1) { hit++; print r; next }
        print }
      END { if (bad) exit 3; if (hit != 1) exit 4 }' "$1" > "$2"
  }
  mut_mk() {  # mut_mk <label> <out> <anchor> <repl> [<anchor> <repl>]...
    local label="$1" out="$2" cur="$WORK/mut.cur" rc
    shift 2
    cp "$SUT" "$cur" || return 2
    while [ $# -ge 2 ]; do
      mut_sub "$cur" "$cur.next" "$1" "$2"; rc=$?
      if [ "$rc" -ne 0 ]; then
        bad "MUTATION ($label) DID NOT APPLY — anchor '$1' is not exactly ONE line of the subject (rc=$rc)"
        return 1
      fi
      mv "$cur.next" "$cur" || return 2
      shift 2
    done
    mv "$cur" "$out" || return 2
    if cmp -s "$SUT" "$out"; then
      bad "MUTATION ($label) DID NOT APPLY — the copy is byte-identical to the subject"; return 1
    fi
    if ! bash -n "$out" 2>/dev/null; then
      bad "MUTATION ($label) DID NOT APPLY — the copy does not parse (bash -n)"; return 1
    fi
    return 0
  }
  # The applied-check must itself be able to fire: an anchor on no line and an anchor on
  # many lines are both refused, and the one-line anchor every mutant below uses is taken.
  mut_sub "$SUT" "$WORK/mut.probe" 'NO_SUCH_LINE_IN_THE_SUBJECT_7q' 'x'; pr0=$?
  mut_sub "$SUT" "$WORK/mut.probe" 'fi' 'x'; prn=$?
  mut_sub "$SUT" "$WORK/mut.probe" 'else print "NONE"' 'x'; pr1=$?
  if [ "$pr0" -ne 0 ] && [ "$prn" -ne 0 ] && [ "$pr1" -eq 0 ]; then
    ok "MUTATION HARNESS: an anchor on zero lines or many is refused, one line is taken"
  else
    bad "MUTATION HARNESS: mut_sub zero=$pr0 many=$prn one=$pr1 — wanted non-zero, non-zero, 0"
  fi
  # score <label> <mutant> <owner> <what> <sanity>... — KILLED only when the owner predicate
  # FAILS on the mutant while every sanity predicate still PASSES on it.
  score() {
    local label="$1" m="$2" owner="$3" what="$4" q
    shift 4
    if "$owner" "$m"; then
      bad "MUTATION ($label) SURVIVED — $owner still passes: $what"; return
    fi
    for q in "$@"; do
      "$q" "$m" || { bad "MUTATION ($label) broke sanity predicate $q — it is not the fix it models"; return; }
    done
    ok "MUTATION ($label): $what — KILLED by $owner"
  }

  # Named predicates, one per arm a mutant is scored against, each taking only the script.
  q_col1()     { p_verify "$1" col1; }
  q_cell()     { p_verify "$1" cell; }
  q_xprefix()  { vx "$1" cell-xprefix 311; [ "$X_RC" -eq 1 ] && ! grep -q '^PASS' <<<"$X_OUT"; }
  q_g()        { p_changed "$1" cell-stale; }
  q_lm()       { p_lm "$1" col1-then-prose; }
  q_dnrd()     { p_verify "$1" vb-hdr-dnrd; }
  q_hdr_pass() { p_verify "$1" vb-hdr-pass; }
  q_cross()    { p_refuse "$1" rb-cross 1 'inside other text'; }
  q_fail_mv()  { p_refuse "$1" rb-fail-moved 3 'does not begin PASS'; }
  q_cite()     { p_cite "$1"; }
  q_adv_none() { local s; for s in $ADV_SEEDS; do p_adv "$1" "$s" || return 1; done; }
  q_cs_hole()  { p_refuse "$1" rb-cs-hole 3 'does not begin PASS'; }
  q_gfm()      { p_refuse "$1" rb-gfm-mirror 3 '(reading every pipe as a cell border'; }
  q_mech()     { p_refuse "$1" rb-mech-fail 1 'inside other text'; }

  # An UNMUTATED copy in the same place must pass every predicate first, so a harness that
  # cannot run a copy from $WORK is reported as broken rather than as a row of kills. Each
  # predicate is PRESENCE-shaped (a PASS line, a CHANGED line, a located <log>:<line>), so a
  # copy that emits nothing fails them rather than passing as clean.
  MCTL="$WORK/h2-control.copy.sh"
  cp "$SUT" "$MCTL" || exit 2
  ctl_ok=1
  for p in p_bullet_live p_bullet_moved p_empty p_order p_two p_remedy p_all_vb p_all_rb \
           q_col1 q_cell q_xprefix q_g q_lm q_cite q_adv_none; do
    "$p" "$MCTL" || { ctl_ok=0; bad "MUTATION CONTROL: the unmutated copy fails $p (rc=$X_RC) —"
      echo "        the harness cannot drive a copy from \$WORK, so no mutant verdict is evidence." >&2; }
  done
  [ "$ctl_ok" -eq 1 ] && ok "MUTATION CONTROL: an unmutated copy in \$WORK passes every scored arm"

  if [ "$ctl_ok" -eq 1 ]; then
    # (a) the token boundary dropped outright, BOTH layers: the closed lead and the locating
    #     boundary. XH2_ATTESTED then verifies; arms I/J own it.
    M="$WORK/h2-lead-bare.mutant.sh"
    mut_mk a "$M" "ATTEST_LEAD=" "ATTEST_LEAD='.*'" "ATTEST_LOCATE=" "ATTEST_LOCATE=''" \
      && score a "$M" q_xprefix "an unbounded lead grants XH2_ATTESTED" q_cell q_col1
    # (b) the CHANGED arm held to column 1 while the accepting arm reads cells: a stale cell
    #     never reaches CHANGED; arm G owns it.
    M="$WORK/h2-changed-col1.mutant.sh"
    mut_mk b "$M" 'why = judge(ANY)' \
      'why = judge(ANY); if (why == "OK" && $0 !~ ("^(" ANY ")")) why = "not at column 1"' \
      && score b "$M" q_g "a CHANGED arm anchored at column 1 loses the stale table cell" q_cell q_col1
    # (c) the trailing bound opened: a span followed by WORDS verifies; arms L/M own it.
    M="$WORK/h2-tail-open.mutant.sh"
    mut_mk c "$M" "ATTEST_TAIL=" "ATTEST_TAIL='.*'" \
      && score c "$M" q_lm "an unbounded tail attests the column-1 FAIL sentence" q_cell q_col1
    # (d) a FAILURE VOCABULARY over the sibling cells instead of the header-keyed PASS column.
    #     It refuses sprint 289's real PASS row, whose verdict reads "do not re-drive".
    M="$WORK/h2-verdict-vocab.mutant.sh"
    mut_mk d "$M" 'hn = cells(hdr, hc); vi = 0' \
      'for (i = 1; i <= n; i++) if (i != at && toupper(c[i]) ~ /FAIL|INVALID|REFUSED|RE-DRIVE|DO NOT CITE/) return "a sibling cell names a failure"; match(c[at], rx); CITE = substr(c[at], RSTART, RLENGTH); return "OK"' \
      && score d "$M" q_dnrd "a failure vocabulary refuses the do-not-re-drive PASS row" q_col1 q_hdr_pass
    # (e) a COLUMN-1-ONLY reader: every table row refused. The over-narrow fix the defect
    #     report's own receipt cannot tell from the right one; the header-table arm owns it.
    M="$WORK/h2-col1-only.mutant.sh"
    mut_mk e "$M" 'if (hdr == "") return' 'return "column 1 only"' \
      && score e "$M" q_hdr_pass "a column-1-only reader refuses the PASS table row" q_col1
    # (f) a NEGATED-CLASS lead, the old tail mirrored: any non-word glyph before the span
    #     passes, including a cross mark; the cross arm owns it.
    M="$WORK/h2-lead-negated.mutant.sh"
    mut_mk f "$M" "ATTEST_LEAD=" "ATTEST_LEAD='[^0-9A-Za-z|]*'" \
      && score f "$M" q_cross "a negated-class lead grants a cross-marked span" q_col1 q_cell
    # (g) the verdict column judged on the ACCEPTING arm only: the CHANGED arm grants any
    #     placement-clean row, so a FAIL row at a moved digest reads CHANGED.
    M="$WORK/h2-verdict-arm1-only.mutant.sh"
    mut_mk g "$M" 'why = judge(ANY)' \
      'why = judge(ANY); if (why ~ /header|does not begin PASS/) why = "OK"' \
      && score g "$M" q_fail_mv "verdict unjudged on the moved-digest arm reports CHANGED for a FAIL row" q_col1 q_g
    # (h) the citation cut from the LAST span in the log, not from the accepted placement.
    M="$WORK/h2-cite-last.mutant.sh"
    mut_mk h "$M" 'if ($0 !~ (LOC "(" ANY ")")) next' \
      'if ($0 !~ (LOC "(" ANY ")")) next; match($0, ANY); lastspan = substr($0, RSTART, RLENGTH)' \
      'if (pass) print "PASS|" cite' 'if (pass) print "PASS|" lastspan' \
      && score h "$M" q_cite "citing the last span in the log prints the refused re-drive" q_col1 q_cell

    # (i2) the splitter before code spans were read: every pipe is a border in BOTH readings,
    #      so the code-span hole reads PASS in the Result column; arm (i) owns it.
    M="$WORK/h2-cells-every-pipe.mutant.sh"
    mut_mk i2 "$M" 'if (GFM) return gfmcells(s, arr)' 'return gfmcells(s, arr)' \
      && score i2 "$M" q_cs_hole "a splitter blind to code spans grants the code-span hole" q_col1 q_hdr_pass
    # (j) only the code-span reading judged: the GFM mirror verifies; arm (ii) owns it.
    M="$WORK/h2-judge-codespan-only.mutant.sh"
    mut_mk j "$M" 'GFM = 1; b = judgeone(rx); GFM = 0' 'b = "OK"' \
      && score j "$M" q_gfm "judging only the code-span reading grants the GFM mirror" q_col1 q_hdr_pass
    # (k) only the GFM reading judged: both judgeone calls split on every pipe, so the
    #     code-span hole verifies; arm (i) owns it.
    M="$WORK/h2-judge-gfm-only.mutant.sh"
    mut_mk k "$M" 'GFM = 0; a = judgeone(rx); cite = CITE' 'GFM = 1; a = judgeone(rx); cite = CITE; GFM = 0' \
      && score k "$M" q_cs_hole "judging only the GFM reading grants the code-span hole" q_col1 q_hdr_pass
    # (l) the mechanical value class reopened: `:FAIL` satisfies the field group, so the
    #     column-1 line recording a FAILED mechanical item verifies; the :FAIL arm owns it.
    M="$WORK/h2-mechanical-open.mutant.sh"
    mut_mk l "$M" "ATTEST_FIELDS=" \
      "ATTEST_FIELDS='( at=[0-9A-Za-z:-]+)?( items=[0-9,]+)?( mechanical=[0-9A-Za-z:_.-]+)?'" \
      && score l "$M" q_mech "an open mechanical value grants the :FAIL line" q_col1 q_cell
    # (m1) locating keyed on this digest only: a moved-digest bullet falls to first-gate.
    M="$WORK/h2-locate-span.mutant.sh"
    mut_mk m1 "$M" 'locn = NR; locwhy = why' 'if ($0 ~ SPAN) { locn = NR; locwhy = why }' \
      && score m1 "$M" p_bullet_moved "a locator keyed on the live digest loses the moved bullet" p_bullet_live
    # (m2) the locating arm deleted: every refused span reads as first-gate.
    M="$WORK/h2-locate-deleted.mutant.sh"
    mut_mk m2 "$M" 'locn = NR; locwhy = why' 'why = why' \
      && score m2 "$M" p_bullet_live "with no locator the live bullet reads as first-gate" p_empty p_order
    # (m3) tail widened to backtick-then-anything: FAIL prose after a closing backtick is
    #     granted; the adversarial arms own it, through adv-col1-bt-fail, the one FAIL seed
    #     the closed lead admits.
    M="$WORK/h2-tail-backtick-any.mutant.sh"
    mut_mk m3 "$M" "ATTEST_TAIL=" "ATTEST_TAIL='(${BT}.*|${BT}?(\\*\\*)?\\.?[ ]*)'" \
      && score m3 "$M" q_adv_none "backtick-then-anything grants a FAIL sentence" p_order q_cell
    # (m4) the diagnostic HOISTED above the accepting arm: a log carrying both reads LOCATE.
    M="$WORK/h2-locate-hoisted.mutant.sh"
    mut_mk m4 "$M" 'if (pass) print "PASS|" cite' \
      'if (locn) print "LOCATE|" locn "|" locwhy; else if (pass) print "PASS|" cite' \
      && score m4 "$M" p_order "a hoisted locator refuses a log with a column-1 line" p_bullet_live
    # (m5) the diagnostic made unconditional: a log with no span is LOCATED at line 0.
    M="$WORK/h2-locate-always.mutant.sh"
    mut_mk m5 "$M" 'else print "NONE"' 'else print "LOCATE|0|always"' \
      && score m5 "$M" p_empty "an unconditional locator loses first-gate" p_bullet_live
    # (m6) the FIRST quoted line named, not the last.
    M="$WORK/h2-locate-first.mutant.sh"
    mut_mk m6 "$M" 'locn = NR; locwhy = why' 'if (!locn) { locn = NR; locwhy = why }' \
      && score m6 "$M" p_two "naming the first quoted line misses line 4" p_bullet_live
    # (m7) the REMEDY line deleted, the location kept.
    M="$WORK/h2-locate-no-remedy.mutant.sh"
    grep -vF -- '--attest and append its line on its OWN line at column 1' "$SUT" > "$M"
    if cmp -s "$SUT" "$M" || ! bash -n "$M" 2>/dev/null; then
      bad "MUTATION (m7) DID NOT APPLY — the remedy line was not found or the copy does not parse"
    else
      score m7 "$M" p_remedy "deleting the remedy line loses the column-1 instruction" p_bullet_live
    fi
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "h2-attest-scripts-dir: PASS"
  echo "  --attest drives its fixture from an installed consumer layout; a wrong explicit"
  echo "  --scripts is fatal; the pre-relocation derivation is one. --verify admits a"
  echo "  transcribed line in a table cell and at column 1, refuses a non-token prefix,"
  echo "  and reaches the CHANGED branch from either placement. A span quoted inside other"
  echo "  text — the consumer's bullet, seven FAIL sentences — grants nothing and is LOCATED,"
  echo "  and so does a table row under no header, no verdict column or a verdict not PASS."
  exit 0
fi
echo "h2-attest-scripts-dir: FAIL ($fails assertion(s))" >&2
exit 1
