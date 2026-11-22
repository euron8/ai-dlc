#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# layer-readopt-gate — assert the v0.52.0 landing machinery can actually LAND.
#
# Three properties, each of which fails RED against a real defect that shipped:
#
#   A. `readopt-override.sh --check` catches an override whose body still carries
#      core text upstream has SUPERSEDED. Un-caught, the core fix lands on disk and
#      the lead goes on obeying the old rule out of the override.
#   B. A bare re-stamp is REFUSED while the body is stale. Drift is computed
#      base_sha..theirs, so re-stamping ALONE makes the HARD status evaporate with
#      nothing migrated -- "proceed by doing nothing" wearing a stamp. This is the
#      single most important assertion in the file.
#   C. `unregistered-drift.sh` tells an in-place core rewrite apart from install.sh's
#      template substitution. Getting that wrong in EITHER direction is fatal: miss
#      the rewrite and `apply` silently deletes it; flag the substitution and the
#      check fires on 13 of 13 files on first contact and gets turned off. (It did,
#      in development -- a `$(...)` capture ate the trailing newline and every file
#      read as drift.)
#
# Usage: run.sh [readopt-override.sh] [unregistered-drift.sh]
# Exit:  0 = every assertion holds, 1 = a gate regressed.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook.
#
# A fixture that INHERITS ambient config tests the config, not the code. The hooks honour
# thirteen AI_DLC_* tunables; a consumer that sets any of them in settings.json exports it
# into every session, `git push` inherits it, and the pre-push gate then runs this fixture
# against a hook configured differently from what the assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M (the documented, sanctioned way to
# declare the model row). Its effective window became 300000 instead of 200000, every
# threshold shifted, and SEVEN assertions failed against a sensor that was behaving exactly
# as specified. The gate blocked every push on the repo. The distribution never caught it
# because the distribution sets none of these -- the check could not fire where it was
# authored.
#
# Unset ALL of them, by pattern, so a NEW tunable cannot reintroduce this. Per-command
# assignments (`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work: those are the deliberate tests.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done


# SHARDS. THIS FILE IS FIVE SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY. Every section below is a UNIT guarded by `if sg <unit>; then ... fi`; `--group <x>` runs the units
# dealt to shard <x>. `layer-readopt-gate-{b,c,d,e}/run.sh` are one-line drivers that `exec bash` this file with their
# group, so the pre-push pool starts each on its own. No `--group` runs shard 'a'. The seed and the helpers above
# the first unit are not units: every shard pays them. The coverage join below runs in EVERY shard: the declared
# units are DERIVED from this file's own `if sg <unit>; then` lines, the dealt lists must be disjoint and their
# union exact, and every declared shard needs a driver; it proves it can fire first on a seeded duplicate and omission.
#   a  main f   arms A-E (the re-adoption gate, dossier, merge, register-drift), F (absorbed delta)
#   b  e2       E2: register-drift refusals and the world battery
#   c  c3       C3: layer-drift delegation, survival, loose and double-shadow arms
#   d  gh j     G and H (additive / wrap-insensitive) and J (re-flowed paragraph)
#   e  sup stub OVERRIDE-SUPERSEDED: the supersession and surplus arms; OVERRIDE-SHADOWS-POINTER-STUB (LC-O17)
SHARDS="a b c d e"
UNITS_a="main f"
UNITS_b="e2"
UNITS_c="c3"
UNITS_d="gh j"
UNITS_e="sup stub"
GROUP=a; GROUP_SET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --group) GROUP="${2:-}"; GROUP_SET=1; [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }; shift 2 ;;
    *) break ;;
  esac
done
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
NAME="layer-readopt-gate"; [ "$GROUP" = a ] || NAME="layer-readopt-gate-$GROUP"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
READOPT="$(pick "${1:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/readopt-override.sh")"
UNREG="$(pick "${2:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh")"

[ -n "$READOPT" ] || { echo "FIXTURE ERROR: cannot locate readopt-override.sh" >&2; exit 2; }
[ -n "$UNREG" ]   || { echo "FIXTURE ERROR: cannot locate unregistered-drift.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED $(cd "$(dirname "$READOPT")" && pwd -P)/$(basename "$READOPT")"
echo "HERMETIC-CONSUMED $(cd "$(dirname "$UNREG")" && pwd -P)/$(basename "$UNREG")"

# THE COVERAGE JOIN, in every shard before anything is built.
lr_broken() { echo "  FAIL  $1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
[ -n "$MINE" ] || lr_broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
lr_partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/lrgate-join.XXXXXX")" || lr_broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if lr_partition_ok "$JW/pd" "$JW/pdup" >/dev/null || lr_partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! lr_partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  rm -rf "$JW"; lr_broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$0" > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  rm -rf "$JW"; lr_broken "$ndecl unit guards derived from $0 ($ndupdecl declared twice)"
fi
if ! _why="$(lr_partition_ok "$JW/declared" "$JW/dealt")"; then
  rm -rf "$JW"; lr_broken "the shard partition does not cover the guarded units exactly -- $_why"
fi
# THE DIST-ONLY SHARDS: DIST_SHARDS reach no consumer. Each carries a non-empty .dist-only and no other shard does,
# and a consumer holds none of their directories, so only a DIST_SHARDS shard, whose inputs.decl declares its
# dist-only siblings, checks their drivers and markers; a shipped shard declares none and skips them.
DIST_SHARDS="b d e"
case " $DIST_SHARDS " in *" $GROUP "*) _me=dist ;; *) _me=ship ;; esac
[ ! -e "$HERE/.dist-only" ] || { rm -rf "$JW"; lr_broken "shard 'a' carries $HERE/.dist-only, but shard a ships"; }
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  case " $DIST_SHARDS " in *" $_s "*) _do=1 ;; *) _do=0 ;; esac
  [ "$_do" = 1 ] && [ "$_me" = ship ] && continue
  _drv="$HERE/../layer-readopt-gate-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    rm -rf "$JW"; lr_broken "shard '$_s' is declared but $_drv does not drive it"
  fi
  if [ "$_do" = 1 ] && [ ! -s "${_drv%/run.sh}/.dist-only" ]; then
    rm -rf "$JW"; lr_broken "shard '$_s' is in DIST_SHARDS but ${_drv%/run.sh}/.dist-only is absent or empty"
  fi
  if [ "$_do" = 0 ] && [ -e "${_drv%/run.sh}/.dist-only" ]; then
    rm -rf "$JW"; lr_broken "shard '$_s' carries ${_drv%/run.sh}/.dist-only but is not in DIST_SHARDS"
  fi
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"

ROOT="$(bash "$HERE/seed.sh")"
# layer-drift.sh is resolved here as well: units C3 and SUP (two shards) drive it.
DRIFT="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
# register-drift.sh is resolved here, not inside unit E: unit E2 (another shard) drives it too.
REG="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../core/skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/register-drift.sh")"
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
OVR="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# IN PROCESS (BL-878), shard a's units (main, f). Every drive of readopt-override.sh, unregistered-drift.sh and
# register-drift.sh there calls the subject's entry function (rov_main, ud_main, rd_main) through lib/inproc.sh's
# inproc_run, in a subshell made to look like a fresh `bash <subject>`. No inproc_load: three subjects, so each pass
# sources the path it runs and fx_inproc logs it under that path (the three `inproc:` rows). The command-line starts
# left are the `cli` cells of cells.decl, one per distinct CLI outcome, each compared byte for byte with the in-process
# call. The other shards' units (e2, c3, gh, j, sup) still start the subjects as programs: those shards' declarations
# carry no subject row, and none of them is a row of scripts/fixture-inprocess-allowlist.txt.
#
# THE BLOB MEMO. A CLI run sources lib.sh at the top of its own process and builds a private memo for that run; in a
# subshell lib.sh does not (it keys on `$BASH_SUBSHELL` 0). So `lrg_ip` hands each run a FRESH memo, as private to
# that run as the CLI's, unless the caller exported one.
#
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped subjects,
# and sourcing a pre-wrap subject would run its whole body on inproc_run's arguments. So each subject's shape is
# checked first, on its two halves: a subject with neither the `<p>_main() {` line nor the column-0 source guard
# predates the wrap, which prints SKIP and exits 0 -- never an ok. Exactly one half is a respelled subject this
# fixture can no longer drive, which FAILS; a subject the gate cannot read is FIXTURE ERROR.
if sg main || sg f; then
  [ -f "$HERE/../lib/layout.sh" ] || { echo "FIXTURE ERROR: lib/layout.sh not found beside $HERE" >&2; exit 2; }
  . "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: sourcing lib/layout.sh failed" >&2; exit 2; }
  [ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
  . "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
  [ -f "$HERE/../lib/inproc.sh" ] || { echo "FIXTURE ERROR: lib/inproc.sh not found beside $HERE" >&2; exit 2; }
  . "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: sourcing lib/inproc.sh failed" >&2; exit 2; }
  lrg_gate() { # <subject> <entry> -> returns on a wrapped subject; SKIP, FAIL or FIXTURE ERROR otherwise
    local _s="$1" _e="$2" _def=0 _grd=0 _gx
    grep -q "^$_e() {\$" "$_s"; _gx=$?
    [ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $_s (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
    [ "$_gx" -ne 0 ] || _def=1
    grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$_s"; _gx=$?
    [ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $_s (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
    [ "$_gx" -ne 0 ] || _grd=1
    if [ "$_def$_grd" = 00 ]; then echo "SKIP: subject $_s predates the in-process wrap"; fx_skip_exit "$HERE"; fi
    if [ "$_def" = 0 ]; then echo "   FAIL  $_s carries the column-0 source guard but no \`$_e() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "$NAME: FAIL (1)" >&2; exit 1; fi
    if [ "$_grd" = 0 ]; then echo "   FAIL  $_s defines \`$_e() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $_e on inproc_run's arguments" >&2; echo "$NAME: FAIL (1)" >&2; exit 1; fi
    return 0
  }
  lrg_gate "$READOPT" rov_main
  lrg_gate "$UNREG" ud_main
  [ -z "$REG" ] || lrg_gate "$REG" rd_main
fi
lrg_ip() { # <subject> <entry> [args...] -> what `bash <subject> [args...]` prints and exits with, in process
  local _m _rc
  case "$(declare -p AI_DLC_RECONCILE_MEMO 2>/dev/null)" in
    "declare -x"*) inproc_run "$@"; return ;;
  esac
  _m="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX")" || return 125
  AI_DLC_RECONCILE_MEMO="$_m" inproc_run "$@"; _rc=$?
  rm -rf "$_m"
  return "$_rc"
}
ro() { lrg_ip "$READOPT" rov_main "$@"; }
ud() { lrg_ip "$UNREG" ud_main "$@"; }
rd() { lrg_ip "$REG" rd_main "$@"; }
# THE cli CELLS (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome, on the same input as one
# in-process call; stdout, stderr and exit are compared separately, byte for byte. Each caller also asserts the
# outcome itself, so two runs that both printed nothing cannot read as equivalent. Only non-writing calls are cells.
LRG_EQ="$(mktemp -d "${TMPDIR:-/tmp}/lrgate-eq.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$LRG_EQ"' EXIT
lrg_eqv() { # <cell-id> <subject> <entry> <subject args...> -> 0 when program and in-process call agree; files in $LRG_EQ/<id>.*
  local _id="$1" _s="$2" _e="$3"; shift 3
  lrg_ip "$_s" "$_e" "$@" > "$LRG_EQ/$_id.ip.out" 2> "$LRG_EQ/$_id.ip.err"; echo "$?" > "$LRG_EQ/$_id.ip.rc"
  FXCELL="$_id" bash "$_s" "$@" > "$LRG_EQ/$_id.cl.out" 2> "$LRG_EQ/$_id.cl.err"; echo "$?" > "$LRG_EQ/$_id.cl.rc"
  cmp -s "$LRG_EQ/$_id.ip.out" "$LRG_EQ/$_id.cl.out" && cmp -s "$LRG_EQ/$_id.ip.err" "$LRG_EQ/$_id.cl.err" \
    && cmp -s "$LRG_EQ/$_id.ip.rc" "$LRG_EQ/$_id.cl.rc"
}
lrg_twin() { printf 'in-process rc=%s out=%s err=[%s] / program rc=%s out=%s err=[%s]' "$(cat "$LRG_EQ/$1.ip.rc")" \
  "$(grep -c . "$LRG_EQ/$1.ip.out")" "$(head -1 "$LRG_EQ/$1.ip.err")" "$(cat "$LRG_EQ/$1.cl.rc")" \
  "$(grep -c . "$LRG_EQ/$1.cl.out")" "$(head -1 "$LRG_EQ/$1.cl.err")"; }
lrg_cell() { # <cell-id> <want rc> <want text on stdout+stderr> <label> -> ok/bad on the pair lrg_eqv just wrote
  local _t
  _t="$(cat "$LRG_EQ/$1.cl.out" "$LRG_EQ/$1.cl.err")"
  if cmp -s "$LRG_EQ/$1.ip.out" "$LRG_EQ/$1.cl.out" && cmp -s "$LRG_EQ/$1.ip.err" "$LRG_EQ/$1.cl.err" \
     && cmp -s "$LRG_EQ/$1.ip.rc" "$LRG_EQ/$1.cl.rc" && [ "$(cat "$LRG_EQ/$1.cl.rc")" = "$2" ] && grep -q -- "$3" <<<"$_t"; then
    ok "$1: $4 -- the program and the in-process call agree (stdout, stderr, exit $2)"
  else
    bad "$1: the program and the in-process call differ, or the outcome is not exit $2 carrying '$3' ($(lrg_twin "$1"))"
  fi
}

if sg main; then
echo "== A. the stale-core-text gate fires on the real shape =="

out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--check RED: override body carries core text theirs no longer has"
else
  bad "--check did NOT fire on an override copying a superseded core clause (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi

# The gate must name the actual superseded sentence, not merely exit 1.
if grep -q 'more CRITICALs than pass N' <<<"$out"; then
  ok "--check names the superseded clause verbatim"
else
  bad "--check fired but did not identify the stale line"
fi
lrg_eqv cli-ro-stale "$READOPT" rov_main "$DIST" "$THEIRS" "$CONS" "$OVR" --check
lrg_cell cli-ro-stale 1 'STALE-CORE-TEXT' "--check on a stale body"

echo "== B. a bare re-stamp is REFUSED while the body is stale =="

before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"

if [ "$rc" -ne 0 ] && grep -q 'REFUSED' <<<"$out"; then
  ok "--stamp readopt REFUSED while superseded text remains"
else
  bad "--stamp readopt SUCCEEDED on a stale body -- the block can be cleared by doing nothing (rc=$rc)"
fi
if [ "$before_sha" = "$after_sha" ]; then
  ok "base_sha untouched by the refused stamp ($before_sha)"
else
  bad "REFUSED stamp still rewrote base_sha ($before_sha -> $after_sha)"
fi

echo "== B2. reaffirm without a note is REFUSED =="
out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp reaffirm 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'REQUIRES --note' <<<"$out"; then
  ok "--stamp reaffirm demands a recorded reason"
else
  bad "--stamp reaffirm accepted with no note -- an unrecorded decision (rc=$rc)"
fi

echo "== C. the gate GOES GREEN once the body is genuinely re-adopted =="

# Re-adopt: carry theirs' clause into the override, keep the consumer's delta.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs IN THE SCOPE THE PRIOR PASS ALSO REVIEWED
(\`findings_critical_prior_scope\`) than pass N reported in total, the repair step
is injecting defects. CRITICALs in scope the sprint ADDED are NOT divergence.
EOF

out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--check green after a real re-adoption"
else bad "--check still red after the body was re-adopted (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/        /'; fi
lrg_eqv cli-ro-green "$READOPT" rov_main "$DIST" "$THEIRS" "$CONS" "$OVR" --check
lrg_cell cli-ro-green 0 'body carries no superseded core text' "--check on a re-adopted body"

out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
new_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
if [ "$rc" -eq 0 ] && [ "$new_sha" = "$THEIRS" ]; then
  ok "--stamp readopt re-stamped base_sha $BASE -> $THEIRS"
else
  bad "--stamp readopt did not re-stamp (rc=$rc, base_sha=$new_sha, want $THEIRS)"
fi

# And the consumer's own delta must have SURVIVED the re-adoption.
if grep -q 'validation-intensity\|Validation intensity' "$OVR"; then
  ok "the consumer's delta survived re-adoption"
else
  bad "re-adoption destroyed the consumer's delta"
fi

echo "== B3. reaffirm must not CORRUPT a multi-line reason: block =="

# A `reason:` is routinely a multi-line YAML block — six of the reference consumer's
# overrides have one, the longest running 99 lines. Appending the note to the `reason:`
# LINE splices it into the middle of a sentence. That shipped, and it corrupted a live
# override. The reason is what the NEXT pull reads to decide "does upstream supersede
# this?"; corrupting it corrupts the record the whole workflow turns on.
ML="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Multiline.md"
cat > "$ML" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: The core paragraph claims a thing that is
  not true in this consumer, and the second line
  finishes the sentence.
---
Body.
EOF
ro "$DIST" "$THEIRS" "$CONS" "$ML" --stamp reaffirm --note "still stands" >/dev/null 2>&1

if grep -q 'reason: The core paragraph claims a thing that is$' "$ML"; then
  ok "the reason's first line is INTACT (note not spliced mid-sentence)"
else
  bad "reaffirm mangled the multi-line reason — spliced the note into line 1"
  grep -n '^reason:' "$ML" | sed 's/^/        /'
fi
if grep -q 'finishes the sentence.$' "$ML"; then
  ok "the reason's continuation lines survived"
else
  bad "reaffirm destroyed the reason's continuation lines"
fi
if [ "$(grep -c 'RE-AFFIRMED against' "$ML")" = "1" ] && \
   tail -n +2 "$ML" | awk '/^---$/{exit} {last=$0} END{exit !(last ~ /RE-AFFIRMED/)}'; then
  ok "the note is appended at the END of the reason block"
else
  bad "the note is not at the end of the reason block"
fi
rm -f "$ML"

echo "== B4. the dossier must RENDER a block-scalar reason, not its indicator =="

# The twin of B3, in the other direction. B3 proved the WRITER tracks a block scalar; the
# READER did not. `fm()` is `… | head -1`, so on `reason: |` it captured the indicator and
# nothing else and the dossier's rationale panel printed a bare `|`. Eight of the reference
# consumer's sixteen overrides declare `reason:` as a block; every one rendered empty.
#
# SKILL.md step 7's retire / readopt / reaffirm decision turns on that field, so the operator
# adjudicated a re-adoption against a blank rationale — and a blank rationale reads as an
# override with no stated purpose, which is an argument for retiring it.
BL="$CONS/.claude/skills/ai-dlc/overrides/SKILL__BlockReason.md"
cat > "$BL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: |
  UNIQUE-BLOCK-SENTINEL the first line of the block.
  And a continuation line that must also survive.
---
Body.
EOF
out="$(ro "$DIST" "$THEIRS" "$CONS" "$BL" 2>&1)"
if grep -q 'UNIQUE-BLOCK-SENTINEL' <<<"$out"; then
  ok "the dossier renders a block-scalar reason's text"
else
  bad "the dossier did NOT render the block-scalar reason — step 7's readopt decision turns on a field the operator cannot see"
  printf '%s\n' "$out" | sed -n '/WHY THIS OVERRIDE EXISTS/,+3p' | sed 's/^/        /'
fi
if grep -q 'continuation line that must also survive' <<<"$out"; then
  ok "the block's continuation lines render too (not just line 1)"
else
  bad "the dossier rendered only the block's first line — a 99-line reason still reads as a one-liner"
fi
# Non-vacuity in the other direction: the INLINE form must not regress.
cat > "$BL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: UNIQUE-INLINE-SENTINEL a single-line reason.
---
Body.
EOF
out="$(ro "$DIST" "$THEIRS" "$CONS" "$BL" 2>&1)"
if grep -q 'UNIQUE-INLINE-SENTINEL' <<<"$out"; then
  ok "an INLINE reason still renders (the block reader did not break the common path)"
else
  bad "the inline reason stopped rendering — fixing the block form broke the single-line form"
  printf '%s\n' "$out" | head -12 | sed 's/^/        /'
fi
rm -f "$BL"

echo "== B4b. a MULTI-LINE PLAIN reason renders whole, and it fails WORSE than the block form =="

# THE SAME DEFECT ONE YAML SHAPE OVER, AND IN THE MORE DANGEROUS DIRECTION. B4 above cured
# `reason: |`; `reason: <text>` continued over the lines beneath it took `fm_block()`'s
# `print v; exit` arm and rendered its FIRST LINE ONLY. A bare `|` rendered EMPTY, which the
# operator reads as a missing field and goes to the file for. One surviving line that ends in a
# complete sentence reads as the WHOLE reason, so step 7's retire / readopt / reaffirm decision
# is taken against a fragment that looks whole and nothing in the output says otherwise.
#
# THREE SENTINELS, NOT TWO. A two-line seed cannot tell "reads the continuation" from "reads one
# more line"; the third is what makes the arm about the continuation STATE rather than about a
# lookahead. Each is unique in the file, so a hit is that line and not a substring of another.
PM="$CONS/.claude/skills/ai-dlc/overrides/SKILL__PlainMulti.md"
cat > "$PM" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: PLAIN-FIRST-SENTINEL the first line of a plain scalar,
  PLAIN-CONT-SENTINEL and the continuation that finishes it,
  PLAIN-TAIL-SENTINEL and a third line beneath that one.
---
Body.
EOF
pm_out="$(ro "$DIST" "$THEIRS" "$CONS" "$PM" 2>&1)"
if grep -q 'PLAIN-FIRST-SENTINEL' <<<"$pm_out"; then
  ok "a PLAIN multi-line reason renders its first line"
else
  bad "the dossier rendered nothing for a plain scalar reason at all — the common path is broken, and every verdict below is about an empty panel"
fi
if grep -q 'PLAIN-CONT-SENTINEL' <<<"$pm_out" && grep -q 'PLAIN-TAIL-SENTINEL' <<<"$pm_out"; then
  ok "  ...and BOTH continuation lines beneath it — a reason that runs past line 1 is not silently truncated to a fragment that reads whole"
else
  bad "the dossier rendered only line 1 of a PLAIN multi-line reason (cont=$(grep -c 'PLAIN-CONT-SENTINEL' <<<"$pm_out") tail=$(grep -c 'PLAIN-TAIL-SENTINEL' <<<"$pm_out"), want 1 and 1) — step 7's decision is taken against a fragment ending in a complete sentence, which is worse than the blank field B4 fixed"
fi

# THE CONTINUATION MUST STOP AT THE NEXT KEY, and that is the half a widened reader breaks.
# `inb` carries the block-END rule — an unindented `key:` closes it, which is the `--note`
# WRITER's own rule — and the plain arm reuses it precisely so reader and writer cannot disagree
# about where a reason stops. A reader that simply consumed to the fence would pass every
# assertion above and swallow `base_sha` into the rationale panel.
PK="$CONS/.claude/skills/ai-dlc/overrides/SKILL__PlainKeyStop.md"
cat > "$PK" <<EOF
---
shadows: SKILL.md#Rule 7
reason: PLAIN-STOP-SENTINEL line one of the reason,
  PLAIN-STOP-CONT-SENTINEL line two of the reason.
base_sha: ${BASE}
---
Body.
EOF
pk_panel="$(ro "$DIST" "$THEIRS" "$CONS" "$PK" 2>&1 \
            | awk '/WHY THIS OVERRIDE EXISTS/{p=1;next} /^--- WHAT UPSTREAM/{p=0} p')"
if grep -q 'PLAIN-STOP-CONT-SENTINEL' <<<"$pk_panel"; then
  ok "CONTROL: with a key BELOW it the reason's continuation line still renders (so the absence below is a real zero)"
else
  bad "CONTROL: the continuation did not render when a key follows the reason, so the stop assertion below is a statement about an empty panel"
fi
if grep -q 'base_sha' <<<"$pk_panel"; then
  bad "the rationale panel swallowed the `base_sha:` key that follows the reason — the plain arm is consuming to the fence instead of reusing the block-END rule, and the operator reads frontmatter as the override's stated purpose"
else
  ok "  ...and the reason STOPS at the next unindented key: base_sha does not leak into the panel"
fi
rm -f "$PK"

echo "== B4c. the reason panel's CLIP ANNOUNCES ITSELF =="

# IT WAS `head -20`: a reason longer than twenty folded lines lost its tail with nothing in the
# output saying so, and the operator adjudicated against a fragment indistinguishable from a
# complete field. The same dangerous direction as B4b — a plausible value is worse than an
# obviously missing one.
#
# RAISING THE LIMIT IS NOT THE FIX AND THE ARM IS BUILT SO THAT IT COULD NOT BE. The notice is a
# function of the INPUT (the awk END rule fires whenever the authored line count exceeds what was
# printed), so what is asserted is the RELATION — head shown, tail withheld, count stated — and
# no value of the bound satisfies it while clipping silently.
CLIP="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Clip.md"
{
  echo '---'
  echo 'shadows: SKILL.md#Rule 7'
  echo "base_sha: ${BASE}"
  echo 'reason: CLIP-HEAD-SENTINEL line 1 of a long plain scalar.'
  i=2
  while [ "$i" -le 30 ]; do echo "  continuation line ${i} of the long plain scalar."; i=$((i+1)); done
  echo '  CLIP-TAIL-SENTINEL the very last line, which must not be shown.'
  echo '---'
  echo 'Body.'
} > "$CLIP"
clip_out="$(ro "$DIST" "$THEIRS" "$CONS" "$CLIP" 2>&1)"
if grep -q 'CLIP-HEAD-SENTINEL' <<<"$clip_out" && ! grep -q 'CLIP-TAIL-SENTINEL' <<<"$clip_out"; then
  ok "a long reason is still clipped (head shown, tail withheld) — the panel is bounded, which is what makes the notice necessary"
else
  bad "the clip itself has moved (head=$(grep -c 'CLIP-HEAD-SENTINEL' <<<"$clip_out") tail=$(grep -c 'CLIP-TAIL-SENTINEL' <<<"$clip_out"), want 1 and 0) — if nothing is withheld the notice arm below asserts nothing, and if nothing is shown the panel is empty"
fi
clip_n="$(grep -oE '\[\.\.\. [0-9]+ further line' <<<"$clip_out" | grep -oE '[0-9]+' | head -1)"
if [ -n "$clip_n" ] && [ "$clip_n" -gt 0 ]; then
  ok "  ...and the clip ANNOUNCES itself with a COUNT ($clip_n further line(s)) — the operator is told the field is partial instead of reading a fragment as whole"
else
  bad "the reason panel clipped with NO notice and no count — this is the shipped defect: a truncated rationale is indistinguishable from a complete one, and the retire/readopt/reaffirm decision is taken on it"
fi
# THE NEAR-MISS, AND IT CARRIES THE PROPERTY THE FEARED REGRESSION KEYS ON. A notice printed
# unconditionally would satisfy both assertions above. This reason is long enough to be a real
# multi-line scalar and short enough to fit, so a notice here is a false one.
SHORT="$CONS/.claude/skills/ai-dlc/overrides/SKILL__ClipCtl.md"
cat > "$SHORT" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: SHORT-HEAD-SENTINEL line one of a short plain scalar,
  and line two, which fits inside the bound with room to spare.
---
Body.
EOF
short_out="$(ro "$DIST" "$THEIRS" "$CONS" "$SHORT" 2>&1)"
if grep -q 'SHORT-HEAD-SENTINEL' <<<"$short_out"; then
  ok "CONTROL: the short reason renders (so the notice's absence below is a real zero, not a dead run)"
else
  bad "CONTROL: the short reason did not render at all, so the absence below says nothing"
fi
if grep -q 'NOT SHOWN' <<<"$short_out"; then
  bad "a reason that FITS carried the clip notice anyway — the notice fires unconditionally, so it tells the operator nothing about whether this field is partial"
else
  ok "  ...and carries NO clip notice: the announcement is a function of the input, not a line printed on every dossier"
fi
lrg_eqv cli-ro-dossier "$READOPT" rov_main "$DIST" "$THEIRS" "$CONS" "$SHORT"
lrg_cell cli-ro-dossier 0 'SHORT-HEAD-SENTINEL' "the default dossier"
rm -f "$SHORT"

rm -f "$PM" "$CLIP"

echo "== B5. the dossier's upstream-change panel must SAY when nothing drifted =="

# The panel titled "WHAT UPSTREAM CHANGED IN THE SHADOWED SECTION" echoed its heading for
# EVERY anchor before computing that anchor's diff, so an entry whose sections are
# byte-identical rendered as a list of bare headings underneath a title asserting they
# CHANGED. Measured on the reference consumer, `overrides/steps__retro__domain-sections.md`,
# four anchors: four headings, ZERO diff hunks. The reader's inference is "four sections
# drifted", which points at --merge / --stamp readopt -- surgery on an entry needing none.
# It reached an operator's report before it was caught.
#
# SELF-MASKING, which is why it needs an arm rather than a doc note: the same rendering is
# CORRECT whenever at least one anchor did change, so nothing downstream disagrees and the
# panel is internally consistent in both cases.
#
# THE ARM IS PRESENCE-SHAPED IN BOTH DIRECTIONS, and that is deliberate. Asserting only
# "no bare heading appears" would pass against a subject that emits nothing at all.
# So the quiet direction DEMANDS the explicit sentence, and the loud direction DEMANDS a real
# diff hunk. Rule 7 is byte-identical BASE..THEIRS in this seed and Rule 8 is not, so the
# two directions are driven by two different anchors of the same seeded core file — a
# single anchor could not produce both.
PANEL="$CONS/.claude/skills/ai-dlc/overrides/SKILL__PanelQuiet.md"
panel_filter() { # stdin: a dossier -> just the upstream-change panel
  awk '/WHAT UPSTREAM CHANGED/{p=1} /SUPERSEDED CORE TEXT/{p=0} p'
}
panel_of() { # $1 override path -> just the upstream-change panel
  ro "$DIST" "$THEIRS" "$CONS" "$1" 2>&1 | panel_filter
}

# -- QUIET DIRECTION: an anchor that did NOT drift. NO RUN OF ITS OWN: the panel span, from WHAT UPSTREAM CHANGED to
# SUPERSEDED CORE TEXT, is a function of the shadow ids, BASE_SHA and THEIRS only (readopt-override.sh), and the Rule 7
# dossier above (short_out: shadows SKILL.md#Rule 7, the same base_sha) carries exactly that state, so its panel is
# this arm's panel (cmp-equal on the base tree). The loud direction below keeps its own run.
qp="$(panel_filter <<<"$short_out")"
if grep -qE '\(none -- all [0-9]+ compared anchor' <<<"$qp"; then
  ok "an unchanged anchor renders an explicit 'nothing drifted' sentence"
else
  bad "the panel did NOT state that nothing drifted — a reader cannot tell 'unchanged' from 'not compared'"
  printf '%s\n' "$qp" | sed 's/^/        /'
fi
if grep -qE '^[[:space:]]*## ' <<<"$qp"; then
  bad "an unchanged anchor still rendered a bare '## <id>' heading under a title asserting it CHANGED"
  printf '%s\n' "$qp" | sed 's/^/        /'
else
  ok "no bare anchor heading is printed for a section that did not drift"
fi

# -- LOUD DIRECTION, the non-vacuity control. Same panel, an anchor that DID drift.
cat > "$PANEL" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: shadows a section upstream DID rewrite in this range.
---
Body that restates nothing.
EOF
lp="$(panel_of "$PANEL")"
if grep -qE '^[[:space:]]*@@' <<<"$lp"; then
  ok "CONTROL: a genuinely drifted anchor still renders its diff hunk"
else
  bad "CONTROL: the drifted anchor rendered NO diff — the quiet arm above is passing because the panel went silent for everything"
  printf '%s\n' "$lp" | sed 's/^/        /'
fi
if grep -qE '^[[:space:]]*## Rule 8' <<<"$lp"; then
  ok "CONTROL: the drifted anchor's heading IS printed, above its diff"
else
  bad "CONTROL: a drifted anchor lost its heading — the fix suppressed headings unconditionally"
fi
rm -f "$PANEL"


echo "== C0. --merge re-adopts MECHANICALLY (no hand edit) =="

# The operator must never be told to "merge the new core text in, preserving your
# delta" by hand: that is asking them to run a three-way merge in their head, on prose,
# and a hand-merge is where half an upstream clause gets silently dropped. Re-seed the
# stale override and let --merge do it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.
EOF

out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --merge 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -q 'MERGED' <<<"$out"; then
  ok "--merge applied upstream's change with no hand edit"
else
  bad "--merge failed (rc=$rc): $out"
fi
if grep -q 'IN THE SCOPE THE PRIOR PASS ALSO REVIEWED' "$OVR"; then
  ok "upstream's new clause is IN the override body"
else
  bad "--merge did not bring upstream's clause into the body"
fi
if grep -q 'Validation intensity by path' "$OVR"; then
  ok "the consumer's delta survived the merge"
else
  bad "--merge destroyed the consumer's delta -- the whole reason the override exists"
fi
if grep -q 'more CRITICALs than pass N' "$OVR"; then
  bad "the superseded clause is STILL in the body after --merge"
else
  ok "the superseded clause is gone"
fi
# And the merged body must now pass the gate it previously failed.
ro "$DIST" "$THEIRS" "$CONS" "$OVR" --check >/dev/null 2>&1 \
  && ok "--check green after --merge (stamp is now permitted)" \
  || bad "--check still red after --merge -- the merge did not actually clear the block"

echo "== C0b. a MULTI-ANCHOR override merges per anchor, not by hand =="

# This used to be `REFUSED ... merge them one at a time by hand`, which routed the
# operator into the exact procedure C0 exists to abolish. It is also disproportionate:
# Rule 7 and Rule 9 are BYTE-IDENTICAL base..theirs, so three of the four anchors need
# no work at all -- only Rule 8 drifted. The differential is that the two unchanged
# sections must come out byte-for-byte, INCLUDING their consumer deltas: a merge that
# re-flows a section core never touched is indistinguishable, in a diff, from one that
# quietly rewrote it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 7, SKILL.md#Rule 8, SKILL.md#Rule 9
base_sha: ${BASE}
reason: consumer rewrites of three rule sections; only one of them drifted upstream.
---

Preamble prose no anchor covers. Must survive verbatim.

## Rule 7 -- Something Else

CONSUMER-DELTA-SEVEN kept exactly as written.

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.

## Rule 9 -- Trailing

CONSUMER-DELTA-NINE kept exactly as written.
EOF

out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --merge 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  ok "--merge accepted a multi-anchor override (was: REFUSED, exit 2)"
else
  bad "--merge still refuses a multi-anchor override (rc=$rc): $out"
fi
if grep -q '1 merged, 2 unchanged, 0 conflicted' <<<"$out"; then
  ok "only the anchor that drifted was merged (1 merged, 2 unchanged)"
else
  bad "expected '1 merged, 2 unchanged, 0 conflicted', got: $out"
fi
if grep -Fqx 'CONSUMER-DELTA-SEVEN kept exactly as written.' "$OVR" \
   && grep -Fqx 'CONSUMER-DELTA-NINE kept exactly as written.' "$OVR"; then
  ok "the two unchanged sections came out byte-for-byte"
else
  bad "an unchanged section was rewritten -- --merge must not touch what core did not change"
fi
if grep -Fqx 'Preamble prose no anchor covers. Must survive verbatim.' "$OVR"; then
  ok "prose outside every anchor span survived verbatim"
else
  bad "--merge dropped body prose no anchor covers"
fi
if grep -q 'IN THE SCOPE THE PRIOR PASS ALSO REVIEWED' "$OVR" \
   && grep -q 'Validation intensity by path' "$OVR" \
   && ! grep -q 'more CRITICALs than pass N' "$OVR"; then
  ok "the drifted anchor took upstream's clause, kept the delta, dropped the superseded line"
else
  bad "the drifted anchor did not merge correctly"
fi
ro "$DIST" "$THEIRS" "$CONS" "$OVR" --check >/dev/null 2>&1 \
  && ok "--check green after the multi-anchor merge" \
  || bad "--check still red after the multi-anchor merge"

echo "== C0c. --merge invents no whitespace the file did not have =="

# Found on the reference consumer, NOT here: its override has no blank line after the
# `---` fence, and --merge emitted one because the writer appended a separator
# unconditionally. A whitespace-only edit is still an edit to a file whose promise is that
# untouched sections come out byte-for-byte, and it lands in every reviewer's diff. The
# fixture's other overrides all happen to have that blank, so none of them could see it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 7, SKILL.md#Rule 8
base_sha: ${BASE}
reason: no blank line after the fence, and none may be added.
---
FLUSH-PREAMBLE immediately after the fence.

## Rule 7 -- Something Else

CONSUMER-DELTA-SEVEN kept exactly as written.

## Rule 8 -- Validation Depth

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.
EOF
before_line10="$(sed -n '6p' "$OVR")"
ro "$DIST" "$THEIRS" "$CONS" "$OVR" --merge >/dev/null 2>&1
if [ "$(sed -n '5p' "$OVR")" = '---' ] && [ "$(sed -n '6p' "$OVR")" = "$before_line10" ]; then
  ok "no blank line invented after the frontmatter fence"
else
  bad "--merge inserted whitespace after the fence: line 6 was '$before_line10', now '$(sed -n '6p' "$OVR")'"
fi
if [ -n "$(tail -c 1 "$OVR")" ] || [ "$(tail -n 1 "$OVR")" != "" ]; then
  ok "no trailing blank line appended at EOF"
else
  bad "--merge appended a trailing blank line at EOF"
fi

echo "== C1. a stamp cannot outrun an unresolved CONFLICT =="

printf '\n<<<<<<< override (yours)\nfoo\n=======\nbar\n>>>>>>> core\n' >> "$OVR"
out="$(ro "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'conflict markers' <<<"$out"; then
  ok "--stamp readopt REFUSED while conflict markers remain"
else
  bad "--stamp readopt shipped <<<<<<< into the rulebook the lead reads (rc=$rc)"
fi

echo "== C2. an UNRESOLVABLE anchor fails CLOSED (the vacuous-check hole) =="

# If `shadows:` names an anchor that resolves to no heading, the stale-text test
# compares two EMPTY sections, finds nothing, and reports the body clean. That is a
# check that cannot fail -- gating the very re-stamp it exists to withhold. It must
# refuse, not pass. (Found live: the anchor "Empirical gate validation (the
# `Enforcement:` paragraph)" resolves under layer-drift's matcher but not under a
# naive one, so the gate blocked and its remedy silently cleared the block.)
GHOST="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Ghost.md"
cat > "$GHOST" <<EOF
---
shadows: SKILL.md#Rule 404 -- Does Not Exist
base_sha: ${BASE}
reason: anchor names no heading in core.
---
Body that copies nothing and can be proven safe by nobody.
EOF

out="$(ro "$DIST" "$THEIRS" "$CONS" "$GHOST" --check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'UNDECIDABLE' <<<"$out"; then
  ok "--check on an unresolvable anchor: UNDECIDABLE, not 'clean'"
else
  bad "--check reported an unresolvable anchor as clean (rc=$rc) -- a check that cannot fail"
fi
lrg_eqv cli-ro-undecidable "$READOPT" rov_main "$DIST" "$THEIRS" "$CONS" "$GHOST" --check
lrg_cell cli-ro-undecidable 1 'UNDECIDABLE' "--check on an unresolvable anchor"

out="$(ro "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'REFUSED' <<<"$out"; then
  ok "--stamp readopt REFUSED on an unresolvable anchor"
else
  bad "--stamp readopt cleared a HARD block via a vacuous test (rc=$rc)"
fi

# reaffirm --note is the sanctioned way past it: a human puts their name on it.
out="$(ro "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp reaffirm --note "anchor is legacy; override still stands" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--stamp reaffirm --note is the recorded way past an undecidable anchor"
else bad "reaffirm --note could not clear an undecidable anchor (rc=$rc) -- no path out means the gate gets routed around"; fi

rm -f "$GHOST"

echo "== D. unregistered drift vs sanctioned template substitution =="

tsv="$(ud "$DIST" "$BASE" "$CONS" 2>&1)"

st() { printf '%s\n' "$tsv" | awk -F'\t' -v f="$1" '$2==f {print $1}'; }

if [ "$(st team-roles/tea.md)" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "in-place core rewrite (tea.md) -> HARD-UNREGISTERED-CORE-DRIFT"
else
  bad "in-place core rewrite NOT flagged (got '$(st team-roles/tea.md)') -- apply would silently delete it"
fi

if [ "$(st team-roles/dev.md)" = "CORE-TEMPLATE-SUBSTITUTED" ]; then
  ok "install.sh token substitution (dev.md) -> CORE-TEMPLATE-SUBSTITUTED, not drift"
else
  bad "template substitution misread as '$(st team-roles/dev.md)' -- this is the false positive that gets the check turned off"
fi

if [ "$(st skills/ai-dlc/SKILL.md)" = "CORE-OK" ]; then
  ok "untouched core file -> CORE-OK"
else
  bad "untouched core file reported '$(st skills/ai-dlc/SKILL.md)' -- trailing-newline regression is back"
fi
lrg_eqv cli-ud-rows "$UNREG" ud_main "$DIST" "$BASE" "$CONS"
lrg_cell cli-ud-rows 0 'HARD-UNREGISTERED-CORE-DRIFT' "the drift rows"

echo "== E. register-drift pulls an in-place edit INTO the layer system =="

# Detecting unregistered drift is half the job. Telling the operator to "refile the
# delta as an override with a base_sha" and leaving them to hand-author the YAML, pick
# the anchor, and copy the right section out is the other half, undone -- and a
# hand-picked anchor that resolves to no heading is how drift detection dies silently.
REG="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../core/skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/register-drift.sh")"
if [ -z "$REG" ]; then
  bad "cannot locate register-drift.sh"
else
  echo "HERMETIC-CONSUMED $(cd "$(dirname "$REG")" && pwd -P)/$(basename "$REG")"
  # The dry run writes nothing, so the program and the in-process call read the same tree.
  lrg_eqv cli-rd-dryrun "$REG" rd_main "$DIST" "$BASE" "$CONS" team-roles/tea.md
  lrg_cell cli-rd-dryrun 0 'Test Architect' "the dry run prints the override it would write"
  out="$(rd "$DIST" "$BASE" "$CONS" team-roles/tea.md --apply 2>&1)"; rc=$?
  NEW="$CONS/.claude/skills/ai-dlc/overrides/team-roles__tea__consumer-drift.md"

  if [ "$rc" -eq 0 ] && [ -f "$NEW" ]; then ok "authored the overrides/ entry"
  else bad "register-drift did not author an override (rc=$rc)"; fi

  # The anchor MUST resolve to a real heading in core, or drift detection is dead
  # for this entry from the day it is written.
  anchor="$(sed -n 's/^shadows:[[:space:]]*//p' "$NEW" 2>/dev/null | sed 's/.*#//; s/,.*//')"
  if [ -n "$anchor" ] && grep -qiF "$anchor" <<<"$(git -C "$DIST" show "${BASE}:core/team-roles/tea.md")"; then
    ok "shadows: anchors to a heading that EXISTS in core (#$anchor)"
  else
    bad "shadows: anchor '#$anchor' resolves to no heading -- drift detection is dead for this entry"
  fi

  # base_sha at BASE, not THEIRS. Stamping theirs would claim the consumer had already
  # read an upstream change it has not.
  b="$(sed -n 's/^base_sha:[[:space:]]*//p' "$NEW" 2>/dev/null)"
  if [ "$b" = "$BASE" ]; then ok "base_sha stamped at BASE (where the delta forked), not THEIRS"
  else bad "base_sha is '$b', want '$BASE' -- stamping theirs claims a read that never happened"; fi

  if grep -q 'Test Architect' "$NEW" 2>/dev/null; then ok "the consumer's text was carried into the override"
  else bad "the consumer's text was not carried into the override -- it is now LOST"; fi

  # core reverted, so the drift is gone
  if [ "$(ud "$DIST" "$BASE" "$CONS" | awk -F'\t' '$2=="team-roles/tea.md"{print $1}')" = "CORE-OK" ]; then
    ok "core reverted; tea.md is no longer unregistered drift"
  else
    bad "tea.md still reports drift after register-drift --apply"
  fi

  # A hook has no override grain. It must REFUSE, not invent one.
  rd "$DIST" "$BASE" "$CONS" hooks/ai-dlc-continue.sh --apply >/dev/null 2>&1
  if [ $? -eq 2 ]; then ok "refuses a HOOK (no override grain exists for hooks)"
  else bad "register-drift invented an override for a hook -- overrides shadow headings, hooks have none"; fi
  lrg_eqv cli-rd-refuse "$REG" rd_main "$DIST" "$BASE" "$CONS" hooks/ai-dlc-continue.sh --apply
  lrg_cell cli-rd-refuse 2 'register-drift' "a hook is refused"
  # tea.md is reverted now, so there is nothing left to register: the exit-1 outcome.
  lrg_eqv cli-rd-none "$REG" rd_main "$DIST" "$BASE" "$CONS" team-roles/tea.md
  lrg_cell cli-rd-none 1 'register-drift' "nothing to register"
fi

fi
if sg e2; then
echo "== E2. register-drift REFUSES rather than revert an edit it did not carry =="

# register-drift ends in a revert: core overwrites the consumer's file. Every step before it
# that fails QUIETLY therefore destroys an edit, and each world below is one such step, forced:
#   (a) a MIXED diff failure -- two edited sections, `diff` failing for Beta alone. Before the
#       fix the classifier read the empty stream as `yes` (template substitution only), Beta was
#       skipped, the override carried Alpha alone, and core was reverted: rc 0, Beta gone.
#   (b) the same world as a DRY RUN, which is the preview an operator approves.
#   (c) the override path already a DIRECTORY, so the override cannot be written as a file.
#   (d) the BODY extraction failing for Alpha (a `mktemp` shim, keyed on the call index derived
#       from a counting run, not hardcoded) -- only the pre-revert conservation check reads the
#       RESULT, so only it can see an override whose body lost a section. Its CONSUMER side does:
#       Alpha's edited line sits in a section whose text nothing written carries.
#   (e) the positive control: the same two-edit seed, nothing shimmed, registers BOTH sections.
# The shapes the name-keyed resolver misfiles, each measured before ff1ed69e as rc 0, REGISTERED,
# core reverted and the edit gone. Each is refused by the POSITIONAL conservation check:
#   (s) SHADOWED heading: an edited `## Review` below an unedited `## Review Process` -- both names
#       resolve to the latter, so the override carries the wrong section.
#   (u) DUPLICATE same-level heading, edited at its second occurrence.
#   (p) a PREAMBLE edit, above every `##`, beside an edited section.
#   (x) a core section the consumer DELETED: nothing shadows it, so it would render back. Only
#       the CORE side of the check sees this; the consumer side has no added line to test.
#   (y) a consumer-only `## Review` beside core's `## Review Process`: the name resolves to core's
#       section, so it is filed as an unchanged override section, not an extension. Only the
#       CONSUMER side sees this; the core side has no removed line.
#   (g) an EDITED `## 概要`, a heading whose name normalizes to nothing, so no override can anchor it.
#   (k) the ALLOW twin of (g), one property apart: `## 概要` UNCHANGED beside an edited Alpha
#       registers (rc 0) -- the unaddressable heading needs no carrying when byte-equal to core.
#   (j) the same world as (k) as a DRY RUN, which must preview rather than refuse.
#   (eof) an edited Alpha plus a new section appended at EOF must REGISTER: the edit in the
#       override, the new section in the extension. Its separator blank sits in core's last span.
#   (tok) a token site and a real edit coalesced into one hunk (`run {test_cmd} first.` / `then
#       merge.` -> `run pytest first.` / `then merge after E2S-REVIEW.`) must carry the edit, rc 0.
# Content refusals must say they are DETERMINISTIC (re-running unchanged refuses the same way),
# and (x) must name the deleted heading and the way through.
# Every arm is PRESENCE-shaped: a named refusal on stderr (the exact conservation line, by line
# number and text), a shim `.fired` marker where there is a shim, and the consumer file
# cmp-identical. A subject that emits nothing fails all of them.
# Worlds are fresh `mktemp -d` directories under $ROOT, one per drive: every --apply mutates its
# world, so a drive never reads a file a previous drive left.
E2_REALDIFF="$(command -v diff)"; E2_REALMK="$(command -v mktemp)"
if [ -z "$REG" ] || [ -z "$E2_REALDIFF" ] || [ -z "$E2_REALMK" ]; then
  bad "E2: cannot locate register-drift.sh ($REG), diff ($E2_REALDIFF) or mktemp ($E2_REALMK)"
else
  echo "HERMETIC-CONSUMED $(cd "$(dirname "$REG")" && pwd -P)/$(basename "$REG")"
  # Each world SHAPE is built once (one git init) as a template under $E2_TPL and copied per drive:
  # every --apply mutates its world, so a drive still gets a world nobody else touched, and the
  # subject sees the same bytes and the same base sha it would in a freshly initialised one.
  E2_TPL="$ROOT/e2tpl"; mkdir -p "$E2_TPL"
  e2_clone() { # <template> -> prints a fresh world dir copied from it
    local w
    w="$(mktemp -d "$ROOT/e2w.XXXXXX")" || return 1
    cp -R "$1/." "$w/" || return 1
    printf '%s' "$w"
  }
  e2_world() { # <beta-edit-marker> -> prints a fresh world dir
    local t="$E2_TPL/b-$1"
    if [ ! -d "$t" ]; then
      mkdir -p "$t/dist/core/team-roles" "$t/cons/.claude/team-roles" || return 1
      { git -C "$t/dist" init -q && git -C "$t/dist" config user.email f@x \
        && git -C "$t/dist" config user.name f \
        && printf '# Role: X\n\n## Alpha\n\nalpha core text.\n\n## Beta\n\nbeta core text.\n\n## Gamma\n\ngamma core text.\n' \
          > "$t/dist/core/team-roles/x.md" \
        && git -C "$t/dist" add -A && git -C "$t/dist" commit -qm base \
        && sed "s/alpha core text\./alpha E2-ALPHA-EDIT./; s/beta core text\./beta $1./" \
          "$t/dist/core/team-roles/x.md" > "$t/cons/.claude/team-roles/x.md" \
        && cp "$t/cons/.claude/team-roles/x.md" "$t/orig.md" \
        && git -C "$t/dist" rev-parse HEAD > "$t/base"; } || { rm -rf "$t"; return 1; }
    fi
    e2_clone "$t"
  }
  # The resolver-shape worlds (s u p x y g k j): core and consumer written whole, printf-%b text.
  e2_seed() { # <arm> -> sets E2_CORE / E2_CONS
    case "$1" in
      s) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Review Process\n\nproc.\n\n## Review\n\nreview.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Review Process\n\nproc.\n\n## Review\n\nreview E2S-REVIEW.\n' ;;
      u) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Notes\n\nn1.\n\n## Beta\n\nbeta.\n\n## Notes\n\nn2.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Notes\n\nn1.\n\n## Beta\n\nbeta.\n\n## Notes\n\nn2 E2S-NOTES.\n' ;;
      p) E2_CORE='# X\n\nintro.\n\n## Alpha\n\nalpha.\n'
         E2_CONS='# X\n\nintro E2S-INTRO.\n\n## Alpha\n\nalpha E2S-ALPHA.\n' ;;
      x) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Beta\n\nbeta E2S-COREBETA.\n\n## Gamma\n\ngamma.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Gamma\n\ngamma.\n' ;;
      y) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Review Process\n\nproc.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Review Process\n\nproc.\n\n## Review\n\nreview E2S-ADDREVIEW.\n' ;;
      g) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## 概要\n\ngaiyou.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## 概要\n\ngaiyou E2S-GAIYOU.\n' ;;
      k|j) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## 概要\n\ngaiyou.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## 概要\n\ngaiyou.\n' ;;
      o) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Beta\n\nbeta.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Beta\n\nbeta.\n\n## Local\n\nlocal E2S-EOF.\n' ;;
      t) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Beta\n\nrun {test_cmd} first.\nthen merge.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Beta\n\nrun pytest first.\nthen merge after E2S-REVIEW.\n' ;;
      *) return 1 ;;
    esac
  }
  e2_world2() { # <arm> -> prints a fresh world dir
    local t="$E2_TPL/s-$1"
    if [ ! -d "$t" ]; then
      e2_seed "$1" || return 1
      mkdir -p "$t/dist/core/team-roles" "$t/cons/.claude/team-roles" || return 1
      { git -C "$t/dist" init -q && git -C "$t/dist" config user.email f@x \
        && git -C "$t/dist" config user.name f \
        && printf '%b' "$E2_CORE" > "$t/dist/core/team-roles/x.md" \
        && git -C "$t/dist" add -A && git -C "$t/dist" commit -qm base \
        && printf '%b' "$E2_CONS" > "$t/cons/.claude/team-roles/x.md" \
        && cp "$t/cons/.claude/team-roles/x.md" "$t/orig.md" \
        && git -C "$t/dist" rev-parse HEAD > "$t/base"; } || { rm -rf "$t"; return 1; }
    fi
    e2_clone "$t"
  }
  # The exact refusal each resolver-shape arm must print: which SIDE of the check fired, at which
  # line, quoting that line. Derived by driving ff1ed69e over the seeds above.
  # One line per acceptable refusal (grep -F reads a newline-separated pattern list). Where BOTH
  # sides of the check see the shape (s u p g), either side's line for that position is accepted,
  # so disabling one side leaves the arm holding on the other -- the side-specific proof is owned
  # by (x), which only the core side sees, and by (y) and (d), which only the consumer side sees.
  # The consumer-side refusal is keyed on its line-and-text PREFIX only: the prose after it, and
  # which line of a pure addition it names first (blank added lines are about to be skipped), are
  # not what the arm is about. (y) therefore accepts any consumer line.
  e2_want() { case "$1" in
    s) printf '%s\n' "conservation: core line 13 (review.) was changed or removed by the consumer" \
                     "conservation: consumer line 13 (review E2S-REVIEW.)" ;;
    u) printf '%s\n' "conservation: core line 17 (n2.) was changed or removed by the consumer" \
                     "conservation: consumer line 17 (n2 E2S-NOTES.)" ;;
    p) printf '%s\n' "conservation: core line 3 (intro.) was changed or removed by the consumer" \
                     "conservation: consumer line 3 (intro E2S-INTRO.)" ;;
    g) printf '%s\n' "conservation: core line 9 (gaiyou.) was changed or removed by the consumer" \
                     "conservation: consumer line 9 (gaiyou E2S-GAIYOU.)" ;;
    x) echo "conservation: the consumer DELETED core heading \"## Beta\" (core line 7)" ;;
    y) echo "conservation: consumer line " ;;
    d) echo "conservation: consumer line 5 (alpha E2-ALPHA-EDIT.)" ;;
  esac; }
  # A `diff` that exits 2 only when an input carries KEEPME (Beta's marker in the keyed seed) AND
  # it was handed a non-path first operand -- substitution_only's per-section diff, never the
  # whole-file conservation diff, which takes two real paths. That operand was a `/dev/fd/*`
  # process substitution until 0.647.0 and is `-` (the staged section piped in) since, because the
  # `<( )` spelling races under concurrent bash 3.2; both are keyed. So Alpha is classified, Beta alone
  # is not, and the conservation check still runs for real: layer 1 is then answered
  # by layer 2's positional check, not by a shim that happened to fail both.
  e2_diffshim() {
    local d
    d="$(mktemp -d "$ROOT/e2dshim.XXXXXX")" || return 1
    cat > "$d/diff" <<EOF
#!/bin/bash
t1=\$(mktemp) || exit 3; t2=\$(mktemp) || exit 3
cat "\$1" > "\$t1"; cat "\$2" > "\$t2"
case "\$1" in /dev/fd/*|-) psub=y ;; *) psub=n ;; esac
if [ "\$psub" = y ] && grep -q KEEPME "\$t1" "\$t2"; then rm -f "\$t1" "\$t2"; : > "$d/.fired"; exit 2; fi
"$E2_REALDIFF" "\$t1" "\$t2"; rc=\$?; rm -f "\$t1" "\$t2"; exit \$rc
EOF
    chmod +x "$d/diff" && printf '%s' "$d"
  }
  # A `mktemp` that logs every call (`noarg` = section_of's own temp file, `arg` = a templated
  # temp beside a target, `argdir` = a `-d` directory) and fails the Nth no-argument call; N=0
  # never fails. `argdir` is its own token because lib.sh makes its memo directory with
  # `mktemp -d` when it is sourced, which is BEFORE any section is read: logged as `arg`, it was
  # the first templated call and put Alpha's body at call 0, so arm (d) could not be keyed.
  e2_mkshim() { # <N>
    local d
    d="$(mktemp -d "$ROOT/e2mshim.XXXXXX")" || return 1
    echo 0 > "$d/n"; : > "$d/log"
    cat > "$d/mktemp" <<EOF
#!/bin/bash
if [ \$# -eq 0 ]; then
  n=\$(( \$(cat "$d/n") + 1 )); echo \$n > "$d/n"; echo noarg >> "$d/log"
  if [ "\$n" = "$1" ]; then : > "$d/.fired"; exit 1; fi
elif [ "\$1" = -d ]; then
  echo argdir >> "$d/log"
else
  echo arg >> "$d/log"
fi
exec "$E2_REALMK" "\$@"
EOF
    chmod +x "$d/mktemp" && printf '%s' "$d"
  }
  e2_run() { # <script> <world> <shim-dir or -> [--apply]
    local s="$1" w="$2" p="$3" P="$PATH"; shift 3
    [ "$p" = - ] || P="$p:$PATH"
    PATH="$P" bash "$s" "$w/dist" "$(cat "$w/base")" "$w/cons" team-roles/x.md "$@" > "$w/out" 2> "$w/err"
    echo $? > "$w/rc"
  }
  e2_novr() { ls -A "$1/cons/.claude/skills/ai-dlc/overrides" 2>/dev/null | wc -l | tr -d ' '; }

  # The call index of Alpha's BODY extraction, derived: the body is extracted after the classify
  # loop and immediately before the first templated temp file (the override's), one no-argument
  # call per changed section, Alpha first. A counting run that registers cleanly supplies it.
  E2_N=""
  e2w="$(e2_world E2-BETA-EDIT-KEEPME)"; e2m="$(e2_mkshim 0)"
  if [ -n "$e2w" ] && [ -n "$e2m" ]; then
    e2_run "$REG" "$e2w" "$e2m" --apply
    e2c="$(awk '/^arg$/ { print c + 0; f = 1; exit } /^noarg$/ { c++ }' "$e2m/log")"
    if [ "$(cat "$e2w/rc")" = 0 ] && grep -q '^REGISTERED' "$e2w/out" && [ -n "$e2c" ] && [ "$e2c" -ge 3 ]; then
      E2_N=$((e2c - 1))
    fi
  fi
  if [ -n "$E2_N" ]; then
    ok "E2 harness: a counting run registers cleanly and puts Alpha's body extraction at no-argument mktemp call $E2_N"
  else
    bad "E2 harness: the counting run did not register or logged no templated mktemp before the body (rc=$(cat "$e2w/rc" 2>/dev/null)) -- arm (d) cannot be keyed"
  fi

  E2_WHY=""; E2_W=""
  e2_arm() { # <a|b|c|d|e|n|s|u|p|x|y|g|k|j|o|t> <script> -> 0 holds / 1 fails / 2 harness; E2_WHY and E2_W describe the run
    local arm="$1" s="$2" w sh="" o rc f=n same=n novr beta=E2-BETA-EDIT-KEEPME want ext fixd
    E2_WHY=""; E2_W=""
    case "$arm" in
      s|u|p|x|y|g|k|j|o|t)
        w="$(e2_world2 "$arm")"; [ -n "$w" ] || { E2_WHY="world build failed"; return 2; }
        E2_W="$w"; o="$w/cons/.claude/skills/ai-dlc/overrides/team-roles__x__consumer-drift.md"
        if [ "$arm" = j ]; then e2_run "$s" "$w" -; else e2_run "$s" "$w" - --apply; fi
        rc="$(cat "$w/rc")"
        cmp -s "$w/orig.md" "$w/cons/.claude/team-roles/x.md" && same=y
        novr="$(e2_novr "$w")"
        case "$arm" in
          k)
            E2_WHY="rc=$rc registered=$(grep -c '^REGISTERED' "$w/out") unaddressable-line=$(grep -c 'headings no override can anchor.*概要' "$w/out") alpha=$(grep -c E2S-ALPHA "$o" 2>/dev/null) reverted=$(cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" && echo y || echo n) err=$(head -1 "$w/err" | cut -c1-120)"
            [ "$rc" = 0 ] && grep -q '^REGISTERED' "$w/out" && grep -q 'headings no override can anchor.*概要' "$w/out" \
              && grep -q E2S-ALPHA "$o" && cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" ;;
          j)
            E2_WHY="rc=$rc dry-run-line=$(grep -c 'DRY RUN' "$w/out") unaddressable-line=$(grep -c 'headings no override can anchor.*概要' "$w/out") preview-alpha=$(grep -c E2S-ALPHA "$w/out") overrides-dir-entries=$novr consumer-identical=$same err=$(head -1 "$w/err" | cut -c1-120)"
            [ "$rc" = 0 ] && grep -q 'DRY RUN' "$w/out" && grep -q 'headings no override can anchor.*概要' "$w/out" \
              && grep -q E2S-ALPHA "$w/out" && [ "$novr" = 0 ] && [ "$same" = y ] ;;
          o)
            ext="$w/cons/.claude/skills/ai-dlc/extensions/roles/x-consumer.md"
            E2_WHY="rc=$rc registered=$(grep -c '^REGISTERED' "$w/out") ovr-alpha=$(grep -c E2S-ALPHA "$o" 2>/dev/null) ext-eof=$(grep -c E2S-EOF "$ext" 2>/dev/null) reverted=$(cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" && echo y || echo n) err=$(head -1 "$w/err" | cut -c1-140)"
            [ "$rc" = 0 ] && grep -q '^REGISTERED' "$w/out" && grep -q E2S-ALPHA "$o" && grep -q E2S-EOF "$ext" \
              && cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" ;;
          t)
            E2_WHY="rc=$rc registered=$(grep -c '^REGISTERED' "$w/out") ovr-review=$(grep -c E2S-REVIEW "$o" 2>/dev/null) ovr-alpha=$(grep -c E2S-ALPHA "$o" 2>/dev/null) reverted=$(cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" && echo y || echo n) err=$(head -1 "$w/err" | cut -c1-140)"
            [ "$rc" = 0 ] && grep -q '^REGISTERED' "$w/out" && grep -q E2S-REVIEW "$o" && grep -q E2S-ALPHA "$o" \
              && cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" ;;
          *)
            # Every content refusal is DETERMINISTIC and must say so, not tell the operator to re-run.
            # A deleted heading must also name the way through.
            want="$(e2_want "$arm")"
            fixd="re-running without changing the file refuses the same way"
            E2_WHY="rc=$rc names-the-line=$(grep -cF "$want" "$w/err") deterministic=$(grep -cF "$fixd" "$w/err") way-through=$(grep -cF 'Way through: keep the heading' "$w/err") registered=$(grep -c '^REGISTERED' "$w/out") overrides-dir-entries=$novr consumer-identical=$same err=$(head -1 "$w/err" | cut -c1-140)"
            [ "$rc" = 2 ] && grep -qF "$want" "$w/err" && grep -qF "$fixd" "$w/err" && [ "$novr" = 0 ] && [ "$same" = y ] \
              && ! grep -q '^REGISTERED' "$w/out" \
              && { [ "$arm" != x ] || grep -qF 'Way through: keep the heading' "$w/err"; } ;;
        esac
        return $? ;;
    esac
    [ "$arm" = n ] && beta=E2-BETA-EDIT-PLAIN
    w="$(e2_world "$beta")"; [ -n "$w" ] || { E2_WHY="world build failed"; return 2; }
    E2_W="$w"; o="$w/cons/.claude/skills/ai-dlc/overrides/team-roles__x__consumer-drift.md"
    case "$arm" in
      a|b|n) sh="$(e2_diffshim)" ;;
      d)     [ -n "$E2_N" ] || { E2_WHY="no derived call index"; return 2; }; sh="$(e2_mkshim "$E2_N")" ;;
      c)     mkdir -p "$o" ;;
    esac
    case "$arm" in a|b|n|d) [ -n "$sh" ] || { E2_WHY="shim build failed"; return 2; } ;; esac
    if [ "$arm" = b ]; then e2_run "$s" "$w" "${sh:--}"; else e2_run "$s" "$w" "${sh:--}" --apply; fi
    rc="$(cat "$w/rc")"
    [ -n "$sh" ] && [ -e "$sh/.fired" ] && f=y
    cmp -s "$w/orig.md" "$w/cons/.claude/team-roles/x.md" && same=y
    novr="$(e2_novr "$w")"
    case "$arm" in
      a|b)
        E2_WHY="rc=$rc fired=$f names-Beta=$(grep -cF "cannot classify section 'Beta'" "$w/err") overrides-dir-entries=$novr consumer-identical=$same dry-run-line=$(grep -c 'DRY RUN' "$w/out")"
        [ "$rc" = 2 ] && [ "$f" = y ] && grep -qF "cannot classify section 'Beta'" "$w/err" \
          && [ "$novr" = 0 ] && [ "$same" = y ] && ! grep -q 'DRY RUN' "$w/out" && ! grep -q '^REGISTERED' "$w/out" ;;
      c)
        E2_WHY="rc=$rc names-path=$(grep -cF 'exists and is not a regular file' "$w/err") inside-the-dir=$(ls -A "$o" 2>/dev/null | wc -l | tr -d ' ') consumer-identical=$same"
        [ "$rc" = 2 ] && grep -qF 'exists and is not a regular file' "$w/err" && [ -d "$o" ] \
          && [ "$(ls -A "$o" | wc -l | tr -d ' ')" = 0 ] && [ "$novr" = 1 ] && [ "$same" = y ] ;;
      d)
        want="$(e2_want d)"
        E2_WHY="rc=$rc fired=$f names-Alpha-line=$(grep -cF "$want" "$w/err") overrides-dir-entries=$novr consumer-identical=$same err=$(head -1 "$w/err" | cut -c1-140)"
        [ "$rc" = 2 ] && [ "$f" = y ] && grep -qF "$want" "$w/err" \
          && [ "$novr" = 0 ] && [ "$same" = y ] ;;
      e|n)
        E2_WHY="rc=$rc fired=$f registered=$(grep -c '^REGISTERED' "$w/out") alpha=$(grep -c E2-ALPHA-EDIT "$o" 2>/dev/null) beta=$(grep -c "$beta" "$o" 2>/dev/null) reverted=$(cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" && echo y || echo n)"
        [ "$rc" = 0 ] && [ "$f" = n ] && grep -q '^REGISTERED' "$w/out" && grep -q E2-ALPHA-EDIT "$o" \
          && grep -q "$beta" "$o" && cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" ;;
    esac
  }

  e2_label() { case "$1" in
    a) echo "(a) MIXED diff failure, --apply" ;;   b) echo "(b) MIXED diff failure, dry run" ;;
    c) echo "(c) override path is a directory" ;;  d) echo "(d) Alpha's body extraction fails" ;;
    e) echo "(e) positive control, unshimmed" ;;   n) echo "(a') keyed shim over an UNKEYED seed" ;;
    s) echo "(s) edited ## Review SHADOWED by ## Review Process" ;;
    u) echo "(u) duplicate same-level ## Notes, second one edited" ;;
    p) echo "(p) preamble edit beside an edited section" ;;
    x) echo "(x) a core section the consumer DELETED" ;;
    y) echo "(y) consumer-only ## Review resolving to core's ## Review Process" ;;
    g) echo "(g) an EDITED unaddressable ## 概要" ;;
    k) echo "(k) an UNCHANGED unaddressable ## 概要, --apply" ;;
    j) echo "(j) an UNCHANGED unaddressable ## 概要, dry run" ;;
    o) echo "(eof) an edit plus a section appended at EOF" ;;
    t) echo "(tok) a token site coalesced with a real edit in one hunk" ;;
  esac; }
  e2_ok() { case "$1" in
    a) echo "refused naming Beta (rc 2), the diff shim fired, no override written, the consumer file cmp-identical" ;;
    b) echo "the dry run refuses too, naming Beta, and prints no DRY RUN preview missing a section" ;;
    c) echo "refused (rc 2) naming the path, nothing moved inside the directory, the consumer file cmp-identical" ;;
    d) echo "the conservation check's CONSUMER side refuses naming Alpha's edited line 5 (rc 2), the mktemp shim fired, no override, the consumer file cmp-identical" ;;
    s|u|p|g) echo "refused (rc 2) by the positional conservation check naming the edited line by number and text, as deterministic, no override, the consumer file cmp-identical" ;;
    x) echo "refused (rc 2) naming the DELETED core heading \"## Beta\" at core line 7 and the way through, as deterministic, no override, the consumer file cmp-identical" ;;
    y) echo "refused (rc 2) by the CONSUMER side naming a line of the misfiled section, as deterministic, no override, the consumer file cmp-identical" ;;
    o) echo "rc 0, REGISTERED, Alpha's edit in the override, the appended section in the extension, core reverted" ;;
    t) echo "rc 0, REGISTERED, the edit beside the token (E2S-REVIEW) carried in the override, core reverted" ;;
    k) echo "the allow twin of (g): rc 0, REGISTERED, the heading reported as unaddressable, Alpha carried, core reverted" ;;
    j) echo "the dry run previews (rc 0, DRY RUN, Alpha in the preview) rather than refusing, and writes nothing" ;;
    e) echo "rc 0, REGISTERED, the override carries BOTH edits, and core is reverted" ;;
    n) echo "the allow twin of (a): the same shim on a seed without its key does not fire, and both edits register" ;;
  esac; }

  E2_ARMS="a b c d e n s u p x y g k j o t"
  for e2a in $E2_ARMS; do
    e2_arm "$e2a" "$REG"; e2r=$?
    if [ "$e2r" = 0 ]; then ok "$(e2_label "$e2a"): $(e2_ok "$e2a")"
    else bad "$(e2_label "$e2a"): $E2_WHY (verdict $e2r)"; fi
  done

fi

fi
if sg f; then
echo "== F. upstream ABSORBED the consumer's in-place delta =="

# Extensions have had this signal since v0.34.0 (EXTENSION-RETIRE-CANDIDATE). Core drift
# had NO equivalent, so a consumer whose hardening was upstreamed went on being told to
# "refile it as an override, or revert" — with nothing saying the revert was now the
# RIGHT answer. It would have blocked forever on a delta core already carried.
# (Live case: the reference consumer's handoff resume-prompt guard, v0.55.0.)
st_theirs="$(ud "$DIST" "$BASE" "$CONS" "$THEIRS" | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"
st_base="$(ud "$DIST" "$BASE" "$CONS" "$BASE"   | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"
st_none="$(ud "$DIST" "$BASE" "$CONS"           | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"

if [ "$st_theirs" = "HARD-CORE-DRIFT-ABSORBED" ]; then
  ok "upstream absorbed the delta -> HARD-CORE-DRIFT-ABSORBED (remedy: revert, not override)"
else
  bad "absorption NOT detected (got '$st_theirs') — the consumer would be told to refile a delta core already carries, forever"
fi

# The control: at BASE, upstream does NOT have the lines, so it must NOT claim absorption.
# A detector that says 'absorbed' when nothing was absorbed invites the operator to
# DELETE consumer text upstream never took.
if [ "$st_base" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "not-yet-absorbed -> plain HARD-UNREGISTERED-CORE-DRIFT (no false 'absorbed')"
else
  bad "claimed absorption against a core that does NOT carry the delta (got '$st_base') — this would delete consumer text"
fi

if [ "$st_none" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "no theirs-ref -> old behaviour preserved"
else
  bad "behaviour changed when no theirs-ref is passed (got '$st_none')"
fi

# It must still BLOCK. Absorption changes the recommendation, not who decides: a revert
# deletes consumer content, and only the operator can confirm nothing was lost.
case "$st_theirs" in
  HARD-*) ok "absorption still BLOCKS apply (a revert deletes text; the operator confirms)" ;;
  *)      bad "absorption downgraded out of HARD- — apply would silently delete the consumer's hook" ;;
esac

fi
if sg c3; then
echo "== C3. an override that delegates INTO the section it shadows =="

# Precedence is overrides > extensions > core, so a whole-section shadow deletes every
# construct defined inside that section -- including one the override's own body points
# the lead at. It reads as a correct single-source delegation and behaves as a dropped
# one. Both real instances on the reference consumer were reported OVERRIDE-OK while
# doing exactly this, which is why the two questions must be asked separately.
DRIFT="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
if [ -z "$DRIFT" ]; then
  bad "FIXTURE BROKEN — cannot locate layer-drift.sh; C3 would pass by not running"
else
  echo "HERMETIC-CONSUMED $(cd "$(dirname "$DRIFT")" && pwd -P)/$(basename "$DRIFT")"
  # IN PROCESS (BL-878). The classifier is not started as a program: `inproc_run` sources it in a subshell made to look
  # like a fresh bash (core/fixtures/lib/inproc.sh; its guard returns after defining ld_main) and calls ld_main. lib.sh
  # builds its own blob memo only at BASH_SUBSHELL 0, which no subshell is, so the run gets a fresh private memo, as
  # the program builds one per run. layer-title-join carries the cli equivalence cells. A CORE FIXTURE SHIPS AHEAD OF
  # ITS SUBJECT, and this unit is shard c's first assertion: a classifier with neither the `ld_main() {` line nor the
  # column-0 source guard predates the wrap and reads SKIP (exit 0, never an ok); exactly one half is a respelled
  # subject and FAILs; a subject grep cannot READ is FIXTURE ERROR.
  # A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
  . "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
  . "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found beside $HERE" >&2; exit 2; }
  . "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found beside $HERE" >&2; exit 2; }
  grep -q '^ld_main() {$' "$DRIFT"; _gd=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$DRIFT"; _gg=$?
  if [ "$_gd" -gt 1 ] || [ "$_gg" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $DRIFT (grep exit $_gd/$_gg), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2
  fi
  [ "$_gd$_gg" != 11 ] || { echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE"; }
  [ "$_gd" = 0 ] || { echo "  FAIL  $DRIFT carries the column-0 source guard but no \`ld_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "$NAME: FAIL (1)" >&2; exit 1; }
  [ "$_gg" = 0 ] || { echo "  FAIL  $DRIFT defines \`ld_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run ld_main in this shell" >&2; echo "$NAME: FAIL (1)" >&2; exit 1; }
  _ldm="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX")" || { echo "FIXTURE ERROR: mktemp memo" >&2; exit 2; }
  ld_out="$(AI_DLC_RECONCILE_MEMO="$_ldm" inproc_run "$DRIFT" ld_main "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
  rm -rf "$_ldm"
  st_of() { printf '%s\n' "$ld_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }

  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-10\.md$')"; then
    ok "an override naming a construct defined inside its own shadow is REPORTED"
  else
    bad "the delegation went undetected — every future change to that construct fails to arrive while every check reports green"
  fi

  # THE CONTROL, and it must be able to fail. Same shape, same file, delegating to a
  # construct defined OUTSIDE the shadowed span. Without it the assertion above passes
  # for a detector that flags every override carrying a backticked term.
  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-10-control\.md$')"; then
    bad "an override delegating OUTSIDE its shadow was reported — the detector fires on every legitimate cross-section pointer"
  else
    ok "  and delegating to a construct outside the shadow stays silent"
  fi

  # It answers a DIFFERENT question than the drift arm. Both rows must appear for the
  # same entry: folding this into `worst` would hide it behind an OVERRIDE-OK, which is
  # precisely how both live instances stayed invisible.
  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-10\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (the two questions are independent)"
  else
    bad "  but the delegation status displaced the drift status — one entry, two questions, two rows"
  fi

  # THE MEASURED FALSE POSITIVE, and the only assertion that can catch its return.
  # When the backticked term is in the ANCHOR heading itself, naming it is
  # self-description, not delegation. Dropping the anchor-heading exclusion re-fires
  # this (1 of 13 on the reference consumer) and every other assertion here stays green.
  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-12-anchor\.md$')"; then
    bad "an override naming a term from the heading it OVERRIDES was reported — the anchor heading is not being excluded, and every self-describing override now fires"
  else
    ok "  and naming a term from the overridden heading itself stays silent"
  fi

  # Report-only. It must not block `apply`, or a consumer cannot take a security fix
  # until it has restructured its own overrides.
  if grep -q DELEGATES <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "OVERRIDE-DELEGATES-INTO-SHADOW carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only, never a blocker"
  fi

  # --- OVERRIDE-ASSERTS-SHADOW-SURVIVES, the sibling status ---------------------------
  # Same mechanism as the delegation arm, opposite failure: that one points the lead at
  # text precedence has removed, this one TELLS the lead the text is still there. Measured
  # on the reference consumer: a bare survival-vocabulary scan matches 5 of 13 overrides
  # with only 2 real; restricting the claim's noun to the shadowed grain takes the
  # false-positive set to zero. The three controls below are those three false positives.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    ok "an override asserting its own shadowed span survives is REPORTED"
  else
    bad "the survival claim went undetected — the body states something false about its own effect and every check reports green"
  fi

  # THE WRAP, isolated in its own entry so exactly ONE assertion is sensitive to it. The
  # claim splits across a newline between 'Every other part of' and 'Rule 16', where the
  # real instance splits. A line-based predicate returns zero here, which reads identically
  # to compliance. Nothing else in this file would notice the flattening being removed.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-16-wrapped\.md$')"; then
    ok "  and a claim WRAPPING across a newline is still found (the body is flattened)"
  else
    bad "  the wrapped claim was missed — a line-based scan reports a false zero on the real shape"
  fi

  # --- OVERRIDE-BODY-UNCLAIMED (LC-O16) ------------------------------------------------
  # The third body-side question, and the one that asks something the other two cannot:
  # LC-O9 and LC-O14 ask whether the body is TRUTHFUL, this asks whether it is REACHED.
  # The state is what an LC-O15 narrowing LEAVES BEHIND when it removes an anchor and keeps
  # the text, so the two clauses have to be read together.
  if grep -qx OVERRIDE-BODY-UNCLAIMED <<<"$(st_of 'SKILL__Rule-18-unclaimed\.md$')"; then
    ok "a body section no shadows: anchor claims is REPORTED"
  else
    bad "the unclaimed body section went undetected — it is applied by nothing while every mechanical check reports green"
  fi

  # THE NEAR-MISS, and it is the assertion that stops this arm being a heading counter. A
  # sub-heading nested INSIDE a claimed section is inside that anchor's span; a heading-set
  # difference would report every '###' child of every shadowed section on every consumer.
  if grep -qx OVERRIDE-BODY-UNCLAIMED <<<"$(st_of 'SKILL__Rule-19-nested\.md$')"; then
    bad "a sub-heading NESTED inside the claimed section was reported — the claim is being read as a heading set, not a span, and every override with a child heading is a false positive"
  else
    ok "  and a sub-heading nested inside a claimed section stays silent"
  fi

  # The single-anchor shape: a body restating NO shadowed heading is the WHOLE span of its
  # one anchor, so nothing in it can be unclaimed. readopt-override.sh names this shape at
  # its own refusal site; an arm that fired here would report every such entry forever.
  if grep -qx OVERRIDE-BODY-UNCLAIMED <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    bad "the single-anchor shape (a body restating no shadowed heading) was reported — the whole body is that anchor's span and nothing in it can be unclaimed"
  else
    ok "  and the single-anchor shape stays silent"
  fi

  if grep -q '^HARD-' <<<"$(st_of 'SKILL__Rule-18-unclaimed\.md$')"; then
    bad "OVERRIDE-BODY-UNCLAIMED carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only (no HARD- prefix), so it cannot block an apply"
  fi

  # It answers a DIFFERENT question than the drift arm, same as its sibling. Both real
  # instances were OVERRIDE-OK while making the claim.
  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (two questions, two rows)"
  else
    bad "  but the survival status displaced the drift status — it would hide behind an OVERRIDE-OK"
  fi

  # CONTROL 1 — the shape the grain warning names as legitimate, and the reason the noun
  # set excludes `file`. An override shadowing ONE section that says the rest of the FILE
  # is unchanged is telling the truth, in the same vocabulary. Widening the predicate to
  # any survival claim re-fires this and every other assertion here stays green.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-14-file-claim\.md$')"; then
    bad "an override correctly saying the rest of the FILE is unchanged was reported — the noun restriction is gone and every honest scoping sentence now fires"
  else
    ok "  and a true claim about the rest of the FILE stays silent"
  fi

  # CONTROL 2 — the measured false-positive class: survival vocabulary whose subject is a
  # DIFFERENT named unit, plus a self-reference to the override's own body. Both shapes
  # occur on the reference consumer and both must stay silent.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-15-other-unit\.md$')"; then
    bad "an override whose survival claim names a DIFFERENT unit was reported — this is the 3-of-5 false-positive set returning"
  else
    ok "  and survival vocabulary about another unit stays silent"
  fi

  # Report-only, for the same reason as its sibling.
  if grep -q ASSERTS <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "OVERRIDE-ASSERTS-SHADOW-SURVIVES carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only, never a blocker"
  fi

  # --- OVERRIDE-LOOSE-ANCHOR: the pull-time counterpart of E7 --------------------------
  # E7 rejects an anchor that resolves only by the REVERSE arm at AUTHORING time. That
  # validator is consumer-run and skippable; the pull is not, and an anchor finer than a
  # heading silently widens the shadow to the whole section either way.
  #
  # NOT a "mirror of E7". Even now that both read `shadows:` through the same shadow_parts,
  # E7 resolves against the consumer's on-disk core and this resolves against THEIRS — the
  # incoming distribution — so they answer the same question about two different trees.
  if grep -qx OVERRIDE-LOOSE-ANCHOR <<<"$(st_of 'SKILL__Rule-11-loose\.md$')"; then
    ok "an anchor that CONTAINS its heading is REPORTED at pull time"
  else
    bad "the loose anchor went undetected — the entry shadows the whole section while the operator believes it shadowed a paragraph"
  fi

  # CONTROL — the legitimate id-prefix grain, in the same vocabulary. `#Rule 8` naming
  # `## Rule 8 -- Validation Depth` is a consumer naming a rule by its id, and it is what
  # nearly every entry here does. If this fires, the arm has been inverted and every
  # well-formed override in the consumer reports.
  if grep -qx OVERRIDE-LOOSE-ANCHOR <<<"$(st_of 'SKILL__Rule-8\.md$')"; then
    bad "a FORWARD-matching id-prefix anchor was reported loose — the containment direction is inverted and every honest entry now fires"
  else
    ok "  and a FORWARD-matching id-prefix anchor stays silent"
  fi

  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-11-loose\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (two questions, two rows)"
  else
    bad "  but the loose status displaced the drift status — it would hide behind an OVERRIDE-OK"
  fi

  # --- OVERRIDE-DOUBLE-SHADOW: a finding that exists only ACROSS entries ---------------
  # Each entry is individually well-formed. Precedence resolves the overlap silently, so
  # which body governs is an ordering accident no entry declares, and every commit touching
  # the span invalidates BOTH stamps while reconciling one looks complete.
  ds_a="$(printf '%s\n' "$(st_of 'SKILL__Rule-7-dup-a\.md$')" | grep -cx OVERRIDE-DOUBLE-SHADOW || true)"
  ds_b="$(printf '%s\n' "$(st_of 'SKILL__Rule-7-dup-b\.md$')" | grep -cx OVERRIDE-DOUBLE-SHADOW || true)"
  if [ "$ds_a" -eq 1 ] && [ "$ds_b" -eq 1 ]; then
    ok "two entries claiming one (file, anchor) are BOTH reported"
  else
    bad "double shadow filed under a=$ds_a b=$ds_b (want 1 and 1) — a row under only one of them leaves the other reading clean on the finding it is half of"
  fi

  # CONTROL — a single-claimant anchor. Without this the check could be counting every
  # anchor as its own duplicate and both assertions above would still be green.
  if grep -qx OVERRIDE-DOUBLE-SHADOW <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    bad "a single-claimant anchor was reported as a double shadow — the key is collapsing entries that do not collide"
  else
    ok "  and an anchor only one entry claims stays silent"
  fi

  # Report-only, and the reason is on the record: the one live instance is DELIBERATE and
  # says so in prose. An ERROR would fire on a case the consumer already reasoned about.
  if grep -qE 'LOOSE-ANCHOR|DOUBLE-SHADOW' <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "a new pull-time status carries a HARD- prefix — it would block apply on a report-only finding"
  else
    ok "  and both new statuses are report-only, never blockers"
  fi

fi

fi
if sg sup; then
[ -z "$DRIFT" ] || echo "HERMETIC-CONSUMED $(cd "$(dirname "$DRIFT")" && pwd -P)/$(basename "$DRIFT")"
# --- OVERRIDE-SUPERSEDED: core declaring an entry is no longer NEEDED ------------------
#
# Every other status asks whether the override is still CORRECT. This one asks whether it
# is still needed, and it is the only status whose answer is "delete this entry". Without
# it a superseded override presents as ordinary section drift -- which reads as "re-adopt
# the new wording", not "you can retire this" -- so the entry survives and goes on freezing
# every unrelated line in its shadowed span at base_sha. That is how a real core fix failed
# to reach the reference consumer.
if [ -z "$DRIFT" ]; then
  bad "FIXTURE BROKEN — no layer-drift.sh; the supersession arm would pass by not running"
else
  mkdir -p "$DIST/core/skills/ai-dlc"

  # A CORE FILE THE SURPLUS ARMS CAN BE MEASURED AGAINST, committed BEFORE the declaration so an
  # entry can carry it as its own `base_sha`. Every other SUP__ entry below shadows a file that
  # does not exist in this seed at all — which is the UNMEASURABLE case, asserted in its own right
  # further down. Without this commit the surplus arms would only ever exercise that branch, and a
  # measurement that never runs reports the same silence as one that found nothing.
  #
  # `### 3. Widget schema.` is FIVE non-blank lines including its heading. The two entries seeded
  # against it differ by exactly three lines, so the expected numbers below are seeded rather than
  # recomputed — a fixture that re-derives the answer with the same expression it is testing
  # agrees with itself.
  mkdir -p "$DIST/core/skills/ai-dlc/steps"
  cat > "$DIST/core/skills/ai-dlc/steps/widget.md" <<'WIDGET'
# Widget

### 3. Widget schema.

Core line one.
Core line two.
Core line three.

### 4. Other section.

Untouched.
WIDGET
  git -C "$DIST" add -A >/dev/null 2>&1
  git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "core carries the widget schema" >/dev/null 2>&1
  WBASE="$(git -C "$DIST" rev-parse --short HEAD)"

  cat > "$DIST/core/skills/ai-dlc/layer-contract.yaml" <<'YML'
contract_version: 13
override_supersessions:
  - shadows: steps/widget.md#3. Widget schema.
    since_core_version: "9.9.9"
    replaces_with:
      settings_env_key: AI_DLC_WIDGET_EXTRA
  - shadows: steps/widget.md#5. Adopted section.
    since_core_version: "9.9.9"
    reason: core took this entry's paragraph verbatim; there is nothing to configure.
  - shadows: steps/widget.md#6. Two-key section.
    since_core_version: "9.9.9"
    replaces_with:
      settings_env_keys:
        - AI_DLC_WIDGET_ALPHA
        - AI_DLC_WIDGET_BETA
  - shadows: steps/widget.md#8. No-since section.
    replaces_with:
      settings_env_key: AI_DLC_WIDGET_NOSINCE
absorbed_from:
  - path: core/skills/ai-dlc/extensions/README.md
YML
  git -C "$DIST" add -A >/dev/null 2>&1
  git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "declare a supersession" >/dev/null 2>&1
  THEIRS2="$(git -C "$DIST" rev-parse --short HEAD)"

  # The MATCH and its CONTROL differ in one field: the anchor. Same file, same shape, same
  # base_sha -- so an arm that fires on both is matching "is an override", not "is superseded".
  #
  # SUP__multi and SUP__multictl are the MULTI-ANCHOR pair, and they are the case the join was
  # blind to. The declared anchor is deliberately FIRST in SUP__multi's list, so a reader that keeps only the LAST part misses THIS entry
  # while single-anchor SUP__match still fires.
  # single-anchor SUP__match firing. Their own difference is one anchor: SUP__multictl bundles
  # two anchors core declares nothing about, so an arm that fires on it is matching "shadows more
  # than one thing", not "shadows something core superseded".
  for pair in "SUP__match:steps/widget.md#3. Widget schema." "SUP__control:steps/widget.md#4. Other section." "SUP__adopted:steps/widget.md#5. Adopted section." "SUP__twokey:steps/widget.md#6. Two-key section." "SUP__nosince:steps/widget.md#8. No-since section." "SUP__multi:steps/widget.md#3. Widget schema., #4. Other section." "SUP__multictl:steps/widget.md#4. Other section., #7. Also undeclared."; do
    nm="${pair%%:*}"; sh_v="${pair#*:}"
    cat > "$CONS/.claude/skills/ai-dlc/overrides/${nm}.md" <<EOF
---
shadows: ${sh_v}
base_sha: ${BASE}
reason: fixture entry
conforms_to: 13
---

# body
EOF
  done

  # THE TWO SURPLUS ENTRIES. Same anchor, same base_sha, same declaration — they differ ONLY in
  # whether the shadowed span carries lines core does not have. That is what makes the pair a
  # test of the measurement rather than of the entry's size.
  cat > "$CONS/.claude/skills/ai-dlc/overrides/SUP__surplus.md" <<EOF
---
shadows: steps/widget.md#3. Widget schema.
base_sha: ${WBASE}
reason: fixture entry carrying three lines core does not have
conforms_to: 13
---

### 3. Widget schema.

Core line one.
Core line two.
Core line three.
Consumer surplus A.
Consumer surplus B.
Consumer surplus C.
EOF
  cat > "$CONS/.claude/skills/ai-dlc/overrides/SUP__nosurplus.md" <<EOF
---
shadows: steps/widget.md#3. Widget schema.
base_sha: ${WBASE}
reason: fixture entry whose span is byte-identical to core's
conforms_to: 13
---

### 3. Widget schema.

Core line one.
Core line two.
Core line three.
EOF

  sup_out="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>&1)"
  sup_st() { printf '%s\n' "$sup_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__match\.md$')"; then
    ok "an override core declares SUPERSEDED is reported as retirable"
  else
    bad "a superseded override was not reported — it survives the pull and keeps freezing its shadowed span"
  fi

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__control\.md$')"; then
    bad "CONTROL: an override on a DIFFERENT anchor was reported superseded — the arm matches any override"
  else
    ok "  and an override on an undeclared anchor stays silent"
  fi

  # THE TOKEN CONTRACT WITH apply.sh, which is where this can rot silently. apply.sh reads
  # `replaces_with=<KEY> ::` off the front of the detail to expand ONE superseded row into an
  # ORDERED, ATOMIC two-step worklist. If this prefix ever changes, apply falls back to a
  # single unordered row -- still green, still emitted, and the ordering constraint that keeps
  # a retire from re-imposing the core rule before its replacement is written is simply gone.
  # A degradation that keeps passing is the shape this repo names; assert the join, not the row.
  sup_detail="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__match\.md$/ {print $4}')"
  case "$sup_detail" in
    "replaces_with=AI_DLC_WIDGET_EXTRA ::"*)
      ok "  the detail leads with the replaces_with= token apply.sh parses, carrying the declared key" ;;
    *)
      bad "the replaces_with= token is missing or malformed -- apply.sh silently drops to a single unordered row: ${sup_detail:0:60}" ;;
  esac

  # NON-VACUITY. The two assertions above are both satisfied by a run that emitted nothing
  # at all for the control and something for the match; assert the run itself is alive.
  if [ "$(printf '%s\n' "$sup_out" | grep -c 'SUP__control')" -ge 1 ]; then
    ok "  CONTROL is present in the output under some other status (so its silence above is a real zero)"
  else
    bad "the control entry produced NO row at all — its silence proves nothing"
  fi

  # A SUPERSESSION NEEDS NO CONFIGURATION TO BE ONE.
  #
  # Core stops needing an override two ways: it turns a hardcoded set into an AI_DLC_* key
  # the consumer declares its value in (the row above), or it simply ADOPTS the entry's
  # prose, where there is no key because there is nothing to configure. The emission used to
  # be gated on `settings_env_key`, so the second kind could be authored in the contract and
  # would silently never fire — a declaration with no reader, which is the cannot-fire class
  # arriving through the data side where I36 does not look. Measured on the reference
  # consumer: three of eleven overrides retire by adoption, none by configuration.
  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__adopted\.md$')"; then
    ok "  a supersession declaring NO settings_env_key still fires (core adopted the prose)"
  else
    bad "an env-keyless supersession was not reported — the cheapest retirement class is undeclarable, and the contract row that declares it has no reader"
  fi

  # THE OTHER HALF OF THE apply.sh TOKEN CONTRACT. apply.sh strips a leading
  # `replaces_with=<KEY> ::` and, finding none, emits the SINGLE worklist row. If the
  # env-less detail carried the token with an empty key, apply would instead emit
  # "1/2 ATOMIC — write  into .claude/settings.json" and hand the operator an instruction
  # naming nothing. Assert the absence, because that failure is green on every other check.
  sup_adopted="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__adopted\.md$/ {print $4}')"
  case "$sup_adopted" in
    replaces_with=*) bad "the env-keyless detail leads with replaces_with= anyway — apply.sh will emit a 1/2 ATOMIC row telling the operator to write an empty key: ${sup_adopted:0:70}" ;;
    "")              bad "the env-keyless supersession produced an empty detail" ;;
    *)               ok "  and its detail omits the replaces_with= token, so apply.sh renders the single retire row" ;;
  esac

  # A SUPERSESSION MAY NEED MORE THAN ONE KEY, AND ONE PER ROW WAS NEVER A DECISION.
  # It was the only shape anyone had needed, so a retirement requiring two keys could not
  # be expressed at all and the entry stayed shadowed over a mechanism gap rather than over
  # a disagreement. The list form joins on a comma into the same field the single form
  # fills, and apply.sh splits it into N+1 ATOMIC rows.
  sup_twokey="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__twokey\.md$/ {print $4}')"
  case "$sup_twokey" in
    "replaces_with=AI_DLC_WIDGET_ALPHA,AI_DLC_WIDGET_BETA ::"*)
      ok "  a settings_env_keys: LIST carries BOTH keys, comma-joined, in the token apply.sh parses" ;;
    "") bad "the two-key supersession produced no detail at all" ;;
    *)  bad "the settings_env_keys: list did not render both keys in order: ${sup_twokey:0:80}" ;;
  esac

  # A DECLARATION WITH NO since_core_version AND A settings_env_key. The producer prints the empty
  # middle field, and a tab is IFS whitespace, so an `IFS=<tab> read` reader collapses it and lands
  # the env key in the since variable: the row then reads as an adoption needing no configuration.
  # The three declarations above all carry a since, so they are the control for this one.
  sup_nosince="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__nosince\.md$/ {print $4}')"
  case "$sup_nosince" in
    "replaces_with=AI_DLC_WIDGET_NOSINCE ::"*)
      ok "  a declaration with a settings_env_key and NO since_core_version keeps the key in its own field" ;;
    "") bad "the no-since supersession produced no detail at all" ;;
    *"nothing to configure"*) bad "the no-since declaration read as an adoption needing no configuration -- its env key moved into the since field: ${sup_nosince:0:100}" ;;
    *)  bad "the no-since declaration did not carry replaces_with=AI_DLC_WIDGET_NOSINCE: ${sup_nosince:0:100}" ;;
  esac
  case "$sup_detail" in
    "replaces_with=AI_DLC_WIDGET_EXTRA ::"*) ok "  CONTROL: the declaration beside it that carries a since still keys on its own env key" ;;
    *) bad "CONTROL: the with-since declaration lost its env key: ${sup_detail:0:80}" ;;
  esac


  # THE LIST MUST NOT BLEED. Its items begin with a dash, exactly like the rows of the
  # block itself, so a loose item pattern would swallow the next `- shadows:` and attribute
  # one entry's keys to another. The single-key row that follows it in the contract is the
  # control: if it still carries exactly its own key, the list terminated where it should.
  sup_still="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__match\.md$/ {print $4}')"
  case "$sup_still" in
    "replaces_with=AI_DLC_WIDGET_EXTRA ::"*)
      ok "  and the neighbouring single-key row still carries exactly its own key (the list did not bleed)" ;;
    *)  bad "the single-key row was contaminated by the list above it: ${sup_still:0:80}" ;;
  esac

  # --- THE SURPLUS THE REMEDY DROPS IS STATED AS A NUMBER --------------------------------
  #
  # THE REPORT BEHIND THIS. The consumer was told to narrow `shadows:` because core superseded
  # ONE ARM of an anchor, while their span under it carried 119 lines core does not have. The row
  # already warned, in prose, that narrowing "releases every unrelated line that anchor's span
  # froze at base_sha" — and an unquantified warning beside a concrete instruction reads as
  # boilerplate. The obvious remedy is to declare the ARM, and an arm is NOT ADDRESSABLE:
  # `override_supersessions` keys on `<file>#<anchor>` with no span vocabulary, the real case's
  # 231-line span carries exactly one sub-heading with the superseded machinery on BOTH sides of
  # it, and the other superseded arm is not in the shadowed file at all. So the row states the
  # size of what the operator is about to drop, which needs no new declaration.
  sup_surp="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__surplus\.md$/ {print $4}')"
  case "$sup_surp" in
    *"against core's 4 at ${WBASE}, and 3 of yours appear nowhere in core's"*)
      ok "the row MEASURES the surplus: 3 consumer-only line(s) against core's span at ${WBASE} — the operator is told the size of what narrowing drops" ;;
    "") bad "the surplus entry produced no OVERRIDE-SUPERSEDED detail at all, so this arm asserts nothing" ;;
    *"could NOT be measured"*)
      bad "the surplus went UNMEASURABLE on an entry whose span and core span both exist. Either the anchor is not resolving in one of the two, or base_sha is not being read — and the fallback sentence then hides it behind honest-sounding prose: ${sup_surp:0:200}" ;;
    *)  bad "the surplus was measured wrongly (want 3 consumer-only against core's 4): $(printf %s "$sup_surp" | grep -oE 'MEASURED:.*' | head -1 || echo "<no MEASURED clause in the detail at all>")" ;;
  esac

  # THE CONTROL, and it is what stops the arm being "print the entry's size". Same anchor, same
  # base_sha, same declaration; the only difference is that this span carries nothing core lacks.
  sup_nosurp="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__nosurplus\.md$/ {print $4}')"
  case "$sup_nosurp" in
    *"and 0 of yours appear nowhere in core's"*)
      ok "  CONTROL: an identical span reports 0 consumer-only lines — the number is a comparison, not the entry's length" ;;
    "") bad "the no-surplus control produced no detail at all, so the assertion above is unpaired" ;;
    *)  bad "CONTROL: a span byte-identical to core's did not report 0 consumer-only lines: ${sup_nosurp:0:220}" ;;
  esac

  # UNMEASURABLE IS SAID OUT LOUD. SUP__match shadows a section its own body does not contain, so
  # neither span resolves. The clause must SAY that rather than fall back to the qualitative
  # sentence alone — a warning that quietly loses its number reads exactly like one that never had
  # a subject, which is the defect class this whole arm belongs to.
  case "$sup_still" in
    *"could NOT be measured"*)
      ok "  an entry whose span does not resolve says so in the row, instead of dropping silently to prose" ;;
    *"appear nowhere in core's"*)
      bad "an entry with no resolvable span reported a MEASUREMENT anyway, so the numbers in the two assertions above cannot be trusted: ${sup_still:0:200}" ;;
    *)  bad "an entry whose span does not resolve carries neither a measurement nor the unmeasurable notice: ${sup_still:0:200}" ;;
  esac


  # --- A MULTI-ANCHOR OVERRIDE IS THE CASE THIS ARM WAS BLIND TO ------------------------------
  #
  # The join compared `norm` of the WHOLE `shadows:` value against `norm` of the declaration's,
  # so an entry bundling several anchors could never match a declaration naming ONE of them --
  # and the more anchors an entry bundles the more unrelated core text it freezes, which is
  # exactly the entry a retirement signal exists for. Measured on the reference consumer at
  # 0.310.0 and it was a LIVE miss: `overrides/steps__retro__domain-sections.md` shadows four
  # retro anchors, one of which core declared superseded at 0.281.0. Whole-string join on the
  # real tree over the real pull range: 0 rows. Same tree, that anchor alone in `shadows:`: 1.
  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__multi\.md$')"; then
    ok "a MULTI-anchor override is reported when core supersedes ONE of its anchors"
  else
    bad "a multi-anchor override naming a declared supersession went unreported — the join reads the whole shadows: string, so the entries that freeze the most core text are the ones it cannot see"
  fi

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__multictl\.md$')"; then
    bad "CONTROL: a multi-anchor override with NO declared anchor was reported — the arm is matching 'shadows more than one thing', not 'shadows something superseded'"
  else
    ok "  and a multi-anchor override with no declared anchor stays silent"
  fi

  # NON-VACUITY for that control, same reasoning as SUP__control's above.
  if [ "$(printf '%s\n' "$sup_out" | grep -c 'SUP__multictl')" -ge 1 ]; then
    ok "  CONTROL is present under some other status (so its silence is a real zero)"
  else
    bad "the multi-anchor control produced NO row at all — its silence proves nothing"
  fi

  # THE REMEDY IS NOT THE SAME REMEDY, AND SAYING SO IS THE POINT OF THE TOKEN.
  # `readopt-override.sh --stamp retire` DELETES THE FILE; there is no per-anchor retire. On a
  # multi-anchor entry that discards the anchors core has NOT superseded, and every section they
  # shadowed silently reverts to core. apply.sh renders the last worklist row off `retire_anchor=`
  # (asserted end to end in apply-worklist-rows), so a lost token is a row telling the operator
  # to delete an entry core asked them to narrow.
  sup_multi="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__multi\.md$/ {print $4}')"
  case "$sup_multi" in
    "replaces_with=AI_DLC_WIDGET_EXTRA :: retire_anchor=steps/widget.md#3. Widget schema. ::"*)
      ok "  its detail carries retire_anchor= after replaces_with=, naming the entry's OWN spelling of the superseded anchor" ;;
    *retire_anchor=*)
      bad "the retire_anchor= token is present but not in the ordered prefix apply.sh parses: ${sup_multi:0:100}" ;;
    *)
      bad "the multi-anchor detail carries NO retire_anchor= token, so apply.sh renders '--stamp retire' and tells the operator to delete an entry core asked them to narrow: ${sup_multi:0:100}" ;;
  esac

  # AND THE SINGLE-ANCHOR DETAIL MUST NOT GAIN THE TOKEN. For a one-anchor entry deleting the
  # file really IS the remedy, and a token there would turn the correct instruction into
  # "remove the only anchor", leaving an override that shadows nothing.
  case "$sup_still" in
    *retire_anchor=*) bad "the SINGLE-anchor detail gained a retire_anchor= token — apply.sh would tell the operator to strip the entry's only anchor instead of retiring it" ;;
    *)                ok "  and the single-anchor detail is unchanged: no token, so its remedy is still the retire stamp" ;;
  esac

fi

fi
if sg stub; then
# --- OVERRIDE-SHADOWS-POINTER-STUB (LC-O17): a shadow whose core section became a load-pointer stub ---
#
# Its own world: one dist with a BASE, a theirs whose `## Rule 8` carries lib.sh's pointer sentence (the stub) and a
# sibling theirs whose section is byte-identical but for that one line (the twin). The same override is driven
# against both, so every stub arm has a twin one property apart. Shard e is .dist-only: the subject is always
# present here, so a missing pointer grammar is a regression (bad), never a SKIP.
REC_DIR="$(cd "$(dirname "$READOPT")" && pwd -P)"
echo "HERMETIC-CONSUMED $REC_DIR/pull.sh"
if [ -z "$DRIFT" ] || [ ! -f "$REC_DIR/pull.sh" ] || ! grep -q '^rule_body_pointers() {' "$REC_DIR/lib.sh"; then
  bad "stub: layer-drift.sh, pull.sh or lib.sh's rule_body_pointers() is missing beside readopt-override.sh -- the pointer-stub arms cannot run"
else
  SW="$(mktemp -d "${TMPDIR:-/tmp}/lrg-stub.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  SD="$SW/dist"; SC="$SW/consumer"
  mkdir -p "$SD/core/skills/ai-dlc/rule-bodies" "$SC/.claude/skills/ai-dlc/overrides"
  git -C "$SD" init -q && git -C "$SD" config user.email f@x && git -C "$SD" config user.name f
  stub_skill() { # <divergence line> [pointer line] -> SKILL.md
    printf '%s\n' '# AI/DLC' '' '## Rule 7 -- Before' '' 'Untouched.' '' '## Rule 8 -- Validation Depth' '' \
      'Intro line kept across the range.' '' 'Second paragraph, kept across the range.' '' "$1"
    [ -z "${2:-}" ] || printf '\n%s\n' "$2"
    printf '%s\n' '' '## Rule 9 -- After' '' 'Tail section.'
  }
  stub_skill 'Divergence clause, OLD wording.' > "$SD/core/skills/ai-dlc/SKILL.md"
  printf '# Rule 8 -- binding text\n\nThe rule body.\n' > "$SD/core/skills/ai-dlc/rule-bodies/rule-8.md"
  git -C "$SD" add -A && git -C "$SD" commit -qm base
  SB="$(git -C "$SD" rev-parse --short HEAD)"
  stub_skill 'Divergence clause, NEW wording.' > "$SD/core/skills/ai-dlc/SKILL.md"
  git -C "$SD" add -A && git -C "$SD" commit -qm twin
  STW="$(git -C "$SD" rev-parse --short HEAD)"
  git -C "$SD" checkout -q "$SB" 2>/dev/null
  stub_skill 'Divergence clause, NEW wording.' 'READ AND FOLLOW `rule-bodies/rule-8.md` -- the binding text of this rule.' > "$SD/core/skills/ai-dlc/SKILL.md"
  git -C "$SD" add -A && git -C "$SD" commit -qm stub
  STS="$(git -C "$SD" rev-parse --short HEAD)"
  git -C "$SC" init -q && git -C "$SC" config user.email f@x && git -C "$SC" config user.name f
  git -C "$SD" show "${SB}:core/skills/ai-dlc/SKILL.md" > "$SC/.claude/skills/ai-dlc/SKILL.md"
  SOV="$SC/.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md"
  {
    printf '%s\n' '---' 'shadows: SKILL.md#Rule 8' "base_sha: ${SB}" 'reason: consumer validation-intensity line.' '---' ''
    printf '%s\n' '## Rule 8 -- Validation Depth' '' 'Consumer intensity: service/ is FULL, docs/ is LIGHT.' '' \
      'Intro line kept across the range.' '' 'Second paragraph, kept across the range.' '' 'Divergence clause, OLD wording.'
  } > "$SOV"
  git -C "$SC" add -A && git -C "$SC" commit -qm consumer
  st_diff="$(git -C "$SD" diff "$STW" "$STS" -- core/skills/ai-dlc/SKILL.md)"
  [ -n "$SB" ] && [ -n "$STS" ] && [ -n "$STW" ] && [ "$STS" != "$STW" ] \
    && [ "$(grep -c '^[-+][^-+]' <<<"$st_diff")" = 1 ] \
    && grep -q '^+READ AND FOLLOW `rule-bodies/rule-8.md`' <<<"$st_diff" \
    || { echo "FIXTURE ERROR: the pointer-stub world did not build its two theirs one line apart" >&2; exit 2; }
  sov0="$(git hash-object "$SOV")"
  cp "$SOV" "$SW/ovr.pristine" || { echo "FIXTURE ERROR: cannot keep the override" >&2; exit 2; }
  stub_ro() { # <theirs> <args...> -> $SW/ro.out (stdout+stderr), $SW/ro.rc; each run starts from the pristine entry
    local _t="$1"; shift
    cp "$SW/ovr.pristine" "$SOV" || { echo "FIXTURE ERROR: cannot restore the override" >&2; exit 2; }
    bash "$READOPT" "$SD" "$_t" "$SC" "$SOV" "$@" > "$SW/ro.out" 2>&1; echo "$?" > "$SW/ro.rc"
  }

  # layer-drift: the row on the stub theirs, none on the twin (whose own drift row is the positive conjunct).
  bash "$DRIFT" "$SD" "$SB" "$STS" "$SC" > "$SW/ld-stub.out" 2>&1
  bash "$DRIFT" "$SD" "$SB" "$STW" "$SC" > "$SW/ld-twin.out" 2>&1
  if [ -n "$(awk -F'\t' '$1 == "OVERRIDE-SHADOWS-POINTER-STUB" && $2 ~ /SKILL__Rule-8\.md$/' "$SW/ld-stub.out")" ] \
     && grep -q 'rule-bodies/rule-8.md' "$SW/ld-stub.out"; then
    ok "stub-ld: layer-drift reports OVERRIDE-SHADOWS-POINTER-STUB on an override whose shadowed section is, at theirs, a load-pointer stub, naming rule-bodies/rule-8.md"
  else
    bad "stub-ld: no OVERRIDE-SHADOWS-POINTER-STUB row for the stub shadow: $(cut -f1,2 "$SW/ld-stub.out" | tr '\n\t' '| ' | cut -c1-300)"
  fi
  if [ -n "$(awk -F'\t' '$2 ~ /SKILL__Rule-8\.md$/' "$SW/ld-twin.out")" ] && ! grep -q 'OVERRIDE-SHADOWS-POINTER-STUB' "$SW/ld-twin.out"; then
    ok "stub-ld-twin: the twin (the same section without the pointer sentence) gets its drift row and no pointer-stub row"
  else
    bad "stub-ld-twin: twin rows: $(cut -f1,2 "$SW/ld-twin.out" | tr '\n\t' '| ' | cut -c1-300)"
  fi

  # readopt-override: --check BLOCKED on the stub; the twin's gate speaks without the stub row.
  stub_ro "$STS" --check
  if [ "$(cat "$SW/ro.rc")" = 1 ] && grep -q '^BLOCKED  SKILL__Rule-8.md: OVERRIDE-SHADOWS-POINTER-STUB ' "$SW/ro.out"; then
    ok "stub-check: --check exits 1 BLOCKED with OVERRIDE-SHADOWS-POINTER-STUB on the stub shadow"
  else
    bad "stub-check: --check rc=$(cat "$SW/ro.rc") out: $(head -3 "$SW/ro.out" | tr '\n' '|')"
  fi
  stub_ro "$STW" --check
  if grep -q 'STALE-CORE-TEXT' "$SW/ro.out" && ! grep -q 'OVERRIDE-SHADOWS-POINTER-STUB' "$SW/ro.out"; then
    ok "stub-check-twin: the twin's --check reads the stale divergence clause (STALE-CORE-TEXT), not the pointer stub"
  else
    bad "stub-check-twin: --check rc=$(cat "$SW/ro.rc") out: $(head -3 "$SW/ro.out" | tr '\n' '|')"
  fi

  # The refusals: rc 1, the row, and the override's bytes unchanged.
  for _m in "--merge" "--stamp readopt" "--stamp reaffirm --note kept-on-purpose"; do
    # shellcheck disable=SC2086
    stub_ro "$STS" $_m
    if [ "$(cat "$SW/ro.rc")" = 1 ] && grep -q '^REFUSED  SKILL__Rule-8.md: OVERRIDE-SHADOWS-POINTER-STUB ' "$SW/ro.out" \
       && [ "$(git hash-object "$SOV")" = "$sov0" ]; then
      ok "stub-refuse: $_m exits 1 REFUSED OVERRIDE-SHADOWS-POINTER-STUB and the override's bytes are unchanged"
    else
      bad "stub-refuse: $_m rc=$(cat "$SW/ro.rc") bytes-moved=$([ "$(git hash-object "$SOV")" = "$sov0" ] && echo no || echo yes) out: $(head -3 "$SW/ro.out" | tr '\n' '|')"
    fi
  done

  # pull.sh merge: the stub's refusal relayed, exit 3, no decision row; the twin merges and records its row.
  SDEC="$SC/_bmad-output/ai-dlc-update/pull-decisions.tsv"
  SOV_REL=.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md
  cp "$SW/ovr.pristine" "$SOV" || { echo "FIXTURE ERROR: cannot restore the override" >&2; exit 2; }
  bash "$REC_DIR/pull.sh" merge "$SD" "$SB" "$SC" "$STS" "$SOV_REL" > "$SW/pm.out" 2> "$SW/pm.err" < /dev/null; pm_rc=$?
  if [ "$pm_rc" = 3 ] && grep -q '^REFUSED  SKILL__Rule-8.md: OVERRIDE-SHADOWS-POINTER-STUB ' "$SW/pm.out" \
     && ! grep -q '^DECIDE ' "$SW/pm.out" && [ ! -e "$SDEC" ] && [ "$(git hash-object "$SOV")" = "$sov0" ]; then
    ok "stub-pull-merge: pull.sh merge relays the OVERRIDE-SHADOWS-POINTER-STUB refusal, exits 3, records no decision row and leaves the override's bytes"
  else
    bad "stub-pull-merge: rc=$pm_rc decisions-file=$([ -e "$SDEC" ] && echo present || echo absent) out: $(head -3 "$SW/pm.out" | tr '\n' '|') err: $(head -2 "$SW/pm.err" | tr '\n' '|')"
  fi
  cp "$SW/ovr.pristine" "$SOV" || { echo "FIXTURE ERROR: cannot restore the override" >&2; exit 2; }
  bash "$REC_DIR/pull.sh" merge "$SD" "$SB" "$SC" "$STW" "$SOV_REL" > "$SW/pmt.out" 2> "$SW/pmt.err" < /dev/null; pmt_rc=$?
  if [ "$pmt_rc" = 0 ] && grep -q '^DECIDE override-drift .claude/skills/ai-dlc/overrides/SKILL__Rule-8.md merged$' "$SW/pmt.out" \
     && grep -q '^override-drift	.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md	' "$SDEC" 2>/dev/null \
     && grep -q 'Divergence clause, NEW wording.' "$SOV" && grep -q 'Consumer intensity: service/ is FULL' "$SOV" \
     && ! grep -q 'OVERRIDE-SHADOWS-POINTER-STUB' "$SW/pmt.out" "$SW/pmt.err"; then
    ok "stub-pull-merge-twin: on the twin, pull.sh merge merges cleanly (theirs' clause in, the consumer line kept) and records its decision row"
  else
    bad "stub-pull-merge-twin: rc=$pmt_rc out: $(head -3 "$SW/pmt.out" | tr '\n' '|') err: $(head -2 "$SW/pmt.err" | tr '\n' '|')"
  fi

  # --stamp retire stays open on the stub: rc 0, RETIRED, the file gone.
  stub_ro "$STS" --stamp retire
  if [ "$(cat "$SW/ro.rc")" = 0 ] && grep -q '^RETIRED  SKILL__Rule-8.md' "$SW/ro.out" && [ ! -e "$SOV" ]; then
    ok "stub-retire: --stamp retire stays open on the stub shadow (rc 0, RETIRED, the entry deleted)"
  else
    bad "stub-retire: rc=$(cat "$SW/ro.rc") file=$([ -e "$SOV" ] && echo present || echo deleted) out: $(head -3 "$SW/ro.out" | tr '\n' '|')"
  fi
  rm -rf "$SW"
fi
fi
if sg gh; then
# ---------------------------------------------------------------------------
# G / H. THE OTHER DIRECTION OF THE SET DIFFERENCE, AND THE WRAP.
# ---------------------------------------------------------------------------
# Arms A-C test SUPERSEDED text: a line core DROPPED that the body still carries.
# That is one half of a two-sided question and shipping only it made the COMMONEST
# upstream change invisible — a purely ADDITIVE edit removes nothing, so the stale
# set is empty by construction, `--check` printed OK, and `--stamp readopt` then
# advanced base_sha, after which the next pull computes no drift on that section and
# never offers the new text again. Measured on the reference consumer's own
# `steps__retro__domain-sections.md` across `a5cbdf0b -> 95670e58`: the shipping gate
# exited 0 while five lines of core's rewritten `#4a. Close-Out Sweep` were absent
# from the body.
#
# THE TWO NEW GUARDS GET SUBJECTS THE OTHER CANNOT SEE. G's core change is a pure
# ADDITION (nothing deleted, so the stale arm has no input at all); H's is a pure
# DELETION (nothing added, so the unadopted arm has none). An arm that fired on both
# subjects would be reporting "this section moved", which every override in this
# fixture would trip.
G3="$ROOT/g3"; rm -rf "$G3"; mkdir -p "$G3"
GPRE="$(git -C "$DIST" rev-parse --short HEAD)"
python3 - "$DIST/core/skills/ai-dlc/SKILL.md" <<'GPY'
import sys
p = sys.argv[1]; s = open(p).read()
# PURE ADDITION to Rule 7 -- nothing removed.
s = s.replace("""## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.
""", """## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.

**Every rule-7 adjudication now records the deciding session id**, and a record
that carries no session id is rejected at the gate rather than queued.
""")
# PURE DELETION from Rule 13 -- nothing added.
s = s.replace("""The adjudication order, the freeze semantics, and the record format live here, in the
paragraphs an override of this rule silently drops.
""", "")
open(p, "w").write(s)
GPY
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "additive rule 7, deleted rule 13 paragraph" >/dev/null 2>&1
GTH="$(git -C "$DIST" rev-parse --short HEAD)"

GOVR="$CONS/.claude/skills/ai-dlc/overrides/G__additive.md"
cat > "$GOVR" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${GPRE}
reason: consumer keeps core's rule 7 and adds one project-specific sentence.
---

## Rule 7 -- Something Else

This consumer also records the adjudicating team, which core does not ask for.

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.
EOF
cp "$GOVR" "$G3/additive.orig"
# THE CONSUMER DELTA SITS AT THE TOP OF THE BODY ON PURPOSE. Upstream's addition lands
# at the END of the section, and a three-way merge of two edits to adjacent lines is a
# CONFLICT -- which the stamp then refuses on its markers, so the satisfiability arm
# below would be asserting the conflict path rather than the clean one and would pass
# for the wrong reason.

# THE NEAR-MISS, IN THE SAME RUN. Same anchor, same base_sha, same upstream change --
# and this body DID adopt it, re-wrapped at a different column. A whole-line test calls
# that absent, so this entry is what separates "the body lacks upstream's text" from
# "the body does not match upstream's line breaks".
GOK="$CONS/.claude/skills/ai-dlc/overrides/G__adopted.md"
cat > "$GOK" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${GPRE}
reason: consumer adopted the new clause and re-wrapped it.
---

## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.

**Every rule-7 adjudication now records the deciding session id**, and a record that
carries no session id is rejected at the gate rather than queued.
EOF

HOVR="$CONS/.claude/skills/ai-dlc/overrides/H__rewrap.md"
cat > "$HOVR" <<EOF
---
shadows: SKILL.md#Rule 13
base_sha: ${GPRE}
reason: consumer escalation rules; still carries core's deleted sentence, re-wrapped.
---

## Rule 13 -- Escalation (CONSUMER OVERRIDE)

Escalate at three failures rather than two.

The adjudication order, the freeze semantics, and the record format live
here, in the paragraphs an override of this rule silently
drops.
EOF

HOK="$CONS/.claude/skills/ai-dlc/overrides/H__clean.md"
cat > "$HOK" <<EOF
---
shadows: SKILL.md#Rule 13
base_sha: ${GPRE}
reason: consumer escalation rules, carrying none of core's superseded prose.
---

## Rule 13 -- Escalation (CONSUMER OVERRIDE)

Escalate at three failures rather than two. Nothing else from core's rule 13 is
reproduced here.
EOF

echo "== G. an ADDITIVE upstream change to a shadowed section is REPORTED =="
# THE TIER IS THE ASSERTION, and v0.476.0 got it wrong in the direction that loses data.
# This arm shipped as a REFUSAL and was demoted one release later: replayed over the 27
# re-adoptions in the reference consumer's own history, a refusing form refuses 7 of them,
# at least one demonstrably falsely -- a body that had ALREADY adopted upstream's addition,
# reworded. And the escape is worse than the wedge: `--stamp reaffirm --note` advances
# base_sha, so a falsely-refused re-adoption is re-stamped and the clause is never offered
# again, under a note asserting the consumer declined text it had in fact taken. So the arm
# must REPORT and must NOT refuse, and both halves are asserted here.
out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --check 2>&1)"; rc=$?
if grep -q 'UNADOPTED-CORE-TEXT' <<<"$out"; then
  ok "--check REPORTS: core ADDED text to the shadowed section and the body does not carry it"
else
  bad "--check did NOT report a purely additive upstream change (rc=$rc) -- the stale set is empty by construction, so this is the direction that reads as clean"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
if [ "$rc" -eq 0 ]; then
  ok "  and it does NOT fail: a REWORDED adoption scores here too, and refusing on that routes a correct re-adoption to reaffirm"
else
  bad "  --check exited $rc on an unadopted-only finding: that is the tier v0.477.0 removed, and it converts a false positive into a permanent re-stamp"
fi
if grep -q 'records the deciding session id' <<<"$out"; then
  ok "  and it names the un-adopted sentence verbatim"
else
  bad "  it reported but did not identify the un-adopted line, so the operator cannot act on it"
fi

before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$GOVR" | head -1)"
out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$GOVR" | head -1)"
if [ "$rc" -eq 0 ] && grep -q 'UNADOPTED-CORE-TEXT' <<<"$out"; then
  ok "--stamp readopt LANDS and says what was not adopted -- the operator decides, having been told"
else
  bad "--stamp readopt exited $rc or said nothing about the unadopted lines: either it refuses (v0.476.0's defect) or it is silent (the defect that release fixed)"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
# THE VALUE, NOT THE EXIT CODE. An arm reading only the exit code passes against an
# implementation that reports and does NOT stamp, and against one that stamps silently.
if [ "$after_sha" = "$GTH" ] && [ "$before_sha" != "$after_sha" ]; then
  ok "  and base_sha advanced $before_sha -> $after_sha, so the stamp is a real one"
else
  bad "  base_sha is $after_sha (was $before_sha, theirs is $GTH): the stamp did not land"
fi

gok_out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOK" --check 2>&1)"
if ! grep -q 'UNADOPTED-CORE-TEXT' <<<"$gok_out"; then
  ok "NEAR-MISS: a body that adopted the same addition RE-WRAPPED is not reported at all"
else
  bad "NEAR-MISS FAILED: a body carrying upstream's new text at a different column is reported as un-adopted -- the arm is testing line breaks, not content"
  printf '%s\n' "$gok_out" | sed 's/^/    /'
fi

# SATISFIABILITY. A gate that cannot be cleared by the remedy it prints is a wedge, and
# `--merge` is that remedy. Assert the whole round trip, ending in the stamp actually
# landing -- asserting only the refusal would pass against a guard that refuses always.
cp "$G3/additive.orig" "$GOVR"
bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --merge >/dev/null 2>&1
if bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --check >/dev/null 2>&1; then
  ok "  --merge clears it: the body carries the addition and --check goes green"
else
  bad "  --merge did NOT clear the new gate -- the remedy the message prints cannot satisfy it"
  bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --check 2>&1 | sed 's/^/    /'
fi
if bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --stamp readopt >/dev/null 2>&1 \
   && [ "$(sed -n 's/^base_sha:[[:space:]]*//p' "$GOVR" | head -1)" = "$GTH" ]; then
  ok "  and the stamp then LANDS, advancing base_sha to $GTH"
else
  bad "  the stamp still refused after a clean merge, or base_sha did not advance to $GTH"
fi

# THE FRONTMATTER IS NOT THE BODY. `reason:` is prose ABOUT the override, and the natural
# way to decline an upstream clause is to quote it there — so a containment test that reads
# the whole file scores the clause as ADOPTED on the entry that says, in as many words, that
# it did not adopt it. That is a false clean produced by the remedy text itself. Its ALLOW
# twin is the same clause in the body, in the same run: without that half this arm passes for
# an implementation that reads neither.
GFM="$CONS/.claude/skills/ai-dlc/overrides/G__reason-only.md"
cat > "$GFM" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${GPRE}
reason: consumer rule 7. Upstream now says **Every rule-7 adjudication now records the deciding session id**, and a record that carries no session id is rejected at the gate rather than queued. This consumer declines it.
---

## Rule 7 -- Something Else

This consumer also records the adjudicating team, which core does not ask for.

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.
EOF
if grep -q 'UNADOPTED-CORE-TEXT' <<<"$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GFM" --check 2>&1)"; then
  ok "  and core text quoted in \`reason:\` does NOT count as adoption: only the body the lead reads can carry it"
else
  bad "an entry carrying core's new clause only in its \`reason:\` — to say it DECLINES it — was scored as having adopted it, so the report is silenced by the sentence that says it was not"
fi

# THE SECOND PASTE TARGET, and the frontmatter fix left it open for a release. Upstream text
# dropped into an HTML comment INSIDE the body reaches no lead either, so it is not adoption.
# Its ALLOW twin is the same clause as real body prose, asserted in the near-miss above.
GHC="$CONS/.claude/skills/ai-dlc/overrides/G__comment-only.md"
{ cat "$G3/additive.orig"; printf '\n<!--\n**Every rule-7 adjudication now records the deciding session id**, and a record\nthat carries no session id is rejected at the gate rather than queued.\n-->\n'; } > "$GHC"
if grep -q 'UNADOPTED-CORE-TEXT' <<<"$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GHC" --check 2>&1)"; then
  ok "  and core text pasted into an HTML COMMENT in the body does not count either"
else
  bad "core text inside <!-- --> scored as adoption -- the report prints the offending lines verbatim, so the tool emits the exact text that silences it"
fi
rm -f "$GFM" "$GHC"

echo "== H. the body test is WRAP-INSENSITIVE in the superseded direction too =="
out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$HOVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--check RED: a superseded core sentence carried at a DIFFERENT wrap is still found"
else
  bad "--check missed a superseded sentence the body demonstrably carries, re-wrapped (rc=$rc) -- and an override of a consumer-rewritten section is a re-wrap by definition"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
if bash "$READOPT" "$DIST" "$GTH" "$CONS" "$HOK" --check >/dev/null 2>&1; then
  ok "CONTROL: a body carrying none of the superseded prose stays green"
else
  bad "CONTROL FAILED: an override reproducing no core text was reported -- the containment test matches anything"
fi

rm -f "$GOK" "$HOVR" "$HOK"

fi
if sg j; then
# ---------------------------------------------------------------------------
# J. UPSTREAM RE-FLOWED A PARAGRAPH, AND A FAITHFUL ADOPTION MUST NOT BE REFUSED.
# ---------------------------------------------------------------------------
# Arms A-H all change WORDS. This one changes only LINE BREAKS on the core side: the
# same sentences, re-wrapped so that a base line survives at theirs as the SUFFIX of
# a longer line. A whole-line set difference scores that base line as DELETED, and a
# body that adopted theirs faithfully still CONTAINS it (it contains the whole longer
# line), so the superseded gate refuses exactly the state it exists to certify.
# Measured on the reference consumer's `steps__gate-validation__check-20.md` across
# `eb49b783 -> a798e215`: --merge 1 merged / 0 conflicted, all 38 substantive theirs
# lines carried, --stamp readopt REFUSED on one suffix line, and the only stamp left
# was `reaffirm`, which recorded a re-adoption under the wrong outcome name.
#
# THREE SUBJECTS, AND THE NEAR-MISS CARRIES THE PROPERTY THE FEARED REGRESSION KEYS ON.
# JOK adopted theirs verbatim (must pass). JBAD adopted theirs' re-flow AND still carries
# a sentence theirs genuinely DROPPED (must refuse, naming that sentence and NOT the
# re-flowed one). A fix that simply stopped looking at the base side would pass JOK and
# miss JBAD's dropped sentence; a fix keyed on "line count unchanged" would pass JOK and
# call JBAD clean too. JBAD's dropped sentence sits in a DIFFERENT paragraph from the
# re-flow so neither guard covers the other's subject.
J3="$ROOT/j3"; rm -rf "$J3"; mkdir -p "$J3"
JPRE="$(git -C "$DIST" rev-parse --short HEAD)"
python3 - "$DIST/core/skills/ai-dlc/SKILL.md" <<'JPY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """## Rule 14 -- Budget

Shadowed by an override whose survival claim is about the rest of the FILE, which is
TRUE for a single-section shadow. The control for the noun restriction.
"""
assert old in s, "rule 14 seed text moved; re-anchor arm J"
# RE-FLOW ONLY: the second base line becomes the SUFFIX of a longer theirs line, and
# the first base line is split. Every word survives; no whole base line does.
# Then a SEPARATE paragraph is DROPPED (the genuinely superseded sentence JBAD keeps).
new = """## Rule 14 -- Budget

Shadowed by an override whose survival claim is about the rest of the FILE, which is TRUE
for a single-section shadow. The control for the noun restriction.
"""
s = s.replace(old, new)
old2 = """The ordering guarantee and the retention window live here, in the paragraphs that entry
silently drops.
"""
assert old2 in s, "rule 16 seed text moved; re-anchor arm J"
s = s.replace(old2, "")
# NEGATED IN PLACE: the base rule-15 line survives at theirs as the SUFFIX of one longer
# line whose meaning is the opposite. Bare containment acquits a body carrying only the
# old line; that is the false pass an adversarial hand measured on the first cut.
old3 = """Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
"""
assert old3 in s, "rule 15 seed text moved; re-anchor arm J"
s = s.replace(old3, """Never Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
""")
open(p, "w").write(s)
JPY
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "re-flow rule 14, drop a rule 16 paragraph" >/dev/null 2>&1
JTH="$(git -C "$DIST" rev-parse --short HEAD)"
# The seed must actually be a re-flow: no base Rule 14 line survives whole at theirs, and
# every base line's words are contained in theirs' flattened section. Without this the arm
# would be asserting an ordinary rewrite, which arm A already covers.
j_base_lines="$(git -C "$DIST" show "${JPRE}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 14/{f=1;next} /^## /{f=0} f && length($0)>24')"
j_theirs_lines="$(git -C "$DIST" show "${JTH}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 14/{f=1;next} /^## /{f=0} f && length($0)>24')"
j_theirs_flat="$(printf '%s\n' "$j_theirs_lines" | tr '\n' ' ' | tr -s ' ')"
j_whole=0; j_contained=0; j_n=0
while IFS= read -r l; do
  [ -n "$l" ] || continue; j_n=$((j_n+1))
  grep -qxF -- "$l" <<<"$j_theirs_lines" && j_whole=$((j_whole+1))
  case "$j_theirs_flat" in *"$l"*) j_contained=$((j_contained+1));; esac
done <<<"$j_base_lines"
if [ "$j_n" -ge 2 ] && [ "$j_whole" -eq 0 ] && [ "$j_contained" -eq "$j_n" ]; then
  ok "SEED: rule 14 is a pure RE-FLOW -- $j_n base lines, 0 survive whole at theirs, $j_n contained in theirs' flattened section"
else
  bad "SEED: rule 14 is not a re-flow (lines=$j_n whole=$j_whole contained=$j_contained) -- arm J would be asserting an ordinary rewrite"
fi

JOK="$CONS/.claude/skills/ai-dlc/overrides/J__reflow-adopted.md"
cat > "$JOK" <<EOF
---
shadows: SKILL.md#Rule 14
base_sha: ${JPRE}
reason: consumer budget ceiling; body carries core's rule 14 at theirs verbatim.
---

## Rule 14 -- Budget

This consumer raises the budget ceiling.

Shadowed by an override whose survival claim is about the rest of the FILE, which is TRUE
for a single-section shadow. The control for the noun restriction.
EOF

JBAD="$CONS/.claude/skills/ai-dlc/overrides/J__reflow-plus-dropped.md"
cat > "$JBAD" <<EOF
---
shadows: SKILL.md#Rule 14, SKILL.md#Rule 16
base_sha: ${JPRE}
reason: consumer budget and record format; adopted the re-flow, still carries a sentence core dropped.
---

## Rule 14 -- Budget

This consumer raises the budget ceiling.

Shadowed by an override whose survival claim is about the rest of the FILE, which is TRUE
for a single-section shadow. The control for the noun restriction.

## Rule 16 -- Recording

Multi-paragraph, shadowed by an override whose survival claim WRAPS across a newline --
the shape that returns a false zero to any line-based predicate.

The ordering guarantee and the retention window live here, in the paragraphs that entry
silently drops.
EOF

# NEGATED IN PLACE. Base rule 15 permits; theirs prepends `Never`, so the old line is a
# strict SUFFIX of the new one. JNEG carries only the OLD line and must be refused naming
# it; JNEGOK carries theirs' line and must pass. Bare containment acquits JNEG, because
# the old line's words are in theirs; what separates the two is that JNEGOK's body carries
# the theirs text holding those words and JNEG's does not.
JNEG="$CONS/.claude/skills/ai-dlc/overrides/J__negated-kept.md"
cat > "$JNEG" <<EOF
---
shadows: SKILL.md#Rule 15
base_sha: ${JPRE}
reason: consumer gating; still teaches the rule core inverted.
---

## Rule 15 -- Gating

This consumer gates at two failures.

Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
EOF
JNEGOK="$CONS/.claude/skills/ai-dlc/overrides/J__negated-adopted.md"
cat > "$JNEGOK" <<EOF
---
shadows: SKILL.md#Rule 15
base_sha: ${JPRE}
reason: consumer gating; adopted core's inverted rule.
---

## Rule 15 -- Gating

This consumer gates at two failures.

Never Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
EOF
# The seed must be a NEGATION IN PLACE: the base line's words survive INSIDE one theirs
# line and not as a whole line. The first cut lowercased a letter after `Never`, so the
# base line was not contained at all and every implementation refused JNEG, so this
# assertion is what separates a real negation-in-place from a lowercased one.
jn_base="Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and"
jn_theirs="$(git -C "$DIST" show "${JTH}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 15/{f=1;next} /^## /{f=0} f' | tr -s ' ')"
if ! grep -qxF -- "$jn_base" <<<"$jn_theirs" && grep -qF -- "$jn_base" <<<"$jn_theirs"; then
  ok "SEED: the rule 15 base line survives at theirs INSIDE a longer line and not as a whole line"
else
  bad "SEED: the rule 15 base line is not a negation-in-place at theirs -- the JNEG arm below cannot discriminate"
fi

echo "== J. a RE-FLOWED core paragraph, faithfully adopted, is not superseded text =="
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JOK" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--check OK: a body carrying theirs' re-flowed paragraph verbatim is not refused"
else
  bad "--check refused a faithful adoption of a RE-FLOWED paragraph (rc=$rc) -- the suffix false positive: the only stamp left is reaffirm, which records a readopt under the wrong name"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JOK" | head -1)"
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JOK" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JOK" | head -1)"
if [ "$rc" -eq 0 ] && [ "$after_sha" = "$JTH" ]; then
  ok "--stamp readopt LANDS on it ($before_sha -> $after_sha)"
else
  bad "--stamp readopt REFUSED a faithful re-flow adoption (rc=$rc, base_sha $before_sha -> $after_sha)"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JBAD" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out" && grep -q 'retention window live here' <<<"$out"; then
  ok "NEAR-MISS: the same re-flow adopted PLUS a sentence core genuinely dropped is still refused, naming the dropped sentence"
else
  bad "NEAR-MISS: a body still carrying a sentence core DROPPED was not refused, or the refusal did not name it (rc=$rc) -- containment has swallowed the superseded direction"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
if ! grep -q 'noun restriction' <<<"$out"; then
  ok "  and the re-flowed rule 14 line is NOT among the lines it names"
else
  bad "  the refusal names the RE-FLOWED line as superseded -- the false positive is back, hiding behind a true one"
fi
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JNEG" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out" && grep -q 'survival vocabulary names a DIFFERENT unit' <<<"$out"; then
  ok "NEGATED IN PLACE: a body carrying only the line core prefixed with Never is REFUSED, naming it"
else
  bad "NEGATED IN PLACE: a body teaching the rule core INVERTED was not refused (rc=$rc) -- bare containment acquitted it because the old words survive inside the new line"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JNEGOK" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "  and a body carrying core's Never line passes -- the same words, in the context theirs gives them"
else
  bad "  a body that adopted the inverted line was refused (rc=$rc) -- the narrowing overshot and refuses a faithful adoption"
  printf '%s\n' "$out" | sed 's/^/    /'
fi

rm -f "$JOK" "$JBAD" "$JNEG" "$JNEGOK"

# CROSS-SECTION RE-FLOW (BL-1197). One override shadows two sections, A (Rule 18) and B (Rule 19).
# Between base and theirs a base line standalone in A is DELETED there and reappears as the tail
# of a LONGER line in B -- the shape a consumer measured when a rule's closing line moved from one
# numbered section to a later one. KTH carries the moved line faithfully; NTH carries the same
# line behind `Never `, so its meaning is inverted. Both are built on JTH, so the arms above are
# untouched.
JKL="Unchanged base..theirs, so the entry stays OVERRIDE-OK and the unclaimed row cannot be"
# NTH also negates a SECOND line, JL2, IN ITS OWN section (rule 18), while rule 19 holds JL2's words
# inside a longer line the body carries: the other section's carrier must not acquit it.
JL2="Claimed by ONE entry whose body carries a SECOND same-level section that no anchor names."
JL2X="Cross-reference, unchanged in force: ${JL2}"
for JKV in plain never; do
  python3 - "$DIST/core/skills/ai-dlc/SKILL.md" "$JKV" "$JKL" "$JL2" "$JL2X" <<'JKPY'
import sys
p, kind, line, l2, l2x = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
s = open(p).read()
assert s.count(line + "\n") == 1, "rule 18 seed text moved; re-anchor the cross-section arm"
s = s.replace(line + "\n", "")
head = "## Rule 19 -- Sweep\n\n"
assert head in s, "rule 19 seed text moved; re-anchor the cross-section arm"
pre = "Close-out rule moved here: " if kind == "plain" else "Never close-out rule moved here: "
s = s.replace(head, head + pre + line + "\n", 1)
if kind != "plain":
    assert s.count(l2 + "\n") == 1, "rule 18 first line moved; re-anchor the own-section negation"
    s = s.replace(l2 + "\n", "Never " + l2 + "\n")
    s = s.replace(head, head + l2x + "\n", 1)
open(p, "w").write(s)
JKPY
  git -C "$DIST" add -A >/dev/null 2>&1
  git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "move a rule 18 line into rule 19 ($JKV)" >/dev/null 2>&1
  if [ "$JKV" = plain ]; then
    JKTH="$(git -C "$DIST" rev-parse --short HEAD)"
    git -C "$DIST" checkout -q --detach "$JTH" >/dev/null 2>&1
  else
    JNTH="$(git -C "$DIST" rev-parse --short HEAD)"
  fi
done
# SEED: at KTH and at NTH the line is absent whole and uncontained in section A, and contained
# (not whole) in section B. Without this the arms below could pass or fail on an ordinary rewrite.
jk_ok=1
for jk_sha in "$JKTH" "$JNTH"; do
  jk_a="$(git -C "$DIST" show "${jk_sha}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 18/{f=1;next} /^## /{f=0} f' | tr '\n' ' ' | tr -s ' ')"
  jk_b_lines="$(git -C "$DIST" show "${jk_sha}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 19/{f=1;next} /^## /{f=0} f')"
  jk_b="$(printf '%s\n' "$jk_b_lines" | tr '\n' ' ' | tr -s ' ')"
  jk_pre="$(git -C "$DIST" show "${JPRE}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 18/{f=1;next} /^## /{f=0} f' | tr '\n' ' ' | tr -s ' ')"
  case "$jk_pre" in *"$JKL"*) ;; *) jk_ok=0 ;; esac
  case "$jk_a" in *"$JKL"*) jk_ok=0 ;; esac
  grep -qxF -- "$JKL" <<<"$jk_b_lines" && jk_ok=0
  case "$jk_b" in *"$JKL"*) ;; *) jk_ok=0 ;; esac
done
if [ "$jk_ok" -eq 1 ] && [ "$JKTH" != "$JNTH" ] && [ -n "$JKTH" ] && [ -n "$JNTH" ]; then
  ok "SEED: the rule 18 line is in base section A, absent whole and uncontained in theirs' A, contained (not whole) in theirs' B -- at both the faithful and the negated theirs"
else
  bad "SEED: the rule 18 line did not cross sections (ok=$jk_ok kth=$JKTH nth=$JNTH) -- the cross-section arms below cannot discriminate"
fi

# SWAP. One theirs commit moves a Rule 18 line X into a longer Rule 19 line AND a Rule 19 line Y
# into a longer Rule 18 line. Each anchor's call then has to look in the OTHER section, and the
# two calls need different others, so a flat cached by the first anchor's call and reused by the
# second reads the wrong section and the stamp refuses. A single move cannot show that: only one
# anchor's call ever fills the cache.
JRL="The near-miss for the same arm: its override nests a sub-heading INSIDE the claimed section."
git -C "$DIST" checkout -q --detach "$JTH" >/dev/null 2>&1
python3 - "$DIST/core/skills/ai-dlc/SKILL.md" "$JRL" "$JKL" <<'JRPY'
import sys
p, y, x = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert s.count(y + "\n") == 1, "rule 19 seed text moved; re-anchor the swap cross-section arm"
assert s.count(x + "\n") == 1, "rule 18 seed text moved; re-anchor the swap cross-section arm"
s = s.replace(y + "\n", "").replace(x + "\n", "")
h18 = "## Rule 18 -- Close-Out\n\n"
h19 = "## Rule 19 -- Sweep\n\n"
assert h18 in s and h19 in s, "rule 18/19 headings moved; re-anchor the swap cross-section arm"
s = s.replace(h18, h18 + "Sweep rule moved here: " + y + "\n", 1)
s = s.replace(h19, h19 + "Close-out rule moved here: " + x + "\n", 1)
open(p, "w").write(s)
JRPY
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "swap a line between rule 18 and rule 19" >/dev/null 2>&1
JRTH="$(git -C "$DIST" rev-parse --short HEAD)"
jr_sec() { # <sha> <rule number> -> the section's lines
  git -C "$DIST" show "${1}:core/skills/ai-dlc/SKILL.md" | awk -v h="## Rule $2 " 'index($0,h)==1{f=1;next} /^## /{f=0} f'
}
jr_flat() { tr '\n' ' ' | tr -s ' '; }
jr_ok=1
for jr_pair in "$JKL|18|19" "$JRL|19|18"; do
  jr_l="${jr_pair%%|*}"; jr_rest="${jr_pair#*|}"; jr_from="${jr_rest%%|*}"; jr_to="${jr_rest#*|}"
  jr_pre_f="$(jr_sec "$JPRE" "$jr_from" | jr_flat)"
  jr_th_f="$(jr_sec "$JRTH" "$jr_from" | jr_flat)"
  jr_to_lines="$(jr_sec "$JRTH" "$jr_to")"
  jr_to_f="$(printf '%s\n' "$jr_to_lines" | jr_flat)"
  case "$jr_pre_f" in *"$jr_l"*) ;; *) jr_ok=0 ;; esac
  case "$jr_th_f" in *"$jr_l"*) jr_ok=0 ;; esac
  grep -qxF -- "$jr_l" <<<"$jr_to_lines" && jr_ok=0
  case "$jr_to_f" in *"$jr_l"*) ;; *) jr_ok=0 ;; esac
done
if [ "$jr_ok" -eq 1 ]; then
  ok "SEED: a rule 18 line moved INTO rule 19 and a rule 19 line moved INTO rule 18 in one theirs -- each absent and uncontained in the section it left, contained (not whole) in the other"
else
  bad "SEED: the swap did not cross sections both ways (ok=$jr_ok) -- the swap arm cannot discriminate"
fi
JXREV="$CONS/.claude/skills/ai-dlc/overrides/J__cross-reverse-adopted.md"
cat > "$JXREV" <<EOF
---
shadows: SKILL.md#Rule 18, SKILL.md#Rule 19
base_sha: ${JPRE}
reason: consumer close-out; body carries core's text at theirs verbatim, both swapped lines included.
---

## Rule 18 -- Close-Out

Sweep rule moved here: ${JRL}
Claimed by ONE entry whose body carries a SECOND same-level section that no anchor names.
mistaken for a drift row.

## Rule 19 -- Sweep

Close-out rule moved here: ${JKL}
A heading-set difference would report that child; a span-based claim does not.
EOF

JXOK="$CONS/.claude/skills/ai-dlc/overrides/J__cross-adopted.md"
cat > "$JXOK" <<EOF
---
shadows: SKILL.md#Rule 18, SKILL.md#Rule 19
base_sha: ${JPRE}
reason: consumer close-out; body carries core's text at theirs verbatim, the moved line included.
---

## Rule 18 -- Close-Out

Claimed by ONE entry whose body carries a SECOND same-level section that no anchor names.
mistaken for a drift row.

## Rule 19 -- Sweep

Close-out rule moved here: ${JKL}
The near-miss for the same arm: its override nests a sub-heading INSIDE the claimed section.
A heading-set difference would report that child; a span-based claim does not.
EOF
JXNEG="$CONS/.claude/skills/ai-dlc/overrides/J__cross-negated-kept.md"
cat > "$JXNEG" <<EOF
---
shadows: SKILL.md#Rule 18, SKILL.md#Rule 19
base_sha: ${JPRE}
reason: consumer close-out; still carries the old standalone line, not the inverted carrier theirs holds.
---

## Rule 18 -- Close-Out

Claimed by ONE entry whose body carries a SECOND same-level section that no anchor names.
${JKL}
mistaken for a drift row.

## Rule 19 -- Sweep

${JL2X}
The near-miss for the same arm: its override nests a sub-heading INSIDE the claimed section.
A heading-set difference would report that child; a span-based claim does not.
EOF
# SEED for the second shape: at NTH rule 18 holds JL2 only inside its Never line, the body does not
# carry that line, and rule 19 holds JL2 inside a longer line the body DOES carry.
jl_a_lines="$(git -C "$DIST" show "${JNTH}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 18/{f=1;next} /^## /{f=0} f')"
jl_b_lines="$(git -C "$DIST" show "${JNTH}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 19/{f=1;next} /^## /{f=0} f')"
jl_body="$(tr '\n' ' ' < "$JXNEG" | tr -s ' ')"
jl_ok=1
grep -qxF -- "Never ${JL2}" <<<"$jl_a_lines" || jl_ok=0
grep -qxF -- "$JL2" <<<"$jl_a_lines" && jl_ok=0
grep -qxF -- "$JL2X" <<<"$jl_b_lines" || jl_ok=0
grep -qxF -- "$JL2" <<<"$jl_b_lines" && jl_ok=0
case "$jl_body" in *"Never ${JL2}"*) jl_ok=0 ;; esac
case "$jl_body" in *"$JL2X"*) ;; *) jl_ok=0 ;; esac
if [ "$jl_ok" -eq 1 ]; then
  ok "SEED: theirs' rule 18 holds the second line only inside its Never line (the body does not carry it) and rule 19 holds it inside a longer line the body carries"
else
  bad "SEED: the own-section negation shape is not seeded (ok=$jl_ok) -- the second half of the NEGATED ELSEWHERE arm cannot discriminate"
fi

echo "== K. a line RE-FLOWED ACROSS SECTIONS, faithfully adopted, is not superseded text =="
before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JXOK" | head -1)"
out="$(bash "$READOPT" "$DIST" "$JKTH" "$CONS" "$JXOK" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JXOK" | head -1)"
if [ "$rc" -eq 0 ] && [ "$after_sha" = "$JKTH" ] && ! grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--stamp readopt LANDS when a base line moved from one shadowed section to the tail of a longer line in another ($before_sha -> $after_sha)"
else
  bad "--stamp readopt REFUSED a faithful cross-section re-flow (rc=$rc, base_sha $before_sha -> $after_sha)"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
out="$(bash "$READOPT" "$DIST" "$JNTH" "$CONS" "$JXNEG" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out" && grep -qF -- "$JKL" <<<"$out"; then
  ok "NEGATED ELSEWHERE: a body carrying only the old line, while theirs' other section holds it behind Never, is REFUSED naming it"
else
  bad "NEGATED ELSEWHERE: a body teaching the rule core INVERTED in another section was not refused, or the line was not named (rc=$rc) -- the cross-section search acquitted it on containment alone"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
if [ "$rc" -eq 1 ] && grep -qF -- "$JL2" <<<"$out"; then
  ok "NEGATED IN OWN SECTION: the line theirs negated in its own section is REFUSED naming it, though another shadowed section's carrier holds its words"
else
  bad "NEGATED IN OWN SECTION: a line theirs negated in its own section was acquitted by another section's carrier (rc=$rc) -- the cross-section search overrode the own section's verdict"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JXREV" | head -1)"
out="$(bash "$READOPT" "$DIST" "$JRTH" "$CONS" "$JXREV" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JXREV" | head -1)"
if [ "$rc" -eq 0 ] && [ "$after_sha" = "$JRTH" ] && ! grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--stamp readopt LANDS when one line moved each way between the two shadowed sections ($before_sha -> $after_sha)"
else
  bad "--stamp readopt REFUSED a faithful two-way cross-section swap (rc=$rc, base_sha $before_sha -> $after_sha) -- state from the first anchor's call leaked into the second"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
rm -f "$JXOK" "$JXNEG" "$JXREV"

fi
rm -rf "$ROOT"
echo ""
report_end "$NAME"
