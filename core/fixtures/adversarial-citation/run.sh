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
# Inherited AI_DLC_* tunables (e.g. AI_DLC_TRUNK) change what the seeded worlds and the validator resolve; scrub them so the run is the same under any caller environment. AI_DLC_SCRUB_PROBE is exported on the scrub line and arm SCRUB-RAN asserts it is gone after (BL-965): under hermetic-run.sh an undeclared `env` is command-not-found, the loop iterates zero times, and no other arm sees it.
export AI_DLC_SCRUB_PROBE=1; for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
SCRUB_RAN=0; [ -z "${AI_DLC_SCRUB_PROBE+x}" ] && SCRUB_RAN=1
unset CLAUDE_PROJECT_DIR
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-adversarial-convergence.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-adversarial-convergence.sh" \
  "$DIR/../../core/scripts/validate-adversarial-convergence.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FAIL: cannot locate validate-adversarial-convergence.sh from $DIR"; exit 1; }

ROOT="$(bash "$DIR/seed.sh" "$(cd "$(dirname "$VALIDATOR")" && pwd)" | tail -1)"
MEMO="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$MEMO"' EXIT
FAIL=0; N=0
N=$((N + 1))
if [ "$SCRUB_RAN" = 1 ]; then printf '  ok   %-38s the AI_DLC_* scrub unset its probe variable\n' "SCRUB-RAN"
else FAIL=$((FAIL + 1)); printf '  FAIL %-38s AI_DLC_SCRUB_PROBE survived the scrub -- env is unreachable and the scrub is a no-op\n' "SCRUB-RAN"; fi

# One validator invocation per distinct (validator, argv). Several assertions below ask
# DIFFERENT questions of the SAME run (exit code, stdout state, a stderr marker, a message
# substring); each used to pay its own invocation. The key is the validator path plus its full
# argv, so every assertion reads
# the real stdout/stderr/exit of a real run. Sets VC_OUT, VC_ERR, VC_RC.
vcall() {
  local k f line
  # The key is the argv joined by tabs, numbered by its position in an index file (no hashing tool
  # is declared for this fixture's sandbox, and an index cannot collide the way a checksum can).
  line="$(printf '%s\t' "$@")"
  k="$(grep -nFx -e "$line" "$MEMO/index" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -z "$k" ]; then printf '%s\n' "$line" >> "$MEMO/index"; k="$(wc -l < "$MEMO/index" | tr -d ' ')"; fi
  f="$MEMO/$k"
  if [ ! -f "$f.rc" ]; then
    [ -z "${AC_COUNT_FILE:-}" ] || echo "$line" >> "$AC_COUNT_FILE"
    bash "$@" >"$f.out" 2>"$f.err"; echo "$?" >"$f.rc"
  fi
  VC_OUT="$(cat "$f.out")"; VC_ERR="$(cat "$f.err")"; VC_RC="$(cat "$f.rc")"
}

# gate-mode exit-code assertion. $1 case  $2 want-exit  $3 why  $4 (optional) transcript basename
g() {
  local c="$1" want="$2" why="$3" t="${4:-}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out got
  vcall "$VALIDATOR" "${args[@]}"; out="$VC_OUT
$VC_ERR"; got=$VC_RC
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
  vcall "$VALIDATOR" --series "$ROOT/$c/s-adversarial-p" --transcript "$ROOT/$t"; out="$VC_OUT
$VC_ERR"
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
  vcall "$VALIDATOR" "${args[@]}"; out="$VC_OUT"; rc=$VC_RC
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
  vcall "$VALIDATOR" --series "$ROOT/$c/s-adversarial-p" --cycle-state; err="$VC_ERR"
  if grep -qF -- "$mark" <<<"$err"; then printf '  ok   %-30s logs %s\n' "$c" "$mark"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s did NOT log %s\n' "$c" "$mark"; fi
}

# --- corpus-aware helpers -------------------------------------------------------------------
# `g()`, `st()` and `says()` above take a single --transcript and NO directory. That is the
# whole reason an empty --transcript-dir reached the release surface unmeasured: not one arm
# in this file could EXPRESS a corpus, so the branch that ranks above the fail-open path had
# no reader. These three take a directory, a file, or both, plus an optional validator
# override.

# hook tier. $1 case  $2 dir-or-""  $3 transcript-or-""  $4 want-state  $5 want-rc  $6 why
# $7 optional validator override.
std() {
  local c="$1" d="$2" t="$3" ws="$4" wr="$5" why="$6" v="${7:-$VALIDATOR}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p" --cycle-state)
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out rc s
  vcall "$v" "${args[@]}"; out="$VC_OUT"; rc=$VC_RC
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
  vcall "$v" "${args[@]}"; err="$VC_ERR"
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
  vcall "$v" "${args[@]}"; out="$VC_OUT
$VC_ERR"; got=$VC_RC
  [ "$got" -eq "$want" ] || why="$why [exit=$got want=$want]"
  grep -qF -- "$yes" <<<"$out" || why="$why [missing: $yes]"
  grep -qF -- "$no"  <<<"$out" && why="$why [PRESENT but must not be: $no]"
  if [ -z "$why" ]; then printf '  ok   %-38s exit=%s, says absence not accusation\n' "$c/${d:-nodir}" "$got"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-38s%s\n' "$c/${d:-nodir}" "$why"; return 1; fi
}

echo "adversarial-citation proof (arm F6)"
# The candidate list above spans both install layouts and takes the first that EXISTS, so
# the file this unit loads is not necessarily the one an author just edited. Print it: a
# edit applied to the other copy leaves every arm green and reads exactly like an arm
# that cannot fire.
echo "adversarial-citation: resolved subject = $(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"
# The REQUIRED input of inputs.decl: the validator under test, resolved above and driven by every
# assertion below. Unconditional: a sentinel guarded by a file test would print the declared name
# whether or not the verdict depended on it.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$VALIDATOR")" && pwd -P)/$(basename "$VALIDATOR")"
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
# not. These two arms return DIVERGENT/3 against the pre-fix predicate.
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
# into rc 0 for exactly that caller. These are the arms that catch it.
echo "  -- BOTH flags: the fallthrough must reach the named file, not the fail-open path --"
std terminal dir-empty silent.jsonl DIVERGENT 3 "empty dir + a forgery -> falls through to the file and DENIES"
std terminal dir-empty real.jsonl   RESOLVED  0 "empty dir + the genuine turn -> falls through and RESOLVES"

# (i) THE GATE TIER of the same case. Both states fail CLOSED at 1 -- that posture is settled
# and is not the defect -- so the exit code cannot tell them apart. The MESSAGE can, and
# reporting the operator as having said nothing when the true state is "no corpus" is an
# accusation the gate has no evidence for.
gd resolved dir-empty 1 "no readable transcript was provided" "appears in NO genuine"

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

# --- BL-923: the gate-only arms K2, K3 and L, each on its own seeded world --------------------------
# seed.sh builds six stamped git repositories (an ACCEPT and a REFUSE twin per arm, one property apart)
# and drops `bl923-built` only when all six built. Each world is driven with `--arms <its arm>`, so a
# line in its output is that arm's alone. SIX CELLS, every one presence- or shape-asserted:
#   k2-accept  rc 0, `PASS: the cycle converged`, no `K2 -- SECTIONS` token (K2 prints nothing on accept)
#   k2-refuse  `FAIL (K2 -- SECTIONS):`
#   k3-accept  rc 0, `PASS: the cycle converged`, no `K3 -- SUBJECT` token
#   k3-refuse  `FAIL (K3 -- SUBJECT):`
#   l-accept   rc 0, `OK (L -- ELICITATION)`, no `PENDING (L` and no `FAIL (L`
#   l-refuse   `FAIL (L -- ELICITATION)`
# A PENDING on any of them fails its cell: accept cells refuse the arm's token (K2/K3) or require the
# OK line (L), and refuse cells require the FAIL line. The FALLBACK (K2/K3 partitioner) lines this
# distribution layout prints are expected and are not suppressed.
echo
echo "  -- BL-923: arms K2, K3 and L reach their own verdicts on seeded worlds --"
BL_WORLDS="k2-accept:K2:prd-adversarial-p k2-refuse:K2:prd-adversarial-p k3-accept:K3:_bmad-output/planning-artifacts/s9/requirements-adversarial-p k3-refuse:K3:_bmad-output/planning-artifacts/s9/requirements-adversarial-p l-accept:L:s9/stories-adversarial-p l-refuse:L:s9/stories-adversarial-p"
BL_CELLS=""
bl_cells() {  # $1 validator -> BL_CELLS, one 1/0 per world in BL_WORLDS order
  local v="$1" c="" e wn arm stem tok o
  for e in $BL_WORLDS; do
    wn="${e%%:*}"; arm="${e#*:}"; stem="${arm#*:}"; arm="${arm%%:*}"
    vcall "$v" --series "$ROOT/$wn/$stem" --transcript "$ROOT/silent.jsonl" --arms "$arm"
    o="$VC_OUT
$VC_ERR"
    case "$arm" in K2) tok="K2 -- SECTIONS" ;; K3) tok="K3 -- SUBJECT" ;; *) tok="L -- ELICITATION" ;; esac
    case "$wn" in
      l-accept)
        if [ "$VC_RC" -eq 0 ] && grep -qF -- "OK ($tok)" <<<"$o" && ! grep -qF -- "PENDING (L" <<<"$o" && ! grep -qF -- "FAIL (L" <<<"$o"; then c="${c}1"; else c="${c}0"; fi ;;
      *-accept)
        if [ "$VC_RC" -eq 0 ] && grep -qF -- "PASS: the cycle converged" <<<"$o" && ! grep -qF -- "$tok" <<<"$o"; then c="${c}1"; else c="${c}0"; fi ;;
      *)
        if grep -qF -- "FAIL ($tok)" <<<"$o"; then c="${c}1"; else c="${c}0"; fi ;;
    esac
  done
  BL_CELLS="$c"
}
N=$((N + 1))
if [ ! -f "$ROOT/bl923-built" ]; then
  FAIL=$((FAIL + 1))
  printf '  FAIL %-38s FIXTURE BROKEN: seed.sh did not build the six BL-923 worlds under %s\n' "bl923-worlds" "$ROOT"
  BL_BASE=000000
else
  printf '  ok   %-38s six stamped worlds built\n' "bl923-worlds"
  bl_cells "$VALIDATOR"; BL_BASE="$BL_CELLS"
fi
i=0
for bl_lb in bl923-k2-accept bl923-k2-refuse bl923-k3-accept bl923-k3-refuse bl923-l-accept bl923-l-refuse; do
  nm="${bl_lb#bl923-}"; i=$((i + 1)); N=$((N + 1))
  if [ "$(printf '%s' "$BL_BASE" | cut -c"$i")" = 1 ]; then printf '  ok   %-38s its arm'"'"'s own verdict\n' "bl923-$nm"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-38s its arm did not print its own verdict (cells=%s)\n' "bl923-$nm" "$BL_BASE"
    e="$(printf '%s\n' $BL_WORLDS | sed -n "${i}p")"; a="${e#*:}"
    vcall "$VALIDATOR" --series "$ROOT/${e%%:*}/${a#*:}" --transcript "$ROOT/silent.jsonl" --arms "${a%%:*}"
    printf '%s\n%s\n' "$VC_OUT" "$VC_ERR" | sed 's/^/       | /'
  fi
done

echo
if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL of $N assertions wrong."
  exit 1
fi
echo "PASS: all $N assertions correct."
exit 0
