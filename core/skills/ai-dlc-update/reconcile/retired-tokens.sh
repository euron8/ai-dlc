#!/bin/bash
#
# AI/DLC reconcile — RETIRED CONTRACT TOKENS
#
# WHY THIS EXISTS
# One class of merge defect no other detector in this directory can see: upstream
# RETIRES a shared contract -- a temp-file path, a channel, a variable -- and the
# consumer's own code, living inside the same upstream-maintained file, still
# speaks the old one. `diff3` merges it cleanly. `bash -n` passes. The result is a
# gate that cannot fire.
#
# MEASURED on the reference consumer's 0.114.0 -> 0.118.2 pull. v0.118.2 moved the
# budget scanner's channels to a per-run `mktemp -d`. The consumer's WHOLE_READ_POOL
# block -- consumer-only code upstream does not have -- kept writing its OVER verdict
# to the retired `$ROOT/.ai-dlc-budget-breach.tmp`. Writer and reader became different
# files. On a forced breach the merged script reported
# `PASS  every measured living artifact is within its Rule 25(d) budget` and exited 0
# with the pool at 1212% of its budget. It was found by hand-building a functional
# test, which is the machine's job being done by a person.
#
# The signal was ALREADY in emit-report.sh's "ONLY IN OURS" sample -- buried at
# "149 lines, 137 suppressed". The cap is what hid it. So this set is emitted
# UNCAPPED, and it is small by construction: only tokens BASE used, THEIRS
# eliminated, and OURS still references.
#
# WHAT COUNTS AS A TOKEN
# A variable-rooted path: `$VAR/some/path`. That is deliberately narrow. It is the
# shape a channel, a scratch file, or a state path takes in these scripts, and it is
# unambiguous to extract. Widening this to bare identifiers would flag every renamed
# local and drown the finding it exists to surface.
#
# COMMENTS ARE STRIPPED before matching. Upstream routinely documents a path it just
# retired -- v0.118.2's own header quotes both old paths in its explanation -- and
# flagging prose would make this fire on every release that explains itself.
#
# WHAT IT DOES NOT CATCH, STATED PLAINLY
# A consumer path that upstream never had. In the motivating case the consumer's
# `POOL_TMP="$ROOT/.ai-dlc-pool.tmp"` is invisible here, because BASE never contained
# it -- there is no retirement to detect. That one is hygiene (a killed run leaves it
# behind); the one this catches is correctness (the gate goes silent). Do not read a
# clean result as "the merge is semantically complete."
#
# USAGE
#   retired-tokens.sh <dist> <base> <theirs> <consumer> [<path>]
#
#   With <path>, restrict to that one repo-relative core path.
#
# OUTPUT  (TAB-delimited, the same contract as its sibling detectors)
#   RETIRED-CONTRACT-TOKEN<TAB><core-path><TAB><token>
#
# STDERR
#   A run that opened no core file says so, in one NOTE line, because its stdout is
#   byte-identical to a run that scanned every CLASSIFY file and found nothing. The
#   0.410.0 -> 0.412.0 reference-consumer pull bucketed every path ALREADY-AT-THEIRS,
#   the CLASSIFY set was empty, and this script exited 0 with zero rows -- read as a
#   clean scan. Any bucket set with no CLASSIFY member produces the same state: on the
#   same consumer's 0.504.0 -> 0.508.0 range it is UPSTREAM-ONLY paths (the consumer
#   never touched them), not ALREADY-AT-THEIRS, so read the NOTE's counts and not this
#   header for the cause. Its siblings carried a NOTE for the same state; this one did not. A
#   run that opened files and matched nothing states its denominator for the same
#   reason. A run where preclassify.sh listed nothing at all -- an empty range, a bad
#   ref, an unreadable dist -- is refused rather than read as clean; no program caller
#   can reach that state (both call from inside a CLASSIFY case arm), so the by-hand
#   run is its only reader. A run that produced rows says nothing on stderr: the rows
#   are the answer.
#   Both program callers (`apply.sh`, `emit-report.sh`) discard stderr and read the
#   rows only; the NOTE is for the operator running step 3a-ii by hand.
#
# EXIT
#   0  always (a detector reports; the caller decides)

set -u

DIST="${1:?usage: retired-tokens.sh <dist> <base> <theirs> <consumer> [<path>]}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"
ONLY="${5:-}"

SELF="$(cd "$(dirname "$0")" && pwd)"

# Live `$VAR/path` tokens on stdin, comments stripped, sorted unique.
toks() {
  grep -vE '^[[:space:]]*#' \
  | grep -oE '\$[A-Za-z_][A-Za-z0-9_]*/[A-Za-z0-9._/-]+' \
  | sort -u
}

# The limit a quiet run must restate, because the operator reads the RUN and never this
# header. Every NOTE below carries it.
LIMIT='A consumer path upstream never had is outside this detector BY DESIGN (there is no retirement to detect) -- this zero does not cover it.'

# The subject set is captured ONCE, outside the loop, so the run can count what it
# opened: a counter kept in a pipeline's last stage is lost to its subshell.
ROWS="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"

# preclassify.sh emitting NOTHING has three causes and this script cannot tell them
# apart: no file under a mapped core path moved between base and theirs (a docs-only
# release, or base == theirs), a ref that did not resolve, or an unreadable dist. All
# three mean NO core file was scanned. Refuse to read it as clean -- "no rows" and "no
# retired token" are the same stdout -- and name every cause, because a refusal that
# lists only the exotic ones misdiagnoses the common one.
if [ -z "$ROWS" ]; then
  echo "retired-tokens: preclassify.sh produced no rows for ${BASE}..${THEIRS} (no file under a mapped core path moved between them, a ref did not resolve, or the dist is unreadable) -- refusing to report clean, because 'no rows' and 'no retired token' are the same output. $LIMIT" >&2
  exit 0
fi

SUBJECT="$(printf '%s\n' "$ROWS" | awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2"\t"$3}' | sort -u)"

listed=0; opened=0; retiring=0; rows=""
while IFS="$(printf '\t')" read -r cp cons; do
  [ -n "${cp:-}" ] || continue
  [ -z "$ONLY" ] || [ "$ONLY" = "$cp" ] || continue
  listed=$((listed + 1))

  ours="$CONSUMER/$cons"
  [ -f "$ours" ] || continue

  b="$(git -C "$DIST" show "${BASE}:${cp}" 2>/dev/null || true)"
  t="$(git -C "$DIST" show "${THEIRS}:${cp}" 2>/dev/null || true)"
  [ -n "$b" ] && [ -n "$t" ] || continue
  opened=$((opened + 1))

  # base tokens MINUS theirs tokens = what upstream retired.
  # Intersected with ours = what the consumer still speaks.
  retired="$(comm -23 <(printf '%s\n' "$b" | toks) <(printf '%s\n' "$t" | toks))"
  [ -n "$retired" ] || continue
  retiring=$((retiring + 1))

  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    rows="$rows$(printf 'RETIRED-CONTRACT-TOKEN\t%s\t%s' "$cp" "$tok")
"
  done < <(comm -12 <(printf '%s\n' "$retired") <(toks < "$ours"))
done < <(printf '%s\n' "$SUBJECT")

if [ -n "$rows" ]; then
  printf '%s' "$rows"
  exit 0
fi

# A ZERO THAT NEVER OPENED A FILE MUST NOT READ LIKE A ZERO THAT SCANNED EVERYTHING.
# Two quiet states, and they are different findings. Opened nothing: the pull listed no
# CLASSIFY file (every path ALREADY-AT-THEIRS, the measured case), or listed some and
# none was readable on all three sides -- either way this run scanned no core file and
# is SILENT about retired contract tokens, which is not a finding of none. Opened some
# and matched nothing: a real result, stated with its denominator.
if [ "$opened" -eq 0 ]; then
  echo "retired-tokens: NOTE -- this pull listed $listed CLASSIFY file(s)${ONLY:+ at $ONLY} and opened NONE, so NO core file was scanned. This run is SILENT about retired contract tokens, not a finding of none. $LIMIT" >&2
else
  # Both counts, always: a pull that lists many and opens one is a partial scan, and
  # "1 opened" alone reads as a complete scan of a one-file pull.
  echo "retired-tokens: NOTE -- $opened of $listed CLASSIFY file(s) opened, $retiring carrying a token upstream retired; no consumer reference to a retired token. $LIMIT" >&2
fi

exit 0
