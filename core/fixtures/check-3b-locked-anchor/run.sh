#!/usr/bin/env bash
# Exercise validate-locked-anchor.sh against the check-3b fixture set.
# Exit 0 iff:
#   - bad-story.md FAILS            (mis-anchor / summarized propagation)
#   - good-story.md PASSES          (honest verbatim full-text claim)
#   - uncheckable-story.md FAILS    (bullets, no full_text_source AND no requires_context)
#   - requires-context-story.md PASSES (honest cite-by-reference; guard must NOT over-fire)
#   - the MUTATION control holds    (neuter the uncheckable guard -> uncheckable-story
#                                    goes green, proving the guard is what fails it)
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# Locate the validator: installed consumer path first, then upstream core path.
VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-locked-anchor.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-locked-anchor.sh" \
  "$DIR/../../core/scripts/validate-locked-anchor.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "run.sh: could not locate validate-locked-anchor.sh" >&2
  exit 2
fi

rc=0

if "$VALIDATOR" "$DIR/bad-story.md" >/dev/null 2>&1; then
  echo "FAIL: bad-story.md should have been rejected but passed" >&2
  rc=1
else
  echo "ok: bad-story.md rejected"
fi

if "$VALIDATOR" "$DIR/good-story.md" >/dev/null 2>&1; then
  echo "ok: good-story.md accepted"
else
  echo "FAIL: good-story.md should have passed but was rejected" >&2
  rc=1
fi

if "$VALIDATOR" "$DIR/uncheckable-story.md" >/dev/null 2>&1; then
  echo "FAIL: uncheckable-story.md should have been rejected but passed" >&2
  rc=1
else
  echo "ok: uncheckable-story.md rejected"
fi

if "$VALIDATOR" "$DIR/requires-context-story.md" >/dev/null 2>&1; then
  echo "ok: requires-context-story.md accepted (honest cite-by-reference not red)"
else
  echo "FAIL: requires-context-story.md should have passed but was rejected" >&2
  rc=1
fi

# --- MUTATION control: prove the uncheckable guard is what fails uncheckable-story ---
# Assertions above show uncheckable-story FAILS, but a FAIL is only evidence for THIS
# guard if removing the guard makes it PASS. Neuter the guard condition in a copy and
# require uncheckable-story to go green; if it still fails, some OTHER rejection is
# doing the work and the assertion above proves nothing.
WORK="$(mktemp -d 2>/dev/null)" || { echo "run.sh: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
MUTANT="$WORK/mutant.sh"
sed 's/if bullets and not any(REQUIRES_CTX_RE.match(ln) for ln in lines):/if False:  # MUTANT: uncheckable guard disabled/' \
  "$VALIDATOR" > "$MUTANT" || { echo "run.sh: sed failed" >&2; exit 2; }
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing — the uncheckable guard was renamed." >&2
  echo "  update the sed pattern in run.sh to match the real guard condition." >&2
  rc=2
elif bash "$MUTANT" "$DIR/uncheckable-story.md" >/dev/null 2>&1; then
  echo "ok: MUTATION — neutering the guard lets uncheckable-story.md pass (guard fires)"
else
  echo "FAIL: MUTATION — uncheckable-story.md still rejected without the guard; the FAIL above proves nothing" >&2
  rc=1
fi

[ "$rc" -eq 0 ] && echo "check-3b fixture: PASS"
exit "$rc"
