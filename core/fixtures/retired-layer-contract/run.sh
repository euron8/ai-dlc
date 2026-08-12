#!/usr/bin/env bash
# retired-layer-contract/run.sh — prove the layer-contract detector fires, stays quiet
# where it should, and cannot report clean by finding nothing to compare.
#
# THE DEFECT THIS EXISTS TO CATCH. `retired-tokens.sh` scans only CLASSIFY core files,
# so `overrides/` and `extensions/` are in no bucket and no detector opens them. A layer
# file that still speaks a retired core contract survives the pull unreported — and the
# layer is what the teammate actually reads. Measured on the reference consumer: two
# layer files spoke a retired role-file line shape and nothing said so.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

detect() { bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null; }

echo "retired-layer-contract:"

OUT="$(detect)"

# --- Assertion 0: SANITY — the detector produced SOMETHING ---------------------
# Every negative assertion below would score a false pass against a detector that is
# simply broken and emitting nothing.
if [ -n "$OUT" ]; then
  ok "the detector produced output against a tree with a retired shape"
else
  bad "FIXTURE BROKEN — no output at all; every assertion below would be a false pass"
  echo; echo "retired-layer-contract: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: a LIVE retired line in an override is flagged ----------------
grep -q 'overrides/team-roles__tea__consumer.md.*Personal:/model' <<<"$OUT" \
  && ok "an override carrying the retired shape on a live line is flagged" \
  || bad "the live retired line in the tea override was NOT flagged — the detector misses the plainest case"

grep -q 'overrides/team-roles__tea__consumer.md.*Bedrock:/model' <<<"$OUT" \
  && ok "both retired labels are reported, not just the first" \
  || bad "only one of the two retired labels was reported"

# --- Assertion 2: an INDENTED, ESCAPED occurrence is flagged -------------------
# The matcher must not anchor at line start. An extension that greps core and pastes the
# captured output indents it; one that quotes the pattern in a fence escapes the
# backtick. Anchoring on '^- ' missed exactly this file on the reference consumer.
grep -q 'extensions/steps-domain/bug-investigation-push.md.*Personal:/model' <<<"$OUT" \
  && ok "an indented / backslash-escaped occurrence is flagged (matcher is not line-anchored)" \
  || bad "the indented+escaped occurrence was NOT flagged — the matcher is anchored again and misses embedded greps"

# --- Assertion 3: a PARAPHRASE is not flagged ---------------------------------
# The documented limit. Asserting it keeps the matcher from widening into every
# reworded sentence, which would drown the finding it exists to surface.
grep -q 'team-roles__analyst__effort.md' <<<"$OUT" \
  && bad "a paraphrase with no literal shape was flagged — the matcher has widened into prose" \
  || ok "a prose paraphrase carrying no literal shape is NOT flagged (stated limit holds)"

# --- Assertion 4: an unrelated layer file is not flagged ----------------------
grep -q 'retro-domain.md' <<<"$OUT" \
  && bad "a layer file with no core-contract reference was flagged" \
  || ok "a layer file referencing no core contract is not flagged"

# --- Assertion 5: nothing retired -> no ROWS, but never a silent zero ----------
# base == theirs, so the retired set is empty and the detector must report no finding.
#
# BOTH REFS ARE `BASE`, AND THAT IS LOAD-BEARING. This arm used to pass `THEIRS THEIRS`,
# which does not exercise the empty-retired-set branch at all: the seeded rulebook at
# THEIRS carries NO contract shape (that is what the release retired), so that invocation
# trips the unreadable-base guard instead and exits before the retired set is ever
# computed. The arm asserted empty stdout, got it from the wrong branch, and read as a
# pass for nine releases. `BASE BASE` gives a ref whose rulebook HAS shapes and whose
# retired set is genuinely empty, which is the case this arm names.
NOOP="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>/dev/null)"
[ -z "$NOOP" ] && ok "a release that retires nothing reports no finding" \
  || bad "the detector reported a finding when base and theirs are identical — it is not deriving the retired set"

# --- Assertion 5b: that zero SAYS it opened no file ---------------------------
# THIS ARM EXISTS BECAUSE ASSERTION 5 ALONE CERTIFIED THE DEFECT. It asserted silence and
# got it, and the silence came from a branch that exits before opening a single layer file
# -- output byte-identical to a full scan that matched nothing. Measured on the reference
# consumer's 0.356.0 -> 0.357.0 pull: the retired set was empty, this branch was taken, and
# the clean read was taken as evidence about layer files the run never read.
NOOPERR="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>&1 >/dev/null)"
# Control: this must be the empty-retired-set branch, NOT the unreadable-base guard that
# the old `THEIRS THEIRS` form reached. Without this the arm could pass on the wrong exit.
grep -q 'refusing to report clean' <<<"$NOOPERR" \
  && bad "  the empty-retired-set arm reached the unreadable-base guard instead — it is testing the wrong branch" \
  || ok "  and it reached the empty-retired-set branch, not the unreadable-base guard"
grep -q 'NO layer file was opened' <<<"$NOOPERR" \
  && ok "a release that retires nothing SAYS it opened no layer file, so the zero cannot read as coverage" \
  || bad "a release that retires nothing produced a silent zero — indistinguishable from a full scan that found nothing"
grep -q 'outside this detector' <<<"$NOOPERR" \
  && ok "  and that note restates the prose-restatement limit, which the operator never reads in the header" \
  || bad "  the quiet path does not restate the prose limit — the reader has no way to know what the zero excludes"

# --- Assertion 5c: a scanned-but-empty result carries its denominator ---------
# The other unqualified zero: shapes WERE retired and every layer file was read, but none
# matched. Without a denominator that reads identically to a scan that opened no files.
EMPTYC="$WORK/empty-consumer"
mkdir -p "$EMPTYC/.claude/skills/ai-dlc/overrides" "$EMPTYC/.claude/skills/ai-dlc/extensions"
printf '# nothing here speaks any core contract shape\n' \
  > "$EMPTYC/.claude/skills/ai-dlc/overrides/inert.md"
DENOM="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC" 2>&1 >/dev/null)"
grep -qE 'retired shape\(s\) checked against [1-9][0-9]* layer file\(s\)' <<<"$DENOM" \
  && ok "a scanned-but-no-match run reports its denominator, so the zero has a control" \
  || bad "a scanned-but-no-match run reported no denominator — the zero cannot be told from one that opened nothing"
# Control on the arm above: the same run must still emit NO finding rows, or the
# denominator is being read off a run that actually matched something.
DENOMOUT="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC" 2>/dev/null)"
[ -z "$DENOMOUT" ] \
  && ok "  and that run emits no finding row, so the denominator describes a genuine zero" \
  || bad "  the empty-consumer run emitted a finding — the denominator arm is not measuring a zero"

# --- Assertion 6: an unreadable base WARNS, never reports clean ---------------
# 'no shapes found' and 'nothing was retired' are the same empty output. If the rulebook
# cannot be read the detector must say so, or it passes vacuously on every release.
ERRTXT="$(bash "$SCRIPT" "$DIST" deadbeefdeadbeefdeadbeef "$THEIRS" "$CONSUMER" 2>&1 >/dev/null)"
grep -q 'refusing to report clean' <<<"$ERRTXT" \
  && ok "an unreadable base warns loudly instead of reporting clean" \
  || bad "an unreadable base produced no warning — the detector would pass vacuously whenever the rulebook cannot be read"

echo
if [ "$fails" -eq 0 ]; then echo "retired-layer-contract: PASS"; exit 0; fi
echo "retired-layer-contract: $fails assertion(s) FAILED" >&2
exit 1
