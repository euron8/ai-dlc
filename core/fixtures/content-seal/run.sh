#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# content-seal/run.sh -- THE CONTENT SEAL on gate join inputs, driven end to end through the
# shipping programs: the PostToolUse recorder `ai-dlc-content-seal.sh` writes every seal row, and
# the three join readers (`merge-adversarial-shards.sh`, `join-remediator-shards.sh`,
# `validate-gate-adjudication.sh --merge`) are run against worlds whose join inputs were then
# changed, or not, through a channel no hook sees.
#
# THE DEFECT. At s319 the lead ran `perl -0pi` over twelve sealed-to-be adversary shards from inside
# a shell function, rewriting the `tool_use_id:` field the merge reads, and the merge exited 0. A
# remediator and a gate-adjudicator did the same with `python3` open-for-write, an adversary with
# `printf >>`. Every write-capturing hook matches Write|Edit|MultiEdit, so none of those writes left
# a record. The seal records the sha of the bytes a Write or Edit left; the readers refuse bytes that
# are not those.
#
# FOUR ARM SCRIPTS. unit-arms.sh asks the LIBRARY's answers in process: it sources content-seal.sh once,
# sources the recorder in a subshell per seal row, and calls the function each reader mode calls. The
# other three, one per READER, keep one end-to-end run per distinct outcome of that reader, because the
# two worlds they borrow (`adversarial-shard-merge/lib.sh`, `remediator-shard-join/lib.sh`) each own WORK,
# the EXIT trap and the ok/bad counters, and cannot be sourced into one process. Each script is run here
# as its own `bash`, from the caller's working directory; its FAIL lines carry the arm id.
#
# THE SEALED SET IS NEVER RESTATED HERE. Each near-miss asks `content-seal.sh`'s own `seal_sealed`
# whether its path is in the set (seal-lib.sh `in_set`), so a widened or narrowed declaration moves
# the arm's subject rather than silently invalidating it.
#
# Exit: 0 every arm passed, 1 an arm failed, 2 the fixture could not run.
HERE="$(cd "$(dirname "$0")" && pwd)"
for f in seal-lib.sh unit-arms.sh merge-arms.sh join-arms.sh gate-arms.sh; do
  [ -f "$HERE/$f" ] || { echo "FIXTURE BROKEN: $HERE/$f is absent; nothing was asserted" >&2; exit 2; }
done
. "$(cd "$HERE/../lib" && pwd)/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present subject with neither the `<p>_main() {` line nor the source guard
# predates the in-process wrap, and loading it would run its whole body: SKIP and exit 0 on a consumer (FIXTURE BROKEN in
# the distribution), never an ok. Exactly one half is a respelled subject this fixture cannot drive, which FAILS. An
# unreadable subject is FIXTURE ERROR. content-seal.sh spells its guard as `if [ ... ]; then`, every other subject as
# `|| return 0`. All of it runs BEFORE any arm script loads a subject.
cs_up() { # <dist rel> <consumer rel> -> the first existing path walking up from $HERE
  local d="$HERE" c
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    for c in "$d/$1" "$d/$2"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done
    d="$(dirname "$d")"
  done
  return 1
}
cs_halves() { # cs_halves <file> <entry> -> "<def><guard>" (1 present, 0 absent); exit 2 on an unreadable file
  local d=0 g=0 x
  grep -q "^$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1" || grep -qxF 'if [ "${BASH_SOURCE[0]}" = "$0" ]; then' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
_cs_pre=""
cs_check() { # cs_check <file> <entry>
  local gh
  [ -n "$1" ] || return 0
  gh="$(cs_halves "$1" "$2")" || exit 2
  case "$gh" in
    11) : ;;
    00) _cs_pre="$_cs_pre ${1##*/}" ;;
    *) echo "FAIL  content-seal: ${1##*/} carries one half of the in-process wrap ($2 line, source guard: $gh) -- a respelled subject this fixture cannot drive"; exit 1 ;;
  esac
}
cs_check "$(cs_up core/scripts/content-seal.sh scripts/ai-dlc/content-seal.sh)" seal_main
cs_check "$(cs_up core/hooks/ai-dlc-content-seal.sh .claude/hooks/ai-dlc-content-seal.sh)" acs_main
cs_check "$(cs_up core/scripts/merge-adversarial-shards.sh scripts/ai-dlc/merge-adversarial-shards.sh)" merge_main
cs_check "$(cs_up core/scripts/join-remediator-shards.sh scripts/ai-dlc/join-remediator-shards.sh)" join_main
cs_check "$(cs_up core/scripts/validate-gate-adjudication.sh scripts/ai-dlc/validate-gate-adjudication.sh)" vga_main
cs_check "$(cs_up core/scripts/wait-for-deliverable.sh scripts/ai-dlc/wait-for-deliverable.sh)" wfd_mark_main
if [ -n "$_cs_pre" ]; then echo "SKIP: content-seal:$_cs_pre predate(s) the in-process wrap"; fx_skip_exit "$HERE"; fi
echo "content-seal:"
rc=0; broken=0
tally() { # <exit> <arm file>
  case "$1" in
    0) ;;
    1) rc=1 ;;
    *) broken=1; echo "FIXTURE BROKEN: $2 exited $1" >&2 ;;
  esac
}
# ONE LITERAL CALL PER ARM FILE, never a loop variable: validate-fixture-git-env resolves where this
# run.sh reaches join-arms.sh's `git init` by the sibling's basename on an invoking line, so a
# `bash "$HERE/$s"` hides the site and reads as init-site-unresolved.
bash "$HERE/unit-arms.sh"; tally $? unit-arms.sh
bash "$HERE/merge-arms.sh"; tally $? merge-arms.sh
bash "$HERE/join-arms.sh"; tally $? join-arms.sh
bash "$HERE/gate-arms.sh"; tally $? gate-arms.sh
[ "$broken" = 0 ] || exit 2
if [ "$rc" = 0 ]; then echo "PASS content-seal"; else echo "FAIL content-seal"; fi
exit "$rc"
