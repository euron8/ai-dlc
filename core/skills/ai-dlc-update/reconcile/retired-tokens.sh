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

bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null \
| awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2"\t"$3}' | sort -u \
| while IFS="$(printf '\t')" read -r cp cons; do
    [ -n "${cp:-}" ] || continue
    [ -z "$ONLY" ] || [ "$ONLY" = "$cp" ] || continue

    ours="$CONSUMER/$cons"
    [ -f "$ours" ] || continue

    b="$(git -C "$DIST" show "${BASE}:${cp}" 2>/dev/null || true)"
    t="$(git -C "$DIST" show "${THEIRS}:${cp}" 2>/dev/null || true)"
    [ -n "$b" ] && [ -n "$t" ] || continue

    # base tokens MINUS theirs tokens = what upstream retired.
    # Intersected with ours = what the consumer still speaks.
    retired="$(comm -23 <(printf '%s\n' "$b" | toks) <(printf '%s\n' "$t" | toks))"
    [ -n "$retired" ] || continue

    comm -12 <(printf '%s\n' "$retired") <(toks < "$ours") \
    | while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        printf 'RETIRED-CONTRACT-TOKEN\t%s\t%s\n' "$cp" "$tok"
      done
  done

exit 0
