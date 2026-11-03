#!/usr/bin/env bash
# core/fixtures/predicate-reclassification/receipt-bl896.sh [<differential> [<manifest>]] -- the BL-896
# backlog receipt: the gate-adjudication predicate site observes a change to how waivers are read.
#
# Drives core/skills/ai-dlc-update/reconcile/predicate-differential.sh (or <differential>) with its
# consumer-read.sh sibling and the SHIPPED predicate-sites.md (or <manifest>) over seed.sh's distw:
#   a consumer whose stored verdict carries FAIL_WAIVED and whose docs/escalations/pending.md holds the
#   OVERRIDDEN row that waives it; the toy adjudicator resolves the waiver through the
#   validate-suppression-lifetime.sh sibling beside itself, failing closed without the file or sibling.
#     WV   BASE -> HEAD, the row is no longer honoured            the site RECLASSIFIES
#     WVC  BASE -> HEAD~1, an unrelated change (bytes moved)      the site is STABLE, read-set moved
# Without the escalations file passed to both sides by path, or without the sibling in the site's
# reads:, both sides fail the waiver identically and WV reads STABLE.
#
# Exit 0 when both hold. 1 when either does not. 9 when it cannot measure: no subject, no sibling, a
# seed that failed, or the WVC drive produced no row for the site.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/preamble.sh"
cant() { echo "receipt-bl896: cannot measure: $*" >&2; exit 9; }

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "${1:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/predicate-differential.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/predicate-differential.sh")"
[ -n "$SUBJ" ] || cant "no predicate-differential.sh"
SDIR="$(cd "$(dirname "$SUBJ")" && pwd)"
MAN="${2:-$SDIR/predicate-sites.md}"
[ -f "$MAN" ] || cant "no manifest at $MAN"
[ -f "$SDIR/consumer-read.sh" ] || cant "no consumer-read.sh beside $SUBJ"
[ -f "$HERE/seed.sh" ] || cant "no seed.sh beside $0"

ROOT="$(bash "$HERE/seed.sh")" || cant "seed.sh failed"
case "$ROOT" in */predicate-reclass-??????) ;; *) cant "seed.sh printed no seeded root" ;; esac
trap 'case "$ROOT" in */predicate-reclass-??????) rm -rf "$ROOT" ;; esac' EXIT

DW="$ROOT/distw"; CW="$ROOT/consw"
BW="$(git -C "$DW" rev-list --max-parents=0 HEAD)"; MW="$(git -C "$DW" rev-parse HEAD~1)"; TW="$(git -C "$DW" rev-parse HEAD)"
[ -n "$BW" ] && [ -n "$MW" ] && [ -n "$TW" ] || cant "distw refs unresolvable"
[ -f "$CW/docs/escalations/pending.md" ] || cant "consw holds no escalations file"

R="$(mktemp -d "$ROOT/r896.XXXXXX")" || cant "mktemp failed"
cp "$SUBJ" "$R/predicate-differential.sh" && cp "$SDIR/consumer-read.sh" "$R/" && cp "$MAN" "$R/predicate-sites.md" || cant "copy failed"
drive() { env -u CLAUDE_PROJECT_DIR bash "$@" 2>&1; }
srow() { awk -F'\t' -v n="$1" '$2 == n { print; exit }' <<<"$2"; }
owv="$(drive "$R/predicate-differential.sh" "$DW" "$BW" "$TW" "$CW")"
owc="$(drive "$R/predicate-differential.sh" "$DW" "$BW" "$MW" "$CW")"
rwc="$(srow validate-gate-adjudication.sh "$owc")"
[ -n "$rwc" ] || cant "the WVC drive produced no gate-adjudication row: $(head -c 200 <<<"$owc")"

fails=0
w() { if [ "$2" = 1 ]; then echo "receipt-bl896: ok   $1"; else echo "receipt-bl896: FAIL $1"; fails=$((fails + 1)); fi; }
case "$(srow validate-gate-adjudication.sh "$owv")" in PREDICATE-RECLASSIFIES*) w WV 1 ;; *) w WV 0 ;; esac
case "$rwc" in "PREDICATE-STABLE	"*"read-set moved"*) w WVC 1 ;; *) w WVC 0 ;; esac

[ "$fails" -eq 0 ] || exit 1
exit 0
