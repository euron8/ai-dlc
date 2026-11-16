# shellcheck shell=bash
# core/fixtures/lib/pool-span.sh -- the one way a fixture extracts a pre-push hook span that binds the record homes.
#
#   pool_span <hook> <out> <SPAN>...
#
# Writes to <out> each named `# <SPAN>_BEGIN` .. `# <SPAN>_END` span of <hook>, in the hook's file order, under these
# two first lines:
#   export AI_DLC_VERDICT_STORE="${AI_DLC_VERDICT_STORE:-$PWD.verdicts}"
#   unset REC_ROOT
# The second makes every source resolve the root commit from its own $PWD: RECORD_HOME keeps a REC_ROOT already set in
# the shell, so a second source in another world would file that world's records under the first world's root.
# Source <out> from inside the world it drives (after a `cd` into it), as hook_drive runs a hook from its tree. Every
# record home then resolves under that world's own store, <world>.verdicts, unless the caller set a non-empty one: the
# RECORD_HOME span (which FIXTURE_POOL carries) at the source, rec_home calls later in that shell, and every child it
# starts, among them hermetic-run.sh, the writer of the per-fixture entries. An unset or empty store is the shape
# that files a world's records in the real verdict store. The default holds whatever form the source takes: a
# variable, a function parameter or a driver script the fixture wrote. Returns 1, and <out> is not to be sourced, when
# <hook> is unreadable, no SPAN is named, a SPAN is not a sentinel name, or a named span is absent or empty.
# scripts/validate-fixture-hygiene.sh H13 fails a fixture line that extracts such a span by hand.
pool_span() {
  local hk="${1:-}" out="${2:-}" s prog=""
  [ $# -ge 3 ] && [ -r "$hk" ] && [ -n "$out" ] || return 1
  shift 2
  for s in "$@"; do
    case "$s" in ''|*[!A-Z0-9_]*) return 1 ;; esac
    grep -qx "# ${s}_BEGIN" "$hk" && grep -qx "# ${s}_END" "$hk" || return 1
    prog="$prog/^# ${s}_BEGIN\$/,/^# ${s}_END\$/p;"
  done
  { printf '%s\n' 'export AI_DLC_VERDICT_STORE="${AI_DLC_VERDICT_STORE:-$PWD.verdicts}"' 'unset REC_ROOT'; sed -n "$prog" "$hk"; } > "$out" || return 1
  [ "$(grep -c . "$out")" -gt "$(($# * 2))" ]
}
