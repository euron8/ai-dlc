#!/usr/bin/env bash
# check-24-adversarial-convergence/receipt-bl1175c.sh [<validator>] -- the backlog receipt for BL-1175 item 13 (the
# attestation's `differs` pass): the write ledger holds only a sha256 of the bytes the merge wrote, so a pass whose
# bytes moved read every underived and repair-introduced count as 0 even when the move touched one unrelated line.
# The validator now recovers the bytes whose sha256 the newest merge row records from git history and reads the
# counts from THEM. It drives the SHIPPED validator in a mktemp world and reads no fixture file.
#
#   exit 0   the fix is present        exit 1   it is not        exit 9   the receipt cannot measure
#
# Worlds (each its own git repository, one MET pass: findings_major 6, findings_major_underived U, the pass written
# by the merge's own seal record, `content-seal.sh --record`, then bytes edited):
#   benign   merged with underived 3, committed, then only `invoked_at` edited and committed
#                                     base FAIL (B -- CONSISTENCY), fix: no FAIL, exit 0
#   tamper   merged with underived 1, committed; v2 with underived 3 committed on top
#                                     the recovered bytes say 1: FAIL (B -- CONSISTENCY), exit 1
#   nocommit the merged bytes never committed (only the edited bytes are): no version hashes to the row, so the
#            disbelief stands: FAIL (B -- CONSISTENCY), exit 1, no recovery note
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ="${1:-}"
if [ -z "$SUBJ" ]; then
  for c in "$HERE/../../scripts/validate-adversarial-convergence.sh" \
           "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh"; do
    [ -f "$c" ] && { SUBJ="$c"; break; }
  done
fi
[ -n "$SUBJ" ] && [ -f "$SUBJ" ] || { echo "receipt: no validate-adversarial-convergence.sh to score" >&2; exit 9; }
# The validator is asked in process when wrapped (vac-inproc.sh), as a process otherwise.
# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")" && pwd)/vac-inproc.sh" || { echo "receipt: cannot source vac-inproc.sh beside this receipt" >&2; exit 9; }
SEAL="$(cd "$(dirname "$SUBJ")" && pwd)/content-seal.sh"
[ -f "$SEAL" ] || { echo "receipt: no content-seal.sh beside the validator" >&2; exit 9; }
command -v git >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || { echo "receipt: git and jq are required" >&2; exit 9; }
B="$(mktemp -d "${TMPDIR:-/tmp}/bl1175c-receipt-XXXXXX")" || exit 9
B="$(cd "$B" && pwd -P)"
ST=_bmad-output
D=$ST/planning-artifacts/s1
lg() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid \
       -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
pass() { # file underived invoked_at artifact-sha
  { printf '# test strategy -- adversarial pass 1\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n'
    printf 'invoked_at: %s\ntool_use_id: toolu_receipt_t1\nmode: subagent\nlead_role: qa\nartifact: %s\nartifact_sha: %s\n' "$3" "$D/artifact.md" "$4"
    printf 'shard_tool_use_ids: toolu_shard_1\n'
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 6\nfindings_major_underived: %s\nfindings_minor: 0\n' "$2"
    printf 'verdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n'
    printf '\n### M1 -- MAJOR a\n### M2 -- MAJOR b\n### M3 -- MAJOR c\n### M4 -- MAJOR d\n'; } > "$1"
}
world() { # name underived-v1 commit-v1(yes|no) invoked-v2 underived-v2
  local w="$B/$1" p a
  mkdir -p "$w/$D" || return 1
  printf '# artifact\n' > "$w/$D/artifact.md"; a="$(sha "$w/$D/artifact.md")"
  p="$w/$D/test-strategy-adversarial-p1.md"
  ( lg "$w" init -q . && lg "$w" add . && lg "$w" commit -q -m base ) >/dev/null 2>&1 || return 1
  pass "$p" "$2" 2026-09-29T11:00:00Z "$a"
  bash "$SEAL" --record "$w/$ST" program:merge-adversarial-shards "$p" >/dev/null 2>&1 || return 1
  if [ "$3" = yes ]; then ( lg "$w" add "$D/test-strategy-adversarial-p1.md" && lg "$w" commit -q -m merged ) >/dev/null 2>&1 || return 1; fi
  pass "$p" "$5" "$4" "$a"
  ( lg "$w" add "$D/test-strategy-adversarial-p1.md" && lg "$w" commit -q -m edited ) >/dev/null 2>&1 || return 1
}
{ world benign 3 yes 2026-09-29T11:30:00Z 3 && world tamper 1 yes 2026-09-29T11:00:00Z 3 \
    && world nocommit 3 no 2026-09-29T11:30:00Z 3; } || { echo "receipt: a world could not be built under $B" >&2; exit 9; }
[ -n "$(lg "$B/benign" log --all --format=%H -- "$D/test-strategy-adversarial-p1.md")" ] \
  && [ "$(lg "$B/nocommit" log --all --format=%H -- "$D/test-strategy-adversarial-p1.md" | wc -l | tr -d ' ')" = 1 ] \
  && grep -q '"actor":"program:merge-adversarial-shards"' "$B/benign/$ST/planning-artifacts/.artifact-writes.jsonl" \
  || { echo "receipt: world shape wrong" >&2; exit 9; }

run() { # world -> RC, OUT
  OUT="$(GIT_CEILING_DIRECTORIES="$B" rcpt_vac "$SUBJ" --series "$B/$1/$D/test-strategy-adversarial-p" 2>&1)"; RC=$?
}
bad=""
run benign;   [ "$RC" -eq 0 ] && [[ "$OUT" != *"FAIL (B -- CONSISTENCY)"* ]] && [[ "$OUT" == *"recovered from git history"* ]] || bad="$bad benign(rc=$RC)"
run tamper;   [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (B -- CONSISTENCY)"* ]] && [[ "$OUT" == *"findings_major_underived=1"* ]] || bad="$bad tamper(rc=$RC)"
run nocommit; [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (B -- CONSISTENCY)"* ]] && [[ "$OUT" != *"recovered from git history"* ]] || bad="$bad nocommit(rc=$RC)"
if [ -n "$bad" ]; then echo "receipt BL-1175c: NOT FIXED --$bad"; exit 1; fi
echo "receipt BL-1175c: fixed (a moved-bytes pass reads the counts of the bytes its merge row records: benign MET, tamper and uncommitted FAIL)"
exit 0
