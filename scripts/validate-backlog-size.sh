#!/usr/bin/env bash
# validate-backlog-size.sh -- docs/backlog.md is a QUEUE, and a queue has a depth.
#
# Distribution-only. A consumer tree has no docs/backlog.md, and install.sh copies from
# core/scripts/ only, so nothing here ships.
#
# WHY THIS IS NOT INSIDE ONE OF THE TWO FILES THAT ALREADY OWN THIS LEDGER. Neither can gate.
# `backlog-reverify.sh`'s own header declares it a CLASSIFIER, not a gate -- exit 0 ALWAYS, the
# caller decides -- and it costs 52-71s because it evals every receipt. `backlog-rotate.sh`
# takes an early `exit 0` at :202-206 the moment no entry carries the close annotation, which is
# exactly the state a ledger is in when it is at its LONGEST, and is this tree's state today
# (measured: 0 entries carry `**LANDED (v`). A ceiling sited after that return is a check that
# cannot fire. Neither script runs at pre-push at all.
#
# WHY NOT AN ARM IN validate-enforcement-map.sh. Measured 20.2s per run, referenced from 36
# fixture directories, and the two mutation batteries at #2/#3 of the duration table drive it
# through ~20 and ~17 mutants each. It is also the only file carrying FORK_BUDGET. This is the
# same reasoning .githooks/pre-push already records for validate-shell-portability.sh.
#
# WHY NOT AN ARM IN validate-claude-rules.sh, which owns the repo's other ceiling. A6 sums BYTES
# over `durable_files()` = CLAUDE.md + the unconditional .claude/rules/*.md; an entry COUNT over
# a different corpus cannot be added to that sum. That file's declared subject is the join
# between CLAUDE.md and .claude/rules/*.md, and every helper it owns parses rule frontmatter.
# The reuse would have been ~15 lines of boilerplate, against making the rules validator source
# the reconcile library for one arm about an unrelated file.
#
# NEITHER THE BOUNDARY NOR THE LABEL RULE IS RESTATED HERE. Both come from reconcile/lib.sh --
# `ledger_entry_awk` and `backlog_entry_label_awk` -- whose header records that two hand-copies of
# the boundary DRIFTED WITHIN ONE RELEASE. The label rule was moved there by this change, because
# the first draft of this file restated it and that is the same defect one file over.
#
# DO NOT SUBSTITUTE `ledger_entry_id()`. It is backtick-tolerant by design (lib.sh's header says
# so), and this ledger's callers do not strip backticks, so it OVER-COUNTS by 3: the prose
# cross-reference bullets `- **`BL-081`'s receipt**` and its two siblings at
# docs/backlog.md:174/181/186 score as entries. Measured 68 against 65, where 65 is what both
# `grep -c '^## BL-'` and backlog-reverify.sh's own distinct-label count return.
#
# AND DO NOT SUBSTITUTE A HEADING GREP, WHICH FAILS IN THE OTHER DIRECTION. `^## BL-` MISSES the
# `### BL-` and `- **BL-` forms the ledger's own tooling accepts -- measured, a seeded h3 entry
# and a seeded bullet entry take this arm from 65 to 67 while `grep -c '^## BL-'` stays at 65, so
# the ceiling would be evadable by heading level. An UNANCHORED heading grep reads 68 instead, on
# three DIFFERENT lines from the `ledger_entry_id()` trap: BL-091's prose and receipt, which quote
# the heading pattern. Three plausible spellings, three wrong answers; the sourced pair is the
# only reading that is right in both directions.
#
# THE CEILING IS A POLICY NUMBER, NOT A MEASUREMENT, and it is the operator's to set;
# `AI_DLC_BACKLOG_MAX_ENTRIES` overrides it the way `AI_DLC_DURABLE_BYTES` overrides A6's.
#
# IT BOUNDS ENTRIES AND NOT BYTES, AND THAT WAS MEASURED RATHER THAN ASSUMED. A byte clause was
# specified, built, and withdrawn. Rotation is the only sanctioned lever on this file --
# backlog-rotate.sh:14, "IT MOVES, IT NEVER DELETES" -- and rotation is denominated in ENTRIES.
# Archived entries average 7193 bytes against a live mean of 3758 (n=27 and n=65), so archiving
# one entry frees 1.9x the live mean and the entry ceiling already bounds bytes at roughly 7KB
# granularity. A byte ceiling calibrated to admit the same growth sat within 1.5% of this one and
# bound FIRST, which would have made this clause vacuous. And at all four states where such a
# clause approached firing -- c01d588a 279422B, 890b921b 275114B, 727ddc6c 271884B, and HEAD --
# the count of rotatable entries was ZERO, so its sanctioned remedy was a measured no-op exactly
# when it fired. A per-entry byte cap fails too: 10 of 27 archived entries exceed 8000 bytes and
# the largest is 16137, so any cap low enough to bind has a false-positive set of legitimate
# entries.
#
# THE ARCHIVE IS UNBOUNDED BY DESIGN and is deliberately never opened. docs/backlog.archive.md is
# a LOG -- rotate appends and never deletes -- so bounding it would make the only legal remedy for
# this arm illegal. The OK line says the archive was not read, because "exempt by design" and
# "nobody thought about it" are otherwise the same silence.
#
# THE MEASURED FALSE-POSITIVE SET IS ONE COMMIT IN 42. Across every commit that has touched this
# file the count has never exceeded 68, so this ceiling would have fired zero times; the one state
# it blocks is a bulk triage filing like 158d7528, which added 42 entries at once without
# rotating. The remedy is rotation, not a raise.
#
# THERE IS NO PATH WHERE AN ABSENT OR UNREADABLE LEDGER RETURNS 0. The `-f` test below exits 2,
# and a file that exists but parses to zero entries exits 1 -- an empty parse and a fully-rotated
# ledger are the same zero, and passing over it is how a ceiling stops observing anything.
#
# Usage: validate-backlog-size.sh [<ledger>] [--quiet]   (default: <repo-root>/docs/backlog.md)
# Exit:  0 = under the ceiling; 1 = over it, or the ledger parsed to zero; 2 = usage/environment.
set -uo pipefail

QUIET=0
LEDGER=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    -*)      echo "usage: validate-backlog-size.sh [<ledger>] [--quiet]" >&2; exit 2 ;;
    *)       LEDGER="$1"; shift ;;
  esac
done

# Resolve the root by walking UP for a marker, never by counting `..` hops -- this script must
# give the same answer from the repo root, from a subdirectory, and from a fixture sandbox that
# copied it, and the sandbox answer is the silent one.
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/VERSION" ] || { echo "validate-backlog-size: FAIL -- no VERSION marker above $0" >&2; exit 2; }

LIB="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
[ -f "$LIB" ] || { echo "validate-backlog-size: FAIL -- reconcile/lib.sh missing; refusing to fall back to a private copy of the entry-boundary rule" >&2; exit 2; }
# shellcheck source=../core/skills/ai-dlc-update/reconcile/lib.sh
. "$LIB" || { echo "validate-backlog-size: FAIL -- cannot source $LIB" >&2; exit 2; }

DEFAULTED=0
[ -n "$LEDGER" ] || { LEDGER="$ROOT/docs/backlog.md"; DEFAULTED=1; }
[ -f "$LEDGER" ] || { echo "validate-backlog-size: FAIL -- $LEDGER is not a file" >&2; exit 2; }

MAX="${AI_DLC_BACKLOG_MAX_ENTRIES:-75}"
case "$MAX" in
  ''|*[!0-9]*) echo "validate-backlog-size: FAIL -- AI_DLC_BACKLOG_MAX_ENTRIES is not a non-negative integer: '$MAX'" >&2; exit 2 ;;
esac

# The awk program is built OUTSIDE a command substitution, deliberately: bash 3.2's `$( )` parser
# counts parentheses across a heredoc body and does not exempt it. See backlog-reverify.sh:87.
AWKF="$(mktemp)" || { echo "validate-backlog-size: FAIL -- mktemp" >&2; exit 2; }
probe="$(mktemp -d)" || { echo "validate-backlog-size: FAIL -- mktemp -d" >&2; exit 2; }
trap 'rm -rf "$probe" "$AWKF"' EXIT

{ ledger_entry_awk; backlog_entry_label_awk; cat <<'AWK'
{ if (backlog_entry_label($0) != "") n++ }
END { print n+0 }
AWK
} > "$AWKF"

count_entries() { awk -f "$AWKF" "$1"; }

# ---------------------------------------------------------------------------
# THE SELF-PROBE RUNS BEFORE THE CORPUS, IN BOTH DIRECTIONS. An arm reporting "under the ceiling"
# without first proving it can produce a breach has established that it ran, not that the ledger
# is short. The probe tree is under mktemp and is never the real corpus.
# ---------------------------------------------------------------------------
seed() { i=1; : > "$2"; while [ "$i" -le "$1" ]; do printf '## BL-%03d — seeded\n\nverify: manual\n\n' "$i" >> "$2"; i=$((i+1)); done; }
seed 3 "$probe/over.md"; seed 2 "$probe/at.md"
p_over="$(count_entries "$probe/over.md")"; p_at="$(count_entries "$probe/at.md")"
if [ "$p_over" != "3" ] || [ "$p_at" != "2" ]; then
  echo "validate-backlog-size: SELF-PROBE FAILED -- the entry counter read ${p_over}/3 and ${p_at}/2 on seeded ledgers, so it cannot be trusted on the real one and nothing below is a reading." >&2
  exit 2
fi
if ! { [ "$p_over" -gt 2 ] && [ "$p_at" -le 2 ]; }; then
  echo "validate-backlog-size: SELF-PROBE FAILED -- the comparison does not discriminate 3 from 2 at a ceiling of 2." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# B1 -- docs/backlog.md carries at most AI_DLC_BACKLOG_MAX_ENTRIES entries.
# ---------------------------------------------------------------------------
N="$(count_entries "$LEDGER")"
if [ "$N" -eq 0 ]; then
  echo "FAIL: B1: $LEDGER parsed to ZERO entries. An empty parse and a fully-rotated ledger are the same zero, so this is reported rather than passed over -- the count is not a reading." >&2
  exit 1
fi
if [ "$N" -gt "$MAX" ]; then
  echo "FAIL: B1: $LEDGER carries ${N} entries against a ceiling of ${MAX}. This ledger is a QUEUE; past this depth nobody reads it end to end and entries get re-filed rather than found. Run scripts/backlog-reverify.sh, annotate what has landed as '**LANDED (v<version>, verified <sha>).**', then scripts/backlog-rotate.sh --check --apply. Raising AI_DLC_BACKLOG_MAX_ENTRIES is the operator's call and the last resort." >&2
  exit 1
fi
if [ "$QUIET" != "1" ]; then
  if [ "$DEFAULTED" = "1" ]; then
    echo "OK: validate-backlog-size -- B1 ${N}/${MAX} entries in docs/backlog.md (probe fired both directions; docs/backlog.archive.md deliberately NOT read -- it is an append-only log and unbounded by design)."
  else
    echo "OK: validate-backlog-size -- B1 ${N}/${MAX} entries in ${LEDGER} (probe fired both directions)."
  fi
fi
exit 0
