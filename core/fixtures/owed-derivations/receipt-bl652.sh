#!/bin/bash
# BL-652 receipt. usage: receipt-bl652.sh [<reader>]; run from the repo root.
#   <reader> defaults to core/scripts/check-owed-derivations.sh. The derivations validator it drives is copied
#   from core/scripts/validate-artifact-derivations.sh in the tree the receipt runs in. In an installed tree,
#   where core/scripts/ lands at scripts/ai-dlc/, both fall back to scripts/ai-dlc/.
#   exit 0   an absent record and an empty record both exit 0 and each prints its own UNMEASURED line (the two
#            differ), and a record with one OWED row and no OPEN row is silent (the fix is present)
#   exit 1   it does not
#   exit 9   the receipt cannot measure: no reader, no validator, or its world could not be built
set -uo pipefail
RD="${1:-core/scripts/check-owed-derivations.sh}"
VAL=core/scripts/validate-artifact-derivations.sh
[ -f "$RD" ] || RD=scripts/ai-dlc/check-owed-derivations.sh
[ -f "$VAL" ] || VAL=scripts/ai-dlc/validate-artifact-derivations.sh
[ -f "$RD" ] || exit 9
[ -f "$VAL" ] || exit 9
D="$(mktemp -d "${TMPDIR:-/tmp}/bl652rcpt.XXXXXX")" || exit 9
[ -d "$D" ] || exit 9
mkdir -p "$D/bin" "$D/r/scripts/ai-dlc" "$D/r/.claude" "$D/r/_bmad-output/planning-artifacts/s1" "$D/r/_bmad-output/ai-dlc-update" || exit 9
cp "$RD" "$D/bin/check-owed-derivations.sh" || exit 9
cp "$VAL" "$D/r/scripts/ai-dlc/" || exit 9
printf '#!/usr/bin/env bash\ncat "${3:-/dev/null}/.sprint-id"\n' > "$D/bin/sprint-status.sh" || exit 9
printf '1\n' > "$D/r/.sprint-id" || exit 9
printf 'qqalpha\n' > "$D/r/t.txt" || exit 9
F=_bmad-output/planning-artifacts/s1/story.md
printf '# S\n\n```derived\n$ grep -c qqalpha t.txt\n1\n```\n' > "$D/r/$F" || exit 9
REC="$D/r/_bmad-output/ai-dlc-update/owed-derivations.tsv"
go() { ( cd / && AI_DLC_PROJECT_ROOT="$D/r" bash "$D/bin/check-owed-derivations.sh" ) > "$D/out" 2>"$D/err"; RC=$?; OUT="$(cat "$D/out")"; }
go; a_rc=$RC; a_out="$OUT"
: > "$REC" || exit 9
go; e_rc=$RC; e_out="$OUT"
printf 'OWED\t%s:4\tgrep -c qqalpha t.txt\t5\t1\tb..t\tlog\n' "$F" > "$REC" || exit 9
go; c_rc=$RC; c_out="$OUT"
[ "$a_rc" = 0 ] && [ "$e_rc" = 0 ] && [ "$c_rc" = 0 ] || exit 1
case "$a_out" in UNMEASURED:*"no owed-derivations record at"*) ;; *) exit 1 ;; esac
case "$e_out" in UNMEASURED:*"present with 0 OWED rows"*) ;; *) exit 1 ;; esac
[ "$a_out" != "$e_out" ] || exit 1
[ -z "$c_out" ] || exit 1
exit 0
