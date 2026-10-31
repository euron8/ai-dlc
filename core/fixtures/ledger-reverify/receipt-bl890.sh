#!/usr/bin/env bash
# BL-890 receipt: a ledger label carrying ONE trailing parenthetical after its id is asked about by
# that id, and every other suffix is refused as before.
# Usage:
#   bash receipt-bl890.sh [<reconcile dir> [<cells> [<world cache>]]]
# <reconcile dir> holds the ledger-reverify.sh under test and its siblings; without it the receipt
# resolves this tree's own by walking up from itself for either install layout. With <cells>
# (space-separated names) only those cells are judged; every cell reads the SAME one engine run, so
# naming cells changes what is judged and never how often the engine runs. <world cache> builds the
# distribution and the consumer ONCE across invocations: a path that does not exist yet is filled by
# this run's build, with B and T recorded inside it, and a filled one is copied instead of rebuilt.
# The world reads no reconcile file, so one cache serves every engine copy. A cache that exists
# without its completion sentinel is refused (9), never rebuilt.
#
# THE ENGINE IS THE SHIPPING PROGRAM, run as `bash <dir>/ledger-reverify.sh <dist> <base> <consumer>
# <theirs>` from a scratch directory, never from the distribution root. Every cell reads its rows.
#
# ONE DISTRIBUTION, ONE CONSUMER LEDGER. Each cell has its own sprint prefix, so no cell's naming
# commit can cite another's prefix, and each naming commit changes a file under core/ and carries no
# `Not-discharged:` line, so a naming row is the plain kind unless the cell says otherwise. Every
# heading is `## <label>`; the label is the row's ENTRY column.
#   c0   `PC-S1113-BARE-CONTROL`, no receipt, named          -> NAMED-UPSTREAM citing its commit
#        (form (a), asked under every engine: the positive control that the engine ran)
#   s1   `PC-S1101-… (filed <date>, lead session)`, no receipt, named
#                                                            -> NAMED-UPSTREAM citing its commit
#   s0   the same heading form, its id named by NO commit    -> no NAMED-UPSTREAM-family row for the
#        label and no AMBIGUOUS row for its prefix, which nothing cites
#   s2   a suffixed heading with a `theirs_has` receipt; its naming commit removes the anchor from
#        the receipt path                                    -> NAMED-UPSTREAM citing its commit
#   s3   `BL-1104 (filed <date>, lead session)`, named       -> NAMED-UPSTREAM citing its commit
#   r1   `<id> and BL-12 prose`, named under <id>            -> no NAMED-UPSTREAM-family row
#   r2   `<id>: note`                                         -> none
#   r3   `<id> (a) (b)`, two parentheticals                   -> none
#   r4   `<id> (unclosed`                                     -> none
#   r5   `<id> (x) trailing`, text after the parenthetical    -> none
#   r6   `PC-S1110 (retro)`, a bare sprint prefix, cited bare by two commits
#                                                            -> no row for the label, no AMBIGUOUS row
#   sib  X and Y, two suffixed `theirs_has` entries on ONE file; one commit names both and changes
#        only Y's anchor                                     -> X reads NAMED-UPSTREAM-SIBLING-ATTRIBUTED
#   sibY Y itself                                            -> NAMED-UPSTREAM citing the same commit
#   amb  `PC-S1114-AMB-UNNAMED (filed <date>, lead session)`, its slug named by NO commit and its bare
#        prefix `PC-S1114` cited by exactly one                -> NAMED-UPSTREAM-AMBIGUOUS keyed on the
#        prefix `PC-S1114`, its detail naming that commit (s1 is the twin: the same heading form, named)
# A presence cell asserts the STATUS of the first NAMED-UPSTREAM-family row for its exact label AND
# that the row's detail names the cell's own commit; an absence cell asserts no such row, AMBIGUOUS
# included, keyed on the label and on the prefix.
# 0 = every judged cell answered as above. 1 = a cell did not (one `FAIL <cell>:` line each).
# 9 = the receipt could not run (no reconcile dir, a world could not be built, the engine exited
# non-zero or printed no c0 row).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -le 3 ] || { echo "REFUSED: usage: bash receipt-bl890.sh [<reconcile dir> [<cells> [<world cache>]]]" >&2; exit 9; }
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
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl890.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
gd() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$R/dist" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
LED="_bmad-output/ai-dlc-update/push-candidate-ledger.md"
# The cells' commits, recorded as each is made: <cell>=<full sha>, one per line.
WSET="dist cons SHAS B T"
if [ -n "$WCACHE" ] && [ -e "$WCACHE" ]; then
  [ -f "$WCACHE/.complete" ] || { echo "REFUSED: world cache $WCACHE exists without its completion sentinel" >&2; exit 9; }
  for _w in $WSET; do cp -R "$WCACHE/$_w" "$R/$_w" || { echo "REFUSED: could not copy $_w out of the world cache" >&2; exit 9; }; done
else
  mkdir -p "$R/dist/core/scripts" "$R/cons/_bmad-output/ai-dlc-update" && gd init -q || exit 9
  printf '1.0.0\n' > "$R/dist/VERSION"
  printf '#!/bin/sh\n# BUG_S1103 still here\n' > "$R/dist/core/scripts/s1103-subject.sh"
  printf '#!/bin/sh\n# X_ANCHOR_S1111\n:\n:\n:\n# Y_ANCHOR_S1112\n' > "$R/dist/core/scripts/sib1111.sh"
  gd add -A && gd commit -qm base || exit 9
  gd rev-parse HEAD > "$R/B" || exit 9
  : > "$R/SHAS"
  # nc <cell> <file> <subject> [<body>...] -> one commit changing <file> under core/scripts/, recorded.
  nc() {
    local c="$1" f="$2" s="$3"; shift 3
    printf '%s\n' "$c" >> "$R/dist/core/scripts/$f" || return 1
    gd add -A && gd commit -q -m "$s" "${@/#/-m}" || return 1
    printf '%s=%s\n' "$c" "$(gd rev-parse HEAD)" >> "$R/SHAS"
  }
  nc c0 c0.sh 'fix: absorb PC-S1113-BARE-CONTROL' || exit 9
  nc s1 s1.sh 'fix: absorb PC-S1101-SUFFIXED-NORECEIPT' 'Lands the fix in core.' || exit 9
  # s2: the naming commit is the one that removes the receipt's anchor.
  printf '#!/bin/sh\n# fixed\n' > "$R/dist/core/scripts/s1103-subject.sh"
  nc s2 s2.sh 'fix: absorb PC-S1103-SUFFIXED-RECEIPTED' || exit 9
  nc s3 s3.sh 'fix: absorb BL-1104' || exit 9
  nc r1 r1.sh 'fix: absorb PC-S1105-PROSE-AFTER' || exit 9
  nc r2 r2.sh 'fix: absorb PC-S1106-COLON-NOTE' || exit 9
  nc r3 r3.sh 'fix: absorb PC-S1107-TWO-PARENS' || exit 9
  nc r4 r4.sh 'fix: absorb PC-S1108-UNCLOSED' || exit 9
  nc r5 r5.sh 'fix: absorb PC-S1109-TRAILING' || exit 9
  nc r6 r6.sh 'fix: the PC-S1110 retro lands' || exit 9
  nc r6b r6.sh 'docs: PC-S1110, recorded' || exit 9
  nc amb amb.sh 'fix: the PC-S1114 retro lands' || exit 9
  # sib: ONE commit names both, and changes only Y's anchor line of the shared file.
  printf '#!/bin/sh\n# X_ANCHOR_S1111\n:\n:\n:\n# Y fixed\n' > "$R/dist/core/scripts/sib1111.sh"
  nc sib sib.sh 'fix: absorb PC-S1112-SIB-Y' 'Touches the file PC-S1111-SIB-X also anchors on.' || exit 9
  gd rev-parse HEAD > "$R/T" || exit 9
  cat > "$R/cons/$LED" <<'LEDGER'
# Push-candidate ledger

## PC-S1113-BARE-CONTROL

A bare-id heading, named by its own commit.

## PC-S1101-SUFFIXED-NORECEIPT (filed 2026-10-27, lead session)

A suffixed heading with no receipt, named by its own commit.

## PC-S1102-NEVER-NAMED (filed 2026-10-27, lead session)

The same heading form; no commit names it.

## PC-S1103-SUFFIXED-RECEIPTED (filed 2026-10-27, lead session)

A suffixed heading with a receipt.

verify: theirs_has core/scripts/s1103-subject.sh "BUG_S1103"

## BL-1104 (filed 2026-10-28, lead session)

A suffixed BL heading.

## PC-S1105-PROSE-AFTER and BL-12 prose

Prose after the id.

## PC-S1106-COLON-NOTE: note

A colon note after the id.

## PC-S1107-TWO-PARENS (a) (b)

Two parentheticals.

## PC-S1108-UNCLOSED (unclosed

An unclosed parenthetical.

## PC-S1109-TRAILING (x) trailing

Text after the parenthetical.

## PC-S1110 (retro)

A bare sprint prefix with a parenthetical.

## PC-S1111-SIB-X (filed 2026-10-29, lead session)

The entry the shared commit does not fix.

verify: theirs_has core/scripts/sib1111.sh "X_ANCHOR_S1111"

## PC-S1112-SIB-Y (filed 2026-10-29, lead session)

The entry the shared commit fixes.

verify: theirs_has core/scripts/sib1111.sh "Y_ANCHOR_S1112"
## PC-S1114-AMB-UNNAMED (filed 2026-10-30, lead session)

A suffixed heading whose slug no commit names; its sprint prefix is cited bare by one commit.
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
[ "$(kind PC-S1113-BARE-CONTROL)" != none ] || { echo "REFUSED: the engine printed no row for the c0 control; it did not reach the naming query" >&2; exit 9; }
FAILS=0
pres() { # <cell> <label> <status> <sha cell>
  want "$1" || return 0
  local g s d w; g="$(kind "$2")"; s="${g%%	*}"; d="${g#*	}"; w="$(sha "$4")"
  if [ "$s" = "$3" ] && [ -n "$w" ] && case "$d" in *"$w"*) true ;; *) false ;; esac; then echo "ok $1: $s citing $w"
  else FAILS=$((FAILS + 1)); echo "FAIL $1: [$2] read [$s], want $3 citing ${w:-<no sha>}"; fi
}
abs() { # <cell> <label> <prefix>
  want "$1" || return 0
  local g a; g="$(kind "$2")"
  a="$(printf '%s\n' "$ROWS" | LR_P="$3" awk -F'\t' '$2 == ENVIRON["LR_P"] && $1 ~ /^NAMED-UPSTREAM/ { n++ } END { print n + 0 }')"
  if [ "$g" = none ] && [ "$a" = 0 ]; then echo "ok $1: no NAMED-UPSTREAM-family row for [$2] or [$3]"
  else FAILS=$((FAILS + 1)); echo "FAIL $1: [$2] read [${g%%	*}], prefix rows $a; want none and 0"; fi
}
pres c0 PC-S1113-BARE-CONTROL NAMED-UPSTREAM c0
pres s1 'PC-S1101-SUFFIXED-NORECEIPT (filed 2026-10-27, lead session)' NAMED-UPSTREAM s1
abs  s0 'PC-S1102-NEVER-NAMED (filed 2026-10-27, lead session)' PC-S1102
pres s2 'PC-S1103-SUFFIXED-RECEIPTED (filed 2026-10-27, lead session)' NAMED-UPSTREAM s2
pres s3 'BL-1104 (filed 2026-10-28, lead session)' NAMED-UPSTREAM s3
abs  r1 'PC-S1105-PROSE-AFTER and BL-12 prose' PC-S1105
abs  r2 'PC-S1106-COLON-NOTE: note' PC-S1106
abs  r3 'PC-S1107-TWO-PARENS (a) (b)' PC-S1107
abs  r4 'PC-S1108-UNCLOSED (unclosed' PC-S1108
abs  r5 'PC-S1109-TRAILING (x) trailing' PC-S1109
abs  r6 'PC-S1110 (retro)' PC-S1110
pres sib 'PC-S1111-SIB-X (filed 2026-10-29, lead session)' NAMED-UPSTREAM-SIBLING-ATTRIBUTED sib
pres sibY 'PC-S1112-SIB-Y (filed 2026-10-29, lead session)' NAMED-UPSTREAM sib
pres amb PC-S1114 NAMED-UPSTREAM-AMBIGUOUS amb
[ "$FAILS" -eq 0 ] || exit 1
exit 0
