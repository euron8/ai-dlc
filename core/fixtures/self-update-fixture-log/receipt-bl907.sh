#!/usr/bin/env bash
# core/fixtures/self-update-fixture-log/receipt-bl907.sh -- the BL-907 backlog receipt: the self-update
# checker refuses a whole fixture-directory write that overwrote a consumer edit preclassify never
# bucketed, and acquits a copy that is upstream's bytes.
#
# Drives the REAL gate-record checker, core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh, from a
# COPY of its whole directory, against a throwaway distribution and four throwaway consumers built here in
# mktemp. Each consumer is its own repository: an installed commit carrying a stamp and a fixture
# directory, then a self-update commit writing that directory whole from theirs. The distribution's gate
# records nothing and no record exists, so the gate-record arm answers NOT-REQUIRED and the slice check
# is the only thing that can refuse. Every case requires that NOT-REQUIRED line, so a copy that died early
# is "cannot measure", never a pass.
#   (a) seed.sh undiffed (equal at base and theirs), the consumer repaired it   want rc 2, SLICE UNDIFFED-OVERWRITE seed.sh
#   (b) the consumer's seed.sh equals the blob at its HEAD^ skill_commit         want rc 0, no SLICE line
#   (c) a consumer-added local.sh, absent at base and theirs, the write deleted  want rc 2, SLICE UNDIFFED-OVERWRITE local.sh
#   (d) seed.sh equal to base, the write changing only its mode                  want rc 0, no SLICE line
#   (e) the consumer edited the DIFFED run.sh (preclassify's question)          want rc 0, no SLICE line
#
# Exit 0 when every case holds. 1 when one does not (the defect reproduces). 9 when it cannot measure: no
# checker, no git, no mktemp, a world that did not build, a mode whose mutation did not apply, or a case
# whose run never reached the gate-record arm.
#
# SCORING MODES, by RECEIPT_BL907_MODE (default `tip`); each mutates the checker COPY (cmp -s guarded):
#   tip             the shipped checker                                                       want 0
#   unfixed         the UNDIFFED-OVERWRITE arm removed, every layer (its loop never entered)   want 1
#   no-skill-commit the skill_commit acquittal dropped                                         want 1
#   no-undiffed     the UNDIFFED conjunct (base blob equals theirs blob) dropped               want 1
#   hash-object     a second correct spelling: every blob compared by `git cat-file -p | git
#                   hash-object --stdin` instead of a `rev-parse <ref>:<path>` id              want 0
#   no-remedy-prose the step-2 UNDIFFED-OVERWRITE remedy paragraph deleted from a COPY of the
#                   skill (subject 2: the prose an agent reads)                                 want 1
#
# SUBJECT 2, the prose: ai-dlc-update/SKILL.md step 2 must carry the undiffed-file consumer-edit rule and
# the UNDIFFED-OVERWRITE remedy with its four parts in order (restore from HEAD^, git rm added files,
# amend, re-run the wrapper with a NEW <out>). Read on the text an agent reads: newlines and runs of blanks
# collapsed, every HTML comment span deleted first, and the phrases required in ORDER so a comment, a stub
# sentence or a bare token cannot satisfy it.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

r907_root() { # walk up from $1 for the checker; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(r907_root "$(cd "$(dirname "$0")" && pwd)")" || { echo "receipt-bl907: no repository root" >&2; exit 9; }
RECON="$ROOT/core/skills/ai-dlc-update/reconcile"
MODE="${RECEIPT_BL907_MODE:-tip}"
command -v git >/dev/null 2>&1 || { echo "receipt-bl907: no git" >&2; exit 9; }

W="$(mktemp -d 2>/dev/null)" || { echo "receipt-bl907: no mktemp" >&2; exit 9; }
[ -n "$W" ] && [ -d "$W" ] || exit 9
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
gi() { git -c init.templateDir= -c user.name=receipt -c user.email=receipt@invalid -c commit.gpgsign=false "$@"; }

# --- the checker COPY, mutated per mode ----------------------------------------------------------
CK="$W/reconcile"
mkdir -p "$CK" && cp -R "$RECON/." "$CK/" || exit 9
[ -f "$CK/lib.sh" ] && [ -f "$CK/preclassify.sh" ] || { echo "receipt-bl907: the checker's siblings did not copy" >&2; exit 9; }
r907_sub() { # r907_sub <old> <new> -- replace the ONE occurrence of <old> in the checker copy; exit 9 otherwise
  R_OLD="$1" R_NEW="$2" LC_ALL=C awk '
    { s = s $0 "\n" }
    END {
      o = ENVIRON["R_OLD"]; n = ENVIRON["R_NEW"]; c = 0; t = s
      while ((i = index(t, o)) > 0) { c++; t = substr(t, i + length(o)) }
      if (c != 1) exit 3
      i = index(s, o); printf "%s%s%s", substr(s, 1, i - 1), n, substr(s, i + length(o))
    }' "$CK/self-update-fixtures.sh" > "$W/ck.new" || { echo "receipt-bl907: mode $MODE: anchor not exactly once" >&2; exit 9; }
  mv -f "$W/ck.new" "$CK/self-update-fixtures.sh" || exit 9
}
# hash-object: a blob id derived from the bytes, through a helper defined just above the loop. A failed
# cat-file keeps the memo's discrimination: 128 with no object is "absent" only when ls-tree confirms it.
HO_FN='r907_blob() { # <repo> <ref:path> -> the blob id from its bytes; 0 present, 1 absent, 125 unconfirmable
  local _o _h
  _o="$(git -C "$1" cat-file -t "$2" 2>/dev/null)" || { _ai_dlc_rev_absent "$1" "$2" && return 1; return 125; }
  [ "$_o" = blob ] || return 125
  _h="$(git -C "$1" cat-file -p "$2" 2>/dev/null | git hash-object --stdin 2>/dev/null)" || return 125
  [ -n "$_h" ] || return 125
  printf "%s\n" "$_h"
}
su_slice_bad=""'
case "$MODE" in
  tip) ;;
  unfixed)
    r907_sub '    case "$_ud_f" in "$FX_ROOT/$d/"*) ;; *) continue ;; esac' '    continue' ;;
  no-skill-commit)
    r907_sub '    [ -n "$_ud_skb" ] && [ "$_ud_c" = "$_ud_skb" ] && continue' '    :' ;;
  no-undiffed)
    r907_sub '    if [ "$_ud_brc" -eq 0 ] && [ "$_ud_trc" -eq 0 ] && [ "$_ud_b" = "$_ud_t" ]; then' '    if [ "$_ud_brc" -eq 0 ] && [ "$_ud_trc" -eq 0 ]; then' ;;
  hash-object)
    r907_sub 'su_slice_bad=""' "$HO_FN"
    r907_sub '_ud_c="$(memo_rev_parse "$CONSUMER" "HEAD^:${_ud_f}")"' '_ud_c="$(r907_blob "$CONSUMER" "HEAD^:${_ud_f}")"'
    r907_sub '_ud_b="$(memo_rev_parse "$DIST" "${BASE}:${_ud_core}")"' '_ud_b="$(r907_blob "$DIST" "${BASE}:${_ud_core}")"'
    r907_sub '_ud_t="$(memo_rev_parse "$DIST" "${THEIRS}:${_ud_core}")"' '_ud_t="$(r907_blob "$DIST" "${THEIRS}:${_ud_core}")"'
    r907_sub '_ud_skb="$(memo_rev_parse "$DIST" "${_ud_sk}:${_ud_core}")"' '_ud_skb="$(r907_blob "$DIST" "${_ud_sk}:${_ud_core}")"' ;;
  no-remedy-prose) ;;
  *) echo "receipt-bl907: unknown mode $MODE" >&2; exit 9 ;;
esac
SKILL="$ROOT/core/skills/ai-dlc-update/SKILL.md"
[ -f "$SKILL" ] || { echo "receipt-bl907: no ai-dlc-update/SKILL.md" >&2; exit 9; }
if [ "$MODE" = no-remedy-prose ]; then
  LC_ALL=C awk '/^     \*\*An `UNDIFFED-OVERWRITE` refusal has a sanctioned remedy/ {p=1} !p {print} p && /safe fallback\.$/ {p=0}' "$SKILL" > "$W/SKILL.md" || exit 9
  cmp -s "$SKILL" "$W/SKILL.md" && { echo "receipt-bl907: mode $MODE produced an identical skill" >&2; exit 9; }
  SKILL="$W/SKILL.md"
fi
if [ "$MODE" != tip ] && [ "$MODE" != no-remedy-prose ] && cmp -s "$RECON/self-update-fixtures.sh" "$CK/self-update-fixtures.sh"; then
  echo "receipt-bl907: mode $MODE produced an identical checker" >&2; exit 9
fi

# --- the distribution: seed.sh equal at base and theirs, a third content at SK; run.sh moves -----
D="$W/dist"
gi init -q "$D" >/dev/null 2>&1 || exit 9
dp() { mkdir -p "$(dirname "$D/$1")" && printf '%s\n' "$2" > "$D/$1"; }
SEED='seed, never changed upstream'
dp core/skills/ai-dlc-update/reconcile/self-update-gate.sh '#!/usr/bin/env bash
echo SELF-UPDATE-OK'
dp core/fixtures/fx/run.sh 'run at base'
dp core/fixtures/fx/seed.sh "$SEED"
{ gi -C "$D" add -A && gi -C "$D" commit -q --no-verify -m base; } >/dev/null 2>&1 || exit 9
DB="$(git -C "$D" rev-parse HEAD)" || exit 9
dp core/fixtures/fx/seed.sh 'seed at the skill_commit release'
{ gi -C "$D" add -A && gi -C "$D" commit -q --no-verify -m sk; } >/dev/null 2>&1 || exit 9
DSK="$(git -C "$D" rev-parse HEAD)" || exit 9
dp core/fixtures/fx/seed.sh "$SEED"
dp core/fixtures/fx/run.sh 'run at theirs'
{ gi -C "$D" add -A && gi -C "$D" commit -q --no-verify -m theirs; } >/dev/null 2>&1 || exit 9
DT="$(git -C "$D" rev-parse HEAD)" || exit 9

# --- the consumers -------------------------------------------------------------------------------
cput() { mkdir -p "$(dirname "$1/$2")" && printf '%s\n' "$3" > "$1/$2"; }
cons() { # cons <name> <skill_commit> <seed-before> <local-before|-> [chmod|-] [run-before]
  local c="$W/$1" fx="$W/$1/tests/fixtures/fx" runb="${6:-run at base}"
  gi init -q "$c" >/dev/null 2>&1 || return 1
  printf 'base\n' > "$c/README" || return 1
  cput "$c" .claude/.ai-dlc-version "version: 1.0.0
commit: $DB
skill_commit: $2" && cput "$c" tests/fixtures/fx/seed.sh "$3" && cput "$c" tests/fixtures/fx/run.sh "$runb" || return 1
  [ "$4" = - ] || cput "$c" tests/fixtures/fx/local.sh "$4" || return 1
  { gi -C "$c" add -A && gi -C "$c" commit -q --no-verify -m installed; } >/dev/null 2>&1 || return 1
  rm -f "$fx/run.sh" "$fx/seed.sh" "$fx/local.sh" || return 1
  git -C "$D" show "${DT}:core/fixtures/fx/run.sh" > "$fx/run.sh" && git -C "$D" show "${DT}:core/fixtures/fx/seed.sh" > "$fx/seed.sh" || return 1
  [ "${5:-}" != chmod ] || chmod 755 "$fx/seed.sh" || return 1
  cput "$c" .claude/.ai-dlc-version "version: 1.0.0
commit: $DB
skill_commit: $DT" || return 1
  { gi -C "$c" add -A && gi -C "$c" commit -q --no-verify -m self-update; } >/dev/null 2>&1
}
cons a "$DB" 'seed, REPAIRED by the consumer' - || exit 9
cons b "$DSK" 'seed at the skill_commit release' - || exit 9
cons c "$DB" "$SEED" 'a consumer-added helper' || exit 9
cons d "$DB" "$SEED" - chmod || exit 9
cons e "$DB" "$SEED" - - 'run, edited by the consumer' || exit 9
# Every world's commit must LIST its subject, or its case is not asked at all.
for p in a:seed.sh b:seed.sh c:local.sh d:seed.sh e:run.sh; do
  l="$(git -C "$W/${p%%:*}" diff --name-only 'HEAD^' HEAD -- tests/fixtures/fx/)" || exit 9
  case "$l" in *"tests/fixtures/fx/${p#*:}"*) ;; *) echo "receipt-bl907: world ${p%%:*} does not list ${p#*:}" >&2; exit 9 ;; esac
done

fail=0
case_run() { # case_run <name> <want-rc> <want-slice-regex|-> -> sets fail; exit 9 when the run never reached its gate arm
  local rc=0 o="$W/$1.out" n
  bash "$CK/self-update-fixtures.sh" "$D" "$DB" "$DT" "$W/$1" > "$o" 2>&1 || rc=$?
  grep -q '^GATE-RECORD: NOT-REQUIRED' "$o" || { echo "receipt-bl907: case $1 never reached the gate-record arm (rc $rc)" >&2; exit 9; }
  n="$(grep -c '^GATE-RECORD: SLICE' "$o")" || n=0
  if [ "$3" = - ]; then
    [ "$rc" = "$2" ] && [ "$n" = 0 ] && { echo "case ($1): ok rc=$rc"; return; }
  else
    [ "$rc" = "$2" ] && [ "$n" = 1 ] && grep -qE "$3" "$o" && { echo "case ($1): ok rc=$rc"; return; }
  fi
  echo "case ($1): DEFECT rc=$rc slice-lines=$n"; fail=1
}
case_run a 2 '^GATE-RECORD: SLICE fx — UNDIFFED-OVERWRITE: tests/fixtures/fx/seed.sh'
case_run b 0 -
case_run c 2 '^GATE-RECORD: SLICE fx — UNDIFFED-OVERWRITE: tests/fixtures/fx/local.sh'
case_run d 0 -
case_run e 0 -

prose="$(tr '\n' ' ' < "$SKILL" | tr -s ' \t' '  ' | LC_ALL=C awk '{ s = $0
  while ((i = index(s, "<!--")) > 0) { r = substr(s, i + 4); j = index(r, "-->"); if (j == 0) { s = substr(s, 1, i - 1); break }; s = substr(s, 1, i - 1) substr(r, j + 3) }
  print s }')"
case "$prose" in
  *'In a directory written whole, a file with NO `preclassify.sh` row'*'is a consumer edit when its consumer copy differs from the distribution blob at `base` AND at the stamp'*'or when the consumer added it (absent upstream at both refs)'*'holds its whole directory back under the ONE-UNIT rule below'*'An `UNDIFFED-OVERWRITE` refusal has a sanctioned remedy that lands the cycle'*'restore it from the parent commit with `git checkout HEAD^ -- <dir>`'*'`git rm` any file the commit added under it'*'run `git commit --amend --no-edit`'*'re-run the push wrapper with a NEW `<out>` path'*)
    echo "prose: ok (undiffed-file rule and the four-part remedy in step 2)" ;;
  *) echo "prose: DEFECT step 2 lacks the undiffed-file rule or the four-part UNDIFFED-OVERWRITE remedy"; fail=1 ;;
esac

echo "receipt-bl907: mode $MODE -> $fail"
exit "$fail"
