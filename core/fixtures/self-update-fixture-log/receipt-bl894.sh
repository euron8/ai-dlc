#!/usr/bin/env bash
# core/fixtures/self-update-fixture-log/receipt-bl894.sh -- the BL-894 backlog receipt: the self-update
# slice check accepts a support directory upstream ships with no run.sh (the shared lib/, a seed-only
# directory) and still refuses a directory written without its driver.
#
# Drives the REAL gate-record checker, core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh, from
# a COPY of its whole directory, against a throwaway distribution and five throwaway consumers built here
# in mktemp. Each consumer is its own repository with a self-update commit on top; the distribution's
# base gate records nothing and no record exists, so the gate-record arm answers NOT-REQUIRED and the
# slice check is the only thing that can refuse. Every case requires that NOT-REQUIRED line, so a copy
# that died early is "cannot measure", never a pass.
#   (a) the commit writes tests/fixtures/lib/inproc.sh and tests/fixtures/real/run.sh   want rc 0, no SLICE line
#   (b) the commit writes tests/fixtures/seedonly/seed.sh (README.md + seed.sh at theirs) want rc 0, no SLICE line
#   (c) the commit writes tests/fixtures/dropped/inputs.decl; dropped has run.sh at theirs  want rc 2, SLICE dropped NO-DRIVER
#   (d) the commit writes tests/fixtures/nowhere/README.md; nowhere is absent at theirs    want rc 2, SLICE nowhere NO-DRIVER
#   (e) the commit writes tests/fixtures/unreadable/README.md, judged against a COPY of the distribution
#       whose unreadable/run.sh BLOB is removed, so that read confirms neither presence nor absence
#                                                                       want rc 2, SLICE unreadable UNCONFIRMED
#   (f) core/skills/ai-dlc-update/SKILL.md states the support-directory term: a dir upstream ships with no
#       `run.sh` is a support dir written whole, and a dir upstream does not ship at `theirs` is excluded
#
# Exit 0 when every case holds. 1 when one does not (the defect reproduces). 9 when it cannot measure: no
# checker, no git, no mktemp, a world that did not build, a mode whose mutation did not apply, or a case
# whose run never reached the gate-record arm.
#
# SCORING MODES, by RECEIPT_BL894_MODE (default `tip`); each mutates the checker COPY (cmp -s guarded) and
# scores the same six cases, so one script scores every spelling:
#   tip          the shipped checker                                                  want 0
#   unfixed      the theirs reads removed: every driverless directory is NO-DRIVER    want 1
#   literal-lib  a literal `lib` exemption in place of the theirs reads               want 1
#   exempt-all   no driverless directory is ever refused                              want 1
#   bare-128     run.sh absent at theirs accepts, the directory never read            want 1
#   unconfirmed-accepts  neither UNCONFIRMED branch of the theirs reads refuses       want 1
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

r894_root() { # walk up from $1 for the checker; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh" ] && [ -f "$d/core/skills/ai-dlc-update/SKILL.md" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(r894_root "$(cd "$(dirname "$0")" && pwd)")" || { echo "receipt-bl894: no repository root" >&2; exit 9; }
RECON="$ROOT/core/skills/ai-dlc-update/reconcile"
SKILL="$ROOT/core/skills/ai-dlc-update/SKILL.md"
MODE="${RECEIPT_BL894_MODE:-tip}"
command -v git >/dev/null 2>&1 || { echo "receipt-bl894: no git" >&2; exit 9; }

W="$(mktemp -d 2>/dev/null)" || { echo "receipt-bl894: no mktemp" >&2; exit 9; }
[ -n "$W" ] && [ -d "$W" ] || exit 9
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
gi() { git -c init.templateDir= -c user.name=receipt -c user.email=receipt@invalid -c commit.gpgsign=false "$@"; }

# --- the checker COPY, mutated per mode ----------------------------------------------------------
CK="$W/reconcile"
mkdir -p "$CK" && cp -R "$RECON/." "$CK/" || exit 9
[ -f "$CK/lib.sh" ] && [ -f "$CK/preclassify.sh" ] || { echo "receipt-bl894: the checker's siblings did not copy" >&2; exit 9; }
r894_sub() { # r894_sub <old> <new> -- replace the ONE occurrence of <old> in the checker copy; exit 9 otherwise
  R_OLD="$1" R_NEW="$2" LC_ALL=C awk '
    { s = s $0 "\n" }
    END {
      o = ENVIRON["R_OLD"]; n = ENVIRON["R_NEW"]; c = 0; t = s
      while ((i = index(t, o)) > 0) { c++; t = substr(t, i + length(o)) }
      if (c != 1) exit 3
      i = index(s, o); printf "%s%s%s", substr(s, 1, i - 1), n, substr(s, i + length(o))
    }' "$CK/self-update-fixtures.sh" > "$W/ck.new" || { echo "receipt-bl894: mode $MODE: anchor not exactly once" >&2; exit 9; }
  mv -f "$W/ck.new" "$CK/self-update-fixtures.sh" || exit 9
}
L_HEAD='  elif ! git -C "$CONSUMER" cat-file -e "HEAD:${FX_ROOT}/${d}/run.sh" 2>/dev/null; then'
L_RS='    memo_has_path "$DIST" "$THEIRS" "core/fixtures/${d}/run.sh" || _rs_rc=$?'
L_DIR='      memo_has_path "$DIST" "$THEIRS" "core/fixtures/${d}" || _dir_rc=$?'
L_RSU='    elif [ "$_rs_rc" -ne 128 ]; then'
L_DIRU='      elif [ "$_dir_rc" -ne 0 ]; then'
case "$MODE" in
  tip) ;;
  unfixed) r894_sub "$L_RS" '    _rs_rc=0' ;;
  literal-lib) r894_sub "$L_RS" '    [ "$d" != lib ] || _rs_rc=128'; r894_sub "$L_DIR" '      :' ;;
  exempt-all) r894_sub "$L_HEAD" '  elif false; then' ;;
  bare-128) r894_sub "$L_DIR" '      :' ;;
  unconfirmed-accepts) r894_sub "$L_RSU" '    elif false; then'; r894_sub "$L_DIRU" '      elif false; then' ;;
  *) echo "receipt-bl894: unknown mode $MODE" >&2; exit 9 ;;
esac
if [ "$MODE" != tip ] && cmp -s "$RECON/self-update-fixtures.sh" "$CK/self-update-fixtures.sh"; then
  echo "receipt-bl894: mode $MODE produced an identical checker" >&2; exit 9
fi

# --- the distribution ----------------------------------------------------------------------------
D="$W/dist"
gi init -q "$D" >/dev/null 2>&1 || exit 9
dp() { mkdir -p "$(dirname "$D/$1")" && printf '%s\n' "$2" > "$D/$1"; }
dp core/skills/ai-dlc-update/reconcile/self-update-gate.sh '#!/usr/bin/env bash
echo SELF-UPDATE-OK'
dp core/fixtures/real/run.sh 'exit 0'
dp core/fixtures/dropped/run.sh 'exit 0'
dp core/fixtures/lib/inproc.sh 'shared helpers'
dp core/fixtures/seedonly/README.md 'a seed-only directory'
dp core/fixtures/seedonly/seed.sh 'echo seed'
dp core/fixtures/unreadable/run.sh "a driver whose blob one copy of the distribution loses $$"
{ gi -C "$D" add -A && gi -C "$D" commit -q --no-verify -m base; } >/dev/null 2>&1 || exit 9
DB="$(git -C "$D" rev-parse HEAD)" || exit 9
dp core/fixtures/real/run.sh 'exit 0 # theirs'
{ gi -C "$D" add -A && gi -C "$D" commit -q --no-verify -m theirs; } >/dev/null 2>&1 || exit 9
DT="$(git -C "$D" rev-parse HEAD)" || exit 9
# The COPY for case (e): the unreadable/run.sh blob removed, its tree still readable.
DU="$W/dist-u"
mkdir -p "$DU" && cp -R "$D/." "$DU/" || exit 9
UB="$(git -C "$D" rev-parse -q --verify "${DT}:core/fixtures/unreadable/run.sh")" || exit 9
rm -f "$DU/.git/objects/${UB:0:2}/${UB:2}" || exit 9
if git -C "$DU" cat-file -e "$UB" 2>/dev/null || ! git -C "$D" cat-file -e "$UB" 2>/dev/null; then
  echo "receipt-bl894: the unreadable/run.sh blob is not a removable loose object" >&2; exit 9
fi

# --- the consumers -------------------------------------------------------------------------------
cons() { # cons <name> <relpath>... -> a consumer whose self-update commit writes each relpath
  local c="$W/$1" p; shift
  { gi init -q "$c" && printf 'base\n' > "$c/README" && gi -C "$c" add README \
      && gi -C "$c" commit -q --no-verify -m base; } >/dev/null 2>&1 || return 1
  for p in "$@"; do mkdir -p "$c/$(dirname "$p")" && printf 'exit 0\n' > "$c/$p" || return 1; done
  { gi -C "$c" add -- tests && gi -C "$c" commit -q --no-verify -m self-update; } >/dev/null 2>&1
}
cons a tests/fixtures/lib/inproc.sh tests/fixtures/real/run.sh || exit 9
cons b tests/fixtures/seedonly/seed.sh tests/fixtures/seedonly/README.md || exit 9
cons c tests/fixtures/dropped/inputs.decl || exit 9
cons d tests/fixtures/nowhere/README.md || exit 9
cons e tests/fixtures/unreadable/README.md || exit 9

fail=0
case_run() { # case_run <name> <want-rc> <want-slice-regex|-> [<dist>] -> sets fail; exit 9 when the run never reached its gate arm
  local rc=0 o="$W/$1.out" n
  bash "$CK/self-update-fixtures.sh" "${4:-$D}" "$DB" "$DT" "$W/$1" > "$o" 2>&1 || rc=$?
  grep -q '^GATE-RECORD: NOT-REQUIRED' "$o" || { echo "receipt-bl894: case $1 never reached the gate-record arm (rc $rc)" >&2; exit 9; }
  n="$(grep -c '^GATE-RECORD: SLICE' "$o")" || n=0
  if [ "$3" = - ]; then
    [ "$rc" = "$2" ] && [ "$n" = 0 ] && { echo "case ($1): ok rc=$rc"; return; }
  else
    [ "$rc" = "$2" ] && [ "$n" = 1 ] && grep -qE "$3" "$o" && { echo "case ($1): ok rc=$rc"; return; }
  fi
  echo "case ($1): DEFECT rc=$rc slice-lines=$n"; fail=1
}
case_run a 0 -
case_run b 0 -
case_run c 2 '^GATE-RECORD: SLICE dropped — NO-DRIVER'
case_run d 2 '^GATE-RECORD: SLICE nowhere — NO-DRIVER'
case_run e 2 '^GATE-RECORD: SLICE unreadable — UNCONFIRMED: its run.sh' "$DU"

[ -f "$SKILL" ] || exit 9
if grep -qF 'a dir **upstream does not ship at `theirs`** has nothing to write' "$SKILL" \
   && grep -qF '(a support dir: the shared `lib/`, seed-only dirs) is written whole' "$SKILL"; then
  echo "case (f): ok SKILL.md states the support-directory term"
else
  echo "case (f): DEFECT SKILL.md does not state the support-directory term"; fail=1
fi

echo "receipt-bl894: mode $MODE -> $fail"
exit "$fail"
