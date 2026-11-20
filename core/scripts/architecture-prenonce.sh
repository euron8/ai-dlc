#!/usr/bin/env bash
# architecture-prenonce.sh -- the record-format checks the architecture gate's adjudicators found, run
# BEFORE the gate nonce opens, so the gate attests judgment items and not a lead-written format defect.
#
# usage: architecture-prenonce.sh --sprint <N> [--pending <path>] [--root <dir>]
#
# ARMS (one line each, every line names how many items it examined):
#   E1  every `## ` heading of docs/escalations/pending.md that carries the sprint token S<N> heads an
#       entry holding exactly one `**Status:**` line. (A header-grammar arm was measured and dropped: 90%
#       of the real headers differ in form.)
#       validate-escalation-status-vocabulary.sh (Check 2) examines only entries that HAVE that line, so
#       a header it cannot parse or an entry with no Status line is never judged there.
#   E2  validate-escalation-status-vocabulary.sh over the same file: the Status token is in the closed set.
#   E3  validate-snapshot-conservation.sh (Check 35): nothing substantive left the snapshot since the
#       last gate without a copy elsewhere.
# Check 15's budget-evidence cell is written by Check 12 at the gate and cannot be examined here.
#
# EXIT  0 every arm passed or reads NOT-APPLICABLE (no pending.md, no entry of the sprint, no gate yet)
#       1 at least one arm FAILED   2 bad arguments, or a sibling validator is absent
# An arm that cannot run reads NOT-APPLICABLE or PENDING and never FAIL; a zero examined is printed as
# "examined 0", never as a bare pass.

AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "architecture-prenonce.sh: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
ROOT="$AI_DLC_ROOT"
SPRINT=""; PENDING=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sprint)  SPRINT="${2:-}"; shift 2 ;;
    --pending) PENDING="${2:-}"; shift 2 ;;
    --root)    ROOT="${2:-}"; shift 2 ;;
    *) echo "architecture-prenonce: unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$SPRINT" in ''|*[!0-9]*) echo "architecture-prenonce: --sprint <digits> is required (project root $ROOT)" >&2; exit 2 ;; esac
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "architecture-prenonce: cannot resolve the project root" >&2; exit 2; }
[ -n "$PENDING" ] || PENDING="$ROOT/docs/escalations/pending.md"
for s in validate-escalation-status-vocabulary.sh validate-snapshot-conservation.sh; do
  [ -f "$AI_DLC_SELF_DIR/$s" ] || { echo "architecture-prenonce: $s is not beside this program ($AI_DLC_SELF_DIR)" >&2; exit 2; }
done

FAILED=0

# E1 -- the Status line, for this sprint entries only.
if [ ! -f "$PENDING" ]; then
  echo "E1 NOT-APPLICABLE: no $PENDING"
else
  E1="$(LC_ALL=C awk -v sp="S$SPRINT" '
    function flush() { if (h != "") { n++; if (st != 1) { bad++; print "  line " hl ", " st " **Status:** line(s): " h } } h = ""; st = 0 }
    function tok(s,   i, c) {
      i = index(s, sp)
      while (i > 0) { c = substr(s, i + length(sp), 1); if (c !~ /[0-9]/) return 1; s = substr(s, i + length(sp)); i = index(s, sp) }
      return 0 }
    /^## / { flush(); if (tok($0)) { h = $0; hl = NR }; next }
    /^\*\*Status:\*\*/ { if (h != "") st++ }
    END { flush(); print "EXAMINED " n + 0 " BAD " bad + 0 }' "$PENDING")"
  E1_N="$(printf '%s\n' "$E1" | sed -n 's/^EXAMINED \([0-9]*\) BAD \([0-9]*\)$/\1/p')"
  E1_BAD="$(printf '%s\n' "$E1" | sed -n 's/^EXAMINED \([0-9]*\) BAD \([0-9]*\)$/\2/p')"
  if [ -z "$E1_N" ]; then
    echo "E1 PENDING: the entry scan produced no summary line"
  elif [ "$E1_N" -eq 0 ]; then
    echo "E1 NOT-APPLICABLE: examined 0 entries carrying S$SPRINT"
  elif [ "$E1_BAD" -gt 0 ]; then
    echo "E1 FAIL: $E1_BAD of $E1_N S$SPRINT entries without exactly one **Status:** line"
    printf '%s\n' "$E1" | grep -v '^EXAMINED ' | head -20
    FAILED=1
  else
    echo "E1 PASS: examined $E1_N S$SPRINT entries"
  fi
fi

# E2 -- the closed Status vocabulary.
if [ -f "$PENDING" ]; then
  if E2="$(bash "$AI_DLC_SELF_DIR/validate-escalation-status-vocabulary.sh" "$PENDING" 2>&1)"; then
    echo "E2 PASS: $(printf '%s\n' "$E2" | tail -1 | cut -c1-120)"
  else
    case "$?" in
      1) echo "E2 FAIL:"; printf '%s\n' "$E2" | head -12; FAILED=1 ;;
      *) echo "E2 PENDING: the vocabulary validator could not evaluate: $(printf '%s\n' "$E2" | head -1 | cut -c1-120)" ;;
    esac
  fi
else
  echo "E2 NOT-APPLICABLE: no $PENDING"
fi

# E3 -- snapshot conservation (Check 35).
E3="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$AI_DLC_SELF_DIR/validate-snapshot-conservation.sh" --root "$ROOT" 2>&1)"; E3RC=$?
case "$E3RC" in
  0) echo "E3 PASS: $(printf '%s\n' "$E3" | grep -E '^(lines_destroyed|verdict)' | tr '\n' ' ' | cut -c1-200)" ;;
  1) echo "E3 FAIL:"; printf '%s\n' "$E3" | head -16; FAILED=1 ;;
  *) echo "E3 PENDING: conservation could not be evaluated (exit $E3RC): $(printf '%s\n' "$E3" | head -1 | cut -c1-120)" ;;
esac

[ "$FAILED" -eq 0 ] || exit 1
exit 0
