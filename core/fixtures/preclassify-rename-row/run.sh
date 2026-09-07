#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# preclassify-rename-row — a file upstream RENAMED between base and theirs must classify
# as a delete of the old path plus an add of the new one, never as one six-field row.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `git diff --name-status` pairs a delete and a byte-identical add into ONE row,
# `R100<TAB>old<TAB>new`. preclassify.sh reads that stream with `read -r status path`, so
# `path` receives "old<TAB>new" joined: map_consumer() maps only the leading path, the
# consumer hash of the joined string is MISSING, and the row lands in the M arm as
# UPSTREAM-MOD+consumer-deleted->CLASSIFY -- a semantic-merge task for a file nobody
# edited -- carrying six tab-separated fields where every reader expects four.
#
# Measured on the reference consumer's 0.489.0 -> 0.490.0 dry run, the first pull after
# the first rename ever committed under core/ (a fixture transcript). Ground truth there:
# the consumer's copy of the old path equalled the base blob and theirs' new path was that
# same blob, so the correct verdicts are UPSTREAM-DELETED (gated) for the old path and
# UPSTREAM-ONLY-ADD for the new one -- exactly what the D and A arms already emit once the
# row is split. The fix is `--no-renames` on that one diff.
#
# Every assertion is PRESENCE-shaped: a named bucket on a named path. A subject that emits
# nothing fails A, B and C by construction, and the four-field arm is paired with a row
# count so an empty stream cannot satisfy it.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS, BOTH ROOTED AT THIS FILE, AND NO VERSION-MARKER WALK. This fixture SHIPS:
# install.sh lands core/fixtures/<x> at tests/fixtures/<x>, and an installed consumer has no
# VERSION file at its root (its stamp is .claude/.ai-dlc-version), so a walk up for one
# resolves to nothing there and the fixture exits 2 on every consumer push -- which is
# exactly how v0.491.0 shipped it, copied from a .dist-only sibling where the walk is fine.
# Three levels up from this file is the project root in BOTH layouts; the reconcile dir is
# then named at its distribution path and its consumer path. I106 fails the push on a
# shipping fixture that walks for VERSION.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
for cand in "$ROOT/core/skills/ai-dlc-update/reconcile" "$ROOT/.claude/skills/ai-dlc-update/reconcile"; do
  [ -f "$cand/preclassify.sh" ] && RECON="$cand" && break
done
[ -n "${RECON:-}" ] || { echo "FIXTURE ERROR: reconcile/preclassify.sh not found in either layout below $ROOT" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pc-rename.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "preclassify-rename-row"
echo "  subject: ${RECON#$ROOT/}/preclassify.sh"

# --- a synthetic distribution, two commits ------------------------------------
# base ships a fixture directory with a transcript and a runner. theirs renames the
# transcript byte-for-byte (the shape git detects as R100) and edits the runner (an M row
# in the same range, the control that ordinary rows still parse beside the split ones).
DIST="$WORK/dist"
mkdir -p "$DIST/core/fixtures/probe" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

printf '{"type":"assistant","usage":{"input_tokens":250000}}\n' > "$DIST/core/fixtures/probe/old-name.jsonl"
printf '#!/usr/bin/env bash\necho base\n' > "$DIST/core/fixtures/probe/run.sh"
printf '1.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

gitc mv core/fixtures/probe/old-name.jsonl core/fixtures/probe/new-name.jsonl
printf '#!/usr/bin/env bash\necho theirs\n' > "$DIST/core/fixtures/probe/run.sh"
printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# CAN THE SEED EXPRESS THE DEFECT? git must actually pair the two paths into a rename row
# when left to its defaults; otherwise the flag under test has nothing to split and every
# arm below passes against an unfixed subject.
_ns="$(git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/)"
if ! grep -q '^R100' <<<"$_ns"; then
  echo "FIXTURE ERROR: git did not detect the seeded move as R100, so the rename row this fixture exists for is unreachable" >&2
  exit 2
fi

# --- a consumer holding base ---------------------------------------------------
CONS="$WORK/consumer"
mkdir -p "$CONS/.claude" "$CONS/tests/fixtures/probe" || exit 2
git -C "$DIST" show "$BASE:core/fixtures/probe/old-name.jsonl" > "$CONS/tests/fixtures/probe/old-name.jsonl"
git -C "$DIST" show "$BASE:core/fixtures/probe/run.sh"        > "$CONS/tests/fixtures/probe/run.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONS/.claude/.ai-dlc-version"

run_pc() { bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
bucket_of() { # bucket_of <rows> <core-path> -> field 4 of that path's row, or empty
  printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v p="$2" '$2==p {print $4}'
}

score() { # score <recon-dir> -> prints the failing arm letters, or empty
  local rows f="" n4 n
  rows="$(run_pc "$1")"
  # A. the new path is a plain upstream add
  [ "$(bucket_of "$rows" core/fixtures/probe/new-name.jsonl)" = UPSTREAM-ONLY-ADD ] || f="${f}A"
  # B. the old path is a gated upstream delete (consumer untouched)
  [ "$(bucket_of "$rows" core/fixtures/probe/old-name.jsonl)" = UPSTREAM-DELETED ] || f="${f}B"
  # C. the ordinary M row beside them still classifies (control)
  [ "$(bucket_of "$rows" core/fixtures/probe/run.sh)" = UPSTREAM-ONLY ] || f="${f}C"
  # D. every fixture row has exactly four fields, and there are rows to count
  n="$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\//' | wc -l | tr -d ' ')"
  n4="$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '$2 ~ /^core\/fixtures\/probe\// && NF==4' | wc -l | tr -d ' ')"
  { [ "$n" -ge 3 ] && [ "$n4" = "$n" ]; } || f="${f}D"
  printf '%s' "$f"
}

# --- 1. the shipping subject ---------------------------------------------------
got="$(score "$RECON")"
if [ -z "$got" ]; then
  ok "A the renamed file's NEW path is UPSTREAM-ONLY-ADD"
  ok "B the renamed file's OLD path is UPSTREAM-DELETED (gated), not a CLASSIFY row"
  ok "C the M row beside them (run.sh) still classifies as UPSTREAM-ONLY"
  ok "D every probe row carries exactly four fields, over a non-empty row set"
else
  bad "the shipping preclassify.sh fails arm(s) [$got] on a rename row. Rows:"
  run_pc "$RECON" | sed 's/^/          /' | sed 's/\t/<TAB>/g'
fi

# --- 2. the unmutated control ---------------------------------------------------
CTRL="$WORK/control"
cp -R "$RECON" "$CTRL" || exit 2
cmp -s "$RECON/preclassify.sh" "$CTRL/preclassify.sh" || { echo "FIXTURE ERROR: control copy differs from the subject" >&2; exit 2; }
if [ -z "$(score "$CTRL")" ]; then
  ok "unmutated control: a byte-identical copy of the reconcile dir scores clean, so the harness is not what a mutant verdict measures"
else
  echo "FIXTURE ERROR: the unmutated copy fails [$(score "$CTRL")] -- the harness, not the mutation, is what the arms report" >&2
  exit 2
fi

# --- 3. THE MUTANT: remove --no-renames, guarded by cmp -s ----------------------
# The pre-fix shape. Every arm must go red at once: A and B because neither path gets its
# own row, C stays green (the M row is untouched) and is what proves the mutant did not
# simply kill the whole pass, D because the joined row carries six fields.
MUT="$WORK/mutant"
cp -R "$RECON" "$MUT" || exit 2
sed 's/diff --no-renames --name-status "\$BASE" "\$THEIRS" -- core\//diff --name-status "$BASE" "$THEIRS" -- core\//' \
  "$RECON/preclassify.sh" > "$MUT/preclassify.sh"
if cmp -s "$RECON/preclassify.sh" "$MUT/preclassify.sh"; then
  echo "FIXTURE ERROR: the mutation matched nothing -- the --no-renames line is not where this fixture expects it" >&2
  exit 2
fi
bash -n "$MUT/preclassify.sh" || { echo "FIXTURE ERROR: the mutant is not valid bash" >&2; exit 2; }
mg="$(score "$MUT")"
case "$mg" in
  ABD) ok "MUTANT (--no-renames removed) fails exactly [A B D]: both rename paths lose their bucket and a six-field row appears, while the M control stays green" ;;
  "")  bad "MUTANT SURVIVED: with --no-renames removed every arm still passes, so nothing here can see a rename row" ;;
  *)   bad "MUTANT killed by [$mg], expected exactly [ABD] -- the arms are entangled or the control row is not independent" ;;
esac

echo ""
if [ "$fails" -eq 0 ]; then
  echo "preclassify-rename-row: PASS"
  exit 0
fi
echo "preclassify-rename-row: FAIL ($fails assertion(s))"
exit 1
