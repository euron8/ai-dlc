#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# emit-report-refusal/run.sh — a sample or detector that did not run renders DETECTOR-REFUSED in
# the reconcile report, never `none`; and the reconcile-emit-report fixture's R6 guard retries a
# world built or scored under such a refusal instead of reading it as a verdict.
#
# THE DEFECT (BL-230). emit-report.sh's orientation block read no status at all: `diff` exit 2
# was swallowed with exit 1, the grep|sed|grep sample chain and its `grep -c` swallowed their own
# failures, and a failed `git show` rendered `THEIRS absent`. Seven sibling detector sites read
# their rows through a pipeline and rendered `none` whatever the detector's exit was. A batch-160
# pool put reconcile-emit-report's E3 on V-N at `3|BLOCKERS-RESOLVED|1|1|4|4`: an approval
# rendered while the orientation diff failed recorded a sample that never ran as an empty one.
# The TRIGGER, measured afterwards: `diff <(…) file` under four concurrent bash workers fails
# with `/dev/fd/63: Bad file descriptor`, rc 2 — between 0 and 9 of each 10000 calls across
# repeated runs, load-dependent — where the same comparison through a temp file failed 0 of
# 40000. A7 forces that interleaving rather than sampling it.
#
# WHY A SEPARATE UNIT. reconcile-emit-report is the suite's heaviest reconcile unit; these arms
# re-render the seed world roughly fifty times across the mutant programs, and added there they
# would move a pole-adjacent directory. The seed is SHARED, not copied: this unit runs the
# sibling's own `seed.sh`, so both units read one world, and the R6 battery below extracts the
# guard helpers from the sibling's own `run.sh` and drives them, so it binds the shipping text.
#
# ARMS (each runs against every program in its group; the ctl copy must pass all of them):
#   A0  CONTROL: an unmutated copy of reconcile/ renders the seed world byte-identically to the
#       seed's own region, with positive rows in every section the stub arms later refuse.
#   A1  per site (retired-tokens, relabel, ledger-reverify, predicate-differential,
#       retired-fixtures, retired-layer-contract, retired-layer-passage): a stub exiting
#       non-zero renders exactly ONE column-0 `DETECTOR-REFUSED  <name> exited <rc>` in place of
#       the section, and the render still exits 0 with the unstubbed sections intact.
#   A2  relabel exiting 1 is its FINDING: its row renders, and no refusal does.
#   A3  per-FILE: the orientation diff failing on the SECOND of two CLASSIFY files refuses that
#       file only; the first keeps its complete sample and no `ONLY IN …: none` renders.
#   A4a the sample awk exiting non-zero refuses that side; A4b a non-numeric count refuses too.
#   A5  absence is decided by ls-tree: a failed ls-tree and a failed show each render a refusal,
#       while a path truly absent at theirs renders `THEIRS absent`.
#   A6  R1's shape: approve healthy, resolve the HARD drift, verify under a diff shim -> rc 1,
#       UNDECIDED, one DETECTOR-REFUSED line (an indented refusal reads rc 3 BLOCKERS-RESOLVED).
#   A7  the race itself, FORCED on the engine's own orientation-diff text (a delayed `diff`),
#       against two reference spellings that must split 5/5 and 0/5 first.
#   R6  the reconcile-emit-report guard: approve-side and score-side retry, baseline derivation,
#       and the stub exemption, each with a mutant.
#
# MUTANTS. Each is a copy of the whole reconcile/ directory with ONE edit (or, for the R6 guard, a copy of
# the guard helpers cut from reconcile-emit-report/run.sh). A UNIT is one render or scenario of one program,
# run as a background job that writes only under its own directory; nothing is asserted in a job.
#   - PER PUSH the unmutated copy runs EVERY unit (the base pass), and each mutant runs the units of its
#     DECIDING arm, which must FAIL, and of one named TWIN, an arm the measured matrix shows GREEN for it,
#     which must PASS. The kill is emitted through mutant_killed behind the same-run base pass of both arms
#     and of the whole unmutated copy. The twin proves the kill stays confined to the deciding arm.
#   - `--matrix` runs every unit of every program and prints one MATRIX row per (program, arm) cell,
#     `killed=yes` iff THAT arm tripped under THAT program. An arm whose subject a program does not touch
#     (an R6 arm under an emit-report.sh mutant, an emit-report arm under an R6 variant) reads the control's
#     verdict, which is the verdict the shipping subject earns; it is reused, not re-run.
# The matrix is re-measured whenever an arm or a mutant is added or changed, from the repo root, by the
# command on the MUTANT-MATRIX-REMEASURE line, with AI_DLC_VERDICT_STORE set to a fresh mktemp dir. It is
# not run through hermetic-run.sh, which forwards no argument.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/emit-report-refusal/run.sh --matrix
# MUTANT-MATRIX-CONTROL MX0 why=the unmutated copy of the reconcile engine must trip no arm; it is the base pass every kill is gated on
# MUTANT-MATRIX m-diff-rc decides=A3 twins=A4a
# MUTANT-MATRIX m-diff-indent decides=A6 twins=A3
# MUTANT-MATRIX m-samp-rc decides=A4a twins=A3
# MUTANT-MATRIX m-samp-nonnum decides=A4b twins=A3
# MUTANT-MATRIX m-lstree decides=A5 twins=A3
# MUTANT-MATRIX m-rt decides=A1-retired-tokens.sh twins=A2
# MUTANT-MATRIX m-rl-refuse decides=A1-relabel-extension-checks.sh twins=A2
# MUTANT-MATRIX m-rl-one decides=A2 twins=A1-ledger-reverify.sh
# MUTANT-MATRIX m-lr decides=A1-ledger-reverify.sh twins=A2
# MUTANT-MATRIX m-pd decides=A1-predicate-differential.sh twins=A2
# MUTANT-MATRIX m-rf decides=A1-retired-fixtures.sh twins=A2
# MUTANT-MATRIX m-rlc decides=A1-retired-layer-contract.sh twins=A2
# MUTANT-MATRIX m-rlp decides=A1-retired-layer-passage.sh twins=A2
# MUTANT-MATRIX h1-unstable decides=H1 twins=A8
# MUTANT-MATRIX a8-stable-filter decides=A8 twins=A9
# MUTANT-MATRIX a9-counts-in-projection decides=A9 twins=H1
# MUTANT-MATRIX r6-approve-noretry decides=R6APPR twins=R6SCORE
# MUTANT-MATRIX r6-approve-noguard decides=R6APPR twins=R6SCORE
# MUTANT-MATRIX r6-baseline-empty decides=R6APPR twins=R6SCORE
# MUTANT-MATRIX r6-score-noretry decides=R6SCORE twins=R6APPR
# MUTANT-MATRIX r6-score-noguard decides=R6SCORE twins=R6APPR
# MUTANT-MATRIX r6-score-nostub decides=R6STUB twins=R6APPR
set -uo pipefail
MATRIX=0; MATRIX_ROWS=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (usage: run.sh [--matrix])" >&2; exit 2 ;;
  esac
done

# HERMETIC -- scrub the operator's tuning before reading anything (I10). H1 below drives a world
# carrying an ai-dlc hook through the hook-registration validator.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SIB="$HERE/../reconcile-emit-report"
[ -f "$SIB/seed.sh" ] && [ -f "$SIB/run.sh" ] \
  || { echo "FIXTURE ERROR: sibling reconcile-emit-report/ (seed.sh, run.sh) not found beside this unit" >&2; exit 2; }
WORK="$(bash "$SIB/seed.sh")" || { echo "FIXTURE ERROR: the sibling seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
RDIR="$(dirname "$EMIT")"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/emit-report.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
echo "emit-report-refusal:"
for _l in matrix.sh mutant.sh; do
  [ -f "$HERE/../lib/$_l" ] || { echo "FIXTURE ERROR: $HERE/../lib/$_l is absent; nothing was asserted" >&2; exit 2; }
  . "$HERE/../lib/$_l"
done
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

R="$WORK/err"; mkdir -p "$R/sh" "$R/prog" "$R/out"
REAL_DIFF="$(command -v diff)"; REAL_AWK="$(command -v awk)"; REAL_GIT="$(command -v git)"
[ -n "$REAL_DIFF" ] && [ -n "$REAL_AWK" ] && [ -n "$REAL_GIT" ] \
  || { echo "FIXTURE ERROR: diff/awk/git not on PATH" >&2; exit 2; }
CL='core/skills/ai-dlc/templates/classes.md'
ZE='core/skills/ai-dlc/templates/zeta.md'

# --- SHIMS --------------------------------------------------------------------------------
# Each fails ONE call shape and execs the real binary for every other. Keyed on TWO arguments
# with the SECOND the consumer file, so the diff shims fire whatever the first operand is: a
# `/dev/fd/*` process substitution until 0.647.0, `-` (the staged side piped in) since. EVERY
# FIRING APPENDS A LINE TO "$SHIM_FIRED", and every forced-failure arm below refuses as FIXTURE
# BROKEN when that file is empty: a shim that silently stopped matching the engine's call shape
# would otherwise read exactly like an engine that stopped refusing -- or, under a mutant, like a
# kill.
shim() { # shim <dir> <binary-name> <body-lines...>
  local d="$R/sh/$1" b="$2"; shift 2
  mkdir -p "$d"; printf '%s\n' '#!/bin/bash' "$@" > "$d/$b"; chmod +x "$d/$b"
}
FIRE='echo "$0 $*" >> "${SHIM_FIRED:-/dev/null}"'
shim diff-zeta    diff "case \"\$#:\${2:-}\" in 2:*templates/zeta.md) $FIRE; exit 2 ;; esac"    "exec '$REAL_DIFF' \"\$@\""
shim diff-classes diff "case \"\$#:\${2:-}\" in 2:*templates/classes.md) $FIRE; exit 2 ;; esac" "exec '$REAL_DIFF' \"\$@\""
shim awk-fail     awk "if [ \"\${1:-}\" = -v ] && [ \"\${2:-}\" = 'm=<' ]; then $FIRE; exit 2; fi"          "exec '$REAL_AWK' \"\$@\""
shim awk-nonnum   awk "if [ \"\${1:-}\" = -v ] && [ \"\${2:-}\" = 'm=<' ]; then $FIRE; echo x; exit 0; fi" "exec '$REAL_AWK' \"\$@\""
# Keyed on the ORIENTATION read's shape (`ls-tree <ref> -- <path>`), never on lib.sh's absence
# discriminator (`ls-tree -z --full-tree`), which preclassify also asks about classes.md at base: a
# forced failure there makes that absence unconfirmable and preclassify refuses first, correctly,
# so the orientation read this arm is about is never reached.
shim git-split    git 'case " $* " in' \
  "  *' --full-tree '*) exec '$REAL_GIT' \"\$@\" ;;" \
  "  *' ls-tree '*' -- $CL '*) $FIRE; exit 128 ;;" \
  "  *' show '*':$ZE '*) $FIRE; exit 128 ;;" 'esac' "exec '$REAL_GIT' \"\$@\""
# ONE-SHOT: fails the first classes.md diff after its latch is cleared, then passes. `mkdir` is
# the latch because it is atomic; the latch directory's existence afterwards proves it FIRED.
shim diff-once diff "case \"\$#:\${2:-}\" in 2:*templates/classes.md) mkdir \"\$ONESHOT\" 2>/dev/null && exit 2 ;; esac" \
  "exec '$REAL_DIFF' \"\$@\""

# --- WORLDS -------------------------------------------------------------------------------
# W0 is the sibling's seed as it stands. T2 adds a SECOND both-added CLASSIFY file (zeta, sorted
# AFTER classes, so the refused file is the non-first) and deletes thing.json upstream, so one
# render carries a path truly absent at theirs beside two present ones.
C2="$R/c2"; cp -R "$CONSUMER" "$C2"
printf 'shared line\nSENTINEL-ZETA-OURS consumer\n' > "$C2/.claude/skills/ai-dlc/templates/zeta.md"
printf 'shared line\nSENTINEL-ZETA-THEIRS upstream\n' > "$DIST/$ZE"
TG() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }
_head0="$(git -C "$DIST" rev-parse HEAD 2>/dev/null)"
TG checkout -q -b fixture-refusal-t2 "$THEIRS" && TG rm -q core/schemas/thing.json && TG add -A \
  && TG commit -q -m t2-second-classify-and-upstream-delete
T2="$(git -C "$DIST" rev-parse HEAD 2>/dev/null)"
TG checkout -q "$_head0"
rm -f "$DIST/$ZE"
if [ -z "$T2" ] || [ "$T2" = "$THEIRS" ] || [ "$(git -C "$DIST" rev-parse HEAD 2>/dev/null)" != "$_head0" ] \
   || [ -z "$(git -C "$DIST" ls-tree "$T2" -- "$ZE" 2>/dev/null)" ] \
   || [ -n "$(git -C "$DIST" ls-tree "$T2" -- core/schemas/thing.json 2>/dev/null)" ]; then
  echo "FIXTURE ERROR: world T2 was not built (T2=${T2:-<none>}; zeta must be present and thing.json absent at it, HEAD restored)" >&2
  exit 2
fi

# A6's approval, rendered ONCE by the shipped engine at the copy's own path (the region embeds
# the consumer path), then the HARD drift is resolved with base's own bytes.
C3="$R/c3"; cp -R "$CONSUMER" "$C3"
_a=0
until [ "$_a" -ge 3 ]; do
  _a=$((_a+1))
  bash "$EMIT" "$DIST" "$BASE" "$C3" "$THEIRS" > "$R/a6-region.md" 2>/dev/null
  cmp -s <(grep '^DETECTOR-REFUSED' "$R/a6-region.md") <(grep '^DETECTOR-REFUSED' "$REGION") && break
done
{ echo "# Reconcile report (fixture)"; echo; cat "$R/a6-region.md"; } > "$R/a6-approved.md"
git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$C3/.claude/schemas/thing.json" 2>/dev/null
grep -q 'HARD-UNREGISTERED-CORE-DRIFT' "$R/a6-region.md" && ! cmp -s "$C3/.claude/schemas/thing.json" "$CONSUMER/.claude/schemas/thing.json" \
  || { echo "FIXTURE ERROR: A6's approval carries no HARD row, or the resolution changed nothing" >&2; exit 2; }

# --- PROGRAMS -----------------------------------------------------------------------------
# Every program is a copy of the WHOLE reconcile/ directory (emit-report.sh resolves $SELF
# beside itself), guarded for its siblings. Mutants overwrite the copy's emit-report.sh.
MUTS=""
mkprog() { # mkprog <name> -> copies reconcile/, refuses a copy missing its siblings
  local d="$R/prog/$1"
  rm -rf "$d"; cp -R "$RDIR" "$d" || { bad "HARNESS BROKEN [$1]: copy of reconcile/ failed"; return 1; }
  [ -f "$d/preclassify.sh" ] && [ -f "$d/ledger-reverify.sh" ] \
    || { bad "HARNESS BROKEN [$1]: the copy lacks its siblings, so it would render nothing and every arm would read as a kill"; return 1; }
}
mkmut() { # mkmut <name> <anchor-regex> <want-hits> <sed-args...>
  local n="$1" anch="$2" want="$3" hits; shift 3
  mkprog "$n" || return 1
  hits="$(grep -c -e "$anch" "$EMIT")" || hits=0
  if [ "$hits" -ne "$want" ]; then
    bad "MUTANT STALE [$n]: its anchor matches $hits line(s) in emit-report.sh, not $want — re-anchor it on the same observable; never relax the assertion"; return 1
  fi
  if ! sed "$@" "$EMIT" > "$R/prog/$n/emit-report.sh"; then
    bad "MUTANT DID NOT APPLY [$n]: sed failed"; return 1
  fi
  if cmp -s "$EMIT" "$R/prog/$n/emit-report.sh"; then
    bad "MUTANT DID NOT APPLY [$n]: the sed matched nothing"; return 1
  fi
  bash -n "$R/prog/$n/emit-report.sh" 2>/dev/null || { bad "MUTANT STALE [$n]: the mutant does not parse"; return 1; }
  MUTS="$MUTS $n"
}
mkprog ctl
if ! diff -rq "$RDIR" "$R/prog/ctl" >/dev/null 2>&1 || [ "$(ls "$R/prog/ctl" | wc -l | tr -d ' ')" -lt 20 ]; then
  bad "HARNESS BROKEN: the unmutated copy differs from reconcile/ or holds fewer than 20 files"
fi

# Orientation group.
mkmut m-diff-rc     '^          if \[ "\$d_rc" = staging-failed \] || \[ "\$d_rc" -ge 2 \]; then$' 1 \
  -e 's/^          if \[ "\$d_rc" = staging-failed \] || \[ "\$d_rc" -ge 2 \]; then$/          if false; then/'
mkmut m-diff-indent '^            echo "DETECTOR-REFUSED  orientation diff exited' 1 \
  -e 's/^            echo "DETECTOR-REFUSED  orientation diff exited/            echo "    DETECTOR-REFUSED  orientation diff exited/'
mkmut m-samp-rc     '^              \[!0\]\*|0:|0:\*\[!0-9\]\*)$' 1 \
  -e 's/^              \[!0\]\*|0:|0:\*\[!0-9\]\*)$/              ZZ-NEVER-ZZ)/'
mkmut m-samp-nonnum '^              \[!0\]\*|0:|0:\*\[!0-9\]\*)$' 1 \
  -e 's/^              \[!0\]\*|0:|0:\*\[!0-9\]\*)$/              [!0]*|0:)/'
mkmut m-lstree      '^        if \[ "\$t_ls_rc" -ne 0 \] || \[ "\$t_rc" -ne 0 \]; then$' 1 \
  -e 's/^        if \[ "\$t_ls_rc" -ne 0 \] || \[ "\$t_rc" -ne 0 \]; then$/        if false; then/'
# Stub group.
mkmut m-rt          '^          if \[ "\$rt_rc" != 0 \]; then$' 1 \
  -e 's/^          if \[ "\$rt_rc" != 0 \]; then$/          if false; then/'
mkmut m-rl-refuse   '^  if \[ "\$rl_rc" = 0 \] || \[ "\$rl_rc" = 1 \]; then none_or "\$rl"; else$' 1 \
  -e 's/^  if \[ "\$rl_rc" = 0 \] || \[ "\$rl_rc" = 1 \]; then none_or "\$rl"; else$/  if true; then none_or "$rl"; else/'
mkmut m-rl-one      '^  if \[ "\$rl_rc" = 0 \] || \[ "\$rl_rc" = 1 \]; then none_or "\$rl"; else$' 1 \
  -e 's/^  if \[ "\$rl_rc" = 0 \] || \[ "\$rl_rc" = 1 \]; then none_or "\$rl"; else$/  if [ "$rl_rc" = 0 ]; then none_or "$rl"; else/'
mkmut m-lr          '^  if \[ "\$lr_rc" -eq 0 \]; then none_or "\$lr"; else$' 1 \
  -e 's/^  if \[ "\$lr_rc" -eq 0 \]; then none_or "\$lr"; else$/  if true; then none_or "$lr"; else/'
# The four "0 ALWAYS" sites share a0_render; each mutant zeroes ONE site's rc, addressed by the
# range from that site's own call line to the rc read after it. The count of intact rc reads
# must drop from 4 to 3, or the range reached the wrong site (or none).
for _s in predicate-differential:m-pd retired-fixtures:m-rf retired-layer-contract:m-rlc retired-layer-passage:m-rlp; do
  _d="${_s%%:*}"; _m="${_s#*:}"
  if mkmut "$_m" "bash \"\\\$SELF/${_d}\\.sh\"" 1 -e "/bash \"\\\$SELF\\/${_d}\\.sh\"/,/^  a0_rc=\\\$?\$/ s/^  a0_rc=\\\$?\$/  a0_rc=0/"; then
    _n="$(grep -c '^  a0_rc=\$?$' "$R/prog/$_m/emit-report.sh")" || _n=0
    _n0="$(grep -c '^  a0_rc=\$?$' "$EMIT")" || _n0=0
    if [ "$_n0" -ne 4 ] || [ "$_n" -ne 3 ]; then
      bad "MUTANT STALE [$_m]: intact a0 rc reads went $_n0 -> $_n, not 4 -> 3"
      MUTS="$(printf '%s\n' $MUTS | grep -vx "$_m" | tr '\n' ' ')"
    fi
  fi
done
# --- THE ENGINE-DRIVEN ARMS H1, A8, A9: their worlds, constants and mutants --------------------------
# H1: THE HOOK VALIDATOR'S FIX LINE NAMES A STABLE PATH, SO TWO RENDERS ARE ONE. The validator prints
# `bash <its own path> --root …` at the foot of its FIX block, and emit-report runs THEIRS' copy out of a
# fresh mktemp file -- so with any ai-dlc hook unregistered every render differed in that line, `--verify`
# failed on every render, and the apply gate could not pass on that consumer state at all. The line now
# names the consumer's INSTALLED path. Its own world: the seed above carries no validator at THEIRS.
# SHIPS AHEAD OF ITS SUBJECT: an installed emit-report.sh that predates the rewrite SKIPs, keyed on the
# rewrite's own variable, which the pre-fix copy lacks. Decided on the RESOLVED engine dir.
H_ISDIST=0
[ "$RDIR" = "$(cd "$HERE/../../skills/ai-dlc-update/reconcile" 2>/dev/null && pwd)" ] && H_ISDIST=1
H1_STATE=on
if ! grep -qF 'HRI="$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh"' "$EMIT" && [ "$H_ISDIST" = 0 ]; then
  H1_STATE=skip
  printf '  SKIP  H1 -- the installed emit-report.sh predates the stable hook-validator path; it lands with the pull that carries this fixture\n'
else
  HV=""; for _c in "$HERE/../../scripts/validate-hook-registration.sh" "$HERE/../../../scripts/ai-dlc/validate-hook-registration.sh"; do
    [ -f "$_c" ] && { HV="$_c"; break; }; done
  HM=""; for _c in "$RDIR/settings-merge.sh"; do [ -f "$_c" ] && HM="$_c"; done
  if [ -z "$HV" ] || [ -z "$HM" ]; then
    H1_STATE=broken
    bad "H1 FIXTURE BROKEN: validate-hook-registration.sh or settings-merge.sh not found beside this unit, so no world can carry an unregistered hook"
  else
    H="$WORK/hook"; mkdir -p "$H/d/core/scripts" "$H/d/templates" "$H/c/.claude/hooks" "$H/c/.claude/skills/ai-dlc-update/reconcile"
    cp "$HV" "$H/d/core/scripts/validate-hook-registration.sh"
    echo "HERMETIC-CONSUMED core/scripts/validate-hook-registration.sh"
    printf '{\n  "hooks": {}\n}\n' > "$H/d/templates/settings.json.template"
    hg() { git -C "$H/d" -c user.name=f -c user.email=f@f -c commit.gpgsign=false "$@"; }
    git init -q "$H/d"; hg add -A; hg commit -qm base; HB="$(hg rev-parse HEAD)"
    printf 'x\n' > "$H/d/templates/x.md"; hg add -A; hg commit -qm theirs; HT="$(hg rev-parse HEAD)"
    printf '{\n  "hooks": {}\n}\n' > "$H/c/.claude/settings.json"
    printf '#!/bin/sh\nexit 0\n' > "$H/c/.claude/hooks/ai-dlc-probe.sh"
    cp "$HM" "$H/c/.claude/skills/ai-dlc-update/reconcile/settings-merge.sh"
  fi
fi

# A8: A STABLE PREDICATE SITE RENDERS ITS POPULATION, NEVER `none`. The step-5 projection used to drop every
# PREDICATE-STABLE row, so a differential whose every site was STABLE rendered `none`: the null reached the
# operator with no population definition. A stub differential with FIXED rows drives the copy, so the cell
# is about the projection alone. The non-STABLE row's rendering is held byte-for-byte. Only the STATIC
# definition renders on the STABLE line; the live counts after it do not (A9 says why).
A8_STABLE="$(printf 'PREDICATE-STABLE\tvalidate-x.sh\tthe read-set moved and NO stored artifact changes verdict, long prose. population: root=`_bmad-output` corpus=`*p*` series=`s/$//`; records=3 series=3 compared=1 passed=1 unclassified=1.')"
A8_RECL="$(printf 'PREDICATE-RECLASSIFIES\tvalidate-y.sh\tAT LEAST 1 of 2 stored series change verdict. population: root=`_bmad-output` corpus=`*q*` series=`s/$//`; records=2 series=2 compared=2 unclassified=n/a (grammar spells failures only).')"
a8_prog() { # a8_prog <dir> <emit-source> <rows...> -> a reconcile/ copy whose differential prints <rows>
  local d="$1" e="$2"; shift 2
  cp -R "$RDIR" "$d" && cp "$e" "$d/emit-report.sh" || return 1
  { echo '#!/usr/bin/env bash'; for r in "$@"; do printf "printf '%%s\\\\n' '%s'\n" "$r"; done; echo 'exit 0'; } > "$d/predicate-differential.sh"
}
a8_sect() { # a8_sect <dir> -> the rendered Predicate reclassification section
  bash "$1/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$1.out" 2>/dev/null
  sect "$1.out" '**Predicate reclassification'
}
a8_want_s='PREDICATE-STABLE  validate-x.sh  population: root=`_bmad-output` corpus=`*p*` series=`s/$//`'
a8_want_r="$(printf '%s' "$A8_RECL" | awk -F'\t' '{print $1"  "$2"  "$3}')"

# A9: A CORPUS THAT GROWS BETWEEN APPROVE AND VERIFY DOES NOT FAIL --verify. `apply.sh` runs `--verify` at
# step 7 against the region approved at step 5, byte-compared. The differential's counts come from the LIVE
# corpus, so a projection carrying them fails verify as stale/hand-edited the moment the consumer's own
# pipeline writes one artifact in between. The stub counts a real pattern under its consumer argument, so
# growing the corpus is a real write. Control: the same world verifies at rc 0 before the write.
a9_world() { # a9_world <dir> <emit-source> -> a reconcile/ copy and a private consumer copy
  local d="$1"
  cp -R "$RDIR" "$d" && cp "$2" "$d/emit-report.sh" && cp -R "$CONSUMER" "$d.c" || return 1
  mkdir -p "$d.c/_bmad-output/a9" && printf 'a9\n' > "$d.c/_bmad-output/a9/a9-pass1.md" || return 1
  cat > "$d/predicate-differential.sh" <<'A9STUB'
#!/usr/bin/env bash
n="$(find "$4/_bmad-output/a9" -type f -name 'a9-pass*' | wc -l | tr -d ' ')"
printf 'PREDICATE-STABLE\tvalidate-a9.sh\tthe read-set moved and NO stored artifact changes verdict. population: root=`_bmad-output` corpus=`a9-pass*` series=`s/$//`; records=%s series=%s compared=0 unclassified=n/a (grammar spells failures only).\n' "$n" "$n"
exit 0
A9STUB
}
a9_run() { # a9_run <dir> -> "<rc-before-write> <rc-after-write>"
  local d="$1" r1 r2
  bash "$d/emit-report.sh" "$DIST" "$BASE" "$d.c" "$THEIRS" > "$d.region" 2>/dev/null
  { echo "# Reconcile report (fixture)"; echo; cat "$d.region"; } > "$d.report"
  bash "$d/emit-report.sh" --verify "$d.report" "$DIST" "$BASE" "$d.c" "$THEIRS" >/dev/null 2>&1; r1=$?
  printf 'a9\n' > "$d.c/_bmad-output/a9/a9-pass2.md"
  bash "$d/emit-report.sh" --verify "$d.report" "$DIST" "$BASE" "$d.c" "$THEIRS" >/dev/null 2>&1; r2=$?
  printf '%s %s' "$r1" "$r2"
}

# The three mutants of these arms, each a program (a whole reconcile/ copy, one emit-report.sh edited) built by
# whole-line replacement (awk, ENVIRON), so no sed escaping can make it a no-op; each must apply to one line.
EMUTS=""
if [ "$H1_STATE" = on ] && mkprog h1-unstable; then
  # MUTANT: the rewrite removed, so the FIX line names the mktemp copy again.
  A='             print }'"'"')" && [ -n "$hrs" ] && hro="$hrs"' B='             print }'"'"')"' \
    awk '$0 == ENVIRON["A"] { print ENVIRON["B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' "$EMIT" > "$R/prog/h1-unstable/emit-report.sh"
  _arc=$?
  if [ "$_arc" -ne 0 ] || cmp -s "$EMIT" "$R/prog/h1-unstable/emit-report.sh"; then
    bad "H1 mutant DID NOT APPLY, so the stable-path arm is unproven"
  else EMUTS="$EMUTS h1-unstable"; fi
fi
# The mutant restores the pre-fix projection (STABLE rows filtered out).
A8_OLD="  a0_render \"\$a0_rc\" \"\$a0_raw\" '\$1!=\"PREDICATE-STABLE\"{print \$1\"  \"\$2\"  \"\$3}' \"predicate-differential.sh <dist> <base> <theirs> <consumer>\""
A8_KEY='  a0_render "$a0_rc" "$a0_raw" '"'"'$1!="PREDICATE-STABLE"{print $1"  "$2"  "$3; next}'
if mkprog a8-stable-filter; then
  A8_OLD="$A8_OLD" A8_KEY="$A8_KEY" awk 'index($0, ENVIRON["A8_KEY"]) == 1 { print ENVIRON["A8_OLD"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
    "$EMIT" > "$R/prog/a8-stable-filter/emit-report.sh"
  _arc=$?
  if [ "$_arc" -ne 0 ] || cmp -s "$EMIT" "$R/prog/a8-stable-filter/emit-report.sh"; then
    bad "A8 mutant DID NOT APPLY (the projection line moved), so the STABLE arm is unproven -- re-anchor on the same line"
  else EMUTS="$EMUTS a8-stable-filter"; fi
fi
# The mutant puts the counts back into the projection: the match runs to end of line again.
A9_NEW='match($3, /population: root=`[^`]*` corpus=`[^`]*` series=`[^`]*`/){print $1"  "$2"  "substr($3, RSTART, RLENGTH); next}'
A9_OLD='match($3, /population: .*$/){print $1"  "$2"  "substr($3, RSTART); next}'
if mkprog a9-counts-in-projection; then
  A9_NEW="$A9_NEW" A9_OLD="$A9_OLD" awk '{ i = index($0, ENVIRON["A9_NEW"]); if (i) { $0 = substr($0, 1, i - 1) ENVIRON["A9_OLD"] substr($0, i + length(ENVIRON["A9_NEW"])); n++ } print }
    END { exit (n == 1) ? 0 : 3 }' "$EMIT" > "$R/prog/a9-counts-in-projection/emit-report.sh"
  _arc=$?
  if [ "$_arc" -ne 0 ] || cmp -s "$EMIT" "$R/prog/a9-counts-in-projection/emit-report.sh"; then
    bad "A9 mutant DID NOT APPLY (the projection line moved), so the verify arm is unproven -- re-anchor on the same line"
  else EMUTS="$EMUTS a9-counts-in-projection"; fi
fi

# --- UNITS ----------------------------------------------------------------------------------------
# A unit is one render of one program (or one R6 scenario). It is a background job that writes ONLY under
# $R/out/<prog>/ (or $R6/), is idempotent through its .done file, and asserts nothing; every verdict is
# read in the foreground, where `bad` counts. Which units run is decided by the mode (see the header).
STUBS="retired-tokens.sh:2 relabel-extension-checks.sh:2 ledger-reverify.sh:3 predicate-differential.sh:1 retired-fixtures.sh:3 retired-layer-contract.sh:2 retired-layer-passage.sh:1"
ren() { # ren <prog> <arm> <shim-or-> <theirs> <consumer> [<emit>]
  local o="$R/out/$1" p="$PATH" e="${6:-$R/prog/$1/emit-report.sh}"
  [ "$3" != - ] && p="$R/sh/$3:$PATH"
  : > "$o/$2.fired"
  env PATH="$p" SHIM_FIRED="$o/$2.fired" bash "$e" "$DIST" "$BASE" "$5" "$4" > "$o/$2.out" 2>/dev/null
  echo "$?" > "$o/$2.rc"
}
unit_of() { # <arm> -> the unit whose run decides it
  case "$1" in
    A0) echo w0 ;; A1-*) echo a1 ;; A2) echo a2 ;; A3) echo a3 ;; A4a) echo a4a ;; A4b) echo a4b ;;
    A5) echo a5 ;; A6) echo a6 ;; H1) echo H1 ;; A8) echo A8 ;; A9) echo A9 ;;
    R6APPR) echo appr ;; R6SCORE) echo score ;; R6STUB) echo stub ;;
  esac
}
h1_unit() { # <prog> -> $R/out/<prog>/H1.v = "<identical yes|no> <verify rc> <unregistered named yes|no>"
  local e="$R/prog/$1/emit-report.sh" o="$R/out/$1" a b v
  a="$(bash "$e" "$H/d" "$HB" "$H/c" "$HT" 2>/dev/null)"; b="$(bash "$e" "$H/d" "$HB" "$H/c" "$HT" 2>/dev/null)"
  printf '%s\n' "$a" > "$o/H1.report"
  bash "$e" --verify "$o/H1.report" "$H/d" "$HB" "$H/c" "$HT" >/dev/null 2>&1; v=$?
  printf '%s %s %s' "$([ "$a" = "$b" ] && echo yes || echo no)" "$v" \
    "$(grep -qF '.claude/hooks/ai-dlc-probe.sh' <<<"$a" && echo yes || echo no)" > "$o/H1.v"
}
a8_unit() { # <prog> -> A8.s (a STABLE-only differential's section) and A8.b (beside a RECLASSIFIES row)
  local e="$R/prog/$1/emit-report.sh" o="$R/out/$1"
  a8_prog "$R/a8-$1-s" "$e" "$A8_STABLE" && a8_sect "$R/a8-$1-s" > "$o/A8.s"
  a8_prog "$R/a8-$1-b" "$e" "$A8_STABLE" "$A8_RECL" && a8_sect "$R/a8-$1-b" > "$o/A8.b"
}
a9_unit() { # <prog> -> A9.v = "<verify rc before the write> <after>"; A9.live when the region carries the live count
  local e="$R/prog/$1/emit-report.sh" o="$R/out/$1"
  a9_world "$R/a9-$1" "$e" || { echo X > "$o/A9.v"; return 0; }
  a9_run "$R/a9-$1" > "$o/A9.v"
  grep -qF 'records=1 ' "$R/a9-$1.region" && : > "$o/A9.live"
}
unit_run() { # <prog> <unit>
  local p="$1" u="$2" o d s n c v
  case "$u" in appr|score|stub)
    v="${p#r6-}"; [ "$p" = ship ] && v=ship
    [ -f "$R6/$v.$u.done" ] || r6run "$u" "$v"
    return 0 ;;
  esac
  o="$R/out/$p"; d="$R/prog/$p"; mkdir -p "$o"
  [ -f "$o/$u.done" ] && return 0
  case "$u" in
    w0)  ren "$p" w0 - "$THEIRS" "$CONSUMER" ;;
    a3)  ren "$p" a3 diff-zeta "$T2" "$C2" ;;
    a4a) ren "$p" a4a awk-fail "$THEIRS" "$CONSUMER" ;;
    a4b) ren "$p" a4b awk-nonnum "$THEIRS" "$CONSUMER" ;;
    a5)  ren "$p" a5 git-split "$T2" "$C2" ;;
    a6)
      : > "$o/a6.fired"
      env PATH="$R/sh/diff-classes:$PATH" SHIM_FIRED="$o/a6.fired" bash "$d/emit-report.sh" --verify "$R/a6-approved.md" "$DIST" "$BASE" "$C3" "$THEIRS" >/dev/null 2>"$o/a6.err"
      echo "$?" > "$o/a6.rc" ;;
    a1)
      cp -R "$d" "$d-allstub"
      for s in $STUBS; do n="${s%%:*}"; c="${s#*:}"; printf '#!/usr/bin/env bash\nexit %s\n' "$c" > "$d-allstub/$n"; done
      ren "$p" a1 - "$THEIRS" "$CONSUMER" "$d-allstub/emit-report.sh" ;;
    a2)
      cp -R "$d" "$d-rl1"
      printf '#!/usr/bin/env bash\nprintf "%%s\\n" "  + ### 7. probe relabel"\nexit 1\n' > "$d-rl1/relabel-extension-checks.sh"
      ren "$p" a2 - "$THEIRS" "$CONSUMER" "$d-rl1/emit-report.sh" ;;
    H1)  h1_unit "$p" ;;
    A8)  a8_unit "$p" ;;
    A9)  a9_unit "$p" ;;
  esac
  : > "$o/$u.done"
}

# --- R6: the reconcile-emit-report guard, extracted from the sibling's own run.sh ---------------
# The helpers are cut from the SHIPPING file by their definitions, so a change there is a change
# here. Positive control: all four definitions and the baseline derivation must be present.
R6="$R/r6"; mkdir -p "$R6"
awk '
  /^V_TRIES=3$/ { p = 1 }
  /^v_resolve\(\) / { p = 0 }
  /^v_stub\(\) \{/ || /^v_score\(\) \{/ { q = 1 }
  p || q { print }
  q && /^}$/ { q = 0 }' "$SIB/run.sh" > "$R6/ship.sh"
_r6n="$(grep -cE '^(v_foreign|v_approve|v_stub|v_score)\(\) \{|^V_REFUSE_OK=' "$R6/ship.sh")" || _r6n=0
R6_ON=1
if [ "$_r6n" -ne 5 ]; then
  R6_ON=0
  bad "R6 HARNESS BROKEN: extracted $_r6n of 5 definitions (v_foreign, v_approve, v_stub, v_score, V_REFUSE_OK) from reconcile-emit-report/run.sh — the guard was renamed or moved; re-anchor the extraction, never relax it"
fi
r6mut() { # r6mut <name> <anchor-regex> <sed-expr>
  local h; h="$(grep -c -e "$2" "$R6/ship.sh")" || h=0
  if [ "$h" -ne 1 ]; then bad "R6 MUTANT STALE [$1]: anchor matches $h lines, not 1"; return 1; fi
  sed -e "$3" "$R6/ship.sh" > "$R6/$1.sh" || { bad "R6 MUTANT DID NOT APPLY [$1]: sed failed"; return 1; }
  cmp -s "$R6/ship.sh" "$R6/$1.sh" && { bad "R6 MUTANT DID NOT APPLY [$1]: matched nothing"; return 1; }
  bash -n "$R6/$1.sh" 2>/dev/null || { bad "R6 MUTANT STALE [$1]: does not parse"; return 1; }
}
R6MUTS=""
r6m() { r6mut "$@" && R6MUTS="$R6MUTS r6-$1"; }
r6m approve-noretry '^  until \[ "\$a" -ge "\$V_TRIES" \]; do$' 's/^  until \[ "\$a" -ge "\$V_TRIES" \]; do$/  until [ "$a" -ge 1 ]; do/'
r6m approve-noguard '^    x="\$(v_foreign "\$d/region.md" "")"$' 's/^    x="\$(v_foreign "\$d\/region.md" "")"$/    x=""/'
r6m baseline-empty  '^V_REFUSE_OK=' 's/^V_REFUSE_OK=.*/V_REFUSE_OK=""/'
r6m score-noretry   '^  while \[ "\$a" -lt "\$V_TRIES" \]; do$' 's/^  while \[ "\$a" -lt "\$V_TRIES" \]; do$/  while [ "$a" -lt 1 ]; do/'
r6m score-noguard   '^    x="\$(v_foreign "\$f" "< " "\$sok")"$' 's/^    x="\$(v_foreign "\$f" "< " "\$sok")"$/    x=""/'
r6m score-nostub    '^  \[ -f "\${e%/\*}/\.stubbed" \] && read' 's/^  \[ -f "\${e%\/\*}\/\.stubbed" \] && read.*/  :/'
# E3 exactly as reconcile-emit-report builds it: V-N's recorded wrong verdict needs that program.
E3D="$R6/e3"; rm -rf "$E3D"; cp -R "$RDIR" "$E3D"
sed -e 's/^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$/elif [ "$hard_gone" -gt 0 ] \&\& [ "$refused_new" -eq 0 ]; then/' "$EMIT" > "$E3D/emit-report.sh"
cmp -s "$EMIT" "$E3D/emit-report.sh" && bad "R6 HARNESS BROKEN: the E3 mutation matched nothing in emit-report.sh"

# r6run <kind appr|score|stub> <variant> — one subshell, its own VW, results in $R6/<variant>.<kind>.*
r6run() {
  local kind="$1" var="$2" key="$2.$1"
  (
    VW="$R6/vw-$key"; mkdir -p "$VW"
    bad() { printf '%s\n' "$1" >> "$R6/$key.bad"; }
    # shellcheck source=/dev/null
    . "$R6/$var.sh"
    export ONESHOT="$R6/$key.fired"; rmdir "$ONESHOT" 2>/dev/null
    w() { mkdir -p "$VW/$1" && cp -R "$CONSUMER" "$VW/$1/consumer"; }
    resolve() { git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$VW/$1/consumer/.claude/schemas/thing.json"; }
    case "$kind" in
      appr)   # V-N approved under a one-shot orientation failure, then scored by E3
        w V-N
        PATH="$R/sh/diff-once:$PATH" v_approve V-N "$THEIRS"
        resolve V-N
        mkdir -p "$VW/V-N/consumer/.claude/skills/ai-dlc/overrides"
        printf -- '---\nshadows: core/rules/nonexistent.md#Nope\nbase_sha: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\nreason: probe\n---\n\n## Nope\n\nprobe body\n' \
          > "$VW/V-N/consumer/.claude/skills/ai-dlc/overrides/probe.md"
        v_score "$E3D/emit-report.sh" V-N E3 > "$R6/$key.cell"
        grep -c '^DETECTOR-REFUSED  retired-layer-token\.sh' "$VW/V-N/region.md" > "$R6/$key.base" ;;
      score)  # V-HC approved healthy, scored under a one-shot failure
        w V-HC; v_approve V-HC "$THEIRS"
        awk '/^HARD-UNREGISTERED-CORE-DRIFT/ && !d { d = 1; next } { print }' "$VW/V-HC/region.md" > "$VW/V-HC/half.md"
        { echo "# Reconcile report (fixture)"; echo; cat "$VW/V-HC/half.md"; } > "$VW/V-HC/approved.md"
        PATH="$R/sh/diff-once:$PATH" v_score "$EMIT" V-HC ship > "$R6/$key.cell"
        [ -f "$VW/V-HC/broken.ship" ] && cp "$VW/V-HC/broken.ship" "$R6/$key.broken" ;;
      stub)   # V-HB: the stubbed sibling's own refusal is the world's subject, not a transient
        w V-HB; v_approve V-HB "$THEIRS"
        dh="$(v_stub "$EMIT" "$VW/dead-hb" hard-blockers.sh)"
        v_score "$dh" V-HB ship > "$R6/$key.cell"
        [ -f "$VW/V-HB/broken.ship" ] && cp "$VW/V-HB/broken.ship" "$R6/$key.broken" ;;
    esac
    : > "$R6/$key.done"
  )
}

# --- JUDGES: each prints nothing and returns 0 on PASS, prints its reason and returns 1 ------
O=""
sect() { awk -v h="$2" 'f && /^$/ { exit } f { print } index($0, h) == 1 { f = 1 }' "$1"; }
cnt()  { local n; n="$(grep -c -e "$1" "$2" 2>/dev/null)" || n=0; printf '%s' "$n"; }
hdr_of() {
  case "$1" in
    relabel-extension-checks.sh) echo '**Catalog relabel' ;;
    ledger-reverify.sh)          echo '**Push-candidate ledger' ;;
    predicate-differential.sh)   echo '**Predicate reclassification' ;;
    retired-fixtures.sh)         echo '**Retired core fixtures' ;;
    retired-layer-contract.sh)   echo '**Retired contract shapes' ;;
    retired-layer-passage.sh)    echo '**Retired core passages' ;;
  esac
}
j_a0() {
  local f="$O/w0.out"
  [ "$(cat "$O/w0.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/w0.rc" 2>/dev/null)"; return 1; }
  cmp -s "$f" "$REGION" || { echo "the copy's render differs from the seed region"; return 1; }
  [ "$(cnt 'ONLY IN THEIRS (1, complete):' "$f")" = 1 ] && [ "$(cnt '^NEEDS-REVIEW  PC-FIXTURE' "$f")" = 2 ] \
    && [ "$(cnt 'RETIRED-CONTRACT-TOKEN: none' "$f")" = 1 ] && [ "$(sect "$f" '**Catalog relabel')" = none ] \
    || { echo "a baseline row is missing (orientation sample, the two NEEDS-REVIEW rows, the RETIRED-CONTRACT-TOKEN line or relabel's none)"; return 1; }
  [ "$(grep '^DETECTOR-REFUSED' "$f" | awk '{ print $2 }')" = retired-layer-token.sh ] \
    || { echo "the seed's refusal set is not exactly {retired-layer-token.sh}"; return 1; }
}
j_a1() { # j_a1 <sibling>
  local f="$O/a1.out" s c b
  c="$(printf '%s\n' $STUBS | awk -F: -v n="$1" '$1 == n { print $2 }')"
  [ "$(cat "$O/a1.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/a1.rc" 2>/dev/null)"; return 1; }
  grep -q '^HARD-UNREGISTERED-CORE-DRIFT' "$f" && [ "$(cnt 'ONLY IN OURS (1, complete):' "$f")" = 1 ] \
    || { echo "the unstubbed sections did not render (no HARD row or no orientation sample)"; return 1; }
  s="$(cnt "^DETECTOR-REFUSED  $1 exited $c " "$f")"
  [ "$s" = 1 ] || { echo "$s column-0 'DETECTOR-REFUSED  $1 exited $c' lines, want 1"; return 1; }
  if [ "$1" = retired-tokens.sh ]; then
    [ "$(cnt 'RETIRED-CONTRACT-TOKEN: none' "$f")" = 0 ] || { echo "RETIRED-CONTRACT-TOKEN: none still renders"; return 1; }
  else
    b="$(sect "$f" "$(hdr_of "$1")")"
    case "$b" in "DETECTOR-REFUSED  $1 exited $c "*) : ;; *) echo "its section reads '$(printf '%s' "$b" | head -1 | cut -c1-60)', not the refusal"; return 1 ;; esac
    [ "$(printf '%s\n' "$b" | grep -c .)" = 1 ] || { echo "its section carries more than the refusal"; return 1; }
  fi
}
j_a2() {
  local f="$O/a2.out"
  [ "$(cat "$O/a2.rc" 2>/dev/null)" = 0 ] && [ "$(sect "$f" '**Catalog relabel')" = '  ### 7. probe relabel' ] \
    && [ "$(cnt 'DETECTOR-REFUSED  relabel' "$f")" = 0 ] \
    || { echo "relabel exit 1 did not render exactly its row with no refusal"; return 1; }
}
j_a3() {
  local f="$O/a3.out"
  [ "$(cat "$O/a3.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/a3.rc" 2>/dev/null)"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation diff exited 2 for $ZE" "$f")" = 1 ] || { echo "no refusal naming zeta.md"; return 1; }
  [ "$(cnt 'DETECTOR-REFUSED  orientation' "$f")" = 1 ] || { echo "more than the one refused file refused"; return 1; }
  [ "$(cnt 'SENTINEL-THEIRS-ONLY upstream process class' "$f")" = 1 ] && [ "$(cnt 'ONLY IN THEIRS (1, complete):' "$f")" = 1 ] \
    || { echo "the FIRST file lost its sample"; return 1; }
  [ "$(cnt 'ONLY IN [A-Z]*: none' "$f")" = 0 ] || { echo "an ONLY IN …: none rendered"; return 1; }
}
j_a4() { # j_a4 <a4a|a4b> <rc-in-line>
  local f="$O/$1.out"
  [ "$(cat "$O/$1.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/$1.rc" 2>/dev/null)"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation sample exited $2 for $CL (THEIRS)" "$f")" = 1 ] || { echo "no THEIRS-side sample refusal exiting $2"; return 1; }
  [ "$(cnt 'ONLY IN OURS (1, complete):' "$f")" = 1 ] && [ "$(cnt 'ONLY IN THEIRS' "$f")" = 0 ] \
    || { echo "the OURS side did not keep its sample, or the THEIRS side rendered one"; return 1; }
}
j_a5() {
  local f="$O/a5.out"
  [ "$(cat "$O/a5.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/a5.rc" 2>/dev/null)"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation read of $CL at $T2 failed (ls-tree exited 128, show exited 0)" "$f")" = 1 ] || { echo "no ls-tree refusal for classes.md"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation read of $ZE at $T2 failed (ls-tree exited 0, show exited 128)" "$f")" = 1 ] || { echo "no show refusal for zeta.md"; return 1; }
  [ "$(cnt "THEIRS absent at $T2" "$f")" = 1 ] || { echo "the truly absent thing.json did not render THEIRS absent (or a refused file did)"; return 1; }
}
j_a6() {
  local rc; rc="$(cat "$O/a6.rc" 2>/dev/null)"
  [ "$rc" = 1 ] && grep -q '^  cause: UNDECIDED .* and 1 DETECTOR-REFUSED line(s)' "$O/a6.err" \
    && grep -q '^< DETECTOR-REFUSED  orientation diff exited 2 for ' "$O/a6.err" \
    || { echo "verify rc $rc cause $(awk '/^  cause: /{ print $2; exit }' "$O/a6.err"), want 1 UNDECIDED counting 1 column-0 refusal"; return 1; }
}
ORIENT_ARMS="a3 a4a a4b a5 a6"
STUB_ARMS="a1:retired-tokens.sh a1:relabel-extension-checks.sh a1:ledger-reverify.sh a1:predicate-differential.sh a1:retired-fixtures.sh a1:retired-layer-contract.sh a1:retired-layer-passage.sh a2"
judge() { # judge <arm> -> reason on stdout, rc
  case "$1" in
    a0) j_a0 ;; a1:*) j_a1 "${1#a1:}" ;; a2) j_a2 ;; a3) j_a3 ;;
    a4a) j_a4 a4a 2 ;; a4b) j_a4 a4b 0 ;; a5) j_a5 ;; a6) j_a6 ;;
  esac
}
arm_text() {
  case "$1" in
    a0) echo "A0 CONTROL the unmutated copy renders the seed world byte-identically, with every section the stub arms refuse carrying its baseline row, and the seed's only refusal is retired-layer-token.sh" ;;
    a1:*) echo "A1 ${1#a1:} exiting non-zero renders ONE column-0 DETECTOR-REFUSED naming it and its rc in place of its section, render rc 0, the unstubbed sections intact" ;;
    a2) echo "A2 relabel exiting 1 is its FINDING: the row renders and no refusal does" ;;
    a3) echo "A3 the orientation diff failing on the SECOND CLASSIFY file refuses that file only; the first keeps its complete sample and no 'ONLY IN …: none' renders" ;;
    a4a) echo "A4a the sample awk exiting 2 refuses the THEIRS side and the OURS side keeps its sample" ;;
    a4b) echo "A4b the sample awk printing a non-numeric count refuses rather than defaulting to 0" ;;
    a5) echo "A5 a failed ls-tree and a failed show each render a refusal, while a path truly absent at theirs renders THEIRS absent" ;;
    a6) echo "A6 approve healthy, resolve the HARD drift, verify under a diff shim: rc 1 UNDECIDED counting the column-0 refusal, never BLOCKERS-RESOLVED" ;;
  esac
}

# --- ARM VERDICTS ----------------------------------------------------------------------------------
# armv <program> <arm> -> 0 the arm HOLDS, 1 it TRIPPED, X its unit never ran. An arm whose subject a
# program does not touch reads the control's verdict (header): an R6 arm under an emit-report.sh mutant reads
# the shipping guard (variant ship), an emit-report arm under an R6 variant reads the control program.
oldid() { case "$1" in A1-*) echo "a1:${1#A1-}" ;; *) printf '%s' "$1" | tr 'A-Z' 'a-z' ;; esac; }
r6f() { cat "$R6/$1" 2>/dev/null; }
r6_verdict() { # <arm> <variant>
  local k
  case "$1" in
    R6APPR) k="$2.appr"; [ -f "$R6/$k.done" ] || { echo X; return 0; }
      if [ -d "$R6/$k.fired" ] && [ ! -s "$R6/$k.bad" ] && [ "$(r6f "$k.cell")" = '3|BLOCKERS-RESOLVED|1|1|0|0' ] && [ "$(r6f "$k.base")" = 1 ]; then echo 0; else echo 1; fi ;;
    R6SCORE) k="$2.score"; [ -f "$R6/$k.done" ] || { echo X; return 0; }
      if [ -d "$R6/$k.fired" ] && [ ! -f "$R6/$k.broken" ] && [ "$(r6f "$k.cell")" = '1|UNDECIDED|0|0|0|0' ]; then echo 0; else echo 1; fi ;;
    R6STUB) k="$2.stub"; [ -f "$R6/$k.done" ] || { echo X; return 0; }
      if [ ! -f "$R6/$k.broken" ] && [ "$(r6f "$k.cell")" = '1|UNDECIDED|0|0|1|0' ]; then echo 0; else echo 1; fi ;;
  esac
}
a8_judge_s() { [ "$(cat "$1/A8.s" 2>/dev/null)" = "$a8_want_s" ]; }
a8_judge_b() {
  local b n r; b="$(cat "$1/A8.b" 2>/dev/null)"
  n="$(grep -c . <<<"$b")" || n=0; r="$(grep -F 'PREDICATE-RECLASSIFIES' <<<"$b")" || r=""
  [ "$n" = 2 ] && [ "$r" = "$a8_want_r" ] && grep -qxF "$a8_want_s" <<<"$b"
}
emit_verdict() { # <program> <arm>
  local p="$1" a="$2" u; u="$(unit_of "$a")"
  [ -f "$R/out/$p/$u.done" ] || { echo X; return 0; }
  O="$R/out/$p"
  case "$a" in
    H1) [ "$(cat "$O/H1.v" 2>/dev/null)" = "yes 0 yes" ] && echo 0 || echo 1 ;;
    A8) if a8_judge_s "$O" && a8_judge_b "$O"; then echo 0; else echo 1; fi ;;
    A9) [ "$(cat "$O/A9.v" 2>/dev/null)" = "0 0" ] && echo 0 || echo 1 ;;
    *)  if judge "$(oldid "$a")" >/dev/null; then echo 0; else echo 1; fi ;;
  esac
}
armv() { # <program> <arm>
  local p="$1" a="$2"
  case "$a" in
    R6*) case "$p" in r6-*) r6_verdict "$a" "${p#r6-}" ;; *) r6_verdict "$a" ship ;; esac ;;
    *)   case "$p" in r6-*) p=ctl ;; esac; emit_verdict "$p" "$a" ;;
  esac
}

# --- THE MUTANT TABLE: name | program | deciding arm | twin arm ---------------------------------------
# The deciding arm is the one arm the base's exact-vector assertion named first (the minimal one); the twin
# is an arm the measured matrix shows GREEN for the mutant. Re-measure with --matrix after any change.
MT="m-diff-rc|m-diff-rc|A3|A4a
m-diff-indent|m-diff-indent|A6|A3
m-samp-rc|m-samp-rc|A4a|A3
m-samp-nonnum|m-samp-nonnum|A4b|A3
m-lstree|m-lstree|A5|A3
m-rt|m-rt|A1-retired-tokens.sh|A2
m-rl-refuse|m-rl-refuse|A1-relabel-extension-checks.sh|A2
m-rl-one|m-rl-one|A2|A1-ledger-reverify.sh
m-lr|m-lr|A1-ledger-reverify.sh|A2
m-pd|m-pd|A1-predicate-differential.sh|A2
m-rf|m-rf|A1-retired-fixtures.sh|A2
m-rlc|m-rlc|A1-retired-layer-contract.sh|A2
m-rlp|m-rlp|A1-retired-layer-passage.sh|A2
h1-unstable|h1-unstable|H1|A8
a8-stable-filter|a8-stable-filter|A8|A9
a9-counts-in-projection|a9-counts-in-projection|A9|H1
r6-approve-noretry|r6-approve-noretry|R6APPR|R6SCORE
r6-approve-noguard|r6-approve-noguard|R6APPR|R6SCORE
r6-baseline-empty|r6-baseline-empty|R6APPR|R6SCORE
r6-score-noretry|r6-score-noretry|R6SCORE|R6APPR
r6-score-noguard|r6-score-noguard|R6SCORE|R6APPR
r6-score-nostub|r6-score-nostub|R6STUB|R6APPR
"
# A kill is evidence only if the mutant produced the observable its defect names, for the right reason: a
# unit that died for another reason also reads TRIPPED. These three arms assert the exact observable.
kobs_ok() { # <mutant> <program>
  case "$1" in
    h1-unstable)             [ "$(cat "$R/out/$2/H1.v" 2>/dev/null)" = "no 1 yes" ] ;;
    a8-stable-filter)        [ "$(cat "$R/out/$2/A8.s" 2>/dev/null)" = none ] ;;
    a9-counts-in-projection) [ "$(cat "$R/out/$2/A9.v" 2>/dev/null)" = "0 1" ] ;;
    r6-approve-noretry) grep -q '^FIXTURE BROKEN — V-N approval rendered DETECTOR-REFUSED on 3 attempts: DETECTOR-REFUSED  orientation diff exited 2 ' "$R6/${2#r6-}.appr.bad" 2>/dev/null ;;
    r6-approve-noguard) [ ! -s "$R6/${2#r6-}.appr.bad" ] && [ "$(r6f "${2#r6-}.appr.cell")" = '3|BLOCKERS-RESOLVED|1|1|4|4' ] ;;
    r6-baseline-empty)  grep -q '^FIXTURE BROKEN — V-N approval rendered DETECTOR-REFUSED on 3 attempts: DETECTOR-REFUSED  retired-layer-token\.sh' "$R6/${2#r6-}.appr.bad" 2>/dev/null ;;
    r6-score-noretry)   [ "$(r6f "${2#r6-}.score.cell")" = '1|UNDECIDED|0|0|1|0' ] && grep -q '^DETECTOR-REFUSED  orientation diff exited 2 ' "$R6/${2#r6-}.score.broken" 2>/dev/null ;;
    r6-score-noguard)   [ "$(r6f "${2#r6-}.score.cell")" = '1|UNDECIDED|0|0|1|0' ] && [ ! -f "$R6/${2#r6-}.score.broken" ] ;;
    r6-score-nostub)    grep -q '^DETECTOR-REFUSED  hard-blockers\.sh' "$R6/${2#r6-}.stub.broken" 2>/dev/null ;;
    *) true ;;
  esac
}

EUNITS="w0 a1 a2 a3 a4a a4b a5 a6"
[ "$H1_STATE" = on ] && EUNITS="$EUNITS H1"
EUNITS="$EUNITS A8 A9"
ARMS_ALL="A0 A1-retired-tokens.sh A1-relabel-extension-checks.sh A1-ledger-reverify.sh A1-predicate-differential.sh A1-retired-fixtures.sh A1-retired-layer-contract.sh A1-retired-layer-passage.sh A2 A3 A4a A4b A5 A6"
[ "$H1_STATE" = on ] && ARMS_ALL="$ARMS_ALL H1"
ARMS_ALL="$ARMS_ALL A8 A9"
[ "$R6_ON" = 1 ] && ARMS_ALL="$ARMS_ALL R6APPR R6SCORE R6STUB"
in_set() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; } # <word> <space-separated set>

# --- SCHEDULE: every unit the mode needs, 4 at a time ------------------------------------------------
NEEDS=""
need() { NEEDS="$NEEDS $1:$2"; }
for _u in $EUNITS; do need ctl "$_u"; done
[ "$R6_ON" = 1 ] && for _u in appr score stub; do need ship "$_u"; done
while IFS='|' read -r _n _p _d _t; do
  [ -n "$_n" ] || continue
  in_set "$_p" "$MUTS $EMUTS $R6MUTS" || continue
  case "$_p" in
    r6-*) if [ "$MATRIX" -eq 1 ]; then for _u in appr score stub; do need "$_p" "$_u"; done
          else need "$_p" "$(unit_of "$_d")"; need "$_p" "$(unit_of "$_t")"; fi ;;
    *)    if [ "$MATRIX" -eq 1 ]; then for _u in $EUNITS; do need "$_p" "$_u"; done
          else need "$_p" "$(unit_of "$_d")"; need "$_p" "$(unit_of "$_t")"; fi ;;
  esac
done <<EOF
$MT
EOF
_n=0
for _x in $(printf '%s\n' $NEEDS | sort -u); do
  ( unit_run "${_x%%:*}" "${_x#*:}" ) &
  _n=$((_n+1)); [ "$_n" -ge 4 ] && { wait; _n=0; }
done
wait
N_UNITS="$(printf '%s\n' $NEEDS | sort -u | grep -c .)" || N_UNITS=0
printf '  units run: %s\n' "$N_UNITS"

# --- EVERY FORCED FAILURE MUST HAVE FIRED, IN EVERY PROGRAM THAT RAN IT ------------------------------
# Checked apart from the verdicts and before any is read: an arm whose shim never matched the engine's
# call shape measures a healthy render, which the ctl judges read as a failure and a mutant's judges read
# as a kill. A5's shim has two call shapes (ls-tree on one file, show on another), so it fires at least twice.
_unfired=""
for _p in ctl $MUTS $EMUTS; do
  for _f in a3:1 a4a:1 a4b:1 a5:2 a6:1; do
    [ -f "$R/out/$_p/${_f%%:*}.done" ] || continue
    _k="$(grep -c . "$R/out/$_p/${_f%%:*}.fired" 2>/dev/null)" || _k=0
    [ "$_k" -ge "${_f#*:}" ] || _unfired="$_unfired $_p/${_f%%:*}($_k)"
  done
done
[ -z "$_unfired" ] && ok "every forced-failure shim FIRED in every program that ran it (a marker line per firing)" \
  || bad "FIXTURE BROKEN — these forced failures never fired, so their renders are healthy and every verdict on them is void:$_unfired — the engine's call shape moved away from the shim; re-key the shim, never relax this"

# --- VERDICTS: the unmutated copy (MX0) -------------------------------------------------------------
CTLBAD=""
O="$R/out/ctl"
for _a in a0 $STUB_ARMS $ORIENT_ARMS; do
  _arm="A0"; case "$_a" in a1:*) _arm="A1-${_a#a1:}" ;; a0) _arm=A0 ;; *) _arm="$(printf '%s' "$_a" | tr 'a-z' 'A-Z')"; _arm="${_arm/A4A/A4a}"; _arm="${_arm/A4B/A4b}" ;; esac
  if _why="$(judge "$_a")"; then ok "$(arm_text "$_a")"; else bad "$(arm_text "$_a") — FAILED: $_why"; CTLBAD="$CTLBAD $_arm"; fi
done
if [ "$H1_STATE" = on ]; then
  if [ "$(armv ctl H1)" = 0 ]; then
    ok "H1 a world with an unregistered ai-dlc hook renders byte-identically twice, names the hook, and --verify returns 0"
  else
    bad "H1 the unregistered-hook world: identical/verify/named = $(cat "$R/out/ctl/H1.v" 2>/dev/null), want 'yes 0 yes' — the FIX line is not stable, so --verify fails on every render of this state"; CTLBAD="$CTLBAD H1"
  fi
fi
a8_judge_s "$R/out/ctl" && ok "A8 a STABLE-only differential renders its site's population definition in one line, not 'none'" \
  || { bad "A8 a STABLE-only differential rendered [$(head -2 "$R/out/ctl/A8.s" | tr '\n' '|' | cut -c1-160)], want its population line"; CTLBAD="$CTLBAD A8"; }
a8_judge_b "$R/out/ctl" && ok "A8 beside a STABLE row, the RECLASSIFIES row renders byte-for-byte as before (status, subject, whole detail)" \
  || { bad "A8 the mixed render was [$(tr '\n' '|' < "$R/out/ctl/A8.b" | cut -c1-200)]"; CTLBAD="$CTLBAD A8"; }
[ -f "$R/out/ctl/A9.live" ] && bad "A9 FIXTURE BROKEN: the shipping region carries the live count, so the cell cannot separate the projections"
if [ "$(armv ctl A9)" = 0 ]; then
  ok "A9 a STABLE row's region survives a corpus write between approve and verify (verify rc 0 before and after; control rc 0 before)"
else
  bad "A9 verify before/after the corpus write read [$(cat "$R/out/ctl/A9.v" 2>/dev/null)], want [0 0]"; CTLBAD="$CTLBAD A9"
fi
if [ "$R6_ON" = 1 ]; then
  for _j in appr score stub; do [ -f "$R6/ship.$_j.done" ] || bad "R6 scenario ship.$_j never completed"; done
  [ "$(armv ctl R6APPR)" = 0 ] \
    && ok "R6 approve: a one-shot orientation failure at approve is retried away — E3 on V-N scores its recorded kill verdict 3|BLOCKERS-RESOLVED|1|1|0|0, nothing reads FIXTURE BROKEN, and the seed's own retired-layer-token refusal (the derived baseline) is kept without a retry" \
    || { bad "R6 approve: fired=$([ -d "$R6/ship.appr.fired" ] && echo y || echo n) bad=[$(head -1 "$R6/ship.appr.bad" 2>/dev/null)] E3 cell=[$(r6f ship.appr.cell)] baseline-refusals=$(r6f ship.appr.base), want fired, no bad, 3|BLOCKERS-RESOLVED|1|1|0|0, 1"; CTLBAD="$CTLBAD R6APPR"; }
  [ "$(armv ctl R6SCORE)" = 0 ] \
    && ok "R6 score: a one-shot orientation failure while --verify scores V-HC is re-scored away — the cell stays 1|UNDECIDED|0|0|0|0" \
    || { bad "R6 score: fired=$([ -d "$R6/ship.score.fired" ] && echo y || echo n) broken=[$(r6f ship.score.broken)] cell=[$(r6f ship.score.cell)], want fired, none, 1|UNDECIDED|0|0|0|0"; CTLBAD="$CTLBAD R6SCORE"; }
  [ "$(armv ctl R6STUB)" = 0 ] \
    && ok "R6 score: a program built by v_stub keeps its OWN sibling's refusal as the world's subject — V-HB scores 1|UNDECIDED|0|0|1|0, unmarked" \
    || { bad "R6 score: V-HB under its stub scored [$(r6f ship.stub.cell)] broken=[$(r6f ship.stub.broken)]"; CTLBAD="$CTLBAD R6STUB"; }
fi
CTLBAD="${CTLBAD# }"
mrow() { matrix_row "$1" "$2" 0 "$3" "$4"; MATRIX_ROWS=$((MATRIX_ROWS + 1)); } # <id> <arm> <GREEN|TRIPPED> <yes|no>
mx_cells() { # <id> <program>
  local a v
  for a in $ARMS_ALL; do
    v="$(armv "$2" "$a")"
    case "$v" in 0) mrow "$1" "$a" GREEN no ;; 1) mrow "$1" "$a" TRIPPED yes ;; *) bad "$1: arm $a on program $2 never ran" ;; esac
  done
}
B_MX0=0
if [ -z "$CTLBAD" ]; then
  B_MX0=1
  [ "$MATRIX" -eq 1 ] && mx_cells MX0 ctl
  ok "CONTROL MX0 (unmutated copy): every one of the $(printf '%s\n' $ARMS_ALL | grep -c .) arms HOLDS on it, tripped=[]"
else
  bad "unmutated copy fails [$CTLBAD] -- the harness, not a mutant, is what fails"
fi

# --- VERDICTS: each mutant on its deciding arm and its twin -----------------------------------------
n_scored=0; n_exp=0
while IFS='|' read -r name p dec twin; do
  [ -n "$name" ] || continue
  [ "$name" = h1-unstable ] && [ "$H1_STATE" != on ] && continue
  case "$name" in r6-*) [ "$R6_ON" = 1 ] || continue ;; esac
  n_exp=$((n_exp + 1))
  in_set "$p" "$MUTS $EMUTS $R6MUTS" || continue
  n_scored=$((n_scored + 1))
  [ "$MATRIX" -eq 1 ] && mx_cells "$name" "$p"
  dv="$(armv "$p" "$dec")"; tv="$(armv "$p" "$twin")"
  if [ "$dv" = X ] || [ "$tv" = X ]; then bad "mutant [$name]: deciding [$dec]=$dv or twin [$twin]=$tv never ran"
  elif [ "$dv" = 0 ]; then bad "mutant [$name] SURVIVED its deciding arm [$dec] -- the kill moved; re-measure with --matrix"
  elif [ "$tv" = 1 ]; then bad "mutant [$name]: twin [$twin] FAILS too -- the kill spread past the recorded matrix; re-measure with --matrix"
  elif ! kobs_ok "$name" "$p"; then bad "mutant [$name] tripped [$dec] without its defect's observable -- the kill is the harness's, not the mutation's"
  else
    mutant_killed "$(( B_MX0 && $([ "$(armv ctl "$dec")" = 0 ] && echo 1 || echo 0) && $([ "$(armv ctl "$twin")" = 0 ] && echo 1 || echo 0) ))" "$name" "mutant [$name] KILLED by [$dec]; twin [$twin] holds"
  fi
done <<EOF
$MT
EOF
[ "$n_scored" -eq "$n_exp" ] && ok "all $n_exp mutants were built (anchor count, cmp -s, bash -n) and scored" \
  || bad "only $n_scored of $n_exp mutants were scored — an unbuilt mutant leaves its arm unproven"
_na="$(printf '%s\n' $ARMS_ALL | grep -c .)" || _na=0
if [ "$MATRIX" -eq 0 ]; then
  [ "$MATRIX_ROWS" -eq 0 ] && ok "PLAIN-RUN: no MATRIX row printed -- the full matrix runs only under --matrix" || bad "PLAIN-RUN printed $MATRIX_ROWS MATRIX row(s)"
else
  [ "$MATRIX_ROWS" -eq $(( (n_scored + 1) * _na )) ] && ok "MATRIX: $MATRIX_ROWS rows printed ($_na arms x (every mutant plus MX0))" || bad "MATRIX printed $MATRIX_ROWS rows, expected $(( (n_scored + 1) * _na ))"
fi

# --- A7: THE RACE, FORCED, ON THE ENGINE'S OWN ORIENTATION-DIFF TEXT --------------------------
# The body is cut from emit-report.sh between the THEIRS line and the rc test, so whatever
# spelling ships is what runs.
#
# FORCED, NOT SAMPLED, BECAUSE A SAMPLE COULD NOT DISCRIMINATE. The same `<( )` spelling under 4
# concurrent workers measured 3, 0 and 0 failures in three runs of 2000 calls, and 1, 1, 2 and 9
# in four runs of 10000: a rate of roughly 0.01-0.15% that swings with load, where three expected
# failures at the low end needs ~30000 calls and still passes the unfixed engine by chance. So the
# interleaving is forced instead: `diff` is shadowed by a shell FUNCTION that sleeps before the
# real fork, which lets the process-substitution child exit first. The process-substitution
# spelling then fails EVERY call (`/dev/fd/63: Bad file descriptor`) and a temp-file spelling
# fails none. Two reference bodies prove that split on this machine before the engine's body is
# read, and a counter proves the shadow was the `diff` that ran, so a body that bypasses it
# (`command diff`, `/usr/bin/diff`) cannot pass by never meeting the delay.
#
# A SAMPLED HALF RUNS BESIDE IT, because the brief asks the real race be observed and not only
# modelled: the engine's body and the unfixed `<( )` spelling are interleaved per iteration in
# the same 8 workers, 10000 calls each. Measured on this machine: the unfixed side 3, 5 and 4 of
# 10000 (and 2 and 9 in earlier runs), the fixed side 0 of 30000. So 10000 is the smallest N whose
# expected unfixed count is at least 3; it costs ~12s. An unfixed count of 0 means the load did
# not reach the race on this run, which says NOTHING about the fixed side, so that case prints
# INCONCLUSIVE -- never ok, and not a failure either, since an idle machine is not a defect. The
# forced half above is what carries the arm on such a run.
#
# THE ENGINE'S BODY NEEDS ITS HELPER. Since 0.647.0 the site stages THEIRS into "$_er_tmp" and
# pipes it through `er_pdiff`; both are cut from emit-report.sh here, so the arm drives the
# shipping function and not a restatement of it.
RB="$R/race-body.sh"; RF="$R/race-fn.sh"
awk '/^          echo "    THEIRS \$\{THEIRS\}:\$\{cp\}/ { f = 1; next } f && /^          if .*\$d_rc/ { exit } f' "$EMIT" > "$RB"
# Since BL-360 the THEIRS staging write is `er_stage`, a second helper cut the same way.
awk '/^(er_pdiff|er_stage)\(\) \{/ { f = 1 } f { print } f && /^}$/ { f = 0 }' "$EMIT" > "$RF"
_rbc="$(grep -c 'd_rc=\$?' "$RB")" || _rbc=0
_rfc="$(grep -c '^er_pdiff() {' "$RF")" || _rfc=0
_rsc="$(grep -c '^er_stage() {' "$RF")" || _rsc=0
# A helper is required only when the body CALLS it: an engine whose site diffs inline (the
# `<( )` spelling before 0.647.0) is driven as it is, and must then FAIL the forced half rather
# than stop at a harness refusal. Measured that way against 1f0a81f3's engine.
_rbu="$(grep -c 'er_pdiff' "$RB")" || _rbu=0
_rbs="$(grep -c 'er_stage' "$RB")" || _rbs=0
if [ "$_rbc" -ne 1 ] || { [ "$_rbu" -gt 0 ] && [ "$_rfc" -ne 1 ]; } || { [ "$_rbs" -gt 0 ] && [ "$_rsc" -ne 1 ]; }; then
  bad "A7 HARNESS BROKEN: the cut from emit-report.sh carries $_rbc 'd_rc=\$?' reads (want 1), calls er_pdiff $_rbu time(s) with $_rfc definition(s) cut and er_stage $_rbs time(s) with $_rsc cut — re-anchor the cut, never relax it"
else
  printf 'shared line\nSENTINEL-OURS-ONLY consumer domain class\n' > "$R/race-ours"
  printf '%s\n' 'd="$(diff <(printf '"'"'%s\n'"'"' "$t") "$local_ours" 2>/dev/null)"; d_rc=$?' > "$R/ref-procsub.sh"
  printf '%s\n' '_tf="$(mktemp)"; printf '"'"'%s\n'"'"' "$t" > "$_tf"' \
    'd="$(diff "$_tf" "$local_ours" 2>/dev/null)"; d_rc=$?' 'rm -f "$_tf"' > "$R/ref-tmpfile.sh"
  cat > "$R/race.sh" <<'RACE'
#!/usr/bin/env bash
# race.sh <body> <ours> <iterations> <delay> <calls-file> <fn> -> "<refused> <shadow-calls>"
t="$(printf 'shared line\nSENTINEL-THEIRS-ONLY upstream process class\n')"; local_ours="$2"
. "$6"; _er_tmp="$(mktemp -d)" || exit 3
DELAY="$4"; CALLS="$5"; : > "$CALLS"
diff() { echo x >> "$CALLS"; sleep "$DELAY"; command diff "$@"; }
n=0; i=0
while [ "$i" -lt "$3" ]; do i=$((i+1)); . "$1"; case "$d_rc" in 0|1) : ;; *) n=$((n+1)) ;; esac; done
rm -rf "$_er_tmp"; echo "$n $(grep -c . "$CALLS")"
RACE
  cat > "$R/sample.sh" <<'RACE'
#!/usr/bin/env bash
# sample.sh <body> <ours> <iterations> <fn> <unfixed-ref> -> "<unfixed-refused> <engine-refused>"
t="$(printf 'shared line\nSENTINEL-THEIRS-ONLY upstream process class\n')"; local_ours="$2"
. "$4"; _er_tmp="$(mktemp -d)" || exit 3
a=0; b=0; i=0
while [ "$i" -lt "$3" ]; do i=$((i+1))
  . "$5"; case "$d_rc" in 0|1) : ;; *) a=$((a+1)) ;; esac
  . "$1"; case "$d_rc" in 0|1) : ;; *) b=$((b+1)) ;; esac
done
rm -rf "$_er_tmp"; echo "$a $b"
RACE
  _rp="$(bash "$R/race.sh" "$R/ref-procsub.sh" "$R/race-ours" 5 0.05 "$R/calls.p" "$RF")"
  _rf="$(bash "$R/race.sh" "$R/ref-tmpfile.sh" "$R/race-ours" 5 0.05 "$R/calls.f" "$RF")"
  # THE RACE IS A PROPERTY OF BASH 3.2, NOT OF EVERY BASH. Measured in `bash:5.2` against local
  # 3.2.57 on the same cut bodies: bash 5 holds the substitution's fd open across the call, so the
  # process-substitution reference reads `0 5` there and `5 5` here. A consumer whose PATH resolves
  # a newer bash has no race for this arm to force, which is a fact about that shell and not a
  # broken harness, so that one reading is INCONCLUSIVE. The harness is still BROKEN when the
  # shadow was not the diff that ran (calls != 5) or the temp-file reference refused at all.
  if [ "$_rf" != "0 5" ] || [ "${_rp#* }" != 5 ]; then
    bad "A7 HARNESS BROKEN: the forced interleaving is not measuring what it claims (process-substitution reference '$_rp', want '5 5'; temp-file reference '$_rf', want '0 5'), so the engine's result below would mean nothing"
  elif [ "$_rp" = "0 5" ]; then
    printf '  INCONCLUSIVE  A7 forced: this bash (%s) keeps a process substitution'"'"'s fd open across the call, so the forced interleaving cannot reproduce the bash 3.2 race here and the engine'"'"'s result would discriminate nothing\n' "$BASH_VERSION"
  elif [ "$_rp" != "5 5" ]; then
    bad "A7 HARNESS BROKEN: the process-substitution reference refused ${_rp% *} of 5 under the forced delay, neither every call (bash 3.2) nor none (a bash that holds the fd), so the forcing is not deterministic here"
  else
    _rs="$(bash "$R/race.sh" "$RB" "$R/race-ours" 5 0.05 "$R/calls.s" "$RF")"
    if [ "${_rs#* }" != 5 ]; then
      bad "A7 the engine's orientation diff did not call the shadowed diff (calls: '${_rs#* }', want 5) — it bypasses \`diff\` by path or \`command\`, so this arm cannot reach it; re-point the arm, never relax it"
    elif [ "${_rs% *}" = 0 ]; then
      ok "A7 forced: the engine's orientation diff survives a forced interleaving 5 of 5 (the process-substitution reference fails 5 of 5 and the temp-file reference 0 of 5 under the same delay)"
    else
      bad "A7 forced: the engine's orientation diff refused ${_rs% *} of 5 under a forced interleaving that a temp file survives — an operand is a process substitution whose /dev/fd can close before diff opens it, which under load is the BL-230 transient"
    fi
  fi
  _k=0; while [ "$_k" -lt 8 ]; do _k=$((_k+1)); bash "$R/sample.sh" "$RB" "$R/race-ours" 1250 "$RF" "$R/ref-procsub.sh" > "$R/sample.$_k" & done
  wait
  _ua=0; _ub=0; _k=0
  while [ "$_k" -lt 8 ]; do _k=$((_k+1))
    read -r _x _y < "$R/sample.$_k" 2>/dev/null || { _x=; _y=; }
    case "$_x:$_y" in *[!0-9:]*|:*|*:) _ua=X; break ;; esac
    _ua=$((_ua+_x)); _ub=$((_ub+_y))
  done
  if [ "$_ua" = X ]; then
    bad "A7 HARNESS BROKEN: a sampling worker printed no count, so the sampled half has no reading"
  elif [ "$_ub" -ne 0 ]; then
    bad "A7 sampled: the engine's orientation diff refused $_ub of 10000 calls across 8 concurrent workers (unfixed <( ) beside it: $_ua) — a healthy render can refuse under load"
  elif [ "$_ua" -eq 0 ]; then
    printf '  INCONCLUSIVE  A7 sampled: the unfixed <( ) control failed 0 of 10000 on this run, so the load never reached the race and the engine side'"'"'s 0 of 10000 discriminates nothing (the forced half above carries the arm)\n'
  else
    ok "A7 sampled: across 8 concurrent workers the unfixed <( ) spelling failed $_ua of 10000 and the engine's orientation diff 0 of 10000, interleaved in the same loop"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "emit-report-refusal: PASS"; exit 0; fi
echo "emit-report-refusal: $fails assertion(s) FAILED" >&2
exit 1
