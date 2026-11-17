#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
echo "HERMETIC-CONSUMED core/scripts/validate-audit-anchors.sh"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# IN PROCESS (BL-878). The validator is loaded once (core/fixtures/lib/inproc.sh inproc_load: its column-0 guard
# returns after defining vaa_main) and every assertion calls vaa_main through inproc_run, in a subshell that starts as
# a fresh `bash validate-audit-anchors.sh` would: fixture functions and unexported fixture variables dropped, shell
# options reset; exported variables and prefix assignments reach it as they reach the program. Each call is one
# fx_inproc pass (the inproc: row). The command-line runs left are the cli cells at the end (cells.decl).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a validator with neither its `vaa_main() {` line nor the column-0 source
# guard predates the wrap and reads SKIP through fx_skip_exit (exit 0 on a consumer, never an ok; FIXTURE BROKEN in
# the distribution); exactly one half FAILs; an unreadable one is FIXTURE ERROR.
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
grep -q '^vaa_main() {$' "$VALIDATOR"; _wd=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VALIDATOR"; _wg=$?
if [ "$_wd" -gt 1 ] || [ "$_wg" -gt 1 ]; then
  echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_wd/$_wg), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2
fi
case "$_wd$_wg" in
  00) ;;
  11) echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  10) echo "  FAIL $VALIDATOR defines \`vaa_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run vaa_main in this shell"; echo "audit-anchors-schema: FAIL (1 assertion(s))"; exit 1 ;;
  *) echo "  FAIL $VALIDATOR carries the column-0 source guard but no \`vaa_main() {\` line -- a respelled subject this fixture cannot drive"; echo "audit-anchors-schema: FAIL (1 assertion(s))"; exit 1 ;;
esac
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined nothing" >&2; exit 2; }
vaa() { inproc_run "$VALIDATOR" vaa_main "$@"; }

echo "audit-anchors-schema:"

# --- Assertion 0: SANITY — render is non-empty and deterministic -------------
# The render is paid twice here (the determinism question needs two) and every later arm that needs a
# rendered header cats the first one's bytes from RENDER_F: the output is a pure function of the
# schema, so re-rendering it per arm asked the same question five more times.
RENDER_F="$WORK/render.txt"
vaa --render > "$RENDER_F"; R1="$(cat "$RENDER_F")"; R2="$(vaa --render)"
[ -n "$R1" ] && [ "$R1" = "$R2" ] && ok "--render is non-empty and deterministic" \
  || bad "--render is empty or non-deterministic — the schema render is the source of truth"

# --- Assertion 1: rendered header + valid entries → validate PASS ------------
GOOD="$WORK/good.md"
{ cat "$RENDER_F"; cat <<'EOF'

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
if vaa "$GOOD"; then ok "rendered header + well-formed entries → validate PASS" \
  ; else bad "a valid audit-anchors file was rejected"; fi

# --- Assertion 2: header hand-edited → --check FAIL --------------------------
DRIFT="$WORK/drift.md"
sed 's/integer sprint number\. REQUIRED\./integer sprint number./' "$GOOD" > "$DRIFT"
if ! cmp -s "$GOOD" "$DRIFT"; then
  vaa --check "$DRIFT" 2>/dev/null && bad "a hand-edited header passed --check (drift undetected)" \
    || ok "a hand-edited header region → --check FAIL (drift caught)"
else
  bad "FIXTURE STALE: the header edit changed nothing"
fi

# --- Assertion 3: missing header region → --check FAIL ----------------------
NOHDR="$WORK/nohdr.md"
printf '# Audit Anchors\n\n## Entries\n\n- sprint: 1\n  sha: PENDING\n' > "$NOHDR"
vaa --check "$NOHDR" 2>/dev/null && bad "a file with no GENERATED header passed --check" \
  || ok "no GENERATED header region → --check FAIL"

# --- Assertion 4: entry missing a REQUIRED field (sha) → validate FAIL -------
MISS="$WORK/missing-sha.md"
{ cat "$RENDER_F"; printf '\n## Entries\n\n```yaml\n- sprint: 42\n  closed_at: PENDING\n```\n'; } > "$MISS"
vaa "$MISS" 2>/dev/null && bad "an entry missing the required 'sha' passed validate" \
  || ok "entry missing required 'sha' → validate FAIL (fail-closed on shape)"

# --- Assertion 5a: non-integer sprint → validate FAIL (structural) ----------
BADSPRINT="$WORK/bad-sprint.md"
{ cat "$RENDER_F"; printf '\n## Entries\n\n```yaml\n- sprint: forty-two\n  sha: PENDING\n```\n'; } > "$BADSPRINT"
vaa "$BADSPRINT" 2>/dev/null && bad "an entry with a non-integer sprint passed validate" \
  || ok "entry with non-integer 'sprint' → validate FAIL"

# --- Assertion 5b: a real sha with an inline YAML '# comment' → PASS ---------
# Real consumer files carry backfill notes after the value; the parser must strip the comment.
COMMENTED="$WORK/commented.md"
{ cat "$RENDER_F"; printf '\n## Entries\n\n```yaml\n- sprint: 285\n  sha: ad6ecefb72f264771250371541e9f41e3a4a6272 # backfilled on main after retro PR merge\n```\n'; } > "$COMMENTED"
vaa "$COMMENTED" >/dev/null 2>&1 && ok "a sha with an inline '# comment' → validate PASS (comment stripped)" \
  || bad "a real sha with a trailing '# comment' was rejected — the parser did not strip the comment"

# --- Assertion 6b: MIGRATION-SAFE — --entries passes a file with valid entries but no header ---
# A consumer file predating this schema has no GENERATED region. --entries (Check 18) must NOT
# wedge it, while full validate + --check (producer side) still require the header.
MIG="$WORK/pre-schema.md"
printf '# Audit Anchors\n\n## Entries\n\n```yaml\n- sprint: 200\n  sha: 6e8d254f9edefc2a180d9a9d6d95d27c1a2b064c\n  closed_at: 2026-04-24T18:39:00Z\n```\n' > "$MIG"
if vaa --entries "$MIG" 2>/dev/null; then
  vaa "$MIG" 2>/dev/null && bad "full validate passed a headerless file (should require the region)" \
    || ok "--entries passes a headerless (pre-schema) file while full validate still fails — migration-safe"
else
  bad "--entries wedged a pre-schema file with valid entries — Check 18 would fail-closed on a not-yet-migrated consumer"
fi

# --- Assertion 6: unreadable/malformed schema → fail CLOSED -----------------
AI_DLC_AUDIT_ANCHORS_SCHEMA="$BAD_SCHEMA" vaa --render >/dev/null 2>&1 \
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
{ cat "$RENDER_F"
  printf '\n## Entries\n\n```yaml\n- sprint: 900\n  sha: %s\n  closed_at: 2026-06-01T00:00:00Z\n```\n' "$REPO_SHA"
} > "$CLOSE"
CR_OUT="$( ( cd "$REPO" && vaa --close-record "$CLOSE" 901 reset "$REPO_SHA" ) 2>/dev/null )"; CR_RC=$?
CR_VAL="$(vaa "$CLOSE" 2>/dev/null)"
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
NOCR_OUT="$(vaa --entries "$NOCR" 2>/dev/null)"
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

enum_battery() {   # -> two space-separated tokens
  local out rc t
  out="$( vaa --entries "$BOGUS" 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -ne 0 ] && grep -qF "'close_reason'='paused' is not one of reset, abandoned" <<<"$out"
  then t="E:named"; else t="E:no"; fi
  out="$( vaa --entries "$VALIDCR" 2>/dev/null )"; rc=$?
  if [ "$rc" -eq 0 ] && grep -q '1 entry validated' <<<"$out"; then t="$t V:pass"; else t="$t V:no"; fi
  printf '%s' "$t"
}
ENUM_EXPECTED="E:named V:pass"

GOT="$(enum_battery)"
if [ "$GOT" = "$ENUM_EXPECTED" ]; then
  ok "a hand-written close_reason outside the enum → --entries FAIL naming the closed set, while a member of it still PASSes"
else
  bad "enum battery: expected [$ENUM_EXPECTED], got [$GOT]"
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
  vaa --close-record "$ALT_FILE" 911 reset "$REPO_SHA" ) 2>&1 >/dev/null )"; ALT_RC=$?
ALT_ACCEPT="$( ( cd "$REPO" && AI_DLC_AUDIT_ANCHORS_SCHEMA="$ALT_SCHEMA" \
  vaa --close-record "$ALT_FILE" 912 quiesced "$REPO_SHA" ) 2>/dev/null )"; ALT_ARC=$?
ALT_READ="$(AI_DLC_AUDIT_ANCHORS_SCHEMA="$ALT_SCHEMA" vaa --entries "$ALT_FILE" 2>/dev/null)"
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
  out="$( ( cd "$REPO" && vaa --close-record "$WORK/refuse.md" "$@" ) 2>&1 >/dev/null )"; rc=$?
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
  out="$( ( cd "$REPO" && vaa --close-record "$WORK/usage.md" "$@" ) 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -eq 2 ] && grep -qF "$want" <<<"$out" && cmp -s "$CLOSE" "$WORK/usage.md"; then
    ok "--close-record with $label → exit 2 (usage), not exit 1 (a broken chain)"
  else
    bad "--close-record ($label): wanted exit 2 + [$want]; got rc=$rc out=[${out:-<nothing>}]"
  fi
}
usage_is_2 "a non-integer sprint" "needs <sprint-n> as a positive integer" nine reset "$REPO_SHA"
usage_is_2 "no reason at all"     "needs <reason>"                          902
usage_is_2 "no sha at all"        "needs <sha>"                             902 reset

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome ---------------------
# The outcomes this fixture reaches are exit 0 (a valid file), exit 1 (a shape FAIL) and exit 2 (a fumbled argument).
# One `FXCELL=<id> bash "$VALIDATOR"` start per outcome, each compared with the in-process call on the same input:
# stdout, stderr and exit separately, byte for byte. --close-record writes into its file, so each side gets its own
# copy restored to the same path first. A cell also asserts its own outcome (a positive conjunct, so two runs that
# both printed nothing cannot read as equivalent), and the cells must differ.
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}; runs in $REPO on a fresh $EQ/f.md each side
  local id="$1"; shift
  cp "$CLOSE" "$EQ/f.md"
  ( cd "$REPO" && vaa "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  cp "$CLOSE" "$EQ/f.md"
  ( cd "$REPO" && FXCELL="$id" bash "$VALIDATOR" "$@" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
if eqv cli-pass "$EQ/f.md" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] \
   && grep -q '2 entries validated' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program validates the closed file exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with 2 entries ($(eq_twin cli-pass))"; fi
if eqv cli-fail --close-record "$EQ/f.md" 902 paused "$REPO_SHA" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] \
   && grep -qF "reason 'paused' is not one of reset, abandoned" "$EQ/cli-fail.cl.err"; then
  ok "cli-fail: the program refuses a reason outside the enum exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 naming the enum ($(eq_twin cli-fail))"; fi
if eqv cli-usage --close-record "$EQ/f.md" nine reset "$REPO_SHA" && [ "$(cat "$EQ/cli-usage.cl.rc")" = 2 ] \
   && grep -qF "needs <sprint-n> as a positive integer" "$EQ/cli-usage.cl.err"; then
  ok "cli-usage: the program refuses a fumbled argument exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 with the usage message ($(eq_twin cli-usage))"; fi
if ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-fail.cl.rc" && ! cmp -s "$EQ/cli-fail.cl.rc" "$EQ/cli-usage.cl.rc" \
   && ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-fail.cl.out"; then
  ok "cli cells discriminate: the passing, refusing and usage inputs give three different exits"
else bad "cli cells do not discriminate: two of cli-pass, cli-fail and cli-usage gave the same exit or stdout"; fi

report_end audit-anchors-schema 25
