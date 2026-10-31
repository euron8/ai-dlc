#!/usr/bin/env bash
# BL-872 receipt. Usage: bash core/fixtures/backlog-real-ledger/receipt-bl872.sh   (run from the repo root)
# Runs NO fixture. It reads the fixture's key rows from the hook's own composer
# (`hermetic-run.sh --key-only backlog-real-ledger`) and requires that the frozen snapshot is keyed and
# that the live ledger is not, by file row or by any directory row that covers it.
# It self-probes FIRST, in a scratch git worktree: a copy whose inputs.decl re-adds `+docs/backlog.md`
# must REFUSE, a copy with `+docs/` must REFUSE, the unmodified copy must PASS.
# 0 = the snapshot row is present and no row covers docs/backlog.md (and the probe fired both ways).
# 1 = the live ledger is keyed, or the snapshot row is absent, or zero rows were read.
# Row-set probes call judge_rows directly on seeded rows: snapshot + bare docs/, docs or docs/backlog.md must
# REFUSE; docs/plans/x.md and docsx/ must PASS; an empty set and a snapshot-less set must REFUSE.
# 2 = the receipt could not run (no composer, no git worktree, a probe that did not fire).
set -uo pipefail
# The pre-push hook exports GIT_DIR; the git calls below must act on the repository of the cwd.
r872_seam() { # walk up from $1 for the git-env seam; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/lib/preamble.sh" ]; then printf '%s\n' "$d/core/fixtures/lib/preamble.sh"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
_PRE="$(r872_seam "$(cd "$(dirname "$0")" && pwd)")" || _PRE=""
[ -n "$_PRE" ] && [ -f "$_PRE" ] || { echo "REFUSED: no git-env seam core/fixtures/lib/preamble.sh above $0" >&2; exit 2; }
. "$_PRE"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
FX=backlog-real-ledger
SNAP=core/fixtures/$FX/ledger.snapshot
[ -f core/scripts/hermetic-run.sh ] && [ -f "$SNAP" ] || { echo "REFUSED: run from the distribution root" >&2; exit 2; }

# judge_rows <rows> -> 0 pass, 1 refuse. Pure: takes the composer's row text (path<TAB>hash per line), runs no tool.
judge_rows() {
  local rows="$1" n paths
  n="$(grep -c . <<<"$rows")" || n=0
  [ "$n" -gt 0 ] || { echo "REFUSED: zero key rows read" >&2; return 1; }
  paths="$(cut -f1 <<<"$rows")"
  if ! grep -qxF "$SNAP" <<<"$paths"; then
    echo "REFUSED: the positive control row $SNAP is absent" >&2; return 1
  fi
  if grep -qxE 'docs/backlog\.md|docs/?' <<<"$paths"; then
    echo "REFUSED: a row covers docs/backlog.md" >&2; return 1
  fi
  return 0
}

# judge <root> -> 0 pass, 1 refuse. Obtains the rows from the composer, then judges them.
judge() {
  local rows
  # A declaration the composer itself rejects (it refuses `+docs/`, a directory with +) cannot be a pass.
  # The unmodified probe below proves the composer works, so a composer failure here reads as a refusal.
  rows="$(bash core/scripts/hermetic-run.sh --root "$1" --key-only "$FX" 2>/dev/null)" || { echo "REFUSED: the key composer rejected the declaration" >&2; return 1; }
  judge_rows "$rows"
}

# Row-set probes: judge_rows on seeded rows in the composer's shape (path TAB hash), bypassing the composer,
# so the directory clause is shown able to fire. A miss is PROBE DEAD.
TAB="$(printf '\t')"
H=0000000000000000000000000000000000000000000000000000000000000000
row() { printf '%s%s%s\n' "$1" "$TAB" "$H"; }
probe_rows() { # <label> <expected rc> <rows>
  local rc
  judge_rows "$3" 2>/dev/null; rc=$?
  [ "$rc" -eq "$2" ] || { echo "PROBE DEAD: row probe '$1' gave rc $rc, expected $2" >&2; exit 2; }
}
SR="$(row /bin/bash)
$(row "$SNAP")"
probe_rows "snapshot only" 0 "$SR"
probe_rows "snapshot + docs/" 1 "$SR
$(row docs/)"
probe_rows "snapshot + docs" 1 "$SR
$(row docs)"
probe_rows "snapshot + docs/backlog.md" 1 "$SR
$(row docs/backlog.md)"
probe_rows "snapshot + docs/plans/x.md" 0 "$SR
$(row docs/plans/x.md)"
probe_rows "snapshot + docsx/" 0 "$SR
$(row docsx/)"
probe_rows "empty" 1 ""
probe_rows "no snapshot" 1 "$(row /bin/bash)"

T="$(mktemp -d)" || exit 2
# Every exit path removes the worktree, the two scratch files and the directory; set BEFORE the worktree exists.
trap 'git worktree remove --force "$T/wt" >/dev/null 2>&1; rm -f "$T/decl.orig"; rmdir "$T" 2>/dev/null' EXIT
git worktree add --detach "$T/wt" HEAD >/dev/null 2>&1 || { echo "REFUSED: cannot build the probe worktree" >&2; exit 2; }
D="$T/wt/core/fixtures/$FX/inputs.decl"
[ -f "$D" ] || exit 2
cp "$D" "$T/decl.orig" || exit 2

printf '+docs/backlog.md\n' >> "$D"
judge "$T/wt" 2>/dev/null; rc=$?
[ "$rc" -eq 1 ] || { echo "PROBE DEAD: +docs/backlog.md was not refused (rc $rc)" >&2; exit 2; }
cp "$T/decl.orig" "$D"
printf '+docs/\n' >> "$D"
judge "$T/wt" 2>/dev/null; rc=$?
[ "$rc" -eq 1 ] || { echo "PROBE DEAD: +docs/ was not refused (rc $rc)" >&2; exit 2; }
cp "$T/decl.orig" "$D"
judge "$T/wt" 2>/dev/null; rc=$?
[ "$rc" -eq 0 ] || { echo "PROBE DEAD: the unmodified copy did not pass (rc $rc)" >&2; exit 2; }

judge "$(pwd)"; rc=$?
[ "$rc" -eq 0 ] && exit 0
[ "$rc" -eq 1 ] && exit 1
exit 2
