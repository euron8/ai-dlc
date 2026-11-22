# shellcheck shell=bash
# vac-inproc.sh -- sourced by receipt-bl733.sh, receipt-bl736.sh, receipt-bl814.sh and receipt-bl1175c.sh (BL-878).
# rcpt_vac <validator> <args...> answers what `bash <validator> <args...>` prints (stdout, stderr) and exits with.
#
# IN PROCESS WHEN THE SUBJECT IS WRAPPED: a validator with BOTH its `vac_main() {` line and the column-0 source guard is
# SOURCED in a subshell, which the guard stops after defining vac_main, and vac_main is called there; its `exit`, `set -u`
# and EXIT trap end with that subshell. The subshell first drops every unexported variable and every function (fx_inproc
# kept) and turns pipefail off, so the call starts as the program would; exported variables, GIT_CEILING_DIRECTORIES and
# TMPDIR included, reach it as they reach a program. Any other validator (one that predates the wrap, or carries one half
# of it) runs as a process: `bash <validator> <args>`, so a receipt scoring a respelled or older copy answers as it did.
# The fixture's run.sh gates a pre-wrap subject (SKIP on a consumer) before it starts any receipt.
# lib/mutant.sh is guarded: absent, fx_inproc is a no-op, so the archived `verify:` lines still run a receipt standalone.
_rv_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)" || _rv_lib=""
if [ -n "$_rv_lib" ] && [ -f "$_rv_lib/mutant.sh" ]; then . "$_rv_lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }; fi
declare -F fx_inproc >/dev/null 2>&1 || fx_inproc() { return 0; }
unset _rv_lib
rcpt_vac() { # rcpt_vac <validator> <args...>
  local _rv_d=1 _rv_g=1
  grep -q '^vac_main() {$' "$1" 2>/dev/null && _rv_d=0
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1" 2>/dev/null && _rv_g=0
  if [ "$_rv_d$_rv_g" != 00 ]; then bash "$@"; return; fi
  ( set +o pipefail +u
    _vr_keep='^(BASH.*|IFS|OPTIND|OPTERR|LINENO|RANDOM|SRANDOM|SECONDS|EPOCH.*|PIPESTATUS|FUNCNAME|GROUPS|EUID|UID|PPID|SHELLOPTS|HOSTNAME|HOSTTYPE|MACHTYPE|OSTYPE|DIRSTACK|PS[0-9]|SHLVL|PWD|OLDPWD|HOME|PATH|TMPDIR|_vr_.*)$'
    _vr_exp=" $(compgen -e | tr '\n' ' ') "
    for _vr_i in 1 2 3 4 5 6 7 8; do # a caller's local, unset, uncovers the caller's caller's binding: repeat
      _vr_n=0
      for _vr_v in $(compgen -v); do
        [[ $_vr_v =~ $_vr_keep ]] && continue
        case "$_vr_exp" in *" $_vr_v "*) continue ;; esac
        unset "$_vr_v" 2>/dev/null && _vr_n=$((_vr_n + 1))
      done
      [ "$_vr_n" -eq 0 ] && break
    done
    for _vr_v in $(compgen -A function); do case "$_vr_v" in fx_inproc) ;; *) unset -f "$_vr_v" ;; esac; done
    unset _vr_keep _vr_exp _vr_i _vr_n _vr_v
    . "$1" || exit 125
    fx_inproc "$1"; shift; vac_main "$@" )
}
