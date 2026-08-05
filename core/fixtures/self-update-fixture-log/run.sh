#!/usr/bin/env bash
# self-update-fixture-log — assert step 2's fixture run leaves evidence behind.
#
# THE LOAD-BEARING ASSERTION IS PART 3: the failing fixture's own output must still be
# readable AFTER the tree it ran in has been deleted. That is the whole defect this runner
# closes — step 2 discards the branch and restores the tree on red, so a run whose output
# lived only in the operating agent's context left the next operator with "the self-update
# failed" and nothing else. It happened twice on the reference consumer.
#
# Parts 4 and 5 are the other half, and they are not decoration: a runner that exits 0 when
# it ran nothing turns an empty set into a green suite, which is the failure mode this repo
# names "a zero is not a finding". A green run and a run that never happened must not be the
# same exit code.
#
# Usage: run.sh [path-to-self-update-fixtures.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = the harness could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
RUNNER="$(pick "${1:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$HERE/../../skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/self-update-fixtures.sh")"
[ -n "$RUNNER" ] || { echo "FIXTURE ERROR: cannot locate self-update-fixtures.sh" >&2; exit 2; }
RECONCILE="$(cd "$(dirname "$RUNNER")" && pwd)"

CONS="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$CONS"' EXIT
LOGDIR="$CONS/_bmad-output/ai-dlc-update"
DIST="$RECONCILE/../../../.."   # recorded in the header only; never read as a repo

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

newest_log() { ls -t "$LOGDIR"/self-update-fixtures-*.md 2>/dev/null | head -1; }

# --- Part 1: an all-green run exits 0 and still writes the log --------------------------
# The log is not a failure artifact. A green self-update that is later questioned needs the
# same record, and a runner that wrote only on red would have none.
rm -f "$LOGDIR"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" base-sha theirs-ref "$CONS" green-one cwd-probe >/dev/null 2>&1
rc=$?
L="$(newest_log)"
if [ "$rc" -eq 0 ] && [ -n "$L" ] && [ -s "$L" ]; then
  ok "an all-green run exits 0 and writes a non-empty log"
else
  bad "all-green run: expected rc=0 with a non-empty log, got rc=$rc log='${L:-none}'"
fi

# --- Part 2: the fixture runs from the CONSUMER ROOT ------------------------------------
if [ -n "$L" ] && grep -qF "cwd-probe ran from: $CONS" "$L"; then
  ok "the fixture is run with the consumer root current — the same directory both pre-push hooks use"
else
  bad "the fixture did not run from the consumer root. A fixture whose verdict depends on the caller's directory has shipped before (v0.263.0), so the runner deciding a self-update must stand where the gate deciding a push stands"
fi

# --- Part 3: THE DECISIVE ONE — the output outlives the tree ----------------------------
# Run a red fixture, then destroy the fixture tree exactly as step 2 does on red, and require
# the failing output to still be readable. The log is written to _bmad-output/, which the
# branch discard does not touch; a runner that buffered and wrote at exit would pass Parts 1
# and 2 and fail here, and so would one that wrote into the tree it is about to lose.
rm -f "$LOGDIR"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" base-sha theirs-ref "$CONS" green-one red-one >/dev/null 2>&1
rc=$?
L="$(newest_log)"
rm -rf "$CONS/tests"          # the branch discard, in one line
if [ "$rc" -ne 0 ] && [ -n "$L" ] && grep -qF "THE DECISIVE LINE the operator needs after the branch is gone" "$L"; then
  ok "a red run exits non-zero and its failing output survives the tree being destroyed"
else
  bad "a red run left nothing readable after the tree was discarded (rc=$rc). That is the whole defect: the record died with the branch"
fi
if [ -n "$L" ] && grep -qF "red-one: and a stderr line too" "$L"; then
  ok "stderr is captured too — a fixture that reports its failure on stderr is the common case"
else
  bad "the log captured stdout only; a fixture failing on stderr would leave a log that reads clean"
fi
if [ -n "$L" ] && grep -qF "green-one: every assertion held" "$L"; then
  ok "the green fixture's output is in the same log — the reader can see what DID pass alongside what did not"
else
  bad "only the failing fixture was logged; without the passing ones the reader cannot tell a broken slice from a broken harness"
fi

# --- Part 4: an EMPTY set must not read as green ----------------------------------------
bash "$RUNNER" "$DIST" base-sha theirs-ref "$CONS" >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "naming no fixtures exits 2, not 0 — 'no failures' and 'no assertions' are not the same answer"
else
  bad "naming no fixtures did not exit 2. An empty set reporting green is how a self-update ships having verified nothing"
fi

# --- Part 5: a named fixture with no driver is not a pass -------------------------------
# The derived set comes from the distribution; if the slice did not write one of them, that is
# a finding about the CYCLE. Counting it green is how a missing file becomes a silent skip.
bash "$RUNNER" "$DIST" base-sha theirs-ref "$CONS" never-written-by-the-slice >/dev/null 2>&1
if [ $? -ne 0 ]; then
  ok "a named fixture whose driver the slice never wrote is not counted as a pass"
else
  bad "a named fixture with no run.sh scored as green — a slice that wrote nothing would report a clean suite"
fi

# --- Part 6: the log extension is one git can still show ---------------------------------
# A reference consumer's .gitignore carries `*.log` and `*.txt`. Either would produce an
# artifact that exists on disk and is invisible to every `git status` the operator reads.
if [ -n "$L" ] && case "$L" in *.md) true ;; *) false ;; esac; then
  ok "the log is written as .md — not an extension a consumer's .gitignore commonly swallows"
else
  bad "the log is '${L:-none}'. A .log or .txt artifact is on disk and absent from git status, which is how evidence goes missing twice"
fi

# --- MUTATION: prove Part 4 can fail -----------------------------------------------------
# The runner sources nothing from its own directory, so a lone copy is a working harness here
# — but the copy is still taken beside the original and checked with an unmutated control,
# because "the mutant emitted nothing" and "the mutant survived" are the same bytes.
MUTDIR="$(mktemp -d)"; trap 'rm -rf "$CONS" "$MUTDIR"' EXIT
cp "$RECONCILE"/*.sh "$MUTDIR"/ 2>/dev/null
MUT="$MUTDIR/self-update-fixtures.sh"
CTL="$MUTDIR/control-unmutated.sh"; cp "$RUNNER" "$CTL"
MUT_OLD='  exit 2
fi

SELF='
MUT_NEW='  exit 0
fi

SELF='
MUT_OLD="$MUT_OLD" MUT_NEW="$MUT_NEW" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$RUNNER" "$MUT" 2>/dev/null
if [ ! -s "$MUT" ] || cmp -s "$RUNNER" "$MUT"; then
  bad "FIXTURE ERROR: the empty-set mutation matched nothing — Part 4 proves nothing. Update MUT_OLD to match the runner's real empty-set guard"
else
  bash "$CTL" "$DIST" base-sha theirs-ref "$CONS" >/dev/null 2>&1
  if [ $? -eq 2 ]; then
    ok "CONTROL: the unmutated copy still exits 2 on an empty set — the mutant verdict below is its edit"
  else
    bad "FIXTURE ERROR: the unmutated copy did not exit 2, so the copied harness is what is being measured"
  fi
  bash "$MUT" "$DIST" base-sha theirs-ref "$CONS" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ok "MUTATION — with the empty-set guard returning 0, naming nothing reads as a green suite: Part 4 is what catches that"
  else
    bad "MUTATION — the empty-set guard was neutered and the runner still refused; Part 4's assertion is vacuous"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "self-update-fixture-log: PASS"
  exit 0
fi
echo "self-update-fixture-log: FAIL ($fails)"
exit 1
