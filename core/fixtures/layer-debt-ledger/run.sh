#!/usr/bin/env bash
# layer-debt-ledger — assert the layer-debt reader can actually SEE a debt, and can tell an
# open one from a discharged one.
#
# THE DEFECT THIS EXISTS TO CATCH. `audit-layer-debt.sh` reports obligations the layer
# adjudications left behind. Every failure mode it has is SILENT: subtract the closed set
# wrongly and a discharged debt is reported forever until the reader is ignored; subtract it
# too eagerly and an open debt vanishes; read a missing register as "no debts" and the whole
# thing reports CLEAN on a tree it never opened. None of those change an exit code, because
# this is a reporter. So every assertion here is on the OUTPUT.
#
# Usage: run.sh [audit-layer-debt.sh]
# Exit:  0 = every assertion holds, 1 = the reader regressed, 2 = fixture broken.
set -uo pipefail

# HERMETIC — a consumer that pins AI_DLC_* in settings.json exports it into every session,
# and `git push` inherits it. Scrub by pattern so a NEW tunable cannot reintroduce the
# coupling; per-command assignments still work.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
AUDIT="$(pick "${1:-}" \
  "$HERE/../../scripts/audit-layer-debt.sh" \
  "$HERE/../../../core/scripts/audit-layer-debt.sh" \
  "$HERE/../../../scripts/ai-dlc/audit-layer-debt.sh")"
[ -n "$AUDIT" ] || { echo "FIXTURE ERROR: cannot locate audit-layer-debt.sh" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
REG="$WORK/register.jsonl"

EXPECTED_ASSERTIONS=16
fails=0; made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

row() { # row <entry> <verdict> <reason> [owed-json] [closes-json]
  python3 - "$1" "$2" "$3" "${4:-}" "${5:-}" >>"$REG" <<'PY'
import json, sys
e, v, reason, owed, closes = sys.argv[1:6]
r = {"clause":"LC-E4","entry":e,"subject_digest":"0"*40,"verdict":v,
     "recorded_utc":"2026-08-06T00:00:00Z","reason":reason}
if owed:   r["owed"] = json.loads(owed)
if closes: r["closes_owed"] = json.loads(closes)
print(json.dumps(r))
PY
}

run() { bash "$AUDIT" --register "$REG" 2>&1; }

# --- the corpus ---------------------------------------------------------------------------
: >"$REG"
row "extensions/a.md" still-additive "additive; core says nothing about this surface"
row "extensions/b.md" still-additive "carries an obligation" '{"id":"OWED-OPEN-1","what":"split X out","closes_when":"after the pull"}'
row "extensions/c.md" still-additive "carries one that gets paid" '{"id":"OWED-PAID-1","what":"delete Y"}'
row "extensions/c.md" still-additive "and here it is paid" '' '["OWED-PAID-1"]'
row "extensions/d.md" still-additive "the fork is named as a follow-up rather than done here"
row "extensions/e.md" still-additive "mentions test-check18-debt-audit, a filename"
row "extensions/f.md" contradicts-core "declared AND prosey: deferred remediation still owed" '{"id":"OWED-BOTH-1","what":"refile as override"}'

out="$(run)"

# --- 1. an undischarged debt is OPEN -------------------------------------------------------
if grep -q 'OWED-OPEN-1' <<<"$out" && grep -qE '^OPEN \(2\)' <<<"$out"; then
  ok "an undischarged \`owed\` is reported OPEN"
else
  bad "the open debt was not reported"; sed 's/^/        /' <<<"$out"
fi

# --- 2. a discharged debt is NOT open ------------------------------------------------------
# THE LOAD-BEARING ONE. Closing is a LATER row naming the id, because the register is
# append-only; a reader that ignores `closes_owed` reports every paid debt forever, and a
# ledger that never shrinks is one nobody reads.
if grep -q 'OWED-PAID-1' <<<"$out"; then
  bad "a debt closed by a later row is still reported OPEN — the ledger can never shrink"
else
  ok "a debt closed by a later row drops out of OPEN"
fi

# --- 3. prose-only obligations surface as UNDECLARED ---------------------------------------
if grep -qE '^UNDECLARED \(1\)' <<<"$out" && grep -q 'd\.md' <<<"$out"; then
  ok "a prose-only obligation is reported UNDECLARED (the migration backlog)"
else
  bad "prose-only obligations were not surfaced"; sed 's/^/        /' <<<"$out"
fi

# --- 4. CONTROL: a cue inside a longer identifier is NOT prose ------------------------------
# Measured false positive on the reference register: `debt` inside `test-check18-debt-audit`.
if grep -q 'e\.md' <<<"$out"; then
  bad "a cue embedded in a filename was flagged — the arm fires on identifiers"
else
  ok "CONTROL: a cue inside a longer identifier is not flagged"
fi

# --- 5. CONTROL: a row that DECLARES is not also listed as undeclared -----------------------
# f.md carries both an `owed` object and obligation-shaped prose. A commitment outranks a
# suspicion; listing it twice would make the migration backlog never reach zero.
und_block="$(awk '/^UNDECLARED/,0' <<<"$out")"
if grep -q 'f\.md' <<<"$und_block"; then
  bad "a row that declares \`owed\` was ALSO listed as undeclared — the backlog cannot drain"
else
  ok "CONTROL: a declaring row is not also counted as undeclared"
fi

# --- 6. CONTROL: a clean row appears nowhere -----------------------------------------------
if grep -q 'a\.md' <<<"$out"; then
  bad "a row with no debt and no cue was reported — the reader flags everything"
else
  ok "CONTROL: a row with neither a debt nor a cue is silent"
fi

# --- 7. an ABSENT register is DISARMED, never 'no debts' -----------------------------------
# The whole subject of this file is obligations that went invisible; a reader that reports
# CLEAN on a register it could not open is the same failure one level up.
miss_out="$(bash "$AUDIT" --register "$WORK/nope.jsonl" 2>&1)"; miss_rc=$?
if [ "$miss_rc" -eq 2 ] && grep -q 'DISARMED' <<<"$miss_out"; then
  ok "an unreadable register exits 2 DISARMED rather than reporting zero"
else
  bad "a missing register did not disarm (rc=$miss_rc)"; sed 's/^/        /' <<<"$miss_out"
fi

# --- 8. MUTATION: drop the closed-set subtraction -------------------------------------------
# Assertion 2 is an ABSENCE, and an absence passes for a reader that emitted nothing. Mutate
# the subtraction and demand the paid debt reappears; without this, assertion 2 also passes
# against a reader whose OPEN arm is dead.
MUT="$WORK/mutant.sh"
cp "$AUDIT" "$MUT"
python3 - "$MUT" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
n = s.replace("open_items = [v for k, v in declared.items() if k not in closed]",
              "open_items = [v for k, v in declared.items()]")
assert n != s, "MUTATION MATCHED NOTHING"
io.open(p, "w", encoding="utf-8").write(n)
PY
if cmp -s "$AUDIT" "$MUT"; then
  bad "FIXTURE ERROR: the mutation matched nothing — assertion 2 proves nothing"
else
  mut_out="$(bash "$MUT" --register "$REG" 2>&1)"
  if grep -q 'OWED-PAID-1' <<<"$mut_out"; then
    ok "MUTATION: without the closed-set subtraction the paid debt reappears (so assertion 2 is live)"
  else
    bad "MUTATION: the paid debt stayed hidden even with the subtraction removed — assertion 2 is vacuous"
  fi
fi

# --- 9. a `closes_owed` written as a STRING still closes its debt ---------------------------
# WHY THIS COULD NOT BE SEEDED WITH `row()`. That helper builds the field with
# `json.loads(closes)`, so every value it can produce is already a well-formed array — a fixture
# whose tree cannot EXPRESS the defect proves nothing about it. The row below is written raw.
#
# THE DEFECT. `closes_owed` is `{"type": "array"}` in the schema, but a bare string is still
# valid JSON and still parses, and `for cid in "OWED-X"` iterates CHARACTERS. Nothing errored,
# nothing warned, and the debt was reported OPEN forever. Filed by the graph consumer as
# PC-S302-AUDIT-LAYER-DEBT-SILENTLY-IGNORES-A-STRING-CLOSES-OWED after one such row had been
# reporting a discharged debt open on every pull since the day it was closed.
STR_REG="$WORK/register-strclose.jsonl"
: >"$STR_REG"
python3 - >>"$STR_REG" <<'PY'
import json
base = {"clause":"LC-E4","subject_digest":"0"*40,"verdict":"still-additive",
        "recorded_utc":"2026-08-06T00:00:00Z"}
print(json.dumps(dict(base, entry="extensions/s.md", reason="carries one that gets paid",
                      owed={"id":"OWED-STR-1","what":"delete Z"})))
# THE ROW UNDER TEST: closes_owed as a bare STRING, which the schema forbids and json accepts.
print(json.dumps(dict(base, entry="extensions/s.md", reason="and here it is paid",
                      closes_owed="OWED-STR-1")))
PY
str_out="$(bash "$AUDIT" --register "$STR_REG" 2>&1)"
if grep -q 'OWED-STR-1' <<<"$str_out"; then
  bad "a string-valued \`closes_owed\` did not close its debt — the id is iterated character by character and the debt is reported OPEN forever"
  sed 's/^/        /' <<<"$str_out"
else
  ok "a \`closes_owed\` written as a bare string still discharges its debt"
fi

# ...and it is COUNTED, not silently repaired. A quiet coercion makes the schema unenforceable by
# making its violation harmless, so the row never gets corrected.
grep -q 'MISTYPED_CLOSES_OWED=1' <<<"$str_out" \
  && ok "the mistyped row is reported, so the register still gets fixed" \
  || bad "the string form was coerced silently — nothing tells the operator the row violates its own schema"

# CONTROL: the well-formed corpus above must NOT be reported as mistyped. Without this the arm
# passes against a reader that counts every row, and the count discriminates nothing.
grep -q 'MISTYPED_CLOSES_OWED' <<<"$out" \
  && bad "CONTROL: the well-formed register was reported as carrying a mistyped row — the counter fires on correct data" \
  || ok "CONTROL: a register whose closes_owed are all arrays reports no mistyped rows"

# --- 10/11. MUTATIONS: the two absence-shaped arms above -----------------------------------
# Assertion 9 is an ABSENCE (`OWED-STR-1` must NOT appear) and so is assertion 11's control.
# Measured: with the reader replaced by `exit 0` BOTH scored green, which is precisely the
# defect assertion 8 exists for one arm up. These two make them mean something.
mkmut() { # mkmut <label> <find> <replace> -> prints path, or empty on a no-op mutation
  local m="$WORK/mutant-$1.sh"
  cp "$AUDIT" "$m"
  python3 - "$m" "$2" "$3" <<'PY'
import io, sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding="utf-8").read()
n = s.replace(a, b)
if n == s:
    raise SystemExit(3)
io.open(p, "w", encoding="utf-8").write(n)
PY
  [ $? -eq 0 ] && ! cmp -s "$AUDIT" "$m" && printf '%s' "$m"
}

# 10 — the coercion reverted to the bare `or []` this release replaced. The string form must
# stop closing its debt, i.e. the id REAPPEARS. Asserted as a positive outcome, not as the
# absence of the new message.
M10="$(mkmut a9 '    co = r.get("closes_owed")
    if isinstance(co, str):
        co, mistyped = [co], mistyped + 1
    elif co is None:
        co = []
    elif not isinstance(co, list):
        co, mistyped = [], mistyped + 1
    for cid in co:' '    for cid in r.get("closes_owed") or []:')"
if [ -z "$M10" ]; then
  bad "FIXTURE ERROR: the assertion-9 mutation matched nothing — assertion 9 proves nothing"
else
  m10_out="$(bash "$M10" --register "$STR_REG" 2>&1)"
  grep -q 'OWED-STR-1' <<<"$m10_out" \
    && ok "MUTATION: without the coercion the string-form close stops working and the debt reappears (so assertion 9 is live)" \
    || bad "MUTATION: the debt stayed closed with the coercion removed — assertion 9 passes whatever the reader does"
fi

# 11 — the mistyped counter widened to flag well-formed lists. Assertion 11's control must go
# red, which is what makes it a statement about correct data rather than about silence.
M11="$(mkmut a11 '    elif co is None:' '    elif isinstance(co, list) and co:
        mistyped += 1
    elif co is None:')"
if [ -z "$M11" ]; then
  bad "FIXTURE ERROR: the assertion-11 mutation matched nothing — assertion 11's control proves nothing"
else
  m11_out="$(bash "$M11" --register "$REG" 2>&1)"
  grep -q 'MISTYPED_CLOSES_OWED' <<<"$m11_out" \
    && ok "MUTATION: a counter that flags well-formed lists is caught by the control (so assertion 11 discriminates)" \
    || bad "MUTATION: the well-formed register still reported no mistyped rows — assertion 11's control is vacuous"
fi

# --- 12/13/14. a `contradicts-core` ruling that declares no debt ---------------------------
# The verdict no detector can re-derive, keyed on a digest that expires the next time either
# file moves — after which the ruling is unaddressable rather than overwritten. Measured on
# the reference consumer: nine days unactioned while ten later rows on the same entry recorded
# their own subjects, none of them wrong and none about it.
#
# THE CORPUS CARRIES BOTH SHAPES, and the second is the whole scoping argument: entry `y` has
# its contradicts-core on one row and its `owed` on a LATER row under a different digest, which
# is how both real debts on the reference consumer were actually declared. Row scoping would
# report it, and could never stop reporting it — the register is append-only, so a historical
# row can never acquire an `owed`.
CC_REG="$WORK/register-contradicts.jsonl"
: >"$CC_REG"
python3 - >>"$CC_REG" <<'PY'
import json
base = {"clause":"LC-E4","recorded_utc":"2026-08-06T00:00:00Z"}
# x — ruled against core, debt never declared anywhere. REPORTED.
print(json.dumps(dict(base, entry="extensions/x.md", subject_digest="a"*40,
                      verdict="contradicts-core", reason="relaxes a core check")))
# y — same ruling, and a LATER row under a different digest declares the debt. NOT reported.
print(json.dumps(dict(base, entry="extensions/y.md", subject_digest="b"*40,
                      verdict="contradicts-core", reason="relaxes a core check")))
print(json.dumps(dict(base, entry="extensions/y.md", subject_digest="c"*40,
                      verdict="still-additive", reason="declaring the migration",
                      owed={"id":"OWED-Y-SPLIT","what":"refile as an override"})))
PY
cc_out="$(bash "$AUDIT" --register "$CC_REG" 2>&1)"

if grep -qE '^CONTRADICTS-CORE WITHOUT AN `owed` \(1\)' <<<"$cc_out" && grep -q 'x\.md' <<<"$cc_out"; then
  ok "a contradicts-core entry that declares no \`owed\` anywhere is reported"
else
  bad "the undeclared contradicts-core ruling was not reported — it expires with its digest and nothing else names it"
  sed 's/^/        /' <<<"$cc_out"
fi

# CONTROL, and it is the arm the mutant below exists for: an entry whose debt is declared on a
# LATER row must NOT be reported. Absence-shaped, so it passes against an arm that reports
# nothing at all.
cc_block="$(awk '/^CONTRADICTS-CORE/,0' <<<"$cc_out")"
grep -q 'y\.md' <<<"$cc_block" \
  && bad "CONTROL: an entry whose \`owed\` sits on a later row was reported — the arm is row-scoped, and an append-only register can never satisfy it" \
  || ok "CONTROL: a contradicts-core entry whose debt is declared by a LATER row is not reported"

# MUTATION: entry scoping reduced to row scoping. The control must go red, and `y` must appear.
M14="$(mkmut cc 'owed_entries = {(r.get("clause"), r.get("entry")) for r in rows
                if isinstance(r.get("owed"), dict) and r.get("owed", {}).get("id")}' 'owed_entries = set()')"
if [ -z "$M14" ]; then
  bad "FIXTURE ERROR: the entry-scoping mutation matched nothing — the control proves nothing"
else
  m14_out="$(bash "$M14" --register "$CC_REG" 2>&1)"
  grep -q 'y\.md' <<<"$(awk '/^CONTRADICTS-CORE/,0' <<<"$m14_out")" \
    && ok "MUTATION: scoped to the ROW, the later-declared entry is reported too — so the control is what proves the scope" \
    || bad "MUTATION: row scoping still did not report the later-declared entry — the control is vacuous"
fi

echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "layer-debt-ledger: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. One did not execute at all, which is not the same as one that passed."
  exit 1
fi
if [ "$fails" -eq 0 ]; then echo "layer-debt-ledger: PASS ($made assertions)"; exit 0; fi
echo "layer-debt-ledger: FAIL ($fails of $made)"; exit 1
