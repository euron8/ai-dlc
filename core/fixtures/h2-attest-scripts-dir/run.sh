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
echo "HERMETIC-CONSUMED core/scripts/validate-h2-attestation.sh"

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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# --- a FAITHFUL installed consumer ---------------------------------------------
# .git is the walk-up marker. The core validators go to scripts/ai-dlc/ and NOWHERE
# else; scripts/ carries a consumer-authored decoy, the shape core-manifest.md
# describes (ai-dlc ships audit-rule-files.sh, the consumer owns audit-dormant-gates.sh).
# tests/scripts/ is deliberately never created, so check-17-bypass/run.sh's first
# candidate ($HERE/../../scripts) cannot win by accident and mask a wrong answer.
mkdir -p "$WORK/.git" "$WORK/.claude/schemas" "$WORK/scripts/ai-dlc" "$WORK/tests/fixtures" || exit 2
cp "$SCHEMAS"/*.json "$WORK/.claude/schemas/" 2>/dev/null || {
  echo "FIXTURE ERROR: no schemas to copy from $SCHEMAS" >&2; exit 2; }

# Exactly the validators the drive reaches: the subject, and the two check-17-bypass/run.sh
# runs as PROV and EVID (its :48-49). Each is required by name; an absent one is fatal,
# never a quietly smaller install.
n_installed=0
for f in validate-h2-attestation.sh validate-provenance-block.sh validate-retro-evidence.sh; do
  [ -f "$SRC/$f" ] || {
    echo "FIXTURE ERROR: core script $f not found in $SRC" >&2; exit 2; }
  cp "$SRC/$f" "$WORK/scripts/ai-dlc/" || exit 2
  [ -f "$WORK/scripts/ai-dlc/$f" ] || {
    echo "FIXTURE ERROR: $f was not copied into the consumer tree" >&2; exit 2; }
  n_installed=$((n_installed + 1))
done

printf '#!/usr/bin/env bash\n# consumer-authored, not core\nexit 0\n' \
  > "$WORK/scripts/audit-dormant-gates.sh"

# The decoy must not accidentally BE the file the broken derivation looks for.
[ ! -f "$WORK/scripts/validate-provenance-block.sh" ] || {
  echo "FIXTURE ERROR: bare scripts/ holds a core validator — the tree is not a faithful" >&2
  echo "  consumer and the mutation control below would pass against the real bug." >&2
  exit 2; }

# The three fixture dirs --attest needs: all three feed the digest, and check-17-bypass
# is the one it drives (so its seed.sh must travel with its run.sh).
# `lib` travels as a fourth directory because install.sh ships it exactly that way: its
# fixture loop (scripts/install.sh, the "THE SHIP LIST IS DERIVED" block) copies every
# core/fixtures/<dir>/ without a `.dist-only` marker to tests/fixtures/<dir>/, and lib/
# carries no marker, so a consumer has tests/fixtures/lib/ beside tests/fixtures/check-17-bypass/.
# check-17-bypass/run.sh:2 sources ../lib/preamble.sh and exits 2 without it.
for d in check-h1-recursion check-17-bypass check-manifest-bypass lib; do
  [ -d "$FIXSRC/$d" ] || { echo "FIXTURE ERROR: missing source fixture $FIXSRC/$d" >&2; exit 2; }
  cp -R "$FIXSRC/$d" "$WORK/tests/fixtures/" || exit 2
done
chmod +x "$WORK/tests/fixtures"/*/*.sh 2>/dev/null || true

# ONE shared root resolution for EVERY drive of the subject below (D, A, B, C, v_run, vx, vxl,
# the --sprint drive): exported once, here, after the
# tree is built, so no drive can forget it. $SUT stays at $SRC. `cd "$WORK"` moves nothing on its
# own, because the validator walks up from the directory of the SCRIPT it runs; without this the
# walk-up finds the distribution root and the fixture search resolves core/fixtures, never
# $WORK/tests/fixtures.
export AI_DLC_PROJECT_ROOT="$WORK"

# The two candidate fixture directories must DIGEST differently, or the resolution arm below
# reads agreement between two directories that are the same bytes. check-17-bypass is driven by
# --attest, so it is left alone; the extra file goes into check-h1-recursion.
printf 'consumer-only seed: tests/fixtures differs from core/fixtures\n' \
  > "$WORK/tests/fixtures/check-h1-recursion/consumer-extra.txt" || exit 2

echo "h2-attest-scripts-dir"
echo "  subject: ${SUT#"$ROOT/"}"
echo "  consumer tree: scripts/ai-dlc/ ($n_installed core), scripts/ (1 consumer decoy),"
echo "                 tests/fixtures/ (3 fixture dirs plus lib), no core/, no tests/scripts/"
echo ""

# --- D. the fixture set resolves at all, in a consumer --------------------------
DIG_OUT="$( cd "$WORK" && bash "$SUT" --digest 2>&1 )"
DIG_RC=$?
if [ "$DIG_RC" -eq 0 ] && grep -qE '^[0-9a-f]{16}$' <<<"$DIG_OUT"; then
  ok "--digest resolves a fixture set in a consumer root ($DIG_OUT)"
else
  bad "--digest failed in a consumer tree (rc=$DIG_RC)"
  printf '%s\n' "$DIG_OUT" | sed 's/^/        /'
fi

# --- D2. WHICH set: tests/fixtures of the consumer root, never core/fixtures ----
# PRESENCE-shaped: the default digest must EQUAL the digest over $WORK/tests/fixtures and must
# DIFFER from the digest over the distribution's fixtures. The two explicit digests are shown to
# differ first, so equality with one side is evidence about the other.
D_CONS="$( bash "$SUT" --digest --fixtures "$WORK/tests/fixtures" 2>&1 )"; D_CONS_RC=$?
D_DIST="$( bash "$SUT" --digest --fixtures "$FIXSRC" 2>&1 )"; D_DIST_RC=$?
if [ "$D_CONS_RC" -ne 0 ] || [ "$D_DIST_RC" -ne 0 ] \
   || ! grep -qE '^[0-9a-f]{16}$' <<<"$D_CONS" || ! grep -qE '^[0-9a-f]{16}$' <<<"$D_DIST"; then
  echo "FIXTURE ERROR: an explicit --fixtures digest was not well-formed (rc=$D_CONS_RC/$D_DIST_RC)" >&2; exit 2
fi
[ "$D_CONS" != "$D_DIST" ] || {
  echo "FIXTURE ERROR: the consumer and distribution fixture digests are identical" >&2; exit 2; }
if [ "$DIG_OUT" = "$D_CONS" ] && [ "$DIG_OUT" != "$D_DIST" ]; then
  ok "the default --digest resolves \$WORK/tests/fixtures, not core/fixtures"
else
  bad "the default --digest ($DIG_OUT) is not the consumer tests/fixtures digest ($D_CONS) --"
  echo "        it resolved the distribution set ($D_DIST) or something else." >&2
fi

# --- A. THE ASSERTION. --attest must drive the fixture end to end ---------------
# This is the run that failed in every consumer for the life of the derivation. It is
# also this fixture's only real cost: one full check-17-bypass drive.
ATT_OUT="$( cd "$WORK" && bash "$SUT" --attest --sprint 999 2>&1 )"
ATT_RC=$?
if grep -q 'FIXTURE BROKEN: cannot source' <<<"$ATT_OUT"; then
  bad "HARNESS BROKEN: the copied check-17-bypass could not source its lib file, so --attest never drove it — the consumer tree lacks tests/fixtures/lib/, not a finding about H2"
  printf '%s\n' "$ATT_OUT" | grep 'cannot source' | sed 's/^/        /'
elif [ "$ATT_RC" -ne 0 ]; then
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
  # because EVERY verdict goes to stdout and stderr must stay empty for one (BL-344): a
  # caller capturing only stdout once saw nothing for a located refusal or for CHANGED.
  # Every predicate below takes the SCRIPT as its argument, so the same predicate is the
  # arm against the subject.
  vx() {
    ( cd "$WORK" && bash "$1" --verify --sprint "$3" --gate-log "$VLOG/$2.md" ) \
      >"$WORK/vx.out" 2>"$WORK/vx.err"
    X_RC=$?
    X_OUT="$(cat "$WORK/vx.out")"; X_ERR="$(cat "$WORK/vx.err")"
  }
  located() { grep -qF "$VLOG/$1.md:$2 QUOTES" <<<"$X_OUT" && [ -z "$X_ERR" ]; }  # located <seed> <line>
  vx_show() { printf '%s\n%s\n' "$X_OUT" "$X_ERR" | head -3 | sed 's/^/        /' >&2; }

  # L + M. THE TRAILING ACQUITTAL, and it is the half that makes a widened reader WORSE
  # than the anchored one. A gate log's own narrative QUOTES the line it complains about,
  # at the same sprint and the same digest. Both seeds must be refused WITHOUT a PASS and
  # WITHOUT the CHANGED message — routing prose to CHANGED still tells an operator the
  # sprint attested and the fixtures moved, when neither happened — and must be LOCATED:
  # the span is there, so "this is the sprint's first gate" is the wrong diagnostic too.
  p_lm() {  # p_lm <script> <seed>
    vx "$1" "$2" 311
    [ "$X_RC" -eq 1 ] && ! grep -q '^PASS' <<<"$X_OUT" \
      && ! grep -q 'CHANGED' <<<"$X_OUT$X_ERR" && located "$2" 1
  }
  for seed in prose-failure col1-then-prose; do
    if p_lm "$SUT" "$seed"; then
      ok "--verify refuses $seed and LOCATES it (a span followed by WORDS is prose)"
    else
      bad "--verify on $seed (rc=$X_RC): wanted rc 1, no PASS, no CHANGED, and"
      echo "        '$seed.md:1 QUOTES' on stdout, stderr empty." >&2
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
    [ "$X_RC" -eq 1 ] && located bullet-live 2 && ! grep -q '^PASS' <<<"$X_OUT"
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
    echo "        and 'bullet-live.md:2 QUOTES' on stdout, stderr empty." >&2; vx_show
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
    located bullet-live 2 && grep -qF 'OWN line at column 1, nothing before or after it.' <<<"$X_OUT"
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
  p_adv() { vx "$1" "$2" 314; [ "$X_RC" -eq 1 ] && ! grep -q '^PASS' <<<"$X_OUT" && grep -q 'RE-DRIVE' <<<"$X_OUT"; }
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
      && located "$2" "$3" && { [ -z "${4:-}" ] || grep -qF -- "$4" <<<"$X_OUT"; }
  }
  p_changed() { vx "$1" "$2" 311; [ "$X_RC" -eq 1 ] && grep -q 'the fixture set CHANGED' <<<"$X_OUT" && [ -z "$X_ERR" ]; }
  p_first()   { vx "$1" "$2" 311; [ "$X_RC" -eq 1 ] && grep -q "this is the sprint's first gate" <<<"$X_OUT"; }
  p_cite() {
    vx "$1" cb-cite-last 311
    [ "$X_RC" -eq 0 ] && [ "$(printf '%s\n' "$X_OUT" | sed -n '2p')" = "$V_OK" ]
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
      echo "        '$s.md:$l QUOTES' on stdout${r:+ and the reason '$r'}, stderr empty." >&2; vx_show
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

  # BL-342..BL-351. Each entry: its offender REFUSED (and located, never first-gate), and a
  # near-miss carrying every property the feared regression keys on ACCEPTED. The shapes are
  # the sweep probe the defect reports were measured with, and the near-misses come from the
  # consumer's own logs (a span AFTER a closed fence, the 309 re-attestation row, the
  # "voids the attestation by design" sentence).
  FN="${BT}${BT}${BT}"
  # BL-346: fenced, HTML comment block, indented code block
  sd b346-fence       "${FN}
${V_OK}
${FN}"
  sd b346-fence-table "${FN}
${HR}
| H2 | PASS | ${BT}${V_OK}${BT} |
${FN}"
  sd b346-comment     "<!--
${V_OK}
-->"
  sd b346-indent4     "    ${V_OK}"
  sd b346-split-table "${HR}
${FN}
note
${FN}
| H2 | PASS | ${BT}${V_OK}${BT} |"
  sd n346-after-fence   "${FN}
x
${FN}
${V_OK}"
  sd n346-after-comment "<!--
x
-->
<!-- one-line note -->
${V_OK}"
  sd n346-indent3       "   ${V_OK}"
  # BL-347: a tab is decoration where a space is; a tab BEFORE a line is an indented code block
  sd b347-tab-col1  "$(printf '\t%s' "$V_OK")"
  sd n347-tab-cell  "$HR
$(printf '| H2 | PASS |\t%s%s%s\t|' "$BT" "$V_OK" "$BT")"
  sd n347-tab-trail "$(printf '%s\t' "$V_OK")"
  # BL-349: the WHOLE verdict cell, and EVERY verdict column
  sd b349-pass-fail  "$HR
| H2 | PASS (FAILED on re-drive) | ${BT}${V_OK}${BT} |"
  sd b349-pass-slash "$HR
| H2 | PASS/FAIL | ${BT}${V_OK}${BT} |"
  sd b349-two-cols   "| Check | Result | Status | Evidence |
|---|---|---|---|
| H2 | PASS | FAIL | ${BT}${V_OK}${BT} |"
  sd n349-two-cols   "| Check | Result | Status | Evidence |
|---|---|---|---|
| H2 | PASS | PASSED | ${BT}${V_OK}${BT} |"
  sd n349-reattested "$HR
| H2 | PASSED (RE-ATTESTED, digest changed) | ${BT}${V_OK}${BT} |"
  # BL-350: a LATER revocation revokes; a later grant re-grants
  sd b350-row      "${V_OK}

${HR}
| H2 | VOIDED | ${BT}${V_OK}${BT} |"
  sd b350-sentence "${V_OK}
The attestation above is void."
  sd b350-over-changed "${V_OK}
${HR}
| H2 | VOIDED | ${BT}${V_OK}${BT} |
| H2 | PASS | ${BT}${V_BAD}${BT} |"
  sd n350-regrant  "${V_OK}
${HR}
| H2 | VOIDED | ${BT}${V_OK}${BT} |

${V_LATER}"
  sd n350-commentary "${V_OK}
A changed fixture voids the attestation by design.
| [core] H2 | PASSED (RE-ATTESTED, digest changed) | Prior attestation (${BT}digest=0000000000000000${BT}) voided by the reconcile |
The attestation above is void: digest=0000000000000000 predates the reconcile."
  # BL-342 / BL-351: a NUL byte, which ends a line for BSD awk
  printf '| Check | Result | Evidence |\n|---|---|---|\n| H2 | FAIL\000 | %s%s%s |\n' "$BT" "$V_OK" "$BT" > "$VLOG/b351-nul-cell.md" || exit 2
  printf '%s\000 FAILED, do not cite\n' "$V_OK" > "$VLOG/b351-nul-prose.md" || exit 2
  printf 'x\000y\nH2 FAILED: %s%s%s do not cite\n' "$BT" "$V_OK" "$BT" > "$VLOG/b342-nul-number.md" || exit 2
  printf 'x\000y\n%s\n' "$V_OK" > "$VLOG/n351-nul-elsewhere.md" || exit 2
  sd b351-underscore "_${V_OK}_"
  sd b351-star       "*${V_OK}*"
  # BL-343: one cp1252 byte on the quoted line, and on a line beside a good one
  printf -- '- \223note: %s%s%s; item 3 FAILED\n' "$BT" "$V_OK" "$BT" > "$VLOG/b343-cp1252.md" || exit 2
  printf '\223 note\n%s\n' "$V_OK" > "$VLOG/n343-cp1252.md" || exit 2
  for s in b351-nul-cell b351-nul-prose b342-nul-number n351-nul-elsewhere; do
    [ "$(wc -c < "$VLOG/$s.md")" -gt "$(tr -d '\000' < "$VLOG/$s.md" | wc -c)" ] \
      || { echo "FIXTURE ERROR: $s.md carries no NUL byte" >&2; exit 2; }
  done
  # BL-344: an unreadable log. Root reads a mode-000 file, so the cell is skipped there.
  cp "$VLOG/col1.md" "$VLOG/b344-unread.md" && chmod 000 "$VLOG/b344-unread.md"
  UNREAD_OK=1; [ -r "$VLOG/b344-unread.md" ] && UNREAD_OK=0

  p_rev() {  # p_rev <script> <seed> <line> <grantline>
    vx "$1" "$2" 311
    [ "$X_RC" -eq 1 ] && [ -z "$X_ERR" ] && ! grep -q '^PASS' <<<"$X_OUT" \
      && grep -qF "$VLOG/$2.md:$3 REVOKES the H2 attestation for sprint 311 accepted at line $4." <<<"$X_OUT"
  }
  p_sprint_rx() {
    ( cd "$WORK" && bash "$1" --verify --sprint '.*' --gate-log "$VLOG/col1.md" ) >"$WORK/vx.out" 2>"$WORK/vx.err"
    X_RC=$?; X_OUT="$(cat "$WORK/vx.out")"; X_ERR="$(cat "$WORK/vx.err")"
    [ "$X_RC" -eq 1 ] && ! grep -q '^PASS' <<<"$X_OUT" && grep -q 'digits only' <<<"$X_ERR"
  }
  p_first_stdout() { p_first "$1" cb-none && [ -z "$X_ERR" ]; }
  p_unread() {
    vx "$1" b344-unread 311
    [ "$X_RC" -eq 1 ] && grep -q 'could not read' <<<"$X_ERR" && ! grep -q 'first gate' <<<"$X_OUT$X_ERR"
  }
  vxl() {  # vxl <script> <seed> <locale>
    ( cd "$WORK" && LC_ALL="$3" bash "$1" --verify --sprint 311 --gate-log "$VLOG/$2.md" ) \
      >"$WORK/vx.out" 2>"$WORK/vx.err"
    X_RC=$?; X_OUT="$(cat "$WORK/vx.out")"; X_ERR="$(cat "$WORK/vx.err")"
  }
  U8=""
  for l in en_US.UTF-8 C.UTF-8; do [ "$(LC_ALL=$l locale charmap 2>/dev/null)" = "UTF-8" ] && { U8="$l"; break; }; done
  p_cp1252() {  # both locales: refused-and-located, and the neighbouring good line verifies
    local l
    for l in C $U8; do
      vxl "$1" b343-cp1252 "$l"; [ "$X_RC" -eq 1 ] && located b343-cp1252 1 || return 1
      vxl "$1" n343-cp1252 "$l"; [ "$X_RC" -eq 0 ] && grep -q '^PASS  H2 attested' <<<"$X_OUT" || return 1
    done
  }

  # <seed>|<line>|<reason>, all refused, all located
  B_ROWS="b346-fence|2|inside a fenced code block
b346-fence-table|4|inside a fenced code block
b346-comment|2|inside an HTML comment block
b346-indent4|1|inside an indented code block
b346-split-table|6|no header row
b347-tab-col1|1|inside an indented code block
b349-pass-fail|3|carries a failure word after PASS
b349-pass-slash|3|carries more than PASS and one parenthetical
b349-two-cols|3|Status cell does not begin PASS
b351-nul-cell|3|does not begin PASS
b351-nul-prose|1|inside other text
b342-nul-number|2|inside other text
b351-underscore|1|inside other text
b351-star|1|inside other text"
  N_SEEDS="n346-after-fence n346-after-comment n346-indent3 n347-tab-cell n347-tab-trail n349-two-cols n349-reattested n350-regrant n350-commentary n351-nul-elsewhere"
  n_b=0
  while IFS='|' read -r s l r; do
    [ -n "$s" ] || continue; n_b=$((n_b + 1))
    if p_refuse "$SUT" "$s" "$l" "$r"; then ok "--verify refuses $s and LOCATES it at :$l ($r)"
    else bad "--verify on $s (rc=$X_RC): wanted located at :$l with '$r', nothing on stderr"; vx_show; fi
  done <<<"$B_ROWS"
  [ "$n_b" -ge 14 ] || bad "only $n_b BL-342..351 refusal rows were driven — B_ROWS was truncated"
  for s in $N_SEEDS; do
    if p_verify "$SUT" "$s"; then ok "--verify accepts near-miss $s"
    else bad "--verify REFUSED near-miss $s (rc=$X_RC)"; vx_show; fi
  done
  if p_rev "$SUT" b350-row 5 1; then ok "--verify: a later VOIDED row carrying the span REVOKES the grant at line 1"
  else bad "--verify on b350-row (rc=$X_RC) did not report the revocation at :5"; vx_show; fi
  if p_rev "$SUT" b350-sentence 2 1; then ok "--verify: a later 'attestation above is void' sentence REVOKES it"
  else bad "--verify on b350-sentence (rc=$X_RC) did not report the revocation at :2"; vx_show; fi
  if p_rev "$SUT" b350-over-changed 4 1; then ok "--verify: a revocation outranks a later moved-digest row (REVOKED, not CHANGED)"
  else bad "--verify on b350-over-changed (rc=$X_RC) did not report REVOKED at :4"; vx_show; fi
  if p_sprint_rx "$SUT"; then ok "--verify refuses --sprint '.*' (digits only) and grants nothing"
  else bad "--verify with --sprint '.*' (rc=$X_RC) was not refused on stderr"; vx_show; fi
  if p_first_stdout "$SUT"; then ok "--verify's first-gate verdict is on stdout, stderr empty"
  else bad "--verify's first-gate verdict (rc=$X_RC) is not stdout-only"; vx_show; fi
  if [ "$UNREAD_OK" -eq 1 ]; then
    if p_unread "$SUT"; then ok "--verify on a mode-000 log says could-not-read, never first-gate"
    else bad "--verify on an unreadable log (rc=$X_RC) did not say could-not-read"; vx_show; fi
  else echo "  skip  mode-000 cell: this user can read a mode-000 file"; fi
  [ -n "$U8" ] || echo "  skip  UTF-8 half of the cp1252 cell: no UTF-8 locale on this host"
  if p_cp1252 "$SUT"; then ok "--verify: a cp1252 byte is located, and its neighbour verifies, under C${U8:+ and $U8}"
  else bad "--verify on the cp1252 seeds (rc=$X_RC) differs by locale or lost the location"; vx_show; fi

fi

echo ""
report_end h2-attest-scripts-dir
