#!/usr/bin/env bash
# layer-debt-due-and-discharge — a row that DISCHARGES a layer debt must not be filed as an
# undeclared one.
#
# THE DEFECT THIS EXISTS TO CATCH, and it is silent: `audit-layer-debt.sh` is a reporter, so
# nothing here moves an exit code and no assertion but one on the OUTPUT can see it.
#
# The migration arm reports rows whose `reason` PROSE reads like owed work while the row
# declares no `owed` object. It used to skip a row only when `owed` was a dict, and never
# consulted `closes_owed`. A discharge row carries `closes_owed` and — by the convention every
# discharge row on the reference register follows — opens its reason `Debt discharged.`, which
# trips the `debt` cue. So THE CORRECT WAY TO CLOSE A DEBT WAS ALSO THE PHRASING THAT FILED IT
# AS AN UNDECLARED ONE, and the metric moved the wrong way in response to the action it exists
# to encourage: the reference consumer discharged six debts and watched the count rise by
# exactly six, which is how it was found.
#
# WHY THE NEAR-MISS SITS BESIDE THE OFFENDER IN THE SAME RUN. A near-miss in a SEPARATE run can
# only ask whether an arm fires at all; it can never ask whether it fires on the RIGHT rows. So
# the discriminating pair here is two rows of ONE register read by ONE invocation, carrying
# BYTE-IDENTICAL reason prose and differing in exactly one field.
#
# THERE IS DELIBERATELY NO ARM ON `owed.closes_when`. The obvious one — assert the report
# derives something from a debt whose stated trigger names a command — was built and scored
# against the live register: the `\S+\.sh` token partition emits 3 rows and ALL 3 ARE FALSE, two
# reading a condition about a script's output and one reading a script named as a NOUN. An arm
# here would demand a behaviour that should not ship. See BL-067.
#
# Usage: run.sh [audit-layer-debt.sh]
# Exit:  0 = every assertion holds, 1 = the reader regressed, 2 = fixture broken.
set -uo pipefail

# HERMETIC — a consumer that pins AI_DLC_* in settings.json exports it into every session, and
# `git push` inherits it. Scrub by pattern so a NEW tunable cannot reintroduce the coupling.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
AUDIT="$(pick "${1:-}" \
  "$HERE/../../scripts/audit-layer-debt.sh" \
  "$HERE/../../../core/scripts/audit-layer-debt.sh" \
  "$HERE/../../../scripts/ai-dlc/audit-layer-debt.sh")"
# THE SUBJECT MAY LEGITIMATELY BE ABSENT ON A CONSUMER — a core fixture ships ahead of the code
# it guards. That is exit 2 FIXTURE BROKEN, never a green run: "I could not find the subject"
# and "the subject behaves" are different claims and must not share an exit code.
[ -n "$AUDIT" ] || { echo "FIXTURE ERROR: cannot locate audit-layer-debt.sh" >&2; exit 2; }
case "$AUDIT" in /*) : ;; *) AUDIT="$(cd "$(dirname "$AUDIT")" && pwd)/$(basename "$AUDIT")" ;; esac

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 absent" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

EXPECTED_ASSERTIONS=27
fails=0; made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }
show() { sed 's/^/        /' <<<"$1"; }

run() { bash "$AUDIT" --register "$1" 2>&1; }

# --- the seeds are written by a producer, never from the reader's accept-set ------------------
# A seed derived from what the reader accepts proves the reader accepts its own grammar. These
# rows are the shapes the ADJUDICATOR emits, including the two malformed ones it has emitted in
# the wild: a bare-string `closes_owed` and an empty-array one.
cat >"$WORK/mkreg.py" <<'PY'
import json, sys
# mkreg.py <out>  — one JSON object per stdin line, merged onto a common base
out = sys.argv[1]
base = {"clause": "LC-E4", "subject_digest": "0" * 40, "verdict": "still-additive",
        "recorded_utc": "2026-08-06T00:00:00Z"}
with open(out, "w", encoding="utf-8") as fh:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        fh.write(json.dumps(dict(base, **json.loads(line))) + "\n")
PY

# Build a mutant as a COPY and refuse a mutation that matched nothing — a replacement that hit
# no line produces a mutant identical to the subject, and an arm that then goes green scores a
# kill it never earned.
mkmut() { # mkmut <label> <find> <replace> -> prints path, or nothing on a no-op
  local m="$WORK/mut-$1.sh"
  cp "$AUDIT" "$m" || return 0
  python3 - "$m" "$2" "$3" <<'PY' || return 0
import io, sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding="utf-8").read()
n = s.replace(a, b)
if n == s:
    raise SystemExit(3)
io.open(p, "w", encoding="utf-8").write(n)
PY
  cmp -s "$AUDIT" "$m" || printf '%s' "$m"
}

# The two anchors every mutant below keys on, chosen for LOCATION rather than for a spelling the
# fix is free to choose: the parse boundary (which decides what every later reader can see) and
# the head of the migration loop (which decides what that one arm examines).
ANCHOR_PARSE='            rows.append(json.loads(line))'
ANCHOR_UND='undeclared = []
for r in rows:'

# =============================================================================================
# HARNESS POSITIVE CONTROL — before any assertion, prove the subject runs at all.
# A copy that dies sourcing something emits nothing, and "no output" scores as a kill on every
# absence-shaped arm below. This one is PRESENCE-shaped and it exits 2, not 1: a fixture that
# cannot drive its subject is broken, not a regression in the subject.
# =============================================================================================
printf '%s\n' '{"entry":"extensions/probe.md","reason":"probe","owed":{"id":"OWED-PROBE-0","what":"w"}}' \
  | python3 "$WORK/mkreg.py" "$WORK/probe.jsonl"
probe_out="$(run "$WORK/probe.jsonl")"; probe_rc=$?
if [ "$probe_rc" -ne 0 ] || ! grep -q 'LAYER DEBT' <<<"$probe_out" || ! grep -q 'OWED-PROBE-0' <<<"$probe_out"; then
  echo "layer-debt-due-and-discharge: FIXTURE BROKEN — the subject did not produce a report (rc=$probe_rc)" >&2
  show "$probe_out" >&2
  exit 2
fi

# =============================================================================================
# THE CORPUS — one register, one run, every shape side by side. `dis` and `nom` carry the SAME
# reason string and differ in exactly one field, so an arm that passes on `dis` and fails on
# `nom` is an arm that fires on the right ROW rather than merely on the right corpus.
# =============================================================================================
DREG="$WORK/discharge.jsonl"
python3 "$WORK/mkreg.py" "$DREG" <<'SPEC'
{"entry":"extensions/dis.md","reason":"carries an obligation","owed":{"id":"OWED-D1","what":"split X out","closes_when":"after the pull"}}
{"entry":"extensions/dis.md","reason":"Debt discharged. The repath landed.","closes_owed":["OWED-D1"]}
{"entry":"extensions/nom.md","reason":"Debt discharged. The repath landed."}
{"entry":"extensions/str.md","reason":"Debt discharged. The repath landed.","closes_owed":"OWED-D2"}
{"entry":"extensions/emp.md","reason":"Debt discharged. The repath landed.","closes_owed":[]}
{"entry":"extensions/both.md","reason":"Debt discharged. A follow-up split is still deferred.","closes_owed":["OWED-D3"],"owed":{"id":"OWED-B1","what":"refile as an override"}}
{"entry":"extensions/ride.md","reason":"Debt discharged. A follow-up split is still deferred.","closes_owed":["OWED-D3"]}
{"entry":"extensions/clean.md","reason":"additive; core says nothing about this surface"}
SPEC
dout="$(run "$DREG")"
und_block() { awk '/^UNDECLARED/{f=1} /^CONTRADICTS-CORE/{f=0} f' <<<"$1"; }
dund="$(und_block "$dout")"

# --- 1. THE OFFENDER: a discharge row must not be filed as undeclared debt ---------------------
if grep -q 'dis\.md' <<<"$dund"; then
  bad "a row that DISCHARGES a debt was filed as an undeclared one — closing a debt raises the backlog it is supposed to drain"
  show "$dund"
else
  ok "a discharge row (\`closes_owed\`, conventional \`Debt discharged.\` reason) is not filed as undeclared"
fi

# --- 2. THE NEAR-MISS, BESIDE IT, IN THE SAME RUN ---------------------------------------------
# Byte-identical reason to `dis`. The ONLY difference is that this row discharges nothing, so
# its prose really is an undeclared obligation. An exemption that swallows this row has widened
# past its own subject, and no separate run could ask the question.
if grep -q 'nom\.md' <<<"$dund"; then
  ok "NEAR-MISS: the same reason prose on a row that discharges NOTHING is still reported"
else
  bad "the exemption swallowed a genuine undeclared obligation — it is keyed on the prose, not on the discharge"
  show "$dund"
fi

# --- 3. and the count is exactly the two rows that earn it ------------------------------------
# A count on its own passes against an arm that flags everything and against one that flags
# nothing; it is asserted here only as a conjunct to the identities either side of it.
if grep -qE '^UNDECLARED \(2\)' <<<"$dout"; then
  ok "exactly 2 of the 5 cue-carrying rows are reported — the other 3 discharge a debt"
else
  bad "the undeclared count is not 2; the arm is not partitioning discharge rows from obligations"
  show "$dout"
fi

# --- 4. EXEMPTION BOUNDARY: an EMPTY `closes_owed` discharges nothing --------------------------
# The exemption's whole justification is "this row pays a debt". `[]` pays none, so the row is an
# ordinary one and its prose still counts. A fix written on key PRESENCE rather than on VALUE
# gets this wrong, and it is the seed that tells the two apart.
if grep -q 'emp\.md' <<<"$dund"; then
  ok "EXEMPTION BOUNDARY: an empty \`closes_owed\` array discharges nothing and does not exempt"
else
  bad "an empty \`closes_owed\` exempted the row — the skip is keyed on the KEY, not on a discharge"
  show "$dund"
fi

# --- 5. EXEMPTION SEED: the malformed-but-real discharge --------------------------------------
# `closes_owed` as a bare STRING is schema-invalid, still valid JSON, and the debt join already
# honours it while COUNTING it rather than repairing it silently. It is a real discharge, so it
# exempts here too — otherwise the two readers answer differently about the same row, and the
# operator is punished twice for one typo. An implementation keyed on `isinstance(..., list)`
# gets this wrong.
if grep -q 'str\.md' <<<"$dund"; then
  bad "a mistyped-but-real discharge row was filed as undeclared debt — the two readers disagree about whether that row discharges anything"
  show "$dund"
else
  ok "EXEMPTION SEED: a bare-string \`closes_owed\` is still a discharge and still exempts"
fi
if grep -q 'MISTYPED_CLOSES_OWED=1' <<<"$dout"; then
  ok "CONTROL: and the mistyped row is still COUNTED, so the exemption did not make its schema unenforceable"
else
  bad "the mistyped row stopped being counted — the exemption swallowed the report that gets the row fixed"
  show "$dout"
fi

# --- 6. THE EXEMPTION DOES NOT ACQUIT THE ARM'S OWN SUBJECT -----------------------------------
# A discharge row may also open a NEW obligation, and the schema permits `owed` and `closes_owed`
# on one row. If the exemption left no route to declaring one, it would be a mechanism defending
# its own defect: the arm's subject would become unreportable on exactly the rows the exemption
# covers. Both halves are asserted — the row is exempt from the suspicion arm AND its explicit
# commitment is still enumerated.
if grep -q 'both\.md' <<<"$dund"; then
  bad "a row carrying an explicit \`owed\` was still filed as undeclared — a commitment is being reported as a suspicion"
  show "$dund"
else
  ok "a discharge row carrying an explicit \`owed\` is exempt from the suspicion arm"
fi
if grep -qE '^OPEN \(1\)' <<<"$dout" && grep -q 'OWED-B1' <<<"$dout"; then
  ok "ACQUITTAL PROBE: and its explicit commitment is still OPEN — the exemption left the route to the arm's own subject reachable"
else
  bad "the new obligation declared on a discharge row vanished — the exemption closed the only way to report the arm's subject"
  show "$dout"
fi

# --- 6b. THE EXEMPTION'S KNOWN COST, ASSERTED SO IT CANNOT BE FORGOTTEN ------------------------
# `ride.md` carries `both.md`'s reason VERBATIM and declares no `owed`. It genuinely rides a new
# obligation in on a discharge row, and the exemption DOES silence it. Arm 6 above proves the
# DECLARED route stays open; it does not prove this one is caught, because it is not.
#
# THIS ARM ASSERTS THE TRADE RATHER THAN THE ABSENCE OF ONE. The alternative — reporting any
# discharge row whose prose reads forward — is the lexical narrowing this arm's own header
# rejects, and it reinstates the 27% noise the exemption removed. So the boundary is: an
# obligation riding on a discharge row must be DECLARED in `owed`, and `ride.md` is here so the
# next author meets that cost as an assertion instead of rediscovering it as a silence.
#
# MEASURED BEFORE ACCEPTING IT, on the reference consumer's register: of the 9 rows this
# exemption silences, **0** declare a new obligation. Both candidates that a forward-looking
# prose scan flags were read in full and both REPORT a completed close — one ends "Verdict
# unchanged", the other names a residual and calls it "migration backlog rather than a reason to
# keep prescribing the retired shape". The trade costs nothing on the only register that exists.
if grep -q 'ride\.md' <<<"$dund"; then
  bad "FIXTURE STALE: \`ride.md\` was reported, so the exemption no longer silences an undeclared obligation riding on a discharge row. That is a BEHAVIOUR CHANGE, not a bug — re-measure the noise it costs and rewrite this arm."
  show "$dund"
else
  ok "KNOWN COST: an obligation riding on a discharge row without an explicit \`owed\` IS silenced — the documented trade, measured at 0 of 9 on the reference register"
fi

# --- 7. CONTROL: a row with neither a discharge nor a cue appears nowhere ----------------------
if grep -q 'clean\.md' <<<"$dout"; then
  bad "CONTROL: a row with no debt, no discharge and no cue was reported — the reader flags everything"
  show "$dout"
else
  ok "CONTROL: a row with neither a debt nor a cue is silent"
fi

# --- 8. cwd-invariance ------------------------------------------------------------------------
# Every path this fixture hands the subject is absolute and the subject is located relative to
# THIS script, so the answer must not depend on where the process happens to stand. A fixture
# that is green only from the repo root may be asserting nothing; this arm asserts the property
# in its own arms rather than inheriting it from how the suite is driven.
cwd_out="$( (cd / && bash "$AUDIT" --register "$DREG" 2>&1) )"
if [ "$cwd_out" = "$dout" ]; then
  ok "cwd-invariant: the same register read from / produces a byte-identical report"
else
  bad "the report depends on the process working directory — the same register read from / differs"
  show "$(diff <(printf '%s\n' "$dout") <(printf '%s\n' "$cwd_out") || true)"
fi

# =============================================================================================
# THE DENIED-CUE CLASS — a reason that says, in as many words, that nothing is owed.
#
# The third false-positive class of the same arm, and the one that punishes the correct answer:
# the remedy this report prints is "re-record each with an `owed` object", and an adjudicator who
# instead writes `No owed is carried because there is no residual obligation` trips the cue by
# saying so. The register is APPEND-ONLY, so no later act can clear that row.
#
# Every seed below is a phrasing taken from the reference register, never from what the reader
# accepts — a seed derived from the accept-set only proves the reader accepts its own grammar.
# The pairs sit in ONE register read by ONE invocation, so each arm asks whether the discount
# fires on the RIGHT row rather than merely whether it fires.
# =============================================================================================
NREG="$WORK/negation.jsonl"
python3 "$WORK/mkreg.py" "$NREG" <<'SPEC'
{"entry":"extensions/deny.md","reason":"Verdict recorded. No owed is carried on this entry."}
{"entry":"extensions/keep.md","reason":"Verdict recorded. New owed is carried on this entry."}
{"entry":"extensions/mixed.md","reason":"No owed is declared for the anchor. The split remains deferred to a later pull."}
{"entry":"extensions/nothingtp.md","reason":"Nothing but this reason field is tracking that debt."}
{"entry":"extensions/clause.md","reason":"This entry declares no extends: anchor. The split remains deferred to a later pull."}
{"entry":"extensions/contrast.md","reason":"GAP CLOSED IN THIS COMMIT rather than deferred: added the row with this project's path set."}
SPEC
nout="$(run "$NREG")"
nund="$(und_block "$nout")"

# --- 9. THE OFFENDER: a reason denying an obligation is not filed as one -----------------------
if grep -q 'deny\.md' <<<"$nund"; then
  bad "a reason stating \`No owed is carried\` was filed as an undeclared obligation — the arm charges the adjudicator for writing down that nothing is owed, and an append-only register can never clear it"
  show "$nund"
else
  ok "a cue inside a clause that DENIES an obligation is not reported"
fi

# --- 10. THE NEAR-MISS, BESIDE IT, IN THE SAME RUN --------------------------------------------
# `keep.md` differs from `deny.md` by exactly one token: `No` -> `New`. An implementation that
# discounts the cue rather than the DENIAL swallows this row too, and no separate run could ask.
if grep -q 'keep\.md' <<<"$nund"; then
  ok "NEAR-MISS: the same sentence one token apart (\`New owed\` for \`No owed\`) is still reported"
else
  bad "the discount swallowed a genuine obligation one token from the denial — it is keyed on the cue, not on the negation"
  show "$nund"
fi

# --- 11. PER OCCURRENCE, NOT PER ROW ----------------------------------------------------------
# `mixed.md` denies one obligation and states another in the next sentence. A row-grain
# implementation — skip the row if ANY cue is denied — silences the second, and that is a
# genuine debt lost to a disclaimer sitting in front of it. This is the arm that separates the
# two designs; nothing else here can.
if grep -q 'mixed\.md' <<<"$nund"; then
  ok "PER-OCCURRENCE: a reason that denies one obligation and STATES another is still reported"
else
  bad "a row-grain discount silenced a real obligation because an earlier sentence denied a different one"
  show "$nund"
fi

# --- 12. `nothing` IS NOT A NEGATOR, AND THIS IS THE ARM THAT SAYS SO -------------------------
# `Nothing but this reason field is tracking that debt` is the strongest TRUE positive phrasing
# in the corpus — it is how both genuine debts on the reference register describe themselves.
# A negator set that reads `nothing` as a denial acquits exactly the sentence this file exists
# to surface, and it would look like a reasonable widening.
#
# THE SEED CARRIES THAT SENTENCE AND NOTHING ELSE, and the first cut of it did not. Written with
# the register's full phrasing — `OWED REMEDIATION, deferred by operator decision.` ahead of it —
# the row kept THREE cues in a sentence the discount never touches, so it was reported whatever
# the negator set said and mutant M7 SURVIVED. A guard needs a subject the other guards cannot
# see; here that means the governed cue must be the row's ONLY cue.
if grep -q 'nothingtp\.md' <<<"$nund"; then
  ok "\`Nothing but this reason field is tracking that debt\` is still reported — \`nothing\` is not admitted as a negator"
else
  bad "the strongest true-positive phrasing in the corpus was acquitted — \`nothing\` has been admitted to the negator set and the arm now silences its own subject"
  show "$nund"
fi

# --- 13. CLAUSE BOUNDARY: a negator in a PREVIOUS sentence must not reach the cue --------------
# `clause.md` carries `no` in its first sentence, about an `extends:` anchor, and a real
# obligation in its second. A discount that searches the whole reason before the cue — the
# obvious implementation — acquits it on a negator governing something else entirely.
if grep -q 'clause\.md' <<<"$nund"; then
  ok "CLAUSE BOUNDARY: a negator in the previous sentence does not acquit the cue in this one"
else
  bad "a negator two sentences upstream acquitted a real obligation — the discount is not bounded to the cue's own clause"
  show "$nund"
fi

# --- 14. the explicit-contrast spelling ------------------------------------------------------
if grep -q 'contrast\.md' <<<"$nund"; then
  bad "\`rather than deferred\` — an explicit statement that the work was NOT deferred — was filed as deferred work"
  show "$nund"
else
  ok "an explicit contrast (\`rather than deferred\`) is not reported as an obligation"
fi

# --- 15. and the count is exactly the four rows that earn it ----------------------------------
if grep -qE '^UNDECLARED \(4\)' <<<"$nout"; then
  ok "exactly 4 of the 6 cue-carrying rows are reported — the other 2 deny their obligation"
else
  bad "the undeclared count is not 4; the discount is not partitioning denials from obligations"
  show "$nout"
fi

# =============================================================================================
# MUTANTS. Every arm above that asserts an ABSENCE passes against a subject that emitted
# nothing, and a both-directions control cannot see that: it establishes that the arm
# discriminates between two inputs, never that it discriminates at all. These do.
#
# Each is keyed on a LOCATION and scored on an OBSERVABLE, never on a spelling the fix is free
# to choose. The kill is asserted as a POSITIVE outcome — a specific row REAPPEARING or
# VANISHING — because a widened guard often reproduces the original output and would otherwise
# score a kill it did not earn.
# =============================================================================================
score() { # score <label> <path-or-empty> <register> <describe> <present|absent> <token>
  local label="$1" m="$2" reg="$3" desc="$4" mode="$5" tok="$6" out hit
  if [ -z "$m" ]; then
    bad "FIXTURE ERROR: mutation '$label' matched nothing — the arm it scores proves nothing"
    return
  fi
  out="$(bash "$m" --register "$reg" 2>&1)"
  hit=no; grep -q "$tok" <<<"$out" && hit=yes
  if { [ "$mode" = present ] && [ "$hit" = yes ]; } || { [ "$mode" = absent ] && [ "$hit" = no ]; }; then
    ok "MUTANT $label KILLED — $desc"
  else
    bad "MUTANT $label SURVIVED — $desc did not happen, so the arm it backs passes whatever the reader does"
    show "$out"
  fi
}

# M1 — the migration arm made blind to `closes_owed`, i.e. the behaviour this fixture's subject
# replaced. Rebinding `rows` at the head of that loop reaches nothing above it: `open_items` and
# the contradicts-core join are both already computed, so this mutant can only move arms 1/3/5.
score M1 "$(mkmut m1 "$ANCHOR_UND" 'undeclared = []
rows = [ {k: v for k, v in _r.items() if k != "closes_owed"} for _r in rows ]
for r in rows:')" "$DREG" \
  "with the discharge field hidden from the migration arm, the discharge row is filed as undeclared again" \
  present 'dis\.md'

# M2 — THE DISARM. The loop still runs, the script still exits 0, the report still prints a tidy
# `UNDECLARED (0)` — and zero rows were examined. This is the shape that reads as a fix, and
# every absence-shaped arm above passes against it.
score M2 "$(mkmut m2 "$ANCHOR_UND" 'undeclared = []
for r in rows:
    continue')" "$DREG" \
  "an arm that examines zero rows and reports a clean tree loses the genuine obligation" \
  absent 'nom\.md'

# M3 — the exemption widened from a discharge to the mere presence of the key.
score M3 "$(mkmut m3 "$ANCHOR_UND" 'undeclared = []
rows = [ (dict(_r, closes_owed=["X"]) if "closes_owed" in _r else _r) for _r in rows ]
for r in rows:')" "$DREG" \
  "an exemption keyed on the KEY rather than on a discharge acquits the empty-array row" \
  absent 'emp\.md'

# M4 — the exemption reaching one loop too far and eating the declaration path. Scored on the
# NEW obligation vanishing, which is the acquittal probe's whole subject.
score M4 "$(mkmut m4 "$ANCHOR_PARSE" '            _r = json.loads(line)
            if _r.get("closes_owed"):
                _r.pop("owed", None)
            rows.append(_r)')" "$DREG" \
  "an exemption that reaches the declaration loop deletes the commitment declared on a discharge row" \
  absent 'OWED-B1'

# The denied-cue anchors. Keyed on the three decisions the discount makes — WHICH words deny,
# HOW FAR back it looks for one, and WHETHER it is scored per cue or per row — rather than on a
# spelling. Each mutant below moves exactly one of the three.
ANCHOR_HITS='    hits = sorted({m.group(0).lower() for m in PROSE.finditer(reason)
                   if not cue_denied(reason, m)})'
ANCHOR_NEGSET='NEGATED = re.compile(r"\bno\b|\brather than\b|\binstead of\b", re.I)'
ANCHOR_CLAUSE='    start = 0
    for b in CLAUSE_END.finditer(reason, 0, m.start()):
        start = b.end()'

# M5 — the discount removed entirely, i.e. the behaviour this section's subject replaced. Scored
# on the denial row REAPPEARING, which is a positive outcome rather than the absence of a message.
score M5 "$(mkmut m5 "$ANCHOR_HITS" '    hits = sorted({m.group(0).lower() for m in PROSE.finditer(reason)})')" "$NREG" \
  "with the denial discount gone, a reason stating \`No owed is carried\` is filed as an obligation again" \
  present 'deny\.md'

# M6 — the discount moved from the CUE to the ROW: any denied cue silences the whole row. This is
# the design the arm above exists to reject, and every other assertion in this section passes
# against it — only `mixed.md` can tell the two apart.
score M6 "$(mkmut m6 "$ANCHOR_HITS" '    hits = sorted({m.group(0).lower() for m in PROSE.finditer(reason)})
    if any(cue_denied(reason, _m) for _m in PROSE.finditer(reason)):
        hits = []')" "$NREG" \
  "a row-grain discount silences a real obligation stated after a denial of a different one" \
  absent 'mixed\.md'

# M7 — `nothing` admitted to the negator set. The plausible widening, and it acquits the exact
# sentence both genuine debts on the reference register use to describe themselves.
score M7 "$(mkmut m7 "$ANCHOR_NEGSET" 'NEGATED = re.compile(r"\bno\b|\bnothing\b|\brather than\b|\binstead of\b", re.I)')" "$NREG" \
  "admitting \`nothing\` as a negator acquits \`Nothing but this reason field is tracking that debt\`" \
  absent 'nothingtp\.md'

# M8 — the clause bound dropped, so the search runs from the head of the reason. The obvious
# implementation, and it acquits an obligation on a negator governing an earlier sentence.
score M8 "$(mkmut m8 "$ANCHOR_CLAUSE" '    start = 0')" "$NREG" \
  "an unbounded backward search acquits a real obligation on a negator from the previous sentence" \
  absent 'clause\.md'

# UNMUTATED CONTROL — necessary and NOT sufficient. rc=0-with-no-findings is exactly what a
# subject replaced by `exit 0` looks like, so this carries a POSITIVE conjunct: a copy taken and
# invoked the same way as every mutant must still NAME the baseline rows.
CTL="$WORK/control.sh"
cp "$AUDIT" "$CTL"
ctl_out="$(bash "$CTL" --register "$DREG" 2>&1)"; ctl_rc=$?
if [ "$ctl_rc" -eq 0 ] && grep -q 'nom\.md' <<<"$ctl_out" && grep -q 'OWED-B1' <<<"$ctl_out"; then
  ok "CONTROL: an UNMUTATED copy, taken and invoked exactly as the mutants are, still names the baseline rows — so a kill above is the mutation and not the harness"
else
  bad "CONTROL: an unmutated copy did not reproduce the baseline (rc=$ctl_rc) — every kill above may be the harness failing to run the subject"
  show "$ctl_out"
fi

echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "layer-debt-due-and-discharge: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. One did not execute at all, which is not the same as one that passed."
  exit 1
fi
if [ "$fails" -eq 0 ]; then echo "layer-debt-due-and-discharge: PASS ($made assertions)"; exit 0; fi
echo "layer-debt-due-and-discharge: FAIL ($fails of $made)"; exit 1
