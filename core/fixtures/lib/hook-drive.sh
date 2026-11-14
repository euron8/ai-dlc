# shellcheck shell=bash
# core/fixtures/lib/hook-drive.sh -- the one way a fixture runs a pre-push hook inside a world it built.
#
#   hook_drive [--hook <path>] <tree> <out> [NAME=value ...] [-- <hook args>...]
#
# Runs `bash <hook> <hook args>` (default hook `.githooks/pre-push`, relative to <tree>) from <tree>, with:
#   - every leaked GIT_* location unset, so the hook's git calls land on <tree>'s repository
#   - stdin /dev/null, as the push pool gives every fixture
#   - AI_DLC_READSET_LIVE_TRACE=0, so a green inner suite starts no detached trace
#   - AI_DLC_VERDICT_STORE=<tree>.verdicts, so the inner hook never reads or writes the real verdict store
#   - each NAME=value exported after those, so a caller may override any of them
# Its stdout and stderr go to <out>. hook_drive prints the hook's exit status and returns 0; it prints 125 for a
# <tree> it cannot enter or an argument that is not NAME=value, and returns 125 printing nothing on too few
# arguments. It sets no AI_DLC_FIXTURE_JOBS: the hook's nested-pool cap decides the width.
hook_drive() {
  local hook=.githooks/pre-push t o
  if [ "${1:-}" = --hook ]; then hook="$2"; shift 2; fi
  [ $# -ge 2 ] || { echo "hook_drive: usage: hook_drive [--hook <path>] <tree> <out> [NAME=value ...] [-- <args>...]" >&2; return 125; }
  t="$1"; o="$2"; shift 2
  case "$t" in /*) ;; *) t="$PWD/$t" ;; esac
  case "$o" in /*) ;; *) o="$PWD/$o" ;; esac
  (
    cd "$t" || exit 125
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_VERDICT_STORE="$t.verdicts"
    while [ $# -gt 0 ] && [ "$1" != -- ]; do
      case "$1" in
        [A-Za-z_]*=*) export "${1?}" ;;
        *) echo "hook_drive: not NAME=value: $1" >&2; exit 125 ;;
      esac
      shift
    done
    [ "${1:-}" != -- ] || shift
    bash "$hook" "$@" < /dev/null > "$o" 2>&1
  )
  printf '%s\n' "$?"
}
