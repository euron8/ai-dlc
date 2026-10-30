# artifact-derivations/unit.sh -- the in-process way to ask validate-artifact-derivations.sh a question.
# Sourced by run.sh. The validator is a loadable file (vad_load, vad_invoke; see the header of the
# validator): vad_call sources the COPY it is given in a subshell, loads its tables and startup
# self-probes, and runs one vad_invoke, so the file answers what `bash <copy> <args>` answers and the
# mutant copies are sourced, never re-implemented. The subshell is what keeps the validator's `fails`,
# `rc`, `out`, `exit` and trap away from this fixture's own names.
#   vad_call <copy> [NAME=value ...] -- <args>...
# stdout and stderr go where the caller sends them; the status is the validator's own.
vad_call() {
  local _vc="$1" _ve=() _vk
  shift
  while [ $# -gt 0 ] && [ "$1" != -- ]; do _ve+=("$1"); shift; done
  [ $# -gt 0 ] || { echo "vad_call: no -- before the arguments" >&2; return 125; }
  shift
  (
    for _vk in ${_ve[@]+"${_ve[@]}"}; do export "$_vk"; done
    # shellcheck source=/dev/null
    . "$_vc" || exit 125
    vad_load
    vad_invoke "$@"
  )
}
