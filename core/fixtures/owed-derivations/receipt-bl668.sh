#!/bin/bash
# BL-668 receipt. usage: receipt-bl668.sh [<writer> [<reader>]]; any cwd.
#   Drives the SHIPPING writer (reconcile/derivation-differential.sh --record-owed) over a seeded consumer whose
#   pull broke NOTHING (zero NEWLY-FAILING rows), then the reader (check-owed-derivations.sh) over that consumer.
#   exit 0   the writer left a record, the reader prints the "present with 0 OWED rows" line for it, and a second
#            consumer that was never reconciled still prints the "no owed-derivations record" line (control)
#   exit 1   it does not
#   exit 9   the receipt cannot measure: a subject is missing, or its world could not be built
set -uo pipefail
H="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
WR="$(pick "${1:-}" "$H/../../skills/ai-dlc-update/reconcile/derivation-differential.sh" "$H/../../../.claude/skills/ai-dlc-update/reconcile/derivation-differential.sh")"
RD="$(pick "${2:-}" "$H/../../scripts/check-owed-derivations.sh" "$H/../../../scripts/ai-dlc/check-owed-derivations.sh")"
VAL="$(pick "$H/../../scripts/validate-artifact-derivations.sh" "$H/../../../scripts/ai-dlc/validate-artifact-derivations.sh")"
[ -n "$WR" ] && [ -n "$RD" ] && [ -n "$VAL" ] || exit 9
WR="$(cd "$(dirname "$WR")" && pwd)/$(basename "$WR")"
D="$(mktemp -d "${TMPDIR:-/tmp}/bl668rcpt.XXXXXX")" || exit 9
[ -d "$D" ] || exit 9
g() { local d="$1"; shift; git -C "$d" -c user.name=r -c user.email=r@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
stub() { printf '#!/usr/bin/env bash\n[ "${1:-}" = sprint-id ] || exit 2\nshift; r=""; [ "${1:-}" = --root ] && r="${2:-}"\n[ -f "$r/.sprint-id" ] || exit 1\ncat "$r/.sprint-id"\n' > "$1/sprint-status.sh"; }
# distribution: base and theirs both keep qqalpha, so the pull breaks nothing
DIST="$D/dist"; mkdir -p "$DIST/core/scripts" || exit 9; g "$DIST" init -q || exit 9
printf 'qqprev\n' > "$DIST/core/scripts/toy.sh"; g "$DIST" add -A; g "$DIST" commit -qm prev
printf 'qqalpha\n' > "$DIST/core/scripts/toy.sh"; g "$DIST" add -A; g "$DIST" commit -qm base
BASE="$(g "$DIST" rev-parse HEAD)"
printf 'qqalpha\nqqmore\n' > "$DIST/core/scripts/toy.sh"; g "$DIST" add -A; g "$DIST" commit -qm theirs
THEIRS="$(g "$DIST" rev-parse HEAD)"
[ -n "$BASE" ] && [ -n "$THEIRS" ] && [ "$BASE" != "$THEIRS" ] || exit 9
mkc() { # <dir>
  mkdir -p "$1/scripts/ai-dlc" "$1/.claude" "$1/_bmad-output" || return 1; g "$1" init -q || return 1
  cp "$VAL" "$1/scripts/ai-dlc/" && cp "$RD" "$1/scripts/ai-dlc/check-owed-derivations.sh" || return 1
  stub "$1/scripts/ai-dlc"; printf '1\n' > "$1/.sprint-id"
  printf 'qqalpha\n' > "$1/scripts/ai-dlc/toy.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$1/.claude/.ai-dlc-version"
  printf '# Story\n\n```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n```\n' > "$1/_bmad-output/story.md"
  g "$1" add -A; g "$1" commit -qm pull
}
C="$D/clean"; U="$D/never"
mkc "$C" || exit 9; mkc "$U" || exit 9
g "$DIST" show "${THEIRS}:core/scripts/toy.sh" > "$C/scripts/ai-dlc/toy.sh"
REC=_bmad-output/ai-dlc-update/owed-derivations.tsv
W_OUT="$( cd / && TMPDIR="$D" bash "$WR" "$DIST" "$BASE" "$C" "$THEIRS" --record-owed "$C/$REC" --log-name reconcile-log-r.md 2>&1 )"; w_rc=$?
rd() { ( cd / && AI_DLC_PROJECT_ROOT="$1" bash "$1/scripts/ai-dlc/check-owed-derivations.sh" 2>&1 ); }
a_out="$(rd "$C")"; a_rc=$?
u_out="$(rd "$U")"
printf 'writer rc=%s\nreader after writer: %s\ncontrol (never reconciled): %s\n' "$w_rc" "$a_out" "$u_out"
[ "$w_rc" = 0 ] || { printf '%s\n' "$W_OUT" | tail -3; exit 1; }
case "$(printf '%s\n' "$W_OUT" | awk -F'\t' '$1 == "NEWLY-FAILING" { n++ } END { print n + 0 }')" in 0) ;; *) exit 1 ;; esac
[ -f "$C/$REC" ] || exit 1
case "$a_out" in UNMEASURED:*"present with 0 OWED rows"*) ;; *) exit 1 ;; esac
case "$u_out" in UNMEASURED:*"no owed-derivations record at"*) ;; *) exit 1 ;; esac
[ ! -e "$U/$REC" ] || exit 1
exit 0
