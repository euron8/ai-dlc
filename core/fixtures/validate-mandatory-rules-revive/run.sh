#!/usr/bin/env bash
# validate-mandatory-rules-revive/run.sh — prove the retro-compliance validator no longer
# self-poisons, and that Check 3 genuinely enforces the closed envelope.
#
# THE DEFECT THIS EXISTS TO CATCH. validate-mandatory-rules.sh delegated Checks 2 and 4 to sibling
# scripts, and Check 5 keyed on a "## Gate Log: Sprint N" header no core artifact produces. Each
# FAILED on a clean tree, so the whole validator exited 1 on every real retro — a wired CI gate that
# could never pass, enforcing nothing. Check 3 additionally read a shape (sprint_<N>_housekeeping)
# that no producer wrote until sprint-status.sh `close`.
#
# The fix: each check SKIPs loudly when its input is absent (un-poison), and Check 3 reads the
# canonical envelope `close` writes. Check 2 now ships in core and keys its SKIP on the PRODUCER
# (no validation-cycle-log.md -> SKIP), not on the validator's presence; Check 4's sibling stays
# consumer-provided (SKIP when absent). Regression lock below: the SKIPs must hold, Check 3 must
# PASS on a closed envelope, and an un-closed envelope must FAIL Check 3.
#
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
# HERMETIC-CONSUMED sentinels: the validator under test, then the two delegates it reads only if present.
VMR_DIR="$(dirname "$VMR")"
echo "HERMETIC-CONSUMED $VMR"
[ -f "$VMR_DIR/validate-retro-evidence.sh" ] && echo "HERMETIC-CONSUMED $VMR_DIR/validate-retro-evidence.sh"
[ -f "$VMR_DIR/validate-audit-anchors.sh" ] && echo "HERMETIC-CONSUMED $VMR_DIR/validate-audit-anchors.sh"

P="$WORK/proj"
export AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA"
IMPL_YAML="$P/_bmad-output/implementation-artifacts/sprint-status.yaml"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }

# IN PROCESS (BL-878). The validator is asked through vmr_f, which hands it to inproc_run: it is sourced inside the
# subshell, never in this shell (its top level carries `set -u`), and vmr_main runs there. The operand is a literal
# tail, the shape arm P2 of scripts/validate-fixture-invocations.sh resolves. Both states below fail Check 1 (the
# delegate is run by path and exits non-zero here), so no state drives the all-pass exit. vmr_main initialises
# FAILURES, SKIPPED_CHECKS and FAILURE_MSGS itself, so the in-process call reads the same state the program does.
# Check 1 EXECS validate-retro-evidence.sh directly by path ("$RETRO_EVIDENCE_SH" ...), so no fixture-side bash shim can
# route it to vre_main: vmr_f exports FXCELL=<cell> around the in-process call and the exec'd child carries that tag,
# one e2e cell per in-process call (cells.decl).
# CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a present subject with neither wrap half predates the wrap -- SKIP (exit 0 on
# a consumer, FIXTURE BROKEN in the distribution); exactly one half is a respelled subject, which FAILS.
vm_halves() { # vm_halves <file> <entry> -> "<def><guard>"; exit 2 on an unreadable file
  local d=0 g=0 x
  grep -qxF "$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x)" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x)" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
_vm_pre=""
vm_check() { # vm_check <file> <entry>
  [ -f "$1" ] || return 0
  _gh="$(vm_halves "$1" "$2")" || exit 2
  case "$_gh" in
    11) : ;;
    00) _vm_pre="$_vm_pre $1" ;;
    *) bad "$1 carries one half of the in-process wrap ($2 line, column-0 source guard: $_gh) -- a respelled subject this fixture cannot drive"
       report_end validate-mandatory-rules-revive ;;
  esac
}
vm_check "$VMR" vmr_main
vm_check "$VMR_DIR/validate-retro-evidence.sh" vre_main
if [ -n "$_vm_pre" ]; then echo "SKIP: validate-mandatory-rules-revive:$_vm_pre predate(s) the in-process wrap"; fx_skip_exit "$HERE"; fi
vmr_f() { # vmr_f <cell> <sprint> -> vmr_main's stdout, stderr and exit, in the project root; the exec'd delegate carries FXCELL=<cell>
  local c="$1"; shift
  ( cd "$P" && FXCELL="$c" inproc_run "${VMR%/*}/validate-mandatory-rules.sh" vmr_main "$@" )
}
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # eqv <cell-id> <sprint> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when all three agree
  local id="$1"
  vmr_f "e2e-$id" "$2" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$P" && FXCELL="$id" bash "$VMR" "$2" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}

echo "validate-mandatory-rules-revive:"

# Compliant tree: roll then close the envelope (Check 3's producer writes the housekeeping block).
bash "$SS" roll  --sprint 900 --intensity full --root "$P" >/dev/null 2>&1
bash "$SS" close --evidence "fixture: PR merged, deploy green, smoke pass" --root "$P" >/dev/null 2>&1

if eqv cli-vmr-pass 900; then
  ok "cli-vmr-pass: the program and the in-process call agree byte for byte on the closed envelope (stdout, stderr, exit $(cat "$EQ/cli-vmr-pass.cl.rc"))"
else
  bad "cli-vmr-pass: the program and the in-process call differ (rc ip=$(cat "$EQ/cli-vmr-pass.ip.rc") cl=$(cat "$EQ/cli-vmr-pass.cl.rc"))"
fi
OUT="$(cat "$EQ/cli-vmr-pass.ip.out")"

grep -q 'CHECK 2: SKIP' <<<"$OUT" \
  && ok "Check 2 SKIPs when no validation-cycle-log.md (per-artifact-changelog model)" \
  || bad "Check 2 did not SKIP — the no-log gate regressed"
grep -q 'CHECK 4: SKIP' <<<"$OUT" \
  && ok "Check 4 SKIPs when its consumer-provided sibling is absent (un-poison)" \
  || bad "Check 4 did not SKIP"
grep -q 'CHECK 5: SKIP' <<<"$OUT" \
  && ok "Check 5 SKIPs (no audit-anchors.md — diff base unresolvable on this clean tree)" \
  || bad "Check 5 did not SKIP"
grep -q 'CHECK 3: PASS' <<<"$OUT" \
  && ok "Check 3 PASSes on a closed envelope (close wrote the housekeeping block)" \
  || bad "Check 3 did not PASS on a closed envelope"

# Un-close the envelope -> Check 3 must FAIL.
sed 's/^status: done/status: in_progress/' "$IMPL_YAML" > "$IMPL_YAML.tmp" && mv "$IMPL_YAML.tmp" "$IMPL_YAML"
if eqv cli-vmr-fail 900; then
  ok "cli-vmr-fail: the program and the in-process call agree byte for byte on the un-closed envelope (stdout, stderr, exit $(cat "$EQ/cli-vmr-fail.cl.rc"))"
else
  bad "cli-vmr-fail: the program and the in-process call differ (rc ip=$(cat "$EQ/cli-vmr-fail.ip.rc") cl=$(cat "$EQ/cli-vmr-fail.cl.rc"))"
fi
MUT="$(cat "$EQ/cli-vmr-fail.ip.out")"
grep -q 'CHECK 3: FAIL' <<<"$MUT" \
  && [ "$(cat "$EQ/cli-vmr-fail.ip.rc")" = 1 ] \
  && ok "an un-closed envelope FAILS Check 3 (exit 1)" \
  || bad "Check 3 did not FAIL on an un-closed envelope"
echo
report_end validate-mandatory-rules-revive
