#!/usr/bin/env bash
# backlog-receipt-lib.sh -- SOURCED, never run. The could-not-measure predicate shared by the two
# programs that execute `verify: sh` receipts: scripts/backlog-reverify.sh (the classifier) and
# scripts/validate-backlog-receipts.sh (the pre-push receipt worker). It lived inside the
# classifier, where a second program could not source it without also running the classifier, so
# the worker would have had to re-implement it -- and a second implementation of a grammar drifts.
# Each caller resolves this file under the repo root it found by walking up for `VERSION`, and
# refuses rather than falling back to a private copy when it is absent.
#
# THE CONTRACT. The caller sets SELF_NAME to the `$0` its receipts are `eval`led under, then calls
# `cant_measure <rc>` with the receipt's stderr on stdin. It prints why the receipt could not
# measure, or nothing.
#
# A RECEIPT THAT EXITS NON-ZERO HAVING MEASURED NOTHING IS NOT A REPRODUCTION (BL-089, second
# subject). The eval's stderr used to go to /dev/null, so `receipt_path_tokens: command not
# found` (BL-081's receipt, after its helper moved one line above a `sed` range) and a fragment
# that dies at eval time (BL-066's) read STILL-LIVE in the same words as a live defect.
#
# ONLY THE RECEIPT'S OWN INTERPRETER COUNTS. `eval` runs inside the caller, so bash prefixes
# its own diagnostics with `$0: line N:` or `$0: eval: line N:`; a subject's diagnostics carry
# ITS name (`cat:`, `bash:`, `./x.sh: line N:`). That prefix is what separates "the receipt's
# shell could not run it" from "the subject failed, which may be the defect". Matched as a
# quoted `case` literal, never a regex: `$0` is a path and carries metacharacters.
#
# THE NARROWING, MEASURED BEFORE THIS SHIPPED. Candidates were exit 127 on any stderr, and exit
# 1/2/127 with `command not found`, `syntax error` or `No such file or directory` anywhere. The
# census ran every live receipt through the classifier (36) and the archived ones through
# `--closed-receipts` (300 of 309; the 11 that run the whole pre-push suite were excluded),
# logging rc and every stderr line carrying a candidate string. Own-prefix matches: ZERO, so
# the routed set moves no real row. Unprefixed: ONE, a subject's `cat: ...: No such file` in a
# receipt that exits 0. The census hook was proven able to fire first: a probe ledger scored an
# own-prefix `command not found`, a subject-side `No such file` and an `unbound variable`.
# Unprefixed matching is refused anyway: a subject that prints `No such file` and exits 1 is exactly
# how several receipts OBSERVE their defect, so that route would hide live entries. Exit 127
# alone is refused for the same reason from the other side -- `bash "$subject"` returns 127
# when the SUBJECT calls a helper it does not ship, which is a defect a receipt may be
# asserting. `unbound variable` is not routed: the engine's `set -u` reaches receipts, and
# widening to it is a separate decision.
cant_measure() {
  local rc="$1" line msg
  case "$rc" in 1|2|127) ;; *) return 0 ;; esac
  while IFS= read -r line; do
    case "$line" in
      "$SELF_NAME: line "*|"$SELF_NAME: eval: line "*) ;;
      *) continue ;;
    esac
    case "$line" in
      *": command not found"|*"syntax error"*|*": No such file or directory")
        msg="${line#"$SELF_NAME: "}"
        msg="${msg//	/ }"
        printf "its own shell reported '%s'" "$(printf '%s' "$msg" | cut -c1-200)"
        return 0 ;;
    esac
  done
  return 0
}
