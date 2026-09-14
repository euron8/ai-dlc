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

EXPECTED_ASSERTIONS=50
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

# 10 — the string coercion broken so the id is iterated CHARACTER BY CHARACTER, which is the
# defect assertion 9 names. The string form must stop closing its debt, i.e. the id REAPPEARS.
# Asserted as a positive outcome, not as the absence of the new message.
#
# THE ANCHOR MOVED AT v0.453.0 AND THE MUTATION FOLLOWED IT. This coercion used to be spelled
# inline in the declaration loop; that release lifted it into `closes_ids()` so the migration
# arm could read the same predicate rather than restate it. The old anchor then matched
# nothing, and `mkmut` correctly refused to let a no-op pass as a mutation — which is the
# fixture working, not failing. **The repair for a fixture that has lost its subject is a NEW
# SUBJECT, never a relaxed assertion**, so this mutates the coercion where it now lives and
# asserts the identical observable.
M10="$(mkmut a9 '    if isinstance(co, str):
        return [co], 1' '    if isinstance(co, str):
        return list(co), 1')"
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
# Anchor moved at v0.453.0 for the same reason as assertion 9's above.
M11="$(mkmut a11 '    return co, 0' '    return co, (1 if co else 0)')"
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

# --- 15-24. a row that CITES a resolvable `OWED-` id is a REFERENCE, not a declaration --------
# THE DEFECT. The UNDECLARED arm's remedy is "re-record each with an `owed` object". A row whose
# reason cites an id some OTHER row declares was filed in the same bucket as a genuine offender,
# so obeying the remedy files a SECOND id for work already tracked — a wrong WRITE prompted by a
# false finding, not a glance. Measured on the reference consumer's 471-row register: 1 of the 7
# reported rows, `checks/gate-validation-push-914.md`, citing `OWED-S330-914-RETRO-SCOPE`.
#
# THE JOIN IS AGAINST THE DECLARED SET, NEVER A TOKEN GRAMMAR, and that is what `c3`/M1 below
# assert: a row inventing an id nothing declares has no handle either and stays reported.
CIT_REG="$WORK/register-cited.jsonl"
: >"$CIT_REG"
python3 - >>"$CIT_REG" <<'PY'
import json
base = {"clause":"LC-E4","subject_digest":"0"*40,"verdict":"still-additive",
        "recorded_utc":"2026-01-01T00:00:00Z"}
def r(entry, reason, owed=None):
    d = dict(base, entry=entry, reason=reason)
    if owed: d["owed"] = owed
    print(json.dumps(d))
# c1 SUBJECT — a standalone cue beside a citation of an id c2 declares. Must be acquitted.
r("extensions/c1.md", "The narrowing is owed under OWED-CIT-X.")
# c2 — the DECLARING row. Its debt must still be OPEN; the acquittal must not reach the OPEN arm.
r("extensions/c2.md", "declaring the migration", {"id":"OWED-CIT-X","what":"split X out"})
# c3 UNRESOLVABLE — a citation of nothing is not a handle. Must STAY reported. Kills M1.
r("extensions/c3.md", "The narrowing is owed under OWED-CIT-NOPE.")
# c4 GENUINE — no citation at all. Must stay reported. Kills M3.
r("extensions/c4.md", "A narrowing is still owed here.")
# c5 INSIDE-TOKEN CONTROL — the state the filed remedy targeted, unconstructible either way.
# Reported by neither the old arm nor the new one, which is what makes it a control on the
# claim that this fix changes nothing there.
r("extensions/c5.md", "Tracked on the row that carries OWED-DEBT-DEFERRED.")
# c6 THE COST, SEEDED RATHER THAN ASSUMED — one obligation cited, a SECOND stated in prose.
# Row scope silences it; clause scope would not. Named here so the trade is visible in the arm.
r("extensions/c6.md", "Filed under OWED-CIT-X. A second narrowing is still owed.")
# c7 NEAR-MISS on the denial discount — a cue already denied by `no`, beside a resolvable token.
# It must stay unreported, and for the OLD reason; M3 proves the new key did not take it over.
r("extensions/c7.md", "No owed beyond OWED-CIT-X.")
# c8 — closes_owed DISCHARGE naming an id NO row declares, so `closed` and `declared` are
# DIFFERENT SETS on this register. Without that the wrong-set mutant M2 below is
# indistinguishable from the disable mutant M3 — measured, both moved the identical four cells
# — and two mutants that move one cell between them prove one thing, not two.
print(json.dumps(dict(base, entry="extensions/c8.md", reason="Debt discharged.",
                      closes_owed=["OWED-CIT-OTHER"])))
# c9 — M2'S OWN SUBJECT, and it exists because no other seed can see that mutant. A standalone
# cue beside a citation of `OWED-CIT-OTHER`, an id that is CLOSED and never DECLARED — so it
# was never on the record as an obligation at all, and a citation of it is a citation of
# nothing. The fix REPORTS it; a join taken against `closes_owed` acquits it. No mutation of
# the derivation reaches this row, and no other row separates the two id sets.
r("extensions/c9.md", "The narrowing is owed under OWED-CIT-OTHER.")
# c10/c11/c12 — THE DISCHARGED-CITATION SHAPE, which is what the live register actually holds:
# on the reference consumer all 36 declared ids are discharged, so a key of `declared - closed`
# would be EMPTY there and acquit nothing. c10 cites `OWED-C`, c11 declares it, c12 pays it.
# c10 must be ACQUITTED — telling an adjudicator to re-record it with a NEW `owed` object
# re-opens finished work under a second id. Read against c9 this pair is the whole distinction:
# c10's id was DECLARED and then paid, c9's was only ever named in a discharge.
r("extensions/c10.md", "The narrowing is owed under OWED-C.")
r("extensions/c11.md", "declaring the second migration", {"id":"OWED-C","what":"split C out"})
print(json.dumps(dict(base, entry="extensions/c12.md", reason="Debt discharged.",
                      closes_owed=["OWED-C"])))
PY
cit_out="$(bash "$AUDIT" --register "$CIT_REG" 2>&1)"
cit_und="$(awk '/^UNDECLARED/,/^$/' <<<"$cit_out")"

# 15 — the SUBJECT is acquitted. Absence-shaped, which is why M1/M3 below exist.
grep -q 'c1\.md' <<<"$cit_und" \
  && { bad "a row CITING a resolvable \`OWED-\` id is still filed as undeclared — obeying the printed remedy declares a duplicate obligation for work another row already tracks"; sed 's/^/        /' <<<"$cit_out"; } \
  || ok "a row citing a resolvable \`OWED-\` id is not filed as an undeclared obligation"

# 16 — PRESENCE: a citation of an id NOTHING declares is not a handle and stays reported. This
# is the arm that separates the join from a token grammar, and it is M1's killer.
grep -q 'c3\.md' <<<"$cit_und" \
  && ok "a citation of an id no row declares is still reported — the acquittal joins the DECLARED set, not an \`OWED-\` spelling" \
  || { bad "a row citing an UNRESOLVABLE id was acquitted — the key is a token grammar and a row can silence itself by inventing an id"; sed 's/^/        /' <<<"$cit_out"; }

# 17 — PRESENCE: a genuine undeclared obligation with no citation is untouched. M3's killer, and
# the arm that makes every absence above mean something against a reader emitting nothing.
grep -q 'c4\.md' <<<"$cit_und" \
  && ok "a genuine undeclared obligation carrying no citation is still reported" \
  || { bad "the genuine obligation vanished — the acquittal reaches rows that cite nothing"; sed 's/^/        /' <<<"$cit_out"; }

# 18 — the VERDICT, asserted as the exact reported set rather than as a count. A count is
# reachable by the wrong rows; the names are not.
cit_names="$(grep -oE 'c[0-9]+\.md' <<<"$cit_und" | sort -u | tr '\n' ' ')"
[ "$cit_names" = "c3.md c4.md c9.md " ] \
  && ok "the reported set is exactly {c3,c4,c9} — the rows with no resolvable handle" \
  || { bad "the reported set was '$cit_names', expected 'c3.md c4.md c9.md '"; sed 's/^/        /' <<<"$cit_out"; }

# 18b — THE DISCHARGED CITATION IS ACQUITTED. This is the shape the live register actually
# holds; a key of `declared - closed` acquits NOTHING there, because every declared id is paid.
grep -q 'c10\.md' <<<"$cit_und" \
  && { bad "a row citing a DISCHARGED obligation was filed as undeclared — obeying the remedy re-opens finished work under a new id"; sed 's/^/        /' <<<"$cit_out"; } \
  || ok "a row citing an obligation that was declared and later DISCHARGED is acquitted — the handle is the declaring row, not this run's OPEN list"

# 18c — CONTROL, one property apart from 18b: `c9` cites an id that is closed and NEVER
# declared, so it was never on the record as an obligation. It must stay reported. Without this
# twin, 18b passes equally against a key joined on `closed` — which is the acquittal inverted.
grep -q 'c9\.md' <<<"$cit_und" \
  && ok "CONTROL: a citation of an id that is CLOSED but never DECLARED is still reported — the discharge join is not a declaration" \
  || { bad "CONTROL: the closed-but-never-declared citation was acquitted — the key reads discharges as declarations"; sed 's/^/        /' <<<"$cit_out"; }

# 19 — THE ACQUITTAL DOES NOT REACH THE OPEN ARM. The declared debt must still be enumerated;
# an acquittal that silenced the declaration would satisfy this section by deleting its subject.
grep -q 'OWED-CIT-X' <<<"$cit_out" && grep -qE '^OPEN \(1\)' <<<"$cit_out" \
  && ok "the cited obligation is still OPEN — the acquittal moves the suspicion, never the commitment" \
  || { bad "the declared debt stopped being reported OPEN — the acquittal reached the enumeration it depends on"; sed 's/^/        /' <<<"$cit_out"; }

# 20 — the INSIDE-TOKEN control, the state the filed remedy named. Unreported before and after.
grep -q 'c5\.md' <<<"$cit_und" \
  && bad "CONTROL: the inside-token row was reported — the \`(?![\\w-])\` lookahead is gone and the refuted remedy's premise changed" \
  || ok "CONTROL: a cue occurring only INSIDE an \`OWED-\` token is reported by neither arm"

# --- MUTANTS ------------------------------------------------------------------------------
# 21 — M1, the OVER-BROAD non-fix: acquit on ANY `OWED-` token, resolvable or not. This is the
# closer BL-227 measured as satisfying the old receipt while shipping nothing, so it is built
# and scored rather than argued about. It must go RED on assertion 16 and ONLY there.
M_CIT1="$(mkmut cit1 'CITED = (re.compile(r"(?<![\w-])(?:%s)(?![\w-])"
                    % "|".join(re.escape(i) for i in sorted(declared, key=len, reverse=True)))
         if declared else None)' 'CITED = re.compile(r"(?<![\w-])OWED-[A-Za-z0-9][A-Za-z0-9-]*(?![\w-])")')"
if [ -z "$M_CIT1" ]; then
  bad "FIXTURE ERROR: the any-token mutation DID NOT APPLY — assertion 16 proves nothing"
else
  m1_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$M_CIT1" --register "$CIT_REG" 2>&1)")"
  if grep -q 'c3\.md' <<<"$m1_und"; then
    bad "MUTATION M1: an any-token acquittal still reported the unresolvable citation — assertion 16 cannot see the difference between a join and a spelling"
  elif grep -q 'c4\.md' <<<"$m1_und"; then
    ok "MUTATION M1: acquitting on ANY \`OWED-\` token silences the unresolvable citation (so assertion 16 is live), while the genuine row survives"
  else
    bad "MUTATION M1: the genuine obligation vanished too — M1 moves two cells and assertion 16 is entangled with assertion 17"
  fi
fi

# 22 — M2, the join taken against the WRONG SET: `closes_owed` ids instead of `owed.id`. The
# plausible wrong derivation, and it INVERTS the acquittal: it silences the row citing a
# DISCHARGED id and reports the row citing a DECLARED one.
#
# SCORED ON `c9`, WHICH IS THE ONLY ROW M3 CANNOT ALSO MOVE. Keyed on `c1` this mutant moved
# the identical four cells as M3 — measured before this seed existed — so two mutants proved
# one property and one of them was vacuous. `c9` cites an id that is closed and never declared,
# a state no other seed builds, and M2 is the only variant here that acquits it.
M_CIT2="$(mkmut cit2 '% "|".join(re.escape(i) for i in sorted(declared, key=len, reverse=True)))
         if declared else None)' '% "|".join(re.escape(i) for i in sorted(closed, key=len, reverse=True)))
         if closed else None)')"
if [ -z "$M_CIT2" ]; then
  bad "FIXTURE ERROR: the wrong-set mutation DID NOT APPLY — assertion 15 proves nothing about WHICH set is joined"
else
  m2_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$M_CIT2" --register "$CIT_REG" 2>&1)")"
  if grep -q 'c9\.md' <<<"$m2_und"; then
    bad "MUTATION M2: a join against \`closes_owed\` still reported the discharged-id citation — assertion 18 cannot tell the DECLARED set from the CLOSED one"
  elif grep -q 'c1\.md' <<<"$m2_und"; then
    ok "MUTATION M2: joined against \`closes_owed\` the discharged-id row is acquitted and the declared-id row reported again — the acquittal inverts, so assertion 18 names WHICH set is joined"
  else
    bad "MUTATION M2: neither row moved — the two id sets are identical on this register and M2 has no subject"
  fi
fi

# 22b — M4, THE REFUSED KEY: `declared - closed`, i.e. acquit only on an id that is still OPEN.
# It is the reading a hand arrives at from the phrase "an obligation the report already
# enumerates", and it is the reason that phrasing is not in this file. Scored on `c10`, its own
# subject — no other mutant here moves that row. On the reference consumer this key acquits
# NOTHING at all, every declared id there being discharged, so without a seeded discharged
# citation it is a wrong answer no corpus could expose.
M_CIT4="$(mkmut cit4 'in sorted(declared, key=len, reverse=True)))
         if declared else None)' 'in sorted(set(declared) - closed, key=len, reverse=True)))
         if (set(declared) - closed) else None)')"
if [ -z "$M_CIT4" ]; then
  bad "FIXTURE ERROR: the open-only mutation DID NOT APPLY — assertion 18b proves nothing"
else
  m4_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$M_CIT4" --register "$CIT_REG" 2>&1)")"
  if grep -q 'c10\.md' <<<"$m4_und"; then
    grep -q 'c1\.md' <<<"$m4_und" \
      && bad "MUTATION M4: acquitting only on OPEN ids moved the live citation too — assertion 18b is entangled with assertion 15" \
      || ok "MUTATION M4: acquitting only on ids still OPEN files the discharged citation as undeclared again (so assertion 18b is live), while the open citation stays acquitted"
  else
    bad "MUTATION M4: the discharged citation stayed acquitted under an OPEN-only key — assertion 18b passes whichever half of the declared set is joined"
  fi
fi

# 23 — M3, the fix DISABLED at its only reader. Both absence-shaped arms (15 and 20) must be
# unable to tell this from the fix, and assertion 15 must go RED. Anchored on the `continue`
# rather than on the `CITED =` assignment so it reverts the BEHAVIOUR and not the derivation —
# reverting only one layer of a two-layer change leaves a mutant that proves the other layer.
#
# THE ANCHOR MOVED WITH THE CITATION-NEGATION CHANGE AND THIS MUTATION FOLLOWED IT. The acquittal
# was a whole-reason `CITED.search(reason)`; it is now a per-OCCURRENCE `any(not
# citation_denied(...))` spanning two lines, so the old single-line anchor matches NOTHING and
# `mkmut` refuses the no-op — the fixture goes red on the commit that fixes the defect, which
# reads exactly like the fix being wrong. Re-anchored on the two-line form, SCORED THREE WAYS as
# `fixture-mutants.md` requires:
#   ANCHOR UNIQUE — the three-line literal below occurs once in the subject; the impossible-anchor
#     control in the same derivation occurs zero times, so the 1 is a discriminating 1.
#   RIGHT OBSERVABLE FOR THE RIGHT REASON — on `CIT_REG` it reports c1 (the citation acquittal is
#     gone) and leaves c7 acquitted (the OLD `cue_denied` discount still runs), which is the
#     conjunction below. On `CIT_NEG_REG` it reports EVERY row, the signature of a reader that
#     consults no citation at all.
#   FAILS ONLY ITS OWN ASSERTION — of the n-seeds it alone moves n0 and n9, and those two cells
#     are moved by no other mutant in this file.
M_CIT3="$(mkmut cit3 '    if CITED is not None and any(not citation_denied(reason, m)
                                 for m in CITED.finditer(reason)):
        continue' '    if False:
        continue')"
if [ -z "$M_CIT3" ]; then
  bad "FIXTURE ERROR: the disable mutation DID NOT APPLY — assertion 15 proves nothing"
else
  m3_out="$(bash "$M_CIT3" --register "$CIT_REG" 2>&1)"
  m3_und="$(awk '/^UNDECLARED/,/^$/' <<<"$m3_out")"
  if grep -q 'c1\.md' <<<"$m3_und"; then
    grep -q 'c7\.md' <<<"$m3_und" \
      && bad "MUTATION M3: with the citation key disabled the ALREADY-DENIED row appeared too — the new key had taken over \`cue_denied\`'s subject" \
      || ok "MUTATION M3: with the citation key disabled the cited row is filed as undeclared again (so assertion 15 is live), while the \`no\`-denied row stays acquitted by the OLD discount"
  else
    bad "MUTATION M3: the cited row stayed acquitted with the key disabled — assertion 15 passes against a reader that never consults it"
  fi
fi

# --- 26-40. A DECLARED-ID CITATION DENIED IN ITS OWN SENTENCE IS NOT A HANDLE ----------------
# THE DEFECT. The acquittal above was a whole-reason `CITED.search(reason)`, so ANY occurrence
# of a declared id acquitted the row — including one inside a clause that DENIES the handle.
# *"This is not tracked under OWED-CIT-X and a narrowing is still owed."* names a real,
# undeclared obligation and says in as many words that the id is not its handle, and it was
# silenced. That is the false-acquittal direction, which for a recall-biased arm is the
# expensive one: the glance a false positive costs is nothing beside a debt that stops being
# reported.
#
# THE SUBJECT IS A SECOND VOCABULARY, NOT A WIDER `NEGATED`. `CITATION_NEGATED` governs the
# MENTION of a declared id and admits `not`; `NEGATED` governs a CUE and excludes it, on a
# measurement recorded beside that regex. n8 and MN10 below are the pair that holds the two
# apart — widening `NEGATED` reaches n8, and nothing else here does.
#
# WHAT EACH SEED ISOLATES, and each is here because it is the only row in this register that
# dies under its own mutant:
#   n0  live shape, ACQUITTED — an un-negated mention. The fix must not touch it. Only M_CIT3
#       moves it, which is what makes the whole section a statement about the citation key.
#   n1  the filed subject, REPORTED — `not` before the mention in its own sentence.
#   n2  REPORTED — negator and mention straddle a COMMA. MN2's only cell; a comma-bounded
#       search starts after the `not` and finds nothing, which is why this bound is `.;:`.
#   n3  ACQUITTED — the negator sits in the PREVIOUS sentence and must not reach the mention.
#       Carries a `PROSE` cue of its own, so it is a row the arm would otherwise report: a
#       seed with no cue is acquitted by the cue filter and proves nothing about the bound.
#   n4  REPORTED — isolates `no`. MN5's only cell.
#   n5  REPORTED — isolates `rather than`. MN6's only cell.
#   n6  REPORTED — isolates `instead of`. MN7's only cell.
#   n7  ACQUITTED — one denied mention AND one clean mention. The per-OCCURRENCE `any` rule.
#       Scored on its OWN register below, never here; see MN8.
#   n8  CUE-SIDE CONTROL, REPORTED — `not` denying a cue with no citation anywhere. It is
#       reported before and after, and MN10 is the only mutant that acquits it.
#   n9  ACQUITTED — a `no` AFTER the mention. The search runs only BEFORE, so a negator
#       downstream of the id cannot deny it. Only M_CIT3 moves it.
#   n10 REPORTED — the sentence-initial `not` form, with no trailing `and ... still owed`
#       clause. MN4/MN9's cell: they and MN1 are the only mutants that acquit it.
CIT_NEG_REG="$WORK/register-citneg.jsonl"
: >"$CIT_NEG_REG"
python3 - >>"$CIT_NEG_REG" <<'PY'
import json
base = {"clause":"LC-E4","subject_digest":"0"*40,"verdict":"still-additive",
        "recorded_utc":"2026-01-01T00:00:00Z"}
def r(entry, reason, owed=None):
    d = dict(base, entry=entry, reason=reason)
    if owed: d["owed"] = owed
    print(json.dumps(d))
r("extensions/n0.md",  "The narrowing is owed under OWED-CIT-X.")
r("extensions/n1.md",  "This is not tracked under OWED-CIT-X and a narrowing is still owed.")
r("extensions/n2.md",  "Separately and not part of this verdict, OWED-CIT-X. A split is still deferred.")
r("extensions/n3.md",  "No restatement of core here. The narrowing is owed under OWED-CIT-X.")
r("extensions/n4.md",  "No handle under OWED-CIT-X; a split is still deferred.")
r("extensions/n5.md",  "Tracked here rather than under OWED-CIT-X; the split is still deferred.")
r("extensions/n6.md",  "Filed here instead of under OWED-CIT-X; the narrowing is still owed.")
r("extensions/n7.md",  "Not under OWED-CIT-X; the narrowing is owed under OWED-CIT-X.")
r("extensions/n8.md",  "A narrowing is not owed here.")
r("extensions/n9.md",  "The narrowing is owed under OWED-CIT-X, and no second split is deferred.")
r("extensions/n10.md", "Not tracked under OWED-CIT-X; a split is still deferred.")
# THE DECLARING ROW. Without it `declared` is empty, `CITED` is None, and every arm above
# passes for a reason that has nothing to do with the citation key.
r("extensions/nd.md", "declaring the migration", {"id":"OWED-CIT-X","what":"split X out"})
PY
cn_out="$(bash "$AUDIT" --register "$CIT_NEG_REG" 2>&1)"
cn_und="$(awk '/^UNDECLARED/,/^$/' <<<"$cn_out")"
cn_names() { grep -oE 'n[0-9]+\.md' <<<"$1" | sort -u | tr '\n' ' '; }
CN_EXPECT='n1.md n10.md n2.md n4.md n5.md n6.md n8.md '

# 26 — THE VERDICT, as the EXACT reported set. A membership assertion is reachable by the wrong
# rows; this names every cell of the register in one string, so any mutant that moves any row
# either way is caught here whether or not its own arm below fires.
cn_got="$(cn_names "$cn_und")"
[ "$cn_got" = "$CN_EXPECT" ] \
  && ok "the citation-negation reported set is exactly {n1,n2,n4,n5,n6,n8,n10} — every denied mention reported, every un-denied one acquitted" \
  || { bad "the citation-negation set was '$cn_got', expected '$CN_EXPECT'"; sed 's/^/        /' <<<"$cn_out"; }

# 27 — the filed SUBJECT, asserted on its own so a failure names the defect rather than a set.
grep -q 'n1\.md' <<<"$cn_und" \
  && ok "a row denying the handle in the mention's own sentence is still reported — a citation inside a clause that denies it is not a handle" \
  || { bad "the denied-citation row was acquitted — ANY occurrence of a declared id silences a row that says the id does not track it"; sed 's/^/        /' <<<"$cn_out"; }

# 28 — LIVE-SHAPE CONTROL, one property apart from 27: the same sentence without the negator.
# This is the row the whole acquittal exists for, and the measured live register holds exactly
# this shape. Without it every arm above is satisfied by a fix that acquits nothing at all.
grep -q 'n0\.md' <<<"$cn_und" \
  && { bad "CONTROL: the un-negated citation was reported — the new vocabulary reaches the live shape and the acquittal is gone"; sed 's/^/        /' <<<"$cn_out"; } \
  || ok "CONTROL: a citation with no negator before it is still acquitted — the fix narrows the acquittal, it does not delete it"

# 29 — the SENTENCE bound, from the acquitting side: a negator one sentence back does not reach.
grep -q 'n3\.md' <<<"$cn_und" \
  && { bad "CONTROL: a negator in the PREVIOUS sentence denied the mention — the search is unbounded and a `no` anywhere upstream silences a citation"; sed 's/^/        /' <<<"$cn_out"; } \
  || ok "CONTROL: a negator in the previous sentence does not deny the mention — the search is bounded to the mention's own sentence"

# 30 — and from the other side: a negator AFTER the mention does not reach it either. The bound
# is directional, and 29 alone passes against a search that reads the whole reason backwards.
grep -q 'n9\.md' <<<"$cn_und" \
  && { bad "CONTROL: a `no` occurring AFTER the mention denied it — the search does not stop at the mention"; sed 's/^/        /' <<<"$cn_out"; } \
  || ok "CONTROL: a negator occurring after the mention does not deny it — the search runs only on the text before"

# 31 — THE CUE SIDE DID NOT MOVE. `not` denies a MENTION and must not deny a CUE; this row has
# no citation at all, so only a widened `NEGATED` can acquit it. MN10 is its mutant.
grep -q 'n8\.md' <<<"$cn_und" \
  && ok "CONTROL: a \`not\`-denied CUE with no citation is still reported — \`not\` did not leak into \`NEGATED\`" \
  || { bad "CONTROL: the cue-side row was acquitted — \`not\` reached the cue filter, and the two vocabularies have collapsed into one"; sed 's/^/        /' <<<"$cn_out"; }

# 32 — STRUCTURAL: the citation vocabulary is its OWN compiled pattern. An alias
# (`CITATION_NEGATED = NEGATED`) satisfies every behavioural arm above whose seed does not turn
# on `not`, and reintroduces the coupling the split exists to refuse. MN9 is its mutant; this
# arm is the byte-level statement beside it.
n="$(grep -c '^CITATION_NEGATED = re\.compile(' "$AUDIT")" || n=0
[ "$n" -eq 1 ] \
  && ok "\`CITATION_NEGATED\` is its own \`re.compile(\` — the citation vocabulary is a separate set, not an alias of the cue one" \
  || bad "\`CITATION_NEGATED = re.compile(\` occurred $n times, expected 1 — the citation vocabulary is aliased, aliased away, or declared twice"

# 33 — STRUCTURAL: `NEGATED` is BYTE-IDENTICAL to the literal this change left it at. The
# behavioural twin of 31, keyed on the line rather than on a row, so a widening is caught even
# on a register that happens to seed no cue-only row.
n="$(grep -cxF 'NEGATED = re.compile(r"\bno\b|\brather than\b|\binstead of\b", re.I)' "$AUDIT")" || n=0
[ "$n" -eq 1 ] \
  && ok "the \`NEGATED\` line is byte-identical to the cue vocabulary this change did not touch" \
  || bad "the \`NEGATED\` line moved ($n exact matches, expected 1) — the cue vocabulary changed under a citation fix"

# --- MUTANTS MN1-MN10 -----------------------------------------------------------------------
# ONE CELL PER MUTANT, AND THE CELLS WERE DERIVED BY BUILDING ALL TEN AND READING THE MATRIX
# rather than reasoned about. Reported cells on `CIT_NEG_REG`, subject then mutants, `x` marks
# the cell each arm below is keyed on:
#
#             n0   n1   n2   n3   n4   n5   n6   n7   n8   n9   n10
#   subject   acq  REP  REP  acq  REP  REP  REP  acq  REP  acq  REP
#   MN1       acq  acq  acq  acq  acqx acq  acq  acq  REP  acq  acq
#   MN2       acq  REP  acqx acq  REP  REP  REP  acq  REP  acq  REP
#   MN3       acq  REP  REP  REPx REP  REP  REP  REP  REP  acq  REP
#   MN4       acq  acq  acq  acq  REP  REP  REP  acq  REP  acq  acqx
#   MN5       acq  REP  REP  acq  acqx REP  REP  acq  REP  acq  REP
#   MN6       acq  REP  REP  acq  REP  acqx REP  acq  REP  acq  REP
#   MN7       acq  REP  REP  acq  REP  REP  acqx acq  REP  acq  REP
#   MN8       acq  REP  REP  acq  REP  REP  REP  REP  acq  acq  REP   (scored elsewhere)
#   MN9       acq  acq  acq  acq  REP  REP  REP  acq  REP  acq  acq
#   MN10      acq  acq  REP  acq  REP  REP  REP  acq  acqx acq  REP
#   M_CIT3    REP  REP  REP  REP  REP  REP  REP  REPx REP  REPx REP
#
# MN3 MOVES n7 AS WELL AS n3, AND BOTH MOVEMENTS ARE TRUE OF THE SAME PROPERTY. Dropping the
# bound makes the sentence-initial `Not` in n7 reach the SECOND mention too, so the row loses
# its clean mention. Assertion 29 OWNS the bound and is keyed on n3; n7's arm is MN8's and is
# scored on MN8's own register, where MN8 is the only mutant it reads. Neither arm is vacuous
# and neither is keyed on a cell the other reads.
#
# MN1 AND MN4 SHARE n1, WHICH IS WHY NEITHER IS SCORED ON IT. MN1 (revert to a whole-reason
# search) acquits six rows; MN4 (drop `not`) acquits three, all six of MN1's being a superset.
# The separating cells are n4 — MN1 acquits it, MN4 does not — and n10, which MN4 acquits and
# MN1 also does. So MN1 OWNS n4 and MN4 owns n10, and each arm below reads its own cell plus a
# conjunct naming a cell the OTHER mutant moves, so neither can pass by moving everything.
#
# MN4 AND MN9 ARE BEHAVIOURALLY IDENTICAL ON THIS REGISTER — measured, the same three cells —
# because `NEGATED` is `CITATION_NEGATED` minus `not` and the alias reproduces it exactly. That
# is not a redundant mutant: MN9 is the one assertion 32 exists for, and the two are separated
# STRUCTURALLY rather than behaviourally. Scored together, with 32 as the arm that tells them
# apart, because inventing a behavioural difference between them would be inventing a seed the
# subject cannot distinguish either.

# 34 — MN1, THE REVERT: the per-occurrence rule dropped for a whole-reason search, which is the
# state before this change. Its cell is n4.
MN1="$(mkmut mn1 '    if CITED is not None and any(not citation_denied(reason, m)
                                 for m in CITED.finditer(reason)):
        continue' '    if CITED is not None and CITED.search(reason):
        continue')"
if [ -z "$MN1" ]; then
  bad "FIXTURE ERROR: the whole-reason revert MN1 DID NOT APPLY — the citation-negation arms prove nothing"
else
  mn1_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$MN1" --register "$CIT_NEG_REG" 2>&1)")"
  if grep -q 'n4\.md' <<<"$mn1_und"; then
    bad "MUTATION MN1: a whole-reason citation search still reported the \`no\`-denied row — the arms above cannot tell a per-occurrence rule from a search"
  elif grep -q 'n8\.md' <<<"$mn1_und"; then
    ok "MUTATION MN1: reverted to a whole-reason search every denied citation is acquitted (so the section is live), while the cue-only row survives"
  else
    bad "MUTATION MN1: the cue-only row vanished too — MN1 reaches \`NEGATED\`'s subject and the two vocabularies are entangled"
  fi
fi

# 35 — MN2, the bound widened to the COMMA, i.e. `CLAUSE_END`'s set. Its cell is n2, whose
# negator and mention straddle a comma; nothing else here separates the two bounds.
MN2="$(mkmut mn2 'SENTENCE_END = re.compile(r"[.;:]")' 'SENTENCE_END = re.compile(r"[.;:,]")')"
if [ -z "$MN2" ]; then
  bad "FIXTURE ERROR: the comma-bound mutation MN2 DID NOT APPLY — assertion 26 proves nothing about the bound"
else
  mn2_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$MN2" --register "$CIT_NEG_REG" 2>&1)")"
  if grep -q 'n2\.md' <<<"$mn2_und"; then
    bad "MUTATION MN2: a comma-bounded search still reported the comma-spliced denial — the bound is not what makes that row work"
  elif grep -q 'n1\.md' <<<"$mn2_und"; then
    ok "MUTATION MN2: bounded at the comma the comma-spliced denial is acquitted (so the sentence bound is live), while the single-clause denial survives"
  else
    bad "MUTATION MN2: the single-clause denial vanished too — MN2 moves two cells and the bound arm is entangled with assertion 27"
  fi
fi

# 36 — MN3, the bound DROPPED entirely, so the search runs from the start of the reason. Its
# cell is n3, whose negator sits in the previous sentence.
MN3="$(mkmut mn3 '    for b in SENTENCE_END.finditer(reason, 0, m.start()):
        start = b.end()
' '')"
if [ -z "$MN3" ]; then
  bad "FIXTURE ERROR: the no-bound mutation MN3 DID NOT APPLY — assertion 29 proves nothing"
else
  mn3_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$MN3" --register "$CIT_NEG_REG" 2>&1)")"
  if grep -q 'n3\.md' <<<"$mn3_und"; then
    grep -q 'n9\.md' <<<"$mn3_und" \
      && bad "MUTATION MN3: the after-the-mention row moved too — MN3 reaches assertion 30's cell and the two bound arms are entangled" \
      || ok "MUTATION MN3: with the bound dropped a negator in the PREVIOUS sentence denies the mention (so assertion 29 is live), while a negator after the mention still does not"
  else
    bad "MUTATION MN3: the previous-sentence row stayed acquitted with the bound removed — assertion 29 passes whatever the search window is"
  fi
fi

# 37 — MN4, the vocabulary WITHOUT `not`, i.e. `NEGATED`'s member set spelled into the citation
# regex. Its cell is n10; n1 is MN1's too and is read here only as a conjunct.
MN4="$(mkmut mn4 'CITATION_NEGATED = re.compile(r"\bno\b|\bnot\b|\brather than\b|\binstead of\b", re.I)' 'CITATION_NEGATED = re.compile(r"\bno\b|\brather than\b|\binstead of\b", re.I)')"
if [ -z "$MN4" ]; then
  bad "FIXTURE ERROR: the drop-\`not\` mutation MN4 DID NOT APPLY — assertion 27 proves nothing about \`not\`"
else
  mn4_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$MN4" --register "$CIT_NEG_REG" 2>&1)")"
  if grep -q 'n10\.md' <<<"$mn4_und"; then
    bad "MUTATION MN4: without \`not\` the sentence-initial denial was still reported — no arm here turns on \`not\` being in the citation vocabulary"
  elif grep -q 'n4\.md' <<<"$mn4_und"; then
    ok "MUTATION MN4: dropping \`not\` acquits the sentence-initial denial (so \`not\` is load-bearing), while the \`no\` form survives"
  else
    bad "MUTATION MN4: the \`no\` form vanished too — MN4 removed more than \`not\` and its cell is shared with MN5"
  fi
fi

# 38-40 — MN5/MN6/MN7, one member of the vocabulary dropped each. Every member gets a seed that
# isolates it and a mutant that drops it, so no member is in the set without a subject.
#
# THE REPLACEMENT REGEX IS SPELLED WITH ONE BACKSLASH AND THAT IS THE WHOLE TRAP. Written
# `\\bno\\b` — the habit from an `awk -v` or a double-quoted context — python's raw string
# takes it as a literal backslash, `CITATION_NEGATED` then matches NOTHING, every citation is
# un-denied and the mutant acquits all seven reported rows at once. It applies cleanly, `cmp -s`
# sees a real edit, and the kill is scored for a reason that has nothing to do with the dropped
# member. Caught here by the survivor conjunct going red, which is what that conjunct is for.
mn_member() { # mn_member <label> <regex-without-the-member> <own-cell> <survivor-cell> <member>
  local m; m="$(mkmut "$1" 'CITATION_NEGATED = re.compile(r"\bno\b|\bnot\b|\brather than\b|\binstead of\b", re.I)' "CITATION_NEGATED = re.compile(r\"$2\", re.I)")"
  if [ -z "$m" ]; then
    bad "FIXTURE ERROR: the drop-\`$5\` mutation DID NOT APPLY — no arm proves \`$5\` is load-bearing"
    return
  fi
  local u; u="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$m" --register "$CIT_NEG_REG" 2>&1)")"
  if grep -q "$3\.md" <<<"$u"; then
    bad "MUTATION $1: dropping \`$5\` still reported $3 — that seed does not isolate \`$5\` and the member has no subject"
  elif grep -q "$4\.md" <<<"$u"; then
    ok "MUTATION $1: dropping \`$5\` from the citation vocabulary acquits $3 (so \`$5\` is load-bearing), while $4 survives"
  else
    bad "MUTATION $1: $4 vanished too — dropping \`$5\` moved a cell another member owns"
  fi
}
mn_member MN5 '\bnot\b|\brather than\b|\binstead of\b' n4 n5 'no'
mn_member MN6 '\bno\b|\bnot\b|\binstead of\b'          n5 n4 'rather than'
mn_member MN7 '\bno\b|\bnot\b|\brather than\b'         n6 n4 'instead of'

# 41 — MN8, `any` -> `all`, ON ITS OWN SINGLE-CANDIDATE REGISTER. `all()` over an EMPTY
# generator is True, so on the shared register this mutant acquits every row that mentions no
# declared id and silences the arm wholesale — a kill scored for a reason that has nothing to
# do with the per-occurrence rule. This register holds n7 (one denied mention, one clean one),
# a genuine obligation that cites nothing (n11, the row `all` wrongly acquits, which is what
# makes the second conjunct a statement rather than a formality), and the declaring row.
MN8_REG="$WORK/register-citneg-any.jsonl"
: >"$MN8_REG"
python3 - >>"$MN8_REG" <<'PY'
import json
base = {"clause":"LC-E4","subject_digest":"0"*40,"verdict":"still-additive",
        "recorded_utc":"2026-01-01T00:00:00Z"}
def r(entry, reason, owed=None):
    d = dict(base, entry=entry, reason=reason)
    if owed: d["owed"] = owed
    print(json.dumps(d))
# n7 — the SUBJECT: the second mention carries no negator in its sentence, so one clean mention
# is a handle and the row is acquitted. Under `all` the denied first mention is enough to report it.
r("extensions/n7.md", "Not under OWED-CIT-X; the narrowing is owed under OWED-CIT-X.")
# n11 — the row `all` silences: a genuine obligation citing NOTHING, so its generator is empty
# and `all()` is vacuously True. Reported by the subject and by every mutant except MN8.
r("extensions/n11.md", "A narrowing is still owed here.")
r("extensions/nd.md", "declaring the migration", {"id":"OWED-CIT-X","what":"split X out"})
PY
any_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$AUDIT" --register "$MN8_REG" 2>&1)")"
any_got="$(cn_names "$any_und")"
[ "$any_got" = "n11.md " ] \
  && ok "one clean mention beside a denied one is a handle — the rule is per OCCURRENCE, and the row citing nothing is still reported" \
  || { bad "the per-occurrence register reported '$any_got', expected 'n11.md '"; sed 's/^/        /' <<<"$any_und"; }

MN8="$(mkmut mn8 'any(not citation_denied(reason, m)' 'all(not citation_denied(reason, m)')"
if [ -z "$MN8" ]; then
  bad "FIXTURE ERROR: the \`all\` mutation MN8 DID NOT APPLY — the per-occurrence rule proves nothing"
else
  mn8_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$MN8" --register "$MN8_REG" 2>&1)")"
  if ! grep -q 'n7\.md' <<<"$mn8_und"; then
    bad "MUTATION MN8: under \`all\` the row with one clean mention stayed acquitted — no arm distinguishes \`any\` from \`all\`"
  elif grep -q 'n11\.md' <<<"$mn8_und"; then
    bad "MUTATION MN8: the row citing nothing was reported too — \`all\` did not vacuously acquit it and this register cannot show the cost"
  else
    ok "MUTATION MN8: under \`all\` one denied mention condemns the row AND the citation-free row is vacuously acquitted — both halves of why the rule is \`any\`"
  fi
fi

# 42 — MN9, the ALIAS: `CITATION_NEGATED = NEGATED`, with `NEGATED` itself untouched. It is the
# collapse assertion 32 is keyed on, and it passes every arm whose seed does not turn on `not`.
MN9="$(mkmut mn9 'CITATION_NEGATED = re.compile(r"\bno\b|\bnot\b|\brather than\b|\binstead of\b", re.I)' 'CITATION_NEGATED = NEGATED')"
if [ -z "$MN9" ]; then
  bad "FIXTURE ERROR: the alias mutation MN9 DID NOT APPLY — assertion 32 proves nothing"
else
  n="$(grep -c '^CITATION_NEGATED = re\.compile(' "$MN9")" || n=0
  mn9_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$MN9" --register "$CIT_NEG_REG" 2>&1)")"
  if [ "$n" -ne 0 ]; then
    bad "MUTATION MN9: the alias left a \`CITATION_NEGATED = re.compile(\` behind — assertion 32 cannot see an aliased vocabulary"
  elif grep -q 'n1\.md' <<<"$mn9_und"; then
    bad "MUTATION MN9: aliased to \`NEGATED\` the filed subject was still reported — the separate vocabulary is not what reports it"
  else
    ok "MUTATION MN9: aliased to \`NEGATED\` the vocabulary loses \`not\` and the filed subject is acquitted, and assertion 32's grep goes to 0 — so the separation is asserted structurally as well as behaviourally"
  fi
fi

# 43 — MN10, the move MN9 inverts: `NEGATED` WIDENED with `not` instead of a second vocabulary.
# Its cell is n8, the cue-only row — the leak into the cue filter, which no other mutant here
# reaches and which assertion 33 asserts at the byte level.
MN10="$(mkmut mn10 'NEGATED = re.compile(r"\bno\b|\brather than\b|\binstead of\b", re.I)' 'NEGATED = re.compile(r"\bno\b|\bnot\b|\brather than\b|\binstead of\b", re.I)')"
if [ -z "$MN10" ]; then
  bad "FIXTURE ERROR: the \`NEGATED\`-widening mutation MN10 DID NOT APPLY — assertion 31 proves nothing"
else
  mn10_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$MN10" --register "$CIT_NEG_REG" 2>&1)")"
  if grep -q 'n8\.md' <<<"$mn10_und"; then
    bad "MUTATION MN10: widening \`NEGATED\` with \`not\` still reported the cue-only row — assertion 31 cannot see \`not\` leaking into the cue filter"
  elif grep -q 'n2\.md' <<<"$mn10_und"; then
    ok "MUTATION MN10: \`not\` admitted to \`NEGATED\` silences a cue the citation vocabulary must not reach (so assertion 31 is live), while the citation arms are unmoved"
  else
    bad "MUTATION MN10: the comma-spliced citation moved too — MN10 reaches the citation side and the two vocabularies are not independent here"
  fi
fi

# 44 — M_CIT3 ON THE NEW REGISTER. The re-anchored disable mutant's third scoring: with the
# citation key gone EVERY row of this register is reported, including the two the fix acquits
# for reasons no other mutant here touches. That is the signature of a reader consulting no
# citation at all, and it is what makes the acquittals above statements about this key.
if [ -z "$M_CIT3" ]; then
  bad "FIXTURE ERROR: the disable mutation DID NOT APPLY — the citation-negation acquittals prove nothing"
else
  m3n_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$M_CIT3" --register "$CIT_NEG_REG" 2>&1)")"
  m3n_got="$(cn_names "$m3n_und")"
  [ "$m3n_got" = "n0.md n1.md n10.md n2.md n3.md n4.md n5.md n6.md n7.md n8.md n9.md " ] \
    && ok "MUTATION M_CIT3 on the citation-negation register: with the key disabled every row is reported, including the four the fix acquits — so each acquittal above is this key's doing" \
    || { bad "MUTATION M_CIT3 reported '$m3n_got' on the citation-negation register — the disabled key did not report every row, so some acquittal above is somebody else's"; sed 's/^/        /' <<<"$m3n_und"; }
fi

# 45 — UNMUTATED CONTROL FOR THIS SECTION, necessary and not sufficient, so it carries a
# POSITIVE conjunct: a copy taken and invoked exactly as MN1-MN10 are must still report the
# denied citation AND leave the live shape acquitted. A subject replaced by `exit 0` reports
# nothing and fails the first half.
CN_CTL="$WORK/control-citneg.sh"
cp "$AUDIT" "$CN_CTL"
cnc_out="$(bash "$CN_CTL" --register "$CIT_NEG_REG" 2>&1)"; cnc_rc=$?
if [ "$cnc_rc" -eq 0 ] && [ "$(cn_names "$(awk '/^UNDECLARED/,/^$/' <<<"$cnc_out")")" = "$CN_EXPECT" ]; then
  ok "CONTROL: an UNMUTATED copy, taken and invoked exactly as MN1-MN10 are, reproduces the exact baseline set — so the kills above are the mutations and not the harness"
else
  bad "CONTROL: an unmutated copy did not reproduce the citation-negation baseline (rc=$cnc_rc) — every kill in this section may be the harness failing to run the subject"
  sed 's/^/        /' <<<"$cnc_out"
fi

# 25 — UNMUTATED CONTROL, necessary and not sufficient, so it carries a POSITIVE conjunct: a
# copy taken and invoked exactly as the four mutants are must still NAME the baseline rows. A
# subject replaced by `exit 0` fails this, which is what stops silence above scoring as a kill.
CIT_CTL="$WORK/control-cit.sh"
cp "$AUDIT" "$CIT_CTL"
ctl_out="$(bash "$CIT_CTL" --register "$CIT_REG" 2>&1)"; ctl_rc=$?
if [ "$ctl_rc" -eq 0 ] && grep -q 'c4\.md' <<<"$ctl_out" && grep -q 'OWED-CIT-X' <<<"$ctl_out"; then
  ok "CONTROL: an UNMUTATED copy, taken and invoked exactly as M1/M2/M3/M4 are, still names the baseline rows — so the kills above are the mutations and not the harness"
else
  bad "CONTROL: an unmutated copy did not reproduce the baseline (rc=$ctl_rc) — every kill above may be the harness failing to run the subject"
  sed 's/^/        /' <<<"$ctl_out"
fi

echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "layer-debt-ledger: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. One did not execute at all, which is not the same as one that passed."
  exit 1
fi
if [ "$fails" -eq 0 ]; then echo "layer-debt-ledger: PASS ($made assertions)"; exit 0; fi
echo "layer-debt-ledger: FAIL ($fails of $made)"; exit 1
