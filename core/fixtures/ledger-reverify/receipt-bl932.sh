#!/usr/bin/env bash
# BL-932 receipt: a ledger label whose id is closed by ONE punctuation mark inside the bold
# (`<id>.`, `<id>:`, `<id> —`, `<id>. (filed <date>)`) is asked about by its bare id, and every other
# punctuated suffix is refused as before.
# Usage:
#   bash receipt-bl932.sh [<reconcile dir> [<cells> [<world cache>]]]
# <reconcile dir> holds the ledger-reverify.sh and lib.sh under test; without it the receipt resolves
# this tree's own by walking up from itself for either install layout. With <cells> (space-separated
# names) only those cells are judged; every cell reads the SAME one engine run, so naming cells
# changes what is judged and never how often the engine runs. <world cache> builds the distribution
# and the consumer ONCE across invocations: a path that does not exist yet is filled by this run's
# build, with B and T recorded inside it, and a filled one is copied instead of rebuilt. The world
# reads no reconcile file, so one cache serves every engine copy. A cache that exists without its
# completion sentinel is refused (9), never rebuilt.
#
# THE ENGINE IS THE SHIPPING PROGRAM, run as `bash <dir>/ledger-reverify.sh <dist> <base> <consumer>
# <theirs>` from a scratch directory, never from the distribution root. Every cell reads its rows.
#
# ONE DISTRIBUTION, ONE CONSUMER LEDGER. Each cell has its own sprint prefix, so no cell's naming
# commit can cite another's prefix, and each naming commit changes a file under core/. Every entry is
# the BULLET form the reference consumer files (`- **<label>** <body>` then `  verify: manual`); the
# label is the row's ENTRY column.
# SEED RULE: NO naming commit's message carries an id immediately followed by `.`. A message that did
# would let a lib.sh that keeps the trailing dot find its dotted id in `git log`, and the U1-reverted
# mutant would survive. Each message names its id bare, at the end of the subject.
#   c0   `PC-S1200-BARE-CONTROL`                       -> NAMED-UPSTREAM citing its commit (form (a),
#        asked under every engine: the positive control that the engine ran)
#   d1   `<id>.`                                       -> NAMED-UPSTREAM citing its commit
#   d2   `<id>..`                                      -> NAMED-UPSTREAM citing its commit
#   d3   `<id>. (filed <date>)`                        -> NAMED-UPSTREAM citing its commit
#   d4   `PC-S1204-3.2-INNER-DOT.`, inner AND trailing dot -> NAMED-UPSTREAM citing its commit
#   d5   `BL-1205.`                                    -> NAMED-UPSTREAM citing its commit
#   k1   `<id>:`                                       -> NAMED-UPSTREAM citing its commit
#   k2   `<id>: (x)`                                   -> NAMED-UPSTREAM citing its commit
#   m1   `<id> —`, the em dash inside the bold         -> NAMED-UPSTREAM citing its commit
#   i1   `PC-S1209-3.2-INNER-DOT`, inner dot only      -> NAMED-UPSTREAM citing its commit (control)
#   n1   `<id>;`, a mark (c) does not take, named      -> no NAMED-UPSTREAM-family row
#   n2   `<id>.:`, two marks, named                    -> none
#   n3   `PC-S1212.`, a bare sprint prefix, cited bare by one commit
#                                                      -> no row for the label, no row for the prefix
#   n4   `<id>. prose`, prose after the mark, named    -> none
# A presence cell asserts the STATUS of the first NAMED-UPSTREAM-family row for its exact label AND
# that the row's detail names the cell's own commit; an absence cell asserts no such row, AMBIGUOUS
# included, keyed on the label and on the prefix.
# 0 = every judged cell answered as above. 1 = a cell did not (one `FAIL <cell>:` line each).
# 9 = the receipt could not run (no reconcile dir, a world could not be built, the engine exited
# non-zero or printed no c0 row).
set -uo pipefail
# SCRUB-RAN (BL-965): AI_DLC_SCRUB_PROBE is exported on the scrub line and must be gone after it. Under
# hermetic-run.sh an undeclared `env` is command-not-found, the loop iterates zero times and nothing is
# unset, so the scrub is proved by its probe, never assumed: a survivor refuses (9), and success prints the
# SCRUB-RAN line lr_unit_bl932 requires.
export AI_DLC_SCRUB_PROBE=1; for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ -z "${AI_DLC_SCRUB_PROBE+x}" ] || { echo "REFUSED: SCRUB-RAN: AI_DLC_SCRUB_PROBE survived the AI_DLC_* scrub -- env is unreachable and the scrub is a no-op" >&2; exit 9; }
echo "SCRUB-RAN the AI_DLC_* scrub unset its probe variable"
[ "$#" -le 3 ] || { echo "REFUSED: usage: bash receipt-bl932.sh [<reconcile dir> [<cells> [<world cache>]]]" >&2; exit 9; }
REC="${1:-}"; CELLS="${2:-}"; WCACHE="${3:-}"
if [ -z "$REC" ]; then
  # Walk up for the reconcile dir in either layout; never count hops.
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ -n "$d" ] && [ "$d" != / ]; do
    for c in "$d/core/skills/ai-dlc-update/reconcile" "$d/.claude/skills/ai-dlc-update/reconcile"; do
      [ -f "$c/ledger-reverify.sh" ] && { REC="$c"; break 2; }
    done
    d="$(dirname "$d")"
  done
fi
[ -n "$REC" ] && [ -f "$REC/ledger-reverify.sh" ] && [ -f "$REC/lib.sh" ] \
  || { echo "REFUSED: no reconcile dir with ledger-reverify.sh and lib.sh (${REC:-unresolved})" >&2; exit 9; }
REC="$(cd "$REC" && pwd)"
want() { [ -z "$CELLS" ] && return 0; case " $CELLS " in *" $1 "*) return 0 ;; esac; return 1; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl932.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
gd() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$R/dist" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
LED="_bmad-output/ai-dlc-update/push-candidate-ledger.md"
WSET="dist cons SHAS B T"
if [ -n "$WCACHE" ] && [ -e "$WCACHE" ]; then
  [ -f "$WCACHE/.complete" ] || { echo "REFUSED: world cache $WCACHE exists without its completion sentinel" >&2; exit 9; }
  for _w in $WSET; do cp -R "$WCACHE/$_w" "$R/$_w" || { echo "REFUSED: could not copy $_w out of the world cache" >&2; exit 9; }; done
else
  mkdir -p "$R/dist/core/scripts" "$R/cons/_bmad-output/ai-dlc-update" && gd init -q || exit 9
  printf '1.0.0\n' > "$R/dist/VERSION"
  gd add -A && gd commit -qm base || exit 9
  gd rev-parse HEAD > "$R/B" || exit 9
  : > "$R/SHAS"
  # nc <cell> <subject> -> one commit changing core/scripts/<cell>.sh, recorded as <cell>=<sha>.
  nc() {
    printf '%s\n' "$1" >> "$R/dist/core/scripts/$1.sh" || return 1
    gd add -A && gd commit -q -m "$2" || return 1
    printf '%s=%s\n' "$1" "$(gd rev-parse HEAD)" >> "$R/SHAS"
  }
  nc c0 'fix: absorb PC-S1200-BARE-CONTROL' || exit 9
  nc d1 'fix: absorb PC-S1201-DOT-CLOSED' || exit 9
  nc d2 'fix: absorb PC-S1202-TWO-DOTS' || exit 9
  nc d3 'fix: absorb PC-S1203-DOT-THEN-FILED' || exit 9
  nc d4 'fix: absorb PC-S1204-3.2-INNER-DOT' || exit 9
  nc d5 'fix: absorb BL-1205' || exit 9
  nc k1 'fix: absorb PC-S1206-COLON-CLOSED' || exit 9
  nc k2 'fix: absorb PC-S1207-COLON-THEN-PAREN' || exit 9
  nc m1 'fix: absorb PC-S1208-EM-DASH-CLOSED' || exit 9
  nc i1 'fix: absorb PC-S1209-3.2-INNER-DOT' || exit 9
  nc n1 'fix: absorb PC-S1210-SEMICOLON' || exit 9
  nc n2 'fix: absorb PC-S1211-DOT-COLON' || exit 9
  nc n3 'fix: the PC-S1212 retro lands' || exit 9
  nc n4 'fix: absorb PC-S1213-DOT-PROSE' || exit 9
  gd rev-parse HEAD > "$R/T" || exit 9
  cat > "$R/cons/$LED" <<'LEDGER'
# Push candidates

## Sprint 1200 (filed 2026-11-06)

- **PC-S1200-BARE-CONTROL** the bare-id control.
  verify: manual
- **PC-S1201-DOT-CLOSED.** a period closes the bold.
  verify: manual
- **PC-S1202-TWO-DOTS..** two periods close the bold.
  verify: manual
- **PC-S1203-DOT-THEN-FILED. (filed 2026-11-06)** a period, then the filing parenthetical.
  verify: manual
- **PC-S1204-3.2-INNER-DOT.** an inner dot and a closing one.
  verify: manual
- **BL-1205.** a BL id closed by a period.
  verify: manual
- **PC-S1206-COLON-CLOSED:** a colon closes the bold.
  verify: manual
- **PC-S1207-COLON-THEN-PAREN: (x)** a colon, then a parenthetical.
  verify: manual
- **PC-S1208-EM-DASH-CLOSED —** an em dash inside the bold.
  verify: manual
- **PC-S1209-3.2-INNER-DOT** an inner dot only.
  verify: manual
- **PC-S1210-SEMICOLON;** a mark form (c) does not take.
  verify: manual
- **PC-S1211-DOT-COLON.:** two marks.
  verify: manual
- **PC-S1212.** a bare sprint prefix closed by a period.
  verify: manual
- **PC-S1213-DOT-PROSE. prose** prose after the mark.
  verify: manual
LEDGER
  if [ -n "$WCACHE" ]; then
    mkdir -p "$WCACHE" || exit 9
    for _w in $WSET; do cp -R "$R/$_w" "$WCACHE/$_w" || exit 9; done
    : > "$WCACHE/.complete" || exit 9
  fi
fi
B="$(cat "$R/B")" && T="$(cat "$R/T")" && [ -n "$B" ] && [ -n "$T" ] \
  && [ "$(gd rev-parse -q --verify "${T}^{commit}")" = "$T" ] \
  || { echo "REFUSED: B/T do not resolve in the world's distribution" >&2; exit 9; }
sha() { sed -n "s/^$1=//p" "$R/SHAS" | cut -c1-7; }
mkdir -p "$R/tmp" "$R/cwd"
ROWS="$(cd "$R/cwd" && TMPDIR="$R/tmp" bash "$REC/ledger-reverify.sh" "$R/dist" "$B" "$R/cons" "$T" 2>"$R/err")"; rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the engine exited $rc: $(head -3 "$R/err" | tr '\n' ' ')" >&2; exit 9; }
# kind <label> -> "<status> <detail>" of the first NAMED-UPSTREAM-family row for the exact label, or none
kind() { printf '%s\n' "$ROWS" | LR_L="$1" awk -F'\t' '$2 == ENVIRON["LR_L"] && $1 ~ /^NAMED-UPSTREAM/ { print $1 "\t" $3; f = 1; exit } END { if (!f) print "none" }'; }
[ "$(kind PC-S1200-BARE-CONTROL)" != none ] || { echo "REFUSED: the engine printed no row for the c0 control; it did not reach the naming query" >&2; exit 9; }
FAILS=0
pres() { # <cell> <label>
  want "$1" || return 0
  local g s d w; g="$(kind "$2")"; s="${g%%	*}"; d="${g#*	}"; w="$(sha "$1")"
  if [ "$s" = NAMED-UPSTREAM ] && [ -n "$w" ] && case "$d" in *"$w"*) true ;; *) false ;; esac; then echo "ok $1: $s citing $w"
  else FAILS=$((FAILS + 1)); echo "FAIL $1: [$2] read [$s], want NAMED-UPSTREAM citing ${w:-<no sha>}"; fi
}
abs() { # <cell> <label> <prefix>
  want "$1" || return 0
  local g a; g="$(kind "$2")"
  a="$(printf '%s\n' "$ROWS" | LR_P="$3" awk -F'\t' '$2 == ENVIRON["LR_P"] && $1 ~ /^NAMED-UPSTREAM/ { n++ } END { print n + 0 }')"
  if [ "$g" = none ] && [ "$a" = 0 ]; then echo "ok $1: no NAMED-UPSTREAM-family row for [$2] or [$3]"
  else FAILS=$((FAILS + 1)); echo "FAIL $1: [$2] read [${g%%	*}], prefix rows $a; want none and 0"; fi
}
pres c0 PC-S1200-BARE-CONTROL
pres d1 'PC-S1201-DOT-CLOSED.'
pres d2 'PC-S1202-TWO-DOTS..'
pres d3 'PC-S1203-DOT-THEN-FILED. (filed 2026-11-06)'
pres d4 'PC-S1204-3.2-INNER-DOT.'
pres d5 'BL-1205.'
pres k1 'PC-S1206-COLON-CLOSED:'
pres k2 'PC-S1207-COLON-THEN-PAREN: (x)'
pres m1 'PC-S1208-EM-DASH-CLOSED —'
pres i1 PC-S1209-3.2-INNER-DOT
abs  n1 'PC-S1210-SEMICOLON;' PC-S1210
abs  n2 'PC-S1211-DOT-COLON.:' PC-S1211
abs  n3 'PC-S1212.' PC-S1212
abs  n4 'PC-S1213-DOT-PROSE. prose' PC-S1213
[ "$FAILS" -eq 0 ] || exit 1
exit 0
