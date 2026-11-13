#!/usr/bin/env bash
# backlog-receipt-efficiency -- the efficiency-close arms of scripts/validate-backlog-receipts.sh (BL-817: E1 close,
# E2 shape, E3 filing, the b255 F2b verdict grammar, the D2 archive scope and the item (d) value citation), and the
# twenty-eight mutants behind them. Split out of core/fixtures/backlog-receipt-binding/run.sh (BL-982) so that file's
# pole cost falls by this block and the two run in parallel. Distribution-only: its .dist-only says why.
#
# THE HARNESS IS backlog-receipt-binding's, SOURCED. This file sources core/fixtures/backlog-receipt-binding/run.sh,
# whose BASH_SOURCE guard returns just after mut() -- after every helper (seed and seed_build, vin, cli_v, mut, record,
# side, cell, the r_* readers, cls, run_v, $DEF) and lib/mutant.sh and lib/matrix.sh are defined, and before that
# file's own control world is seeded or any cell has run. Everything below the source line is this fixture's own: its
# score() (it overrides the sourced one), its arms, its worlds and mutants, its twin table, its --matrix block and its
# PASS line. Its arms are enumerated from THIS file's text, never through the sourced all_arms, which reads every
# arm_* in the process. The seeded repository template is built once per run (seed_build under $TMP/.seed-tpl, the
# sourced file's own $TMP) and copied into each world.
#
# THE CONTROLS ARE THIS FILE'S. Each ef_world / ef_filing / ef_sac / ef_arch call is the unmutated control of the
# world it names and sets that world's B_ef_* flag; every mutant is scored against the flag of its own world, set in
# this run. VEQ-eff runs the validator end to end (`bash <copy>`) on ef-good (exit 0) and ef-noclose (exit 1) and
# compares each byte for byte with the in-process answer; those two CLI starts are this fixture's only validator
# starts and are its two `cli` cells (cells.decl), tagged through cli_v's env words (FXCELL=veq-eff-<world>).
#
# The mutant matrix: each mutant is scored on its DECIDING ARM plus ONE named TWIN, an arm the measured matrix shows
# GREEN under it, read off the same capture. `--matrix` captures every mutant once and scores it on every arm this
# file defines. The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct
# state") requires. Measured (--matrix, 28 captures x 17
# arms): every row's deciding arm TRIPPED and its twin GREEN. The twelve mutants E0 refuses before any world is
# read twinned on m6 while they lived in backlog-receipt-binding; arm_m6 stays in that file's text, and a twin must
# be a label THIS fixture emits (validate-fixture-hygiene H7), so they twin on m_vprose, another E0-refusal arm,
# which the matrix shows GREEN on all twelve captures.
#
# MUTANT-MATRIX m-noclose decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-widenostep decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-nopathnarrow decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-noseat decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-seatword decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-nofiling decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-noscript decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-nofigs decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-nostep decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-nobaseline decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-nomovement decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-noscope decides=m_noscript twins=m_vprose
# MUTANT-MATRIX m-vprose decides=m_vprose twins=m_nooffstep
# MUTANT-MATRIX m-nooffstep decides=m_nooffstep twins=m_vprose
# MUTANT-MATRIX m-nostepbound decides=m_nostepbound twins=m_notokens
# MUTANT-MATRIX m-notokens decides=m_notokens twins=m_nostepbound
# MUTANT-MATRIX m-nosac decides=m_nosac twins=m_nosacderive
# MUTANT-MATRIX m-nosacderive decides=m_nosacderive twins=m_nosac
# MUTANT-MATRIX m-noconflict decides=m_noconflict twins=m_nosac
# MUTANT-MATRIX m-noarchlive decides=m_noarchlive twins=m_noconflict
# MUTANT-MATRIX m-noarchscope decides=m_noarchscope twins=m_noarchxbase
# MUTANT-MATRIX m-noarchxbase decides=m_noarchxbase twins=m_noarchscope
# MUTANT-MATRIX m-d1 decides=m_d1 twins=m_d2
# MUTANT-MATRIX m-d2 decides=m_d2 twins=m_d1
# MUTANT-MATRIX m-d3 decides=m_d3 twins=m_d4
# MUTANT-MATRIX m-d4 decides=m_d4 twins=m_d3
# MUTANT-MATRIX m-d5 decides=m_d5 twins=m_d6
# MUTANT-MATRIX m-d6 decides=m_d6 twins=m_d5
# MUTANT-MATRIX-DYNAMIC score why=score passes its first argument to mutant_killed; every score call names a literal mutant that carries its own row in this block
# MUTANT-MATRIX-REMEASURE bash core/fixtures/backlog-receipt-efficiency/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit:  0 = every world holds and every mutant is killed, 1 = one regressed, 2 = fixture broken.
set -u
# Every ambient AI_DLC_* key cleared before anything runs (the sourced file clears them again; H8 reads this file).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
EDIR="$(cd "$(dirname "$0")" && pwd)"
BRB="$EDIR/../backlog-receipt-binding/run.sh"
[ -f "$BRB" ] || { echo "backlog-receipt-efficiency: FIXTURE BROKEN -- $BRB is absent, so there is no harness to drive the validator with" >&2; exit 2; }
# Sourcing the old run.sh is an in-process pass of a declared bash subject, so it is counted (fx_inproc, an `inproc:`
# row, P1's pairing). fx_inproc lives in lib/mutant.sh, which the sourced file loads only later, so it is loaded here
# first behind throwaway ok/bad stubs (its load guard requires them) and the stubs are dropped, so the harness check
# below still proves the sourced file defined the real ones.
[ -f "$EDIR/../lib/mutant.sh" ] || { echo "backlog-receipt-efficiency: FIXTURE BROKEN -- lib/mutant.sh is absent beside $EDIR" >&2; exit 2; }
ok() { :; }; bad() { :; }
. "$EDIR/../lib/mutant.sh"
unset -f ok bad
fx_inproc "$BRB"
# shellcheck source=/dev/null
. "$BRB" || { echo "backlog-receipt-efficiency: FIXTURE BROKEN -- sourcing backlog-receipt-binding/run.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/backlog-receipt-binding/run.sh"
# Set here, not inherited from the sourced file's read of the positional parameters.
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
# The sourced file must have stopped at its guard with the whole harness defined and no world built. (lib/mutant.sh
# and lib/matrix.sh are its guarded sources: it exits 2 before the guard if either is absent.)
for _f in seed seed_build vin cli_v run_v mut record side cell r_rc r_has r_line note ok bad; do
  declare -F "$_f" >/dev/null || { echo "backlog-receipt-efficiency: FIXTURE BROKEN -- the sourced harness defined no $_f()" >&2; exit 2; }
done
[ -n "${TMP:-}" ] && [ -d "$TMP" ] && [ -d "${REC:-}" ] || { echo "backlog-receipt-efficiency: FIXTURE BROKEN -- the sourced harness made no \$TMP / \$REC" >&2; exit 2; }
[ ! -e "$TMP/control" ] || { echo "backlog-receipt-efficiency: FIXTURE BROKEN -- the sourced file ran past its guard (its control world exists)" >&2; exit 2; }

# --- the mutant scorer (this file's own; it overrides the sourced score()) -------------------------
# score <mutant> <base-pass flag> <message> [arm]   (arm defaults to the mutant's name, dashes to underscores)
score() {
  local m="$1" f="$2" a="${4:-${1//-/_}}"
  SCORED="$SCORED $m"
  if "arm_$a" "$m"; then mutant_killed "$f" "$m" "$3"
  else bad "$m SURVIVED: its deciding arm $a did not trip -- rc=$(r_rc "$m")"; sed -n '1,3p' "$REC/$m.out" | sed 's/^/      /'; fi
}

# ARMS. Each is the kill condition for its mutant, read off that mutant's capture.
# The efficiency arm: every one of the twelve efficiency mutants is caught by the subject's own E0
# self-probe refusing (exit 2). The kill matrix measured all twelve per-mutant arms tripping on the
# same twelve captures, each through E0, so BL-918 keeps this one and every efficiency mutant decides on it.
ef_e0() { [ "$(r_rc "$1")" = 2 ] && r_has "$1" 'SELF-PROBE FAILED -- E0'; }
arm_m_noscript() { ef_e0 "$1"; }
# The verdict-grammar mutants (b255 F2b). ef_e0_lacks <capture> <row>: E0 refused with its REPORTED
# vs EXPECTED message, the expected list carries <row>, the reported list does not, and the reported
# list still carries SHAPE BL-957 -- so the counts refusal (other text) and a mutant emptying the
# whole close population (m-noclose) trip none of these arms.
ef_e0_lacks() {
  local l g w
  ef_e0 "$1" || return 1
  l="$(grep -F 'SELF-PROBE FAILED -- E0: the efficiency arms over the seeded ledger reported [' "$REC/$1.out" | sed -n '1p')"
  [ -n "$l" ] || return 1
  g="${l#*"reported ["}"; g="${g%%"], expected ["*}"; w="${l#*"], expected ["}"
  case "|$w" in *"|$2|"*) ;; *) return 1 ;; esac
  case "|$g" in *"|$2|"*) return 1 ;; esac
  case "|$g" in *"|SHAPE BL-957|"*) return 0 ;; esac
  return 1
}
arm_m_vprose() { ef_e0_lacks "$1" "NO-DIRECTION BL-1005"; }
arm_m_nooffstep() { ef_e0_lacks "$1" "OFF-STEP BL-1008"; }
arm_m_nostepbound() { ef_e0_lacks "$1" "NO-STEP-BOUND BL-1002"; }
arm_m_notokens() { ef_e0_lacks "$1" "NO-TOKENS BL-1000"; }
arm_m_nosac() { ef_e0_lacks "$1" "STEP-AT-CLOSE BL-1012"; }
arm_m_noconflict() { ef_e0_lacks "$1" "VERDICT-CONFLICT BL-1057"; }
# D2 (b255 F2b). m-noarchlive is refused by E0's own archive refusal (a message of its own, not the
# reported/expected list); m-noarchscope and m-noarchxbase pass E0, so their kills are the archive
# worlds, each presence-shaped: a full --archive OK with no BL-981 row, and a STEP-AT-CLOSE BL-981 row.
arm_m_noarchlive() { ef_e0 "$1" && r_has "$1" 'did not judge BL-1059, an archive entry added since the merge-base'; }
arm_m_noarchscope() { r_line "$1" "SIDE world=arch" && [ "$(r_rc "$1")" = 0 ] && r_has "$1" 'OK: validate-backlog-receipts --archive' && ! grep -qE '^FAIL: E.BL-981.NO-TOKENS' "$REC/$1.out"; }
arm_m_noarchxbase() { r_line "$1" "SIDE world=archq" && [ "$(r_rc "$1")" = 1 ] && grep -qE '^FAIL: E.BL-981.STEP-AT-CLOSE$' "$REC/$1.out"; }
# Item (d): each citation-rule mutant is keyed on its own E0 fire seed (BL-1046..1052).
arm_m_d1() { ef_e0_lacks "$1" "VALUE-NULL BL-1046"; }
arm_m_d2() { ef_e0_lacks "$1" "VALUE-NULL BL-1047"; }
arm_m_d3() { ef_e0_lacks "$1" "VALUE-NULL BL-1048"; }
arm_m_d4() { ef_e0_lacks "$1" "VALUE-NULL BL-1049"; }
arm_m_d5() { ef_e0_lacks "$1" "VALUE-NULL BL-1050"; }
arm_m_d6() { ef_e0_lacks "$1" "VALUE-NULL BL-1052"; }
# m-nosacderive passes E0, so its kill is the ef-sac world itself reading a full OK against a real
# merge-base with no STEP-AT-CLOSE row (presence-shaped: the OK line and the scope must APPEAR).
arm_m_nosacderive() { r_line "$1" "SIDE world=sac" && [ "$(r_rc "$1")" = 0 ] && r_has "$1" 'OK: validate-backlog-receipts --efficiency-only' && r_has "$1" 'against merge-base' && ! grep -qE '^FAIL: E.BL-981.STEP-AT-CLOSE' "$REC/$1.out"; }

# ===== THE EFFICIENCY ARMS (BL-817): E1 close, E2 shape, E3 filing. =========================
# Driven through `--efficiency-only` on seeded ledgers, which runs the subject's own E0 self-probe
# and then the arms, and exits before the per-receipt checkout scorer. Every world is one entry;
# every verdict is read off the subject's own `FAIL: E<TAB><id><TAB><code>` rows, so each arm is
# PRESENCE-shaped: an expected row must APPEAR, and the quiet twin must carry the OK line.
#   ef-good     a valid close, a valid no-step close, a tagged entry citing the ruling, an untagged
#               docs/analysis/ citer carrying the no-step line, and a section preamble citing
#               docs/analysis/ after an entry (the narrowing) -> OK, zero rows
#   ef-noclose  a tagged LANDED entry with no outcome line                     -> NO-OUTCOME
#   ef-sprintless a sprintless line WITHOUT the no-step wording              -> NO-SPRINT
#   ef-untagged an untagged entry citing docs/analysis/                         -> F-UNTAGGED
#   ef-noseat   a sprint-branch line with all three labels and the words lead/subagent but only a
#               percentage and a call count beside them (no `<n> h` / `$<n>` seat figure) -> SHAPE
#   ef-second   the second spelling of a valid line (bold label, `sprint 321`, a Failure caught:
#               citation resolved by its phrase)                                -> OK
# Mutants (copies, cmp-guarded through `mut`): m-noclose removes the close arm's population test,
# m-widenostep widens the no-step branch to accept any sprintless line, m-nofiling removes the
# untagged-citing refusal. Each must turn exactly its own world red; E0 is part of the subject, so
# a mutant the self-probe catches exits 2 -- which is a kill BY THE SELF-PROBE, asserted as such.
EF_RUL='Cites "A step with no measured value goes" in `.claude/rules/operator-rulings.md`.'
EF_SEAT='token-equivalent $9 with API $8 beside it, 1.0 h gap-inclusive, 2.1M tokens, lead active 0.4 h, subagent $5'
# The verdict grammar (b255 F2b) on a passing live sprint-branch close: a Step: line and a Verdict field
# naming that step. The token figure above is roll.py seat_line's `<x.1f>M tokens` form.
EF_SV='

Step: implementation

Verdict: implementation fell.'
EF_SHP="$EF_SEAT, measured by docs/analysis/m.py, before 2.0 h and after 1.0 h"
ef_seed() { # ef_seed <dir> <ledger-body>
  seed "$1"
  mkdir -p "$1/docs/analysis"
  printf '| row | EFROW phrase |\n**M.** Failure caught: EFFC phrase\n' > "$1/docs/analysis/v.md"
  : > "$1/docs/analysis/m.py"
  # Item (d)'s evidence (b255 F2b): a live `did not fall` citation must hit EXACTLY ONE line that is a
  # `Failure caught:` line under core/skills/ai-dlc/steps/ with a non-null tail, or a non-header row
  # with a non-null cell under a catch column, and that does not itself say `did not fall`. One table
  # file and one step file, each phrase on the line its ef-dcite entry needs (see ef-dcite below).
  printf '%s\n' '**M.** Failure caught: EFFC phrase' 'Failure caught: WFCIN a real defect' \
    'WFCNULL four. Failure caught: none' > "$1/core/skills/ai-dlc/steps/implementation.md"
  printf '%s\n' '| Fix | Failure caught | Measured |' '|---|---|---|' '| a | WDUP one | x |' \
    '| b | E-1 | WDUP one again |' '| c | WDNF caught MAJOR | the step did not fall |' \
    '| d | WDNFAIL caught MAJOR | the step did not fail |' "$(printf '| \342\200\224 | 0 of WNULL six | \342\200\224 |')" \
    '| f | WONCE caught MAJOR | x |' '' '| Fix | Entry | Measured |' '|---|---|---|' \
    '| g | BL-1 | WNOCATCH step held across the sprints |' '' '| Fix | Unique survived | Cost |' '|---|---|---|' \
    '| WUNIQ shards | 36 | $3 |' '' '| Fix WHDR | Failure caught | Measured |' '|---|---|---|' \
    '| WBODY | E-1 | b |' '' 'Failure caught: WFCOUT a real defect' > "$1/docs/analysis/d.md"
  printf '%s' "$2" > "$1/docs/backlog.md"
}
ef_rows() { printf '%s\n' "$1" | awk -F'\t' '$1 == "FAIL: E" { print $3 " " $2 }' | LC_ALL=C sort | tr '\n' '|'; }
EF_GOOD="# probe

## BL-971

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, $EF_SHP; fell from 2.0 h.$EF_SV

## BL-972

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: no graph pipeline step; the cost lives in scripts/x.sh.

## BL-973

**DEFECT (efficiency).** open. $EF_RUL

## BL-974

Filed from docs/analysis/x.md; there is no graph pipeline step.

## A section

Section prose citing docs/analysis/x.md.
"
ef_world() { # ef_world <name> <dir> <ledger> <want-rows> <want-rc>
  local out rc_v got
  ef_seed "$2" "$3"
  out="$(vin "$2" "$2/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  got="$(ef_rows "$out")"
  if [ "$rc_v" -eq "$5" ] && [ "$got" = "$4" ] && { [ "$5" -ne 0 ] || grep -qF 'OK: validate-backlog-receipts --efficiency-only' <<<"$out"; }; then
    ok "$1 -- rc $rc_v, rows [${got}]"; case "$1" in ef-good) B_ef_good=1 ;; ef-noclose) B_ef_noclose=1 ;; ef-sprintless) B_ef_sprintless=1 ;; ef-untagged) B_ef_untagged=1 ;; ef-second) B_ef_second=1 ;; ef-noseat) B_ef_noseat=1 ;; ef-pathsprint) B_ef_pathsprint=1 ;; ef-noscript) B_ef_noscript=1 ;; ef-dirbase) B_ef_dirbase=1 ;; ef-nofigs) B_ef_nofigs=1 ;; ef-topair) B_ef_topair=1 ;; ef-filing) B_ef_filing=1 ;; ef-filing-noref) B_ef_filing_noref=1 ;; ef-vprose) B_ef_vprose=1 ;; ef-vfield) B_ef_vfield=1 ;; ef-vfield-quiet) B_ef_vfield_quiet=1 ;; ef-offstep) B_ef_offstep=1 ;; ef-onstep) B_ef_onstep=1 ;; ef-nostepbound) B_ef_nostepbound=1 ;; ef-stepbound) B_ef_stepbound=1 ;; ef-notokens) B_ef_notokens=1 ;; ef-tokens) B_ef_tokens=1 ;; ef-dcite) B_ef_dcite=1 ;; esac
  else
    note "FAIL  $1 -- rc $rc_v (want $5), rows [${got}] (want [$4])"
    printf '%s\n' "$out" | grep -v '^FAIL: E' | sed 's/^/      /' | head -4; rc=1
  fi
}
ef_world ef-good "$TMP/efgood" "$EF_GOOD" "" 0
ef_world ef-noclose "$TMP/efnc" "# probe

## BL-975

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**
" "NO-OUTCOME BL-975|" 1
# VEQ-eff: the --efficiency-only CLI on the same two worlds, exit 0 and exit 1 (see VEQ above).
veq_e_ok=1; veq_e_why=""
for _vw in efgood efnc; do
  _vu="$(vin "$TMP/$_vw" "$TMP/$_vw/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; _vur=$?
  _vc="$(cli_v "$TMP/$_vw" "$TMP/$_vw/scripts/validate-backlog-receipts.sh" "FXCELL=veq-eff-$_vw" --efficiency-only)"; _vcr=$?
  [ "$_vur" = "$_vcr" ] && [ "$_vu" = "$_vc" ] || { veq_e_ok=0; veq_e_why="$veq_e_why $_vw(cli=$_vcr unit=$_vur)"; }
  eval "veq_rc_$_vw=\$_vcr"
done
if [ "$veq_e_ok" = 1 ] && [ "$veq_rc_efgood" = 0 ] && [ "$veq_rc_efnc" = 1 ]; then
  note "ok    VEQ-eff -- --efficiency-only in process equals the CLI byte-for-byte on ef-good (rc 0) and ef-noclose (rc 1)"
else
  note "FAIL  VEQ-eff -- in-process vs CLI:$veq_e_why (ef-good cli rc ${veq_rc_efgood:-?}, ef-noclose cli rc ${veq_rc_efnc:-?})"; rc=1
fi
ef_world ef-sprintless "$TMP/efsl" "# probe

## BL-976

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: the cost fell.
" "NO-SPRINT BL-976|" 1
ef_world ef-untagged "$TMP/efut" "# probe

## BL-977

Filed from docs/analysis/x.md with no tag.
" "F-UNTAGGED BL-977|" 1
ef_world ef-second "$TMP/ef2" "# probe

## BL-978

**DEFECT (efficiency).** x. Cites \"A step with no measured value
goes\" in \`.claude/rules/operator-rulings.md\`.

<br>**LANDED (v0.1.0, verified abc1234).**

<br>**Outcome measured:** graph sprint 321, $EF_SHP; did not fall; \`core/skills/ai-dlc/steps/implementation.md:1\` \"EFFC phrase\".

**Step:** \`implementation\`

**Verdict:** \`implementation\` did not fall.
" "" 0
EF_NOSEAT="# probe

## BL-980

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, token-equivalent \$9 with API \$8 beside it, 1.0 h gap-inclusive; lead 40% of calls, subagent 12 calls.
"
ef_world ef-noseat "$TMP/efns" "$EF_NOSEAT" "SHAPE BL-980|" 1
# ef-pathsprint: a no-step close whose only s<NNN> token sits inside a path segment (BL-821's shape)
# must take the no-step branch, so it reads OK; a sprint branch would refuse it as SHAPE.
EF_PATHSPRINT="# probe

## BL-979

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: no graph pipeline step; the cost lives in this repo's analysis scripts (\`docs/analysis/pipeline-efficiency-s317-s320/scripts/impl_passes.py\`), which are analysis tooling.
"
ef_world ef-pathsprint "$TMP/efps" "$EF_PATHSPRINT" "" 0

# ef_mut <name> <sed> <world-dir-name> <ledger> -- the mutant must be refused by the subject's own E0
# self-probe (exit 2 naming E0), which the kill matrix measured for every efficiency mutant.
ef_mut() { # ef_mut <name> <sed> <world-dir-name> <ledger>
  local d="$TMP/$1" out rc_v
  ef_seed "$d" "$4"
  mut "$d" "$2" || return
  out="$(vin "$d" "$d/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  record "$1" "$rc_v" "$out"
  # The base-pass flag is read LITERALLY per world, so it is a value this run set beside that world's ok.
  case "$3" in
    ef-good) score "$1" "${B_ef_good:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-noclose) score "$1" "${B_ef_noclose:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-sprintless) score "$1" "${B_ef_sprintless:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-untagged) score "$1" "${B_ef_untagged:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-second) score "$1" "${B_ef_second:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-noseat) score "$1" "${B_ef_noseat:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-pathsprint) score "$1" "${B_ef_pathsprint:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-noscript) score "$1" "${B_ef_noscript:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-dirbase) score "$1" "${B_ef_dirbase:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-nofigs) score "$1" "${B_ef_nofigs:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-topair) score "$1" "${B_ef_topair:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-filing) score "$1" "${B_ef_filing:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    ef-filing-noref) score "$1" "${B_ef_filing_noref:-0}" "$1 -- refused by the subject's own E0 self-probe before the $3 world is read" m_noscript ;;
    *) bad "$1 -- ef_mut names world $3, which has no base-pass flag" ;;
  esac
}
ef_mut m-noclose 's/^    if \[ "\$_ld" = "1" \] .. { \[ "\$_t" = "1" \] || \[ "\$_on" = "1" \]; }; then$/    if false; then/' ef-noclose "# probe

## BL-975

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**
"
ef_mut m-widenostep 's/^eff_nostep_ok() { case .*$/eff_nostep_ok() { return 0; }/' ef-sprintless "# probe

## BL-976

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: the cost fell.
"
# m-nopathnarrow reverts the standalone-word narrowing: the raw line is matched again, so the
# path-embedded s317 reads as a sprint. The ef-pathsprint world (green on the subject) is used as the
# seed, so a survivor is rc 0 there; the kill is E0's own BL-966 case refusing first (exit 2), read
# by m_noscript like every efficiency mutant. It is scored here because its world is ef-pathsprint's seed.
d_pn="$TMP/m-nopathnarrow"; ef_seed "$d_pn" "$EF_PATHSPRINT"
if mut "$d_pn" 's/^  _t="\$(sed -e .*$/  _t="$1"/'; then
  out="$(vin "$d_pn" "$d_pn/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  record m-nopathnarrow "$rc_v" "$out"
  score m-nopathnarrow "${B_ef_pathsprint:-0}" "m-nopathnarrow -- refused by the subject's own E0 self-probe (BL-966) with the narrowing reverted" m_noscript
fi
# m-noseat: eff_shape_ok back to the three-label form, eff_seat_ok defined and never called.
ef_mut m-noseat 's#^eff_shape_ok() .*$#eff_shape_ok() { case "$1" in *token-equivalent*) ;; *) return 1 ;; esac; case "$1" in *API*) ;; *) return 1 ;; esac; case "$1" in *gap-inclusive*) return 0 ;; esac; return 1; }#' ef-noseat "$EF_NOSEAT"
# m-seatword: eff_seat_ok reduced to the words lead and subagent occurring (the word-only regression).
ef_mut m-seatword 's#^eff_seat_ok() {$#eff_seat_ok() { grep -qi lead <<<"$1" \&\& grep -qi subagent <<<"$1"; }; eff_seat_orig() {#' ef-noseat "$EF_NOSEAT"
ef_mut m-nofiling 's/^      \[ "\$_a" = "1" \] .. \[ "\$_t" != "1" \] .. \[ "\$_n" != "1" \] .. printf .F-UNTAGGED.*$/      :/' ef-untagged "# probe

## BL-977

Filed from docs/analysis/x.md with no tag.
"

# ===== BL-817 ITEM 1 REMAINDER AND ITEM 2: the measuring script, the before/after pair, and the
# filing shape. Each offender world has a quiet twin one property apart:
#   ef-noscript  a sprint line naming only an unresolved script and a RESOLVING `.sh:NN` value
#                citation                                                    -> NO-SCRIPT
#   ef-dirbase   the same line naming a resolving directory plus a bare basename under it -> OK
#   ef-nofigs    `before` alone and the sprint pair `s319 to s320`           -> NO-FIGURES
#   ef-topair    `$2.23 to 1.24` and no before/after word                    -> OK
#   ef-filing    origin/main at a commit whose ledger holds BL-985 (tagged, no filing fields);
#                the working ledger adds BL-986 (no fields) and BL-987 (all three)
#                                       -> F-BASELINE, F-STEP, F-MOVEMENT for BL-986 only
#   ef-filing-noref  the same ledger with no origin/main                     -> OK, "origin/main is absent"
EF_SL_HEAD="# probe

## BL-981

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, $EF_SEAT,"
ef_world ef-noscript "$TMP/efnsc" "$EF_SL_HEAD measured by docs/analysis/gone.py from \`scripts/validate-backlog-receipts.sh:12\`, before 2.0 h and after 1.0 h; fell.
" "NO-SCRIPT BL-981|" 1
ef_world ef-dirbase "$TMP/efdb" "$EF_SL_HEAD \`docs/analysis/\` (m.py), before 2.0 h and after 1.0 h; fell.$EF_SV
" "" 0
EF_NOFIGS="$EF_SL_HEAD graph s319 to s320, measured by docs/analysis/m.py, 2.0 h before; fell.
"
ef_world ef-nofigs "$TMP/efnf" "$EF_NOFIGS" "NO-FIGURES BL-981|" 1
ef_world ef-topair "$TMP/eftp" "$EF_SL_HEAD measured by docs/analysis/m.py, \$/shard \$2.23 to 1.24; fell.$EF_SV
" "" 0
EF_FBASE="# probe

## BL-985

**DEFECT (efficiency).** filed before the arm. $EF_RUL
"
EF_FADDED="$EF_FBASE
## BL-986

**DEFECT (efficiency).** added, no fields. $EF_RUL

## BL-987

**DEFECT (efficiency).** added, every field. $EF_RUL

Baseline: s320
Step: \`gate-validation[implementation]\`
Expected movement: lead dollars per story fall.
"
ef_filing() { # ef_filing <name> <dir> <with-origin 0|1> <want-rows> <want-rc> <want-scope-text>
  local out rc_v got
  ef_seed "$2" "$EF_FBASE"
  ( cd "$2" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m base >/dev/null 2>&1 )
  [ "$3" = 1 ] && git -C "$2" update-ref refs/remotes/origin/main HEAD
  printf '%s' "$EF_FADDED" > "$2/docs/backlog.md"
  out="$(vin "$2" "$2/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  got="$(ef_rows "$out")"
  if [ "$rc_v" -eq "$5" ] && [ "$got" = "$4" ] && grep -qF -- "$6" <<<"$out"; then
    ok "$1 -- rc $rc_v, rows [${got}], scope [$6]"; case "$1" in ef-good) B_ef_good=1 ;; ef-noclose) B_ef_noclose=1 ;; ef-sprintless) B_ef_sprintless=1 ;; ef-untagged) B_ef_untagged=1 ;; ef-second) B_ef_second=1 ;; ef-noseat) B_ef_noseat=1 ;; ef-pathsprint) B_ef_pathsprint=1 ;; ef-noscript) B_ef_noscript=1 ;; ef-dirbase) B_ef_dirbase=1 ;; ef-nofigs) B_ef_nofigs=1 ;; ef-topair) B_ef_topair=1 ;; ef-filing) B_ef_filing=1 ;; ef-filing-noref) B_ef_filing_noref=1 ;; ef-vprose) B_ef_vprose=1 ;; ef-vfield) B_ef_vfield=1 ;; ef-offstep) B_ef_offstep=1 ;; ef-onstep) B_ef_onstep=1 ;; ef-nostepbound) B_ef_nostepbound=1 ;; ef-stepbound) B_ef_stepbound=1 ;; ef-notokens) B_ef_notokens=1 ;; ef-tokens) B_ef_tokens=1 ;; ef-dcite) B_ef_dcite=1 ;; esac
  else
    note "FAIL  $1 -- rc $rc_v (want $5), rows [${got}] (want [$4]), scope text [$6] $(grep -qF -- "$6" <<<"$out" && echo present || echo ABSENT)"
    printf '%s\n' "$out" | grep -v '^FAIL: E' | sed 's/^/      /' | head -4; rc=1
  fi
}
ef_filing ef-filing "$TMP/effl" 1 "F-BASELINE BL-986|F-MOVEMENT BL-986|F-STEP BL-986|" 1 "FAIL: E: 3 efficiency finding(s)"
ef_filing ef-filing-noref "$TMP/efflnr" 0 "" 0 "filing shape: 0 added entr(y/ies) judged, not evaluated -- origin/main is absent"
# One mutant per new predicate, each made ALWAYS TRUE (the fixture-mutants convention: the guard
# matches nothing). The kill is REQUIRED to be the subject's own E0 refusing (exit 2): a world
# without origin/main reads rc 0 on the shipped subject too, so ef_mut's "turned green" branch would
# score a survivor of a filing mutant as a kill. The unmutated controls are ef-noscript, ef-nofigs
# and ef-filing above, which pass E0 on the same seed builder.
ef_mut0() { # ef_mut0 <name> <sed> <ledger>
  local d="$TMP/$1" out rc_v
  ef_seed "$d" "$3"
  mut "$d" "$2" || return
  out="$(vin "$d" "$d/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  record "$1" "$rc_v" "$out"
  # Each mutant's base-pass flag is read literally (its unmutated control world's flag).
  case "$1" in
    m-noscript) score "$1" "${B_ef_noscript:-0}" "$1 -- refused by the subject's own E0 self-probe before the corpus" ;;
    m-nofigs) score "$1" "${B_ef_nofigs:-0}" "$1 -- refused by the subject's own E0 self-probe before the corpus" m_noscript ;;
    *) score "$1" "${B_ef_filing:-0}" "$1 -- refused by the subject's own E0 self-probe before the corpus" m_noscript ;;
  esac
}
ef_mut0 m-noscript 's/^eff_script_ok() {$/eff_script_ok() { return 0;/' "$EF_SL_HEAD measured by docs/analysis/gone.py, before 2.0 h and after 1.0 h; fell.
"
ef_mut0 m-nofigs 's/^eff_figs_ok() {$/eff_figs_ok() { return 0;/' "$EF_NOFIGS"
ef_mut0 m-nostep 's/^eff_step_ok() {$/eff_step_ok() { return 0;/' "$EF_FADDED"
ef_mut0 m-nobaseline 's/f != "@NONE@" \&\& f ~ \/^`?s3\[0-9\]\[0-9\](\[^0-9\]|\$)\/) bas = 1/1) bas = 1/' "$EF_FADDED"
ef_mut0 m-nomovement 's/f != "@NONE@" \&\& f ~ \/\[A-Za-z0-9\]\/) mv = 1/1) mv = 1/' "$EF_FADDED"
ef_mut0 m-noscope 's/ \&\& \[ -n "\${4:-}" \] \&\& grep -qxF -- "\$_l" "\$4"; then$/; then/' "$EF_FADDED"

# ===== THE VERDICT GRAMMAR (b255 F2b, BL-817 owed items (a), (b), (c)): live ledger only. ==========
# One offender world and one quiet near-miss per rule, each line otherwise valid (EF_SEAT's token
# figure, a Step: line, a Verdict field) so it reaches exactly its own rule:
#   ef-vprose      no Verdict field, `the shards fell` in prose                    -> NO-DIRECTION
#   ef-vfield      a `Verdict: implementation fell.` field beside prose `did not fall` and no
#                  value citation (the field may not cancel the citation the prose owes; D1)
#                                                                                 -> VERDICT-CONFLICT
#   ef-vfield-quiet the same field beside prose that says `fell`, plus a `did not fallback`
#                  (the letter boundary)                                          -> OK
#   ef-offstep     `Step: implementation`, `Verdict: implementation plus pipeline fell` (the bucket
#                  escape: the step rose, the bucket fell)                        -> OFF-STEP
#   ef-onstep      the same step and a plus-group of steps only                    -> OK
#   ef-nostepbound a Verdict field and no Step: line                               -> NO-STEP-BOUND
#   ef-stepbound   the bold, backticked `gate-validation[implementation]` Step     -> OK
#   ef-notokens    no token figure, only the sprint token `s321 tokens`            -> NO-TOKENS
#   ef-tokens      the same line with `1,234 K tokens`                             -> OK
#   ef-sac         origin/main at a ledger holding the entry with no Step: line; the working ledger
#                  adds the Step line at the close                                -> STEP-AT-CLOSE
#   ef-sac-quiet   the identical Step line already at the merge-base               -> OK
# Mutants, one per rule: m-vprose reads prose when the field is absent (the entry awk), the other four
# each remove the rule's line in eff_close. E0 seeds every rule, so each is
# refused by E0 (exit 2) before any world is read; its arm (ef_e0_lacks) requires E0's REPORTED list
# to lack exactly that rule's own E0 seed row while an untouched close row (SHAPE BL-957) is still
# there, so no other rule's mutant and no population-wide mutant can trip it. m-nosacderive is the
# exception: it mutates the merge-base derivation of $4.stepchg, which E0 writes itself and so cannot
# see, and only the ef-sac world kills it.
EF_VG_HEAD="# probe

## BL-981

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, $EF_SEAT, measured by docs/analysis/m.py, before 2.0 h and after 1.0 h;"
EF_NOTOK_HEAD="# probe

## BL-981

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, token-equivalent \$9 with API \$8 beside it, 1.0 h gap-inclusive, lead active 0.4 h, subagent \$5, measured by docs/analysis/m.py, before 2.0 h and after 1.0 h;"
EF_VPROSE="$EF_VG_HEAD the shards fell.

Step: implementation
"
EF_OFFSTEP="$EF_VG_HEAD the shards fell.

Step: implementation

Verdict: implementation plus pipeline fell.
"
EF_NOSTEPB="$EF_VG_HEAD the shards fell.

Verdict: implementation fell.
"
EF_NOTOK="$EF_NOTOK_HEAD s321 tokens were not counted.$EF_SV
"
ef_world ef-vprose "$TMP/efvp" "$EF_VPROSE" "NO-DIRECTION BL-981|" 1
EF_VCONF="$EF_VG_HEAD the shards did not fall.$EF_SV
"
ef_world ef-vfield "$TMP/efvf" "$EF_VCONF" "VERDICT-CONFLICT BL-981|" 1
ef_world ef-vfield-quiet "$TMP/efvfq" "$EF_VG_HEAD the shards fell; the queue did not fallback.$EF_SV
" "" 0
ef_world ef-offstep "$TMP/efos" "$EF_OFFSTEP" "OFF-STEP BL-981|" 1
ef_world ef-onstep "$TMP/efon" "$EF_VG_HEAD the shards fell.

Step: implementation

Verdict: implementation plus gate-validation[implementation] fell.
" "" 0
ef_world ef-nostepbound "$TMP/efnb" "$EF_NOSTEPB" "NO-STEP-BOUND BL-981|" 1
ef_world ef-stepbound "$TMP/efsb" "$EF_VG_HEAD the shards fell.

**Step:** \`gate-validation[implementation]\`

**Verdict:** \`gate-validation[implementation]\` fell.
" "" 0
ef_world ef-notokens "$TMP/efnt" "$EF_NOTOK" "NO-TOKENS BL-981|" 1
ef_world ef-tokens "$TMP/eftk" "$EF_NOTOK_HEAD s321 tokens were counted, 1,234 K tokens in all.$EF_SV
" "" 0
# STEP-AT-CLOSE needs a merge-base: ef_sac_build commits <base-ledger> (after an optional mutation of
# the world's validator copy, so the mutant is part of the committed tree), points origin/main at it,
# and writes <tip-ledger> as the working ledger. The entry is AT the base, so it is not ADDED and no
# filing arm judges it.
EF_SAC_BASE="# probe

## BL-981

**DEFECT (efficiency).** x. $EF_RUL
"
EF_SAC_BASEQ="$EF_SAC_BASE
Step: implementation
"
EF_SAC_TIP="$EF_VG_HEAD the shards fell.$EF_SV
"
ef_sac_build() { # ef_sac_build <dir> <base-ledger> <tip-ledger> [<sed>]
  ef_seed "$1" "$2"
  if [ -n "${4:-}" ]; then mut "$1" "$4" || return 1; fi
  ( cd "$1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m base >/dev/null 2>&1 )
  git -C "$1" update-ref refs/remotes/origin/main HEAD
  printf '%s' "$3" > "$1/docs/backlog.md"
}
ef_sac() { # ef_sac <name> <dir> <base-ledger> <want-rows> <want-rc>
  local out rc_v got
  ef_sac_build "$2" "$3" "$EF_SAC_TIP"
  out="$(vin "$2" "$2/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  got="$(ef_rows "$out")"
  # A STEP-AT-CLOSE row exists only where the merge-base step set was derived, so the scope text (printed
  # on the OK line alone) is required of the quiet world.
  if [ "$rc_v" -eq "$5" ] && [ "$got" = "$4" ] && { [ "$5" -ne 0 ] || { grep -qF -- "against merge-base" <<<"$out" && grep -qF 'OK: validate-backlog-receipts --efficiency-only' <<<"$out"; }; }; then
    ok "$1 -- rc $rc_v, rows [${got}]"; case "$1" in ef-sac) B_ef_sac=1 ;; ef-sac-quiet) B_ef_sac_quiet=1 ;; esac
  else
    note "FAIL  $1 -- rc $rc_v (want $5), rows [${got}] (want [$4]), merge-base scope $(grep -qF -- "against merge-base" <<<"$out" && echo present || echo ABSENT)"
    printf '%s\n' "$out" | grep -v '^FAIL: E' | sed 's/^/      /' | head -4; rc=1
  fi
}
ef_sac ef-sac "$TMP/efsac" "$EF_SAC_BASE" "STEP-AT-CLOSE BL-981|" 1
ef_sac ef-sac-quiet "$TMP/efsacq" "$EF_SAC_BASEQ" "" 0
# ef_mutg <name> <sed> <ledger> -- one rule's line removed; scored on its own arm, against its own
# offender world's base-pass flag, each read literally.
ef_mutg() { # ef_mutg <name> <sed> <ledger>
  local d="$TMP/$1" out rc_v
  ef_seed "$d" "$3"
  mut "$d" "$2" || return
  out="$(vin "$d" "$d/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  record "$1" "$rc_v" "$out"
  case "$1" in
    m-vprose) score "$1" "${B_ef_vprose:-0}" "$1 -- E0 refused it, its prose-fell seed BL-1005 no longer reported NO-DIRECTION" ;;
    m-nooffstep) score "$1" "${B_ef_offstep:-0}" "$1 -- E0 refused it, its bucket-verdict seed BL-1008 no longer reported OFF-STEP" ;;
    m-nostepbound) score "$1" "${B_ef_nostepbound:-0}" "$1 -- E0 refused it, its stepless seed BL-1002 no longer reported NO-STEP-BOUND" ;;
    m-notokens) score "$1" "${B_ef_notokens:-0}" "$1 -- E0 refused it, its tokenless seed BL-1000 no longer reported NO-TOKENS" ;;
    m-nosac) score "$1" "${B_ef_sac:-0}" "$1 -- E0 refused it, its changed-step seed BL-1012 no longer reported STEP-AT-CLOSE" ;;
    m-noconflict) score "$1" "${B_ef_vfield:-0}" "$1 -- E0 refused it, its fell-field seed BL-1057 no longer reported VERDICT-CONFLICT" ;;
    m-noarchlive) score "$1" "${B_ef_arch:-0}" "$1 -- E0 refused it, its added archive seed BL-1059 was no longer judged by the live rules" ;;
    *) bad "$1 -- ef_mutg names no base-pass flag for this mutant" ;;
  esac
}
# Direction read from prose again, ONLY where the Verdict field is ABSENT: a `fell` anywhere in the
# outcome line stands in for `Verdict: <the entry's step> fell` (a present field, well-formed or
# not, is still the only thing read when there is one).
ef_mutg m-vprose 's#everdict(hv ? vf : "@NONE@")#everdict(hv ? vf : (oc ~ /fell/ ? stp " fell" : "@NONE@"))#' "$EF_VPROSE"
ef_mutg m-nooffstep 's#^    \[ "\$7" = 1 \] || { echo OFF-STEP; return; }$#    :#' "$EF_OFFSTEP"
ef_mutg m-nostepbound 's#^    \[ "\$5" = 1 \] || { echo NO-STEP-BOUND; return; }$#    :#' "$EF_NOSTEPB"
ef_mutg m-notokens 's#^    \[ "\$8" = 1 \] || { echo NO-TOKENS; return; }$#    :#' "$EF_NOTOK"
ef_mutg m-nosac 's#^    \[ "\$9" != 1 \] || { echo STEP-AT-CLOSE; return; }$#    :#' "$EF_SAC_TIP"
ef_mutg m-noconflict 's#^    \[ "\${10}" != 1 \] || { echo VERDICT-CONFLICT; return; }$#    :#' "$EF_VCONF"
# m-nosacderive: the merge-base step comparison that writes $4.stepchg never prints. E0 hands
# eff_corpus its own stepchg file, so E0 passes and the run reaches the ef-sac world, which reads OK.
d_sd="$TMP/m-nosacderive"
if ef_sac_build "$d_sd" "$EF_SAC_BASE" "$EF_SAC_TIP" 's#!(\$1 in s) || s\[\$1\] == "-" || s\[\$1\] != \$9 { print \$1 }#0 { print $1 }#'; then
  out="$(vin "$d_sd" "$d_sd/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  record m-nosacderive "$rc_v" "$out"; side m-nosacderive "world=sac"
  score m-nosacderive "${B_ef_sac:-0}" "m-nosacderive -- the ef-sac world read OK against its merge-base: the step-at-close derivation is load-bearing"
fi

# ===== D2 (b255 F2b): THE ARCHIVE SCOPE IS BY MERGE-BASE, NOT BY MODE. ===============================
# origin/main holds a live ledger filing BL-981 (Step: implementation) and an archive holding BL-982,
# a pre-existing tokenless close. The working tree rotates BL-981, stamped, into the archive -- the
# one-squash close-and-archive -- and `--archive` runs:
#   ef-arch        BL-981 archived with no token figure                -> NO-TOKENS BL-981 (live rules);
#                  BL-982 present at the base stays quiet (archive rule)
#   ef-arch-quiet  BL-981 archived as a full live close                 -> OK; its Step line sat in the
#                  base LIVE ledger, so STEP-AT-CLOSE does not fire
# m-noarchscope reverts the --archive call site to no added set (the mode exemption); E0 hands
# eff_corpus its own added file and cannot see it, so ef-arch kills it. m-noarchxbase drops the live
# ledger from the merge-base step map; ef-arch-quiet then reads STEP-AT-CLOSE and kills it.
EF_AR_LIVE0="# probe

## BL-981

**DEFECT (efficiency).** x. $EF_RUL

Step: implementation
"
EF_AR_ARCH0="# archive

## BL-982

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, token-equivalent \$9 with API \$8 beside it, 1.0 h gap-inclusive, lead active 0.4 h, subagent \$5, measured by docs/analysis/m.py, before 2.0 h and after 1.0 h; fell.
"
EF_AR_TIP="$EF_AR_ARCH0
## BL-981

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, token-equivalent \$9 with API \$8 beside it, 1.0 h gap-inclusive, lead active 0.4 h, subagent \$5, measured by docs/analysis/m.py, before 2.0 h and after 1.0 h; fell.$EF_SV
"
EF_AR_TIPQ="$EF_AR_ARCH0
## BL-981

**DEFECT (efficiency).** x. $EF_RUL

**LANDED (v0.1.0, verified abc1234).**

Outcome measured: graph s321, $EF_SHP; fell.$EF_SV
"
ef_arch_build() { # ef_arch_build <dir> <tip-archive> [<sed>]
  ef_seed "$1" "$EF_AR_LIVE0"
  printf '%s' "$EF_AR_ARCH0" > "$1/docs/backlog.archive.md"
  if [ -n "${3:-}" ]; then mut "$1" "$3" || return 1; fi
  ( cd "$1" && git add -A >/dev/null 2>&1 && git -c user.email=p@local -c user.name=p commit -q -m base >/dev/null 2>&1 )
  git -C "$1" update-ref refs/remotes/origin/main HEAD
  printf '# probe\n' > "$1/docs/backlog.md"
  printf '%s' "$2" > "$1/docs/backlog.archive.md"
}
ef_arch() { # ef_arch <name> <dir> <tip-archive> <want-rows> <want-rc>
  local out rc_v got
  ef_arch_build "$2" "$3"
  out="$(vin "$2" "$2/scripts/validate-backlog-receipts.sh" "" --archive)"; rc_v=$?
  got="$(ef_rows "$out")"
  if [ "$rc_v" -eq "$5" ] && [ "$got" = "$4" ] && { [ "$5" -ne 0 ] || { grep -qF -- "archive scope: 1 close(s) added since the merge-base judged by the live rules" <<<"$out" && grep -qF 'OK: validate-backlog-receipts --archive' <<<"$out"; }; }; then
    ok "$1 -- rc $rc_v, rows [${got}]"; case "$1" in ef-arch) B_ef_arch=1 ;; ef-arch-quiet) B_ef_arch_quiet=1 ;; esac
  else
    note "FAIL  $1 -- rc $rc_v (want $5), rows [${got}] (want [$4])"
    printf '%s\n' "$out" | grep -v '^FAIL: E' | sed 's/^/      /' | head -4; rc=1
  fi
}
ef_arch ef-arch "$TMP/efar" "$EF_AR_TIP" "NO-TOKENS BL-981|" 1
ef_arch ef-arch-quiet "$TMP/efarq" "$EF_AR_TIPQ" "" 0
# m-noarchlive, after the world that sets its base-pass flag: an archive entry in the added set keeps
# the archive rule (eff_corpus's routing); E0's archive refusal kills it.
ef_mutg m-noarchlive 's#^"\*) _rule=live; _alive=\$((_alive + 1)) ;; esac$#"*) _alive=$((_alive + 1)) ;; esac#' "$EF_VCONF"
ef_archmut() { # ef_archmut <name> <tip-archive> <sed> <world> <flag>
  local d="$TMP/$1" out rc_v
  ef_arch_build "$d" "$2" "$3" || return
  out="$(vin "$d" "$d/scripts/validate-backlog-receipts.sh" "" --archive)"; rc_v=$?
  record "$1" "$rc_v" "$out"; side "$1" "world=$4"
  score "$1" "$5" "$1 -- the $4 world read the archive scope wrong: the merge-base scope is load-bearing"
}
ef_archmut m-noarchscope "$EF_AR_TIP" 's#^  EFF_SCOPE="\$(eff_added_labels "\$LEDGER" "\$SUBJECT_ROOT" "\$WORK/eff.added" "\$EFF_XNAME")" || exit 2$#  EFF_SCOPE="not evaluated under --archive"#' arch "${B_ef_arch:-0}"
ef_archmut m-noarchxbase "$EF_AR_TIPQ" 's#"\$WORK/eff.added" "\$EFF_XNAME")" || exit 2$#"$WORK/eff.added" "")" || exit 2#' archq "${B_ef_arch_quiet:-0}"

# ===== ITEM (d): THE VALUE CITATION IS STEP-VALUE EVIDENCE (b255 F2b, BL-817), live ledger only. ====
# ONE world, every rule's offender and near-miss as its own entry over ef_seed's d.md / step file
# (one run per distinct state). Each entry is a full live `did not fall` close citing one phrase:
#   BL-1101 WDUP     hits two rows                                       -> VALUE-NULL (d1 exactly one)
#   BL-1102 WDNF     its row says `did not fall`                         -> VALUE-NULL (d2)
#   BL-1103 WFCOUT   a Failure caught: line outside core/skills/ai-dlc/steps/ -> VALUE-NULL (d3)
#   BL-1104 WFCNULL  a steps/ Failure caught: line whose tail is `none`  -> VALUE-NULL (d4)
#   BL-1105 WNULL    a row whose every cell is null (`0 of ...`, em dashes) -> VALUE-NULL (d4)
#   BL-1106 WNOCATCH a row of a table with no catch column              -> VALUE-NULL (d5)
#   BL-1107 WHDR     the phrase sits in the table's HEADER row          -> VALUE-NULL (d6)
#   BL-1108 WONCE    one row, non-null catch cell                        -> quiet (d1's twin)
#   BL-1109 WDNFAIL  `did not fail` on the row (a letter apart)          -> quiet (d2's twin)
#   BL-1110 WFCIN    a steps/ Failure caught: line with a real tail      -> quiet (d3's / d4's twin)
#   BL-1111 WUNIQ    a `Unique survived` catch column                    -> quiet (d5's twin)
#   BL-1112 WBODY    a body row of the table whose header carries WHDR   -> quiet (d6's twin)
#   BL-1113 WGONE    a phrase no line carries                            -> NO-VALUE-CITATION (unresolved
#                    stays its own code, never VALUE-NULL)
# Mutants m-d1..m-d6 each remove one qualifying rule from the citation awk; E0 seeds every rule, so
# each is refused by E0, and its arm requires E0's reported list to lack that rule's own seed row.
ef_dc() { # ef_dc <id> <citation>
  printf '## %s\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s, measured by docs/analysis/m.py, before 2.0 h and after 1.0 h; did not fall; value: %s.\n\nStep: implementation\n\nVerdict: implementation did not fall.\n\n' "$1" "$EF_RUL" "$EF_SEAT" "$2"
}
EF_DCITE="$(printf '# probe\n\n'
  ef_dc BL-1101 'docs/analysis/d.md:3 "WDUP one"'
  ef_dc BL-1102 'docs/analysis/d.md:5 "WDNF caught MAJOR"'
  ef_dc BL-1103 'docs/analysis/d.md:22 "WFCOUT a real defect"'
  ef_dc BL-1104 'core/skills/ai-dlc/steps/implementation.md:3 "WFCNULL four"'
  ef_dc BL-1105 'docs/analysis/d.md:7 "WNULL six"'
  ef_dc BL-1106 'docs/analysis/d.md:12 "WNOCATCH step held"'
  ef_dc BL-1107 'docs/analysis/d.md:18 "WHDR"'
  ef_dc BL-1108 'docs/analysis/d.md:8 "WONCE caught MAJOR"'
  ef_dc BL-1109 'docs/analysis/d.md:6 "WDNFAIL caught MAJOR"'
  ef_dc BL-1110 'core/skills/ai-dlc/steps/implementation.md:2 "WFCIN a real defect"'
  ef_dc BL-1111 'docs/analysis/d.md:16 "WUNIQ shards"'
  ef_dc BL-1112 'docs/analysis/d.md:20 "WBODY"'
  ef_dc BL-1113 'docs/analysis/d.md:1 "WGONE nowhere"')
"
ef_world ef-dcite "$TMP/efdc" "$EF_DCITE" "NO-VALUE-CITATION BL-1113|VALUE-NULL BL-1101|VALUE-NULL BL-1102|VALUE-NULL BL-1103|VALUE-NULL BL-1104|VALUE-NULL BL-1105|VALUE-NULL BL-1106|VALUE-NULL BL-1107|" 1
ef_mutd() { # ef_mutd <name> <sed>
  local d="$TMP/$1" out rc_v
  ef_seed "$d" "$EF_DCITE"
  mut "$d" "$2" || return
  out="$(vin "$d" "$d/scripts/validate-backlog-receipts.sh" "" --efficiency-only)"; rc_v=$?
  record "$1" "$rc_v" "$out"
  case "$1" in
    m-d1) score "$1" "${B_ef_dcite:-0}" "$1 -- E0 refused it, its two-row seed BL-1046 no longer reported VALUE-NULL" ;;
    m-d2) score "$1" "${B_ef_dcite:-0}" "$1 -- E0 refused it, its did-not-fall-row seed BL-1047 no longer reported VALUE-NULL" ;;
    m-d3) score "$1" "${B_ef_dcite:-0}" "$1 -- E0 refused it, its off-steps Failure caught: seed BL-1048 no longer reported VALUE-NULL" ;;
    m-d4) score "$1" "${B_ef_dcite:-0}" "$1 -- E0 refused it, its null-tail seed BL-1049 no longer reported VALUE-NULL" ;;
    m-d5) score "$1" "${B_ef_dcite:-0}" "$1 -- E0 refused it, its no-catch-column seed BL-1050 no longer reported VALUE-NULL" ;;
    m-d6) score "$1" "${B_ef_dcite:-0}" "$1 -- E0 refused it, its header-row seed BL-1052 no longer reported VALUE-NULL" ;;
    *) bad "$1 -- ef_mutd names no base-pass flag for this mutant" ;;
  esac
}
ef_mutd m-d1 's/if (hits == 1 \&\& q) exit 0/if (q) exit 0/'
ef_mutd m-d2 's#^  if (\$0 ~ /(^|\[^A-Za-z\])\[Dd\]id not fall(\[^A-Za-z\]|\$)/) q = 0$#  q = q#'
ef_mutd m-d3 's/if (fc \&\& insteps) {/if (fc) {/'
ef_mutd m-d4 's/^function isnull(s) { /function isnull(s) { return 0; /'
ef_mutd m-d5 's#if (H\[k\] ~ /Failure caught|\[Uu\]nique|\[Cc\]atch/ \&\& #if (1 \&\& #'
ef_mutd m-d6 's/if (isrow \&\& NR != hnr) {/if (isrow) {/'

# --- per-push twins ----------------------------------------------------------------------------
# A TWIN is a different arm that the MEASURED matrix shows GREEN for the mutant. Every push reads it
# off the mutant's own capture, so a kill that spreads past its deciding arm is seen at no cost.
# The table is generated from a `--matrix` run. The matrix is re-measured as
# .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state") requires.
twin_of() {
  case "$1" in
# TWINS-BEGIN
    m-noclose) echo m_vprose ;;
    m-widenostep) echo m_vprose ;;
    m-nopathnarrow) echo m_vprose ;;
    m-noseat) echo m_vprose ;;
    m-seatword) echo m_vprose ;;
    m-nofiling) echo m_vprose ;;
    m-noscript) echo m_vprose ;;
    m-nofigs) echo m_vprose ;;
    m-nostep) echo m_vprose ;;
    m-nobaseline) echo m_vprose ;;
    m-nomovement) echo m_vprose ;;
    m-noscope) echo m_vprose ;;
    m-vprose) echo m_nooffstep ;;
    m-nooffstep) echo m_vprose ;;
    m-nostepbound) echo m_notokens ;;
    m-notokens) echo m_nostepbound ;;
    m-nosac) echo m_nosacderive ;;
    m-nosacderive) echo m_nosac ;;
    m-noconflict) echo m_nosac ;;
    m-noarchlive) echo m_noconflict ;;
    m-noarchscope) echo m_noarchxbase ;;
    m-noarchxbase) echo m_noarchscope ;;
    m-d1) echo m_d2 ;;
    m-d2) echo m_d1 ;;
    m-d3) echo m_d4 ;;
    m-d4) echo m_d3 ;;
    m-d5) echo m_d6 ;;
    m-d6) echo m_d5 ;;
    *) echo "" ;;
# TWINS-END
  esac
}
for m in $SCORED; do
  t="$(twin_of "$m")"
  [ -n "$t" ] && [ "$t" != "-" ] || continue
  # An undefined twin would exit 127 and read as "stays green"; it is a broken table, so it fails.
  declare -F "arm_$t" >/dev/null || { bad "[twin] $m -- its twin arm_$t is not defined, so the twin check cannot fire"; continue; }
  if "arm_$t" "$m"; then bad "[twin] $m -- the twin arm $t TRIPPED on $m's capture, so the kill is not confined to its deciding arm"
  else ok "[twin] $m -- twin $t stays green on $m's capture: the kill is confined to its deciding arm"; fi
done
if [ "$MATRIX" = 1 ]; then
  mx_caps="$(ls "$REC" | sed -n 's/\.rc$//p')"
  # THIS file's arms, read from its own text: the sourced all_arms would also list every arm the harness defines.
  mx_arms="$(sed -n 's/^arm_\([A-Za-z0-9_]*\)() {.*/\1/p' "$EDIR/run.sh")"
  for m in $mx_caps; do
    for a in $mx_arms; do
      if "arm_$a" "$m"; then matrix_row "$m" "$a" "$(r_rc "$m")" TRIPPED yes
      else matrix_row "$m" "$a" "$(r_rc "$m")" GREEN no; fi
      MROWS=$((MROWS + 1))
    done
  done
  mx_nc="$(printf '%s\n' $mx_caps | grep -c .)"; mx_na="$(printf '%s\n' $mx_arms | grep -c .)"
  if [ "$MROWS" -eq $((mx_nc * mx_na)) ] && [ "$MROWS" -gt 0 ]; then ok "[MX] the matrix run measured $MROWS cells for $mx_nc captures x $mx_na arms"
  else bad "[MX] matrix rows=$MROWS for $mx_nc captures x $mx_na arms"; fi
else
  if [ "$MROWS" -eq 0 ]; then ok "[MX] a plain run executed no matrix-only cell (rows=0)"
  else bad "[MX] a plain run executed matrix-only work (rows=$MROWS)"; fi
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-receipt-efficiency -- every efficiency world green, every mutant caught by its own assertion"
fi
exit "$rc"
