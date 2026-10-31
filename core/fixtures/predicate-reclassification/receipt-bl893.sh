#!/usr/bin/env bash
# core/fixtures/predicate-reclassification/receipt-bl893.sh [<differential> [<manifest>]] -- the BL-893
# backlog receipt: a side that renders no verdict on ANY series is UNDECIDABLE, never a mass
# reclassification, and the shipped gate-adjudication site reads gate_adjudication.py.
#
# Drives core/skills/ai-dlc-update/reconcile/predicate-differential.sh (or <differential>) with its
# consumer-read.sh sibling copied from beside it, over the worlds seed.sh (beside this file) builds:
#   dist16, NON-BARE, one toy predicate per world, BASE -> THEIRS, with its index at THEIRS:
#     UNDEC     mixed -> NOTE + exit 2 every series   UNDECIDABLE naming the incoming side, no RECLASSIFIES
#     SILENT0   mixed -> nothing, exit 0              UNDECIDABLE naming the incoming side, no RECLASSIFIES
#     RECL      mixed -> FAIL every series            RECLASSIFIES
#     PASSONLY  FAIL every series -> PASS line every series   RECLASSIFIES
#     PARTIAL   mixed -> NOTE + exit 2 on alpha, beta; FAIL on gamma   RECLASSIFIES
#     DASH      a `pass: -` site, mixed -> PASS every series  RECLASSIFIES (the arm abstains)
#     NONBARE   read-set gains helper.py, absent from BASE but in the index   STABLE, compared
#     BSILENT   NOTE + exit 2 every series -> mixed   UNDECIDABLE naming the base side, no RECLASSIFIES
#     NOTETOK   mixed -> a NOTE line AND a FAIL token every series   RECLASSIFIES (a warning is not silence)
#   distga, the SHIPPED manifest (or <manifest>; default: predicate-sites.md beside the differential):
#     GA   only gate_adjudication.py moves, PASS -> FAIL          the site is not STABLE
#     GAU  gate_adjudication.py no longer imports at THEIRS       UNDECIDABLE naming the incoming side
# Every toy world but DASH declares a sed `pass:`.
#
# Exit 0 when every world holds. 1 when any does not. 9 when it cannot measure: no subject, no
# sibling, a seed that failed, or the control world (RECL) produced no row.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/preamble.sh"
cant() { echo "receipt-bl893: cannot measure: $*" >&2; exit 9; }

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

mkr() { # mkr <manifest file> -> a directory holding the subject, its sibling and that manifest
  local d; d="$(mktemp -d "$ROOT/r893.XXXXXX")" || return 1
  cp "$SUBJ" "$d/predicate-differential.sh" && cp "$SDIR/consumer-read.sh" "$d/" && cp "$1" "$d/predicate-sites.md" || return 1
  printf '%s' "$d"
}
drive() { env -u CLAUDE_PROJECT_DIR bash "$@" 2>&1; }
srow() { awk -F'\t' -v n="$1" '$2 == n { print; exit }' <<<"$2"; }

PL='s/^PASS: .*/PASS/p'
site() { # site <toy> <pass or empty> [<extra member>]
  printf 'reads: core/scripts/%s%s\nentry: core/scripts/%s\ncorpus: *pass[0-9]*\nseries: s/pass[0-9]+.*$/pass/\ninvoke: --series {series}\n' "$1" "${3:+ $3}" "$1"
  [ -z "$2" ] || printf 'pass: %s\n' "$2"
  printf 'verdict: s/^FAIL \\(([A-Z]+) --.*/\\1/p\n\n'
}
{ site toy-undec.sh "$PL"; site toy-silent0.sh "$PL"; site toy-recl.sh "$PL"; site toy-passonly.sh "$PL"
  site toy-partial.sh "$PL"; site toy-dash.sh ""; site toy-nb.sh "$PL" core/scripts/helper.py
  site toy-bsilent.sh "$PL"; site toy-notetok.sh "$PL"; } > "$ROOT/m893.md"

D16="$ROOT/dist16"; DG="$ROOT/distga"
B16="$(git -C "$D16" rev-list --max-parents=0 HEAD)"; T16="$(git -C "$D16" rev-parse HEAD)"
BG="$(git -C "$DG" rev-list --max-parents=0 HEAD)"; MG="$(git -C "$DG" rev-parse HEAD~1)"; TG="$(git -C "$DG" rev-parse HEAD)"
[ -n "$B16" ] && [ -n "$T16" ] && [ -n "$BG" ] && [ -n "$MG" ] && [ -n "$TG" ] || cant "seeded refs unresolvable"
[ -n "$(git -C "$D16" ls-files -- core/scripts/helper.py)" ] && [ -z "$(git -C "$D16" ls-tree --name-only "$B16" -- core/scripts/helper.py)" ] \
  || cant "dist16 does not hold helper.py in its index only"

R="$(mkr "$ROOT/m893.md")" || cant "copy failed"
RG="$(mkr "$MAN")" || cant "copy failed"
o16="$(drive "$R/predicate-differential.sh" "$D16" "$B16" "$T16" "$ROOT/consumer16")"
oga="$(drive "$RG/predicate-differential.sh" "$DG" "$BG" "$MG" "$ROOT/consga")"
ogu="$(drive "$RG/predicate-differential.sh" "$DG" "$BG" "$TG" "$ROOT/consga")"
[ -n "$(srow toy-recl.sh "$o16")" ] || cant "the control world RECL produced no row: $(head -c 200 <<<"$o16")"

fails=0
w() { # w <name> <0|1 holds>
  if [ "$2" = 1 ]; then echo "receipt-bl893: ok   $1"; else echo "receipt-bl893: FAIL $1"; fails=$((fails + 1)); fi
}
silent_ok() { # silent_ok <site> <out> <ref> [<side>]: the row is UNDECIDABLE naming that side (default incoming) and that ref, and no RECLASSIFIES row names the site
  case "$(srow "$1" "$2")" in "PREDICATE-UNDECIDABLE	"*"the ${4:-incoming} side yielded no verdict on any series"*"no pass line at $3)"*) ;; *) echo 0; return ;; esac
  if awk -F'\t' -v t="$1" '$1 == "PREDICATE-RECLASSIFIES" && index($0, t) { f = 1 } END { exit !f }' <<<"$2"; then echo 0; else echo 1; fi
}
is() { case "$(srow "$1" "$2")" in "$3"*) echo 1 ;; *) echo 0 ;; esac; }
w UNDEC    "$(silent_ok toy-undec.sh "$o16" "$T16")"
w SILENT0  "$(silent_ok toy-silent0.sh "$o16" "$T16")"
w BSILENT  "$(silent_ok toy-bsilent.sh "$o16" "$B16" base)"
w NOTETOK  "$(is toy-notetok.sh "$o16" PREDICATE-RECLASSIFIES)"
w RECL     "$(is toy-recl.sh "$o16" PREDICATE-RECLASSIFIES)"
w PASSONLY "$(is toy-passonly.sh "$o16" PREDICATE-RECLASSIFIES)"
w PARTIAL  "$(is toy-partial.sh "$o16" PREDICATE-RECLASSIFIES)"
w DASH     "$(is toy-dash.sh "$o16" PREDICATE-RECLASSIFIES)"
case "$(srow toy-nb.sh "$o16")" in "PREDICATE-STABLE	"*"read-set moved"*) w NONBARE 1 ;; *) w NONBARE 0 ;; esac
case "$(srow validate-gate-adjudication.sh "$oga")" in ""|PREDICATE-STABLE*) w GA 0 ;; *) w GA 1 ;; esac
w GAU      "$(silent_ok validate-gate-adjudication.sh "$ogu" "$TG")"

[ "$fails" -eq 0 ] || exit 1
exit 0
