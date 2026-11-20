# content-seal/seal-lib.sh -- the seal side of the content-seal fixture, sourced by each arm script
# AFTER the subject's own lib (adversarial-shard-merge/lib.sh, remediator-shard-join/lib.sh) or, for
# the gate arms, after they resolve the validator. The caller sets SRCDIR to the directory holding
# the reader it drives; the seal library is resolved as THAT reader's sibling, because that is where
# each reader looks for it (`$(dirname "$0")/content-seal.sh`), so a copy tree is read
# end to end and never half from the real one.
#
# The recorder hook is resolved by walking UP from this file in both layouts, never by counting `..`.
# Every world gets its own copy of the library at `<world>/scripts/ai-dlc/content-seal.sh`, because
# the hook sources only that consumer spelling under CLAUDE_PROJECT_DIR.
[ -n "${SRCDIR:-}" ] || { echo "FIXTURE ERROR: seal-lib.sh sourced without SRCDIR" >&2; exit 2; }
CS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEAL="$SRCDIR/content-seal.sh"
[ -f "$SEAL" ] || { echo "FIXTURE ERROR: $SEAL is not beside the reader under test; every arm would drive the absent-sibling path" >&2; exit 2; }
SEALHOOK=""
_d="$CS_LIB_DIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/hooks/ai-dlc-content-seal.sh" "$_d/.claude/hooks/ai-dlc-content-seal.sh"; do
    if [ -f "$_c" ]; then SEALHOOK="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
[ -n "$SEALHOOK" ] || { echo "FIXTURE ERROR: ai-dlc-content-seal.sh not found above $CS_LIB_DIR in either layout; no seal row can be written" >&2; exit 2; }
echo "content-seal: resolved seal library = $SEAL, recorder = $SEALHOOK"
echo "HERMETIC-CONSUMED core/scripts/content-seal.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-content-seal.sh"

# seal_hook <world root> <tool> <file_path> <agent_id or ""> [transcript_path]
# -- the REAL recorder, driven with the PostToolUse payload a Write or Edit produces. An empty
# agent_id is the top-level session's payload, which carries no agent_id key at all.
seal_hook() {
  mkdir -p "$1/scripts/ai-dlc" && cp "$SEAL" "$1/scripts/ai-dlc/content-seal.sh" || return 1
  jq -nc --arg t "$2" --arg p "$3" --arg a "$4" --arg tp "${5:-$1/.harness/fx-session.jsonl}" \
    '{session_id:"fx-session", hook_event_name:"PostToolUse", tool_name:$t, tool_input:{file_path:$p},
      tool_use_id:"toolu_01FxSealWrite", transcript_path:$tp, tool_response:{}}
     + (if $a == "" then {} else {agent_id:$a, agent_type:"fixture"} end)' \
    | ( CLAUDE_PROJECT_DIR="$1"; export CLAUDE_PROJECT_DIR; set +u +o pipefail; fx_inproc core/hooks/ai-dlc-content-seal.sh; . "$SEALHOOK"; acs_main ) >/dev/null 2>&1
}
# seal_count <ledger> -> the number of content-seal rows in it (0 when it is absent)
seal_count() { local n; n="$(grep -c '"kind":"content-seal"' "$1" 2>/dev/null)" || n=0; printf '%s' "$n"; }
# THE --mark SUBJECT. `wait-for-deliverable.sh --mark`/`--mark-repair` is the ONE sanctioned Bash write
# into the sealed set; it sits beside the reader, as content-seal.sh does.
WFD="$SRCDIR/wait-for-deliverable.sh"
[ -f "$WFD" ] || { echo "FIXTURE ERROR: $WFD is not beside the reader under test; the --mark arms have no subject" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"

# THE IN-PROCESS ROUTE. A call of a registered subject by its shipped path runs in a subshell of this process, as
# `bash <subject> <args>` would answer it: the `bash` function below catches it, and cs_run sources the subject and calls
# its entry (a pass logged by fx_inproc, no start). Every subject a subject starts in turn (the merge's and the join's
# `bash "$SEAL"`, --mark's --record-expect) reaches this function too: cs_run keeps it, and the registry CS_ROUTES it reads
# is exported. Any other `bash` call (a stand-in script, a copy, a data tool) is the program it always was. The CLI is
# started only by cs_eq below, one tagged start per distinct outcome (FXCELL=<cell id> command bash).
CS_ROUTES="
"
export CS_ROUTES
cs_route() { CS_ROUTES="$CS_ROUTES$1
"; export CS_ROUTES; } # <absolute subject path>
cs_route "$SEAL"; cs_route "$WFD"
bash() { case "${CS_ROUTES:-}" in *$'\n'"${1:-}"$'\n'*) cs_run "$@" ;; *) command bash "$@" ;; esac; }
cs_run() { # <subject path> <args...> -- the subject's own entry, in a subshell reduced to a CLI child's names
  (
    set +o pipefail +u
    _cs_keep='^(BASH.*|IFS|OPTIND|OPTERR|LINENO|RANDOM|SRANDOM|SECONDS|EPOCH.*|PIPESTATUS|FUNCNAME|GROUPS|EUID|UID|PPID|SHELLOPTS|HOSTNAME|HOSTTYPE|MACHTYPE|OSTYPE|DIRSTACK|PS[0-9]|SHLVL|PWD|OLDPWD|HOME|PATH|TMPDIR|_cs_.*)$'
    _cs_exp=" $(compgen -e | tr '\n' ' ') "
    for _cs_i in 1 2 3 4 5 6 7 8; do # a caller's local, unset, uncovers the caller's caller's binding: repeat
      _cs_n=0
      for _cs_v in $(compgen -v); do
        [[ $_cs_v =~ $_cs_keep ]] && continue
        case "$_cs_exp" in *" $_cs_v "*) continue ;; esac
        unset "$_cs_v" 2>/dev/null && _cs_n=$((_cs_n + 1))
      done
      [ "$_cs_n" -eq 0 ] && break
    done
    for _cs_v in $(compgen -A function); do case "$_cs_v" in cs_run|bash|fx_inproc) ;; *) unset -f "$_cs_v" ;; esac; done
    _cs_s="$1"; shift
    case "${_cs_s##*/}" in
      content-seal.sh) _cs_r=core/scripts/content-seal.sh; _cs_e=seal_main ;;
      merge-adversarial-shards.sh) _cs_r=core/scripts/merge-adversarial-shards.sh; _cs_e=merge_main ;;
      join-remediator-shards.sh) _cs_r=core/scripts/join-remediator-shards.sh; _cs_e=join_main ;;
      validate-gate-adjudication.sh) _cs_r=core/scripts/validate-gate-adjudication.sh; _cs_e=vga_main ;;
      wait-for-deliverable.sh) _cs_r=core/scripts/wait-for-deliverable.sh; _cs_e=wfd_mark_main ;;
      *) echo "FIXTURE BROKEN: cs_run has no entry for ${_cs_s##*/}" >&2; exit 97 ;;
    esac
    # shellcheck source=/dev/null
    fx_inproc "$_cs_r"; . "$_cs_s" || exit 90
    case "$_cs_e" in
      wfd_mark_main) fx_inproc "$_cs_r"; wfd_mark_main "$@"; fx_inproc "$_cs_r"; wfd_beat_main "$@" ;;
      *) fx_inproc "$_cs_r"; "$_cs_e" "$@" ;;
    esac
  )
}
# cs_eq <cell id> <world root or ""> <subject> <args...> -- ONE distinct outcome end to end: the subject started as a program
# (the cell's tagged start), then asked in process on the same input, and the two answers compared byte for byte (stdout,
# stderr, exit code, and the world's file list). The world is snapshotted first and put back at the SAME path before the
# in-process run (seal rows carry the physical root); the CLI's copy is dropped, so the world afterwards is the in-process
# answer's. Env prefixes and the working directory are the caller's; stdin is CS_EQ_IN (default /dev/null). Sets CS_EQ_RC
# (the shared exit code), CS_EQ_OUT (both streams of the in-process run) and CS_EQ_WHY (what differed); 0 when identical.
cs_eq() {
  local id="$1" w="$2" s="$3" e="${CS_EQ_DIR:-$WORK}/cseq.$1"; shift 3
  case "${CS_ROUTES:-}" in *$'\n'"$s"$'\n'*) ;; *) echo "FIXTURE BROKEN: cs_eq: $s is no registered subject" >&2; exit 2 ;; esac
  [ -z "$w" ] || cp -Rp "$w" "$w.eqsnap" || { echo "FIXTURE BROKEN: cs_eq cannot snapshot $w" >&2; exit 2; }
  FXCELL="$id" command bash "$s" "$@" > "$e.cout" 2> "$e.cerr" < "${CS_EQ_IN:-/dev/null}"; echo $? > "$e.crc"
  if [ -n "$w" ]; then
    ( cd "$w" && find . -type f | LC_ALL=C sort ) > "$e.cfiles" 2>/dev/null
    rm -rf "$w" && mv "$w.eqsnap" "$w" || { echo "FIXTURE BROKEN: cs_eq cannot restore $w" >&2; exit 2; }
  fi
  bash "$s" "$@" > "$e.iout" 2> "$e.ierr" < "${CS_EQ_IN:-/dev/null}"; echo $? > "$e.irc"
  [ -z "$w" ] || {
    ( cd "$w" && find . -type f | LC_ALL=C sort ) > "$e.ifiles" 2>/dev/null; }
  CS_EQ_WHY=""; read -r CS_EQ_RC < "$e.irc"
  cmp -s "$e.crc" "$e.irc" || CS_EQ_WHY="$CS_EQ_WHY rc $(cat "$e.crc")/$CS_EQ_RC"
  cmp -s "$e.cout" "$e.iout" || CS_EQ_WHY="$CS_EQ_WHY stdout[$(head -1 "$e.cout") | $(head -1 "$e.iout")]"
  cmp -s "$e.cerr" "$e.ierr" || CS_EQ_WHY="$CS_EQ_WHY stderr[$(head -1 "$e.cerr") | $(head -1 "$e.ierr")]"
  [ -z "$w" ] || cmp -s "$e.cfiles" "$e.ifiles" || CS_EQ_WHY="$CS_EQ_WHY files"
  [ -s "$e.cout" ] || [ -s "$e.cerr" ] || CS_EQ_WHY="$CS_EQ_WHY the CLI printed nothing (a comparison of nothing)"
  CS_EQ_OUT="$e.out"; cat "$e.iout" "$e.ierr" > "$CS_EQ_OUT"
  [ -z "$CS_EQ_WHY" ]
}
# race_engine <dir> -> the path of a --mark engine copy whose content-seal.sh sibling is a STUB: on a
# --record or --record-expect call it first appends a line to the file through Bash, then runs the real
# library. That is a write landing between --mark's move and its seal row, forced, with no sleep.
race_engine() {
  mkdir -p "$1" && cp "$WFD" "$1/wait-for-deliverable.sh" || return 1
  { printf '#!/bin/bash\nREAL=%q\n' "$SEAL"
    printf 'if [ "${BASH_SOURCE[0]}" != "$0" ]; then . "$REAL"; return 0; fi\n'
    printf 'case "${1:-}" in --record|--record-expect) printf "written through Bash after the move\\n" >> "${@: -1}" ;; esac\n'
    printf '. "$REAL"; seal_main "$@"; exit $?\n'; } > "$1/content-seal.sh" || return 1
  # The installed layout: the join (its checks_field segments a replayed record) and the validator sit
  # beside the engine. The validator is a COUNTING wrapper over the real one: each replay the mark runs
  # appends a line to <dir>/validator.calls, so an arm can assert the BL-816 replay actually ran.
  cp "$SRCDIR/join-remediator-shards.sh" "$1/join-remediator-shards.sh" || return 1
  { printf '#!/bin/bash\nprintf "called\\n" >> %q\n' "$1/validator.calls"
    printf 'exec bash %q "$@"\n' "$SRCDIR/validate-artifact-derivations.sh"; } > "$1/validate-artifact-derivations.sh" || return 1
  printf '%s' "$1/wait-for-deliverable.sh"
}
# in_set <path relative to the state dir> -> the DECLARATION's answer (content-seal.sh seal_sealed),
# read from the library itself, so no arm restates the sealed set.
in_set() { ( fx_inproc core/scripts/content-seal.sh; . "$SEAL" && seal_sealed "$1" ); }
