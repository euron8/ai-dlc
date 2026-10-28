# Mutant-kill helpers. Sourced by a fixture run.sh that scores mutants, AFTER it defines
# ok() and bad().
#
# THE DEFECT THIS EXISTS FOR. A mutant's kill condition is usually a value the UNMUTATED arm
# it guards would also print if that arm were failing. A mutant that breaks the arm's SETUP
# rather than its subject then scores as killed, and the battery certifies a seed that never
# worked. Measured on check-22-spawn-ledger: 41 of its 43 mutant arms scored a kill without
# asserting, in the same run, that the arm they guard had passed.
#
# So a kill is emitted ONLY through mutant_killed, which refuses unless the caller passes the
# same-run base-pass flag. scripts/validate-mutant-kills.sh fails the push on a KILLED/killed
# on a non-comment line of core/fixtures/*/run.sh that does not go through mutant_killed,
# outside a down-only allowlist of the fixtures that predate this file.
#
# THE FLAG IS A VALUE THE UNMUTATED RUN SET. Pass `1` only when the arm the mutant guards
# passed in THIS run -- a B_<name> flag set beside that arm's ok, or a $([ ... ] && echo 1)
# test over a value computed from the unmutated subject. A constant `1` defeats the helper;
# check-22's NB BINDING arm shows how a fixture binds its call sites mechanically.
if ! declare -F ok >/dev/null 2>&1 || ! declare -F bad >/dev/null 2>&1; then
  echo "FIXTURE ERROR: lib/mutant.sh was sourced before ok() and bad() were defined" >&2
  exit 2
fi

# need_base <flag> <mutant-name> -- the gate. Returns 0 when the unmutated arm passed in this
# run (flag 1). Otherwise the "kill" would be the seed failing, not the mutation: FIXTURE BROKEN,
# never ok, and return 2 so the caller skips running the mutant at all.
need_base() {
  [ "$1" = 1 ] && return 0
  bad "FIXTURE BROKEN: MUTANT $2 not scored -- the unmutated arm it guards did not pass in this run, so its kill would read the seed failing"
  return 2
}

# mutant_killed <flag> <mutant-name> <message> -- the ONLY sanctioned emission of a kill.
# Refuses through need_base unless the flag is 1; otherwise emits ok "<message>".
# Under the distribution pre-push's invocation counter (FXCOUNT_LOG set by hermetic-run.sh), the name is also
# appended to ${FXCOUNT_LOG}.mutants for the judge's J5 join against the fixture's MUTANT-MATRIX rows.
# Unset, or unwritable: nothing happens and the caller is never failed.
mutant_killed() {
  [ -z "${FXCOUNT_LOG:-}" ] || { printf '%s\n' "$2" >> "${FXCOUNT_LOG}.mutants"; } 2>/dev/null || :
  need_base "$1" "$2" || return 2
  ok "$3"
}
