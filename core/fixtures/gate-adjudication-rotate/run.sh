#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# gate-adjudication-rotate/run.sh — prove the gate-adjudication rotator moves a closed
# sprint's verdicts and sidecars out of the live directory, loses nothing, refuses rather
# than half-writes, and actually removes the affordance DEFECT 1 names: a prior sprint's
# dispositioned FAIL staying the gate-remediation guard's "live pass" into the next sprint.
#
# THE RECEIPT IS ARM (e). Every other arm proves the mover is correct; arm (e) proves the
# reason it exists — it DRIVES `ai-dlc-gate-remediation-guard.sh` against the same tree
# before and after rotation and asserts DENY -> ALLOW -> DENY (the third leg is the control:
# rotation must not blind the guard to a live FAIL in the CURRENT sprint).
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Locate the rotator by walking UP for a marker, so this resolves from the distribution
# (core/scripts) and from a consumer where install.sh relocates it (scripts/ai-dlc).
ROT=""
d="$HERE"
while [ "$d" != "/" ]; do
  for base in "$d/core/scripts" "$d/scripts/ai-dlc"; do
    if [ -f "$base/rotate-gate-adjudication.sh" ]; then ROT="$base/rotate-gate-adjudication.sh"; break 2; fi
  done
  d="$(dirname "$d")"
done
[ -n "$ROT" ] || { echo "FIXTURE ERROR: rotate-gate-adjudication.sh not found in either layout" >&2; exit 2; }

# Locate the guard hook the same way gate-remediation-deny/run.sh does: three candidates
# spanning the distribution layout and a consumer's installed layout.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
GUARD="$(pick "$HERE/../../hooks/ai-dlc-gate-remediation-guard.sh" \
              "$HERE/../../../.claude/hooks/ai-dlc-gate-remediation-guard.sh" \
              "$HERE/../../../core/hooks/ai-dlc-gate-remediation-guard.sh")"
[ -n "$GUARD" ] || { echo "FIXTURE ERROR: ai-dlc-gate-remediation-guard.sh not found in either layout" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq absent; arm (e) cannot run" >&2; exit 2; }

# HERMETIC — scrub the operator's tuning before invoking the guard (I10 / I87).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# A candidate list resolves the FIRST existing file, so the file this run actually drives is
# not necessarily the one an author just edited. Print both: a mutant applied to the other
# copy leaves every arm green and reads exactly like an arm that cannot fire.
echo "gate-adjudication-rotate: resolved rotator = ${ROT}"
echo "gate-adjudication-rotate: resolved guard   = ${GUARD}"
echo "HERMETIC-CONSUMED $(cd "$(dirname "$ROT")" && pwd)/$(basename "$ROT")"
echo "HERMETIC-CONSUMED $(cd "$(dirname "$GUARD")" && pwd)/$(basename "$GUARD")"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# IN PROCESS (BL-878). Every drive of the rotator is a subshell sourcing it (ip_call, paired with fx_inproc) and calling
# rga_main; a `bash <rotator>` anywhere here, the lay-c/lay-d layout copies included, is answered by the `bash` function
# below. Two cli cells (cells.decl) start it as a program for one distinct outcome each, compared byte for byte with the
# in-process answer. The guard hook is driven in process too (grg_main, through the same `bash` function and ip_call); its
# two cli cells (cells.decl) start it as a program for one distinct outcome each, compared byte for byte with the answer.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A rotator with neither wrap half predates the wrap: SKIP and exit 0 on a
# consumer, FIXTURE BROKEN in the distribution (lib/layout.sh fx_skip_exit); exactly one half FAILS; unreadable is rc 2.
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
[ -r "$ROT" ] || { echo "FIXTURE ERROR: cannot read $ROT -- an unreadable rotator is not one that predates the wrap" >&2; exit 2; }
_pw_d=0; _pw_g=0
grep -qxF 'rga_main() {' "$ROT" && _pw_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$ROT" && _pw_g=1
case "$_pw_d$_pw_g" in
  11) : ;;
  00) echo "SKIP: gate-adjudication-rotate: $ROT predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$ROT carries one half of the in-process wrap (rga_main line, column-0 source guard: $_pw_d$_pw_g) -- a respelled rotator this fixture cannot drive"; report_end gate-adjudication-rotate; exit 1 ;;
esac
# The guard hook gets the same gate. A guard with neither half predates the wrap, and so does one with the column-0
# guard alone (the pre-wrap hook already split its head functions from its body at that line); a `grg_main() {` line
# without the guard is a respelled hook this fixture cannot drive.
[ -r "$GUARD" ] || { echo "FIXTURE ERROR: cannot read $GUARD -- an unreadable guard is not one that predates the wrap" >&2; exit 2; }
_gw_d=0; _gw_g=0
grep -qxF 'grg_main() {' "$GUARD" && _gw_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$GUARD" && _gw_g=1
case "$_gw_d$_gw_g" in
  11) : ;;
  00|01) echo "SKIP: gate-adjudication-rotate: $GUARD predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$GUARD carries one half of the in-process wrap (grg_main line, column-0 source guard: $_gw_d$_gw_g) -- a respelled guard this fixture cannot drive"; report_end gate-adjudication-rotate; exit 1 ;;
esac
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
ip_entry() { case "${1##*/}" in rotate-gate-adjudication.sh) echo rga_main ;; ai-dlc-gate-remediation-guard.sh) echo grg_main ;; *) return 1 ;; esac; }
IP_SUBJ="$ROT"  # seed env.sh redefines ROT, so the logged subject path is taken here
IP_GSUBJ="$GUARD"
IP_KEEP=" bash ip_call ip_scrub ip_entry fx_inproc "
ip_scrub() { # this subshell reduced to what a fresh `bash <script>` has: exported vars only, no fixture functions
  local _v _e
  _e=" $(compgen -e | tr '\n' ' ') "
  for _v in $(compgen -v); do
    case "$_e" in *" $_v "*) continue ;; esac
    case "$_v" in
      BASH*|IFS|OPTIND|OPTERR|PPID|UID|EUID|SHELLOPTS|HISTCMD|LINENO|RANDOM|SECONDS|FUNCNAME|PIPESTATUS|GROUPS|DIRSTACK|HOSTTYPE|MACHTYPE|OSTYPE|HOSTNAME|SHLVL|PWD|OLDPWD|_|PS4|_v|_e|IP_*) continue ;;
    esac
    unset -v "$_v" 2>/dev/null
  done
  for _v in $(compgen -A function); do case "$IP_KEEP" in *" $_v "*) ;; *) unset -f "$_v" ;; esac; done
  OPTIND=1; set +eufx +o pipefail; hash -r
}
ip_call() { # <script> [args...] (a layout copy of the rotator is logged as a pass of the rotator) -- the answer of `bash <script> args`: stdout, stderr, stdin and status are the subject's
  local IP_F="$1" IP_E; shift
  IP_E="$(ip_entry "$IP_F")" || { command bash "$IP_F" "$@"; return; }
  case "$IP_E" in grg_main) IP_LOG="$IP_GSUBJ" ;; *) IP_LOG="$IP_SUBJ" ;; esac
  ( ip_scrub; fx_inproc "$IP_LOG"; . "$IP_F" || exit 126; "$IP_E" "$@" )
}
bash() { # a `bash <rotator>` is answered in process; every other bash is the real one; env FXCELL=<id> bash is the cli cell
  if [ -z "${FXCELL:-}" ] && [ -n "${1:-}" ] && ip_entry "$1" > /dev/null 2>&1 && [ -r "$1" ]; then ip_call "$@"; else command bash "$@"; fi
}
# cli_eqv <id> <cwd> <args...> -- one `env FXCELL=<id> bash $ROT` start and one in-process call over the SAME input from <cwd>,
# stdout, stderr and exit compared byte for byte. A report or a refusal: neither writes.
EQ="$(mktemp -d "${TMPDIR:-/tmp}/gar-eq.XXXXXX")" || exit 2
trap 'rm -rf "$EQ"' EXIT
cli_eqv() {
  local id="$1" cwd="$2"; shift 2
  ( cd "$cwd" && ip_call "$ROT" "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$cwd" && env FXCELL="$id" bash "$ROT" "$@" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  if cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc" \
     && { [ -s "$EQ/$id.cl.out" ] || [ -s "$EQ/$id.cl.err" ]; }; then
    ok "($id) the command line and the in-process call agree byte for byte (exit $(cat "$EQ/$id.cl.rc"))"
  else
    bad "($id) command line and in-process differ: exit $(cat "$EQ/$id.cl.rc") vs $(cat "$EQ/$id.ip.rc"); stdout $(cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && echo equal || echo DIFFERS), stderr $(cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && echo equal || echo DIFFERS)"
  fi
}

seed() { # <case> -> sets W/PROJ/GA/DEST_S308, or aborts the whole run
  W="$(bash "$HERE/seed.sh" "$1")" || { echo "FIXTURE ERROR: seed.sh '$1' exited non-zero" >&2; exit 2; }
  [ -n "$W" ] && [ -d "$W" ] && [ -f "$W/env.sh" ] \
    || { echo "FIXTURE ERROR: seed '$1' produced no usable workspace ('${W}')" >&2; exit 2; }
  # shellcheck source=/dev/null
  . "$W/env.sh"
}

# A recursive, order-independent digest of a directory's CONTENT — relative path plus
# shasum per file, sorted. Two calls comparing equal is the same evidence `cmp -s` gives a
# single file, extended to a whole tree, so a rotator that touched anything unexpected
# (renamed the wrong file, edited bytes in passing, left a stray temp file) is caught even
# though this fixture never names every path up front.
treehash() { ( cd "$1" 2>/dev/null && find . -type f | sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(shasum "$f" | cut -d' ' -f1)" "$f"; done ) }

drive() { # <projdir> <tool> <file_path> <cell id> -> the guard's stdout JSON
  local w="$1" tool="$2" fp="$3" cell="$4"
  jq -nc --arg t "$tool" --arg f "$fp" \
    '{session_id:"t", tool_name:$t, tool_input:{file_path:$f}}' \
    | CLAUDE_PROJECT_DIR="$w" AI_DLC_GATE_METRICS="" bash "$GUARD" 2>/dev/null
}
denied() { case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) return 0 ;; esac; return 1; }
# guard_eqv <id> <file_path under the project> -- one `env FXCELL=<id> bash $GUARD` start and one in-process call over the SAME
# payload, each on its own copy of the project (the hook logs a denial into it): stdout, stderr and exit byte for byte
# after the copy's path is normalised.
guard_eqv() {
  local id="$1" rel="$2" d
  for d in ip cl; do
    rm -rf "$EQ/$id.$d"; cp -R "$PROJ" "$EQ/$id.$d" || { bad "($id) could not copy the project"; return; }
    jq -nc --arg f "$EQ/$id.$d/$rel" '{session_id:"t", tool_name:"Edit", tool_input:{file_path:$f}}' > "$EQ/$id.$d.in"
  done
  CLAUDE_PROJECT_DIR="$EQ/$id.ip" AI_DLC_GATE_METRICS="" ip_call "$GUARD" < "$EQ/$id.ip.in" > "$EQ/$id.ip.out0" 2> "$EQ/$id.ip.err0"; echo "$?" > "$EQ/$id.ip.rc"
  CLAUDE_PROJECT_DIR="$EQ/$id.cl" AI_DLC_GATE_METRICS="" env FXCELL="$id" bash "$GUARD" < "$EQ/$id.cl.in" > "$EQ/$id.cl.out0" 2> "$EQ/$id.cl.err0"; echo "$?" > "$EQ/$id.cl.rc"
  for d in ip cl; do
    sed "s|$EQ/$id.$d|DIR|g" "$EQ/$id.$d.out0" > "$EQ/$id.$d.out"; sed "s|$EQ/$id.$d|DIR|g" "$EQ/$id.$d.err0" > "$EQ/$id.$d.err"
  done
}

# The rotator resolves its repo root by walking UP from the CURRENT WORKING DIRECTORY
# (CLAUDE.md: "resolve the repo root by walking up for a marker"), and the seeded project
# IS its own git repo (seed.sh runs `git init` inside it). So every invocation in this
# fixture runs from INSIDE the seeded $PROJ, never from this fixture's own directory --
# running from here would walk up to the ai-dlc repo itself and silently operate on ITS
# `_bmad-output`, which is exactly the false-zero shape CLAUDE.md warns about (a command
# that "ran" and answered about the wrong tree).
rotate() { ( cd "$PROJ" && bash "$ROT" "$@" ); }

echo "gate-adjudication-rotate:"

# =============================================================================
# ARM 0 — SANITY: the base seed holds the shape every later arm depends on.
# =============================================================================
seed base
N_VERDICTS="$(find "$GA" -maxdepth 1 -name '*.verdict.json' | wc -l | tr -d ' ')"
N_SIDECARS="$(find "$GA" -maxdepth 1 \( -name '*.repair.md' -o -name '*.authorization.md' \) | wc -l | tr -d ' ')"
N_LEGACY="$(grep -L 'gate_series_id' "$GA"/*.verdict.json 2>/dev/null | wc -l | tr -d ' ')"
N_SUBDIR="$(find "$GA" -mindepth 2 -type f | wc -l | tr -d ' ')"
if [ "$N_VERDICTS" -eq 3 ] && [ "$N_SIDECARS" -eq 2 ] && [ "$N_LEGACY" -eq 1 ] && [ "$N_SUBDIR" -eq 1 ] \
   && [ -f "$GA/.verdict-writes.jsonl" ]; then
  ok "(0) seed: 3 verdicts (s308 FAIL, s309 PASS, 1 legacy), 2 sidecars, 1 subdir file, 1 write-ledger"
else
  bad "FIXTURE BROKEN — seed shape wrong (verdicts=${N_VERDICTS} sidecars=${N_SIDECARS} legacy=${N_LEGACY} subdir=${N_SUBDIR})"
  echo; echo "gate-adjudication-rotate: FIXTURE BROKEN" >&2; exit 2
fi

# =============================================================================
# ARM (a) — report mode writes nothing.
# =============================================================================
BEFORE_A="$(treehash "$PROJ")"
out="$(rotate --sprint s308 2>&1)"; rc=$?
AFTER_A="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_A" = "$AFTER_A" ] && [ ! -d "$DEST_S308" ] \
   && grep -q '3 file(s) total\|1 verdict(s) and 2 sidecar(s)' <<<"$out"; then
  ok "(a) report mode (--sprint s308, no --apply): tree byte-identical, no destination created"
else
  bad "(a) report mode changed the tree or misreported (rc=$rc): $(head -1 <<<"$out")"
fi
# The two cli cells, on the same untouched world: the report (exit 0) and the usage refusal (exit 2).
cli_eqv cli-report "$PROJ" --sprint s308
cli_eqv cli-refuse "$PROJ" --no-such-option

# =============================================================================
# ARM (b) — apply moves exactly the s308 set, byte-equal, source absent.
# =============================================================================
SNAP="$W/snap"; mkdir -p "$SNAP"
S308_VERDICT="sprint-review-20260907T002257Z.verdict.json"
S308_REPAIR="sprint-review-20260907T002257Z.repair.md"
S308_AUTH="sprint-review-20260907T002257Z.authorization.md"
for f in "$S308_VERDICT" "$S308_REPAIR" "$S308_AUTH"; do cp "$GA/$f" "$SNAP/$f"; done

out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
ALL_BYTE_EQUAL=1
for f in "$S308_VERDICT" "$S308_REPAIR" "$S308_AUTH"; do
  cmp -s "$SNAP/$f" "$DEST_S308/$f" || ALL_BYTE_EQUAL=0
  [ -e "$GA/$f" ] && ALL_BYTE_EQUAL=0   # must be absent from the source now
done
if [ "$rc" -eq 0 ] && [ "$ALL_BYTE_EQUAL" -eq 1 ]; then
  ok "(b) apply --sprint s308: moved the verdict + 2 sidecars, byte-equal at the destination, gone from the source"
else
  bad "(b) apply did not move the s308 set cleanly (rc=$rc): $out"
fi

# =============================================================================
# ARM (c) — everything else stays, byte-identical.
# =============================================================================
REMAIN_OK=1
[ -f "$GA/planning-20260907T160702Z.verdict.json" ] || REMAIN_OK=0
[ -f "$GA/implementation-20260720T011606Z.verdict.json" ] || REMAIN_OK=0
[ -f "$GA/.verdict-writes.jsonl" ] || REMAIN_OK=0
[ -f "$GA/s293/f.md" ] || REMAIN_OK=0
[ ! -e "$DEST_S308/planning-20260907T160702Z.verdict.json" ] || REMAIN_OK=0
if [ "$REMAIN_OK" -eq 1 ]; then
  ok "(c) the s309 verdict, the legacy verdict, the write-ledger and s293/ all stayed in place"
else
  bad "(c) something that should not have moved is gone or wrongly relocated"
fi

# =============================================================================
# ARM (d) — REFUSAL: a git-ignored destination. Fresh seed, nothing written.
# =============================================================================
seed ignored
BEFORE_D="$(treehash "$GA")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_D="$(treehash "$GA")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_D" = "$AFTER_D" ] && [ ! -d "$DEST_S308" ] && grep -q 'git-ignored' <<<"$out"; then
  ok "(d) REFUSAL: a git-ignored destination is refused (exit 1), source tree byte-identical, nothing written"
else
  bad "(d) an ignored destination was not refused cleanly (rc=$rc, tree changed: $([ "$BEFORE_D" = "$AFTER_D" ] && echo no || echo yes))"
fi

# =============================================================================
# ARM (d2) — idempotence: a second --apply for an already-rotated sprint moves nothing.
# =============================================================================
seed base
rotate --sprint s308 --apply >/dev/null 2>&1
BEFORE_D2="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_D2="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_D2" = "$AFTER_D2" ] && grep -q 'nothing to move' <<<"$out"; then
  ok "(d2) a second --apply for s308 reports zero moves and exits 0, tree unchanged"
else
  bad "(d2) a second --apply was not a clean no-op (rc=$rc): $out"
fi

# =============================================================================
# ARM (e) — THE GUARD CONTROL. Fresh world with ONLY the s308 FAIL verdict live.
# =============================================================================
seed guardworld
TARGET="$PROJ/_bmad-output/planning-artifacts/s309/x.md"

OUT1="$(drive "$PROJ" Edit "$TARGET" e-deny-live)"
if denied "$OUT1"; then
  ok "(e.1) BEFORE rotation: the s308 FAIL verdict is the only live pass and the lead's edit is DENIED (reproduces DEFECT 1)"
else
  bad "(e.1) FIXTURE COULD NOT REPRODUCE THE DEFECT — the pre-rotation edit was not denied, so this arm cannot fire: $OUT1"
fi

guard_eqv cli-guard-deny "_bmad-output/planning-artifacts/s309/x.md"
if cmp -s "$EQ/cli-guard-deny.ip.out" "$EQ/cli-guard-deny.cl.out" && cmp -s "$EQ/cli-guard-deny.ip.err" "$EQ/cli-guard-deny.cl.err" \
   && cmp -s "$EQ/cli-guard-deny.ip.rc" "$EQ/cli-guard-deny.cl.rc" && [ "$(cat "$EQ/cli-guard-deny.cl.rc")" = 0 ] && denied "$(cat "$EQ/cli-guard-deny.cl.out")"; then
  ok "(cli-guard-deny) the program denies the live-FAIL edit exactly as the in-process call does (stdout, stderr, exit 0)"
else
  bad "(cli-guard-deny) the program and the in-process call differ, or the program did not deny"
fi

rotate --sprint s308 --apply >/dev/null 2>&1

guard_eqv cli-guard-allow "_bmad-output/planning-artifacts/s309/x.md"
if cmp -s "$EQ/cli-guard-allow.ip.out" "$EQ/cli-guard-allow.cl.out" && cmp -s "$EQ/cli-guard-allow.ip.err" "$EQ/cli-guard-allow.cl.err" \
   && cmp -s "$EQ/cli-guard-allow.ip.rc" "$EQ/cli-guard-allow.cl.rc" && [ "$(cat "$EQ/cli-guard-allow.cl.rc")" = 0 ] && [ ! -s "$EQ/cli-guard-allow.cl.out" ]; then
  ok "(cli-guard-allow) the program allows the rotated tree's edit silently, exactly as the in-process call does (stdout, stderr, exit 0)"
else
  bad "(cli-guard-allow) the program and the in-process call differ, or the program printed a decision"
fi

OUT2="$(drive "$PROJ" Edit "$TARGET" e-allow-rotated)"
if ! denied "$OUT2"; then
  ok "(e.2) AFTER rotation: the same edit is ALLOWED — the closed sprint's FAIL is no longer the live pass"
else
  bad "(e.2) rotation did not clear the deny: $OUT2"
fi

cat > "$GA/planning-20260907T160702Z.verdict.json" <<'EOF'
{
  "schema_id": "GATE_ADJUDICATION_VERDICT v1",
  "gate_type": "planning",
  "gate_nonce": "planning-20260907T160702Z",
  "generated_at": "2026-09-07T16:07:02Z",
  "adjudicator_agent_id": "gate-adjudicator@session-seed",
  "gate_series_id": "planning-s309-20260907T160702Z",
  "catalog": "core",
  "verdicts": [{"check_id":"1","verdict":"FAIL","evidence":"seeded, current sprint"}]
}
EOF

OUT3="$(drive "$PROJ" Edit "$TARGET" e-deny-current)"
if denied "$OUT3"; then
  ok "(e.3) CONTROL: a live CURRENT-sprint FAIL still DENIES after rotation — rotation did not blind the guard"
else
  bad "(e.3) CONTROL FAILED: a live current-sprint FAIL was allowed after rotation: $OUT3"
fi

# =============================================================================
# ARM (f) — a legacy-only directory: apply moves nothing, exit 0.
# =============================================================================
seed legacyonly
BEFORE_F="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_F="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_F" = "$AFTER_F" ] && grep -q 'nothing to move' <<<"$out"; then
  ok "(f) a directory holding only a legacy (no gate_series_id) verdict: apply moves nothing, exits 0"
else
  bad "(f) a legacy-only directory was not left alone (rc=$rc): $out"
fi

# =============================================================================
# ARM (g) — REFUSAL: an unparseable *.verdict.json. Nothing moved, nothing written.
# =============================================================================
seed badjson
BEFORE_G="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_G="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_G" = "$AFTER_G" ] && grep -q 'do not parse as JSON' <<<"$out"; then
  ok "(g) REFUSAL: an unparseable *.verdict.json refuses the whole run (exit 1), tree byte-identical"
else
  bad "(g) an unparseable verdict was not refused cleanly (rc=$rc): $out"
fi

# =============================================================================
# ARM (h) — REFUSAL: the rotation would STRAND a FAILing legacy verdict.
#
# The two cases differ in exactly ONE property: whether the legacy verdict left
# behind records a FAIL. Both must be here, because a refusal keyed on legacy-ness
# ALONE passes (h.1) and is a wrong fix -- it would refuse 94 files on the
# reference consumer and break every legitimate close. (h.2) is what convicts it.
# =============================================================================
seed strand
BEFORE_H="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_H="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_H" = "$AFTER_H" ] \
   && grep -q 'no mode can move' <<<"$out" \
   && grep -q 'carries no gate_series_id' <<<"$out" \
   && grep -q 'legacy-20260701T000000Z' <<<"$out"; then
  ok "(h.1) REFUSAL: rotating s308 PROMOTES a FAILing legacy verdict to newest — refused (exit 1), tree byte-identical, offender named"
else
  bad "(h.1) a rotation that strands a FAILing legacy verdict was not refused (rc=$rc): $out"
fi

# The offender's remedy must name an action THIS tool honours. An earlier revision
# printed "write a repair or authorization record", which the refusal never reads —
# a remedy the consumer follows to no effect. Assert the executable one is offered.
if grep -q -- '--legacy-through' <<<"$out"; then
  ok "(h.1b) the refusal offers a remedy this tool can execute (--legacy-through), not a sidecar it never reads"
else
  bad "(h.1b) the refusal named no executable remedy: $out"
fi

seed strand-nearmiss
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'would strand' <<<"$out" \
   && [ -f "$DEST_S308/sprint-review-20260907T002257Z.verdict.json" ]; then
  ok "(h.2) NEAR-MISS: a CLEAN legacy verdict rotates normally AND the move landed — the refusal is keyed on the FAIL, not on legacy-ness"
else
  bad "(h.2) a clean legacy verdict was wrongly refused, or the move did not land (rc=$rc): $out"
fi

# =============================================================================
# ARM (h.3) — a FAILing legacy verdict that the rotation does NOT promote.
#
# THE ARM THAT CONVICTS A SURVIVORSHIP-BLIND PREDICATE. (h.1) and (h.2) both pass
# against "refuse if any legacy verdict anywhere records a FAIL" — a fix that
# refuses EVERY rotation on the reference consumer. Here the FAILing legacy
# verdict is shadowed by a newer verdict that does not move, so the correct
# answer is PROCEED, and the destination assertion stops "exit 0 having moved
# nothing" from passing as a rotation.
# =============================================================================
seed strand-shadowed
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'would strand' <<<"$out" \
   && [ -f "$DEST_S308/sprint-review-20260907T002257Z.verdict.json" ]; then
  ok "(h.3) a FAILing legacy verdict SHADOWED by a newer non-moving verdict does not block the rotation, and the move landed"
else
  bad "(h.3) a shadowed FAILing legacy verdict wrongly blocked the rotation, or the move did not land (rc=$rc): $out"
fi

# =============================================================================
# ARM (h.4) — the SECOND unmovable shape: a survivor with a series id that no
# `*-s<N>-*` selector can name. A verdict minted before the series-id form was
# prescribed can carry such an id, so this is real input, and it is worse than a legacy verdict
# because `--legacy-through` skips it too. A predicate keyed on legacy-ness
# scores it movable and lets the rotation strand it — no refusal, no escape.
# =============================================================================
seed strand-unselectable
BEFORE_H4="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_H4="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_H4" = "$AFTER_H4" ] \
   && grep -q 'no mode can move' <<<"$out" \
   && grep -q 'matches no --sprint selector' <<<"$out"; then
  ok "(h.4) REFUSAL: a survivor whose gate_series_id no selector can name is refused too, and the row says WHY it is unmovable"
else
  bad "(h.4) an unselectable FAILing survivor was not refused (rc=$rc): $out"
fi

# Its remedy must NOT be the legacy one — --legacy-through cannot move a verdict
# that has a series id, so printing it here would be a second inert remedy.
# Keyed on the PRESCRIBED COMMAND LINE, not on the token: the prose explains why
# --legacy-through does not apply here, so a bare token grep matches that
# explanation and reads as the wrong remedy being offered.
if ! grep -qE '^ +bash [^ ]*rotate-gate-adjudication\.sh --legacy-through' <<<"$out" \
   && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series 's310-planning' --apply$" <<<"$out" \
   && grep -q 'Re-stamp that' <<<"$out"; then
  ok "(h.4b) the unselectable case prescribes a re-stamp and does NOT offer the legacy escape, which cannot move it"
else
  bad "(h.4b) the unselectable case printed the wrong remedy: $out"
fi

# (h.4c) A SECOND UNSELECTABLE SHAPE, one property apart from (h.4)'s. One shape
# cannot distinguish a predicate that asks the selector's question from one that
# hardcodes the seeded string: a wrong fix special-casing `s<N>-*` passed (h.4)
# and (h.4b) while stranding four of the five unselectable shapes. This seed is
# sprint-LAST and shares no prefix with the sprint-first one.
seed strand-unselectable2
BEFORE_H4C="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_H4C="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_H4C" = "$AFTER_H4C" ] \
   && grep -q 'no mode can move' <<<"$out" \
   && grep -q "x-s310" <<<"$out"; then
  ok "(h.4c) a DIFFERENTLY-SHAPED unselectable survivor is refused too — the predicate asks the selector's question rather than matching one spelling"
else
  bad "(h.4c) a sprint-last unselectable survivor was not refused (rc=$rc): $out"
fi

# =============================================================================
# ARM (i) — the legacy escape the refusal prescribes actually works.
#
# A refusal whose remedy cannot be executed is the defect the remedy text exists
# to avoid, so the remedy is asserted here rather than trusted: rotating the
# pre-series verdicts out must let the previously-refused rotation proceed.
# =============================================================================
#
# THE BOUND IS PARSED OUT OF THE REFUSAL'S OWN OUTPUT AND EXECUTED VERBATIM. An
# earlier revision hardcoded a bound, which is why it could not see a strict-`<`
# off-by-one: the printed command moved everything EXCEPT the verdict it named,
# so the next close re-printed the identical bound and a consumer following the
# message looped forever. A hardcoded bound made that converge and proved nothing.
# It also let a one-line wrong fix — print an impossible bound like
# `00000000T000000Z`, which selects nothing — pass every arm.
seed strand
refusal="$(rotate --sprint s308 --apply 2>&1)"
PRINTED_BOUND="$(grep -oE -- '--legacy-through [0-9]{8}T[0-9]{6}Z' <<<"$refusal" | head -1 | awk '{print $2}')"
if [ -z "$PRINTED_BOUND" ]; then
  bad "(i) the refusal printed no executable bound to run: $refusal"
else
  out="$(rotate --legacy-through "$PRINTED_BOUND" --apply 2>&1)"; rc_i=$?
  # The verdict the refusal NAMED must be the one the printed command removes.
  legacy_gone=1; [ -e "$GA/legacy-20260701T000000Z.verdict.json" ] && legacy_gone=0
  out2="$(rotate --sprint s308 --apply 2>&1)"; rc_i2=$?
  if [ "$rc_i" -eq 0 ] && [ "$rc_i2" -eq 0 ] && [ "$legacy_gone" -eq 1 ] \
     && [ -f "$DEST_S308/sprint-review-20260907T002257Z.verdict.json" ]; then
    ok "(i) running the refusal's OWN printed bound (${PRINTED_BOUND}) removes the verdict it named and unblocks the rotation in ONE run — the remedy converges"
  else
    bad "(i) the printed remedy did not converge (legacy rc=$rc_i, named-verdict-removed=$legacy_gone, sprint rc=$rc_i2): $out / $out2"
  fi
fi

# The bound is not decorative: a legacy verdict at or after it must NOT move.
seed strand
out="$(rotate --legacy-through 20260101T000000Z --apply 2>&1)"; rc_i3=$?
if [ "$rc_i3" -eq 0 ] && grep -q 'nothing to move' <<<"$out"; then
  ok "(i.2) --legacy-through honours its bound: a legacy verdict NEWER than the bound is left alone"
else
  bad "(i.2) the --legacy-through bound was not honoured (rc=$rc_i3): $out"
fi

# =============================================================================
# ARM (j) — REFUSAL: an EMPTY --sprint selection while an unmatchable series (an id
# no --sprint can name) records a FAIL. Before this arm the rotator said "nothing
# to move" and exited 0, so retro passed while the sprint's verdicts stayed live.
# The FAIL-carrying unmatchable verdict is NOT the newest -- a PASS-only one sorts
# above it -- so the survivor block's FAIL refusal cannot be what refuses here; a
# legacy verdict sits beside them and must NOT be named.
# =============================================================================
UM_STEM="planning-20260910T120000Z"   # PASS-only unmatchable, the newest
UM_FAIL="planning-20260909T120000Z"   # FAIL-carrying unmatchable, older
# The refusal block alone: from the REFUSED line up to the WARN that may follow it.
refusal_block() { awk '/REFUSED --/{f=1} /WARN --/{f=0} f' <<<"$1"; }
warn_block()    { awk '/WARN --/{f=1} f' <<<"$1"; }
seed unmatchable
BEFORE_J="$(treehash "$PROJ")"
out_j="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_J="$(treehash "$PROJ")"
ref_j="$(refusal_block "$out_j")"; warn_j="$(warn_block "$out_j")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_J" = "$AFTER_J" ] \
   && grep -q "^    .*/${UM_FAIL}\.verdict\.json$" <<<"$ref_j" \
   && ! grep -q "/${UM_STEM}\.verdict\.json$" <<<"$ref_j" \
   && grep -q "^    .*/${UM_STEM}\.verdict\.json$" <<<"$warn_j" \
   && ! grep -q 'implementation-20260720T011606Z' <<<"$out_j" \
   && ! grep -q 'nothing to move' <<<"$out_j"; then
  ok "(j) REFUSAL: empty s308 selection plus an older FAIL-carrying unmatchable verdict exits 1, names it in the refusal, WARNs the newer PASS-only one, not the legacy one, tree byte-identical"
else
  bad "(j) an empty selection beside a FAIL-carrying unmatchable series id was not refused as specified (rc=$rc): $out_j"
fi

# (j.0) THE NEAR-MISS: the same world without the FAIL series. A stale clean verdict
# is the guard's allow state, so the close WARNs and proceeds.
seed unmatchable-pass
BEFORE_J0="$(treehash "$PROJ")"
out_j0="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_J0="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_J0" = "$AFTER_J0" ] && grep -q 'nothing to move' <<<"$out_j0" \
   && ! grep -q 'REFUSED' <<<"$out_j0" \
   && grep -q "^    .*/${UM_STEM}\.verdict\.json$" <<<"$(warn_block "$out_j0")" \
   && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_STEM}'$" <<<"$out_j0" \
   && grep -qF 'NO HINT (..s308)' <<<"$out_j0"; then
  ok "(j.0) NEAR-MISS: an empty selection beside a PASS-only unmatchable verdict WARNs with its escape and exits 0 'nothing to move'; with no archive the sprint is NO HINT (..s308)"
else
  bad "(j.0) a PASS-only unmatchable verdict was refused or not WARNed (rc=$rc): $out_j0"
fi

# (j.2) The escape is printed as a dry-run command, and with no sprint archive its
# sprint is the `s<N>` placeholder under NO HINT: the lead asks the operator and
# substitutes the answer. The arm plays that lead -- the operator says s309, a sprint
# other than the one closing -- and EXECUTES THE PRINTED LINE with only `s<N>`
# replaced: dry run writes nothing, --apply moves the verdict and its sidecar, and the
# refused command then exits 0.
OPERATOR_SPRINT="s309"
ESC_LINE="$(grep -E "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '[^']+'$" <<<"$ref_j" | head -1)"
ESC_SPRINT="$OPERATOR_SPRINT"
ESC_ID="$(sed -n "s/.*--series '\\([^']*\\)'\$/\\1/p" <<<"$ESC_LINE")"
seed unmatchable
if [ -z "$ESC_LINE" ] || [ "$ESC_ID" != "$UM_FAIL" ] || ! grep -qF 'NO HINT (..s308)' <<<"$ref_j"; then
  bad "(j.2) the refusal printed no runnable --series escape for '${UM_FAIL}' under NO HINT (..s308): $out_j"
else
  BEFORE_JD="$(treehash "$PROJ")"
  out_d="$(rotate --sprint "$ESC_SPRINT" --series "$ESC_ID" 2>&1)"; rc_d=$?
  AFTER_JD="$(treehash "$PROJ")"
  out_a="$(rotate --sprint "$ESC_SPRINT" --series "$ESC_ID" --apply 2>&1)"; rc_a=$?
  D_ESC="$PROJ/_bmad-output/implementation-artifacts/${ESC_SPRINT}/gate-adjudication"
  out_r="$(rotate --sprint s308 --apply 2>&1)"; rc_r=$?
  if [ "$rc_d" -eq 0 ] && [ "$AFTER_JD" = "$BEFORE_JD" ] && [ "$rc_a" -eq 0 ] \
     && [ -f "$D_ESC/${UM_FAIL}.verdict.json" ] && [ -f "$D_ESC/${UM_FAIL}.repair.md" ] \
     && [ ! -e "$GA/${UM_FAIL}.verdict.json" ] && [ -f "$GA/implementation-20260720T011606Z.verdict.json" ] \
     && [ -f "$GA/${UM_STEM}.verdict.json" ] \
     && [ "$rc_r" -eq 0 ] && grep -q 'nothing to move' <<<"$out_r"; then
    ok "(j.2) the printed escape (--sprint ${ESC_SPRINT} --series '${ESC_ID}') is a dry run as printed, moves verdict + sidecar with --apply, and the refused close then exits 0"
  else
    bad "(j.2) the printed escape did not converge (dry rc=$rc_d, apply rc=$rc_a, re-run rc=$rc_r): $out_a / $out_r"
  fi
fi

# (j.3) A FAIL-carrying id that is NOT nonce-tailed -- `story-s311`, a shape the
# reference consumer's writers stamp -- is the only unmatchable verdict. A predicate
# counting only `<gate>-<nonce>` ids misses it.
seed story-s311
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q '^    .*/story-20260913T044428Z\.verdict\.json$' <<<"$(refusal_block "$out")"; then
  ok "(j.3) a FAIL-carrying 'story-s311' id, not nonce-tailed, refuses the empty selection and is named"
else
  bad "(j.3) a FAIL-carrying 'story-s311' id did not refuse (rc=$rc): $out"
fi

# (j.4) An id carrying an apostrophe is printed quoted, so the line pastes as printed.
# Parsed by the shell itself, then executed: the id must arrive intact and move.
seed apostrophe
out="$(rotate --sprint s308 2>&1)"; rc=$?
# With no archive the sprint is the `s<N>` placeholder, which would parse as a redirect,
# so the operator's sprint replaces it before eval -- exactly the lead's substitution.
AP_LINE="$(grep -E "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '[^<>|;&\`\$]*'$" <<<"$(refusal_block "$out")" | head -1)"
AP_LINE="${AP_LINE/--sprint s<N> /--sprint s308 }"
AP_SPRINT=""; AP_ID=""
if [ -n "$AP_LINE" ]; then eval "set -- $AP_LINE"; AP_SPRINT="${4:-}"; AP_ID="${6:-}"; fi
if [ "$rc" -eq 1 ] && [ "$AP_ID" = "it's-planning-20260909T130000Z" ]; then
  out_ap="$(rotate --sprint "$AP_SPRINT" --series "$AP_ID" --apply 2>&1)"; rc_ap=$?
  if [ "$rc_ap" -eq 0 ] && [ -f "$PROJ/_bmad-output/implementation-artifacts/${AP_SPRINT}/gate-adjudication/planning-20260909T130000Z.verdict.json" ] \
     && [ ! -e "$GA/planning-20260909T130000Z.verdict.json" ]; then
    ok "(j.4) an id with an apostrophe is printed shell-quoted; the parsed line carries it intact and moves the verdict"
  else
    bad "(j.4) the parsed apostrophe id did not move (rc=$rc_ap): $out_ap"
  fi
else
  bad "(j.4) the apostrophe id was not printed pasteable (rc=$rc, parsed id='${AP_ID}'): $out"
fi

# (j.5) THE HINT WINDOW. The FAIL-carrying verdict is newer than the only archive,
# s309. Closing s310 leaves one candidate sprint, so it is hinted; closing s311
# leaves s310..s311, so no sprint is hinted and the placeholder is printed.
seed hint-window
out10="$(rotate --sprint s310 2>&1)"; rc10=$?
out11="$(rotate --sprint s311 2>&1)"; rc11=$?
if [ "$rc10" -eq 1 ] && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s310 --series '${UM_FAIL}'$" <<<"$out10" \
   && [ "$rc11" -eq 1 ] && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_FAIL}'$" <<<"$out11" \
   && grep -q 'NO HINT (s310\.\.s311)' <<<"$out11"; then
  ok "(j.5) newer than the newest archive: hinted s310 when that is the only candidate, NO HINT (s310..s311) when it is not"
else
  bad "(j.5) the hint window was not honoured (s310 rc=$rc10, s311 rc=$rc11): $out10 / $out11"
fi

# (j.5b) THE GAP WINDOW. The same verdict between two archives. s309 and s311
# leave s310 alone, so it is hinted whatever sprint is closing; s309 and s310 are
# adjacent, so the archive below may be incomplete and nothing is hinted.
seed hint-gap
out_g="$(rotate --sprint s312 2>&1)"; rc_g=$?
seed hint-adjacent
out_a="$(rotate --sprint s312 2>&1)"; rc_a=$?
if [ "$rc_g" -eq 1 ] && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s310 --series '${UM_FAIL}'$" <<<"$out_g" \
   && [ "$rc_a" -eq 1 ] && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_FAIL}'$" <<<"$out_a" \
   && grep -q 'NO HINT (s309\.\.s310)' <<<"$out_a"; then
  ok "(j.5b) between archives: hinted s310 when it is alone in the gap, NO HINT (s309..s310) between adjacent archives"
else
  bad "(j.5b) the gap window was not honoured (gap rc=$rc_g, adjacent rc=$rc_a): $out_g / $out_a"
fi

# (j.5c) A WIDE GAP: archives s309 and s312, the verdict between them, closing s313.
# Two candidates, s310..s311, so no hint -- in particular not the sprint being closed.
seed hint-wide-gap
out_w="$(rotate --sprint s313 2>&1)"; rc_w=$?
if [ "$rc_w" -eq 1 ] && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_FAIL}'$" <<<"$out_w" \
   && grep -qF 'NO HINT (s310..s311)' <<<"$out_w" && ! grep -q -- '--sprint s313 --series' <<<"$out_w"; then
  ok "(j.5c) between archives s309 and s312, closing s313: NO HINT (s310..s311), never the closing sprint"
else
  bad "(j.5c) the wide gap was hinted (rc=$rc_w): $out_w"
fi

# (j.5d) A BACKFILL: the verdict is newer than the newest archive, s309, while the
# sprint being closed is s308. The window above s309 is empty, and the line must not
# print an inverted range such as s310..s308.
seed hint-window
out_bf="$(rotate --sprint s308 2>&1)"; rc_bf=$?
if [ "$rc_bf" -eq 1 ] && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_FAIL}'$" <<<"$out_bf" \
   && grep -qF 'NO HINT (backfill below s310)' <<<"$out_bf" && ! grep -qF 's310..s308' <<<"$out_bf"; then
  ok "(j.5d) a backfill below the newest archive prints NO HINT (backfill below s310), not an inverted range"
else
  bad "(j.5d) the backfill hint was wrong (rc=$rc_bf): $out_bf"
fi

# (j.9) NEWEST MEMBER. One unmatchable series: an older FAIL and a newer PASSing retry
# under the same id. The series moves whole, so the older FAIL can never be the live
# pass: WARN, exit 0. Its twin, one property apart -- the NEWEST member FAILs -- refuses.
seed series-newest-pass
out_np="$(rotate --sprint s308 --apply 2>&1)"; rc_np=$?
seed series-newest-fail
out_nf="$(rotate --sprint s308 --apply 2>&1)"; rc_nf=$?
if [ "$rc_np" -eq 0 ] && ! grep -q 'REFUSED' <<<"$out_np" && grep -q 'nothing to move' <<<"$out_np" \
   && grep -q '^    .*/planning-20260909T120000Z\.verdict\.json$' <<<"$(warn_block "$out_np")" \
   && [ "$rc_nf" -eq 1 ] && grep -q '^    .*/planning-20260909T120000Z\.verdict\.json$' <<<"$(refusal_block "$out_nf")" \
   && grep -q '^    .*/planning-20260912T000000Z\.verdict\.json$' <<<"$(refusal_block "$out_nf")"; then
  ok "(j.9) a series whose older member FAILs and newest PASSes is WARNed (exit 0); its twin with the newest FAILing refuses and names both files"
else
  bad "(j.9) the series was not keyed on its newest member (pass-newest rc=$rc_np, fail-newest rc=$rc_nf): $out_np / $out_nf"
fi

# (j.10) A --sprint CLOSE THAT LEAVES AN UNMOVABLE FAIL AS THE LIVE PASS REFUSES, PROMOTED
# OR NOT. The FAIL-carrying unmatchable verdict is newer than the s308 verdict, so it is
# the live pass before the move and after it. Nothing follows the close to clear it, so it
# would deny the next sprint's first edit: the close refuses, names it, writes nothing.
seed reapply
BEFORE_R="$(treehash "$PROJ")"
out_r1="$(rotate --sprint s308 --apply 2>&1)"; rc_r1=$?
AFTER_R="$(treehash "$PROJ")"
if [ "$rc_r1" -eq 1 ] && grep -q 'would strand' <<<"$out_r1" && grep -q "${UM_FAIL} -- " <<<"$out_r1" \
   && [ "$BEFORE_R" = "$AFTER_R" ] && [ -f "$GA/sprint-review-20260907T002257Z.verdict.json" ]; then
  ok "(j.10) a --sprint close leaving an unpromoted unmatchable FAIL as the live pass refuses (exit 1), names it, tree byte-identical"
else
  bad "(j.10) a close leaving a FAILing unmatchable live pass was not refused (rc=$rc_r1): $out_r1"
fi

# (j.11) THE PARTIAL WALK. Two FAIL-carrying unmatchable series, older A and newer B, no
# tagged s308 verdict. The operator runs only the FIRST printed line (A into s308), which
# fills s308's archive while B stays the live pass: the re-run must still refuse. Then
# line 2, and the re-run is exit 0.
UM_FAIL_B="implementation-20260914T000000Z"
seed partial-walk
out_p0="$(rotate --sprint s308 2>&1)"; rc_p0=$?
p_lines="$(grep -E "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '[^']+'$" <<<"$out_p0" | sed -n "s/.*--series '\\([^']*\\)'\$/\\1/p" | tr '\n' ' ')"
out_p1="$(rotate --sprint s308 --series "$UM_FAIL" --apply 2>&1)"; rc_p1=$?
out_p2="$(rotate --sprint s308 --apply 2>&1)"; rc_p2=$?
out_p3="$(rotate --sprint s308 --series "$UM_FAIL_B" --apply 2>&1)"; rc_p3=$?
out_p4="$(rotate --sprint s308 --apply 2>&1)"; rc_p4=$?
if [ "$rc_p0" -eq 1 ] && [ "$p_lines" = "${UM_FAIL} ${UM_FAIL_B} " ] \
   && [ "$rc_p1" -eq 0 ] && [ -f "$DEST_S308/${UM_FAIL}.verdict.json" ] \
   && [ "$rc_p2" -eq 1 ] && grep -q "^    .*/${UM_FAIL_B}\.verdict\.json$" <<<"$(refusal_block "$out_p2")" \
   && [ "$rc_p3" -eq 0 ] && [ -f "$DEST_S308/${UM_FAIL_B}.verdict.json" ] && [ "$rc_p4" -eq 0 ] && grep -q 'nothing to move' <<<"$out_p4" \
   && ! grep -q 'REFUSED' <<<"$out_p4"; then
  ok "(j.11) partial walk: line 1 alone fills s308's archive and the re-run still refuses on the live newer FAIL; after line 2 the re-run exits 0"
else
  bad "(j.11) the partial walk was not re-evaluated (rc: initial=$rc_p0 lines='$p_lines' line1=$rc_p1 rerun=$rc_p2 line2=$rc_p3 final=$rc_p4): $out_p1 / $out_p2 / $out_p4"
fi

# (j.12) THE FIRST LINE MOVES A PASS-ONLY SERIES. An older PASS-only unmatchable series
# and a newer FAIL one. Moving the PASS series alone leaves s308's archive holding no
# FAIL, while the FAIL series stays the live pass: the re-run must still refuse.
UM_PASS_OLD="planning-20260908T000000Z"
seed pass-first
out_q0="$(rotate --sprint s308 --apply 2>&1)"; rc_q0=$?
out_q1="$(rotate --sprint s308 --series "$UM_PASS_OLD" --apply 2>&1)"; rc_q1=$?
out_q2="$(rotate --sprint s308 --apply 2>&1)"; rc_q2=$?
if [ "$rc_q0" -eq 1 ] && [ "$rc_q1" -eq 0 ] && [ -f "$DEST_S308/${UM_PASS_OLD}.verdict.json" ] \
   && [ "$rc_q2" -eq 1 ] && grep -q "^    .*/${UM_FAIL}\.verdict\.json$" <<<"$(refusal_block "$out_q2")"; then
  ok "(j.12) moving only an older PASS-only series fills s308's archive with no FAIL, and the re-run still refuses on the live FAIL"
else
  bad "(j.12) the re-run after a PASS-only first line did not refuse (close=$rc_q0 line=$rc_q1 rerun=$rc_q2): $out_q2"
fi

# (j.13) THE REMEDY STEPS CONVERGE. A FAILing legacy verdict below a FAIL-carrying
# unmatchable series. The close refuses and prints --series; that step refuses and prints
# --legacy-through, because it would promote the legacy FAIL; --legacy-through leaves the
# unmatchable FAIL live but promotes nothing, so it applies; then --series, then the close.
# Every command is the one the previous refusal PRINTED, with only s<N> substituted.
seed legacy-then-series
out_d0="$(rotate --sprint s308 --apply 2>&1)"; rc_d0=$?
d_ser="$(grep -E "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '[^']+'$" <<<"$out_d0" | sed -n "s/.*--series '\\([^']*\\)'\$/\\1/p" | head -1)"
out_d1="$(rotate --sprint s308 --series "$d_ser" --apply 2>&1)"; rc_d1=$?
d_bound="$(sed -n 's/.*--legacy-through \([0-9TZ]*\) --apply$/\1/p' <<<"$out_d1" | head -1)"
out_d2="$(rotate --legacy-through "$d_bound" --apply 2>&1)"; rc_d2=$?
out_d3="$(rotate --sprint s308 --series "$d_ser" --apply 2>&1)"; rc_d3=$?
out_d4="$(rotate --sprint s308 --apply 2>&1)"; rc_d4=$?
if [ "$rc_d0" -eq 1 ] && [ "$d_ser" = "$UM_FAIL" ] && [ "$rc_d1" -eq 1 ] && [ "$d_bound" = "20260701T000000Z" ] \
   && [ "$rc_d2" -eq 0 ] && [ ! -e "$GA/legacy-20260701T000000Z.verdict.json" ] \
   && [ "$rc_d3" -eq 0 ] && [ -f "$DEST_S308/${UM_FAIL}.verdict.json" ] \
   && [ "$rc_d4" -eq 0 ] && grep -q 'nothing to move' <<<"$out_d4"; then
  ok "(j.13) legacy FAIL below an unmatchable FAIL: close, --series, the printed --legacy-through, --series, close converge (1 1 0 0 0)"
else
  bad "(j.13) the printed remedies did not converge (close=$rc_d0 series='$d_ser' $rc_d1 bound='$d_bound' legacy=$rc_d2 series=$rc_d3 close=$rc_d4): $out_d1 / $out_d2"
fi

# (j.14) A SAME-SECOND TIE IS A PROMOTION. A legacy FAIL and an unmatchable PASS share one
# nonce; the PASS sorts first in the glob and is live. Moving it by --series hands the live
# pass to the legacy FAIL, so the step refuses and writes nothing.
seed tie
BEFORE_T="$(treehash "$PROJ")"
out_t="$(rotate --sprint s308 --series aplanning-20260909T120000Z --apply 2>&1)"; rc_t=$?
AFTER_T="$(treehash "$PROJ")"
if [ "$rc_t" -eq 1 ] && grep -q 'would strand' <<<"$out_t" && grep -q 'legacy-20260909T120000Z -- ' <<<"$out_t" \
   && [ "$BEFORE_T" = "$AFTER_T" ]; then
  ok "(j.14) a --series move of a verdict tying a legacy FAIL's nonce counts as promotion and refuses (exit 1), tree byte-identical"
else
  bad "(j.14) a same-nonce tie was not treated as promotion (rc=$rc_t): $out_t"
fi

# (j.15) --legacy-through REFUSES WHEN IT PROMOTES A FAIL. A legacy PASS is the live pass
# above an older FAIL-carrying unmatchable series; moving the PASS would make that FAIL live.
seed legacy-promote
BEFORE_LP="$(treehash "$PROJ")"
out_lp="$(rotate --legacy-through 20260920T000000Z --apply 2>&1)"; rc_lp=$?
AFTER_LP="$(treehash "$PROJ")"
if [ "$rc_lp" -eq 1 ] && grep -q 'would strand' <<<"$out_lp" && grep -q "${UM_FAIL} -- " <<<"$out_lp" \
   && [ "$BEFORE_LP" = "$AFTER_LP" ] && [ -f "$GA/legacy-20260920T000000Z.verdict.json" ]; then
  ok "(j.15) --legacy-through that would promote an unmatchable FAIL to live refuses (exit 1), tree byte-identical"
else
  bad "(j.15) a promoting --legacy-through was not refused (rc=$rc_lp): $out_lp"
fi

# (j.6) The printed command is spelled for the layout the rotator runs from. Two
# copies of it, one per layout, against the same world.
seed unmatchable
mkdir -p "$W/lay-c/scripts/ai-dlc" "$W/lay-d/core/scripts"
cp "$ROT" "$W/lay-c/scripts/ai-dlc/rotate-gate-adjudication.sh"
cp "$ROT" "$W/lay-d/core/scripts/rotate-gate-adjudication.sh"
out_c="$( ( cd "$PROJ" && bash "$W/lay-c/scripts/ai-dlc/rotate-gate-adjudication.sh" --sprint s308 ) 2>&1 )"
out_d="$( ( cd "$PROJ" && bash "$W/lay-d/core/scripts/rotate-gate-adjudication.sh" --sprint s308 ) 2>&1 )"
if grep -qE "^ +bash scripts/ai-dlc/rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_FAIL}'$" <<<"$out_c" \
   && grep -qE "^ +bash core/scripts/rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_FAIL}'$" <<<"$out_d"; then
  ok "(j.6) the remedy line reads 'bash scripts/ai-dlc/...' from an installed layout and 'bash core/scripts/...' from the distribution"
else
  bad "(j.6) the remedy line is not spelled for its layout: $out_c / $out_d"
fi

# (j.7) REFUSAL: a destination file already exists. Nothing is overwritten and the
# source stays live.
seed unmatchable
D_CL="$PROJ/_bmad-output/implementation-artifacts/s308/gate-adjudication"
mkdir -p "$D_CL"
printf '{"collide":true}\n' > "$D_CL/${UM_FAIL}.verdict.json"
BEFORE_CL="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --series "$UM_FAIL" --apply 2>&1)"; rc=$?
AFTER_CL="$(treehash "$PROJ")"
if [ "$rc" -eq 1 ] && [ "$BEFORE_CL" = "$AFTER_CL" ] && grep -q 'already exist' <<<"$out" \
   && grep -q '"collide":true' "$D_CL/${UM_FAIL}.verdict.json" && [ -f "$GA/${UM_FAIL}.verdict.json" ]; then
  ok "(j.7) REFUSAL: an existing destination file is not overwritten (exit 1), tree byte-identical"
else
  bad "(j.7) an existing destination file was overwritten or not refused (rc=$rc): $out"
fi

# (j.8) --series '' is a usage error.
out="$(rotate --sprint s308 --series '' 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && grep -q 'non-empty' <<<"$out"; then
  ok "(j.8) --series '' is a usage error (exit 2)"
else
  bad "(j.8) --series '' was not a usage error (rc=$rc): $out"
fi

# =============================================================================
# ARM (k) — tagged verdicts only, none for this sprint: still "nothing to move".
# The near-miss twin of (j): series ids present, every one matchable.
# =============================================================================
seed tagged-nomatch
BEFORE_K="$(treehash "$PROJ")"
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
AFTER_K="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_K" = "$AFTER_K" ] && grep -q 'nothing to move' <<<"$out" \
   && ! grep -q 'REFUSED\|WARN' <<<"$out"; then
  ok "(k) tagged verdicts only, none for s308: exit 0, 'nothing to move', no refusal and no WARN"
else
  bad "(k) a tagged-only directory with no match was not a clean no-op (rc=$rc): $out"
fi

# =============================================================================
# ARM (l) — the --series escape moves EXACTLY that id: a dry run writes nothing,
# and --apply leaves the id that merely STARTS WITH it in place.
# =============================================================================
seed series-move
BEFORE_L="$(treehash "$PROJ")"
out="$(rotate --sprint s309 --series "$UM_STEM" 2>&1)"; rc=$?
AFTER_L="$(treehash "$PROJ")"
if [ "$rc" -eq 0 ] && [ "$BEFORE_L" = "$AFTER_L" ] && [ ! -d "$DEST_S309" ] \
   && grep -q '1 verdict(s) and 1 sidecar(s) would move' <<<"$out"; then
  ok "(l.1) --series dry run: reports 1 verdict + 1 sidecar, tree byte-identical, no destination"
else
  bad "(l.1) the --series dry run wrote or misreported (rc=$rc): $out"
fi
out="$(rotate --sprint s309 --series "$UM_STEM" --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$DEST_S309/${UM_STEM}.verdict.json" ] && [ -f "$DEST_S309/${UM_STEM}.repair.md" ] \
   && [ -f "$GA/planning-20260911T000000Z.verdict.json" ] && [ ! -e "$DEST_S309/planning-20260911T000000Z.verdict.json" ] \
   && [ -f "$GA/implementation-20260720T011606Z.verdict.json" ]; then
  ok "(l.2) --series --apply moves the exact id with its sidecar and leaves '${UM_STEM}-retry' and the legacy verdict live"
else
  bad "(l.2) --series --apply did not move exactly one id (rc=$rc): $out"
fi
# A tokenised id is refused: --sprint already selects it, and moving it by hand
# could file it under the wrong sprint.
seed base
out="$(rotate --sprint s310 --series planning-s309-20260907T160702Z 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && grep -q 'already selects it' <<<"$out" && [ -f "$GA/planning-20260907T160702Z.verdict.json" ]; then
  ok "(l.3) --series refuses an id carrying a -s<N>- token (exit 2), nothing moved"
else
  bad "(l.3) --series accepted a tokenised id (rc=$rc): $out"
fi

# =============================================================================
# ARM (m) — mixed: a NON-empty s308 selection plus an unmatchable verdict. The
# s308 set moves, the unmatchable one stays live, a WARN names it, exit 0.
# =============================================================================
seed mixed
out="$(rotate --sprint s308 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$DEST_S308/sprint-review-20260907T002257Z.verdict.json" ] \
   && [ -f "$GA/${UM_STEM}.verdict.json" ] \
   && grep -q '^rotate-gate-adjudication: WARN -- 1 verdict(s)' <<<"$out" \
   && grep -q "^    .*/${UM_STEM}\.verdict\.json$" <<<"$out" \
   && grep -qE "^ +bash [^ ]*rotate-gate-adjudication\.sh --sprint s<N> --series '${UM_STEM}'$" <<<"$out"; then
  ok "(m) mixed: the s308 set moved, the unmatchable verdict stayed live, a WARN named it with its escape, exit 0"
else
  bad "(m) a mixed selection did not move-and-WARN (rc=$rc): $out"
fi

# =============================================================================
# ARMS (w.1)/(w.2) — FAIL_WAIVED counts as a FAIL at both selects. The rotator has no
# transcript corpus, so it cannot verify a waiver, and the guard reads an unverifiable
# FAIL_WAIVED as FAIL. Only the LOCKED direction is constructible here: there is no input
# through which this script could verify a waiver and unlock it. Each world is the FAIL twin
# with the failing check rewritten to FAIL_WAIVED, so it must refuse exactly as that twin does.
# =============================================================================
wv_p1() { # <rotator> -- the survivor select
  seed strand-unselectable-waived
  local b a o r; b="$(treehash "$PROJ")"; o="$( ( cd "$PROJ" && bash "$1" --sprint s308 --apply ) 2>&1 )"; r=$?; a="$(treehash "$PROJ")"
  [ "$r" -eq 1 ] && [ "$b" = "$a" ] && grep -q 'no mode can move' <<<"$o"; }
wv_p2() { # <rotator> -- the unmatchable-series select
  seed unmatchable-waived
  local o r; o="$( ( cd "$PROJ" && bash "$1" --sprint s308 --apply ) 2>&1 )"; r=$?
  [ "$r" -eq 1 ] && grep -q "^    .*/${UM_FAIL}\.verdict\.json$" <<<"$(refusal_block "$o")"; }
if wv_p1 "$ROT"; then ok "(w.1) a FAIL_WAIVED unselectable survivor is refused like its FAIL twin, tree byte-identical"
else bad "(w.1) a FAIL_WAIVED survivor was rotated past as if clean — an unverifiable waiver left live as the guard's pass"; fi
if wv_p2 "$ROT"; then ok "(w.2) a FAIL_WAIVED unmatchable series refuses the empty selection like its FAIL twin"
else bad "(w.2) a FAIL_WAIVED unmatchable series read as PASS-only and the close exited past it"; fi

echo
report_end gate-adjudication-rotate
