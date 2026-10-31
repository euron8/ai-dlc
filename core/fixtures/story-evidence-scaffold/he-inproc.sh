# he-inproc.sh -- run validate-handoff-evidence.sh, and the two siblings it shells to, IN PROCESS. SOURCED, never run.
#
# The three subjects are loadable: each ends `[ "${BASH_SOURCE[0]}" = "$0" ] || return 0` before one call of its own
# top-level function (he_main, ro_main, ss_main), so sourcing defines functions and runs nothing. he_run asks the
# validator exactly what `bash <validator> <args>` asks, in a SUBSHELL: no bash is started for the validator, and
# none for the record-only-diff.sh / sprint-status.sh calls it makes, because inside that subshell a function named
# `bash` answers `bash <path> <args>` by sourcing THE FILE AT THAT PATH in a further subshell and calling its main
# function -- the file the CLI would have run, never a copy chosen here. A file that is not loadable (it lacks the
# guard line; the SIBLING EXIT arm's wrapper sibling is one) is run by the real bash, as the CLI runs it. No subject
# logic is copied here; every decision is the sourced file's own.
#
# What makes the subshell answer as a fresh `bash <file>` would (_ut_fresh):
#   - shell options are a fresh non-interactive bash's: the caller's -e, -f, -u and pipefail are cleared (each
#     subject sets its own);
#   - every caller FUNCTION is unset, and every caller variable that is neither exported nor a shell special, so a
#     name the caller happens to define (a `line`, a `cell`, a STORY) can never stand in for an external command or
#     an unset variable the subject reads;
#   - record-only-diff.sh calls itself as `bash "$0" <mode>`; sourced, its $0 is the caller's, so inside an RO call
#     a `bash "$0"` is routed to the RO file that is running (the CLI's $0 is that file).
# run.sh's EQUIV arm holds he_run byte-identical (stdout+stderr and exit) to the CLI on a refusing and a passing
# input of every mode it converts, and ro_run / ss_run to theirs.
#
# he_run <file> [<args>...]                      -> the file's stdout/stderr and exit status, as `bash <file> <args>`
# he_run_env <VAR=value|-> <file> [<args>...]    -> the same with one variable exported (`-` for none): LC_ALL for a
#                                                   locale-driven world, PATH for a shim
# ro_run / ss_run <file> [<args>...]             -> he_run under the names the cells read
# rcpt_run <worlds dir|-> <receipt> [<args>...] -> the receipt's output and exit, as `bash <receipt> <args>` gives
#                                                   them, sourced in a fresh subshell; with a worlds dir the receipt
#                                                   seeds its scratch repositories there ONCE and every later call
#                                                   reads them (RCPT_WORLD, each receipt's header)
_UT_GUARD='[ "${BASH_SOURCE[0]}" = "$0" ] || return 0'
rcpt_run() {
  (
    _UT_RW="$1"; _UT_RF="$2"; shift 2
    if [ "$_UT_RW" = - ]; then unset RCPT_WORLD; else export RCPT_WORLD="$_UT_RW"; fi
    _ut_fresh
    # shellcheck source=/dev/null
    . "$_UT_RF" "$@"
  )
}
he_run() { he_run_env - "$@"; }
ro_run() { he_run_env - "$@"; }
ss_run() { he_run_env - "$@"; }
he_run_env() {
  (
    _UT_ENV="$1"; shift
    [ "$_UT_ENV" = - ] || export "${_UT_ENV?}"
    _ut_fresh
    _ut_bash "$@"
  )
}
_ut_fresh() { # clears the caller's options, functions and private variables; keeps _ut_bash and _ut_fresh
  local _v _f _ex=" "
  set +e +f +u +o pipefail
  for _f in $(compgen -A function); do
    case "$_f" in _ut_bash|_ut_fresh|_ut_loadable|he_run|he_run_env|ro_run|ss_run|rcpt_run) ;; *) unset -f "$_f" ;; esac
  done
  for _v in $(compgen -e); do _ex="$_ex$_v "; done
  for _v in $(compgen -v); do
    case "$_v" in
      _UT_*|_v|_f|_ex|IFS|PWD|OLDPWD|BASH|BASH_*|BASHOPTS|SHELLOPTS|PPID|UID|EUID|GROUPS|HOSTNAME|HOSTTYPE|\
      MACHTYPE|OSTYPE|SHLVL|RANDOM|LINENO|SECONDS|FUNCNAME|PIPESTATUS|DIRSTACK|OPTIND|OPTERR|OPTARG|HISTCMD|\
      COMP_*|PS1|PS2|PS4|_) continue ;;
    esac
    case "$_ex" in *" $_v "*) continue ;; esac
    unset "$_v" 2>/dev/null
  done
  IFS=$' \t\n'
}
_ut_loadable() { # <file> -> 0 when its last-but-one line is the source guard
  local _l _p=""
  [ -f "$1" ] || return 1
  while IFS= read -r _l || [ -n "$_l" ]; do _UT_PREV="$_p"; _p="$_l"; done < "$1"
  [ "${_UT_PREV:-}" = "$_UT_GUARD" ]
}
_ut_bash() { # <file> <args>: `bash <file> <args>`, in process when <file> is loadable
  local _m
  if [ "$1" = "$0" ] && [ -n "${_UT_SELF:-}" ]; then set -- "$_UT_SELF" "${@:2}"; fi
  case "${1##*/}" in
    validate-handoff-evidence.sh|he-mut-*.sh) _m=he_main ;;
    record-only-diff.sh) _m=ro_main ;;
    sprint-status.sh) _m=ss_main ;;
    *) [ -z "${UT_FALLBACK_LOG:-}" ] || printf 'not a subject: %s\n' "$1" >> "$UT_FALLBACK_LOG"; command bash "$@"; return ;;
  esac
  # A subject file without the guard runs as the CLI runs it; UT_FALLBACK_LOG (exported by run.sh) names it, so
  # the INPROC arm can assert that every subject call the fixture made was answered in process.
  _ut_loadable "$1" || { [ -z "${UT_FALLBACK_LOG:-}" ] || printf 'not loadable: %s\n' "$1" >> "$UT_FALLBACK_LOG"; command bash "$@"; return; }
  (
    _UT_SELF="$1"; shift
    # shellcheck source=/dev/null
    . "$_UT_SELF" || exit 2
    bash() { _ut_bash "$@"; }
    "$_m" "$@"
  )
}
