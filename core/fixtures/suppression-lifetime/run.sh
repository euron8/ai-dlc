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
# SHAPE. A DRIVE is one validator run on one state, captured once per validator (stdout, stderr,
# exit status, rows). An ARM is a predicate over captured drives, so two arms asking about the same
# state share one run. The shipping validator evaluates every arm.

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
# verdict.sh sits beside the validator in both layouts; arm slvd drives the T1 world through it.
VERDICT="$(dirname "$VALIDATOR")/verdict.sh"
[ -f "$VERDICT" ] && echo "HERMETIC-CONSUMED $VERDICT"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# IN PROCESS (BL-878). The validator and verdict.sh are loaded once each and asked through inproc_run (vlt_drive, vrd_drive);
# verdict.sh's own `bash <validator>` start and the receipt's two validator starts go through the `bash` shim below, which runs
# vlt_main in a subshell made fresh the way inproc_run makes one. A core fixture ships ahead of its subjects: a subject with
# neither the `<p>_main() {` line nor the column-0 source guard predates the wrap and SKIPs (FIXTURE BROKEN in the
# distribution); exactly one half FAILs; an unreadable subject is FIXTURE ERROR.
sl_halves() { # <file> <entry> -> "<def><guard>"
  local d=0 g=0 x
  grep -qxF "$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
sl_pre=""
sl_gate() { # sl_gate <file>:<entry> -- one call line per wrapped subject, so each carries its own gate
  local _s="$1" _h
  _h="$(sl_halves "${_s%%:*}" "${_s##*:}")" || exit 2
  case "$_h" in
    11) : ;;
    00) sl_pre="$sl_pre ${_s%%:*}" ;;
    *) bad "${_s%%:*} carries one half of the in-process wrap (${_s##*:} line, column-0 source guard: $_h) -- a respelled subject this fixture cannot drive"
       report_end suppression-lifetime ;;
  esac
}
sl_gate "$VALIDATOR:vlt_main"
sl_gate "$VERDICT:vrd_main"
if [ -n "$sl_pre" ]; then echo "SKIP: subject predates the in-process wrap:$sl_pre"; fx_skip_exit "$HERE"; fi

. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }
export FX_VLT="$VALIDATOR" # exported: inproc_run keeps exported variables and drops the rest
bash() { # a `bash <validator>` start runs vlt_main in a fresh-options subshell; any other start is real
  if [ "${1:-}" != "$FX_VLT" ]; then command bash "$@"; return; fi
  shift
  (
    _x=" $(compgen -e) "; _x="${_x//$'\n'/ }"
    for _v in $(compgen -v); do
      case "$_x" in *" $_v "*) continue ;; esac
      case "$_v" in
        _x|_v) continue ;;
        BASH|BASH_*|BASHOPTS|BASHPID|COMP_WORDBREAKS|DIRSTACK|EUID|FUNCNAME|GROUPS|HISTCMD|HOSTNAME|HOSTTYPE) continue ;;
        IFS|LINENO|MACHTYPE|OPTERR|OPTIND|OSTYPE|PIPESTATUS|PPID|PS4|PWD|OLDPWD|RANDOM|SECONDS|SHELL|SHELLOPTS) continue ;;
        SHLVL|TERM|UID|_) continue ;;
      esac
      unset "$_v" 2>/dev/null
    done
    OPTIND=1; set +eufx +o pipefail; hash -r
    ! declare -F fx_inproc >/dev/null 2>&1 || fx_inproc "$FX_VLT"; . "$FX_VLT" && vlt_main "$@"
  )
}
inproc_load "$VALIDATOR" || { echo "FIXTURE ERROR: $VALIDATOR defines no vlt_main (not loadable)" >&2; exit 2; }
SL_VLT_FNS="${INPROC_FNS}bash "
inproc_load "$VERDICT" || { echo "FIXTURE ERROR: $VERDICT defines no vrd_main (not loadable)" >&2; exit 2; }
SL_VRD_FNS="${INPROC_FNS}bash "
# inproc_run strips every function the loaded subject did not define; use_subj selects which loaded subject is current and
# names the shim with its set (inproc_run then checks the set's definitions are unchanged, and bash is part of it).
use_subj() {
  case "$1" in
    vlt) INPROC_LOADED="$VALIDATOR"; INPROC_FNS="$SL_VLT_FNS" ;;
    vrd) INPROC_LOADED="$VERDICT"; INPROC_FNS="$SL_VRD_FNS" ;;
  esac
  INPROC_DEFS="$(declare -f $INPROC_FNS)"
}
vlt_drive() { use_subj vlt; inproc_run "$VALIDATOR" vlt_main "$@"; } # <validator args> -> its answer, in process
vrd_drive() { use_subj vrd; inproc_run "$VERDICT" vrd_main "$@"; }   # <verdict args> -> its answer, in process
RCPT="$HERE/receipt-bl959.sh" # a library: its guard returns after defining r959_main, which starts the validator twice through the shim

DRIVES=0           # validator runs actually executed (the cost this fixture is held to)

# ---- fixed inputs the drives share ------------------------------------------------------------
# 18d: every seeded timeline above is written in ASCENDING ts order, so "the newest row" and "the
# last row read" are the same row there and a reader printing the last-seen ts passes 18a and 18b. The
# real file is appended by a lead per gate but nothing orders it. Reversed, the two readings name
# different rows.
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
  printf '#!/bin/bash\ncase "$*" in\n'
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
    c2xi)    c=c2-archived-inforce; gm="$GM_W_C2" ;;
    c2x18)   c=c2-archived-overcap; gm="$GM_W_C2" ;;
    archsup) c=arch-sup; gm="$GM_SL_W" ;;
    archover) c=arch-over; gm="$GM_W_C2" ;;
    archmis) c=arch-mis; gm="$GM_W_C2" ;;
    archgx)  c=arch-gone-exp; gm="$GM_W_C2" ;;
    archgi)  c=arch-gone-inf; gm="$GM_W_C2" ;;
    archbx)  c=arch-blank-exp; gm="$GM_W_C2" ;;
    archgd)  c=arch-gone-dir; gm="$GM_W_C2" ;;
    c2xu)    c=c2-archived-noexpiry; gm="$GM_W_C2" ;;
    c2xt)    c=c2-archived-nots; gm="$GM_W_C2" ;;
    c2u)     c=c2-unresolvable; gm="$GM_W_C2" ;;
    c2r)     c=c2-resolved; gm="$GM_W_C2" ;;
    c2m)     c=c2-mistargeted; gm="$GM_W_C2" ;;
    wsd)     c=own-standdown; gm="$GM_W_SD" ;;
    sl_t1b)  c=sl-t1; gm="$GM_SL_F" ;;
    sl_t11e) c=sl-t11; gm="$GM_SL_F" ;;
    sl_t12)  c=sl-t1; gm="$GM_SL_W"; ex="--baseline $BASELINE_EXP32" ;;
    sl_*)    c="sl-${d#sl_}"; gm="$GM_SL_W" ;;
  esac
  case "$d" in
    nocat)
      O="$(vlt_drive --escalations "$CASES/expired-still-failing/pending.md" \
            --gate-metrics "$GM_FAILING" --enforcement-map "$WORK/nope.yaml" 2>&1)"; RC=$? ;;
    nomet)
      O="$(vlt_drive --escalations "$CASES/malformed-no-target/pending.md" \
            --enforcement-map "$MAP" --gate-metrics "$WORK/absent.jsonl" 2>&1)"; RC=$? ;;
    ident_a|ident_b)
      f="$IDA"; [ "$d" = ident_b ] && f="$IDB"
      O="$(vlt_drive --escalations "$f/pending.md" --gate-metrics "$f/gm.jsonl" \
            --enforcement-map "$f/catalog.yaml" --baseline "$f/baseline.txt" 2>&1)"; RC=$? ;;
    cand_a|cand_b)
      f="$CDA"; [ "$d" = cand_b ] && f="$CDB"
      O="$(AI_DLC_PROJECT_ROOT="$f" vlt_drive --escalations "$f/pending.md" --gate-metrics "$GM_FAILING" 2>&1)"; RC=$? ;;
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
      O="$( cd "$cwd" && AI_DLC_PROJECT_ROOT="$root" vlt_drive --in-force --escalations "$root/pending.md" 2>&1 >"$rows" )"; RC=$?
      X="$(grep -c . "$rows")" || X=0 ;;
    sen_empty|sen_blank|sen_never|sen_head|sen_l4|sen_exp)
      case "$d" in
        sen_empty) f=empty-file ;; sen_blank) f=blank-file ;; sen_never) f=never-written ;;
        sen_head) f=heading-only ;; sen_l4) f=level4-entry ;; sen_exp) f=expired-still-failing ;;
      esac
      O="$(AI_DLC_PROJECT_ROOT="$WORK" vlt_drive --escalations "$CASES/$f/pending.md" \
             --gate-metrics "$GM_FAILING" --enforcement-map "$MAP" 2>/dev/null)"; RC=$? ;;
    sen_if)
      E="$( AI_DLC_PROJECT_ROOT="$WORK" vlt_drive --in-force --escalations "$CASES/empty-file/pending.md" \
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
      O="$(PATH="$p" AI_DLC_PROJECT_ROOT="$WORK" vlt_drive $m --escalations "$f" \
            --gate-metrics "$GM_FAILING" --enforcement-map "$MAP" 2>"$SR/err")"; RC=$?
      E="$(cat "$SR/err")"
      X=0; [ -s "$SR_STUB/LOG" ] && X=1 ;;
    clkself)
      O="$(vlt_drive --now "$CLK_NOW" --escalations "$CASES/clk-self/pending.md" --gate-metrics "$GM_CLK" \
            --enforcement-map "$MAP" 2>&1)"; RC=$? ;;
    clksup)
      O="$(vlt_drive --now "$CLK_NOW" --escalations "$CASES/clk-sup/pending.md" --gate-metrics "$GM_SL_W" \
            --enforcement-map "$MAP" 2>&1)"; RC=$? ;;
    clkinf)
      # The clock worlds' query drive: stdout (the rows) in O, stderr in E.
      E="$( vlt_drive --in-force --now "$CLK_NOW" --escalations "$CASES/clk-inf/pending.md" --gate-metrics "$GM_SL_W" \
              --enforcement-map "$MAP" 2>&1 >"$WORK/clk-inf.out" )"; RC=$?
      O="$(cat "$WORK/clk-inf.out")" ;;
    sli_*|slw_*)
      # The two query modes on a supersession world: stdout (the rows) in O, stderr in E.
      m="--in-force"; [ "${d%%_*}" = slw ] && m="--waivers"
      E="$( vlt_drive $m --escalations "$CASES/sl-${d#*_}/pending.md" --gate-metrics "$GM_SL_W" \
              --enforcement-map "$MAP" 2>&1 >"$WORK/sl-query.out" )"; RC=$?
      O="$(cat "$WORK/sl-query.out")" ;;
    sl_vd)
      # The T1 world through verdict.sh, as gate-transition.sh arm 2 runs it: the shipping validator by
      # name.
      f="validate-suppression-lifetime"; [ "$v" = "$VALIDATOR" ] || f="$v"
      O="$(vrd_drive "$f" --escalations "$CASES/sl-t1/pending.md" --gate-metrics "$GM_SL_W" \
            --enforcement-map "$MAP" 2>&1)"; RC=$? ;;
    *)
      O="$(vlt_drive --escalations "$CASES/$c/pending.md" --gate-metrics "$gm" \
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

# ---- the metrics-resolution block (arm c31) ------------------------------------
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
ar_c2xi() { dv "$1" c2xi; ! hasF "$C2_HIT" && has 'names an entry archived' && w_quiet 1; }
ar_c2x18() { dv "$1" c2x18; [ "$DV_RC" = "1" ] && hasF "$C2_HIT" && has 'names an entry archived'; }
ar_c2xu() { dv "$1" c2xu; [ "$DV_RC" = "1" ] && hasF "$C2_HIT" && has 'names an entry archived'; }
ar_c2xt() { dv "$1" c2xt; [ "$DV_RC" = "1" ] && hasF "$C2_HIT" && has 'names an entry archived'; }
ar_c2u()  { dv "$1" c2u;  [ "$DV_RC" = "1" ] && hasF "$C2_HIT"; }
ar_c2r()  { dv "$1" c2r;  [ "$DV_RC" = "1" ] && hasF "$C2_HIT"; }
ar_c2m()  { dv "$1" c2m;  [ "$DV_RC" = "1" ] && hasF "$C2_HIT"; }
ar_wsd()  { dv "$1" wsd;  ! hasF 'recorded FAILING' && has 'neither OVERRIDDEN nor SUPPRESSED'; }
# ---- SUPERSESSION (BL-959): a fresh in-force SUPPRESSED entry stands an expired one down ---------
# Every world is on the short timeline (seed.sh, "SUPERSESSION"): OLD past its 1-gate lifetime, NEW
# inside its 3. Each arm reads the exit code AND its own line. The stand-down arms need the ONE
# `WARN: superseded:` line naming both entries; the near-misses need the expiry FAIL on OLD, which a
# silent copy cannot print, and superseded=0 on the summary line.
SLO_S="## $SL_OLD"; SLN_S="## $SL_NEW"; SL_TAB="$(printf '\t')"
sl_n() { grep -qE "[[:space:]]superseded=$1([[:space:]]|\$)" <<<"$DV_O"; }
sl_sup() { # the expiry arm's stand-down line, naming OLD as the expired entry and NEW as the superseder
  local l
  l="$(grep -F "WARN: superseded: check '32' [core] -- expired entry '$SLO_S'" <<<"$DV_O")" || return 1
  grep -qF "stood down by the in-force SUPPRESSED entry '$SLN_S'." <<<"$l"
}
sl_term() { # the terminal twin's stand-down line, naming the OVERRIDDEN entry, OLD as the waiver, NEW
  local l
  l="$(grep -F "WARN: superseded: check '32' [core] -- OVERRIDDEN entry '## $SL_OVR' names it" <<<"$DV_O")" || return 1
  grep -qF "under the expired waiver '$SL_OLD'" <<<"$l" && grep -qF "stood down by the in-force SUPPRESSED entry '$SLN_S'." <<<"$l"
}
sl_expfail() { hasF "$C1_MSG" && hasF "entry: $SLO_S"; }
# The expiry FAIL's own remedy text quotes "WARN: superseded:", so the absence keys on the line START.
sl_near() { dv "$1" "$2"; [ "$DV_RC" = 1 ] && sl_expfail && sl_n 0 && ! has '^WARN: superseded:'; }
sl_stood() { dv "$1" "$2"; [ "$DV_RC" = 0 ] && sl_sup && sl_n 1; }
ar_sl1()   { sl_stood "$1" sl_t1 && hasF 'latest verdict FAIL_WAIVED at row ts'; }
ar_sl1b()  { sl_stood "$1" sl_t1b && hasF 'latest verdict FAIL at row ts'; }
ar_sl2()   { sl_near "$1" sl_t2; }
ar_sl3()   { sl_near "$1" sl_t3; }
ar_sl3b()  { sl_near "$1" sl_t3b && hasF 'suppression fields on an entry that does not classify as SUPPRESSED'; }
ar_sl4()   { sl_near "$1" sl_t4; }
ar_sl5()   { sl_near "$1" sl_t5; }
ar_sl5e()  { sl_stood "$1" sl_t5e; }
ar_sl5s()  { sl_stood "$1" sl_t5s; }
ar_sl6()   { sl_near "$1" sl_t6 && hasF 'is outside the permitted 1..3'; }
ar_sl6b()  { sl_near "$1" sl_t6b && hasF 'missing: **Operator authorization:**'; }
ar_sl6c()  { sl_near "$1" sl_t6c && hasF 'missing: **Expires after:**'; }
ar_sl7()   { sl_near "$1" sl_t7; }
ar_sl8a()  { sl_near "$1" sl_t8a; }
ar_sl8b()  { sl_stood "$1" sl_t8b; }
ar_slf3()  { sl_near "$1" sl_f3; }
ar_sl9()   { sl_near "$1" sl_t9; }
ar_sl11()  { dv "$1" sl_t11;  [ "$DV_RC" = 0 ] && sl_sup && sl_term && sl_n 2; }
# BL-961: OLD is archived in T11b and TQ4, so section 6c now judges it too and NEW stands it down there
# as well -- two WARN lines, superseded=2: the terminal twin's, and the archived waiver's (sl_archsup).
sl_archsup() {
  local l
  l="$(grep -F "WARN: superseded: check '32' [core] -- archived waiver '$SL_OLD'" <<<"$DV_O")" || return 1
  grep -qF "stood down by the in-force SUPPRESSED entry '$SLN_S'." <<<"$l"
}
ar_sl11b() { dv "$1" sl_t11b; [ "$DV_RC" = 0 ] && sl_term && sl_archsup && sl_n 2 && has 'names an entry archived'; }
ar_sl11c() { dv "$1" sl_t11c; [ "$DV_RC" = 1 ] && hasF "$C2_HIT" && sl_expfail && sl_n 0; }
ar_sl11d() { dv "$1" sl_t11d; [ "$DV_RC" = 1 ] && hasF 'a RESOLVED entry names check(s) 32,' && sl_sup && sl_n 1; }
ar_sl11e() { dv "$1" sl_t11e; [ "$DV_RC" = 1 ] && hasF "$C2_HIT" && sl_sup && sl_n 1; }
# TQ: T11b's tree with the archived waiver retargeted. 'names an entry archived' proves the archive was
# read, so the terminal FAIL is the twin declining and never an unresolved waiver.
sl_tqfail() { dv "$1" "$2"; [ "$DV_RC" = 1 ] && hasF "$C2_HIT" && sl_n 0 && ! has '^WARN: superseded:' && has 'names an entry archived'; }
ar_slq1()  { sl_tqfail "$1" sl_tq1; }
ar_slq2()  { sl_tqfail "$1" sl_tq2; }
ar_slq3()  { sl_tqfail "$1" sl_tq3; }
ar_slq4()  { dv "$1" sl_tq4; [ "$DV_RC" = 0 ] && sl_term && sl_archsup && sl_n 2 && has 'names an entry archived'; }
# ---- THE ARCHIVED SUPPRESSED WAIVER (BL-961): section 6c judges it; no OVERRIDDEN entry masks it ----
ar_arch_sup()  { dv "$1" archsup; [ "$DV_RC" = 0 ] && sl_archsup && sl_n 1 && has 'names an entry archived' && ! hasF 'is not in force'; }
ar_arch_over() { dv "$1" archover; [ "$DV_RC" = 1 ] && hasF 'under the ARCHIVED SUPPRESSED' && hasF '**Expires after:** 18,' && hasF 'which is not in force'; }
ar_arch_mis()  { dv "$1" archmis; [ "$DV_RC" = 1 ] && hasF "which suppresses [core] '16' and nothing else" && hasF 'The entry is archived to'; }
ar_arch_ovr()  { dv "$1" warch; w_quiet 1 && hasF 'Not adjudicated.' && ! hasF 'judged as a live'; }
# The LAST entry moved out: an absent or zero-byte pending.md beside an archive does not exit through
# EXAMINED NOTHING; section 6c judges the archived waiver. sen_C is the no-archive twin.
arch_gone_fail() { [ "$DV_RC" = 1 ] && hasF 'under the ARCHIVED SUPPRESSED' && hasF 'which is not in force' && ! hasF 'EXAMINED NOTHING'; }
ar_arch_gx() { dv "$1" archgx; arch_gone_fail && hasF 'NOTE: no escalations file'; }
ar_arch_bx() { dv "$1" archbx; arch_gone_fail && hasF 'NOTE: escalations file present but empty'; }
ar_arch_gi() { dv "$1" archgi; w_quiet 1 && hasF 'judged as a live' && ! hasF 'EXAMINED NOTHING' && ! hasF 'not in force'; }
ar_arch_gd() { dv "$1" archgd; [ "$DV_RC" = 2 ] && grep -q '^REFUSED: escalation archive .* is not a readable regular file' <<<"$DV_O" && ! hasF 'EXAMINED NOTHING'; }
ar_sl12()  { dv "$1" sl_t12;  [ "$DV_RC" = 1 ] && hasF 'no longer reproduces: EXPIRED:32' && sl_sup && sl_n 1; }
ar_slvd()  { # verdict.sh surfaces the WARN line at exit 0, so the gate's evidence names both entries
  local l
  dv "$1" sl_vd; [ "$DV_RC" = 0 ] && has '^PASS  ' || return 1
  l="$(grep -F "'$SLO_S'" <<<"$DV_O")" || return 1
  grep -qF "'$SLN_S'" <<<"$l"
}
# T10: the query modes, row for row (C3: E was already absent from both, so nothing changes).
SL_IF_ROW="core${SL_TAB}32${SL_TAB}3${SL_TAB}2${SL_TAB}${A1} | ${SL_Q_NEW}${SL_TAB}${SLN_S}"
SL_WV_ROW="SUPPRESSED${SL_TAB}core${SL_TAB}32${SL_TAB}3${SL_TAB}${A1} | ${SL_Q_NEW}${SL_TAB}${SL_NEW}"
SL_WV_OVR="OVERRIDDEN${SL_TAB}${SL_TAB}${SL_TAB}${SL_TAB}${A1} | ${SL_Q_NEW}${SL_TAB}${SL_OVR}"
sl_q() { dv "$1" "$2"; [ "$DV_RC" = 0 ] && [ "$DV_O" = "$3" ] && grep -qE "$4" <<<"$DV_E"; }
ar_sl10i() { sl_q "$1" sli_t1 "$SL_IF_ROW" '^IN-FORCE: .* in_force=1 ' && sl_q "$1" sli_t11 "$SL_IF_ROW" '^IN-FORCE: .* in_force=1 '; }
ar_sl10w() { sl_q "$1" slw_t1 "$SL_WV_ROW" '^WAIVERS: .* waivers=1 ' && sl_q "$1" slw_t11 "$SL_WV_ROW
$SL_WV_OVR" '^WAIVERS: .* waivers=2 '; }
# F2: NEW is excluded by the condition each near-miss names, NOT by its lifetime: --in-force lists it
# where that condition is not the lifetime, and does not where it is (T6/T6b/T6c/T7).
sl_lists_new() { dv "$1" "$2"; [ "$DV_RC" = 0 ] && grep -q '^IN-FORCE: ' <<<"$DV_E" && grep -qF "${SL_TAB}${SLN_S}" <<<"$DV_O"; }
sl_omits_new() { dv "$1" "$2"; [ "$DV_RC" = 0 ] && grep -q '^IN-FORCE: .* in_force=0 ' <<<"$DV_E" && ! grep -qF "$SLN_S" <<<"$DV_O"; }
ar_slinf()  { sl_lists_new "$1" sli_t1 && sl_lists_new "$1" sli_t4 && sl_lists_new "$1" sli_t5 && sl_lists_new "$1" sli_t8a; }
ar_slinfx() { sl_omits_new "$1" sli_t6 && sl_omits_new "$1" sli_t6b && sl_omits_new "$1" sli_t6c && sl_omits_new "$1" sli_t7; }
# T3's NEW is OVERRIDDEN, which --in-force never lists: --waivers lists it as an OVERRIDDEN row.
ar_slw3()   { dv "$1" slw_t3; [ "$DV_RC" = 0 ] && grep -qxF "OVERRIDDEN${SL_TAB}${SL_TAB}${SL_TAB}${SL_TAB}${A1} | ${SL_Q_NEW}${SL_TAB}${SL_NEW}" <<<"$DV_O"; }
# ---- THE CLOCK (BL-966): every drive passes --now $CLK_NOW, a fixed literal ------------------------
# clkself: the future-dated self-waiver fails by the gate-mode shape arm's own line, and the summary
# names the clock and its source. clksup: a future-dated NEW supersedes nothing (OLD's expiry FAIL,
# superseded=0). clk_past/clk_tol/clk_far: --in-force lists the past and the one-hour-ahead entries
# and not the 2099 one, each arm asking about ONE entry and the past one as its positive conjunct.
clk_lists() { grep -qF "${SL_TAB}## $1" <<<"$DV_O"; }
clk_q() { dv "$1" clkinf; [ "$DV_RC" = 0 ] && grep -q "^IN-FORCE: .* now=$CLK_NOW clock=--now " <<<"$DV_E"; }
ar_clkself() { dv "$1" clkself; [ "$DV_RC" = 1 ] && hasF "**Operator authorization:** ${CLK_F%Z} is later than the clock, $CLK_NOW (--now)," \
                && hasF "entry: ## [S402 gate — a self-waiver dated in the future]" && hasF " now=$CLK_NOW clock=--now"; }
ar_clksup()  { dv "$1" clksup; [ "$DV_RC" = 1 ] && sl_expfail && sl_n 0 && ! has '^WARN: superseded:'; }
ar_clk_past() { clk_q "$1" && clk_lists "$CLK_HP"; }
ar_clk_tol()  { clk_q "$1" && clk_lists "$CLK_HP" && clk_lists "$CLK_HT"; }
ar_clk_far()  { clk_q "$1" && clk_lists "$CLK_HP" && ! clk_lists "$CLK_HF"; }
CLK_ARMS="clkself clksup clk_past clk_tol clk_far"
ARCH_ARMS="arch_sup arch_over arch_mis arch_ovr"
ARCHG_ARMS="arch_gx arch_bx arch_gi arch_gd"
SL_ARMS="sl1 sl1b sl2 sl3 sl3b sl4 sl5 sl5e sl5s sl6 sl6b sl6c sl7 sl8a sl8b slf3 sl9 sl11 sl11b sl11c sl11d sl11e slq1 slq2 slq3 slq4 sl12 slvd sl10i sl10w slinf slinfx slw3"

ARMS="s1 s2 s2m s3 s4 s4m s5 s6 s7 s8 s9 s9z s11 s12 s13a s13b s14 s15 s16 s17 s18 t18a t18b t18c t18d ident cand att17a att17b att17c att18 att19 att20 cwA_gates cwA_inf cwA_met cwA_agree cwA_root cwB_note cwB_inf cwB_gates c31 sen_A sen_B sen_C sen_D sen_E sen_F sr_Ag sr_Ai sr_Bg sr_Bi sr_Cg sr_Dg sr_Di sr_Eg sr_Ei sr_Fg w1 w1b w2 w3 w4 w5 w6 w7 w8 c1 c1b c1u c2ab c2ba c2a c2s c2x c2xi c2x18 c2xu c2xt c2u c2r c2m wsd $SL_ARMS $CLK_ARMS $ARCH_ARMS $ARCHG_ARMS"

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
reg c2xi "C2: an OVERRIDDEN entry naming 32 is quiet when the row's waiver is an ARCHIVED SUPPRESSED entry of 32 still inside its own lifetime" "C2: an archived in-force suppression did not stand the OVERRIDDEN entry down -- the lifetime clause was read as a live-file test"
reg arch_sup "ARCHIVE (BL-961): an archived expired SUPPRESSED waiver is stood down by an in-force re-suppression in pending.md, with the WARN: superseded: line naming both, superseded=1, rc 0" "ARCHIVE (BL-961): an archived expired waiver with a live in-force re-suppression was not stood down -- section 6c skipped supersession"
reg arch_over "ARCHIVE (BL-961): an archived SUPPRESSED waiver with **Expires after:** 18, inside that count, FAILS as not in force" "ARCHIVE (BL-961): an archived over-cap waiver passed -- section 6c judged it by sl_past_lifetime, or not at all"
reg arch_mis "ARCHIVE (BL-961): an archived in-force SUPPRESSED waiver of [core] 16 on check 32's row FAILS the target test" "ARCHIVE (BL-961): an archived waiver of another check passed -- section 6c skipped the target test for an archived entry"
reg arch_ovr "ARCHIVE (BL-961): an archived OVERRIDDEN waiver keeps its NOTE and passes (Not adjudicated.)" "ARCHIVE (BL-961): an archived OVERRIDDEN waiver was judged -- the archive branch is over-broad"
reg arch_gx "ARCHIVE: pending.md ABSENT beside an archived SUPPRESSED waiver past its lifetime FAILS -- section 6c runs, no EXAMINED NOTHING" "ARCHIVE: an absent pending.md acquitted an expired archived waiver -- the early exit returned before section 6c"
reg arch_bx "ARCHIVE: pending.md ZERO BYTES beside an archived SUPPRESSED waiver past its lifetime FAILS -- section 6c runs, no EXAMINED NOTHING" "ARCHIVE: a blank pending.md acquitted an expired archived waiver -- the early exit returned before section 6c"
reg arch_gi "ARCHIVE: pending.md ABSENT beside an archived SUPPRESSED waiver inside its lifetime passes after section 6c judged it (waived_rows=1)" "ARCHIVE: an absent pending.md beside an in-force archived waiver did not pass through section 6c"
reg arch_gd "ARCHIVE: pending.md ABSENT and pending-archive.md a DIRECTORY is REFUSED, exit 2" "ARCHIVE: a non-regular archive was not refused -- a skipped read reads as clean"
reg clkself "CLOCK (BL-966): a future-dated SUPPRESSED entry that is itself the waiver on its check's FAIL_WAIVED row FAILS by name at the gate, and the summary names the clock (--now)" "CLOCK (BL-966): a self-waiver authorized in 2099 passed the gate -- it counts 0 gates until 2099 and would stay green forever"
reg clksup "CLOCK (BL-966): a future-dated NEW supersedes nothing -- OLD's expiry FAIL stands, superseded=0" "CLOCK (BL-966): an entry authorized in 2099 stood an expired one down -- sl_in_force took it as in force"
reg clk_past "CLOCK (BL-966): --in-force lists an entry authorized in the past, inside its lifetime" "CLOCK (BL-966): a past-dated in-force entry was not listed -- the clock comparison is reversed"
reg clk_tol "CLOCK (BL-966): --in-force lists an entry authorized one hour ahead of the clock, inside the 7200 s tolerance" "CLOCK (BL-966): an entry one hour ahead was refused -- the tolerance for hand-typed stamps is gone"
reg clk_far "CLOCK (BL-966): --in-force does not list an entry authorized in 2099" "CLOCK (BL-966): an entry authorized in 2099 was listed in force -- the clock does not bound sl_in_force, or the tolerance is unbounded"
reg c2x18 "C2 (BL-968): an OVERRIDDEN entry naming 32 FIRES when the row's waiver is an ARCHIVED SUPPRESSED entry of 32 with **Expires after:** 18, inside that count but outside the 1..3 cap" "C2 (BL-968): an archived over-cap suppression stood an OVERRIDDEN entry down -- the acquittal skipped the 1..3 cap sl_in_force holds"
reg c2xu "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver is an archived SUPPRESSED entry of 32 with NO Expires after line" "C2: a suppression whose expiry cannot be read stood an OVERRIDDEN entry down -- the lifetime guard fails open"
reg c2xt "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver is an archived SUPPRESSED entry of 32 with NO authorization timestamp" "C2: a suppression whose authorization cannot be dated stood an OVERRIDDEN entry down -- the lifetime guard fails open"
reg c2u "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver resolves nowhere" "C2: an unresolvable waiver stood an OVERRIDDEN entry down"
reg c2r "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver is a RESOLVED entry" "C2: a RESOLVED waiver stood an OVERRIDDEN entry down"
reg c2m "C2: an OVERRIDDEN entry naming 32 FIRES when the row's waiver is a SUPPRESSED entry of another check" "C2: a mis-targeted SUPPRESSED waiver stood an OVERRIDDEN entry down"
reg wsd "own-entry stand-down: a RESOLVED entry naming 32 is quiet when the row's waiver_id is its own header plus a trailing blank" "own-entry stand-down: the entry that IS the waiver fired -- the own-entry compare does not strip the row id"
reg sl1 "T1: an expired SUPPRESSED entry whose latest row is its own FAIL_WAIVED is stood down by a fresh in-force entry for [core] 32 -- exit 0, one WARN: superseded: line naming both, superseded=1" "T1: the fresh authorization did not stand the expired entry down (or did so silently) -- the cure the FAIL message names can never clear the re-fire"
reg sl1b "T1b: the same with the latest row a plain FAIL -- exit 0, superseded=1" "T1b: a plain FAIL latest row was not stood down by the fresh authorization"
reg sl2 "T2 (a): a fresh entry only in pending-archive.md supersedes nothing -- the expiry FAIL on OLD stands" "T2 (a): an ARCHIVED entry stood the expired entry down -- an archived entry is terminal and authorizes nothing new"
reg sl3 "T3 (b): a fresh entry that is OVERRIDDEN, not SUPPRESSED, supersedes nothing" "T3 (b): a non-SUPPRESSED entry stood the expired entry down"
reg sl3b "T3b (b): a fresh entry carrying every suppression field under OVERRIDDEN supersedes nothing (and is reported as an attempt)" "T3b (b): a non-SUPPRESSED entry carrying suppression fields stood the expired entry down -- the status test is gone"
reg sl4 "T4 (c1): a fresh entry suppressing another check (16) supersedes nothing" "T4 (c1): a suppression of a DIFFERENT check stood the expired entry down"
reg sl5 "T5 (c2): a fresh [extension:probe] 32 supersedes nothing for [core] 32" "T5 (c2): a suppression in another CATALOG stood the expired entry down"
reg sl5e "T5 twin: OLD with NO bracket is stood down by NEW [core] 32 -- an empty bracket reads as core" "T5 twin: an unbracketed expired entry was not stood down by [core] -- the core default is missing on the expired side"
reg sl5s "T5 twin: NEW with NO bracket stands OLD [core] 32 down -- an empty bracket reads as core" "T5 twin: an unbracketed fresh entry did not stand [core] down -- the core default is missing on the superseder side"
reg sl6 "T6 (d): a fresh entry with **Expires after:** 5 supersedes nothing (and fails its own range check)" "T6 (d): an out-of-range lifetime stood the expired entry down"
reg sl6b "T6b (d): a fresh entry with no authorization timestamp supersedes nothing" "T6b (d): an undated authorization stood the expired entry down -- an empty timestamp counts as in force"
reg sl6c "T6c (d): a fresh entry with no **Expires after:** supersedes nothing" "T6c (d): an entry with no lifetime stood the expired entry down"
reg sl7 "T7 (e): a fresh entry itself past its lifetime supersedes nothing" "T7 (e): an EXPIRED superseder stood the expired entry down -- the lifetime of the superseder was never asked"
reg sl8a "T8a (f): an entry re-citing OLD's authorization timestamp under a new header and quote supersedes nothing" "T8a (f): a re-citation of the same operator turn stood the expired entry down"
reg sl8b "T8b (f): a new timestamp with OLD's quote IS a fresh turn and stands OLD down" "T8b (f): a fresh timestamp with a copied quote did not stand down -- the turn is keyed on the quote, not the timestamp"
reg slf3 "F3 (b): a second entry under OLD's own header (OLD's waiver key) supersedes nothing" "F3 (b): an entry sharing the expired entry's waiver key stood it down -- the entry superseded itself"
reg sl9 "T9: OLD alone on the same timeline still FAILS past its lifetime, superseded=0 (the control)" "T9: OLD alone no longer fails -- every stand-down arm above agrees for free"
reg sl11 "T11: the OVERRIDDEN entry naming 32 under OLD's expired waiver is stood down by NEW too -- exit 0, superseded=2 (the expiry arm and the terminal twin each count one)" "T11: the terminal twin did not stand down (or the count is not 2)"
reg sl11b "T11b: with OLD archived the terminal twin stands down, and section 6c stands the archived waiver down too (BL-961) -- exit 0, superseded=2" "T11b: the terminal twin did not stand down through an archived expired waiver"
reg sl11c "T11c: with no fresh entry the OVERRIDDEN entry and the expiry both still FAIL" "T11c: without a superseder the OVERRIDDEN entry or the expiry stopped firing"
reg sl11d "T11d: a RESOLVED entry naming 32 still FAILS with NEW present -- RESOLVED keeps exact match only" "T11d: a fresh suppression acquitted a RESOLVED entry naming a still-failing check"
reg sl11e "T11e: over a plain FAIL row the OVERRIDDEN entry naming 32 still FAILS; only the expiry stands down" "T11e: a plain FAIL row acquitted the OVERRIDDEN entry -- the terminal twin is not keyed on FAIL_WAIVED"
reg slq1 "TQ1: a waiver suppressing [core] 16, expired, stands nothing down for 32 -- the OVERRIDDEN entry FAILS" "TQ1: the terminal twin stood down through a waiver whose target is another check"
reg slq2 "TQ2: a waiver suppressing [extension:x] 32 stands nothing down for [core] 32 -- the OVERRIDDEN entry FAILS" "TQ2: the terminal twin stood down through a waiver in another catalog"
reg slq3 "TQ3: a waiver suppressing [core] 16, in force, stands nothing down for 32 -- the OVERRIDDEN entry FAILS" "TQ3: the terminal twin stood down through an in-force waiver of another check"
reg slq4 "TQ4: a [core] 32 waiver with no readable lifetime reads as expired -- the terminal twin stands down, and so does section 6c on the archived waiver (BL-961), superseded=2" "TQ4: an unreadable waiver lifetime was not read as expired, so the twin did not stand down"
reg sl12 "T12: a baselined EXPIRED:32 whose only cause was superseded reports 'no longer reproduces'" "T12: a stood-down entry matched its EXPIRED baseline key, so the stale baseline line was tolerated"
reg slvd "the T1 world through verdict.sh: PASS at exit 0, and one surfaced line names both entries" "verdict.sh did not surface the stand-down at exit 0 -- the gate's evidence is silent on the supersession"
reg sl10i "T10: --in-force on the T1 and T11 trees prints exactly NEW's row" "T10: --in-force output moved -- E must stay absent and NEW's row unchanged"
reg sl10w "T10: --waivers on the T1 and T11 trees prints exactly NEW's SUPPRESSED row (and the OVERRIDDEN row on T11)" "T10: --waivers output moved"
reg slinf "F2: --in-force LISTS NEW in T1, T4, T5 and T8a -- each near-miss is excluded by its own condition, not by NEW's lifetime" "F2: --in-force does not list NEW in a near-miss world -- that arm is acquitted by the lifetime, not by the condition it names"
reg slinfx "F2: --in-force does NOT list NEW in T6, T6b, T6c and T7 (in_force=0)" "F2: --in-force listed a malformed or expired NEW"
reg slw3 "F2: T3's OVERRIDDEN NEW is listed by --waivers as an OVERRIDDEN row" "F2: --waivers does not list T3's OVERRIDDEN NEW"

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
  bad "the metrics-resolution anchor matched $SL_SEC2_N times (control $SL_SEC2_MISS) — arm c31 would count an empty block"
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
# The supersession arms likewise: an installed validator that predates BL-959 prints no superseded=
# field, fails T1 and still fails the T9 control.
if in_set sl1 "$SHIP_FAIL" && in_set sl9 "$SHIP_PASS" && ! grep -qF 'superseded=' "$VALIDATOR" && [ "$SEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the supersession arms -- the installed validator predates BL-959; this fixture ships one pull ahead of it\n'
  SKIPPED="$SKIPPED $SL_ARMS "
fi
# The last-entry archive arms likewise: an installed validator that predates them exits through
# EXAMINED NOTHING beside an archive, so all four read 0 while the no-archive twin sen_C holds.
SAG_PRE=1
for a in $ARCHG_ARMS; do in_set "$a" "$SHIP_FAIL" || SAG_PRE=0; done
in_set sen_C "$SHIP_PASS" || SAG_PRE=0
if [ "$SAG_PRE" = 1 ] && ! grep -qF 'SL_ARCH_GATE' "$VALIDATOR" && [ "$SEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the last-entry archive arms -- the installed validator predates them; this fixture ships one pull ahead of it\n'
  SKIPPED="$SKIPPED $ARCHG_ARMS "
fi
for a in $ARMS; do
  in_set "$a" "$SKIPPED" && continue
  if in_set "$a" "$SHIP_PASS"; then
    _m="OK_$a"; while IFS= read -r _l; do ok "$_l"; done <<<"${!_m}"
  else
    _m="BAD_$a"; bad "${!_m}"
  fi
done
# BL-959's receipt, a fixture-local library sourced here (not a declared subject: nothing outside this fixture reads it):
# the T1 world and the T9 control in one call, against the validator it resolves by walking up from its own directory; its
# `bash <validator>` starts route through run.sh's `bash` shim.
. "$RCPT" || { echo "FIXTURE ERROR: cannot source $RCPT" >&2; exit 2; }
declare -F r959_main >/dev/null 2>&1 || { echo "FIXTURE ERROR: $RCPT defines no r959_main (not loadable)" >&2; exit 2; }
SL_RCPT_O="$(r959_main 2>&1)"; SL_RCPT_RC=$?
if in_set sl1 "$SKIPPED"; then
  printf '  SKIP  receipt-bl959 -- the installed validator predates BL-959\n'
elif [ "$SL_RCPT_RC" = 0 ] && grep -qxF 'receipt-bl959: PASS' <<<"$SL_RCPT_O"; then
  ok "receipt-bl959: T1 stands down with the WARN line naming both entries, and the T9 control still fails"
else
  bad "receipt-bl959 exited $SL_RCPT_RC: $(printf '%s' "$SL_RCPT_O" | tr '\n' ' ')"
fi

# --- the cli cells (cells.decl): each program run as a PROGRAM once per distinct CLI outcome --------------------------
# One `FXCELL=<id> bash <subject>` start per outcome, compared with the in-process answer on the same input (stdout+stderr
# merged and exit, byte for byte); a cell asserts its own outcome too, so two runs that both printed nothing cannot read as
# equivalent.
EQ="$WORK/eq"; mkdir -p "$EQ"
cell() { # <id> <subject> <drive fn> <args...> -> $EQ/<id>.{ip,cl}.{out,rc}
  local id="$1" subj="$2" fn="$3"; shift 3
  "$fn" "$@" > "$EQ/$id.ip.out" 2>&1; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" command bash "$subj" "$@" > "$EQ/$id.cl.out" 2>&1; echo "$?" > "$EQ/$id.cl.rc"
}
cell_ok() { # <id> <rc> <text the answer names>
  if cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc" && [ "$(cat "$EQ/$1.cl.rc")" = "$2" ] && grep -qF -- "$3" "$EQ/$1.cl.out"; then
    ok "$1: the program matches the in-process answer (exit $2, names '$3')"
  else bad "$1: the program and the in-process call disagree (rc cl=$(cat "$EQ/$1.cl.rc") ip=$(cat "$EQ/$1.ip.rc"), wanted $2 naming '$3'; first line: $(head -n 1 "$EQ/$1.cl.out" | cut -c1-160))"; fi
}
cell cli-vlt-ok "$VALIDATOR" vlt_drive --escalations "$CASES/expired-but-fixed/pending.md" --gate-metrics "$GM_FIXED" --enforcement-map "$MAP"
cell cli-vlt-fail "$VALIDATOR" vlt_drive --escalations "$CASES/expired-still-failing/pending.md" --gate-metrics "$GM_FAILING" --enforcement-map "$MAP"
cell cli-vlt-refuse "$VALIDATOR" vlt_drive --escalations "$CASES/expired-still-failing/pending.md" --gate-metrics "$GM_FAILING" --enforcement-map "$WORK/nope.yaml"
cell cli-vrd-pass "$VERDICT" vrd_drive validate-suppression-lifetime --escalations "$CASES/sl-t1/pending.md" --gate-metrics "$GM_SL_W" --enforcement-map "$MAP"
cell cli-vrd-fail "$VERDICT" vrd_drive validate-suppression-lifetime --escalations "$CASES/expired-still-failing/pending.md" --gate-metrics "$GM_FAILING" --enforcement-map "$MAP"
cell_ok cli-vlt-ok 0 'OK: entries_scanned=1 suppressed=1'
cell_ok cli-vlt-fail 1 'is past its lifetime'
cell_ok cli-vlt-refuse 2 'FAIL: enforcement-map.yaml not found'
cell_ok cli-vrd-pass 0 'PASS  validate-suppression-lifetime.sh'
cell_ok cli-vrd-fail 1 'FAIL  validate-suppression-lifetime.sh'
echo "DRIVE-COUNT validator runs=$DRIVES"

echo
report_end suppression-lifetime
