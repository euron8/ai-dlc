#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# layer-conforms-to — prove the per-entry contract receipt (E17 / W6) and the
# LAYER_CONFORMANCE machine footer can FAIL, and prove the one property that is an
# ABSENCE: the receipt never silences a clause.
#
# Usage: run.sh [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS PART 3. `conforms_to` was specified — in the contract's own
# header for eight versions, and in the plan that scheduled this work — as a SKIP: "an entry
# declaring conforms_to: N is held only to clauses with since <= N". Built that way it is a
# one-line-per-file escape hatch from every clause core has allocated since, and the reference
# consumer's 49 band ERRORs sit at since 4 and since 8. So the shipped reader reports scope and
# subtracts nothing, and that is a property no ordinary assertion can see: the code for it is
# absent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LARG="${1:-}"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "$LARG" "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"
[ -f "$(dirname "$LINTER")/artifact-path-config.sh" ] && echo "HERMETIC-CONSUMED core/scripts/artifact-path-config.sh"

# IN PROCESS (BL-878). The validator is SOURCED ONCE into this shell (its guard returns after defining vle_main), and
# every drive calls vle_main inside the subshell of the `$( )` that captures it, so its `exit`, `set -u`, EXIT trap and
# function definitions stay there. It starts as a program only in the cli cells (cells.decl). A CORE FIXTURE SHIPS
# AHEAD OF ITS SUBJECT: a subject with neither its `vle_main() {` line nor the column-0 source guard predates the wrap
# and reads SKIP (exit 0, never an ok); exactly one half is a respelled subject and FAILs; a subject grep cannot READ
# (exit 2) is FIXTURE ERROR.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$LINTER" vle_main; g_vle=$?
[ "$g_vle" = 2 ] && exit 2
[ "$g_vle" = 1 ] && { echo "layer-conforms-to: 1 FAILED"; exit 1; }
[ "$g_vle" = 3 ] && { echo "SKIP: subject predates the in-process wrap"; exit 0; }

ROOT="$(bash "$HERE/seed.sh")"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/layer-conforms-to-m.XXXXXX")"
trap 'rm -rf "$ROOT" "$TMP"' EXIT
CONS="$ROOT/consumer"; BAD="$ROOT/bad-consumer"; NOLC="$ROOT/no-contract"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
fx_inproc "$LINTER"
. "$LINTER" || { echo "FIXTURE ERROR: sourcing $LINTER failed" >&2; exit 2; }
declare -F vle_main > /dev/null || { echo "FIXTURE ERROR: sourcing $LINTER defined no vle_main" >&2; exit 2; }
say() { if [ "$1" = 1 ]; then ok "$2"; else bad "$2"; fi; }

# NO run() HELPER, deliberately. `OUT="$(run ...)"` evaluates the helper in a SUBSHELL, so an
# rc it assigns to a global is discarded and every exit-code assertion below would read a stale
# 0 — the `$( )` swallowing state that cost v0.217.0 a whole silent mutant. Each call site
# captures `$?` on the same line as its own command substitution.

# footer_field <output> <name> -> the value of name= on the LAYER_CONFORMANCE line
# A HERE-STRING, not a pipe, and for I54's reason one reader over: this awk program `exit`s at
# the first match, so under pipefail a large enough value would make the writer die on EPIPE and
# the field read as absent. The redirect goes at the end of the awk command and the pipe is gone.
footer_field() {
  awk -v k="$2" '
    /^LAYER_CONFORMANCE / { for (i=2; i<=NF; i++) { split($i, p, "="); if (p[1] == k) { print p[2]; exit } } }' <<<"$1"
}

echo "layer-conforms-to:"

# ---------------------------------------------------------------------------
# Part 1 — the conforming consumer, and the footer's counts
# ---------------------------------------------------------------------------
CLEAN_OUT="$( ( fx_inproc "$LINTER"; vle_main "$CONS" ) 2>&1)"; CLEAN_RC=$?
say "$([ "$CLEAN_RC" -eq 0 ] && echo 1 || echo 0)" \
  "a consumer whose every entry carries a current receipt exits 0"
if [ "$(footer_field "$CLEAN_OUT" entries)" = 3 ]; then
  ok "the footer counts 3 entries — 2 extensions AND the override, so the pass walks both layers"
else
  bad "the footer counts 3 entries — 2 extensions AND the override, so the pass walks both layers"
fi
if [ "$(footer_field "$CLEAN_OUT" at_current)" = 3 ]; then ok "the footer counts 3 at_current"
else bad "the footer counts 3 at_current"; fi
say "$([ "$(footer_field "$CLEAN_OUT" contract_version)" = "$(awk '/^contract_version:/{print $2; exit}' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml")" ] && echo 1 || echo 0)" \
  "the footer's contract_version is READ from the consumer's own installed contract"

# ---------------------------------------------------------------------------
# Part 2 — one arm per malformed receipt
# ---------------------------------------------------------------------------
BAD_OUT="$( ( fx_inproc "$LINTER"; vle_main "$BAD" ) 2>&1)"; BAD_RC=$?
has() { grep -Fq "$1" <<<\"$BAD_OUT\"; }

say "$([ "$BAD_RC" -eq 1 ] && echo 1 || echo 0)"  "a malformed receipt exits 1 — the consumer's pre-push refuses"
say "$(has "no-receipt.md: missing 'conforms_to:'" && echo 1 || echo 0)"      "E17 reports a MISSING receipt"
say "$(has "not-a-number.md: conforms_to 'eight' is not" && echo 1 || echo 0)" "E17 reports a NON-NUMERIC receipt"
# DERIVED, not written down. This read `conforms_to 10`, which was one above the contract at
# the release that shipped it and became the contract's OWN version at the next bump — the
# assertion then asked E17 to reject a receipt that had become legal, and went red for a
# reason that had nothing to do with E17. The seed already derives the value as CV+1; this
# side has to derive it from the same place or the pair drifts on every bump.
CV_NOW="$(awk '/^contract_version:/{print $2; exit}' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml")"
[ -n "$CV_NOW" ] || { echo "FIXTURE ERROR: no contract_version in the seeded contract" >&2; exit 2; }
if has "above-cv.md: conforms_to $((CV_NOW + 1)) claims a contract version"; then
  ok "E17 reports a receipt ABOVE contract_version — a version no distribution has reached"
else
  bad "E17 reports a receipt ABOVE contract_version — a version no distribution has reached"
fi
if [ "$(footer_field "$BAD_OUT" undeclared)" = 1 ]; then
  ok "the footer's undeclared count is the measured 1, not a restatement of the error count"
else
  bad "the footer's undeclared count is the measured 1, not a restatement of the error count"
fi

# W6 — one line per run, and it must name the entry AND the clauses that postdate it.
say "$(has 'W6 1 of 4 layer entr' && echo 1 || echo 0)" \
  "W6 reports the behind entry once per run, against a measured total"
say "$(grep -Fq 'LC-N5' <<<\"$BAD_OUT\" && echo 1 || echo 0)" \
  "W6's worklist names LC-N5 — a clause introduced after the entry's declared version"
say "$([ "$(footer_field "$BAD_OUT" behind)" = 1 ] && echo 1 || echo 0)" "the footer counts 1 behind"

# ---------------------------------------------------------------------------
# Part 3 — THE NON-SILENCING PROPERTY
# ---------------------------------------------------------------------------
# behind-and-in-core-range.md declares conforms_to: 1 and allocates a heading number core
# already defines. LC-N5 was introduced at since 4. Under the skip semantics the contract
# specified for eight versions this entry escapes the band ERROR outright.
if has 'behind-and-in-core-range.md: SECTION ID OUT OF BAND'; then
  ok "an entry at conforms_to 1 STILL takes the band ERROR from a clause introduced at since 4"
else
  bad "an entry at conforms_to 1 STILL takes the band ERROR from a clause introduced at since 4"
fi

# ---------------------------------------------------------------------------
# Part 4 — the refusal arm: an absent contract is not a clean one
# ---------------------------------------------------------------------------
NOLC_OUT="$( ( fx_inproc "$LINTER"; vle_main "$NOLC" ) 2>&1)"; NOLC_RC=$?
if [ "$NOLC_RC" -eq 1 ]; then
  ok "a consumer with no installed layer-contract.yaml exits 1 rather than reporting clean"
else
  bad "a consumer with no installed layer-contract.yaml exits 1 rather than reporting clean"
fi
say "$(grep -Fq 'went UNCHECKED in this run' <<<\"$NOLC_OUT\" && echo 1 || echo 0)" \
  "the refusal says the receipts were not judged, rather than judging them clean"
if [ "$(footer_field "$NOLC_OUT" contract_version)" = '-' ]; then
  ok "the footer reads contract_version=- when the contract could not be read, never a plausible number"
else bad "the footer reads contract_version=- when the contract could not be read, never a plausible number"; fi

# ---------------------------------------------------------------------------
# Part 4b — PRESENT BUT UNREADABLE is not MALFORMED, and the two must not share a message
# ---------------------------------------------------------------------------
# An awk that cannot open the contract prints nothing and exits 2; a contract lacking
# `contract_version:` prints nothing and exits 0. Keyed on the value alone both drew
# `got '<none>'`, and the operator was told to repair a file that is intact. The pair below is
# the discriminating input: the SAME consumer, once sealed at mode 000 and once readable with
# the version line deleted. Each must draw its own message and not the other's.
SEALED="$TMP/sealed"; MALF="$TMP/malformed"
cp -R "$CONS" "$SEALED"; cp -R "$CONS" "$MALF"
SEALED_LC="$SEALED/.claude/skills/ai-dlc/layer-contract.yaml"
MALF_LC="$MALF/.claude/skills/ai-dlc/layer-contract.yaml"
awk '!/^contract_version:/' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml" > "$MALF_LC"
chmod 000 "$SEALED_LC"
# Restore on exit: a mode-000 file is the one thing in TMP a later cleanup could trip on.
trap 'chmod -R u+rwX "$TMP" 2>/dev/null; rm -rf "$ROOT" "$TMP"' EXIT
# The seal must take, or every assertion below is about a READABLE file. Under root it does
# not, and that is a broken fixture rather than a regression.
if awk '{exit}' "$SEALED_LC" 2>/dev/null; then
  echo "FIXTURE BROKEN: chmod 000 did not make the contract unreadable (running as root?) — Part 4b cannot express its subject" >&2
  exit 2
fi
grep -q '^contract_version:' "$MALF_LC" && { echo "FIXTURE BROKEN: the malformed contract still carries contract_version:" >&2; exit 2; }
SEAL_OUT="$( ( fx_inproc "$LINTER"; vle_main "$SEALED" ) 2>&1)"; SEAL_RC=$?
MALF_OUT="$( ( fx_inproc "$LINTER"; vle_main "$MALF" ) 2>&1)"
UNREAD_MSG='is present but UNREADABLE'
if [ "$SEAL_RC" -eq 1 ] && grep -Fq "$UNREAD_MSG" <<<"$SEAL_OUT"; then
  ok "a contract present at mode 000 exits 1 and is reported as UNREADABLE, by its own E17 message"
else
  bad "a contract present at mode 000 exits 1 and is reported as UNREADABLE, by its own E17 message"
fi
if grep -Fq "got '<none>'" <<<"$SEAL_OUT" || grep -Fq 'read ZERO clauses' <<<"$SEAL_OUT" || grep -Fq "could not read 'consumer_crosswalk_file:'" <<<"$SEAL_OUT"; then
  bad "the sealed contract draws NONE of the malformed-contract messages (got '<none>', ZERO clauses, missing crosswalk key) — one cause, one message"
else
  ok "the sealed contract draws NONE of the malformed-contract messages (got '<none>', ZERO clauses, missing crosswalk key) — one cause, one message"
fi
say "$(grep -Fq "got '<none>'" <<<"$MALF_OUT" && ! grep -Fq "$UNREAD_MSG" <<<"$MALF_OUT" && echo 1 || echo 0)" \
  "NEAR-MISS: a READABLE contract missing contract_version still says got '<none>' and is NOT called unreadable"
say "$(grep -Fq "$UNREAD_MSG" <<<"$CLEAN_OUT" && echo 0 || echo 1)" \
  "the readable, well-formed consumer never draws the UNREADABLE message"
# ---------------------------------------------------------------------------
# The cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome this fixture reads (exit 0
# the conforming consumer, exit 1 the malformed receipts), each compared byte for byte with the in-process call on the
# same input (stdout, stderr and exit separately) and asserting its own outcome.
# ---------------------------------------------------------------------------
EQ="$TMP/eq"; mkdir -p "$EQ" || exit 2
eqv() { # eqv <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two answers are identical
  local id="$1"; shift
  ( fx_inproc "$LINTER"; vle_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$LINTER" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(tail -2 "$EQ/$1.ip.out")" "$(head -2 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(tail -2 "$EQ/$1.cl.out")" "$(head -2 "$EQ/$1.cl.err")"; }
if eqv cli-pass "$CONS" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -q '^LAYER_CONFORMANCE v1 .* errors=0 ' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program passes the conforming consumer exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with errors=0 ($(eq_twin cli-pass))"; fi
if eqv cli-fail "$BAD" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && grep -q "no-receipt.md: missing 'conforms_to:'" "$EQ/cli-fail.cl.out"; then
  ok "cli-fail: the program refuses the malformed receipts exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 with the E17 missing-receipt row ($(eq_twin cli-fail))"; fi

# THE ASSERTION-COUNT FLOOR. A skipped arm prints a shorter green report, which reads exactly like a passing one.
EXPECTED_ASSERTIONS=22
echo
report_end layer-conforms-to "$EXPECTED_ASSERTIONS"
