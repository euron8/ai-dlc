#!/usr/bin/env bash
# check-24-adversarial-convergence/receipt-bl736.sh [<validator>] -- the backlog receipt for BL-736: a
# story split carried into test-strategy.md by a repair chain is a SCOPE change, which arm J2 refuses
# unless it is re-opened on the record. It drives the SHIPPED validator in a mktemp world and reads no
# fixture file.
#
#   exit 0   the fix is present        exit 1   it is not        exit 9   the receipt cannot measure
#
# The subject is resolved from this file's tree (core/scripts/ in the distribution, scripts/ai-dlc/
# installed); an argument names another copy, which is how the base and a mutant are scored.
#
# Each world is its own git repository whose strategy rows take graph s319's real shape
# (`| ST319-2.3-01 | 2.3a | AC1 | ...`), stamped at the validator's own J2T_RELEASE:
#   reword   v1 -> same story ids, one row's type changed, one repair link     J2 silent, exit 0
#   split    v1 (2.3) -> 2.3a + 2.3b, one repair link                          FAIL (J2), exit 1
#   merge    2.3a/2.3b -> 2.3 while the ROW ids keep `2.3a`/`2.3b` and the prose names all three;
#            a whole-file id scan reads both sides equal                        FAIL (J2), exit 1
#   reopen   split's bytes, no link, a REOPEN_AFTER_MET record + ONE verify pass   J2 silent, exit 0
#   unreach  split, the notarized v1 never committed                           PENDING (J2), exit 0
#   norows   v1 -> a strategy mapping no row (the prose names 2.3a/2.3b)        PENDING (J2), exit 0:
#            an empty extraction is UNJUDGED, never "unchanged" and never FAIL
#   legacy   split, the first pass dated BEFORE the J2T_RELEASE stamp            PENDING Legacy, exit 0
#   nostamp  split, .claude/.ai-dlc-version on disk and in NO commit             PENDING not owed yet, exit 0
#   pred     split, the repo stamped only at J2T_RELEASE's predecessor          PENDING not owed yet, exit 0
#
# The era worlds are stamped at the J2T_RELEASE of RCPT_STAMP_FROM when it is set (the shipped
# validator, so a mutant whose constant was lowered or raised is dated against the real stamp: raised,
# split reads not-owed; lowered, pred FAILs), else of the subject.
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
command -v git >/dev/null 2>&1 || { echo "receipt: git is not on PATH" >&2; exit 9; }
# The era stamp is the validator's own constant; a copy without one (the base) is stamped at the
# release after which every series is owed under any later constant.
STAMP_FROM="${RCPT_STAMP_FROM:-$SUBJ}"
[ -f "$STAMP_FROM" ] || { echo "receipt: RCPT_STAMP_FROM names no file ($STAMP_FROM)" >&2; exit 9; }
REL="$(sed -n 's/^J2T_RELEASE="\([0-9.]*\)"$/\1/p' "$STAMP_FROM")"; [ -n "$REL" ] || REL="99.0.0"
IFS=. read -r r_ma r_mi r_pa <<EOF
$REL
EOF
if [ "$r_mi" -ge 1 ] 2>/dev/null; then PRED="${r_ma}.$((r_mi - 1)).${r_pa}"; else PRED="$((r_ma - 1)).999.${r_pa}"; fi

B="$(mktemp -d "${TMPDIR:-/tmp}/bl736-receipt-XXXXXX")" || exit 9
B="$(cd "$B" && pwd -P)"
TS=_bmad-output/planning-artifacts/s1/test-strategy.md
D=_bmad-output/planning-artifacts/s1
lg() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid \
       -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
strat() {
  if [ "$1" = norows ]; then
    printf '# Sprint 1 test strategy\n\nThe mapping moved to an appendix; Story 1.1, 2.3a and 2.3b are named here only.\n'; return 0
  fi
  printf '# Sprint 1 test strategy\n\nStory 2.3 is covered below.\n\n| id | story | ac | type |\n|---|---|---|---|\n'
  printf '| ST1-1.1-01 | 1.1 | AC1 | unit | test | - |\n'
  case "$1" in
    v1)     printf '| ST1-2.3-01 | 2.3 | AC1 | unit | test | - |\n| ST1-2.3-02 | 2.3 | AC2 | unit | test | - |\n' ;;
    reword) printf '| ST1-2.3-01 | 2.3 | AC1 | integration | test | - |\n| ST1-2.3-02 | 2.3 | AC2 | unit | test | - |\n' ;;
    split)  printf '| ST1-2.3-01 | 2.3a | AC1 | unit | test | - |\n| ST1-2.3-02 | 2.3b | AC1 | unit | test | - |\n' ;;
    lsplit) printf '| ST1-2.3a-01 | 2.3a | AC1 | unit | test | - |\n| ST1-2.3b-01 | 2.3b | AC1 | unit | test | - |\nStories 2.3a and 2.3b.\n' ;;
    merge)  printf '| ST1-2.3a-01 | 2.3 | AC1 | unit | test | - |\n| ST1-2.3b-01 | 2.3 | AC2 | unit | test | - |\nStories 2.3a and 2.3b were one.\n' ;;
  esac
}
pass() { # world n invoked_at sha [resolves]
  { printf '# test strategy -- adversarial pass %s\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n' "$2"
    printf 'invoked_at: %s\ntool_use_id: toolu_receipt_t%s\nmode: subagent\nlead_role: qa\nartifact: %s\nartifact_sha: %s\n' "$3" "$2" "$TS" "$4"
    [ -n "${5:-}" ] && printf 'resolves_divergence: %s\n' "$5"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\n'
    printf 'verdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$B/$1/$D/test-strategy-adversarial-p$2.md"
}
link() { # world before after
  printf '# Repair record\n\n- artifact: `%s`\n- artifact_sha_before: %s\n- artifact_sha_after: %s\n\n### G1 — MAJOR\n- **disposition:** repaired\n- **edit:** `%s:8`\n- **derivation:** n/a (no factual claim)\n' \
    "$TS" "$2" "$3" "$TS" > "$B/$1/$D/test-strategy-repair-p1.md"
}
world() { # name before after commit-before(yes|no) [invoked_at] [nostamp|<stamp version>]
  # -> the repo, p1 MET over before, disk at after, one link. nostamp: the version file is on disk and
  # in no commit, the strategy's before bytes committed alone. A version stamps the repo at it, not REL.
  local w="$B/$1" b a sv="${6:-$REL}"
  mkdir -p "$w/.claude" "$w/$D" || return 1
  strat "$2" > "$w/$TS"; b="$(sha "$w/$TS")"
  if [ "$sv" = nostamp ]; then
    ( printf 'version: %s\n' "$REL" > "$w/.claude/.ai-dlc-version"
      lg "$w" init -q . && lg "$w" add "$TS" \
        && GIT_COMMITTER_DATE=2026-09-29T09:30:00Z GIT_AUTHOR_DATE=2026-09-29T09:30:00Z lg "$w" commit -q -m ts-v1 ) >/dev/null 2>&1 || return 1
  else
  ( printf 'version: 0.669.0\n' > "$w/.claude/.ai-dlc-version"
    lg "$w" init -q . && lg "$w" add .claude/.ai-dlc-version \
      && GIT_COMMITTER_DATE=2026-09-29T09:00:00Z GIT_AUTHOR_DATE=2026-09-29T09:00:00Z lg "$w" commit -q -m stamp-old || exit 1
    if [ "$4" = yes ]; then
      lg "$w" add "$TS" && GIT_COMMITTER_DATE=2026-09-29T09:30:00Z GIT_AUTHOR_DATE=2026-09-29T09:30:00Z lg "$w" commit -q -m ts-v1 || exit 1
    fi
    printf 'version: %s\n' "$sv" > "$w/.claude/.ai-dlc-version" && lg "$w" add .claude/.ai-dlc-version \
      && GIT_COMMITTER_DATE=2026-09-29T10:00:00Z GIT_AUTHOR_DATE=2026-09-29T10:00:00Z lg "$w" commit -q -m stamp-new ) >/dev/null 2>&1 || return 1
  fi
  pass "$1" 1 "${5:-2026-09-29T11:00:00Z}" "$b"
  strat "$3" > "$w/$TS"; a="$(sha "$w/$TS")"
  link "$1" "$b" "$a"
  printf '%s %s\n' "$b" "$a" > "$w/.shas"
}
{ world reword v1 reword yes && world split v1 split yes && world merge lsplit merge yes \
    && world reopen v1 split yes && world unreach v1 split no && world norows v1 norows yes \
    && world legacy v1 split yes 2026-09-29T09:45:00Z && world nostamp v1 split yes 2026-09-29T11:00:00Z nostamp \
    && world pred v1 split yes 2026-09-29T11:00:00Z "$PRED"; } || { echo "receipt: a world could not be built under $B" >&2; exit 9; }
# reopen: the link replaced by the re-open record and ONE verify pass notarizing the disk bytes.
read -r rb ra < "$B/reopen/.shas"
rm -f "$B/reopen/$D/test-strategy-repair-p1.md"
printf '# Divergence resolution\n\n<!-- ADVERSARIAL_RESOLUTION v1\nresolves: test-strategy-adversarial-p1.md\nresolution: REOPEN_AFTER_MET\nadjudicated_by: operator\nartifact: %s\nartifact_sha_before: %s\nartifact_sha_after: %s\nartifact_bytes_before: 200\nartifact_bytes_after: 210\nscope_delta: story 2.3 split into 2.3a and 2.3b\noperator_authorization: 2026-09-29T11:30:00Z | "re-open the test strategy for the 2.3 split"\noptions_presented: 3\nrecommended_option: REOPEN_AFTER_MET\nADVERSARIAL_RESOLUTION_END -->\n' \
  "$TS" "$rb" "$ra" > "$B/reopen/$D/test-strategy-resolution-p1.md"
pass reopen 2 2026-09-29T12:00:00Z "$ra" test-strategy-resolution-p1.md
printf '%s\n' '{"type":"user","timestamp":"2026-09-29T11:30:00Z","message":{"content":"Yes: re-open the test strategy for the 2.3 split."}}' > "$B/transcript.jsonl"
# THE WORLDS ARE WHAT THEY CLAIM: merge's two sides carry the same whole-file id set, and unreach's v1 is
# in no commit while split's is.
ids_all() { grep -oE '[0-9]+\.[0-9]+[a-z]?' "$1" | sort -u | tr '\n' ' '; }
strat lsplit > "$B/m-before"; [ "$(ids_all "$B/m-before")" = "$(ids_all "$B/merge/$TS")" ] || { echo "receipt: merge world is not whole-file-equal" >&2; exit 9; }
[ -z "$(lg "$B/unreach" log --all --format=%H -- "$TS")" ] && [ -n "$(lg "$B/split" log --all --format=%H -- "$TS")" ] \
  || { echo "receipt: unreach/split commit shape wrong" >&2; exit 9; }
# nostamp's version file is on disk and in no commit while its v1 is; pred's stamp is the predecessor.
[ -z "$(lg "$B/nostamp" log --all --format=%H -- .claude/.ai-dlc-version)" ] && [ -f "$B/nostamp/.claude/.ai-dlc-version" ] \
  && [ -n "$(lg "$B/nostamp" log --all --format=%H -- "$TS")" ] && grep -qx "version: $PRED" "$B/pred/.claude/.ai-dlc-version" \
  || { echo "receipt: nostamp/pred stamp shape wrong" >&2; exit 9; }

run() { # world -> RC, OUT
  OUT="$(GIT_CEILING_DIRECTORIES="$B" bash "$SUBJ" --series "$B/$1/$D/test-strategy-adversarial-p" \
         --transcript "$B/transcript.jsonl" 2>&1)"; RC=$?
}
bad=""
run reword;  [ "$RC" -eq 0 ] && [[ "$OUT" != *"J2 -- DRIFT"* ]] || bad="$bad reword(rc=$RC)"
run split;   [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J2 -- DRIFT)"* ]] && [[ "$OUT" == *"-2.3 +2.3a +2.3b"* ]] || bad="$bad split(rc=$RC)"
run merge;   [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J2 -- DRIFT)"* ]] && [[ "$OUT" == *"-2.3a -2.3b +2.3"* ]] || bad="$bad merge(rc=$RC)"
run reopen;  [ "$RC" -eq 0 ] && [[ "$OUT" != *"J2 -- DRIFT"* ]] || bad="$bad reopen(rc=$RC)"
run unreach; [ "$RC" -eq 0 ] && [[ "$OUT" == *"PENDING (J2 -- DRIFT)"* ]] && [[ "$OUT" == *"no committed version"* ]] && [[ "$OUT" != *"FAIL (J2"* ]] || bad="$bad unreach(rc=$RC)"
run norows;  [ "$RC" -eq 0 ] && [[ "$OUT" == *"PENDING (J2 -- DRIFT)"* ]] && [[ "$OUT" == *"unjudged"* ]] && [[ "$OUT" != *"FAIL (J2"* ]] || bad="$bad norows(rc=$RC)"
run legacy;  [ "$RC" -eq 0 ] && [[ "$OUT" == *"PENDING (J2 -- DRIFT)"* ]] && [[ "$OUT" == *"Legacy series."* ]] && [[ "$OUT" != *"FAIL (J2"* ]] || bad="$bad legacy(rc=$RC)"
run nostamp; [ "$RC" -eq 0 ] && [[ "$OUT" == *"PENDING (J2 -- DRIFT)"* ]] && [[ "$OUT" == *"not owed yet"* ]] && [[ "$OUT" != *"FAIL (J2"* ]] || bad="$bad nostamp(rc=$RC)"
run pred;    [ "$RC" -eq 0 ] && [[ "$OUT" == *"PENDING (J2 -- DRIFT)"* ]] && [[ "$OUT" == *"not owed yet"* ]] && [[ "$OUT" != *"FAIL (J2"* ]] || bad="$bad pred(rc=$RC)"
if [ -n "$bad" ]; then echo "receipt BL-736: NOT FIXED --$bad"; exit 1; fi
echo "receipt BL-736: fixed (reword silent, split and merge FAIL by story column, reopen silent, unreachable PENDING, legacy, unstamped and predecessor-stamped PENDING by era)"
exit 0
