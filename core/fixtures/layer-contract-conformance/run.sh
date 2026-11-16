#!/usr/bin/env bash
# layer-contract-conformance — the layer contract (core/skills/ai-dlc/layer-contract.yaml) holds against
# scripts/validate-enforcement-map.sh: I36/I37/I38/I41/I42/I61/I62/I63/I64/I65 report nothing on the shipping
# contract, and the in-process `vem_entry` answers byte for byte what the validator CLI answers.
#
# SHARDED: shard 'b' is layer-contract-conformance-b/run.sh, which execs this file with `--group b`. Shard 'a'
# runs the unmutated control and the arms that read it; both shards run the in-process-versus-CLI twin.
#
# Usage: run.sh [--group <a|b>]
# Exit:  0 = every assertion in this shard holds, 1 = one regressed, 2 = fixture broken.
set -u
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# I10 — a fixture must not inherit an ambient tunable that changes what it measures.
unset AI_DLC_LAYER_CONTRACT

# Locate the validator and the contract in BOTH layouts. This validator is
# distribution-only (scripts/, not core/scripts/), so a consumer tree has neither and the
# fixture declares itself inapplicable rather than failing.
VAL=""; CONTRACT=""
for cand in "$DIR/../../../scripts/validate-enforcement-map.sh"; do
  [ -f "$cand" ] && VAL="$cand"
done
for cand in "$DIR/../../skills/ai-dlc/layer-contract.yaml" \
            "$DIR/../../../core/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$cand" ] && CONTRACT="$cand" && break
done
# THE SHARD'S NAME IS DERIVED BEFORE THE SKIP, AND ONLY THE NAME. Shard 'b' `exec`s this file by path, so `$0`
# here names THIS directory in both shards and only the `--group` argument tells them apart.
GROUP=a
while [ $# -gt 0 ]; do
  case "$1" in
    --group)
      GROUP="${2:-}"
      [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
      shift; [ $# -gt 0 ] && shift ;;
    *) echo "FIXTURE ERROR: unknown argument '$1' (known: --group <shard>)" >&2; exit 2 ;;
  esac
done
NAME="layer-contract-conformance"
[ "$GROUP" = a ] || NAME="layer-contract-conformance-$GROUP"
SKIP_MSG="SKIP — validate-enforcement-map.sh is distribution-only and is not installed in a consumer tree."
if [ -z "$VAL" ] || [ -z "$CONTRACT" ]; then
  echo "$NAME: $SKIP_MSG"
  fx_skip_exit "$DIR"
fi
REPO="$(cd "$(dirname "$VAL")/.." && pwd)"
echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh"
# fx_inproc (one row per in-process vem_entry pass, BL-982) comes from lib/mutant.sh, which refuses to load
# without ok() and bad().
[ -f "$DIR/../lib/mutant.sh" ] || { echo "$NAME: FIXTURE ERROR -- lib/mutant.sh not found beside $DIR" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "$NAME: FIXTURE ERROR -- lib/report.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# ---------------------------------------------------------------------------
# THE SHARD SPLIT
# ---------------------------------------------------------------------------
# IT IS PLACED AFTER THE SKIP ABOVE, DELIBERATELY. On a consumer neither directory resolves $VAL, so both take that
# SKIP and exit 0 before any of this runs; hoisting the shard protocol above it would make a consumer's exit depend
# on whether a sibling directory was installed.
SHARDS="a b"

# THE SHARD ARRIVES AS AN ARGUMENT, NOT AS AN ENVIRONMENT VARIABLE: this file unsets AI_DLC_* above, and an
# argument cannot be scrubbed.
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac

# THE COVERAGE JOIN. Shard `a` DERIVES the set of shards that exist beside it and refuses to pass if any declared
# shard has no driver.
if [ "$GROUP" = a ]; then
  missing=""
  for _s in $SHARDS; do
    [ "$_s" = a ] && continue
    [ -f "$DIR/../layer-contract-conformance-$_s/run.sh" ] || missing="$missing $_s"
  done
  if [ -n "$missing" ]; then
    echo "FIXTURE ERROR: shard(s)$missing declared in SHARDS have no driver directory beside this one." >&2
    echo "  Their assertions would run NOWHERE, and this suite would report a shorter green run." >&2
    exit 2
  fi
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/layer-contract-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUTD="$TMP/out"; mkdir -p "$OUTD"
TWD="$TMP/twin"; mkdir -p "$TWD"

echo "$NAME fixture"
echo

# THE UNMUTATED CONTROL AND THE CLI-REFUSE INPUT. The control is the real contract, copied. The refuse input is
# the same contract with LC-O1's code renamed to one no enforcer emits, so `--arms I36` exits 1 on it and 0 on the
# control: the two outcomes the twin compares differ in the input alone.
cp "$CONTRACT" "$TMP/control.yaml"
sed 's/^    code: E1$/    code: E99/' "$CONTRACT" > "$TMP/refuse.yaml"
if cmp -s "$CONTRACT" "$TMP/refuse.yaml"; then
  echo "$NAME: FIXTURE ERROR — the cli-refuse input is byte-identical to the contract, so the twin's two outcomes cannot differ" >&2
  exit 2
fi
SEL=I36

# ip_run <out-prefix> <contract-file> <FULL|I<n>[,I<n>...]> runs the validator IN PROCESS: `vem_entry` exists only
# inside the subshell below that sources the validator once by absolute path. Each call is its own `( … )`, so the
# validator's `exit` and `cd` end there and the contract is exported into that subshell alone. stdout and stderr
# are kept apart because the twin compares them byte for byte.
ip_run() {
  if [ "$3" = FULL ]; then
    fx_inproc "$VAL_ABS"
    ( export AI_DLC_LAYER_CONTRACT="$2"; vem_entry ) > "$1.o" 2> "$1.e"
  else
    fx_inproc "$VAL_ABS"
    ( export AI_DLC_LAYER_CONTRACT="$2"; vem_entry --arms "$3" ) > "$1.o" 2> "$1.e"
  fi
  printf '%s' "$?" > "$1.rc"
}

VAL_ABS="$REPO/scripts/validate-enforcement-map.sh"
(
  . "$VAL_ABS" || exit 2
  ( ip_run "$TWD/pass.ip" "$TMP/control.yaml" "$SEL" ) &
  FXCELL=cli-pass AI_DLC_LAYER_CONTRACT="$TMP/control.yaml" \
    bash "$VAL_ABS" --arms "$SEL" > "$TWD/pass.cl.o" 2> "$TWD/pass.cl.e" &
  _pp=$!
  FXCELL=cli-refuse AI_DLC_LAYER_CONTRACT="$TMP/refuse.yaml" \
    bash "$VAL_ABS" --arms "$SEL" > "$TWD/refuse.cl.o" 2> "$TWD/refuse.cl.e" &
  _rp=$!
  ( ip_run "$TWD/refuse.ip" "$TMP/refuse.yaml" "$SEL" ) &
  [ "$GROUP" = a ] && ip_run "$OUTD/control" "$TMP/control.yaml" FULL
  wait "$_pp"; printf '%s' "$?" > "$TWD/pass.cl.rc"
  wait "$_rp"; printf '%s' "$?" > "$TWD/refuse.cl.rc"
  wait
)

# ---------------------------------------------------------------------------
# THE ARMS THAT READ THE CONTROL — shard 'a' only
# ---------------------------------------------------------------------------
if [ "$GROUP" = a ]; then
  # EXIT 2 IS A BROKEN FIXTURE, AND IT IS NEITHER A PASS NOR A FAILURE: a run under a bad selector or a
  # validator that did not reach its verdict block produces no FAIL lines at all.
  _crc="$(cat "$OUTD/control.rc" 2>/dev/null || true)"
  if [ -z "$_crc" ] || [ "$_crc" = 2 ]; then
    echo "$NAME: FIXTURE ERROR — the control run of validate-enforcement-map.sh produced no verdict (rc [${_crc}])" >&2
    head -2 "$OUTD/control.e" >&2 2>/dev/null
    exit 2
  fi
  cat "$OUTD/control.o" "$OUTD/control.e" > "$OUTD/control.raw"
  grep '^FAIL' "$OUTD/control.raw" > "$OUTD/control.txt" || :

  # THE CONTROL: the real contract passes the whole validator, so nothing below is read against a dirty run.
  if [ ! -s "$OUTD/control.txt" ]; then
    ok "control            clean  (the real contract passes)"
  else
    bad "control            the real contract already fails"
    sed 's/^/          | /' "$OUTD/control.txt" | head -5
  fi
  # I64 and I65 are silent on the shipping contract.
  if grep -q '^FAIL: I64' "$OUTD/control.txt"; then
    bad "i64-control        I64 fires on the shipping contract"
  else
    ok "i64-control        I64 is silent on the shipping contract"
  fi
  if grep -q '^FAIL: I65' "$OUTD/control.txt"; then
    bad "i65-control        I65 fires on the shipping contract"
  else
    ok "i65-control        I65 is silent on the shipping contract"
  fi

  # ---------------------------------------------------------------------------
  # THE CONSUMER SKIP NAMES ITS OWN SHARD
  # ---------------------------------------------------------------------------
  # On a consumer neither directory resolves $VAL, both take the SKIP, and the runner's log is read BY NAME. This
  # builds that tree: copies of both drivers in the consumer layout, tests/fixtures/, three levels below a scratch
  # root, so `$DIR/../../../scripts/` and both contract candidates resolve to nothing, and runs each. Shard 'b'
  # must print ITS name and never this directory's.
  _SK="$TMP/skip-name"
  mkdir -p "$_SK/x/y/tests/fixtures/layer-contract-conformance" "$_SK/x/y/tests/fixtures/layer-contract-conformance-b" \
           "$_SK/x/y/tests/fixtures/lib" \
    && cp "$DIR/run.sh" "$_SK/x/y/tests/fixtures/layer-contract-conformance/run.sh" \
    && cp "$DIR/../layer-contract-conformance-b/run.sh" "$_SK/x/y/tests/fixtures/layer-contract-conformance-b/run.sh" \
    && cp "$DIR/../lib/layout.sh" "$_SK/x/y/tests/fixtures/lib/layout.sh" \
    || { echo "$NAME: FIXTURE ERROR — could not build the consumer-shaped SKIP tree" >&2; exit 2; }
  _sk_a="$(bash "$_SK/x/y/tests/fixtures/layer-contract-conformance/run.sh" 2>&1)"
  _sk_b="$(bash "$_SK/x/y/tests/fixtures/layer-contract-conformance-b/run.sh" 2>&1)"
  if grep -q '^layer-contract-conformance: SKIP' <<<"$_sk_a" \
     && grep -q '^layer-contract-conformance-b: SKIP' <<<"$_sk_b" \
     && ! grep -q '^layer-contract-conformance: SKIP' <<<"$_sk_b"; then
    ok "skip-name          on a consumer-shaped tree each shard's SKIP line names its own directory"
  else
    bad "skip-name          the consumer SKIP lines do not name their shards — a: [${_sk_a}] b: [${_sk_b}]"
  fi
fi

# ---------------------------------------------------------------------------
# THE IN-PROCESS ANSWER EQUALS THE CLI ANSWER — both shards
# ---------------------------------------------------------------------------
# Each outcome is compared byte for byte (stdout, stderr, exit) with the in-process answer on the SAME input:
#   cli-pass    the unmutated contract under `--arms I36`, exit 0;
#   cli-refuse  the refuse input under the same selector, exit 1.
# The two outcomes must differ in exit code and in output, so two drives that both ran nothing cannot agree into
# a pass. Neither is a FULL run: the whole-file entry's in-process/CLI equivalence is owned by
# enforcement-map-sites.
_why=""
for _t in pass refuse; do
  for _x in o e rc; do
    cmp -s "$TWD/$_t.ip.$_x" "$TWD/$_t.cl.$_x" || _why="$_why $_t.$_x"
  done
done
[ "$(cat "$TWD/pass.ip.rc" 2>/dev/null)" = 0 ] && [ "$(cat "$TWD/refuse.ip.rc" 2>/dev/null)" = 1 ] \
  || _why="$_why exit(pass=$(cat "$TWD/pass.ip.rc" 2>/dev/null) refuse=$(cat "$TWD/refuse.ip.rc" 2>/dev/null))"
grep -q '^OK' "$TWD/pass.ip.o" && grep -q '^FAIL' "$TWD/refuse.ip.e" || _why="$_why outcome-lines"
cmp -s "$TWD/pass.ip.e" "$TWD/refuse.ip.e" && _why="$_why pass-and-refuse-stderr-identical"
if [ -z "$_why" ]; then
  ok "vem-cli-twin: in-process vem_entry equals bash validate-enforcement-map.sh byte for byte (stdout, stderr, exit) on a pass (rc 0) and on a refused contract (rc 1)"
else
  bad "vem-cli-twin: the in-process answer differs from the CLI, or the two outcomes did not separate:$_why"
fi

# THE ASSERTION-COUNT FLOOR, per shard: a shard that stops evaluating an arm prints a shorter green report, which
# reads exactly like a passing one.
EXPECTED_ASSERTIONS=1; [ "$GROUP" = a ] && EXPECTED_ASSERTIONS=5

echo
report_end "$NAME" "$EXPECTED_ASSERTIONS"
