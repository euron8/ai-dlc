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
#   `emit-report.sh` discards stderr and reads the rows and the exit. `apply.sh` stages
#   stderr beside the rows and, on a non-zero exit, quotes its first `: REFUSED` line
#   (else its line 1) in `DECISION retired-tokens-refused`; on exit 0 it reads the rows
#   only. The NOTE is for the operator running step 3a-ii by hand.
#
# EXIT
#   0  always when it ran (a detector reports; the caller decides)
#   2  a producer this detector reads did not run -- a refusal, never a finding or a clean

set -u

BUCKET_ROWS=""
while [ "$#" -gt 0 ]; do
  case "${1:-}" in
    --bucket-rows) BUCKET_ROWS="${2:-}"; shift 2 ;;
    --bucket-rows=*) BUCKET_ROWS="${1#--bucket-rows=}"; shift ;;
    *) break ;;
  esac
done

DIST="${1:?usage: retired-tokens.sh [--bucket-rows <file>] <dist> <base> <theirs> <consumer> [<path>]}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"
ONLY="${5:-}"

SELF="$(cd "$(dirname "$0")" && pwd)"

# Live `$VAR/path` tokens on stdin, comments stripped, sorted unique.
#
# EACH GREP'S STATUS IS READ ON ITS OWN. This was one pipeline, read under pipefail by a caller
# accepting 0 or 1: a comment strip that DIED (2) handed the token grep empty input, whose 1
# became the status, and the dead scan was accepted as "no token". Now a 1 from either grep is an
# empty set (status 0), and anything above 1 -- or a failed sort -- is returned.
toks() {
  local _code _t _rc=0
  _code="$(grep -vE '^[[:space:]]*#')" || _rc=$?
  [ "$_rc" -le 1 ] || return "$_rc"
  [ -n "$_code" ] || return 0
  _t="$(printf '%s\n' "$_code" | grep -oE '\$[A-Za-z_][A-Za-z0-9_]*/[A-Za-z0-9._/-]+')" || _rc=$?
  [ "$_rc" -le 1 ] || return "$_rc"
  [ -n "$_t" ] || return 0
  printf '%s\n' "$_t" | sort -u
}

# The limit a quiet run must restate, because the operator reads the RUN and never this
# header. Every NOTE below carries it.
LIMIT='A consumer path upstream never had is outside this detector BY DESIGN (there is no retirement to detect) -- this zero does not cover it.'

# The subject set is captured ONCE, outside the loop, so the run can count what it
# opened: a counter kept in a pipeline's last stage is lost to its subshell.
ROWS=""
if [ -n "$BUCKET_ROWS" ] && [ -s "$BUCKET_ROWS" ]; then
  ROWS="$(cat "$BUCKET_ROWS" 2>/dev/null || true)"
fi
if [ -z "$ROWS" ]; then
  ROWS="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"
fi

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

# EVERY SET OPERAND AND LOOP FEED BELOW IS STAGED TO A FILE AND ITS PRODUCER'S STATUS IS READ.
# They used to read `comm <(…) <(…)` and `done < <(…)`, which discard the status: a failed token
# scan of theirs read as "theirs has no token", so every base token read as retired, and a failed
# scan of the consumer's file read as "the consumer speaks none of them" -- the second is a false
# clear on the one row this detector exists to print. This file does not set `pipefail`; each
# token scan runs inside `( set -o pipefail; … )`, where `toks`' greps exit 1 on a text carrying
# no token -- a healthy empty set -- so 0 and 1 are accepted and anything else refuses with exit
# 2, which emit-report.sh renders as DETECTOR-REFUSED. One directory per run, removed on exit.
RT_T="$(mktemp -d "${TMPDIR:-/tmp}/retired-tokens.XXXXXX")" || {
  echo "retired-tokens: the staging directory did not run (mktemp failed); no verdict" >&2
  exit 2
}
trap 'rm -rf "$RT_T"' EXIT
rt_refuse() { # rt_refuse <what> <status>
  echo "retired-tokens: $1 did not run (exit $2); no verdict" >&2
  exit 2
}
rt_toks() { # rt_toks <what> <out> -- toks of stdin into <out>; 0 and 1 accepted
  local rc=0
  ( set -o pipefail; toks ) > "$2" || rc=$?
  case "$rc" in 0|1) return 0 ;; esac
  rt_refuse "the token scan of $1" "$rc"
}
printf '%s\n' "$SUBJECT" > "$RT_T/subject" || rt_refuse "staging the CLASSIFY subject list" "$?"

# THE BLOB READS ARE STAGED AND THEIR STATUS IS READ. They used to be `$(git show … || true)`, so a
# ref side git could not read came back as an EMPTY file: the path was skipped as though absent,
# or -- one side read, the other not -- the tokens of the readable side were subtracted from
# nothing. Two states are legitimate and both are an empty listing, never a failed one: a path
# ABSENT at base or at theirs, which preclassify's BOTH-ADDED and UPSTREAM-DELETED CLASSIFY
# buckets produce by construction. `git cat-file -e` cannot separate that from a failed read --
# it answers 128 for an absent path, a bad ref and no repository alike -- so both refs are
# verified ONCE here, and per path an `ls-tree` listing decides presence: its failure refuses,
# its empty answer is the absent skip, and a present path whose `show` fails refuses.
for _rt_ref in "$BASE" "$THEIRS"; do
  _rt_rc=0
  git -C "$DIST" rev-parse -q --verify "${_rt_ref}^{commit}" > "$RT_T/ref-verify" 2>/dev/null || _rt_rc=$?
  [ "$_rt_rc" -eq 0 ] || rt_refuse "resolving ${_rt_ref} to a commit in $DIST" "$_rt_rc"
done
rt_blob() { # rt_blob <ref> <path> <out> -- 0 staged into <out>; 1 absent at <ref>; refuses otherwise
  local rc=0 l present=""
  # `core.quotePath=false` BECAUSE THE COMPARISON BELOW IS AGAINST THE RAW PATH. Under the default,
  # ls-tree C-quotes a path carrying a non-ASCII byte (`"caf\303\251.sh"`), the exact-line test
  # never matches, and the path reads as absent: its row was lost at rc 0. An ASCII path lists
  # identically either way. This is hardening only -- the CLASSIFY rows this reads come from a
  # producer that quotes such a path upstream, so that row is lost before it gets here.
  git -C "$DIST" -c core.quotePath=false ls-tree --name-only "$1" -- "$2" > "$3.ls" 2>/dev/null || rc=$?
  [ "$rc" -eq 0 ] || rt_refuse "listing $2 at $1" "$rc"
  # ls-tree matches a pathspec by prefix, so presence is an EXACT line, never a non-empty file.
  while IFS= read -r l; do
    [ "$l" = "$2" ] && { present=yes; break; }
  done < "$3.ls"
  [ -n "$present" ] || return 1
  git -C "$DIST" show "${1}:${2}" > "$3" 2>/dev/null || rc=$?
  [ "$rc" -eq 0 ] || rt_refuse "reading $2 at $1" "$rc"
  return 0
}

listed=0; opened=0; retiring=0; rows=""
while IFS="$(printf '\t')" read -r cp cons; do
  [ -n "${cp:-}" ] || continue
  [ -z "$ONLY" ] || [ "$ONLY" = "$cp" ] || continue
  listed=$((listed + 1))

  ours="$CONSUMER/$cons"
  [ -f "$ours" ] || continue

  rt_blob "$BASE" "$cp" "$RT_T/blob-base" || continue
  rt_blob "$THEIRS" "$cp" "$RT_T/blob-theirs" || continue
  b="$(cat "$RT_T/blob-base")" || rt_refuse "reading the staged base blob of $cp" "$?"
  t="$(cat "$RT_T/blob-theirs")" || rt_refuse "reading the staged theirs blob of $cp" "$?"
  [ -n "$b" ] && [ -n "$t" ] || continue
  opened=$((opened + 1))

  # base tokens MINUS theirs tokens = what upstream retired.
  # Intersected with ours = what the consumer still speaks.
  # FED FROM THE BLOBS `rt_blob` ALREADY STAGED, NEVER A PIPE AND NEVER A HERE-STRING. A pipe is
  # wrong because rt_toks refuses with `exit`, which in a pipeline stage would end only that
  # stage's subshell. A here-string is wrong because bash 3.2 stages it to a temp file, and when
  # that write fails -- `ulimit -f`, a full TMPDIR -- the command does not run at all: rt_toks'
  # redirect never truncates `toks-*`, so the PREVIOUS path's token files were read as this
  # path's. Measured with a 16384-byte blob under `ulimit -f 16`, SIGXFSZ ignored: rc 0 with a
  # FALSE row (the other path's retired token attributed here) and the true row lost. Reading the
  # staged file yields the same token set `<<<"$b"` did: `toks` captures with `$( )`, which drops
  # the trailing newlines the file keeps and `$b` lost, and `git show` wrote these bytes itself.
  # `< file` failing to open is a redirect failure the command never runs past, so it refuses
  # here too, with the same exit 2.
  rt_toks "${cp}@${BASE}" "$RT_T/toks-base" < "$RT_T/blob-base" || rt_refuse "reading the staged base blob of $cp" "$?"
  rt_toks "${cp}@${THEIRS}" "$RT_T/toks-theirs" < "$RT_T/blob-theirs" || rt_refuse "reading the staged theirs blob of $cp" "$?"
  retired="$(comm -23 "$RT_T/toks-base" "$RT_T/toks-theirs")" || rt_refuse "the retired-token subtraction for $cp" "$?"
  [ -n "$retired" ] || continue
  retiring=$((retiring + 1))

  printf '%s\n' "$retired" > "$RT_T/retired" || rt_refuse "staging the retired tokens of $cp" "$?"
  rt_toks "$cons" "$RT_T/toks-ours" < "$ours" || rt_refuse "reading $cons" "$?"
  comm -12 "$RT_T/retired" "$RT_T/toks-ours" > "$RT_T/spoken" || rt_refuse "the consumer-token intersection for $cp" "$?"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    rows="$rows$(printf 'RETIRED-CONTRACT-TOKEN\t%s\t%s' "$cp" "$tok")
"
  done < "$RT_T/spoken"
done < "$RT_T/subject"

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
