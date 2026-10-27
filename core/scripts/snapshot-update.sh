#!/usr/bin/env bash
# snapshot-update.sh -- the lead's writer for pipeline-snapshot.md rows: one call carries every
# change of one snapshot update, and nothing is written unless the stamp check passes on it.
#
# WHAT IT REPLACES. The lead updated the snapshot one Edit per row. Measured on graph's s319 and s320
# lead transcripts: 445 and 219 snapshot Edits (22.25 and 16.85 per story), in 298 and 123 runs of
# consecutive snapshot Edits with no other tool call between them, plus 76 and 18 Reads of the
# snapshot that Edit's read-before-edit precondition costs. One call per run is 7.35 and 7.38 fewer
# calls per story. The shell and interpreter writes the lead also used (451 python and 49 sed -i in
# s319) are already refused by the foreground-budget hook's Deny B since 0.947.0; this program is
# the sanctioned shell path that Deny B's header names.
#
# WHY IT RUNS THE STAMP CHECK ITSELF. An Edit of the snapshot reaches the derivation-capture
# PostToolUse hook, which runs `validate-artifact-budget.sh --stamps-only` on the lines the Edit
# added. A write made from inside a Bash call reaches no PostToolUse hook at all. So this program
# runs that same mode on the lines IT adds, and it runs it BEFORE the write: the candidate is built
# beside the snapshot (the check reads spawn-ledger.jsonl from the snapshot's own directory), judged,
# and moved over the snapshot only on exit 0. A finding leaves the snapshot byte-identical, which is
# stronger than the hook can be -- the hook runs after an Edit has landed.
#
# FAILS CLOSED. The validator absent, its usage refusal, an op whose target matches zero or several
# lines, a cell count that does not match the table header, or a snapshot changed by another writer
# while this one ran: each is exit 2 and writes nothing. There is no path that writes unchecked.
#
# usage:
#   snapshot-update.sh [--snapshot <path>] <op> [<op> ...]
# ops, applied in order to one candidate:
#   --activity <text>            insert `- <text>` as the newest line under `## Recent Activity`
#   --open-item <text>           insert `- <text>` first under `## Open Items`
#   --close-item <substring>     delete the ONE Open Items line containing <substring>
#   --row-add <c1 | c2 | ...>    append an In-Flight Teammates row; the cell count must equal the
#                                header's (`agent | role | deliverable | dispatched-at | status`)
#   --row-status <agent> <status>  set the status cell of the ONE row whose agent cell's first word
#                                is <agent>; <status> is in-flight, delivered-reachable or stopped
#   --row-delete <agent>         delete the ONE row whose agent cell's first word is <agent>
#   --set <key> <value>          rewrite the ONE line `- <key>: ...` to `- <key>: <value>`
# --snapshot defaults to <root>/${AI_DLC_STATE_DIR:-_bmad-output}/pipeline-snapshot.md, the root
# found by walking up for a marker (never by counting `..`).
#
# exit:
#   0  every op applied, the stamp check passed, the snapshot was written
#   1  the stamp check refused the candidate (its FUTURE/MALFORMED/BACKDATED/LATE lines are printed);
#      the snapshot is unchanged
#   2  a refusal: bad usage, an op matching zero or several targets, no validator, the snapshot moved
#      under this call; the snapshot is unchanged
set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of `..` hops:
# this runs from <root>/core/scripts/ and from a consumer's <root>/scripts/ai-dlc/. Inline on
# purpose, as in every script that needs it -- locating a shared lib is the same unsolved problem.
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
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "snapshot-update: REFUSED: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root. Nothing written." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
SU_SELF_DIR="$AI_DLC_SELF_DIR"
SU_ROOT="$AI_DLC_ROOT"

refuse() { printf 'snapshot-update: REFUSED: %s\nsnapshot-update: nothing written.\n' "$1" >&2; exit 2; }

SNAP=""
OPS="$(mktemp "${TMPDIR:-/tmp}/snapshot-update-ops.XXXXXX")" || refuse "no temp file"
trap 'rm -f "$OPS"' EXIT
nops=0
# Ops go to a file, one per record, fields separated by an ASCII unit separator, so a cell or a
# line of text can carry any byte but a newline and the separator.
US=$'\037'
addop() { printf '%s\n' "$*" >> "$OPS"; nops=$((nops + 1)); }
while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot)     [ $# -ge 2 ] || refuse "--snapshot needs a path"; SNAP="$2"; shift 2 ;;
    --activity|--open-item|--close-item|--row-add|--row-delete)
                    [ $# -ge 2 ] && [ -n "$2" ] || refuse "$1 needs a non-empty argument"
                    case "$2" in *$'\n'*|*"$US"*) refuse "$1: the argument carries a newline" ;; esac
                    addop "${1#--}${US}$2"; shift 2 ;;
    --row-status|--set)
                    [ $# -ge 3 ] && [ -n "$2" ] && [ -n "$3" ] || refuse "$1 needs two non-empty arguments"
                    case "$2$3" in *$'\n'*|*"$US"*) refuse "$1: an argument carries a newline" ;; esac
                    if [ "$1" = --row-status ]; then
                      case "$3" in in-flight|delivered-reachable|stopped) ;;
                        *) refuse "--row-status: '$3' is not in-flight, delivered-reachable or stopped" ;; esac
                    fi
                    addop "${1#--}${US}$2${US}$3"; shift 3 ;;
    -h|--help)      sed -n '2,49p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)              refuse "unknown argument '$1'" ;;
  esac
done
[ "$nops" -gt 0 ] || refuse "no op given"
[ -n "$SNAP" ] || SNAP="${SU_ROOT}/${AI_DLC_STATE_DIR:-_bmad-output}/pipeline-snapshot.md"
[ -f "$SNAP" ] || refuse "no snapshot at $SNAP"

VALIDATOR="$SU_SELF_DIR/validate-artifact-budget.sh"
[ -f "$VALIDATOR" ] || refuse "validate-artifact-budget.sh is not beside this program ($SU_SELF_DIR), so the stamp check cannot run"

SDIR="$(cd "$(dirname "$SNAP")" && pwd)" || refuse "cannot enter $(dirname "$SNAP")"
CAND="$SDIR/.pipeline-snapshot.md.candidate.$$"
PAY="$SDIR/.pipeline-snapshot.md.payload.$$"
trap 'rm -f "$OPS" "$CAND" "$PAY"' EXIT
BEFORE="$(cksum < "$SNAP")"

# One awk pass per op over the candidate. Exit 3: the op's target matched nothing; 4: it matched
# more than one line; 5: a row's cell count differs from its table header; 6: the section is absent.
cp "$SNAP" "$CAND" || refuse "cannot write a candidate beside $SNAP"
while IFS="$US" read -r op a b; do
  SU_OP="$op" SU_A="$a" SU_B="${b:-}" LC_ALL=C awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function cells(line, arr,   r) { r = line; sub(/^[ \t]*\|/, "", r); sub(/\|[ \t]*$/, "", r); return split(r, arr, "|") }
    BEGIN { op = ENVIRON["SU_OP"]; A = ENVIRON["SU_A"]; B = ENVIRON["SU_B"]; n = 0 }
    { L[++n] = $0 }
    END {
      want = (op == "activity") ? "Recent Activity" : (op ~ /item$/) ? "Open Items" : (op ~ /^row-/) ? "In-Flight Teammates" : ""
      hs = 0; he = n + 1
      for (i = 1; i <= n; i++) if (L[i] ~ /^## /) {
        t = L[i]; sub(/^##[ \t]*/, "", t)
        if (hs && he == n + 1) he = i
        if (want != "" && substr(t, 1, length(want)) == want) {
          if (hs) { print "two sections named " want > "/dev/stderr"; exit 4 }
          hs = i; he = n + 1
        }
      }
      if (want != "" && !hs) { print "no section named " want > "/dev/stderr"; exit 6 }
      del = 0; ins = 0; insline = ""
      if (op == "activity" || op == "open-item") {
        txt = A; if (substr(txt, 1, 2) != "- ") txt = "- " txt
        ins = hs; insline = txt
      } else if (op == "close-item") {
        m = 0; for (i = hs + 1; i < he; i++) if (index(L[i], A)) { m++; del = i }
        if (m == 0) exit 3; if (m > 1) exit 4
      } else if (op == "set") {
        m = 0; for (i = 1; i <= n; i++) if (index(L[i], "- " A ":") == 1) { m++; hit = i }
        if (m == 0) exit 3; if (m > 1) exit 4
        L[hit] = "- " A ": " B
      } else {
        hdr = 0; for (i = hs + 1; i < he; i++) if (L[i] ~ /\|/) {
          k = cells(L[i], c); for (j = 1; j <= k; j++) if (trim(c[j]) == "dispatched-at") { hdr = i; nc = k }
          if (hdr) break
        }
        if (!hdr) { print "no In-Flight Teammates header row naming dispatched-at" > "/dev/stderr"; exit 6 }
        sc = 0; cells(L[hdr], c); for (j = 1; j <= nc; j++) if (trim(c[j]) == "status") sc = j
        piped = (L[hdr] ~ /^[ \t]*\|/)
        last = hdr
        for (i = hdr + 1; i < he; i++) if (L[i] ~ /\|/) last = i
        if (op == "row-add") {
          k = cells(A, c); if (k != nc) { printf "the row has %d cells, the header %d\n", k, nc > "/dev/stderr"; exit 5 }
          r = ""; for (j = 1; j <= k; j++) r = r (j > 1 ? " | " : "") trim(c[j])
          ins = last; insline = piped ? "| " r " |" : r
        } else {
          m = 0
          for (i = hdr + 1; i < he; i++) if (L[i] ~ /\|/ && L[i] !~ /^[ \t|:-]+$/) {
            cells(L[i], c); f = trim(c[1]); split(f, w, /[ \t]+/)
            if (w[1] == A) { m++; hit = i }
          }
          if (m == 0) exit 3; if (m > 1) exit 4
          if (op == "row-delete") del = hit
          else {
            if (!sc) { print "the header names no status column" > "/dev/stderr"; exit 6 }
            k = cells(L[hit], c); c[sc] = " " B " "
            r = ""; for (j = 1; j <= k; j++) r = r (j > 1 ? " | " : "") trim(c[j])
            L[hit] = piped ? "| " r " |" : r
          }
        }
      }
      for (i = 1; i <= n; i++) {
        if (i == del) continue
        print L[i]
        if (i == ins) print insline
      }
    }' "$CAND" > "$CAND.next"
  rc=$?
  case "$rc" in
    0) mv "$CAND.next" "$CAND" ;;
    3) rm -f "$CAND.next"; refuse "--$op '$a': no line matches" ;;
    4) rm -f "$CAND.next"; refuse "--$op '$a': more than one line matches; name it exactly" ;;
    5) rm -f "$CAND.next"; refuse "--$op: cell count differs from the In-Flight Teammates header" ;;
    *) rm -f "$CAND.next"; refuse "--$op: the snapshot has no section for it (rc $rc)" ;;
  esac
done < "$OPS"

# The payload is what the candidate ADDED, each line counted against its occurrences in the old
# file, exactly as the derivation-capture hook subtracts an Edit's old_string from its new_string.
LC_ALL=C awk 'FNR == NR { c[$0]++; next } { if (c[$0] > 0) c[$0]--; else if ($0 != "") print }' "$SNAP" "$CAND" > "$PAY"

VOUT="$(AI_DLC_PROJECT_ROOT="$SU_ROOT" bash "$VALIDATOR" --stamps-only "$CAND" --payload "$PAY" 2>&1)"
VRC=$?
if [ "$VRC" -eq 1 ]; then
  printf '%s\n' "$VOUT" >&2
  printf 'snapshot-update: REFUSED by the stamp check; %s is unchanged. Fix the stamp and re-run the whole call.\n' "$SNAP" >&2
  exit 1
fi
[ "$VRC" -eq 0 ] || { printf '%s\n' "$VOUT" >&2; refuse "the stamp check could not run (validate-artifact-budget.sh exit $VRC)"; }

[ "$(cksum < "$SNAP")" = "$BEFORE" ] || refuse "$SNAP changed while this call ran; re-run it"
mv "$CAND" "$SNAP" || refuse "cannot move the candidate over $SNAP"
printf 'snapshot-update: %d op(s) written to %s (stamp check passed on %d added line(s))\n' \
  "$nops" "$SNAP" "$(grep -c . "$PAY" 2>/dev/null || true)"
exit 0
