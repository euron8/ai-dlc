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
# WHY A WINDOW AND NOT AN EQUALITY, and why the exact compare is seeded as a
# MUTANT below: over the reference consumer's 26 authorization rows the gap
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
cat > "$AWORK/corpus/a-monday.jsonl" <<'JSONL'
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

# rc AND stdout from one invocation. `cmd | grep` takes grep's status, and --cite exits 2 on
# NOMATCH, so the two have to be captured together.
acite() { # acite <validator> <quote> [<authorized-at>] -> prints "<verdict>/<rc>"
  local v="$1" q="$2" at="${3:-}" o r
  if [ -n "$at" ]; then
    o="$(bash "$v" --dir "$AWORK/corpus" --cite "$q" --authorized-at "$at" --quiet 2>/dev/null)"; r=$?
  else
    o="$(bash "$v" --dir "$AWORK/corpus" --cite "$q" --quiet 2>/dev/null)"; r=$?
  fi
  printf '%s/%s' "${o:-EMPTY}" "$r"
}
acount() { bash "$1" --transcript "$2" --count 2>/dev/null; }

w() { # w <name> <got> <want> <why>
  if [ "$2" = "$3" ]; then ok_ "$1" "$4"; else bad_ "$1" "got '$2', want '$3' -- $4"; fi
}

# --- W1: the two-file corpus, bounded, with a ROUNDED authorization timestamp --
w two-file-rounded "$(acite "$VALIDATOR" "$CITE_AUTH" "$AUTH_TS")" "MATCH 2026-07-02T14:37:41Z/0" \
  "a genuine turn 41s after a minute-rounded authorization time still verifies, and it is in the corpus's SECOND file"

# --- W2: the same corpus, a phrase said a WEEK from the cited moment ----------
w said-elsewhere "$(acite "$VALIDATOR" "$CITE_LATER" "$AUTH_TS")" "NOMATCH/2" \
  "words the operator really said, seven days from the moment this citation claims, do not verify it"

# --- W2c: THE DISCRIMINATOR for W2. Same quote, same corpus, no bound ---------
# Without this the NOMATCH above is indistinguishable from a corpus that does not hold the
# words at all, which is what every pre-bound arm in this file would have reported.
w said-elsewhere-unbounded "$(acite "$VALIDATOR" "$CITE_LATER")" "MATCH 2026-07-09T11:02:13Z/0" \
  "unbounded, that same phrase verifies -- so W2's NOMATCH came from the WINDOW and not from the corpus"

# --- W2d: the NOMATCH says WHICH of the two findings it is -------------------
# "nothing carried these words" and "the operator said them at another moment" are different
# facts and a reader cannot act on them alike. The exit code is 2 either way.
W2D="$(bash "$VALIDATOR" --dir "$AWORK/corpus" --cite "$CITE_LATER" --authorized-at "$AUTH_TS" --quiet 2>&1)"
if has "carried it outside the" "$W2D" && has "$AUTH_TS" "$W2D"; then
  ok_ nomatch-names-the-window "the out-of-window NOMATCH says the words WERE said, and names the cited authorization time"
else
  bad_ nomatch-names-the-window "the diagnostic does not separate 'never said' from 'said at another moment': $W2D"
fi

# --- W3: a harness injection is not an operator turn -------------------------
w ismeta-not-citable "$(acite "$VALIDATOR" "$CITE_META")" "NOMATCH/2" \
  "an isMeta:true record's text does not verify a citation, however operator-shaped its bytes are"

# --- W3b: the ALLOW twin, ONE PROPERTY APART ---------------------------------
# Same file, same record shape, same neighbourhood; only the isMeta key differs. Without it,
# W3 passes identically against a predicate that rejects everything in this corpus.
w typed-still-citable "$(acite "$VALIDATOR" "$CITE_TYPED")" "MATCH 2026-07-02T14:39:00Z/0" \
  "the same record without isMeta still verifies -- W3 discriminates on the flag, not on the file"

# --- W4: an unparseable bound is REFUSED, never dropped ----------------------
# Silently ignoring it hands back a fully unbounded verify wearing a bounded one's exit code.
W4="$(bash "$VALIDATOR" --dir "$AWORK/corpus" --cite "$CITE_AUTH" --authorized-at "yesterday afternoon" --quiet 2>&1)"; W4RC=$?
if [ "$W4RC" -ne 0 ] && [ "$W4RC" -ne 2 ] && has "authorized-at" "$W4"; then
  ok_ bad-bound-refused "an --authorized-at that will not parse exits ${W4RC} (neither MATCH nor NOMATCH) and names the flag"
else
  bad_ bad-bound-refused "an unparseable bound produced rc=$W4RC -- a caller reading 0/2 cannot tell it from a verdict: $W4"
fi

# --- W5: the bound has no meaning without --cite -----------------------------
bash "$VALIDATOR" --dir "$AWORK/corpus" --authorized-at "$AUTH_TS" --quiet >/dev/null 2>&1
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
w checkb-ignores-ismeta "$(acount "$VALIDATOR" "$AWORK/bmeta/session.jsonl")" "0" \
  "a harness injection followed by an Agent dispatch is not a steamroll"
w checkb-counts-typed "$(acount "$VALIDATOR" "$AWORK/btyped/session.jsonl")" "1" \
  "the SAME two records without isMeta still count as one -- W6 discriminates on the flag"

# ===========================================================================
# MUTANTS. Every arm above is a claim about one line of the predicate, and an
# exit code cannot say which line produced it. Each mutant is a COPY, guarded by
# `cmp -s` (a sed that matched nothing must not pass as a mutation) and `bash -n`
# (a mutant that is no longer a program emits nothing, and every NOMATCH arm
# above would score that as a kill).
echo
echo "  -- mutants --"
MWORK="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$CORPA" "$CORPB" "$AWORK" "$MWORK"' EXIT
KILLS=0
# SETS A GLOBAL RATHER THAN PRINTING. A builder called inside `$( )` reports its refusal into
# a subshell: the failure count is lost, the caller gets an empty path, and `if [ -n "$M" ]`
# then SKIPS every arm that mutant owns with no verdict at all -- which reads exactly like a
# clean run. MUTP is the answer and the refusal is scored here, in this shell.
MUTP=""
mut() { # mut <name> <sed-expr> -> 0 and MUTP set, or 1 with the refusal already reported
  MUTP=""
  local name="$1"
  local expr="$2"
  local p="$MWORK/m-$name.sh"
  sed "$expr" "$VALIDATOR" > "$p" || { bad_ "mutant-$name" "sed DID NOT APPLY -- a mutation that dies is a mutant that never existed"; return 1; }
  if cmp -s "$VALIDATOR" "$p"; then
    bad_ "mutant-$name" "changed no bytes -- its anchor is gone, and a no-op mutant scores every NOMATCH arm as a kill"; return 1
  fi
  bash -n "$p" 2>/dev/null || { bad_ "mutant-$name" "does not parse; its silence would score as a kill"; return 1; }
  MUTP="$p"
}
kill_() { KILLS=$((KILLS + 1)); ok_ "$1" "$2"; }
mw() { # mw <name> <mutant> <quote> <at-or-empty> <want> <kill|hold> <why>
  local got; got="$(acite "$2" "$3" "$4")"
  if [ "$got" = "$5" ]; then
    case "$6" in kill) kill_ "$1" "$7" ;; *) ok_ "$1" "$7" ;; esac
  else
    bad_ "$1" "got '$got', want '$5' -- $7"
  fi
}

# CONTROL. An unmutated copy in the same directory must reproduce the baseline, or neither
# mutant result means anything -- and it must reproduce it POSITIVELY, because a copy that
# died before reaching node emits nothing and every NOMATCH expectation would accept that.
MCTL="$MWORK/control.sh"
cp "$VALIDATOR" "$MCTL"
mw control-match "$MCTL" "$CITE_AUTH" "$AUTH_TS" "MATCH 2026-07-02T14:37:41Z/0" hold \
  "control: an unmutated copy still MATCHes the bounded citation, so the copies below can run"
mw control-meta "$MCTL" "$CITE_META" "" "NOMATCH/2" hold \
  "control: the unmutated copy still refuses the harness injection"

# MUTANT A -- the isMeta arm removed. Kill set: {ismeta-not-citable, checkb-ignores-ismeta}.
mut no-ismeta 's|^  if (r.isMeta === true) return "";$||'
MA="$MUTP"
if [ -n "$MA" ]; then
  mw A-meta-cites "$MA" "$CITE_META" "" "MATCH 2026-07-02T14:38:00Z/0" kill \
    "A: without the isMeta arm a harness injection cites -- W3 has teeth"
  if [ "$(acount "$MA" "$AWORK/bmeta/session.jsonl")" = "1" ]; then
    kill_ A-checkb-counts-meta "A: Check B counts the injection as a steamroll too -- the arm is shared, as W6 asserts"
  else
    bad_ A-checkb-counts-meta "A: Check B did not move, so W6 is not testing the shared arm"
  fi
  mw A-window-holds "$MA" "$CITE_LATER" "$AUTH_TS" "NOMATCH/2" hold "A: the window arm is unmoved -- the two subjects are not entangled"
  mw A-typed-holds  "$MA" "$CITE_TYPED" "" "MATCH 2026-07-02T14:39:00Z/0" hold "A: the typed twin is unmoved"
fi

# MUTANT B -- THE WRONG FIX: an EXACT timestamp compare instead of a window. It repairs
# `said-elsewhere` (which is why it reads as a fix) and destroys every rounded citation, which
# on the reference consumer is 22 of the 24 rows that verify today.
mut exact-ts-compare 's|Math.abs(ts - authMs) > authTolMs|ts !== authMs|'
MB="$MUTP"
if [ -n "$MB" ]; then
  mw B-rounded-dies "$MB" "$CITE_AUTH" "$AUTH_TS" "NOMATCH/2" kill \
    "B: an exact compare NOMATCHes a genuine citation whose timestamp was rounded to the minute -- W1 has teeth"
  mw B-window-holds "$MB" "$CITE_LATER" "$AUTH_TS" "NOMATCH/2" hold \
    "B: said-elsewhere is unmoved, which is exactly why this wrong fix reads as a fix"
  mw B-meta-holds "$MB" "$CITE_META" "" "NOMATCH/2" hold "B: the isMeta arm is unmoved"
fi

# MUTANT C -- the bound is computed and never applied. Kill set: {said-elsewhere}.
mut bound-not-applied 's|if (authMs !== null \&\& Math.abs(ts - authMs) > authTolMs) {|if (false) {|'
MC="$MUTP"
if [ -n "$MC" ]; then
  mw C-elsewhere-cites "$MC" "$CITE_LATER" "$AUTH_TS" "MATCH 2026-07-09T11:02:13Z/0" kill \
    "C: with the window never applied, a phrase from another week verifies -- W2 has teeth"
  mw C-rounded-holds "$MC" "$CITE_AUTH" "$AUTH_TS" "MATCH 2026-07-02T14:37:41Z/0" hold "C: W1 is unmoved"
  mw C-meta-holds "$MC" "$CITE_META" "" "NOMATCH/2" hold "C: the isMeta arm is unmoved"
fi

# MUTANT D -- an unparseable bound is DROPPED instead of refused. Kill set: {bad-bound-refused}.
# The shape a hurried fix takes, and the one that cannot be seen from an exit code: the scan
# runs unbounded and answers 0 or 2 exactly as a bounded one would.
mut bad-bound-ignored 's|^    if (Number.isNaN(authMs)) {$|    if (false) {|'
MD="$MUTP"
if [ -n "$MD" ]; then
  MDO="$(bash "$MD" --dir "$AWORK/corpus" --cite "$CITE_AUTH" --authorized-at "yesterday afternoon" --quiet 2>&1)"; MDRC=$?
  if [ "$MDRC" -eq 0 ] || [ "$MDRC" -eq 2 ]; then
    kill_ D-bad-bound-verdict "D: a bound that will not parse now answers with a VERDICT (rc=$MDRC) -- W4 has teeth"
  else
    bad_ D-bad-bound-verdict "D: rc=$MDRC, so W4 is not testing the refusal: $MDO"
  fi
  mw D-window-holds "$MD" "$CITE_LATER" "$AUTH_TS" "NOMATCH/2" hold "D: a parseable bound still binds"
fi

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
W7O="$(AI_DLC_CITE_AUTH_TOLERANCE_S=1000000000 bash "$VALIDATOR" --dir "$AWORK/corpus" --cite "$CITE_LATER" --authorized-at "$AUTH_TS" --quiet 2>/dev/null)"; W7RC=$?
w tolerance-not-overridable "${W7O:-EMPTY}/$W7RC" "NOMATCH/2" \
  "a phrase said a week away still NOMATCHes with AI_DLC_CITE_AUTH_TOLERANCE_S=10^9 exported -- the window is a literal in the program"
# The ALLOW twin, one property apart: the same environment must not break a genuine citation
# either. Without it this arm passes against a build that refuses everything.
W7B="$(AI_DLC_CITE_AUTH_TOLERANCE_S=1000000000 bash "$VALIDATOR" --dir "$AWORK/corpus" --cite "$CITE_AUTH" --authorized-at "$AUTH_TS" --quiet 2>/dev/null)"; W7BRC=$?
w tolerance-env-harmless "${W7B:-EMPTY}/$W7BRC" "MATCH 2026-07-02T14:37:41Z/0" \
  "the same environment leaves a genuine in-window citation verifying -- W7 discriminates on the window, not on the run failing"

# MUTANT E -- THE OVERRIDE RESTORED, exactly as it was written for one revision: the constant
# read from the environment with 7200 as a default. Kill set: {tolerance-not-overridable}.
# Nothing else moves, because with the variable unset the mutant and the shipping program are
# the same program -- which is precisely why an overridable bound is invisible to every arm
# that does not export it, and why this mutant has to.
mut env-overridable-tolerance 's|^const CITE_AUTH_TOLERANCE_S = 7200;$|const CITE_AUTH_TOLERANCE_S = +(process.env.AI_DLC_CITE_AUTH_TOLERANCE_S \|\| 7200);|'
ME="$MUTP"
if [ -n "$ME" ]; then
  MEO="$(AI_DLC_CITE_AUTH_TOLERANCE_S=1000000000 bash "$ME" --dir "$AWORK/corpus" --cite "$CITE_LATER" --authorized-at "$AUTH_TS" --quiet 2>/dev/null)"; MERC=$?
  if [ "${MEO:-EMPTY}/$MERC" = "MATCH 2026-07-09T11:02:13Z/0" ]; then
    kill_ E-env-widens-window "E: with the override restored, one exported variable makes a week-away phrase verify -- W7 has teeth"
  else
    bad_ E-env-widens-window "E: got '${MEO:-EMPTY}/$MERC', want 'MATCH 2026-07-09T11:02:13Z/0' -- W7 is not testing the override"
  fi
  # And the mutant is INDISTINGUISHABLE from the shipping program without the variable, which
  # is the whole hazard: no other arm in this file can see it.
  mw E-unset-holds "$ME" "$CITE_LATER" "$AUTH_TS" "NOMATCH/2" hold \
    "E: with the variable unset the mutant behaves identically -- an overridable bound is invisible to every arm that does not export it"
  mw E-meta-holds "$ME" "$CITE_META" "" "NOMATCH/2" hold "E: the isMeta arm is unmoved"
fi

# KILL COUNT. A mutation that applied cleanly to a file this run never loaded reads exactly
# like an arm that cannot fire, and `cmp -s` cannot tell them apart. Zero kills is that state.
if [ "$KILLS" -ge 6 ]; then
  ok_ KILL-COUNT "$KILLS mutant kill(s) -- the arms above can fire"
else
  bad_ KILL-COUNT "$KILLS kill(s); the mutants changed bytes in a file these arms never loaded"
fi

if [ "$FAILURES" -eq 0 ]; then
  echo "PASS: check-25 steering-conduct fixture holds (3 cases + count contract + 9 identity arms + provenance window/isMeta arms + 5 mutants)."
  exit 0
fi
echo "FAIL: $FAILURES check-25 assertion(s) failed."
exit 1
