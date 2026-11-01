#!/usr/bin/env bash
# backlog-real-ledger -- the two joins and the one label probe whose verdict depends on the CONTENT
# of a real-sized ledger, run over a FROZEN SNAPSHOT of this repository's docs/backlog.md.
#
#   j1   the receipts validator's `sh` population covers the shipping classifier's resolved set
#        on the snapshot (scripts/validate-backlog-receipts.sh vs scripts/backlog-reverify.sh)
#   b16  the size ceiling's entry count equals the classifier's on the snapshot
#        (scripts/validate-backlog-size.sh vs scripts/backlog-reverify.sh)
#   p1   a prose lead-in bullet in a host appended to the snapshot counts once, never twice
#
# THE LEDGER IS ledger.snapshot BESIDE THIS FILE, NOT docs/backlog.md (BL-872). Keyed on the live
# ledger, this unit's invocations.decl counted validator STARTS over that content, so every backlog
# edit re-keyed it or turned it red. The snapshot was copied byte-identical from docs/backlog.md at
# the BL-872 base, and it is refreshed only when one of the three subjects changes shape enough to
# need a newer real corpus; the count then moves with it, in that change. It is not named `.md` so
# that no markdown scanner reads its frozen citations as live ones.
#
# WHAT THE SNAPSHOT MAKES VACUOUS, AND WHERE THAT MOVED. Over a frozen file j1 and b16 can no longer
# see LIVE drift -- a receipt or an entry shape filed after the snapshot. That half runs as arm R9
# of scripts/validate-backlog-receipts.sh in the `.githooks/pre-push` step "backlog receipts" (a
# keyed step whose key holds the ledger; AI_DLC_PRESUITE_SKIP=1 skips it), against the live ledger,
# through the same two readers and the same comparison. What
# stays here is the half a frozen corpus still answers: the three programs, as CHANGED, still agree
# on a real-sized ledger, and p1's label rule (lib.sh's, the subject) still reads one host as one.
# The anchor-collision guard on BL-899 below is now a constant against the snapshot (max id BL-883);
# it can fire only when the snapshot is refreshed past it.
#
# Usage: run.sh
# Exit:  0 = both arms hold, 1 = one regressed, 2 = fixture broken.
# THE ONE MUTANT (m-loose, the strict bullet test deleted from the seed's lib.sh) is scored on its
# deciding arm p1-count (the ceiling reads the real ledger plus one host as +2, not +1) plus ONE named
# twin, b16-count, which must stay green: the same mutated tree reading the real ledger ALONE still
# agrees with the unmutated count, so the effect is confined to the phantom bullet. The mutant x arm
# matrix is MEASURED by the --matrix argv mode and is re-measured whenever an arm or a mutant is added
# or changed. The recorded matrix plus the twin replaces the exact-vector assertion.
# MUTANT-MATRIX m-loose decides=p1-count twins=b16-count
# MUTANT-MATRIX m-r9call decides=r9-call twins=j1-pop
# MUTANT-MATRIX-REMEASURE bash core/fixtures/backlog-real-ledger/run.sh --matrix
set -u

MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi
MROWS=0

# CLEAR EVERY AMBIENT AI_DLC_* KEY (I87): b16 passes its ceiling as a double-quoted `env` word,
# which is not an assignment for the probes that do not set it.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# SCRUB THE REPOSITORY ENVIRONMENT: j1 runs `git init` in mktemp trees, and an inherited GIT_DIR
# makes `git init` succeed without creating a repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
# The receipts validator's re-entry sentinel: inherited, every run below would score nothing.
unset BR_RECEIPTS_RUNNING

DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$DIR/../lib/mutant.sh" ] && [ -f "$DIR/../lib/matrix.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh or lib/matrix.sh not found" >&2; exit 2; }
find_one() { # find_one <relative path>... -> the first candidate that is a file, both layouts
  local c
  for c in "$@"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done
  return 1
}
RECEIPTS="$(find_one "$DIR/../../scripts/validate-backlog-receipts.sh" "$DIR/../../../scripts/validate-backlog-receipts.sh")" || RECEIPTS=""
SIZE="$(find_one "$DIR/../../scripts/validate-backlog-size.sh" "$DIR/../../../scripts/validate-backlog-size.sh")" || SIZE=""
REVERIFY="$(find_one "$DIR/../../scripts/backlog-reverify.sh" "$DIR/../../../scripts/backlog-reverify.sh")" || REVERIFY=""
LIBSRC="$(find_one "$DIR/../../skills/ai-dlc-update/reconcile/lib.sh" "$DIR/../../../core/skills/ai-dlc-update/reconcile/lib.sh")" || LIBSRC=""
REVSRC="$(find_one "$DIR/../../skills/ai-dlc-update/reconcile/ledger-reverify.sh" "$DIR/../../../core/skills/ai-dlc-update/reconcile/ledger-reverify.sh")" || REVSRC=""
EXTRACT="$(find_one "$DIR/../../../docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py" "$DIR/../../docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py")" || EXTRACT=""
# The could-not-measure rule both the classifier and the receipts validator source from beside them.
RLIB="$(find_one "$DIR/../../scripts/backlog-receipt-lib.sh" "$DIR/../../../scripts/backlog-receipt-lib.sh")" || RLIB=""
# The frozen ledger (BL-872); see the header. REAL_LEDGER keeps its name: it is a real ledger, frozen.
REAL_LEDGER=""
[ -f "$DIR/ledger.snapshot" ] && REAL_LEDGER="$DIR/ledger.snapshot"
for _p in RECEIPTS SIZE REVERIFY LIBSRC REVSRC EXTRACT RLIB REAL_LEDGER; do
  eval "_v=\${$_p}"
  [ -n "$_v" ] || { echo "FIXTURE BROKEN: backlog-real-ledger could not resolve $_p" >&2; exit 2; }
done
echo "HERMETIC-CONSUMED scripts/validate-backlog-receipts.sh"
echo "HERMETIC-CONSUMED scripts/validate-backlog-size.sh"
echo "HERMETIC-CONSUMED scripts/backlog-reverify.sh"

TMP="$(mktemp -d)"
cleanup() {
  for _r in "$TMP"/*; do
    [ -d "$_r/.git" ] && git -C "$_r" worktree prune >/dev/null 2>&1
  done
  rm -rf "$TMP"
}
trap cleanup EXIT
rc=0
note() { printf '%s\n' "$*"; }
ok()  { note "ok    $1"; }
bad() { note "FAIL  $1"; rc=1; }
. "$DIR/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
. "$DIR/../lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
B_P1=0
B_R9=0

# ===== p3: THE GATE NEVER NAMES A PROBE RECORD (BL-880). ===================================
# scripts/validate-backlog-receipts.sh replays R1 and R7/R8 from a record only when its caller sets
# BR_PROBE_RECORD, so the gate's every run fires them only as long as nothing the gate runs sets it.
# The set is DERIVED here, never listed: both pre-push hooks, plus every script path either one
# names on a non-comment line (the consumer hook's scripts/ai-dlc/<x> is this tree's core/scripts/<x>).
# A derived file absent from this sandbox is FIXTURE BROKEN, so inputs.decl cannot fall behind the
# hooks. The count is of non-comment lines that SET the token (`T=`, `${T:=`, `export`/`declare`/
# `local` naming it); a read is not counted, because the validator in the set reads it. It must be 0.
# Controls, in the same arm: five seeded setting forms count 5, a seeded comment and a seeded read
# count 0; TMPDIR, which EACH hook sets, counts above 0 in each and over the set, and each hook names
# at least one script (so a derivation that skipped one hook cannot pass); the token's
# READ sites over the same set count above 0; and a hook copy with `BR_PROBE_RECORD=x` counts 1.
p3_count() { # p3_count <token> <file>... -> non-comment lines that SET the token
  # A setting site: `T=` or `${T:=` / `${T=` (the token closed on its left by a non-identifier char),
  # or `export|declare|local|readonly|typeset ... T`. A READ (`${T:-}`, `"$T/x"`) is not one: the
  # validator itself reads the variable and is a member of the set.
  awk -v t="$1" '
    /^[[:space:]]*#/ { next }
    { s = " " $0 " " }
    s ~ ("[^A-Za-z0-9_]" t ":?=") || s ~ ("(export|declare|local|readonly|typeset)[[:space:]]+([^;&|]*[[:space:]])?" t "([^A-Za-z0-9_]|$)") { n++ }
    END { print n + 0 }' "${@:2}"
}
p3_reads() { # p3_reads <token> <file>... -> non-comment lines carrying the token at all
  awk -v t="$1" '/^[[:space:]]*#/ { next } index($0, t) > 0 { n++ } END { print n + 0 }' "${@:2}"
}
# The tree root, from this file's own location (a .dist-only unit: the distribution layout only).
P3R="$(cd "$DIR/../../.." && pwd)"
p3_derive() { # p3_derive -> the hook files and every script they name, one per line
  local h p
  for h in .githooks/pre-push core/git-hooks/pre-push; do
    printf '%s\n' "$h"
    grep -v '^[[:space:]]*#' "$P3R/$h" | grep -oE '(core/)?scripts/(ai-dlc/)?[A-Za-z0-9_./-]+\.(sh|py)' | while read -r p; do
      case "$p" in scripts/ai-dlc/*) p="core/scripts/${p#scripts/ai-dlc/}" ;; esac
      printf '%s\n' "$p"
    done
  done | sort -u
}
p3_ok=1
for _h in .githooks/pre-push core/git-hooks/pre-push; do
  [ -f "$P3R/$_h" ] || { echo "FIXTURE BROKEN: p3 -- $_h is absent from this tree (declare it in inputs.decl)" >&2; exit 2; }
done
p3_set="$(p3_derive)"
p3_n="$(printf '%s\n' "$p3_set" | grep -c .)" || p3_n=0
[ "$p3_n" -gt 2 ] || { echo "FIXTURE BROKEN: p3 -- the derived set holds $p3_n file(s); the hooks named no script" >&2; exit 2; }
for _p in $p3_set; do
  [ -f "$P3R/$_p" ] || { echo "FIXTURE BROKEN: p3 -- $_p, which a pre-push hook runs, is absent from this sandbox; add it to inputs.decl" >&2; exit 2; }
done
echo "HERMETIC-CONSUMED .githooks/pre-push"
echo "HERMETIC-CONSUMED core/git-hooks/pre-push"
mkdir -p "$TMP/p3"
printf '#!/usr/bin/env bash\nexport BR_PROBE_RECORD=/x\n# BR_PROBE_RECORD=/y in a comment\n[ -n "${BR_PROBE_RECORD:-}" ] && cat "$BR_PROBE_RECORD/k"\n' > "$TMP/p3/probe.sh"
p3_probe="$(p3_count BR_PROBE_RECORD "$TMP/p3/probe.sh")"
p3_probe_r="$(p3_reads BR_PROBE_RECORD "$TMP/p3/probe.sh")"
for _f in 'BR_PROBE_RECORD=/a cmd' 'env X=1 BR_PROBE_RECORD="$d" bash v.sh' ': "${BR_PROBE_RECORD:=/d}"' 'export X BR_PROBE_RECORD' 'local BR_PROBE_RECORD'; do printf '%s\n' "$_f"; done > "$TMP/p3/forms.sh"
p3_forms="$(p3_count BR_PROBE_RECORD "$TMP/p3/forms.sh")"
cp "$P3R/.githooks/pre-push" "$TMP/p3/pre-push"; printf 'BR_PROBE_RECORD=x\n' >> "$TMP/p3/pre-push"
p3_seeded="$(p3_count BR_PROBE_RECORD "$TMP/p3/pre-push")"
# The hook must also DROP an inherited BR_PROBE_RECORD: a non-comment, top-level (column 0) `unset ... BR_PROBE_RECORD`
# line that sits BEFORE the first top-level `step "` or `pk_step ` call. p3_unset prints "<unset line> <first step line>"
# (0 when absent). Controls that must fail: the line removed, moved after the first step, and only inside a function body.
p3_unset() { awk '/^#/ { next } !u && /^unset[[:space:]]([^;&|]*[[:space:]])?BR_PROBE_RECORD([[:space:]]|$)/ { u = NR } !s && /^(step "|pk_step )/ { s = NR } END { print u + 0, s + 0 }' "$1"; }
p3_unset_ok() { set -- $1; [ "$1" -ge 1 ] && [ "$2" -ge 1 ] && [ "$1" -lt "$2" ]; }
grep -v '^unset BR_PROBE_RECORD$' "$P3R/.githooks/pre-push" > "$TMP/p3/pre-push.nounset"
{ grep -v '^unset BR_PROBE_RECORD$' "$P3R/.githooks/pre-push"; printf 'unset BR_PROBE_RECORD\n'; } > "$TMP/p3/pre-push.late"
awk '/^unset BR_PROBE_RECORD$/ { print "p3_fn() {"; print "  unset BR_PROBE_RECORD"; print "}"; next } { print }' "$P3R/.githooks/pre-push" > "$TMP/p3/pre-push.infn"
p3_un_real="$(p3_unset "$P3R/.githooks/pre-push")"
p3_un_seed="$(p3_unset "$TMP/p3/pre-push.nounset")"
p3_un_late="$(p3_unset "$TMP/p3/pre-push.late")"
p3_un_fn="$(p3_unset "$TMP/p3/pre-push.infn")"
# shellcheck disable=SC2086
p3_ctl="$(cd "$P3R" && p3_count TMPDIR $p3_set)"
# PER HOOK: each hook must SET the control token and name at least one script, or a derivation that
# never read one hook would pass. AI_DLC_PRESUITE_SKIP is set in the distribution hook only; TMPDIR in both.
p3_ph=""
for _h in .githooks/pre-push core/git-hooks/pre-push; do
  _c="$(p3_count TMPDIR "$P3R/$_h")"
  _m="$(grep -v '^[[:space:]]*#' "$P3R/$_h" | grep -oE '(core/)?scripts/(ai-dlc/)?[A-Za-z0-9_./-]+\.(sh|py)' | sort -u | grep -c .)" || _m=0
  { [ "${_c:-0}" -gt 0 ] && [ "${_m:-0}" -gt 0 ]; } || p3_ph="$p3_ph $_h(control=$_c scripts=$_m)"
done
# shellcheck disable=SC2086
p3_got="$(cd "$P3R" && p3_count BR_PROBE_RECORD $p3_set)"
# shellcheck disable=SC2086
p3_rd="$(cd "$P3R" && p3_reads BR_PROBE_RECORD $p3_set)"
if [ "$p3_probe" != 1 ] || [ "$p3_probe_r" != 2 ] || [ "$p3_forms" != 5 ] || [ "$p3_seeded" != 1 ] || [ "${p3_ctl:-0}" -le 0 ] || [ "${p3_rd:-0}" -le 0 ] || [ -n "$p3_ph" ]; then
  bad "p3 -- the counter cannot discriminate: seeded set+comment+read counted $p3_probe set (want 1) of $p3_probe_r carrying lines (want 2), five setting forms $p3_forms (want 5), seeded hook copy $p3_seeded (want 1), control TMPDIR set $p3_ctl (want > 0), token read sites in the set $p3_rd (want > 0), hooks short of a control or a script:${p3_ph:- none}"; p3_ok=0
elif ! p3_unset_ok "$p3_un_real" || p3_unset_ok "$p3_un_seed" || p3_unset_ok "$p3_un_late" || p3_unset_ok "$p3_un_fn"; then
  bad "p3 -- .githooks/pre-push has its column-0 BR_PROBE_RECORD unset at line/first-step-line [$p3_un_real] (want both >= 1 and unset < first step); seeded copies must fail: removed [$p3_un_seed], moved after the first step [$p3_un_late], only inside a function body [$p3_un_fn]; a caller's exported record would make the gate replay R1 and R7/R8"; p3_ok=0
elif [ "$p3_got" != 0 ]; then
  bad "p3 -- BR_PROBE_RECORD is carried on $p3_got non-comment line(s) of the pre-push hooks or a script they run; the gate would replay R1 and R7/R8 from a record"
else
  ok "p3 -- BR_PROBE_RECORD is set 0 times over the $p3_n files the two pre-push hooks run, which read it on $p3_rd line(s) (control TMPDIR set $p3_ctl, in each hook; a seeded hook copy counts 1; the hook unsets it at line/first-step-line [$p3_un_real]; copies without it [$p3_un_seed], moved late [$p3_un_late], in a function [$p3_un_fn] all fail)"
fi

# THE PROBE RECORD (BL-880): every receipts-validator run below shares this unit's own store, so its
# first green firing of R1 and R7/R8 is replayed by the later runs on the same bytes; a mutated copy
# has its own key and fires. The store lives and dies with $TMP.
export BR_PROBE_RECORD="$TMP/prstore"
mkdir -p "$BR_PROBE_RECORD"

# --- j1's seed: a throwaway REPOSITORY, because the receipts validator checks each receipt out of
# HEAD. It carries the validator, both reconcile files it loads, the classifier (R2's declared-empty
# exemption asks it), and the two probe files the self-probe and the anchor name.
seed_r() { # seed_r <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile" "$d/probe"
  echo "0.0.0" > "$d/VERSION"
  cp "$RECEIPTS" "$d/scripts/validate-backlog-receipts.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVSRC" "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
  cp "$REVERIFY" "$d/scripts/backlog-reverify.sh"
  # The receipts validator reads its F-STEP vocabulary from the extractor and the step basenames.
  mkdir -p "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts" "$d/core/skills/ai-dlc/steps"
  cp "$EXTRACT" "$d/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
  : > "$d/core/skills/ai-dlc/steps/implementation.md"
  cp "$RLIB" "$d/scripts/backlog-receipt-lib.sh"
  printf 'alpha\nbeta\n' > "$d/probe/subject.txt"
  printf 'delta\n' > "$d/probe/guarded.txt"
  printf '# Probe backlog\n' > "$d/docs/backlog.md"
  (
    cd "$d" && git init -q . >/dev/null 2>&1 \
      && git add -A >/dev/null 2>&1 \
      && git -c user.email=p@local -c user.name=p commit -q -m seed >/dev/null 2>&1
  )
  [ -d "$d/.git" ] || { echo "FIXTURE BROKEN: the probe repository at $d has no .git" >&2; exit 2; }
}
# shellcheck disable=SC2086
run_r() { # run_r <env-string-or-empty> <dir> [<extra-args>...]
  local e="$1" d="$2"; shift 2
  ( cd "$d" && env $e bash scripts/validate-backlog-receipts.sh "$@" 2>&1 )
}

# --- b16's seed: a plain tree with the ceiling validator, its library and the classifier.
seed_s() { # seed_s <dir>
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/core/skills/ai-dlc-update/reconcile"
  echo "0.0.0" > "$d/VERSION"
  cp "$SIZE" "$d/scripts/validate-backlog-size.sh"
  cp "$LIBSRC" "$d/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$REVERIFY" "$d/scripts/backlog-reverify.sh"
  cp "$RLIB" "$d/scripts/backlog-receipt-lib.sh"
}
# shellcheck disable=SC2086
run_s() { # run_s <env-string-or-empty> <dir> [<extra-args>...]
  local e="$1" d="$2"; shift 2
  ( cd "$d" && env $e bash scripts/validate-backlog-size.sh "$@" 2>&1 )
}
# Reads the count back out of the ceiling's OWN ok line; empty when the arm did not speak.
bl_reported() { printf '%s\n' "$1" | sed -n 's|^OK: validate-backlog-size -- B1 \([0-9][0-9]*\)/[0-9]* entries in .*|\1|p'; }

# ===== j1: THE POPULATION JOIN. ===========================================================
# Bind the receipts validator's `sh` population to the SHIPPING classifier's view of the same
# ledger, at fixture time rather than on the gate's hot path. NO NUMBER IS HARDCODED: a literal
# would go stale on the next filed entry, and equality alone is satisfied by two broken
# predicates that both return 0, so both sides are asserted non-zero as well.
# R2 REFUSES BEFORE THE SUMMARY when this tree can score none of the real ledger's receipts, and
# that is a property of THIS tree, not of the ledger: it carries only the validator, lib.sh and
# ledger-reverify.sh, so most real receipts exit 9 or 0 here, and a correct fix closing the last
# one it could bind empties the scored set. Reading the population out of R2's refusal instead
# kept j1 green there, and cost j1 its second job: a validator that scored NOTHING read the same.
# So the j1 ledger carries one ANCHOR receipt, appended LAST and keyed on a seed file every
# seed tree holds, which this tree always scores (a literal grep: PROSE-CLOSABLE). The SUMMARY
# is then always printed, the population is read from it alone, and `scored=` must be non-zero.
# The anchor is one more sh receipt on BOTH sides of the join, so the comparison is unmoved.
J1_ANCHOR='BL-899'
J1_ARGS="--max-prose-closable 9999 --max-unscorable 9999 --max-out-of-population 9999 --max-unanchored 9999 --min-sh-receipts 0 --min-entries 0"
j1_read() { # j1_read <validator output> -> "<sh-receipts> <scored>", or nothing without a SUMMARY
  printf '%s\n' "$1" | sed -n 's/^SUMMARY .*sh-receipts=\([0-9][0-9]*\) scored=\([0-9][0-9]*\) .*/\1 \2/p'
}
# SELF-PROBE, BOTH DIRECTIONS, before the real ledger: a zero-scored ledger (one exit-9 receipt)
# must yield NO reading, and the same ledger plus the anchor must yield one with scored >= 1.
seed_r "$TMP/j1p"
printf '# Probe backlog\n\n## BL-803\n\nverify: sh grep -q %s probe/guarded.txt || exit 9\n\n' "'MARK803'" \
  > "$TMP/j1p/docs/backlog.md"
( cd "$TMP/j1p" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m zero >/dev/null 2>&1 )
# shellcheck disable=SC2086
j1p_zero_out="$(run_r "" "$TMP/j1p" $J1_ARGS)"
run_r_first_out() { printf '%s\n' "$j1p_zero_out"; }
j1p_zero="$(j1_read "$j1p_zero_out")"
printf '## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1p/docs/backlog.md"
( cd "$TMP/j1p" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m anchor >/dev/null 2>&1 )
# shellcheck disable=SC2086
j1p_anch_out="$(run_r "" "$TMP/j1p" $J1_ARGS)"
j1p_anch="$(j1_read "$j1p_anch_out")"
if [ -z "$j1p_zero" ] && [ "${j1p_anch#* }" = 1 ]; then
  note "ok    j1 probe -- a zero-scored ledger yields no SUMMARY reading, and the same ledger plus the anchor yields scored=1"
else
  note "FAIL  j1 probe -- zero-scored reading '$j1p_zero' (want none), anchored reading '$j1p_anch' (want '<n> 1'); the j1 reader or its anchor cannot discriminate, so j1 below proves nothing"; rc=1
fi
seed_r "$TMP/j1"
cp "$REAL_LEDGER" "$TMP/j1/docs/backlog.md"
# THIS WORLD ALONE CARRIES THE CEILING, SO THE VALIDATOR'S OWN LIVE-LEDGER ARM R9 RUNS IN IT (BL-872).
# j1p above has none, so its anchored run must say `R9: NOT RUN`; this one must say `R9: OK` with the
# same counts this fixture derives independently below. Both are asserted after b16.
cp "$SIZE" "$TMP/j1/scripts/validate-backlog-size.sh"
# The anchor must be an id the real ledger does not carry, or it is a second entry under one id.
# Real entries are titled (`## BL-NNN — ...`), so the id is closed by a non-digit or line end.
# A real ledger DECLARED EMPTY carries no `## BL-` entry by construction, so that half of the
# precondition binds only when the classifier says the ledger is not declared empty; the anchor
# then supplies the arm's whole population and the join below still runs.
( cd "$TMP/j1" && bash scripts/backlog-reverify.sh --declared-empty docs/backlog.md >/dev/null 2>&1 ); j1_de=$?
if [ "$j1_de" -ne 0 ] && [ "$j1_de" -ne 1 ]; then
  note "FAIL  j1 -- backlog-reverify.sh --declared-empty exited $j1_de on the real ledger, an environment failure"; rc=1
fi
if grep -qE "^## ${J1_ANCHOR}([^0-9]|\$)" "$TMP/j1/docs/backlog.md" \
   || { [ "$j1_de" -ne 0 ] && ! grep -q '^## BL-' "$TMP/j1/docs/backlog.md"; }; then
  note "FAIL  j1 -- the real ledger already carries ${J1_ANCHOR}, or carries no '## BL-' entry at all while not declared empty; the anchor cannot be told apart"; rc=1
fi
printf '\n## %s\n\nverify: sh grep -q %s probe/subject.txt\n\n' "$J1_ANCHOR" "'MARKJ1ANCHOR'" >> "$TMP/j1/docs/backlog.md"
( cd "$TMP/j1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m real >/dev/null 2>&1 )
# shellcheck disable=SC2086
j1_out="$(run_r "" "$TMP/j1" $J1_ARGS)"
j1_rd="$(j1_read "$j1_out")"
# The store is wired: j1p's first run wrote the record, and j1, on the same validator bytes, replayed it.
if grep -q '^PROBE-RECORD: WRITTEN (K=' <<<"$(run_r_first_out)" && grep -q '^PROBE-RECORD: REPLAYED (K=' <<<"$j1_out"; then
  ok "pr -- the probe record is wired: j1p's first run fired and wrote it, and j1 replayed it"
else
  bad "pr -- the probe record did not replay: j1p first '$(run_r_first_out | grep '^PROBE-RECORD' | cut -c1-80)', j1 '$(grep '^PROBE-RECORD' <<<"$j1_out" | cut -c1-80)'"
fi
j1_arm="${j1_rd%% *}"; j1_sc="${j1_rd#* }"
if [ -z "$j1_rd" ] || [ "$j1_sc" -eq 0 ]; then
  note "FAIL  j1 -- the validator printed no SUMMARY or scored nothing on the real ledger plus a receipt it always scores (reading '$j1_rd'); nothing was observed"; rc=1
  j1_arm=""
fi
# Reverify's own view: one row per entry, id in field 2, restricted to the rows whose verb it
# resolved as `sh` -- which are exactly the ones it reports STILL-LIVE or CLOSE-CANDIDATE from an
# sh receipt. Counting its distinct ids for those statuses is its population.
#
# THE CLASSIFIER RUNS ONCE OVER THE REAL LEDGER FOR BOTH ARMS. It evaluates every receipt in the
# ledger, which is the cost of this unit, and b16 below asks it for the same ledger minus the anchor.
# Its rows are held here and b16 subtracts the anchor's row, a rule that is asserted to have removed
# exactly one row so the subtraction cannot decay into a no-op.
j1_rows="$( cd "$TMP/j1" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null )"
j1_rev="$(printf '%s\n' "$j1_rows" | awk -F'\t' '$3 ~ /^sh receipt exited/ { print $2 }' | sort -u | grep -c . )"
if [ -z "$j1_arm" ] || [ -z "$j1_rev" ]; then
  note "FAIL  j1 -- a side produced no value (arm='$j1_arm' reverify='$j1_rev')"; rc=1
elif [ "$j1_arm" -eq 0 ] || [ "$j1_rev" -eq 0 ]; then
  note "FAIL  j1 -- a side counted ZERO (arm=$j1_arm reverify=$j1_rev); two predicates that both find nothing agree perfectly and prove nothing"; rc=1
elif [ "$j1_arm" -lt "$j1_rev" ]; then
  note "FAIL  j1 -- the arm sees $j1_arm sh receipts and backlog-reverify.sh resolves $j1_rev. The arm's population is SMALLER than the classifier's, so receipts exist that it never scores."; rc=1
else
  note "ok    j1 -- on the real ledger the arm's sh population ($j1_arm) covers the classifier's resolved set ($j1_rev)"
fi

# ===== b16: THE CEILING JOIN ON THE REAL LEDGER. ============================================
# The same join core/fixtures/backlog-size-ceiling/ b15 makes on a seeded ledger, against the
# REAL one, which is the one that catches a drift filed after that fixture was written.
# WHEN THE REAL LEDGER IS DECLARED EMPTY the count join has no population, so the two sides are
# asked the declared state instead: the ceiling must report 0 with its declared-empty OK line,
# and the classifier must emit exactly one DECLARED-EMPTY row. Which branch runs is decided by the
# classifier's own --declared-empty on the real file, and each branch is presence-shaped.
seed_s "$TMP/b16"; cp "$REAL_LEDGER" "$TMP/b16/docs/backlog.md"
b16_out="$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/b16")"
b16_arm="$(bl_reported "$b16_out")"
# The declared-empty answer for the real ledger was taken above on j1's byte-identical copy of it
# (before the anchor was appended), so it is not asked again. A declared-empty ledger has no
# receipts to evaluate, so only that branch asks the classifier for its own rows; otherwise the rows
# are j1's with the anchor's single row removed.
b16_de="$j1_de"
if [ "$b16_de" -eq 0 ]; then
  b16_rows="$( cd "$TMP/b16" && bash scripts/backlog-reverify.sh docs/backlog.md 2>/dev/null )"
else
  b16_rows="$(printf '%s\n' "$j1_rows" | awk -F'\t' -v a="$J1_ANCHOR" '$2 != a')"
  b16_gone=$(( $(printf '%s\n' "$j1_rows" | grep -c .) - $(printf '%s\n' "$b16_rows" | grep -c .) ))
  [ "$b16_gone" -eq 1 ] || { note "FAIL  b16 -- removing the anchor's row from the classifier's rows removed $b16_gone rows, want exactly 1"; rc=1; }
fi
b16_rev="$(printf '%s\n' "$b16_rows" | cut -f2 | sort -u | grep -c . )"
if [ "$b16_de" -eq 0 ]; then
  b16_nrow="$(printf '%s\n' "$b16_rows" | grep -c .)" || b16_nrow=0
  if [ "$b16_arm" = 0 ] && grep -qF ', declared empty (' <<<"$b16_out" \
     && [ "$b16_nrow" -eq 1 ] && [ "$(printf '%s\n' "$b16_rows" | cut -f1)" = DECLARED-EMPTY ]; then
    note "ok    b16 -- the real ledger is declared empty, and the ceiling (0, declared empty) and the classifier (one DECLARED-EMPTY row) both say so"
  else
    note "FAIL  b16 -- the real ledger is declared empty but the sides disagree (arm='$b16_arm', classifier rows=$b16_nrow first='$(printf '%s\n' "$b16_rows" | sed -n '1p' | cut -f1)')"; rc=1
  fi
elif [ "$b16_de" -ne 1 ]; then
  note "FAIL  b16 -- backlog-reverify.sh --declared-empty exited $b16_de on the real ledger, an environment failure"; rc=1
elif [ -z "$b16_arm" ] || [ -z "$b16_rev" ] || [ "$b16_arm" -eq 0 ] || [ "$b16_rev" -eq 0 ]; then
  note "FAIL  b16 -- a side produced no usable value (arm='$b16_arm' reverify='$b16_rev')"; rc=1
elif [ "$b16_arm" -ne "$b16_rev" ]; then
  note "FAIL  b16 -- on the REAL ledger the ceiling counts $b16_arm and backlog-reverify.sh classifies $b16_rev"; rc=1
else
  note "ok    b16 -- on the real ledger the ceiling and the classifier agree at $b16_arm entries"
fi

# ===== r9: THE VALIDATOR'S OWN LIVE-LEDGER ARM, BOTH DIRECTIONS (BL-872). ===================
# R9 of the receipts validator is where j1 and b16 run against the LIVE ledger now. Its OK line must
# carry the counts this fixture derived on its own above for the same world (the snapshot plus the
# anchor, so the ceiling reads b16 + 1), and the world with no size validator must say NOT RUN.
# Presence-shaped both ways: a validator with the arm deleted prints neither line.
if [ "$b16_de" -eq 1 ] && [ -n "$b16_arm" ] && [ -n "$j1_arm" ]; then
  r9_want="j1 the sh population $j1_arm covers the classifier's resolved set "
  r9_want2="b16 the ceiling and the classifier agree at $(( b16_arm + 1 )) entries"
  r9_line="$(printf '%s\n' "$j1_out" | grep '^R9: ')" || r9_line=""
  if grep -qF "$r9_want" <<<"$r9_line" && grep -qF "$r9_want2" <<<"$r9_line" && grep -q '^R9: OK -- ' <<<"$r9_line"; then
    ok "r9 -- the validator's live-ledger arm R9 ran in the world carrying the ceiling and agrees with this fixture ($j1_arm sh, $(( b16_arm + 1 )) entries)"; B_R9=1
  else
    bad "r9 -- the validator's R9 line in the world carrying the ceiling is '${r9_line}', want R9: OK carrying '${r9_want}' and '${r9_want2}'"
  fi
  if grep -q '^R9: NOT RUN -- scripts/validate-backlog-size.sh is absent' <<<"$j1p_anch_out"; then
    ok "r9 -- the world with no size validator says R9: NOT RUN rather than a clean result"
  else
    bad "r9 -- the world with no size validator did not print R9: NOT RUN (got '$(printf '%s\n' "$j1p_anch_out" | grep '^R9' )')"
  fi
  # m-r9call: the CALL SITE of R9 neutered (`r9_run; _r9_rc=$?` -> `_r9_rc=0`), in a copy of the j1 world
  # that carries the ceiling. The call line is the only place R9 runs, so the mutated validator prints no
  # `R9:` line at all; the r9 OK arm above is presence-shaped and is what decides. Twin j1-pop: the same
  # mutated tree still prints a SUMMARY whose sh population equals the unmutated world's.
  cp -R "$TMP/j1" "$TMP/r9m"
  r9m_v="$TMP/r9m/scripts/validate-backlog-receipts.sh"
  sed 's/^r9_run; _r9_rc=\$?$/_r9_rc=0/' "$RECEIPTS" > "$r9m_v"
  if cmp -s "$RECEIPTS" "$r9m_v"; then
    note "FAIL  r9 m-r9call -- the call-site mutation DID NOT APPLY"; rc=1
  else
    r9m_out="$(run_r "" "$TMP/r9m" $J1_ARGS)"
    r9m_sum="$(j1_read "$r9m_out")"
    if ! grep -q '^R9: ' <<<"$r9m_out"; then
      mutant_killed "$B_R9" m-r9call "m-r9call [r9-call]: with the R9 call site neutered the validator prints no R9 line at all"
    else
      bad "r9 m-r9call SURVIVED: the validator with its R9 call replaced still printed '$(printf '%s\n' "$r9m_out" | grep '^R9: ')'"
    fi
    if [ -n "$r9m_sum" ] && [ "${r9m_sum%% *}" = "$j1_arm" ]; then
      ok "[j1-pop] twin of m-r9call stays green: the mutated validator still reads the sh population $j1_arm"
    else
      bad "[j1-pop] the twin TRIPPED: the mutated validator read '${r9m_sum}', want population $j1_arm"
    fi
    if [ "$MATRIX" = 1 ]; then
      r9_t=GREEN; r9_k=no; grep -q '^R9: ' <<<"$r9m_out" || { r9_t=TRIPPED; r9_k=yes; }
      j1p_t=GREEN; j1p_k=no; [ -n "$r9m_sum" ] && [ "${r9m_sum%% *}" = "$j1_arm" ] || { j1p_t=TRIPPED; j1p_k=yes; }
      matrix_row m-r9call r9-call 0 "$r9_t" "$r9_k"
      matrix_row m-r9call j1-pop 0 "$j1p_t" "$j1p_k"
      MROWS=$(( MROWS + 2 ))
    fi
  fi
fi

# ===== p1: A PROSE LEAD-IN BULLET ON THE REAL LEDGER (BL-820). ==============================
# The real ledger plus one host entry that carries `- **BL-632 is LANDED** prose` before its
# receipt must count exactly ONE more than the real ledger alone -- the host, never the phantom.
# The ceiling is the cheap reader; the label rule is lib.sh's, shared by every BL- reader.
# Declared empty, the real ledger counts 0 and the marker is no longer last once the host is
# appended, so that branch is not a count comparison and is skipped by name.
# m-loose (the strict bullet test deleted from the seed's lib.sh) must read +2.
p1_seed() { # p1_seed <dir>
  seed_s "$1"; cp "$REAL_LEDGER" "$1/docs/backlog.md"
  printf '\n## BL-898 — host\n\nBody.\n\n- **BL-632 is LANDED** prose about another entry\n\nverify: manual\n' >> "$1/docs/backlog.md"
}
if [ "$b16_de" -eq 1 ] && [ -n "$b16_arm" ] && [ "$b16_arm" -gt 0 ]; then
  p1_seed "$TMP/p1"
  p1_arm="$(bl_reported "$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/p1")")"
  if [ "$p1_arm" = "$(( b16_arm + 1 ))" ]; then
    note "ok    p1 -- a host carrying a '- **BL-632 is LANDED**' lead-in adds exactly one entry to the real ledger ($b16_arm -> $p1_arm)"; B_P1=1
  else
    note "FAIL  p1 -- the real ledger counts $b16_arm and with one host appended counts '${p1_arm}', want $(( b16_arm + 1 ))"; rc=1
  fi
  p1_seed "$TMP/p1m"
  p1m_lib="$TMP/p1m/core/skills/ai-dlc-update/reconcile/lib.sh"
  sed '/if (line !~ \/^BL-/d' "$LIBSRC" > "$p1m_lib"
  if cmp -s "$LIBSRC" "$p1m_lib"; then
    note "FAIL  p1 m-loose -- the label mutation DID NOT APPLY"; rc=1
  else
    p1m_arm="$(bl_reported "$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/p1m")")"
    # The twin: the SAME mutated tree reading the real ledger alone (no host appended).
    seed_s "$TMP/p1mt"; cp "$REAL_LEDGER" "$TMP/p1mt/docs/backlog.md"; cp "$p1m_lib" "$TMP/p1mt/core/skills/ai-dlc-update/reconcile/lib.sh"
    p1mt_arm="$(bl_reported "$(run_s "AI_DLC_BACKLOG_MAX_ENTRIES=100000" "$TMP/p1mt")")"
    if [ "$p1m_arm" = "$(( b16_arm + 2 ))" ]; then
      mutant_killed "$B_P1" m-loose "m-loose [p1-count]: with the loose label rule the lead-in counts too ($b16_arm -> $p1m_arm)"
    else
      bad "p1 m-loose SURVIVED: the loose rule read '${p1m_arm}', want $(( b16_arm + 2 ))"
    fi
    if [ "$p1mt_arm" = "$b16_arm" ]; then
      ok "[b16-count] twin of m-loose stays green: the mutated tree reads the real ledger alone at $p1mt_arm, equal to the unmutated $b16_arm"
    else
      bad "[b16-count] the twin TRIPPED: the mutated tree reads the real ledger at '${p1mt_arm}', the unmutated tree at $b16_arm"
    fi
    if [ "$MATRIX" = 1 ]; then
      p1_t=GREEN; p1_k=no; [ "$p1m_arm" != "$(( b16_arm + 1 ))" ] && { p1_t=TRIPPED; p1_k=yes; }
      b16_t=GREEN; b16_k=no; [ "$p1mt_arm" != "$b16_arm" ] && { b16_t=TRIPPED; b16_k=yes; }
      matrix_row m-loose p1-count 0 "$p1_t" "$p1_k"
      matrix_row m-loose b16-count 0 "$b16_t" "$b16_k"
      MROWS=$(( MROWS + 2 ))
    fi
  fi
elif [ "$b16_de" -eq 0 ]; then
  note "SKIP  p1 -- the real ledger is declared empty, so there is no count to compare"
else
  note "FAIL  p1 -- no usable real-ledger count from b16 (arm='$b16_arm' declared-empty rc=$b16_de)"; rc=1
fi

if [ "$MATRIX" = 0 ]; then
  if [ "$MROWS" -eq 0 ]; then ok "[MX] a plain run executed no matrix-only cell (rows=0)"; else bad "[MX] a plain run executed $MROWS matrix rows"; fi
elif [ "$MROWS" -eq 4 ]; then ok "[MX] the matrix run measured 4 cells for the 2 mutants"
else bad "[MX] matrix rows=$MROWS, 4 expected"; fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-real-ledger -- j1 and b16 hold on the frozen ledger snapshot"
fi
exit "$rc"
