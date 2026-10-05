#!/usr/bin/env bash
# Proof for the operator-CITATION gate (validate-adversarial-convergence.sh arm F6). v0.61.0.
#
# THE 3-STEP PROOF (this repo's discipline: a new check must be shown to pass vacuously, fail
# on the real defect, and pass once the defect is fixed -- a green run otherwise proves only
# that the check cannot fire):
#
#   (a) VACUOUS   a converging cycle never reaches the citation gate     -> PASS
#   (b) FAIL      the S290 shape: a resolution citing words absent from
#                 an operator-silent transcript                          -> FAIL CLOSED
#   (c) PASS      the same series with a genuine operator turn present    -> PASS
#
# Plus two things a bare 3-step proof would miss:
#   (d) GUARD     the quoted span exists only inside a tool_result -- the classifier reuse
#                 (not a naive grep of the file) is load-bearing          -> FAIL
#   (e) TWO-TIER  the hook fails OPEN on a missing transcript (never wedge) but LOGS it; the
#                 gate fails CLOSED. And when a transcript IS present, the hook denies a
#                 fabricated citation too.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-adversarial-convergence.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-adversarial-convergence.sh" \
  "$DIR/../../core/scripts/validate-adversarial-convergence.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FAIL: cannot locate validate-adversarial-convergence.sh from $DIR"; exit 1; }

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT
FAIL=0; N=0

# gate-mode exit-code assertion. $1 case  $2 want-exit  $3 why  $4 (optional) transcript basename
g() {
  local c="$1" want="$2" why="$3" t="${4:-}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out got
  out="$(bash "$VALIDATOR" "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ok   %-30s exit=%s  (%s)\n' "$c/${t:-none}" "$got" "$why"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %-30s exit=%s want=%s  (%s)\n' "$c/${t:-none}" "$got" "$want" "$why"
    printf '%s\n' "$out" | sed 's/^/       | /'
  fi
}

# message assertion. $1 case  $2 transcript  $3... required substrings
says() {
  local c="$1" t="$2"; shift 2; N=$((N + 1))
  local out miss=""
  out="$(bash "$VALIDATOR" --series "$ROOT/$c/s-adversarial-p" --transcript "$ROOT/$t" 2>&1)"
  local w; for w in "$@"; do grep -qF -- "$w" <<<"$out" || miss="$miss [$w]"; done
  if [ -z "$miss" ]; then printf '  ok   %-30s message names the cause\n' "$c(msg)"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s missing:%s\n' "$c(msg)" "$miss"; fi
}

# cycle-state (hook) assertion. $1 case  $2 want-state  $3 want-rc  $4 why  $5 (optional) transcript
st() {
  local c="$1" ws="$2" wr="$3" why="$4" t="${5:-}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p" --cycle-state)
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out rc s
  out="$(bash "$VALIDATOR" "${args[@]}" 2>/dev/null)"; rc=$?
  s="$(printf '%s' "$out" | cut -f1)"
  if [ "$s" = "$ws" ] && [ "$rc" -eq "$wr" ]; then
    printf '  ok   %-30s %s/%s  (%s)\n' "$c/${t:-none}" "$s" "$rc" "$why"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %-30s %s/%s want=%s/%s  (%s)\n' "$c/${t:-none}" "${s:-<none>}" "$rc" "$ws" "$wr" "$why"
  fi
}

# stderr-marker assertion: the fail-open path must LEAVE A TRACE, or a silent fail-open is
# indistinguishable from a verified pass -- the exact defect class this whole change is about.
logs() {
  local c="$1" mark="$2"; N=$((N + 1))
  local err
  err="$(bash "$VALIDATOR" --series "$ROOT/$c/s-adversarial-p" --cycle-state 2>&1 >/dev/null)"
  if grep -qF -- "$mark" <<<"$err"; then printf '  ok   %-30s logs %s\n' "$c" "$mark"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s did NOT log %s\n' "$c" "$mark"; fi
}

# --- corpus-aware helpers -------------------------------------------------------------------
# `g()`, `st()` and `says()` above take a single --transcript and NO directory. That is the
# whole reason an empty --transcript-dir reached the release surface unmeasured: not one arm
# in this file could EXPRESS a corpus, so the branch that ranks above the fail-open path had
# no reader. These three take a directory, a file, or both, plus an optional validator
# override so the mutants at the bottom reuse exactly these assertions.

# hook tier. $1 case  $2 dir-or-""  $3 transcript-or-""  $4 want-state  $5 want-rc  $6 why
# $7 optional validator override.
std() {
  local c="$1" d="$2" t="$3" ws="$4" wr="$5" why="$6" v="${7:-$VALIDATOR}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p" --cycle-state)
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out rc s
  out="$(bash "$v" "${args[@]}" 2>/dev/null)"; rc=$?
  s="$(printf '%s' "$out" | cut -f1)"
  if [ "$s" = "$ws" ] && [ "$rc" -eq "$wr" ]; then
    printf '  ok   %-38s %s/%s  (%s)\n' "$c/${d:-nodir}/${t:-nofile}" "$s" "$rc" "$why"; return 0
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %-38s %s/%s want=%s/%s  (%s)\n' "$c/${d:-nodir}/${t:-nofile}" "${s:-<none>}" "$rc" "$ws" "$wr" "$why"
    return 1
  fi
}

# hook tier, stderr marker, with a corpus. The fail-open path must LEAVE A TRACE: an empty
# corpus that quietly allows is indistinguishable from a corpus that verified.
logsd() {
  local c="$1" d="$2" mark="$3" v="${4:-$VALIDATOR}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p" --cycle-state)
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  local err
  err="$(bash "$v" "${args[@]}" 2>&1 >/dev/null)"
  if grep -qF -- "$mark" <<<"$err"; then printf '  ok   %-38s logs %s\n' "$c/${d:-nodir}" "$mark"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-38s did NOT log %s\n' "$c/${d:-nodir}" "$mark"; return 1; fi
}

# gate tier, with a corpus, MESSAGE-shaped. Exit code alone cannot separate "there was no
# corpus" from "the operator never said this" -- both fail CLOSED at 1 by design, and that
# posture is correct. What separates them is WHICH sentence the gate prints, so this asserts
# a required substring AND a forbidden one. $1 case $2 dir $3 want-exit $4 must-appear
# $5 must-NOT-appear  $6 optional validator override.
gd() {
  local c="$1" d="$2" want="$3" yes="$4" no="$5" v="${6:-$VALIDATOR}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p")
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  local out got why=""
  out="$(bash "$v" "${args[@]}" 2>&1)"; got=$?
  [ "$got" -eq "$want" ] || why="$why [exit=$got want=$want]"
  grep -qF -- "$yes" <<<"$out" || why="$why [missing: $yes]"
  grep -qF -- "$no"  <<<"$out" && why="$why [PRESENT but must not be: $no]"
  if [ -z "$why" ]; then printf '  ok   %-38s exit=%s, says absence not accusation\n' "$c/${d:-nodir}" "$got"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-38s%s\n' "$c/${d:-nodir}" "$why"; return 1; fi
}

echo "adversarial-citation proof (arm F6)"
# The candidate list above spans both install layouts and takes the first that EXISTS, so
# the file this unit loads is not necessarily the one an author just edited. Print it: a
# mutant applied to the other copy leaves every arm green and reads exactly like an arm
# that cannot fire.
echo "adversarial-citation: resolved subject = $(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"
echo

# (a) VACUOUS -----------------------------------------------------------------------------
g clean 0 "no divergence: citation gate dormant" silent.jsonl

# (b) FAIL (the S290 shape) ----------------------------------------------------------------
g    resolved 1 "cited words absent from an operator-silent transcript -> FAIL CLOSED" silent.jsonl
says resolved silent.jsonl "appears in NO genuine" "operator did not say this"

# (c) PASS --------------------------------------------------------------------------------
g resolved 0 "cited words verbatim in a genuine operator turn -> PASS" real.jsonl

# (d) GUARD: classifier reuse, not a naive grep -------------------------------------------
g resolved 1 "phrase only inside a tool_result -> classifier rejects -> FAIL" toolresult.jsonl

# (e) TWO-TIER ----------------------------------------------------------------------------
# hook, transcript present: a fabricated citation is denied at the hook too (not just the gate)
st terminal DIVERGENT 3 "hook denies: NOMATCH -> not RESOLVED" silent.jsonl
st terminal RESOLVED  0 "hook allows: real citation -> RESOLVED"   real.jsonl
# hook, no transcript: fail OPEN (never wedge the pipeline) but LOG the gap
st   terminal RESOLVED 0 "fail-open: no transcript -> allow"
logs terminal ADVERSARIAL_CITATION_UNVERIFIABLE
# gate, no transcript: fail CLOSED
g    resolved 1 "gate fail-closed: no transcript to verify against"

# (f) AN EMPTY CORPUS IS ABSENT GROUND TRUTH, NOT A FORGERY ---------------------------------
# `--transcript-dir` was tested for EXISTENCE only, never for CONTENT, so an empty corpus
# outranked the fail-open branch below it and DENIED every dispatch at rc 3 -- while passing
# NO flag at all allowed it at rc 0. Passing the flag wedged the pipeline; passing nothing did
# not. These two arms return DIVERGENT/3 against the pre-fix predicate, and the mutant at the
# bottom of this file is what holds that true rather than my word for it.
echo
echo "  -- an EMPTY corpus is ABSENT ground truth, not a forgery --"
std   terminal dir-empty   "" RESOLVED 0 "empty corpus -> fail OPEN at the hook, exactly as no flag does"
logsd terminal dir-empty      ADVERSARIAL_CITATION_UNVERIFIABLE
# The reader selects `*.jsonl` and only those (`validate-steering-budget.sh:427`), so a
# directory of sidecar files is exactly as blind as an empty one. This is the WIDER trigger:
# a narrowing keyed on `ls -A` being empty passes the arm above and fails this one.
std   terminal dir-sidecar "" RESOLVED 0 "sidecar-only corpus -> nothing the reader would open, so still absent"
logsd terminal dir-sidecar    ADVERSARIAL_CITATION_UNVERIFIABLE

# (g) THE TEETH. Fail-open on an EMPTY corpus must not widen into fail-open on a corpus.
# Without these two, deleting the citation check, neutering it, or making the --dir branch
# unreachable all make (f) pass -- the battery would inherit the blindness it exists to fix.
echo "  -- ...and a corpus that HOLDS something is still adjudicated --"
std terminal dir-silent "" DIVERGENT 3 "a corpus holding the S290 fabrication still DENIES"
std terminal dir-real   "" RESOLVED  0 "a corpus holding the genuine turn RESOLVES through the --dir branch"

# (h) THE WRONG FIX SHAPE. `steps/gate-validation.md` instructs the operator to pass BOTH
# flags. A narrowing applied AFTER the if/elif chain -- clearing STEER_FLAG once the dir
# branch has already set it -- skips the `-r "$TRANSCRIPT"` fallback entirely and turns rc 3
# into rc 0 for exactly that caller. These are the arms that catch it; mutant W below is the
# proof they can.
echo "  -- BOTH flags: the fallthrough must reach the named file, not the fail-open path --"
std terminal dir-empty silent.jsonl DIVERGENT 3 "empty dir + a forgery -> falls through to the file and DENIES"
std terminal dir-empty real.jsonl   RESOLVED  0 "empty dir + the genuine turn -> falls through and RESOLVES"

# (i) THE GATE TIER of the same case. Both states fail CLOSED at 1 -- that posture is settled
# and is not the defect -- so the exit code cannot tell them apart. The MESSAGE can, and
# reporting the operator as having said nothing when the true state is "no corpus" is an
# accusation the gate has no evidence for.
gd resolved dir-empty 1 "no readable transcript was provided" "appears in NO genuine"

# --- mutants --------------------------------------------------------------------------------
# COPIES, guarded by `cmp -s` so a sed that matched nothing cannot pass as a mutation, and by
# `bash -n` so a mutant that is no longer a program cannot score its silence as a kill. The
# validator resolves its steering sibling from `dirname "$0"` (:120), so BOTH files are
# copied -- a lone copy dies with "no validator", fails OPEN at the hook tier, and that
# fail-open would be read as the mutant working.
echo
MWORK="$(mktemp -d)"; trap 'rm -rf "$ROOT" "$MWORK"' EXIT
SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
cp "$SRC_DIR/validate-steering-budget.sh" "$MWORK/" 2>/dev/null \
  || { echo "  FAIL mutants: cannot copy the steering sibling from $SRC_DIR"; FAIL=$((FAIL + 1)); }
cp "$VALIDATOR" "$MWORK/control.sh"
KILLS=0

mutate() {  # mutate <name> <sed-expr>  -> prints the mutant path
  local name="$1" expr="$2"
  cp "$VALIDATOR" "$MWORK/m-$name.sh" || { echo "  FAIL mutant $name: copy failed"; return 1; }
  sed -i.bak "$expr" "$MWORK/m-$name.sh" && rm -f "$MWORK/m-$name.sh.bak"
  if cmp -s "$VALIDATOR" "$MWORK/m-$name.sh"; then
    echo "  FAIL mutant $name changed no bytes -- its sed matched nothing and would score as a kill"; return 1
  fi
  bash -n "$MWORK/m-$name.sh" || { echo "  FAIL mutant $name does not parse; its silence would score as a kill"; return 1; }
  printf '%s\n' "$MWORK/m-$name.sh"
}

# THE UNMUTATED CONTROL, from the same directory, and it is NECESSARY AND NOT SUFFICIENT: a
# control asserting only "nothing went wrong" passes against a subject replaced by `exit 0`.
# Every arm here is PRESENCE-shaped -- a named STATE must appear on stdout -- so a copy that
# emits nothing fails them by construction rather than by intention.
echo "  -- unmutated control copy --"
std terminal dir-empty  "" RESOLVED  0 "control reproduces the empty-corpus fail-open" "$MWORK/control.sh"
std terminal dir-silent "" DIVERGENT 3 "control reproduces the corpus deny"            "$MWORK/control.sh"
std terminal dir-real   "" RESOLVED  0 "control reproduces the corpus allow"           "$MWORK/control.sh"

# MUTANT R -- the narrowing REVERTED to the shipped-defect predicate, byte for byte. This is
# the one mutant that reproduces the wedge, and (f) is red against it in both shapes.
echo "  -- mutant R: the pre-fix predicate restored (expect the empty-corpus arms to go red) --"
MR="$(mutate revert-existence-only 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@[ -n "$TRANSCRIPT_DIR" ] \&\& [ -d "$TRANSCRIPT_DIR" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MR:-}" ]; then
  std terminal dir-empty   "" DIVERGENT 3 "R: an empty corpus DENIES -- the shipped wedge, reproduced" "$MR" && KILLS=$((KILLS + 1))
  std terminal dir-sidecar "" DIVERGENT 3 "R: a sidecar-only corpus DENIES too"                        "$MR" && KILLS=$((KILLS + 1))
  # ...and nothing else moves. A mutant that fails more than its own assertions means the
  # arms are entangled and one of them is vacuous.
  std terminal dir-silent  "" DIVERGENT 3 "R: the corpus deny is UNCHANGED"  "$MR"
  std terminal dir-real    "" RESOLVED  0 "R: the corpus allow is UNCHANGED" "$MR"
  std terminal dir-empty silent.jsonl DIVERGENT 3 "R: both flags still DENY -- pre-fix kept its teeth here" "$MR"
fi

# MUTANT W -- the WRONG FIX SHAPE the entry's own prose lists as a legitimate option: the
# existence-only predicate back at the head of the chain, and the narrowing moved BELOW it as
# a clearing of STEER_FLAG. It fixes the empty-corpus wedge and silently loses the deny for a
# caller passing both flags, which is the caller `steps/gate-validation.md` creates.
echo "  -- mutant W: the narrowing moved below the chain (expect ONLY the both-flags deny to go red) --"
MW="$(mutate clear-after-chain 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@[ -n "$TRANSCRIPT_DIR" ] \&\& [ -d "$TRANSCRIPT_DIR" ]; then@; s@^  if \[ -z "\$STEER_FLAG" \]; then@  [ "$STEER_FLAG" = "--dir" ] \&\& ! steer_dir_has_transcript "$STEER_ARG" \&\& { STEER_FLAG=""; STEER_ARG=""; }; if [ -z "$STEER_FLAG" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MW:-}" ]; then
  std terminal dir-empty silent.jsonl RESOLVED 0 "W: both flags, empty dir + a FORGERY -> ALLOWED. The teeth are gone." "$MW" && KILLS=$((KILLS + 1))
  # W is a plausible fix everywhere else, which is exactly why it is dangerous: every other
  # arm in this file stays green against it.
  std terminal dir-empty   "" RESOLVED  0 "W: the empty-corpus wedge is fixed (that is why it looks like a fix)" "$MW"
  std terminal dir-silent  "" DIVERGENT 3 "W: the corpus deny is UNCHANGED"  "$MW"
  std terminal dir-real    "" RESOLVED  0 "W: the corpus allow is UNCHANGED" "$MW"
fi

# --- the citation FLOOR is measured on the NORMALISED needle --------------------------------
# The caller compared bash `${#auth_quote}` against 12 while `--cite` collapses whitespace and
# trims, so a padded `"          yes"` and twelve spaces verified against ANY in-window operator
# turn. dir-yes holds the consumer's own free-typed `1. Yes.\n2. Yes.` in its SECOND member, so
# the pre-fix build MATCHES both, and the whole-quote series is the ALLOW twin over that corpus.
#
# SIX CELLS, ONE STRING:
#   P  gate, padded   -> rc 1, "(3 chars once whitespace is collapsed)"
#   Q  gate, blank    -> rc 1, "(0 chars once whitespace is collapsed)"
#   R  gate, whole    -> rc 0
#   p  hook, padded   -> DIVERGENT/3
#   q  hook, blank    -> DIVERGENT/3
#   r  hook, whole    -> RESOLVED/0
# Every cell is presence-shaped: a named state or message must APPEAR.
echo
echo "  -- the citation floor is measured on the NORMALISED needle --"
FL_SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
FL_BASE="$(basename "$VALIDATOR")"
echo "  adversarial-citation: resolved predicate = $FL_SRC_DIR/validate-steering-budget.sh"
FL_FIRST="$(node -e 'const fs=require("fs");console.log(fs.readdirSync(process.argv[1]).filter(f=>f.endsWith(".jsonl"))[0]||"")' "$ROOT/dir-yes" 2>/dev/null)"
N=$((N + 1))
if [ -n "$FL_FIRST" ] && [ "$FL_FIRST" != "b-incident.jsonl" ]; then
  printf '  ok   %-38s the reader opens %s first; the incident turn is in the second member\n' "dir-yes" "$FL_FIRST"
else
  FAIL=$((FAIL + 1)); printf '  FAIL %-38s FIXTURE BROKEN: first member read is "%s"\n' "dir-yes" "$FL_FIRST"
fi
FL_CELLS=""
fl_cells() {  # $1 validator -> FL_CELLS
  local v="$1" c="" n o rc s
  for n in padded blank; do
    o="$(bash "$v" --series "$ROOT/resolved-$n/s-adversarial-p" --transcript-dir "$ROOT/dir-yes" 2>&1)"; rc=$?
    case "$n" in padded) s="(3 chars once whitespace is collapsed)" ;; *) s="(0 chars once whitespace is collapsed)" ;; esac
    if [ "$rc" -eq 1 ] && grep -qF -- "$s" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  done
  bash "$v" --series "$ROOT/resolved-whole/s-adversarial-p" --transcript-dir "$ROOT/dir-yes" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ]; then c="${c}1"; else c="${c}0"; fi
  for n in padded:DIVERGENT:3 blank:DIVERGENT:3 whole:RESOLVED:0; do
    o="$(bash "$v" --series "$ROOT/terminal-${n%%:*}/s-adversarial-p" --cycle-state --transcript-dir "$ROOT/dir-yes" 2>/dev/null)"; rc=$?
    s="$(printf '%s' "$o" | cut -f1)"
    n="${n#*:}"
    if [ "$s" = "${n%%:*}" ] && [ "$rc" -eq "${n#*:}" ]; then c="${c}1"; else c="${c}0"; fi
  done
  FL_CELLS="$c"
}
fl_names="P:gate-padded Q:gate-blank R:gate-whole p:hook-padded q:hook-blank r:hook-whole"
fl_cells "$VALIDATOR"
i=0
for nm in $fl_names; do
  i=$((i + 1)); N=$((N + 1))
  if [ "$(printf '%s' "$FL_CELLS" | cut -c"$i")" = "1" ]; then printf '  ok   %-38s floor cell %s holds\n' "${nm#*:}" "${nm%%:*}"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-38s floor cell %s does not hold (cells=%s)\n' "${nm#*:}" "${nm%%:*}" "$FL_CELLS"; fi
done

# --- floor mutants, each in a copy of the WHOLE scripts dir ------------------------------------
# The validator resolves its predicate beside itself; a copy without it fails OPEN at the hook and
# that would read as a mutant working. The unmutated copy must score all six cells first.
FL_MW="$(mktemp -d)"; trap 'rm -rf "$ROOT" "$MWORK" "$FL_MW"' EXIT
FL_WHY=""
fl_mk() {  # $1 name  then pairs of <target basename> <anchor> <replacement> -> FL_DIR
  local d="$FL_MW/$1" n t
  FL_DIR=""
  shift
  cp -R "$FL_SRC_DIR" "$d" || { FL_WHY="could not copy $FL_SRC_DIR"; return 1; }
  [ -f "$d/validate-steering-budget.sh" ] && [ -f "$d/$FL_BASE" ] || { FL_WHY="the copy lacks the validator or its predicate"; return 1; }
  while [ "$#" -ge 3 ]; do
    t="$1"
    n="$(grep -cF -- "$2" "$FL_SRC_DIR/$t")" || n=0
    [ "$n" -eq 1 ] || { FL_WHY="anchor matches $n line(s) in $t, not 1 -- re-anchor it, never relax the arm"; return 1; }
    A="$2" R="$3" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$FL_SRC_DIR/$t" > "$d/$t" || { FL_WHY="awk died"; return 1; }
    cmp -s "$FL_SRC_DIR/$t" "$d/$t" && { FL_WHY="changed no bytes in $t -- it would score as a kill"; return 1; }
    bash -n "$d/$t" 2>/dev/null || { FL_WHY="$t does not parse"; return 1; }
    shift 3
  done
  FL_DIR="$d"
}
fl_score() {  # $1 label  $2 expected cells  $3 name  [<target> <anchor> <replacement>]...
  local label="$1" want="$2"
  shift 2
  N=$((N + 1))
  if ! fl_mk "$@"; then FAIL=$((FAIL + 1)); printf '  FAIL %-38s DID NOT APPLY: %s\n' "$label" "$FL_WHY"; return 1; fi
  fl_cells "$FL_DIR/$FL_BASE"
  if [ "$FL_CELLS" = "$want" ]; then printf '  ok   %-38s %s -> %s\n' "$label" "$want" "$FL_CELLS"; [ "$want" != 111111 ] && KILLS=$((KILLS + 1)); return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-38s scored %s, wanted %s\n' "$label" "$FL_CELLS" "$want"; return 1; fi
}
FL_M2_A='  auth_nquote="$(cite_norm "$auth_quote")"'
FL_M2_R='  auth_nquote="$auth_quote"'
FL_M1_A='  if (needle.length < CITE_MIN_NORM_CHARS) {'
fl_score "F-control" 111111 ctl
# m2: this caller measures the bash length again. The predicate still refuses the short needle
# (NOMATCH-SHORT), so the verdicts hold and ONLY the gate's normalised-length message is lost.
fl_score "F-m2 caller raw length" 001111 m2 "$FL_BASE" "$FL_M2_A" "$FL_M2_R"
# m1: the predicate's floor removed. The caller refuses on the normalised length before asking,
# so NOTHING here moves -- this is the defence in depth, and it is asserted, not assumed.
fl_score "F-m1 floor removed (caller holds)" 111111 m1 validate-steering-budget.sh "$FL_M1_A" '  if (false) {'
# m1+m2: EVERY layer reverted, which is the shipped defect. Padded and blank now verify at both
# tiers; the whole-quote twin is unmoved.
fl_score "F-m1+m2 both layers reverted" 001001 m12 "$FL_BASE" "$FL_M2_A" "$FL_M2_R" \
  validate-steering-budget.sh "$FL_M1_A" '  if (false) {'

# KILL COUNT. A mutation that applied cleanly to a file the run never loaded reads exactly
# like an arm that cannot fire, and `cmp -s` cannot tell them apart. Zero kills is that state.
N=$((N + 1))
if [ "$KILLS" -ge 4 ]; then printf '  ok   %-38s %s mutant kill(s) -- the arms above can fire\n' "KILL-COUNT" "$KILLS"
else FAIL=$((FAIL + 1)); printf '  FAIL %-38s %s kill(s); the mutants changed bytes in a file these arms never loaded\n' "KILL-COUNT" "$KILLS"; fi

echo
if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL of $N assertions wrong."
  exit 1
fi
echo "PASS: all $N assertions correct."
exit 0
