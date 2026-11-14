# shellcheck shell=bash
# core/fixtures/lib/report.sh -- the reporting seam of a fixture run.sh. Source it after lib/preamble.sh and BEFORE
# lib/mutant.sh, which refuses to load until ok and bad exist.
#
#   ok <message>                    one passing assertion: `  ok    <message>` on stdout; counted in $oks
#   bad <message>                   one failing assertion: `  FAIL  <message>` on stdout; counted in $fails
#   report_end <name> [<expected>]  the verdict and the exit. FAIL and exit 1 when any bad ran, when no ok ran (a
#                                   run that asserted nothing has not passed), or when <expected> is given and
#                                   oks + fails differs from it (an arm that never ran reads like a short green run).
#                                   Otherwise `PASS: <name> -- <n> assertion(s)` and exit 0.
#
# The ok and bad line formats are the ones the hand-written copies already print, so a fixture moving onto this file
# changes no assertion line a reader greps.
fails=0
oks=0
ok() { printf '  ok    %s\n' "$1"; oks=$((oks + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
report_end() { # <name> [<expected>]
  if [ -n "${2:-}" ] && [ $((oks + fails)) -ne "$2" ]; then
    bad "$((oks + fails)) assertion(s) ran, $2 expected -- an arm did not execute"
  fi
  if [ "$fails" -gt 0 ]; then
    printf 'FAIL: %s -- %s assertion(s) failed, %s passed\n' "$1" "$fails" "$oks"; exit 1
  fi
  if [ "$oks" -eq 0 ]; then
    printf 'FAIL: %s -- no assertion ran\n' "$1"; exit 1
  fi
  printf 'PASS: %s -- %s assertion(s)\n' "$1" "$oks"; exit 0
}
