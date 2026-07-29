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

# --- Assertion 5: nothing retired -> NO output --------------------------------
# base == theirs, so the retired set is empty and the detector must say nothing.
NOOP="$(bash "$SCRIPT" "$DIST" "$THEIRS" "$THEIRS" "$CONSUMER" 2>/dev/null)"
[ -z "$NOOP" ] && ok "a release that retires nothing reports nothing" \
  || bad "the detector reported a finding when base and theirs are identical — it is not deriving the retired set"

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
