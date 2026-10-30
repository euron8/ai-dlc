# shellcheck shell=bash
# core/fixtures/lib/inproc.sh -- ask a LOADABLE subject its answer IN PROCESS, as `bash <subject> <args>` would give it.
#
# A loadable subject defines functions when sourced and runs its entry function only when executed: the call is
# preceded by `[ "${BASH_SOURCE[0]}" = "$0" ] || return 0`. `inproc_run` runs that entry function in a SUBSHELL made to
# look like a fresh `bash <subject>`: every function the subject did not define is removed, every UNEXPORTED variable a
# fresh bash does not start with is unset, the shell options are a fresh bash's, and the command hash is empty (a
# `PATH=<shim>:$PATH inproc_run ...` would otherwise still reach a binary hashed before the shim). Exported variables,
# prefix assignments included, are kept: they are exactly what a child process would inherit. The subshell's stdout,
# stderr and exit status are the subject's; an `exit` in the subject ends the subshell only. It execs nothing.
#
#   inproc_load <subject>                   source it ONCE, in this shell; it becomes INPROC_LOADED. Its top level must
#                                           define functions and nothing else, which is what the source guard buys.
#   inproc_run <subject> <entry> [args...]  the answer. <subject> = INPROC_LOADED runs the loaded definitions; any
#                                           other path (a mutant copy) is sourced inside the subshell after every
#                                           function is removed, so its definitions are the only ones present.
#
# THE LOADED DEFINITIONS ARE KEPT, NEVER RE-CREATED. A function's `${BASH_SOURCE[0]}` is the file it was DEFINED in, and
# a subject that locates its siblings from it (ledger-reverify.sh does) would find them beside whatever file re-created
# it -- measured: an `eval` of `declare -f` output made the subject look for consumer-read.sh in core/fixtures/lib/.
# A subject function is one whose DEFINITION the load created or changed, so a caller's helper sharing its name before
# the load is the subject's afterwards. One the caller REDEFINES after the load would run in its place, so every run
# first checks the loaded set is byte-identical to the snapshot and refuses with 125 otherwise.
#
# WHAT THIS CANNOT REPRODUCE is anything a subject decides from being the TOP of a process: `$BASH_SUBSHELL` is 1 here,
# never 0, and `$$` is the caller's pid. A caller asking such a question keeps the CLI run.
INPROC_LOADED=""
INPROC_FNS=" "
INPROC_DEFS=""
inproc_load() { # <subject> -> 0 sourced; 1 not
  local _b _f _before
  _before="$(declare -f)"
  _b=" $(compgen -A function) "; _b="${_b//$'\n'/ }"
  # shellcheck source=/dev/null
  . "$1" || return 1
  INPROC_FNS=" "
  for _f in $(compgen -A function); do
    case "$_b" in *" $_f "*) case "$_before" in *"$(declare -f "$_f")"*) continue ;; esac ;; esac
    INPROC_FNS="$INPROC_FNS$_f "
  done
  [ "$INPROC_FNS" != " " ] || return 1
  # shellcheck disable=SC2086 # names carry no whitespace; the split is the point
  INPROC_DEFS="$(declare -f $INPROC_FNS)"
  INPROC_LOADED="$1"
}
inproc_run() { # <subject> <entry> [args...] -> the entry's stdout, stderr and status
  (
    IFS=$' \t\n'
    _inproc_s="$1"; _inproc_e="$2"; shift 2
    if [ -n "$INPROC_LOADED" ] && [ "$_inproc_s" = "$INPROC_LOADED" ]; then
      # shellcheck disable=SC2086
      [ "$(declare -f $INPROC_FNS)" = "$INPROC_DEFS" ] \
        || { echo "inproc: a function of $INPROC_LOADED was redefined after inproc_load; refusing to run it" >&2; exit 125; }
      _inproc_k="$INPROC_FNS"
    else
      _inproc_k=" "
    fi
    _inproc_x=" $(compgen -e) "; _inproc_x="${_inproc_x//$'\n'/ }"
    for _inproc_f in $(compgen -A function); do
      case "$_inproc_k" in *" $_inproc_f "*) continue ;; esac
      unset -f "$_inproc_f"
    done
    for _inproc_v in $(compgen -v); do
      case "$_inproc_x" in *" $_inproc_v "*) continue ;; esac
      case "$_inproc_v" in
        _inproc_s|_inproc_e|_inproc_x|_inproc_v|_inproc_k) continue ;;
        BASH|BASH_*|BASHOPTS|BASHPID|COMP_WORDBREAKS|DIRSTACK|EUID|FUNCNAME|GROUPS|HISTCMD|HOSTNAME|HOSTTYPE) continue ;;
        IFS|LINENO|MACHTYPE|OPTERR|OPTIND|OSTYPE|PIPESTATUS|PPID|PS4|PWD|OLDPWD|RANDOM|SECONDS|SHELL|SHELLOPTS) continue ;;
        SHLVL|TERM|UID|_) continue ;;
      esac
      unset "$_inproc_v" 2>/dev/null
    done
    OPTIND=1
    set +eufx +o pipefail
    hash -r
    if [ "$_inproc_k" = " " ]; then
      # shellcheck source=/dev/null
      . "$_inproc_s" || exit 126
    fi
    unset _inproc_s _inproc_x _inproc_v _inproc_f _inproc_k
    "$_inproc_e" "$@"
  )
}
