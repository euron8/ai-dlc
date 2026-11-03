#!/usr/bin/env bash
# BL-874 receipt. Usage: bash core/fixtures/backlog-receipt-binding/receipt-bl874.sh   (run from the repo root)
# Two subjects, both driven, never grepped:
#   (a) scripts/backlog-rotate.sh --check on a scratch repository whose VERSION is 0.995.0 and whose
#       CHANGELOG.md carries `## [0.995.0]` and `## [0.990.0]`: sha-less LANDED lines at v0.990.0
#       (a heading), v0.995.0 (VERSION) and v0.1000.0 (PENDING, numerically greater) are accepted
#       (exit 0); a ledger adding v0.991.0 (below VERSION, no heading) is refused (exit 2); and
#       `--check --apply` on v9.9.9 beside v0.995.0 keeps the PENDING v9.9.9 entry and moves only v0.995.0.
#   (b) scripts/validate-backlog-receipts.sh, SOURCED, its r11_judge called on a scratch repository:
#       a branch adding a LANDED line that names a pre-squash (commit-tree side) sha reads 1 failing
#       of 2 added, while the line naming the base sha (an ancestor) does not fail.
# 0 = both hold. 1 = either regressed. 9 = an anchor is absent (a subject file or r11_judge).
# 2 = the receipt could not run (no git-env seam, not at the distribution root).
set -uo pipefail
r874_seam() { # walk up from $1 for the git-env seam; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/lib/preamble.sh" ]; then printf '%s\n' "$d/core/fixtures/lib/preamble.sh"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
_PRE="$(r874_seam "$(cd "$(dirname "$0")" && pwd)")" || _PRE=""
[ -n "$_PRE" ] && [ -f "$_PRE" ] || { echo "REFUSED: no git-env seam core/fixtures/lib/preamble.sh above $0" >&2; exit 2; }
. "$_PRE"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ -f VERSION ] && [ -d core/fixtures ] || { echo "REFUSED: run from the distribution root" >&2; exit 2; }
ROOT="$(pwd)"
RT="$ROOT/scripts/backlog-rotate.sh"; VB="$ROOT/scripts/validate-backlog-receipts.sh"
[ -f "$RT" ] || { echo "ANCHOR ABSENT: $RT" >&2; exit 9; }
[ -f "$VB" ] || { echo "ANCHOR ABSENT: $VB" >&2; exit 9; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
g() { git -c user.email=r@local -c user.name=r "$@"; }

# (a) the rotator, in a copy of its root (it resolves its siblings beside itself).
A="$T/a"; mkdir -p "$A/scripts" "$A/core/skills/ai-dlc-update/reconcile" "$A/docs"
cp "$RT" "$ROOT/scripts/backlog-reverify.sh" "$ROOT/scripts/backlog-receipt-lib.sh" "$A/scripts/"
cp "$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh" "$A/core/skills/ai-dlc-update/reconcile/"
printf '0.995.0\n' > "$A/VERSION"
printf '# Changelog\n\n## [0.995.0] - x\n\n## [0.990.0] - x\n' > "$A/CHANGELOG.md"
( cd "$A" && git init -q . && git add -A && g commit -q -m s ) || { echo "REFUSED: scratch repository" >&2; exit 2; }
ent() { printf '## %s — c\n\nbody\n\n**LANDED (v%s).** Done.\n\nverify: manual\n\n' "$1" "$2"; }
{ printf '# P\n\n'; ent BL-1 0.990.0; ent BL-2 0.995.0; ent BL-3 0.1000.0; printf '## BL-9 — live\n\nb\n\nverify: manual\n'; } > "$A/docs/acc.md"
{ printf '# P\n\n'; ent BL-1 0.990.0; ent BL-4 0.991.0; printf '## BL-9 — live\n\nb\n\nverify: manual\n'; } > "$A/docs/ref.md"
bash "$A/scripts/backlog-rotate.sh" "$A/docs/acc.md" --check >/dev/null 2>&1; ra=$?
bash "$A/scripts/backlog-rotate.sh" "$A/docs/ref.md" --check >/dev/null 2>&1; rr=$?
fail=0
[ "$ra" -eq 0 ] || { echo "FAIL (a): sha-less lines at a heading, at VERSION and above VERSION were refused (exit $ra)" >&2; fail=1; }
[ "$rr" -eq 2 ] || { echo "FAIL (a): a sha-less line naming no release was not refused (exit $rr)" >&2; fail=1; }
# (a2) --apply keeps a PENDING line: v9.9.9 beside v0.995.0 (a heading VERSION has reached). Only BL-2
#      moves; BL-7 stays in the ledger and is reported PENDING.
mkdir "$A/p"; { printf '# P\n\n'; ent BL-7 9.9.9; ent BL-2 0.995.0; printf '## BL-9 — live\n\nb\n\nverify: manual\n'; } > "$A/p/backlog.md"
op="$(bash "$A/scripts/backlog-rotate.sh" "$A/p/backlog.md" --check --apply 2>&1)"; rp=$?
np="$(grep -c '^## BL-' "$A/p/backlog.archive.md" 2>/dev/null)" || np=0
if [ "$rp" -ne 0 ] || [ "$np" != 1 ] || ! grep -q '^## BL-7 ' "$A/p/backlog.md" || grep -q '^## BL-2 ' "$A/p/backlog.md" \
   || ! grep -qF 'BL-7  PENDING, not moved: v9.9.9 is not yet released (VERSION 0.995.0)' <<<"$op"; then
  echo "FAIL (a2): --check --apply did not keep the v9.9.9 PENDING entry and move only the released one (exit $rp, archive $np)" >&2; fail=1
fi

# (b) the validator's R11 judge, sourced.
B="$T/b"; mkdir -p "$B/docs"
printf '# p\n' > "$B/docs/backlog.md"
( cd "$B" && git init -q . && git add -A && g commit -q -m base ) || { echo "REFUSED: scratch repository" >&2; exit 2; }
base="$(git -C "$B" rev-parse HEAD)"; side="$(cd "$B" && g commit-tree "HEAD^{tree}" -p HEAD -m side)"
printf '# p\n\n## BL-5\n\n**LANDED (v0.0.1, verified %s).**\n\nverify: manual\n\n## BL-6\n\n**LANDED (v0.0.2, verified %s).**\n\nverify: manual\n' "$base" "$side" > "$B/docs/backlog.md"
( cd "$B" && git add -A && g commit -q -m head ) || { echo "REFUSED: scratch repository" >&2; exit 2; }
o="$( . "$VB" || exit 9; declare -F r11_judge >/dev/null || exit 9; r11_judge "$B" docs/backlog.md "$base" HEAD )"; rb=$?
[ "$rb" -eq 9 ] && { echo "ANCHOR ABSENT: r11_judge is not defined by $VB" >&2; exit 9; }
case "$(printf '%s\n' "$o" | sed -n '/^R11-COUNTS /p')" in
  "R11-COUNTS 1 "*" 2 1") : ;;
  *) echo "FAIL (b): r11_judge read '$(printf '%s\n' "$o" | sed -n '/^R11-COUNTS /p')', want 2 added and 1 failing" >&2; fail=1 ;;
esac
grep -qF "$(printf 'R11-FAIL\t%s\t' "$side")" <<<"$o" || { echo "FAIL (b): the pre-squash sha was not named" >&2; fail=1; }
exit "$fail"
