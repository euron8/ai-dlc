# advisor-gate-deny/applied.sh — mutant_applied, the one DID-NOT-APPLY guard both committed mutants and
# the must-fire probes in run.sh call. Sourced, never run. It is its own file so a mutant of it never
# re-sources lib.sh's world build.
#
# mutant_applied <builder_rc> <orig> <mut>
#   prints one line whose first word is the verdict, and returns:
#     0 APPLIED      cmp says the files differ (rc 1)
#     1 NOT-APPLIED  the builder exited non-zero, the mutant file is empty or absent, or cmp says identical (rc 0)
#     2 BROKEN       cmp could not compare them: any other rc (2 = an unreadable file, 127 = no cmp on PATH)
# FAIL CLOSED ON cmp's EXIT (BL-983). The fold `if cmp -s a b; then <identical> else <differ>` reads rc 2 and
# rc 127 as "differ", so an undeclared cmp in tools.decl -- the hermetic sandbox puts only the declared tool
# farm on PATH -- made both guards report every mutant APPLIED without comparing anything.
mutant_applied() {
  local brc="$1" orig="$2" mut="$3" crc
  if [ "$brc" != 0 ]; then echo "NOT-APPLIED builder rc=$brc"; return 1; fi
  if [ ! -s "$mut" ]; then echo "NOT-APPLIED mutant file empty or absent"; return 1; fi
  cmp -s "$orig" "$mut"; crc=$?
  case "$crc" in
    0) echo "NOT-APPLIED identical to the original"; return 1 ;;
    1) echo "APPLIED"; return 0 ;;
    *) echo "BROKEN cmp rc=$crc"; return 2 ;;
  esac
}
