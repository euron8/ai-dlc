#!/usr/bin/env bash
# Receipt for BL-777: with no `cksum` on PATH, the recorded-PASS cache of `emit-report.sh --verify`
# could not build its key and missed SILENTLY, even with the cache armed. The fix refuses the key
# through the engine's own refusal channel, so an ARMED run names a cause on stderr, and an unarmed
# run is unchanged.
#
# One mktemp world: a bare dist (the cache refuses a non-bare one) and a consumer that is its own git
# toplevel, carrying NO layer-adjudication-register (layer-drift.sh calls cksum for a register, so a
# world with one would fail the render itself rather than the key). Driving the SHIPPING emit-report.sh:
#   discrimination: the shim PATH (symlinks to every tool on PATH, minus cksum) really lacks cksum and
#                   really has awk, sed, sort, git and shasum; the control PATH is the same shim plus a
#                   cksum link.
#   control:        armed, cksum present -> exit 0, no refusal prefix on stderr, and the record written.
#   subject:        armed, cksum absent  -> exit 0, the record untouched, and stderr carries the engine's
#                   refusal prefix followed by at least one character. The WORDS of the cause are not
#                   read, so any correct fix closes this.
#   unarmed:        stdout, stderr and exit with and without cksum are byte-identical.
# Exit 0 = the defect is fixed. Exit 1 = the armed cksum-less run named no cause, broke the render or
# touched the record, or the unarmed runs differ. Exit 2 = the world could not be built or the
# control did not hold (the receipt cannot discriminate). Exit 9 = the subject cannot be found.
# Usage: receipt-cksum-absent.sh [<reconcile dir>]  (the argument is for scoring copies; default: shipped)
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset EMIT_REPORT_VERIFY_CACHE
R="$(cd "$(dirname "$0")/../../.." && pwd)"
REC="${1:-}"
if [ -z "$REC" ]; then
  REC="$R/core/skills/ai-dlc-update/reconcile"; [ -f "$REC/emit-report.sh" ] || REC="$R/.claude/skills/ai-dlc-update/reconcile"
fi
[ -f "$REC/emit-report.sh" ] || { echo "receipt: subject absent" >&2; exit 9; }
MARK='emit-report: recorded PASS refused, re-rendering: '
W="$(mktemp -d "${TMPDIR:-/tmp}/ra-cksum.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT

# --- the shim PATHs: every PATH entry's tools as symlinks, first wins, cksum left out ---
NOCK="$W/nock"; WITHCK="$W/withck"; mkdir -p "$NOCK" "$WITHCK" || exit 2
_ifs="$IFS"; IFS=:
for _d in $PATH; do
  IFS="$_ifs"
  [ -d "$_d" ] || continue
  for _t in "$_d"/*; do
    _n="${_t##*/}"
    [ -x "$_t" ] && [ ! -d "$_t" ] || continue
    [ "$_n" = cksum ] && continue
    [ -e "$NOCK/$_n" ] || [ -L "$NOCK/$_n" ] || ln -s "$_t" "$NOCK/$_n" 2>/dev/null
  done
done
IFS="$_ifs"
CK="$(command -v cksum)" || { echo "receipt: no cksum on this box to build the control from" >&2; exit 2; }
for _t in "$NOCK"/*; do ln -s "$(readlink "$_t")" "$WITHCK/${_t##*/}" 2>/dev/null; done
ln -s "$CK" "$WITHCK/cksum" || exit 2
# discrimination, under the exact PATHs the runs use
PATH="$NOCK" command -v cksum >/dev/null 2>&1 && { echo "receipt: the cksum-less PATH still resolves cksum" >&2; exit 2; }
PATH="$WITHCK" command -v cksum >/dev/null 2>&1 || { echo "receipt: the control PATH does not resolve cksum" >&2; exit 2; }
for _t in awk sed sort git shasum bash; do
  PATH="$NOCK" command -v "$_t" >/dev/null 2>&1 || { echo "receipt: the cksum-less PATH lacks $_t" >&2; exit 2; }
done
BASH_BIN="$(command -v bash)" || exit 2

# --- the world ---
DW="$W/dist-work"; D="$W/dist.git"; C="$W/consumer"
mkdir -p "$DW/core/schemas" "$C/.claude/schemas" "$C/_bmad-output/ai-dlc-update" || exit 2
g() { git -C "$DW" -c user.email=r@r -c user.name=receipt "$@"; }
printf '{\n  "rule": "original"\n}\n' > "$DW/core/schemas/thing.json"
g init -q && g add -A && g commit -q -m base || exit 2; B="$(git -C "$DW" rev-parse HEAD)" || exit 2
printf '{\n  "rule": "original", "theirs": 1\n}\n' > "$DW/core/schemas/thing.json"
g add -A && g commit -q -m theirs || exit 2; T="$(git -C "$DW" rev-parse HEAD)" || exit 2
git clone -q --mirror "$DW" "$D" >/dev/null 2>&1 || exit 2
printf '{\n  "rule": "original"\n}\n' > "$C/.claude/schemas/thing.json"
printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$C/.claude/.ai-dlc-version"
{ git -C "$C" init -q && git -C "$C" add -A \
  && git -C "$C" -c user.email=r@r -c user.name=receipt commit -q -m consumer; } >/dev/null 2>&1 || exit 2
[ -e "$C/_bmad-output/ai-dlc-update/layer-adjudication-register.md" ] && exit 2
RPT="$C/_bmad-output/ai-dlc-update/reconcile-report.md"
RECORD="$(git -C "$C" rev-parse --absolute-git-dir)/ai-dlc-verify-pass" || exit 2
{ printf '# report\n\n'; "$BASH_BIN" "$REC/emit-report.sh" "$D" "$B" "$C" "$T" 2>/dev/null; } > "$RPT"
grep -q 'BEGIN GENERATED: reconcile-mechanical' "$RPT" || exit 2
# run <tag> <shim> [armed] -- one --verify; writes <tag>.out/.err/.rc
run() {
  if [ -n "${3:-}" ]; then
    env EMIT_REPORT_VERIFY_CACHE=1 PATH="$2" "$BASH_BIN" "$REC/emit-report.sh" --verify "$RPT" "$D" "$B" "$C" "$T" \
      > "$W/$1.out" 2> "$W/$1.err"
  else
    env PATH="$2" "$BASH_BIN" "$REC/emit-report.sh" --verify "$RPT" "$D" "$B" "$C" "$T" > "$W/$1.out" 2> "$W/$1.err"
  fi
  echo "$?" > "$W/$1.rc"
}

# --- control: armed, cksum present -> keys, records, no refusal ---
rm -f "$RECORD"
run ctl "$WITHCK" armed
[ "$(cat "$W/ctl.rc")" = 0 ] || { echo "receipt: the armed control --verify did not exit 0" >&2; exit 2; }
grep -qF "$MARK" "$W/ctl.err" && { echo "receipt: the armed control with cksum present printed a refusal" >&2; exit 2; }
[ -s "$RECORD" ] || { echo "receipt: the armed control with cksum present wrote no record" >&2; exit 2; }
cp "$RECORD" "$W/rec.keep" || exit 2

# --- subject: armed, cksum absent -> a fresh render that names a cause ---
run sub "$NOCK" armed
[ "$(cat "$W/sub.rc")" = 0 ] || { echo "cksum receipt: the armed cksum-less --verify did not exit 0" >&2; exit 1; }
cmp -s "$RECORD" "$W/rec.keep" || { echo "cksum receipt: the armed cksum-less run touched the record" >&2; exit 1; }
_lines="$(grep -F "$MARK" "$W/sub.err")" || _lines=""
_hit=0
while IFS= read -r _l; do
  case "$_l" in "$MARK"?*) _hit=1 ;; esac
done <<< "$_lines"
[ "$_hit" -eq 1 ] \
  || { echo "cksum receipt: the armed cksum-less run missed with no refusal cause on stderr" >&2; exit 1; }

# --- unarmed: byte-identical with and without cksum ---
run u.ck "$WITHCK"; run u.nock "$NOCK"
for _x in out err rc; do
  cmp -s "$W/u.ck.$_x" "$W/u.nock.$_x" || { echo "cksum receipt: the UNARMED run's $_x differs with cksum absent" >&2; exit 1; }
done
echo "cksum receipt: PASS"
