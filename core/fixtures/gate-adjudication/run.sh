#!/usr/bin/env bash
# gate-adjudication/run.sh — the 3-step proof of validate-gate-adjudication.sh's fail-closed
# contract, plus the DERIVATION assertion.
#
# THE DEFECT THIS EXISTS TO CATCH. The gate-adjudication verdict is the ONE deliverable through
# which a cheaper-model lead adopts the read-and-compare judgment checks. If the validator that
# reads it can be fooled — a missing check that reads as covered, a stale verdict that reads as
# fresh, a bad map value that silently empties the escalated set, an absent file that reads as a
# pass — then a judgment check is adjudicated by no one, which reads EXACTLY like a check that
# passed. This proves each of those blocks.
#
# Structure mirrors the fixture discipline used across this suite:
#   (a) a COMPLETE, all-PASS verdict passes (exit 0) — the sanity baseline;
#   (b) each corruption fails with the RIGHT code (1 = defect, 2 = derivation/absent);
#   (c) restoring passes again (exit 0);
#   and --expected prints EXACTLY the derived set (no hand-list can drift from the map).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

run() { # run <verdict_path> -> sets RC to the validator's exit code
  AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
    bash "$VALIDATOR" "$GATE_TYPE" "$1" >/dev/null 2>&1
  RC=$?
}

# Rebuild the pristine verdict from the seed's canonical copy before each mutation, so the
# assertions are independent.
PRISTINE="$WORK/pristine.verdict.json"
cp "$VERDICT" "$PRISTINE"
restore() { cp "$PRISTINE" "$VERDICT"; }

py_edit() { # py_edit <code> — mutate $VERDICT in place with a python snippet over `doc`
  python3 - "$VERDICT" "$1" <<'PY'
import json, sys
path, code = sys.argv[1], sys.argv[2]
doc = json.load(open(path))
exec(code)
open(path, "w").write(json.dumps(doc, indent=2) + "\n")
PY
}

echo "gate-adjudication:"

# --- Assertion 0: SANITY (step a) --------------------------------------------
# A complete, all-PASS verdict must PASS. If it does not, every negative below is a false pass.
run "$VERDICT"
if [ "$RC" -eq 0 ]; then
  ok "complete all-PASS verdict → exit 0 (the negatives below mean something)"
else
  bad "FIXTURE BROKEN — pristine all-PASS verdict did not pass (rc=$RC). Every assertion below would be a false pass."
  echo; echo "gate-adjudication: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: DERIVATION --------------------------------------------------
# --expected must print EXACTLY the verdict's covered set. A hand-maintained escalation list is
# the exact bug this design removes; assert the two derivations agree.
EXP="$(AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" bash "$VALIDATOR" --expected "$GATE_TYPE" | sort)"
COV="$(python3 -c 'import json,sys; print("\n".join(sorted(v["check_id"] for v in json.load(open(sys.argv[1]))["verdicts"])))' "$VERDICT")"
if [ "$EXP" = "$COV" ]; then
  ok "--expected $GATE_TYPE prints exactly the covered set ($(printf '%s' "$EXP" | tr '\n' ' '))"
else
  bad "--expected does NOT match the verdict's covered set — derivation drift"
fi

# --- Assertion 2: MISSING ESCALATED ID (step b) → exit 1 ---------------------
restore
py_edit 'doc["verdicts"] = doc["verdicts"][:-1]'   # drop one escalated check
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "deleting an escalated entry → exit 1" || bad "a missing escalated check did NOT fail with exit 1 (rc=$RC) — an unadjudicated check reads as clean"

# --- Assertion 3: EMPTY EVIDENCE (step b) → exit 1 ---------------------------
restore
py_edit 'doc["verdicts"][0]["evidence"] = ""'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "blanking an evidence → exit 1" || bad "empty evidence did NOT fail with exit 1 (rc=$RC) — an unjustified PASS survived"

# --- Assertion 4: BAD VERDICT ENUM (step b) → exit 1 -------------------------
restore
py_edit 'doc["verdicts"][0]["verdict"] = "MAYBE"'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "verdict:MAYBE → exit 1" || bad "a third verdict value did NOT fail with exit 1 (rc=$RC)"

# --- Assertion 5: MAP ADJUDICATION TYPO (step b) → exit 2 --------------------
# A typo like 'lmm' is a hole in the derivation, not a fourth class. The honest failure is at the
# derivation layer (exit 2), BEFORE any verdict is trusted — else the escalated set silently
# shrinks and a real judgment check is escalated to no one.
restore
BADMAP="$WORK/enforcement-map.bad.yaml"
awk 'BEGIN{d=0} /^    adjudication: llm$/ && !d {sub(/llm/,"lmm"); d=1} {print}' "$MAP" > "$BADMAP"
if ! grep -q 'adjudication: lmm' "$BADMAP"; then
  bad "FIXTURE STALE: no 'adjudication: llm' line to corrupt in the map"
else
  AI_DLC_ENFORCEMENT_MAP="$BADMAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" >/dev/null 2>&1
  RC=$?
  [ "$RC" -eq 2 ] && ok "an unknown map adjudication value ('lmm') → exit 2 (derivation layer)" || bad "a map typo did NOT fail with exit 2 (rc=$RC) — the escalated set could silently empty"
fi

# --- Assertion 6: ABSENT VERDICT → exit 2 ------------------------------------
restore
run "$WORK/gate-adjudication/does-not-exist.verdict.json"
[ "$RC" -eq 2 ] && ok "an absent verdict → exit 2 (non-delivery, not a clean gate)" || bad "an absent verdict did NOT fail with exit 2 (rc=$RC) — the stale/absent-reads-as-pass hole"

# --- Assertion 7: STALE VERDICT (nonce mismatch) → exit 1 --------------------
# A verdict whose gate_nonce does not match its path stem is a stale or foreign artifact.
restore
py_edit 'doc["gate_nonce"] = "implementation-20260101T000000Z"'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "a nonce that mismatches the path stem → exit 1 (freshness anchor)" || bad "a stale nonce did NOT fail with exit 1 (rc=$RC)"

# --- Assertion 8: ABSENT gate_series_id → exit 1 -----------------------------
# Without this arm the new required field is asserted by nothing here: it sits in the pristine
# dict, the restore arm passes, and a reader that never looked at it would score identically.
# The series id is what --series groups on; a verdict that omits it is invisible to the stall
# rung, and the rung's own legacy path would count it as a retained prior series rather than a
# missing pass. The per-pass gate is where that has to be caught.
restore
py_edit 'del doc["gate_series_id"]'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "deleting gate_series_id → exit 1 (the pass would be invisible to --series)" || bad "a verdict with no gate_series_id did NOT fail with exit 1 (rc=$RC) — it would drop out of the stall rung's count"

# --- Assertion 9: RESTORE (step c) → exit 0 ----------------------------------
restore
run "$VERDICT"
[ "$RC" -eq 0 ] && ok "restored verdict → exit 0" || bad "the restored pristine verdict did not pass again (rc=$RC)"

# =============================================================================
# S1–S11: the SUPPRESSED carve-out.
#
# THE DEFECT THESE EXIST TO CATCH, IN BOTH DIRECTIONS. A FAIL on an escalated check used to
# block unconditionally, so an operator's in-force suppression could cover a lead-evaluated
# check and never an escalated one. The carve-out closes that — and every way of writing it
# too widely reopens something worse: a suppression that is expired, malformed, filed under
# another catalog, written for a different check, or simply unreadable must still block.
#
# EVERY CASE SETS AI_DLC_ESCALATIONS AND AI_DLC_GATE_METRICS EXPLICITLY. Both channels
# default to the tree the validator resolves — `<root>/docs/escalations/pending.md`, and for
# the metrics the sibling's own locate-from-cwd. On a consumer those are REAL files holding
# REAL in-force suppressions (measured on the reference consumer: one in-force `[core] 16`),
# so a case that leaves either unset is adjudicated against whatever that consumer happens to
# have suppressed this week. The negative cases would go green there for a reason no output
# names, which is this whole fixture's failure mode one level up.
#
# EVERY CASE IS PRESENCE-SHAPED. An exit code alone cannot tell a carve-out that fired for the
# right reason from a validator that never looked: `exit 1` is also what a program that never
# ran produces. Each arm names a token that only its own path emits.
SOUT="$WORK/carveout.out"

# EVERY CASE NAMES A TRANSCRIPT CORPUS TOO. The validator verifies each in-force entry's
# operator citation against `--transcript-dir` before the entry can cover anything, and with no
# corpus it fails closed (S19, S21). The seed's $TDIR carries the quote every seeded entry
# cites, said by the operator, so S1–S17 exercise the join and the lifetime with the citation
# already verified; the third argument overrides the corpus for the cases that are ABOUT it.
runx() { # runx <escalations> <gate-metrics> [<transcript-dir>] — RC and $SOUT from the pristine-plus-mutation verdict
  AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
  AI_DLC_ESCALATIONS="$1" AI_DLC_GATE_METRICS="$2" \
    bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" --transcript-dir "${3:-$TDIR}" > "$SOUT" 2>&1
  RC=$?
}

# `grep -c` PRINTS ITS ZERO AND EXITS 1, so `n=$(grep -c … || echo 0)` is two lines and the
# arithmetic below would abort the arm with no verdict. Capture first, default on failure.
has() { local n; n="$(grep -cF -- "$1" "$SOUT")" || n=0; [ "$n" -gt 0 ]; }

fail_on() { # fail_on <check_id>… — flip exactly these checks to FAIL in $VERDICT
  python3 - "$VERDICT" "$@" <<'PY'
import json, sys
path, want = sys.argv[1], set(sys.argv[2:])
doc = json.load(open(path))
hit = {v["check_id"] for v in doc["verdicts"] if v["check_id"] in want}
if hit != want:
    sys.stderr.write("FIXTURE STALE: %s not in the verdict\n" % sorted(want - hit))
    sys.exit(2)
for v in doc["verdicts"]:
    if v["check_id"] in want:
        v["verdict"] = "FAIL"
        v["evidence"] = "fixture: seeded FAIL on check %s" % v["check_id"]
open(path, "w").write(json.dumps(doc, indent=2) + "\n")
PY
}

# The tokens each arm demands. Written once here rather than inline, because a token typed
# twice is a token that can drift in one place only.
SUPP_LINE="VALIDATE-GATE-ADJUDICATION: SUPPRESSED — check '$X' FAIL is covered"
BLOCK_X="gate check(s) FAILED per the adjudicator: ['$X']"
BLOCK_Y="gate check(s) FAILED per the adjudicator: ['$Y']"
UNVERIFIED_LINE="VALIDATE-GATE-ADJUDICATION: UNVERIFIED"

# --- S1: an in-force entry naming X, and X FAILs → exit 0 --------------------
restore; fail_on "$X"
runx "$ESC_INFORCE" "$GM_BEFORE"
if [ "$RC" -eq 0 ] && has "$SUPP_LINE" && has "1 FAIL under an in-force"; then
  ok "S1: FAIL on '$X' under an in-force SUPPRESSED entry naming it → exit 0, and the PASS line says 1 FAIL under an in-force entry"
else
  bad "S1: a FAIL covered by a well-formed, in-force suppression did NOT pass (rc=$RC) or printed no SUPPRESSED line — the carve-out this fixture guards is not reachable"
fi

# --- S2: the same entry, a FAIL on a DIFFERENT check → exit 1 ---------------
# X PASSes here, so the block carries no "other FAIL(s)" clause. A suppression is about the
# check it names; anything that reads it as an authorization to proceed past THE GATE would
# pass this, and that is the widest possible wrong fix.
restore; fail_on "$Y"
runx "$ESC_INFORCE" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_Y" && ! has "VALIDATE-GATE-ADJUDICATION: SUPPRESSED" \
   && ! has "other FAIL(s) are under"; then
  ok "S2: an entry naming '$X' does NOT cover a FAIL on '$Y' → exit 1, block names '$Y', nothing suppressed"
else
  bad "S2: a suppression naming '$X' covered a FAIL on '$Y' (rc=$RC) — the carve-out is keyed on the gate, not on the check"
fi

# --- S2b: BOTH fail, one covered → exit 1 with the "other FAIL(s)" clause ----
# The ALLOW twin of S2, one property apart: the same entry, the same two checks, and X now
# failing too. Without it, "no other-FAIL clause" in S2 is satisfied by a validator that never
# writes the clause at all, and the partial-coverage path is asserted by nothing.
restore; fail_on "$X" "$Y"
runx "$ESC_INFORCE" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_Y" && has "$SUPP_LINE" && has "1 other FAIL(s) are under"; then
  ok "S2b: '$X' covered and '$Y' not → exit 1, block names only '$Y', and says 1 other FAIL is under a suppression"
else
  bad "S2b: partial coverage was not reported (rc=$RC) — either the covered FAIL blocked anyway or the block text does not say which FAILs were suppressed"
fi

# --- S3: the entry is EXPIRED → exit 1 --------------------------------------
# Two distinct gate events recorded after the authorization, against `**Expires after:** 1`.
# The token is the sibling's own `in_force=0`: it proves the query RAN and returned nothing,
# which is a different claim from the gate having blocked.
#
# S3 is the ONLY exclusion case keyed on that summary line, and deliberately: its entry is the
# only one that produces no diagnostic, so the summary is all it has. S4, S5 and S8 each key on
# the diagnostic their own exclusion emits instead. Keying all four on the summary would tie
# them to WHEN that line is printed rather than to WHY each entry was excluded, and one change
# to the sibling's exit discipline would then move four cases at once.
restore; fail_on "$X"
runx "$ESC_EXPIRED" "$GM_AFTER"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "in_force=0"; then
  ok "S3: an entry past its 1-gate lifetime (2 gates recorded since authorization) covers nothing → exit 1"
else
  bad "S3: an EXPIRED suppression still covered the FAIL (rc=$RC) — a suppression with no expiry is an override with a new name"
fi

# --- S4: the entry is MALFORMED — no operator citation → exit 1 -------------
# AND IT IS EXCLUDED BY THE SIBLING, not by the citation verifier one screen down. An entry
# with no `**Operator authorization:**` line has no quote, so the verifier would drop it too
# and print its UNVERIFIED line — which would make the sibling's shape exclusion invisible
# from here and let a sibling that lists malformed entries pass this case on the verifier's
# back. The absence of that line is what says the row never reached the verifier.
restore; fail_on "$X"
runx "$ESC_MALFORMED" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "malformed SUPPRESSED entry" && ! has "$UNVERIFIED_LINE"; then
  ok "S4: a SUPPRESSED entry with no **Operator authorization:** covers nothing → exit 1, the sibling says why, and the row never reached the citation verifier"
else
  bad "S4: a malformed suppression covered the FAIL (rc=$RC), or it was excluded only downstream by the citation verifier — an unauthorized entry became an authorization, or the sibling stopped owning the shape"
fi

# --- S5: the CONSUMER'S ORIGINAL SHAPE — fields under DECIDED_AUTONOMOUSLY --
# The status token is the first [A-Z_] run after the label, so this entry classifies as
# DECIDED_AUTONOMOUSLY and its three suppression fields are adjudicated for nothing. It is the
# shape the corpus actually contains; a carve-out that reads the FIELDS rather than the STATUS
# would let a lead's own disposition wave a gate through.
restore; fail_on "$X"
runx "$ESC_DECIDED" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "does not classify as SUPPRESSED"; then
  ok "S5: **Suppresses:**/**Expires after:** under a DECIDED_AUTONOMOUSLY status cover nothing → exit 1"
else
  bad "S5: a non-SUPPRESSED entry carrying suppression fields covered the FAIL (rc=$RC) — the carve-out reads fields, not status"
fi

# --- S6: catalog MISMATCH → exit 1, and the id-only twin → exit 0 -----------
# `in_force=1` in the same output is the load-bearing half: the row IS in force, and the JOIN
# is what rejected it. Without that token this arm passes against a sibling that listed
# nothing, for a reason that has nothing to do with catalogs.
restore; fail_on "$X"
runx "$ESC_OTHERCAT" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "in_force=1"; then
  ok "S6-mismatch: an in-force entry for [extension:foo] '$X' does not cover core's '$X' → exit 1"
else
  bad "S6-mismatch: a suppression in a FOREIGN catalog covered this verdict's check (rc=$RC) — ids collide across catalogs and this join is what separates them"
fi

restore; fail_on "$X"
runx "$ESC_NOCAT" "$GM_BEFORE"
if [ "$RC" -eq 0 ] && has "$SUPP_LINE"; then
  ok "S6-idonly: an entry written **Suppresses:** '$X' with no [catalog] prefix matches on the id alone → exit 0"
else
  bad "S6-idonly: the lenient no-prefix form the lifetime parser accepts was NOT honoured (rc=$RC) — the catalog compare rejects the form the corpus is allowed to write"
fi

# --- S7: no escalations file at all → exit 1, fail-closed and named --------
restore; fail_on "$X"
runx "$ESC_MISSING" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "no-escalations-file"; then
  ok "S7: an unreadable escalations path → exit 1 and the block says 'no-escalations-file'"
else
  bad "S7: a missing escalations file did not fail closed (rc=$RC) — a suppression that cannot be read must cover nothing, and the block must say which absence it was"
fi

# --- S8: a terminal entry whose PROSE names the check → exit 1 -------------
# Kills a carve-out written as a grep for `Check <id>` over pending.md. The prose citation is
# how a RESOLVED entry describes what it closed; reading it as an authorization means every
# discussion of a check becomes a licence to fail it.
restore; fail_on "$X"
runx "$ESC_RESOLVED" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "entry names check(s)"; then
  ok "S8: a RESOLVED entry mentioning 'Check $X' in prose, with no **Suppresses:** field, covers nothing → exit 1"
else
  bad "S8: prose naming the check covered the FAIL (rc=$RC) — the carve-out is a text search, not a field join"
fi

# --- S9: the verdict's OWN catalog is foreign → exit 1 ---------------------
# The near-miss that SUPPORTS the fix, and the mirror of S6-mismatch: the entry is core's, the
# VERDICT is an extension's. One entry, two directions; a join tested from one side only reads
# as working while comparing nothing.
restore; fail_on "$X"
py_edit 'doc["catalog"] = "extension:foo"'
runx "$ESC_INFORCE" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "in_force=1"; then
  ok "S9: an in-force [core] entry does not cover a verdict whose own catalog is 'extension:foo' → exit 1"
else
  bad "S9: a core suppression covered an extension's verdict (rc=$RC) — the join ignores the verdict's catalog field"
fi

# --- S10: all PASS with an in-force entry present → the OLD line, unchanged -
# The carve-out must be invisible when it carves nothing. If the summary line changes shape on
# every gate that happens to have a live suppression, every downstream reader of that line has
# been rewritten by a change that was supposed to be conditional.
restore
runx "$ESC_INFORCE" "$GM_BEFORE"
if [ "$RC" -eq 0 ] && has "all PASS)" && ! has "VALIDATE-GATE-ADJUDICATION: SUPPRESSED"; then
  ok "S10: an all-PASS verdict with an in-force entry present → exit 0 and the unchanged 'all PASS)' line"
else
  bad "S10: the all-PASS summary line changed, or something was reported as SUPPRESSED with no FAIL to suppress (rc=$RC)"
fi

# --- S11: an entry naming a PREFIX of the failing id → exit 1 -------------
# '$XPFX' is an escalated check in its own right and the first character of '$X'. A join
# written with startswith/`in`/a substring test covers X from this entry and cannot be told
# from a correct one by any case above.
restore; fail_on "$X"
runx "$ESC_PREFIX" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "in_force=1"; then
  ok "S11: an in-force entry naming '$XPFX' does not cover a FAIL on '$X' → exit 1 (no prefix or substring match)"
else
  bad "S11: an entry naming '$XPFX' covered a FAIL on '$X' (rc=$RC) — the check id is matched by prefix or substring, so a short id suppresses every longer one"
fi

# --- S12: the bare-id entry against a FOREIGN verdict catalog → exit 1 -----
# The other half of S6-idonly, and the one that says what a missing bracket MEANS. A row with
# no `[catalog]` counts as core and nothing else, because the sibling resolves ids against the
# core catalog alone — so an author error that drops the required field must not buy WIDER
# coverage than writing it correctly would. Without this case, reading the empty catalog as a
# wildcard passes S6-idonly, S6-mismatch and S9 alike.
restore; fail_on "$X"
py_edit 'doc["catalog"] = "ext:gate-validation-domain"'
runx "$ESC_NOCAT" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "in_force=1" \
   && ! has "VALIDATE-GATE-ADJUDICATION: SUPPRESSED"; then
  ok "S12: a bare-id entry (no [catalog]) does NOT cover '$X' in a verdict whose catalog is 'ext:gate-validation-domain' → exit 1"
else
  bad "S12: an entry that named no catalog covered an extension's verdict (rc=$RC) — a dropped bracket is being read as EVERY catalog, which is wider coverage than writing it correctly"
fi

# --- S13: one malformed entry beside one good one → the good one still holds -
# Every other case's file holds a single entry, so none of them can tell "this ENTRY was
# excluded" from "this FILE was refused". Two implementations fail here and pass everything
# else: one that treats any malformed entry as poisoning the file, and one that folds the
# sibling's stderr into the rows it parses. The malformed entry names a different check, so the
# coverage of '$X' can only have come from the well-formed one.
restore; fail_on "$X"
runx "$ESC_MIXED" "$GM_BEFORE"
if [ "$RC" -eq 0 ] && has "$SUPP_LINE" && has "malformed SUPPRESSED entry"; then
  ok "S13: a malformed entry beside a well-formed in-force one is diagnosed and does NOT withdraw the carve-out → exit 0"
else
  bad "S13: a malformed entry elsewhere in the file cost the well-formed entry its carve-out (rc=$RC) — a diagnostic is being read as a refusal, or the sibling's stderr is being parsed as rows"
fi

# --- S14: the lifetime cannot be COUNTED → exit 1 --------------------------
# The same expired entry as S3, with the timeline pointed at a file that is not there. Both
# states arrive at the sibling as GATES_N=0, and reading that as "nothing has elapsed" made an
# expired suppression in force from any cwd where the metrics did not resolve — a fail-OPEN
# reachable by a typo in one environment variable. The rows become gate passage, so the query
# must decline exactly where the lifetime arm declines.
restore; fail_on "$X"
runx "$ESC_EXPIRED" "$GM_MISSING"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "NOT listed in force" && has "gates_recorded=NONE"; then
  ok "S14: an entry whose lifetime cannot be counted (no metrics file found) is NOT in force → exit 1, and the sibling says why"
else
  bad "S14: an unmeasurable lifetime was read as a licence (rc=$RC) — an expired suppression is in force from any cwd where the timeline does not resolve"
fi

# --- S15: the FRESH CONSUMER control → exit 0 ------------------------------
# The ALLOW twin of S14, one property apart: the metrics file EXISTS and records no gate. That
# is a consumer that has genuinely run none yet, and its fresh suppression is in force at 0
# elapsed. Without this case S14 is satisfied by a guard that simply refuses every suppression
# whenever GATES_N is 0, which would wedge every new consumer's first gate.
restore; fail_on "$X"
runx "$ESC_INFORCE" "$GM_EMPTY"
if [ "$RC" -eq 0 ] && has "$SUPP_LINE"; then
  ok "S15: an EXISTING but empty gate timeline is a consumer with no gate yet, not an unreadable one → exit 0"
else
  bad "S15: a fresh consumer's first suppression was refused because its timeline is empty (rc=$RC) — 'no gate recorded' and 'no timeline found' are being treated as one state"
fi

# --- S16: an all-PASS verdict does not ASK the sibling ---------------------
# The parse is hundreds of KB on a real consumer and a verdict with no FAIL has nothing to
# cover. The absence of the sibling's summary line is the only observable that says the query
# was skipped rather than asked and answered empty; S10 already holds the exit and the summary
# line, so this arm owns the skip alone.
restore
runx "$ESC_INFORCE" "$GM_BEFORE"
if [ "$RC" -eq 0 ] && has "all PASS)" && ! has "IN-FORCE:"; then
  ok "S16: an all-PASS verdict skips the in-force query entirely → exit 0 and no IN-FORCE: line"
else
  bad "S16: the sibling was asked on a verdict with no FAIL to cover (rc=$RC) — every all-PASS gate pays a parse of the whole escalations file"
fi

# --- S17: THE TIMELINE IS FOUND FROM THE PROJECT ROOT, NOT FROM THE CWD -----
# Every case above sets AI_DLC_GATE_METRICS, so none of them exercises the resolution this
# script actually performs on a live gate: the sibling is invoked with no `--gate-metrics` and
# LOCATES the timeline itself. It did that from the process CWD before the project root, and
# `verdict.sh` runs wherever the lead's session happens to be. So a suppression's lifetime was
# counted against whatever project the cwd belonged to.
#
# THE WORLD IS A PAIR: a root carrying a timeline that leaves the entry in force, and a decoy
# cwd carrying one that expires it. The two are asserted to DIFFER before the arm is read.
GA_CWD_ROOT="$WORK/cwd-root"
GA_CWD_DECOY="$WORK/cwd-decoy"
mkdir -p "$GA_CWD_ROOT/_bmad-output/implementation-artifacts" \
         "$GA_CWD_DECOY/_bmad-output/implementation-artifacts"
cp "$GM_BEFORE" "$GA_CWD_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
cp "$GM_AFTER"  "$GA_CWD_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
if cmp -s "$GA_CWD_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl" \
          "$GA_CWD_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl"; then
  bad "S17-pre: FIXTURE BROKEN — the root and decoy timelines are identical, so the arm below agrees for free"
else
  ok "S17-pre: the seeded root timeline and the decoy cwd's timeline DIFFER (in force vs expired)"
fi

# The differential's other side, established first: driven with the decoy's timeline handed in
# explicitly, this same verdict BLOCKS. So an exit 0 below can only mean the root's file was read.
restore; fail_on "$X"
runx "$ESC_INFORCE" "$GA_CWD_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
if [ "$RC" -eq 1 ] && has "$BLOCK_X"; then
  ok "S17-pre: handed the decoy's timeline explicitly, the same entry is EXPIRED and the gate blocks"
else
  bad "S17-pre: FIXTURE BROKEN — the decoy timeline does not expire the entry (rc=$RC), so S17 cannot tell which file was read"
fi

restore; fail_on "$X"
GA_S17_OUT="$WORK/s17.out"
( cd "$GA_CWD_DECOY" && AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
    AI_DLC_ESCALATIONS="$ESC_INFORCE" AI_DLC_PROJECT_ROOT="$GA_CWD_ROOT" \
    bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" --transcript-dir "$TDIR" ) > "$GA_S17_OUT" 2>&1
GA_S17_RC=$?
GA_S17_N="$(grep -cF -- "$SUPP_LINE" "$GA_S17_OUT")" || GA_S17_N=0
if [ "$GA_S17_RC" -eq 0 ] && [ "$GA_S17_N" -gt 0 ]; then
  ok "S17: with no AI_DLC_GATE_METRICS, run from a cwd whose own timeline expires the entry, the carve-out still fires — the sibling was pointed at the gate's project root"
else
  bad "S17: the carve-out did not fire (rc=$GA_S17_RC) — the sibling counted the cwd project's gates, or was never told which root this gate belongs to"
fi

# =============================================================================
# S18–S22: THE CITATION IS VERIFIED, and an entry whose quote no operator said covers nothing.
#
# THE DEFECT. The sibling checks that `**Operator authorization:**` carries a timestamp and a
# quote; nothing here compared the quote to anything, so a lead could write its own gate
# passage into pending.md and this validator adopted it — measured on this very seed: a
# well-formed in-force entry with no transcript corpus anywhere exited 0 with the SUPPRESSED
# line. The remediation guard already verifies the same rows with the same predicate
# (`validate-steering-budget.sh --cite`); these cases hold the gate to it too.
#
# THE TWO WRONG FIXES THESE ARE SHAPED AGAINST. (1) A verifier that greps the corpus for the
# words: it accepts $TDIR_FORGED, where the words sit only in an assistant turn and a
# tool_result, and S18 is the case that kills it. (2) A verifier that treats "no corpus given"
# as "nothing to verify" and keeps the rows: S19 and S21 kill it, and S20 holds the single-file
# fallback so the fix cannot simply demand a directory. S22 holds that rows are NARROWED, not
# discarded as a set, when one of two entries fails to verify.
# =============================================================================

# --- S18: the words are in the corpus, and no operator said them → exit 1 --
restore; fail_on "$X"
runx "$ESC_INFORCE" "$GM_BEFORE" "$TDIR_FORGED"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "$UNVERIFIED_LINE" \
   && has "unverified-citation: 1 in-force" && ! has "$SUPP_LINE"; then
  ok "S18: an in-force entry whose quote appears only in an assistant turn and a tool_result covers nothing → exit 1, and the block says unverified-citation: 1"
else
  bad "S18: a FORGED citation covered the FAIL (rc=$RC) — the verifier is a text search over the corpus rather than the genuine-operator predicate, or the block does not say the citation failed to verify"
fi

# --- S19: NO corpus named at all → exit 1, fail-closed and named ------------
restore; fail_on "$X"
AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
AI_DLC_ESCALATIONS="$ESC_INFORCE" AI_DLC_GATE_METRICS="$GM_BEFORE" \
  bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" > "$SOUT" 2>&1
RC=$?
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "no-transcript" && ! has "$SUPP_LINE"; then
  ok "S19: run with neither --transcript nor --transcript-dir, an in-force entry covers nothing → exit 1 and the block says 'no-transcript'"
else
  bad "S19: with no corpus to verify against, the entry still covered the FAIL (rc=$RC) — 'nothing to verify against' is being read as 'verified'"
fi

# --- S20: --transcript is WIDENED to its directory → exit 0 ----------------
# $TFILE does NOT carry the quote; its sibling in the same directory does. The remediation
# guard widens the session transcript it is handed to that directory, and the gate must read
# the same rows against the same corpus or the two disagree about one entry (measured: gate
# NOMATCH, guard MATCH, on this shape). A single-file scan fails this case.
restore; fail_on "$X"
if grep -qF 'proceed past this one' "$TFILE"; then
  bad "S20-pre: FIXTURE BROKEN — the --transcript file itself carries the quote, so this arm cannot tell a widened scan from a single-file one"
else
  ok "S20-pre: the --transcript file does NOT carry the quote; only its sibling does"
fi
AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
AI_DLC_ESCALATIONS="$ESC_INFORCE" AI_DLC_GATE_METRICS="$GM_BEFORE" \
  bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" --transcript "$TFILE" > "$SOUT" 2>&1
RC=$?
if [ "$RC" -eq 0 ] && has "$SUPP_LINE"; then
  ok "S20: --transcript naming a file whose SIBLING carries the operator's words verifies the entry → exit 0 (the file is widened to its corpus, as the guard does)"
else
  bad "S20: --transcript was scanned as a single file (rc=$RC) — the gate reads a narrower corpus than the guard reads for the same rows, and the two disagree about the same entry"
fi

# --- S23: the verifier FAILS (node off PATH) → exit 1, reported as tooling ---
# A verifier that cannot run is not a finding that the operator's words were invented. The
# entry still covers nothing (fail closed) but the line and the block reason must say the
# verifier failed, not that no operator said it. The control asserts node is genuinely absent
# under the stripped PATH before the arm is read.
restore; fail_on "$X"
GA_NODE_DIR="$(dirname "$(command -v node 2>/dev/null || echo /nonexistent/node)")"
GA_P2="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vx "$GA_NODE_DIR" | paste -sd: -)"
if [ -n "$(PATH="$GA_P2" command -v node 2>/dev/null)" ]; then
  bad "S23-pre: FIXTURE BROKEN — node is still on PATH after stripping $GA_NODE_DIR, so the verifier-failure arm cannot be built"
else
  ok "S23-pre: node is absent under the stripped PATH (control), so the verifier below cannot run"
  PATH="$GA_P2" AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
  AI_DLC_ESCALATIONS="$ESC_INFORCE" AI_DLC_GATE_METRICS="$GM_BEFORE" \
    bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" --transcript-dir "$TDIR" > "$SOUT" 2>&1
  RC=$?
  if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "VALIDATE-GATE-ADJUDICATION: UNVERIFIABLE" \
     && has "verifier-error: 1 in-force" && ! has "no genuine operator turn" && ! has "$SUPP_LINE"; then
    ok "S23: with the verifier unable to run, the entry covers nothing → exit 1, and the line and the block say the VERIFIER failed rather than that the citation is forged"
  else
    bad "S23: a verifier that could not run was read as a verdict (rc=$RC) — either the entry still covered the FAIL, or a tooling failure was printed as an accusation of forgery"
  fi
fi

# --- S21: a directory with NO *.jsonl is not a corpus → exit 1 -------------
restore; fail_on "$X"
runx "$ESC_INFORCE" "$GM_BEFORE" "$TDIR_EMPTY"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "no-transcript" && ! has "$SUPP_LINE"; then
  ok "S21: --transcript-dir naming a directory that holds no *.jsonl is no corpus → exit 1 and the block says 'no-transcript'"
else
  bad "S21: an EXISTING directory with nothing in it was accepted as a corpus (rc=$RC) — '-d' answers whether the path exists, never whether it holds ground truth"
fi

# --- S22: two entries, one genuine and one forged → rows NARROWED ----------
# X's quote is in the corpus and Y's is not; both FAIL. The verified row must still cover X
# while the forged one covers nothing about Y, and the block must say both things.
restore; fail_on "$X" "$Y"
runx "$ESC_TWOQUOTES" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_Y" && ! has "$BLOCK_X" && has "$SUPP_LINE" \
   && has "$UNVERIFIED_LINE" && has "unverified-citation: 1 in-force" && has "1 other FAIL(s) are under"; then
  ok "S22: a genuine entry beside a forged one: '$X' stays covered, '$Y' blocks, and the block says unverified-citation: 1 and 1 other FAIL under a suppression"
else
  bad "S22: rows were not narrowed by the citation check (rc=$RC) — either the forged entry poisoned the genuine one, or the forged one covered '$Y' anyway"
fi

# --- S24: the words are in the corpus, and the HARNESS said them → exit 1 --
# The near-miss S18 cannot reach. S18's forgery is structural -- an assistant turn and a
# tool_result, shapes the predicate already rejects by TYPE. This corpus holds a `type:"user"`
# record whose content is a plain string, the exact shape a typed turn has, differing from one
# only by the `isMeta:true` flag Claude Code sets on records IT injected. Measured on the
# reference consumer: 90 of the 984 records the predicate accepted as operator text carried it.
# A lead cannot make the harness inject arbitrary text, so this is not a forgery surface; it is
# a record class that is not an operator turn being counted as one.
restore; fail_on "$X"
runx "$ESC_INFORCE" "$GM_BEFORE" "$TDIR_META"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "$UNVERIFIED_LINE" && ! has "$SUPP_LINE"; then
  ok "S24: an in-force entry whose quote appears only in an isMeta harness injection covers nothing → exit 1"
else
  bad "S24: a harness-injected record verified the citation (rc=$RC) — the predicate reads the bytes of a user record and not the flag saying who wrote it"
fi

# --- S25: the quote is GENUINE and the TIMESTAMP is not → exit 1 -----------
# ONE PROPERTY from S1: same catalog, same check, same lifetime, same words, same corpus, and
# only the authorization timestamp moved -- to a day before the operator said them. Every arm
# keyed on the words alone passes this entry, which is what made it invisible: unbounded, the
# corpus is the project's whole session history and any phrase the operator ever typed verifies
# a citation filed at any time.
restore; fail_on "$X"
runx "$ESC_STALE_TS" "$GM_BEFORE"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "$UNVERIFIED_LINE" && ! has "$SUPP_LINE"; then
  ok "S25: an in-force entry citing real operator words from a DIFFERENT day covers nothing → exit 1"
else
  bad "S25: a citation whose words were said a day after its own authorization timestamp still covered the FAIL (rc=$RC) — the citation verifier is not bounded to the moment the entry claims"
fi

# --- S26: the stamp is three weeks AFTER the operator spoke → exit 1 -------
# THE MIRROR OF S25, and the direction a lead actually forges: nobody writes an entry and then
# waits for the operator to say something, they write today's entry and reach back for a phrase
# that already exists. S25 puts the words after the stamp; every out-of-window seed in every
# channel did, and a window refusing only that side passed all of them while accepting this.
restore; fail_on "$X"
runx "$ESC_FUTURE_TS" "$GM_BEFORE" "$TDIR"
if [ "$RC" -eq 1 ] && has "$BLOCK_X" && has "$UNVERIFIED_LINE" && ! has "$SUPP_LINE"; then
  ok "S26: an in-force entry whose stamp is three weeks AFTER the operator spoke covers nothing → exit 1"
else
  bad "S26: a citation reaching three weeks BACKWARD for its words still covered the FAIL (rc=$RC) — the window has no lower side, so the only forgery direction anyone uses is unrefused"
fi

# --- S27: the PASS line says whether the rows were verified with a bound ----
# `cite_ts` requires `T` between the date and the time, so a space, a lowercase `t` or a
# date-only stamp yields no bound and a row is verified against the whole corpus -- a pass that
# read byte-identically to a bounded one. On THIS path the count is held at zero by the SIBLING,
# which refuses a non-canonical stamp as malformed before the row is ever listed in force (S4 is
# that arm). The count is printed anyway: the zero belongs to the sibling's shape guard, not to
# this validator, and if that guard widens this number is what moves.
restore; fail_on "$X"
runx "$ESC_INFORCE" "$GM_BEFORE" "$TDIR"
if [ "$RC" -eq 0 ] && has "$SUPP_LINE" && has "unbounded-citation: 0"; then
  ok "S27: the carve-out PASS line reports unbounded-citation: 0 — a gate log can tell a bounded pass from an unbounded one"
else
  bad "S27: the PASS line does not report the unbounded-verify count (rc=$RC) — an unbounded pass and a bounded one are the same bytes"
fi

# --- restore, once more, after the carve-out arms ---------------------------
restore
run "$VERDICT"
[ "$RC" -eq 0 ] && ok "restored verdict after the carve-out arms → exit 0" || bad "the pristine verdict did not pass after the carve-out arms (rc=$RC)"

# ============================================================================
# THE DISPATCH BINDING — a nonce with no dispatch at or after it is not a pass.
# ============================================================================
# Every field the arms above read is written by whoever wrote the file, the nonce and the
# stem both, so the freshness anchor anchors the file to itself. The reference consumer holds
# a verdict that satisfies all of them and that no gate entry ever minted:
# `gate-adjudication/planning-20260902T160000Z.verdict.json`, a 16:00:00Z nonce whose
# adjudicator was dispatched at 13:57:46Z. What separates it from a real pass is ORDER, in
# records written by hooks off a clock, and these arms are the pair that shows the validator
# reads them.
#
# THE ARMS BELOW MUST COME IN PAIRS. A binding arm that refuses everything passes every
# negative here; a binding arm that refuses nothing passes every positive. Each negative
# therefore sits beside the near-miss it must NOT catch.
GA_LEDGER="$WORK/spawn-ledger.jsonl"
GA_WRITES="$WORK/gate-adjudication/.verdict-writes.jsonl"
ga_clean_ledgers() { rm -f "$GA_LEDGER" "$GA_WRITES"; }
# TWO ROWS, AND THE FIRST ONE IS THE EPOCH. A ledger holding only the dispatch under test
# makes that dispatch the EARLIEST row, so a nonce before it is EXEMPT and every "binds"
# arm below passes by exemption rather than by binding — measured: the 20s-after arm and a
# 901s-after arm both read exit 0 with a one-row ledger. A remediator row two weeks before
# the nonce pins the epoch, so the only way to exit 0 is to bind.
ga_ledger() { # <dispatch-ts>
  printf '{"v":1,"ts":"2026-07-01T00:00:00Z","sprint":1,"name":"remediator-seed","role":"remediator"}\n{"v":1,"ts":"%s","sprint":1,"name":"gate-adjudicator-seed","role":"gate-adjudicator"}\n' "$1" > "$GA_LEDGER"
}
ga_ledger_only() { # <dispatch-ts> -- ONE row, so the dispatch IS the epoch; the pre-migration arm's shape
  printf '{"v":1,"ts":"%s","sprint":1,"name":"gate-adjudicator-seed","role":"gate-adjudicator"}\n' "$1" > "$GA_LEDGER"
}
ga_writerow() { # <ts> <stem> <agent_id>
  printf '{"v":1,"ts":"%s","stem":"%s","agent_id":"%s","session":"t","tool":"Write"}\n' "$1" "$2" "$3" > "$GA_WRITES"
}
ga_run() { # -> RC, and GA_OUT carries the message
  GA_OUT="$(AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
              bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" 2>&1)"
  RC=$?
}
ga_unbound() { case "$GA_OUT" in *"bound to NO dispatch"*) return 0 ;; esac; return 1; }

ga_clean_ledgers
ga_run
if [ "$RC" -eq 0 ] && ! ga_unbound; then
  ok "BINDING: with NO ledger of any kind the arm reports nocorpus and blocks nothing — a consumer that has never run the dispatch guard is not wedged"
else
  bad "BINDING: an absent ledger blocked the gate (rc=$RC) — the arm errors on correct data"
fi

# The nonce is minted at gate ENTRY and the adjudicator dispatched after it.
ga_ledger "2026-07-15T14:03:42Z"
ga_run
if [ "$RC" -eq 0 ] && ! ga_unbound; then
  ok "BINDING: a gate-adjudicator dispatched 20s AFTER the nonce binds the pass → exit 0"
else
  bad "BINDING: an honestly ordered pass was refused (rc=$RC) — the arm denies real gates"
fi

# One field moves: the same dispatch, 20s BEFORE the nonce. That is the whole difference
# between a nonce minted at gate entry and one invented afterwards.
ga_ledger "2026-07-15T14:03:02Z"
ga_run
if [ "$RC" -eq 1 ] && ga_unbound; then
  ok "BINDING: the SAME dispatch 20s BEFORE the nonce does not bind it → exit 1 (order is the discriminator)"
else
  bad "BINDING: a nonce minted after its own dispatch passed (rc=$RC) — the arm is not reading the order"
fi

# THE WINDOW'S UPPER BOUND, from both sides one property apart. The nonce is 14:03:22Z; a
# dispatch 899s after it binds and one 901s after it does not. Without this pair the window's
# size is asserted by nothing here, and a window widened to 10^9 passed every arm.
ga_ledger "2026-07-15T14:18:21Z"
ga_run
if [ "$RC" -eq 0 ] && ! ga_unbound; then
  ok "BINDING: a gate-adjudicator dispatched 899s AFTER the nonce binds the pass → exit 0"
else
  bad "BINDING: a dispatch inside the 900s window did not bind (rc=$RC) — the window is narrower than stated"
fi
ga_ledger "2026-07-15T14:18:23Z"
ga_run
if [ "$RC" -eq 1 ] && ga_unbound; then
  ok "BINDING: the SAME dispatch 901s AFTER the nonce does not bind it → exit 1 (the window has an upper bound)"
else
  bad "BINDING: a dispatch outside the window bound the pass (rc=$RC) — the window is unbounded above"
fi
# The wrong-fix arms below start from the UNBOUND state, explicitly.
ga_ledger "2026-07-15T14:03:02Z"

# WRONG FIX #1, killed here: the id in the verdict is now the ledger's exact dispatch name.
# A join on `adjudicator_agent_id` reports BOUND; measured on the reference consumer that join
# accepts 92 of 193 verdicts and accepts the forged one.
py_edit 'doc["adjudicator_agent_id"] = "gate-adjudicator-seed"'
ga_run
if [ "$RC" -eq 1 ] && ga_unbound; then
  ok "BINDING: naming the ledger's REAL dispatch in adjudicator_agent_id still does not bind — a name join is not this arm"
else
  bad "BINDING: a name join lifted it (rc=$RC) — the binding is keyed on a field whoever writes the file writes"
fi
restore

# WRONG FIX #2, killed here: gate_nonce, generated_at and the stem are all made mutually
# consistent. They already were; a binding keyed on any of them is a tautology, because one
# writer writes all three.
py_edit 'doc["generated_at"] = "2026-07-15T14:03:22Z"'
ga_run
if [ "$RC" -eq 1 ] && ga_unbound; then
  ok "BINDING: making generated_at agree with the nonce does not bind it — a join over lead-written fields is a tautology"
else
  bad "BINDING: an envelope-internal agreement satisfied the binding (rc=$RC)"
fi
restore

# The acquitting direction for B1: a dispatched agent's own write of THIS stem, after the nonce.
ga_writerow "2026-07-15T14:06:00Z" "$NONCE" "aseed-0123456789abcdef"
ga_run
if [ "$RC" -eq 0 ] && ! ga_unbound; then
  ok "BINDING: a write row for this stem, carrying the harness's agent_id and clocked AFTER the nonce, binds it → exit 0"
else
  bad "BINDING: a legitimately recorded write did not bind the pass (rc=$RC) — B1 cannot acquit, so every refusal above is unearned"
fi

# ...and the two ways that row stops being evidence.
ga_writerow "2026-07-15T14:06:00Z" "$NONCE" ""
ga_run
if [ "$RC" -eq 1 ] && ga_unbound; then
  ok "BINDING: the same row with an EMPTY agent_id does not bind — a lead's own write is not a dispatch"
else
  bad "BINDING: a write row with no harness attribution bound the pass (rc=$RC)"
fi
ga_writerow "2026-07-15T14:02:00Z" "$NONCE" "aseed-0123456789abcdef"
ga_run
if [ "$RC" -eq 1 ] && ga_unbound; then
  ok "BINDING: the same row clocked BEFORE the nonce does not bind — B1 carries the order arm too"
else
  bad "BINDING: a write predating its own nonce bound the pass (rc=$RC)"
fi
ga_writerow "2026-07-15T14:06:00Z" "implementation-20260715T140321Z" "aseed-0123456789abcdef"
ga_run
if [ "$RC" -eq 1 ] && ga_unbound; then
  ok "BINDING: a row for a DIFFERENT stem does not bind this one — B1 is keyed on the stem"
else
  bad "BINDING: a write row for another verdict bound this one (rc=$RC)"
fi
rm -f "$GA_WRITES"

# PRE-MIGRATION. Every row in both ledgers postdates the nonce, so nothing could have recorded
# this pass and the arm must report PENDING rather than a defect. Without this, installing the
# binding turns every verdict already on disk into a gate failure.
ga_ledger_only "2027-01-01T00:00:00Z"
ga_run
if [ "$RC" -eq 0 ] && ! ga_unbound; then
  ok "BINDING: a nonce predating every row in the ledger is EXEMPT → exit 0 (pre-migration is not a defect)"
else
  bad "BINDING: a pre-migration verdict was scored as a defect (rc=$RC) — installing this would fail every gate already on disk"
fi
ga_clean_ledgers
restore
run "$VERDICT"
[ "$RC" -eq 0 ] && ok "restored verdict after the binding arms → exit 0" || bad "the pristine verdict did not pass after the binding arms (rc=$RC)"

echo
if [ "$fails" -eq 0 ]; then echo "gate-adjudication: PASS"; exit 0; fi
echo "gate-adjudication: $fails assertion(s) FAILED" >&2
exit 1
