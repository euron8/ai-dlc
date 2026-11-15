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
printf 'HERMETIC-CONSUMED %s\n' "$(cd "$(dirname "$AUDIT")" && pwd)/$(basename "$AUDIT")"

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
REG="$WORK/register.jsonl"

EXPECTED_ASSERTIONS=30
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

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
  || { ok "CONTROL: a register whose closes_owed are all arrays reports no mistyped rows"; }

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

# CONTROL: an entry whose debt is declared on a
# LATER row must NOT be reported. Absence-shaped, so it passes against an arm that reports
# nothing at all.
cc_block="$(awk '/^CONTRADICTS-CORE/,0' <<<"$cc_out")"
grep -q 'y\.md' <<<"$cc_block" \
  && bad "CONTROL: an entry whose \`owed\` sits on a later row was reported — the arm is row-scoped, and an append-only register can never satisfy it" \
  || { ok "CONTROL: a contradicts-core entry whose debt is declared by a LATER row is not reported"; }

# --- 15-24. a row that CITES a resolvable `OWED-` id is a REFERENCE, not a declaration --------
# THE DEFECT. The UNDECLARED arm's remedy is "re-record each with an `owed` object". A row whose
# reason cites an id some OTHER row declares was filed in the same bucket as a genuine offender,
# so obeying the remedy files a SECOND id for work already tracked — a wrong WRITE prompted by a
# false finding, not a glance. Measured on the reference consumer's 471-row register: 1 of the 7
# reported rows, `checks/gate-validation-push-914.md`, citing `OWED-S330-914-RETRO-SCOPE`.
#
# THE JOIN IS AGAINST THE DECLARED SET, NEVER A TOKEN GRAMMAR, and that is what `c3` below
# asserts: a row inventing an id nothing declares has no handle either and stays reported.
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
# c3 UNRESOLVABLE — a citation of nothing is not a handle. Must STAY reported.
r("extensions/c3.md", "The narrowing is owed under OWED-CIT-NOPE.")
# c4 GENUINE — no citation at all. Must stay reported.
r("extensions/c4.md", "A narrowing is still owed here.")
# c5 INSIDE-TOKEN CONTROL — the state the filed remedy targeted, unconstructible either way.
# Reported by neither the old arm nor the new one, which is what makes it a control on the
# claim that this fix changes nothing there.
r("extensions/c5.md", "Tracked on the row that carries OWED-DEBT-DEFERRED.")
# c6 THE COST, SEEDED RATHER THAN ASSUMED — one obligation cited, a SECOND stated in prose.
# Row scope silences it; clause scope would not. Named here so the trade is visible in the arm.
r("extensions/c6.md", "Filed under OWED-CIT-X. A second narrowing is still owed.")
# c7 NEAR-MISS on the denial discount — a cue already denied by `no`, beside a resolvable token.
# It must stay unreported, and for the OLD reason.
r("extensions/c7.md", "No owed beyond OWED-CIT-X.")
# c8 — closes_owed DISCHARGE naming an id NO row declares, so `closed` and `declared` are
# DIFFERENT SETS on this register.
print(json.dumps(dict(base, entry="extensions/c8.md", reason="Debt discharged.",
                      closes_owed=["OWED-CIT-OTHER"])))
# c9 — a standalone cue beside a citation of `OWED-CIT-OTHER`, an id that is CLOSED and never
# DECLARED — so it was never on the record as an obligation at all, and a citation of it is a
# citation of nothing. The fix REPORTS it; a join taken against `closes_owed` would acquit it.
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

# 15 — the SUBJECT is acquitted. Absence-shaped, so arms 16 and 17 give it presence-shaped twins.
grep -q 'c1\.md' <<<"$cit_und" \
  && { bad "a row CITING a resolvable \`OWED-\` id is still filed as undeclared — obeying the printed remedy declares a duplicate obligation for work another row already tracks"; sed 's/^/        /' <<<"$cit_out"; } \
  || { ok "a row citing a resolvable \`OWED-\` id is not filed as an undeclared obligation"; }

# 16 — PRESENCE: a citation of an id NOTHING declares is not a handle and stays reported. This
# is the arm that separates the join from a token grammar.
grep -q 'c3\.md' <<<"$cit_und" \
  && { ok "a citation of an id no row declares is still reported — the acquittal joins the DECLARED set, not an \`OWED-\` spelling"; } \
  || { bad "a row citing an UNRESOLVABLE id was acquitted — the key is a token grammar and a row can silence itself by inventing an id"; sed 's/^/        /' <<<"$cit_out"; }

# 17 — PRESENCE: a genuine undeclared obligation with no citation is untouched. This is
# the arm that makes every absence above mean something against a reader emitting nothing.
grep -q 'c4\.md' <<<"$cit_und" \
  && ok "a genuine undeclared obligation carrying no citation is still reported" \
  || { bad "the genuine obligation vanished — the acquittal reaches rows that cite nothing"; sed 's/^/        /' <<<"$cit_out"; }

# 18 — the VERDICT, asserted as the exact reported set rather than as a count. A count is
# reachable by the wrong rows; the names are not.
cit_names="$(grep -oE 'c[0-9]+\.md' <<<"$cit_und" | sort -u | tr '\n' ' ')"
[ "$cit_names" = "c3.md c4.md c9.md " ] \
  && { ok "the reported set is exactly {c3,c4,c9} — the rows with no resolvable handle"; } \
  || { bad "the reported set was '$cit_names', expected 'c3.md c4.md c9.md '"; sed 's/^/        /' <<<"$cit_out"; }

# 18b — THE DISCHARGED CITATION IS ACQUITTED. This is the shape the live register actually
# holds; a key of `declared - closed` acquits NOTHING there, because every declared id is paid.
grep -q 'c10\.md' <<<"$cit_und" \
  && { bad "a row citing a DISCHARGED obligation was filed as undeclared — obeying the remedy re-opens finished work under a new id"; sed 's/^/        /' <<<"$cit_out"; } \
  || { ok "a row citing an obligation that was declared and later DISCHARGED is acquitted — the handle is the declaring row, not this run's OPEN list"; }

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
# measurement recorded beside that regex. n8 is the row that holds the two apart.
#
# WHAT EACH SEED ISOLATES:
#   n0  live shape, ACQUITTED — an un-negated mention. The fix must not touch it.
#   n1  the filed subject, REPORTED — `not` before the mention in its own sentence.
#   n2  REPORTED — negator and mention straddle a COMMA; a comma-bounded
#       search starts after the `not` and finds nothing, which is why this bound is `.;:`.
#   n3  ACQUITTED — the negator sits in the PREVIOUS sentence and must not reach the mention.
#       Carries a `PROSE` cue of its own, so it is a row the arm would otherwise report: a
#       seed with no cue is acquitted by the cue filter and proves nothing about the bound.
#   n4  REPORTED — isolates `no`.
#   n5  REPORTED — isolates `rather than`.
#   n6  REPORTED — isolates `instead of`.
#   n7  ACQUITTED — one denied mention AND one clean mention. The per-OCCURRENCE `any` rule.
#       Asserted on its OWN register below, never here.
#   n8  CUE-SIDE CONTROL, REPORTED — `not` denying a cue with no citation anywhere.
#   n9  ACQUITTED — a `no` AFTER the mention. The search runs only BEFORE, so a negator
#       downstream of the id cannot deny it.
#   n10 REPORTED — the sentence-initial `not` form, with no trailing `and ... still owed`
#       clause.
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
# n12/n13 — THE NEGATOR INSIDE A QUOTE OR A PARENTHESIS. Both REPORTED. Measured by the tip
# adversary: an implementation that blanks quoted spans, or parenthesised spans, before searching
# for a negator passed all fifty assertions above and the entry's receipt, because every seed above
# carries its negator in bare prose. A quoted `not` is still a denial, and the live register's
# sixth sentence-denied mention is exactly a `not` inside a quoted fragment.
r("extensions/n12.md", "This is 'not' tracked under OWED-CIT-X and a narrowing is still owed.")
r("extensions/n13.md", "Filed elsewhere (not under OWED-CIT-X) and a narrowing is still owed.")
# THE DECLARING ROW. Without it `declared` is empty, `CITED` is None, and every arm above
# passes for a reason that has nothing to do with the citation key.
r("extensions/nd.md", "declaring the migration", {"id":"OWED-CIT-X","what":"split X out"})
PY
cn_out="$(bash "$AUDIT" --register "$CIT_NEG_REG" 2>&1)"
cn_und="$(awk '/^UNDECLARED/,/^$/' <<<"$cn_out")"
cn_names() { grep -oE 'n[0-9]+\.md' <<<"$1" | sort -u | tr '\n' ' '; }
CN_EXPECT='n1.md n10.md n12.md n13.md n2.md n4.md n5.md n6.md n8.md '

# 26 — THE VERDICT, as the EXACT reported set. A membership assertion is reachable by the wrong
# rows; this names every cell of the register in one string, so any change that moves any row
# either way is caught here whether or not its own arm below fires.
cn_got="$(cn_names "$cn_und")"
[ "$cn_got" = "$CN_EXPECT" ] \
  && { ok "the citation-negation reported set is exactly {n1,n2,n4,n5,n6,n8,n10,n12,n13} — every denied mention reported, every un-denied one acquitted"; } \
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
  || { ok "CONTROL: a negator in the previous sentence does not deny the mention — the search is bounded to the mention's own sentence"; }

# 30 — and from the other side: a negator AFTER the mention does not reach it either. The bound
# is directional, and 29 alone passes against a search that reads the whole reason backwards.
grep -q 'n9\.md' <<<"$cn_und" \
  && { bad "CONTROL: a `no` occurring AFTER the mention denied it — the search does not stop at the mention"; sed 's/^/        /' <<<"$cn_out"; } \
  || ok "CONTROL: a negator occurring after the mention does not deny it — the search runs only on the text before"

# 31 — THE CUE SIDE DID NOT MOVE. `not` denies a MENTION and must not deny a CUE; this row has
# no citation at all, so only a widened `NEGATED` can acquit it.
grep -q 'n8\.md' <<<"$cn_und" \
  && { ok "CONTROL: a \`not\`-denied CUE with no citation is still reported — \`not\` did not leak into \`NEGATED\`"; } \
  || { bad "CONTROL: the cue-side row was acquitted — \`not\` reached the cue filter, and the two vocabularies have collapsed into one"; sed 's/^/        /' <<<"$cn_out"; }

# 32 — STRUCTURAL: the citation vocabulary is its OWN compiled pattern. An alias
# (`CITATION_NEGATED = NEGATED`) satisfies every behavioural arm above whose seed does not turn
# on `not`, and reintroduces the coupling the split exists to refuse. This arm is the
# byte-level statement.
n="$(grep -c '^CITATION_NEGATED = re\.compile(' "$AUDIT")" || n=0
[ "$n" -eq 1 ] \
  && { ok "\`CITATION_NEGATED\` is its own \`re.compile(\` — the citation vocabulary is a separate set, not an alias of the cue one"; } \
  || bad "\`CITATION_NEGATED = re.compile(\` occurred $n times, expected 1 — the citation vocabulary is aliased, aliased away, or declared twice"

# 33 — STRUCTURAL: `NEGATED` is BYTE-IDENTICAL to the literal this change left it at. The
# behavioural twin of 31, keyed on the line rather than on a row, so a widening is caught even
# on a register that happens to seed no cue-only row.
n="$(grep -cxF 'NEGATED = re.compile(r"\bno\b|\brather than\b|\binstead of\b", re.I)' "$AUDIT")" || n=0
[ "$n" -eq 1 ] \
  && ok "the \`NEGATED\` line is byte-identical to the cue vocabulary this change did not touch" \
  || bad "the \`NEGATED\` line moved ($n exact matches, expected 1) — the cue vocabulary changed under a citation fix"

# 41 — the per-OCCURRENCE rule, ON ITS OWN SINGLE-CANDIDATE REGISTER. This register holds n7
# (one denied mention, one clean one), a genuine obligation that cites nothing (n11), and the
# declaring row.
ANY_REG="$WORK/register-citneg-any.jsonl"
: >"$ANY_REG"
python3 - >>"$ANY_REG" <<'PY'
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
# n11 — a genuine obligation citing NOTHING. Reported by the subject.
r("extensions/n11.md", "A narrowing is still owed here.")
r("extensions/nd.md", "declaring the migration", {"id":"OWED-CIT-X","what":"split X out"})
PY
any_und="$(awk '/^UNDECLARED/,/^$/' <<<"$(bash "$AUDIT" --register "$ANY_REG" 2>&1)")"
any_got="$(cn_names "$any_und")"
[ "$any_got" = "n11.md " ] \
  && { ok "one clean mention beside a denied one is a handle — the rule is per OCCURRENCE, and the row citing nothing is still reported"; } \
  || { bad "the per-occurrence register reported '$any_got', expected 'n11.md '"; sed 's/^/        /' <<<"$any_und"; }

# 45 — CONTROL FOR THIS SECTION, necessary and not sufficient, so it carries a POSITIVE
# conjunct: the subject must exit 0 and report the exact baseline set. A subject replaced by
# `exit 0` reports nothing and fails the set comparison.
cnc_out="$(bash "$AUDIT" --register "$CIT_NEG_REG" 2>&1)"; cnc_rc=$?
if [ "$cnc_rc" -eq 0 ] && [ "$(cn_names "$(awk '/^UNDECLARED/,/^$/' <<<"$cnc_out")")" = "$CN_EXPECT" ]; then
  ok "CONTROL: the subject exits 0 and reproduces the exact citation-negation baseline set"
else
  bad "CONTROL: the subject did not reproduce the citation-negation baseline (rc=$cnc_rc)"
  sed 's/^/        /' <<<"$cnc_out"
fi

# 25 — CONTROL, necessary and not sufficient, so it carries a POSITIVE conjunct: the subject must
# still NAME the baseline rows. A subject replaced by `exit 0` fails this.
ctl_out="$(bash "$AUDIT" --register "$CIT_REG" 2>&1)"; ctl_rc=$?
if [ "$ctl_rc" -eq 0 ] && grep -q 'c4\.md' <<<"$ctl_out" && grep -q 'OWED-CIT-X' <<<"$ctl_out"; then
  ok "CONTROL: the subject exits 0 on the citation register and still names the baseline rows"
else
  bad "CONTROL: the subject did not reproduce the citation baseline (rc=$ctl_rc)"
  sed 's/^/        /' <<<"$ctl_out"
fi

echo ""
report_end layer-debt-ledger "$EXPECTED_ASSERTIONS"
