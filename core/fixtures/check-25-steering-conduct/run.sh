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
# takes the first that exists, so a mutation applied to the OTHER copy leaves every
# arm green while a `cmp -s` guard reports the mutation applied cleanly. Print what was
# actually loaded, so a battery can read it back.
printf 'subject: %s\n' "$VALIDATOR"

command -v node >/dev/null 2>&1 || { echo "SKIP: node is required for check-25"; exit 0; }

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT

FAILURES=0

expect_count() { # $1 case-dir  $2 expected count  $3 why
  local got
  got="$(bash "$VALIDATOR" --transcript "$ROOT/$1/session.jsonl" --count 2>/dev/null)"
  if [ "$got" != "$2" ]; then
    echo "FAIL [$1]: --count returned '$got', expected '$2' -- $3"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: count=$got  ($3)"
  fi
}

expect_status() { # $1 case-dir  $2 expected exit  $3 why
  bash "$VALIDATOR" --transcript "$ROOT/$1/session.jsonl" --quiet >/dev/null 2>&1
  local rc=$?
  if [ "$rc" != "$2" ]; then
    echo "FAIL [$1]: exit $rc, expected $2 -- $3"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: exit=$rc  ($3)"
  fi
}

expect_count starves      1 "an unbounded foreground poll loop is one Check A starvation"
expect_count clean        0 "a bounded beat through wait-for-deliverable.sh starves nobody"
expect_count backgrounded 0 "DECOY: run_in_background yields a tool boundary at once -- not starvation"

expect_status starves      1 "the validator itself must still FAIL on the starving session"
expect_status clean        0 "and PASS on the clean one"
expect_status backgrounded 0 "and PASS on the backgrounded decoy"

# --count must be a pure integer on stdout and exit 0 even when violations exist --
# Check 25 reads it directly, and a `cmd | grep` would take grep's exit status.
raw="$(bash "$VALIDATOR" --transcript "$ROOT/starves/session.jsonl" --count 2>/dev/null; echo "rc=$?")"
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
OA="$(bash "$VALIDATOR" --transcript "$CORPA/alpha-session.jsonl" 2>&1)"; ra=$?
OB="$(bash "$VALIDATOR" --transcript "$CORPB/alpha-session.jsonl" 2>&1)"; rb=$?
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
OC="$(bash "$VALIDATOR" --dir "$CORPA" 2>&1)"; rc1=$?
OD="$(bash "$VALIDATOR" --dir "$CORPB" 2>&1)"; rd1=$?
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
# steps/retro.md:618 reads `transcripts scanned : N` BY LABEL and requires N > 1
# on any sprint that handed off. A byte change on that line breaks a live gate,
# so identity goes on a line AFTER it and this arm pins its bytes.
if grep -qxF "transcripts scanned : 1" <<<"$OA" && grep -qxF "transcripts scanned : 2" <<<"$OC"; then
  ok_ scanned-line-bytes "'transcripts scanned : N' is byte-unchanged and still a bare count (retro.md reads it by label)"
else
  bad_ scanned-line-bytes "'transcripts scanned : N' changed bytes -- steps/retro.md:618 reads this line by label"
fi

# --- id-cite-match: the MATCH diagnostic names its corpus --------------------
# --cite is THE genuine-operator predicate; validate-adversarial-convergence.sh,
# validate-escalation-resolution.sh and ai-dlc-gate-remediation-guard.sh all
# delegate "a real human said this" to it. Its stdout (MATCH <ts>) is identical
# across the two corpora BY CONSTRUCTION -- the timestamps match -- so the
# discrimination has to come from the diagnostic on stderr, and these arms
# capture both streams.
OE="$(bash "$VALIDATOR" --dir "$CORPA" --cite "$CITE_PHRASE" 2>&1)"; re1=$?
OF="$(bash "$VALIDATOR" --dir "$CORPB" --cite "$CITE_PHRASE" 2>&1)"; rf1=$?
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
OG="$(bash "$VALIDATOR" --dir "$CORPA" --cite "$NO_SUCH" 2>&1)"; rg1=$?
OH="$(bash "$VALIDATOR" --dir "$CORPB" --cite "$NO_SUCH" 2>&1)"; rh1=$?
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
OI="$(bash "$VALIDATOR" --dir "$CORPA/zero" --cite "$NO_SUCH" 2>&1)"; ri1=$?
OJ="$(bash "$VALIDATOR" --dir "$CORPB/zero" --cite "$NO_SUCH" 2>&1)"; rj1=$?
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
# --count is a bare integer BY CONTRACT (steps/gate-validation.md:1665 reads it
# directly). It is the one output path that must stay identity-free, so this arm
# asserts the two corpora are INDISTINGUISHABLE here -- the inverse of every arm
# above -- with the expected integer as its positive conjunct.
CA="$(bash "$VALIDATOR" --dir "$CORPA" --count 2>/dev/null)"; rca=$?
CB="$(bash "$VALIDATOR" --dir "$CORPB" --count 2>/dev/null)"
if [ "$rca" = 0 ] && [ "$CA" = "0" ] && [ "$CB" = "0" ]; then
  ok_ count-carries-no-identity "--count is still a bare integer on both corpora and carries no path"
else
  bad_ count-carries-no-identity "--count must print a bare integer and nothing else; got '$CA'/'$CB' rc=$rca"
fi

# --- quiet-suppresses-identity: what must NOT change -------------------------
# --quiet suppresses the LOG block, and the new identity line lives in it. The
# FAIL diagnostics are console.error and are NOT suppressed, so the positive
# conjunct is that the STARVATION row is still there.
QO="$(bash "$VALIDATOR" --transcript "$ROOT/starves/session.jsonl" --quiet 2>/dev/null)"; qrc=$?
QE="$(bash "$VALIDATOR" --transcript "$ROOT/starves/session.jsonl" --quiet 2>&1 >/dev/null)"
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
OM="$(bash "$VALIDATOR" --dir "$CORPA/none" 2>&1)"; rm1=$?
ON="$(bash "$VALIDATOR" --dir "$CORPB/none" 2>&1)"
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
# steps/retro.md:613-616 invokes `--dir <slug> --since <sprint start>`. When the
# window excludes every member the file list is empty and the same `(none)`
# branch runs, so the audit the retro records cannot say which project directory
# it was pointed at. Same owner as the arm above; one fix closes both.
SINCE_CUT="2026-01-01T00:00:00Z"
OP="$(bash "$VALIDATOR" --dir "$CORPA/old" --since "$SINCE_CUT" 2>&1)"; rp1=$?
OQ="$(bash "$VALIDATOR" --dir "$CORPB/old" --since "$SINCE_CUT" 2>&1)"
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

if [ "$FAILURES" -eq 0 ]; then
  echo "PASS: check-25 steering-conduct fixture holds (3 cases + count contract + 9 identity arms)."
  exit 0
fi
echo "FAIL: $FAILURES check-25 assertion(s) failed."
exit 1
