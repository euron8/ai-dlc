#!/usr/bin/env bash
# backlog-receipt-fixture-join -- the receipt / fixture-arm join (BL-278), moved out of
# core/fixtures/backlog-receipt-binding/ by BL-918 so that a docs/backlog.archive.md edit keys only
# this unit and never that fixture's validator battery. It runs no shipped script and builds no git
# repository: it derives BL-040's archived receipt, builds every seed shape gate-verdict-grep-shape
# declares over a copy of gate-validation.md, and checks each receipt-blind shape has a row that
# fixture's own oracle reproduces. The arm below is the block that ran in backlog-receipt-binding,
# unchanged.
#
# The mutant matrix. The two self-probes that edit a copy of gate-verdict-grep-shape's verdict table
# are this unit's mutants, and each is decided by the one scan over its own copy. The receipt-owned
# row deletion is the near-miss control, which must stay quiet. The fixture always runs all three,
# so the REMEASURE command below is the plain run: run.sh takes no mode and runs every world.
# MUTANT-MATRIX-FULL probe-off worlds=rj-probe-offender why=the deleted comment row must be named UNCOVERED by the one scan over its copy
# MUTANT-MATRIX-FULL probe-relabel worlds=rj-probe-relabel why=the relabelled comment row must be named UNREPRODUCED by the one scan over its copy
# MUTANT-MATRIX-CONTROL probe-nm why=deleting a receipt-owned row must stay quiet, so the scan does not flag every deletion
# MUTANT-MATRIX-REMEASURE bash core/fixtures/backlog-receipt-fixture-join/run.sh --matrix
#
# Usage: run.sh
# Exit:  0 = the join holds and every self-probe fired, 1 = a finding, 2 = fixture broken.
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

# ===== THE RECEIPT / FIXTURE-ARM JOIN (BL-278). ==============================================
# A closed entry's receipt and the fixture arms covering the same subject divide the work: the
# receipt establishes the fix is present, the arms establish what the receipt cannot express. That
# division lived in a COMMENT in gate-verdict-grep-shape, and a comment goes stale in silence -- the
# next hand to widen the receipt reads an arm as redundant and deletes it. This arm asserts it.
#
# THE RECEIPT IS DERIVED, NEVER COPIED. It is read out of BL-040's archived entry at run time, so
# there is no second definition to drift; the entry id is the join key, the body is not in this
# file. A hardcoded body is the defect one level down, and BL-278's own receipt refuses it.
#
# THE SHAPES ARE DERIVED FROM THE PRODUCER. Every `mode == "..."` branch of gate-verdict-grep-shape's
# seed builder is a shape somebody decided to seed; each is built over a copy of gate-validation.md
# and the derived receipt run against it. A shape on which the receipt exits 0 is RECEIPT-BLIND --
# the receipt would close the entry over it -- so it MUST carry a row in one of that fixture's
# three verdict tables, and that row's verdict must be what that fixture's own join oracle actually
# returns on the seed: a row that is listed but not reproduced is not coverage, and a blind shape
# relabelled as a GREEN near-miss is the receipt's blindness blessed. A shape the receipt
# already fails (non-zero, STILL-LIVE in backlog-reverify.sh's polarity) is receipt-owned and needs
# no row. Known limit: deleting a seed branch AND its row together is invisible here.
#
# SELF-PROBED BEFORE THE CORPUS, IN BOTH DIRECTIONS, through the SAME scan function: a copy of the
# fixture with the `comment` row deleted must be reported UNCOVERED by name (a receipt-blind shape),
# and a copy with the `no-read` row deleted must stay quiet (the receipt exits 1 there, so it owns
# it). The two copies are one property apart and each is cmp-guarded, so a deletion that matched
# nothing cannot pass as a probe.
RJ_GVGS=""; RJ_GATE=""; RJ_ARCHIVE=""
for cand in "$DIR/../gate-verdict-grep-shape/run.sh"; do
  [ -f "$cand" ] && RJ_GVGS="$cand" && break
done
for cand in "$DIR/../../skills/ai-dlc/steps/gate-validation.md" "$DIR/../../../.claude/skills/ai-dlc/steps/gate-validation.md"; do
  [ -f "$cand" ] && RJ_GATE="$cand" && break
done
for cand in "$DIR/../../../docs/backlog.archive.md" "$DIR/../../docs/backlog.archive.md"; do
  [ -f "$cand" ] && RJ_ARCHIVE="$cand" && break
done
if [ -z "$RJ_GVGS" ] || [ -z "$RJ_GATE" ] || [ -z "$RJ_ARCHIVE" ]; then
  echo "FIXTURE BROKEN: receipt join cannot resolve gvgs='$RJ_GVGS' gate='$RJ_GATE' archive='$RJ_ARCHIVE'" >&2; exit 2
fi
echo "HERMETIC-CONSUMED core/fixtures/gate-verdict-grep-shape/run.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc/steps/gate-validation.md"
RJ_ID="BL-040"
RJ_REC="$(awk -v id="$RJ_ID" '$0 == "## " id || index($0, "## " id " ") == 1 { f = 1; next }
  f && /^## / { exit }
  f && /^verify: sh / { sub(/^verify: sh /, ""); print; exit }' "$RJ_ARCHIVE")"
if [ -z "$RJ_REC" ]; then
  echo "FIXTURE BROKEN: no 'verify: sh' receipt derivable for $RJ_ID from $RJ_ARCHIVE" >&2; exit 2
fi
RJ="$TMP/rj"; mkdir -p "$RJ/tree/core/skills/ai-dlc/steps"
RJ_TGT="$RJ/tree/core/skills/ai-dlc/steps/gate-validation.md"

# rj_scan <gvgs-run.sh> -> one line per finding, then "SCANNED <n> BLIND <b> OWNED <o>".
# Exit 2 when the harness itself could not measure (a heredoc not found, a seed that did not build).
rj_scan() {
  local g="$1" w m want got r
  w="$(mktemp -d "$RJ/scan.XXXXXX")" || { echo "HARNESS mktemp failed"; return 2; }
  awk '/<<.GVSEEDPY.$/ { f = 1; next } /^GVSEEDPY$/ { f = 0 } f' "$g" > "$w/seed.py"
  awk '/<<.GVJOINPY.$/ { f = 1; next } /^GVJOINPY$/ { f = 0 } f' "$g" > "$w/join.py"
  [ -s "$w/seed.py" ] && [ -s "$w/join.py" ] || { echo "HARNESS seed.py or join.py not extractable"; return 2; }
  awk '/<<.GVMUTANTS.$/ { t = "M"; next } /<<.GVBOUNDS.$/ { t = "B"; next } /<<.GVNEARMISS.$/ { t = "N"; next }
    /^GV(MUTANTS|BOUNDS|NEARMISS)$/ { t = ""; next }
    t != "" && NF { split($0, a, "|"); w = (t == "M") ? a[2] : (t == "B") ? "BLOWN" : "GREEN"; print a[1] "|" w }' "$g" > "$w/rows"
  grep -oE 'mode == "[a-z0-9-]+"' "$w/seed.py" | sed 's/^mode == "//; s/"$//' > "$w/modes"
  local n=0 b=0 o=0
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    python3 "$w/seed.py" "$RJ_GATE" "$RJ_TGT" "$m" >/dev/null 2>&1 || { echo "HARNESS seed $m did not build"; return 2; }
    cmp -s "$RJ_GATE" "$RJ_TGT" && { echo "HARNESS seed $m changed no bytes"; return 2; }
    n=$((n + 1))
    ( cd "$RJ/tree" && bash -c "$RJ_REC" </dev/null >/dev/null 2>&1 ); r=$?
    if [ "$r" -ne 0 ]; then o=$((o + 1)); continue; fi
    b=$((b + 1))
    want="$(awk -F'|' -v m="$m" '$1 == m { print $2; exit }' "$w/rows")"
    if [ -z "$want" ]; then echo "UNCOVERED $m"; continue; fi
    got="$(python3 "$w/join.py" "$RJ_TGT" join 2>/dev/null)"
    case "$got" in "$want"*) ;; *) echo "UNREPRODUCED $m listed $want, oracle read '${got%% *}'" ;; esac
  done < "$w/modes"
  echo "SCANNED $n BLIND $b OWNED $o"
}

# Positive control first: the derived receipt must CLOSE on the live file, or every "blind" below
# is a receipt that fails everywhere rather than a shape it cannot see.
cp "$RJ_GATE" "$RJ_TGT"
( cd "$RJ/tree" && bash -c "$RJ_REC" </dev/null >/dev/null 2>&1 ); rj_live=$?
if [ "$rj_live" -ne 0 ]; then
  note "FAIL  rj-control -- $RJ_ID's derived receipt exits $rj_live on the live gate-validation.md, so it cannot distinguish any shape from the fix"; rc=1
else
  note "ok    rj-control -- $RJ_ID's receipt, derived from the archive, closes on the live gate-validation.md"
fi

# Self-probes, before the corpus.
rj_probe() { # rj_probe <name> <sed-expr>
  sed "$2" "$RJ_GVGS" > "$RJ/$1.sh"
  if cmp -s "$RJ_GVGS" "$RJ/$1.sh"; then echo "NOAPPLY"; return; fi
  rj_scan "$RJ/$1.sh"
}
rj_off="$(rj_probe probe-off '/^comment|/d')"
case "$rj_off" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-offender -- the probe did not measure: $rj_off"; rc=1 ;;
  *"UNCOVERED comment"*) note "ok    rj-probe-offender -- with the 'comment' row deleted the receipt-blind shape is reported UNCOVERED by name" ;;
  *) note "FAIL  rj-probe-offender -- a receipt-blind shape with no fixture row went unreported: $rj_off"; rc=1 ;;
esac
rj_nm="$(rj_probe probe-nm '/^no-read|/d')"
case "$rj_nm" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-near-miss -- the probe did not measure: $rj_nm"; rc=1 ;;
  *UNCOVERED*|*UNREPRODUCED*) note "FAIL  rj-probe-near-miss -- a shape the receipt already fails was reported as a gap: $rj_nm"; rc=1 ;;
  *SCANNED*) note "ok    rj-probe-near-miss -- with the receipt-owned 'no-read' row deleted the arm stays quiet" ;;
  *) note "FAIL  rj-probe-near-miss -- the scan printed no summary: $rj_nm"; rc=1 ;;
esac
# The row is present but its verdict is wrong: a blind shape relabelled as a near-miss.
rj_rl="$(rj_probe probe-relabel 's/^comment|RED|/comment|GREEN|/')"
case "$rj_rl" in
  *NOAPPLY*|*HARNESS*) note "FAIL  rj-probe-relabel -- the probe did not measure: $rj_rl"; rc=1 ;;
  *"UNREPRODUCED comment"*) note "ok    rj-probe-relabel -- a listed row whose verdict the oracle does not return is not coverage" ;;
  *) note "FAIL  rj-probe-relabel -- a relabelled row was accepted as coverage: $rj_rl"; rc=1 ;;
esac

# The corpus.
rj_out="$(rj_scan "$RJ_GVGS")"; rj_rc=$?
rj_sum="$(sed -n 's/^SCANNED \([0-9]*\) BLIND \([0-9]*\) OWNED \([0-9]*\)$/\1 \2 \3/p' <<<"$rj_out")"
rj_n="${rj_sum%% *}"; rj_b="$(printf '%s' "$rj_sum" | cut -d' ' -f2)"
if [ "$rj_rc" -ne 0 ] || [ -z "$rj_sum" ]; then
  note "FAIL  rj-join -- the scan did not measure: $rj_out"; rc=1
elif [ "$rj_b" -lt 1 ]; then
  note "FAIL  rj-join -- 0 receipt-blind shapes over $rj_n seeds: either the receipt got strong enough to retire the arms, or the scan reached nothing -- re-derive before reading it as either"; rc=1
elif grep -qE '^(UNCOVERED|UNREPRODUCED) ' <<<"$rj_out"; then
  note "FAIL  rj-join -- a shape $RJ_ID's receipt closes over has no fixture arm that fails it: $(grep -E '^(UNCOVERED|UNREPRODUCED) ' <<<"$rj_out" | tr '\n' ';')"; rc=1
else
  note "ok    rj-join -- $rj_b of $rj_n seeded shapes are receipt-blind, and every one carries a gate-verdict-grep-shape row its own oracle reproduces"
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  backlog-receipt-fixture-join -- the derived receipt closes on the live file, every self-probe fired, and every receipt-blind shape carries a reproduced row"
fi
exit "$rc"
