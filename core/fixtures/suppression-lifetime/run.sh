#!/usr/bin/env bash
# suppression-lifetime/run.sh — prove that an operator's permission to proceed past a
# failing check expires, and that a terminal entry cannot close a check that is still red.
#
# THE DEFECT. `RESOLVED` and `OVERRIDDEN` close a QUESTION and name no check. Measured on
# the reference consumer: a `hard_block: true` check failed at two consecutive planning
# gates and the pipeline proceeded past both on a SINGLE operator turn, each passage
# logged as "carried forward, none re-litigated".
#
# THE MECHANISM IS THE LICENCE, NOT THE RE-RUN, AND THAT WAS MEASURED. The first
# specification said the check "goes silent and nothing re-runs it". False: both affected
# checks were emitted at all three of that sprint's gates and read FAIL, FAIL, PASS. So
# arm s3 is the one that carries the release — a suppression whose cause was fixed
# must cost NOTHING, because a check that nags after the failure is gone is the unmeasured
# lint the operator turns off.
#
# THE ARMS WHERE THE COMFORTABLE READING FAILS OPEN:
#   s2. Past expiry with the check STILL failing must FAIL. If this passes, the lifetime is
#      decoration and the release delivers nothing.
#   s4. A SUPPRESSED entry missing its target must be reported MALFORMED. This is the
#      delimiter regression: with an IFS-whitespace delimiter `read` collapses the empty
#      field, every later field shifts left, and malformed input scores as clean.
#   s2 (again). The metrics must be read in BOTH JSON spacings. The real corpus is 47% one form
#      and 53% the other; an extractor anchored to one reads half the file and reports
#      clean over the rest.
#
# SHAPE. A DRIVE is one validator run on one state, captured once per validator copy (stdout, stderr,
# exit status, rows). An ARM is a predicate over captured drives, so two arms asking about the same
# state share one run. The shipping validator evaluates every arm; a mutant is a LONE COPY of the
# validator (it resolves no sibling beside itself, which the unmutated control proves by reproducing
# every verdict from a copy) and per push drives only its DECIDING arm(s) plus one named TWIN.
#
# MUTANT MATRIX. "A mutant fails only its own assertion" (.claude/rules/fixture-mutants.md) is a
# test-quality property, measured ONCE for every mutant against EVERY arm and recorded below; per push
# each mutant runs its deciding arm(s) (must flip) and one twin (must stay green). The matrix is
# re-measured whenever an arm or a mutant is added or changed, with the REMEASURE command below.
# decides= is the minimal set the mutant is about; co-tripping cells are recorded in the comments above, not driven per push.
# a_whitespace_tolerance_dropped also trips 16 further arms in the measured matrix (the metrics reader goes blind, so every lifetime read moves).
# c_ifs_delimiter also trips 35 further arms in the measured matrix (wholesale delimiter break).
# Each mutant's decides cells read 1 and its twin reads 0 in the measured matrix; wide co-trips are listed above.
# k_ts_dropped also trips t18b and t18d in the measured matrix (the dropped ts is seen through three timelines; t18a is the one it targets).
# d_identity_lines_deleted and e_identity_nonce also trip cand in the measured matrix (the candidate-walk identity reads the same block).
# f_attempt_demoted also trips att20 in the measured matrix (the RESOLVED branch world).
# i_join_guard_removed also trips s16, s17 and t18b in the measured matrix (a dropped catalog join moves every join world; s14 is the one it targets).
# w_resolve also trips w7, c1u, c2a and c2x in the measured matrix (each world reaches the skipped resolution).
# w_overridden also trips c1, c2ab and c2ba in the measured matrix (each carries an OVERRIDDEN waiver 6c reads).
# c2_noprepass also trips w7, c2a, c2s and c2x in the measured matrix (the archive and the SUPPRESSED target leave the table with the pre-pass).
# c2_any also trips c2x in the measured matrix (any FAIL_WAIVED stands down, so the expired archived suppression does too).
# MUTANT-MATRIX k_ts_dropped decides=t18a twins=t18c
# MUTANT-MATRIX l_last_ts decides=t18d twins=t18a
# MUTANT-MATRIX a_whitespace_tolerance_dropped decides=s2 twins=cwA_inf
# MUTANT-MATRIX b_catalog_join_dropped decides=s6 twins=s2
# MUTANT-MATRIX c_ifs_delimiter decides=s4m twins=sen_F
# MUTANT-MATRIX d_identity_lines_deleted decides=ident twins=s1
# MUTANT-MATRIX e_identity_nonce decides=ident twins=s1
# MUTANT-MATRIX f_attempt_demoted decides=att17a,att17b,att17c twins=s2
# MUTANT-MATRIX g_cwd_first_regression decides=cwA_gates,cwA_inf,cwA_met,cwA_agree,c31,cwB_note,cwB_inf,cwB_gates twins=cwA_root
# MUTANT-MATRIX h_cwd_fallback_after_root decides=cwB_note,cwB_inf,cwB_gates,c31 twins=cwA_gates
# MUTANT-MATRIX i_join_guard_removed decides=s14 twins=s15
# MUTANT-MATRIX j_join_hardcoded_core decides=s17 twins=s14
# MUTANT-MATRIX m_revert decides=sen_A,sen_B,sr_Eg twins=sen_C
# MUTANT-MATRIX m_zero_records decides=sen_D twins=sen_A
# MUTANT-MATRIX m_hoist decides=sen_F,sr_Ei twins=sen_A
# MUTANT-MATRIX r_revert_all decides=sr_Ag,sr_Ai,sr_Bg,sr_Bi,sr_Cg,sr_Dg,sr_Di twins=sr_Fg
# MUTANT-MATRIX r_nonregular decides=sr_Bg,sr_Bi,sr_Cg twins=sr_Ag
# MUTANT-MATRIX r_no_symlink decides=sr_Cg twins=sr_Bg
# MUTANT-MATRIX r_rc decides=sr_Ag,sr_Ai,sr_Dg,sr_Di twins=sr_Eg
# MUTANT-MATRIX r_readable_never decides=sr_Ag,sr_Ai twins=sr_Dg
# MUTANT-MATRIX r_readable_always decides=sr_Dg,sr_Di twins=sr_Ag
# MUTANT-MATRIX w_standdown decides=wsd twins=w1
# MUTANT-MATRIX w_resolve decides=w5 twins=w1
# MUTANT-MATRIX w_lifetime decides=w4 twins=s2
# MUTANT-MATRIX w_overridden decides=w3,w1 twins=w4
# MUTANT-MATRIX c1_revert decides=c1,c1b,c1u twins=w4
# MUTANT-MATRIX c2_exact decides=c2ab,c2ba,c2a,c2s twins=c2u
# MUTANT-MATRIX c2_any decides=c2u,c2r,c2m twins=c2ab
# MUTANT-MATRIX c2_resolved decides=w2 twins=c2u
# MUTANT-MATRIX c2_noprepass decides=c2ba twins=c2ab
# MUTANT-MATRIX c2_nolife decides=c2x twins=c2s
# MUTANT-MATRIX-DYNAMIC mutant-loop why=the per-push mutant loop passes ${MN[$mut_i]} from the defm table; every defm name has its own MUTANT-MATRIX row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/suppression-lifetime/run.sh --matrix
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a validator while inheriting them tests the CONFIG, not the code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

[ -f "$VALIDATOR" ] && echo "HERMETIC-CONSUMED $VALIDATOR"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# --matrix is an ARGV flag (never an env var, never via hermetic-run.sh): it replaces the per-push
# mutant stage with the full mutant x arm matrix. A plain run executes no matrix-only cell.
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
MX_FULL_RUNS=0     # incremented ONLY by matrix-only cells; a plain run must leave it at 0
DRIVES=0           # validator runs actually executed (the cost this fixture is held to)
if [ "$MATRIX" = 1 ]; then echo "MODE FULL (--matrix)"; else echo "MODE PUSH"; fi

# ---- fixed inputs the drives share ------------------------------------------------------------
# 18d: every seeded timeline above is written in ASCENDING ts order, so "the newest row" and "the
# last row read" are the same row there and a reader printing the last-seen ts passes 18a and 18b. The
# real file is appended by a lead per gate but nothing orders it. Reversed, the two readings name
# different rows; MUTANT l-last-ts is that reader.
GM_REV="$WORK/gm-failing-reversed.jsonl"
awk '{ l[NR] = $0 } END { for (i = NR; i >= 1; i--) print l[i] }' "$GM_FAILING" > "$GM_REV"
if cmp -s "$GM_FAILING" "$GM_REV"; then bad "FIXTURE BROKEN: the reversed timeline is byte-identical to the original — 18d cannot discriminate"; fi

# THE IDENTITY CORPORA (arm ident): two mktemp trees holding the same bytes, all FOUR inputs each.
sl_ident_corpus() {
  local d
  d="$(mktemp -d "$WORK/ident.XXXXXX")" || return 1
  cp "$CASES/in-force/pending.md" "$d/pending.md"    || return 1
  cp "$MAP"                       "$d/catalog.yaml"  || return 1
  cp "$GM_FAILING"                "$d/gm.jsonl"      || return 1
  # THE BASELINE IS DELIBERATELY VERDICT-NEUTRAL: `$BASELINE_GOOD` baselines the terminal-names-failing
  # key; against the in-force case that key does not reproduce, and arm s13b is the one that makes a
  # non-reproducing baseline a FAIL. A baseline with no rows is still OPENED, resolved and named.
  printf '# no baselined violations\n' > "$d/baseline.txt"
  printf '%s\n' "$d"
}
# THE CANDIDATE-WALK CORPORA (arm cand): a root whose catalog is DISCOVERABLE, never passed.
sl_cand_corpus() {
  local d
  d="$(mktemp -d "$WORK/cand.XXXXXX")" || return 1
  mkdir -p "$d/core/skills/ai-dlc" || return 1
  cp "$MAP" "$d/core/skills/ai-dlc/enforcement-map.yaml" || return 1
  cp "$CASES/in-force/pending.md" "$d/pending.md" || return 1
  printf '%s\n' "$d"
}
IDA="$(sl_ident_corpus)" || { echo "FIXTURE ERROR: could not build identity corpus A" >&2; exit 2; }
IDB="$(sl_ident_corpus)" || { echo "FIXTURE ERROR: could not build identity corpus B" >&2; exit 2; }
CDA="$(sl_cand_corpus)"  || { echo "FIXTURE ERROR: could not build candidate corpus A" >&2; exit 2; }
CDB="$(sl_cand_corpus)"  || { echo "FIXTURE ERROR: could not build candidate corpus B" >&2; exit 2; }

SL_A_GM="$SL_CWD_A_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
SL_A_DECOY_GM="$SL_CWD_A_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl"

# THE REFUSAL SEEDS (arms sr_*): an UNREADABLE or NON-REGULAR escalations path refuses in BOTH modes.
SR="$WORK/refusal"; mkdir -p "$SR"
SR_LOCKED="$SR/pending-locked.md"; cp "$CASES/expired-still-failing/pending.md" "$SR_LOCKED"; chmod 000 "$SR_LOCKED"
SR_DIR="$SR/pending-dir.md"; mkdir -p "$SR_DIR"
SR_LINK="$SR/pending-dangling.md"; ln -s "$SR/pending-target-never-written.md" "$SR_LINK"
SR_IO="$SR/pending-io.md"; cp "$CASES/expired-still-failing/pending.md" "$SR_IO"
SR_SKIP_A=""
if [ "$(id -u)" -eq 0 ]; then SR_SKIP_A="running as root, which reads a mode-000 file"
elif cat "$SR_LOCKED" >/dev/null 2>&1; then SR_SKIP_A="this host reads a mode-000 file, so the seed cannot express unreadable"; fi
[ -n "$SR_SKIP_A" ] && printf '  SKIP  refusal arms sr_Ag/sr_Ai (mode-000 file) -- %s\n' "$SR_SKIP_A"
if ! { [ -L "$SR_LINK" ] && [ ! -e "$SR_LINK" ]; }; then bad "FIXTURE BROKEN: the dangling-symlink seed is not a link to a missing target"; fi
SR_STUB="$SR/stub"; mkdir -p "$SR_STUB"
SR_REALGREP="$(command -v grep)" || { echo "FIXTURE ERROR: grep is not on PATH" >&2; exit 2; }
{
  printf '#!/bin/sh\ncase "$*" in\n'
  printf '  %s) printf "x\\n" >> "%s/LOG"; echo "grep: forced failure" >&2; exit 2 ;;\n' "'-q [^[:space:]] '*" "$SR_STUB"
  printf 'esac\nexec "%s" "$@"\n' "$SR_REALGREP"
} > "$SR_STUB/grep"
chmod +x "$SR_STUB/grep"

# ---- the drive cache --------------------------------------------------------------------------
VP=()   # validator key -> path
O=""; E=""; RC=""; X=""
sl_field() { printf '%s\n' "$DV_O" | sed -n "s/.*[[:space:]]$1=\([^[:space:]]*\).*/\1/p" | tail -1; }
drive_run() { # <validator path> <drive> -> O E RC X
  local v="$1" d="$2" c="" gm="" ex="" m="" p="$PATH" f="" root="" cwd="" esc="" rows
  O=""; E=""; RC=""; X=""
  DRIVES=$((DRIVES+1))
  case "$d" in
    inforce) c=in-force; gm="$GM_FAILING" ;;
    exp)     c=expired-still-failing; gm="$GM_FAILING" ;;
    fixed)   c=expired-but-fixed; gm="$GM_FIXED" ;;
    mal)     c=malformed-no-target; gm="$GM_FAILING" ;;
    range)   c=expiry-out-of-range; gm="$GM_FAILING" ;;
    unk)     c=unknown-check-id; gm="$GM_FAILING" ;;
    tnf)     c=terminal-names-failing; gm="$GM_FAILING" ;;
    tnp)     c=terminal-names-passing; gm="$GM_FAILING" ;;
    empty)   c=empty; gm="$GM_FAILING" ;;
    bgood)   c=terminal-names-failing; gm="$GM_FAILING"; ex="--baseline $BASELINE_GOOD" ;;
    bstale)  c=terminal-names-failing; gm="$GM_FAILING"; ex="--baseline $BASELINE_STALE" ;;
    cc)      c=collide-core; gm="$GM_COLLIDE" ;;
    ccon)    c=collide-control; gm="$GM_COLLIDE" ;;
    cb)      c=collide-bare; gm="$GM_COLLIDE" ;;
    ce)      c=collide-ext; gm="$GM_COLLIDE_EXT" ;;
    ccone)   c=collide-control; gm="$GM_COLLIDE_EXT" ;;
    rev)     c=expired-still-failing; gm="$GM_REV" ;;
    att1)    c=attempt-first-token; gm="$GM_FAILING" ;;
    attw)    c=attempt-word-only; gm="$GM_FAILING" ;;
    attc)    c=attempt-corrected; gm="$GM_FAILING" ;;
    attu)    c=attempt-under-terminal; gm="$GM_FAILING" ;;
    wm_ovr)  c=waiver-match; gm="$GM_W_OVR" ;;
    wm_fail) c=waiver-match; gm="$GM_FAILING" ;;
    wo)      c=waiver-other-entry; gm="$GM_W_OTHER" ;;
    wsup1)   c=waiver-suppressed-expired; gm="$GM_W_SUP1" ;;
    wsup3)   c=waiver-suppressed-inforce; gm="$GM_W_SUP3" ;;
    wnone)   c=waiver-wrong-status; gm="$GM_W_NONE" ;;
    wdec)    c=waiver-wrong-status; gm="$GM_W_DEC" ;;
    warch)   c=waiver-archived; gm="$GM_W_ARCH" ;;
    wempty)  c=waiver-match; gm="$GM_W_EMPTY" ;;
    c1)      c=c1-other-waiver; gm="$GM_W_C2" ;;
    c1b)     c=c1-other-waiver; gm="$GM_W_C2"; ex="--baseline $BASELINE_EXP32" ;;
    c1u)     c=c1-unresolvable; gm="$GM_W_C2" ;;
    c2ab)    c=c2-waiver-above; gm="$GM_W_C2" ;;
    c2ba)    c=c2-waiver-below; gm="$GM_W_C2" ;;
    c2a)     c=c2-archived; gm="$GM_W_C2" ;;
    c2s)     c=c2-suppressed-32; gm="$GM_W_C2" ;;
    c2x)     c=c2-archived-expired; gm="$GM_W_C2" ;;
    c2u)     c=c2-unresolvable; gm="$GM_W_C2" ;;
    c2r)     c=c2-resolved; gm="$GM_W_C2" ;;
    c2m)     c=c2-mistargeted; gm="$GM_W_C2" ;;
    wsd)     c=own-standdown; gm="$GM_W_SD" ;;
  esac
  case "$d" in
    nocat)
      O="$(bash "$v" --escalations "$CASES/expired-still-failing/pending.md" \
            --gate-metrics "$GM_FAILING" --enforcement-map "$WORK/nope.yaml" 2>&1)"; RC=$? ;;
    nomet)
      O="$(bash "$v" --escalations "$CASES/malformed-no-target/pending.md" \
            --enforcement-map "$MAP" --gate-metrics "$WORK/absent.jsonl" 2>&1)"; RC=$? ;;
    ident_a|ident_b)
      f="$IDA"; [ "$d" = ident_b ] && f="$IDB"
      O="$(bash "$v" --escalations "$f/pending.md" --gate-metrics "$f/gm.jsonl" \
            --enforcement-map "$f/catalog.yaml" --baseline "$f/baseline.txt" 2>&1)"; RC=$? ;;
    cand_a|cand_b)
      f="$CDA"; [ "$d" = cand_b ] && f="$CDB"
      O="$(AI_DLC_PROJECT_ROOT="$f" bash "$v" --escalations "$f/pending.md" --gate-metrics "$GM_FAILING" 2>&1)"; RC=$? ;;
    cwA_decoy|cwA_root|cwB_decoy)
      case "$d" in
        cwA_decoy) root="$SL_CWD_A_ROOT"; cwd="$SL_CWD_A_DECOY" ;;
        cwA_root)  root="$SL_CWD_A_ROOT"; cwd="$SL_CWD_A_ROOT" ;;
        cwB_decoy) root="$SL_CWD_B_ROOT"; cwd="$SL_CWD_B_DECOY" ;;
      esac
      # No --gate-metrics and no --enforcement-map: the resolution under test is the one the two real
      # callers use. The catalog is seeded at the ROOT-anchored candidate, so a run that never
      # received AI_DLC_PROJECT_ROOT refuses rather than answering from somewhere else.
      rows="$WORK/inforce.rows"
      O="$( cd "$cwd" && AI_DLC_PROJECT_ROOT="$root" bash "$v" --in-force --escalations "$root/pending.md" 2>&1 >"$rows" )"; RC=$?
      X="$(grep -c . "$rows")" || X=0 ;;
    sen_empty|sen_blank|sen_never|sen_head|sen_l4|sen_exp)
      case "$d" in
        sen_empty) f=empty-file ;; sen_blank) f=blank-file ;; sen_never) f=never-written ;;
        sen_head) f=heading-only ;; sen_l4) f=level4-entry ;; sen_exp) f=expired-still-failing ;;
      esac
      O="$(AI_DLC_PROJECT_ROOT="$WORK" bash "$v" --escalations "$CASES/$f/pending.md" \
             --gate-metrics "$GM_FAILING" --enforcement-map "$MAP" 2>/dev/null)"; RC=$? ;;
    sen_if)
      E="$( AI_DLC_PROJECT_ROOT="$WORK" bash "$v" --in-force --escalations "$CASES/empty-file/pending.md" \
              --gate-metrics "$GM_FAILING" --enforcement-map "$MAP" 2>&1 >"$WORK/sen-inforce.out" )"; RC=$?
      O="$(cat "$WORK/sen-inforce.out")" ;;
    sr_lock_g|sr_lock_i|sr_dir_g|sr_dir_i|sr_link_g|sr_io_g|sr_io_i|sr_blank_g|sr_blank_i|sr_exp_g)
      case "$d" in
        sr_lock_g)  f="$SR_LOCKED" ;;
        sr_lock_i)  f="$SR_LOCKED"; m="--in-force" ;;
        sr_dir_g)   f="$SR_DIR" ;;
        sr_dir_i)   f="$SR_DIR"; m="--in-force" ;;
        sr_link_g)  f="$SR_LINK" ;;
        sr_io_g)    f="$SR_IO"; p="$SR_STUB:$PATH" ;;
        sr_io_i)    f="$SR_IO"; m="--in-force"; p="$SR_STUB:$PATH" ;;
        sr_blank_g) f="$CASES/blank-file/pending.md" ;;
        sr_blank_i) f="$CASES/blank-file/pending.md"; m="--in-force" ;;
        sr_exp_g)   f="$CASES/expired-still-failing/pending.md" ;;
      esac
      : > "$SR_STUB/LOG"
      O="$(PATH="$p" AI_DLC_PROJECT_ROOT="$WORK" bash "$v" $m --escalations "$f" \
            --gate-metrics "$GM_FAILING" --enforcement-map "$MAP" 2>"$SR/err")"; RC=$?
      E="$(cat "$SR/err")"
      X=0; [ -s "$SR_STUB/LOG" ] && X=1 ;;
    *)
      O="$(bash "$v" --escalations "$CASES/$c/pending.md" --gate-metrics "$gm" \
            --enforcement-map "$MAP" $ex 2>&1)"; RC=$? ;;
  esac
}
DV_O=""; DV_E=""; DV_RC=""; DV_X=""
dv() { # <validator key> <drive> -> DV_O DV_E DV_RC DV_X, running the validator at most once per (key, drive)
  local rn="C_${1}_${2}_R" on="C_${1}_${2}_O" en="C_${1}_${2}_E" xn="C_${1}_${2}_X"
  if [ -z "${!rn+x}" ]; then
    drive_run "${VP[$1]}" "$2"
    printf -v "$on" '%s' "$O"; printf -v "$en" '%s' "$E"; printf -v "$xn" '%s' "$X"; printf -v "$rn" '%s' "$RC"
  fi
  DV_O="${!on}"; DV_E="${!en}"; DV_X="${!xn}"; DV_RC="${!rn}"
}
has()  { grep -q  -- "$1" <<<"$DV_O"; }
hasF() { grep -qF -- "$1" <<<"$DV_O"; }
SL_TS_WHY=""
sl_names_ts() { # <want-ts> <unwanted-ts> -- reads DV_O
  SL_TS_WHY=""
  grep -qF "ts $1 in " <<<"$DV_O" || { SL_TS_WHY="no 'ts $1 in' in the message"; return 1; }
  if [ -n "$2" ] && grep -qF "ts $2 in " <<<"$DV_O"; then SL_TS_WHY="names $2 too"; return 1; fi
  grep -qF "PREVIOUS" <<<"$DV_O" || { SL_TS_WHY="does not say the source is the PREVIOUS gate"; return 1; }
  return 0
}
w_quiet() { [ "$DV_RC" = "0" ] && grep -qF "waived_rows=$1 " <<<"$DV_O"; }

# ---- the metrics-resolution block (arm c31 and mutants g, h) ------------------------------------
SL_SEC2='# ---- 2. Locate gate-metrics'
sl_sec2_block() { # <file> -> the section-2 resolution block, header through its closing `fi`
  awk -v A="$SL_SEC2" '
    st==0 && index($0, A) { st=1; next }
    st==1 && $0 == "fi"   { st=2; next }
    st==1                 { print }
  ' "$1"
}
sl_cwd_cands() { # <file> -> how many candidates in that block are CWD-RELATIVE
  local n; n="$(sl_sec2_block "$1" | grep -c '^ *"\(_bmad-output\|docs/_bmad-output\)/')" || n=0
  printf '%s' "$n"
}

# ===== THE ARMS ===================================================================================
# Each arm is `ar_<id> <validator key>`: 0 = holds, 1 = does not hold. They read cached drives.
ar_s1()  { dv "$1" inforce; [ "$DV_RC" = 0 ]; }
ar_s2()  { dv "$1" exp; [ "$DV_RC" = 1 ]; }
ar_s2m() { dv "$1" exp; has 'past its lifetime'; }
ar_s3()  { dv "$1" fixed; [ "$DV_RC" = 0 ]; }
ar_s4()  { dv "$1" mal; [ "$DV_RC" = 1 ]; }
ar_s4m() { dv "$1" mal; has 'Suppresses'; }
ar_s5()  { dv "$1" range; [ "$DV_RC" = 1 ]; }
ar_s6()  { dv "$1" unk; [ "$DV_RC" = 1 ]; }
ar_s7()  { dv "$1" tnf; [ "$DV_RC" = 1 ]; }
ar_s8()  { dv "$1" tnp; [ "$DV_RC" = 0 ]; }
ar_s9()  { dv "$1" empty; [ "$DV_RC" = 0 ] && has 'entries_scanned='; }
ar_s9z() { dv "$1" empty; has 'suppressed=0'; }
ar_s11() { dv "$1" nocat; [ "$DV_RC" = 2 ]; }
ar_s12() { dv "$1" nomet; [ "$DV_RC" = 1 ]; }
ar_s13a() { dv "$1" bgood; [ "$DV_RC" = 0 ]; }
ar_s13b() { dv "$1" bstale; [ "$DV_RC" = 1 ] && has 'no longer reproduces'; }
ar_s14() { dv "$1" cc; [ "$DV_RC" = 1 ] && has "STILL FAILING"; }
ar_s15() { dv "$1" ccon; [ "$DV_RC" = 1 ]; }
ar_s16() { dv "$1" cb; [ "$DV_RC" = 1 ]; }
ar_s17() { dv "$1" ce; [ "$DV_RC" = 1 ] && has "STILL FAILING"; }
ar_s18() { dv "$1" ccone; [ "$DV_RC" = 1 ]; }
ar_t18a() { dv "$1" exp; [ "$DV_RC" = 1 ] && sl_names_ts "$G3" "$G2"; }
ar_t18b() { dv "$1" cc; [ "$DV_RC" = 1 ] && sl_names_ts "$G2" "$G3"; }
ar_t18c() { dv "$1" tnf; [ "$DV_RC" = 1 ] && has "recorded FAILING"; }
ar_t18d() { dv "$1" rev; [ "$DV_RC" = 1 ] && sl_names_ts "$G3" "$G1"; }
ar_ident() { # the OK verdict names all four inputs and two identical corpora are distinguishable
  local oa ob
  dv "$1" ident_a; oa="$DV_O"; [ "$DV_RC" = 0 ] || return 1
  dv "$1" ident_b; ob="$DV_O"; [ "$DV_RC" = 0 ] || return 1
  # THE EMITTER TOKEN IS THE ONE UNIQUE TO THIS LINE, NOT `OK: entries_scanned=`: two `OK:` emitters
  # share that prefix and BL-078 inserted `EXAMINED NOTHING — ` between `OK: ` and `entries_scanned=`.
  grep -qF 'no suppression is past its lifetime' <<<"$oa" || return 1
  [ "$oa" != "$ob" ] || return 1
  grep -qF "$IDA/pending.md" <<<"$oa" && grep -qF "$IDA/catalog.yaml" <<<"$oa" \
    && grep -qF "$IDA/gm.jsonl" <<<"$oa" && grep -qF "$IDA/baseline.txt" <<<"$oa" || return 1
  grep -qF "$IDB/pending.md" <<<"$ob" && grep -qF "$IDB/catalog.yaml" <<<"$ob" \
    && grep -qF "$IDB/gm.jsonl" <<<"$ob" && grep -qF "$IDB/baseline.txt" <<<"$ob" || return 1
  ! grep -qF "$IDB" <<<"$oa"
}
ar_cand() { # the RESOLVED catalog, not the one an argument named
  local oa ob
  dv "$1" cand_a; oa="$DV_O"; [ "$DV_RC" = 0 ] || return 1
  dv "$1" cand_b; ob="$DV_O"; [ "$DV_RC" = 0 ] || return 1
  grep -qF 'no suppression is past its lifetime' <<<"$oa" || return 1
  [ "$oa" != "$ob" ] || return 1
  grep -qF "$CDA/core/skills/ai-dlc/enforcement-map.yaml" <<<"$oa" \
    && grep -qF "$CDB/core/skills/ai-dlc/enforcement-map.yaml" <<<"$ob"
}
ar_att17a() { dv "$1" att1; [ "$DV_RC" = 1 ]; }
ar_att17b() { dv "$1" att1; has "Parsed \*\*Status:\*\* as 'DECIDED_AUTONOMOUSLY'"; }
ar_att17c() { dv "$1" att1; has 'malformed_attempt=1'; }
ar_att18()  { dv "$1" attw; [ "$DV_RC" = 0 ] && has 'malformed_attempt=0'; }
ar_att19()  { dv "$1" attc; [ "$DV_RC" = 0 ] && has 'suppressed=1' && has 'malformed_attempt=0'; }
ar_att20()  { dv "$1" attu; [ "$DV_RC" = 1 ] && has 'malformed_attempt=1'; }
ar_cwA_gates() { dv "$1" cwA_decoy; [ "$(sl_field gates_recorded)" = "2" ]; }
ar_cwA_inf()   { dv "$1" cwA_decoy; [ "$(sl_field in_force)" = "1" ] && [ "$DV_X" = "1" ]; }
ar_cwA_met()   { dv "$1" cwA_decoy; [ "$(sl_field metrics)" = "$SL_A_GM" ]; }
ar_cwA_agree() {
  local g i
  dv "$1" cwA_decoy; g="$(sl_field gates_recorded)"; i="$(sl_field in_force)"
  dv "$1" cwA_root;  [ "$g" = "$(sl_field gates_recorded)" ] && [ "$i" = "$(sl_field in_force)" ]
}
ar_cwA_root()  { dv "$1" cwA_root; [ "$(sl_field gates_recorded)" = "2" ] && [ "$(sl_field in_force)" = "1" ]; }
ar_cwB_note()  { dv "$1" cwB_decoy; has 'no gate-metrics.jsonl was found'; }
ar_cwB_inf()   { dv "$1" cwB_decoy; [ "$(sl_field in_force)" = "0" ] && [ "$DV_X" = "0" ]; }
ar_cwB_gates() { dv "$1" cwB_decoy; [ "$(sl_field gates_recorded)" = "NONE" ]; }
ar_c31() { [ "$(sl_cwd_cands "${VP[$1]}")" = "0" ]; }
# ---- the empty-file cells (A..F) ----------------------------------------------------------------
ar_sen_A() { dv "$1" sen_empty; [ "$DV_RC" -eq 0 ] && hasF "EXAMINED NOTHING" && hasF "present but empty"; }
ar_sen_B() { dv "$1" sen_blank; [ "$DV_RC" -eq 0 ] && hasF "EXAMINED NOTHING" && hasF "present but empty"; }
ar_sen_C() { dv "$1" sen_never; [ "$DV_RC" -eq 0 ] && hasF "EXAMINED NOTHING" && hasF "no escalations file" && ! hasF "present but empty"; }
ar_sen_D() {
  local o1 r1
  dv "$1" sen_head; o1="$DV_O"; r1="$DV_RC"
  dv "$1" sen_l4
  [ "$r1" -eq 0 ] && [ "$DV_RC" -eq 0 ] && ! hasF "EXAMINED NOTHING" && ! grep -qF "EXAMINED NOTHING" <<<"$o1" \
    && grep -qF "OK: entries_scanned=0 " <<<"$o1" && hasF "OK: entries_scanned=0 "
}
ar_sen_E() { dv "$1" sen_exp; [ "$DV_RC" -eq 1 ]; }
ar_sen_F() { dv "$1" sen_if; [ "$DV_RC" -eq 0 ] && [ -z "$DV_O" ] && grep -q '^IN-FORCE: entries_scanned=0 ' <<<"$DV_E" \
              && ! grep -qF "EXAMINED NOTHING" <<<"$DV_O$DV_E"; }
# ---- the refusal cells --------------------------------------------------------------------------
sr_refused() { [ "$DV_RC" -eq 2 ] && [ -z "$DV_O" ] && grep -qE "^REFUSED: .*$1" <<<"$DV_E"; }
ar_sr_Ag() { dv "$1" sr_lock_g; sr_refused 'could not be read'; }
ar_sr_Ai() { dv "$1" sr_lock_i; sr_refused 'could not be read'; }
ar_sr_Bg() { dv "$1" sr_dir_g; sr_refused 'is not a regular file'; }
ar_sr_Bi() { dv "$1" sr_dir_i; sr_refused 'is not a regular file'; }
ar_sr_Cg() { dv "$1" sr_link_g; sr_refused 'is not a regular file'; }
ar_sr_Dg() { dv "$1" sr_io_g; [ "$DV_X" = 1 ] && sr_refused 'failed \(grep exited 2\)'; }
ar_sr_Di() { dv "$1" sr_io_i; [ "$DV_X" = 1 ] && sr_refused 'failed \(grep exited 2\)'; }
ar_sr_Eg() { dv "$1" sr_blank_g; [ "$DV_RC" -eq 0 ] && hasF 'present but empty' && ! grep -qF REFUSED <<<"$DV_O$DV_E"; }
ar_sr_Ei() { dv "$1" sr_blank_i; [ "$DV_RC" -eq 0 ] && [ -z "$DV_O" ] && grep -q '^IN-FORCE: entries_scanned=0 ' <<<"$DV_E" && ! grep -qF REFUSED <<<"$DV_E"; }
ar_sr_Fg() { dv "$1" sr_exp_g; [ "$DV_RC" -eq 1 ] && ! grep -qF REFUSED <<<"$DV_O$DV_E"; }
# ---- the waived verdict (W1..W8) ----------------------------------------------------------------
ar_w1()  { dv "$1" wm_ovr; w_quiet 1; }
ar_w1b() { dv "$1" wm_fail; [ "$DV_RC" = "1" ] && has "recorded FAILING"; }
ar_w2()  { dv "$1" wo; [ "$DV_RC" = "1" ] && has "recorded FAILING" && ! has "names NO entry"; }
ar_w3()  { dv "$1" wm_ovr; w_quiet 1 && [ "$(grep -oE '"ts": *"[^"]*"' "$GM_W_OVR" | sed 's/.*"\([^"]*\)"$/\1/' | sort -u | grep -c .)" -eq 3 ]; }
ar_w4()  {
  local w4a=0
  dv "$1" wsup1; [ "$DV_RC" = "1" ] && has "latest recorded verdict is FAIL_WAIVED" && w4a=1
  dv "$1" wsup3; [ "$w4a" -eq 1 ] && w_quiet 1
}
ar_w5()  { dv "$1" wnone; [ "$DV_RC" = "1" ] && has "which names NO entry"; }
ar_w6()  { dv "$1" wdec; [ "$DV_RC" = "1" ] && has "neither OVERRIDDEN nor SUPPRESSED"; }
ar_w7()  { dv "$1" warch; w_quiet 1 && has "names an entry archived"; }
ar_w8()  { dv "$1" wempty; [ "$DV_RC" = "1" ] && has "with NO waiver_id"; }
# ---- whose waiver is it (C1: the expiry arm; C2: the terminal arm for OVERRIDDEN) ----------------
# Each arm keys on ITS OWN message: C1 on "past its lifetime", C2 on the terminal arm's line for the
# one entry naming Check 32. The quiet arms carry a positive conjunct a silent copy cannot print.
C2_HIT='a OVERRIDDEN entry names check(s) 32,'
# The expiry FAIL's own text: the clean OK line also says "past its lifetime", so the bare phrase
# is present on every quiet run and cannot be the absence token.
C1_MSG='is past its lifetime and the check is'
ar_c1()   { dv "$1" c1;   ! hasF "$C1_MSG" && hasF 'suppressed=1 ' && w_quiet 1; }
ar_c1b()  { dv "$1" c1b;  [ "$DV_RC" = "1" ] && hasF 'no longer reproduces: EXPIRED:32' && ! hasF "$C1_MSG"; }
ar_c1u()  { dv "$1" c1u;  ! hasF "$C1_MSG" && has 'which names NO entry' && hasF 'suppressed=1 '; }
ar_c2ab() { dv "$1" c2ab; ! hasF 'recorded FAILING' && hasF 'terminal_naming_check=0 ' && w_quiet 1; }
ar_c2ba() { dv "$1" c2ba; ! hasF 'recorded FAILING' && hasF 'terminal_naming_check=0 ' && w_quiet 1; }
ar_c2a()  { dv "$1" c2a;  ! hasF 'recorded FAILING' && has 'names an entry archived' && w_quiet 1; }
ar_c2s()  { dv "$1" c2s;  ! hasF 'recorded FAILING' && hasF 'suppressed=1 ' && w_quiet 1; }
ar_c2x()  { dv "$1" c2x;  [ "$DV_RC" = "1" ] && hasF "$C2_HIT" && has 'names an entry archived'; }
ar_c2u()  { dv "$1" c2u;  [ "$DV_RC" = "1" ] && hasF "$C2_HIT"; }
ar_c2r()  { dv "$1" c2r;  [ "$DV_RC" = "1" ] && hasF "$C2_HIT"; }
ar_c2m()  { dv "$1" c2m;  [ "$DV_RC" = "1" ] && hasF "$C2_HIT"; }
ar_wsd()  { dv "$1" wsd;  ! hasF 'recorded FAILING' && has 'neither OVERRIDDEN nor SUPPRESSED'; }

ARMS="s1 s2 s2m s3 s4 s4m s5 s6 s7 s8 s9 s9z s11 s12 s13a s13b s14 s15 s16 s17 s18 t18a t18b t18c t18d ident cand att17a att17b att17c att18 att19 att20 cwA_gates cwA_inf cwA_met cwA_agree cwA_root cwB_note cwB_inf cwB_gates c31 sen_A sen_B sen_C sen_D sen_E sen_F sr_Ag sr_Ai sr_Bg sr_Bi sr_Cg sr_Dg sr_Di sr_Eg sr_Ei sr_Fg w1 w1b w2 w3 w4 w5 w6 w7 w8 c1 c1b c1u c2ab c2ba c2a c2s c2x c2u c2r c2m wsd"

reg() { printf -v "OK_$1" '%s' "$2"; printf -v "BAD_$1" '%s' "$3"; }
reg s1 "a SUPPRESSED entry inside its lifetime does not fire (exit 0)" "in-force suppression FAILED — the arm has no green state and would wedge every gate"
reg s2 "past its lifetime with the check STILL failing, the suppression FAILS
spaced-form metrics rows are read (check 32 is seeded spaced-only)" "expired suppression did NOT fail — the lifetime is decoration, and the spaced JSON form was not read (53% of the real corpus is invisible)"
reg s2m "the expiry message names the lifetime as the reason" "the expiry FAIL did not explain itself"
reg s3 "past its lifetime but the check now PASSes — reports nothing" "expired-but-fixed FAILED — the check nags after the failure is gone"
reg s4 "a SUPPRESSED entry with no **Suppresses:** is MALFORMED" "missing **Suppresses:** was accepted — an empty field collapsed and the later fields shifted left"
reg s4m "the malformed message names the missing field" "malformed FAIL did not name which field was missing"
reg s5 "**Expires after:** outside 1..3 is rejected" "an out-of-range expiry was accepted — a suppression could be written to outlive anything"
reg s6 "a **Suppresses:** id absent from the catalog is rejected" "an unknown check id was accepted — 'Check 924' is a real prose token in the corpus"
reg s7 "a RESOLVED entry naming a still-failing check FAILS — the loophole is shut
18c: the terminal-entry arm still reads the verdict out of the widened row" "RESOLVED closed a still-failing check — this is the measured defect, unfixed (and the terminal-entry arm no longer reads the widened row)"
reg s8 "a RESOLVED entry naming only a PASSING check does not fire" "a terminal entry naming a green check FAILED — every closed entry mentioning a check would trip"
reg s9 "a clean run reports the counts it was computed over" "the clean verdict carries no counts — a regex matching nothing reads like full coverage"
reg s9z "the zero-control distinguishes 'no suppressions' from 'all suppressions valid'" "no suppressed= count in the verdict line"
reg s11 "an unreadable catalog exits 2 — a refusal, never a clean pass" "missing catalog did not refuse — it would act on prose tokens that are not checks"
reg s12 "with no metrics the SHAPE arm still fires on a malformed entry" "no-metrics run did not check shape — the whole script went quiet on a missing optional input"
reg s13a "a baselined violation is suppressed" "the baseline did not suppress its own entry"
reg s13b "a baselined key that stops reproducing is itself a FAIL — the baseline cannot outlive its cause" "a stale baseline line was tolerated — a baseline would silently suppress a check that started passing"
reg s14 "an expired suppression on a still-failing CORE check fires, though a newer extension row PASSes" "the extension row ACQUITTED a core check that is still failing — the fail-open direction of the collision"
reg s15 "the single-catalog control still fires in the colliding timeline (assertion 14 discriminates)" "the single-catalog control stopped firing — assertion 14 proves nothing, the arm just refuses"
reg s16 "a bare id resolves as core and fires identically to the bracketed form" "a bare id stopped resolving — dropping the bracket now buys silence"
reg s17 "an expired suppression on a still-failing EXTENSION check fires, though core's newer row PASSes" "hard-coding the core catalog acquitted a failing extension check — every corpus-drawn seed passes this, only this one separates them"
reg s18 "the single-catalog control fires in the mirrored timeline too (assertion 17 discriminates)" "the control stopped firing in the mirrored timeline"
reg t18a "18a: the expiry FAIL names the ts of the row it read ($G3) and that it is the PREVIOUS gate's verdict" "18a: the expiry FAIL does not name the verdict row's ts — a stale read is illegible"
reg t18b "18b: in the colliding timeline the named ts is core's row ($G2), not the newer extension row" "18b: the named ts is not the row the catalog join selected"
reg t18c "18c: the terminal-entry arm still reads the verdict out of the widened row" "18c: the terminal-entry arm stopped firing — it compares the whole row to FAIL"
reg t18d "18d: with the newest row written FIRST the named ts is still the newest ($G3), not the last read" "18d: the named ts follows file order, not recency"
reg ident "the OK verdict names all four inputs — escalations, catalog, gate metrics and baseline — and two identical corpora in different trees are distinguishable" "the OK verdict carries no corpus identity. A run against last sprint's pending file reports the same green line as one against this sprint's"
reg cand "a catalog found by the CANDIDATE WALK is named in the verdict — the identity is a value the script resolved, not an echo of the arguments it was given" "the discovered catalog is not named"
reg att17a "suppression fields under a status that classifies as something else are REPORTED" "a discarded suppression scored clean — the target, expiry and citation were never examined and nothing said so"
reg att17b "the diagnostic names the token the entry actually classified as" "the diagnostic does not name the parsed status — the author cannot tell which token won"
reg att17c "the verdict line carries malformed_attempt=1 — an attempted-and-dropped suppression is no longer indistinguishable from none" "no malformed_attempt count in the verdict line — 'one attempted and dropped' still prints what 'none attempted' prints"
reg att18 "a status line NAMING another disposition in prose, with no suppression fields, stays silent" "the arm fired on a status line's prose — it is keyed on the line, not on the fields, and the corpus is full of 'not a HARD_BLOCK'"
reg att19 "the same fields under a status that DOES classify SUPPRESSED are adjudicated, not flagged" "a well-formed suppression was flagged — the arm is keyed on the fields alone and every real suppression trips it"
reg att20 "suppression fields under RESOLVED are reported — the arm is not the case's else" "a discard under a status WITH its own branch went unreported — the arm sits inside the case and cannot reach it"
reg cwA_gates "world A: from a cwd whose own timeline records 9 gates, gates_recorded=2 — the ROOT's timeline was counted" "world A: gates_recorded is not 2 from the decoy cwd — the lifetime was counted against the cwd project's gate history"
reg cwA_inf "world A: the entry is listed in force from the decoy cwd (in_force=1, one row on stdout)" "world A: the entry is not in force with one row from the decoy cwd — a live licence was expired by a stranger's timeline"
reg cwA_met "world A: the verdict NAMES the root's metrics file as the one it read" "world A: the verdict does not name the root's metrics file — the resolved timeline is not the root's"
reg cwA_agree "world A: the decoy-cwd run and the root-cwd control AGREE — the answer does not depend on the cwd" "world A: cwd-dependent answer — the decoy and the root gave different gates_recorded/in_force"
reg cwA_root "world A: the root-cwd run answers gates_recorded=2 in_force=1 — the near-miss a unit run only from the repo root could never separate from the fix" "world A: the root-cwd run did not answer gates_recorded=2 in_force=1"
reg cwB_note "world B: a root with no timeline DECLINES to count a lifetime, and says so" "world B: no 'no gate-metrics.jsonl was found' NOTE — the resolver reached past its root and counted somebody else's gates"
reg cwB_inf "world B: nothing is listed in force (in_force=0, no rows) — a lifetime that cannot be counted is not a licence" "world B: an entry is in force or a row was listed — the decoy cwd's timeline became this project's licence"
reg cwB_gates "world B: gates_recorded=NONE, so the count the verdict was computed over is visible" "world B: gates_recorded is not NONE — the verdict reports a timeline it should not have found"
reg c31 "no candidate in the metrics-resolution block is CWD-relative" "the metrics-resolution block offers CWD-relative candidate(s) — the timeline is located from wherever the caller happened to be"
reg sen_A "empty-file cell A empty file" "empty-file cell A empty file does not hold"
reg sen_B "empty-file cell B whitespace-only file" "empty-file cell B whitespace-only file does not hold"
reg sen_C "empty-file cell C absent file (unchanged)" "empty-file cell C absent file (unchanged) does not hold"
reg sen_D "empty-file cell D populated file parsing to zero records carries NO token" "empty-file cell D populated file parsing to zero records carries NO token does not hold"
reg sen_E "empty-file cell E a real finding still exits 1" "empty-file cell E a real finding still exits 1 does not hold"
reg sen_F "empty-file cell F --in-force on an empty file: exit 0, empty stdout, IN-FORCE: on stderr" "empty-file cell F --in-force on an empty file: exit 0, empty stdout, IN-FORCE: on stderr does not hold"
reg sr_Ag "refusal cell Ag mode-000 file, gate: exit 2, REFUSED could not be read, stdout empty" "refusal cell Ag mode-000 file, gate does not hold"
reg sr_Ai "refusal cell Ai mode-000 file, --in-force: exit 2, REFUSED, stdout (the caller's rows) empty" "refusal cell Ai mode-000 file, --in-force does not hold"
reg sr_Bg "refusal cell Bg a directory at the path, gate: exit 2, REFUSED is not a regular file" "refusal cell Bg a directory at the path, gate does not hold"
reg sr_Bi "refusal cell Bi a directory at the path, --in-force: exit 2, REFUSED, stdout empty" "refusal cell Bi a directory at the path, --in-force does not hold"
reg sr_Cg "refusal cell Cg a dangling symlink at the path: exit 2, REFUSED is not a regular file" "refusal cell Cg a dangling symlink at the path does not hold"
reg sr_Dg "refusal cell Dg a readable file whose blank probe exits 2, gate: REFUSED grep exited 2 (stub fired)" "refusal cell Dg a readable file whose blank probe exits 2, gate does not hold"
reg sr_Di "refusal cell Di the same under --in-force: REFUSED, stdout empty (stub fired)" "refusal cell Di the same under --in-force does not hold"
reg sr_Eg "refusal cell Eg near-miss: whitespace-only file, gate: still OK EXAMINED NOTHING, exit 0" "refusal cell Eg near-miss: whitespace-only file, gate does not hold"
reg sr_Ei "refusal cell Ei near-miss: whitespace-only file, --in-force: exit 0, empty stdout, IN-FORCE: on stderr" "refusal cell Ei near-miss: whitespace-only file, --in-force does not hold"
reg sr_Fg "refusal cell Fg near-miss: a readable expired-still-failing suppression still exits 1" "refusal cell Fg near-miss: a readable expired-still-failing suppression no longer exits 1"
reg w1 "W1: an OVERRIDDEN entry naming Check 32 is NOT failed when 32's latest row is FAIL_WAIVED under that entry's own header (trailing whitespace stripped), 1 waived row counted" "W1: the matching waiver was not quiet"
reg w1b "W1b: the same OVERRIDDEN entry over a plain FAIL timeline still fires — only the named waiver stands it down" "W1b: the OVERRIDDEN entry over a FAIL timeline did not fire"
reg w2 "W2: a RESOLVED entry naming Check 32 FIRES when 32 is FAIL_WAIVED under a different entry, and that waiver itself resolves" "W2: a FAIL_WAIVED under another entry acquitted a RESOLVED entry naming the check"
reg w3 "W3: an OVERRIDDEN waiver over 3 recorded gates is quiet — it carries no gate-count lifetime" "W3: an OVERRIDDEN waiver expired by count, or the timeline does not hold 3 gates"
reg w4 "W4: a SUPPRESSED waiver past its lifetime FIRES on a FAIL_WAIVED row; the 3-gate twin over the same gates is quiet" "W4: SUPPRESSED waiver lifetime did not fire expired or did not stay quiet in force"
reg w5 "W5: a FAIL_WAIVED whose waiver_id names no pending.md entry FIRES with its own message" "W5: an unresolvable waiver_id did not fire"
reg w6 "W6: a waiver_id resolving to a DECIDED_AUTONOMOUSLY entry FIRES" "W6: a waiver resolving to a non-waiving status did not fire"
reg w7 "W7: a waiver_id resolving only in pending-archive.md is acquitted with a NOTE, not silently" "W7: the archived waiver was not acquitted with its NOTE"
reg w8 "W8: a FAIL_WAIVED row with an empty waiver_id FIRES" "W8: an empty waiver_id did not fire"
reg c1 "C1: an expired SUPPRESSED entry of 32 does not re-fire when 32 is FAIL_WAIVED under ANOTHER entry's waiver" "C1: an unrelated waiver re-fired an expired suppression of the same check"
reg c1b "C1: with that acquittal, a baselined EXPIRED:32 is reported as no longer reproducing" "C1: the stale EXPIRED baseline line was not reported, or the expiry still fired"
reg c1u "C1: the acquittal holds for an id that resolves nowhere; section 6c still fails that id" "C1: an unresolvable other id re-fired the expiry, or 6c went quiet on it"
reg c2ab "C2: a second OVERRIDDEN entry naming 32 is quiet when the row's OVERRIDDEN waiver sits ABOVE it" "C2: the second OVERRIDDEN entry fired with its waiver above it"
reg c2ba "C2: the same, with the waiver BELOW it -- resolution reads the pre-pass table, not the entries so far" "C2: the second OVERRIDDEN entry fired with its waiver below it -- resolved against the entries read so far"
reg c2a "C2: the same, with the OVERRIDDEN waiver archived to pending-archive.md" "C2: an archived OVERRIDDEN waiver did not stand the naming entry down"
reg c2s "C2: an OVERRIDDEN entry naming 32 is quiet when 32 is waived by a SUPPRESSED entry targeting [core] 32" "C2: a matching SUPPRESSED waiver did not stand the OVERRIDDEN entry down"
reg c2x "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver is an ARCHIVED SUPPRESSED entry of 32 past its own lifetime" "C2: an expired archived suppression stood an OVERRIDDEN entry down -- its lifetime was never checked"
reg c2u "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver resolves nowhere" "C2: an unresolvable waiver stood an OVERRIDDEN entry down"
reg c2r "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver is a RESOLVED entry" "C2: a RESOLVED waiver stood an OVERRIDDEN entry down"
reg c2m "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver is a SUPPRESSED entry of another check" "C2: a mis-targeted SUPPRESSED waiver stood an OVERRIDDEN entry down"
reg wsd "own-entry stand-down: a RESOLVED entry naming 32 is quiet when the row's waiver_id is its own header plus a trailing blank" "own-entry stand-down: the entry that IS the waiver fired -- the own-entry compare does not strip the row id"

in_set() { case "$2" in *" $1 "*) return 0 ;; esac; return 1; }
arm_eval() { # <key> <arm> -> 0 holds, 1 does not
  "ar_$2" "$1"
}
VP[0]="$VALIDATOR"

echo "suppression-lifetime:"

# ===== the sandbox facts that are about the fixture, not the validator ===========================
if [ -f "$SL_A_GM" ] && [ -f "$SL_A_DECOY_GM" ] && ! cmp -s "$SL_A_GM" "$SL_A_DECOY_GM"; then
  ok "world A: the root timeline and the decoy-cwd timeline both exist and DIFFER — the pair below can discriminate"
else
  bad "world A: FIXTURE BROKEN — the root and decoy timelines are missing or identical, so every arm below agrees for free"
fi
SL_B_ANY="$(find "$SL_CWD_B_ROOT" -name 'gate-metrics.jsonl' 2>/dev/null | grep -c .)" || SL_B_ANY=0
SL_A_ANY="$(find "$SL_CWD_A_ROOT" -name 'gate-metrics.jsonl' 2>/dev/null | grep -c .)" || SL_A_ANY=0
if [ "$SL_B_ANY" -eq 0 ] && [ "$SL_A_ANY" -gt 0 ]; then
  ok "world B: no gate-metrics.jsonl anywhere under its root (control: world A's root has $SL_A_ANY)"
else
  bad "world B: FIXTURE BROKEN — found $SL_B_ANY metrics files under its root against a control of $SL_A_ANY; the 'nothing to count' world does not exist"
fi
SL_SEC2_N="$(grep -cF "$SL_SEC2" "$VALIDATOR")" || SL_SEC2_N=0
SL_SEC2_MISS="$(grep -cF '# ---- 2. Locate the impossible section' "$VALIDATOR")" || SL_SEC2_MISS=0
if [ "$SL_SEC2_N" = "1" ] && [ "$SL_SEC2_MISS" = "0" ]; then
  ok "the metrics-resolution block has exactly one section header to anchor on (control: an impossible anchor matches 0)"
else
  bad "the metrics-resolution anchor matched $SL_SEC2_N times (control $SL_SEC2_MISS) — the mutants below would land somewhere else or nowhere"
fi

# ===== the shipping validator: every arm ===========================================================
SHIP_PASS=" "; SHIP_FAIL=" "
for a in $ARMS; do
  if arm_eval 0 "$a"; then SHIP_PASS="$SHIP_PASS$a "; else SHIP_FAIL="$SHIP_FAIL$a "; fi
done
# A SUBJECT THAT PREDATES THE FIX. This fixture ships and can reach a consumer one pull ahead of the
# validator: sen_A and sen_B read 0 and nothing else moves (SKIP there; FAIL in the distribution). The
# refusal arms likewise: sr_Bg sr_Bi sr_Cg sr_Dg sr_Di read 0 and the near-misses hold.
SEN_IS_DIST=0
case "$(cd "$(dirname "$VALIDATOR")" && pwd)" in */core/scripts) SEN_IS_DIST=1 ;; esac
SKIPPED=" "
if in_set sen_A "$SHIP_FAIL" && in_set sen_B "$SHIP_FAIL" && in_set sen_C "$SHIP_PASS" && in_set sen_D "$SHIP_PASS" \
   && in_set sen_E "$SHIP_PASS" && in_set sen_F "$SHIP_PASS" && [ "$SEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the empty-file arms -- the installed validator predates the empty-file verdict; this fixture ships one pull ahead of it\n'
  SKIPPED="$SKIPPED sen_A sen_B sen_C sen_D sen_E sen_F "
fi
SR_PRE=1
for a in sr_Bg sr_Bi sr_Cg sr_Dg sr_Di; do in_set "$a" "$SHIP_FAIL" || SR_PRE=0; done
for a in sr_Eg sr_Ei sr_Fg; do in_set "$a" "$SHIP_PASS" || SR_PRE=0; done
if [ "$SR_PRE" = 1 ] && [ "$SEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the refusal arms -- the installed validator predates the unreadable-file refusal; this fixture ships one pull ahead of it\n'
  SKIPPED="$SKIPPED sr_Ag sr_Ai sr_Bg sr_Bi sr_Cg sr_Dg sr_Di sr_Eg sr_Ei sr_Fg "
elif [ -n "$SR_SKIP_A" ]; then
  SKIPPED="$SKIPPED sr_Ag sr_Ai "
fi
for a in $ARMS; do
  in_set "$a" "$SKIPPED" && continue
  if in_set "$a" "$SHIP_PASS"; then
    _m="OK_$a"; while IFS= read -r _l; do ok "$_l"; done <<<"${!_m}"
  else
    _m="BAD_$a"; bad "${!_m}"
  fi
done
# ===== mutant builders =============================================================================
# Every builder writes ONE lone copy of the validator and returns 1 (with BUILD_WHY) when its anchor
# does not match exactly one line, changed no bytes, or does not parse. Strings reach awk through
# ENVIRON, never `-v`, which strips a level of backslash escaping.
BUILD_WHY=""
mk_sub() { # <out> <anchor> <replacement> [<anchor> <replacement> ...] -- each anchor on exactly one line
  local out="$1" n; shift
  cp "$VALIDATOR" "$out.work" || { BUILD_WHY="could not copy"; return 1; }
  while [ "$#" -ge 2 ]; do
    n="$(grep -cF -- "$1" "$out.work")" || n=0
    [ "$n" -eq 1 ] || { BUILD_WHY="anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm: $1"; return 1; }
    A="$1" R="$2" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$out.work" > "$out.next" || { BUILD_WHY="awk died applying: $1"; return 1; }
    mv "$out.next" "$out.work"
    shift 2
  done
  if cmp -s "$VALIDATOR" "$out.work"; then BUILD_WHY="changed no bytes -- it would score as a kill"; return 1; fi
  bash -n "$out.work" 2>/dev/null || { BUILD_WHY="does not parse"; return 1; }
  mv "$out.work" "$out"
}
SL_K_A='END { print bestv "\t" bestt "\t" bestw }'
build_k_ts_dropped() { mk_sub "$1" "$SL_K_A" 'END { print bestv "\t" "\t" bestw }'; }
build_l_last_ts() { mk_sub "$1" "$SL_K_A" 'END { print bestv "\t" t "\t" bestw }'; }
build_a_whitespace_tolerance_dropped() {
  mk_sub "$1" 're = "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\""' 're = "\"" key "\":\"[^\"]*\""'
}
build_b_catalog_join_dropped() { mk_sub "$1" 'if ! grep -qxF "$supp" <<<"$CATALOG"; then' 'if false; then'; }
build_c_ifs_delimiter() {
  local sf="$1.sed"
  cat > "$sf" <<'SED'
s/037%s/011%s/g
s/printf '\\037'/printf '\\011'/
SED
  sed -f "$sf" "$VALIDATOR" > "$1.work"
  if cmp -s "$VALIDATOR" "$1.work"; then BUILD_WHY="anchor matched nothing"; return 1; fi
  bash -n "$1.work" 2>/dev/null || { BUILD_WHY="does not parse"; return 1; }
  mv "$1.work" "$1"
}
# D/E anchor on the VERDICT LINE, NOT ON THE FOUR LABELS. The labels are the thing most likely to be
# reworded; the verdict sentence is the emitter's own text and unique to this site, so the mutation
# follows the block however the labels are respaced.
sl_anchor_v='no suppression is past its lifetime on a still-failing check."'
build_d_identity_lines_deleted() {
  local out="$1"
  [ "$(grep -cF "$sl_anchor_v" "$VALIDATOR")" = "1" ] || { BUILD_WHY="anchor is not unique in the validator"; return 1; }
  [ "$(grep -cE '^echo "  ' "$VALIDATOR")" -ge 4 ] || { BUILD_WHY="fewer than four identity lines follow the verdict -- the block this fixture guards has shrunk"; return 1; }
  A="$sl_anchor_v" awk '
    index($0, ENVIRON["A"])    { print; hit=1; next }
    hit && /^echo "  /         { next }
                               { hit=0; print }
  ' "$VALIDATOR" > "$out.work"
  cmp -s "$VALIDATOR" "$out.work" && { BUILD_WHY="changed no bytes"; return 1; }
  bash -n "$out.work" 2>/dev/null || { BUILD_WHY="does not parse"; return 1; }
  mv "$out.work" "$out"
}
# THE FIX THAT DISCRIMINATES WITHOUT NAMING. `$$-$RANDOM` is evaluated by the mutant at run time, so its
# two runs differ exactly as the real validator's do while naming no file at all.
build_e_identity_nonce() {
  local out="$1"
  [ "$(grep -cF "$sl_anchor_v" "$VALIDATOR")" = "1" ] || { BUILD_WHY="anchor is not unique in the validator"; return 1; }
  A="$sl_anchor_v" awk '
    index($0, ENVIRON["A"])    { print; hit=1; next }
    hit && /^echo "  /         { print "echo \"  nonce: $$-$RANDOM\""; next }
                               { hit=0; print }
  ' "$VALIDATOR" > "$out.work"
  cmp -s "$VALIDATOR" "$out.work" && { BUILD_WHY="changed no bytes"; return 1; }
  bash -n "$out.work" 2>/dev/null || { BUILD_WHY="does not parse"; return 1; }
  mv "$out.work" "$out"
}
# F: the arm demoted to the case's else. The plausible regression, not a deletion: an author siting the
# same test inside the `case` writes it as a `*)` branch. It reaches case 10 and NOT case 13, because
# RESOLVED matches an earlier branch. Anchored on the `if` line's own condition, which is unique to this
# site -- the `case` line below it is shared with three other files.
sl_anchor_f='if [ "${status:-}" != "SUPPRESSED" ] && { [ -n "$supp" ] || [ -n "$expires" ]; }; then'
build_f_attempt_demoted() {
  mk_sub "$1" "$sl_anchor_f" 'if [ "${status:-}" = "__never__" ] && { [ -n "$supp" ] || [ -n "$expires" ]; }; then'
}
# G/H replace the whole metrics-resolution block rather than editing candidate lines, because a mutation
# keyed on the shipped spelling of a candidate is a no-op the day that spelling changes.
sl_mkblock() { # <out> <body-file>
  awk -v A="$SL_SEC2" -v B="$2" '
    st==0 && index($0, A) { print; st=1; next }
    st==1 && $0 == "fi"   { while ((getline l < B) > 0) print l; close(B); st=2; next }
    st==1                 { next }
                          { print }
  ' "$VALIDATOR" > "$1"
  if cmp -s "$VALIDATOR" "$1"; then BUILD_WHY="the block was not replaced"; return 1; fi
  bash -n "$1" 2>/dev/null || { BUILD_WHY="does not parse"; return 1; }
}
cat > "$WORK/mut-body-regress.sh" <<'SLBODY'
# mutant: THE REGRESSION — cwd-relative candidates first, exactly as this shipped.
if [ -z "$GATE_METRICS" ]; then
  for cand in \
      "_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "_bmad-output/gate-metrics.jsonl" \
      "$AI_DLC_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl"; do
    [ -f "$cand" ] && { GATE_METRICS="$cand"; break; }
  done
fi
SLBODY
cat > "$WORK/mut-body-w1.sh" <<'SLBODY'
# mutant: THE WRONG FIX — the root is tried first and the cwd is still a fallback.
if [ -z "$GATE_METRICS" ]; then
  for cand in \
      "$AI_DLC_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "$AI_DLC_ROOT/docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "$AI_DLC_ROOT/_bmad-output/gate-metrics.jsonl" \
      "_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "docs/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
      "_bmad-output/gate-metrics.jsonl"; do
    [ -f "$cand" ] && { GATE_METRICS="$cand"; break; }
  done
fi
SLBODY
build_g_cwd_first_regression() {
  sl_mkblock "$1" "$WORK/mut-body-regress.sh" || return 1
  grep -q 'mutant: THE REGRESSION' "$1" || { BUILD_WHY="carries no marker line -- the replacement body never landed"; return 1; }
}
build_h_cwd_fallback_after_root() {
  sl_mkblock "$1" "$WORK/mut-body-w1.sh" || return 1
  grep -q 'mutant: THE WRONG FIX' "$1" || { BUILD_WHY="carries no marker line -- the replacement body never landed"; return 1; }
}
# I/J: each replaces latest_verdict()'s catalog join with a WRONG one. Keyed on BEHAVIOUR -- the verdict
# each returns -- never on the spelling of the condition line. J hard-codes `core`: every seed drawn from
# the real corpus passes it, because all 18 live suppressions on the reference consumer are `[core]` and
# the non-core control is 0. Only the mirrored world (s17) separates it from the fix.
build_i_join_guard_removed() {
  A='if (g != wantcat) next' R='      # join guard removed' awk '
    index($0, ENVIRON["A"]) { print ENVIRON["R"]; next }
                            { print }
  ' "$VALIDATOR" > "$1.work"
  cmp -s "$VALIDATOR" "$1.work" && { BUILD_WHY="the catalog guard line was not found"; return 1; }
  bash -n "$1.work" 2>/dev/null || { BUILD_WHY="does not parse"; return 1; }
  mv "$1.work" "$1"
}
build_j_join_hardcoded_core() {
  sed 's/^  \[ -n "\$cat" \] || cat="core"$/  cat="core"/' "$VALIDATOR" > "$1.work"
  cmp -s "$VALIDATOR" "$1.work" && { BUILD_WHY="the bare-id default line was not found"; return 1; }
  bash -n "$1.work" 2>/dev/null || { BUILD_WHY="does not parse"; return 1; }
  mv "$1.work" "$1"
}
# M-*: the empty-file verdict.
SEN_ANCHOR='if [ "$IN_FORCE" -ne 1 ] && [ "$SL_BLANK_RC" -eq 1 ]; then'
build_m_revert() { mk_sub "$1" "$SEN_ANCHOR" 'if false; then'; }
build_m_zero_records() {
  mk_sub "$1" '[ -n "$RECORDS" ] || ENTRIES_N=0' $'[ -n "$RECORDS" ] || ENTRIES_N=0\nif [ "$IN_FORCE" -ne 1 ] && [ "$ENTRIES_N" -eq 0 ]; then echo "OK: EXAMINED NOTHING — entries_scanned=0 -- zero parsed records ($ESCALATIONS)."; exit 0; fi'
}
build_m_hoist() { mk_sub "$1" "$SEN_ANCHOR" 'if [ "$SL_BLANK_RC" -eq 1 ]; then'; }
# R-*: one per layer of the refusal guard, and one reverting EVERY layer.
SR_G1='if { [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; } && [ ! -f "$ESCALATIONS" ]; then'
SR_G1L='{ [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; }'
SR_G2='if [ "$SL_BLANK_RC" -gt 1 ]; then'
SR_G3='if [ ! -r "$ESCALATIONS" ]; then'
build_r_revert_all() { mk_sub "$1" "$SR_G1" 'if false; then' "$SR_G2" 'if false; then'; }
build_r_nonregular() { mk_sub "$1" "$SR_G1" 'if false; then'; }
build_r_no_symlink() { mk_sub "$1" "$SR_G1L" '[ -e "$ESCALATIONS" ]'; }
build_r_rc() { mk_sub "$1" "$SR_G2" 'if false; then'; }
build_r_readable_never() { mk_sub "$1" "$SR_G3" 'if false; then'; }
build_r_readable_always() { mk_sub "$1" "$SR_G3" 'if true; then'; }
# MW-*: the waived verdict. Each is scored only after the arm it targets PASSED unmutated in this same run.
SL_SD='if [ -n "$tw" ] && [ "$tw" = "$wkey" ]; then continue; fi'
SL_C1='if [ "$verdict" = "FAIL" ] || { [ "$verdict" = "FAIL_WAIVED" ] && [ "$vwid" = "$wkey" ]; }; then'
SL_C2='if [ "$status" = OVERRIDDEN ] && sl_lookup "$tw"; then'
build_w_standdown() { mk_sub "$1" "$SL_SD" 'if false; then continue; fi'; }
build_w_resolve() { mk_sub "$1" '  if [ -z "$wrec" ]; then' '  if [ -z "$wrec" ]; then continue; fi; if false; then'; }
build_w_lifetime() { mk_sub "$1" "$SL_C1" 'if [ "$verdict" = "FAIL" ]; then'; }
# C1/C2. c1_revert: any FAIL_WAIVED re-fires the expiry. c2_exact: the ruling's mutant, exact match
# only for OVERRIDDEN. c2_any: any FAIL_WAIVED stands an OVERRIDDEN entry down. c2_resolved: C2 for
# RESOLVED too. c2_noprepass: the table holds only the entries read so far, as ENTRY_KEYS once did.
build_c1_revert() { mk_sub "$1" "$SL_C1" 'if [ "$verdict" = "FAIL" ] || [ "$verdict" = "FAIL_WAIVED" ]; then'; }
build_c2_exact() { mk_sub "$1" "$SL_C2" 'if false && sl_lookup "$tw"; then'; }
build_c2_any() { mk_sub "$1" "$SL_C2" 'if [ "$status" = OVERRIDDEN ]; then continue; fi; if false; then'; }
build_c2_resolved() { mk_sub "$1" "$SL_C2" 'if sl_lookup "$tw"; then'; }
build_c2_noprepass() {
  mk_sub "$1" 'SL_TABLE="$RECORDS"' 'SL_TABLE=""' \
    '  short="$(printf '"'"'%s'"'"' "$header" | cut -c1-92)"' \
    '  short="$(printf '"'"'%s'"'"' "$header" | cut -c1-92)"; SL_TABLE="${SL_TABLE}${header}$US${status}$US${supp}$US$US$US$US${suppcat}$US$US${wkey}${US}P
"'
}
# c2_nolife: C2 resolves through a SUPPRESSED waiver without asking its lifetime (tip adversary N5).
SL_C2L='&& [ -n "$LK_EXPIRES" ] && [ -n "$LK_AUTHTS" ] && ! sl_past_lifetime "$LK_AUTHTS" "$LK_EXPIRES"; then continue; fi ;;'
build_c2_nolife() { mk_sub "$1" "$SL_C2L" '; then continue; fi ;;'; }
build_w_overridden() { mk_sub "$1" '    OVERRIDDEN) : ;;' '    OVERRIDDEN) bad=$((bad + 1)) ;;'; }

# ===== mutants =====================================================================================
# Name | decides arms | twin arm | builder. Copies, never in-place edits. `cmp -s` proves the mutation
# landed and `bash -n` proves the result is still a program — a copy that dies on a syntax error emits
# nothing, and "no output" otherwise scores as a kill. Anchors are chosen on backslash-free, grep-unique
# lines: `awk -v` processes escape sequences in the assigned value, so an anchor carrying a backslash
# arrives at index() stripped and the mutation is a silent no-op that comes out GREEN.
MN=(); MD=(); MT=(); NM=0
defm() { MN[$NM]="$1"; MD[$NM]="$2"; MT[$NM]="$3"; NM=$((NM+1)); }

# K: the ts dropped from the row latest_verdict returns. t18a and t18b must die; the verdicts must not move.
defm k_ts_dropped t18a t18c
# L: the ts printed is the LAST matching row read, not the newest. Only t18d can see it.
defm l_last_ts t18d t18a
# A: the metrics extractor stops tolerating whitespace.
defm a_whitespace_tolerance_dropped s2 cwA_inf
# B: the catalog join is dropped.
defm b_catalog_join_dropped s6 s2
# C: the record delimiter reverts to an IFS-whitespace character.
defm c_ifs_delimiter s4m sen_F
# D: the identity lines deleted -- assertion ident AND cand go red, no verdict moves.
defm d_identity_lines_deleted ident s1
# E: identity replaced by a per-run NONCE.
defm e_identity_nonce ident s1
# F: the attempted-suppression arm demoted to the case's else.
defm f_attempt_demoted att17a,att17b,att17c s2
# G: the cwd-first regression. H: the root-then-cwd wrong fix, invisible in world A.
defm g_cwd_first_regression cwA_gates,cwA_inf,cwA_met,cwA_agree,c31,cwB_note,cwB_inf,cwB_gates cwA_root
defm h_cwd_fallback_after_root cwB_note,cwB_inf,cwB_gates,c31 cwA_gates
# I/J: wrong catalog joins.
defm i_join_guard_removed s14 s15
defm j_join_hardcoded_core s17 s14
# M: the empty-file verdict.
defm m_revert sen_A,sen_B,sr_Eg sen_C
defm m_zero_records sen_D sen_A
defm m_hoist sen_F,sr_Ei sen_A
# R: the refusal guard, one per layer.
defm r_revert_all sr_Ag,sr_Ai,sr_Bg,sr_Bi,sr_Cg,sr_Dg,sr_Di sr_Fg
defm r_nonregular sr_Bg,sr_Bi,sr_Cg sr_Ag
defm r_no_symlink sr_Cg sr_Bg
defm r_rc sr_Ag,sr_Ai,sr_Dg,sr_Di sr_Eg
defm r_readable_never sr_Ag,sr_Ai sr_Dg
defm r_readable_always sr_Dg,sr_Di sr_Ag
# MW: the waived verdict.
defm w_standdown wsd w1
defm w_resolve w5 w1
defm w_lifetime w4 s2
defm w_overridden w3,w1 w4
# C1/C2: whose waiver is it.
defm c1_revert c1,c1b,c1u w4
defm c2_exact c2ab,c2ba,c2a,c2s c2u
defm c2_any c2u,c2r,c2m c2ab
defm c2_resolved w2 c2u
defm c2_noprepass c2ba c2ab
defm c2_nolife c2x c2s

MUT="$WORK/mut"; mkdir -p "$MUT"
# The unmutated control: a lone copy. This validator resolves no sibling beside itself and its root by
# walking up for a marker; a lone copy that could not resolve it would emit nothing, and that silence
# would score as a kill for every mutant below.
cp "$VALIDATOR" "$MUT/control.sh"
VP[1]="$MUT/control.sh"
MUT_OK=" "
mut_i=0
while [ "$mut_i" -lt "$NM" ]; do
  n="${MN[$mut_i]}"
  if "build_$(printf '%s' "$n" | tr '.:-' '___')" "$MUT/$n.sh"; then
    VP[$((mut_i+2))]="$MUT/$n.sh"; MUT_OK="$MUT_OK$n "
  else
    bad "MUTANT $n DID NOT APPLY: $BUILD_WHY"
  fi
  mut_i=$((mut_i+1))
done

# --- the control: ONE drive of a lone copy, asserting the one property a copy can lose ------------------
# This validator resolves no sibling beside itself and finds its root by walking up for a marker; a lone
# copy that could not resolve it would emit nothing, and that silence would score as a kill for every
# mutant below. So ONE drive (the expired-still-failing case, arm s2) of the unmutated copy must
# reproduce the shipping verdict. Everything else a control battery would prove is the shipping run's.
CTRL_OK=0
if arm_eval 1 s2; then
  ok "UNMUTATED CONTROL: a lone copy of the validator resolves its root and reproduces the real expired-suppression verdict (s2) — mutant silence means mutation, not breakage"; CTRL_OK=1
else
  bad "UNMUTATED CONTROL: a lone copy did not reproduce the expired-suppression verdict — every mutant result below is uninterpretable"
fi
base_ok() { [ "$CTRL_OK" = 1 ] && in_set "$1" "$SHIP_PASS"; }

# --- the c31 control: the regression mutant's block really does offer cwd-relative candidates ------
SL_SHIP_CWD="$(sl_cwd_cands "$VALIDATOR")"
SL_REGRESS_CWD="$(sl_cwd_cands "$MUT/g_cwd_first_regression.sh")"
if [ "$SL_SHIP_CWD" = "0" ] && [ "$SL_REGRESS_CWD" -gt 0 ]; then
  ok "the regression mutant's resolution block offers $SL_REGRESS_CWD CWD-relative candidate(s) against the shipped file's 0 — c31 can fire"
else
  bad "c31 control: shipped=$SL_SHIP_CWD regression-mutant=$SL_REGRESS_CWD — the cwd-candidate count cannot tell the regression from the fix"
fi

mut_witness() { # <mutant> <vk> -> 0 when the mutant's extra observable holds (checked on cached drives)
  case "$1" in
    k_ts_dropped)    dv "$2" exp; [ "$DV_RC" = 1 ] && hasF "STILL FAILING" ;;                 # the FAIL still fires; only the ts channel moved
    w_standdown)     dv "$2" wsd; [ "$DV_RC" = 1 ] && has "recorded FAILING" ;;               # the own-entry world dies by the terminal arm's own line
    c1_revert)       dv "$2" c1; [ "$DV_RC" = 1 ] && hasF "$C1_MSG" && has 'latest recorded verdict is FAIL_WAIVED' ;;
    c2_exact|c2_noprepass) dv "$2" c2ba; [ "$DV_RC" = 1 ] && hasF "$C2_HIT" ;;
    c2_resolved)     dv "$2" wo; [ "$DV_RC" = 0 ] && ! has 'recorded FAILING' ;;
    w_resolve)       dv "$2" wnone; [ "$DV_RC" = 0 ] && ! has "which names NO entry" && w_quiet 1 ;;   # the acquittal is the skipped resolution's
    w_lifetime)      dv "$2" wsup1; [ "$DV_RC" = 0 ] ;;
    w_overridden)    dv "$2" wm_ovr; has "^FAIL: 1 suppression-lifetime violation(s)" && [ "$(grep -c '^FAIL: ' <<<"$DV_O")" = "1" ] ;;
    c_ifs_delimiter) dv "$2" mal; ! has 'Suppresses' ;;
    *) return 0 ;;
  esac
}

join_set() { local o="" x; for x in "$@"; do o="$o,$x"; done; printf '%s' "${o#,}"; }
if [ "$MATRIX" = 1 ]; then
  # FULL MATRIX: every mutant driven against EVERY arm; every cell printed, 1 = the arm FAILS under the mutant.
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    n="${MN[$mut_i]}"
    case "$MUT_OK" in *" $n "*) ;; *) mut_i=$((mut_i+1)); continue ;; esac
    MX_FULL_RUNS=$((MX_FULL_RUNS + 1))
    cells=""; tripped=""
    for a in $ARMS; do
      if arm_eval $((mut_i+2)) "$a"; then cells="$cells,$a:0"; else cells="$cells,$a:1"; tripped="$tripped $a"; fi
    done
    decl="$(printf '%s' " ${MD[$mut_i]//,/ } " | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
    meas="$(printf '%s' "$tripped" | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
    st=match; for _d in ${MD[$mut_i]//,/ }; do case " $tripped " in *" $_d "*) ;; *) st=DIFFERS ;; esac; done
    tw=green; for _t in ${MT[$mut_i]//,/ }; do case "$tripped " in *" $_t "*) tw=TRIPPED ;; esac; done
    printf 'MATRIX %s decides=%s cells=%s tripped=[%s] declared=%s twins=%s\n' "$n" "${MD[$mut_i]}" "${cells#,}" "$(join_set $tripped)" "$st" "$tw"
    mut_i=$((mut_i+1))
  done
else
  # PER PUSH: each mutant drives its DECIDING arm(s) and its measured-green TWIN only.
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    n="${MN[$mut_i]}"
    case "$MUT_OK" in *" $n "*) ;; *) mut_i=$((mut_i+1)); continue ;; esac
    dec=" "; for a in ${MD[$mut_i]//,/ }; do in_set "$a" "$SKIPPED" || dec="$dec$a "; done
    twn=" "; for a in ${MT[$mut_i]//,/ }; do in_set "$a" "$SKIPPED" || twn="$twn$a "; done
    if [ "$dec" = " " ]; then
      printf '  SKIP  MUTANT %s -- every deciding arm is skipped on this host or against this installed validator\n' "$n"
      mut_i=$((mut_i+1)); continue
    fi
    flag=1
    for a in $dec $twn; do base_ok "$a" || flag=0; done
    wrong=""
    for a in $dec; do if arm_eval $((mut_i+2)) "$a"; then wrong="$wrong $a-did-not-flip"; fi; done
    for a in $twn; do arm_eval $((mut_i+2)) "$a" || wrong="$wrong $a-twin-not-green"; done
    if [ -n "$wrong" ]; then
      if [ "$flag" = 1 ]; then bad "MUTANT $n scored [$wrong ], wanted decides=[${MD[$mut_i]}] flipped and twin=[${MT[$mut_i]}] green"; else need_base "$flag" "$n" || true; fi
    elif ! mut_witness "$n" $((mut_i+2)); then
      bad "MUTANT $n flipped its arm but its witness did not hold — it died for a reason other than its mutation"
    else
      mutant_killed "$flag" "$n" "MUTANT $n killed on [${MD[$mut_i]}]; twin [${MT[$mut_i]}] stays green"
    fi
    mut_i=$((mut_i+1))
  done
  if [ "$MX_FULL_RUNS" -eq 0 ]; then ok "a plain run executed no matrix-only cell (MX_FULL_RUNS=0)"
  else bad "a plain run executed $MX_FULL_RUNS matrix-only cell(s)"; fi
fi
echo "DRIVE-COUNT validator runs=$DRIVES mutants=$NM"

echo
if [ "$fails" -ne 0 ]; then
  echo "suppression-lifetime: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "suppression-lifetime: all assertions passed"
