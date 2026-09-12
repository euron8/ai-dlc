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

EXPECTED_ASSERTIONS=29
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
M_CIT3="$(mkmut cit3 '    if CITED is not None and CITED.search(reason):
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
