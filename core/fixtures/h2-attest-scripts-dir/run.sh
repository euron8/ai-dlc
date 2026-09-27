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

  # X. MUTATION BATTERY FOR THE LOCATING BRANCH. Three wrong shapes of the third --verify
  # branch, each built as a COPY, each required to have APPLIED (differs by cmp) and to
  # PARSE (bash -n) before any verdict is read — a mutant that did neither reads as killed.
  #   (m1) diagnostic keyed on ATTEST_SPAN, not ATTEST_ANY -> a moved-digest bullet falls
  #        through to "first gate"; the moved-digest arm owns the kill.
  #   (m2) diagnostic branch deleted -> every quoted span reads as "first gate"; the live
  #        bullet arm owns the kill.
  #   (m3) tail widened to backtick-then-anything -> FAIL sentences are granted; the
  #        adversarial arms own the kill. The backtick comes from printf '\140' into a FILE
  #        that awk reads with getline: `awk -v` decodes the escape into a live backtick
  #        and the resulting mutant exits 2 on parse.
  # An UNMUTATED copy in the same place must pass every predicate first, so a harness
  # that cannot run a copy from $WORK is reported as broken rather than as five kills.
  MCTL="$WORK/h2-locate-control.copy.sh"
  cp "$SUT" "$MCTL" || exit 2
  M1="$WORK/h2-locate-span.mutant.sh"
  sed 's/\${ATTEST_LEAD}\${ATTEST_ANY}" "\$GATE_LOG"/${ATTEST_LEAD}${ATTEST_SPAN}" "$GATE_LOG"/g' "$SUT" > "$M1"
  M2="$WORK/h2-locate-deleted.mutant.sh"
  awk 'skip==0 && index($0, "if grep -qE \"${ATTEST_LEAD}${ATTEST_ANY}\" \"$GATE_LOG\"; then") == 3 { skip=1; next }
       skip==1 { if ($0 == "  fi") skip=2; next }
       { print }' "$SUT" > "$M2"
  M3="$WORK/h2-tail-backtick-any.mutant.sh"
  M3LINE="$WORK/m3-tail-line.txt"
  printf '%s\140%s\n' "ATTEST_TAIL='(" '|[^0-9A-Za-z|]*(\||$))'"'" > "$M3LINE"
  awk -v f="$M3LINE" 'BEGIN { if ((getline r < f) <= 0) exit 3 }
       /^ATTEST_TAIL=/ { print r; next } { print }' "$SUT" > "$M3"

  ctl_ok=1
  for p in p_bullet_live p_bullet_moved p_empty p_order p_two p_remedy; do
    "$p" "$MCTL" || { ctl_ok=0; bad "MUTATION CONTROL: the unmutated copy fails $p (rc=$X_RC) —"
      echo "        the harness cannot drive a copy from \$WORK, so no mutant verdict is evidence." >&2; }
  done
  for seed in $ADV_SEEDS; do
    p_adv "$MCTL" "$seed" || { ctl_ok=0; bad "MUTATION CONTROL: the unmutated copy grants $seed"; }
  done
  [ "$ctl_ok" -eq 1 ] && ok "MUTATION CONTROL: an unmutated copy in \$WORK passes every locating arm"

  mut_ready() {  # mut_ready <label> <mutant> -> 0 only if it applied AND parses
    if cmp -s "$SUT" "$2"; then
      bad "MUTATION ($1) DID NOT APPLY — its anchor matched nothing. Re-anchor it."; return 1
    fi
    if ! bash -n "$2" 2>/dev/null; then
      bad "MUTATION ($1) does not PARSE (bash -n) — it cannot score a kill."; return 1
    fi
    return 0
  }

  if [ "$ctl_ok" -eq 1 ] && mut_ready m1 "$M1"; then
    n1="$(grep -c 'ATTEST_LEAD}${ATTEST_SPAN}" "$GATE_LOG"' "$M1")" || n1=0
    if [ "$n1" -ne 2 ]; then
      bad "MUTATION (m1) rewrote $n1 site(s), not the diagnostic's 2 — it is not the shape it models"
    elif p_bullet_moved "$M1"; then
      bad "MUTATION (m1) SURVIVED: keyed on ATTEST_SPAN, the moved-digest bullet is still located"
    elif ! p_bullet_live "$M1"; then
      bad "MUTATION (m1) broke the live bullet too — the kill is not the moved-digest arm's alone"
    else
      ok "MUTATION (m1): a diagnostic keyed on ATTEST_SPAN loses the moved digest — its arm kills it"
    fi
  fi
  if [ "$ctl_ok" -eq 1 ] && mut_ready m2 "$M2"; then
    if grep -q 'QUOTES an H2_ATTESTED span' "$M2"; then
      bad "MUTATION (m2) left the located message in place — the branch was not deleted"
    elif p_bullet_live "$M2"; then
      bad "MUTATION (m2) SURVIVED: with the branch deleted the live bullet is still located"
    elif ! p_empty "$M2" || ! p_order "$M2"; then
      bad "MUTATION (m2) broke first-gate or the accepting arm — the deletion overran the branch"
    else
      ok "MUTATION (m2): deleting the locating branch fails the consumer-bullet arm"
    fi
  fi
  if [ "$ctl_ok" -eq 1 ] && mut_ready m3 "$M3"; then
    granted=0
    for seed in $ADV_SEEDS; do p_adv "$M3" "$seed" || granted=$((granted + 1)); done
    if ! grep -q '^ATTEST_TAIL=.(.|' "$M3" || ! grep -q "$(printf '\140')" "$M3"; then
      bad "MUTATION (m3) did not write a backtick alternative into ATTEST_TAIL"
    elif [ "$granted" -eq 0 ]; then
      bad "MUTATION (m3) SURVIVED: backtick-then-anything granted none of the six FAIL lines"
    elif ! p_order "$M3"; then
      bad "MUTATION (m3) broke the column-1 accept — it is not the widening it models"
    else
      ok "MUTATION (m3): backtick-then-anything grants $granted of 6 FAIL lines — the adversarial arms kill it"
    fi
  fi

  # (m4-m6) The three arms the BASE script passes too (it refuses correctly, just with the
  # wrong words), so the base run cannot show they fire. Each gets a mutant of its own:
  #   (m4) diagnostic HOISTED above the accepting arm -> the order arm dies
  #   (m5) diagnostic made unconditional              -> the empty-log arm dies
  #   (m6) FIRST quoted line named, not the last      -> the two-bullets arm dies
  DIAG_IF='  if grep -qE "${ATTEST_LEAD}${ATTEST_ANY}" "$GATE_LOG"; then'
  ACCEPT_IF='  if grep -qE "${ATTEST_LEAD}${ATTEST_SPAN}${ATTEST_TAIL}" "$GATE_LOG"; then'
  M4BLK="$WORK/m4-block.txt"
  awk -v a="$DIAG_IF" 'on==0 && $0 == a { on=1 } on==1 { print; if ($0 == "  fi") exit }' "$SUT" > "$M4BLK"
  M4="$WORK/h2-locate-hoisted.mutant.sh"
  awk -v a="$DIAG_IF" -v b="$ACCEPT_IF" -v f="$M4BLK" '
       $0 == b { while ((getline l < f) > 0) print l }
       skip==0 && $0 == a { skip=1; next }
       skip==1 { if ($0 == "  fi") skip=2; next }
       { print }' "$SUT" > "$M4"
  M5="$WORK/h2-locate-always.mutant.sh"
  awk -v a="$DIAG_IF" '$0 == a { print "  if true; then"; next } { print }' "$SUT" > "$M5"
  M6="$WORK/h2-locate-first.mutant.sh"
  sed 's/| tail -1 | cut -d: -f1)/| head -1 | cut -d: -f1)/' "$SUT" > "$M6"

  if [ "$ctl_ok" -eq 1 ] && mut_ready m4 "$M4"; then
    nblk="$(grep -c . "$M4BLK")" || nblk=0
    if [ "$nblk" -lt 3 ] || [ "$(wc -l < "$M4")" -ne "$(wc -l < "$SUT")" ]; then
      bad "MUTATION (m4) did not MOVE the branch intact (block=$nblk lines)"
    elif p_order "$M4"; then
      bad "MUTATION (m4) SURVIVED: a hoisted diagnostic still accepted the column-1 line"
    elif ! p_bullet_live "$M4"; then
      bad "MUTATION (m4) broke the live bullet too — the kill is not the order arm's alone"
    else
      ok "MUTATION (m4): a diagnostic hoisted above the accepting arm fails the order arm"
    fi
  fi
  if [ "$ctl_ok" -eq 1 ] && mut_ready m5 "$M5"; then
    if p_empty "$M5"; then
      bad "MUTATION (m5) SURVIVED: an unconditional diagnostic still said first-gate"
    elif ! p_bullet_live "$M5"; then
      bad "MUTATION (m5) broke the live bullet too — the kill is not the empty-log arm's alone"
    else
      ok "MUTATION (m5): an unconditional diagnostic fails the empty-log arm"
    fi
  fi
  if [ "$ctl_ok" -eq 1 ] && mut_ready m6 "$M6"; then
    if p_two "$M6"; then
      bad "MUTATION (m6) SURVIVED: naming the FIRST quoted line still read as line 4"
    elif ! p_bullet_live "$M6"; then
      bad "MUTATION (m6) broke the one-bullet case too — the kill is not the two-bullets arm's"
    else
      ok "MUTATION (m6): naming the first quoted line, not the last, fails the two-bullets arm"
    fi
  fi
  # (m7) the REMEDY line deleted, the location kept -> only the remedy arm dies.
  M7="$WORK/h2-locate-no-remedy.mutant.sh"
  grep -vF -- '--attest and append its line on its OWN line at column 1' "$SUT" > "$M7"
  if [ "$ctl_ok" -eq 1 ] && mut_ready m7 "$M7"; then
    if p_remedy "$M7"; then
      bad "MUTATION (m7) SURVIVED: with the remedy line deleted the remedy arm still passed"
    elif ! p_bullet_live "$M7"; then
      bad "MUTATION (m7) broke the location too — the kill is not the remedy arm's alone"
    else
      ok "MUTATION (m7): deleting the remedy line fails the remedy arm and keeps the location"
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
  echo "  text — the consumer's bullet, six FAIL sentences — grants nothing and is LOCATED."
  exit 0
fi
echo "h2-attest-scripts-dir: FAIL ($fails assertion(s))" >&2
exit 1
