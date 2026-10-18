#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# THREE ARM SCRIPTS, ONE PER READER, because the two worlds this fixture borrows
# (`adversarial-shard-merge/lib.sh`, `remediator-shard-join/lib.sh`) each own WORK, the EXIT trap and
# the ok/bad counters, and cannot be sourced into one process. Each script is run here as its own
# `bash`, from the caller's working directory; its FAIL lines carry the arm id, which is what the
# retired mutation battery read its kill sets from.
#
# THE SEALED SET IS NEVER RESTATED HERE. Each near-miss asks `content-seal.sh`'s own `seal_sealed`
# whether its path is in the set (seal-lib.sh `in_set`), so a widened or narrowed declaration moves
# the arm's subject rather than silently invalidating it.
#
# Exit: 0 every arm passed, 1 an arm failed, 2 the fixture could not run.
HERE="$(cd "$(dirname "$0")" && pwd)"
for f in seal-lib.sh merge-arms.sh join-arms.sh gate-arms.sh; do
  [ -f "$HERE/$f" ] || { echo "FIXTURE BROKEN: $HERE/$f is absent; nothing was asserted" >&2; exit 2; }
done
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
bash "$HERE/merge-arms.sh"; tally $? merge-arms.sh
bash "$HERE/join-arms.sh"; tally $? join-arms.sh
bash "$HERE/gate-arms.sh"; tally $? gate-arms.sh
[ "$broken" = 0 ] || exit 2
if [ "$rc" = 0 ]; then echo "PASS content-seal"; else echo "FAIL content-seal"; fi
exit "$rc"
