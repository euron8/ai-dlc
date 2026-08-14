#!/usr/bin/env bash
# audit-anchors-schema/run.sh — prove the audit-anchors housekeeping schema is single-source and
# enforced: the header is RENDERED from schemas/audit-anchors.json, --check catches header drift,
# validate catches entry shape drift, and the reader fails CLOSED on an unreadable schema.
#
# THE DEFECT THIS EXISTS TO CATCH. The schema lived in two places — templates/audit-anchors.md.template
# (never shipped) and each project's live audit-anchors.md header (hand-carried) — with nothing
# comparing them. They diverged, and the de-facto schema survived only in whichever file was carried
# forward. Fresh installs would have seeded the stale shape. This proves the second copy is gone.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
asserted=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserted=$((asserted+1)); }

echo "audit-anchors-schema:"

# --- Assertion 0: SANITY — render is non-empty and deterministic -------------
R1="$(bash "$VALIDATOR" --render)"; R2="$(bash "$VALIDATOR" --render)"
[ -n "$R1" ] && [ "$R1" = "$R2" ] && ok "--render is non-empty and deterministic" \
  || bad "--render is empty or non-deterministic — the schema render is the source of truth"

# --- Assertion 1: rendered header + valid entries → validate PASS ------------
GOOD="$WORK/good.md"
{ bash "$VALIDATOR" --render; cat <<'EOF'

## Entries

```yaml
- sprint: 167
  sha: 6e8d254f9edefc2a180d9a9d6d95d27c1a2b064c
  closed_at: 2026-04-24T18:39:00Z
  audit_window: <pre-S167-baseline>..6e8d254f
- sprint: 168
  sha: PENDING
  closed_at: PENDING
```
EOF
} > "$GOOD"
if bash "$VALIDATOR" "$GOOD"; then ok "rendered header + well-formed entries → validate PASS" \
  ; else bad "a valid audit-anchors file was rejected"; fi

# --- Assertion 2: header hand-edited → --check FAIL --------------------------
DRIFT="$WORK/drift.md"
sed 's/integer sprint number\. REQUIRED\./integer sprint number./' "$GOOD" > "$DRIFT"
if ! cmp -s "$GOOD" "$DRIFT"; then
  bash "$VALIDATOR" --check "$DRIFT" 2>/dev/null && bad "a hand-edited header passed --check (drift undetected)" \
    || ok "a hand-edited header region → --check FAIL (drift caught)"
else
  bad "FIXTURE STALE: the header edit changed nothing"
fi

# --- Assertion 3: missing header region → --check FAIL ----------------------
NOHDR="$WORK/nohdr.md"
printf '# Audit Anchors\n\n## Entries\n\n- sprint: 1\n  sha: PENDING\n' > "$NOHDR"
bash "$VALIDATOR" --check "$NOHDR" 2>/dev/null && bad "a file with no GENERATED header passed --check" \
  || ok "no GENERATED header region → --check FAIL"

# --- Assertion 4: entry missing a REQUIRED field (sha) → validate FAIL -------
MISS="$WORK/missing-sha.md"
{ bash "$VALIDATOR" --render; printf '\n## Entries\n\n```yaml\n- sprint: 42\n  closed_at: PENDING\n```\n'; } > "$MISS"
bash "$VALIDATOR" "$MISS" 2>/dev/null && bad "an entry missing the required 'sha' passed validate" \
  || ok "entry missing required 'sha' → validate FAIL (fail-closed on shape)"

# --- Assertion 5a: non-integer sprint → validate FAIL (structural) ----------
BADSPRINT="$WORK/bad-sprint.md"
{ bash "$VALIDATOR" --render; printf '\n## Entries\n\n```yaml\n- sprint: forty-two\n  sha: PENDING\n```\n'; } > "$BADSPRINT"
bash "$VALIDATOR" "$BADSPRINT" 2>/dev/null && bad "an entry with a non-integer sprint passed validate" \
  || ok "entry with non-integer 'sprint' → validate FAIL"

# --- Assertion 5b: a real sha with an inline YAML '# comment' → PASS ---------
# Real consumer files carry backfill notes after the value; the parser must strip the comment.
COMMENTED="$WORK/commented.md"
{ bash "$VALIDATOR" --render; printf '\n## Entries\n\n```yaml\n- sprint: 285\n  sha: ad6ecefb72f264771250371541e9f41e3a4a6272 # backfilled on main after retro PR merge\n```\n'; } > "$COMMENTED"
bash "$VALIDATOR" "$COMMENTED" >/dev/null 2>&1 && ok "a sha with an inline '# comment' → validate PASS (comment stripped)" \
  || bad "a real sha with a trailing '# comment' was rejected — the parser did not strip the comment"

# --- Assertion 6b: MIGRATION-SAFE — --entries passes a file with valid entries but no header ---
# A consumer file predating this schema has no GENERATED region. --entries (Check 18) must NOT
# wedge it, while full validate + --check (producer side) still require the header.
MIG="$WORK/pre-schema.md"
printf '# Audit Anchors\n\n## Entries\n\n```yaml\n- sprint: 200\n  sha: 6e8d254f9edefc2a180d9a9d6d95d27c1a2b064c\n  closed_at: 2026-04-24T18:39:00Z\n```\n' > "$MIG"
if bash "$VALIDATOR" --entries "$MIG" 2>/dev/null; then
  bash "$VALIDATOR" "$MIG" 2>/dev/null && bad "full validate passed a headerless file (should require the region)" \
    || ok "--entries passes a headerless (pre-schema) file while full validate still fails — migration-safe"
else
  bad "--entries wedged a pre-schema file with valid entries — Check 18 would fail-closed on a not-yet-migrated consumer"
fi

# --- Assertion 6: unreadable/malformed schema → fail CLOSED -----------------
AI_DLC_AUDIT_ANCHORS_SCHEMA="$BAD_SCHEMA" bash "$VALIDATOR" --render >/dev/null 2>&1 \
  && bad "a malformed schema still rendered — the reader degraded instead of failing closed" \
  || ok "malformed schema → exit 1 (fail-closed, never degrades to no-schema)"

# ============================================================================
# CLOSE RECORDS — the OPTIONAL `close_reason` enum and `--close-record`, its only writer.
#
# The question these arms answer is NOT "does the writer work". It is whether adding a way to
# anchor a sprint that never reached a retro opened a way PAST the anchor. So every arm asserts a
# POSITIVE outcome — a resolved sha on stdout, a named message on stderr, an entry count from the
# validator, a file left byte-identical — and never the absence of the old failure. An arm phrased
# as "it did not pass" is satisfied by a subject that emits nothing at all.
#
# The RESOLVER half of the same change (`--prior-sprint-sha` reading a close record, and still
# failing closed when the prior sprint has no entry) belongs to core/fixtures/check5-anchor-base,
# which owns that mode and its two callers. It is not restated here: two arms that both catch a
# case mean one of them is vacuous.
# ============================================================================

# --- Assertion 7: a close record is APPENDED and the file still validates ----
# Seeded from what the real producer emits — a --render header over a FENCED entry list, the shape
# retro.md Step 5b writes — not from what the entry parser is known to accept.
CLOSE="$WORK/close.md"
{ bash "$VALIDATOR" --render
  printf '\n## Entries\n\n```yaml\n- sprint: 900\n  sha: %s\n  closed_at: 2026-06-01T00:00:00Z\n```\n' "$REPO_SHA"
} > "$CLOSE"
CR_OUT="$( ( cd "$REPO" && bash "$VALIDATOR" --close-record "$CLOSE" 901 reset "$REPO_SHA" ) 2>/dev/null )"; CR_RC=$?
CR_VAL="$(bash "$VALIDATOR" "$CLOSE" 2>/dev/null)"
if [ "$CR_RC" -eq 0 ] && [ "$CR_OUT" = "$REPO_SHA" ] \
   && grep -q '^  close_reason: reset$' "$CLOSE" \
   && grep -q '2 entries validated' <<<"$CR_VAL"; then
  ok "--close-record appends a close record (resolved sha on stdout) and the file still validates — 1 entry became 2"
else
  bad "--close-record did not leave a valid file: rc=$CR_RC stdout='$CR_OUT' validate='${CR_VAL:-<nothing>}'"
fi

# --- Assertion 8: an entry with NO close_reason still validates --------------
# The field is OPTIONAL and that is load-bearing: every audit-anchors.md already in the field
# lacks it, and a required field would error on real data on first contact. Asserted through the
# COUNT the validator prints — "it exited 0" is also what a validator that parsed nothing prints.
NOCR="$WORK/no-close-reason.md"
printf -- '# Audit Anchors\n\n## Entries\n\n- sprint: 300\n  sha: %s\n  closed_at: 2026-01-01T00:00:00Z\n- sprint: 301\n  sha: %s\n' \
  "$REPO_SHA" "$REPO_SHA" > "$NOCR"
NOCR_OUT="$(bash "$VALIDATOR" --entries "$NOCR" 2>/dev/null)"
if grep -q '2 entries validated' <<<"$NOCR_OUT"; then
  ok "entries carrying NO close_reason still validate (the field is optional — real files have none)"
else
  bad "an audit-anchors file with no close_reason was rejected or validated nothing — got: ${NOCR_OUT:-<nothing>}"
fi

# --- the enum is ENFORCED on a hand-written value ----------------------------
# `--close-record` is the only sanctioned writer, but nothing stops a hand-edit, and Check 18 reads
# whatever is in the file. Both tokens matter: E proves a value outside the set is REFUSED and
# named, V proves a value inside it still PASSES — a guard widened to reject everything produces a
# red E-arm's mirror image and would otherwise score as enforcement.
BOGUS="$WORK/bogus-reason.md"
printf -- '# Audit Anchors\n\n## Entries\n\n- sprint: 902\n  sha: %s\n  close_reason: paused\n' "$REPO_SHA" > "$BOGUS"
VALIDCR="$WORK/valid-reason.md"
printf -- '# Audit Anchors\n\n## Entries\n\n- sprint: 902\n  sha: %s\n  close_reason: abandoned\n' "$REPO_SHA" > "$VALIDCR"

enum_battery() {   # <script> -> two space-separated tokens. A mutant must move EXACTLY one.
  local S="$1" out rc t
  out="$( bash "$S" --entries "$BOGUS" 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -ne 0 ] && grep -qF "'close_reason'='paused' is not one of reset, abandoned" <<<"$out"
  then t="E:named"; else t="E:no"; fi
  out="$( bash "$S" --entries "$VALIDCR" 2>/dev/null )"; rc=$?
  if [ "$rc" -eq 0 ] && grep -q '1 entry validated' <<<"$out"; then t="$t V:pass"; else t="$t V:no"; fi
  printf '%s' "$t"
}
ENUM_EXPECTED="E:named V:pass"

GOT="$(enum_battery "$VALIDATOR")"
if [ "$GOT" = "$ENUM_EXPECTED" ]; then
  ok "a hand-written close_reason outside the enum → --entries FAIL naming the closed set, while a member of it still PASSes"
else
  bad "enum battery: expected [$ENUM_EXPECTED], got [$GOT]"
fi

# An UNMUTATED control from the same directory: a lone copy that cannot resolve ../schemas/ fails
# every arm, and "it failed" would otherwise score as a kill for the mutant below.
CTL="$WORK/mut/control.sh"
cp "$VALIDATOR" "$CTL"
CGOT="$(enum_battery "$CTL")"
if [ "$CGOT" = "$ENUM_EXPECTED" ]; then
  ok "CONTROL: an unmutated copy beside the mutant answers identically (the harness is not what fails below)"
else
  echo "FIXTURE ERROR: the unmutated control does not reproduce the enum battery — expected" >&2
  echo "  [$ENUM_EXPECTED], got [$CGOT]. Most likely the copy cannot resolve ../schemas/." >&2
  exit 2
fi

# The enum check in the ENTRY loop, removed. Its sibling read inside --close-record is a different
# line (`spec.get("enum") or []`), so this reverts the reader half only — which is the half the
# arm above claims. Without it a hand-written `paused` reaches Check 18 as a valid close record.
MUT_ENUM="$WORK/mut/no-enum-check.sh"
sed 's/^        allowed = spec\.get("enum")$/        allowed = None/' "$VALIDATOR" > "$MUT_ENUM"
if cmp -s "$VALIDATOR" "$MUT_ENUM"; then
  echo "FIXTURE ERROR: mutant 'no-enum-check' matched nothing — the entry-loop enum read was renamed." >&2
  exit 2
fi
MGOT="$(enum_battery "$MUT_ENUM")"
if [ "$MGOT" = "E:no V:pass" ]; then
  ok "MUTANT no-enum-check: removing the entry-loop enum read lets a hand-written 'paused' validate, and moves nothing else"
else
  bad "MUTANT no-enum-check: expected [E:no V:pass], got [$MGOT]"
fi

# --- the closed set is READ FROM the schema, not restated --------------------
# Mutate the schema's `enum` ARRAY and the accepted set has to move with it. A pattern restated in
# the validator would keep accepting reset/abandoned under a schema that declares neither.
# Observed at the WRITER, where the enum is read on its own line: the reader half of this is arm
# 9's to own, and an arm that moved under arm 9's mutant would make one of the two vacuous.
ALT_SCHEMA="$WORK/alt-enum-schema.json"
sed 's/"enum": \["reset", "abandoned"\]/"enum": ["quiesced"]/' "$SCHEMA" > "$ALT_SCHEMA"
if cmp -s "$SCHEMA" "$ALT_SCHEMA"; then
  echo "FIXTURE ERROR: the schema's close_reason enum array was not found — its spelling changed." >&2
  exit 2
fi
ALT_FILE="$WORK/alt-enum.md"
printf -- '# Audit Anchors\n\n## Entries\n\n- sprint: 910\n  sha: %s\n' "$REPO_SHA" > "$ALT_FILE"
ALT_REFUSE="$( ( cd "$REPO" && AI_DLC_AUDIT_ANCHORS_SCHEMA="$ALT_SCHEMA" \
  bash "$VALIDATOR" --close-record "$ALT_FILE" 911 reset "$REPO_SHA" ) 2>&1 >/dev/null )"; ALT_RC=$?
ALT_ACCEPT="$( ( cd "$REPO" && AI_DLC_AUDIT_ANCHORS_SCHEMA="$ALT_SCHEMA" \
  bash "$VALIDATOR" --close-record "$ALT_FILE" 912 quiesced "$REPO_SHA" ) 2>/dev/null )"; ALT_ARC=$?
ALT_READ="$(AI_DLC_AUDIT_ANCHORS_SCHEMA="$ALT_SCHEMA" bash "$VALIDATOR" --entries "$ALT_FILE" 2>/dev/null)"
if [ "$ALT_RC" -eq 1 ] && grep -qF "is not one of quiesced" <<<"$ALT_REFUSE" \
   && [ "$ALT_ARC" -eq 0 ] && [ "$ALT_ACCEPT" = "$REPO_SHA" ] \
   && grep -q '^  close_reason: quiesced$' "$ALT_FILE" \
   && grep -q '2 entries validated' <<<"$ALT_READ"; then
  ok "the closed set is read FROM the schema's enum array: under a schema declaring only 'quiesced', 'reset' is refused and 'quiesced' is written and accepted"
else
  bad "the accepted set did not move with the schema's enum (restated, not single-sourced): refuse rc=$ALT_RC [$ALT_REFUSE]; accept rc=$ALT_ARC [$ALT_ACCEPT]; read [${ALT_READ:-<nothing>}]"
fi

# --- --close-record REFUSES, each with its own message -----------------------
# All four exit 1 and would all match a grep for FAIL. A mutant that collapses two into one is
# invisible to anything but the wording, and a caller that cannot tell "wrong reason" from
# "unresolvable anchor" cannot act on either. The third clause is the anti-exemption one: a refusal
# that appended anyway would satisfy the exit code and the message and still hole the chain.
refuses() {   # <label> <expected-message-substring> <close-record args...>
  local label="$1" want="$2" out rc; shift 2
  cp "$CLOSE" "$WORK/refuse.md"
  out="$( ( cd "$REPO" && bash "$VALIDATOR" --close-record "$WORK/refuse.md" "$@" ) 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "$want" <<<"$out" && cmp -s "$CLOSE" "$WORK/refuse.md"; then
    ok "--close-record refuses $label — exit 1, its own message, and nothing appended"
  else
    bad "--close-record ($label): wanted exit 1 + [$want] + an unchanged file; got rc=$rc out=[${out:-<nothing>}]"
  fi
}
refuses "a reason outside the enum"  "reason 'paused' is not one of reset, abandoned" \
        902 paused "$REPO_SHA"
refuses "a sha that resolves to nothing" "does not resolve to a commit in the repository this ran in" \
        902 reset deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
refuses "a sprint that already has an entry" "an entry for sprint 901 already exists" \
        901 reset "$REPO_SHA"
# THE PLACEHOLDER ARM, ASSERTED AS IT ACTUALLY BEHAVES. The sha is resolved BEFORE it is inspected
# for PENDING, so the ordinary placeholder a retro writes (`<PENDING-S901-RETRO>`) is refused by the
# resolution arm and never reaches the placeholder message. The placeholder message is reachable
# only through a value that resolves AND is named PENDING — the tag seed.sh creates. Both are
# asserted: the refusal holds for the realistic value either way, and the dedicated message is
# proven to exist rather than assumed from reading the source.
refuses "an unresolvable PENDING placeholder" "does not resolve to a commit in the repository this ran in" \
        902 reset '<PENDING-S901-RETRO>'
refuses "a PENDING placeholder that resolves" "is a PENDING placeholder" \
        902 reset "$PENDING_REF"

# --- a fumbled ARGUMENT is exit 2, never exit 1 ------------------------------
# Exit 1 from this script means "the anchor chain is wrong". Check 18 fails a gate on that, so a
# typo arriving as exit 1 is a false gate failure. The separation was already load-bearing for
# --prior-sprint-sha; a writer that got it wrong would report a missing anchor for a missing space.
usage_is_2() {   # <label> <expected-message-substring> <close-record args...>
  local label="$1" want="$2" out rc; shift 2
  cp "$CLOSE" "$WORK/usage.md"
  out="$( ( cd "$REPO" && bash "$VALIDATOR" --close-record "$WORK/usage.md" "$@" ) 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -eq 2 ] && grep -qF "$want" <<<"$out" && cmp -s "$CLOSE" "$WORK/usage.md"; then
    ok "--close-record with $label → exit 2 (usage), not exit 1 (a broken chain)"
  else
    bad "--close-record ($label): wanted exit 2 + [$want]; got rc=$rc out=[${out:-<nothing>}]"
  fi
}
usage_is_2 "a non-integer sprint" "needs <sprint-n> as a positive integer" nine reset "$REPO_SHA"
usage_is_2 "no reason at all"     "needs <reason>"                          902
usage_is_2 "no sha at all"        "needs <sha>"                             902 reset

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
if [ "$asserted" -ne 23 ]; then
  echo "audit-anchors-schema: FIXTURE ERROR — ran $asserted assertions, expected 23" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then echo "audit-anchors-schema: PASS ($asserted assertions)"; exit 0; fi
echo "audit-anchors-schema: $fails of $asserted assertion(s) FAILED" >&2
exit 1
