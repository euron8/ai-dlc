#!/usr/bin/env bash
# Exercise validate-ac-falsifiability.sh (gate-validation Check 31).
#
# Exit 0 iff:
#   - bad-unbounded.md      FAILS (1)  -- a forbidden term on the AC header line
#   - bad-continuation.md   FAILS (1)  -- forbidden term on a CONTINUATION line;
#                                         a line-scoped check misses this one
#   - dangling-evidence.md  FAILS (1)  -- prior_evidence path not on disk
#   - dangling-anchor.md    FAILS (1)  -- path resolves, anchor absent
#   - good-bounded.md       PASSES (0) -- OVER-FIRE CONTROL. An AC entirely about
#                                         covering a set, correctly bounded, using
#                                         no forbidden term. Proves the check
#                                         discriminates on the word, not the topic.
#   - good-evidence.md      PASSES (0) -- OVER-FIRE CONTROL, resolvable citation
#   - waiver.md             PASSES (0) -- waiver path reachable, AND the waiver is
#                                         REPORTED on stdout (suppresses the FAIL,
#                                         never the report)
#   - undeclared-form.md    DISARMS (2) -- declares ACs, presents none in the form
#                                          stories-test-strategy.md mandates. Must
#                                          NOT exit 0: an AC the checker cannot read
#                                          is not an AC that passed.
#   - an empty term list    DISARMS (2) -- FAIL-CLOSED control. A zero-term lexicon
#                                          reports every story clean and prints the
#                                          same shape of line as a real pass.
#   - two MUTATION controls hold        -- neuter the term check and the
#                                          prior_evidence check independently; each
#                                          must turn its own red case green. Two
#                                          guards need two mutants; one mutant
#                                          licenses only one FAIL.
#
# MUTANT MATRIX. "A mutant fails only its own assertion" (.claude/rules/fixture-mutants.md) is a
# test-quality property, measured ONCE for every mutant x arm and recorded here; per push each
# mutant runs its deciding arm (must fail) and a twin arm the measured matrix shows green (must
# stay green). The recorded matrix plus the twin replaces a per-push exact-vector assertion.
# Measured: term-off also trips bad-continuation (same term check); every other mutant trips
# only its deciding arm. The matrix is re-measured whenever an arm or a mutant is added or changed.
# Clause (c), the run window: its four mutants are scored by rw_expect_kill on their deciding arms
# plus the twin below; --matrix drives each against all ten rw arms and prints its MATRIX row.
# MUTANT-MATRIX defer-ignored decides=w2 twins=w1
# MUTANT-MATRIX cmp-inverted decides=w1,w3 twins=w2
# MUTANT-MATRIX floor-ignored decides=w4 twins=w4b
# MUTANT-MATRIX earliest-counts-deferred decides=w6 twins=w6n
# MUTANT-MATRIX term-off decides=bad-unbounded twins=dangling-evidence
# MUTANT-MATRIX evidence-off decides=dangling-evidence twins=dangling-anchor
# MUTANT-MATRIX ident-drop decides=identity twins=good-bounded
# MUTANT-MATRIX ident-nonce decides=identity twins=good-bounded
# MUTANT-MATRIX-DYNAMIC muts-loop why=the loop for m in $MUTS passes "$m" to mutant_killed; every MUTS member carries its own row in this block
# MUTANT-MATRIX-REMEASURE bash core/fixtures/check-31-ac-falsifiability/run.sh --matrix
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

V=""
for cand in \
  "$DIR/../../scripts/validate-ac-falsifiability.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-ac-falsifiability.sh" \
  "$DIR/../../core/scripts/validate-ac-falsifiability.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-ac-falsifiability.sh" >&2; exit 2; }

# The lexicon lives in the step file, not in the validator. Resolve it explicitly so
# the fixture drives the same list the pipeline does.
LEX=""
for cand in \
  "$DIR/../../skills/ai-dlc/steps/stories-test-strategy.md" \
  "$DIR/../../../.claude/skills/ai-dlc/steps/stories-test-strategy.md" \
  "$DIR/../../core/skills/ai-dlc/steps/stories-test-strategy.md"; do
  [ -f "$cand" ] && LEX="$cand" && break
done
[ -n "$LEX" ] || { echo "run.sh: could not locate stories-test-strategy.md (the lexicon home)" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-31.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }

# --matrix is an ARGV flag (never an env var, never via hermetic-run.sh, which forwards no argument):
# it replaces the per-push mutant stage with the full mutant x arm matrix and prints MATRIX rows.
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
MX_FULL_RUNS=0     # incremented ONLY by the matrix-only cells; a plain run must leave it at 0
MUT_LIB="$DIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
[ -f "$DIR/matrix.sh" ] || { echo "FIXTURE ERROR: matrix.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/check-31-ac-falsifiability/matrix.sh"

echo "check-31-ac-falsifiability:"

# Never `out=$(...)` for the verdict: command substitution moves the validator's
# status into the assignment's, and a fixture that reads the wrong status proves
# nothing. Run it, then read $?.
expect() { # <expected-rc> <payload> <label>
  ( cd "$DIR" && bash "$V" --lexicon-from "$LEX" "$DIR/$2" ) >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$1" ]; then ok "$3"; else bad "$3 (expected rc=$1, got rc=$got)"; fi
}

expect 1 bad-unbounded.md     "a forbidden term on the AC header is rejected"
expect 1 bad-continuation.md  "a forbidden term on a CONTINUATION line is rejected (block scope, not line scope)"
expect 1 dangling-evidence.md "an unresolvable prior_evidence path is rejected"
expect 1 dangling-anchor.md   "a resolvable path with an absent anchor is rejected"
expect 0 good-bounded.md      "OVER-FIRE CONTROL: a correctly-bounded set-covering AC passes"
expect 0 good-evidence.md     "OVER-FIRE CONTROL: a resolvable prior_evidence citation passes"
expect 2 undeclared-form.md   "a story declaring ACs in an undeclared form DISARMS (never exits 0)"

# REAL bmad-create-epics-and-stories OUTPUT FORM. Its stories carry a BOLD INLINE
# `**Acceptance Criteria:**` label and unnumbered Given/When/Then blocks, and contain
# ZERO `AC` tokens. The first disarm predicate tested only for an Acceptance-Criteria
# HEADING or an `acceptance_criteria:` field, so against this real shape the script
# reported PASS with "0 AC block(s)" on criteria containing BOTH `definitively` and
# `exhaustive` — a silent false pass, which is the defect class this check removes.
expect 2 bmad-gwt-form.md      "PIN: BMAD's real Given/When/Then AC form DISARMS, never passes silently"

# The waiver must still be REPORTED. A waiver that silences the report is a hole
# nobody can audit.
# ONE run of waiver.md answers both questions: it used to be run twice, once for the exit code
# (`expect 0`) and once for the stdout line. The exit code and the stdout are captured together
# (never `cmd | grep`, which would take grep's status).
W_OUT="$( cd "$DIR" && bash "$V" --lexicon-from "$LEX" "$DIR/waiver.md" 2>/dev/null )"; W_RC=$?
if [ "$W_RC" -eq 0 ]; then ok "a declared falsifiability_waiver suppresses the FAIL"
else bad "a declared falsifiability_waiver suppresses the FAIL (expected rc=0, got rc=$W_RC)"; fi
if grep -q 'waiver' <<<"$W_OUT"; then
  ok "the waiver is printed, not silently honoured"
else
  bad "waiver.md passed but printed no waiver line — a suppressed FAIL with no record"
fi

# --- FAIL-CLOSED control ------------------------------------------------------
# An empty lexicon must not be able to report a clean scan.
printf '<!-- AC_UNBOUNDED_TERMS v1 -->\n<!-- AC_UNBOUNDED_TERMS_END -->\n' > "$WORK/empty-lex.md"
( cd "$DIR" && bash "$V" --lexicon-from "$WORK/empty-lex.md" "$DIR/bad-unbounded.md" ) >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "FAIL-CLOSED: a zero-term lexicon exits 2, not 0"
else
  bad "a zero-term lexicon did not exit 2 — the check can be disarmed into a silent pass"
fi
( cd "$DIR" && bash "$V" --lexicon-from "$WORK/no-such-file.md" "$DIR/bad-unbounded.md" ) >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "FAIL-CLOSED: an unreadable lexicon exits 2, not 0"
else
  bad "an unreadable lexicon did not exit 2"
fi

# THE `echo "$@"` ATTACK IS OPEN HERE AND THAT IS RECORDED RATHER THAN PAPERED OVER. The
# lexicon arrives through `--lexicon-from` and the stories are positionals, so a fix echoing
# its arguments rather than what it RESOLVED would satisfy every arm below -- for a
# caller-supplied flag with no defaulted form the two strings are identical and no observation
# here can separate them. `validate-ac-falsifiability.sh` DOES default its lexicon when the
# flag is omitted (it walks candidates), so the arm that would close this drives the validator
# with NO `--lexicon-from` and requires the DEFAULTED path to appear. That arm is not built;
# the gap is stated so the next author knows it is a gap and not a covered case.
# --- CORPUS IDENTITY on the PASS line -----------------------------------------
# THE DEFECT. Both inputs are caller-supplied — the lexicon through `--lexicon-from`, the
# stories as positional arguments — and the PASS line reported only a TALLY:
# `PASS (1 story file(s), 2 AC block(s), 9 term(s) loaded, 0 waiver(s))`. Two runs over two
# different trees holding identical bytes were therefore BYTE-IDENTICAL. The lexicon is the
# consequential half: it is the term list the whole check is, and `9 term(s) loaded` is a
# COUNT, which is exactly what cannot distinguish this sprint's list from another's.
#
# THE ARM IS KEYED ON DISCRIMINATION, NOT ON A SPELLING. The pair is driven twice over two
# mktemp corpora seeded with the same bytes; the outputs must DIFFER **and** each must carry
# ITS OWN two paths. Those halves are separate requirements and the second is load-bearing:
# a nonce, a PID or a timestamp makes two runs differ while naming nothing, and the nonce
# mutant below is that fix. No label text is grepped, so re-wording `lexicon:` leaves the arm
# working; what it demands is the resolved path, and the roots are mktemp names, so no
# implementation can hardcode the literal it needs.
#
# IT IS PRESENCE-SHAPED — two paths must APPEAR in a run that reached the PASS emitter — so
# a subject replaced by `exit 0` fails it by construction.
AC_IDENT_WHY=""
ac_ident_corpus() {   # -> prints a fresh corpus root holding a copy of the passing pair
  local d
  d="$(mktemp -d "$WORK/ident.XXXXXX")" || return 1
  cp "$LEX"                 "$d/lexicon.md" || return 1
  cp "$DIR/good-bounded.md" "$d/story.md"   || return 1
  printf '%s\n' "$d"
}
ac_ident_holds() {   # <validator>
  local v="$1" a b oa ob ra rb
  AC_IDENT_WHY=""
  a="$(ac_ident_corpus)" || { AC_IDENT_WHY="could not build corpus A"; return 1; }
  b="$(ac_ident_corpus)" || { AC_IDENT_WHY="could not build corpus B"; return 1; }
  oa="$(bash "$v" --lexicon-from "$a/lexicon.md" "$a/story.md" 2>&1)"; ra=$?
  ob="$(bash "$v" --lexicon-from "$b/lexicon.md" "$b/story.md" 2>&1)"; rb=$?
  if [ "$ra" != "0" ] || [ "$rb" != "0" ]; then
    AC_IDENT_WHY="rc=$ra/$rb, expected 0/0 — the run never reached the PASS emitter"; return 1
  fi
  if ! grep -qF ': PASS (' <<<"$oa"; then
    AC_IDENT_WHY="no PASS line — this arm did not reach the emitter it claims to guard"; return 1
  fi
  if [ "$oa" = "$ob" ]; then
    AC_IDENT_WHY="two different trees holding identical bytes produced byte-identical output"
    return 1
  fi
  if ! grep -qF "$a/lexicon.md" <<<"$oa" || ! grep -qF "$a/story.md" <<<"$oa"; then
    AC_IDENT_WHY="run A names neither the lexicon it loaded nor the story file it scanned"
    return 1
  fi
  if ! grep -qF "$b/lexicon.md" <<<"$ob" || ! grep -qF "$b/story.md" <<<"$ob"; then
    AC_IDENT_WHY="run B names neither the lexicon it loaded nor the story file it scanned"
    return 1
  fi
  if grep -qF "$b" <<<"$oa"; then
    AC_IDENT_WHY="run A's output carries run B's root — the paths are not the ones it resolved"
    return 1
  fi
  return 0
}

if ac_ident_holds "$V"; then
  ok "IDENTITY: the PASS line names the lexicon it loaded and the story files it scanned, and two identical corpora in different trees are distinguishable"
else
  bad "IDENTITY: the PASS line carries no corpus identity — $AC_IDENT_WHY. A scan against another sprint's term list reports the same green tally as one against this sprint's"
fi

# THE UNMUTATED CONTROL, with a positive conjunct. The mutants below are copies in $WORK;
# a copy that could not run would emit nothing, and "no output" would otherwise score as a
# kill. `ac_ident_holds` demands a PASS line and two paths, so this cannot pass against a
# copy replaced by `exit 0`.
AC_CTL="$WORK/ident-control.sh"; cp "$V" "$AC_CTL"
AC_CTL_OK=0
if ac_ident_holds "$AC_CTL"; then
  ok "IDENTITY CONTROL: an unmutated copy reproduces the identity lines, so a mutant's silence below means mutation and not breakage"
  AC_CTL_OK=1
else
  bad "IDENTITY CONTROL FAILED ($AC_IDENT_WHY) — the two identity mutants below are uninterpretable"
fi

# ===========================================================================
# THE MUTANTS, table-driven. Every mutant is a COPY of the validator (cmp -s guarded, bash -n
# guarded). On every push a mutant runs its DECIDING arm (which must FAIL, at the recorded
# token) and its measured-green TWIN arm(s) (which must stay green, proving the kill is
# confined to the deciding arm). The full mutant x arm matrix runs only under --matrix.
#
# The per-mutant assertion that "a mutant fails ONLY its own assertion"
# (.claude/rules/fixture-mutants.md) is established at authoring by the MUTANT-MATRIX header
# rows and re-established by `--matrix`; the twin replaces it per push.
ARMS="bad-unbounded bad-continuation dangling-evidence dangling-anchor good-bounded good-evidence waiver undeclared-form bmad-gwt-form identity"
MUTS="term-off evidence-off ident-drop ident-nonce"

arm_want() { case "$1" in
  bad-unbounded|bad-continuation|dangling-evidence|dangling-anchor) printf 1 ;;
  good-bounded|good-evidence|waiver) printf 0 ;;
  undeclared-form|bmad-gwt-form) printf 2 ;;
  identity) printf holds ;;
esac; }
# arm <validator> <arm> -> the arm's verdict token for that program
arm() {
  case "$2" in
    identity) if ac_ident_holds "$1"; then printf holds; else printf broken; fi ;;
    *) ( cd "$DIR" && bash "$1" --lexicon-from "$LEX" "$DIR/$2.md" ) >/dev/null 2>&1; printf '%s' "$?" ;;
  esac
}
mut_decides() { case "$1" in term-off) printf bad-unbounded ;; evidence-off) printf dangling-evidence ;; *) printf identity ;; esac; }
mut_killtok() { case "$1" in term-off|evidence-off) printf 0 ;; *) printf broken ;; esac; }
mut_twins()   { case "$1" in
  term-off)     printf 'dangling-evidence' ;;
  evidence-off) printf 'dangling-anchor' ;;
  ident-drop)   printf 'good-bounded' ;;
  ident-nonce)  printf 'good-bounded' ;;
esac; }

# build_mutant <name> -> sets MCOPY; returns 1 (already reported) when it cannot be built.
ac_av=': PASS (${#FILES[@]} story file(s)'
build_mutant() {
  MCOPY="$WORK/mut-$1.sh"
  case "$1" in
    term-off)
      sed 's/if grep -qiE "(\^|\[\^\[:alnum:\]_\])\${term}(\[\^\[:alnum:\]_\]|\\\$)" <<<"\$body"; then/if false; then/' "$V" > "$MCOPY" 2>/dev/null ;;
    # Neuter the EXISTENCE TEST, not the loop that drives it: emptying the candidate list leaves
    # `resolved` unset, the same state a real miss produces, so the mutant would fail for the
    # guard's own reason and demonstrate nothing. The guard is `[ -f ... ]`; that has to go.
    evidence-off)
      sed 's/\[ -f "\$base\/\$cpath" \] \&\&/true \&\&/' "$V" > "$MCOPY" 2>/dev/null ;;
    ident-drop)
      # The identity block deleted -- the state this release replaced. Anchored on the PASS
      # verdict line, and guarded on the line count so the block cannot shrink under the arm.
      if [ "$(grep -cF "$ac_av" "$V")" != "1" ]; then
        bad "FIXTURE ERROR: mutation 'ident-drop' has a non-unique anchor -- the deletion could land on another emitter"; return 1
      elif [ "$(grep -cE '^ *echo "  ' "$V")" -lt 2 ]; then
        bad "FIXTURE ERROR: fewer than 2 identity lines follow the PASS verdict -- the block this fixture guards has shrunk"; return 1
      fi
      awk -v A="$ac_av" '
        index($0, A)          { print; hit=1; next }
        hit && /^ *echo "  /  { next }
                              { hit=0; print }
      ' "$V" > "$MCOPY" ;;
    # Identity replaced by a per-run nonce -- THE FIX THAT DISCRIMINATES WITHOUT NAMING.
    ident-nonce)
      awk -v A="$ac_av" '
        index($0, A)          { print; hit=1; next }
        hit && /^ *echo "  /  { print "  echo \"  nonce: $$-$RANDOM\""; next }
                              { hit=0; print }
      ' "$V" > "$MCOPY" ;;
  esac
  if cmp -s "$V" "$MCOPY"; then
    bad "FIXTURE ERROR: mutation '$1' matched nothing -- its assertion would prove nothing"; return 1
  elif ! bash -n "$MCOPY" 2>/dev/null; then
    bad "FIXTURE ERROR: mutant '$1' is not a valid shell script -- its silence is not a kill"; return 1
  fi
  return 0
}

if [ "$AC_CTL_OK" = "1" ]; then
  if [ "$MATRIX" = "1" ]; then
    for m in $MUTS; do
      build_mutant "$m" || continue
      d="$(mut_decides "$m")"; tr=""; gr=""
      for a in $ARMS; do
        MX_FULL_RUNS=$((MX_FULL_RUNS + 1))
        got="$(arm "$MCOPY" "$a")"
        if [ "$got" = "$(arm_want "$a")" ]; then gr="$gr,$a"; else tr="$tr,$a"; fi
      done
      k=no; case "$tr," in *",$d,"*|",$d,"*) k=yes ;; esac
      case ",$tr," in *",$d,"*) k=yes ;; esac
      mx_row "$m" "$d" "$k" "${tr#,}" "${gr#,}"
    done
  else
    for m in $MUTS; do
      build_mutant "$m" || continue
      d="$(mut_decides "$m")"; kt="$(mut_killtok "$m")"
      # SAME-RUN BASE PASS: the unmutated validator must pass the deciding arm in THIS run.
      bflag=0; if [ "$(arm "$V" "$d")" = "$(arm_want "$d")" ]; then bflag=1; fi
      got="$(arm "$MCOPY" "$d")"
      if [ "$got" = "$kt" ]; then
        mutant_killed "$bflag" "$m" "MUTANT $m: deciding arm $d fails ($got) -- the guard under test is what produced the verdict"
      else
        bad "MUTANT $m SURVIVED: arm $d answered '$got', wanted '$kt' -- the guard under test is not what produced the verdict"
      fi
      for t in $(mut_twins "$m"); do
        [ "$t" = "-" ] && continue
        got="$(arm "$MCOPY" "$t")"
        if [ "$got" = "$(arm_want "$t")" ]; then ok "MUTANT $m: twin arm $t stays green ($got) -- the kill is confined to $d"
        else bad "MUTANT $m moved its twin arm $t to '$got' -- the arms overlap, re-measure with --matrix"; fi
      done
    done
  fi
else
  bad "IDENTITY CONTROL FAILED -- the mutants below are uninterpretable"
fi

# --- CLAUSE (c): RUN WINDOW INSIDE THE PLANNED CLOSE ---------------------------------
# Three project roots, each a canonical sprint-status.yaml plus Check 28's spec-adoption
# declaration, driven through AI_DLC_PROJECT_ROOT. The floor is validate-spec-adoption.sh, the
# validator's SIBLING, so every mutant below is built in a directory holding a copy of both.
#   IN  -- s320, floor s300 (in force), planned_close 2026-10-28T21:00:00Z
#   AT  -- s299, floor s299 (equal is IN-FORCE: --verdict refuses only below), no planned_close
#   BLW -- s298, floor s299 (below), no planned_close
rw_world() { # <name> <sprint> <floor> [planned_close]
  local w="$WORK/rw-$1"
  mkdir -p "$w/_bmad-output/implementation-artifacts" "$w/_bmad-output/planning-artifacts" || return 1
  { printf 'sprint: %s\nname: "rw-probe"\nstatus: in_progress\n' "$2"
    [ -n "${4:-}" ] && printf 'planned_close: %s   # written at planning\n' "$4"
    printf 'stories:\n  story-%s-1:\n    status: ready-for-dev\n' "$2"
  } > "$w/_bmad-output/implementation-artifacts/sprint-status.yaml" || return 1
  printf '<!-- SPEC_ADOPTION v1 -->\nadopted_from_sprint: %s\ndeclared_at_sha: abc1234\nrationale: probe floor\n' "$3" \
    > "$w/_bmad-output/planning-artifacts/spec-adoption.md" || return 1
  printf '%s\n' "$w"
}
RW_IN="$(rw_world in 320 300 2026-10-28T21:00:00Z)"; RW_AT="$(rw_world at 299 299)"; RW_BLW="$(rw_world blw 298 299)"
[ -n "$RW_IN" ] && [ -n "$RW_AT" ] && [ -n "$RW_BLW" ] || { echo "FIXTURE BROKEN: a clause (c) world could not be built" >&2; exit 2; }
# The --stories-dir worlds are BUILT here from flat seeds, never shipped as subdirectories:
# install.sh copies a fixture with a non-recursive `cp <fixture>/*`, so a seed subdirectory
# would not reach a consumer and w6/w6n would DISARM there while passing here.
RW_WAVE="$WORK/rw-wave"; RW_NOWIN="$WORK/rw-nowin"
mkdir -p "$RW_WAVE" "$RW_NOWIN" || { echo "FIXTURE BROKEN: could not build the --stories-dir worlds" >&2; exit 2; }
for _s in a-early b-max c-deferred-later d-mid; do
  cp "$DIR/rw-wave-$_s.md" "$RW_WAVE/$_s.md" || { echo "FIXTURE BROKEN: seed rw-wave-$_s.md missing" >&2; exit 2; }
done
cp "$DIR/rw-none.md" "$RW_NOWIN/a-none.md" || { echo "FIXTURE BROKEN: seed rw-none.md missing" >&2; exit 2; }
RW_SIB="$(dirname "$V")/validate-spec-adoption.sh"
[ -f "$RW_SIB" ] || { echo "FIXTURE BROKEN: validate-spec-adoption.sh is not beside $V; clause (c) has no floor to read" >&2; exit 2; }

RW_OUT="$WORK/rw.out"; RW_ERR="$WORK/rw.err"
rw_run() { # <validator> <root> <args...> -> rc; stdout/stderr in RW_OUT/RW_ERR
  local v="$1" r="$2"; shift 2
  ( cd "$WORK" && AI_DLC_PROJECT_ROOT="$r" bash "$v" --lexicon-from "$LEX" "$@" ) > "$RW_OUT" 2> "$RW_ERR"
}
# Each arm is PRESENCE-shaped: it demands a specific line, so a subject replaced by `exit 0`
# fails every one of them.
rw_w1()  { rw_run "$1" "$RW_IN" "$DIR/rw-after.md"; [ $? -eq 1 ] && grep -q "^REFUSED run-window-after-close $DIR/rw-after.md AC2 " "$RW_ERR"; }
rw_w2()  { rw_run "$1" "$RW_IN" "$DIR/rw-deferred.md"; [ $? -eq 0 ] && grep -q ': PASS (' "$RW_OUT" && ! grep -q REFUSED "$RW_ERR"; }
rw_w3()  { rw_run "$1" "$RW_IN" "$DIR/rw-before.md"; [ $? -eq 0 ] && grep -q ': PASS (' "$RW_OUT"; }
rw_w4()  { rw_run "$1" "$RW_BLW" "$DIR/rw-after.md"; [ $? -eq 0 ] && grep -q '^SKIP RUN-WINDOW (below floor) s298' "$RW_OUT" && grep -q ': PASS (' "$RW_OUT"; }
rw_w4b() { rw_run "$1" "$RW_AT" "$DIR/rw-after.md"; [ $? -eq 1 ] && grep -q "^REFUSED planned-close-missing $DIR/rw-after.md " "$RW_ERR"; }
rw_w4n() { rw_run "$1" "$RW_AT" "$DIR/rw-none.md"; [ $? -eq 0 ] && grep -q ': PASS (' "$RW_OUT" && ! grep -q 'planned-close' "$RW_ERR"; }
rw_w5()  { rw_run "$1" "$RW_IN" "$DIR/rw-malformed.md"; [ $? -eq 1 ] && grep -q "^REFUSED run-window-malformed $DIR/rw-malformed.md AC2 .*2026-10-29 09:36" "$RW_ERR"; }
rw_w5d() { rw_run "$1" "$RW_IN" "$DIR/rw-bad-defer.md"; [ $? -eq 1 ] && grep -q "^REFUSED defers-to-malformed $DIR/rw-bad-defer.md AC2 .*next sprint" "$RW_ERR"; }
# w6 reads the EARLIEST-CLOSE line and NOT the exit: that line is independent of the clause (c)
# verdict by contract, and asserting rc=0 here would let the w2 and w1/w3 mutants kill w6 too.
rw_w6()  { rw_run "$1" "$RW_IN" --stories-dir "$RW_WAVE"; [ "$(grep -c '^EARLIEST-CLOSE ' "$RW_OUT")" = 1 ] && grep -qx 'EARLIEST-CLOSE 2026-10-28T12:00:00Z' "$RW_OUT"; }
rw_w6n() { rw_run "$1" "$RW_IN" --stories-dir "$RW_NOWIN"; [ $? -eq 0 ] && grep -qx 'EARLIEST-CLOSE none' "$RW_OUT"; }
RW_ARMS="w1 w2 w3 w4 w4b w4n w5 w5d w6 w6n"
rw_label() {
  case "$1" in
    w1)  echo "(w1) s320 1.3 AC4 shape: a window after planned_close with no defers_to is REFUSED run-window-after-close" ;;
    w2)  echo "(w2) the same window with defers_to: CO-S320-... is accepted" ;;
    w3)  echo "(w3) a window before planned_close is accepted" ;;
    w4)  echo "(w4) below the floor with no planned_close prints SKIP RUN-WINDOW (below floor), exit unchanged" ;;
    w4b) echo "(w4b) at the floor, no planned_close, a window present: REFUSED planned-close-missing" ;;
    w4n) echo "(w4n) NEAR-MISS: at the floor, no planned_close, no window: accepted, nothing about planned_close" ;;
    w5)  echo "(w5) a malformed run_not_before is REFUSED, naming the text" ;;
    w5d) echo "(w5d) a defers_to that is not a CO-S<N>-<descriptor> id is REFUSED, naming the text" ;;
    w6)  echo "(w6) --stories-dir EARLIEST-CLOSE is the max non-deferred window; a later deferred one does not count" ;;
    w6n) echo "(w6n) --stories-dir with no window prints EARLIEST-CLOSE none" ;;
  esac
}
rw_failset() { # <validator> -> space-separated arms that FAIL against it
  local a s=""
  for a in $RW_ARMS; do "rw_$a" "$1" || s="$s $a"; done
  printf '%s' "${s# }"
}

# RW_BASE records, per arm, that it PASSED against the unmutated subject in this run. A mutant is
# scored only when every arm it is declared to fail did so; otherwise its "kill" would be the
# seed failing (lib/mutant.sh, need_base).
RW_BASE=" "
for a in $RW_ARMS; do
  if "rw_$a" "$V"; then ok "$(rw_label "$a")"; RW_BASE="$RW_BASE$a "
  else bad "$(rw_label "$a") — rc/out: $(head -2 "$RW_ERR" | cut -c1-160)"; fi
done
rw_base_flag() { # <space-separated arms> -> 1 iff every one passed unmutated in this run
  local a
  for a in $1; do case "$RW_BASE" in *" $a "*) ;; *) echo 0; return ;; esac; done
  echo 1
}

# MUTANTS. Each is a copy of the validator in its own directory beside a copy of its floor
# sibling, built by an anchor that occurs ONCE. Per push a mutant runs its DECIDING arms (each
# must fail) and its TWINS (each must stay green), the cells the header's MUTANT-MATRIX rows
# record; --matrix drives it against every rw arm and prints the measured row instead. The
# unmutated copy in the same shape must fail NOTHING, so a copy that cannot run is not read as
# a kill.
rw_mut() { # <name> <anchor> <replacement> -> prints the mutant path, or nothing
  local d="$WORK/rwm-$1" n
  mkdir -p "$d" && cp "$V" "$d/validate-ac-falsifiability.sh" && cp "$RW_SIB" "$d/validate-spec-adoption.sh" || return 1
  [ -z "$2" ] && { printf '%s\n' "$d/validate-ac-falsifiability.sh"; return 0; }
  n="$(grep -cF -- "$2" "$V")" || n=0
  [ "$n" = 1 ] || { echo "FIXTURE ERROR: mutation '$1' anchor occurs $n times, expected 1" >&2; return 1; }
  awk -v A="$2" -v B="$3" '{ i = index($0, A); if (i) $0 = substr($0, 1, i-1) B substr($0, i+length(A)); print }' \
    "$V" > "$d/validate-ac-falsifiability.sh" || return 1
  cmp -s "$V" "$d/validate-ac-falsifiability.sh" && { echo "FIXTURE ERROR: mutation '$1' matched nothing" >&2; return 1; }
  bash -n "$d/validate-ac-falsifiability.sh" || { echo "FIXTURE ERROR: mutant '$1' is not valid shell" >&2; return 1; }
  printf '%s\n' "$d/validate-ac-falsifiability.sh"
}
rw_expect_kill() { # <name> <deciding arms> <twin arms> <anchor> <replacement> <what>
  local m a bf tr="" gr="" wrong=""
  m="$(rw_mut "$1" "$4" "$5")"
  [ -n "$m" ] || { bad "MUTATION '$1' could not be built — $6 is unproved"; return; }
  if [ "$MATRIX" = "1" ]; then
    for a in $RW_ARMS; do
      MX_FULL_RUNS=$((MX_FULL_RUNS + 1))
      if "rw_$a" "$m"; then gr="$gr,$a"; else tr="$tr,$a"; fi
    done
    a=yes; for d in $2; do case ",$tr," in *",$d,"*) ;; *) a=no ;; esac; done
    mx_row "$1" "$(printf '%s' "$2" | tr ' ' ',')" "$a" "${tr#,}" "${gr#,}"
    return
  fi
  for a in $2; do "rw_$a" "$m" && wrong="$wrong $a-did-not-flip"; done
  for a in $3; do "rw_$a" "$m" || wrong="$wrong $a-twin-not-green"; done
  bf="$(rw_base_flag "$2 $3")"
  if [ -z "$wrong" ]; then mutant_killed "$([ "$bf" = 1 ] && echo 1 || echo 0)" "$1" "MUTATION '$1' ($6) fails $2; twin $3 stays green"
  else bad "MUTATION '$1' ($6) scored [${wrong# }], wanted $2 failing and twin $3 green — re-measure with --matrix"; fi
}
# The unmutated copy, built the same way, must fail NO arm. It is not a kill, so it is not
# emitted through mutant_killed; it is what makes a silent mutant copy uninterpretable.
RW_CTL="$(rw_mut control "" "")"
if [ -n "$RW_CTL" ] && [ -z "$(rw_failset "$RW_CTL")" ]; then
  ok "CONTROL: an unmutated copy beside its floor sibling passes every clause (c) arm"
else
  bad "CONTROL: an unmutated copy beside its floor sibling failed arms '$( [ -n "$RW_CTL" ] && rw_failset "$RW_CTL")' — the mutant verdicts below are uninterpretable"
fi
rw_expect_kill defer-ignored "w2" "w1"  '[ "$w_def" = 1 ] && continue'           ':'                   "the defers_to exemption ignored"
rw_expect_kill cmp-inverted "w1 w3" "w2" '[[ "$w_rnb" > "$RW_CLOSE_RAW" ]]'       '[[ "$w_rnb" < "$RW_CLOSE_RAW" ]]' "the comparison inverted"
rw_expect_kill floor-ignored "w4" "w4b" 'if [ "$RW_STATE" != in-force ]; then'   'if false; then'      "the floor ignored"
rw_expect_kill earliest-counts-deferred "w6" "w6n" '[ "$w_def" = 0 ] || continue' ':'                   "the deferred window counted in EARLIEST-CLOSE"

if [ "$MATRIX" = "0" ]; then
  if [ "$MX_FULL_RUNS" -eq 0 ]; then ok "a plain run executed no matrix-only cell (MX_FULL_RUNS=0)"
  else bad "a plain run executed $MX_FULL_RUNS matrix-only cell(s)"; fi
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "check-31-ac-falsifiability: PASS"
else
  echo "check-31-ac-falsifiability: FAILED" >&2
fi
exit $rc
