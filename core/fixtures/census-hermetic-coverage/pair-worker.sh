#!/usr/bin/env bash
# census-hermetic-coverage/pair-worker.sh <census> --pair <index> <fixture> -- one pool worker of an IN-PROCESS census run.
#
# The census's pool starts `bash <census> --pair <index> <fixture>` per listed fixture through xargs. Under run.sh's
# in-process drive, `bash` on the PATH is the run.sh-written bash shim, which sources this file for exactly that argv
# shape (every other `bash` passes through to the real one). The shim is still a process of its own, with the census
# path and `--pair` in its argv, so s-selfkill's parent check and kill read it as they read a CLI worker. The census is
# SOURCED (its guard returns) and census_main answers the `--pair` call: one fx_inproc pass per worker.
# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/../lib/mutant.sh" || { echo "FIXTURE BROKEN: pair-worker cannot source lib/mutant.sh" >&2; exit 2; }
. "$1" || exit 126
shift
fx_inproc "$CHC_CENSUS"
census_main "$@"
