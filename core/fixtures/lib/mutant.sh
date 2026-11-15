# In-process pass counter. Sourced by a fixture run.sh that drives a subject in process.

# fx_inproc <subject-path> -- one IN-PROCESS pass of a subject: a drive that SOURCES the subject and calls its
# functions, which starts no bash and so is invisible to the start counter. Call it once per pass, on the line
# before the `.`/`source` of the subject (the static arm P1 in scripts/validate-fixture-invocations.sh pairs them).
# Under the distribution pre-push's invocation counter (FXCOUNT_LOG set by hermetic-run.sh), one row naming the subject,
# a relative path prefixed by $PWD, is appended to ${FXCOUNT_LOG}.inproc, which the judge counts against the fixture's
# `<N> inproc:<path>` rows of invocations.decl (J3) and refuses when no such row covers it (J7).
# Unset, or unwritable: nothing happens and the caller is never failed.
fx_inproc() {
  [ -z "${FXCOUNT_LOG:-}" ] || { case "${1:-}" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$PWD/${1:-}" ;; esac >> "${FXCOUNT_LOG}.inproc"; } 2>/dev/null || :
  return 0
}
