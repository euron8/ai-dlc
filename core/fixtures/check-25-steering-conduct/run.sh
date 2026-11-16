#!/usr/bin/env bash
#
# Exercise validate-steering-budget.sh against the check-25 fixture.
#
# Check 25 does not ask the validator's own question ("any violations?"). It asks
# "how many, versus last gate?" -- so this fixture asserts the INTEGER that
# `--count` returns, not merely the exit status. A check-25 that only asserted
# PASS/FAIL would pass with a broken count, and the count is the whole mechanism.
#
# The decoy that decides shippability is `backgrounded`: it must return 0. A naive
# "any long call is starvation" implementation fails it, and would flag the exact
# background-dispatch shape Rule 29 prescribes -- an unpassable check, and an
# unpassable check gets turned off.
set -u
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-steering-budget.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-steering-budget.sh" \
  "$DIR/../../core/scripts/validate-steering-budget.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FAIL: cannot locate validate-steering-budget.sh from $DIR"
  exit 1
fi

# The RESOLVED subject. This fixture names candidates in both install layouts and
# takes the first that exists. Print what was actually loaded.
printf 'subject: %s\n' "$VALIDATOR"

command -v node >/dev/null 2>&1 || { echo "FIXTURE BROKEN: node is required for check-25"; exit 2; }

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT
# The REQUIRED input of inputs.decl: seed.sh has built the corpus and every assertion below
# drives this file, so this is the point the declaration is consumed.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$VALIDATOR")" && pwd -P)/$(basename "$VALIDATOR")"

# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# IN PROCESS (BL-878). The validator is SOURCED once (its column-0 guard returns after defining sb_main) and every
# drive below calls sb_main through sbv in a subshell, so the validator's own `exit`, `set -u` and its variables
# (it assigns DIR, TRANSCRIPT, COUNT) stay in that subshell and never reach this shell.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped validator, and
# sourcing a pre-wrap one would run its argument loop and `exit` in this shell. So the shape is checked first, on its
# two halves: neither the `sb_main() {` line nor the column-0 source guard is a subject that predates the wrap, which
# prints SKIP and exits 0 -- never an ok. Exactly one half is a respelled subject this fixture can no longer drive,
# which FAILS. An unreadable subject is FIXTURE ERROR.
sb_def=0; sb_guard=0
grep -q '^sb_main() {$' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || sb_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || sb_guard=1
if [ "$sb_def$sb_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$sb_def" = 0 ]; then echo "FAIL: $VALIDATOR carries the column-0 source guard but no \`sb_main() {\` line -- a respelled subject this fixture cannot drive"; exit 1; fi
if [ "$sb_guard" = 0 ]; then echo "FAIL: $VALIDATOR defines \`sb_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run sb_main in this shell"; exit 1; fi
fx_inproc "$VALIDATOR"
. "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR failed" >&2; exit 2; }
declare -F sb_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined no sb_main" >&2; exit 2; }
sbv() { fx_inproc "$VALIDATOR"; ( sb_main "$@" ); }

FAILURES=0

expect_count() { # $1 case-dir  $2 expected count  $3 why  [$4 a count already read from one run]
  local got
  got="${4-$(sbv --transcript "$ROOT/$1/session.jsonl" --count 2>/dev/null)}"
  if [ "$got" != "$2" ]; then
    echo "FAIL [$1]: --count returned '$got', expected '$2' -- $3"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: count=$got  ($3)"
  fi
}

expect_status() { # $1 case-dir  $2 expected exit  $3 why
  sbv --transcript "$ROOT/$1/session.jsonl" --quiet >/dev/null 2>&1
  local rc=$?
  if [ "$rc" != "$2" ]; then
    echo "FAIL [$1]: exit $rc, expected $2 -- $3"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: exit=$rc  ($3)"
  fi
}

# ONE `--count` run over `starves` feeds BOTH the count arm and the contract arm below: they
# were two identical invocations of the same command on the same transcript, the contract arm
# merely adding the exit status. `rc=$?` is appended inside the substitution so the status
# survives, which is the only thing the second run bought.
raw="$(sbv --transcript "$ROOT/starves/session.jsonl" --count 2>/dev/null; echo "rc=$?")"
rawcount="${raw%%rc=*}"; rawcount="${rawcount%$'\n'}"
expect_count starves      1 "an unbounded foreground poll loop is one Check A starvation" "$rawcount"
expect_count clean        0 "a bounded beat through wait-for-deliverable.sh starves nobody"
expect_count backgrounded 0 "DECOY: run_in_background yields a tool boundary at once -- not starvation"

expect_status starves      1 "the validator itself must still FAIL on the starving session"
expect_status clean        0 "and PASS on the clean one"
expect_status backgrounded 0 "and PASS on the backgrounded decoy"

# --count must be a pure integer on stdout and exit 0 even when violations exist --
# Check 25 reads it directly, and a `cmd | grep` would take grep's exit status.
case "$raw" in
  "1"*"rc=0") echo "ok   [contract]: --count prints a bare integer and exits 0 despite violations" ;;
  *) echo "FAIL [contract]: --count must print a bare integer and exit 0; got: $raw"
     FAILURES=$((FAILURES + 1)) ;;
esac

# ---------------------------------------------------------------------------
# IDENTITY -- a COUNT is not PROVENANCE.
#
# The arms above are structurally blind to this: they assert --count integers and
# exit statuses only, and the status arm passes --quiet, which suppresses the
# entire evidence block. `--transcript` and `--dir` are free caller-supplied paths
# bound to nothing, so two runs over two DIFFERENT corpora holding identical
# content produced BYTE-IDENTICAL output -- a wrong-session run was
# indistinguishable from a correct one, on the validator whose whole job is to be
# ground truth about what the operator said.
#
# THE ASSERTION IS DISCRIMINATION, NOT PRESENCE. A presence arm on the literal
# string `transcripts read` closes on a hardcoded constant that reads nothing. So:
# two corpora in two `mktemp -d` roots, IDENTICAL content under IDENTICALLY-NAMED
# members, and the requirement that the two outputs DIFFER, that each names its
# own root, and that NEITHER names the other. The roots are random, which makes a
# hardcoded literal unconstructible.
CORPA="$(mktemp -d)"
CORPB="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$CORPA" "$CORPB"' EXIT
if [ "$CORPA" = "$CORPB" ] || [ -z "$CORPA" ] || [ -z "$CORPB" ]; then
  echo "FIXTURE BROKEN: mktemp -d did not return two distinct roots"
  exit 1
fi

# Seeded from what the HARNESS writes, never from what the parser accepts. The
# tool_use/tool_result pair is seed.sh's own (lifted from the live consumer's S290
# transcripts); the operator turn is the plain type:"user" record with
# message.content as a STRING, which is what Claude Code writes for a typed
# message; and the zero-records member is a transcript caught mid-flush, whose
# last line is a partial write.
CITE_PHRASE="drain the batch five backlog before the retro"
NO_SUCH="zzz no operator ever typed this zzz"
for d in "$CORPA" "$CORPB"; do
  mkdir -p "$d/zero" "$d/none" "$d/old"
  for m in alpha-session.jsonl bravo-session.jsonl; do
    cp "$ROOT/clean/session.jsonl" "$d/$m"
    cp "$ROOT/clean/session.jsonl" "$d/old/$m"
  done
  printf '%s\n' "{\"type\":\"user\",\"timestamp\":\"2026-07-13T12:05:00.000Z\",\"message\":{\"role\":\"user\",\"content\":\"$CITE_PHRASE\"}}" >> "$d/alpha-session.jsonl"
  printf '%s\n' '{"type":"user","timestamp":"2026-07-13T12:05:00.000Z","mess' > "$d/zero/alpha-session.jsonl"
  touch -t 202001010101 "$d/old/alpha-session.jsonl" "$d/old/bravo-session.jsonl"
done

ok_()  { echo "ok   [$1]: $2"; }
bad_() { echo "FAIL [$1]: $2"; FAILURES=$((FAILURES + 1)); }
has()  { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# --- id-transcript: --transcript names the file it actually read -------------
OA="$(sbv --transcript "$CORPA/alpha-session.jsonl" 2>&1)"; ra=$?
OB="$(sbv --transcript "$CORPB/alpha-session.jsonl" 2>&1)"; rb=$?
if [ "$ra" != 0 ] || [ "$rb" != 0 ]; then
  bad_ id-transcript "the clean corpus must exit 0 on both sides; got $ra/$rb -- the run did not complete"
elif ! has "$CORPA/alpha-session.jsonl" "$OA" || ! has "$CORPB/alpha-session.jsonl" "$OB"; then
  bad_ id-transcript "each run must NAME the resolved transcript it read; it named a count instead"
elif [ "$OA" = "$OB" ]; then
  bad_ id-transcript "two DIFFERENT transcripts holding identical content produced byte-identical output"
elif has "$CORPB" "$OA" || has "$CORPA" "$OB"; then
  bad_ id-transcript "a run named a corpus it never read"
else
  ok_ id-transcript "--transcript names its resolved file; two identical-content corpora are distinguishable"
fi

# --- id-dir: --dir names every member it actually read -----------------------
OC="$(sbv --dir "$CORPA" 2>&1)"; rc1=$?
OD="$(sbv --dir "$CORPB" 2>&1)"; rd1=$?
if [ "$rc1" != 0 ] || [ "$rd1" != 0 ]; then
  bad_ id-dir "the clean corpus must exit 0 on both sides; got $rc1/$rd1 -- the run did not complete"
elif ! has "$CORPA/alpha-session.jsonl" "$OC" || ! has "$CORPA/bravo-session.jsonl" "$OC"; then
  bad_ id-dir "--dir must name EVERY member it read; a member was missing"
elif ! has "$CORPB/alpha-session.jsonl" "$OD" || ! has "$CORPB/bravo-session.jsonl" "$OD"; then
  bad_ id-dir "--dir must name EVERY member it read; a member was missing on the B side"
elif [ "$OC" = "$OD" ]; then
  bad_ id-dir "two DIFFERENT directories holding identical members produced byte-identical output"
elif has "$CORPB" "$OC" || has "$CORPA" "$OD"; then
  bad_ id-dir "a run named a corpus it never read"
else
  ok_ id-dir "--dir names every resolved member; two identical-content directories are distinguishable"
fi

# --- scanned-line-bytes: what must NOT change --------------------------------
# steps/retro.md:885 reads `transcripts scanned : N` BY LABEL and requires N > 1
# on any sprint that handed off. A byte change on that line breaks a live gate,
# so identity goes on a line AFTER it and this arm pins its bytes.
if grep -qxF "transcripts scanned : 1" <<<"$OA" && grep -qxF "transcripts scanned : 2" <<<"$OC"; then
  ok_ scanned-line-bytes "'transcripts scanned : N' is byte-unchanged and still a bare count (retro.md reads it by label)"
else
  bad_ scanned-line-bytes "'transcripts scanned : N' changed bytes -- steps/retro.md:885 reads this line by label"
fi

# --- id-cite-match: the MATCH diagnostic names its corpus --------------------
# --cite is THE genuine-operator predicate; validate-adversarial-convergence.sh,
# validate-escalation-resolution.sh and ai-dlc-gate-remediation-guard.sh all
# delegate "a real human said this" to it. Its stdout (MATCH <ts>) is identical
# across the two corpora BY CONSTRUCTION -- the timestamps match -- so the
# discrimination has to come from the diagnostic on stderr, and these arms
# capture both streams.
OE="$(sbv --dir "$CORPA" --cite "$CITE_PHRASE" 2>&1)"; re1=$?
OF="$(sbv --dir "$CORPB" --cite "$CITE_PHRASE" 2>&1)"; rf1=$?
if [ "$re1" != 0 ] || [ "$rf1" != 0 ]; then
  bad_ id-cite-match "a genuine operator message must MATCH and exit 0; got $re1/$rf1"
elif ! has "MATCH 2026-07-13T12:05:00.000Z" "$OE" || ! has "MATCH 2026-07-13T12:05:00.000Z" "$OF"; then
  bad_ id-cite-match "the MATCH verdict itself is missing -- the contract stdout must survive"
elif ! has "$CORPA" "$OE" || ! has "$CORPB" "$OF"; then
  bad_ id-cite-match "the MATCH diagnostic must name the corpus the citation was verified against"
elif [ "$OE" = "$OF" ]; then
  bad_ id-cite-match "a citation verified against the WRONG corpus is byte-identical to one verified against the right one"
elif has "$CORPB" "$OE" || has "$CORPA" "$OF"; then
  bad_ id-cite-match "a --cite run named a corpus it never read"
else
  ok_ id-cite-match "--cite MATCH names its corpus, and stdout is still the bare MATCH verdict"
fi

# --- id-cite-nomatch: the no-match diagnostic names its corpus ---------------
OG="$(sbv --dir "$CORPA" --cite "$NO_SUCH" 2>&1)"; rg1=$?
OH="$(sbv --dir "$CORPB" --cite "$NO_SUCH" 2>&1)"; rh1=$?
if [ "$rg1" != 2 ] || [ "$rh1" != 2 ]; then
  bad_ id-cite-nomatch "an uncited phrase must exit 2; got $rg1/$rh1"
elif ! has "no genuine operator message carried it" "$OG"; then
  bad_ id-cite-nomatch "the no-match diagnostic is missing -- the run reported nothing"
elif ! has "$CORPA" "$OG" || ! has "$CORPB" "$OH"; then
  bad_ id-cite-nomatch "the no-match diagnostic must name the corpus that was searched"
elif [ "$OG" = "$OH" ]; then
  bad_ id-cite-nomatch "two DIFFERENT searched corpora produced byte-identical NOMATCH output"
elif has "$CORPB" "$OG" || has "$CORPA" "$OH"; then
  bad_ id-cite-nomatch "a --cite run named a corpus it never read"
else
  ok_ id-cite-nomatch "--cite no-match names the corpus it searched"
fi

# --- id-cite-zero: the zero-parseable-records diagnostic names its corpus ----
# The third --cite site, and the one a differential found rather than a reading:
# two of three were patched and the corpora were still indistinguishable here.
OI="$(sbv --dir "$CORPA/zero" --cite "$NO_SUCH" 2>&1)"; ri1=$?
OJ="$(sbv --dir "$CORPB/zero" --cite "$NO_SUCH" 2>&1)"; rj1=$?
if [ "$ri1" != 2 ] || [ "$rj1" != 2 ]; then
  bad_ id-cite-zero "an unparseable corpus must exit 2; got $ri1/$rj1 -- the seed did not reach the branch"
elif ! has "NOMATCH (0 records across 1 transcript(s)" "$OI"; then
  bad_ id-cite-zero "the zero-records diagnostic is missing -- the seed did not reach the branch under test"
elif ! has "$CORPA/zero" "$OI" || ! has "$CORPB/zero" "$OJ"; then
  bad_ id-cite-zero "the zero-records diagnostic must name the corpus that held no records"
elif [ "$OI" = "$OJ" ]; then
  bad_ id-cite-zero "two DIFFERENT unparseable corpora produced byte-identical output"
else
  ok_ id-cite-zero "--cite zero-records names the corpus that held no parseable record"
fi

# --- count-carries-no-identity: what must NOT change -------------------------
# --count is a bare integer BY CONTRACT (steps/gate-validation.md:2295 reads it
# directly). It is the one output path that must stay identity-free, so this arm
# asserts the two corpora are INDISTINGUISHABLE here -- the inverse of every arm
# above -- with the expected integer as its positive conjunct.
CA="$(sbv --dir "$CORPA" --count 2>/dev/null)"; rca=$?
CB="$(sbv --dir "$CORPB" --count 2>/dev/null)"
if [ "$rca" = 0 ] && [ "$CA" = "0" ] && [ "$CB" = "0" ]; then
  ok_ count-carries-no-identity "--count is still a bare integer on both corpora and carries no path"
else
  bad_ count-carries-no-identity "--count must print a bare integer and nothing else; got '$CA'/'$CB' rc=$rca"
fi

# --- quiet-suppresses-identity: what must NOT change -------------------------
# --quiet suppresses the LOG block, and the new identity line lives in it. The
# FAIL diagnostics are console.error and are NOT suppressed, so the positive
# conjunct is that the STARVATION row is still there.
# ONE run, the two streams kept apart: stdout in QO, stderr in a file read back as QE.
QO="$(sbv --transcript "$ROOT/starves/session.jsonl" --quiet 2>"$ROOT/quiet.err")"; qrc=$?
QE="$(cat "$ROOT/quiet.err")"
if [ "$qrc" != 1 ]; then
  bad_ quiet-suppresses-identity "the starving session must still exit 1 under --quiet; got $qrc"
elif ! has "FAIL (A -- STARVATION)" "$QE"; then
  bad_ quiet-suppresses-identity "--quiet must not suppress the FAIL diagnostic; the row is gone"
elif [ -n "$QO" ]; then
  bad_ quiet-suppresses-identity "--quiet printed on stdout: $QO"
elif has "transcripts read" "$QE"; then
  bad_ quiet-suppresses-identity "the identity line leaked into --quiet"
else
  ok_ quiet-suppresses-identity "--quiet still prints nothing on stdout and still emits the FAIL row"
fi

# --- dir-empty-identity: the corpus SOURCE, not just its members -------------
# The identity line names MEMBERS. An EMPTY corpus has none, so it prints
# `(none)` and two different empty directories are byte-identical again -- the
# original defect, surviving in the case where a wrong corpus is MOST likely:
# a mis-derived project slug resolves to a directory that exists and holds no
# transcripts. The `(none)` branch has to name the SOURCE.
OM="$(sbv --dir "$CORPA/none" 2>&1)"; rm1=$?
ON="$(sbv --dir "$CORPB/none" 2>&1)"
if [ "$rm1" != 0 ]; then
  bad_ dir-empty-identity "an empty corpus must exit 0; got $rm1"
elif ! has "transcripts scanned : 0" "$OM"; then
  bad_ dir-empty-identity "the evidence block is missing -- the run reported nothing"
elif ! has "$CORPA/none" "$OM" || ! has "$CORPB/none" "$ON"; then
  bad_ dir-empty-identity "an EMPTY corpus names no source, so a wrong-corpus run is still invisible"
elif [ "$OM" = "$ON" ]; then
  bad_ dir-empty-identity "two DIFFERENT empty corpora produced byte-identical output"
else
  ok_ dir-empty-identity "an empty corpus still names the source that held nothing"
fi

# --- dir-since-excluded-identity: same branch, on the LIVE call site ---------
# steps/retro.md:882-883 invokes `--since <sprint start>` with no path; the
# validator derives this session's project directory itself (validate-steering-budget.sh
# :287-288 sets DIR) and names it on its `corpus :` line. This arm drives the explicit
# `--dir <x> --since` equivalent, which reaches the same code after that derivation.
# When the window excludes every member the file list is empty and the same `(none)`
# branch runs, so the audit the retro records cannot say which project directory
# it was pointed at. Same owner as the arm above; one fix closes both.
SINCE_CUT="2026-01-01T00:00:00Z"
OP="$(sbv --dir "$CORPA/old" --since "$SINCE_CUT" 2>&1)"; rp1=$?
OQ="$(sbv --dir "$CORPB/old" --since "$SINCE_CUT" 2>&1)"
if [ "$rp1" != 0 ]; then
  bad_ dir-since-excluded-identity "a fully-excluded corpus must exit 0; got $rp1"
elif ! grep -qxF "transcripts scanned : 0 (2 excluded: mtime before $SINCE_CUT)" <<<"$OP"; then
  bad_ dir-since-excluded-identity "the exclusion note is missing or changed bytes -- the seed did not reach the branch"
elif ! has "$CORPA/old" "$OP" || ! has "$CORPB/old" "$OQ"; then
  bad_ dir-since-excluded-identity "a --since window that excludes everything names no source; retro.md's own invocation shape"
elif [ "$OP" = "$OQ" ]; then
  bad_ dir-since-excluded-identity "two DIFFERENT fully-excluded corpora produced byte-identical output"
else
  ok_ dir-since-excluded-identity "a fully-excluded corpus still names the source it was pointed at"
fi

# ===========================================================================
# WHO SAID IT, AND WHEN. Two properties of the genuine-operator predicate that
# nothing above can see, because every arm above cites a phrase that IS in the
# corpus and asks only whether the scan found it.
#
#   isMeta   Claude Code writes user-SHAPED records of its own -- skill re-load
#            notices, usage-limit resets, "please continue" nudges -- and flags
#            them `isMeta:true`. Their bytes are a typed turn's bytes. Measured
#            on the reference consumer's 252 transcripts: of 984 records the
#            predicate accepted as operator text, 90 carried the flag, every one
#            long enough to verify a citation quoting it. The exclusions beside
#            this one are a list of the injections somebody happened to SEE; the
#            flag is the producer saying so.
#
#   the WHEN A citation is `<ISO ts> | "<quote>"`. Unbounded, the corpus is the
#            project's entire session history, so any phrase the operator ever
#            typed verifies a citation filed today -- and `MATCH <ts>` was
#            printed and discarded by every caller, so the one output that could
#            have refuted it was the one nobody read. `--authorized-at` bounds
#            the scan to a window around the citation's own timestamp.
#
# WHY A WINDOW AND NOT AN EQUALITY: over the reference consumer's 26 authorization rows the gap
# between the stated timestamp and the NEAREST accepted record runs from -1116s
# to +4283s, because these timestamps are hand-typed and routinely rounded to
# the minute or the ten-minute. An exact compare NOMATCHes 22 of the 24 rows
# that verify today.
echo
echo "  -- who said it, and when --"
AWORK="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$CORPA" "$CORPB" "$AWORK"' EXIT
mkdir -p "$AWORK/corpus"
# THE FIRST MEMBER CARRIES NO CITED PHRASE. A verifier that reads the corpus's first file and
# stops satisfied every case of this kind when the seed held one transcript, and returned
# NOMATCH on the reference consumer's one genuine in-force citation.
# THE OLD TURN IS IN THE FIRST FILE, and it is the direction a lead actually forges: write
# today's entry, reach back to a phrase the operator typed weeks ago. Every out-of-window seed
# this suite had placed the record AFTER the bound, which is the direction nobody forges --
# measured, a window spliced to refuse only the later side passed the receipt, this fixture,
# the reader fixture, while accepting a citation stamped in
# September for a phrase said in June.
cat > "$AWORK/corpus/a-monday.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-06-10T08:12:44Z","message":{"role":"user","content":"take the second option and carry on"}}
{"type":"user","timestamp":"2026-07-01T09:00:00Z","message":{"role":"user","content":"/ai-dlc Sprint 77. Kick off."}}
JSONL
# The SECOND member holds every subject: the authorization turn, a harness injection, its
# one-property-apart typed twin, and a turn a week later carrying different words.
cat > "$AWORK/corpus/b-tuesday.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-02T14:37:41Z","message":{"role":"user","content":"Suppress this check for this gate only"}}
{"type":"user","isMeta":true,"timestamp":"2026-07-02T14:38:00Z","message":{"role":"user","content":"the harness injected this sentence verbatim"}}
{"type":"user","timestamp":"2026-07-02T14:39:00Z","message":{"role":"user","content":"the operator typed this sentence verbatim"}}
{"type":"user","timestamp":"2026-07-09T11:02:13Z","message":{"role":"user","content":"Carry the residue into the next sprint"}}
JSONL
AUTH_TS="2026-07-02T14:37:00Z"     # the turn is at :41; a hand-typed line rounds to the minute
CITE_AUTH="Suppress this check for this gate only"
CITE_LATER="Carry the residue into the next sprint"
CITE_META="the harness injected this sentence verbatim"
CITE_TYPED="the operator typed this sentence verbatim"
CITE_OLD="take the second option and carry on"
# The SAME INSTANT as the authorization turn, written with a zone offset instead of `Z`. The
# citation field's grammar permits it and the lifetime sibling accepts it, so it reaches every
# call site; truncated to its naive part it moves the window by the offset -- seven hours here.
AUTH_TS_OFFSET="2026-07-02T07:37:00-07:00"

# rc AND stdout from one invocation. `cmd | grep` takes grep's status, and --cite exits 2 on
# NOMATCH, so the two have to be captured together.
acite() { # acite <quote> [<authorized-at>] -> prints "<verdict>/<rc>"
  local q="$1" at="${2:-}" o r
  if [ -n "$at" ]; then
    o="$(sbv --dir "$AWORK/corpus" --cite "$q" --authorized-at "$at" --quiet 2>/dev/null)"; r=$?
  else
    o="$(sbv --dir "$AWORK/corpus" --cite "$q" --quiet 2>/dev/null)"; r=$?
  fi
  printf '%s/%s' "${o:-EMPTY}" "$r"
}
acount() { sbv --transcript "$1" --count 2>/dev/null; }

w() { # w <name> <got> <want> <why>
  if [ "$2" = "$3" ]; then ok_ "$1" "$4"; else bad_ "$1" "got '$2', want '$3' -- $4"; fi
}

# --- W1: the two-file corpus, bounded, with a ROUNDED authorization timestamp --
w two-file-rounded "$(acite "$CITE_AUTH" "$AUTH_TS")" "MATCH 2026-07-02T14:37:41Z/0" \
  "a genuine turn 41s after a minute-rounded authorization time still verifies, and it is in the corpus's SECOND file"

# --- W2: the same corpus, a phrase said a WEEK from the cited moment ----------
# ONE run feeds this arm and the diagnostic arm (W2d) below: the same command and arguments,
# the diagnostic arm having only wanted stderr as well. stdout -> W2O, stderr -> a file.
W2O="$(sbv --dir "$AWORK/corpus" --cite "$CITE_LATER" --authorized-at "$AUTH_TS" --quiet 2>"$AWORK/w2.err")"; W2RC=$?
w said-elsewhere "${W2O:-EMPTY}/$W2RC" "NOMATCH/2" \
  "words the operator really said, seven days from the moment this citation claims, do not verify it"

# --- W2c: THE DISCRIMINATOR for W2. Same quote, same corpus, no bound ---------
# Without this the NOMATCH above is indistinguishable from a corpus that does not hold the
# words at all, which is what every pre-bound arm in this file would have reported.
w said-elsewhere-unbounded "$(acite "$CITE_LATER")" "MATCH 2026-07-09T11:02:13Z/0" \
  "unbounded, that same phrase verifies -- so W2's NOMATCH came from the WINDOW and not from the corpus"

# --- W2d: the NOMATCH says WHICH of the two findings it is -------------------
# "nothing carried these words" and "the operator said them at another moment" are different
# facts and a reader cannot act on them alike. The exit code is 2 either way.
W2D="$(cat "$AWORK/w2.err")$W2O"
if has "carried it outside the" "$W2D" && has "$AUTH_TS" "$W2D"; then
  ok_ nomatch-names-the-window "the out-of-window NOMATCH says the words WERE said, and names the cited authorization time"
else
  bad_ nomatch-names-the-window "the diagnostic does not separate 'never said' from 'said at another moment': $W2D"
fi

# --- W2e: THE OTHER SIDE OF THE WINDOW, and the one a lead actually reaches for -----------
# The entry is stamped 2026-07-02; the words were typed on 2026-06-10, three weeks BEFORE it.
# Every other out-of-window case in this suite puts the record AFTER the bound, and a window
# refusing only that side accepts this citation while passing every one of them.
w said-weeks-before "$(acite "$CITE_OLD" "$AUTH_TS")" "NOMATCH/2" \
  "a phrase the operator typed three weeks BEFORE the cited authorization does not verify it"

# --- W2f: THE DISCRIMINATOR for W2e. Same quote, same corpus, no bound --------
w said-weeks-before-unbounded "$(acite "$CITE_OLD")" "MATCH 2026-06-10T08:12:44Z/0" \
  "unbounded, that same phrase verifies -- so W2e's NOMATCH came from the WINDOW and not from the corpus, and it came from the corpus's FIRST file"

# --- W2g: a zone OFFSET is honoured, not truncated ---------------------------
# The same instant as the in-window authorization time, written `-07:00` instead of `Z`. Read
# as its naive part the window moves by the offset and this citation NOMATCHes; read whole it
# is the same moment and must MATCH. The pair is W1's, one property apart -- only the spelling
# of the timestamp differs.
w offset-honoured "$(acite "$CITE_AUTH" "$AUTH_TS_OFFSET")" "MATCH 2026-07-02T14:37:41Z/0" \
  "an authorization time written with a -07:00 offset is the same instant as the Z form and verifies the same citation"
w offset-still-bounds "$(acite "$CITE_OLD" "$AUTH_TS_OFFSET")" "NOMATCH/2" \
  "and it still BOUNDS -- the offset form is not a way to widen the window to everything"

# --- W3: a harness injection is not an operator turn -------------------------
w ismeta-not-citable "$(acite "$CITE_META")" "NOMATCH/2" \
  "an isMeta:true record's text does not verify a citation, however operator-shaped its bytes are"

# --- W3b: the ALLOW twin, ONE PROPERTY APART ---------------------------------
# Same file, same record shape, same neighbourhood; only the isMeta key differs. Without it,
# W3 passes identically against a predicate that rejects everything in this corpus.
w typed-still-citable "$(acite "$CITE_TYPED")" "MATCH 2026-07-02T14:39:00Z/0" \
  "the same record without isMeta still verifies -- W3 discriminates on the flag, not on the file"

# --- W4: an unparseable bound is REFUSED, never dropped ----------------------
# Silently ignoring it hands back a fully unbounded verify wearing a bounded one's exit code.
W4="$(sbv --dir "$AWORK/corpus" --cite "$CITE_AUTH" --authorized-at "yesterday afternoon" --quiet 2>&1)"; W4RC=$?
if [ "$W4RC" -ne 0 ] && [ "$W4RC" -ne 2 ] && has "authorized-at" "$W4"; then
  ok_ bad-bound-refused "an --authorized-at that will not parse exits ${W4RC} (neither MATCH nor NOMATCH) and names the flag"
else
  bad_ bad-bound-refused "an unparseable bound produced rc=$W4RC -- a caller reading 0/2 cannot tell it from a verdict: $W4"
fi

# --- W5: the bound has no meaning without --cite -----------------------------
sbv --dir "$AWORK/corpus" --authorized-at "$AUTH_TS" --quiet >/dev/null 2>&1
W5RC=$?
w bound-needs-cite "$W5RC" "1" "--authorized-at outside a --cite query is refused rather than accepted and ignored"

# --- W6: CHECK B MOVES WITH THE PREDICATE, and its twin says so --------------
# The isMeta arm sits in genuineOperatorText, which Check B is the only other caller of. A fix
# applied to --cite alone leaves the steamroll check reading a machine event as a human steer --
# the failure class its own header warns against twice.
mkdir -p "$AWORK/bmeta" "$AWORK/btyped"
cat > "$AWORK/bmeta/session.jsonl" <<'JSONL'
{"type":"user","isMeta":true,"timestamp":"2026-07-04T10:00:00Z","message":{"role":"user","content":"Your claude.ai usage limit has reset. Continue the task you were working on"}}
{"type":"assistant","timestamp":"2026-07-04T10:00:05Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"prompt":"go"}}]}}
JSONL
cat > "$AWORK/btyped/session.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-04T10:00:00Z","message":{"role":"user","content":"Your claude.ai usage limit has reset. Continue the task you were working on"}}
{"type":"assistant","timestamp":"2026-07-04T10:00:05Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"prompt":"go"}}]}}
JSONL
w checkb-ignores-ismeta "$(acount "$AWORK/bmeta/session.jsonl")" "0" \
  "a harness injection followed by an Agent dispatch is not a steamroll"
w checkb-counts-typed "$(acount "$AWORK/btyped/session.jsonl")" "1" \
  "the SAME two records without isMeta still count as one -- W6 discriminates on the flag"

# --- W8: A CLEAR IN A DENIED CALL CLEARED NOTHING ----------------------------
# A denied call runs none of its parts. A pause-flag rm folded into a compound Bash call that
# ANOTHER hook refused for its other part left the flag present, and the lead then advanced.
# The deny result is seeded from what the harness writes for a PreToolUse refusal. The twin is
# the same records with the call RUN (a non-zero exit from its later part is not a deny: the rm
# before it ran), which must read as cleared.
mkdir -p "$AWORK/bclrdeny" "$AWORK/bclrran"
cat > "$AWORK/bclrdeny/session.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-04T10:00:00Z","message":{"role":"user","content":"ok carry on with the deploy"}}
{"type":"assistant","timestamp":"2026-07-04T10:00:05Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"rm -f _bmad-output/pipeline-paused.flag; curl -sf http://127.0.0.1:8788/health"}}]}}
{"type":"user","timestamp":"2026-07-04T10:00:06Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"PreToolUse:Bash hook error: context-mode: curl/wget redirected. Call ctx_execute to fetch the URL."}]}}
{"type":"assistant","timestamp":"2026-07-04T10:00:10Z","message":{"content":[{"type":"tool_use","id":"t2","name":"Agent","input":{"prompt":"go"}}]}}
JSONL
cat > "$AWORK/bclrran/session.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-04T10:00:00Z","message":{"role":"user","content":"ok carry on with the deploy"}}
{"type":"assistant","timestamp":"2026-07-04T10:00:05Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"rm -f _bmad-output/pipeline-paused.flag; curl -sf http://127.0.0.1:8788/health"}}]}}
{"type":"user","timestamp":"2026-07-04T10:00:06Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"Exit code 7"}]}}
{"type":"assistant","timestamp":"2026-07-04T10:00:10Z","message":{"content":[{"type":"tool_use","id":"t2","name":"Agent","input":{"prompt":"go"}}]}}
JSONL
w checkb-denied-clear-not-cleared "$(acount "$AWORK/bclrdeny/session.jsonl")" "1" \
  "an rm of the pause flag inside a call a hook DENIED cleared nothing, so the Agent after it is a steamroll"
w checkb-run-clear-cleared "$(acount "$AWORK/bclrran/session.jsonl")" "0" \
  "the SAME call that RAN and exited non-zero cleared the flag -- W8 discriminates on the deny, not on is_error"

# --- W7: THE TOLERANCE IS A CONSTANT, AND NO ENVIRONMENT REACHES IT ------------
# Every other tunable in this validator is a BUDGET -- widen it and the check reports
# differently about the same facts. This one is a PROVENANCE bound: widen it and the check
# stops asking its question while its output, its exit codes, every other arm here and every
# receipt stay exactly as green. Readers inherit the environment they are run in and the
# remediation guard runs in the LEAD'S, so an exported value would be a one-word way to turn
# off the arm standing between a lead and lifting its own gate deny.
#
# THE ARM IS RUN WITH THE OLD VARIABLE SET, not with it absent: an absent variable proves only
# that the default is 7200, which was true while the knob existed too.
W7O="$(AI_DLC_CITE_AUTH_TOLERANCE_S=1000000000 sbv --dir "$AWORK/corpus" --cite "$CITE_LATER" --authorized-at "$AUTH_TS" --quiet 2>/dev/null)"; W7RC=$?
w tolerance-not-overridable "${W7O:-EMPTY}/$W7RC" "NOMATCH/2" \
  "a phrase said a week away still NOMATCHes with AI_DLC_CITE_AUTH_TOLERANCE_S=10^9 exported -- the window is a literal in the program"
# The ALLOW twin, one property apart: the same environment must not break a genuine citation
# either. Without it this arm passes against a build that refuses everything.
W7B="$(AI_DLC_CITE_AUTH_TOLERANCE_S=1000000000 sbv --dir "$AWORK/corpus" --cite "$CITE_AUTH" --authorized-at "$AUTH_TS" --quiet 2>/dev/null)"; W7BRC=$?
w tolerance-env-harmless "${W7B:-EMPTY}/$W7BRC" "MATCH 2026-07-02T14:37:41Z/0" \
  "the same environment leaves a genuine in-window citation verifying -- W7 discriminates on the window, not on the run failing"

# ===========================================================================
# NO CORPUS FLAG: THE SESSION'S CORPUS IS DERIVED, OR THE RUN REFUSES EXACTLY AS BEFORE.
#
# The gate step used to make the model type the corpus path (`ls -t` over a `sed`-slugged
# working directory); the validator now derives it from CLAUDE_CODE_SESSION_ID under
# $HOME/.claude/projects/*/. Every call below sets BOTH variables explicitly -- the suite runs
# under `git push` from a Claude Code session, where the real id is exported, and in CI, where
# it is not, and an arm that inherited either would score against whatever that machine holds.
#
# THE SLUG DIRECTORY HOLDS A SECOND SESSION, and it is what separates the two modes. The cited
# phrase is ONLY in the other session's file (an operator authorizes in one session and the
# gate that leans on it runs in another), so --cite must derive the DIRECTORY to MATCH; and
# both files starve once, so --count must derive the FILE to read 1 rather than 2.
echo
echo "  -- flagless: the derived session corpus --"
DWORK="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$CORPA" "$CORPB" "$AWORK" "$DWORK"' EXIT
DSID="0c0ffee0-1111-4222-8333-444455556666"
DPHRASE="ship the flagless corpus derivation today"
DH1="$DWORK/one"; DSLUG="$DH1/.claude/projects/-seeded-checkout"
mkdir -p "$DSLUG" "$DH1/.claude/projects/-another-project"
cp "$ROOT/starves/session.jsonl" "$DSLUG/$DSID.jsonl"
cp "$ROOT/starves/session.jsonl" "$DSLUG/aaaa-earlier-session.jsonl"
printf '%s\n' "{\"type\":\"user\",\"timestamp\":\"2026-07-13T12:05:00.000Z\",\"message\":{\"role\":\"user\",\"content\":\"$DPHRASE\"}}" >> "$DSLUG/aaaa-earlier-session.jsonl"
cp "$ROOT/clean/session.jsonl" "$DH1/.claude/projects/-another-project/other.jsonl"
# ZERO: a projects tree holding transcripts, none of them this session's.
DH0="$DWORK/zero"; mkdir -p "$DH0/.claude/projects/-seeded-checkout"
cp "$ROOT/clean/session.jsonl" "$DH0/.claude/projects/-seeded-checkout/aaaa-earlier-session.jsonl"
# TWO: the same session id under two project slugs. Ambiguous, so nothing is derived.
DH2="$DWORK/two"; mkdir -p "$DH2/.claude/projects/-a" "$DH2/.claude/projects/-b"
cp "$DSLUG/aaaa-earlier-session.jsonl" "$DH2/.claude/projects/-a/$DSID.jsonl"
cp "$DSLUG/aaaa-earlier-session.jsonl" "$DH2/.claude/projects/-b/$DSID.jsonl"
# ESCAPE: an id carrying `../` would splice a path out of the slug directory into the glob.
DESC="../escape-session"
mkdir -p "$DWORK/esc/.claude/projects/-x"
cp "$DSLUG/aaaa-earlier-session.jsonl" "$DWORK/esc/.claude/projects/escape-session.jsonl"

REF_CITE="FAIL: --cite requires --transcript PATH or --dir PATH"
REF_ANY="FAIL: pass --transcript PATH or --dir PATH"
# drive <home> <sid-or-UNSET> <args...> -> "<rc>|<stdout+stderr>"
drive() {
  local h="$1" sid="$2" o r; shift 2
  if [ "$sid" = "UNSET" ]; then
    o="$( ( unset CLAUDE_CODE_SESSION_ID; export HOME="$h"; fx_inproc "$VALIDATOR"; sb_main "$@" ) 2>&1)"; r=$?
  else
    o="$( ( export HOME="$h" CLAUDE_CODE_SESSION_ID="$sid"; fx_inproc "$VALIDATOR"; sb_main "$@" ) 2>&1)"; r=$?
  fi
  printf '%s|%s' "$r" "$o"
}
# DREF: the unset-id reference for each refusal world, driven ONCE with the shipping program.
# `refuse` compares each set-id run against this reference and against the literal.
DREF0C="$(drive "$DH0" UNSET --cite "$DPHRASE")"; DREF0N="$(drive "$DH0" UNSET --count)"
DREF2C="$(drive "$DH2" UNSET --cite "$DPHRASE")"; DREF2N="$(drive "$DH2" UNSET --count)"
DREFEC="$(drive "$DWORK/esc" UNSET --cite "$DPHRASE")"; DREFEN="$(drive "$DWORK/esc" UNSET --count)"
# The verdict for one validator over the derivation worlds, one token per world.
#   C  flagless --cite, single match: MATCH, and the diagnostic names the slug DIRECTORY
#   N  flagless --count, single match: the bare integer 1 (the FILE, not the directory's 2)
#   S  flagless --since: the corpus line names the slug DIRECTORY
#   Z  zero matches: both refusals byte-identical to an unset-id run, and each IS the literal
#   T  two matches: the same
#   E  an id carrying ../: the same
dvec() {
  local c n s z t e x y
  c="$(drive "$DH1" "$DSID" --cite "$DPHRASE")"
  if [ "$c" = "0|cite: scanned 2 transcript(s) from $DSLUG
MATCH 2026-07-13T12:05:00.000Z" ]; then c=C; else c=c; fi
  n="$(drive "$DH1" "$DSID" --count)"
  if [ "$n" = "0|1" ]; then
    n="$(drive "$DH1" "$DSID")"
    case "$n" in *"corpus              : $DSLUG/$DSID.jsonl"*) n=N ;; *) n=n ;; esac
  else n=n; fi
  s="$(drive "$DH1" "$DSID" --since 2020-01-01T00:00:00Z)"
  case "$s" in *"corpus              : $DSLUG
"*) s=S ;; *) s=s ;; esac
  # refuse <home> <sid> <yc> <yn> -> R when both flagless shapes refuse exactly as an unset id
  # does. <yc>/<yn> are that unset-id reference, read ONCE per world from the shipping program
  # (see DREF above).
  refuse() {
    x="$(drive "$1" "$2" --cite "$DPHRASE")"
    [ "$x" = "$3" ] && [ "$x" = "1|$REF_CITE" ] || { printf r; return; }
    x="$(drive "$1" "$2" --count)"
    [ "$x" = "$4" ] && [ "$x" = "1|$REF_ANY" ] || { printf r; return; }
    printf R
  }
  z="$(refuse "$DH0" "$DSID" "$DREF0C" "$DREF0N")"; t="$(refuse "$DH2" "$DSID" "$DREF2C" "$DREF2N")"; e="$(refuse "$DWORK/esc" "$DESC" "$DREFEC" "$DREFEN")"
  z="${z/R/Z}"; z="${z/r/z}"; t="${t/R/T}"; t="${t/r/t}"; e="${e/R/E}"; e="${e/r/e}"
  printf '%s%s%s%s%s%s' "$c" "$n" "$s" "$z" "$t" "$e"
}
DV="$(dvec)"
w derive-shipping "$DV" "CNSZTE" \
  "flagless --cite derives the slug DIRECTORY, --count the session FILE, --since the DIRECTORY; zero, two and a ../ id refuse byte-for-byte as an unset id does"
# THE ESCAPE WORLD MUST BE ABLE TO MATCH, or E is a refusal for a reason that is not the guard:
# the same file read through an explicit --dir must MATCH the phrase.
w derive-escape-reachable "$(drive "$DWORK/esc" UNSET --dir "$DWORK/esc/.claude/projects" --cite "$DPHRASE" | sed -n '$p')" \
  "MATCH 2026-07-13T12:05:00.000Z" "the ../ world's file carries the phrase, so E refuses because of the id guard and not an empty world"

# ===========================================================================
# THE SIBLINGS OF AN AskUserQuestion. Calls issued in one assistant turn return together, so a
# Bash sent beside an AskUserQuestion gets its result only once the human answers, and its raw
# duration is the human's think-time. Check A charges such a sibling only for what it blocks
# AFTER the latest answer in its message. The join key is `message.id`: the harness writes each
# content block as its OWN record, so the seeds (seed.sh, sib-*) are separate records sharing
# that id and each carrying its own `uuid`.
#
# One token per case, upper case when the case reads as the shipping program must:
#   A  sib-a  same message, Bash ends at the answer          count 0, no STARVATION
#   B  sib-b  same timing, Bash in a DIFFERENT message        count 1, STARVATION
#   C  sib-c  same message, Bash blocks 600s past the answer  count 1, STARVATION
#   D  sib-d  sib-a's timing, no message.id at all            count 1, STARVATION
#   E  sib-e  two AskUserQuestions, Bash ends at the LATER    count 0, no STARVATION
#   F  sib-f  sib-a with a READ sibling                       count 0, no STARVATION
#   G  sib-g  sib-a with the sibling's record BEFORE the AUQ  count 0, no STARVATION
#   H  sib-h  UNANSWERED AskUserQuestion, Bash blocks 600s    count 1, STARVATION
# B is the arm a timestamp-proximity key fails: its Bash ends 0.5s after an answer it never
# waited on. E is the arm a first-answer key fails. F is the arm a Bash-only join fails, G the
# arm a join that sees only siblings written AFTER the AskUserQuestion fails, H the arm an
# unanswered question acquitting its siblings fails. All are positive-shaped: the count must be
# a bare integer, so a subject that emits nothing reads EMPTY and matches no token.
echo
echo "  -- AskUserQuestion siblings --"
# ONE run per (program, case). This used to run `--count` AND the full report, and both read
# the same `starv` array: the count is the number in the STARVATION row's first line. A
# sibling case has no operator turn, wait run or TaskOutput, so the count IS the starvation
# count. `0` still needs a positive witness -- the report's last line, `PASS  (D)` -- so a
# program that emitted nothing reads EMPTY and matches no expected token.
sib() { # sib <case> -> "<count>/<yes|no>"
  local c o st=no
  o="$(sbv --transcript "$ROOT/$1/session.jsonl" 2>&1)"
  case "$o" in
    *"FAIL (A -- STARVATION): "*) st=yes; c="${o#*FAIL (A -- STARVATION): }"; c="${c%% *}" ;;
    *"PASS  (D)"*) c=0 ;;
    *) c=EMPTY ;;
  esac
  printf '%s/%s' "$c" "$st"
}
w sib-a-same-message-acquitted "$(sib sib-a)" "0/no" \
  "a Bash sharing an AskUserQuestion's message.id and ending at the answer is think-time, not starvation"
w sib-b-other-message-charged "$(sib sib-b)" "1/yes" \
  "the same timing with the Bash in ANOTHER message is starvation -- the key is message.id, not proximity"
w sib-c-past-answer-charged "$(sib sib-c)" "1/yes" \
  "a same-message Bash blocking 600s past the answer is still starvation -- the exemption is bounded"
w sib-d-no-message-id-charged "$(sib sib-d)" "1/yes" \
  "a record with no message.id joins nothing and is charged its full duration"
w sib-e-latest-answer "$(sib sib-e)" "0/no" \
  "with two AskUserQuestions in one message the sibling is charged from the LATER answer"
w sib-f-read-sibling-acquitted "$(sib sib-f)" "0/no" \
  "a READ sibling ending at the answer is think-time too -- the join is not limited to Bash"
w sib-g-sibling-written-first "$(sib sib-g)" "0/no" \
  "a sibling whose record precedes the AskUserQuestion's in the same message still joins"
w sib-h-unanswered-charged "$(sib sib-h)" "1/yes" \
  "an AskUserQuestion with no answer acquits nothing: its Bash sibling is charged in full"
# ===========================================================================
# SERVER-SIDE TOOLS. Two layers, and they cover each other on the advisor seed, which is why
# a second seed exists. The READER must see a server_tool_use / *_tool_result pair at all; the
# EXEMPT set then excuses `advisor` by name. Reverting the reader makes the advisor seed read 0
# BYTE-IDENTICALLY to the shipping program (nothing is read, so nothing is charged), so only
# the non-advisor server seed can tell. Removing the exemption shows on the advisor seed.
#   srv-advisor  advisor, 176s, producer shape       count 0 (exempt by decision)
#   srv-search   tool_search_tool_regex, 176s, same  count 1 (a server tool is still charged)
echo
echo "  -- server-side tools --"
srvc() { local c; c="$(sbv --transcript "$ROOT/$1/session.jsonl" --count 2>/dev/null)"; printf '%s' "${c:-EMPTY}"; }
w srv-advisor-exempt "$(srvc srv-advisor)" "0" \
  "an advisor call over 150s, in the shape the harness writes it, is exempt by name"
w srv-search-charged "$(srvc srv-search)" "1" \
  "CONTROL: a non-advisor server tool over 150s is still charged -- the exemption is the name, not the shape"
# ===========================================================================
# PAUSE-LEGAL CALLS ARE NOT STEAMROLLS (BL-783). Check B must not score a call the pause hook
# (ai-dlc-acknowledge.sh) allows: a write matching one of its allow arms, or any advancing call
# in an UPDATER session as the hook's I126 scan decides it. Every cell is an operator message
# followed by ONE call; paths are ABSOLUTE, as the harness writes them. The typed-command records
# are the producer's shape (graph transcripts, 2026-10-16). `pb-control` is the genuine steamroll
# in a pipeline session, so a 0 elsewhere is not a check that cannot fire.
#   pb-snapshot    Edit  .../_bmad-output/pipeline-snapshot.md                            0
#   pb-resolution  Edit  .../_bmad-output/planning-artifacts/s292/prd-resolution-p2.md    0
#   pb-archive     Edit  .../_bmad-output/pipeline-snapshot.archive.x.md                  1
#   pb-control     Edit  .../_bmad-output/implementation-artifacts/x.md                   1
#   pb-skillupd    Skill(ai-dlc-update)                                                   0
#   pb-updater     typed /ai-dlc-update, then the control's Edit                          0
#   pb-recency     typed /ai-dlc-update, then typed /ai-dlc, then the control's Edit      1
#   pb-wait        Check C: 4 wait beats, a snapshot Edit, 3 beats (the Edit no reset)   1
echo
echo "  -- pause-legal calls (BL-783) --"
PB="$AWORK/pb"; mkdir -p "$PB"
pb_op='{"type":"user","timestamp":"2026-07-04T10:00:00Z","message":{"role":"user","content":"hold on, change the plan please"}}'
pb_ai='{"type":"user","timestamp":"2026-07-04T09:00:00Z","message":{"role":"user","content":"<command-message>ai-dlc</command-message>\n<command-name>/ai-dlc</command-name>"}}'
pb_up='{"type":"user","timestamp":"2026-07-04T09:30:00Z","message":{"role":"user","content":"<command-message>ai-dlc-update</command-message>\n<command-name>/ai-dlc-update</command-name>"}}'
pb_edit() { printf '{"type":"assistant","timestamp":"2026-07-04T10:00:05Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Edit","input":{"file_path":"/Users/x/proj/_bmad-output/%s","old_string":"a","new_string":"b"}}]}}' "$1"; }
pb_skill='{"type":"assistant","timestamp":"2026-07-04T10:00:05Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"ai-dlc-update","args":"abc apply"}}]}}'
pb_seed() { local n="$1"; shift; printf '%s\n' "$@" > "$PB/$n.jsonl"; }
pb_seed snapshot   "$pb_ai" "$pb_op" "$(pb_edit pipeline-snapshot.md)"
pb_seed resolution "$pb_ai" "$pb_op" "$(pb_edit planning-artifacts/s292/prd-resolution-p2.md)"
pb_seed archive    "$pb_ai" "$pb_op" "$(pb_edit pipeline-snapshot.archive.x.md)"
pb_seed control    "$pb_ai" "$pb_op" "$(pb_edit implementation-artifacts/x.md)"
pb_seed skillupd   "$pb_ai" "$pb_op" "$pb_skill"
pb_seed updater    "$pb_up" "$pb_op" "$(pb_edit implementation-artifacts/x.md)"
pb_seed recency    "$pb_up" "$pb_ai" "$pb_op" "$(pb_edit implementation-artifacts/x.md)"
# Check C shares the narrowed path test: 4 wait beats, a snapshot Edit, 3 more beats, no operator
# message. The Edit is pause-legal, so it no longer resets the run, and 7 beats pass the 6 ceiling.
# Under PB1 and PB2 the Edit is advancing again, resets the run, and the cell reads 0.
pb_beat() { printf '{"type":"assistant","timestamp":"2026-07-04T10:0%s:00Z","message":{"content":[{"type":"tool_use","id":"w%s","name":"Bash","input":{"command":"sleep 30; [ -f _bmad-output/x.md ] && echo ok"}}]}}' "$1" "$1"; }
pb_seed wait "$pb_ai" "$(pb_beat 1)" "$(pb_beat 2)" "$(pb_beat 3)" "$(pb_beat 4)" "$(pb_edit pipeline-snapshot.md)" "$(pb_beat 5)" "$(pb_beat 6)" "$(pb_beat 7)"
PB_CELLS="snapshot resolution archive control skillupd updater recency wait"
# One string per program: the eight counts in PB_CELLS order, EMPTY for a copy that emitted nothing.
pbv() { local o="" c n; for c in $PB_CELLS; do n="$(acount "$PB/$c.jsonl")"; o="$o${n:-E}"; done; printf '%s' "$o"; }
PB_WANT=00110011
w pb-shipped "$(pbv)" "$PB_WANT" \
  "snapshot 0, nested resolution 0, archive 1, control 1, Skill(ai-dlc-update) 0, updater Edit 0, recency 1, Check C wait run across a snapshot Edit 1"
# ===========================================================================
# A LEAD'S Explore DISPATCH WHILE PAUSED IS NOT A STEAMROLL (BL-784). acknowledge.sh allows a lead
# Agent/Task call whose subagent_type is exactly "Explore", that carries no `name` and no
# `team_name` key, and whose prompt cites no `team-roles/<role>.md` (its deny text offers exactly
# that dispatch to a paused lead). Every cell is an operator message followed by ONE call, in the
# producer's tool_use shape. The near-misses each carry every property of the allowed cell but one:
#   ex-agent     Agent, Explore, plain prompt                                   0
#   ex-task      the same as Task                                               0
#   ex-noprompt  Agent, Explore, no prompt key (the hook's `// empty`)          0
#   ex-namenull  ex-agent plus "name": null (jq has("name") is true)            1
#   ex-role      ex-agent with a prompt citing team-roles/dev.md                1
#   ex-lower     ex-agent with "subagent_type":"explore"                        1
#   ex-team      ex-agent plus "team_name"                                      1
#   ex-gp        ex-agent with subagent_type general-purpose (the control)      1
#   ex-objrole   ex-agent with an OBJECT prompt citing team-roles/dev.md        1
#                (jq -r emits a non-string as JSON text, which the hook greps)
#   ex-hyphen    ex-agent with a prompt citing team-roles/a-b.md                1
echo
echo "  -- paused lead Explore dispatch (BL-784) --"
EX="$AWORK/ex"; mkdir -p "$EX"
ex_call() { printf '{"type":"assistant","timestamp":"2026-07-04T10:00:05Z","message":{"content":[{"type":"tool_use","id":"t1","name":"%s","input":%s}]}}' "$1" "$2"; }
ex_seed() { printf '%s\n' "$pb_op" "$(ex_call "$2" "$3")" > "$EX/$1.jsonl"; }
ex_seed agent    Agent '{"subagent_type":"Explore","description":"find X","prompt":"find where X is defined"}'
ex_seed task     Task  '{"subagent_type":"Explore","description":"find X","prompt":"find where X is defined"}'
ex_seed noprompt Agent '{"subagent_type":"Explore","description":"find X"}'
ex_seed namenull Agent '{"subagent_type":"Explore","description":"find X","name":null,"prompt":"find where X is defined"}'
ex_seed role     Agent '{"subagent_type":"Explore","description":"find X","prompt":"read .claude/team-roles/dev.md, then find where X is defined"}'
ex_seed lower    Agent '{"subagent_type":"explore","description":"find X","prompt":"find where X is defined"}'
ex_seed team     Agent '{"subagent_type":"Explore","description":"find X","team_name":"t","prompt":"find where X is defined"}'
ex_seed gp       Agent '{"subagent_type":"general-purpose","description":"find X","prompt":"find where X is defined"}'
ex_seed objrole  Agent '{"subagent_type":"Explore","description":"find X","prompt":{"a":"team-roles/dev.md"}}'
ex_seed hyphen   Agent '{"subagent_type":"Explore","description":"find X","prompt":"read team-roles/a-b.md, then find X"}'
EX_CELLS="agent task noprompt namenull role lower team gp objrole hyphen"
exv() { local o="" c n; for c in $EX_CELLS; do n="$(acount "$EX/$c.jsonl")"; o="$o${n:-E}"; done; printf '%s' "$o"; }
EX_WANT=0001111111
w ex-shipped "$(exv)" "$EX_WANT" \
  "Explore as Agent 0, as Task 0, with no prompt 0; name:null 1, a team-roles/dev.md prompt 1, lower-case explore 1, team_name 1, general-purpose 1, an object prompt citing a role 1, team-roles/a-b.md 1"

# ===========================================================================
# THE CLI CELLS (cells.decl). The validator run as a PROGRAM once per distinct CLI outcome: exit 0 with the --count
# integer, exit 0 with the PASS report, exit 1 with the starvation report, exit 0 MATCH, exit 2 NOMATCH and exit 1 with
# a FAIL refusal. One `FXCELL=<id> bash "$VALIDATOR"` start per outcome, each compared with the in-process call on the
# same input: stdout, stderr and exit separately, byte for byte. A cell also asserts its own outcome (a positive
# conjunct, so two runs that both printed nothing cannot read as equivalent).
echo
echo "  -- cli cells --"
EQ="$ROOT/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  sbv "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VALIDATOR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
cellspec() { # <file> <spec>: `=text` the file is exactly text, `~text` it contains text, `-` it is empty
  case "$2" in
    -)  [ ! -s "$1" ] ;;
    =*) [ "$(cat "$1")" = "${2#=}" ] ;;
    ~*) grep -qF -e "${2#\~}" "$1" ;;
    *)  return 1 ;;
  esac
}
cellok() { # <id> <want rc> <stdout spec> <stderr spec>
  [ "$(cat "$EQ/$1.cl.rc")" = "$2" ] && cellspec "$EQ/$1.cl.out" "$3" && cellspec "$EQ/$1.cl.err" "$4"
}
cell() { # <id> <want rc> <stdout pattern> <stderr pattern> <why> <args...>
  local id="$1" rc="$2" op="$3" ep="$4" why="$5"; shift 5
  if eqv "$id" "$@" && cellok "$id" "$rc" "$op" "$ep"; then ok_ "$id" "$why: the program answers exactly as the in-process call does (stdout, stderr, exit $rc)"
  else bad_ "$id" "$why: the program and the in-process call differ, or the outcome is not exit $rc ($(eq_twin "$id"))"; fi
}
cell cli-count 0 '=1' - "--count over the starving session" --transcript "$ROOT/starves/session.jsonl" --count
cell cli-pass 0 '~PASS  (D)' - "the full report over the clean session" --transcript "$ROOT/clean/session.jsonl"
cell cli-violation 1 '~PASS  (D)' '~FAIL (A -- STARVATION): ' "the full report over the starving session" --transcript "$ROOT/starves/session.jsonl"
cell cli-match 0 '~MATCH 2026-07-02T14:37:41Z' '~cite: scanned' "--cite of an authorized phrase" --dir "$AWORK/corpus" --cite "$CITE_AUTH" --authorized-at "$AUTH_TS" --quiet
cell cli-nomatch 2 '=NOMATCH' '~no genuine operator message carried it' "--cite of a phrase said weeks before the authorization" --dir "$AWORK/corpus" --cite "$CITE_OLD" --authorized-at "$AUTH_TS" --quiet
cell cli-refuse 1 - '~FAIL: dir not readable' "--dir naming a directory that does not exist" --dir "$ROOT/no-such-dir"
if ! cmp -s "$EQ/cli-match.cl.out" "$EQ/cli-nomatch.cl.out" && ! cmp -s "$EQ/cli-match.cl.rc" "$EQ/cli-nomatch.cl.rc" \
   && ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-violation.cl.rc"; then
  ok_ cli-discriminate "the passing and the refusing inputs give different stdout and exit"
else bad_ cli-discriminate "cli-match/cli-nomatch or cli-pass/cli-violation gave the same stdout or exit"; fi

if [ "$FAILURES" -eq 0 ]; then
  echo "PASS: check-25 steering-conduct fixture holds."
  exit 0
fi
echo "FAIL: $FAILURES check-25 assertion(s) failed."
exit 1
